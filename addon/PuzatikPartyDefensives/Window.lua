-- The settings window: the party cooldowns page in a window of its own.
-- Loads before PartyCooldowns.lua, which keeps ns.UIKit from load time.
local _,ns=...
local W=ns.Widgets
local C=W.colors
-- Black and violet from the Puzatik icon. The colours change in place, so every module holding W.colors sees them.
local palette={
    background="08050f",sidebar="0c0816",panel="120c1f",raised="1a1230",hover="24193f",line="2d2148",lineStrong="4a3878",
    accent="9b5cff",accentSoft="26164a",accentText="c9a8ff",brand="b88cff",brandDark="7a3fe0",
    text="efe9fb",soft="c8bde0",muted="9d90b8",faint="645880",iconIdle="8475a3",dark="08050f",warning="ffb347",
}
for key,value in pairs(palette)do
    local c=C[key];c[1],c[2],c[3],c[4]=tonumber(value:sub(1,2),16)/255,tonumber(value:sub(3,4),16)/255,tonumber(value:sub(5,6),16)/255,1
end
W.icon="Interface\\AddOns\\PuzatikPartyDefensives\\Media\\Icon"
local WIDTH,HEIGHT=952,724
local window,body,status,close,language
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
    W.Clear(body);W.Begin();ns.UIControls={["pcd-close"]=close,["pcd-language"]=language};ns.UIScrolls={};W.scrollPositions=state.scrolls
    body=W.Frame("Frame",nil,window);body:SetPoint("TOPLEFT",16,-86);body:SetSize(920,600);body.surface=C.background
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
        W.Texture(window,W.icon,12,8,72,72)
        W.Label(window,"Puzatik Party Defensives",92,22,500,20,C.brand,true)
        W.Label(window,"v"..tostring(ns.version).." · /pcd help",92,50,400,11,C.faint)
        language=W.Select(window,ns.L("LANGUAGE"),{{value="auto",label="Auto (game client)"},{value="enUS",label="English"},{value="ruRU",label="Русский"}},
            PuzatikPartyDefensivesDB and PuzatikPartyDefensivesDB.lang or"auto",WIDTH-250,8,190,function(v)
            ns.SetLanguage(v);if ns.RefreshPartyCooldowns then ns.RefreshPartyCooldowns()end;Refresh()end,"pcd-language")
        close=W.Button(window,"",WIDTH-44,14,28,function()window:Hide()end,false,"pcd-close",{h=28,kind="ghost",glyph="close",tooltip=ns.L("Close")})
        status=W.Label(window,"",20,HEIGHT-24,WIDTH-40,11,C.muted)
        ns.PartyCooldownWindow=window
    end
    state.message=nil;state.error=nil
    Refresh();window:Show()
end
