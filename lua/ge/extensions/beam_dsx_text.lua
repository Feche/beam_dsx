local defaultPath = "settings/beam_dsx/languages.json"

local function deep_copy_safe(t)
    if(type(t) == "table") then
        local copy = {}
        for key, value in pairs(t) do
            if(type(value) ~= "function" and key ~= "langs") then
                copy[key] = (type(value) == "table") and deep_copy_safe(value) or value
            end
        end
        return copy
    end
    return nil
end

local function get_path()
    local s = jsonReadFile(defaultPath)
    return s and s.path or defaultPath
end

return
{
    path = defaultPath,
    active = "en",
    langs = {},
    languages =
    {
        -- English
        en =
        {
            titles = { "Throttle Trigger", "Brake Trigger", "Lightbar and LEDs", "Profile '%s'" },
            -- Throttle trigger
            throttle =
            {
                titles = { "Rigidity", "Wheel Slip", "Up Shift", "Rev. Limiter" },
                enableHover = "If disabled, throttle trigger haptics will be turned off.",
                engineOff = "If enabled, the throttle trigger will soften while the engine is off.",
                wheelSlip =
                {
                    titles = { "Slip Tolerance", "Maximum Force at", "Minimum Hertz", "Maximum Hertz", "Minimum Amplitude", "Maximum Amplitude" },
                    enable = "If enabled, the trigger will vibrate in sync with the level of wheelslip.",
                    tolerance = "Slip detection tolerance, lower values triggers slip earlier.",
                    maxForceAt = "At this value, the trigger vibration will reach its maximum force, lower values will activate haptics earlier.",
                },
                upShift =
                {
                    titles = { "Maximum Hertz", "Maximum Force", "Vibration Duration" },
                    enable = "If enabled, the trigger will vibrate while upshifting or downshifting.",
                    timeOn = "Vibration duration in milliseconds when upshifting or downshifting, higher values make trigger vibrate longer.",
                },
                revLimit =
                {
                    titles = { "Minimum Hertz", "Maximum Hertz", "Maximum Force", "Vibration Duration" },
                    enable = "If enabled, the trigger will vibrate in sync with the engine's fuel cutoff system.",
                    timeOn = "Vibration duration in milliseconds when rev. limiting, higher values make trigger vibrate longer.",
                },
            },
            -- Brake
            brake =
            {
                titles = { "Rigidity", "ABS" },
                enableHover = "If disabled, brake trigger haptics will be turned off.",
                abs =
                {
                    titles = { "Minimum Hertz", "Maximum Hertz", "Minimum Amplitude", "Maximum Amplitude" },
                    enable = "If enabled, the trigger will vibrate in sync with the vehicle's ABS system.",
                    engineOff = "If enabled, the brake trigger will harden if the engine is off.",
                    wheelMissing = "If enabled, the brake trigger will harden if a wheel is missing.",
                }
            },
            lightBar =
            {
                titles = { "Hazard Lights", "Low Fuel", "Parking Brake", "Emergency Braking", "Tachometer", "Electronic Stability Control (ESC)", "Reverse Gear" },
                enableHover = "If disabled, lighbar will be turned off.",
                hazardLights =
                {
                    titles = { "Color On", "Color Off" },
                    enable = "If enabled, the lightbar will sync with the vehicle's hazard lights.",
                    colorOn = "Color of the lightbar while hazards lights are on, in RGB format.",
                    colorOff = "Color of the lightbar while hazards lights are off, in RGB format.",
                },
                lowFuel =
                {
                    titles = { "Time On", "Time Off" },
                    enable = "If enabled, the microphone LED will flash when your vehicle has low fuel.",
                },
                parkingBrake =
                {
                    titles = { "Time On", "Time Off" },
                    enable = "If enabled, the microphone LED will flash when the parking brake is engaged.",
                },
                emergencyBraking =
                {
                    titles = { "Color On", "Color Off" },
                    enable = "If enabled, the lightbar will blink in sync with the vehicle's Adaptive Brake Lights (ABL) system. (if present)",
                    colorOn = "Color of the lightbar when the Adaptive Brake Lights (ABL) system turns on the rear brake lights.",
                    colorOff = "Color of the lightbar when the Adaptive Brake Lights (ABL) system turns off the rear brake lights.",
                    alwaysBlink = "If enabled, lighbar will always flash under Emergency Braking\non any vehicle.",
                },
                tachometer =
                {
                    titles = { "Color Low RPM", "Color Medium RPM", "Color High RPM" },
                    enable = "If enabled, lighbar will fade between colors depending on engine RPM.",
                    colorLow = "Color of the lightbar when engine is at low RPM.",
                    colorMed = "Color of the lightbar when engine is at medium RPM.",
                    colorHi = "Color of the lightbar when engine is at high RPM.",
                },
                reverse =
                {
                    titles = { "Color On" },
                    enable = "If enabled, the lightbar will activate when the reverse gear is engaged.",
                    colorOn = "Color of the lightbar when reverse gear is engaged."
                },
                tcs =
                {
                    enable = "If enabled, the microphone LED will flash according to the status\nreported by the Traction Control System.",
                },
                esc =
                {
                    enable = "If enabled, the microphone LED will flash according to the status\nreported by the Electronic Stability Control system.",
                },
            },
            profile =
            {
                titles = { "Rename Profile", "Profile Color", "Lightbar Brightness" },
                rename =
                {
                    titles = { "New profile name" },
                },
                color =
                {
                    titles = { "This is the color the lightbar will blink when saving the profile or\nresetting the vehicle." },
                },
                brightness =
                {
                    titles = { "You can set the controller's lightbar brightness from 0%% to 100%%." },
                },
                hover = "Click on '%s' to confirm the changes.",
            },
            -- shared/general use, so we don't repeat data
            general =
            {
                enable = "Enable",
                minHz = "Minimum frequency at which the triggers vibrates, lower values decrease the number of vibrations per second.",
                maxHz = "Maximum frequency at which the triggers vibrates, higher values increase the number of vibrations per second.",
                minAmplitude = "Minimum amplitude of the vibration, lower numbers decrease vibration strenght.",
                maxAmplitude = "Maximum amplitude of the vibration, higher numbers increase vibration strenght.",
                minForce = "Minimum force applied to the trigger, lower values make trigger softer.",
                maxForce = "Maximum force applied to the trigger, higher values make trigger stiffer.",
                -- Rigidiity
                rigidity =
                {
                    titles = { "By speed", "Constant" },
                    -- By speed
                    bySpeed =
                    {
                        titles = { "Minimum force", "Maximum force", "Target speed" },
                        enable = "If enabled, trigger stiffness will be based on vehicle speed.",
                    },
                    -- Constant
                    constant =
                    {
                        titles = { "Minimum force", "Maximum force" },
                        enable = "If enabled, trigger stiffness will be based on throttle input.",
                        minForce = "Minimum force of the trigger when the throttle is fully released.",
                        maxForce = "Maximum force of the trigger when the throttle is fully pressed.",
                    },
                    minForce = "Minimum force of the trigger when vehicle is stationary, lower values make trigger softer.",
                    minForceInverted = "Minimum force of the trigger when vehicle is at or above %dkm/h, lower values make trigger softer.",
                    maxForce = "Maximum force of the trigger when vehicle is at or above %dkm/h, higher values make trigger stiffer.",
                    maxForceInverted = "Maximum force of the trigger when vehicle is stationary, higher values make trigger stiffer.",
                    maxForceAt = "Speed at where the trigger applies its maximum force.",
                    maxForceAtInverted = "Speed at where the trigger applies its minimum force.",
                    inverted = "Use minimum speed instead of maximum (inverted)",
                },
                micLed =
                {
                    timeOn = "Time, in milliseconds, that the microphone LED will remain on.",
                    timeOff = "Time, in milliseconds, that the microphone LED will remain off.",
                },
            },
            strings =
            {
                modEnable = "Enable Beam DSX",
                modEnableHover = "If disabled, Beam DSX will not send any data to your DualSense controller.",
                allowBeamMp = "Allow mod to run on BeamMp servers",
                allowBeamMpHover = "Allows the mod to run on BeamMp servers (ask for permission)",
                saveProfile = "Save",
                saveProfileHovered = "Saves the current profile.",
                saveProfileOk = "Profile '%s' has been saved",
                deleteProfile = "Delete",
                deleteProfileHover = "Deletes the current profile '%s'.",
                deleteProfileError = "Can't delete profile '%s', you must keep at least one profile",
                restoreProfile = "Restore defaults",
                restoreProfileHover = "Restores current profile '%s' to default settings.",
                restoreProfileOk = "Default settings for profile '%s' restored, click on %s to confirm",
                activeProfile = "Active profile: %s",
                welcomeMessage = "Welcome to Beam DSX configuration windows, here you can manage multiple\nprofiles with each one having individual settings.",
                profileNameEmptyError = "Profile name can't be empty!",
                profileNameInvalidError = "Profile name cannot contain\n'-' or '+'.",
                profileAlreadyExistError = "Profile '%s' already exists",
                profileCreateOk = "Created profile '%s'",
                profileCreateTitle = "Create new profile",
                profileCreateName = "Please enter the profile name:",
                profileCreateMaxError = "Maximum profiles reached (%d/%d)",
                profileCreateButton1 = "Create",
                profileCreateButton2 = "Cancel",
                profileActive = "Profile '%s' is now active",
                changeLanguage = "?",
                changeLanguageHover = "Click to switch between different languages.",
            },
        }
    },
    -- Functions
    init = function(self)
        self.path = get_path()

        local s = jsonReadFile(self.path)

        if(not s or (type(s) == "table" and not s.path)) then
            jsonWriteFile(self.path, deep_copy_safe(self), true)
            
            s = jsonReadFile(self.path)

            log("I", "createLangFile", "[beam_dsx] GE: created default language 'en'")
        end

        self.active = s.active
        self.languages = s.languages

        for key, value in pairs(self.languages) do
            self.langs[#self.langs + 1] = key
        end

        table.sort(self.langs)

        log("I", "createLangFile", "[beam_dsx] GE: language '" ..tostring(self.active).. "' loaded (" ..self.path.. ")")
    end,
    getText = function(self)
        return self.languages[self.active]
    end,
    getLangIndex = function(self)
        for i = 1, #self.langs do
            if(self.langs[i] == self.active) then
                return i
            end
        end

        return 1
    end,
    switchLanguage = function(self)
        local index = self:getLangIndex()
        self.active = self.langs[index + 1] or self.langs[1]

        jsonWriteFile(self.path, deep_copy_safe(self), true)

        log("I", "switchLanguage", "[beam_dsx] GE: switched to language '" ..tostring(self.active).. "'")
    end,
}   