-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local defaultsettings =
{
    enableOnBeamMPServers = false,

    throttle =
    {
        rigidity =
        {
            -- if this is enabled, then the trigger will get softer/stiffer depending on speed
            bySpeed =
            {
                enable = false,
                minForce = 10, -- byte -- minimum force of the throttle trigger (higher speeds), default: 10, max: 255
                maxForce = 40, -- byte -- maximum force of the throttle trigger (lower speeds), default: 40, max: 255
                maxForceAt = 150, -- kmh -- speed at where force is at minimum, going faster will make the throttle force softer, default: 150, max: 1000
                inverted = false, -- bool -- if set to true, it will work in inverse mode, default: false
            },
            -- if this is enabled, then the trigger will get softer/stiffer depending on how much you press the throttle, default configs makes the throttle stronger when reaching the end of the trigger
            constant =
            {
                enable = true,
                minForce = 20, -- byte -- position at where force starts to apply, default: 20, max: 255
                maxForce = 60, -- byte -- maximum force of the throttle when the trigger reaches the end, default: 40, max: 255
            },
        },
        wheelSlip =
        {
            enable = true,
            tolerance = 5, -- lower tolerances triggers slip earlier, default: 5, max: 1000
            maxForceAt = 65, -- int -- at this value the vibration will be at max force, default: 45, max: 1000
            minHz = 25, -- hz -- minimum frequency at which the triggers vibrates, default: 20, max: 255
            maxHz = 40, -- hz -- maximum frequency at which the triggers vibrates, default: 40, max: 255
            minAmplitude = 1, -- minimum amplitude of the vibration, higher numbers increase vibration strenght, default: 1, max: 8
            maxAmplitude = 2, -- maximum amplitude of the vibration, higher numbers increase vibration strenght, default: 3, max: 8
        },
        upShift =
        {
            enable = true,
            maxHz = 120, -- hz -- frequency at which the triggers vibrates, default: 120, max: 255
            maxForce = 200, -- hz -- higher numbers will make the shift vibration stronger, default: 255, max: 255
            timeOn = 32, -- ms -- duration of the vibration when upshifting, default: 32, max: 1000
        },
        engineOff = 
        {
            enable = true, -- bool -- if enabled, throttle trigger force will turn off when engine is not running
        },
        revLimit =
        {
            enable = true,
            minHz = 180, -- hz -- frequency at which the triggers vibrates, default: 160, max: 255
            maxHz = 220,
            maxForce = 1, -- hz -- higher numbers will make the rev limiter vibration stronger, default: 100, max: 255
            timeOn = 16, -- ms -- duration of the vibration when upshifting, default: 16, max: 1000
        },
    },
    brake =
    {
        rigidity = 
        {
            bySpeed =
            {
                enable = true,
                minForce = 0, -- byte -- minimum rigidity for the brake trigger, default: 0, max: 255
                maxForce = 40, -- byte -- maximum rigidity for the brake trigger, default: 40, max: 255
                maxForceAt = 150, -- kmh -- maximum rigidity for the brake trigger at this speed, default: 150, max: 1000
                inverted = false,
            },
            constant =
            {
                enable = true,
                minForce = 20, -- byte -- position at where force starts to apply, default: 20, max: 255
                maxForce = 60, -- byte -- maximum force of the throttle when the trigger reaches the end, default: 40, max: 255
            },
        },
        abs = 
        {
            enable = true,
            minHz = 10, -- hz -- minimum frequency at which the trigger will vibrate, default: 20, max: 40
            maxHz = 40, -- hz -- maximum frequency at which the trigger will vibrate, default 40, max: 40
            minAmplitude = 2, -- force of the trigger while vibrating, lower numbers decrease force, default: 2, max: 8
            maxAmplitude = 3, -- force of the trigger while vibrating, higher numbers increase force, default: 3, max: 8
        },
        wheelMissing =
        {
            enable = true,
            maxForce = 255, -- byte -- force of the brake trigger when a wheel is missing, default: 255, max: 255
        },
        engineOff = 
        {
            enable = true,
            maxForce = 255, -- byte -- force of the brake trigger when engine is off, default: 255, max: 255
        },
    },
    lightBar =
    {
        hazardLights =
        {
            enable = true,
            colorOn = { 255, 165, 0, 255 }, -- color -- RGBA color of the led when hazards are ON, default: 255, 165, 0, 255
            colorOff = { 0, 0, 0, 0 }, -- color -- RGBA color of the led when hazards are ON, default: 0, 0, 0, 0
            timeOn = 200,
            timeOff = 200,
        },
        lowFuel =
        {
            enable = true,
            timeOn = 300, -- ms -- amount of time the led is ON, default: 300
            timeOff = 1300, -- ms -- amount of time the led is OFF, default: 1000
        },
        parkingBrake =
        {
            enable = true,
            timeOn = 250, -- ms -- amount of time the led is ON, default: 500
            timeOff = 500, -- ms -- amount of time the led is OFF, default: 125
        },
        emergencyBraking =
        {
            enable = true,
            colorOn = { 255, 0, 0, 255 },
            colorOff = { 0, 0, 0, 0 },
        },
        tachometer =
        {
            enable = true,
            colorLow = { 0, 255, 0, 125 },
            colorMed = { 255, 200, 0, 200 },
            colorHi = { 255, 0, 0, 255 },
            offset = 2500, -- int -- the offset at where the tachometer starts to change color (low revs to high revs) - default: 2500, max: inf
        },
        esc =
        {
            enable = true,
            timeOn = 16,
        },
        tcs = 
        {
            enable = true,
        },
        reverse =
        {
            enable = true,
            colorOn = { 255, 255, 255, 255 },
        },
    },
}

local function deep_copy(t)
    if(type(t) == "table") then
        local copy = {}
        for key, value in pairs(t) do
            if(type(value) ~= "function") then
                copy[key] = (type(value) == "table") and deep_copy(value) or value
            end
        end
        return copy
    end
    return false
end

return
{
    profiles = {},
	max = 6, -- max profiles
    active = 1, -- active profile
	path = "settings/beam_dsx/profiles.json",
    temp = nil,
	-- Functions
	init = function(self)
		local s = jsonReadFile(self.path)

		self.max = s and s.max or self.max
		self.path = s and s.path or self.path
		self.active = s and s.active or self.active
		self.profiles = s and s.profiles or self.profiles

        if(not s) then
			self:createProfile("Profile 1", "", deep_copy(defaultsettings))
            self:saveProfiles()
		end

		print("[beam_dsx] GE: init profiles " ..self.path.. " (max: " ..self.max.. ", active: " ..self.active.. ", total: " ..(#self.profiles).. ") ..")
	end,
	saveProfiles = function(self)
		jsonWriteFile(self.path, deep_copy(self), true)
	end,
	loadProfiles = function(self)
		self.profiles = jsonReadFile(self.path)
	end,
    saveActiveProfileToTemp = function(self)
        self.temp = deep_copy(self.profiles[self.active].settings)
    end,
    restoreActiveProfileFromTemp = function(self)
        if(self.temp) then
            self.profiles[self.active].settings = deep_copy(self.temp)
            self.temp = nil
        end
    end,
	createProfile = function(self, name, vehicle, settings)
		table.insert(self.profiles, { name = name, vehicle = vehicle, settings = settings })
        print("[beam_dsx] GE: created profile " ..name)
	end,
    setActiveProfile = function(self, index)
        index = index and index or 1
        self.active = index

        local s = jsonReadFile(self.path)

        if(s) then
            s.active = self.active
            jsonWriteFile(self.path, deep_copy(s), true)
        end
    end,
    setActiveProfileSettings = function(self, settings)
        self.profiles[self.active].settings = deep_copy(settings)
    end,
	getProfiles = function()
		return self.profiles
	end,
	getPath = function(self)
		return self.path
	end,
	getActiveProfileID = function(self)
		return self.active
	end,
	getProfileSettings = function(self, index)
		index = index and index or self.active
		return self.profiles[index].settings
	end,
	getProfileName = function(self, index)
		index = index and index or self.active
		return self.profiles[index].name
	end,
	getProfileVehicle = function(self, index)
		index = index and index or self.active
		return self.profiles[index].vehicle
	end,
	getTotalProfiles = function(self)
		return #self.profiles
	end,
    getDefaultSettings = function(self)
        return deep_copy(defaultsettings)
    end,
    getActiveProfileSetting = function(self, setting)
        return self.profiles[self.active].settings[setting]
    end,
    getActiveProfileSettings = function(self, setting)
        return self.profiles[self.active].settings
    end,
}