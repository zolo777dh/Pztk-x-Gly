local _,ns=...
-- Pull trace (NSR trace / observed timings / keys): what the boss mod announced on each pull and what
-- every reminder did with it, shown or skipped and why. Kept for the last three pulls, so one wipe is
-- enough to see which call did not come. /ndp trace, /ndp observed, /ndp keys.
local MAXPULLS,MAXLINES=3,400
local pull
local function Cfg()
    local store=ns.Store();store.trace=type(store.trace)=="table"and store.trace or{}
    local c=store.trace;c.pulls=type(c.pulls)=="table"and c.pulls or{}
    return c
end
function ns.TraceOn()return Cfg().on~=false end
function ns.SetTrace(on)Cfg().on=on and true or false;if not on then pull=nil end end
function ns.ClearTrace()Cfg().pulls={};pull=nil end
function ns.TracePulls()return Cfg().pulls end
-- Seconds to one decimal, without a trailing .0 (Lua 5.1 and 5.3 print floats differently).
local function Num(x)
    x=math.floor((tonumber(x)or 0)*10+0.5)/10
    if x==math.floor(x)then return string.format("%d",x)end
    return string.format("%.1f",x)
end
local function Now()return ns.pullTime and math.floor((GetTime()-ns.pullTime)*10+0.5)/10 or 0 end
local function Label(spell)
    if not ns.Plain(spell,"number")then return tostring(spell)end
    local n=(ns.AbilityName and ns.AbilityName(spell))or(ns.SpellLabel and ns.SpellLabel(spell))or(ns.Catalog and ns.Catalog.spellNames[spell])
    if type(n)~="string"then n=nil end
    return(n and(n.." ")or"")..spell
end
ns.TraceLabel=Label
function ns.TraceStart(encounter,difficulty)
    pull=nil
    if not ns.TraceOn()then return end
    local c=Cfg()
    pull={encounter=encounter,difficulty=difficulty,at=time and time()or 0,lines={},seen={}}
    table.insert(c.pulls,1,pull)
    while #c.pulls>MAXPULLS do table.remove(c.pulls)end
end
function ns.Trace(kind,text)
    if not pull then return end
    if #pull.lines>=MAXLINES then pull.truncated=true;return end
    pull.lines[#pull.lines+1]={Now(),kind,tostring(text)}
end
-- One boss mod timer bar (duration) or message (no duration) of the running pull.
function ns.TraceEvent(spell,duration)
    if not pull or not ns.Plain(spell,"number")then return end
    local s=pull.seen[spell]
    if not s then s={n=0,bar=0,msg=0,first=Now(),times={}};pull.seen[spell]=s end
    s.n=s.n+1
    local at=Now()+(duration or 0)
    if duration then s.bar=s.bar+1 else s.msg=s.msg+1 end
    if #s.times<20 then s.times[#s.times+1]=math.floor(at*10+0.5)/10 end
    ns.Trace("event",(duration and("bar "..Num(duration).."s")or"message").."  "..Label(spell))
end
function ns.TraceEnd(kill)
    if not pull then return end
    pull.kill=kill==true;pull.length=Now();pull=nil
end
-- A short name for a reminder in the trace.
function ns.TraceName(entry)
    if type(entry)~="table"then return"reminder"end
    local d=type(entry.display)=="table"and entry.display or{}
    local t=type(entry.trigger)=="table"and entry.trigger or{}
    local name=entry.name or(d.text~=""and d.text)or nil
    if t.spellID then name=(name and(name.."  ·  ")or"")..Label(t.spellID)end
    return name or(t.type and(t.type.." reminder"))or"reminder"
end
-- Why ns.Fire would not show an entry, or nil when it will.
function ns.SkipReason(entry,occurrence)
    if ns.ContentMatches and not ns.ContentMatches(entry)then return"other content (Mythic+ / raid)"end
    if ns.Enabled and not ns.Enabled()then return"reminders are off in Settings"end
    local conflict=ns.Conflict()
    if conflict then return"paused: "..conflict.." is loaded"end
    if entry.enabled==false then return"turned off"end
    if not ns.Difficulty(entry)then return"other difficulty"end
    if not ns.Target(entry.target,occurrence)then return"not for you (recipients)"end
end
local function Boss(encounter)
    local b=ns.JournalBoss and ns.JournalBoss(encounter)
    local script=ns.BossTimers and ns.BossTimers[tonumber(encounter)]
    local n=b and b.name or script and script.name
    return(n and(n.." ")or"").."("..tostring(encounter)..")"
end
local function Header(p)
    local when=p.at and date and date("%Y-%m-%d %H:%M",p.at)or"?"
    return"Pull "..when.."  ·  boss "..Boss(p.encounter).."  ·  difficulty "..tostring(p.difficulty)..
        "  ·  "..(p.kill and"kill"or p.length and"wipe"or"running").."  ·  "..Num(p.length or Now()).."s"
end
-- /ndp trace: everything of the last pulls, newest first.
function ns.TraceText()
    local pulls=Cfg().pulls
    if not ns.TraceOn()then return"Pull trace is off. Turn it on with /ndp trace on."end
    if #pulls==0 then return"No pull traced yet. Pull a boss, then type /ndp trace."end
    local out={}
    for i,p in ipairs(pulls)do
        if i>1 then out[#out+1]=""end
        out[#out+1]=Header(p)
        for _,l in ipairs(p.lines or{})do out[#out+1]=string.format("%7.1f  %-6s %s",tonumber(l[1])or 0,tostring(l[2]),tostring(l[3]))end
        if #(p.lines or{})==0 then out[#out+1]="  nothing announced and no reminder ran"end
        if p.truncated then out[#out+1]="  (cut at "..MAXLINES.." lines)"end
    end
    return table.concat(out,"\n")
end
local function Seen(p)
    local list={}
    for spell,s in pairs(p.seen or{})do list[#list+1]={spell=tonumber(spell)or spell,s=s}end
    table.sort(list,function(a,b)return(a.s.first or 0)<(b.s.first or 0)end)
    return list
end
-- /ndp observed: when each boss ability came on the last pull (bar end or message time).
function ns.ObservedText()
    local p=Cfg().pulls[1]
    if not p then return"No pull traced yet. Pull a boss, then type /ndp observed."end
    local out={"Observed timings  ·  "..Header(p)}
    for _,e in ipairs(Seen(p))do
        local times={};for _,t in ipairs(e.s.times or{})do times[#times+1]=Num(t)end
        out[#out+1]=Label(e.spell).."  x"..tostring(e.s.n)..":  "..table.concat(times,", ")
    end
    if #out==1 then out[#out+1]="The boss mod announced nothing on this pull."end
    return table.concat(out,"\n")
end
-- /ndp keys: the spell IDs (keys) the boss mod used on the last pull, for bars and messages.
function ns.KeysText()
    local p=Cfg().pulls[1]
    if not p then return"No pull traced yet. Pull a boss, then type /ndp keys."end
    local out={"Boss mod keys  ·  "..Header(p)}
    for _,e in ipairs(Seen(p))do
        local planned=""
        local profile=ns.Active()
        if profile then
            for _,entry in pairs(ns.Get(profile.data.raidReminders,p.encounter)or{})do
                if type(entry)=="table"and type(entry.trigger)=="table"and entry.trigger.spellID==e.spell then planned="  ·  planned";break end
            end
        end
        out[#out+1]=tostring(e.spell).."  "..Label(e.spell):gsub(" %d+$","").."  ·  "..tostring(e.s.bar).." bars, "..tostring(e.s.msg).." messages"..planned
    end
    if #out==1 then out[#out+1]="The boss mod announced nothing on this pull."end
    return table.concat(out,"\n")
end
-- /ndp cds: which spells of your defensive sets are ready now.
function ns.CooldownsText()
    local profile,spec=ns.Active(),ns.Spec()
    if not profile or not spec then return"No active profile or specialization."end
    local out={"Defensive sets of "..tostring(ns.Catalog.specs[spec]or spec).." (ready now)"}
    for _,scope in ipairs({"mythic","raid"})do
        local sets=ns.ScopePresets and ns.ScopePresets(profile,scope,spec)or ns.Get(profile.data.presets,spec)
        for key,set in pairs(sets or{})do if type(set)=="table"then
            local parts={}
            for _,spell in ipairs(set.list or{})do
                local off=ns.Get(set.disabled,spell)
                parts[#parts+1]=Label(spell):gsub(" %d+$","")..(off and" off"or ns.SpellReady(spell)and" ready"or" on cooldown")
            end
            out[#out+1]=(scope=="mythic"and"M+ "or"Raid ")..tostring(set.name or key)..":  "..(#parts>0 and table.concat(parts,", ")or"empty")
        end end
    end
    if #out==1 then out[#out+1]="No defensive sets for this specialization yet."end
    return table.concat(out,"\n")
end
-- /ndp bosses: every boss and dungeon the active profile plans something for.
function ns.BossesText()
    local profile=ns.Active()
    if not profile then return"No active profile."end
    local count={}
    local function add(encounter,n)if tonumber(encounter)then encounter=tonumber(encounter);count[encounter]=(count[encounter]or 0)+n end end
    for encounter,entries in pairs(profile.data.raidReminders or{})do local n=0;for _ in pairs(entries)do n=n+1 end;add(encounter,n)end
    for _,bySpec in pairs(profile.data.abilityBindings or{})do for encounter,spells in pairs(bySpec)do local n=0;for _ in pairs(spells)do n=n+1 end;add(encounter,n)end end
    local list={};for encounter,n in pairs(count)do if n>0 then list[#list+1]={encounter,n}end end
    table.sort(list,function(a,b)return a[1]<b[1]end)
    local out={"Planned bosses in "..tostring(ns.Store().active or"the active profile")}
    for _,e in ipairs(list)do out[#out+1]=Boss(e[1]).."  ·  "..e[2].." reminders"end
    local dungeons=0;for _,rules in pairs(profile.data.integrationRules or{})do for _ in pairs(rules)do dungeons=dungeons+1 end end
    if dungeons>0 then out[#out+1]="Mythic+ trash reminders: "..dungeons end
    if #out==1 then out[#out+1]="Nothing planned yet."end
    return table.concat(out,"\n")
end
-- /ndp calls: the reminders that would reach you on a boss (the current one, or the last traced).
function ns.CallsText(encounter)
    local profile=ns.Active()
    if not profile then return"No active profile."end
    encounter=tonumber(encounter)or ns.encounter or(Cfg().pulls[1]and Cfg().pulls[1].encounter)
    if not encounter then return"No boss yet: type /ndp calls <encounter ID>, or pull a boss first. /ndp bosses lists the IDs."end
    local out={"Your calls on "..Boss(encounter)}
    for _,entry in pairs(ns.EncounterEntries(profile,encounter)or{})do if type(entry)=="table"then
        local t=type(entry.trigger)=="table"and entry.trigger or{}
        local why=nil
        if entry.enabled==false then why="off"elseif not ns.Target(entry.target)then why="not for you"end
        local at=t.type=="pull"and(tostring(t.delay or 0).."s")or t.type=="stage"and("P"..tostring(t.stage).." "..tostring(t.delay or 0).."s")or t.type=="prepull"and("-"..tostring(t.delay or 0).."s")or tostring(t.type)
        out[#out+1]=at.."  ·  "..ns.TraceName(entry)..(why and("  ("..why..")")or"")
    end end
    local spec=ns.Spec()
    for spell,binding in pairs(ns.Get(ns.Get(profile.data.abilityBindings,spec),encounter)or{})do
        out[#out+1]="ability  ·  "..Label(spell).."  ·  defensive set "..tostring(type(binding)=="table"and binding.preset or"active")
    end
    if #out==1 then out[#out+1]="Nothing planned on this boss."end
    return table.concat(out,"\n")
end
