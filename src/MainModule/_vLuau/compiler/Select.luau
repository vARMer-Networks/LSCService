-- Chooses the source-compiler backend (Texere²).
-- `config.backend` overrides the build default in Backend.luau for one compiler instance.
local roblox = script ~= nil
local default = if roblox then require(script.Parent.Backend) else require("./Backend")

local function load(name)
    if name == "texere" then
        return if roblox then require(script.Parent.TexereCompiler) else require("./TexereCompiler")
    end
    error(`unknown compiler backend {tostring(name)}; expected "texere"`, 3)
end

return function(config)
    local name = if type(config) == "table" and config.backend ~= nil then config.backend else default
    return load(name)(config)
end
