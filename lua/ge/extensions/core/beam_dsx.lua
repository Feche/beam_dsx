-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local profiles = require("ge.extensions.core.beam_dsx_profiles")

local version = "1.0"
local im = ui_imgui
local tick = 0
local settings = nil

local ui =
{
    main = 
    {
        show = im.BoolPtr(false),
        closed = true,
        tabSet = false,
    },
    createProfile =
    {
        show = im.BoolPtr(false),
        closed = true,
    },
    constraints =
    {
        main =
        {
            width = 490,
            height = 600,
            flags = im.WindowFlags_AlwaysAutoResize,
        },
        createProfile = 
        {
            width = 300,
            height = 150,
            flags = im.WindowFlags_AlwaysAutoResize,
        },
    },
    -- Messages
    message =
    {
        progress = 0,
        tick = 0,
        str = nil,
        duration = 0,
    },
    showMessage = function(self, str, duration)
        self.message.progress = 0
        self.message.tick = tick
        self.message.str = str and str.. "." or nil
        self.message.duration = (duration or 3)
    end,
}

local function onExtensionLoaded()
    -- Load user settings
    profiles:init()

    settings = profiles:getActiveProfileSettings()

    if(not settings) then
        print("[beam_dsx] GE: profile settings missing ..")
        return
    end

    if(settings.enableOnBeamMPServers == true) then
        local env = getfenv and getfenv(0);
        local cm = env and rawget(env, 'core_modmanager')

        if cm then 
            local dm = cm.deactivateMod

            cm.deactivateMod = function(name) 
                if debug.getinfo(2,'S').short_src:find('MPModManager.lua') and name:find("beam_dsx") then 
                    return
                end

                return dm(name)
             end
        end
    end

    print("[beam_dsx] GE: extension loaded (allow beammp: " ..tostring(settings.enableOnBeamMPServers).. ", profile: " ..profiles:getProfileName().. ")")
end

local function onExtensionUnloaded()
	print("[beam_dsx] GE: extension unloaded")
end

local function toggleUI(change)
    if(change == nil) then
        ui.main.show[0] = (not ui.main.show[0]) 
    end

    if(ui.main.show[0]) then
        profiles:saveActiveProfileToTemp()
        settings = profiles:getActiveProfileSettings()
        ui.main.closed = false
    else
        profiles:restoreActiveProfileFromTemp()
        ui.main.closed = true
        ui:showMessage(nil)
    end
end

local function toggleCreateProfileUI(change)
    if(change) then
        ui.createProfile.show[0] = change
        return
    end

    if(ui.createProfile.show[0]) then
        ui.createProfile.closed = false
    else
        ui.createProfile.closed = true
    end
end

local function updateConfig()
    local obj = be:getPlayerVehicle(0)
    if obj then
        obj:queueLuaCommand('updateConfig("' ..profiles:getPath().. '")') 
    end
end

local function onVehicleResetted(vehicleId)
    local playerVehicleId = be:getPlayerVehicleID(0)

    if(vehicleId == playerVehicleId) then
        print("[beam_dsx] GE: player vehicle resetted, signaling VE ..")
        updateConfig()
    end
end

local function dsxSettings()
    local setting = nil

    im.BeginChild1("TriggerSettings", im.ImVec2(ui.constraints.main.width - 20, false, ui.constraints.main.flags))

    -- Throttle trigger
    if im.TreeNode1("Throttle trigger") then
        -- Rigidity
        if im.TreeNode1("Rigidity") then
            -- By speed
            setting = settings.throttle.rigidity.bySpeed

            if im.TreeNode1("By speed") then
                local enable = im.BoolPtr(setting.enable)

                if im.Checkbox("Enable", enable) then
                    setting.enable = enable[0]

                    if(settings.throttle.rigidity.constant.enable == true) then
                        settings.throttle.rigidity.constant.enable = false
                    end
                end

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Enable or disable trigger rigidity based on vehicle speed")
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()

                    -- minForce
                    im.Text("Minimum force:")

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text("Changes minimum force of the trigger when vehicle is at 0km/h")
                        im.EndTooltip()
                    end

                    im.PushItemWidth(128)

                    local minForce = im.FloatPtr(setting.minForce)

                    if im.SliderFloat("##1", minForce, 0, 255, "%.0f") then
                        setting.minForce = minForce[0]
                    end

                    -- maxForce
                    im.Text("Maximum force:")

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text("Changes maximum force of the trigger when vehicle is at target speed")
                        im.EndTooltip()
                    end

                    im.PushItemWidth(128)

                    local maxForce = im.FloatPtr(setting.maxForce)

                    if im.SliderFloat("##2", maxForce, 0, 255, "%.0f") then
                        setting.maxForce = maxForce[0]
                    end

                    -- maxForceAt
                    if(setting.inverted == false) then
                        im.Text("Maximum force at:")
                    else
                        im.Text("Minimum force at:")
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()

                        if(setting.inverted == false) then
                            im.Text("The speed at which the trigger applies its maximum force")
                        else
                            im.Text("The speed at which the trigger applies its minimum force")
                        end

                        im.EndTooltip()
                    end

                    im.PushItemWidth(128)

                    local maxForceAt = im.FloatPtr(setting.maxForceAt)

                    if im.SliderFloat("km/h##3", maxForceAt, 0, 1000, "%.0f") then
                        setting.maxForceAt = maxForceAt[0]
                    end

                    -- Inverted
                    local inverted = im.BoolPtr(setting.inverted)

                    if im.Checkbox("Use minimum speed instead of maximum (inverted)", inverted) then
                        setting.inverted = inverted[0]
                    end

                    im.Separator()
                end

                im.TreePop()
            end

            -- Constant
            setting = settings.throttle.rigidity.constant

            if im.TreeNode1("Constant") then
                local enable = im.BoolPtr(setting.enable)

                if im.Checkbox("Enable", enable) then
                    setting.enable = enable[0]

                    if(settings.throttle.rigidity.bySpeed.enable == true) then
                        settings.throttle.rigidity.bySpeed.enable = false
                    end
                end

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Enable or disable constant trigger force based on two interpolated values")
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()

                    -- minForce
                    im.Text("Minimum force:")

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text("The minimum force applied to the trigger when it is fully released")
                        im.EndTooltip()
                    end

                    im.PushItemWidth(128)

                    local minForce = im.FloatPtr(setting.minForce)

                    if im.SliderFloat("##4", minForce, 0, 255, "%.0f") then
                        setting.minForce = minForce[0]
                    end

                    -- maxForce
                    im.Text("Maximum force:")

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text("The maximum force applied to the trigger when it is fully pressed")
                        im.EndTooltip()
                    end

                    im.PushItemWidth(128)

                    local maxForce = im.FloatPtr(setting.maxForce)

                    if im.SliderFloat("##5", maxForce, 0, 255, "%.0f") then
                        setting.maxForce = maxForce[0]
                    end

                    im.Separator()
                end

                im.TreePop()
            end

            im.TreePop()
        end

        -- Wheelslip
        setting = settings.throttle.wheelSlip

        if im.TreeNode1("Wheel slip") then
            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox("Enable", enable) then
                setting.enable = enable[0]
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text("Enable or disable haptic feedback during wheelslip")
                im.EndTooltip()
            end

            if(setting.enable == true) then
                im.Separator()

                -- tolerance
                im.Text("Tolerance:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Lower tolerances triggers slip earlier")
                    im.EndTooltip()
                end

                im.PushItemWidth(128)

                local tolerance = im.FloatPtr(setting.tolerance)

                if im.SliderFloat("##6", tolerance, 0, 200, "%.0f") then
                    setting.tolerance  = tolerance[0]
                end

                -- maxForceAt 
                im.Text("Max force at:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("At this value the trigger vibration will be at maximum force")
                    im.EndTooltip()
                end

                im.PushItemWidth(128)

                local maxForceAt  = im.FloatPtr(setting.maxForceAt)

                if im.SliderFloat("##7", maxForceAt, 0, 200, "%.0f") then
                    setting.maxForceAt = maxForceAt[0]
                end

                -- minHz 
                im.Text("Minimum hz:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Minimum frequency at which the triggers vibrates")
                    im.EndTooltip()
                end

                im.PushItemWidth(128)

                local minHz  = im.FloatPtr(setting.minHz)

                if im.SliderFloat("hz##8", minHz, 0, 255, "%.0f") then
                    setting.minHz = minHz[0]
                end

                -- maxHz 
                im.Text("Maximum hz:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Maximum frequency at which the triggers vibrates")
                    im.EndTooltip()
                end

                im.PushItemWidth(128)

                local maxHz  = im.FloatPtr(setting.maxHz)

                if im.SliderFloat("hz##9", maxHz, 0, 255, "%.0f") then
                    setting.maxHz = maxHz[0]
                end

                -- minAmplitude  
                im.Text("Minimum amplitude:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Minimum amplitude of the vibration, lower numbers decrease vibration strenght")
                    im.EndTooltip()
                end

                im.PushItemWidth(128)

                local minAmplitude = im.FloatPtr(setting.minAmplitude)

                if im.SliderFloat("##10", minAmplitude, 1, 8, "%.0f") then
                    setting.minAmplitude  = minAmplitude[0]
                end

                -- maxAmplitude  
                im.Text("Maximum amplitude:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Maximum amplitude of the vibration, higher numbers increase vibration strenght")
                    im.EndTooltip()
                end

                im.PushItemWidth(128)

                local maxAmplitude = im.FloatPtr(setting.maxAmplitude)

                if im.SliderFloat("##11", maxAmplitude, 1, 8, "%.0f") then
                    setting.maxAmplitude  = maxAmplitude[0]
                end

                im.Separator()
            end

            im.TreePop()
        end

        -- Upshift
        setting = settings.throttle.upShift

        if im.TreeNode1("Up shift") then
            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox("Enable", enable) then
                setting.enable = enable[0]
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text("Enable or disable haptic feedback during upshift")
                im.EndTooltip()
            end

            if(setting.enable) then
                im.Separator()

                -- maxHz 
                im.Text("Maximum hz:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Maximum frequency at which the triggers vibrates")
                    im.EndTooltip()
                end

                im.PushItemWidth(128)

                local maxHz = im.FloatPtr(setting.maxHz)

                if im.SliderFloat("hz##12", maxHz, 1, 255, "%.0f") then
                    setting.maxHz  = maxHz[0]
                end

                -- maxForce  
                im.Text("Maximum force:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Maximum force of the trigger")
                    im.EndTooltip()
                end

                im.PushItemWidth(128)

                local maxForce = im.FloatPtr(setting.maxForce)

                if im.SliderFloat("##13", maxForce, 1, 255, "%.0f") then
                    setting.maxForce  = maxForce[0]
                end

                -- timeOn  
                im.Text("Duration:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Duration of the vibration when up shifting, in milliseconds")
                    im.EndTooltip()
                end

                im.PushItemWidth(128)

                local timeOn = im.FloatPtr(setting.timeOn)

                if im.SliderFloat("ms##14", timeOn, 1, 255, "%.0f") then
                    setting.timeOn  = timeOn[0]
                end

                im.Separator()
            end

            im.TreePop()
        end

        -- Rev limit
        setting = settings.throttle.revLimit

        if im.TreeNode1("Rev limiter") then
            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox("Enable", enable) then
                setting.enable = enable[0]
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text("Enable or disable haptic feedback during engine red line")
                im.EndTooltip()
            end

            if(setting.enable == true) then
                im.Separator()

                -- minHz 
                im.Text("Minimum hz:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Minimum frequency at which the triggers vibrates")
                    im.EndTooltip()
                end

                im.PushItemWidth(128)

                local minHz  = im.FloatPtr(setting.minHz)

                if im.SliderFloat("hz##8", minHz, 0, 255, "%.0f") then
                    setting.minHz = minHz[0]
                end

                -- maxHz 
                im.Text("Maximum hz:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Maximum frequency at which the triggers vibrates")
                    im.EndTooltip()
                end

                im.PushItemWidth(128)

                local maxHz  = im.FloatPtr(setting.maxHz)

                if im.SliderFloat("hz##9", maxHz, 0, 255, "%.0f") then
                    setting.maxHz = maxHz[0]
                end

                -- maxForce  
                im.Text("Maximum force:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Maximum force of the trigger")
                    im.EndTooltip()
                end

                im.PushItemWidth(128)

                local maxForce = im.FloatPtr(setting.maxForce)

                if im.SliderFloat("##13", maxForce, 1, 255, "%.0f") then
                    setting.maxForce  = maxForce[0]
                end

                -- timeOn  
                im.Text("Duration:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Duration of the vibration when rev limiting, in milliseconds")
                    im.EndTooltip()
                end

                im.PushItemWidth(128)

                local timeOn = im.FloatPtr(setting.timeOn)

                if im.SliderFloat("ms##14", timeOn, 1, 255, "%.0f") then
                    setting.timeOn  = timeOn[0]
                end
            end

            im.TreePop()
        end

        im.Separator()

        -- Engine off
        setting = settings.throttle.engineOff

        local enable = im.BoolPtr(setting.enable)

        if im.Checkbox("Throttle trigger force will be disabled when the engine is off", enable) then
            setting.enable = enable[0]
        end

        im.TreePop()
    end

    im.Separator()

    -- Brake trigger
    if im.TreeNode1("Brake trigger") then
        -- Rigidity
        if im.TreeNode1("Rigidity") then
            -- bySpeed
            setting = settings.brake.rigidity.bySpeed

            if im.TreeNode1("By speed") then
                local enable = im.BoolPtr(setting.enable)

                if im.Checkbox("Enable", enable) then
                    setting.enable = enable[0]

                    if(settings.brake.rigidity.constant.enable == true) then
                        settings.brake.rigidity.constant.enable = false
                    end
                end

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Enable or disable trigger rigidity based on vehicle speed")
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()

                    -- minForce
                    im.Text("Minimum force:")

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text("Changes minimum force of the trigger when vehicle is at 0km/h")
                        im.EndTooltip()
                    end

                    im.PushItemWidth(128)

                    local minForce = im.FloatPtr(setting.minForce)

                    if im.SliderFloat("##15", minForce, 0, 255, "%.0f") then
                        setting.minForce = minForce[0]
                    end

                    -- maxForce
                    im.Text("Maximum force:")

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text("Changes maximum force of the trigger when vehicle is at target speed")
                        im.EndTooltip()
                    end

                    im.PushItemWidth(128)

                    local maxForce = im.FloatPtr(setting.maxForce)

                    if im.SliderFloat("##16", maxForce, 0, 255, "%.0f") then
                        setting.maxForce = maxForce[0]
                    end

                    -- maxForceAt
                    if(setting.inverted == false) then
                        im.Text("Maximum force at:")
                    else
                        im.Text("Minimum force at:")
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()

                        if(setting.inverted == false) then
                            im.Text("The speed at which the trigger applies its maximum force")
                        else
                            im.Text("The speed at which the trigger applies its minimum force")
                        end

                        im.EndTooltip()
                    end

                    im.PushItemWidth(128)

                    local maxForceAt = im.FloatPtr(setting.maxForceAt)

                    if im.SliderFloat("km/h##17", maxForceAt, 0, 1000, "%.0f") then
                        setting.maxForceAt = maxForceAt[0]
                    end

                    -- Inverted
                    local inverted = im.BoolPtr(setting.inverted)

                    if im.Checkbox("Use minimum speed instead of maximum (inverted)", inverted) then
                        setting.inverted = inverted[0]
                    end

                    im.Separator()
                end

                im.TreePop()
            end

            -- Constant
            setting = settings.brake.rigidity.constant

            if im.TreeNode1("Constant") then
                local enable = im.BoolPtr(setting.enable)

                if im.Checkbox("Enable", enable) then
                    setting.enable = enable[0]

                    if(settings.brake.rigidity.bySpeed.enable == true) then
                        settings.brake.rigidity.bySpeed.enable = false
                    end
                end

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Enable or disable constant trigger force based on two interpolated values")
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()

                    -- minForce
                    im.Text("Minimum force:")

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text("The minimum force applied to the trigger when it is fully released")
                        im.EndTooltip()
                    end

                    im.PushItemWidth(128)

                    local minForce = im.FloatPtr(setting.minForce)

                    if im.SliderFloat("##100", minForce, 0, 255, "%.0f") then
                        setting.minForce = minForce[0]
                    end

                    -- maxForce
                    im.Text("Maximum force:")

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text("The maximum force applied to the trigger when it is fully pressed")
                        im.EndTooltip()
                    end

                    im.PushItemWidth(128)

                    local maxForce = im.FloatPtr(setting.maxForce)

                    if im.SliderFloat("##101", maxForce, 0, 255, "%.0f") then
                        setting.maxForce = maxForce[0]
                    end

                    im.Separator()
                end

                im.TreePop()
            end

            im.TreePop()
        end

        -- ABS
        setting = settings.brake.abs

        if im.TreeNode1("ABS") then
            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox("Enable", enable) then
                setting.enable = enable[0]
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text("Enable or disable haptic feedback while ABS is active")
                im.EndTooltip()
            end

            if(setting.enable == true) then
                im.Separator()

                -- minHz 
                im.Text("Minimum hz:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Minimum frequency at which the trigger vibrates")
                    im.EndTooltip()
                end

                im.PushItemWidth(128)

                local minHz  = im.FloatPtr(setting.minHz)

                if im.SliderFloat("hz##18", minHz, 0, 255, "%.0f") then
                    setting.minHz = minHz[0]
                end

                -- maxHz 
                im.Text("Maximum hz:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Maximum frequency at which the trigger vibrates")
                    im.EndTooltip()
                end

                im.PushItemWidth(128)

                local maxHz  = im.FloatPtr(setting.maxHz)

                if im.SliderFloat("hz##19", maxHz, 0, 255, "%.0f") then
                    setting.maxHz = maxHz[0]
                end

                -- minAmplitude  
                im.Text("Minimum amplitude:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Minimum amplitude of the vibration, lower numbers decrease vibration strenght")
                    im.EndTooltip()
                end

                im.PushItemWidth(128)

                local minAmplitude = im.FloatPtr(setting.minAmplitude)

                if im.SliderFloat("##20", minAmplitude, 1, 8, "%.0f") then
                    setting.minAmplitude = minAmplitude[0]
                end

                -- maxAmplitude  
                im.Text("Maximum amplitude:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Maximum amplitude of the vibration, higher numbers increase vibration strenght")
                    im.EndTooltip()
                end

                im.PushItemWidth(128)

                local maxAmplitude = im.FloatPtr(setting.maxAmplitude)

                if im.SliderFloat("##21", maxAmplitude, 1, 8, "%.0f") then
                    setting.maxAmplitude = maxAmplitude[0]
                end
            end

            im.TreePop()
        end

        im.Separator()

        -- Engine off
        setting = settings.brake.engineOff

        local enable = im.BoolPtr(setting.enable)

        if im.Checkbox("Brake trigger force will be at max when the engine is off", enable) then
            setting.enable = enable[0]
        end

        -- Wheel missing
        setting = settings.brake.wheelMissing

        local enable = im.BoolPtr(setting.enable)

        if im.Checkbox("Brake trigger force will be at max when a wheel is missing", enable) then
            setting.enable = enable[0]
        end

        im.TreePop()
    end
   
    im.Separator()

    -- Lightbar and leds
    if im.TreeNode1("Lightbar and leds") then
        -- Hazard lights
        setting = settings.lightBar.hazardLights

        if im.TreeNode1("Hazard lights") then
            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox("Enable", enable) then
                setting.enable = enable[0]
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text("Enable or disable lightbar flashing while hazards are active")
                im.EndTooltip()
            end

            if(setting.enable == true) then
                im.Separator()

                local r, g, b

                -- colorOn
                im.Text("Color while on:")

                r = im.FloatPtr(setting.colorOn[1])

                im.PushItemWidth(128)

                if im.SliderFloat("R##22", r, 0, 255, "%.0f") then
                    setting.colorOn[1] = r[0]
                end

                g = im.FloatPtr(setting.colorOn[2])

                im.PushItemWidth(128)

                if im.SliderFloat("G##23", g, 0, 255, "%.0f") then
                    setting.colorOn[2] = g[0]
                end

                b = im.FloatPtr(setting.colorOn[3])

                im.PushItemWidth(128)

                if im.SliderFloat("B##24", b, 0, 255, "%.0f") then
                    setting.colorOn[3] = b[0]
                end

                im.Separator()

                -- colorOff
                im.Text("Color while off:")

                r = im.FloatPtr(setting.colorOff[1])

                im.PushItemWidth(128)

                if im.SliderFloat("R##25", r, 0, 255, "%.0f") then
                    setting.colorOff[1] = r[0]
                end

                g = im.FloatPtr(setting.colorOff[2])

                im.PushItemWidth(128)

                if im.SliderFloat("G##26", g, 0, 255, "%.0f") then
                    setting.colorOff[2] = g[0]
                end

                b = im.FloatPtr(setting.colorOff[3])

                im.PushItemWidth(128)

                if im.SliderFloat("B##27", b, 0, 255, "%.0f") then
                    setting.colorOff[3] = b[0]
                end

                im.Separator()
            end

            im.TreePop()
        end

        -- Low fuel
        setting = settings.lightBar.lowFuel

        if im.TreeNode1("Low fuel warning") then
            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox("Enable", enable) then
                setting.enable = enable[0]
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text("Enable or disable microphone led low fuel warning")
                im.EndTooltip()
            end

            if(setting.enable == true) then
                im.Separator()

                -- timeOn
                im.Text("Time on:")

                local timeOn = im.FloatPtr(setting.timeOn)

                im.PushItemWidth(128)

                if im.SliderFloat("ms##28", timeOn, 0, 5000, "%.0f") then
                    setting.timeOn = timeOn[0]
                end

                -- timeOff
                im.Text("Time off:")

                local timeOff = im.FloatPtr(setting.timeOff)

                im.PushItemWidth(128)

                if im.SliderFloat("ms##29", timeOff, 0, 5000, "%.0f") then
                    setting.timeOff = timeOff[0]
                end

                im.Separator()
            end

            im.TreePop()
        end

        -- Parking brake
        setting = settings.lightBar.parkingBrake

        if im.TreeNode1("Parking brake") then
            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox("Enable", enable) then
                setting.enable = enable[0]
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text("Enable or disable microphone led indicator when the parking brake is engaged") 
                im.EndTooltip()
            end

            if(setting.enable == true) then
                im.Separator()

                -- timeOn
                im.Text("Time on:")

                local timeOn = im.FloatPtr(setting.timeOn)

                im.PushItemWidth(128)

                if im.SliderFloat("ms##29", timeOn, 0, 5000, "%.0f") then
                    setting.timeOn = timeOn[0]
                end

                -- timeOff
                im.Text("Time off:")

                local timeOff = im.FloatPtr(setting.timeOff)

                im.PushItemWidth(128)

                if im.SliderFloat("ms##30", timeOff, 0, 5000, "%.0f") then
                    setting.timeOff = timeOff[0]
                end

                im.Separator()
            end

            im.TreePop()
        end

        -- Emergency braking
        setting = settings.lightBar.emergencyBraking

        if im.TreeNode1("Emergency braking") then
            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox("Enable", enable) then
                setting.enable = enable[0]
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text("Enable or disable lightbar emergency braking flashing")
                im.EndTooltip()
            end

            if(setting.enable == true) then
                im.Separator()

                local r, g, b

                -- colorOn
                im.Text("Color while on:")

                r = im.FloatPtr(setting.colorOn[1])

                im.PushItemWidth(128)

                if im.SliderFloat("R##31", r, 0, 255, "%.0f") then
                    setting.colorOn[1] = r[0]
                end

                g = im.FloatPtr(setting.colorOn[2])

                im.PushItemWidth(128)

                if im.SliderFloat("G##32", g, 0, 255, "%.0f") then
                    setting.colorOn[2] = g[0]
                end

                b = im.FloatPtr(setting.colorOn[3])

                im.PushItemWidth(128)

                if im.SliderFloat("B##33", b, 0, 255, "%.0f") then
                    setting.colorOn[3] = b[0]
                end

                im.Separator()

                -- colorOff
                im.Text("Color while off:")

                r = im.FloatPtr(setting.colorOff[1])

                im.PushItemWidth(128)

                if im.SliderFloat("R##34", r, 0, 255, "%.0f") then
                    setting.colorOff[1] = r[0]
                end

                g = im.FloatPtr(setting.colorOff[2])

                im.PushItemWidth(128)

                if im.SliderFloat("G##35", g, 0, 255, "%.0f") then
                end

                b = im.FloatPtr(setting.colorOff[3])

                im.PushItemWidth(128)

                if im.SliderFloat("B##36", b, 0, 255, "%.0f") then
                    setting.colorOff[3] = b[0]
                end

                im.Separator()
            end

            im.TreePop()
        end

        -- Tachometer
        setting = settings.lightBar.tachometer

        if im.TreeNode1("Tachometer") then
            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox("Enable", enable) then
                setting.enable = enable[0]
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text("Enable or disable light bar tachometer")
                im.EndTooltip()
            end

            if(setting.enable == true) then
                im.Separator()

                local r, g, b

                -- colorLow
                im.Text("Color low RPM:")

                r = im.FloatPtr(setting.colorLow[1])

                im.PushItemWidth(128)

                if im.SliderFloat("R##37", r, 0, 255, "%.0f") then
                    setting.colorLow[1] = r[0]
                end

                g = im.FloatPtr(setting.colorLow[2])

                im.PushItemWidth(128)

                if im.SliderFloat("G##38", g, 0, 255, "%.0f") then
                    setting.colorLow[2] = g[0]
                end

                b = im.FloatPtr(setting.colorLow[3])

                im.PushItemWidth(128)

                if im.SliderFloat("B##39", b, 0, 255, "%.0f") then
                    setting.colorLow[3] = b[0]
                end

                im.Separator()

                -- colorMed
                im.Text("Color medium RPM:")

                r = im.FloatPtr(setting.colorMed[1])

                im.PushItemWidth(128)

                if im.SliderFloat("R##40", r, 0, 255, "%.0f") then
                    setting.colorMed[1] = r[0]
                end

                g = im.FloatPtr(setting.colorMed[2])

                im.PushItemWidth(128)

                if im.SliderFloat("G##41", g, 0, 255, "%.0f") then
                end

                b = im.FloatPtr(setting.colorMed[3])

                im.PushItemWidth(128)

                if im.SliderFloat("B##42", b, 0, 255, "%.0f") then
                    setting.colorMed[3] = b[0]
                end

                im.Separator()

                -- colorHi
                im.Text("Color high RPM:")

                r = im.FloatPtr(setting.colorHi[1])

                im.PushItemWidth(128)

                if im.SliderFloat("R##43", r, 0, 255, "%.0f") then
                    setting.colorHi[1] = r[0]
                end

                g = im.FloatPtr(setting.colorHi[2])

                im.PushItemWidth(128)

                if im.SliderFloat("G##44", g, 0, 255, "%.0f") then
                end

                b = im.FloatPtr(setting.colorHi[3])

                im.PushItemWidth(128)

                if im.SliderFloat("B##45", b, 0, 255, "%.0f") then
                    setting.colorHi[3] = b[0]
                end

                im.Separator()
            end

            im.TreePop()
        end

        -- Electronic stability control (esc)
        setting = settings.lightBar.esc

        if im.TreeNode1("Electronic stability control (esc)") then
            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox("Enable", enable) then
                setting.enable = enable[0]
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text("Enable or disable the player LED for electronic stability control when active")
                im.EndTooltip()
            end

            if(setting.enable == true) then
                im.Separator()

                -- timeOn
                im.Text("Time on:")

                local timeOn = im.FloatPtr(setting.timeOn)

                im.PushItemWidth(128)

                if im.SliderFloat("ms##46", timeOn, 0, 5000, "%.0f") then
                    setting.timeOn = timeOn[0]
                end

                im.Separator()
            end

            im.TreePop()
        end

        -- Reverse
        setting = settings.lightBar.reverse

        if im.TreeNode1("Reverse") then
            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox("Enable", enable) then
                setting.enable = enable[0]
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text("Enable or disable lightbar reverse indicator")
                im.EndTooltip()
            end

            if(setting.enable == true) then
                im.Separator()

                local r, g, b

                -- colorOn
                im.Text("Color:")

                r = im.FloatPtr(setting.colorOn[1])

                im.PushItemWidth(128)

                if im.SliderFloat("R##47", r, 0, 255, "%.0f") then
                    setting.colorOn[1] = r[0]
                end

                g = im.FloatPtr(setting.colorOn[2])

                im.PushItemWidth(128)

                if im.SliderFloat("G##48", g, 0, 255, "%.0f") then
                    setting.colorOn[2] = g[0]
                end

                b = im.FloatPtr(setting.colorOn[3])

                im.PushItemWidth(128)

                if im.SliderFloat("B##49", b, 0, 255, "%.0f") then
                    setting.colorOn[3] = b[0]
                end
            end

            im.TreePop()
        end

        im.Separator()

        -- Traction control system (tcs)
        setting = settings.lightBar.tcs

        local enable = im.BoolPtr(setting.enable)

        if im.Checkbox("Enable or disable the mic LED for traction control when active", enable) then
            setting.enable = enable[0]
        end

        im.TreePop()
    end

    im.Separator()

    -- Allow on BeamMP servers
    local enable = im.BoolPtr(settings.enableOnBeamMPServers)

    if im.Checkbox("Allow mod to run on BeamMP servers", enable) then
        settings.enableOnBeamMPServers = enable[0]
    end

    if im.IsItemHovered() then
        im.BeginTooltip()
        im.Text("Allows the mod to run on BeamMP servers (ask for permission)")
        im.EndTooltip()
    end

    im.EndChild()
end

local function renderNotificationMessage()
    if(ui.message.str) then
        local elapsed = tick - ui.message.tick
        local fadeTime = 0.25

        if(elapsed < ui.message.duration) then
            ui.message.progress = (elapsed <= fadeTime) and (elapsed / fadeTime) or (elapsed >= ui.message.duration - fadeTime) and (1 - (elapsed - (ui.message.duration - fadeTime)) / fadeTime) or ui.message.progress
            ui.message.progress = ui.message.progress > 1 and 1 or ui.message.progress
            ui.message.progress = ui.message.progress < 0 and 0 or ui.message.progress

            im.TextColored(im.ImVec4(1, 1, 1, 1 * ui.message.progress), ui.message.str)
            return
        else
            ui.message.str = nil
        end
    end

    im.TextColored(im.ImVec4(1, 1, 1, 1), "")
end

local function renderCreateProfile()
    if(not ui.createProfile.show[0]) then
        return
    end

    im.SetNextWindowSizeConstraints(im.ImVec2(ui.constraints.createProfile.width, ui.constraints.createProfile.height), im.ImVec2(ui.constraints.createProfile.width, ui.constraints.createProfile.height))
    im.Begin("Create new profile", ui.createProfile.show, ui.constraints.createProfile.flags)

    im.TextColored(im.ImVec4(1, 1, 1, 0.6), "Please enter the profile name:")

    local newProfileName = ""
    if im.InputText("Enter Text", newProfileName, 256) then
        print("newProfileName: " ..newProfileName)
    end
end

local function renderWindow()
    im.SetNextWindowSizeConstraints(im.ImVec2(ui.constraints.main.width, ui.constraints.main.height), im.ImVec2(ui.constraints.main.width, ui.constraints.main.height))
    im.Begin("BeamDSX v" ..version.. " - by Feche", ui.main.show, ui.constraints.main.flags)

    im.TextColored(im.ImVec4(1, 1, 1, 0.6), "Welcome to BeamDSX configuration windows, here you can change the\nfeel of the different haptics provided by the mod.")
    im.Separator()

    -- Save button
    if im.Button("Save") then
        profiles:saveProfiles()
        profiles:saveActiveProfileToTemp()
        updateConfig()
        ui:showMessage("Profile '" ..profiles:getProfileName().. "' saved")
    end

    im.SameLine()

    if im.Button("Cancel") then
        toggleUI()
    end

    im.SameLine()

    if im.Button("Restore defaults") then
        profiles:setActiveProfileSettings(settings)
        ui:showMessage("Default settings for profile '" ..profiles:getProfileName().. "' restored, click on Save to confirm", 10)
    end

    im.SameLine()

    im.TextColored(im.ImVec4(1, 1, 1, 0.9), "Active profile: " ..profiles:getProfileName())
end

local function renderTabs()
	if im.BeginTabBar("Profiles") then
        local totalProfiles = profiles:getTotalProfiles()

        if(totalProfiles == 0) then
            ui:showMessage("No profiles are present, please create one", 1)
        end
        
        for i = 1, totalProfiles do
            local profileName = profiles:getProfileName(i)
            local tabFlags = im.TabItemFlags_None
            local activeProfile = profiles:getActiveProfileID()

            if(activeProfile == i) then
                if(ui.main.tabSet == false) then
                    tabFlags = im.TabItemFlags_SetSelected
                    ui.main.tabSet = true
                end
            end

            if im.BeginTabItem(profileName, nil, tabFlags) then
                if(activeProfile ~= i and ui.main.tabSet) then
                    profiles:restoreActiveProfileFromTemp()
                    profiles:setActiveProfile(i)
                    profiles:saveActiveProfileToTemp()
                    settings = profiles:getActiveProfileSettings()
                    ui:showMessage("Profile " ..profileName.. " is now active", 5)
                    ui.main.tabSet = false
                end
                im.EndTabItem()
            end
        end

        if im.BeginTabItem("+", nil, im.TabItemFlags_None) then
            toggleCreateProfileUI(true)
            ui.main.tabSet = false
            im.EndTabItem()
        end
    end

    im.EndTabBar()
end

local function onUpdate(dt)
    tick = tick + dt

    if(ui.main.show[0] == false) then
        if(ui.main.closed == false) then
            toggleUI(false)
        end
        return
    end

    if(not settings) then
        return
    end

    -- Create profile UI
    renderCreateProfile()

    -- Main window
    renderWindow()

    im.Separator()

    -- Draws UI text message notification
    renderNotificationMessage()

    im.Separator()

    -- Profile tabs
    renderTabs()

    -- im.Separator()

    -- Settings
    dsxSettings()
    
    im.End()
end

return
{
    dependencies = { "ui_imgui" },

    onExtensionLoaded = onExtensionLoaded,
    onExtensionUnloaded = onExtensionUnloaded,
    onVehicleResetted = onVehicleResetted,
    onUpdate = onUpdate,
    toggleUI = toggleUI,
}