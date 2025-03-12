local currTick = 0
local currDt = 0
-- TODO: create as self version
return
{
	handleGameTick = function(dtSim)
		currTick = currTick + dtSim
		currDt = dtSim
	end,
	getTick = function()
		return currTick * 1000
	end,
	getDt = function()
		return currDt
	end
}