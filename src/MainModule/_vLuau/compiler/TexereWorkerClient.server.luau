-- SPDX-License-Identifier: MIT
local actor = assert(script:GetActor(), "Texere worker must be inside an Actor")
local ref = actor.Parent.WorkerModule
require(ref.Value)(actor)
