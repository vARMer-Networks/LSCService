local roblox = script ~= nil
return if roblox then require(script.Parent.TexereIncrementalCompiler) else require("./TexereIncrementalCompiler")
