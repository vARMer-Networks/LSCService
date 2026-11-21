-- Resumable, budgeted Luau source compiler backed by an instrumented Texere² factory.
local roblox = script ~= nil
local texere = if roblox then script.Parent.Parent.generated.texere else nil
local Support = if roblox then require(script.Parent.CompileSupport) else require("./CompileSupport")
local Cache = if roblox then require(script.Parent.BytecodeCache) else require("./BytecodeCache")
local Compiler = {}
local MAX_FUEL = 2 ^ 53 - 1

local function positive(value, label)
    assert(type(value) == "number" and value > 0 and value < math.huge, label .. " must be positive and finite")
    return value
end

local function adaptiveSettings(options, budgetMs)
    local config = options.adaptiveConfig or {}
    local min = positive(config.minBudgetMs or 1, "minBudgetMs")
    local max = positive(config.maxBudgetMs or 8, "maxBudgetMs")
    assert(min <= max, "minBudgetMs exceeds maxBudgetMs")
    return 1000 / positive(config.targetFps or 60, "targetFps"), min, max,
        math.clamp(positive(config.initialBudgetMs or budgetMs, "initialBudgetMs"), min, max)
end

local function traceLimit(options)
    if options.traceLimit ~= nil then
        local limit = options.traceLimit
        assert(type(limit) == "number" and limit >= 0 and limit <= 65536 and limit % 1 == 0, "invalid traceLimit")
    end
    assert(options.detailedTelemetry == nil or type(options.detailedTelemetry) == "boolean", "detailedTelemetry must be a boolean")
    return if options.detailedTelemetry then options.traceLimit or 256 else 0
end

local function waitFrame()
    if script then return game:GetService("RunService").Heartbeat:Wait() * 1000 end
    if task and task.wait then task.wait() end
    return nil
end

function Compiler.prewarm(factory, yieldFn)
    if type(factory) == "table" and type(factory.prewarm) == "function" then
        return factory.prewarm(yieldFn)
    end
    return 0
end

function Compiler.prewarmCooperative(factory, budgetMs, yieldFn)
    local ms = if budgetMs == nil then 4 else positive(budgetMs, "budgetMs")
    local stepYield = yieldFn or (if coroutine.isyieldable() then function() waitFrame() end else nil)
    if type(factory) == "table" and type(factory.prewarmCooperative) == "function" then
        return factory.prewarmCooperative(ms / 1000, stepYield)
    end
    return Compiler.prewarm(factory, stepYield)
end

function Compiler.new(config)
    config = config or {}
    assert(type(config) == "table", "Texere incremental compiler config must be a table")
    local factory = config.factory
        or (if roblox then require(texere.Resumable.Main) else require("../generated/texere/Resumable/Main"))
    local adapter = config.adapter
        or (if roblox then require(texere.Adapter) else require("../generated/texere/Adapter"))
    local binding = config.binding
        or (if roblox then require(texere.LuauCompiler) else require("../generated/texere/LuauCompiler"))
    local configuredMs = if config.budgetMs == nil then config.defaultBudgetMs else config.budgetMs
    local budgetMs = positive(if configuredMs == nil then 2 else configuredMs, "budgetMs")
    local cache = Cache.new(config.cacheBytes)
    local defaultTraceLimit = traceLimit(config)
    local bound, instance
    local active, disposed = false, false
    local sharedRegistry = config.registry

    local function buildAdapterOptions()
        local base = if type(config.adapterOptions) == "table" then table.clone(config.adapterOptions) else {}
        base.resumable = true
        if base.plugins == nil and config.plugins ~= nil then base.plugins = config.plugins end
        if base.extensions == nil and config.extensions ~= nil then base.extensions = config.extensions end
        if base.imports == nil and config.imports ~= nil then base.imports = config.imports end
        if base.globals == nil and config.globals ~= nil then base.globals = config.globals end
        if base.resolveImport == nil and config.resolveImport ~= nil then base.resolveImport = config.resolveImport end
        if base.hooks == nil and config.hooks ~= nil then base.hooks = config.hooks end
        if base.gc == nil and config.gc ~= nil then base.gc = config.gc end
        if sharedRegistry ~= nil then base.registry = sharedRegistry end
        return base
    end

    local function buildBindingOptions()
        local opts = {}
        local hasAny = false
        for _, key in {"beforeCompile", "afterCompile", "onDiagnostic", "plugins", "extensions", "hooks", "profile"} do
            if config[key] ~= nil then
                opts[key] = config[key]
                hasAny = true
            end
        end
        return if hasAny then opts else nil
    end

    local memoryBytes = config.memoryBytes
    local function initialize()
        local candidate = adapter.instantiate(factory, buildAdapterOptions())
        candidate.initialize()
        local capacity = candidate.exports().memory.size() * 65536
        assert(memoryBytes == nil or memoryBytes == capacity, "Texere compiler memory profile mismatch")
        memoryBytes = capacity
        if candidate.registry ~= nil then
            sharedRegistry = candidate.registry
        end
        bound = binding.bind(candidate, buildBindingOptions())
        instance = candidate
        if type(config.onReset) == "function" then
            config.onReset(candidate)
        end
    end

    local function initializeCooperative(stepBudgetMs)
        assert(coroutine.isyieldable(), "cooperative initialization requires a yieldable coroutine")
        local stepMs = positive(if stepBudgetMs == nil then budgetMs else stepBudgetMs, "initBudgetMs")
        local candidate = adapter.instantiate(factory, buildAdapterOptions())
        local initTask = candidate.beginInitialize()
        local ok, problem = pcall(function()
            while true do
                local state = initTask:stepFor(stepMs)
                if state == "completed" then
                    break
                elseif state ~= "suspended" then
                    local _, failure = initTask:getFailure()
                    error(failure or "Texere initialization failed", 0)
                end
                waitFrame()
            end
        end)
        if not ok then
            pcall(initTask.cancel, initTask)
            error(problem, 0)
        end
        local capacity = candidate.exports().memory.size() * 65536
        assert(memoryBytes == nil or memoryBytes == capacity, "Texere compiler memory profile mismatch")
        memoryBytes = capacity
        if candidate.registry ~= nil then
            sharedRegistry = candidate.registry
        end
        bound = binding.bind(candidate, buildBindingOptions())
        instance = candidate
        if type(config.onReset) == "function" then
            config.onReset(candidate)
        end
    end

    if config.prewarm == true then
        Compiler.prewarm(factory, if coroutine.isyieldable() then function() waitFrame() end else nil)
    elseif type(config.prewarm) == "function" then
        Compiler.prewarm(factory, config.prewarm)
    end
    if config.cooperativeInit == true then
        initializeCooperative(config.initBudgetMs)
    else
        initialize()
    end
    local api = {
        backend = "texere",
        memoryBytes = memoryBytes,
        registry = sharedRegistry,
        gc = if instance then instance.gc else nil,
        isDisposed = function() return disposed or (instance ~= nil and instance.isDisposed and instance.isDisposed()) or false end,
        dispose = function()
            if disposed then return end
            disposed = true
            bound = nil
            if instance and instance.dispose then instance.dispose() end
        end,
    }

    local function release(discard)
        active = false
        if discard then bound = nil end
    end

    function api:beginCompile(source, options)
        assert(not disposed, "Texere incremental compiler has been disposed")
        assert(not active, "compiler instance is already running a compilation job")
        assert(type(source) == "string", "source must be a string")
        assert(#source + 1 <= memoryBytes, "compiler source exceeds its fixed memory limit")
        options = Support.options(options)
        local defaultMs = if options.budgetMs == nil then budgetMs else positive(options.budgetMs, "budgetMs")
        local targetFrame, minBudget, maxBudget, adaptiveBudget = adaptiveSettings(options, defaultMs)
        local limit = if options.detailedTelemetry == nil then defaultTraceLimit else traceLimit(options)
        -- Each cache belongs to the resumable incremental Texere compiler instance.
        local key = if cache.limit > 0 then Cache.key(options, "texere-incremental") else nil
        local cached = if key then cache:get(source, key) else nil
        local request = {
            optimizationLevel = options.optimizationLevel,
            debugLevel = options.debugLevel,
            coverageLevel = options.coverageLevel,
        }
        if Support.hasExtra(options) then
            request.extra = options
        end
        active = true
        local execution
        if not cached then
            local ok, pending = pcall(function()
                if not bound then initialize() end
                return bound.beginCompile(source, request)
            end)
            if not ok then
                release(true)
                error(pending, 0)
            end
            execution = pending
        end
        local sourceName, raw = options.sourceName, options.raw
        local status, result, bytes, message = "running", nil, nil, nil
        local totalSteps, totalCheckpoints = 0, 0
        local elapsedCpuMs, maxStepMs, maxOvershootMs, maxResumeGapMs = 0, 0, 0, 0
        local startedAt, finishedAt, lastStepEnd = os.clock(), nil, nil
        local stepTimes, budgetTimes, resumeGaps = nil, nil, nil
        if limit > 0 then stepTimes, budgetTimes, resumeGaps = {}, {}, {} end
        local frames, frameIndex, healthy, recovery = nil, 1, 0, 0
        local profiling = options.profileCheckpoints == true
        local maxCheckpointGapMs
        local job = {}
        local releaseOwner = release
        local cacheHit = cached ~= nil
        local cacheSource, resultCache = if key and not cached then source else nil, if key and not cached then cache else nil
        local stepping = false

        local function updateWork()
            if not execution then return end
            local stats = execution:getStats()
            totalCheckpoints = stats.work
            maxCheckpointGapMs = stats.maxCheckpointGapMs
        end

        local function finish(discard, finished)
            updateWork()
            execution, cacheSource, resultCache, cached = nil, nil, nil, nil
            finishedAt = finished
            releaseOwner(discard)
            releaseOwner = nil
        end

        local function step(timed, budget)
            local start = os.clock()
            if lastStepEnd then
                local gap = (start - lastStepEnd) * 1000
                maxResumeGapMs = math.max(maxResumeGapMs, gap)
                if resumeGaps and #resumeGaps < limit then resumeGaps[#resumeGaps + 1] = gap end
            end
            stepping = true
            local ok, state = true, "completed"
            if execution then
                local method = if timed then execution.stepFor else execution.step
                ok, state = pcall(method, execution, budget, profiling)
            end
            stepping = false
            local ended = os.clock()
            lastStepEnd = ended
            local elapsed = (ended - start) * 1000
            totalSteps += 1
            elapsedCpuMs += elapsed
            maxStepMs = math.max(maxStepMs, elapsed)
            if stepTimes and #stepTimes < limit then stepTimes[#stepTimes + 1] = elapsed end
            if timed then
                maxOvershootMs = math.max(maxOvershootMs, elapsed - budget)
                if budgetTimes and #budgetTimes < limit then budgetTimes[#budgetTimes + 1] = budget end
            end
            if ok and state == "suspended" then return false end
            if not ok or state ~= "completed" then
                local problem = state
                if ok then
                    local _, failure = execution:getFailure()
                    problem = failure
                else
                    pcall(execution.cancel, execution)
                end
                message = tostring(problem)
                if string.find(message, "cannot grow the fixed", 1, true) or string.find(message, "malloc returned null", 1, true) then
                    message = "compiler memory limit exceeded: " .. message
                end
                status, result = "failed", Support.failure(message, sourceName)
                finish(true, ended)
                return true
            end
            local diagnostic
            if execution then
                bytes, diagnostic = execution:getResult()
            else
                bytes = cached
            end
            if diagnostic then
                status = if raw then "completed" else "failed"
                if not raw then message = string.sub(bytes, 2) end
                result = {ok = false, diagnostic = {
                    category = if diagnostic.category == 1 then "syntax" else "compile",
                    message = diagnostic.message,
                    sourceName = sourceName,
                    range = {
                        start = {line = diagnostic.beginLine, column = diagnostic.beginColumn},
                        finish = {line = diagnostic.endLine, column = diagnostic.endColumn},
                    },
                }}
            else
                status, result = "completed", {ok = true, bytecode = bytes}
                if resultCache then resultCache:put(cacheSource, key, bytes) end
            end
            finish(false, ended)
            return true
        end

        function job:step(ms)
            if status ~= "running" then return true end
            assert(not stepping, "cannot step a running compilation job")
            return step(true, positive(if ms == nil then budgetMs else ms, "budgetMs"))
        end
        function job:stepFuel(checkpoints)
            if status ~= "running" then return true end
            assert(not stepping, "cannot step a running compilation job")
            local fuel = if checkpoints == nil then 500 else checkpoints
            assert(type(fuel) == "number" and fuel >= 1 and fuel <= MAX_FUEL and fuel % 1 == 0,
                "work budget must be a positive safe integer")
            return step(false, fuel)
        end
        function job:stepAdaptive(observedFrameDtMs)
            if status ~= "running" then return true end
            assert(not stepping, "cannot step a running compilation job")
            if observedFrameDtMs ~= nil then
                local dt = observedFrameDtMs
                assert(type(dt) == "number" and dt >= 0 and dt < math.huge, "observedFrameDtMs must be finite and nonnegative")
                -- At most 16 samples, so the nearest-rank 95th percentile is the maximum.
                if not frames then frames = table.create(16) end
                frames[frameIndex] = dt
                frameIndex = frameIndex % 16 + 1
                local slowest = dt
                for _, frame in frames do slowest = math.max(slowest, frame) end
                if slowest > targetFrame * 1.05 then
                    adaptiveBudget = math.max(minBudget, adaptiveBudget * 0.7)
                    healthy, recovery = 0, 4
                elseif recovery > 0 then
                    recovery -= 1
                elseif slowest < targetFrame * 0.85 then
                    healthy += 1
                    if healthy == 3 then
                        adaptiveBudget = math.min(maxBudget, adaptiveBudget + 0.5)
                        healthy = 0
                    end
                else
                    healthy = 0
                end
            end
            return step(true, adaptiveBudget)
        end
        function job:getAdaptiveBudget() return adaptiveBudget end
        function job:isComplete() return status ~= "running" end
        function job:getStatus() return status end
        function job:getError() return message end
        function job:getResult()
            return result or {ok = false, diagnostic = {category = "pending", message = "compilation is running", sourceName = sourceName}}
        end
        function job:getBytecode()
            assert(self:isComplete(), "compilation job has not completed")
            if status == "cancelled" then error("compilation job was cancelled", 0) end
            if status == "failed" then error(message, 0) end
            return bytes
        end
        function job:getStats()
            updateWork()
            return {totalSteps = totalSteps, totalCheckpoints = totalCheckpoints, elapsedCpuMs = elapsedCpuMs,
                maxStepMs = maxStepMs, totalWallMs = ((finishedAt or os.clock()) - startedAt) * 1000,
                maxResumeGapMs = maxResumeGapMs, maxOvershootMs = maxOvershootMs, maxCheckpointGapMs = maxCheckpointGapMs,
                traceLimit = limit, traceTruncated = totalSteps > limit, cacheHit = cacheHit,
                adaptiveBudgetMs = adaptiveBudget, stepTimes = if stepTimes then table.clone(stepTimes) else {},
                budgetTimes = if budgetTimes then table.clone(budgetTimes) else {},
                resumeGaps = if resumeGaps then table.clone(resumeGaps) else {}}
        end
        function job:cancel()
            if status ~= "running" then return end
            assert(not stepping, "cannot cancel a running compilation job")
            if execution then execution:cancel() end
            status = "cancelled"
            result = {ok = false, diagnostic = {category = "cancelled", message = "compilation was cancelled", sourceName = sourceName}}
            finish(totalSteps > 0, os.clock())
        end
        return table.freeze(job)
    end

    function api:compile(source, options)
        local job = self:beginCompile(source, options)
        while not job:stepFuel(MAX_FUEL) do end
        return job:getBytecode()
    end

    function api:compileResult(source, options)
        local ok, job = pcall(self.beginCompile, self, source, options)
        if not ok then
            local name = Support.sourceName(options)
            local failure = Support.failure(job, name)
            return if failure.diagnostic.category == "resource" then failure else Support.validation(job, name)
        end
        while not job:stepFuel(MAX_FUEL) do end
        return job:getResult()
    end

    function api:getCacheStats() return cache:stats() end
    function api:clearCache() cache:clear() end

    function api:compileCooperative(source, options, ms)
        assert(coroutine.isyieldable(), "compileCooperative requires a yieldable coroutine")
        if ms ~= nil then positive(ms, "budgetMs") end
        if not bound then initializeCooperative(ms) end
        local job = self:beginCompile(source, options)
        while not job:step(ms) do waitFrame() end
        return job:getBytecode(), job:getStats()
    end

    function api:compileAdaptive(source, options, config)
        assert(coroutine.isyieldable(), "compileAdaptive requires a yieldable coroutine")
        assert(options == nil or type(options) == "table", "compile options must be a table")
        if not bound then
            local initMs = if type(config) == "table" and config.initialBudgetMs ~= nil then config.initialBudgetMs else budgetMs
            initializeCooperative(initMs)
        end
        local request = table.clone(options or {})
        if config ~= nil then request.adaptiveConfig = config end
        local job = self:beginCompile(source, request)
        local frameMs
        while not job:stepAdaptive(frameMs) do frameMs = waitFrame() end
        return job:getBytecode(), job:getStats()
    end

    return table.freeze(api)
end

return table.freeze(Compiler)
