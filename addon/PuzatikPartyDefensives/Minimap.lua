-- Minimap button: a click opens or closes the window, a drag moves it around the minimap. The
-- addon is also in the game's addon menu (AddonCompartmentFunc in the toc), and when another addon
-- has loaded the shared minimap button library, the button is registered there so minimap button
-- collectors gather it with the others.
local _,ns=...
local L=ns.L
local ICON="Interface\\AddOns\\PuzatikPartyDefensives\\Media\\Icon"
local button,lib
local function Settings()
    local s=ns.Store();s.minimap=type(s.minimap)=="table"and s.minimap or{angle=200}
    s.minimap.lib=type(s.minimap.lib)=="table"and s.minimap.lib or{hide=s.minimap.hide}
    return s.minimap
end
function ns.TogglePartyCooldownWindow()
    local w=ns.PartyCooldownWindowFrame and ns.PartyCooldownWindowFrame()
    if w and w:IsShown()then w:Hide()else ns.OpenPartyCooldownWindow()end
end
function PuzatikPartyDefensives_Compartment()ns.TogglePartyCooldownWindow()end
local function Lines(tip)
    tip:AddLine("|cffb88cffPuzatik|r Party Defensives")
    tip:AddLine(L("Click: settings. Drag: move the button."),1,1,1)
end
local function Place()
    local a=math.rad(Settings().angle or 200);local r=(Minimap:GetWidth()or 140)/2+5
    button:ClearAllPoints();button:SetPoint("CENTER",Minimap,"CENTER",math.cos(a)*r,math.sin(a)*r)
end
local function Build()
    local s=Settings()
    local broker=LibStub and LibStub("LibDataBroker-1.1",true);local icons=LibStub and LibStub("LibDBIcon-1.0",true)
    if broker and icons then
        local object=broker:NewDataObject("PuzatikPartyDefensives",{type="launcher",icon=ICON,label="Puzatik Party Defensives",
            OnClick=function()ns.TogglePartyCooldownWindow()end,OnTooltipShow=Lines})
        if object then icons:Register("PuzatikPartyDefensives",object,s.lib);lib=icons;return end
    end
    if not Minimap then return end
    button=CreateFrame("Button","PuzatikPartyDefensivesMinimapButton",Minimap)
    button:SetSize(31,31);button:SetFrameStrata("MEDIUM");button:SetFrameLevel(8)
    button:RegisterForClicks("AnyUp");button:RegisterForDrag("LeftButton")
    local bg=button:CreateTexture(nil,"BACKGROUND");bg:SetSize(20,20);bg:SetPoint("CENTER");bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon=button:CreateTexture(nil,"ARTWORK");icon:SetSize(20,20);icon:SetPoint("CENTER");icon:SetTexture(ICON)
    local ring=button:CreateTexture(nil,"OVERLAY");ring:SetSize(53,53);ring:SetPoint("TOPLEFT");ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnClick",function()ns.TogglePartyCooldownWindow()end)
    button:SetScript("OnEnter",function(self)GameTooltip:SetOwner(self,"ANCHOR_LEFT");Lines(GameTooltip);GameTooltip:Show()end)
    button:SetScript("OnLeave",function()GameTooltip:Hide()end)
    button:SetScript("OnDragStart",function(self)self:SetScript("OnUpdate",function()
        local mx,my=Minimap:GetCenter();local px,py=GetCursorPosition();local scale=Minimap:GetEffectiveScale()
        s.angle=math.deg(math.atan2(py/scale-my,px/scale-mx));Place()
    end)end)
    button:SetScript("OnDragStop",function(self)self:SetScript("OnUpdate",nil)end)
    Place();if s.hide then button:Hide()end
end
-- /pcd minimap: show or hide the button.
function ns.SetPartyMinimapButton(show)
    local s=Settings();s.hide=not show;s.lib.hide=not show
    if lib then if show then lib:Show("PuzatikPartyDefensives")else lib:Hide("PuzatikPartyDefensives")end
    elseif button then button:SetShown(show)end
    return show
end
function ns.PartyMinimapButtonShown()return not Settings().hide end
local login=CreateFrame("Frame");login:RegisterEvent("PLAYER_LOGIN");login:SetScript("OnEvent",function()pcall(Build)end)
