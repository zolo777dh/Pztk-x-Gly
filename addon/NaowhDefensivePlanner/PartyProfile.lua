-- Party cooldowns profile: every setting of the party cooldowns and extras in one string that
-- others paste to get the same setup. "!PPD1:" and Base64 of a small own table format; reading it
-- never runs code from the string.
local _,ns=...
local W=ns.Widgets
local C=W.colors
local L=ns.L
local kit=ns.UIKit

local PREFIX="!PPD1:"
-- Kept per player, never sent: learned lengths, talents seen, migrations and the unlock state.
-- The settings kept for each of your specs stay home too.
local SKIP={learned=true,talentSpells=true,unlocked=true,aliasMigrated=true,learnedVersion=true,presetFix=true,perSpec=true,bySpec=true,profileSpec=true}
local MAX_TEXT,MAX_DEPTH,MAX_ITEMS=400000,12,50000

-- Values: t (table) ... e, s<len>:<bytes>, n<number>;, T and F for true and false.
local function Write(v,out,depth)
    local kind=type(v)
    if kind=="table"then
        if depth>MAX_DEPTH then error("too deep")end
        out[#out+1]="t"
        local keys={};for k in pairs(v)do if type(k)=="string"or type(k)=="number"then keys[#keys+1]=k end end
        table.sort(keys,function(a,b)if type(a)~=type(b)then return type(a)=="number"end;return a<b end)
        for _,k in ipairs(keys)do local x=v[k];local t=type(x)
            if t=="table"or t=="string"or t=="number"or t=="boolean"then Write(k,out,depth+1);Write(x,out,depth+1)end
        end
        out[#out+1]="e"
    elseif kind=="string"then out[#out+1]="s"..#v..":"..v
    elseif kind=="number"then out[#out+1]="n"..string.format("%.17g",v)..";"
    elseif kind=="boolean"then out[#out+1]=v and"T"or"F"
    else error("unsupported "..kind)end
end
local function Read(text)
    local at,items=1,0
    local function value(depth)
        if depth>MAX_DEPTH then error("too deep")end
        items=items+1;if items>MAX_ITEMS then error("too big")end
        local c=text:sub(at,at);at=at+1
        if c=="t"then
            local t={}
            while true do
                if text:sub(at,at)=="e"then at=at+1;return t end
                if at>#text then error("cut off")end
                local k=value(depth+1)
                if type(k)~="string"and type(k)~="number"then error("bad key")end
                t[k]=value(depth+1)
            end
        elseif c=="s"then
            local colon=text:find(":",at,true);if not colon then error("cut off")end
            local len=tonumber(text:sub(at,colon-1));if not len or len<0 or colon+len>#text then error("cut off")end
            local s=text:sub(colon+1,colon+len);at=colon+len+1;return s
        elseif c=="n"then
            local semi=text:find(";",at,true);if not semi then error("cut off")end
            local n=tonumber(text:sub(at,semi-1));if not n or n~=n then error("bad number")end
            at=semi+1;return n
        elseif c=="T"then return true
        elseif c=="F"then return false end
        error("bad data")
    end
    local v=value(0)
    if at<=#text then error("extra data")end
    return v
end

local CHARS="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local INDEX={};for i=1,64 do INDEX[CHARS:sub(i,i)]=i-1 end
local function Encode64(data)
    local out={}
    for i=1,#data,3 do
        local a,b,c=data:byte(i,i+2);local n=a*65536+(b or 0)*256+(c or 0)
        local d1,d2,d3,d4=math.floor(n/262144),math.floor(n/4096)%64,math.floor(n/64)%64,n%64
        out[#out+1]=CHARS:sub(d1+1,d1+1)..CHARS:sub(d2+1,d2+1)..(b and CHARS:sub(d3+1,d3+1)or"=")..(c and CHARS:sub(d4+1,d4+1)or"=")
    end
    return table.concat(out)
end
local function Decode64(text)
    text=text:gsub("[^%w%+/=]","")
    if #text%4~=0 then error("cut off")end
    local out={}
    for i=1,#text,4 do
        local q={text:byte(i,i+3)};local n,pad=0,0
        for k=1,4 do local ch=string.char(q[k])
            if ch=="="then pad=pad+1;n=n*64 else local v=INDEX[ch];if not v then error("bad text")end;n=n*64+v end
        end
        local a,b,c=math.floor(n/65536),math.floor(n/256)%256,n%256
        out[#out+1]=string.char(a)..(pad<2 and string.char(b)or"")..(pad<1 and string.char(c)or"")
    end
    return table.concat(out)
end
ns.PartyProfileBase64={encode=Encode64,decode=Decode64}

function ns.PartyProfileExport()
    local cfg=ns.PartyCooldownConfig();if ns.PartyExtrasConfig then ns.PartyExtrasConfig()end
    local copy={}
    for k,v in pairs(cfg)do if not SKIP[k]then copy[k]=v end end
    local out={};Write({v=1,version=tostring(ns.version or""),settings=copy},out,0)
    return PREFIX..Encode64(table.concat(out))
end
-- Replaces your settings with the ones in the string. Your learned lengths and talents stay.
function ns.PartyProfileImport(text)
    if type(text)~="string"then return false,L("Paste a profile string first")end
    text=text:gsub("^%s+",""):gsub("%s+$","")
    if text==""then return false,L("Paste a profile string first")end
    if #text>MAX_TEXT then return false,L("This profile string is too long")end
    if text:sub(1,#PREFIX)~=PREFIX then return false,L("This is not a party cooldowns profile string")end
    local ok,data=pcall(function()return Read(Decode64(text:sub(#PREFIX+1)))end)
    if not ok or type(data)~="table"or type(data.settings)~="table"then return false,L("This profile string is damaged")end
    local cfg=ns.PartyCooldownConfig()
    local n=0
    for k,v in pairs(data.settings)do
        if type(k)=="string"and not SKIP[k]and(cfg[k]==nil or type(cfg[k])==type(v))then cfg[k]=v;n=n+1 end
    end
    if n==0 then return false,L("This profile string is damaged")end
    -- Missing or new settings get their defaults again.
    ns.PartyCooldownConfig();if ns.PartyExtrasConfig then ns.PartyExtrasConfig()end
    if ns.RefreshPartyCooldowns then ns.RefreshPartyCooldowns()end
    if ns.RefreshPartyExtras then ns.RefreshPartyExtras()end
    return true
end

-- Settings for each of your specs: switched on, every spec keeps its own settings (what is
-- tracked, the lists, the look) and they change when your spec does. A healer can watch every
-- defensive of the group while a damage spec shows only a few.
local function Snapshot(cfg)local copy={};for k,v in pairs(cfg)do if not SKIP[k]then copy[k]=ns.Clone(v)end end;return copy end
local function Refresh()
    if ns.PartyCooldownListDirty then ns.PartyCooldownListDirty()end
    if ns.RebuildPartyCooldownSensors then ns.RebuildPartyCooldownSensors()end
    if ns.RefreshPartyCooldowns then ns.RefreshPartyCooldowns()end
    if ns.RefreshPartyExtras then ns.RefreshPartyExtras()end
end
local function Restore(cfg,copy)
    local old={};for k in pairs(cfg)do if not SKIP[k]then old[#old+1]=k end end
    for _,k in ipairs(old)do cfg[k]=nil end
    for k,v in pairs(copy)do if not SKIP[k]then cfg[k]=ns.Clone(v)end end
    -- Settings the saved copy did not have get their defaults again.
    ns.PartyCooldownConfig();if ns.PartyExtrasConfig then ns.PartyExtrasConfig()end
end
local function MySpecs()
    local _,class=UnitClass("player");return ns.ClassSpecs and ns.ClassSpecs[class]or{}
end
-- Your spec now: the settings of the spec you left are kept, those of the new one are loaded.
-- A spec with nothing kept yet starts from the settings you had.
function ns.PartyProfileSwitch(spec)
    local cfg=ns.PartyCooldownConfig()
    spec=spec or ns.Spec()
    if not cfg.perSpec or not spec then return false end
    cfg.bySpec=type(cfg.bySpec)=="table"and cfg.bySpec or{}
    local was=cfg.profileSpec
    if was==spec then return false end
    if was then cfg.bySpec[was]=Snapshot(cfg)end
    cfg.profileSpec=spec
    if type(cfg.bySpec[spec])=="table"then Restore(cfg,cfg.bySpec[spec])end
    Refresh();return true
end
function ns.SetPartyProfilePerSpec(on)
    local cfg=ns.PartyCooldownConfig()
    cfg.bySpec=type(cfg.bySpec)=="table"and cfg.bySpec or{}
    if on then cfg.perSpec=true;cfg.profileSpec=ns.Spec();if cfg.profileSpec then cfg.bySpec[cfg.profileSpec]=Snapshot(cfg)end
    else cfg.perSpec=nil;cfg.profileSpec=nil end
end
-- The settings you have now become those of every spec of your class.
function ns.PartyProfileCopyToSpecs()
    local cfg=ns.PartyCooldownConfig()
    cfg.bySpec=type(cfg.bySpec)=="table"and cfg.bySpec or{}
    for _,spec in ipairs(MySpecs())do cfg.bySpec[spec]=Snapshot(cfg)end
    return true
end
local watch=CreateFrame("Frame")
for _,e in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_SPECIALIZATION_CHANGED","ACTIVE_TALENT_GROUP_CHANGED"})do pcall(watch.RegisterEvent,watch,e)end
watch:SetScript("OnEvent",function(_,event,unit)
    if event=="PLAYER_SPECIALIZATION_CHANGED"and unit and unit~="player"then return end
    ns.PartyProfileSwitch()
end)

-- The profile page: your string to copy, and a box to paste someone's.
function ns.DrawPartyProfile(parent,apply,d)
    local left=W.Card(parent,0,56,454,320,L("Share my settings"))
    W.Label(left,L("Every setting of the party cooldowns, lists, look and extras in one string. Press the box, then Ctrl+A and Ctrl+C, and share it."),12,34,430,11,C.muted)
    local out=W.Input(left,d.exported or"",12,80,430,"pcd-profile:export",true)
    W.Button(left,L("Make the string"),12,276,430,function()d.exported=ns.PartyProfileExport();kit.refresh()
        local box=ns.UIControls["pcd-profile:export"];if box then box:SetFocus();box:HighlightText()end end,false,"pcd-profile:make",{kind="primary",align="CENTER"})
    if out and out.SetScript then out:SetScript("OnEditFocusGained",function(self)self:HighlightText()end)end
    local right=W.Card(parent,466,56,454,320,L("Use someone's settings"))
    W.Label(right,L("Paste a profile string and press Import. Your settings are replaced; your learned cooldown lengths stay."),12,34,430,11,C.muted)
    local input=W.Input(right,d.importText or"",12,80,430,"pcd-profile:import",true)
    W.OnText(input,function(self)d.importText=self:GetText()end)
    W.Button(right,L("Import"),12,276,430,function()
        local box=ns.UIControls["pcd-profile:import"];local text=box and box:GetText()or d.importText
        local ok,err=ns.PartyProfileImport(text);if ok then d.importText=""end
        kit.done(ok,err,L("Profile imported"))
    end,false,"pcd-profile:importButton",{kind="primary",align="CENTER"})
    local cfg=ns.PartyCooldownConfig()
    local specs=W.Card(parent,0,388,920,234,L("Settings for each of my specs"))
    W.Toggle(specs,L("Own settings for each of my specs"),cfg.perSpec==true,12,30,600,function(v)ns.SetPartyProfilePerSpec(v);kit.refresh()end,"pcd-profile:perSpec")
    W.Label(specs,L("Each spec keeps its own settings: what is tracked, the lists and the look. They change when your spec does. A healer can watch every defensive of the group, a damage dealer or a tank only a few."),12,68,896,11,C.muted)
    local now=ns.Spec();local name=now and ns.Catalog and ns.Catalog.specs and ns.Catalog.specs[now]
    if cfg.perSpec then W.Label(specs,L("Now")..": "..(name and L(name)or"?"),12,118,600,12,C.text)end
    W.Button(specs,L("Copy these settings to all my specs"),12,150,300,function()ns.PartyProfileCopyToSpecs();kit.done(true,nil,L("Copied to all your specs"))end,false,"pcd-profile:copySpecs",{kind="outline",align="CENTER"})
end
