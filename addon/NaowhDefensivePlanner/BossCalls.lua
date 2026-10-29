-- Built-in boss calls: a short text, an optional bar and a spoken word for every mechanic the
-- built-in timers name, on every Midnight season 2 raid boss, with nothing to set up. A call
-- hangs on the live timeline bar of its spell (BossTimers.lua, or BigWigs/DBM when they run the
-- pull), so it follows pauses, stage changes and skipped casts instead of fixed seconds.
-- Each call: say (text), voice (true speaks the text, a string speaks that word), who (tank,
-- threat = the tank the boss is on, nontank, healer, damager), lead (seconds shown before the
-- cast), bar (a countdown bar instead of text), color, taunt (the other tank gets "Taunt" when
-- the cast lands), diff (difficulty IDs it is for; none means all).
-- The wording is ours; check each call in game before relying on it.
local _, ns = ...
ns.BossCalls = ns.BossCalls or {}
local C = ns.BossCalls

local RED, GREEN, ORANGE, BLUE, PURPLE = { 1, 0.2, 0.2, 1 }, { 0.3, 0.9, 0.3, 1 }, { 1, 0.55, 0.1, 1 }, { 0.25, 0.6, 1, 1 }, { 0.7, 0.4, 1, 1 }
local MYTHIC = { [16] = true }

-- Nymrissa Wavecaller
C[3379] = {
    [1276710] = { say = "Adds", voice = true },
    [1257717] = { say = "Bubbles on players", lead = 4 },
    [1258668] = { say = "Waves, knockback after", voice = "Dodge", bar = true, color = BLUE },
    [1260837] = { say = "Raid damage", who = "healer" },
    [1282937] = { say = "Tank hit", who = "threat", color = RED, taunt = true },
    [1268562] = { say = "Frontal", who = "nontank", color = RED, taunt = true, diff = MYTHIC },
    [1313393] = { say = "Frost debuffs" },
}
-- Sszorak
C[3420] = {
    [1285732] = { say = "Maelstrom", voice = true, bar = true, lead = 8, color = PURPLE },
    [1277025] = { say = "Tank combo", who = "tank", color = RED, taunt = true },
    [1305959] = { say = "Bait the surge", voice = "Bait", color = ORANGE },
    [1285425] = { say = "Wind debuffs" },
}
-- Vashnik the Malignant
C[3455] = {
    [1283164] = { say = "Adds", voice = true },
    [1282525] = { say = "Raid damage, soaks next", voice = "Soak soon", color = ORANGE },
    [1281907] = { say = "Spread for waves", voice = "Spread", color = BLUE, lead = 6 },
    [1280935] = { say = "Tank hit", who = "threat", color = RED, taunt = true },
    [1282117] = { say = "Infection debuffs" },
}
-- Nek'zali the Soulcoiler
C[3470] = {
    [1285681] = { say = "Raid damage", who = "healer" },
    [1287426] = { say = "Rend debuffs" },
    [1295397] = { say = "Adds" },
    [1287533] = { say = "Boss advances, move" },
    [1292036] = { say = "Frontal", who = "nontank", color = RED },
    [1293212] = { say = "Depths: watch your feet" },
    [1305421] = { say = "Soak the pyre", voice = "Soak", bar = true, color = ORANGE },
    [1299673] = { say = "Dodge", voice = true, color = BLUE },
}
-- Entombed Sentinels
C[3445] = {
    [1284588] = { say = "Intermission: spread", voice = "Spread", bar = true, lead = 6, color = PURPLE },
    [1296878] = { say = "Spread", voice = true, color = BLUE },
    [1284251] = { say = "Poison add" },
    [1284434] = { say = "Bait the orbs", voice = "Bait", color = ORANGE },
    [1284458] = { say = "Tank hit", who = "threat", color = RED, taunt = true },
    [1284483] = { say = "Dispels", who = "healer", color = GREEN },
    [1288232] = { say = "Blood soak", voice = "Soak", color = ORANGE },
    [1284487] = { say = "Tank hit, drop the pool", who = "threat", color = RED, taunt = true },
}
-- The Twin Fangs
C[3421] = {
    [1308556] = { say = "Boss submerges" },
    [1289192] = { say = "Knockback", voice = true, color = BLUE },
    [1290809] = { say = "Spread", voice = true, color = BLUE },
    [1291404] = { say = "Adds", voice = true },
    [1290516] = { say = "Soak", voice = true, bar = true, lead = 8, color = ORANGE },
    [1303230] = { say = "Blood torrent", diff = MYTHIC },
    [1290956] = { say = "Defensives", voice = true, color = RED },
    [1288538] = { say = "Tank soak", who = "tank", voice = "Soak", bar = true, lead = 8, color = ORANGE },
    [1306872] = { say = "Storm: watch your side", voice = "Watch side" },
    [1294293] = { say = "Flood: watch your side", voice = "Watch side" },
    [1308356] = { say = "Adds", voice = true, diff = MYTHIC },
}
-- The Coiled Altar
C[3429] = {
    [1299960] = { say = "Raid damage", who = "healer" },
    [1283832] = { say = "Frontal", voice = true, who = "nontank", color = RED },
    [1282281] = { say = "Tank hit", who = "threat", color = RED, taunt = true },
    [1283489] = { say = "Soak", voice = true, color = ORANGE },
    [1299680] = { say = "Sever debuffs" },
    [1282487] = { say = "Orbs", voice = true, bar = true, color = PURPLE },
    [1289900] = { say = "Mind controls", color = PURPLE },
    [1286918] = { say = "Break the shield", voice = "Shield", bar = true, color = PURPLE },
    [1286441] = { say = "Interrupt the ghosts", voice = "Interrupt", color = GREEN },
    [1286895] = { say = "Bomb debuffs" },
    [1286573] = { say = "Tank hit", who = "threat", color = RED, taunt = true },
    [1298381] = { say = "Orbs", voice = true, bar = true, color = PURPLE },
    [1299266] = { say = "Soak", voice = true, color = ORANGE },
    [1307279] = { say = "Tank hit", who = "threat", color = RED, taunt = true },
}
-- The Lost Explorers
C[3497] = {
    [1292779] = { say = "Ascension", voice = true, color = PURPLE },
    [1290711] = { say = "Blink nova", color = BLUE },
    [1286921] = { say = "Flames" },
    [1295854] = { say = "Tank hit", who = "threat", color = RED, taunt = true },
    [1295886] = { say = "Volley debuffs" },
    [1291759] = { say = "Bait the spin", voice = "Bait", color = ORANGE },
    [1296092] = { say = "Soaks", voice = "Soak", bar = true, lead = 8, color = ORANGE },
    [1291933] = { say = "Junk incoming" },
    [1295817] = { say = "Fish" },
    [1292104] = { say = "Bait the mushroom", color = ORANGE },
    [1296249] = { say = "Bomb debuff", color = RED },
}
-- Ula'tek
C[3492] = {
    [1292188] = { say = "Waves", voice = true, color = BLUE },
    [1300751] = { say = "Adds", voice = true },
    [1298367] = { say = "Hit and knockback", voice = "Knock", color = RED },
    [1298559] = { say = "Rattle" },
    [1296301] = { say = "Sweep", color = BLUE },
    [1300530] = { say = "Coils" },
    [1292999] = { say = "Boss submerges" },
    [1286860] = { say = "Damage amp soon", bar = true, color = PURPLE },
    [1310738] = { say = "Eggs" },
    [1299757] = { say = "Eggs" },
    [1302982] = { say = "Spit debuffs" },
    [1290779] = { say = "Malice" },
    [1301117] = { say = "Fangs" },
    [1301510] = { say = "Platform breaks", voice = "Move", bar = true, color = PURPLE },
    [1300635] = { say = "Boss submerges" },
    [1295905] = { say = "Tank hit", who = "threat", color = RED, taunt = true },
    [1286905] = { say = "Raid damage", voice = "Defensives", color = RED },
}
-- Kith'ix
C[3513] = {
    [1301511] = { say = "Adds", voice = true },
    [1303681] = { say = "Tentacle" },
    [1304930] = { say = "Tank hit", who = "threat", color = RED, taunt = true },
    [1304424] = { say = "Get an orb", voice = "Orb", color = ORANGE },
    [1304508] = { say = "Light" },
    [1304045] = { say = "Horrors" },
    [1302951] = { say = "Darkness", voice = true, color = PURPLE },
    [1303169] = { say = "Radiance" },
    [1303406] = { say = "Grasp" },
    [1308873] = { say = "Gate" },
    [1318467] = { say = "Negation", color = RED },
    [1301479] = { say = "Eclipse", voice = true, bar = true, lead = 8, color = PURPLE },
}

---------------------------------------------------------------------------
local LEAD, TAUNT_AFTER = 5, 0.5
local function Key(encounter, spell) return tostring(encounter) .. ":" .. tostring(spell) end
function ns.BossCallSettings()
    local s = ns.Settings and ns.Settings() or {}
    return s.bossCalls ~= false, s.bossCallsVoice ~= false, s.bossCallsOff or {}
end
function ns.BossCallFor(encounter, spell)
    local boss = C[tonumber(encounter)]
    return boss and boss[tonumber(spell)]
end
-- The timeline spell a planner ability stands for: the same ID, or a timeline spell with the
-- same journal name (the journal sometimes lists another ID of the same ability).
function ns.BossCallSpell(encounter, spell)
    encounter, spell = tonumber(encounter), tonumber(spell)
    if not encounter or not spell or not C[encounter] then return nil end
    if C[encounter][spell] then return spell end
    local name = ns.AbilityName and ns.AbilityName(spell, encounter)
    if not ns.Plain(name, "string") or name == "" then return nil end
    for _, id in ipairs(ns.BossTimerSpells and ns.BossTimerSpells[encounter] or {}) do
        if C[encounter][id] and ns.AbilityName(id, encounter) == name then return id end
    end
end
local function Role()
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    return ns.Plain(role, "string") and role or nil
end
-- nil when the game hides it.
local function HasThreat()
    if not UnitThreatSituation then return nil end
    local ok, s = pcall(UnitThreatSituation, "player", "boss1")
    if not ok or not ns.Plain(s, "number") then return nil end
    return s >= 2
end
local function ForMe(call)
    local who, role = call.who, Role()
    if not who then return true end
    if who == "tank" then return role == "TANK" end
    if who == "nontank" then return role ~= "TANK" or HasThreat() ~= false end
    if who == "threat" then return role == "TANK" and HasThreat() ~= false end
    if who == "healer" then return role == "HEALER" end
    if who == "damager" then return role == "DAMAGER" end
    return true
end
-- A reminder of your own with a text alert on the same spell replaces the built-in call.
local function Authored(encounter, spell)
    local profile = ns.Active()
    for _, entry in pairs(profile and ns.EncounterEntries(profile, encounter) or {}) do
        local t, d = entry.trigger or {}, entry.display or {}
        if entry.enabled ~= false and t.spellID == spell and (entry.alert ~= nil or d.type == "ability") then return true end
    end
    return false
end
local function Show(spell, call, seconds, text, color, voice)
    local _, speak = ns.BossCallSettings()
    voice = speak and voice or nil
    ns.Display({ type = "ability", spellID = spell, text = text, style = call.bar and "bar" or "text", dur = seconds,
        textColor = color, barColor = call.bar and color or nil, tts = voice ~= nil, ttsText = type(voice) == "string" and voice or text, sticky = call.sticky })
end
-- Called by ns.Mechanic for every bar start (duration) and cast message (no duration).
function ns.BossCall(spell, duration, identity, encounter)
    local on, _, off = ns.BossCallSettings()
    if not on or not encounter then return end
    local call = ns.BossCallFor(encounter, spell)
    if not call or off[Key(encounter, spell)] then return end
    if call.diff and not call.diff[ns.difficulty or 0] then return end
    if Authored(encounter, spell) then return end
    local key = "ability:" .. tostring(identity or spell) .. ":call"
    if duration then
        local lead = math.min(call.lead or LEAD, duration)
        ns.Schedule(key, math.max(0, duration - lead), function()
            if ForMe(call) then Show(spell, call, lead, call.say, call.color, call.voice == true and call.say or call.voice) end
        end)
    elseif call.taunt then
        ns.Schedule("message:" .. tostring(identity or spell) .. ":taunt", TAUNT_AFTER, function()
            if Role() == "TANK" and HasThreat() ~= true then Show(355, { sticky = 3 }, 4, "Taunt", GREEN, "Taunt") end
        end)
    end
end
function ns.SetBossCallEnabled(encounter, spell, on)
    return ns.EditProfile(function(data)
        assert(ns.BossCallFor(encounter, spell), "No built-in call for that spell")
        data.settings = data.settings or {}
        local off = data.settings.bossCallsOff or {}
        off[Key(encounter, spell)] = (not on) or nil
        data.settings.bossCallsOff = next(off) and off or nil
        return true
    end)
end
-- /ndp bosscalls: the calls of one boss (current pull, or a name or encounter ID).
function ns.BossCallsText(which)
    local wanted = tonumber(which)
    if not wanted and which and which ~= "" then
        local needle = which:lower()
        for id, boss in pairs(ns.BossTimers or {}) do if boss.name and boss.name:lower():find(needle, 1, true) then wanted = id end end
    end
    wanted = wanted or ns.encounter
    local on, voice, off = ns.BossCallSettings()
    local lines = { "Built-in boss calls: " .. (on and "on" or "off") .. ", voice " .. (voice and "on" or "off") }
    local order = wanted and { wanted } or ns.BossTimerOrder or {}
    for _, id in ipairs(order) do
        local boss = C[id]
        if boss then
            lines[#lines + 1] = ""
            lines[#lines + 1] = (ns.BossTimers[id] and ns.BossTimers[id].name or tostring(id)) .. " (" .. id .. ")"
            for _, spell in ipairs(ns.BossTimerSpells and ns.BossTimerSpells[id] or {}) do
                local call = boss[spell]
                if call then
                    local name = ns.AbilityName and ns.AbilityName(spell, id) or tostring(spell)
                    local extra = {}
                    if call.who then extra[#extra + 1] = call.who end
                    if call.voice then extra[#extra + 1] = "says \"" .. (call.voice == true and call.say or call.voice) .. "\"" end
                    if call.bar then extra[#extra + 1] = "bar" end
                    if call.taunt then extra[#extra + 1] = "taunt call" end
                    if call.diff then extra[#extra + 1] = "Mythic only" end
                    lines[#lines + 1] = string.format("  %s %s (%d): %s%s", off[Key(id, spell)] and "[off]" or "[on] ", tostring(name), spell, call.say, #extra > 0 and "  ·  " .. table.concat(extra, ", ") or "")
                end
            end
        end
    end
    return table.concat(lines, "\n")
end
