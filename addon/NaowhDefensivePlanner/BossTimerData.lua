-- Boss scripts for the built-in timers (BossTimers.lua). Each maps the game's timeline bars of
-- one encounter to abilities by their rounded duration, stage and order, and follows the
-- stages. The spell IDs and seconds are facts about the encounters, checked against the boss
-- mod timelines of patch 12.1.5. Bars no script recognises are ignored.
-- added(api, d) gets d.r (whole seconds), d.r1 (one decimal), d.r2 (one decimal, then whole)
-- and d.dur; it returns the spell and options: fixed (ignore pause/cancel, fire at the end),
-- extra (seconds added to the bar), gap (seconds to the next cast after this one ends),
-- cancelFires (a cancel counts as the cast), data (kept on the bar for the hooks).
local _, ns = ...
local B = ns.BossTimers

local function In(r, ...)
    for i = 1, select("#", ...) do if r == select(i, ...) then return true end end
    return false
end
-- Rotates through a list by the count of one duration (1-based).
local function Cycle(api, key, list)
    local n = api.Count(key)
    return list[(n - 1) % #list + 1], n
end

---------------------------------------------------------------------------
-- Nymrissa Wavecaller
do
    local ADDS, BUBBLE, WHIRLPOOLS, RAIN, FLURRY, FROST, JET = 1276710, 1257717, 1258668, 1260837, 1282937, 1313393, 1268562
    B[3379] = { name = "Nymrissa Wavecaller", added = function(api, d)
        local r = d.r
        if r == 44 then
            local spell = Cycle(api, 44, { ADDS, FROST, RAIN })
            return spell, { fixed = spell == ADDS }
        elseif r == 18 then return BUBBLE
        elseif In(r, 8, 23, 33) then return RAIN
        elseif In(r, 22, 27, 9) then return api.mythic and JET or FLURRY
        elseif In(r, 25, 7) then return ADDS, { fixed = true }
        elseif In(r, 107, 89) then return WHIRLPOOLS
        elseif In(r, 35, 17) then return FROST end
    end }
end

---------------------------------------------------------------------------
-- Sszorak
do
    local MAELSTROM, APEX, SURGE, CROSSWINDS = 1285732, 1277025, 1305959, 1285425
    B[3420] = { name = "Sszorak", added = function(api, d)
        local r = d.r
        if api.mythic and r == 46 then r = 47 end
        if In(r, 100, 111, 125) then return MAELSTROM, { cancelFires = true }
        elseif In(r, 5, 6) then return APEX
        elseif In(r, 29, 32, 36) then return SURGE
        elseif In(r, 39, 43, 49) then return CROSSWINDS
        elseif In(r, 47, 52, 59) then
            local spell = Cycle(api, r, { APEX, SURGE, CROSSWINDS })
            return spell, { fixed = spell == CROSSWINDS }
        end
    end }
end

---------------------------------------------------------------------------
-- Vashnik the Malignant
do
    local IMBIBE, CATALYST, FROTH, FANGS, INFECTION = 1283164, 1282525, 1281907, 1280935, 1282117
    local gaps = {
        heroic = { [IMBIBE] = { [20] = 84, [80] = 84 }, [CATALYST] = { [39] = 45 }, [FROTH] = { [13] = 41, [33] = 51 }, [FANGS] = { [8] = 29, [28] = 29 }, [INFECTION] = { [52] = 32 } },
        easy = { [IMBIBE] = { [20] = 84, [80] = 84 }, [FROTH] = { [13] = 21, [26] = 22 }, [FANGS] = { [8] = 18, [30] = 21 }, [INFECTION] = { [32] = 52 } },
    }
    local function With(api, spell, r)
        local g = (api.easy and gaps.easy or gaps.heroic)[spell]
        return spell, { gap = g and g[r] }
    end
    B[3455] = { name = "Vashnik the Malignant", added = function(api, d)
        local r = d.r
        if api.easy then
            if In(r, 20, 80) then return With(api, IMBIBE, r)
            elseif In(r, 13, 10, 17, 36, 26) then return With(api, FROTH, r)
            elseif In(r, 6, 39) then return With(api, CATALYST, r)
            elseif In(r, 2, 30, 33) then return With(api, FANGS, r)
            elseif r == 32 then return With(api, INFECTION, r)
            elseif r == 8 then return With(api, api.Count(8) == 1 and FANGS or INFECTION, r) end
            return
        end
        if r == 13 then return With(api, api.Count(13) == 1 and FROTH or FANGS, r)
        elseif In(r, 20, 80) then return With(api, IMBIBE, r)
        elseif In(r, 30, 33) then return With(api, FROTH, r)
        elseif In(r, 8, 27, 28) then return With(api, FANGS, r)
        elseif In(r, 18, 52) then return With(api, INFECTION, r)
        elseif In(r, 6, 39) then return With(api, CATALYST, r) end
    end }
end

---------------------------------------------------------------------------
-- Nek'zali the Soulcoiler
do
    local IGNITION, REND, AMANI, ADVANCE, BARRAGE, DEPTHS, PYRE, INVOKE = 1285681, 1287426, 1295397, 1287533, 1292036, 1293212, 1305421, 1299673
    local gaps = {
        [AMANI] = { [1] = { [40] = 71 }, [1.5] = { [30] = 40 }, [2] = { [40] = 40 } },
        [REND] = { [1] = { [40] = 31 }, [2] = { [49.5] = 80 } },
        [BARRAGE] = { [1] = { [36] = 35 }, [2] = { [28] = 52 } },
        [PYRE] = { [1.5] = { [11] = 40 } },
        [INVOKE] = { [2] = { [48] = 32 } },
    }
    local mythicIntermission = { [AMANI] = { [25] = 35 }, [PYRE] = { [11] = 35 } }
    local function With(api, spell, d)
        local stage = api.Stage()
        local g = (stage == 1.5 and api.mythic and mythicIntermission[spell]) or (gaps[spell] and gaps[spell][stage])
        return spell, { gap = g and g[d.r1] }
    end
    local ignition = { 3.0, 74.5, 70.5 }
    local function Ignition(api, n)
        local cd = ignition[n]
        if not cd then return end
        api.Bar(IGNITION, cd)
        api.After("ignition", cd, function() Ignition(api, n + 1) end)
    end
    local function Depths(api, cd)
        api.Bar(DEPTHS, cd)
        api.After("depths", cd, function()
            local stage = api.Stage()
            Depths(api, stage == 1 and 71 or stage == 1.5 and 35 or 40)
        end)
    end
    local castStart = 0
    B[3470] = { name = "Nek'zali the Soulcoiler",
        start = function(api)
            Ignition(api, 1)
            if api.mythic then Depths(api, 42.5) end
            api.On("UNIT_SPELLCAST_START", function() castStart = GetTime() end, "boss1")
            local function Ritual(api, unit)
                -- A short cast (or an interrupt) is the Ritual of Awakening: stage one ends.
                api.Off("UNIT_SPELLCAST_START"); api.Off("UNIT_SPELLCAST_SUCCEEDED"); api.Off("UNIT_SPELLCAST_INTERRUPTED")
                api.Cancel("ignition"); api.StopBar(IGNITION); api.StopSpell(AMANI); api.StopSpell(REND); api.StopSpell(BARRAGE)
                if api.mythic then api.Cancel("depths"); api.StopBar(DEPTHS) end
                api.On("UNIT_SPELLCAST_CHANNEL_START", function(api)
                    if api.Stage() == 1 then
                        api.SetStage(1.5)
                        if api.mythic then api.Cancel("depths"); Depths(api, 44) end
                    elseif api.Stage() == 1.5 then
                        api.Off("UNIT_SPELLCAST_CHANNEL_START")
                        api.StopSpell(AMANI); api.StopSpell(PYRE)
                        api.SetStage(2)
                        if api.mythic then api.Cancel("depths"); Depths(api, 27.5) end
                    end
                end, "boss1")
            end
            api.On("UNIT_SPELLCAST_SUCCEEDED", function(api, unit) if GetTime() - castStart < 2 then Ritual(api, unit) end end, "boss1")
            api.On("UNIT_SPELLCAST_INTERRUPTED", function(api, unit) Ritual(api, unit) end, "boss1")
        end,
        added = function(api, d)
            local r, stage = d.r, api.Stage()
            if stage < 2 then
                if In(r, 40, 28, 15) and api.Count("first" .. r) == 1 then return false end -- the first bar is cancelled
                if r == 40 then return With(api, api.Count(40) % 2 == 1 and AMANI or REND, d)
                elseif In(r, 28, 36) then return With(api, BARRAGE, d)
                elseif r == 15 then return With(api, REND, d)
                elseif r == (api.mythic and 25 or 30) then return With(api, AMANI, d)
                elseif r == 11 then return With(api, PYRE, d) end
            else
                if In(r, 8, 48) then return With(api, INVOKE, d)
                elseif r == 28 then return With(api, BARRAGE, d)
                elseif r == 40 then return With(api, api.Count(40) % 2 == 1 and BARRAGE or AMANI, d)
                elseif r == 50 then return With(api, REND, d)
                elseif r == 20 then return With(api, AMANI, d) end
            end
        end,
        finished = function(api, spell) if spell == AMANI then api.Bar(ADVANCE, 12.6) end end,
    }
end

---------------------------------------------------------------------------
-- Entombed Sentinels
do
    local STASIS, PROTOVENOM, COAGULATION, DROPLETS, SLAM, BLOOD, MIASMA, INJECTION = 1284588, 1296878, 1284251, 1284434, 1284458, 1284483, 1288232, 1284487
    local opening = { [12] = true, [8] = true, [4] = true, [16] = true, [40] = true, [6] = true }
    B[3445] = { name = "Entombed Sentinels",
        start = function(api)
            local v = api.vars
            v.intermission, v.proto = false, 0
            api.Bar(STASIS, 46); v.nextStasis = GetTime() + 46
            if api.mythic then api.Bar(PROTOVENOM, 36) end
        end,
        added = function(api, d)
            local v, r = api.vars, d.r2
            if v.intermission then
                -- The first bar after Vitriolic Stasis opens the next stage.
                v.intermission = false
                api.SetStage(api.Stage() + 1)
                v.nextStasis = GetTime() + 91
                api.Bar(STASIS, 91)
                if api.mythic then api.Bar(PROTOVENOM, 39.9) end
            end
            local stage = api.Stage()
            local n = api.Count(r)
            if stage > 1 and opening[r] and n < 3 then return false end
            if d.dur ~= 20 and d.dur ~= 15 and GetTime() + d.dur >= (v.nextStasis or 0) then return false end
            if In(r, 12, 32) then return DROPLETS
            elseif In(r, 8, 10) or d.r1 == 51.5 then return COAGULATION
            elseif r == 4 then return SLAM
            elseif In(r, 16, 41) then return MIASMA
            elseif In(r, 40, 52) then return BLOOD
            elseif r == 6 then return INJECTION
            elseif r == 20 then
                local proto = api.mythic and (stage == 1 and n % 2 > 0 or stage > 1 and n % 3 > 0)
                if proto then
                    v.proto = v.proto + 1
                    return PROTOVENOM, { fixed = true, extra = 3, gap = stage > 1 and v.proto < 3 and 41 or nil }
                end
                api.StopBar(STASIS)
                v.nextStasis = GetTime() + d.dur
                return STASIS, { fixed = true, extra = 1 }
            elseif r == 22 then return n % 2 == 1 and SLAM or INJECTION end
        end,
        finished = function(api, spell)
            if spell == STASIS and not api.vars.intermission then api.vars.intermission, api.vars.proto = true, 0 end
        end,
    }
end

---------------------------------------------------------------------------
-- The Twin Fangs
do
    local SUBMERGE, CAUSTIC, TOXIN, BECKON, FEAST, TORRENT, STIR, STONE, BARRAGE, FLOOD, ROUSE =
        1308556, 1289192, 1290809, 1291404, 1290516, 1303230, 1290956, 1288538, 1306872, 1294293, 1308356
    B[3421] = { name = "The Twin Fangs", added = function(api, d)
        if api.mythic then
            local r = d.r
            if r == 130 then return SUBMERGE
            elseif r == 6 then return (Cycle(api, 6, { BARRAGE, FLOOD }))
            elseif r == 8 then return (Cycle(api, 8, { CAUSTIC, TORRENT }))
            elseif r == 18 then return STONE
            elseif r == 33 then return (Cycle(api, 33, { ROUSE, BECKON }))
            elseif r == 40 then return TOXIN
            elseif r == 47 then return STIR
            elseif r == 57 then return FEAST
            elseif r == 61 then return (Cycle(api, 61, { CAUSTIC, TORRENT, STONE, ROUSE, BECKON, TOXIN, STIR, FEAST })) end
            return
        end
        local r, e = d.r2, api.easy
        if r == (e and 163 or 144) then return SUBMERGE
        elseif r == 6 then return (Cycle(api, 6, { BARRAGE, FLOOD }))
        elseif r == (e and 50 or 44) then return TOXIN
        elseif r == (e and 71 or 63) then return FEAST
        elseif r == (e and 23 or 20) or r == 22 then return STONE
        elseif r == (e and 41 or 37) then return BECKON
        elseif r == (e and 10 or 9) then return CAUSTIC
        elseif r == (e and 59 or 52) then return STIR
        elseif r == (e and 76 or 68) then return (Cycle(api, r, { CAUSTIC, STONE, BECKON, TOXIN, STIR, FEAST })) end
    end }
end

---------------------------------------------------------------------------
-- The Coiled Altar
do
    local DELUGE, AXE, VENOMFANG, GUILLOTINE, SEVER, FANGS = 1299960, 1283832, 1282281, 1283489, 1299680, 1282487
    local DREAD, NIGHTFALL, SPIRIT, GLOOM, SOULSEVER, DEFILEMENT, GRIM, BLIGHTED = 1289900, 1286918, 1286441, 1286895, 1286573, 1298381, 1299266, 1307279
    local stage1 = { [DELUGE] = { [43] = 42 }, [GUILLOTINE] = { [43] = 85 }, [SEVER] = { [17] = 31 }, [VENOMFANG] = { [35] = 50 }, [AXE] = { [12] = 85 } }
    local gaps = {
        mythic = { [1] = stage1, [2] = { [SPIRIT] = { [33] = 52 }, [NIGHTFALL] = { [70] = 85 }, [DREAD] = { [34] = 51 }, [GLOOM] = { [37] = 48 }, [SOULSEVER] = { [31] = 54 } } },
        heroic = { [1] = stage1, [2] = { [SPIRIT] = { [33] = 52 }, [NIGHTFALL] = { [70] = 85 }, [DREAD] = { [34] = 51 }, [GLOOM] = { [38] = 47 }, [SOULSEVER] = { [31] = 54 } } },
        easy = {
            [1] = { [DELUGE] = { [42] = 43 }, [GUILLOTINE] = { [42] = 85 }, [SEVER] = { [16] = 31 }, [VENOMFANG] = { [35] = 50 }, [AXE] = { [12] = 85 } },
            [2] = { [NIGHTFALL] = { [70] = 85 }, [DREAD] = { [34] = 51 }, [GLOOM] = { [40] = 45 }, [SOULSEVER] = { [33] = 52 } },
        },
    }
    local function With(api, spell, d, opts)
        local mode = api.mythic and "mythic" or api.easy and "easy" or "heroic"
        local g = gaps[mode][api.Stage()]
        opts = opts or {}
        if opts.gap == nil then opts.gap = g and g[spell] and g[spell][d.r] or nil end
        if opts.gap == false then opts.gap = nil end
        return spell, opts
    end
    local function Intermission(api)
        if api.Stage() ~= 2 then return end
        api.Off("UNIT_SPELLCAST_CHANNEL_START")
        for _, spell in ipairs({ SPIRIT, NIGHTFALL, DREAD, GLOOM, SOULSEVER }) do api.StopSpell(spell) end
        api.SetStage(2.5)
    end
    B[3429] = { name = "The Coiled Altar",
        start = function(api)
            api.vars.fangs, api.vars.s3 = 0, 0
            api.On("UNIT_SPELLCAST_CHANNEL_STOP", function(api)
                if api.Stage() == 2.5 then api.SetStage(3) end -- Soulbinding ends
            end, "boss2")
        end,
        added = function(api, d)
            local v, r, stage = api.vars, d.r2, api.Stage()
            if stage == 1 then
                if r == 2 then return With(api, DELUGE, d)
                elseif r == 12 then return With(api, AXE, d)
                elseif In(r, 28, 35) then return With(api, VENOMFANG, d)
                elseif r == (api.easy and 42 or 43) then return With(api, (Cycle(api, r, { GUILLOTINE, DELUGE })), d)
                elseif In(r, 20, 17) or not api.mythic and In(r, 21, 16) then
                    local n = api.Count("sever")
                    return With(api, SEVER, d, { gap = n % 4 ~= 0 and false or nil }) -- the gap follows every fourth cast
                elseif r == 85 then
                    v.fangs = v.fangs + 1
                    return With(api, FANGS, d, { data = v.fangs })
                end
            elseif stage == 2 then
                if api.mythic or api.heroic then
                    local gloom = api.mythic and { 18, 37 } or { 22, 38 }
                    if In(r, 13, 33) then return With(api, SPIRIT, d)
                    elseif r == 70 then return With(api, NIGHTFALL, d)
                    elseif r == 6 then return With(api, DREAD, d)
                    elseif In(r, gloom[1], gloom[2]) then return With(api, GLOOM, d)
                    elseif r == 31 then return With(api, SOULSEVER, d)
                    elseif r == 34 then return With(api, (Cycle(api, 34, { SOULSEVER, DREAD })), d) end
                else
                    if r == 70 then return With(api, NIGHTFALL, d)
                    elseif In(r, 6, 34) then return With(api, DREAD, d)
                    elseif In(r, 20, 40) then return With(api, GLOOM, d)
                    elseif In(r, 32, 33) then return With(api, SOULSEVER, d) end
                end
            elseif stage == 3 then
                if api.mythic then
                    v.s3 = v.s3 + 1
                    if v.s3 > 27 then return false end -- nothing past the enrage
                    if In(r, 62, 90) then return SPIRIT
                    elseif In(r, 55, 48, 104) then return DREAD
                    elseif In(r, 24, 44, 63) then return GLOOM
                    elseif In(r, 2, 41, 60) then return DELUGE
                    elseif In(r, 32, 31, 33, 37) then return BLIGHTED
                    elseif In(r, 17, 64, 100, 56) then return GRIM
                    elseif In(r, 102, 101) then return DEFILEMENT
                    elseif r == 38 then local n = api.Count(38); return n == 1 and NIGHTFALL or n == 2 and GLOOM or nil
                    elseif r == 58 then local n = api.Count(58); return n == 1 and DEFILEMENT or n == 2 and DELUGE or nil
                    elseif r == 97 then local n = api.Count(97); return (n == 1 or n == 4) and NIGHTFALL or n == 2 and DREAD or n == 3 and SPIRIT or nil end
                elseif api.heroic then
                    if In(r, 61, 101, 44, 108) then return DREAD
                    elseif In(r, 39, 100) then return NIGHTFALL
                    elseif In(r, 26, 51, 67, 86) then return GLOOM
                    elseif In(r, 2, 47, 57, 43, 62) or d.r1 == 57.5 then return DELUGE
                    elseif In(r, 32, 34, 38, 25) or d.r1 == 34.5 then return BLIGHTED
                    elseif In(r, 17, 170) then return GRIM
                    elseif In(r, 106, 105) then return DEFILEMENT
                    elseif r == 33 then local n = api.Count(33); return (n == 1 or n == 3) and BLIGHTED or n == 2 and GLOOM or nil
                    elseif r == 60 then local n = api.Count(60); return n == 1 and DEFILEMENT or n == 2 and DELUGE or nil end
                else
                    if In(r, 87, 66) then return NIGHTFALL
                    elseif d.r1 == 53.5 or In(r, 88, 38, 49, 43) then return DREAD
                    elseif In(r, 2, 41, 50, 37, 54) then return DELUGE
                    elseif In(r, 29, 28, 30, 33) then return BLIGHTED
                    elseif In(r, 92, 91) then return DEFILEMENT
                    elseif r == 34 then local n = api.Count(34); return n == 1 and NIGHTFALL or n == 2 and BLIGHTED or nil end
                end
            end
        end,
        finished = function(api, spell)
            if spell == NIGHTFALL and api.Stage() == 2 then
                api.On("UNIT_SPELLCAST_CHANNEL_START", function(api) Intermission(api) end, "boss2")
            end
        end,
        canceled = function(api, spell, bar)
            if spell == NIGHTFALL then Intermission(api)
            elseif spell == FANGS and api.Stage() == 1 then
                -- A cancelled Fangs bar without a newer one ends stage one.
                api.After("fangs", 0.1, function()
                    if api.vars.fangs == bar.data and api.Stage() == 1 then
                        for _, s in ipairs({ DELUGE, AXE, VENOMFANG, GUILLOTINE, SEVER, FANGS }) do api.StopSpell(s) end
                        api.SetStage(2)
                    end
                end)
            end
        end,
    }
end

---------------------------------------------------------------------------
-- The Lost Explorers
do
    local ASCENSION, BLINK, ICEBOUND, SHARDS, VOLLEY, SHELL, THUD, JUNK, FISH, MUSHROOM, SURPRISE =
        1292779, 1290711, 1286921, 1295854, 1295886, 1291759, 1296092, 1291933, 1295817, 1292104, 1296249
    local function Has(events, seconds)
        for _, ev in ipairs(events) do if ev.duration > seconds - 0.5 and ev.duration < seconds + 0.5 then return true end end
    end
    local function Junk(api, d)
        local n = api.Count("junk")
        if d.r == 20 then api.Bar(FISH, 28) end
        return JUNK, { fixed = api.Stage() == 1 and ((d.r == 4 and n == 3) or n >= 4) }
    end
    B[3497] = { name = "The Lost Explorers",
        start = function(api)
            local channel
            api.On("UNIT_SPELLCAST_CHANNEL_START", function(api, unit, guid, spell, castID) channel = castID end, "boss2")
            api.On("UNIT_SPELLCAST_CHANNEL_STOP", function(api, unit, guid, spell, interrupted, castID)
                local ok, same = pcall(function() return castID == channel end)
                if ok and same then
                    channel = nil
                    if api.Stage() ~= 1 then api.SetStage(1) end
                end
            end, "boss2")
        end,
        -- A set of three or more bars shows which explorer is empowered.
        batch = function(api, events)
            if #events < 3 then return end
            local stage = Has(events, 60) and 1 or Has(events, 27) and 2 or Has(events, 11) and 3 or Has(events, 16) and 4
            if stage and stage ~= api.Stage() then api.SetStage(stage) end
        end,
        added = function(api, d)
            local r, stage = d.r, api.Stage()
            if stage == 1 then
                if r == 60 then return ASCENSION
                elseif In(r, 20, 4, 27, 23) then return Junk(api, d)
                elseif r == 30 then return SHARDS
                elseif r == 10 then return BLINK
                elseif In(r, 18, 16, 15) then return SHELL
                elseif r == 5 then return ICEBOUND
                elseif r == 31 then return (Cycle(api, 31, { ICEBOUND, BLINK })) end
            elseif stage == 2 then
                if r == 30 then return SHARDS
                elseif In(r, 2, 16) then return ICEBOUND
                elseif r == 3 then return MUSHROOM
                elseif In(r, 27, 4) then return Junk(api, d)
                elseif r == 13 then return SURPRISE
                elseif In(r, 11, 17, 15, 7) then return SHELL
                elseif r == 32 then return ({ MUSHROOM, SHELL, SURPRISE, ICEBOUND })[api.Count(32)] end
            elseif stage == 3 then
                if In(r, 20, 4, 27) then return Junk(api, d)
                elseif In(r, 3, 32) then return THUD
                elseif r == 30 then return SHARDS
                elseif In(r, 11, 5, 22) then return ICEBOUND end
            elseif stage == 4 then
                if In(r, 7, 4, 11, 23) then return Junk(api, d)
                elseif r == 30 then return SHARDS
                elseif r == 21 then return BLINK
                elseif In(r, 2, 13) then return ICEBOUND
                elseif In(r, 17, 16) then return SHELL
                elseif r == 8 then return VOLLEY
                elseif r == 27 then return ({ VOLLEY, ICEBOUND, SHELL })[api.Count(27)] end
            end
        end,
        canceled = function(api, spell) if spell == JUNK then api.StopBar(FISH) end end,
    }
end

---------------------------------------------------------------------------
-- Ula'tek
do
    local WAVES, CALL, WRATH, RATTLE, THRASH, COILS, SUBMERGE1, RAGE, WOMB, INCUBATION, SPIT, MALICE, GRASP, PREY, SUBMERGE3, BITE, FURY =
        1292188, 1300751, 1298367, 1298559, 1296301, 1300530, 1292999, 1286860, 1310738, 1299757, 1302982, 1290779, 1301117, 1301510, 1300635, 1295905, 1286905
    local FIXED = { fixed = true }
    local function Spit(api, r, fixed)
        if r == 30 then api.Bar(MALICE, 13.5); api.Bar(GRASP, 27) end
        return SPIT, fixed and FIXED or nil
    end
    local function StageTwo(api)
        api.StopSpell(RAGE); api.vars.check = false
        api.Off("UNIT_TARGETABLE_CHANGED")
        api.SetStage(2)
    end
    local skipMythic = { [235] = 1, [205] = 1, [67] = 1, [60] = 1, [55] = 1, [50] = 1, [25] = 1, [10] = 1, [5] = 1 }
    local skipHeroic = { [235] = 1, [205] = 1, [67] = 1, [60] = 1, [50] = 1, [25] = 1, [10] = 1, [5] = 1 }
    local skipEasy = { [230] = 1, [40] = 1, [25] = 1, [200] = 1, [10] = 1, [57] = 1, [5] = 1, [50] = 1 }
    B[3492] = { name = "Ula'tek",
        start = function(api)
            api.vars.check = false
            api.On("UNIT_TARGETABLE_CHANGED", function(api, unit)
                local ok, hostile = pcall(UnitCanAttack, "player", unit)
                if api.vars.check and ok and not hostile then StageTwo(api) end
            end, "boss1")
        end,
        added = function(api, d)
            local v, r, stage = api.vars, d.r, api.Stage()
            -- Stage changes the timeline itself announces.
            if stage == 1 and r == 118 then StageTwo(api); stage = 2
            elseif stage == 2 and r == 10 then api.SetStage(2.5); stage = 2.5
            elseif stage == 2.5 and v.check then v.check = false; api.SetStage(3); stage = 3 end
            if stage == 2.5 then if r == 10 then return COILS end; return end
            if api.mythic then
                if stage < 3 then
                    if In(r, 20, 90) then return RATTLE
                    elseif r == 22 then return WRATH
                    elseif In(r, 33, 94) then return COILS
                    elseif r == 45 then return THRASH, FIXED
                    elseif r == 50 then return WAVES
                    elseif r == 69 then return INCUBATION, { fixed = true, extra = 14 }
                    elseif r == 77 then return SUBMERGE1
                    elseif In(r, 139, 118) then return RAGE
                    elseif r == 1 then
                        local n = api.Count(1)
                        if n == 1 then return INCUBATION, { fixed = true, extra = 14 }
                        elseif n == 2 then api.Bar(WOMB, d.dur + 2.1); return CALL, { fixed = true, extra = 3 } end
                    elseif r == 57 then return api.Count(57) == 1 and THRASH or WAVES, FIXED
                    elseif r == 70 then
                        if api.Count(70) == 1 then api.Bar(WOMB, d.dur + 1.3); return CALL, FIXED end
                        return WRATH
                    elseif In(r, 30, 40) then return Spit(api, r) end
                    return
                end
                local n = api.Count(r)
                if n == 1 and skipMythic[r] then return false end -- the opening set comes twice
                if r == 235 then return FURY
                elseif r == 205 then return RAGE
                elseif In(r, 5, 30, 98) then if r == 5 then api.Bar(WOMB, 57) end; return CALL
                elseif In(r, 10, 85, 68) then return WRATH
                elseif In(r, 25, 64, 104) then return BITE
                elseif r == 55 then if n == 2 then return INCUBATION, { fixed = true, extra = 14 } elseif n == 3 then return WAVES end
                elseif In(r, 50, 44) then return WAVES, FIXED
                elseif In(r, 51, 61, 52) then return PREY, FIXED
                elseif In(r, 67, 53) then return SUBMERGE3, FIXED
                elseif r == 60 then if n == 2 then return PREY, FIXED elseif n == 3 then return SUBMERGE3, FIXED end end
                return
            end
            if api.heroic then
                if stage < 3 then
                    if In(r, 5, 70) then return RATTLE
                    elseif In(r, 10, 37, 67) then return WRATH
                    elseif In(r, 20, 94, 95) then return COILS
                    elseif r == 35 then return THRASH, FIXED
                    elseif r == 42 then return WAVES
                    elseif r == 62 then return SUBMERGE1
                    elseif r == 72 then return CALL, FIXED
                    elseif In(r, 129, 118) then return RAGE
                    elseif r == 52 then if api.Count(52) == 1 then return THRASH, FIXED end; return WAVES
                    elseif In(r, 30, 40) then return Spit(api, r) end
                    return
                end
                local n = api.Count(r)
                if n == 1 and skipHeroic[r] then return false end
                if r == 235 then return FURY
                elseif r == 205 then return RAGE
                elseif In(r, 5, 30, 45) then return CALL
                elseif In(r, 10, 75, 76) then return WRATH
                elseif In(r, 25, 71, 37) then return BITE
                elseif In(r, 50, 55, 44) then return WAVES, FIXED
                elseif In(r, 51, 61, 52) then return PREY, FIXED
                elseif In(r, 67, 53) then return SUBMERGE3, FIXED
                elseif r == 60 then
                    if n == 2 then return PREY, FIXED elseif n == 3 then return CALL elseif n == 4 then return SUBMERGE3, FIXED elseif n == 5 then return BITE end
                end
                return
            end
            if stage < 3 then
                if r == 42 then return WAVES
                elseif In(r, 10, 62) then return WRATH
                elseif In(r, 20, 84) then return COILS
                elseif In(r, 130, 118) then return RAGE
                elseif r == 5 then return RATTLE
                elseif In(r, 35, 41) then return THRASH, FIXED
                elseif In(r, 30, 40) then return Spit(api, r, true) end
                return
            end
            local n = api.Count(r)
            if n == 1 and skipEasy[r] then return false end
            if r == 230 then return FURY
            elseif r == 60 then return WAVES, FIXED
            elseif In(r, 25, 61) then return BITE
            elseif r == 200 then return RAGE
            elseif In(r, 10, 86) then return WRATH
            elseif r == 57 then return SUBMERGE3, FIXED
            elseif In(r, 5, 63) then return CALL
            elseif r == 47 then return PREY
            elseif r == 50 then if n == 2 then return PREY, FIXED elseif n == 3 then return WAVES, FIXED end
            elseif r == 65 then if n == 1 then return CALL elseif n == 2 then return WRATH end
            elseif r == 56 then if n == 1 then return PREY, FIXED elseif n == 2 then return SUBMERGE3, FIXED end
            elseif r == 40 then if n == 2 then return WAVES, FIXED elseif n == 3 then return BITE end
            elseif r == 66 then if n == 1 then return PREY, FIXED elseif n == 2 then return SUBMERGE3, FIXED elseif n == 3 then return BITE end end
        end,
        finished = function(api, spell)
            -- Rage of the Shackled in stage one and the intermission Spectral Coils announce the next stage.
            if spell == RAGE and api.Stage() == 1 then api.vars.check = true
            elseif spell == COILS and api.Stage() == 2.5 then api.vars.check = true end
        end,
    }
end

---------------------------------------------------------------------------
-- Kith'ix
do
    local VOIDSWARM, APPENDAGE, DEVASTATION, EXTINGUISH, EMBRACE, HORRORS, DARKNESS, RADIANCE, GRASP, NULLGATE, NEGATION, ECLIPSE =
        1301511, 1303681, 1304930, 1304424, 1304508, 1304045, 1302951, 1303169, 1303406, 1308873, 1318467, 1301479
    -- Some bars are kept to their full time and dropped when any bar is cancelled in stage one.
    local function Tracked(api, spell)
        api.vars.tracked = true
        return spell, { fixed = true, data = "tracked" }
    end
    local function Extinguish(api, d)
        api.Bar(EMBRACE, d.dur + 2)
        return EXTINGUISH
    end
    B[3513] = { name = "Kith'ix",
        added = function(api, d)
            local r, stage = d.r, api.Stage()
            local gate = api.mythic and 1 or 3
            if stage == 1 and (r == gate or api.easy and r == 121) then api.SetStage(2); stage = 2 end
            if stage == 2 then
                if r == gate then return NULLGATE
                elseif r == (api.mythic and 16 or 15) then return NEGATION
                elseif r == 10 then
                    if api.Count(10) == 1 and not api.lfr then return NEGATION end
                    return Tracked(api, NULLGATE)
                elseif r == 61 or api.easy and r == 121 then return ECLIPSE end
                return
            end
            if api.mythic then
                if r == 5 then return VOIDSWARM
                elseif In(r, 12, 15, 16, 18) then return APPENDAGE
                elseif In(r, 19, 20, 23, 66) then return DEVASTATION
                elseif In(r, 42, 67) then return Extinguish(api, d)
                elseif r == 37 then return HORRORS
                elseif r == 47 then return Tracked(api, HORRORS)
                elseif r == 52 then return DARKNESS
                elseif r == 40 then return RADIANCE
                elseif In(r, 27, 82) then return Tracked(api, GRASP)
                elseif r == 29 then if api.Count(29) == 1 then return Extinguish(api, d) end; return APPENDAGE
                elseif r == 62 then if api.Count(62) == 1 then return GRASP end; return Tracked(api, HORRORS)
                elseif r == 109 then return (Cycle(api, 109, { VOIDSWARM, DARKNESS })) end
            elseif api.heroic then
                if r == 5 then return VOIDSWARM
                elseif In(r, 12, 15, 18, 32) then return APPENDAGE
                elseif In(r, 20, 22, 69) then return DEVASTATION
                elseif r == 57 then return Extinguish(api, d)
                elseif r == 37 then return HORRORS
                elseif In(r, 33, 76) then return Tracked(api, HORRORS)
                elseif r == 40 then return RADIANCE
                elseif r == 62 then return GRASP
                elseif In(r, 27, 82) then return Tracked(api, GRASP)
                elseif r == 29 then if api.Count(29) == 1 then return Extinguish(api, d) end; return APPENDAGE
                elseif r == 52 then if api.Count(52) == 1 then return DARKNESS end; return Extinguish(api, d)
                elseif r == 109 then return (Cycle(api, 109, { VOIDSWARM, DARKNESS })) end
            else
                if r == 5 then return VOIDSWARM
                elseif In(r, 15, 21, 34) then return APPENDAGE
                elseif In(r, 20, 22, 77) then return DEVASTATION
                elseif In(r, 31, 62) then return Extinguish(api, d)
                elseif r == 40 then return HORRORS
                elseif In(r, 37, 82) then return Tracked(api, HORRORS)
                elseif r == 67 then return GRASP
                elseif In(r, 30, 89) then return Tracked(api, GRASP)
                elseif r == 45 then if api.Count(45) == 1 then return DEVASTATION end; return RADIANCE
                elseif r == 57 then if api.Count(57) == 1 then return DARKNESS end; return Extinguish(api, d)
                elseif r == 119 then return (Cycle(api, 119, { VOIDSWARM, DARKNESS })) end
            end
        end,
        anyCanceled = function(api, bars)
            if api.Stage() ~= 1 then return end
            for id, bar in pairs(bars) do if bar.data == "tracked" and not bar.done then api.Drop(id) end end
        end,
        stage = function(api, bars)
            for id, bar in pairs(bars) do if bar.data == "tracked" and not bar.done then api.Drop(id) end end
        end,
    }
end

---------------------------------------------------------------------------
-- The spells each script above announces, in the order it names them, and the bosses in
-- order: the planner lists these abilities for each boss (Journal.lua).
ns.BossTimerOrder = { 3379, 3420, 3455, 3470, 3445, 3421, 3429, 3497, 3492, 3513 }
ns.BossTimerSpells = {
    [3379] = { 1276710, 1257717, 1258668, 1260837, 1282937, 1313393, 1268562 },
    [3420] = { 1285732, 1277025, 1305959, 1285425 },
    [3455] = { 1283164, 1282525, 1281907, 1280935, 1282117 },
    [3470] = { 1285681, 1287426, 1295397, 1287533, 1292036, 1293212, 1305421, 1299673 },
    [3445] = { 1284588, 1296878, 1284251, 1284434, 1284458, 1284483, 1288232, 1284487 },
    [3421] = { 1308556, 1289192, 1290809, 1291404, 1290516, 1303230, 1290956, 1288538, 1306872, 1294293, 1308356 },
    [3429] = { 1299960, 1283832, 1282281, 1283489, 1299680, 1282487, 1289900, 1286918, 1286441, 1286895, 1286573, 1298381, 1299266, 1307279 },
    [3497] = { 1292779, 1290711, 1286921, 1295854, 1295886, 1291759, 1296092, 1291933, 1295817, 1292104, 1296249 },
    [3492] = { 1292188, 1300751, 1298367, 1298559, 1296301, 1300530, 1292999, 1286860, 1310738, 1299757, 1302982, 1290779, 1301117, 1301510, 1300635, 1295905, 1286905 },
    [3513] = { 1301511, 1303681, 1304930, 1304424, 1304508, 1304045, 1302951, 1303169, 1303406, 1308873, 1318467, 1301479 },
}
