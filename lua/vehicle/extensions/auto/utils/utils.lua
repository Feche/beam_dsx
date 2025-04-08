-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local controllers = require("vehicle.extensions.auto.utils.controllers")
local tick = require("common.tick")
local common = require("common.common")

-- Some of the code here has been extracted from adaptiveBrakeLights.lua since BeamNG 
-- does not report if the vehicle is currently on a emergency stop
local function boolToNumber(bool)
    if not bool then
        return
    end

    if type(bool) == "boolean" then
        return bool and 1 or 0
    end

    return bool
end

local adaptiveBrakeLights = controllers:getControllerData("adaptiveBrakeLights")
local blinkOnTime = adaptiveBrakeLights and adaptiveBrakeLights.blinkOnTime or 0.1
local blinkOffTime = adaptiveBrakeLights and adaptiveBrakeLights.blinkOffTime or 0.1

local blinkPulse = 1
local absBlinkOffTimer = 0
local absBlinkTimer = 0
local absBlinkTime = blinkOnTime
local absBlinkOffTime = blinkOffTime
local absActiveSmoother = newTemporalSmoothing(2, 2)

local function isEmergencyBraking(forced, adaptiveBrakeLightsState, brake)
    -- vehicle does not have adaptiveBrakeLights as controller, it is disabled or it is not forced
    if(brake == 0 or (not forced and not adaptiveBrakeLightsState)) then
        return
    end

    local dt = tick:getDt()
    local absActiveCoef = boolToNumber(electrics.values.absActive) or 0
    local absActive = absActiveSmoother:getUncapped(absActiveCoef, dt)

    if blinkPulse > 0 then
        absBlinkTimer = absBlinkTimer + dt * absActive

        if absBlinkTimer > absBlinkTime then
            absBlinkTimer = 0
            blinkPulse = 0
        end
    end

    if blinkPulse <= 0 then
        absBlinkOffTimer = absBlinkOffTimer + dt

        if absBlinkOffTimer > absBlinkOffTime then
            absBlinkOffTimer = 0
            blinkPulse = 1
        end
    end

    return blinkPulse
end

local function getAirSpeed()
    return math.max((electrics.values.airspeed or 1) * 3.6, 1)
end

local function getWheelSpeed()
    return (electrics.values.wheelspeed or 0) * 3.6
end

local function getThrottle()
    return input.state.throttle.val or 0
end

local function getBrake()
    return input.state.brake.val or 0
end

local function getRpm()
    return electrics.values.rpm or 0
end

local function getIdleRpm()
    return electrics.values.idlerpm or 0
end

local function getMaxRpm()
    return electrics.values.maxrpm or 0
end

local function getMaxAvailableRpm()
    local engine = powertrain.getDevice("mainEngine")
    return engine and engine.maxAvailableRPM or 0
end

local function getGearboxMode()
    return electrics.values.gearboxMode
end

local function getVehicleName()
    return v.config.model or v.config.mainPartName
end

local function isEngineOn()
    return (electrics.values.engineRunning == 1)
end

local function areHazardsEnabled()
    return (electrics.values.hazard_enabled == 1)
end

local function isWheelSlip()
    local isWheelSlip = 0

    for i = 0, wheels.wheelRotatorCount - 1 do
        if(wheels.wheelRotators[i].isPropulsed == true) then
            isWheelSlip = isWheelSlip + wheels.wheelRotators[i].lastSlip
        end
    end

    return isWheelSlip
end

local function getGear()
    local gearbox = powertrain.getDevice("gearbox")
    return gearbox and (gearbox.gearIndex or 0) or 0
end

local function isWheelMissing()
    for i = 0, wheels.wheelRotatorCount - 1 do
        if(wheels.wheelRotators[i].isBroken == true) then
            return true
        end
    end

    return false
end

local function getAbsCoef()
    if(electrics.values.hasABS == false) then
        return 1
    end

    local absCoef = 0

    for i = 0, wheels.wheelRotatorCount - 1 do
        absCoef = absCoef + wheels.wheelRotators[i].lastABSCoef
    end

    return (absCoef / 4)
end

local function isElectric()
    local devices = powertrain.getDevices()

    if(devices.frontMotor or devices.rearMotor) then
        return true
    end

    return false
end

local function isInReverse()
    return (electrics.values.reverse == 1) and true or false
end

local function isBrakeThrottleInverted()
    return (getGearboxMode() == "arcade" and isInReverse() == true)
end

local function isAtRevLimiter(random)
    local engine = powertrain.getDevice("mainEngine")

    if(engine and engine.revLimiterActive) then
        if(random == true or engine.revLimiterActiveTimer == nil) then
            return (math.random() > 0.5) and 1 or 0
        else
            return engine.revLimiterActiveTimer / engine.revLimiterCutTime
        end
    end

    return 0
end

local function getDriveModeColor(driveMode)
    local driveModes = controllers:getControllerData("driveModes")
    
    if(driveModes and driveModes.modes[driveMode]) then
        for i = 1, #driveModes.modes[driveMode].settings do
            local d = driveModes.modes[driveMode].settings[i][2]

            if(d and (d.controllerName == "gauge" or d.icon == "powertrain_esc")) then
                return common.hexToRGB(d.modeColor or d.color)
            end
        end
    end

    local esc = controllers:getControllerData("esc")

    if(esc) then
        return common.hexToRGB(esc.configurations[driveMode].activeColor)
    end
    return false
end

return
{
    isWheelMissing = isWheelMissing,
    isWheelSlip = isWheelSlip,
    isEngineOn = isEngineOn,
    isEmergencyBraking = isEmergencyBraking,
    isElectric = isElectric,
    isBrakeThrottleInverted = isBrakeThrottleInverted,
    isAtRevLimiter = isAtRevLimiter,
    isInReverse = isInReverse,
    areHazardsEnabled = areHazardsEnabled,
    
    getAirSpeed = getAirSpeed,
    getWheelSpeed = getWheelSpeed,
    getThrottle = getThrottle,
    getBrake = getBrake,
    getRpm = getRpm,
    getIdleRpm = getIdleRpm,
    getMaxRpm = getMaxRpm,
    getMaxAvailableRpm = getMaxAvailableRpm,
    getGear = getGear,
    getAbsCoef = getAbsCoef,
    getGearboxMode = getGearboxMode,
    getVehicleName = getVehicleName,
    getDriveModeColor = getDriveModeColor,
}