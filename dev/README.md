# Nebbinator dev harness

Not an addon — no `.toc`, so the client ignores this folder.

    cd Interface/AddOns/Nebbinator
    lua5.1 dev/tests.lua          # the whole window, headless
    lua5.1 dev/options.lua        # the shared options kit on its own
    lua5.1 dev/theme.lua          # palette, with and without BiSTheme (expects ../BiSTheme)
    .\dev\release.ps1 -ZipOnly    # the zip; refuses if an embedded lib drifted from canon
    lua5.1 ../_bisdev/bislint.lua Core/*.lua UI/*.lua UI/Pages/*.lua

`NEB=/some/other/copy lua5.1 dev/tests.lua` runs the suite against a scratch
copy, which is how the strict stubs get proved: reintroduce a bug on the copy
and watch the suite go red.

## What the harness is strict about, and why

- `SetColorTexture`, `SetVertexColor`, `SetTextColor` and `SetFont` **error**
  unless they got real numbers. `cond and T.rgba(n) or shade(n)` truncates a
  multi-return to one value; the live client throws on the spot and takes the
  whole window with it. Same for a multi-return that is not the last argument:
  `SetTextColor(T.rgba("ink2", 1), true)` passes `true` as green.
- Frames are **shown** when created and `IsVisible()` walks the ancestors, like
  the real client. A mock that gets this backwards makes visibility-gated code
  (the send-bar ticker) look dead when it is fine, and vice versa.
- `SetPoint` is **recorded**, so the layout tests can do the arithmetic a
  screenshot would show: nothing overlapping inside a responder card, no page
  drawing past the bottom of the window.
- New globals are trapped. Anything the addon leaks into `_G` beyond the
  allowlist fails the run.

## Proving a stub still works

    cp -r . /tmp/scratch
    # break one thing on the copy, e.g. in UI/Window.lua's Check sync:
    #   fill:SetColorTexture(get() and NS.T.rgba("accent", 1) or K.shade("field", 1))
    NEB=/tmp/scratch lua5.1 dev/tests.lua     # must fail

Both truncation shapes and both layout checks were verified this way when the
Fojji-style window was built.

Verified again when the prompt header and LibBiSComm went in (9 Sep 2026), five
mutations, each one caught:

| Break this | The test that goes red |
| --- | --- |
| gate the lib behind a feature toggle | "turning off autoReply leaves the lib on" |
| hardcode the version in Init.lua again | "NS.VERSION comes from the TOC" |
| print to chat instead of the prompt | "posting the ad says nothing in chat" |
| set the console's fade to 0 | "alpha on the way down, not a hard cut" |
| add a second button to the header | "one frame in the header: the close button" |

The console tests step the clock in 0.05 s slices, never in whole seconds: a
3 s jump expires a 3 s event before it is ever drawn, and that is a fact about
the test rather than about the console.
