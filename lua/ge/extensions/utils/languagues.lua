-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Code author: Feche

local common = require("common.common")
local defaultLanguages = require("ge.extensions.utils.default_languages")

local log = common.log
local defaultPath = "settings/beam_dsx/languages.json"
local forceAlwaysDefaultSettings = true

return
{
    path = defaultPath,
    active = "en",
    langsIndex = {},
    languages = common.deep_copy_safe(defaultLanguages),
    -- Functions
    init = function(self)
        self.path = common.get_path(defaultPath)

        local s = jsonReadFile(self.path)

        if(not s or (type(s) == "table" and not s.path) or forceAlwaysDefaultSettings) then
            jsonWriteFile(self.path, common.deep_copy_safe(self, "langsIndex"), true)
            
            s = jsonReadFile(self.path)

            log("I", "createLangFile", "created default language 'en'")
        end

        self.active = s.active
        self.languages = s.languages

        for key, value in pairs(self.languages) do
            self.langsIndex[#self.langsIndex + 1] = key
        end

        table.sort(self.langsIndex)

        log("I", "createLangFile", "language '%s' loaded (%s)", self.active, self.path)
    end,
    getText = function(self)
        return self.languages[self.active]
    end,
    getLangIndex = function(self)
        for i = 1, #self.langsIndex do
            if(self.langsIndex[i] == self.active) then
                return i
            end
        end

        return 1
    end,
    switchLanguage = function(self)
        local index = self:getLangIndex()
        self.active = self.langsIndex[index + 1] or self.langsIndex[1]

        jsonWriteFile(self.path, common.deep_copy_safe(self, "langsIndex"), true)

        log("I", "switchLanguage", "switched to language '%s'", self.active)
    end,
}   