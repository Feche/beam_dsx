local dualSense = require("vehicle.extensions.auto.utils.dualSense")
local settings = require("vehicle.extensions.auto.beam_dsx_settings")
local tick = require("vehicle.extensions.auto.utils.gameTick")
local udp = require("vehicle.extensions.auto.utils.udp")
local utils = require("vehicle.extensions.auto.utils.utils")

local print_ = print
local function print(format, ...) print_(string.format(format, ...)) end

-- TODO: github repo | ***detect when script unloads | GUI | test dsx v2 compatibility | esc, tcs led | improve rgb tachometer

local dsxv2 =
{
    tick = 0,
    lastGear = 0,
    rgbTick = 0,
    parkingBrakeTick = 0,
    emergencyBraking = 0,
}

local function triggerL(brake, activeTrigger, gear)
    local setting = nil
    local airSpeed = utils.getAirSpeed()

    -- Brake rigidity if wheel is missing
    setting = settings.brake.wheelMissing

    if(setting.enable) then
        if(utils.isWheelMissing() == true) then
            local force1 = 0
            local force2 = utils.safeValue(setting.maxForce, 255)

            dualSense:sendDsx(0, 100, dualSense.type.triggerUpdate, activeTrigger, dualSense.mode.customTriggerValue, dualSense.mode.custom.rigid, force1, force2)
        end
    end

    -- Brake rigidity if engine is off
    setting = settings.brake.engineOff

    if(setting.enable) then
        if(utils.isEngineOn() == false) then
            local force1 = 0
            local force2 = utils.safeValue(setting.maxForce, 255)

            dualSense:sendDsx(1, 100, dualSense.type.triggerUpdate, activeTrigger, dualSense.mode.customTriggerValue, dualSense.mode.custom.rigid, force1, force2)
        end
    end

    -- ABS vibration
    setting = settings.brake.abs

    if(setting.enable) then
        local absCoef = utils.getAbsCoef()

        if(absCoef < 1) then
            local minAmplitude = utils.safeValue(setting.minAmplitude, dualSense:safeValue("vibration", "maxAmplitude"))
            local maxAmplitude = utils.safeValue(setting.maxAmplitude, dualSense:safeValue("vibration", "maxAmplitude"))
            local minHz = utils.safeValue(setting.minHz, dualSense:safeValue("vibration", "maxHz"))
            local maxHz = utils.safeValue(setting.maxHz, dualSense:safeValue("vibration", "maxHz"))

            local progress = absCoef
            local startPos = 1
            local amplitude = utils.lerp(maxAmplitude, minAmplitude, progress)
            local frequency = utils.lerp(maxHz, minHz, progress)

            dualSense:sendDsx(2, 100, dualSense.type.triggerUpdate, activeTrigger, dualSense.mode.vibration, startPos, amplitude, frequency) -- TODO: test different duration
        end
    end
    
    -- Brake rigidity normal operation
    setting = settings.brake.rigidity

    if(setting.enable) then
        local maxForceAt = utils.safeValue(setting.maxForceAt)
        local minForce = utils.safeValue(setting.minForce, dualSense:safeValue("customTriggerValue", "maxForce"))
        local maxForce = utils.safeValue(setting.maxForce, dualSense:safeValue("customTriggerValue", "maxForce"))

        local progress = math.min(1, airSpeed / maxForceAt) * brake
        local force1 = 0
        local force2 = utils.lerp(minForce, maxForce, progress)

        dualSense:sendDsx(3, 100, dualSense.type.triggerUpdate, activeTrigger, dualSense.mode.customTriggerValue, dualSense.mode.custom.rigid, force1, force2)
    end
end

local function triggerR(throttle, activeTrigger, gear)
    local setting = nil
    local wheelSpeed = utils.getWheelSpeed()

    -- Upshift vibration
    setting = settings.throttle.gear
    
    if(setting.enable) then
        if(dsxv2.lastGear ~= gear and gear ~= 0 and throttle >= 0.1) then
            local duration = utils.safeValue(setting.duration)
            local force1 = utils.safeValue(setting.hz, dualSense:safeValue("customTriggerValue", "maxForce"))
            local force2 = utils.safeValue(setting.maxForce, dualSense:safeValue("customTriggerValue", "maxForce"))
            local force3 = 135

            dualSense:sendDsx(0, duration, dualSense.type.triggerUpdate, activeTrigger, dualSense.mode.customTriggerValue, dualSense.mode.custom.vibrateResistance, force1, force2, force3)
            --print("[beam_dsx] VE: upshift! (" ..gear.. ")")
        end

        dsxv2.lastGear = gear
    end

    -- Wheelslip vibration
    setting = settings.throttle.wheelslip

    if(setting.enable) then
        local isWheelSlip = utils.isWheelSlip()
        local tolerance = utils.safeValue(settings.throttle.wheelslip.tolerance)

        if(isWheelSlip >= tolerance and throttle >= 0.1) then
            local maxForceAt = utils.safeValue(setting.maxForceAt)
            local minAmplitude = utils.safeValue(setting.minAmplitude, dualSense:safeValue("vibration", "maxAmplitude"))
            local maxAmplitude = utils.safeValue(setting.maxAmplitude, dualSense:safeValue("vibration", "maxAmplitude"))
            local minHz = utils.safeValue(setting.minHz, dualSense:safeValue("vibration", "maxHz"))
            local maxHz = utils.safeValue(setting.maxHz, dualSense:safeValue("vibration", "maxHz"))

            local progress = math.min(1, wheelSpeed / maxForceAt) * throttle
            local startPos = 1
            local amplitude = utils.lerp(minAmplitude, maxAmplitude, progress)
            local frequency = utils.lerp(minHz, maxHz, progress)

            dualSense:sendDsx(1, 10, dualSense.type.triggerUpdate, activeTrigger, dualSense.mode.vibration, startPos, amplitude, frequency)
        end
    end

     -- Throttle rigidity if engine is off
    setting = settings.throttle.engineOff

    if(setting.enable) then
        if(utils.isEngineOn() == false) then
            dualSense:sendDsx(2, 100, dualSense.type.triggerUpdate, activeTrigger, dualSense.mode.off)
        end
    end

    -- Throttle rigidity by speed
    setting = settings.throttle.rigidity.bySpeed

    if(setting.enable) then
        local minForce = utils.safeValue(setting.minForce, dualSense:safeValue("customTriggerValue", "maxForce"))
        local maxForce = utils.safeValue(setting.maxForce, dualSense:safeValue("customTriggerValue", "maxForce"))
        local minForceAt = utils.safeValue(setting.minForceAt)

        local progress = math.min(1, wheelSpeed / minForceAt)
        local force1 = 1
        local force2 = 0

        if(settings.inverted == false) then
            force2 = utils.lerp(maxForce, minForce, progress)
        else
            force2 = utils.lerp(minForce, maxForce, progress)
        end

        dualSense:sendDsx(3, 100, dualSense.type.triggerUpdate, activeTrigger, dualSense.mode.customTriggerValue, dualSense.mode.custom.rigid, force1, force2)
    end

    -- Throttle rigidity constant
    setting = settings.throttle.rigidity.constant

    if(setting.enable) then
        local minForce = utils.safeValue(setting.minForce, dualSense:safeValue("customTriggerValue", "maxForce"))
        local maxForce = utils.safeValue(setting.maxForce, dualSense:safeValue("customTriggerValue", "maxForce"))

        local force1 = 0
        local force2 = utils.lerp(minForce, maxForce, throttle)

        dualSense:sendDsx(4, 100, dualSense.type.triggerUpdate, activeTrigger, dualSense.mode.customTriggerValue, dualSense.mode.custom.rigid, force1, force2)
    end
end

local function rgbUpdate(tick, throttle, brake)
    local setting = nil

    -- RGB standby mode
    setting = settings.rgb

    if(setting.enable == false) then
        dualSense:sendDsx(0, 1000, dualSense.type.rgbUpdate, setting.standbyColor[1], setting.standbyColor[2], setting.standbyColor[3], setting.standbyColor[4])
        return
    end

    -- Parking Brake
    setting = settings.rgb.parkingbrake

    if(setting.enable) then
        if(electrics.values.parkingbrake == 1) then
            local elapsed = (tick - dsxv2.parkingBrakeTick) % (setting.timeOn + setting.timeOff)

            if(elapsed < setting.timeOn)then
                dualSense:sendDsx(0, setting.timeOn, dualSense.type.micLed, dualSense.micLed.on)
            else
                dualSense:sendDsx(0, setting.timeOff, dualSense.type.micLed, dualSense.micLed.off)
            end
        else
            dsxv2.parkingBrakeTick = tick
        end
    end

    -- Low fuel
    setting = settings.rgb.lowFuel

    if(setting.enable) then
        if(electrics.values.lowfuel == true) then
            local elapsed = (tick - dsxv2.rgbTick) % (setting.timeOn + setting.timeOff)

            if(elapsed < setting.timeOn)then
                dualSense:sendDsx(1, setting.timeOn, dualSense.type.micLed, dualSense.micLed.on)
            else
                dualSense:sendDsx(1, setting.timeOff, dualSense.type.micLed, dualSense.micLed.off)
            end
        else
            dsxv2.rgbTick = tick
        end
    end

    -- Emergency braking
    setting = settings.rgb.emergencyBraking

    if(setting.enable) then
        if(utils.isEmergencyBraking() == true) then
            dualSense:sendDsx(0, 100, dualSense.type.rgbUpdate, setting.colorOn[1], setting.colorOn[2], setting.colorOn[3], setting.colorOn[4])
            dsxv2.emergencyBraking = 1
        elseif(dsxv2.emergencyBraking == 1) then
            dualSense:sendDsx(0, 100, dualSense.type.rgbUpdate, setting.colorOff[1], setting.colorOff[2], setting.colorOff[3], setting.colorOff[4])
            dsxv2.emergencyBraking = 0
        end
    end

    -- Hazard lights
    setting = settings.rgb.hazardLights

    if(setting.enable) then
        if(electrics.values.hazard_enabled > 0) then
            if(electrics.values.signal_L == 1 or electrics.values.signal_R == 1) then
                dualSense:sendDsx(1, 1000, dualSense.type.rgbUpdate, setting.colorOn[1], setting.colorOn[2], setting.colorOn[3], setting.colorOn[4])
            else
                dualSense:sendDsx(1, 1000, dualSense.type.rgbUpdate, setting.colorOff[1], setting.colorOff[2], setting.colorOff[3], setting.colorOff[4])
            end
        end
    end

    -- RGB tachometer
    setting = settings.rgb.tachometer

    if(setting.enable) then
        local minRpm = electrics.values.idlerpm
        local maxRpm = electrics.values.maxrpm
        local rpm = electrics.values.rpm

        local progress = (rpm - minRpm) / (maxRpm - minRpm)
        local color = utils.lerpRgb(setting.colorLow, setting.colorMed, setting.colorHi, progress)

        dualSense:sendDsx(2, 100, dualSense.type.rgbUpdate, color[1], color[2], color[3], 255)
    end

    dualSense:sendDsx(100, 1000, dualSense.type.rgbUpdate, 0, 0, 0, 0)
    dualSense:sendDsx(100, 1000, dualSense.type.micLed, dualSense.micLed.off)
end

local dumpTick = 0
local dumped = false
local function test()
    if(tick.getTick() - dumpTick >= 2000 and dumped == false) then
        local allControllers = controller.getAllControllers()
        print("-- dumping allControllers:")
        --utils.dumpTable(v.data.controller)
        dump(allControllers)
        --dumpTick = tick.getTick()
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

    tick.handleGameTick(dtSim)

    local tick = tick.getTick()

    -- Update at 30fps
    if(tick - dsxv2.tick > 0.0333) then
        dsxv2.tick = tick

        local brake = utils.getBrake()
        local throttle = utils.getThrottle()
        local activeTriggerBrake = dualSense.trigger.left
        local activeTriggerThrottle = dualSense.trigger.right
        local gear = utils.getGear()

        if(electrics.values.gearboxMode == "arcade") then
            if(gear < 0 and utils.getWheelSpeed() > 0) then
                activeTriggerBrake = dualSense.trigger.right
                activeTriggerThrottle = dualSense.trigger.left

                throttle = utils.getBrake()
                brake = utils.getThrottle()
            end
        end

        triggerL(brake, activeTriggerBrake, gear)
        triggerR(throttle, activeTriggerThrottle, gear)
        rgbUpdate(tick, throttle, brake)
    end

   -- print("electrics.values.esc: " ..electrics.values.esc.. ", electrics.values.tcs: " ..electrics.values.tcs)
end

local function onExtensionLoaded()
    -- Start udp socket
    udp.startUdp()
    -- Reset contoller state
    dualSense:resetController()

    print("[beam_dsx] VE: extension loaded")
end

local M = {}

M.updateGFX = updateGFX
M.onExtensionLoaded = onExtensionLoaded

return M