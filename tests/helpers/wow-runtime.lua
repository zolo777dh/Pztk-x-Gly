-- Minimal WoW API stand-ins for running NaowhDefensivePlanner outside the game.
strmatch, strsub, strbyte, strchar, strfind, strlen, format = string.match, string.sub, string.byte, string.char, string.find, string.len, string.format
tinsert, tremove, unpack, loadstring = table.insert, table.remove, unpack or table.unpack, loadstring or load
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
local now = 100
T = { timers = {}, displays = {}, glows = {}, stopped = {}, printed = {} }
function GetTime() return now end
function T.Advance(seconds)
    now = now + seconds
    local due = true
    while due do
        due = false
        table.sort(T.timers, function(a, b) return a.at < b.at end)
        for i, timer in ipairs(T.timers) do
            if timer.at <= now then table.remove(T.timers, i); if not timer.cancelled then timer.callback() end; due = true; break end
        end
    end
end
C_Timer = { NewTimer = function(delay, callback)
    local timer = { at = now + delay, callback = callback }
    function timer:Cancel() self.cancelled = true end
    T.timers[#T.timers + 1] = timer
    return timer
end }
local function mock()
    local object = {}
    return setmetatable(object, { __index = function(_, key)
        if key == "GetFont" then return function() return "font", 12, "" end end
        if key == "CreateTexture" or key == "CreateFontString" then return function() return mock() end end
        return function() end
    end })
end
function CreateFrame() return mock() end
UIParent = mock()
function print(...) T.printed[#T.printed + 1] = table.concat({ ... }, " ") end
function GetBuildInfo() return "12.1.5", "70448", "", 120105 end
function GetInstanceInfo() return "Raid", "raid", 16, "", 20, 0, false, 2900 end
function GetSpecialization() return 1 end
function GetSpecializationInfo() return 65 end
function UnitGroupRolesAssigned() return "HEALER" end
function UnitClass() return "Paladin", "PALADIN" end
T.units = { player = { "Healbot", "Realm" }, raid2 = { "Tankadin", "Realm" } }
function UnitExists(unit) return T.units[unit] ~= nil end
function UnitFullName(unit) local u = T.units[unit]; if u then return u[1], u[2] end end
function UnitName(unit) local u = T.units[unit]; return u and u[1] end
function IsInRaid() return true end
function UnitIsUnit(a, b) return a == b end
function GetRaidRosterInfo() end
C_AddOns = { IsAddOnLoaded = function() return false end, GetAddOnMetadata = function() return "test" end }
function PlaySoundFile() end
function InCombatLockdown() return false end
SlashCmdList = {}
-- Encounter Journal: two planned bosses on map 2401, the player standing next to the second.
T.pins = { { encounterID = 11, mapX = 0.2, mapY = 0.2 }, { encounterID = 12, mapX = 0.8, mapY = 0.8 } }
T.position = { 0.75, 0.8 }
C_Map = {
    GetBestMapForUnit = function() return 2401 end,
    GetPlayerMapPosition = function() if T.position then return { GetXY = function() return T.position[1], T.position[2] end } end end,
}
C_EncounterJournal = { GetEncountersOnMap = function() return T.pins end }
function EJ_GetEncounterInfo(id) return "Boss", "", id, 0, "", 1, ({ [11] = 3183, [12] = 3176 })[id], 2900 end
-- Frame lookups and glows are recorded instead of drawn.
local groupFrames = {}
for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do groupFrames[#groupFrames + 1] = unit end
for i = 1, 40 do groupFrames[#groupFrames + 1] = "raid" .. i end
for i, unit in ipairs(groupFrames) do groupFrames[i] = { unit = unit, GetAttribute = function(self, key) return key == "unit" and self.unit or nil end, IsVisible = function() return true end } end
function EnumerateFrames(after)
    if not after then return groupFrames[1] end
    for i, f in ipairs(groupFrames) do if f == after then return groupFrames[i + 1] end end
end
local registry = {}
function LibStub(name)
    if name == "LibCustomGlow-1.0" then return {
        PixelGlow_Start = function(frame, color, _, _, _, _, _, _, _, key) T.glows[#T.glows + 1] = { unit = frame.unit, color = color, key = key } end,
        PixelGlow_Stop = function(frame, key) T.stopped[#T.stopped + 1] = frame.unit end,
    } end
    return registry[name]
end
