-- Nebbinator :: UI/Pages/Message.lua
-- Guild details, saved templates, and the tokens that fill them in.

local ADDON, NS = ...
local K  = NS.Kit
local UI = NS.UI

function UI:BuildMessage(page)
    local w = UI.colW(page)
    local y = -2

    y = self:Caption(page, y, "guild details")

    y = self:Field(page, y, "guildName", "Guild name", 96,
        function() return NS.db.guildName end,
        function(v) NS.db.guildName = v end,
        "Only fills the {guild} token. Blank uses the guild you are actually in.")

    y = self:Field(page, y, "discord", "Discord link", 96,
        function() return NS.db.discord end,
        function(v) NS.SetDiscord(v) end,
        "Used by {discord} in the ad and by the auto-reply whisper.")

    y = self:Field(page, y, "content", "Content", 96,
        function() return NS.db.content end,
        function(v) NS.db.content = v end,
        "Karazhan, SSC/TK, heroics. Fills the {content} token.")

    y = self:Field(page, y, "preText", "Prefix", 96,
        function() return NS.db.preText end,
        function(v) NS.db.preText = v end, "Optional text for the {pre} token.")

    y = self:Field(page, y, "postText", "Suffix", 96,
        function() return NS.db.postText end,
        function(v) NS.db.postText = v end, "Optional text for the {post} token.")

    -- a name or a link that never appears in the ad is the most confusing
    -- thing this addon can do, so it says so, right here, with a fix
    self.guildHint = K.fs(page, "", 10, "gold")
    self.guildHint:SetPoint("TOPLEFT", 2, y - 2)
    self.guildHint:SetWidth(w - 230)
    if self.guildHint.SetWordWrap then self.guildHint:SetWordWrap(true) end

    self.addGuildBtn = K.Button(page, "Add <{guild}>", 104, 20, function()
        UI:SetAdText(NS.Util.Trim("<{guild}> " .. UI:AdText()))
    end)
    self.addGuildBtn:SetPoint("TOPRIGHT", page, "TOPRIGHT", -116, y - 2)
    self.addGuildBtn:SetTip("Add <{guild}>", "Puts the guild name at the front of your ad.")

    self.addDiscordBtn = K.Button(page, "Add {discord}", 104, 20, function()
        UI:SetAdText(NS.Util.Trim(UI:AdText() .. " Discord: {discord}"))
    end)
    self.addDiscordBtn:SetPoint("TOPRIGHT", page, "TOPRIGHT", -2, y - 2)
    self.addDiscordBtn:SetTip("Add {discord}", "Appends the Discord link to the end of your ad.")

    self.actions.addGuildToken   = function() UI:SetAdText(NS.Util.Trim("<{guild}> " .. UI:AdText())) end
    self.actions.addDiscordToken = function() UI:SetAdText(NS.Util.Trim(UI:AdText() .. " Discord: {discord}")) end

    y = y - 26

    -- templates ----------------------------------------------------
    y = self:Caption(page, y, "template")

    self.templateStrip = CreateFrame("Frame", nil, page)
    self.templateStrip:SetPoint("TOPLEFT", 2, y)
    self.templateStrip:SetSize(w, 22)
    self.templateTabs = {}

    local newBtn = K.Button(page, "New", 54, 20, function()
        table.insert(NS.db.templates, { name = "Template " .. (#NS.db.templates + 1), text = "" })
        NS.db.activeTemplate = #NS.db.templates
        UI:RebuildTemplateStrip()
        UI:Apply()
    end)
    newBtn:SetPoint("TOPRIGHT", page, "TOPRIGHT", -62, y - 1)

    local delBtn = K.Button(page, "Delete", 54, 20, function()
        if #NS.db.templates <= 1 then
            NS.Util.Print(NS.T.text("warn", "Keep at least one template."))
            return
        end
        table.remove(NS.db.templates, NS.db.activeTemplate)
        NS.db.activeTemplate = 1
        UI:RebuildTemplateStrip()
        UI:Apply()
    end, "warn")
    delBtn:SetPoint("TOPRIGHT", page, "TOPRIGHT", -2, y - 1)

    self.actions.newTemplate = function()
        table.insert(NS.db.templates, { name = "Template " .. (#NS.db.templates + 1), text = "" })
        NS.db.activeTemplate = #NS.db.templates
        UI:RebuildTemplateStrip()
    end
    self.actions.deleteTemplate = function()
        if #NS.db.templates <= 1 then return end
        table.remove(NS.db.templates, NS.db.activeTemplate)
        NS.db.activeTemplate = 1
        UI:RebuildTemplateStrip()
    end

    y = y - 28

    local nameLabel = K.fs(page, "Name", 11, "ink2")
    nameLabel:SetPoint("TOPLEFT", 2, y - 3)
    self.templateName = K.Input(page, 200, 20, {
        maxLetters = 40, size = 11,
        onChange = function(text)
            local template = NS.Message:ActiveTemplate()
            if template then template.name = text; UI:RebuildTemplateStrip() end
        end,
    })
    self.templateName:SetPoint("TOPLEFT", 44, y)
    self:Register("templateName",
        function() local t = NS.Message:ActiveTemplate(); return t and t.name or "" end,
        function(v) local t = NS.Message:ActiveTemplate(); if t then t.name = tostring(v or "") end end,
        function() local t = NS.Message:ActiveTemplate(); self.templateName:Set(t and t.name or "") end)

    y = y - 26

    self.templateArea = K.TextArea(page, w, 74, function(text)
        local template = NS.Message:ActiveTemplate()
        if template then template.text = text end
        UI:RefreshPreview()
    end)
    self.templateArea:SetPoint("TOPLEFT", 0, y)
    self:Register("templateText",
        function() local t = NS.Message:ActiveTemplate(); return t and t.text or "" end,
        function(v) local t = NS.Message:ActiveTemplate(); if t then t.text = tostring(v or "") end end,
        function() local t = NS.Message:ActiveTemplate(); self.templateArea:Set(t and t.text or "") end)

    y = y - 82

    -- tokens -------------------------------------------------------
    y = self:Caption(page, y, "tokens - click to insert")
    local x = 2
    for _, token in ipairs(NS.TOKEN_HELP) do
        local b = K.Button(page, token, #token * 6 + 16, 18, function()
            local edit = UI.templateArea.edit
            edit:SetFocus()
            edit:Insert(token)
            local template = NS.Message:ActiveTemplate()
            if template then template.text = edit:GetText() end
            UI:RefreshPreview()
        end)
        if x + b:GetWidth() > w then x = 2; y = y - 20 end
        b:SetPoint("TOPLEFT", x, y)
        x = x + b:GetWidth() + 3
    end
    y = y - 26

    -- result -------------------------------------------------------
    self.msgPreviewCap = K.fs(page, "RESULT", 10, "dim")
    self.msgPreviewCap:SetPoint("TOPLEFT", 2, y)
    self.msgPreviewInfo = K.fs(page, "", 10, "dim")
    self.msgPreviewInfo:SetPoint("TOPRIGHT", page, "TOPRIGHT", -2, y)
    self.msgPreviewInfo:SetJustifyH("RIGHT")

    self.msgPreviewBox = K.TextArea(page, w, 56, nil, true)
    self.msgPreviewBox:SetPoint("TOPLEFT", 0, y - 16)

    self.overrideWarning = K.fs(page, "", 10, "gold")
    self.overrideWarning:SetPoint("TOPLEFT", 2, y - 78)
    self.overrideWarning:SetWidth(w - 4)
    if self.overrideWarning.SetWordWrap then self.overrideWarning:SetWordWrap(true) end

    self:RebuildTemplateStrip()
    return page
end

-- Whichever text is actually driving the ad right now: the active template,
-- or the "write my own" box if that is on.
function UI:AdText()
    if NS.db.customEnabled then return NS.db.customText or "" end
    local template = NS.Message:ActiveTemplate()
    return template and template.text or ""
end

function UI:SetAdText(text)
    if NS.db.customEnabled then
        NS.db.customText = text
    else
        local template = NS.Message:ActiveTemplate()
        if template then template.text = text end
    end
    self:Apply()
end

function UI:AdUsesToken(token)
    return self:AdText():lower():find(token:lower(), 1, true) ~= nil
end

-- The template picker is a row of pills, not a dropdown: with three or four
-- templates you can see them all and switch in one click.
function UI:RebuildTemplateStrip()
    if not self.templateStrip then return end
    for _, b in ipairs(self.templateTabs) do b:Hide() end
    wipe(self.templateTabs)

    local x = 0
    for i, template in ipairs(NS.db.templates) do
        local label = template.name or ("Template " .. i)
        local b = K.Button(self.templateStrip, label, 0, 20, function()
            NS.db.activeTemplate = i
            UI:RebuildTemplateStrip()
            UI:Apply()
        end)
        b:SetWidth(math.max(56, math.floor((b.text:GetStringWidth() or 40) + 0.5) + 20))
        if x + b:GetWidth() > (UI.colW(self.pages.Message) - 130) then break end
        b:SetPoint("TOPLEFT", x, 0)
        b:SetMarked(NS.db.activeTemplate == i)
        x = x + b:GetWidth() + 4
        self.templateTabs[#self.templateTabs + 1] = b
    end
end

function UI:RefreshMessageHints()
    if not self.guildHint then return end

    if self:AdUsesToken("{guild}") then
        self.guildHint:SetText(NS.T.text("good", "Guild name and Discord link are both in your ad."))
        self.addGuildBtn:Hide()
    else
        self.guildHint:SetText("Your ad has no {guild} in it, so the guild name never shows up.")
        self.addGuildBtn:Show()
    end

    if self:AdUsesToken("{discord}") then
        self.addDiscordBtn:Hide()
        if not self:AdUsesToken("{guild}") then
            self.guildHint:SetText("Your ad has no {guild} in it, so the guild name never shows up.")
        end
    else
        self.addDiscordBtn:Show()
        if self:AdUsesToken("{guild}") then
            self.guildHint:SetText("Your ad has no {discord} in it. The auto-reply whisper still sends it.")
        else
            self.guildHint:SetText("Your ad uses neither {guild} nor {discord}, so neither one shows up in it.")
        end
    end

    self.overrideWarning:SetText(NS.db.customEnabled
        and "\"Write my own\" is on over on the Recruit tab, so this template is not being used."
        or "")
end
