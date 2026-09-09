-- Nebbinator :: UI/Pages/Settings.lua

local ADDON, NS = ...
local K  = NS.Kit
local UI = NS.UI

function UI:BuildSettings(page)
    local left, right = self:Columns(page, 0.52)

    local y = -2
    y = self:Caption(left, y, "safety")

    y = self:Check(left, y, "previewMode", "Preview mode - print, never send",
        "The safe way to test. Everything is printed to your chat frame instead of going out.",
        function() return NS.db.previewMode and true or false end,
        function(v) UI.flip(NS.db.previewMode, v, NS.TogglePreview) end)

    y = self:Slider(left, y, "sendCooldown", "Cooldown between posts to one channel", 3, 120, 1, "%ds",
        function() return NS.db.sendCooldown or 10 end,
        function(v) NS.db.sendCooldown = v end)

    y = self:Note(left, y, "The send buttons grey out and count down for this long. Raise it if a channel's rules are stricter.")

    y = y - 6
    y = self:Caption(left, y, "alert sound")

    y = self:Check(left, y, "playSound", "Play a sound when a message lands", nil,
        function() return NS.db.autoReply.playSound and true or false end,
        function(v) NS.db.autoReply.playSound = v and true or false end)

    y = self:Check(left, y, "soundOnlyNew", "Only for the first message from someone new",
        "Off means every whisper from anyone on the list dings.",
        function() return NS.db.autoReply.soundOnlyNew and true or false end,
        function(v) NS.db.autoReply.soundOnlyNew = v and true or false end)

    -- the sound list is a grid of buttons rather than a dropdown, so picking
    -- one plays it and you can walk the whole list in a few clicks
    y = y - 2
    local soundCap = K.fs(left, "PICK ONE - IT PLAYS WHEN YOU CLICK", 10, "dim")
    soundCap:SetPoint("TOPLEFT", left, "TOPLEFT", 2, y)
    y = y - 18

    self.soundButtons = {}
    local x, colWidth = 2, math.floor((UI.colW(left) - 8) / 2)
    for i, sound in ipairs(NS.SOUNDS) do
        local b = K.Button(left, sound.name, colWidth, 20, function()
            NS.db.autoReply.sound = sound.key
            NS.Util.PlayAlert(sound.key)
            UI:Apply()
        end)
        b:SetPoint("TOPLEFT", x, y)
        self.soundButtons[i] = { button = b, key = sound.key }
        if x > 2 then x = 2; y = y - 22 else x = 2 + colWidth + 4 end
    end
    if x > 2 then y = y - 22 end

    self:Register("sound",
        function() return NS.db.autoReply.sound or "bell" end,
        function(v) NS.db.autoReply.sound = v end,
        function()
            for _, entry in ipairs(self.soundButtons or {}) do
                entry.button:SetMarked(NS.db.autoReply.sound == entry.key)
            end
        end)

    -- right column -------------------------------------------------
    local ry = -2
    ry = self:Caption(right, ry, "window")

    ry = self:Check(right, ry, "minimap", "Minimap button",
        "Left click opens the window, right click jumps to Responders.",
        function() return not NS.db.minimap.hide end,
        function(v) UI.flip(not NS.db.minimap.hide, v, NS.ToggleMinimap) end)

    ry = self:Btn(right, ry, "resetWindow", "Put the window back",
        "Back to the middle of the screen.", NS.ResetWindow, "warn", 170)

    ry = ry - 8
    ry = self:Caption(right, ry, "finding people")

    ry = self:Check(right, ry, "leadFinder", "Watch channels for \"LF guild\"",
        "Anyone posting that in a channel you are in lands on the responders list as a lead. Nothing is ever sent to them automatically.",
        function() return NS.db.leadFinder and true or false end,
        function(v) NS.db.leadFinder = v and true or false end)

    ry = ry - 4
    ry = self:Caption(right, ry, "logs address")

    ry = self:Field(right, ry, "logsUrl", "Address", 62,
        function() return NS.db.logsUrl end,
        function(v) NS.db.logsUrl = v end,
        "The Logs button on a responder builds this and pops it up ready to copy.")

    ry = self:Note(right, ry, "{name} is the responder. {realm} and {region} fill themselves in.")

    ry = ry - 4
    ry = self:Caption(right, ry, "channels")

    ry = self:Field(right, ry, "customChannels", "Extra", 62,
        function() return NS.db.customChannels end,
        function(v) NS.db.customChannels = v end,
        "Comma separated channel names to add buttons for, beyond the ones you are already in.")

    return page
end
