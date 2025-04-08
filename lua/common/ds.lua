-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local udp = require("common.udp")
local tick = require("common.tick")
local common = require("common.common")

local log = common.log
local logType = nil

local dsxDevices = 
{ 
    [0] = "DualSense",
    [3] = "DualShock 4 [v2]",
}

return
{
    status = nil,
    controllerIndex = 0,
    -- Instruction types
    type =
    {
        getDsxStatus = 0,
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
        other = 6,
    },
    -- Trigger modes
    mode =
    {
        gameCube = 1,
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
        -- other (used by: getDsxStatus)
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
    getDsxColor = function(self)
        return self.commands[self.trigger.rgbUpdate].color
    end,
    updateDsxStatus = function(self)
        self.status = nil
        udp:clear()

        -- not sure if there is any better way to do this
        for i = 1, 10 do
            self:sendDsx(-1000, 1, self.type.getDsxStatus)

            local data, ip, port = udp:receive(0)

            if(data) then
                self.status = jsonDecode(data)
            end
        end
    end,
    getDsxStatus = function(self)
        if(self.status) then
            return true
        end
        return false
    end,
    getDsxDeviceType = function(self, index)
        index = index and index or self.controllerIndex
        if(not self.status) then
            return false
        end

        if(not self.status.Devices[index]) then
            return -1
        end

        return dsxDevices[self.status.Devices[index].DeviceType]
    end,
    getDsxBatttery = function(self, index)
        index = index and index or self.controllerIndex
        if(not self.status or not self.status.Devices[index]) then
            return "-"
        end

        return tostring(self.status.Devices[index].BatteryLevel)
    end,
    getDsxMacAddress = function(self, index)
        index = index and index or self.controllerIndex
        if(not self.status or not self.status.Devices[index]) then
            return "-"
        end

        return tostring(self.status.Devices[index].MacAddress)
    end,
    getDsxTime = function(self)
        if(not self.status or not self.status.TimeReceived) then
            return "-"
        end
        
        return string.match(self.status.TimeReceived, "%s(%d+:%d+:%d+)")
    end,
    setUDPAddress = function(self, ip, port, type) 
        udp:set_address(ip, port, type)
    end,
    setControllerIndex = function(self, index, type)
        index = index + 1
        if(self.controllerIndex == index) then
            return
        end

        self.controllerIndex = index
        log("I", "setControllerIndex", "%s: controller index changed to %d", type, index)
    end,
    sendDsx = function(self, priority, gt, type, ...)
        local args = { ... }
        local trigger = -1
        logType = logType and logType or common.getLogType(debug.getinfo(2, "Sl"))
        
        if(type == self.type.triggerUpdate) then
            trigger = args[1]
        elseif(type == self.type.rgbUpdate) then
            trigger = self.trigger.rgbUpdate
        elseif(type == self.type.micLed) then
            trigger = self.trigger.micLed
        elseif(type == self.type.playerLed) then
            trigger = self.trigger.playerLed
        elseif(type == self.type.getDsxStatus) then
            trigger = self.trigger.other
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

        buffer = string.format("{\"instructions\":[{\"type\":%d,\"parameters\":[%s%s]}]}", type, tostring(self.controllerIndex - 1), buffer)
            
        self.commands[trigger].priority = priority
        self.commands[trigger].duration = tick:tickRateToMs(gt)
        self.commands[trigger].tick = t

        -- save current lightBar color
        if(trigger == self.trigger.rgbUpdate) then
            for i = 1, 4 do
                self.commands[trigger].color[i] = args[i]
            end
        end

        udp:send(buffer, logType)

        if(self.debug.send == true) then
            self:debugCommand(buffer, logType)
        end
    end,
    resetController = function(self)
        
        self.debug.send = true

        logType = common.getLogType(debug.getinfo(2, "Sl"))

        log("I", "resetController", "%s: resetting controller %d ..", logType, self.controllerIndex)

        self:sendDsx(0, 0, self.type.triggerUpdate, self.trigger.left, self.mode.off)
        self:sendDsx(0, 0, self.type.triggerUpdate, self.trigger.right, self.mode.off)
        self:sendDsx(0, 0, self.type.rgbUpdate, 0, 0, 0, 0)
        self:sendDsx(0, 0, self.type.playerLed, self.playerLed.off)
        self:sendDsx(0, 0, self.type.micLed, self.micLed.off)

        logType = nil

        self.debug.send = false
    end,
    debugCommand = function(self, buffer, logType)
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

                    log("I", "debugCommand", "%s: send: (%s -> %s -> %s -> %s) %s", logType, trigger, type, mode, submode, buffer)
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

                    log("I", "debugCommand", "%s: send: (%s -> %s -> %s) %s", logType, trigger, type, mode, buffer)
                end
            -- rgbUpdate
            elseif(data.type == self.type.rgbUpdate) then
                log("I", "debugCommand", "%s: send: (rgbUpdate) %s", logType, buffer)
            -- micLed
            elseif(data.type == self.type.micLed) then
                log("I", "debugCommand", "%s: send: (micLed) %s", logType, buffer)
            -- playerLed
            elseif(data.type == self.type.playerLed) then
                log("I", "debugCommand", "%s: send: (playerLed) %s", logType, buffer)
            elseif(data.type == self.type.getDsxStatus) then
                log("I", "debugCommand", "%s: send: (getDsxStatus) %s", logType, buffer)
            -- unknown
            else
                log("I", "debugCommand", "%s: send: (unknown) %s", logType, buffer)
            end
        end
    end,
}