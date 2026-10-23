-- Built-in boss timers from the game's own encounter timeline (Midnight). Timeline bars do not
-- name their ability to addons, only their duration, so every supported boss has a short
-- script in BossTimerData.lua that maps bars to abilities and follows its stages. A bar feeds
-- the same triggers as a boss mod: its start is a "Boss mod timer bar", its end a
-- "Boss mod message". BigWigs or DBM stay in charge when connected, unless Settings say
-- "Built-in only".
local _, ns = ...
ns.BossTimers = ns.BossTimers or {}
local state = { bars = {}, counts = {}, gaps = {}, pending = {}, hooks = {}, vars = {}, serial = 0 }
local frame = CreateFrame and CreateFrame("Frame")
local unitFrame = CreateFrame and CreateFrame("Frame")

local function Round(x, digits)
    local m = 10 ^ (digits or 0)
    return math.floor(x * m + 0.5) / m
end
function ns.BuiltinTimersFor(encounter)
    return ns.BossTimers[encounter] ~= nil
end
function ns.BuiltinTimersActive()
    if not ns.encounter or not ns.BuiltinTimersFor(ns.encounter) then return false end
    local source = ns.Settings and ns.Settings().bossSource
    if source == "ndp" then return true end
    -- A chosen boss mod that is not installed falls back to the built-in timers too.
    local p = ns.ProviderStatus and ns.ProviderStatus() or {}
    return not p.BigWigs and not p.DBM
end

local api = {}
local function Message(spell)
    ns.Mechanic(spell, nil, "NDPMSG:" .. spell, ns.encounter, true)
end
-- Counters restart with every stage, like the cast counts of a boss mod.
function api.Count(key)
    state.counts[key] = (state.counts[key] or 0) + 1
    return state.counts[key]
end
function api.Stage() return ns.phase or 1 end
function api.SetStage(n)
    state.counts = {}
    ns.Phase(n)
    local boss = ns.BossTimers[ns.encounter]
    if boss and boss.stage then boss.stage(api, state.bars, n) end
end
-- Ends one timeline bar quietly, without its message.
function api.Drop(id)
    local bar = state.bars[id]
    if not bar or bar.done then return end
    bar.done = true; ns.Cancel("ndp:msg:" .. id); ns.Cancel("ability:" .. bar.identity .. ":")
end
function api.Now() return GetTime() end
-- A bar NDP keeps itself (pull timers, repeating casts); its end counts as the cast.
function api.Bar(spell, seconds)
    if not seconds or seconds <= 0 then return end
    ns.Mechanic(spell, seconds, "NDPBAR:" .. spell, ns.encounter)
    ns.Schedule("ndp:bar:" .. spell, seconds, function() Message(spell) end)
end
function api.StopBar(spell)
    ns.Cancel("ability:NDPBAR:" .. spell .. ":"); ns.Cancel("ndp:bar:" .. spell)
end
function api.After(name, seconds, fn)
    ns.Schedule("ndp:after:" .. name, math.max(0.01, seconds), fn)
end
function api.Cancel(name) ns.Cancel("ndp:after:" .. name) end
-- Unit events for stage changes; all are dropped when the pull ends.
function api.On(event, fn, ...)
    state.hooks[event] = fn
    if not unitFrame then return end
    if select("#", ...) > 0 and unitFrame.RegisterUnitEvent then pcall(unitFrame.RegisterUnitEvent, unitFrame, event, ...)
    else pcall(unitFrame.RegisterEvent, unitFrame, event) end
end
function api.Off(event)
    state.hooks[event] = nil
    if unitFrame then pcall(unitFrame.UnregisterEvent, unitFrame, event) end
end
-- Ends every timeline bar of a spell, as the boss mods do when a stage starts.
function api.StopSpell(spell)
    for id, bar in pairs(state.bars) do
        if bar.spell == spell and not bar.done then
            bar.done = true; ns.Cancel("ndp:msg:" .. id); ns.Cancel("ability:" .. bar.identity .. ":")
        end
    end
    api.StopBar(spell)
end
if unitFrame then
    unitFrame:SetScript("OnEvent", function(_, event, ...)
        local fn = state.hooks[event]
        if fn and ns.encounter and ns.BuiltinTimersActive() then fn(api, ...) end
    end)
end

local function Finish(id)
    local bar = state.bars[id]
    if not bar or bar.done then return end
    bar.done = true; ns.Cancel("ndp:msg:" .. id)
    Message(bar.spell)
    if bar.gap then
        state.gaps[bar.spell] = GetTime() + bar.gap
        ns.Mechanic(bar.spell, bar.gap, "NDPGAP:" .. bar.spell, ns.encounter)
    end
    local boss = ns.BossTimers[ns.encounter]
    if boss and boss.finished then boss.finished(api, bar.spell, bar) end
end
local function Cancelled(id)
    local bar = state.bars[id]
    if not bar or bar.done then return end
    bar.done = true; ns.Cancel("ndp:msg:" .. id); ns.Cancel("ability:" .. bar.identity .. ":")
    local boss = ns.BossTimers[ns.encounter]
    if boss and boss.canceled then boss.canceled(api, bar.spell, bar) end
end
local function Start(id, spell, opts, duration, elapsed)
    opts = opts or {}
    local total = duration + (opts.extra or 0)
    local remaining = math.max(0.1, total - (elapsed or 0))
    local gap = state.gaps[spell]
    local repeatEvent = gap ~= nil and gap > GetTime() - 2
    if gap then state.gaps[spell] = nil; ns.Cancel("ability:NDPGAP:" .. spell .. ":") end
    local bar = {
        id = id, spell = spell, duration = duration, deadline = GetTime() + remaining, identity = "NDP:" .. id,
        fixed = opts.fixed, cancelFires = opts.cancelFires, gap = opts.gap, data = opts.data,
    }
    state.bars[id] = bar
    ns.Mechanic(spell, remaining, bar.identity, ns.encounter, false, repeatEvent)
    ns.Schedule("ndp:msg:" .. id, remaining, function() Finish(id) end)
end
local function Handle(ev)
    local boss = ns.BossTimers[ns.encounter]
    if not boss or not boss.added then return end
    local d = { dur = ev.duration, r = Round(ev.duration), r1 = Round(ev.duration, 1) }
    d.r2 = Round(d.r1)
    local spell, opts = boss.added(api, d, ev)
    if spell then Start(ev.id, spell, opts, ev.duration, GetTime() - ev.at) end
end
-- Bars of one game frame are handled together, so a boss script can read the whole set.
local queue, queued = {}, false
local function Dispatch()
    queued = false
    local batch = queue; queue = {}
    if not ns.encounter or not ns.BuiltinTimersActive() then return end
    local boss = ns.BossTimers[ns.encounter]
    if boss and boss.batch then boss.batch(api, batch) end
    for _, ev in ipairs(batch) do Handle(ev) end
end
local function Added(info)
    local ok, source, duration, id = pcall(function() return info.source, info.duration, info.id end)
    if not ok or not ns.Plain(source, "number") or source ~= 0 or not ns.Plain(duration, "number") or duration <= 0 or not ns.Plain(id, "number") then return end
    local ev = { id = id, duration = duration, at = GetTime() }
    if not ns.encounter then
        if #state.pending < 40 then state.pending[#state.pending + 1] = ev end
        return
    end
    queue[#queue + 1] = ev
    if not queued then queued = true; C_Timer.After(0, Dispatch) end
end
local function Changed(id)
    if not ns.encounter or not ns.BuiltinTimersActive() then return end
    local bar = state.bars[id]
    local boss = ns.BossTimers[ns.encounter]
    local watch = boss and boss.anyCanceled
    if not watch and (not bar or bar.done or bar.fixed) then return end
    local timeline = C_EncounterTimeline
    if not timeline or not timeline.GetEventState then return end
    local ok, s = pcall(timeline.GetEventState, id)
    if not ok or not ns.Plain(s, "number") then return end
    -- Some bosses react to any cancelled bar, also to bars NDP does not name.
    if watch and s == 3 and not (bar and bar.fixed) then watch(api, state.bars, id) end
    if not bar or bar.done or bar.fixed then return end
    if s == 2 then Finish(id)
    elseif s == 3 then if bar.cancelFires then Finish(id) else Cancelled(id) end
    elseif s == 1 and not bar.paused then
        bar.paused, bar.remaining = true, math.max(0, bar.deadline - GetTime())
        ns.Cancel("ndp:msg:" .. id); ns.Cancel("ability:" .. bar.identity .. ":")
    elseif s == 0 and bar.paused then
        bar.paused, bar.deadline = false, GetTime() + bar.remaining
        ns.Mechanic(bar.spell, bar.remaining, bar.identity, ns.encounter, false, true)
        ns.Schedule("ndp:msg:" .. id, bar.remaining, function() Finish(id) end)
    end
end

function ns.ResetBuiltinTimers()
    state.bars, state.counts, state.gaps, queue = {}, {}, {}, {}
    for event in pairs(state.hooks) do api.Off(event) end
    state.vars = {}; api.vars = state.vars
end
-- Called from ns.Begin: per-pull state, the boss script's pull timers and the bars the game
-- added just before ENCOUNTER_START.
function ns.StartBuiltinTimers()
    local pending = state.pending; state.pending = {}
    if not ns.encounter or not ns.BuiltinTimersActive() then return end
    local d = ns.difficulty
    api.mythic, api.heroic, api.normal, api.lfr = d == 16, d == 15, d == 14, d == 17
    api.easy = d == 14 or d == 17
    local boss = ns.BossTimers[ns.encounter]
    if boss.start then boss.start(api) end
    for _, ev in ipairs(pending) do if GetTime() - ev.at < 5 then queue[#queue + 1] = ev end end
    if #queue > 0 and not queued then queued = true; C_Timer.After(0, Dispatch) end
end
ns.BuiltinTimerEvent = function(event, a)
    if event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then Added(a)
    elseif event == "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED" then if ns.Plain(a, "number") then Changed(a) end
    elseif event == "ENCOUNTER_TIMELINE_EVENT_REMOVED" then if ns.Plain(a, "number") then state.bars[a] = nil end
    elseif event == "ENCOUNTER_END" then state.pending = {} end
end
ns.BuiltinTimerAPI = api
if frame then
    for _, event in ipairs({ "ENCOUNTER_TIMELINE_EVENT_ADDED", "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", "ENCOUNTER_TIMELINE_EVENT_REMOVED", "ENCOUNTER_END" }) do
        pcall(frame.RegisterEvent, frame, event)
    end
    frame:SetScript("OnEvent", function(_, event, a) ns.BuiltinTimerEvent(event, a) end)
end
