-- Raid tools: ready check, pull and break timers, invites, group arrangement and assistants.
-- Everything here uses the game's own group API and needs leader or assistant where the game asks for it.
local _,ns=...
local W=ns.Widgets
local C=W.colors
local L=ns.L
local kit=ns.UIKit

local function Cfg()
    local store=ns.Store();store.raidtools=store.raidtools or{keywords="inv, invite",rank=1,breakAnnounce=true,promote=""}
    return store.raidtools
end
ns.RaidToolsConfig=Cfg
local function channel()return IsInRaid and IsInRaid()and"RAID"or IsInGroup and IsInGroup()and"PARTY"or nil end
local function lead()return ns.GroupAuthority(UnitName("player"))or not channel()end
---------------------------------------------------------------------------
-- Break timer: a small plain bar of text, updated once a second.
local bar,ticker,breakEnds
local function stopBreak()if ticker then ticker:Cancel();ticker=nil end;breakEnds=nil;if bar then bar:Hide()end end
local function showBreak()
    if not bar then
        bar=CreateFrame("Frame",nil,UIParent);bar:SetSize(240,34);bar:SetPoint("TOP",UIParent,"TOP",0,-160);bar:SetFrameStrata("HIGH")
        bar.bg=bar:CreateTexture(nil,"BACKGROUND");bar.bg:SetAllPoints();bar.bg:SetColorTexture(0.04,0.055,0.08,0.8)
        bar.text=bar:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");bar.text:SetPoint("CENTER");bar.text:SetTextColor(1,1,1,1)
    end
    local left=math.max(0,math.floor((breakEnds or 0)-GetTime()))
    bar.text:SetText(string.format("%s %d:%02d",L("Break"),math.floor(left/60),left%60));bar:Show()
    if left<=0 then stopBreak();ns.Print(L("Break is over."));if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then pcall(PlaySound,SOUNDKIT.RAID_WARNING,"Master")end end
end
function ns.StartBreak(minutes,remote)
    minutes=tonumber(minutes);if not minutes or minutes<0 or minutes>60 then return nil,"Enter break minutes from 0 to 60"end
    if not remote and channel()and not lead()then return nil,"Only the group leader or an assistant can start a break"end
    stopBreak()
    if not remote then
        ns.Send("BREAK",tostring(minutes))
        if Cfg().breakAnnounce and channel()and SendChatMessage then pcall(SendChatMessage,minutes>0 and("Break: "..minutes.." min")or"Break cancelled",channel())end
    end
    if minutes==0 then return true end
    breakEnds=GetTime()+minutes*60;showBreak()
    if C_Timer and C_Timer.NewTicker then ticker=C_Timer.NewTicker(1,showBreak)end
    return true
end
function ns.BreakRemaining()return breakEnds and math.max(0,breakEnds-GetTime())or nil end
ns.CommHandlers.BREAK=function(minutes,sender)if ns.GroupAuthority(sender)then ns.StartBreak(minutes,true)end end
---------------------------------------------------------------------------
-- Invites.
local function keywords()
    local out={};for word in(tostring(Cfg().keywords or"")..","):gmatch("([^,]*),")do word=word:match("^%s*(.-)%s*$"):lower();if word~=""then out[word]=true end end;return out
end
local function invite(name)
    if not(C_PartyInfo and C_PartyInfo.InviteUnit)then return false end
    if IsInGroup and IsInGroup()and not(IsInRaid and IsInRaid())and(GetNumGroupMembers and GetNumGroupMembers()or 0)>=5 and C_PartyInfo.ConvertToRaid then pcall(C_PartyInfo.ConvertToRaid)end
    return(pcall(C_PartyInfo.InviteUnit,name))
end
local function guildMember(name)
    if C_GuildInfo and C_GuildInfo.MemberExistsByName then local ok,v=pcall(C_GuildInfo.MemberExistsByName,name);return ok and v==true end
    return false
end
function ns.InviteGuild()
    if not(IsInGuild and IsInGuild())then return nil,"You are not in a guild"end
    if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster)end
    local me=UnitName("player");local count=0;local maxRank=tonumber(Cfg().rank)or 1
    for i=1,(GetNumGuildMembers and GetNumGuildMembers()or 0)do
        local name,_,rankIndex,_,_,_,_,_,online=GetGuildRosterInfo(i)
        local short=ns.ShortName(name)
        if online and short and short~=me and(tonumber(rankIndex)or 99)<=maxRank and count<39 then if invite(name)then count=count+1 end end
    end
    return count
end
---------------------------------------------------------------------------
-- Default arrangement: tanks, melee, ranged, then healers, five to a group.
local melee={WARRIOR=true,ROGUE=true,DEATHKNIGHT=true,DEMONHUNTER=true,MONK=true,PALADIN=true}
local function plan()
    local members={}
    for i=1,40 do local name,_,subgroup,_,_,class,_,online=GetRaidRosterInfo(i)
        if name then local role=UnitGroupRolesAssigned and UnitGroupRolesAssigned("raid"..i)or"NONE"
            local order=role=="TANK"and 1 or role=="HEALER"and 4 or melee[class]and 2 or 3
            members[#members+1]={index=i,name=name,subgroup=subgroup,order=order}
        end
    end
    table.sort(members,function(a,b)if a.order~=b.order then return a.order<b.order end;return a.name<b.name end)
    for i,m in ipairs(members)do m.target=math.floor((i-1)/5)+1 end
    return members
end
local arranging
local function step()
    local members=plan();local counts={}
    for _,m in ipairs(members)do counts[m.subgroup]=(counts[m.subgroup]or 0)+1 end
    for _,m in ipairs(members)do if m.subgroup~=m.target then
        if(counts[m.target]or 0)<5 then pcall(SetRaidSubgroup,m.index,m.target);return true end
        for _,o in ipairs(members)do if o.subgroup==m.target and o.target~=m.target then pcall(SwapRaidSubgroup,m.index,o.index);return true end end
    end end
    return false
end
function ns.ArrangeGroups()
    if not(IsInRaid and IsInRaid())then return nil,"Arranging works in a raid group"end
    if not lead()then return nil,"Needs raid leader or assistant"end
    if InCombatLockdown and InCombatLockdown()then return nil,"Arrange groups after combat"end
    if arranging then arranging:Cancel()end
    local steps=0
    if C_Timer and C_Timer.NewTicker then arranging=C_Timer.NewTicker(0.3,function(self)steps=steps+1;if not step()or steps>80 then self:Cancel();arranging=nil end end)else while step()and steps<80 do steps=steps+1 end end
    return true
end
---------------------------------------------------------------------------
-- Assistants: names (or nicknames) from the list get assist when you lead the raid.
function ns.PromoteAssistants()
    if not(IsInRaid and IsInRaid()and UnitIsGroupLeader and UnitIsGroupLeader("player"))then return nil,"Only the raid leader can promote"end
    local wanted={};for word in(tostring(Cfg().promote or"")..","):gmatch("([^,]*),")do word=word:match("^%s*(.-)%s*$"):lower();if word~=""then wanted[word]=true end end
    local count=0
    for i=1,40 do local name,rank=GetRaidRosterInfo(i)
        local short=ns.ShortName(name);local nick=short and ns.Nickname and ns.Nickname(short)
        if short and rank==0 and(wanted[short:lower()]or(nick and wanted[nick:lower()]))then if PromoteToAssistant then pcall(PromoteToAssistant,"raid"..i);count=count+1 end end
    end
    return count
end
local events=CreateFrame("Frame")
for _,e in ipairs({"CHAT_MSG_WHISPER","GROUP_ROSTER_UPDATE"})do events:RegisterEvent(e)end
events:SetScript("OnEvent",function(_,event,text,sender)
    local cfg=Cfg()
    if event=="CHAT_MSG_WHISPER"then
        if cfg.autoInvite and type(text)=="string"and keywords()[text:match("^%s*(.-)%s*$"):lower()]and(not cfg.guildOnly or guildMember(sender))then invite(sender)end
    elseif event=="GROUP_ROSTER_UPDATE"and cfg.autoPromote then ns.PromoteAssistants()end
end)
---------------------------------------------------------------------------
local function DrawRaidTools(parent)
    local state=kit.state;local cfg=Cfg();local d=state.drafts
    d.rt=d.rt or{breakMin="5",keywords=cfg.keywords or"",promote=cfg.promote or"",pull="10"};local f=d.rt
    kit.header(parent,L("Raid tools"),L("Timers, invites, groups and assistants. Most need leader or assist."))
    local a=W.Card(parent,0,56,298,536,L("Pull and break"))
    W.Button(a,L("Ready check"),12,34,274,function()if DoReadyCheck then DoReadyCheck()end;kit.notify(L("Ready check started"))end,false,"rt-ready",{glyph="check"})
    W.Field(a,L("PULL TIMER (SECONDS)"),f.pull,12,74,130,"rt:pull")
    W.Button(a,L("Start pull"),150,90,136,function()local s=tonumber(ns.UIControls["rt:pull"]:GetText());if not s or s<1 or s>60 then kit.notify(L("Enter 1 to 60 seconds"),true)return end;if C_PartyInfo and C_PartyInfo.DoCountdown then C_PartyInfo.DoCountdown(s)end;kit.notify(L("Pull timer started"))end,false,"rt-pull",{glyph="play"})
    W.Button(a,L("Cancel pull"),12,128,274,function()if C_PartyInfo and C_PartyInfo.DoCountdown then C_PartyInfo.DoCountdown(0)end;kit.notify(L("Pull timer cancelled"))end,false,"rt-pull-cancel",{kind="outline"})
    W.Heading(a,L("Break"),12,176,274)
    W.Field(a,L("MINUTES"),f.breakMin,12,198,130,"rt:breakMin")
    W.Button(a,L("Start break"),150,214,136,function()local ok,err=ns.StartBreak(ns.UIControls["rt:breakMin"]:GetText());kit.done(ok,err,L("Break started"))end,false,"rt-break",{glyph="clock"})
    W.Button(a,L("End break"),12,252,274,function()kit.done(ns.StartBreak(0),nil,L("Break ended"))end,false,"rt-break-cancel",{kind="outline"})
    W.Toggle(a,L("Announce the break in group chat"),cfg.breakAnnounce,12,292,274,function(v)cfg.breakAnnounce=v end,"rt-break-announce")
    local left=ns.BreakRemaining();W.Label(a,left and(L("Break running")..": "..math.floor(left/60).." min")or L("No break running. /ndp break 10 starts one."),12,326,274,11,C.muted)
    local b=W.Card(parent,310,56,298,536,L("Invites"))
    W.Toggle(b,L("Invite on whisper keyword"),cfg.autoInvite,12,34,274,function(v)cfg.autoInvite=v end,"rt-autoinv")
    W.Field(b,L("KEYWORDS, COMMA SEPARATED"),f.keywords,12,66,274,"rt:keywords")
    W.Button(b,L("Save keywords"),12,118,274,function()cfg.keywords=ns.UIControls["rt:keywords"]:GetText();kit.done(true,nil,L("Keywords saved"))end,false,"rt-keywords-save",{align="CENTER"})
    W.Toggle(b,L("Guild members only"),cfg.guildOnly,12,156,274,function(v)cfg.guildOnly=v end,"rt-guildonly")
    local ranks={};for i=0,9 do ranks[#ranks+1]={value=i,label=L("Up to rank").." "..(i+1)..(i==0 and" ("..L("guild master")..")"or"")}end
    W.Select(b,L("GUILD INVITE RANK"),ranks,tonumber(cfg.rank)or 1,12,190,274,function(v)cfg.rank=v;kit.refresh()end,"rt-rank")
    W.Button(b,L("Invite guild members now"),12,248,274,function()local n,err=ns.InviteGuild();kit.done(n,err,(tonumber(n)or 0)..L(" invites sent"))end,false,"rt-inv-guild",{glyph="players"})
    W.Label(b,L("/ndp inv invites the guild from chat."),12,290,274,11,C.muted)
    local c=W.Card(parent,620,56,300,536,L("Group"))
    W.Button(c,L("Arrange groups"),12,34,276,function()local ok,err=ns.ArrangeGroups();kit.done(ok,err,L("Arranging: tanks, melee, ranged, healers"))end,false,"rt-arrange",{glyph="list"})
    W.Label(c,L("Tanks, then melee, ranged and healers, five per group. Melee is guessed from class and role."),12,72,276,11,C.muted)
    W.Heading(c,L("Assistants"),12,118,276)
    W.Field(c,L("NAMES OR NICKNAMES, COMMA SEPARATED"),f.promote,12,140,276,"rt:promote")
    W.Button(c,L("Save names"),12,192,276,function()cfg.promote=ns.UIControls["rt:promote"]:GetText();kit.done(true,nil,L("Assistant list saved"))end,false,"rt-promote-save",{align="CENTER"})
    W.Toggle(c,L("Promote them automatically"),cfg.autoPromote,12,230,276,function(v)cfg.autoPromote=v end,"rt-autopromote")
    W.Button(c,L("Promote now"),12,262,276,function()local n,err=ns.PromoteAssistants();kit.done(n,err,(tonumber(n)or 0)..L(" players promoted"))end,false,"rt-promote",{glyph="up"})
end
ns.ExtraPages.raidtools=DrawRaidTools
