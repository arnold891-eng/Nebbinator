-- Nebbinator :: UI/SendBar.lua
--
-- One button per chat channel you are actually in, wrapped onto as many rows
-- as it takes, each with a corner timer: red countdown while the cooldown is
-- running (and the button is dead), grey time-since once it is free.
--
-- Both the Recruit page and the Responders page use this, so they can never
-- disagree about what has been posted where.

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

function UI:FillSendBar(holder)
    for _, b in ipairs(holder.buttons) do b:Hide() end
    wipe(holder.buttons)

    local x, row = 0, 0
    local function add(label, chatType, target, tip)
        local b = K.Button(holder, label, 60, 22, function()
            NS.Message:Send(chatType, target)
            UI:UpdateSendTimers()
        end)
        b.chatType, b.target, b.label = chatType, target, label

        local fsw = b.text and b.text:GetStringWidth() or (#label * 7)
        b:SetWidth(math.max(54, math.floor((fsw or 0) + 0.5) + 30))

        if x > 0 and (x + b:GetWidth()) > holder.maxWidth then
            x, row = 0, row + 1
        end
        b:SetPoint("TOPLEFT", x, -row * UI.SEND_ROW)
        b:SetTip(label, tip)

        b.timer = K.fs(b, "", 9, "dim")
        b.timer:SetPoint("BOTTOMRIGHT", -3, 3)

        x = x + b:GetWidth() + 4
        table.insert(holder.buttons, b)
    end

    for _, channel in ipairs(NS.Message:GetChannels()) do
        add("/" .. channel.id .. " " .. channel.name, "CHANNEL", channel.name,
            "Post the ad in " .. channel.name .. ".")
    end
    add("Yell", "YELL", nil, "Yell the ad. Loud, and easy to overdo.")
    add("Say", "SAY", nil, "Say the ad where you stand.")
    if IsInGuild() then
        add("Guild", "GUILD", nil, "Post to guild chat.")
    end

    local rows = row + 1
    holder:SetHeight(rows * UI.SEND_ROW)
    holder.rows = rows

    if #holder.buttons == 0 then
        if not holder.emptyLabel then
            holder.emptyLabel = K.fs(holder, "Join a chat channel first.", 11, "dim")
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

    -- preview mode used to have its own light up in the header; it is a
    -- standing slot in the prompt now, and the slots are cheap to re-read
    self:PaintSlots()

    local now = GetTime()
    local cooldown = tonumber(NS.db.sendCooldown) or 10

    for _, holder in ipairs(self.holders) do
        if holder:IsVisible() then
            for _, b in ipairs(holder.buttons) do
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
