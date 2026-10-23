-- In-game workspace: separate Mythic+ / raid sets, mechanics and timed reminders.
local _,ns=...
local W=ns.Widgets
local C=W.colors
local state={tab="mythic",mode="mechanics",difficulty=15,filter="",setRows={},form={}}
ns.UIState=state
local window,body,header,status
local Refresh
local WIDTH,HEIGHT,SIDEBAR=1120,720,168
-- UI drafts are local SavedVariables, separate from the active runtime profile.
-- Navigation never commits a partial reminder or silently throws its inputs away.
local workspace,owner,profileName
local viewFields={"mode","difficulty","group","entity","ability","ruleKey","timed","form","reference","context","ruleDrafts","setKey","setRows","setName","setDrafts","newSpell","settings","settingFields","manual","profileName","importText","confirmDelete","confirmCopy","scrolls"}
local formKeys={"name","leadTime","delay","phase","counter","duration","text","displaySpellID","player","glowTarget"}
local function viewKey()return state.tab..":"..tostring((state.tab=="mythic"or state.tab=="raid")and state.spec or"general")end
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
        state.setDrafts[state.setKey or"new"]={name=state.setName,rows=ns.Clone(state.setRows),newSpell=state.newSpell}
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
    state.tab=workspace.tab or"mythic";state.spec=workspace.spec or ns.Spec()or 104;loadView()
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
local function scope()return state.tab=="raid"and"raid"or"mythic"end
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
    local draft=not fresh and state.setDrafts and state.setDrafts[key or"new"]
    if draft then state.setName=draft.name;state.setRows=ns.Clone(draft.rows);state.newSpell=draft.newSpell;return end
    state.setName=p and p.name or"New defensive set"
    state.newSpell=""
    for _,spell in ipairs(p and p.list or{})do state.setRows[#state.setRows+1]={spellID=spell,together=ns.Get(p.together,spell)==true,enabled=not ns.Get(p.disabled,spell)}end
end
local function ContentHeader(parent,title,subtitle)
    W.Label(parent,title,0,0,560,20);W.Label(parent,subtitle,0,28,600,11,C.muted)
end
local function ModeSwitch(parent)
    W.Segmented(parent,{{value="mechanics",label="Mechanics"},{value="sets",label="Defensive sets"}},state.mode=="sets"and"sets"or"mechanics",620,0,300,function(v)state.mode=v;Refresh()end,"mode")
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
    ContentHeader(parent,scope()=="mythic"and"Mythic+ defensive sets"or"Raid defensive sets","Each specialization and content type keeps its own sets. The first ready ability wins; Together abilities are called as one.")
    ModeSwitch(parent)
    local sets=ns.ScopePresets(ns.Active(),scope(),state.spec);local options=rowsOptions(sets)
    if state.setKey and not sets[state.setKey]then chooseSet(nil)end
    if not state.setName then chooseSet(options[1]and options[1].value)end
    -- Copy the whole spec setup (both content types) onto another specialization.
    local specs={};for id,label in pairs(ns.Catalog.specs)do if id~=state.spec then specs[#specs+1]={value=id,label="Copy setup to "..label}end end;table.sort(specs,function(a,b)return a.label<b.label end)
    if state.confirmCopy then
        W.Button(parent,"Replace "..(ns.Catalog.specs[state.confirmCopy]or"spec").."?",620,56,200,function()local target=state.confirmCopy;state.confirmCopy=nil;done(ns.CopySpecSetup(state.spec,target),nil,"Setup copied to "..(ns.Catalog.specs[target]or"spec"))end,false,"copy-spec-confirm",{kind="primary"})
        W.Button(parent,"Cancel",828,56,92,function()state.confirmCopy=nil;Refresh()end,false,"copy-spec-cancel")
    else
        W.Select(parent,nil,specs,nil,620,56,300,function(v)state.confirmCopy=v;Refresh()end,"copy-spec");ns.UIControls["copy-spec"].label:SetText("Copy this spec's setup to...")
    end
    local list=W.Scroll(parent,0,96,240,460,"sets:list")
    W.Label(list,"SETS",8,8,200,10,C.muted)
    for i,o in ipairs(options)do
        local p=sets[o.value];local b=W.Button(list,o.label,0,28+(i-1)*52,212,function()chooseSet(o.value);Refresh()end,o.value==state.setKey,"set:"..o.value,{h=46,marker=true,badge=ns.SetUses and ns.SetUses(scope(),state.spec,o.value)})
        b.label:ClearAllPoints();b.label:SetPoint("TOPLEFT",b,"TOPLEFT",10,-8)
        for j,spell in ipairs(p.list or{})do if j<=6 then W.Icon(b,spell,10+(j-1)*20,26,16)end end
    end;list:SetHeight(math.max(1,36+#options*52))
    W.Button(parent,"+ New set",0,566,116,function()chooseSet(nil,true);Refresh()end,false,"new-set")
    W.Button(parent,"Duplicate",124,566,116,function()state.setKey=nil;state.setName=(state.setName or"Set").." copy";Refresh()end,false,"copy-set")
    local panel=W.Panel(parent,252,96,668,460)
    W.Field(panel,"SET NAME",state.setName,16,14,400,"set-name")
    if state.setKey and ns.SetUses then W.Label(panel,"Used by "..ns.SetUses(scope(),state.spec,state.setKey).." reminders",430,36,220,11,C.muted)end
    W.Heading(panel,"PRIORITY ORDER",16,72,636)
    local content=W.Scroll(panel,12,94,644,218,"sets:abilities",C.background)
    for i,row in ipairs(state.setRows)do
        local y=(i-1)*46;local r=W.Panel(content,0,y,612,42,C.raised)
        W.Label(r,tostring(i),10,15,20,12,C.muted);W.Icon(r,row.spellID,32,6,30);W.Label(r,name(row.spellID),72,7,200,12);W.Label(r,tostring(row.spellID),72,24,200,10,C.muted)
        W.Toggle(r,"On",row.enabled,270,9,64,function(v)row.enabled=v end,"set-enabled:"..i)
        W.Toggle(r,"Together",row.together,344,9,102,function(v)row.together=v end,"set-together:"..i)
        W.Button(r,"^",464,7,30,function()if i>1 then state.setRows[i],state.setRows[i-1]=state.setRows[i-1],state.setRows[i]end;state.setName=read("set-name");Refresh()end,false,"set-up:"..i,{h=28,align="CENTER",tooltip="Move up"})
        W.Button(r,"v",498,7,30,function()if i<#state.setRows then state.setRows[i],state.setRows[i+1]=state.setRows[i+1],state.setRows[i]end;state.setName=read("set-name");Refresh()end,false,"set-down:"..i,{h=28,align="CENTER",tooltip="Move down"})
        W.Button(r,"x",538,7,30,function()table.remove(state.setRows,i);state.setName=read("set-name");Refresh()end,false,"set-remove:"..i,{h=28,align="CENTER",kind="danger",tooltip="Remove"})
    end;content:SetHeight(math.max(1,#state.setRows*46))
    if #state.setRows==0 then W.Label(content,"Add defensives from your spellbook below, or enter a spell ID.",12,14,560,12,C.muted)end
    W.Heading(panel,"ADD FROM YOUR SPELLBOOK",16,324,636)
    local x=16;local ids={};for id in pairs(ns.Catalog.spellNames)do if knownSpell(id)then ids[#ids+1]=id end end;table.sort(ids)
    local inSet={};for _,r in ipairs(state.setRows)do inSet[r.spellID]=true end
    local shown=0
    for _,id in ipairs(ids)do if not inSet[id]and shown<17 then
        local b=W.Button(panel,"",x,346,34,function()setRowsAdd(id)end,false,"suggest:"..id,{h=34,tooltip=name(id)});W.Icon(b,id,3,3,28);x=x+37;shown=shown+1
    end end
    if shown==0 then W.Label(panel,"No known catalog defensives to suggest for this character.",16,356,600,11,C.muted)end
    W.Field(panel,"OR ADD BY SPELL ID",state.newSpell or"",16,392,210,"new-spell")
    W.Button(panel,"Add ability",236,408,120,function()local spell=tonumber(read("new-spell"));if not spell or spell<1 or spell%1~=0 then notify("Enter a positive integer spell ID",true);return end;setRowsAdd(spell)end,false,"add-spell")
    W.Button(parent,"Delete set",252,566,116,function()local key=state.setKey;local a,b=ns.DeleteSet(scope(),state.spec,key);if a then state.setDrafts[key or"new"]=nil;chooseSet(nil,true)end;done(a,b,"Set deleted")end,false,"delete-set",{kind="danger"})
    W.Button(parent,"Test set",600,566,120,function()local preset={list={},together={},disabled={}};for _,r in ipairs(state.setRows)do preset.list[#preset.list+1]=r.spellID;if r.together then preset.together[r.spellID]=true end;if not r.enabled then preset.disabled[r.spellID]=true end end;local spells=ns.Pick(preset);if #spells==0 then for _,r in ipairs(state.setRows)do if r.enabled then spells={r.spellID};break end end end;ns.Display({type="icon",spells=spells,text="Set preview",dur=4});notify("Preview only; no encounter trigger was fired")end,false,"test-set")
    W.Button(parent,"Save set",730,566,190,function()local oldKey=state.setKey;local a,b=ns.SaveSet(scope(),state.spec,oldKey,read("set-name"),state.setRows);if a then state.setDrafts[oldKey or"new"]=nil;state.setKey=a;state.setName=read("set-name")end;done(a,b,"Defensive set saved")end,true,"save-set",{kind="primary",align="CENTER"})
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
    local box=W.Panel(parent,x,y,w,56,C.background)
    local spells={}
    if form.action=="defensive"then local p=ns.ScopePresets(ns.Active(),ctx.scope,ctx.spec)[form.preset];for i,s in ipairs(p and p.list or{})do if i<=4 then spells[#spells+1]=s end end
    elseif form.action=="icon"or form.action=="circle"then spells={tonumber(form.displaySpellID)or ctx.spell}end
    local ix=10;for i,s in ipairs(spells)do local icon=W.Icon(box,s,ix,10,32);if i>1 then icon:SetVertexColor(0.55,0.55,0.55,1)end;ix=ix+36 end
    local text=form.text~=""and form.text or(spells[1]and name(spells[1]))or(ctx.abilityName or"Reminder")
    if form.action=="chat"then text="(sound only) "..text end
    W.Label(box,text,ix+4,12,w-ix-60,14);W.Label(box,tostring(form.duration).."s",w-50,14,40,12,C.brand)
    W.Rect(box,ix+4,40,w-ix-16,4,C.line);W.Rect(box,ix+4,40,math.floor((w-ix-16)*0.6),4,form.action=="raidframeGlow"and C.brand or C.accent)
    return box
end
local function DrawInspector(parent,ctx,rules)
    local form=state.form;local p=W.Panel(parent,480,96,440,504);local inner=416
    local function collect()for _,k in ipairs(formKeys)do local c=ns.UIControls["rule:"..k];if c then form[k]=c:GetText()end end end
    if ctx.spell then W.Icon(p,ctx.spell,12,12,32)else W.Rect(p,12,12,32,32,C.accentSoft)end
    W.Label(p,ctx.abilityName or"Timed reminder",54,12,270,14);W.Label(p,ctx.spell and("Spell "..ctx.spell)or("Encounter "..tostring(ctx.encounter).." · timed"),54,32,270,10,C.muted)
    W.Toggle(p,"Enabled",form.enabled,330,15,98,function(v)form.enabled=v end,"rule:enabled")
    local y=56
    if #rules>0 and not state.timed then
        local o={{value="new",label="+ Another reminder for this mechanic"}};for _,r in ipairs(rules)do o[#o+1]={value=r.key,label=r.entry.name or tostring(r.key)}end
        W.Select(p,nil,o,state.reference and state.reference.key or"new",12,y,inner,function(v)state.ruleKey=v;state.form=nil;Refresh()end,"rule-choice");y=y+38
    end
    Preview(p,ctx,form,12,y,inner);y=y+62
    W.Label(p,Summary(ctx,form),12,y,inner,11,C.muted);y=y+36
    local content=W.Scroll(p,8,y,424,450-y,"inspector",C.panel)
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
    W.Button(p,"Test",12,462,76,function()collect();local spell=tonumber(form.displaySpellID);if form.action=="defensive"then local preset=ns.ScopePresets(ns.Active(),ctx.scope,ctx.spec)[form.preset];spell=preset and preset.list[1]end;ns.Display({type=spell and"icon"or"text",spellID=spell,text=form.text~=""and form.text or"Reminder preview",dur=tonumber(form.duration)or 4,sound=form.sound,tts=form.tts});notify("Display preview; verify the mechanic in game")end,false,"test-rule",{align="CENTER"})
    W.Button(p,"Delete",96,462,86,function()local a,b=ns.DeleteRule(ctx,state.reference);if a then state.ruleDrafts[ruleKey(ctx,state.ruleKey)]=nil;state.reference=nil;state.ruleKey="new";state.form=InitialForm(ctx)end;done(a,b,"Reminder deleted")end,false,"delete-rule",{kind="danger",align="CENTER"})
    W.Button(p,"Save reminder",258,462,170,function()collect();local key,error=ns.SaveRule(ctx,form,state.reference);if key then state.ruleDrafts[ruleKey(ctx,state.ruleKey)]=nil;state.ruleDrafts[ruleKey(ctx,key)]=nil;state.ruleKey=key;state.form=nil end;done(key,error,"Reminder saved")end,true,"save-rule",{kind="primary",align="CENTER"})
end
local function DrawManual(parent)
    ContentHeader(parent,"Add an encounter mechanic","Use verified IDs from your installed client. Retail catalogs are not applied to Forever.")
    local a=state.manual or{kind="boss",groupName="",npcName="",npcID="",mapID="",encounterId="",spellID="",spellName=""};state.manual=a
    local keys={{"DUNGEON / RAID NAME","groupName"},{"NPC / BOSS NAME","npcName"},{"NPC ID","npcID"},{"INSTANCE MAP ID (M+)","mapID"},{"ENCOUNTER ID (BOSS)","encounterId"},{"MECHANIC SPELL ID","spellID"},{"ABILITY NAME (OPTIONAL)","spellName"}}
    local panel=W.Panel(parent,0,64,920,420)
    for i,row in ipairs(keys)do W.Field(panel,row[1],a[row[2]],20+(i-1)%2*450,20+math.floor((i-1)/2)*70,420,"manual:"..row[2])end
    W.Select(panel,"TYPE",{{value="boss",label="Boss"},{value="trash",label="Trash (M+ only)"}},a.kind,470,230,420,function(v)a.kind=v end,"manual:kind")
    W.Button(parent,"Back",0,500,100,function()state.mode="mechanics";Refresh()end,false,"manual-back")
    W.Button(parent,"Save mechanic",720,500,200,function()for _,r in ipairs(keys)do a[r[2]]=read("manual:"..r[2])end;a.scope=scope();if a.scope=="raid"then a.kind="boss"end;local id,error=ns.AddManualMechanic(a);if id then state.group=id;state.mode="mechanics";state.entity=nil end;done(id,error,"Mechanic added")end,true,"save-manual",{kind="primary",align="CENTER"})
end
local function DrawMechanics(parent)
    local content=scope();ContentHeader(parent,content=="mythic"and"Mythic+ mechanics"or"Raid encounters",content=="mythic"and"Bind your defensive sets to boss and trash abilities."or"Mechanic, pull and phase reminders for Heroic and Mythic.")
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
    W.Button(parent,"+ Custom mechanic",760,56,160,function()state.mode="manual";Refresh()end,false,"add-mechanic",{kind="ghost",align="CENTER"})
    if not g then W.Label(parent,state.filter~=""and("Nothing matches \""..state.filter.."\".")or"No encounters for this client yet. Add your own verified IDs.",0,110,600,13,C.muted);return end
    local entities=g and(g.npcs or g.bosses)or{};if content=="raid"and g then entities=g.bosses end
    local visible={};for _,v in ipairs(entities)do if entityMatches(v)then visible[#visible+1]=v end end
    local n=visible[1];for _,v in ipairs(visible)do if v.id==state.entity then n=v end end
    if n then state.entity=n.id end
    local list=W.Scroll(parent,0,96,226,504,"mechanics:entities")
    local ly=6
    local function entityButtons(kind,title)
        local any=false
        for _,v in ipairs(visible)do if(v.kind=="trash")==(kind=="trash")then
            if not any then W.Label(list,title,8,ly+2,190,10,C.muted);ly=ly+20;any=true end
            W.Button(list,v.name,0,ly,198,function()state.entity=v.id;state.timed=false;state.ability=nil;state.form=nil;state.ruleKey=nil;Refresh()end,n==v,"entity:"..v.id,{h=32,marker=true,badge=entityCount(content,g,v)});ly=ly+36
        end end
        if any then ly=ly+6 end
    end
    entityButtons("boss","BOSSES");entityButtons("trash","TRASH");list:SetHeight(ly+4)
    local abilities={};for _,a in ipairs(allowedAbilities(content,n))do if matches(n.name)or matches(name(a.id,a.name))then abilities[#abilities+1]=a end end
    local ability=abilities[1];for _,a in ipairs(abilities)do if a.id==state.ability then ability=a end end
    local ctx=entityContext(content,g,n,ability)
    if ability then state.ability=ability.id end
    local mechanics=W.Scroll(parent,234,96,238,504,"mechanics:abilities");W.Label(mechanics,"MECHANICS",8,8,200,10,C.muted)
    local my=28
    for _,a in ipairs(abilities)do W.Button(mechanics,name(a.id,a.name),0,my,210,function()state.ability=a.id;state.form=nil;state.ruleKey=nil;state.timed=false;Refresh()end,ability==a and not state.timed,"ability:"..a.id,{h=32,icon=a.id,marker=true,badge=abilityCount(content,g,n,a)});my=my+36 end
    if content=="raid"and n then
        W.Label(mechanics,"TIMED",8,my+8,200,10,C.muted);my=my+28
        -- Existing pull/phase reminders remain visible even when no spell is attached.
        for _,r in ipairs(timedRules(ctx))do
            local t=r.entry.trigger;local at=t.type=="prepull"and("-"..tostring(t.delay).."s")or t.type=="stage"and("P"..tostring(t.stage).." "..tostring(t.delay).."s")or(tostring(t.delay).."s")
            W.Button(mechanics,at.."  "..(r.entry.name or"Timed reminder"),0,my,210,function()state.timed=true;state.ruleKey=r.key;state.form=nil;Refresh()end,state.ruleKey==r.key and state.timed,"timed:"..r.key,{h=32,marker=true});my=my+36
        end
        W.Button(mechanics,"+ Timed reminder",0,my,210,function()state.timed=true;state.ruleKey=nil;state.form=nil;Refresh()end,state.timed and state.ruleKey=="new","new-timed",{h=32,kind="ghost"});my=my+38
    end;mechanics:SetHeight(my+8)
    if state.timed then ctx.spell=nil;ctx.abilityName="Timed encounter reminder"end
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
    else W.Label(parent,"Choose an encounter and mechanic, or add your own verified IDs.",496,140,400,13,C.muted)end
end
local function DrawOverview(parent)
    local spec=ns.Catalog.specs[state.spec]or"Specialization";ContentHeader(parent,"Overview",spec.." · reminders per dungeon and raid. Click a card to open it.")
    local y=56
    for _,content in ipairs({"mythic","raid"})do
        local groups=ns.CatalogGroups(content)
        local sets=0;for _ in pairs(ns.ScopePresets(ns.Active(),content,state.spec))do sets=sets+1 end
        W.Heading(parent,(content=="mythic"and"MYTHIC+"or"RAIDS").."  ·  "..sets.." defensive sets",0,y,920);y=y+26
        if #groups==0 then W.Label(parent,"No encounters for this client. Add custom mechanics from the "..(content=="mythic"and"Mythic+"or"Raids").." page.",0,y,900,12,C.muted);y=y+28 end
        for i,g in ipairs(groups)do
            local x=((i-1)%3)*308;local count=groupCount(content,g);local entities=g.npcs or g.bosses or{}
            local covered=0;for _,n in ipairs(entities)do if entityCount(content,g,n)>0 then covered=covered+1 end end
            local b=W.Button(parent,g.name,x,y,300,function()state.tab=content;loadView();state.group=g.id;state.mode="mechanics";state.entity=nil;state.ability=nil;state.form=nil;state.ruleKey=nil;state.timed=false;Refresh()end,false,"overview:"..content..":"..tostring(g.id),{h=56,badge=count})
            b.label:ClearAllPoints();b.label:SetPoint("TOPLEFT",b,"TOPLEFT",12,-11)
            W.Label(b,covered.." of "..#entities.." "..(content=="mythic"and"bosses / packs"or"bosses").." have reminders",12,32,270,10,covered>0 and C.muted or C.warning)
            if i%3==0 or i==#groups then y=y+64 end
        end
        y=y+10
    end
end
local function DrawSettings(parent)
    ContentHeader(parent,"General settings","One display style across both content types. Defensive sets stay separate.")
    local s=state.settings or ns.Clone(ns.Settings());state.settings=s;state.settingFields=state.settingFields or{}
    local panel=W.Panel(parent,0,56,920,456)
    W.Heading(panel,"DISPLAY",20,16,420);W.Heading(panel,"SIZE AND POSITION",480,16,420)
    local flags={{"Enable reminders","enabled"},{"Show spell icons","showIcon"},{"Show reminder text","showText"},{"Show duration bar","showBar"},{"Enable text to speech","voiceOn"},{"Call external when no defensive is ready","fallbackOn"}}
    for i,f in ipairs(flags)do local value=s[f[2]];if value==nil then value=f[2]~="voiceOn"and f[2]~="fallbackOn"end;W.Toggle(panel,f[1],value,20,44+(i-1)*38,420,function(v)s[f[2]]=v end,"setting:"..f[2])end
    local fields={{"ICON SIZE","iconSize",42},{"TEXT SIZE","textSize",14},{"VOICE VOLUME","voiceVol",100},{"X POSITION","x",0},{"Y POSITION","y",100}}
    for i,f in ipairs(fields)do local v=(f[2]=="x"or f[2]=="y")and s.pos and s.pos[f[2]]or s[f[2]];W.Field(panel,f[1],state.settingFields[f[2]]or v or f[3],480,44+(i-1)*60,420,"setting:"..f[2])end
    W.Heading(panel,"BOSS MODS",20,290,420)
    W.Select(panel,"BOSS MOD SOURCE",{{value="bigwigs",label="BigWigs / LittleWigs"},{value="dbm",label="DBM"}},s.bossSource or"bigwigs",20,318,420,function(v)s.bossSource=v end,"setting:bossSource")
    W.Label(panel,"Boss mechanics require matching provider messages/timers.\nExBoss supplies trash countdowns. Readiness uses public game APIs.",20,382,425,11,C.muted)
    W.Button(parent,"Preview display",0,526,160,function()ns.Display({type="icon",spellID=22812,text="Use a defensive",dur=4,tts=s.voiceOn});notify("Preview uses currently saved settings")end,false,"preview-display",{align="CENTER"})
    W.Button(parent,"Save settings",720,526,200,function()local v,e=ns.EditProfile(function(data)
        for _,f in ipairs(fields)do local number=tonumber(read("setting:"..f[2]));assert(number,"Enter a number for "..f[1]);if f[2]=="x"or f[2]=="y"then s.pos=s.pos or{point="CENTER",relPoint="CENTER"};s.pos[f[2]]=number else s[f[2]]=number end end;data.settings=s
    end);done(v,e,"Settings saved")end,true,"save-settings",{kind="primary",align="CENTER"})
end
local function DrawProfiles(parent)
    ContentHeader(parent,"Profiles","One profile holds both content types. Imports create a separate copy.")
    local opts={};for name in pairs(ns.Store().profiles)do opts[#opts+1]={value=name,label=name}end;table.sort(opts,function(a,b)return a.label<b.label end)
    W.Select(parent,"ACTIVE PROFILE",opts,ns.Store().active,0,56,400,function(v)local a,b=ns.SelectProfile(v);done(a,b,"Profile selected")end,"profile-select")
    W.Field(parent,"NEW PROFILE NAME",state.profileName or"",420,56,500,"profile-name")
    W.Button(parent,"Create",0,118,130,function()done(ns.CreateProfile(read("profile-name"),false))end,false,"profile-create",{align="CENTER"})
    W.Button(parent,"Copy active",140,118,130,function()done(ns.CreateProfile(read("profile-name"),true))end,false,"profile-copy",{align="CENTER"})
    W.Button(parent,"Rename",280,118,120,function()done(ns.RenameProfile(read("profile-name")))end,false,"profile-rename",{align="CENTER"})
    W.Button(parent,state.confirmDelete and"Confirm delete"or"Delete active",420,118,160,function()if not state.confirmDelete then state.confirmDelete=true;Refresh()else state.confirmDelete=false;done(ns.DeleteProfile())end end,false,"profile-delete",{kind="danger",align="CENTER"})
    W.Heading(parent,"IMPORT / EXPORT STRING",0,170,920)
    local panel=W.Panel(parent,0,196,920,244,C.background);local scroll=W.Frame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",10,-10);scroll:SetSize(884,224)
    local text=W.Frame("EditBox",nil,scroll);text:SetMultiLine(true);text:SetFont(STANDARD_TEXT_FONT or"Fonts\\FRIZQT__.TTF",12,"");text:SetTextColor(unpack(C.text));text:SetWidth(864);text:SetHeight(214);text:SetAutoFocus(false);text:SetMaxLetters(130000);text:SetText(state.importText or"");W.AttachScrollChild(scroll,text);text:SetScript("OnTextChanged",function(self)
        if self.GetNumLines then local ok,n=pcall(self.GetNumLines,self);if ok and type(n)=="number"then self:SetHeight(math.max(224,n*16+24));scroll:UpdateScrollChildRect()end end
    end);text:SetScript("OnEscapePressed",function(self)self:ClearFocus()end);ns.UIControls["profile-string"]=text
    W.Button(parent,"Import profile",0,452,180,function()local value=read("profile-string");local a,b,report=ns.Import(value);if a then ensureWorkspace();state.tab="profiles";loadView();state.importText=ns.ImportReportText(report)end;done(a,b,report and("Imported · "..#report.issues.." migration items to review below")or"Profile imported")end,true,"profile-import",{kind="primary",align="CENTER"})
    W.Button(parent,"Export active",192,452,180,function()local value,error=ns.Export();if value then text:SetText(value);text:HighlightText();text:SetFocus();state.importText=value;notify("Export ready · Ctrl+C copies the selected text")else notify(error,true)end end,false,"profile-export",{align="CENTER"})
    W.Button(parent,"Diagnostics",384,452,160,function()local v=ns.Diagnostics();text:SetText(v);text:HighlightText();text:SetFocus();state.importText=v;notify("Diagnostics ready to copy")end,false,"diagnostics",{align="CENTER"})
    W.Label(parent,"PZTK1, NSRPACK2 and full NSRT Profile / EncounterAlert imports. Review migration notes.\nProfile data is local to the current game client. Original profiles are retained.",0,500,900,11,C.muted)
end
local function DrawHeader()
    W.Rect(header,0,0,WIDTH,56,C.sidebar);W.Rect(header,0,56,WIDTH,1,C.line)
    W.Texture(header,W.logo,14,8,40,40)
    W.Label(header,"NAOWH DEFENSIVE",62,12,200,13);W.Label(header,"PLANNER",62,30,200,13,C.brand)
    -- Search filters encounters and mechanics on Enter.
    local search=W.Input(header,state.filter or"",210,13,330,"search")
    local hint=W.Label(search.surround,"Search bosses and mechanics, press Enter",10,9,300,11,C.muted);if(state.filter or"")~=""then hint:Hide()end
    search:SetScript("OnTextChanged",function(self)if self:GetText()==""then hint:Show()else hint:Hide()end end)
    search:SetScript("OnEnterPressed",function(self)state.filter=self:GetText():match("^%s*(.-)%s*$");self:ClearFocus();if state.tab~="mythic"and state.tab~="raid"then state.tab="mythic";loadView()end;state.mode="mechanics";state.form=nil;state.ruleKey=nil;Refresh()end)
    if(state.filter or"")~=""then W.Button(header,"x",546,13,30,function()state.filter="";state.form=nil;Refresh()end,false,"search-clear",{kind="ghost",align="CENTER",tooltip="Clear search"})end
    local providers=ns.ProviderStatus and ns.ProviderStatus()or{};local source=providers.BigWigs and"BigWigs"or providers.DBM and"DBM"or nil
    W.Rect(header,596,24,8,8,source and C.ok or C.warning);W.Label(header,source or"No boss mod",610,22,100,11,source and C.muted or C.warning)
    local specs={};for id,label in pairs(ns.Catalog.specs)do specs[#specs+1]={value=id,label=label}end;table.sort(specs,function(a,b)return a.label<b.label end)
    local icon=specInfo(state.spec);W.Texture(header,icon or 134400,722,14,28,28)
    W.Select(header,nil,specs,state.spec,756,13,300,function(v)state.spec=v;loadView();Refresh()end,"specialization")
    W.Button(header,"x",1076,13,30,function()window:Hide();if W.popup then W.popup:Hide()end end,false,"close",{kind="ghost",align="CENTER",tooltip="Close (Esc)"})
end
local function DrawSidebar()
    W.Rect(header,0,57,SIDEBAR,HEIGHT-57,C.sidebar);W.Rect(header,SIDEBAR,57,1,HEIGHT-57,C.line)
    local tabs={{"overview","Overview"},{"mythic","Mythic+",contentCount("mythic")},{"raid","Raids",contentCount("raid")},{"profiles","Profiles"},{"settings","Settings"}}
    for i,t in ipairs(tabs)do W.Button(header,t[2],8,72+(i-1)*40,SIDEBAR-16,function()if state.tab~=t[1]then state.tab=t[1];loadView()end;Refresh()end,state.tab==t[1],"tab:"..t[1],{kind="nav",h=34,badge=t[3]})end
    W.Label(header,ns.Client():upper().."  ·  "..ns.version,16,HEIGHT-58,SIDEBAR-24,10,C.muted)
    W.Label(header,"Profile: "..tostring(ns.Store().active or"none"),16,HEIGHT-40,SIDEBAR-24,10,C.muted)
end
Refresh=function()
    if not window then return end
    ensureWorkspace()
    if W.popup then W.popup:Hide()end
    W.Clear(body);W.Clear(header);W.Begin();ns.UIControls={};ns.UIScrolls={};W.scrollPositions=state.scrolls
    header=W.Frame("Frame",nil,window);header:SetPoint("TOPLEFT",0,0);header:SetSize(WIDTH,HEIGHT)
    DrawHeader();DrawSidebar()
    body=W.Frame("Frame",nil,window);body:SetPoint("TOPLEFT",SIDEBAR+16,-72);body:SetSize(920,604)
    if state.tab=="mythic"or state.tab=="raid"then
        if state.mode=="sets"then DrawSets(body)elseif state.mode=="manual"then DrawManual(body)else DrawMechanics(body)end
    elseif state.tab=="overview"then DrawOverview(body)
    elseif state.tab=="profiles"then DrawProfiles(body)else DrawSettings(body)end
    W.Finish();saveView();notify(state.message or"Drafts stay when you navigate. Save explicitly to activate changes.",state.error)
end
function ns.OpenWorkspace()
    if window then capture();saveView()end
    if not window then
        window=W.Panel(UIParent,0,0,WIDTH,HEIGHT,C.background,C.lineStrong);window:ClearAllPoints();window:SetPoint("CENTER");window:SetFrameStrata("DIALOG");window:SetMovable(true);window:EnableMouse(true);window:RegisterForDrag("LeftButton");window:SetScript("OnDragStart",function(self)if not(InCombatLockdown and InCombatLockdown())then self:StartMoving()end end);window:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end)
        local sw=GetScreenWidth and GetScreenWidth()or 1920;local sh=GetScreenHeight and GetScreenHeight()or 1080
        window:SetScale(math.min(1,math.max(0.55,(sw-30)/WIDTH),math.max(0.55,(sh-50)/HEIGHT)))
        window:EnableKeyboard(true);window:SetPropagateKeyboardInput(true);window:SetScript("OnKeyDown",function(self,key)if key=="ESCAPE"then self:Hide();if W.popup then W.popup:Hide()end end end)
        window:SetScript("OnHide",function()capture();saveView();if W.popup then W.popup:Hide()end end)
        status=W.Label(window,"",SIDEBAR+16,HEIGHT-26,WIDTH-SIDEBAR-40,11,C.muted)
        ns.WorkspaceWindow=window
    end
    if not ns.Active()then
        if not(InCombatLockdown and InCombatLockdown())then ns.CreateProfile("Default",false)end
    end
    Refresh();window:Show()
end
function ns.ShowDiagnostics()
    ns.OpenWorkspace();state.tab="profiles";state.importText=ns.Diagnostics();Refresh()
end
