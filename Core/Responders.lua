-- Nebbinator - Core/Responders.lua
-- Whisper capture, instant class detection, auto-reply, applicant tracking.

local ADDON, NS = ...
local U = NS.Util

NS.Responders = {}
local R = NS.Responders

local WHO_INTERVAL = 3.5      -- server throttles /who; stay well under it

function R:Initialize()
    self.whoPending   = nil
    self.whoBusy      = false
    self.replyLog     = {}     -- timestamps of auto-replies, for the rate cap
    self.guildRoster  = {}

    local f = CreateFrame("Frame")
    self.frame = f
    f:RegisterEvent("CHAT_MSG_WHISPER")
    f:RegisterEvent("CHAT_MSG_CHANNEL")
    f:RegisterEvent("WHO_LIST_UPDATE")
    f:RegisterEvent("CHAT_MSG_SYSTEM")
    f:RegisterEvent("GUILD_ROSTER_UPDATE")
    f:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_WHISPER" then
            R:OnWhisper(...)
        elseif event == "CHAT_MSG_CHANNEL" then
            R:OnChannelMessage(...)
        elseif event == "WHO_LIST_UPDATE" then
            R:OnWhoResult()
        elseif event == "CHAT_MSG_SYSTEM" then
            R:OnSystemMessage(...)
        elseif event == "GUILD_ROSTER_UPDATE" then
            R:RefreshGuildRoster()
        end
    end)

    self:InstallChatFilter()

    if IsInGuild() then
        if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster()
        elseif GuildRoster then GuildRoster() end
    end
end

--------------------------------------------------------------------
-- Guild roster (so we never cold-pitch our own members)
--------------------------------------------------------------------

function R:RefreshGuildRoster()
    wipe(self.guildRoster)
    local total = GetNumGuildMembers and GetNumGuildMembers() or 0
    for i = 1, total do
        local name = GetGuildRosterInfo(i)
        if name then self.guildRoster[U.StripRealm(name):lower()] = true end
    end
end

function R:IsGuildMember(name)
    return self.guildRoster[name:lower()] == true
end

--------------------------------------------------------------------
-- Incoming whispers
--------------------------------------------------------------------

function R:OnWhisper(text, sender, _, _, _, _, _, _, _, _, _, guid)
    sender = U.StripRealm(sender or "")
    if sender == "" then return end

    local db = NS.db.responders
    local entry = db[sender]
    local isNew = false

    if not entry then
        isNew = true
        entry = {
            name      = sender,
            status    = "new",
            class     = nil,
            level     = nil,
            guild     = nil,
            note      = "",
            source    = "whisper",
            timestamp = time(),
            messages  = {},
        }
        db[sender] = entry
    end

    entry.timestamp = time()
    table.insert(entry.messages, { text = text, at = time() })
    while #entry.messages > 10 do table.remove(entry.messages, 1) end

    -- The whisper carries the sender's GUID: class is free and instant,
    -- no /who round trip needed just to colour the name.
    if guid and not entry.class then
        local ok, _, englishClass = pcall(GetPlayerInfoByGUID, guid)
        if ok and englishClass then entry.class = englishClass end
    end

    local settings = NS.db.autoReply
    if settings.playSound and (isNew or not settings.soundOnlyNew) then
        U.PlayAlert(settings.sound)
    end
    if isNew then
        NS.Say(sender .. " whispered", "gold")
    end

    self:MaybeAutoReply(entry, text)
    NS.UI:OnDataChanged()
    NS.Minimap:Update()
end

--------------------------------------------------------------------
-- Passive lead finder: people advertising for a guild in your channels
--------------------------------------------------------------------

local LEAD_PATTERNS = {
    "lf%s*guild", "looking for a? ?guild", "lfguild", "guildless",
    "need a? ?guild", "want to join a? ?guild",
}

function R:OnChannelMessage(text, sender, _, _, _, _, _, _, channelName)
    if not NS.db.leadFinder then return end
    sender = U.StripRealm(sender or "")
    if sender == "" or sender == UnitName("player") then return end
    if NS.db.responders[sender] then return end

    local lower = (text or ""):lower()
    local hit = false
    for _, pattern in ipairs(LEAD_PATTERNS) do
        if lower:find(pattern) then hit = true break end
    end
    if not hit then return end

    NS.db.responders[sender] = {
        name = sender, status = "new", note = "", source = "channel",
        channel = channelName, timestamp = time(),
        messages = { { text = text, at = time() } },
    }
    if NS.db.autoReply.playSound then U.PlayAlert(NS.db.autoReply.sound) end
    NS.Say(sender .. " wants a guild", "gold")
    NS.UI:OnDataChanged()
    NS.Minimap:Update()
end

--------------------------------------------------------------------
-- Auto-reply
--------------------------------------------------------------------

function R:MatchesKeywords(text)
    local settings = NS.db.autoReply
    if settings.mode == "any" then return true end
    local lower = (text or ""):lower()
    for _, word in ipairs(U.SplitList(settings.keywords)) do
        if lower:find(word, 1, true) then return true end
    end
    return false
end

function R:UnderRateCap()
    local now = time()
    for i = #self.replyLog, 1, -1 do
        if now - self.replyLog[i] > 60 then table.remove(self.replyLog, i) end
    end
    return #self.replyLog < (tonumber(NS.db.autoReply.maxPerMinute) or 6)
end

function R:MaybeAutoReply(entry, text)
    local settings = NS.db.autoReply
    if not settings.enabled then return end
    if settings.skipGuildies and self:IsGuildMember(entry.name) then return end
    if not self:MatchesKeywords(text) then return end

    -- Don't ping-pong with another addon echoing our own link back at us.
    local discord = U.Trim(NS.db.discord)
    if discord ~= "" and (text or ""):find(discord, 1, true) then return end

    local cooldown = tonumber(settings.cooldown) or 900
    if entry.lastReply and (time() - entry.lastReply) < cooldown then return end

    if not self:UnderRateCap() then
        NS.Say("reply cap hit", "warn")
        return
    end

    local body = NS.Message:Render(settings.text)
    if body == "" then return end

    if NS.Message:SendWhisper(entry.name, body) then
        NS.Say(entry.name .. " auto-replied", "good")
        entry.lastReply = time()
        entry.autoReplied = true
        if entry.status == "new" then entry.status = "contacted" end
        table.insert(self.replyLog, time())
    end
end

--------------------------------------------------------------------
-- /who lookup
--
-- SendWho() is protected: Blizzard only allows it straight out of a
-- hardware event, so this must be called from a button's OnClick, never
-- from an event handler or a timer.
--
-- Results arrive one of two ways depending on the client's who-to-UI
-- setting: through WHO_LIST_UPDATE, or printed to chat as a system
-- message. We handle both, because the UI list is empty in the second
-- case and that is what actually happens here.
--------------------------------------------------------------------

function R:LookupPlayer(name)
    if not (C_FriendList and C_FriendList.SendWho) then
        NS.Say("no /who on this client", "warn")
        return
    end
    if self.whoBusy then
        NS.Say("still looking up", "muted")
        return
    end

    self.whoBusy    = true
    self.whoPending = name
    self.whoGotResult = false

    -- Ask for results in the UI list. Some builds ignore or hide this, which
    -- is why the chat parser below exists.
    if C_FriendList.SetWhoToUI then C_FriendList.SetWhoToUI(true)
    elseif SetWhoToUI then SetWhoToUI(1) end

    C_FriendList.SendWho('n-"' .. name .. '"')

    C_Timer.After(6, function()
        if self.whoBusy and self.whoPending == name then
            if not self.whoGotResult then
                local entry = NS.db.responders[name]
                if entry then entry.online, entry.lookedUp = false, true end
                NS.Say(name .. " looks offline", "muted")
            end
            self:FinishLookup()
        end
    end)
end

function R:FinishLookup()
    if C_FriendList and C_FriendList.SetWhoToUI then C_FriendList.SetWhoToUI(false)
    elseif SetWhoToUI then SetWhoToUI(0) end
    self.whoBusy, self.whoPending = false, nil
    NS.UI:OnDataChanged()
    NS.Minimap:Update()
end

function R:ApplyWhoData(name, level, className, guild, zone)
    local entry = NS.db.responders[name]
    if not entry then return false end

    if level and level > 0 then entry.level = level end
    if className and className ~= "" then
        entry.className = className
        entry.class = U.FileNameFromLocalized(className) or entry.class
    end
    entry.guild    = (guild and guild ~= "") and guild or "No guild"
    entry.zone     = zone or entry.zone
    entry.online   = true
    entry.lookedUp = true

    self.whoGotResult = true
    return true
end

-- Path 1: the who list actually got populated.
function R:OnWhoResult()
    if not self.whoBusy then return end

    local count = C_FriendList.GetNumWhoResults and C_FriendList.GetNumWhoResults() or 0
    for i = 1, count do
        local info = C_FriendList.GetWhoInfo(i)
        if info and info.fullName then
            self:ApplyWhoData(U.StripRealm(info.fullName), info.level, info.classStr,
                info.fullGuildName, info.area)
        end
    end

    if count > 0 then self:FinishLookup() end
end

-- Path 2: "[Kumlance]: Level 70 Gnome Mage <Guild> - Shattrath City"
-- Pulled apart by landmark instead of by the localised format string, so
-- it survives locales and client differences.
local function LocalizedClassFromLine(line)
    for _, table_ in ipairs({ LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE }) do
        if table_ then
            for _, localized in pairs(table_) do
                if localized ~= "" and line:find(localized, 1, true) then return localized end
            end
        end
    end
end

function R:ParseWhoLine(line)
    if not line or line == "" then return false end

    local name = line:match("|Hplayer:([^|:%]]+)") or line:match("^%[(.-)%]")
    if not name then return false end
    name = U.StripRealm(name)
    if not NS.db.responders[name] then return false end

    local body  = line:match("%]%s*|?h?:?%s*(.*)$") or line
    local level = tonumber(body:match("(%d+)"))
    local guild = line:match("<(.-)>")
    local zone  = line:match("%s%-%s([^%-]+)%s*$")

    return self:ApplyWhoData(name, level, LocalizedClassFromLine(line), guild, zone and U.Trim(zone))
end

function R:OnSystemMessage(text)
    if not self.whoBusy then return end
    if self:ParseWhoLine(text) then
        C_Timer.After(0.1, function()
            if self.whoBusy then self:FinishLookup() end
        end)
    end
end

-- Keep the /who noise out of the chat frame while one of our lookups is in
-- flight. Manual /who typed by the player is untouched.
function R:InstallChatFilter()
    if self.chatFilterInstalled or not ChatFrame_AddMessageEventFilter then return end
    self.chatFilterInstalled = true
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, text)
        if not R.whoBusy then return false end
        if text and (text:find("|Hplayer:", 1, true) or text:match("^%d+ ")) then
            return true
        end
        return false
    end)
end

--------------------------------------------------------------------
-- Actions used by the responders window
--------------------------------------------------------------------

function R:SetStatus(name, status)
    local entry = NS.db.responders[name]
    if entry then
        entry.status = status
        NS.UI:OnDataChanged()
        NS.Minimap:Update()
    end
end

function R:Remove(name)
    NS.db.responders[name] = nil
    NS.UI:OnDataChanged()
    NS.Minimap:Update()
end

function R:ClearWithStatus(status)
    for name, entry in pairs(NS.db.responders) do
        if not status or entry.status == status then
            NS.db.responders[name] = nil
        end
    end
    NS.UI:OnDataChanged()
    NS.Minimap:Update()
end

function R:CountNew()
    local n = 0
    for _, entry in pairs(NS.db.responders) do
        if entry.status == "new" then n = n + 1 end
    end
    return n
end

function R:SortedList(filter)
    local list = {}
    for _, entry in pairs(NS.db.responders) do
        if not filter or filter == "all" or entry.status == filter then
            table.insert(list, entry)
        end
    end
    table.sort(list, function(a, b)
        if (a.timestamp or 0) == (b.timestamp or 0) then
            return (a.name or "") < (b.name or "")
        end
        return (a.timestamp or 0) > (b.timestamp or 0)
    end)
    return list
end

function R:LogsUrl(name)
    local url = U.Trim(NS.db.logsUrl)
    if url == "" then return "" end
    local realm = (GetRealmName() or ""):gsub("%s+", ""):lower()
    return (url:gsub("{(%w+)}", function(token)
        token = token:lower()
        if token == "name"   then return U.StripRealm(name):lower() end
        if token == "realm"  then return realm end
        if token == "region" then return "us" end
        return "{" .. token .. "}"
    end))
end

function R:ShowLogs(name)
    local url = self:LogsUrl(name)
    if url == "" then
        NS.Say("no logs address set", "warn")
        return
    end
    NS.Kit.ShowCopyBox(url, "Logs for " .. name)
end

function R:WhisperTo(name)
    if ChatFrame_OpenChat then
        ChatFrame_OpenChat("/w " .. name .. " ")
    end
end

function R:InviteToGroup(name)
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(name)
    elseif InviteUnit then
        InviteUnit(name)
    end
end

function R:InviteToGuild(name)
    if not IsInGuild() then
        NS.Say("not in a guild", "warn")
        return
    end
    if not (CanGuildInvite and CanGuildInvite()) then
        NS.Say("rank cannot invite", "warn")
        return
    end
    GuildInvite(name)
    NS.Say(name .. " invited", "good")
    self:SetStatus(name, "trial")
end

function R:SendQuickReply(name, index)
    local reply = NS.db.quickReplies[index]
    if not reply or U.Trim(reply.text) == "" then
        NS.Say("reply " .. index .. " is empty", "warn")
        return
    end

    local body = NS.Message:Render(reply.text)
    if body == "" then return end

    NS.Message:SendWhisper(name, body)
    NS.Say(name .. " <- " .. (NS.Util.Trim(reply.label) ~= "" and reply.label or ("reply " .. index)), "good")

    local entry = NS.db.responders[name]
    if entry then
        entry.lastReply = time()
        entry.sentReplies = entry.sentReplies or {}
        entry.sentReplies[index] = true
        if entry.status == "new" then entry.status = "contacted" end
    end
    NS.UI:OnDataChanged()
    NS.Minimap:Update()
end

function R:SendDiscord(name)
    local link = U.Trim(NS.db.discord)
    if link == "" then
        NS.Say("no discord link set", "warn")
        return
    end
    NS.Message:SendWhisper(name, NS.Message:Render(NS.db.autoReply.text))
    local entry = NS.db.responders[name]
    if entry then
        entry.lastReply = time()
        if entry.status == "new" then entry.status = "contacted" end
    end
    NS.UI:OnDataChanged()
end
