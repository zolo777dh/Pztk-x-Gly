-- Party extras, beside the party cooldowns: crowd control on enemy nameplates, a kick rotation for
-- bosses, asking the healers for an external, and the externals, Bloodlust and potions on you.
-- The game draws the aura timers itself (aura containers), so they work in combat too.
local addonName,ns=...
local W=ns.Widgets
local C=W.colors
local L=ns.L
local kit=ns.UIKit

local SOUND="Interface\\AddOns\\"..tostring(addonName).."\\Media\\UI\\Alert.ogg"
local SOUND_NOW,SOUND_NEXT=8959,12889 -- raid warning, alarm clock
local LUST={2825,32182,80353,264667,390386,466904,381301,444062,444257,178207,230935,256740,309658}
local defaults={
    ccbars={on=false,width=110,height=14,sound=true},
    rotation={on=false,names="",accept=true,sound=true,size=44,x=-400,y=150},
    request={on=true,word="hx",whisper=false,sound=true,size=40,x=0,y=180},
    externals={on=false,size=40,sound=true,x=0,y=230},
    lust={on=false,size=40,sound=true,x=0,y=290},
}
function ns.PartyExtrasConfig()
    local cfg=ns.PartyCooldownConfig();cfg.extras=type(cfg.extras)=="table"and cfg.extras or{}
    for key,d in pairs(defaults)do
        local e=type(cfg.extras[key])=="table"and cfg.extras[key]or{};cfg.extras[key]=e
        for k,v in pairs(d)do if e[k]==nil then e[k]=v end end
    end
    return cfg.extras
end
local function Play(id)if PlaySound then pcall(PlaySound,id,"Master")end end
local function ClassColor(name)
    local m=ns.Plain(name,"string")and ns.PartyCooldownFind(name);local c=m and m.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
    return c and c.r or 1,c and c.g or 1,c and c.b or 1
end
local function Me()for _,m in pairs(ns.PartyCooldownMembers)do if m.me then return m end end end
-- Everything here follows the main switch and the load options: /pcd off turns it all off.
local StopAll -- defined with the refresh
local function Active()
    local cfg=ns.PartyCooldownConfig();return cfg.enabled==true and ns.PartyCooldownsLoaded()
end
ns.PartyExtrasActive=Active

-- A movable box of its own, placed by extras[key].x/y and dragged while the lists are unlocked.
local holders={}
local TITLES={rotation="Kick rotation",request="External request",externals="Externals on you",lust="Bloodlust and potions"}
local function Holder(key)
    local h=holders[key];if h then return h end
    h=CreateFrame("Frame",nil,UIParent);h:SetFrameStrata("MEDIUM");h:SetSize(60,60);h:SetMovable(true);h:SetClampedToScreen(true);h:RegisterForDrag("LeftButton")
    h.bg=h:CreateTexture(nil,"BACKGROUND");h.bg:SetAllPoints();h.bg:SetColorTexture(0.6,0.36,1,0.25);h.bg:Hide()
    h.title=h:CreateFontString(nil,"OVERLAY","GameFontNormal");h.title:SetPoint("BOTTOMLEFT",h,"TOPLEFT",2,2);h.title:SetText(L(TITLES[key]));h.title:Hide()
    h:SetScript("OnDragStart",function(self)if ns.PartyCooldownConfig().unlocked then self:StartMoving()end end)
    h:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing()
        local x,y=self:GetCenter();local ux,uy=UIParent:GetCenter()
        if type(x)=="number"and type(ux)=="number"then local e=ns.PartyExtrasConfig()[key];e.x,e.y=math.floor(x-ux+0.5),math.floor(y-uy+0.5);h.x,h.y=e.x,e.y end
    end)
    h:Hide();holders[key]=h;return h
end
ns.PartyExtraHolders=holders
local function Place(key)
    local h=Holder(key);local e=ns.PartyExtrasConfig()[key];local x,y=tonumber(e.x)or 0,tonumber(e.y)or 0
    if h.x~=x or h.y~=y then h:ClearAllPoints();h:SetPoint("CENTER",UIParent,"CENTER",x,y);h.x,h.y=x,y end
    local unlocked=ns.PartyCooldownConfig().unlocked==true
    h:EnableMouse(unlocked);if unlocked then h.bg:Show();h.title:Show()else h.bg:Hide();h.title:Hide()end
    return h,unlocked
end

---------------------------------------------------------------------------
-- Aura containers: the game lays out and times the auras of a unit that pass a filter. Built out
-- of combat only; a container then follows its unit by itself.
local function Container(parent)
    local ok,c=pcall(CreateFrame,"AuraContainer",nil,parent,"CustomAuraContainerTemplate")
    if not ok or not c or not c.AddAuraGroup then return nil end
    c:SetSize(1,1);pcall(c.EnableMouse,c,false)
    return c
end
local function Flow(c,vertical,corner)
    local axis,dir=AnchorUtil and AnchorUtil.FlowLayoutAxis,AnchorUtil and AnchorUtil.FlowDirection
    if not(axis and dir)then return end
    pcall(c.SetFlowLayoutAxis,c,vertical and axis.Vertical or axis.Horizontal)
    pcall(c.SetFlowLayoutAnchorPoint,c,corner or"TOPLEFT")
    pcall(c.SetFlowLayoutGrowthDirection,c,dir.Right,vertical and dir.Up or dir.Down)
end
-- An aura frame drawn as an icon with the game's cooldown swipe and seconds.
local function IconFrame(size,edge)
    return function(f)
        pcall(f.SetSize,f,size,size);pcall(f.SetMouseClickEnabled,f,false);pcall(f.SetMouseMotionEnabled,f,false)
        if edge then local e=f:CreateTexture(nil,"BACKGROUND");e:SetPoint("TOPLEFT",-2,2);e:SetPoint("BOTTOMRIGHT",2,-2);e:SetColorTexture(1,0.82,0,1)end
        local icon=f:CreateTexture(nil,"ARTWORK");icon:SetAllPoints();icon:SetTexCoord(0.07,0.93,0.07,0.93);pcall(f.SetIcon,f,icon)
        local cd=CreateFrame("Cooldown",nil,f,"CooldownFrameTemplate");cd:SetAllPoints();pcall(f.SetDurationCooldown,f,cd)
    end
end
-- An aura frame drawn as an icon and a bar that runs down with the aura.
local function BarFrame(width,height)
    return function(f)
        pcall(f.SetSize,f,width,height);pcall(f.SetMouseClickEnabled,f,false);pcall(f.SetMouseMotionEnabled,f,false)
        local icon=f:CreateTexture(nil,"ARTWORK");icon:SetSize(height,height);icon:SetPoint("LEFT",f,"LEFT",0,0);icon:SetTexCoord(0.07,0.93,0.07,0.93);pcall(f.SetIcon,f,icon)
        local bar=CreateFrame("StatusBar",nil,f);bar:SetPoint("TOPLEFT",f,"TOPLEFT",height+1,0);bar:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",0,0)
        bar:SetStatusBarTexture(ns.PartyBarFile and ns.PartyBarFile("")or"Interface\\TargetingFrame\\UI-StatusBar");bar:SetStatusBarColor(1,0.55,0.1,1)
        local bg=bar:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(0,0,0,0.55)
        local E=Enum;local opts={}
        if E and E.StatusBarInterpolation then opts.interpolation=E.StatusBarInterpolation.Immediate end
        if E and E.StatusBarTimerDirection then opts.direction=E.StatusBarTimerDirection.RemainingTime end
        pcall(f.SetDurationBar,f,bar,opts)
        local text=bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");text:SetPoint("RIGHT",bar,"RIGHT",-3,0)
        local font=W.Font and W.Font(true);if type(font)=="string"then pcall(text.SetFont,text,font,math.max(9,height-4),"OUTLINE")end
        pcall(f.SetDurationText,f,text,{})
    end
end
-- Sounds the game plays itself when an aura lands (works in combat): {unit, spell} pairs.
local sounds,soundState={},{registered=0,refused=0}
local function ClearSounds()
    local remove=C_UnitAuras and(C_UnitAuras.RemoveAuraSound or C_UnitAuras.RemoveAuraAppliedSound)
    for _,id in ipairs(sounds)do if remove then pcall(remove,id)end end
    sounds={}
end
local function AddSound(unit,spell,file)
    local api=C_UnitAuras;if not api then return false end
    local info={unitToken=unit,spellID=spell,soundFileName=file or SOUND,outputChannel="Master"}
    local ok,id
    if api.AddAuraSound then ok,id=pcall(api.AddAuraSound,Enum and Enum.UnitAuraSoundTrigger and Enum.UnitAuraSoundTrigger.Added or 0,info)
    elseif api.AddAuraAppliedSound then ok,id=pcall(api.AddAuraAppliedSound,info)end
    if ok and id then sounds[#sounds+1]=id;soundState.registered=soundState.registered+1;return true end
    soundState.refused=soundState.refused+1;return false
end
function ns.PartyExtrasSounds()return sounds,soundState end

-- Spells by the kind of aura the party cooldowns sense them with (1 own buff, 2 external, 3 enemy
-- debuff). `defensive`: only the defensive ones (no Blessing of Freedom and other movement).
local function AuraIDs(kind,defensive)
    local out,seen={},{}
    for id,b in pairs(ns.PartyCooldownBuffs or{})do if b[1]==kind and not(defensive and ns.PartyCooldownKind(id))then for i=2,#b do if not seen[b[i]]then seen[b[i]]=true;out[#out+1]=b[i]end end end end
    table.sort(out);return out
end
ns.PartyExtrasAuraIDs=AuraIDs
local function Set(list)local s={};for _,id in ipairs(list)do s[id]=true end;return s end

---------------------------------------------------------------------------
-- Crowd control on enemies: a bar over each enemy nameplate for every stun, fear or other
-- crowd control on it, running down with the debuff. The sound plays when one lands on your
-- target or focus.
local PLATES=40 -- as many as the party cooldown sensors watch
local plateBars={}
local function BuildPlateBars()
    local e=ns.PartyExtrasConfig().ccbars;local ids=Set(AuraIDs(3))
    for i=1,PLATES do local p=plateBars[i]
        if not p then
            local c=Container(UIParent);if not c then return false end
            pcall(c.SetUnit,c,"nameplate"..i);Flow(c,true,"BOTTOMLEFT")
            pcall(c.AddAuraGroup,c,"ccbars","HARMFUL",{maxFrameCount=3,candidateFilters={includeSpellIDs=ids},initializeFrame=BarFrame(e.width,e.height),
                layout={elementWidth=e.width,elementHeight=e.height+1,elementSpacing=0,lineSpacing=0}})
            p={frame=c,sig=e.width.."x"..e.height};plateBars[i]=p
        end
        -- Only a change of state needs the container to read its plate again.
        local on=e.on==true and Active()
        if p.on~=on then p.on=on;pcall(p.frame.SetEnabled,p.frame,on);if on then pcall(p.frame.UpdateAllAuras,p.frame)end end
        if not on then p.frame:Hide()end
    end
    -- Nameplates already up get their bars now, not only the ones added later.
    if e.on and Active()then for i=1,PLATES do local unit="nameplate"..i;if UnitExists and UnitExists(unit)then ns.PartyPlateAdded(unit)end end end
    return true
end
function ns.PartyPlateAdded(unit)
    local i=ns.Plain(unit,"string")and tonumber(unit:match("^nameplate(%d+)$"));local p=i and plateBars[i]
    if not p or not(ns.PartyExtrasConfig().ccbars.on and Active())then return end
    local plate=C_NamePlate and C_NamePlate.GetNamePlateForUnit and select(2,pcall(C_NamePlate.GetNamePlateForUnit,unit))
    if type(plate)=="table"then p.frame:ClearAllPoints();pcall(p.frame.SetPoint,p.frame,"BOTTOM",plate,"TOP",0,4);p.frame:Show()end
end
ns.PartyPlateBars=plateBars

---------------------------------------------------------------------------
-- Auras on you: the externals others put on you, and Bloodlust (and its kind) with combat potions.
local own={}
local function BuildOwn(key,filter,ids)
    local e=ns.PartyExtrasConfig()[key];local h=Place(key)
    local o=own[key]
    if not o or o.size~=e.size then
        if o then pcall(o.frame.SetEnabled,o.frame,false);o.frame:Hide()end
        local c=Container(h);if not c then return false end
        pcall(c.SetUnit,c,"player");Flow(c,false,"TOPLEFT");c:SetPoint("TOPLEFT",h,"TOPLEFT",0,0)
        pcall(c.AddAuraGroup,c,key,filter,{maxFrameCount=6,candidateFilters=ids and{includeSpellIDs=Set(ids)}or nil,initializeFrame=IconFrame(e.size,key=="externals"),
            layout={elementWidth=e.size+4,elementHeight=e.size,elementSpacing=0,lineSpacing=0}})
        o={frame=c,size=e.size};own[key]=o
    end
    h:SetSize(e.size*6+24,e.size)
    local on=e.on==true and Active()
    pcall(o.frame.SetEnabled,o.frame,on);if on then pcall(o.frame.UpdateAllAuras,o.frame);h:Show()else h:Hide()end
    return true
end
ns.PartyOwnAuras=own

---------------------------------------------------------------------------
-- Kick rotation: who interrupts the boss next. The list is a line of names; every interrupt that
-- lands on a boss moves it on. The one whose turn it is hears a sound when they become next and
-- when the boss starts a cast.
local rot={index=1,last=0}
function ns.KickRotationList()
    local out={}
    for name in(ns.PartyExtrasConfig().rotation.names or""):gmatch("[^,;%s]+")do out[#out+1]=name end
    return out
end
local function Next()local list=ns.KickRotationList();if #list==0 then return nil end;return list[(rot.index-1)%#list+1],(rot.index-1)%#list+1,#list end
-- A typed name with a realm must be yours exactly; without one, your name on any realm.
local function IsMe(name)
    if not(ns.Plain(name,"string")and UnitName)then return false end
    if name:find("-",1,true)then return ns.FullName(name)==ns.UnitFullName("player")end
    return name==UnitName("player")
end
function ns.DrawKickRotation()
    local e=ns.PartyExtrasConfig().rotation;local h,unlocked=Place("rotation")
    local name,pos,total=Next()
    if not(e.on and name and(rot.fight and Active()or unlocked))then h:Hide();return false end
    if not h.box then
        h.box=h:CreateTexture(nil,"ARTWORK");h.box:SetPoint("LEFT",h,"LEFT",0,0)
        h.num=h:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge");h.num:SetPoint("CENTER",h.box,"CENTER",0,0)
        h.name=h:CreateFontString(nil,"OVERLAY","GameFontHighlight");h.name:SetPoint("LEFT",h.box,"RIGHT",6,0)
    end
    local size=tonumber(e.size)or 44;local font=W.Font and W.Font(true)
    h:SetSize(size+130,size);h.box:SetSize(size,size)
    local mine=IsMe(name)
    if mine then h.box:SetColorTexture(1,0.82,0,0.9)else h.box:SetColorTexture(0.1,0.08,0.16,0.9)end
    if type(font)=="string"then pcall(h.num.SetFont,h.num,font,math.floor(size*0.6),"OUTLINE");pcall(h.name.SetFont,h.name,font,14,"OUTLINE")end
    h.num:SetText(tostring(pos));h.num:SetTextColor(mine and 0.1 or 1,mine and 0.1 or 0.2,mine and 0.1 or 0.2)
    local r,g,b=ClassColor(name)
    h.name:SetText(mine and L("You kick next")or((ns.DisplayName and ns.DisplayName(name)or name).." · "..pos.."/"..total));h.name:SetTextColor(r,g,b)
    h:Show();return true
end
-- An interrupt landed on a boss: the turn passes on (once per interrupt, whatever unit shows it).
function ns.KickRotationInterrupt(unit)
    if not(ns.Plain(unit,"string")and rot.fight and Active())then return false end
    local boss=unit:match("^boss%d")~=nil
    if not boss and UnitIsUnit then for i=1,5 do local ok,same=pcall(UnitIsUnit,unit,"boss"..i);if ok and same==true then boss=true end end end
    if not boss or GetTime()-rot.last<1.5 then return false end
    rot.last=GetTime();rot.index=rot.index+1
    local e=ns.PartyExtrasConfig().rotation
    if e.sound and IsMe(Next())then Play(SOUND_NEXT)end
    ns.DrawKickRotation();return true
end
function ns.KickRotationStart(on)rot.fight=on;rot.index=1;rot.last=0;ns.DrawKickRotation()end
function ns.KickRotationState()return rot end
-- The leader or an assistant shares the list with the group.
function ns.SendKickRotation()return ns.Send("PKR",ns.PartyExtrasConfig().rotation.names or"")end
ns.CommHandlers.PKR=function(text,sender,channel,full)
    local e=ns.PartyExtrasConfig().rotation;sender=ns.PartyCooldownSender(sender,channel,full)
    if not e.accept or not sender or type(text)~="string"or #text>300 or not ns.GroupAuthority(sender)then return end
    e.names=text;ns.DrawKickRotation()
end

---------------------------------------------------------------------------
-- External request: you ask, the healers of the group see who needs one and which of their
-- externals are ready. Players without this addon get the word in a whisper (switch).
local lastAsk,hideAt=0,nil
function ns.RequestExternal()
    if not(IsInGroup and IsInGroup())or not ns.PartyCooldownConfig().enabled or GetTime()-lastAsk<3 then return false end
    lastAsk=GetTime();local e=ns.PartyExtrasConfig().request
    ns.Send("PXR","1")
    if e.whisper and SendChatMessage then
        for _,m in pairs(ns.PartyCooldownMembers)do
            if not m.me and m.unit and UnitGroupRolesAssigned and UnitGroupRolesAssigned(m.unit)=="HEALER"then pcall(SendChatMessage,e.word or"hx","WHISPER",nil,m.name)end
        end
    end
    return true
end
-- Your externals that are ready now.
local function ReadyExternals()
    local me=Me();if not me then return{}end
    local out={}
    for _,id in ipairs(ns.PartyCooldownList(me))do local b=ns.PartyCooldownBuffs[id]
        if b and b[1]==2 and not ns.PartyCooldownKind(id)and ns.PartyCooldownReady(me,id)then out[#out+1]=id end
    end
    return out
end
ns.PartyReadyExternals=ReadyExternals
function ns.ShowExternalRequest(name)
    local e=ns.PartyExtrasConfig().request;if not e.on or not name or not Active()then return false end
    local h=Place("request");local size=tonumber(e.size)or 40
    if not h.text then
        h.text=h:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge");h.text:SetPoint("TOP",h,"TOP",0,0);h.icons={}
    end
    local font=W.Font and W.Font(true);if type(font)=="string"then pcall(h.text.SetFont,h.text,font,16,"OUTLINE")end
    h.text:SetText((ns.DisplayName and ns.DisplayName(name)or name).." "..L("needs an external"));h.text:SetTextColor(ClassColor(name))
    local ids=ReadyExternals()
    for i,id in ipairs(ids)do local t=h.icons[i]or h:CreateTexture(nil,"ARTWORK");h.icons[i]=t
        t:SetSize(size,size);t:ClearAllPoints();t:SetPoint("TOP",h,"TOP",(i-(#ids+1)/2)*(size+4),-24);t:SetTexture(W.SpellTexture(id));t:SetTexCoord(0.07,0.93,0.07,0.93);t:Show()
    end
    for i=#ids+1,#h.icons do h.icons[i]:Hide()end
    h:SetSize(math.max(220,#ids*(size+4)),size+24);h:Show()
    if e.sound then Play(SOUND_NOW)end
    hideAt=GetTime()+6
    if C_Timer and C_Timer.NewTimer then C_Timer.NewTimer(6.1,function()if hideAt and GetTime()>=hideAt and not ns.PartyCooldownConfig().unlocked then h:Hide()end end)end
    return true
end
ns.CommHandlers.PXR=function(_,sender,channel,full)
    sender=ns.PartyCooldownSender(sender,channel,full)
    if sender and ns.PartyCooldownMembers[sender]then ns.ShowExternalRequest(sender)end
end
function ns.PartyExternalWhisper(text,sender)
    local e=ns.PartyExtrasConfig().request
    if not(ns.Plain(text,"string")and ns.Plain(sender,"string"))then return false end
    local name=ns.FullName(sender);if not(name and ns.PartyCooldownMembers[name])then return false end
    if text:match("^%s*(.-)%s*$"):lower()==tostring(e.word or"hx"):lower()then return ns.ShowExternalRequest(name)end
    return false
end

---------------------------------------------------------------------------
-- Switched off (or not loaded here): sounds removed, containers stopped and every box hidden at
-- once; what the game refuses in combat is set up again by the refresh after combat.
function StopAll()
    ClearSounds()
    for _,p in pairs(plateBars)do pcall(p.frame.SetEnabled,p.frame,false);p.on=false;p.frame:Hide()end
    for _,o in pairs(own)do pcall(o.frame.SetEnabled,o.frame,false)end
    for key,h in pairs(holders)do if not(key=="request"and ns.PartyCooldownConfig().unlocked)then h:Hide()end end
    hideAt=nil
end
ns.PartyExtrasStop=StopAll
-- The sounds of the parts that are on, set again after any change.
local function Sounds(e)
    ClearSounds();if not Active()then return end
    if e.ccbars.on and e.ccbars.sound and next(plateBars)then for _,unit in ipairs({"target","focus"})do for _,id in ipairs(AuraIDs(3))do AddSound(unit,id)end end end
    if e.externals.on and e.externals.sound and own.externals then for _,id in ipairs(AuraIDs(2,true))do AddSound("player",id)end end
    if e.lust.on and e.lust.sound and own.lust then for _,id in ipairs(LUST)do AddSound("player",id)end end
end
local Refresh
function ns.RefreshPartyExtras()return ns.PartyCooldownTimed("extras refresh",Refresh)end
Refresh=function()
    local e=ns.PartyExtrasConfig()
    if InCombatLockdown and InCombatLockdown()then
        -- New containers wait for the end of combat; what is switched off stops at once.
        if not Active()then StopAll()
        else
            if not e.ccbars.on then for _,p in pairs(plateBars)do pcall(p.frame.SetEnabled,p.frame,false);p.on=false;p.frame:Hide()end end
            for key,o in pairs(own)do if not e[key].on then pcall(o.frame.SetEnabled,o.frame,false);if holders[key]then holders[key]:Hide()end end end
            if not e.request.on and holders.request then holders.request:Hide();hideAt=nil end
            Sounds(e)
        end
        ns.DrawKickRotation();return false
    end
    local on=Active()
    -- Containers are made only once something needs them.
    if e.ccbars.on or next(plateBars)then BuildPlateBars()end
    if e.externals.on or own.externals then BuildOwn("externals","HELPFUL|EXTERNAL_DEFENSIVE",nil)end
    if e.lust.on or own.lust then
        local ids={};for _,id in ipairs(LUST)do ids[#ids+1]=id end
        local potion=ns.PartyCooldownBuffs[ns.PartyCooldownPotion]or{};for i=2,#potion do ids[#ids+1]=potion[i]end
        BuildOwn("lust","HELPFUL",ids)
    end
    if ns.PartyCooldownConfig().unlocked then
        if e.request.on then local h=Place("request");h:SetSize(220,(tonumber(e.request.size)or 40)+24);h:Show()end
    elseif holders.request and not(on and e.request.on and hideAt and GetTime()<hideAt)then holders.request:Hide()end
    if on then Sounds(e)else StopAll()end
    ns.DrawKickRotation()
    return true
end
local events,refreshTimer=CreateFrame("Frame"),nil
for _,ev in ipairs({"PLAYER_LOGIN","PLAYER_REGEN_ENABLED","PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE","ENCOUNTER_START","ENCOUNTER_END","NAME_PLATE_UNIT_ADDED","CHAT_MSG_WHISPER","UNIT_SPELLCAST_START","UNIT_SPELLCAST_CHANNEL_START"})do pcall(events.RegisterEvent,events,ev)end
events:SetScript("OnEvent",function(_,event,a,b)
    if event=="NAME_PLATE_UNIT_ADDED"then ns.PartyPlateAdded(a)
    elseif event=="ENCOUNTER_START"then ns.KickRotationStart(true)
    elseif event=="ENCOUNTER_END"then ns.KickRotationStart(false)
    elseif event=="CHAT_MSG_WHISPER"then ns.PartyExternalWhisper(a,b)
    elseif event=="UNIT_SPELLCAST_START"or event=="UNIT_SPELLCAST_CHANNEL_START"then
        -- The boss starts a cast while it is your turn: kick now.
        local e=ns.PartyExtrasConfig().rotation
        if rot.fight and e.on and e.sound and Active()and ns.Plain(a,"string")and a:match("^boss%d$")and IsMe(Next())then Play(SOUND_NOW)end
    elseif event=="GROUP_ROSTER_UPDATE"then
        -- Joining or leaving a group can change what loads; one refresh for a burst of updates.
        if not refreshTimer and C_Timer and C_Timer.NewTimer then refreshTimer=C_Timer.NewTimer(0.5,function()refreshTimer=nil;ns.RefreshPartyExtras()end)end
    else ns.RefreshPartyExtras()end
end)

---------------------------------------------------------------------------
-- The Extras page.
function ns.DrawPartyExtras(parent,apply)
    local e=ns.PartyExtrasConfig()
    local function again()ns.RefreshPartyExtras();apply()end
    local left=W.Card(parent,0,56,454,566,L("Enemies and bosses"))
    W.Toggle(left,L("Crowd control bars on enemy nameplates"),e.ccbars.on,12,34,430,function(v)e.ccbars.on=v;again()end,"pcdx:ccbars")
    W.Toggle(left,L("Sound when crowd control lands on your target or focus"),e.ccbars.sound,12,62,430,function(v)e.ccbars.sound=v;again()end,"pcdx:ccsound")
    W.Label(left,L("Stuns, fears and other crowd control get a bar over the enemy's nameplate that runs down with the debuff. The game draws the bars, so they work in combat. Enemy nameplates must be shown."),12,92,430,11,C.muted)
    W.Toggle(left,L("Kick rotation on bosses"),e.rotation.on,12,150,430,function(v)e.rotation.on=v;again()end,"pcdx:rotation")
    local field=W.Field(left,L("ORDER (NAMES, SEPARATED BY COMMAS)"),e.rotation.names or"",12,180,430,"pcdx:names")
    W.OnText(field,function(self)e.rotation.names=self:GetText()end)
    W.Toggle(left,L("Sounds when you are next and when the boss casts"),e.rotation.sound,12,240,430,function(v)e.rotation.sound=v;again()end,"pcdx:rotsound")
    W.Toggle(left,L("Accept lists from the leader"),e.rotation.accept,12,268,430,function(v)e.rotation.accept=v;again()end,"pcdx:accept")
    -- What is typed is saved as it is typed; the buttons read the field too.
    local function names()local f=ns.UIControls["pcdx:names"];if f and f.GetText then e.rotation.names=f:GetText()end end
    W.Button(left,L("Send to group"),12,300,207,function()names();ns.DrawKickRotation();kit.done(ns.SendKickRotation(),L("Join a group first"),L("The order was sent"))end,false,"pcdx:send",{align="CENTER"})
    W.Button(left,L("Test"),235,300,207,function()names();ns.KickRotationStart(true);kit.refresh()end,false,"pcdx:rottest",{kind="outline",align="CENTER"})
    W.Label(left,L("Every interrupt that lands on a boss passes the turn on; a pull starts at the first name. The box shows whose turn it is and turns gold when it is yours."),12,340,430,11,C.muted)
    local right=W.Card(parent,466,56,454,566,L("You and your healers"))
    W.Toggle(right,L("Show external requests from the group"),e.request.on,12,34,430,function(v)e.request.on=v;again()end,"pcdx:request")
    W.Toggle(right,L("Also whisper the word to healers"),e.request.whisper,12,62,430,function(v)e.request.whisper=v;again()end,"pcdx:whisper")
    local word=W.Field(right,L("WORD"),e.request.word or"hx",12,92,120,"pcdx:word")
    W.OnText(word,function(self)local t=self:GetText();if t and t:match("%S")then e.request.word=t end end)
    W.Button(right,L("Ask for an external"),146,108,296,function()kit.done(ns.RequestExternal(),L("Join a group first"),L("Your healers were asked"))end,false,"pcdx:ask",{align="CENTER"})
    W.Label(right,L("Type /pcd ext or put it in a macro. Healers with this addon see who asked and their ready externals; a whisper of the word from a group member shows the same."),12,150,430,11,C.muted)
    W.Toggle(right,L("Externals on you"),e.externals.on,12,206,430,function(v)e.externals.on=v;again()end,"pcdx:externals")
    W.Toggle(right,L("Sound when an external lands on you"),e.externals.sound,12,234,430,function(v)e.externals.sound=v;again()end,"pcdx:extsound")
    W.Toggle(right,L("Bloodlust and combat potions on you"),e.lust.on,12,270,430,function(v)e.lust.on=v;again()end,"pcdx:lust")
    W.Toggle(right,L("Sound on Bloodlust"),e.lust.sound,12,298,430,function(v)e.lust.sound=v;again()end,"pcdx:lustsound")
    W.Label(right,L("The game draws these icons with their time left. Unlock on the Display page to move every box."),12,334,430,11,C.muted)
    local _,st=ns.PartyExtrasSounds()
    W.Label(right,L("Sounds set")..": "..st.registered..(st.refused>0 and(", "..L("refused")..": "..st.refused)or""),12,530,430,11,C.soft)
end
