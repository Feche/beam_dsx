local settings = require("vehicle.extensions.auto.beam_dsx_settings")
local socket = require("socket")
local udp = nil

return
{
    startUdp = function()
        udp = socket.udp()

        if(udp) then
            print("[beam_dsx] VE: udp socket ready - sending data to '" ..settings.dsxIp.. ":" ..settings.dsxPort.. "'")
        else
            print("[beam_dsx] VE: udp socket error. (" ..tostring(udp).. ")")
        end
    end,
    send = function(buffer)
        if(udp == nil) then
            return
        end

        udp:sendto(buffer, settings.dsxIp, settings.dsxPort)
    end,
    shutdown = function()
        udp:close()
        print("[beam_dsx] VE: shutting down udp socket ..")
    end,
    ready = function() 
        return udp 
    end
}