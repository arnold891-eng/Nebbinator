-- Nebbinator :: UI/Pages/Responders.lua
-- The list Arn actually works out of: send bar, filters, and one card per
-- person with every action on it.

local ADDON, NS = ...
local K  = NS.Kit
local UI = NS.UI

local ROW_H = 92

local FILTERS = {
    { key = "all",       label = "All" },
    { key = "new",       label = "New" },
    { key = "contacted", label = "Contacted" },
    { key = "trial",     label = "Trial" },
    { key = "accepted",  label = "Accepted" },
    { key = "declined",  label = "Declined" },
}

local STATUS_ORDER = { "new", "contacted", "trial", "accepted", "declined" }

local STATUS_TONE = {
    new = "gold", contacted = "slate", trial = "accent",
    accepted = "good", declined = "warn",
}

local function StatusInfo(key)
    for _, status in ipairs(NS.STATUSES) do
        if status.key == key then return status end
    end
    return NS.STATUSES[1]
end

local function NextStatus(current, backwards)
    for i, key in ipairs(STATUS_ORDER) do
        if key == current then
            local index = backwards and (i - 1) or (i + 1)
            if index < 1 then index = #STATUS_ORDER end
            if index > #STATUS_ORDER then index = 1 end
            return STATUS_ORDER[index]
        end
    end
    return "new"
end

function UI:BuildResponders(page)
    local w = UI.colW(page)
    self.rows = {}
    self.filter = "all"

    -- send bar -----------------------------------------------------
    local sendCap = K.fs(page, "SEND THE AD", 10, "dim")
    sendCap:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -2)

    local holder = self:SendBar(page, w)
    holder:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -18)
    self.respondersSend = holder

    -- filters ------------------------------------------------------
    local filterRow = CreateFrame("Frame", nil, page)
    filterRow:SetSize(w, 24)
    self.filterRow = filterRow

    self.filterButtons = {}
    local x = 0
    for i, filter in ipairs(FILTERS) do
        local b = K.Button(filterRow, filter.label, 62, 22, function()
            UI.filter = filter.key
            UI:RefreshResponders()
        end)
        b:SetPoint("TOPLEFT", x, 0)
        x = x + 66
        self.filterButtons[i] = { button = b, key = filter.key }
    end

    self.countText = K.fs(page, "", 10, "dim")

    local logsLabel = K.fs(page, "Logs", 11, "ink2")
    self.logsLabel = logsLabel

    self.logsBox = K.Input(page, 250, 20, {
        maxLetters = 255,
        size = 11,
        onChange = function(text) NS.db.logsUrl = text end,
    })

    -- list ---------------------------------------------------------
    local listHost = CreateFrame("Frame", nil, page)
    listHost:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 30)
    listHost:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 30)
    self.listHost = listHost

    local scroll, content = K.FillScroll(listHost, 0)
    self.listScroll, self.listContent = scroll, content

    self.emptyText = K.fs(content, "", 11, "dim")
    self.emptyText:SetPoint("TOPLEFT", 4, -8)
    self.emptyText:SetWidth(w - 20)
    if self.emptyText.SetWordWrap then self.emptyText:SetWordWrap(true) end

    -- footer -------------------------------------------------------
    local clearDeclined = K.Button(page, "Clear declined", 110, 22, function()
        NS.Responders:ClearWithStatus("declined")
    end)
    clearDeclined:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 2)

    local clearAll = K.Button(page, "Clear all", 80, 22, function()
        if StaticPopup_Show then StaticPopup_Show("NEBBINATOR_CLEAR_ALL") else NS.Responders:ClearWithStatus(nil) end
    end, "warn")
    clearAll:SetPoint("LEFT", clearDeclined, "RIGHT", 6, 0)

    if StaticPopupDialogs then
        StaticPopupDialogs["NEBBINATOR_CLEAR_ALL"] = {
            text = "Remove every responder from the list?",
            button1 = YES or "Yes", button2 = NO or "No",
            OnAccept = function() NS.Responders:ClearWithStatus(nil) end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
    end

    self.actions.clearDeclined = function() NS.Responders:ClearWithStatus("declined") end
    self.actions.clearAll      = function() NS.Responders:ClearWithStatus(nil) end

    self:LayoutResponders()
    return page
end

-- The send bar is a variable number of rows, so everything under it is
-- anchored after the bar is filled rather than at a fixed offset.
function UI:LayoutResponders()
    local rows = self:FillSendBar(self.respondersSend)
    local top = -18 - (rows * UI.SEND_ROW) - 10

    self.filterRow:ClearAllPoints()
    self.filterRow:SetPoint("TOPLEFT", self.respondersSend:GetParent(), "TOPLEFT", 0, top)

    self.countText:ClearAllPoints()
    self.countText:SetPoint("TOPLEFT", self.filterRow, "BOTTOMLEFT", 2, -6)

    self.logsBox:ClearAllPoints()
    self.logsBox:SetPoint("TOPRIGHT", self.filterRow, "BOTTOMRIGHT", 0, -2)
    self.logsLabel:ClearAllPoints()
    self.logsLabel:SetPoint("RIGHT", self.logsBox, "LEFT", -6, 0)

    self.listHost:ClearAllPoints()
    self.listHost:SetPoint("TOPLEFT", self.countText, "BOTTOMLEFT", -2, -8)
    self.listHost:SetPoint("BOTTOMRIGHT", self.respondersSend:GetParent(), "BOTTOMRIGHT", 0, 30)
end

--------------------------------------------------------------------
-- one card
--------------------------------------------------------------------

function UI:AcquireRow(index)
    if self.rows[index] then return self.rows[index] end

    local width = UI.colW(self.pages.Responders) - 14
    local card = K.panel(self.listContent, "sidebar", "hair")
    card:SetSize(width, ROW_H - 8)
    card:SetPoint("TOPLEFT", 2, -((index - 1) * ROW_H))

    card.stripe = card:CreateTexture(nil, "ARTWORK")
    card.stripe:SetPoint("TOPLEFT"); card.stripe:SetPoint("BOTTOMLEFT")
    card.stripe:SetWidth(3)
    card.stripe:SetColorTexture(K.shade("gold", 1))

    card.name = K.fs(card, "", 13, "ink")
    card.name:SetPoint("TOPLEFT", 12, -5)

    -- level, class, guild and how long ago, all on the name's line and
    -- right-aligned, so the card only needs two lines of text
    card.info = K.fs(card, "", 10, "ink2")
    card.info:SetPoint("TOPRIGHT", -10, -6)
    card.info:SetJustifyH("RIGHT")

    card.message = K.fs(card, "", 10, "muted")
    card.message:SetPoint("TOPLEFT", 12, -22)
    card.message:SetPoint("TOPRIGHT", -10, -22)
    card.message:SetJustifyH("LEFT")
    card.message:SetHeight(12)

    -- action row
    local y = 6
    card.status = K.Button(card, "New", 74, 20)
    card.status:SetPoint("BOTTOMLEFT", 10, y + 24)
    card.status:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    card.status:SetTip("Status", "Left click moves it forward, right click moves it back.")

    local defs = {
        { key = "whisper", label = "Whisper", w = 58 },
        { key = "discord", label = "Discord", w = 58 },
        { key = "invite",  label = "Invite",  w = 50 },
        { key = "who",     label = "Who",     w = 42 },
        { key = "logs",    label = "Logs",    w = 46 },
    }
    local prev = card.status
    for _, def in ipairs(defs) do
        local b = K.Button(card, def.label, def.w, 20)
        b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        card[def.key] = b
        prev = b
    end
    card.invite:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    card.invite:SetTip("Invite", "Left click invites to your group, right click invites to the guild.")
    card.discord:SetTip("Send the reply", "Whispers them your auto-reply text, Discord link included.")
    card.who:SetTip("Look up", "Fills in level and guild with a /who. Blizzard only allows this from a button click, so it cannot happen automatically.")
    card.logs:SetTip("Logs", "Builds the logs address for this player and pops it up ready to copy.")

    card.remove = K.Button(card, "x", 22, 20, nil, "warn")
    card.remove:SetPoint("BOTTOMRIGHT", -10, y + 24)

    -- quick replies
    card.quick = {}
    local slotWidth = math.floor((width - 20 - 9) / 4)
    for i = 1, 4 do
        local b = K.Button(card, "", slotWidth, 20)
        b:SetPoint("BOTTOMLEFT", 10 + (i - 1) * (slotWidth + 3), y)
        card.quick[i] = b
    end

    self.rows[index] = card
    return card
end

function UI:RefreshResponders()
    if not self.listContent then return end

    local list = NS.Responders:SortedList(self.filter)

    for i, entry in ipairs(list) do
        local card = self:AcquireRow(i)
        local name = entry.name

        card.name:SetText("|cFF" .. NS.Util.ClassHex(entry.class) .. name .. "|r")

        local bits = {}
        if entry.level then table.insert(bits, "Level " .. entry.level) end
        table.insert(bits, entry.className
            or (entry.class and entry.class:sub(1, 1) .. entry.class:sub(2):lower())
            or "class unknown")
        if entry.guild then
            table.insert(bits, "<" .. entry.guild .. ">")
        elseif not entry.lookedUp then
            table.insert(bits, NS.T.text("dim", "press Who for level and guild"))
        end
        if entry.source == "channel" then
            table.insert(bits, NS.T.text("slate", "seen in " .. tostring(entry.channel)))
        end
        table.insert(bits, NS.T.text("dim", NS.Util.TimeAgo(entry.timestamp)))
        card.info:SetText(table.concat(bits, "   "))

        local last = entry.messages and entry.messages[#entry.messages]
        card.message:SetText(last and ('"' .. last.text .. '"') or "")

        local status = StatusInfo(entry.status)
        card.status:SetLabel(status.name)
        card.status:SetTone(STATUS_TONE[entry.status] or "accent")
        card.status:SetMarked(true)
        card.status:SetScript("OnClick", function(_, button)
            NS.Responders:SetStatus(name, NextStatus(entry.status, button == "RightButton"))
        end)

        card.whisper:SetScript("OnClick", function() NS.Responders:WhisperTo(name) end)
        card.discord:SetScript("OnClick", function() NS.Responders:SendDiscord(name) end)
        card.invite:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                NS.Responders:InviteToGuild(name)
            else
                NS.Responders:InviteToGroup(name)
            end
        end)
        card.who:SetScript("OnClick", function() NS.Responders:LookupPlayer(name) end)
        card.logs:SetScript("OnClick", function() NS.Responders:ShowLogs(name) end)
        card.remove:SetScript("OnClick", function() NS.Responders:Remove(name) end)

        for slot = 1, 4 do
            local button = card.quick[slot]
            local reply = NS.db.quickReplies[slot]
            local label = NS.Util.Trim(reply and reply.label or "")
            if label == "" then label = "Reply " .. slot end
            local sent = entry.sentReplies and entry.sentReplies[slot]
            button:SetLabel(label)
            button:SetEnabledFlat(NS.Util.Trim(reply and reply.text or "") ~= "")
            button:SetTone(sent and "good" or "accent")
            button:SetMarked(sent and true or false)
            button:SetTip(label, NS.Message:Render(reply and reply.text or "")
                .. (sent and ("\n\nAlready sent to " .. name) or ""))
            button:SetScript("OnClick", function() NS.Responders:SendQuickReply(name, slot) end)
        end

        card.stripe:SetColorTexture(K.shade(STATUS_TONE[entry.status] or "accent", 1))
        card:Show()
    end

    for i = #list + 1, #self.rows do
        self.rows[i]:Hide()
    end

    self.listContent:SetWidth(math.max(1, self.listScroll:GetWidth() or 1))
    self.listContent:SetHeight(math.max(1, #list * ROW_H + 4))
    self.listScroll:Update()

    local total = 0
    for _ in pairs(NS.db.responders) do total = total + 1 end
    self.countText:SetText(("Showing %d of %d"):format(#list, total) .. "   " ..
        (NS.db.autoReply.enabled and NS.T.text("good", "auto-reply on") or NS.T.text("dim", "auto-reply off")))

    if #list == 0 then
        self.emptyText:SetText(total == 0
            and "No responders yet. When somebody whispers you they land here, with their class already filled in from the whisper itself."
            or "Nothing with that status.")
    else
        self.emptyText:SetText("")
    end

    for _, entry in ipairs(self.filterButtons) do
        entry.button:SetMarked(self.filter == entry.key)
    end

    self.logsBox:Set(NS.db.logsUrl)
end
