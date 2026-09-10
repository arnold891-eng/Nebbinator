-- Nebbinator :: UI/Desk.lua
--
-- The working window. BiSJC's desk shape: a one-line row per responder, click
-- one to serve them, and only the served one opens up with the buttons. The
-- window is as tall as the list and no taller, so it grows as whispers land and
-- shrinks again as they are dealt with.
--
-- Everything that is not "who is waiting" lives in the book (the tab rail),
-- which is rolled up until the header's list button is pressed.

local ADDON, NS = ...
local K  = NS.Kit
local UI = NS.UI

UI.ROW_H     = 16     -- one queue line
UI.MAX_ROWS  = 10     -- past this the list scrolls instead of growing
UI.SERVED_H  = 82     -- the opened-up block for whoever is served
UI.FOOT_H    = 26
UI.CLOCK_W   = 22     -- room a send button reserves for its corner clock

local FILTERS = {
    { key = "all", label = "All" }, { key = "new", label = "New" },
    { key = "contacted", label = "Contacted" }, { key = "trial", label = "Trial" },
    { key = "accepted", label = "Accepted" }, { key = "declined", label = "Declined" },
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

--------------------------------------------------------------------
-- build
--------------------------------------------------------------------

function UI:BuildDesk(f)
    local desk = CreateFrame("Frame", nil, f)
    desk:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -self.HEADER)
    desk:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -self.HEADER)
    desk:SetHeight(1)
    self.desk = desk
    self.rows = {}
    self.filter = NS.db.filter or "all"

    -- send bar -----------------------------------------------------
    self.sendCap = K.fs(desk, "SEND THE AD", 9, "dim")
    self.sendCap:SetPoint("TOPLEFT", 10, -6)

    self.send = self:SendBar(desk, self.DESK_W - 20)
    self.send:SetPoint("TOPLEFT", 10, -18)

    -- filters ------------------------------------------------------
    -- Parented straight to the desk, not to a container frame. The container
    -- had one anchor and no width, so it measured 0x20 and its buttons never
    -- drew - the desk reserved the 22 px and showed a blank band. Everything
    -- else on the desk is a direct child with real anchors, and everything else
    -- on the desk rendered.
    self.filterButtons = {}
    for i, filter in ipairs(FILTERS) do
        local b = K.Button(desk, filter.label, 58, 18, function()
            UI.filter = filter.key
            NS.db.filter = filter.key
            UI:LayoutDesk()
        end)
        self.filterButtons[i] = { button = b, key = filter.key }
    end

    self.countText = K.fs(desk, "", 9, "dim")

    -- the list -----------------------------------------------------
    self.listHost = CreateFrame("Frame", nil, desk)
    self.listHost:SetHeight(1)
    local scroll, content = K.FillScroll(self.listHost, 0)
    self.listScroll, self.listContent = scroll, content

    self:BuildServed(desk)

    -- footer -------------------------------------------------------
    self.clearDeclined = K.Button(desk, "Clear declined", 100, 20, function()
        NS.Responders:ClearWithStatus("declined")
    end)
    self.clearAll = K.Button(desk, "Clear all", 74, 20, function()
        if StaticPopup_Show then StaticPopup_Show("NEBBINATOR_CLEAR_ALL") else NS.Responders:ClearWithStatus(nil) end
    end, "warn")

    self.logsBox = K.Input(desk, 210, 18, {
        maxLetters = 255, size = 10,
        onChange = function(text) NS.db.logsUrl = text end,
    })
    self.logsLabel = K.fs(desk, "Logs", 10, "muted")

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
    return desk
end

-- The block that opens under the list for whoever is being served. Built once
-- and re-pointed at a name, the way the rows are.
function UI:BuildServed(desk)
    local s = CreateFrame("Frame", nil, desk)
    s:SetHeight(self.SERVED_H)
    s:Hide()
    self.served = s

    local hair = K.hairline(s, "hair")
    hair:SetPoint("TOPLEFT"); hair:SetPoint("TOPRIGHT")

    -- NOT s.who: that name belongs to the /who button below, and the button
    -- was quietly overwriting this label.
    s.title = K.fs(s, "", 11, "accent")
    s.title:SetPoint("TOPLEFT", 10, -6)

    s.status = K.Button(s, "New", 78, 18)
    s.status:SetPoint("TOPRIGHT", -8, -4)
    s.status:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    s.status:SetTip("Status", "Left click moves it forward, right click moves it back.")

    s.message = K.fs(s, "", 10, "muted")
    s.message:SetPoint("TOPLEFT", 10, -22)
    s.message:SetPoint("TOPRIGHT", -8, -22)
    s.message:SetJustifyH("LEFT")
    s.message:SetHeight(12)

    local defs = {
        { key = "whisper", label = "Whisper", w = 58 },
        { key = "discord", label = "Discord", w = 58 },
        { key = "invite",  label = "Invite",  w = 50 },
        { key = "who",     label = "Who",     w = 42 },
        { key = "logs",    label = "Logs",    w = 46 },
    }
    local x = 10
    for _, def in ipairs(defs) do
        local b = K.Button(s, def.label, def.w, 18)
        b:SetPoint("TOPLEFT", x, -38)
        x = x + def.w + 4
        s[def.key] = b
    end
    s.invite:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    s.invite:SetTip("Invite", "Left click invites to your group, right click invites to the guild.")
    s.discord:SetTip("Send the reply", "Whispers them your auto-reply text, Discord link included.")
    s.who:SetTip("Look up", "Fills in level and guild with a /who. Blizzard only allows this from a button click, so it cannot happen by itself.")
    s.logs:SetTip("Logs", "Builds the logs address and pops it up ready to copy.")

    s.quick = {}
    for i = 1, 4 do
        local b = K.Button(s, "", 60, 18)
        s.quick[i] = b
    end
    return s
end

--------------------------------------------------------------------
-- one queue line
--------------------------------------------------------------------

function UI:AcquireRow(index)
    if self.rows[index] then return self.rows[index] end

    local row = CreateFrame("Button", nil, self.listContent)
    row:SetHeight(self.ROW_H)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * self.ROW_H))
    row:SetPoint("TOPRIGHT", 0, -((index - 1) * self.ROW_H))
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.bg = K.tex(row, "BACKGROUND", "sidebar", 0)
    row.mark = row:CreateTexture(nil, "ARTWORK")
    row.mark:SetPoint("TOPLEFT"); row.mark:SetPoint("BOTTOMLEFT")
    row.mark:SetWidth(2)
    row.mark:SetColorTexture(K.shade("accent", 1))
    row.mark:Hide()

    row.name = K.fs(row, "", 10, "ink")
    row.name:SetPoint("LEFT", 8, 0)
    row.name:SetWidth(110)

    row.info = K.fs(row, "", 10, "ink2")
    row.info:SetPoint("LEFT", 122, 0)

    row.remove = K.Button(row, "x", 14, 12, nil, "warn")
    row.remove:SetPoint("RIGHT", -4, 0)

    row.age = K.fs(row, "", 9, "dim")
    row.age:SetPoint("RIGHT", row.remove, "LEFT", -6, 0)
    row.age:SetJustifyH("RIGHT")

    row:SetScript("OnEnter", function(s) if not s.isServed then s.bg:SetColorTexture(K.shade("sidebar", 0.7)) end end)
    row:SetScript("OnLeave", function(s) if not s.isServed then s.bg:SetColorTexture(K.shade("sidebar", 0)) end end)

    self.rows[index] = row
    return row
end

--------------------------------------------------------------------
-- serving
--------------------------------------------------------------------

function UI:Serve(name)
    self.serving = name
    self:LayoutDesk()
end

function UI:ServedName()
    -- a served responder who has been removed or filtered away stops being served
    if self.serving and NS.db.responders[self.serving] then return self.serving end
    return nil
end

--------------------------------------------------------------------
-- layout: the whole point of the desk
--------------------------------------------------------------------

function UI:LayoutDesk()
    if not self.desk then return end

    local sendRows = self:FillSendBar(self.send)
    local top = 18 + sendRows * self.SEND_ROW + 6

    local fx = 10
    for _, entry in ipairs(self.filterButtons) do
        entry.button:ClearAllPoints()
        entry.button:SetPoint("TOPLEFT", self.desk, "TOPLEFT", fx, -top)
        fx = fx + entry.button:GetWidth() + 4
    end
    top = top + 22

    self.countText:ClearAllPoints()
    self.countText:SetPoint("TOPLEFT", self.desk, "TOPLEFT", 12, -top)
    self.logsBox:ClearAllPoints()
    self.logsBox:SetPoint("TOPRIGHT", self.desk, "TOPRIGHT", -10, -top + 2)
    self.logsLabel:ClearAllPoints()
    self.logsLabel:SetPoint("RIGHT", self.logsBox, "LEFT", -5, 0)
    top = top + 16

    -- An empty desk is the SMALLEST desk: no list area at all, and the count
    -- line carries the hint. Otherwise the first whisper would SHRINK the
    -- window, which is the opposite of what it is meant to do.
    local list = NS.Responders:SortedList(self.filter)
    local shown = math.min(#list, self.MAX_ROWS)
    local listH = shown * self.ROW_H

    self.listHost:ClearAllPoints()
    self.listHost:SetPoint("TOPLEFT", self.desk, "TOPLEFT", 8, -top)
    self.listHost:SetPoint("TOPRIGHT", self.desk, "TOPRIGHT", -8, -top)
    self.listHost:SetHeight(math.max(1, listH))
    if shown > 0 then self.listHost:Show() else self.listHost:Hide() end
    top = top + listH + 4

    local servedName = self:ServedName()
    if servedName then
        self.served:ClearAllPoints()
        self.served:SetPoint("TOPLEFT", self.desk, "TOPLEFT", 0, -top)
        self.served:SetPoint("TOPRIGHT", self.desk, "TOPRIGHT", 0, -top)
        self.served:Show()
        top = top + self.SERVED_H
    else
        self.served:Hide()
    end

    self.clearDeclined:ClearAllPoints()
    self.clearDeclined:SetPoint("TOPLEFT", self.desk, "TOPLEFT", 10, -top - 3)
    self.clearAll:ClearAllPoints()
    self.clearAll:SetPoint("LEFT", self.clearDeclined, "RIGHT", 5, 0)
    top = top + self.FOOT_H

    self.desk:SetHeight(top)
    self:RefreshDesk()
    self:Relayout()
end

--------------------------------------------------------------------
-- paint
--------------------------------------------------------------------

function UI:RefreshDesk()
    if not self.listContent then return end

    local list = NS.Responders:SortedList(self.filter)
    local servedName = self:ServedName()
    local shown = math.min(#list, self.MAX_ROWS * 4)   -- the scroll child may hold more

    for i = 1, shown do
        local entry = list[i]
        local row = self:AcquireRow(i)
        local name = entry.name

        row.name:SetText("|cFF" .. NS.Util.ClassHex(entry.class) .. name .. "|r")

        local bits = {}
        if entry.level then bits[#bits + 1] = tostring(entry.level) end
        bits[#bits + 1] = entry.className
            or (entry.class and entry.class:sub(1, 1) .. entry.class:sub(2):lower())
            or "?"
        if entry.guild then bits[#bits + 1] = "<" .. entry.guild .. ">" end
        if entry.source == "channel" then bits[#bits + 1] = NS.T.text("slate", "lf guild") end
        row.info:SetText(table.concat(bits, " "))

        row.age:SetText(NS.Util.TimeAgo(entry.timestamp))

        local isServed = (name == servedName)
        row.isServed = isServed
        if isServed then
            row.bg:SetColorTexture(K.shade("accent", 0.16))
            row.mark:Show()
        else
            row.bg:SetColorTexture(K.shade("sidebar", 0))
            row.mark:Hide()
        end
        -- an unread one is gold until it has been moved off New
        row.name:SetTextColor(NS.Util.ClassColor(entry.class))

        row:SetScript("OnClick", function(_, click)
            if click == "RightButton" then
                NS.Responders:SetStatus(name, NextStatus(entry.status))
            elseif UI.serving == name then
                UI:Serve(nil)
            else
                UI:Serve(name)
            end
        end)
        row.remove:SetScript("OnClick", function()
            if UI.serving == name then UI.serving = nil end
            NS.Responders:Remove(name)
        end)
        row:Show()
    end

    for i = shown + 1, #self.rows do self.rows[i]:Hide() end

    self.listContent:SetWidth(math.max(1, self.listScroll:GetWidth() or 1))
    self.listContent:SetHeight(math.max(1, shown * self.ROW_H))
    self.listScroll:Update()

    local total = 0
    for _ in pairs(NS.db.responders) do total = total + 1 end
    local new = NS.Responders:CountNew()
    if #list == 0 then
        self.countText:SetText(NS.T.text("dim", total == 0
            and "Nobody yet - post the ad and whispers land here"
            or "nothing with that status"))
    else
        self.countText:SetText(("%d of %d"):format(#list, total)
            .. (new > 0 and ("   " .. NS.T.text("gold", new .. " new")) or "")
            .. (NS.db.autoReply.enabled and ("   " .. NS.T.text("good", "auto-reply")) or ""))
    end

    for _, entry in ipairs(self.filterButtons) do
        entry.button:SetMarked(self.filter == entry.key)
    end

    self.logsBox:Set(NS.db.logsUrl)
    self:PaintServed(servedName)
end

function UI:PaintServed(name)
    local s = self.served
    if not s or not name then return end
    local entry = NS.db.responders[name]
    if not entry then return end

    s.title:SetText("Serving |cFF" .. NS.Util.ClassHex(entry.class) .. name .. "|r")

    local last = entry.messages and entry.messages[#entry.messages]
    s.message:SetText(last and ('"' .. last.text .. '"') or "")

    local status = StatusInfo(entry.status)
    s.status:SetLabel(status.name)
    s.status:SetTone(STATUS_TONE[entry.status] or "accent")
    s.status:SetMarked(true)
    s.status:SetScript("OnClick", function(_, click)
        NS.Responders:SetStatus(name, NextStatus(entry.status, click == "RightButton"))
    end)

    s.whisper:SetScript("OnClick", function() NS.Responders:WhisperTo(name) end)
    s.discord:SetScript("OnClick", function() NS.Responders:SendDiscord(name) end)
    s.invite:SetScript("OnClick", function(_, click)
        if click == "RightButton" then
            NS.Responders:InviteToGuild(name)
        else
            NS.Responders:InviteToGroup(name)
        end
    end)
    s.who:SetScript("OnClick", function() NS.Responders:LookupPlayer(name) end)
    s.logs:SetScript("OnClick", function() NS.Responders:ShowLogs(name) end)

    local width = (self.desk:GetWidth() or self.DESK_W) - 20
    local slot = math.floor((width - 9) / 4)
    for i = 1, 4 do
        local b = s.quick[i]
        local reply = NS.db.quickReplies[i]
        local label = NS.Util.Trim(reply and reply.label or "")
        if label == "" then label = "Reply " .. i end
        local sent = entry.sentReplies and entry.sentReplies[i]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 10 + (i - 1) * (slot + 3), -60)
        b:SetWidth(slot)
        b:SetLabel(label)
        b:SetEnabledFlat(NS.Util.Trim(reply and reply.text or "") ~= "")
        b:SetTone(sent and "good" or "accent")
        b:SetMarked(sent and true or false)
        b:SetTip(label, NS.Message:Render(reply and reply.text or "")
            .. (sent and ("\n\nAlready sent to " .. name) or ""))
        b:SetScript("OnClick", function() NS.Responders:SendQuickReply(name, i) end)
    end
end
