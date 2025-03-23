-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local ds = require("vehicle.extensions.auto.utils.ds")
local tick = require("vehicle.extensions.auto.utils.tick")
local udp = require("vehicle.extensions.auto.utils.udp")
local utils = require("vehicle.extensions.auto.utils.utils")
local settings = nil

local dsxv2 =
{
    lastGear = 0,
    brakeRigidity = 0,

    gfxTick = 0,
    saveTick = 0,
    hazardTick = 0,
    lowFuelTick = 0,
    parkingBrakeTick = 0,
    emergencyBraking = false,

    hazardState = false,
    profileColor = nil,
    mailboxLast = nil
}

local function onExtensionLoaded()
    log("I", "onExtensionLoaded", "[beam_dsx] VE: extension loaded.")
end

local function onReceiveMailbox(buffer)
    local mailbox = jsonDecode(buffer)

    if(mailbox.playerVehicleId ~= obj:getID()) then
        return
    end

    log("W", "onReceiveMailbox", "[beam_dsx] VE: received mailbox '" ..mailbox.code.. "' ..")

    if(mailbox.code == "mod_enable_disable") then
        settings = nil
        ds:resetController()
        log("W", "onReceiveMailbox", "[beam_dsx] VE: mod disabled ..")
    elseif(mailbox.code == "save" or mailbox.code == "profile_change" or mailbox.code == "vehicle_reset" or mailbox.code == "vehicle_switch") then
        -- Start udp socket
        udp.startUdp()
        -- Reset contoller state
        ds:resetController()

        local p = jsonReadFile(mailbox.path)
        settings = p.profiles[p.active].settings
        dsxv2.profileColor = p.profiles[p.active].color

        if(not settings) then
            return log("E", "onReceiveMailbox", "[beam_dsx] VE: could not load settings file '" ..mailbox.path.. "''")
        end

        dsxv2.saveTick = tick:getTick()

        log("I", "onReceiveMailbox", "[beam_dsx] VE: applying user config, profile '" ..p.profiles[p.active].name.. "' ..")
    end
end

local function updateTriggerL(activeTrigger, throttle, brake, gear)
    -- Brake disabled
    if(settings.brake.enable == false) then
        ds:sendDsx(0, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.off)
        return
    end

    local setting = nil
    local airSpeed = utils.getAirSpeed()

    airSpeed = airSpeed < 1 and 1 or airSpeed

    -- Brake rigidity if wheel is missing
    setting = settings.brake.wheelMissing

    if(setting.enable) then
        if(utils.isWheelMissing() == true) then
            local force1 = 0
            local force2 = setting.maxForce

            ds:sendDsx(0, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.rigid, force1, force2)
            return
        end
    end

    -- Brake rigidity if engine is off
    setting = settings.brake.engineOff

    if(setting.enable) then
        if(utils.isEngineOn() == false) then
            local force1 = 0
            local force2 = setting.maxForce

            ds:sendDsx(1, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.rigid, force1, force2)
            return
        end
    end

    -- ABS vibration
    setting = settings.brake.abs

    if(setting.enable) then
        local absCoef = utils.getAbsCoef()

        if(absCoef ~= 0 and absCoef ~= 1) then
            local minAmplitude = setting.minAmplitude
            local maxAmplitude = setting.maxAmplitude
            local minHz = setting.minHz
            local maxHz = setting.maxHz
            
            local progress = 1 - absCoef
            local startPos = math.min(9, ((dsxv2.brakeRigidity / 255) * 9) + 1)
            local amplitude = utils.lerp(maxAmplitude, minAmplitude, progress)
            local frequency = utils.lerp(minHz, maxHz, progress)

            ds:sendDsx(2, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.vibration, startPos, amplitude, frequency)
            return
        end
    end
    
    -- Brake rigidity
    -- bySpeed
    setting = settings.brake.rigidity.bySpeed

    if(setting.enable) then
        local maxForceAt = setting.maxForceAt
        local minForce = setting.minForce
        local maxForce = setting.maxForce

        local progress = (airSpeed / maxForceAt) * brake
        local force1 = 0
        local force2 = 0

        if(setting.inverted == false) then
            force2 = utils.lerp(minForce, maxForce, progress)
        else
            force2 = utils.lerp(maxForce, minForce, progress)
        end

        dsxv2.brakeRigidity = force2

        ds:sendDsx(3, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.rigid, force1, force2)
        return
    end

    -- Constant
    setting = settings.brake.rigidity.constant

    if(setting.enable) then
        local minForce = setting.minForce
        local maxForce = setting.maxForce

        local force1 = 0
        local force2 = utils.lerp(minForce, maxForce, brake)

        dsxv2.brakeRigidity = force2

        ds:sendDsx(3, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.rigid, force1, force2)
        return
    end

    ds:sendDsx(100, 1000, ds.type.triggerUpdate, activeTrigger, ds.mode.off)
end

local function updateTriggerR(activeTrigger, throttle, brake, gear)
    -- Throttle disabled
    if(settings.throttle.enable == false) then
        ds:sendDsx(0, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.off)
        return
    end

    local setting = nil
    local wheelSpeed = utils.getWheelSpeed()

    -- Upshift vibration
    setting = settings.throttle.upShift
    
    if(setting.enable) then
        if(dsxv2.lastGear ~= gear and gear ~= 0) then
            dsxv2.lastGear = gear

            if(throttle == 1) then
                local timeOn = setting.timeOn
                local maxHz = setting.maxHz
                local maxForce = setting.maxForce

                local force1 = maxHz
                local force2 = maxForce
                local force3 = 135

                ds:sendDsx(0, tick:msToTickRate(timeOn), ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.vibrateResistance, force1, force2, force3)
                return
            end
        end
    end

    -- Rev limiter vibration
    setting = settings.throttle.revLimit

    if(setting.enable) then
        local progress = utils.isAtRevLimiter()

        if(progress > 0 and throttle == 1) then 
            local timeOn = setting.timeOn
            local minHz = setting.minHz
            local maxHz = setting.maxHz
            local maxForce = setting.maxForce

            local force1 = utils.lerp(minHz, maxHz, progress)
            local force2 = maxForce
            local force3 = 135

            ds:sendDsx(1, tick:msToTickRate(timeOn), ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.vibrateResistance, force1, force2, force3)
            return
        end
    end

    -- Wheelslip vibration
    setting = settings.throttle.wheelSlip

    if(setting.enable) then
        local isWheelSlip = utils.isWheelSlip()
        local tolerance = setting.tolerance

        if(isWheelSlip >= tolerance and throttle == 1) then
            local maxForceAt = setting.maxForceAt
            local minAmplitude = setting.minAmplitude
            local maxAmplitude = setting.maxAmplitude
            local minHz = setting.minHz
            local maxHz = setting.maxHz

            local progress = (isWheelSlip / maxForceAt) * throttle
            local startPos = 1
            local amplitude = utils.lerp(minAmplitude, maxAmplitude, progress)
            local frequency = utils.lerp(minHz, maxHz, progress)

            ds:sendDsx(2, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.vibration, startPos, amplitude, frequency)
            return
        end
    end

    -- Throttle rigidity if engine is off
    setting = settings.throttle.engineOff

    if(setting.enable) then
        if(utils.isEngineOn() == false) then
            ds:sendDsx(3, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.off)
            return
        end
    end

    -- Throttle rigidity
    -- bySpeed
    setting = settings.throttle.rigidity.bySpeed

    if(setting.enable) then
        local minForce = setting.minForce
        local maxForce = setting.maxForce
        local maxForceAt = setting.maxForceAt

        local progress = (wheelSpeed / maxForceAt)
        local force1 = 0
        local force2 = 0

        if(setting.inverted == false) then
            force2 = utils.lerp(minForce, maxForce, progress)
        else
            force2 = utils.lerp(maxForce, minForce, progress)
        end

        ds:sendDsx(4, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.rigid, force1, force2)
        return
    end

    -- Constant
    setting = settings.throttle.rigidity.constant

    if(setting.enable) then
        local minForce = setting.minForce
        local maxForce = setting.maxForce

        local force1 = 0
        local force2 = utils.lerp(minForce, maxForce, throttle)

        ds:sendDsx(5, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.rigid, force1, force2)
        return
    end

    ds:sendDsx(100, 1000, ds.type.triggerUpdate, activeTrigger, ds.mode.off)
end

local function updateMicLed(t, throttle, brake)
    -- Lightbar disabled
    if(settings.lightBar.enable == false) then
        return
    end

    local setting = nil

    -- Low fuel
    setting = settings.lightBar.lowFuel

    if(setting.enable) then
        if(electrics.values.lowfuel == true) then
            local timeOn = setting.timeOn
            local timeOff = setting.timeOff
            local elapsed = (t - dsxv2.lowFuelTick) % (timeOn + timeOff)

            if(elapsed < timeOn)then
                ds:sendDsx(0, tick:msToTickRate(timeOn), ds.type.micLed, ds.micLed.on)
            else
                ds:sendDsx(0, tick:msToTickRate(timeOff), ds.type.micLed, ds.micLed.off)
            end
            return
        else
            dsxv2.lowFuelTick = t
        end
    end

    -- Parking Brake
    setting = settings.lightBar.parkingBrake

    if(setting.enable) then
        if(electrics.values.parkingbrake == 1) then
            local timeOn = setting.timeOn
            local timeOff = setting.timeOff
            local elapsed = (t - dsxv2.parkingBrakeTick) % (timeOn + timeOff)

            if(elapsed < timeOn)then
                ds:sendDsx(1, tick:msToTickRate(timeOn), ds.type.micLed, ds.micLed.on)
            else
                ds:sendDsx(1, tick:msToTickRate(timeOff), ds.type.micLed, ds.micLed.off)
            end
            return
        else
            dsxv2.parkingBrakeTick = t
        end
    end

    -- TCS
    setting = settings.lightBar.tcs

    if(setting.enable) then
        if((electrics.values.tcsActive == true or electrics.values.tcsActive == 1) and electrics.values.tcs == 1) then
            ds:sendDsx(2, 1, ds.type.micLed, ds.micLed.on)
            return
        end
    end

    ds:sendDsx(100, 1000, ds.type.micLed, ds.micLed.off)
end

local function updatePlayerLed(t, throttle, brake)
    -- Lightbar disabled
    if(settings.lightBar.enable == false) then
        return
    end

    local setting = nil

    -- ESC
    setting = settings.lightBar.esc

    if(setting.enable) then
        if((electrics.values.escActive == true or electrics.values.escActive == 1) and electrics.values.esc == 1) then
            ds:sendDsx(0, 1, ds.type.playerLed, ds.playerLed.one)
            return
        end
    end

    ds:sendDsx(100, 1000, ds.type.playerLed, ds.playerLed.off)
end

local function updateLightbar(t, throttle, brake)
    -- Save profile lightbar flash
    local saveTick = dsxv2.saveTick

    if(saveTick > 0) then
        local elapsed = (t - saveTick)
        local fmod = (elapsed % 300)

        if(fmod < 150) then
            ds:sendDsx(-1, 16, ds.type.rgbUpdate, dsxv2.profileColor[1], dsxv2.profileColor[2], dsxv2.profileColor[3], dsxv2.profileColor[4])
        else
            ds:sendDsx(-1, 16, ds.type.rgbUpdate, 0, 0, 0, 0)
        end

        if(elapsed > 1500) then
            dsxv2.saveTick = 0
            ds:sendDsx(-1, 16, ds.type.rgbUpdate, 0, 0, 0, 0)
        end
        return
    end

    -- Lightbar disabled
    if(settings.lightBar.enable == false) then
        return
    end

    local setting = nil
    local inReverse = utils.isInReverse()
    
    -- Emergency braking
    setting = settings.lightBar.emergencyBraking

    if(setting.enable) then
        local emergencyBraking = utils.isEmergencyBraking(setting.alwaysBlink)

        if(emergencyBraking == 0) then
            dsxv2.emergencyBraking = true
            ds:sendDsx(-1, 1, ds.type.rgbUpdate, setting.colorOn[1], setting.colorOn[2], setting.colorOn[3], dsxv2.profileColor[4])
            return
        elseif(dsxv2.emergencyBraking == true) then
            dsxv2.emergencyBraking = false
            ds:sendDsx(-1, 6, ds.type.rgbUpdate, setting.colorOff[1], setting.colorOff[2], setting.colorOff[3], dsxv2.profileColor[4])
            return
        end
    end

    -- Hazard lights
    setting = settings.lightBar.hazardLights

    if(setting.enable) then
        if(utils.areHazardsEnabled() == true) then
            if(electrics.values.signal_L == 1 or electrics.values.signal_R == 1) then
                if(dsxv2.hazardState == false) then
                    dsxv2.hazardTick = t
                    dsxv2.hazardState = true
                end
            else
                if(dsxv2.hazardState == true) then
                    dsxv2.hazardTick = t
                    dsxv2.hazardState = false
                end
            end

            local colorOff = inReverse and settings.lightBar.reverse.colorOn or setting.colorOff
            local progress = dsxv2.hazardState and ((t - dsxv2.hazardTick) / 100) or (1 - ((t - dsxv2.hazardTick) / 100))
            local color = utils.lerpRgb2(colorOff, setting.colorOn, progress)

            ds:sendDsx(0, tick:msToTickRate(400), ds.type.rgbUpdate, color[1], color[2], color[3], dsxv2.profileColor[4])
            return
        elseif(dsxv2.hazardState == true) then
            dsxv2.hazardState = false
            ds:sendDsx(-1, 1, ds.type.rgbUpdate, setting.colorOff[1], setting.colorOff[2], setting.colorOff[3], dsxv2.profileColor[4])
            return
        end
    end

    -- Reverse
    setting = settings.lightBar.reverse

    if(setting.enable) then
        if(inReverse == true) then
            ds:sendDsx(1, 1, ds.type.rgbUpdate, setting.colorOn[1], setting.colorOn[2], setting.colorOn[3], dsxv2.profileColor[4])
            return
        end
    end

    -- Tachometer
    setting = settings.lightBar.tachometer

    if(setting.enable) then
        if(utils.isEngineOn() == true) then
            local progress = utils.isAtRevLimiter(false)

            -- Redline limiter
            if(progress > 0) then
                local color = ds:getColor()

                ds:sendDsx(2, 1, ds.type.rgbUpdate, color[1], color[2], color[3], 0)
                return
            -- Lightbar tachometer
            else
                local minRpm = utils.getIdleRpm()
                local maxRpm = utils.getMaxRpm()
                local rpm = utils.getRpm()

                local progress = 0

                if(rpm > setting.offset) then
                    progress = (rpm - setting.offset) / (maxRpm - setting.offset - minRpm)
                end

                local color = utils.lerpRgb3(setting.colorLow, setting.colorMed, setting.colorHi, progress)

                ds:sendDsx(2, 1, ds.type.rgbUpdate, color[1], color[2], color[3], dsxv2.profileColor[4])
                return
            end
        end
    end

    ds:sendDsx(100, 1000, ds.type.rgbUpdate, 0, 0, 0, 0)
end

local function updateGFX(dtSim)
    local mailboxNew = obj:getLastMailbox("mailboxToVE")

    if(mailboxNew ~= dsxv2.mailboxLast) then
        dsxv2.mailboxLast = mailboxNew
        onReceiveMailbox(mailboxNew)
    end

    if(not settings or not udp.ready() or not playerInfo.firstPlayerSeated) then 
        return 
    end

    tick:handleGameTick(dtSim)

    local t = tick:getTick()

    if(t - dsxv2.gfxTick > tick:getTickRate()) then
        dsxv2.gfxTick = t

        local gear = utils.getGear()
        local inverted = utils.isBrakeThrottleInverted()
        local brake = inverted and utils.getThrottle() or utils.getBrake()
        local throttle = inverted and utils.getBrake() or utils.getThrottle()

        updateTriggerL(inverted and ds.trigger.right or ds.trigger.left, throttle, brake, gear)
        updateTriggerR(inverted and ds.trigger.left or ds.trigger.right, throttle, brake, gear)
        updateMicLed(t, throttle, brake)
        updateLightbar(t, throttle, brake)
        updatePlayerLed(t, throttle, brake)
    end
end

return
{
    onExtensionLoaded = onExtensionLoaded,
    updateGFX = updateGFX,
}