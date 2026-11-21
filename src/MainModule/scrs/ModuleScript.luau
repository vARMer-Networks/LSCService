local source = script:GetAttribute("Source")
script:SetAttribute("Source", "")

local LuauSquared = require(script:WaitForChild("_vLuau"))
local runtime = LuauSquared.new()

return runtime:execute(source)
