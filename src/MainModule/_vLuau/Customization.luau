-- Composable extension/profile framework and Fiu / LuauCeption compatibility bridges.
local roblox = script ~= nil
local makeCompiler = if roblox then require(script.Parent.compiler.Select) else require("./compiler/Select")

local Customization = {}
local runtimeFactory

function Customization._bindRuntime(fn)
    runtimeFactory = fn
end

local function cloneTable(src)
    if type(src) ~= "table" then
        return src
    end
    local copy = table.clone(src)
    for k, v in copy do
        if type(v) == "table" then
            copy[k] = cloneTable(v)
        end
    end
    return copy
end

local function chainFn(prev, nextFn)
    if nextFn == nil then
        return prev
    end
    assert(type(nextFn) == "function", "expected callback function")
    if prev == nil then
        return nextFn
    end
    return function(...)
        prev(...)
        return nextFn(...)
    end
end

local function chainPipe(prev, nextFn)
    if nextFn == nil then
        return prev
    end
    assert(type(nextFn) == "function", "expected transform function")
    if prev == nil then
        return nextFn
    end
    return function(...)
        local first = prev(...)
        return nextFn(if first ~= nil then first else ...)
    end
end

local function chainFirstNonNil(prev, nextFn)
    if nextFn == nil then
        return prev
    end
    assert(type(nextFn) == "function", "expected handler function")
    if prev == nil then
        return nextFn
    end
    return function(...)
        local res = prev(...)
        if res ~= nil then
            return res
        end
        return nextFn(...)
    end
end

local function appendUnique(dst, items)
    if type(items) ~= "table" then
        return dst
    end
    dst = dst or {}
    local seen = {}
    for _, v in dst do
        seen[v] = true
    end
    for k, v in items do
        local item = if type(k) == "number" then v else (if v then k else nil)
        if item ~= nil and not seen[item] then
            seen[item] = true
            dst[#dst + 1] = item
        end
    end
    return dst
end

local function mergePolicy(a, b)
    if not a then
        return cloneTable(b)
    end
    if not b then
        return cloneTable(a)
    end
    local out = cloneTable(a)
    if b.allow then
        if out.allow then
            local allowed = {}
            local bSet = {}
            for _, v in b.allow do bSet[v] = true end
            for _, v in out.allow do
                if bSet[v] then
                    allowed[#allowed + 1] = v
                end
            end
            out.allow = allowed
        else
            out.allow = cloneTable(b.allow)
        end
    end
    if b.deny then
        out.deny = appendUnique(out.deny, b.deny)
    end
    if b.disallowGlobals then
        out.disallowGlobals = appendUnique(out.disallowGlobals, b.disallowGlobals)
    end
    if b.disallowImports then
        out.disallowImports = appendUnique(out.disallowImports, b.disallowImports)
    end
    for _, key in { "maxInstructions", "maxProtos", "maxConstants", "maxStack" } do
        if b[key] ~= nil then
            out[key] = if out[key] ~= nil then math.min(out[key], b[key]) else b[key]
        end
    end
    if b.custom then
        out.custom = chainFirstNonNil(out.custom, b.custom)
    end
    return out
end

local function normalizeOpcodeEntry(entry)
    if type(entry) == "function" then
        return { handler = entry }
    end
    assert(type(entry) == "table", "opcode entry must be a handler function or { before?, after?, handler? } table")
    return {
        before = entry.before,
        after = entry.after,
        handler = entry.handler,
    }
end

local function mergeExtensionInto(acc, ext)
    assert(type(ext) == "table", "expected extension table")
    if ext.name ~= nil then
        acc.names[#acc.names + 1] = tostring(ext.name)
    end
    if type(ext.globals) == "table" then
        for k, v in ext.globals do
            acc.globals[k] = v
        end
    end
    if type(ext.libraries) == "table" then
        for libName, members in ext.libraries do
            if type(members) == "table" then
                local dst = acc.libraries[libName]
                if not dst then
                    dst = {}
                    acc.libraries[libName] = dst
                end
                for member, val in members do
                    dst[member] = val
                end
            end
        end
    end
    if type(ext.behaviors) == "table" then
        for name, fn in ext.behaviors do
            if name == "afterCompile" or name == "onError" then
                acc.behaviors[name] = chainPipe(acc.behaviors[name], fn)
            elseif name == "namecall" then
                acc.behaviors[name] = chainFirstNonNil(acc.behaviors[name], fn)
            else
                acc.behaviors[name] = chainFn(acc.behaviors[name], fn)
            end
        end
    end
    if type(ext.opcodes) == "table" then
        for key, raw in ext.opcodes do
            local nextEntry = normalizeOpcodeEntry(raw)
            local prev = acc.opcodes[key]
            if not prev then
                acc.opcodes[key] = nextEntry
            else
                acc.opcodes[key] = {
                    before = chainFn(prev.before, nextEntry.before),
                    after = chainFn(prev.after, nextEntry.after),
                    handler = nextEntry.handler or prev.handler,
                }
            end
        end
    end
    if type(ext.customOpcodes) == "table" then
        for id, spec in ext.customOpcodes do
            acc.customOpcodes[id] = spec
        end
    end
    if ext.decodeOp ~= nil then
        acc.decodeOp = chainPipe(acc.decodeOp, ext.decodeOp)
    end
    if ext.bytecodePolicy ~= nil then
        acc.bytecodePolicy = mergePolicy(acc.bytecodePolicy, ext.bytecodePolicy)
    end
    if type(ext.bytecodeHooks) == "table" then
        for name, fn in ext.bytecodeHooks do
            acc.bytecodeHooks[name] = if name == "beforeDecode"
                then chainPipe(acc.bytecodeHooks[name], fn)
                else chainFn(acc.bytecodeHooks[name], fn)
        end
    end
    if ext.registry ~= nil then
        acc.registry = ext.registry
    end
    if type(ext.registries) == "table" then
        for k, v in ext.registries do
            acc.registries[k] = v
        end
    end
    if type(ext.gc) == "table" then
        for k, v in ext.gc do
            if type(v) == "function" and (k == "onAllocate" or k == "onFinalize" or k == "onPressure" or k == "onLimitExceeded") then
                acc.gc[k] = chainFn(acc.gc[k], v)
            else
                acc.gc[k] = v
            end
        end
    end
    if type(ext.compiler) == "table" then
        for k, v in ext.compiler do
            if k == "plugins" or k == "extensions" then
                acc.compiler.plugins = acc.compiler.plugins or {}
                for _, p in v do
                    table.insert(acc.compiler.plugins, p)
                end
            elseif k == "hooks" and type(v) == "table" then
                acc.compiler.hooks = acc.compiler.hooks or {}
                for hn, hf in v do
                    acc.compiler.hooks[hn] = chainFn(acc.compiler.hooks[hn], hf)
                end
            elseif type(v) == "table" then
                acc.compiler[k] = acc.compiler[k] or {}
                for sk, sv in v do
                    acc.compiler[k][sk] = sv
                end
            else
                acc.compiler[k] = v
            end
        end
    end
    if type(ext.setup) == "function" then
        acc.setup = chainFn(acc.setup, ext.setup)
    end
end

local Extension = {}

function Extension.define(spec)
    assert(type(spec) == "table", "Extension.define expects a specification table")
    local copy = table.clone(spec)
    copy.__isExtension = true
    return table.freeze(copy)
end

function Extension.global(name, valueOrDescriptor)
    assert(type(name) == "string" and #name > 0, "Extension.global expects a non-empty global name")
    return Extension.define({
        name = "global:" .. name,
        globals = { [name] = valueOrDescriptor },
    })
end

function Extension.compose(...)
    local acc = {
        name = nil,
        names = {},
        globals = {},
        libraries = {},
        behaviors = {},
        opcodes = {},
        customOpcodes = {},
        decodeOp = nil,
        bytecodePolicy = nil,
        bytecodeHooks = {},
        registry = nil,
        registries = {},
        gc = {},
        compiler = {},
        setup = nil,
    }
    local list = { ... }
    if #list == 1 and type(list[1]) == "table" and list[1][1] ~= nil and not list[1].__isExtension then
        list = list[1]
    end
    for _, ext in list do
        mergeExtensionInto(acc, ext)
    end
    acc.name = if #acc.names > 0 then table.concat(acc.names, "+") else "composed"
    acc.__isExtension = true
    return table.freeze(acc)
end

local function mergeOptions(base, override)
    local out = cloneTable(base or {})
    if type(override) ~= "table" then
        return out
    end
    for k, v in override do
        if k == "extensions" then
            local merged = if type(out.extensions) == "table" then table.clone(out.extensions) else {}
            for _, ext in v do
                merged[#merged + 1] = ext
            end
            out.extensions = merged
        elseif k == "bytecodePolicy" then
            out.bytecodePolicy = mergePolicy(out.bytecodePolicy, v)
        elseif type(v) == "table" and type(out[k]) == "table" and (k == "globals" or k == "environment"
            or k == "limits" or k == "compile" or k == "compiler" or k == "registries" or k == "libraries"
            or k == "customOpcodes" or k == "opcodes" or k == "behaviors" or k == "bytecodeHooks" or k == "gc") then
            for sk, sv in v do
                out[k][sk] = sv
            end
        else
            out[k] = v
        end
    end
    return out
end

function Customization.createProfile(baseConfig)
    assert(baseConfig == nil or type(baseConfig) == "table", "createProfile expects a config table")
    local base = cloneTable(baseConfig or {})
    local profile = { config = table.freeze(base) }
    function profile:extend(override)
        return Customization.createProfile(mergeOptions(base, override))
    end
    function profile:createRuntime(extraOptions)
        assert(runtimeFactory ~= nil, "LuauSquared runtime factory is not initialized yet")
        return runtimeFactory(mergeOptions(base, extraOptions))
    end
    return table.freeze(profile)
end

local Compat = {}

function Compat.fromFiuOptions(fiuOpts)
    assert(fiuOpts == nil or type(fiuOpts) == "table", "fromFiuOptions expects a table")
    local opts = fiuOpts or {}
    local out = {}
    for _, key in {
        "instructionLimit", "limits", "onError", "safeEnvironment", "sourceCompilation",
        "compile", "namecall", "userdataMetatables", "libraries", "behaviors", "extensions",
        "compiler", "bytecodePolicy", "bytecodeHooks", "customOpcodes", "registry", "registries",
    } do
        if opts[key] ~= nil then
            out[key] = opts[key]
        end
    end
    if opts.env ~= nil then
        out.environment = opts.env
    elseif opts.environment ~= nil then
        out.environment = opts.environment
    end
    if opts.globals ~= nil then
        out.globals = opts.globals
    end
    if opts.decodeOp ~= nil then
        out.decodeOp = opts.decodeOp
    end
    if opts.opcodeHandlers ~= nil then
        out.opcodes = opts.opcodeHandlers
    elseif opts.opcodes ~= nil then
        out.opcodes = opts.opcodes
    end
    if type(opts.gc) == "function" then
        out.gc = { collect = opts.gc, exposeToGuest = true }
    elseif type(opts.gc) == "table" then
        out.gc = cloneTable(opts.gc)
    end
    if type(opts.collectgarbage) == "function" then
        out.gc = out.gc or {}
        out.gc.guestCollectGarbage = opts.collectgarbage
        out.gc.exposeToGuest = true
    end
    return out
end

function Compat.createFiuLoader(runtimeOptions)
    assert(runtimeFactory ~= nil, "LuauSquared runtime factory is not initialized yet")
    local baseOpts = Compat.fromFiuOptions(runtimeOptions)
    local defaultVm = runtimeFactory(baseOpts)

    local function resolveVm(settings)
        if settings == nil then
            return defaultVm
        end
        return runtimeFactory(mergeOptions(baseOpts, Compat.fromFiuOptions(settings)))
    end

    local loader = { runtime = defaultVm }
    function loader.luau_load(bytecode, env, settings, chunkName)
        local vm = resolveVm(settings)
        return vm:loadBytecode(bytecode, chunkName or "=(fiu)", env)
    end
    function loader.luau_execute(sourceOrBytes, env, settings, ...)
        local vm = resolveVm(settings)
        local chunk
        if string.byte(sourceOrBytes, 1) ~= nil and string.byte(sourceOrBytes, 1) <= 15 then
            chunk = vm:loadBytecode(sourceOrBytes, "=(fiu)", env)
        else
            chunk = vm:load(sourceOrBytes, "=(fiu)", nil, env)
        end
        return chunk(...)
    end
    return table.freeze(loader)
end

function Compat.createLuauCeption(runtimeOptions)
    local compiler = makeCompiler(if runtimeOptions then runtimeOptions.compiler else nil)
    local fiu = Compat.createFiuLoader(runtimeOptions)
    return table.freeze({
        compiler = compiler,
        runtime = fiu.runtime,
        luau_compile = function(source, options)
            return compiler.compile(source, options)
        end,
        luau_load = fiu.luau_load,
        luau_execute = fiu.luau_execute,
    })
end

Customization.Extension = table.freeze(Extension)
Customization.Compat = table.freeze(Compat)
Customization._mergePolicy = mergePolicy

return table.freeze(Customization)
