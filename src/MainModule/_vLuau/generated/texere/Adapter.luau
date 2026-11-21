-- Host ABI for the assertions-enabled, fixed-memory Emscripten 3.1.64 build.
local Adapter = {}
local WORD = 2 ^ 32
local STACK_COOKIES = {0x02135467, 0x89bacdfe}
local NULL_COOKIE = 0x63736d65

-- Byte offsets within libc++abi's wasm32 exception header (24 bytes).
local Header = {size = 24, type = 4, destructor = 8, caught = 12, rethrown = 13, adjusted = 16}
local CppException = table.freeze({
    __tostring = function(thrown)
        return string.format("Emscripten C++ exception (object %#x)", thrown.pointer)
    end,
})

local INVOKES = {
    "v", "vi", "vii", "viii", "viiii", "viiiii", "viiiiii", "viiiiiiii",
    "viiiiiiiii", "viiiiiiiiiiii", "viiidd", "ii", "iii", "iiii", "iiiii",
    "iiiiii", "iiiiiii", "iiiiiiii", "iid", "vij", "iij", "jiiiii",
    "iiijiii", "iiijii", "iiiij", "viiiiij", "iiiiiiiji",
}

function Adapter.isException(value)
    return type(value) == "table" and getmetatable(value) == CppException
end

function Adapter.instantiate(factory, options)
    options = options or {}
    local state = "linking"
    local exports, memory, functions, getFunction, rawTargets, rawSigs
    local getStack, restoreStack, setThrew
    local stackCookie
    local activeException
    local uncaught = 0
    local catches = {}
    local owner = {}
    local pending = {"", ""}
    local callGuest = pcall
    local raiseTrap = function(reason) error("wasm trap: " .. reason, 0) end

    local function requireMemory()
        if not memory then
            error("Emscripten host ABI: the exported memory is unavailable during Wasm instantiation", 0)
        end
        return memory
    end

    local function readWord(address)
        return (string.unpack("<I4", requireMemory().read_bytes(address, 4)))
    end

    local function writeWord(address, value)
        requireMemory().write_bytes(address, string.pack("<I4", value % WORD))
    end

    local function readCString(address)
        address %= WORD
        if address == 0 then
            return ""
        end
        local heap = requireMemory()
        local limit = heap.size() * 65536
        local chunks = {}
        while address < limit do
            local bytes = heap.read_bytes(address, math.min(256, limit - address))
            local terminator = string.find(bytes, "\0", 1, true)
            chunks[#chunks + 1] = if terminator then string.sub(bytes, 1, terminator - 1) else bytes
            if terminator then
                return table.concat(chunks)
            end
            address += #bytes
        end
        error("Emscripten host ABI: unterminated C string", 0)
    end

    local custom = if factory.compose and (options.plugins or options.extensions or options.globals
        or options.importOverrides or options.resolveImport or options.hooks or options.gc or options.registry)
        then factory.compose(options) else nil
    local hooks = custom and custom.hooks or options.hooks

    local function abort(message)
        state = "failed"
        if hooks and hooks.onAbort then pcall(hooks.onAbort, message, state) end
        error("Emscripten abort: " .. message, 0)
    end

    local function emit(fd, message)
        local sink = if fd == 1 then options.stdout else options.stderr
        if sink then
            sink(message)
        end
    end

    local function writeStream(fd, bytes)
        local start = 1
        while true do
            local stop = string.find(bytes, "[%z\n]", start)
            if not stop then
                pending[fd] ..= string.sub(bytes, start)
                return
            end
            emit(fd, pending[fd] .. string.sub(bytes, start, stop - 1))
            pending[fd] = ""
            start = stop + 1
        end
    end

    local function newException(pointer)
        return table.freeze(setmetatable({pointer = pointer % WORD, owner = owner}, CppException))
    end

    local function findCatch(...)
        if not activeException then
            exports._emscripten_tempret_set(0)
            return 0
        end
        local pointer = activeException.pointer
        local header = pointer - Header.size
        local adjusted = header + Header.adjusted
        writeWord(adjusted, pointer)
        local rtti = readWord(header + Header.type)
        if rtti ~= 0 then
            for index = 1, select("#", ...) do
                local candidate = select(index, ...) % WORD
                if candidate == 0 or candidate == rtti then break end
                if exports.__cxa_can_catch(candidate, rtti, adjusted) ~= 0 then
                    rtti = candidate
                    break
                end
            end
        end
        exports._emscripten_tempret_set(rtti)
        return pointer
    end

    local env = {
        __cxa_throw = function(pointer, rtti, destructor)
            local exception = newException(pointer)
            local header = exception.pointer - Header.size
            writeWord(header + Header.type, rtti)
            writeWord(header + Header.destructor, destructor)
            writeWord(header + Header.adjusted, 0)
            activeException = exception
            uncaught += 1
            if hooks and hooks.onException then pcall(hooks.onException, exception, rtti, destructor) end
            error(exception, 0)
        end,
        __cxa_begin_catch = function(pointer)
            pointer %= WORD
            local header = pointer - Header.size
            if requireMemory().read_u8(header + Header.caught) == 0 then
                requireMemory().write_u8(header + Header.caught, 1)
                uncaught -= 1
            end
            requireMemory().write_u8(header + Header.rethrown, 0)
            catches[#catches + 1] = if activeException and activeException.pointer == pointer
                then activeException else newException(pointer)
            exports.__cxa_increment_exception_refcount(pointer)
            if exports.__cxa_is_pointer_type(readWord(header + Header.type)) ~= 0 then
                return readWord(pointer)
            end
            local adjusted = readWord(header + Header.adjusted)
            return if adjusted ~= 0 then adjusted else pointer
        end,
        __cxa_end_catch = function()
            exports.setThrew(0, 0)
            local caught = table.remove(catches)
            if not caught then
                error("Emscripten exception ABI: catch stack is empty", 0)
            end
            exports.__cxa_decrement_exception_refcount(caught.pointer)
            activeException = nil
        end,
        __cxa_rethrow = function()
            local caught = catches[#catches]
            if not caught then abort("no exception to rethrow") end
            local header = caught.pointer - Header.size
            local heap = requireMemory()
            if heap.read_u8(header + Header.rethrown) == 0 then
                heap.write_u8(header + Header.rethrown, 1)
                heap.write_u8(header + Header.caught, 0)
                uncaught += 1
            else
                table.remove(catches)
            end
            activeException = caught
            error(caught, 0)
        end,
        __cxa_find_matching_catch_2 = findCatch,
        __cxa_find_matching_catch_3 = findCatch,
        __cxa_find_matching_catch_4 = findCatch,
        __cxa_find_matching_catch_5 = findCatch,
        __resumeException = function(pointer)
            activeException = activeException or newException(pointer)
            error(activeException, 0)
        end,
        llvm_eh_typeid_for = function(rtti) return rtti end,
        _abort_js = function() abort("native code called abort()") end,
        __assert_fail = function(condition, file, line, context)
            abort(string.format("assertion %q failed at %s:%d in %s",
                readCString(condition), readCString(file), line % WORD, readCString(context)))
        end,
        _emscripten_memcpy_js = function(dest, source, count)
            requireMemory().copy(dest, source, count)
        end,
        emscripten_resize_heap = function(request)
            abort(string.format("cannot grow the fixed %d-byte heap to %d bytes",
                requireMemory().size() * 65536, request % WORD))
        end,
    }

    local function invokeTarget(index, ...)
        local target = getFunction(index)
        if not target then
            raiseTrap("null function reference")
        end
        return target.call(...)
    end

    for _, signature in INVOKES do
        local legalized = string.find(signature, "j", 1, true) ~= nil
        local returnsValue = string.sub(signature, 1, 1) ~= "v"
        local fast = not legalized and not string.find(signature, "[^iv]")
        local expectedSig = if fast then (string.sub(signature, 2) .. ">" .. (if returnsValue then "i" else "")) else nil
        env["invoke_" .. signature] = function(index, ...)
            if not exports then
                error("Emscripten host ABI: invoke_" .. signature .. " requires linked Wasm exports", 0)
            end
            local stack = getStack()
            local ok, result
            if legalized then
                -- The guest trampoline owns word pairing and the secondary result register.
                local trampoline = exports["dynCall_" .. signature]
                if not trampoline then
                    error("Emscripten host ABI: missing dynCall_" .. signature, 0)
                end
                ok, result = callGuest(trampoline, index, ...)
            elseif fast then
                local target = if rawSigs and rawSigs[index] == expectedSig then rawTargets[index] else nil
                if target then
                    ok, result = callGuest(target, ...)
                else
                    ok, result = callGuest(invokeTarget, index, ...)
                end
            else
                ok, result = callGuest(invokeTarget, index, ...)
            end
            if not ok then
                restoreStack(stack)
                if not Adapter.isException(result) or result.owner ~= owner then
                    error(result, 0)
                end
                setThrew(1, 0)
                result = 0
            end
            if returnsValue then
                return result
            end
        end
    end

    local imports = {
        env = env,
        wasi_snapshot_preview1 = {
            fd_close = function() abort("fd_close requires filesystem support") end,
            fd_seek = function() return 70 end, -- ESPIPE for non-seekable streams, independent of offset.
            fd_write = function(fd, iov, count, written)
                if fd ~= 1 and fd ~= 2 then
                    abort("fd_write requires stdout or stderr")
                end
                iov %= WORD
                count %= WORD
                local heap = requireMemory()
                local capacity = heap.size() * 65536
                if iov + count * 8 > capacity or written % WORD + 4 > capacity then
                    error("Emscripten host ABI: fd_write iovec or result pointer is outside memory", 0)
                end
                local total = 0
                for entry = iov, iov + (count - 1) * 8, 8 do
                    local bytes = heap.read_bytes(readWord(entry), readWord(entry + 4))
                    writeStream(fd, bytes)
                    total += #bytes
                end
                writeWord(written, total)
                return 0
            end,
        },
    }

    if type(options.imports) == "table" then
        for namespace, group in options.imports do
            if type(group) == "table" then
                local dest = imports[namespace]
                if type(dest) ~= "table" then
                    dest = {}
                    imports[namespace] = dest
                end
                for name, callback in group do
                    dest[name] = callback
                end
            end
        end
    end

    if options.trace then
        for namespace, group in imports do
            for name, callback in group do
                local qualified = namespace .. "." .. name
                group[name] = function(...)
                    options.trace(qualified, state)
                    return callback(...)
                end
            end
        end
    end

    local instance = if custom then factory.instantiate(imports, custom) else factory.instantiate(imports)
    exports = instance.exports
    getStack = exports.emscripten_stack_get_current
    restoreStack = exports._emscripten_stack_restore
    setThrew = exports.setThrew
    local beginTask
    if options.resumable then
        assert(instance.beginTask and instance.protectedGuestCall, "expected a resumable Texere factory")
        callGuest = instance.protectedGuestCall
        raiseTrap = instance.raiseTrap or raiseTrap
        beginTask = instance.beginTask
    end
    memory = exports.memory
    functions = exports.__indirect_function_table
    if not memory or not functions then
        error("Emscripten host ABI: expected memory and __indirect_function_table exports", 0)
    end
    getFunction = functions.get
    local tableMeta = rawget(functions, "__texere_v1")
    if type(tableMeta) == "table" and tableMeta.kind == "table" then
        local backing = tableMeta.backing
        rawTargets = backing.targets
        rawSigs = backing.signatures
    end
    state = "linked"

    local function checkCookies()
        if readWord(0) ~= NULL_COOKIE then
            abort("heap cookie at address zero was overwritten")
        end
        for index, value in STACK_COOKIES do
            if readWord(stackCookie + (index - 1) * 4) ~= value then
                abort(string.format("stack cookie was overwritten at %#x", stackCookie))
            end
        end
    end

    local function ready()
        if state ~= "ready" then
            error("Emscripten runtime is " .. state .. "; expected ready", 0)
        end
        return exports
    end

    local function initialize()
        if state ~= "linked" then
            error("Emscripten runtime is " .. state .. "; expected linked", 0)
        end
        state = "initializing"
        local ok, problem = pcall(function()
            exports.emscripten_stack_init()
            stackCookie = exports.emscripten_stack_get_end() % WORD
            if stackCookie % 4 ~= 0 then
                error("unaligned stack limit", 0)
            end
            stackCookie = math.max(stackCookie, 4)
            writeWord(0, NULL_COOKIE)
            for index, value in STACK_COOKIES do
                writeWord(stackCookie + (index - 1) * 4, value)
            end
            exports.__wasm_call_ctors()
            checkCookies()
        end)
        if not ok then
            state = "failed"
            error("Emscripten initialization failure: " .. tostring(problem), 0)
        end
        state = "ready"
    end

    return table.freeze({
        initialize = initialize,
        beginInitialize = if beginTask then function() return beginTask(initialize) end else nil,
        beginExecution = if beginTask then function(target, ...)
            ready()
            return beginTask(target, ...)
        end else nil,
        exports = ready,
        registry = instance.registry,
        gc = instance.gc,
        customGlobals = instance.customGlobals,
        metadata = factory.metadata,
        dispose = function()
            if state == "disposed" then return end
            state = "disposed"
            if instance.dispose then instance.dispose() end
        end,
        isDisposed = function()
            return state == "disposed" or (instance.isDisposed and instance.isDisposed()) or false
        end,
        getMemoryStats = function()
            return {
                capacityBytes = if memory then memory.size() * 65536 else 0,
                committedBytes = if memory and memory.committed_bytes then memory.committed_bytes() else 0,
            }
        end,
        check = function()
            ready()
            checkCookies()
            if uncaught ~= 0 or #catches ~= 0 then
                error("Emscripten exception ABI: unbalanced exception state at the host boundary", 0)
            end
        end,
        flush = function()
            ready().fflush(0)
            for fd, message in pending do
                if #message > 0 then
                    emit(fd, message)
                    pending[fd] = ""
                end
            end
        end,
    })
end

return table.freeze(Adapter)
