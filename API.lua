--------------------------------------------------------------------------------
-- NebbinatorAPI: for other addons (16 Oct 2026, playbook 5a).
--
-- A caller never reaches into Nebbinator's insides (NS.db.responders, NS.Message): it asks here, and
-- here stays the same while the insides change. Shaped like BiSToolsAPI:
--   * NebbinatorAPI.version goes up when something is added; nothing is changed or taken away
--     without a new NebbinatorAPI.major. Check `api.major == 1` before using it.
--   * Read-only, plus opening the window. NOTHING here posts the ad, whispers anybody or changes a
--     setting - sending is the player's own click on the send bar or the desk.
--   * Safe at any time: before login every question answers nil, "not ready". Never errors.
--   * Answers are copies: editing one does not touch the desk.
--
-- Times are epoch seconds, as GetServerTime() counts them (the desk stamps whispers with time(), the
-- same count off the PC's clock - a few seconds apart at most on a PC that keeps time). Names are as the desk keys them: the realm suffix stripped
-- ("Kumlance-Dreamscythe" is "Kumlance"); Forever's whole "Name Surname" is kept as it is.
--
-- A recruit (somebody on the desk) is a table:
--   { name = "Kumlance", status = "new" | "contacted" | "trial" | "accepted" | "declined",
--     source = "whisper" | "channel" (the lead finder saw them ask for a guild), channel = name or nil,
--     classFile = "MAGE" or nil, class = "Mage" (as /who wrote it) or nil, level = n or nil,
--     guild = "Their Guild" | "No guild" | nil (nil = never looked up), zone = or nil,
--     online = true | false | nil (nil = never looked up), note = "" (the player's own note),
--     lastAt = when they last spoke, lastReplyAt = when we last whispered them or nil,
--     autoReplied = true | nil, messages = { { text = , at = }, ... } (oldest first, the last 10) }
--
-- Questions (all since version 1):
--   NebbinatorAPI.Ready()          -> true once logged in and loaded, else false
--   NebbinatorAPI.Recruits(status) -> list of recruits, newest first; `status` (optional) keeps only
--                                     that status. nil, "not ready" | "no such status"
--   NebbinatorAPI.Recruit(name)    -> one recruit, or nil, "not ready" | "no name" | "no such recruit"
--   NebbinatorAPI.CountNew()       -> how many recruits still have status "new", or nil, "not ready"
--   NebbinatorAPI.Ad()             -> the ad as the send bar would post it now (text, may be ""), and
--                                     a list of the tokens that rendered empty ({ "{discord}" }).
--                                     nil, "not ready"
--   NebbinatorAPI.Status()         -> { version = "3.5.0", preview = bool (true: nothing really sends),
--                                       autoReply = bool, leadFinder = bool, cooldown = seconds between
--                                       posts, template = the ad's template name, custom = bool (the
--                                       custom text replaces the template), lastPostAt = server time
--                                       of the last real post this session or nil,
--                                       recruits = n, new = n }. nil, "not ready"
--
-- Actions (since version 1) - only what a player's click does:
--   NebbinatorAPI.Open(page)       -> opens the window; `page` (optional) is "Recruit" | "Message" |
--                                     "Replies" | "About" and rolls the book out on it. Answers true,
--                                     or nil, "not ready" | "no such page" | "failed"
--
-- Events (since version 1):
--   NebbinatorAPI.RegisterCallback(owner, event, fn) -> true, or nil, "bad callback" | "no such event"
--   NebbinatorAPI.UnregisterCallback(owner, event)   -> true
--   `owner` is any key you choose (your addon's name); one fn per owner per event, a second replaces
--   the first. fn(event, ...) is called inside a pcall, so an error in it never reaches Nebbinator.
--   "Nebbinator_NewRecruit"  (event, name, source)  somebody new landed on the desk
--   "Nebbinator_Whisper"     (event, name, text)    a recruit whispered (the first whisper too)
--------------------------------------------------------------------------------
local _, NS = ...

local API = { major = 1, version = 1 }
NebbinatorAPI = API

local function Now()
  return GetServerTime and GetServerTime() or time()
end

local function DB()
  local db = NS.db
  if type(db) ~= "table" or type(db.responders) ~= "table" then return nil, "not ready" end
  return db
end

function API.Ready()
  return DB() ~= nil
end

local function Copy(e)
  local msgs = {}
  for i, m in ipairs(type(e.messages) == "table" and e.messages or {}) do
    if type(m) == "table" then msgs[i] = { text = m.text, at = m.at } end
  end
  return {
    name = e.name, status = e.status, source = e.source, channel = e.channel,
    classFile = e.class, class = e.className, level = e.level, guild = e.guild, zone = e.zone,
    online = e.online, note = e.note, lastAt = e.timestamp, lastReplyAt = e.lastReply,
    autoReplied = e.autoReplied, messages = msgs,
  }
end

local function IsStatus(key)
  for _, s in ipairs(NS.STATUSES or {}) do
    if s.key == key then return true end
  end
  return false
end

function API.Recruits(status)
  local db, why = DB()
  if not db then return nil, why end
  if status ~= nil and not IsStatus(status) then return nil, "no such status" end
  local out = {}
  for key, e in pairs(db.responders) do
    if type(e) == "table" and (status == nil or e.status == status) then
      local c = Copy(e)
      c.name = c.name or key
      out[#out + 1] = c
    end
  end
  table.sort(out, function(a, b)
    if (a.lastAt or 0) == (b.lastAt or 0) then return tostring(a.name) < tostring(b.name) end
    return (a.lastAt or 0) > (b.lastAt or 0)
  end)
  return out
end

function API.Recruit(name)
  local db, why = DB()
  if not db then return nil, why end
  if type(name) ~= "string" or name == "" then return nil, "no name" end
  local key = NS.Util.StripRealm(name)
  local e = db.responders[key]
  if type(e) ~= "table" then return nil, "no such recruit" end
  local c = Copy(e)
  c.name = c.name or key
  return c
end

function API.CountNew()
  local db, why = DB()
  if not db then return nil, why end
  local n = 0
  for _, e in pairs(db.responders) do
    if type(e) == "table" and e.status == "new" then n = n + 1 end
  end
  return n
end

function API.Ad()
  local db, why = DB()
  if not db then return nil, why end
  local M = NS.Message
  if not (M and M.Build) then return nil, "not ready" end
  local ok, text, missing = pcall(M.Build, M)
  if not ok or type(text) ~= "string" then return nil, "failed" end
  local list = {}
  for i, v in ipairs(type(missing) == "table" and missing or {}) do list[i] = v end
  return text, list
end

function API.Status()
  local db, why = DB()
  if not db then return nil, why end
  local M = NS.Message
  local tpl = M and M.ActiveTemplate and select(2, pcall(M.ActiveTemplate, M))
  local lastPostAt
  if M and type(M.lastAny) == "number" and M.lastAny > 0 and GetTime then
    lastPostAt = math.floor(Now() - (GetTime() - M.lastAny) + 0.5)
  end
  local recruits, new = 0, 0
  for _, e in pairs(db.responders) do
    if type(e) == "table" then
      recruits = recruits + 1
      if e.status == "new" then new = new + 1 end
    end
  end
  local ar = type(db.autoReply) == "table" and db.autoReply or {}
  return {
    version = NS.VERSION, preview = db.previewMode and true or false,
    autoReply = ar.enabled and true or false, leadFinder = db.leadFinder and true or false,
    cooldown = tonumber(db.sendCooldown) or 10,
    template = type(tpl) == "table" and tpl.name or nil, custom = db.customEnabled and true or false,
    lastPostAt = lastPostAt, recruits = recruits, new = new,
  }
end

function API.Open(page)
  if not DB() then return nil, "not ready" end
  local UI = NS.UI
  if not (UI and UI.Open) then return nil, "not ready" end
  if page ~= nil then
    local found = false
    for _, p in ipairs(UI.PAGES or {}) do
      if p == page then found = true end
    end
    if not found then return nil, "no such page" end
  end
  local ok = pcall(UI.Open, UI, page)
  if not ok then return nil, "failed" end
  return true
end

--------------------------------------------------------------------------------
-- Events: a small table of owners, a pcall per call, no library.
--------------------------------------------------------------------------------
local EVENTS = { Nebbinator_NewRecruit = true, Nebbinator_Whisper = true }
local owners = {}     -- [event] = { [owner] = fn }

function API.RegisterCallback(owner, event, fn)
  if owner == nil or type(fn) ~= "function" then return nil, "bad callback" end
  if not EVENTS[event] then return nil, "no such event" end
  owners[event] = owners[event] or {}
  owners[event][owner] = fn
  return true
end

function API.UnregisterCallback(owner, event)
  if owner ~= nil and owners[event] then owners[event][owner] = nil end
  return true
end

-- Nebbinator's own files call this; it is not part of the API. Nothing to do when nobody listens.
function NS.APIFire(event, ...)
  local list = owners[event]
  if not list or next(list) == nil then return end
  local fns = {}
  for _, fn in pairs(list) do fns[#fns + 1] = fn end
  for _, fn in ipairs(fns) do pcall(fn, event, ...) end
end
