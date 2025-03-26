-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local function deep_copy_safe(t, skip)
    if(type(t) == "table") then
        local copy = {}
        for key, value in pairs(t) do
            if((type(value) == "number" or type(value) == "string" or type(value) == "boolean" or type(value) == "table") and key ~= skip) then
                copy[key] = (type(value) == "table") and deep_copy_safe(value) or value
            end
        end
        return copy
    end
    return nil
end

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
                tmp[fileName] = utils.deep_copy_safe(v.data.controller[i])
            end
        end

        self.data = utils.deep_copy_safe(tmp)
        log("I", "controllers.init", "[beam_dsx] VE: " ..#v.data.controller.. " controllers loaded")
    end,
    getControllerData = function(self, controllerName)
        return self.data[controllerName]
    end,
    getAllControllers = function(self)
        return self.data
    end,
}