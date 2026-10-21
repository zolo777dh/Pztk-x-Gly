local _,ns=...
function ns.Print(message)print("|cff009dffPztk Reminders:|r "..tostring(message))end
local warning,window
function ns.RefreshContext()
    local difficulty,map,kind
    if GetInstanceInfo then local _,k,d,_,_,_,_,m=GetInstanceInfo();difficulty=d;map=m;kind=k end
    ns.difficulty=ns.Plain(difficulty,"number")and difficulty or nil
    ns.map=ns.Plain(map,"number")and map or nil
    ns.instanceType=ns.Plain(kind,"string")and kind or nil
end
local function Button(parent,label,x,y,callback)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetSize(125,24);b:SetPoint("TOPLEFT",x,y);b:SetText(label);b:SetScript("OnClick",callback);return b
end
function ns.Diagnostics()
    local version,build,_,interface=GetBuildInfo()
    local lines={"Pztk Reminders "..ns.version,"Client: "..ns.Client(),"Build: "..tostring(version).." / "..tostring(build).." / interface "..tostring(interface)}
    local loaded=C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    local metadata=C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local status,errors=ns.ProviderStatus()
    for _,name in ipairs({"BigWigs","LittleWigs","EXBoss","EXBossData","ExwindCore","EXBOSS-Locale","EXBOSS-LocaleBase"})do
        local ok,addonVersion
        if metadata then ok,addonVersion=pcall(metadata,name,"Version")end
        if not ok then addonVersion="unknown"end
        if not ns.Plain(addonVersion,"string")then addonVersion="unknown"end
        lines[#lines+1]=name..": "..(loaded and loaded(name)and "loaded"or "not loaded").." / "..addonVersion
    end
    for _,name in ipairs({"BigWigs","DBM","EXBoss"})do lines[#lines+1]=name.." connection: "..(status[name]and "connected"or "not connected");if errors[name]then lines[#lines+1]=errors[name]end end
    lines[#lines+1]="Conflict: "..(ns.Conflict()or "none")
    lines[#lines+1]="Profile present: "..(ns.Active()and "yes"or "no")
    lines[#lines+1]="Encounter / difficulty / map: "..tostring(ns.encounter).." / "..tostring(ns.difficulty).." / "..tostring(ns.map)
    if ns.AuraSoundStatus then lines[#lines+1]="Aura sounds: "..ns.AuraSoundStatus()end
    return table.concat(lines,"\n")
end
function ns.Open()
    if not window then
        window=CreateFrame("Frame","PztkRemindersWindow",UIParent,"BasicFrameTemplateWithInset");window:SetSize(680,440);window:SetPoint("CENTER");window:SetFrameStrata("DIALOG");window:SetMovable(true);window:EnableMouse(true);window:RegisterForDrag("LeftButton");window:SetScript("OnDragStart",window.StartMoving);window:SetScript("OnDragStop",window.StopMovingOrSizing);window.TitleText:SetText("Pztk Reminders "..ns.version)
        window.status=window:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");window.status:SetPoint("TOPLEFT",16,-35);window.status:SetWidth(640);window.status:SetJustifyH("LEFT")
        local scroll=CreateFrame("ScrollFrame",nil,window,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",18,-105);scroll:SetPoint("BOTTOMRIGHT",-38,55)
        window.edit=CreateFrame("EditBox",nil,scroll);window.edit:SetMultiLine(true);window.edit:SetFontObject(GameFontHighlightSmall);window.edit:SetWidth(610);window.edit:SetHeight(1);window.edit:SetAutoFocus(false);window.edit:SetMaxLetters(130000);window.edit:SetScript("OnEscapePressed",function(self)self:ClearFocus()end);scroll:SetScrollChild(window.edit)
        Button(window,"Import string",16,-72,function()if InCombatLockdown and InCombatLockdown()then ns.Print("Import after combat.");return end;local name,error=ns.Import(window.edit:GetText());ns.Print(name and "Imported "..name or error);ns.Open()end)
        Button(window,"Export active",150,-72,function()local text,error=ns.Export();if text then window.edit:SetText(text);window.edit:HighlightText();window.edit:SetFocus()else ns.Print(error)end end)
        Button(window,"Next profile",284,-72,function()if InCombatLockdown and InCombatLockdown()then return end;local store=ns.Store();local names={};for name in pairs(store.profiles)do names[#names+1]=name end;table.sort(names);for i,name in ipairs(names)do if name==store.active then store.active=names[i%#names+1];ns.Reset();ns.Open();return end end;if names[1]then store.active=names[1];ns.Open()end end)
        Button(window,"Test display",418,-72,function()ns.Display({type="icon",spellID=498,text="Preview: use defensive",dur=5,sound="voice:use-a-defensive"})end)
        local diagnostic=Button(window,"Diagnostics",552,-72,function()window.edit:SetText(ns.Diagnostics());window.edit:HighlightText();window.edit:SetFocus()end);diagnostic:SetWidth(110)
        local help=window:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");help:SetPoint("BOTTOMLEFT",16,16);help:SetText("Paste one PZTK1 profile from Pztk x Glyalith. Disable NSR / NSRT / TimelineReminders.")
    end
    ns.ConnectProviders()
    if ns.RefreshAuraSounds then ns.RefreshAuraSounds()end
    local conflict=ns.Conflict();window.status:SetText(ns.Client().." | Profile: "..tostring(ns.Store().active or "none")..(conflict and " | PAUSED: "..conflict.." is loaded"or " | Ready"));window:Show()
end
SLASH_PZTKREMINDERS1="/pztkr"
SLASH_PZTKREMINDERS2="/pztkreminders"
SlashCmdList.PZTKREMINDERS=function(message)
    ns.Open()
    if type(message)=="string"and message:lower():match("^%s*debug%s*$")then window.edit:SetText(ns.Diagnostics());window.edit:HighlightText();window.edit:SetFocus()end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","ENCOUNTER_START","ENCOUNTER_END","PLAYER_REGEN_ENABLED","PLAYER_SPECIALIZATION_CHANGED"})do events:RegisterEvent(event)end
events:SetScript("OnEvent",function(_,event,a,b,c)
    if event=="ENCOUNTER_START"then ns.RefreshContext();ns.Begin(a,c,ns.map)
    elseif event=="ENCOUNTER_END"then ns.Reset()
    elseif event=="PLAYER_REGEN_ENABLED"then ns.Cancel("trash:")
    else
        if event=="PLAYER_SPECIALIZATION_CHANGED"and a~="player"then return end
        if event=="PLAYER_ENTERING_WORLD"or event=="PLAYER_SPECIALIZATION_CHANGED"then ns.Reset()end
        ns.RefreshContext();ns.ConnectProviders();local conflict=ns.Conflict();if conflict then ns.Cancel();if ns.HideDisplays then ns.HideDisplays()end end;if conflict and warning~=conflict then warning=conflict;ns.Print("Paused: disable "..conflict.." and reload to use Pztk Reminders.")elseif not conflict then warning=nil end
    end
    if ns.RefreshAuraSounds then ns.RefreshAuraSounds()end
end)
