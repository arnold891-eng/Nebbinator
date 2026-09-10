-- Nebbinator :: UI/SendBar.lua
--
-- One button per chat channel you are actually in, each with a corner clock:
-- red countdown while the cooldown runs (and the button is dead), grey
-- time-since once it is free.
--
-- On a compact desk eleven buttons is three rows of chrome for a thing you use
-- two of, so a channel can be hidden with a right-click and the whole set is one
-- click away behind the arrow. Nothing is hidden until you hide it.

local ADDON, NS = ...
local K = NS.Kit
local UI = NS.UI

UI.SEND_ROW = 26
UI.holders = {}

local function ShortTime(seconds)
    if seconds < 60 then return math.floor(seconds) .. "s" end
    if seconds < 3600 then return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60)) end
    if seconds < 86400 then return math.floor(seconds / 3600) .. "h" end
    return "old"
end

function UI.IsHidden(label)
    local hidden = NS.db.hiddenChannels
    return hidden and hidden[label] == true
end

function UI.ToggleHidden(label)
    NS.db.hiddenChannels = NS.db.hiddenChannels or {}
    if NS.db.hiddenChannels[label] then
        NS.db.hiddenChannels[label] = nil
    else
        NS.db.hiddenChannels[label] = true
    end
end

function UI.AnyHidden()
    for _ in pairs(NS.db.hiddenChannels or {}) do return true end
    return false
end

function UI:SendBar(parent, maxWidth)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetWidth(maxWidth)
    holder:SetHeight(UI.SEND_ROW)
    holder.buttons = {}
    holder.maxWidth = maxWidth
    table.insert(self.holders, holder)
    self:StartSendTicker()
    return holder
end

-- Every target the player could post to, in one list, so the pinned set and the
-- unrolled set are the same objects in the same order.
function UI:SendTargets()
    local out = {}
    for _, channel in ipairs(NS.Message:GetChannels()) do
        out[#out + 1] = {
            label = "/" .. channel.id .. " " .. channel.name,
            chatType = "CHANNEL", target = channel.name,
            tip = "Post the ad in " .. channel.name .. ".",
        }
    end
    out[#out + 1] = { label = "Yell",  chatType = "YELL", tip = "Yell the ad. Loud, and easy to overdo." }
    out[#out + 1] = { label = "Say",   chatType = "SAY",  tip = "Say the ad where you stand." }
    if IsInGuild() then
        out[#out + 1] = { label = "Guild", chatType = "GUILD", tip = "Post to guild chat." }
    end
    return out
end

function UI:FillSendBar(holder)
    for _, b in ipairs(holder.buttons) do b:Hide() end
    wipe(holder.buttons)

    local expanded = self.sendExpanded
    local x, row = 0, 0

    local function add(entry)
        local hidden = UI.IsHidden(entry.label)
        if hidden and not expanded then return end

        local b = K.Button(holder, entry.label, 60, 22, function()
            NS.Message:Send(entry.chatType, entry.target)
            UI:UpdateSendTimers()
        end)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.chatType, b.target, b.label = entry.chatType, entry.target, entry.label

        -- The label is LEFT anchored and the clock is RIGHT anchored, and the
        -- width reserves room for both. Centring the label put "23" straight
        -- through "/2 Trade" on a long channel name (landmine #9b).
        b.text:ClearAllPoints()
        b.text:SetPoint("LEFT", b, "LEFT", 7, 0)
        b.text:SetJustifyH("LEFT")

        b.timer = K.fs(b, "", 8, "dim")
        b.timer:SetPoint("RIGHT", b, "RIGHT", -6, 0)
        b.timer:SetJustifyH("RIGHT")

        local textWidth = b.text:GetStringWidth() or (#entry.label * 5)
        b:SetWidth(math.max(56, math.floor(textWidth + 0.5) + 7 + 6 + UI.CLOCK_W + 6))

        if x > 0 and (x + b:GetWidth()) > holder.maxWidth then
            x, row = 0, row + 1
        end
        b:SetPoint("TOPLEFT", x, -row * UI.SEND_ROW)
        b:SetTip(entry.label, (entry.tip or "") ..
            (hidden and "\n\nHidden from the desk. Right-click to bring it back."
                   or "\n\nRight-click to hide it from the desk."))
        if hidden then b:SetTone("muted") end

        b:SetScript("OnClick", function(s, click)
            if click == "RightButton" then
                UI.ToggleHidden(s.label)
                UI:LayoutDesk()
                return
            end
            if not s.enabled then return end
            NS.Message:Send(s.chatType, s.target)
            UI:UpdateSendTimers()
        end)

        x = x + b:GetWidth() + 4
        table.insert(holder.buttons, b)
    end

    for _, entry in ipairs(self:SendTargets()) do add(entry) end

    -- the arrow only exists when something is actually hidden
    if UI.AnyHidden() then
        local arrow = K.Button(holder, expanded and "^" or "v", 22, 22, function()
            UI.sendExpanded = not UI.sendExpanded
            UI:LayoutDesk()
        end)
        if x > 0 and (x + 22) > holder.maxWidth then x, row = 0, row + 1 end
        arrow:SetPoint("TOPLEFT", x, -row * UI.SEND_ROW)
        arrow:SetTip(expanded and "Hide the rest" or "Show every channel",
            "Right-click any button to hide or unhide it.")
        table.insert(holder.buttons, arrow)
    end

    local rows = row + 1
    holder:SetHeight(rows * UI.SEND_ROW)
    holder.rows = rows

    if #holder.buttons == 0 then
        if not holder.emptyLabel then
            holder.emptyLabel = K.fs(holder, "Join a chat channel first.", 10, "dim")
            holder.emptyLabel:SetPoint("TOPLEFT", 2, -6)
        end
        holder.emptyLabel:Show()
    elseif holder.emptyLabel then
        holder.emptyLabel:Hide()
    end

    self:UpdateSendTimers()
    return rows
end

-- One ticker drives both: the prompt at ~0.15 s so the cursor blinks and the
-- words fade smoothly, the send-button clocks at 0.25 s because a second is the
-- smallest thing they show.
function UI:StartSendTicker()
    if self.sendTicker then return end
    local ticker = CreateFrame("Frame")
    local blink, clocks = 0, 0
    ticker:SetScript("OnUpdate", function(_, elapsed)
        blink = blink + elapsed
        clocks = clocks + elapsed
        if blink >= 0.15 then
            blink = 0
            if UI.frame and UI.frame:IsShown() then UI:PaintConsole() end
        end
        if clocks >= 0.25 then
            clocks = 0
            UI:UpdateSendTimers()
        end
    end)
    self.sendTicker = ticker
end

function UI:UpdateSendTimers()
    if not NS.db or not NS.Message then return end

    -- the ticker runs four times a second anyway, so it also keeps the prompt's
    -- standing slots honest no matter what changed them
    self:PaintSlots()

    local now = GetTime()
    local cooldown = tonumber(NS.db.sendCooldown) or 10

    for _, holder in ipairs(self.holders) do
        if holder:IsVisible() then
            for _, b in ipairs(holder.buttons) do
                if b.chatType then
                    local last = NS.Message:LastSendTime(b.chatType, b.target)
                    if not last then
                        b.timer:SetText("")
                        b:SetEnabledFlat(true)
                    else
                        local since = now - last
                        if since < cooldown then
                            b.timer:SetText(NS.T.text("warn", math.ceil(cooldown - since)))
                            b:SetEnabledFlat(false)   -- can't spam it by accident
                        else
                            b.timer:SetText(NS.T.text("dim", ShortTime(since)))
                            b:SetEnabledFlat(true)
                        end
                    end
                end
            end
        end
    end
end
