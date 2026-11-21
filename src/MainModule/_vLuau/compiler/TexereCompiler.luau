-- Luau² V3 synchronous source-compiler backed by the pinned Luau compiler translated by Texere² (MIT).
local roblox = script ~= nil
local texere = if roblox then script.Parent.Parent.generated.texere else nil
local Profiles = if roblox then require(texere.MemoryProfiles) else require("../generated/texere/MemoryProfiles")
local Adapter = if roblox then require(texere.Adapter) else require("../generated/texere/Adapter")
local Binding = if roblox then require(texere.LuauCompiler) else require("../generated/texere/LuauCompiler")
local Support = if roblox then require(script.Parent.CompileSupport) else require("./CompileSupport")
local Cache = if roblox then require(script.Parent.BytecodeCache) else require("./BytecodeCache")

local MEMORY_BYTES = 16777216

local function positive(value, label)
    assert(type(value) == "number" and value > 0 and value < math.huge, label .. " must be positive and finite")
    return value
end

local function waitFrame()
    if script then return game:GetService("RunService").Heartbeat:Wait() * 1000 end
    if task and task.wait then task.wait() end
    return nil
end

local function prewarmFactory(factory, yieldFn)
    if type(factory) == "table" and type(factory.prewarm) == "function" then
        return factory.prewarm(yieldFn)
    end
    return 0
end

local function prewarmFactoryCooperative(factory, budgetMs, yieldFn)
    local ms = if budgetMs == nil then 4 else positive(budgetMs, "budgetMs")
    local stepYield = yieldFn or (if coroutine.isyieldable() then function() waitFrame() end else nil)
    if type(factory) == "table" and type(factory.prewarmCooperative) == "function" then
        return factory.prewarmCooperative(ms / 1000, stepYield)
    end
    return prewarmFactory(factory, stepYield)
end

-- Texere reports faults as tables that print their stage. Callers of this API expect strings, and
-- Support.failure classifies resource exhaustion by text.
local function describe(problem)
    local message = tostring(problem)
    if string.find(message, "malloc returned null", 1, true) then
        return "compiler source allocation failed: " .. message
    end
    if string.find(message, "cannot grow the fixed", 1, true) then
        return "compiler memory limit exceeded: " .. message
    end
    return message
end

local function makeCompiler(config)
    config = config or {}
    local memoryBytes = if config.memoryBytes == nil then MEMORY_BYTES else config.memoryBytes
    local profile = Profiles[memoryBytes]
    assert(profile ~= nil, "memoryBytes is unavailable in this Texere compiler build")
    local factory = if roblox then require(texere[profile.entry]) else require("../generated/texere/" .. profile.entry)
    local revision = profile.revision or (if roblox then require(texere.Revision) else require("../generated/texere/Revision"))

    if config.prewarm == true then
        prewarmFactory(factory, if coroutine.isyieldable() then function() waitFrame() end else nil)
    elseif type(config.prewarm) == "function" then
        prewarmFactory(factory, config.prewarm)
    end
    local instance, translate
    local busy, needsReset, disposed = false, false, false
    local api
    local cache = Cache.new(config.cacheBytes)
    local lastDiagnostic
    local sharedRegistry = config.registry

    local function buildAdapterOptions()
        local base = if type(config.adapterOptions) == "table" then table.clone(config.adapterOptions) else {}
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

    local function initialize()
        -- A failed call can abandon C++ destructors and allocator state. Recreate the whole instance.
        local nextInstance = Adapter.instantiate(factory, buildAdapterOptions())
        nextInstance.initialize()
        assert(nextInstance.exports().memory.size() * 65536 == memoryBytes, "Texere compiler memory profile mismatch")
        if nextInstance.registry ~= nil then
            sharedRegistry = nextInstance.registry
        end
        local bound = Binding.bind(nextInstance, buildBindingOptions())
        translate = bound.compile
        instance = nextInstance
        needsReset = false
        if api then
            api.registry = sharedRegistry or instance.registry
            api.gc = instance.gc
            api.metadata = instance.metadata
        end
        if type(config.onReset) == "function" then
            config.onReset(nextInstance)
        end
    end
    initialize()

    local function compileWork(source, options)
        local request = {
            optimizationLevel = options.optimizationLevel,
            debugLevel = options.debugLevel,
            coverageLevel = options.coverageLevel,
        }
        if Support.hasExtra(options) then
            local extra = {typeInfoLevel = options.typeInfoLevel}
            for _, name in {"vectorLib", "vectorCtor", "vectorType", "mutableGlobals", "disabledBuiltins", "userdataTypes"} do
                extra[name] = options[name]
            end
            request.extra = extra
        end
        local bytes, diagnostic = translate(source, request)
        lastDiagnostic = if diagnostic then {
            category = if diagnostic.category == 1 then "syntax" else "compile",
            message = diagnostic.message,
            sourceName = options.sourceName,
            range = {
                start = {line = diagnostic.beginLine, column = diagnostic.beginColumn},
                finish = {line = diagnostic.endLine, column = diagnostic.endColumn},
            },
        } else nil
        assert(string.byte(bytes) == 0 or string.byte(bytes) == 14, "upstream compiler bytecode profile changed")
        return bytes
    end

    local function compileInternal(source, options)
        assert(not disposed, "Texere compiler has been disposed")
        assert(type(source) == "string", "source must be a string")
        options = Support.options(options)
        local key = if cache.limit > 0 then Cache.key(options, revision) else ""
        assert(not busy, "compiler instance is already compiling")
        assert(#source + 1 <= memoryBytes, "compiler source exceeds its fixed memory limit")
        lastDiagnostic = nil
        local cached = if cache.limit > 0 then cache:get(source, key) else nil
        if cached then return cached end
        if needsReset then initialize() end
        busy = true
        local ok, bytes = pcall(compileWork, source, options)
        busy = false
        if not ok then
            needsReset = true
            error(describe(bytes), 0)
        end
        if string.byte(bytes) == 0 then
            if not options.raw then error(string.sub(bytes, 2), 0) end
            -- Raw error bytes do not carry structured coordinates. Let compileResult
            -- rerun the guest so it can return the full diagnostic.
            return bytes
        end
        cache:put(source, key, bytes)
        return bytes
    end

    local function compile(a, b, c, d, e)
        local source, options, debugLevel, raw
        if type(a) == "table" then
            assert(a == api, "invalid compiler receiver")
            source, options, debugLevel, raw = b, c, d, e
        else
            source, options, debugLevel, raw = a, b, c, d
        end
        if type(options) == "table" then
            return compileInternal(source, options)
        end
        return compileInternal(source, {optimizationLevel = options, debugLevel = debugLevel, raw = raw})
    end

    local function compileDeferred(a, b, c, d, e)
        -- Deferral only: compilation itself is synchronous and does not yield.
        if task and task.defer then
            assert(coroutine.isyieldable(), "compileDeferred requires a yieldable coroutine")
            if type(a) == "table" and type(c) == "table" then c = table.clone(c)
            elseif type(b) == "table" then b = table.clone(b) end
            local thread = coroutine.running()
            task.defer(function()
                if coroutine.status(thread) == "dead" then return end
                local ok, result = pcall(compile, a, b, c, d, e)
                if coroutine.status(thread) ~= "dead" then task.spawn(thread, ok, result) end
            end)
            local ok, result = coroutine.yield()
            if not ok then error(result, 0) end
            return result
        end
        return compile(a, b, c, d, e)
    end

    api = {
        backend = "texere",
        compile = compile,
        compileDeferred = compileDeferred,
        compileAsync = compileDeferred, -- compatibility alias; no nonblocking guarantee
        memoryBytes = memoryBytes,
        factory = factory,
        chunkCount = if type(factory) == "table" and factory.chunkCount then factory.chunkCount else 0,
        prewarm = function(_, yieldFn) return prewarmFactory(factory, yieldFn) end,
        prewarmCooperative = function(_, budgetMs, yieldFn) return prewarmFactoryCooperative(factory, budgetMs, yieldFn) end,
        heapUsed = function() return instance.exports().ls_compile_heap_used() end,
        committedMemoryBytes = function() return instance.exports().memory.committed_bytes() end,
        getCacheStats = function() return cache:stats() end,
        clearCache = function() cache:clear() end,
        registry = sharedRegistry or instance.registry,
        gc = instance.gc,
        metadata = instance.metadata,
        isDisposed = function() return disposed or (instance ~= nil and instance.isDisposed()) end,
        dispose = function()
            if disposed then return end
            disposed = true
            if instance and instance.dispose then instance.dispose() end
        end,
        compileResult = function(a, b, c)
            local source, options = if a == api then b else a, if a == api then c else b
            lastDiagnostic = nil
            if type(source) ~= "string" then return Support.validation("source must be a string", Support.sourceName(options)) end
            local valid, sanitized = pcall(Support.options, options)
            if not valid then return Support.validation(sanitized, Support.sourceName(options)) end
            options = sanitized
            local ok, result = pcall(compile, source, options)
            if not ok then
                return if lastDiagnostic then {ok = false, diagnostic = lastDiagnostic} else Support.failure(result, Support.sourceName(options))
            end
            if string.byte(result) == 0 then return {ok = false, diagnostic = lastDiagnostic} end
            return {ok = true, bytecode = result}
        end,
    }
    return api
end

local Compiler = setmetatable({
    new = makeCompiler,
    prewarm = prewarmFactory,
    prewarmCooperative = prewarmFactoryCooperative,
}, {
    __call = function(_, config)
        return makeCompiler(config)
    end,
})

return Compiler
