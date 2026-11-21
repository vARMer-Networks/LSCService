-- SPDX-License-Identifier: MIT
-- Throughput-oriented Actor compilation. Jobs run to completion in their Actor.
local roblox = script ~= nil
local Support = if roblox then require(script.Parent.CompileSupport) else require("./CompileSupport")
local Pool = {}
Pool.__index = Pool

local function limit(value, default, name, minimum, maximum)
    if value == nil then return default end
    assert(type(value) == "number" and value % 1 == 0 and value >= minimum and value <= maximum,
        name .. " is out of range")
    return value
end

local function timeout(value, default)
    if value == nil then return default end
    assert(type(value) == "number" and value >= 0 and value < math.huge, "invalid timeoutSeconds")
    return value
end

local function finish(self, job, ok, result, stats)
    if not self.jobs[job.id] then return end
    self.jobs[job.id] = nil
    if job.timer then task.cancel(job.timer) end
    task.defer(job.callback, ok, result, stats)
end

local function removeQueued(self, index)
    local job = table.remove(self.queue, index)
    self.queuedBytes -= job.bytes
    return job
end

local function release(self, slot)
    local job = slot.job
    slot.job = nil
    if job then self.inFlightBytes -= job.bytes end
    return job
end

local function clearStartupTimer(slot)
    if slot.startupTimer then
        task.cancel(slot.startupTimer)
        slot.startupTimer = nil
    end
end

local function dispatch(self)
    if self.destroyed then return end
    local available = false
    for _, slot in self.slots do
        available = available or slot.state ~= "failed"
        local job = self.queue[1]
        if job and slot.state == "ready" and not slot.job and self.inFlightBytes + job.bytes <= self.maxInFlightBytes then
            removeQueued(self, 1)
            self.inFlightBytes += job.bytes
            slot.job = job
            local sent, problem = pcall(slot.actor.SendMessage, slot.actor, "Compile", job.id, job.source, job.options, job.structured)
            job.source, job.options = nil, nil
            if not sent then
                release(self, slot)
                finish(self, job, false, tostring(problem))
                -- Destroying will replace the transport if the container is still active.
                slot.actor:Destroy()
            end
        end
    end
    if not available then
        while #self.queue > 0 do
            finish(self, removeQueued(self, 1), false, self.workerError or "Texere Actor workers are unavailable")
        end
    end
end

local function spawnWorker(self, slot)
    local actor = Instance.new("Actor")
    actor.Name = "Worker" .. slot.index
    slot.actor, slot.state = actor, "starting"
    slot.startup = nil
    local entry = self.template:Clone()
    entry.Parent = actor
    actor.Parent = self.container
    slot.destroying = actor.Destroying:Connect(function()
        if self.destroyed or slot.actor ~= actor then return end
        clearStartupTimer(slot)
        local job = release(self, slot)
        if job then finish(self, job, false, "Worker Actor was destroyed") end
        slot.state = "failed"
        -- A successfully initialized worker can be replaced once per loss.
        -- Failed startup is terminal for that slot until a new pool is created.
        if slot.startup then
            slot.state = "restarting"
            task.defer(function()
                if not self.destroyed and self.container.Parent then spawnWorker(self, slot) end
            end)
        else
            dispatch(self)
        end
    end)
    entry.Enabled = true
    slot.startupTimer = task.delay(self.startupTimeout, function()
        slot.startupTimer = nil
        if self.destroyed or slot.actor ~= actor or slot.state ~= "starting" then return end
        self.workerError = "Texere worker initialization timed out"
        actor:Destroy()
    end)
end

function Pool.new(options)
    assert(roblox and game and game.GetService and game:GetService("RunService"):IsRunning(),
        "Texere Actor workers require a running Roblox client or server")
    options = options or {}
    assert(type(options) == "table", "parallel compiler options must be a table")
    local runService = game:GetService("RunService")
    local client = runService:IsClient()
    local profile = require(script.Parent.Parent.generated.texere.MemoryProfiles)
    local memoryBytes = if options.memoryBytes == nil then 16777216 else options.memoryBytes
    assert(profile[memoryBytes], "memoryBytes is unavailable in this Texere compiler build")
    assert(not options.defaultBudgetMs and not options.idleRetireSeconds and not options.lazyWorkers,
        "Texere Actor workers support throughput mode with eager startup")
    local workers = limit(options.numWorkers, if client then 1 else 2, "numWorkers", 1, 8)
    local maxSourceBytes = limit(options.maxSourceBytes, math.min(memoryBytes - 1, 10 * 2^20),
        "maxSourceBytes", 1, memoryBytes - 1)
    local maxQueue = limit(options.maxQueueLength, 1000, "maxQueueLength", 1, 2^31 - 1)
    local maxQueuedBytes = limit(options.maxQueuedSourceBytes, 20 * 2^20, "maxQueuedSourceBytes", 1, 2^31 - 1)
    local maxInFlightBytes = limit(options.maxInFlightSourceBytes, 20 * 2^20, "maxInFlightSourceBytes", 1, 2^31 - 1)
    local defaultTimeout = timeout(options.timeoutSeconds, 30)
    local startupTimeout = timeout(options.startupTimeoutSeconds, 30)
    assert(startupTimeout > 0, "startupTimeoutSeconds must be positive")
    local parent = options.parent
    if not parent then
        parent = if client then game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")
            else game:GetService("ServerScriptService")
    end
    assert(typeof(parent) == "Instance" and parent:IsDescendantOf(game), "Actor parent must be in the DataModel")
    local template = script.Parent[if client then "TexereWorkerClient" else "TexereWorkerServer"]
    local container = Instance.new("Folder")
    container.Name = "TexereCompilerWorkers"
    container:SetAttribute("MemoryBytes", memoryBytes)
    container:SetAttribute("Prewarm", options.prewarm == true)
    local module = Instance.new("ObjectValue")
    module.Name = "WorkerModule"
    module.Value = script.Parent.TexereWorker
    module.Parent = container
    local inbox = Instance.new("BindableEvent")
    inbox.Name = "WorkerReply"
    inbox.Parent = container
    local self = setmetatable({
        container = container, template = template, memoryBytes = memoryBytes, cacheBytes = options.cacheBytes,
        maxSourceBytes = maxSourceBytes, maxQueue = maxQueue, maxQueuedBytes = maxQueuedBytes,
        maxInFlightBytes = maxInFlightBytes, defaultTimeout = defaultTimeout, startupTimeout = startupTimeout,
        slots = {}, queue = {}, jobs = {}, nextId = 0, queuedBytes = 0, inFlightBytes = 0, destroyed = false,
    }, Pool)

    self.reply = inbox.Event:Connect(function(actor, request, ok, payload, stats)
        if self.destroyed then return end
        for _, slot in self.slots do
            if slot.actor ~= actor then continue end
            if request == 0 and slot.state == "starting" then
                clearStartupTimer(slot)
                if ok then
                    slot.state, slot.startup = "ready", payload
                else
                    self.workerError = tostring(payload)
                    slot.state = "failed"
                    actor:Destroy()
                end
            elseif slot.job and slot.job.id == request then
                local job = release(self, slot)
                finish(self, job, ok, payload, stats)
            else
                return
            end
            dispatch(self)
            return
        end
    end)
    self.containerDestroying = container.Destroying:Connect(function()
        self:_dispose(false)
    end)
    container.Parent = parent
    for index = 1, workers do
        local slot = {index = index}
        self.slots[index] = slot
        spawnWorker(self, slot)
    end
    return self
end

local function submit(self, source, options, callback, structured)
    assert(not self.destroyed, "ParallelCompiler is destroyed")
    assert(type(source) == "string" and #source <= self.maxSourceBytes, "source exceeds per-request limit or is not a string")
    assert(type(callback) == "function", "callback must be a function")
    assert(options == nil or type(options) == "table", "compile options must be a table")
    options = options or {}
    assert(not options.adaptive and not options.adaptiveConfig and not options.budgetMs and not options.editorKey,
        "Texere Actor workers support throughput requests only")
    local seconds = timeout(options.timeoutSeconds, self.defaultTimeout)
    local validated = Support.options(options)
    local wire = {}
    for _, name in {"optimizationLevel", "debugLevel", "coverageLevel", "typeInfoLevel", "raw", "sourceName",
        "vectorLib", "vectorCtor", "vectorType", "mutableGlobals", "disabledBuiltins", "userdataTypes"} do
        wire[name] = validated[name]
    end
    assert(self:isParallelSupported(), self.workerError or "Texere Actor workers are unavailable")
    assert(#self.queue < self.maxQueue, "compile queue is full")
    assert(self.queuedBytes + #source <= self.maxQueuedBytes, "aggregate queued source bytes limit exceeded")
    assert(#source <= self.maxInFlightBytes, "request exceeds the in-flight source bytes limit")
    self.nextId += 1
    local id = self.nextId
    local job = {id = id, source = source, bytes = #source, options = wire, callback = callback, structured = structured}
    self.jobs[id] = job
    table.insert(self.queue, job)
    self.queuedBytes += job.bytes
    if seconds > 0 then
        job.timer = task.delay(seconds, function()
            job.timer = nil
            self:cancel(id, "Request timed out")
        end)
    end
    dispatch(self)
    return id
end

function Pool:compileQueued(source, options, callback)
    if self._isCliFallback then
        local ok, result = pcall(function() return self:compile(source, options) end)
        if callback then callback(ok, result) end
        return 1
    end
    return submit(self, source, options, callback, false)
end

function Pool:compileResultQueued(source, options, callback)
    if self._isCliFallback then
        local result = self:compileResult(source, options)
        if callback then callback(result.ok, result) end
        return 1
    end
    return submit(self, source, options, callback, true)
end

local function await(self, source, options, structured)
    if self._isCliFallback then
        return if structured then self:compileResult(source, options) else self:compile(source, options)
    end
    assert(coroutine.isyieldable(), "Actor compilation requires a yieldable coroutine")
    local thread = coroutine.running()
    submit(self, source, options, function(...)
        if coroutine.status(thread) == "suspended" then task.spawn(thread, ...) end
    end, structured)
    local ok, result, stats = coroutine.yield()
    if not ok then error(result, 2) end
    return result, stats
end

function Pool:compileAsync(source, options)
    return await(self, source, options, false)
end

function Pool:compileResultAsync(source, options)
    return await(self, source, options, true)
end

function Pool:compile(source, options)
    assert(not self.destroyed, "ParallelCompiler is destroyed")
    assert(type(source) == "string" and #source <= self.maxSourceBytes, "source exceeds per-request limit or is not a string")
    if not self.sync then
        local TexereCompiler = if roblox then require(script.Parent.TexereCompiler) else require("./TexereCompiler")
        self.sync = TexereCompiler({memoryBytes = self.memoryBytes, cacheBytes = self.cacheBytes})
    end
    return self.sync.compile(source, options)
end

function Pool:compileResult(source, options)
    assert(not self.destroyed, "ParallelCompiler is destroyed")
    assert(type(source) == "string" and #source <= self.maxSourceBytes, "source exceeds per-request limit or is not a string")
    if not self.sync then
        local TexereCompiler = if roblox then require(script.Parent.TexereCompiler) else require("./TexereCompiler")
        self.sync = TexereCompiler({memoryBytes = self.memoryBytes, cacheBytes = self.cacheBytes})
    end
    return self.sync.compileResult(source, options)
end

function Pool:compileFrameSafe(source, options)
    assert(not self.destroyed, "ParallelCompiler is destroyed")
    return self:compile(source, options)
end

function Pool:cancel(id, reason)
    local job = self.jobs[id]
    if not job then
        for index, qJob in ipairs(self.queue) do
            if qJob.id == id then
                qJob.cancelled = true
                qJob.state = "cancelled"
                removeQueued(self, index)
                finish(self, qJob, false, reason or "Request was cancelled")
                dispatch(self)
                return true
            end
        end
        return false
    end
    job.cancelled = true
    job.state = "cancelled"
    local index = table.find(self.queue, job)
    if index then removeQueued(self, index) end
    finish(self, job, false, reason or "Request was cancelled")
    dispatch(self)
    return true
end

function Pool:isParallelSupported()
    if self.destroyed or self._isCliFallback then return false end
    for _, slot in self.slots do
        if slot.state ~= "failed" then return true end
    end
    return false
end

function Pool:getWorkersReady()
    local ready = 0
    for _, slot in self.slots do
        if slot.state == "ready" then ready += 1 end
    end
    return ready
end

function Pool:getTotalWorkers()
    return #self.slots
end

function Pool:getQueueLength()
    return #self.queue
end

function Pool:getStatus()
    local idle, inFlight = 0, 0
    for _, slot in self.slots do
        if slot.job then inFlight += 1 elseif slot.state == "ready" then idle += 1 end
    end
    return {
        isParallelSupported = self:isParallelSupported(),
        workerCount = #self.slots,
        idleWorkerCount = idle,
        queueLength = #self.queue,
        inFlightCount = inFlight,
        mode = if self._isCliFallback then "cli_fallback" else "actor_parallel",
        workersTotal = #self.slots,
        workersReady = self:getWorkersReady(),
        queuedSourceBytes = self.queuedBytes,
        inFlightSourceBytes = self.inFlightBytes,
        maxQueuedSourceBytes = self.maxQueuedBytes,
        maxInFlightSourceBytes = self.maxInFlightBytes,
        memoryBytesPerWorker = self.memoryBytes,
        destroyed = self.destroyed,
    }
end

function Pool:prewarm(seconds)
    assert(not self.destroyed, "ParallelCompiler is destroyed")
    seconds = timeout(seconds, self.startupTimeout)
    local started = os.clock()
    while self:getWorkersReady() < #self.slots do
        if self.destroyed then return false, "ParallelCompiler was destroyed" end
        if self.workerError then return false, self.workerError end
        if os.clock() - started >= seconds then return false, "Worker initialization timed out" end
        task.wait()
    end
    local workers = {}
    for _, slot in self.slots do workers[slot.index] = table.clone(slot.startup) end
    return true, {elapsedMs = (os.clock() - started) * 1000, workers = workers}
end

function Pool:_dispose(destroyContainer)
    if self.destroyed then return end
    self.destroyed = true
    self._destroyed = true
    if self.reply then self.reply:Disconnect() end
    if self.containerDestroying then self.containerDestroying:Disconnect() end
    for _, job in self.jobs do finish(self, job, false, "ParallelCompiler was destroyed") end
    table.clear(self.queue)
    self.queuedBytes = 0
    for _, slot in self.slots do
        if slot.destroying then slot.destroying:Disconnect() end
        clearStartupTimer(slot)
        release(self, slot)
        slot.state, slot.startup, slot.actor = "failed", nil, nil
    end
    if destroyContainer and self.container then self.container:Destroy() end
    self.container, self.sync = nil, nil
end

function Pool:destroy()
    self:_dispose(true)
end

return table.freeze(Pool)
