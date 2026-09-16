Read ../_bisdev/CLAUDE.md first.

## Layout (Nebbinator only)

- `Nebbinator.toc`: Interface 20506. It holds the load order and is the only place the version lives (`## Version`, currently 3.3.1). `NS.VERSION` reads it through `GetAddOnMetadata`, and `dev/release.ps1` and every dev suite read the TOC too. SavedVariables are `NebbinatorDB, NubbinatorDB`. `## OptionalDeps: BiSTheme`. Load order: `Libs` → `Core\Util`, `Init`, `Message`, `Responders` → `UI\Kit`, `Window`, `SendBar`, `Desk`, `Options`, `Pages\*`, `Minimap`.
- Every file starts with `local ADDON, NS = ...`, and each module hangs off `NS` (`NS.Util`, `NS.Message`, `NS.Responders`, `NS.Kit`, `NS.UI`, `NS.Minimap`). `NS` is exposed as `_G.Nebbinator`. Files reach sibling modules through `NS.*`, never a bare local, because later files would not exist yet when an earlier one loads.
- `Core/Init.lua` (425 lines): the namespace, the DB, slash commands and boot. Sections are split by `----` banners:
  - Defaults, plus migration from 1.x (`NS.DB_VERSION`, currently 3; the value is stored in `db.dbVersion`). `NS:LoadDB` reads `NebbinatorDB or NubbinatorDB` (1.x used the old name). v1 goes through `MigrateV1`; v2 → v3 only fills in new keys and drops `db.windows`.
  - Toggles (`NS.TogglePreview`, `NS.ToggleAutoReply`, `NS.SetChannels`, `NS.SetDiscord`, `NS.ToggleMinimap`, `NS.ResetWindow`). A slash command and a UI control must both call these functions, never write the key themselves.
  - The shared BiS channel (`NS.Comm`, on the embedded LibBiSComm-1.0)
  - Slash commands `/nebbinator`, `/nb`, `/ns`. Subcommands: `show`, `r`, `book`, `config`/`options`/`settings`, `preview`/`test`, `reply`, `channels <a, b>`, `discord <link>`, `minimap`, `reset`.
  - Events: `ADDON_LOADED`, then `PLAYER_LOGIN` → `NS:Initialize()`, then `PLAYER_LOGOUT` → `NS.Comm.Save()`
- `Core/Util.lua` (359 lines): has no side effects. Contains the palette (`NS.T`, which uses `BiSTheme` when loaded and otherwise the same hex values inline), the TBC class/spec table `NS.CLASSES` (its order is used everywhere) and string helpers.
- `Core/Message.lua` (290 lines): template tokens (`{guild}`, `{discord}`, ...), rendering, channels, and a chat-safe split/send queue (`NS.CHAT_LIMIT` = 255).
- `Core/Responders.lua` (481 lines): guild roster, incoming whispers, a passive lead finder, auto-reply with a rate cap, and a `/who` lookup (`WHO_INTERVAL` 3.5 s, needs a real button click). Also the actions the desk uses.
- `UI/Kit.lua` (487 lines): `NS.Kit`, flat drawing primitives with no Blizzard templates or backdrops. Holds the primitives, flat button, text input, scrolling, multi-line box and copy box. Everything lives in one table because of the Lua 5.1 limit of 200 locals per chunk.
- `UI/Window.lua` (664 lines): `NS.UI`, the single window (`NebbinatorFrame`). Its sections are widgets, live effects, the frame, rolling the book up and down, the prompt, and "driving it without a screen". Controls write the same saved variable as the slash commands, through the same function.
- The other `UI/` files:
  - `Desk.lua` (434 lines): the queue of responders, one row each, with filters. The row being served opens up.
  - `SendBar.lua` (217 lines): one send button per channel, each with a cooldown clock. Right-click hides a channel.
  - `Options.lua` (102 lines): only the option list for the shared `Libs\BiSTheme\Options.lua` window. Every `set` calls the function the slash command already uses.
  - `Minimap.lua` (112 lines): `NebbinatorMinimapButton`, uses no libraries.
- `UI/Pages/`: the pages of the book (the tab rail). `Recruit.lua` covers needs, raid times and the preview. `Message.lua` covers guild details, templates and tokens. `Replies.lua` covers the four quick replies and the auto-reply. `About.lua` is the about page.
- `Libs/`: embedded copies of `BiSTheme/Console.lua`, `BiSTheme/Options.lua` and `LibBiSComm-1.0`.
- `dev/harness.lua` (478 lines): the real stub library, not a shim.
  - Paint setters (`SetColorTexture`, `SetVertexColor`, `SetTextColor`, `SetFont`) throw an error unless they get real numbers, and they record what they were given.
  - `SetPoint` is recorded for layout checks.
  - Any global outside `ALLOWED_GLOBALS` fails the run.
  - `H.TOC(root, "Nebbinator.toc")` turns the TOC into the load list, and `H.Load` runs each file as `chunk("Nebbinator", NS)`.
- `dev/tests.lua` (929 lines): the main suite, `lua5.1 dev/tests.lua`. It loads files in TOC order and seeds a v1 `NubbinatorDB` so the migration runs every time. `NEB=<path>` runs it against a scratch copy, which is how you check that a stub still catches a deliberately broken copy.
- `dev/options.lua` (199 lines): tests `Libs/BiSTheme/Options.lua` on its own, from a hand list (`OPT=` overrides the root). It expects `T.OPTIONS_MINOR` to be 2.
- `dev/theme.lua` (30 lines): checks the palette both without and with BiSTheme. It needs the real `../BiSTheme/BiSTheme.lua` next to this checkout (`BISTHEME=` overrides).
- `dev/suite.lua`: a stub left after a rename. It only errors and points you to `dev/tests.lua`. There are no stress, kit or load suites.
- `dev/README.md`: how to run the suites, why the stubs are strict, and a table of past test-breaking mutations.
- `dev/release.ps1`: zips the addon into Downloads and uploads it to CurseForge project 1683356 (unlisted).
  - Switches: `-Type alpha|beta|release` (alpha by default), `-ZipOnly`, `-Force`.
  - It sends the top entry of `CHANGELOG.md` and writes a `.uploaded` marker so a version goes up only once.
- `.github/workflows/check.yml`: calls the reusable `bisdev` workflow with `addon: Nebbinator`.
- `_backup_v1/` and `_backup_v2/`: old UI and Core, kept in git but not listed in the TOC, so they never load. Leave them alone.
- `Claude outputs/`: holds an old `Nebbinator-3.0.0.zip`, which git ignores because of `*.zip`.
