-- Adapters for provider callbacks. Provider tables are observed, never modified.
local _, ns = ...
local modules, trash = {}, {}
local serial = 0
local bwConnected, dbmConnected, exConnected
local registrationErrors = {}

local function Encounter(module)
    if not ns.Plain(module, "table") then return nil end
    local id = module.engageId
    if not ns.Plain(id, "number") then id = ns.encounter end
    if ns.encounter and id ~= ns.encounter then return nil end
    return id
end

local function Module(module)
    if not ns.Plain(module, "table") then return nil end
    if not modules[module] then
        serial = serial + 1
        modules[module] = {id = serial, bars = {}}
    end
    return modules[module]
end

local function Stop(record)
    ns.Cancel("ability:" .. record.id .. ":")
end

local function BigWigs(event, module, spell, duration, _, text)
    if ns.ProviderSelected and not ns.ProviderSelected("bigwigs")then return end
    local state = Module(module)
    if not state then return end
    if event == "BigWigs_Timer" then
        local encounter = Encounter(module)
        if not encounter or not ns.Plain(spell, "number") or not ns.Plain(duration, "number") or duration <= 0 then return end
        local label = ns.Plain(text, "string") and text or nil
        local key = label or spell
        local record = state.bars[key]
        if not record then
            serial = serial + 1
            record = {id = "BW:" .. serial}
            state.bars[key] = record
        end
        local repeatEvent=record.deadline and record.deadline>GetTime()
        record.spell, record.encounter, record.deadline = spell, encounter, GetTime() + duration
        record.paused, record.remaining = false, nil
        ns.Mechanic(spell, duration, record.id, encounter,false,repeatEvent)
    elseif event == "BigWigs_Message" then
        local encounter = Encounter(module)
        if not encounter or not ns.Plain(spell, "number") then return end
        if not ns.encounter then
            state.messages=state.messages or {}
            if #state.messages<50 then state.messages[#state.messages+1]={spell=spell,at=GetTime(),encounter=encounter}end
            return
        end
        local predicted = false
        for _, record in pairs(state.bars) do
            if record.spell == spell and not record.paused and record.deadline >= GetTime() - 2 then predicted = true; break end
        end
        ns.Mechanic(spell, nil, "BWMSG:" .. state.id .. ":" .. spell, encounter, predicted)
    elseif event == "BigWigs_StopBar" or event == "BigWigs_PauseBar" or event == "BigWigs_ResumeBar" then
        -- These callbacks carry (module, bar TEXT), not the spell ID.
        if not ns.Plain(spell, "string") then return end
        local record = state.bars[spell]
        if not record then return end
        if event == "BigWigs_ResumeBar" then
            if not record.paused or not record.remaining or record.remaining <= 0 then return end
            record.deadline = GetTime() + record.remaining
            record.paused = false
            ns.Mechanic(record.spell, record.remaining, record.id, record.encounter,false,true)
        else
            Stop(record)
            if event == "BigWigs_StopBar" then state.bars[spell] = nil
            elseif not record.paused then record.remaining = math.max(0, record.deadline - GetTime()); record.paused = true end
        end
    elseif event == "BigWigs_SetStage" then
        if Encounter(module) then ns.Phase(spell) end
    elseif event == "BigWigs_StopBars" or event == "BigWigs_OnBossDisable" or event == "BigWigs_OnBossWipe" then
        for _, record in pairs(state.bars) do Stop(record) end
        state.bars, state.messages = {}, {}
        if event ~= "BigWigs_StopBars" and Encounter(module) == ns.encounter then ns.Reset() end
    end
end

local function DBMEvent(event, ...)
    -- A failed BigWigs registration must not silently disable DBM too.
    if ns.ProviderSelected and not ns.ProviderSelected("dbm")then return end
    local explicit=ns.Settings and ns.Settings().bossSource
    if bwConnected and explicit~="dbm"then return end
    if event == "DBM_TimerBegin" or event == "DBM_TimerStart" then
        local identity, _, duration, _, _, spell = ...
        if ns.Plain(identity, "string") and ns.Plain(spell, "number") and ns.Plain(duration, "number") then
            ns.Mechanic(spell, duration, "DBM:" .. identity)
        end
    elseif event == "DBM_Announce" then
        -- (message, icon, announceType, spellID)
        local _, _, _, spell = ...
        if ns.Plain(spell, "number") then ns.Mechanic(spell, nil, "DBMMSG:" .. spell) end
    elseif event == "DBM_SetStage" then
        -- (mod, modId, stage, encounterID, stageTotality)
        local _, _, stage = ...
        ns.Phase(stage)
    elseif event == "DBM_TimerStop" or event == "DBM_TimerPause" then
        local identity = ...
        if ns.Plain(identity, "string") then ns.Cancel("ability:DBM:" .. identity .. ":") end
    end
end

local function Failure(provider, err)
    local message = provider .. " connection failed: " .. tostring(err)
    if registrationErrors[provider] ~= message then
        registrationErrors[provider] = message
        if ns.Print then ns.Print(message) end
    end
end

local function ObserveTrash(scheduler, id)
    if not ns.Plain(id, "number") then return end
    local all = scheduler:GetActiveTimers()
    local timer = ns.Get(all, id)
    if not ns.Plain(timer, "table") or not ns.Plain(timer.source, "string") or timer.source ~= "trash"
        or not ns.Plain(timer.spellID, "number") or not ns.Plain(timer.castTime, "number") then return end
    local at, spell = timer.castTime, timer.spellID
    if at <= GetTime() then return end
    if ns.RefreshContext then ns.RefreshContext() end
    local map = ns.map
    local old = trash[id]
    if old and old.timer == timer and old.at == at then return end
    local anchor
    if ns.Plain(timer.trashFixedCombatTimeline, "boolean") and timer.trashFixedCombatTimeline then anchor = at
    elseif ns.Plain(timer.trashRuntime, "table") then anchor = ns.Get(timer.trashRuntime.nextSpellAnchorAt, spell) end
    if not ns.Plain(anchor, "number") then anchor = nil end
    local sameCycle = old and old.timer == timer and ((anchor and anchor == old.anchor) or (not anchor and GetTime() < old.at))
    local record = {timer = timer, at = at, anchor = anchor, delivered = sameCycle and old.delivered or {}}
    trash[id] = record
    ns.Trash(spell, at - GetTime(), id, function(key)
        local current = ns.Get(scheduler:GetActiveTimers(), id)
        if trash[id] ~= record or current ~= timer or ns.map ~= map
            or not ns.Plain(timer.castTime, "number") or timer.castTime ~= at
            or not ns.Plain(timer.source, "string") or timer.source ~= "trash" or record.delivered[key] then return false end
        record.delivered[key] = true
        return true
    end)
end

function ns.ResetProviders()
    if ns.ResetBuiltinTimers then ns.ResetBuiltinTimers() end
    modules, trash = {}, {}
end

function ns.CaptureProviderTimers(encounter)
    -- BigWigs' ENCOUNTER_START frame may run before ours. Retain its still-live
    -- first bars across Begin(), without retaining the previous encounter's queue.
    if ns.encounter then return nil end
    local result={}
    for module,state in pairs(modules)do
        for label,record in pairs(state.bars)do
            if record.encounter==encounter and not record.paused and record.deadline>GetTime()then
                result[#result+1]={module=module,spell=record.spell,deadline=record.deadline,label=type(label)=="string"and label or nil}
            end
        end
        for _,message in ipairs(state.messages or {})do
            if message.encounter==encounter and GetTime()-message.at>=0 and GetTime()-message.at<=1 then
                result.messages=result.messages or {}
                result.messages[#result.messages+1]={module=module,spell=message.spell}
            end
        end
    end
    return result
end

function ns.ReplayProviderTimers(records)
    for _,record in ipairs(records or {})do
        local remaining=record.deadline-GetTime()
        if remaining>0 then BigWigs("BigWigs_Timer",record.module,record.spell,remaining,nil,record.label)end
    end
    for _,message in ipairs(records and records.messages or {})do BigWigs("BigWigs_Message",message.module,message.spell)end
end

function ns.ProviderStatus()
    return {BigWigs = bwConnected == true, DBM = dbmConnected == true, EXBoss = exConnected ~= nil}, registrationErrors
end

function ns.ConnectProviders()
    if not bwConnected and BigWigsLoader and type(BigWigsLoader.RegisterMessage) == "function" then
        local ok, err = pcall(function()
            for _, event in ipairs({"BigWigs_Timer", "BigWigs_Message", "BigWigs_SetStage", "BigWigs_StopBar", "BigWigs_PauseBar", "BigWigs_ResumeBar", "BigWigs_StopBars", "BigWigs_OnBossDisable", "BigWigs_OnBossWipe"}) do
                BigWigsLoader.RegisterMessage(ns, event, BigWigs)
            end
        end)
        bwConnected = ok
        if ok then registrationErrors.BigWigs=nil else Failure("BigWigs", err) end
    end
    if not dbmConnected and DBM and type(DBM.RegisterCallback) == "function" then
        local ok, err = pcall(function()
            for _, event in ipairs({"DBM_TimerBegin", "DBM_TimerStart", "DBM_Announce", "DBM_SetStage", "DBM_TimerStop", "DBM_TimerPause"}) do DBM:RegisterCallback(event, DBMEvent) end
        end)
        dbmConnected = ok
        if ok then registrationErrors.DBM=nil else Failure("DBM", err) end
    end
    local scheduler = ExBoss and ExBoss.Timeline and ExBoss.Timeline.Scheduler
    if scheduler and not exConnected and type(scheduler.GetActiveTimers) == "function"
        and type(scheduler.RegisterTrashLocalTimer) == "function" and type(hooksecurefunc) == "function" then
        exConnected = scheduler
        hooksecurefunc(scheduler, "RegisterTrashLocalTimer", function(self, runtime, _, spell)
            if ns.Plain(runtime, "table") and ns.Plain(spell, "table") and ns.Plain(spell.spellID, "number") then ObserveTrash(self, ns.Get(runtime.localTimerIDsBySpellID, spell.spellID)) end
        end)
        if type(scheduler._AdvanceTrashFixedCombatTimeline) == "function" then
            hooksecurefunc(scheduler, "_AdvanceTrashFixedCombatTimeline", function(self, timer)
                if ns.Plain(timer, "table") then ObserveTrash(self, timer.id) end
            end)
        end
        if type(scheduler._RemoveActiveTimerByID) == "function" then
            hooksecurefunc(scheduler, "_RemoveActiveTimerByID", function(_, id)
                if not ns.Plain(id, "number") then return end
                trash[id] = nil
                ns.Cancel("trash:" .. id .. ":")
            end)
        end
    end
    if scheduler and scheduler == exConnected then
        local all = scheduler:GetActiveTimers()
        if ns.Plain(all, "table") then for id in pairs(all) do ObserveTrash(scheduler, id) end end
    end
end
