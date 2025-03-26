-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche
-- GE beam_dsx.lua

local profiles = require("ge.extensions.utils.profiles")
local utils = require("ge.extensions.utils.utils")
local text = require("ge.extensions.utils.lang")
local ds = require("common.ds")
local ffi = require("ffi")

local version = "1.0"
local lang = {}
local im = ui_imgui
local tick = 0
local settings = nil
local allowedVersions = { ["0.34"] = true }

local beam_dsx =
{
    disabled = true,
    deactivateMod = nil,
    modEnable = true,
    main = 
    {
        show = im.BoolPtr(false),
        closed = true,
        tabSet = false,
        preventCreateProfileFromOpeningTick = 0,
        profileRenameName = "",
        profileVehicle = "",
    },
    createProfile =
    {
        show = im.BoolPtr(false),
        newProfileName = nil,
    },
    constraints =
    {
        main =
        {
            width = 510,
            height = 850,
            flags = im.WindowFlags_AlwaysAutoResize,
            offsetWidth = 206,
        },
        createProfile = 
        {
            width = 220,
            height = 116,
            flags = im.WindowFlags_AlwaysAutoResize,
        },
    },
    -- Functions
    toggle = function(self, change)
        if(change == nil) then
            self.main.show[0] = (not self.main.show[0]) 
        end

        if(self.main.show[0]) then
            settings = profiles:getProfileSettings()

            self.main.profileRenameName = im.ArrayChar(32, profiles:getProfileName())
            self.main.profileVehicle = im.ArrayChar(32, profiles:getProfileVehicle())
            self.main.closed = false
        else
            self.main.closed = true
        end
    end,
    toggleBeamMpHook = function(self)
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

            log("i", "toggleBeamMpHook", "[beam_dsx] GE: mod allowed to run on BeamMp servers")
        else
            _G["core_modmanager"].deactivateMod = self.deactivateMod

            log("W", "toggleBeamMpHook", "[beam_dsx] GE: mod disabled to run on BeamMp servers")
        end
    end,
    showMessage = function(self, str, duration)
        guihooks.message(str, duration or 3, tostring(tick))
    end,
    mailboxToVE = function(self, code, vehicle)
        if(not self.modEnable) then
            log("W", "mailboxToVE", "[beam_dsx] GE: mod is disabled")
            return
        end

        local playerVehicleId = vehicle and vehicle or be:getPlayerVehicleID(0)

        if(not playerVehicleId) then
            return
        end

        local policeMode = 0

        if(gameplay_police) then
            local policeData = gameplay_police.getPursuitData()

            policeMode = policeData and policeData.mode or 0
        end

        local data =
        {
            code = code,
            playerVehicleId = playerVehicleId,
            tick = tick,
            policeMode = policeMode,
            path = profiles:getPath()
        }

        be:sendToMailbox("beam_dsx_mailboxToVE", jsonEncode(data))
        
        log("I", "mailboxToVE", "[beam_dsx] GE: sending mailbox to VE '" ..code.. "' ..")
    end,
    onRenameProfile = function(self)
        local profileName = profiles:getProfileName()
        local newProfileName = ffi.string(self.main.profileRenameName)

        if(profileName == newProfileName) then
            return true
        end

        local isValid = self:isValidName(newProfileName)
        local tooltip = lang.strings

        if(isValid == 0) then
            self:showMessage(tooltip.profileNameEmptyError)
        elseif(isValid == 1) then
            self:showMessage(tooltip.profileNameInvalidError)
        elseif(isValid == 2) then
            self:showMessage(string.format(tooltip.profileAlreadyExistError, newProfileName))
        else
            profiles:setProfileName(newProfileName)
            return true
        end

        return false
    end,
    onCreateProfile = function(self)
        local profileName = ffi.string(self.createProfile.newProfileName)
        local isValid = self:isValidName(profileName)
        local tooltip = lang.strings

        if(isValid == 0) then
            return self:showMessage(tooltip.profileNameEmptyError)
        elseif(isValid == 1) then
            return self:showMessage(tooltip.profileNameInvalidError)
        elseif(isValid == 2) then
            return self:showMessage(string.format(tooltip.profileAlreadyExistError, profileName))
        end

        profiles:loadProfiles()
        profiles:createProfile(profileName, profiles:getDefaultSettings())

        self:showCreateProfile(false)
        self:showMessage(string.format(tooltip.profileCreateOk, profileName))
    end,
    onProfileVehicleChange = function(self)
        local profilePerVehicleStr = ffi.string(self.main.profileVehicle)
        local vehicles = {}

        -- Get vehicle list
        for veh in string.gmatch(profilePerVehicleStr, "%s*([^,]+)%s*") do
            table.insert(vehicles, veh)
        end

        for i = 1, #vehicles do
            -- Returns vehicle profile
            if(profiles:getVehicleProfile(vehicles[i], true) ~= 0) then
                self:showMessage(string.format(lang.strings.profileVehicleIsInAnotherProfile, vehicles[i]))
                return false
            end
        end

        profiles:setProfileVehicle(profilePerVehicleStr)
        return true
    end, 
    onDeleteProfile = function(self)
        local tooltip = lang.strings
        local profileName = profiles:getProfileName()

        if(profiles:getTotalProfiles() - 1 == 0) then
            return self:showMessage(string.format(tooltip.deleteProfileError, profileName), 5)
        end

        self:showMessage(string.format(tooltip.deleteProfileNotification, profileName), 5)
        profiles:deleteProfile(profiles:getActiveProfileID())
    end,
    onTabChange = function(self, profileID, auto)
        local profileName = profiles:getProfileName(profileID)
        local tooltip = lang.strings

        profiles:setActiveProfile(profileID)
        self:showMessage(not auto and string.format(tooltip.switchProfile, profileName) or string.format(tooltip.autoSwitchProfile, profileName), auto and 6)

        settings = profiles:getProfileSettings()

        self.main.tabSet = false
        self.main.profileRenameName = im.ArrayChar(32, profileName)
        self.main.profileVehicle = im.ArrayChar(32, profiles:getProfileVehicle())

        self:mailboxToVE("profile_change")
        --self:showMessage(string.format(tooltip.profileActive, profileName), 5)
    end,
    isValidName = function(self, name)
        -- Check if profile name is valid
        if(#name == 0) then
            return 0
        end

        -- Check if profile name is valid
        if(name == "-" or name == "+") then
            return 1
        end

        -- Check if profile name already exists
        local p = profiles:getProfiles()

        for i = 1, #p do
            if(p[i].name == name) then
                return 2
            end
        end
    end,
    showCreateProfile = function(self, show)
        self.createProfile.show[0] = show

        if(show) then
            self.createProfile.newProfileName = im.ArrayChar(32, "")
        end
    end,
    onSaveProfile = function(self)
        -- Checks if profile name already exists
        if(not self:onRenameProfile()) then
            return
        end

        -- Checks if the vehicle has already set another profile
        if(not self:onProfileVehicleChange()) then
            return
        end

        local tooltip = lang.strings

        profiles:saveProfiles()
        self:mailboxToVE("save")
        self:showMessage(string.format(tooltip.saveProfileOk, profiles:getProfileName()))

        local enable = profiles:isProfilesEnabled()

        if(enable == false and self.modEnable == true) then
            self:mailboxToVE("mod_disable")
            self.modEnable = false
            ds:resetController()
        elseif(enable == true and self.modEnable == false) then
            self.modEnable = true
            self:mailboxToVE("mod_enable")
        end
    end,
    onVehicleUpdate = function(self, id)
        if(id ~= be:getPlayerVehicleID(0)) then
            --log("I", "onVehicleUpdate", "[beam_dsx] GE: '" ..utils.getVehicleName(id).. "' is not the player vehicle ..")
            return
        end

        local vehName = utils.getVehicleName(id)

        if(vehName == "unicycle" or id == -1) then
            self:mailboxToVE("vehicle_invalid")
            ds:resetController()
        else
            local profile = profiles:getVehicleProfile(vehName)

            if(profile > 0) then
                self:onTabChange(profile, true)

                log("I", "onVehicleSwitched", "[beam_dsx] GE: found profile '" ..profiles:getProfileName().. "' for vehicle '" ..vehName.. "'")
            else
                self:mailboxToVE("vehicle_reset_or_switch", id)
            end
        end
    end,
    gameVersionCheck = function(self)
        local version = string.format("%0.4s", beamng_version)
        if(allowedVersions[version]) then
            return { status = true, version = version }
        end
        return { status = false, version = version }
    end,
}

-- Beam DSX events
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

            if(beam_dsx.main.tabSet == false) then
                if(activeProfile == i) then
                    tabFlags = im.TabItemFlags_SetSelected
                    beam_dsx.main.tabSet = true
                end
            end

            if im.BeginTabItem(profileName, nil, tabFlags) then
                if(activeProfile ~= i and beam_dsx.main.tabSet) then
                    beam_dsx:onTabChange(i)
                end
                im.EndTabItem()
            end
        end

        if im.BeginTabItem("+", nil, im.TabItemFlags_None) then
            local maxProfiles = profiles:getMaxProfiles()
            local totalProfiles = profiles:getTotalProfiles()

            if(maxProfiles >= totalProfiles + 1) then
                -- Prevents from showing 'showCreateProfile' when user deletes a profile and last selected tab was '+'
                if(tick - beam_dsx.main.preventCreateProfileFromOpeningTick > 0.5) then
                    beam_dsx:showCreateProfile(true)
                end
            else
                beam_dsx:showMessage(string.format(tooltip.profileCreateMaxError, totalProfiles, maxProfiles))
            end

            beam_dsx.main.tabSet = false
            im.EndTabItem()
        end
    end

    im.EndTabBar()
end

local function renderProfileSettings()
    if(not settings) then
        return
    end

    local setting = nil
    local tooltip = nil

    im.BeginChild1("TriggerSettings", im.ImVec2(beam_dsx.constraints.main.width - 20, beam_dsx.constraints.main.height - beam_dsx.constraints.main.offsetWidth, beam_dsx.constraints.main.flags))

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

                    im.Spacing()

                    if im.Checkbox(lang.general.enable, enable) then
                        setting.enable = enable[0]

                        if(settings.throttle.rigidity.constant.enable == true) then
                            settings.throttle.rigidity.constant.enable = false
                        end
                    end

                    im.Spacing()

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.bySpeed.enable)
                        im.EndTooltip()
                    end

                    if(setting.enable == true) then
                        im.Separator()
                        im.Spacing()

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

                        im.Spacing()

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

                        im.Spacing()

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

                        im.Spacing()
                        im.Spacing()

                        -- Inverted
                        local inverted = im.BoolPtr(setting.inverted)

                        if im.Checkbox(tooltip.inverted, inverted) then
                            setting.inverted = inverted[0]
                        end

                        im.Spacing()
                        im.Spacing()
                    end

                    im.TreePop()
                end

                -- Constant
                setting = settings.throttle.rigidity.constant

                if im.TreeNode1(tooltip.titles[2]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(lang.general.enable, enable) then
                        setting.enable = enable[0]

                        if(settings.throttle.rigidity.bySpeed.enable == true) then
                            settings.throttle.rigidity.bySpeed.enable = false
                        end
                    end

                    im.Spacing()

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.constant.enable)
                        im.EndTooltip()
                    end

                    if(setting.enable == true) then
                        im.Separator()
                        im.Spacing()

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

                        im.Spacing()

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

                        im.Spacing()
                        im.Spacing()
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

                im.Spacing()

                if im.Checkbox(lang.general.enable, enable) then
                    setting.enable = enable[0]
                end

                im.Spacing()

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text(tooltip.enable)
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()
                    im.Spacing()

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

                    im.Spacing()

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

                    im.Spacing()

                    -- minHz 
                    im.Text(tooltip.titles[3])

                    im.PushItemWidth(128)

                    local minHz  = im.FloatPtr(setting.minHz)

                    if im.SliderFloat("hz##8", minHz, 0, 40, "%.0f") then
                        setting.minHz = minHz[0]
                    end
                
                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.minHz)
                        im.EndTooltip()
                    end

                    im.Spacing()

                    -- maxHz 
                    im.Text(tooltip.titles[4])

                    im.PushItemWidth(128)

                    local maxHz  = im.FloatPtr(setting.maxHz)

                    if im.SliderFloat("hz##9", maxHz, 0, 40, "%.0f") then
                        setting.maxHz = maxHz[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.maxHz)
                        im.EndTooltip()
                    end

                    im.Spacing()

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

                    im.Spacing()
                    im.Spacing()
                end

                im.TreePop()
            end

            -- Upshift
            setting = settings.throttle.upShift
            tooltip = lang.throttle.upShift

            if im.TreeNode1(lang.throttle.titles[3]) then
                local enable = im.BoolPtr(setting.enable)

                im.Spacing()

                if im.Checkbox(lang.general.enable, enable) then
                    setting.enable = enable[0]
                end

                im.Spacing()

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text(tooltip.enable)
                    im.EndTooltip()
                end

                if(setting.enable) then
                    im.Separator()
                    im.Spacing()

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

                    im.Spacing()

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

                    im.Spacing()

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

                    im.Spacing()
                    im.Spacing()
                end

                im.TreePop()
            end

            -- Rev limit
            setting = settings.throttle.revLimit
            tooltip = lang.throttle.revLimit

            if im.TreeNode1(lang.throttle.titles[4]) then
                local enable = im.BoolPtr(setting.enable)

                im.Spacing()

                if im.Checkbox(lang.general.enable, enable) then
                    setting.enable = enable[0]
                end

                im.Spacing()

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text(tooltip.enable)
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()
                    im.Spacing()

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

                    im.Spacing()

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

                    im.Spacing()

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

                    im.Spacing()

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

                    im.Spacing()
                    im.Spacing()
                end

                im.TreePop()
            end

            -- Red line
            setting = settings.throttle.redLine
            tooltip = lang.throttle.redLine

            if im.TreeNode1(lang.throttle.titles[5]) then
                local enable = im.BoolPtr(setting.enable)

                im.Spacing()

                if im.Checkbox(lang.general.enable, enable) then
                    setting.enable = enable[0]
                end

                im.Spacing()

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text(tooltip.enable)
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()
                    im.Spacing()

                    -- startAt  
                    im.Text(tooltip.titles[1])

                    im.PushItemWidth(128)

                    local startAt = im.FloatPtr(setting.startAt)

                    if im.SliderFloat("%##800", startAt, 1, 100, "%.0f") then
                        setting.startAt  = startAt[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.startAt)
                        im.EndTooltip()
                    end

                    im.Spacing()

                    -- bounces  
                    im.Text(tooltip.titles[2])

                    im.PushItemWidth(128)

                    local bounces = im.FloatPtr(setting.bounces)

                    if im.SliderFloat("##801", bounces, 0, 8, "%.0f") then
                        setting.bounces  = bounces[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.bounces)
                        im.EndTooltip()
                    end

                    im.Spacing()

                    -- minHz 
                    im.Text(tooltip.titles[3])

                    im.PushItemWidth(128)

                    local minHz  = im.FloatPtr(setting.minHz)

                    if im.SliderFloat("hz##802", minHz, 1, 255, "%.0f") then
                        setting.minHz = minHz[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.minHz)
                        im.EndTooltip()
                    end

                    im.Spacing()

                    -- maxHz 
                    im.Text(tooltip.titles[4])

                    im.PushItemWidth(128)

                    local maxHz  = im.FloatPtr(setting.maxHz)

                    if im.SliderFloat("hz##803", maxHz, 1, 255, "%.0f") then
                        setting.maxHz = maxHz[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.maxHz)
                        im.EndTooltip()
                    end

                    im.Spacing()

                    -- vibrationForce  
                    im.Text(tooltip.titles[5])

                    im.PushItemWidth(128)

                    local vibrationForce = im.FloatPtr(setting.vibrationForce)

                    if im.SliderFloat("##805", vibrationForce, 1, 3, "%.0f") then
                        setting.vibrationForce  = vibrationForce[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(lang.general.vibrationForce)
                        im.EndTooltip()
                    end

                    im.Spacing()
                    im.Spacing()
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

            -- Engine on
            setting = settings.throttle.engineOn
            tooltip = lang.throttle

            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox(tooltip.engineOn, enable) then
                setting.enable = enable[0]
            end

            im.Spacing()
            im.Spacing()
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

                    im.Spacing()

                    if im.Checkbox(lang.general.enable, enable) then
                        setting.enable = enable[0]

                        if(settings.brake.rigidity.constant.enable == true) then
                            settings.brake.rigidity.constant.enable = false
                        end
                    end

                    im.Spacing()

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.bySpeed.enable)
                        im.EndTooltip()
                    end

                    if(setting.enable == true) then
                        im.Separator()
                        im.Spacing()

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

                        im.Spacing()

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

                        im.Spacing()

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

                        im.Spacing()
                        im.Spacing()

                        -- Inverted
                        local inverted = im.BoolPtr(setting.inverted)

                        if im.Checkbox(tooltip.inverted, inverted) then
                            setting.inverted = inverted[0]
                        end

                        im.Spacing()
                        im.Spacing()
                    end

                    im.TreePop()
                end

                -- Constant
                setting = settings.brake.rigidity.constant

                if im.TreeNode1(tooltip.titles[2]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(lang.general.enable, enable) then
                        setting.enable = enable[0]

                        if(settings.brake.rigidity.bySpeed.enable == true) then
                            settings.brake.rigidity.bySpeed.enable = false
                        end
                    end

                    im.Spacing()

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.constant.enable)
                        im.EndTooltip()
                    end

                    if(setting.enable == true) then
                        im.Separator()
                        im.Spacing()

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

                        im.Spacing()

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

                        im.Spacing()
                        im.Spacing()
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

                im.Spacing()

                if im.Checkbox(lang.general.enable, enable) then
                    setting.enable = enable[0]
                end

                im.Spacing()

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text(tooltip.enable)
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()
                    im.Spacing()

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

                    im.Spacing()

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

                    im.Spacing()

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

                    im.Spacing()

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

                    im.Spacing()
                end

                im.TreePop()
            end

            im.Spacing()
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
            im.Spacing()
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

            if im.TreeNode1("Lightbar") then
                -- Emergency braking
                setting = settings.lightBar.emergencyBraking
                tooltip = lang.lightBar.emergencyBraking

                if im.TreeNode1(lang.lightBar.titles[4]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(lang.general.enable, enable) then
                        setting.enable = enable[0]
                    end

                    im.Spacing()

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.enable)
                        im.EndTooltip()
                    end

                    if(setting.enable) then
                        im.Separator()
                        im.Spacing()

                        local r, g, b

                        -- colorOn R
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

                        im.Spacing()

                        -- colorOn G
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

                        im.Spacing()

                        -- colorOn B
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

                        im.Spacing()

                        -- colorOff R
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

                        im.Spacing()

                        -- colorOff G
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

                        im.Spacing()

                        -- colorOff B
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
                        
                        im.Spacing()
                        im.Separator()
                        im.Spacing()

                        -- alwaysBlink - checkbox
                        local enable = im.BoolPtr(setting.alwaysBlink)

                        if im.Checkbox(tooltip.alwaysBlink, enable) then
                            setting.alwaysBlink = enable[0]
                        end

                        im.Spacing()
                        im.Spacing()
                    end

                    im.TreePop()
                end

                -- Hazard lights
                setting = settings.lightBar.hazardLights
                tooltip = lang.lightBar.hazardLights

                if im.TreeNode1(lang.lightBar.titles[1]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(lang.general.enable, enable) then
                        setting.enable = enable[0]
                    end

                    im.Spacing()

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.enable)
                        im.EndTooltip()
                    end

                    if(setting.enable == true) then
                        im.Separator()
                        im.Spacing()

                        local r, g, b

                        -- colorOn R
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

                        im.Spacing()

                        -- colorOn G
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

                        im.Spacing()

                        -- colorOn B
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

                        im.Spacing()

                        -- colorOff R
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

                        im.Spacing()

                        -- colorOff G
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

                        im.Spacing()

                        -- colorOff B
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

                        im.Spacing()
                        im.Spacing()
                    end

                    im.TreePop()
                end

                -- Reverse
                setting = settings.lightBar.reverse
                tooltip = lang.lightBar.reverse

                if im.TreeNode1(lang.lightBar.titles[7]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(lang.general.enable, enable) then
                        setting.enable = enable[0]
                    end

                    im.Spacing()

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.enable)
                        im.EndTooltip()
                    end

                    if(setting.enable == true) then
                        im.Separator()
                        im.Spacing()

                        local r, g, b

                        -- colorOn R
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

                        im.Spacing()

                        -- colorOn G
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

                        im.Spacing()

                        -- colorOn B
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

                        im.Spacing()
                        im.Spacing()
                    end

                    im.TreePop()
                end

                -- Tachometer
                setting = settings.lightBar.tachometer
                tooltip = lang.lightBar.tachometer

                if im.TreeNode1(lang.lightBar.titles[5]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(lang.general.enable, enable) then
                        setting.enable = enable[0]
                    end

                    im.Spacing()

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.enable)
                        im.EndTooltip()
                    end

                    if(setting.enable == true) then
                        im.Separator()
                        im.Spacing()

                        local r, g, b

                        -- colorLow R
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

                        im.Spacing()

                        -- colorLow G
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

                        im.Spacing()

                        -- colorLow B
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

                        im.Spacing()

                        -- colorMed R
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

                        im.Spacing()

                        -- colorMed G
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

                        im.Spacing()

                        -- colorMed B
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

                        im.Spacing()

                        -- colorHi R
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

                        im.Spacing()

                        -- colorHi G
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

                        im.Spacing()

                        -- colorHi B
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

                        im.Spacing()
                    end

                    im.TreePop()
                end

                -- Vehicle damage
                setting = settings.lightBar.vehicleDamage
                tooltip = lang.lightBar.vehicleDamage

                if im.TreeNode1(lang.lightBar.titles[8]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(lang.general.enable, enable) then
                        setting.enable = enable[0]
                    end

                    im.Spacing()

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.enable)
                        im.EndTooltip()
                    end

                    if(setting.enable == true) then
                        im.Separator()
                        im.Spacing()

                        local r, g, b

                        -- timeOn
                        im.Text(tooltip.titles[1])

                        local timeOn = im.FloatPtr(setting.timeOn)

                        im.PushItemWidth(128)

                        if im.SliderFloat("ms##900", timeOn, 500, 10000, "%.0f") then
                            setting.timeOn = timeOn[0]
                        end
                
                        if im.IsItemHovered() then
                            im.BeginTooltip()
                            im.Text(tooltip.timeOn)
                            im.EndTooltip()
                        end

                        im.Spacing()

                        -- blinkSpeed
                        im.Text(tooltip.titles[2])

                        local blinkSpeed = im.FloatPtr(setting.blinkSpeed)

                        im.PushItemWidth(128)

                        if im.SliderFloat("##901", blinkSpeed, 2, 10, "%.0f") then
                            setting.blinkSpeed = blinkSpeed[0]
                        end
                
                        if im.IsItemHovered() then
                            im.BeginTooltip()
                            im.Text(tooltip.blinkSpeed)
                            im.EndTooltip()
                        end

                        im.Spacing()

                        -- colorOn
                        im.Text(tooltip.titles[3])

                        -- colorOn R
                        r = im.FloatPtr(setting.colorOn[1])

                        im.PushItemWidth(128)

                        if im.SliderFloat("R##902", r, 0, 255, "%.0f") then
                            setting.colorOn[1] = r[0]
                        end

                        if im.IsItemHovered() then
                            im.BeginTooltip()
                            im.Text(tooltip.colorOn)
                            im.EndTooltip()
                        end

                        im.Spacing()

                        -- colorOn G
                        g = im.FloatPtr(setting.colorOn[2])

                        im.PushItemWidth(128)

                        if im.SliderFloat("G##903", g, 0, 255, "%.0f") then
                            setting.colorOn[2] = g[0]
                        end

                        if im.IsItemHovered() then
                            im.BeginTooltip()
                            im.Text(tooltip.colorOn)
                            im.EndTooltip()
                        end

                        im.Spacing()

                        -- colorOn B
                        b = im.FloatPtr(setting.colorOn[3])

                        im.PushItemWidth(128)

                        if im.SliderFloat("B##904", b, 0, 255, "%.0f") then
                            setting.colorOn[3] = b[0]
                        end

                        if im.IsItemHovered() then
                            im.BeginTooltip()
                            im.Text(tooltip.colorOn)
                            im.EndTooltip()
                        end

                        im.Spacing()

                        -- colorOff
                        im.Text(tooltip.titles[4])

                        -- colorOff R
                        r = im.FloatPtr(setting.colorOff[1])

                        im.PushItemWidth(128)

                        if im.SliderFloat("R##905", r, 0, 255, "%.0f") then
                            setting.colorOff[1] = r[0]
                        end

                        if im.IsItemHovered() then
                            im.BeginTooltip()
                            im.Text(tooltip.colorOff)
                            im.EndTooltip()
                        end

                        im.Spacing()

                        -- colorOff G
                        g = im.FloatPtr(setting.colorOff[2])

                        im.PushItemWidth(128)

                        if im.SliderFloat("G##906", g, 0, 255, "%.0f") then
                            setting.colorOff[2] = g[0]
                        end

                        if im.IsItemHovered() then
                            im.BeginTooltip()
                            im.Text(tooltip.colorOff)
                            im.EndTooltip()
                        end

                        im.Spacing()

                        -- colorOff B
                        b = im.FloatPtr(setting.colorOff[3])

                        im.PushItemWidth(128)

                        if im.SliderFloat("B##907", b, 0, 255, "%.0f") then
                            setting.colorOff[3] = b[0]
                        end
                
                        if im.IsItemHovered() then
                            im.BeginTooltip()
                            im.Text(tooltip.colorOff)
                            im.EndTooltip()
                        end

                        im.Spacing()
                    end

                    im.TreePop()
                end

                -- Drive mode switch
                setting = settings.lightBar.driveMode
                tooltip = lang.lightBar.driveMode

                if im.TreeNode1(lang.lightBar.titles[9]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(lang.general.enable, enable) then
                        setting.enable = enable[0]
                    end

                    im.Spacing()

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.enable)
                        im.EndTooltip()
                    end

                    if(setting.enable == true) then
                        im.Separator()
                        im.Spacing()

                        local r, g, b

                        -- blinkTime
                        im.Text(tooltip.titles[1])

                        local blinkTime = im.FloatPtr(setting.blinkTime)

                        im.PushItemWidth(128)

                        if im.SliderFloat("ms##600", blinkTime, 500, 10000, "%.0f") then
                            setting.blinkTime = blinkTime[0]
                        end
                
                        if im.IsItemHovered() then
                            im.BeginTooltip()
                            im.Text(tooltip.blinkTime)
                            im.EndTooltip()
                        end

                        im.Spacing()
                    end

                    im.TreePop()
                end

                im.Spacing()
                im.Separator()
                im.Spacing()

                -- Police chase
                setting = settings.lightBar.policeChase
                tooltip = lang.lightBar.policeChase

                local enable = im.BoolPtr(setting.enable)

                if im.Checkbox(tooltip.enable, enable) then
                    setting.enable = enable[0]
                end

                im.Spacing()
                im.Spacing()

                im.TreePop()
            end

            if im.TreeNode1("Microphone LED") then
                -- Low fuel
                setting = settings.lightBar.lowFuel
                tooltip = lang.lightBar.lowFuel

                if im.TreeNode1(lang.lightBar.titles[2]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(lang.general.enable, enable) then
                        setting.enable = enable[0]
                    end

                    im.Spacing()

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.enable)
                        im.EndTooltip()
                    end

                    if(setting.enable == true) then
                        im.Separator()
                        im.Spacing()

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

                        im.Spacing()

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

                        im.Spacing()
                        im.Spacing()
                    end

                    im.TreePop()
                end

                -- Parking brake
                setting = settings.lightBar.parkingBrake
                tooltip = lang.lightBar.parkingBrake

                if im.TreeNode1(lang.lightBar.titles[3]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(lang.general.enable, enable) then
                        setting.enable = enable[0]
                    end

                    im.Spacing()

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.enable) 
                        im.EndTooltip()
                    end

                    if(setting.enable == true) then
                        im.Separator()
                        im.Spacing()

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

                        im.Spacing()

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

                        im.Spacing()
                    end

                    im.TreePop()
                end

                im.Spacing()
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
                im.Spacing()

                im.TreePop()
            end

            if im.TreeNode1("Player LED") then
                im.Spacing()
                im.Spacing()

                -- Electronic Stability Control (ESC)
                setting = settings.lightBar.esc
                tooltip = lang.lightBar.esc

                local enable = im.BoolPtr(setting.enable)

                if im.Checkbox(tooltip.enable, enable) then
                    setting.enable = enable[0]
                end
                
                im.Spacing()

                -- Police stars
                setting = settings.lightBar.policeStars
                tooltip = lang.lightBar.policeStars

                local enable = im.BoolPtr(setting.enable)

                if im.Checkbox(tooltip.enable, enable) then
                    setting.enable = enable[0]
                end 

                im.Spacing()

                im.TreePop()
            end
        end

        im.TreePop()
    end

    im.Spacing()
    im.Separator()
    im.Spacing()

    -- Profile settings
    if im.TreeNode1(string.format(lang.titles[4], profiles:getProfileName())) then
        tooltip = lang.profile

        -- Profile name
        if im.TreeNode1(tooltip.titles[1]) then
            tooltip = lang.profile.rename

            im.Text(tooltip.titles[1])

            --im.Separator()
            --im.Separator()
            im.Spacing()

            im.PushItemWidth(185)

            if im.InputText("##profileRenameName", beam_dsx.main.profileRenameName, 32, im.InputTextFlags_EnterReturnsTrue) then
                
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

            --im.Spacing()
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

        -- Profile based on vehicle
        tooltip = lang.profile

        if im.TreeNode1(tooltip.titles[4]) then
            tooltip = lang.profile.perVehicle

            local enable = im.BoolPtr(not (ffi.string(beam_dsx.main.profileVehicle) == ""))

            im.Spacing()

            if im.Checkbox(lang.general.enable, enable) then
               if(enable[0]) then
                    beam_dsx.main.profileVehicle = im.ArrayChar(32, utils.getVehicleName())
               else
                    beam_dsx.main.profileVehicle = im.ArrayChar(32, "")
               end
            end

            im.Spacing()

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text(tooltip.enableHover)
                im.EndTooltip()
            end

            if(enable[0]) then
                im.PushTextWrapPos(0.0)
                im.Text(tooltip.titles[1])
                im.PopTextWrapPos()

                im.Spacing()
                --im.Separator()
                im.Spacing()

                im.PushItemWidth(185)

                if im.InputText("##profileVehicle", beam_dsx.main.profileVehicle, 32, im.InputTextFlags_EnterReturnsTrue) then
                
                end

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text(lang.profile.hover, lang.strings.saveProfile)
                    im.EndTooltip()
                end

                im.Spacing()
                im.Separator()
            end

            im.TreePop()
        end

        im.TreePop()
    end

    im.EndChild()
end

local function renderModSettings()
    local tooltip = lang.strings

    im.Spacing()

    -- Disable mod
    local enable = im.BoolPtr(profiles:isProfilesEnabled())

    if im.Checkbox(tooltip.modEnable, enable) then
        profiles:setProfilesEnabled(enable[0])
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
        beam_dsx:toggleBeamMpHook()
    end

    if im.IsItemHovered() then
        im.BeginTooltip()
        im.Text(tooltip.allowBeamMpHover)
        im.EndTooltip()
    end

    im.Spacing()
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
        beam_dsx:onSaveProfile()
    end

    if im.IsItemHovered() then
        im.BeginTooltip()
        im.Text(tooltip.saveProfileHovered)
        im.EndTooltip()
    end

    im.SameLine()

    -- Delete profile
    if im.Button(tooltip.deleteProfile) then
        beam_dsx:onDeleteProfile()
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

        beam_dsx:showMessage(string.format(tooltip.restoreProfileOk, profileName, tooltip.saveProfile), 10)
    end

    if im.IsItemHovered() then
        im.BeginTooltip()
        im.Text(string.format(tooltip.restoreProfileHover, profileName))
        im.EndTooltip()
    end

    im.SameLine()

    -- Active profile text
    im.Text(lang.strings.activeProfile, profiles:getProfileName())

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

local function renderMainWindow()
    -- Prevents from showing 'showCreateProfile' when user deletes a profile and last selected tab was '+'
    if(profiles:getProfileName() == "-") then
        profiles:setActiveProfile(1)
        beam_dsx.main.preventCreateProfileFromOpeningTick = tick
    end

    im.SetNextWindowBgAlpha(0.95)  

    im.SetNextWindowSizeConstraints(im.ImVec2(beam_dsx.constraints.main.width, beam_dsx.constraints.main.height), im.ImVec2(beam_dsx.constraints.main.width, beam_dsx.constraints.main.height))
    im.Begin("BeamDSX v" ..version.. " - by Feche", beam_dsx.main.show, beam_dsx.constraints.main.flags)

    im.TextColored(im.ImVec4(1, 1, 1, 0.6), lang.strings.welcomeMessage)
    im.Separator()

    -- Profile tabs
    renderTabs()

    -- Profile settings
    renderProfileSettings()

    im.Separator()

    -- Mod settings
    renderModSettings()

    -- Buttons
    renderButtons()
end

local function renderCreateProfileWindow()
    if(not beam_dsx.createProfile.show[0]) then
        return
    end

    local tooltip = lang.strings

    im.SetNextWindowSizeConstraints(im.ImVec2(beam_dsx.constraints.createProfile.width, beam_dsx.constraints.createProfile.height), im.ImVec2(beam_dsx.constraints.createProfile.width, beam_dsx.constraints.createProfile.height))
    im.Begin(tooltip.profileCreateTitle, beam_dsx.createProfile.show, beam_dsx.constraints.createProfile.flags)

    im.PushTextWrapPos(0.0)
    im.TextColored(im.ImVec4(1, 1, 1, 0.6), tooltip.profileCreateName)
    im.PopTextWrapPos()
    
    im.PushItemWidth(185)

    -- Player hits enter
    if im.InputText("##profileCreateNew", beam_dsx.createProfile.newProfileName, 32, im.InputTextFlags_EnterReturnsTrue) then
        beam_dsx:onCreateProfile()
    end

    im.Spacing()

    -- Player clicks 'create' button
    if im.Button(tooltip.profileCreateButton1) then
        beam_dsx:onCreateProfile()
    end

    im.SameLine()

    -- Player clicks 'cancel' button
    if im.Button(tooltip.profileCreateButton2) then
        beam_dsx:showCreateProfile(false)
    end
end

-- BeamNG events
local function onUpdate(dt)
    if(beam_dsx.disabled) then
        return
    end

    tick = tick + dt

    -- Detects if user exits menu via X close button
    if(beam_dsx.main.show[0] == false) then
        if(beam_dsx.main.closed == false) then
            beam_dsx:toggle(false)
        end
        return
    end

    -- Create profile UI
    renderCreateProfileWindow()

    -- Main window
    renderMainWindow()
    
    im.End()
end

local function onExtensionLoaded() 
    local v = beam_dsx:gameVersionCheck()

    if(v.status == false) then
        guihooks.trigger("toastrMsg", { type = "error", title = "Beam DSX", msg = "Beam DSX v" ..version.. " is incompatible with game version '" ..v.version.. "', check console for more info." })
        return log("E", "onExtensionLoaded", "[beam_dsx] GE: mod is incompatible with version '" ..v.version.. "', please check if a compatible game version exists, mod disabled.")
    end

    log("I", "onExtensionLoaded", "[beam_dsx] GE: mod is compatible with version '" ..v.version.. "'")

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
    
    beam_dsx.modEnable = profiles:isProfilesEnabled()
    beam_dsx:toggleBeamMpHook()
    beam_dsx.disabled = false

    log("I", "onExtensionLoaded", "[beam_dsx] GE: extension loaded, active profile: '" ..profiles:getProfileName().. "'")
end

local function onExtensionUnloaded()
	log("I", "onExtensionUnloaded", "[beam_dsx] GE: extension unloaded")
end

local function onClientEndMission()
    log("I", "onClientEndMission", "[beam_dsx] GE: player quit, disabling controller ..")

    ds:resetController()
end

local function onVehicleSwitched(oldId, newId, player)
    beam_dsx:onVehicleUpdate(newId)
end

local function onVehicleResetted(vehicleId)
    beam_dsx:onVehicleUpdate(vehicleId)
end

local function onPursuitModeUpdate(targetId, mode)
    local playerVehicleId = be:getPlayerVehicleID(0)

    if(playerVehicleId ~= targetId) then
        return
    end

    beam_dsx:mailboxToVE("police_chase_update")    
end

return
{
    dependencies = { "ui_imgui" },

    onExtensionLoaded = onExtensionLoaded,
    onExtensionUnloaded = onExtensionUnloaded,
    onClientEndMission = onClientEndMission,
    onVehicleResetted = onVehicleResetted,
    onVehicleSwitched = onVehicleSwitched,
    onUpdate = onUpdate,
    toggle = function() beam_dsx:toggle() end,
    onPursuitModeUpdate = onPursuitModeUpdate,
}