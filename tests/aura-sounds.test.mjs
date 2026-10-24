import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import fengari from 'fengari';
const runtime=await fs.readFile('addon/PuzatikDefensivePlanner/Runtime.lua','utf8'),rules=await fs.readFile('addon/PuzatikDefensivePlanner/RuleRuntime.lua','utf8'),auras=await fs.readFile('addon/PuzatikDefensivePlanner/AuraSounds.lua','utf8');
function execute(script){const {lua,lauxlib,lualib,to_luastring}=fengari,L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);try{if(lauxlib.luaL_loadstring(L,to_luastring(script))!==lua.LUA_OK||lua.lua_pcall(L,0,0,0)!==lua.LUA_OK)throw Error(lua.lua_tojsstring(L,-1));}finally{lua.lua_close(L);}}
const fixture=`local ns={};local profile;local combat=false;local now=0;local spec=264;local frames={};local handles={};local nextId=1;local added,removed=0,0;local muted={};local known={[100]=true,[20594]=true,[58984]=false};local cds={};local usable=true;local dead=false;local secret={};local shown={};local pending={}
function GetTime()return now end
function GetSpecialization()return 1 end
function GetSpecializationInfo()return spec end
function InCombatLockdown()return combat end
function UnitIsDeadOrGhost()return dead end
function issecretvalue(v)return v==secret end
function CreateFrame()local f={};function f:RegisterEvent()end;function f:SetScript(_,fn)self.callback=fn end;frames[#frames+1]=f;return f end
C_SpellBook={IsSpellKnown=function(s)return known[s]==true end}
C_Spell={GetSpellCooldown=function(s)return cds[s]or{isActive=false,isEnabled=true,startTime=0,duration=0}end,IsSpellUsable=function()return usable end}
C_Timer={NewTimer=function(delay,fn)local t={at=now+delay,fn=fn};function t:Cancel()self.cancelled=true end;pending[#pending+1]=t;return t end}
Enum={UnitAuraSoundTrigger={Added=1,Removed=2,ApplicationsIncreased=3}}
C_UnitAuras={AddAuraSound=function(trigger,info)assert(not combat,'registration in combat');local id=nextId;nextId=nextId+1;handles[id]={trigger=trigger,info=info};added=added+1;return id end,RemoveAuraSound=function(id)assert(not combat,'removal in combat');handles[id]=nil;removed=removed+1 end}
function MuteSoundFile(path)assert(path:find('PuzatikDefensivePlanner',1,true));muted[path]=true end
function UnmuteSoundFile(path)assert(path:find('PuzatikDefensivePlanner',1,true));muted[path]=false end
${[runtime,rules].map(s=>`;(function(...)\n${s}\nend)('PuzatikDefensivePlanner',ns);`).join('\n')}
ns.Store=function()return {active='p',profiles={p=profile}}end
ns.SoundPath=function(key)if not key or key=='none'then return nil end;return 'Interface/AddOns/PuzatikDefensivePlanner/'..key end
ns.Display=function(display)shown[#shown+1]=display end
ns.SpellLabel=function(spell)return 'Fixture spell '..spell end
;(function(...)\n${auras}\nend)('PuzatikDefensivePlanner',ns)
local function rule(spell,sound)return {enabled=true,trigger={type='auraSound',mapID=456,spellID=spell,target='player',auraEvent='Added'},display={sound=sound,text='',dur=3}}end
profile={data={settings={enabled=true,voiceOn=true},presets={[264]={p={list={100}}}},activePreset={[264]='p'},callouts={[100]='Fixture callout'},integrationRules={[264]={a=rule(600,'voice:stoneform-ready'),b=rule(601,'voice:shadowmeld-ready')}}}}
ns.map=456;ns.instanceType='party'
local function event(name)frames[1].callback(nil,name)end
local function advance(time)now=time;for _,t in ipairs(pending)do if not t.cancelled and not t.fired and t.at<=now then t.fired=true;t.fn()end end end
`;
test('native aura registrations are scoped/deduplicated and private racial files follow public readiness, not aura reads',()=>execute(fixture+`
ns.RefreshAuraSounds();ns.RefreshAuraSounds();assert(added==2)
assert(muted[ns.SoundPath('voice:stoneform-ready')]==false);assert(muted[ns.SoundPath('voice:shadowmeld-ready')]==true)
cds[20594]={isActive=true,isEnabled=true};event('SPELL_UPDATE_COOLDOWN');assert(muted[ns.SoundPath('voice:stoneform-ready')])
cds[20594]={isActive=secret,isEnabled=true};event('SPELL_UPDATE_COOLDOWN');assert(muted[ns.SoundPath('voice:stoneform-ready')])
cds[20594]=nil;event('SPELL_UPDATE_USABLE');assert(not muted[ns.SoundPath('voice:stoneform-ready')]);assert(added==2)
ns.map=999;ns.RefreshAuraSounds();assert(removed==2)
`));
test('combat profile changes mute owned files immediately and defer registrations until restrictions end',()=>execute(fixture+`
ns.RefreshAuraSounds();combat=true;profile={data={settings={enabled=true},integrationRules={}}};ns.Reset();ns.RefreshAuraSounds()
assert(muted[ns.SoundPath('voice:stoneform-ready')]);assert(removed==0);assert(ns.AuraSoundStatus():find('pending',1,true))
combat=false;ns.RefreshAuraSounds();assert(removed==2);assert(not muted[ns.SoundPath('voice:stoneform-ready')])
`));
test('missing native APIs and rejected/muting-failed registrations are reported without enabling an unsafe racial sound',()=>execute(fixture+`
local api=C_UnitAuras;C_UnitAuras=nil;ns.RefreshAuraSounds();assert(added==0 and ns.AuraSoundStatus():find('unavailable',1,true))
C_UnitAuras=api;MuteSoundFile=function()error('unavailable')end;ns.RefreshAuraSounds();assert(added==0);assert(ns.AuraSoundStatus():find('API failures',1,true))
`));
test('delayed authored defensives honor occurrence conditions, callouts and stale/spec cancellation',()=>execute(fixture+`
profile.data.integrationRules={};profile.data.raidReminders={[123]={r={enabled=true,trigger={type='bwmsg',spellID=400,delay=2,counterGroups={{{op='>',value=1}}}},target={specs={[264]=true}},defensive={specID=264,preset='p'},display={type='icon',text='',dur=3}}}}
profile.data.abilityBindings={[264]={[123]={[400]={enabled=true,preset='p'}}}}
ns.Begin(123,8,456);ns.Mechanic(400,nil,'message');advance(3);assert(#shown==0)
ns.Mechanic(400,nil,'message');advance(4);assert(#shown==0);advance(5);assert(#shown==1 and shown[1].spellID==100 and shown[1].text=='Fixture spell 100'and shown[1].ttsText=='Fixture callout'and shown[1].tts)
ns.Mechanic(400,nil,'message');ns.Reset();advance(10);assert(#shown==1)
ns.Begin(123,8,456);spec=65;ns.Mechanic(400,nil,'message');advance(20);assert(#shown==1)
`));
test('overlapping delayed mechanic messages remain independent and bar cancellation cannot discard them',()=>execute(fixture+`
profile.data.integrationRules={};profile.data.raidReminders={[123]={r={enabled=true,trigger={type='bwmsg',spellID=400,delay=18},target={specs={[264]=true}},defensive={specID=264,preset='p'},display={type='icon',text='',dur=3}}}}
ns.Begin(123,8,456);ns.Mechanic(400,nil,'message');advance(5);ns.Mechanic(400,nil,'message')
ns.Cancel('ability:message:');advance(18);assert(#shown==1);advance(23);assert(#shown==2)
`));

test('defensive selection uses public cooldown flags when timestamps are secret, and never confuses empty charges with an inactive cooldown',()=>execute(fixture+`
known[100]=true;C_Spell.GetSpellCooldown=function()return{startTime=secret,duration=secret,isEnabled=true,isActive=false,isOnGCD=false}end
assert(ns.Pick({list={100}})[1]==100)
C_Spell.GetSpellCharges=function()return{currentCharges=0,maxCharges=2,isActive=false}end;assert(#ns.Pick({list={100}})==0)
C_Spell.GetSpellCharges=function()return{currentCharges=secret,maxCharges=2,isActive=true}end;assert(#ns.Pick({list={100}})==0)
C_Spell.GetSpellCharges=nil;C_Spell.GetSpellCooldown=function()return{startTime=secret,duration=secret,isEnabled=true,isActive=secret,isOnGCD=false}end;assert(#ns.Pick({list={100}})==0)
`));

test('defensive calls always carry the actual spell name/icon while custom trash text without a set remains usable',()=>execute(fixture+`
ns.RenderDefensive({preset='p',display={type='text',text='Boss context'}},true)
assert(shown[1].type=='icon'and shown[1].spellID==100 and shown[1].text:find('Fixture spell 100',1,true))
ns.RenderDefensive({display={type='text',text='Custom mechanic warning'}},true)
assert(shown[2].text=='Custom mechanic warning')
`));
