--!native
-- Emscripten 3.1.64 import-based C++ exception ABI, implemented in ordinary Luau.
-- ABI reference: Emscripten library_exceptions.js (MIT, Copyright 2010 The Emscripten Authors).
-- Native libcxxabi retains type matching, reference counting and destructors.
return function(importNames, attach)
    local exports, memory, indirect
    local exceptionLast, uncaught, tempRet = 0, 0, 0
    local caught = {}
    local thrownToken = {}
    local env = {}
    local function setTempRet(value)
        tempRet = value
        exports._emscripten_tempret_set(value)
    end
    local function u32(address) return buffer.readu32(memory(), address) end
    local function put32(address, value) buffer.writeu32(memory(), address, value) end
    local function u8(address) return buffer.readu8(memory(), address) end
    local function put8(address, value) buffer.writeu8(memory(), address, value) end
    local function raise(pointer) error({ token = thrownToken, pointer = pointer }, 0) end
    local function exceptionPointer(pointer)
        if exports.__cxa_is_pointer_type(u32(pointer - 20)) ~= 0 then return u32(pointer) end
        local adjusted = u32(pointer - 8)
        return if adjusted ~= 0 then adjusted else pointer
    end
    function env.__cxa_throw(pointer, kind, destructor)
        put32(pointer - 8, 0)
        put32(pointer - 20, kind)
        put32(pointer - 16, destructor)
        exceptionLast = pointer
        uncaught += 1
        raise(pointer)
    end
    function env.__cxa_begin_catch(pointer)
        if u8(pointer - 12) == 0 then put8(pointer - 12, 1); uncaught -= 1 end
        put8(pointer - 11, 0)
        table.insert(caught, pointer)
        exports.__cxa_increment_exception_refcount(pointer)
        return exceptionPointer(pointer)
    end
    function env.__cxa_end_catch()
        exports.setThrew(0, 0)
        local pointer = assert(table.remove(caught), "compiler exception catch stack underflow")
        exports.__cxa_decrement_exception_refcount(pointer)
        exceptionLast = 0
    end
    function env.__cxa_rethrow()
        local pointer = assert(table.remove(caught), "compiler rethrow without catch")
        if u8(pointer - 11) == 0 then
            table.insert(caught, pointer)
            put8(pointer - 11, 1); put8(pointer - 12, 0); uncaught += 1
        end
        exceptionLast = pointer
        raise(pointer)
    end
    env.__cxa_get_exception_ptr = exceptionPointer
    function env.__cxa_uncaught_exceptions() return uncaught end
    function env.__cxa_current_primary_exception()
        local pointer = caught[#caught] or 0
        if pointer ~= 0 then exports.__cxa_increment_exception_refcount(pointer) end
        return pointer
    end
    function env.__cxa_rethrow_primary_exception(pointer)
        if pointer == 0 then return end
        table.insert(caught, pointer); put8(pointer - 11, 1); env.__cxa_rethrow()
    end
    function env.__resumeException(pointer)
        if exceptionLast == 0 then exceptionLast = pointer end
        raise(exceptionLast)
    end
    function env.llvm_eh_typeid_for(kind) return kind end
    function env.getTempRet0() return tempRet end
    function env.setTempRet0(value) setTempRet(value) end
    function env._abort_js() error("upstream compiler aborted", 0) end
    function env.abort() error("upstream compiler aborted", 0) end
    function env.__assert_fail() error("upstream compiler assertion failed", 0) end
    function env.fd_close() error("compiler attempted to close a file with filesystem disabled", 0) end
    function env.fd_seek() return 70 end -- WASI ESPIPE: these streams cannot seek.
    function env.__cxa_call_unexpected() error("unexpected C++ exception in compiler", 0) end
    function env.emscripten_resize_heap() error("compiler exceeded its fixed memory limit", 0) end
    function env.emscripten_memcpy_big(destination, source, size)
        local mem = memory()
        if not env.checkpoint or size <= 16384 then
            buffer.copy(mem, destination, mem, source, size)
        elseif destination > source and destination < source + size then
            local remaining = size
            while remaining > 0 do
                local count = math.min(16384, remaining)
                remaining -= count
                buffer.copy(mem, destination + remaining, mem, source + remaining, count)
                env.checkpoint(-2)
            end
        else
            for offset = 0, size - 1, 16384 do
                buffer.copy(mem, destination + offset, mem, source + offset, math.min(16384, size-offset))
                env.checkpoint(-2)
            end
        end
        return destination
    end
    env._emscripten_memcpy_js = env.emscripten_memcpy_big
    function env.fd_write(fd, vectors, count, written)
        assert(fd == 1 or fd == 2, "compiler attempted unsupported file access")
        local output, total = {}, 0
        for i = 0, count - 1 do
            local address, size = u32(vectors + i * 8), u32(vectors + i * 8 + 4)
            output[i + 1] = buffer.readstring(memory(), address, size)
            total += size
        end
        put32(written, total)
        local message = table.concat(output)
        if #message > 0 then print(message) end
        return 0
    end
    for _, name in importNames do
        if string.sub(name, 1, 7) == "invoke_" then
            local signature = string.sub(name, 8)
            env[name] = function(index, ...)
                local stack = exports.emscripten_stack_get_current()
                -- Emscripten legalizes i64 arguments into low/high i32 pairs.
                local call = if string.find(signature, "j", 1, true) then exports["dynCall_" .. signature] else indirect
                local ok, r1 = pcall(call, index, ...)
                if ok then return r1 end
                exports._emscripten_stack_restore(stack)
                if type(r1) ~= "table" or r1.token ~= thrownToken then error(r1, 0) end
                exports.setThrew(1, 0)
                return 0
            end
        elseif string.sub(name, 1, 26) == "__cxa_find_matching_catch_" then
            env[name] = function(...)
                local pointer = exceptionLast
                if pointer == 0 then setTempRet(0); return 0 end
                put32(pointer - 8, pointer)
                local thrownType = u32(pointer - 20)
                if thrownType == 0 then setTempRet(0); return pointer end
                for _, caughtType in { ... } do
                    if caughtType == 0 or caughtType == thrownType then break end
                    if exports.__cxa_can_catch(caughtType, thrownType, pointer - 8) ~= 0 then
                        setTempRet(caughtType)
                        return pointer
                    end
                end
                setTempRet(thrownType)
                return pointer
            end
        end
        assert(env[name], `unsupported compiler import {name}`)
    end
    attach(function(instance)
        exports, memory, indirect = instance.exports, instance.memory, instance.indirect
    end)
    return env
end
