-- /pcd: the settings of the party cooldowns, typed in chat.
local _,ns=...
local function say(text)print("|cff33c3a6NDP Party Cooldowns|r "..text)end
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
    "/pcd report: what is being tracked, for bug reports",
}
local SIDE={left="LEFT",right="RIGHT",top="TOP",bottom="BOTTOM"}
SLASH_NDPPARTYCOOLDOWNS1="/pcd";SLASH_NDPPARTYCOOLDOWNS2="/ndppcd"
SlashCmdList.NDPPARTYCOOLDOWNS=function(input)
    if ns.FullAddonLoaded()then say("Naowh Defensive Planner is enabled and already tracks party cooldowns (/ndp party). This addon stays off.");return end
    local cmd,arg=strtrim(input or""):lower():match("^(%S*)%s*(.-)$")
    local cfg=ns.PartyCooldownConfig()
    if cmd=="on"or cmd=="off"then cfg.enabled=cmd=="on";say("Tracking "..(cfg.enabled and"on"or"off"))
    elseif cmd=="frames"or cmd=="list"then cfg.mode=cmd;say(cmd=="frames"and"Beside the party frames"or"As a list")
    elseif SIDE[cmd]then cfg.side=SIDE[cmd];say("Side: "..cmd)
    elseif cmd=="size"then local n=tonumber(arg);if n and n>=20 and n<=40 then cfg.size=math.floor(n);say("Icon size "..cfg.size)else say("Size from 20 to 40")end
    elseif cmd=="unlock"or cmd=="lock"then cfg.unlocked=cmd=="unlock";say(cfg.unlocked and"Unlocked: drag the list"or"Locked")
    elseif cmd=="ready"then cfg.hideReady=not cfg.hideReady;say("Only cooldowns in use: "..(cfg.hideReady and"on"or"off"))
    elseif cmd=="names"then cfg.names=not cfg.names;say("Names: "..(cfg.names and"on"or"off"))
    elseif cmd=="self"then cfg.self=not cfg.self;say("Your own cooldowns: "..(cfg.self and"on"or"off"))
    elseif cmd=="reset"then ns.PartyCooldownReset();say("All cooldowns are ready again");return
    elseif cmd=="report"then for _,line in ipairs(ns.PartyCooldownReport())do print("  "..line)end;return
    elseif cmd==""then ns.OpenPartyCooldownWindow();return
    else for _,line in ipairs(HELP)do say(line)end;return end
    ns.RefreshPartyCooldowns()
end
