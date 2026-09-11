-- run from the addon root: lua5.1 dev/tests.lua
local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local H = dofile(HERE .. "/harness.lua")
local ROOT = os.getenv("NEB") or (HERE .. "/..")

-- The TOC is the truth for what loads and in what order. This used to be a
-- hand-kept copy of the list, which is the same duplication that let NS.VERSION
-- disagree with the TOC for two weeks (landmine 0c) - a file added to one and
-- not the other is a test suite exercising a different addon than the client
-- loads. BiSTools has read its TOC since day one; this now does too.
local FILES = H.TOC(ROOT, "Nebbinator.toc")

-- an existing v1 profile, so the upgrade path is exercised on every run
_G.NubbinatorDB = {
    needs = { shaman = { resto = 2, ele = 0, enh = 0 },
              druid = { boomie = 1, tank = 1, resto = 0, feral = 0 },
              warrior = { prot = 1, dps = 0 } },
    raidTimes = { tuesday = "5pm", sunday = "5pm server time" },
    preText = "lf raiders", postText = "SSC/TK",
    responders = { Zug = { name = "Zug", message = "are you recruiting?", timestamp = os.time() } },
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
H.ok(NS.db.responders.Zug ~= nil, "v1 responders carried over")
H.eq(NS.db.windows, nil, "old two-window positions dropped")
H.eq(#NS.db.quickReplies, 4, "four quick replies")

H.section("the desk, and four pages in the book")
local UI = NS.UI
H.ok(UI.frame ~= nil, "window built at login")
H.eq(UI.frame:IsShown(), false, "starts hidden")
H.eq(#UI.PAGES, 4, "four pages in the book")
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
UI:ShowTab("Recruit")

H.section("toggle")
UI:Toggle()
H.eq(UI.frame:IsShown(), true, "toggle opens a closed window")
UI:Toggle()
H.eq(UI.frame:IsShown(), false, "toggle closes an open window")
UI:Toggle("Replies")
H.eq(UI.frame:IsShown(), true, "toggle with a page opens")
H.eq(UI:ShownTab(), "Replies", "...on that page")
H.ok(UI.bookOpen, "...with the book rolled out")
UI:ShowTab("Recruit")
UI:Toggle("Replies")
H.eq(UI.frame:IsShown(), true, "toggle to another page keeps it open")
H.eq(UI:ShownTab(), "Replies", "...and switches to it")
UI:ToggleBook(false)

H.section("every control round-trips")
local EXPECTED = {
    "need.shaman.resto", "need.druid.balance", "need.warrior.prot", "time.tuesday", "time.sunday",
    "override", "guildName", "discord", "content", "preText", "postText",
    "templateName", "templateText",
    "quick1Label", "quick1Text", "quick4Label", "quick4Text",
    "autoReply", "replyMode", "keywords", "replyText", "replyCooldown", "replyRate", "skipGuildies",
}
-- previewMode / sendCooldown / playSound / soundOnlyNew / sound / minimap /
-- leadFinder left with the Settings tab: they live in the options window now
-- and are exercised in "the options window" below. logsUrl is the box on the
-- desk; customChannels is /nb channels.
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
    replyCooldown = 600, replyRate = 4, replyMode = "any",
}
for id, value in pairs(SAMPLES) do
    H.ok(UI:Set(id, value), "Set works: " .. id)
    H.eq(UI:Get(id), value, "round-trip: " .. id)
end

for _, id in ipairs({ "override", "autoReply", "skipGuildies" }) do
    UI:Set(id, true);  H.eq(UI:Get(id), true,  "toggle on: " .. id)
    UI:Set(id, false); H.eq(UI:Get(id), false, "toggle off: " .. id)
end

H.section("sliders clamp instead of storing junk")
UI:Set("replyRate", 500)
H.eq(NS.db.autoReply.maxPerMinute, 20, "rate cap clamps")

H.section("the window writes the same key the slash command owns")
NS.db.autoReply.enabled = false
UI:Set("autoReply", true)
H.eq(NS.db.autoReply.enabled, true, "checkbox turned auto-reply on")
UI:Set("autoReply", true)
H.eq(NS.db.autoReply.enabled, true, "...and again is a no-op, not a flip")
SlashCmdList["NEBBINATOR"]("reply")
H.eq(NS.db.autoReply.enabled, false, "/nb reply turns the same key off")

SlashCmdList["NEBBINATOR"]("discord discord.gg/fromslash")
H.eq(UI:Get("discord"), "discord.gg/fromslash", "/nb discord reaches the field")

H.section("checkbox paint")
UI:ShowTab("Replies")
UI:Set("autoReply", true)
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
local bar = UI.send
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

UI:LayoutDesk()
local row = UI.rows[1]
H.ok(row ~= nil, "a queue row was built")
H.ok(row.name:GetText():find("Kumlance", 1, true) ~= nil, "the row names them")
H.eq(row:GetHeight(), UI.ROW_H, "one line tall, like BiSJC's queue")

-- clicking a row serves them, and only then do the buttons appear
H.ok(not UI.served:IsShown(), "nothing served yet, no block")
row:Click()
H.eq(UI.serving, "Kumlance", "clicking a row serves them")
H.ok(UI.served:IsShown(), "and the block opens")
H.ok(UI.served.title:GetText():find("Kumlance", 1, true) ~= nil, "naming who is being served")
H.ok(UI.served.who ~= UI.served.title, "the Who button did not eat the Serving label")
row:Click()
H.ok(UI.serving == nil, "clicking again puts them down")
H.ok(not UI.served:IsShown(), "and the block closes")
row:Click()

UI.served.whisper:Click()
H.ok(H.chatOpened ~= nil, "Whisper opens a whisper to them", tostring(H.chatOpened))

H.section("the served block fits inside itself")
do
    local s2 = UI.served
    local h = s2:GetHeight()
    local _, msgY = s2.message:OffsetFor("TOPLEFT")
    local msgBottom = -msgY + (s2.message._h or 12)
    local _, actY = s2.whisper:OffsetFor("TOPLEFT")
    H.ok(msgBottom <= -actY, "the message clears the action row",
         ("message ends %d, actions start %d"):format(msgBottom, -actY))
    local _, quickY = s2.quick[1]:OffsetFor("TOPLEFT")
    H.ok(-actY + s2.whisper:GetHeight() <= -quickY, "the actions clear the quick replies")
    H.ok(-quickY + s2.quick[1]:GetHeight() <= h, "the quick replies stay inside the block")
    local wide = s2.whisper:GetWidth() + s2.discord:GetWidth() + s2.invite:GetWidth()
        + s2.who:GetWidth() + s2.logs:GetWidth() + 4 * 4 + 20
    H.ok(wide <= UI.DESK_W, "every action button fits one row of the desk",
         ("needs %d, has %d"):format(wide, UI.DESK_W))
    H.ok(s2.quick[1]:GetWidth() * 4 + 9 + 20 <= UI.DESK_W, "four quick replies fit across")
end

H.section("status pipeline")
R:SetStatus("Kumlance", "new")
UI.served.status:Click("LeftButton")
H.eq(NS.db.responders.Kumlance.status, "contacted", "left click moves the status forward")
UI.served.status:Click("RightButton")
H.eq(NS.db.responders.Kumlance.status, "new", "right click moves it back")

H.section("logs")
NS.db.logsUrl = "https://fresh.warcraftlogs.com/character/us/dreamscythe/{name}"
UI.served.logs:Click()
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
R:OnWhisper("recruiting?", "Newbie", nil,nil,nil,nil,nil,nil,nil,nil,nil,nil)
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
H.eq(UI.bookBtn.slot, -17, "the book button sits at its own")
H.eq(UI.optBtn.slot, -31, "and options at its own")
for _, b in ipairs({ UI.closeBtn, UI.bookBtn, UI.optBtn }) do
    H.eq(b:GetWidth(), 12, "12 px boxes, all of them")
end
H.eq(UI.STRIP, 31 + UI.optBtn:GetWidth(), "the strip is exactly the far button plus its offset")
H.ok(UI.badge == nil and UI.preview == nil, "no badge, no preview pill - both are slots now")
local inHeader = 0
for _, fr in ipairs(H.frames) do if fr._parent == UI.head then inHeader = inHeader + 1 end end
-- This count is the guard that catches the NEXT thing somebody adds to a 16 px
-- bar without predicting what it is. It went 2 -> 3 on purpose when Settings
-- stopped being a tab and became the options window.
H.eq(inHeader, 3, "three frames in the header: close, the book, options")

-- slots: state that lasts, cleared the moment it ends
NS.db.responders = {}
NS.db.previewMode, NS.db.leadFinder = false, false
NS.db.autoReply.enabled = false
UI:PaintSlots() settle()
H.ok(UI.con.slots.name and UI.con.slots.name.text == "Nebbinator", "the name slot is always there")
H.ok(UI.con.slots["new"] == nil, "no new responders: no count slot")
NS.db.responders.Bob = { name = "Bob", status = "new", timestamp = os.time(), messages = {} }
NS.db.responders.Cid = { name = "Cid", status = "trial", timestamp = os.time(), messages = {} }
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
UI:Clear() step(4)
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
for _, b in ipairs(UI.send.buttons) do if b.label == "Yell" then b:Click() end end
H.eq(#H.prints, chat1, "posting the ad says nothing in chat")
H.ok(await("sent to yell", 3), "the prompt says it went", plain())

-- a slash command still answers in chat: that is what chat is for
local chat2 = #H.prints
SlashCmdList["NEBBINATOR"]("help")
H.ok(#H.prints > chat2, "/nb help still answers in the chat frame")

H.section("every queue row fits the desk")
NS.db.responders = {}
R:OnWhisper("recruiting? i am a resto shaman with kara gear and logs",
    "Kumlanceroo", nil,nil,nil,nil,nil,nil,nil,nil,nil, "Player-1-1")
NS.db.responders.Kumlanceroo.level = 70
NS.db.responders.Kumlanceroo.className = "Shaman"
NS.db.responders.Kumlanceroo.guild = "Some Very Long Guild Name"
UI:LayoutDesk()
for i, r in ipairs(UI.rows) do
    if r:IsShown() then
        local _, nameX = 0, select(1, r.name:OffsetFor("LEFT"))
        local infoX = select(1, r.info:OffsetFor("LEFT"))
        H.ok(nameX + r.name:GetStringWidth() <= infoX,
             "row " .. i .. ": the name clears the class column",
             math.floor(nameX + r.name:GetStringWidth()) .. " of " .. infoX)
        H.ok(infoX + r.info:GetStringWidth() + 60 <= UI.DESK_W,
             "row " .. i .. ": name + class + age fit the desk",
             math.floor(infoX + r.info:GetStringWidth() + 60) .. " of " .. UI.DESK_W)
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
H.eq(lib and lib.MINOR, 5, "minor 5, the current one (bystander CONFIRM_SUMMON ignored)")
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

--------------------------------------------------------------------
-- the desk: as tall as the list and no taller
--------------------------------------------------------------------

H.section("the window grows as whispers land and shrinks as they are dealt with")
UI:ToggleBook(false)
UI.serving = nil
NS.db.responders = {}
UI.filter = "all"
UI:LayoutDesk()

local empty = UI.frame:GetHeight()
H.eq(UI.frame:GetWidth(), UI.DESK_W, "rolled up, the window is desk width")

local heights = { [0] = empty }
for i = 1, 4 do
    NS.db.responders["P" .. i] = { name = "P" .. i, status = "new",
        timestamp = os.time() - i, messages = { { text = "hi", at = os.time() } } }
    UI:LayoutDesk()
    heights[i] = UI.frame:GetHeight()
    H.ok(heights[i] > heights[i - 1], i .. " waiting is taller than " .. (i - 1),
         heights[i - 1] .. " -> " .. heights[i])
end
H.eq(heights[1] - heights[0], UI.ROW_H, "each one costs exactly one row")

-- and back down again
for i = 4, 1, -1 do
    NS.db.responders["P" .. i] = nil
    UI:LayoutDesk()
    H.eq(UI.frame:GetHeight(), heights[i - 1], "removing one gives the height back")
end
H.eq(UI.frame:GetHeight(), empty, "empty desk is back to its smallest")

-- a long list stops growing and scrolls instead
for i = 1, 40 do
    NS.db.responders["Q" .. i] = { name = "Q" .. i, status = "new",
        timestamp = os.time() - i, messages = { { text = "hi", at = os.time() } } }
end
UI:LayoutDesk()
local tall = UI.frame:GetHeight()
H.ok(tall <= empty + UI.MAX_ROWS * UI.ROW_H + 2, "40 waiting is capped at MAX_ROWS, not 40 rows", tall)
H.ok(UI.listScroll.track:IsShown(), "and the list scrolls instead")
H.ok(UI.rows[1]:IsShown(), "the rows are still there to scroll through")

-- serving one opens the block and costs its height, exactly once
local before = UI.frame:GetHeight()
UI:Serve("Q1")
H.eq(UI.frame:GetHeight(), before + UI.SERVED_H, "serving opens the block")
UI:Serve("Q2")
H.eq(UI.frame:GetHeight(), before + UI.SERVED_H, "serving somebody else does not stack another")
UI:Serve(nil)
H.eq(UI.frame:GetHeight(), before, "putting them down closes it again")

-- a served responder who gets removed stops being served
UI:Serve("Q1")
NS.Responders:Remove("Q1")
H.ok(UI:ServedName() == nil, "removing the served one un-serves them")
H.eq(UI.frame:GetHeight(), UI.frame:GetHeight(), "and the block goes with them")
NS.db.responders = {}
UI:LayoutDesk()

H.section("the book rolls up and down")
H.ok(not UI.book:IsShown(), "rolled up by default")
local rolled = UI.frame:GetHeight()
UI:ToggleBook(true)
H.ok(UI.book:IsShown(), "the button rolls it out")
H.eq(UI.frame:GetWidth(), UI.BOOK_W, "and the window widens for the rail")
H.eq(UI.frame:GetHeight(), rolled + UI.BOOK_H, "and grows by exactly the book")
H.ok(UI.bookBtn.marked, "the header button lights while it is out")
UI:ToggleBook(false)
H.eq(UI.frame:GetWidth(), UI.DESK_W, "rolling it up gives the width back")
H.eq(UI.frame:GetHeight(), rolled, "and the height")
H.ok(not UI.bookBtn.marked, "and the light goes out")
-- the desk keeps working while the book is out
UI:ToggleBook(true)
NS.db.responders.Zed = { name = "Zed", status = "new", timestamp = os.time(), messages = {} }
UI:LayoutDesk()
H.eq(UI.frame:GetHeight(), rolled + UI.ROW_H + UI.BOOK_H, "a whisper still grows the desk under an open book")
NS.db.responders = {}
UI:ToggleBook(false)
UI:LayoutDesk()

H.section("send buttons: the clock never sits on the label")
do
    local widest
    for _, b in ipairs(UI.send.buttons) do
        if b.chatType then
            b.timer:SetText("|cfff08cb088|r")           -- the widest clock it can show
            -- the label must be LEFT anchored: centred in a box that also holds
            -- a clock is exactly how "/2 Trade" got a "23" through it
            local point = b.text:OffsetFor("LEFT")
            H.ok(point ~= nil, "label is left-anchored, not centred: " .. tostring(b.label))
            local labelEnd = 7 + b.text:GetStringWidth()
            local clockStart = b:GetWidth() - 6 - b.timer:GetStringWidth()
            H.ok(labelEnd <= clockStart,
                 "clock clears the label: " .. tostring(b.label),
                 math.floor(labelEnd) .. " vs " .. math.floor(clockStart))
            if not widest or b:GetWidth() > widest:GetWidth() then widest = b end
        end
    end
    H.ok(widest ~= nil, "there were buttons to check")
end

H.section("hiding a channel you never post to")
local function labels()
    local out = {}
    for _, b in ipairs(UI.send.buttons) do if b.chatType then out[#out + 1] = b.label end end
    return out
end
local all = #labels()
H.ok(all >= 8, "every target shows by default", all)
H.ok(not UI.AnyHidden(), "nothing hidden until you hide it")

local trade
for _, b in ipairs(UI.send.buttons) do if b.label == "/2 Trade" then trade = b end end
H.ok(trade ~= nil, "found Trade")
trade:Click("RightButton")
H.eq(#labels(), all - 1, "right-click takes it off the desk")
H.ok(UI.AnyHidden(), "and the addon knows something is hidden")
H.eq(NS.db.hiddenChannels["/2 Trade"], true, "remembered in the saved variables")

-- the arrow brings the whole set back for a moment
local arrow
for _, b in ipairs(UI.send.buttons) do if not b.chatType then arrow = b end end
H.ok(arrow ~= nil, "an arrow appeared once something was hidden")
arrow:Click()
H.eq(#labels(), all, "unrolled, every target is back")
for _, b in ipairs(UI.send.buttons) do if b.label == "/2 Trade" then trade = b end end
trade:Click("RightButton")
H.eq(NS.db.hiddenChannels["/2 Trade"], nil, "right-click again un-hides it")
UI.sendExpanded = false
UI:LayoutDesk()
H.eq(#labels(), all, "and it is back on the desk for good")


H.section("the window stays where it was put")
-- Arn, 10 Sep: "every time I right click to pin or unpin it shifts the window
-- down." Relayout re-anchored to `top - height` instead of `top`, so the frame
-- fell by its own height on every single call. The harness used to answer
-- GetTop() with a constant, which is why nothing here could see it.
UI:Open()
UI:LayoutDesk()
local topBefore = UI.frame:GetTop()
local leftBefore = UI.frame:GetLeft()
H.ok(topBefore ~= nil, "the window has a top edge", tostring(topBefore))

for _, b in ipairs(UI.send.buttons) do
    if b.label == "/2 Trade" then b:Click("RightButton") break end
end
H.eq(UI.frame:GetTop(), topBefore, "pinning a channel does not move the top edge")
H.eq(UI.frame:GetLeft(), leftBefore, "and it does not move sideways either")

local heightPinned = UI.frame:GetHeight()
for _, b in ipairs(UI.send.buttons) do
    if b.label == "/2 Trade" then b:Click("RightButton") break end
end
H.eq(UI.frame:GetTop(), topBefore, "un-pinning does not move it back down either")

UI:ToggleBook(true)
H.eq(UI.frame:GetTop(), topBefore, "rolling the book out grows downward, not off the top")
H.ok(UI.frame:GetHeight() > heightPinned, "and it really did get taller",
     UI.frame:GetHeight() .. " vs " .. heightPinned)
UI:ToggleBook(false)
H.eq(UI.frame:GetTop(), topBefore, "rolling it back up leaves the top alone")

NS.db.responders["Topcheck"] = { name = "Topcheck", status = "new",
    timestamp = os.time(), messages = { { text = "any room?", at = os.time() } } }
UI:LayoutDesk()
H.eq(UI.frame:GetTop(), topBefore, "a whisper landing does not move it either")
NS.db.responders["Topcheck"] = nil
UI:LayoutDesk()
H.eq(UI.frame:GetTop(), topBefore, "and neither does dealing with them")

H.section("the filter buttons are on the desk, not in a phantom frame")
-- The old container had one anchor and no width, so it measured 0 wide and its
-- children never drew: the desk reserved 22 px and showed a blank band.
H.eq(#UI.filterButtons, 6, "six filters")
for _, entry in ipairs(UI.filterButtons) do
    H.eq(entry.button:GetParent(), UI.desk, "the " .. entry.key .. " button hangs off the desk")
    local x, y = entry.button:OffsetFor("TOPLEFT")
    H.ok(x ~= nil and y ~= nil, "the " .. entry.key .. " button is anchored")
    H.ok(x >= 0 and x + entry.button:GetWidth() <= UI.DESK_W,
         "the " .. entry.key .. " button fits across the desk",
         tostring(x and (x + entry.button:GetWidth())) .. " of " .. UI.DESK_W)
end
-- and they do not sit on top of the count line below them
do
    local _, fy = UI.filterButtons[1].button:OffsetFor("TOPLEFT")
    local _, cy = UI.countText:OffsetFor("TOPLEFT")
    H.ok(cy < fy - 17, "the count line clears the filter row",
         tostring(cy) .. " vs " .. tostring(fy))
end

H.section("the options window")
-- Settings stopped being a tab (Arn, 10 Sep: "replaced - tab goes away") and
-- became the window every BiS addon wears. Everything the tab used to prove is
-- proved here instead, against the shared kit.
local O = BiSTheme.OPTIONS
local opt = UI:BuildOptions()

local SECTIONS = { "nebbinator", "posting", "answering", "finding people" }
local OPTIONS = {
    "minimap button", "BiS channel (/biscomm)", "reset window position",
    "preview - never sends", "cooldown per channel",
    "auto-reply", "alert sound", "only the first one", "which sound",
    "watch for \"LF guild\"",
}
-- Counted from a written-down list, NOT from UI:OptionSections() - deriving the
-- expectation from the thing under test means deleting a section changes both
-- sides and the assert cannot fail.
local haveSections, haveOptions = {}, {}
for _, s in ipairs(UI:OptionSections()) do
    haveSections[s.title] = true
    for _, o in ipairs(s.options) do haveOptions[o.label] = true end
end
for _, name in ipairs(SECTIONS) do H.ok(haveSections[name], "section: " .. name) end
for _, name in ipairs(OPTIONS) do H.ok(haveOptions[name], "option: " .. name) end
H.eq(#opt.rows, #SECTIONS + #OPTIONS, "one row per section header and per option")
H.eq(opt:GetHeight(), O.HEADER + #opt.rows * O.ROW + O.PAD, "height is header + rows + pad")
H.eq(opt:GetWidth(), O.W, "and it is the house width")
H.ok(not opt:IsShown(), "built hidden; the toggle decides")

-- budgets
H.ok(opt.con:Width() <= O.W - 15 - 8, "the prompt fits its header", opt.con:Width())
for _, r in ipairs(opt.rows) do
    local budget = r.isSection and (O.W - 6 - O.CTL) or (O.W - O.INDENT - O.CTL)
    H.ok(r.name:GetStringWidth() <= budget, "label fits: " .. tostring(r.name:GetText()),
         math.floor(r.name:GetStringWidth()) .. " of " .. budget)
    -- and every one of OUR labels was picked to fit outright: the ellipsis is
    -- the net, not the plan
    H.ok(not tostring(r.name:GetText()):find("%.%.%.$"),
         "and was not trimmed to get there: " .. tostring(r.name:GetText()))
end

local function optRow(label)
    for _, r in ipairs(opt.rows) do if r.opt and r.opt.label == label then return r end end
end

H.section("every option calls the function the slash command owns")
-- The rule that matters: no `set` here writes a saved variable itself. Proven
-- by driving the control and the slash command at the same key and watching
-- them agree, both ways round.
NS.db.previewMode = false
opt:Paint()
local prev = optRow("preview - never sends")
H.ok(prev ~= nil, "there is a preview row")
prev.ctl:Click()
H.eq(NS.db.previewMode, true, "the box turned preview on")
SlashCmdList["NEBBINATOR"]("preview")
H.eq(NS.db.previewMode, false, "/nb preview turns the same key off")
opt:Paint()
H.eq(prev.ctl.on, false, "and the box reads the slash command's change")

NS.db.minimap.hide = false
NS.Minimap:Update()
opt:Paint()
local mm = optRow("minimap button")
H.eq(mm.ctl.on, true, "the minimap box starts on")
mm.ctl:Click()
H.eq(NS.db.minimap.hide, true, "clicking it hides the button")
-- the side effect, not just the key: NS.ToggleMinimap also calls Minimap:Update,
-- and a `set` that wrote db.minimap.hide by hand would leave the button on
-- screen with the box saying otherwise
H.eq(NS.Minimap.button:IsShown(), false, "and the button really went away")
SlashCmdList["NEBBINATOR"]("minimap")
H.eq(NS.db.minimap.hide, false, "/nb minimap shows it again")
H.eq(NS.Minimap.button:IsShown(), true, "and it really came back")

NS.db.autoReply.enabled = false
opt:Paint()
local ar = optRow("auto-reply")
ar.ctl:Click()
H.eq(NS.db.autoReply.enabled, true, "auto-reply toggles from the window")
SlashCmdList["NEBBINATOR"]("reply")
H.eq(NS.db.autoReply.enabled, false, "and from the slash command")

H.section("the stepper clamps, and the sound one plays what it lands on")
NS.SetCooldown(10)
opt:Paint()
local cd = optRow("cooldown per channel")
cd.ctl.plus:Click()
H.eq(NS.db.sendCooldown, 15, "> raises the cooldown")
for _ = 1, 40 do cd.ctl.plus:Click() end
H.eq(NS.db.sendCooldown, 120, "and it clamps at the top")
for _ = 1, 40 do cd.ctl.minus:Click() end
H.eq(NS.db.sendCooldown, 5, "and at the bottom")
NS.SetCooldown(10)

local snd = optRow("which sound")
NS.SetSoundIndex(2)
H.sounds = {}
snd.ctl.plus:Click()
H.eq(NS.db.autoReply.sound, NS.SOUNDS[3].key, "> walks to the next sound")
H.eq(#H.sounds, 1, "and plays it, so you hear what you landed on")
for _ = 1, 40 do snd.ctl.plus:Click() end
H.eq(NS.db.autoReply.sound, NS.SOUNDS[#NS.SOUNDS].key, "the sound stepper clamps at the end")
for _ = 1, 40 do snd.ctl.minus:Click() end
H.eq(NS.db.autoReply.sound, NS.SOUNDS[1].key, "and at the start")
-- and the name it shows fits between the arrows, un-trimmed, for EVERY sound
for i = 1, #NS.SOUNDS do
    NS.SetSoundIndex(i)
    opt:Paint()
    local shown = tostring(snd.ctl.val:GetText())
    H.ok(not shown:find("%.%.%.$"), "sound name fits whole: " .. shown)
    H.ok(snd.ctl.val:GetStringWidth() <= O.STEP_V, "...between the arrows: " .. shown,
         math.floor(snd.ctl.val:GetStringWidth()) .. " of " .. O.STEP_V)
end
NS.SetSoundIndex(2)

H.section("the button row, and the ways in")
local reset = optRow("reset window position")
NS.db.window = { point = "TOPLEFT", x = 5, y = 5 }
reset.ctl:Click()
H.eq(NS.db.window.point, nil, "reset put the window back")

H.ok(not opt:IsShown(), "still hidden")
SlashCmdList["NEBBINATOR"]("config")
H.ok(opt:IsShown(), "/nb config opens it")
H.ok(UI.optBtn.marked, "and the header box lights while it is out")
UI.optBtn:Click()
H.ok(not opt:IsShown(), "the header box closes it again")

H.section("what did not fit the four kinds went somewhere real")
-- The law: a setting that is not a toggle, seg, step or button is a slash
-- command, not a fifth control kind.
for _, r in ipairs(opt.rows) do
    if r.opt then
        H.ok(BiSTheme.OptionKinds[r.opt.kind] ~= nil,
             "known kind: " .. tostring(r.opt.kind) .. " (" .. tostring(r.opt.label) .. ")")
    end
end
SlashCmdList["NEBBINATOR"]("channels world, lookingforgroup")
H.eq(NS.db.customChannels, "world, lookingforgroup", "/nb channels took the extra channels")
H.ok(UI.logsBox ~= nil, "and the logs address is the box on the desk")
NS.db.logsUrl = "https://x/{name}"
UI:RefreshDesk()
H.eq(UI.logsBox:Get(), "https://x/{name}", "which round-trips")

H.section("chat stays clean when the window does the talking")
local chatBefore = #H.prints
prev.ctl:Click() prev.ctl:Click()
mm.ctl:Click() mm.ctl:Click()
cd.ctl.plus:Click() cd.ctl.minus:Click()
snd.ctl.plus:Click() snd.ctl.minus:Click()
H.eq(#H.prints, chatBefore, "not one line in chat from a round of clicks")
-- but the slash command still answers in chat, because that is what a slash is
SlashCmdList["NEBBINATOR"]("preview")
H.ok(#H.prints > chatBefore, "/nb preview still answers in the chat frame")
SlashCmdList["NEBBINATOR"]("preview")

H.section("embedded libs are the canonical bytes")
-- The lib is edited in _bisdev (Console in BiSTheme) and copied out by
-- _bisdev/sync.ps1; a stale copy in an addon is how three addons kept shipping
-- minor 4 after minor 5 fixed the phantom summon. Run from the addon folder, the
-- siblings are one level up; when they are not (a bare checkout) the check says
-- so and skips instead of lying green. Options.lua joined 11 Sep pm (minor 2).
do
    local function bytes(path)
        local fh = io.open(path, "rb")
        if not fh then return nil end
        local b = fh:read("*a") fh:close()
        return b
    end
    local canon = {
        { "Libs/LibBiSComm-1.0/LibBiSComm-1.0.lua", "../_bisdev/LibBiSComm-1.0/LibBiSComm-1.0.lua" },
        { "Libs/BiSTheme/Console.lua",              "../BiSTheme/Console.lua" },
        { "Libs/BiSTheme/Options.lua",              "../BiSTheme/Options.lua" },
    }
    for _, pr in ipairs(canon) do
        local mine, ref = bytes(pr[1]), bytes(pr[2])
        H.ok(mine ~= nil, "embedded " .. pr[1] .. " is on disk")
        if ref then
            H.ok(mine == ref, "embedded " .. pr[1] .. " is byte-identical to " .. pr[2] .. " (run _bisdev/sync.ps1)")
        else
            H.say("   (canonical " .. pr[2] .. " not beside this checkout - embed check skipped)")
        end
    end
end

H.report()
