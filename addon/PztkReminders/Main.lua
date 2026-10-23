local _,ns=...
function ns.Print(message)print("|cff009dffPuzatik Reminders:|r "..tostring(message))end
local warning
function ns.RefreshContext()
    local difficulty,map,kind
    if GetInstanceInfo then local _,k,d,_,_,_,_,m=GetInstanceInfo();difficulty=d;map=m;kind=k end
    ns.difficulty=ns.Plain(difficulty,"number")and difficulty or nil
    ns.map=ns.Plain(map,"number")and map or nil
    ns.instanceType=ns.Plain(kind,"string")and kind or nil
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
    local pull,status=ns.pullEncounter,ns.pullStatus
    if pull==nil and status==nil then pull,status=ns.PullEncounter()end
    lines[#lines+1]="Pre-pull encounter: "..(pull and tostring(pull)or "none ("..tostring(status)..")")
    if ns.AuraSoundStatus then lines[#lines+1]="Aura sounds: "..ns.AuraSoundStatus()end
    return table.concat(lines,"\n")
end
function ns.Open()
    ns.ConnectProviders()
    if ns.RefreshAuraSounds then ns.RefreshAuraSounds()end
    ns.OpenWorkspace()
end
SLASH_PZTKREMINDERS1="/pztkr"
SLASH_PZTKREMINDERS2="/pztkreminders"
SLASH_PZTKREMINDERS3="/puzatik"
SlashCmdList.PZTKREMINDERS=function(message)
    if type(message)=="string"and message:lower():match("^%s*debug%s*$")then ns.ShowDiagnostics()else ns.Open()end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","ENCOUNTER_START","ENCOUNTER_END","PLAYER_REGEN_ENABLED","PLAYER_SPECIALIZATION_CHANGED","PLAYER_LOGOUT"})do events:RegisterEvent(event)end
-- Countdown events may be missing on some clients; pre-pull reminders then stay idle.
for _,event in ipairs({"START_PLAYER_COUNTDOWN","CANCEL_PLAYER_COUNTDOWN"})do pcall(events.RegisterEvent,events,event)end
events:SetScript("OnEvent",function(_,event,a,b,c)
    if event=="PLAYER_LOGOUT"then if ns.SaveWorkspaceDrafts then ns.SaveWorkspaceDrafts()end;return
    elseif event=="ENCOUNTER_START"then ns.RefreshContext();ns.Begin(a,c,ns.map)
    elseif event=="START_PLAYER_COUNTDOWN"then ns.Countdown(b)
    elseif event=="CANCEL_PLAYER_COUNTDOWN"then ns.Countdown(nil)
    elseif event=="ENCOUNTER_END"then ns.Reset()
    elseif event=="PLAYER_REGEN_ENABLED"then ns.Cancel("trash:")
    else
        if event=="PLAYER_SPECIALIZATION_CHANGED"and a~="player"then return end
        if event=="PLAYER_ENTERING_WORLD"or event=="PLAYER_SPECIALIZATION_CHANGED"then ns.Reset()end
        ns.RefreshContext();ns.ConnectProviders();local conflict=ns.Conflict();if conflict then ns.Cancel();if ns.HideDisplays then ns.HideDisplays()end end;if conflict and warning~=conflict then warning=conflict;ns.Print("Paused: disable "..conflict.." and reload to use Pztk Reminders.")elseif not conflict then warning=nil end
    end
    if ns.RefreshAuraSounds then ns.RefreshAuraSounds()end
end)
