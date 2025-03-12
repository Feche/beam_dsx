local tick = require("vehicle.extensions.auto.utils.gameTick")

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpRgb(color1, color2, color3, t)
    local r, g, b = 0

    t = t < 0 and 0 or t
    t = t > 1 and 1 or t

    r = (t < 0.5) and lerp(color1[1], color2[1], t) or lerp(color2[1], color3[1], t)
    g = (t < 0.5) and lerp(color1[2], color2[2], t) or lerp(color2[2], color3[2], t)
    b = (t < 0.5) and lerp(color1[3], color2[3], t) or lerp(color2[3], color3[3], t)

    print("r: " ..r.. ", g: " ..g.. ", b: " ..b.. ", t: " ..t)

    return { r, g, b }
end

local function getAirSpeed()
    return (electrics.values.airspeed or 0) * 3.6
end

local function getWheelSpeed()
    return (electrics.values.wheelspeed or 0) * 3.6
end

local function safeValue(input, max)
    max = max or 1000
    return math.max(1, math.min(max, input))
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

local function isEngineOn()
    return electrics.values.running or false
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
    if(type(table) ~= "table") then
        print("[beam_dsx] VE: dumpTable: not a table (" ..type(table).. ")")
        return
    end

    for key, value in pairs(table) do
        print("key: " ..tostring(key).. ", value: " ..tostring(value))
    end
end

-- Used to detect emergency braking, please BeamNG add a variable that holds blinkPulse value
-- Code extracted from adaptiveBrakeLights.lua
local blinkPulse = 0
local absBlinkTimer = 0
local absBlinkTime = 0.1
local absBlinkOffTime = 0.1
local absBlinkOffTimer = 0

local function isEmergencyBraking_ex()
    local dt = tick.getDt()

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

    -- blinkPulse is 1 when no emergency braking, otherwise it's  0
    -- and check against brakelights since there is no way to get adaptiveBrakeLights isEnabled ?
    if((blinkPulse == 1)) then
        return false
    end

    return true
end

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
    local brake = utils.getBrake()
    local adaptiveBrakeLights = controller.getAllControllers().adaptiveBrakeLights and true or false

    if(adaptiveBrakeLights == false or brake == 0) then
        return
    end

    local dt = tick.getDt()

    local absActiveCoef = boolToNumber(electrics.values.absActive) or 0
    local absActive = absActiveSmoother:getUncapped(absActiveCoef, dt)
    absBlinkTimer = absBlinkTimer + dt * absActive

    if absBlinkTimer > 0.1 then
        if(lights == 0) then
            return true
        end
    end

    return false
end

local M = {}

M.lerp = lerp
M.getAirSpeed = getAirSpeed
M.getWheelSpeed = getWheelSpeed
M.safeValue = safeValue
M.getThrottle = getThrottle
M.getBrake = getBrake
M.getRpm = getRpm
M.isWheelSlip = isWheelSlip
M.getGear = getGear
M.isWheelMissing = isWheelMissing
M.dumpTable = dumpTable
M.getAbsCoef = getAbsCoef
M.isEngineOn = isEngineOn
--M.isShifting = isShifting
M.isEmergencyBraking = isEmergencyBraking
M.lerpRgb = lerpRgb

return M