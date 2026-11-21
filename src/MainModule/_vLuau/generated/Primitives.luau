-- Luau² and Luau numeric primitives translated by Texere².
local factory = if script then require(script.Parent.texere.Primitives.Main) else require("./texere/Primitives/Main")
return function()
    local exports = factory.instantiate().exports
    exports.memoryBytes = exports.memory.size() * 65536
    exports.memory = nil
    return exports
end
