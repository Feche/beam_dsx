-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche
-- GE beam_dsx.lua

local common = require("common.common")
local tick = require("common.tick")
local ds = require("common.ds")

local profiles = require("ge.extensions.utils.profiles")
local utils = require("ge.extensions.utils.utils")
local text = require("ge.extensions.utils.languagues")

local ffi = require("ffi")

local log = common.log
local im = ui_imgui

local version = "1.1"
local settings = nil

local languagues = {}
local modStates =
{
    enabled = 0,
    disabled = 1,
    version_fail_send_toast_msg = 2,
    version_fail = 3,
}

local allowedVersions = 
{ 
    ["0.34"] = true,
    ["0.35"] = true,
	["0.36"] = true,
	["0.37"] = true,
}

local beam_dsx =
{
    deactivateMod = nil,
    status = modStates.enabled,
    main = 
    {
        show = im.BoolPtr(false),
        tabSet = false,
        uiTabsTick = 0,
        profileRenameName = "",
        profileVehicle = "",
    },
    createProfile =
    {
        show = im.BoolPtr(false),
        newProfileName = nil,
    },
    settings =
    {
        show = im.BoolPtr(false),
        statusTick = -1,
        status = nil,
        udpIP = "",
        udpPort = "",
        controllerIndex = "",
    },
    constraints =
    {
        main =
        {
            width = 510,
            height = 900,
            flags = im.WindowFlags_AlwaysAutoResize,
            offsetWidth = 146,
        },
        createProfile = 
        {
            width = 220,
            height = 122,
            flags = im.WindowFlags_AlwaysAutoResize,
        },
        settings =
        {
            width = 300,
            height = 150,
            flags = im.WindowFlags_AlwaysAutoResize,
        },
    },
    tabs = {},
    -- Functions
    toggleMainWindow = function(self)
        self.main.show[0] = not self.main.show[0]

        if(self.main.show[0]) then
            profiles:loadProfiles()
            settings = profiles:getProfileSettings()

            self.main.profileRenameName = im.ArrayChar(32, profiles:getProfileName())
            self.main.profileVehicle = im.ArrayChar(32, profiles:getProfileVehicle())
        else
            self:hideAllWindows()
        end
    end,
    toggleSettingsWindow = function(self)
        self.settings.show[0] = not self.settings.show[0]

        if(self.settings.show[0]) then
            self.main.statusTick = -1

            self.settings.udpIP = im.ArrayChar(32, profiles:getUDPIp())
            self.settings.udpPort = im.ArrayChar(8, tostring(profiles:getUDPPort()))
            self.settings.controllerIndex = im.ArrayChar(8, tostring(profiles:getControllerIndex()))
        end
    end,
    toggleCreateProfileWindow = function(self, force)
        self.createProfile.show[0] = not self.createProfile.show[0]

        if(force ~= nil) then
            self.createProfile.show[0] = force
        end

        if(self.createProfile.show[0]) then
            self.createProfile.newProfileName = im.ArrayChar(32, "")
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
                    return log("W", "deactivateMod", "BeamMp tried to disable mod, avoiding ..")
                end

                return self.deactivateMod(name)
            end

            log("i", "toggleBeamMpHook", "mod allowed to run on BeamMp servers")
        else
            _G["core_modmanager"].deactivateMod = self.deactivateMod

            log("W", "toggleBeamMpHook", "mod disabled to run on BeamMp servers")
        end
    end,
    showMessage = function(self, str, duration)
        guihooks.message(str, duration or 3, tostring(tick:getTick()))
    end,
    mailboxToVE = function(self, code, vehicle)
        if(self.status == modStates.disabled) then
            return log("W", "mailboxToVE", "mod is disabled")
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
            tick = tick:getTick(),
            policeMode = policeMode,
            path = profiles:getPath(),
        }

        be:sendToMailbox("beam_dsx_mailboxToVE", jsonEncode(data))
        
        log("I", "mailboxToVE", "sending mailbox to VE '%s' ..", code)
    end,
    gameVersionCheck = function(self)
        local version = string.format("%0.4s", beamng_version)
        if(allowedVersions[version]) then
            return { status = true, version = version }
        end
        return { status = false, version = version }
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
    getModState = function(self)
        return self.state
    end,
    hideAllWindows = function(self)
        self.main.show[0] = false
        self.settings.show[0] = false
        self.createProfile.show[0] = false
    end,
    ---
    --set
    ---
    setFontSize = function(self, newSize)
        newSize = math.min(1.5, math.max(0.8, newSize))
        profiles:setFontSize(newSize)
        self:onFontSizeChange(newSize)
    end,
    setModState = function(self, state)
        self.state = state
    end,
    ---
    -- on
    ---
    onRenameProfile = function(self)
        local profileName = profiles:getProfileName()
        local newProfileName = ffi.string(self.main.profileRenameName)

        if(profileName == newProfileName) then
            return true
        end

        local isValid = self:isValidName(newProfileName)
        local tooltip = languagues.strings

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
        local tooltip = languagues.strings

        if(isValid == 0) then
            return self:showMessage(tooltip.profileNameEmptyError)
        elseif(isValid == 1) then
            return self:showMessage(tooltip.profileNameInvalidError)
        elseif(isValid == 2) then
            return self:showMessage(string.format(tooltip.profileAlreadyExistError, profileName))
        end

        profiles:loadProfiles() -- restore settings if player has modified values but not saved them since createProfile saves config file
        profiles:createProfile(profileName, profiles:getDefaultSettings())

        self:toggleCreateProfileWindow()
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
                self:showMessage(string.format(languagues.strings.profileVehicleIsInAnotherProfile, vehicles[i]))
                return false
            end
        end

        profiles:setProfileVehicle(profilePerVehicleStr)
        return true
    end, 
    onDeleteProfile = function(self)
        local tooltip = languagues.strings
        local profileName = profiles:getProfileName()

        if(profiles:getTotalProfiles() == 1) then
            return self:showMessage(string.format(tooltip.deleteProfileError, profileName), 5)
        end

        local profileID = profiles:getActiveProfileID()

        profiles:setActiveProfile(profileID - 1)
        profiles:deleteProfile(profileID)
        self:showMessage(string.format(tooltip.deleteProfileNotification, profileName), 5)

        self.main.uiTabsTick = tick:getTick()
    end,
    onTabChange = function(self, profileID, automatic)
        local profileName = profiles:getProfileName(profileID)
        local tooltip = languagues.strings

        profiles:loadProfiles()
        profiles:setActiveProfile(profileID)
        self:showMessage(not automatic and string.format(tooltip.switchProfile, profileName) or string.format(tooltip.autoSwitchProfile, profileName), 6)

        settings = profiles:getProfileSettings()

        self.main.profileRenameName = im.ArrayChar(32, profileName)
        self.main.profileVehicle = im.ArrayChar(32, profiles:getProfileVehicle())

        self:mailboxToVE("profile_change")
        --self:showMessage(string.format(tooltip.profileActive, profileName), 5)
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

        local tooltip = languagues.strings

        profiles:saveProfiles()
        self:mailboxToVE("save")
        self:showMessage(string.format(tooltip.saveProfileOk, profiles:getProfileName()))
    end,
    onVehicleUpdate = function(self, id)
        local playerVehicle = be:getPlayerVehicleID(0)
        id = id and id or playerVehicle
        if(id ~= playerVehicle) then
            --log("I", "onVehicleUpdate", "'" ..utils.getVehicleName(id).. "' is not the player vehicle ..")
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

                log("I", "onVehicleSwitched", "found profile '%s' for vehicle '%s'", profiles:getProfileName(), vehName)
            else
                self:mailboxToVE("vehicle_reset_or_switch", id)
            end
        end
    end,
    onFontSizeChange = function(self, newSize)
        local main = self.constraints.main
        local profile = self.constraints.createProfile
        local settings = self.constraints.settings

        main.width = (newSize / 1) * 510
        main.height = (newSize / 1) * 900
        main.offsetWidth = (newSize / 1) * 146

        profile.width = (newSize / 1) * 220
        profile.height = (newSize / 1) * 122

        settings.width = (newSize / 1) * 320
        settings.height = (newSize / 1) * 350
    end,
    onUdpSave = function(self, ip, port)
        if(not utils.isIPv4(ip)) then
            return self:showMessage(languagues.strings.settingsNetworkInvalidIp)
        end

        port = tonumber(port) 

        if(not port or port <= 0 or port > 65535) then 
            return self:showMessage(languagues.strings.settingsNetworkInvalidPort)
        end

        self.settings.udpIP = im.ArrayChar(32, ip)
        self.settings.udpPort = im.ArrayChar(8, tostring(port))

        profiles:setUDPAddress(ip, port)

        self:showMessage(languagues.strings.settingsNetworkSave)
        self:mailboxToVE("udp_address_change")
    end,
    onControllerIndexChange = function(self, controllerIndex)
        if(not controllerIndex or ds:getDsxDeviceType(controllerIndex + 1) == -1 or not controllerIndex or controllerIndex < 0 or controllerIndex > 8) then
            return self:showMessage(languagues.strings.settingsControllerIndexInvalid)
        end

        ds:resetController()
        profiles:setControllerIndex(controllerIndex)
        self:showMessage(languagues.strings.settingsControllerIndexSave)
        self:mailboxToVE("controller_index_change")
    end,    
}

--
-- Beam DSX events
--
local function renderProfileTabs()
	if im.BeginTabBar("Profiles") then
        local totalProfiles = profiles:getTotalProfiles()
        local tooltip = languagues.strings
        local tick = tick:getTick()
        
        for i = 1, totalProfiles do
            local profileName = profiles:getProfileName(i)
            local tabFlags = im.TabItemFlags_None
            local activeProfile = profiles:getActiveProfileID()

            if(activeProfile == i and beam_dsx.main.tabSet == false) then
                tabFlags = im.TabItemFlags_SetSelected
                beam_dsx.main.tabSet = true
            end

            local debug = false

            if im.BeginTabItem(profileName.. (debug and (" (id: " ..i.. ")") or ""), nil, tabFlags) then
                if(activeProfile ~= i and beam_dsx.main.tabSet) then
                    beam_dsx.main.tabSet = false

                    if(tick - beam_dsx.main.uiTabsTick > 100) then
                        beam_dsx:onTabChange(i)
                    end
                end
                im.EndTabItem()
            end
        end

        if im.BeginTabItem("+", nil, im.TabItemFlags_None) then
            beam_dsx.main.tabSet = false

            if(tick - beam_dsx.main.uiTabsTick > 100) then
                local maxProfiles = profiles:getMaxProfiles()
                local totalProfiles = profiles:getTotalProfiles()

                if(maxProfiles >= totalProfiles + 1) then
                    beam_dsx:toggleCreateProfileWindow(true)
                else
                    beam_dsx:showMessage(string.format(tooltip.profileCreateMaxError, totalProfiles, maxProfiles))
                end
            end

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
    if im.TreeNode1(languagues.titles[1]) then
        im.Spacing()

        -- Disable all haptics
        setting = settings.throttle
        tooltip = languagues.throttle

        local enable = im.BoolPtr(setting.enable)

        if im.Checkbox(languagues.general.enable, enable) then
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
            tooltip = languagues.general.rigidity

            if im.TreeNode1(languagues.throttle.titles[1]) then
                -- By speed
                setting = settings.throttle.rigidity.bySpeed

                if im.TreeNode1(tooltip.titles[1]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(languagues.general.enable, enable) then
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

                    if im.Checkbox(languagues.general.enable, enable) then
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
                            im.Text(languagues.general.rigidity.constant.minForce)
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
                            im.Text(languagues.general.rigidity.constant.maxForce)
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
            tooltip = languagues.throttle.wheelSlip

            if im.TreeNode1(languagues.throttle.titles[2]) then
                local enable = im.BoolPtr(setting.enable)

                im.Spacing()

                if im.Checkbox(languagues.general.enable, enable) then
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
                        im.Text(languagues.general.minHz)
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
                        im.Text(languagues.general.maxHz)
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
                        im.Text(languagues.general.minAmplitude)
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
                        im.Text(languagues.general.maxAmplitude)
                        im.EndTooltip()
                    end

                    im.Spacing()
                    im.Spacing()
                end

                im.TreePop()
            end

            -- Upshift
            setting = settings.throttle.upShift
            tooltip = languagues.throttle.upShift

            if im.TreeNode1(languagues.throttle.titles[3]) then
                local enable = im.BoolPtr(setting.enable)

                im.Spacing()

                if im.Checkbox(languagues.general.enable, enable) then
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
                        im.Text(languagues.general.maxHz)
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
                        im.Text(languagues.general.maxForce)
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
            tooltip = languagues.throttle.revLimit

            if im.TreeNode1(languagues.throttle.titles[4]) then
                local enable = im.BoolPtr(setting.enable)

                im.Spacing()

                if im.Checkbox(languagues.general.enable, enable) then
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
                        im.Text(languagues.general.minHz)
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
                        im.Text(languagues.general.maxHz)
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
                        im.Text(languagues.general.maxForce)
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
            tooltip = languagues.throttle.redLine

            if im.TreeNode1(languagues.throttle.titles[5]) then
                local enable = im.BoolPtr(setting.enable)

                im.Spacing()

                if im.Checkbox(languagues.general.enable, enable) then
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
                        setting.startAt = startAt[0]
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text(tooltip.startAt)
                        im.EndTooltip()
                    end

                    --print("startAt: " ..setting.startAt.. ", config startAt: " ..profiles:getProfileSettings().throttle.redLine.startAt)

                    im.Spacing()

                    -- bounces  
                    im.Text(tooltip.titles[2])

                    im.PushItemWidth(128)

                    local bounces = im.FloatPtr(setting.bounces)

                    if im.SliderFloat("##801", bounces, 0, 8, "%.0f") then
                        setting.bounces = bounces[0]
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
                        im.Text(languagues.general.minHz)
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
                        im.Text(languagues.general.maxHz)
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
                        im.Text(languagues.general.vibrationForce)
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
            tooltip = languagues.throttle

            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox(tooltip.engineOff, enable) then
                setting.enable = enable[0]
            end

            im.Spacing()

            -- Engine on
            setting = settings.throttle.engineOn
            tooltip = languagues.throttle

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
    if im.TreeNode1(languagues.titles[2]) then
        setting = settings.brake
        tooltip = languagues.brake

        local enable = im.BoolPtr(setting.enable)

        im.Spacing()

        if im.Checkbox(languagues.general.enable, enable) then
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
            tooltip = languagues.general.rigidity

            if im.TreeNode1(languagues.brake.titles[1]) then
                -- bySpeed
                setting = settings.brake.rigidity.bySpeed

                if im.TreeNode1(languagues.general.rigidity.titles[1]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(languagues.general.enable, enable) then
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

                    if im.Checkbox(languagues.general.enable, enable) then
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
                            im.Text(languagues.general.rigidity.constant.minForce)
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
                            im.Text(languagues.general.rigidity.constant.maxForce)
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
            tooltip = languagues.brake.abs

            if im.TreeNode1(languagues.brake.titles[2]) then
                local enable = im.BoolPtr(setting.enable)

                im.Spacing()

                if im.Checkbox(languagues.general.enable, enable) then
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
                        im.Text(languagues.general.minHz)
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
                        im.Text(languagues.general.maxHz)
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
                        im.Text(languagues.general.minAmplitude)
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
                        im.Text(languagues.general.maxAmplitude)
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
    if im.TreeNode1(languagues.titles[3]) then
        setting = settings.lightBar
        tooltip = languagues.lightBar

        local enable = im.BoolPtr(setting.enable)

        im.Spacing()

        if im.Checkbox(languagues.general.enable, enable) then
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
                tooltip = languagues.lightBar.emergencyBraking

                if im.TreeNode1(languagues.lightBar.titles[4]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(languagues.general.enable, enable) then
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
                tooltip = languagues.lightBar.hazardLights

                if im.TreeNode1(languagues.lightBar.titles[1]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(languagues.general.enable, enable) then
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
                tooltip = languagues.lightBar.reverse

                if im.TreeNode1(languagues.lightBar.titles[7]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(languagues.general.enable, enable) then
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
                tooltip = languagues.lightBar.tachometer

                if im.TreeNode1(languagues.lightBar.titles[5]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(languagues.general.enable, enable) then
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
                tooltip = languagues.lightBar.vehicleDamage

                if im.TreeNode1(languagues.lightBar.titles[8]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(languagues.general.enable, enable) then
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
                tooltip = languagues.lightBar.driveMode

                if im.TreeNode1(languagues.lightBar.titles[9]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(languagues.general.enable, enable) then
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
                tooltip = languagues.lightBar.policeChase

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
                tooltip = languagues.lightBar.lowFuel

                if im.TreeNode1(languagues.lightBar.titles[2]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(languagues.general.enable, enable) then
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
                            im.Text(languagues.general.micLed.timeOn)
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
                            im.Text(languagues.general.micLed.timeOff)
                            im.EndTooltip()
                        end

                        im.Spacing()
                        im.Spacing()
                    end

                    im.TreePop()
                end

                -- Parking brake
                setting = settings.lightBar.parkingBrake
                tooltip = languagues.lightBar.parkingBrake

                if im.TreeNode1(languagues.lightBar.titles[3]) then
                    local enable = im.BoolPtr(setting.enable)

                    im.Spacing()

                    if im.Checkbox(languagues.general.enable, enable) then
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
                            im.Text(languagues.general.micLed.timeOn)
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
                            im.Text(languagues.general.micLed.timeOff)
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
                tooltip = languagues.lightBar.tcs

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
                tooltip = languagues.lightBar.esc

                local enable = im.BoolPtr(setting.enable)

                if im.Checkbox(tooltip.enable, enable) then
                    setting.enable = enable[0]
                end
                
                im.Spacing()

                -- Police stars
                setting = settings.lightBar.policeStars
                tooltip = languagues.lightBar.policeStars

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
    if im.TreeNode1(string.format(languagues.titles[4], profiles:getProfileName())) then
        tooltip = languagues.profile

        -- Profile name
        if im.TreeNode1(tooltip.titles[1]) then
            tooltip = languagues.profile.rename

            im.Text(tooltip.titles[1])
            im.Spacing()

            im.PushItemWidth(185)

            if im.InputText("##profileRenameName", beam_dsx.main.profileRenameName, 32, im.InputTextFlags_EnterReturnsTrue) then
                
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text(languagues.profile.hover, languagues.strings.save)
                im.EndTooltip()
            end

            im.Spacing()
            im.Separator()

            im.TreePop()
        end

        -- Profile color
        tooltip = languagues.profile

        if im.TreeNode1(tooltip.titles[2]) then
            tooltip = languagues.profile.color

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
                im.Text(languagues.profile.hover, languagues.strings.save)
                im.EndTooltip()
            end

            g = im.FloatPtr(profileColor[2])

            im.PushItemWidth(128)

            if im.SliderFloat("G##301", g, 0, 255, "%.0f") then
                profileColor[2] = g[0]
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text(languagues.profile.hover, languagues.strings.save)
                im.EndTooltip()
            end

            b = im.FloatPtr(profileColor[3])

            im.PushItemWidth(128)

            if im.SliderFloat("B##302", b, 0, 255, "%.0f") then
                profileColor[3] = b[0]
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text(languagues.profile.hover, languagues.strings.save)
                im.EndTooltip()
            end

            profiles:setProfileColor(profileColor)

            im.Spacing()
            im.Separator()

            im.TreePop()
        end

        -- Profile brightness
        tooltip = languagues.profile

        if im.TreeNode1(tooltip.titles[3]) then
            tooltip = languagues.profile.brightness

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
                im.Text(languagues.profile.hover, languagues.strings.save)
                im.EndTooltip()
            end

            im.Spacing()
            im.Separator()

            im.TreePop()
        end

        -- Profile based on vehicle
        tooltip = languagues.profile

        if im.TreeNode1(tooltip.titles[4]) then
            tooltip = languagues.profile.perVehicle

            local enable = im.BoolPtr(not (ffi.string(beam_dsx.main.profileVehicle) == ""))

            im.Spacing()

            if im.Checkbox(languagues.general.enable, enable) then
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
                    im.Text(languagues.profile.hover, languagues.strings.save)
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

local function renderButtons()
    if(not settings) then
        return
    end

    local tooltip = languagues.strings
    local profileName = profiles:getProfileName()

    im.Spacing()

    -- Save profile
    if im.Button(tooltip.save) then
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

        beam_dsx:showMessage(string.format(tooltip.restoreProfileOk, profileName, tooltip.save), 10)
    end

    if im.IsItemHovered() then
        im.BeginTooltip()
        im.Text(string.format(tooltip.restoreProfileHover, profileName))
        im.EndTooltip()
    end

    im.SameLine()

    -- Active profile text
    im.Text(languagues.strings.activeProfile, profiles:getProfileName())

    im.SameLine()

    im.SetCursorPosX(im.GetWindowWidth() - 30)

    -- Settings
    if im.Button("?") then
        beam_dsx:toggleSettingsWindow()
    end

    if im.IsItemHovered() then
        im.BeginTooltip()
        im.Text(tooltip.settingsHover)
        im.EndTooltip()
    end
end

--

local function renderMainWindow()
    if(not beam_dsx.main.show[0]) then
        return
    end

    im.SetNextWindowBgAlpha(0.95)  
    im.SetNextWindowSizeConstraints(im.ImVec2(beam_dsx.constraints.main.width, beam_dsx.constraints.main.height), im.ImVec2(beam_dsx.constraints.main.width, beam_dsx.constraints.main.height))
    im.Begin("BeamDSX v" ..version.. " - by Feche", beam_dsx.main.show, beam_dsx.constraints.main.flags)
    im.SetWindowFontScale(profiles:getFontSize())

    im.PushTextWrapPos(0.0)
    im.TextColored(im.ImVec4(1, 1, 1, 0.6), languagues.strings.welcomeMessage)
    im.PopTextWrapPos()
    im.Separator()

    -- Profile tabs
    renderProfileTabs()

    -- Profile settings
    renderProfileSettings()

    im.Separator()

    -- Buttons
    renderButtons()

    if(not beam_dsx.main.show[0]) then
        
    end
end

local function renderCreateProfileWindow()
    if(not beam_dsx.createProfile.show[0]) then
        return
    end

    local tooltip = languagues.strings

    im.SetNextWindowSizeConstraints(im.ImVec2(beam_dsx.constraints.createProfile.width, beam_dsx.constraints.createProfile.height), im.ImVec2(beam_dsx.constraints.createProfile.width, beam_dsx.constraints.createProfile.height))
    im.Begin(tooltip.profileCreateTitle, beam_dsx.createProfile.show, beam_dsx.constraints.createProfile.flags)
    im.SetWindowFontScale(profiles:getFontSize())

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
        beam_dsx:toggleCreateProfileWindow()
    end

    im.End()

    if(not beam_dsx.createProfile.show[0]) then

    end
end

local function renderSettingsWindow()
    if(not beam_dsx.settings.show[0]) then
        return
    end

    -- DualSenseX app status
    local t = tick:getTick()

    if(beam_dsx.settings.statusTick == -1 or (t - beam_dsx.settings.statusTick >= 1000)) then
        beam_dsx.settings.statusTick = t
        ds:updateDsxStatus()
    end

    local tooltip = languagues.strings

    im.SetNextWindowSizeConstraints(im.ImVec2(beam_dsx.constraints.settings.width, beam_dsx.constraints.settings.height), im.ImVec2(beam_dsx.constraints.settings.width, beam_dsx.constraints.settings.height))
    im.Begin(tooltip.settingsTitle, beam_dsx.settings.show, beam_dsx.constraints.settings.flags)
    im.SetWindowFontScale(profiles:getFontSize())

    -- Network settings
    if im.TreeNode1(tooltip.settingsDSXNetwork) then
        im.PushItemWidth(185)
        im.Spacing()

        -- IP
        im.Text(tooltip.settingsNetworkIP)
        im.InputText("##udpIP", beam_dsx.settings.udpIP, 32, im.InputTextFlags_EnterReturnsTrue)

        im.Spacing()

        -- Port
        im.Text(tooltip.settingsNetworkPort)
        im.InputText("##udpPort", beam_dsx.settings.udpPort, 6, im.InputTextFlags_EnterReturnsTrue) 

        im.Spacing()

        -- Save button
        if im.Button(tooltip.save) then
            local udpIP = ffi.string(beam_dsx.settings.udpIP)
            local udpPort = ffi.string(beam_dsx.settings.udpPort)

            beam_dsx:onUdpSave(udpIP, udpPort)
        end

        im.SameLine()

        -- Reset button
        if im.Button(tooltip.settingsNetworkRestore) then
            beam_dsx.settings.udpIP = im.ArrayChar(32, "127.0.0.1")
            beam_dsx.settings.udpPort = im.ArrayChar(8, "6969")
            beam_dsx:onUdpSave("127.0.0.1", 6969)
        end

        im.Spacing()
        im.Spacing()

        im.TreePop()
    end

    -- Font size
    if im.TreeNode1(tooltip.settingsFontSize) then
        local fontSize = profiles:getFontSize()

        im.Text(string.format(tooltip.settingsFontCurrentSize, fontSize))
        im.Spacing()

        if im.Button(tooltip.settingsFontSizePlus) then
            beam_dsx:setFontSize(fontSize + 0.025)
        end

        im.SameLine()

        if im.Button(tooltip.settingsFontSizeMinus) then
            beam_dsx:setFontSize(fontSize - 0.025)
        end

        im.SameLine()

        if im.Button(tooltip.settingsFontSizeReset) then
            beam_dsx:setFontSize(1)
        end

        im.TreePop()
    end

    -- Controller index
    if im.TreeNode1(tooltip.settingsControllerIndexTitle) then
        im.PushItemWidth(185)
        im.Spacing()

        im.PushTextWrapPos(0.0)
        im.Text(tooltip.settingsControllerIndexText)
        im.PopTextWrapPos()

        im.InputText("##controllerIndex", beam_dsx.settings.controllerIndex, 32, im.InputTextFlags_EnterReturnsTrue)

        im.Spacing()

        -- Save button
        if im.Button(tooltip.save) then
            local newControllerIndex = ffi.string(beam_dsx.settings.controllerIndex)
            beam_dsx:onControllerIndexChange(tonumber(newControllerIndex))
        end

        im.Spacing()
        im.Spacing()

        im.TreePop()
    end

    -- Status
    if im.TreeNode1(tooltip.settingsStatusTitle) then
        im.Text("Beam DSX:")
        im.SameLine()

        if(beam_dsx.status == modStates.enabled) then
            im.TextColored(im.ImVec4(0, 1, 0, 0.6), tooltip.settingsStatusEnabled)
        else                                             
            im.TextColored(im.ImVec4(1, 0, 0, 0.8), tooltip.settingsStatusDisabled)
        end

        im.Text("DualSenseX:")
        im.SameLine()

        if(not ds:getDsxStatus()) then
            im.TextColored(im.ImVec4(1, 0, 0, 0.8), tooltip.settingsStatusDisconnected)
        else                                      
            im.TextColored(im.ImVec4(0, 1, 0, 0.6), tooltip.settingsStatusConnected)
            im.SameLine()
            im.Text("-> %s:%s", profiles:getUDPIp(), tostring(profiles:getUDPPort()))
        end

        local controllerIndex = profiles:getControllerIndex()
        local device = ds:getDsxDeviceType()

        if(ds:getDsxStatus() and device) then
            im.Text(tooltip.settingsStatusControllerText1)
            im.SameLine()
            im.Text(tooltip.settingsStatusControllerText2, (device == -1) and tooltip.settingsStatusControllerUnknown or device, tostring(controllerIndex))
            im.Text(tooltip.settingsStatusCharge, ds:getDsxBatttery())
            im.Text(tooltip.settingsStatusMacAddress, ds:getDsxMacAddress())
        end

        if(not device) then
            im.Text(tooltip.settingsStatusControllerText1)
            im.SameLine()
            im.TextColored(im.ImVec4(1, 0, 0, 0.8), tooltip.settingsStatusControllerText2, tooltip.settingsStatusDisconnected, tostring(controllerIndex))
        end

        im.Text(tooltip.settingsStatusTime, ds:getDsxTime())
        im.TreePop()
    end

    im.Spacing()
    im.Separator()
    im.Spacing()

    -- Disable mod
    local enable = im.BoolPtr(profiles:isProfilesEnabled())

    if im.Checkbox(tooltip.modEnable, enable) then
        profiles:setProfilesEnabled(enable[0])

        if(not enable[0]) then
            beam_dsx:mailboxToVE("mod_disable")
            beam_dsx.status = modStates.disabled
            ds:resetController()
        else
            beam_dsx.status = modStates.enabled
            beam_dsx:mailboxToVE("mod_enable")
        end
    end

    if im.IsItemHovered() then
        im.BeginTooltip()
        im.Text(tooltip.modEnableHover)
        im.EndTooltip()
    end

    im.Spacing()

    -- Allow on BeamMp servers
    -- Detect if mod is running on a BeamMp server as extension; if it is, then do not display 'Allow on BeamMp servers' text
    if(not MPModManager or not MPModManager.getModList().multiplayerbeam_dsx) then
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

    -- Close all GUIs when vehicle moves
    local enable = im.BoolPtr(profiles.closeOnVehicleMove)

    if im.Checkbox(tooltip.closeOnVehicleMove, enable) then
        profiles:setCloseOnVehicleMove(enable[0])
    end

    if im.IsItemHovered() then
        im.BeginTooltip()
        im.Text(tooltip.closeOnVehicleMoveHover)
        im.EndTooltip()
    end

    if(not beam_dsx.settings.show[0]) then
       
    end
end

--
-- BeamNG events
--
local function onUpdate(dt)
    tick:handleGameTick(dt)

    -- Mod is not compatible with current game version
    if(beam_dsx.status == modStates.version_fail) then
        local t = tick:getTick()
        -- Fix for BeamMp not showing toast message
        if(t > 2000 and t < 2500) then
            local v = beam_dsx:gameVersionCheck()
            guihooks.trigger("toastrMsg", { type = "error", title = "", msg = "Beam DSX v" ..version.. " is not compatible with game version '" ..v.version.. "', check console for more info.", config = { closeButton = true, timeOut = 0, extendedTimeOut = 0 } })
            log("E", "onExtensionLoaded", "mod is not compatible with game version '%s', please check if a compatible Beam DSX version exists, mod disabled.", v.version)
        end
        return
    end

    -- Create profile UI
    renderCreateProfileWindow()

    -- Main window
    renderMainWindow()
    
    -- Settings window
    renderSettingsWindow()

    -- Close all windows if vehicle is moving
    if(profiles.closeOnVehicleMove) then
        if(utils.getAirSpeed() > 10) then
            beam_dsx:hideAllWindows()
        end
    end
end

local function onExtensionLoaded() 
    local v = beam_dsx:gameVersionCheck()

    if(v.status == false) then
        beam_dsx.status = modStates.version_fail
        return 
    end

    profiles:init()
    text:init()

    languagues = text:getText() -- get current language
    settings = profiles:getProfileSettings() -- get profile settings

    if(not settings) then
        profiles:createDefaultProfile()
        profiles:setActiveProfile(1)

        settings = profiles:getProfileSettings()
    end
    
    beam_dsx.status = profiles:isProfilesEnabled() and modStates.enabled or modStates.disabled
    beam_dsx:toggleBeamMpHook()

    profiles:setUDPAddress(profiles:getUDPIp(), profiles:getUDPPort())
    profiles:setControllerIndex(profiles:getControllerIndex())

    beam_dsx:setFontSize(profiles:getFontSize())
    beam_dsx:onVehicleUpdate()

    log("I", "onExtensionLoaded", "extension loaded, active profile: '%s'", profiles:getProfileName())
end

local function onExtensionUnloaded()
	log("I", "onExtensionUnloaded", "extension unloaded")
end

local function onClientEndMission()
    log("I", "onClientEndMission", "player quit, disabling controller ..")

    ds:resetController()
    beam_dsx:hideAllWindows()
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

local function onAiModeChange(objectId, mode)
    local playerVehicleId = be:getPlayerVehicleID(0)

    if(playerVehicleId ~= objectId) then
        return
    end

    if(mode == "disabled") then
        beam_dsx:onVehicleUpdate(playerVehicleId)
    else
        beam_dsx:mailboxToVE("vehicle_invalid")
    end
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
    toggleMainWindow = function() beam_dsx:toggleMainWindow() end,
    onPursuitModeUpdate = onPursuitModeUpdate,
    onAiModeChange = onAiModeChange,
}