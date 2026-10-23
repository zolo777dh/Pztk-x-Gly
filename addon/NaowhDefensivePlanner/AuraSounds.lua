-- The game owns aura detection. This module never reads aura contents.
local _,ns=...
local registrations={}
local gates={
    ["voice:stoneform-ready"]={spell=20594},
    ["voice:shadowmeld-ready"]={spell=58984},
}
local status="Not initialized"

local function Busy()
    if InCombatLockdown and InCombatLockdown()then return true end
    if ns.encounter then return true end
    local api,types,states=C_RestrictedActions,Enum and Enum.AddOnRestrictionType,Enum and Enum.AddOnRestrictionState
    if api and api.GetAddOnRestrictionState and types and states then
        for _,kind in ipairs({types.Combat,types.Encounter})do
            local ok,value=pcall(api.GetAddOnRestrictionState,kind)
            if not ok or not ns.Plain(value)or value~=states.Inactive then return true end
        end
    end
    return false
end

local function Readiness(spell)
    local known=C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell
    if not known or not C_Spell or not C_Spell.GetSpellCooldown or not C_Spell.IsSpellUsable or not UnitIsDeadOrGhost then return false,"readiness API unavailable"end
    local ok,value=pcall(known,spell)
    if not ok or not ns.Plain(value,"boolean")or not value then return false,"spell unknown or unreadable"end
    ok,value=pcall(UnitIsDeadOrGhost,"player")
    if not ok or not ns.Plain(value,"boolean")or value then return false,"player state unavailable or dead"end
    ok,value=pcall(C_Spell.GetSpellCooldown,spell)
    if not ok or not ns.Plain(value,"table")or not ns.Plain(value.isActive,"boolean")or not ns.Plain(value.isEnabled,"boolean")then return false,"cooldown unreadable"end
    if value.isActive or not value.isEnabled then return false,"cooldown active or disabled"end
    ok,value=pcall(C_Spell.IsSpellUsable,spell)
    if not ok or not ns.Plain(value,"boolean")or not value then return false,"spell unusable or unreadable"end
    return true,"ready"
end

local function SetMuted(key,muted)
    local gate=gates[key]
    if gate.muted==muted then return true end
    local fn=muted and MuteSoundFile or UnmuteSoundFile
    if type(fn)~="function"then return false end
    local ok=pcall(fn,ns.SoundPath(key))
    if ok then gate.muted=muted end
    return ok
end

local function RefreshGates()
    for key,gate in pairs(gates)do
        if gate.allowed then
            local ready,reason=Readiness(gate.spell)
            gate.reason=reason;SetMuted(key,not ready)
        elseif gate.used then gate.reason="registration change pending or disabled";SetMuted(key,true)
        else gate.reason="not registered";SetMuted(key,false)end
    end
end

function ns.SuspendAuraSounds()
    for key,gate in pairs(gates)do gate.allowed=false;if gate.used then SetMuted(key,true)end end
end

function ns.RefreshAuraSounds()
    local api=C_UnitAuras
    if not(api and type(api.AddAuraSound)=="function"and type(api.RemoveAuraSound)=="function"and Enum and Enum.UnitAuraSoundTrigger)then
        ns.SuspendAuraSounds();status="Native AddAuraSound API unavailable; aura rules remain in the profile.";return
    end
    local wanted,missing={},0
    local profile=ns.Active()
    if ns.Enabled()and(not ns.ContentMatches or ns.ContentMatches({}))and(ns.instanceType=="party"or ns.instanceType=="raid")then
        for _,rule in pairs(ns.Get(profile.data.integrationRules,ns.Spec())or{})do
            local t=rule.trigger or{}
            if rule.enabled~=false and t.type=="auraSound"and(t.mapID==0 or t.mapID==ns.map)then
                local sound=rule.display and rule.display.sound
                local path=ns.SoundPath(sound)
                local gate=gates[sound]and sound or nil
                if gate and(type(MuteSoundFile)~="function"or type(UnmuteSoundFile)~="function")then path=nil end
                local trigger=Enum.UnitAuraSoundTrigger[t.auraEvent]
                if path and trigger~=nil then
                    local units=t.target=="party"and{"party1","party2","party3","party4"}or{"player"}
                    for _,unit in ipairs(units)do
                        local key=unit..":"..t.spellID..":"..t.auraEvent..":"..path
                        wanted[key]={trigger=trigger,gate=gate,info={unitToken=unit,spellID=t.spellID,soundFileName=path,outputChannel="Master"}}
                    end
                else missing=missing+1 end
            end
        end
    end
    local same=true
    for key in pairs(registrations)do if not wanted[key]then same=false;break end end
    if same then for key in pairs(wanted)do if not registrations[key]then same=false;break end end end
    local pending=Busy()and not same
    local failed=0
    if not pending then
        for key,entry in pairs(registrations)do
            if not wanted[key]then
                local ok=pcall(api.RemoveAuraSound,entry.handle)
                if ok then registrations[key]=nil else failed=failed+1 end
            end
        end
        for key,entry in pairs(wanted)do
            if not registrations[key]then
                -- Gate our private file BEFORE the client can play its new registration.
                local safe=true
                if entry.gate then gates[entry.gate].used=true;safe=SetMuted(entry.gate,true)end
                if safe then
                    local ok,handle=pcall(api.AddAuraSound,entry.trigger,entry.info)
                    if ok and ns.Plain(handle)and handle~=nil and handle~=false then registrations[key]={handle=handle,gate=entry.gate}
                    else failed=failed+1 end
                else failed=failed+1 end
            end
        end
    end
    for _,gate in pairs(gates)do gate.used,gate.allowed=false,false end
    local count=0
    for key,entry in pairs(registrations)do
        count=count+1
        if entry.gate then gates[entry.gate].used=true;if not pending and wanted[key]then gates[entry.gate].allowed=true end end
    end
    RefreshGates()
    status=count.." native aura sound registrations; "..missing.." unavailable sound rules; "..failed.." API failures"..(pending and"; changes pending until restrictions end"or"")
end

function ns.AuraSoundStatus()
    local lines={status}
    for _,key in ipairs({"voice:stoneform-ready","voice:shadowmeld-ready"})do local gate=gates[key];lines[#lines+1]=key..": "..(gate.reason or"not registered")end
    return table.concat(lines,"\n")
end

function ns.ShutdownAuraSounds()
    if C_UnitAuras and C_UnitAuras.RemoveAuraSound and not Busy()then for _,entry in pairs(registrations)do pcall(C_UnitAuras.RemoveAuraSound,entry.handle)end end
    for key in pairs(gates)do SetMuted(key,false)end
end

local events=CreateFrame("Frame")
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGOUT"then ns.ShutdownAuraSounds()
    elseif event=="ADDON_RESTRICTION_STATE_CHANGED"then ns.RefreshAuraSounds()
    else RefreshGates()end
end)
for _,event in ipairs({"SPELL_UPDATE_COOLDOWN","SPELL_UPDATE_USABLE","SPELLS_CHANGED","PLAYER_DEAD","PLAYER_ALIVE","PLAYER_UNGHOST","PLAYER_LOGOUT"})do events:RegisterEvent(event)end
if C_RestrictedActions and C_RestrictedActions.GetAddOnRestrictionState and Enum and Enum.AddOnRestrictionType then events:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")end
