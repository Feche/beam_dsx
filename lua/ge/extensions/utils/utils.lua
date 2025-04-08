-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local function getVehicleName(vehID)
	local vehicle = be:getObjectByID(vehID or be:getPlayerVehicleID(0))

    if vehicle then
        return vehicle:getJBeamFilename() or "Unknown"
    end

    return "Unknown"
end

local function getAirSpeed()
    local playerVehicle = be:getPlayerVehicle(0)
    if(playerVehicle) then
        local vel = playerVehicle:getVelocity()
        return vec3(vel):length() * 3.6
    end
    return 0
end

local function saveJsonValue(file, key, value)
    if(not key or not value or not file) then
        return
    end

    local s = jsonReadFile(file)

    if(not s or (type(s) == "table" and not s[key])) then
        return
    end

    s[key] = value
    jsonWriteFile(file, s, true)
end

local function isIPv4(ip)
    local oct1, oct2, oct3, oct4 = ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if not (oct1 and oct2 and oct3 and oct4) then 
        return false 
    end
    return tonumber(oct1) <= 255 and tonumber(oct2) <= 255 and tonumber(oct3) <= 255 and tonumber(oct4) <= 255
end

return
{
    getVehicleName = getVehicleName,
    getAirSpeed = getAirSpeed,
    isIPv4 = isIPv4,
    saveJsonValue = saveJsonValue,
}