-- Customizable GC handler, weak reference tracker, finalizers, and memory pressure controller.
local GC = {}

function GC.new(config, runtime)
    config = config or {}
    local weakRefs = setmetatable({}, { __mode = "k" })
    local entries = {}
    local nextId = 0
    local tracked = 0
    local totalTracked = 0
    local totalFinalized = 0
    local totalCollections = 0
    local totalSweeps = 0
    local totalSteps = 0
    local stepAccumulator = 0
    local paused = false
    local disposed = false
    local gc = {}

    local function finalize(id, entry)
        entries[id] = nil
        tracked -= 1
        totalFinalized += 1
        if entry.finalizer then
            pcall(entry.finalizer, entry.meta, id)
        end
        if config.onFinalize then
            pcall(config.onFinalize, entry, gc)
        end
    end

    function gc:track(obj, finalizerOrMeta, meta)
        assert(not disposed, "GC handler has been disposed")
        assert(obj ~= nil, "cannot track nil")
        local fin = if type(finalizerOrMeta) == "function" then finalizerOrMeta else nil
        nextId += 1
        weakRefs[obj] = nextId
        entries[nextId] = {
            id = nextId,
            kind = type(obj),
            finalizer = fin,
            meta = if fin then meta else finalizerOrMeta,
        }
        tracked += 1
        totalTracked += 1
        return nextId
    end

    function gc:untrack(targetOrId)
        local id = if type(targetOrId) == "number" then targetOrId else weakRefs[targetOrId]
        if type(targetOrId) ~= "number" and targetOrId ~= nil then
            weakRefs[targetOrId] = nil
        end
        if id and entries[id] then
            entries[id] = nil
            tracked -= 1
            return true
        end
        return false
    end

    function gc:sweep()
        totalSweeps += 1
        local alive, dead = {}, {}
        for _, id in weakRefs do
            alive[id] = true
        end
        for id in entries do
            if not alive[id] then
                dead[#dead + 1] = id
            end
        end
        table.sort(dead)
        for _, id in dead do
            local entry = entries[id]
            if entry then
                finalize(id, entry)
            end
        end
        return #dead
    end

    function gc:getMemoryKB()
        if config.getMemoryKB then
            return config.getMemoryKB(gc, runtime)
        elseif collectgarbage then
            return collectgarbage("count")
        end
        return 0
    end

    function gc:checkPressure(usedBytes)
        if disposed then
            return false
        end
        local current = usedBytes or (gc:getMemoryKB() * 1024)
        local soft, hard = config.softLimitBytes, config.hardLimitBytes
        if soft and current > soft and config.onPressure then
            config.onPressure({ bytes = current, limit = soft, kind = "soft" }, gc)
        end
        if hard and current > hard then
            gc:collect("pressure")
            local after = if usedBytes ~= nil and not config.getMemoryKB
                then usedBytes
                else gc:getMemoryKB() * 1024
            if after > hard then
                if config.onLimitExceeded then
                    local handled = config.onLimitExceeded({ bytes = after, limit = hard, kind = "hard" }, gc)
                    if handled == true then
                        return true
                    end
                end
                error("LuauSquared memory limit exceeded", 0)
            end
        end
        return false
    end

    function gc:collect(reason)
        if disposed then
            return 0
        end
        totalCollections += 1
        if config.collect then
            config.collect("full", reason or "manual", gc)
        elseif collectgarbage then
            pcall(collectgarbage, "collect")
        end
        return gc:sweep()
    end

    function gc:step(work)
        if disposed or paused then
            return false
        end
        totalSteps += 1
        stepAccumulator += work or 1
        local interval = config.stepInterval or 1000
        if config.step then
            local finished = config.step(work or 1, gc)
            if stepAccumulator >= interval then
                stepAccumulator = 0
                gc:sweep()
            end
            return finished == true
        end
        if stepAccumulator >= interval then
            stepAccumulator = 0
            if collectgarbage then
                pcall(collectgarbage, "step", work or 0)
            end
            gc:sweep()
            return true
        end
        return false
    end

    function gc:pause()
        paused = true
        if config.collect then
            pcall(config.collect, "stop", "pause", gc)
        elseif collectgarbage then
            pcall(collectgarbage, "stop")
        end
    end

    function gc:resume()
        paused = false
        if config.collect then
            pcall(config.collect, "restart", "resume", gc)
        elseif collectgarbage then
            pcall(collectgarbage, "restart")
        end
    end

    function gc:isPaused()
        return paused
    end

    function gc:notifyAllocate(kind, obj, bytes, meta)
        if disposed then
            return
        end
        if config.onAllocate then
            config.onAllocate(kind, obj, bytes, meta, gc)
        end
        if config.softLimitBytes or config.hardLimitBytes then
            gc:checkPressure(nil)
        end
    end

    function gc:getStats()
        return {
            trackedCount = tracked,
            totalTracked = totalTracked,
            totalFinalized = totalFinalized,
            totalCollections = totalCollections,
            totalSweeps = totalSweeps,
            totalSteps = totalSteps,
            paused = paused,
            disposed = disposed,
            memoryKB = gc:getMemoryKB(),
        }
    end

    function gc:makeGuestCollectGarbage()
        return function(opt, arg)
            if config.guestCollectGarbage then
                return config.guestCollectGarbage(opt, arg, gc)
            end
            opt = if opt == nil then "collect" else opt
            assert(type(opt) == "string", "bad argument #1 to 'collectgarbage' (string expected)")
            if opt == "collect" then
                gc:collect("guest")
                return 0
            elseif opt == "count" then
                return gc:getMemoryKB()
            elseif opt == "step" then
                return gc:step(arg or 0)
            elseif opt == "stop" then
                gc:pause()
                return 0
            elseif opt == "restart" then
                gc:resume()
                return 0
            elseif opt == "isrunning" then
                return not paused
            end
            error(`invalid option '{opt}' to 'collectgarbage'`, 2)
        end
    end

    function gc:dispose()
        if disposed then
            return
        end
        disposed = true
        local ids = {}
        for id in entries do
            ids[#ids + 1] = id
        end
        table.sort(ids)
        for _, id in ids do
            finalize(id, entries[id])
        end
        table.clear(weakRefs)
    end

    function gc:isDisposed()
        return disposed
    end

    return table.freeze(gc)
end

return table.freeze(GC)
