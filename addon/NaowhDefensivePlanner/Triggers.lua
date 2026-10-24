local _, ns = ...
-- Game-state triggers of a pull: "bosshp" fires once when a boss falls below a health percent,
-- "aura" fires each time an aura with that spell ID lands on you. Events are only watched
-- while the encounter has such reminders. Health and auras the game hides read as unknown.
local frame=CreateFrame("Frame")
local watch={hp={},aura={}}
local function Percent(unit)
    if not(UnitExists and UnitHealth and UnitHealthMax)then return end
    local ok,exists=pcall(UnitExists,unit);if not ok or exists~=true then return end
    local a,hp=pcall(UnitHealth,unit);local b,max=pcall(UnitHealthMax,unit)
    if not a or not b or not ns.Plain(hp,"number")or not ns.Plain(max,"number")or max<=0 then return end
    return hp/max*100
end
local function HasAura(spell)
    if not(C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID)then return false end
    local ok,aura=pcall(C_UnitAuras.GetPlayerAuraBySpellID,spell)
    return ok and ns.Plain(aura,"table")and true or false
end
local function Fire(w)
    ns.occurrences[w.entry]=(ns.occurrences[w.entry]or 0)+1
    ns.Fire(w.entry,nil,ns.occurrences[w.entry])
end
local function CheckHealth()
    for _,w in ipairs(watch.hp)do if not w.done then
        for i=1,5 do local p=Percent("boss"..i);if p and p<=w.percent then w.done=true;Fire(w);break end end
    end end
end
local function CheckAuras()
    for _,w in ipairs(watch.aura)do
        local up=HasAura(w.spell)
        if up and not w.up then Fire(w)end
        w.up=up
    end
end
frame:SetScript("OnEvent",function(_,event,unit)
    if not ns.encounter or ns.simulation then return end
    if event=="UNIT_HEALTH"then if type(unit)=="string"and unit:match("^boss%d$")then CheckHealth()end
    elseif event=="UNIT_AURA"then CheckAuras()end
end)
function ns.StopStateTriggers()
    watch.hp,watch.aura={},{}
    frame:UnregisterEvent("UNIT_HEALTH");frame:UnregisterEvent("UNIT_AURA")
end
function ns.StartStateTriggers()
    ns.StopStateTriggers()
    if not ns.encounter or ns.simulation then return end
    for _,entry in pairs(ns.EncounterEntries(ns.Active(),ns.encounter)or{})do
        local t=type(entry)=="table"and entry.enabled~=false and entry.trigger
        if t and t.type=="bosshp"and tonumber(t.percent)then watch.hp[#watch.hp+1]={entry=entry,percent=tonumber(t.percent)}
        elseif t and t.type=="aura"and tonumber(t.spellID)then watch.aura[#watch.aura+1]={entry=entry,spell=tonumber(t.spellID),up=HasAura(tonumber(t.spellID))}end
    end
    if #watch.hp>0 then frame:RegisterEvent("UNIT_HEALTH")end
    if #watch.aura>0 then frame:RegisterUnitEvent("UNIT_AURA","player")end
end
-- Expected-time fallback: an ability no boss mod announces still drives the reminders bound to
-- it, from its expected times this pull (a 10 s bar, then the message). The first real
-- announcement of that ability cancels its fallback.
local LEAD=10
function ns.ExpectedAnnounced(spell)
    if ns.expectedFallback and ns.expectedFallback[spell]then ns.expectedFallback[spell]=nil;ns.Cancel("exp:"..spell..":")end
end
function ns.StartExpectedFallback()
    ns.expectedFallback=nil
    if not ns.encounter or ns.simulation or ns.simStarting or not ns.ExpectedTimeline or not ns.UnannouncedAbilities then return end
    local profile=ns.Active();if not profile then return end
    local encounter=ns.encounter
    local bound={}
    for _,entry in pairs(ns.EncounterEntries(profile,encounter)or{})do local t=type(entry)=="table"and entry.trigger;if t and(t.type=="bwtimer"or t.type=="bwmsg")and ns.UnannouncedAbilities[t.spellID]then bound[t.spellID]=true end end
    for _,byEnc in pairs(profile.data.abilityBindings or{})do for spell in pairs(ns.Get(byEnc,encounter)or{})do spell=tonumber(spell);if spell and ns.UnannouncedAbilities[spell]then bound[spell]=true end end end
    if not next(bound)then return end
    local timeline=ns.ExpectedTimeline(encounter,ns.difficulty);if not timeline then return end
    ns.expectedFallback=bound
    local function call(spell,duration,identity,skip)
        local recording=ns.recording;ns.recording=nil -- expected times never enter the recorded pull
        ns.Mechanic(spell,duration,identity,encounter,skip);ns.recording=recording
    end
    for i,ev in ipairs(timeline.events)do local at,spell=tonumber(ev[1])or 0,ev[2]
        if bound[spell]and at>0 then
            local start=math.max(0,at-LEAD)
            ns.Schedule("exp:"..spell..":bar:"..i,start,function()call(spell,at-start,"EXP:"..i)end)
            ns.Schedule("exp:"..spell..":msg:"..i,at,function()call(spell,nil,"EXPMSG:"..spell,true)end)
        end
    end
end
