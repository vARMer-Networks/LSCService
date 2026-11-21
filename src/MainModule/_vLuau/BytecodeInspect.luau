-- Static bytecode inspection, disassembly, instruction decoding, and policy enforcement.
local roblox = script ~= nil
local O = if roblox then require(script.Parent.generated.Opcodes) else require("./generated/Opcodes")
local makePrimitives = if roblox then require(script.Parent.generated.Primitives) else require("./generated/Primitives")

local BytecodeInspect = {}
local cachedPrimitives
local opLengths = {}

local function defaultOpLength(op)
    local len = opLengths[op]
    if len ~= nil then
        return len
    end
    if not cachedPrimitives then
        cachedPrimitives = makePrimitives()
    end
    len = cachedPrimitives.ls_oplength(op)
    opLengths[op] = len
    return len
end

local function opName(op, opcodes, customOpcodes)
    local custom = if customOpcodes then customOpcodes[op] else nil
    if type(custom) == "table" and custom.name then
        return custom.name, true
    end
    local tbl = opcodes or O
    return tbl.names[op] or ("OP_" .. tostring(op)), false
end

function BytecodeInspect.decodeInstruction(word, aux, opcodes, customOpcodes)
    local op = bit32.band(word, 255)
    local a = bit32.band(bit32.rshift(word, 8), 255)
    local b = bit32.band(bit32.rshift(word, 16), 255)
    local c = bit32.rshift(word, 24)
    local d = bit32.rshift(word, 16)
    if d >= 32768 then
        d -= 65536
    end
    local e = bit32.rshift(word, 8)
    if e >= 8388608 then
        e -= 16777216
    end
    local name, isCustom = opName(op, opcodes, customOpcodes)
    local custom = if customOpcodes then customOpcodes[op] else nil
    local length = if type(custom) == "table" and custom.length then custom.length else (if aux ~= nil then 2 else 1)
    return {
        op = op,
        name = name,
        a = a,
        b = b,
        c = c,
        d = d,
        e = e,
        aux = aux,
        length = length,
        isCustom = isCustom,
    }
end

local function resolveProgram(programOrBytes, context)
    if type(programOrBytes) == "table" and programOrBytes.protos then
        return programOrBytes
    end
    assert(type(programOrBytes) == "string", "expected decoded program table or bytecode string")
    if context and type(context.decode) == "function" then
        return context.decode(programOrBytes, context)
    end
    error("bytecode inspection of raw bytes requires a decoder context", 2)
end

function BytecodeInspect.inspect(programOrBytes, context)
    local program = resolveProgram(programOrBytes, context)
    local opcodes = if context and context.opcodes then context.opcodes else O
    local customOpcodes = if context then context.customOpcodes else nil
    local oplength = if context and context.oplength then context.oplength else defaultOpLength

    local opcodeCounts = {}
    local opcodeIds = {}
    local globals = {}
    local globalsSeen = {}
    local imports = {}
    local importsSeen = {}
    local totalInstructions = 0
    local protoSummaries = {}

    for index, proto in program.protos do
        local code = proto.code
        local k = proto.constants
        local count = #code
        local pc = 1
        local pCount = 0
        local pOpcodes = {}
        local instructions = {}
        local pGlobals = {}
        local pImports = {}

        while pc <= count do
            local word = code[pc]
            local op = bit32.band(word, 255)
            local custom = if customOpcodes then customOpcodes[op] else nil
            local len = if type(custom) == "table" and custom.length then custom.length else oplength(op)
            local aux = if len == 2 then code[pc + 1] else nil
            local info = BytecodeInspect.decodeInstruction(word, aux, opcodes, customOpcodes)
            info.pc = pc
            info.line = if proto.lineinfo then proto.lineinfo[pc] else nil
            info.length = len

            pCount += 1
            totalInstructions += 1
            opcodeCounts[info.name] = (opcodeCounts[info.name] or 0) + 1
            opcodeIds[op] = (opcodeIds[op] or 0) + 1
            pOpcodes[info.name] = (pOpcodes[info.name] or 0) + 1
            instructions[#instructions + 1] = info

            if op == opcodes.GETGLOBAL or op == opcodes.SETGLOBAL then
                local gname = if aux then k[bit32.band(aux, 0xFFFFFF)] else nil
                if type(gname) == "string" then
                    pGlobals[#pGlobals + 1] = gname
                    if not globalsSeen[gname] then
                        globalsSeen[gname] = true
                        globals[#globals + 1] = gname
                    end
                end
            elseif op == opcodes.GETIMPORT then
                local imp = k[bit32.rshift(word, 16)]
                if type(imp) == "table" and imp.kind == "import" and aux then
                    local partsCount = bit32.rshift(aux, 30)
                    local parts = { k[bit32.band(bit32.rshift(aux, 20), 1023)] }
                    if partsCount >= 2 then
                        parts[2] = k[bit32.band(bit32.rshift(aux, 10), 1023)]
                    end
                    if partsCount >= 3 then
                        parts[3] = k[bit32.band(aux, 1023)]
                    end
                    local path = table.concat(parts, ".")
                    pImports[#pImports + 1] = path
                    if not importsSeen[path] then
                        importsSeen[path] = true
                        imports[#imports + 1] = path
                    end
                end
            end

            pc += len
        end

        protoSummaries[index] = {
            index = index,
            name = proto.debugname or proto.name,
            line = proto.line,
            stack = proto.stack,
            params = proto.params,
            upvalues = proto.upvalues,
            constantCount = proto.constantCount,
            instructionCount = pCount,
            opcodes = pOpcodes,
            globals = pGlobals,
            imports = pImports,
            instructions = instructions,
        }
    end

    table.sort(globals)
    table.sort(imports)
    return {
        version = program.version,
        main = program.main,
        protoCount = #program.protos,
        totalInstructions = totalInstructions,
        opcodes = opcodeCounts,
        opcodeIds = opcodeIds,
        globals = globals,
        imports = imports,
        protos = protoSummaries,
    }
end

function BytecodeInspect.hasOpcode(programOrBytes, opcodeNameOrId, context)
    local report = BytecodeInspect.inspect(programOrBytes, context)
    if type(opcodeNameOrId) == "number" then
        return (report.opcodeIds[opcodeNameOrId] or 0) > 0
    end
    return (report.opcodes[tostring(opcodeNameOrId)] or 0) > 0
end

function BytecodeInspect.disassemble(programOrBytes, context)
    local report = BytecodeInspect.inspect(programOrBytes, context)
    local lines = {
        string.format(
            "-- Luau bytecode v%s (%d protos, %d instructions)",
            tostring(report.version),
            report.protoCount,
            report.totalInstructions
        ),
    }
    for _, proto in report.protos do
        lines[#lines + 1] = string.format(
            "\n; proto %d%s (stack=%d params=%d upvalues=%d instructions=%d)",
            proto.index,
            if proto.name then " '" .. tostring(proto.name) .. "'" else "",
            proto.stack or 0,
            proto.params or 0,
            proto.upvalues or 0,
            proto.instructionCount
        )
        for _, instr in proto.instructions do
            lines[#lines + 1] = string.format(
                "  [%04d] L%-4s %-16s A=%-3d B=%-3d C=%-3d D=%-6d%s",
                instr.pc,
                if instr.line and instr.line > 0 then tostring(instr.line) else "-",
                instr.name,
                instr.a,
                instr.b,
                instr.c,
                instr.d,
                if instr.aux ~= nil then string.format(" AUX=0x%08X", instr.aux) else ""
            )
        end
    end
    return table.concat(lines, "\n")
end

local function makeLookupSet(list)
    if type(list) ~= "table" then
        return nil
    end
    local set = {}
    for k, v in list do
        if type(k) == "number" then
            set[v] = true
        elseif v then
            set[k] = true
        end
    end
    return set
end

function BytecodeInspect.check(programOrBytes, policy, context)
    if policy == nil then
        return true, {}
    end
    local program = resolveProgram(programOrBytes, context)
    local report = BytecodeInspect.inspect(program, context)
    local violations = {}

    local function addViolation(proto, instr, reason)
        violations[#violations + 1] = {
            proto = if proto then proto.index else 0,
            name = if proto then proto.name else nil,
            pc = if instr then instr.pc else 0,
            line = if instr then instr.line else nil,
            op = if instr then instr.op else nil,
            opcode = if instr then instr.name else nil,
            reason = reason,
        }
    end

    if policy.maxProtos and report.protoCount > policy.maxProtos then
        addViolation(nil, nil, `proto count {report.protoCount} exceeds limit {policy.maxProtos}`)
    end
    if policy.maxInstructions and report.totalInstructions > policy.maxInstructions then
        addViolation(
            nil,
            nil,
            `instruction count {report.totalInstructions} exceeds limit {policy.maxInstructions}`
        )
    end

    local allowSet = makeLookupSet(policy.allow)
    local denySet = makeLookupSet(policy.deny)
    local disallowGlobals = makeLookupSet(policy.disallowGlobals)
    local disallowImports = makeLookupSet(policy.disallowImports)
    local customCheck = if type(policy.custom) == "function" then policy.custom else nil

    for idx, pSummary in report.protos do
        local proto = program.protos[idx]
        if policy.maxConstants and (pSummary.constantCount or 0) > policy.maxConstants then
            addViolation(pSummary, nil, `constant count {pSummary.constantCount} exceeds limit {policy.maxConstants}`)
        end
        if policy.maxStack and (pSummary.stack or 0) > policy.maxStack then
            addViolation(pSummary, nil, `stack size {pSummary.stack} exceeds limit {policy.maxStack}`)
        end
        for _, instr in pSummary.instructions do
            if allowSet and not (allowSet[instr.name] or allowSet[instr.op]) then
                addViolation(pSummary, instr, `opcode '{instr.name}' is not in allowlist`)
            elseif denySet and (denySet[instr.name] or denySet[instr.op]) then
                addViolation(pSummary, instr, `opcode '{instr.name}' is denied by policy`)
            end
            if disallowGlobals and (instr.name == "GETGLOBAL" or instr.name == "SETGLOBAL") and instr.aux then
                local gname = proto.constants[bit32.band(instr.aux, 0xFFFFFF)]
                if type(gname) == "string" and disallowGlobals[gname] then
                    addViolation(pSummary, instr, `global '{gname}' is disallowed by policy`)
                end
            end
            if disallowImports and instr.name == "GETIMPORT" and instr.aux then
                local partsCount = bit32.rshift(instr.aux, 30)
                local k = proto.constants
                local parts = { k[bit32.band(bit32.rshift(instr.aux, 20), 1023)] }
                if partsCount >= 2 then
                    parts[2] = k[bit32.band(bit32.rshift(instr.aux, 10), 1023)]
                end
                if partsCount >= 3 then
                    parts[3] = k[bit32.band(instr.aux, 1023)]
                end
                local path = table.concat(parts, ".")
                if disallowImports[path] or disallowImports[parts[1]] then
                    addViolation(pSummary, instr, `import '{path}' is disallowed by policy`)
                end
            end
            if customCheck then
                local customReason = customCheck(proto, instr, program)
                if type(customReason) == "string" then
                    addViolation(pSummary, instr, customReason)
                end
            end
        end
    end

    return #violations == 0, violations
end

return table.freeze(BytecodeInspect)
