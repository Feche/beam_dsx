return
{
    dsxIp = "127.0.0.1",
    dsxPort = 6969,

    contollerIndex = 0,

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
                minForce = 20, -- byte -- position at where force starts to apply, default: 1, max: 255
                maxForce = 40, -- byte -- maximum force of the throttle when the trigger reaches the end, default: 10, max: 255
            },
        },
        wheelslip =
        {
            enable = true,
            tolerance = 5, -- lower tolerances triggers slip earlier, default: 5, max: 1000
            maxForceAt = 45, -- int -- at this value the vibration will be at max force, default: 45, max: 1000
            minHz = 40, -- hz -- minimum frequency at which the triggers vibrates, default: 40, max: 255
            maxHz = 150, -- hz -- maximum frequency at which the triggers vibrates, default: 150, max: 255
            minAmplitude = 1, -- minimum amplitude of the vibration, higher numbers increase vibration strenght, default: 1, max: 8
            maxAmplitude = 2, -- maximum amplitude of the vibration, higher numbers increase vibration strenght, default: 3, max: 8
        },
        gear =
        {
            enable = true,
            hz = 120, -- hz -- frequency at which the triggers vibrates, default: 120, max: 255
            maxForce = 100, -- hz -- higher numbers will make the shift vibration stronger, default: 100, max: 255
            duration = 100, -- ms -- duration of the vibration when upshifting, default: 100, max: 1000
        },
        engineOff = 
        {
            enable = true, -- bool -- if enabled, throttle trigger force will turn off when engine is not running
        },
    },
    brake =
    {
        rigidity = 
        {
            enable = true,
            minForce = 0, -- byte -- minimum rigidity for the brake trigger, default: 0, max: 255
            maxForce = 30, -- byte -- maximum rigidity for the brake trigger, default: 30, max: 255
            maxForceAt = 150, -- kmh -- maximum rigidity for the brake trigger at this speed, default: 150
        },
        abs = 
        {
            enable = true,
            minHz = 10, -- hz -- minimum frequency at which the triggers vibrates, default: 10, max: 40
            maxHz = 40, -- hz -- maximum frequency at which the triggers vibrates, default 30, max: 40
            minAmplitude = 2, -- minimum amplitude of the vibration, higher numbers increase vibration strenght, default: 1, max: 8
            maxAmplitude = 4, -- maximum amplitude of the vibration, higher numbers increase vibration strenght, default: 2, max: 8
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
        enable = true, -- bool - disables all led functionality, led enters in stand by mode
        standbyColor = { 255, 255, 255, 100 }, -- rgb -- rgb color when rgb is disabled (stand by)

        hazardLights =
        {
            enable = true,
            colorOn = { 255, 165, 0, 255 }, -- color -- RGBA color of the led when hazards are ON, default: 255, 165, 0, 255
            colorOff = { 0, 0, 0, 0 }, -- color -- RGBA color of the led when hazards are ON, default: 0, 0, 0, 0
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
            timeOn = 500, -- ms -- amount of time the led is ON, default: 500
            timeOff = 200, -- ms -- amount of time the led is OFF, default: 125
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
            colorLow = { 0, 0, 0, 0 },
            colorMed = { 255, 204, 0, 255 },
            colorHi = { 255, 0, 0, 255 }
        }
    },
}