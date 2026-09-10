# Nebbinator 3.2

Guild recruitment for WoW TBC (Anniversary), in one window.

`/nb` opens the **desk**: the prompt header, one line per person waiting, the
one you are serving opened up underneath, and the send buttons along the foot.
Nothing else. It is 620 px wide and only as tall as the work in it - one row
taller per whisper, one row shorter per accept or decline. Past ten waiting it
stops growing and the list scrolls.

Click a line to serve that person: their block opens with their class, level,
guild, the logs link, the quick replies and the Accept / Decline / Who buttons.
Click the same line again to close it.

Everything else is a **book** behind the header's list box. Open it and the
window widens to 820 and a tab rail appears beside the desk; close it and it is
a desk again. It remembers which way you left it.

| Tab | What lives there |
| --- | --- |
| **Recruit** | class/spec counts, raid times, the live preview |
| **Message** | guild details, saved templates, tokens |
| **Replies** | the four quick replies and the auto-reply |
| **Settings** | sounds, cooldown, minimap, logs address, lead finder |
| **About** | how it works, and every command |

Minimap button: left click opens the desk, right click opens the book. It grows
a violet ring when somebody is waiting.

## The send buttons pin

Right-click a channel button to take it off the desk - most of them you never
post to, and they were eating the foot. The `v` arrow at the end brings the
hidden ones back. Each button counts its own cooldown down in its right corner
while the label sits on the left.

## The header is a prompt

The title bar is `BiS> Nebbinator_`, cursor blinking. It rotates through what is
standing right now - `2 new`, `1 on trial`, `preview - nothing sends`,
`watching channels`, `auto-reply on` - and an event jumps in over them for three
seconds when something happens: `Bob whispered`, `Bob <- Signups`, `sent to /2`.

Nothing the addon does goes to the chat frame any more. Chat is for `/slash`
answers only. The one exception is the upgrade notice, which has to survive a
window that has not been built yet.

## Nothing is ever sent on a timer

An ad goes out when you click a channel button, and never otherwise. Each send
button counts down its own cooldown in the corner and greys itself out until it
is safe again. Auto-reply is the only thing that sends by itself, and only in
answer to somebody whispering you first.

## Commands

    /nb                open the desk
    /nb book           roll the tab rail out, or back up
    /nb r              open the desk on the queue
    /nb config         open the book on Settings
    /nb preview        toggle preview mode (print, never send)
    /nb reply          toggle auto-reply
    /nb discord <url>  set the Discord link
    /nb minimap        show or hide the minimap button
    /nb reset          put the window back in the middle

Every one of those writes the same saved variable the matching checkbox writes,
through the same function, so the window and the commands can never disagree.

## Tokens

Usable in a template, in the auto-reply, and in any quick reply:

    {needs} {needs:short} {times} {times:full} {guild} {discord} {content}
    {tanks} {healers} {dps} {total} {pre} {post} {player} {level} {realm} {faction}

If your ad uses neither `{guild}` nor `{discord}`, the Message tab says so and
offers a button that adds it — a name that never appears in the ad is the most
confusing thing this addon can do.

## Safety rails

- a per-channel cooldown, shown as a countdown on the button itself
- messages over 255 characters are split on a clean seam and sent 1.2s apart,
  never truncated
- preview mode prints everything to chat instead of sending, and lights up the
  window header while it is on
- auto-reply: per-player cooldown, a per-minute cap, a guild-member skip, and it
  will not answer a whisper that already contains your own Discord link
- `/who` is only ever fired from the Who button. Blizzard made `SendWho()`
  protected; an addon calling it from an event gets blocked, which is why level
  and guild need one click each. Class needs no lookup — it comes free from the
  whisper's GUID.

## The shared BiS channel

Nebbinator carries `LibBiSComm`, the channel every BiS addon speaks on. Having
this addon installed is enough to answer any BiS summoner in your raid about
where you are and whether a summon landed - you do not need their addon too.

It is not a Nebbinator feature and nothing here can switch it off: turn off
auto-reply, preview mode, the lead finder, the minimap button, all of it, and
the channel keeps answering. `/bis off` is the only mute, and Nebbinator
remembers it for next login.

Nebbinator puts no traffic of its own on the wire.

## Look

FojjiCore's flat shape on the BiS palette: no Blizzard templates, no backdrop
art, every surface a plain colour and every border four 1px textures. A 16 px
header at half alpha, a 1 px `edge` border, 12x12 header boxes. Uses `BiSTheme`
when it is installed and the same values inline when it is not - and ships a
copy of `Console.lua` so the prompt works either way.

## Files

    Libs/BiSTheme/       Console.lua - the BiS> prompt, copied from BiSTheme
    Libs/LibBiSComm-1.0/ the shared channel, copied from _bisdev
    Core/Util.lua        palette, class tables, string helpers, message splitting
    Core/Init.lua        saved variables, migration, slash commands, the toggles
    Core/Message.lua     tokens, rendering, channels, sending
    Core/Responders.lua  whisper capture, auto-reply, /who parsing
    UI/Kit.lua           flat primitives and widgets
    UI/Window.lua        the frame, the desk/book sizing, the rail, ConfigSet/Get
    UI/SendBar.lua       channel buttons, their timers, and pinning
    UI/Desk.lua          the queue, the served block, the auto-height
    UI/Pages/*.lua       one file per tab in the book
    UI/Minimap.lua       minimap button
    dev/                 headless test harness - see dev/README.md
    CHANGELOG.md         what changed, per version
    _backup_v1/          the original 1.0
    _backup_v2/          the 2.0 two-window build

Your old settings are read once and migrated forward: 1.x `NubbinatorDB` into
`NebbinatorDB`, then v2 into v3. Needs, raid times, templates, quick replies and
responders all carry over.
