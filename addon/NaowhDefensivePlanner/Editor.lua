-- Independent, transactional in-game profile editor. No imported Lua is executed.
local _,ns=...
local serial=0
function ns.Clone(value)
    if type(value)~="table"then return value end
    local out={};for k,v in pairs(value)do out[k]=ns.Clone(v)end;return out
end
local function Integer(v,label,min,max)
    v=tonumber(v);assert(v and v==math.floor(v)and v>=(min or 1)and v<=(max or 100000000),"Enter a valid "..label);return v
end
local function Number(v,label,min,max)
    v=tonumber(v);assert(v and v>=min and v<=max,"Enter "..label.." between "..min.." and "..max);return v
end
local function Name(v)
    assert(type(v)=="string","Enter a name");v=v:match("^%s*(.-)%s*$");assert(#v>0 and #v<=120,"Use a name of 1-120 characters");return v
end
local function OwnSpec(spec)
    assert(ns.CanEditSpec(spec),"This specialization belongs to another class. Log in on that class to edit its sets");return spec
end
local function Editable()
    assert(not(InCombatLockdown and InCombatLockdown()),"Edit profiles after combat")
    assert(not ns.encounter,"Edit profiles after the encounter")
end
function ns.UID(prefix)
    serial=serial+1;return (prefix or"rule").."_"..tostring(GetTime and math.floor(GetTime()*1000)or 0).."_"..serial
end
function ns.ScopePresets(profile,scope,spec)
    local data=profile and profile.data or{}
    local scoped=ns.Get(data.scopePresets,scope)
    return ns.Get(scoped,spec)or ns.Get(data.presets,spec)or{}
end
function ns.ScopeActive(profile,scope,spec)
    local data=profile and profile.data or{}
    return ns.Get(ns.Get(data.scopeActivePreset,scope),spec)or ns.Get(data.activePreset,spec)
end
function ns.ContentScope(entry)
    if entry and entry.defensive and entry.defensive.scope then return entry.defensive.scope end
    if entry and entry.content then return entry.content end
    if entry and entry.trigger and entry.trigger.type=="exboss"then return "mythic"end
    return (ns.instanceType=="raid"or ns.difficulty==15 or ns.difficulty==16)and"raid"or"mythic"
end
function ns.ContentMatches(entry)
    local profile=ns.Active();local filters=profile and profile.data.contentDifficulties
    local selected=ns.ContentScope(entry);local allowed=filters and filters[selected]
    -- Dungeon content runs in any dungeon difficulty, whatever an imported NSR filter says.
    if selected=="mythic"and ns.InDungeon and ns.InDungeon()then allowed=nil end
    if allowed and not ns.Get(allowed,ns.difficulty)then return false end
    return not entry.content or entry.content==ns.ContentScope()
end
local function Prepare(data)
    data.contentDifficulties=data.contentDifficulties or{mythic={[1]=true,[2]=true,[8]=true,[23]=true,[24]=true},raid={[15]=true,[16]=true}}
    data.scopePresets=data.scopePresets or{}
    data.scopeActivePreset=data.scopeActivePreset or{}
    for _,scope in ipairs({"mythic","raid"})do
        -- A one-time independent copy of legacy shared sets; old references stay valid.
        if not data.scopePresets[scope]then data.scopePresets[scope]=ns.Clone(data.presets or{})end
        if not data.scopeActivePreset[scope]then data.scopeActivePreset[scope]=ns.Clone(data.activePreset or{})end
    end
end
local function Changed()
    ns.Reset();if ns.RefreshAuraSounds then ns.RefreshAuraSounds()end
end
function ns.EditProfile(callback)
    local ok,result=pcall(function()
        Editable();local current=assert(ns.Active(),"Create or import a profile first")
        local copy=ns.Clone(current);Prepare(copy.data);local value=callback(copy.data,copy)
        copy.minimumAddon=ns.MinimumAddon(copy.data);assert(ns.Validate(copy),"The change contains unsupported profile data")
        if ns.Encode then local encoded,error=ns.Encode(copy);assert(encoded,error)end
        ns.Store().profiles[ns.Store().active]=copy;Changed();return value
    end)
    if not ok then return nil,tostring(result)end
    return result==nil and true or result
end
function ns.CreateProfile(name,copy)
    local ok,result=pcall(function()
        Editable();name=Name(name);local store=ns.Store();assert(not store.profiles[name],"A profile with this name already exists")
        local p=copy and ns.Clone(assert(ns.Active(),"No profile to copy"))or{format=1,addon="PztkReminders",client=ns.Client(),data={settings={enabled=true,showIcon=true,showText=true,voiceOn=true},presets={},activePreset={},abilityBindings={},integrationRules={},raidReminders={}}}
        p.name=name;p.minimumAddon=ns.MinimumAddon(p.data);Prepare(p.data);store.profiles[name]=p;store.active=name;Changed();return name
    end);if ok then return result end;return nil,tostring(result)
end
function ns.SelectProfile(name)
    local ok,error=pcall(function()Editable();assert(ns.Store().profiles[name],"Profile not found");ns.Store().active=name;Changed()end)
    return ok,not ok and tostring(error)or nil
end
function ns.RenameProfile(name)
    local ok,error=pcall(function()Editable();name=Name(name);local store=ns.Store();assert(ns.Active(),"No active profile");assert(not store.profiles[name],"A profile with this name already exists");local p=ns.Active();local oldName=store.active;store.profiles[oldName]=nil;store.profiles[name]=p;p.name=name;store.active=name
        if store.workspace and store.workspace.profiles then store.workspace.profiles[name]=store.workspace.profiles[oldName];store.workspace.profiles[oldName]=nil end
        Changed()end)
    return ok,not ok and tostring(error)or nil
end
function ns.DeleteProfile()
    local ok,error=pcall(function()Editable();local store=ns.Store();store.profiles[store.active]=nil;if store.workspace and store.workspace.profiles then store.workspace.profiles[store.active]=nil end;store.active=nil;for name in pairs(store.profiles)do if not store.active or name<store.active then store.active=name end end;Changed()end)
    return ok,not ok and tostring(error)or nil
end
function ns.SaveSet(scope,spec,key,name,rows)
    return ns.EditProfile(function(data)
        assert(scope=="mythic"or scope=="raid","Choose content");spec=OwnSpec(Integer(spec,"specialization"));assert(ns.Catalog.specs[spec],"Unknown specialization")
        local sets=ns.Get(data.scopePresets[scope],spec);if not sets then sets={};data.scopePresets[scope][spec]=sets end
        key=key or ns.UID("set");local p={name=Name(name),list={},together={},disabled={}}
        local seen={};assert(#rows>0,"Add at least one defensive ability");assert(#rows<=200,"Use at most 200 abilities in one set")
        for _,row in ipairs(rows)do local spell=Integer(row.spellID,"spell ID");assert(not seen[spell],"This ability is already in the set");seen[spell]=true;p.list[#p.list+1]=spell;if row.together then p.together[spell]=true end;if row.enabled==false then p.disabled[spell]=true end end
        sets[key]=p;if not ns.Get(data.scopeActivePreset[scope],spec)then data.scopeActivePreset[scope][spec]=key end;return key
    end)
end
local function References(data,scope,spec,key)
    local count=0
    for _,b in pairs(ns.Get(data.integrationRules,spec)or{})do if scope=="mythic"and b.preset==key then count=count+1 end end
    for encounter,entries in pairs(data.abilityBindings and ns.Get(data.abilityBindings,spec)or{})do
        local kind=ns.EncounterScope(tonumber(encounter));if kind==scope or not kind then for _,b in pairs(entries)do if b.preset==key then count=count+1 end end end
    end
    for enc,entries in pairs(data.raidReminders or{})do for _,e in pairs(entries)do
        local content=e.content or ns.EncounterScope(tonumber(enc))
        if e.defensive and e.defensive.specID==spec and e.defensive.preset==key and(content==scope or not content)then count=count+1 end
    end end
    return count
end
local function Referenced(data,scope,spec,key)return References(data,scope,spec,key)>0 end
function ns.SetUses(scope,spec,key)
    local p=ns.Active();if not p or not key then return 0 end;return References(p.data,scope,spec,key)
end
-- True when an entry belongs to exactly this specialization: its defensive set, or a lone spec recipient.
local function SpecOwned(entry,spec)
    if entry.defensive then return entry.defensive.specID==spec end
    local t=entry.target;if type(t)~="table"or t.matchAny or t.all then return false end
    for k,v in pairs(t)do if k~="specs"and type(v)=="table"and next(v)then return false end end
    local only=nil;for id,on in pairs(t.specs or{})do if on then if only then return false end;only=tonumber(id)end end
    return only==spec
end
-- Replaces the target specialization's sets and spec-owned reminders with copies of the source's.
function ns.CopySpecSetup(from,to)
    return ns.EditProfile(function(data)
        from=OwnSpec(Integer(from,"specialization"));to=OwnSpec(Integer(to,"specialization"));assert(from~=to,"Choose another specialization")
        assert(ns.Catalog.specs[from]and ns.Catalog.specs[to],"Unknown specialization")
        local function put(t,value)if t then t[tostring(to)]=nil;t[to]=ns.Clone(value)end end
        for _,scope in ipairs({"mythic","raid"})do
            put(data.scopePresets[scope],ns.Get(data.scopePresets[scope],from)or{})
            put(data.scopeActivePreset[scope],ns.Get(data.scopeActivePreset[scope],from))
        end
        data.integrationRules=data.integrationRules or{};put(data.integrationRules,ns.Get(data.integrationRules,from))
        data.abilityBindings=data.abilityBindings or{};put(data.abilityBindings,ns.Get(data.abilityBindings,from))
        for _,entries in pairs(data.raidReminders or{})do
            local copies={}
            for key,e in pairs(entries)do
                if SpecOwned(e,to)then entries[key]=nil
                elseif SpecOwned(e,from)then
                    local c=ns.Clone(e)
                    if c.defensive then c.defensive.specID=to end
                    if c.target and c.target.specs then c.target.specs={[to]=true}end
                    copies[#copies+1]=c
                end
            end
            for _,c in ipairs(copies)do entries[ns.UID("reminder")]=c end
        end
        return to
    end)
end
function ns.DeleteSet(scope,spec,key)
    return ns.EditProfile(function(data)spec=OwnSpec(Integer(spec,"specialization"));assert(key,"Choose a saved set first");assert(not Referenced(data,scope,spec,key),"This set is assigned to mechanics. Reassign them first.");local sets=ns.Get(data.scopePresets[scope],spec)or{};sets[key]=nil;if ns.Get(data.scopeActivePreset[scope],spec)==key then data.scopeActivePreset[scope][spec]=nil end end)
end
function ns.EncounterScope(encounter)
    for _,d in ipairs(ns.Catalog.dungeons)do for _,n in ipairs(d.npcs)do if n.encounterId==encounter then return "mythic"end end end
    for _,r in ipairs(ns.Catalog.raids)do for _,b in ipairs(r.bosses)do if b.id==encounter then return "raid"end end end
end
function ns.CatalogGroups(scope)
    local out=ns.Client()=="retail"and ns.Clone(scope=="mythic"and ns.Catalog.dungeons or ns.Catalog.raids)or{}
    local p=ns.Active();local manual=p and p.data.manualCatalog and p.data.manualCatalog[scope]or{}
    for _,g in ipairs(manual)do out[#out+1]=ns.Clone(g)end
    -- Imported encounters without a bundled reference remain editable.
    local known={};for _,g in ipairs(out)do for _,n in ipairs(g.npcs or g.bosses or{})do if n.encounterId or scope=="raid"then known[n.encounterId or n.id]=true end end end
    local extra={id="imported",name="Imported encounters",npcs={},bosses={}}
    local ids={};local data=p and p.data or{}
    for _,es in pairs(data.abilityBindings or{})do for enc in pairs(es)do ids[tonumber(enc)]=true end end
    for enc in pairs(data.raidReminders or{})do ids[tonumber(enc)]=true end
    for enc in pairs(ids)do if enc and not known[enc]and(not ns.EncounterScope(enc)or ns.EncounterScope(enc)==scope)then
        local n={id=enc,encounterId=enc,name="Encounter "..enc,kind="boss",abilities={}}
        local seen={};local function add(spell)if spell and not seen[spell]then seen[spell]=true;n.abilities[#n.abilities+1]={id=spell}end end
        for _,es in pairs(data.abilityBindings or{})do for spell in pairs(ns.Get(es,enc)or{})do add(tonumber(spell))end end
        for _,e in pairs(ns.Get(data.raidReminders,enc)or{})do add(e.trigger and e.trigger.spellID)end
        local list=scope=="mythic"and extra.npcs or extra.bosses;list[#list+1]=n
    end end
    if #(scope=="mythic"and extra.npcs or extra.bosses)>0 then out[#out+1]=extra end
    return out
end
function ns.AddManualMechanic(args)
    return ns.EditProfile(function(data)
        local scope=args.scope;assert(scope=="mythic"or scope=="raid","Choose content");local groupName=Name(args.groupName);local npcName=Name(args.npcName)
        local encounter=args.kind=="trash"and nil or Integer(args.encounterId,"encounter ID")
        local map=scope=="mythic"and Integer(args.mapID,"instance map ID")or nil
        local npc=Integer(args.npcID or encounter,"NPC ID");local spell=Integer(args.spellID,"mechanic spell ID")
        data.manualCatalog=data.manualCatalog or{};data.manualCatalog[scope]=data.manualCatalog[scope]or{}
        local groups=data.manualCatalog[scope];local group
        for _,g in ipairs(groups)do if g.name==groupName and g.mapID==map then group=g end end
        if not group then group={id=ns.UID("group"),mapID=map,name=groupName,npcs={},bosses={}};groups[#groups+1]=group end
        local list=scope=="mythic"and group.npcs or group.bosses;local entity
        for _,n in ipairs(list)do if n.id==npc then entity=n end end
        if not entity then entity={id=scope=="raid"and encounter or npc,encounterId=encounter,name=npcName,kind=args.kind or"boss",abilities={}};list[#list+1]=entity end
        for _,a in ipairs(entity.abilities)do assert(a.id~=spell,"This mechanic already exists")end
        entity.abilities[#entity.abilities+1]={id=spell,name=args.spellName~=""and args.spellName or nil};return group.id
    end)
end
function ns.RuleOptions(ctx)
    local data=ns.Active()and ns.Active().data or{};local rows={}
    if ctx.kind=="trash"then
        for key,e in pairs(ns.Get(data.integrationRules,ctx.spec)or{})do local t=e.trigger or{};if t.type=="exboss"and t.spellID==ctx.spell and(t.mapID==ctx.map or t.mapID==0)then rows[#rows+1]={key=key,section="integrationRules",entry=ns.Clone(e)}end end
    else
        local enc=ctx.encounter
        for key,e in pairs(ns.Get(data.raidReminders,enc)or{})do
            if (not e.content or e.content==ctx.scope)and(not e.difficulties or not next(e.difficulties)or ns.Get(e.difficulties,ctx.difficulty))and(not ctx.spell or e.trigger.spellID==ctx.spell)then
                if not e.defensive or e.defensive.specID==ctx.spec then rows[#rows+1]={key=key,section="raidReminders",entry=ns.Clone(e)}end
            end
        end
        if ctx.spell then local b=ns.Get(ns.Get(ns.Get(data.abilityBindings,ctx.spec),enc),ctx.spell);if b then rows[#rows+1]={key=ctx.spell,section="abilityBindings",entry=ns.Clone(b)}end end
    end
    table.sort(rows,function(a,b)return tostring(a.entry.name or a.key)<tostring(b.entry.name or b.key)end);return rows
end
function ns.ParseCounter(text)
    if not text or text:match("^%s*$")then return nil end
    assert(#text<=200,"Counter expression is too long");local groups={}
    for token in (text..","):gmatch("(.-),")do
        local andFlag,op,value=token:match("^%s*(%+?)([<>!=]*)(%-?%d+)%s*$")
        assert(value,"Use counters such as 2,4 or >1");if op==""then op="="end
        assert(({["="]=true,["!"]=true,[">"]=true,["<"]=true,[">="]=true,["<="]=true})[op],"Unsupported counter operator")
        value=Number(value,"counter",0,1000000);if andFlag~="+"or #groups==0 then groups[#groups+1]={}end
        local g=groups[#groups];g[#g+1]={op=op,value=value}
    end
    return groups
end
function ns.CounterText(groups)
    local parts={};for _,g in ipairs(groups or{})do for i,p in ipairs(g)do parts[#parts+1]=(i>1 and"+"or"")..(p.op=="="and""or p.op)..p.value end end;return table.concat(parts,",")
end
function ns.SaveRule(ctx,form,reference)
    return ns.EditProfile(function(data)
        local scope=ctx.scope;assert(scope=="mythic"or scope=="raid","Choose content");local spec=OwnSpec(Integer(ctx.spec,"specialization"))
        local sets=ns.Get(data.scopePresets[scope],spec)or{};local dynamic=form.action=="defensive"
        if dynamic then assert(sets[form.preset],"Create or choose a defensive set for this content and specialization")end
        local duration=Number(form.duration or 4,"duration",0.1,120);local lead=Number(form.leadTime or 2,"lead time",0,120)
        local display={type=dynamic and"icon"or(form.action or"text"),text=tostring(form.text or""),dur=duration,sound=tostring(form.sound or""),tts=form.tts==true}
        if display.type=="icon"and not dynamic then display.spellID=Integer(form.displaySpellID,"display spell ID")end
        if display.type=="raidframeGlow"then display.glowTarget=Name(form.glowTarget)end
        -- Extra raid-frame glows (NSRT glowunit) have no in-game field yet; keep them across edits.
        local previous=reference and reference.section=="raidReminders"and type(reference.entry.display)=="table"and reference.entry.display
        if previous and display.type~="raidframeGlow"then display.glowTargets=ns.Clone(previous.glowTargets);display.glowColor=ns.Clone(previous.glowColor)end
        local key=reference and reference.section~="abilityBindings"and reference.key or ns.UID("reminder")
        if ctx.kind=="trash"then
            assert(dynamic,"Trash timer reminders use a defensive set");local map=Integer(ctx.map,"instance map ID");local spell=Integer(ctx.spell,"mechanic spell ID")
            data.integrationRules=data.integrationRules or{};data.integrationRules[spec]=ns.Get(data.integrationRules,spec)or{}
            local old=reference and reference.entry or{}
            local e=ns.Clone(old);e.name=Name(form.name);e.enabled=form.enabled~=false;e.content="mythic";e.preset=form.preset;e.display=display;e.difficulties={[8]=true};e.trigger={type="exboss",mapID=map,spellID=spell,timeleft=lead};e.catalog={npcID=ctx.npc,groupId=ctx.group}
            data.integrationRules[spec][key]=e
        else
            local encounter=Integer(ctx.encounter,"encounter ID");local triggerType=form.trigger or"bwtimer";assert(({pull=true,prepull=true,stage=true,bwtimer=true,bwmsg=true})[triggerType],"Choose a trigger")
            if scope=="mythic"then assert(triggerType=="bwtimer"or triggerType=="bwmsg","M+ reminders bind to a mechanic")end
            local trigger={type=triggerType,leadTime=lead,delay=triggerType=="prepull"and Number(form.delay,"seconds before pull",0.1,3600)or Number(form.delay or 0,"delay",0,7200),counterGroups=ns.ParseCounter(form.counter)}
            if triggerType=="stage"then trigger.stage=Number(form.phase or 1,"phase",1,100)end
            if triggerType=="bwtimer"or triggerType=="bwmsg"then trigger.spellID=Integer(ctx.spell,"mechanic spell ID")end
            local target
            if dynamic or form.recipient=="spec"then target={specs={[spec]=true}}
            elseif form.recipient=="role"then assert(({TANK=true,HEALER=true,DAMAGER=true})[form.role],"Choose a role");target={roles={[form.role]=true}}
            elseif form.recipient=="player"then target={names={[Name(form.player)]=true}}
            elseif form.recipient=="preserve"then target=reference and ns.Clone(reference.entry.target);assert(target,"No imported recipient filter")
            else target={all=true}end
            local diff=scope=="mythic"and 8 or Integer(ctx.difficulty,"raid difficulty");assert(diff==8 or diff==15 or diff==16,"Choose Mythic+, Heroic or Mythic")
            local entry=ns.Clone(reference and reference.section=="raidReminders"and reference.entry or{});entry.name=Name(form.name);entry.enabled=form.enabled~=false;entry.content=scope;entry.trigger=trigger;entry.target=target;entry.display=display
            entry.difficulties=form.preserveDifficulties and entry.difficulties or{[diff]=true}
            entry.defensive=dynamic and{specID=spec,preset=form.preset,scope=scope}or nil;entry.catalog={npcID=ctx.npc,groupId=ctx.group,abilityID=ctx.spell}
            data.raidReminders=data.raidReminders or{};data.raidReminders[encounter]=ns.Get(data.raidReminders,encounter)or{};data.raidReminders[encounter][key]=entry
            if reference and reference.section=="abilityBindings"then ns.Get(ns.Get(data.abilityBindings,spec),encounter)[ctx.spell]=nil end
        end
        return key
    end)
end
function ns.DeleteRule(ctx,reference)
    return ns.EditProfile(function(data)
        assert(reference,"Select a reminder");OwnSpec(ctx.spec)
        if reference.section=="integrationRules"then ns.Get(data.integrationRules,ctx.spec)[reference.key]=nil
        elseif reference.section=="abilityBindings"then ns.Get(ns.Get(data.abilityBindings,ctx.spec),ctx.encounter)[reference.key]=nil
        else local entry=ns.Get(data.raidReminders,ctx.encounter)[reference.key];local diff=ctx.scope=="mythic"and 8 or ctx.difficulty
            if entry.difficulties and ns.Get(entry.difficulties,diff)and next(entry.difficulties)then
                entry.difficulties[diff]=nil;entry.difficulties[tostring(diff)]=nil;if not next(entry.difficulties)then ns.Get(data.raidReminders,ctx.encounter)[reference.key]=nil end
            else ns.Get(data.raidReminders,ctx.encounter)[reference.key]=nil end
        end
    end)
end
-- One ability's call-out: text on screen, spoken phrase or a sound, and its voice switch.
function ns.SaveCallout(spell,form)
    return ns.EditProfile(function(data)
        spell=Integer(spell,"spell ID");data.callouts=data.callouts or{};data.calloutOptions=data.calloutOptions or{}
        local label=tostring(form.label or""):match("^%s*(.-)%s*$");local spoken=tostring(form.spoken or""):match("^%s*(.-)%s*$")
        assert(#label<=200 and #spoken<=200,"Use at most 200 characters")
        local o={label=label~=""and label or nil};if form.audio==false then o.audio=false end
        if form.speak==false then
            assert(ns.SoundPath(form.sound),"Choose a sound, or turn Speak text back on");o.speak=false;o.sound=form.sound
        end
        data.callouts[spell]=nil;data.callouts[tostring(spell)]=nil
        if form.speak~=false and spoken~=""then data.callouts[spell]=spoken end
        data.calloutOptions[spell]=nil;data.calloutOptions[tostring(spell)]=nil
        if next(o)then data.calloutOptions[spell]=o end
        return spell
    end)
end
-- The fallback step: its phrase, voice and the EXTERNAL! chat line.
function ns.SaveExternalCallout(form)
    return ns.EditProfile(function(data)
        local text=tostring(form.text or""):match("^%s*(.-)%s*$");assert(#text<=200,"Use at most 200 characters")
        data.voiceNone=text~=""and text or nil;data.settings=data.settings or{}
        if form.on~=nil then data.settings.fallbackOn=form.on==true end
        if form.audio~=nil then data.settings.externalAudio=form.audio==true end
        if form.chat~=nil then data.settings.externalChat=form.chat==true end
        return true
    end)
end
---------------------------------------------------------------------------
-- Debuff alerts: a sound or racial voice when an aura is applied, stacks or falls off.
local auraEvents={Added=true,ApplicationsIncreased=true,Removed=true}
function ns.DebuffRules(spec)
    local data=ns.Active()and ns.Active().data or{};local out={}
    for key,rule in pairs(ns.Get(data.integrationRules,spec)or{})do if rule.trigger and rule.trigger.type=="auraSound"then out[#out+1]={key=key,rule=ns.Clone(rule)}end end
    table.sort(out,function(a,b)return tostring(a.rule.name or"")<tostring(b.rule.name or"")end);return out
end
function ns.SaveDebuffRule(spec,key,form)
    return ns.EditProfile(function(data)
        spec=OwnSpec(Integer(spec,"specialization"))
        local spell=Integer(form.spellID,"debuff spell ID");local map=Integer(form.mapID or 0,"instance ID",0)
        assert(auraEvents[form.event],"Choose when the sound plays");assert(form.unit=="player"or form.unit=="party","Choose whose debuff to watch")
        assert(ns.SoundPath(form.sound),"Choose a sound")
        if (form.sound=="voice:stoneform-ready"or form.sound=="voice:shadowmeld-ready")then assert(form.unit=="player","Racial voices need Unit: Me")end
        data.integrationRules=data.integrationRules or{};data.integrationRules[spec]=ns.Get(data.integrationRules,spec)or{}
        key=key or ns.UID("debuff")
        local name=tostring(form.name or""):match("^%s*(.-)%s*$");if name==""then name=(ns.SpellLabel and ns.SpellLabel(spell))or("Debuff "..spell)end
        local scope=form.scope=="raid"and"raid"or nil
        data.integrationRules[spec][key]={name=Name(name),enabled=form.enabled~=false,trigger={type="auraSound",mapID=map,spellID=spell,auraEvent=form.event,target=form.unit,scope=scope},display={sound=form.sound}}
        return key
    end)
end
function ns.SetDebuffEnabled(spec,key,on)
    return ns.EditProfile(function(data)spec=OwnSpec(Integer(spec,"specialization"));local rule=assert(ns.Get(ns.Get(data.integrationRules,spec),key),"Debuff alert not found");rule.enabled=on==true;return key end)
end
function ns.DeleteDebuffRule(spec,key)
    return ns.EditProfile(function(data)spec=OwnSpec(Integer(spec,"specialization"));local rules=ns.Get(data.integrationRules,spec);assert(rules and ns.Get(rules,key),"Debuff alert not found");rules[key]=nil;return true end)
end
-- Adds the bundled racial list (Stoneform / Shadowmeld) of the season dungeons, or of the raid
-- with scope "raid". Debuffs already watched on the same instance are kept.
function ns.AddRacialDebuffs(spec,racial,scope)
    return ns.EditProfile(function(data)
        spec=OwnSpec(Integer(spec,"specialization"));local voice=assert(({stoneform="voice:stoneform-ready",shadowmeld="voice:shadowmeld-ready"})[racial],"Choose a racial")
        data.integrationRules=data.integrationRules or{};data.integrationRules[spec]=ns.Get(data.integrationRules,spec)or{}
        local rules=data.integrationRules[spec];local have={};local added=0
        for _,r in pairs(rules)do local t=r.trigger or{};if t.type=="auraSound"then have[t.mapID..":"..t.spellID]=true end end
        local raid=scope=="raid"
        for _,d in ipairs((raid and ns.RaidRacialDebuffs or ns.RacialDebuffs)or{})do for _,e in ipairs(d.list)do
            local map=raid and 0 or d.mapID
            if e[3]==racial and not have[map..":"..e[1]]then
                have[map..":"..e[1]]=true
                rules[ns.UID("debuff")]={name=e[2],enabled=true,trigger={type="auraSound",mapID=map,spellID=e[1],auraEvent="Added",target="player",scope=raid and"raid"or nil},display={sound=voice}};added=added+1
            end
        end end
        return added
    end)
end
-- Additive copy of debuff alerts from another specialization of the same class.
function ns.CopyDebuffRules(from,to)
    return ns.EditProfile(function(data)
        from=OwnSpec(Integer(from,"specialization"));to=OwnSpec(Integer(to,"specialization"));assert(from~=to,"Choose another specialization")
        data.integrationRules=data.integrationRules or{};data.integrationRules[to]=ns.Get(data.integrationRules,to)or{}
        local have={};for _,r in pairs(data.integrationRules[to])do local t=r.trigger or{};if t.type=="auraSound"then have[t.mapID..":"..t.spellID..":"..t.auraEvent]=true end end
        local added=0
        for _,r in pairs(ns.Get(data.integrationRules,from)or{})do local t=r.trigger or{}
            if t.type=="auraSound"and not have[t.mapID..":"..t.spellID..":"..t.auraEvent]then data.integrationRules[to][ns.UID("debuff")]=ns.Clone(r);added=added+1 end
        end
        return added
    end)
end
-- On/off switch for any saved reminder, from the Boss alerts list. Turning off keeps every setting.
function ns.SetReminderEnabled(section,spec,encounter,key,on)
    return ns.EditProfile(function(data)
        local entry
        if section=="raidReminders"then entry=ns.Get(ns.Get(data.raidReminders,encounter),key)
            if entry and entry.defensive then OwnSpec(entry.defensive.specID)end
        elseif section=="abilityBindings"then entry=ns.Get(ns.Get(ns.Get(data.abilityBindings,OwnSpec(spec)),encounter),key)
        else entry=ns.Get(ns.Get(data.integrationRules,OwnSpec(spec)),key)end
        assert(entry,"Reminder not found");entry.enabled=on==true;return key
    end)
end
