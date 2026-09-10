# Nebbinator

## 3.2.0 - 10 Sep 2026

The desk, and the book behind it.

- **The window is the queue now.** Nebbinator opens as a 620 px desk: the
  prompt header, one 16 px line per person waiting, the one you are serving
  opened up underneath, and the send buttons along the foot. Nothing else.
  It grows one row per whisper and shrinks one row per accept or decline, so
  the window is exactly as tall as the work in it. Past ten waiting it stops
  growing and the list scrolls instead.
- **The rest rolls up.** Recruit / Message / Replies / Settings / About moved
  behind a header button. Open it and the window widens to 820 and the tab
  rail appears beside the desk; close it and it is a desk again. The state is
  remembered (`bookOpen`), and `/nb book` toggles it from chat.
- **An empty desk is the smallest desk.** No list area at all - the hint lives
  on the count line. The first whisper used to *shrink* the window, which is
  the opposite of the point.
- **Send buttons pin.** Right-click one to take it off the desk; the `v` arrow
  brings the hidden ones back. The elapsed clock moved to the button's right
  edge and the label to its left, with the width reserving room for both -
  on a long channel name the clock used to print straight through the label.
- `UI\Pages\Responders.lua` is gone; `UI\Desk.lua` replaces it.
- 367 checks, four of them mutation-verified.

## 3.1.0 - 9 Sep 2026

The house style, and the shared channel.

- **The header is a prompt.** `BiS> Nebbinator_`, cursor blinking, standing
  slots rotating every 3 s and events jumping in over them. The 64 px bar with a
  logo, a version, a PREVIEW pill and a new-responder badge is now a 16 px bar
  with the prompt and one 12x12 close box; the pill and the badge were state, so
  they became slots. `BiSTheme/Console.lua` ships under `Libs/` so it works
  whether or not BiSTheme is installed.
- **Chat is for `/slash` answers only.** Everything the addon used to announce -
  a whisper landing, an ad going out, a cooldown, a lookup - now goes to the
  prompt instead. The only line left in chat is the settings-upgrade notice.
- **LibBiSComm embedded** (minor 3, byte-identical to `_bisdev`). Registered and
  booted from `Core/Init.lua`; `/bis off` is remembered in `NebbinatorDB.comm`
  and restored next login. No Nebbinator setting can mute it, and Nebbinator
  puts nothing of its own on the wire.
- **One version, in the TOC.** `NS.VERSION` reads `GetAddOnMetadata`. It had
  been a literal saying `2.0.1` since the v3 rebuild while the TOC said `3.0.0`.
- `dev/suite.lua` is `dev/tests.lua`, the name every other BiS addon uses.
  313 checks, five of them mutation-verified.

## 3.0.0 - 27 Aug 2026

One window, six tabs, on the BiS palette. Responders / Recruit / Message /
Replies / Settings / About, replacing the two Blizzard-backdrop windows.

## 2.0.0 - 26 Aug 2026

Rewrite: deterministic message order, real channel lookup, 255-character
splitting, send cooldowns, quick replies, auto-reply, `/who` from a click only.

## 1.0.0

The original.
