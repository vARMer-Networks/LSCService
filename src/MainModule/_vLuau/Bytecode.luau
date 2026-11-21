-- Reads and verifies wire versions 9-14 / type version 3 from the pinned compiler,
-- including line/debug metadata, feedback and bounded prototype extensions.
-- Vectors and integers require host constructors; class constants are unsupported.
--
-- Input is untrusted. Every size is checked against the bytes that remain, every
-- reference (register, constant, upvalue, child function, jump target, capture) is
-- checked against the function it appears in, and failures raise
-- "invalid bytecode: ..." without a host position. The work is linear in the
-- input. A program that passes cannot make the interpreter hit an internal
-- inconsistency; what is left to run time is the program's own behavior (type
-- errors, loops, allocation), which the instruction budget and limits govern.
local roblox = script ~= nil
local Inspect = if roblox then require(script.Parent.BytecodeInspect) else require("./BytecodeInspect")
local Opcodes = if roblox then require(script.Parent.generated.Opcodes) else require("./generated/Opcodes")
local makePrimitives = if roblox then require(script.Parent.generated.Primitives) else require("./generated/Primitives")

local prepared = setmetatable({}, { __mode = "k" })

-- Operand classes by opcode, built once per opcode table.
local function prepare(O)
    local cached = prepared[O]
    if cached then return cached end
    local function set(...)
        local result = {}
        for _, name in { ... } do result[O[name]] = true end
        return result
    end
    cached = {
        -- Every opcode the interpreter implements; anything else is "unsupported".
        supported = set(
            "NOP", "COVERAGE", "CALLFB", "CMPPROTO", "FASTPCALL", "LOADNIL", "LOADB", "LOADN", "LOADK", "MOVE", "GETGLOBAL", "SETGLOBAL",
            "GETUPVAL", "SETUPVAL", "CLOSEUPVALS", "GETIMPORT", "GETTABLE", "SETTABLE",
            "GETTABLEKS", "SETTABLEKS", "GETTABLEN", "SETTABLEN", "NEWCLOSURE", "NAMECALL",
            "CALL", "RETURN", "JUMP", "JUMPBACK", "JUMPIF", "JUMPIFNOT", "JUMPIFEQ",
            "JUMPIFLE", "JUMPIFLT", "JUMPIFNOTEQ", "JUMPIFNOTLE", "JUMPIFNOTLT",
            "ADD", "SUB", "MUL", "DIV", "MOD", "POW", "ADDK", "SUBK", "MULK", "DIVK",
            "MODK", "POWK", "AND", "OR", "ANDK", "ORK", "CONCAT", "NOT", "MINUS",
            "LENGTH", "NEWTABLE", "DUPTABLE", "SETLIST", "FORNPREP", "FORNLOOP",
            "GETVARARGS", "DUPCLOSURE", "PREPVARARGS", "LOADKX", "JUMPX", "CAPTURE",
            "IDIV", "IDIVK", "SUBRK", "DIVRK", "FORGPREP", "FORGLOOP",
            "FORGPREP_INEXT", "FORGPREP_NEXT", "FASTCALL", "FASTCALL1", "FASTCALL2",
            "FASTCALL2K", "FASTCALL3", "JUMPXEQKNIL", "JUMPXEQKB", "JUMPXEQKN", "JUMPXEQKS"),
        threeRegisters = set("GETTABLE", "SETTABLE", "ADD", "SUB", "MUL", "DIV", "MOD", "POW", "AND", "OR", "IDIV"),
        twoRegisters = set("MOVE", "NOT", "MINUS", "LENGTH", "GETTABLEN", "SETTABLEN"),
        registerAndNumber = set("ADDK", "SUBK", "MULK", "DIVK", "MODK", "POWK", "IDIVK"), -- A, B registers; C number constant
        registerAndConstant = set("ANDK", "ORK"), -- A, B registers; C any constant
        reverseNumber = set("SUBRK", "DIVRK"), -- A, C registers; B number constant
        globalAccess = set("GETGLOBAL", "SETGLOBAL"),
        tableString = set("GETTABLEKS", "SETTABLEKS"),
        conditionalOnRegister = set("JUMPIF", "JUMPIFNOT"),
        compare = set("JUMPIFEQ", "JUMPIFLE", "JUMPIFLT", "JUMPIFNOTEQ", "JUMPIFNOTLE", "JUMPIFNOTLT"),
        constantJump = set("JUMPXEQKNIL", "JUMPXEQKB", "JUMPXEQKN", "JUMPXEQKS"),
        loopPrepare = set("FORGPREP", "FORGPREP_INEXT", "FORGPREP_NEXT"),
        fastcall = set("FASTCALL", "FASTCALL1", "FASTCALL2", "FASTCALL2K", "FASTCALL3", "FASTPCALL"),
        terminal = set("RETURN", "JUMP", "JUMPBACK", "JUMPX"),
    }
    prepared[O] = cached
    return cached
end

local function decode(bytes, context)
    assert(type(bytes) == "string", "expected bytecode string")
    local O, oplength = context.opcodes, context.oplength
    local customOpcodes = context.customOpcodes
    local decodeOp = context.decodeOp
    local function effectiveLength(op)
        local custom = if customOpcodes then customOpcodes[op] else nil
        if type(custom) == "table" and custom.length then
            return custom.length
        end
        return oplength(op)
    end
    local G = prepare(O)
    local function fail(message) error("invalid bytecode: " .. message, 0) end
    local limit = context.maxBytes
    if limit and #bytes > limit then fail(`{#bytes} bytes exceeds the {limit}-byte limit`) end

    local data = buffer.fromstring(bytes)
    local size, offset = buffer.len(data), 0
    local function take(count)
        if count > size - offset then fail("truncated") end
        local start = offset
        offset += count
        return start
    end
    local function byte() return buffer.readu8(data, take(1)) end
    local function word() return buffer.readu32(data, take(4)) end
    -- A 32-bit variable-length integer; five bytes at most, the last using four bits.
    local function varint()
        local value, scale = 0, 1
        for index = 1, 5 do
            local b = byte()
            if index == 5 and b > 15 then fail("variable-length integer overflows 32 bits") end
            value += bit32.band(b, 127) * scale
            if b < 128 then return value end
            scale *= 128
        end
        fail("unterminated variable-length integer")
    end
    local function varint64()
        local low, high = 0, 0
        for index = 0, 9 do
            local b = byte()
            if index == 9 and b > 1 then fail("variable-length integer overflows 64 bits") end
            local payload, shift = bit32.band(b, 127), index * 7
            if shift < 32 then
                low = bit32.bor(low, bit32.lshift(payload, shift))
                if shift > 25 then high = bit32.bor(high, bit32.rshift(payload, 32 - shift)) end
            else high = bit32.bor(high, bit32.lshift(payload, shift - 32)) end
            if b < 128 then return low, high end
        end
        fail("unterminated 64-bit variable-length integer")
    end
    -- A count of items that each need at least `each` bytes, so a lie about it is
    -- rejected before any work is done on its behalf.
    local function items(what, each)
        local n = varint()
        if n * each > size - offset then fail(`{what} count {n} exceeds the data that remains`) end
        return n
    end

    if byte() == 0 then
        -- A compile error travels as a zero byte followed by its message.
        fail("this is a compiler error, not bytecode")
    end
    offset = 0
    local version = byte()
    if version < 9 or version > 14 then fail(`unsupported bytecode version {version}; expected 9-14`) end
    if byte() ~= 3 then fail("unsupported bytecode type version; expected 3") end

    local strings = {}
    for i = 1, items("string", 1) do
        local length = varint()
        strings[i] = buffer.readstring(data, take(length), length)
    end
    local stringCount = #strings
    local function stringIndex(what)
        local index = varint()
        if index > stringCount then fail(`{what} refers to string {index} of {stringCount}`) end
        return index
    end
    while byte() ~= 0 do stringIndex("type remapping") end -- userdata type remapping metadata

    local protos = {}
    for i = 1, items("function", 8) do
        local enclosingSize, ending = size, nil
        if version >= 12 then
            local length = varint()
            if length > size - offset then fail("function size exceeds the data that remains") end
            ending = offset + length
            size = ending
        end
        local p = { stack = byte(), params = byte(), upvalues = byte(), vararg = byte() ~= 0,
            flags = byte(), code = {}, constants = {}, children = {} }
        if p.params > p.stack then fail(`function {i} has {p.params} parameters but {p.stack} registers`) end
        take(varint()) -- optional type metadata
        local codeSize = items("instruction", 4)
        if codeSize == 0 then fail(`function {i} has no instructions`) end
        for pc = 1, codeSize do p.code[pc] = word() end
        local constantCount = items("constant", 1)
        p.constantCount = constantCount
        local constants = p.constants
        for k = 0, constantCount - 1 do
            local tag = byte()
            if tag == 0 then constants[k] = nil
            elseif tag == 1 then constants[k] = byte() ~= 0
            elseif tag == 2 then constants[k] = buffer.readf64(data, take(8))
            elseif tag == 3 then
                local index = stringIndex("string constant")
                if index == 0 then fail("string constant refers to no string") end
                constants[k] = strings[index]
            elseif tag == 4 then
                -- An import path: its length in the top two bits, then up to three
                -- indices of earlier string constants.
                local id = word()
                local length = bit32.rshift(id, 30)
                if length < 1 then fail("import constant has no path") end
                for part = 1, length do
                    local at = bit32.band(bit32.rshift(id, 30 - 10 * part), 1023)
                    if at >= k or type(constants[at]) ~= "string" then fail("import path names something that is not an earlier string constant") end
                end
                constants[k] = { kind = "import", id = id }
            elseif tag == 5 or tag == 8 then
                -- Table template: earlier string constants as keys; tag 8 also pairs
                -- each key with the constant that fills it (or -1).
                local keys, values = {}, if tag == 8 then {} else nil
                for n = 1, items("table key", if tag == 8 then 5 else 1) do
                    local key = varint()
                    if key >= k or type(constants[key]) ~= "string" then fail("table template key is not an earlier string constant") end
                    keys[n] = key
                    if values then
                        local constant = buffer.readi32(data, take(4))
                        if constant < -1 or constant >= k then fail("table template value is not an earlier constant or -1") end
                        values[n] = if constant >= 0 then constant else false
                    end
                end
                constants[k] = { kind = "table", keys = keys, values = values }
            elseif tag == 6 then
                local id = varint()
                if id >= i - 1 then fail(`closure constant refers to function {id}, which is not defined before function {i - 1}`) end
                constants[k] = { kind = "closure", proto = id + 1 }
            elseif tag == 7 then
                local start = take(16)
                if not context.vector then fail("vector constants are unavailable on this host") end
                constants[k] = context.vector(buffer.readf32(data, start), buffer.readf32(data, start + 4),
                    buffer.readf32(data, start + 8), buffer.readf32(data, start + 12))
            elseif tag == 9 then
                local negative = byte()
                if negative > 1 then fail("integer sign is not boolean") end
                local low, high = varint64()
                local int = context.integer
                if not int then fail("integer constants are unavailable on this host") end
                local value = int.add(int.create(low), int.lshift(int.create(high), int.create(32)))
                constants[k] = if negative == 1 then int.neg(value) else value
            elseif tag == 11 and version >= 13 then
                local start = take(32)
                if not context.vector then fail("vector constants are unavailable on this host") end
                constants[k] = context.vector(buffer.readf64(data, start), buffer.readf64(data, start + 8),
                    buffer.readf64(data, start + 16), buffer.readf64(data, start + 24))
            else fail(`unsupported constant tag {tag}`) end
        end
        local childCount = items("child function", 1)
        p.childCount = childCount
        for child = 0, childCount - 1 do
            local id = varint()
            if id >= i - 1 then fail(`function {i - 1} lists child {id}, which is not defined before it`) end
            p.children[child] = id + 1
        end
        p.line = varint()
        p.debugname = strings[stringIndex("function name")]
        p.name = p.debugname or "anonymous"
        -- Line info (debug level 1+): a byte offset per instruction relative to an
        -- absolute line stored once per 2^gap instructions, as the VM loader reads it.
        if byte() ~= 0 then
            local gap = byte()
            if gap > 31 then fail(`line gap {gap} is out of range`) end
            local lineinfo, absolute, base, offsets = {}, {}, nil, 0
            base = take(codeSize)
            for pc = 1, codeSize do
                offsets = (offsets + buffer.readu8(data, base + pc - 1)) % 256
                lineinfo[pc] = offsets
            end
            local intervals = bit32.rshift(codeSize - 1, gap) + 1
            local start, line = take(4 * intervals), 0
            for interval = 1, intervals do
                line += buffer.readi32(data, start + 4 * (interval - 1))
                absolute[interval] = line
            end
            p.lineinfo, p.abslineinfo, p.linegaplog2 = lineinfo, absolute, gap
        end
        -- Debug info (debug level 2): local variable ranges and upvalue names.
        if byte() ~= 0 then
            local locals, upvalueNames = {}, {}
            for n = 1, items("local variable", 4) do
                local name, startpc, endpc, register = stringIndex("local variable name"), varint(), varint(), byte()
                if startpc > endpc or endpc > codeSize or register >= p.stack then fail("local variable range lies outside its function") end
                locals[n] = { name = strings[name], startpc = startpc, endpc = endpc, register = register }
            end
            local names = items("upvalue name", 1)
            if names ~= p.upvalues then fail(`function {i} names {names} upvalues but has {p.upvalues}`) end
            for n = 1, names do upvalueNames[n] = strings[stringIndex("upvalue name")] end
            p.locals, p.upvalueNames = locals, upvalueNames
        end
        if version >= 11 then
            p.feedback = {}
            for slot = 1, items("feedback slot", 2) do
                if byte() ~= 0 then fail("unsupported feedback slot kind") end
                p.feedback[slot] = varint() + 1
            end
        end
        if version >= 12 and bit32.band(p.flags, 8) ~= 0 then varint64() end
        if ending then offset, size = ending, enclosingSize end
        protos[i] = p
    end
    local protoCount = #protos
    local main = varint() + 1
    if main > protoCount then fail("the main function does not exist") end
    if protos[main].upvalues ~= 0 then fail("the main function has upvalues") end
    if offset ~= size then fail("data follows the last function") end

    -- Everything below checks one function against itself and the functions it names.
    for index, p in protos do
        local code, constants, nconst = p.code, p.constants, p.constantCount
        local count, stack = #code, p.stack
        local function bad(pc, message)
            local word = code[pc]
            local op = if word then bit32.band(word, 255) else -1
            local custom = if customOpcodes then customOpcodes[op] else nil
            local label = if type(custom) == "table" and custom.name then custom.name else (O.names[op] or op)
            fail(`{message} (function {index - 1}, instruction {pc}, opcode {label})`)
        end

        -- Pass 1: where instructions start, and which CAPTUREs belong to a closure.
        local starts, captures = {}, {}
        local pc = 1
        while pc <= count do
            local word = code[pc]
            local op = bit32.band(word, 255)
            local length = effectiveLength(op)
            if captures[pc] then
                if op ~= O.CAPTURE then bad(pc, "expected CAPTURE") end
            else
                if decodeOp then
                    local aux = if length == 2 and pc < count then code[pc + 1] else nil
                    local mapped = decodeOp(op, word, aux, pc, p)
                    if mapped ~= nil and mapped ~= op then
                        assert(type(mapped) == "number", "decodeOp must return a numeric opcode or encoded word")
                        if mapped > 255 or mapped < 0 then
                            code[pc] = mapped
                            op = bit32.band(mapped, 255)
                        else
                            op = bit32.band(mapped, 255)
                            code[pc] = word - bit32.band(word, 255) + op
                        end
                        length = effectiveLength(op)
                    end
                end
                local custom = if customOpcodes then customOpcodes[op] else nil
                if not G.supported[op] and not custom then
                    error(`unsupported opcode {O.names[op] or op} at {p.name}:{pc}`, 0)
                end
                if op == O.CAPTURE then bad(pc, "CAPTURE does not follow a closure") end
                starts[pc] = true
            end
            if pc + length - 1 > count then bad(pc, "instruction is cut off") end
            if op == O.NEWCLOSURE or op == O.DUPCLOSURE then
                local d = bit32.rshift(code[pc], 16)
                if d > 32767 then bad(pc, "operand is out of range") end
                local child
                if op == O.NEWCLOSURE then
                    if d >= p.childCount then bad(pc, `child function {d} does not exist`) end
                    child = protos[p.children[d]]
                else
                    local template = if d < nconst then constants[d] else nil
                    if type(template) ~= "table" or template.kind ~= "closure" then bad(pc, "constant is not a function") end
                    child = protos[template.proto]
                end
                for capture = 1, child.upvalues do
                    if pc + capture > count then bad(pc, "capture list is cut off") end
                    captures[pc + capture] = true
                end
            end
            pc += length
        end
        if pc ~= count + 1 then bad(count, "instruction is cut off") end

        -- Pass 2: operands.
        local function register(pc, value)
            if value >= stack then bad(pc, `register {value} is outside the {stack} this function has`) end
        end
        local function window(pc, first, last) -- registers first..last inclusive
            if first >= stack or last >= stack then bad(pc, `registers {first}..{last} are outside the {stack} this function has`) end
        end
        local function constant(pc, value, what, kind)
            if value >= nconst then bad(pc, `{what} constant {value} does not exist`) end
            if kind and type(constants[value]) ~= kind then bad(pc, `{what} constant {value} is not a {kind}`) end
        end
        local function jump(pc, offset)
            local to = pc + 1 + offset
            if to < 1 or to > count or not starts[to] then bad(pc, `jump to instruction {to} does not land on an instruction`) end
            return to
        end
        local last
        pc = 1
        while pc <= count do
            local word = code[pc]
            local op = bit32.band(word, 255)
            local a = bit32.band(bit32.rshift(word, 8), 255)
            local b = bit32.band(bit32.rshift(word, 16), 255)
            local c = bit32.rshift(word, 24)
            local d = bit32.rshift(word, 16)
            if d >= 32768 then d -= 65536 end
            local aux = if effectiveLength(op) == 2 then code[pc + 1] else nil
            -- The 16-bit operand read as an index: documented as 0..32767.
            local wide = bit32.rshift(word, 16)
            if wide > 32767 and (op == O.LOADK or op == O.GETIMPORT or op == O.DUPTABLE) then bad(pc, "operand is out of range") end
            if captures[pc] then
                -- Capture type 0 copies a register, 1 shares one, 2 shares an upvalue.
                if a == 0 or a == 1 then register(pc, b)
                elseif a == 2 then
                    if b >= p.upvalues then bad(pc, `upvalue {b} does not exist`) end
                else bad(pc, `capture type {a} is not valid`) end
            else
                last = op
                if op == O.NOP then
                elseif op == O.COVERAGE then
                    if bit32.rshift(word, 8) > 0x7FFFFF then bad(pc, "coverage count is negative") end
                elseif G.threeRegisters[op] then register(pc, a); register(pc, b); register(pc, c)
                elseif G.twoRegisters[op] then register(pc, a); register(pc, b)
                elseif G.registerAndNumber[op] then register(pc, a); register(pc, b); constant(pc, c, "arithmetic", "number")
                elseif G.registerAndConstant[op] then register(pc, a); register(pc, b); constant(pc, c, "operand")
                elseif G.reverseNumber[op] then register(pc, a); register(pc, c); constant(pc, b, "arithmetic", "number")
                elseif op == O.LOADNIL or op == O.CLOSEUPVALS then register(pc, a)
                elseif op == O.LOADB then register(pc, a); jump(pc, c)
                elseif op == O.LOADN then register(pc, a)
                elseif op == O.LOADK then register(pc, a); constant(pc, wide, "operand")
                elseif op == O.LOADKX then register(pc, a); constant(pc, aux, "operand")
                elseif G.globalAccess[op] then register(pc, a); constant(pc, aux, "name", "string")
                elseif op == O.GETUPVAL or op == O.SETUPVAL then
                    register(pc, a)
                    if b >= p.upvalues then bad(pc, `upvalue {b} does not exist`) end
                elseif op == O.GETIMPORT then
                    register(pc, a)
                    constant(pc, wide, "import")
                    local import = constants[wide]
                    if type(import) ~= "table" or import.kind ~= "import" or import.id ~= aux then bad(pc, "import path does not match its constant") end
                elseif G.tableString[op] then register(pc, a); register(pc, b); constant(pc, aux, "key", "string")
                elseif op == O.NEWCLOSURE or op == O.DUPCLOSURE then register(pc, a)
                elseif op == O.NAMECALL then
                    register(pc, a); register(pc, a + 1); register(pc, b); constant(pc, aux, "method", "string")
                    local nextop = bit32.band(code[pc + 2] or 0, 255)
                    if not starts[pc + 2] or (nextop ~= O.CALL and nextop ~= O.CALLFB) then bad(pc, "NAMECALL is not followed by CALL") end
                elseif op == O.CALL or op == O.CALLFB then
                    if op == O.CALLFB then
                        if version < 11 then bad(pc, "CALLFB requires bytecode version 11 or later") end
                        if aux ~= 0xFFFFFFFF and (not p.feedback[aux + 1] or p.feedback[aux + 1] ~= pc) then
                            bad(pc, "call feedback slot does not refer to this instruction")
                        end
                    end
                    register(pc, a)
                    if b > 1 then window(pc, a, a + b - 1) end
                    if c > 1 then window(pc, a, a + c - 2) end
                elseif op == O.RETURN then
                    -- A return of no values touches no register.
                    if b > 1 then window(pc, a, a + b - 2) elseif b == 0 then register(pc, a) end
                elseif op == O.JUMP or op == O.JUMPBACK then jump(pc, d)
                elseif op == O.JUMPX then
                    local e = bit32.rshift(word, 8)
                    if e >= 8388608 then e -= 16777216 end
                    jump(pc, e)
                elseif G.conditionalOnRegister[op] then register(pc, a); jump(pc, d)
                elseif G.compare[op] then
                    register(pc, a); jump(pc, d)
                    if aux >= 256 then bad(pc, "comparison operand is not a register") end
                    register(pc, aux)
                elseif G.constantJump[op] then
                    register(pc, a); jump(pc, d)
                    if bit32.band(aux, 0x7F000000) ~= 0 then bad(pc, "constant comparison has stray flags") end
                    if op == O.JUMPXEQKN then constant(pc, bit32.band(aux, 0xFFFFFF), "comparison", "number")
                    elseif op == O.JUMPXEQKS then constant(pc, bit32.band(aux, 0xFFFFFF), "comparison", "string") end
                elseif op == O.CONCAT then
                    register(pc, a)
                    if b > c then bad(pc, "CONCAT range is empty") end
                    window(pc, b, c)
                elseif op == O.NEWTABLE then
                    register(pc, a)
                    if aux > 0xFFFFFF then bad(pc, `table size hint {aux} is too large`) end
                elseif op == O.DUPTABLE then
                    register(pc, a)
                    constant(pc, wide, "template")
                    if type(constants[wide]) ~= "table" or constants[wide].kind ~= "table" then bad(pc, "constant is not a table template") end
                elseif op == O.SETLIST then
                    register(pc, a)
                    if c > 1 then window(pc, b, b + c - 2) elseif c == 0 then register(pc, b) end
                elseif op == O.FORNPREP or op == O.FORNLOOP then window(pc, a, a + 2); jump(pc, d) -- limit, step, index (the index is the loop variable)
                elseif G.loopPrepare[op] then window(pc, a, a + 2); jump(pc, d)
                elseif op == O.FORGLOOP then
                    local variables = bit32.band(aux, 255)
                    if variables < 1 or bit32.band(aux, 0x7FFFFF00) ~= 0 then bad(pc, "generic loop has an invalid variable count") end
                    window(pc, a, a + 2 + math.max(variables, 2)); jump(pc, d)
                elseif op == O.GETVARARGS then
                    if b > 1 then window(pc, a, a + b - 2) elseif b == 0 then register(pc, a) end
                elseif op == O.PREPVARARGS then
                elseif op == O.CMPPROTO then
                    register(pc, a); jump(pc, d)
                elseif G.fastcall[op] then
                    local call = pc + 1 + c
                    if call > count or not starts[call] or bit32.band(code[call], 255) ~= O.CALL then
                        bad(pc, "fast call does not lead to a CALL")
                    end
                    if op == O.FASTPCALL then
                        if version < 14 then bad(pc, "FASTPCALL requires bytecode version 14") end
                        if a > 1 then bad(pc, "invalid protected call id") end
                    elseif op ~= O.FASTCALL then register(pc, b) end
                    if op == O.FASTCALL2 then register(pc, bit32.band(aux, 255))
                    elseif op == O.FASTCALL2K then constant(pc, aux, "argument")
                    elseif op == O.FASTCALL3 then register(pc, bit32.band(aux, 255)); register(pc, bit32.band(bit32.rshift(aux, 8), 255)) end
                else
                    local custom = if customOpcodes then customOpcodes[op] else nil
                    if type(custom) == "table" then
                        if type(custom.validate) == "function" then
                            custom.validate(word, aux, pc, p, bad, register, window, constant, jump)
                        end
                    else
                        error(`unsupported opcode {O.names[op] or op} at {p.name}:{pc}`, 0)
                    end
                end
            end
            pc += effectiveLength(op)
        end
        for _, at in p.feedback or {} do
            if not starts[at] or bit32.band(code[at] or 0, 255) ~= O.CALLFB then bad(at, "feedback does not name a CALLFB instruction") end
        end
        if not G.terminal[last] then bad(count, "execution can run off the end of the function") end
    end
    return { protos = protos, main = main, version = version }
end

local defaultPrimitives
local function ensureInspectContext(context)
    if context and context.decode and context.oplength and context.opcodes then
        return context
    end
    if not defaultPrimitives then
        defaultPrimitives = makePrimitives()
    end
    local merged = if type(context) == "table" then table.clone(context) else {}
    merged.opcodes = merged.opcodes or Opcodes
    merged.oplength = merged.oplength or defaultPrimitives.ls_oplength
    merged.decode = merged.decode or decode
    return merged
end

local Bytecode = {
    decode = decode,
    decodeInstruction = Inspect.decodeInstruction,
    inspect = function(programOrBytes, context)
        return Inspect.inspect(programOrBytes, ensureInspectContext(context))
    end,
    hasOpcode = function(programOrBytes, opcodeNameOrId, context)
        return Inspect.hasOpcode(programOrBytes, opcodeNameOrId, ensureInspectContext(context))
    end,
    disassemble = function(programOrBytes, context)
        return Inspect.disassemble(programOrBytes, ensureInspectContext(context))
    end,
    check = function(programOrBytes, policy, context)
        return Inspect.check(programOrBytes, policy, ensureInspectContext(context))
    end,
}

return setmetatable(Bytecode, {
    __call = function(_, bytes, context)
        return decode(bytes, context)
    end,
})
