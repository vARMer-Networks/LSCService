-- Budgeted Luau patterns, adapted from the pinned MIT-licensed Luau lstrlib.cpp.
-- Every search, expansion, bracket scan and backreference comparison spends work
-- before continuing. The matcher retains the native 200-level / 32-capture limits.
local byte, sub = string.byte, string.sub
local classes = {}
for _, name in { "a", "c", "d", "g", "l", "p", "s", "u", "w", "x", "z" } do
    local values = {}
    for c = 0, 255 do values[c] = string.match(string.char(c), "%" .. name) ~= nil end
    classes[string.byte(name)] = values
end
local specials = {}
for i = 1, #"^$*+?.([%-" do specials[byte("^$*+?.([%-", i)] = true end

return function(runtime)
    local library = {}
    local function checkString(value, name, index, count)
        if type(value) == "number" then return tostring(value) end
        if type(value) ~= "string" then
            if count and count < index then error(`missing argument #{index} to '{name}' (string expected)`, 0) end
            error(`invalid argument #{index} to '{name}' (string expected, got {type(value)})`, 0)
        end
        return value
    end
    local function integer(value, default, name, index)
        if value == nil then return default end
        local number = tonumber(value)
        if not number then error(`invalid argument #{index} to '{name}' (number expected, got {type(value)})`, 0) end
        if not (number > -2147483649 and number < 2147483648) then return -2147483648 end
        return if number < 0 then math.ceil(number) else math.floor(number)
    end
    local function text(s, first, last)
        local size = math.max(0, last - first + 1)
        if size > runtime._limits.stringBytes then error("resulting string too large", 0) end
        runtime:_charge(math.ceil(size / 128))
        return sub(s, first, last)
    end
    local function state(s, pattern)
        local work = 0
        local function tick()
            work += 1
            if work == 128 then work = 0; runtime:_charge(1) end
        end
        local captures, level, depth, length, plen = {}, 0, 200, #s, #pattern
        local function class(c, cl)
            local lower = if cl >= 65 and cl <= 90 then cl + 32 else cl
            local values = classes[lower]
            if not values then return c == cl end
            return if lower == cl then values[c] else not values[c]
        end
        local function classend(p)
            tick()
            local c = byte(pattern, p)
            if c == 37 then
                if p == plen then error("malformed pattern (ends with '%')", 0) end
                return p + 2
            elseif c == 91 then
                p += 1
                if byte(pattern, p) == 94 then p += 1 end
                repeat
                    tick()
                    if p > plen then error("malformed pattern (missing ']')", 0) end
                    if byte(pattern, p) == 37 and p < plen then p += 1 end
                    p += 1
                until byte(pattern, p) == 93
                return p + 1
            end
            return p + 1
        end
        local function bracket(c, p, ending)
            local positive = byte(pattern, p + 1) ~= 94
            p += if positive then 1 else 2
            while p < ending do
                tick()
                local current = byte(pattern, p)
                if current == 37 then
                    p += 1
                    if class(c, byte(pattern, p)) then return positive end
                elseif byte(pattern, p + 1) == 45 and p + 2 < ending then
                    if current <= c and c <= byte(pattern, p + 2) then return positive end
                    p += 2
                elseif current == c then return positive end
                p += 1
            end
            return not positive
        end
        local function single(at, p, ending)
            tick()
            if at > length then return false end
            local c, pc = byte(s, at), byte(pattern, p)
            if pc == 46 then return true end
            if pc == 37 then return class(c, byte(pattern, p + 1)) end
            if pc == 91 then return bracket(c, p, ending - 1) end
            return c == pc
        end
        local match
        local function capture(at, p, position)
            if level == 32 then error("too many captures", 0) end
            level += 1
            local index = level
            captures[index] = { start = at, length = if position then -2 else -1 }
            local result = match(at, p)
            if not result then level -= 1 end
            return result
        end
        local function close(at, p)
            local index = level
            while index > 0 and captures[index].length ~= -1 do tick(); index -= 1 end
            if index == 0 then error("invalid pattern capture", 0) end
            local entry = captures[index]
            entry.length = at - entry.start
            local result = match(at, p)
            if not result then entry.length = -1 end
            return result
        end
        local function expand(at, p, ending, minimal)
            if minimal then
                while true do
                    local result = match(at, ending + 1)
                    if result then return result end
                    if not single(at, p, ending) then return nil end
                    at += 1
                end
            end
            local count = 0
            while single(at + count, p, ending) do count += 1 end
            while count >= 0 do
                local result = match(at + count, ending + 1)
                if result then return result end
                count -= 1
            end
            return nil
        end
        local function body(at, p)
            while p <= plen do
                tick()
                local c, nextc = byte(pattern, p), byte(pattern, p + 1)
                if c == 40 then return capture(at, p + (if nextc == 41 then 2 else 1), nextc == 41) end
                if c == 41 then return close(at, p + 1) end
                if c == 36 and p == plen then return if at == length + 1 then at else nil end
                if c == 37 and nextc == 98 then
                    local opening, closing = byte(pattern, p + 2), byte(pattern, p + 3)
                    if not closing then error("malformed pattern (missing arguments to '%b')", 0) end
                    if byte(s, at) ~= opening then return nil end
                    local count = 1
                    repeat
                        tick(); at += 1
                        if at > length then return nil end
                        local sc = byte(s, at)
                        if sc == closing then count -= 1 elseif sc == opening then count += 1 end
                    until count == 0
                    at += 1; p += 4
                elseif c == 37 and nextc == 102 then
                    p += 2
                    if byte(pattern, p) ~= 91 then error("missing '[' after '%f' in pattern", 0) end
                    local ending = classend(p)
                    local previous = if at == 1 then 0 else byte(s, at - 1)
                    if bracket(previous, p, ending - 1) or not bracket(byte(s, at) or 0, p, ending - 1) then return nil end
                    p = ending
                elseif c == 37 and nextc and nextc >= 48 and nextc <= 57 then
                    local index = nextc - 48
                    local entry = captures[index]
                    if index < 1 or index > level or entry.length == -1 then error(`invalid capture index %{index}`, 0) end
                    if entry.length < 0 or length - at + 1 < entry.length then return nil end
                    for offset = 0, entry.length - 1 do
                        tick()
                        if byte(s, entry.start + offset) ~= byte(s, at + offset) then return nil end
                    end
                    at += entry.length; p += 2
                else
                    local ending = classend(p)
                    local suffix = byte(pattern, ending)
                    if not single(at, p, ending) then
                        if suffix == 42 or suffix == 63 or suffix == 45 then p = ending + 1 else return nil end
                    elseif suffix == 63 then
                        local result = match(at + 1, ending + 1)
                        if result then return result end
                        p = ending + 1
                    elseif suffix == 43 or suffix == 42 then
                        return expand(at + (if suffix == 43 then 1 else 0), p, ending, false)
                    elseif suffix == 45 then return expand(at, p, ending, true)
                    else at += 1; p = ending end
                end
            end
            return at
        end
        match = function(at, p)
            tick()
            if depth == 0 then error("pattern too complex", 0) end
            depth -= 1
            local result = body(at, p)
            depth += 1
            return result
        end
        local function one(index, first, ending)
            if level == 0 and index == 1 then return text(s, first, ending - 1) end
            if index > level then error("invalid capture index", 0) end
            local entry = captures[index]
            if entry.length == -1 then error("unfinished capture", 0) end
            if entry.length == -2 then return entry.start end
            return text(s, entry.start, entry.start + entry.length - 1)
        end
        return {
            -- A prior budget/error unwind must not spend the next call's depth.
            attempt = function(at, p) level, depth = 0, 200; return match(at, p) end,
            one = one, tick = tick,
            results = function(first, ending, whole)
                local n = if level == 0 and whole then 1 else level
                local values = table.create(n)
                for index = 1, n do values[index] = one(index, first, ending) end
                return table.unpack(values, 1, n)
            end,
        }
    end
    local function search(s, pattern, init, plain, finding, count)
        local name = if finding then "find" else "match"
        s, pattern = checkString(s, name, 1, count), checkString(pattern, name, 2, count)
        init = integer(init, 1, name, 3)
        if init < 0 then init += #s + 1 end
        init = math.max(1, init)
        runtime:_charge(1)
        if init > #s + 1 then return nil end
        local ms = state(s, pattern)
        if finding and not plain then
            plain = true
            for p = 1, #pattern do ms.tick(); if specials[byte(pattern, p)] then plain = false; break end end
        end
        if finding and plain then
            -- Literal search is linear in the source and pattern lengths (KMP).
            if #pattern > runtime._limits.tableElements then error("table allocation limit exceeded", 0) end
            local prefix, matched = { [1] = 0 }, 0
            for p = 2, #pattern do
                ms.tick()
                while matched > 0 and byte(pattern, matched + 1) ~= byte(pattern, p) do ms.tick(); matched = prefix[matched] end
                if byte(pattern, matched + 1) == byte(pattern, p) then matched += 1 end
                prefix[p] = matched
            end
            if #pattern == 0 then return init, init - 1 end
            prefix[1], matched = 0, 0
            for at = init, #s do
                ms.tick()
                while matched > 0 and byte(pattern, matched + 1) ~= byte(s, at) do ms.tick(); matched = prefix[matched] end
                if byte(pattern, matched + 1) == byte(s, at) then matched += 1 end
                if matched == #pattern then return at - matched + 1, at end
            end
            return nil
        end
        local anchored = byte(pattern, 1) == 94
        for at = init, #s + 1 do
            local ending = ms.attempt(at, if anchored then 2 else 1)
            if ending then
                if finding then return at, ending - 1, ms.results(at, ending, false) end
                return ms.results(at, ending, true)
            end
            if anchored then break end
        end
        return nil
    end
    library.find = function(...)
        local s, pattern, init, plain = ...
        return search(s, pattern, init, plain, true, select("#", ...))
    end
    library.match = function(...)
        local s, pattern, init = ...
        return search(s, pattern, init, false, false, select("#", ...))
    end
    library.gmatch = function(...)
        local s, pattern = ...
        s, pattern = checkString(s, "gmatch", 1, select("#", ...)), checkString(pattern, "gmatch", 2, select("#", ...))
        local ms, start = state(s, pattern), 1
        return function()
            runtime:_charge(1)
            for at = start, #s + 1 do
                local ending = ms.attempt(at, 1)
                if ending then
                    start = if ending == at then ending + 1 else ending
                    return ms.results(at, ending, true)
                end
            end
            start = #s + 2
            return -- native terminal iterator returns zero values
        end
    end
    library.gsub = function(...)
        local s, pattern, replacement, maximum = ...
        s, pattern = checkString(s, "gsub", 1, select("#", ...)), checkString(pattern, "gsub", 2, select("#", ...))
        local kind = type(replacement)
        if kind ~= "string" and kind ~= "number" and kind ~= "function" and kind ~= "table" then
            -- The native library validates this type before it runs the pattern.
            -- Use that bounded error path to retain missing-argument diagnostics.
            return string.gsub(...)
        end
        maximum = integer(maximum, #s + 1, "gsub", 4)
        if kind == "number" then replacement = tostring(replacement); kind = "string" end
        runtime:_charge(1)
        local ms, at, count, total, parts = state(s, pattern), 1, 0, 0, {}
        local anchored = byte(pattern, 1) == 94
        local function append(value)
            total += #value
            if total > runtime._limits.stringBytes then error("resulting string too large", 0) end
            runtime:_charge(math.ceil(#value / 128))
            if #parts >= runtime._limits.tableElements then error("table allocation limit exceeded", 0) end
            parts[#parts + 1] = value
        end
        while count < maximum do
            local ending = ms.attempt(at, if anchored then 2 else 1)
            if ending then
                count += 1
                if kind == "string" then
                    local position, first = 1, 1
                    while position <= #replacement do
                        ms.tick()
                        if byte(replacement, position) == 37 then
                            append(text(replacement, first, position - 1))
                            position += 1
                            local c = byte(replacement, position)
                            if c == 37 then append("%")
                            elseif c and c >= 48 and c <= 57 then
                                append(tostring(if c == 48 then text(s, at, ending - 1) else ms.one(c - 48, at, ending)))
                            else error("invalid use of '%' in replacement string", 0) end
                            first = position + 1
                        end
                        position += 1
                    end
                    append(text(replacement, first, #replacement))
                else
                    local value
                    local arguments = table.pack(ms.results(at, ending, true))
                    -- A bounded native call retains gsub's non-yieldable callback
                    -- boundary. The subject/pattern here are fixed and empty.
                    string.gsub("", "", function()
                        if kind == "function" then
                            runtime:_countHostCall(replacement)
                            value = replacement(table.unpack(arguments, 1, arguments.n))
                        else value = replacement[arguments[1]] end
                        return ""
                    end, 1)
                    if value == nil or value == false then value = text(s, at, ending - 1)
                    elseif type(value) ~= "string" and type(value) ~= "number" then error(`invalid replacement value (a {type(value)})`, 0) end
                    append(tostring(value))
                end
            end
            if ending and ending > at then at = ending
            elseif at <= #s then append(sub(s, at, at)); at += 1
            else break end
            if anchored then break end
        end
        append(text(s, at, #s))
        return table.concat(parts), count
    end
    return library
end
