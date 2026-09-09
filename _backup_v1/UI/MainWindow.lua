-- UI/MainWindow.lua
Nebbinator.MainWindow = {}
local MW = Nebbinator.MainWindow

local WINDOW_WIDTH = 620
local WINDOW_HEIGHT = 550

function MW:Initialize()
    -- Create main window
    self.frame = CreateFrame("Frame", "NebbinatorWindow", UIParent, "BackdropTemplate")
    self.frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    self.frame:SetPoint("CENTER")
    self.frame:SetFrameStrata("DIALOG")
    
    self.frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    
    self.frame:EnableMouse(true)
    self.frame:SetMovable(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    self.frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    self.frame:Hide()
    
    -- Title
    self.frame.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.frame.title:SetPoint("TOP", 0, -16)
    self.frame.title:SetText("Nebbinator")
    
    self:CreateClassSection()
    self:CreateRaidTimesSection()
    self:CreatePreviewSection()
    self:CreateButtons()
end

function MW:CreateClassSection()
    local yOffset = -50
    
    -- Header
    local header = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 20, yOffset)
    header:SetText("Class/Spec Needs")
    header:SetTextColor(1, 0.82, 0)
    
    yOffset = yOffset - 25
    
    -- Class data - reordered
    local classes = {
        {name = "Shaman", color = {0, 0.44, 0.87}, specs = {"Ele", "Resto", "Enh"}, key = "shaman"},
        {name = "Warrior", color = {0.78, 0.61, 0.43}, specs = {"Prot", "DPS"}, key = "warrior"},
        {name = "Priest", color = {1, 1, 1}, specs = {"Holy", "Shadow"}, key = "priest"},
        {name = "Warlock", color = {0.58, 0.51, 0.79}, specs = {"DPS"}, key = "warlock"},
        {name = "Mage", color = {0.25, 0.78, 0.92}, specs = {"DPS"}, key = "mage"},
        {name = "Druid", color = {1, 0.49, 0.04}, specs = {"Resto", "Boomie", "Feral", "Tank"}, key = "druid"},
        {name = "Hunter", color = {0.67, 0.83, 0.45}, specs = {"DPS"}, key = "hunter"},
        {name = "Paladin", color = {0.96, 0.55, 0.73}, specs = {"Prot", "Holy", "Ret"}, key = "paladin"},
        {name = "Rogue", color = {1, 0.96, 0.41}, specs = {"DPS"}, key = "rogue"},
    }
    
    -- 3 columns - better spacing
    local col1X = 20
    local col2X = 150
    local col3X = 280
    
    for i, classData in ipairs(classes) do
        local xPos
        if i <= 5 then
            xPos = col1X
        elseif i == 6 then
            xPos = col2X
        else
            xPos = col3X
        end
        
        local rowY
        if i <= 5 then
            rowY = yOffset - ((i - 1) * 70)
        elseif i == 6 then
            rowY = yOffset  -- Druid at top of column 2
        else
            rowY = yOffset - ((i - 7) * 70)
        end
        
        -- Class name
        local classLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        classLabel:SetPoint("TOPLEFT", xPos, rowY)
        classLabel:SetText(classData.name)
        classLabel:SetTextColor(classData.color[1], classData.color[2], classData.color[3])
        
        -- Spec counters - NUMBER FIRST
        for j, spec in ipairs(classData.specs) do
            local specY = rowY - 15 - (j - 1) * 18
            
            -- Counter box FIRST
            local counter = CreateFrame("EditBox", nil, self.frame, "InputBoxTemplate")
            counter:SetSize(30, 20)
            counter:SetPoint("TOPLEFT", xPos + 10, specY)
            counter:SetAutoFocus(false)
            counter:SetNumeric(true)
            counter:SetMaxLetters(2)
            counter:SetText("0")
            counter:SetScript("OnTextChanged", function(self)
                local num = tonumber(self:GetText()) or 0
                Nebbinator.db.needs[classData.key][spec:lower()] = num
            end)
            
            -- Spec label AFTER
            local specLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            specLabel:SetPoint("LEFT", counter, "RIGHT", 5, 0)
            specLabel:SetText(spec)
            
            local saved = Nebbinator.db.needs[classData.key][spec:lower()]
            if saved and saved > 0 then
                counter:SetText(tostring(saved))
            end
        end
    end
end

function MW:CreateRaidTimesSection()
    local xPos = 410
    local yPos = -50
    
    -- Header
    local header = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", xPos, yPos)
    header:SetText("Raid Times")
    header:SetTextColor(1, 0.82, 0)
    
    yPos = yPos - 25
    
    local days = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}
    
    for i, day in ipairs(days) do
        local rowY = yPos - (i - 1) * 28
        
        local dayLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        dayLabel:SetPoint("TOPLEFT", xPos, rowY)
        dayLabel:SetText(day)
        dayLabel:SetWidth(70)
        dayLabel:SetJustifyH("LEFT")
        
        local timeInput = CreateFrame("EditBox", nil, self.frame, "InputBoxTemplate")
        timeInput:SetSize(100, 20)
        timeInput:SetPoint("LEFT", dayLabel, "RIGHT", 5, 0)
        timeInput:SetAutoFocus(false)
        timeInput:SetMaxLetters(20)
        timeInput:SetText("")
        timeInput:SetScript("OnTextChanged", function(self)
            Nebbinator.db.raidTimes[day:lower()] = self:GetText()
        end)
        
        local saved = Nebbinator.db.raidTimes[day:lower()]
        if saved and saved ~= "" then
            timeInput:SetText(saved)
        end
    end
    
    yPos = yPos - 220
    
    -- Pre-text on right
    local preLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    preLabel:SetPoint("TOPLEFT", xPos, yPos)
    preLabel:SetText("Pre-text:")
    
    local preInput = CreateFrame("EditBox", nil, self.frame, "InputBoxTemplate")
    preInput:SetSize(165, 20)
    preInput:SetPoint("TOPLEFT", xPos, yPos - 18)
    preInput:SetAutoFocus(false)
    preInput:SetMaxLetters(50)
    preInput:SetText(Nebbinator.db.preText or "")
    preInput:SetScript("OnTextChanged", function(self)
        Nebbinator.db.preText = self:GetText()
    end)
    
    yPos = yPos - 48
    
    -- Post-text on right
    local postLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    postLabel:SetPoint("TOPLEFT", xPos, yPos)
    postLabel:SetText("Post-text:")
    
    local postInput = CreateFrame("EditBox", nil, self.frame, "InputBoxTemplate")
    postInput:SetSize(165, 20)
    postInput:SetPoint("TOPLEFT", xPos, yPos - 18)
    postInput:SetAutoFocus(false)
    postInput:SetMaxLetters(50)
    postInput:SetText(Nebbinator.db.postText or "")
    postInput:SetScript("OnTextChanged", function(self)
        Nebbinator.db.postText = self:GetText()
    end)
end

function MW:CreatePreviewSection()
    -- Preview in CENTER column at Rogue level
    local xPos = 150
    local yPos = -260
    
    -- Preview checkbox (big red)
    self.frame.previewCheck = CreateFrame("CheckButton", nil, self.frame, "UICheckButtonTemplate")
    self.frame.previewCheck:SetPoint("TOPLEFT", xPos, yPos)
    self.frame.previewCheck:SetSize(32, 32)
    self.frame.previewCheck:SetChecked(Nebbinator.db.previewMode)
    self.frame.previewCheck:GetCheckedTexture():SetVertexColor(1, 0, 0)
    
    self.frame.previewCheck.text = self.frame.previewCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.frame.previewCheck.text:SetPoint("LEFT", self.frame.previewCheck, "RIGHT", 5, 0)
    self.frame.previewCheck.text:SetText("Message Preview")
    self.frame.previewCheck.text:SetTextColor(1, 0.3, 0.3)
    
    self.frame.previewCheck:SetScript("OnClick", function(self)
        Nebbinator.db.previewMode = self:GetChecked()
    end)
    
    yPos = yPos - 35
    
    -- Update Preview button
    local updateBtn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    updateBtn:SetSize(120, 25)
    updateBtn:SetPoint("TOPLEFT", xPos, yPos)
    updateBtn:SetText("Update Preview")
    updateBtn:SetScript("OnClick", function() self:UpdatePreview() end)
    
    yPos = yPos - 30
    
    -- Preview text display (larger box)
    local scrollFrame = CreateFrame("ScrollFrame", nil, self.frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", xPos, yPos)
    scrollFrame:SetSize(240, 110)
    
    local previewText = CreateFrame("EditBox", nil, scrollFrame)
    previewText:SetMultiLine(true)
    previewText:SetFontObject("GameFontNormalSmall")
    previewText:SetWidth(220)
    previewText:SetAutoFocus(false)
    previewText:EnableMouse(false)
    scrollFrame:SetScrollChild(previewText)
    
    self.frame.previewText = previewText
    
    -- Border around preview
    local border = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    border:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", -5, 5)
    border:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 25, -5)
    border:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    border:SetBackdropColor(0, 0, 0, 0.8)
    border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
end

function MW:CreateButtons()
    -- Responders button
    local respondersBtn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    respondersBtn:SetSize(100, 30)
    respondersBtn:SetPoint("BOTTOMLEFT", 20, 12)
    respondersBtn:SetText("Responders")
    respondersBtn:SetScript("OnClick", function()
        if Nebbinator.RespondersWindow then
            Nebbinator.RespondersWindow:Toggle()
        end
    end)
    
    -- Yell button
    local yellBtn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    yellBtn:SetSize(70, 30)
    yellBtn:SetPoint("BOTTOM", -130, 12)
    yellBtn:SetText("Yell")
    yellBtn:SetScript("OnClick", function() self:SendMessage("YELL") end)
    
    -- Channel 1 button
    local chan1Btn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    chan1Btn:SetSize(70, 30)
    chan1Btn:SetPoint("BOTTOM", -55, 12)
    chan1Btn:SetText("/1 Gen")
    chan1Btn:SetScript("OnClick", function() self:SendMessage("CHANNEL", 1) end)
    
    -- Channel 2 button
    local chan2Btn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    chan2Btn:SetSize(70, 30)
    chan2Btn:SetPoint("BOTTOM", 20, 12)
    chan2Btn:SetText("/2 Trade")
    chan2Btn:SetScript("OnClick", function() self:SendMessage("CHANNEL", 2) end)
    
    -- Channel 3 button
    local chan3Btn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    chan3Btn:SetSize(70, 30)
    chan3Btn:SetPoint("BOTTOM", 95, 12)
    chan3Btn:SetText("/3 LFG")
    chan3Btn:SetScript("OnClick", function() self:SendMessage("CHANNEL", 3) end)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 30)
    closeBtn:SetPoint("BOTTOMRIGHT", -20, 12)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() self:Hide() end)
end

function MW:BuildMessage()
    local parts = {}
    
    -- Pre-text (prefix)
    local preText = Nebbinator.db.preText
    if preText and preText ~= "" then
        table.insert(parts, preText)
    end
    
    -- Build needs list
    local needs = {}
    for class, specs in pairs(Nebbinator.db.needs) do
        for spec, count in pairs(specs) do
            if count > 0 then
                local className = class:sub(1,1):upper() .. class:sub(2)
                local specName = spec:sub(1,1):upper() .. spec:sub(2)
                table.insert(needs, count .. " " .. specName .. " " .. className)
            end
        end
    end
    
    for _, need in ipairs(needs) do
        table.insert(parts, need)
    end
    
    -- Raid times
    local times = {}
    for day, time in pairs(Nebbinator.db.raidTimes) do
        if time and time ~= "" then
            local dayName = day:sub(1,1):upper() .. day:sub(2)
            table.insert(times, dayName .. " " .. time)
        end
    end
    
    if #times > 0 then
        table.insert(parts, "Raid Times:")
        for _, time in ipairs(times) do
            table.insert(parts, time)
        end
    end
    
    -- Post-text (suffix)
    local postText = Nebbinator.db.postText
    if postText and postText ~= "" then
        table.insert(parts, postText)
    end
    
    return table.concat(parts, " - ")
end

function MW:UpdatePreview()
    local message = self:BuildMessage()
    
    if self.frame.previewText then
        if message == "" then
            self.frame.previewText:SetText("(Fill in pre-text, class needs, raid times, or post-text)")
        else
            self.frame.previewText:SetText(message)
        end
    end
end

function MW:SendMessage(chatType, channel)
    local message = self:BuildMessage()
    
    if message == "" then
        print("|cFFFFD700Nebbinator|r: No message to send! Fill in some info.")
        return
    end
    
    local previewMode = Nebbinator.db.previewMode
    
    if previewMode then
        print("|cFFFF0000[PREVIEW MODE - NOT SENT]|r")
        if chatType == "YELL" then
            print("|cFFFFD700[YELL]|r " .. message)
        elseif chatType == "CHANNEL" then
            print("|cFFFFD700[Channel " .. channel .. "]|r " .. message)
        end
    else
        if chatType == "YELL" then
            SendChatMessage(message, "YELL")
        elseif chatType == "CHANNEL" then
            SendChatMessage(message, "CHANNEL", nil, channel)
        end
        print("|cFFFFD700Nebbinator|r: Message sent!")
    end
end

function MW:Show()
    if not self.frame then
        self:Initialize()
    end
    self.frame:Show()
end

function MW:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function MW:Toggle()
    if not self.frame then
        self:Initialize()
    end
    
    if self.frame:IsVisible() then
        self:Hide()
    else
        self:Show()
    end
end
