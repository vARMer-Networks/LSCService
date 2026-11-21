local Adapter = if script then require(script.Parent.Adapter) else require("./Adapter")
local Compiler = {}
local instanceState = setmetatable({}, {__mode = "k"})
local Failure = table.freeze({
    __tostring = function(problem)
        return string.format("%s failure during %s: %s", problem.kind, problem.stage, tostring(problem.cause))
    end,
})

local function i32(value, default, name)
    if value == nil then
        return default
    end
    if type(value) ~= "number" or not (value >= -2147483648 and value <= 2147483647 and value % 1 == 0) then
        error("compile option " .. name .. " must be a signed 32-bit integer", 3)
    end
    return value
end

local function cString(value)
    if type(value) ~= "string" or string.find(value, "\0", 1, true) then
        error("extended compile options require strings without NUL bytes", 3)
    end
    return value .. "\0"
end

local function readResult(memory, address, count, label)
    address %= 2 ^ 32
    count %= 2 ^ 32
    if (count > 0 and address == 0) or address + count > memory.size() * 65536 then
        error(string.format("invalid %s pointer %#x or byte length %u", label, address, count), 0)
    end
    return memory.read_bytes(address, count)
end

local function execCompile(exports, memory, sourcePtr, sourceLen, opt, dbg, cov)
    local result = exports.ls_compile(sourcePtr, sourceLen, opt, dbg, cov)
    local output = readResult(memory, result, exports.ls_compile_size(), "compiler result")
    local category = exports.ls_diagnostic_field(0)
    local info
    if category ~= 0 then
        info = {
            category = category,
            beginLine = exports.ls_diagnostic_field(1),
            beginColumn = exports.ls_diagnostic_field(2),
            endLine = exports.ls_diagnostic_field(3),
            endColumn = exports.ls_diagnostic_field(4),
            message = readResult(memory, exports.ls_diagnostic_message(),
                exports.ls_diagnostic_message_size(), "diagnostic"),
        }
    end
    return output, info
end

function Compiler.bind(runtime, profileOrOptions)
    local profile, hooks
    if type(profileOrOptions) == "function" then
        profile = profileOrOptions
    elseif type(profileOrOptions) == "table" then
        profile = profileOrOptions.profile
        hooks = if type(profileOrOptions.hooks) == "table" then profileOrOptions.hooks else profileOrOptions
    elseif profileOrOptions ~= nil then
        error("Compiler.bind expected a profile function or options table", 2)
    end
    local status = instanceState[runtime]
    if not status then
        status = {busy = false, failed = false, sourcePtr = 0, sourceCapacity = 0}
        instanceState[runtime] = status
    end

    local exports = runtime.exports()
    local memory = exports.memory
    local getStack = exports.emscripten_stack_get_current
    local restoreStack = exports._emscripten_stack_restore

    local function compile(source, options)
        if status.busy or status.failed then
            error(if status.busy then "Luau compiler call is already in progress" else "Luau compiler instance has failed", 2)
        end
        if hooks and hooks.beforeCompile then
            local nextSource, nextOptions = hooks.beforeCompile(source, options)
            if nextSource ~= nil then source = nextSource end
            if nextOptions ~= nil then options = nextOptions end
        end
        if type(source) ~= "string" or #source >= 2 ^ 32 then
            error("expected Wasm32 source bytes as a string", 2)
        end
        if options ~= nil and type(options) ~= "table" then
            error("compile options must be a table", 2)
        end
        options = options or {}
        local optimization = i32(options.optimizationLevel, 1, "optimizationLevel")
        local debugLevel = i32(options.debugLevel, 1, "debugLevel")
        local coverage = i32(options.coverageLevel, 0, "coverageLevel")
        local extra = options.extra

        local stack = getStack()
        local stage = "allocating source and options"
        status.busy = true

        local ok, bytes, diagnostic
        local sourceLen = #source

        if not extra and not profile then
            local need = sourceLen + 1
            local sourcePtr = status.sourcePtr
            if need > status.sourceCapacity then
                if sourcePtr ~= 0 then exports.free(sourcePtr) end
                local newCap = math.max(need + 1024, status.sourceCapacity * 2)
                sourcePtr = exports.malloc(newCap)
                if sourcePtr == 0 then
                    status.busy = false
                    status.failed = true
                    error(setmetatable({kind = "Host ABI", stage = stage, cause = "malloc returned null for source"}, Failure), 0)
                end
                status.sourcePtr = sourcePtr
                status.sourceCapacity = newCap
            end
            memory.write_bytes(sourcePtr, source)
            memory.write_u8(sourcePtr + sourceLen, 0)
            stage = "executing ls_compile"
            ok, bytes, diagnostic = pcall(execCompile, exports, memory, sourcePtr, sourceLen, optimization, debugLevel, coverage)
            if not ok then
                restoreStack(stack)
                status.busy = false
                status.failed = true
                local kind = if Adapter.isException(bytes) then "C++ exception" else "Compiler execution"
                error(setmetatable({kind = kind, stage = stage, cause = bytes}, Failure), 0)
            end
            if stack ~= getStack() then
                restoreStack(stack)
                status.busy = false
                status.failed = true
                error(setmetatable({kind = "Host ABI", stage = "cleanup", cause = "guest stack pointer changed across compilation"}, Failure), 0)
            end
            runtime.check()
            status.busy = false
            if diagnostic and hooks and hooks.onDiagnostic then hooks.onDiagnostic(diagnostic, source, options) end
            if hooks and hooks.afterCompile then
                local nextBytes = hooks.afterCompile(bytes, diagnostic, source, options)
                if nextBytes ~= nil then bytes = nextBytes end
            end
            return bytes, diagnostic
        end

        local typeInfo, vector, lists
        if extra ~= nil then
            if type(extra) ~= "table" then
                error("extended compile options must be a table", 2)
            end
            typeInfo = i32(extra.typeInfoLevel, 0, "typeInfoLevel")
            vector = {}
            for index, name in {"vectorLib", "vectorCtor", "vectorType"} do
                if extra[name] ~= nil then
                    vector[index] = cString(extra[name])
                end
            end
            lists = {}
            for index, name in {"mutableGlobals", "disabledBuiltins", "userdataTypes"} do
                local values = extra[name]
                if values ~= nil then
                    if type(values) ~= "table" then
                        error("compile option " .. name .. " must be an array of strings", 2)
                    end
                    local encoded = {}
                    local count = 0
                    for position, value in values do
                        if type(position) ~= "number" or position % 1 ~= 0 or position < 1 or position > #values then
                            error("compile option " .. name .. " must be an array of strings", 2)
                        end
                        encoded[position] = cString(value)
                        count += 1
                    end
                    if count ~= #values then
                        error("compile option " .. name .. " must be an array of strings", 2)
                    end
                    lists[index] = encoded
                end
            end
        end

        local owned = {}
        local function alloc(b)
            local address = exports.malloc(math.max(#b, 1))
            if address == 0 then
                error(string.format("malloc returned null for %d bytes", #b), 0)
            end
            owned[#owned + 1] = address
            memory.write_bytes(address, b)
            return address
        end
        local function allocateList(values)
            local words = table.create(#values + 1)
            for index, value in values do
                words[index] = string.pack("<I4", alloc(value) % 2 ^ 32)
            end
            words[#values + 1] = string.pack("<I4", 0)
            return alloc(table.concat(words))
        end

        local started = if profile then os.clock() else 0
        local allocated, compiled, copied
        ok, bytes, diagnostic = pcall(function()
            local sourceAddress = alloc(source)
            local extraAddress
            if extra then
                local words = {string.pack("<i4", typeInfo)}
                for index = 1, 3 do
                    words[#words + 1] = string.pack("<I4", if vector[index] then alloc(vector[index]) % 2 ^ 32 else 0)
                end
                for index = 1, 3 do
                    words[#words + 1] = string.pack("<I4", if lists[index] then allocateList(lists[index]) % 2 ^ 32 else 0)
                end
                extraAddress = alloc(table.concat(words))
            end
            if profile then allocated = os.clock() end
            stage = "executing ls_compile"
            local result
            if extraAddress then
                stage = "executing ls_compile_ex"
                result = exports.ls_compile_ex(sourceAddress, #source, optimization, debugLevel, coverage, extraAddress)
            else
                result = exports.ls_compile(sourceAddress, #source, optimization, debugLevel, coverage)
            end
            if profile then compiled = os.clock() end
            stage = "copying compiler result and diagnostics"
            local output = readResult(memory, result, exports.ls_compile_size(), "compiler result")
            local category = exports.ls_diagnostic_field(0)
            local info
            if category ~= 0 then
                info = {
                    category = category,
                    beginLine = exports.ls_diagnostic_field(1),
                    beginColumn = exports.ls_diagnostic_field(2),
                    endLine = exports.ls_diagnostic_field(3),
                    endColumn = exports.ls_diagnostic_field(4),
                    message = readResult(memory, exports.ls_diagnostic_message(),
                        exports.ls_diagnostic_message_size(), "diagnostic"),
                }
            end
            if profile then copied = os.clock() end
            return output, info
        end)

        local clean, cleanupError = pcall(function()
            if not ok then
                restoreStack(stack)
            end
            for index = #owned, 1, -1 do
                exports.free(owned[index])
            end
            if ok then
                if stack ~= getStack() then
                    restoreStack(stack)
                    error("guest stack pointer changed across compilation", 0)
                end
                runtime.check()
            end
        end)
        status.busy = false
        if not ok then
            status.failed = true
            local kind = if Adapter.isException(bytes) then "C++ exception"
                elseif stage == "executing ls_compile" or stage == "executing ls_compile_ex" then "Compiler execution"
                else "Host ABI"
            error(setmetatable({
                kind = kind, stage = stage, cause = bytes,
                cleanup = if clean then nil else cleanupError,
            }, Failure), 0)
        end
        if not clean then
            status.failed = true
            error(setmetatable({kind = "Host ABI", stage = "cleanup", cause = cleanupError}, Failure), 0)
        end
        if profile then
            profile({
                allocateAndCopy = allocated - started,
                execute = compiled - allocated,
                marshal = copied - compiled,
                cleanup = os.clock() - copied,
            })
        end
        if diagnostic and hooks and hooks.onDiagnostic then hooks.onDiagnostic(diagnostic, source, options) end
        if hooks and hooks.afterCompile then
            local nextBytes = hooks.afterCompile(bytes, diagnostic, source, options)
            if nextBytes ~= nil then bytes = nextBytes end
        end
        return bytes, diagnostic
    end

    local function beginCompile(source, options)
        if status.busy or status.failed then
            error(if status.busy then "Luau compiler call is already in progress" else "Luau compiler instance has failed", 2)
        end
        if type(options) == "table" then
            options = table.clone(options)
            if type(options.extra) == "table" then
                options.extra = table.clone(options.extra)
                for _, name in {"mutableGlobals", "disabledBuiltins", "userdataTypes"} do
                    local value = options.extra[name]
                    if type(value) == "table" then options.extra[name] = table.clone(value) end
                end
            end
        end
        return runtime.beginExecution(compile, source, options)
    end

    return table.freeze({
        compile = compile,
        beginCompile = if runtime.beginExecution then beginCompile else nil,
        registry = runtime.registry,
        gc = runtime.gc,
        metadata = runtime.metadata,
        isDisposed = runtime.isDisposed,
        dispose = function()
            if hooks and hooks.onDispose then pcall(hooks.onDispose) end
            if runtime.dispose then runtime.dispose() end
        end,
    })
end

return table.freeze(Compiler)
