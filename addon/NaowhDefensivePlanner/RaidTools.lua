-- Raid tools: ready check, pull and break timers, invites, group arrangement and assistants.
-- Everything here uses the game's own group API and needs leader or assistant where the game asks for it.
local _,ns=...
local W=ns.Widgets
local C=W.colors
local L=ns.L
local kit=ns.UIKit

local function Cfg()
    local store=ns.Store();store.raidtools=store.raidtools or{keywords="inv, invite",rank=1,breakAnnounce=true,promote=""}
    local c=store.raidtools;if c.breakShow==nil then c.breakShow=true end;if c.breakSound==nil then c.breakSound=true end;c.breakPos=c.breakPos or{x=0,y=-160};c.officerRank=c.officerRank or 1
    return c
end
ns.RaidToolsConfig=Cfg
local function channel()return IsInRaid and IsInRaid()and"RAID"or IsInGroup and IsInGroup()and"PARTY"or nil end
local function lead()return ns.GroupAuthority(UnitName("player"))or not channel()end
---------------------------------------------------------------------------
-- Break timer: a small plain bar of text, updated once a second. It can be hidden, moved,
-- print the time left in chat each minute and play a sound when the break ends.
local bar,ticker,breakEnds,lastPrinted
local function Bar()
    if bar then return bar end
    local cfg=Cfg()
    bar=CreateFrame("Frame",nil,UIParent);bar:SetSize(240,34);bar:SetPoint("TOP",UIParent,"TOP",tonumber(cfg.breakPos.x)or 0,tonumber(cfg.breakPos.y)or-160);bar:SetFrameStrata("HIGH")
    bar:SetMovable(true);bar:SetClampedToScreen(true);bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart",function(self)if Cfg().breakUnlocked then self:StartMoving()end end)
    bar:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing()
        local x,top=self:GetCenter(),self:GetTop();local ux,uy=UIParent:GetCenter(),UIParent:GetTop()
        if type(x)=="number"and type(ux)=="number"and type(top)=="number"and type(uy)=="number"then Cfg().breakPos={x=math.floor(x-ux+0.5),y=math.floor(top-uy+0.5)}end
    end)
    bar.bg=bar:CreateTexture(nil,"BACKGROUND");bar.bg:SetAllPoints();bar.bg:SetColorTexture(0.04,0.055,0.08,0.8)
    bar.text=bar:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");bar.text:SetPoint("CENTER");bar.text:SetTextColor(1,1,1,1)
    return bar
end
local function stopBreak()if ticker then ticker:Cancel();ticker=nil end;breakEnds=nil;lastPrinted=nil;if bar and not Cfg().breakUnlocked then bar:Hide()end end
local function showBreak()
    local cfg=Cfg();Bar()
    local left=math.max(0,math.floor((breakEnds or 0)-GetTime()))
    bar.text:SetText(string.format("%s %d:%02d",L("Break"),math.floor(left/60),left%60))
    if cfg.breakShow or cfg.breakUnlocked then bar:Show()else bar:Hide()end
    local minutes=math.ceil(left/60)
    if cfg.breakPrint and left>0 and left%60==0 and minutes~=lastPrinted then lastPrinted=minutes;ns.Print(string.format(L("Break: %d min left"),minutes))end
    if left<=0 then stopBreak();ns.Print(L("Break is over."));if cfg.breakSound and PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then pcall(PlaySound,SOUNDKIT.RAID_WARNING,"Master")end end
end
-- Unlocked, the bar stays on screen with a sample time so it can be dragged.
function ns.UnlockBreakBar(on)
    local cfg=Cfg();cfg.breakUnlocked=on==true;Bar()
    bar:EnableMouse(cfg.breakUnlocked)
    if cfg.breakUnlocked then if not breakEnds then bar.text:SetText(L("Break").." 5:00")end;bar:Show()elseif not breakEnds then bar:Hide()end
    return cfg.breakUnlocked
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
ns.CommHandlers.BREAK=function(minutes,sender,_,full)if ns.GroupAuthority(full or sender)then ns.StartBreak(minutes,true)end end
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
-- Invite and arrange from the note (NSRT): "Group 1: Name Name" (or "G1:") lines put players in
-- a raid group, an "Invite: Name Name" line lists extra players. Nicknames are resolved through
-- the shared nickname list.
local function character(name)
    local want=name:lower()
    for char,nick in pairs(ns.PlayersData and ns.PlayersData().nicknames or{})do if type(nick)=="string"and nick:lower()==want then return char end end
    return name
end
function ns.NoteGroups()
    local out={}
    for g=1,8 do
        local names=ns.NoteList("Group "..g);if #names==0 then names=ns.NoteList("G"..g)end
        for _,name in ipairs(names)do out[(ns.ShortName(character(name))or name):lower()]=g end
    end
    return out
end
function ns.NoteInvites()
    local seen,out={},{}
    local function add(name)local c=character(name);local key=c:lower();if not seen[key]then seen[key]=true;out[#out+1]=c end end
    for _,name in ipairs(ns.NoteList("Invite"))do add(name)end
    for g=1,8 do local names=ns.NoteList("Group "..g);if #names==0 then names=ns.NoteList("G"..g)end;for _,name in ipairs(names)do add(name)end end
    return out
end
local function inGroup(name)
    if UnitInRaid and UnitInRaid(name)then return true end
    if UnitInParty and UnitInParty(name)then return true end
    return ns.IsMe(name)
end
function ns.InviteFromNote()
    local list=ns.NoteInvites()
    if #list==0 then return nil,"No names in the note (Invite: Name Name, or Group 1: ...)"end
    local count=0
    for _,name in ipairs(list)do if not inGroup(name)and count<39 then if invite(name)then count=count+1 end end end
    return count
end
---------------------------------------------------------------------------
-- Group sorting. Default: tanks, melee, ranged, then healers, five to a group.
-- Split: two halves with the same mix of roles (groups 1-2-.. and the next ones).
-- Evens/odds: the same two halves, one in odd groups and one in even groups.
local melee={WARRIOR=true,ROGUE=true,DEATHKNIGHT=true,DEMONHUNTER=true,MONK=true,PALADIN=true}
local sortMode="default"
local function plan()
    local members={}
    for i=1,40 do local name,_,subgroup,_,_,class,_,online=GetRaidRosterInfo(i)
        if name then local role=UnitGroupRolesAssigned and UnitGroupRolesAssigned("raid"..i)or"NONE"
            local order=role=="TANK"and 1 or role=="HEALER"and 4 or melee[class]and 2 or 3
            members[#members+1]={index=i,name=name,subgroup=subgroup,order=order}
        end
    end
    table.sort(members,function(a,b)if a.order~=b.order then return a.order<b.order end;return a.name<b.name end)
    if sortMode=="default"then for i,m in ipairs(members)do m.target=math.floor((i-1)/5)+1 end;return members end
    -- From the note: listed players go to their group; the rest stay where they are.
    if sortMode=="note"then
        local wanted=ns.NoteGroups()
        for _,m in ipairs(members)do m.target=wanted[(ns.ShortName(m.name)or m.name):lower()]or m.subgroup end
        return members
    end
    -- Alternate down the role order so both halves get the same roles.
    local halves={{},{}};for i,m in ipairs(members)do local h=halves[(i-1)%2+1];h[#h+1]=m end
    local perHalf=math.ceil(#halves[1]/5)
    for h,list in ipairs(halves)do for i,m in ipairs(list)do local n=math.floor((i-1)/5)
        if sortMode=="evenodd"then m.target=h==1 and(2*n+1)or(2*n+2)else m.target=(h-1)*perHalf+n+1 end
        m.target=math.min(8,m.target)
    end end
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
function ns.ArrangeGroups(mode)
    if mode~=nil and mode~="default"and mode~="split"and mode~="evenodd"and mode~="note"then return nil,"Unknown sorting"end
    if mode=="note"and not next(ns.NoteGroups())then return nil,"No group lines in the note (Group 1: Name Name ...)"end
    if not(IsInRaid and IsInRaid())then return nil,"Arranging works in a raid group"end
    if not lead()then return nil,"Needs raid leader or assistant"end
    if InCombatLockdown and InCombatLockdown()then return nil,"Arrange groups after combat"end
    if arranging then arranging:Cancel()end
    sortMode=mode or"default"
    local steps=0
    if C_Timer and C_Timer.NewTicker then arranging=C_Timer.NewTicker(0.3,function(self)steps=steps+1;if not step()or steps>80 then self:Cancel();arranging=nil end end)else while step()and steps<80 do steps=steps+1 end end
    return true
end
function ns.AbortSorting()
    if not arranging then return nil,"No sorting is running"end
    arranging:Cancel();arranging=nil;return true
end
---------------------------------------------------------------------------
-- Assistants: names (or nicknames) from the list get assist when you lead the raid.
-- Guild members up to the officer rank (0 is the guild master).
local function officer(name)
    if not(IsInGuild and IsInGuild()and GetNumGuildMembers and GetGuildRosterInfo)then return false end
    local max=tonumber(Cfg().officerRank)or 1
    for i=1,GetNumGuildMembers()do local full,_,rank=GetGuildRosterInfo(i);if ns.ShortName(full)==name then return(tonumber(rank)or 99)<=max end end
    return false
end
function ns.PromoteAssistants()
    if not(IsInRaid and IsInRaid()and UnitIsGroupLeader and UnitIsGroupLeader("player"))then return nil,"Only the raid leader can promote"end
    local cfg=Cfg()
    if cfg.everyoneAssist and SetEveryoneIsAssistant then pcall(SetEveryoneIsAssistant,true);return 0 end
    local wanted={};for word in(tostring(Cfg().promote or"")..","):gmatch("([^,]*),")do word=word:match("^%s*(.-)%s*$"):lower();if word~=""then wanted[word]=true end end
    local count=0
    for i=1,40 do local name,rank=GetRaidRosterInfo(i)
        local short=ns.ShortName(name);local nick=short and ns.Nickname and ns.Nickname(short)
        if short and rank==0 and(wanted[short:lower()]or(nick and wanted[nick:lower()])or(cfg.promoteOfficers and officer(short)))then if PromoteToAssistant then pcall(PromoteToAssistant,"raid"..i);count=count+1 end end
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
    W.Toggle(a,L("Show the break bar"),cfg.breakShow,12,322,274,function(v)cfg.breakShow=v end,"rt-break-show")
    W.Toggle(a,L("Sound when the break ends"),cfg.breakSound,12,352,274,function(v)cfg.breakSound=v end,"rt-break-sound")
    W.Toggle(a,L("Print time left each minute"),cfg.breakPrint,12,382,274,function(v)cfg.breakPrint=v end,"rt-break-print")
    W.Button(a,cfg.breakUnlocked and L("Lock break bar")or L("Unlock and preview bar"),12,418,274,function()ns.UnlockBreakBar(not cfg.breakUnlocked);kit.refresh()end,false,"rt-break-unlock",{kind="outline",align="CENTER"})
    local left=ns.BreakRemaining();W.Label(a,left and(L("Break running")..": "..math.floor(left/60).." min")or L("No break running. /ndp break 10 starts one."),12,462,274,11,C.muted)
    local b=W.Card(parent,310,56,298,536,L("Invites"))
    W.Toggle(b,L("Invite on whisper keyword"),cfg.autoInvite,12,34,274,function(v)cfg.autoInvite=v end,"rt-autoinv")
    W.Field(b,L("KEYWORDS, COMMA SEPARATED"),f.keywords,12,66,274,"rt:keywords")
    W.Button(b,L("Save keywords"),12,118,274,function()cfg.keywords=ns.UIControls["rt:keywords"]:GetText();kit.done(true,nil,L("Keywords saved"))end,false,"rt-keywords-save",{align="CENTER"})
    W.Toggle(b,L("Guild members only"),cfg.guildOnly,12,156,274,function(v)cfg.guildOnly=v end,"rt-guildonly")
    local ranks={};for i=0,9 do ranks[#ranks+1]={value=i,label=L("Up to rank").." "..(i+1)..(i==0 and" ("..L("guild master")..")"or"")}end
    W.Select(b,L("GUILD INVITE RANK"),ranks,tonumber(cfg.rank)or 1,12,190,274,function(v)cfg.rank=v;kit.refresh()end,"rt-rank")
    W.Button(b,L("Invite guild members now"),12,248,274,function()local n,err=ns.InviteGuild();kit.done(n,err,(tonumber(n)or 0)..L(" invites sent"))end,false,"rt-inv-guild",{glyph="players"})
    W.Label(b,L("/ndp inv invites the guild from chat."),12,290,274,11,C.muted)
    W.Heading(b,L("From the note"),12,322,274)
    W.Button(b,L("Invite from note"),12,344,274,function()local n,err=ns.InviteFromNote();kit.done(n,err,(tonumber(n)or 0)..L(" invites sent"))end,false,"rt-inv-note",{glyph="notes"})
    W.Button(b,L("Arrange from note"),12,380,274,function()local ok,err=ns.ArrangeGroups("note");kit.done(ok,err,L("Arranging from the note"))end,false,"rt-arrange-note",{glyph="list"})
    W.Label(b,L("The shared note lists players as \"Group 1: Name Name\" (or G1:) and extras as \"Invite: Name\". Nicknames work. /ndp invite and /ndp arrange note do the same."),12,420,274,11,C.muted)
    local c=W.Card(parent,620,56,300,536,L("Group"))
    W.Button(c,L("Default arrangement"),12,34,276,function()local ok,err=ns.ArrangeGroups("default");kit.done(ok,err,L("Arranging: tanks, melee, ranged, healers"))end,false,"rt-arrange",{glyph="list"})
    W.Button(c,L("Split groups"),12,70,134,function()local ok,err=ns.ArrangeGroups("split");kit.done(ok,err,L("Splitting into two even halves"))end,false,"rt-split",{align="CENTER"})
    W.Button(c,L("Split evens/odds"),154,70,134,function()local ok,err=ns.ArrangeGroups("evenodd");kit.done(ok,err,L("Splitting into odd and even groups"))end,false,"rt-evenodd",{align="CENTER"})
    W.Button(c,L("Abort sorting"),12,106,276,function()kit.done(ns.AbortSorting())end,false,"rt-abort",{kind="outline",align="CENTER"})
    W.Label(c,L("Split halves get the same mix of roles. Melee is guessed from class."),12,142,276,11,C.muted)
    W.Heading(c,L("Assistants"),12,184,276)
    W.Field(c,L("NAMES OR NICKNAMES, COMMA SEPARATED"),f.promote,12,206,276,"rt:promote")
    W.Button(c,L("Save names"),12,258,276,function()cfg.promote=ns.UIControls["rt:promote"]:GetText();kit.done(true,nil,L("Assistant list saved"))end,false,"rt-promote-save",{align="CENTER"})
    W.Toggle(c,L("Promote guild officers"),cfg.promoteOfficers,12,294,276,function(v)cfg.promoteOfficers=v end,"rt-officers")
    local officerRanks={};for i=0,9 do officerRanks[#officerRanks+1]={value=i,label=L("Officer rank: up to").." "..(i+1)}end
    W.Select(c,nil,officerRanks,tonumber(cfg.officerRank)or 1,12,326,276,function(v)cfg.officerRank=v;kit.refresh()end,"rt-officer-rank")
    W.Toggle(c,L("Always promote everyone"),cfg.everyoneAssist,12,366,276,function(v)cfg.everyoneAssist=v end,"rt-everyone")
    W.Toggle(c,L("Promote automatically"),cfg.autoPromote,12,396,276,function(v)cfg.autoPromote=v end,"rt-autopromote")
    W.Button(c,L("Promote now"),12,430,276,function()local n,err=ns.PromoteAssistants();kit.done(n,err,(tonumber(n)or 0)..L(" players promoted"))end,false,"rt-promote",{glyph="up"})
end
ns.ExtraPages.raidtools=DrawRaidTools
