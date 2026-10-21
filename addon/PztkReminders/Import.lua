-- Independent, bounded data-only import adapters. Native exports always use PZTK1.
local _,ns=...
local function Native(name,data)return{format=1,addon="PztkReminders",client=ns.Client(),minimumAddon="0.3.0",name=tostring(name or"Imported profile"):sub(1,120),data=data}end
local function Report(kind)return{source=kind,converted=0,issues={}}end
local function issue(report,key,reason)report.issues[#report.issues+1]=tostring(key)..": "..reason end
local function Base64(input)
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
    data.contentDifficulties={mythic={[8]=true},raid={[15]=true,[16]=true}}
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
    for _,key in ipairs({"cdmGlow","coveredSkip","coveredSkipDefaultOn","coveredCastWindow"})do if data.settings and data.settings[key]then issue(report,"settings/"..key,"Setting retained; this behavior is not implemented")end end
    for spec,rules in pairs(data.integrationRules or{})do for key,r in pairs(rules)do
        
        if r.trigger and r.trigger.type~="exboss"and r.trigger.type~="auraSound"then rules[key]=nil;issue(report,spec.."/"..key,"Unsupported integration trigger")
        elseif r.preset and not ns.Get(ns.Get(data.presets,spec),r.preset)then issue(report,spec.."/"..key,"Set is missing; empty-text ExBoss rules retain active-set fallback")end
    end end
    local p=Native(source.name,data);p.derivedFrom=ns.Clone(source.derivedFrom);p.author=source.author;return p,report
end
local function NSRT(input)
    local kind,encoded=input:match("^!NSRT:(%a+):(.+)$");assert(kind=="Profile"or kind=="EncounterAlert","Use a full NSRT Profile or EncounterAlert export")
    local source=ns.ReadCBOR(Uncompress(Base64(encoded)));assert(type(source)=="table","Invalid NSRT payload")
    local alerts=kind=="Profile"and source.sharedData and source.sharedData.EncounterAlerts or source.type=="alerts"and source.encounterAlerts
    assert(type(alerts)=="table","Export a full NSRT profile or all encounter alerts")
    local report=Report("NSRT");local data={presets={},activePreset={},raidReminders={},settings={enabled=true,voiceOn=true}}
    local defaults=source.data and source.data.ReminderSettings or{}
    for enc,diffs in pairs(alerts)do for diff,entries in pairs(diffs)do for key,a in pairs(entries)do
        local path=tostring(enc).."/"..tostring(diff).."/"..tostring(key)
        local success,error=pcall(function()
            assert(tonumber(diff)==15 or tonumber(diff)==16,"Only Heroic and Mythic raid data is imported")
            assert(not a.ReloeReminder and not a.isSpecialDisplay and not a.castDuration and not a.isTaunt and not a.glow and not a.Glow and not a.glowSettings,"Unsupported alert engine")
            local typeMap={Icon="icon",Text="text",Bar="bar",Circle="circle"};local display=typeMap[a.DisplayType]or(not a.DisplayType and(a.spellID and"icon"or"text"));assert(display,"Unsupported display type")
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
            for phase,times in pairs(phases)do for _,time in ipairs(times)do
                assert(tonumber(phase)and tonumber(phase)>0 and tonumber(phase)<=100 and type(time)=="number"and time>=0 and time<=7200,"Unsupported phase or time")
                local e={name=tostring(a.name or key):sub(1,120),enabled=a.enabled~=false,content="raid",difficulties={[tonumber(diff)]=true},trigger={type=tonumber(phase)==1 and"pull"or"stage",stage=tonumber(phase)~=1 and tonumber(phase)or nil,delay=time,leadTime=math.min(duration,time)},target=ns.Clone(target),display={type=display,text=a.text or tostring(a.name or key),spellID=a.spellID,dur=math.max(0.1,math.min(duration,time>0 and time or duration)),tts=tts~=false and tts~="false",ttsText=type(tts)=="string"and tts~="true"and tts~="false"and tts or nil},pztkMigration={source="NSRT",key=key}}
                staged[#staged+1]=e
            end end
            assert(#staged>0,"No scheduled times")
            data.raidReminders[tonumber(enc)]=data.raidReminders[tonumber(enc)]or{}
            for _,e in ipairs(staged)do data.raidReminders[tonumber(enc)][ns.UID("nsrt")]=e;report.converted=report.converted+1 end
            if a.TTSTimer or(a.text and a.text:find("%%"))then issue(report,path,"Review countdown / text substitutions")end
        end)
        if not success then issue(report,path,tostring(error))end
    end end end
    assert(report.converted>0,"No supported encounter reminders. "..table.concat(report.issues,"; "):sub(1,400))
    for key,value in pairs(source.sharedData or{})do if key~="EncounterAlerts"and type(value)=="table"and next(value)then issue(report,key,"Retained in the local source archive; not migrated by this reminder adapter")end end
    return Native(source.profileName or"NSRT raid profile",data),report
end
function ns.DecodeImport(text)
    local ok,p,report=pcall(function()
        assert(type(text)=="string","Paste a profile string");local input=text:gsub("%s+","");assert(#input<=130000,"Import string exceeds 130 KB")
        if input:sub(1,6)=="PZTK1:"then local value,error=ns.Decode(input);assert(value,error);return value end
        if input:sub(1,9)=="NSRPACK2:"then return NSR(input)end
        if input:sub(1,6)=="!NSRT:"then return NSRT(input)end
        error("Expected PZTK1, NSRPACK2 or a full !NSRT profile")
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
