--!native
-- ParallelCompiler.luau
-- Parallel Luau compiler driver utilizing Roblox Actor workers.
-- Supports throughput-oriented and cooperative time-budgeted compilation.
-- Cooperative budgets are measured targets, not engine frame-time guarantees.

local roblox = script ~= nil
local Cache = if roblox then require(script.Parent.BytecodeCache) else require('./BytecodeCache')
local Support = if roblox then require(script.Parent.CompileSupport) else require('./CompileSupport')
local function mark(name)
    if debug.profilebegin then debug.profilebegin('LuauSquared.'..name) end
end
local function unmark() if debug.profileend then debug.profileend() end end
-- Factory loading belongs to the chosen execution path, not manager require.
local Compiler, IncrementalCompiler
local function loadSync()
    if not Compiler then Compiler = if roblox then require(script.Parent.Compiler) else require("./Compiler") end
    return Compiler
end
local function loadIncremental()
    if not IncrementalCompiler then
        if roblox then
            local mod = script.Parent:FindFirstChild("IncrementalCompiler")
            if mod then IncrementalCompiler = require(mod) end
        else
            IncrementalCompiler = require("./IncrementalCompiler")
        end
    end
    return IncrementalCompiler
end

local ParallelCompiler = {}
ParallelCompiler.__index = ParallelCompiler

local DEFAULT_MAX_SOURCE_BYTES = 10 * 1024 * 1024 -- 10 MB per-request limit
local DEFAULT_MAX_QUEUED_SOURCE_BYTES = 20 * 1024 * 1024 -- 20 MB aggregate queue limit
local DEFAULT_MAX_IN_FLIGHT_SOURCE_BYTES = 20 * 1024 * 1024 -- 20 MB aggregate in-flight limit
local DEFAULT_MAX_QUEUE_LENGTH = 1000

local function finitePositive(value, name, integer)
    assert(type(value)=="number" and value>0 and value<math.huge and (not integer or value%1==0), `{name} must be finite and positive`)
    return value
end

function ParallelCompiler.new(options)
    options = options or {}
    local timeoutSeconds = options.timeoutSeconds
    if timeoutSeconds~=nil then
        assert(type(timeoutSeconds)=="number" and timeoutSeconds>=0 and timeoutSeconds<math.huge,"timeoutSeconds must be finite and nonnegative")
    end
    local maxSourceBytes = finitePositive(options.maxSourceBytes or DEFAULT_MAX_SOURCE_BYTES,"maxSourceBytes",true)
    local maxQueuedSourceBytes = finitePositive(options.maxQueuedSourceBytes or DEFAULT_MAX_QUEUED_SOURCE_BYTES,"maxQueuedSourceBytes",true)
    local maxInFlightSourceBytes = finitePositive(options.maxInFlightSourceBytes or DEFAULT_MAX_IN_FLIGHT_SOURCE_BYTES,"maxInFlightSourceBytes",true)
    local maxQueueLength = finitePositive(options.maxQueueLength or DEFAULT_MAX_QUEUE_LENGTH,"maxQueueLength",true)
    local defaultBudgetMs = finitePositive(options.defaultBudgetMs or 2.0,"defaultBudgetMs")
    local idleRetireSeconds = if options.idleRetireSeconds==nil then 0 else options.idleRetireSeconds
    assert(type(idleRetireSeconds)=='number' and idleRetireSeconds>=0 and idleRetireSeconds<math.huge,'invalid idleRetireSeconds')
    local memoryBytes = if options.memoryBytes==nil then 16777216 else options.memoryBytes
    assert(memoryBytes==16777216 or memoryBytes==33554432 or memoryBytes==67108864,'invalid memoryBytes')

    -- Detect execution context to choose lean default worker count
    local isClient = false
    local isRunning = false
    if roblox and game and game.GetService then
        local rs = game:GetService("RunService")
        pcall(function() isRunning = rs:IsRunning() end)
        pcall(function() isClient = rs:IsClient() end)
    end

    -- Default: one worker on the client, two on the server.
    local defaultWorkers = if isClient then 1 else 2
    local numWorkers = math.clamp(finitePositive(options.numWorkers or defaultWorkers,"numWorkers",true), 1, 8)
    local lazyWorkers = options.lazyWorkers == true

    local self = setmetatable({
        _syncCompiler = nil,
        _incCompiler = nil,
        _actors = {},
        _workerQueue = {},
        _idleWorkers = {},
        _pendingRequests = {},
        _nextRequestId = 1,
        _destroyed = false,
        _replyEvent = nil,
        _readyEvent = nil,
        _replyConn = nil,
        _readyConn = nil,
        _container = nil,
        _isRobloxActorSupported = false,
        _lazyWorkers = lazyWorkers,
        _actorsCreated = false,
        _ensureWorkers = nil,
        _timeoutSeconds = timeoutSeconds,
        _maxSourceBytes = maxSourceBytes,
        _maxQueuedSourceBytes = maxQueuedSourceBytes,
        _maxInFlightSourceBytes = maxInFlightSourceBytes,
        _maxQueueLength = maxQueueLength,
        _defaultBudgetMs = defaultBudgetMs,
        _queuedSourceBytes = 0,
        _inFlightSourceBytes = 0,
        _workersInitialized = 0,
        _workerStartup = {},
        _readyWorkers = {},
        _workerConns = {},
        _totalWorkers = numWorkers,
        _memoryBytes = memoryBytes,
        _idleRetireSeconds = idleRetireSeconds,
        _cache = Cache.new(options.cacheBytes),
        _shared = {},
        _subscribers = {},
        _editorRequests = {},
        _sharedRequests = 0,
        _workerEpoch = {},
    }, ParallelCompiler)

    -- Detect if running in an active Roblox game engine with parallel Actor support
    if roblox and game and game.GetService and isRunning then
        local hs = game:GetService("HttpService")

        -- Determine container parent
        local parentContainer = options.parent
        if not parentContainer then
            local containerName = "LuauParallelWorkers_" .. hs:GenerateGUID(false):sub(1, 8)
            parentContainer = Instance.new("Folder")
            parentContainer.Name = containerName

            local targetService = if isClient
                then game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")
                else game:GetService("ServerScriptService")

            parentContainer.Parent = targetService
        end
        self._container = parentContainer
        parentContainer:SetAttribute('CompilerMemoryBytes',memoryBytes)

        -- ObjectValue reference to Compiler module for worker script resolution
        local compilerRef = Instance.new("ObjectValue")
        compilerRef.Name = "CompilerModule"
        compilerRef.Value = script.Parent:FindFirstChild("Compiler")
        compilerRef.Parent = parentContainer

        -- ObjectValue reference to IncrementalCompiler module
        local incRef = Instance.new("ObjectValue")
        incRef.Name = "IncrementalCompilerModule"
        incRef.Value = script.Parent:FindFirstChild("IncrementalCompiler")
        incRef.Parent = parentContainer
        local workerRef = Instance.new("ObjectValue")
        workerRef.Name = "WorkerModule"
        workerRef.Value = script.Parent:FindFirstChild("ParallelWorker")
        workerRef.Parent = parentContainer

        -- Reply event for worker results
        local replyEvent = Instance.new("BindableEvent")
        replyEvent.Name = "ReplyEvent"
        replyEvent.Parent = parentContainer
        self._replyEvent = replyEvent

        -- Ready event for worker startup handshake
        local readyEvent = Instance.new("BindableEvent")
        readyEvent.Name = "ReadyEvent"
        readyEvent.Parent = parentContainer
        self._readyEvent = readyEvent

        -- Handle worker readiness handshake
        self._readyConn = readyEvent.Event:Connect(function(actorName, startup)
            if self._destroyed then return end
            for i, actor in ipairs(self._actors) do
                if actor.Name == actorName then
                    if not self._readyWorkers[i] then
                        self._readyWorkers[i] = true
                        table.insert(self._idleWorkers, i)
                        self._workersInitialized += 1
                        self._workerStartup[i] = startup
                        self:_dispatchNext()
                        self:_scheduleRetirement()
                    end
                    break
                end
            end
        end)

        -- Handle incoming compilation results
        self._replyConn = replyEvent.Event:Connect(function(requestId, ok, result, stats)
            local req = self._pendingRequests[requestId]
            if not req then return end
            self._pendingRequests[requestId] = nil
            mark('ResultHandling')

            -- Release in-flight resource accounting
            self._inFlightSourceBytes = math.max(0, self._inFlightSourceBytes - #req.source)
            unmark()
            self:_scheduleRetirement()

            -- Recycle worker back to idle pool and dispatch next queued job
            local workerIndex = req.workerIndex
            if workerIndex and not self._destroyed then
                table.insert(self._idleWorkers, workerIndex)
                self:_dispatchNext()
            end

            -- If the request was cancelled, discard the result
            if req.cancelled then
                req.state = "cancelled"
                return
            end

            req.state = if ok then "completed" else "failed"

            self:_complete(req, ok, result, stats)
            self:_scheduleRetirement()
        end)

        -- Locate worker script template and configure lazy/immediate worker spawning
        local workerTemplate = script.Parent:FindFirstChild(if isClient then "ParallelWorkerClient" else "ParallelWorkerServer")
        if workerTemplate and (not workerTemplate:IsA("Script") or workerTemplate.RunContext ~= (if isClient then Enum.RunContext.Client else Enum.RunContext.Server)) then
            workerTemplate = nil
        end
        local function spawnWorkers()
            if self._actorsCreated or self._destroyed or not workerTemplate then return end
            self._actorsCreated = true
            self._poolGeneration=(self._poolGeneration or 0)+1
            for i = 1, numWorkers do
                local actor = Instance.new("Actor")
                actor.Name = "WorkerActor_" .. i .. '_' .. self._poolGeneration
                actor.Parent = parentContainer

                local workerScript = workerTemplate:Clone()
                -- Attach the disabled template before enabling it. Enabling a
                -- detached Script can consume its startup before Actor parenting.
                workerScript.Parent = actor

                table.insert(self._actors, actor)
                local index = i
                table.insert(self._workerConns, actor.Destroying:Connect(function()
                    if self._destroyed then return end
                    if self._readyWorkers[index] then self._workersInitialized -= 1 end
                    self._readyWorkers[index] = nil
                    local idle=table.find(self._idleWorkers,index)
                    if idle then table.remove(self._idleWorkers,idle) end
                    for id,req in self._pendingRequests do
                        if req.workerIndex==index then
                            self._pendingRequests[id]=nil
                            self._inFlightSourceBytes=math.max(0,self._inFlightSourceBytes-#req.source)
                            req.state="failed"
                            self:_complete(req,false,"Worker Actor was destroyed")
                        end
                    end
                    self:_dispatchNext()
                end))
                workerScript.Enabled = true
            end
            self._isRobloxActorSupported = (#self._actors > 0)
        end
        self._ensureWorkers = spawnWorkers

        if workerTemplate then
            self._isRobloxActorSupported = true
            if not lazyWorkers then
                spawnWorkers()
            end
        end
    else
        self._ensureWorkers = function() end
    end

    -- Lazy synchronous compiler for direct fallback or non-Actor environments
    self._getSyncCompiler = function()
        if not self._syncCompiler then
            mark('InitializeSync')
            self._syncCompiler = loadSync()({memoryBytes=memoryBytes,cacheBytes=options.cacheBytes})
            unmark()
        end
        return self._syncCompiler
    end

    -- Lazy incremental compiler for cooperative single-thread execution
    self._getIncCompiler = function()
        if not self._incCompiler then
            local incremental = loadIncremental()
            if incremental then
                mark('InitializeCooperative')
                self._incCompiler = incremental.new({ defaultBudgetMs = self._defaultBudgetMs, memoryBytes=memoryBytes,cacheBytes=options.cacheBytes })
                unmark()
            else
                self._incCompiler = self._getSyncCompiler()
            end
        end
        return self._incCompiler
    end

    return self
end

function ParallelCompiler:_notify(req, ok, result, stats)
    if req.notified then return end
    req.notified=true
    if stats then
        stats=table.clone(stats)
        for name,value in stats do if type(value)=='table' then stats[name]=table.clone(value) end end
    end
    if req.thread and coroutine.status(req.thread) ~= "dead" then task.spawn(req.thread,ok,result,stats) end
    if req.callback then
        local success,message=pcall(req.callback,ok,result,stats)
        if not success then warn(message) end
    end
end

function ParallelCompiler:_complete(work, ok, result, stats)
    if work.sharedKey then
        local group = self._shared[work.source]
        if group and group[work.sharedKey]==work then
            group[work.sharedKey]=nil
            if next(group)==nil then self._shared[work.source]=nil end
        end
        if ok then self._cache:put(work.source,work.sharedKey,result) end
    end
    if work.waiters then
        for id,req in work.waiters do
            self._subscribers[id]=nil
            req.work=nil
            req.state=if ok then 'completed' else 'failed'
            if req.editorKey and self._editorRequests[req.editorKey]==id then self._editorRequests[req.editorKey]=nil end
            self:_notify(req,ok,result,stats)
        end
        work.waiters=nil
    else self:_notify(work,ok,result,stats) end
end

function ParallelCompiler:_scheduleRetirement()
    if self._idleRetireSeconds==0 or not task or not task.delay then return end
    self._retireEpoch=(self._retireEpoch or 0)+1
    local epoch=self._retireEpoch
    task.delay(self._idleRetireSeconds,function()
        if self._destroyed or self._retireEpoch~=epoch or #self._workerQueue>0 or next(self._pendingRequests) then return end
        -- Retire the whole idle pool together; the next request recreates it.
        self._actorsCreated=false
        for _,connection in self._workerConns do connection:Disconnect() end
        self._workerConns={}
        for _,actor in self._actors do actor:Destroy() end
        self._actors={} self._idleWorkers={} self._readyWorkers={} self._workersInitialized=0
    end)
end

function ParallelCompiler:_dispatchNext()
    if self._destroyed then return end
    if #self._workerQueue == 0 or #self._idleWorkers == 0 then
        return
    end
    local best,score
    local now=os.clock()
    for i,queued in self._workerQueue do
        if self._inFlightSourceBytes+#queued.source<=self._maxInFlightSourceBytes then
            local current=(queued.options and queued.options.priority or 0)+(now-queued.startTime)
            if not score or current>score then best,score=i,current end
        end
    end
    if not best then return end

    -- Pick first non-cancelled request
    local req = table.remove(self._workerQueue, best)
    if not req then return end

    if req.cancelled then
        req.state = "cancelled"
        self._queuedSourceBytes = math.max(0, self._queuedSourceBytes - #req.source)
        return self:_dispatchNext()
    end

    local workerIndex = table.remove(self._idleWorkers, 1)
    req.workerIndex = workerIndex
    req.state = "running"
    self._pendingRequests[req.id] = req

    -- Transition from queued to in-flight accounting
    self._queuedSourceBytes = math.max(0, self._queuedSourceBytes - #req.source)
    self._inFlightSourceBytes += #req.source

    local actor = self._actors[workerIndex]
    if actor and actor.Parent then
        local msgType = if req.frameSafe then "CompileFrameSafe" else "Compile"
        mark('Dispatch')
        actor:SendMessage(msgType, req.id, req.source, req.options, self._replyEvent)
        unmark()
    else
        -- Worker actor missing or destroyed; fail request gracefully
        self._pendingRequests[req.id] = nil
        self._inFlightSourceBytes = math.max(0, self._inFlightSourceBytes - #req.source)
        req.state = "failed"
        self:_complete(req,false,"Worker Actor destroyed or unavailable")
        self:_dispatchNext()
    end
end

function ParallelCompiler:_submitRequest(source, options, thread, callback, frameSafe)
    assert(not self._destroyed, "ParallelCompiler is destroyed")
    assert(type(source) == "string", "source must be a string")
    assert(#source <= self._maxSourceBytes, "source size exceeds per-request maximum limit")
    options=Support.options(options)
    local priority=options.priority or 0
    assert(type(priority)=='number' and priority>=0 and priority<=10 and priority<math.huge,'priority must be from 0 to 10')
    assert(options.editorKey==nil or type(options.editorKey)=='string' and #options.editorKey<=4096,'invalid editorKey')
    local timeout=if options.timeoutSeconds~=nil then options.timeoutSeconds else self._timeoutSeconds
    assert(timeout==nil or type(timeout)=='number' and timeout>=0 and timeout<math.huge,'invalid request timeout')
    local key=Cache.key({options=options,cooperative=frameSafe==true})
    local cached=self._cache:get(source,key)
    local group=self._shared[source]
    local work=group and group[key]
    local id=self._nextRequestId
    local subscriber={id=id,thread=thread,callback=callback,state='queued',editorKey=options.editorKey}
    if options.editorKey then
        local previous=self._editorRequests[options.editorKey]
        if previous then self:cancel(previous,'Editor request was superseded') end
        assert(not self._destroyed,'ParallelCompiler was destroyed during a completion callback')
        group=self._shared[source]
        work=group and group[key]
    end
    if not cached and not work then
    assert(#self._workerQueue < self._maxQueueLength, "compile queue is full")
    assert(self._queuedSourceBytes + #source <= self._maxQueuedSourceBytes, "aggregate queued source bytes limit exceeded")
    assert(self._inFlightSourceBytes + #source <= self._maxInFlightSourceBytes, "aggregate in-flight source bytes limit exceeded")
    end
    self._nextRequestId+=1
    self._subscribers[id]=subscriber
    if options.editorKey then self._editorRequests[options.editorKey]=id end
    if cached then
        task.defer(function()
            self._subscribers[id]=nil
            if subscriber.editorKey and self._editorRequests[subscriber.editorKey]==id then self._editorRequests[subscriber.editorKey]=nil end
            if not subscriber.notified then
                subscriber.state='completed'
                self:_notify(subscriber,true,cached,{cacheHit=true,totalSteps=0})
            end
        end)
        return id
    end
    if work then
        self._sharedRequests+=1
        work.waiters[id]=subscriber subscriber.work=work
    else
    self._retireEpoch=(self._retireEpoch or 0)+1
    if self._ensureWorkers then self:_ensureWorkers() end

    local req = {
        id = id,
        source = source,
        options = options,
        cancelled = false,
        state = "queued",
        workerIndex = nil,
        startTime = os.clock(),
        frameSafe = frameSafe or false,
        sharedKey=key,
        waiters={[id]=subscriber},
    }
    subscriber.work=req
    group=self._shared[source] or {}
    self._shared[source]=group group[key]=req

    self._queuedSourceBytes += #source
    table.insert(self._workerQueue, req)
    self:_dispatchNext()
    end

    -- Request timeout safeguard
    if timeout and timeout > 0 and task and task.delay then
        task.delay(timeout, function()
            if not subscriber.notified then
                local msg = "Request timed out after " .. tostring(timeout) .. " seconds"
                self:cancel(id,msg)
            end
        end)
    end

    return id
end

-- Mode 1: High-throughput parallel compilation
function ParallelCompiler:compileAsync(source, options)
    assert(not self._destroyed, "ParallelCompiler is destroyed")
    if self:isParallelSupported() then
        assert(coroutine.isyieldable(), "compileAsync requires a yieldable coroutine")
        local thread = coroutine.running()
        self:_submitRequest(source, options, thread, nil, false)
        local ok, result, stats = coroutine.yield()
        if not ok then error(result, 0) end
        return result, stats
    end

    -- Fallback in non-Actor environment
    local sync = self._getSyncCompiler()
    if sync.compileDeferred and coroutine.isyieldable() then
        return sync:compileDeferred(source, options)
    end
    return sync:compile(source, options)
end

-- Mode 2: Time-budgeted parallel cooperative compilation (legacy API name).
function ParallelCompiler:compileFrameSafe(source, options)
    assert(not self._destroyed, "ParallelCompiler is destroyed")
    options = options or {}
    local budgetMs = options.budgetMs or self._defaultBudgetMs

    if self:isParallelSupported() then
        assert(coroutine.isyieldable(), "compileFrameSafe requires a yieldable coroutine")
        local thread = coroutine.running()
        self:_submitRequest(source, options, thread, nil, true)
        local ok, result, stats = coroutine.yield()
        if not ok then error(result, 0) end
        return result, stats
    end

    -- Fallback in non-Actor environment: cooperative stepping on main thread
    return self:compileCooperative(source, options, budgetMs)
end

-- Mode 2b: Adaptive dynamic-budgeting compilation
function ParallelCompiler:compileAdaptive(source, options, adaptiveConfig)
    options = table.clone(options or {})
    options.adaptive = true
    if adaptiveConfig then
        options.adaptiveConfig = adaptiveConfig
    end
    return self:compileFrameSafe(source, options)
end

-- Mode 3: Local single-thread cooperative compilation.
function ParallelCompiler:compileCooperative(source, options, budgetMs)
    assert(not self._destroyed, "ParallelCompiler is destroyed")
    assert(type(source) == "string", "source must be a string")
    assert(coroutine.isyieldable(), "compileCooperative requires a yieldable coroutine")
    local inc = self._getIncCompiler()
    if options and (options.adaptive or options.adaptiveConfig) and inc.compileAdaptive then
        return inc:compileAdaptive(source, options, options.adaptiveConfig)
    elseif inc.compileCooperative then
        return inc:compileCooperative(source, options, budgetMs or self._defaultBudgetMs)
    elseif inc.beginCompile then
        local job = inc:beginCompile(source, options)
        budgetMs = budgetMs or self._defaultBudgetMs
        while not job:isComplete() do
            job:step(budgetMs)
            if not job:isComplete() and task and task.wait then
                task.wait()
            end
        end
        return job:getBytecode()
    else
        return self:compile(source, options)
    end
end

function ParallelCompiler:compileQueued(source, options, callback)
    assert(not self._destroyed, "ParallelCompiler is destroyed")
    assert(type(source) == "string", "source must be a string")
    assert(type(callback) == "function", "callback must be a function")
    assert(#source <= self._maxSourceBytes, "source size exceeds per-request maximum limit")
    assert(self._queuedSourceBytes + #source <= self._maxQueuedSourceBytes, "aggregate queued source bytes limit exceeded")
    assert(self._inFlightSourceBytes + #source <= self._maxInFlightSourceBytes, "aggregate in-flight source bytes limit exceeded")

    if self:isParallelSupported() then
        return self:_submitRequest(source, options, nil, callback, false)
    end

    -- Fallback for non-Actor environments
    local id = self._nextRequestId
    self._nextRequestId += 1
    self._queuedSourceBytes += #source

    if task and task.defer then
        task.defer(function()
            local ok, result = pcall(function()
                return self._getSyncCompiler():compile(source, options)
            end)
            self._queuedSourceBytes = math.max(0, self._queuedSourceBytes - #source)
            callback(ok, result)
        end)
    else
        self._queuedSourceBytes = math.max(0, self._queuedSourceBytes - #source)
        local ok, result = pcall(function()
            return self._getSyncCompiler():compile(source, options)
        end)
        callback(ok, result)
    end
    return id
end

-- Mode 5: Direct synchronous compilation
function ParallelCompiler:compile(source, options)
    assert(not self._destroyed, "ParallelCompiler is destroyed")
    assert(type(source) == "string", "source must be a string")
    assert(#source <= self._maxSourceBytes, "source size exceeds maximum limit")
    return self._getSyncCompiler():compile(source, options)
end

function ParallelCompiler:cancel(requestId, reason)
    local subscriber=self._subscribers[requestId]
    if subscriber then
        self._subscribers[requestId]=nil
        if subscriber.editorKey and self._editorRequests[subscriber.editorKey]==requestId then self._editorRequests[subscriber.editorKey]=nil end
        subscriber.state='cancelled'
        self:_notify(subscriber,false,reason or 'Request was cancelled')
        local work=subscriber.work
        subscriber.work=nil
        if not work then return true end
        work.waiters[requestId]=nil
        if next(work.waiters) then return true end
        local group=self._shared[work.source]
        if group and group[work.sharedKey]==work then
            group[work.sharedKey]=nil
            if next(group)==nil then self._shared[work.source]=nil end
        end
        requestId=work.id
    end
    -- 1. Check if request is currently running on a worker
    local req = self._pendingRequests[requestId]
    if req then
        req.cancelled = true
        req.state = "cancelled"
        self:_notify(req,false,reason or "Request was cancelled")
        -- Send cancel message to worker Actor so it aborts early at the next slice
        local workerIndex = req.workerIndex
        if workerIndex and self._actors[workerIndex] then
            pcall(function()
                self._actors[workerIndex]:SendMessage("Cancel", requestId)
            end)
        end
        return true
    end

    -- 2. Check if request is still waiting in the queue
    for i, qReq in ipairs(self._workerQueue) do
        if qReq.id == requestId then
            qReq.cancelled = true
            qReq.state = "cancelled"
            self._queuedSourceBytes = math.max(0, self._queuedSourceBytes - #qReq.source)
            table.remove(self._workerQueue, i)
            self:_notify(qReq,false,reason or "Request was cancelled")
            return true
        end
    end

    return false
end

function ParallelCompiler:isParallelSupported()
    if self._destroyed then return false end
    return self._isRobloxActorSupported
end

-- Explicitly pay worker initialization before interactive use. Status queries
-- and rejected requests never spawn lazy workers. Returns actual readiness.
function ParallelCompiler:prewarm(timeoutSeconds)
    assert(not self._destroyed, "ParallelCompiler is destroyed")
    assert(coroutine.isyieldable(), "prewarm requires a yieldable coroutine")
    timeoutSeconds = timeoutSeconds or self._timeoutSeconds or 30
    assert(type(timeoutSeconds)=="number" and timeoutSeconds>0 and timeoutSeconds<math.huge, "invalid prewarm timeout")
    if not self._isRobloxActorSupported then return false, "Actor workers are unavailable" end
    local started = os.clock()
    self:_ensureWorkers()
    while self._workersInitialized < self._totalWorkers do
        if self._destroyed then return false, "ParallelCompiler was destroyed" end
        if os.clock()-started >= timeoutSeconds then return false, "Worker initialization timed out" end
        task.wait()
    end
    return true, {elapsedMs=(os.clock()-started)*1000, workers=self._workerStartup}
end

function ParallelCompiler:getWorkersReady()
    return self._workersInitialized
end

function ParallelCompiler:getTotalWorkers()
    return self._totalWorkers
end

function ParallelCompiler:getQueueLength()
    return #self._workerQueue
end

function ParallelCompiler:getStatus()
    local isPar = self:isParallelSupported()
    local inFlight = 0
    for _ in pairs(self._pendingRequests) do inFlight += 1 end
    return {
        isParallelSupported = isPar,
        workerCount = #self._actors,
        idleWorkerCount = #self._idleWorkers,
        queueLength = #self._workerQueue,
        inFlightCount = inFlight,
        mode = if not self._isRobloxActorSupported
            then (if roblox then "roblox_serial_fallback" else "cli_fallback")
            else "actor_parallel",
        workersTotal = self._totalWorkers,
        workersReady = self._workersInitialized,
        idleWorkers = #self._idleWorkers,
        queuedRequests = #self._workerQueue,
        pendingRequests = inFlight,
        queuedSourceBytes = self._queuedSourceBytes,
        inFlightSourceBytes = self._inFlightSourceBytes,
        maxQueuedSourceBytes = self._maxQueuedSourceBytes,
        maxInFlightSourceBytes = self._maxInFlightSourceBytes,
        destroyed = self._destroyed,
        memoryBytesPerWorker = self._memoryBytes,
        cache = self._cache:stats(),
        sharedRequests = self._sharedRequests,
    }
end

function ParallelCompiler:destroy()
    if self._destroyed then return end
    self._destroyed = true

    if self._replyConn then self._replyConn:Disconnect(); self._replyConn = nil end
    if self._readyConn then self._readyConn:Disconnect(); self._readyConn = nil end
    for _,connection in self._workerConns do connection:Disconnect() end
    self._workerConns={}

    for _, req in ipairs(self._workerQueue) do
        req.cancelled = true
        req.state = "cancelled"
        self:_complete(req,false,"ParallelCompiler was destroyed")
    end
    self._workerQueue = {}
    self._queuedSourceBytes = 0

    for id, req in pairs(self._pendingRequests) do
        req.cancelled = true
        req.state = "cancelled"
        self:_complete(req,false,"ParallelCompiler was destroyed")
    end
    self._pendingRequests = {}
    self._inFlightSourceBytes = 0

    if self._container and self._container.Parent then
        self._container:Destroy()
        self._container = nil
    end

    self._actors = {}
    self._idleWorkers = {}
    self._workersInitialized = 0
    self._readyWorkers = {}
    self._workerStartup = {}
    self._syncCompiler = nil
    self._incCompiler = nil
    for _,req in self._subscribers do self:_notify(req,false,'ParallelCompiler was destroyed') end
    self._subscribers={} self._shared={} self._editorRequests={}
    self._cache:clear()
end

return ParallelCompiler
