local _, ns = ...
function ns.Client()
    local version, _, _, interface = GetBuildInfo()
    return (interface == 16001 or (type(version) == "string" and version:match("^1%.60%."))) and "forever" or "retail"
end
function ns.Store()
    -- 0.4.0 renamed the addon from PztkReminders. A copied PztkReminders.lua
    -- SavedVariables file still holds PztkRemindersDB; adopt it once, then drop it.
    if NaowhDefensivePlannerDB == nil and type(PztkRemindersDB) == "table" then NaowhDefensivePlannerDB = PztkRemindersDB end
    PztkRemindersDB = nil
    NaowhDefensivePlannerDB = NaowhDefensivePlannerDB or { clients = {} }
    NaowhDefensivePlannerDB.clients = NaowhDefensivePlannerDB.clients or {}
    local client = ns.Client()
    NaowhDefensivePlannerDB.clients[client] = NaowhDefensivePlannerDB.clients[client] or {profiles={},history={}}
    return NaowhDefensivePlannerDB.clients[client]
end
local function Data(value, seen, depth, budget)
    if depth > 32 then return false end
    local kind = type(value)
    if kind == "number" then return value == value and math.abs(value) < math.huge end
    if kind ~= "table" then return kind == "string" or kind == "boolean" or kind == "nil" end
    if seen[value] then return false end
    seen[value] = true
    for key, child in pairs(value) do
        budget[1] = budget[1] - 1
        if key=="__proto__"or key=="constructor"or key=="prototype"or budget[1] < 0 or (type(key) ~= "string" and type(key) ~= "number") or not Data(child, seen, depth+1,budget) then return false end
    end
    seen[value] = nil; return true
end
local function Number(v, min, max, optional)
    return (optional and v == nil) or (type(v) == "number" and v >= min and v <= max)
end
local function ID(v)return Number(v,1,100000000) and v % 1 == 0 end
local function Flags(t)
    if t == nil then return true end
    if type(t) ~= "table" then return false end
    for _,v in pairs(t)do if type(v) ~= "boolean" then return false end end
    return true
end
local function Sequence(t,min,max,valid)
    if type(t)~="table"then return false end
    local count=0
    for key,value in pairs(t)do count=count+1;if type(key)~="number"or key%1~=0 or key<1 or not valid(value)then return false end end
    if count<min or count>max then return false end
    for i=1,count do if t[i]==nil then return false end end
    return true
end
local function Newer(required,current)
    local a,b={},{}
    for n in required:gmatch("%d+")do a[#a+1]=tonumber(n)end
    for n in current:gmatch("%d+")do b[#b+1]=tonumber(n)end
    for i=1,math.max(#a,#b)do if (a[i]or 0)~=(b[i]or 0)then return (a[i]or 0)>(b[i]or 0)end end
    return false
end
local function Binding(b)
    if type(b)~="table" or (b.enabled~=nil and type(b.enabled)~="boolean") or (b.preset~=nil and type(b.preset)~="string") or not Number(b.leadTime,-120,120,true) then return false end
    if b.sound~=nil and type(b.sound)~="string" then return false end
    if b.display~=nil then
        if type(b.display)~="table" or not Number(b.display.dur,0.1,120,true) or (b.display.text~=nil and type(b.display.text)~="string") then return false end
        for _,key in ipairs({"sound","ttsText"})do if b.display[key]~=nil and type(b.display[key])~="string"then return false end end
        if b.display.tts~=nil and type(b.display.tts)~="boolean"then return false end
    end
    return true
end
local function Settings(s)
    if s==nil then return true end
    if type(s)~="table"then return false end
    for _,key in ipairs({"enabled","voiceOn","soundOn","fallbackOn","showIcon","showText","showBar","cdmGlow","externalAudio","externalChat","coveredSkip","coveredSkipDefaultOn"})do if s[key]~=nil and type(s[key])~="boolean"then return false end end
    for _,range in ipairs({{"voiceVol",0,100},{"iconSize",8,256},{"textSize",6,80},{"leadTime",0,120},{"lingerSec",0.1,120},{"coveredCastWindow",0,60}})do if not Number(s[range[1]],range[2],range[3],true)then return false end end
    for _,key in ipairs({"soundKey","voiceNone","textSide","bossSource"})do if s[key]~=nil and type(s[key])~="string"then return false end end
    if s.pos~=nil then
        if type(s.pos)~="table"or not Number(s.pos.x,-10000,10000,true)or not Number(s.pos.y,-10000,10000,true)then return false end
        local anchors={CENTER=true,TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
        for _,key in ipairs({"point","relPoint"})do if s.pos[key]~=nil and not anchors[s.pos[key]]then return false end end
    end
    return true
end
function ns.Validate(profile)
    if type(profile) ~= "table" or profile.format ~= 1 or profile.addon ~= "PztkReminders" or type(profile.name) ~= "string" or #profile.name > 200 or type(profile.data) ~= "table"or profile.licensed then return false end
    if profile.client ~= "retail" and profile.client ~= "forever" then return false end
    if not Data(profile, {}, 0, {100000}) then return false end
    if not Settings(profile.data.settings)then return false end
    local function Scope(value)return value==nil or value=="mythic"or value=="raid"end
    if profile.data.contentDifficulties~=nil then
        if type(profile.data.contentDifficulties)~="table"then return false end
        for scope,flags in pairs(profile.data.contentDifficulties)do if not Scope(scope)or not Flags(flags)then return false end end
    end
    if profile.data.scopePresets~=nil then
        if type(profile.data.scopePresets)~="table"then return false end
        for scope,presets in pairs(profile.data.scopePresets)do
            if not Scope(scope)or not ns.Validate({format=1,addon="PztkReminders",name="Scoped sets",client=profile.client,data={presets=presets}})then return false end
        end
    end
    if profile.data.scopeActivePreset~=nil then
        if type(profile.data.scopeActivePreset)~="table"then return false end
        for scope,active in pairs(profile.data.scopeActivePreset)do
            if not Scope(scope)or type(active)~="table"then return false end
            for _,key in pairs(active)do if type(key)~="string"then return false end end
        end
    end
    if profile.data.manualCatalog~=nil then
        if type(profile.data.manualCatalog)~="table"then return false end
        for scope,groups in pairs(profile.data.manualCatalog)do
            if not Scope(scope)or type(groups)~="table"then return false end
            for _,g in pairs(groups)do
                if type(g)~="table"or type(g.name)~="string"or(type(g.id)~="string"and type(g.id)~="number")or(g.mapID~=nil and not ID(g.mapID))then return false end
                for _,list in pairs({g.npcs or{},g.bosses or{}})do
                    if type(list)~="table"then return false end
                    for _,n in pairs(list)do
                        if type(n)~="table"or not ID(n.id)or type(n.name)~="string"or type(n.abilities)~="table"or(n.encounterId~=nil and not ID(n.encounterId))then return false end
                        for _,a in pairs(n.abilities)do if type(a)~="table"or not ID(a.id)or(a.name~=nil and type(a.name)~="string")then return false end end
                    end
                end
            end
        end
    end
    for _, key in ipairs({"presets","activePreset","abilityBindings","integrationRules","raidReminders","callouts","settings"}) do if profile.data[key] ~= nil and type(profile.data[key]) ~= "table" then return false end end
    for _,value in pairs(profile.data.callouts or{})do if type(value)~="string"then return false end end
    -- Per-ability call-out options: text shown on screen, voice on/off, a sound instead of speech.
    if profile.data.calloutOptions~=nil then
        if type(profile.data.calloutOptions)~="table"then return false end
        for spell,o in pairs(profile.data.calloutOptions)do
            if not ID(tonumber(spell))or type(o)~="table"then return false end
            for _,key in ipairs({"label","sound"})do if o[key]~=nil and(type(o[key])~="string"or #o[key]>200)then return false end end
            for _,key in ipairs({"audio","speak"})do if o[key]~=nil and type(o[key])~="boolean"then return false end end
        end
    end
    if profile.data.voiceNone~=nil and type(profile.data.voiceNone)~="string"then return false end
    if not Number(profile.data.leadTime,0,120,true)then return false end
    for _, presets in pairs(profile.data.presets or {})do
        if type(presets) ~= "table" then return false end
        for _,preset in pairs(presets)do
            if type(preset) ~= "table" or type(preset.list) ~= "table" or not Flags(preset.together)or not Flags(preset.disabled) then return false end
            local count=0
            for index,spell in pairs(preset.list)do if not ID(index)or not ID(spell)then return false end;count=count+1 end
            if count>200 then return false end
            for i=1,count do if not preset.list[i]then return false end end
        end
    end
    for _,value in pairs(profile.data.activePreset or {})do if type(value)~="string"then return false end end
    for _,encounters in pairs(profile.data.abilityBindings or {})do
        if type(encounters)~="table"then return false end
        for _,bindings in pairs(encounters)do if type(bindings)~="table"then return false end;for _,binding in pairs(bindings)do if not Scope(binding.content)or not Flags(binding.difficulties)or not Binding(binding)then return false end end end
    end
    for _,rules in pairs(profile.data.integrationRules or {})do
        if type(rules)~="table"then return false end
        for _,rule in pairs(rules)do
            if not Scope(rule.content)or not Flags(rule.difficulties)or not Binding(rule)or type(rule.trigger)~="table"then return false end
            local t=rule.trigger
            if (t.type~="exboss"and t.type~="auraSound")or not Number(t.mapID,0,100000000)or t.mapID%1~=0 or not ID(t.spellID)or not Number(t.timeleft,0,120,true)then return false end
            if t.type=="auraSound"then
                if (t.target~="player"and t.target~="party")or(t.auraEvent~="Added"and t.auraEvent~="ApplicationsIncreased"and t.auraEvent~="Removed")or type(rule.display)~="table"or type(rule.display.sound)~="string"or rule.display.sound==""or rule.display.sound=="none"or(t.scope~=nil and t.scope~="raid")then return false end
                if (rule.display.sound=="voice:stoneform-ready"or rule.display.sound=="voice:shadowmeld-ready")and t.target~="player"then return false end
            end
        end
    end
    for _, entries in pairs(profile.data.raidReminders or {}) do
        if type(entries) ~= "table" then return false end
        for _, entry in pairs(entries) do
            if type(entry) ~= "table" or type(entry.trigger) ~= "table" or type(entry.display) ~= "table" then return false end
            if entry.enabled~=nil and type(entry.enabled)~="boolean"then return false end
            local trigger = entry.trigger
            if not Scope(entry.content)then return false end
            if entry.defensive~=nil then
                local d=entry.defensive
                if type(d)~="table"or not Scope(d.scope)or type(d.preset)~="string"or not ID(d.specID)then return false end
            end
            if trigger.counterGroups~=nil then
                if type(trigger.counterGroups)~="table"then return false end
                for _,group in pairs(trigger.counterGroups)do
                    if type(group)~="table"then return false end
                    for _,pred in pairs(group)do
                        if type(pred)~="table"or not Number(pred.value,-1000000,1000000)or not({["="]=true,["!"]=true,[">"]=true,["<"]=true,[">="]=true,["<="]=true})[pred.op]then return false end
                    end
                end
            end
            if trigger.type ~= "pull" and trigger.type ~= "prepull" and trigger.type ~= "stage" and trigger.type ~= "bwtimer" and trigger.type ~= "bwmsg" then return false end
            if trigger.type=="prepull"and not Number(trigger.delay,0.1,3600)then return false end
            if not Number(trigger.delay,0,7200,true)or not Number(trigger.leadTime,0,120,true)or not Number(trigger.stage,0.01,100,true)then return false end
            if (trigger.type=="bwtimer"or trigger.type=="bwmsg")and not ID(trigger.spellID)then return false end
            if trigger.type=="stage"and not trigger.stage then return false end
            if not Flags(entry.difficulties)then return false end
            local display=entry.display
            local types={icon=true,text=true,bar=true,circle=true,chat=true,raidframeGlow=true,nameplateGlow=true}
            if not types[display.type]or not Number(display.dur,0.1,120,true)or (display.spellID and not ID(display.spellID))then return false end
            for _,key in ipairs({"text","sound","ttsText","glowTarget"})do if display[key]~=nil and type(display[key])~="string"then return false end end
            if display.tts~=nil and type(display.tts)~="boolean"then return false end
            if display.glowTargets~=nil and not Sequence(display.glowTargets,1,40,function(v)return type(v)=="string"and #v>0 and #v<=100 end)then return false end
            if display.glowColor~=nil and not Sequence(display.glowColor,4,4,function(v)return Number(v,0,1)end)then return false end
            -- NSRT-style look: text and bar colours, bar ticks, sticky time and the countdown switch.
            for _,key in ipairs({"textColor","barColor"})do if display[key]~=nil and not Sequence(display[key],4,4,function(v)return Number(v,0,1)end)then return false end end
            if display.ticks~=nil and not Sequence(display.ticks,0,20,function(v)return Number(v,0,120)end)then return false end
            if not Number(display.sticky,0,60,true)then return false end
            for _,key in ipairs({"hideTimer","countdown","hideOnUse"})do if display[key]~=nil and type(display[key])~="boolean"then return false end end
            if not Number(display.voiceCountdown,0,10,true)then return false end
            if entry.target and type(entry.target) ~= "table" then return false end
            for _,key in ipairs({"all","matchAny"})do if entry.target and entry.target[key]~=nil and type(entry.target[key])~="boolean"then return false end end
            for _, key in ipairs({"roles","specs","classes","names","subgroups"}) do if entry.target and entry.target[key] and not Flags(entry.target[key]) then return false end end
            -- Rotations (cast N goes to the N-th name) and note slots (the N-th name of a note line).
            local rot=entry.target and entry.target.rotation
            if rot~=nil and(type(rot)~="table"or(rot.note~=nil and(type(rot.note)~="string"or #rot.note>40))or(rot.names~=nil and not Sequence(rot.names,1,40,function(v)return type(v)=="string"and #v<=64 end))or(rot.note==nil and rot.names==nil))then return false end
            local slot=entry.target and entry.target.noteSlot
            if slot~=nil and(type(slot)~="table"or type(slot.note)~="string"or #slot.note>40 or not Number(slot.index,1,40))then return false end
        end
    end
    return true
end
-- Hide on use and spoken countdowns need 0.6.7; NSRT-style colours, ticks, sticky time and
-- countdowns need 0.6.5; pre-pull countdowns and
-- multi-frame glows need 0.3.3; everything else the in-game editor writes needs 0.3.0.
local lookKeys={"textColor","barColor","ticks","sticky","hideTimer","countdown"}
function ns.MinimumAddon(data)
    local need="0.3.0"
    for _,entries in pairs(type(data)=="table"and type(data.raidReminders)=="table"and data.raidReminders or{})do
        for _,e in pairs(type(entries)=="table"and entries or{})do
            -- Rotations and note slots are read only from 0.7.0; older addons would show them to everyone.
            if type(e)=="table"and type(e.target)=="table"and(e.target.rotation~=nil or e.target.noteSlot~=nil)then return "0.7.0"end
            if type(e)=="table"and type(e.display)=="table"and(e.display.hideOnUse~=nil or e.display.voiceCountdown~=nil)then need="0.6.7"end
            if type(e)=="table"and type(e.display)=="table"and need~="0.6.7"then for _,key in ipairs(lookKeys)do if e.display[key]~=nil then need="0.6.5"end end end
            if need=="0.3.0"and type(e)=="table"and(type(e.trigger)=="table"and e.trigger.type=="prepull"or type(e.display)=="table"and(e.display.glowTargets~=nil or e.display.glowColor~=nil))then need="0.3.3"end
        end
    end
    return need
end
function ns.Decode(input)
    if type(input) ~= "string" then return nil, "Paste a PZTK1 string" end
    input = input:gsub("%s+", "")
    if ns.IsNativeExport and ns.IsNativeExport(input) then
        local bundle,error=ns.DecodeProfiles(input);if not bundle then return nil,error end
        for _,p in ipairs(bundle.profiles)do if p.name==bundle.active then return p end end
        return bundle.profiles[1]
    end
    if input:sub(1,6) ~= "PZTK1:" or #input > 130000 then return nil, "Expected PZTK1 string under 130 KB" end
    local ld, ser = LibStub("LibDeflate"), LibStub("LibSerialize")
    local bytes = ld:DecodeForPrint(input:sub(7))
    local raw = bytes and ld:DecompressDeflate(bytes)
    if not raw or #raw > 4000000 then return nil, "Invalid compressed profile or size limit exceeded" end
    local ok, profile = ser:Deserialize(raw)
    -- 0.4.0 desktop text reminders could serialize an optional ID as "".
    -- Treat that exact blank sentinel as absent, while still refusing other bad IDs.
    if ok and type(profile)=="table"and type(profile.data)=="table"and type(profile.data.raidReminders)=="table"then
        for _,entries in pairs(profile.data.raidReminders)do if type(entries)=="table"then
            for _,entry in pairs(entries)do if type(entry)=="table"then
                if type(entry.display)=="table"and entry.display.spellID==""then entry.display.spellID=nil end
                if type(entry.trigger)=="table"and entry.trigger.spellID==""and entry.trigger.type~="bwtimer"and entry.trigger.type~="bwmsg"then entry.trigger.spellID=nil end
            end end
        end end
    end
    if ok and type(profile)=="table"and type(profile.minimumAddon)=="string"and type(ns.version)=="string"and Newer(profile.minimumAddon,ns.version)then return nil,"This profile needs Naowh Defensive Planner "..profile.minimumAddon.." or newer" end
    if not ok or not ns.Validate(profile) then return nil, "Unsupported profile data" end
    return profile
end
-- Adds every profile of an import; same names get a number. The bundle's active profile
-- (or the first one) becomes active.
-- History: a copy of a profile is kept before an import or restore changes it, newest first,
-- ten per game client, so any import can be undone from the Profiles page.
function ns.Snapshot(profile,reason)
    if type(profile)~="table"then return end
    local store=ns.Store();store.history=store.history or{}
    table.insert(store.history,1,{name=profile.name,client=profile.client or ns.Client(),time=time and time()or 0,reason=reason,profile=ns.Clone(profile)})
    local kept,n={},0
    for _,h in ipairs(store.history)do if h.client~=ns.Client()then kept[#kept+1]=h elseif n<10 then n=n+1;kept[#kept+1]=h end end
    store.history=kept
end
function ns.History()
    local out={};for i,h in ipairs(ns.Store().history or{})do if h.client==ns.Client()then out[#out+1]={index=i,name=h.name,time=h.time,reason=h.reason}end end
    return out
end
function ns.RestoreSnapshot(index)
    if (InCombatLockdown and InCombatLockdown())or ns.encounter then return nil,"Restore after combat and the encounter"end
    local store=ns.Store();local h=store.history and store.history[index]
    if not h or h.client~=ns.Client()then return nil,"Snapshot not found"end
    local copy=ns.Clone(h.profile)
    if store.profiles[h.name]then ns.Snapshot(store.profiles[h.name],"before restore")end
    store.profiles[h.name]=copy;store.active=h.name;ns.Reset()
    return h.name
end
-- Maps merge key by key; lists (sets' spell order, ticks) are taken whole from the import.
local function Merge(into,from)
    for k,v in pairs(from)do
        if type(v)=="table"and type(into[k])=="table"and #v==0 and next(v)then Merge(into[k],v)else into[k]=ns.Clone(v)end
    end
end
-- A one-boss string (ns.ExportBoss) replaces that boss in the active profile and adds its sets.
local function ImportPart(part)
    local target=ns.Active();if not target then return nil,"Create or select a profile first"end
    local enc=tonumber(part.part.encounter);if not enc then return nil,"Invalid boss export"end
    ns.Snapshot(target,"before boss import")
    local d,from=target.data,part.data
    d.raidReminders=d.raidReminders or{};d.raidReminders[enc]=ns.Clone(ns.Get(from.raidReminders,enc)or{})
    d.abilityBindings=d.abilityBindings or{}
    for spec,byEnc in pairs(from.abilityBindings or{})do d.abilityBindings[spec]=d.abilityBindings[spec]or{};d.abilityBindings[spec][enc]=ns.Clone(ns.Get(byEnc,enc))end
    for _,key in ipairs({"presets","scopePresets"})do if type(from[key])=="table"then d[key]=d[key]or{};Merge(d[key],from[key])end end
    return target.name
end
-- mode: "copy" (default: every profile is added, a clashing name gets a number), "merge" (into the
-- profile of the same name, imported entries win) or "replace" (the same-name profile is replaced).
-- Merge and replace keep a snapshot first.
function ns.Import(input,mode)
    if (InCombatLockdown and InCombatLockdown())or ns.encounter then return nil,"Import after combat and the encounter"end
    local profiles, error, report, active
    if ns.DecodeImport then profiles,error,report,active=ns.DecodeImport(input)else local p;p,error=ns.Decode(input);profiles=p and{p}end
    if not profiles then return nil, error end
    for _,profile in ipairs(profiles)do
        if profile.client ~= ns.Client() then return nil, "Profile belongs to " .. tostring(profile.client) .. "; use the matching game client" end
    end
    local store = ns.Store()
    local selected
    for i,profile in ipairs(profiles)do
        local base=tostring(profile.name or"Imported profile")
        local name
        if type(profile.part)=="table"then
            local err;name,err=ImportPart(profile);if not name then return nil,err end
        elseif mode=="replace"and store.profiles[base]then
            ns.Snapshot(store.profiles[base],"before replace");profile.part=nil;store.profiles[base]=profile;name=base
        elseif mode=="merge"and store.profiles[base]then
            ns.Snapshot(store.profiles[base],"before merge");Merge(store.profiles[base].data,profile.data);name=base
        else
            local index=2;name=base
            while store.profiles[name] do name = base .. " " .. index; index = index+1 end
            profile.name = name; store.profiles[name] = profile
        end
        if i==1 or base==active then selected=name end
    end
    store.active = selected
    if report then store.importReports=store.importReports or{};store.importReports[selected]=report;store.migrationSources=store.migrationSources or{};store.migrationSources[selected]=input end
    ns.Reset()
    return selected,nil,report,#profiles
end
-- One profile as an !NDP1: string (Codec.lua).
function ns.Encode(profile)
    if not profile or not ns.Validate(profile)then return nil,"Invalid profile data"end
    return ns.EncodeProfiles({profile},profile.name)
end
local function Sorted()
    local store=ns.Store();local list={}
    for name,p in pairs(store.profiles or{})do if p.client==nil or p.client==ns.Client()then list[#list+1]=p end end
    table.sort(list,function(a,b)if(a.name==store.active)~=(b.name==store.active)then return a.name==store.active end;return tostring(a.name)<tostring(b.name)end)
    return list
end
-- Every profile of this game client in one string, Mythic+ and raids included.
function ns.Export()
    local list=Sorted();if #list==0 then return nil,"No profiles to export"end
    return ns.EncodeProfiles(list,ns.Store().active)
end
function ns.ExportActive()
    local profile=ns.Active();if not profile then return nil,"No active profile"end;return ns.Encode(profile)
end
-- One boss of the active profile: its reminders, ability bindings of every spec and the sets they
-- use. Importing it replaces that boss in the receiver's active profile.
function ns.ExportBoss(encounter,label)
    local profile=ns.Active();if not profile then return nil,"No active profile"end
    encounter=tonumber(encounter);if not encounter then return nil,"Choose a boss"end
    local d=profile.data;local part={format=profile.format,addon=profile.addon,client=profile.client,minimumAddon=profile.minimumAddon,name=tostring(profile.name).." · "..tostring(label or encounter),part={encounter=encounter},data={}}
    part.data.raidReminders={[encounter]=ns.Clone(ns.Get(d.raidReminders,encounter)or{})}
    part.data.abilityBindings={}
    for spec,byEnc in pairs(d.abilityBindings or{})do local b=ns.Get(byEnc,encounter);if b then part.data.abilityBindings[spec]={[encounter]=ns.Clone(b)}end end
    for _,key in ipairs({"presets","scopePresets","activePreset","scopeActivePreset","contentDifficulties","settings"})do if d[key]~=nil then part.data[key]=ns.Clone(d[key])end end
    if not next(part.data.raidReminders[encounter])and not next(part.data.abilityBindings)then return nil,"Nothing planned on this boss yet"end
    -- Older versions would add a boss string as a whole profile, so it needs 0.7.0.
    local need=ns.MinimumAddon(part.data);part.minimumAddon=Newer("0.7.0",need)and"0.7.0"or need
    return ns.Encode(part)
end
