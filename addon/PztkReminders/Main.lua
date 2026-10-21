local _,ns=...
function ns.Print(message)print("|cff009dffPztk Reminders:|r "..tostring(message))end
local hooked,exhooked,warning,window
local function Context()
    if GetInstanceInfo then local _,_,difficulty,_,_,_,_,map=GetInstanceInfo();if ns.Plain(difficulty,"number")then ns.difficulty=difficulty end;if ns.Plain(map,"number")then ns.map=map end end
end
local function Connect()
    if not hooked and BigWigsLoader and BigWigsLoader.RegisterMessage then
        hooked=true
        BigWigsLoader.RegisterMessage(ns,"BigWigs_Timer",function(_,module,spell,duration)if ns.Plain(spell,"number")and ns.Plain(duration,"number")then ns.Mechanic(spell,duration,"BW:"..spell,(type(module)=="table"and module.engageId)or ns.encounter)end end)
        BigWigsLoader.RegisterMessage(ns,"BigWigs_Message",function(_,module,spell)if ns.Plain(spell,"number")then ns.Mechanic(spell,nil,"BW:"..spell,(type(module)=="table"and module.engageId)or ns.encounter)end end)
        BigWigsLoader.RegisterMessage(ns,"BigWigs_SetStage",function(_,_,phase)ns.Phase(phase)end)
        for _,event in ipairs({"BigWigs_StopBar","BigWigs_PauseBar"})do BigWigsLoader.RegisterMessage(ns,event,function(_,_,spell)if ns.Plain(spell,"number")then ns.Cancel("ability:BW:"..spell..":")end end)end
        BigWigsLoader.RegisterMessage(ns,"BigWigs_StopBars",function()ns.Cancel("ability:BW:")end)
    end
    if DBM and DBM.RegisterCallback and not ns.dbmHooked then
        ns.dbmHooked=true
        for _,event in ipairs({"DBM_TimerBegin","DBM_TimerStart"})do DBM:RegisterCallback(event,function(_,identity,_,duration,_,_,spell)if not BigWigsLoader and ns.Plain(spell,"number")and ns.Plain(duration,"number")and ns.Plain(identity)then ns.Mechanic(spell,duration,"DBM:"..tostring(identity))end end)end
        DBM:RegisterCallback("DBM_Announce",function(_,_,_,_,spell)if not BigWigsLoader and ns.Plain(spell,"number")then ns.Mechanic(spell)end end)
        DBM:RegisterCallback("DBM_SetStage",function(_,_,_,phase)if not BigWigsLoader then ns.Phase(phase)end end)
        for _,event in ipairs({"DBM_TimerStop","DBM_TimerPause"})do DBM:RegisterCallback(event,function(_,identity)if ns.Plain(identity)then ns.Cancel("ability:DBM:"..tostring(identity)..":")end end)end
    end
    local scheduler=ExBoss and ExBoss.Timeline and ExBoss.Timeline.Scheduler
    if not exhooked and scheduler and type(scheduler.GetActiveTimers)=="function"and type(scheduler.RegisterTrashLocalTimer)=="function"and hooksecurefunc then
        exhooked=true
        local function Observe(id)
            if not ns.Plain(id)then return end
            local timer=scheduler:GetActiveTimers()[id]
            if type(timer)=="table"and ns.Plain(timer.spellID,"number")and ns.Plain(timer.castTime,"number")then Context();ns.Trash(timer.spellID,math.max(0,timer.castTime-GetTime()),id)end
        end
        hooksecurefunc(scheduler,"RegisterTrashLocalTimer",function(_,runtime,_,spell)if type(runtime)=="table"and type(spell)=="table"and ns.Plain(spell.spellID,"number")then Observe(ns.Get(runtime.localTimerIDsBySpellID,spell.spellID))end end)
        if type(scheduler._AdvanceTrashFixedCombatTimeline)=="function"then hooksecurefunc(scheduler,"_AdvanceTrashFixedCombatTimeline",function(_,timer)if type(timer)=="table"then Observe(timer.id)end end)end
        if type(scheduler._RemoveActiveTimerByID)=="function"then hooksecurefunc(scheduler,"_RemoveActiveTimerByID",function(_,id)if ns.Plain(id)then ns.Cancel("trash:"..tostring(id)..":")end end)end
    end
end
local function Button(parent,label,x,y,callback)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetSize(125,24);b:SetPoint("TOPLEFT",x,y);b:SetText(label);b:SetScript("OnClick",callback);return b
end
function ns.Open()
    if not window then
        window=CreateFrame("Frame","PztkRemindersWindow",UIParent,"BasicFrameTemplateWithInset");window:SetSize(680,440);window:SetPoint("CENTER");window:SetFrameStrata("DIALOG");window:SetMovable(true);window:EnableMouse(true);window:RegisterForDrag("LeftButton");window:SetScript("OnDragStart",window.StartMoving);window:SetScript("OnDragStop",window.StopMovingOrSizing);window.TitleText:SetText("Pztk Reminders 0.1.0")
        window.status=window:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");window.status:SetPoint("TOPLEFT",16,-35);window.status:SetWidth(640);window.status:SetJustifyH("LEFT")
        local scroll=CreateFrame("ScrollFrame",nil,window,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",18,-105);scroll:SetPoint("BOTTOMRIGHT",-38,55)
        window.edit=CreateFrame("EditBox",nil,scroll);window.edit:SetMultiLine(true);window.edit:SetFontObject(GameFontHighlightSmall);window.edit:SetWidth(610);window.edit:SetAutoFocus(false);window.edit:SetMaxLetters(130000);window.edit:SetScript("OnEscapePressed",function(self)self:ClearFocus()end);scroll:SetScrollChild(window.edit)
        Button(window,"Import string",16,-72,function()if InCombatLockdown and InCombatLockdown()then ns.Print("Import after combat.");return end;local name,error=ns.Import(window.edit:GetText());ns.Print(name and "Imported "..name or error);ns.Open()end)
        Button(window,"Export active",150,-72,function()local text,error=ns.Export();if text then window.edit:SetText(text);window.edit:HighlightText();window.edit:SetFocus()else ns.Print(error)end end)
        Button(window,"Next profile",284,-72,function()if InCombatLockdown and InCombatLockdown()then return end;local store=ns.Store();local names={};for name in pairs(store.profiles)do names[#names+1]=name end;table.sort(names);for i,name in ipairs(names)do if name==store.active then store.active=names[i%#names+1];ns.Reset();ns.Open();return end end;if names[1]then store.active=names[1];ns.Open()end end)
        Button(window,"Test display",418,-72,function()ns.Display({type="icon",spellID=498,text="Preview: use defensive",dur=5,sound="voice:use-a-defensive"})end)
        local help=window:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");help:SetPoint("BOTTOMLEFT",16,16);help:SetText("Paste one PZTK1 profile from Pztk x Glyalith. Disable NSR / NSRT / TimelineReminders.")
    end
    local conflict=ns.Conflict();window.status:SetText(ns.Client().." | Profile: "..tostring(ns.Store().active or "none")..(conflict and " | PAUSED: "..conflict.." is loaded"or " | Ready"));window:Show()
end
SLASH_PZTKREMINDERS1="/pztkr"
SLASH_PZTKREMINDERS2="/pztkreminders"
SlashCmdList.PZTKREMINDERS=function()ns.Open()end
local events=CreateFrame("Frame")
for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","ENCOUNTER_START","ENCOUNTER_END","PLAYER_REGEN_ENABLED"})do events:RegisterEvent(event)end
events:SetScript("OnEvent",function(_,event,a,b,c)
    if event=="ENCOUNTER_START"then Context();ns.Begin(a,c,ns.map)
    elseif event=="ENCOUNTER_END"then ns.Reset()
    elseif event=="PLAYER_REGEN_ENABLED"then ns.Cancel("trash:")
    else Context();Connect();local conflict=ns.Conflict();if conflict then ns.Cancel();if ns.HideDisplays then ns.HideDisplays()end end;if conflict and warning~=conflict then warning=conflict;ns.Print("Paused: disable "..conflict.." and reload to use Pztk Reminders.")elseif not conflict then warning=nil end end
end)
