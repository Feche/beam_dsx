-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

return
{
    -- English
    en =
    {
        titles = { "Throttle Trigger", "Brake Trigger", "Lightbar and LEDs", "Profile '%s'" },
        -- Throttle trigger
        throttle =
        {
            titles = { "Rigidity", "Wheel Slip", "Up Shift", "Rev. Limiter", "Redline" },
            enableHover = "If disabled, throttle trigger haptics will be turned off.",
            engineOff = "If enabled, the throttle trigger will soften while the engine is off.",
            engineOn = "If enabled, the trigger will click when turning on the engine.",
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
            redLine =
            {
                titles = { "Start At", "Vibration Bounces", "Minimum Hertz", "Maximum Hertz", "Vibration Force" },
                enable = "If enabled, the trigger will vibrate when reaching the engine red line.",
                startAt = "Specifies the engine RPM threshold (percentage of maximum RPM) at which the trigger begins to vibrate.",
                bounces = "The number of 'bounces' the vibration will have until it reaches maximum RPM.",
            }
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
            titles = { "Hazard Lights", "Low Fuel", "Parking Brake", "Emergency Braking", "Tachometer", "Electronic Stability Control (ESC)", "Reverse Gear", "Vehicle Damage", "Drive Mode" },
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
                colorOn = "Color of the lightbar when the Adaptive Brake Lights (ABL) system turns on the rear brake lights, in RGB format.",
                colorOff = "Color of the lightbar when the Adaptive Brake Lights (ABL) system turns off the rear brake lights, in RGB format.",
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
                colorOn = "Color of the lightbar when reverse gear is engaged, in RGB format."
            },
            tcs =
            {
                enable = "If enabled, the microphone LED will flash according to the status\nreported by the Traction Control System.",
            },
            esc =
            {
                enable = "If enabled, the player LED will flash according to the status\nreported by the Electronic Stability Control system.",
            },
            policeChase =
            { 
                enable = "If enabled, the lightbar will flash red and blue when the police is\nchasing you.",
            },
            policeStars =
            {
                enable = "If enabled, the player LED will indicate the current police\nwanted level.",
            },
            vehicleDamage =
            {
                titles = { "Time On", "Blink Speed", "Color On", "Color Off" },
                enable = "If enabled, the lightbar will blink when the vehicle's sensors detect a hard collision.",
                timeOn = "The amount of time the lighbar will blink, in milliseconds.",
                blinkSpeed = "Blinking speed, higher values increase blink speed.",
                colorOn = "Color of the lightbar when blink is at the on state, in RGB format.",
                colorOff = "Color of the lightbar when blink is at the off state, in RGB format.",
            },
            driveMode =
            {
                titles = { "Blink Time" },
                enable = "If enabled, the lightbar will flash when you change your vehicle drive mode.",
                blinkTime = "The amount of time the lightbar will flash, in milliseconds.",
            }
        },
        profile =
        {
            titles = { "Rename Profile", "Profile Color", "Lightbar Brightness", "Per Vehicle" },
            rename =
            {
                titles = { "Rename your profile by typing a new profile name." },
            },
            color =
            {
                titles = { "This is the color the lightbar will blink when saving or activating\nthe profile." },
            },
            brightness =
            {
                titles = { "You can set the controller lightbar brightness from 0%% to 100%%." },
            },
            perVehicle =
            {
                titles = { "Add multiple vehicles to a profile by separating them with commas, example: md_series, pickup, sbr" },
                enableHover = "If enabled, this profile will automatically load when the driven vehicle matches the name.",
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
            vibrationForce = "The force of the vibration, higher numbers make trigger vibration stronger.",
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
            save = "Save",
              
            modEnable = "Enable Beam DSX",
            modEnableHover = "If disabled, Beam DSX will not send any data to your DualSense controller.",

            allowBeamMp = "Allow mod to run on BeamMp servers",
            allowBeamMpHover = "Allows the mod to run on BeamMp servers (ask for permission)",

            closeOnVehicleMove = "Close all windows when the vehicle moves",
            closeOnVehicleMoveHover = "If enabled, any open window will close automatically when reaching 10km/h.",

            saveProfileHovered = "Saves the current profile.",
            saveProfileOk = "Profile '%s' has been saved",

            deleteProfile = "Delete",
            deleteProfileNotification = "Profile '%s' has been deleted",
            deleteProfileHover = "Deletes the current profile '%s'.",
            deleteProfileError = "Can't delete profile '%s', you must keep at least one profile",

            restoreProfile = "Restore defaults",
            restoreProfileHover = "Restores current profile '%s' to default settings.",
            restoreProfileOk = "Profile '%s' has been restored to default settings, click '%s' to confirm",

            activeProfile = "Active profile: %s",

            welcomeMessage = "Welcome to Beam DSX configuration windows, here you can manage multiple profiles with each one having individual settings.",

            profileNameEmptyError = "Profile name can't be empty!",
            profileNameInvalidError = "Profile name cannot contain '-' or '+'",
            profileAlreadyExistError = "Profile '%s' already exists!",

            profileCreateOk = "Created profile '%s'",
            profileCreateTitle = "Create new profile",
            profileCreateName = "Please enter the profile name:",
            profileCreateMaxError = "Maximum profiles reached (%d/%d)",
            profileCreateButton1 = "Create",
            profileCreateButton2 = "Cancel",
            profileActive = "Profile '%s' is now active",
            profileVehicleIsInAnotherProfile = "Vehicle '%s' is already in another profile!",

            changeLanguage = "?",
            changeLanguageHover = "Click to switch between different languages.",

            switchProfile = "Switched to profile '%s'",
            autoSwitchProfile = "Automatically switched to profile '%s'",

            settingsTitle = "Beam DSX settings",
            settingsHover = "Beam DSX settings",
            settingsDSXNetwork = "Network Settings",

            settingsFontSize = "Font Size",
            settingsFontSizePlus = "Font Size +",
            settingsFontSizeMinus = "Font Size -",
            settingsFontCurrentSize = "Current font size: %s (px)",
            settingsFontSizeReset = "Reset",

            settingsControllerIndexTitle = "Controller Index",
            settingsControllerIndexText = "Select the active controller by typing it's index number (0 - 8)",
            settingsControllerIndexInvalid = "Invalid controller index or controller is disconnected",
            settingsControllerIndexSave = "Controller index saved",

            settingsNetworkRestore = "Reset",
            settingsNetworkIP = "IP",
            settingsNetworkPort = "Port",
            settingsNetworkInvalidIp = "Invalid IP address!",
            settingsNetworkInvalidPort = "Invalid port!",
            settingsNetworkSave = "Network settings saved",

            settingsStatusTitle = "Status",
            settingsStatusEnabled = "Enabled",
            settingsStatusDisabled = "Disabled",
            settingsStatusConnected = "Connected",
            settingsStatusDisconnected = "Disconnected",
            settingsStatusControllerText1 = "Controller:",
            settingsStatusControllerText2 = "%s -> Index %s",
            settingsStatusControllerUnknown = "Unknown",
            settingsStatusCharge = "Charge: %s%%",
            settingsStatusMacAddress = "Mac Address: %s",
            settingsStatusTime = "Time: %s",

        },
    },
}