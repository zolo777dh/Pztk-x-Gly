-- Group messages between Naowh Defensive Planner users: notes, break timers, nicknames, version checks.
-- Long payloads are split into chunks and sent from a small queue that waits out the game's throttle.
local _,ns=...
local PREFIX="NDP"
local queue,parts,serial,ticker={},{},0,nil
ns.CommHandlers={}
-- The prefix is registered at load, so messages arrive even before anything is sent. The game
-- answers with a result code (older clients with true/false); an already registered prefix is fine.
local isRegistered=false
local function registered()
    if isRegistered then return true end
    if not(C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix)then return false end
    local ok,result=pcall(C_ChatInfo.RegisterAddonMessagePrefix,PREFIX)
    local codes=Enum and Enum.RegisterAddonMessagePrefixResult
    if ok then
        if result==nil or result==true then isRegistered=true
        elseif codes then isRegistered=result==codes.Success or result==codes.DuplicatePrefix
        else isRegistered=result==0 or result==1 end
    end
    return isRegistered
end
registered()
function ns.GroupChannel()
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)and not(IsInGroup(LE_PARTY_CATEGORY_HOME))then return"INSTANCE_CHAT"end
    if IsInRaid and IsInRaid()then return"RAID"end
    if IsInGroup and IsInGroup()then return"PARTY"end
end
local function pump()
    local item=queue[1]
    if not item then if ticker then ticker:Cancel();ticker=nil end;return end
    if not(C_ChatInfo and C_ChatInfo.SendAddonMessage)then for k in pairs(queue)do queue[k]=nil end;return end
    local ok,result=pcall(C_ChatInfo.SendAddonMessage,PREFIX,item.text,item.channel,item.target)
    -- Throttled or restricted (combat in instances): keep the chunk and try again on the next tick.
    local throttled=Enum and Enum.SendAddonMessageResult and(result==Enum.SendAddonMessageResult.AddonMessageThrottle or result==Enum.SendAddonMessageResult.ChannelThrottle or result==Enum.SendAddonMessageResult.GeneralError)
    item.tries=(item.tries or 0)+1
    if not ok or not throttled or item.tries>100 then table.remove(queue,1)end
end
-- Sends text of any length to the group (or one player with channel "WHISPER").
function ns.Send(kind,text,channel,target)
    channel=channel or ns.GroupChannel();if not channel or not registered()then return false end
    text=tostring(text or"");serial=serial%9999+1
    local size=200;local count=math.max(1,math.ceil(#text/size))
    for i=1,count do queue[#queue+1]={text=kind.."\t"..serial.."\t"..i.."\t"..count.."\t"..text:sub((i-1)*size+1,i*size),channel=channel,target=target}end
    pump()
    if queue[1]and not ticker and C_Timer and C_Timer.NewTicker then ticker=C_Timer.NewTicker(0.3,pump)end
    return true
end
function ns.ShortName(name)
    if type(name)~="string"then return nil end
    if Ambiguate then local ok,short=pcall(Ambiguate,name,"none");if ok and type(short)=="string"then return short end end
    return(name:match("^([^%-]+)"))
end
-- Realms as group messages name them: no spaces or hyphens.
local function Realm(realm)
    if type(realm)~="string"or realm==""then return nil end
    realm=realm:gsub("[%s%-]","");return realm~=""and realm or nil
end
function ns.MyRealm()
    for _,get in ipairs({GetNormalizedRealmName or false,GetRealmName or false})do
        if get then local ok,r=pcall(get);r=ok and ns.Plain(r,"string")and Realm(r);if r then return r end end
    end
end
-- "Name-Realm" for a player: the realm given, or the one in the name, or your own. Two players of
-- the same name on different realms never share it. Short names are only for showing.
function ns.FullName(name,realm)
    if not(ns.Plain(name,"string")and name~="")then return nil end
    local short,inName=name:match("^([^%-]+)%-(.+)$")
    if short then name,realm=short,inName end
    realm=Realm(realm)or ns.MyRealm()
    return realm and name.."-"..realm or name
end
function ns.UnitFullName(unit)
    if not UnitName then return nil end
    local ok,name,realm=pcall(UnitName,unit);if not ok or not ns.Plain(name,"string")then return nil end
    return ns.FullName(name,ns.Plain(realm,"string")and realm or nil)
end
-- Leader or assistant of the current group, by full name.
function ns.GroupAuthority(name)
    name=ns.FullName(name);if not name then return false end
    if IsInRaid and IsInRaid()and GetRaidRosterInfo then
        for i=1,40 do local who,rank=GetRaidRosterInfo(i);if ns.FullName(who)==name then return(tonumber(rank)or 0)>=1 end end
        return false
    end
    for _,unit in ipairs({"player","party1","party2","party3","party4"})do
        if UnitExists and UnitExists(unit)and ns.UnitFullName(unit)==name then return UnitIsGroupLeader and UnitIsGroupLeader(unit)==true end
    end
    return false
end
local events=CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent",function(_,_,prefix,text,channel,sender)
    if prefix~=PREFIX or type(text)~="string"then return end
    local full=ns.FullName(sender);if not full or full==ns.UnitFullName("player")then return end
    local kind,id,i,count,chunk=text:match("^(%w+)\t(%d+)\t(%d+)\t(%d+)\t(.*)$")
    if not kind then return end
    i,count=tonumber(i),tonumber(count);if count<1 or count>200 or i<1 or i>count then return end
    -- Unfinished messages expire after 30 s, at most 50 wait at a time, and a message whose part
    -- count changed (a reused number) starts over.
    local now=GetTime and GetTime()or 0;local waiting,oldest,oldestAt=0,nil,nil
    for k,p in pairs(parts)do
        if now-p.at>30 then parts[k]=nil
        else waiting=waiting+1;if not oldestAt or p.at<oldestAt then oldest,oldestAt=k,p.at end end
    end
    local key=tostring(sender)..":"..kind..":"..id;local p=parts[key]
    if p and p.count~=count then p=nil end
    if not p then
        if waiting>=50 and oldest then parts[oldest]=nil end
        p={n=0,count=count,at=now};parts[key]=p
    end
    if not p[i]then p[i]=chunk;p.n=p.n+1 end
    if p.n<count then return end
    parts[key]=nil;local handler=ns.CommHandlers[kind]
    -- Handlers get the short name (nicknames, notes) and the full one (who exactly sent it).
    if handler then pcall(handler,table.concat(p,"",1,count),ns.ShortName(sender),channel,full)end
end)
