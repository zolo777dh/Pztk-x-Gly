-- Independent runtime. Imported profiles are data; no profile Lua is executed.
local _, ns = ...
_G.NaowhDefensivePlanner = ns
ns.version = "0.6.4"
ns.timers, ns.occurrences, ns.generation = {}, {}, 0
function ns.Plain(value, kind)
    return not (issecretvalue and issecretvalue(value)) and (not kind or type(value) == kind)
end
function ns.Get(t, key)
    if not ns.Plain(t, "table") or not ns.Plain(key) or (type(key) ~= "string" and type(key) ~= "number") then return nil end
    if t[key] ~= nil then return t[key] end
    if t[tostring(key)] ~= nil then return t[tostring(key)] end
    local numeric = tonumber(key)
    if numeric then return t[numeric] end
end
function ns.Conflict()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if loaded then
        for _, name in ipairs({ "NaowhSmartReminders", "NorthernSkyRaidTools", "TimelineReminders", "PztkReminders" }) do
            if loaded(name) then return name end
        end
    end
end
function ns.Active()
    local store = ns.Store and ns.Store()
    return store and store.profiles[store.active]
end
-- Class of each catalog specialization, read from its name ("Guardian Druid").
local classNames = { ["Death Knight"]="DEATHKNIGHT", ["Demon Hunter"]="DEMONHUNTER", Druid="DRUID", Evoker="EVOKER", Hunter="HUNTER", Mage="MAGE", Monk="MONK", Paladin="PALADIN", Priest="PRIEST", Rogue="ROGUE", Shaman="SHAMAN", Warlock="WARLOCK", Warrior="WARRIOR" }
function ns.SpecClass(spec)
    local label = ns.Catalog and ns.Catalog.specs[tonumber(spec)]
    if type(label) ~= "string" then return nil end
    for name, class in pairs(classNames) do if label:sub(-#name - 1) == " " .. name then return class end end
end
function ns.PlayerClass()
    if not UnitClass then return nil end
    local _, class = UnitClass("player")
    return ns.Plain(class, "string") and class or nil
end
-- Sets and reminders are edited only for the specializations of the logged-in class.
function ns.CanEditSpec(spec)
    local class, own = ns.SpecClass(spec), ns.PlayerClass()
    return not class or not own or class == own
end
function ns.OwnSpecs()
    local out = {}
    for id in pairs(ns.Catalog.specs) do if ns.CanEditSpec(id) then out[#out + 1] = id end end
    table.sort(out)
    return out
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
        if not ns.Plain(name) or not ns.Plain(realm) then return false end
        name = name or UnitName("player")
        realm = realm or (GetRealmName and GetRealmName())
        if not ns.Plain(name, "string") or not ns.Plain(realm, "string") then return false end
        local full = name and realm and (name .. "-" .. realm:gsub("%s+", ""))
        if not t.names[name] and not (full and t.names[full]) then return false end
    end
    if t.subgroups and next(t.subgroups) then
        local group = 1
        for i = 1, 40 do
            local name, _, subgroup = GetRaidRosterInfo(i)
            if ns.Plain(name, "string") and ns.Plain(subgroup, "number") then
                local isPlayer = UnitIsUnit("raid" .. i, "player")
                if ns.Plain(isPlayer, "boolean") and isPlayer then group = subgroup; break end
            end
        end
        if not ns.Get(t.subgroups, group) then return false end
    end
    return true
end
-- Dungeon difficulties: Normal, Heroic, Mythic, Mythic+, Timewalking, Follower and story dungeons.
ns.DungeonDifficulties={[1]=true,[2]=true,[8]=true,[23]=true,[24]=true,[150]=true,[205]=true}
function ns.InDungeon()
    return ns.instanceType=="party"or(ns.difficulty~=nil and ns.DungeonDifficulties[ns.difficulty]==true)
end
-- A dungeon reminder fires in every dungeon difficulty: a Mythic+ flag (8) from NSR or the
-- planner covers Normal, Heroic and Mythic too. Raid flags still pick Heroic or Mythic.
function ns.Difficulty(entry)
    if not entry.difficulties or not next(entry.difficulties) then return true end
    if ns.Get(entry.difficulties, ns.difficulty) == true then return true end
    if ns.InDungeon() then for diff, on in pairs(entry.difficulties) do if on == true and ns.DungeonDifficulties[tonumber(diff)] then return true end end end
    return false
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
function ns.Fire(entry, display)
    if (ns.ContentMatches and not ns.ContentMatches(entry))or (ns.Enabled and not ns.Enabled()) or ns.Conflict() or entry.enabled == false or not ns.Difficulty(entry) or not ns.Target(entry.target) then return end
    if entry.defensive and ns.RenderDefensive then return ns.RenderDefensive(entry)end
    if ns.Display then ns.Display(display or entry.display or {}) end
end
function ns.Reset()
    ns.Cancel(); ns.generation = ns.generation + 1; ns.occurrences = {}; ns.encounter = nil; ns.phase = nil
    if ns.ResetProviders then ns.ResetProviders() end
    if ns.SuspendAuraSounds then ns.SuspendAuraSounds()end
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
            ns.occurrences[entry]=(ns.occurrences[entry]or 0)+1
            if not ns.CounterMatches or ns.CounterMatches(trigger.counterGroups,ns.occurrences[entry])then ns.Schedule(kind .. ":" .. tostring(key), math.max(0, delay - lead), function() ns.Fire(entry) end)end
        end
    end
end
function ns.Begin(encounter, difficulty, map)
    if not ns.Plain(encounter, "number") or not ns.Plain(difficulty, "number") then ns.Reset(); return end
    local firstBars=ns.CaptureProviderTimers and ns.CaptureProviderTimers(encounter)
    ns.Reset(); ns.encounter, ns.difficulty, ns.map, ns.phase = encounter, difficulty, map, 1
    ns.Anchor("pull"); ns.Anchor("stage", 1)
    if ns.ReplayProviderTimers then ns.ReplayProviderTimers(firstBars) end
end
-- Pre-pull reminders run before ENCOUNTER_START, so the encounter comes from the
-- Encounter Journal pins on the player's map: only bosses this profile plans
-- pre-pull reminders for, nearest first when the map position is readable.
function ns.PullEncounter()
    local profile = ns.Active()
    if not profile then return nil, "no active profile" end
    local wanted = {}
    for encounter, entries in pairs(profile.data.raidReminders or {}) do
        for _, entry in pairs(entries) do
            if type(entry) == "table" and type(entry.trigger) == "table" and entry.trigger.type == "prepull" and entry.enabled ~= false then
                if tonumber(encounter) then wanted[tonumber(encounter)] = true end
                break
            end
        end
    end
    if not next(wanted) then return nil, "no pre-pull reminders in this profile" end
    if not (C_Map and C_Map.GetBestMapForUnit and C_EncounterJournal and C_EncounterJournal.GetEncountersOnMap and EJ_GetEncounterInfo) then return nil, "Encounter Journal map API unavailable" end
    local ok, uiMap = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or not ns.Plain(uiMap, "number") then return nil, "current map unknown" end
    local pins
    ok, pins = pcall(C_EncounterJournal.GetEncountersOnMap, uiMap)
    if not ok or not ns.Plain(pins, "table") then return nil, "no bosses on map " .. uiMap end
    local px, py
    if C_Map.GetPlayerMapPosition then
        local found, position = pcall(C_Map.GetPlayerMapPosition, uiMap, "player")
        if found and ns.Plain(position, "table") and position.GetXY then
            local x, y = position:GetXY()
            if ns.Plain(x, "number") and ns.Plain(y, "number") then px, py = x, y end
        end
    end
    local best, bestDistance, count = nil, nil, 0
    for _, pin in ipairs(pins) do
        if ns.Plain(pin, "table") and ns.Plain(pin.encounterID, "number") then
            local found, _, _, _, _, _, _, encounter = pcall(EJ_GetEncounterInfo, pin.encounterID)
            if found and ns.Plain(encounter, "number") and wanted[encounter] then
                count = count + 1
                local distance = 0
                if px and ns.Plain(pin.mapX, "number") and ns.Plain(pin.mapY, "number") then distance = (pin.mapX - px) ^ 2 + (pin.mapY - py) ^ 2 end
                if not best or distance < bestDistance then best, bestDistance = encounter, distance end
            end
        end
    end
    if not best then return nil, "no planned boss on map " .. uiMap end
    if count > 1 and not px then return nil, "several planned bosses on map " .. uiMap .. " and no player position" end
    return best
end
function ns.Countdown(remaining)
    ns.Cancel("prepull:")
    ns.pullEncounter, ns.pullStatus = nil, nil
    if not ns.Plain(remaining, "number") or remaining <= 0 or ns.encounter or ns.Conflict() then return end
    if ns.Enabled and not ns.Enabled() then return end
    if ns.RefreshContext then ns.RefreshContext() end
    local encounter, status = ns.PullEncounter()
    ns.pullEncounter, ns.pullStatus = encounter, status
    if not encounter then return end
    local pullAt = GetTime() + remaining
    for key, entry in pairs(ns.Get(ns.Active().data.raidReminders, encounter) or {}) do
        local trigger = type(entry) == "table" and entry.trigger or {}
        local before, lead = tonumber(trigger.delay) or 0, tonumber(trigger.leadTime) or 0
        if trigger.type == "prepull" and before > 0 and remaining > before then
            ns.Schedule("prepull:" .. tostring(key), math.max(0, remaining - before - lead), function()
                -- A countdown shorter than the lead time shows the reminder at once, for the time that is left.
                local left = pullAt - before - GetTime()
                if left <= 0 then return end
                local display = entry.display or {}
                if lead > 0 then
                    local copy = {}
                    for k, v in pairs(display) do copy[k] = v end
                    copy.dur = math.min(tonumber(display.dur) or 5, left)
                    display = copy
                end
                ns.Fire(entry, display)
            end)
        end
    end
end
function ns.Phase(phase)
    if not ns.Plain(phase, "number") or phase == ns.phase or not ns.encounter then return end
    ns.Cancel("stage:"); ns.phase = phase; ns.Anchor("stage", phase)
end
local function Ready(spell)
    local known=C_SpellBook and(C_SpellBook.IsSpellKnownOrInSpellBook or C_SpellBook.IsSpellKnown)or IsPlayerSpell
    if known then local ok,value=pcall(known,spell);if not ok or not ns.Plain(value,"boolean")or not value then return false end end
    if C_Spell and C_Spell.GetSpellCharges then
        local ok,charges=pcall(C_Spell.GetSpellCharges,spell)
        if not ok then return false end
        if ns.Plain(charges,"table")then
            local read,current,maximum=pcall(function()return charges.currentCharges,charges.maxCharges end)
            if not read then return false end
            if ns.Plain(current,"number")then return current>0 end
            -- A cooldown can be inactive at zero charges. Never substitute its state
            -- for an unreadable charge count or invent a recharge estimate.
            if not ns.Plain(current)or(ns.Plain(maximum,"number")and maximum>0)then return false end
        end
    end
    local start,duration,enabled,active,gcd
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok,cd=pcall(C_Spell.GetSpellCooldown,spell)
        if not ok or not ns.Plain(cd,"table")then return false end
        local read;read,enabled,active,gcd=pcall(function()return cd.isEnabled,cd.isActive,cd.isOnGCD end)
        if not read then return false end
        if ns.Plain(enabled)and(enabled==false or enabled==0)then return false end
        -- Public status flags answer without arithmetic on protected timestamps.
        if ns.Plain(active,"boolean")and ns.Plain(gcd)and(type(gcd)=="boolean"or gcd==nil)then return gcd==true or not active end
        if C_Spell.GetSpellCooldownDuration then
            local got,object=pcall(C_Spell.GetSpellCooldownDuration,spell,true)
            if got and ns.Plain(object)and object then
                local readZero,zero=pcall(function()return object:IsZero()end)
                if readZero and ns.Plain(zero,"boolean")then return zero end
            end
        end
        local readTimes;readTimes,start,duration=pcall(function()return cd.startTime,cd.duration end)
        if not readTimes then return false end
    elseif GetSpellCooldown then
        local ok;ok,start,duration,enabled=pcall(GetSpellCooldown,spell);if not ok then return false end
    else return false end
    if not ns.Plain(start,"number")or not ns.Plain(duration,"number")or not ns.Plain(enabled)then return false end
    if enabled==false or enabled==0 then return false end
    return start==0 or start+duration<=GetTime()or duration<=1.5
end
function ns.Pick(preset)
    if not preset then return {} end
    if preset.disabled then
        local filtered={list={},together=preset.together}
        for _,spell in ipairs(preset.list or{})do if not ns.Get(preset.disabled,spell)then filtered.list[#filtered.list+1]=spell end end
        preset=filtered
    end
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
function ns.Defensive(binding, lead, key, valid)
    local profile, spec = ns.Active(), ns.Spec()
    if not profile or binding.enabled == false or not spec then return end
    ns.Schedule(key, math.max(0, lead), function()
        if ns.Spec() ~= spec or (valid and not valid()) then return end
        if ns.RenderDefensive then return ns.RenderDefensive(binding,binding.trigger and binding.trigger.type=="exboss")end
        local presetKey = binding.preset or ns.Get(profile.data.activePreset, spec)
        local preset = ns.Get(ns.Get(profile.data.presets, spec), presetKey)
        local spells = ns.Pick(preset)
        if #spells > 0 and ns.Display then ns.Display({type="icon",spells=spells,spellID=spells[1],text=binding.display and binding.display.text or "Use defensive",dur=binding.display and binding.display.dur or 5,sound=binding.sound}) end
    end)
end
function ns.Mechanic(spell, duration, identity, encounter, skipDefensive, repeatEvent)
    if not ns.Plain(spell, "number") or (duration ~= nil and not ns.Plain(duration, "number")) then return end
    if ns.Conflict() or not ns.Plain(identity) or not ns.Plain(encounter) then return end
    local profile, spec = ns.Active(), ns.Spec()
    if not profile then return end
    if ns.Enabled and not ns.Enabled()then return end
    encounter = encounter or ns.encounter
    local prefix = "ability:" .. tostring(identity or spell) .. ":"
    if duration then ns.Cancel(prefix)
    else
        -- Each message occurrence owns its delayed reminders. A new occurrence
        -- must not cancel an older one that is still waiting for its delay.
        ns.occurrences[prefix]=(ns.occurrences[prefix]or 0)+1
        prefix="message:"..tostring(identity or spell)..":"..ns.occurrences[prefix]..":"
    end
    local binding = ns.Get(ns.Get(ns.Get(profile.data.abilityBindings, spec), encounter), spell)
    local entries=ns.Get(profile.data.raidReminders,encounter)or{}
    local authored=false
    for _,entry in pairs(entries)do if entry.defensive and entry.enabled~=false and entry.trigger.spellID==spell and ns.Target(entry.target)and ns.Difficulty(entry)and(not ns.ContentMatches or ns.ContentMatches(entry))then authored=true;break end end
    local defaults=profile.data.settings or{}
    if binding and ns.Difficulty(binding)and(not ns.ContentMatches or ns.ContentMatches(binding))and not skipDefensive and not authored and binding.mode~="custom" then ns.Defensive(binding, duration and math.max(0, duration - (binding.leadTime or profile.data.leadTime or defaults.leadTime or 3)) or 0, prefix .. "defensive") end
    for key, entry in pairs(entries) do
        local trigger = entry.trigger or {}
        if trigger.spellID == spell and entry.enabled~=false and ns.Target(entry.target) and ((duration and trigger.type == "bwtimer") or (not duration and trigger.type == "bwmsg")) then
            if not repeatEvent then ns.occurrences[entry]=(ns.occurrences[entry]or 0)+1 end
            local occurrence=ns.occurrences[entry]or 0
            if not ns.CounterMatches or ns.CounterMatches(trigger.counterGroups,occurrence)then
                local delay=(duration and math.max(0,duration-(trigger.leadTime or 3))or 0)+(trigger.delay or 0)
                ns.Schedule(prefix .. tostring(key),delay,function()ns.Fire(entry)end)
            end
        end
    end
end
function ns.Trash(spell, remaining, identity, valid)
    if not ns.Plain(spell, "number") or not ns.Plain(remaining, "number") or ns.Conflict() then return end
    local p, spec = ns.Active(), ns.Spec()
    if not p then return end
    for key, rule in pairs(ns.Get(p.data.integrationRules, spec) or {}) do
        local trigger = rule.trigger or {}
        if (not ns.ContentMatches or ns.ContentMatches(rule))and ns.Difficulty(rule)and trigger.type == "exboss" and trigger.spellID == spell and (trigger.mapID==0 or trigger.mapID == ns.map) then
            ns.Defensive(rule, math.max(0, remaining - (trigger.timeleft or 3)), "trash:" .. tostring(identity or spell) .. ":" .. tostring(key), valid and function() return valid(key) end)
        end
    end
end
