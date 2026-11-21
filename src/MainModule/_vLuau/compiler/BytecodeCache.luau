-- Exact source keys; byte-limited LRU, including retained source/key bytes.
local Cache = {}
-- The compiler revision loads on first use when a caller does not supply one.
local Revision
Cache.__index = Cache

-- Precomputed cache key fragments for the 54 standard compiler option permutations
-- (optimizationLevel 0..2, debugLevel 0..2, coverageLevel 0..2, typeInfoLevel 0..1)
local standardKeyFragments = {}
for o = 0, 2 do
    standardKeyFragments[o] = {}
    for d = 0, 2 do
        standardKeyFragments[o][d] = {}
        for c = 0, 2 do
            standardKeyFragments[o][d][c] = {}
            for ti = 0, 1 do
                standardKeyFragments[o][d][c][ti] = string.format("{s10:debugLeveld%d;s13:coverageLeveld%d;s13:typeInfoLeveld%d;s17:optimizationLeveld%d;}", d, c, ti, o)
            end
        end
    end
end

local function encode(value, seen)
    local kind = type(value)
    if kind=='nil' then return 'n' end
    if kind=='boolean' then return if value then 't' else 'f' end
    if kind=='number' then return 'd'..tostring(value)..';' end
    if kind=='string' then return 's'..#value..':'..value end
    assert(kind=='table' and not seen[value], 'cache options must be acyclic data')
    seen[value] = true
    local items = {}
    for key in value do
        assert(type(key)=='string' or type(key)=='number', 'invalid cache option key')
        items[#items+1] = { key = key, enc = encode(key, seen) }
    end
    table.sort(items, function(a, b) return a.enc < b.enc end)
    local result = {'{'}
    for _, item in items do
        result[#result+1] = item.enc .. encode(value[item.key], seen)
    end
    seen[value] = nil
    result[#result+1] = '}'
    return table.concat(result)
end

function Cache.key(options, revision)
    if not revision then
        if not Revision then Revision = if script then require(script.Parent.Parent.generated.texere.Revision) else require('../generated/texere/Revision') end
        revision = Revision
    end
    if options == nil or next(options) == nil then
        return revision .. "{}"
    end
    local o = options.optimizationLevel
    local d = options.debugLevel
    local c = options.coverageLevel
    local ti = options.typeInfoLevel
    if o and d and c and ti and standardKeyFragments[o] and standardKeyFragments[o][d] and standardKeyFragments[o][d][c] and standardKeyFragments[o][d][c][ti] then
        if options.vectorLib == nil and options.vectorCtor == nil and options.vectorType == nil and options.sourceName == nil
            and options.mutableGlobals == nil and options.disabledBuiltins == nil and options.userdataTypes == nil
            and options.adaptiveConfig == nil and options.detailedTelemetry == nil and options.profileCheckpoints == nil
            and options.adaptive == nil and options.traceLimit == nil and options.raw == nil then
            return revision .. standardKeyFragments[o][d][c][ti]
        end
    end
    return revision..encode(options, {})
end
function Cache.new(maxBytes)
    maxBytes = if maxBytes==nil then 4*1024*1024 else maxBytes
    assert(type(maxBytes)=='number' and maxBytes%1==0 and maxBytes>=0 and maxBytes<=256*1024*1024, 'invalid cacheBytes')
    return setmetatable({limit=maxBytes,bytes=0,entries=0,hits=0,misses=0,evictions=0,sources={}},Cache)
end
function Cache:_unlink(entry)
    if entry.previous then entry.previous.next=entry.next else self.first=entry.next end
    if entry.next then entry.next.previous=entry.previous else self.last=entry.previous end
end
function Cache:_touch(entry)
    entry.previous=self.last
    entry.next=nil
    if self.last then self.last.next=entry else self.first=entry end
    self.last=entry
end
function Cache:get(source,key)
    local entry = self.sources[source] and self.sources[source][key]
    if not entry then self.misses+=1 return nil end
    self.hits+=1 self:_unlink(entry) self:_touch(entry)
    return entry.bytecode
end
function Cache:put(source,key,bytecode)
    local version = string.byte(bytecode)
    if not version or version < 9 or version > 14 then return end -- do not retain failures
    local size = #source+#key+#bytecode+128
    if size>self.limit then return end
    if self.sources[source] and self.sources[source][key] then return end
    while self.bytes+size>self.limit and self.first do
        local old = self.first
        self:_unlink(old)
        local group = self.sources[old.source]
        group[old.key]=nil
        if next(group)==nil then self.sources[old.source]=nil end
        self.bytes-=old.size self.entries-=1 self.evictions+=1
    end
    local entry={source=source,key=key,bytecode=bytecode,size=size}
    local group = self.sources[source] or {}
    self.sources[source]=group group[key]=entry
    self.bytes+=size self.entries+=1 self:_touch(entry)
end
function Cache:clear()
    self.sources={} self.first=nil self.last=nil self.bytes=0 self.entries=0
end
function Cache:stats()
    return {bytes=self.bytes,limitBytes=self.limit,entries=self.entries,hits=self.hits,misses=self.misses,evictions=self.evictions}
end
return Cache
