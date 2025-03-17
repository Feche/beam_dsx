-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local socket = require("socket")
local udp = nil

local ip = "127.0.0.1"
local port = 6969

return
{
    startUdp = function()
        udp = socket.udp()

        if(udp) then
            --print("[beam_dsx] VE: udp socket ready - sending data to '" ..ip.. ":" ..port.. "'")
        else
            print("[beam_dsx] VE: udp socket error. (" ..tostring(udp).. ")")
        end
    end,
    send = function(buffer)
        if(udp == nil) then
            return
        end

        udp:sendto(buffer, ip, port)
    end,
    shutdown = function()
        udp:close()
        print("[beam_dsx] VE: shutting down udp socket ..")
    end,
    ready = function() 
        return udp 
    end
}