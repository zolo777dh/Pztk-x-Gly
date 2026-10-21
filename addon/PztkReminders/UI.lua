-- In-game workspace: separate Mythic+ / raid sets, mechanics and timed reminders.
local _,ns=...
local W=ns.Widgets
local state={tab="mythic",mode="mechanics",difficulty=15,filter="",setRows={},form={}}
ns.UIState=state
local window,body,header,status
local Refresh
local function notify(text,error)
    state.message=text;state.error=error;if status then status:SetText(text);status:SetTextColor(unpack(error and W.colors.warning or W.colors.muted))end
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
local function chooseSet(key)
    state.setKey=key;state.setRows={};local p=ns.ScopePresets(ns.Active(),scope(),state.spec)[key]
    state.setName=p and p.name or"New defensive set"
    for _,spell in ipairs(p and p.list or{})do state.setRows[#state.setRows+1]={spellID=spell,together=ns.Get(p.together,spell)==true,enabled=not ns.Get(p.disabled,spell)}end
end
local function ContentHeader(parent,title,subtitle)
    W.Label(parent,title,0,0,700,21);W.Label(parent,subtitle,0,28,810,11,W.colors.muted)
end
local function DrawSets(parent)
    ContentHeader(parent,scope()=="mythic"and"Mythic+ defensive sets"or"Raid defensive sets","Separate sets for each specialization and content type. Use the arrows to change priority.")
    local sets=ns.ScopePresets(ns.Active(),scope(),state.spec);local options=rowsOptions(sets)
    if state.setKey and not sets[state.setKey]then chooseSet(nil)end
    if not state.setName then chooseSet(options[1]and options[1].value)end
    local list=W.Scroll(parent,0,60,205,452)
    for i,o in ipairs(options)do W.Button(list,o.label,0,(i-1)*35,177,function()chooseSet(o.value);Refresh()end,o.value==state.setKey,"set:"..o.value)end;list:SetHeight(math.max(1,#options*35))
    W.Button(parent,"+ New set",0,522,97,function()chooseSet(nil);Refresh()end,false,"new-set")
    W.Button(parent,"Copy",103,522,102,function()state.setKey=nil;state.setName=(state.setName or"Set").." copy";Refresh()end,false,"copy-set")
    local panel=W.Panel(parent,218,60,650,452)
    W.Field(panel,"SET NAME",state.setName,14,12,420,"set-name")
    W.Label(panel,"Priority order · first ready ability, or the ready Together group",14,71,600,12,W.colors.muted)
    local content=W.Scroll(panel,12,98,625,280)
    for i,row in ipairs(state.setRows)do
        local y=(i-1)*48;local r=W.Panel(content,0,y,594,43,W.colors.raised);W.Icon(r,row.spellID,8,8,26);W.Label(r,name(row.spellID),43,7,220,12);W.Label(r,tostring(row.spellID),43,24,200,10,W.colors.muted)
        W.Toggle(r,"On",row.enabled,268,9,64,function(v)row.enabled=v end,"set-enabled:"..i)
        W.Toggle(r,"Together",row.together,337,9,105,function(v)row.together=v end,"set-together:"..i)
        W.Button(r,"^",452,6,33,function()if i>1 then state.setRows[i],state.setRows[i-1]=state.setRows[i-1],state.setRows[i]end;state.setName=read("set-name");Refresh()end,false,"set-up:"..i)
        W.Button(r,"v",488,6,33,function()if i<#state.setRows then state.setRows[i],state.setRows[i+1]=state.setRows[i+1],state.setRows[i]end;state.setName=read("set-name");Refresh()end,false,"set-down:"..i)
        W.Button(r,"x",524,6,33,function()table.remove(state.setRows,i);state.setName=read("set-name");Refresh()end,false,"set-remove:"..i)
    end;content:SetHeight(math.max(1,#state.setRows*48))
    W.Field(panel,"ADD ABILITY BY SPELL ID","",14,389,210,"new-spell")
    W.Button(panel,"Add ability",236,406,120,function()local spell=tonumber(read("new-spell"));if not spell or spell<1 or spell%1~=0 then notify("Enter a positive integer spell ID",true);return end;for _,r in ipairs(state.setRows)do if r.spellID==spell then notify("Ability already exists",true);return end end;state.setName=read("set-name");state.setRows[#state.setRows+1]={spellID=spell,enabled=true};Refresh()end,false,"add-spell")
    W.Button(parent,"Delete set",218,522,116,function()local a,b=ns.DeleteSet(scope(),state.spec,state.setKey);if done(a,b,"Set deleted")then chooseSet(nil);Refresh()end end,false,"delete-set")
    W.Button(parent,"Test set",524,522,130,function()local preset={list={},together={},disabled={}};for _,r in ipairs(state.setRows)do preset.list[#preset.list+1]=r.spellID;if r.together then preset.together[r.spellID]=true end;if not r.enabled then preset.disabled[r.spellID]=true end end;local spells=ns.Pick(preset);if #spells==0 then for _,r in ipairs(state.setRows)do if r.enabled then spells={r.spellID};break end end end;ns.Display({type="icon",spells=spells,text="Set preview",dur=4});notify("Preview only; no encounter trigger was fired")end,false,"test-set")
    W.Button(parent,"Save set",666,522,202,function()local a,b=ns.SaveSet(scope(),state.spec,state.setKey,read("set-name"),state.setRows);if a then state.setKey=a;state.setName=read("set-name")end;done(a,b,"Defensive set saved")end,true,"save-set")
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
local function DrawInspector(parent,ctx)
    local form=state.form;local p=W.Panel(parent,476,111,392,440)
    if ctx.spell then W.Icon(p,ctx.spell,14,12,29)end
    W.Label(p,ctx.abilityName or"Timed reminder",ctx.spell and 52 or 14,12,325,16);W.Label(p,ctx.spell and("Spell ID "..ctx.spell)or("Encounter "..tostring(ctx.encounter)),ctx.spell and 52 or 14,36,325,11,W.colors.muted)
    local function collect()
        for _,k in ipairs({"name","leadTime","delay","phase","counter","duration","text","displaySpellID","player","glowTarget"})do local c=ns.UIControls["rule:"..k];if c then form[k]=c:GetText()end end
    end
    state.inspectorTab=state.inspectorTab or"assignment"
    for i,t in ipairs({{"assignment","Assignment"},{"display","Display"},{"filters","Conditions"}})do
        W.Button(p,t[2],12+(i-1)*124,61,118,function()collect();state.inspectorTab=t[1];Refresh()end,state.inspectorTab==t[1],"inspector:"..t[1])
    end
    local content=W.Scroll(p,8,101,374,284)
    local y=8
    local function field(title,key,w,x)W.Field(content,title,form[key],x or 8,y,w or 325,"rule:"..key);end
    local function select(title,key,options,w,x)
        W.Select(content,title,options,form[key],x or 8,y,w or 325,function(v)
            -- Preserve unsaved input while revealing a different set of fields.
            for _,k in ipairs({"name","leadTime","delay","phase","counter","duration","text","displaySpellID","player","glowTarget"})do local c=ns.UIControls["rule:"..k];if c then form[k]=c:GetText()end end
            form[key]=v;Refresh()
        end,"rule:"..key)
    end
    if state.inspectorTab=="assignment"then
    field("REMINDER NAME","name");y=y+57
    W.Toggle(content,"Enabled",form.enabled,8,y,325,function(v)form.enabled=v end,"rule:enabled");y=y+35
    if ctx.kind~="trash"then
        local triggers={{value="bwtimer",label="Mechanic countdown"},{value="bwmsg",label="Mechanic message"}}
        if ctx.scope=="raid"then triggers[#triggers+1]={value="pull",label="Time from pull"};triggers[#triggers+1]={value="stage",label="Time from phase"}end
        select("TRIGGER","trigger",triggers);y=y+57
        local actions={{value="defensive",label="Defensive priority set"},{value="icon",label="Spell icon"},{value="text",label="Text"},{value="bar",label="Countdown bar"},{value="circle",label="Circle"},{value="chat",label="Sound only"},{value="raidframeGlow",label="Player frame glow"}}
        select("ACTION","action",actions);y=y+57
    end
    if form.action=="defensive"then
        local sets=rowsOptions(ns.ScopePresets(ns.Active(),ctx.scope,ctx.spec));table.insert(sets,1,{value="",label="Choose defensive set..."});select("DEFENSIVE SET","preset",sets);y=y+57
    elseif form.action=="icon"then field("DISPLAY SPELL ID","displaySpellID");y=y+57 end
    if form.trigger=="pull"or form.trigger=="stage"then field("SECONDS FROM ANCHOR","delay");y=y+57;if form.trigger=="stage"then field("PHASE","phase");y=y+57 end
    elseif ctx.kind~="trash"then field("DELAY AFTER EVENT (SECONDS)","delay");y=y+57 end
    field("WARN BEFORE (SECONDS)","leadTime");y=y+57
    end
    if state.inspectorTab=="filters"then
    if ctx.scope=="raid"and form.action~="defensive"then
        local targets={{value="everyone",label="Everyone"},{value="spec",label="Selected specialization"},{value="role",label="Role"},{value="player",label="Player"}}
        if form.recipient=="preserve"then targets[#targets+1]={value="preserve",label="Imported filters (preserve)"}end
        select("RECIPIENTS","recipient",targets);y=y+57
        if form.recipient=="role"then select("ROLE","role",{{value="TANK",label="Tank"},{value="HEALER",label="Healer"},{value="DAMAGER",label="Damage"}});y=y+57 end
        if form.recipient=="player"then field("PLAYER NAME OR NAME-REALM","player");y=y+57 end
    end
    if ctx.kind~="trash"then field("OCCURRENCE · BLANK = EVERY, E.G. >1 OR 2,4","counter");y=y+57 end
    if form.preserveDifficulties then
        W.Toggle(content,"Keep imported difficulty filters",true,8,y,325,function(v)form.preserveDifficulties=v end,"rule:preserve-difficulty");y=y+35
    end
    end
    if state.inspectorTab=="display"then
    field("TEXT · BLANK USES THE SELECTED SPELL NAME","text");y=y+57
    local sounds={{value="",label="None"},{value="voice:use-a-defensive",label="Use a defensive"},{value="voice:move-out",label="Move out"},{value="voice:dispel-me",label="Dispel me"}}
    local known=false;for _,o in ipairs(sounds)do if o.value==form.sound then known=true end end
    if not known then sounds[#sounds+1]={value=form.sound,label="Imported sound"}end
    select("SOUND","sound",sounds);y=y+57
    field("DISPLAY DURATION (SECONDS)","duration");y=y+57
    if form.action=="raidframeGlow"then field("PLAYER TO GLOW","glowTarget");y=y+57 end
    W.Toggle(content,"Text to speech",form.tts,8,y,325,function(v)form.tts=v end,"rule:tts");y=y+35
    end
    content:SetHeight(y+12)
    W.Button(p,"Test",12,397,72,function()collect();local spell=tonumber(form.displaySpellID);if form.action=="defensive"then local preset=ns.ScopePresets(ns.Active(),ctx.scope,ctx.spec)[form.preset];spell=preset and preset.list[1]end;ns.Display({type=spell and"icon"or"text",spellID=spell,text=form.text~=""and form.text or"Reminder preview",dur=tonumber(form.duration)or 4,sound=form.sound,tts=form.tts});notify("Display preview; verify the mechanic in game")end,false,"test-rule")
    W.Button(p,"Delete",92,397,82,function()done(ns.DeleteRule(ctx,state.reference));state.reference=nil;state.form=InitialForm(ctx);Refresh()end,false,"delete-rule")
    W.Button(p,"Save reminder",182,397,198,function()collect();local key,error=ns.SaveRule(ctx,form,state.reference);if key then state.ruleKey=key;state.form=nil end;done(key,error,"Reminder saved")end,true,"save-rule")
end
local function DrawManual(parent)
    ContentHeader(parent,"Add an encounter mechanic","Use verified IDs from your installed client. Retail catalogs are not applied to Forever.")
    local a=state.manual or{kind="boss",groupName="",npcName="",npcID="",mapID="",encounterId="",spellID="",spellName=""};state.manual=a
    local keys={{"DUNGEON / RAID NAME","groupName"},{"NPC / BOSS NAME","npcName"},{"NPC ID","npcID"},{"INSTANCE MAP ID (M+)","mapID"},{"ENCOUNTER ID (BOSS)","encounterId"},{"MECHANIC SPELL ID","spellID"},{"ABILITY NAME (OPTIONAL)","spellName"}}
    for i,row in ipairs(keys)do W.Field(parent,row[1],a[row[2]],(i-1)%2*425,64+math.floor((i-1)/2)*66,400,"manual:"..row[2])end
    W.Select(parent,"TYPE",{{value="boss",label="Boss"},{value="trash",label="Trash (M+ only)"}},a.kind,425,262,400,function(v)a.kind=v end,"manual:kind")
    W.Button(parent,"Save mechanic",628,380,197,function()for _,r in ipairs(keys)do a[r[2]]=read("manual:"..r[2])end;a.scope=scope();if a.scope=="raid"then a.kind="boss"end;local id,error=ns.AddManualMechanic(a);if id then state.group=id;state.mode="mechanics";state.entity=nil end;done(id,error,"Mechanic added")end,true,"save-manual")
    W.Button(parent,"Back",0,380,100,function()state.mode="mechanics";Refresh()end,false,"manual-back")
end
local function DrawMechanics(parent)
    local content=scope();ContentHeader(parent,content=="mythic"and"Mythic+ mechanics"or"Raid encounters",content=="mythic"and"Bind your defensive sets to a specific boss or trash ability. Mythic+ only."or"Mechanic, pull and phase reminders. Choose Heroic or Mythic explicitly.")
    local groups=ns.CatalogGroups(content);local g=groups[1];for _,v in ipairs(groups)do if v.id==state.group then g=v end end
    if g then state.group=g.id end
    local opts={};for _,v in ipairs(groups)do opts[#opts+1]={value=v.id,label=v.name}end
    W.Select(parent,content=="mythic"and"DUNGEON"or"RAID",opts,state.group,0,55,328,function(v)state.group=v;state.timed=false;state.entity=nil;state.ability=nil;state.ruleKey=nil;state.form=nil;Refresh()end,"group")
    if content=="raid"then W.Select(parent,"DIFFICULTY",{{value=15,label="Heroic"},{value=16,label="Mythic"}},state.difficulty,342,55,125,function(v)state.difficulty=v;state.form=nil;state.ruleKey=nil;Refresh()end,"difficulty")end
    W.Button(parent,"+ Add mechanic",708,72,160,function()state.mode="manual";Refresh()end,false,"add-mechanic")
    local entities=g and(g.npcs or g.bosses)or{};if content=="raid"and g then entities=g.bosses end
    local n=entities[1];for _,v in ipairs(entities)do if v.id==state.entity then n=v end end
    if n then state.entity=n.id end
    local list=W.Scroll(parent,0,111,224,440)
    W.Label(list,content=="mythic"and"BOSSES & TRASH"or"BOSSES",6,8,190,10,W.colors.muted)
    for i,v in ipairs(entities)do local label=(v.kind=="trash"and"T · "or"B · ")..v.name;W.Button(list,label,0,29+(i-1)*37,196,function()state.entity=v.id;state.timed=false;state.ability=nil;state.form=nil;state.ruleKey=nil;Refresh()end,n==v,"entity:"..v.id)end;list:SetHeight(38+#entities*37)
    local abilities={};for _,a in ipairs(n and n.abilities or{})do
        local allowed=true;if content=="raid"and a.difficulties then allowed=false;for _,d in ipairs(a.difficulties)do if d==(state.difficulty==15 and"heroic"or"mythic")then allowed=true end end end
        if allowed then abilities[#abilities+1]=a end
    end
    local ability=abilities[1];for _,a in ipairs(abilities)do if a.id==state.ability then ability=a end end
    local ctx={scope=content,spec=state.spec,map=g and g.mapID,group=g and g.id,npc=n and n.id,kind=n and n.kind or"boss",encounter=n and(n.encounterId or(content=="raid"and n.id)),difficulty=content=="mythic"and 8 or state.difficulty,spell=ability and ability.id,abilityName=ability and name(ability.id,ability.name)}
    if ability then state.ability=ability.id end
    local mechanics=W.Scroll(parent,234,111,232,440);W.Label(mechanics,"MECHANICS",6,8,200,10,W.colors.muted)
    for i,a in ipairs(abilities)do local button=W.Button(mechanics,name(a.id,a.name),0,29+(i-1)*37,204,function()state.ability=a.id;state.form=nil;state.ruleKey=nil;state.timed=false;Refresh()end,ability==a and not state.timed,"ability:"..a.id);W.Icon(button,a.id,5,7,16);button.label:ClearAllPoints();button.label:SetPoint("TOPLEFT",button,"TOPLEFT",28,-8);button.label:SetWidth(165)end
    local my=35+#abilities*37
    if content=="raid"and n then W.Button(mechanics,"+ Timed reminder",0,my,204,function()state.timed=true;state.ruleKey=nil;state.form=nil;Refresh()end,state.timed,"new-timed");my=my+38 end
    -- Existing pull/phase reminders remain visible even when no spell is attached.
    if n and ctx.encounter then
        local allctx=ns.Clone(ctx);allctx.spell=nil
        for _,r in ipairs(ns.RuleOptions(allctx))do if r.entry.trigger and(r.entry.trigger.type=="pull"or r.entry.trigger.type=="stage")then
            W.Button(mechanics,r.entry.name or"Timed reminder",0,my,204,function()state.timed=true;state.ruleKey=r.key;state.form=nil;Refresh()end,state.ruleKey==r.key,"timed:"..r.key);my=my+35
        end end
    end;mechanics:SetHeight(my+8)
    if state.timed then ctx.spell=nil;ctx.abilityName="Timed encounter reminder"end
    if n and(ability or state.timed)then
        local rules=ns.RuleOptions(ctx);local reference
        for _,r in ipairs(rules)do if r.key==state.ruleKey then reference=r end end
        if not state.form then reference=reference or(not state.timed and rules[1]);state.reference=reference;state.form=InitialForm(ctx,reference);state.inspectorTab="assignment";if state.timed and not reference then state.form.trigger="pull";state.form.delay=30;state.form.action="text"end end
        state.context=ctx;DrawInspector(parent,ctx)
        if #rules>0 and not state.timed then
            local o={{value="new",label="+ Another reminder for this mechanic"}};for _,r in ipairs(rules)do o[#o+1]={value=r.key,label=r.entry.name or tostring(r.key)}end
            W.Select(parent,"SAVED REMINDERS",o,state.reference and state.reference.key or"new",476,55,220,function(v)state.ruleKey=v;state.form=nil;if v=="new"then state.reference=nil;state.form=InitialForm(ctx)end;Refresh()end,"rule-choice")
        end
    else W.Label(parent,"Choose an encounter and mechanic, or add your own verified IDs.",493,150,350,14,W.colors.muted)end
end
local function DrawSettings(parent)
    ContentHeader(parent,"General settings","One display style across both content types. Defensive sets stay separate.")
    local s=ns.Clone(ns.Settings());state.settings=s
    local panel=W.Panel(parent,0,62,868,451)
    local flags={{"Enable reminders","enabled"},{"Show spell icons","showIcon"},{"Show reminder text","showText"},{"Show duration bar","showBar"},{"Enable text to speech","voiceOn"},{"Call external when no defensive is ready","fallbackOn"}}
    for i,f in ipairs(flags)do local value=s[f[2]];if value==nil then value=f[2]~="voiceOn"and f[2]~="fallbackOn"end;W.Toggle(panel,f[1],value,18,18+(i-1)*44,420,function(v)s[f[2]]=v end,"setting:"..f[2])end
    local fields={{"ICON SIZE","iconSize",42},{"TEXT SIZE","textSize",14},{"VOICE VOLUME","voiceVol",100},{"X POSITION","x",0},{"Y POSITION","y",100}}
    for i,f in ipairs(fields)do local v=(f[2]=="x"or f[2]=="y")and s.pos and s.pos[f[2]]or s[f[2]];W.Field(panel,f[1],v or f[3],488,18+(i-1)*64,325,"setting:"..f[2])end
    W.Select(panel,"BOSS MOD SOURCE",{{value="bigwigs",label="BigWigs / LittleWigs"},{value="dbm",label="DBM"}},s.bossSource or"bigwigs",18,300,420,function(v)s.bossSource=v end,"setting:bossSource")
    W.Label(panel,"Boss mechanics require matching provider messages/timers.\nExBoss supplies trash countdowns. Readiness uses public game APIs.",18,373,425,12,W.colors.muted)
    W.Button(parent,"Preview display",0,526,160,function()ns.Display({type="icon",spellID=22812,text="Use a defensive",dur=4,tts=s.voiceOn});notify("Preview uses currently saved settings")end,false,"preview-display")
    W.Button(parent,"Save settings",656,526,212,function()local v,e=ns.EditProfile(function(data)
        for _,f in ipairs(fields)do local number=tonumber(read("setting:"..f[2]));assert(number,"Enter a number for "..f[1]);if f[2]=="x"or f[2]=="y"then s.pos=s.pos or{point="CENTER",relPoint="CENTER"};s.pos[f[2]]=number else s[f[2]]=number end end;data.settings=s
    end);done(v,e,"Settings saved")end,true,"save-settings")
end
local function DrawProfiles(parent)
    ContentHeader(parent,"Profiles","One profile holds both content types. Imports create a separate copy.")
    local opts={};for name in pairs(ns.Store().profiles)do opts[#opts+1]={value=name,label=name}end;table.sort(opts,function(a,b)return a.label<b.label end)
    W.Select(parent,"ACTIVE PROFILE",opts,ns.Store().active,0,60,400,function(v)local a,b=ns.SelectProfile(v);state.group=nil;state.entity=nil;state.form=nil;state.setName=nil;done(a,b,"Profile selected")end,"profile-select")
    W.Field(parent,"NEW PROFILE NAME","",420,60,448,"profile-name")
    W.Button(parent,"Create",0,127,130,function()done(ns.CreateProfile(read("profile-name"),false))end,false,"profile-create")
    W.Button(parent,"Copy active",140,127,130,function()done(ns.CreateProfile(read("profile-name"),true))end,false,"profile-copy")
    W.Button(parent,"Rename",280,127,120,function()done(ns.RenameProfile(read("profile-name")))end,false,"profile-rename")
    W.Button(parent,state.confirmDelete and"Confirm delete"or"Delete active",420,127,160,function()if not state.confirmDelete then state.confirmDelete=true;Refresh()else state.confirmDelete=false;done(ns.DeleteProfile())end end,false,"profile-delete")
    W.Label(parent,"IMPORT / EXPORT STRING",0,183,700,11,W.colors.muted)
    local panel=W.Panel(parent,0,207,868,230,W.colors.background);local scroll=W.Frame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",10,-10);scroll:SetSize(832,210)
    local text=W.Frame("EditBox",nil,scroll);text:SetMultiLine(true);text:SetFont(STANDARD_TEXT_FONT or"Fonts\\FRIZQT__.TTF",12);text:SetWidth(812);text:SetHeight(200);text:SetAutoFocus(false);text:SetMaxLetters(130000);text:SetText(state.importText or"");scroll:SetScrollChild(text);text:SetScript("OnTextChanged",function(self)
        if self.GetNumLines then local ok,n=pcall(self.GetNumLines,self);if ok and type(n)=="number"then self:SetHeight(math.max(210,n*16+24));scroll:UpdateScrollChildRect()end end
    end);text:SetScript("OnEscapePressed",function(self)self:ClearFocus()end);ns.UIControls["profile-string"]=text
    W.Button(parent,"Import profile",0,452,180,function()local value=read("profile-string");local a,b,report=ns.Import(value);if a then state.importText=ns.ImportReportText(report);state.form=nil;state.setName=nil;state.group=nil end;done(a,b,report and("Imported · "..#report.issues.." migration items to review below")or"Profile imported")end,true,"profile-import")
    W.Button(parent,"Export active",192,452,180,function()local value,error=ns.Export();if value then text:SetText(value);text:HighlightText();text:SetFocus();state.importText=value;notify("Export ready · Ctrl+C copies the selected text")else notify(error,true)end end,false,"profile-export")
    W.Button(parent,"Diagnostics",384,452,160,function()local v=ns.Diagnostics();text:SetText(v);text:HighlightText();text:SetFocus();state.importText=v;notify("Diagnostics ready to copy")end,false,"diagnostics")
    W.Label(parent,"PZTK1, NSRPACK2 and full NSRT Profile / EncounterAlert imports. Review migration notes.\nProfile data is local to the current game client. Original profiles are retained.",0,510,860,12,W.colors.muted)
end
Refresh=function()
    if not window then return end
    if W.popup then W.popup:Hide()end
    W.Clear(body);W.Clear(header);W.Begin();ns.UIControls={}
    header=W.Frame("Frame",nil,window);header:SetPoint("TOPLEFT",0,0);header:SetSize(1120,105)
    W.Label(header,"PUZATIK",22,17,300,25);W.Label(header,"REMINDERS",23,48,300,12,W.colors.accent)
    W.Label(header,ns.Client():upper().."  /  "..ns.version.."  /  "..tostring(ns.Store().active or"No profile"),335,24,720,12,W.colors.muted)
    local specs={};for id,label in pairs(ns.Catalog.specs)do specs[#specs+1]={value=id,label=label}end;table.sort(specs,function(a,b)return a.label<b.label end)
    W.Select(header,"SPECIALIZATION",specs,state.spec,773,43,310,function(v)state.spec=v;state.setName=nil;state.form=nil;state.ruleKey=nil;Refresh()end,"specialization")
    W.Button(header,"x",1080,12,28,function()window:Hide();if W.popup then W.popup:Hide()end end,false,"close")
    local tabs={{"mythic","Mythic+"},{"raid","Raids"},{"profiles","Profiles"},{"settings","Settings"}}
    for i,t in ipairs(tabs)do W.Button(header,t[2],18,115+(i-1)*44,124,function()state.tab=t[1];state.mode="mechanics";state.group=nil;state.entity=nil;state.ability=nil;state.timed=false;state.form=nil;state.setName=nil;Refresh()end,state.tab==t[1],"tab:"..t[1])end
    W.Label(header,"M+ and raid sets\nare independent.",24,510,112,11,W.colors.muted)
    body=W.Frame("Frame",nil,window);body:SetPoint("TOPLEFT",164,-113);body:SetSize(868,560)
    if state.tab=="mythic"or state.tab=="raid"then
        -- Context navigation belongs to the current content, not global extra modules.
        W.Button(header,"Mechanics",164,72,126,function()state.mode="mechanics";state.form=nil;Refresh()end,state.mode=="mechanics","mode:mechanics")
        W.Button(header,"Defensive sets",300,72,150,function()state.mode="sets";state.setName=nil;Refresh()end,state.mode=="sets","mode:sets")
        if state.mode=="sets"then DrawSets(body)elseif state.mode=="manual"then DrawManual(body)else DrawMechanics(body)end
    elseif state.tab=="profiles"then DrawProfiles(body)else DrawSettings(body)end
    W.Finish();notify(state.message or"Choose an encounter to configure a reminder",state.error)
end
function ns.OpenWorkspace()
    if not window then
        window=W.Panel(UIParent,0,0,1120,720,W.colors.background);window:ClearAllPoints();window:SetPoint("CENTER");window:SetFrameStrata("DIALOG");window:SetMovable(true);window:EnableMouse(true);window:RegisterForDrag("LeftButton");window:SetScript("OnDragStart",function(self)if not(InCombatLockdown and InCombatLockdown())then self:StartMoving()end end);window:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end)
        local sw=GetScreenWidth and GetScreenWidth()or 1920;local sh=GetScreenHeight and GetScreenHeight()or 1080
        window:SetScale(math.min(1,math.max(0.55,(sw-30)/1120),math.max(0.55,(sh-50)/720)))
        window:EnableKeyboard(true);window:SetPropagateKeyboardInput(true);window:SetScript("OnKeyDown",function(self,key)if key=="ESCAPE"then self:Hide();if W.popup then W.popup:Hide()end end end)
        status=W.Label(window,"",20,687,1080,11,W.colors.muted)
        ns.WorkspaceWindow=window
    end
    if not ns.Active()then
        if not(InCombatLockdown and InCombatLockdown())then ns.CreateProfile("Default",false)end
    end
    state.spec=state.spec or ns.Spec()or 104
    Refresh();window:Show()
end
function ns.ShowDiagnostics()
    ns.OpenWorkspace();state.tab="profiles";state.importText=ns.Diagnostics();Refresh()
end
