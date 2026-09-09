-- Core/Init.lua
local ADDON_NAME = "Nebbinator"

Nebbinator = {}
local NB = Nebbinator

-- Saved variables defaults
local defaults = {
    previewMode = false,
    needs = {
        -- Format: [class][spec] = count
        shaman = { ele = 0, resto = 0, enh = 0 },
        warrior = { prot = 0, dps = 0 },
        priest = { holy = 0, shadow = 0 },
        druid = { resto = 0, boomie = 0, feral = 0, tank = 0 },
        warlock = { dps = 0 },
        mage = { dps = 0 },
        hunter = { dps = 0 },
        paladin = { prot = 0, holy = 0, ret = 0 },
        rogue = { dps = 0 },
    },
    raidTimes = {
        monday = "",
        tuesday = "",
        wednesday = "",
        thursday = "",
        friday = "",
        saturday = "",
        sunday = "",
    },
    preText = "",
    postText = "",
    responders = {},
}

-- Event frame
local frame = CreateFrame("Frame")

function NB:Initialize()
    if not NubbinatorDB then
        NubbinatorDB = {}
    end
    
    -- Deep copy defaults
    for k, v in pairs(defaults) do
        if NubbinatorDB[k] == nil then
            if type(v) == "table" then
                NubbinatorDB[k] = {}
                for k2, v2 in pairs(v) do
                    if type(v2) == "table" then
                        NubbinatorDB[k][k2] = {}
                        for k3, v3 in pairs(v2) do
                            NubbinatorDB[k][k2][k3] = v3
                        end
                    else
                        NubbinatorDB[k][k2] = v2
                    end
                end
            else
                NubbinatorDB[k] = v
            end
        end
    end
    
    self.db = NubbinatorDB
    
    -- Initialize modules
    if self.MainWindow then
        self.MainWindow:Initialize()
    end
    
    if self.RespondersWindow then
        self.RespondersWindow:Initialize()
    end
    
    print("|cFFFFD700Nebbinator|r loaded. Type |cFF00FF00/ns|r to open")
end

-- Slash commands
SLASH_NEBBINATOR1 = "/nebbinator"
SLASH_NEBBINATOR2 = "/ns"
SlashCmdList["NEBBINATOR"] = function(msg)
    if msg == "responders" or msg == "r" then
        if NB.RespondersWindow then
            NB.RespondersWindow:Toggle()
        end
    else
        if NB.MainWindow then
            NB.MainWindow:Toggle()
        end
    end
end

-- Events
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            NB:Initialize()
        end
    end
end)
