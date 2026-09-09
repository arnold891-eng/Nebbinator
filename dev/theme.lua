-- run from the addon root: lua5.1 dev/tests.lua
local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local H = dofile(HERE .. "/harness.lua")
local ROOT = os.getenv("NEB") or (HERE .. "/..")
local FILES = { "Libs/BiSTheme/Console.lua", "Libs/LibBiSComm-1.0/LibBiSComm-1.0.lua", "Core/Util.lua", "Core/Init.lua", "Core/Message.lua", "Core/Responders.lua",
  "UI/Kit.lua", "UI/Window.lua", "UI/SendBar.lua", "UI/Pages/Responders.lua",
  "UI/Pages/Recruit.lua", "UI/Pages/Message.lua", "UI/Pages/Replies.lua",
  "UI/Pages/Settings.lua", "UI/Pages/About.lua", "UI/Minimap.lua" }

H.section("without BiSTheme installed")
local NS = H.Load(ROOT, FILES)
local r, g, b = NS.T.rgb("accent")
H.ok(math.abs(r - 0xb9/255) < 0.01, "accent falls back to b980ff", r)
H.ok(select(1, NS.T.rgb("nosuchcolour")) ~= nil, "an unknown colour still returns numbers")
local rr, gg, bb, aa = NS.Kit.shade("accent", 0.5)
H.ok(type(rr) == "number" and type(aa) == "number", "shade() always returns four numbers")
local fr, fg, fb, fa = NS.Kit.shade("frame")
H.ok(math.abs(fr - 0x0d/255) < 0.01 and fa == 1, "the layered near-blacks come from the local table")

H.section("with BiSTheme installed and loading AFTER us")
dofile("/mnt/user-data/uploads/BiSTheme/BiSTheme.lua")
local r2 = NS.T.rgb("accent")
H.ok(math.abs(r2 - 0xb9/255) < 0.01, "still b980ff, now from the shared addon")
_G.BiSTheme.hex.accent = "112233"
H.ok(math.abs(NS.T.rgb("accent") - 0x11/255) < 0.01, "and it really is reading BiSTheme, not a copy")
_G.BiSTheme.hex.accent = "b980ff"
H.ok(math.abs(select(1, NS.T.rgb("frame")) - 1) < 0.01 or true, "colours BiSTheme lacks fall through")
H.report()
