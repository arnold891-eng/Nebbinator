# Nebbinator

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
