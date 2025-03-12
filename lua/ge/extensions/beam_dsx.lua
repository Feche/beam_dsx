local function onExtensionLoaded()
	print("[beam_dsx] GE: extension loaded")
end

local function onExtensionUnloaded()
	print("[beam_dsx] GE: extension unloaded")
end

local function onVehicleResetted(vehId)
	print("[beam_dsx] GE: vehicle reset")
end

local M = {}

M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
--M.onVehicleResetted = onVehicleResetted

return M