local _, ns = ...
-- Pull analysis: each real pull logs when PDP called a defensive (and which spells it showed)
-- and when you cast a spell of your sets. The last pull per boss and difficulty is kept, so the
-- Timeline can compare the plan with what happened: a call is followed when one of its spells
-- was cast within FOLLOW seconds. Only your own casts are read; the game hides other players'.
local FOLLOW = 8
ns.AnalysisFollowWindow = FOLLOW
local frame = CreateFrame("Frame")
local log
local function Key(encounter, difficulty) return ns.Client() .. ":" .. tostring(encounter) .. ":" .. tostring(difficulty) end
-- Every spell of the player's sets, so only those casts are logged.
local function SetSpells()
    local out, profile, spec = {}, ns.Active(), ns.Spec()
    if not profile or not spec then return out end
    for _, scope in ipairs({ "raid", "mythic" }) do
        local sets = ns.ScopePresets and ns.ScopePresets(profile, scope, spec) or ns.Get(profile.data.presets, spec)
        for _, set in pairs(sets or {}) do for _, s in ipairs(type(set) == "table" and set.list or {}) do
            local id = type(s) == "table" and tonumber(s.spellID) or tonumber(s); if id then out[id] = true end
        end end
    end
    return out
end
function ns.StartPullLog()
    log = nil; frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    if not ns.encounter or ns.simulation or ns.simStarting then return end
    log = { encounter = ns.encounter, difficulty = ns.difficulty, started = GetTime(), calls = {}, casts = {}, spells = SetSpells() }
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
end
local function Now() return math.floor((GetTime() - log.started) * 10 + 0.5) / 10 end
-- A defensive call shown on screen (RuleRuntime.lua).
function ns.LogDefensiveCall(spells, label)
    if not log or #log.calls >= 200 then return end
    local list = {}; for i, s in ipairs(spells or {}) do if i <= 4 then list[i] = s end end
    log.calls[#log.calls + 1] = { at = Now(), spells = list, label = label }
end
frame:SetScript("OnEvent", function(_, _, unit, _, spell)
    if not log or unit ~= "player" or not ns.Plain(spell, "number") or not log.spells[spell] or #log.casts >= 300 then return end
    log.casts[#log.casts + 1] = { at = Now(), spell = spell }
end)
function ns.FinishPullLog(kill)
    local done = log; log = nil; frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    if not done or (#done.calls == 0 and #done.casts == 0) then return end
    local store = ns.Store(); store.pullLogs = store.pullLogs or {}
    store.pullLogs[Key(done.encounter, done.difficulty)] = { calls = done.calls, casts = done.casts, length = math.floor(GetTime() - done.started), kill = kill == true, at = time and time() or 0 }
end
function ns.PullLog(encounter, difficulty)
    local store = ns.Store(); return store.pullLogs and store.pullLogs[Key(encounter, difficulty)]
end
-- Each call with the first matching cast after it (or nil), and the counts.
function ns.AnalysePull(entry)
    local out, followed = {}, 0
    if not entry then return out, 0 end
    local used = {}
    for _, call in ipairs(entry.calls or {}) do
        local want = {}; for _, s in ipairs(call.spells or {}) do want[s] = true end
        local hit
        for i, c in ipairs(entry.casts or {}) do
            if not used[i] and want[c.spell] and c.at >= call.at - 1 and c.at <= call.at + FOLLOW then hit = c; used[i] = true; break end
        end
        if hit then followed = followed + 1 end
        out[#out + 1] = { call = call, cast = hit, late = hit and (hit.at - call.at) or nil }
    end
    return out, followed
end
