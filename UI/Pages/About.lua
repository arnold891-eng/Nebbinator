-- Nebbinator :: UI/Pages/About.lua

local ADDON, NS = ...
local K  = NS.Kit
local UI = NS.UI

function UI:BuildAbout(page)
    local y = -2
    y = self:Caption(page, y, "how it works")

    local lines = {
        "Set what you need on Recruit, write the ad on Message, then click a channel to post it.",
        "Nothing is ever posted on a timer. A button click is the only thing that sends an ad.",
        "Every send button counts down its own cooldown and greys out until it is safe again.",
        "",
        "When somebody whispers you they appear on Responders, class already filled in from",
        "the whisper itself. Auto-reply can answer them with your Discord link straight away.",
        "Level and guild need a /who, which Blizzard only allows from a real button click -",
        "that is the Who button, and it is why it cannot happen by itself.",
        "",
        "The four quick replies are on every row. Click one and that player gets it; the",
        "button turns green so you never send the loot rules twice.",
    }
    for _, line in ipairs(lines) do
        local t = K.fs(page, line, 11, line == "" and "dim" or "ink2")
        t:SetPoint("TOPLEFT", page, "TOPLEFT", 2, y)
        y = y - 15
    end

    y = self:Caption(page, y - 10, "commands")
    local cmds = {
        { "/nb",              "open this window" },
        { "/nb r",            "open it on Responders" },
        { "/nb config",       "open it on Settings" },
        { "/nb preview",      "toggle preview mode" },
        { "/nb reply",        "toggle auto-reply" },
        { "/nb discord <url>", "set the Discord link" },
        { "/nb minimap",      "show or hide the minimap button" },
        { "/nb reset",        "put the window back in the middle" },
    }
    for _, pair in ipairs(cmds) do
        local c = K.fs(page, pair[1], 11, "accent")
        c:SetPoint("TOPLEFT", page, "TOPLEFT", 2, y)
        local d = K.fs(page, pair[2], 11, "muted")
        d:SetPoint("TOPLEFT", page, "TOPLEFT", 130, y)
        y = y - 16
    end

    y = self:Caption(page, y - 10, "this build")
    -- the header is a prompt now and carries no version, so it lives here:
    -- it is the first thing worth knowing when a BugGrabber line comes back
    self.aboutVersion = K.fs(page, "", 11, "ink2")
    self.aboutVersion:SetPoint("TOPLEFT", page, "TOPLEFT", 2, y)
    y = y - 16

    local t = K.fs(page, "Colours come from BiSTheme when it is installed, and the same palette inline when it is not. The shared BiS channel answers for any BiS addon in your raid; /bis off is the only thing that mutes it.", 10, "dim")
    t:SetPoint("TOPLEFT", page, "TOPLEFT", 2, y)
    t:SetWidth(UI.colW(page) - 4)
    if t.SetWordWrap then t:SetWordWrap(true) end

    return page
end

function UI:RefreshAbout()
    if not self.aboutVersion then return end
    local lib = _G.LibBiSComm
    self.aboutVersion:SetText("Nebbinator " .. NS.T.text("accent", NS.VERSION) ..
        "     shared channel " ..
        (lib and (NS.T.text("good", "on, minor " .. (lib.MINOR or "?")) )
             or NS.T.text("warn", "missing")))
end
