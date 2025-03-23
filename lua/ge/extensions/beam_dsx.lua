-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local profiles = require("ge.extensions.beam_dsx_profiles")
local text = require("ge.extensions.beam_dsx_text")
local ffi = require("ffi")

local version = "1.0"
local lang = {}
local im = ui_imgui
local tick = 0
local settings = nil

local ui =
{
    deactivateMod = nil,
    main = 
    {
        show = im.BoolPtr(false),
        closed = true,
        tabSet = false,
        preventCreateProfileFromOpeningTick = 0,
        profileRenameName = ""
    },
    createProfile =
    {
        show = im.BoolPtr(false),
        newProfileName = nil,
        str = "",
    },
    constraints =
    {
        main =
        {
            width = 500,
            height = 700,
            flags = im.WindowFlags_AlwaysAutoResize,
            offsetWidth = 230,
        },
        createProfile = 
        {
            width = 230,
            height = 180,
            flags = im.WindowFlags_AlwaysAutoResize,
        },
    },
    -- Message box
    message =
    {
        progress = 0,
        tick = 0,
        str = nil,
        duration = 0,
    },
    -- Functions
    toggle = function(self, change)
        if(change == nil) then
            self.main.show[0] = (not self.main.show[0]) 
        end

        if(self.main.show[0]) then
            settings = profiles:getProfileSettings()

            self.main.profileRenameName = im.ArrayChar(32, profiles:getProfileName())
            self.main.closed = false
            self.message.duration = 0
        else
            self.main.closed = true
        end
    end,
    showMessage = function(self, str, duration)
        self.message.progress = 0
        self.message.tick = tick
        self.message.str = str and str.. "." or nil
        self.message.duration = (duration or 3)
    end,
    checkEnableBeamMp = function(self)
        if(self.deactivateMod == nil) then
            self.deactivateMod = _G["core_modmanager"].deactivateMod
        end

        local enableOnBeamMp = profiles:isBeamMpAllowed()

        if(enableOnBeamMp == true) then
            _G["core_modmanager"].deactivateMod = function(name)
                if debug.getinfo(2, "S").short_src:find("MPModManager.lua") and name:find("beam_dsx") then 
                    return log("W", "deactivateMod", "[beam_dsx] GE: BeamMp tried to disable mod, avoiding ..")
                end

                return self.deactivateMod(name)
            end

            log("i", "checkEnableBeamMp", "[beam_dsx] GE: mod allowed to run on BeamMp servers")
        else
            _G["core_modmanager"].deactivateMod = self.deactivateMod

            log("W", "checkEnableBeamMp", "[beam_dsx] GE: mod disabled to run on BeamMp servers")
        end
    end,
    checkRenameProfile = function(self)
        local profileName = ffi.string(ui.main.profileRenameName)
        local tooltip = lang.strings

        -- Check if profile name is valid
        if(#profileName == 0) then
            return ui:showMessage(tooltip.profileNameEmptyError)
        end

        -- Check if profile name is valid
        if(profileName == "-" or profileName == "+") then
            return ui:showMessage(tooltip.profileNameInvalidError)
        end

        -- Check if profile name already exists
        local p = profiles:getProfiles()

        for i = 1, #p do
            if(p[i].name == profileName) then
                return ui:showMessage(string.format(tooltip.profileAlreadyExistError, profileName))
            end
        end
    end,
    mailboxToVE = function(self, code)
        local playerVehicleId = be:getPlayerVehicleID(0)

        if(code == "mod_enable_disable") then
            be:sendToMailbox("mailboxToVE", jsonEncode({ code = code, playerVehicleId = playerVehicleId, tick = tick }))
        else
            be:sendToMailbox("mailboxToVE", jsonEncode({ code = code, playerVehicleId = playerVehicleId, path = profiles:getPath(), tick = tick }))
        end
        
        log("I", "mailboxToVE", "[beam_dsx] GE: sending mailbox to VE '" ..code.. "' ..")
    end,
}

-- Beam DSX events
local function updateConfig()
    local obj = be:getPlayerVehicle(0)

    if not obj then
        return
    end

    if(profiles:isProfilesEnabled() == false) then
        obj:queueLuaCommand('updateConfig(nil)') 
    else
        obj:queueLuaCommand('updateConfig("' ..profiles:getPath().. '")')
    end
end

local function showCreateProfile(show)
    ui.createProfile.show[0] = show

    if(show) then
        ui.createProfile.str = ""
        ui.createProfile.newProfileName = im.ArrayChar(32, "")
    end
end

local function checkCreateProfile()
    local profileName = ffi.string(ui.createProfile.newProfileName)
    local tooltip = lang.strings

    -- Check if profile name is valid
    if(#profileName == 0) then
        ui.createProfile.str = tooltip.profileNameEmptyError
        return
    end

    -- Check if profile name is valid
    if(profileName == "-" or profileName == "+") then
        ui.createProfile.str = tooltip.profileNameInvalidError
        return
    end

    -- Check if profile name already exists
    local p = profiles:getProfiles()

    for i = 1, #p do
        if(p[i].name == profileName) then
            ui.createProfile.str = string.format(tooltip.profileAlreadyExistError, profileName)
            return
        end
    end

    -- Everything ok
    profiles:loadProfiles()
    profiles:createProfile(profileName, profiles:getDefaultSettings())

    showCreateProfile(false)
    ui:showMessage(string.format(tooltip.profileCreateOk, profileName))
end

local function renderCreateProfile()
    if(not ui.createProfile.show[0]) then
        return
    end

    local height = #ui.createProfile.str > 0 and ui.constraints.createProfile.height or ui.constraints.createProfile.height - 25
    local tooltip = lang.strings

    im.SetNextWindowSizeConstraints(im.ImVec2(ui.constraints.createProfile.width, height), im.ImVec2(ui.constraints.createProfile.width, height))
    im.Begin(tooltip.profileCreateTitle, ui.createProfile.show, ui.constraints.createProfile.flags)

    im.PushTextWrapPos(0.0)
    im.TextColored(im.ImVec4(1, 1, 1, 0.6), tooltip.profileCreateName)
    im.PopTextWrapPos()
    
    im.PushItemWidth(185)

    if im.InputText("##profileCreateNew", ui.createProfile.newProfileName, 32, im.InputTextFlags_EnterReturnsTrue) then
        checkCreateProfile()
    end

    im.Spacing()

    if im.Button(tooltip.profileCreateButton1) then
        checkCreateProfile()
    end

    im.SameLine()

    if im.Button(tooltip.profileCreateButton2) then
        showCreateProfile(false)
    end

    -- Show error message
    if(#ui.createProfile.str > 0) then
        im.Spacing()
        im.Separator()
        im.Spacing()
        im.PushTextWrapPos(0.0)
        im.TextColored(im.ImVec4(1, 1, 1, 0.6), ui.createProfile.str)
        im.PopTextWrapPos()
    end
end

local function renderButtons()
    if(not settings) then
        return
    end

    local tooltip = lang.strings
    local profileName = profiles:getProfileName()

    im.Separator()
    im.Spacing()

    -- Save profile
    if im.Button(tooltip.saveProfile) then
        local newProfileName = ffi.string(ui.main.profileRenameName)

        if(profileName ~= newProfileName) then
            profiles:setProfileName(newProfileName)
        end

        profiles:saveProfiles()
        ui:mailboxToVE("save")
        ui:showMessage(string.format(tooltip.saveProfileOk, profileName))
    end

    if im.IsItemHovered() then
        im.BeginTooltip()
        im.Text(tooltip.saveProfileHovered)
        im.EndTooltip()
    end

    im.SameLine()

    -- Delete profile
    if im.Button(tooltip.deleteProfile) then
        if(profiles:getTotalProfiles() - 1 == 0) then
            ui:showMessage(string.format(tooltip.deleteProfileError, profileName), 5)
            return
        end

        profiles:deleteProfile(profiles:getActiveProfileID())
    end

    if im.IsItemHovered() then
        im.BeginTooltip()
        im.Text(string.format(tooltip.deleteProfileHover, profileName))
        im.EndTooltip()
    end

    im.SameLine()

    -- Restore defaults to profile
    if im.Button(tooltip.restoreProfile) then
        profiles:setProfileSettings(profiles:getDefaultSettings())
        settings = profiles:getProfileSettings()

        ui:showMessage(string.format(tooltip.restoreProfileOk, profileName, tooltip.saveProfile), 10)
    end

    if im.IsItemHovered() then
        im.BeginTooltip()
        im.Text(string.format(tooltip.restoreProfileHover, profileName))
        im.EndTooltip()
    end

    im.SameLine()

    im.SetCursorPosX(im.GetWindowWidth() - 30)

    -- Change language
    if im.Button(tooltip.changeLanguage) then
        text:switchLanguage()

        -- Update current language
        lang = text:getText()
    end

    if im.IsItemHovered() then
        im.BeginTooltip()
        im.Text(tooltip.changeLanguageHover)
        im.EndTooltip()
    end
end

local function renderProfileSettings()
    if(not settings) then
        return
    end

    local setting = nil
    local tooltip = nil

    im.BeginChild1("TriggerSettings", im.ImVec2(ui.constraints.main.width - 20, ui.constraints.main.height - ui.constraints.main.offsetWidth, ui.constraints.main.flags))

    -- Throttle trigger
    if im.TreeNode1(lang.titles[1]) then
        im.Spacing()

        -- Disable all haptics
        setting = settings.throttle
        tooltip = lang.throttle

        local enable = im.BoolPtr(setting.enable)

        if im.Checkbox(lang.general.enable, enable) then
            setting.enable = enable[0]
        end

        if im.IsItemHovered() then
            im.BeginTooltip()
            im.Text(tooltip.enableHover)
            im.EndTooltip()
        end

        im.Spacing()

        if(setting.enable) then
            im.Separator()

            -- Rigidity
            tooltip = lang.general.rigidity

            if im.TreeNode1(lang.throttle.titles[1]) then
                -- By speed
                setting = settings.throttle.rigidity.bySpeed

                if im.TreeNode1(tooltip.titles[1]) then
                    local enable = im.BoolPtr(setting.enable)

                    if im.Checkbox(lang.general.enable, enable) then
                        setting.enable = enable[0]

                        if(settings.throttle.rigidity.constant.enable == true) then
                            settings.throttle.rigidity.constant.enable = false
                        end
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.bySpeed.enable)
                        im.EndTooltip()
                    end

                    if(setting.enable == true) then
                        im.Separator()

                        -- minForce
                        im.Text(tooltip.bySpeed.titles[1])

                        im.PushItemWidth(128)

                        local minForce = im.FloatPtr(setting.minForce)

                        if im.SliderFloat("##1", minForce, 0, 255, "%.0f") then
                            setting.minForce = minForce[0]
                        end

                        if im.IsItemHovered() then
                            im.BeginTooltip()

                            if(setting.inverted == true) then
                                im.Text(string.format(tooltip.minForceInverted, setting.maxForceAt))
                            else
                                im.Text(string.format(tooltip.minForce, setting.maxForceAt))
                            end

                            im.EndTooltip()
                        end

                        -- maxForce
                        im.Text(tooltip.bySpeed.titles[2])

                        im.PushItemWidth(128)

                        local maxForce = im.FloatPtr(setting.maxForce)

                        if im.SliderFloat("##2", maxForce, 0, 255, "%.0f") then
                            setting.maxForce = maxForce[0]
                        end

                        if im.IsItemHovered() then
                            im.BeginTooltip()
                        
                            if(setting.inverted == true) then
                                im.Text(string.format(tooltip.maxForceInverted, setting.maxForceAt))
                            else
                                im.Text(string.format(tooltip.maxForce, setting.maxForceAt))
                            end

                            im.EndTooltip()
                        end

                        -- maxForceAt
                        im.Text(tooltip.bySpeed.titles[3])

                        im.PushItemWidth(128)

                        local maxForceAt = im.FloatPtr(setting.maxForceAt)

                        if im.SliderFloat("km/h##3", maxForceAt, 0, 1000, "%.0f") then
                            setting.maxForceAt = maxForceAt[0]
                        end

                        if im.IsItemHovered() then
                            im.BeginTooltip()
                            im.Text(setting.inverted == false and tooltip.maxForceAt or tooltip.maxForceAtInverted)
                            im.EndTooltip()
                        end

                        -- Inverted
                        local inverted = im.BoolPtr(setting.inverted)

                        if im.Checkbox(tooltip.inverted, inverted) then
                            setting.inverted = inverted[0]
                        end

                        im.Separator()
                    end

                    im.TreePop()
                end

                -- Constant
                setting = settings.throttle.rigidity.constant

                if im.TreeNode1(tooltip.titles[2]) then
                    local enable = im.BoolPtr(setting.enable)

                    if im.Checkbox(lang.general.enable, enable) then
                        setting.enable = enable[0]

                        if(settings.throttle.rigidity.bySpeed.enable == true) then
                            settings.throttle.rigidity.bySpeed.enable = false
                        end
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.constant.enable)
                        im.EndTooltip()
                    end

                    if(setting.enable == true) then
                        im.Separator()

                        -- minForce
                        im.Text(tooltip.constant.titles[1])

                        im.PushItemWidth(128)

                        local minForce = im.FloatPtr(setting.minForce)

                        if im.SliderFloat("##4", minForce, 0, 255, "%.0f") then
                            setting.minForce = minForce[0]
                        end

                        if im.IsItemHovered() then
                            im.BeginTooltip()
                            im.Text(lang.general.rigidity.constant.minForce)
                            im.EndTooltip()
                        end

                        -- maxForce
                        im.Text(tooltip.constant.titles[2])

                        im.PushItemWidth(128)

                        local maxForce = im.FloatPtr(setting.maxForce)

                        if im.SliderFloat("##5", maxForce, 0, 255, "%.0f") then
                            setting.maxForce = maxForce[0]
                        end

                        if im.IsItemHovered() then
                            im.BeginTooltip()
                            im.Text(lang.general.rigidity.constant.maxForce)
                            im.EndTooltip()
                        end

                        im.Separator()
                    end

                    im.TreePop()
                end

                im.TreePop()
            end

            -- Wheelslip
            setting = settings.throttle.wheelSlip
            tooltip = lang.throttle.wheelSlip

            if im.TreeNode1(lang.throttle.titles[2]) then
                local enable = im.BoolPtr(setting.enable)

                if im.Checkbox(lang.general.enable, enable) then
                    setting.enable = enable[0]
                end

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text(tooltip.enable)
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()

                    -- Tolerance
                    im.Text(tooltip.titles[1])

                    im.PushItemWidth(128)

                    local tolerance = im.FloatPtr(setting.tolerance)

                    if im.SliderFloat("##6", tolerance, 0, 200, "%.0f") then
                        setting.tolerance  = tolerance[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.tolerance)
                        im.EndTooltip()
                    end

                    -- maxForceAt 
                    im.Text(tooltip.titles[2])

                    im.PushItemWidth(128)

                    local maxForceAt  = im.FloatPtr(setting.maxForceAt)

                    if im.SliderFloat("##7", maxForceAt, 0, 200, "%.0f") then
                        setting.maxForceAt = maxForceAt[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.maxForceAt)
                        im.EndTooltip()
                    end

                    -- minHz 
                    im.Text(tooltip.titles[3])

                    im.PushItemWidth(128)

                    local minHz  = im.FloatPtr(setting.minHz)

                    if im.SliderFloat("hz##8", minHz, 0, 255, "%.0f") then
                        setting.minHz = minHz[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.minHz)
                        im.EndTooltip()
                    end

                    -- maxHz 
                    im.Text(tooltip.titles[4])

                    im.PushItemWidth(128)

                    local maxHz  = im.FloatPtr(setting.maxHz)

                    if im.SliderFloat("hz##9", maxHz, 0, 255, "%.0f") then
                        setting.maxHz = maxHz[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.maxHz)
                        im.EndTooltip()
                    end

                    -- minAmplitude  
                    im.Text(tooltip.titles[5])

                    im.PushItemWidth(128)

                    local minAmplitude = im.FloatPtr(setting.minAmplitude)

                    if im.SliderFloat("##10", minAmplitude, 1, 8, "%.0f") then
                        setting.minAmplitude  = minAmplitude[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.minAmplitude)
                        im.EndTooltip()
                    end

                    -- maxAmplitude  
                    im.Text(tooltip.titles[6])

                    im.PushItemWidth(128)

                    local maxAmplitude = im.FloatPtr(setting.maxAmplitude)

                    if im.SliderFloat("##11", maxAmplitude, 1, 8, "%.0f") then
                        setting.maxAmplitude  = maxAmplitude[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.maxAmplitude)
                        im.EndTooltip()
                    end

                    im.Separator()
                end

                im.TreePop()
            end

            -- Upshift
            setting = settings.throttle.upShift
            tooltip = lang.throttle.upShift

            if im.TreeNode1(lang.throttle.titles[3]) then
                local enable = im.BoolPtr(setting.enable)

                if im.Checkbox(lang.general.enable, enable) then
                    setting.enable = enable[0]
                end

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text(tooltip.enable)
                    im.EndTooltip()
                end

                if(setting.enable) then
                    im.Separator()

                    -- maxHz 
                    im.Text(tooltip.titles[1])

                    im.PushItemWidth(128)

                    local maxHz = im.FloatPtr(setting.maxHz)

                    if im.SliderFloat("hz##12", maxHz, 1, 255, "%.0f") then
                        setting.maxHz  = maxHz[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.maxHz)
                        im.EndTooltip()
                    end

                    -- maxForce  
                    im.Text(tooltip.titles[2])

                    im.PushItemWidth(128)

                    local maxForce = im.FloatPtr(setting.maxForce)

                    if im.SliderFloat("##13", maxForce, 1, 255, "%.0f") then
                        setting.maxForce  = maxForce[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.maxForce)
                        im.EndTooltip()
                    end

                    -- timeOn  
                    im.Text(tooltip.titles[3])

                    im.PushItemWidth(128)

                    local timeOn = im.FloatPtr(setting.timeOn)

                    if im.SliderFloat("ms##14", timeOn, 1, 255, "%.0f") then
                        setting.timeOn  = timeOn[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.timeOn)
                        im.EndTooltip()
                    end

                    im.Separator()
                end

                im.TreePop()
            end

            -- Rev limit
            setting = settings.throttle.revLimit
            tooltip = lang.throttle.revLimit

            if im.TreeNode1(lang.throttle.titles[4]) then
                local enable = im.BoolPtr(setting.enable)

                if im.Checkbox(lang.general.enable, enable) then
                    setting.enable = enable[0]
                end

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text(tooltip.enable)
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()

                    -- minHz 
                    im.Text(tooltip.titles[1])

                    im.PushItemWidth(128)

                    local minHz  = im.FloatPtr(setting.minHz)

                    if im.SliderFloat("hz##8", minHz, 0, 255, "%.0f") then
                        setting.minHz = minHz[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.minHz)
                        im.EndTooltip()
                    end

                    -- maxHz 
                    im.Text(tooltip.titles[2])

                    im.PushItemWidth(128)

                    local maxHz  = im.FloatPtr(setting.maxHz)

                    if im.SliderFloat("hz##9", maxHz, 0, 255, "%.0f") then
                        setting.maxHz = maxHz[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.maxHz)
                        im.EndTooltip()
                    end

                    -- maxForce  
                    im.Text(tooltip.titles[3])

                    im.PushItemWidth(128)

                    local maxForce = im.FloatPtr(setting.maxForce)

                    if im.SliderFloat("##13", maxForce, 1, 255, "%.0f") then
                        setting.maxForce  = maxForce[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.maxForce)
                        im.EndTooltip()
                    end

                    -- timeOn  
                    im.Text(tooltip.titles[4])

                    im.PushItemWidth(128)

                    local timeOn = im.FloatPtr(setting.timeOn)

                    if im.SliderFloat("ms##14", timeOn, 1, 255, "%.0f") then
                        setting.timeOn  = timeOn[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.timeOn)
                        im.EndTooltip()
                    end
                end

                im.TreePop()
            end

            im.Separator()
            im.Spacing()

            -- Engine off
            setting = settings.throttle.engineOff
            tooltip = lang.throttle

            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox(tooltip.engineOff, enable) then
                setting.enable = enable[0]
            end

            im.Spacing()
            im.Separator()
        end

        im.TreePop()
    end

    -- Brake trigger
    if im.TreeNode1(lang.titles[2]) then
        setting = settings.brake
        tooltip = lang.brake

        local enable = im.BoolPtr(setting.enable)

        im.Spacing()

        if im.Checkbox(lang.general.enable, enable) then
            setting.enable = enable[0]
        end

        im.Spacing()

        if im.IsItemHovered() then
            im.BeginTooltip()
            im.Text(tooltip.enableHover)
            im.EndTooltip()
        end

        if(setting.enable) then
            im.Separator()

            -- Rigidity
            tooltip = lang.general.rigidity

            if im.TreeNode1(lang.brake.titles[1]) then
                -- bySpeed
                setting = settings.brake.rigidity.bySpeed

                if im.TreeNode1(lang.general.rigidity.titles[1]) then
                    local enable = im.BoolPtr(setting.enable)

                    if im.Checkbox(lang.general.enable, enable) then
                        setting.enable = enable[0]

                        if(settings.brake.rigidity.constant.enable == true) then
                            settings.brake.rigidity.constant.enable = false
                        end
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.bySpeed.enable)
                        im.EndTooltip()
                    end

                    if(setting.enable == true) then
                        im.Separator()

                        -- minForce
                        im.Text(tooltip.bySpeed.titles[1])

                        im.PushItemWidth(128)

                        local minForce = im.FloatPtr(setting.minForce)

                        if im.SliderFloat("##15", minForce, 0, 255, "%.0f") then
                            setting.minForce = minForce[0]
                        end

                         if im.IsItemHovered() then
                            im.BeginTooltip()

                            if(setting.inverted == true) then
                                im.Text(string.format(tooltip.minForceInverted, setting.maxForceAt))
                            else
                                im.Text(string.format(tooltip.minForce, setting.maxForceAt))
                            end

                            im.EndTooltip()
                        end

                        -- maxForce
                        im.Text(tooltip.bySpeed.titles[2])

                        im.PushItemWidth(128)

                        local maxForce = im.FloatPtr(setting.maxForce)

                        if im.SliderFloat("##16", maxForce, 0, 255, "%.0f") then
                            setting.maxForce = maxForce[0]
                        end

                        if im.IsItemHovered() then
                            im.BeginTooltip()
                        
                            if(setting.inverted == true) then
                                im.Text(string.format(tooltip.maxForceInverted, setting.maxForceAt))
                            else
                                im.Text(string.format(tooltip.maxForce, setting.maxForceAt))
                            end

                            im.EndTooltip()
                        end

                        -- maxForceAt
                        im.Text(tooltip.bySpeed.titles[3])

                        im.PushItemWidth(128)

                        local maxForceAt = im.FloatPtr(setting.maxForceAt)

                        if im.SliderFloat("km/h##17", maxForceAt, 0, 1000, "%.0f") then
                            setting.maxForceAt = maxForceAt[0]
                        end

                        if im.IsItemHovered() then
                            im.BeginTooltip()
                            im.Text(setting.inverted == false and tooltip.maxForceAt or tooltip.maxForceAtInverted)
                            im.EndTooltip()
                        end

                        -- Inverted
                        local inverted = im.BoolPtr(setting.inverted)

                        if im.Checkbox(tooltip.inverted, inverted) then
                            setting.inverted = inverted[0]
                        end

                        im.Separator()
                    end

                    im.TreePop()
                end

                -- Constant
                setting = settings.brake.rigidity.constant

                if im.TreeNode1(tooltip.titles[2]) then
                    local enable = im.BoolPtr(setting.enable)

                    if im.Checkbox(lang.general.enable, enable) then
                        setting.enable = enable[0]

                        if(settings.brake.rigidity.bySpeed.enable == true) then
                            settings.brake.rigidity.bySpeed.enable = false
                        end
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.constant.enable)
                        im.EndTooltip()
                    end

                    if(setting.enable == true) then
                        im.Separator()

                        -- minForce
                        im.Text(tooltip.constant.titles[1])

                        im.PushItemWidth(128)

                        local minForce = im.FloatPtr(setting.minForce)

                        if im.SliderFloat("##100", minForce, 0, 255, "%.0f") then
                            setting.minForce = minForce[0]
                        end

                        if im.IsItemHovered() then
                            im.BeginTooltip()
                            im.Text(lang.general.rigidity.constant.minForce)
                            im.EndTooltip()
                        end

                        -- maxForce
                        im.Text(tooltip.constant.titles[2])

                        im.PushItemWidth(128)

                        local maxForce = im.FloatPtr(setting.maxForce)

                        if im.SliderFloat("##101", maxForce, 0, 255, "%.0f") then
                            setting.maxForce = maxForce[0]
                        end

                        if im.IsItemHovered() then
                            im.BeginTooltip()
                            im.Text(lang.general.rigidity.constant.maxForce)
                            im.EndTooltip()
                        end

                        im.Separator()
                    end

                    im.TreePop()
                end

                im.TreePop()
            end

            -- ABS
            setting = settings.brake.abs
            tooltip = lang.brake.abs

            if im.TreeNode1(lang.brake.titles[2]) then
                local enable = im.BoolPtr(setting.enable)

                if im.Checkbox(lang.general.enable, enable) then
                    setting.enable = enable[0]
                end

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text(tooltip.enable)
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()

                    -- minHz 
                    im.Text(tooltip.titles[1])

                    im.PushItemWidth(128)

                    local minHz  = im.FloatPtr(setting.minHz)

                    if im.SliderFloat("hz##18", minHz, 0, 255, "%.0f") then
                        setting.minHz = minHz[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.minHz)
                        im.EndTooltip()
                    end

                    -- maxHz 
                    im.Text(tooltip.titles[2])

                    im.PushItemWidth(128)

                    local maxHz  = im.FloatPtr(setting.maxHz)

                    if im.SliderFloat("hz##19", maxHz, 0, 255, "%.0f") then
                        setting.maxHz = maxHz[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.maxHz)
                        im.EndTooltip()
                    end

                    -- minAmplitude  
                    im.Text(tooltip.titles[3])
                    im.PushItemWidth(128)

                    local minAmplitude = im.FloatPtr(setting.minAmplitude)

                    if im.SliderFloat("##20", minAmplitude, 1, 8, "%.0f") then
                        setting.minAmplitude = minAmplitude[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.minAmplitude)
                        im.EndTooltip()
                    end

                    -- maxAmplitude  
                    im.Text(tooltip.titles[4])
                    im.PushItemWidth(128)

                    local maxAmplitude = im.FloatPtr(setting.maxAmplitude)

                    if im.SliderFloat("##21", maxAmplitude, 1, 8, "%.0f") then
                        setting.maxAmplitude = maxAmplitude[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.maxAmplitude)
                        im.EndTooltip()
                    end

                end

                im.TreePop()
            end

            im.Separator()
            im.Spacing()

            -- Engine off
            setting = settings.brake.engineOff

            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox(tooltip.engineOff, enable) then
                setting.enable = enable[0]
            end

            im.Spacing()

            -- Wheel missing
            setting = settings.brake.wheelMissing

            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox(tooltip.wheelMissing, enable) then
                setting.enable = enable[0]
            end

            im.Spacing()
            im.Separator()
        end

        im.TreePop()
    end

    -- Lightbar and leds
    if im.TreeNode1(lang.titles[3]) then
        setting = settings.lightBar
        tooltip = lang.lightBar

        local enable = im.BoolPtr(setting.enable)

        im.Spacing()

        if im.Checkbox(lang.general.enable, enable) then
            setting.enable = enable[0]
        end

        im.Spacing()

        if im.IsItemHovered() then
            im.BeginTooltip()
            im.Text(tooltip.enableHover)
            im.EndTooltip()
        end

        if(setting.enable) then
            im.Separator()

            -- Hazard lights
            setting = settings.lightBar.hazardLights
            tooltip = lang.lightBar.hazardLights

            if im.TreeNode1(lang.lightBar.titles[1]) then
                local enable = im.BoolPtr(setting.enable)

                if im.Checkbox(lang.general.enable, enable) then
                    setting.enable = enable[0]
                end

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text(tooltip.enable)
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()

                    local r, g, b

                    -- colorOn
                    im.Text(tooltip.titles[1])

                    r = im.FloatPtr(setting.colorOn[1])

                    im.PushItemWidth(128)

                    if im.SliderFloat("R##22", r, 0, 255, "%.0f") then
                        setting.colorOn[1] = r[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorOn)
                        im.EndTooltip()
                    end

                    g = im.FloatPtr(setting.colorOn[2])

                    im.PushItemWidth(128)

                    if im.SliderFloat("G##23", g, 0, 255, "%.0f") then
                        setting.colorOn[2] = g[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorOn)
                        im.EndTooltip()
                    end

                    b = im.FloatPtr(setting.colorOn[3])

                    im.PushItemWidth(128)

                    if im.SliderFloat("B##24", b, 0, 255, "%.0f") then
                        setting.colorOn[3] = b[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorOn)
                        im.EndTooltip()
                    end

                    im.Separator()

                    -- colorOff
                    im.Text(tooltip.titles[2])

                    r = im.FloatPtr(setting.colorOff[1])

                    im.PushItemWidth(128)

                    if im.SliderFloat("R##25", r, 0, 255, "%.0f") then
                        setting.colorOff[1] = r[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorOff)
                        im.EndTooltip()
                    end

                    g = im.FloatPtr(setting.colorOff[2])

                    im.PushItemWidth(128)

                    if im.SliderFloat("G##26", g, 0, 255, "%.0f") then
                        setting.colorOff[2] = g[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorOff)
                        im.EndTooltip()
                    end

                    b = im.FloatPtr(setting.colorOff[3])

                    im.PushItemWidth(128)

                    if im.SliderFloat("B##27", b, 0, 255, "%.0f") then
                        setting.colorOff[3] = b[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorOff)
                        im.EndTooltip()
                    end

                    im.Separator()
                end

                im.TreePop()
            end

            -- Low fuel
            setting = settings.lightBar.lowFuel
            tooltip = lang.lightBar.lowFuel

            if im.TreeNode1(lang.lightBar.titles[2]) then
                local enable = im.BoolPtr(setting.enable)

                if im.Checkbox(lang.general.enable, enable) then
                    setting.enable = enable[0]
                end

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text(tooltip.enable)
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()

                    -- timeOn
                    im.Text(tooltip.titles[1])

                    local timeOn = im.FloatPtr(setting.timeOn)

                    im.PushItemWidth(128)

                    if im.SliderFloat("ms##28", timeOn, 0, 5000, "%.0f") then
                        setting.timeOn = timeOn[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.micLed.timeOn)
                        im.EndTooltip()
                    end

                    -- timeOff
                    im.Text(tooltip.titles[2])

                    local timeOff = im.FloatPtr(setting.timeOff)

                    im.PushItemWidth(128)

                    if im.SliderFloat("ms##29", timeOff, 0, 5000, "%.0f") then
                        setting.timeOff = timeOff[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.micLed.timeOff)
                        im.EndTooltip()
                    end

                    im.Separator()
                end

                im.TreePop()
            end

            -- Parking brake
            setting = settings.lightBar.parkingBrake
            tooltip = lang.lightBar.parkingBrake

            if im.TreeNode1(lang.lightBar.titles[3]) then
                local enable = im.BoolPtr(setting.enable)

                if im.Checkbox(lang.general.enable, enable) then
                    setting.enable = enable[0]
                end

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text(tooltip.enable) 
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()

                    -- timeOn
                    im.Text(tooltip.titles[1])

                    local timeOn = im.FloatPtr(setting.timeOn)

                    im.PushItemWidth(128)

                    if im.SliderFloat("ms##29", timeOn, 0, 5000, "%.0f") then
                        setting.timeOn = timeOn[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.micLed.timeOn)
                        im.EndTooltip()
                    end

                    -- timeOff
                    im.Text(tooltip.titles[2])

                    local timeOff = im.FloatPtr(setting.timeOff)

                    im.PushItemWidth(128)

                    if im.SliderFloat("ms##30", timeOff, 0, 5000, "%.0f") then
                        setting.timeOff = timeOff[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.micLed.timeOff)
                        im.EndTooltip()
                    end

                    im.Separator()
                end

                im.TreePop()
            end

            -- Emergency braking
            setting = settings.lightBar.emergencyBraking
            tooltip = lang.lightBar.emergencyBraking

            if im.TreeNode1(lang.lightBar.titles[4]) then
                local enable = im.BoolPtr(setting.enable)

                if im.Checkbox(lang.general.enable, enable) then
                    setting.enable = enable[0]
                end

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text(tooltip.enable)
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()

                    local r, g, b

                    -- colorOn
                    im.Text(tooltip.titles[1])

                    r = im.FloatPtr(setting.colorOn[1])

                    im.PushItemWidth(128)

                    if im.SliderFloat("R##31", r, 0, 255, "%.0f") then
                        setting.colorOn[1] = r[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorOn)
                        im.EndTooltip()
                    end

                    g = im.FloatPtr(setting.colorOn[2])

                    im.PushItemWidth(128)

                    if im.SliderFloat("G##32", g, 0, 255, "%.0f") then
                        setting.colorOn[2] = g[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorOn)
                        im.EndTooltip()
                    end

                    b = im.FloatPtr(setting.colorOn[3])

                    im.PushItemWidth(128)

                    if im.SliderFloat("B##33", b, 0, 255, "%.0f") then
                        setting.colorOn[3] = b[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorOn)
                        im.EndTooltip()
                    end

                    im.Separator()

                    -- colorOff
                    im.Text(tooltip.titles[2])

                    r = im.FloatPtr(setting.colorOff[1])

                    im.PushItemWidth(128)

                    if im.SliderFloat("R##34", r, 0, 255, "%.0f") then
                        setting.colorOff[1] = r[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorOff)
                        im.EndTooltip()
                    end

                    g = im.FloatPtr(setting.colorOff[2])

                    im.PushItemWidth(128)

                    if im.SliderFloat("G##35", g, 0, 255, "%.0f") then
                        setting.colorOff[2] = g[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorOff)
                        im.EndTooltip()
                    end

                    b = im.FloatPtr(setting.colorOff[3])

                    im.PushItemWidth(128)

                    if im.SliderFloat("B##36", b, 0, 255, "%.0f") then
                        setting.colorOff[3] = b[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorOff)
                        im.EndTooltip()
                    end

                    im.Separator()
                    im.Spacing()

                    -- alwaysBlink
                    local enable = im.BoolPtr(setting.alwaysBlink)

                    if im.Checkbox(tooltip.alwaysBlink, enable) then
                        setting.alwaysBlink = enable[0]
                    end
                end

                im.TreePop()
            end

            -- Tachometer
            setting = settings.lightBar.tachometer
            tooltip = lang.lightBar.tachometer

            if im.TreeNode1(lang.lightBar.titles[5]) then
                local enable = im.BoolPtr(setting.enable)

                if im.Checkbox(lang.general.enable, enable) then
                    setting.enable = enable[0]
                end

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text(tooltip.enable)
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()

                    local r, g, b

                    -- colorLow
                    im.Text(tooltip.titles[1])

                    r = im.FloatPtr(setting.colorLow[1])

                    im.PushItemWidth(128)

                    if im.SliderFloat("R##37", r, 0, 255, "%.0f") then
                        setting.colorLow[1] = r[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorLow)
                        im.EndTooltip()
                    end

                    g = im.FloatPtr(setting.colorLow[2])

                    im.PushItemWidth(128)

                    if im.SliderFloat("G##38", g, 0, 255, "%.0f") then
                        setting.colorLow[2] = g[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorLow)
                        im.EndTooltip()
                    end

                    b = im.FloatPtr(setting.colorLow[3])

                    im.PushItemWidth(128)

                    if im.SliderFloat("B##39", b, 0, 255, "%.0f") then
                        setting.colorLow[3] = b[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorLow)
                        im.EndTooltip()
                    end

                    im.Separator()

                    -- colorMed
                    im.Text(tooltip.titles[2])

                    r = im.FloatPtr(setting.colorMed[1])

                    im.PushItemWidth(128)

                    if im.SliderFloat("R##40", r, 0, 255, "%.0f") then
                        setting.colorMed[1] = r[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorMed)
                        im.EndTooltip()
                    end

                    g = im.FloatPtr(setting.colorMed[2])

                    im.PushItemWidth(128)

                    if im.SliderFloat("G##41", g, 0, 255, "%.0f") then
                        setting.colorMed[2] = g[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorMed)
                        im.EndTooltip()
                    end

                    b = im.FloatPtr(setting.colorMed[3])

                    im.PushItemWidth(128)

                    if im.SliderFloat("B##42", b, 0, 255, "%.0f") then
                        setting.colorMed[3] = b[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorMed)
                        im.EndTooltip()
                    end

                    im.Separator()

                    -- colorHi
                    im.Text(tooltip.titles[3])

                    r = im.FloatPtr(setting.colorHi[1])

                    im.PushItemWidth(128)

                    if im.SliderFloat("R##43", r, 0, 255, "%.0f") then
                        setting.colorHi[1] = r[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorHi)
                        im.EndTooltip()
                    end

                    g = im.FloatPtr(setting.colorHi[2])

                    im.PushItemWidth(128)

                    if im.SliderFloat("G##44", g, 0, 255, "%.0f") then
                        setting.colorHi[2] = g[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorHi)
                        im.EndTooltip()
                    end

                    b = im.FloatPtr(setting.colorHi[3])

                    im.PushItemWidth(128)

                    if im.SliderFloat("B##45", b, 0, 255, "%.0f") then
                        setting.colorHi[3] = b[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorHi)
                        im.EndTooltip()
                    end

                    im.Separator()
                end

                im.TreePop()
            end

            -- Reverse
            setting = settings.lightBar.reverse
            tooltip = lang.lightBar.reverse

            if im.TreeNode1(lang.lightBar.titles[7]) then
                local enable = im.BoolPtr(setting.enable)

                if im.Checkbox(lang.general.enable, enable) then
                    setting.enable = enable[0]
                end

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text(tooltip.enable)
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()

                    local r, g, b

                    -- colorOn
                    im.Text(tooltip.titles[1])

                    r = im.FloatPtr(setting.colorOn[1])

                    im.PushItemWidth(128)

                    if im.SliderFloat("R##47", r, 0, 255, "%.0f") then
                        setting.colorOn[1] = r[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorOn)
                        im.EndTooltip()
                    end

                    g = im.FloatPtr(setting.colorOn[2])

                    im.PushItemWidth(128)

                    if im.SliderFloat("G##48", g, 0, 255, "%.0f") then
                        setting.colorOn[2] = g[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorOn)
                        im.EndTooltip()
                    end

                    b = im.FloatPtr(setting.colorOn[3])

                    im.PushItemWidth(128)

                    if im.SliderFloat("B##49", b, 0, 255, "%.0f") then
                        setting.colorOn[3] = b[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.colorOn)
                        im.EndTooltip()
                    end
                end
            end
            
            im.Separator()
            im.Spacing()

            -- Traction Control System (TCS)
            setting = settings.lightBar.tcs
            tooltip = lang.lightBar.tcs

            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox(tooltip.enable, enable) then
                setting.enable = enable[0]
            end

            im.Spacing()

            -- Electronic Stability Control (ESC)
            setting = settings.lightBar.esc
            tooltip = lang.lightBar.esc

            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox(tooltip.enable, enable) then
                setting.enable = enable[0]
            end

            im.Spacing()
            im.Separator()

            im.TreePop()
        end

        im.TreePop()
    end

    im.Spacing()
    im.Separator()
    im.Spacing()

    -- Profile settings
    if im.TreeNode1(string.format(lang.titles[4], profiles:getProfileName())) then
        setting = settings.lightBar
        tooltip = lang.profile

        -- Profile name
        if im.TreeNode1(tooltip.titles[1]) then
            tooltip = lang.profile.rename

            --im.Text(tooltip.titles[1])

            im.Spacing()
            --im.Separator()
            im.Spacing()

            im.PushItemWidth(185)

            if im.InputText("##profileRenameName", ui.main.profileRenameName, 32, im.InputTextFlags_EnterReturnsTrue) then
                
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text(lang.profile.hover, lang.strings.saveProfile)
                im.EndTooltip()
            end

            im.Spacing()
            im.Separator()

            im.TreePop()
        end

        -- Profile color
        tooltip = lang.profile

        if im.TreeNode1(tooltip.titles[2]) then
            tooltip = lang.profile.color

            local r, g, b
            local profileColor = profiles:getProfileColor()

            -- color
            im.Text(tooltip.titles[1])

            im.Spacing()
            im.Separator()
            im.Spacing()

            r = im.FloatPtr(profileColor[1])

            im.PushItemWidth(128)

            if im.SliderFloat("R##300", r, 0, 255, "%.0f") then
                profileColor[1] = r[0]
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text(lang.profile.hover, lang.strings.saveProfile)
                im.EndTooltip()
            end

            g = im.FloatPtr(profileColor[2])

            im.PushItemWidth(128)

            if im.SliderFloat("G##301", g, 0, 255, "%.0f") then
                profileColor[2] = g[0]
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text(lang.profile.hover, lang.strings.saveProfile)
                im.EndTooltip()
            end

            b = im.FloatPtr(profileColor[3])

            im.PushItemWidth(128)

            if im.SliderFloat("B##302", b, 0, 255, "%.0f") then
                profileColor[3] = b[0]
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text(lang.profile.hover, lang.strings.saveProfile)
                im.EndTooltip()
            end

            profiles:setProfileColor(profileColor)

            im.Spacing()
            im.Separator()

            im.TreePop()
        end

        -- Profile brightness
        tooltip = lang.profile

        if im.TreeNode1(tooltip.titles[3]) then
            tooltip = lang.profile.brightness

            local a = nil
            local lightbarBrightness = (profiles:getProfileBrightness() / 255) * 100

            -- brightness
            im.Text(tooltip.titles[1])

            im.Spacing()
            --im.Separator()
            im.Spacing()

            a = im.FloatPtr(lightbarBrightness)

            im.PushItemWidth(128)

            if im.SliderFloat("%##300", a, 0, 100, "%.0f") then
                local brightness = (a[0] / 100) * 255
                profiles:setProfileBrightness(brightness)
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text(lang.profile.hover, lang.strings.saveProfile)
                im.EndTooltip()
            end

            im.Spacing()
            im.Separator()

            im.TreePop()
        end

        im.TreePop()
    end

    im.EndChild()
end

local function renderTabs()
	if im.BeginTabBar("Profiles") then
        local totalProfiles = profiles:getTotalProfiles()

        if(totalProfiles == 0) then
            return
        end

        local tooltip = lang.strings

        for i = 1, totalProfiles do
            local activeProfile = profiles:getActiveProfileID()
            local profileName = profiles:getProfileName(i)
            local tabFlags = im.TabItemFlags_None

            if(ui.main.tabSet == false) then
                if(activeProfile == i) then
                    tabFlags = im.TabItemFlags_SetSelected
                    ui.main.tabSet = true
                end
            end

            if im.BeginTabItem(profileName, nil, tabFlags) then
                if(activeProfile ~= i and ui.main.tabSet) then
                    profiles:setActiveProfile(i)

                    settings = profiles:getProfileSettings()
                    ui.main.tabSet = false

                    ui:mailboxToVE("profile_change")

                    ui.main.profileRenameName = im.ArrayChar(32, profileName)

                    ui:showMessage(string.format(tooltip.profileActive, profileName), 5)
                end
                im.EndTabItem()
            end
        end

        if im.BeginTabItem("+", nil, im.TabItemFlags_None) then
            local maxProfiles = profiles:getMaxProfiles()
            local totalProfiles = profiles:getTotalProfiles()

            if(maxProfiles >= totalProfiles + 1) then
                -- Prevents from showing 'showCreateProfile' when user deletes a profile and last selected tab was '+'
                if(tick - ui.main.preventCreateProfileFromOpeningTick > 0.5) then
                    showCreateProfile(true)
                end
            else
                ui:showMessage(string.format(tooltip.profileCreateMaxError, totalProfiles, maxProfiles))
            end

            ui.main.tabSet = false
            im.EndTabItem()
        end
    end

    im.EndTabBar()
end

local function renderNotificationMessage()
    im.Separator()

    local elapsed = tick - ui.message.tick
    local fadeTime = 0.25

    if(elapsed < ui.message.duration) then
        ui.message.progress = (elapsed <= fadeTime) and (elapsed / fadeTime) or (elapsed >= ui.message.duration - fadeTime) and (1 - (elapsed - (ui.message.duration - fadeTime)) / fadeTime) or ui.message.progress
        ui.message.progress = ui.message.progress > 1 and 1 or ui.message.progress
        ui.message.progress = ui.message.progress < 0 and 0 or ui.message.progress

        im.TextColored(im.ImVec4(1, 1, 1, 1 * ui.message.progress), ui.message.str or "")
        return
    end

    im.TextColored(im.ImVec4(1, 1, 1, 0.9), string.format(lang.strings.activeProfile, profiles:getProfileName()))
end

local function renderModSettings()
    local tooltip = lang.strings

    im.Spacing()

    -- Disable mod
    local enable = im.BoolPtr(profiles:isProfilesEnabled())

    if im.Checkbox(tooltip.modEnable, enable) then
        profiles:setProfilesEnabled(enable[0])
        ui:mailboxToVE("mod_enable_disable")
    end

    if im.IsItemHovered() then
        im.BeginTooltip()
        im.Text(tooltip.modEnableHover)
        im.EndTooltip()
    end

    -- Allow on BeamMP servers
    local enable = im.BoolPtr(profiles:isBeamMpAllowed())

    if im.Checkbox(tooltip.allowBeamMp, enable) then
        profiles:setBeamMpAllowed(enable[0])
        ui:checkEnableBeamMp()
    end

    if im.IsItemHovered() then
        im.BeginTooltip()
        im.Text(tooltip.allowBeamMpHover)
        im.EndTooltip()
    end

    im.Spacing()
end

local function renderMainWindow()
    -- Prevents from showing 'showCreateProfile' when user deletes a profile and last selected tab was '+'
    if(profiles:getProfileName() == "-") then
        profiles:setActiveProfile(1)
        ui.main.preventCreateProfileFromOpeningTick = tick
    end

    im.SetNextWindowBgAlpha(0.95)  

    im.SetNextWindowSizeConstraints(im.ImVec2(ui.constraints.main.width, ui.constraints.main.height), im.ImVec2(ui.constraints.main.width, ui.constraints.main.height))
    im.Begin("BeamDSX v" ..version.. " - by Feche", ui.main.show, ui.constraints.main.flags)

    im.TextColored(im.ImVec4(1, 1, 1, 0.6), lang.strings.welcomeMessage)
    im.Separator()

    -- Profile tabs
    renderTabs()

    -- Profile settings
    renderProfileSettings()

    im.Separator()

    -- Mod settings
    renderModSettings()

    -- Draws UI text message notification
    renderNotificationMessage()

    -- Buttons
    renderButtons()
end

-- BeamNG events
local function onUpdate(dt)
    tick = tick + dt

    -- Detects if user exits menu via X close button
    if(ui.main.show[0] == false) then
        if(ui.main.closed == false) then
            ui:toggle(false)
        end
        return
    end

    -- Create profile UI
    renderCreateProfile()

    -- Main window
    renderMainWindow()
    
    im.End()
end

local function onExtensionLoaded()
    -- Load user settings
    profiles:init()
    -- Init GUI text
    text:init()

    lang = text:getText()
    settings = profiles:getProfileSettings()

    if(not settings) then
        profiles:createDefaultProfile()
        profiles:setActiveProfile(1)

        settings = profiles:getProfileSettings()
    end
    
    ui:checkEnableBeamMp()

    log("I", "onExtensionLoaded", "[beam_dsx] GE: extension loaded, active profile: '" ..profiles:getProfileName().. "'")
end

local function onExtensionUnloaded()
	log("I", "onExtensionUnloaded", "[beam_dsx] GE: extension unloaded")
end

local function onVehicleSwitched(id)
    local playerVehicleId = be:getPlayerVehicleID(0)

    if(vehicleId == playerVehicleId) then
        log("I", "onVehicleSwitched", "[beam_dsx] GE: player switched vehicle, signaling VE ..")
        ui:mailboxToVE("vehicle_switch")
    end
end

local function onVehicleResetted(vehicleId)
    local playerVehicleId = be:getPlayerVehicleID(0)

    if(vehicleId == playerVehicleId) then
        log("I", "onVehicleResetted", "[beam_dsx] GE: player vehicle resetted, signaling VE ..")
        ui:mailboxToVE("vehicle_reset")
    end
end

return
{
    dependencies = { "ui_imgui" },

    onExtensionLoaded = onExtensionLoaded,
    onExtensionUnloaded = onExtensionUnloaded,
    onVehicleResetted = onVehicleResetted,
    onUpdate = onUpdate,
    toggle = function() ui:toggle() end,
    dumpex = profiles.dumpex
}