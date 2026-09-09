-- Nebbinator - UI/Widgets.lua
-- Thin helpers so every window looks and behaves the same.

local ADDON, NS = ...
local U = NS.Util
local T = NS.T

NS.W = {}
local W = NS.W

local BACKDROP_WINDOW = {
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local BACKDROP_PANEL = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

function W.Window(globalName, width, height, titleText, storageKey)
    local f = CreateFrame("Frame", globalName, UIParent, "BackdropTemplate")
    f:SetSize(width, height)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetBackdrop(BACKDROP_WINDOW)
    f:SetBackdropColor(T.rgba("bg", 0.96))
    f:SetBackdropBorderColor(T.rgb("line2"))
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if storageKey and NS.db then
            local point, _, relPoint, x, y = self:GetPoint()
            NS.db.windows[storageKey] = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)
    f:Hide()

    local pos = storageKey and NS.db and NS.db.windows[storageKey]
    if pos then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint("CENTER")
    end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText(titleText)
    title:SetTextColor(T.rgb("accent"))
    f.titleText = title

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() f:Hide() end)

    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(T.rgba("line2", 1))
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 14, -36)
    line:SetPoint("TOPRIGHT", -14, -36)

    tinsert(UISpecialFrames, globalName)   -- ESC closes it
    return f
end

function W.Panel(parent)
    local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    p:SetBackdrop(BACKDROP_PANEL)
    p:SetBackdropColor(T.rgba("surface", 1))
    p:SetBackdropBorderColor(T.rgba("line2", 1))
    return p
end

function W.Label(parent, text, x, y, font, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    if r then
        fs:SetTextColor(r, g, b)
    elseif (font or "GameFontHighlightSmall"):find("Disable") then
        fs:SetTextColor(T.rgb("muted"))
    else
        fs:SetTextColor(T.rgb("ink2"))
    end
    return fs
end

function W.Header(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    fs:SetTextColor(T.rgb("ink"))
    return fs
end

function W.Button(parent, text, width, height, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, height or 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

function W.EditBox(parent, width, opts)
    opts = opts or {}
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(width, opts.height or 20)
    e:SetAutoFocus(false)
    e:SetMaxLetters(opts.maxLetters or 200)
    if opts.numeric then e:SetNumeric(true) end
    e:SetScript("OnEscapePressed", e.ClearFocus)
    e:SetScript("OnEnterPressed", e.ClearFocus)
    e:SetScript("OnTextChanged", function(self, userInput)
        if userInput and opts.onChange then opts.onChange(self:GetText(), self) end
    end)
    if opts.tooltip then W.Tooltip(e, opts.tooltipTitle or "", opts.tooltip) end
    return e
end

-- Multi-line box inside a scroll frame, with a visible border.
function W.TextArea(parent, width, height, onChange)
    local border = W.Panel(parent)
    border:SetSize(width, height)
    border:SetBackdropColor(T.rgba("sunken", 1))

    local scroll = CreateFrame("ScrollFrame", nil, border, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetFontObject("ChatFontNormal")
    edit:SetTextColor(T.rgb("ink"))
    edit:SetWidth(width - 40)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(0)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput and onChange then onChange(self:GetText(), self) end
        scroll:UpdateScrollChildRect()
    end)
    scroll:SetScrollChild(edit)

    border.edit = edit
    border.scroll = scroll
    return border
end

function W.Check(parent, text, get, set, tooltip)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    c.text:SetPoint("LEFT", c, "RIGHT", 2, 0)
    c.text:SetText(text)
    c.text:SetTextColor(T.rgb("ink2"))
    c:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
    end)
    c.Sync = function(self) self:SetChecked(get() and true or false) end
    c:Sync()
    if tooltip then W.Tooltip(c, text, tooltip) end
    return c
end

function W.Tooltip(frame, title, body)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if title and title ~= "" then GameTooltip:SetText(title, T.rgb("accent")) end
        if body then GameTooltip:AddLine(body, T.rgb("ink2"), true) end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Simple tab strip. Returns the tab buttons; caller supplies page frames.
function W.Tabs(parent, names, onSelect)
    local buttons = {}
    local x = 14
    for i, name in ipairs(names) do
        local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        b:SetSize(math.max(70, #name * 8 + 22), 22)
        b:SetPoint("TOPLEFT", x, -40)
        b:SetText(name)
        b:SetScript("OnClick", function() onSelect(i) end)
        x = x + b:GetWidth() + 4
        buttons[i] = b
    end
    return buttons
end

function W.SetTabSelected(buttons, index)
    for i, b in ipairs(buttons) do
        if i == index then
            b:SetEnabled(false)
            b:GetFontString():SetTextColor(T.rgb("accent"))
        else
            b:SetEnabled(true)
            b:GetFontString():SetTextColor(T.rgb("ink2"))
        end
    end
end

-- Dropdown built from { {value=, text=, color={r,g,b}} }
function W.Dropdown(parent, width, items, getValue, setValue)
    local dd = CreateFrame("Frame", "NebDD" .. tostring(math.random(1, 1e9)), parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, width)
    UIDropDownMenu_Initialize(dd, function(self, level)
        for _, item in ipairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.value = item.value
            info.checked = (getValue() == item.value)
            info.func = function()
                setValue(item.value)
                UIDropDownMenu_SetText(dd, item.text)
                CloseDropDownMenus()
            end
            if item.color then
                info.colorCode = string.format("|cff%02x%02x%02x",
                    item.color[1] * 255, item.color[2] * 255, item.color[3] * 255)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    dd.Sync = function()
        for _, item in ipairs(items) do
            if item.value == getValue() then UIDropDownMenu_SetText(dd, item.text) end
        end
    end
    dd:Sync()
    return dd
end

--------------------------------------------------------------------
-- Copy box
--
-- Addons cannot write to the system clipboard - the game gives us no
-- API for it. The next best thing is a box with the text already
-- selected, so it is one Ctrl+C away.
--------------------------------------------------------------------

function W.ShowCopyBox(text, titleText)
    local f = W.copyBox
    if not f then
        f = W.Window("NebbinatorCopyBox", 480, 130, "Copy", nil)
        f:SetFrameStrata("FULLSCREEN_DIALOG")

        f.edit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        f.edit:SetSize(420, 22)
        f.edit:SetPoint("TOPLEFT", 22, -52)
        f.edit:SetAutoFocus(true)
        f.edit:SetMaxLetters(0)
        f.edit:SetScript("OnEscapePressed", function() f:Hide() end)
        f.edit:SetScript("OnEnterPressed", function() f:Hide() end)
        -- Never let the text be edited away by accident.
        f.edit:SetScript("OnTextChanged", function(box, userInput)
            if userInput then
                box:SetText(f.contents or "")
                box:HighlightText()
            end
        end)

        f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        f.hint:SetPoint("TOPLEFT", 22, -82)
        f.hint:SetText("Already selected - press Ctrl+C to copy, Esc to close.")
        f.hint:SetTextColor(T.rgb("muted"))

        W.copyBox = f
    end

    f.contents = text
    f.titleText:SetText(titleText or "Copy")
    f:Show()
    f.edit:SetText(text)
    f.edit:SetCursorPosition(0)
    f.edit:HighlightText()
    f.edit:SetFocus()
    return f
end

--------------------------------------------------------------------
-- Send bar
--
-- One button per chat channel you are actually in, wrapped onto as many
-- rows as it takes. Used by both windows, so they can never disagree.
--------------------------------------------------------------------

function W.SendButtons(holder, maxWidth)
    holder.buttons = holder.buttons or {}
    for _, b in ipairs(holder.buttons) do b:Hide() end
    wipe(holder.buttons)

    local x, row = 0, 0

    local function add(label, chatType, target, tooltip)
        local b = W.Button(holder, label, 60, 26, function()
            NS.Message:Send(chatType, target)
        end)
        b.chatType, b.target, b.label = chatType, target, label

        local fs = b:GetFontString()
        if fs then fs:SetTextColor(T.rgb("accent")) end   -- posting is the one action here
        local textWidth = fs and fs:GetStringWidth() or (#label * 7)
        b:SetWidth(math.max(56, math.floor(textWidth + 0.5) + 26))

        if x > 0 and (x + b:GetWidth()) > maxWidth then
            x, row = 0, row + 1
        end
        b:SetPoint("TOPLEFT", x, -row * 29)

        -- Corner timer: warn countdown while the cooldown runs, then muted
        -- time-since so you can see at a glance how stale each channel is.
        b.timer = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.timer:SetPoint("BOTTOMRIGHT", -3, 3)

        W.Tooltip(b, label, tooltip)
        x = x + b:GetWidth() + 4
        table.insert(holder.buttons, b)
    end

    for _, channel in ipairs(NS.Message:GetChannels()) do
        add("/" .. channel.id .. " " .. channel.name, "CHANNEL", channel.name,
            "Post the ad in " .. channel.name .. ".")
    end
    add("Yell", "YELL", nil, "Yell the ad. Loud, and easy to overdo.")
    add("Say", "SAY", nil, "Say the ad locally.")
    if IsInGuild() then
        add("Guild", "GUILD", nil, "Post to guild chat.")
    end

    local rows = row + 1
    holder:SetHeight(rows * 29)
    W.RegisterSendHolder(holder)

    if #holder.buttons == 0 then
        if not holder.emptyLabel then
            holder.emptyLabel = W.Label(holder, "Join a chat channel first.", 0, -6, "GameFontDisableSmall")
        end
        holder.emptyLabel:Show()
    elseif holder.emptyLabel then
        holder.emptyLabel:Hide()
    end

    return rows
end

--------------------------------------------------------------------
-- Send-button timers
--------------------------------------------------------------------

local function ShortTime(seconds)
    if seconds < 60 then return math.floor(seconds) .. "s" end
    if seconds < 3600 then return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60)) end
    if seconds < 86400 then return math.floor(seconds / 3600) .. "h" end
    return "old"
end

local sendTicker

function W.RegisterSendHolder(holder)
    W.sendHolders = W.sendHolders or {}
    for _, existing in ipairs(W.sendHolders) do
        if existing == holder then return end
    end
    table.insert(W.sendHolders, holder)

    if not sendTicker then
        sendTicker = CreateFrame("Frame")
        local accumulated = 0
        sendTicker:SetScript("OnUpdate", function(_, elapsed)
            accumulated = accumulated + elapsed
            if accumulated < 0.25 then return end
            accumulated = 0
            W.UpdateSendTimers()
        end)
    end
end

function W.UpdateSendTimers()
    if not NS.db then return end
    local now = GetTime()
    local cooldown = tonumber(NS.db.sendCooldown) or 10

    for _, holder in ipairs(W.sendHolders or {}) do
        if holder:IsVisible() then
            for _, b in ipairs(holder.buttons or {}) do
                local last = NS.Message:LastSendTime(b.chatType, b.target)
                local fs = b:GetFontString()
                if not last then
                    b.timer:SetText("")
                    b:SetEnabled(true)
                    if fs then fs:SetTextColor(T.rgb("accent")) end
                else
                    local since = now - last
                    if since < cooldown then
                        b.timer:SetText(T.text("warn", math.ceil(cooldown - since)))
                        b:SetEnabled(false)          -- can't spam it by accident
                        if fs then fs:SetTextColor(T.rgb("muted")) end
                    else
                        b.timer:SetText(T.text("muted", ShortTime(since)))
                        b:SetEnabled(true)
                        if fs then fs:SetTextColor(T.rgb("accent")) end
                    end
                end
            end
        end
    end
end
