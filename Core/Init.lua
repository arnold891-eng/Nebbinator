-- Nebbinator - Core/Init.lua
-- Namespace, saved variables, migration, slash commands, boot.

local ADDON, NS = ...
local T = NS.T
_G.Nebbinator = NS

NS.ADDON_NAME    = ADDON
-- One version, in the TOC. Keeping the number in two places is how the header
-- spent v3 announcing itself as 2.0.1.
NS.VERSION       = (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "dev"
NS.DB_VERSION    = 3
NS.CHAT_LIMIT    = 255

--------------------------------------------------------------------
-- Defaults
--------------------------------------------------------------------

local function BuildNeedsDefaults()
    local t = {}
    for _, class in ipairs(NS.CLASSES) do
        t[class.key] = {}
        for _, spec in ipairs(class.specs) do
            t[class.key][spec.key] = 0
        end
    end
    return t
end

local function BuildTimesDefaults()
    local t = {}
    for _, day in ipairs(NS.DAYS) do t[day.key] = "" end
    return t
end

NS.DEFAULT_TEMPLATES = {
    {
        name = "Standard",
        text = "<{guild}> is recruiting {needs} for {content}. Raids {times}. Whisper me or join our Discord: {discord}",
    },
    {
        name = "Short",
        text = "<{guild}> recruiting: {needs}. {times}. Whisper for info!",
    },
    {
        name = "Roles only",
        text = "<{guild}> is looking for {tanks} tanks, {healers} healers and {dps} dps for {content}. Raids {times}. Discord: {discord}",
    },
}

NS.DEFAULT_KEYWORDS = "recruit,recruiting,guild,raid,raiding,invite,inv,join,spot,discord,info,interested,apply,application"

local function Defaults()
    return {
        dbVersion   = NS.DB_VERSION,
        needs       = BuildNeedsDefaults(),
        raidTimes   = BuildTimesDefaults(),
        templates   = NS.Util.CopyTable(NS.DEFAULT_TEMPLATES),
        activeTemplate = 1,

        guildName   = "",          -- blank = use the guild you are actually in
        discord     = "",
        content     = "raids",
        preText     = "",
        postText    = "",

        customEnabled = false,     -- ignore the template, send customText verbatim
        customText    = "",

        previewMode  = false,      -- print instead of send, for testing
        sendCooldown = 10,         -- seconds between manual broadcasts
        customChannels = "",       -- extra channel names, comma separated

        autoReply = {
            enabled     = false,
            mode        = "keywords",   -- "keywords" | "any"
            keywords    = NS.DEFAULT_KEYWORDS,
            text        = "Thanks for the interest in <{guild}>! We raid {times}. Everything you need is in our Discord: {discord}",
            cooldown    = 900,          -- per player, seconds
            maxPerMinute = 6,           -- hard spam brake
            skipGuildies = true,
            playSound   = true,
            sound       = "bell",       -- deliberately not the ready-check sound
            soundOnlyNew = false,       -- false = ding on every message, not just first contact
        },

        -- Four canned whispers, one button each on every responder row.
        quickReplies = {
            { label = "Raid times", text = "Raid times work?" },
            { label = "Enchants",   text = "We expect raiders to consume and enchant their gear. Greens n Blues shouldnt be a thing this late in phase" },
            { label = "Loot",       text = "We use LC for loot and raiders need RCLC to get loot. We use a mix of Officers and Raiders" },
            { label = "Signups",    text = "Sign ups are a must. If you cant make it no worries but ALWAYS sign up" },
        },

        -- {name} is the responder; {realm} and {region} fill themselves in.
        logsUrl = "https://fresh.warcraftlogs.com/character/us/dreamscythe/{name}",

        leadFinder = false,        -- watch channels for "LF guild" posts
        responders = {},
        minimap    = { hide = false, angle = 205 },
        window     = {},
        uiTab      = "Recruit",
        bookOpen   = false,        -- the tab rail is rolled up until asked for
        filter     = "all",
        hiddenChannels = {},       -- send buttons right-clicked off the desk
    }
end

--------------------------------------------------------------------
-- Migration from the 1.x saved variables
--------------------------------------------------------------------

local V1_SPEC_MAP = {
    warrior = { prot = "prot",  dps = "fury"  },
    paladin = { prot = "prot",  holy = "holy", ret = "ret" },
    priest  = { holy = "holy",  shadow = "shadow" },
    shaman  = { ele = "ele",    resto = "resto", enh = "enh" },
    druid   = { resto = "resto", boomie = "balance", tank = "feral", feral = "cat" },
    mage    = { dps = "dps" },
    warlock = { dps = "dps" },
    hunter  = { dps = "dps" },
    rogue   = { dps = "dps" },
}

local function MigrateV1(old)
    local new = Defaults()
    if type(old) ~= "table" then return new end

    if type(old.needs) == "table" then
        for classKey, specs in pairs(old.needs) do
            local map = V1_SPEC_MAP[classKey]
            if map and type(specs) == "table" then
                for oldSpec, count in pairs(specs) do
                    local newSpec = map[oldSpec]
                    if newSpec and new.needs[classKey] and type(count) == "number" then
                        new.needs[classKey][newSpec] = count
                    end
                end
            end
        end
    end

    if type(old.raidTimes) == "table" then
        for dayKey, value in pairs(old.raidTimes) do
            if new.raidTimes[dayKey] ~= nil and type(value) == "string" then
                new.raidTimes[dayKey] = value
            end
        end
    end

    new.preText     = type(old.preText) == "string" and old.preText or ""
    new.postText    = type(old.postText) == "string" and old.postText or ""
    new.previewMode = old.previewMode and true or false
    new.responders  = type(old.responders) == "table" and old.responders or {}

    -- Rebuild the 1.x message shape as a template so nothing is lost.
    if new.preText ~= "" or new.postText ~= "" then
        local parts = {}
        if new.preText ~= ""  then table.insert(parts, "{pre}")  end
        table.insert(parts, "{needs}")
        table.insert(parts, "Raid Times: {times}")
        if new.postText ~= "" then table.insert(parts, "{post}") end
        table.insert(new.templates, 1, { name = "Migrated (v1)", text = table.concat(parts, " - ") })
        new.activeTemplate = 1
    end

    return new
end

--------------------------------------------------------------------
-- Boot
--------------------------------------------------------------------

function NS:LoadDB()
    -- 1.x shipped as NubbinatorDB; keep reading it so upgrades are seamless.
    local saved = _G.NebbinatorDB or _G.NubbinatorDB

    if type(saved) ~= "table" or next(saved) == nil then
        saved = Defaults()
    elseif (saved.dbVersion or 1) < 2 then
        saved = MigrateV1(saved)
        NS.migratedThisSession = true
    elseif (saved.dbVersion or 1) < NS.DB_VERSION then
        -- v2 -> v3 only added keys; ApplyDefaults fills them in
        saved = NS.Util.ApplyDefaults(saved, Defaults())
        saved.windows = nil
    else
        saved = NS.Util.ApplyDefaults(saved, Defaults())
    end

    saved.dbVersion = NS.DB_VERSION
    _G.NebbinatorDB = saved
    self.db = saved

    -- Normalise responder records written by older builds.
    for name, data in pairs(self.db.responders) do
        if type(data) ~= "table" then
            self.db.responders[name] = nil
        else
            data.name      = data.name or name
            data.status    = data.status or "new"
            data.messages  = data.messages or { { text = data.message or "", at = data.timestamp or time() } }
            data.timestamp = data.timestamp or time()
            data.note      = data.note or ""
            data.message   = nil
        end
    end
end

--------------------------------------------------------------------
-- The toggles. A slash command and a checkbox must never be two
-- different ways of writing the same key, so both land here.
--------------------------------------------------------------------

function NS.TogglePreview()
    NS.db.previewMode = not NS.db.previewMode
    NS.Util.Print("Preview mode " .. (NS.db.previewMode
        and NS.T.text("warn", "ON") .. " - nothing is really sent"
        or NS.T.text("good", "OFF") .. " - messages go live"))
    NS.UI:Refresh()
end

function NS.ToggleAutoReply()
    NS.db.autoReply.enabled = not NS.db.autoReply.enabled
    NS.Util.Print("Auto-reply " .. (NS.db.autoReply.enabled
        and NS.T.text("good", "ON") or NS.T.text("warn", "OFF")))
    NS.UI:Refresh()
end

function NS.SetDiscord(link)
    NS.db.discord = NS.Util.Trim(link)
    NS.UI:Refresh()
end

function NS.ToggleMinimap()
    NS.db.minimap.hide = not NS.db.minimap.hide
    NS.Minimap:Update()
    NS.UI:Refresh()
end

function NS.ResetWindow()
    NS.db.window = {}
    if NS.UI.frame then
        NS.UI.frame:ClearAllPoints()
        NS.UI.frame:SetPoint("CENTER")
    end
    NS.Util.Print("window put back in the middle.")
end

--------------------------------------------------------------------
-- The shared BiS channel (Libs/LibBiSComm-1.0, embedded from _bisdev).
--
-- It is NOT a Nebbinator feature and no setting here may gate it: just having
-- this addon installed makes the client answer WHERE and SUM for any BiS
-- summoner in the raid, which is the whole point of "one addon gets you half
-- way". Only /bis off mutes it. The lib has no SavedVariables of its own, so
-- that off switch is remembered here and restored next login.
--------------------------------------------------------------------

NS.Comm = {}

function NS.Comm.Lib() return _G.LibBiSComm end

function NS.Comm.Boot()
    local lib = _G.LibBiSComm
    if not lib then return end
    lib:RegisterAddon(ADDON, NS.VERSION)
    if NS.db and NS.db.comm == false then lib:SetEnabled(false) end
    lib:Boot()
end

function NS.Comm.Save()
    local lib = _G.LibBiSComm
    if lib and NS.db then NS.db.comm = lib:Enabled() and true or false end
end

function NS:Initialize()
    self:LoadDB()

    NS.Message:Initialize()
    NS.Responders:Initialize()
    NS.Comm.Boot()
    NS.UI:Initialize()
    NS.Minimap:Initialize()

    -- the window says hello in its own prompt; chat only speaks when the
    -- upgrade actually moved somebody's settings
    if NS.migratedThisSession then
        NS.Util.Print("upgraded your old settings - needs, raid times and responders were kept.")
    end
    NS.Say("ready", "good")
end

--------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------

local function HandleSlash(msg)
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "" or cmd == "show" then
        NS.UI:Toggle()
    elseif cmd == "r" or cmd == "responders" then
        NS.UI:Toggle()
    elseif cmd == "config" or cmd == "options" or cmd == "settings" then
        NS.UI:Open("Settings")
    elseif cmd == "book" then
        NS.UI:Open()
        NS.UI:ToggleBook()
    elseif cmd == "preview" or cmd == "test" then
        NS.TogglePreview()
    elseif cmd == "reply" then
        NS.ToggleAutoReply()
    elseif cmd == "discord" then
        if rest ~= "" then
            NS.SetDiscord(rest)
            NS.Util.Print("Discord link set to " .. NS.db.discord)
        else
            NS.Util.Print("Discord link: " .. (NS.db.discord ~= "" and NS.db.discord
                or NS.T.text("warn", "not set")))
        end
    elseif cmd == "minimap" then
        NS.ToggleMinimap()
        NS.Util.Print("Minimap button " .. (NS.db.minimap.hide and "hidden" or "shown"))
    elseif cmd == "reset" then
        NS.ResetWindow()
    else
        NS.Util.Print("commands:")
        print("  " .. NS.T.text("accent", "/nb") .. " - open the window")
        print("  " .. NS.T.text("accent", "/nb book") .. " - roll the rest of it out")
        print("  " .. NS.T.text("accent", "/nb config") .. " - open it on Settings")
        print("  " .. NS.T.text("accent", "/nb preview") .. " - toggle preview (test) mode")
        print("  " .. NS.T.text("accent", "/nb reply") .. " - toggle auto-reply")
        print("  " .. NS.T.text("accent", "/nb discord <link>") .. " - set the Discord invite")
        print("  " .. NS.T.text("accent", "/nb minimap") .. " - show or hide the minimap button")
        print("  " .. NS.T.text("accent", "/nb reset") .. " - put the window back")
    end
end

SLASH_NEBBINATOR1 = "/nebbinator"
SLASH_NEBBINATOR2 = "/nb"
SLASH_NEBBINATOR3 = "/ns"
SlashCmdList["NEBBINATOR"] = HandleSlash

--------------------------------------------------------------------
-- Events
--------------------------------------------------------------------

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_LOGOUT")
boot:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        NS.loadedVars = true
    elseif event == "PLAYER_LOGIN" then
        NS:Initialize()
    elseif event == "PLAYER_LOGOUT" then
        -- the lib has no SavedVariables; its off switch is ours to remember
        NS.Comm.Save()
    end
end)
