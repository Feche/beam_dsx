-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche
-- VE beam_dsx

local ds = require("common.ds")
local tick = require("common.tick")
local common = require("common.common")
local controllers = require("vehicle.extensions.auto.utils.controllers")
local utils = require("vehicle.extensions.auto.utils.utils")

local log = common.log
local settings = nil

local beam_dsx =
{
    state = nil,
    gearLast = 0,
    brakeRigidity = 0,

    gfxTick = 0,
    saveTick = 0,
    hazardTick = 0,
    lowFuelTick = 0,
    parkingBrakeTick = 0,

    policeMode = 0,
    policeModeLast = 0,
    policeModeTick = 0,

    lastCrashTick = 0,
    lastCrashStartTick = 0,
    lastCrashEnd = true,

    adaptiveBrakeLights = false,
    emergencyBraking = false,
    absCoefLast = 0,
    hazardState = false,
    profileColor = nil,

    mbLast = nil,

    driveMode =
    {
        last = nil,
        color = nil,
        tick = 0,
        escModes = {},
        load = function(self)
            if(not v.data.esc) then
                return
            end

            local tmp = {}
            for key, value in pairs(v.data.esc.configurations) do
                table.insert(tmp, { name = key, order = value.order })
            end

            table.sort(tmp, function(a, b) return b.order > a.order end)
            self.escModes = common.deep_copy_safe(tmp)
        end,
        getCurrentDriveMode = function(self)
            local driveModes = controller.getController("driveModes")

            if(driveModes) then
                return driveModes.getCurrentDriveModeKey()
            end

            local esc = controller.getController("esc")
    
            if(esc) then
                local driveMode = esc.serialize().escConfigKey
                return self.escModes[driveMode].name
            end

            return nil
        end,
    },
    onReceiveMailbox = function(self, buffer)
        self.state = nil

        if(not playerInfo.firstPlayerSeated) then
            log("W", "onReceiveMailbox", "not the player vehicle (firstPlayerSeated)")
            return
        end

        -- Disable if spectating or driving a self-driving AI car (supports BeamMp spectating)
        if(ai.mode ~= "disabled" or (v.mpVehicleType and v.mpVehicleType ~= "L")) then
            log("W", "onReceiveMailbox", "not the player vehicle (ai or remote mpVehicle)")
            return ds:resetController()
        end

        local mailbox = jsonDecode(buffer)

        if(not mailbox.code) then
            return log("E", "onReceiveMailbox", "received nil mailbox ..")
        end

        local vehicleName = utils.getVehicleName()

        self.state = true
        self.lastCrashStartTick = 0
        self.driveMode:load()

        log("W", "onReceiveMailbox", "received mailbox '%s', vehicle '%s' ..", mailbox.code, vehicleName)

        if(mailbox.code == "mod_disable") then
            self.state = nil  
            log("W", "onReceiveMailbox", "mod disabled")
        elseif(mailbox.code == "vehicle_invalid") then
            self.state = nil
            log("W", "onReceiveMailbox", "no longer in a valid vehicle, disabling controller")
        elseif(mailbox.code == "save" or mailbox.code == "profile_change" or mailbox.code == "vehicle_reset_or_switch" or mailbox.code == "mod_enable" or mailbox.code == "udp_address_change" or mailbox.code == "controller_index_change") then
            controllers:load()

            local p = jsonReadFile(mailbox.path)

            if(not p or not p.profiles or not p.profiles[p.active] or not p.profiles[p.active].settings or not p.profiles[p.active].color or not p.ip or not p.port or not p.controllerIndex) then
                self.state = nil
                return log("E", "onReceiveMailbox", "error while loading profile ID %d", p and p.active or -1)
            end

            -- Blink lightbar on save or profile switch
            if(mailbox.code == "save" or mailbox.code == "profile_change") then
                self.saveTick = tick:getTick()
            end

            settings = p.profiles[p.active].settings
            self.profileColor = p.profiles[p.active].color
            self.policeMode = mailbox.policeMode

            ds:setUDPAddress(p.ip, p.port, "VE")
            ds:setControllerIndex(p.controllerIndex, "VE")

            log("I", "onReceiveMailbox", "applying user config, profile '%s', police mode: %d, controller index: %d ..", p.profiles[p.active].name, self.policeMode, p.controllerIndex)
        elseif(mailbox.code == "police_chase_update") then
            if(mailbox.policeMode == -1) then
                self.policeModeLast = self.policeMode
            end

            self.policeMode = mailbox.policeMode
            self.policeModeTick = 0

            log("I", "onReceiveMailbox", "chase update received, police mode: %d", self.policeMode)
        end
    end,
    onDriveModeSwitch = function(self, oldDriveMode, newDriveMode)
        if(not newDriveMode) then
            return
        end

        self.driveMode.color = utils.getDriveModeColor(newDriveMode)
        self.driveMode.tick = tick:getTick()

        log("I", "onDriveModeSwitch", "player switched from drivemode '%s' to '%s'", oldDriveMode, newDriveMode)
    end,
}

local function onExtensionLoaded()
    -- Get adaptiveBrakeLights state
    local adaptiveBrakeLights = controller.getController("adaptiveBrakeLights")
    
    if(adaptiveBrakeLights) then
        local setParameters_ = adaptiveBrakeLights.setParameters

        -- Hook function to save adaptiveBrakeLights state
        adaptiveBrakeLights.setParameters = function(data)
            beam_dsx.adaptiveBrakeLights = data.isEnabled
            return setParameters_(data)
        end

        beam_dsx.adaptiveBrakeLights = true
    end

    log("I", "onExtensionLoaded", "extension loaded.")
end

local function updateTriggerL(activeTrigger, throttle, brake, gear)
    -- Brake disabled
    if(settings.brake.enable == false) then
        ds:sendDsx(0, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.off)
        return
    end

    local setting = nil
    local airSpeed = utils.getAirSpeed()

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

        if(absCoef ~= beam_dsx.absCoefLast) then
            beam_dsx.absCoefLast = absCoef

            local minAmplitude = setting.minAmplitude
            local maxAmplitude = setting.maxAmplitude
            local minHz = setting.minHz
            local maxHz = setting.maxHz
            
            local progress = 1 - absCoef
            local startPos = math.min(9, ((beam_dsx.brakeRigidity / 255) * 9) + 1)
            local amplitude = common.lerp(maxAmplitude, minAmplitude, progress)
            local frequency = common.lerp(minHz, maxHz, progress)

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
            force2 = common.lerp(minForce, maxForce, progress)
        else
            force2 = common.lerp(maxForce, minForce, progress)
        end

        beam_dsx.brakeRigidity = force2

        ds:sendDsx(3, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.rigid, force1, force2)
        return
    end

    -- Constant
    setting = settings.brake.rigidity.constant

    if(setting.enable) then
        local minForce = setting.minForce
        local maxForce = setting.maxForce

        local force1 = 0
        local force2 = common.lerp(minForce, maxForce, brake)

        beam_dsx.brakeRigidity = force2

        ds:sendDsx(3, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.rigid, force1, force2)
        return
    end

    ds:sendDsx(100, 1000, ds.type.triggerUpdate, activeTrigger, ds.mode.off)
end

local function updateTriggerR(activeTrigger, throttle, brake, gear)
    -- Throttle disabled
    if(settings.throttle.enable == false) then
        return ds:sendDsx(0, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.off)
    end

    local setting = nil
    local wheelSpeed = utils.getWheelSpeed()

    -- Upshift vibration
    setting = settings.throttle.upShift
    
    if(setting.enable) then
        if(beam_dsx.gearLast ~= gear and gear ~= 0) then
            beam_dsx.gearLast = gear

            if(throttle == 1) then
                local timeOn = setting.timeOn
                local maxHz = setting.maxHz
                local maxForce = setting.maxForce

                local force1 = maxHz
                local force2 = maxForce
                local force3 = 135

                return ds:sendDsx(0, tick:msToTickRate(timeOn), ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.vibrateResistance, force1, force2, force3)
            end
        end
    end

    -- Rev limiter vibration
    setting = settings.throttle.revLimit

    if(setting.enable) then
        local progress = utils.isAtRevLimiter()

        if(progress > 0 and throttle == 1) then
            local minHz = setting.minHz
            local maxHz = setting.maxHz
            local maxForce = setting.maxForce
            local timeOn = setting.timeOn

            local force1 = common.lerp(minHz, maxHz, progress)
            local force2 = maxForce
            local force3 = 135

            return ds:sendDsx(1, tick:msToTickRate(timeOn), ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.vibrateResistance, force1, force2, force3)
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
            local amplitude = common.lerp(minAmplitude, maxAmplitude, progress)
            local frequency = common.lerp(minHz, maxHz, progress)

            return ds:sendDsx(2, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.vibration, startPos, amplitude, frequency)
        end
    end

    -- Engine reaching redline
    setting = settings.throttle.redLine

    if(setting.enable) then
        local rpm = utils.getRpm()
        local maxRpm = utils.getMaxRpm()
        local at = rpm / maxRpm
        local startAt = setting.startAt / 100

        if(at >= startAt and throttle == 1) then
            local rpmProgress = (at - startAt) / (1 - startAt)
            local bounces = setting.bounces * rpmProgress
            local progress = 0
            
            if(setting.bounces == 0) then 
                progress = common.lerpNonLineal(0, 1, rpmProgress, 6)
            else
                progress = common.bounceLerp(rpmProgress, bounces)
            end

            local minHz = setting.minHz
            local maxHz = setting.maxHz
            local vibrationForce = setting.vibrationForce

            local force1 = common.lerp(minHz, maxHz, progress)
            local force2 = vibrationForce == 1 and 1 or (vibrationForce / 3) * 255 
            local force3 = 135

            return ds:sendDsx(3, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.vibrateResistance, force1, force2, force3)
        end
    end

    -- Throttle clicky when turning engine on
    setting = settings.throttle.engineOn

    if(setting.enable) then
        if(utils.isEngineOn() == false and utils.getGearboxMode() == "arcade") then
            return ds:sendDsx(4, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.gameCube)
        end
    end

    -- Throttle rigidity disabled if engine is off
    setting = settings.throttle.engineOff

    if(setting.enable) then
        if(utils.isEngineOn() == false) then
            return ds:sendDsx(5, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.off)
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
            force2 = common.lerp(minForce, maxForce, progress)
        else
            force2 = common.lerp(maxForce, minForce, progress)
        end

        return ds:sendDsx(6, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.rigid, force1, force2)
    end

    -- Constant
    setting = settings.throttle.rigidity.constant

    if(setting.enable) then
        local minForce = setting.minForce
        local maxForce = setting.maxForce

        local force1 = 0
        local force2 = common.lerp(minForce, maxForce, throttle)

        return ds:sendDsx(7, 1, ds.type.triggerUpdate, activeTrigger, ds.mode.customTriggerValue, ds.mode.custom.rigid, force1, force2)
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
            local elapsed = (t - beam_dsx.lowFuelTick) % (timeOn + timeOff)

            if(elapsed < timeOn)then
                ds:sendDsx(0, tick:msToTickRate(timeOn), ds.type.micLed, ds.micLed.on)
            else
                ds:sendDsx(0, tick:msToTickRate(timeOff), ds.type.micLed, ds.micLed.off)
            end
            return
        else
            beam_dsx.lowFuelTick = t
        end
    end

    -- Parking Brake
    setting = settings.lightBar.parkingBrake

    if(setting.enable) then
        if(electrics.values.parkingbrake == 1) then
            local timeOn = setting.timeOn
            local timeOff = setting.timeOff
            local elapsed = (t - beam_dsx.parkingBrakeTick) % (timeOn + timeOff)

            if(elapsed < timeOn)then
                ds:sendDsx(1, tick:msToTickRate(timeOn), ds.type.micLed, ds.micLed.on)
            else
                ds:sendDsx(1, tick:msToTickRate(timeOff), ds.type.micLed, ds.micLed.off)
            end
            return
        else
            beam_dsx.parkingBrakeTick = t
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
            return ds:sendDsx(0, 1, ds.type.playerLed, ds.playerLed.one)
        end
    end

    -- Police 'stars'
    setting = settings.lightBar.policeStars

    if(setting.enable) then
        local stars = { ds.playerLed.one, ds.playerLed.two, ds.playerLed.three, ds.playerLed.four, ds.playerLed.five }

        if(beam_dsx.policeMode > 0) then
            return ds:sendDsx(1, 1, ds.type.playerLed, stars[beam_dsx.policeMode] or ds.playerLed.five)
        elseif(beam_dsx.policeMode == -1) then
            local elapsed = (t - beam_dsx.policeModeTick)
            local blinkTime = 200

            if(elapsed % (blinkTime * 2) < blinkTime) then
                return ds:sendDsx(1, 1, ds.type.playerLed, stars[beam_dsx.policeModeLast] or ds.playerLed.five)
            else
                return ds:sendDsx(1, 1, ds.type.playerLed, ds.playerLed.off)
            end
        end
    end

    ds:sendDsx(100, 1000, ds.type.playerLed, ds.playerLed.off)
end

local function updateLightbar(t, throttle, brake)
    -- Lightbar disabled
    if(settings.lightBar.enable == false) then
        return
    end

    -- Save profile lightbar flash
    local saveTick = beam_dsx.saveTick

    if(saveTick > 0) then
        local elapsed = (t - saveTick)
        local fmod = (elapsed % 300)

        if(fmod < 150) then
            ds:sendDsx(-1, 16, ds.type.rgbUpdate, beam_dsx.profileColor[1], beam_dsx.profileColor[2], beam_dsx.profileColor[3], beam_dsx.profileColor[4])
        else
            ds:sendDsx(-1, 16, ds.type.rgbUpdate, 0, 0, 0, 0)
        end

        if(elapsed > 1500) then
            beam_dsx.saveTick = 0
            ds:sendDsx(-1, 16, ds.type.rgbUpdate, 0, 0, 0, 0)
        end
        return
    end

    local setting = nil
    local inReverse = utils.isInReverse()

    -- Drivemode switched
    setting = settings.lightBar.driveMode

    if(setting.enable) then
        if(beam_dsx.driveMode.tick > 0 and beam_dsx.driveMode.color) then
            local blinkTime = setting.blinkTime
            local elapsed = t - beam_dsx.driveMode.tick
            local progress = common.bounceLerp(elapsed / blinkTime, 3 * (blinkTime / 2000))

            if(elapsed > blinkTime) then
                beam_dsx.driveMode.tick = 0
            end

            return ds:sendDsx(-2, 1, ds.type.rgbUpdate, beam_dsx.driveMode.color[1], beam_dsx.driveMode.color[2], beam_dsx.driveMode.color[3], beam_dsx.profileColor[4] * progress)
        end
    end

    -- Vehicle damage
    setting = settings.lightBar.vehicleDamage

    if(setting.enable) then
        local postCrashBrake = controllers:getControllerData("postCrashBrake")
        local brakeThreshold = postCrashBrake and postCrashBrake.brakeThreshold or 50

        if (math.abs(sensors.gx2) > brakeThreshold or math.abs(sensors.gy2) > brakeThreshold) or ((sensors.gz2 - powertrain.currentGravity) > brakeThreshold) then
            if(beam_dsx.lastCrashStartTick == 0) then
                beam_dsx.lastCrashStartTick = t
                beam_dsx.lastCrashEnd = false
            end
            
            beam_dsx.lastCrashTick = t
        elseif(t - beam_dsx.lastCrashTick >= 1000 and not beam_dsx.lastCrashEnd) then
            beam_dsx.lastCrashEnd = true
        end

        if(beam_dsx.lastCrashStartTick > 0) then
            local elapsedStart = t - beam_dsx.lastCrashStartTick
            local timeOn = setting.timeOn
            
            if(elapsedStart < timeOn or beam_dsx.lastCrashEnd == false) then
                local colorOn = setting.colorOn
                local colorOff = setting.colorOff
                local blinkSpeed = setting.blinkSpeed * (timeOn / 2000)

                local progress = (elapsedStart / timeOn) % 1
                local bounceProgress = common.bounceLerp(progress, blinkSpeed)
                local color = common.lerpRgb2(colorOn, colorOff, bounceProgress)

                return ds:sendDsx(-2, 1, ds.type.rgbUpdate, color[1], color[2], color[3], beam_dsx.profileColor[4])
            else
                log("I", "updateLightbar.vehicleDamage", "crash duration %d ms.", t - beam_dsx.lastCrashStartTick)
                beam_dsx.lastCrashStartTick = 0
            end
        end
    end
    
    -- Emergency braking
    setting = settings.lightBar.emergencyBraking

    if(setting.enable) then
        local emergencyBraking = utils.isEmergencyBraking(setting.alwaysBlink, beam_dsx.adaptiveBrakeLights, brake)

        if(emergencyBraking == 0) then
            beam_dsx.emergencyBraking = true
            return ds:sendDsx(-2, 1, ds.type.rgbUpdate, setting.colorOn[1], setting.colorOn[2], setting.colorOn[3], beam_dsx.profileColor[4])
        elseif(beam_dsx.emergencyBraking == true) then
            beam_dsx.emergencyBraking = false
            return ds:sendDsx(-2, 6, ds.type.rgbUpdate, setting.colorOff[1], setting.colorOff[2], setting.colorOff[3], beam_dsx.profileColor[4])
        end
    end

    -- Police chase
    setting = settings.lightBar.policeChase

    if(setting.enable) then
        if(beam_dsx.policeMode == 0) then
            beam_dsx.policeModeTick = 0
        elseif(beam_dsx.policeMode == -1) then
            if(beam_dsx.policeModeTick == 0) then
                beam_dsx.policeModeTick = t
            end

            local elapsed = t - beam_dsx.policeModeTick
            local progress = (elapsed / 5000)
            local color = common.lerpRgb2({ 255, 165, 0, 255 }, { 255, 200, 128, 255 }, progress)

            ds:sendDsx(-1, 6, ds.type.rgbUpdate, color[1], color[2], color[3], beam_dsx.profileColor[4])
            return
        else
            if(beam_dsx.policeModeTick == 0) then
                beam_dsx.policeModeTick = t
            end

            local bounceTime = (850 / beam_dsx.policeMode)

            local elapsed = t - beam_dsx.policeModeTick
            local bounceProgress = (elapsed % bounceTime) / bounceTime
            local progress = common.bounceLerp(bounceProgress, 2)
            local color = nil

            if((elapsed % (bounceTime * 2)) < bounceTime) then
                color = { 255, 0, 0 }
            else
                color = { 0, 0, 255 }
            end
       
            -- Send color update
            ds:sendDsx(-1, 6, ds.type.rgbUpdate, color[1], color[2], color[3], beam_dsx.profileColor[4] * progress)
            return
        end
    end

    -- Hazard lights
    setting = settings.lightBar.hazardLights

    if(setting.enable) then
        if(utils.areHazardsEnabled() == true) then
            if(electrics.values.signal_L == 1 or electrics.values.signal_R == 1) then
                if(beam_dsx.hazardState == false) then
                    beam_dsx.hazardTick = t
                    beam_dsx.hazardState = true
                end
            else
                if(beam_dsx.hazardState == true) then
                    beam_dsx.hazardTick = t
                    beam_dsx.hazardState = false
                end
            end

            local colorOff = inReverse and settings.lightBar.reverse.colorOn or setting.colorOff
            local progress = beam_dsx.hazardState and ((t - beam_dsx.hazardTick) / 100) or (1 - ((t - beam_dsx.hazardTick) / 100))
            local color = common.lerpRgb2(colorOff, setting.colorOn, progress)

            ds:sendDsx(0, tick:msToTickRate(400), ds.type.rgbUpdate, color[1], color[2], color[3], beam_dsx.profileColor[4])
            return
        elseif(beam_dsx.hazardState == true) then
            beam_dsx.hazardState = false
            ds:sendDsx(-1, 1, ds.type.rgbUpdate, setting.colorOff[1], setting.colorOff[2], setting.colorOff[3], beam_dsx.profileColor[4])
            return
        end
    end

    -- Reverse
    setting = settings.lightBar.reverse

    if(setting.enable) then
        if(inReverse == true) then
            ds:sendDsx(1, 1, ds.type.rgbUpdate, setting.colorOn[1], setting.colorOn[2], setting.colorOn[3], beam_dsx.profileColor[4])
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
                local color = ds:getDsxColor()

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

                local color = common.lerpRgb3(setting.colorLow, setting.colorMed, setting.colorHi, progress)

                ds:sendDsx(2, 1, ds.type.rgbUpdate, color[1], color[2], color[3], beam_dsx.profileColor[4])
                return
            end
        end
    end

    ds:sendDsx(100, 1000, ds.type.rgbUpdate, 0, 0, 0, 0)
end

local function updateGFX(dtSim)
    tick:handleGameTick(dtSim)

    local t = tick:getTick()

    if(t - beam_dsx.gfxTick >= tick:getTickRate()) then
        beam_dsx.gfxTick = t

        -- onReceiveMailbox
        local mailboxNew = obj:getLastMailbox("beam_dsx_mailboxToVE")
        if(mailboxNew ~= beam_dsx.mbLast) then
            beam_dsx:onReceiveMailbox(mailboxNew)
            beam_dsx.mbLast = mailboxNew
        end

        -- disable VE if mod should not run on current vehicle
        if(beam_dsx.state == nil) then
            return
        end

        -- onDriveModeSwitch
        local driveModeNew = beam_dsx.driveMode:getCurrentDriveMode()
        if(beam_dsx.driveMode.last ~= driveModeNew) then
            beam_dsx:onDriveModeSwitch(beam_dsx.driveMode.last, driveModeNew)
            beam_dsx.driveMode.last = driveModeNew
        end

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