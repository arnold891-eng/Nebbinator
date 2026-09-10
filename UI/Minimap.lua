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

    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", -1, 1)
    icon:SetTexture("Interface\\Icons\\INV_Scroll_11")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- a violet ring when somebody is waiting, so the button itself reports
    local ring = b:CreateTexture(nil, "ARTWORK")
    ring:SetSize(24, 24)
    ring:SetPoint("CENTER", -1, 1)
    ring:SetTexture("Interface\\Buttons\\WHITE8X8")
    ring:SetVertexColor(NS.T.rgba("accent", 0.30))
    ring:Hide()
    self.ring = ring

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
    if self.ring then
        if NS.Responders:CountNew() > 0 then self.ring:Show() else self.ring:Hide() end
    end
    Reposition(self.button)
end
