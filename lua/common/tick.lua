-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local tickRate = 16 -- milliseconds -- the rate at which commands sent to DualSenseX, default value targets 60fps, default: 16
local currTick = 0
local currDt = 0

return
{
	handleGameTick = function(self, dtSim)
		currTick = currTick + dtSim
		currDt = dtSim
	end,
	getTick = function(self)
		return currTick * 1000
	end,
	getDt = function(self)
		return currDt
	end,
	getTickRate = function(self)
		return tickRate 
	end,
	msToTickRate = function(self, ms)
		return ms / self:getTickRate()
	end,
	tickRateToMs = function(self, rate)
		return self:getTickRate() * rate
	end,
}