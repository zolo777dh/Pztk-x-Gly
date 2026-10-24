-- Pull simulation: plays a boss timeline (your recorded pull, or the expected one) through the
-- normal reminder engine outside combat, so every reminder, voice and glow shows exactly as it
-- would on the pull. Each ability gets a 10 s boss mod bar before its cast and a message on it.
local _, ns = ...
local LEAD = 10
local function now() return GetTime() end

function ns.SimulationTimeline(encounter, difficulty)
    return ns.RecordedTimeline(encounter, difficulty) or (ns.ExpectedTimeline and ns.ExpectedTimeline(encounter, difficulty))
end
function ns.Simulating() return ns.simulation ~= nil end
function ns.StopSimulation()
    if not ns.simulation then return end
    ns.Reset()
    if ns.OnSimulationChanged then ns.OnSimulationChanged() end
end
-- Returns true, or nil and a reason.
function ns.SimulatePull(encounter, difficulty)
    if IsEncounterInProgress and IsEncounterInProgress() then return nil, "Not during a boss fight" end
    if InCombatLockdown and InCombatLockdown() then return nil, "Leave combat first" end
    local timeline = ns.SimulationTimeline(encounter, difficulty)
    if not timeline or not timeline.events or #timeline.events == 0 then return nil, "No timeline for this boss yet" end
    ns.simStarting = true -- keeps the built-in boss timers out of the simulated pull
    ns.Begin(encounter, difficulty, nil)
    ns.simStarting = nil
    ns.recording, ns.pullTime = nil, nil -- a simulated pull never replaces a recorded one
    local sim = { encounter = encounter, difficulty = difficulty, started = now(), length = (tonumber(timeline.length) or 0) + 5 }
    ns.simulation = sim
    for i, ev in ipairs(timeline.events) do
        local at, spell = tonumber(ev[1]) or 0, ev[2]
        local barStart = math.max(0, at - LEAD)
        ns.Schedule("sim:bar:" .. i, barStart, function() ns.Mechanic(spell, at - barStart, "SIM:" .. i, encounter) end)
        ns.Schedule("sim:msg:" .. i, at, function() ns.Mechanic(spell, nil, "SIMMSG:" .. spell, encounter, true) end)
    end
    ns.Schedule("sim:end", sim.length, function() ns.StopSimulation() end)
    if ns.OnSimulationChanged then ns.OnSimulationChanged() end
    return true
end
-- Seconds since the simulated pull, for the Timeline playhead.
function ns.SimulationTime()
    return ns.simulation and (now() - ns.simulation.started) or nil
end
