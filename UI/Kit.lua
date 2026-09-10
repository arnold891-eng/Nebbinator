-- Nebbinator :: UI/Kit.lua
--
-- Flat drawing primitives in the FojjiCore style on the BiS palette. No
-- Blizzard templates and no backdrop art anywhere: every surface is a plain
-- SetColorTexture, every border is four 1px textures, and depth comes from
-- each surface being a shade lighter as it comes forward.
--
-- Everything hangs off one table. Lua 5.1 allows 200 locals per chunk and a
-- widget kit is thirty names if you let it be.

local ADDON, NS = ...

local K = {}
NS.Kit = K

K.T = NS.T

-- House shape (BiSTools / Innervate): a 16 px header at half alpha over a
-- low-alpha body, a 1 px edge border, 8 pt labels, 12x12 header boxes.
K.HEADER = 16
K.HEAD_A = 0.5
K.BODY_A = 0.88
K.LABEL  = 8

-- the layered near-blacks, darkest (furthest back) to lightest (forward)
K.SH = {
    frame   = "0d0b18",
    header  = "141127",
    sidebar = "191531",
    content = "1f1a3a",
    field   = "17132e",
    hair    = "2a2446",
    edge    = "3a3260",
}

--------------------------------------------------------------------
-- primitives
--------------------------------------------------------------------

function K.hx(hex)
    hex = tostring(hex or "ffffff")
    return tonumber(string.sub(hex, 1, 2), 16) / 255,
           tonumber(string.sub(hex, 3, 4), 16) / 255,
           tonumber(string.sub(hex, 5, 6), 16) / 255
end

-- Always returns four numbers. Every SetColorTexture in this addon comes
-- through here, because `cond and T.rgba(...) or shade(...)` truncates to one
-- value and the client throws on the spot, taking the whole window with it.
function K.shade(name, a)
    local hex = K.SH[name]
    if hex then
        local r, g, b = K.hx(hex)
        return r, g, b, a or 1
    end
    return NS.T.rgba(name, a or 1)
end

function K.tex(parent, layer, name, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(K.shade(name, a))
    return t
end

-- four 1px textures, with :set(name, a) to recolour all of them at once
function K.border(frame, name, a)
    local b = {}
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(K.shade(name, a))
        b[side] = t
    end
    b.top:SetPoint("TOPLEFT");       b.top:SetPoint("TOPRIGHT");       b.top:SetHeight(1)
    b.bottom:SetPoint("BOTTOMLEFT"); b.bottom:SetPoint("BOTTOMRIGHT"); b.bottom:SetHeight(1)
    b.left:SetPoint("TOPLEFT");      b.left:SetPoint("BOTTOMLEFT");    b.left:SetWidth(1)
    b.right:SetPoint("TOPRIGHT");    b.right:SetPoint("BOTTOMRIGHT");  b.right:SetWidth(1)
    function b:set(n, alpha)
        for _, side in ipairs({ "top", "bottom", "left", "right" }) do
            self[side]:SetColorTexture(K.shade(n, alpha))
        end
    end
    return b
end

function K.font(region, size)
    pcall(region.SetFont, region, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 12)
    if not region:GetFont() then region:SetFontObject("GameFontHighlightSmall") end
    return region
end

function K.fs(parent, text, size, name)
    local f = parent:CreateFontString(nil, "OVERLAY")
    K.font(f, size)
    local r, g, b = K.shade(name or "ink")
    f:SetTextColor(r, g, b, 1)
    f:SetText(text or "")
    f:SetJustifyH("LEFT")
    return f
end

-- a plain sunken surface with a hairline border
function K.panel(parent, fillName, edgeName)
    local p = CreateFrame("Frame", nil, parent)
    p.fill = K.tex(p, "BACKGROUND", fillName or "field")
    p.edge = K.border(p, edgeName or "hair")
    return p
end

function K.hairline(parent, name, horizontal)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(K.shade(name or "hair", 1))
    if horizontal ~= false then t:SetHeight(1) else t:SetWidth(1) end
    return t
end

--------------------------------------------------------------------
-- flat button
--------------------------------------------------------------------

-- tone is a palette name: nil/"accent" for normal, "warn" for destructive,
-- "good" for something already done.
function K.Button(parent, label, w, h, onClick, tone)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 90, h or 22)
    b.fill = K.tex(b, "ARTWORK", "field")
    b.edge = K.border(b, "edge")
    b.text = K.fs(b, label, 11, "ink2")
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")
    b.tone = tone or "accent"
    b.enabled = true

    function b:SetTone(name) self.tone = name or "accent"; self:Restore() end
    function b:SetLabel(t) self.text:SetText(t or "") end

    function b:Restore()
        if not self.enabled then
            self.fill:SetColorTexture(K.shade("field", 0.5))
            self.edge:set("hair", 1)
            self.text:SetTextColor(K.shade("dim"))
        elseif self.marked then
            self.fill:SetColorTexture(K.shade(self.tone, 0.20))
            self.edge:set(self.tone, 1)
            self.text:SetTextColor(K.shade(self.tone))
        else
            self.fill:SetColorTexture(K.shade("field", 1))
            self.edge:set("edge", 1)
            self.text:SetTextColor(K.shade("ink2"))
        end
    end

    function b:SetMarked(on) self.marked = on and true or false; self:Restore() end

    function b:SetEnabledFlat(on)
        self.enabled = on and true or false
        if self.EnableMouse then self:EnableMouse(self.enabled) end
        self:Restore()
    end

    function b:SetTip(title, body) self.tipTitle, self.tipBody = title, body end

    b:SetScript("OnClick", function(s, button)
        if not s.enabled then return end
        if onClick then onClick(s, button) end
    end)
    b:SetScript("OnEnter", function(s)
        if s.enabled then
            s.fill:SetColorTexture(K.shade(s.tone, 0.18))
            s.edge:set(s.tone, 1)
            s.text:SetTextColor(K.shade(s.tone))
        end
        if s.tipTitle and GameTooltip then
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:AddLine(s.tipTitle)
            if s.tipBody then GameTooltip:AddLine(s.tipBody, 1, 1, 1, true) end
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(s)
        s:Restore()
        if GameTooltip then GameTooltip:Hide() end
    end)

    b:Restore()
    return b
end

-- A 12x12 box in the header strip, anchored by its RIGHT offset so the budget
-- comment and the harness can both talk about "the button at -3".
function K.HeaderButton(parent, x, label, title, tip, onClick, tone)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(12, 12)
    b:SetPoint("RIGHT", parent, "RIGHT", x, 0)
    b.slot, b.tone = x, tone or "accent"
    b.fill = K.tex(b, "ARTWORK", "field")
    b.edge = K.border(b, "edge")
    b.text = K.fs(b, label, K.LABEL, "ink2")
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")

    -- lit when whatever it toggles is showing; the kit's other buttons all do
    -- this and the book button silently could not
    function b:Restore()
        if self.marked then
            self.fill:SetColorTexture(K.shade(self.tone, 0.22))
            self.edge:set(self.tone, 1)
            self.text:SetTextColor(K.shade(self.tone))
        else
            self.fill:SetColorTexture(K.shade("field", 1))
            self.edge:set("edge", 1)
            self.text:SetTextColor(K.shade("ink2"))
        end
    end
    function b:SetMarked(on) self.marked = on and true or false; self:Restore() end

    b:SetScript("OnClick", function(s, button) if onClick then onClick(s, button) end end)
    b:SetScript("OnEnter", function(s)
        s.edge:set(s.tone, 1)
        s.text:SetTextColor(K.shade(s.tone))
        if title and GameTooltip then
            GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(title)
            if tip then GameTooltip:AddLine(tip, 1, 1, 1, true) end
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(s)
        s:Restore()
        if GameTooltip then GameTooltip:Hide() end
    end)
    return b
end

--------------------------------------------------------------------
-- text input
--------------------------------------------------------------------

function K.Input(parent, w, h, opts)
    opts = opts or {}
    local well = K.panel(parent, "field", "edge")
    well:SetSize(w or 160, h or 22)

    local e = CreateFrame("EditBox", nil, well)
    e:SetPoint("TOPLEFT", 6, -1)
    e:SetPoint("BOTTOMRIGHT", -6, 1)
    K.font(e, opts.size or 12)
    e:SetTextColor(K.shade("ink"))
    e:SetAutoFocus(false)
    e:SetMaxLetters(opts.maxLetters or 255)
    if opts.numeric then e:SetNumeric(true) end
    if opts.justify then e:SetJustifyH(opts.justify) end
    e:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    e:SetScript("OnEditFocusGained", function() well.edge:set("accent", 1) end)
    e:SetScript("OnEditFocusLost", function() well.edge:set("edge", 1) end)
    e:SetScript("OnTextChanged", function(s, userInput)
        if userInput and opts.onChange then opts.onChange(s:GetText(), s) end
    end)

    well.edit = e
    function well:Set(text)
        if not self.edit:HasFocus() then self.edit:SetText(text or "") end
    end
    function well:Get() return self.edit:GetText() end
    return well
end

--------------------------------------------------------------------
-- scrolling
--------------------------------------------------------------------

-- A hand-built scroll area: plain ScrollFrame, wheel support, and a flat
-- accent thumb instead of Blizzard's chrome. Caller sets the content height
-- and calls :Update().
function K.Scroll(parent, barWidth)
    barWidth = barWidth or 6

    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    local track = CreateFrame("Frame", nil, parent)
    track:SetWidth(barWidth)
    K.tex(track, "BACKGROUND", "field")

    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    thumb:SetWidth(barWidth)
    thumb:SetHeight(20)
    K.tex(thumb, "ARTWORK", "accent", 0.55)

    scroll.track, scroll.thumb, scroll.content = track, thumb, content

    function scroll:Range()
        local viewH = self:GetHeight() or 0
        local fullH = self.content:GetHeight() or 0
        local range = fullH - viewH
        if not range or range < 0 then range = 0 end
        return range, viewH, fullH
    end

    function scroll:Update()
        local range, viewH, fullH = self:Range()
        local offset = self:GetVerticalScroll() or 0
        if offset > range then offset = range; self:SetVerticalScroll(offset) end
        if range <= 0 then
            self.track:Hide()
            return
        end
        self.track:Show()
        local frac = (fullH > 0) and (viewH / fullH) or 1
        local th = math.max(18, math.floor((viewH * frac) + 0.5))
        self.thumb:SetHeight(th)
        local travel = viewH - th
        local pos = (range > 0) and (offset / range) or 0
        self.thumb:SetPoint("TOPLEFT", self.track, "TOPLEFT", 0, -math.floor(travel * pos + 0.5))
    end

    function scroll:ScrollBy(delta)
        local range = self:Range()
        local offset = (self:GetVerticalScroll() or 0) - delta * 40
        if offset < 0 then offset = 0 elseif offset > range then offset = range end
        self:SetVerticalScroll(offset)
        self:Update()
    end

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(s, delta) s:ScrollBy(delta) end)

    -- dragging the thumb
    thumb:EnableMouse(true)
    thumb:SetScript("OnMouseDown", function(s) s.dragging = true end)
    thumb:SetScript("OnMouseUp", function(s) s.dragging = false end)
    thumb:SetScript("OnUpdate", function(s)
        if not s.dragging or not GetCursorPosition then return end
        local _, cy = GetCursorPosition()
        local scale = (track.GetEffectiveScale and track:GetEffectiveScale()) or 1
        local top = track.GetTop and track:GetTop()
        local h = track.GetHeight and track:GetHeight()
        if not cy or not top or not h or h <= 0 or not scale or scale <= 0 then return end
        local frac = (top - (cy / scale)) / h
        if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
        local range = scroll:Range()
        scroll:SetVerticalScroll(range * frac)
        scroll:Update()
    end)

    return scroll, content
end

-- Anchors a scroll area to fill `parent` with the bar down the right edge.
function K.FillScroll(parent, inset)
    inset = inset or 0
    local scroll, content = K.Scroll(parent)
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -(inset + 12), inset)
    scroll.track:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -inset)
    scroll.track:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, inset)
    return scroll, content
end

--------------------------------------------------------------------
-- multi-line text box
--------------------------------------------------------------------

function K.TextArea(parent, w, h, onChange, readOnly)
    local well = K.panel(parent, "field", "edge")
    well:SetSize(w, h)

    local scroll, content = K.Scroll(well)
    scroll:SetPoint("TOPLEFT", 7, -6)
    scroll:SetPoint("BOTTOMRIGHT", -14, 6)
    scroll.track:SetPoint("TOPRIGHT", well, "TOPRIGHT", -4, -6)
    scroll.track:SetPoint("BOTTOMRIGHT", well, "BOTTOMRIGHT", -4, 6)

    local e = CreateFrame("EditBox", nil, content)
    e:SetPoint("TOPLEFT")
    e:SetWidth(w - 24)
    e:SetMultiLine(true)
    e:SetAutoFocus(false)
    e:SetMaxLetters(0)
    K.font(e, 12)
    e:SetTextColor(K.shade(readOnly and "ink2" or "ink"))
    e:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    e:SetScript("OnEditFocusGained", function() well.edge:set("accent", 1) end)
    e:SetScript("OnEditFocusLost", function() well.edge:set("edge", 1) end)
    e:SetScript("OnTextChanged", function(s, userInput)
        content:SetHeight(math.max(1, s:GetHeight() or 1))
        scroll:Update()
        if not userInput then return end
        if well.readOnly then
            s:SetText(well.locked or "")
        elseif onChange then
            onChange(s:GetText(), s)
        end
    end)
    e:SetScript("OnCursorChanged", function(_, _, cy, _, ch)
        -- keep the caret in view while typing a long template
        local top = -(cy or 0)
        local bottom = top + (ch or 14)
        local offset = scroll:GetVerticalScroll() or 0
        local viewH = scroll:GetHeight() or 1
        if top < offset then scroll:SetVerticalScroll(top)
        elseif bottom > offset + viewH then scroll:SetVerticalScroll(bottom - viewH) end
        scroll:Update()
    end)

    well.readOnly = readOnly and true or false
    well.edit, well.scroll = e, scroll
    function well:Set(text)
        if self.edit:HasFocus() then return end
        self.locked = text or ""
        self.edit:SetText(text or "")
        self.scroll:Update()
    end
    function well:Get() return self.edit:GetText() end
    return well
end

--------------------------------------------------------------------
-- copy box
--
-- Addons cannot write to the system clipboard - the game gives us no API for
-- it. The next best thing is a box with the text already selected, so it is
-- one Ctrl+C away.
--------------------------------------------------------------------

function K.ShowCopyBox(text, titleText)
    local f = K.copyBox
    if not f then
        f = CreateFrame("Frame", "NebbinatorCopyBox", UIParent)
        f:SetSize(470, 120)
        f:SetPoint("CENTER", 0, 120)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(s) s:StartMoving() end)
        f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
        K.tex(f, "BACKGROUND", "frame")
        K.border(f, "accent")

        f.title = K.fs(f, "Copy", 13, "accent")
        f.title:SetPoint("TOPLEFT", 16, -14)

        local close = K.Button(f, "x", 24, 22, function() f:Hide() end, "warn")
        close:SetPoint("TOPRIGHT", -12, -12)

        local well = K.Input(f, 438, 24, { maxLetters = 0, size = 12 })
        well:SetPoint("TOPLEFT", 16, -42)
        f.well = well

        well.edit:SetAutoFocus(true)
        well.edit:SetScript("OnEscapePressed", function() f:Hide() end)
        well.edit:SetScript("OnEnterPressed", function() f:Hide() end)
        -- never let the address be edited away by accident
        well.edit:SetScript("OnTextChanged", function(box, userInput)
            if userInput then
                box:SetText(f.contents or "")
                box:HighlightText()
            end
        end)

        f.hint = K.fs(f, "Already selected - press Ctrl+C to copy, Esc to close.", 10, "dim")
        f.hint:SetPoint("TOPLEFT", 16, -76)

        if UISpecialFrames then table.insert(UISpecialFrames, "NebbinatorCopyBox") end
        K.copyBox = f
    end

    f.contents = text
    f.title:SetText(titleText or "Copy")
    f:Show()
    f.well.edit:SetText(text)
    f.well.edit:SetCursorPosition(0)
    f.well.edit:HighlightText()
    f.well.edit:SetFocus()
    return f
end
