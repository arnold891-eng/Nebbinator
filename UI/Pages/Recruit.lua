-- Nebbinator :: UI/Pages/Recruit.lua
-- What we need, when we raid, and exactly what will be sent.

local ADDON, NS = ...
local K  = NS.Kit
local UI = NS.UI

function UI:BuildRecruit(page)
    local w = UI.colW(page)
    local gridW = 372

    -- what we need -------------------------------------------------
    local cap = K.fs(page, "WHAT WE NEED", 10, "dim")
    cap:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -2)

    self.needBoxes = {}
    local colX = { 2, 126, 250 }
    local colHeight = { 0, 0, 0 }

    for _, class in ipairs(NS.CLASSES) do
        -- each class goes into whichever column is currently shortest, so the
        -- grid balances itself instead of overflowing one side
        local shortest = 1
        for c = 2, 3 do
            if colHeight[c] < colHeight[shortest] then shortest = c end
        end
        local x = colX[shortest]
        local y = -20 - colHeight[shortest]

        local r, g, b = NS.Util.ClassColor(class.file)
        local label = K.fs(page, class.name, 11, "ink")
        label:SetPoint("TOPLEFT", x, y)
        label:SetTextColor(r, g, b, 1)

        for i, spec in ipairs(class.specs) do
            local rowY = y - 15 - (i - 1) * 20
            local id = "need." .. class.key .. "." .. spec.key

            local well = K.Input(page, 28, 18, {
                numeric = true, maxLetters = 2, size = 11, justify = "CENTER",
                onChange = function(text)
                    NS.db.needs[class.key][spec.key] = tonumber(text) or 0
                    UI:Apply()
                end,
            })
            well:SetPoint("TOPLEFT", x + 4, rowY)

            local specLabel = K.fs(page, spec.name, 11, "ink2")
            specLabel:SetPoint("LEFT", well, "RIGHT", 6, 0)

            if spec.role ~= "DPS" then
                local tag = K.fs(page, spec.role == "TANK" and "T" or "H", 9,
                    spec.role == "TANK" and "slate" or "good")
                tag:SetPoint("LEFT", specLabel, "RIGHT", 4, 0)
            end

            self.needBoxes[#self.needBoxes + 1] = well
            self:Register(id,
                function() return NS.db.needs[class.key][spec.key] or 0 end,
                function(v) NS.db.needs[class.key][spec.key] = tonumber(v) or 0 end,
                function() well:Set(tostring(NS.db.needs[class.key][spec.key] or 0)) end)
        end

        colHeight[shortest] = colHeight[shortest] + 15 + #class.specs * 20 + 10
    end

    local gridBottom = -20 - math.max(colHeight[1], colHeight[2], colHeight[3])

    self.roleSummary = K.fs(page, "", 11, "ink2")
    self.roleSummary:SetPoint("TOPLEFT", 2, gridBottom - 2)

    local clearNeeds = K.Button(page, "Clear needs", 96, 20, function()
        for _, class in ipairs(NS.CLASSES) do
            for _, spec in ipairs(class.specs) do
                NS.db.needs[class.key][spec.key] = 0
            end
        end
        UI:Apply()
    end)
    clearNeeds:SetPoint("TOPLEFT", 250, gridBottom - 4)
    self.actions.clearNeeds = function()
        for _, class in ipairs(NS.CLASSES) do
            for _, spec in ipairs(class.specs) do NS.db.needs[class.key][spec.key] = 0 end
        end
    end

    -- raid times ---------------------------------------------------
    local timesCap = K.fs(page, "RAID TIMES", 10, "dim")
    timesCap:SetPoint("TOPLEFT", page, "TOPLEFT", gridW + 12, -2)

    local timesNote = K.fs(page, "Blank days are skipped. Two days on the same time get merged.", 9, "dim")
    timesNote:SetPoint("TOPLEFT", page, "TOPLEFT", gridW + 12, -16)
    timesNote:SetWidth(w - gridW - 14)
    if timesNote.SetWordWrap then timesNote:SetWordWrap(true) end

    self.timeBoxes = {}
    for i, day in ipairs(NS.DAYS) do
        local y = -42 - (i - 1) * 24
        local dayLabel = K.fs(page, day.short, 11, "ink2")
        dayLabel:SetPoint("TOPLEFT", gridW + 12, y + 3)

        local well = K.Input(page, w - gridW - 54, 20, {
            maxLetters = 40, size = 11,
            onChange = function(text) NS.db.raidTimes[day.key] = text; UI:Apply() end,
        })
        well:SetPoint("TOPLEFT", gridW + 44, y)
        self.timeBoxes[#self.timeBoxes + 1] = well
        self:Register("time." .. day.key,
            function() return NS.db.raidTimes[day.key] or "" end,
            function(v) NS.db.raidTimes[day.key] = tostring(v or "") end,
            function() well:Set(NS.db.raidTimes[day.key]) end)
    end

    local copyMon = K.Button(page, "Copy Mon to all", 110, 20, function()
        local value = NS.db.raidTimes.monday
        for _, day in ipairs(NS.DAYS) do NS.db.raidTimes[day.key] = value end
        UI:Apply()
    end)
    copyMon:SetPoint("TOPLEFT", gridW + 44, -42 - 7 * 24 - 2)
    self.actions.copyMonday = function()
        local value = NS.db.raidTimes.monday
        for _, day in ipairs(NS.DAYS) do NS.db.raidTimes[day.key] = value end
    end

    local clearTimes = K.Button(page, "Clear", 60, 20, function()
        for _, day in ipairs(NS.DAYS) do NS.db.raidTimes[day.key] = "" end
        UI:Apply()
    end)
    clearTimes:SetPoint("LEFT", copyMon, "RIGHT", 6, 0)
    self.actions.clearTimes = function()
        for _, day in ipairs(NS.DAYS) do NS.db.raidTimes[day.key] = "" end
    end

    -- preview ------------------------------------------------------
    local previewTop = math.min(gridBottom - 30, -250)

    self.previewCap = K.fs(page, "THIS IS WHAT GETS SENT", 10, "dim")
    self.previewCap:SetPoint("TOPLEFT", 2, previewTop)

    self.previewInfo = K.fs(page, "", 10, "dim")
    self.previewInfo:SetPoint("TOPRIGHT", page, "TOPRIGHT", -2, previewTop)
    self.previewInfo:SetJustifyH("RIGHT")

    local overrideBox = CreateFrame("Button", nil, page)
    overrideBox:SetSize(150, 20)
    overrideBox:SetPoint("TOPLEFT", 176, previewTop - 3)
    local obFrame = CreateFrame("Frame", nil, overrideBox)
    obFrame:SetSize(14, 14)
    obFrame:SetPoint("LEFT", overrideBox, "LEFT", 0, 0)
    local obFill = K.tex(obFrame, "ARTWORK", "field")
    local obEdge = K.border(obFrame, "edge")
    local obText = K.fs(overrideBox, "Write my own", 11, "ink2")
    obText:SetPoint("LEFT", obFrame, "RIGHT", 6, 0)

    local syncOverride = function()
        if NS.db.customEnabled then
            obFill:SetColorTexture(K.shade("accent", 1))
            obEdge:set("accent", 1)
            obText:SetTextColor(K.shade("ink"))
        else
            obFill:SetColorTexture(K.shade("field", 1))
            obEdge:set("edge", 1)
            obText:SetTextColor(K.shade("ink2"))
        end
    end

    local setOverride = function(v)
        NS.db.customEnabled = v and true or false
        if NS.db.customEnabled and NS.Util.Trim(NS.db.customText) == "" then
            NS.db.customText = self.lastPreview or ""
        end
        UI:Apply()
    end

    overrideBox:SetScript("OnClick", function() setOverride(not NS.db.customEnabled) end)
    overrideBox:SetScript("OnEnter", function(s)
        obEdge:set("accent", 1)
        if not GameTooltip then return end
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Write my own")
        GameTooltip:AddLine("Ignore the template and send exactly what is in the box. Tokens like {discord} still work.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    overrideBox:SetScript("OnLeave", function()
        syncOverride()
        if GameTooltip then GameTooltip:Hide() end
    end)

    self:Register("override",
        function() return NS.db.customEnabled and true or false end,
        setOverride, syncOverride)
    syncOverride()

    self.previewBox = K.TextArea(page, w, 84, function(text)
        if NS.db.customEnabled then
            NS.db.customText = text
            UI:RefreshPreview(true)
        end
    end)
    self.previewBox:SetPoint("TOPLEFT", 0, previewTop - 18)

    -- No send bar here: the desk owns posting, and two of them would drift.
    local note = K.fs(page, "The channel buttons live on the desk, above the list.", 10, "dim")
    note:SetPoint("TOPLEFT", 2, previewTop - 110)

    return page
end

--------------------------------------------------------------------
-- preview
--------------------------------------------------------------------

local function DescribeLength(text)
    local length = #text
    local parts = #NS.Util.SplitMessage(text, NS.CHAT_LIMIT)
    local colour = length <= NS.CHAT_LIMIT and "good" or "gold"
    return NS.T.text(colour, length .. " characters") .. NS.T.text("dim",
        "  -  " .. (parts <= 1 and "one message" or (parts .. " messages, back to back")))
end

function UI:RefreshPreview(keepBoxText)
    if not self.previewBox then return end

    local override = NS.db.customEnabled
    local text, missing = NS.Message:Build()
    self.lastPreview = text

    local display = text
    if text == "" then
        display = override and "Type or paste your message here."
            or "Nothing yet. Set some class needs, or write a template on the Message tab."
    end

    if not keepBoxText then
        self.previewBox:Set(override and (NS.db.customText or "") or display)
    end
    self.previewBox.readOnly = not override
    self.previewBox.edge:set(override and "accent" or "edge", 1)
    self.previewCap:SetText(override and "YOUR MESSAGE, SENT EXACTLY AS TYPED" or "THIS IS WHAT GETS SENT")

    local info = text == "" and "" or DescribeLength(text)
    if #missing > 0 then
        info = info .. "  " .. NS.T.text("gold", "empty: " .. table.concat(missing, " "))
    end
    self.previewInfo:SetText(info)

    if self.msgPreviewBox then
        self.msgPreviewBox:Set(display)
        self.msgPreviewInfo:SetText(info)
    end

    local tanks, healers, dps = NS.Message:RoleCounts()
    if self.roleSummary then
        self.roleSummary:SetText(string.format("Total %d      %s   %s   %s",
            tanks + healers + dps,
            NS.T.text("slate", tanks .. " tanks"),
            NS.T.text("good", healers .. " healers"),
            NS.T.text("warn", dps .. " dps")))
    end

end
