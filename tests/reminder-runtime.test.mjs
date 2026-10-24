import test from 'node:test';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import fengari from 'fengari';
const {lua,lauxlib,lualib,to_luastring}=fengari;
const runtime=await fs.readFile('addon/PuzatikDefensivePlanner/Runtime.lua','utf8');
function execute(script){const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);try{if(lauxlib.luaL_loadstring(L,to_luastring(script))!==lua.LUA_OK||lua.lua_pcall(L,0,0,0)!==lua.LUA_OK)throw Error(lua.lua_tojsstring(L,-1));}finally{lua.lua_close(L);}}
const fixture=`local ns={};local now=0;local loaded={};local pending={};local displayed={};local secret={};local cooldowns={};local known={};local role='HEALER';local current
function GetTime()return now end
function GetSpecialization()return 1 end
function GetSpecializationInfo()return 264 end
function UnitGroupRolesAssigned()return role end
function UnitName()return 'Tester' end
function UnitFullName()return 'Tester','Other Realm' end
function UnitClass()return 'Shaman','SHAMAN' end
function GetRaidRosterInfo()return nil end
function issecretvalue(v)return v==secret end
C_AddOns={IsAddOnLoaded=function(name)return loaded[name]end}
C_SpellBook={IsSpellKnown=function(spell)return known[spell]~=false end}
C_Spell={GetSpellCooldown=function(spell)return cooldowns[spell]or {startTime=0,duration=0,isEnabled=true}end}
C_Timer={NewTimer=function(delay,fn)local t={at=now+delay,fn=fn};function t:Cancel()self.cancelled=true end;pending[#pending+1]=t;return t end}
(function(...) ${runtime}\nend)('PuzatikDefensivePlanner',ns)
ns.Store=function()return {active='p',profiles={p=current}}end
ns.Display=function(d)displayed[#displayed+1]=d end
local function advance(t)now=t;for _,timer in ipairs(pending)do if not timer.cancelled and not timer.fired and timer.at<=now then timer.fired=true;timer.fn()end end end
`;
test('independent runtime targets specs/roles/names, preserves OR filters and gates difficulty',()=>execute(fixture+`
assert(ns.Target({specs={[264]=true}}));assert(not ns.Target({specs={[65]=true}}))
assert(ns.Target({names={['Tester-OtherRealm']=true}}));assert(not ns.Target({names={['Tester-WrongRealm']=true}}))
assert(not ns.Target({roles={TANK=true},specs={[264]=true}}));assert(ns.Target({matchAny=true,roles={TANK=true},specs={[264]=true}}))
ns.difficulty=15;assert(ns.Difficulty({difficulties={[15]=true}}));assert(not ns.Difficulty({difficulties={[16]=true}}))
`));
test('pull / phase schedules cancel on phase reset and stale profiles; prefix keys do not swallow sibling reminders',()=>execute(fixture+`
current={data={raidReminders={[3470]={a={trigger={type='pull',delay=30,leadTime=5},target={roles={HEALER=true}},difficulties={[15]=true},display={text='a'}},ab={trigger={type='pull',delay=30,leadTime=5},display={text='ab'}},phase={trigger={type='stage',stage=2,delay=10},display={text='phase'}}}}}}
ns.Begin(3470,15,2813);advance(24);assert(#displayed==0);advance(25);assert(#displayed==2)
ns.Phase(2);advance(30);ns.Phase(3);advance(40);assert(#displayed==2)
ns.Begin(3470,15,2813);current={data={}};advance(100);assert(#displayed==2)
`));
test('defensive selection respects known spells, Together groups and inaccessible cooldowns without inspecting secrets',()=>execute(fixture+`
assert(ns.Pick({list={100,200}})[1]==100);known[100]=false;assert(ns.Pick({list={100,200}})[1]==200)
known[100]=true;cooldowns[100]={startTime=secret,duration=secret};assert(ns.Pick({list={100,200}})[1]==200)
cooldowns[100]=nil;local group=ns.Pick({list={100,200,300},together={[100]=true,[200]=true}});assert(#group==2)
cooldowns[100]={startTime=0,duration=secret};assert(ns.Pick({list={100,200,300},together={[100]=true,[200]=true}})[1]==300)
`));
test('ability timers and ExBoss trash bind to selected spec/map; conflicting reminder addons pause dispatch',()=>execute(fixture+`
current={data={presets={[264]={personal={list={108271}}}},activePreset={[264]='personal'},abilityBindings={[264]={[3470]={[123]={enabled=true,preset='personal',leadTime=3}}}},integrationRules={[264]={r={enabled=true,preset='personal',trigger={type='exboss',spellID=456,mapID=2813,timeleft=2}}}},raidReminders={}}}
ns.Begin(3470,15,2813);ns.Mechanic(123,10,'bar');advance(6);assert(#displayed==0);advance(7);assert(#displayed==1 and displayed[1].spellID==108271)
ns.Trash(456,5,'trash');advance(10);assert(#displayed==2)
ns.map=999;ns.Trash(456,5,'wrong');advance(20);assert(#displayed==2)
loaded.NaowhSmartReminders=true;ns.Mechanic(123,10,'blocked');advance(100);assert(#displayed==2)
loaded.NaowhSmartReminders=nil;ns.Mechanic(secret,secret,'secret');assert(#displayed==2)
`));
