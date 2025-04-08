-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local socket = require("socket")
local common = require("common.common")
local log = common.log

return
{
    udp = nil,
    ip = "127.0.0.1",
    port = 6969,
    lastError = nil,
    -- Functions
    init = function(self, type)
        if(not self:ready()) then
            self.udp = socket.udp()
            log("I", "init", "%s: opening udp socket to '%s:%d'", type, self.ip, self.port)
        end
    end,
    send = function(self, buffer, type)
        if(not self:ready()) then
            return self:init(type)
        end

        local bytes, err = self.udp:sendto(buffer, self.ip, self.port)
        self.lastError = err
    end,
    shutdown = function(self, type)
        if(not self:ready()) then
            return
        end

        self.udp:close()
        self.udp = nil
        log("I", "shutdown", "%s: shutting down udp socket ..", type)
    end,
    ready = function(self) 
        return self.udp 
    end,
    receive = function(self, timeout)
        if(not self:ready())then
            return
        end

        self.udp:settimeout(timeout or 2)
        return self.udp:receivefrom()
    end,
    clear = function(self)  
        if(not self:ready())then
            return
        end

        self.udp:settimeout(0)

        while true do
            local data, err = self.udp:receive(0)
            if not data then
                return
            end
        end
    end,
    set_address = function(self, ip, port, type)
        self.ip = ip
        self.port = port

        log("I", "setUDPAddress", "%s: udp address changed to '%s:%d'", type, ip, port)
    end,
    get_last_error = function(self)
        return self.lastError
    end,
}