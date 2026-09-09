-- Nebbinator - Core/Message.lua
-- Template tokens, message assembly, chat-safe splitting and sending.

local ADDON, NS = ...
local U = NS.Util

NS.Message = {}
local M = NS.Message

function M:Initialize()
    self.lastSend = {}      -- [targetKey] = timestamp
    self.lastAny  = 0
    self.queue    = {}
    self.sending  = false
end

--------------------------------------------------------------------
-- Token sources
--------------------------------------------------------------------

-- "2 Resto Shaman, 1 Prot Warrior" - always in the same declared order,
-- unlike v1 which walked the table with pairs() and shuffled every build.
function M:NeedsText(short)
    local parts = {}
    for _, class in ipairs(NS.CLASSES) do
        local counts = NS.db.needs[class.key]
        if counts then
            for _, spec in ipairs(class.specs) do
                local n = tonumber(counts[spec.key]) or 0
                if n > 0 then
                    if #class.specs == 1 then
                        table.insert(parts, n .. " " .. class.name)
                    elseif short then
                        table.insert(parts, n .. " " .. spec.name .. " " .. class.name:sub(1, 4))
                    else
                        table.insert(parts, n .. " " .. spec.name .. " " .. class.name)
                    end
                end
            end
        end
    end
    return table.concat(parts, ", ")
end

function M:RoleCounts()
    local tanks, healers, dps = 0, 0, 0
    for _, class in ipairs(NS.CLASSES) do
        local counts = NS.db.needs[class.key]
        if counts then
            for _, spec in ipairs(class.specs) do
                local n = tonumber(counts[spec.key]) or 0
                if spec.role == "TANK" then tanks = tanks + n
                elseif spec.role == "HEALER" then healers = healers + n
                else dps = dps + n end
            end
        end
    end
    return tanks, healers, dps
end

-- Days that share a time get folded together: "Tue/Thu 8-11pm, Sun 7pm".
function M:TimesText(useFullNames)
    local order, byTime = {}, {}
    for _, day in ipairs(NS.DAYS) do
        local value = U.Trim(NS.db.raidTimes[day.key])
        if value ~= "" then
            if not byTime[value] then
                byTime[value] = {}
                table.insert(order, value)
            end
            table.insert(byTime[value], useFullNames and day.name or day.short)
        end
    end
    local groups = {}
    for _, value in ipairs(order) do
        table.insert(groups, table.concat(byTime[value], "/") .. " " .. value)
    end
    return table.concat(groups, ", ")
end

function M:GuildName()
    local override = U.Trim(NS.db.guildName)
    if override ~= "" then return override end
    local name = GetGuildInfo("player")
    return name or "our guild"
end

function M:Tokens()
    local tanks, healers, dps = self:RoleCounts()
    return {
        needs          = self:NeedsText(false),
        ["needs:short"]= self:NeedsText(true),
        times          = self:TimesText(false),
        ["times:full"] = self:TimesText(true),
        guild          = self:GuildName(),
        discord        = U.Trim(NS.db.discord),
        content        = U.Trim(NS.db.content),
        pre            = U.Trim(NS.db.preText),
        post           = U.Trim(NS.db.postText),
        player         = UnitName("player") or "",
        level          = tostring(UnitLevel("player") or ""),
        realm          = GetRealmName() or "",
        faction        = UnitFactionGroup("player") or "",
        tanks          = tostring(tanks),
        healers        = tostring(healers),
        dps            = tostring(dps),
        total          = tostring(tanks + healers + dps),
    }
end

NS.TOKEN_HELP = {
    "{needs}", "{needs:short}", "{times}", "{times:full}", "{guild}",
    "{discord}", "{content}", "{tanks}", "{healers}", "{dps}", "{total}",
    "{pre}", "{post}", "{player}", "{level}", "{realm}", "{faction}",
}

--------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------

-- Replaces tokens, then tidies the punctuation left behind by empty ones
-- so "Discord: {discord}." never renders as "Discord: ."
function M:Render(template)
    local tokens = self:Tokens()
    local missing = {}

    local text = tostring(template or ""):gsub("{([%w:]+)}", function(key)
        local value = tokens[key:lower()]
        if value == nil then return "{" .. key .. "}" end
        if value == "" then missing[key:lower()] = true end
        return value
    end)

    text = text:gsub("%s+", " ")
    text = text:gsub("[%(%[]%s*[%)%]]", "")
    text = text:gsub("%s*([:,;])%s*([%.!,])", "%2")
    text = text:gsub("([:,;-])%s*$", "")
    text = text:gsub("%s+([%.,!%?])", "%1")
    text = text:gsub("%s*,%s*,", ",")

    local missingList = {}
    for key in pairs(missing) do table.insert(missingList, "{" .. key .. "}") end
    table.sort(missingList)

    return U.Trim(text), missingList
end

function M:ActiveTemplate()
    local index = NS.db.activeTemplate or 1
    return NS.db.templates[index] or NS.db.templates[1]
end

function M:Build()
    -- Override wins: whatever is in the box is what goes out. Tokens still
    -- work there, so {discord} keeps doing its job if they want it.
    if NS.db.customEnabled then
        return self:Render(NS.db.customText or "")
    end
    local template = self:ActiveTemplate()
    return self:Render(template and template.text or "")
end

--------------------------------------------------------------------
-- Channels
--------------------------------------------------------------------

-- Every numbered channel you are actually in, plus any custom names
-- from settings. v1 hardcoded 1/2/3, which is wrong on most realms.
function M:GetChannels()
    local list, seen = {}, {}
    local raw = { GetChannelList() }
    for i = 1, #raw, 3 do
        local id, name = raw[i], raw[i + 1]
        if type(id) == "number" and type(name) == "string" and name ~= "" then
            local short = name:match("^([^%-]+)") or name
            short = U.Trim(short)
            if not seen[short:lower()] then
                seen[short:lower()] = true
                table.insert(list, { id = id, name = short, label = id .. ". " .. short })
            end
        end
    end
    for _, name in ipairs(U.SplitList(NS.db.customChannels)) do
        if not seen[name] then
            local id = GetChannelName(name)
            table.insert(list, { id = id, name = name, label = (id and id > 0 and (id .. ". ") or "") .. name })
        end
    end
    return list
end

--------------------------------------------------------------------
-- Sending
--------------------------------------------------------------------

local function TargetKey(chatType, target)
    return chatType .. ":" .. tostring(target or "")
end

-- When was this target last posted to? Channels are keyed by id internally,
-- so resolve the name the button carries.
function M:LastSendTime(chatType, target)
    if chatType == "CHANNEL" then
        local id = GetChannelName(target)
        if not id or id == 0 then return nil end
        target = id
    end
    return self.lastSend[TargetKey(chatType, target)]
end

function M:CanSend(chatType, target)
    local now = GetTime()
    local cooldown = tonumber(NS.db.sendCooldown) or 10
    local last = self.lastSend[TargetKey(chatType, target)]
    if last and (now - last) < cooldown then
        return false, math.ceil(cooldown - (now - last))
    end
    return true
end

function M:Send(chatType, target)
    local message, missing = self:Build()

    if message == "" then
        NS.Say("nothing to send", "warn")
        return
    end

    if chatType == "CHANNEL" then
        local id = GetChannelName(target)
        if not id or id == 0 then
            NS.Say("not in " .. tostring(target), "warn")
            return
        end
        target = id
    end

    local ok, wait = self:CanSend(chatType, target)
    if not ok then
        NS.Say(wait .. "s cooldown left", "warn")
        return
    end

    if #missing > 0 then
        NS.Say("empty: " .. table.concat(missing, " "), "gold")
    end

    local segments = U.SplitMessage(message, NS.CHAT_LIMIT)

    if NS.db.previewMode then
        -- the text itself is in the window's preview box already; chat gets nothing
        NS.Say("preview - not sent", "warn")
        return
    end

    self.lastSend[TargetKey(chatType, target)] = GetTime()
    self.lastAny = GetTime()

    -- Stagger multi-part messages; the server drops bursts.
    for i, segment in ipairs(segments) do
        if i == 1 then
            SendChatMessage(segment, chatType, nil, target)
        else
            C_Timer.After((i - 1) * 1.2, function()
                SendChatMessage(segment, chatType, nil, target)
            end)
        end
    end

    NS.Say("sent to " .. (chatType == "CHANNEL" and ("/" .. target) or chatType:lower()) ..
        (#segments > 1 and (" x" .. #segments) or ""), "good")
end

function M:SendWhisper(playerName, text)
    if not playerName or playerName == "" or not text or text == "" then return false end
    if NS.db.previewMode then
        NS.Say("preview - " .. playerName .. " not whispered", "warn")
        return true
    end
    for i, segment in ipairs(U.SplitMessage(text, NS.CHAT_LIMIT)) do
        if i == 1 then
            SendChatMessage(segment, "WHISPER", nil, playerName)
        else
            C_Timer.After((i - 1) * 1.2, function()
                SendChatMessage(segment, "WHISPER", nil, playerName)
            end)
        end
    end
    return true
end
