-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

-- TODO: testing!!

local defaultsettings = require("ge.extensions.utils.settings")
local utils = require("ge.extensions.utils.utils")
local defaultPath = "settings/beam_dsx/profiles.json"
local forceAlwaysDefaultSettings = false

return
{
    enable = true,
    profiles = {},
	max = 8, -- max profiles
    active = 1, -- active profile
	path = defaultPath,
    temp = nil,
    enableOnBeamMPServers = false,
	-- Functions
	init = function(self)
        self.path = utils.get_path(defaultPath)

        local s = jsonReadFile(self.path)

        if(not s or (type(s) == "table" and not s.path) or forceAlwaysDefaultSettings) then
            self:createDefaultProfile()
            
            s = jsonReadFile(self.path)
        end

		self.max = s.max
		self.active = s.active
		self.profiles = s.profiles
        self.enableOnBeamMPServers = s.enableOnBeamMPServers
        self.enable = s.enable

        if(not self.profiles[self.active]) then
            self.active = 1
        end

		log("I", "init", "[beam_dsx] GE: " ..#self.profiles.. " profiles loaded (" ..self.path.. ")")
        --log("I", "init", "[beam_dsx] GE: (max: " ..self.max.. ", active: " ..self.active.. ", total: " ..(#self.profiles).. ")")
	end,
	loadProfiles = function(self)
        local s = jsonReadFile(self.path)

        if(not s or (type(s) == "table" and not s.path)) then
            return
        end

		self.profiles = s.profiles
	end,
    saveProfiles = function(self)
		jsonWriteFile(self.path, utils.deep_copy_safe(self, "temp"), true)
	end,
	createProfile = function(self, name, settings, color)
		table.insert(self.profiles, { name = name, vehicle = "", settings = settings, color = color or ({ math.random() * 255, math.random() * 255, math.random() * 255 }) })

        self:saveProfiles()

        log("I", "createProfile", "[beam_dsx] GE: created profile " ..name.. " (id: " ..#self.profiles.. ")")
	end,
    createDefaultProfile = function(self)
        local defaults = utils.deep_copy_safe(defaultsettings)

        self:createProfile("Normal", utils.deep_copy_safe(defaults), { 128, 56, 255, 255 })

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

        self:createProfile("Stronger", utils.deep_copy_safe(defaults), { 255, 12, 23, 255 })
        self:saveProfiles()

        log("I", "createDefaultProfile", "[beam_dsx] GE: creating default profiles ..")
    end,
    deleteProfile = function(self, index)
        if(not index) then
            return
        end

        log("I", "deleteProfile", "[beam_dsx] GE: deleting profile " ..self.profiles[index].name.. " (id: " ..index.. ")")

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
        self:loadProfiles() -- actually reloads config file

        log("I", "setActiveProfile", "[beam_dsx] GE: switching active profile to '" ..(self:getProfileName() or "-").. "' (id: " ..self.active.. ")")

        -- Update active profile in config file
        local s = jsonReadFile(self.path)

        if(s) then
            s.active = self.active
            jsonWriteFile(self.path, utils.deep_copy_safe(s), true)
        end
    end,
    setProfileSettings = function(self, settings, index)
        index = index and index or self.active

        if(not self.profiles[index]) then
            return
        end

        self.profiles[index].settings = utils.deep_copy_safe(settings)
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

        log("I", "setProfileName", "[beam_dsx] GE: renaming profile '" ..self.profiles[self.active].name.. "' to '" ..name.. "' ..")

        self.profiles[self.active].name = name
    end,
    setProfileBrightness = function(self, a)
        if(not self.profiles[self.active]) then
            return
        end

        self.profiles[self.active].color[4] = a

        log("I", "setProfileBrightness", "[beam_dsx] GE: lightbar brightness set to " ..tostring(a))
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
            jsonWriteFile(self.path, utils.deep_copy_safe(s), true)
        end
    end,
    setProfilesEnabled = function(self, value)
        self.enable = value
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
        return utils.deep_copy_safe(defaultsettings)
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
    isBeamMpAllowed = function(self)
        return self.enableOnBeamMPServers
    end,
    isProfilesEnabled = function(self)
        return self.enable
    end,
}