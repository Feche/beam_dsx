-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local common = require("common.common")
local log = common.log

return
{
    data = {},
    load = function(self)
        if(not v or not v.data or not v.data.controller) then
            return
        end

        local tmp = {}
        for i = 0, #v.data.controller do
            local fileName = v.data.controller[i].fileName
            if(fileName) then
                tmp[fileName] = common.deep_copy_safe(v.data.controller[i])
            end
        end

        self.data = common.deep_copy_safe(tmp)
        log("I", "controllers.load", "%d vehicle controllers loaded", #v.data.controller)
    end,
    getControllerData = function(self, controllerName)
        return self.data[controllerName]
    end,
    getAllControllers = function(self)
        return self.data
    end,
}