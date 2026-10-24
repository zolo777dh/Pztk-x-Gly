-- Cooldown planner: walks the planned defensive calls of a boss in time order and predicts which
-- spell of each set will be ready, using the spells' cooldowns and charges, the same priority
-- rules as the live pick (first ready spell, or the whole "together" group). A call with nothing
-- ready is a conflict to fix before the pull.
local _, ns = ...
local ASSUMED = 120

-- Cooldown in seconds and charges of one of your spells; known=false when the game gave none.
function ns.SpellCooldownInfo(spell)
    local cd, charges, known = nil, 1, false
    if C_Spell and C_Spell.GetSpellCharges then
        local ok, info = pcall(C_Spell.GetSpellCharges, spell)
        if ok and type(info) == "table" and ns.Plain(info.maxCharges, "number") and info.maxCharges > 1 then
            charges = info.maxCharges
            if ns.Plain(info.cooldownDuration, "number") and info.cooldownDuration > 0 then cd, known = info.cooldownDuration, true end
        end
    end
    if not cd and GetSpellBaseCooldown then
        local ok, ms = pcall(GetSpellBaseCooldown, spell)
        if ok and ns.Plain(ms, "number") and ms > 0 then cd, known = ms / 1000, true end
    end
    return cd or ASSUMED, charges, known
end

-- uses: list of {at = seconds, preset = set table, label = text}. Returns the same list sorted by
-- time with .spells (what will be cast, empty when nothing is ready) and .readyAt (when the first
-- spell of the set is back) filled in.
function ns.PlanDefensives(uses)
    local out = {}
    for _, u in ipairs(uses) do out[#out + 1] = u end
    table.sort(out, function(a, b) return a.at < b.at end)
    local charges = {} -- spell -> list of times each charge is ready
    local function slot(spell, at)
        local list = charges[spell]
        if not list then
            local _, n = ns.SpellCooldownInfo(spell); list = {}
            for i = 1, n do list[i] = -math.huge end
            charges[spell] = list
        end
        local best
        for i, t in ipairs(list) do if t <= at and (not best or t < list[best]) then best = i end end
        return best, list
    end
    local function spend(spell, at)
        local i, list = slot(spell, at)
        local cd = ns.SpellCooldownInfo(spell)
        list[i] = at + cd
    end
    local function nextReady(spell)
        local _, list = slot(spell, -math.huge)
        local t = math.huge; for _, v in ipairs(list) do t = math.min(t, v) end
        return t
    end
    for _, u in ipairs(out) do
        local preset = u.preset or {}
        local list, together = {}, {}
        for _, spell in ipairs(preset.list or {}) do
            if not ns.Get(preset.disabled, spell) then
                list[#list + 1] = spell
                if ns.Get(preset.together, spell) then together[#together + 1] = spell end
            end
        end
        u.spells = {}
        local groupReady = #together > 0
        for _, spell in ipairs(together) do if not slot(spell, u.at) then groupReady = false end end
        for _, spell in ipairs(list) do
            if ns.Get(preset.together, spell) then
                if groupReady then u.spells = together; break end
            elseif slot(spell, u.at) then u.spells = { spell }; break end
        end
        for _, spell in ipairs(u.spells) do spend(spell, u.at) end
        if #u.spells == 0 then
            local soonest = math.huge
            for _, spell in ipairs(list) do soonest = math.min(soonest, nextReady(spell)) end
            u.readyAt = soonest < math.huge and soonest or nil
        end
    end
    return out
end
