-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

-- TODO: testing | color picker | close gui windows on exit/car move

local defaultSettings = require("ge.extensions.utils.default_settings")
local utils = require("ge.extensions.utils.utils")
local common = require("common.common")
local udp = require("common.udp")
local ds = require("common.ds")

local log = common.log
local defaultPath = "settings/beam_dsx/profiles.json"
local forceAlwaysDefaultSettings = true

return
{
    enable = true,
    profiles = {},
	max = 8, -- max profiles
    active = 1, -- active profile
	path = defaultPath,
    fontSize = 1,
    ip = "127.0.0.1",
    port = 6969,
    enableOnBeamMPServers = false,
    controllerIndex = 0,
    closeOnVehicleMove = true,
    temp = nil,
	-- Functions
	init = function(self)
        self.path = common.get_path(defaultPath)

        local s = jsonReadFile(self.path)

        if(not s or (type(s) == "table" and not s.path) or forceAlwaysDefaultSettings) then
            self:createDefaultProfile()
            
            s = jsonReadFile(self.path)
        end

		common.table_merge(self, s)

        if(not self.profiles[self.active]) then
            self.active = 1
            self:saveProfiles()
        end

		log("I", "init", "%d profiles loaded (%s)", #self.profiles, self.path)
        --log("I", "init", "(max: " ..self.max.. ", active: " ..self.active.. ", total: " ..(#self.profiles).. ")")
	end,
	loadProfiles = function(self)
        local s = jsonReadFile(self.path)

        if(not s or (type(s) == "table" and not s.path)) then
            return
        end

		self.profiles = s.profiles
	end,
    saveProfiles = function(self)
		jsonWriteFile(self.path, common.deep_copy_safe(self, "temp"), true)
	end,
	createProfile = function(self, name, settings, color)
		table.insert(self.profiles, { name = name, vehicle = "", settings = settings, color = color or ({ math.random() * 255, math.random() * 255, math.random() * 255, 255 }) })

        self:saveProfiles()

        log("I", "createProfile", "created profile '%s' (id: %d)", name, #self.profiles)
	end,
    createDefaultProfile = function(self)
        local defaults = common.deep_copy_safe(defaultSettings)

        self:createProfile("Normal", common.deep_copy_safe(defaults), { 128, 56, 255, 255 })

        defaults.throttle.rigidity.bySpeed.minForce = 40
        defaults.throttle.rigidity.bySpeed.maxForce = 120

        defaults.throttle.wheelSlip.tolerance = 3
        defaults.throttle.wheelSlip.maxForceAt = 35
        defaults.throttle.wheelSlip.minAmplitude = 2
        defaults.throttle.wheelSlip.maxAmplitude = 4

        defaults.throttle.upShift.maxForce = 255
        defaults.throttle.revLimit.maxForce = 100

        defaults.throttle.redLine.minHz = 120
        defaults.throttle.redLine.maxHz = 255
        defaults.throttle.redLine.vibrationForce = 2
        defaults.throttle.redLine.startAt = 70

        defaults.brake.rigidity.bySpeed.minForce = 60
        defaults.brake.rigidity.bySpeed.maxForce = 180

        defaults.brake.abs.minAmplitude = 2
        defaults.brake.abs.maxAmplitude = 4

        self:createProfile("Stronger", common.deep_copy_safe(defaults), { 255, 12, 23, 255 })
        self:saveProfiles()

        log("I", "createDefaultProfile", "creating default profiles ..")
    end,
    deleteProfile = function(self, index)
        if(not index) then
            return
        end

        log("I", "deleteProfile", "deleting profile '%s' (id: %d)", self.profiles[index].name, index)

        table.remove(self.profiles, index)
        self:saveProfiles()
    end,
    --
    -- set
    --
    setActiveProfile = function(self, index)
        index = index and index or 1

        if(index < 0 or index > self.max or not self.profiles[index]) then
            return
        end

        self.active = index

        log("I", "setActiveProfile", "switching active profile to '%s' (id: %d)", self:getProfileName(), self.active)

        -- Update active profile in config file
        local s = jsonReadFile(self.path)

        if(s) then
            s.active = self.active
            jsonWriteFile(self.path, common.deep_copy_safe(s), true)
        end
    end,
    setProfileSettings = function(self, settings, index)
        index = index and index or self.active

        if(not self.profiles[index]) then
            return
        end

        self.profiles[index].settings = common.deep_copy_safe(settings)
    end,
    setProfileColor = function(self, color)
        if(not color) then
            return
        end

        self.color = color
    end,
    setProfileName = function(self, name)
        if(not self.profiles[self.active]) then
            return
        end

        log("I", "setProfileName", "renaming profile '%s' to '%s' ..", self.profiles[self.active].name, name)
        self.profiles[self.active].name = name
    end,
    setProfileBrightness = function(self, a)
        if(not self.profiles[self.active]) then
            return
        end

        self.profiles[self.active].color[4] = a

        log("I", "setProfileBrightness", "lightbar brightness set to %d", a)
    end,
    setProfileVehicle = function(self, vehicle)
        if(not self.profiles[self.active]) then
            return
        end

        self.profiles[self.active].vehicle = vehicle or ""
    end,
    setBeamMpAllowed = function(self, value)
        self.enableOnBeamMPServers = value

        -- Update enableOnBeamMPServers in config file
        local s = jsonReadFile(self.path)

        if(s) then
            s.enableOnBeamMPServers = self.enableOnBeamMPServers
            jsonWriteFile(self.path, common.deep_copy_safe(s), true)
        end
    end,
    setProfilesEnabled = function(self, value)
        self.enable = value

        -- Update enable in config file
        local s = jsonReadFile(self.path)

        if(s) then
            s.enable = self.enable
            jsonWriteFile(self.path, common.deep_copy_safe(s), true)
        end
    end,
    setFontSize = function(self, size)
        self.fontSize = size

        -- Update fontSize in config file
        local s = jsonReadFile(self.path)

        if(s) then
            s.fontSize = self.fontSize
            jsonWriteFile(self.path, common.deep_copy_safe(s), true)
        end
    end,
    setUDPAddress = function(self, ip, port)
        self.ip = ip
        self.port = port

        utils.saveJsonValue(self.path, "ip", ip)
        utils.saveJsonValue(self.path, "port", port)

        ds:setUDPAddress(self.ip, self.port, "GE")
    end,
    setControllerIndex = function(self, index)
        self.controllerIndex = index

        utils.saveJsonValue(self.path, "controllerIndex", index)

        ds:setControllerIndex(index, "GE")
    end,
    --
    -- get
    --
    getProfiles = function(self)
		return self.profiles
	end,
	getPath = function(self)
		return self.path
	end,
	getActiveProfileID = function(self)
		return self.active
	end,
    getTotalProfiles = function(self)
		return #self.profiles
	end,
    getDefaultSettings = function(self)
        return common.deep_copy_safe(defaultSettings)
    end,
    getMaxProfiles = function(self)
        return self.max
    end,
    getProfileColor = function(self)
        if(not self.profiles[self.active]) then
            return { 255, 255, 255 }
        end

        return self.profiles[self.active].color
    end,
	getProfileName = function(self, index)
		index = index and index or self.active

        if(not self.profiles[index]) then
            return "Unknown"
        end

		return self.profiles[index].name
	end,
	getProfileVehicle = function(self, index)
		index = index and index or self.active

        if(not self.profiles[index]) then
            return ""
        end

		return self.profiles[index].vehicle
	end,
    getVehicleProfile = function(self, vehicle, checkactive)
        for i = 1, self:getMaxProfiles() do
            if(string.find(self:getProfileVehicle(i), "%f[%a]" .. vehicle .. "%f[%A]")) then
                if(checkactive) then
                    if(i ~= self.active) then
                        return i
                    end
                else
                    return i
                end
            end
        end
        return 0
    end,
    getProfileSettings = function(self, index)
        index = index and index or self.active

        if(not self.profiles[index]) then
            return
        end

        return self.profiles[index].settings
    end,
    getProfileBrightness = function(self)
        if(not self.profiles[self.active]) then
            return
        end

        return self.profiles[self.active].color[4] or 255
    end,
    getFontSize = function(self)
        return self.fontSize
    end,
    getUDPIp = function(self)
        return self.ip
    end,
    getUDPPort = function(self)
        return self.port
    end,
    getControllerIndex = function(self)
        return self.controllerIndex
    end,
    isBeamMpAllowed = function(self)
        return self.enableOnBeamMPServers
    end,
    isProfilesEnabled = function(self)
        return self.enable
    end,
}