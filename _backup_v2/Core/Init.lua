-- Nebbinator - Core/Init.lua
-- Namespace, saved variables, migration, slash commands, boot.

local ADDON, NS = ...
local T = NS.T
_G.Nebbinator = NS

NS.ADDON_NAME    = ADDON
NS.VERSION       = "2.0.1"
NS.DB_VERSION    = 2
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
        windows    = {},
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
    elseif (saved.dbVersion or 1) < NS.DB_VERSION then
        saved = MigrateV1(saved)
        NS.migratedThisSession = true
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

function NS:Initialize()
    self:LoadDB()

    NS.Message:Initialize()
    NS.Responders:Initialize()
    NS.MainWindow:Initialize()
    NS.RespondersWindow:Initialize()
    NS.Minimap:Initialize()

    NS.Util.Print("v" .. NS.VERSION .. " loaded. " .. T.text("accent", "/nb") .. " to open, " .. T.text("accent", "/nb help") .. " for commands.")
    if NS.migratedThisSession then
        NS.Util.Print("Upgraded your old settings - class needs, raid times and responders were kept.")
    end
end

--------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------

local function HandleSlash(msg)
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "" or cmd == "show" then
        NS.MainWindow:Toggle()
    elseif cmd == "r" or cmd == "responders" then
        NS.RespondersWindow:Toggle()
    elseif cmd == "preview" or cmd == "test" then
        NS.db.previewMode = not NS.db.previewMode
        NS.Util.Print("Preview mode " .. (NS.db.previewMode and (T.text("warn", "ON") .. " (nothing is sent)") or (T.text("good", "OFF") .. " (messages go live)")))
        NS.MainWindow:Refresh()
    elseif cmd == "reply" then
        NS.db.autoReply.enabled = not NS.db.autoReply.enabled
        NS.Util.Print("Auto-reply " .. (NS.db.autoReply.enabled and T.text("good", "ON") or T.text("warn", "OFF")))
        NS.MainWindow:Refresh()
    elseif cmd == "discord" then
        if rest ~= "" then
            NS.db.discord = NS.Util.Trim(rest)
            NS.Util.Print("Discord link set to " .. NS.db.discord)
            NS.MainWindow:Refresh()
        else
            NS.Util.Print("Discord link: " .. (NS.db.discord ~= "" and NS.db.discord or T.text("warn", "not set")))
        end
    elseif cmd == "minimap" then
        NS.db.minimap.hide = not NS.db.minimap.hide
        NS.Minimap:Update()
        NS.Util.Print("Minimap button " .. (NS.db.minimap.hide and "hidden" or "shown"))
    elseif cmd == "reset" then
        NS.MainWindow:ResetPosition()
        NS.RespondersWindow:ResetPosition()
        NS.Util.Print("Window positions reset.")
    else
        NS.Util.Print("commands:")
        print("  " .. T.text("accent", "/nb") .. " - open the recruiter window")
        print("  " .. T.text("accent", "/nb r") .. " - open the responders window")
        print("  " .. T.text("accent", "/nb preview") .. " - toggle preview (test) mode")
        print("  " .. T.text("accent", "/nb reply") .. " - toggle auto-reply")
        print("  " .. T.text("accent", "/nb discord <link>") .. " - set the Discord invite")
        print("  " .. T.text("accent", "/nb minimap") .. " - show/hide the minimap button")
        print("  " .. T.text("accent", "/nb reset") .. " - reset window positions")
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
boot:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        NS.loadedVars = true
    elseif event == "PLAYER_LOGIN" then
        NS:Initialize()
        self:UnregisterAllEvents()
    end
end)
