-- Independent runtime. Imported profiles are data; no profile Lua is executed.
local _, ns = ...
_G.PztkReminders = ns
ns.version = "0.1.0"
ns.timers, ns.occurrences, ns.generation = {}, {}, 0
function ns.Plain(value, kind)
    return not (issecretvalue and issecretvalue(value)) and (not kind or type(value) == kind)
end
function ns.Get(t, key)
    if type(t) ~= "table" or key == nil then return nil end
    return t[key] or t[tostring(key)] or (tonumber(key) and t[tonumber(key)])
end
function ns.Conflict()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if loaded then
        for _, name in ipairs({ "NaowhSmartReminders", "NorthernSkyRaidTools", "TimelineReminders" }) do
            if loaded(name) then return name end
        end
    end
end
function ns.Active()
    local store = ns.Store and ns.Store()
    return store and store.profiles[store.active]
end
function ns.Spec()
    local get = GetSpecialization or (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization)
    local info = GetSpecializationInfo or (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo)
    if not get or not info then return nil end
    local index = get()
    local spec = index and info(index)
    return ns.Plain(spec, "number") and spec or nil
end
function ns.Target(t)
    if type(t) ~= "table" or t.all then return true end
    if t.matchAny then
        local tested = false
        for _, key in ipairs({ "roles", "specs", "classes", "names", "subgroups" }) do
            if type(t[key]) == "table" and next(t[key]) then
                tested = true
                if ns.Target({ [key] = t[key] }) then return true end
            end
        end
        return not tested
    end
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    if t.roles and next(t.roles) and (not ns.Plain(role) or not t.roles[role]) then return false end
    if t.specs and next(t.specs) and not ns.Get(t.specs, ns.Spec()) then return false end
    if t.classes and next(t.classes) then
        local _, class = UnitClass("player")
        if not ns.Plain(class) or not t.classes[class] then return false end
    end
    if t.names and next(t.names) then
        local name, realm
        if UnitFullName then name, realm = UnitFullName("player") end
        name = name or UnitName("player")
        realm = realm or (GetRealmName and GetRealmName())
        if not ns.Plain(name) or not ns.Plain(realm) then return false end
        local full = name and realm and (name .. "-" .. realm:gsub("%s+", ""))
        if not t.names[name] and not (full and t.names[full]) then return false end
    end
    if t.subgroups and next(t.subgroups) then
        local group = 1
        for i = 1, 40 do
            local name, _, subgroup = GetRaidRosterInfo(i)
            if name and UnitIsUnit(name, "player") then group = subgroup; break end
        end
        if not ns.Get(t.subgroups, group) then return false end
    end
    return true
end
function ns.Difficulty(entry)
    if not entry.difficulties or not next(entry.difficulties) then return true end
    return ns.Get(entry.difficulties, ns.difficulty) == true
end
function ns.Cancel(prefix)
    local keys = {}
    for key in pairs(ns.timers) do if not prefix or key:sub(1, #prefix) == prefix then keys[#keys + 1] = key end end
    for _, key in ipairs(keys) do
        local timer = ns.timers[key]
        ns.timers[key] = nil
        if timer and timer.Cancel then timer:Cancel() end
    end
end
function ns.Schedule(key, delay, callback)
    if ns.timers[key] and ns.timers[key].Cancel then ns.timers[key]:Cancel() end
    ns.timers[key] = nil
    local generation, profile = ns.generation, ns.Active()
    local timer
    timer = C_Timer.NewTimer(math.max(0.01, delay), function()
        if ns.timers[key] ~= timer then return end
        ns.timers[key] = nil
        if generation == ns.generation and profile == ns.Active() and not ns.Conflict() then callback() end
    end)
    ns.timers[key] = timer
end
function ns.Fire(entry)
    if ns.Conflict() or entry.enabled == false or not ns.Difficulty(entry) or not ns.Target(entry.target) then return end
    if ns.Display then ns.Display(entry.display or {}) end
end
function ns.Reset()
    ns.Cancel(); ns.generation = ns.generation + 1; ns.occurrences = {}; ns.encounter = nil; ns.phase = nil
    if ns.HideDisplays then ns.HideDisplays() end
end
function ns.Anchor(kind, phase)
    local p = ns.Active()
    local entries = p and ns.Get(p.data.raidReminders, ns.encounter)
    for key, entry in pairs(entries or {}) do
        local trigger = entry.trigger or {}
        if trigger.type == kind and (kind ~= "stage" or trigger.stage == phase) then
            local delay = tonumber(trigger.delay) or 0
            local lead = tonumber(trigger.leadTime) or 0
            ns.Schedule(kind .. ":" .. tostring(key), math.max(0, delay - lead), function() ns.Fire(entry) end)
        end
    end
end
function ns.Begin(encounter, difficulty, map)
    if not ns.Plain(encounter, "number") or not ns.Plain(difficulty, "number") then return end
    ns.Reset(); ns.encounter, ns.difficulty, ns.map, ns.phase = encounter, difficulty, map, 1
    ns.Anchor("pull"); ns.Anchor("stage", 1)
end
function ns.Phase(phase)
    if not ns.Plain(phase, "number") or phase == ns.phase or not ns.encounter then return end
    ns.Cancel("stage:"); ns.phase = phase; ns.Anchor("stage", phase)
end
local function Ready(spell)
    local known = C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell
    if known then local ok, value = pcall(known, spell); if not ok or not ns.Plain(value, "boolean") or not value then return false end end
    if C_Spell and C_Spell.GetSpellCharges then
        local ok, charges = pcall(C_Spell.GetSpellCharges, spell)
        if ok and charges and ns.Plain(charges) and ns.Plain(charges.currentCharges, "number") then return charges.currentCharges > 0 end
    end
    local start, duration, enabled
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, cd = pcall(C_Spell.GetSpellCooldown, spell)
        if not ok or not cd or not ns.Plain(cd) then return false end
        start, duration, enabled = cd.startTime, cd.duration, cd.isEnabled
    elseif GetSpellCooldown then
        local ok
        ok, start, duration, enabled = pcall(GetSpellCooldown, spell)
        if not ok then return false end
    else return false end
    if not ns.Plain(start, "number") or not ns.Plain(duration, "number") or not ns.Plain(enabled) then return false end
    if enabled == false or enabled == 0 then return false end
    return start == 0 or start + duration <= GetTime() or duration <= 1.5
end
function ns.Pick(preset)
    if not preset then return {} end
    local together, ready, result = {}, true, {}
    for _, spell in ipairs(preset.list or {}) do
        if ns.Get(preset.together, spell) then together[#together + 1] = spell; if not Ready(spell) then ready = false end end
    end
    for _, spell in ipairs(preset.list or {}) do
        if ns.Get(preset.together, spell) then if ready and #together > 0 then return together end
        elseif Ready(spell) then result[1] = spell; return result end
    end
    return result
end
function ns.Defensive(binding, lead, key)
    local profile, spec = ns.Active(), ns.Spec()
    if not profile or binding.enabled == false or not spec then return end
    ns.Schedule(key, math.max(0, lead), function()
        local presetKey = binding.preset or ns.Get(profile.data.activePreset, spec)
        local preset = ns.Get(ns.Get(profile.data.presets, spec), presetKey)
        local spells = ns.Pick(preset)
        if #spells > 0 and ns.Display then ns.Display({type="icon",spells=spells,spellID=spells[1],text=binding.display and binding.display.text or "Use defensive",dur=binding.display and binding.display.dur or 5,sound=binding.sound}) end
    end)
end
function ns.Mechanic(spell, duration, identity, encounter)
    if not ns.Plain(spell, "number") or (duration ~= nil and not ns.Plain(duration, "number")) then return end
    if ns.Conflict() or not ns.Plain(identity) or not ns.Plain(encounter) then return end
    local profile, spec = ns.Active(), ns.Spec()
    if not profile then return end
    encounter = encounter or ns.encounter
    local prefix = "ability:" .. tostring(identity or spell) .. ":"
    ns.Cancel(prefix)
    local binding = ns.Get(ns.Get(ns.Get(profile.data.abilityBindings, spec), encounter), spell)
    if binding then ns.Defensive(binding, duration and math.max(0, duration - (binding.leadTime or 3)) or 0, prefix .. "defensive") end
    for key, entry in pairs(ns.Get(profile.data.raidReminders, encounter) or {}) do
        local trigger = entry.trigger or {}
        if trigger.spellID == spell and ((duration and trigger.type == "bwtimer") or (not duration and trigger.type == "bwmsg")) then
            ns.Schedule(prefix .. tostring(key), duration and math.max(0, duration - (trigger.leadTime or 3)) or 0, function() ns.Fire(entry) end)
        end
    end
end
function ns.Trash(spell, remaining, identity)
    if not ns.Plain(spell, "number") or not ns.Plain(remaining, "number") or ns.Conflict() then return end
    local p, spec = ns.Active(), ns.Spec()
    if not p then return end
    for key, rule in pairs(ns.Get(p.data.integrationRules, spec) or {}) do
        local trigger = rule.trigger or {}
        if trigger.type == "exboss" and trigger.spellID == spell and trigger.mapID == ns.map then
            ns.Defensive(rule, math.max(0, remaining - (trigger.timeleft or 3)), "trash:" .. tostring(identity or spell) .. ":" .. tostring(key))
        end
    end
end
