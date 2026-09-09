-- Nebbinator - UI/MainWindow.lua

local ADDON, NS = ...
local U, W = NS.Util, NS.W
local T = NS.T

NS.MainWindow = {}
local MW = NS.MainWindow

local WIDTH, HEIGHT = 720, 600
local TABS = { "Recruit", "Message", "Auto-reply", "Quick replies" }

function MW:Initialize()
    if self.frame then return end

    local f = W.Window("NebbinatorFrame", WIDTH, HEIGHT, "Nebbinator", "main")
    self.frame = f
    f.titleText:SetText("Nebbinator  " .. T.text("muted", "v" .. NS.VERSION))

    self.msgFields = {}
    self.pages = {}
    for i = 1, #TABS do
        local page = CreateFrame("Frame", nil, f)
        page:SetPoint("TOPLEFT", 0, -66)
        page:SetPoint("BOTTOMRIGHT", 0, 46)
        page:Hide()
        self.pages[i] = page
    end

    self.tabButtons = W.Tabs(f, TABS, function(index) self:SelectTab(index) end)

    self:BuildRecruitPage(self.pages[1])
    self:BuildMessagePage(self.pages[2])
    self:BuildAutoReplyPage(self.pages[3])
    self:BuildQuickRepliesPage(self.pages[4])
    self:BuildFooter(f)

    f:SetScript("OnShow", function()
        self:Refresh()
        self:UpdatePreview()
    end)

    self:SelectTab(1)
end

-- Whichever text is actually driving the ad right now.
function MW:AdText()
    if NS.db.customEnabled then return NS.db.customText or "" end
    local template = NS.Message:ActiveTemplate()
    return template and template.text or ""
end

function MW:SetAdText(text)
    if NS.db.customEnabled then
        NS.db.customText = text
    else
        local template = NS.Message:ActiveTemplate()
        if template then template.text = text end
    end
    self:Refresh()
    self:UpdatePreview()
end

function MW:AdUsesToken(token)
    return self:AdText():lower():find(token:lower(), 1, true) ~= nil
end

function MW:SelectTab(index)
    for i, page in ipairs(self.pages) do
        if i == index then page:Show() else page:Hide() end
    end
    W.SetTabSelected(self.tabButtons, index)
    self.currentTab = index
    if index == 1 then self:RebuildChannelButtons() end
end

--------------------------------------------------------------------
-- Tab 1: Recruit
--------------------------------------------------------------------

function MW:BuildRecruitPage(page)
    self.needBoxes = {}

    W.Header(page, "What we need", 16, -4)

    -- Three balanced columns: each class goes to the shortest column,
    -- so nothing overflows the way the v1 fixed layout did.
    local colX      = { 16, 156, 296 }
    local colHeight = { 0, 0, 0 }

    for _, class in ipairs(NS.CLASSES) do
        local shortest = 1
        for c = 2, 3 do
            if colHeight[c] < colHeight[shortest] then shortest = c end
        end

        local x = colX[shortest]
        local y = -24 - colHeight[shortest]
        local r, g, b = U.ClassColor(class.file)

        local label = W.Label(page, class.name, x, y, "GameFontNormalSmall", r, g, b)
        label:SetWidth(120)

        for i, spec in ipairs(class.specs) do
            local rowY = y - 14 - (i - 1) * 19

            local box = W.EditBox(page, 26, {
                numeric = true, maxLetters = 2,
                onChange = function(text)
                    NS.db.needs[class.key][spec.key] = tonumber(text) or 0
                    self:UpdatePreview()
                end,
            })
            box:SetPoint("TOPLEFT", x + 6, rowY)
            box.classKey, box.specKey = class.key, spec.key
            table.insert(self.needBoxes, box)

            local specLabel = W.Label(page, spec.name, 0, 0, "GameFontHighlightSmall")
            specLabel:ClearAllPoints()
            specLabel:SetPoint("LEFT", box, "RIGHT", 6, 0)

            local roleTag = W.Label(page, "", 0, 0, "GameFontDisableSmall")
            roleTag:ClearAllPoints()
            roleTag:SetPoint("LEFT", specLabel, "RIGHT", 4, 0)
            roleTag:SetText(spec.role == "TANK" and "|cFF6699CCT|r"
                or spec.role == "HEALER" and "|cFF66CC66H|r" or "")
        end

        colHeight[shortest] = colHeight[shortest] + 14 + #class.specs * 19 + 12
    end

    self.roleSummary = W.Label(page, "", 16, -24 - math.max(colHeight[1], colHeight[2], colHeight[3]) - 2,
        "GameFontNormalSmall", T.rgb("ink2"))
    self.roleSummary:SetWidth(400)

    local clearBtn = W.Button(page, "Clear needs", 90, 20, function()
        for _, class in ipairs(NS.CLASSES) do
            for _, spec in ipairs(class.specs) do
                NS.db.needs[class.key][spec.key] = 0
            end
        end
        self:Refresh()
        self:UpdatePreview()
    end)
    clearBtn:SetPoint("TOPLEFT", 296, -24 - math.max(colHeight[1], colHeight[2], colHeight[3]) - 6)

    -- Raid times ----------------------------------------------------
    W.Header(page, "Raid times", 440, -4)
    W.Label(page, "Blank days are skipped. Same time on two days gets merged.",
        440, -20, "GameFontDisableSmall")

    self.timeBoxes = {}
    for i, day in ipairs(NS.DAYS) do
        local y = -38 - (i - 1) * 24
        W.Label(page, day.short, 440, y + 2, "GameFontHighlightSmall")
        local box = W.EditBox(page, 180, {
            maxLetters = 40,
            onChange = function(text)
                NS.db.raidTimes[day.key] = text
                self:UpdatePreview()
            end,
        })
        box:SetPoint("TOPLEFT", 478, y)
        box.dayKey = day.key
        table.insert(self.timeBoxes, box)
    end

    local copyBtn = W.Button(page, "Copy Mon to all", 120, 20, function()
        local value = NS.db.raidTimes.monday
        for _, day in ipairs(NS.DAYS) do NS.db.raidTimes[day.key] = value end
        self:Refresh()
        self:UpdatePreview()
    end)
    copyBtn:SetPoint("TOPLEFT", 478, -38 - 7 * 24 - 2)

    local clearTimes = W.Button(page, "Clear", 60, 20, function()
        for _, day in ipairs(NS.DAYS) do NS.db.raidTimes[day.key] = "" end
        self:Refresh()
        self:UpdatePreview()
    end)
    clearTimes:SetPoint("LEFT", copyBtn, "RIGHT", 4, 0)

    -- Preview -------------------------------------------------------
    self.previewHeader = W.Header(page, "This is what gets sent", 16, -252)
    self.previewInfo = W.Label(page, "", 200, -250, "GameFontDisableSmall")
    self.previewInfo:SetWidth(300)
    self.previewInfo:SetJustifyH("RIGHT")
    self.previewInfo:ClearAllPoints()
    self.previewInfo:SetPoint("TOPRIGHT", page, "TOPRIGHT", -16, -250)

    self.overrideCheck = W.Check(page, "Write my own",
        function() return NS.db.customEnabled end,
        function(v)
            NS.db.customEnabled = v
            if v and U.Trim(NS.db.customText) == "" then
                NS.db.customText = self.lastPreview or ""
            end
            self:UpdatePreview()
        end,
        "Ignore the template and send exactly what you type in the box below. Tokens like {discord} still work if you use them.")
    self.overrideCheck:SetPoint("TOPLEFT", 196, -250)

    self.previewBox = W.TextArea(page, WIDTH - 32, 76)
    self.previewBox:SetPoint("TOPLEFT", 16, -268)
    self.previewBox.edit:SetTextColor(T.rgb("ink"))
    self.previewBox.edit:SetScript("OnTextChanged", function(box, userInput)
        if not userInput then return end
        if NS.db.customEnabled then
            NS.db.customText = box:GetText()
            self:UpdatePreview(true)     -- refresh the counter, leave the box alone
        else
            box:SetText(MW.lastPreview or "")   -- read-only while the template drives it
        end
    end)

    -- Send buttons --------------------------------------------------
    W.Header(page, "Send to", 16, -396)
    self.channelHolder = CreateFrame("Frame", nil, page)
    self.channelHolder:SetPoint("TOPLEFT", 16, -414)
    self.channelHolder:SetSize(WIDTH - 32, 87)
    self.channelButtons = {}

    -- Discord link, right here so it can be pasted without leaving the tab.
    W.Header(page, "Discord link", 16, -352)
    self.msgFields.discordRecruit = W.EditBox(page, WIDTH - 150, {
        maxLetters = 255,
        onChange = function(text)
            NS.db.discord = text
            self:UpdatePreview()
            self:UpdateReplyPreview()
        end,
    })
    self.msgFields.discordRecruit:SetPoint("TOPLEFT", 110, -350)
    self.msgFields.discordRecruit.Sync = function(b)
        if not b:HasFocus() then b:SetText(NS.db.discord or "") end
    end
    W.Tooltip(self.msgFields.discordRecruit, "Discord link",
        "Ctrl+V to paste. Used by the {discord} token in your ad and by the auto-reply whisper.")

    self.discordHint = W.Label(page, "", 16, -374, "GameFontDisableSmall")
    self.discordHint:SetWidth(520)

    self.addDiscordBtn = W.Button(page, "Add to ad", 100, 20, function()
        self:SetAdText(U.Trim(self:AdText() .. " Discord: {discord}"))
    end)
    self.addDiscordBtn:SetPoint("TOPLEFT", 570, -372)
    W.Tooltip(self.addDiscordBtn, "Add to ad", "Appends 'Discord: {discord}' so the link goes out with the ad.")
end

function MW:RebuildChannelButtons()
    if not self.channelHolder then return end
    W.SendButtons(self.channelHolder, WIDTH - 36)
end

--------------------------------------------------------------------
-- Tab 2: Message
--------------------------------------------------------------------

function MW:BuildMessagePage(page)
    W.Header(page, "Guild details", 16, -4)

    local function field(labelText, y, width, get, set, tooltip)
        W.Label(page, labelText, 16, y + 3, "GameFontHighlightSmall")
        local box = W.EditBox(page, width, {
            maxLetters = 255,
            onChange = function(text) set(text) self:UpdatePreview() end,
        })
        box:SetPoint("TOPLEFT", 110, y)
        if tooltip then W.Tooltip(box, labelText, tooltip) end
        box.Sync = function(b) if not b:HasFocus() then b:SetText(get() or "") end end
        return box
    end

    self.msgFields.guild = field("Guild name", -24, 220,
        function() return NS.db.guildName end,
        function(v) NS.db.guildName = v end,
        "This only fills the {guild} token. If your ad has no {guild} in it, nothing changes. " ..
        "Leave it blank to use the guild you are actually in.")
    self.msgFields.discord = field("Discord link", -50, 380,
        function() return NS.db.discord end,
        function(v) NS.db.discord = v end,
        "Used by the {discord} token and by the auto-reply.")
    self.msgFields.content = field("Content", -76, 220,
        function() return NS.db.content end,
        function(v) NS.db.content = v end,
        "e.g. Karazhan, SSC/TK, heroics. Used by {content}.")
    self.msgFields.pre = field("Prefix", -102, 380,
        function() return NS.db.preText end,
        function(v) NS.db.preText = v end,
        "Optional text for the {pre} token.")
    self.msgFields.post = field("Suffix", -128, 380,
        function() return NS.db.postText end,
        function(v) NS.db.postText = v end,
        "Optional text for the {post} token.")

    self.guildHint = W.Label(page, "", 340, -21, "GameFontNormalSmall", T.rgb("warn"))
    self.guildHint:SetWidth(230)

    self.addGuildBtn = W.Button(page, "Add <{guild}>", 110, 20, function()
        self:SetAdText(U.Trim("<{guild}> " .. self:AdText()))
    end)
    self.addGuildBtn:SetPoint("TOPLEFT", 580, -25)
    W.Tooltip(self.addGuildBtn, "Add <{guild}>",
        "Puts <{guild}> at the front of your ad so the guild name actually shows up.")

    -- Template picker ------------------------------------------------
    W.Header(page, "Template", 16, -164)

    self.templateDropdown = CreateFrame("Frame", "NebbinatorTemplateDropdown", page, "UIDropDownMenuTemplate")
    self.templateDropdown:SetPoint("TOPLEFT", 80, -160)
    UIDropDownMenu_SetWidth(self.templateDropdown, 200)

    local function InitTemplateDropdown()
        UIDropDownMenu_Initialize(self.templateDropdown, function()
            for i, template in ipairs(NS.db.templates) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = template.name
                info.checked = (NS.db.activeTemplate == i)
                info.func = function()
                    NS.db.activeTemplate = i
                    self:Refresh()
                    self:UpdatePreview()
                    CloseDropDownMenus()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        local active = NS.Message:ActiveTemplate()
        UIDropDownMenu_SetText(self.templateDropdown, active and active.name or "")
    end
    self.InitTemplateDropdown = InitTemplateDropdown
    InitTemplateDropdown()

    local newBtn = W.Button(page, "New", 60, 22, function()
        table.insert(NS.db.templates, { name = "Template " .. (#NS.db.templates + 1), text = "" })
        NS.db.activeTemplate = #NS.db.templates
        self:Refresh()
        self:UpdatePreview()
    end)
    newBtn:SetPoint("TOPLEFT", 300, -161)

    local deleteBtn = W.Button(page, "Delete", 60, 22, function()
        if #NS.db.templates <= 1 then
            U.Print(T.text("warn", "Keep at least one template."))
            return
        end
        table.remove(NS.db.templates, NS.db.activeTemplate)
        NS.db.activeTemplate = 1
        self:Refresh()
        self:UpdatePreview()
    end)
    deleteBtn:SetPoint("LEFT", newBtn, "RIGHT", 4, 0)

    W.Label(page, "Name", 430, -158, "GameFontHighlightSmall")
    self.templateName = W.EditBox(page, 180, {
        maxLetters = 40,
        onChange = function(text)
            local template = NS.Message:ActiveTemplate()
            if template then
                template.name = text
                InitTemplateDropdown()
            end
        end,
    })
    self.templateName:SetPoint("TOPLEFT", 470, -161)

    self.templateArea = W.TextArea(page, WIDTH - 32, 110, function(text)
        local template = NS.Message:ActiveTemplate()
        if template then template.text = text end
        self:UpdatePreview()
    end)
    self.templateArea:SetPoint("TOPLEFT", 16, -188)

    -- Token help ------------------------------------------------------
    W.Header(page, "Tokens (click to insert)", 16, -306)
    local x, y = 16, -324
    for _, token in ipairs(NS.TOKEN_HELP) do
        local b = W.Button(page, token, #token * 7 + 12, 18, function()
            local edit = self.templateArea.edit
            edit:SetFocus()
            edit:Insert(token)
            local template = NS.Message:ActiveTemplate()
            if template then template.text = edit:GetText() end
            self:UpdatePreview()
        end)
        b:SetPoint("TOPLEFT", x, y)
        x = x + b:GetWidth() + 3
        if x > WIDTH - 110 then x = 16 y = y - 21 end
    end

    W.Header(page, "Result", 16, -392)
    self.msgPreviewInfo = W.Label(page, "", 0, 0, "GameFontDisableSmall")
    self.msgPreviewInfo:ClearAllPoints()
    self.msgPreviewInfo:SetPoint("TOPRIGHT", page, "TOPRIGHT", -16, -390)

    self.msgPreviewBox = W.TextArea(page, WIDTH - 32, 78)
    self.msgPreviewBox:SetPoint("TOPLEFT", 16, -408)
    self.msgPreviewBox.edit:SetTextColor(T.rgb("ink"))
    self.msgPreviewBox.edit:SetScript("OnChar", function(box) box:SetText(MW.lastPreview or "") end)

    self.overrideWarning = W.Label(page, "", 16, -390, "GameFontNormalSmall", T.rgb("warn"))
    self.overrideWarning:SetWidth(420)
end

--------------------------------------------------------------------
-- Tab 3: Auto-reply
--------------------------------------------------------------------

function MW:BuildAutoReplyPage(page)
    local settings = function() return NS.db.autoReply end

    W.Label(page, "When someone whispers you, Nebbinator can answer instantly with your Discord link.",
        16, -6, "GameFontHighlightSmall")

    self.replyEnable = W.Check(page, "Auto-reply to whispers",
        function() return settings().enabled end,
        function(v) settings().enabled = v self:Refresh() end,
        "Only replies once per player per cooldown, and never to guild members while 'skip guildies' is on.")
    self.replyEnable:SetPoint("TOPLEFT", 14, -26)

    self.replyAnyMode = W.Check(page, "Reply to every whisper (not just recruitment ones)",
        function() return settings().mode == "any" end,
        function(v) settings().mode = v and "any" or "keywords" self:Refresh() end,
        "Leave this off so friends saying 'hey' don't get the recruitment pitch.")
    self.replyAnyMode:SetPoint("TOPLEFT", 14, -52)

    W.Label(page, "Trigger words", 16, -82, "GameFontHighlightSmall")
    self.keywordBox = W.EditBox(page, WIDTH - 130, {
        maxLetters = 500,
        onChange = function(text) settings().keywords = text end,
        tooltipTitle = "Trigger words",
        tooltip = "Comma separated. The whisper only gets an auto-reply if it contains one of these.",
    })
    self.keywordBox:SetPoint("TOPLEFT", 106, -80)

    W.Label(page, "Reply text (same tokens as the ad)", 16, -110, "GameFontHighlightSmall")
    self.replyArea = W.TextArea(page, WIDTH - 32, 90, function(text)
        settings().text = text
        self:UpdateReplyPreview()
    end)
    self.replyArea:SetPoint("TOPLEFT", 16, -128)

    W.Header(page, "Reply preview", 16, -226)
    self.replyPreview = W.TextArea(page, WIDTH - 32, 60)
    self.replyPreview:SetPoint("TOPLEFT", 16, -244)
    self.replyPreview.edit:SetTextColor(T.rgb("ink"))
    self.replyPreview.edit:SetScript("OnChar", function(s) s:SetText(MW.lastReplyPreview or "") end)

    -- Safety ----------------------------------------------------------
    W.Header(page, "Safety", 16, -314)

    W.Label(page, "Wait", 16, -336, "GameFontHighlightSmall")
    self.cooldownBox = W.EditBox(page, 50, {
        numeric = true, maxLetters = 5,
        onChange = function(text) settings().cooldown = tonumber(text) or 900 end,
        tooltipTitle = "Per-player cooldown",
        tooltip = "Seconds before the same player can be auto-replied to again.",
    })
    self.cooldownBox:SetPoint("TOPLEFT", 50, -334)
    W.Label(page, "seconds before replying to the same player again", 108, -336, "GameFontDisableSmall")

    W.Label(page, "Max", 16, -360, "GameFontHighlightSmall")
    self.rateBox = W.EditBox(page, 50, {
        numeric = true, maxLetters = 3,
        onChange = function(text) settings().maxPerMinute = tonumber(text) or 6 end,
        tooltipTitle = "Rate cap",
        tooltip = "Hard brake. Auto-replies stop for the rest of the minute once this many have gone out.",
    })
    self.rateBox:SetPoint("TOPLEFT", 50, -358)
    W.Label(page, "auto-replies per minute", 108, -360, "GameFontDisableSmall")

    self.skipGuildies = W.Check(page, "Never auto-reply to guild members",
        function() return settings().skipGuildies end,
        function(v) settings().skipGuildies = v end)
    self.skipGuildies:SetPoint("TOPLEFT", 14, -382)

    self.soundCheck = W.Check(page, "Alert sound",
        function() return settings().playSound end,
        function(v) settings().playSound = v end)
    self.soundCheck:SetPoint("TOPLEFT", 14, -402)

    local soundItems = {}
    for _, sound in ipairs(NS.SOUNDS) do
        table.insert(soundItems, { value = sound.key, text = sound.name })
    end
    self.soundDropdown = W.Dropdown(page, 130, soundItems,
        function() return settings().sound end,
        function(v)
            settings().sound = v
            U.PlayAlert(v)
        end)
    self.soundDropdown:SetPoint("TOPLEFT", 118, -398)

    local testSound = W.Button(page, "Play it", 70, 22, function()
        U.PlayAlert(settings().sound)
    end)
    testSound:SetPoint("TOPLEFT", 300, -401)
    W.Tooltip(testSound, "Play it", "Hear the alert. Ready check is deliberately not in the list.")

    self.soundOnlyNew = W.Check(page, "Only for the first message from someone new",
        function() return settings().soundOnlyNew end,
        function(v) settings().soundOnlyNew = v end,
        "Off means every whisper from anyone on the list dings.")
    self.soundOnlyNew:SetPoint("TOPLEFT", 14, -426)

    self.leadCheck = W.Check(page, "Also watch chat channels for people posting \"LF guild\"",
        function() return NS.db.leadFinder end,
        function(v) NS.db.leadFinder = v end,
        "Adds them to your responders list as leads. Nothing is sent to them automatically.")
    self.leadCheck:SetPoint("TOPLEFT", 14, -450)

    local testBtn = W.Button(page, "Send the reply to myself", 180, 22, function()
        NS.Message:SendWhisper(UnitName("player"), NS.Message:Render(settings().text))
    end)
    testBtn:SetPoint("TOPLEFT", 470, -450)
end

--------------------------------------------------------------------
-- Tab 4: Quick replies
--------------------------------------------------------------------

function MW:BuildQuickRepliesPage(page)
    W.Label(page, "Four canned whispers. Each one gets a button on every responder row - click it and that player gets the text below.",
        16, -6, "GameFontHighlightSmall")
    W.Label(page, "The button label is what fits on the button. Tokens work here too ({times}, {discord}, {guild}).",
        16, -22, "GameFontDisableSmall")

    self.quickWidgets = {}

    for i = 1, 4 do
        local top = -44 - (i - 1) * 106

        W.Label(page, "Button " .. i, 16, top + 4, "GameFontNormalSmall", T.rgb("ink"))

        local labelBox = W.EditBox(page, 150, {
            maxLetters = 18,
            onChange = function(text)
                NS.db.quickReplies[i].label = text
                NS.RespondersWindow:Refresh()
            end,
        })
        labelBox:SetPoint("TOPLEFT", 86, top)

        local sendSelf = W.Button(page, "Test on myself", 120, 20, function()
            NS.Message:SendWhisper(UnitName("player"), NS.Message:Render(NS.db.quickReplies[i].text))
        end)
        sendSelf:SetPoint("TOPLEFT", 250, top)

        local counter = W.Label(page, "", 0, 0, "GameFontDisableSmall")
        counter:ClearAllPoints()
        counter:SetPoint("TOPRIGHT", page, "TOPRIGHT", -16, top + 3)

        local area = W.TextArea(page, WIDTH - 102, 66, function(text)
            NS.db.quickReplies[i].text = text
            self:UpdateQuickCounters()
        end)
        area:SetPoint("TOPLEFT", 86, top - 24)

        self.quickWidgets[i] = { label = labelBox, area = area, counter = counter }
    end
end

function MW:UpdateQuickCounters()
    if not self.quickWidgets then return end
    for i, widget in ipairs(self.quickWidgets) do
        local text = NS.Message:Render(NS.db.quickReplies[i].text)
        if text == "" then
            widget.counter:SetText(T.text("muted", "empty"))
        else
            local parts = #U.SplitMessage(text, NS.CHAT_LIMIT)
            widget.counter:SetText(#text .. " characters" ..
                (parts > 1 and ("  " .. T.text("gold", "splits into " .. parts .. " whispers")) or ""))
        end
    end
end

--------------------------------------------------------------------
-- Footer
--------------------------------------------------------------------

function MW:BuildFooter(f)
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(T.rgba("line", 1))
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 14, 40)
    line:SetPoint("BOTTOMRIGHT", -14, 40)

    self.previewCheck = W.Check(f, "Preview mode (print, don't send)",
        function() return NS.db.previewMode end,
        function(v) NS.db.previewMode = v self:Refresh() end,
        "Safe way to test. Everything is printed to your chat frame instead of being sent.")
    self.previewCheck:SetPoint("BOTTOMLEFT", 14, 10)

    self.respondersBtn = W.Button(f, "Responders", 130, 24, function()
        NS.RespondersWindow:Toggle()
    end)
    self.respondersBtn:SetPoint("BOTTOMRIGHT", -100, 10)

    local closeBtn = W.Button(f, "Close", 80, 24, function() f:Hide() end)
    closeBtn:SetPoint("BOTTOMRIGHT", -14, 10)
end

--------------------------------------------------------------------
-- Refresh / preview
--------------------------------------------------------------------

function MW:Refresh()
    if not self.frame then return end

    for _, box in ipairs(self.needBoxes) do
        if not box:HasFocus() then
            box:SetText(tostring(NS.db.needs[box.classKey][box.specKey] or 0))
        end
    end
    for _, box in ipairs(self.timeBoxes) do
        if not box:HasFocus() then box:SetText(NS.db.raidTimes[box.dayKey] or "") end
    end
    for _, box in pairs(self.msgFields or {}) do
        if box.Sync then box:Sync() end
    end

    local template = NS.Message:ActiveTemplate()
    if template then
        if not self.templateName:HasFocus() then self.templateName:SetText(template.name or "") end
        if not self.templateArea.edit:HasFocus() then self.templateArea.edit:SetText(template.text or "") end
    end
    if self.InitTemplateDropdown then self.InitTemplateDropdown() end

    local settings = NS.db.autoReply
    if not self.keywordBox:HasFocus() then self.keywordBox:SetText(settings.keywords or "") end
    if not self.replyArea.edit:HasFocus() then self.replyArea.edit:SetText(settings.text or "") end
    if not self.cooldownBox:HasFocus() then self.cooldownBox:SetText(tostring(settings.cooldown or 900)) end
    if not self.rateBox:HasFocus() then self.rateBox:SetText(tostring(settings.maxPerMinute or 6)) end

    for _, check in ipairs({ self.replyEnable, self.replyAnyMode, self.skipGuildies,
                             self.soundCheck, self.leadCheck, self.previewCheck,
                             self.overrideCheck, self.soundOnlyNew }) do
        if check and check.Sync then check:Sync() end
    end

    for i, widget in ipairs(self.quickWidgets or {}) do
        local reply = NS.db.quickReplies[i]
        if not widget.label:HasFocus() then widget.label:SetText(reply.label or "") end
        if not widget.area.edit:HasFocus() then widget.area.edit:SetText(reply.text or "") end
    end
    self:UpdateQuickCounters()

    if self.soundDropdown and self.soundDropdown.Sync then self.soundDropdown:Sync() end

    self:RefreshBadge()
    self:UpdateReplyPreview()
    self:UpdatePreview()
end

function MW:RefreshBadge()
    if not self.respondersBtn then return end
    local new = NS.Responders:CountNew()
    if new > 0 then
        self.respondersBtn:SetText("Responders " .. T.text("gold", "(" .. new .. " new)"))
    else
        self.respondersBtn:SetText("Responders")
    end
end

local function DescribeLength(text)
    local length = #text
    local parts = #U.SplitMessage(text, NS.CHAT_LIMIT)
    local color = length <= NS.CHAT_LIMIT and "good" or "gold"
    return T.text(color, length .. " characters") .. " - " ..
        (parts <= 1 and "one message" or (parts .. " messages, sent back to back"))
end

function MW:UpdatePreview(keepBoxText)
    if not self.frame then return end
    local override = NS.db.customEnabled
    local text, missing = NS.Message:Build()
    self.lastPreview = text

    local display = text
    if text == "" then
        display = override
            and "Type or paste your message here."
            or "Nothing yet. Set some class needs, or write a template on the Message tab."
    end

    if not keepBoxText then
        self.previewBox.edit:SetText(override and (NS.db.customText or "") or display)
    end
    self.msgPreviewBox.edit:SetText(display)

    -- Editable and accent-framed when it is yours to type in.
    self.previewBox.edit:EnableMouse(true)
    self.previewBox:SetBackdropBorderColor(T.rgba(override and "accent" or "line2", 1))
    if self.previewHeader then
        self.previewHeader:SetText(override and "Your message (sent exactly as typed)" or "This is what gets sent")
    end
    if self.overrideWarning then
        self.overrideWarning:SetText(override
            and "The 'Write my own' box on the Recruit tab is on, so this template is not being used."
            or "")
    end

    -- A name or link that never appears in the ad is the most confusing
    -- thing this addon can do, so say so plainly.
    if self.guildHint then
        if self:AdUsesToken("{guild}") then
            self.guildHint:SetText(T.text("good", "In your ad as {guild}."))
            self.addGuildBtn:Hide()
        else
            self.guildHint:SetText("Your ad has no {guild} in it, so this name never shows up ->")
            self.addGuildBtn:Show()
        end
    end
    if self.discordHint then
        if self:AdUsesToken("{discord}") then
            self.discordHint:SetText(T.text("good", "In your ad as {discord}, and the auto-reply uses it too."))
            self.addDiscordBtn:Hide()
        else
            self.discordHint:SetText("Paste it here (Ctrl+V). Your ad has no {discord} in it - the auto-reply whisper still sends it.")
            self.addDiscordBtn:Show()
        end
    end

    local info = text == "" and "" or DescribeLength(text)
    if #missing > 0 then
        info = info .. "  " .. T.text("warn", "empty: " .. table.concat(missing, " "))
    end
    self.previewInfo:SetText(info)
    self.msgPreviewInfo:SetText(info)

    local tanks, healers, dps = NS.Message:RoleCounts()
    if self.roleSummary then
        self.roleSummary:SetText(string.format(
            "Total: %d  |cFF6699CC%d tanks|r  |cFF66CC66%d healers|r  |cFFCC6666%d dps|r",
            tanks + healers + dps, tanks, healers, dps))
    end
end

function MW:UpdateReplyPreview()
    if not self.replyPreview then return end
    local text = NS.Message:Render(NS.db.autoReply.text)
    self.lastReplyPreview = text
    self.replyPreview.edit:SetText(text ~= "" and text or "(empty)")
end

function MW:ResetPosition()
    if not self.frame then return end
    NS.db.windows.main = nil
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER")
end

function MW:Show()   if self.frame then self.frame:Show() end end
function MW:Hide()   if self.frame then self.frame:Hide() end end
function MW:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end
