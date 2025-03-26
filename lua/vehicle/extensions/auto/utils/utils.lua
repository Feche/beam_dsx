-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local controllers = require("vehicle.extensions.auto.utils.controllers")
local tick = require("vehicle.extensions.auto.utils.tick")

function dumpex(t)
    if(type(t) == "userdata") then
        local meta = getmetatable(t)
        if meta then
            for k, v in pairs(meta) do
                print(k, v)
            end
        end
        return
    elseif(type(t) ~= "table") then
        return print(type(t).. ": " ..tostring(t))
    end

    local f = {}
    local v = {}
    
    for key, value in pairs(t) do 
        value = tostring(value)
        if value:find("function") then 
            table.insert(f, tostring(key).. ": " ..tostring(value)) 
        else 
            table.insert(v, tostring(key).. ": " ..tostring(value)) 
        end
    end 

    print("-- variables -- ") 
    table.sort(v)
    for i = 1, #v do 
        print(v[i]) 
    end 
    print("- total variables: " ..#v)

    print(" ")

    print("-- functions --") 
    table.sort(f)
    for i = 1, #f do 
        print(f[i]) 
    end 
    print("- total functions: " ..#f)
    print(" ")
end

local function deep_copy_safe(t, skip)
    if(type(t) == "table") then
        local copy = {}
        for key, value in pairs(t) do
            if((type(value) == "number" or type(value) == "string" or type(value) == "boolean" or type(value) == "table") and key ~= skip) then
                copy[key] = (type(value) == "table") and deep_copy_safe(value) or value
            end
        end
        return copy
    end
    return nil
end

local function lerpNonLineal(start, finish, progress, steepness)
    return start + (finish - start) * (progress ^ steepness)
end

local function lerp(a, b, t)
    t = t < 0 and 0 or t
    t = t > 1 and 1 or t
    return a + (b - a) * t
end

local function lerpRgb2(color1, color2, t)
    return 
    { 
        lerp(color1[1], color2[1], t),
        lerp(color1[2], color2[2], t),
        lerp(color1[3], color2[3], t),
        lerp(color1[4], color2[4], t)
    }
end

local function lerpRgb3(color1, color2, color3, t)
    t = t < 0 and 0 or t
    t = t > 1 and 1 or t

    local segment = t * 2
    
    if segment < 1 then
        t = segment

        return {
            lerp(color1[1], color2[1], t),
            lerp(color1[2], color2[2], t),
            lerp(color1[3], color2[3], t),
            lerp(color1[4], color2[4], t)
        }
    else
        t = segment - 1

        return {
            lerp(color2[1], color3[1], t),
            lerp(color2[2], color3[2], t),
            lerp(color2[3], color3[3], t),
            lerp(color2[4], color3[4], t)
        }
    end
end

local function bounceLerp(t, bounces)
    t = t < 0 and 0 or t
    t = t > 1 and 1 or t
    return math.abs(math.sin(t * math.pi * bounces))
end

local function hexToRGB(hex)
    hex = hex:gsub("#", "")
    return { tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16) }
end

--

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

local inspectLast = nil
local inspectTick = 0

local function inspect(table, speed)
    if(not table) then
        return
    end

    if(type(table) ~= "table") then
        return print(tostring(table))
    end

    local t = tick:getTick()
    
    if((t - inspectTick) >= (speed or 1000)) then
        inspectTick = t

        if(not inspectLast) then
            inspectLast = deep_copy_safe(table)
            return
        end

        print(" ")

        local changes = 0

        for key, value in pairs(table) do
            if(type(value) ~= "table" and value ~= inspectLast[key]) then
                changes = changes + 1

                print(key.. " changed its value from '" ..tostring(inspectLast[key]).. "' to '" ..tostring(value).. "'")
            end
        end

        print("-- " ..changes.. " changes ocurred in the last " ..speed.. " ms.")

        inspectLast = deep_copy_safe(table)
    end
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

local function getDriveModeColor(driveMode)
    local driveModes = controllers:getControllerData("driveModes")
    
    if(driveModes) then
        for i = 1, #driveModes.modes[driveMode].settings do
            local d = driveModes.modes[driveMode].settings[i][2]

            if(d and (d.controllerName == "gauge" or d.icon == "powertrain_esc")) then
                return hexToRGB(d.modeColor or d.color)
            end
        end
    end

    local esc = controllers:getControllerData("esc")

    if(esc) then
        return hexToRGB(esc.configurations[driveMode].activeColor)
    end
    return false
end

return
{
    deep_copy_safe = deep_copy_safe,
    lerpNonLineal = lerpNonLineal,
    lerp = lerp,
    lerpRgb2 = lerpRgb2,
    lerpRgb3 = lerpRgb3,
    bounceLerp = bounceLerp,
    dumpex = dumpex,
    inspect = inspect,
    hexToRGB = hexToRGB,
    
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