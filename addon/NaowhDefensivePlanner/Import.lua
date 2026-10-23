-- Independent, bounded data-only import adapters. Native exports always use PZTK1.
local _,ns=...
local function Native(name,data)return{format=1,addon="PztkReminders",client=ns.Client(),minimumAddon=ns.MinimumAddon(data),name=tostring(name or"Imported profile"):sub(1,120),data=data}end
local function Report(kind)return{source=kind,converted=0,issues={}}end
local function issue(report,key,reason)report.issues[#report.issues+1]=tostring(key)..": "..reason end
-- Accepts the URL-safe (NSRT) and the standard (Timeline Reminders) alphabet.
local function Base64(input)
    input=input:gsub("%+","-"):gsub("/","_")
    assert(input:match("^[A-Za-z0-9_=%-]+$")and #input%4~=1,"Invalid NSRT encoding")
    local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";local lookup={};for i=1,#alphabet do lookup[alphabet:sub(i,i)]=i-1 end
    local out,cache,bits={},0,0
    for i=1,#input do local ch=input:sub(i,i);if ch~="="then local v=lookup[ch];assert(v,"Invalid NSRT encoding");cache=cache*64+v;bits=bits+6;if bits>=8 then bits=bits-8;local byte=math.floor(cache/2^bits);out[#out+1]=string.char(byte);cache=cache%2^bits end end end
    return table.concat(out)
end
function ns.ReadCBOR(bytes)
    assert(type(bytes)=="string"and #bytes<=4000000,"CBOR size limit exceeded")
    local at,count=1,0
    local function take(n)assert(n>=0 and at+n<=#bytes+1,"Truncated CBOR");local s=bytes:sub(at,at+n-1);at=at+n;return s end
    local function uint(n)local value=0;for byte in take(n):gmatch(".")do value=value*256+byte:byte()end;assert(value<=9007199254740991,"CBOR integer exceeds safe precision");return value end
    local function argument(ai)if ai<24 then return ai elseif ai==24 then return uint(1)elseif ai==25 then return uint(2)elseif ai==26 then return uint(4)elseif ai==27 then return uint(8)elseif ai==31 then return -1 end;error("Invalid CBOR argument")end
    local function float(n)
        local raw=take(n);local first,second=raw:byte(1,2);local sign=first>=128 and -1 or 1;local exponent,mantissa,bits,bias
        if n==2 then exponent=math.floor((first%128)/4);mantissa=(first%4)*256+second;bits=10;bias=15
        elseif n==4 then exponent=(first%128)*2+math.floor(second/128);mantissa=second%128;for i=3,4 do mantissa=mantissa*256+raw:byte(i)end;bits=23;bias=127
        else exponent=(first%128)*16+math.floor(second/16);mantissa=second%16;for i=3,8 do mantissa=mantissa*256+raw:byte(i)end;bits=52;bias=1023 end
        assert(exponent~=bias*2+1,"Non-finite CBOR number")
        if exponent==0 then return sign*2^(1-bias)*(mantissa/2^bits)end
        return sign*2^(exponent-bias)*(1+mantissa/2^bits)
    end
    local item
    item=function(depth)
        count=count+1;assert(depth<=32 and count<=300000,"CBOR structure limit exceeded")
        local h=uint(1);local major,ai=math.floor(h/32),h%32
        if major==7 then if ai==20 then return false elseif ai==21 then return true elseif ai==22 then return nil elseif ai==25 then return float(2)elseif ai==26 then return float(4)elseif ai==27 then return float(8)end;error("Unsupported CBOR value")end
        local n=argument(ai)
        if major==0 or major==1 then assert(n>=0,"Invalid CBOR integer");return major==0 and n or -1-n end
        if major==2 or major==3 then assert(n>=0,"Indefinite CBOR strings are unsupported");return take(n)end
        if major==4 or major==5 then
            local value,seen={},{};local i=0
            while n<0 and bytes:byte(at)~=255 or n>=0 and i<n do
                i=i+1;local key=major==4 and i or item(depth+1)
                assert((type(key)=="string"or type(key)=="number")and not seen[key]and key~="__proto__"and key~="constructor"and key~="prototype","Invalid or duplicate CBOR key");seen[key]=true
                value[key]=item(depth+1)
            end
            if n<0 then assert(take(1):byte()==255,"Invalid CBOR break")end;return value
        end
        error("Unsupported CBOR type or tag")
    end
    local value=item(0);assert(at==#bytes+1,"Trailing CBOR data");return value
end
local function Uncompress(bytes)local raw=bytes and LibStub("LibDeflate"):DecompressDeflate(bytes);assert(raw and #raw<=4000000,"Invalid compression or expanded size limit exceeded");return raw end
local function NSR(input)
    assert(not input:find(":LIC1:",1,true),"Account-licensed packs must be managed in NSR. Licenses are not removed or bypassed.")
    local raw=Uncompress(LibStub("LibDeflate"):DecodeForPrint(input:sub(10)))
    local ok,source=LibStub("LibSerialize"):Deserialize(raw);assert(ok and type(source)=="table"and source.format==1,"Invalid NSR profile")
    assert(not source.licensed,"Account-licensed packs must be managed in NSR")
    local original=source.data
    if not original and type(source.profiles)=="table"then local first,v=next(source.profiles);assert(v and next(source.profiles,first)==nil,"Export one named NSR profile at a time");original=v end
    assert(type(original)=="table","No NSR profile data")
    assert(original.bindingsBySpec~=false or not next(original.abilityBindings or{}),"Migrate legacy non-spec bindings in NSR first")
    local data,report={},Report("NSR")
    for _,key in ipairs({"presets","activePreset","abilityBindings","integrationRules","raidReminders","callouts","voiceNone","leadTime","settings","scopePresets","scopeActivePreset","manualCatalog"})do data[key]=ns.Clone(original[key])end
    data.raidReminders=data.raidReminders or{}
    data.contentDifficulties={mythic={[1]=true,[2]=true,[8]=true,[23]=true,[24]=true},raid={[15]=true,[16]=true}}
    for enc,entries in pairs(original.customReminders or{})do for key,r in pairs(entries)do
        local success,error=pcall(function()
            local t=r.trigger or{};assert(({pull=true,stage=true,bwtimer=true,bwmsg=true})[t.type],"Unsupported trigger "..tostring(t.type))
            assert(not r.defensive or(r.preset and ns.Catalog.specs[r.specID]),"Missing specialization or set")
            local groups=ns.ParseCounter(t.counter);local delays={};local value=t.delay
            if value==nil or value==""then value="0"end
            for part in tostring(value):gmatch("[^,%s]+")do local m,s=part:match("^(%d+):(%d+%.?%d*)$");local delay=m and tonumber(m)*60+tonumber(s)or tonumber(part);assert(delay and delay>=0 and delay<=7200,"Unsupported delay");delays[#delays+1]=delay end
            assert(#delays>0,"Missing delay")
            data.raidReminders[enc]=data.raidReminders[enc]or{}
            for _,delay in ipairs(delays)do
                local e={name=r.name or tostring(key),enabled=r.enabled~=false,healerReminder=r.healerReminder,trigger={type=t.type,spellID=t.spellID,stage=t.stage,delay=delay,leadTime=t.timeleft or t.leadTime or 0,counterGroups=groups},target=r.specID and{specs={[r.specID]=true}}or{all=true},display={type=r.defensive and"icon"or"text",text=r.defensive and""or r.msg or r.name or"",dur=r.dur or 3,sound=r.sound,tts=r.tts},defensive=r.defensive and{specID=r.specID,preset=r.preset}or nil,pztkOrigin={section="customReminders",encounterId=tonumber(enc),key=key}}
                e.content=ns.EncounterScope(tonumber(enc))
                data.raidReminders[enc][ns.UID("nsr")]=e;report.converted=report.converted+1
            end
        end)
        if not success then issue(report,tostring(enc).."/"..tostring(key),tostring(error))end
    end end
    -- NSR "already covered" settings work here too; an out-of-range window is clamped.
    if data.settings and type(data.settings.coveredCastWindow)=="number"then data.settings.coveredCastWindow=math.max(0,math.min(60,data.settings.coveredCastWindow))end
    for spec,rules in pairs(data.integrationRules or{})do for key,r in pairs(rules)do
        
        if r.trigger and r.trigger.type~="exboss"and r.trigger.type~="auraSound"then rules[key]=nil;issue(report,spec.."/"..key,"Unsupported integration trigger")
        elseif r.preset and not ns.Get(ns.Get(data.presets,spec),r.preset)and not ns.Get(ns.Get(ns.Get(data.scopePresets,"mythic"),spec),r.preset)then
            -- The rule points at a set that is not in the export: it falls back to the active Mythic+ set.
            r.preset=nil;issue(report,spec.."/"..key,"Set was not in the export; this trash rule now uses the active Mythic+ set")
        end
    end end
    local p=Native(source.name,data);p.derivedFrom=ns.Clone(source.derivedFrom);p.author=source.author;return p,report
end
local function OnlyDifficulty(alerts,diff)
    if diff==nil then return alerts end
    local out={};for enc,diffs in pairs(alerts)do out[enc]={[diff]=type(diffs)=="table"and ns.Get(diffs,diff)or nil}end;return out
end
-- Every NSRT EncounterAlert export shape, normalised to EncounterAlerts[encounter][difficulty][key].
local function NsrtAlerts(kind,source)
    if kind=="Profile"then local alerts=source.sharedData and source.sharedData.EncounterAlerts;assert(type(alerts)=="table","This NSRT Profile has no shared EncounterAlerts");return alerts end
    if source.type=="alerts"then
        assert(type(source.encounterAlerts)=="table","This NSRT alerts export is empty")
        if source.encID==nil then return OnlyDifficulty(source.encounterAlerts,source.diffID)end
        local scoped=ns.Get(source.encounterAlerts,source.encID)
        return OnlyDifficulty({[source.encID]=type(scoped)=="table"and scoped or source.encounterAlerts},source.diffID)
    elseif source.type=="single_alert"then
        assert(source.encID~=nil and source.diffID~=nil and type(source.data)=="table","This NSRT single alert export has no encounter, difficulty or alert data")
        return {[source.encID]={[source.diffID]={[source.alertKey or"single_alert"]=source.data}}}
    elseif source.type=="alert_group"then
        local group=source.groupEncID~=nil and type(source.encounterAlerts)=="table"and ns.Get(source.encounterAlerts,source.groupEncID)
        assert(type(group)=="table","This NSRT alert group export is empty")
        return OnlyDifficulty({[source.groupEncID]=group},source.diffID)
    end
    error("Unsupported NSRT EncounterAlert export type "..tostring(source.type))
end
-- NSRT glowunit is a space-separated name string (a table in older saves); "glowunit" itself is a tag word NSRT drops.
local function GlowNames(value)
    local names,seen={},{}
    local function add(name)if type(name)=="string"and name~=""and name~="glowunit"and not seen[name]then seen[name]=true;names[#names+1]=name end end
    if type(value)=="string"then for name in value:gmatch("[^%s:,]+")do add(name)end
    elseif type(value)=="table"then for _,name in ipairs(value)do add(name)end end
    return names
end
local function GlowColor(value)
    if type(value)~="table"then return end
    local c={};for i=1,4 do local v=value[i];if i==4 and v==nil then v=1 end;if type(v)~="number"or v<0 or v>1 then return end;c[i]=v end;return c
end
local function NSRT(input)
    local kind,encoded=input:match("^!NSRT:(%a+):(.+)$");assert(kind=="Profile"or kind=="EncounterAlert","Use an NSRT Profile or EncounterAlert export")
    local source=ns.ReadCBOR(Uncompress(Base64(encoded)));assert(type(source)=="table","Invalid NSRT payload")
    local alerts=NsrtAlerts(kind,source)
    local report=Report("NSRT");local data={presets={},activePreset={},raidReminders={},settings={enabled=true,voiceOn=true}}
    local defaults=source.data and source.data.ReminderSettings or{}
    for enc,diffs in pairs(alerts)do for diff,entries in pairs(diffs)do for key,a in pairs(entries)do
        local path=tostring(enc).."/"..tostring(diff).."/"..tostring(key)
        local success,error=pcall(function()
            assert(tonumber(diff)==15 or tonumber(diff)==16,"Only Heroic and Mythic raid data is imported")
            assert(not a.ReloeReminder and not a.isSpecialDisplay and not a.castDuration and not a.isTaunt,"Unsupported alert engine")
            local typeMap={Icon="icon",Text="text",Bar="bar",Circle="circle"};local display=typeMap[a.DisplayType]or(not a.DisplayType and(a.spellID and"icon"or"text"));assert(display,"Unsupported display type")
            local glows=GlowNames(a.glowunit);assert(#glows<=40,"More than 40 glow targets");for _,name in ipairs(glows)do assert(#name<=100,"Glow target name is too long")end
            local glowColor=#glows>0 and GlowColor(a.glowColors)or nil
            local lc=a.loadConditions or{}
            if next(lc.Difficulties or{})then assert(ns.Get(lc.Difficulties,diff),"Excluded by difficulty filter")end
            if next(lc.EncounterIDs or{})then assert(ns.Get(lc.EncounterIDs,enc),"Excluded by encounter filter")end
            for k,v in pairs(lc)do assert(k=="SpecIDs"or k=="Roles"or k=="Classes"or k=="Names"or k=="Difficulties"or k=="EncounterIDs"or not v or type(v)=="table"and not next(v),"Unsupported load condition "..k)end
            local target,count,filtered={},0,false
            for from,to in pairs({SpecIDs="specs",Roles="roles",Classes="classes",Names="names"})do
                if next(lc[from]or{})then filtered=true end
                for k,v in pairs(lc[from]or{})do if v==true then target[to]=target[to]or{};target[to][k]=true;count=count+1 end end
            end
            assert(not filtered or count>0,"Recipient filter contains no enabled targets");if count==0 then target.all=true else target.matchAny=true end
            local duration=tonumber(a.dur or defaults[a.spellID and"SpellDuration"or"TextDuration"]or 10);assert(duration and duration>=0.1 and duration<=120,"Invalid display duration")
            local phases=a.phaseTimers
            if not phases or not next(phases)then phases={};if type(a.phase)=="table"then for _,p in ipairs(a.phase)do phases[p]=a.timers or{}end else phases[a.phase or 1]=a.timers or{}end end
            local staged={};local tts=a.TTS;if tts==nil then tts=defaults[a.spellID and"SpellTTS"or"TextTTS"]end;if tts==nil then tts=true end
            local prepulls=0
            for phase,times in pairs(phases)do for _,time in ipairs(times)do
                -- Negative phase-1 times are NSRT pre-pull reminders, run from the pull countdown.
                local prepull=type(time)=="number"and time<0
                assert(not prepull or tonumber(phase)==1,"Negative time outside phase 1 (NSRT only runs pre-pull times in phase 1)")
                assert(tonumber(phase)and tonumber(phase)>0 and tonumber(phase)<=100 and type(time)=="number"and time>=-3600 and time<=7200,"Unsupported phase or time")
                local trigger=prepull and{type="prepull",delay=-time,leadTime=duration}or{type=tonumber(phase)==1 and"pull"or"stage",stage=tonumber(phase)~=1 and tonumber(phase)or nil,delay=time,leadTime=math.min(duration,time)}
                local e={name=tostring(a.name or key):sub(1,120),enabled=a.enabled~=false,content="raid",difficulties={[tonumber(diff)]=true},trigger=trigger,target=ns.Clone(target),display={type=display,text=a.text or tostring(a.name or key),spellID=a.spellID,dur=prepull and duration or math.max(0.1,math.min(duration,time>0 and time or duration)),tts=tts~=false and tts~="false",ttsText=type(tts)=="string"and tts~="true"and tts~="false"and tts or nil,glowTargets=#glows>0 and ns.Clone(glows)or nil,glowColor=glowColor},pztkMigration={source="NSRT",key=key}}
                staged[#staged+1]=e;if prepull then prepulls=prepulls+1 end
            end end
            assert(#staged>0,"No scheduled times")
            data.raidReminders[tonumber(enc)]=data.raidReminders[tonumber(enc)]or{}
            for _,e in ipairs(staged)do data.raidReminders[tonumber(enc)][ns.UID("nsrt")]=e;report.converted=report.converted+1 end
            if a.TTSTimer or(a.text and a.text:find("%%"))then issue(report,path,"Review countdown / text substitutions")end
            if #glows>0 then issue(report,path,"Glow targets are literal character names or unit tokens; check nickname mappings")end
            if prepulls>0 then issue(report,path,"Pre-pull reminder needs a pull countdown near the boss; check it in game")end
        end)
        if not success then issue(report,path,tostring(error))end
    end end end
    assert(report.converted>0,"No supported encounter reminders. "..table.concat(report.issues,"; "):sub(1,400))
    for key,value in pairs(source.sharedData or{})do if key~="EncounterAlerts"and type(value)=="table"and next(value)then issue(report,key,"Retained in the local source archive; not migrated by this reminder adapter")end end
    return Native(source.profileName or"NSRT raid profile",data),report
end
---------------------------------------------------------------------------
-- Timeline Reminders (!TR2: CBOR, !TR: LibSerialize): one string per boss and difficulty,
-- difficulty 1 = Heroic, 2 = Mythic. A reminder's time is when it ends, from the pull or from
-- an event; it shows for its duration before that. Only the published format is read.
local classSpecs,meleeSpecs=ns.ClassSpecs,ns.MeleeSpecs
local spellEvents={SPELL_CAST_START=true,SPELL_CAST_SUCCESS=true,SPELL_AURA_APPLIED=true,SPELL_AURA_REMOVED=true,UNIT_SPELLCAST_START=true,UNIT_SPELLCAST_SUCCEEDED=true}
local function TrChunks(input)
    local out={}
    for prefix,body in input:gmatch("(!TR2?:)([^!]+)")do
        local data
        if prefix=="!TR2:"then
            local api=C_EncodingUtil
            if api and api.DecodeBase64 and api.DecompressString and api.DeserializeCBOR and Enum and Enum.CompressionMethod then
                local ok,v=pcall(function()return api.DeserializeCBOR(api.DecompressString(api.DecodeBase64(body,Enum.Base64Variant and Enum.Base64Variant.Standard),Enum.CompressionMethod.Deflate))end)
                if ok then data=v end
            end
            data=data or ns.ReadCBOR(Uncompress(Base64(body)))
        else
            local ok,v=LibStub("LibSerialize"):Deserialize(Uncompress(LibStub("LibDeflate"):DecodeForPrint(body)));assert(ok,"Invalid Timeline Reminders string");data=v
        end
        assert(type(data)=="table"and type(data.r)=="table","Invalid Timeline Reminders string")
        out[#out+1]=data
    end
    assert(#out>0,"Paste a Timeline Reminders export (!TR2: or !TR:)")
    return out
end
local function TrTarget(load)
    load=type(load)=="table"and load or{type="ALL"}
    local t=load.type
    if t==nil or t=="ALL"then return{all=true}end
    if t=="NAME"then assert(type(load.name)=="string"and load.name~="","Reminder for a player without a name");return{names={[load.name]=true}}end
    if t=="ROLE"then assert(({TANK=true,HEALER=true,DAMAGER=true})[load.role],"Unknown role");return{roles={[load.role]=true}}end
    if t=="GROUP"then local g=tonumber(load.group);assert(g and g>=1 and g<=8,"Unknown raid group");return{subgroups={[g]=true}}end
    if t=="CLASS_SPEC"then
        local specs=classSpecs[load.class];assert(specs,"Unknown class "..tostring(load.class))
        local index=tonumber(load.spec)
        if index then assert(specs[index],"Unknown specialization");return{specs={[specs[index]]=true}}end
        return{classes={[load.class]=true}}
    end
    if t=="POSITION"then
        local melee=load.position=="MELEE";local specs={}
        for _,list in pairs(classSpecs)do for _,id in ipairs(list)do if(meleeSpecs[id]~=nil)==melee then specs[id]=true end end end
        return{specs=specs,matchAny=true},"Melee / ranged became a list of specializations"
    end
    error("Unsupported recipient type "..tostring(t))
end
local function TrColor(c,alpha)
    if type(c)~="table"then return nil end
    local r,g,b=tonumber(c.r),tonumber(c.g),tonumber(c.b)
    if not(r and g and b)then return nil end
    local function clamp(v)return math.max(0,math.min(1,v))end
    return{clamp(r),clamp(g),clamp(b),alpha or 1}
end
function ns.TimelineRemindersImport(input)
    local report=Report("Timeline Reminders");local data={presets={},activePreset={},raidReminders={},settings={enabled=true,voiceOn=true}}
    local dungeon={};for _,g in ipairs(ns.Catalog.dungeons or{})do for _,n in ipairs(g.npcs or g.bosses or{})do if n.encounterId then dungeon[n.encounterId]=true end end end
    for _,chunk in ipairs(TrChunks(input))do
        local enc=tonumber(chunk.id);local diff=tonumber(chunk.d)
        for key,r in pairs(chunk.r)do
            local path=tostring(enc or"?").."/"..tostring(diff or"?").."/"..tostring(key)
            local ok,err=pcall(function()
                assert(enc and enc>0,"Export has no boss; export it from the boss timeline")
                assert(diff==1 or diff==2,"Only Heroic and Mythic timelines are imported")
                assert(type(r)=="table"and type(r.trigger)=="table"and type(r.display)=="table","Not a reminder")
                local tr,dp=r.trigger,r.display
                local time=tonumber(tr.time);assert(time and time>0 and time<=7200,"Time must be after the pull or event")
                local duration=math.max(0.1,math.min(120,tonumber(tr.duration)or 8))
                local trigger,warn
                local rel=type(tr.relativeTo)=="table"and tr.relativeTo or nil
                if not rel then trigger={type="pull",delay=time,leadTime=math.min(duration,time)}
                elseif spellEvents[rel.event]and tonumber(rel.value)then
                    local count=tonumber(rel.count)
                    -- Boss mod messages fire the reminder after delay seconds; it then shows for its duration.
                    trigger={type="bwmsg",spellID=math.floor(tonumber(rel.value)),delay=math.max(0,time-duration),counterGroups=count and count>=1 and{{{op="=",value=math.floor(count)}}}or nil}
                    warn="Started from the boss mod message of spell "..math.floor(tonumber(rel.value))..(count and(" #"..math.floor(count))or"")..", not from the combat log event; check the timing in game"
                else error("Relative to "..tostring(rel.event).." is not supported (needs a boss mod spell)")end
                local region=({TEXT="text",ICON="icon",BAR="bar",CIRCLE="circle"})[dp.region]or(dp.type=="SPELL"and"icon"or"text")
                local spell=dp.type=="SPELL"and tonumber(dp.spellID)and tonumber(dp.spellID)>0 and math.floor(tonumber(dp.spellID))or nil
                if region=="icon"then assert(spell,"Icon reminder without a spell")end
                local text=dp.type=="SPELL"and(type(dp.spellText)=="string"and dp.spellText or"")or(type(dp.text)=="string"and dp.text or"")
                local target,note=TrTarget(r.load)
                local display={type=region,text=text:sub(1,500),spellID=spell,dur=math.min(duration,time),tts=false}
                display.textColor=TrColor(dp.color)
                if region=="bar"then display.barColor=TrColor(dp.color)
                    local ticks={};for _,t in ipairs(type(dp.ticks)=="table"and dp.ticks or{})do t=tonumber(t);if t and t>0 and t<=120 and #ticks<20 then ticks[#ticks+1]=t end end
                    display.ticks=ticks[1]and ticks or nil
                end
                local linger=tonumber(tr.linger);if linger and linger>0 then display.sticky=math.min(60,linger)end
                if type(r.tts)=="table"and r.tts.enabled then display.tts=true;if type(r.tts.alias)=="string"and r.tts.alias~=""then display.ttsText=r.tts.alias:sub(1,200)end end
                if type(r.sound)=="table"and r.sound.enabled and type(r.sound.file)=="string"then
                    if r.sound.file:lower():find("addons[\\/]timelinereminders")then issue(report,path,"Sound from the Timeline Reminders folder was left out")
                    else display.sound=r.sound.file:sub(1,300)end
                end
                if type(r.countdown)=="table"and r.countdown.enabled then display.countdown=true;issue(report,path,"Spoken countdown became seconds shown after the text")end
                if type(r.glow)=="table"and r.glow.enabled and type(r.glow.names)=="table"then
                    local names={};for _,n in ipairs(r.glow.names)do if type(n)=="string"and n~=""and #n<=100 and #names<40 then names[#names+1]=n end end
                    if names[1]then display.glowTargets=names;display.glowColor=TrColor(r.glow.color)end
                end
                local mythicPlus=dungeon[enc]
                local e={name=(text~=""and text or spell and("Spell "..spell)or"Timeline reminder"):sub(1,120),enabled=true,content=mythicPlus and"mythic"or"raid",
                    difficulties={[mythicPlus and 8 or(diff==2 and 16 or 15)]=true},trigger=trigger,target=target,display=display,pztkMigration={source="TimelineReminders",key=tostring(key)}}
                data.raidReminders[enc]=data.raidReminders[enc]or{}
                data.raidReminders[enc][ns.UID("tr")]=e;report.converted=report.converted+1
                if warn then issue(report,path,warn)end
                if note then issue(report,path,note)end
                if text:find("{")then issue(report,path,"Text has {} tags from Timeline Reminders; check how it reads")end
            end)
            if not ok then issue(report,path,tostring(err):gsub("^.-:%d+: ",""))end
        end
    end
    assert(report.converted>0,"No supported reminders. "..table.concat(report.issues,"; "):sub(1,400))
    return Native("Timeline Reminders",data),report
end
function ns.DecodeImport(text)
    local ok,p,report=pcall(function()
        assert(type(text)=="string","Paste a profile string");local input=text:gsub("%s+","");assert(#input<=130000,"Import string exceeds 130 KB")
        if input:sub(1,6)=="PZTK1:"then local value,error=ns.Decode(input);assert(value,error);return value end
        if input:sub(1,9)=="NSRPACK2:"then return NSR(input)end
        if input:sub(1,6)=="!NSRT:"then return NSRT(input)end
        if input:sub(1,5)=="!TR2:"or input:sub(1,4)=="!TR:"then return ns.TimelineRemindersImport(input)end
        error("Expected PZTK1, NSRPACK2, an !NSRT or a Timeline Reminders export")
    end)
    if not ok then return nil,tostring(p)end
    if not ns.Validate(p)then return nil,"The imported profile contains unsupported data"end
    local encoded,error=ns.Encode(p);if not encoded then return nil,error end
    return p,nil,report
end
function ns.ImportReportText(report)
    if not report then return "Profile imported without migration."end
    local text={report.source.." migration: "..report.converted.." scheduled reminders created.",#report.issues.." items need review.",""}
    for _,s in ipairs(report.issues)do text[#text+1]=s end;return table.concat(text,"\n")
end
