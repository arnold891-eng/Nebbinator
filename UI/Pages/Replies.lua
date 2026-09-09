-- Nebbinator :: UI/Pages/Replies.lua
-- The four canned whispers, and the automatic one.

local ADDON, NS = ...
local K  = NS.Kit
local UI = NS.UI

function UI:BuildReplies(page)
    local left, right = self:Columns(page, 0.5)

    -- quick replies ------------------------------------------------
    local y = -2
    y = self:Caption(left, y, "quick replies")
    y = self:Note(left, y, "Each one is a button on every responder row. Tokens work here too.")

    self.quickWidgets = {}
    for i = 1, 4 do
        local slotTop = y - ((i - 1) * 84)

        local labelWell = K.Input(left, 118, 20, {
            maxLetters = 18, size = 11,
            onChange = function(text)
                NS.db.quickReplies[i].label = text
                UI:RefreshResponders()
            end,
        })
        labelWell:SetPoint("TOPLEFT", left, "TOPLEFT", 2, slotTop)

        local counter = K.fs(left, "", 9, "dim")
        counter:SetPoint("TOPRIGHT", left, "TOPRIGHT", -66, slotTop + 4)
        counter:SetJustifyH("RIGHT")

        local testBtn = K.Button(left, "Test", 56, 20, function()
            NS.Message:SendWhisper(UnitName("player"), NS.Message:Render(NS.db.quickReplies[i].text))
        end)
        testBtn:SetPoint("TOPRIGHT", left, "TOPRIGHT", -2, slotTop)
        testBtn:SetTip("Test", "Whispers this reply to yourself.")

        local area = K.TextArea(left, UI.colW(left) - 2, 52, function(text)
            NS.db.quickReplies[i].text = text
            UI:RefreshQuick()
        end)
        area:SetPoint("TOPLEFT", left, "TOPLEFT", 2, slotTop - 24)

        self.quickWidgets[i] = { label = labelWell, area = area, counter = counter }

        self:Register("quick" .. i .. "Label",
            function() return NS.db.quickReplies[i].label or "" end,
            function(v) NS.db.quickReplies[i].label = tostring(v or "") end,
            function() labelWell:Set(NS.db.quickReplies[i].label) end)

        self:Register("quick" .. i .. "Text",
            function() return NS.db.quickReplies[i].text or "" end,
            function(v) NS.db.quickReplies[i].text = tostring(v or "") end,
            function() area:Set(NS.db.quickReplies[i].text) end)
    end

    -- auto reply ---------------------------------------------------
    local ry = -2
    ry = self:Caption(right, ry, "auto-reply")
    ry = self:Note(right, ry, "Answers a whisper with your Discord link, once per player.")

    ry = self:Check(right, ry, "autoReply", "Auto-reply to whispers",
        "Never to guild members while the skip is on, never twice inside the cooldown, and never past the per-minute cap.",
        function() return NS.db.autoReply.enabled and true or false end,
        -- the slash command owns this toggle, so call it rather than writing
        -- the key: the checkbox then inherits whatever guards it grows
        function(v) UI.flip(NS.db.autoReply.enabled, v, NS.ToggleAutoReply) end)

    ry = self:Seg(right, ry, "replyMode", "Fires on", {
        { "keywords", "Keywords" }, { "any", "Any whisper" },
    },
        function() return NS.db.autoReply.mode or "keywords" end,
        function(v) NS.db.autoReply.mode = v end)

    ry = self:Field(right, ry, "keywords", "Trigger words", 92,
        function() return NS.db.autoReply.keywords end,
        function(v) NS.db.autoReply.keywords = v end,
        "Comma separated. Keeps a friend saying 'hey' from getting the pitch.",
        { maxLetters = 500 })

    ry = ry - 4
    local replyCap = K.fs(right, "REPLY TEXT", 10, "dim")
    replyCap:SetPoint("TOPLEFT", right, "TOPLEFT", 2, ry)
    ry = ry - 16

    self.replyArea = K.TextArea(right, UI.colW(right) - 2, 62, function(text)
        NS.db.autoReply.text = text
        UI:RefreshQuick()
    end)
    self.replyArea:SetPoint("TOPLEFT", right, "TOPLEFT", 2, ry)
    self:Register("replyText",
        function() return NS.db.autoReply.text or "" end,
        function(v) NS.db.autoReply.text = tostring(v or "") end,
        function() self.replyArea:Set(NS.db.autoReply.text) end)
    ry = ry - 68

    local previewCap = K.fs(right, "WHAT THEY GET", 10, "dim")
    previewCap:SetPoint("TOPLEFT", right, "TOPLEFT", 2, ry)
    ry = ry - 16

    self.replyPreview = K.TextArea(right, UI.colW(right) - 2, 50, nil, true)
    self.replyPreview:SetPoint("TOPLEFT", right, "TOPLEFT", 2, ry)
    ry = ry - 58

    ry = self:Slider(right, ry, "replyCooldown", "Wait before replying to the same player", 60, 3600, 30, "%ds",
        function() return NS.db.autoReply.cooldown or 900 end,
        function(v) NS.db.autoReply.cooldown = v end)

    ry = self:Slider(right, ry, "replyRate", "Never more than this many a minute", 1, 20, 1, "%d",
        function() return NS.db.autoReply.maxPerMinute or 6 end,
        function(v) NS.db.autoReply.maxPerMinute = v end)

    ry = self:Check(right, ry, "skipGuildies", "Never auto-reply to guild members", nil,
        function() return NS.db.autoReply.skipGuildies and true or false end,
        function(v) NS.db.autoReply.skipGuildies = v and true or false end)

    self:Btn(right, ry, "testReply", "Send the reply to myself", nil, function()
        NS.Message:SendWhisper(UnitName("player"), NS.Message:Render(NS.db.autoReply.text))
    end, nil, 180)

    return page
end

function UI:RefreshQuick()
    if self.quickWidgets then
        for i, widget in ipairs(self.quickWidgets) do
            local text = NS.Message:Render(NS.db.quickReplies[i].text)
            if text == "" then
                widget.counter:SetText(NS.T.text("dim", "empty"))
            else
                local parts = #NS.Util.SplitMessage(text, NS.CHAT_LIMIT)
                widget.counter:SetText(NS.T.text(parts > 1 and "gold" or "dim",
                    #text .. " chars" .. (parts > 1 and ("  splits into " .. parts) or "")))
            end
        end
    end

    if self.replyPreview then
        local text = NS.Message:Render(NS.db.autoReply.text)
        self.replyPreview:Set(text ~= "" and text or "(empty)")
    end
end
