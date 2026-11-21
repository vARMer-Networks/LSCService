local roblox = script ~= nil
return if roblox then require(script.Parent.Select) else require("./Select")
