-- Party cooldowns: the important cooldowns of every specialization (personal defensives, externals,
-- raid cooldowns and burst) for each member of your party, with a timer once they are used.
-- Lengths come from the game (base cooldown of the spell). Members who run this addon also send,
-- out of combat, which of these spells they know and the real cooldowns learned from their own
-- casts, so talents count for them. The game can hide other players' casts in combat; then
-- nothing is guessed and the icon stays as it was.
local _,ns=...
local W=ns.Widgets
local C=W.colors
local L=ns.L
local kit=ns.UIKit

-- Per class: {spell ID, cooldown in seconds when the game gives none, specializations...}.
-- No specializations listed means every spec of the class has it.
local SPELLS={
    DEATHKNIGHT={{48707,60},{48792,120},{51052,120},{49028,120,250},{55233,90,250},{51271,60,251},{47568,120,251},{279302,90,251},{275699,45,252},{49206,180,252},{42650,90,252}},
    DEMONHUNTER={{198589,60,577},{196555,180,577},{191427,120,577},{196718,300,577,581},{370965,90,577,581},{187827,120,581},{204021,60,581}},
    DRUID={{22812,60},{108238,90},{124974,90},{77761,120},{61336,180,103,104},{194223,180,102},{102560,180,102},{106951,180,103},{102543,180,103},
        {50334,180,104},{102558,180,104},{391528,120,102,103,104,105},{102342,90,105},{740,180,105},{33891,180,105},{197721,90,105}},
    EVOKER={{363916,90},{374348,90},{374227,120},{375087,120,1467},{363534,240,1468},{370960,180,1468},{357170,60,1468},{403631,120,1473}},
    HUNTER={{186265,180},{109304,120},{264735,180},{19574,90,253},{359844,120,253},{288613,120,254},{360952,120,255}},
    MAGE={{45438,240},{414658,240},{342245,60},{55342,120},{80353,300},{365350,90,62},{190319,120,63},{12472,120,64}},
    MONK={{115203,120},{122278,120},{122783,90},{115176,300,268},{132578,120,268},{116849,120,270},{115310,180,270},{388615,180,270},
        {322118,120,270},{325197,120,270},{137639,90,269},{123904,120,269}},
    PALADIN={{642,300},{1022,300},{6940,120},{633,600},{31884,120},{498,60,65},{31821,180,65},{216331,60,65},{86659,300,66},{31850,120,66},{204018,300,66},
        {184662,90,70},{403876,90,70},{231895,120,70}},
    PRIEST={{19236,90},{10060,120},{33206,180,256},{62618,180,256},{47536,90,256},{421453,240,256},{47788,180,257},{64843,180,257},{200183,120,257},
        {47585,120,258},{15286,120,258},{228260,120,258},{391109,60,258}},
    ROGUE={{31224,120},{5277,120},{360194,120,259},{13750,180,260},{121471,90,261}},
    SHAMAN={{108271,120},{2825,300},{32182,300},{198103,300},{114050,180,262},{198067,150,262},{192249,150,262},{114051,180,263},{51533,90,263},
        {108280,180,264},{98008,180,264},{114052,180,264},{207399,300,264}},
    WARLOCK={{104773,180},{108416,60},{205180,120,265},{265187,90,266},{1122,120,267}},
    WARRIOR={{97462,180},{107574,90},{118038,120,71},{227847,90,71},{184364,120,72},{1719,90,72},{871,180,73},{12975,180,73}},
}
ns.PartyCooldownSpells=SPELLS
local byID={}
for class,list in pairs(SPELLS)do for order,s in ipairs(list)do byID[s[1]]={class=class,cd=s[2],order=order,specs=#s>2 and{select(3,unpack(s))}or nil}end end

local defaults={enabled=false,mode="list",side="RIGHT",size=26,self=true,raidGroup=true,hideReady=false,share=true,cdm=true,pos={x=-420,y=120},learned={},disabled={},custom={}}
function ns.PartyCooldownConfig()
    local store=ns.Store();store.partycds=store.partycds or{}
    local c=store.partycds
    for k,v in pairs(defaults)do if c[k]==nil then c[k]=type(v)=="table"and ns.Clone(v)or v end end
    return c
end
local members={}
ns.PartyCooldownMembers=members
-- Spells you added for a class (any spec). Lengths come from the game.
local function Register(id,class,order)
    if byID[id]then return byID[id]end
    byID[id]={class=class,cd=0,order=order,added=true};return byID[id]
end
local function LoadCustom()
    for class,ids in pairs(ns.PartyCooldownConfig().custom)do for id in pairs(ids)do Register(tonumber(id)or id,class,900+(tonumber(id)or 0)%1000)end end
end
function ns.PartyCooldownSpellInfo(id)return byID[id]end
function ns.PartyCooldownClassSpells(class)
    local out={};for _,s in ipairs(SPELLS[class]or{})do out[#out+1]=s[1]end
    local extra={};for id in pairs(ns.PartyCooldownConfig().custom[class]or{})do id=tonumber(id);if id and not byID[id]or(id and byID[id].added)then extra[#extra+1]=id end end
    table.sort(extra);for _,id in ipairs(extra)do out[#out+1]=id end
    return out
end
function ns.AddPartyCooldownSpell(class,id)
    id=tonumber(id);if not SPELLS[class]then return nil,"Choose a class"end
    if not id or id<1 or id~=math.floor(id)then return nil,"Enter a spell ID"end
    if byID[id]and not byID[id].added then return nil,"This spell is already in the list"end
    local cfg=ns.PartyCooldownConfig();cfg.custom[class]=cfg.custom[class]or{};cfg.custom[class][id]=true;cfg.disabled[id]=nil
    Register(id,class,900+id%1000);ns.DrawPartyCooldowns();return true
end
function ns.RemovePartyCooldownSpell(class,id)
    local cfg=ns.PartyCooldownConfig();local ids=cfg.custom[class];if not ids or not ids[id]then return nil,"Only added spells can be removed"end
    ids[id]=nil;if byID[id]and byID[id].added then byID[id]=nil end;ns.DrawPartyCooldowns();return true
end
-- Switched off spells are neither shown nor timed.
function ns.SetPartyCooldownTracked(id,on)ns.PartyCooldownConfig().disabled[id]=(not on)or nil;ns.DrawPartyCooldowns();return true end
function ns.PartyCooldownTracked(id)return byID[id]~=nil and not ns.PartyCooldownConfig().disabled[id]end

-- The spell applies to spec (nil: unknown spec, then only the spells of every spec count).
local function ForSpec(info,spec)
    if not info.specs then return true end
    if not spec then return false end
    for _,s in ipairs(info.specs)do if s==spec then return true end end
    return false
end
-- The spells shown for one member: exactly what they sent, otherwise their spec's list, plus
-- anything they were seen casting.
function ns.PartyCooldownList(member)
    local out,seen={},{}
    local function add(id)if not seen[id]and ns.PartyCooldownTracked(id)then seen[id]=true;out[#out+1]=id end end
    if member.known then for id in pairs(member.known)do add(id)end
    elseif member.class and SPELLS[member.class]then for _,id in ipairs(ns.PartyCooldownClassSpells(member.class))do if ForSpec(byID[id],member.spec)then add(id)end end end
    for id in pairs(member.used or{})do add(id)end
    table.sort(out,function(a,b)return byID[a].order<byID[b].order end)
    return out
end
local function BaseCooldown(id)
    local get=(C_Spell and C_Spell.GetSpellBaseCooldown)or GetSpellBaseCooldown
    if get then local ok,ms=pcall(get,id);if ok and ns.Plain(ms,"number")and ms>1500 then return ms/1000 end end
    return byID[id]and byID[id].cd or 0
end
-- Seconds: what the member sent, then what this character learned from its own casts, then the game.
function ns.PartyCooldownLength(member,id)
    local sent=member and member.cds and member.cds[id];if sent then return sent end
    if member and member.me then
        local learned=ns.PartyCooldownConfig().learned[tostring(member.spec or 0)]
        if learned and learned[id]then return learned[id]end
    end
    return BaseCooldown(id)
end
-- Seconds left on a member's cooldown, 0 when ready.
function ns.PartyCooldownLeft(member,id)
    local start=member and member.used and member.used[id];if not start then return 0 end
    return math.max(0,start+ns.PartyCooldownLength(member,id)-GetTime())
end

---------------------------------------------------------------------------
-- Who is tracked: you and party1-4, or in a raid the players of your own group.
local function Units()
    local cfg=ns.PartyCooldownConfig();local out={}
    if cfg.self then out[1]="player"end
    if IsInRaid and IsInRaid()then
        if not cfg.raidGroup or not GetRaidRosterInfo then return out end
        local me=UnitName and UnitName("player");local mine
        for i=1,40 do local name,_,group=GetRaidRosterInfo(i);if name and ns.ShortName(name)==me then mine=group end end
        for i=1,40 do local name,_,group=GetRaidRosterInfo(i)
            if name and group==mine and ns.ShortName(name)~=me then out[#out+1]="raid"..i end
        end
    elseif IsInGroup and IsInGroup()then
        for i=1,4 do if UnitExists and UnitExists("party"..i)then out[#out+1]="party"..i end end
    end
    return out
end
local function InspectSpec(unit)
    if unit=="player"then return ns.Spec()end
    if not GetInspectSpecialization then return nil end
    local ok,spec=pcall(GetInspectSpecialization,unit)
    return ok and ns.Plain(spec,"number")and spec>0 and spec or nil
end
local order={}
-- Brings the member list up to date with the group. Sent data and timers of players who stay are kept.
function ns.PartyCooldownRoster()
    local keep={};order={}
    for _,unit in ipairs(Units())do
        local name=UnitName and UnitName(unit);local class;if UnitClass then class=select(2,UnitClass(unit))end
        if ns.Plain(name,"string")and name~=""then
            name=ns.ShortName(name)or name
            local m=members[name]or{name=name,used={}};members[name]=m
            m.unit=unit;m.me=unit=="player";m.class=ns.Plain(class,"string")and class or m.class
            m.spec=(m.me and ns.Spec())or m.sentSpec or InspectSpec(unit)or m.spec
            keep[name]=true;order[#order+1]=name
        end
    end
    for name in pairs(members)do if not keep[name]then members[name]=nil end end
    return order
end
function ns.PartyCooldownOrder()return order end

-- Inspecting fills in the spec of members without the addon, one at a time and only out of combat.
local inspectTimer
local function InspectNext()
    inspectTimer=nil
    if InCombatLockdown and InCombatLockdown()then return end
    if not(NotifyInspect and CanInspect)then return end
    for _,name in ipairs(order)do local m=members[name]
        if m and not m.me and not m.spec and not m.asked then
            local ok,can=pcall(CanInspect,m.unit);if ok and can then m.asked=true;pcall(NotifyInspect,m.unit)
                if C_Timer and C_Timer.NewTimer then inspectTimer=C_Timer.NewTimer(2,InspectNext)end;return end
        end
    end
end
local function QueueInspect()if not inspectTimer and C_Timer and C_Timer.NewTimer then inspectTimer=C_Timer.NewTimer(1,InspectNext)end end

---------------------------------------------------------------------------
-- Sharing: "spec;id=seconds;id=seconds..." for the tracked spells this character knows.
local function Known(id)
    local known=C_SpellBook and(C_SpellBook.IsSpellKnownOrInSpellBook or C_SpellBook.IsSpellKnown)or IsPlayerSpell
    if not known then return false end
    local ok,v=pcall(known,id);return ok and ns.Plain(v,"boolean")and v
end
function ns.PartyCooldownPayload()
    local spec=ns.Spec();local _,class=UnitClass("player");local parts={tostring(spec or 0)}
    local me={me=true,spec=spec}
    local done={}
    local function add(id)
        if done[id]or #parts>60 then return end;done[id]=true
        parts[#parts+1]=id.."="..math.floor(ns.PartyCooldownLength(me,id)+0.5)
    end
    for _,id in ipairs(ns.PartyCooldownClassSpells(class))do if ForSpec(byID[id],spec)and Known(id)then add(id)end end
    if ns.PartyCooldownConfig().cdm then for _,id in ipairs(ns.CooldownManagerSpells())do add(id)end end
    return table.concat(parts,";")
end
-- The game's Cooldown Manager lists the important cooldowns of your current spec (its Essential
-- category). The ones of a minute or more are sent too, so the group sees what the game considers
-- major for your spec even when this addon's list does not have it.
function ns.CooldownManagerSpells()
    local out={};local v=C_CooldownViewer
    if not(v and v.GetCooldownViewerCategorySet and v.GetCooldownViewerCooldownInfo)then return out end
    local essential=Enum and Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.Essential or 0
    local ok,ids=pcall(v.GetCooldownViewerCategorySet,essential);if not ok or type(ids)~="table"then return out end
    for _,cooldownID in ipairs(ids)do
        local ok2,info=pcall(v.GetCooldownViewerCooldownInfo,cooldownID)
        local id=ok2 and type(info)=="table"and(info.overrideSpellID or info.spellID)
        if ns.Plain(id,"number")and id>0 and Known(id)and BaseCooldown(id)>=60 then out[#out+1]=id end
    end
    return out
end
local lastShare,shareTimer=-100,nil
function ns.SharePartyCooldowns(force)
    local cfg=ns.PartyCooldownConfig();if not cfg.enabled or not cfg.share then return false end
    if InCombatLockdown and InCombatLockdown()then return false end
    local wait=10-(GetTime()-lastShare)
    if not force and wait>0 then
        if not shareTimer and C_Timer and C_Timer.NewTimer then shareTimer=C_Timer.NewTimer(wait,function()shareTimer=nil;ns.SharePartyCooldowns(true)end)end
        return false
    end
    lastShare=GetTime();return ns.Send("PCD",ns.PartyCooldownPayload())
end
ns.CommHandlers.PCD=function(text,sender)
    if not sender or type(text)~="string"or #text>1000 then return end
    local fields={};for f in(text..";"):gmatch("([^;]*);")do fields[#fields+1]=f end
    local spec=tonumber(fields[1]);if not spec or #fields>80 then return end
    local m=members[sender]or{name=sender,used={}};members[sender]=m
    m.sentSpec=spec>0 and spec or nil;m.spec=m.sentSpec or m.spec;m.known={};m.cds={};m.ndp=true
    for i=2,#fields do
        local id,cd=fields[i]:match("^(%d+)=(%d+)$");id,cd=tonumber(id),tonumber(cd)
        if id and cd and cd>0 and cd<=1800 then
            if not byID[id]then Register(id,m.class,800+i)end
            m.known[id]=true;m.cds[id]=cd
        end
    end
    ns.DrawPartyCooldowns()
end

---------------------------------------------------------------------------
-- Casts. Your own exact cooldown is read right after the cast, or after combat when the game
-- hides it during combat, and remembered per spec.
local pendingLearn={}
local function Learn(id)
    if not(C_Spell and C_Spell.GetSpellCooldown)then return false end
    local ok,info=pcall(C_Spell.GetSpellCooldown,id)
    if not ok or type(info)~="table"or not ns.Plain(info.duration,"number")then return false end
    if info.duration>1.5 then
        local learned=ns.PartyCooldownConfig().learned;local key=tostring(ns.Spec()or 0)
        learned[key]=learned[key]or{};learned[key][id]=math.floor(info.duration*10+0.5)/10
    end
    return true
end
local function RedrawLater(seconds)
    if not(C_Timer and C_Timer.NewTimer)then return end
    C_Timer.NewTimer(seconds+0.1,function()ns.DrawPartyCooldowns()end)
end
-- A tracked cast by unit: starts the timer. Returns true when it counted. Every cast is counted as
-- seen or hidden (the game hid its spell), so a pull shows how much of the group was visible.
function ns.PartyCooldownCast(unit,id)
    if not ns.Plain(unit,"string")then return false end
    local m
    for _,x in pairs(members)do if x.unit==unit then m=x end end
    -- Target, focus and nameplates show the same casts of a member as their party unit.
    if not m and UnitIsUnit then for _,x in pairs(members)do
        local ok,same=pcall(UnitIsUnit,unit,x.unit);if ok and same==true then m=x end
    end end
    if not m then return false end
    if not ns.Plain(id,"number")then m.hidden=(m.hidden or 0)+1;return false end
    m.seen=(m.seen or 0)+1
    local info=byID[id]
    if not info or not ns.PartyCooldownTracked(id)or(info.class and m.class and info.class~=m.class)then return false end
    -- One cast arrives once per unit that shows it.
    if m.used[id]and GetTime()-m.used[id]<1 then return true end
    m.used[id]=GetTime()
    if m.me and not Learn(id)then pendingLearn[id]=true end
    ns.DrawPartyCooldowns();RedrawLater(ns.PartyCooldownLength(m,id))
    return true
end
function ns.PartyCooldownReset()for _,m in pairs(members)do m.used={}end;ns.DrawPartyCooldowns()end

---------------------------------------------------------------------------
-- Display: a movable list (name and icons per member), or icons beside the Blizzard or ElvUI
-- party frames. Members whose frame is not found stay in the list.
local list,rows,attached
local function Movable(frame,cfg)
    frame:SetMovable(true);frame:SetClampedToScreen(true);frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",function(self)if cfg.unlocked then self:StartMoving()end end)
    frame:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing()
        local x,y=self:GetCenter();local ux,uy=UIParent:GetCenter()
        if type(x)=="number"and type(ux)=="number"then cfg.pos={x=math.floor(x-ux+0.5),y=math.floor(y-uy+0.5)}end
    end)
end
local function List()
    if list then return list end
    local cfg=ns.PartyCooldownConfig()
    list=CreateFrame("Frame",nil,UIParent);list:SetFrameStrata("MEDIUM");list:SetSize(200,30)
    list:SetPoint("CENTER",UIParent,"CENTER",tonumber(cfg.pos.x)or-420,tonumber(cfg.pos.y)or 120)
    list.bg=list:CreateTexture(nil,"BACKGROUND");list.bg:SetAllPoints();list.bg:SetColorTexture(0,0.6,1,0.25)
    Movable(list,cfg);list:Hide()
    return list
end
local function Row(i)
    local row=rows and rows[i];if row then return row end
    rows=rows or{}
    row=CreateFrame("Frame",nil,List());row.name=row:CreateFontString(nil,"OVERLAY","GameFontNormal");row.icons={};rows[i]=row
    return row
end
local function Icon(row,i,size)
    local icon=row.icons[i]
    if not icon then
        icon=CreateFrame("Frame",nil,row);icon.tex=icon:CreateTexture(nil,"ARTWORK");icon.tex:SetAllPoints();icon.tex:SetTexCoord(0.07,0.93,0.07,0.93)
        icon.cd=CreateFrame("Cooldown",nil,icon,"CooldownFrameTemplate");icon.cd:SetAllPoints();row.icons[i]=icon
    end
    icon:SetSize(size,size);return icon
end
-- Blizzard compact party/raid frames and ElvUI party/raid frames, by the unit they show.
local FRAME_NAMES={"CompactPartyFrameMember%d","CompactRaidFrame%d","ElvUF_PartyGroup1UnitButton%d"}
local function UnitFrame(unit)
    if not UnitIsUnit then return nil end
    local function match(f)
        if type(f)~="table"or not f.IsVisible or not f:IsVisible()then return false end
        local u=f.unit or(f.GetAttribute and f:GetAttribute("unit"))
        if not ns.Plain(u,"string")then return false end
        local ok,same=pcall(UnitIsUnit,u,unit);return ok and same==true
    end
    for _,pattern in ipairs(FRAME_NAMES)do for i=1,40 do
        local f=_G[pattern:format(i)];if f==nil and i>5 then break end
        if match(f)then return f end
    end end
    for g=1,8 do for i=1,5 do
        local f=_G[("CompactRaidGroup%dMember%d"):format(g,i)];if match(f)then return f end
        f=_G[("ElvUF_RaidGroup%dUnitButton%d"):format(g,i)];if match(f)then return f end
    end end
end
ns.PartyCooldownFrame=UnitFrame
local SIDES={RIGHT={"LEFT","RIGHT",2,0,1,0},LEFT={"RIGHT","LEFT",-2,0,-1,0},TOP={"BOTTOMLEFT","TOPLEFT",0,2,1,0},BOTTOM={"TOPLEFT","BOTTOMLEFT",0,-2,1,0}}
local function FillIcons(row,m,ids,size,cfg)
    local n=0
    for _,id in ipairs(ids)do
        local left=ns.PartyCooldownLeft(m,id)
        if not(cfg.hideReady and left<=0)then
            n=n+1;local icon=Icon(row,n,size)
            icon.tex:SetTexture(W.SpellTexture(id));icon.spellID=id
            if left>0 then icon.cd:SetCooldown(m.used[id],ns.PartyCooldownLength(m,id));icon.tex:SetDesaturated(true)
            else icon.cd:Clear();icon.tex:SetDesaturated(false)end
            icon:Show()
        end
    end
    for i=n+1,#row.icons do row.icons[i]:Hide()end
    return n
end
function ns.DrawPartyCooldowns()
    local cfg=ns.PartyCooldownConfig()
    attached=attached or{}
    for _,a in pairs(attached)do a:Hide()end
    if not(cfg.enabled or cfg.unlocked)then if list then list:Hide()end;return false end
    ns.PartyCooldownRoster()
    local size=tonumber(cfg.size)or 26;local font=W.Font and W.Font(true);local y,used,widest=0,0,0
    local names=order
    if #names==0 and cfg.unlocked then
        local _,class=UnitClass("player");local me=UnitName("player")or"Player"
        members[me]=members[me]or{name=me,used={},me=true,class=class,spec=ns.Spec()};names={me}
    end
    List()
    for _,name in ipairs(names)do
        local m=members[name];local ids=ns.PartyCooldownList(m)
        local frame=cfg.mode=="frames"and m.unit and UnitFrame(m.unit)
        if frame then
            local holder=attached[name]
            if not holder then holder=CreateFrame("Frame",nil,UIParent);holder.icons={};attached[name]=holder end
            local side=SIDES[cfg.side]or SIDES.RIGHT
            local n=FillIcons(holder,m,ids,size,cfg)
            holder:ClearAllPoints();holder:SetPoint(side[1],frame,side[2],side[3],side[4]);holder:SetSize(math.max(1,n*(size+2)),size)
            for i=1,n do local icon=holder.icons[i];icon:ClearAllPoints()
                if side[5]>0 then icon:SetPoint("LEFT",holder,"LEFT",(i-1)*(size+2),0)else icon:SetPoint("RIGHT",holder,"RIGHT",-(i-1)*(size+2),0)end
            end
            holder:Show()
        else
            used=used+1;local row=Row(used)
            row:ClearAllPoints();row:SetPoint("TOPLEFT",list,"TOPLEFT",4,-y-4);row:SetSize(1,size)
            if type(font)=="string"then row.name:SetFont(font,12,"OUTLINE")end
            local c=m.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
            row.name:SetTextColor(c and c.r or 1,c and c.g or 1,c and c.b or 1);row.name:SetText(ns.DisplayName and ns.DisplayName(name)or name)
            row.name:ClearAllPoints();row.name:SetPoint("LEFT",row,"LEFT",0,0);row.name:SetWidth(90)
            local n=FillIcons(row,m,ids,size,cfg)
            for i=1,n do local icon=row.icons[i];icon:ClearAllPoints();icon:SetPoint("LEFT",row,"LEFT",94+(i-1)*(size+2),0)end
            widest=math.max(widest,94+n*(size+2));row:Show();y=y+size+4
        end
    end
    for i=used+1,#(rows or{})do rows[i]:Hide()end
    list:SetSize(math.max(160,widest+8),math.max(size+8,y+4));list:EnableMouse(cfg.unlocked==true)
    if cfg.unlocked then list.bg:Show()else list.bg:Hide()end
    if used>0 or cfg.unlocked then list:Show()else list:Hide()end
    return true
end

---------------------------------------------------------------------------
local events=CreateFrame("Frame")
local function Listen(on)
    for _,e in ipairs({"UNIT_SPELLCAST_SUCCEEDED","GROUP_ROSTER_UPDATE","PLAYER_SPECIALIZATION_CHANGED","TRAIT_CONFIG_UPDATED","INSPECT_READY",
        "READY_CHECK","PLAYER_REGEN_ENABLED","ENCOUNTER_END","CHALLENGE_MODE_START","PLAYER_ENTERING_WORLD"})do
        if on then pcall(events.RegisterEvent,events,e)elseif events.UnregisterEvent then events:UnregisterEvent(e)end
    end
end
function ns.RefreshPartyCooldowns()
    local cfg=ns.PartyCooldownConfig();LoadCustom();Listen(cfg.enabled==true)
    if cfg.enabled then ns.PartyCooldownRoster();QueueInspect();ns.SharePartyCooldowns()end
    return ns.DrawPartyCooldowns()
end
events:SetScript("OnEvent",function(_,event,a,_,c)
    if event=="UNIT_SPELLCAST_SUCCEEDED"then
        if ns.Plain(a,"string")and(a=="player"or a=="target"or a=="focus"or a:match("^party%d")or a:match("^raid%d")or a:match("^nameplate%d"))then ns.PartyCooldownCast(a,c)end
    elseif event=="PLAYER_REGEN_ENABLED"then
        for id in pairs(pendingLearn)do if Learn(id)then pendingLearn[id]=nil end end
        ns.SharePartyCooldowns();QueueInspect();ns.DrawPartyCooldowns()
    elseif event=="CHALLENGE_MODE_START"then ns.PartyCooldownReset()
    elseif event=="ENCOUNTER_END"then
        -- Raid boss cooldowns come back after each encounter.
        if IsInRaid and IsInRaid()then ns.PartyCooldownReset()end
    elseif event=="INSPECT_READY"then ns.PartyCooldownRoster();QueueInspect();ns.DrawPartyCooldowns()
    else
        if event~="READY_CHECK"then ns.PartyCooldownRoster()end
        if event=="GROUP_ROSTER_UPDATE"or event=="PLAYER_ENTERING_WORLD"then QueueInspect()end
        ns.SharePartyCooldowns();ns.DrawPartyCooldowns()
    end
end)
local login=CreateFrame("Frame");login:RegisterEvent("PLAYER_LOGIN");login:SetScript("OnEvent",function()ns.RefreshPartyCooldowns()end)

---------------------------------------------------------------------------
local CLASSES={"DEATHKNIGHT","DEMONHUNTER","DRUID","EVOKER","HUNTER","MAGE","MONK","PALADIN","PRIEST","ROGUE","SHAMAN","WARLOCK","WARRIOR"}
local CLASS_NAMES={DEATHKNIGHT="Death Knight",DEMONHUNTER="Demon Hunter",DRUID="Druid",EVOKER="Evoker",HUNTER="Hunter",MAGE="Mage",MONK="Monk",PALADIN="Paladin",PRIEST="Priest",ROGUE="Rogue",SHAMAN="Shaman",WARLOCK="Warlock",WARRIOR="Warrior"}
local function SpellName(id)
    local ok,info=pcall(C_Spell and C_Spell.GetSpellInfo or function()end,id)
    return ok and type(info)=="table"and ns.Plain(info.name,"string")and info.name or(ns.Catalog.spellNames[id]or("Spell "..id))
end
-- Abilities: every class with its spells, each switched on or off, and spells you add yourself.
local function DrawAbilities(parent,d)
    local cfg=ns.PartyCooldownConfig();LoadCustom()
    if not d.class then local _,mine=UnitClass("player");d.class=SPELLS[mine]and mine or"DEATHKNIGHT"end
    local left=W.Card(parent,0,56,200,536,L("Class"))
    for i,class in ipairs(CLASSES)do
        W.Button(left,L(CLASS_NAMES[class]),10,30+(i-1)*36,180,function()d.class=class;kit.refresh()end,d.class==class,"pcd-class:"..class,{h=32})
    end
    local right=W.Card(parent,212,56,708,536,L(CLASS_NAMES[d.class]))
    local ids=ns.PartyCooldownClassSpells(d.class)
    local list=W.Scroll(right,12,34,684,404,"pcd:spells",C.background);local y=4
    for _,id in ipairs(ids)do
        local info=byID[id]or{};local on=not cfg.disabled[id]
        local row=W.Panel(list,0,y,656,36,C.raised,C.clear,6)
        W.Icon(row,id,6,4,28)
        W.Toggle(row,SpellName(id),on,42,4,300,function(v)ns.SetPartyCooldownTracked(id,v);kit.refresh()end,"pcd-spell:"..id)
        local specs={}
        for _,sp in ipairs(info.specs or{})do specs[#specs+1]=(ns.Catalog.specs[sp]or tostring(sp)):match("^(%S+)")end
        W.Label(row,info.added and L("Added by you")or(#specs>0 and table.concat(specs,", ")or L("All specs")),350,12,180,11,C.muted):SetWordWrap(false)
        W.Label(row,math.floor(BaseCooldown(id)+0.5).." s",536,12,60,11,C.soft)
        if info.added then W.Button(row,"",620,5,26,function()kit.done(ns.RemovePartyCooldownSpell(d.class,id),nil,L("Spell removed"))end,false,"pcd-del:"..id,{h=26,kind="danger",glyph="trash",tooltip=L("Remove")})end
        y=y+40
    end;list:SetHeight(math.max(1,y))
    W.Field(right,L("ADD A SPELL BY ID"),d.newSpell or"",12,450,200,"pcd:newSpell")
    W.Button(right,L("Add"),220,466,100,function()local text=ns.UIControls["pcd:newSpell"]:GetText();local ok,err=ns.AddPartyCooldownSpell(d.class,text);if ok then d.newSpell=""else d.newSpell=text end;kit.done(ok,err,L("Spell added"))end,false,"pcd-add",{kind="primary",align="CENTER"})
    W.Button(right,L("All on"),336,466,100,function()for _,id in ipairs(ids)do cfg.disabled[id]=nil end;ns.DrawPartyCooldowns();kit.refresh()end,false,"pcd-allon",{kind="outline",align="CENTER"})
    W.Button(right,L("All off"),444,466,100,function()for _,id in ipairs(ids)do cfg.disabled[id]=true end;ns.DrawPartyCooldowns();kit.refresh()end,false,"pcd-alloff",{kind="outline",align="CENTER"})
    W.Label(right,L("Off: not shown and not timed for anyone of this class. Lengths are the game's base cooldowns."),12,506,684,11,C.muted)
end
local function DrawPage(parent)
    local cfg=ns.PartyCooldownConfig()
    local function apply()ns.RefreshPartyCooldowns();kit.refresh()end
    local d=kit.state.drafts;d.pcd=d.pcd or{view="display"}
    kit.header(parent,L("Party cooldowns"),L("Important defensive, external, raid and burst cooldowns of every specialization, for each party member."))
    W.Segmented(parent,{{value="display",label=L("Display")},{value="abilities",label=L("Abilities")}},d.pcd.view,660,0,260,function(v)d.pcd.view=v;kit.refresh()end,"pcd-view")
    if d.pcd.view=="abilities"then return DrawAbilities(parent,d.pcd)end
    local c1=W.Card(parent,0,56,298,536,L("Display"))
    W.Toggle(c1,L("Track party cooldowns"),cfg.enabled,12,34,274,function(v)cfg.enabled=v;apply()end,"pcd:enabled")
    W.Select(c1,L("SHOW"),{{value="list",label=L("As a list")},{value="frames",label=L("Beside party frames")}},cfg.mode,12,70,274,function(v)cfg.mode=v;apply()end,"pcd:mode")
    W.Select(c1,L("SIDE OF THE FRAME"),{{value="RIGHT",label=L("Right")},{value="LEFT",label=L("Left")},{value="TOP",label=L("Above")},{value="BOTTOM",label=L("Below")}},cfg.side,12,126,130,function(v)cfg.side=v;apply()end,"pcd:side")
    local sizes={};for _,s in ipairs({20,24,26,30,36})do sizes[#sizes+1]={value=s,label=s.." px"}end
    W.Select(c1,L("ICON SIZE"),sizes,tonumber(cfg.size)or 26,156,126,130,function(v)cfg.size=v;apply()end,"pcd:size")
    W.Toggle(c1,L("Include my own cooldowns"),cfg.self,12,186,274,function(v)cfg.self=v;apply()end,"pcd:self")
    W.Toggle(c1,L("In raids, track my group"),cfg.raidGroup,12,216,274,function(v)cfg.raidGroup=v;apply()end,"pcd:raid")
    W.Toggle(c1,L("Only show cooldowns in use"),cfg.hideReady,12,246,274,function(v)cfg.hideReady=v;apply()end,"pcd:hideReady")
    W.Toggle(c1,L("Share my cooldowns with the group"),cfg.share,12,276,274,function(v)cfg.share=v;if v then ns.SharePartyCooldowns(true)end;apply()end,"pcd:share")
    W.Toggle(c1,L("Also share my Cooldown Manager ones"),cfg.cdm,12,306,274,function(v)cfg.cdm=v;apply()end,"pcd:cdm")
    W.Button(c1,cfg.unlocked and L("Lock")or L("Unlock and preview"),12,346,274,function()cfg.unlocked=not cfg.unlocked;apply()end,false,"pcd-unlock",{kind="outline",align="CENTER"})
    W.Button(c1,L("Reset timers"),12,386,130,function()ns.PartyCooldownReset();kit.notify(L("All cooldowns are ready again"))end,false,"pcd-reset",{kind="outline",align="CENTER"})
    W.Button(c1,L("Send mine now"),156,386,130,function()kit.done(ns.SharePartyCooldowns(true),L("Turn tracking on, join a group and leave combat first"),L("Your cooldowns were sent to the group"))end,false,"pcd-share",{align="CENTER"})
    W.Label(c1,L("Timers start when a member casts. The game can hide other players' casts in combat; then nothing is guessed. Mythic+ keys and raid encounters start everyone ready."),12,430,274,11,C.muted)
    local c2=W.Card(parent,310,56,610,536,L("Group"))
    if cfg.enabled then ns.PartyCooldownRoster()end
    local names=order;local y=34
    if #names==0 then W.Label(c2,cfg.enabled and L("Nobody to track yet. Join a party.")or L("Turn tracking on to see your group here."),12,y,580,12,C.muted)end
    for i,name in ipairs(names)do if i<=10 then
        local m=members[name];local row=W.Panel(c2,12,y,586,40,C.raised,C.clear,6)
        W.Dot(row,8,15,kit.classColor(m.class));W.Label(row,ns.DisplayName and ns.DisplayName(name)or name,22,6,170,12,kit.classColor(m.class)):SetWordWrap(false)
        local source=m.me and L("You")or m.ndp and L("Sent by their addon")or L("Base cooldowns from the game")
        W.Label(row,(m.spec and ns.Catalog.specs[m.spec]or L("Specialization unknown")).." · "..source,22,22,170,10,C.muted):SetWordWrap(false)
        if m.seen or m.hidden then
            local t=W.Label(row,L("Casts")..": "..(m.seen or 0).." "..L("seen")..", "..(m.hidden or 0).." "..L("hidden"),436,14,144,10,(m.hidden or 0)>0 and C.warning or C.muted);t:SetJustifyH("RIGHT")
        end
        local x=196
        for _,id in ipairs(ns.PartyCooldownList(m))do if x<=400 then
            W.Icon(row,id,x,6,28);x=x+30
        end end
        y=y+44
    end end
    W.Label(c2,L("Members without this addon show the cooldowns of their specialization at the game's base length; talents that shorten them are not known. Members with the addon send exactly what they have."),12,476,586,11,C.muted)
end
ns.ExtraPages.partycds=DrawPage
