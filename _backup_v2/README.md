# Nebbinator 2.0

Guild recruitment for WoW TBC (Anniversary). Build the ad, click to post it, and
handle everyone who whispers back.

## Commands

    /nb                open the recruitment window
    /nb r              open the responders window
    /nb preview        toggle preview mode (prints instead of sending)
    /nb reply          toggle auto-reply
    /nb discord <url>  set the Discord invite
    /nb minimap        show/hide the minimap button
    /nb reset          reset window positions

Minimap button: left click = recruitment window, right click = responders.

## Tabs

**Recruit** - class/spec counts, raid times, a live preview of the exact text
that will be sent, and one button per chat channel you are actually in.

**Message** - guild name, Discord link, content, prefix/suffix, and any number
of saved templates. Tokens: {needs} {needs:short} {times} {times:full} {guild}
{discord} {content} {tanks} {healers} {dps} {total} {pre} {post} {player}
{level} {realm} {faction}

**Auto-reply** - whisper answers with your Discord link. Off by default. Only
fires on whispers containing a trigger word, once per player per cooldown,
never to guild members, and never more than N per minute.

## Nothing is ever sent on a timer

Ads go out only when you press a channel button. Auto-reply is the one thing
that sends by itself, and only in response to somebody whispering you first.

## Safety rails

- 10s cooldown per channel between posts (configurable)
- messages over 255 characters are split and staggered instead of truncated
- preview mode prints everything to chat instead of sending
- auto-reply: per-player cooldown, per-minute cap, guild-member skip, and it
  will not answer a whisper that already contains your own Discord link

## Files

    Core/Util.lua        class tables, string helpers, message splitting
    Core/Init.lua        saved variables, v1 migration, slash commands
    Core/Message.lua     tokens, rendering, channels, sending
    Core/Responders.lua  whisper capture, auto-reply, /who lookups
    UI/Widgets.lua       shared widget helpers
    UI/MainWindow.lua    the three tabs
    UI/RespondersWindow.lua
    UI/Minimap.lua
    _backup_v1/          the original 1.0 files, untouched

Your 1.0 settings (NubbinatorDB) are read once and migrated into NebbinatorDB.
