-- Nebbinator :: UI/Minimap.lua
-- A small draggable minimap button. No libraries.

local ADDON, NS = ...

NS.Minimap = {}
local MB = NS.Minimap

local RADIUS = 80

local function Reposition(button)
    local angle = math.rad(NS.db.minimap.angle or 205)
    button:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(angle) * RADIUS, math.sin(angle) * RADIUS)
end

function MB:Initialize()
    if self.button then return end

    local b = CreateFrame("Button", "NebbinatorMinimapButton", Minimap)
    self.button = b
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetMovable(true)

    -- A violet pad with a star on it. The pad is BACKGROUND and the star is
    -- ARTWORK, in that order, because the old build had them the other way
    -- round: a 24x24 solid square sitting ON TOP of the icon.
    local pad = b:CreateTexture(nil, "BACKGROUND")
    pad:SetSize(20, 20)
    pad:SetPoint("CENTER", -1, 1)
    pad:SetTexture("Interface\\Buttons\\WHITE8X8")
    self.pad = pad

    -- The star comes off the raid-target sheet, not Interface\Icons. Raid
    -- markers are core UI art, so the file is in every client - the old
    -- INV_Scroll_11 path evidently was not, and the button drew nothing at all.
    -- The sheet is a 4x2 grid; the star is the top-left cell.
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetPoint("CENTER", -1, 1)
    icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    icon:SetTexCoord(0, 0.25, 0, 0.25)
    self.icon = icon

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            NS.UI:Open()
            NS.UI:ToggleBook()
        else
            NS.UI:Toggle()
        end
    end)

    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            NS.db.minimap.angle = math.deg(math.atan2(cy - my, cx - mx))
            Reposition(self)
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Nebbinator", NS.T.rgb("accent"))
        GameTooltip:AddLine("Left click: open the window", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Right click: roll out the rest", 0.9, 0.9, 0.9)
        local new = NS.Responders:CountNew()
        if new > 0 then
            GameTooltip:AddLine(new .. " new responder" .. (new > 1 and "s" or ""), NS.T.rgb("good"))
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    Reposition(b)
    self:Update()
end

function MB:Update()
    if not self.button then return end
    if NS.db.minimap.hide then self.button:Hide() else self.button:Show() end

    -- The button reports for itself: idle is a dim star on a quiet pad, waiting
    -- is a full-bright star on accent. Same two textures either way, so there
    -- is nothing that can cover the icon up.
    if self.pad and self.icon then
        if NS.Responders:CountNew() > 0 then
            self.pad:SetVertexColor(NS.T.rgba("accent", 0.85))
            self.icon:SetVertexColor(1, 1, 1)
        else
            self.pad:SetVertexColor(NS.T.rgba("accentSoft", 0.90))
            self.icon:SetVertexColor(0.78, 0.74, 0.88)
        end
    end

    Reposition(self.button)
end
