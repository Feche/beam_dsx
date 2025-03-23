-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

return
{
	currTick = 0,
	currDt = 0,
	handleGameTick = function(self, dtSim)
		self.currTick = self.currTick + dtSim
		self.currDt = dtSim
	end,
	getTick = function(self)
		return self.currTick * 1000
	end,
	getDt = function(self)
		return self.currDt
	end,
	getTickRate = function(self)
		return 16 -- milliseconds -- the rate at which commands sent to DualSenseX, default value targets 60fps, default: 16, min: 8, max: 33
	end,
	msToTickRate = function(self, ms)
		return ms / self:getTickRate()
	end,
	tickRateToMs = function(self, rate)
		return self:getTickRate() * rate
	end,
	getCurrTick = function(self)
		return self.currTick
	end
}