-- UI/RespondersWindow.lua
Nebbinator.RespondersWindow = {}
local RW = Nebbinator.RespondersWindow

local WINDOW_WIDTH = 400
local WINDOW_HEIGHT = 500

function RW:Initialize()
    -- Create responders window
    self.frame = CreateFrame("Frame", "NubbinatorRespondersWindow", UIParent, "BackdropTemplate")
    self.frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    self.frame:SetPoint("CENTER", 250, 0)
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
    self.frame.title:SetText("Responders")
    
    self:CreateScrollList()
    self:CreateButtons()
    
    -- Register for whispers
    self:RegisterEvents()
end

function RW:CreateScrollList()
    -- Scroll frame for responders
    local scrollFrame = CreateFrame("ScrollFrame", nil, self.frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 50)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(340, 1)
    scrollFrame:SetScrollChild(content)
    
    self.scrollFrame = scrollFrame
    self.content = content
    self.responderFrames = {}
end

function RW:CreateButtons()
    -- Clear All button
    local clearBtn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 30)
    clearBtn:SetPoint("BOTTOMLEFT", 20, 12)
    clearBtn:SetText("Clear All")
    clearBtn:SetScript("OnClick", function() self:ClearAll() end)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 30)
    closeBtn:SetPoint("BOTTOMRIGHT", -20, 12)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() self:Hide() end)
end

function RW:RegisterEvents()
    -- Event frame for whispers and /who responses
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
    self.eventFrame:RegisterEvent("FRIENDLIST_UPDATE")  -- This is the one that works!
    
    self.eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "CHAT_MSG_WHISPER" then
            RW:OnWhisper(...)
        elseif event == "FRIENDLIST_UPDATE" then
            RW:OnWhoUpdate()
        end
    end)
    
    self.whoQueue = {}
    self.whoInProgress = false
end

function RW:OnWhisper(message, sender)
    -- Remove realm suffix if present
    sender = sender:gsub("%-.*", "")
    
    -- Add to responders list if not already there
    if not Nebbinator.db.responders[sender] then
        Nebbinator.db.responders[sender] = {
            name = sender,
            message = message,
            timestamp = time(),
            class = "Unknown",
            level = "?",
            guild = "None",
        }
        
        -- Queue /who request
        self:QueueWho(sender)
        
        -- Refresh display
        self:RefreshList()
    end
end

function RW:QueueWho(playerName)
    table.insert(self.whoQueue, playerName)
    self:ProcessWhoQueue()
end

function RW:ProcessWhoQueue()
    if self.whoInProgress or #self.whoQueue == 0 then
        return
    end
    
    local playerName = table.remove(self.whoQueue, 1)
    self.whoInProgress = true
    self.currentWhoTarget = playerName
    
    -- Use C_FriendList API
    if C_FriendList and C_FriendList.SendWho then
        C_FriendList.SendWho("n-" .. playerName)
    else
        -- Fallback: mark as processed
        self.whoInProgress = false
        self.currentWhoTarget = nil
    end
end

function RW:OnWhoUpdate()
    if not self.whoInProgress or not self.currentWhoTarget then
        return
    end
    
    -- Try C_FriendList API
    local numResults = 0
    if C_FriendList and C_FriendList.GetNumWhoResults then
        numResults = C_FriendList.GetNumWhoResults()
    end
    
    if numResults > 0 then
        local info
        if C_FriendList and C_FriendList.GetWhoInfo then
            info = C_FriendList.GetWhoInfo(1)
        end
        
        if info and info.fullName then
            local name = info.fullName:gsub("%-.*", "")
            
            if Nebbinator.db.responders[name] then
                -- classStr is the right field!
                Nebbinator.db.responders[name].class = info.classStr or "Unknown"
                Nebbinator.db.responders[name].level = info.level or "?"
                Nebbinator.db.responders[name].guild = (info.fullGuildName and info.fullGuildName ~= "") and info.fullGuildName or "None"
                
                -- Refresh display
                self:RefreshList()
            end
        end
    end
    
    self.whoInProgress = false
    self.currentWhoTarget = nil
    
    -- Process next in queue after delay
    C_Timer.After(0.5, function() self:ProcessWhoQueue() end)
end

function RW:RefreshList()
    -- Clear existing frames
    for _, frame in ipairs(self.responderFrames) do
        frame:Hide()
        frame:SetParent(nil)
    end
    self.responderFrames = {}
    
    -- Get sorted list
    local sorted = {}
    for name, data in pairs(Nebbinator.db.responders) do
        table.insert(sorted, data)
    end
    
    table.sort(sorted, function(a, b)
        return a.timestamp > b.timestamp
    end)
    
    -- Create frames
    local yOffset = -10
    
    for i, data in ipairs(sorted) do
        local frame = self:CreateResponderFrame(data, yOffset)
        table.insert(self.responderFrames, frame)
        yOffset = yOffset - 80
    end
    
    self.content:SetHeight(math.max(1, math.abs(yOffset)))
    
    -- Force visual update if window open
    if self.frame and self.frame:IsVisible() then
        self.scrollFrame:UpdateScrollChildRect()
    end
end

function RW:CreateResponderFrame(data, yOffset)
    local frame = CreateFrame("Button", nil, self.content, "BackdropTemplate")
    frame:SetSize(320, 70)
    frame:SetPoint("TOPLEFT", 10, yOffset)
    
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    
    -- Make clickable to /who (silent now)
    frame:RegisterForClicks("LeftButtonUp")
    frame:SetScript("OnClick", function()
        self:QueueWho(data.name)
    end)
    
    frame:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
    end)
    
    frame:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    end)
    
    -- Class colors
    local classColors = {
        ["Warrior"] = {0.78, 0.61, 0.43},
        ["Paladin"] = {0.96, 0.55, 0.73},
        ["Hunter"] = {0.67, 0.83, 0.45},
        ["Rogue"] = {1, 0.96, 0.41},
        ["Priest"] = {1, 1, 1},
        ["Shaman"] = {0, 0.44, 0.87},
        ["Mage"] = {0.25, 0.78, 0.92},
        ["Warlock"] = {0.58, 0.51, 0.79},
        ["Druid"] = {1, 0.49, 0.04},
    }
    
    local color = classColors[data.class] or {0.5, 0.5, 0.5}
    
    -- Name and level/class
    local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameText:SetPoint("TOPLEFT", 8, -8)
    nameText:SetText(data.name)
    nameText:SetTextColor(color[1], color[2], color[3])
    
    local infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoText:SetPoint("TOPLEFT", 8, -26)
    infoText:SetText("Level " .. data.level .. " " .. data.class)
    infoText:SetTextColor(0.8, 0.8, 0.8)
    
    -- Guild
    local guildText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    guildText:SetPoint("TOPLEFT", 8, -42)
    guildText:SetText("<" .. data.guild .. ">")
    guildText:SetTextColor(0.6, 0.6, 0.6)
    
    -- Message preview
    local msgText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    msgText:SetPoint("TOPLEFT", 8, -56)
    msgText:SetPoint("TOPRIGHT", -70, -56)
    msgText:SetJustifyH("LEFT")
    msgText:SetText(data.message:sub(1, 40) .. (data.message:len() > 40 and "..." or ""))
    msgText:SetTextColor(0.7, 0.7, 0.7)
    
    -- Remove button
    local removeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    removeBtn:SetSize(60, 20)
    removeBtn:SetPoint("TOPRIGHT", -5, -5)
    removeBtn:SetText("Remove")
    removeBtn:SetScript("OnClick", function(self, button)
        Nebbinator.db.responders[data.name] = nil
        RW:RefreshList()
        -- Stop event propagation so clicking Remove doesn't also trigger /who
        self:GetParent():SetScript("OnClick", nil)
        C_Timer.After(0.1, function()
            if self:GetParent() then
                self:GetParent():SetScript("OnClick", function()
                    print("|cFFFFD700Nebbinator|r: Running /who on " .. data.name)
                    RW:QueueWho(data.name)
                end)
            end
        end)
    end)
    
    return frame
end

function RW:ClearAll()
    Nebbinator.db.responders = {}
    self:RefreshList()
end

function RW:Show()
    if not self.frame then
        self:Initialize()
    end
    self.frame:Show()
    self:RefreshList()
end

function RW:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function RW:Toggle()
    if not self.frame then
        self:Initialize()
    end
    
    if self.frame:IsVisible() then
        self:Hide()
    else
        self:Show()
    end
end
