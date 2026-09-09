-- Nebbinator - UI/RespondersWindow.lua

local ADDON, NS = ...
local U, W = NS.Util, NS.W
local T = NS.T

NS.RespondersWindow = {}
local RW = NS.RespondersWindow

local WIDTH = 520
local MIN_LIST, MAX_LIST_FRACTION = 70, 0.82
local TOP_OFFSET = 96          -- everything above the send bar
local FOOTER = 46
local ROW_HEIGHT = 118

local FILTERS = {
    { key = "all",       label = "All" },
    { key = "new",       label = "New" },
    { key = "contacted", label = "Contacted" },
    { key = "trial",     label = "Trial" },
    { key = "accepted",  label = "Accepted" },
    { key = "declined",  label = "Declined" },
}

local STATUS_ORDER = { "new", "contacted", "trial", "accepted", "declined" }

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

function RW:Initialize()
    if self.frame then return end

    local f = W.Window("NebbinatorRespondersFrame", WIDTH, 420, "Responders", "responders")
    self.frame = f
    self.filter = "all"
    self.rows = {}

    local x = 14
    self.filterButtons = {}
    for i, filter in ipairs(FILTERS) do
        local b = W.Button(f, filter.label, math.max(46, #filter.label * 7 + 12), 20, function()
            self.filter = filter.key
            self:Refresh()
        end)
        b:SetPoint("TOPLEFT", x, -42)
        x = x + b:GetWidth() + 3
        self.filterButtons[i] = b
    end

    self.countText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.countText:SetPoint("TOPLEFT", 16, -66)
    self.countText:SetTextColor(T.rgb("muted"))

    W.Label(f, "Logs", 218, -64, "GameFontHighlightSmall")
    self.logsBox = W.EditBox(f, 250, {
        maxLetters = 255,
        onChange = function(text) NS.db.logsUrl = text end,
        tooltipTitle = "Logs address",
        tooltip = "The Logs button on each row builds this address for that player and opens it ready to copy.\n\n" ..
                  "{name} is the responder. {realm} and {region} fill themselves in.",
    })
    self.logsBox:SetPoint("TOPLEFT", 254, -68)

    self.sendLabel = W.Label(f, "Send the ad", 16, -92, "GameFontNormalSmall", T.rgb("ink"))
    self.sendHolder = CreateFrame("Frame", nil, f)
    self.sendHolder:SetPoint("TOPLEFT", 14, -108)
    self.sendHolder:SetSize(WIDTH - 32, 27)

    local scroll = CreateFrame("ScrollFrame", "NebbinatorRespondersScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("BOTTOMRIGHT", -34, FOOTER)
    self.scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 56, 10)
    scroll:SetScrollChild(content)
    self.content = content

    self.empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.empty:SetPoint("TOPLEFT", 8, -10)
    self.empty:SetTextColor(T.rgb("muted"))
    self.empty:SetWidth(WIDTH - 80)
    self.empty:SetJustifyH("LEFT")

    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(T.rgba("line", 1))
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 14, 40)
    line:SetPoint("BOTTOMRIGHT", -14, 40)

    local clearDeclined = W.Button(f, "Clear declined", 110, 24, function()
        NS.Responders:ClearWithStatus("declined")
    end)
    clearDeclined:SetPoint("BOTTOMLEFT", 14, 10)

    local clearAll = W.Button(f, "Clear all", 80, 24, function()
        StaticPopup_Show("NEBBINATOR_CLEAR_ALL")
    end)
    clearAll:SetPoint("LEFT", clearDeclined, "RIGHT", 4, 0)

    local closeBtn = W.Button(f, "Close", 80, 24, function() f:Hide() end)
    closeBtn:SetPoint("BOTTOMRIGHT", -14, 10)

    StaticPopupDialogs["NEBBINATOR_CLEAR_ALL"] = {
        text = "Remove every responder from the list?",
        button1 = YES, button2 = NO,
        OnAccept = function() NS.Responders:ClearWithStatus(nil) end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }

    f:SetScript("OnShow", function()
        self:LayoutSendBar()
        self:Refresh()
    end)
end

--------------------------------------------------------------------
-- Layout: send bar height is variable, and the window grows with the list
--------------------------------------------------------------------

function RW:LayoutSendBar()
    local rows = W.SendButtons(self.sendHolder, WIDTH - 36)
    self.sendRows = rows
    self.scroll:ClearAllPoints()
    self.scroll:SetPoint("TOPLEFT", 14, -(108 + rows * 29 + 6))
    self.scroll:SetPoint("BOTTOMRIGHT", -34, FOOTER)
    return rows
end

-- Small when nobody has answered, taller as they come in, capped so it
-- never runs off the screen. Grows downward from wherever you put it.
function RW:ResizeToFit(count)
    local chrome   = TOP_OFFSET + (self.sendRows or 1) * 29 + 6 + FOOTER
    local wanted   = count > 0 and (count * ROW_HEIGHT + 12) or MIN_LIST
    local maxList  = math.max(MIN_LIST, UIParent:GetHeight() * MAX_LIST_FRACTION - chrome)
    local height   = chrome + math.min(math.max(wanted, MIN_LIST), maxList)
    height = math.floor(height + 0.5)

    if math.abs((self.frame:GetHeight() or 0) - height) < 1 then return end

    local top, left = self.frame:GetTop(), self.frame:GetLeft()
    self.frame:SetHeight(height)
    if top and left then
        self.frame:ClearAllPoints()
        self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top - height)
    end
end

--------------------------------------------------------------------
-- Rows (pooled - v1 recreated and orphaned frames on every refresh)
--------------------------------------------------------------------

function RW:AcquireRow(index)
    if self.rows[index] then return self.rows[index] end

    local row = W.Panel(self.content)
    row:SetSize(WIDTH - 72, ROW_HEIGHT - 6)
    row:SetPoint("TOPLEFT", 6, -6 - (index - 1) * ROW_HEIGHT)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", 8, -7)

    row.when = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.when:SetPoint("TOPRIGHT", -8, -8)
    row.when:SetTextColor(T.rgb("muted"))

    row.info = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.info:SetPoint("TOPLEFT", 8, -24)
    row.info:SetJustifyH("LEFT")
    row.info:SetTextColor(T.rgb("ink"))

    row.message = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.message:SetPoint("TOPLEFT", 8, -38)
    row.message:SetPoint("TOPRIGHT", -8, -38)
    row.message:SetJustifyH("LEFT")
    row.message:SetHeight(24)
    row.message:SetTextColor(T.rgb("ink2"))

    local y = 32
    row.status = W.Button(row, "New", 84, 20)
    row.status:SetPoint("BOTTOMLEFT", 6, y)
    row.status:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    W.Tooltip(row.status, "Status", "Left click moves it forward, right click moves it back.")

    row.whisper = W.Button(row, "Whisper", 62, 20)
    row.whisper:SetPoint("LEFT", row.status, "RIGHT", 3, 0)

    row.discord = W.Button(row, "Discord", 62, 20)
    row.discord:SetPoint("LEFT", row.whisper, "RIGHT", 3, 0)
    W.Tooltip(row.discord, "Send the reply", "Whispers them your auto-reply text, Discord link included.")

    row.invite = W.Button(row, "Invite", 52, 20)
    row.invite:SetPoint("LEFT", row.discord, "RIGHT", 3, 0)
    W.Tooltip(row.invite, "Invite", "Left click invites to your group, right click invites to the guild.")
    row.invite:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Protected call: this must stay wired straight to a click.
    row.who = W.Button(row, "Who", 44, 20)
    row.who:SetPoint("LEFT", row.invite, "RIGHT", 3, 0)
    W.Tooltip(row.who, "Look up",
        "Fills in level and guild with a /who. Blizzard only allows this from a button click, so it cannot happen automatically.")

    row.logs = W.Button(row, "Logs", 46, 20)
    row.logs:SetPoint("LEFT", row.who, "RIGHT", 3, 0)
    W.Tooltip(row.logs, "Logs",
        "Builds the logs address for this player and pops it up already selected, ready for Ctrl+C.")

    row.remove = W.Button(row, "X", 22, 20)
    row.remove:SetPoint("BOTTOMRIGHT", -6, y)

    -- Second row: the four canned answers.
    row.quick = {}
    local slotWidth = math.floor((WIDTH - 72 - 12 - 9) / 4)
    for i = 1, 4 do
        local b = W.Button(row, "", slotWidth, 20)
        b:SetPoint("BOTTOMLEFT", 6 + (i - 1) * (slotWidth + 3), 6)
        row.quick[i] = b
    end

    self.rows[index] = row
    return row
end

function RW:Refresh()
    if not self.frame or not self.frame:IsShown() then
        if NS.MainWindow then NS.MainWindow:RefreshBadge() end
        return
    end

    local list = NS.Responders:SortedList(self.filter)

    for i, entry in ipairs(list) do
        local row = self:AcquireRow(i)
        local name = entry.name

        local hex = U.ClassHex(entry.class)
        row.name:SetText("|cFF" .. hex .. name .. "|r")
        row.when:SetText(U.TimeAgo(entry.timestamp))

        local bits = {}
        if entry.level then table.insert(bits, "Level " .. entry.level) end
        table.insert(bits, entry.className
            or (entry.class and entry.class:sub(1, 1) .. entry.class:sub(2):lower())
            or "class unknown")
        if entry.guild then
            table.insert(bits, "<" .. entry.guild .. ">")
        elseif not entry.lookedUp then
            table.insert(bits, T.text("muted", "press Who for level and guild"))
        end
        if entry.source == "channel" then
            table.insert(bits, T.text("slate", "seen in " .. tostring(entry.channel)))
        end
        row.info:SetText(table.concat(bits, "  "))

        local last = entry.messages and entry.messages[#entry.messages]
        row.message:SetText(last and ('"' .. last.text .. '"') or "")

        local status = StatusInfo(entry.status)
        row.status:SetText(status.name)
        row.status:GetFontString():SetTextColor(status.color[1], status.color[2], status.color[3])
        row.status:SetScript("OnClick", function(_, button)
            NS.Responders:SetStatus(name, NextStatus(entry.status, button == "RightButton"))
        end)

        row.whisper:SetScript("OnClick", function() NS.Responders:WhisperTo(name) end)
        row.discord:SetScript("OnClick", function() NS.Responders:SendDiscord(name) end)
        row.invite:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                NS.Responders:InviteToGuild(name)
            else
                NS.Responders:InviteToGroup(name)
            end
        end)
        row.who:SetScript("OnClick", function() NS.Responders:LookupPlayer(name) end)
        row.logs:SetScript("OnClick", function() NS.Responders:ShowLogs(name) end)

        for i = 1, 4 do
            local button = row.quick[i]
            local reply = NS.db.quickReplies[i]
            local label = U.Trim(reply and reply.label or "")
            if label == "" then label = "Reply " .. i end
            button:SetText(label)
            button:SetEnabled(U.Trim(reply and reply.text or "") ~= "")
            local sent = entry.sentReplies and entry.sentReplies[i]
            button:GetFontString():SetTextColor(T.rgb(sent and "good" or "ink"))
            button:SetScript("OnClick", function() NS.Responders:SendQuickReply(name, i) end)
            button:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(label, T.rgb("accent"))
                GameTooltip:AddLine(NS.Message:Render(reply and reply.text or ""), T.rgb("ink2"), true)
                if sent then GameTooltip:AddLine("Already sent to " .. name, T.rgb("good")) end
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        row.remove:SetScript("OnClick", function() NS.Responders:Remove(name) end)

        if entry.autoReplied then
            row:SetBackdropBorderColor(T.rgba("good", 1))
        elseif entry.status == "new" then
            row:SetBackdropBorderColor(T.rgba("gold", 1))
        else
            row:SetBackdropBorderColor(T.rgba("line2", 1))
        end

        row:Show()
    end

    for i = #list + 1, #self.rows do
        self.rows[i]:Hide()
    end

    self.content:SetHeight(math.max(10, #list * ROW_HEIGHT + 12))
    self:ResizeToFit(#list)
    self.scroll:UpdateScrollChildRect()

    local total = 0
    for _ in pairs(NS.db.responders) do total = total + 1 end
    self.countText:SetText(("Showing %d of %d"):format(#list, total) ..
        (NS.db.autoReply.enabled and ("  " .. T.text("good", "auto-reply on")) or ("  " .. T.text("muted", "auto-reply off"))))

    if #list == 0 then
        self.empty:SetText(total == 0
            and "No responders yet. When somebody whispers you, they show up here with their level, class and guild filled in automatically."
            or "Nothing with that status.")
    else
        self.empty:SetText("")
    end

    for i, filter in ipairs(FILTERS) do
        self.filterButtons[i]:SetEnabled(self.filter ~= filter.key)
    end

    if not self.logsBox:HasFocus() then self.logsBox:SetText(NS.db.logsUrl or "") end

    if NS.MainWindow then NS.MainWindow:RefreshBadge() end
end

function RW:ResetPosition()
    if not self.frame then return end
    NS.db.windows.responders = nil
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", 260, 0)
    self:Refresh()
end

function RW:Show()   if self.frame then self.frame:Show() end end
function RW:Hide()   if self.frame then self.frame:Hide() end end
function RW:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end
