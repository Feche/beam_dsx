local settings = require("vehicle.extensions.auto.beam_dsx_settings")

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
		return settings.tickRate
	end,
	msToTickRate = function(self, ms)
		return ms / self.getTickRate()
	end,
	tickRateToMs = function(self, rate)
		return self.getTickRate() * rate
	end,
	getCurrTick = function(self)
		return self.currTick
	end
}