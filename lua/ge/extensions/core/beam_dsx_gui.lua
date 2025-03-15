local ffi = require("ffi")

local im = ui_imgui
local show = true
local setting = nil
local color = ffi.new("float[4]", { 1, 0, 0, 1 })
local showColorPicker = false

local settings =
{
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
                minForceAt = 150, -- kmh -- speed at where force is at minimum, going faster will make the throttle force softer, default: 150, max: 1000
                inverted = false, -- bool -- if set to true, it will work in inverse mode, default: false
            },
            -- if this is enabled, then the trigger will get softer/stiffer depending on how much you press the throttle, default configs makes the throttle stronger when reaching the end while pressed
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
            }
        },
        abs = 
        {
            enable = true,
            minHz = 20, -- hz -- minimum frequency at which the trigger will vibrate, default: 20, max: 40
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
    rgb =
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
        parkingbrake =
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
            color = { 255, 255, 255, 255 },
        }
    },
}

local function onExtensionLoaded()
	print("[beam_dsx] GE: extension loaded")
end

local function onExtensionUnloaded()
	print("[beam_dsx] GE: extension unloaded")
end

local function onVehicleResetted(vehId)
	print("[beam_dsx] GE: vehicle reset")
end

local function dsxSettings()
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
                    im.Text("Enable or disable trigger rigidity based on current vehicle speed.")
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()

                    -- minForce
                    im.Text("Minimum force:")

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text("Changes minimum force of the trigger when vehicle is at target speed.")
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
                        im.Text("Changes maximum force of the trigger when vehicle is at target speed.")
                        im.EndTooltip()
                    end

                    im.PushItemWidth(128)

                    local maxForce = im.FloatPtr(setting.maxForce)

                    if im.SliderFloat("##2", maxForce, 0, 255, "%.0f") then
                        setting.maxForce = maxForce[0]
                    end

                    -- minForceAt
                    if(setting.inverted == false) then
                        im.Text("Minimum force at:")
                    else
                        im.Text("Maximum force at:")
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()

                        if(setting.inverted == false) then
                            im.Text("Speed at which the trigger force is at its minimum.")
                        else
                            im.Text("Speed at which the trigger force is at its maximum.")
                        end

                        im.EndTooltip()
                    end

                    im.PushItemWidth(128)

                    local minForceAt = im.FloatPtr(setting.minForceAt)

                    if im.SliderFloat("km/h##3", minForceAt, 0, 1000, "%.0f") then
                        setting.minForceAt = minForceAt[0]
                    end

                    -- Inverted
                    local inverted = im.BoolPtr(setting.inverted)

                    if im.Checkbox("Use maximum speed instead of minimum", inverted) then
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
                    im.Text("Enable or disable trigger rigidity based on two interpolated values.")
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()

                    -- minForce
                    im.Text("Minimum force:")

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text("Minimum force of the trigger when trigger position is at 0%%.")
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
                        im.Text("Maximum force of the trigger when trigger position is at 100%%.")
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
                im.Text("Enable or disable trigger vibration during wheelslip.")
                im.EndTooltip()
            end

            if(setting.enable == true) then
                im.Separator()

                -- tolerance
                im.Text("Tolerance:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Lower tolerances triggers slip earlier.")
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
                    im.Text("At this value the trigger vibration will be at maximum force.")
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
                    im.Text("Minimum frequency at which the triggers vibrates.")
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
                    im.Text("Maximum frequency at which the triggers vibrates.")
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
                    im.Text("Minimum amplitude of the vibration, lower numbers decrease vibration strenght.")
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
                    im.Text("Maximum amplitude of the vibration, higher numbers increase vibration strenght.")
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
                im.Text("Enable or disable trigger vibration during upshift.")
                im.EndTooltip()
            end

            if(setting.enable) then
                im.Separator()

                -- maxHz 
                im.Text("Maximum hz:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Maximum frequency at which the triggers vibrates.")
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
                    im.Text("Maximum force of the trigger.")
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
                    im.Text("Duration of the vibration when up shifting, in milliseconds.")
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
                im.Text("Enable or disable trigger vibration during engine red line.")
                im.EndTooltip()
            end

            if(setting.enable == true) then
                im.Separator()

                -- minHz 
                im.Text("Minimum hz:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Minimum frequency at which the triggers vibrates.")
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
                    im.Text("Maximum frequency at which the triggers vibrates.")
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
                    im.Text("Maximum force of the trigger.")
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
                    im.Text("Duration of the vibration when rev limiting, in milliseconds.")
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

        im.TreePop()
        im.Separator()

        -- Engine off
        setting = settings.throttle.engineOff

        local enable = im.BoolPtr(setting.enable)

        if im.Checkbox("Throttle trigger force will be disabled when the engine is off.", enable) then
            setting.enable = enable[0]
        end
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

                    -- if(settings.throttle.rigidity.constant.enable == true) then
                        --settings.throttle.rigidity.constant.enable = false
                    -- end
                end

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Enable or disable trigger rigidity based on current vehicle speed.")
                    im.EndTooltip()
                end

                if(setting.enable == true) then
                    im.Separator()

                    -- minForce
                    im.Text("Minimum force:")

                    if im.IsItemHovered() then
                        im.BeginTooltip()
                        im.Text("Changes minimum force of the trigger when vehicle is at target speed.")
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
                        im.Text("Changes maximum force of the trigger when vehicle is at target speed.")
                        im.EndTooltip()
                    end

                    im.PushItemWidth(128)

                    local maxForce = im.FloatPtr(setting.maxForce)

                    if im.SliderFloat("##16", maxForce, 0, 255, "%.0f") then
                        setting.maxForce = maxForce[0]
                    end

                    -- maxForceAt 
                    if(setting.inverted == false) then
                        im.Text("Minimum force at:")
                    else
                        im.Text("Maximum force at:")
                    end

                    if im.IsItemHovered() then
                        im.BeginTooltip()

                        if(setting.inverted == false) then
                            im.Text("Speed at which the trigger force is at its minimum.")
                        else
                            im.Text("Speed at which the trigger force is at its maximum.")
                        end

                        im.EndTooltip()
                    end

                    im.PushItemWidth(128)

                    local maxForceAt  = im.FloatPtr(setting.maxForceAt )

                    if im.SliderFloat("km/h##17", maxForceAt , 0, 1000, "%.0f") then
                        setting.maxForceAt  = maxForceAt[0]
                    end

                    -- Inverted
                    local inverted = im.BoolPtr(setting.inverted)

                    if im.Checkbox("Use maximum speed instead of minimum", inverted) then
                        setting.inverted = inverted[0]
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
                im.Text("Enable or disable trigger vibration while ABS is active.")
                im.EndTooltip()
            end

            if(setting.enable == true) then
                im.Separator()

                -- minHz 
                im.Text("Minimum hz:")

                if im.IsItemHovered() then
                    im.BeginTooltip()
                    im.Text("Minimum frequency at which the triggers vibrates.")
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
                    im.Text("Maximum frequency at which the triggers vibrates.")
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
                    im.Text("Minimum amplitude of the vibration, lower numbers decrease vibration strenght.")
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
                    im.Text("Maximum amplitude of the vibration, higher numbers increase vibration strenght.")
                    im.EndTooltip()
                end

                im.PushItemWidth(128)

                local maxAmplitude = im.FloatPtr(setting.maxAmplitude)

                if im.SliderFloat("##21", maxAmplitude, 1, 8, "%.0f") then
                    setting.maxAmplitude = maxAmplitude[0]
                end

                im.Separator()
            end

            im.TreePop()
        end

        im.Separator()

        -- Engine off
        setting = settings.brake.engineOff

        local enable = im.BoolPtr(setting.enable)

        if im.Checkbox("Brake trigger force will be at maximum when the engine is off.", enable) then
            setting.enable = enable[0]
        end

        -- Wheel missing
        setting = settings.brake.wheelMissing

        local enable = im.BoolPtr(setting.enable)

        if im.Checkbox("Brake trigger force will be at maximum when a wheel is missing.", enable) then
            setting.enable = enable[0]
        end

        im.TreePop()
    end
   
    im.Separator()

    showColorPicker = false

    -- RGB and leds
    if im.TreeNode1("RGB and leds") then
        -- Hazard lights
        setting = settings.rgb.hazardLights

        if im.TreeNode1("Hazard lights") then
            local enable = im.BoolPtr(setting.enable)

            if im.Checkbox("Enable", enable) then
                setting.enable = enable[0]
            end

            if im.IsItemHovered() then
                im.BeginTooltip()
                im.Text("Enable or disable led flashing while hazards are active.")
                im.EndTooltip()
            end

            if(setting.enable == true) then
                im.Separator()

                --showColorPicker = true

                local r, g, b

                -- colorOn
                im.Text("Color while on:")

                r = im.FloatPtr(setting.colorOn[1])

                if im.SliderFloat("R##22", r, 0, 255, "%.0f") then
                    setting.colorOn[1] = r[0]
                end

                g = im.FloatPtr(setting.colorOn[2])

                if im.SliderFloat("G##23", g, 0, 255, "%.0f") then
                    setting.colorOn[2] = g[0]
                end

                b = im.FloatPtr(setting.colorOn[3])

                if im.SliderFloat("B##24", b, 0, 255, "%.0f") then
                    setting.colorOn[3] = b[0]
                end

                -- colorOff
                im.Text("Color while off:")

                r = im.FloatPtr(setting.colorOff[1])

                if im.SliderFloat("R##25", r, 0, 255, "%.0f") then
                    setting.colorOff[1] = r[0]
                end

                g = im.FloatPtr(setting.colorOff[2])

                if im.SliderFloat("G##26", g, 0, 255, "%.0f") then
                    setting.colorOff[2] = g[0]
                end

                b = im.FloatPtr(setting.colorOff[3])

                if im.SliderFloat("B##27", b, 0, 255, "%.0f") then
                    setting.colorOff[3] = b[0]
                end
            end
        end
    end
end

local function colorPicker()
    im.TextColored(im.ImVec4(1, 1, 1, 0.6), "Color picker:")
    im.Separator()

    if(im.ColorPicker4("", color, nil)) then

    end
end

local settingsWidth = 475
local colorPickerWidth = 300
local totalWidth = settingsWidth + colorPickerWidth
local height = 500

local function renderImgui()
    im.SetNextWindowSizeConstraints(im.ImVec2(showColorPicker and totalWidth or settingsWidth, height), im.ImVec2(showColorPicker and totalWidth or settingsWidth, height))
    im.Begin("BeamDSX settings", ui_imgui.BoolPtr(false), im.WindowFlags_AlwaysAutoResize)

    im.TextColored(im.ImVec4(1, 1, 1, 0.6), "Welcome to BeamDSX configuration windows, here you can change\nthe feel of the different haptics provided by the mod created by Feche.")
    im.Separator()

    im.BeginChild1("TriggerSettings", im.ImVec2(settingsWidth, false, im.WindowFlags_ChildWindow))
    dsxSettings()
    im.EndChild()

    if(showColorPicker == true) then
        im.SameLine()

        im.BeginChild1("ColorPicker", im.ImVec2(colorPickerWidth, 0, false, im.WindowFlags_ChildWindow))
        colorPicker()
        im.EndChild()
    end

    im.End()
end

local function dumpTable(table)
    if(type(table) == "table") then
        local f = 0

        for key, value in pairs(table) do
            local isFunction = tostring(value):find("function")

            if(not isFunction) then
                --print("key: " ..tostring(key).. ", value: " ..tostring(value))
            else
                f = f + 1
                print("key: " ..tostring(key).. ", value: " ..tostring(value))
            end
        end

        print("-- " ..f.. " function(s)")
    else
        print("value: " ..tostring(table))
    end
end

local dumped = false

local function onUpdate()
    if(show == true) then
        renderImgui()
    end

    if(dumped == false) then
        dumpTable(ui_imgui)

        dumped = true
    end
end

local function toggle()
    show = not show
end

local M = {}

M.dependencies = {"ui_imgui"}
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onUpdate = onUpdate
M.toggle = toggle
--M.onVehicleResetted = onVehicleResetted

return M