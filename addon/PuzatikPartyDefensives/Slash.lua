-- /pcd: the settings of the party cooldowns, typed in chat.
local _,ns=...
local L=ns.L
local function say(text)print("|cffb88cffPuzatik Party Defensives|r "..text)end
local HELP={
    "/pcd: the settings window",
    "/pcd on | off: track party cooldowns",
    "/pcd frames | list: icons beside the party frames, or a movable list",
    "/pcd left | right | top | bottom: side of the party frame",
    "/pcd size 20-40: icon size",
    "/pcd unlock | lock: move the list (and preview it out of a group)",
    "/pcd ready: show only cooldowns in use, on/off",
    "/pcd names: names in the list, on/off",
    "/pcd self: your own cooldowns, on/off",
    "/pcd reset: every cooldown ready again",
    "/pcd ext: ask your healers for an external",
    "/pcd report: what is being tracked, for bug reports",
    "/pcd perf: time the addon spends, for lag reports (perf reset starts over)",
    "/pcd trace on | off | clear: write what the addon sees to the saved variables (for a whole key)",
}
local SIDE={left="LEFT",right="RIGHT",top="TOP",bottom="BOTTOM"}
SLASH_PUZATIKPARTYDEFENSIVES1="/pcd";SLASH_PUZATIKPARTYDEFENSIVES2="/ppd"
SlashCmdList.PUZATIKPARTYDEFENSIVES=function(input)
    local cmd,arg=strtrim(input or""):lower():match("^(%S*)%s*(.-)$")
    local cfg=ns.PartyCooldownConfig()
    if cmd=="on"or cmd=="off"then cfg.enabled=cmd=="on";say(L(cfg.enabled and"Tracking on"or"Tracking off"))
    elseif cmd=="frames"or cmd=="list"then cfg.mode=cmd;say(L(cmd=="frames"and"Beside the party frames"or"As a list"))
    elseif SIDE[cmd]then cfg.side=SIDE[cmd];say(L("Side: ")..cmd)
    elseif cmd=="size"then local n=tonumber(arg);if n and n>=20 and n<=40 then cfg.size=math.floor(n);say(L("Icon size ")..cfg.size)else say(L("Size from 20 to 40"))end
    elseif cmd=="unlock"or cmd=="lock"then cfg.unlocked=cmd=="unlock";say(L(cfg.unlocked and"Unlocked: drag the list"or"Locked"))
    elseif cmd=="ready"then cfg.hideReady=not cfg.hideReady;say(L("Only cooldowns in use: ")..L(cfg.hideReady and"on"or"off"))
    elseif cmd=="names"then cfg.names=not cfg.names;say(L("Names: ")..L(cfg.names and"on"or"off"))
    elseif cmd=="self"then cfg.self=not cfg.self;say(L("Your own cooldowns: ")..L(cfg.self and"on"or"off"))
    elseif cmd=="reset"then ns.PartyCooldownReset();say(L("Group timers were reset; yours follow the game"));return
    elseif cmd=="ext"then if not ns.RequestExternal()then say(L("Join a group first"))end;return
    elseif cmd=="report"then for _,line in ipairs(ns.PartyCooldownReport())do print("  "..line)end;return
    elseif cmd=="perf"then
        if arg=="reset"then ns.PartyCooldownPerf(true);say(L("Timing starts over"));return end
        local rows={};for key,p in pairs(ns.PartyCooldownPerf())do rows[#rows+1]={key,p}end
        table.sort(rows,function(a,b)return a[2].ms>b[2].ms end)
        say(L("Time spent since the last reset (ms)")..": "..L("sensors")..": "..ns.PartyCooldownSensorCount())
        for _,r in ipairs(rows)do local p=r[2];print(("  %s: %.1f ms, %d x, %.2f avg, %.1f max, %d KB"):format(r[1],p.ms,p.n,p.ms/math.max(1,p.n),p.max,math.floor(p.kb or 0)))end
        return
    elseif cmd=="trace"then
        if arg=="on"or arg=="off"or arg=="clear"then ns.PartyTraceSet(arg=="clear"and"clear"or arg=="on")end
        local t=ns.Store().partyTrace
        say(L("Trace")..": "..L(t and t.on and"on"or"off")..", "..(t and t.lines and #t.lines or 0).." "..L("lines. Saved on /reload or logout in WTF\\Account\\<account>\\SavedVariables\\PuzatikPartyDefensives.lua"))
        return
    elseif cmd==""then ns.OpenPartyCooldownWindow();return
    else for _,line in ipairs(HELP)do say(L(line))end;return end
    ns.RefreshPartyCooldowns()
end
