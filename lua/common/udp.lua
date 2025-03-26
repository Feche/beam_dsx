-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local socket = require("socket")

local ip = "127.0.0.1"
local port = 6969

return
{
    udp = nil,
    init = function(self, type)
        if(not self:ready()) then
            self.udp = socket.udp()
            log("I", "init", "[beam_dsx] " ..type.. ": opening udp socket to '" ..ip.. ":" ..port.. "'")
        end
    end,
    send = function(self, buffer, type)
        if(not self:ready()) then
            return self:init(type)
        end

        self.udp:sendto(buffer, ip, port)
    end,
    shutdown = function(self, type)
        if(not self:ready()) then
            return
        end

        self.udp:close()
        self.udp = nil
        log("I", "shutdown", "[beam_dsx] " ..type.. ": shutting down udp socket ..")
    end,
    ready = function(self) 
        return self.udp 
    end
}