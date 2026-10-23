-- In-game workspace laid out like the design mockup: top bar, grouped sidebar, cards.
-- Separate Mythic+ / raid sets, mechanics and timed reminders for the current specialization.
local _,ns=...
local W=ns.Widgets
local C=W.colors
local L=ns.L
local state={tab="mythic",mode="mechanics",difficulty=15,filter="",setRows={},form={}}
ns.UIState=state
local window,body,header,status
local Refresh
local WIDTH,HEIGHT,SIDEBAR,TOP=1120,720,176,60
-- UI drafts are local SavedVariables, separate from the active runtime profile.
-- Navigation never commits a partial reminder or silently throws its inputs away.
local workspace,owner,profileName
local viewFields={"mode","difficulty","group","entity","ability","ruleKey","timed","form","reference","context","ruleDrafts","setKey","setRows","setName","setDrafts","newSpell","settings","settingFields","manual","profileName","importText","confirmDelete","confirmCopy","scrolls","setScope","tlGroup","tlBoss","tlDifficulty"}
local formKeys={"name","leadTime","delay","phase","counter","duration","text","displaySpellID","player","glowTarget"}
local specTabs={mythic=true,raid=true,sets=true,timeline=true}
local function viewKey()return state.tab..":"..tostring(specTabs[state.tab]and state.spec or"general")end
local function scope()return state.tab=="raid"and"raid"or state.tab=="sets"and(state.setScope or"mythic")or"mythic"end
local function draftKey(key)return scope()..":"..tostring(key or"new")end
local function ruleKey(ctx,key)
    return table.concat({ctx.scope,tostring(ctx.spec),tostring(ctx.map),tostring(ctx.npc),tostring(ctx.encounter),tostring(ctx.difficulty),tostring(ctx.spell or"timed"),tostring(key or"new")},":")
end
local function capture()
    for key,c in pairs(ns.UIControls)do
        if key=="set-name"then state.setName=c:GetText()
        elseif key=="new-spell"then state.newSpell=c:GetText()
        elseif key=="profile-name"then state.profileName=c:GetText()
        elseif key=="profile-string"then state.importText=c:GetText()
        elseif key:match("^rule:")and c.GetText and c.GetObjectType and c:GetObjectType()=="EditBox"then
            if state.form then state.form[key:sub(6)]=c:GetText()end
        elseif key:match("^setting:")and c.GetObjectType and c:GetObjectType()=="EditBox"then
            state.settingFields=state.settingFields or{};state.settingFields[key:sub(9)]=c:GetText()
        elseif key:match("^manual:")and c.GetObjectType and c:GetObjectType()=="EditBox"then
            state.manual=state.manual or{};state.manual[key:sub(8)]=c:GetText()
        end
    end
    state.scrolls=state.scrolls or{}
    for key,s in pairs(ns.UIScrolls)do state.scrolls[key]=s:GetVerticalScroll()end
end
local function remember()
    if state.context and state.form then
        state.ruleDrafts=state.ruleDrafts or{}
        state.ruleDrafts[ruleKey(state.context,state.ruleKey)]={form=ns.Clone(state.form),reference=ns.Clone(state.reference)}
    end
    if state.setName then
        state.setDrafts=state.setDrafts or{}
        state.setDrafts[draftKey(state.setKey)]={name=state.setName,rows=ns.Clone(state.setRows),newSpell=state.newSpell}
    end
end
local function saveView()
    if not workspace then return end
    remember();local saved={};for _,key in ipairs(viewFields)do saved[key]=ns.Clone(state[key])end
    workspace.views[viewKey()]=saved;workspace.tab=state.tab;workspace.spec=state.spec
end
local function loadView()
    local saved=workspace.views[viewKey()]or{}
    for _,key in ipairs(viewFields)do state[key]=ns.Clone(saved[key])end
    state.mode=state.mode or"mechanics";state.difficulty=state.difficulty or 15;state.setRows=state.setRows or{}
    state.ruleDrafts=state.ruleDrafts or{};state.setDrafts=state.setDrafts or{};state.scrolls=state.scrolls or{}
end
local function ensureWorkspace()
    local store=ns.Store()
    if owner==store and profileName==store.active then return end
    saveView();owner=store;profileName=store.active
    store.workspace=store.workspace or{profiles={}};store.workspace.profiles=store.workspace.profiles or{}
    local key=profileName or"";workspace=store.workspace.profiles[key]or{views={}};workspace.views=workspace.views or{}
    store.workspace.profiles[key]=workspace
    -- Only the logged-in specialization is shown; a saved spec from another class is never reopened.
    state.tab=workspace.tab or"mythic";state.spec=ns.Spec()or workspace.spec or 104
    if not ns.CanEditSpec(state.spec)then state.spec=ns.OwnSpecs()[1]or state.spec end
    loadView()
end
W.BeforeAction=function()capture();saveView()end
function ns.SaveWorkspaceDrafts()if window then capture();saveView()end end
local function notify(text,error)
    if error then text=tostring(text):gsub("^.-%.lua:%d+:%s*","")end
    state.message=text;state.error=error;if status then status:SetText(text);status:SetTextColor(unpack(error and C.warning or C.muted))end
end
local function done(value,error,message)
    if not value then notify(error or"Change could not be saved",true);return false end
    state.message=message or"Saved";state.error=false;Refresh();return true
end
local function name(spell,fallback)
    local result=ns.SpellLabel and ns.SpellLabel(spell)
    if result and not result:match("^Spell %d+$")and result~="Reminder"then return result end
    return fallback or ns.Catalog.spellNames[spell]or("Spell "..tostring(spell))
end
local function rowsOptions(t)
    local rows={};for k,p in pairs(t or{})do rows[#rows+1]={value=k,label=p.name or tostring(k)}end
    table.sort(rows,function(a,b)return a.label<b.label end);return rows
end
local function read(key)return ns.UIControls[key]:GetText()end
local function specInfo(spec)
    local icon,class
    if GetSpecializationInfoByID then local ok,_,_,_,i,_,c=pcall(GetSpecializationInfoByID,spec);if ok then icon=ns.Plain(i,"number")and i or nil;class=ns.Plain(c,"string")and c or nil end end
    return icon,class
end
local function matches(text)
    local f=state.filter;if not f or f==""then return true end
    return tostring(text or""):lower():find(f:lower(),1,true)~=nil
end
---------------------------------------------------------------------------
-- Reminder counts. A context is one ability (or the timed list) of one entity.
local timedTypes={pull=true,stage=true,prepull=true}
local function entityContext(content,g,n,ability)
    return {scope=content,spec=state.spec,map=g and g.mapID,group=g and g.id,npc=n and n.id,kind=n and n.kind or"boss",encounter=n and(n.encounterId or(content=="raid"and n.id)),difficulty=content=="mythic"and 8 or state.difficulty,spell=ability and ability.id,abilityName=ability and name(ability.id,ability.name)}
end
local function allowedAbilities(content,n)
    local out={}
    for _,a in ipairs(n and n.abilities or{})do
        local allowed=true;if content=="raid"and a.difficulties then allowed=false;for _,d in ipairs(a.difficulties)do if d==(state.difficulty==15 and"heroic"or"mythic")then allowed=true end end end
        if allowed then out[#out+1]=a end
    end
    return out
end
local function timedRules(ctx)
    local out={};if not ctx.encounter then return out end
    local all=ns.Clone(ctx);all.spell=nil
    for _,r in ipairs(ns.RuleOptions(all))do if r.entry.trigger and timedTypes[r.entry.trigger.type]then out[#out+1]=r end end
    return out
end
local function abilityCount(content,g,n,a)return #ns.RuleOptions(entityContext(content,g,n,a))end
local function entityCount(content,g,n)
    local total=0;for _,a in ipairs(allowedAbilities(content,n))do total=total+abilityCount(content,g,n,a)end
    if content=="raid"then total=total+#timedRules(entityContext(content,g,n))end
    return total
end
local function groupCount(content,g)
    local total=0;for _,n in ipairs(g.npcs or g.bosses or{})do total=total+entityCount(content,g,n)end;return total
end
local function contentCount(content)
    local total=0;for _,g in ipairs(ns.CatalogGroups(content))do total=total+groupCount(content,g)end;return total
end
local function entityMatches(n)
    if matches(n.name)then return true end
    for _,a in ipairs(n.abilities or{})do if matches(name(a.id,a.name))then return true end end
end
---------------------------------------------------------------------------
local function chooseSet(key,fresh)
    state.setKey=key;state.setRows={};local p=ns.ScopePresets(ns.Active(),scope(),state.spec)[key]
    local draft=not fresh and state.setDrafts and state.setDrafts[draftKey(key)]
    if draft then state.setName=draft.name;state.setRows=ns.Clone(draft.rows);state.newSpell=draft.newSpell;return end
    state.setName=p and p.name or L("New defensive set")
    state.newSpell=""
    for _,spell in ipairs(p and p.list or{})do state.setRows[#state.setRows+1]={spellID=spell,together=ns.Get(p.together,spell)==true,enabled=not ns.Get(p.disabled,spell)}end
end
local function ContentHeader(parent,title,subtitle)
    W.Label(parent,title,0,0,600,20,C.text,true);W.Label(parent,subtitle,0,29,600,12,C.muted)
end
local function ModeSwitch(parent)
    if state.tab=="sets"then
        W.Segmented(parent,{{value="mythic",label="Mythic+"},{value="raid",label=L("Raid")}},scope(),620,0,300,function(v)state.setScope=v;state.setKey=nil;state.setName=nil;state.setRows={};Refresh()end,"sets-scope");return
    end
    W.Segmented(parent,{{value="mechanics",label=L("Mechanics")},{value="sets",label=L("Defensive sets")}},state.mode=="sets"and"sets"or"mechanics",620,0,300,function(v)state.mode=v;Refresh()end,"mode")
end
local function setRowsAdd(spell)
    for _,r in ipairs(state.setRows)do if r.spellID==spell then notify("Ability already exists",true);return end end
    state.setName=read("set-name");state.setRows[#state.setRows+1]={spellID=spell,enabled=true};state.newSpell="";Refresh()
end
local function knownSpell(spell)
    local known=C_SpellBook and(C_SpellBook.IsSpellKnownOrInSpellBook or C_SpellBook.IsSpellKnown)or IsPlayerSpell
    if not known then return false end
    local ok,value=pcall(known,spell);return ok and ns.Plain(value,"boolean")and value
end
local function DrawSets(parent)
    ContentHeader(parent,scope()=="mythic"and L("Mythic+ defensive sets")or L("Raid defensive sets"),(ns.Catalog.specs[state.spec]or"").." · "..L("The first ready ability wins; Together abilities are called as one."))
    ModeSwitch(parent)
    local sets=ns.ScopePresets(ns.Active(),scope(),state.spec);local options=rowsOptions(sets)
    if state.setKey and not sets[state.setKey]then chooseSet(nil)end
    if not state.setName then chooseSet(options[1]and options[1].value)end
    -- Copy the whole spec setup (both content types) onto another specialization.
    local specs={};for _,id in ipairs(ns.OwnSpecs())do if id~=state.spec then specs[#specs+1]={value=id,label=L("Copy setup to ")..ns.Catalog.specs[id]}end end;table.sort(specs,function(a,b)return a.label<b.label end)
    if state.confirmCopy then
        W.Button(parent,L("Replace ")..(ns.Catalog.specs[state.confirmCopy]or"spec").."?",620,56,200,function()local target=state.confirmCopy;state.confirmCopy=nil;done(ns.CopySpecSetup(state.spec,target),nil,"Setup copied to "..(ns.Catalog.specs[target]or"spec"))end,false,"copy-spec-confirm",{kind="primary"})
        W.Button(parent,L("Cancel"),828,56,92,function()state.confirmCopy=nil;Refresh()end,false,"copy-spec-cancel")
    else
        if #specs>0 then W.Select(parent,nil,specs,nil,620,56,300,function(v)state.confirmCopy=v;Refresh()end,"copy-spec");ns.UIControls["copy-spec"].label:SetText(L("Copy this spec's setup to..."))end
    end
    local list=W.Scroll(parent,0,96,240,460,"sets:list")
    W.Caption(list,L("Sets"),8,8,200)
    for i,o in ipairs(options)do
        local p=sets[o.value];local b=W.Button(list,o.label,0,28+(i-1)*52,212,function()chooseSet(o.value);Refresh()end,o.value==state.setKey,"set:"..o.value,{h=46,marker=true,badge=ns.SetUses and ns.SetUses(scope(),state.spec,o.value)})
        b.label:ClearAllPoints();b.label:SetPoint("TOPLEFT",b,"TOPLEFT",10,-8)
        for j,spell in ipairs(p.list or{})do if j<=6 then W.Icon(b,spell,10+(j-1)*20,26,16)end end
    end;list:SetHeight(math.max(1,36+#options*52))
    W.Button(parent,L("+ New set"),0,566,116,function()chooseSet(nil,true);Refresh()end,false,"new-set")
    W.Button(parent,L("Duplicate"),124,566,116,function()state.setKey=nil;state.setName=(state.setName or"Set").." copy";Refresh()end,false,"copy-set")
    local panel=W.Card(parent,252,96,668,460)
    W.Field(panel,L("Set name"),state.setName,16,14,400,"set-name")
    if state.setKey and ns.SetUses then W.Label(panel,L("Used by reminders: ")..ns.SetUses(scope(),state.spec,state.setKey),430,38,220,12,C.muted)end
    W.Heading(panel,L("Priority order"),16,72,636)
    local content=W.Scroll(panel,12,94,644,218,"sets:abilities",C.background)
    for i,row in ipairs(state.setRows)do
        local y=(i-1)*46;local r=W.Panel(content,0,y,620,42,C.raised,C.line,8)
        W.Label(r,tostring(i),10,15,20,12,C.muted);W.Icon(r,row.spellID,32,6,30);W.Label(r,name(row.spellID),72,7,200,12);W.Label(r,tostring(row.spellID),72,24,200,10,C.muted)
        W.Toggle(r,L("On"),row.enabled,270,9,64,function(v)row.enabled=v end,"set-enabled:"..i)
        W.Toggle(r,L("Together"),row.together,344,9,110,function(v)row.together=v end,"set-together:"..i)
        W.Button(r,"",470,7,30,function()if i>1 then state.setRows[i],state.setRows[i-1]=state.setRows[i-1],state.setRows[i]end;state.setName=read("set-name");Refresh()end,false,"set-up:"..i,{h=28,glyph="up",tooltip=L("Move up")})
        W.Button(r,"",504,7,30,function()if i<#state.setRows then state.setRows[i],state.setRows[i+1]=state.setRows[i+1],state.setRows[i]end;state.setName=read("set-name");Refresh()end,false,"set-down:"..i,{h=28,glyph="chevron",tooltip=L("Move down")})
        W.Button(r,"",544,7,30,function()table.remove(state.setRows,i);state.setName=read("set-name");Refresh()end,false,"set-remove:"..i,{h=28,kind="danger",glyph="trash",tooltip=L("Remove")})
    end;content:SetHeight(math.max(1,#state.setRows*46))
    if #state.setRows==0 then W.Label(content,L("Add defensives from your spellbook below, or enter a spell ID."),12,14,560,12,C.muted)end
    W.Heading(panel,L("Add from your spellbook"),16,324,636)
    local x=16;local ids={};for id in pairs(ns.Catalog.spellNames)do if knownSpell(id)then ids[#ids+1]=id end end;table.sort(ids)
    local inSet={};for _,r in ipairs(state.setRows)do inSet[r.spellID]=true end
    local shown=0
    for _,id in ipairs(ids)do if not inSet[id]and shown<17 then
        local b=W.Button(panel,"",x,346,34,function()setRowsAdd(id)end,false,"suggest:"..id,{h=34,tooltip=name(id)});W.Icon(b,id,3,3,28);x=x+37;shown=shown+1
    end end
    if shown==0 then W.Label(panel,L("No known catalog defensives to suggest for this character."),16,356,600,12,C.muted)end
    W.Field(panel,L("Or add by spell ID"),state.newSpell or"",16,392,210,"new-spell")
    W.Button(panel,L("Add ability"),236,408,120,function()local spell=tonumber(read("new-spell"));if not spell or spell<1 or spell%1~=0 then notify("Enter a positive integer spell ID",true);return end;setRowsAdd(spell)end,false,"add-spell")
    W.Button(parent,L("Delete set"),252,566,116,function()local key=state.setKey;local a,b=ns.DeleteSet(scope(),state.spec,key);if a then state.setDrafts[draftKey(key)]=nil;chooseSet(nil,true)end;done(a,b,"Set deleted")end,false,"delete-set",{kind="danger"})
    W.Button(parent,L("Test set"),600,566,120,function()local preset={list={},together={},disabled={}};for _,r in ipairs(state.setRows)do preset.list[#preset.list+1]=r.spellID;if r.together then preset.together[r.spellID]=true end;if not r.enabled then preset.disabled[r.spellID]=true end end;local spells=ns.Pick(preset);if #spells==0 then for _,r in ipairs(state.setRows)do if r.enabled then spells={r.spellID};break end end end;ns.Display({type="icon",spells=spells,text="Set preview",dur=4});notify("Preview only; no encounter trigger was fired")end,false,"test-set")
    W.Button(parent,L("Save set"),730,566,190,function()local oldKey=state.setKey;local a,b=ns.SaveSet(scope(),state.spec,oldKey,read("set-name"),state.setRows);if a then state.setDrafts[draftKey(oldKey)]=nil;state.setKey=a;state.setName=read("set-name")end;done(a,b,"Defensive set saved")end,true,"save-set",{kind="primary",align="CENTER"})
end
local function InitialForm(ctx,reference)
    local e=reference and reference.entry or{};local t=e.trigger or{};local d=e.display or{}
    local dynamic=e.defensive
    local action=dynamic and"defensive"or reference and reference.section=="raidReminders"and(d.type or"text")or"defensive"
    local recipient="everyone";local player,role
    if e.target then
        local count=0;for k,v in pairs(e.target)do if type(v)=="table"and next(v)then count=count+1 end end
        if e.target.matchAny or count>1 then recipient="preserve"
        elseif e.target.specs then recipient="spec"
        elseif e.target.roles then recipient="role";role=next(e.target.roles)
        elseif e.target.names then recipient="player";player=next(e.target.names)
        elseif not e.target.all then recipient="preserve"end
    end
    return {name=e.name or(ctx.abilityName or"New reminder"),enabled=e.enabled~=false,preset=dynamic and dynamic.preset or e.preset,action=action,trigger=t.type=="exboss"and"bwtimer"or t.type or"bwtimer",leadTime=t.timeleft or t.leadTime or e.leadTime or 2,delay=t.delay or 0,phase=t.stage or 1,counter=ns.CounterText(t.counterGroups),duration=d.dur or 4,text=d.text or"",sound=d.sound or"",tts=d.tts==true,displaySpellID=d.spellID or"",glowTarget=d.glowTarget or"",recipient=recipient,role=role or"HEALER",player=player or"",preserveDifficulties=e.difficulties and ns.Clone(e.difficulties)or nil}
end
local actionLabels={defensive="Defensive priority set",icon="Spell icon",text="Text",bar="Countdown bar",circle="Circle",chat="Sound only",raidframeGlow="Player frame glow"}
local roleLabels={TANK="Tank",HEALER="Healer",DAMAGER="Damage"}
-- One plain sentence describing what the reminder will do.
local function Summary(ctx,form)
    local ability=ctx.abilityName or"the mechanic";local t=form.trigger;local when
    if ctx.kind=="trash"then when=tostring(form.leadTime).."s before "..ability.." (trash timer)"
    elseif t=="pull"then when=tostring(form.delay).."s after pull"
    elseif t=="prepull"then when=tostring(form.delay).."s before pull"
    elseif t=="stage"then when=tostring(form.delay).."s into phase "..tostring(form.phase)
    elseif t=="bwmsg"then when="On the "..ability.." message"..((tonumber(form.delay)or 0)>0 and(" +"..tostring(form.delay).."s")or"")
    else when=tostring(form.leadTime).."s before "..ability end
    if form.counter and form.counter~=""and ctx.kind~="trash"then when=when.." (casts "..form.counter..")"end
    local who="everyone"
    if form.action=="defensive"or form.recipient=="spec"then who="you ("..(ns.Catalog.specs[ctx.spec]or"this spec")..")"
    elseif form.recipient=="role"then who=(roleLabels[form.role]or"role").." players"
    elseif form.recipient=="player"then who=form.player~=""and form.player or"one player"
    elseif form.recipient=="preserve"then who="imported recipients"end
    local what
    if form.action=="defensive"then local p=ns.ScopePresets(ns.Active(),ctx.scope,ctx.spec)[form.preset];what=p and("set \""..p.name.."\"")or"a defensive set (choose one)"
    else what=(actionLabels[form.action]or"text"):lower()end
    return when.."  >  "..who.."  >  "..what
end
local function Preview(parent,ctx,form,x,y,w)
    local box=W.Panel(parent,x,y,w,56,C.background,C.line,8)
    local spells={}
    if form.action=="defensive"then local p=ns.ScopePresets(ns.Active(),ctx.scope,ctx.spec)[form.preset];for i,s in ipairs(p and p.list or{})do if i<=4 then spells[#spells+1]=s end end
    elseif form.action=="icon"or form.action=="circle"then spells={tonumber(form.displaySpellID)or ctx.spell}end
    local ix=10;for i,s in ipairs(spells)do local icon=W.Icon(box,s,ix,10,32);if i>1 then icon:SetVertexColor(0.55,0.55,0.55,1)end;ix=ix+36 end
    local text=form.text~=""and form.text or(spells[1]and name(spells[1]))or(ctx.abilityName or"Reminder")
    if form.action=="chat"then text="(sound only) "..text end
    W.Label(box,text,ix+4,12,w-ix-60,14,C.text,true);W.Label(box,tostring(form.duration).."s",w-50,14,40,12,C.brand)
    W.Bar(box,ix+4,40,w-ix-16,0.6,form.action=="raidframeGlow"and C.brand or C.accent,4)
    return box
end
local function DrawInspector(parent,ctx,rules)
    local form=state.form;local p=W.Card(parent,480,96,440,504);local inner=416
    local function collect()for _,k in ipairs(formKeys)do local c=ns.UIControls["rule:"..k];if c then form[k]=c:GetText()end end end
    if ctx.spell then W.Icon(p,ctx.spell,12,12,32)else W.Rect(p,12,12,32,32,C.accentSoft)end
    W.Label(p,ctx.abilityName or L("Timed reminder"),54,12,260,14,C.text,true);W.Label(p,ctx.spell and("Spell "..ctx.spell)or("Encounter "..tostring(ctx.encounter).." · timed"),54,32,270,10,C.muted)
    W.Toggle(p,L("Enabled"),form.enabled,316,15,112,function(v)form.enabled=v end,"rule:enabled")
    local y=56
    if #rules>0 and not state.timed then
        local o={{value="new",label="+ Another reminder for this mechanic"}};for _,r in ipairs(rules)do o[#o+1]={value=r.key,label=r.entry.name or tostring(r.key)}end
        W.Select(p,nil,o,state.reference and state.reference.key or"new",12,y,inner,function(v)state.ruleKey=v;state.form=nil;Refresh()end,"rule-choice");y=y+38
    end
    Preview(p,ctx,form,12,y,inner);y=y+62
    W.Label(p,Summary(ctx,form),12,y,inner,12,C.muted);y=y+36
    local content=W.Scroll(p,8,y,424,450-y,"inspector",C.background)
    local cy=4
    local function field(title,key,w,x)W.Field(content,title,form[key],x or 6,cy,w or 384,"rule:"..key)end
    local function select(title,key,options,w,x)
        W.Select(content,title,options,form[key],x or 6,cy,w or 384,function(v)
            -- Preserve unsaved input while revealing a different set of fields.
            collect();form[key]=v;Refresh()
        end,"rule:"..key)
    end
    local function heading(text)W.Heading(content,text,6,cy,384);cy=cy+24 end
    field("REMINDER NAME","name");cy=cy+56
    heading("WHEN")
    if ctx.kind~="trash"then
        local triggers={{value="bwtimer",label="Mechanic countdown"},{value="bwmsg",label="Mechanic message"}}
        if ctx.scope=="raid"then triggers[#triggers+1]={value="pull",label="Time from pull"};triggers[#triggers+1]={value="prepull",label="Before pull (countdown)"};triggers[#triggers+1]={value="stage",label="Time from phase"}end
        select("TRIGGER","trigger",triggers);cy=cy+54
    end
    if form.trigger=="pull"or form.trigger=="stage"or form.trigger=="prepull"then
        field(form.trigger=="prepull"and"SECONDS BEFORE PULL"or"SECONDS FROM ANCHOR","delay",186);if form.trigger=="stage"then field("PHASE","phase",186,204)end;cy=cy+54
    elseif ctx.kind~="trash"then field("DELAY AFTER EVENT (S)","delay",186);field("WARN BEFORE (S)","leadTime",186,204);cy=cy+54 end
    if ctx.kind=="trash"or form.trigger=="pull"or form.trigger=="stage"or form.trigger=="prepull"then field("WARN BEFORE (SECONDS)","leadTime",186);cy=cy+54 end
    if ctx.kind~="trash"then field("WHICH CASTS · BLANK = EVERY, E.G. >1 OR 2,4","counter");cy=cy+54 end
    if ctx.scope=="raid"and form.action~="defensive"then
        heading("WHO")
        local targets={{value="everyone",label="Everyone"},{value="spec",label="Selected specialization"},{value="role",label="Role"},{value="player",label="Player"}}
        if form.recipient=="preserve"then targets[#targets+1]={value="preserve",label="Imported filters (preserve)"}end
        select("RECIPIENTS","recipient",targets);cy=cy+54
        if form.recipient=="role"then select("ROLE","role",{{value="TANK",label="Tank"},{value="HEALER",label="Healer"},{value="DAMAGER",label="Damage"}});cy=cy+54 end
        if form.recipient=="player"then field("PLAYER NAME OR NAME-REALM","player");cy=cy+54 end
    end
    heading("SHOW")
    if ctx.kind~="trash"then
        local actions={};for _,k in ipairs({"defensive","icon","text","bar","circle","chat","raidframeGlow"})do actions[#actions+1]={value=k,label=actionLabels[k]}end
        select("ACTION","action",actions);cy=cy+54
    end
    if form.action=="defensive"then
        local sets=rowsOptions(ns.ScopePresets(ns.Active(),ctx.scope,ctx.spec));table.insert(sets,1,{value="",label="Choose defensive set..."});select("DEFENSIVE SET","preset",sets);cy=cy+54
    elseif form.action=="icon"then field("DISPLAY SPELL ID","displaySpellID");cy=cy+54 end
    field("TEXT · BLANK USES THE SPELL NAME","text");cy=cy+54
    local sounds={{value="",label="None"},{value="voice:use-a-defensive",label="Use a defensive"},{value="voice:move-out",label="Move out"},{value="voice:dispel-me",label="Dispel me"}}
    local known=false;for _,o in ipairs(sounds)do if o.value==form.sound then known=true end end
    if not known then sounds[#sounds+1]={value=form.sound,label="Imported sound"}end
    select("SOUND","sound",sounds,186);field("SHOW FOR (SECONDS)","duration",186,204);cy=cy+54
    if form.action=="raidframeGlow"then field("PLAYER TO GLOW","glowTarget");cy=cy+54 end
    W.Toggle(content,"Text to speech",form.tts,6,cy,384,function(v)form.tts=v end,"rule:tts");cy=cy+32
    if form.preserveDifficulties then
        W.Toggle(content,"Keep imported difficulty filters",true,6,cy,384,function(v)form.preserveDifficulties=v end,"rule:preserve-difficulty");cy=cy+32
    end
    content:SetHeight(cy+8)
    W.Button(p,L("Test"),12,462,76,function()collect();local spell=tonumber(form.displaySpellID);if form.action=="defensive"then local preset=ns.ScopePresets(ns.Active(),ctx.scope,ctx.spec)[form.preset];spell=preset and preset.list[1]end;ns.Display({type=spell and"icon"or"text",spellID=spell,text=form.text~=""and form.text or"Reminder preview",dur=tonumber(form.duration)or 4,sound=form.sound,tts=form.tts});notify("Display preview; verify the mechanic in game")end,false,"test-rule",{align="CENTER"})
    W.Button(p,L("Delete"),96,462,86,function()local a,b=ns.DeleteRule(ctx,state.reference);if a then state.ruleDrafts[ruleKey(ctx,state.ruleKey)]=nil;state.reference=nil;state.ruleKey="new";state.form=InitialForm(ctx)end;done(a,b,"Reminder deleted")end,false,"delete-rule",{kind="danger",align="CENTER"})
    W.Button(p,L("Save reminder"),258,462,170,function()collect();local key,error=ns.SaveRule(ctx,form,state.reference);if key then state.ruleDrafts[ruleKey(ctx,state.ruleKey)]=nil;state.ruleDrafts[ruleKey(ctx,key)]=nil;state.ruleKey=key;state.form=nil end;done(key,error,"Reminder saved")end,true,"save-rule",{kind="primary",align="CENTER"})
end
local function DrawManual(parent)
    ContentHeader(parent,L("Add an encounter mechanic"),L("Use verified IDs from your installed client. Retail catalogs are not applied to Forever."))
    local a=state.manual or{kind="boss",groupName="",npcName="",npcID="",mapID="",encounterId="",spellID="",spellName=""};state.manual=a
    local keys={{"DUNGEON / RAID NAME","groupName"},{"NPC / BOSS NAME","npcName"},{"NPC ID","npcID"},{"INSTANCE MAP ID (M+)","mapID"},{"ENCOUNTER ID (BOSS)","encounterId"},{"MECHANIC SPELL ID","spellID"},{"ABILITY NAME (OPTIONAL)","spellName"}}
    local panel=W.Card(parent,0,64,920,420)
    for i,row in ipairs(keys)do W.Field(panel,row[1],a[row[2]],20+(i-1)%2*450,20+math.floor((i-1)/2)*70,420,"manual:"..row[2])end
    W.Select(panel,"TYPE",{{value="boss",label="Boss"},{value="trash",label="Trash (M+ only)"}},a.kind,470,230,420,function(v)a.kind=v end,"manual:kind")
    W.Button(parent,L("Back"),0,500,100,function()state.mode="mechanics";Refresh()end,false,"manual-back")
    W.Button(parent,L("Save mechanic"),720,500,200,function()for _,r in ipairs(keys)do a[r[2]]=read("manual:"..r[2])end;a.scope=scope();if a.scope=="raid"then a.kind="boss"end;local id,error=ns.AddManualMechanic(a);if id then state.group=id;state.mode="mechanics";state.entity=nil end;done(id,error,"Mechanic added")end,true,"save-manual",{kind="primary",align="CENTER"})
end
local function DrawMechanics(parent)
    local content=scope();ContentHeader(parent,content=="mythic"and L("Mythic+ mechanics")or L("Raid encounters"),content=="mythic"and L("Bind your defensive sets to boss and trash abilities.")or L("Mechanic, pull and phase reminders for Heroic and Mythic."))
    ModeSwitch(parent)
    local groups=ns.CatalogGroups(content)
    if state.filter and state.filter~=""then
        local hits={};for _,g in ipairs(groups)do for _,n in ipairs(g.npcs or g.bosses or{})do if entityMatches(n)then hits[#hits+1]=g;break end end end;groups=hits
    end
    local g=groups[1];for _,v in ipairs(groups)do if v.id==state.group then g=v end end
    if g then state.group=g.id end
    local opts={};for _,v in ipairs(groups)do opts[#opts+1]={value=v.id,label=v.name}end
    W.Select(parent,nil,opts,state.group,0,56,320,function(v)state.group=v;state.timed=false;state.entity=nil;state.ability=nil;state.ruleKey=nil;state.form=nil;Refresh()end,"group")
    if content=="raid"then W.Segmented(parent,{{value=15,label="Heroic"},{value=16,label="Mythic"}},state.difficulty,330,56,200,function(v)state.difficulty=v;state.form=nil;state.ruleKey=nil;Refresh()end,"difficulty")end
    W.Button(parent,L("+ Custom mechanic"),760,56,160,function()state.mode="manual";Refresh()end,false,"add-mechanic",{kind="outline",align="CENTER"})
    if not g then W.Label(parent,state.filter~=""and(L("Nothing matches")..": "..state.filter)or L("No encounters for this client yet. Add your own verified IDs."),0,110,600,13,C.muted);return end
    local entities=g and(g.npcs or g.bosses)or{};if content=="raid"and g then entities=g.bosses end
    local visible={};for _,v in ipairs(entities)do if entityMatches(v)then visible[#visible+1]=v end end
    local n=visible[1];for _,v in ipairs(visible)do if v.id==state.entity then n=v end end
    if n then state.entity=n.id end
    local list=W.Scroll(parent,0,96,226,504,"mechanics:entities")
    local ly=6
    local function entityButtons(kind,title)
        local any=false
        for _,v in ipairs(visible)do if(v.kind=="trash")==(kind=="trash")then
            if not any then W.Caption(list,title,8,ly+2,190);ly=ly+20;any=true end
            W.Button(list,v.name,0,ly,198,function()state.entity=v.id;state.timed=false;state.ability=nil;state.form=nil;state.ruleKey=nil;Refresh()end,n==v,"entity:"..v.id,{h=32,marker=true,badge=entityCount(content,g,v)});ly=ly+36
        end end
        if any then ly=ly+6 end
    end
    entityButtons("boss","Bosses");entityButtons("trash","Trash");list:SetHeight(ly+4)
    local abilities={};for _,a in ipairs(allowedAbilities(content,n))do if matches(n.name)or matches(name(a.id,a.name))then abilities[#abilities+1]=a end end
    local ability=abilities[1];for _,a in ipairs(abilities)do if a.id==state.ability then ability=a end end
    local ctx=entityContext(content,g,n,ability)
    if ability then state.ability=ability.id end
    local mechanics=W.Scroll(parent,234,96,238,504,"mechanics:abilities");W.Caption(mechanics,L("Mechanics"),8,8,200)
    local my=28
    for _,a in ipairs(abilities)do W.Button(mechanics,name(a.id,a.name),0,my,210,function()state.ability=a.id;state.form=nil;state.ruleKey=nil;state.timed=false;Refresh()end,ability==a and not state.timed,"ability:"..a.id,{h=32,icon=a.id,marker=true,badge=abilityCount(content,g,n,a)});my=my+36 end
    if content=="raid"and n then
        W.Caption(mechanics,L("Timed"),8,my+8,200);my=my+28
        -- Existing pull/phase reminders remain visible even when no spell is attached.
        for _,r in ipairs(timedRules(ctx))do
            local t=r.entry.trigger;local at=t.type=="prepull"and("-"..tostring(t.delay).."s")or t.type=="stage"and("P"..tostring(t.stage).." "..tostring(t.delay).."s")or(tostring(t.delay).."s")
            W.Button(mechanics,at.."  "..(r.entry.name or"Timed reminder"),0,my,210,function()state.timed=true;state.ruleKey=r.key;state.form=nil;Refresh()end,state.ruleKey==r.key and state.timed,"timed:"..r.key,{h=32,marker=true});my=my+36
        end
        W.Button(mechanics,L("+ Timed reminder"),0,my,210,function()state.timed=true;state.ruleKey=nil;state.form=nil;Refresh()end,state.timed and state.ruleKey=="new","new-timed",{h=32,kind="outline"});my=my+38
    end;mechanics:SetHeight(my+8)
    if state.timed then ctx.spell=nil;ctx.abilityName=L("Timed encounter reminder")end
    if n and(ability or state.timed)then
        local rules=ns.RuleOptions(ctx);local reference
        for _,r in ipairs(rules)do if r.key==state.ruleKey then reference=r end end
        if not state.form then
            if not reference and state.ruleKey~="new"and not state.timed then reference=rules[1]end
            state.ruleKey=reference and reference.key or"new"
            local draft=state.ruleDrafts[ruleKey(ctx,state.ruleKey)]
            if draft then state.reference=ns.Clone(draft.reference);state.form=ns.Clone(draft.form)
            else state.reference=reference;state.form=InitialForm(ctx,reference);if state.timed and not reference then state.form.trigger="pull";state.form.delay=30;state.form.action="text"end end
        end
        state.context=ctx;DrawInspector(parent,ctx,rules)
    else W.Label(parent,L("Choose an encounter and mechanic, or add your own verified IDs."),496,140,400,13,C.muted)end
end
---------------------------------------------------------------------------
-- Overview: four stat cards, Mythic+ coverage and raid readiness, like the mockup.
local function coverage(content,g)
    local entities=g.npcs or g.bosses or{};local covered=0
    for _,n in ipairs(entities)do if entityCount(content,g,n)>0 then covered=covered+1 end end
    return covered,#entities
end
local function setCount(content)local n=0;for _ in pairs(ns.ScopePresets(ns.Active(),content,state.spec))do n=n+1 end;return n end
local function providerName()
    local p=ns.ProviderStatus and ns.ProviderStatus()or{}
    return p.BigWigs and"BigWigs"or p.DBM and"DBM"or nil,p.EXBoss
end
local function openGroup(content,g)
    state.tab=content;loadView();state.group=g.id;state.mode="mechanics";state.entity=nil;state.ability=nil;state.form=nil;state.ruleKey=nil;state.timed=false;Refresh()
end
local function DrawOverview(parent)
    local spec=ns.Catalog.specs[state.spec]or L("Specialization")
    W.Label(parent,L("Overview"),0,0,300,20,C.text,true);W.Label(parent,spec.." · "..L("profile").." "..tostring(ns.Store().active or"-"),110,6,500,12,C.muted)
    local mythic,raid=contentCount("mythic"),contentCount("raid");local source,ex=providerName()
    local stats={{L("Reminders"),tostring(mythic+raid),"M+ "..mythic.." · "..L("raid").." "..raid,C.text},{L("Defensive sets"),tostring(setCount("mythic")+setCount("raid")),"M+ "..setCount("mythic").." · "..L("raid").." "..setCount("raid"),C.text},
        {L("Specialization"),(spec:match("^(%S+)")or spec),L("Sets load for your current spec"),C.accent},{L("Combat source"),source or L("None"),ex and L("ExBoss for trash")or L("No ExBoss trash timers"),source and C.ok or C.warning}}
    for i,s in ipairs(stats)do
        local card=W.Card(parent,(i-1)*232,40,222,96,s[1])
        W.Label(card,s[2],12,32,200,26,s[4],true);W.Label(card,s[3],12,70,200,12,C.muted)
    end
    local left=W.Card(parent,0,148,454,444,L("Mythic+ · coverage"));local y=36
    local groups=ns.CatalogGroups("mythic")
    if #groups==0 then W.Label(left,L("No encounters for this client. Add custom mechanics from the Mythic+ page."),12,y,420,12,C.muted)end
    for _,g in ipairs(groups)do
        local covered,total=coverage("mythic",g);local p=total>0 and covered/total or 0
        local color=p>=1 and C.ok or p>=0.5 and C.accent or p>0 and C.warning or C.danger
        local b=W.Button(left,g.name,8,y,438,function()openGroup("mythic",g)end,false,"overview:mythic:"..tostring(g.id),{kind="ghost",h=30,badge=groupCount("mythic",g)})
        b.label:SetWidth(170);W.Bar(b,190,12,170,p,color);local l=W.Label(b,covered.." / "..total,364,9,36,12,color);l:SetJustifyH("RIGHT")
        y=y+32;if y>410 then break end
    end
    local right=W.Card(parent,466,148,454,444,L("Raid · readiness"));y=36
    local raids=ns.CatalogGroups("raid")
    if #raids==0 then W.Label(right,L("No encounters for this client. Add custom mechanics from the Raids page."),12,y,420,12,C.muted)end
    for _,g in ipairs(raids)do
        local covered,total=coverage("raid",g);local done=total>0 and covered==total
        local row=W.Panel(right,10,y,434,34,C.raised,C.clear,8)
        W.Dot(row,10,13,done and C.ok or covered>0 and C.warning or C.muted)
        W.Label(row,g.name,26,10,200,13);W.Label(row,covered.." / "..total.." "..L("bosses covered"),226,11,130,11,C.muted):SetWordWrap(false)
        W.Button(row,L("Open"),364,3,64,function()openGroup("raid",g)end,false,"overview:raid:"..tostring(g.id),{kind="ghost",h=28,align="CENTER"}).label:SetTextColor(unpack(C.accent))
        y=y+40;if y>400 then break end
    end
    local tips={{L("Display anchors"),"display"},{L("Notes and alerts"),"notes"},{L("Diagnostics and /ndp commands"),"diag"}}
    y=math.max(y+6,260)
    for _,t in ipairs(tips)do if y<=404 then
        local row=W.Panel(right,10,y,434,34,C.raised,C.clear,8);W.Dot(row,10,13,C.muted);W.Label(row,t[1],26,10,300,13,C.soft)
        W.Button(row,L("Open"),364,3,64,function()state.tab=t[2];loadView();Refresh()end,false,"overview:go:"..t[2],{kind="ghost",h=28,align="CENTER"}).label:SetTextColor(unpack(C.accent));y=y+40
    end end
end
---------------------------------------------------------------------------
-- Settings: cards with label-left rows. Profile settings save explicitly; window preferences apply at once.
local function UIPrefs()local store=ns.Store();store.ui=store.ui or{};return store.ui end
ns.UIPrefs=UIPrefs
local function ApplyPrefs()
    local p=UIPrefs();W.SetTheme(p.theme);W.SetFont(p.font)
    if ns.Anim then ns.Anim.SetMode(p.anim or"full")end
end
ns.ApplyUIPrefs=ApplyPrefs
local function DrawSettings(parent)
    W.Label(parent,L("Settings"),0,0,200,20,C.text,true);W.Label(parent,L("Profile settings save with the button. Window, theme and font apply at once and are not exported."),130,6,560,12,C.muted)
    local s=state.settings or ns.Clone(ns.Settings());state.settings=s;state.settingFields=state.settingFields or{}
    W.Button(parent,L("Show a sample"),740,0,180,function()ns.Display({type="icon",spellID=22812,text=L("Use a defensive"),dur=4,tts=s.voiceOn});notify(L("Preview uses currently saved settings"))end,false,"preview-display",{align="CENTER",border=C.accent})
    local col,top,cw=304,40,296
    local reminders=W.Card(parent,0,top,cw,268,L("Reminders"))
    local flags={{"Enable reminders","enabled",reminders},{"Show spell icons","showIcon",reminders},{"Show reminder text","showText",reminders},{"Show duration bar","showBar",reminders},{"Call external if nothing is ready","fallbackOn",reminders}}
    for i,f in ipairs(flags)do local value=s[f[2]];if value==nil then value=f[2]~="voiceOn"and f[2]~="fallbackOn"end;W.Toggle(f[3],L(f[1]),value,12,34+(i-1)*30,cw-24,function(v)s[f[2]]=v end,"setting:"..f[2])end
    W.Select(reminders,L("Boss mod source"),{{value="bigwigs",label="BigWigs / LittleWigs"},{value="dbm",label="DBM"}},s.bossSource or"bigwigs",12,190,cw-24,function(v)s.bossSource=v end,"setting:bossSource")
    local look=W.Card(parent,col,top,cw,268,L("Reminder look"))
    local fields={{"Icon size","iconSize",42},{"Text size","textSize",14},{"Voice volume","voiceVol",100},{"X position","x",0},{"Y position","y",100}}
    local row=0
    for _,f in ipairs(fields)do if f[2]~="voiceVol"then
        local v=(f[2]=="x"or f[2]=="y")and s.pos and s.pos[f[2]]or s[f[2]];local y=34+row*36;row=row+1
        W.Label(look,L(f[1]),12,y+8,170,13);W.Input(look,state.settingFields[f[2]]or v or f[3],cw-102,y,90,"setting:"..f[2])
    end end
    W.Label(look,L("Position is relative to the screen center. The Display page lets you drag the anchor."),12,214,cw-24,11,C.muted)
    local sound=W.Card(parent,col*2,top,cw-8,268,L("Sound and voice"))
    W.Toggle(sound,L("Enable text to speech"),s.voiceOn==true,12,34,cw-32,function(v)s.voiceOn=v end,"setting:voiceOn")
    W.Label(sound,L("Voice volume"),12,78,170,13);W.Input(sound,state.settingFields.voiceVol or s.voiceVol or 100,cw-110,70,90,"setting:voiceVol")
    W.Label(sound,L("Boss mechanics require matching provider messages/timers. ExBoss supplies trash countdowns. Readiness uses public game APIs."),12,118,cw-32,11,C.muted)
    -- Local window preferences.
    local prefs=UIPrefs()
    local anim=W.Card(parent,0,top+280,cw,232,L("Animations"))
    W.Select(anim,L("Mode"),{{value="full",label=L("Full")},{value="reduced",label=L("Reduced")},{value="off",label=L("Off")}},prefs.anim or"full",12,34,cw-24,function(v)prefs.anim=v;ApplyPrefs();Refresh()end,"ui:anim")
    W.Label(anim,L("Full: living background at 60 fps, particles, trails, glow, logo shine and a burst on each reminder. Reduced keeps only the glow. Animations run only while the window or a reminder is shown."),12,90,cw-24,11,C.muted)
    local window_=W.Card(parent,col,top+280,cw,232,L("Window"))
    W.Select(window_,L("Theme"),{{value="mockup",label=L("Like the mockup")},{value="logo",label=L("Logo blue")}},prefs.theme or"mockup",12,34,cw-24,function(v)prefs.theme=v;ApplyPrefs();Refresh()end,"ui:theme")
    W.Select(window_,L("Font"),{{value="urw",label="URW Gothic"},{value="naowh",label=L("Naowh.ttf (your own file)")},{value="game",label=L("Game font")}},prefs.font or"urw",12,86,cw-24,function(v)prefs.font=v;ApplyPrefs();Refresh()end,"ui:font")
    W.Label(window_,L("Naowh.ttf is not shipped: put your own copy in Media/Fonts and restart the game."),12,142,cw-24,11,C.muted)
    W.Button(parent,L("Save settings"),col*2,top+472,cw-8,function()local v,e=ns.EditProfile(function(data)
        for _,f in ipairs(fields)do local number=tonumber(read("setting:"..f[2]));assert(number,L("Enter a number for ")..L(f[1]));if f[2]=="x"or f[2]=="y"then s.pos=s.pos or{point="CENTER",relPoint="CENTER"};s.pos[f[2]]=number else s[f[2]]=number end end;data.settings=s
    end);done(v,e,L("Settings saved"))end,true,"save-settings",{kind="primary",align="CENTER",h=40})
end
---------------------------------------------------------------------------
local function DrawProfiles(parent)
    W.Label(parent,L("Profiles"),0,0,200,20,C.text,true);W.Label(parent,L("One profile holds both content types. Imports create a separate copy."),110,6,600,12,C.muted)
    local left=W.Card(parent,0,40,300,552,L("Profiles"))
    local opts={};for name in pairs(ns.Store().profiles)do opts[#opts+1]={value=name,label=name}end;table.sort(opts,function(a,b)return a.label<b.label end)
    W.Select(left,L("Active profile"),opts,ns.Store().active,12,34,276,function(v)local a,b=ns.SelectProfile(v);done(a,b,L("Profile selected"))end,"profile-select")
    local y=96
    for i,o in ipairs(opts)do if i<=6 then
        local active=o.value==ns.Store().active
        local row=W.Panel(left,12,y,276,40,active and C.accentSoft or C.raised,active and C.accent or C.line,8)
        W.Label(row,o.label,10,7,250,13,C.text,true);W.Label(row,active and L("active")or L("saved profile"),10,23,250,11,C.muted);y=y+46
    end end
    W.Field(left,L("New profile name"),state.profileName or"",12,y+4,276,"profile-name");y=y+60
    W.Button(left,L("Create"),12,y,134,function()done(ns.CreateProfile(read("profile-name"),false))end,false,"profile-create",{align="CENTER"})
    W.Button(left,L("Copy active"),154,y,134,function()done(ns.CreateProfile(read("profile-name"),true))end,false,"profile-copy",{align="CENTER"})
    W.Button(left,L("Rename"),12,y+36,134,function()done(ns.RenameProfile(read("profile-name")))end,false,"profile-rename",{align="CENTER"})
    W.Button(left,state.confirmDelete and L("Confirm delete")or L("Delete active"),154,y+36,134,function()if not state.confirmDelete then state.confirmDelete=true;Refresh()else state.confirmDelete=false;done(ns.DeleteProfile())end end,false,"profile-delete",{kind="danger",align="CENTER"})
    local right=W.Card(parent,312,40,608,552,L("Import / export string"))
    local panel=W.Panel(right,12,34,584,420,C.background,C.line,8);local scroll=W.Frame("ScrollFrame",nil,panel);scroll:SetPoint("TOPLEFT",10,-10);scroll:SetSize(560,400)
    local text=W.Frame("EditBox",nil,scroll);text:SetMultiLine(true);text:SetFont(W.Font(false),12,"");text:SetTextColor(unpack(C.text));text:SetWidth(554);text:SetHeight(400);text:SetAutoFocus(false);text:SetMaxLetters(130000);text:SetText(state.importText or"");W.AttachScrollChild(scroll,text);text:SetScript("OnTextChanged",function(self)
        if self.GetNumLines then local ok,n=pcall(self.GetNumLines,self);if ok and type(n)=="number"then self:SetHeight(math.max(400,n*16+24));scroll:UpdateScrollChildRect()end end
    end);text:SetScript("OnEscapePressed",function(self)self:ClearFocus()end);ns.UIControls["profile-string"]=text;W.Wheel(scroll,panel,577,6,408)
    W.Button(right,L("Import profile"),424,466,172,function()local value=read("profile-string");local a,b,report=ns.Import(value);if a then ensureWorkspace();state.tab="profiles";loadView();state.importText=ns.ImportReportText(report)end;done(a,b,report and(L("Imported · migration items to review below: ")..#report.issues)or L("Profile imported"))end,true,"profile-import",{kind="primary",align="CENTER",h=34})
    W.Button(right,L("Export active"),12,466,150,function()local value,error=ns.Export();if value then text:SetText(value);text:HighlightText();text:SetFocus();state.importText=value;notify(L("Export ready · Ctrl+C copies the selected text"))else notify(error,true)end end,false,"profile-export",{align="CENTER",h=34})
    W.Button(right,L("Diagnostics"),170,466,140,function()local v=ns.Diagnostics();text:SetText(v);text:HighlightText();text:SetFocus();state.importText=v;notify(L("Diagnostics ready to copy"))end,false,"diagnostics",{align="CENTER",h=34})
    W.Label(right,L("Reads PZTK1, NSRPACK2 and NSRT Profile / EncounterAlert strings. Profile data is local to the current game client; originals are kept."),12,512,584,11,C.muted)
end
---------------------------------------------------------------------------
-- Timeline: pull and phase reminders of one raid boss on a time axis.
local function DrawTimeline(parent)
    ContentHeader(parent,L("Timeline"),L("Pull and phase reminders of one boss on a time axis. Click a marker to edit it."))
    local raids=ns.CatalogGroups("raid")
    if #raids==0 then W.Label(parent,L("No raid encounters for this client yet."),0,60,600,13,C.muted);return end
    local g=raids[1];for _,v in ipairs(raids)do if v.id==state.tlGroup then g=v end end;state.tlGroup=g.id
    local bosses=g.bosses or{};local n=bosses[1];for _,v in ipairs(bosses)do if v.id==state.tlBoss then n=v end end;state.tlBoss=n and n.id
    local go={};for _,v in ipairs(raids)do go[#go+1]={value=v.id,label=v.name}end
    W.Select(parent,nil,go,g.id,0,56,260,function(v)state.tlGroup=v;state.tlBoss=nil;Refresh()end,"tl-group")
    local bo={};for _,v in ipairs(bosses)do bo[#bo+1]={value=v.id,label=v.name}end
    if n then W.Select(parent,nil,bo,n.id,270,56,260,function(v)state.tlBoss=v;Refresh()end,"tl-boss")end
    state.tlDifficulty=state.tlDifficulty or 15
    W.Segmented(parent,{{value=15,label=L("Heroic")},{value=16,label=L("Mythic")}},state.tlDifficulty,540,56,200,function(v)state.tlDifficulty=v;Refresh()end,"tl-difficulty")
    if not n then return end
    local saved=state.difficulty;state.difficulty=state.tlDifficulty
    local ctx=entityContext("raid",g,n);local rules=timedRules(ctx);state.difficulty=saved
    local function open(key)
        state.tab="raid";loadView();state.group=g.id;state.entity=n.id;state.difficulty=state.tlDifficulty;state.mode="mechanics";state.timed=true;state.ruleKey=key;state.form=nil;Refresh()
    end
    W.Button(parent,L("+ Timed reminder"),760,56,160,function()open(nil)end,false,"tl-new",{kind="outline",align="CENTER"})
    local card=W.Card(parent,0,100,920,300,n.name.." · "..(state.tlDifficulty==16 and L("Mythic")or L("Heroic")))
    local lanes={{key="pull",label=L("Pull")}};local maxT=300
    for _,r in ipairs(rules)do local t=r.entry.trigger;maxT=math.max(maxT,(tonumber(t.delay)or 0)+30)
        if t.type=="stage"then local found=false;for _,l in ipairs(lanes)do if l.key=="stage"..tostring(t.stage)then found=true end end;if not found then lanes[#lanes+1]={key="stage"..tostring(t.stage),label=L("Phase").." "..tostring(t.stage)}end end
    end
    maxT=math.ceil(maxT/60)*60;local x0,w=96,800;local step=maxT<=360 and 30 or 60
    for t=0,maxT,step do local x=x0+w*t/maxT;W.Rect(card,x,40,1,240,t%60==0 and C.line or C.raised);local l=W.Label(card,string.format("%d:%02d",math.floor(t/60),t%60),x-20,276,40,10,C.faint);l:SetJustifyH("CENTER")end
    for i,lane in ipairs(lanes)do
        local y=44+(i-1)*44;W.Label(card,lane.label,12,y+12,80,12,C.muted);W.RoundRect(card,x0,y+18,w,4,C.raised,2)
        for _,r in ipairs(rules)do local t=r.entry.trigger
            local laneKey=(t.type=="stage")and("stage"..tostring(t.stage))or"pull"
            if laneKey==lane.key then
                local at=(t.type=="prepull"and-(tonumber(t.delay)or 0)or tonumber(t.delay)or 0)
                local x=x0+w*math.max(0,at)/maxT
                local b=W.Button(card,"",x-11,y+9,22,function()open(r.key)end,false,"tl-marker:"..r.key,{h=22,radius=11,kind="primary",tooltip=(r.entry.name or L("Timed reminder")).." · "..tostring(at).."s"})
                W.Label(card,r.entry.name or"",x+14,y+2,120,10,C.soft)
            end
        end
    end
    local list=W.Card(parent,0,412,920,180,L("Reminders on this boss"))
    if #rules==0 then W.Label(list,L("No pull or phase reminders yet. Add one with + Timed reminder."),12,36,700,12,C.muted)end
    for i,r in ipairs(rules)do if i<=8 then
        local t=r.entry.trigger;local at=t.type=="prepull"and("-"..tostring(t.delay).."s")or t.type=="stage"and("P"..tostring(t.stage).." "..tostring(t.delay).."s")or(tostring(t.delay).."s")
        W.Button(list,at.."  ·  "..(r.entry.name or L("Timed reminder")),12+((i-1)%2)*452,32+math.floor((i-1)/2)*34,440,function()open(r.key)end,false,"tl-row:"..r.key,{kind="ghost",h=30,glyph="clock"})
    end end
end
---------------------------------------------------------------------------
-- Raid sections from Northern Sky Raid Tools and Naowh Smart Reminders. Real tools first, then what is planned.
local planned={
    notes={"Notes","Shared, personal and tank notes with {time:} lines, phases and spell icons, sent to the raid.",{"Shared note with raid sync","Personal and tank notes","Reminders from MRT notes","Note displays on screen with countdown"}},
    alerts={"Boss alerts","Season encounter alerts: icons, text, bars, sounds and voice per ability.",{"Alert list per boss with on/off","Custom text, sound and voice","Test any alert","Share alerts with the raid"}},
    auras={"Auras","Debuff and buff tracking with frame glows and sounds.",{"Aura tracking on raid frames","Private aura sounds (available now: see below)","Glow and sound per aura","Stack thresholds"}},
    assign={"Assignments","Who soaks, kicks and dispels: assignments from the note to each player.",{"Soak and interrupt groups","Dispel order","Personal callouts from assignments","Import from the note"}},
    raidtools={"Raid tools","Ready check, pull and break timers, invites and group arrangement.",{"Break timer (/ndp break)","Invite by note or guild rank","Arrange groups by note","Cooldown check before pull"}},
    players={"Players","Nicknames, addon versions and the current group.",{"Nicknames shared with the raid","Addon and note version check","Missing addon warning"}},
}
local function Roster()
    local out={};local raid=IsInRaid and IsInRaid();local count=GetNumGroupMembers and GetNumGroupMembers()or 0
    if type(count)~="number"or count==0 then count=1 end
    for i=1,math.min(40,count)do
        local unit=raid and("raid"..i)or(i==1 and"player"or"party"..(i-1))
        local name=UnitName and UnitName(unit);local _,class=UnitClass and UnitClass(unit)
        if ns.Plain(name,"string")then out[#out+1]={name=name,class=ns.Plain(class,"string")and class or nil}end
    end
    return out
end
ns.Roster=Roster
local function classColor(class)
    local c=class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class];if c then return{c.r,c.g,c.b,1}end;return C.text
end
local function DrawPlanned(parent,id)
    local p=planned[id];ContentHeader(parent,L(p[1]),L(p[2]))
    local left=W.Card(parent,0,56,454,536,L("Available now"))
    local right=W.Card(parent,466,56,454,536,L("Next stage"))
    local y=36
    for _,line in ipairs(p[3])do
        local row=W.Panel(right,12,y,430,34,C.raised,C.clear,8);W.Glyph(row,"clock",10,9,16,C.warning);W.Label(row,L(line),34,10,384,13,C.soft);y=y+40
    end
    W.Label(right,L("These parts of Naowh Smart Reminders and Northern Sky Raid Tools are being rebuilt in our own code. Their original code is not copied."),12,y+6,430,11,C.muted)
    y=36
    if id=="auras"then
        W.Label(left,L("Private aura sounds")..": "..tostring(ns.AuraSoundStatus and ns.AuraSoundStatus()or"-"),12,y,430,13);y=y+28
        W.Label(left,L("Sounds for imported NSRT private auras play automatically when the aura is applied to you."),12,y,430,12,C.muted)
    elseif id=="players"or id=="assign"then
        local roster=Roster()
        W.Label(left,L("Current group").." · "..#roster,12,y,430,13,C.text,true);y=y+26
        for i,r in ipairs(roster)do if i<=20 then
            local x=12+((i-1)%2)*216;local row=W.Panel(left,x,y+math.floor((i-1)/2)*36,208,30,C.raised,C.clear,8)
            W.Dot(row,10,11,classColor(r.class));W.Label(row,r.name,26,8,176,13,classColor(r.class))
        end end
    elseif id=="raidtools"then
        W.Button(left,L("Ready check"),12,y,206,function()if DoReadyCheck then DoReadyCheck()end end,false,"rt-ready",{glyph="check"})
        W.Button(left,L("Pull timer 10 s"),230,y,212,function()if C_PartyInfo and C_PartyInfo.DoCountdown then C_PartyInfo.DoCountdown(10)end end,false,"rt-pull",{glyph="play"})
        W.Label(left,L("Ready check and pull timer use the game's own raid tools and need lead or assist."),12,y+44,430,12,C.muted)
    elseif id=="notes"or id=="alerts"then
        W.Label(left,L("Encounter-time reminders from NSRT notes and EncounterAlerts are already imported on the Profiles page and play during the fight."),12,y,430,12,C.soft)
        W.Button(left,L("Open profiles"),12,y+52,180,function()state.tab="profiles";loadView();Refresh()end,false,"go-profiles",{glyph="profiles"})
    end
end
---------------------------------------------------------------------------
local function DrawDisplay(parent)
    ContentHeader(parent,L("Display"),L("Where reminders appear and how they look. Drag the anchor to move them."))
    local s=ns.Settings();local pos=type(s.pos)=="table"and s.pos or{}
    local preview=W.Card(parent,0,56,600,300,L("Preview"))
    local stage=W.Panel(preview,12,34,576,254,C.background,C.line,8)
    local sample=W.Panel(stage,138,96,300,62,C.panel,C.accent,8);W.Icon(sample,22812,8,8,46);W.Label(sample,L("Use a defensive"),64,12,220,16,C.text,true);W.Bar(sample,64,42,220,0.6,C.accent,4)
    W.Label(stage,"x "..tostring(pos.x or 0).." · y "..tostring(pos.y or 100),10,232,300,11,C.faint)
    local actions=W.Card(parent,612,56,308,300,L("Anchors"))
    W.Button(actions,ns.AnchorsUnlocked and ns.AnchorsUnlocked()and L("Lock anchor")or L("Unlock anchor"),12,34,284,function()if ns.ToggleAnchors then ns.ToggleAnchors()end;Refresh()end,false,"display-anchor",{glyph="anchor"})
    W.Button(actions,L("Show a sample"),12,72,284,function()ns.Display({type="icon",spellID=22812,text=L("Use a defensive"),dur=4});notify(L("Preview uses currently saved settings"))end,false,"display-preview",{glyph="play"})
    W.Button(actions,L("Reset position"),12,110,284,function()done(ns.EditProfile(function(data)data.settings=data.settings or{};data.settings.pos={point="CENTER",relPoint="CENTER",x=0,y=100}end),nil,L("Position reset"))end,false,"display-reset",{glyph="reset",kind="outline"})
    W.Label(actions,L("Size, text and bar options are on the Settings page. /ndp anchors toggles the anchor too."),12,154,284,11,C.muted)
    local tips=W.Card(parent,0,368,920,224,L("What a reminder shows"))
    local rows={{"Spell icons in priority order",s.showIcon~=false},{"Reminder text",s.showText~=false},{"Duration bar",s.showBar~=false},{"Text to speech",s.voiceOn==true},{"Burst animation",(UIPrefs().anim or"full")=="full"}}
    for i,r in ipairs(rows)do local y=34+(i-1)*34;W.Dot(tips,14,y+4,r[2]and C.ok or C.faint);W.Label(tips,L(r[1]),30,y,400,13,r[2]and C.text or C.muted)end
end
---------------------------------------------------------------------------
local commands={{"/ndp","open or close the window"},{"/ndp status","state and combat source"},{"/ndp test","test a defensive reminder"},{"/ndp diag","diagnostics report"},{"/ndp sets · mythic · raid","open a section"},
    {"/ndp tl","timeline"},{"/ndp notes · alerts · auras","raid sections"},{"/ndp anchors","move the reminder anchor"},{"/ndp pull 10","pull timer"},{"/ndp rc","ready check"},
    {"/ndp roster","copy the group roster"},{"/ndp export","export the active profile"},{"/ndp anim full · reduced · off","animation mode"},{"/ndp wipe","reset all data (asks to confirm)"},{"/ndp help","this list"}}
ns.CommandHelp=commands
local function DrawDiagnostics(parent)
    W.Label(parent,L("Diagnostics"),0,0,200,20,C.text,true)
    local p=ns.ProviderStatus and ns.ProviderStatus()or{};local x=150
    for _,chip in ipairs({{"BigWigs",p.BigWigs},{"DBM",p.DBM},{"ExBoss",p.EXBoss},{L("Conflict")..": "..(ns.Conflict()or L("none")),not ns.Conflict()}})do
        local w=#chip[1]*7+34;local c=W.Panel(parent,x,0,w,26,C.panel,C.line,13);W.Dot(c,10,9,chip[2]and C.ok or C.faint);W.Label(c,chip[1],24,7,w-28,12);x=x+w+6
    end
    local cmds=W.Card(parent,0,40,360,552,L("Commands · /ndp help"))
    for i,c in ipairs(commands)do local y=34+(i-1)*33;W.Label(cmds,c[1],12,y,150,12,C.accent,true);W.Label(cmds,L(c[2]),164,y,184,12,C.soft)end
    local log=W.Card(parent,372,40,548,552,L("Report"))
    local panel=W.Panel(log,12,34,524,460,C.background,C.line,8);local scroll=W.Frame("ScrollFrame",nil,panel);scroll:SetPoint("TOPLEFT",10,-10);scroll:SetSize(500,440)
    local text=W.Frame("EditBox",nil,scroll);text:SetMultiLine(true);text:SetFont(W.Font(false),12,"");text:SetTextColor(unpack(C.soft));text:SetWidth(496);text:SetHeight(440);text:SetAutoFocus(false);text:SetMaxLetters(130000)
    text:SetText(state.diagText or ns.Diagnostics());W.AttachScrollChild(scroll,text);text:SetScript("OnEscapePressed",function(self)self:ClearFocus()end);ns.UIControls["diag-text"]=text;W.Wheel(scroll,panel,517,6,448)
    W.Button(log,L("Copy"),12,506,120,function()text:HighlightText();text:SetFocus();notify(L("Selected · Ctrl+C copies"))end,false,"diag-copy",{glyph="copy"})
    W.Button(log,L("Refresh"),140,506,120,function()state.diagText=nil;Refresh()end,false,"diag-refresh",{glyph="reset",kind="outline"})
    W.Button(log,L("Group roster"),268,506,150,function()local lines={};for _,r in ipairs(Roster())do lines[#lines+1]=r.name end;state.diagText=table.concat(lines,"\n");Refresh()end,false,"diag-roster",{glyph="players",kind="outline"})
end
---------------------------------------------------------------------------
local nav={
    {"Planner",{{"overview","Overview","overview"},{"mythic","Mythic+","mythic"},{"raid","Raids","raid"},{"sets","Defensives","sets"},{"timeline","Timeline","clock"}}},
    {"Raid",{{"notes","Notes","notes"},{"alerts","Boss alerts","alerts"},{"auras","Auras","auras"},{"assign","Assignments","assign"},{"raidtools","Raid tools","raidtools"},{"players","Players","players"}}},
    {"System",{{"display","Display","display"},{"profiles","Profiles","profiles"},{"settings","Settings","settings"},{"diag","Diagnostics","diag"}}},
}
local function go(tab)if state.tab~=tab then state.tab=tab;loadView()end;Refresh()end
local function DrawHeader()
    -- Top bar background with square bottom corners inside the rounded window.
    W.Shape(header,1,1,WIDTH-2,TOP-1,9,C.panel,"BACKGROUND",-2);W.Rect(header,1,TOP-12,WIDTH-2,12,C.panel,"BACKGROUND");W.Rect(header,0,TOP-1,WIDTH,1,C.line)
    header.logo=W.Texture(header,W.logo,14,12,36,36)
    W.Label(header,"Naowh Defensive",58,13,160,14,C.text,true);W.Label(header,"Planner",58,31,160,14,C.accent,true)
    -- Search filters encounters and mechanics on Enter.
    local search=W.Input(header,state.filter or"",224,13,272,"search",false,{h=34,radius=8,glyph="search"})
    local hint=W.Label(search.surround,L("Search: boss, mechanic, ability"),32,11,190,12,C.muted);hint:SetWordWrap(false);if(state.filter or"")~=""then hint:Hide()end
    local enter=W.Panel(search.surround,228,8,36,18,C.clear,C.line,4);W.Label(enter,"Enter",0,4,36,9,C.faint):SetJustifyH("CENTER")
    search:SetScript("OnTextChanged",function(self)if self:GetText()==""then hint:Show()else hint:Hide()end end)
    search:SetScript("OnEnterPressed",function(self)state.filter=self:GetText():match("^%s*(.-)%s*$");self:ClearFocus();if state.tab~="mythic"and state.tab~="raid"then state.tab="mythic";loadView()end;state.mode="mechanics";state.form=nil;state.ruleKey=nil;Refresh()end)
    if(state.filter or"")~=""then W.Button(header,"",462,18,24,function()state.filter="";state.form=nil;Refresh()end,false,"search-clear",{kind="ghost",h=24,glyph="close",tooltip=L("Clear search")});enter:Hide()end
    W.IconButton(header,"clock",506,13,function()go("timeline")end,"top:timeline",L("Timeline"))
    W.IconButton(header,"anchor",544,13,function()go("display")end,"top:display",L("Preview and anchors"))
    W.IconButton(header,"export",582,13,function()state.tab="diag";loadView();local lines={};for _,r in ipairs(Roster())do lines[#lines+1]=r.name end;state.diagText=table.concat(lines,"\n");Refresh()end,"top:roster",L("Export group roster"))
    -- Current specialization only: sets of other specs and classes are never shown.
    local spec=ns.Catalog.specs[state.spec]or L("Specialization");local icon=specInfo(state.spec)
    local pill=W.Panel(header,626,12,206,36,C.raised,C.accent,18)
    if icon then W.Avatar(pill,icon,5,5,26)else W.Avatar(pill,nil,5,5,26,spec:sub(1,1))end
    W.Label(pill,spec,38,11,160,13,C.text,true):SetWordWrap(false)
    W.Button(header,L("Profile")..": "..tostring(ns.Store().active or"-"),840,12,128,function()go("profiles")end,false,"header-profile",{h=36,radius=8})
    local source=providerName()
    W.Dot(header,978,26,source and C.ok or C.warning);W.Label(header,source or L("No boss mod"),990,23,82,12,source and C.muted or C.warning):SetWordWrap(false)
    W.Button(header,"",1074,14,32,function()window:Hide();if W.popup then W.popup:Hide()end end,false,"close",{kind="ghost",h=32,glyph="close",tooltip=L("Close (Esc)")})
end
local function DrawSidebar()
    W.Rect(header,1,TOP,SIDEBAR-1,HEIGHT-TOP-12,C.sidebar,"BACKGROUND");W.Shape(header,1,HEIGHT-24,SIDEBAR-1,23,9,C.sidebar,"BACKGROUND");W.Rect(header,SIDEBAR-12,HEIGHT-24,12,23,C.sidebar,"BACKGROUND")
    W.Rect(header,SIDEBAR,TOP,1,HEIGHT-TOP-1,C.line)
    local counts={mythic=contentCount("mythic"),raid=contentCount("raid"),sets=setCount("mythic")+setCount("raid")}
    local y=TOP+8
    for _,group in ipairs(nav)do
        W.Caption(header,group[1],18,y+8,140,C.faint);y=y+26
        for _,item in ipairs(group[2])do
            local count=counts[item[1]];if count==0 then count=nil end
            W.Button(header,L(item[2]),8,y,SIDEBAR-16,function()go(item[1])end,state.tab==item[1],"tab:"..item[1],{kind="nav",h=32,glyph=item[3],count=count});y=y+34
        end
    end
    W.Label(header,"v"..ns.version.." · "..ns.Client(),18,HEIGHT-44,SIDEBAR-28,11,C.faint)
    W.Label(header,"/ndp - "..L("open the window"),18,HEIGHT-28,SIDEBAR-28,11,C.faint)
end
local pages={overview=DrawOverview,profiles=DrawProfiles,settings=DrawSettings,timeline=DrawTimeline,display=DrawDisplay,diag=DrawDiagnostics}
Refresh=function()
    if not window then return end
    ensureWorkspace()
    if W.popup then W.popup:Hide()end
    W.Clear(body);W.Clear(header);W.Begin();ns.UIControls={};ns.UIScrolls={};W.scrollPositions=state.scrolls
    header=W.Frame("Frame",nil,window);header:SetPoint("TOPLEFT",0,0);header:SetSize(WIDTH,HEIGHT);header.surface=C.panel
    DrawHeader();DrawSidebar()
    body=W.Frame("Frame",nil,window);body:SetPoint("TOPLEFT",SIDEBAR+16,-(TOP+14));body:SetSize(920,600);body.surface=C.background
    if state.tab=="mythic"or state.tab=="raid"then
        if state.mode=="sets"then DrawSets(body)elseif state.mode=="manual"then DrawManual(body)else DrawMechanics(body)end
    elseif state.tab=="sets"then DrawSets(body)
    elseif pages[state.tab]then pages[state.tab](body)
    elseif planned[state.tab]then DrawPlanned(body,state.tab)
    else state.tab="overview";DrawOverview(body)end
    W.Finish();saveView();notify(state.message or L("Drafts stay when you navigate. Save explicitly to activate changes."),state.error)
    if ns.Anim then ns.Anim.Layout(window,header)end
end
function ns.RefreshWorkspace()if window and window:IsShown()then capture();saveView();Refresh()end end
function ns.OpenWorkspace(tab)
    if window then capture();saveView()end
    if not window then
        ApplyPrefs()
        window=W.Panel(UIParent,0,0,WIDTH,HEIGHT,C.background,C.line,10);window:ClearAllPoints();window:SetPoint("CENTER");window:SetFrameStrata("DIALOG");window:SetMovable(true);window:EnableMouse(true);window:RegisterForDrag("LeftButton");window:SetScript("OnDragStart",function(self)if not(InCombatLockdown and InCombatLockdown())then self:StartMoving()end end);window:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end)
        local sw=GetScreenWidth and GetScreenWidth()or 1920;local sh=GetScreenHeight and GetScreenHeight()or 1080
        window:SetScale(math.min(1,math.max(0.55,(sw-30)/WIDTH),math.max(0.55,(sh-50)/HEIGHT)))
        window:EnableKeyboard(true);window:SetPropagateKeyboardInput(true);window:SetScript("OnKeyDown",function(self,key)if key=="ESCAPE"then self:Hide();if W.popup then W.popup:Hide()end end end)
        window:SetScript("OnHide",function()capture();saveView();if W.popup then W.popup:Hide()end end)
        status=W.Label(window,"",SIDEBAR+16,HEIGHT-22,WIDTH-SIDEBAR-40,11,C.muted)
        ns.WorkspaceWindow=window
        if ns.Anim then ns.Anim.Attach(window)end
    end
    if not ns.Active()then
        if not(InCombatLockdown and InCombatLockdown())then ns.CreateProfile("Default",false)end
    end
    ensureWorkspace()
    -- The window always follows the logged-in specialization.
    local current=ns.Spec()
    if current and current~=state.spec and ns.CanEditSpec(current)then saveView();state.spec=current;loadView()end
    if tab and(pages[tab]or planned[tab]or tab=="mythic"or tab=="raid"or tab=="sets")and tab~=state.tab then saveView();state.tab=tab;loadView()end
    Refresh();window:Show()
end
function ns.ShowDiagnostics()
    ns.OpenWorkspace();state.tab="diag";loadView();state.diagText=ns.Diagnostics();Refresh()
end
