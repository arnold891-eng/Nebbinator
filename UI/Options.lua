-- Nebbinator :: UI/Options.lua
--
-- The options window, built on BiSTheme's shared kit. Arn, 10 Sep 2026, looking
-- at BiSTools' Hub: "this is beautiful ... I want all option windows to look
-- like this." Nebbinator is the second addon to wear it, which is why the
-- generic half lives in Libs\BiSTheme\Options.lua and this file is only a list.
--
-- The Settings TAB is gone. One place for settings across every BiS addon beats
-- a different place per addon, and a tab inside a working desk was the odd one
-- out. What did not fit the four control kinds went where it belongs instead:
--
--   logs address     -> the box on the desk, where you actually use it
--   extra channels   -> /nb channels <a, b>   (a free-text field is not a control)
--   alert sound      -> a stepper that walks NS.SOUNDS and plays what it lands on
--
-- EVERY `set` HERE CALLS THE FUNCTION THE SLASH COMMAND ALREADY OWNS. None of
-- them writes a saved variable itself. Two paths that write the same key
-- separately drift; two paths through one function cannot.

local ADDON, NS = ...
local UI = NS.UI

--- The addon's own section, then the ones that group its settings. Labels are
--- plain words a raider understands and stay under ~24 characters: the kit's
--- budget is W - 12 - 110 and BiSTheme.Fit is the net, not the plan.
function UI:OptionSections()
    return {
        { title = "nebbinator", options = {
            { kind = "toggle", label = "minimap button",
              get = function() return not NS.db.minimap.hide end,
              set = function() NS.ToggleMinimap() end },
            { kind = "toggle", label = "BiS channel (/biscomm)",
              get = function() local l = _G.LibBiSComm return l and l:Enabled() end,
              set = function(_, on) local l = _G.LibBiSComm if l then l:SetEnabled(on and true or false) end end },
            { kind = "button", label = "reset window position", button = "reset",
              action = function() NS.ResetWindow() end },
        } },

        { title = "posting", options = {
            { kind = "toggle", label = "preview - never sends",
              get = function() return NS.db.previewMode and true or false end,
              set = function() NS.TogglePreview() end },
            { kind = "step", label = "cooldown per channel", min = 5, max = 120, step = 5,
              get = function() return NS.db.sendCooldown or 10 end,
              set = function(_, v) NS.SetCooldown(v) end,
              show = function() return (NS.db.sendCooldown or 10) .. " s" end },
        } },

        { title = "answering", options = {
            { kind = "toggle", label = "auto-reply",
              get = function() return NS.db.autoReply.enabled and true or false end,
              set = function() NS.ToggleAutoReply() end },
            { kind = "toggle", label = "alert sound",
              get = function() return NS.db.autoReply.playSound and true or false end,
              set = function() NS.ToggleSound() end },
            { kind = "toggle", label = "only the first one",
              get = function() return NS.db.autoReply.soundOnlyNew and true or false end,
              set = function() NS.ToggleSoundOnlyNew() end },
            -- a stepper, not a grid: it plays each one as you land on it, so you
            -- can walk the whole list without leaving the row
            { kind = "step", label = "which sound", min = 1, max = #NS.SOUNDS, step = 1,
              get = function() return NS.Util.SoundIndex(NS.db.autoReply.sound or "bell") end,
              set = function(_, v) NS.SetSoundIndex(v) end,
              show = function()
                  local s = NS.Util.SoundByKey(NS.db.autoReply.sound or "bell")
                  return s.short or s.name
              end },
        } },

        { title = "finding people", options = {
            { kind = "toggle", label = "watch for \"LF guild\"",
              get = function() return NS.db.leadFinder and true or false end,
              set = function() NS.ToggleLeadFinder() end },
        } },
    }
end

function UI:BuildOptions()
    if self.opt then return self.opt end
    local f = BiSTheme.Options("NebbinatorOptions", BiSTheme.OPTIONS.W, "Options")
    self.opt = f
    f:Recenter(60)
    -- the desk shows preview and auto-reply in its own prompt slots
    f.onChange = function() UI:Refresh() end
    for _, section in ipairs(self:OptionSections()) do
        f:Section(section.title)
        for _, opt in ipairs(section.options) do f:Row(opt, NS.db) end
    end
    f:Fit()
    return f
end

function UI:ToggleOptions(want)
    self:BuildOptions():Toggle(want)
    if self.optBtn then self.optBtn:SetMarked(self.opt:IsShown()) end
end

--- Called from UI:Refresh so the window agrees with a slash command that ran
--- while it was open.
function UI:RefreshOptions()
    if self.opt and self.opt:IsShown() then self.opt:Paint() end
end
