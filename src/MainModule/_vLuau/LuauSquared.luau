-- Hand-maintained hybrid interpreter. Native bytecode loading is never used.
local roblox = script ~= nil
local decode = if roblox then require(script.Parent.Bytecode) else require("./Bytecode")
local BytecodeInspect = if roblox then require(script.Parent.BytecodeInspect) else require("./BytecodeInspect")
local Opcodes = if roblox then require(script.Parent.generated.Opcodes) else require("./generated/Opcodes")
local makePrimitives = if roblox then require(script.Parent.generated.Primitives) else require("./generated/Primitives")
local makePatterns = if roblox then require(script.Parent.Patterns) else require("./Patterns")
local Registry = if roblox then require(script.Parent.Registry) else require("./Registry")
local GC = if roblox then require(script.Parent.GC) else require("./GC")
local Customization = if roblox then require(script.Parent.Customization) else require("./Customization")
local O = Opcodes
local Runtime = {}
Runtime.__index = Runtime
local instructionLengths
local defaultPrimitives
local function getDefaultPrimitives()
    if not defaultPrimitives then
        defaultPrimitives = makePrimitives()
    end
    return defaultPrimitives
end

-- The largest limit whose decrements stay exact in a double.
local MAX_INSTRUCTION_LIMIT = 2 ^ 53 - 1

-- Native Lua states can execute on the main thread, where running() returns nil.
-- The private token is never exposed through the guest coroutine library.
local MAIN_THREAD = {}
-- Environment tables the VM would no longer treat as safe (lua_setsafeenv false):
-- getfenv and setfenv mark the table they hand out or install. Imports cached at
-- load are used only while a closure's environment is not in this set.
local unsafeEnvironments = setmetatable({}, { __mode = "k" })
local function currentThread() return coroutine.running() or MAIN_THREAD end

-- Defaults for options.limits. bytecodeBytes and sourceBytes bound what is loaded or
-- compiled (both cost host time outside the budget); stringBytes bounds any string
-- the guest builds; callDepth bounds nested guest calls.
local DEFAULT_LIMITS = {
    bytecodeBytes = 16 * 1024 * 1024, sourceBytes = 128 * 1024,
    stringBytes = 64 * 1024 * 1024, callDepth = 6000,
    bufferBytes = 16 * 1024 * 1024, tableElements = 1000000, hostCalls = 100000,
}

-- Compile levels used when neither the runtime nor the call chooses them.
local DEFAULT_OPTIMIZATION_LEVEL, DEFAULT_DEBUG_LEVEL = 1, 1

-- Luau CLI/Lune provide native vectors; Roblox represents them as Vector3.
local makeVector = if vector then vector.create elseif Vector3 then Vector3.new else nil

-- table.clear preserves capacity. Integer keys outside the array reserve the
-- compiler's hash hint; temporary array values prevent rehash from shrinking it.
local function createTable(array, hash)
    local value = table.create(array, if hash > 0 then true else nil)
    if hash > 0 then
        for index = 1, hash do value[-index] = true end
        table.clear(value)
    end
    return value
end

-- Marks a host (C) function in a logical call stack. It occupies a level, as in
-- the host VM, but has no source position and is left out of tracebacks.
local HOST = {}

-- Luau's luaO_chunkid: how a chunk name is shown in messages and tracebacks.
-- "=name" is used as written, "@name" is a file name, anything else is source
-- text shown as [string "..."].
local CHUNK_ID_SIZE = 256

local function sourceChunkId(text)
    local length = math.min(#string.match(text, "^[^\n\r]*"), CHUNK_ID_SIZE - 16)
    if #text > length then return `[string "{string.sub(text, 1, length)}..."]` end
    return `[string "{text}"]`
end

local function chunkId(name)
    local kind = string.sub(name, 1, 1)
    if kind == "=" then return string.sub(name, 2, CHUNK_ID_SIZE) end
    if kind == "@" then
        if #name <= CHUNK_ID_SIZE then return string.sub(name, 2) end
        return "..." .. string.sub(name, -(CHUNK_ID_SIZE - 4))
    end
    return sourceChunkId(name)
end

-- Source line of the instruction starting at word `pc`, or 0 without line info.
local function lineAt(proto, pc)
    local lineinfo = proto.lineinfo
    if not lineinfo then return 0 end
    return proto.abslineinfo[bit32.rshift(pc - 1, proto.linegaplog2) + 1] + lineinfo[pc]
end

-- Execution budgets are tracked per host thread. A coroutine created while an
-- execution is live inherits it, so coroutines driven by guest code draw from
-- the active budget while independent host threads keep their own.
local function inheritExecution(executions, fn)
    local parent = executions[currentThread()]
    if not parent or type(fn) ~= "function" then return fn end
    return function(...)
        local thread = currentThread()
        if not executions[thread] then executions[thread] = parent end
        return fn(...)
    end
end

-- A guest coroutine body also reports errors with guest positions: it is a
-- protected boundary, like pcall and the outermost entry into guest code. A new
-- thread starts with the environment its creator's thread had when it was made
-- (`environment`, nil for the runtime's own), as lua_newthread copies it.
local function coroutineBody(self, fn, environment)
    if type(fn) ~= "function" then return fn end
    local body = inheritExecution(self._executions, fn)
    return function(...)
        local thread = currentThread()
        self._guestCoroutines[thread] = true
        self._threadEnvs[thread] = environment
        local stack = self._stacks[thread]
        local before = if stack then stack.n else 0
        local results = table.pack(pcall(body, ...))
        self._guestCoroutines[thread] = nil
        self._threadEnvs[thread] = nil
        if results[1] then return table.unpack(results, 2, results.n) end
        error(self:_locate(results[2], before), 0)
    end
end

local function guestCoroutine(self)
    local library = table.clone(coroutine)
    local create, wrap, hostYield, hostResume = coroutine.create, coroutine.wrap, coroutine.yield, coroutine.resume
    library.create = function(fn)
        local thread = create(coroutineBody(self, fn, self:_threadEnvironment(currentThread())))
        self._guestCoroutines[thread] = true
        return thread
    end
    library.resume = function(thread, ...)
        if type(thread) ~= "thread" then
            error(`invalid argument #1 to 'resume' (thread expected, got {typeof(thread)})`, 0)
        end
        local results = table.pack(hostResume(thread, ...))
        if not results[1] and type(results[2]) == "string" then
            local err = results[2]
            err = string.gsub(err, "^runtime error: ", "")
            err = string.gsub(err, "\nstack traceback:.*", "")
            results[2] = err
        end
        return table.unpack(results, 1, results.n)
    end
    library.wrap = function(fn) return wrap(coroutineBody(self, fn, self:_threadEnvironment(currentThread()))) end
    library.yield = function(...)
        local thread = currentThread()
        if not self._guestCoroutines[thread] then
            error("attempt to yield from outside a coroutine", 0)
        end
        return hostYield(...)
    end
    for name, fn in library do
        if fn ~= coroutine[name] then self._hostFunctionOrigins[fn] = coroutine[name] end
    end
    return library
end

-- Builds error/pcall/xpcall/debug for the guest. They locate errors in guest
-- source and walk the guest call stack, which the host functions cannot see.
local function guestDiagnostics(self)
    local hostError, hostPcall, hostXpcall, hostDebug = error, pcall, xpcall, debug
    local env = {}

    -- The host's argument errors, positioned at whoever called `tool`.
    local function argumentError(tool, name, index, text)
        hostError(self:_where(1, tool) .. `invalid argument #{index} to '{name}' ({text})`, 0)
    end
    -- luaL_optinteger: absent or nil gives the default, numeric strings convert.
    local function optionalInteger(tool, name, index, value, default)
        if value == nil then return default end
        local number = tonumber(value)
        if number == nil then argumentError(tool, name, index, `number expected, got {type(value)}`) end
        return number // 1
    end

    env.error = function(message, level)
        level = optionalInteger(env.error, "error", 2, level, 1)
        -- Numbers count as strings here, as in the host (lua_isstring).
        if (type(message) == "string" or type(message) == "number") and level > 0 then
            message = self:_where(level, env.error) .. tostring(message)
        end
        return hostError(message, 0)
    end

    -- How many guest frames the running thread has now; a protected call that fails
    -- with no more than it started with failed inside a host function.
    local function depth()
        local stack = self._stacks[currentThread()]
        return if stack then stack.n else 0
    end

    env.pcall = function(...)
        local before = depth()
        local results = table.pack(hostPcall(...))
        if not results[1] then results[2] = self:_locate(results[2], before) end
        return table.unpack(results, 1, results.n)
    end

    env.xpcall = function(fn, handler, ...)
        if type(handler) ~= "function" then return hostXpcall(fn, handler, ...) end
        local before = depth()
        return hostXpcall(fn, function(err) return handler(self:_locate(err, before)) end, ...)
    end

    -- Mutable environments. A guest closure's environment table is the `env` field
    -- of its record in self._guest, read at every global access. Only guest
    -- closures have one: any other function, the host's included, is treated as a C
    -- function is (it reports the thread's environment and cannot be changed), so
    -- the guest never reaches or alters host environments. The identifiers
    -- getfenv/setfenv are deliberately never named as globals in this module: the
    -- compiler would switch off closure sharing, inlining and builtin folding for it.
    local function threadEnvironment()
        return self:_threadEnvironment(currentThread())
    end

    -- luaL_checkinteger/luaL_optinteger followed by lua_getinfo(level, "f"): the
    -- numeric argument (strings convert, fractions truncate toward zero) names a
    -- level of the logical stack. Values outside int32 convert to a negative level,
    -- as the pinned x86-64 build does. Returns the entry: HOST or a frame.
    local function levelEntry(tool, name, value, optional)
        local level = 1
        if value ~= nil or not optional then
            local number = tonumber(value)
            if number == nil then argumentError(tool, name, 1, `number expected, got {type(value)}`) end
            if number > -2147483649 and number < 2147483648 then
                level = if number >= 0 then number // 1 else -((-number) // 1)
            else
                level = -1
            end
        end
        if level < 0 then argumentError(tool, name, 1, "level must be non-negative") end
        local entry = self:_logicalFrame(level, tool)
        if entry == nil then argumentError(tool, name, 1, "invalid level") end
        return entry
    end

    env.getfenv = function(target)
        local fn = target
        if type(target) ~= "function" then
            local entry = levelEntry(env.getfenv, "getfenv", target, true)
            fn = if entry == HOST then nil else entry.fn
        end
        local record = fn and self._guest[fn]
        local result = if record then record.env else threadEnvironment()
        unsafeEnvironments[result] = true
        return result
    end

    env.setfenv = function(...)
        local target, replacement = ...
        if type(replacement) ~= "table" then
            if select("#", ...) < 2 then
                hostError(self:_where(1, env.setfenv) .. "missing argument #2 to 'setfenv' (table expected)", 0)
            end
            argumentError(env.setfenv, "setfenv", 2, `table expected, got {type(replacement)}`)
        end
        local fn = target
        if type(target) == "function" then unsafeEnvironments[replacement] = true end
        if type(target) ~= "function" then
            local entry = levelEntry(env.setfenv, "setfenv", target, false)
            unsafeEnvironments[replacement] = true
            -- Zero changes the running thread's environment instead of a function's.
            if tonumber(target) == 0 then
                local thread = currentThread()
                while self._iterationParents[thread] do thread = self._iterationParents[thread] end
                self._threadEnvs[thread] = replacement
                return
            end
            fn = if entry == HOST then nil else entry.fn
        end
        local record = fn and self._guest[fn]
        if not record then
            hostError(self:_where(1, env.setfenv) .. "'setfenv' cannot change environment of given object", 0)
        end
        record.env = replacement
        return fn
    end

    local library = {}
    library.traceback = function(...)
        local first = ...
        local thread, offset = currentThread(), 0
        if type(first) == "thread" then thread, offset = first, 1 end
        local message, level = (select(offset + 1, ...)), (select(offset + 2, ...))
        if message ~= nil and type(message) ~= "string" and type(message) ~= "number" then
            argumentError(library.traceback, "traceback", offset + 1, `string expected, got {type(message)}`)
        end
        level = optionalInteger(library.traceback, "traceback", offset + 2, level,
            if thread == currentThread() then 1 else 0)
        if level < 0 then argumentError(library.traceback, "traceback", offset + 2, "level can't be negative") end
        return self:_traceback(thread, message, level, library.traceback)
    end

    library.info = function(...)
        local tool, argumentCount = library.info, select("#", ...)
        local first = ...
        local thread, offset = currentThread(), 0
        if type(first) == "thread" then thread, offset = first, 1 end
        local target, options = (select(offset + 1, ...)), (select(offset + 2, ...))
        local level
        if type(target) == "number" or (type(target) == "string" and tonumber(target) ~= nil) then
            level = tonumber(target) // 1
            if level < 0 then argumentError(tool, "info", offset + 1, "level can't be negative") end
        elseif not (offset == 0 and type(target) == "function") then
            argumentError(tool, "info", offset + 1, "function or level expected")
        end
        if argumentCount < offset + 2 then
            hostError(self:_where(1, tool) .. `missing argument #{offset + 2} to 'info' (string expected)`, 0)
        elseif type(options) == "number" then
            options = tostring(options)
        elseif type(options) ~= "string" then
            argumentError(tool, "info", offset + 2, `string expected, got {type(options)}`)
        end
        local entry, proto, fn
        if level == nil then
            fn = target
            local record = self._guest[fn]
            proto = record and record.proto
        else
            local entries, count = self:_logicalStack(thread, tool)
            if level + 1 > count then return end
            entry = entries[level + 1]
            if entry ~= HOST then proto, fn = entry.proto, entry.fn
            -- Level 0 of the running thread is debug.info itself.
            elseif level == 0 and thread == currentThread() then fn = tool end
        end
        -- Validate here so errors still name the guest's call site. A host Luau
        -- callback has real metadata; absence from _guest does not make it C.
        local seen = {}
        for option in string.gmatch(options, ".") do
            if seen[option] then argumentError(tool, "info", offset + 2, "duplicate option") end
            seen[option] = true
            if not string.find("slnaf", option, 1, true) then
                argumentError(tool, "info", offset + 2, "invalid option")
            end
        end
        local hostInfo = if fn and not proto
            then self._cFunctionInfo[fn] or table.pack(hostDebug.info(self._hostFunctionOrigins[fn] or fn, "slna"))
            else nil
        local results, size = {}, 0
        for option in string.gmatch(options, ".") do
            size += 1
            if option == "s" then
                results[size] = if proto then proto.source elseif hostInfo then hostInfo[1] else "[C]"
            elseif option == "l" then
                -- A running frame has a current line; a bare function only where it is defined.
                results[size] = if entry and proto then lineAt(proto, entry.current) elseif proto then proto.line elseif hostInfo then hostInfo[2] else -1
            elseif option == "n" then
                results[size] = if proto then proto.debugname or "" elseif hostInfo then hostInfo[3] else ""
            elseif option == "f" then
                results[size] = fn
            elseif option == "a" then
                results[size] = if proto then proto.params elseif hostInfo then hostInfo[4] else 0
                size += 1
                results[size] = if proto then proto.vararg elseif hostInfo then hostInfo[5] else true
            else
                argumentError(tool, "info", offset + 2, "invalid option")
            end
        end
        return table.unpack(results, 1, size)
    end
    -- What debug.info reports for them: they are C functions in the host VM.
    for _, name in { "getfenv", "setfenv" } do
        self._cFunctionInfo[env[name]] = table.pack("[C]", -1, name, 0, true)
    end
    self._hostFunctionOrigins[env.error] = error
    self._hostFunctionOrigins[env.pcall] = pcall
    self._hostFunctionOrigins[env.xpcall] = xpcall
    self._hostFunctionOrigins[library.info] = hostDebug.info
    self._hostFunctionOrigins[library.traceback] = hostDebug.traceback
    env.debug = library
    return env
end

-- Library calls do work the instruction counter cannot see: copying, scanning and
-- moving data. The functions below can do far more than their one call suggests, so
-- each is wrapped to charge that work to the running execution (a unit is 128 bytes
-- or 8 elements, about what an interpreted instruction costs the host), and calls
-- that could allocate without bound are refused up front. Costs are computed from
-- the arguments only and never raise: a bad argument is left for the host function
-- to report in its own words.
local BYTES_PER_UNIT = 128
local ELEMENTS_PER_UNIT = 8
-- With a heap limit the instruction budget is handed out in slices so the heap is
-- looked at between them; a single charge this large (about 1 MiB of work) also
-- looks at it, since one operation can allocate far more than a slice's worth.
local HEAP_SLICE = 16384
local HEAP_CHECK_UNITS = 8192

local function meterLibraries(self, env, suppliedMetatables)
    local patterns = makePatterns(self)
    local maxString = self._limits.stringBytes
    local function bytes(count) self:_charge(count // BYTES_PER_UNIT) end
    local function elements(count) self:_charge(count // ELEMENTS_PER_UNIT) end
    local function integer(value)
        local number = tonumber(value)
        if number == nil or number ~= number then return nil end
        return number // 1
    end
    local function wrapAll(library, wrappers)
        if type(library) ~= "table" then return end
        for name, build in wrappers do
            local fn = rawget(library, name)
            if type(fn) == "function" then
                local wrapped = build(fn)
                -- Supplied libraries may inherit methods through __index and
                -- reject writes through __newindex. Install into our own copy.
                rawset(library, name, wrapped)
                self._hostFunctionOrigins[wrapped] = fn
            end
        end
        local meta = suppliedMetatables and suppliedMetatables[library]
        local index = meta and rawget(meta, "__index")
        if index ~= nil then
            -- Inherited functions are wrapped on first lookup. Do not invoke a
            -- custom __index for every possible method during construction.
            meta.__index = function(object, key)
                local fn = if type(index) == "function" then index(object, key) else index[key]
                local build = wrappers[key]
                if build and type(fn) == "function" then
                    local wrapped = build(fn)
                    rawset(object, key, wrapped)
                    self._hostFunctionOrigins[wrapped] = fn
                    return wrapped
                end
                return fn
            end
        end
    end
    -- Charges the whole first argument when it is a string.
    local function subject(fn)
        return function(...)
            local s = ...
            if type(s) == "string" then bytes(#s) end
            return fn(...)
        end
    end
    -- Reserve the remaining subject scan before the host starts, including
    -- failing patterns. Successful early matches keep the conservative charge.
    local function scan(fn)
        return function(...)
            local s, _, init = ...
            if type(s) == "string" then
                local start = integer(init) or 1
                if start < 0 then start = #s + start + 1 end
                bytes(math.max(0, #s - math.max(start, 1) + 1))
            end
            return fn(...)
        end
    end
    -- Bytes a sub/byte call returns: the span i..j of a string of `length` bytes.
    local function span(length, i, j)
        i, j = integer(i) or 1, integer(j) or length
        if i < 0 then i = length + i + 1 end
        if j < 0 then j = length + j + 1 end
        return math.max(0, math.min(j, length) - math.max(i, 1) + 1)
    end
    local function tooLarge() error("resulting string too large") end

    wrapAll(env.string, {
        upper = subject, lower = subject, reverse = subject, split = subject,
        gmatch = function(fn)
            if fn == string.gmatch then return patterns.gmatch end
            return function(...)
                local s = ...
                if type(s) == "string" then bytes(#s) end
                local results = table.pack(fn(...))
                local iterator = results[1]
                if type(iterator) == "function" then
                    -- The host hides its scan cursor. Reserve a full subject
                    -- scan before every step, including the terminal step.
                    local cost = 1 + (if type(s) == "string" then math.ceil(#s / BYTES_PER_UNIT) else 0)
                    local wrapped = function(...)
                        self:_charge(cost)
                        return iterator(...)
                    end
                    self._hostFunctionOrigins[wrapped] = iterator
                    results[1] = wrapped
                end
                return table.unpack(results, 1, results.n)
            end
        end,
        sub = function(fn)
            return function(...)
                local s, i, j = ...
                if type(s) == "string" then bytes(span(#s, i, if j == nil then -1 else j)) end
                return fn(...)
            end
        end,
        byte = function(fn)
            return function(...)
                local s, i, j = ...
                if type(s) == "string" then bytes(span(#s, i or 1, if j == nil then (integer(i) or 1) else j)) end
                return fn(...)
            end
        end,
        rep = function(fn)
            return function(...)
                local s, n = ... -- Luau's rep takes no separator
                n = integer(n)
                if type(s) == "string" and n and n >= 1 then
                    local length = #s * n
                    if length > maxString then tooLarge() end
                    bytes(length)
                end
                return fn(...)
            end
        end,
        format = function(fn)
            return function(...)
                local total = 0
                for index = 1, select("#", ...) do
                    local value = select(index, ...)
                    if type(value) == "string" then total += #value end
                end
                bytes(total)
                return fn(...)
            end
        end,
        find = function(fn) return if fn == string.find then patterns.find else scan(fn) end,
        match = function(fn) return if fn == string.match then patterns.match else scan(fn) end,
        gsub = function(fn)
            if fn == string.gsub then return patterns.gsub end
            return function(...)
                local s, _, replacement = ...
                if type(s) ~= "string" then return fn(...) end
                bytes(#s)
                local arguments = table.pack(...)
                if type(replacement) == "string" then
                    -- Matches never overlap, so references (%0-%9) copy at most #s bytes in all.
                    local _, references = string.gsub(replacement, "%%", "")
                    if (#s + 1) * #replacement + references * #s > maxString then tooLarge() end
                elseif type(replacement) == "function" or type(replacement) == "table" then
                    -- Whatever the replacement returns is appended; stop it growing the result.
                    local total = 0
                    arguments[3] = function(...)
                        local value
                        if type(replacement) == "function" then value = replacement(...) else value = replacement[(...)] end
                        if type(value) == "string" then
                            total += #value
                            if total > maxString then tooLarge() end
                        end
                        return value
                    end
                end
                local results = table.pack(fn(table.unpack(arguments, 1, arguments.n)))
                if type(results[1]) == "string" then bytes(#results[1]) end
                return table.unpack(results, 1, results.n)
            end
        end,
    })

    wrapAll(env.table, {
        create = function(fn)
            return function(...)
                local n = integer((...))
                if n and n > 0 then
                    if n > self._limits.tableElements then error("table allocation limit exceeded", 0) end
                    elements(n)
                    if self._gcTracksAlloc then self.gc:notifyAllocate("table.create", nil, n) end
                end
                return fn(...)
            end
        end,
        move = function(fn)
            return function(...)
                local source, first, last, target, destination = ...
                local function index(value)
                    local n = tonumber(value)
                    if not n or n ~= n or n <= -2147483649 or n >= 2147483648 then return nil end
                    return if n < 0 then math.ceil(n) else math.floor(n)
                end
                first, last, target = index(first), index(last), index(target)
                destination = if destination == nil then source else destination
                if fn == table.move and type(source) == "table" and type(destination) == "table"
                    and first and last and target and last - first + 1 > self._limits.tableElements then
                    -- Preserve native integer-range and allocation diagnostics,
                    -- then move only present integer keys. Snapshot before clearing
                    -- the destination so overlapping moves retain their source.
                    if first <= 0 and last >= 2147483647 + first then
                        error("invalid argument #3 to 'move' (too many elements to move)", 0)
                    end
                    local count = last - first + 1
                    if target > 2147483647 - count + 1 then
                        error("invalid argument #4 to 'move' (destination wrap around)", 0)
                    end
                    if table.isfrozen(destination) then error("attempt to modify a readonly table", 0) end
                    if target > 0 and target <= rawlen(destination) + 1 and target - 1 + count > 67108864 then
                        error("table overflow", 0)
                    end
                    local saved, keys, work = {}, {}, 0
                    local function tick()
                        work += 1
                        if work == ELEMENTS_PER_UNIT then work = 0; self:_charge(1) end
                    end
                    for key, value in next, source do
                        tick()
                        if type(key) == "number" and key % 1 == 0 and key >= first and key <= last then
                            if #keys >= self._limits.tableElements then error("table allocation limit exceeded", 0) end
                            keys[#keys + 1] = key
                            saved[key] = value
                        end
                    end
                    local ending = target + count - 1
                    for key in next, destination do
                        tick()
                        if type(key) == "number" and key % 1 == 0 and key >= target and key <= ending then
                            rawset(destination, key, nil)
                        end
                    end
                    for _, key in keys do tick(); rawset(destination, key - first + target, saved[key]) end
                    return destination
                end
                if first and last and last >= first then elements(last - first + 1) end
                return fn(...)
            end
        end,
        unpack = function(fn)
            return function(...)
                local t, i, j = ...
                i = integer(i) or 1
                j = integer(j) or (if type(t) == "table" then rawlen(t) else 0)
                if j >= i then elements(j - i + 1) end
                return fn(...)
            end
        end,
        insert = function(fn)
            return function(...)
                local t, position = ...
                if select("#", ...) == 3 and type(t) == "table" then
                    position = integer(position)
                    if position then elements(math.max(0, rawlen(t) - position + 1)) end
                end
                return fn(...)
            end
        end,
        remove = function(fn)
            return function(...)
                local t, position = ...
                if select("#", ...) >= 2 and type(t) == "table" then
                    position = integer(position)
                    if position then elements(math.max(0, rawlen(t) - position + 1)) end
                end
                return fn(...)
            end
        end,
        concat = function(fn)
            return function(...)
                local t, _, i, j = ...
                if type(t) == "table" then elements(math.max(0, (integer(j) or rawlen(t)) - (integer(i) or 1) + 1)) end
                return fn(...)
            end
        end,
        sort = function(fn)
            return function(...)
                local t = ...
                if type(t) == "table" then
                    local n = rawlen(t)
                    if n > 1 then elements(n * (math.floor(math.log(n, 2)) + 1)) end
                end
                return fn(...)
            end
        end,
        clone = function(fn)
            return function(...)
                local t = ...
                if type(t) == "table" then elements(rawlen(t)) end
                return fn(...)
            end
        end,
        clear = function(fn)
            return function(...)
                local t = ...
                if type(t) == "table" then elements(rawlen(t)) end
                return fn(...)
            end
        end,
        find = function(fn)
            return function(...)
                local t, _, init = ...
                local result = fn(...)
                if type(t) == "table" then
                    local start = integer(init) or 1
                    elements(math.max(0, (if result ~= nil then result else rawlen(t)) - start + 1))
                end
                return result
            end
        end,
    })

    wrapAll(env.buffer, {
        create = function(fn)
            return function(...)
                local size = integer((...))
                if size and size > 0 then
                    if size > self._limits.bufferBytes then error("buffer allocation limit exceeded", 0) end
                    bytes(size)
                    if self._gcTracksAlloc then self.gc:notifyAllocate("buffer", nil, size) end
                end
                return fn(...)
            end
        end,
        fill = function(fn)
            return function(...)
                local target, offset, _, count = ...
                count = integer(count)
                if count == nil and type(target) == "buffer" then count = buffer.len(target) - (integer(offset) or 0) end
                if count and count > 0 then bytes(count) end
                return fn(...)
            end
        end,
        copy = function(fn)
            return function(...)
                local _, _, source, sourceOffset, count = ...
                count = integer(count)
                if count == nil and type(source) == "buffer" then count = buffer.len(source) - (integer(sourceOffset) or 0) end
                if count and count > 0 then bytes(count) end
                return fn(...)
            end
        end,
    })

    wrapAll(env.utf8, { len = subject, codepoint = subject, offset = subject, codes = subject })
end

-- Strings resolve methods through a per-runtime metatable whose __index is the
-- guest's own `string` library, so `s:sub()` and `string.sub(s)` agree and guest
-- overrides never reach the host's string library. Where the host hides its
-- string metatable (Roblox returns a "locked" string), the guest sees the same
-- value and extends the string library through `string` instead.
local function defaultEnvironment(self, stringMetatable)
    local exposesStringMetatable = type(getmetatable("")) == "table"
    local env = {
        assert = assert,
        type = type, typeof = typeof, tonumber = tonumber, tostring = tostring,
        select = select, next = next, pairs = pairs, ipairs = ipairs,
        rawequal = rawequal, rawget = rawget, rawset = rawset, rawlen = rawlen,
        setmetatable = setmetatable,
        -- Varargs keep the host's arity check: getmetatable() must still raise.
        getmetatable = function(...)
            if exposesStringMetatable and type((...)) == "string" then return stringMetatable end
            return getmetatable(...)
        end,
        print = print,
    }
    for name, library in { math = math, string = string, table = table,
        bit32 = bit32, utf8 = utf8, buffer = buffer, os = os, vector = vector, integer = integer } do
        env[name] = table.clone(library)
    end
    if newproxy then
        env.newproxy = function(...)
            local object = newproxy(...)
            local meta = getmetatable(object)
            if meta then self._userdataMetatables[object] = meta end
            return object
        end
        self._hostFunctionOrigins[env.newproxy] = newproxy
    end
    meterLibraries(self, env)
    self._hostFunctionOrigins[env.getmetatable] = getmetatable
    env.unpack = env.table.unpack
    env.coroutine = guestCoroutine(self)
    for name, value in guestDiagnostics(self) do env[name] = value end
    env._G = env
    return env
end

local function escapePattern(text)
    return (string.gsub(text, "%p", "%%%0"))
end

local METERED_LIBRARIES = { string = true, table = true, buffer = true, utf8 = true }
local function copySuppliedLibrary(library)
    -- clone handles frozen tables and preserves readable metatable lookup.
    local ok, copy = pcall(table.clone, library)
    if ok then
        local meta = getmetatable(copy)
        local localMeta
        if type(meta) == "table" then
            -- Guest writes stay local even when the source forwards or rejects
            -- them. Do not mutate the host's shared metatable to remove its hook.
            localMeta = {}
            for key, value in next, meta do
                if key ~= "__newindex" then localMeta[key] = value end
            end
            setmetatable(copy, localMeta)
        end
        return copy, localMeta
    end
    -- A protected metatable cannot be cloned or recovered in ordinary Luau.
    -- Keep raw fields local and delegate missing-key reads to the host table;
    -- retain its protection token without mistaking it for the actual table.
    copy = {}
    for key, value in next, library do copy[key] = value end
    local localMeta = {
        __index = function(_, key) return library[key] end,
        __metatable = getmetatable(library),
    }
    return setmetatable(copy, localMeta), localMeta
end

-- options.instructionLimit: instructions one entry into guest code may run.
-- options.environment: extra globals. options.limits: { bytecodeBytes, sourceBytes,
-- stringBytes, callDepth }. options.sourceCompilation: false omits the compiler. options.compile: default { optimizationLevel, debugLevel } (0-2) for
-- compile/load/execute. options.onError(message, traceback): called for an
-- error that leaves an entry into guest code, while the guest stack is intact.
-- options.limits.heapBytes: optional. Ends an entry ("memory limit exceeded") when the
-- host Lua heap, as collectgarbage("count") reports it, has grown by more than this
-- many bytes above the lowest size seen since the entry began. The measure is the whole host heap, garbage
-- included, not only this guest's: it is a backstop against retained allocations,
-- checked every few thousand instructions and after each large allocation (so one
-- allocation can overshoot it), not an accounting. Where the host lets scripts
-- collect, a collection runs before the check fails. Off by default.
-- options.safeEnvironment: true mirrors lua_setsafeenv for the runtime's environment.
-- Imports (global reads the compiler resolved to constant paths, like math.floor)
-- are resolved once when code is loaded and used afterwards unless getfenv or
-- setfenv has handed out or installed the closure's environment, so later changes
-- to the environment table do not reach code that already loaded. Default false:
-- every import reads the live environment.
-- options.userdataMetatables: host-owned userdata -> actual metatable, retained
-- before applying __metatable protection; enables dispatch through hidden handlers.
local DESCRIPTOR_KEYS = {
    value = true, get = true, set = true, readOnly = true,
    mutable = true, disableBuiltin = true, hidden = true, __descriptor = true,
}

local function isGlobalDescriptor(candidate)
    if type(candidate) ~= "table" then
        return false
    end
    if rawget(candidate, "__descriptor") == true then
        return true
    end
    local count = 0
    for k in candidate do
        if not DESCRIPTOR_KEYS[k] then
            return false
        end
        count += 1
    end
    if count == 0 then
        return false
    end
    local g, s = rawget(candidate, "get"), rawget(candidate, "set")
    if g ~= nil and type(g) ~= "function" then return false end
    if s ~= nil and type(s) ~= "function" then return false end
    for _, bkey in { "readOnly", "mutable", "disableBuiltin", "hidden" } do
        local bv = rawget(candidate, bkey)
        if bv ~= nil and type(bv) ~= "boolean" then
            return false
        end
    end
    return true
end

local function appendUniqueString(list, item)
    for _, existing in list do
        if existing == item then
            return
        end
    end
    list[#list + 1] = item
end

local function resolveOpcodeKey(opNameOrId, customOpcodes)
    if type(opNameOrId) == "number" then
        return opNameOrId
    end
    assert(type(opNameOrId) == "string", "expected opcode name or numeric opcode id")
    if opNameOrId == "*" then
        return "*"
    end
    if O[opNameOrId] ~= nil then
        return O[opNameOrId]
    end
    local upper = string.upper(opNameOrId)
    if O[upper] ~= nil then
        return O[upper]
    end
    if customOpcodes then
        for id, spec in customOpcodes do
            if type(spec) == "table" and spec.name == opNameOrId then
                return id
            end
        end
    end
    error(`unknown opcode '{opNameOrId}'`, 2)
end

function Runtime.new(options)
    options = options or {}
    local limit = if options.instructionLimit == nil then 1000000 else options.instructionLimit
    assert(type(limit) == "number" and limit >= 1 and limit <= MAX_INSTRUCTION_LIMIT and limit % 1 == 0,
        `instructionLimit must be an integer from 1 to {MAX_INSTRUCTION_LIMIT}`)
    local compileOptions = table.clone(options.compile or {})
    for name,value in compileOptions do if type(value)=='table' then compileOptions[name]=table.clone(value) end end
    for _, name in { "optimizationLevel", "debugLevel" } do
        local level = compileOptions[name]
        assert(level == nil or (type(level) == "number" and level % 1 == 0 and level >= 0 and level <= 2),
            `compile.{name} must be 0, 1 or 2`)
    end
    if compileOptions.optimizationLevel==nil then compileOptions.optimizationLevel=DEFAULT_OPTIMIZATION_LEVEL end
    if compileOptions.debugLevel==nil then compileOptions.debugLevel=DEFAULT_DEBUG_LEVEL end
    assert(options.onError == nil or type(options.onError) == "function", "onError must be a function")
    assert(options.namecall == nil or type(options.namecall) == "function", "namecall must be a function")
    assert(options.safeEnvironment == nil or type(options.safeEnvironment) == "boolean", "safeEnvironment must be a boolean")
    assert(options.userdataMetatables == nil or type(options.userdataMetatables) == "table", "userdataMetatables must be a table")
    local limits = table.clone(DEFAULT_LIMITS)
    for name, value in options.limits or {} do
        assert(DEFAULT_LIMITS[name] ~= nil or name == "heapBytes", `unknown limit {name}`)
        assert(type(value) == "number" and value >= 1 and value % 1 == 0 and value <= MAX_INSTRUCTION_LIMIT,
            `limits.{name} must be a positive integer`)
        limits[name] = value
    end
    local primitives = options.primitives or getDefaultPrimitives()
    if not instructionLengths then
        local lengths = {}
        for opcode in O.names do lengths[opcode] = primitives.ls_oplength(opcode) end
        instructionLengths = table.freeze(lengths)
    end
    local weak = { __mode = "k" }
    -- Luau's weak keys are not ephemerons: a value that reaches its own key keeps the
    -- entry alive. A closure record holds captured cells that can hold the closure
    -- itself (a recursive local function), so _guest must not hold records strongly.
    -- The closure keeps its record alive; the entry lives exactly as long as it does.
    local weakPairs = { __mode = "kv" }
    local stringMetatable = {}
    local userDataMetatables = setmetatable({}, weakPairs)
    local cFunctionInfo = setmetatable({}, weak)
    local hostFunctionOrigins = setmetatable({}, weak)
    local mainRegistry = if Registry.isRegistry(options.registry)
        then options.registry
        else Registry.new(if type(options.registry) == "table" then options.registry else nil)
    local registries = {
        general = mainRegistry,
        metatables = Registry.newMetatableRegistry(userDataMetatables),
        functions = Registry.newFunctionRegistry(cFunctionInfo, hostFunctionOrigins),
    }
    if type(options.registries) == "table" then
        for name, reg in options.registries do
            registries[name] = reg
        end
    end
    local gcConfig = if type(options.gc) == "table" and type(options.gc.track) ~= "function" then options.gc else nil
    local self = setmetatable({
        _primitives = primitives, _limit = limit, _limits = limits, _onError = options.onError,
        _namecall = options.namecall,
        _sourceCompilation = options.sourceCompilation ~= false,
        _safeEnvironment = options.safeEnvironment == true,
        _heapKB = if limits.heapBytes then limits.heapBytes / 1024 else nil,
        _executions = setmetatable({}, weak), _stacks = setmetatable({}, weak), _guest = setmetatable({}, weakPairs),
        _guestCoroutines = setmetatable({}, weak),
        -- Environment of the code running on a thread (setfenv(0, ...)); absent
        -- means the runtime's own. And what debug.info says about runtime C-like functions.
        _threadEnvs = setmetatable({}, weak), _cFunctionInfo = cFunctionInfo,
        _hostIterators = setmetatable({}, weak),
        _iterationParents = setmetatable({}, weakPairs),
        _hostFunctionOrigins = hostFunctionOrigins,
        -- A userdata holds its actual metatable; weak values avoid retaining an
        -- otherwise unreachable object through a handler that closes over it.
        _userdataMetatables = userDataMetatables,
        _stringMetatable = stringMetatable,
        _compileOptions = compileOptions,
        _compilerConfig = if type(options.compiler) == "table" then table.clone(options.compiler) else nil,
        _globalDescriptors = {},
        _hasGlobalDescriptors = false,
        _behaviors = { namecall = options.namecall },
        _opHooks = {},
        _hasOpHooks = false,
        _customOpcodeHandlers = {},
        _hasCustomOpcodeHandlers = false,
        _customOpcodes = nil,
        _decodeOp = options.decodeOp,
        _bytecodePolicy = if options.bytecodePolicy then table.clone(options.bytecodePolicy) else nil,
        _bytecodeHooks = if type(options.bytecodeHooks) == "table" then table.clone(options.bytecodeHooks) else {},
        _extensions = {},
        _disposed = false,
        _gcConfig = gcConfig,
        _gcTracksAlloc = gcConfig ~= nil and (gcConfig.trackAllocations == true or gcConfig.onAllocate ~= nil),
        _gcManagesBudget = gcConfig ~= nil and (
            gcConfig.getMemoryKB ~= nil or gcConfig.collect ~= nil or gcConfig.step ~= nil
            or gcConfig.softLimitBytes ~= nil or gcConfig.hardLimitBytes ~= nil
            or gcConfig.onPressure ~= nil or gcConfig.onLimitExceeded ~= nil
        ),
        registry = mainRegistry,
        registries = registries,
    }, Runtime)
    self.gc = if options.gc and type(options.gc.track) == "function" then options.gc else GC.new(gcConfig, self)
    -- Hosts that own a userdata's real metatable can retain it before locking
    -- it. Ordinary Luau cannot recover it from an arbitrary __metatable value.
    for object, metatable in options.userdataMetatables or {} do
        assert(type(object) == "userdata" and type(metatable) == "table", "userdataMetatables must map userdata to metatable tables")
        self._userdataMetatables[object] = metatable
    end
    -- Messages raised by this module's own code carry its source position; these
    -- patterns recognize them so they can be reported at the guest position.
    self._hostPatterns = {}
    local hostSources = { debug.info(1, "s"), debug.info(primitives.ls_add, "s"), debug.info(makePatterns, "s") }
    for index, source in hostSources do
        if table.find(hostSources, source) == index then
            table.insert(self._hostPatterns, "^" .. escapePattern(source) .. ":%d+: ")
        end
    end
    local env = defaultEnvironment(self, stringMetatable)
    if options.environment then
        for key, value in options.environment do
            if METERED_LIBRARIES[key] and type(value) == "table" then
                local library, meta = copySuppliedLibrary(value)
                env[key] = library
                meterLibraries(self, { [key] = library }, { [library] = meta })
            else
                env[key] = value
            end
        end
    end
    if gcConfig and (gcConfig.exposeToGuest == true or type(gcConfig.guestCollectGarbage) == "function") then
        env.collectgarbage = self.gc:makeGuestCollectGarbage()
    end
    stringMetatable.__index = env.string
    self.environment = env

    if type(options.libraries) == "table" then
        for libName, additions in options.libraries do
            self:extendLibrary(libName, additions)
        end
    end
    if type(options.behaviors) == "table" then
        for bName, fn in options.behaviors do
            self:defineBehavior(bName, fn)
        end
    end
    if type(options.customOpcodes) == "table" then
        for id, spec in options.customOpcodes do
            self:registerCustomOpcode(id, spec)
        end
    end
    if type(options.opcodes) == "table" then
        for opKey, entry in options.opcodes do
            if type(entry) == "table" and entry.handler ~= nil and entry.before == nil and entry.after == nil then
                self:registerOpcodeHandler(opKey, entry.handler)
            else
                self:onOpcode(opKey, entry)
                if type(entry) == "table" and type(entry.handler) == "function" then
                    self:registerOpcodeHandler(opKey, entry.handler)
                end
            end
        end
    end
    if type(options.globals) == "table" then
        self:defineGlobals(options.globals)
    end
    if type(options.extensions) == "table" then
        for _, ext in options.extensions do
            self:use(ext)
        end
    end
    return self
end

function Runtime:defineGlobal(name, valueOrDescriptor)
    assert(type(name) == "string" and #name > 0, "global name must be a non-empty string")
    assert(not self._disposed, "LuauSquared runtime has been disposed")
    if isGlobalDescriptor(valueOrDescriptor) then
        local desc = table.clone(valueOrDescriptor)
        self._globalDescriptors[name] = desc
        self._hasGlobalDescriptors = true
        if desc.value ~= nil then
            self.environment[name] = desc.value
        elseif desc.hidden then
            self.environment[name] = nil
        end
        if desc.mutable or desc.get ~= nil or desc.set ~= nil then
            self._compileOptions.mutableGlobals = self._compileOptions.mutableGlobals or {}
            appendUniqueString(self._compileOptions.mutableGlobals, name)
        end
        if desc.disableBuiltin then
            self._compileOptions.disabledBuiltins = self._compileOptions.disabledBuiltins or {}
            appendUniqueString(self._compileOptions.disabledBuiltins, name)
        end
    else
        self._globalDescriptors[name] = nil
        self.environment[name] = valueOrDescriptor
        local any = false
        for _ in self._globalDescriptors do
            any = true
            break
        end
        self._hasGlobalDescriptors = any
    end
    return self
end

function Runtime:defineGlobals(map)
    assert(type(map) == "table", "defineGlobals expects a table")
    for name, valueOrDescriptor in map do
        self:defineGlobal(name, valueOrDescriptor)
    end
    return self
end

function Runtime:removeGlobal(name)
    assert(type(name) == "string", "removeGlobal expects a string name")
    self._globalDescriptors[name] = nil
    self.environment[name] = nil
    local any = false
    for _ in self._globalDescriptors do
        any = true
        break
    end
    self._hasGlobalDescriptors = any
    return self
end

function Runtime:getGlobalDescriptor(name)
    return self._globalDescriptors[name]
end

function Runtime:extendLibrary(libName, additions)
    assert(type(libName) == "string" and type(additions) == "table", "extendLibrary(libName, additions) expects string and table")
    local target = self.environment[libName]
    if type(target) ~= "table" then
        target = {}
        self.environment[libName] = target
    end
    for k, v in additions do
        target[k] = v
    end
    return self
end

function Runtime:defineBehavior(name, fn)
    assert(type(name) == "string", "defineBehavior expects a behavior name")
    assert(fn == nil or type(fn) == "function", "defineBehavior expects a function or nil")
    self._behaviors[name] = fn
    if name == "namecall" then
        self._namecall = fn
    elseif name == "onError" then
        self._onError = fn
    end
    return self
end

function Runtime:setBytecodePolicy(policy)
    assert(policy == nil or type(policy) == "table", "bytecodePolicy must be a table or nil")
    self._bytecodePolicy = if policy then table.clone(policy) else nil
    return self
end

function Runtime:getBytecodePolicy()
    return self._bytecodePolicy
end

function Runtime:onOpcode(opNameOrId, hook)
    local key = resolveOpcodeKey(opNameOrId, self._customOpcodes)
    self._opHooks[key] = hook
    local any = false
    for _ in self._opHooks do
        any = true
        break
    end
    self._hasOpHooks = any
    return self
end

function Runtime:registerOpcodeHandler(opNameOrId, handler)
    local key = resolveOpcodeKey(opNameOrId, self._customOpcodes)
    assert(handler == nil or type(handler) == "function", "opcode handler must be a function or nil")
    self._customOpcodeHandlers[key] = handler
    local any = false
    for _ in self._customOpcodeHandlers do
        any = true
        break
    end
    self._hasCustomOpcodeHandlers = any
    return self
end

function Runtime:registerCustomOpcode(id, spec)
    assert(type(id) == "number" and id >= 0 and id <= 255 and id % 1 == 0, "custom opcode id must be integer 0..255")
    assert(type(spec) == "table", "custom opcode spec must be a table")
    self._customOpcodes = self._customOpcodes or {}
    self._customOpcodes[id] = table.clone(spec)
    if type(spec.handler) == "function" then
        self:registerOpcodeHandler(id, spec.handler)
    end
    return self
end

function Runtime:_decodeContext()
    return {
        opcodes = O,
        oplength = self._primitives.ls_oplength,
        maxBytes = self._limits.bytecodeBytes,
        vector = makeVector,
        integer = integer,
        customOpcodes = self._customOpcodes,
        decodeOp = self._decodeOp,
        decode = decode.decode or decode,
    }
end

function Runtime:inspectBytecode(bytes)
    assert(type(bytes) == "string", "inspectBytecode expects a bytecode string")
    return BytecodeInspect.inspect(bytes, self:_decodeContext())
end

function Runtime:inspectSource(source, compileOptions)
    local bytes = self:compile(source, compileOptions, false)
    return self:inspectBytecode(bytes), bytes
end

function Runtime:checkBytecode(bytes, policy)
    assert(type(bytes) == "string", "checkBytecode expects a bytecode string")
    return BytecodeInspect.check(bytes, policy or self._bytecodePolicy, self:_decodeContext())
end

function Runtime:inspectFunction(guestFn)
    local record = if type(guestFn) == "function" then self._guest[guestFn] else nil
    assert(record ~= nil, "inspectFunction expects a guest function of this runtime")
    return BytecodeInspect.inspect(record.program, self:_decodeContext())
end

function Runtime:use(extension)
    assert(type(extension) == "table" or type(extension) == "function", "use() expects an extension table or setup function")
    assert(not self._disposed, "LuauSquared runtime has been disposed")
    if type(extension) == "function" then
        self._extensions[#self._extensions + 1] = { name = "fn", setup = extension }
        extension(self)
        return self
    end
    self._extensions[#self._extensions + 1] = extension
    if type(extension.customOpcodes) == "table" then
        for id, spec in extension.customOpcodes do
            self:registerCustomOpcode(id, spec)
        end
    end
    if type(extension.decodeOp) == "function" then
        local prev = self._decodeOp
        local nextFn = extension.decodeOp
        self._decodeOp = if prev then function(...)
            local a = prev(...)
            return nextFn(if a ~= nil then a else ...)
        end else nextFn
    end
    if type(extension.libraries) == "table" then
        for libName, additions in extension.libraries do
            self:extendLibrary(libName, additions)
        end
    end
    if type(extension.globals) == "table" then
        self:defineGlobals(extension.globals)
    end
    if type(extension.behaviors) == "table" then
        for bName, fn in extension.behaviors do
            local prev = self._behaviors[bName]
            if prev and fn then
                if bName == "afterCompile" or bName == "onError" then
                    self:defineBehavior(bName, function(...)
                        local r1 = prev(...)
                        return fn(if r1 ~= nil then r1 else ...)
                    end)
                elseif bName == "namecall" then
                    self:defineBehavior(bName, function(...)
                        local r1 = prev(...)
                        if r1 ~= nil then return r1 end
                        return fn(...)
                    end)
                else
                    self:defineBehavior(bName, function(...)
                        prev(...)
                        return fn(...)
                    end)
                end
            else
                self:defineBehavior(bName, fn)
            end
        end
    end
    if type(extension.opcodes) == "table" then
        for opKey, entry in extension.opcodes do
            if type(entry) == "table" and entry.handler ~= nil and entry.before == nil and entry.after == nil then
                self:registerOpcodeHandler(opKey, entry.handler)
            else
                self:onOpcode(opKey, entry)
                if type(entry) == "table" and type(entry.handler) == "function" then
                    self:registerOpcodeHandler(opKey, entry.handler)
                end
            end
        end
    end
    if extension.bytecodePolicy then
        self._bytecodePolicy = Customization._mergePolicy(self._bytecodePolicy, extension.bytecodePolicy)
    end
    if type(extension.bytecodeHooks) == "table" then
        for hName, fn in extension.bytecodeHooks do
            local prev = self._bytecodeHooks[hName]
            if prev and fn then
                self._bytecodeHooks[hName] = function(...)
                    prev(...)
                    return fn(...)
                end
            else
                self._bytecodeHooks[hName] = fn
            end
        end
    end
    if type(extension.registries) == "table" then
        for rName, reg in extension.registries do
            self.registries[rName] = reg
        end
    end
    if type(extension.gc) == "table" then
        self._gcConfig = self._gcConfig or {}
        for gk, gv in extension.gc do
            self._gcConfig[gk] = gv
        end
        self.gc = GC.new(self._gcConfig, self)
        self._gcTracksAlloc = self._gcConfig.trackAllocations == true or self._gcConfig.onAllocate ~= nil
        self._gcManagesBudget = self._gcConfig.getMemoryKB ~= nil or self._gcConfig.collect ~= nil or self._gcConfig.step ~= nil
            or self._gcConfig.softLimitBytes ~= nil or self._gcConfig.hardLimitBytes ~= nil
            or self._gcConfig.onPressure ~= nil or self._gcConfig.onLimitExceeded ~= nil
        if self._gcConfig.exposeToGuest == true or type(self._gcConfig.guestCollectGarbage) == "function" then
            self.environment.collectgarbage = self.gc:makeGuestCollectGarbage()
        end
    end
    if type(extension.compiler) == "table" then
        self._compilerConfig = self._compilerConfig or {}
        for ck, cv in extension.compiler do
            self._compilerConfig[ck] = cv
        end
        self._compiler = nil
    end
    if type(extension.setup) == "function" then
        extension.setup(self)
    end
    return self
end

function Runtime:getExtensions()
    return table.clone(self._extensions)
end

function Runtime:isDisposed()
    return self._disposed
end

function Runtime:dispose()
    if self._disposed then
        return
    end
    self._disposed = true
    if self._behaviors.onDispose then
        pcall(self._behaviors.onDispose, self)
    end
    if self._compiler and self._compiler.dispose then
        pcall(self._compiler.dispose)
    end
    self._compiler = nil
    if self.gc and self.gc.dispose then
        self.gc:dispose()
    end
    table.clear(self._executions)
    table.clear(self._stacks)
end

local function fields(word)
    local a = bit32.band(bit32.rshift(word, 8), 255)
    local b = bit32.band(bit32.rshift(word, 16), 255)
    local c = bit32.rshift(word, 24)
    local d = bit32.rshift(word, 16)
    if d >= 32768 then d -= 65536 end
    return bit32.band(word, 255), a, b, c, d
end

-- Every call into guest code passes through here. A call made while a live
-- execution owns the current thread (a callback, metamethod, or coroutine driven
-- by guest code) shares that execution's budget; any other call starts a new
-- execution with a full budget, including calls to closures a previous
-- execution returned. That outermost entry is also where an error leaves guest
-- code: it is located in guest source and offered to options.onError.
-- Returns the guest function and its record: the captured cells at 0..n-1 (filled by
-- the caller), the prototype, and the environment table in `env` (changed by
-- setfenv; every global access reads it).
function Runtime:_closure(program, proto, environment)
    local executions, stacks = self._executions, self._stacks
    local wrapper
    local upvalues = { env = environment, proto = program.protos[proto], program = program, index = proto }
    wrapper = function(...)
        if self._disposed then
            error("LuauSquared runtime has been disposed", 0)
        end
        local thread = currentThread()
        local execution = executions[thread]
        if execution and not execution.done then
            return self:_run(program, proto, upvalues, table.pack(...), execution, wrapper)
        end
        execution = self:_newExecution()
        executions[thread] = execution
        -- Frames left behind by an earlier failed entry are no longer wanted.
        local stack = stacks[thread]
        if stack then stack.n = 0 end
        local results = table.pack(pcall(self._run, self, program, proto, upvalues, table.pack(...), execution, wrapper))
        -- setfenv(0, ...) belongs to this runtime's thread, including later entries
        -- and loads, exactly as in the VM. It never changes the host environment.
        -- Frames that outlive the entry (suspended coroutines) see the negative
        -- balance on resumption and attach to a fresh execution (see _attach).
        execution.done, execution.remaining = true, -1
        if executions[thread] == execution then executions[thread] = nil end
        if not results[1] then
            local err = self:_locate(results[2])
            -- The guest stack is deliberately left in place so a handler further
            -- out (xpcall, onError) can still ask for a traceback.
            local errHandler = self._behaviors.onError or self._onError
            if errHandler then
                local okErr, override = pcall(errHandler, err, self:_traceback(thread, nil, 1, nil))
                if okErr and type(override) == "string" then
                    err = override
                end
            end
            error(err, 0)
        end
        return table.unpack(results, 2, results.n)
    end
    self._guest[wrapper] = upvalues
    return wrapper, upvalues
end

-- Spends `units` of the running execution's budget on work the host does for the
-- guest (a library call's copying or scanning). Outside an execution, nothing.
function Runtime:_charge(units)
    if not (units > 0) then return end
    local execution = self._executions[currentThread()]
    if not execution or execution.done then return end
    local remaining = execution.remaining - units
    if remaining >= 0 then execution.remaining = remaining
    else self:_refill(execution, -remaining) end
    if units >= HEAP_CHECK_UNITS and execution.heapBase then self:_checkHeap(execution) end
end

-- The budget an entry starts with. Without a heap limit it is one slice, so the
-- instruction counter is all there is; with one, slices of HEAP_SLICE instructions
-- come out of `reserve` and each refill is a point where the heap is checked.
function Runtime:_newExecution()
    local limit = self._limit
    if self._heapKB == nil and not self._gcManagesBudget then
        return { remaining = limit, reserve = 0, hostCalls = 0, done = false }
    end
    local slice = math.min(limit, HEAP_SLICE)
    return {
        remaining = slice,
        reserve = limit - slice,
        hostCalls = 0,
        done = false,
        heapBase = if self._heapKB then collectgarbage("count") else nil,
        gcActive = self._gcManagesBudget,
    }
end

-- `deficit` is how far the slice went below zero. Takes the next slice (at least
-- the deficit) from the reserve, or ends the entry when the budget is spent.
function Runtime:_refill(execution, deficit)
    local reserve = execution.reserve
    local take = math.max(math.min(reserve, HEAP_SLICE), deficit)
    if take > reserve then
        execution.remaining = -deficit
        error("LuauSquared instruction limit exceeded", 0)
    end
    execution.reserve = reserve - take
    execution.remaining = take - deficit
    if execution.gcActive and not self.gc:isPaused() then
        self.gc:step(take)
        self.gc:checkPressure(nil)
    end
    if execution.heapBase then self:_checkHeap(execution) end
end

-- Ends the entry when the host heap has grown by more than limits.heapBytes above
-- the lowest size seen since it began (a collection of older garbage during the
-- entry lowers the starting point instead of hiding what the guest retains).
-- collectgarbage("count") includes garbage, so before failing the collector runs
-- once where the host allows it (Roblox permits only "count").
function Runtime:_checkHeap(execution)
    local limit = self._heapKB
    local used = collectgarbage("count")
    if used < execution.heapBase then execution.heapBase = used return end
    if used - execution.heapBase <= limit then return end
    if self._gcConfig and self._gcConfig.collect then
        pcall(self.gc.collect, self.gc, "pressure")
    else
        pcall(collectgarbage, "collect")
    end
    used = collectgarbage("count")
    if used < execution.heapBase then execution.heapBase = used return end
    if used - execution.heapBase > limit then
        if self._gcConfig and self._gcConfig.onLimitExceeded then
            local handled = self._gcConfig.onLimitExceeded({
                bytes = used * 1024,
                limit = limit * 1024,
                kind = "heap",
            }, self.gc)
            if handled == true then
                return
            end
        end
        error("LuauSquared memory limit exceeded", 0)
    end
end

-- Count explicit calls and iterator/replacement callbacks before host code runs.
function Runtime:_countHostCall(fn)
    if self._guest[fn] then return end
    local execution = self._executions[currentThread()]
    if not execution or execution.done then return end
    execution.hostCalls += 1
    if execution.hostCalls > self._limits.hostCalls then error("host call limit exceeded", 0) end
end

function Runtime:_threadEnvironment(thread)
    while self._iterationParents[thread] do thread = self._iterationParents[thread] end
    return self._threadEnvs[thread] or self.environment
end

-- A frame resumed after its execution ended continues under the execution now
-- current for its thread, or a new one owned by the thread if there is none.
function Runtime:_attach()
    local thread = currentThread()
    local execution = self._executions[thread]
    if not execution or execution.done then
        execution = self:_newExecution()
        self._executions[thread] = execution
    end
    return execution
end

-- The call stack of `thread` as the host debug library numbers it: entry
-- `level + 1` is the function at `level`. Guest frames come from the thread's
-- frame stack; a host function between two of them (pcall, a sort callback) is
-- inferred from the callee a frame is waiting on. For the running thread, level 0
-- is `tool`, the function that asked. With `limit`, the walk stops once the entry
-- for that level exists.
function Runtime:_logicalStack(thread, tool, limit)
    local entries, count = {}, 0
    if thread == currentThread() then count = 1; entries[1] = HOST end
    local guest = self._guest
    local first = true
    repeat
        local stack = self._stacks[thread]
        if stack then
            for index = stack.n, 1, -1 do
                if limit and count > limit then return entries, count end
                local frame = stack[index]
                local callee = frame.callee
                if callee ~= nil and not guest[callee] and not self._hostIterators[callee]
                    and not (first and index == stack.n and callee == tool) then
                    count += 1; entries[count] = HOST
                end
                count += 1; entries[count] = frame
            end
        end
        first = false
        thread = self._iterationParents[thread]
    until not thread
    return entries, count
end

-- The entry `level` frames up the running thread's logical stack (0 is `tool`, the
-- host function asking), as lua_getinfo finds a function by level: HOST for a host
-- function, a frame for a guest function, nil past the end. The walk is work the
-- instruction counter cannot see, so it is charged.
function Runtime:_logicalFrame(level, tool)
    local entries, count = self:_logicalStack(currentThread(), tool, level)
    self:_charge(count // ELEMENTS_PER_UNIT)
    return entries[level + 1]
end

-- "source:line: " for the function at `level`, or "" when it is a host function,
-- does not exist, or has no line information (the host's luaL_where).
function Runtime:_where(level, tool)
    local entries = self:_logicalStack(currentThread(), tool)
    local entry = entries[level + 1]
    if entry == nil or entry == HOST then return "" end
    local line = lineAt(entry.proto, entry.current)
    if line <= 0 then return "" end
    return `{entry.proto.source}:{line}: `
end

-- Replaces the host source position at the front of an error message with the
-- position of the guest code that was running. Errors raised by host library
-- functions follow luaL_where (no position without line info); errors raised by
-- an operation of the guest function itself always carry one. `before` is the
-- guest depth when a protected call began: if the error arrives with no deeper
-- frames, a host function the guest never entered raised it, and as in the host
-- (where its caller is the C pcall) it has no position at all.
function Runtime:_locate(err, before)
    if type(err) ~= "string" then return err end
    local length
    for _, pattern in self._hostPatterns do
        local _, finish = string.find(err, pattern)
        if finish then length = finish break end
    end
    if not length then return err end
    local stack = self._stacks[currentThread()]
    local frame = stack and stack[stack.n]
    if not frame then return err end
    if before and stack.n <= before then return string.sub(err, length + 1) end
    local proto = frame.proto
    local line = lineAt(proto, frame.current)
    local prefix = if line > 0 or frame.callee == nil then `{proto.source}:{line}: ` else ""
    return prefix .. string.sub(err, length + 1)
end

function Runtime:_traceback(thread, message, level, tool)
    local entries, count = self:_logicalStack(thread, tool)
    local lines, size = {}, 0
    if message ~= nil then size += 1; lines[size] = tostring(message) .. "\n" end
    for index = level + 1, count do
        local entry = entries[index]
        if entry ~= HOST then
            local proto = entry.proto
            local line = lineAt(proto, entry.current)
            size += 1
            lines[size] = proto.source .. (if line > 0 then `:{line}` else "")
                .. (if proto.debugname then ` function {proto.debugname}` else "") .. "\n"
        end
    end
    return table.concat(lines)
end

-- The guest call stack of the running thread in the host's traceback format,
-- for use from a handler while the stack is still in place (xpcall handlers,
-- options.onError). `level` 1 is the innermost guest function.
function Runtime:traceback(message, level)
    return self:_traceback(currentThread(), message, level or 1, nil)
end

-- Hit counts of the COVERAGE instructions in a guest function and the functions
-- nested in it, as lua_getcoverage reports them: an array with one entry per
-- function in definition order (the function itself at depth 0), each
-- { name = debugname or nil, linedefined = line, depth = depth, [line] = hits }.
-- Lines the function has no COVERAGE instruction for are absent and a line with
-- several reports the largest count. The instructions come from the compiler's
-- coverage instrumentation (bytecode compiled with coverageLevel 1 or 2); the
-- runtime's own source compiler does not emit them. Without line information
-- (debug level 0) a function reports no lines.
function Runtime:coverage(fn)
    local record = if type(fn) == "function" then self._guest[fn] else nil
    if not record then error("coverage expects a guest function of this runtime", 2) end
    local program, results = record.program, {}
    local function visit(index, depth)
        local proto = program.protos[index]
        local entry = { name = proto.debugname, linedefined = proto.line, depth = depth }
        if proto.lineinfo then
            local code, pc = proto.code, 1
            while pc <= #code do
                local op = bit32.band(code[pc], 255)
                if op == O.COVERAGE then
                    local line, hits = lineAt(proto, pc), bit32.rshift(code[pc], 8)
                    local previous = entry[line]
                    if previous == nil or previous < hits then entry[line] = hits end
                end
                pc += instructionLengths[op]
            end
        end
        results[#results + 1] = entry
        for child = 0, proto.childCount - 1 do visit(proto.children[child], depth + 1) end
    end
    visit(record.index, 0)
    return results
end

-- Indexes a string the way the VM does: through the string metatable's __index.
function Runtime:_indexString(object, key)
    local handler = rawget(self._stringMetatable, "__index")
    if type(handler) == "function" then return handler(object, key) end
    if handler == nil then error(`attempt to index string with '{key}'`) end
    return handler[key]
end

-- Mirrors FORGPREP for a value that is not already a function. Returns the
-- generator, state and control registers the loop continues with. A nil
-- generator selects builtin traversal of the table left in the state register.
function Runtime:_prepareIteration(value, state, control)
    local kind = type(value)
    if kind == "table" then
        local metatable = getmetatable(value)
        if metatable == nil then return nil, value, nil end
        -- Reassigning the same metatable changes nothing, and the host refuses
        -- it for protected tables. This authenticates a readable metatable
        -- without trusting a table-valued __metatable decoy. Frozen tables use
        -- the host loop below, which does not attempt to change them.
        if type(metatable) == "table" and not table.isfrozen(value) and pcall(setmetatable, value, metatable) then
            local iter = rawget(metatable, "__iter")
            if iter ~= nil then
                self:_countHostCall(iter)
                local generator, nextState, nextControl = iter(value)
                if generator == nil then error("attempt to call a nil value") end
                return generator, nextState, nextControl
            end
            if rawget(metatable, "__call") ~= nil then return value, state, control end
            return nil, value, nil
        end
        -- Even a table-valued result can be an __metatable decoy. The native
        -- loop resolves the actual protocol without inspecting that result.
    elseif kind ~= "userdata" then
        error(`attempt to iterate over a {typeof(value)} value`)
    end
    return self:_hostIterator(value, state, control), state, control
end

-- A private marker separates completed loop steps from yields inside __iter
-- or the generator. Use the compiler's maximum 197 named loop variables (plus
-- its three hidden loop locals); table construction avoids 197 call arguments.
local ITERATION_RESULT = {}
local HOST_ITERATION_VARIABLES = 197
local function hostIterationBody(...)
    for
            v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12,
            v13, v14, v15, v16, v17, v18, v19, v20, v21, v22, v23, v24,
            v25, v26, v27, v28, v29, v30, v31, v32, v33, v34, v35, v36,
            v37, v38, v39, v40, v41, v42, v43, v44, v45, v46, v47, v48,
            v49, v50, v51, v52, v53, v54, v55, v56, v57, v58, v59, v60,
            v61, v62, v63, v64, v65, v66, v67, v68, v69, v70, v71, v72,
            v73, v74, v75, v76, v77, v78, v79, v80, v81, v82, v83, v84,
            v85, v86, v87, v88, v89, v90, v91, v92, v93, v94, v95, v96,
            v97, v98, v99, v100, v101, v102, v103, v104, v105, v106, v107, v108,
            v109, v110, v111, v112, v113, v114, v115, v116, v117, v118, v119, v120,
            v121, v122, v123, v124, v125, v126, v127, v128, v129, v130, v131, v132,
            v133, v134, v135, v136, v137, v138, v139, v140, v141, v142, v143, v144,
            v145, v146, v147, v148, v149, v150, v151, v152, v153, v154, v155, v156,
            v157, v158, v159, v160, v161, v162, v163, v164, v165, v166, v167, v168,
            v169, v170, v171, v172, v173, v174, v175, v176, v177, v178, v179, v180,
            v181, v182, v183, v184, v185, v186, v187, v188, v189, v190, v191, v192,
            v193, v194, v195, v196, v197
    in ... do
        coroutine.yield(ITERATION_RESULT, {
            v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12,
            v13, v14, v15, v16, v17, v18, v19, v20, v21, v22, v23, v24,
            v25, v26, v27, v28, v29, v30, v31, v32, v33, v34, v35, v36,
            v37, v38, v39, v40, v41, v42, v43, v44, v45, v46, v47, v48,
            v49, v50, v51, v52, v53, v54, v55, v56, v57, v58, v59, v60,
            v61, v62, v63, v64, v65, v66, v67, v68, v69, v70, v71, v72,
            v73, v74, v75, v76, v77, v78, v79, v80, v81, v82, v83, v84,
            v85, v86, v87, v88, v89, v90, v91, v92, v93, v94, v95, v96,
            v97, v98, v99, v100, v101, v102, v103, v104, v105, v106, v107, v108,
            v109, v110, v111, v112, v113, v114, v115, v116, v117, v118, v119, v120,
            v121, v122, v123, v124, v125, v126, v127, v128, v129, v130, v131, v132,
            v133, v134, v135, v136, v137, v138, v139, v140, v141, v142, v143, v144,
            v145, v146, v147, v148, v149, v150, v151, v152, v153, v154, v155, v156,
            v157, v158, v159, v160, v161, v162, v163, v164, v165, v166, v167, v168,
            v169, v170, v171, v172, v173, v174, v175, v176, v177, v178, v179, v180,
            v181, v182, v183, v184, v185, v186, v187, v188, v189, v190, v191, v192,
            v193, v194, v195, v196, v197
        })
    end
end

-- The helper thread shares the execution budget. Yields from the generator are
-- relayed to its caller, including nils and values passed back on resume.
function Runtime:_hostIterator(value, state, control)
    local parent = currentThread()
    local thread = coroutine.create(inheritExecution(self._executions, function()
        return hostIterationBody(value, state, control)
    end))
    self._guestCoroutines[thread] = self._guestCoroutines[currentThread()]
    self._threadEnvs[thread] = self._threadEnvs[currentThread()]
    self._iterationParents[thread] = parent
    local generator = function(_, _, variables)
        if variables > HOST_ITERATION_VARIABLES then
            error("unsupported hidden iteration: more than 197 loop variables", 0)
        end
        self._iterationParents[thread] = currentThread()
        self:_countHostCall(value)
        local packed = table.pack(coroutine.resume(thread))
        while true do
            if not packed[1] then error(packed[2], 0) end
            if coroutine.status(thread) == "dead" then
                self._iterationParents[thread], self._threadEnvs[thread], self._guestCoroutines[thread] = nil, nil, nil
                return nil
            end
            if packed[2] == ITERATION_RESULT then
                return table.unpack(packed[3], 1, variables)
            end
            packed = table.pack(coroutine.resume(thread, coroutine.yield(table.unpack(packed, 2, packed.n))))
        end
    end
    self._hostIterators[generator] = true
    return generator
end

function Runtime:_run(program, proto, upvalues, args, execution, fn)
    local p, r, pc, top = program.protos[proto], {}, 1, 0
    local code, k, num = p.code, p.constants, self._primitives
    local imports = p.imports
    local maxString = self._limits.stringBytes
    local baseEnv = self.environment
    local hasGlobalDesc = self._hasGlobalDescriptors
    local globalDescs = if hasGlobalDesc then self._globalDescriptors else nil
    local beh = self._behaviors
    local onGlobalRead, onGlobalWrite = beh.onGlobalRead, beh.onGlobalWrite
    local onIndex, onNewIndex = beh.onIndex, beh.onNewIndex
    local onCall, afterCall = beh.onCall, beh.afterCall
    local hasOpHooks = self._hasOpHooks
    local opHooks = if hasOpHooks then self._opHooks else nil
    local customOpcodes = self._customOpcodes
    local customHandlers = if self._hasCustomOpcodeHandlers then self._customOpcodeHandlers else nil
    local gcAlloc, gc = self._gcTracksAlloc, self.gc
    -- The register table doubles as this call's frame in the thread's guest
    -- stack: tracebacks and error positions read proto, current and callee.
    local thread = currentThread()
    local stack = self._stacks[thread]
    if not stack then stack = { n = 0 }; self._stacks[thread] = stack end
    local depth = stack.n + 1
    if depth > self._limits.callDepth then error("stack overflow") end
    stack.n, stack[depth] = depth, r
    r.proto, r.fn, r.current = p, fn, 1
    -- Only registers captured by reference need shared cells. Ordinary registers
    -- store values directly, avoiding an allocation and indirection per register.
    local cells = {}
    local function cell(index)
        local shared = cells[index]
        if not shared then shared = { value = r[index] }; cells[index] = shared end
        return shared
    end
    local function get(index)
        local shared = cells[index]
        return if shared then shared.value else r[index]
    end
    local function put(index, value)
        local shared = cells[index]
        if shared then shared.value = value else r[index] = value end
    end
    for i = 0, p.params - 1 do put(i, args[i + 1]) end
    local function capture(child, target, template)
        -- A new closure starts with its creator's environment. DUPCLOSURE keeps the
        -- first closure in its constant slot and reuses it when the creator's
        -- environment is that closure's (setfenv may have changed it) and captures
        -- are raw-equal; otherwise the creator gets a fresh closure without replacing
        -- that first cache (the pinned VM's preload/reuse contract).
        local environment = upvalues.env
        if template and template.cached and template.captures.env == environment then
            put(target, template.cached)
            local same = true
            for i = 0, program.protos[child].upvalues - 1 do
                local _, kind, index = fields(code[pc + i])
                local previous = template.captures[i]
                if kind == 0 then
                    same = same and previous.immutable and rawequal(previous.value, get(index))
                elseif kind == 2 then
                    local current = upvalues[index]
                    same = same and (rawequal(previous, current) or
                        (previous.immutable and current.immutable and rawequal(previous.value, current.value)))
                else same = false end
            end
            if same then pc += program.protos[child].upvalues; return template.cached end
        end
        -- Recursive local functions capture their own destination by value.
        -- Install the closure before processing its CAPTURE instructions.
        if not cells[target] then r[target] = nil end
        local closure, values = self:_closure(program, child, environment)
        put(target, closure)
        for i = 0, program.protos[child].upvalues - 1 do
            local op, kind, index = fields(assert(code[pc], "missing CAPTURE"))
            assert(op == O.CAPTURE, "expected CAPTURE")
            if kind == 0 then values[i] = { value = get(index), immutable = true }
            elseif kind == 1 then values[i] = cell(index)
            elseif kind == 2 then values[i] = assert(upvalues[index], "invalid captured upvalue")
            else error(`unsupported capture mode {kind}`, 0) end
            pc += 1
        end
        if template and not template.cached and program.env == environment then
            template.cached, template.captures = closure, values
        end
        return closure
    end
    while true do
        local remaining = execution.remaining - 1
        execution.remaining = remaining
        if remaining < 0 then
            if execution.done then
                execution = self:_attach()
                execution.remaining -= 1
            end
            if execution.remaining < 0 then self:_refill(execution, -execution.remaining) end
        end
        local current = pc
        r.current = current
        local word = assert(code[pc], "instruction pointer outside code")
        local op, a, b, c, d = fields(word)
        pc += 1
        local aux
        local ilen = instructionLengths[op] or (if customOpcodes and customOpcodes[op] then (customOpcodes[op].length or 1) else 1)
        if ilen == 2 then aux = code[pc]; pc += 1 end
        local afterOpHook
        if hasOpHooks then
            local hook = opHooks[op] or opHooks[O.names[op]] or opHooks["*"]
            if hook ~= nil then
                if type(hook) == "function" then
                    hook(op, current, a, b, c, d, aux, p, r)
                elseif type(hook) == "table" then
                    if hook.before then
                        hook.before(op, current, a, b, c, d, aux, p, r)
                    end
                    afterOpHook = hook.after
                end
            end
        end
        if op == O.NOP or op == O.PREPVARARGS then
        elseif op == O.COVERAGE then
            local hits = bit32.rshift(code[current], 8)
            if hits < 0x7FFFFF then code[current] = O.COVERAGE + (hits + 1) * 256 end
        elseif op == O.LOADNIL then put(a, nil)
        elseif op == O.LOADB then put(a, b ~= 0); pc += c
        elseif op == O.LOADN then put(a, d)
        elseif op == O.LOADK then put(a, k[bit32.rshift(code[current], 16)])
        elseif op == O.LOADKX then put(a, k[aux])
        elseif op == O.MOVE then put(a, get(b))
        elseif op == O.GETGLOBAL then
            if not hasGlobalDesc and not onGlobalRead then
                put(a, upvalues.env[k[bit32.band(aux, 0xFFFFFF)]])
            else
                local gname = k[bit32.band(aux, 0xFFFFFF)]
                local envTbl = upvalues.env
                local val
                local desc = if hasGlobalDesc and envTbl == baseEnv then globalDescs[gname] else nil
                if desc then
                    if desc.hidden then
                        val = nil
                    elseif desc.get then
                        val = desc.get(gname, envTbl)
                    else
                        val = envTbl[gname]
                    end
                else
                    val = envTbl[gname]
                end
                if onGlobalRead then
                    local override = onGlobalRead(gname, val, envTbl)
                    if override ~= nil then val = override end
                end
                put(a, val)
            end
        elseif op == O.SETGLOBAL then
            if not hasGlobalDesc and not onGlobalWrite then
                upvalues.env[k[bit32.band(aux, 0xFFFFFF)]] = get(a)
            else
                local gname = k[bit32.band(aux, 0xFFFFFF)]
                local val = get(a)
                local envTbl = upvalues.env
                local desc = if hasGlobalDesc and envTbl == baseEnv then globalDescs[gname] else nil
                if desc and desc.readOnly then
                    error(`attempt to assign read-only global '{gname}'`, 0)
                end
                local proceed = if onGlobalWrite then onGlobalWrite(gname, val, envTbl) else true
                if proceed ~= false then
                    if desc and desc.set then
                        desc.set(val, gname, envTbl)
                    else
                        envTbl[gname] = val
                    end
                end
            end
        elseif op == O.GETUPVAL then put(a, upvalues[b].value)
        elseif op == O.SETUPVAL then upvalues[b].value = get(a)
        elseif op == O.CLOSEUPVALS then
            for i = a, p.stack - 1 do
                local shared = cells[i]
                if shared then r[i], cells[i] = shared.value, nil end
            end
        elseif op == O.GETIMPORT then
            local cached = if imports then imports[d] else nil
            if cached ~= nil and not unsafeEnvironments[upvalues.env] then put(a, cached)
            else
                local count = bit32.rshift(aux, 30)
                local topName = k[bit32.band(bit32.rshift(aux, 20), 1023)]
                local envTbl = upvalues.env
                local value
                if not hasGlobalDesc and not onGlobalRead then
                    value = envTbl[topName]
                else
                    local desc = if hasGlobalDesc and envTbl == baseEnv then globalDescs[topName] else nil
                    if desc then
                        if desc.hidden then value = nil
                        elseif desc.get then value = desc.get(topName, envTbl)
                        else value = envTbl[topName] end
                    else
                        value = envTbl[topName]
                    end
                    if onGlobalRead then
                        local override = onGlobalRead(topName, value, envTbl)
                        if override ~= nil then value = override end
                    end
                end
                if count >= 2 then value = value[k[bit32.band(bit32.rshift(aux, 10), 1023)]] end
                if count >= 3 then value = value[k[bit32.band(aux, 1023)]] end
                put(a, value)
            end
        elseif op == O.GETTABLE then
            local object, key = get(b), get(c)
            local value = if type(object) == "string" then self:_indexString(object, key) else object[key]
            if onIndex then
                local override = onIndex(object, key, value)
                if override ~= nil then value = override end
            end
            put(a, value)
        elseif op == O.SETTABLE then
            local object, key, val = get(b), get(c), get(a)
            if not onNewIndex or onNewIndex(object, key, val) ~= false then
                object[key] = val
            end
        elseif op == O.GETTABLEKS then
            local object = get(b)
            local key = k[bit32.band(aux, 0xFFFFFF)]
            local value
            if type(object) == "string" then value = self:_indexString(object, key)
            elseif type(object) == "vector" and (key == "x" or key == "X") then value = object.X
            elseif type(object) == "vector" and (key == "y" or key == "Y") then value = object.Y
            elseif type(object) == "vector" and (key == "z" or key == "Z") then value = object.Z
            else value = object[key] end
            if onIndex then
                local override = onIndex(object, key, value)
                if override ~= nil then value = override end
            end
            put(a, value)
        elseif op == O.SETTABLEKS then
            local object, key, val = get(b), k[bit32.band(aux, 0xFFFFFF)], get(a)
            if not onNewIndex or onNewIndex(object, key, val) ~= false then
                object[key] = val
            end
        elseif op == O.GETTABLEN then
            local object, key = get(b), c + 1
            local value = if type(object) == "string" then self:_indexString(object, key) else object[key]
            if onIndex then
                local override = onIndex(object, key, value)
                if override ~= nil then value = override end
            end
            put(a, value)
        elseif op == O.SETTABLEN then
            local object, key, val = get(b), c + 1, get(a)
            if not onNewIndex or onNewIndex(object, key, val) ~= false then
                object[key] = val
            end
        elseif op == O.NEWTABLE then
            local hash = if b == 0 then 0 else 2 ^ (b - 1)
            if aux + hash > self._limits.tableElements then error("table allocation limit exceeded", 0) end
            self:_charge((aux + 3 * hash) // ELEMENTS_PER_UNIT)
            if not cells[a] then r[a] = nil end
            local tbl = createTable(aux, hash)
            if gcAlloc then gc:notifyAllocate("table", tbl, aux + hash) end
            put(a, tbl)
        elseif op == O.DUPTABLE then
            local template = k[bit32.rshift(code[current], 16)]
            assert(template.kind == "table", "invalid table constant")
            local values = template.values
            if #template.keys > self._limits.tableElements then error("table allocation limit exceeded", 0) end
            local cost = 3 * #template.keys // ELEMENTS_PER_UNIT
            if cost > 0 then self:_charge(cost) end
            if not cells[a] then r[a] = nil end
            local value = createTable(0, #template.keys)
            for index, key in template.keys do
                local constant = values and values[index]
                value[k[key]] = if constant then k[constant] else 0
            end
            if gcAlloc then gc:notifyAllocate("table", value, #template.keys) end
            put(a, value)
        elseif op == O.SETLIST then
            local count = if c == 0 then top - b else c - 1
            if count < 0 then error("invalid bytecode: SETLIST uses a result count that was never set", 0) end
            for i = 0, count - 1 do get(a)[aux + i] = get(b + i) end
        elseif op == O.NEWCLOSURE then capture(assert(p.children[d], "invalid child prototype"), a)
        elseif op == O.DUPCLOSURE then
            local template = k[bit32.rshift(code[current], 16)]
            assert(template.kind == "closure", "invalid closure constant")
            capture(template.proto, a, template)
        elseif op == O.NAMECALL then
            -- The VM resolves the method here and CALL supplies the arguments.
            -- Strings use the guest string library; a userdata/vector __namecall handler
            -- takes precedence over __index (a Luau handler cannot see the name,
            -- exactly as in the host); everything else is ordinary indexing.
            local object, name = get(b), k[bit32.band(aux, 0xFFFFFF)]
            local kind, method = type(object), nil
            if kind == "string" then
                method = self:_indexString(object, name)
            elseif kind == "userdata" or kind == "vector" then
                if self._namecall then
                    method = function(...) return self._namecall(object, name, select(2, ...)) end
                    self._hostFunctionOrigins[method] = self._namecall
                else
                    local metatable = self._userdataMetatables[object] or getmetatable(object)
                    if type(metatable) == "table" then method = rawget(metatable, "__namecall") end
                    if method == nil then method = object[name] end
                end
            else
                method = object[name]
            end
            if method == nil then
                error(`attempt to call missing method '{name}' of {typeof(object)}`)
            end
            put(a + 1, object); put(a, method)
        elseif op == O.CALL or op == O.CALLFB then
            local count = if b == 0 then top - a - 1 else b - 1
            if count < 0 then error("invalid bytecode: CALL uses an argument count that was never set", 0) end
            local arguments = table.create(count)
            for i = 1, count do arguments[i] = get(a + i) end
            local callee = get(a)
            self:_countHostCall(callee)
            if onCall then onCall(callee, arguments, count) end
            -- While a function is being called its errors are the callee's, not
            -- this instruction's; calling a non-function stays this instruction's.
            if type(callee) == "function" then r.callee = callee end
            local record = self._guest[callee]
            local results
            if record then
                -- The caller already owns the active entry. Enter the guest frame
                -- directly, avoiding a redundant wrapper and a host stack level.
                results = table.pack(self:_run(record.program, record.index, record, table.pack(table.unpack(arguments, 1, count)), execution, callee))
            else results = table.pack(callee(table.unpack(arguments, 1, count))) end
            r.callee = nil
            stack.n = depth
            if afterCall then afterCall(callee, results) end
            local wanted = if c == 0 then results.n else c - 1
            for i = 1, wanted do put(a + i - 1, results[i]) end
            if c == 0 then top = a + wanted end
        elseif op == O.RETURN then
            local count = if b == 0 then top - a else b - 1
            if count < 0 then error("invalid bytecode: RETURN uses a result count that was never set", 0) end
            local results = table.create(count)
            for i = 1, count do results[i] = get(a + i - 1) end
            if afterOpHook then afterOpHook(op, current, a, b, c, d, aux, p, r, results) end
            stack[depth] = nil
            stack.n = depth - 1
            return table.unpack(results, 1, count)
        elseif op == O.GETVARARGS then
            local count = if b == 0 then math.max(0, args.n - p.params) else b - 1
            for i = 1, count do put(a + i - 1, args[p.params + i]) end
            if b == 0 then top = a + count end
        elseif op == O.JUMP or op == O.JUMPBACK then pc = current + 1 + d
        elseif op == O.JUMPX then
            local e = bit32.rshift(code[current], 8)
            if e >= 8388608 then e -= 16777216 end
            pc = current + 1 + e
        elseif op == O.JUMPIF then if get(a) then pc = current + 1 + d end
        elseif op == O.JUMPIFNOT then if not get(a) then pc = current + 1 + d end
        elseif op == O.JUMPIFEQ or op == O.JUMPIFNOTEQ or op == O.JUMPIFLE
            or op == O.JUMPIFNOTLE or op == O.JUMPIFLT or op == O.JUMPIFNOTLT then
            local left, right = get(a), get(bit32.band(aux, 255))
            local test
            if op == O.JUMPIFEQ or op == O.JUMPIFNOTEQ then test = left == right
            elseif op == O.JUMPIFLE or op == O.JUMPIFNOTLE then test = left <= right
            else test = left < right end
            if op == O.JUMPIFNOTEQ or op == O.JUMPIFNOTLE or op == O.JUMPIFNOTLT then test = not test end
            if test then pc = current + 1 + d end
        elseif op == O.JUMPXEQKNIL or op == O.JUMPXEQKB or op == O.JUMPXEQKN or op == O.JUMPXEQKS then
            -- Equality with a constant; bit 31 of the auxiliary word negates the test.
            local value, matches = get(a), nil
            if op == O.JUMPXEQKNIL then matches = value == nil
            elseif op == O.JUMPXEQKB then matches = value == (bit32.band(aux, 1) ~= 0)
            else matches = value == k[bit32.band(aux, 0xFFFFFF)] end
            if matches ~= (bit32.rshift(aux, 31) ~= 0) then pc = current + 1 + d end
        elseif op == O.FASTCALL or op == O.FASTCALL1 or op == O.FASTCALL2
            or op == O.FASTCALL2K or op == O.FASTCALL3 or op == O.FASTPCALL then
            -- Fall through to the ordinary call sequence that follows.
        elseif op == O.CMPPROTO then
            -- Serialized native function identities cannot refer to our closures.
            -- Always use the compiler's ordinary call fallback.
            pc = current + 1 + d
        elseif op == O.FORNPREP or op == O.FORNLOOP then
            local limit, step, index = get(a), get(a + 1), get(a + 2)
            if op == O.FORNPREP then
                local numbers = { tonumber(index), tonumber(limit), tonumber(step) }
                for position, what in { "initial value", "limit", "step" } do
                    if numbers[position] == nil then
                        local value = if position == 1 then index elseif position == 2 then limit else step
                        error(`invalid 'for' {what} (number expected, got {typeof(value)})`)
                    end
                end
                index, limit, step = numbers[1], numbers[2], numbers[3]
                put(a, limit); put(a + 1, step); put(a + 2, index)
            end
            if op == O.FORNLOOP then index += step; put(a + 2, index) end
            local keep = if step > 0 then index <= limit else index >= limit
            if (op == O.FORNPREP and not keep) or (op == O.FORNLOOP and keep) then pc = current + 1 + d end
        elseif op == O.FORGPREP or op == O.FORGPREP_INEXT or op == O.FORGPREP_NEXT then
            local generator = get(a)
            if type(generator) ~= "function" then
                local g, state, control = self:_prepareIteration(generator, get(a + 1), get(a + 2))
                put(a, g); put(a + 1, state); put(a + 2, control)
            end
            pc = current + 1 + d
        elseif op == O.FORGLOOP then
            local generator, variables = get(a), bit32.band(aux, 255)
            if generator == nil then
                -- Builtin traversal: the state register holds the table and the
                -- control register the previous key (nil before the first step).
                local key, value = next(get(a + 1), get(a + 2))
                if key ~= nil then
                    put(a + 2, key); put(a + 3, key)
                    if variables >= 2 then put(a + 4, value) end
                    for i = 2, variables - 1 do put(a + 3 + i, nil) end
                    pc = current + 1 + d
                end
            else
                if type(generator) == "function" then r.callee = generator end
                local results
                if self._hostIterators[generator] then
                    results = table.pack(generator(get(a + 1), get(a + 2), variables))
                else
                    self:_countHostCall(generator)
                    results = table.pack(generator(get(a + 1), get(a + 2)))
                end
                r.callee = nil
                stack.n = depth
                for i = 1, variables do put(a + 2 + i, results[i]) end
                put(a + 2, results[1])
                if results[1] ~= nil then pc = current + 1 + d end
            end
        elseif op == O.CONCAT then
            -- Refuse before building: every operand is a string or number, or has a __concat.
            local total = 0
            for i = b, c do
                local part = get(i)
                if type(part) == "string" then total += #part elseif type(part) == "number" then total += 24 end
            end
            if total > maxString then error("string length overflow") end
            if total >= BYTES_PER_UNIT then self:_charge(total // BYTES_PER_UNIT) end
            -- The VM overwrites the destination before its garbage collection check,
            -- so release the old value before this host allocation can trigger a step.
            if (a < b or a > c) and not cells[a] then r[a] = nil end
            local value = get(c)
            for i = c - 1, b, -1 do value = get(i) .. value end
            if gcAlloc then gc:notifyAllocate("string", value, total) end
            put(a, value)
        elseif op == O.NOT then put(a, not get(b))
        elseif op == O.MINUS then put(a, -get(b))
        elseif op == O.LENGTH then put(a, #get(b))
        elseif op == O.AND then put(a, get(b) and get(c))
        elseif op == O.OR then put(a, get(b) or get(c))
        elseif op == O.ANDK then put(a, get(b) and k[c])
        elseif op == O.ORK then put(a, get(b) or k[c])
        elseif op == O.SUBRK then put(a, k[b] - get(c))
        elseif op == O.DIVRK then put(a, k[b] / get(c))
        elseif (op >= O.ADD and op <= O.POWK) or op == O.IDIV or op == O.IDIVK then
            local isConstant = op >= O.ADDK and op <= O.POWK or op == O.IDIVK
            local left, right = get(b), if isConstant then k[c] else get(c)
            local base = if op >= O.ADDK and op <= O.POWK then op - O.ADDK + O.ADD else op
            local value
            if base == O.ADD then value = left + right
            elseif base == O.SUB then value = left - right
            elseif base == O.MUL then value = left * right
            elseif base == O.DIV then value = left / right
            elseif base == O.POW then value = left ^ right
            elseif base == O.MOD then
                value = if type(left) == "number" and type(right) == "number" then num.ls_mod(left, right) else left % right
            else value = if type(left) == "number" and type(right) == "number" then num.ls_idiv(left, right) else left // right end
            put(a, value)
        else
            local customHandler = if customHandlers then customHandlers[op] else nil
            if customHandler then
                customHandler({
                    op = op, pc = current, a = a, b = b, c = c, d = d, aux = aux,
                    get = get, put = put, constants = k, code = code, env = upvalues.env,
                    proto = p, upvalues = upvalues, runtime = self,
                    setPc = function(nextPc) pc = nextPc end,
                })
            else
                error(`unsupported opcode {Opcodes.names[op] or op} at {p.name}:{current}`, 0)
            end
        end
        if afterOpHook then
            afterOpHook(op, current, a, b, c, d, aux, p, r)
        end
    end
end

-- Resolves every import constant once against `environment`, as the VM does when it
-- loads code into a safe environment. A path that reaches nil or fails (a metamethod
-- that errors, indexing a non-table) stays unresolved and is read live at run time.
local function resolveImports(program, environment, runtime)
    local hasDynamic = runtime and environment == runtime.environment
        and (runtime._hasGlobalDescriptors or runtime._behaviors.onGlobalRead ~= nil)
    local globalDescs = if hasDynamic then runtime._globalDescriptors else nil
    local onGlobalRead = if hasDynamic then runtime._behaviors.onGlobalRead else nil
    for _, proto in program.protos do
        local constants, resolved = proto.constants, nil
        for index = 0, proto.constantCount - 1 do
            local constant = constants[index]
            if type(constant) == "table" and constant.kind == "import" then
                local id = constant.id
                local topName = constants[bit32.band(bit32.rshift(id, 20), 1023)]
                if hasDynamic and (onGlobalRead ~= nil or (globalDescs and globalDescs[topName] ~= nil)) then
                    continue
                end
                local ok, value = pcall(function()
                    local count = bit32.rshift(id, 30)
                    local value = environment[topName]
                    if count >= 2 and value ~= nil then value = value[constants[bit32.band(bit32.rshift(id, 10), 1023)]] end
                    if count >= 3 and value ~= nil then value = value[constants[bit32.band(id, 1023)]] end
                    return value
                end)
                if ok and value ~= nil then
                    resolved = resolved or {}
                    resolved[index] = value
                end
            end
        end
        proto.imports = resolved
    end
end

-- Turns bytecode into a guest function (the main chunk). `shown` is the chunk
-- as it appears in messages; bytecode carries no chunk name of its own.
function Runtime:_load(bytes, shown, customEnv)
    assert(not self._disposed, "LuauSquared runtime has been disposed")
    assert(type(bytes) == "string", "expected bytecode string")
    if #bytes > self._limits.bytecodeBytes then
        error(`invalid bytecode: {#bytes} bytes exceeds the {self._limits.bytecodeBytes}-byte limit`, 0)
    end
    -- Reentrant loading is work requested by the active guest. Host-initiated
    -- loads have no execution yet and are bounded by bytecodeBytes instead.
    self:_charge(math.ceil(#bytes / BYTES_PER_UNIT))
    -- A compile error arrives as a zero byte followed by ":line: message".
    if string.byte(bytes, 1) == 0 then error(shown .. string.sub(bytes, 2), 0) end
    if self._bytecodeHooks.beforeDecode then
        local nextBytes = self._bytecodeHooks.beforeDecode(bytes, shown, self)
        if type(nextBytes) == "string" then bytes = nextBytes end
    end
    -- Decoding verifies the whole program, including functions that never run.
    local ctx = self:_decodeContext()
    local program = decode(bytes, ctx)
    for _, p in program.protos do p.source = shown end
    if self._bytecodeHooks.afterDecode then
        self._bytecodeHooks.afterDecode(program, shown, self)
    end
    if self._bytecodePolicy then
        local ok, violations = BytecodeInspect.check(program, self._bytecodePolicy, ctx)
        if not ok then
            error(`bytecode policy violation: {violations[1].reason}`, 0)
        end
    end
    if self._bytecodeHooks.afterVerify then
        self._bytecodeHooks.afterVerify(program, shown, self)
    end
    -- Code loaded by guest code (through a host loader it was given) runs in the
    -- environment of the thread loading it, like loadstring; otherwise in the
    -- runtime's own. Constant closures start out in that same environment.
    local environment = customEnv or self:_threadEnvironment(currentThread())
    program.env = environment
    if self._safeEnvironment and not unsafeEnvironments[environment] then resolveImports(program, environment, self) end
    local main = self:_closure(program, program.main, environment)
    if self._behaviors.onLoad then
        self._behaviors.onLoad(main, program, shown, self)
    end
    if self._bytecodeHooks.afterLoad then
        self._bytecodeHooks.afterLoad(main, program, shown, self)
    end
    return main
end

-- chunkName follows Luau: "=name" as written, "@file", otherwise source text.
function Runtime:loadBytecode(bytes, chunkName, customEnv)
    assert(chunkName == nil or type(chunkName) == "string", "chunkName must be a string")
    return self:_load(bytes, chunkId(chunkName or "=(bytecode)"), customEnv)
end

function Runtime:executeBytecode(bytes, ...)
    return self:loadBytecode(bytes)(...)
end

-- options: { optimizationLevel = 0-2, debugLevel = 0-2 }, defaulting to the
-- runtime's compile options. Level 1+ debug info is what gives errors and
-- tracebacks their line numbers.
function Runtime:compile(source, options, raw)
    assert(not self._disposed, "LuauSquared runtime has been disposed")
    assert(self._sourceCompilation, "source compilation is disabled for this runtime")
    options = table.clone(options or {})
    for name,value in self._compileOptions do if options[name]==nil then options[name]=value end end
    local optimization = if options.optimizationLevel == nil then self._compileOptions.optimizationLevel else options.optimizationLevel
    local debugLevel = if options.debugLevel == nil then self._compileOptions.debugLevel else options.debugLevel
    for name, level in { optimizationLevel = optimization, debugLevel = debugLevel } do
        assert(type(level) == "number" and level % 1 == 0 and level >= 0 and level <= 2, `{name} must be 0, 1 or 2`)
    end
    assert(type(source) == "string", "source must be a string")
    -- Compilation runs to completion outside the instruction budget, so its input is bounded.
    assert(#source <= self._limits.sourceBytes, `source is {#source} bytes; the limit is {self._limits.sourceBytes}`)
    self:_charge(math.ceil(#source / BYTES_PER_UNIT))
    if self._behaviors.onCompile then
        self._behaviors.onCompile(source, options, self)
    end
    if not self._compiler then
        local makeCompiler = if roblox then require(script.Parent.compiler.Select) else require("./compiler/Select")
        self._compiler = makeCompiler(self._compilerConfig)
    end
    options.optimizationLevel=optimization
    options.debugLevel=debugLevel
    options.raw=true
    local ok, bytes = pcall(self._compiler.compile, source, options)
    if not ok then
        -- Nesting or size beyond the compiler's fixed memory aborts it, possibly in
        -- the middle of an allocation. As a precaution it is never reused: the next
        -- compile starts a fresh instance.
        self._compiler = nil
        local message = tostring(bytes)
        if string.find(message, "unreachable", 1, true) then
            message = "the source is too large or too deeply nested for the compiler"
        end
        error("compilation failed: " .. message, 0)
    end
    -- A syntax error is the compiler's error bytecode: a zero byte, then its message.
    if string.byte(bytes, 1) == 0 and not raw then error(string.sub(bytes, 2), 0) end
    if self._behaviors.afterCompile then
        local nextBytes = self._behaviors.afterCompile(bytes, source, options, self)
        if type(nextBytes) == "string" then bytes = nextBytes end
    end
    return bytes
end

-- Compiles source into a guest function. Without a chunkName the source text
-- names the chunk, as in Lua's load.
function Runtime:load(source, chunkName, options, customEnv)
    assert(chunkName == nil or type(chunkName) == "string", "chunkName must be a string")
    local bytes = self:compile(source, options, true)
    return self:_load(bytes, if chunkName == nil then sourceChunkId(source) else chunkId(chunkName), customEnv)
end

function Runtime:execute(source, ...)
    return self:load(source)(...)
end

Customization._bindRuntime(Runtime.new)

return Runtime
