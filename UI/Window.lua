-- Nebbinator :: UI/Window.lua
--
-- One window, a tab rail down the left, every part of the addon on a page.
-- FojjiCore's flat shape, the BiS palette, and hand-built widgets.
--
-- The rule that matters more than the look: every control here writes the SAME
-- saved variable the slash commands write, through the same function where one
-- exists. A checkbox that flips db.previewMode by hand instead of calling
-- NS.TogglePreview would drift from /nb preview the first time either changed.
--
-- Sibling modules are reached through NS.*, never a bare local: the page files
-- load after this one, and a bare name would resolve to a nil global.

local ADDON, NS = ...
local K = NS.Kit

local UI = {}
NS.UI = UI

-- The desk is the window. The book (the tab rail and its pages) rolls up out of
-- sight until you ask for it, and the frame is only ever as tall as what is on
-- show: header + desk + (book).
UI.DESK_W    = 620          -- rolled up: just the queue
UI.BOOK_W    = 820          -- unrolled: room for the rail and the pages
UI.BOOK_H    = 500
UI.W         = 820          -- pages are laid out for the wide state, always
UI.H         = 660
UI.HEADER    = 16   -- K.HEADER, the house bar
UI.SIDEBAR   = 168
UI.STRIP     = 43   -- header buttons: x(12) at -3, =(12) at -17, o(12) at -31 -> -3..-43
UI.ROW       = 30
UI.controls  = {}
UI.actions   = {}
UI.pages     = {}
UI.tabs      = {}
UI.PAGES     = { "Recruit", "Message", "Replies", "About" }

function UI.colW(page)
    return (page and page.colW) or (UI.W - UI.SIDEBAR - 56)
end

function UI:Columns(page, leftFrac)
    leftFrac = leftFrac or 0.5
    local total, gutter = UI.colW(page), 22
    local lw = math.floor((total - gutter) * leftFrac)
    local left = CreateFrame("Frame", nil, page)
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT")
    left:SetWidth(lw)
    left.colW = lw
    local right = CreateFrame("Frame", nil, page)
    right:SetPoint("TOPLEFT", page, "TOPLEFT", lw + gutter, 0)
    right:SetPoint("BOTTOMRIGHT")
    right.colW = total - gutter - lw
    return left, right
end

function UI:Register(id, get, set, sync)
    self.controls[id] = { get = get, set = set, sync = sync }
end

--------------------------------------------------------------------
-- widgets. Each returns the next y and registers itself.
--------------------------------------------------------------------

function UI:Caption(page, y, text)
    local f = K.fs(page, string.upper(text), 10, "dim")
    f:SetPoint("TOPLEFT", page, "TOPLEFT", 2, y)
    return y - 20
end

function UI:Note(page, y, text, name)
    local f = K.fs(page, text, 10, name or "dim")
    f:SetPoint("TOPLEFT", page, "TOPLEFT", 2, y)
    f:SetWidth(UI.colW(page) - 4)
    if f.SetWordWrap then f:SetWordWrap(true) end
    local lines = math.ceil(#tostring(text) / math.max(1, math.floor(UI.colW(page) / 5.4)))
    return y - 4 - (14 * math.max(1, lines)), f
end

function UI:Check(page, y, id, label, tip, get, set)
    local b = CreateFrame("Button", nil, page)
    b:SetSize(UI.colW(page), 24)
    b:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)

    local box = CreateFrame("Frame", nil, b)
    box:SetSize(16, 16)
    box:SetPoint("LEFT", b, "LEFT", 2, 0)
    local fill = K.tex(box, "ARTWORK", "field")
    local edge = K.border(box, "edge")

    local text = K.fs(b, label, 12, "ink2")
    text:SetPoint("LEFT", box, "RIGHT", 10, 0)

    local sync = function()
        -- both branches pass a full argument list on purpose
        if get() then
            fill:SetColorTexture(K.shade("accent", 1))
            edge:set("accent", 1)
            text:SetTextColor(K.shade("ink"))
        else
            fill:SetColorTexture(K.shade("field", 1))
            edge:set("edge", 1)
            text:SetTextColor(K.shade("ink2"))
        end
    end

    b:SetScript("OnClick", function() set(not get()); UI:Apply() end)
    b:SetScript("OnEnter", function(s)
        edge:set("accent", 1)
        if tip and GameTooltip then
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label)
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function()
        sync()
        if GameTooltip then GameTooltip:Hide() end
    end)

    self:Register(id, get, set, sync)
    sync()
    return y - self.ROW
end

-- right-anchored pill group. options: { {value, label}, ... }
function UI:Seg(page, y, id, label, options, get, set)
    local row = CreateFrame("Frame", nil, page)
    row:SetSize(UI.colW(page), 26)
    row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)

    local text = K.fs(row, label, 12, "ink2")
    text:SetPoint("LEFT", row, "LEFT", 2, 0)

    local pills, x = {}, 0
    local rowW = UI.colW(page)
    local pw = math.min(86, math.floor((rowW - 110 - 4 * (#options - 1)) / #options))
    for i = #options, 1, -1 do
        local opt = options[i]
        local p = CreateFrame("Button", nil, row)
        p:SetSize(pw, 22)
        p:SetPoint("RIGHT", row, "RIGHT", -x, 0)
        x = x + pw + 4
        p.fill = K.tex(p, "ARTWORK", "field")
        p.edge = K.border(p, "edge")
        p.text = K.fs(p, opt[2], 11, "ink2")
        p.text:SetPoint("CENTER")
        p.text:SetJustifyH("CENTER")
        p.value = opt[1]
        p:SetScript("OnClick", function(s) set(s.value); UI:Apply() end)
        pills[#pills + 1] = p
    end

    local sync = function()
        local v = get()
        for _, p in ipairs(pills) do
            if p.value == v then
                p.fill:SetColorTexture(K.shade("accent", 0.22))
                p.edge:set("accent", 1)
                p.text:SetTextColor(K.shade("accent"))
            else
                p.fill:SetColorTexture(K.shade("field", 1))
                p.edge:set("edge", 1)
                p.text:SetTextColor(K.shade("ink2"))
            end
        end
    end

    self:Register(id, get, set, sync)
    sync()
    return y - self.ROW
end

function UI:Slider(page, y, id, label, lo, hi, step, fmt, get, set)
    local row = CreateFrame("Frame", nil, page)
    row:SetSize(UI.colW(page), 40)
    row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)

    local text = K.fs(row, label, 12, "ink2")
    text:SetPoint("TOPLEFT", row, "TOPLEFT", 2, 0)

    local value = K.fs(row, "", 12, "accent")
    value:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, 0)
    value:SetJustifyH("RIGHT")

    local track = CreateFrame("Frame", nil, row)
    track:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -20)
    track:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -20)
    track:SetHeight(6)
    track:EnableMouse(true)
    K.tex(track, "ARTWORK", "field")
    K.border(track, "hair")

    local fill = track:CreateTexture(nil, "OVERLAY")
    fill:SetPoint("TOPLEFT", track, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 1, 1)
    fill:SetColorTexture(K.shade("accent", 0.85))
    fill:SetWidth(1)

    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetSize(10, 16)
    thumb:SetPoint("LEFT", track, "LEFT", 0, 0)
    K.tex(thumb, "OVERLAY", "accent")

    local clamp = function(v)
        v = tonumber(v) or lo
        if step and step > 0 then v = math.floor((v / step) + 0.5) * step end
        if v < lo then v = lo elseif v > hi then v = hi end
        return v
    end

    local sync = function()
        local v = clamp(get())
        local w = (track.GetWidth and track:GetWidth()) or (UI.colW(page) - 4)
        if not w or w <= 2 then w = UI.colW(page) - 4 end
        local frac = (hi > lo) and ((v - lo) / (hi - lo)) or 0
        fill:SetWidth(math.max(1, (w - 2) * frac))
        thumb:SetPoint("LEFT", track, "LEFT", math.max(0, (w * frac) - 5), 0)
        value:SetText(string.format(fmt or "%d", v))
    end

    local fromCursor = function()
        if not GetCursorPosition then return end
        local cx = GetCursorPosition()
        local scale = (track.GetEffectiveScale and track:GetEffectiveScale()) or 1
        local left = (track.GetLeft and track:GetLeft())
        local w    = (track.GetWidth and track:GetWidth())
        if not cx or not scale or scale <= 0 or not left or not w or w <= 0 then return end
        local frac = ((cx / scale) - left) / w
        if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
        set(clamp(lo + frac * (hi - lo)))
        UI:Apply()
    end

    track:SetScript("OnMouseDown", function(s) s.dragging = true; fromCursor() end)
    track:SetScript("OnMouseUp",   function(s) s.dragging = false end)
    track:SetScript("OnUpdate",    function(s) if s.dragging then fromCursor() end end)

    -- clamping lives in the setter too, so Set() and the drag agree
    self:Register(id, get, function(v) set(clamp(v)) end, sync)
    sync()
    return y - 46
end

-- a labelled single-line field
function UI:Field(page, y, id, label, labelW, get, set, tip, opts)
    local row = CreateFrame("Frame", nil, page)
    row:SetSize(UI.colW(page), 24)
    row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)

    local text = K.fs(row, label, 12, "ink2")
    text:SetPoint("LEFT", row, "LEFT", 2, 0)

    opts = opts or {}
    opts.onChange = function(value) set(value); UI:Apply() end
    local well = K.Input(row, UI.colW(page) - (labelW or 110), 22, opts)
    well:SetPoint("LEFT", row, "LEFT", labelW or 110, 0)
    if tip then
        well.edit:SetScript("OnEnter", function(s)
            if not GameTooltip then return end
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label)
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        well.edit:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        well.edit:EnableMouse(true)
    end

    local sync = function() well:Set(get()) end
    self:Register(id, get, set, sync)
    sync()
    row.well = well
    return y - 28, well
end

function UI:Btn(page, y, id, label, tip, onclick, tone, width)
    local b = K.Button(page, label, width or 150, 24, function() onclick(); UI:Apply() end, tone)
    b:SetPoint("TOPLEFT", page, "TOPLEFT", 2, y)
    b:SetTip(label, tip)
    -- a button is an action, not a setting: it is not in `controls`, so Set()
    -- cannot fire it by accident and Get() never lies about it
    self.actions[id] = onclick
    return y - 30, b
end

function UI:Run(id)
    self:Build()
    local fn = self.actions[id]
    if fn then fn(); self:Apply(); return true end
    return false
end

-- only call a slash-owned toggle when the answer would actually change
function UI.flip(currentIsOn, want, toggle)
    if (want and true or false) ~= (currentIsOn and true or false) then toggle() end
end

--------------------------------------------------------------------
-- live effects
--------------------------------------------------------------------

function UI:Apply()
    self:Refresh()
end

function UI:Refresh()
    if not self.frame then return end
    for _, c in pairs(self.controls) do
        if c.sync then pcall(c.sync) end
    end
    self:RefreshChrome()
    if self.RefreshDesk then self:RefreshDesk() end
    if self.RefreshPreview then self:RefreshPreview() end
    if self.RefreshQuick then self:RefreshQuick() end
    if self.RefreshMessageHints then self:RefreshMessageHints() end
    if self.RefreshAbout then self:RefreshAbout() end
    if self.RefreshOptions then self:RefreshOptions() end
end

-- Data changed underneath us (a whisper landed, a /who came back). Cheap
-- enough to call from an event; does nothing until the window exists.
-- A whisper landed, or a /who came back. The list may have grown or shrunk, so
-- this goes through the layout rather than just repainting.
function UI:OnDataChanged()
    if not self.frame then return end
    self:LayoutDesk()
    self:RefreshChrome()
end

function UI:RefreshChrome()
    if not self.frame then return end
    self:PaintSlots()
end

--------------------------------------------------------------------
-- the frame
--------------------------------------------------------------------

function UI:Build()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "NebbinatorFrame", UIParent)
    f:SetSize(self.W, self.H)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", function(s) s:StartMoving() end)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local point, _, relPoint, x, y = s:GetPoint()
        NS.db.window = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    K.tex(f, "BACKGROUND", "frame", K.BODY_A)
    K.border(f, "edge")
    self.frame = f

    local pos = NS.db.window
    if pos and pos.point then
        f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        f:SetPoint("CENTER")
    end

    self:BuildHeader(f)
    self:BuildDesk(f)
    self:BuildBook(f)

    if UISpecialFrames then table.insert(UISpecialFrames, "NebbinatorFrame") end

    self.bookOpen = NS.db.bookOpen and true or false
    self:ShowTab(NS.db.uiTab or self.PAGES[1])
    self:LayoutDesk()
    f:Hide()
    return f
end

--------------------------------------------------------------------
-- rolling the book up and down
--------------------------------------------------------------------

function UI:ToggleBook(open)
    if open == nil then open = not self.bookOpen end
    self.bookOpen = open and true or false
    NS.db.bookOpen = self.bookOpen
    self:Relayout()
end

-- One place decides how big the window is: header + desk + whatever the book
-- is worth right now. Called on every change that can alter either.
function UI:Relayout()
    if not self.frame then return end

    local deskH = (self.desk and self.desk:GetHeight()) or 1
    local width = self.bookOpen and self.BOOK_W or self.DESK_W
    local height = self.HEADER + deskH + (self.bookOpen and self.BOOK_H or 0)

    if self.book then
        if self.bookOpen then
            self.book:ClearAllPoints()
            self.book:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -(self.HEADER + deskH))
            self.book:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, -(self.HEADER + deskH))
            self.book:SetHeight(self.BOOK_H)
            self.book:Show()
        else
            self.book:Hide()
        end
    end

    if self.bookBtn then self.bookBtn:SetMarked(self.bookOpen) end

    -- Grow downward from wherever the window was put: pin the top-left corner
    -- where it already was and let the height run down from it.
    --
    -- `SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, y)` puts the frame's
    -- TOP edge at y. This said `top - height`, which dropped the window by its
    -- own height on EVERY relayout - Arn saw it as "every time I right click to
    -- pin or unpin it shifts the window down", but a whisper landing did it too.
    local top, left = self.frame:GetTop(), self.frame:GetLeft()
    self.frame:SetWidth(width)
    self.frame:SetHeight(height)
    if top and left then
        self.frame:ClearAllPoints()
        self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        NS.db.window = { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = left, y = top }
    end
end

function UI:BuildHeader(f)
    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(self.HEADER)
    K.tex(head, "BACKGROUND", "header", K.HEAD_A)
    local hair = K.hairline(head, "edge")
    hair:SetPoint("BOTTOMLEFT"); hair:SetPoint("BOTTOMRIGHT")
    self.head = head

    -- The title IS the prompt: "BiS> Nebbinator_", cycling the state slots.
    --
    -- Header budget, left to right: 4 + prompt, width DESK_W - STRIP - 8 = 583 px
    -- ("BiS> " plus ~120 characters at 8 pt, so the words never reach the boxes)
    -- and the window is only ever wider than that. From the right: x(12) at -3,
    -- =(12) at -17, o(12) at -31, so the strip owns -3..-43. Nothing else goes
    -- in this bar.
    -- No logo -- "BiS>" is the brand. No version -- that is on the About page.
    -- No preview pill and no new-responder badge -- both were state, and state
    -- belongs in the prompt's slots.
    self.title = K.fs(head, "", K.LABEL, "ink")
    self.title:SetPoint("LEFT", head, "LEFT", 4, 0)
    -- budget against the NARROW state; the wide one only ever has more room
    self.con = BiSTheme.Console(self.title, { width = self.DESK_W - self.STRIP - 8 })
    self.con:Set("name", "Nebbinator", "accent")

    self.closeBtn = K.HeaderButton(head, -3, "x", "Close",
        "/nb brings it back.", function() UI:Hide() end, "warn")

    self.bookBtn = K.HeaderButton(head, -17, "=", "The rest of it",
        "Needs, raid times, templates and replies. Rolls back up when you are done.",
        function() UI:ToggleBook() end)

    -- Settings used to be a tab in the book. It is its own window now, the same
    -- one every BiS addon wears -- see UI/Options.lua.
    self.optBtn = K.HeaderButton(head, -31, "o", "Options",
        "Sounds, cooldown, auto-reply, the minimap button. Also /nb config.",
        function() UI:ToggleOptions() end)

    -- the header is the drag handle
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() f:StartMoving() end)
    head:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint()
        NS.db.window = { point = point, relPoint = relPoint, x = x, y = y }
    end)
end

--------------------------------------------------------------------
-- the prompt
--------------------------------------------------------------------

-- An event: jumps the rotation, holds 3 s, then the slots resume.
function UI:Log(text, colour)
    if self.con then self.con:Say(text, colour) else NS.Print(text) end
end

-- Standing state, in rotation order. A slot goes nil the moment its state ends.
function UI:PaintSlots()
    local c = self.con
    if not c or not NS.db then return end

    local new, trial = 0, 0
    for _, entry in pairs(NS.db.responders) do
        if entry.status == "new" then new = new + 1
        elseif entry.status == "trial" then trial = trial + 1 end
    end

    c:Set("new",   new > 0 and (new .. " new") or nil, "gold")
    c:Set("trial", trial > 0 and (trial .. " on trial") or nil, "good")
    -- preview mode changes what a click DOES, so it stands rather than passes
    c:Set("preview", NS.db.previewMode and "preview - nothing sends" or nil, "warn")
    c:Set("watch",   NS.db.leadFinder and "watching channels" or nil, "muted")
    c:Set("reply",   NS.db.autoReply.enabled and "auto-reply on" or nil, "good")
end

function UI:PaintConsole()
    if self.con then self.con:Paint() end
end

-- drop anything queued but not yet shown
function UI:Clear()
    if self.con then self.con:Clear() end
end

function UI:BuildBook(f)
    local book = CreateFrame("Frame", nil, f)
    book:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -self.HEADER)
    book:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -self.HEADER)
    book:SetHeight(self.BOOK_H)
    book:Hide()
    self.book = book

    local top = K.hairline(book, "edge")
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT")

    local rail = CreateFrame("Frame", nil, book)
    rail:SetPoint("TOPLEFT", book, "TOPLEFT", 0, -1)
    rail:SetPoint("BOTTOMLEFT", book, "BOTTOMLEFT", 0, 0)
    rail:SetWidth(self.SIDEBAR)
    K.tex(rail, "BACKGROUND", "sidebar")
    local divider = K.hairline(rail, "edge", false)
    divider:SetPoint("TOPRIGHT"); divider:SetPoint("BOTTOMRIGHT")

    local body = CreateFrame("Frame", nil, book)
    body:SetPoint("TOPLEFT", rail, "TOPRIGHT", 1, 0)
    body:SetPoint("BOTTOMRIGHT", book, "BOTTOMRIGHT", -1, 1)
    K.tex(body, "BACKGROUND", "content")
    self.body = body

    for i, name in ipairs(self.PAGES) do
        local tab = CreateFrame("Button", nil, rail)
        tab:SetSize(self.SIDEBAR, 40)
        tab:SetPoint("TOPLEFT", rail, "TOPLEFT", 0, -12 - ((i - 1) * 42))

        local glow = tab:CreateTexture(nil, "ARTWORK")
        glow:SetAllPoints()
        glow:SetColorTexture(K.shade("accent", 0.10))
        glow:Hide()

        local mark = tab:CreateTexture(nil, "OVERLAY")
        mark:SetPoint("TOPLEFT"); mark:SetPoint("BOTTOMLEFT"); mark:SetWidth(3)
        mark:SetColorTexture(K.shade("accent", 1))
        mark:Hide()

        local label = K.fs(tab, name, 13, "muted")
        label:SetPoint("LEFT", tab, "LEFT", 20, 0)

        tab.glow, tab.mark, tab.label, tab.tabName = glow, mark, label, name
        tab:SetScript("OnClick", function(s) UI:ShowTab(s.tabName) end)
        tab:SetScript("OnEnter", function(s)
            if UI.shown ~= s.tabName then s.label:SetTextColor(K.shade("ink2")) end
        end)
        tab:SetScript("OnLeave", function(s)
            if UI.shown ~= s.tabName then s.label:SetTextColor(K.shade("muted")) end
        end)
        self.tabs[name] = tab

        local page = CreateFrame("Frame", nil, body)
        page:SetPoint("TOPLEFT", body, "TOPLEFT", 22, -18)
        page:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -22, 16)
        pcall(page.SetClipsChildren, page, true)
        page:Hide()
        local builder = self["Build" .. name]
        if builder then builder(self, page) end
        self.pages[name] = page
    end
end

function UI:ShowTab(name)
    if not self.frame or not self.pages[name] then return end
    self.shown = name
    NS.db.uiTab = name
    for tabName, tab in pairs(self.tabs) do
        local on = (tabName == name)
        if on then
            tab.glow:Show(); tab.mark:Show()
            tab.label:SetTextColor(K.shade("accent"))
        else
            tab.glow:Hide(); tab.mark:Hide()
            tab.label:SetTextColor(K.shade("muted"))
        end
        if self.pages[tabName] then
            if on then self.pages[tabName]:Show() else self.pages[tabName]:Hide() end
        end
    end
    self:Refresh()
end

-- `tab` names a page in the book, so asking for one unrolls it.
function UI:Open(tab)
    self:Build()
    if tab then
        self:ShowTab(tab)
        self:ToggleBook(true)
    end
    self:LayoutDesk()
    self.frame:Show()
end

function UI:Hide()
    if self.frame then self.frame:Hide() end
end

function UI:Toggle(tab)
    self:Build()
    if self.frame:IsShown() then
        if tab and not (self.bookOpen and self.shown == tab) then
            self:ShowTab(tab)
            self:ToggleBook(true)
        else
            self:Hide()
        end
    else
        self:Open(tab)
    end
end

function UI:Initialize()
    self:Build()
end

--------------------------------------------------------------------
-- driving it without a screen
--------------------------------------------------------------------

function UI:Set(id, value)
    self:Build()
    local c = self.controls[id]
    if not c then return false end
    c.set(value)
    self:Apply()
    return true
end

function UI:Get(id)
    self:Build()
    local c = self.controls[id]
    if not c then return nil end
    return c.get()
end

function UI:IDs()
    self:Build()
    local out = {}
    for id in pairs(self.controls) do out[#out + 1] = id end
    table.sort(out)
    return out
end

function UI:ShownTab() return self.shown end
