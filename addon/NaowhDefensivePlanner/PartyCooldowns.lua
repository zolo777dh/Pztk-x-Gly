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
    DEMONHUNTER={{198589,60,577},{196555,180,577},{191427,120,577},{196718,300},{370965,90},{187827,120,581},{204021,60,581}},
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

-- Talents that change a cooldown (game facts): {talent spell, add = seconds, pct = percent,
-- spec = only for that specialization}. A rank counts as many times as it is taken. Entries with
-- no talent apply to the whole spec.
local TALENT_CD={
    [49028]={{377637,add=-30}},[48707]={{205727,add=-20},{457574,add=20}},[51052]={{374383,add=-60}},
    [196718]={{389783,add=-120}},
    [194223]={{390378,add=-60},{468743,add=-60}},[102560]={{390378,add=-60},{468743,add=-60}},
    [106951]={{391174,add=-60},{391548,add=-30}},[102543]={{391174,add=-60},{391548,add=-30}},
    [22812]={{spec=104,add=-15},{203965,pct=-12}},[61336]={{203965,pct=-12}},[102342]={{382552,add=-20}},
    [363534]={{381922,add=-60}},[403631]={{412713,pct=-10}},[363916]={{412713,pct=-10}},[357170]={{376204,add=-10}},[374227]={{412713,pct=-10}},
    [19574]={{231548,add=-60}},[288613]={{260404,add=-30}},[186265]={{266921,add=-15},{1258485,add=-30}},
    [190319]={{1254194,add=-60}},[45438]={{382424,add=-30},{1265517,add=-30},{1244110,add=-30}},[414658]={{382424,add=-30},{1265517,add=-30},{1244110,add=-30}},
    [342245]={{342249,add=-5},{1255166,add=-10}},[55342]={{1244025,add=-30}},
    [132578]={{450989,add=-25}},[123904]={{392986,add=-30}},[115203]={{spec=269,add=-240},{spec=270,add=-240},{388813,add=-30}},[116849]={{202424,add=-45}},
    [31884]={{spec=70,add=-60},{1241511,add=-15},{204074,pct=-50}},[231895]={{1241511,add=-15}},[216331]={{1241511,add=-15}},
    [642]={{114154,pct=-30},{378425,pct=-15}},[498]={{spec=70,add=30},{114154,pct=-30}},[31850]={{114154,pct=-30}},
    [6940]={{384820,add=-60},{384820,spec=65,add=45}},[1022]={{384909,add=-60},{378425,pct=-15}},[31821]={{392911,add=-30}},
    [19236]={{238100,add=-20}},[47585]={{288733,add=-30}},
    [114050]={{462440,add=-60}},[114051]={{384444,add=-60}},[108271]={{381647,add=-30}},
    [1122]={{1280483,add=-30}},[104773]={{386659,add=-45}},[108416]={{386686,add=-15}},
    [118038]={{391271,pct=-10}},[184364]={{391271,pct=-10}},
}
-- Cooldowns cut while the fight goes on, by the resource a member spends (read from their power
-- bar): `sec` seconds per `per` spent, on these spells per spec. Warrior Anger Management (rage),
-- Blood Red Thirst (runic power on Vampiric Blood), Guardian Ursoc's Guidance (rage on Incarnation).
local SPEND={WARRIOR={talent=152278,power=1,sec=1,per={[71]=20,[72]=20,[73]=10},
        spells={[71]={107574,227847},[72]={1719,107574,227847},[73]={107574,871}}},
    DEATHKNIGHT={talent=205723,power=6,sec=2,per={[250]=10},spells={[250]={55233}}},
    DRUID={talent=393414,power=1,sec=1,per={[104]=25},spells={[104]={102558}}}}
-- Talents read from trees: those that change a cooldown and those that cut one by spending.
local WANTED={}
for _,mods in pairs(TALENT_CD)do for _,x in ipairs(mods)do if x[1]then WANTED[x[1]]=true end end end
for _,sp in pairs(SPEND)do WANTED[sp.talent]=true end
-- Other spell IDs the game uses for a tracked spell (a talent or hero version of it).
local ALIAS={[446035]=227847,[401150]=107574}
ns.PartyCooldownTalentMods=TALENT_CD
local defaults={enabled=false,mode="frames",side="RIGHT",size=26,self=true,raidGroup=true,hideReady=false,names=false,sensors=true,share=true,cdm=true,detect=true,pos={x=-420,y=120},learned={},disabled={},specOff={},custom={},talentSpells={}}
function ns.PartyCooldownConfig()
    local store=ns.Store();store.partycds=store.partycds or{}
    local c=store.partycds
    for k,v in pairs(defaults)do if c[k]==nil then c[k]=type(v)=="table"and ns.Clone(v)or v end end
    -- 0.10.2: icons beside the party frames, every cooldown of the spec shown, no names.
    if(c.layout or 0)<2 then c.layout=2;c.mode="frames";c.hideReady=false;c.names=false end
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
    for id,info in pairs(byID)do if info.detected and info.class==class then extra[#extra+1]=id end end
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
-- Switched off spells are neither shown nor timed: for one spec, or with no spec for the whole class.
function ns.SetPartyCooldownTracked(id,on,spec)
    local cfg=ns.PartyCooldownConfig()
    if spec then
        -- Switched off for the whole class before: keep it off for the class's other specs.
        if on and cfg.disabled[id]then
            cfg.disabled[id]=nil;local info=byID[id]
            for _,other in ipairs(info and ns.ClassSpecs and ns.ClassSpecs[info.class]or{})do if other~=spec then cfg.specOff[other]=cfg.specOff[other]or{};cfg.specOff[other][id]=true end end
        end
        cfg.specOff[spec]=cfg.specOff[spec]or{};cfg.specOff[spec][id]=(not on)or nil
    else cfg.disabled[id]=(not on)or nil end
    ns.DrawPartyCooldowns();return true
end
function ns.PartyCooldownTracked(id,spec)
    local cfg=ns.PartyCooldownConfig()
    if byID[id]==nil or cfg.disabled[id]then return false end
    return not(spec and cfg.specOff[spec]and cfg.specOff[spec][id])
end

-- The spell applies to spec. With the spec unknown, the specs the member's role allows count
-- (a tank or healer of most classes is one spec); with no role either, the class-wide spells.
local function ForSpec(info,spec,candidates)
    if not info.specs then return true end
    for _,s in ipairs(info.specs)do
        if s==spec then return true end
        if not spec and candidates then for _,c in ipairs(candidates)do if c==s then return true end end end
    end
    return false
end
local function Known(id)
    local known=C_SpellBook and(C_SpellBook.IsSpellKnownOrInSpellBook or C_SpellBook.IsSpellKnown)or IsPlayerSpell
    if not known then return false end
    local ok,v=pcall(known,id);return ok and ns.Plain(v,"boolean")and v
end
local FACTION={[2825]="Horde",[32182]="Alliance"}
local TANKS={[66]=1,[73]=1,[104]=1,[250]=1,[268]=1,[581]=1}
local HEALERS={[65]=1,[105]=1,[256]=1,[257]=1,[264]=1,[270]=1,[1468]=1}
function ns.RoleSpecs(class,role)
    local out={}
    for _,spec in ipairs(ns.ClassSpecs and ns.ClassSpecs[class]or{})do
        local r=TANKS[spec]and"TANK"or HEALERS[spec]and"HEALER"or"DAMAGER"
        if r==role then out[#out+1]=spec end
    end
    return #out>0 and out or nil
end
-- The spells of one spec of a class, in list order: its own, the class-wide ones and added ones.
function ns.PartyCooldownSpecSpells(class,spec)
    local out={}
    for _,id in ipairs(ns.PartyCooldownClassSpells(class))do if ForSpec(byID[id],spec)then out[#out+1]=id end end
    return out
end
-- The spells shown for one member: exactly what they sent, otherwise their spec's list, plus
-- anything they were seen casting.
function ns.PartyCooldownList(member)
    local out,seen={},{}
    local function add(id)if not seen[id]and ns.PartyCooldownTracked(id,member.spec)and not(member.talented and member.talented[id]==false)then seen[id]=true;out[#out+1]=id end end
    if member.known then for id in pairs(member.known)do add(id)end
    elseif member.class and SPELLS[member.class]then
        -- Strictly the member's spec: your own list is what your spellbook knows right now; for
        -- others the spec's list (nothing spec-only until the spec is known), minus talents they
        -- did not take and the other faction's Bloodlust/Heroism.
        local faction=member.faction
        for _,id in ipairs(ns.PartyCooldownClassSpells(member.class))do
            local info=byID[id]
            local unread=not member.me and not member.talented and ns.PartyCooldownConfig().talentSpells[id]
            if ForSpec(info,member.spec)and not unread and not(FACTION[id]and faction and FACTION[id]~=faction)and(not member.me or info.added or info.detected or Known(id))then add(id)end
        end
    end
    for id in pairs(member.used or{})do add(id)end
    table.sort(out,function(a,b)return byID[a].order<byID[b].order end)
    return out
end
local function BaseCooldown(id)
    local get=(C_Spell and C_Spell.GetSpellBaseCooldown)or GetSpellBaseCooldown
    if get then local ok,ms=pcall(get,id);if ok and ns.Plain(ms,"number")and ms>1500 then return ms/1000 end end
    return byID[id]and byID[id].cd or 0
end
-- The game's base cooldown changed by the member's talents. Talents not read yet: only the
-- spec's own changes count.
local function WithTalents(m,id,base)
    local mods=TALENT_CD[id];if not mods then return base end
    local ranks=m and m.ranks
    local cd,mul=base,1
    for _,x in ipairs(mods)do
        local rank=0
        if x[1]then rank=ranks and ranks[x[1]]or 0 else rank=1 end
        if x.spec and x.spec~=(m and m.spec)then rank=0 end
        if rank>0 then cd=cd+(x.add or 0)*rank;mul=mul*(1+(x.pct or 0)*rank/100)end
    end
    return math.max(5,math.floor(cd*mul+0.5))
end
ns.PartyCooldownWithTalents=WithTalents
-- Seconds: what the member sent, then what this character learned from its own casts, then the
-- game's base changed by their talents.
function ns.PartyCooldownLength(member,id)
    local sent=member and member.cds and member.cds[id];if sent then return sent end
    if member and member.me then
        local learned=ns.PartyCooldownConfig().learned[tostring(member.spec or 0)]
        if learned and learned[id]then return learned[id]end
    end
    return WithTalents(member,id,BaseCooldown(id))
end
-- Your own cooldown straight from the game, so every reduction counts: start and length.
local function OwnCooldown(id)
    local get=C_Spell and C_Spell.GetSpellCooldown;if not get then return nil end
    local ok,info=pcall(get,id);if not ok or type(info)~="table"then return nil end
    local start,dur=info.startTime,info.duration
    if ns.Plain(start,"number")and ns.Plain(dur,"number")and dur>1.5 and start>0 then return start,dur end
    return nil
end
ns.PartyCooldownOwn=OwnCooldown
-- Seconds left on a member's cooldown, 0 when ready.
function ns.PartyCooldownLeft(member,id)
    if member and member.me then local start,dur=OwnCooldown(id);if start then return math.max(0,start+dur-GetTime())end end
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
            if UnitFactionGroup then local ok,f=pcall(UnitFactionGroup,unit);if ok and ns.Plain(f,"string")then m.faction=f end end
            local role=UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
            m.roleSpecs=m.class and ns.Plain(role,"string")and ns.RoleSpecs(m.class,role)or nil
            if not m.spec and m.roleSpecs and #m.roleSpecs==1 then m.spec=m.roleSpecs[1]end
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
        -- No answer (out of range...): asked again after 15 s, up to 6 times.
        if m and not m.me and not m.ndp and(not m.spec or not m.talented)and(m.tries or 0)<6 and(not m.asked or GetTime()-m.asked>15)then
            local ok,can=pcall(CanInspect,m.unit);if ok and can then m.asked=GetTime();m.tries=(m.tries or 0)+1;pcall(NotifyInspect,m.unit)
                if C_Timer and C_Timer.NewTimer then inspectTimer=C_Timer.NewTimer(2,InspectNext)end;return end
        end
    end
end
-- Talents of an inspected member: every talent spell of their trees, true when taken. Spells of
-- the list that are talents they did not take are then left out.
-- Every spell of the list seen in any talent tree is remembered as a talent, so members whose
-- talents are not read yet do not show talents they may not have.
local function ReadTalents(m,config)
    local T=C_Traits;if not(T and T.GetConfigInfo and T.GetTreeNodes and T.GetNodeInfo and T.GetEntryInfo and T.GetDefinitionInfo)then return false end
    config=config or(Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID or-1)
    local marks=ns.PartyCooldownConfig().talentSpells
    local ok,info=pcall(T.GetConfigInfo,config);if not ok or type(info)~="table"or type(info.treeIDs)~="table"then return false end
    local talented={};local any=false;local ranks={};local read=false
    for _,tree in ipairs(info.treeIDs)do
        local ok2,nodes=pcall(T.GetTreeNodes,tree)
        for _,node in ipairs(ok2 and type(nodes)=="table"and nodes or{})do
            local ok3,n=pcall(T.GetNodeInfo,config,node)
            if ok3 and type(n)=="table"and type(n.entryIDs)=="table"then
                local active=type(n.activeEntry)=="table"and n.activeEntry.entryID
                local rank=ns.Plain(n.currentRank,"number")and n.currentRank or 0
                for _,entry in ipairs(n.entryIDs)do
                    local ok4,e=pcall(T.GetEntryInfo,config,entry);local def=ok4 and type(e)=="table"and e.definitionID
                    local ok5,d=pcall(T.GetDefinitionInfo,def or 0);local id=ok5 and type(d)=="table"and d.spellID
                    if ns.Plain(id,"number")and WANTED[id]then ranks[id]=math.max(ranks[id]or 0,(active==entry or #n.entryIDs==1)and rank or 0);read=true end
                    if ns.Plain(id,"number")and byID[id]then
                        marks[id]=true
                        talented[id]=talented[id]or(rank>0 and(active==entry or #n.entryIDs==1));any=true
                    end
                end
            end
        end
    end
    if any and m then m.talented=talented end
    if(any or read)and m then m.ranks=ranks end
    return any
end
-- Your own talent tree, read when the addon loads and whenever your spec or talents change.
local function ReadOwnTalents()
    local get=C_ClassTalents and C_ClassTalents.GetActiveConfigID
    local ok,config=pcall(get or function()end)
    local me;for _,m in pairs(members)do if m.me then me=m end end
    if ok and ns.Plain(config,"number")then return ReadTalents(me,config)end
    return false
end
ns.PartyCooldownReadOwnTalents=ReadOwnTalents
ns.PartyCooldownReadTalents=ReadTalents
local function QueueInspect()if not inspectTimer and C_Timer and C_Timer.NewTimer then inspectTimer=C_Timer.NewTimer(1,InspectNext)end end

---------------------------------------------------------------------------
-- Sharing: "spec;id=seconds;id=seconds..." for the tracked spells this character knows.
function ns.PartyCooldownPayload()
    local spec=ns.Spec();local _,class=UnitClass("player");local parts={tostring(spec or 0)}
    local me={me=true,spec=spec}
    local done={}
    local function add(id)
        if done[id]or #parts>60 then return end;done[id]=true
        parts[#parts+1]=id.."="..math.floor(ns.PartyCooldownLength(me,id)+0.5)
    end
    for _,id in ipairs(ns.PartyCooldownClassSpells(class))do if ForSpec(byID[id],spec)and Known(id)and not(FACTION[id]and UnitFactionGroup and FACTION[id]~=UnitFactionGroup("player"))then add(id)end end
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
    id=ALIAS[id]or id
    m.seen=(m.seen or 0)+1
    local info=byID[id]
    -- Not in the list (a follower's spell, a new talent...): any spell the game gives a cooldown of
    -- a minute or more is tracked from now on for that class.
    if not info and ns.PartyCooldownConfig().detect and BaseCooldown(id)>=60 then info=Register(id,m.class,700+id%100);info.detected=true end
    if not info or not ns.PartyCooldownTracked(id,m.spec)or(info.class and m.class and info.class~=m.class)then return false end
    -- One cast arrives once per unit that shows it.
    if m.used[id]and GetTime()-m.used[id]<1 then return true end
    m.used[id]=GetTime()
    if m.me and not Learn(id)then pendingLearn[id]=true end
    ns.DrawPartyCooldowns();RedrawLater(ns.PartyCooldownLength(m,id))
    return true
end
function ns.PartyCooldownReset()for _,m in pairs(members)do m.used={};m.hiddenCd=nil end;ns.DrawPartyCooldowns()end

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
local frameCache={}
function ns.PartyCooldownForgetFrames()frameCache={}end
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
    -- Any other unit frame addon (EllesmereUI, Cell, Grid2...): a shown frame whose unit is exactly
    -- this one. Looked up out of combat and remembered for the group.
    local cached=frameCache[unit];if cached==false then return nil end;if cached and cached:IsVisible()then return cached end
    if InCombatLockdown and InCombatLockdown()or not EnumerateFrames then return nil end
    local best
    local f=EnumerateFrames()
    while f do
        local ok,hit=pcall(function()
            if f.IsForbidden and f:IsForbidden()or not f:IsVisible()then return false end
            local u=rawget(f,"unit")or(f.GetAttribute and f:GetAttribute("unit"))
            return u==unit and(f:GetHeight()or 0)>=16
        end)
        if ok and hit and f~=TargetFrame and f~=FocusFrame then
            -- Party frames before the player frame for yourself.
            if not best or(best==PlayerFrame and f~=PlayerFrame)then best=f end
        end
        f=EnumerateFrames(f)
    end
    -- Not found is remembered too, until the group changes, so the scan runs once.
    frameCache[unit]=best or false;return best
end
ns.PartyCooldownFrame=UnitFrame
local ShowHidden -- hidden timers on icons, defined with the buff sensors
local SIDES={RIGHT={"LEFT","RIGHT",2,0,1,0},LEFT={"RIGHT","LEFT",-2,0,-1,0},TOP={"BOTTOMLEFT","TOPLEFT",0,2,1,0},BOTTOM={"TOPLEFT","BOTTOMLEFT",0,-2,1,0}}
local function FillIcons(row,m,ids,size,cfg)
    local n=0
    for _,id in ipairs(ids)do
        local left=ns.PartyCooldownLeft(m,id)
        local hidden=m.hiddenCd and m.hiddenCd[id]
        if not(cfg.hideReady and left<=0 and not hidden)then
            n=n+1;local icon=Icon(row,n,size)
            icon.tex:SetTexture(W.SpellTexture(id));icon.spellID=id
            local start,dur;if m.me then start,dur=OwnCooldown(id)end
            if not start and m.used[id]then start,dur=m.used[id],ns.PartyCooldownLength(m,id)end
            if left>0 and start then icon.cd:SetCooldown(start,dur);icon.tex:SetDesaturated(true)
            else icon.cd:Clear();icon.tex:SetDesaturated(false)end
            icon:Show();ShowHidden(icon,hidden)
        end
    end
    for i=n+1,#row.icons do row.icons[i]:Hide();ShowHidden(row.icons[i],nil)end
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
            row.name:SetTextColor(c and c.r or 1,c and c.g or 1,c and c.b or 1)
            -- Without names a thin bar in the class colour starts each row.
            local start=cfg.names and 94 or 6
            if not row.bar then row.bar=row:CreateTexture(nil,"ARTWORK")end
            row.bar:SetColorTexture(c and c.r or 1,c and c.g or 1,c and c.b or 1,1);row.bar:ClearAllPoints();row.bar:SetPoint("LEFT",row,"LEFT",0,0);row.bar:SetSize(3,size)
            if cfg.names then row.name:SetText(ns.DisplayName and ns.DisplayName(name)or name);row.name:Show();row.bar:Hide()else row.name:SetText("");row.name:Hide();row.bar:Show()end
            row.name:ClearAllPoints();row.name:SetPoint("LEFT",row,"LEFT",0,0);row.name:SetWidth(90)
            local n=FillIcons(row,m,ids,size,cfg)
            for i=1,n do local icon=row.icons[i];icon:ClearAllPoints();icon:SetPoint("LEFT",row,"LEFT",start+(i-1)*(size+2),0)end
            widest=math.max(widest,start+n*(size+2));row:Show();y=y+size+4
        end
    end
    for i=used+1,#(rows or{})do rows[i]:Hide()end
    list:SetSize(math.max(60,widest+8),math.max(size+8,y+4));list:EnableMouse(cfg.unlocked==true)
    if cfg.unlocked then list.bg:Show()else list.bg:Hide()end
    if used>0 or cfg.unlocked then list:Show()else list:Hide()end
    return true
end

---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Buff sensors, for casts the game hides in combat. The game's own aura container widget is
-- given one buff and a unit; it only grows when that buff is on the unit. Its size answers a plain
-- mouse-over test (the hit area is stretched so the answer does not depend on where the cursor
-- is), so the moment a cooldown's buff appears its timer starts. Externals (Pain Suppression,
-- Ironbark...) appear on the target and are credited to the group member who can cast them.
-- Switch: "Buff sensors" on the page. The game may change this widget; then it simply stays off.
local SELF,EXTERNAL=1,2
-- Spells whose buff is not the spell itself, or that buff more than the caster. Every other
-- tracked spell is sensed by its own ID on the caster. {kind, buff IDs...}
local BUFFS={
    [49028]={SELF,81256},[48707]={SELF,48707,444741},[51052]={EXTERNAL,51052,145629},
    [198589]={SELF,212800},[191427]={SELF,162264},[196718]={EXTERNAL,209426},
    [194223]={SELF,194223,102560,390414},[102560]={SELF,102560,390414},[106951]={SELF,106951,102543},[102543]={SELF,102543},
    [740]={EXTERNAL,740,157982,1264623},[33891]={SELF,117679,33891},[102342]={EXTERNAL,102342},[77761]={EXTERNAL,77764,106898},
    [357170]={EXTERNAL,357170},[374227]={EXTERNAL,374227},
    [19574]={SELF,19574,186254,1235388,1285912},[365350]={SELF,365350,365362},[45438]={SELF,45438,414658},[414658]={SELF,414658,45438},
    [342245]={SELF,342246},[80353]={EXTERNAL,80353},
    [123904]={SELF,123904,1248992},[115203]={SELF,115203,120954},[116849]={EXTERNAL,116849},
    [31884]={SELF,31884,231895,454351,216331,389539},[231895]={SELF,231895,31884},[216331]={SELF,216331,31884},
    [498]={SELF,498,403876},[403876]={SELF,403876,498},[31821]={EXTERNAL,31821},
    [1022]={EXTERNAL,1022},[6940]={EXTERNAL,6940},[204018]={EXTERNAL,204018},
    [62618]={EXTERNAL,81782},[228260]={SELF,194249},[10060]={EXTERNAL,10060},[33206]={EXTERNAL,33206},[47788]={EXTERNAL,47788},
    [64843]={EXTERNAL,64843,64844},[360194]={SELF,1249810,360194},
    [114050]={SELF,114050,1219480},[98008]={EXTERNAL,325174},[198103]={SELF,198103,381755},[2825]={EXTERNAL,2825},[32182]={EXTERNAL,32182},
    [265187]={SELF,1276767,265187},[1122]={SELF,1122,111685,266087,417282},
    [97462]={EXTERNAL,97463},[227847]={SELF,227847,446035},[107574]={SELF,107574,401150},
}
ns.PartyCooldownBuffs=BUFFS
local function BuffsOf(id)
    local b=BUFFS[id];if not b then return SELF,{[id]=true}end
    local set={};for i=2,#b do set[b[i]]=true end
    return b[1],set
end
local sensorHost,sensorTicker
local sensors={}
local sensorState={available=nil,reason=nil}
local spendState={plain=0,hidden=0}
function ns.PartyCooldownSensors()return sensors,sensorState end
-- The container's answer. In combat the game hands it out as a hidden yes/no that no addon can
-- read or compare; it can only be passed on to the game's own helpers and widgets.
-- Hidden answers are never compared, not even with nil. Returns false when there is no answer.
local function Plain(v)return ns.Plain(v,"boolean")end
local function SensorRead(c)
    local ok,v=pcall(c.IsMouseOver,c,1e5,-1e5,0,0)
    if not ok then return false end
    if ns.Plain(v)then return v==true end
    return v
end

-- Hidden timers. A buff that appears in combat gives only a hidden yes, so the start time of its
-- cooldown cannot be known. It is still kept, as a hidden number: the game's curve helper
-- (C_CurveUtil.EvaluateColorValueFromBoolean) picks between two numbers by a hidden yes/no and
-- returns the pick, hidden too. Each tick: "if the buff is up now and was not up before, the
-- start is now, else keep the old start". Nothing about the start is ever read back: it goes
-- into status bars (bars take hidden values), and things anchored to the end of a bar's fill
-- move with it. The bars' range and position follow the plain clock, so on the icon:
--  * a dark fill shrinks as the cooldown runs out;
--  * a grey copy of the icon shows while the cooldown runs;
--  * the seconds left: a column "1, 2, 3 ... cd" seen through a one-line window over the icon,
--    pushed up by one line per second left.
--
-- The helper returns colour values, 0 to 1, so a start is coded in steps of 1/255 inside a
-- window that begins at the slot's epoch: one step is `unit` whole seconds, and
-- seconds left = epoch + window * code - now. A code of 0 is a cooldown that ended before the
-- epoch. The window is about 2.5 cooldowns and a slot takes new starts only during its first
-- (window - cd) seconds; then the other slot opens. A cooldown started in a slot ends before that
-- slot is opened again, so two slots per spell are enough. Epochs and the clock used for drawing
-- are whole seconds, so the seconds shown are whole too.
local EVAL=function()return C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean end
-- Each slot keeps the start twice: `code` as finely as the curve helper carries numbers (checked
-- once, see Fine), for the dark fill and the grey cover, which so end on the exact moment; and
-- `whole`, in whole steps from a whole-second epoch, for the seconds column.
local fine
local function Fine()
    if fine~=nil then return fine end
    local eval=EVAL();if not eval then return false end
    local ok,a=pcall(eval,true,0.123456789,0);local ok2,b=pcall(eval,false,0,0.987654321)
    fine=ok and ok2 and a==0.123456789 and b==0.987654321 or false
    return fine
end
ns.PartyCooldownFine=function()fine=nil;return Fine()end
local function NewSlot(now)return{epoch=Fine()and now or math.floor(now),code=0,wepoch=math.floor(now),whole=0}end
local function MoveSlot(sl,sec)sl.epoch=sl.epoch+sec;sl.wepoch=sl.wepoch+sec end
ns.PartyCooldownMoveSlot=MoveSlot
local HiddenTrack
function HiddenTrack(m,id,now)
    m.hiddenCd=m.hiddenCd or{}
    local t=m.hiddenCd[id]
    if not t then
        local cd=math.floor(ns.PartyCooldownLength(m,id)+0.5);if cd<=0 then return nil end
        local unit=math.max(1,math.ceil(cd/100));local window=255*unit
        t={cd=cd,unit=unit,window=window,open=window-cd,cur=1,slot={NewSlot(now),NewSlot(now)}}
        m.hiddenCd[id]=t;t.created=true
    end
    -- The length changed (talents read, a sent cooldown): a running timer keeps its start.
    local cd=math.floor(ns.PartyCooldownLength(m,id)+0.5)
    if cd~=t.cd and cd>0 then
        if cd*2<=t.window then for k=1,2 do MoveSlot(t.slot[k],cd-t.cd)end;t.cd=cd;t.open=t.window-cd
        else m.hiddenCd[id]=nil;return HiddenTrack(m,id,now)end
    end
    local sl=t.slot[t.cur]
    if now-sl.wepoch>t.open then t.cur=3-t.cur;t.slot[t.cur]=NewSlot(now);t.moved=true end
    return t
end
ns.PartyCooldownHiddenTrack=function(m,id)return m.hiddenCd and m.hiddenCd[id]end
-- A rising edge between two answers, plain or hidden, written into the open slot.
-- `at` is when the buff appeared (the game's aura event), `now` the time of this read.
local function HiddenEdge(m,id,cur,prev,now,at)
    local eval=EVAL();if not eval then return false end
    local t=HiddenTrack(m,id,now);if not t then return false end
    local sl=t.slot[t.cur];at=at or now
    local whole=math.min(255,math.floor((at-sl.wepoch+t.cd)/t.unit+0.5))/255
    local code=Fine()and math.min(1,(at-sl.epoch+t.cd)/t.window)or whole
    local ok,v,w=pcall(function()return eval(cur,eval(prev,sl.code,code),sl.code),eval(cur,eval(prev,sl.whole,whole),sl.whole)end)
    if not ok then sensorState.refused=(sensorState.refused or 0)+1;return false end
    sl.code,sl.whole=v,w;sensorState.hiddenEdges=(sensorState.hiddenEdges or 0)+1
    local created=t.created;t.created=nil
    return true,created
end
ns.PartyCooldownHiddenEdge=HiddenEdge
-- Seconds still to run, for slots whose code is plain (tests and the report).
function ns.PartyCooldownHiddenLeft(t,now)
    local best=0
    for k=1,2 do local sl=t.slot[k]
        if ns.Plain(sl.code,"number")then best=math.max(best,sl.epoch+t.window*sl.code-now)end
    end
    return math.max(0,best)
end
-- The seconds column for a cooldown: "1" on top, the cooldown at the bottom.
local columns={}
local function Column(cd)
    if columns[cd]then return columns[cd]end
    local out={}
    for r=1,cd do out[r]=r>=60 and string.format("%d:%02d",math.floor(r/60),r%60)or tostring(r)end
    columns[cd]=table.concat(out,"\n");return columns[cd]
end
-- Height of one line of the column, measured on the font itself.
local lineSteps={}
local function LineStep(font,size)
    local key=tostring(font)..size
    if lineSteps[key]then return lineSteps[key]end
    local probe=sensorHost or UIParent
    local fs=probe:CreateFontString(nil,"OVERLAY");pcall(fs.SetFont,fs,font,size,"OUTLINE");pcall(fs.SetSpacing,fs,0)
    fs:SetText("0");local one=fs.GetStringHeight and fs:GetStringHeight()
    fs:SetText("0\n0");local two=fs.GetStringHeight and fs:GetStringHeight();fs:Hide()
    local step=ns.Plain(one,"number")and ns.Plain(two,"number")and two-one or 0
    if step<=0 then step=size*1.15 end
    lineSteps[key]=step;return step
end
local function Bar(parent,r,g,b,a)
    local bar=CreateFrame("StatusBar",nil,parent)
    pcall(bar.SetStatusBarTexture,bar,"Interface\\Buttons\\WHITE8X8");pcall(bar.SetStatusBarColor,bar,r,g,b,a)
    pcall(bar.SetOrientation,bar,"VERTICAL");pcall(bar.SetMinMaxValues,bar,0,1);pcall(bar.SetValue,bar,0)
    return bar
end
local hiddenLayer
local function HiddenParts(icon)
    if icon.hidden then return icon.hidden end
    if not hiddenLayer then
        hiddenLayer=CreateFrame("Frame",nil,UIParent);hiddenLayer:SetFrameStrata("MEDIUM");hiddenLayer:SetSize(1,1);hiddenLayer:SetPoint("CENTER",UIParent,"CENTER",0,0)
    end
    local parts={win=CreateFrame("Frame",nil,icon)}
    pcall(parts.win.SetClipsChildren,parts.win,true)
    for k=1,2 do
        local p={}
        -- Dark fill over the icon.
        p.fill=Bar(icon,0,0,0,0.55);p.fill:SetAllPoints(icon)
        -- Grey copy of the icon, seen through a clip that covers the icon while time is left.
        p.gate=Bar(hiddenLayer,0,0,0,0)
        p.veil=CreateFrame("Frame",nil,icon);pcall(p.veil.SetClipsChildren,p.veil,true)
        p.grey=p.veil:CreateTexture(nil,"ARTWORK");p.grey:SetAllPoints(icon);p.grey:SetTexCoord(0.07,0.93,0.07,0.93)
        pcall(p.grey.SetDesaturated,p.grey,true);p.grey:SetVertexColor(0.55,0.55,0.55)
        -- Seconds column, pushed up through the window.
        p.pos=Bar(hiddenLayer,0,0,0,0)
        p.text=CreateFrame("Frame",nil,parts.win);p.text:SetAllPoints(parts.win)
        p.column=p.text:CreateFontString(nil,"OVERLAY");p.column:SetJustifyH("CENTER")
        parts[k]=p
    end
    icon.hidden=parts;return parts
end
-- Lays the parts out for this icon size and cooldown; once per change.
local function DressHidden(icon,t)
    local parts=HiddenParts(icon)
    local size=icon:GetWidth();if not ns.Plain(size,"number")or size<=0 then size=26 end
    local font=(W.Font and W.Font(true))or"Fonts\\FRIZQT__.TTF";local ts=math.max(9,math.floor(size*0.42))
    local sig=t.cd.."|"..size.."|"..ts
    if parts.sig==sig then return parts end
    local step=LineStep(font,ts);local jump=size+4
    parts.step,parts.jump,parts.sig=step,jump,sig
    parts.win:ClearAllPoints();parts.win:SetPoint("CENTER",icon,"CENTER",0,0);parts.win:SetSize(size+6,step)
    pcall(parts.win.SetFrameLevel,parts.win,(icon:GetFrameLevel()or 0)+6)
    for k=1,2 do local p=parts[k]
        p.fill:SetFrameLevel((icon:GetFrameLevel()or 0)+3);p.veil:SetFrameLevel((icon:GetFrameLevel()or 0)+2)
        p.pos:SetSize(1,t.window*step);pcall(p.pos.SetMinMaxValues,p.pos,0,1)
        p.gate:SetSize(1,t.window*jump);pcall(p.gate.SetMinMaxValues,p.gate,0,1)
        local edge=p.gate.GetStatusBarTexture and p.gate:GetStatusBarTexture()or p.gate
        p.veil:ClearAllPoints();p.veil:SetPoint("TOP",edge,"TOP",0,0);p.veil:SetPoint("BOTTOM",edge,"TOP",0,-(t.cd+1)*jump);p.veil:SetWidth(size)
        local top=p.pos.GetStatusBarTexture and p.pos:GetStatusBarTexture()or p.pos
        pcall(p.column.SetFont,p.column,font,ts,"OUTLINE");pcall(p.column.SetSpacing,p.column,0);p.column:SetTextColor(1,1,1)
        p.column:SetText(Column(t.cd));p.column:ClearAllPoints();p.column:SetPoint("TOP",top,"TOP",0,0)
        p.second=nil
    end
    return parts
end
local shownHidden={}
-- Moves every shown hidden timer to the current time.
local function SlideHidden()
    local now=GetTime();local second=math.floor(now)
    for icon,t in pairs(shownHidden)do
        if icon.track~=t or not icon:IsShown()then shownHidden[icon]=nil
        else
            local parts=icon.hidden
            for k=1,2 do local sl,p=t.slot[k],parts[k]
                local low=(now-sl.epoch)/t.window
                pcall(p.fill.SetMinMaxValues,p.fill,low,low+t.cd/t.window);pcall(p.fill.SetValue,p.fill,sl.code)
                pcall(p.pos.SetValue,p.pos,sl.whole);pcall(p.gate.SetValue,p.gate,sl.code)
                -- The grey cover follows the clock every frame, so it leaves the icon on time.
                p.gate:ClearAllPoints();p.gate:SetPoint("BOTTOM",icon,"BOTTOM",0,-(now-sl.epoch)*parts.jump)
                -- Whole seconds: the column moves once per second.
                if p.second~=second or p.epoch~=sl.wepoch then
                    p.second,p.epoch=second,sl.wepoch
                    p.pos:ClearAllPoints();p.pos:SetPoint("BOTTOM",parts.win,"BOTTOM",0,-(second-sl.wepoch)*parts.step)
                end
            end
        end
    end
end
ns.PartyCooldownSlideHidden=SlideHidden
function ShowHidden(icon,t)
    icon.track=t
    local parts=icon.hidden
    if not t then
        if parts then parts.win:Hide();for k=1,2 do parts[k].fill:Hide();parts[k].veil:Hide();parts[k].pos:Hide();parts[k].gate:Hide()end end
        shownHidden[icon]=nil;return
    end
    parts=DressHidden(icon,t)
    local tex=icon.spellID and W.SpellTexture(icon.spellID)
    parts.win:Show();for k=1,2 do parts[k].grey:SetTexture(tex);parts[k].fill:Show();parts[k].veil:Show();parts[k].pos:Show();parts[k].gate:Show();parts[k].second=nil end
    shownHidden[icon]=t
end
ns.PartyCooldownShowHidden=ShowHidden
-- /ndp pcd: what the sensors and the cast tracking see, printed to chat.
function ns.PartyCooldownReport()
    local lines={}
    lines[#lines+1]="NDP "..tostring(ns.version)..", in combat: "..tostring(InCombatLockdown and InCombatLockdown()or false)..". Buff sensors: "..(sensorState.available==false and("not available ("..tostring(sensorState.reason)..")")or(#sensors.." watching"))
        ..", lit now "..(function()local n=0;for _,s in ipairs(sensors)do if s.lit then n=n+1 end end;return n end)()
        ..", hidden answers kept "..(sensorState.hiddenEdges or 0)..", power bars read "..spendState.plain.." hidden "..spendState.hidden..", exact times "..tostring(ns.PartyCooldownFine and ns.PartyCooldownFine()or false)..", refused "..(sensorState.refused or 0)..(EVAL()and""or", no curve helper")
    for _,name in ipairs(order)do local m=members[name]
        local sens=0;for _,s in ipairs(sensors)do if s.member==name then sens=sens+1 end end
        lines[#lines+1]=name..": "..tostring(m.class).." "..tostring(m.spec and ns.Catalog.specs[m.spec]or"spec unknown")..(m.talented and", talents read"or", talents not read")
            ..", icons "..#ns.PartyCooldownList(m)..", sensors "..sens..", casts seen "..(m.seen or 0).." hidden "..(m.hidden or 0).." by buff "..(m.sensed or 0)
            ..", hidden timers "..(function()local n=0;for _ in pairs(m.hiddenCd or{})do n=n+1 end;return n end)()
            ..(m.ranks and", cooldown talents read"or"")
    end
    return lines
end
local function NewSensor(unit,buffs)
    if not sensorHost then sensorHost=CreateFrame("Frame",nil,UIParent);sensorHost:SetSize(1,1);sensorHost:SetPoint("TOPLEFT",UIParent,"TOPLEFT",-20,0)end
    local ok,c=pcall(CreateFrame,"AuraContainer",nil,sensorHost,"CustomAuraContainerTemplate")
    if not ok or not c or not c.AddAuraGroup then sensorState.available=false;sensorState.reason="the game has no aura container widget";return nil end
    c:SetSize(1,1);c:ClearAllPoints();c:SetPoint("TOPLEFT",UIParent,"TOPLEFT",-11,0);pcall(c.EnableMouse,c,false)
    local added=pcall(c.AddAuraGroup,c,"ndp","HELPFUL",{maxFrameCount=1,candidateFilters={includeSpellIDs=buffs},
        initializeFrame=function(b)pcall(b.SetSize,b,1,1);pcall(b.SetMouseClickEnabled,b,false);pcall(b.SetMouseMotionEnabled,b,false)end,
        layout={elementWidth=50000,elementHeight=1,elementSpacing=0,lineSpacing=0}})
    if not added then sensorState.available=false;sensorState.reason="the aura container refused a buff group";return nil end
    sensorState.available=true
    return c
end
-- The member who cast an external: the one whose list has the spell and whose cooldown is ready.
local function ExternalOwner(id)
    local best
    for _,m in pairs(members)do
        local info=byID[id]
        if info and m.class==info.class and ns.PartyCooldownLeft(m,id)<=0 then
            for _,x in ipairs(ns.PartyCooldownList(m))do if x==id then best=best or m end end
        end
    end
    return best
end
local function Sensed(m,id,at)
    if not m or not ns.PartyCooldownTracked(id,m.spec)then return end
    local last=m.used[id]
    -- The cast itself was seen, or the cooldown is still running: nothing new.
    if last and GetTime()-last<ns.PartyCooldownLength(m,id)-1 then return end
    m.used[id]=at or GetTime();m.sensed=(m.sensed or 0)+1
    ns.DrawPartyCooldowns();RedrawLater(ns.PartyCooldownLength(m,id))
end
-- When each unit's auras last changed: the moment a buff appeared, read a frame later.
local auraAt={}
local function PollSensors()
    local now,redraw=GetTime(),false
    for _,s in ipairs(sensors)do
        local v=SensorRead(s.frame)
        local at=auraAt[s.unit];if not at or now-at>0.5 or at>now then at=now end
        -- A container just pointed at its unit shows the old answer for a moment: no edges then.
        if s.hold and now<s.hold then s.prev=v;s.lit=Plain(v)and v
        else
            local m=s.kind==EXTERNAL and s.owner or members[s.member]
            -- A spell whose timer still runs cannot have been cast again.
            local running=m and ns.PartyCooldownLeft(m,s.spell)>0
            if running then
            elseif Plain(v)and Plain(s.prev)then
                -- Out of combat the answer is plain: an ordinary timer, with seconds and a swipe.
                if v and not s.prev then
                    if s.kind==EXTERNAL then Sensed(ExternalOwner(s.spell),s.spell,at)else Sensed(m,s.spell,at)end
                end
            elseif m and ns.PartyCooldownTracked(s.spell,m.spec)then
                local _,created=HiddenEdge(m,s.spell,v,s.prev,now,at);if created then redraw=true end
            end
            s.prev=v;s.lit=Plain(v)and v
        end
    end
    -- A new hidden timer needs its bars on the icon.
    if redraw then ns.DrawPartyCooldowns()end
end
ns.PartyCooldownPollSensors=function()PollSensors();SlideHidden()end
-- Reads: a few frames right after a unit's auras change (the container updates on the same event),
-- and every 0.25 s otherwise. Hidden timers are moved every frame.
local driver=CreateFrame("Frame");local quick,lastRead=0,0
driver:SetScript("OnUpdate",function()
    local now=GetTime()
    if #sensors>0 and(quick>0 or now-lastRead>=0.25)then quick=math.max(0,quick-1);lastRead=now;PollSensors()end
    if next(shownHidden)then SlideHidden()end
end)
function ns.PartyCooldownAura(unit)
    if not ns.Plain(unit,"string")then return end
    for _,s in ipairs(sensors)do if s.unit==unit then auraAt[unit]=GetTime();quick=3;return end end
end
-- Builds the sensors for the group: each member's own buffs on them, and every external of the
-- group on everyone. Out of combat only; containers are reused.
local pool={}
function ns.RebuildPartyCooldownSensors()
    for _,s in ipairs(sensors)do pcall(s.frame.SetEnabled,s.frame,false);s.frame:Hide();pool[#pool+1]=s.frame end
    sensors={}
    local cfg=ns.PartyCooldownConfig()
    if sensorTicker then sensorTicker:Cancel();sensorTicker=nil end
    if not(cfg.enabled and cfg.sensors)or sensorState.available==false then return 0 end
    if InCombatLockdown and InCombatLockdown()then return 0 end
    local externals,externalOwners={},{}
    for _,name in ipairs(order)do local m=members[name]
        for _,id in ipairs(ns.PartyCooldownList(m))do local kind,buffs=BuffsOf(id)
            if kind==EXTERNAL then externals[id]=buffs;externalOwners[id]=externalOwners[id]or m
            elseif not m.me then sensors[#sensors+1]={unit=m.unit,member=name,spell=id,buff=buffs,kind=SELF}end
        end
    end
    for _,name in ipairs(order)do local m=members[name]
        for id,buff in pairs(externals)do sensors[#sensors+1]={unit=m.unit,member=name,spell=id,buff=buff,kind=EXTERNAL,owner=externalOwners[id]}end
    end
    local made={}
    for _,s in ipairs(sensors)do
        local c=table.remove(pool)
        if c then pcall(c.SetAuraGroupCandidateFilters,c,"ndp",{includeSpellIDs=s.buff});c:Show()
        else c=NewSensor(s.unit,s.buff)end
        if not c then break end
        -- A container only follows its unit's auras while enabled; a full update reads what is up now.
        pcall(c.SetUnit,c,s.unit);pcall(c.SetEnabled,c,true);pcall(c.UpdateAllAuras,c)
        s.frame=c;s.prev=SensorRead(c);s.lit=Plain(s.prev)and s.prev;s.hold=GetTime()+0.6;made[#made+1]=s
    end
    sensors=made

    return #sensors
end

-- Spending cuts cooldowns (warrior Anger Management): each fall of the member's power bar in
-- combat is spent resource. A running timer is shortened; a hidden one by moving its epoch, which
-- moves its start without reading it. Power bars the game hides cannot be counted.
local function Shorten(m,id,sec)
    local start=m.used[id]
    if start and GetTime()<start+ns.PartyCooldownLength(m,id)then m.used[id]=start-sec;m.shortened=true end
    local t=m.hiddenCd and m.hiddenCd[id]
    if t then for k=1,2 do MoveSlot(t.slot[k],-sec)end end
end
ns.PartyCooldownShorten=Shorten
local lastSpendDraw=0
function ns.PartyCooldownPower(unit)
    for _,m in pairs(members)do
        local sp=m.class and SPEND[m.class]
        if sp and m.unit==unit and not m.me and(not m.ranks or(m.ranks[sp.talent]or 0)>0)and sp.per[m.spec or 0]then
            local ok,power=pcall(UnitPower,unit,sp.power)
            if ok and ns.Plain(power,"number")then
                spendState.plain=spendState.plain+1
                local fighting=UnitAffectingCombat and UnitAffectingCombat(unit)
                if m.power and power<m.power and ns.Plain(fighting,"boolean")and fighting then
                    m.spent=(m.spent or 0)+m.power-power
                    local per=sp.per[m.spec]
                    while m.spent>=per do
                        m.spent=m.spent-per
                        for _,id in ipairs(sp.spells[m.spec]or{})do Shorten(m,id,sp.sec or 1)end
                    end
                end
                m.power=power
            else spendState.hidden=spendState.hidden+1;m.power=nil end
            if m.shortened and GetTime()-lastSpendDraw>1 then m.shortened=nil;lastSpendDraw=GetTime();ns.DrawPartyCooldowns()end
        end
    end
end
local ownDraw
local events=CreateFrame("Frame")
local function Listen(on)
    for _,e in ipairs({"UNIT_SPELLCAST_SUCCEEDED","GROUP_ROSTER_UPDATE","PLAYER_SPECIALIZATION_CHANGED","TRAIT_CONFIG_UPDATED","INSPECT_READY",
        "READY_CHECK","PLAYER_REGEN_ENABLED","ENCOUNTER_END","CHALLENGE_MODE_START","PLAYER_ENTERING_WORLD","UNIT_POWER_UPDATE","SPELL_UPDATE_COOLDOWN","UNIT_AURA"})do
        if on then pcall(events.RegisterEvent,events,e)elseif events.UnregisterEvent then events:UnregisterEvent(e)end
    end
end
function ns.RefreshPartyCooldowns()
    local cfg=ns.PartyCooldownConfig();LoadCustom();Listen(cfg.enabled==true)
    if cfg.enabled then ReadOwnTalents()end
    if cfg.enabled then ns.PartyCooldownRoster();QueueInspect();ns.SharePartyCooldowns()end
    ns.RebuildPartyCooldownSensors()
    return ns.DrawPartyCooldowns()
end
events:SetScript("OnEvent",function(_,event,a,_,c)
    if event=="UNIT_SPELLCAST_SUCCEEDED"then
        if ns.Plain(a,"string")and(a=="player"or a=="target"or a=="focus"or a:match("^party%d")or a:match("^raid%d")or a:match("^nameplate%d"))then ns.PartyCooldownCast(a,c)end
    elseif event=="UNIT_AURA"then ns.PartyCooldownAura(a)
    elseif event=="UNIT_POWER_UPDATE"then
        if ns.Plain(a,"string")and a~="player"then ns.PartyCooldownPower(a)end
    elseif event=="SPELL_UPDATE_COOLDOWN"then
        -- Your own icons follow the game's cooldowns; one redraw for a burst of updates.
        if not ownDraw and C_Timer and C_Timer.NewTimer then ownDraw=C_Timer.NewTimer(0.2,function()ownDraw=nil;ns.DrawPartyCooldowns()end)end
    elseif event=="PLAYER_REGEN_ENABLED"then
        for id in pairs(pendingLearn)do if Learn(id)then pendingLearn[id]=nil end end
        ns.SharePartyCooldowns();QueueInspect();ns.RebuildPartyCooldownSensors();ns.DrawPartyCooldowns()
    elseif event=="CHALLENGE_MODE_START"then ns.PartyCooldownReset()
    elseif event=="ENCOUNTER_END"then
        -- Raid boss cooldowns come back after each encounter.
        if IsInRaid and IsInRaid()then ns.PartyCooldownReset()end
    elseif event=="INSPECT_READY"then
        ns.PartyCooldownRoster()
        for _,m in pairs(members)do
            if not m.me and UnitGUID and ns.Plain(a,"string")then local ok,guid=pcall(UnitGUID,m.unit);if ok and guid==a then ReadTalents(m)end end
        end
        QueueInspect();ns.RebuildPartyCooldownSensors();ns.DrawPartyCooldowns()
    else
        if event~="READY_CHECK"then ns.PartyCooldownRoster()end
        if event=="GROUP_ROSTER_UPDATE"or event=="PLAYER_ENTERING_WORLD"then QueueInspect();frameCache={}end
        if event=="PLAYER_SPECIALIZATION_CHANGED"and ns.Plain(a,"string")then for _,m in pairs(members)do if m.unit==a and not m.me then m.asked=nil;m.tries=nil;m.talented=nil;m.spec=nil;m.sentSpec=nil end end;QueueInspect()end
        if event=="TRAIT_CONFIG_UPDATED"or event=="PLAYER_SPECIALIZATION_CHANGED"and a=="player"then ReadOwnTalents()end
        if event~="READY_CHECK"then ns.RebuildPartyCooldownSensors()end
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
    local specs=ns.ClassSpecs[d.class]or{}
    d.specs=d.specs or{};local spec=d.specs[d.class]or specs[1];d.specs[d.class]=spec
    local tabs={};for _,sp in ipairs(specs)do tabs[#tabs+1]={value=sp,label=(ns.Catalog.specs[sp]or tostring(sp)):gsub(" "..CLASS_NAMES[d.class].."$","")}end
    W.Segmented(right,tabs,spec,12,30,684,function(v)d.specs[d.class]=v;kit.refresh()end,"pcd-spec")
    local ids=ns.PartyCooldownSpecSpells(d.class,spec)
    local list=W.Scroll(right,12,70,684,368,"pcd:spells",C.background);local y=4
    for _,id in ipairs(ids)do
        local info=byID[id]or{};local on=ns.PartyCooldownTracked(id,spec)
        local row=W.Panel(list,0,y,656,36,C.raised,C.clear,6)
        W.Icon(row,id,6,4,28)
        W.Toggle(row,SpellName(id),on,42,4,300,function(v)ns.SetPartyCooldownTracked(id,v,spec);kit.refresh()end,"pcd-spell:"..id)
        W.Label(row,info.added and L("Added by you")or info.detected and L("Seen in game")or(info.specs and L("This spec")or L("Every spec of the class")),350,12,180,11,C.muted):SetWordWrap(false)
        W.Label(row,math.floor(BaseCooldown(id)+0.5).." s",536,12,60,11,C.soft)
        if info.added then W.Button(row,"",620,5,26,function()kit.done(ns.RemovePartyCooldownSpell(d.class,id),nil,L("Spell removed"))end,false,"pcd-del:"..id,{h=26,kind="danger",glyph="trash",tooltip=L("Remove")})end
        y=y+40
    end;list:SetHeight(math.max(1,y))
    W.Field(right,L("ADD A SPELL BY ID"),d.newSpell or"",12,450,200,"pcd:newSpell")
    W.Button(right,L("Add"),220,466,100,function()local text=ns.UIControls["pcd:newSpell"]:GetText();local ok,err=ns.AddPartyCooldownSpell(d.class,text);if ok then d.newSpell=""else d.newSpell=text end;kit.done(ok,err,L("Spell added"))end,false,"pcd-add",{kind="primary",align="CENTER"})
    W.Button(right,L("All on"),336,466,100,function()for _,id in ipairs(ids)do ns.SetPartyCooldownTracked(id,true,spec)end;kit.refresh()end,false,"pcd-allon",{kind="outline",align="CENTER"})
    W.Button(right,L("All off"),444,466,100,function()for _,id in ipairs(ids)do ns.SetPartyCooldownTracked(id,false,spec)end;kit.refresh()end,false,"pcd-alloff",{kind="outline",align="CENTER"})
    W.Label(right,L("The cooldowns tracked for this spec. Off: not shown and not timed for players of this spec. Lengths are the game's base cooldowns."),12,506,684,11,C.muted)
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
    W.Toggle(c1,L("Only in use"),cfg.hideReady,12,246,130,function(v)cfg.hideReady=v;apply()end,"pcd:hideReady")
    W.Toggle(c1,L("Names"),cfg.names,156,246,130,function(v)cfg.names=v;apply()end,"pcd:names")
    W.Toggle(c1,L("Share my cooldowns with the group"),cfg.share,12,276,274,function(v)cfg.share=v;if v then ns.SharePartyCooldowns(true)end;apply()end,"pcd:share")
    W.Toggle(c1,L("Also share my Cooldown Manager ones"),cfg.cdm,12,306,274,function(v)cfg.cdm=v;apply()end,"pcd:cdm")
    W.Toggle(c1,L("Auto 1 min+"),cfg.detect,12,336,130,function(v)cfg.detect=v;apply()end,"pcd:detect")
    W.Toggle(c1,L("Buff sensors"),cfg.sensors,156,336,130,function(v)cfg.sensors=v;apply()end,"pcd:sensors")
    W.Button(c1,cfg.unlocked and L("Lock")or L("Unlock and preview"),12,372,274,function()cfg.unlocked=not cfg.unlocked;apply()end,false,"pcd-unlock",{kind="outline",align="CENTER"})
    W.Button(c1,L("Reset timers"),12,410,130,function()ns.PartyCooldownReset();kit.notify(L("All cooldowns are ready again"))end,false,"pcd-reset",{kind="outline",align="CENTER"})
    W.Button(c1,L("Send mine now"),156,410,130,function()kit.done(ns.SharePartyCooldowns(true),L("Turn tracking on, join a group and leave combat first"),L("Your cooldowns were sent to the group"))end,false,"pcd-share",{align="CENTER"})
    W.Label(c1,L("Timers start when a member casts. The game can hide other players' casts in combat; then nothing is guessed. Mythic+ keys and raid encounters start everyone ready."),12,452,274,11,C.muted)
    local c2=W.Card(parent,310,56,610,536,L("Group"))
    if cfg.enabled then ns.PartyCooldownRoster()end
    local names=order;local y=34
    if #names==0 then W.Label(c2,cfg.enabled and L("Nobody to track yet. Join a party.")or L("Turn tracking on to see your group here."),12,y,580,12,C.muted)end
    for i,name in ipairs(names)do if i<=10 then
        local m=members[name];local row=W.Panel(c2,12,y,586,40,C.raised,C.clear,6)
        W.Dot(row,8,15,kit.classColor(m.class));W.Label(row,ns.DisplayName and ns.DisplayName(name)or name,22,6,170,12,kit.classColor(m.class)):SetWordWrap(false)
        local source=m.me and L("You")or m.ndp and L("Sent by their addon")or m.talented and L("Talents from inspect")or L("Base cooldowns from the game")
        W.Label(row,(m.spec and ns.Catalog.specs[m.spec]or L("Specialization unknown")).." · "..source,22,22,170,10,C.muted):SetWordWrap(false)
        if m.seen or m.hidden or m.sensed then
            local t=W.Label(row,L("Casts")..": "..(m.seen or 0).." "..L("seen")..", "..(m.hidden or 0).." "..L("hidden")..", "..(m.sensed or 0).." "..L("by buff"),396,14,184,10,(m.hidden or 0)>0 and C.warning or C.muted);t:SetJustifyH("RIGHT")
        end
        local x=196
        for _,id in ipairs(ns.PartyCooldownList(m))do if x<=360 then
            W.Icon(row,id,x,6,28);x=x+30
        end end
        y=y+44
    end end
    local _,st=ns.PartyCooldownSensors()
    W.Label(c2,L("Buff sensors")..": "..(not cfg.sensors and L("off")or st.available==false and(L("not available")..", "..L(st.reason or""))or st.available and(#sensors..L(" watching"))or L("waiting for a group")),12,452,586,11,st.available==false and C.warning or C.soft)
    W.Label(c2,L("Members without this addon show the cooldowns of their specialization at the game's base length; talents that shorten them are not known. Members with the addon send exactly what they have."),12,476,586,11,C.muted)
end
ns.ExtraPages.partycds=DrawPage
