-- SPDX-License-Identifier: MIT
return function(actor)
    local container = actor.Parent
    local reply = container.WorkerReply
    local started = os.clock()
    local ok, compiler, loadDone = pcall(function()
        local makeCompiler = require(script.Parent.TexereCompiler)
        local prewarm = container:GetAttribute("Prewarm") == true
        local compilerInstance = makeCompiler({
            memoryBytes = container:GetAttribute("MemoryBytes"),
            cacheBytes = 0,
            prewarm = prewarm,
        })
        local loaded = os.clock()
        return compilerInstance, loaded
    end)
    if not ok then
        reply:Fire(actor, 0, false, tostring(compiler))
        return
    end
    actor:BindToMessageParallel("Compile", function(id, source, options, structured)
        local begin = os.clock()
        local compiled, value = pcall(if structured then compiler.compileResult else compiler.compile, source, options)
        local compileMs = (os.clock() - begin) * 1000
        -- A guest abort invalidates its exports until the next request rebuilds it.
        local sampled, committed = pcall(compiler.committedMemoryBytes)
        local stats = {compileMs = compileMs, committedBytes = if sampled then committed else nil}
        task.synchronize()
        if actor.Parent == container and reply.Parent == container then
            stats.worker = actor.Name
            reply:Fire(actor, id, compiled, value, stats)
        end
    end)
    reply:Fire(actor, 0, true, {moduleRequireMs = (loadDone - started) * 1000,
        instanceMs = (os.clock() - loadDone) * 1000, committedBytes = compiler.committedMemoryBytes()})
end
