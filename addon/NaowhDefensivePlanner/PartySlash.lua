-- /pcd and /ppd: the party cooldown settings typed in chat (from Puzatik Party Defensives, now part
-- of this addon). /pcd alone opens the Party cooldowns page.
local _,ns=...
local L=ns.L
local function say(text)print("|cff33c3a6NDP|r "..text)end
local HELP={
    "/pcd: the Party cooldowns page",
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
SLASH_PUZATIKPARTYDEFENSIVES1="/pcd";SLASH_PUZATIKPARTYDEFENSIVES2="/ppd"
SlashCmdList.PUZATIKPARTYDEFENSIVES=function(input)
    local cmd,arg=tostring(input or""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local cfg=ns.PartyCooldownConfig()
    if cmd=="on"or cmd=="off"then cfg.enabled=cmd=="on";say(L(cfg.enabled and"Tracking on"or"Tracking off"))
    elseif cmd=="frames"or cmd=="list"then cfg.mode=cmd;say(L(cmd=="frames"and"Beside the party frames"or"As a list"))
    elseif SIDE[cmd]then cfg.side=SIDE[cmd];say(L("Side: ")..cmd)
    elseif cmd=="size"then local n=tonumber(arg);if n and n>=20 and n<=40 then cfg.size=math.floor(n);say(L("Icon size ")..cfg.size)else say(L("Size from 20 to 40"))end
    elseif cmd=="unlock"or cmd=="lock"then cfg.unlocked=cmd=="unlock";say(L(cfg.unlocked and"Unlocked: drag the list"or"Locked"))
    elseif cmd=="ready"then cfg.hideReady=not cfg.hideReady;say(L("Only cooldowns in use: ")..L(cfg.hideReady and"on"or"off"))
    elseif cmd=="names"then cfg.names=not cfg.names;say(L("Names: ")..L(cfg.names and"on"or"off"))
    elseif cmd=="self"then cfg.self=not cfg.self;say(L("Your own cooldowns: ")..L(cfg.self and"on"or"off"))
    elseif cmd=="reset"then ns.PartyCooldownReset();say(L("All cooldowns are ready again"));return
    elseif cmd=="report"then for _,line in ipairs(ns.PartyCooldownReport())do print("  "..line)end;return
    elseif cmd==""then ns.OpenWorkspace("partycds");return
    else for _,line in ipairs(HELP)do say(L(line))end;return end
    ns.RefreshPartyCooldowns()
end
