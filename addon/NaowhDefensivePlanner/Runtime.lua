-- Independent runtime. Imported profiles are data; no profile Lua is executed.
local _, ns = ...
_G.NaowhDefensivePlanner = ns
ns.version = "1.0.2"
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
        for _, name in ipairs({ "NaowhSmartReminders", "NorthernSkyRaidTools", "TimelineReminders", "PztkReminders", "PuzatikDefensivePlanner" }) do
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
-- Specializations of each class in the game's order, and the ones that fight in melee range.
ns.ClassSpecs={WARRIOR={71,72,73},PALADIN={65,66,70},HUNTER={253,254,255},ROGUE={259,260,261},PRIEST={256,257,258},DEATHKNIGHT={250,251,252},
    SHAMAN={262,263,264},MAGE={62,63,64},WARLOCK={265,266,267},MONK={268,270,269},DRUID={102,103,104,105},DEMONHUNTER={577,581,1480},EVOKER={1467,1468,1473}}
ns.MeleeSpecs={[250]=1,[251]=1,[252]=1,[577]=1,[581]=1,[103]=1,[104]=1,[255]=1,[268]=1,[270]=1,[269]=1,[65]=1,[66]=1,[70]=1,[259]=1,[260]=1,[261]=1,[263]=1,[71]=1,[72]=1,[73]=1}
-- All melee or all ranged specializations, the recipient list for "melee" / "ranged".
function ns.PositionSpecs(melee)
    local specs = {}
    for _, list in pairs(ns.ClassSpecs) do for _, id in ipairs(list) do if (ns.MeleeSpecs[id] ~= nil) == melee then specs[id] = true end end end
    return specs
end
-- occurrence is the cast number of the trigger, for rotations.
function ns.Target(t, occurrence)
    if type(t) ~= "table" or t.all then return true end
    if type(t.rotation) == "table" then
        local names = t.rotation.names or (ns.NoteList and ns.NoteList(t.rotation.note)) or {}
        if #names == 0 then return false end
        local n = math.max(1, tonumber(occurrence) or 1)
        return ns.IsMe and ns.IsMe(names[(n - 1) % #names + 1]) or false
    end
    if type(t.noteSlot) == "table" then
        local names = ns.NoteList and ns.NoteList(t.noteSlot.note) or {}
        return ns.IsMe and ns.IsMe(names[tonumber(t.noteSlot.index) or 1]) or false
    end
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
-- Boss ability alert of a reminder (entry.alert): a small ability icon and text on its own anchor,
-- shown next to whatever the reminder itself shows (usually a personal defensive), like NSR.
-- On a boss mod timer it counts down to the cast.
function ns.ShowAbilityAlert(entry)
    local alert=type(entry)=="table"and entry.alert
    if type(alert)~="table"or not ns.Display then return end
    local trigger=type(entry.trigger)=="table"and entry.trigger or{}
    local spell=alert.spellID or trigger.spellID or(type(entry.catalog)=="table"and entry.catalog.abilityID)
    local dur=trigger.type=="bwtimer"and math.max(1,(tonumber(trigger.leadTime)or 3)-(tonumber(trigger.delay)or 0))or(type(entry.display)=="table"and tonumber(entry.display.dur))or 4
    ns.Display({type="ability",spellID=spell,text=alert.text or"",style=alert.style,dur=dur,small=true,tts=false})
end
function ns.Fire(entry, display, occurrence)
    local why = ns.SkipReason and ns.SkipReason(entry, occurrence)
    if why then if ns.Trace then ns.Trace("skip", ns.TraceName(entry) .. "  ·  " .. why) end; return end
    if ns.Trace and not entry.defensive then ns.Trace("show", ns.TraceName(entry)) end
    ns.ShowAbilityAlert(entry)
    if entry.defensive and ns.RenderDefensive then return ns.RenderDefensive(entry)end
    display = display or entry.display or {}
    -- In dungeons every reminder is spoken unless "Speak every Mythic+ reminder" is off (Settings).
    local settings = ns.Settings and ns.Settings() or {}
    if display.tts == false and ns.instanceType == "party" and settings.mplusVoice ~= false and settings.voiceOn ~= false then
        local spoken = {}; for k, v in pairs(display) do spoken[k] = v end; spoken.tts = true; display = spoken
    end
    if ns.Display then ns.Display(display) end
end
function ns.Reset()
    ns.Cancel(); ns.generation = ns.generation + 1; ns.occurrences = {}; ns.encounter = nil; ns.phase = nil; ns.simulation = nil
    if ns.ResetProviders then ns.ResetProviders() end
    if ns.SuspendAuraSounds then ns.SuspendAuraSounds()end
    if ns.HideDisplays then ns.HideDisplays() end
    if ns.StopStateTriggers then ns.StopStateTriggers() end
end
-- Reminders of an encounter: the profile's, plus timers read from the active notes for this pull.
ns.noteEntries = {}
function ns.EncounterEntries(profile, encounter)
    local base = profile and ns.Get(profile.data.raidReminders, encounter)
    if not next(ns.noteEntries) or encounter ~= ns.noteEncounter then return base end
    local merged = {}
    for k, v in pairs(base or {}) do merged[k] = v end
    for k, v in pairs(ns.noteEntries) do merged[k] = v end
    return merged
end
function ns.Anchor(kind, phase)
    local p = ns.Active()
    local entries = ns.EncounterEntries(p, ns.encounter)
    for key, entry in pairs(entries or {}) do
        local trigger = entry.trigger or {}
        if trigger.type == kind and (kind ~= "stage" or trigger.stage == phase) then
            local delay = tonumber(trigger.delay) or 0
            local lead = tonumber(trigger.leadTime) or 0
            ns.occurrences[entry]=(ns.occurrences[entry]or 0)+1
            local occurrence=ns.occurrences[entry]
            if not ns.CounterMatches or ns.CounterMatches(trigger.counterGroups,occurrence)then ns.Schedule(kind .. ":" .. tostring(key), math.max(0, delay - lead), function() ns.Fire(entry, nil, occurrence) end)end
        end
    end
end
function ns.Begin(encounter, difficulty, map)
    if not ns.Plain(encounter, "number") or not ns.Plain(difficulty, "number") then ns.Reset(); return end
    local firstBars=ns.CaptureProviderTimers and ns.CaptureProviderTimers(encounter)
    ns.Reset(); ns.encounter, ns.difficulty, ns.map, ns.phase = encounter, difficulty, map, 1
    ns.pullTime, ns.recording = GetTime(), {}
    if ns.TraceStart then ns.TraceStart(encounter, difficulty) end
    ns.noteEntries, ns.noteEncounter = ns.NoteTimerEntries and ns.NoteTimerEntries(difficulty) or {}, encounter
    ns.Anchor("pull"); ns.Anchor("stage", 1)
    if ns.ReplayProviderTimers then ns.ReplayProviderTimers(firstBars) end
    if ns.StartBuiltinTimers then ns.StartBuiltinTimers() end
    if ns.StartStateTriggers then ns.StartStateTriggers() end
    if ns.StartPullLog then ns.StartPullLog() end
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
    ns.Cancel("stage:"); ns.phase = phase
    if ns.Trace then ns.Trace("phase", "phase " .. phase) end
    ns.Anchor("stage", phase)
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
ns.SpellReady = Ready
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
        if ns.Spec() ~= spec or (valid and not valid()) then if ns.Trace then ns.Trace("skip", ns.TraceName(binding) .. "  ·  specialization changed or the trash pack is gone") end; return end
        ns.ShowAbilityAlert(binding)
        if ns.RenderDefensive then return ns.RenderDefensive(binding,binding.trigger and binding.trigger.type=="exboss")end
        local presetKey = binding.preset or ns.Get(profile.data.activePreset, spec)
        local preset = ns.Get(ns.Get(profile.data.presets, spec), presetKey)
        local spells = ns.Pick(preset)
        if #spells > 0 and ns.Display then ns.Display({type="icon",defensive=true,spells=spells,spellID=spells[1],text=binding.display and binding.display.text or "Use defensive",dur=binding.display and binding.display.dur or 5,sound=binding.sound}) end
    end)
end
-- Boss timeline from your own pulls: the time of each boss mod timer or message, kept per boss and
-- difficulty from the longest pull (or the kill). The Timeline page draws it above the reminders.
function ns.RecordMechanic(spell, duration)
    if not (ns.recording and ns.pullTime and ns.encounter) or #ns.recording >= 300 then return end
    local at = math.floor((GetTime() - ns.pullTime + (duration or 0)) * 2 + 0.5) / 2
    if at < 0 or at > 3600 then return end
    for _, e in ipairs(ns.recording) do if e[2] == spell and math.abs(e[1] - at) < 3 then return end end
    ns.recording[#ns.recording + 1] = { at, spell }
end
function ns.FinishRecording(kill)
    local events, started = ns.recording, ns.pullTime
    ns.recording, ns.pullTime = nil, nil
    if not (events and started and ns.encounter and ns.difficulty) or #events == 0 then return false end
    local store = ns.Store(); store.timelines = store.timelines or {}
    local key = ns.Client() .. ":" .. ns.encounter .. ":" .. ns.difficulty
    local length = GetTime() - started
    local old = store.timelines[key]
    if old and old.shared then old = nil end -- your own pull replaces a shared one
    if old and old.kill and not kill then return false end
    if old and not kill and (old.length or 0) >= length then return false end
    table.sort(events, function(a, b) return a[1] < b[1] end)
    store.timelines[key] = { events = events, length = math.floor(length), kill = kill == true, at = time and time() or 0 }
    return true
end
function ns.RecordedTimeline(encounter, difficulty)
    local store = ns.Store()
    return store.timelines and store.timelines[ns.Client() .. ":" .. tostring(encounter) .. ":" .. tostring(difficulty)]
end
function ns.Mechanic(spell, duration, identity, encounter, skipDefensive, repeatEvent)
    if not ns.Plain(spell, "number") or (duration ~= nil and not ns.Plain(duration, "number")) then return end
    if (encounter or ns.encounter) == ns.encounter then ns.RecordMechanic(spell, duration); if ns.TraceEvent then ns.TraceEvent(spell, duration) end end
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
    local entries=ns.EncounterEntries(profile,encounter)or{}
    local authored=false
    for _,entry in pairs(entries)do if entry.defensive and entry.enabled~=false and entry.trigger.spellID==spell and ns.Target(entry.target)and ns.Difficulty(entry)and(not ns.ContentMatches or ns.ContentMatches(entry))then authored=true;break end end
    local defaults=profile.data.settings or{}
    if binding and ns.Difficulty(binding)and(not ns.ContentMatches or ns.ContentMatches(binding))and not skipDefensive and not authored and binding.mode~="custom" then ns.Defensive(binding, duration and math.max(0, duration - (binding.leadTime or profile.data.leadTime or defaults.leadTime or 3)) or 0, prefix .. "defensive") end
    for key, entry in pairs(entries) do
        local trigger = entry.trigger or {}
        if trigger.spellID == spell and entry.enabled~=false and ((duration and trigger.type == "bwtimer") or (not duration and trigger.type == "bwmsg")) then
            if not repeatEvent then ns.occurrences[entry]=(ns.occurrences[entry]or 0)+1 end
            local occurrence=ns.occurrences[entry]or 0
            if ns.Target(entry.target,occurrence)and(not ns.CounterMatches or ns.CounterMatches(trigger.counterGroups,occurrence))then
                local delay=(duration and math.max(0,duration-(trigger.leadTime or 3))or 0)+(trigger.delay or 0)
                ns.Schedule(prefix .. tostring(key),delay,function()ns.Fire(entry,nil,occurrence)end)
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
