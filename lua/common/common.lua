-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local _log_ = log

local function getLogType(debugInfo)
    if(string.find(debugInfo.short_src, "lua/ge")) then
        return "GE"
    elseif(string.find(debugInfo.short_src, "lua/vehicle")) then
        return "VE"
    elseif(string.find(debugInfo.short_src, "lua/common")) then
        return "CO"
    end
    return "UNK"
end

local function log(debugType, event, str, ...)
    local type = getLogType(debug.getinfo(2, "Sl"))

	local args = { ... }

    if(type == "CO") then
	    _log_(debugType, event.. "_CO", "[beam_dsx] " ..string.format(str, unpack(args)))
    else
        _log_(debugType, event, "[beam_dsx] " ..type.. ": " ..string.format(str, unpack(args)))
    end
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

local function dumpex(t)
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

local function nonLinearLerp(start, finish, progress, steepness)
    return start + (finish - start) * (progress ^ steepness)
end

local function lerp(a, b, t)
    t = t < 0 and 0 or t
    t = t > 1 and 1 or t
    return a + (b - a) * t
end

local function lerpRgb2(color1, color2, t)
    return 
    { 
        lerp(color1[1], color2[1], t),
        lerp(color1[2], color2[2], t),
        lerp(color1[3], color2[3], t),
        lerp(color1[4], color2[4], t)
    }
end

local function lerpRgb3(color1, color2, color3, t)
    t = t < 0 and 0 or t
    t = t > 1 and 1 or t

    local segment = t * 2
    
    if segment < 1 then
        t = segment

        return {
            lerp(color1[1], color2[1], t),
            lerp(color1[2], color2[2], t),
            lerp(color1[3], color2[3], t),
            lerp(color1[4], color2[4], t)
        }
    else
        t = segment - 1

        return {
            lerp(color2[1], color3[1], t),
            lerp(color2[2], color3[2], t),
            lerp(color2[3], color3[3], t),
            lerp(color2[4], color3[4], t)
        }
    end
end

local function bounceLerp(t, bounces)
    t = t < 0 and 0 or t
    t = t > 1 and 1 or t
    return math.abs(math.sin(t * math.pi * bounces))
end

local function hexToRGB(hex)
    if(hex == nil) then
        return false
    end

    hex = hex:gsub("#", "")
    return { tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16) }
end

local inspectLast = nil
local inspectTick = 0

local function inspect(table, speed)
    if(not table) then
        return
    end

    if(type(table) ~= "table") then
        return print(tostring(table))
    end

    local t = tick:getTick()
    
    if((t - inspectTick) >= (speed or 1000)) then
        inspectTick = t

        if(not inspectLast) then
            inspectLast = deep_copy_safe(table)
            return
        end

        print(" ")

        local changes = 0

        for key, value in pairs(table) do
            if(type(value) ~= "table" and value ~= inspectLast[key]) then
                changes = changes + 1

                print(key.. " changed its value from '" ..tostring(inspectLast[key]).. "' to '" ..tostring(value).. "'")
            end
        end

        print("-- " ..changes.. " changes ocurred in the last " ..speed.. " ms.")

        inspectLast = deep_copy_safe(table)
    end
end

local function table_merge(dest, source)
    if(type(dest) == "table" and type(source) == "table") then
        for key, value in pairs(source) do
            if(type(value) == "table") then
                if(type(dest[key]) ~= "table") then
                    dest[key] = {}
                end
                table_merge(dest[key], value)
            else
                dest[key] = value
            end
        end
    end
end

return
{
	log = log,
    deep_copy_safe = deep_copy_safe,
    get_path = get_path,
    table_merge = table_merge,
    inspect = inspect,
    dumpex = dumpex,
    
    lerpNonLineal = lerpNonLineal,
    lerp = lerp,
    lerpRgb2 = lerpRgb2,
    lerpRgb3 = lerpRgb3,
    bounceLerp = bounceLerp,
    hexToRGB = hexToRGB,
    getLogType = getLogType,
}