-- General, namespaced, metatable, and host-function registries for Luau² runtimes.
local Registry = {}
local REGISTRY_TAG = table.freeze({})

function Registry.isRegistry(value)
    return type(value) == "table" and rawget(value, "__luauSquaredRegistry") == REGISTRY_TAG
end

function Registry.new(initial)
    local store = {}
    local listeners = {}
    local refs = {}
    local weakTables = {}
    local nextId = 0

    if type(initial) == "table" then
        for key, value in initial do
            store[key] = value
        end
    end

    local function emit(fullKey, nextValue, prevValue)
        for index = 1, #listeners do
            local listener = listeners[index]
            if listener then
                listener(fullKey, nextValue, prevValue)
            end
        end
    end

    local function makeScope(prefix)
        local prefixLen = if prefix then #prefix else 0
        local function qualify(key)
            return if prefix then prefix .. tostring(key) else key
        end
        local function matches(fullKey)
            return not prefix or (type(fullKey) == "string" and string.sub(fullKey, 1, prefixLen) == prefix)
        end
        local function unqualify(fullKey)
            return if prefix then string.sub(fullKey, prefixLen + 1) else fullKey
        end
        local function put(fullKey, value)
            local prev = store[fullKey]
            store[fullKey] = value
            emit(fullKey, value, prev)
            return value
        end

        local api = {}
        function api:get(key)
            return store[qualify(key)]
        end
        function api:has(key)
            return store[qualify(key)] ~= nil
        end
        function api:set(key, value)
            return put(qualify(key), value)
        end
        function api:delete(key)
            local fk = qualify(key)
            if store[fk] == nil then
                return false
            end
            put(fk, nil)
            return true
        end
        function api:getOrCreate(key, factory)
            local fk = qualify(key)
            local existing = store[fk]
            if existing ~= nil then
                return existing
            end
            assert(type(factory) == "function", "getOrCreate expects a factory function")
            return put(fk, factory(key))
        end
        function api:keys()
            local out = {}
            for fullKey in store do
                if matches(fullKey) then
                    out[#out + 1] = unqualify(fullKey)
                end
            end
            return out
        end
        function api:values()
            local out = {}
            for fullKey, value in store do
                if matches(fullKey) then
                    out[#out + 1] = value
                end
            end
            return out
        end
        function api:count()
            local n = 0
            for fullKey in store do
                if matches(fullKey) then
                    n += 1
                end
            end
            return n
        end
        function api:snapshot()
            local out = {}
            for fullKey, value in store do
                if matches(fullKey) then
                    out[unqualify(fullKey)] = value
                end
            end
            return out
        end
        function api:clear()
            for _, key in api:keys() do
                api:delete(key)
            end
        end
        function api:weak(name, mode)
            local fk = qualify(name)
            local existing = weakTables[fk]
            if existing then
                return existing
            end
            mode = mode or "k"
            assert(mode == "k" or mode == "v" or mode == "kv", "weak mode must be 'k', 'v', or 'kv'")
            local created = setmetatable({}, { __mode = mode })
            weakTables[fk] = created
            return created
        end
        function api:onChange(listener)
            assert(type(listener) == "function", "onChange expects a listener function")
            local index = #listeners + 1
            listeners[index] = function(fk, nextVal, prevVal)
                if matches(fk) then
                    listener(unqualify(fk), nextVal, prevVal)
                end
            end
            return function()
                listeners[index] = false
            end
        end
        return api
    end

    local root = makeScope(nil)
    root.__luauSquaredRegistry = REGISTRY_TAG
    function root:isRegistry(value)
        return Registry.isRegistry(value)
    end
    function root:ref(value)
        assert(value ~= nil, "cannot register nil reference")
        nextId += 1
        refs[nextId] = value
        return nextId
    end
    function root:getRef(id)
        return refs[id]
    end
    function root:unref(id)
        local prev = refs[id]
        refs[id] = nil
        return prev
    end
    function root:namespace(prefix)
        assert(type(prefix) == "string" and #prefix > 0, "namespace prefix must be a non-empty string")
        return table.freeze(makeScope(prefix .. ":"))
    end
    return table.freeze(root)
end

function Registry.newMetatableRegistry(backingWeakTable)
    local store = backingWeakTable or setmetatable({}, { __mode = "kv" })
    local api = {}
    function api:register(object, metatable)
        assert(object ~= nil, "expected object or userdata")
        assert(type(metatable) == "table", "expected metatable table")
        store[object] = metatable
        return metatable
    end
    function api:get(object)
        return store[object]
    end
    function api:unregister(object)
        local prev = store[object]
        store[object] = nil
        return prev ~= nil
    end
    function api:has(object)
        return store[object] ~= nil
    end
    return table.freeze(api)
end

function Registry.newFunctionRegistry(cInfoTable, hostOriginsTable)
    local cInfo = cInfoTable or setmetatable({}, { __mode = "k" })
    local origins = hostOriginsTable or setmetatable({}, { __mode = "k" })
    local api = {}
    function api:register(fn, info)
        assert(type(fn) == "function", "expected function")
        assert(type(info) == "table", "expected info table")
        cInfo[fn] = info
        return info
    end
    function api:get(fn)
        return cInfo[fn]
    end
    function api:setOrigin(wrapper, origin)
        assert(type(wrapper) == "function", "expected wrapper function")
        origins[wrapper] = origin
        return origin
    end
    function api:getOrigin(wrapper)
        return origins[wrapper]
    end
    return table.freeze(api)
end

return table.freeze(Registry)
