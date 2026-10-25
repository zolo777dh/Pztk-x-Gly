-- Debuff alerts page: a sound or racial voice when a debuff is applied, stacks or falls off.
-- The game plays the sounds (C_UnitAuras.AddAuraSound, see AuraSounds.lua); this file only edits rules.
local _,ns=...
local W=ns.Widgets
local C=W.colors
local L=ns.L
local kit=ns.UIKit

-- Season dungeon debuffs a racial can clear: Stoneform (Dwarf) removes poison, disease, curse,
-- magic and bleed effects; Shadowmeld (Night Elf) drops the ones that follow a target.
-- Aura IDs come from the LittleWigs references in resources/npc-catalog.json.
ns.RacialDebuffs={
    {mapID=2993,name="Altar of Fangs",list={{1294567,"Paralyzing Shots","stoneform"},{1289426,"Envenom","stoneform"}}},
    {mapID=2825,name="Den of Nalorakk",list={{1235548,"Glacial Torment","stoneform"},{1238439,"Razor Dive","stoneform"},{1238801,"Insatiable Hunger","stoneform"},{1239860,"Cryo Surge","stoneform"}}},
    {mapID=1762,name="Kings' Rest",list={{1303488,"Savage Maul","stoneform"},{1306763,"Serpent Strike","stoneform"},{1297918,"Mortal Bleed","stoneform"},{1297781,"Sudden Rupture","stoneform"},{267763,"Wretched Discharge","stoneform"},{1301851,"Bloodthirsty Axe","stoneform"},{269972,"Hex Volley","stoneform"},{267618,"Drain Fluids","shadowmeld"},{266231,"Severing Axe","stoneform"},{266206,"Whirling Axes","stoneform"}}},
    {mapID=2813,name="Murder Row",list={{1217633,"Corroding Spittle","stoneform"},{1216590,"Heartstop Poison","stoneform"},{1218347,"Murder in a Row","stoneform"},{1216300,"Cutpurse","stoneform"},{1295035,"Glaive Toss","stoneform"},{1311136,"Sharp Nail","stoneform"},{1295427,"Flay","stoneform"}}},
    {mapID=2521,name="Ruby Life Pools",list={{1306366,"Lightning Torrent","shadowmeld"}}},
    {mapID=1877,name="Temple of Sethraliss",list={{1291399,"Serrated Charge","stoneform"},{1308113,"Arrow Barrage","shadowmeld"},{1308148,"Cytotoxin","stoneform"}}},
    {mapID=2859,name="The Blinding Vale",list={{1235640,"Thornblade","stoneform"},{1259365,"Bloodthorn Roots","stoneform"},{1241058,"Grievous Thrash","stoneform"},{1247685,"Thornspike","stoneform"},{1238066,"Thornblade (trash)","stoneform"},{1242135,"Grievous Gash","stoneform"},{1250937,"Toxic Spew","stoneform"}}},
    {mapID=2923,name="Voidscar Arena",list={{1267894,"Savage Leap","stoneform"},{1299133,"Ferocious Leap","stoneform"},{1250043,"Melt Armor","stoneform"},{1249238,"Fire Spit","stoneform"},{1289258,"Corrosive Essence","stoneform"},{1311778,"Rip and Slice","stoneform"},{1300138,"Void Beam","shadowmeld"}}},
}
-- Raid boss debuffs for Stoneform come from the game's Encounter Journal (Journal.lua): the
-- abilities it marks as magic, curse, poison, disease or bleed, grouped by boss. Empty until
-- the journal has been read (the window reads it out of combat).
local stoneformFlags={[7]=true,[8]=true,[9]=true,[10]=true,[13]=true}
function ns.RaidRacialDebuffs()
    local out={}
    for _,g in ipairs((ns.Journal()or{}).raids or{})do for _,b in ipairs(g.bosses or{})do
        local list={}
        for _,a in ipairs(b.abilities or{})do local hit=false;for _,f in ipairs(a.flags or{})do if stoneformFlags[f]then hit=true end end
            if hit then list[#list+1]={a.id,a.name or("Spell "..a.id),"stoneform"}end end
        if #list>0 then out[#out+1]={encounterID=b.id,name=b.name,list=list}end
    end end
    return out
end
local racialSpell={stoneform=20594,shadowmeld=58984}
-- The game plays debuff alerts itself and needs a sound file, so these are game sounds
-- (Display.lua), not speech.
local sounds={{value="voice:stoneform-ready",label="Stoneform alert (only when ready)"},{value="voice:shadowmeld-ready",label="Shadowmeld alert (only when ready)"},{value="voice:use-a-defensive",label="Encounter warning: medium"},{value="voice:move-out",label="Encounter warning: high"},{value="voice:dispel-me",label="Encounter warning: low"},{value="sound:567397",label="Raid warning"}}
local events={{value="Added",label="Applied"},{value="ApplicationsIncreased",label="Stack increased"},{value="Removed",label="Removed"}}
local units={{value="player",label="Me"},{value="party",label="Party members"}}
local previews={["voice:stoneform-ready"]="voice:stoneform-preview",["voice:shadowmeld-ready"]="voice:shadowmeld-preview"}

local function instanceName(map)
    map=tonumber(map)or 0;if map==0 then return L("All instances")end
    for _,d in ipairs(ns.Catalog.dungeons or{})do if d.mapID==map then return d.name end end
    for _,d in ipairs(ns.RacialDebuffs)do if d.mapID==map then return d.name end end
    return L("Instance").." "..map
end
-- Raid alerts are grouped by the boss that casts the debuff.
local function raidBoss(spell)
    for _,d in ipairs(ns.RaidRacialDebuffs())do for _,e in ipairs(d.list)do if e[1]==spell then return d.name end end end
    for _,g in ipairs(ns.RaidGroups())do for _,b in ipairs(g.bosses or{})do for _,a in ipairs(b.abilities or{})do if a.id==spell then return b.name end end end end
    return L("Other raid debuffs")
end
local function count(list,racial)local n=0;for _,d in ipairs(list)do for _,e in ipairs(d.list)do if e[3]==racial then n=n+1 end end end;return n end
local function known(spell)
    local fn=C_SpellBook and(C_SpellBook.IsSpellKnownOrInSpellBook or C_SpellBook.IsSpellKnown)or IsPlayerSpell
    if not fn then return false end;local ok,v=pcall(fn,spell);return ok and v==true
end
local function blank(map)return{name="",spellID="",mapID=tostring(map or 0),map=map or 0,event="Added",unit="player",sound="voice:use-a-defensive",enabled=true}end
local function formFrom(rule)
    local t=rule.trigger or{};local map=tonumber(t.mapID)or 0;local listed=map==0
    for _,d in ipairs(ns.Catalog.dungeons or{})do if d.mapID==map then listed=true end end
    return{name=rule.name or"",spellID=tostring(t.spellID or""),mapID=tostring(map),map=listed and map or"other",event=t.auraEvent or"Added",unit=t.target or"player",sound=rule.display and rule.display.sound or"voice:use-a-defensive",enabled=rule.enabled~=false}
end

-- Mythic+ and Raids each show their own alerts: raid ones carry trigger.scope "raid".
local function scoped(spec,raid)
    local out={};for _,r in ipairs(ns.DebuffRules(spec))do if(r.rule.trigger.scope=="raid")==raid then out[#out+1]=r end end;return out
end
function ns.DrawDebuffs(parent)
    local state=kit.state;local spec=state.spec;local raid=state.tab=="raid";local scope=raid and"raid"or nil
    kit.header(parent,raid and L("Raid debuffs")or L("Dungeon debuffs"),L("A sound or racial voice when a debuff is applied, stacks or falls off."))
    kit.modeSwitch(parent)
    local status=ns.AuraSoundStatus and ns.AuraSoundStatus()or"";W.Label(parent,(status:match("^[^\n]*")or"")..L(" · changes apply outside combat"),0,46,500,11,C.faint)
    local rules=scoped(spec,raid)
    -- Bundled racial lists and an additive copy from the other specs of this class.
    local source=raid and ns.RaidRacialDebuffs()or ns.RacialDebuffs;local racials={}
    for _,r in ipairs({"stoneform","shadowmeld"})do local n=count(source,r);if n>0 then racials[#racials+1]={value=r,label=L(r=="stoneform"and"Add Stoneform list"or"Add Shadowmeld list").." ("..n..")"..(known(racialSpell[r])and""or" - "..L("not your racial"))}end end
    W.Select(parent,nil,racials,nil,520,40,200,function(v)
        local added,err=ns.AddRacialDebuffs(spec,v,scope);kit.done(added,err,(tonumber(added)or 0)..L(" debuff alerts added"))end,"debuffs-racial")
    ns.UIControls["debuffs-racial"].label:SetText(L("Add racial debuffs..."))
    local copy={};for _,id in ipairs(ns.OwnSpecs())do if id~=spec and #ns.DebuffRules(id)>0 then copy[#copy+1]={value=id,label=ns.Catalog.specs[id].." ("..#ns.DebuffRules(id)..")"}end end
    if #copy>0 then W.Select(parent,nil,copy,nil,730,40,190,function(v)local added,err=ns.CopyDebuffRules(v,spec);kit.done(added,err,(tonumber(added)or 0)..L(" debuff alerts copied"))end,"debuffs-copy");ns.UIControls["debuffs-copy"].label:SetText(L("Copy from spec..."))end
    -- Saved alerts grouped by dungeon (or raid boss); a group header folds its rows.
    local groups,order={},{}
    for _,r in ipairs(rules)do local g=raid and raidBoss(r.rule.trigger.spellID)or instanceName(r.rule.trigger.mapID);if not groups[g]then groups[g]={};order[#order+1]=g end;table.insert(groups[g],r)end
    table.sort(order)
    state.drafts.folded=state.drafts.folded or{}
    local list=W.Scroll(parent,0,80,300,464,"debuffs:list");local y=4
    if #rules==0 then W.Label(list,L("No debuff alerts for this specialization yet. Add the racial list above or create one."),10,10,260,12,C.muted)end
    local selected=state.drafts.debuffKey
    for _,group in ipairs(order)do
        local folded=state.drafts.folded[group]
        W.Button(list,(folded and"+ "or"- ")..group.."  ("..#groups[group]..")",0,y,272,function()state.drafts.folded[group]=not folded or nil;kit.refresh()end,false,"debuff-group:"..group,{kind="ghost",h=26});y=y+28
        if not folded then for _,r in ipairs(groups[group])do
            local row=W.Panel(list,6,y,266,28,r.key==selected and C.accentSoft or C.raised,r.key==selected and C.accent or C.clear,6)
            W.Toggle(row,"",r.rule.enabled~=false,4,2,34,function(v)kit.done(ns.SetDebuffEnabled(spec,r.key,v),nil,v and L("Debuff alert on")or L("Debuff alert off"))end,"debuff-on:"..r.key)
            local sound=r.rule.display and r.rule.display.sound or"";local racial=sound:match("^voice:(%a+)%-ready$")
            W.Button(row,r.rule.name..(racial and(" - "..racial:sub(1,1):upper()..racial:sub(2))or""),42,1,222,function()state.drafts.debuffKey=r.key;state.drafts.debuff=formFrom(r.rule);kit.refresh()end,r.key==selected,"debuff:"..r.key,{kind="ghost",h=26,icon=r.rule.trigger.spellID})
            y=y+30
        end end
    end
    list:SetHeight(math.max(1,y+4))
    W.Button(parent,L("+ Debuff alert"),0,552,300,function()state.drafts.debuffKey=nil;state.drafts.debuff=blank();kit.refresh()end,false,"debuff-new",{kind="outline",align="CENTER"})
    -- Editor of the selected or new alert. Save writes it; the list switch saves at once.
    local f=state.drafts.debuff
    if selected and not f then for _,r in ipairs(rules)do if r.key==selected then f=formFrom(r.rule)end end end
    if not f then f=blank()end;state.drafts.debuff=f
    local exists=false;for _,r in ipairs(rules)do if r.key==selected then exists=true end end
    if not exists then selected=nil;state.drafts.debuffKey=nil end
    local card=W.Card(parent,312,80,608,504,selected and L("Debuff settings")or L("New debuff alert"))
    local function collect()for _,k in ipairs({"name","spellID","mapID"})do local c=ns.UIControls["debuff:"..k];if c then f[k]=c:GetText()end end end
    W.Toggle(card,L("Enabled"),f.enabled,456,8,140,function(v)f.enabled=v end,"debuff:enabled")
    W.Field(card,L("DEBUFF SPELL ID (THE AURA, NOT THE CAST)"),f.spellID,16,40,280,"debuff:spellID")
    local spell=tonumber(f.spellID);if spell then W.Icon(card,spell,308,58,26);W.Label(card,ns.SpellLabel(spell),340,64,250,12,C.soft)end
    W.Field(card,L("REMINDER NAME · BLANK = SPELL NAME"),f.name,16,100,576,"debuff:name")
    local maps={{value=0,label=L("All instances")}};if not raid then for _,d in ipairs(ns.Catalog.dungeons or{})do maps[#maps+1]={value=d.mapID,label=d.name}end end;maps[#maps+1]={value="other",label=L("Another instance (by ID)")}
    W.Select(card,raid and L("INSTANCE")or L("DUNGEON"),maps,f.map,16,160,280,function(v)collect();f.map=v;if v~="other"then f.mapID=tostring(v)end;kit.refresh()end,"debuff:map")
    if f.map=="other"then W.Field(card,L("INSTANCE ID · 0 = EVERYWHERE"),f.mapID,312,160,280,"debuff:mapID")end
    W.Select(card,L("WHEN"),events,f.event,16,220,280,function(v)collect();f.event=v;kit.refresh()end,"debuff:event")
    W.Select(card,L("UNIT"),units,f.unit,312,220,280,function(v)collect();f.unit=v;if v~="player"and previews[f.sound]then f.sound="voice:use-a-defensive"end;kit.refresh()end,"debuff:unit")
    local options={};for _,o in ipairs(sounds)do if f.unit=="player"or not previews[o.value]then options[#options+1]=o end end
    W.Select(card,L("SOUND"),options,f.sound,16,280,576,function(v)collect();f.sound=v;kit.refresh()end,"debuff:sound")
    W.Label(card,L("The game plays debuff alerts itself and allows only sounds here, not speech. Stoneform and Shadowmeld alerts play only while the racial is ready and need Unit: Me; Test plays them anyway."),16,342,576,11,C.muted)
    if raid then W.Label(card,L("The raid list is picked from the debuff names; dispel types and aura IDs are not confirmed yet, so check each alert in game."),16,372,576,11,C.warning)end
    W.Button(card,L("Test"),16,470,100,function()collect();local path=ns.SoundPath(previews[f.sound]or f.sound);if path and PlaySoundFile then pcall(PlaySoundFile,path,"Master")end;kit.notify(L("Sound preview; the real alert needs the debuff in game"))end,false,"debuff-test",{glyph="play"})
    if selected then W.Button(card,L("Remove"),124,470,110,function()local ok,err=ns.DeleteDebuffRule(spec,selected);if ok then state.drafts.debuffKey=nil;state.drafts.debuff=nil end;kit.done(ok,err,L("Debuff alert removed"))end,false,"debuff-delete",{kind="danger",align="CENTER"})end
    W.Button(card,L("Save debuff alert"),412,470,180,function()collect()
        local form={name=f.name,spellID=f.spellID,mapID=f.map=="other"and f.mapID or f.map,event=f.event,unit=f.unit,sound=f.sound,enabled=f.enabled,scope=scope}
        local key,err=ns.SaveDebuffRule(spec,selected,form);if key then state.drafts.debuffKey=key;state.drafts.debuff=nil end;kit.done(key,err,L("Debuff alert saved"))end,true,"debuff-save",{kind="primary",align="CENTER"})
end

