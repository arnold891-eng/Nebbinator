-- run from the addon root: lua5.1 dev/tests.lua
local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local H = dofile(HERE .. "/harness.lua")
local ROOT = os.getenv("NEB") or (HERE .. "/..")

local FILES = {
    "Libs/BiSTheme/Console.lua", "Libs/LibBiSComm-1.0/LibBiSComm-1.0.lua",
    "Core/Util.lua", "Core/Init.lua", "Core/Message.lua", "Core/Responders.lua",
    "UI/Kit.lua", "UI/Window.lua", "UI/SendBar.lua",
    "UI/Pages/Responders.lua", "UI/Pages/Recruit.lua", "UI/Pages/Message.lua",
    "UI/Pages/Replies.lua", "UI/Pages/Settings.lua", "UI/Pages/About.lua",
    "UI/Minimap.lua",
}

-- an existing v1 profile, so the upgrade path is exercised on every run
_G.NubbinatorDB = {
    needs = { shaman = { resto = 2, ele = 0, enh = 0 },
              druid = { boomie = 1, tank = 1, resto = 0, feral = 0 },
              warrior = { prot = 1, dps = 0 } },
    raidTimes = { tuesday = "5pm", sunday = "5pm server time" },
    preText = "lf raiders", postText = "SSC/TK",
    responders = { Dps4 = { name = "Dps4", message = "are you recruiting?", timestamp = os.time() } },
}

local NS = H.Load(ROOT, FILES)

H.section("load")
H.eq(#H.leaked, 0, "no accidental globals", table.concat(H.leaked, ", "))
NS:Initialize()
H.ok(NS.db ~= nil, "db exists")
H.eq(NS.db.dbVersion, 3, "db upgraded to v3")
H.eq(NS.db.needs.shaman.resto, 2, "v1 needs carried over")
H.eq(NS.db.needs.druid.balance, 1, "v1 boomie -> balance")
H.eq(NS.db.needs.druid.feral, 1, "v1 tank -> feral")
H.eq(NS.db.raidTimes.tuesday, "5pm", "v1 raid times carried over")
H.ok(NS.db.responders.Dps4 ~= nil, "v1 responders carried over")
H.eq(NS.db.windows, nil, "old two-window positions dropped")
H.eq(#NS.db.quickReplies, 4, "four quick replies")

H.section("one window, six tabs")
local UI = NS.UI
H.ok(UI.frame ~= nil, "window built at login")
H.eq(UI.frame:IsShown(), false, "starts hidden")
H.eq(#UI.PAGES, 6, "six pages")
for _, name in ipairs(UI.PAGES) do
    H.ok(UI.pages[name] ~= nil, "page exists: " .. name)
end

for _, name in ipairs(UI.PAGES) do
    UI:ShowTab(name)
    local shownCount = 0
    for other, page in pairs(UI.pages) do
        if page:IsShown() then shownCount = shownCount + 1 end
    end
    H.eq(shownCount, 1, "exactly one page shown for " .. name)
    H.eq(UI:ShownTab(), name, "ShownTab reports " .. name)
    -- assert on the PAINT: the active tab label is really accent-coloured
    local ar, ag, ab = NS.T.rgb("accent")
    H.isColor(UI.tabs[name].label._color, ar, ag, ab, "active tab label is accent: " .. name)
    H.ok(UI.tabs[name].mark:IsShown(), "active tab has its accent bar: " .. name)
    local other = (name == "Recruit") and "Message" or "Recruit"
    local mr, mg, mb = NS.T.rgb("muted")
    H.isColor(UI.tabs[other].label._color, mr, mg, mb, "inactive tab label is muted: " .. other)
    H.ok(not UI.tabs[other].mark:IsShown(), "inactive tab has no bar: " .. other)
end

H.eq(NS.db.uiTab, "About", "last tab remembered")
UI:ShowTab("Responders")

H.section("toggle")
UI:Toggle()
H.eq(UI.frame:IsShown(), true, "toggle opens a closed window")
UI:Toggle()
H.eq(UI.frame:IsShown(), false, "toggle closes an open window")
UI:Toggle("Responders")
H.eq(UI.frame:IsShown(), true, "toggle with a tab opens")
H.eq(UI:ShownTab(), "Responders", "...on that tab")
UI:ShowTab("Recruit")
UI:Toggle("Responders")
H.eq(UI.frame:IsShown(), true, "toggle to another tab keeps it open")
H.eq(UI:ShownTab(), "Responders", "...and switches to it")

H.section("every control round-trips")
local EXPECTED = {
    "need.shaman.resto", "need.druid.balance", "need.warrior.prot", "time.tuesday", "time.sunday",
    "override", "guildName", "discord", "content", "preText", "postText",
    "templateName", "templateText",
    "quick1Label", "quick1Text", "quick4Label", "quick4Text",
    "autoReply", "replyMode", "keywords", "replyText", "replyCooldown", "replyRate", "skipGuildies",
    "previewMode", "sendCooldown", "playSound", "soundOnlyNew", "sound",
    "minimap", "leadFinder", "logsUrl", "customChannels",
}
local ids = {}
for _, id in ipairs(UI:IDs()) do ids[id] = true end
for _, id in ipairs(EXPECTED) do H.ok(ids[id], "control exists: " .. id) end

local SAMPLES = {
    ["need.shaman.resto"] = 3, ["need.druid.balance"] = 2, ["need.warrior.prot"] = 1,
    ["time.tuesday"] = "8-11pm ST", ["time.sunday"] = "7pm",
    guildName = "The Heathens", discord = "discord.gg/heathens", content = "SSC and TK",
    preText = "lf raiders", postText = "toe beans",
    templateName = "Main ad", templateText = "<{guild}> needs {needs}. {times}. {discord}",
    quick1Label = "Times?", quick1Text = "Do the raid times work for you?",
    quick4Label = "Signups", quick4Text = "Sign ups are a must.",
    keywords = "recruit,guild,inv", replyText = "Join us: {discord}",
    replyCooldown = 600, replyRate = 4, logsUrl = "https://x/{name}", customChannels = "world",
    sendCooldown = 25, sound = "ping", replyMode = "any",
}
for id, value in pairs(SAMPLES) do
    H.ok(UI:Set(id, value), "Set works: " .. id)
    H.eq(UI:Get(id), value, "round-trip: " .. id)
end

for _, id in ipairs({ "override", "autoReply", "skipGuildies", "previewMode",
                      "playSound", "soundOnlyNew", "minimap", "leadFinder" }) do
    UI:Set(id, true);  H.eq(UI:Get(id), true,  "toggle on: " .. id)
    UI:Set(id, false); H.eq(UI:Get(id), false, "toggle off: " .. id)
end

H.section("sliders clamp instead of storing junk")
UI:Set("sendCooldown", 9999)
H.eq(NS.db.sendCooldown, 120, "cooldown clamps to the top of its range")
UI:Set("sendCooldown", -50)
H.eq(NS.db.sendCooldown, 3, "cooldown clamps to the bottom")
UI:Set("replyRate", 500)
H.eq(NS.db.autoReply.maxPerMinute, 20, "rate cap clamps")
UI:Set("sendCooldown", 10)

H.section("the window writes the same key the slash command owns")
NS.db.previewMode = false
UI:Set("previewMode", true)
H.eq(NS.db.previewMode, true, "checkbox turned preview mode on")
local before = NS.db.previewMode
UI:Set("previewMode", true)
H.eq(NS.db.previewMode, before, "setting it on again does not flip it back")
SlashCmdList["NEBBINATOR"]("preview")
H.eq(NS.db.previewMode, false, "/nb preview turns the same key off")
H.eq(UI:Get("previewMode"), false, "the checkbox reads the slash command's change")

NS.db.autoReply.enabled = false
UI:Set("autoReply", true)
H.eq(NS.db.autoReply.enabled, true, "checkbox turned auto-reply on")
UI:Set("autoReply", true)
H.eq(NS.db.autoReply.enabled, true, "...and again is a no-op, not a flip")
SlashCmdList["NEBBINATOR"]("reply")
H.eq(NS.db.autoReply.enabled, false, "/nb reply turns the same key off")

NS.db.minimap.hide = false
UI:Set("minimap", false)
H.eq(NS.db.minimap.hide, true, "unchecking the minimap box hides it")
SlashCmdList["NEBBINATOR"]("minimap")
H.eq(NS.db.minimap.hide, false, "/nb minimap shows it again")

SlashCmdList["NEBBINATOR"]("discord discord.gg/fromslash")
H.eq(UI:Get("discord"), "discord.gg/fromslash", "/nb discord reaches the field")

H.section("checkbox paint")
UI:ShowTab("Settings")
UI:Set("leadFinder", true)
UI:Refresh()
local ar, ag, ab = NS.T.rgb("accent")
local found
for _, fr in ipairs(H.frames) do
    if fr._regions then
        for _, region in ipairs(fr._regions) do
            if region._color and math.abs(region._color[1] - ar) < 0.01
               and math.abs(region._color[2] - ag) < 0.01 then found = true end
        end
    end
end
H.ok(found, "a ticked box is really filled with the accent colour")

H.section("no page draws past the bottom of the window")
do
    -- Innervate shipped a page that ran straight off the frame. This is the
    -- arithmetic that would have caught it: everything anchored from the top
    -- of a page must end above the page's own bottom edge.
    local pageH = UI.H - UI.HEADER - 18 - 16
    for _, name in ipairs(UI.PAGES) do
        local page = UI.pages[name]
        local worst, worstBottom = nil, 0
        for _, fr in ipairs(H.frames) do
            local host = fr._parent
            local viaColumn = host and host._parent == page
            if host == page or viaColumn then
                local _, y = fr:OffsetFor("TOPLEFT")
                if y and y < 0 then
                    local bottom = -y + (fr:GetHeight() or 0)
                    if bottom > worstBottom then worst, worstBottom = fr, bottom end
                end
            end
        end
        H.ok(worstBottom <= pageH, "page fits: " .. name,
             ("deepest widget ends at %d, page is %d tall"):format(worstBottom, pageH))
    end
end

H.section("send bar")
UI:ShowTab("Responders")
local bar = UI.respondersSend
H.ok(#bar.buttons >= 8, "a button per channel plus yell/say/guild", #bar.buttons)
local labels = {}
for _, b in ipairs(bar.buttons) do labels[#labels + 1] = b.text:GetText() end
H.ok(table.concat(labels, " "):find("/2 Trade", 1, true) ~= nil, "channels are named and numbered")
H.ok(bar.rows >= 2, "wraps onto more than one row", bar.rows)

NS.db.previewMode = false
NS.db.customEnabled = false
NS.db.templates[NS.db.activeTemplate].text = "<{guild}> needs {needs}. Raids {times}."
local sentBefore = #H.sent
for _, b in ipairs(bar.buttons) do if b.label == "/2 Trade" then b:Click() end end
H.eq(#H.sent - sentBefore, 1, "clicking a channel button posts the ad")
H.eq(H.sent[#H.sent].chatType, "CHANNEL", "...to a channel")
H.eq(H.sent[#H.sent].target, 2, "...the right one")

local trade
for _, b in ipairs(bar.buttons) do if b.label == "/2 Trade" then trade = b end end
UI:UpdateSendTimers()
H.eq(trade.enabled, false, "the button greys out while the cooldown runs")
H.ok(trade.timer:GetText():find("|cff" .. NS.T.hex.warn, 1, true) ~= nil,
     "the countdown is painted in the warn colour", trade.timer:GetText())
local blocked = #H.sent
trade:Click()
H.eq(#H.sent, blocked, "a greyed button cannot post")
H.clock = H.clock + 11
UI:UpdateSendTimers()
H.eq(trade.enabled, true, "it comes back when the cooldown expires")
H.ok(trade.timer:GetText():find("11s", 1, true) ~= nil, "then shows time since", trade.timer:GetText())

H.section("responders")
local R = NS.Responders
R:ClearWithStatus(nil)
R:OnWhisper("hi, are you recruiting? resto shaman here", "Kumlance-Dreamscythe",
    nil, nil, nil, nil, nil, nil, nil, nil, nil, "Player-1-0000ABC")
local entry = NS.db.responders.Kumlance
H.ok(entry ~= nil, "the whisper landed on the list")
H.eq(entry.class, "MAGE", "class came free from the whisper GUID")
H.eq(#H.who, 0, "no protected SendWho fired from an event")

UI:RefreshResponders()
local card = UI.rows[1]
H.ok(card ~= nil, "a card was built")
H.ok(card.name:GetText():find("Kumlance", 1, true) ~= nil, "card shows the name")
H.ok(card.info:GetText():find("press Who", 1, true) ~= nil, "card asks for a Who before it has a level")

card.who:Click()
H.eq(#H.who, 1, "Who fires SendWho exactly once, from the click")
H.filters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM",
    "|Hplayer:Kumlance|h[Kumlance]|h: Level 70 Gnome Mage <Old Guild> - Shattrath City")
R:OnSystemMessage("|Hplayer:Kumlance|h[Kumlance]|h: Level 70 Gnome Mage <Old Guild> - Shattrath City")
H.eq(NS.db.responders.Kumlance.level, 70, "level parsed out of the chat line")
H.eq(NS.db.responders.Kumlance.guild, "Old Guild", "guild parsed too")
UI:RefreshResponders()
H.ok(card.info:GetText():find("Level 70", 1, true) ~= nil, "the card picked it up")

H.section("the card fits inside itself")
do
    -- the arithmetic a screenshot would show: nothing may sit on top of
    -- anything else, and nothing may hang out of the bottom of the card
    local h = card:GetHeight()
    local _, msgY = card.message:OffsetFor("TOPLEFT")
    local msgTop, msgBottom = -msgY, -msgY + (card.message._h or 12)
    local _, actY = card.status:OffsetFor("BOTTOMLEFT")
    local actTop = h - actY - card.status:GetHeight()
    local _, quickY = card.quick[1]:OffsetFor("BOTTOMLEFT")
    local quickTop = h - quickY - card.quick[1]:GetHeight()
    H.ok(msgBottom <= actTop, "the message line clears the action row",
         ("message ends %d, actions start %d"):format(msgBottom, actTop))
    H.ok(actTop + card.status:GetHeight() <= quickTop,
         "the action row clears the quick replies",
         ("actions end %d, quick starts %d"):format(actTop + card.status:GetHeight(), quickTop))
    H.ok(quickTop + card.quick[1]:GetHeight() <= h, "the quick replies stay inside the card")
    local nameX = select(1, card.name:OffsetFor("TOPLEFT"))
    H.ok(nameX >= 8, "the name clears the status stripe", nameX)

    local total = 0
    for i = 1, 6 do total = total + (card.quick[1]:GetWidth() or 0) end
    H.ok(card.quick[1]:GetWidth() * 4 + 9 + 20 <= card:GetWidth(),
         "four quick replies fit across the card")
    local actionsWide = card.status:GetWidth() + card.whisper:GetWidth() + card.discord:GetWidth()
        + card.invite:GetWidth() + card.who:GetWidth() + card.logs:GetWidth()
        + card.remove:GetWidth() + 6 * 4 + 20
    H.ok(actionsWide <= card:GetWidth(), "every action button fits on one row",
         ("needs %d, has %d"):format(actionsWide, card:GetWidth()))
end

H.section("quick replies from the card")
NS.db.previewMode = false
local qBefore = #H.sent
for slot = 1, 4 do card.quick[slot]:Click() end
H.eq(#H.sent - qBefore, 4, "four buttons, four whispers")
H.eq(H.sent[#H.sent].chatType, "WHISPER", "...as whispers")
H.eq(H.sent[#H.sent].target, "Kumlance", "...to that player")
H.eq(NS.db.responders.Kumlance.status, "contacted", "sending one moves them off New")
UI:RefreshResponders()
local gr, gg, gb = NS.T.rgb("good")
H.isColor(card.quick[1].text._color, gr, gg, gb, "a sent quick reply is painted green")

H.section("status pipeline")
R:SetStatus("Kumlance", "new")
card.status:Click("LeftButton")
H.eq(NS.db.responders.Kumlance.status, "contacted", "left click moves the status forward")
card.status:Click("RightButton")
H.eq(NS.db.responders.Kumlance.status, "new", "right click moves it back")

H.section("logs")
NS.db.logsUrl = "https://fresh.warcraftlogs.com/character/us/dreamscythe/{name}"
card.logs:Click()
local box = NS.Kit.copyBox
H.ok(box ~= nil and box:IsShown(), "the copy box opened")
H.eq(box.contents, "https://fresh.warcraftlogs.com/character/us/dreamscythe/kumlance",
     "the address is built and lowercased")
H.ok(box.well.edit._highlighted, "the text is already selected for Ctrl+C")
box.well.edit:Type("oops")
H.eq(box.well.edit:GetText(), box.contents, "typing in it cannot mangle the address")

H.section("write my own")
NS.db.customEnabled = false
NS.db.customText = ""
UI:ShowTab("Recruit")
UI:RefreshPreview()
local generated = UI.lastPreview
UI:Set("override", true)
H.eq(NS.db.customText, generated, "ticking it prefills with what the template just made")
UI.previewBox.edit:Type("<The Heathens> LF chill raiders. {discord}")
H.eq(NS.db.customText, "<The Heathens> LF chill raiders. {discord}", "typing writes the custom text")
NS.db.discord = "discord.gg/heathens"
H.eq((NS.Message:Build()), "<The Heathens> LF chill raiders. discord.gg/heathens",
     "the override is what gets built, tokens and all")
UI:Set("override", false)
H.ok((NS.Message:Build()) ~= "<The Heathens> LF chill raiders. discord.gg/heathens",
     "unticking goes back to the template")
H.ok(NS.db.customText ~= "", "the custom text is kept for next time")

H.section("message hints")
UI:ShowTab("Message")
NS.db.templates[NS.db.activeTemplate].text = "{pre} - {needs} - {times} - {post}"
UI:Refresh()
H.ok(UI.guildHint:GetText():find("{guild}", 1, true) ~= nil, "warns when the ad has no {guild}")
H.ok(UI.addGuildBtn:IsShown(), "and offers the fix")
UI:Run("addGuildToken")
H.ok(UI:AdUsesToken("{guild}"), "the fix adds the token")
UI:Refresh()
H.ok(not UI.addGuildBtn:IsShown(), "the offer goes away once it is in")

H.section("sound")
for _, sound in ipairs(NS.SOUNDS) do
    H.sounds = {}
    NS.Util.PlayAlert(sound.key)
    if sound.key == "none" then
        H.eq(#H.sounds, 0, "no sound plays nothing")
    else
        H.ok(#H.sounds >= 0, "sound resolves: " .. sound.key)
    end
    H.ok(not tostring(sound.kit or ""):find("READY"), "not the ready check: " .. sound.key)
    H.ok(not tostring(sound.file or ""):find("ReadyCheck"), "not the ready check file: " .. sound.key)
end

H.sounds = {}
NS.db.autoReply.playSound = true
NS.db.autoReply.soundOnlyNew = false
NS.db.autoReply.sound = "bell"
R:OnWhisper("recruiting?", "Dps2", nil,nil,nil,nil,nil,nil,nil,nil,nil,nil)
H.eq(#H.sounds, 1, "a whisper dings")

H.section("preview mode really stops the wire")
NS.db.previewMode = true
local pBefore = #H.sent
H.clock = H.clock + 999
UI:UpdateSendTimers()
for _, b in ipairs(bar.buttons) do if b.label == "Yell" then b:Click() end end
H.eq(#H.sent, pBefore, "nothing is sent in preview mode")
UI:PaintSlots()
H.ok(UI.con.slots.preview ~= nil, "and the prompt stands on it")
H.eq(UI.con.slots.preview.colour, "warn", "in the warn colour")
NS.db.previewMode = false
UI:Refresh()
H.ok(UI.con.slots.preview == nil, "slot clears the moment the state ends")

--------------------------------------------------------------------
-- the header is a prompt (BiSTheme 1.1.0, the header law)
--------------------------------------------------------------------

H.section("the BiS> prompt in the header")
UI:Open("Responders")

local BUDGET = UI.W - UI.STRIP - 8
local function plain()
    return (tostring(UI.con:Text()):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
-- Step the clock in small slices, painting every slice. A single 3 s jump
-- expires a 3 s event before it is ever drawn, which is a fact about the test
-- and not about the console.
local function step(seconds, stopWhen)
    local slices = math.max(1, math.floor(seconds / 0.05))
    for _ = 1, slices do
        H.clock = H.clock + 0.05
        UI:PaintConsole()
        if stopWhen and stopWhen() then return true end
    end
    return false
end
local function settle() step(0.6) end
-- wait for a line to appear on the prompt
local function await(text, seconds)
    return step(seconds or 8, function() return plain():find(text, 1, true) ~= nil end)
end

H.ok(UI.con and UI.con.fs == UI.title, "the title FontString is the BiSTheme console")
H.ok(UI.con.words:GetParent() == UI.title:GetParent(), "the words FontString lives in the header too")
H.eq(UI.HEADER, 16, "16 px header, the house bar")
settle()
H.ok(plain():find("^BiS> "), "the line starts BiS> ", plain())
H.ok(plain():find("_$") or plain():find(" $"), "and ends on the cursor", plain())
H.ok(UI.con:Width() <= BUDGET, "prompt fits the header budget (idle)", UI.con:Width())

-- nothing but the prompt and the button strip lives in that bar
H.eq(UI.closeBtn.slot, -3, "close sits at its computed slot")
H.eq(UI.closeBtn:GetWidth(), 12, "12 px wide, so the strip is 15")
H.eq(UI.STRIP, 3 + UI.closeBtn:GetWidth(), "the strip is exactly the button plus its offset")
H.ok(UI.badge == nil and UI.preview == nil, "no badge, no preview pill - both are slots now")
local inHeader = 0
for _, fr in ipairs(H.frames) do if fr._parent == UI.head then inHeader = inHeader + 1 end end
H.eq(inHeader, 1, "one frame in the header: the close button")

-- slots: state that lasts, cleared the moment it ends
NS.db.responders = {}
NS.db.previewMode, NS.db.leadFinder = false, false
NS.db.autoReply.enabled = false
UI:PaintSlots() settle()
H.ok(UI.con.slots.name and UI.con.slots.name.text == "Nebbinator", "the name slot is always there")
H.ok(UI.con.slots["new"] == nil, "no new responders: no count slot")
NS.db.responders.Bob = { name = "Dps3", status = "new", timestamp = os.time(), messages = {} }
NS.db.responders.Dps1 = { name = "Dps1", status = "trial", timestamp = os.time(), messages = {} }
UI:PaintSlots()
H.ok(UI.con.slots["new"].text == "1 new" and UI.con.slots["new"].colour == "gold", "1 new, in gold")
H.ok(UI.con.slots.trial.text == "1 on trial" and UI.con.slots.trial.colour == "good", "1 on trial, in good")

-- the rotation: name now, the count after a cycle, and no hard cut between them
-- drop anything the earlier blocks queued, and let a held line expire, so what
-- we are watching really is the slot rotation
UI:Clear() step(4)
local seen = {}
step(20, function() seen[plain()] = true return false end)
local sawName, sawCount = false, false
for line in pairs(seen) do
    if line:find("Nebbinator", 1, true) then sawName = true end
    if line:find("1 new", 1, true) then sawCount = true end
end
H.ok(sawName and sawCount, "the slots rotate through name and count")

-- Watch one whole cycle boundary go by and record what the words did. The
-- handoff asks for exactly this shape: alpha down, swap at zero, alpha up.
local sawOut, sawMid, sawZero, sawSolid = false, false, false, false
local zeroText
step(12, function()
    local a = UI.con.words:GetAlpha()
    if UI.con.fading == "out" then sawOut = true end
    if sawOut and a > 0 and a < 1 then sawMid = true end
    if sawOut and a == 0 then sawZero = true zeroText = zeroText or plain() end
    if sawZero and a == 1 and not UI.con.fading then sawSolid = true end
    return sawSolid
end)
H.ok(sawOut, "a cycle comes due and the old words start fading")
H.ok(sawMid, "alpha on the way down, not a hard cut")
H.ok(sawZero, "the swap happens at zero")
H.ok(sawSolid, "and the new words come back up solid")

-- the cursor blinks at 2 Hz and is never trimmed away
H.clock = H.clock + 0.5 UI:PaintConsole() local c1 = plain():sub(-1)
H.clock = H.clock + 0.5 UI:PaintConsole() local c2 = plain():sub(-1)
H.ok((c1 == "_" and c2 == " ") or (c1 == " " and c2 == "_"), "cursor blinks", c1 .. c2)

-- events jump the rotation, hold, and queue; and none of it reaches chat
local chat0 = #H.prints
UI:Log("Bob whispered", "gold")
UI:Log("Bob replied", "ink2")
H.ok(await("Bob whispered", 2), "an event takes the prompt first", plain())
H.ok(UI.con:Width() <= BUDGET, "prompt fits while an event is up", UI.con:Width())
H.ok(await("Bob replied", 6), "queued events show one after the other", plain())
H.eq(#H.prints, chat0, "and the chat frame got none of it")

-- a normal recruiting line is nowhere near the budget in a window this wide
UI:Clear() step(7)
UI:Log("Kumlanceroo whispered", "gold")
H.ok(await("Kumlanceroo whispered", 2), "a real event line shows in full", plain())
H.ok(not plain():find("%.%.%."), "and is not trimmed")
-- the net still works: something absurd is cut to the budget, never under the buttons
UI:Clear() step(7)
UI:Log(string.rep("a very long line indeed ", 40), "warn")
step(1)
H.ok(UI.con:Width() <= BUDGET, "an absurd line is trimmed to the budget", UI.con:Width())
H.ok(plain():find("%.%.%."), "trimmed with an ellipsis", plain():sub(1, 40))
UI:Clear() step(7)

-- the addon's own chatter goes through the prompt, not the chat frame
local chat1 = #H.prints
NS.db.previewMode = false
NS.db.templates[NS.db.activeTemplate].text = "<{guild}> needs {needs}"
H.clock = H.clock + 999 UI:UpdateSendTimers()
for _, b in ipairs(UI.respondersSend.buttons) do if b.label == "Yell" then b:Click() end end
H.eq(#H.prints, chat1, "posting the ad says nothing in chat")
H.ok(await("sent to yell", 3), "the prompt says it went", plain())

-- a slash command still answers in chat: that is what chat is for
local chat2 = #H.prints
SlashCmdList["NEBBINATOR"]("help")
H.ok(#H.prints > chat2, "/nb help still answers in the chat frame")

H.section("every responder row fits the card")
NS.db.responders = {}
R:OnWhisper("recruiting? i am a resto shaman with kara gear and logs",
    "Kumlanceroo", nil,nil,nil,nil,nil,nil,nil,nil,nil, "Player-1-1")
NS.db.responders.Kumlanceroo.level = 70
NS.db.responders.Kumlanceroo.className = "Shaman"
NS.db.responders.Kumlanceroo.guild = "Some Very Long Guild Name"
UI:ShowTab("Responders")
UI:RefreshResponders()
for i, card in ipairs(UI.rows) do
    if card:IsShown() then
        H.ok(card.name:GetStringWidth() + card.info:GetStringWidth() + 12 <= card:GetWidth(),
             "row " .. i .. ": name + info fit the card",
             math.floor(card.name:GetStringWidth() + card.info:GetStringWidth() + 12) .. " of " .. card:GetWidth())
    end
end

--------------------------------------------------------------------
-- the shared BiS channel
--------------------------------------------------------------------

H.section("the version has somewhere to live now the header dropped it")
UI:ShowTab("About")
UI:Refresh()
H.ok(UI.aboutVersion:GetText():find(NS.VERSION, 1, true), "About names the running version", UI.aboutVersion:GetText())
H.ok(UI.aboutVersion:GetText():find("shared channel", 1, true), "and whether the shared channel is up")
H.ok(UI.aboutVersion:GetStringWidth() <= UI.colW(UI.pages.About), "and it fits the page")
UI:ShowTab("Responders")

H.section("LibBiSComm is embedded, booted, and never gated by a feature")
local lib = _G.LibBiSComm
H.ok(lib ~= nil, "the lib loaded from Libs/")
H.eq(lib and lib.MINOR, 3, "minor 3, the current one")
H.ok(lib and lib._booted, "booted from Core/Init, not lazily")
-- the stub answers GetAddOnMetadata with "test": if this ever reads a literal
-- like "2.0.1" the version has been hardcoded again and drifted from the TOC
H.eq(lib and lib.addons.Nebbinator, "test", "Nebbinator registered itself with the TOC's version, not a literal")
H.eq(NS.VERSION, "test", "NS.VERSION comes from the TOC")
H.ok(lib:Enabled(), "on by default")
H.eq(NS.db.comm, nil, "nothing persisted until a logout")

-- the hard rule: no Nebbinator setting may mute the raid's channel
for _, id in ipairs({ "autoReply", "previewMode", "leadFinder", "playSound", "minimap" }) do
    UI:Set(id, false)
    H.ok(lib:Enabled(), "turning off " .. id .. " leaves the lib on")
end
UI:Set("minimap", true)

-- /bis off is the user's own switch, and Nebbinator remembers it
local bootFrame
for _, fr in ipairs(H.frames) do
    if fr._events and fr._events.PLAYER_LOGOUT then bootFrame = fr end
end
H.ok(bootFrame ~= nil, "the addon listens for PLAYER_LOGOUT")
SlashCmdList["BISCOMM"]("off")
H.ok(not lib:Enabled(), "/bis off mutes the lib")
bootFrame:Fire("OnEvent", "PLAYER_LOGOUT")
H.eq(NS.db.comm, false, "logout persists the off switch")
SlashCmdList["BISCOMM"]("on")
bootFrame:Fire("OnEvent", "PLAYER_LOGOUT")
H.ok(NS.db.comm == true and lib:Enabled(), "/bis on persists too")

-- and it comes back off on the next login
NS.db.comm = false
lib._booted = nil
NS.Comm.Boot()
H.ok(not lib:Enabled(), "a saved off switch is restored at boot")
lib:SetEnabled(true)

H.report()
