-- Players page: nicknames shared inside the group and an addon version check.
local _,ns=...
local W=ns.Widgets
local C=W.colors
local L=ns.L
local kit=ns.UIKit

local function Players()
    local store=ns.Store();store.players=store.players or{}
    local p=store.players;p.nicknames=p.nicknames or{};p.versions=p.versions or{}
    if p.share==nil then p.share=true end;if p.accept==nil then p.accept=true end
    return p
end
ns.PlayersData=Players
function ns.MyNickname()return Players().nick end
function ns.Nickname(name)return Players().nicknames[ns.ShortName(name)or""]end
local function validNick(nick)
    nick=tostring(nick or""):match("^%s*(.-)%s*$");assert(#nick<=24,"Use a nickname of at most 24 characters");assert(not nick:find("[|\t\n]"),"Nicknames cannot contain | or line breaks");return nick
end
local lastShare=0
function ns.ShareNickname(force)
    local p=Players();if not p.share or not p.nick or p.nick==""then return false end
    if not force and GetTime()-lastShare<10 then return false end
    lastShare=GetTime();return ns.Send("NICK",p.nick)
end
function ns.SetMyNickname(nick)
    local ok,value=pcall(validNick,nick);if not ok then return nil,tostring(value)end
    Players().nick=value~=""and value or nil;ns.ShareNickname(true);return true
end
function ns.SetNickname(name,nick)
    name=ns.ShortName(tostring(name or""):match("^%s*(.-)%s*$"));if not name or name==""then return nil,"Enter the player's character name"end
    local ok,value=pcall(validNick,nick);if not ok then return nil,tostring(value)end
    if value==""then return nil,"Enter a nickname"end
    Players().nicknames[name]=value;return true
end
function ns.RemoveNickname(name)Players().nicknames[name]=nil;return true end
function ns.WipeNicknames()Players().nicknames={};return true end
ns.CommHandlers.NICK=function(nick,sender)
    local p=Players();if not p.accept or not sender then return end
    local ok,value=pcall(validNick,nick);if ok and value~=""then p.nicknames[sender]=value end
end
-- Version check: ask the group, every Naowh Defensive Planner answers with its version.
local pending
function ns.CheckVersions()
    local p=Players();p.versions={};p.versions[UnitName("player")]=ns.version;p.checkedAt=GetTime()
    local sent=ns.Send("VERQ","")
    pending=true
    if C_Timer and C_Timer.NewTimer then C_Timer.NewTimer(5,function()pending=false;if ns.RefreshWorkspace then ns.RefreshWorkspace()end end)end
    return sent
end
ns.CommHandlers.VERQ=function()ns.Send("VER",ns.version)end
ns.CommHandlers.VER=function(version,sender)
    if sender and type(version)=="string"and #version<=20 then Players().versions[sender]=version;if ns.RefreshWorkspace then ns.RefreshWorkspace()end end
end
-- Nicknames on unit frames (NSRT): NDPAPI:GetName(unit or name) for other addons, the ElvUI tag
-- [ndp:nick], and optionally the Blizzard party and raid frames. Names the game hides stay as they are.
function ns.DisplayName(value)
    local name=value
    if type(value)=="string"and UnitName and(value=="player"or value:match("^party%d")or value:match("^raid%d"))then
        local ok,n=pcall(UnitName,value);name=ok and n or nil
    end
    if not ns.Plain(name,"string")or name==""then return value end
    local short=ns.ShortName(name)or name
    if ns.IsMe and ns.IsMe(short)and ns.MyNickname()then return ns.MyNickname()end
    return ns.Nickname(short)or short
end
NDPAPI=type(NDPAPI)=="table"and NDPAPI or{}
function NDPAPI.GetName(a,b)if a==NDPAPI then a=b end;return ns.DisplayName(a)end
local elvTag
local function ElvTag()
    if elvTag or type(ElvUI)~="table"then return end
    local E=ElvUI[1];if type(E)~="table"or type(E.AddTag)~="function"then return end
    elvTag=pcall(E.AddTag,E,"ndp:nick","UNIT_NAME_UPDATE GROUP_ROSTER_UPDATE",function(unit)return ns.DisplayName(unit)end)
    if elvTag and type(E.AddTagInfo)=="function"then pcall(E.AddTagInfo,E,"ndp:nick","Names","Nickname from Naowh Defensive Planner")end
end
local hooked
local function BlizzardFrames()
    if hooked or not(hooksecurefunc and CompactUnitFrame_UpdateName)then return end
    hooked=true
    hooksecurefunc("CompactUnitFrame_UpdateName",function(frame)
        if not Players().frames or type(frame)~="table"or not frame.name or type(frame.unit)~="string"then return end
        if not(frame.unit=="player"or frame.unit:match("^party%d")or frame.unit:match("^raid%d"))then return end
        local nick=ns.DisplayName(frame.unit)
        if ns.Plain(nick,"string")and nick~=frame.unit then pcall(frame.name.SetText,frame.name,nick)end
    end)
end
ns.ApplyFrameNicknames=function()ElvTag();BlizzardFrames()end
local events=CreateFrame("Frame");events:RegisterEvent("GROUP_ROSTER_UPDATE");events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent",function(_,event)if event=="PLAYER_ENTERING_WORLD"then ns.ApplyFrameNicknames()else ns.ShareNickname()end end)

local function DrawPlayers(parent)
    local state=kit.state;local p=Players();local d=state.drafts
    d.players=d.players or{nick=p.nick or"",newName="",newNick=""};local f=d.players
    kit.header(parent,L("Players"),L("Nicknames shared with the group, and an addon version check."))
    local left=W.Card(parent,0,56,454,536,L("Nicknames"))
    W.Field(left,L("YOUR NICKNAME"),f.nick,12,34,300,"players:nick")
    W.Button(left,L("Save"),320,50,122,function()local ok,err=ns.SetMyNickname(ns.UIControls["players:nick"]:GetText());kit.done(ok,err,L("Nickname saved"))end,false,"players-nick",{kind="primary",align="CENTER"})
    W.Toggle(left,L("Share my nickname with the group"),p.share,12,92,430,function(v)p.share=v;if v then ns.ShareNickname(true)end end,"players-share")
    W.Toggle(left,L("Accept nicknames from the group"),p.accept,12,120,430,function(v)p.accept=v end,"players-accept")
    W.Heading(left,L("Known nicknames"),12,156,430)
    local names={};for name in pairs(p.nicknames)do names[#names+1]=name end;table.sort(names)
    local list=W.Scroll(left,12,180,430,220,"players:nicks",C.background);local y=4
    if #names==0 then W.Label(list,L("No nicknames yet."),8,8,380,12,C.muted)end
    for _,name in ipairs(names)do
        local row=W.Panel(list,0,y,404,28,C.raised,C.clear,6);W.Label(row,name,10,8,170,12,C.text);W.Label(row,p.nicknames[name],190,8,170,12,C.accent)
        W.Button(row,"",372,2,26,function()kit.done(ns.RemoveNickname(name),nil,L("Nickname removed"))end,false,"players-del:"..name,{h=24,kind="danger",glyph="trash",tooltip=L("Remove")})
        y=y+32
    end;list:SetHeight(math.max(1,y))
    W.Field(left,L("PLAYER"),f.newName,12,410,160,"players:newName");W.Field(left,L("NICKNAME"),f.newNick,180,410,150,"players:newNick")
    W.Button(left,L("Add"),338,426,104,function()local ok,err=ns.SetNickname(ns.UIControls["players:newName"]:GetText(),ns.UIControls["players:newNick"]:GetText());if ok then f.newName="";f.newNick=""end;kit.done(ok,err,L("Nickname added"))end,false,"players-add",{align="CENTER"})
    W.Button(left,d.wipeNicks and L("Confirm: remove all")or L("Remove all nicknames"),12,476,220,function()if not d.wipeNicks then d.wipeNicks=true;kit.refresh()return end;d.wipeNicks=nil;kit.done(ns.WipeNicknames(),nil,L("All nicknames removed"))end,false,"players-wipe",{kind="danger",align="CENTER"})
    local right=W.Card(parent,466,56,454,536,L("Group and versions"))
    W.Button(right,L("Check versions"),12,34,200,function()local sent=ns.CheckVersions();kit.notify(sent and L("Asked the group; answers arrive within a few seconds")or L("Not in a group: only your own version is listed"));kit.refresh()end,false,"players-check",{glyph="check"})
    W.Label(right,L("Your version")..": "..ns.version,226,42,214,12,C.soft)
    local roster=kit.roster();local y2=78
    for i,r in ipairs(roster)do if i<=15 then
        local version=p.versions[r.name];local state_=version and(version==ns.version and C.ok or C.warning)or C.faint
        local row=W.Panel(right,12,y2,430,22,C.raised,C.clear,6);W.Dot(row,8,7,kit.classColor(r.class));W.Label(row,r.name..(p.nicknames[r.name]and(" ("..p.nicknames[r.name]..")")or""),22,5,260,12,kit.classColor(r.class))
        W.Label(row,version or(p.checkedAt and(pending and L("waiting...")or L("no answer"))or"-"),290,5,130,12,state_)
        y2=y2+24
    end end
    W.Toggle(right,L("Show nicknames on Blizzard party and raid frames"),p.frames,12,448,430,function(v)p.frames=v;ns.ApplyFrameNicknames()end,"players-frames")
    W.Label(right,L("ElvUI: use the [ndp:nick] tag. Other addons can call NDPAPI:GetName(unit). No answer to a version check means the addon is missing, disabled, or the player is offline."),12,482,430,11,C.muted)
end
ns.ExtraPages.players=DrawPlayers
