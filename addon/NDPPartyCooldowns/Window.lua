-- The settings window: the party cooldowns page of Naowh Defensive Planner in a window of its own.
-- Loads before PartyCooldowns.lua, which keeps ns.UIKit from load time.
local _,ns=...
local W=ns.Widgets
local C=W.colors
local WIDTH,HEIGHT=952,700
local window,body,status,close
local state={drafts={}}
local Refresh
local function notify(text,error)
    if error then text=tostring(text):gsub("^.-%.lua:%d+:%s*","")end
    state.message=text;state.error=error;if status then status:SetText(text or"");status:SetTextColor(unpack(error and C.warning or C.muted))end
end
local function done(value,error,message)
    if not value then notify(error or"Change could not be saved",true);return false end
    state.message=message or"Saved";state.error=false;Refresh();return true
end
local function classColor(class)
    local c=class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class];if c then return{c.r,c.g,c.b,1}end;return C.text
end
local function header(parent,title,subtitle)
    W.Label(parent,title,0,0,600,20,C.text,true);W.Label(parent,subtitle,0,29,600,12,C.muted)
end
Refresh=function()
    if not window then return end
    if W.popup then W.popup:Hide()end
    W.Clear(body);W.Begin();ns.UIControls={["pcd-close"]=close};ns.UIScrolls={};W.scrollPositions=state.scrolls
    body=W.Frame("Frame",nil,window);body:SetPoint("TOPLEFT",16,-62);body:SetSize(920,600);body.surface=C.background
    ns.ExtraPages.partycds(body)
    W.Finish();notify(state.message or"",state.error)
end
ns.UIKit={state=state,notify=notify,done=done,header=header,classColor=classColor,refresh=function()Refresh()end}
function ns.OpenPartyCooldownWindow()
    if not window then
        window=W.Panel(UIParent,0,0,WIDTH,HEIGHT,C.background,C.line,10);window:ClearAllPoints();window:SetPoint("CENTER");window:SetFrameStrata("DIALOG")
        window:SetMovable(true);window:EnableMouse(true);window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart",function(self)if not(InCombatLockdown and InCombatLockdown())then self:StartMoving()end end)
        window:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end)
        local sw=GetScreenWidth and GetScreenWidth()or 1920;local sh=GetScreenHeight and GetScreenHeight()or 1080
        window:SetScale(math.min(1,math.max(0.55,(sw-30)/WIDTH),math.max(0.55,(sh-50)/HEIGHT)))
        window:EnableKeyboard(true);window:SetPropagateKeyboardInput(true)
        window:SetScript("OnKeyDown",function(self,key)if key=="ESCAPE"then self:Hide()end end)
        window:SetScript("OnHide",function()if W.popup then W.popup:Hide()end end)
        W.Label(window,"NDP Party Cooldowns",20,18,400,16,C.text,true)
        W.Label(window,"v"..tostring(ns.version).." · /pcd help",20,40,400,11,C.faint)
        close=W.Button(window,"",WIDTH-44,14,28,function()window:Hide()end,false,"pcd-close",{h=28,kind="ghost",glyph="close",tooltip="Close"})
        status=W.Label(window,"",20,HEIGHT-24,WIDTH-40,11,C.muted)
        ns.PartyCooldownWindow=window
    end
    state.message=nil;state.error=nil
    Refresh();window:Show()
end
