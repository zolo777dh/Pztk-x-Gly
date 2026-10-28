-- The few Naowh Defensive Planner helpers the party cooldowns need, so they run on their own.
-- Comms.lua, Widgets.lua, PartyCooldowns.lua and the window media are copied from Naowh Defensive Planner when packaging.
local _,ns=...
ns.version=C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("NDPPartyCooldowns","Version")or"standalone"
function ns.Plain(value,kind)return not(issecretvalue and issecretvalue(value))and(not kind or type(value)==kind)end
function ns.Spec()
    local get=GetSpecialization or(C_SpecializationInfo and C_SpecializationInfo.GetSpecialization)
    local info=GetSpecializationInfo or(C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo)
    if not get or not info then return nil end
    local index=get();local spec=index and info(index)
    return ns.Plain(spec,"number")and spec or nil
end
function ns.Clone(value)
    if type(value)~="table"then return value end
    local out={};for k,v in pairs(value)do out[k]=ns.Clone(v)end;return out
end
ns.ClassSpecs={WARRIOR={71,72,73},PALADIN={65,66,70},HUNTER={253,254,255},ROGUE={259,260,261},PRIEST={256,257,258},DEATHKNIGHT={250,251,252},
    SHAMAN={262,263,264},MAGE={62,63,64},WARLOCK={265,266,267},MONK={268,270,269},DRUID={102,103,104,105},DEMONHUNTER={577,581,1480},EVOKER={1467,1468,1473}}
-- Specialization names, as Naowh Defensive Planner's catalog has them.
ns.Catalog={specs={[62]="Arcane Mage",[63]="Fire Mage",[64]="Frost Mage",[65]="Holy Paladin",[66]="Protection Paladin",[70]="Retribution Paladin",[71]="Arms Warrior",[72]="Fury Warrior",[73]="Protection Warrior",[102]="Balance Druid",[103]="Feral Druid",[104]="Guardian Druid",[105]="Restoration Druid",[250]="Blood Death Knight",[251]="Frost Death Knight",[252]="Unholy Death Knight",[253]="Beast Mastery Hunter",[254]="Marksmanship Hunter",[255]="Survival Hunter",[256]="Discipline Priest",[257]="Holy Priest",[258]="Shadow Priest",[259]="Assassination Rogue",[260]="Outlaw Rogue",[261]="Subtlety Rogue",[262]="Elemental Shaman",[263]="Enhancement Shaman",[264]="Restoration Shaman",[265]="Affliction Warlock",[266]="Demonology Warlock",[267]="Destruction Warlock",[268]="Brewmaster Monk",[269]="Windwalker Monk",[270]="Mistweaver Monk",[577]="Havoc Demon Hunter",[581]="Vengeance Demon Hunter",[1467]="Devastation Evoker",[1468]="Preservation Evoker",[1473]="Augmentation Evoker",[1480]="Devourer Demon Hunter"},spellNames={}}
ns.L=function(text)return text end
ns.ExtraPages={}
-- With Naowh Defensive Planner enabled, it already shows these cooldowns: this addon stays off.
function ns.FullAddonLoaded()
    local loaded=C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return loaded and loaded("NaowhDefensivePlanner")and true or false
end
local idle={partycds={enabled=false}}
function ns.Store()
    if ns.FullAddonLoaded()then return idle end
    NDPPartyCooldownsDB=NDPPartyCooldownsDB or{}
    local store=NDPPartyCooldownsDB
    -- On by default here: tracking is the only thing this addon does.
    if not store.partycds then store.partycds={enabled=true,mode="frames"}end
    return store
end
