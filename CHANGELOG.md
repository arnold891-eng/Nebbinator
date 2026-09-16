# Nebbinator

## 3.3.2 - 16 Sep 2026

- LibBiSComm minor 6: summon API moved to C_SummonInfo on 2.5.6 — the phantom-summon filter works again.

## 3.3.1 - 11 Sep 2026

- Shared console minor 4: the blinking cursor in the `BiS>` header is its own text now, so
  the words beside it no longer shift a hair every half second.

## 3.3.0 - 10 Sep 2026

The Settings tab is gone. Settings live in the window every BiS addon wears.

- **One options window, shared.** Arn, looking at BiSTools' Hub: *"this is
  beautiful ... I want all option windows to look like this."* So the generic
  half of that window moved into `BiSTheme/Options.lua` - self-guarded and
  embedded under `Libs\` exactly like `Console.lua`, carrying its own primitives
  so it borrows no widget kit from its host. Nebbinator is the second addon to
  wear it; the third is a table and a TOC line.
- **Four control kinds and no more**: toggle, 3-way seg, stepper, button. A
  setting that fits none of them is a slash command, not a fifth kind. The
  stepper clamps, so a setter that does not still cannot store junk.
- **Where the Settings tab's contents went.** Sounds, cooldown, auto-reply, the
  minimap button and the lead finder are rows in the options window. The logs
  address is the box on the desk, where you use it. Extra channels became
  `/nb channels <a, b>`. The alert sound became a stepper that plays each one as
  you land on it, which beats a grid of ten buttons.
- **`o` in the header** opens it, so does `/nb config`, and the box lights while
  it is out.
- **Every option calls the function the slash command owns.** None of them
  writes a saved variable itself, and the tests drive both paths at the same key
  and watch them agree - including the side effects, because a hand-written key
  is right and a missing `Minimap:Update` is not.
- **Both test suites read the TOC now.** `dev/theme.lua` kept its own copy of the
  file list, drifted, and was still loading `UI/Pages/Responders.lua` a day after
  the TOC dropped it - a suite testing an addon the client does not run.
- 458 checks, plus 59 for the shared kit on its own.

## 3.2.1 - 10 Sep 2026

Four things the first desk got wrong, all of them things Arn saw and the tests
did not.

- **The window walked down the screen.** Every relayout - pinning a channel,
  rolling the book, a whisper landing - re-anchored the frame to `top - height`
  instead of `top`, so it fell by its own height each time. The harness answered
  `GetTop()` with a flat `600`, which is exactly why no test could see it; the
  harness now does the anchor arithmetic and six checks watch the top edge.
- **The filter row never drew.** Its container frame had one anchor and no
  width, so it measured 0 wide and its buttons rendered nowhere - the desk
  reserved the 22 px and showed a blank band under the send buttons. The buttons
  hang off the desk directly now, like everything else on it.
- **The minimap button was blank.** `Interface\Icons\INV_Scroll_11` is not in
  this client. It is a star off the raid-target sheet now, which is core UI art
  and cannot go missing. The "somebody waiting" ring was also a solid square
  drawn *over* the icon; it is a pad *behind* it, and the star brightens.
- **The logs box showed the tail of the address.** `SetText` leaves the cursor
  at the end, so a long URL read `cter/us/dreamscythe/[name]`. Cursor home.

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
