local ds = require("vehicle.extensions.auto.utils.ds")
local settings = require("vehicle.extensions.auto.beam_dsx_settings")
local tick = require("vehicle.extensions.auto.utils.tick")
local udp = require("vehicle.extensions.auto.utils.udp")
local utils = require("vehicle.extensions.auto.utils.utils")

local print_ = print
local function print(format, ...) print_(string.format(format, ...)) end

-- TODO: ***detect when script unloads | test dsx v2 compatibility

local dsxv2 =
{
    tick = 0,
    lastGear = 0,
    rgbTick = 0,
    parkingBrakeTick = 0,
    emergencyBraking = 0,
    hazardTick = 0,
    hazardState = 0,
    brakeRigidity = 0,
}

local function updateTriggerL(activeTrigger, throttle, brake, gear)
    local setting = nil
    local airSpeed = utils.getAirSpeed()

    -- Brake rigidity if wheel is missing
    setting = settings.brake.wheelMissing

    if(setting.enable) then
        if(utils.isWheelMissing() == true) then
            local force1 = 0
            local force2 = utils.safeValue(setting.maxForce, ds:safeValue("customTriggerValue", "max"))

            ds:sendDsx(0, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.rigid, force1, force2)
        end
    end

    -- Brake rigidity if engine is off
    setting = settings.brake.engineOff

    if(setting.enable) then
        if(utils.isEngineOn() == false) then
            local force1 = 0
            local force2 = utils.safeValue(setting.maxForce, ds:safeValue("customTriggerValue", "max"))

            ds:sendDsx(1, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.rigid, force1, force2)
        end
    end

    -- ABS vibration
    setting = settings.brake.abs

    if(setting.enable) then
        local absCoef = utils.getAbsCoef()

        if(absCoef < 1) then
            local minAmplitude = utils.safeValue(setting.minAmplitude, ds:safeValue("vibration", "maxAmplitude"))
            local maxAmplitude = utils.safeValue(setting.maxAmplitude, ds:safeValue("vibration", "maxAmplitude"))
            local minHz = utils.safeValue(setting.minHz, ds:safeValue("vibration", "maxHz"))
            local maxHz = utils.safeValue(setting.maxHz, ds:safeValue("vibration", "maxHz"))

            local progress = absCoef
            local startPos = math.min(9, ((dsxv2.brakeRigidity / 255) * 9) + 1)
            local amplitude = utils.lerp(maxAmplitude, minAmplitude, progress)
            local frequency = utils.lerp(minHz, maxHz, progress)

            ds:sendDsx(2, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.vibration, startPos, amplitude, frequency)
        end
    end
    
    -- Brake rigidity normal operation
    setting = settings.brake.rigidity

    if(setting.enable) then
        local maxForceAt = utils.safeValue(setting.maxForceAt)
        local minForce = utils.safeValue(setting.minForce, ds:safeValue("customTriggerValue", "max"))
        local maxForce = utils.safeValue(setting.maxForce, ds:safeValue("customTriggerValue", "max"))

        local progress = math.min(1, airSpeed / maxForceAt) * brake
        local force1 = 0
        local force2 = utils.lerp(minForce, maxForce, progress)

        dsxv2.brakeRigidity = force2

        ds:sendDsx(3, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.rigid, force1, force2)
    end

    ds:sendDsx(100, 1000, ds.type.triggerUpdate, activeTrigger, ds.mode.off)
end

local function updateTriggerR(activeTrigger, throttle, brake, gear)
    local setting = nil
    local wheelSpeed = utils.getWheelSpeed()

    -- Upshift vibration
    setting = settings.throttle.upShift
    
    if(setting.enable) then
        if(dsxv2.lastGear ~= gear and gear ~= 0 and throttle == 1) then
            local timeOn = utils.safeValue(setting.timeOn)
            local maxHz = utils.safeValue(setting.maxHz, ds:safeValue("customTriggerValue", "max"))
            local maxForce = utils.safeValue(setting.maxForce, ds:safeValue("customTriggerValue", "max"))

            local force1 = maxHz
            local force2 = maxForce
            local force3 = 135

            ds:sendDsx(0, tick:msToTickRate(timeOn), ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.vibrateResistance, force1, force2, force3)
        end

        dsxv2.lastGear = gear
    end

    -- Rev limiter vibration
    setting = settings.throttle.revLimit

    if(setting.enable) then
        local progress = utils.isAtRevLimiter()

        if(progress > 0 and throttle == 1) then 
            local timeOn = utils.safeValue(setting.timeOn)
            local minHz = utils.safeValue(setting.minHz, ds:safeValue("customTriggerValue", "max"))
            local maxHz = utils.safeValue(setting.maxHz, ds:safeValue("customTriggerValue", "max"))
            local maxForce = utils.safeValue(setting.maxForce, ds:safeValue("customTriggerValue", "max"))

            local force1 = utils.lerp(minHz, maxHz, progress)
            local force2 = maxForce
            local force3 = 135

            ds:sendDsx(1, tick:msToTickRate(timeOn), ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.vibrateResistance, force1, force2, force3)
        end
    end

    -- Wheelslip vibration
    setting = settings.throttle.wheelSlip

    if(setting.enable) then
        local isWheelSlip = utils.isWheelSlip()
        local tolerance = utils.safeValue(setting.tolerance)

        if(isWheelSlip >= tolerance and throttle == 1) then
            local maxForceAt = utils.safeValue(setting.maxForceAt)
            local minAmplitude = utils.safeValue(setting.minAmplitude, ds:safeValue("vibration", "maxAmplitude"))
            local maxAmplitude = utils.safeValue(setting.maxAmplitude, ds:safeValue("vibration", "maxAmplitude"))
            local minHz = utils.safeValue(setting.minHz, ds:safeValue("vibration", "maxHz"))
            local maxHz = utils.safeValue(setting.maxHz, ds:safeValue("vibration", "maxHz"))

            local progress = math.min(1, wheelSpeed / maxForceAt) * throttle
            local startPos = 1
            local amplitude = utils.lerp(minAmplitude, maxAmplitude, progress)
            local frequency = utils.lerp(minHz, maxHz, progress)

            ds:sendDsx(2, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.vibration, startPos, amplitude, frequency)
        end
    end

    -- Throttle rigidity if engine is off
    setting = settings.throttle.engineOff

    if(setting.enable) then
        if(utils.isEngineOn() == false) then
            ds:sendDsx(3, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.off)
        end
    end

    -- Throttle rigidity by speed
    setting = settings.throttle.rigidity.bySpeed

    if(setting.enable) then
        local minForce = utils.safeValue(setting.minForce, ds:safeValue("customTriggerValue", "max"))
        local maxForce = utils.safeValue(setting.maxForce, ds:safeValue("customTriggerValue", "max"))
        local minForceAt = utils.safeValue(setting.minForceAt)

        local progress = math.min(1, wheelSpeed / minForceAt)
        local force1 = 0
        local force2 = 0

        if(settings.inverted == false) then
            force2 = utils.lerp(maxForce, minForce, progress)
        else
            force2 = utils.lerp(minForce, maxForce, progress)
        end

        ds:sendDsx(4, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.rigid, force1, force2)
    end

    -- Throttle rigidity constant
    setting = settings.throttle.rigidity.constant

    if(setting.enable) then
        local minForce = utils.safeValue(setting.minForce, ds:safeValue("customTriggerValue", "max"))
        local maxForce = utils.safeValue(setting.maxForce, ds:safeValue("customTriggerValue", "max"))

        local force1 = 0
        local force2 = utils.lerp(minForce, maxForce, throttle)

        ds:sendDsx(5, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.rigid, force1, force2)
    end

    ds:sendDsx(100, 1000, ds.type.triggerUpdate, activeTrigger, ds.mode.off)
end

local function updateRgb(t, throttle, brake)
    local setting = nil

    -- RGB standby mode
    setting = settings.rgb

    if(setting.enable == false) then
        ds:sendDsx(0, 1, ds.type.rgbUpdate, setting.standbyColor[1], setting.standbyColor[2], setting.standbyColor[3], setting.standbyColor[4])
        return
    end

    -- micLed
    --
    -- Low fuel
    setting = settings.rgb.lowFuel

    if(setting.enable) then
        if(electrics.values.lowfuel == true) then
            local timeOn = utils.safeValue(setting.timeOn)
            local timeOff = utils.safeValue(setting.timeOff)
            local elapsed = (t - dsxv2.rgbTick) % (timeOn + timeOff)

            if(elapsed < timeOn)then
                ds:sendDsx(0, tick:msToTickRate(timeOn), ds.type.micLed, ds.micLed.on)
            else
                ds:sendDsx(0, tick:msToTickRate(timeOff), ds.type.micLed, ds.micLed.off)
            end
        else
            dsxv2.rgbTick = t
        end
    end

    -- Parking Brake
    setting = settings.rgb.parkingbrake

    if(setting.enable) then
        if(electrics.values.parkingbrake == 1) then
            local timeOn = utils.safeValue(setting.timeOn)
            local timeOff = utils.safeValue(setting.timeOff)
            local elapsed = (t - dsxv2.parkingBrakeTick) % (timeOn + timeOff)

            if(elapsed < timeOn)then
                ds:sendDsx(1, tick:msToTickRate(timeOn), ds.type.micLed, ds.micLed.on)
            else
                ds:sendDsx(1, tick:msToTickRate(timeOff), ds.type.micLed, ds.micLed.off)
            end
        else
            dsxv2.parkingBrakeTick = t
        end
    end

    -- TCS
    setting = settings.rgb.tcs

    if(setting.enable) then
        if(electrics.values.tcsActive == true and electrics.values.tcs == 1) then
            ds:sendDsx(2, 1, ds.type.micLed, ds.micLed.on)
        end
    end

    -- rgbUpdate
    --
    -- Reverse
    setting = settings.rgb.reverse

    if(setting.enable) then
        if(utils.isInReverse() == true) then
            ds:sendDsx(-1, 1, ds.type.rgbUpdate, setting.color[1], setting.color[2], setting.color[3], setting.color[4])
        end
    end

    -- Emergency braking
    setting = settings.rgb.emergencyBraking

    if(setting.enable) then
        if(utils.isEmergencyBraking() == true) then
            dsxv2.emergencyBraking = 1
            ds:sendDsx(0, 6, ds.type.rgbUpdate, setting.colorOn[1], setting.colorOn[2], setting.colorOn[3], setting.colorOn[4])
        elseif(dsxv2.emergencyBraking == 1) then
            dsxv2.emergencyBraking = 0
            ds:sendDsx(0, 6, ds.type.rgbUpdate, setting.colorOff[1], setting.colorOff[2], setting.colorOff[3], setting.colorOff[4])
        end
    end

    -- Hazard lights
    setting = settings.rgb.hazardLights

    if(setting.enable) then
        if(electrics.values.hazard_enabled > 0) then
            local turnOn = (electrics.values.signal_L == 1 or electrics.values.signal_R == 1)
            local elapsed = t - dsxv2.hazardTick

            if(turnOn == true and dsxv2.hazardState == 0) then
                dsxv2.hazardTick = t
                dsxv2.hazardState = 1
                elapsed = 0
            elseif(turnOn == false and dsxv2.hazardState == 1) then
                dsxv2.hazardTick = t
                dsxv2.hazardState = 0
                elapsed = 0
            end

            local progress = (dsxv2.hazardState == 0) and 1 - (elapsed / utils.safeValue(setting.timeOff)) or (elapsed / setting.timeOn)
            local color = utils.lerpRgb2(setting.colorOff, setting.colorOn, progress)

            ds:sendDsx(1, tick:msToTickRate(400), ds.type.rgbUpdate, color[1], color[2], color[3], color[4])
        else
            if(dsxv2.hazardState == 1) then
                dsxv2.hazardState = 0

                ds:sendDsx(1, 1, ds.type.rgbUpdate, setting.colorOff[1], setting.colorOff[2], setting.colorOff[3], setting.colorOff[4])
            end
        end
    end

    -- RGB tachometer
    setting = settings.rgb.tachometer

    if(setting.enable) then
        if(utils.isEngineOn() == true) then
            local progress = utils.isAtRevLimiter(false)

            if(progress > 0) then
                local color = ds:getColor()
                ds:sendDsx(2, 1, ds.type.rgbUpdate, color[1], color[2], color[3], 255 * progress)
            else
                local minRpm = utils.getIdleRpm()
                local maxRpm = utils.getMaxRpm()
                local rpm = utils.getRpm()

                local progress = 0

                if(rpm > setting.offset) then
                    progress = (rpm - setting.offset) / (maxRpm - setting.offset - minRpm)
                end

                local color = utils.lerpRgb3(setting.colorLow, setting.colorMed, setting.colorHi, progress)

                ds:sendDsx(2, 1, ds.type.rgbUpdate, color[1], color[2], color[3], color[4])
            end
        end
    end

    -- playerLed
    --
    -- ECS
    setting = settings.rgb.esc

    if(setting.enable) then
        if(electrics.values.escActive == true and electrics.values.esc == 1) then
            local timeOn = utils.safeValue(setting.timeOn)
            ds:sendDsx(0, tick:msToTickRate(timeOn), ds.type.playerLed, ds.playerLed.one)
        end
    end

    ds:sendDsx(100, 1000, ds.type.rgbUpdate, 0, 0, 0, 0)
    ds:sendDsx(100, 1000, ds.type.micLed, ds.micLed.off)
    ds:sendDsx(100, 1000, ds.type.playerLed, ds.playerLed.off)
end

local dumpTick = 0
local dumped = false
local function test()
    if(tick:getTick() - dumpTick >= 2000 and dumped == false) then
        print("-- dumping mainEngine.sustainedAfterFireFuelDelay:")
        utils.dumpTable(powertrain.getDevice("mainEngine").sustainedAfterFireFuelDelay.times)
        --dump(input)
        --dumpTick = tick:getTick()
        dumped = true
    end
end

local function updateGFX(dtSim)
    if(udp.ready() == nil) then 
        return 
    end

    if not playerInfo.firstPlayerSeated then
        return
    end

    --test()

    tick:handleGameTick(dtSim)

    local t = tick:getTick()

    if(t - dsxv2.tick > tick:getTickRate()) then
        dsxv2.tick = t

        local gear = utils.getGear()
        local inverted = utils.isBrakeThrottleInverted()
        local brake = inverted and utils.getThrottle() or utils.getBrake()
        local throttle = inverted and utils.getBrake() or utils.getThrottle()

        updateTriggerL(inverted and ds.trigger.right or ds.trigger.left, throttle, brake, gear)
        updateTriggerR(inverted and ds.trigger.left or ds.trigger.right, throttle, brake, gear)
        updateRgb(t, throttle, brake)

        local s = electrics.values
        --print(string.format("hasESC: %s, hasTCS: %s, escActive: %s, tcsActive: %s, esc: %s, tcs: %s, isYCBrakeActive: %s, isTCBrakeActive: %s, yawControlRequestReduceOversteer: %s", s.hasESC, s.hasTCS, s.escActive, s.tcsActive, s.esc, s.tcs, s.isYCBrakeActive, s.isTCBrakeActive, s.yawControlRequestReduceOversteer))
    end
end

local function onExtensionLoaded()
    print("[beam_dsx] VE: extension loading ..")
    -- Start udp socket
    udp.startUdp()
    -- Reset contoller state
    ds:resetController()

    print("[beam_dsx] VE: extension loaded.")
end

--[[local env = getfenv and getfenv(0); 
local cm = env and rawget(env, 'core_modmanager'); 
if cm then 
    local dm = cm.deactivateMod; 

    cm.deactivateMod = function(name) 
        if debug.getinfo(2,'S').short_src:find('MPModManager.lua') then 
            print("BeamMP tried to deactivate mod "..name.." but it was blocked"); 
            return; 
        end; 

        return dm(name); 
     end; 
end;]]

local M = {}

M.dependencies = {"ui_imgui"}
M.updateGFX = updateGFX
M.onExtensionLoaded = onExtensionLoaded

return M