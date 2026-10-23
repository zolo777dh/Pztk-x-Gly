local _,ns=...
function ns.Print(message)print("|cff009dffNaowh Defensive Planner:|r "..tostring(message))end
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
    local lines={"Naowh Defensive Planner "..ns.version,"Client: "..ns.Client(),"Build: "..tostring(version).." / "..tostring(build).." / interface "..tostring(interface)}
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
-- /ndp is the main command. Old NSR (/nutank) and NSRT (/ns, /nsrt) commands live on as /ndp subcommands;
-- pre-0.4.0 slashes stay as aliases.
SLASH_NDP1="/ndp"
SLASH_NDP2="/nwhdp"
SLASH_NDP3="/naowhdp"
SLASH_NDP4="/pztkr"
SLASH_NDP5="/puzatik"
-- Entry in the minimap addon compartment menu (declared in the TOC).
function NaowhDefensivePlanner_OnAddonCompartmentClick()ns.Open()end
local sections={sets="sets",defensives="sets",mythic="mythic",["m+"]="mythic",raid="raid",raids="raid",overview="overview",tl="timeline",timeline="timeline",
    notes="notes",reminders="notes",r="notes",preminders="notes",pr="notes",alerts="alerts",auras="debuffs",debuffs="debuffs",assign="assign",assignments="assign",
    tools="raidtools",raidtools="raidtools",rt="raidtools",players="players",qol="qol",combat="combat",interrupts="combat",kicks="combat",pace="combat",nicks="players",display="display",profiles="profiles",settings="settings",config="settings"}
-- Commands from the old addons that are not rebuilt yet: say so instead of silently opening the window.
local planned={bosses=true,keys=true,trace=true,observed=true,cds=true,calls=true,cd=true,invite=true}
local function help()
    ns.Print("Commands:")
    for _,c in ipairs(ns.CommandHelp or{})do print("  |cff33c3a6"..c[1].."|r - "..c[2])end
end
local wipeAsked
function ns.Command(message)
    local command,rest=tostring(message or""):match("^%s*(%S*)%s*(.-)%s*$");command=(command or""):lower()
    if command~="wipe"then wipeAsked=nil end
    if command==""then
        if ns.WorkspaceWindow and ns.WorkspaceWindow:IsShown()then ns.WorkspaceWindow:Hide()else ns.Open()end
    elseif command=="help"or command=="?"then help()
    elseif command=="debug"or command=="diag"or command=="diagnostics"then ns.ShowDiagnostics()
    elseif command=="status"then
        local p=ns.ProviderStatus and ns.ProviderStatus()or{}
        ns.Print(ns.version.." · "..ns.Client().." · profile "..tostring(ns.Store().active or"none").." · spec "..tostring(ns.Catalog.specs[ns.Spec()or 0]or"unknown"))
        ns.Print("Combat source: "..(p.BigWigs and"BigWigs"or p.DBM and"DBM"or"none")..(p.EXBoss and" + ExBoss"or"").." · conflict: "..(ns.Conflict()or"none"))
    elseif command=="test"then ns.Display({type="icon",spellID=22812,text="Use a defensive",dur=4})
    elseif command=="anchors"or command=="anchor"or command=="move"then if ns.ToggleAnchors then ns.Print(ns.ToggleAnchors()and"Anchor unlocked: drag it, then /ndp anchors to lock."or"Anchor locked.")end
    elseif command=="pull"then
        local seconds=tonumber(rest)or 10
        if C_PartyInfo and C_PartyInfo.DoCountdown then C_PartyInfo.DoCountdown(seconds)else ns.Print("Pull timers are not available on this client.")end
    elseif command=="rc"or command=="readycheck"then if DoReadyCheck then DoReadyCheck()end
    elseif command=="roster"then ns.OpenWorkspace("diag");if ns.UIControls["diag-roster"]then ns.UIControls["diag-roster"]:Click()end
    elseif command=="export"then ns.OpenWorkspace("profiles");if ns.UIControls["profile-export"]then ns.UIControls["profile-export"]:Click()end
    elseif command=="wipe"then
        if rest:lower()=="confirm"and wipeAsked then NaowhDefensivePlannerDB=nil;ns.Print("All data removed. Reloading.");if ReloadUI then ReloadUI()end
        else wipeAsked=true;ns.Print("This removes every profile and setting on all clients. Type /ndp wipe confirm to continue.")end
    elseif command=="note"or command=="n"or command=="anote"or command=="an"or command=="pnote"or command=="pn"or command=="snote"or command=="sn"or command=="tnote"or command=="tn"then
        ns.Print(ns.ToggleNoteDisplay()and"Note frame on."or"Note frame off.")
    elseif command=="clear"or command=="c"then local ok,err=ns.UnloadNote("shared",true);ns.Print(ok and"Shared note cleared."or err)
    elseif command=="pclear"or command=="pc"then ns.UnloadNote("personal");ns.Print("Personal note cleared.")
    elseif command=="break"or command=="brb"then local ok,err=ns.StartBreak(tonumber(rest)or 10);if not ok then ns.Print(err)end
    elseif command=="inv"then local n,err=ns.InviteGuild();ns.Print(n and(n.." guild invites sent.")or err)
    elseif command=="arrange"then local ok,err=ns.ArrangeGroups();ns.Print(ok and"Arranging groups."or err)
    elseif command=="promote"then local n,err=ns.PromoteAssistants();ns.Print(n and(n.." players promoted.")or err)
    elseif command=="nick"or command=="nickname"then local ok,err=ns.SetMyNickname(rest);ns.Print(ok and("Nickname: "..(rest~=""and rest or"none"))or err)
    elseif command=="versions"or command=="vc"then ns.CheckVersions();ns.OpenWorkspace("players")
    elseif sections[command]then ns.OpenWorkspace(sections[command])
    elseif planned[command]then ns.Print("/ndp "..command.." is not rebuilt yet; see the Diagnostics page for what is available.")
    else ns.Print("Unknown command: "..command..". Type /ndp help.")end
end
SlashCmdList.NDP=function(message)ns.Command(message)end
local events=CreateFrame("Frame")
for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","ENCOUNTER_START","ENCOUNTER_END","PLAYER_REGEN_ENABLED","PLAYER_SPECIALIZATION_CHANGED","PLAYER_LOGOUT"})do events:RegisterEvent(event)end
-- Countdown events may be missing on some clients; pre-pull reminders then stay idle.
for _,event in ipairs({"START_PLAYER_COUNTDOWN","CANCEL_PLAYER_COUNTDOWN"})do pcall(events.RegisterEvent,events,event)end
pcall(events.RegisterUnitEvent or events.RegisterEvent,events,"UNIT_SPELLCAST_SUCCEEDED","player")
events:SetScript("OnEvent",function(_,event,a,b,c,d,e)
    if event=="UNIT_SPELLCAST_SUCCEEDED"then if a=="player"then if ns.NoteCast then ns.NoteCast(c)end;if ns.HideSpell then ns.HideSpell(c)end end;return end
    if event=="PLAYER_LOGOUT"then if ns.SaveWorkspaceDrafts then ns.SaveWorkspaceDrafts()end;return
    elseif event=="ENCOUNTER_START"then ns.RefreshContext();ns.Begin(a,c,ns.map)
    elseif event=="START_PLAYER_COUNTDOWN"then ns.Countdown(b)
    elseif event=="CANCEL_PLAYER_COUNTDOWN"then ns.Countdown(nil)
    elseif event=="ENCOUNTER_END"then if ns.FinishRecording then ns.FinishRecording(e==1)end;ns.Reset()
    elseif event=="PLAYER_REGEN_ENABLED"then ns.Cancel("trash:")
    else
        if event=="PLAYER_SPECIALIZATION_CHANGED"and a~="player"then return end
        if event=="PLAYER_ENTERING_WORLD"or event=="PLAYER_SPECIALIZATION_CHANGED"then ns.Reset()end
        if event=="ADDON_LOADED"and a=="NaowhDefensivePlanner"and ns.ApplyUIPrefs then ns.ApplyUIPrefs()end
        -- The window only ever shows the current specialization.
        if event=="PLAYER_SPECIALIZATION_CHANGED"and ns.WorkspaceWindow and ns.WorkspaceWindow:IsShown()then ns.OpenWorkspace()end
        ns.RefreshContext();ns.ConnectProviders();local conflict=ns.Conflict();if conflict then ns.Cancel();if ns.HideDisplays then ns.HideDisplays()end end;if conflict and warning~=conflict then warning=conflict;ns.Print("Paused: disable "..conflict.." and reload to use Naowh Defensive Planner.")elseif not conflict then warning=nil end
    end
    if ns.RefreshAuraSounds then ns.RefreshAuraSounds()end
end)
