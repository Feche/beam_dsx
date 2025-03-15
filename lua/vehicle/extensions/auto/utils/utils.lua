local tick = require("vehicle.extensions.auto.utils.tick")

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function safeValue(input, max)
    max = max or 1000
    return math.max(1, math.min(max, input))
end

local function lerpRgb2(color1, color2, t)
    t = t < 0 and 0 or t
    t = t > 1 and 1 or t

    return { 
        lerp(safeValue(color1[1], 255), safeValue(color2[1], 255), t),
        lerp(safeValue(color1[2], 255), safeValue(color2[2], 255), t),
        lerp(safeValue(color1[3], 255), safeValue(color2[3], 255), t),
        lerp(safeValue(color1[4], 255), safeValue(color2[4], 255), t)
    }
end

local function lerpRgb3(color1, color2, color3, t)
    t = t < 0 and 0 or t
    t = t > 1 and 1 or t

    local segment = t * 2
    
    if segment < 1 then
        t = segment

        return {
            lerp(safeValue(color1[1], 255), safeValue(color2[1], 255), t),
            lerp(safeValue(color1[2], 255), safeValue(color2[2], 255), t),
            lerp(safeValue(color1[3], 255), safeValue(color2[3], 255), t),
            lerp(safeValue(color1[4], 255), safeValue(color2[4], 255), t)
        }
    else
        t = segment - 1

        return {
            lerp(safeValue(color2[1], 255), safeValue(color3[1], 255), t),
            lerp(safeValue(color2[2], 255), safeValue(color3[2], 255), t),
            lerp(safeValue(color2[3], 255), safeValue(color3[3], 255), t),
            lerp(safeValue(color2[4], 255), safeValue(color3[4], 255), t)
        }
    end
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
    return (electrics.values.engineRunning == 0) and false or true
end

local function isWheelSlip()
    local isWheelSlip = 0

    for i = 0, wheels.wheelRotatorCount - 1 do
        isWheelSlip = math.max(isWheelSlip, wheels.wheelRotators[i].lastSlip)
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

--[[local function isShifting()
    return electrics.values.isShifting or false
end]]

local function dumpTable(table)
    if(type(table) == "table") then
        local f = 0

        for key, value in pairs(table) do
            local isFunction = tostring(value):find("function")

            if(not isFunction) then
                print("key: " ..tostring(key).. ", value: " ..tostring(value))
            else
                f = f + 1
            end
        end

        print("-- " ..f.. " function(s)")
    else
        print("value: " ..tostring(table))
    end
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

local absBlinkTimer = 0
local absActiveSmoother = newTemporalSmoothing(2, 2)

local function isEmergencyBraking()
    local lights = electrics.values.brakelights
    local brake = utils.isBrakeThrottleInverted() and utils.getThrottle() or utils.getBrake()
    local adaptiveBrakeLights = (controller.getAllControllers().adaptiveBrakeLights) and true or false

    if(adaptiveBrakeLights == false or brake == 0) then
        return false
    end

    local dt = tick:getDt()
    local absActiveCoef = boolToNumber(electrics.values.absActive) or 0
    local absActive = absActiveSmoother:getUncapped(absActiveCoef, dt)

    absBlinkTimer = absBlinkTimer + dt * absActive

    -- 0.1 is the default BeamNG value for emergency stop blinking
    if absBlinkTimer > 0.1 then
        if(lights == 0) then
            return true
        end
    end

    return false
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

--[[local function isShootingFlames()
    local engine = powertrain.getDevice("mainEngine")

    --print("revLimiterAV: " ..engine.revLimiterAV)

    return false
end]]

local M = {}

M.lerp = lerp
M.lerpRgb2 = lerpRgb2
M.lerpRgb3 = lerpRgb3
M.safeValue = safeValue
M.dumpTable = dumpTable

M.isWheelMissing = isWheelMissing
M.isWheelSlip = isWheelSlip
M.isEngineOn = isEngineOn
--M.isShifting = isShifting
M.isEmergencyBraking = isEmergencyBraking
M.isElectric = isElectric
M.isBrakeThrottleInverted = isBrakeThrottleInverted
M.isAtRevLimiter = isAtRevLimiter
--M.isShootingFlames = isShootingFlames
M.isInReverse = isInReverse

M.getAirSpeed = getAirSpeed
M.getWheelSpeed = getWheelSpeed
M.getThrottle = getThrottle
M.getBrake = getBrake
M.getRpm = getRpm
M.getIdleRpm = getIdleRpm
M.getMaxRpm = getMaxRpm
M.getMaxAvailableRpm = getMaxAvailableRpm
M.getGear = getGear
M.getAbsCoef = getAbsCoef

return M