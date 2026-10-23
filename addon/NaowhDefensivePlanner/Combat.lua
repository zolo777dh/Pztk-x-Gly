-- Combat tools, like the NSRT pages of the same purpose: an interrupt rotation display, pace
-- against your best pull, and a large display of your own private auras. Each listens to its
-- events only while it is switched on.
local _,ns=...
local W=ns.Widgets
local C=W.colors
local L=ns.L
local kit=ns.UIKit

local defaults={
    kicks={enabled=false,order="",fromNote=false,resetOnCombat=true,nameSize=16,numberSize=16,width=180,now="green",next="yellow",other="white",pos={x=-300,y=0}},
    pace={enabled=false,interval=5,history={}},
    auras={enabled=false,size=64,count=3,coTank=false,pos={x=0,y=-140}},
}
function ns.CombatConfig()
    local store=ns.Store();store.combat=store.combat or{}
    local c=store.combat
    for part,values in pairs(defaults)do c[part]=c[part]or{};for k,v in pairs(values)do if c[part][k]==nil then c[part][k]=type(v)=="table"and ns.Clone(v)or v end end end
    return c
end
local function Color(key,fallback)
    for _,o in ipairs(ns.LookColors or{})do if o.value==key and o.color then return o.color end end
    return fallback
end
local function Movable(frame,cfg,unlockedKey)
    frame:SetMovable(true);frame:SetClampedToScreen(true);frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",function(self)if cfg[unlockedKey]then self:StartMoving()end end)
    frame:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing()
        local x,y=self:GetCenter();local ux,uy=UIParent:GetCenter()
        if type(x)=="number"and type(ux)=="number"then cfg.pos={x=math.floor(x-ux+0.5),y=math.floor(y-uy+0.5)}end
    end)
end
---------------------------------------------------------------------------
-- Interrupt rotation: the names in order, the one to kick now and the next one coloured.
-- It moves on when a listed player's interrupt goes off. Your own casts are always visible;
-- other players' casts count when the game shows them.
local INTERRUPTS={[1766]=1,[6552]=1,[47528]=1,[2139]=1,[57994]=1,[96231]=1,[116705]=1,[106839]=1,[78675]=1,[183752]=1,[147362]=1,[187707]=1,[15487]=1,[351338]=1,[19647]=1,[119910]=1,[132409]=1,[89766]=1,[31935]=1,[217824]=1}
ns.InterruptSpells=INTERRUPTS
local kickFrame
local kickRows,kickIndex,kickNames={},1,{}
function ns.KickOrder()
    local k=ns.CombatConfig().kicks;local text=k.order or""
    if k.fromNote and ns.Notes then
        local live=ns.Notes().live;local note=live and live.text or""
        for line in(note.."\n"):gmatch("(.-)\n")do local rest=line:match("^%s*[Kk]ick[^:]*:%s*(.+)$");if rest then text=rest;break end end
    end
    local names={};for name in tostring(text):gmatch("[^,%s]+")do if #names<10 then names[#names+1]=name end end
    return names
end
local function KickFrame()
    if kickFrame then return kickFrame end
    local k=ns.CombatConfig().kicks
    kickFrame=CreateFrame("Frame",nil,UIParent);kickFrame:SetFrameStrata("HIGH");kickFrame:SetSize(180,40)
    kickFrame:SetPoint("CENTER",UIParent,"CENTER",tonumber(k.pos.x)or-300,tonumber(k.pos.y)or 0)
    kickFrame.bg=kickFrame:CreateTexture(nil,"BACKGROUND");kickFrame.bg:SetAllPoints();kickFrame.bg:SetColorTexture(0,0,0,0.35)
    Movable(kickFrame,k,"unlocked");kickFrame:Hide()
    return kickFrame
end
function ns.DrawKicks()
    local k=ns.CombatConfig().kicks;kickNames=ns.KickOrder()
    if not(k.enabled or k.unlocked)or(#kickNames==0 and not k.unlocked)then if kickFrame then kickFrame:Hide()end;return false end
    KickFrame()
    local names=#kickNames>0 and kickNames or{"Name 1","Name 2","Name 3"}
    if kickIndex>#names then kickIndex=1 end
    local font=W.Font and W.Font(true);local nameSize,ms=tonumber(k.nameSize)or 16,tonumber(k.numberSize)or 16;local h=math.max(nameSize,ms)+6
    for i,name in ipairs(names)do
        local row=kickRows[i]
        if not row then row={num=kickFrame:CreateFontString(nil,"OVERLAY","GameFontNormal"),name=kickFrame:CreateFontString(nil,"OVERLAY","GameFontNormal")};kickRows[i]=row end
        if type(font)=="string"then row.num:SetFont(font,ms,"OUTLINE");row.name:SetFont(font,nameSize,"OUTLINE")end
        local c=i==kickIndex and Color(k.now,{0.3,0.9,0.3,1})or i==(kickIndex%#names)+1 and Color(k.next,{1,0.85,0.1,1})or Color(k.other,{1,1,1,1})
        row.num:SetTextColor(c[1],c[2],c[3],1);row.name:SetTextColor(c[1],c[2],c[3],1)
        row.num:ClearAllPoints();row.num:SetPoint("TOPLEFT",kickFrame,"TOPLEFT",6,-(i-1)*h-3);row.num:SetText(tostring(i))
        row.name:ClearAllPoints();row.name:SetPoint("TOPLEFT",kickFrame,"TOPLEFT",10+ms,-(i-1)*h-3);row.name:SetText(name)
        row.num:Show();row.name:Show()
    end
    for i=#names+1,#kickRows do kickRows[i].num:Hide();kickRows[i].name:Hide()end
    kickFrame:SetSize(tonumber(k.width)or 180,#names*h+6);kickFrame:EnableMouse(k.unlocked==true)
    if k.unlocked then kickFrame.bg:Show()else kickFrame.bg:Hide()end
    kickFrame:Show();return true
end
-- Moves the rotation on after name kicked (or one step when name is nil).
function ns.KickDone(name)
    if #kickNames==0 then return false end
    if name then
        local short=ns.ShortName(name);local found
        for i,n in ipairs(kickNames)do if n:lower()==tostring(short):lower()or(ns.Nickname and ns.Nickname(short)and ns.Nickname(short):lower()==n:lower())then found=i end end
        if not found then return false end
        kickIndex=found%#kickNames+1
    else kickIndex=kickIndex%#kickNames+1 end
    ns.DrawKicks();return true
end
function ns.KickReset()kickIndex=1;ns.DrawKicks()end
function ns.KickIndex()return kickIndex end
---------------------------------------------------------------------------
-- Pace: boss health sampled every few seconds of a raid pull and compared with the best pull of
-- the same boss and difficulty (the kill, or the pull that got the boss lowest).
local pull
local function BossHealth()
    if not(UnitExists and UnitExists("boss1"))then return end
    local ok,h=pcall(UnitHealth,"boss1");local ok2,m=pcall(UnitHealthMax,"boss1")
    if ok and ok2 and ns.Plain(h,"number")and ns.Plain(m,"number")and m>0 then return h/m*100 end
end
local function PaceKey(encounter,difficulty)return tostring(encounter).."-"..tostring(difficulty)end
function ns.PaceDelta(best,samples)
    local i=#samples;if i==0 or not best or not best.samples or not best.samples[i]then return nil end
    return best.samples[i]-samples[i]
end
local function PaceTick()
    if not pull then return end
    local hp=BossHealth()
    if not hp then pull.hidden=true;ns.Notice("pace",L("Pace: boss health is hidden"),5,0.7,0.7,0.7);return end
    pull.samples[#pull.samples+1]=math.floor(hp*10+0.5)/10
    local best=ns.CombatConfig().pace.history[pull.key]
    local d=ns.PaceDelta(best,pull.samples)
    if d then ns.Notice("pace",string.format("%s %+.1f%%",L("Pace vs best:"),d),nil,d>=0 and 0.4 or 1,d>=0 and 1 or 0.35,d>=0 and 0.5 or 0.3)
    else ns.Notice("pace",string.format("%s %.1f%%",L("Boss health:"),hp),nil,1,1,1)end
end
function ns.PaceStart(encounter,difficulty)
    local p=ns.CombatConfig().pace;if not p.enabled then return false end
    if pull and pull.ticker then pull.ticker:Cancel()end
    pull={key=PaceKey(encounter,difficulty),samples={}}
    if C_Timer and C_Timer.NewTicker then pull.ticker=C_Timer.NewTicker(math.max(2,tonumber(p.interval)or 5),PaceTick)end
    return true
end
function ns.PaceEnd(success)
    if not pull then return end
    if pull.ticker then pull.ticker:Cancel()end
    local p=ns.CombatConfig().pace;local best=p.history[pull.key];local s=pull.samples;local last=s[#s]
    if success then last=0 end
    if last and not pull.hidden and(not best or(success and not best.kill)or(not best.kill and last<(best.lowest or 100))or(success and best.kill and #s<#best.samples))then
        p.history[pull.key]={samples=s,lowest=last,kill=success==true}
    end
    ns.Notice("pace",nil);pull=nil
end
---------------------------------------------------------------------------
-- Private auras: the game draws them into frames we place, so nothing here reads aura data.
local auraFrame
local auraAnchors={}
local function ClearAnchors()
    if C_UnitAuras and C_UnitAuras.RemovePrivateAuraAnchor then for _,id in ipairs(auraAnchors)do pcall(C_UnitAuras.RemovePrivateAuraAnchor,id)end end
    auraAnchors={}
end
local function OtherTank()
    if not(IsInRaid and IsInRaid())then return end
    for i=1,40 do local unit="raid"..i
        if UnitExists(unit)and not(UnitIsUnit and UnitIsUnit(unit,"player"))and UnitGroupRolesAssigned(unit)=="TANK"then return unit end
    end
end
function ns.DrawPrivateAuras()
    local a=ns.CombatConfig().auras;ClearAnchors()
    if not(a.enabled or a.unlocked)then if auraFrame then auraFrame:Hide()end;return false end
    if not auraFrame then
        auraFrame=CreateFrame("Frame",nil,UIParent);auraFrame:SetFrameStrata("HIGH")
        auraFrame:SetPoint("CENTER",UIParent,"CENTER",tonumber(a.pos.x)or 0,tonumber(a.pos.y)or-140)
        auraFrame.bg=auraFrame:CreateTexture(nil,"BACKGROUND");auraFrame.bg:SetAllPoints();auraFrame.bg:SetColorTexture(0,0.6,1,0.25)
        auraFrame.slots={};Movable(auraFrame,a,"unlocked")
    end
    local size=tonumber(a.size)or 64;local count=math.max(1,math.min(6,tonumber(a.count)or 3))
    local units={"player"};local tank=a.coTank and UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")=="TANK"and OtherTank();if tank then units[2]=tank end
    auraFrame:SetSize(count*(size+4),#units*(size+4));auraFrame:EnableMouse(a.unlocked==true)
    if a.unlocked then auraFrame.bg:Show()else auraFrame.bg:Hide()end
    local n=0
    for row,unit in ipairs(units)do for i=1,count do
        n=n+1;local slot=auraFrame.slots[n]
        if not slot then slot=CreateFrame("Frame",nil,auraFrame);auraFrame.slots[n]=slot end
        slot:SetSize(size,size);slot:ClearAllPoints();slot:SetPoint("TOPLEFT",auraFrame,"TOPLEFT",(i-1)*(size+4),-(row-1)*(size+4));slot:Show()
        if C_UnitAuras and C_UnitAuras.AddPrivateAuraAnchor then
            local ok,id=pcall(C_UnitAuras.AddPrivateAuraAnchor,{unitToken=unit,auraIndex=i,parent=slot,showCountdownFrame=true,showCountdownNumbers=true,
                iconInfo={iconWidth=size,iconHeight=size,iconAnchor={point="CENTER",relativeTo=slot,relativePoint="CENTER",offsetX=0,offsetY=0}}})
            if ok and id then auraAnchors[#auraAnchors+1]=id end
        end
    end end
    for i=n+1,#auraFrame.slots do auraFrame.slots[i]:Hide()end
    auraFrame:Show();return true
end
---------------------------------------------------------------------------
local events=CreateFrame("Frame")
local wanted={}
local function want(event,on)
    if(wanted[event]or false)==on then return end
    wanted[event]=on
    if on then pcall(events.RegisterEvent,events,event)elseif events.UnregisterEvent then events:UnregisterEvent(event)end
end
function ns.RefreshCombatTools()
    local c=ns.CombatConfig()
    local kicks=c.kicks.enabled and #ns.KickOrder()>0
    want("UNIT_SPELLCAST_SUCCEEDED",kicks and true or false)
    want("PLAYER_REGEN_ENABLED",kicks and c.kicks.resetOnCombat or false)
    want("ENCOUNTER_START",c.pace.enabled or kicks or false);want("ENCOUNTER_END",c.pace.enabled)
    want("GROUP_ROSTER_UPDATE",c.auras.enabled and c.auras.coTank or false)
    ns.DrawKicks();ns.DrawPrivateAuras()
end
events:SetScript("OnEvent",function(_,event,a,b,c,d,e)
    if event=="UNIT_SPELLCAST_SUCCEEDED"then
        if not ns.Plain(c,"number")or not INTERRUPTS[c]or not ns.Plain(a,"string")then return end
        local name=UnitName(a);if ns.Plain(name,"string")then ns.KickDone(name)end
    elseif event=="PLAYER_REGEN_ENABLED"then ns.KickReset()
    elseif event=="ENCOUNTER_START"then
        if ns.CombatConfig().kicks.enabled then ns.KickReset()end
        if IsInRaid and IsInRaid()then ns.PaceStart(a,c)end
    elseif event=="ENCOUNTER_END"then ns.PaceEnd(e==1)
    elseif event=="GROUP_ROSTER_UPDATE"then if not(InCombatLockdown and InCombatLockdown())then ns.DrawPrivateAuras()end end
end)
local login=CreateFrame("Frame");login:RegisterEvent("PLAYER_LOGIN");login:SetScript("OnEvent",function()ns.RefreshCombatTools()end)
---------------------------------------------------------------------------
local function DrawCombat(parent)
    local cfg=ns.CombatConfig();local k,p,a=cfg.kicks,cfg.pace,cfg.auras;local d=kit.state.drafts
    d.combat=d.combat or{order=k.order or""};local f=d.combat
    local function apply()ns.RefreshCombatTools();kit.refresh()end
    kit.header(parent,L("Combat tools"),L("Interrupt rotation, pace against your best pull and big private aura icons."))
    local colors={};for _,o in ipairs(ns.LookColors)do if o.value~=""then colors[#colors+1]={value=o.value,label=o.label}end end
    local sizes={};for _,s in ipairs({12,14,16,18,22,26})do sizes[#sizes+1]={value=s,label=tostring(s)}end
    local c1=W.Card(parent,0,56,298,536,L("Interrupt display"))
    W.Toggle(c1,L("Show the rotation"),k.enabled,12,34,274,function(v)k.enabled=v;apply()end,"kick:enabled")
    W.Field(c1,L("ORDER · NAMES, SPACE-SEPARATED"),f.order,12,66,274,"kick:order")
    W.Button(c1,L("Save order"),12,118,274,function()k.order=ns.UIControls["kick:order"]:GetText();ns.KickReset();ns.RefreshCombatTools();kit.done(true,nil,L("Rotation saved"))end,false,"kick-save",{align="CENTER"})
    W.Toggle(c1,L("Use the note's Kick: line instead"),k.fromNote,12,156,274,function(v)k.fromNote=v;apply()end,"kick:fromNote")
    W.Toggle(c1,L("Start over after combat"),k.resetOnCombat,12,186,274,function(v)k.resetOnCombat=v;apply()end,"kick:reset")
    W.Select(c1,L("NOW"),colors,k.now,12,220,84,function(v)k.now=v;apply()end,"kick:now")
    W.Select(c1,L("NEXT"),colors,k.next,107,220,84,function(v)k.next=v;apply()end,"kick:next")
    W.Select(c1,L("OTHERS"),colors,k.other,202,220,84,function(v)k.other=v;apply()end,"kick:other")
    W.Select(c1,L("NUMBER FONT"),sizes,tonumber(k.numberSize)or 16,12,276,130,function(v)k.numberSize=v;apply()end,"kick:numberSize")
    W.Select(c1,L("NAME FONT"),sizes,tonumber(k.nameSize)or 16,156,276,130,function(v)k.nameSize=v;apply()end,"kick:nameSize")
    local widths={};for _,w in ipairs({140,180,220,260})do widths[#widths+1]={value=w,label=w.." px"}end
    W.Select(c1,L("WIDTH"),widths,tonumber(k.width)or 180,12,332,130,function(v)k.width=v;apply()end,"kick:width")
    W.Button(c1,k.unlocked and L("Lock")or L("Unlock"),156,348,130,function()k.unlocked=not k.unlocked;apply()end,false,"kick-unlock",{kind="outline",align="CENTER"})
    W.Button(c1,L("Next kicker"),12,394,130,function()kit.done(ns.KickDone(),L("Save a rotation first"),L("Moved to the next kicker"))end,false,"kick-next",{align="CENTER"})
    W.Button(c1,L("Start over"),156,394,130,function()ns.KickReset();kit.notify(L("Rotation starts from the first name"))end,false,"kick-reset",{kind="outline",align="CENTER"})
    W.Label(c1,L("Moves on when a listed player interrupts. The game may hide other players' casts in combat; your own always count."),12,438,274,11,C.muted)
    local c2=W.Card(parent,310,56,298,536,L("Pace comparison"))
    W.Toggle(c2,L("Compare raid pulls with my best"),p.enabled,12,34,274,function(v)p.enabled=v;apply()end,"pace:enabled")
    local steps={};for _,s in ipairs({3,5,10})do steps[#steps+1]={value=s,label=L("Every").." "..s.." s"}end
    W.Select(c2,L("SAMPLE"),steps,tonumber(p.interval)or 5,12,68,274,function(v)p.interval=v;apply()end,"pace:interval")
    local saved=0;for _ in pairs(p.history)do saved=saved+1 end
    W.Label(c2,L("Saved best pulls")..": "..saved,12,126,274,12,C.text)
    W.Button(c2,L("Forget best pulls"),12,150,274,function()p.history={};kit.done(true,nil,L("Best pulls forgotten"))end,false,"pace-clear",{kind="danger",align="CENTER"})
    W.Label(c2,L("Shows on the text display (Quality of life). Plus means the boss is lower than at the same time of your best pull. The game may hide boss health; then pace says so."),12,194,274,11,C.muted)
    local c3=W.Card(parent,620,56,300,536,L("Private auras"))
    W.Toggle(c3,L("Big icons for my private auras"),a.enabled,12,34,276,function(v)a.enabled=v;apply()end,"auras:enabled")
    W.Toggle(c3,L("Also the other tank's (as tank)"),a.coTank,12,64,276,function(v)a.coTank=v;apply()end,"auras:coTank")
    local icon={};for _,s in ipairs({40,52,64,80,100})do icon[#icon+1]={value=s,label=s.." px"}end
    W.Select(c3,L("ICON SIZE"),icon,tonumber(a.size)or 64,12,98,130,function(v)a.size=v;apply()end,"auras:size")
    local counts={};for i=1,6 do counts[#counts+1]={value=i,label=tostring(i)}end
    W.Select(c3,L("ICONS"),counts,tonumber(a.count)or 3,158,98,130,function(v)a.count=v;apply()end,"auras:count")
    W.Button(c3,a.unlocked and L("Lock")or L("Unlock and preview"),12,156,276,function()a.unlocked=not a.unlocked;apply()end,false,"auras-unlock",{kind="outline",align="CENTER"})
    W.Label(c3,L("The game draws private auras itself into these slots, with their timers. Nothing reads the aura data."),12,200,276,11,C.muted)
end
ns.ExtraPages.combat=DrawCombat
