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
    end
end
local function DrawAssignments(parent)
    local n=ns.Notes()
    kit.header(parent,L("Assignments"),L("Lines of the active notes that have your name or nickname."))
    local card=W.Card(parent,0,56,600,536,L("Your assignments"))
    local lines=ns.MyNoteLines()
    if #lines==0 then W.Label(card,L("No line of the active notes names you yet. Load a note on the Notes page or ask the leader to send one."),16,40,560,13,C.muted)end
    for i,line in ipairs(lines)do if i<=14 then local row=W.Panel(card,12,34+(i-1)*34,576,30,C.raised,C.clear,6);W.Label(row,line,10,8,556,13,C.text)end end
    local side=W.Card(parent,612,56,308,536,L("On pull"))
    W.Toggle(side,L("Show my lines when the pull starts"),n.cfg.assignOnPull,12,36,284,function(v)n.cfg.assignOnPull=v end,"assign-pull")
    W.Button(side,L("Show them now"),12,72,284,function()local count=ns.ShowAssignment();kit.notify(count>0 and(count..L(" lines shown"))or L("No line names you"))end,false,"assign-test",{glyph="play"})
    W.Button(side,L("Open notes"),12,110,284,function()kit.go("notes")end,false,"assign-notes",{glyph="notes",kind="outline"})
    W.Label(side,L("Lines match your character name and the nickname from the Players page. Boss-specific automatic splits of Northern Sky Raid Tools are not rebuilt."),12,156,284,11,C.muted)
end
ns.ExtraPages.notes=DrawNotes
ns.ExtraPages.assign=DrawAssignments
