local udp = require("vehicle.extensions.auto.utils.udp")
local settings = require("vehicle.extensions.auto.beam_dsx_settings")
local tick = require("vehicle.extensions.auto.utils.gameTick")

return
{
    -- Instruction types
    type =
    {
        triggerUpdate = 1,
        rgbUpdate = 2,
        micLed = 5,
    },
    -- Triggers
    trigger =
    {
        left = 1,
        right = 2,
        -- not actual DualSenseX codes, used internally
        rgbUpdate = 3,
        micLed = 4,
        both = 255,
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
                maxForce = 255,
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
    -- Internal usage
    commands = 
    {
        {
            priority = 0,
            duration = 0,
            tick = 0,
        },
        {
            priority = 0,
            duration = 0,
            tick = 0,
        },
        {
            priority = 0,
            duration = 0,
            tick = 0,
        },
        {
            priority = 0,
            duration = 0,
            tick = 0,
        },
        lastCommand = ""
    },
    -- Functions
    sendDsx = function(self, priority, duration, type, ...)
        local args = { ... }
        local trigger = -1
        local tick = tick.getTick();

        if(type == self.type.triggerUpdate) then
            trigger = args[1]
        elseif(type == self.type.rgbUpdate) then
            trigger = self.trigger.rgbUpdate
        elseif(type == self.type.micLed) then
            trigger = self.trigger.micLed
        end

        if(trigger == self.trigger.both) then
            self:sendDsx(priority, duration, type, self.trigger.left, mode, ...)
            self:sendDsx(priority, duration, type, self.trigger.right, mode, ...)
        else
            if(self.commands[trigger].priority < priority and tick - self.commands[trigger].tick < self.commands[trigger].duration) then
                return
            end

            local buffer = ""
 
            for i = 1, #args do
                buffer = buffer.. "," ..tostring(args[i])
            end

            buffer = string.format("{\"instructions\":[{\"type\":%d,\"parameters\":[%d%s]}]}", type, settings.contollerIndex, buffer)
            
            if(self.commands[trigger].lastCommand ~= buffer or trigger < 3) then
                self.commands[trigger].priority = priority
                self.commands[trigger].duration = duration
                self.commands[trigger].tick = tick
                self.commands[trigger].lastCommand = buffer

                udp.send(buffer)
                --print("[beam_dsx] sending: '" ..buffer.. "'")
            end
        end
    end,
    resetController = function(self)
        self:sendDsx(0, 0, self.type.triggerUpdate, self.trigger.both, self.mode.off)
        self:sendDsx(0, 0, self.type.micLed, self.micLed.off)
        self:sendDsx(0, 0, self.type.rgbUpdate, 0, 0, 0, 0)

        print("[beam_dsx] VE: resetting controller ..")
    end,
    safeValue = function(self, type, subtype)
        if type and subtype and self.mode.safeValues[type] and self.mode.safeValues[type][subtype] then
            return self.mode.safeValues[type][subtype]
        else
            return -255 -- TODO: try -(0xff)
        end
    end
}