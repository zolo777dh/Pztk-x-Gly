-- Boss abilities from the game's own Encounter Journal: the raids and dungeons of the current
-- season, each boss with its journal abilities (name, icon, spell ID, role and dispel flags)
-- per difficulty. The journal is read out of combat, when the window opens, and kept per game
-- client and build, so NDP needs no ability lists from other addons. The raid list, the
-- ability names and icons and the category strip on the Timeline all come from here; the
-- built-in timer scripts (BossTimerData.lua) add the spells they announce.
local _, ns = ...
local L = ns.L

-- Journal icon flags are indices: 0 tank, 1 damage, 2 healer, 3 heroic, 4 deadly, 5 important,
-- 6 interruptible, 7 magic, 8 curse, 9 poison, 10 disease, 11 enrage, 12 mythic, 13 bleed.
local flagCategory = { [0] = "tank", [2] = "raid", [11] = "buff", [6] = "interrupt",
    [7] = "dispel", [8] = "dispel", [9] = "dispel", [10] = "dispel", [13] = "dispel" }
-- The category strip prefers the most specific flag.
local categoryOrder = { "tank", "interrupt", "dispel", "buff", "raid" }
ns.JournalFlags = flagCategory

local function Build()
    local _, build = GetBuildInfo()
    return tostring(build or "")
end
local function Call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d, e, f, g, h, i, j, k = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h, i, j, k end
end
local function Number(v) return ns.Plain(v, "number") and v or nil end
local function Text(v) return ns.Plain(v, "string") and v ~= "" and v or nil end

-- Every ability section of one boss under the selected difficulty: a depth-first walk of the
-- journal tree, siblings after children. Sections hidden for the difficulty are left out.
local function Sections(root)
    local out, stack, seen, steps = {}, { root }, {}, 0
    local get = C_EncounterJournal and C_EncounterJournal.GetSectionInfo
    local flags = C_EncounterJournal and C_EncounterJournal.GetSectionIconFlags
    while #stack > 0 and steps < 600 do
        steps = steps + 1
        local id = table.remove(stack)
        if Number(id) and not seen[id] then
            seen[id] = true
            local info = Call(get, id)
            if ns.Plain(info, "table") then
                if Number(info.siblingSectionID) then stack[#stack + 1] = info.siblingSectionID end
                if Number(info.firstChildSectionID) then stack[#stack + 1] = info.firstChildSectionID end
                local spell = Number(info.spellID)
                if spell and spell > 0 and info.filteredByDifficulty ~= true then
                    local list = {}
                    local raw = Call(flags, id)
                    if ns.Plain(raw, "table") then for _, f in ipairs(raw) do if Number(f) then list[#list + 1] = f end end end
                    out[#out + 1] = { id = spell, name = Text(info.title), icon = Number(info.abilityIcon), flags = list }
                end
            end
        end
    end
    return out
end

local function Encounters(instance, difficulties)
    local bosses = {}
    for i = 1, 30 do
        local name, _, journalID, root, _, _, encounterID = Call(EJ_GetEncounterInfoByIndex, i, instance)
        if not Text(name) then break end
        local boss = { id = Number(encounterID), journal = Number(journalID), name = name, abilities = {} }
        if boss.id and Number(root) then
            local byID = {}
            for _, diff in ipairs(difficulties) do
                if diff.id then Call(EJ_SetDifficulty, diff.id) end
                for _, a in ipairs(Sections(root)) do
                    local have = byID[a.id]
                    if not have then
                        have = { id = a.id, name = a.name, icon = a.icon, flags = a.flags, difficulties = {} }
                        byID[a.id] = have; boss.abilities[#boss.abilities + 1] = have
                    end
                    if diff.key then have.difficulties[#have.difficulties + 1] = diff.key end
                end
            end
            for _, a in ipairs(boss.abilities) do if #a.difficulties == 0 then a.difficulties = nil end end
            bosses[#bosses + 1] = boss
        end
    end
    return bosses
end

-- Reads the journal; returns true when it was read. The player's own journal tier, instance
-- and difficulty are put back afterwards.
function ns.ScanJournal(force)
    if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex and EJ_GetEncounterInfoByIndex and C_EncounterJournal) then return false end
    if InCombatLockdown and InCombatLockdown() or ns.encounter then return false end
    local store = ns.Store()
    if not force and store.journal and store.journal.build == Build() then return true end
    if EncounterJournal and EncounterJournal.IsShown and EncounterJournal:IsShown() then return false end
    local tiers = Number(Call(EJ_GetNumTiers)) or 0
    if tiers == 0 then return false end
    local oldTier, oldDiff = Call(EJ_GetCurrentTier), Call(EJ_GetDifficulty)
    local oldInstance = EncounterJournal and Number(EncounterJournal.instanceID)
    local raids, dungeons, seenRaid, seenBoss = {}, {}, {}, {}
    -- The last tier is the current season (or the newest expansion); the one before it holds
    -- the expansion's other raids of this season.
    for tier = tiers, math.max(1, tiers - 1), -1 do
        Call(EJ_SelectTier, tier)
        for _, raid in ipairs({ true, false }) do
            for i = 1, 30 do
                local instance, name, _, _, _, _, _, _, _, _, mapID = Call(EJ_GetInstanceByIndex, i, raid)
                if not Number(instance) then break end
                if not seenRaid[instance] then
                    seenRaid[instance] = true
                    Call(EJ_SelectInstance, instance)
                    local diffs = raid and { { id = 15, key = "heroic" }, { id = 16, key = "mythic" } } or { { id = 23 } }
                    local bosses = {}
                    for _, b in ipairs(Encounters(instance, diffs)) do
                        if not seenBoss[b.id] then seenBoss[b.id] = true; bosses[#bosses + 1] = b end
                    end
                    if #bosses > 0 then
                        local list = raid and raids or dungeons
                        list[#list + 1] = { id = "ej:" .. instance, instance = instance, mapID = Number(mapID), name = Text(name) or (L("Instance") .. " " .. instance), bosses = bosses }
                    end
                end
            end
        end
    end
    if Number(oldTier) then Call(EJ_SelectTier, oldTier) end
    if oldInstance then Call(EJ_SelectInstance, oldInstance) end
    if Number(oldDiff) then Call(EJ_SetDifficulty, oldDiff) end
    store.journal = { build = Build(), at = time and time() or 0, raids = raids, dungeons = dungeons }
    ns.journalIndex, ns.raidGroups = nil, nil
    return true
end

function ns.Journal()
    local j = ns.Store().journal
    return ns.Plain(j, "table") and j or nil
end
-- Lookups by spell ID and by lower-case name, built once per scan.
local function Index()
    if ns.journalIndex then return ns.journalIndex end
    local index = { spell = {}, name = {}, boss = {} }
    local j = ns.Journal()
    for _, list in ipairs({ j and j.raids or {}, j and j.dungeons or {} }) do
        for _, g in ipairs(list) do for _, b in ipairs(g.bosses or {}) do
            index.boss[b.id] = b
            for _, a in ipairs(b.abilities or {}) do
                index.spell[a.id] = index.spell[a.id] or a
                if a.name then index.name[b.id .. ":" .. a.name:lower()] = index.name[b.id .. ":" .. a.name:lower()] or a end
            end
        end end
    end
    ns.journalIndex = index
    return index
end
function ns.JournalBoss(encounter) return Index().boss[tonumber(encounter)] end
-- The journal ability behind a spell ID: the same ID, or (on a boss) the same name, since boss
-- timers often announce a different spell ID than the journal shows.
function ns.JournalAbility(spell, encounter)
    local index = Index()
    if index.spell[spell] then return index.spell[spell] end
    if encounter and ns.SpellLabel then
        local label = ns.SpellLabel(spell)
        if type(label) == "string" then return index.name[tonumber(encounter) .. ":" .. label:lower()] end
    end
end
function ns.AbilityCategory(spell, encounter)
    local a = ns.JournalAbility(spell, encounter)
    if not a or not a.flags then return nil end
    local have = {}
    for _, f in ipairs(a.flags) do if flagCategory[f] then have[flagCategory[f]] = true end end
    for _, c in ipairs(categoryOrder) do if have[c] then return c end end
end
function ns.AbilityIcon(spell, encounter)
    local a = ns.JournalAbility(spell, encounter)
    return a and a.icon
end
function ns.AbilityName(spell, encounter)
    local a = ns.JournalAbility(spell, encounter)
    return a and a.name
end

-- Raid groups for the planner: the journal's raids, each boss listing the spells its built-in
-- timer script announces first, then its journal abilities. Without a journal read yet, the
-- bosses with built-in timers form one group.
local function Merge(boss, encounter)
    local seen, out = {}, {}
    for _, spell in ipairs(ns.BossTimerSpells and ns.BossTimerSpells[encounter] or {}) do
        if not seen[spell] then seen[spell] = true; out[#out + 1] = { id = spell } end
    end
    local names = {}
    for _, a in ipairs(out) do local label = ns.SpellLabel and ns.SpellLabel(a.id); if type(label) == "string" then names[label:lower()] = true end end
    for _, a in ipairs(boss and boss.abilities or {}) do
        if not seen[a.id] and not (a.name and names[a.name:lower()]) then seen[a.id] = true; out[#out + 1] = { id = a.id, name = a.name, difficulties = a.difficulties } end
    end
    return out
end
function ns.RaidGroups()
    if ns.raidGroups then return ns.raidGroups end
    local out, listed = {}, {}
    local j = ns.Journal()
    for _, g in ipairs(j and j.raids or {}) do
        local group = { id = g.id, name = g.name, bosses = {} }
        for _, b in ipairs(g.bosses or {}) do
            listed[b.id] = true
            group.bosses[#group.bosses + 1] = { id = b.id, name = b.name, abilities = Merge(b, b.id) }
        end
        out[#out + 1] = group
    end
    local builtin = { id = "builtin", name = L("Raid bosses"), bosses = {} }
    for _, encounter in ipairs(ns.BossTimerOrder or {}) do
        if not listed[encounter] then
            local script = ns.BossTimers and ns.BossTimers[encounter]
            builtin.bosses[#builtin.bosses + 1] = { id = encounter, name = script and script.name or (L("Encounter") .. " " .. encounter), abilities = Merge(nil, encounter) }
        end
    end
    if #builtin.bosses > 0 then out[#out + 1] = builtin end
    ns.raidGroups = out
    return out
end
-- Dungeon bosses keep their catalog abilities and gain the journal's.
function ns.JournalDungeonAbilities(encounter)
    local b = ns.JournalBoss(encounter)
    return b and b.abilities or {}
end

-- Base timeline before your own pull: the median of public kills on Warcraft Logs
-- (LogTimelines.lua, built by tools/build-wcl-timelines.mjs), in the recorded-timeline shape.
-- Normal and LFR use the Heroic times.
function ns.ExpectedTimeline(encounter, difficulty)
    local boss = ns.LogTimelines and ns.LogTimelines[tonumber(encounter)]
    local data = boss and (boss[difficulty] or ((difficulty == 14 or difficulty == 17) and boss[15]))
    if not data or not data.events or #data.events == 0 then return nil end
    local phases = {}
    for _, p in ipairs(data.phases or {}) do phases[#phases + 1] = { name = p.name, at = p.at } end
    return { events = data.events, length = data.length, phases = phases, kills = data.kills, expected = true }
end
