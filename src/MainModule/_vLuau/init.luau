--!strict
-- SPDX-License-Identifier: MIT
-- Luau² V3: Unified Self-Hosting Luau Compiler & Virtual Machine Runtime

local roblox = script ~= nil

-- 1. Base Runtime Engine
local Runtime = if roblox then require(script.LuauSquared) else require("./src/LuauSquared")

-- 2. Submodules
local Bytecode = if roblox then require(script.Bytecode) else require("./src/Bytecode")
local Patterns = if roblox then require(script.Patterns) else require("./src/Patterns")
local Licenses = if roblox then require(script.Licenses) else require("./src/Licenses")
local Registry = if roblox then require(script.Registry) else require("./src/Registry")
local GC = if roblox then require(script.GC) else require("./src/GC")
local Opcodes = if roblox then require(script.generated.Opcodes) else require("./src/generated/Opcodes")
local Customization = if roblox then require(script.Customization) else require("./src/Customization")

-- The source-compiler backend is configured in src/compiler/Backend.luau.
local CompilerBackend: string = if roblox then require(script.compiler.Backend) else require("./src/compiler/Backend")
local makeCompiler = if roblox then require(script.compiler.Select) else require("./src/compiler/Select")
local IncrementalCompiler: any = if roblox then require(script.compiler.TexereIncrementalCompiler) else require("./src/compiler/TexereIncrementalCompiler")
local ParallelCompiler: any = if roblox then require(script.compiler.TexereParallelCompiler) else require("./src/compiler/TexereParallelCompiler")
local profiles = if roblox then require(script.generated.texere.MemoryProfiles) else require("./src/generated/texere/MemoryProfiles")
local memoryProfiles = {}
for bytes in profiles do table.insert(memoryProfiles, bytes) end
table.sort(memoryProfiles)

-- 3. MainModule Facade
local MainModule = {}

-- Expose submodules directly on the main module
MainModule.Runtime = Runtime
MainModule.Bytecode = Bytecode
MainModule.Patterns = Patterns
MainModule.Licenses = Licenses
MainModule.Registry = Registry
MainModule.GC = GC
MainModule.Opcodes = Opcodes
MainModule.Extension = Customization.Extension
MainModule.Compat = Customization.Compat
MainModule.createProfile = Customization.createProfile
MainModule.Compiler = makeCompiler
MainModule.CompilerBackend = CompilerBackend
MainModule.CompilerCapabilities = table.freeze({
	backend = CompilerBackend,
	synchronousCompile = true,
	incrementalCompile = true,
	actorWorkers = true,
	actorTimeSlicing = false,
	memoryBytes = table.freeze(memoryProfiles),
	diagnostics = true,
	binarySource = true,
})
MainModule.IncrementalCompiler = IncrementalCompiler
MainModule.ParallelCompiler = ParallelCompiler

-- Constructor
MainModule.new = Runtime.new

-- Cached default compiler instance for instant top-level compilation (LuauCeption parity)
local defaultCompilerInstance = nil
local function getDefaultCompiler()
	if not defaultCompilerInstance then
		defaultCompilerInstance = makeCompiler()
	end
	return defaultCompilerInstance
end

-- Prewarm helpers for modular compiler chunks
function MainModule.prewarm(yieldFn: ((loaded: number, total: number) -> ())?): number
	local compiler = getDefaultCompiler()
	return makeCompiler.prewarm(compiler.factory, yieldFn)
end

function MainModule.prewarmCooperative(budgetMs: number?, yieldFn: (() -> ())?): number
	local compiler = getDefaultCompiler()
	return makeCompiler.prewarmCooperative(compiler.factory, budgetMs, yieldFn)
end

-- Top-level compile convenience method: compiles source code into raw bytecode string
function MainModule.compile(source: string, options: any?): string
	return getDefaultCompiler().compile(source, options)
end

-- Top-level execution convenience methods
function MainModule.execute(source: string, ...: any): ...any
	local vm = Runtime.new()
	return vm:execute(source, ...)
end

function MainModule.load(source: string, chunkName: string?, options: any?)
	local vm = Runtime.new()
	return vm:load(source, chunkName, options)
end

function MainModule.executeBytecode(bytecode: string, ...: any): ...any
	local vm = Runtime.new()
	return vm:executeBytecode(bytecode, ...)
end

-- Allow calling require(LuauSquared)(options) directly to create a new runtime
setmetatable(MainModule, {
	__call = function(_, ...)
		return Runtime.new(...)
	end,
	__index = Runtime,
})

return MainModule
