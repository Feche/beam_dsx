-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local udp = require("vehicle.extensions.auto.utils.udp")
local tick = require("vehicle.extensions.auto.utils.tick")

local controllerIndex = 0 -- DualSenseX controller index, default: 0

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
    },
    debug = 
    {
        send = false,
    },
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

        buffer = string.format("{\"instructions\":[{\"type\":%d,\"parameters\":[%d%s]}]}", type, controllerIndex, buffer)
            
        self.commands[trigger].priority = priority
        self.commands[trigger].duration = tick:tickRateToMs(gt)
        self.commands[trigger].tick = t

        -- save current lightBar color
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
        log("I", "resetController", "[beam_dsx] VE: resetting controller ..")
        self.debug.send = true

        self:sendDsx(0, 0, self.type.triggerUpdate, self.trigger.left, self.mode.off)
        self:sendDsx(0, 0, self.type.triggerUpdate, self.trigger.right, self.mode.off)
        self:sendDsx(0, 0, self.type.rgbUpdate, 0, 0, 0, 0)
        self:sendDsx(0, 0, self.type.playerLed, self.playerLed.off)
        self:sendDsx(0, 0, self.type.micLed, self.micLed.off)

        self.debug.send = false
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

                    log("I", "debugCommand", "[beam_dsx] send: (" ..trigger.. " -> " ..type.. " -> " ..mode.. " -> " ..submode.. ") " ..buffer)
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

                    log("I", "debugCommand", "[beam_dsx] send: (" ..trigger.. " -> " ..type.. " -> " ..mode.. ") " ..buffer)
                end
            -- rgbUpdate
            elseif(data.type == self.type.rgbUpdate) then
                log("I", "debugCommand", "[beam_dsx] send: (rgbUpdate) " ..buffer)
            -- micLed
            elseif(data.type == self.type.micLed) then
                log("I", "debugCommand", "[beam_dsx] send: (micLed) " ..buffer)
            -- playerLed
            elseif(data.type == self.type.playerLed) then
                log("I", "debugCommand", "[beam_dsx] send: (playerLed) " ..buffer)
            -- unknown
            else
                log("I", "debugCommand", "[beam_dsx] send: (unknown) " ..buffer)
            end
        end
    end
}