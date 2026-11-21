local source = script:GetAttribute("Source")
script:SetAttribute("Source", "")

local LuauSquared = require(script:WaitForChild("_vLuau"))
local runtime = LuauSquared.new()

runtime:execute(source)
