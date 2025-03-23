return
{
    throttle =
    {
        enable = true,
        rigidity =
        {
            bySpeed =
            {
                enable = true,
                minForce = 10,
                maxForce = 40,
                maxForceAt = 150,
                inverted = false,
            },
            constant =
            {
                enable = false,
                minForce = 20,
                maxForce = 60,
            },
        },
        wheelSlip =
        {
            enable = true,
            tolerance = 5,
            maxForceAt = 45,
            minHz = 25,
            maxHz = 40,
            minAmplitude = 1,
            maxAmplitude = 2,
        },
        upShift =
        {
            enable = true,
            maxHz = 120,
            maxForce = 200,
            timeOn = 32,
        },
        engineOff = 
        {
            enable = true,
        },
        revLimit =
        {
            enable = true,
            minHz = 180,
            maxHz = 220,
            maxForce = 1,
            timeOn = 16,
        },
    },
    brake =
    {
        enable = true,
        rigidity = 
        {
            bySpeed =
            {
                enable = true,
                minForce = 0,
                maxForce = 40,
                maxForceAt = 150,
                inverted = false,
            },
            constant =
            {
                enable = true,
                minForce = 20,
                maxForce = 60,
            },
        },
        abs = 
        {
            enable = true,
            minHz = 10,
            maxHz = 40,
            minAmplitude = 2,
            maxAmplitude = 3,
        },
        wheelMissing =
        {
            enable = true,
            maxForce = 255,
        },
        engineOff = 
        {
            enable = true,
            maxForce = 255,
        },
    },
    lightBar =
    {
        enable = true,
        hazardLights =
        {
            enable = true,
            colorOn = { 255, 165, 0, 255 },
            colorOff = { 0, 0, 0, 0 },
        },
        lowFuel =
        {
            enable = true,
            timeOn = 5000,
            timeOff = 0,
        },
        parkingBrake =
        {
            enable = true,
            timeOn = 250,
            timeOff = 500,
        },
        emergencyBraking =
        {
            enable = true,
            colorOn = { 255, 0, 0, 255 },
            colorOff = { 0, 0, 0, 0 },
            alwaysBlink = false,
        },
        tachometer =
        {
            enable = true,
            colorLow = { 0, 255, 0, 125 },
            colorMed = { 255, 200, 0, 200 },
            colorHi = { 255, 0, 0, 255 },
            offset = 2500,
        },
        esc =
        {
            enable = true,
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