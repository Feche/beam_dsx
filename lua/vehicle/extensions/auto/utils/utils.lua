-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local tick = require("vehicle.extensions.auto.utils.tick")

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

local function dumpex(t)
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

    print("-- variables: ") 
    table.sort(v)
    for i = 1, #v do 
        print(v[i]) 
    end 
    print("-- total variables: " ..#v)

    print("-- functions:") 
    table.sort(f)
    for i = 1, #f do 
        print(f[i]) 
    end 
    print("-- total functions: " ..#f)
end


local function getAirSpeed()
    return (electrics.values.airspeed or 0) * 3.6
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
    return (electrics.values.gearboxMode == "arcade" and isInReverse() == true)
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

local blinkPulse = 1
local absBlinkOffTimer = 0
local absBlinkTimer = 0
local absBlinkTime = 0.1
local absBlinkOffTime = 0.1
local absActiveSmoother = newTemporalSmoothing(2, 2)

local function isEmergencyBraking(force)
    local brake = utils.isBrakeThrottleInverted() and utils.getThrottle() or utils.getBrake()
    local adaptiveBrakeLights = force and true or ((controller.getAllControllers().adaptiveBrakeLights) and true or false)

    if(adaptiveBrakeLights == false or brake == 0) then
        return 1
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
--

return
{
    lerp = lerp,
    lerpRgb2 = lerpRgb2,
    lerpRgb3 = lerpRgb3,
    dumpex = dumpex,
    
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
}