-- Shared and personal notes: a library per client, one active note of each kind on screen,
-- the shared one sent to the group by its leader or an assistant. Assignments are the note lines
-- that name you (or your nickname); they can pop up when the pull starts.
local _,ns=...
local W=ns.Widgets
local C=W.colors
local L=ns.L
local kit=ns.UIKit

function ns.Notes()
    local store=ns.Store();store.notes=store.notes or{}
    local n=store.notes;n.shared=n.shared or{};n.personal=n.personal or{}
    n.cfg=n.cfg or{show=false,unlocked=false,outside=false,assignOnPull=true,fontSize=13}
    return n
end
local function clean(text)return tostring(text or""):gsub("\r",""):sub(1,20000)end
function ns.SaveNote(kind,id,form)
    assert(kind=="shared"or kind=="personal","Choose shared or personal")
    local name=tostring(form.name or""):match("^%s*(.-)%s*$");if name==""then return nil,"Enter a note name"end
    if #name>80 then return nil,"Use a name of at most 80 characters"end
    local n=ns.Notes();id=id or ns.UID("note")
    n[kind][id]={name=name,text=clean(form.text),encounter=tonumber(form.boss)or 0,difficulty=tonumber(form.diff)or 0}
    if kind=="shared"and n.live and n.live.id==id then n.live.text=n[kind][id].text;n.live.name=name end
    ns.RefreshNoteDisplay();return id
end
function ns.DeleteNote(kind,id)
    local n=ns.Notes();if not n[kind]or not n[kind][id]then return nil,"Note not found"end
    n[kind][id]=nil;if kind=="personal"and n.activePersonal==id then n.activePersonal=nil end
    if kind=="shared"and n.live and n.live.id==id then n.live=nil end
    ns.RefreshNoteDisplay();return true
end
-- Makes a note the active one; a shared note can also be sent to the group.
function ns.LoadNote(kind,id,send)
    local n=ns.Notes();local note=n[kind]and n[kind][id];if not note then return nil,"Save the note first"end
    if kind=="personal"then n.activePersonal=id;ns.RefreshNoteDisplay();return true end
    if send and ns.GroupChannel()and not ns.GroupAuthority(UnitName("player"))then return nil,"Only the group leader or an assistant can send the shared note"end
    n.live={id=id,name=note.name,text=note.text,from=UnitName and UnitName("player")or"you",time=time and time()or 0}
    if send then if not ns.Send("NOTE",note.name.."\n"..note.text)then ns.RefreshNoteDisplay();return true,"Loaded. Not in a group, so nothing was sent"end end
    ns.RefreshNoteDisplay();return true
end
function ns.UnloadNote(kind,send)
    local n=ns.Notes()
    if kind=="personal"then n.activePersonal=nil else
        n.live=nil
        if send and ns.GroupChannel()then if not ns.GroupAuthority(UnitName("player"))then return nil,"Only the group leader or an assistant can clear the group's note"end;ns.Send("NOTECLR","")end
    end
    ns.RefreshNoteDisplay();return true
end
ns.CommHandlers.NOTE=function(payload,sender)
    if not ns.GroupAuthority(sender)then return end
    local name,text=payload:match("^([^\n]*)\n?(.*)$")
    ns.Notes().live={name=name~=""and name or L("Shared note"),text=clean(text),from=sender,time=time and time()or 0,received=true}
    ns.RefreshNoteDisplay();ns.Print(L("Shared note received from ")..sender..": "..(name or""))
    if ns.RefreshWorkspace then ns.RefreshWorkspace()end
end
ns.CommHandlers.NOTECLR=function(_,sender)
    if not ns.GroupAuthority(sender)then return end
    ns.Notes().live=nil;ns.RefreshNoteDisplay();if ns.RefreshWorkspace then ns.RefreshWorkspace()end
end
-- Sharing a boss plan: the leader or an assistant sends the reminders of one boss and difficulty;
-- group members store them in their active profile, replacing what that sender sent before.
local function Pack(value)local ld=LibStub("LibDeflate");return ld:EncodeForPrint(ld:CompressDeflate(LibStub("LibSerialize"):Serialize(value)))end
local function Unpack(text)
    local ld=LibStub("LibDeflate");local raw=ld:DecompressDeflate(ld:DecodeForPrint(text)or"")
    if not raw or #raw>400000 then return nil end
    local ok,value=LibStub("LibSerialize"):Deserialize(raw);return ok and type(value)=="table"and value or nil
end
local function SharedEntries(encounter,difficulty)
    local out,count={},0
    for key,e in pairs(ns.Get(ns.Active().data.raidReminders,encounter)or{})do
        if type(e)=="table"and not e.defensive and(not e.difficulties or ns.Get(e.difficulties,difficulty))and not tostring(key):match("^recv:")then
            local c=ns.Clone(e);c.pztkMigration=nil;c.sharedFrom=nil;out[tostring(key)]=c;count=count+1
        end
    end
    return out,count
end
function ns.SendReminders(encounter,difficulty)
    if not ns.Active()then return nil,"Create or import a profile first"end
    if not ns.GroupChannel()then return nil,"Join a group to send reminders"end
    if not ns.GroupAuthority(UnitName("player"))then return nil,"Only the group leader or an assistant can send reminders"end
    local entries,count=SharedEntries(encounter,difficulty)
    if count==0 then return nil,"No reminders for this boss and difficulty to send"end
    ns.Send("REMS",Pack({enc=encounter,diff=difficulty,r=entries}))
    return count
end
function ns.ReceiveReminders(payload,sender)
    local p=Unpack(payload);local enc,diff=p and tonumber(p.enc),p and tonumber(p.diff)
    if not(enc and diff and type(p.r)=="table")then return nil,"Unreadable reminders"end
    local who=ns.ShortName(sender)or"?"
    local count=0
    local ok,err=ns.EditProfile(function(data)
        data.raidReminders=data.raidReminders or{};local list=data.raidReminders[enc]or{};data.raidReminders[enc]=list
        local prefix="recv:"..who..":"..diff..":"
        for key in pairs(list)do if tostring(key):sub(1,#prefix)==prefix then list[key]=nil end end
        for key,e in pairs(p.r)do if type(e)=="table"and count<300 then e.sharedFrom=who;e.difficulties={[diff]=true};list[prefix..tostring(key)]=e;count=count+1 end end
    end)
    if not ok then return nil,err end
    return count
end
ns.CommHandlers.REMS=function(payload,sender)
    if not ns.GroupAuthority(sender)or ns.Notes().cfg.acceptReminders==false then return end
    if ns.ShortName(sender)==ns.ShortName(UnitName("player"))then return end
    local n,err=ns.ReceiveReminders(payload,sender)
    ns.Print(n and(n.." "..L("reminders received from ")..sender)or(L("Reminders from ")..sender..L(" were not stored: ")..tostring(err)))
    if n and ns.RefreshWorkspace then ns.RefreshWorkspace()end
end
-- Lines of the active notes that name this character or its nickname.
function ns.MyNoteLines()
    local n=ns.Notes();local names={}
    local me=UnitName and UnitName("player");if type(me)=="string"then names[#names+1]=me:lower()end
    local nick=ns.MyNickname and ns.MyNickname();if nick and nick~=""then names[#names+1]=nick:lower()end
    local out={}
    local function scan(text)for line in(tostring(text or"").."\n"):gmatch("(.-)\n")do
        local plain=line:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):lower()
        for _,who in ipairs(names)do if plain:find(who,1,true)then out[#out+1]=line;break end end
    end end
    if n.live then scan(n.live.text)end
    local personal=n.activePersonal and n.personal[n.activePersonal];if personal then scan(personal.text)end
    return out
end
-- Note timers, in the line format raid notes commonly use for timeline reminders:
--   {time:1:30} Ability - Name {spell:12345}  {everyone} {text}Move{/text}@Glow1,Glow2
--   {time:0:20,p2} ...            seconds into phase 2 (p1 is the pull)
--   {time:0:05,SCS:12345:2} ...   seconds after the 2nd cast of spell 12345 (from the boss mod message)
-- Two spaces separate the reminders of a line. Who: a name or nickname, {everyone}, class:MAGE,
-- spec:MAGE:2, role:HEALER, group:3 or type:melee / type:ranged. The time is when it happens; the
-- reminder shows for the note timer duration before it.
local spellEvents={SCC=true,SCS=true,SAA=true,SAR=true}
local function NoteTarget(load,me,nick)
    load=load:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):match("^%s*(.-)%s*$")
    if load==""or load:lower()=="{everyone}"then return{all=true}end
    local kind,value=load:match("^(%a+):(.+)$")
    if kind then
        kind=kind:lower();value=value:upper()
        if kind=="class"then return{classes={[value]=true}}end
        if kind=="spec"then local class,index=value:match("^(%a+):(%d)$");local list=class and ns.ClassSpecs[class];local id=list and list[tonumber(index)];if id then return{specs={[id]=true}}end;return nil end
        if kind=="role"then if({TANK=true,HEALER=true,DAMAGER=true})[value]then return{roles={[value]=true}}end;return nil end
        if kind=="group"then local g=tonumber(value);if g then return{subgroups={[g]=true}}end;return nil end
        if kind=="type"then local melee=value=="MELEE";local specs={};for _,list in pairs(ns.ClassSpecs)do for _,id in ipairs(list)do if(ns.MeleeSpecs[id]~=nil)==melee then specs[id]=true end end end;return{specs=specs,matchAny=true}end
        return nil
    end
    -- A name: only reminders for this character (or its nickname) are kept.
    local who=load:lower()
    if who==me or(nick and who==nick)then return{all=true}end
end
function ns.ParseNoteTimers(text,me,nick,duration)
    local out,count={},0;duration=tonumber(duration)or 6
    for line in(tostring(text or"").."\n"):gmatch("(.-)\n")do
        local trig,rest=line:match("^%s*{(time:[^}]+)}(.*)$")
        if trig then
            local m,sec,extra=trig:match("^time:(%d+):(%d+%.?%d*)(.*)$")
            local t=m and tonumber(m)*60+tonumber(sec)
            local trigger
            if t and t>0 then
                local phase=extra:match("^,p(%d+)$")
                local event,spell,count=extra:match("^,(%u+):(%d+):?(%d*)$")
                if extra==""or phase=="1"then trigger={type="pull",delay=t,leadTime=math.min(duration,t)}
                elseif phase then trigger={type="stage",stage=tonumber(phase),delay=t,leadTime=math.min(duration,t)}
                elseif event and spellEvents[event]then trigger={type="bwmsg",spellID=tonumber(spell),delay=math.max(0,t-duration),counterGroups=tonumber(count)and{{{op="=",value=tonumber(count)}}}or nil}end
            end
            if trigger then
                rest=rest:match("^.-%s%-%s(.+)$")or rest
                for chunk in(rest.."  "):gmatch("(.-)%s%s+")do
                    local load,shown,after=chunk:match("^(.-)%s*({.+})(.*)$")
                    if not load then load,shown,after="",chunk,""end
                    -- Glow names follow an @, after the display or inside the recipient part.
                    local glow=after:match("@(.+)$")
                    if load:find("@")then load,glow=load:match("^(.-)@(.*)$")end
                    local target=NoteTarget(load,me,nick)
                    local textValue=shown:match("{[Tt][Ee][Xx][Tt]}(.-){/[Tt][Ee][Xx][Tt]}")
                    local spell=tonumber(shown:match("{spell:(%d+)}"))
                    if target and(spell or(textValue and textValue~=""))then
                        local display={type=spell and"icon"or"text",spellID=spell,text=textValue or"",dur=math.min(duration,t),tts=true}
                        if glow then local names={};for name in glow:gmatch("[^,%s]+")do if #names<40 then names[#names+1]=name end end;display.glowTargets=names[1]and names or nil end
                        count=count+1;out["note:"..count]={name="Note timer",trigger=trigger,target=target,display=display}
                    end
                end
            end
        end
    end
    return out
end
-- Timers for this pull from the shared note and the active personal note.
-- Names on a note line "Tag: name name name" (shared note first, then personal), in order.
-- Rotations and note slots pick from it, so a raid leader reorders players in the note only.
function ns.NoteList(tag)
    if type(tag)~="string"or tag==""then return{}end
    local n=ns.Notes();local personal=n.activePersonal and n.personal[n.activePersonal]
    local want=tag:lower()
    for _,text in ipairs({n.live and n.live.text or"",personal and personal.text or""})do
        for line in (text.."\n"):gmatch("(.-)\n")do
            local head,rest=line:match("^%s*(.-)%s*:%s*(.*)$")
            if head and head:lower()==want then
                local out={};rest=rest:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("{.-}"," ")
                for name in rest:gmatch("[^%s,;]+")do out[#out+1]=name end
                return out
            end
        end
    end
    return{}
end
-- True when a name from a note or list is you: character name, name-realm or your nickname.
function ns.IsMe(name)
    if type(name)~="string"or name==""then return false end
    local want=name:lower()
    local me=UnitName and UnitName("player");if type(me)=="string"and(me:lower()==want or want:match("^"..me:lower():gsub("%p","%%%0").."%-"))then return true end
    local nick=ns.MyNickname and ns.MyNickname();if type(nick)=="string"and nick~=""and nick:lower()==want then return true end
    return false
end
function ns.NoteTimerEntries()
    local n=ns.Notes();if n.cfg.timers==false then return{}end
    local me=UnitName and UnitName("player");me=type(me)=="string"and me:lower()or""
    local nick=ns.MyNickname and ns.MyNickname();nick=type(nick)=="string"and nick~=""and nick:lower()or nil
    local all={}
    local personal=n.activePersonal and n.personal[n.activePersonal]
    for i,text in ipairs({n.live and n.live.text or"",personal and personal.text or""})do
        for k,v in pairs(ns.ParseNoteTimers(text,me,nick,n.cfg.timerDuration))do all[i..k]=v end
    end
    return all
end
function ns.ShowAssignment()
    local lines=ns.MyNoteLines()
    if #lines>0 and ns.Display then ns.Display({type="text",text=table.concat(lines,"\n",1,math.min(4,#lines)),dur=8,tts=false})end
    return #lines
end
---------------------------------------------------------------------------
-- On-screen note: one plain panel with the active shared and personal note. No animation.
local frame
function ns.RefreshNoteDisplay()
    local n=ns.Notes();local cfg=n.cfg
    local inside=ns.instanceType=="raid"or ns.instanceType=="party"
    local parts={}
    if n.live then parts[#parts+1]="|cff33c3a6"..n.live.name.."|r\n"..n.live.text end
    local personal=n.activePersonal and n.personal[n.activePersonal];if personal then parts[#parts+1]="|cfff2b84b"..personal.name.."|r\n"..personal.text end
    local wanted=cfg.unlocked or(cfg.show and #parts>0 and(inside or cfg.outside))
    if not wanted then if frame then frame:Hide()end;return false end
    if not frame then
        frame=CreateFrame("Frame",nil,UIParent);frame:SetFrameStrata("MEDIUM");frame:SetClampedToScreen(true);frame:SetMovable(true)
        frame.bg=frame:CreateTexture(nil,"BACKGROUND");frame.bg:SetAllPoints();frame.bg:SetColorTexture(0.04,0.055,0.08,0.72)
        frame.text=frame:CreateFontString(nil,"OVERLAY","GameFontHighlight");frame.text:SetPoint("TOPLEFT",8,-8);frame.text:SetJustifyH("LEFT");frame.text:SetJustifyV("TOP")
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart",function(self)if ns.Notes().cfg.unlocked then self:StartMoving()end end)
        frame:SetScript("OnDragStop",function(self)self:StopMovingOrSizing();local point,_,rel,x,y=self:GetPoint();ns.Notes().cfg.pos={point=point,relPoint=rel,x=x,y=y}end)
    end
    local width=tonumber(cfg.width)or 320
    frame:SetSize(width,tonumber(cfg.height)or 260);frame.text:SetWidth(width-16)
    if ns.Widgets then frame.text:SetFont(ns.Widgets.Font(false),tonumber(cfg.fontSize)or 13,"OUTLINE")end
    frame.text:SetText(#parts>0 and table.concat(parts,"\n\n")or L("Note frame · drag to move"))
    frame:ClearAllPoints();local pos=cfg.pos or{point="LEFT",relPoint="LEFT",x=40,y=80};frame:SetPoint(pos.point or"LEFT",UIParent,pos.relPoint or"LEFT",pos.x or 40,pos.y or 80)
    frame:EnableMouse(cfg.unlocked==true);frame:Show();return true
end
function ns.ToggleNoteDisplay()
    local cfg=ns.Notes().cfg;cfg.show=not cfg.show;ns.RefreshNoteDisplay();return cfg.show
end
local events=CreateFrame("Frame")
for _,e in ipairs({"PLAYER_ENTERING_WORLD","ENCOUNTER_START","ENCOUNTER_END"})do events:RegisterEvent(e)end
events:SetScript("OnEvent",function(_,event)
    if event=="ENCOUNTER_START"and ns.Notes().cfg.assignOnPull then ns.ShowAssignment()end
    if ns.RefreshContext then ns.RefreshContext()end;ns.RefreshNoteDisplay()
end)
---------------------------------------------------------------------------
local function bossOptions()
    local out={{value=0,label=L("No boss")}}
    for _,r in ipairs(ns.Catalog.raids or{})do for _,b in ipairs(r.bosses or{})do out[#out+1]={value=b.id,label=b.name}end end
    return out
end
local function sorted(list)
    local out={};for id,note in pairs(list)do out[#out+1]={id=id,note=note}end
    table.sort(out,function(a,b)return a.note.name:lower()<b.note.name:lower()end);return out
end
local function DrawNotes(parent)
    local state=kit.state;local n=ns.Notes();local d=state.drafts
    d.noteKind=d.noteKind or"shared";local kind=d.noteKind
    kit.header(parent,L("Notes"),L("Shared notes go to the group, personal notes stay with you."))
    W.Segmented(parent,{{value="shared",label=L("Shared notes")},{value="personal",label=L("Personal notes")}},kind,0,56,300,function(v)d.noteKind=v;d.note=nil;d.noteId=nil;kit.refresh()end,"note-kind")
    local rows=sorted(n[kind])
    local list=W.Scroll(parent,0,96,300,412,"notes:list");local y=4
    local active=kind=="shared"and n.live and n.live.id or kind=="personal"and n.activePersonal
    if #rows==0 then W.Label(list,L("No notes yet. Create one, write it and save."),10,10,260,12,C.muted)end
    for _,r in ipairs(rows)do
        local label=r.note.name..(r.id==active and("  · "..L("active"))or"")
        W.Button(list,label,0,y,272,function()d.noteId=r.id;d.note={name=r.note.name,text=r.note.text,boss=r.note.encounter or 0,diff=r.note.difficulty or 0};d.noteConfirm=nil;kit.refresh()end,r.id==d.noteId,"note:"..r.id,{h=30,marker=true,glyph="notes"});y=y+34
    end;list:SetHeight(math.max(1,y+4))
    W.Button(parent,L("+ Create note"),0,516,300,function()d.noteId=nil;d.note={name=L("New note"),text="",boss=0,diff=0};d.noteConfirm=nil;kit.refresh()end,false,"note-new",{kind="outline",align="CENTER"})
    if kind=="shared"and n.live and n.live.received then
        W.Button(parent,L("Keep received note")..": "..n.live.name.." ("..tostring(n.live.from)..")",0,552,300,function()d.noteId=nil;d.note={name=n.live.name,text=n.live.text,boss=0,diff=0};kit.refresh()end,false,"note-received",{kind="ghost"})
    end
    local f=d.note
    if not f then
        local card=W.Card(parent,312,56,608,536,L("Note"))
        W.Label(card,L("Choose a note on the left or create a new one."),16,40,560,13,C.muted)
    else
        local card=W.Card(parent,312,56,608,536,d.noteId and L("Edit note")or L("New note"))
        local function collect()for _,k in ipairs({"name","text"})do local c=ns.UIControls["note:"..k];if c then f[k]=c:GetText()end end end
        W.Field(card,L("NAME"),f.name,16,34,280,"note:name")
        W.Select(card,L("BOSS"),bossOptions(),f.boss,312,34,280,function(v)collect();f.boss=v;kit.refresh()end,"note:boss")
        W.Caption(card,L("TEXT · ONE ASSIGNMENT PER LINE, E.G. \"Soak 1: Name Name\""),16,90,576)
        W.Input(card,f.text,16,106,576,"note:text",true)
        local save=function()collect();local id,err=ns.SaveNote(kind,d.noteId,f);if id then d.noteId=id end;return id,err end
        W.Button(card,L("Save"),16,300,110,function()local id,err=save();kit.done(id,err,L("Note saved"))end,false,"note-save",{kind="primary",align="CENTER"})
        if kind=="shared"then
            W.Button(card,L("Load & send"),134,300,140,function()local id,err=save();if not id then kit.done(nil,err)return end;local ok,msg=ns.LoadNote(kind,id,true);kit.done(ok,msg,msg or L("Shared note loaded and sent to the group"))end,false,"note-load",{glyph="play"})
        else
            W.Button(card,L("Load"),134,300,140,function()local id,err=save();if not id then kit.done(nil,err)return end;kit.done(ns.LoadNote(kind,id),nil,L("Personal note on screen"))end,false,"note-load",{glyph="play"})
        end
        W.Button(card,L("Unload"),282,300,110,function()kit.done(ns.UnloadNote(kind,true),nil,L("Note taken off"))end,false,"note-unload",{kind="outline",align="CENTER"})
        if d.noteId then
            W.Button(card,d.noteConfirm and L("Confirm delete")or L("Delete"),472,300,120,function()if not d.noteConfirm then d.noteConfirm=true;kit.refresh()return end;d.noteConfirm=nil;local ok,err=ns.DeleteNote(kind,d.noteId);if ok then d.noteId=nil;d.note=nil end;kit.done(ok,err,L("Note deleted"))end,false,"note-delete",{kind="danger",align="CENTER"})
        end
        local cfg=n.cfg
        W.Heading(card,L("On screen"),16,348,576)
        W.Toggle(card,L("Show active notes on screen"),cfg.show,16,374,270,function(v)cfg.show=v;ns.RefreshNoteDisplay()end,"note-show")
        W.Toggle(card,L("Unlock to move"),cfg.unlocked,312,374,270,function(v)cfg.unlocked=v;ns.RefreshNoteDisplay()end,"note-unlock")
        W.Toggle(card,L("Also outside dungeons and raids"),cfg.outside,16,406,270,function(v)cfg.outside=v;ns.RefreshNoteDisplay()end,"note-outside")
        W.Toggle(card,L("Show my lines when the pull starts"),cfg.assignOnPull,312,406,270,function(v)cfg.assignOnPull=v end,"note-assign")
        local live={};if n.live then live[#live+1]=L("shared")..": "..n.live.name end;local p=n.activePersonal and n.personal[n.activePersonal];if p then live[#live+1]=L("personal")..": "..p.name end
        W.Label(card,L("Active now")..": "..(#live>0 and table.concat(live," · ")or L("none")),16,446,576,12,C.soft)
        W.Label(card,L("Load & send needs group leader or assistant. /ndp note shows or hides the frame, /ndp clear takes the shared note off."),16,470,576,11,C.muted)
        W.Button(card,L("Show my lines now"),16,498,200,function()local count=ns.ShowAssignment();kit.notify(count>0 and(count..L(" lines shown"))or L("No line names you"))end,false,"assign-test",{glyph="play"})
        W.Toggle(card,L("Timers from {time:} lines"),cfg.timers~=false,228,502,200,function(v)cfg.timers=v end,"note-timers")
        local secs={};for _,v in ipairs({4,6,8,10})do secs[#secs+1]={value=v,label=v..L(" s before")}end
        W.Select(card,nil,secs,tonumber(cfg.timerDuration)or 6,448,496,144,function(v)cfg.timerDuration=v;kit.refresh()end,"note-timer-duration")
    end
end
ns.ExtraPages.notes=DrawNotes
