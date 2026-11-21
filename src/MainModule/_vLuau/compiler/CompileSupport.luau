-- Shared validation, narrow ABI marshaling and structured diagnostic results.
local Support = {}
function Support.options(options)
    assert(options==nil or type(options)=='table','compile options must be a table')
    if options == nil or next(options) == nil then
        return {optimizationLevel = 0, debugLevel = 0, coverageLevel = 0, typeInfoLevel = 0}
    end
    local hasOtherKeys = false
    for k in options do
        if k ~= "optimizationLevel" and k ~= "debugLevel" and k ~= "coverageLevel" and k ~= "raw" and k ~= "typeInfoLevel" then
            hasOtherKeys = true
            break
        end
    end
    if not hasOtherKeys then
        local opt = options.optimizationLevel
        local dbg = options.debugLevel
        local cov = options.coverageLevel
        local tip = options.typeInfoLevel
        local raw = options.raw
        if (opt == nil or (type(opt) == "number" and opt >= 0 and opt <= 2 and opt % 1 == 0))
            and (dbg == nil or (type(dbg) == "number" and dbg >= 0 and dbg <= 2 and dbg % 1 == 0))
            and (cov == nil or (type(cov) == "number" and cov >= 0 and cov <= 2 and cov % 1 == 0))
            and (tip == nil or (type(tip) == "number" and tip >= 0 and tip <= 1 and tip % 1 == 0))
            and (raw == nil or type(raw) == "boolean") then
            local out = {
                optimizationLevel = opt or 0,
                debugLevel = dbg or 0,
                coverageLevel = cov or 0,
                typeInfoLevel = tip or 0,
            }
            if raw ~= nil then out.raw = raw end
            return out
        end
    end
    options = table.clone(options)
    local optionBytes = 0
    for _, name in {'optimizationLevel','debugLevel','coverageLevel','typeInfoLevel'} do
        local v = options[name]
        local maximum = if name=='typeInfoLevel' then 1 else 2
        assert(v==nil or type(v)=='number' and v%1==0 and v>=0 and v<=maximum, `{name} is out of range`)
        options[name] = v or 0
    end
    for _, name in {'vectorLib','vectorCtor','vectorType','sourceName'} do
        local v = options[name]
        assert(v==nil or type(v)=='string' and #v<=4096 and not string.find(v,'\0',1,true), `{name} must be a bounded string without NUL`)
        if v then optionBytes+=#v+1 end
    end
    assert(options.vectorLib==nil or options.vectorCtor~=nil, 'vectorLib requires vectorCtor')
    for _, name in {'mutableGlobals','disabledBuiltins','userdataTypes'} do
        local v = options[name]
        if v~=nil then
            assert(type(v)=='table' and #v<=256, `{name} must be an array of at most 256 names`)
            local list = {}
            local count = 0
            for k, value in v do
                count+=1
                assert(type(k)=='number' and k%1==0 and k>=1 and k<=#v, `{name} must be a dense array`)
                assert(type(value)=='string' and #value>0 and #value<=4096 and not string.find(value,'\0',1,true), `{name} contains an invalid name`)
                list[k] = value
                optionBytes+=#value+5
            end
            assert(count==#v, `{name} must be a dense array`)
            options[name] = list
        end
    end
    assert(optionBytes<=65536,'compiler option strings exceed 64 KiB')
    if options.adaptiveConfig then options.adaptiveConfig = table.clone(options.adaptiveConfig) end
    for _,name in {'detailedTelemetry','profileCheckpoints','adaptive'} do
        assert(options[name]==nil or type(options[name])=='boolean', `{name} must be a boolean`)
    end
    local traceLimit=options.traceLimit
    assert(traceLimit==nil or type(traceLimit)=='number' and traceLimit%1==0 and traceLimit>=0 and traceLimit<=65536, 'invalid traceLimit')
    assert(options.raw==nil or type(options.raw)=='boolean', 'raw must be a boolean')
    return options
end

function Support.marshal(exports, mem, options)
    local size = 28
    for _, name in {'vectorLib','vectorCtor','vectorType'} do
        if options[name] then size += #options[name]+1 end
    end
    for _, name in {'mutableGlobals','disabledBuiltins','userdataTypes'} do
        local list = options[name]
        if list then
            size += (#list+1)*4+3
            for _, value in list do size += #value+1 end
        end
    end
    local pointer = exports.malloc(size)
    assert(pointer~=0, 'compiler option allocation failed')
    buffer.fill(mem,pointer,0,size)
    buffer.writeu32(mem,pointer,options.typeInfoLevel)
    local cursor = pointer+28
    local function text(value)
        local p = cursor
        buffer.writestring(mem,p,value)
        cursor += #value+1
        return p
    end
    for i,name in {'vectorLib','vectorCtor','vectorType'} do
        if options[name] then buffer.writeu32(mem,pointer+i*4,text(options[name])) end
    end
    for i,name in {'mutableGlobals','disabledBuiltins','userdataTypes'} do
        local list = options[name]
        if list then
            cursor = math.ceil(cursor/4)*4
            local array = cursor
            cursor += (#list+1)*4
            buffer.writeu32(mem,pointer+(i+3)*4,array)
            for j,value in list do buffer.writeu32(mem,array+(j-1)*4,text(value)) end
        end
    end
    assert(cursor<=pointer+size, 'compiler option ABI overflow')
    return pointer
end
function Support.hasExtra(options)
    return options.typeInfoLevel~=0 or options.vectorLib~=nil or options.vectorCtor~=nil or options.vectorType~=nil
        or options.mutableGlobals~=nil or options.disabledBuiltins~=nil or options.userdataTypes~=nil
end

function Support.diagnostic(exports, mem, sourceName)
    local category = exports.ls_diagnostic_field(0)
    if category==0 then return nil end
    return {category=if category==1 then 'syntax' else 'compile',
        message=buffer.readstring(mem,exports.ls_diagnostic_message(),exports.ls_diagnostic_message_size()),
        sourceName=sourceName,
        range={start={line=exports.ls_diagnostic_field(1),column=exports.ls_diagnostic_field(2)},
               finish={line=exports.ls_diagnostic_field(3),column=exports.ls_diagnostic_field(4)}}}
end

function Support.failure(message, sourceName)
    message = tostring(message)
    local resource = string.find(message,'memory limit',1,true) or string.find(message,'allocation failed',1,true)
    return {ok=false, diagnostic={category=if resource then 'resource' else 'internal',message=message,sourceName=sourceName}}
end
function Support.sourceName(options)
    return if type(options)=='table' and type(options.sourceName)=='string' then options.sourceName else nil
end
function Support.validation(message,sourceName)
    return {ok=false,diagnostic={category='validation',message=tostring(message),sourceName=sourceName}}
end
return Support
