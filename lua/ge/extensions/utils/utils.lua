-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local function getVehicleName(vehID)
	local vehicle = be:getObjectByID(vehID or be:getPlayerVehicleID(0))

    if vehicle then
        return vehicle:getJBeamFilename() or "Unknown"
    end

    return "Unknown"
end

local function deep_copy_safe(t, skip)
    skip = skip and skip or ""
    if(type(t) == "table") then
        local copy = {}
        for key, value in pairs(t) do
            if(type(value) ~= "function" and key ~= skip) then
                copy[key] = (type(value) == "table") and deep_copy_safe(value) or value
            end
        end
        return copy
    end
    return false
end

local function get_path(path)
    local s = jsonReadFile(path)
    return s and s.path or path
end

function dumpex(t)
    if(type(t) == "userdata") then
        local meta = getmetatable(t)
        if meta then
            for k, v in pairs(meta) do
                print(k, v)
            end
        end
        return
    elseif(type(t) ~= "table") then
        return print(type(t).. ": " ..tostring(t))
    end

    local f = {}
    local v = {}
    
    for key, value in pairs(t) do 
        value = tostring(value)
        if value:find("function") then 
            table.insert(f, tostring(key).. ": " ..tostring(value)) 
        else 
            table.insert(v, tostring(key).. ": " ..tostring(value)) 
        end
    end 

    print("-- variables: ") 
    table.sort(v)
    for i = 1, #v do 
       print(v[i]) 
    end 
    print("-- total variables: " ..#v)

    print("-- functions:") 
    table.sort(f)
    for i = 1, #f do 
        print(f[i]) 
    end 
    print("-- total functions: " ..#f)
end

return
{
    getVehicleName = getVehicleName,
    dumpex = dumpex,
    deep_copy_safe = deep_copy_safe,
    get_path = get_path,
}