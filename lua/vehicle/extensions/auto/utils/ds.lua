local udp = require("vehicle.extensions.auto.utils.udp")
local settings = require("vehicle.extensions.auto.beam_dsx_settings")
local tick = require("vehicle.extensions.auto.utils.tick")

return
{
    -- Instruction types
    type =
    {
        triggerUpdate = 1,
        rgbUpdate = 2,
        micLed = 5,
        playerLed = 6,
    },
    -- Triggers
    trigger =
    {
        left = 1,
        right = 2,
        rgbUpdate = 3,
        micLed = 4,
        playerLed = 5,
    },
    -- Trigger modes
    mode =
    {
        -- Custom trigger mode
        customTriggerValue = 12,
        custom =
        {
            rigid = 1,
            vibrateResistance = 9,
        },

        off = 20,
        feedback = 21,
        vibration = 23,
        slopeFeedback = 24,

        safeValues =
        {
            customTriggerValue =
            {
                max = 255,
            },
            vibration =
            {
                maxPos = 9,
                maxHz = 40,
                maxAmplitude = 8,
            },
            feedback =
            {
                maxPos = 9,
                maxForce = 8,
            },
            slopeFeedback =
            {
                minPos = 8,
                maxPos = 8,
                minForce = 8,
                maxForce = 8,
            },
        },
    },
    micLed =
    {
        on = 0,
        pulsing = 1,
        off = 2,
    },
    playerLed =
    {
        one = 0,
        two = 1,
        three = 2,
        four = 3,
        five = 4,
        off = 5
    },
    -- Internal usage
    commands = 
    {
        -- left
        {
            priority = 0,
            duration = 0,
            tick = 0,
        },
        -- right
        {
            priority = 0,
            duration = 0,
            tick = 0,
        },
        -- rgbUpdate
        {
            priority = 0,
            duration = 0,
            tick = 0,
            color = { 0, 0, 0, 0 },
        },
        -- micLed
        {
            priority = 0,
            duration = 0,
            tick = 0,
        },
        -- playerLed
        {
            priority = 0,
            duration = 0,
            tick = 0,
        },
        lastCommand = "",
    },
    debug = 
    {
        send = false,
    },
    -- tickRateToMs = tick:tickRateToMs, -- TODO: test
    -- Functions
    sendDsx = function(self, priority, gt, type, ...)
        local args = { ... }
        local trigger = -1
        
        if(type == self.type.triggerUpdate) then
            trigger = args[1]
        elseif(type == self.type.rgbUpdate) then
            trigger = self.trigger.rgbUpdate
        elseif(type == self.type.micLed) then
            trigger = self.trigger.micLed
        elseif(type == self.type.playerLed) then
            trigger = self.trigger.playerLed
        end

        local t = tick:getTick()
        local elapsed = t - self.commands[trigger].tick

        if(elapsed < self.commands[trigger].duration and self.commands[trigger].priority < priority) then
            return
        end

        local buffer = ""
 
        for i = 1, #args do
            buffer = buffer.. "," ..math.floor(args[i])
        end

        buffer = string.format("{\"instructions\":[{\"type\":%d,\"parameters\":[%d%s]}]}", type, settings.contollerIndex, buffer)
            
        self.commands[trigger].priority = priority
        self.commands[trigger].duration = tick:tickRateToMs(gt)
        self.commands[trigger].tick = t
        
        -- do not send repeated data
        if(self.commands[trigger].lastCommand == buffer) then
            --return
        end

        self.commands[trigger].lastCommand = buffer

        -- save current rgb color
        if(trigger == self.trigger.rgbUpdate) then
            for i = 1, 4 do
                self.commands[trigger].color[i] = args[i]
            end
        end

        udp.send(buffer)

        if(self.debug.send == true) then
            self:debugCommand(buffer)
        end
    end,
    resetController = function(self)
        print("[beam_dsx] VE: resetting controller ..")
        self.debug.send = true

        self:sendDsx(0, 0, self.type.triggerUpdate, self.trigger.left, self.mode.off)
        self:sendDsx(0, 0, self.type.triggerUpdate, self.trigger.right, self.mode.off)
        self:sendDsx(0, 0, self.type.rgbUpdate, 0, 0, 0, 0)
        self:sendDsx(0, 0, self.type.playerLed, self.playerLed.off)
        self:sendDsx(0, 0, self.type.micLed, self.micLed.off)

        self.debug.send = false
    end,
    safeValue = function(self, type, subtype)
        if type and subtype and self.mode.safeValues[type] and self.mode.safeValues[type][subtype] then
            return self.mode.safeValues[type][subtype]
        else
            return 0
        end
    end,
    getColor = function(self)
        return self.commands[self.trigger.rgbUpdate].color
    end,
    debugCommand = function(self, buffer)
        local data = jsonDecode(buffer).instructions[1]

        if(data.type) then
            -- triggerUpdate
            if(data.type == self.type.triggerUpdate) then
                local type = "triggerUpdate"
                local mode = ""
                local submode = ""
                local trigger = (data.parameters[2] == self.trigger.left) and "left" or "right"

                mode = data.parameters[3]

                if(mode == self.mode.customTriggerValue) then
                    mode = "customTriggerValue"
                    submode = data.parameters[2]

                    if(submode == self.mode.custom.rigid) then
                        submode = "rigid"
                    elseif(submode == self.mode.custom.vibrateResistance) then
                        submode = "vibrateResistance"
                    end

                    print("[beam_dsx] send: (" ..trigger.. " -> " ..type.. " -> " ..mode.. " -> " ..submode.. ") " ..buffer)
                else
                    if(mode == self.mode.off) then
                        mode = "off"
                    elseif(mode == self.mode.feedback) then
                        mode = "feedback"
                    elseif(mode == self.mode.vibration) then
                        mode = "vibration"
                    elseif(mode == self.mode.slopeFeedback) then
                        mode = "slopeFeedback"
                    end

                    print("[beam_dsx] send: (" ..trigger.. " -> " ..type.. " -> " ..mode.. ") " ..buffer)
                end
            -- rgbUpdate
            elseif(data.type == self.type.rgbUpdate) then
                print("[beam_dsx] send: (rgbUpdate) " ..buffer)
            -- micLed
            elseif(data.type == self.type.micLed) then
                print("[beam_dsx] send: (micLed) " ..buffer)
            -- playerLed
            elseif(data.type == self.type.playerLed) then
                print("[beam_dsx] send: (playerLed) " ..buffer)
            -- unknown
            else
                print("[beam_dsx] send: (unknown) " ..buffer)
            end
        end
    end
}