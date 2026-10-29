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
    DEATHKNIGHT={{48707,60},{48792,120},{51052,240},{49028,120,250},{55233,90,250},{51271,45,251},{42650,90,252}},
    DEMONHUNTER={{198589,60,577,1480},{191427,120,577},{196718,300}},
    DRUID={{22812,60},{106898,120},{61336,180,103,104},{194223,180,102},{106951,180,103},{102558,180,104},{22842,36,104},{204066,60,104},
        {102342,90,105},{740,180,105}},
    EVOKER={{363916,90},{374227,120},{374968,120},{375087,120,1467},{363534,240,1468},{357170,60,1468},{403631,120,1473}},
    HUNTER={{186265,180},{264735,90},{19574,90,253},{288613,120,254},{1250646,90,255}},
    MAGE={{45438,240},{342245,60},{66,300},{365350,90,62},{55342,120,62},{235450,30,62},{190319,120,63},{235313,30,63},{11426,30,64}},
    MONK={{116841,30},{115203,360,269,270},{132578,120,268},{123904,120,269},{122470,90,269},{116849,120,270}},
    PALADIN={{1022,300},{6940,120},{31884,120},{1044,25},{642,300,65,70},{498,60,65,70},{31821,180,65},{31850,90,66}},
    PRIEST={{19236,90},{10060,120},{33206,180,256},{62618,180,256},{47788,180,257},{200183,120,257},{228260,120,258},{47585,120,258},{15286,120,258}},
    ROGUE={{31224,120},{5277,120},{1966,15},{185311,30},{1856,120},{360194,120,259},{121471,90,261}},
    SHAMAN={{108271,120},{198103,180},{192077,120},{114050,180,262},{191634,60,262},{114051,180,263},{98008,180,264}},
    WARLOCK={{104773,180},{108416,60},{205180,120,265},{265187,60,266},{1122,120,267}},
    WARRIOR={{97462,180},{23920,25},{118038,120,71},{1719,90,72},{184364,120,72}},
}
-- Interrupts and crowd control (stuns, fears, knock-ups, grips...), same format. They follow the
-- defensives on the icons and are switched off as groups on the Display page.
local KICKS={
    DEATHKNIGHT={{47528,15}},DEMONHUNTER={{183752,15}},DRUID={{106839,15,103,104},{78675,60,102}},EVOKER={{351338,20,1467,1473}},
    HUNTER={{147362,24,253,254},{187707,15,255}},MAGE={{2139,25}},MONK={{116705,15,268,269}},PALADIN={{96231,15,66,70}},PRIEST={{15487,30,258}},
    ROGUE={{1766,15}},SHAMAN={{57994,12}},WARLOCK={{19647,24,265,267},{89766,30,266}},WARRIOR={{6552,15},{386071,90,73}},
}
local STOPS={
    DEATHKNIGHT={{207167,60},{108199,90,250}},DEMONHUNTER={{179057,45},{207684,120},{202138,60,581}},
    DRUID={{99,30},{102793,60},{132469,30}},HUNTER={{109248,45},{19577,60}},MONK={{119381,60}},PALADIN={{853,45},{115750,90}},
    PRIEST={{8122,40}},ROGUE={{2094,120}},SHAMAN={{192058,60}},WARLOCK={{30283,60}},WARRIOR={{46968,40},{5246,90}},
}
local KIND={}
for kind,lists in pairs({kick=KICKS,cc=STOPS})do
    for class,list in pairs(lists)do for _,s in ipairs(list)do table.insert(SPELLS[class],s);KIND[s[1]]=kind end end
end
ns.PartyCooldownKind=function(id)return KIND[id]end
ns.PartyCooldownSpells=SPELLS
local byID={}
for class,list in pairs(SPELLS)do for order,s in ipairs(list)do byID[s[1]]={class=class,cd=s[2],order=order,specs=#s>2 and{select(3,unpack(s))}or nil}end end
-- Racial cooldowns, by the race the game names (any class): {spell ID, cooldown}.
local RACIAL={NightElf={{58984,120}},Dwarf={{20594,120}}}
for race,list in pairs(RACIAL)do for i,s in ipairs(list)do byID[s[1]]={race=race,cd=s[2],order=900+i}end end

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
    [118038]={{391271,pct=-10}},[184364]={{391271,pct=-10}},[23920]={{spec=73,add=-5},{391271,pct=-10}},
    [191634]={{468571,add=-15},{454026,add=-15}},[106898]={{288826,add=-60}},[192077]={{462791,add=-30}},
    [66]={{110959,add=-180},{210476,add=-60}},
    -- Interrupts: only interrupts that land are seen, so cuts on a landed interrupt count.
    [47528]={{378848,add=-3}},[78675]={{202918,add=-15}},[351338]={{412713,pct=-10}},[2139]={{382297,add=-5}},[57994]={{spec=264,add=18}},
    [6552]={{391271,pct=-10}},
    [119381]={{344359,add=-5}},[30283]={{1270255,add=-15}},[192058]={{381867,add=-5},{265046,add=-10},{445027,add=-5}},
    [46968]={{275339,add=-15},{440992,add=-5}},[19577]={{459507,add=-20}},[115750]={{469325,add=-15}},
    [8122]={{196704,add=-10}},[5246]={{424742,add=-15}},[207684]={{320418,add=-30},{389718,pct=-15}},[202138]={{389718,pct=-15}},
    [132469]={{400140,add=-5}},[2094]={{200733,pct=-50},{256165,pct=-25},{441415,pct=-10}},[374968]={{412713,pct=-10}},[204066]={{429539,add=-20}},[1250646]={{1251790,add=-15}},
}
-- Usual lengths per spec for members whose talents are not read yet (the common build).
local LIKELY={
    [250]={[49028]=90,[48707]=40,[47528]=12},[251]={[48707]=40,[47528]=12},[252]={[48707]=40,[47528]=12},
    [577]={[198589]=60,[196718]=180},[581]={[196718]=180},[1480]={[198589]=60,[196718]=180},
    [102]={[194223]=120,[78675]=45},[103]={[106951]=90},[104]={[22812]=34,[22842]=20,[204066]=40,[61336]=137,[106898]=60},[105]={[102342]=70},
    [253]={[19574]=30,[186265]=120},[254]={[186265]=120},[255]={[186265]=120},
    [62]={[45438]=150,[342245]=55,[66]=60,[55342]=60,[2139]=20},[63]={[190319]=60,[45438]=150,[342245]=50,[66]=60,[2139]=20},[64]={[45438]=120,[342245]=50,[66]=60,[2139]=20},
    [269]={[115203]=90},[270]={[116849]=75,[115203]=90},
    [65]={[1022]=240,[31884]=90,[642]=210,[498]=42,[31821]=150},[66]={[31884]=60,[31850]=63,[6940]=60},[70]={[31884]=60,[642]=210,[498]=63,[6940]=60},
    [257]={[19236]=70},[258]={[19236]=70},
    [262]={[114050]=120,[108271]=90},[263]={[114051]=120,[108271]=90},[264]={[108271]=90},
    [265]={[108416]=45},[266]={[108416]=45},[267]={[108416]=45},
    [71]={[118038]=108,[23920]=23,[46968]=25},[72]={[184364]=108,[23920]=23,[46968]=25},[73]={[23920]=23,[46968]=25},
}
-- Cooldowns cut while the fight goes on, by the resource a member spends (read from their power
-- bar): `sec` seconds per `per` spent, on these spells per spec. Warrior Anger Management (rage),
-- Blood Red Thirst (runic power on Vampiric Blood), Guardian Ursoc's Guidance (rage on Incarnation).
local SPEND={WARRIOR={talent=152278,power=1,sec=1,per={[72]=20},spells={[72]={1719}}},
    DEATHKNIGHT={talent=205723,power=6,sec=2,per={[250]=10},spells={[250]={55233}}},
    DRUID={talent=393414,power=1,sec=1,per={[104]=25},spells={[104]={102558}}}}
-- Talents read from trees: those that change a cooldown and those that cut one by spending.
local WANTED={}
for _,mods in pairs(TALENT_CD)do for _,x in ipairs(mods)do if x[1]then WANTED[x[1]]=true end end end
for _,sp in pairs(SPEND)do WANTED[sp.talent]=true end
-- Other spell IDs the game uses for a tracked spell (a talent or hero version of it).
local ALIAS={[77761]=106898,[77764]=106898,[110959]=66,[204018]=1022,[231895]=31884,[216331]=31884,[389539]=31884,[442204]=403631,
    [102560]=194223,[102543]=106951,[414658]=45438,
    [389813]=207684,[389807]=202138,[474421]=19577,[119910]=19647,[132409]=19647,[1276467]=19647,[119914]=89766}
-- Cooldowns cut by what a member does (resource spent, Bone Shield charges, crits, finishers,
-- Barbed Shot...). The game hides all of that for others in combat, so their timers could not be
-- exact: these are shown only for yourself, whose cooldowns the game gives. true = every spec.
local DYNAMIC={
    [49028]=true,[55233]=true,[51271]=true,[42650]=true,   -- DRW (Bone Shield), VB (Red Thirst), PoF (Icecap), Army (Death Coil)
    [106951]=true,[102558]=true,[19574]=true,[288613]=true, -- Feral Berserk (combo points), Guardian Incarnation (rage), Bestial Wrath (Barbed Shot), Trueshot (focus)
    [190319]=true,[123904]=true,[1719]=true,                -- Combustion (crits), Xuen (Combo Strikes), Recklessness (Anger Management)
    [31884]={66},                                           -- Protection Righteous Protector (Holy Power)
    [853]=true,                                             -- Hammer of Justice (Fist of Justice, Holy Power)
}
local function Dynamic(id,spec)
    local d=DYNAMIC[id];if d==true then return true end
    if d then for _,s in ipairs(d)do if s==spec then return true end end end
    return false
end
ns.PartyCooldownDynamic=Dynamic
ns.PartyCooldownTalentMods=TALENT_CD
local defaults={enabled=false,mode="frames",side="RIGHT",size=26,self=true,raidGroup=true,hideReady=false,names=false,sensors=true,kicks=true,cc=true,share=true,cdm=true,detect=true,loadWorld=true,loadSolo=true,pos={x=-420,y=120},
    anchors={kick={x=-420,y=-60,style="bars",size=22,width=200,dir="RIGHT",grow="DOWN",perRow=1,rows=5,names=true,hideReady=false,texture=""},
        cc={x=-420,y=-220,style="icons",size=30,width=180,dir="RIGHT",grow="DOWN",perRow=8,rows=2,names=false,hideReady=false,texture=""}},learned={},disabled={},specOff={},custom={},talentSpells={}}
function ns.PartyCooldownConfig()
    local store=ns.Store()
    -- Settings of the former Puzatik Party Defensives addon move over once, while it is still loaded.
    if store.partycds==nil and type(PuzatikPartyDefensivesDB)=="table"and type(PuzatikPartyDefensivesDB.partycds)=="table"then store.partycds=ns.Clone(PuzatikPartyDefensivesDB.partycds)end
    store.partycds=store.partycds or{}
    local c=store.partycds
    for k,v in pairs(defaults)do if c[k]==nil then c[k]=type(v)=="table"and ns.Clone(v)or v end end
    for key,a in pairs(defaults.anchors)do
        c.anchors[key]=type(c.anchors[key])=="table"and c.anchors[key]or{}
        -- 0.10.22: each list has its own "your own cooldowns" switch; it starts as the main one was.
        if c.anchors[key].self==nil then c.anchors[key].self=c.self~=false end
        for k,v in pairs(a)do if c.anchors[key][k]==nil then c.anchors[key][k]=v end end
    end
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
    local extra={};for id in pairs(ns.PartyCooldownConfig().custom[class]or{})do id=tonumber(id);if id and not byID[id]then Register(id,class,900+id%1000)end;if id and byID[id].added and byID[id].class==class then extra[#extra+1]=id end end
    for id,info in pairs(byID)do if info.detected and info.class==class then extra[#extra+1]=id end end
    table.sort(extra);for _,id in ipairs(extra)do out[#out+1]=id end
    return out
end
function ns.AddPartyCooldownSpell(class,id)
    id=tonumber(id);if not SPELLS[class]then return nil,"Choose a class"end
    if not id or id<1 or id~=math.floor(id)then return nil,"Enter a spell ID"end
    if byID[id]and not byID[id].added then return nil,"This spell is already in the list"end
    -- One added spell belongs to one class.
    if byID[id]and byID[id].class~=class then return nil,"This spell is already added for another class"end
    local cfg=ns.PartyCooldownConfig();cfg.custom[class]=cfg.custom[class]or{};cfg.custom[class][id]=true;cfg.disabled[id]=nil
    Register(id,class,900+id%1000);ns.RebuildPartyCooldownSensors();ns.DrawPartyCooldowns();return true
end
function ns.RemovePartyCooldownSpell(class,id)
    local cfg=ns.PartyCooldownConfig();local ids=cfg.custom[class];if not ids or not ids[id]then return nil,"Only added spells can be removed"end
    ids[id]=nil
    local used=false;for _,other in pairs(cfg.custom)do if other[id]then used=true end end
    if byID[id]and byID[id].added and not used then byID[id]=nil end
    ns.RebuildPartyCooldownSensors();ns.DrawPartyCooldowns();return true
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
    ns.RebuildPartyCooldownSensors();ns.DrawPartyCooldowns();return true
end
function ns.PartyCooldownTracked(id,spec)
    local cfg=ns.PartyCooldownConfig()
    if byID[id]==nil or cfg.disabled[id]then return false end
    return not(spec and cfg.specOff[spec]and cfg.specOff[spec][id])
end

-- The spell applies to spec. With the spec unknown, the specs the member's role allows count
-- (a tank or healer of most classes is one spec); with no role either, the class-wide spells.
local function ForSpec(info,spec,candidates)
    if not info then return false end
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
-- anything they were seen casting. `kind`: only "kick", only "cc", or "defensive" for the rest.
function ns.PartyCooldownList(member,kind)
    local out,seen={},{}
    local cfg=ns.PartyCooldownConfig()
    local function add(id)if not seen[id]and(not kind or(KIND[id]or"defensive")==kind)and(KIND[id]~="kick"or cfg.kicks~=false)and(KIND[id]~="cc"or cfg.cc~=false)and ns.PartyCooldownTracked(id,member.spec)and(member.me or not Dynamic(id,member.spec))and not(member.talented and member.talented[id]==false)then seen[id]=true;out[#out+1]=id end end
    if member.known then for id in pairs(member.known)do add(id)end
    elseif member.class and SPELLS[member.class]then
        -- Strictly the member's spec: your own list is what your spellbook knows right now; for
        -- others the spec's list (nothing spec-only until the spec is known), minus talents they
        -- did not take and the other faction's Bloodlust/Heroism.
        local faction=member.faction
        for _,id in ipairs(ns.PartyCooldownClassSpells(member.class))do
            local info=byID[id]
            local unread=not member.me and not member.talented and ns.PartyCooldownConfig().talentSpells[id]
            if ForSpec(info,member.spec,member.roleSpecs)and not unread and not(FACTION[id]and faction and FACTION[id]~=faction)and(not member.me or info.added or info.detected or Known(id))then add(id)end
        end
    end
    for _,s in ipairs(member.race and RACIAL[member.race]or{})do if not member.me or Known(s[1])then add(s[1])end end
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
        local learned=ns.PartyCooldownConfig().learned[ns.PartyCooldownLearnKey(member)]
        if learned and learned[id]then return learned[id]end
    end
    -- Talents not read: the spec's usual build.
    local likely=member and not member.me and not member.ranks and member.spec and LIKELY[member.spec]
    if likely and likely[id]then return likely[id]end
    return WithTalents(member,id,BaseCooldown(id))
end
-- Learned lengths belong to a spec and the cooldown talents taken, so a talent change is not
-- hidden by a length learned with the old talents.
function ns.PartyCooldownLearnKey(member)
    local key=tostring(member and member.spec or ns.Spec()or 0)
    local ranks=member and member.ranks;if not ranks then return key end
    local ids={};for id,r in pairs(ranks)do if r>0 then ids[#ids+1]=id..":"..r end end;table.sort(ids)
    return key.."/"..table.concat(ids,",")
end
-- Your own cooldown straight from the game, so every reduction counts: start and length when it
-- runs, 0 when the game says it is ready, nil when the game does not say (hidden in combat).
local function OwnCooldown(id)
    local get=C_Spell and C_Spell.GetSpellCooldown;if not get then return nil end
    local ok,info=pcall(get,id);if not ok or type(info)~="table"then return nil end
    local start,dur=info.startTime,info.duration
    if not(ns.Plain(start,"number")and ns.Plain(dur,"number"))then return nil end
    if dur>1.5 and start>0 then return start,dur end
    return 0,0
end
ns.PartyCooldownOwn=OwnCooldown
-- Exact: your own cooldown as the game shows it now, or a length the member's addon sent with a
-- start that was seen (a cast, a buff, an interrupt that named them) and not shortened by a guess.
-- Everything else is an estimate, marked with "~": base lengths, guessed interrupts, hidden timers.
local SURE={cast=true,sensor=true,named=true}
-- A hidden timer, unless it is surely over: one full length after the combat it started in ended.
local function Hidden(m,id)
    local t=m.hiddenCd and m.hiddenCd[id]
    if t and t.over and GetTime()>=t.over then m.hiddenCd[id]=nil;return nil end
    return t
end
function ns.PartyCooldownExact(member,id)
    if not member then return false end
    if member.me then local start=OwnCooldown(id);if start and start>0 then return true end end
    if Hidden(member,id)and not member.used[id]then return false end
    local how=member.how and member.how[id]
    return(member.cds and member.cds[id]and SURE[how]and not(member.cut and member.cut[id]))and true or false
end
local function Started(m,id,at,how)m.used[id]=at;m.how=m.how or{};m.how[id]=how;if m.cut then m.cut[id]=nil end end
-- Seconds left on a member's cooldown, 0 when ready.
function ns.PartyCooldownLeft(member,id)
    if member and member.me then local start,dur=OwnCooldown(id);if start then return start>0 and math.max(0,start+dur-GetTime())or 0 end end
    local start=member and member.used and member.used[id];if not start then return 0 end
    return math.max(0,start+ns.PartyCooldownLength(member,id)-GetTime())
end

---------------------------------------------------------------------------
-- Who is tracked: you and party1-4, or in a raid the players of your own group.
local function Units()
    local cfg=ns.PartyCooldownConfig();local out={"player"}
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
local pendingPCD,ReadPendingPCD={},nil -- group messages from players not in the roster yet
function ns.PartyCooldownRoster()
    local keep={};order={}
    for _,unit in ipairs(Units())do
        local name,realm;if UnitName then name,realm=UnitName(unit)end;local class;if UnitClass then class=select(2,UnitClass(unit))end
        if ns.Plain(name,"string")and name~=""then
            -- Players of another realm are kept as Name-Realm (as group messages and the meter
            -- name them), so two players of the same name never share timers.
            if ns.Plain(realm,"string")and realm~=""then name=name.."-"..realm end
            name=ns.ShortName(name)or name
            local m=members[name]or{name=name,used={}};members[name]=m
            m.unit=unit;m.me=unit=="player";m.class=ns.Plain(class,"string")and class or m.class
            m.spec=(m.me and ns.Spec())or m.sentSpec or InspectSpec(unit)or m.spec
            if UnitRace then local ok,_,race=pcall(UnitRace,unit);if ok and ns.Plain(race,"string")then m.race=race end end
            if UnitFactionGroup then local ok,f=pcall(UnitFactionGroup,unit);if ok and ns.Plain(f,"string")then m.faction=f end end
            local role=UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
            m.roleSpecs=m.class and ns.Plain(role,"string")and ns.RoleSpecs(m.class,role)or nil
            if not m.spec and m.roleSpecs and #m.roleSpecs==1 then m.spec=m.roleSpecs[1]end
            keep[name]=true;order[#order+1]=name
        end
    end
    for name in pairs(members)do if not keep[name]then members[name]=nil end end
    if next(pendingPCD)and ReadPendingPCD then ReadPendingPCD()end
    return order
end
function ns.PartyCooldownOrder()return order end

-- Inspecting fills in the spec of members without the addon, one at a time and only out of combat.
local inspectTimer
local function InspectNext()
    inspectTimer=nil
    if InCombatLockdown and InCombatLockdown()then return end
    if not(NotifyInspect and CanInspect)then return end
    local soonest
    for _,name in ipairs(order)do local m=members[name]
        -- No answer (out of range...): asked again after 15 s, up to 6 times.
        if m and not m.me and not m.addon and(not m.spec or not m.talented)and(m.tries or 0)<6 then
            local wait=m.asked and 15-(GetTime()-m.asked)or 0
            if wait<=0 then
                local ok,can=pcall(CanInspect,m.unit);if ok and can then m.asked=GetTime();m.tries=(m.tries or 0)+1;pcall(NotifyInspect,m.unit)
                    if C_Timer and C_Timer.NewTimer then inspectTimer=C_Timer.NewTimer(2,InspectNext)end;return end
            elseif not soonest or wait<soonest then soonest=wait end
        end
    end
    -- Everyone left was asked recently: come back when the first wait is over.
    if soonest and C_Timer and C_Timer.NewTimer then inspectTimer=C_Timer.NewTimer(soonest+0.1,InspectNext)end
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
    -- Your own record carries your talent ranks, so the lengths sent include them.
    local me;for _,x in pairs(members)do if x.me then me=x end end
    if not me or me.spec~=spec then me={me=true,spec=spec,used={},ranks=me and me.ranks}end
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
local lastShare,shareTimer,shareState=-100,nil,"never"
function ns.SharePartyCooldowns(force)
    local cfg=ns.PartyCooldownConfig();if not cfg.enabled or not cfg.share then return false end
    if InCombatLockdown and InCombatLockdown()then return false end
    local wait=10-(GetTime()-lastShare)
    if not force and wait>0 then
        if not shareTimer and C_Timer and C_Timer.NewTimer then shareTimer=C_Timer.NewTimer(wait,function()shareTimer=nil;ns.SharePartyCooldowns(true)end)end
        return false
    end
    lastShare=GetTime();local sent=ns.Send("PCD",ns.PartyCooldownPayload());shareState=sent and"queued"or"not sent";return sent
end
-- A message from a player not yet in the roster (it can arrive before the group update) waits
-- 30 s and is read when they appear.
local function ReadPCD(m,text)
    local fields={};for f in(text..";"):gmatch("([^;]*);")do fields[#fields+1]=f end
    local spec=tonumber(fields[1]);if not spec or #fields>80 then return false end
    -- Everything is checked first and applied as a whole: a spec of the member's class, and
    -- spells that are not another class's.
    if spec>0 then
        local fits=not m.class
        for _,s in ipairs(m.class and ns.ClassSpecs and ns.ClassSpecs[m.class]or{})do if s==spec then fits=true end end
        if not fits then return false end
    end
    local known,cds,new={},{},{}
    for i=2,#fields do
        local id,cd=fields[i]:match("^(%d+)=(%d+)$");id,cd=tonumber(id),tonumber(cd)
        if id and cd and id>0 and cd>0 and cd<=1800 then
            local info=byID[id]
            if not info then new[#new+1]={id,i}
            elseif info.class and m.class and info.class~=m.class then id=nil end
            if id then known[id]=true;cds[id]=cd end
        end
    end
    for _,x in ipairs(new)do if m.class then Register(x[1],m.class,800+x[2])else known[x[1]],cds[x[1]]=nil,nil end end
    m.sentSpec=spec>0 and spec or nil;m.spec=m.sentSpec or m.spec;m.known=known;m.cds=cds;m.addon=true;m.sentAt=GetTime()
    return true
end
ns.CommHandlers.PCD=function(text,sender)
    if not sender or type(text)~="string"or #text>1000 then return end
    -- Only members of the group being tracked are listened to.
    local m=members[sender]
    if not m then pendingPCD[sender]={text=text,at=GetTime()};return end
    pendingPCD[sender]=nil
    if ReadPCD(m,text)then ns.RebuildPartyCooldownSensors();ns.DrawPartyCooldowns()end
end
function ReadPendingPCD()
    local read=false
    for name,p in pairs(pendingPCD)do
        if GetTime()-p.at>30 then pendingPCD[name]=nil
        elseif members[name]then pendingPCD[name]=nil;read=ReadPCD(members[name],p.text)or read end
    end
    -- Read while the roster is rebuilt: sensors and icons follow right after.
    if read and C_Timer and C_Timer.NewTimer then C_Timer.NewTimer(0,function()ns.RebuildPartyCooldownSensors();ns.DrawPartyCooldowns()end)end
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
        local me;for _,x in pairs(members)do if x.me then me=x end end
        local learned=ns.PartyCooldownConfig().learned;local key=ns.PartyCooldownLearnKey(me)
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
    if not info or not ns.PartyCooldownTracked(id,m.spec)or(info.class and m.class and info.class~=m.class)or(info.race and m.race~=info.race)then return false end
    -- One cast arrives once per unit that shows it.
    if m.used[id]and GetTime()-m.used[id]<1 then return true end
    Started(m,id,GetTime(),"cast")
    if m.me and not Learn(id)then pendingLearn[id]=true end
    ns.DrawPartyCooldowns();RedrawLater(ns.PartyCooldownLength(m,id))
    return true
end
function ns.PartyCooldownReset()for _,m in pairs(members)do m.used={};m.hiddenCd=nil end;ns.DrawPartyCooldowns()end

---------------------------------------------------------------------------
-- Display: a movable list (name and icons per member), or icons beside the Blizzard or ElvUI
-- party frames. Members whose frame is not found stay in the list. Interrupts and crowd control
-- have movable lists of their own ("anchors"), each with its own size, direction and names.
local attached
local groups={}
local TITLES={main="Party cooldowns",kick="Interrupts",cc="Crowd control"}
-- Where a list sits: the main list keeps cfg.pos, the anchors keep x/y in their own settings.
local function Place(key)
    local cfg=ns.PartyCooldownConfig()
    if key=="main"then return cfg.pos end
    return cfg.anchors[key]
end
local function Group(key)
    local g=groups[key];if g then return g end
    local f=CreateFrame("Frame",nil,UIParent);f:SetFrameStrata("MEDIUM");f:SetSize(200,30)
    f.bg=f:CreateTexture(nil,"BACKGROUND");f.bg:SetAllPoints();f.bg:SetColorTexture(0.6,0.36,1,0.25)
    f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormal");f.title:SetPoint("BOTTOMLEFT",f,"TOPLEFT",2,2);f.title:SetText(L(TITLES[key]))
    f:SetMovable(true);f:SetClampedToScreen(true);f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function(self)if ns.PartyCooldownConfig().unlocked then self:StartMoving()end end)
    f:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing()
        local x,y=self:GetCenter();local ux,uy=UIParent:GetCenter()
        if type(x)=="number"and type(ux)=="number"then
            local pos=Place(key);pos.x,pos.y=math.floor(x-ux+0.5),math.floor(y-uy+0.5);g.x,g.y=pos.x,pos.y
        end
    end)
    f:Hide()
    g={key=key,frame=f,rows={}};groups[key]=g
    return g
end
ns.PartyCooldownGroups=groups
-- Moves the list only when its saved place changed (a reset), never in the middle of a drag.
local function Anchor(g)
    local pos=Place(g.key);local x,y=tonumber(pos.x)or 0,tonumber(pos.y)or 0
    if g.x~=x or g.y~=y then g.frame:ClearAllPoints();g.frame:SetPoint("CENTER",UIParent,"CENTER",x,y);g.x,g.y=x,y end
end
local function Row(g,i)
    local row=g.rows[i];if row then return row end
    row=CreateFrame("Frame",nil,g.frame);row.name=row:CreateFontString(nil,"OVERLAY","GameFontNormal");row.icons={};g.rows[i]=row
    return row
end
local function Icon(row,i,size)
    local icon=row.icons[i]
    if not icon then
        icon=CreateFrame("Frame",nil,row);icon.tex=icon:CreateTexture(nil,"ARTWORK");icon.tex:SetAllPoints();icon.tex:SetTexCoord(0.07,0.93,0.07,0.93)
        icon.cd=CreateFrame("Cooldown",nil,icon,"CooldownFrameTemplate");icon.cd:SetAllPoints();row.icons[i]=icon
        icon.approx=icon.cd:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");icon.approx:SetPoint("TOPRIGHT",icon,"TOPRIGHT",-1,-1);icon.approx:SetText("~");icon.approx:Hide()
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
    -- A remembered frame is used only while it still shows this unit; "not found" is looked up
    -- again after 10 s.
    local cached=frameCache[unit]
    if type(cached)=="number"and GetTime()-cached<10 then return nil end
    if type(cached)=="table"and match(cached)then return cached end
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
    frameCache[unit]=best or GetTime();return best
end
ns.PartyCooldownFrame=UnitFrame
local ShowHidden -- hidden timers on icons, defined with the buff sensors
local SIDES={RIGHT={"LEFT","RIGHT",2,0,1,0},LEFT={"RIGHT","LEFT",-2,0,-1,0},TOP={"BOTTOMLEFT","TOPLEFT",0,2,1,0},BOTTOM={"TOPLEFT","BOTTOMLEFT",0,-2,1,0}}
local function FillIcons(row,m,ids,size,cfg)
    local n=0
    for _,id in ipairs(ids)do
        local left=ns.PartyCooldownLeft(m,id)
        local hidden=Hidden(m,id)
        if not(cfg.hideReady and left<=0 and not hidden)then
            n=n+1;local icon=Icon(row,n,size)
            icon.tex:SetTexture(W.SpellTexture(id));icon.spellID=id
            local start,dur;if m.me then start,dur=OwnCooldown(id)end
            if start==0 then start=nil elseif not start and m.used[id]then start,dur=m.used[id],ns.PartyCooldownLength(m,id)end
            if left>0 and start then icon.cd:SetCooldown(start,dur);icon.tex:SetDesaturated(true)
            else icon.cd:Clear();icon.tex:SetDesaturated(false)end
            if(left>0 or hidden)and not ns.PartyCooldownExact(m,id)then icon.approx:Show()else icon.approx:Hide()end
            icon:Show();ShowHidden(icon,hidden)
        end
    end
    for i=n+1,#row.icons do row.icons[i]:Hide();ShowHidden(row.icons[i],nil)end
    return n
end
-- One list: a row per member, a class bar or the name, then the icons. `opts`: size, names,
-- hideReady, grow ("DOWN" or "UP").
local function DrawRows(g,entries,opts,unlocked)
    local f=g.frame;Anchor(g)
    local size=tonumber(opts.size)or 26;local font=W.Font and W.Font(true);local y,widest=0,0
    local up=opts.grow=="UP"
    for i,e in ipairs(entries)do
        local m,ids=e[1],e[2]
        local row=Row(g,i)
        row:ClearAllPoints()
        if up then row:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",4,y+4)else row:SetPoint("TOPLEFT",f,"TOPLEFT",4,-y-4)end
        row:SetSize(1,size)
        if type(font)=="string"then row.name:SetFont(font,12,"OUTLINE")end
        local c=m.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
        row.name:SetTextColor(c and c.r or 1,c and c.g or 1,c and c.b or 1)
        -- Without names a thin bar in the class colour starts each row.
        local start=opts.names and 94 or 6
        if not row.bar then row.bar=row:CreateTexture(nil,"ARTWORK")end
        row.bar:SetColorTexture(c and c.r or 1,c and c.g or 1,c and c.b or 1,1);row.bar:ClearAllPoints();row.bar:SetPoint("LEFT",row,"LEFT",0,0);row.bar:SetSize(3,size)
        if opts.names then row.name:SetText(ns.DisplayName and ns.DisplayName(m.name)or m.name);row.name:Show();row.bar:Hide()else row.name:SetText("");row.name:Hide();row.bar:Show()end
        row.name:ClearAllPoints();row.name:SetPoint("LEFT",row,"LEFT",0,0);row.name:SetWidth(90)
        local n=FillIcons(row,m,ids,size,opts)
        for k=1,n do local icon=row.icons[k];icon:ClearAllPoints();icon:SetPoint("LEFT",row,"LEFT",start+(k-1)*(size+2),0)end
        widest=math.max(widest,start+n*(size+2));row:Show();y=y+size+4
    end
    for i=#entries+1,#g.rows do g.rows[i]:Hide()end
    f:SetSize(math.max(60,widest+8),math.max(size+8,y+4));f:EnableMouse(unlocked==true)
    f.title:SetText(L(TITLES[g.key]))
    if unlocked then f.bg:Show();f.title:Show()else f.bg:Hide();f.title:Hide()end
    if #entries>0 or unlocked then f:Show()else f:Hide()end
    return #entries
end
-- Interrupts and crowd control: one cell per member and spell, as icons or as bars, in a grid.
-- a.style "icons" or "bars"; a.size: icon size or bar height; a.width: bar width; a.dir "RIGHT" or
-- "LEFT": where bars fill and the grid grows; a.grow "DOWN" or "UP"; a.perRow cells in a row, a.rows
-- rows at most; a.texture: the bar texture (see BarTextures); a.self: show your own spells.
-- Bar textures: a few of the game's, and every one LibSharedMedia-3.0 lists when another addon loads it.
local GAME_BARS={{value="",label="Blizzard",file="Interface\\TargetingFrame\\UI-StatusBar"},{value="flat",label="Flat",file="Interface\\Buttons\\WHITE8X8"},
    {value="raid",label="Raid frame",file="Interface\\RaidFrame\\Raid-Bar-Hp-Fill"},{value="skills",label="Skill bar",file="Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"}}
local function SharedMedia()return LibStub and LibStub("LibSharedMedia-3.0",true)end
function ns.PartyBarTextures()
    local out={};for _,t in ipairs(GAME_BARS)do out[#out+1]={value=t.value,label=L(t.label)}end
    local lsm=SharedMedia();if lsm and lsm.List then local ok,list=pcall(lsm.List,lsm,"statusbar")
        if ok and type(list)=="table"then for _,name in ipairs(list)do out[#out+1]={value="lsm:"..name,label=name}end end end
    return out
end
local function BarFile(choice)
    for _,t in ipairs(GAME_BARS)do if t.value==choice then return t.file end end
    if type(choice)=="string"and choice:sub(1,4)=="lsm:"then local lsm=SharedMedia()
        local ok,file=pcall(function()return lsm and lsm:Fetch("statusbar",choice:sub(5),true)end);if ok and type(file)=="string"then return file end end
    return GAME_BARS[1].file
end
ns.PartyBarFile=BarFile
local function CellSpellName(id)
    local ok,name=pcall(C_Spell and C_Spell.GetSpellName or function()end,id)
    return ok and ns.Plain(name,"string")and name or""
end
local function Timing(m,id)
    local start,dur;if m.me then start,dur=OwnCooldown(id)end
    if start==0 then start=nil elseif not start and m.used[id]then start,dur=m.used[id],ns.PartyCooldownLength(m,id)end
    local left=start and math.max(0,start+dur-GetTime())or 0
    return left,start,dur,Hidden(m,id)
end
local function Cell(g,i)
    local f=g.frame;f.icons=f.icons or{}
    local cell=Icon(f,i,10)
    if not cell.bar then
        local bar=CreateFrame("StatusBar",nil,f);bar:SetStatusBarTexture(GAME_BARS[1].file);bar:SetMinMaxValues(0,1);bar:SetValue(1)
        bar.bg=bar:CreateTexture(nil,"BACKGROUND");bar.bg:SetAllPoints();bar.bg:SetColorTexture(0,0,0,0.55)
        bar.name=bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        bar.time=bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        cell.bar=bar
        cell.label=cell:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    end
    return cell
end
-- Bars drain while their cooldown runs. Only exact timers show seconds.
local function UpdateBars(self,elapsed)
    self.wait=(self.wait or 0)-(elapsed or 0);if self.wait>0 then return end;self.wait=0.1
    local now=GetTime()
    for _,cell in ipairs(self.icons or{})do local bar=cell.bar
        if bar and bar:IsShown()then
            local left=bar.start and bar.start+bar.dur-now or 0
            if left>0 then bar:SetMinMaxValues(0,bar.dur);bar:SetValue(left);bar.time:SetText((bar.approx and"~"or"")..math.ceil(left))
            else bar:SetMinMaxValues(0,1);bar:SetValue(bar.hidden and 0 or 1);bar.time:SetText("")end
        end
    end
end
local function DrawAnchor(g,entries,a,unlocked)
    local f=g.frame;Anchor(g)
    local bars=a.style=="bars";local size=tonumber(a.size)or 26;local width=bars and math.max(size+20,tonumber(a.width)or 180)or size
    local perRow=math.max(1,math.floor(tonumber(a.perRow)or 1));local rows=math.max(1,math.floor(tonumber(a.rows)or 5))
    local left,up,gap=a.dir=="LEFT",a.grow=="UP",2
    local h,v=left and"RIGHT"or"LEFT",up and"BOTTOM"or"TOP"
    local font=W.Font and W.Font(true)
    local n=0
    for _,e in ipairs(entries)do local m=e[1]
        for _,id in ipairs(e[2])do
            local remain,start,dur,hidden=Timing(m,id)
            if n<perRow*rows and not(a.hideReady and remain<=0 and not hidden)then
                n=n+1;local cell=Cell(g,n);local col,row=(n-1)%perRow,math.floor((n-1)/perRow)
                cell:ClearAllPoints();cell:SetSize(size,size)
                cell:SetPoint(v..h,f,v..h,(left and-1 or 1)*(3+col*(width+gap)),(up and 1 or-1)*(3+row*(size+gap)))
                cell.tex:SetTexture(W.SpellTexture(id));cell.spellID=id;cell.member=m.name
                if remain>0 and start then cell.cd:SetCooldown(start,dur);cell.tex:SetDesaturated(true)else cell.cd:Clear();cell.tex:SetDesaturated(false)end
                local approx=(remain>0 or hidden)and not ns.PartyCooldownExact(m,id)
                if approx and not bars then cell.approx:Show()else cell.approx:Hide()end
                -- Bars carry the time; the icon beside a bar shows no countdown of its own.
                if cell.cd.SetHideCountdownNumbers then cell.cd:SetHideCountdownNumbers(bars)end
                cell:Show();ShowHidden(cell,hidden)
                local c=m.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
                local r,gr,b=c and c.r or 0.6,c and c.g or 0.36,c and c.b or 1
                local bar,label=cell.bar,cell.label
                local name=ns.DisplayName and ns.DisplayName(m.name)or m.name
                if bars then
                    bar:ClearAllPoints();bar:SetSize(width-size-gap,size)
                    if left then bar:SetPoint("RIGHT",cell,"LEFT",-gap,0)else bar:SetPoint("LEFT",cell,"RIGHT",gap,0)end
                    if bar.SetReverseFill then bar:SetReverseFill(left)end
                    local file=BarFile(a.texture);if bar.file~=file then bar.file=file;bar:SetStatusBarTexture(file)end
                    bar:SetStatusBarColor(r,gr,b,1)
                    bar.start,bar.dur,bar.hidden,bar.approx=remain>0 and start or nil,dur,hidden~=nil,approx
                    if type(font)=="string"then bar.name:SetFont(font,11,"OUTLINE");bar.time:SetFont(font,11,"OUTLINE")end
                    bar.name:ClearAllPoints();bar.time:ClearAllPoints()
                    bar.name:SetPoint(left and"RIGHT"or"LEFT",bar,left and"RIGHT"or"LEFT",left and-4 or 4,0)
                    bar.time:SetPoint(left and"LEFT"or"RIGHT",bar,left and"LEFT"or"RIGHT",left and 4 or-4,0)
                    bar.name:SetText(a.names and name or CellSpellName(id))
                    bar:Show();label:Hide()
                else
                    bar:Hide();bar.start=nil
                    if a.names then
                        if type(font)=="string"then label:SetFont(font,9,"OUTLINE")end
                        label:ClearAllPoints();label:SetPoint("BOTTOM",cell,"BOTTOM",0,1);label:SetWidth(size)
                        label:SetText(name);label:SetTextColor(r,gr,b);label:Show()
                    else label:Hide()end
                end
            end
        end
    end
    for i=n+1,#(f.icons or{})do local cell=f.icons[i];cell:Hide();ShowHidden(cell,nil);if cell.bar then cell.bar:Hide();cell.bar.start=nil end end
    local cols=math.max(1,math.min(perRow,n));local used=math.max(1,math.ceil(n/perRow))
    f:SetSize(cols*(width+gap)+4,used*(size+gap)+4);f:EnableMouse(unlocked==true)
    f.title:SetText(L(TITLES[g.key]))
    if unlocked then f.bg:Show();f.title:Show()else f.bg:Hide();f.title:Hide()end
    if n>0 or unlocked then f:Show()else f:Hide()end
    if bars and n>0 then f.wait=0;f:SetScript("OnUpdate",UpdateBars);UpdateBars(f,0)else f:SetScript("OnUpdate",nil)end
    return n
end
ns.PartyCooldownUpdateBars=UpdateBars
-- Where the lists show: cfg.loadWorld off hides them outside dungeons, raids, scenarios and
-- arenas; cfg.loadSolo off hides them while you are not in a group. Tracking goes on either way.
function ns.PartyCooldownsLoaded()
    local cfg=ns.PartyCooldownConfig()
    if cfg.loadSolo==false and not(IsInGroup and IsInGroup())then return false end
    if cfg.loadWorld==false then local ok,inside=pcall(IsInInstance or function()end);if not(ok and inside)then return false end end
    return true
end
function ns.DrawPartyCooldowns()
    local cfg=ns.PartyCooldownConfig()
    attached=attached or{}
    for _,a in pairs(attached)do a:Hide()end
    if not((cfg.enabled and ns.PartyCooldownsLoaded())or cfg.unlocked)then for _,g in pairs(groups)do g.frame:Hide()end;return false end
    ns.PartyCooldownRoster()
    local size=tonumber(cfg.size)or 26
    -- You stay tracked (your casts, learned lengths, what you send); "self" only hides your icons,
    -- for the main list (cfg.self) and for each of the kick and cc lists (anchors[key].self).
    -- Unlocked with nobody else in the group, your own spells are the preview of every list.
    local kickSelf,ccSelf=cfg.anchors.kick.self~=false,cfg.anchors.cc.self~=false
    local names,others={},0
    for _,name in ipairs(order)do local me=members[name]and members[name].me
        if not me then others=others+1 end
        if not me or cfg.self or kickSelf or ccSelf or cfg.unlocked then names[#names+1]=name end
    end
    local preview=cfg.unlocked and others==0
    if #names==0 and cfg.unlocked then
        local _,class=UnitClass("player");local me=UnitName("player")or"Player"
        members[me]=members[me]or{name=me,used={},me=true,class=class,spec=ns.Spec()};names={me}
    end
    local main,kicks,cc={},{},{}
    for _,name in ipairs(names)do
        local m=members[name];m.name=m.name or name
        local ids=ns.PartyCooldownList(m,"defensive")
        local frame=cfg.mode=="frames"and m.unit and UnitFrame(m.unit)
        if m.me and not cfg.self and not preview then -- your own icons are hidden in the main list
        elseif frame then
            local holder=attached[name]
            if not holder then holder=CreateFrame("Frame",nil,UIParent);holder.icons={};attached[name]=holder end
            local side=SIDES[cfg.side]or SIDES.RIGHT
            local n=FillIcons(holder,m,ids,size,cfg)
            holder:ClearAllPoints();holder:SetPoint(side[1],frame,side[2],side[3],side[4]);holder:SetSize(math.max(1,n*(size+2)),size)
            for i=1,n do local icon=holder.icons[i];icon:ClearAllPoints()
                if side[5]>0 then icon:SetPoint("LEFT",holder,"LEFT",(i-1)*(size+2),0)else icon:SetPoint("RIGHT",holder,"RIGHT",-(i-1)*(size+2),0)end
            end
            holder:Show()
        else main[#main+1]={m,ids}end
        local own=m.me and not preview
        local k=(kickSelf or not own)and ns.PartyCooldownList(m,"kick")or{};if #k>0 then kicks[#kicks+1]={m,k}end
        local x=(ccSelf or not own)and ns.PartyCooldownList(m,"cc")or{};if #x>0 then cc[#cc+1]={m,x}end
    end
    DrawRows(Group("main"),main,cfg,cfg.unlocked)
    DrawAnchor(Group("kick"),cfg.kicks~=false and kicks or{},cfg.anchors.kick,cfg.unlocked and cfg.kicks~=false)
    DrawAnchor(Group("cc"),cfg.cc~=false and cc or{},cfg.anchors.cc,cfg.unlocked and cfg.cc~=false)
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
local SELF,EXTERNAL,ENEMY=1,2,3
-- Spells whose buff is not the spell itself, or that buff more than the caster. Every other
-- tracked spell is sensed by its own ID on the caster. {kind, buff IDs...}
local BUFFS={
    [49028]={SELF,81256},[48707]={SELF,48707,444741},[51052]={EXTERNAL,51052,145629},
    [198589]={SELF,212800},[191427]={SELF,162264},[196718]={EXTERNAL,209426},
    [194223]={SELF,194223,102560,390414},[102560]={SELF,102560,390414},[106951]={SELF,106951,102543},[102543]={SELF,102543},
    [740]={EXTERNAL,740,157982,1264623},[33891]={SELF,117679,33891},[102342]={EXTERNAL,102342},[106898]={EXTERNAL,106898,77761,77764},
    [357170]={EXTERNAL,357170},[374227]={EXTERNAL,374227},
    [19574]={SELF,19574,186254,1235388,1285912},[365350]={SELF,365350,365362},[45438]={SELF,45438,414658},[414658]={SELF,414658,45438},
    [342245]={SELF,342246},[80353]={EXTERNAL,80353},
    [123904]={SELF,123904,1248992},[115203]={SELF,115203,120954},[116849]={EXTERNAL,116849},
    [31884]={SELF,31884,231895,454351,216331,389539},[231895]={SELF,231895,31884},[216331]={SELF,216331,31884},
    [498]={SELF,498,403876},[403876]={SELF,403876,498},[31821]={EXTERNAL,31821},
    [1022]={EXTERNAL,1022,204018},[6940]={EXTERNAL,6940},[204018]={EXTERNAL,204018},
    [62618]={EXTERNAL,81782},[228260]={SELF,194249},[10060]={EXTERNAL,10060},[33206]={EXTERNAL,33206},[47788]={EXTERNAL,47788},
    [64843]={EXTERNAL,64843,64844},[360194]={SELF,1249810,360194},
    [114050]={SELF,114050,1219480},[98008]={EXTERNAL,325174},[198103]={SELF,198103,381755},[2825]={EXTERNAL,2825},[32182]={EXTERNAL,32182},
    [265187]={SELF,1276767,265187},[1122]={SELF,1122,111685,266087,417282},
    [192077]={EXTERNAL,192082},[1044]={EXTERNAL,1044},[116841]={EXTERNAL,116841},[1250646]={SELF,1250646,1251703},
    [66]={SELF,66,32612,110960,113862},[1856]={SELF,11327},[20594]={SELF,65116},
    [374968]={EXTERNAL,375226,375229,375230,375234,375238,375240,375252,375253,375254,375255,375256,375257,375258},
    [97462]={EXTERNAL,97463},[227847]={SELF,227847,446035},[107574]={SELF,107574,401150},
}
-- Crowd control is seen as its debuff on enemy nameplates. `LAG`: seconds from the cast to the
-- debuff (sigils and totems go off later).
for id,debuffs in pairs({[119381]={119381},[179057]={179057},[30283]={30283},[192058]={118905},[46968]={132168},[109248]={117405,117526},
    [853]={853},[19577]={24394,474421},[207167]={207167},[115750]={105421},[8122]={8122},[99]={99},[5246]={5246},[207684]={207685},
    [202138]={204843},[108199]={374776},[102793]={127797},[132469]={61391},[2094]={2094}})do BUFFS[id]={ENEMY,unpack(debuffs)}end
local LAG={[192058]=2,[207684]=2,[202138]=2}
local PLATES=40
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
    if InCombatLockdown and InCombatLockdown()then t.over=nil end
    local sl=t.slot[t.cur]
    if now-sl.wepoch>t.open then t.cur=3-t.cur;t.slot[t.cur]=NewSlot(now);t.moved=true end
    return t
end
ns.PartyCooldownHiddenTrack=Hidden
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
        if icon.track~=t or not icon:IsVisible()then shownHidden[icon]=nil
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
    lines[#lines+1]="Party cooldowns "..tostring(ns.version)..", in combat: "..tostring(InCombatLockdown and InCombatLockdown()or false)..". Buff sensors: "..(sensorState.available==false and("not available ("..tostring(sensorState.reason)..")")or(#sensors.." watching"))
        ..", lit now "..(function()local n=0;for _,s in ipairs(sensors)do if s.lit then n=n+1 end end;return n end)()
        ..", hidden answers kept "..(sensorState.hiddenEdges or 0)..", power bars read "..spendState.plain.." hidden "..spendState.hidden..", exact times "..tostring(ns.PartyCooldownFine and ns.PartyCooldownFine()or false)..", refused "..(sensorState.refused or 0)..(EVAL()and""or", no curve helper")..", my cooldowns "..shareState
    local k=ns.PartyCooldownKickStats and ns.PartyCooldownKickStats()
    if k then lines[#lines+1]="Interrupts seen "..k.seen..": by the meter "..k.meter..", by name "..k.named..", only one ready "..k.ready..", unknown "..k.unsure end
    for _,name in ipairs(order)do local m=members[name]
        local sens=0;for _,s in ipairs(sensors)do if s.member==name then sens=sens+1 end end
        lines[#lines+1]=name..": "..tostring(m.class).." "..tostring(m.spec and ns.Catalog.specs[m.spec]or"spec unknown")..(m.talented and", talents read"or", talents not read")
            ..", icons "..#ns.PartyCooldownList(m)..", sensors "..sens..", casts seen "..(m.seen or 0).." hidden "..(m.hidden or 0).." by buff "..(m.sensed or 0)
            ..", hidden timers "..(function()local n=0;for _ in pairs(m.hiddenCd or{})do n=n+1 end;return n end)()
            ..(m.ranks and", cooldown talents read"or"")
            ..(m.addon and(", lengths sent "..math.floor(GetTime()-(m.sentAt or GetTime())).." s ago")or", base lengths")
            ..(function()
                -- Running timers: how many are exact, and where each start came from.
                local exact,guess,from=0,0,{}
                for id in pairs(m.used)do if ns.PartyCooldownLeft(m,id)>0 then
                    if ns.PartyCooldownExact(m,id)then exact=exact+1 else guess=guess+1 end
                    local how=m.how and m.how[id]or"?";from[how]=(from[how]or 0)+1
                end end
                local list={};for how,n in pairs(from)do list[#list+1]=how.." "..n end;table.sort(list)
                return exact+guess>0 and(", running "..exact.." exact "..guess.." estimated ("..table.concat(list,", ")..")")or""
            end)()
    end
    return lines
end
local function NewSensor(unit,buffs,filter)
    if not sensorHost then sensorHost=CreateFrame("Frame",nil,UIParent);sensorHost:SetSize(1,1);sensorHost:SetPoint("TOPLEFT",UIParent,"TOPLEFT",-20,0)end
    local ok,c=pcall(CreateFrame,"AuraContainer",nil,sensorHost,"CustomAuraContainerTemplate")
    if not ok or not c or not c.AddAuraGroup then sensorState.available=false;sensorState.reason="the game has no aura container widget";return nil end
    c:SetSize(1,1);c:ClearAllPoints();c:SetPoint("TOPLEFT",UIParent,"TOPLEFT",-11,0);pcall(c.EnableMouse,c,false)
    local added=pcall(c.AddAuraGroup,c,"pcd",filter or"HELPFUL",{maxFrameCount=1,candidateFilters={includeSpellIDs=buffs},
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
            for _,x in ipairs(ns.PartyCooldownList(m))do if x==id then
                -- Two members could have cast it: nobody is credited.
                if best and best~=m then return nil end;best=m
            end end
        end
    end
    return best
end
local function Sensed(m,id,at)
    if not m or not ns.PartyCooldownTracked(id,m.spec)then return end
    local last=m.used[id]
    -- The cast itself was seen, or the cooldown is still running: nothing new.
    if last and GetTime()-last<ns.PartyCooldownLength(m,id)-1 then return end
    Started(m,id,at or GetTime(),"sensor");m.sensed=(m.sensed or 0)+1
    ns.DrawPartyCooldowns();RedrawLater(ns.PartyCooldownLength(m,id))
end
-- When each unit's auras last changed: the moment a buff appeared, read a frame later.
local auraAt={}
local function PollSensors(only)
    local now,redraw=GetTime(),false
    for _,s in ipairs(sensors)do if not only or only[s.unit]then
        local v=SensorRead(s.frame)
        local at=auraAt[s.unit];if not at or now-at>0.5 or at>now then at=now end
        at=at-(LAG[s.spell]or 0)
        -- A container just pointed at its unit shows the old answer for a moment: no edges then.
        if s.hold and now<s.hold then s.prev=v;s.lit=Plain(v)and v
        else
            local shared=s.kind==EXTERNAL or s.kind==ENEMY
            local m=shared and s.owner or members[s.member]
            -- A spell whose timer still runs cannot have been cast again.
            local running=m and ns.PartyCooldownLeft(m,s.spell)>0
            if running then
            elseif Plain(v)and Plain(s.prev)then
                -- Out of combat the answer is plain: an ordinary timer, with seconds and a swipe.
                if v and not s.prev then
                    if shared then Sensed(ExternalOwner(s.spell),s.spell,at)else Sensed(m,s.spell,at)end
                end
            elseif m and ns.PartyCooldownTracked(s.spell,m.spec)then
                local _,created=HiddenEdge(m,s.spell,v,s.prev,now,at);if created then redraw=true end
            end
            s.prev=v;s.lit=Plain(v)and v
        end
    end end
    -- A new hidden timer needs its bars on the icon.
    if redraw then ns.DrawPartyCooldowns()end
end
ns.PartyCooldownPollSensors=function()PollSensors();SlideHidden()end
-- Reads: a few frames right after a unit's auras change (the container updates on the same event),
-- and every 0.25 s otherwise. Hidden timers are moved every frame.
-- The quick reads look only at the units whose auras changed.
local driver=CreateFrame("Frame");local quick,lastRead,dirty=0,0,{}
local sensorUnits={}
driver:SetScript("OnUpdate",function()
    local now=GetTime()
    if #sensors>0 and now-lastRead>=0.25 then quick=0;dirty={};lastRead=now;PollSensors()
    elseif quick>0 then quick=quick-1;PollSensors(dirty);if quick==0 then dirty={}end end
    if next(shownHidden)then SlideHidden()end
end)
function ns.PartyCooldownAura(unit)
    if not ns.Plain(unit,"string")then return end
    if sensorUnits[unit]then auraAt[unit]=GetTime();dirty[unit]=true;quick=3 end
end
-- A nameplate token that now shows another enemy reads that enemy's debuffs: no edges for a moment.
function ns.PartyCooldownPlate(unit)
    if not(ns.Plain(unit,"string")and sensorUnits[unit])then return end
    local hold=GetTime()+0.4
    for _,s in ipairs(sensors)do if s.unit==unit then s.hold=hold end end
end
-- Builds the sensors for the group: each member's own buffs on them, and every external of the
-- group on everyone. Out of combat only; containers are reused.
local pools={HELPFUL={},HARMFUL={}}
function ns.RebuildPartyCooldownSensors()
    local cfg=ns.PartyCooldownConfig()
    -- Containers cannot be set up in combat: the current ones keep working until combat ends,
    -- when this runs again.
    if cfg.enabled and cfg.sensors and InCombatLockdown and InCombatLockdown()then return #sensors end
    for _,s in ipairs(sensors)do pcall(s.frame.SetEnabled,s.frame,false);s.frame:Hide();local p=pools[s.filter];p[#p+1]=s.frame end
    sensors={};sensorUnits={}
    if sensorTicker then sensorTicker:Cancel();sensorTicker=nil end
    if not(cfg.enabled and cfg.sensors)or sensorState.available==false then return 0 end
    local externals,externalOwners,stops,stopOwners={},{},{},{}
    for _,name in ipairs(order)do local m=members[name]
        for _,id in ipairs(ns.PartyCooldownList(m))do local kind,buffs=BuffsOf(id)
            -- With two possible casters the owner stays open (false) and is decided when it lands.
            if kind==EXTERNAL then externals[id]=buffs;if externalOwners[id]==nil then externalOwners[id]=m else externalOwners[id]=false end
            elseif kind==ENEMY then if not m.me then stops[id]=buffs;if stopOwners[id]==nil then stopOwners[id]=m else stopOwners[id]=false end end
            elseif KIND[id]=="kick"then
            elseif not m.me then sensors[#sensors+1]={unit=m.unit,member=name,spell=id,buff=buffs,kind=SELF}end
        end
    end
    for _,name in ipairs(order)do local m=members[name]
        for id,buff in pairs(externals)do sensors[#sensors+1]={unit=m.unit,member=name,spell=id,buff=buff,kind=EXTERNAL,owner=externalOwners[id]or nil}end
    end
    -- Crowd control of the others: its debuff on every enemy nameplate.
    for id,debuffs in pairs(stops)do
        for i=1,PLATES do sensors[#sensors+1]={unit="nameplate"..i,spell=id,buff=debuffs,kind=ENEMY,owner=stopOwners[id]or nil,filter="HARMFUL"}end
    end
    local made={}
    for _,s in ipairs(sensors)do
        s.filter=s.filter or"HELPFUL"
        local c=table.remove(pools[s.filter])
        if c then pcall(c.SetAuraGroupCandidateFilters,c,"pcd",{includeSpellIDs=s.buff});c:Show()
        else c=NewSensor(s.unit,s.buff,s.filter)end
        if not c then break end
        sensorUnits[s.unit]=true
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
    if start and GetTime()<start+ns.PartyCooldownLength(m,id)then m.used[id]=start-sec;m.shortened=true;m.cut=m.cut or{};m.cut[id]=true end
    local t=m.hiddenCd and m.hiddenCd[id]
    if t then for k=1,2 do MoveSlot(t.slot[k],-sec)end end
end
ns.PartyCooldownShorten=Shorten
local lastSpendDraw=0
function ns.PartyCooldownPower(unit)
    for _,m in pairs(members)do
        local sp=m.class and SPEND[m.class]
        -- Only a talent read with a rank above 0 counts as taken.
        if sp and m.unit==unit and m.ranks and(m.ranks[sp.talent]or 0)>0 and sp.per[m.spec or 0]then
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
---------------------------------------------------------------------------
-- Interrupts of the others. In combat the game hides who cast what, but two things stay readable:
-- an enemy's interrupted cast (sometimes with who interrupted it), and the order of the built-in
-- damage meter's Interrupts list (names and classes; the counts are hidden). A member who joins
-- that list or moves up in it has just interrupted. When neither tells who, the interrupt goes to
-- the only member whose interrupt was ready, or to nobody. Interrupts that hit nothing are not seen.
local kickState={seen=0,meter=0,named=0,ready=0,unsure=0}
local meterOrder,lastKickAt,ownKickAt,lastKick=nil,0,0,{}
local function KickOf(m)
    for _,id in ipairs(ns.PartyCooldownList(m))do if KIND[id]=="kick"then return id end end
end
local function Kicked(m,at,how)
    lastKickAt=GetTime()
    if not m or m.me then return false end
    local id=KickOf(m);if not id then return false end
    -- The meter and the enemy's event can both report the same interrupt.
    if lastKick[m.name]and math.abs(at-lastKick[m.name])<1 then return true end
    lastKick[m.name]=at;kickState[how]=kickState[how]+1
    Started(m,id,at,how);ns.DrawPartyCooldowns();RedrawLater(ns.PartyCooldownLength(m,id))
    return true
end
local specIcons={}
local function SpecIcon(spec)
    if specIcons[spec]==nil then
        local get=(C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoByID)or GetSpecializationInfoByID
        local ok,_,_,_,icon=pcall(get or error,spec);specIcons[spec]=ok and ns.Plain(icon,"number")and icon or false
    end
    return specIcons[spec]or nil
end
-- The meter's Interrupts list for this fight, in order: a key per entry, with what is readable.
local function MeterList()
    local DM,E=C_DamageMeter,Enum
    if not(DM and DM.GetCombatSessionFromType and E and E.DamageMeterType and E.DamageMeterType.Interrupts and E.DamageMeterSessionType)then return nil end
    local ok,session=pcall(DM.GetCombatSessionFromType,E.DamageMeterSessionType.Current,E.DamageMeterType.Interrupts)
    if not ok or not ns.Plain(session,"table")or not ns.Plain(session.combatSources,"table")then return nil end
    local list,count={},{}
    for _,src in ipairs(session.combatSources)do if ns.Plain(src,"table")then
        local name,class,icon=src.name,src.classFilename,src.specIconID
        name=ns.Plain(name,"string")and name~=""and(ns.ShortName(name)or name)or nil
        class=ns.Plain(class,"string")and class~=""and class or nil
        icon=ns.Plain(icon,"number")and icon or nil
        if name or class then
            local key=name or(class..":"..tostring(icon));count[key]=(count[key]or 0)+1
            list[#list+1]={key=key..(count[key]>1 and("#"..count[key])or""),name=name,class=class,icon=icon}
        end
    end end
    return list
end
local function MemberOf(e)
    if e.name then return members[e.name]end
    local found
    for _,m in pairs(members)do
        if m.class==e.class and not(e.icon and m.spec and SpecIcon(m.spec)and SpecIcon(m.spec)~=e.icon)then if found then return nil end;found=m end
    end
    return found
end
function ns.PartyCooldownMeter(base)
    local list=MeterList();local old=meterOrder;meterOrder=list
    if base or not(list and old)then return nil end
    local was={};for i,e in ipairs(old)do was[e.key]=i end
    local who,n=nil,0
    for i,e in ipairs(list)do local o=was[e.key];if not o or i<o then who=e;n=n+1 end end
    if n~=1 then return nil end
    local m=MemberOf(who);if m then Kicked(m,GetTime(),"meter")end
    return m
end
local ENEMY_UNIT={"^nameplate%d","^target$","^focus$","^boss%d"}
function ns.PartyCooldownInterrupted(unit,by)
    if not ns.Plain(unit,"string")then return end
    local enemy=false;for _,p in ipairs(ENEMY_UNIT)do if unit:match(p)then enemy=true end end
    if not enemy then return end
    local ok,hostile=pcall(UnitCanAttack or error,"player",unit);if ok and ns.Plain(hostile,"boolean")and not hostile then return end
    local now=GetTime();kickState.seen=kickState.seen+1
    if ns.Plain(by,"string")and by~=""then
        for _,m in pairs(members)do
            local pet=m.me and"pet"or(m.unit or""):gsub("^(%a+)(%d+)$","%1pet%2")
            for _,u in ipairs({m.unit,pet})do local okG,guid=pcall(UnitGUID or error,u);if okG and guid==by then Kicked(m,now,"named");return end end
        end
        return
    end
    -- Your own interrupt is seen as your cast.
    if now-ownKickAt<0.6 then lastKickAt=now;return end
    local function decide()
        if lastKickAt>=now-0.05 then return end
        local only
        for _,m in pairs(members)do
            local id=not m.me and KickOf(m)
            if id and ns.PartyCooldownLeft(m,id)<=0 then if only then kickState.unsure=kickState.unsure+1;return end;only=m end
        end
        if only then Kicked(only,now,"ready")else kickState.unsure=kickState.unsure+1 end
    end
    -- The meter usually reports the same interrupt a moment later.
    if C_Timer and C_Timer.After then C_Timer.After(0.4,decide)else decide()end
end
function ns.PartyCooldownKickStats()return kickState end

local ownDraw
local events=CreateFrame("Frame")
local function Listen(on)
    for _,e in ipairs({"UNIT_SPELLCAST_SUCCEEDED","GROUP_ROSTER_UPDATE","PLAYER_SPECIALIZATION_CHANGED","TRAIT_CONFIG_UPDATED","INSPECT_READY",
        "READY_CHECK","PLAYER_REGEN_ENABLED","ENCOUNTER_END","CHALLENGE_MODE_START","PLAYER_ENTERING_WORLD","UNIT_POWER_UPDATE","SPELL_UPDATE_COOLDOWN","UNIT_AURA",
        "UNIT_SPELLCAST_INTERRUPTED","UNIT_SPELLCAST_CHANNEL_STOP","DAMAGE_METER_COMBAT_SESSION_UPDATED","DAMAGE_METER_CURRENT_SESSION_UPDATED","DAMAGE_METER_RESET",
        "PLAYER_REGEN_DISABLED","NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED"})do
        if on then pcall(events.RegisterEvent,events,e)elseif events.UnregisterEvent then events:UnregisterEvent(e)end
    end
end
function ns.RefreshPartyCooldowns()
    local cfg=ns.PartyCooldownConfig();LoadCustom();Listen(cfg.enabled==true)
    -- Your own record first, then your talents into it.
    if cfg.enabled then ns.PartyCooldownRoster();ReadOwnTalents();QueueInspect();ns.SharePartyCooldowns()end
    ns.RebuildPartyCooldownSensors()
    return ns.DrawPartyCooldowns()
end
events:SetScript("OnEvent",function(_,event,a,_,c,d)
    if event=="UNIT_SPELLCAST_SUCCEEDED"then
        if a=="player"and ns.Plain(c,"number")and KIND[ALIAS[c]or c]=="kick"then ownKickAt=GetTime()end
        if ns.Plain(a,"string")and(a=="player"or a=="target"or a=="focus"or a:match("^party%d")or a:match("^raid%d")or a:match("^nameplate%d"))then ns.PartyCooldownCast(a,c)end
    elseif event=="UNIT_SPELLCAST_INTERRUPTED"then ns.PartyCooldownInterrupted(a,d)
    elseif event=="UNIT_SPELLCAST_CHANNEL_STOP"then
        -- A channel that was stopped by someone names (or hides) who; an ended one names nobody.
        if d~=nil then ns.PartyCooldownInterrupted(a,d)end
    elseif event=="DAMAGE_METER_COMBAT_SESSION_UPDATED"then
        if ns.Plain(a,"number")and Enum and Enum.DamageMeterType and a==Enum.DamageMeterType.Interrupts then ns.PartyCooldownMeter()end
    elseif event=="DAMAGE_METER_CURRENT_SESSION_UPDATED"or event=="DAMAGE_METER_RESET"or event=="PLAYER_REGEN_DISABLED"then ns.PartyCooldownMeter(true)
    elseif event=="NAME_PLATE_UNIT_ADDED"or event=="NAME_PLATE_UNIT_REMOVED"then ns.PartyCooldownPlate(a)
    elseif event=="UNIT_AURA"then ns.PartyCooldownAura(a)
    elseif event=="UNIT_POWER_UPDATE"then
        if ns.Plain(a,"string")then ns.PartyCooldownPower(a)end
    elseif event=="SPELL_UPDATE_COOLDOWN"then
        -- Your own icons follow the game's cooldowns; one redraw for a burst of updates.
        if not ownDraw and C_Timer and C_Timer.NewTimer then ownDraw=C_Timer.NewTimer(0.2,function()ownDraw=nil;ns.DrawPartyCooldowns()end)end
    elseif event=="PLAYER_REGEN_ENABLED"then
        for id in pairs(pendingLearn)do if Learn(id)then pendingLearn[id]=nil end end
        -- A hidden timer started in combat at the latest now: it is surely over one length later.
        local longest=0
        for _,m in pairs(members)do for _,t in pairs(m.hiddenCd or{})do t.over=t.over or GetTime()+t.cd;longest=math.max(longest,t.cd)end end
        if longest>0 then RedrawLater(longest)end
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
        if event=="PLAYER_SPECIALIZATION_CHANGED"and ns.Plain(a,"string")then for _,m in pairs(members)do if m.unit==a and not m.me then m.asked=nil;m.tries=nil;m.talented=nil;m.ranks=nil;m.spec=nil;m.sentSpec=nil;m.known=nil;m.cds=nil end end;QueueInspect()end
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
local DrawAnchors
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
    local tabs={};for _,sp in ipairs(specs)do tabs[#tabs+1]={value=sp,label=L((ns.Catalog.specs[sp]or tostring(sp)):gsub(" "..CLASS_NAMES[d.class].."$",""))}end
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
    -- What is typed is kept when the page is drawn again (a toggle, a tab).
    local field=W.Field(right,L("ADD A SPELL BY ID"),d.newSpell or"",12,450,200,"pcd:newSpell")
    if field and field.HookScript then field:HookScript("OnTextChanged",function(self)d.newSpell=self:GetText()end)end
    W.Button(right,L("Add"),220,466,100,function()local text=ns.UIControls["pcd:newSpell"]:GetText();local ok,err=ns.AddPartyCooldownSpell(d.class,text);if ok then d.newSpell=""else d.newSpell=text end;kit.done(ok,err,L("Spell added"))end,false,"pcd-add",{kind="primary",align="CENTER"})
    W.Button(right,L("All on"),336,466,100,function()for _,id in ipairs(ids)do ns.SetPartyCooldownTracked(id,true,spec)end;kit.refresh()end,false,"pcd-allon",{kind="outline",align="CENTER"})
    W.Button(right,L("All off"),444,466,100,function()for _,id in ipairs(ids)do ns.SetPartyCooldownTracked(id,false,spec)end;kit.refresh()end,false,"pcd-alloff",{kind="outline",align="CENTER"})
    W.Label(right,L("The cooldowns tracked for this spec. Off: not shown and not timed for players of this spec. Lengths are the game's base cooldowns."),12,506,684,11,C.muted)
end
-- Interrupts and crowd control: two movable lists of their own, each set up here.
local ANCHOR_HELP={
    kick="An interrupt is credited by the game's interrupt meter, by the interrupter's name when the game gives it, or to the only member whose interrupt is ready. A kick that misses the cast cannot be seen.",
    cc="Stuns and other crowd control are seen as their debuff on enemy nameplates, so enemy nameplates must be shown. Hammer of Justice is shown only for yourself, because Fist of Justice shortens it.",
}
function DrawAnchors(parent,apply)
    local cfg=ns.PartyCooldownConfig()
    local function list(values,suffix)local out={};for _,v in ipairs(values)do out[#out+1]={value=v,label=v..(suffix or"")}end;return out end
    local sizes,widths,counts=list({16,18,20,22,24,26,30,36,42,48}," px"),list({120,150,180,200,240,280,320}," px"),list({1,2,3,4,5,6,7,8,9,10})
    for i,key in ipairs({"kick","cc"})do
        local a=cfg.anchors[key];local field=key=="kick"and"kicks"or"cc";local id="pcd-"..key..":"
        local bars=a.style=="bars"
        local card=W.Card(parent,(i-1)*466,56,454,484,L(TITLES[key]))
        W.Toggle(card,L("Show"),cfg[field]~=false,12,34,430,function(v)cfg[field]=v;apply()end,"pcd:"..field)
        W.Select(card,L("STYLE"),{{value="icons",label=L("Icons")},{value="bars",label=L("Bars")}},bars and"bars"or"icons",12,70,207,function(v)a.style=v;apply()end,id.."style")
        W.Select(card,bars and L("BAR HEIGHT")or L("ICON SIZE"),sizes,tonumber(a.size)or 30,235,70,207,function(v)a.size=v;apply()end,id.."size")
        W.Select(card,L("HORIZONTAL"),{{value="RIGHT",label=L("To the right")},{value="LEFT",label=L("To the left")}},a.dir or"RIGHT",12,126,207,function(v)a.dir=v;apply()end,id.."dir")
        W.Select(card,L("VERTICAL"),{{value="DOWN",label=L("Down")},{value="UP",label=L("Up")}},a.grow or"DOWN",235,126,207,function(v)a.grow=v;apply()end,id.."grow")
        W.Select(card,L("PER ROW"),counts,tonumber(a.perRow)or 1,12,182,207,function(v)a.perRow=v;apply()end,id.."perRow")
        W.Select(card,L("ROWS"),counts,tonumber(a.rows)or 5,235,182,207,function(v)a.rows=v;apply()end,id.."rows")
        if bars then
            W.Select(card,L("BAR WIDTH"),widths,tonumber(a.width)or 180,12,238,207,function(v)a.width=v;apply()end,id.."width")
            W.Select(card,L("BAR TEXTURE"),ns.PartyBarTextures(),a.texture or"",235,238,207,function(v)a.texture=v;apply()end,id.."texture")
        end
        W.Toggle(card,L("Names"),a.names,12,300,207,function(v)a.names=v;apply()end,id.."names")
        W.Toggle(card,L("Only in use"),a.hideReady,235,300,207,function(v)a.hideReady=v;apply()end,id.."hideReady")
        W.Toggle(card,L("Include my own cooldowns"),a.self~=false,12,328,430,function(v)a.self=v;apply()end,id.."self")
        W.Button(card,L("Reset position"),12,364,430,function()local d=defaults.anchors[key];a.x,a.y=d.x,d.y;apply()end,false,id.."reset",{kind="outline",align="CENTER"})
        W.Label(card,L(ANCHOR_HELP[key]),12,406,430,11,C.muted)
    end
    W.Button(parent,cfg.unlocked and L("Lock")or L("Unlock and preview"),0,552,454,function()cfg.unlocked=not cfg.unlocked;apply()end,false,"pcd-unlock",{kind="outline",align="CENTER"})
    W.Label(parent,L("Unlock shows every list with its name; drag them where you want them."),466,560,454,11,C.muted)
end
local function DrawPage(parent)
    local cfg=ns.PartyCooldownConfig()
    local function apply()ns.RefreshPartyCooldowns();kit.refresh()end
    local d=kit.state.drafts;d.pcd=d.pcd or{view="display"}
    kit.header(parent,L("Party cooldowns"),L("Important defensive, external, raid and burst cooldowns of every specialization, for each party member."))
    W.Segmented(parent,{{value="display",label=L("Display")},{value="anchors",label=L("Kicks & CC")},{value="abilities",label=L("Abilities")}},d.pcd.view,560,0,360,function(v)d.pcd.view=v;kit.refresh()end,"pcd-view")
    if d.pcd.view=="abilities"then return DrawAbilities(parent,d.pcd)end
    if d.pcd.view=="anchors"then return DrawAnchors(parent,apply)end
    local c1=W.Card(parent,0,56,298,566,L("Display"))
    W.Toggle(c1,L("Track party cooldowns"),cfg.enabled,12,34,274,function(v)cfg.enabled=v;apply()end,"pcd:enabled")
    W.Select(c1,L("SHOW"),{{value="list",label=L("As a list")},{value="frames",label=L("Beside party frames")}},cfg.mode,12,70,274,function(v)cfg.mode=v;apply()end,"pcd:mode")
    W.Select(c1,L("SIDE OF THE FRAME"),{{value="RIGHT",label=L("Right")},{value="LEFT",label=L("Left")},{value="TOP",label=L("Above")},{value="BOTTOM",label=L("Below")}},cfg.side,12,126,130,function(v)cfg.side=v;apply()end,"pcd:side")
    local sizes={};for _,s in ipairs({20,24,26,30,36})do sizes[#sizes+1]={value=s,label=s.." px"}end
    W.Select(c1,L("ICON SIZE"),sizes,tonumber(cfg.size)or 26,156,126,130,function(v)cfg.size=v;apply()end,"pcd:size")
    W.Toggle(c1,L("Include my own cooldowns"),cfg.self,12,186,274,function(v)cfg.self=v;apply()end,"pcd:self")
    W.Toggle(c1,L("In raids, track my group"),cfg.raidGroup,12,212,274,function(v)cfg.raidGroup=v;apply()end,"pcd:raid")
    W.Toggle(c1,L("Only in use"),cfg.hideReady,12,238,274,function(v)cfg.hideReady=v;apply()end,"pcd:hideReady")
    W.Toggle(c1,L("Names"),cfg.names,12,264,274,function(v)cfg.names=v;apply()end,"pcd:names")
    W.Toggle(c1,L("Share my cooldowns with the group"),cfg.share,12,290,274,function(v)cfg.share=v;if v then ns.SharePartyCooldowns(true)end;apply()end,"pcd:share")
    W.Toggle(c1,L("Also share my Cooldown Manager ones"),cfg.cdm,12,316,274,function(v)cfg.cdm=v;apply()end,"pcd:cdm")
    W.Toggle(c1,L("Auto 1 min+"),cfg.detect,12,342,274,function(v)cfg.detect=v;apply()end,"pcd:detect")
    W.Toggle(c1,L("Buff sensors"),cfg.sensors,12,368,274,function(v)cfg.sensors=v;apply()end,"pcd:sensors")
    W.Toggle(c1,L("Open world"),cfg.loadWorld~=false,12,394,130,function(v)cfg.loadWorld=v;apply()end,"pcd:loadWorld")
    W.Toggle(c1,L("Solo"),cfg.loadSolo~=false,156,394,130,function(v)cfg.loadSolo=v;apply()end,"pcd:loadSolo")
    W.Button(c1,cfg.unlocked and L("Lock")or L("Unlock and preview"),12,428,274,function()cfg.unlocked=not cfg.unlocked;apply()end,false,"pcd-unlock",{kind="outline",align="CENTER"})
    W.Button(c1,L("Reset timers"),12,466,130,function()ns.PartyCooldownReset();kit.notify(L("All cooldowns are ready again"))end,false,"pcd-reset",{kind="outline",align="CENTER"})
    W.Button(c1,L("Send mine now"),156,466,130,function()kit.done(ns.SharePartyCooldowns(true),L("Turn tracking on, join a group and leave combat first"),L("Your cooldowns were sent to the group"))end,false,"pcd-share",{align="CENTER"})
    W.Label(c1,L("Timers start when a member casts. The game can hide other players' casts in combat; then nothing is guessed. Mythic+ keys and raid encounters start everyone ready."),12,506,274,11,C.muted)
    local c2=W.Card(parent,310,56,610,566,L("Group"))
    if cfg.enabled then ns.PartyCooldownRoster()end
    local names=order;local y=34
    if #names==0 then W.Label(c2,cfg.enabled and L("Nobody to track yet. Join a party.")or L("Turn tracking on to see your group here."),12,y,580,12,C.muted)end
    for i,name in ipairs(names)do if i<=10 then
        local m=members[name];local row=W.Panel(c2,12,y,586,40,C.raised,C.clear,6)
        W.Dot(row,8,15,kit.classColor(m.class));W.Label(row,ns.DisplayName and ns.DisplayName(name)or name,22,6,170,12,kit.classColor(m.class)):SetWordWrap(false)
        local source=m.me and L("You")or m.addon and L("Sent by their addon")or m.talented and L("Talents from inspect")or L("Base cooldowns from the game")
        W.Label(row,(m.spec and ns.Catalog.specs[m.spec]and L(ns.Catalog.specs[m.spec])or L("Specialization unknown")).." · "..source,22,22,170,10,C.muted):SetWordWrap(false)
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
    W.Label(c2,L("Members without this addon show the cooldowns of their specialization at the game's base length; talents that shorten them are not known. Members with the addon send the lengths they have. A ~ on a timer marks an estimate: a guessed start, a base or shortened length, or a timer the game hides."),12,476,586,11,C.muted)
end
ns.ExtraPages.partycds=DrawPage
