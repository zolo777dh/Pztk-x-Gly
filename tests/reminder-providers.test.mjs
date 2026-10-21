import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import fengari from 'fengari';
import luaparse from 'luaparse';

const files=['Runtime.lua','Providers.lua'];
const sources=await Promise.all(files.map(f=>fs.readFile('addon/PztkReminders/'+f,'utf8')));
const providerRoot=process.env.DOCTOR_TIMER_TEST_ROOT;
function method(source,base,name){
 const tree=luaparse.parse(source,{ranges:true,luaVersion:'5.1'});
 const node=tree.body.find(n=>n.type==='FunctionDeclaration'&&n.identifier?.base?.name===base&&n.identifier.identifier.name===name);
 assert.ok(node,base+':'+name);return source.slice(...node.range);
}
const portableBus=`local callbacks={}
function public:RegisterMessage(event,fn)assert(self~=public);callbacks[event]=fn end
function public:SendMessage(event,...)if callbacks[event]then callbacks[event](event,...)end end`;
let bus=portableBus,bossMethods='',schedulerMethods='';
if(providerRoot){
 const loader=await fs.readFile(path.join(providerRoot,'BigWigs/Loader.lua'),'utf8');
 const tree=luaparse.parse(loader,{ranges:true,luaVersion:'5.1'});
 const block=tree.body.find(n=>n.type==='DoStatement'&&n.body.some(m=>m.type==='FunctionDeclaration'&&m.identifier?.identifier?.name==='RegisterMessage'));
 assert.ok(block);bus=loader.slice(...block.range);
 const boss=await fs.readFile(path.join(providerRoot,'BigWigs_Core/BossPrototype.lua'),'utf8');
 bossMethods=['StopBar','PauseBar','ResumeBar'].map(name=>method(boss,'boss',name)).join('\n');
 const scheduler=await fs.readFile(path.join(providerRoot,'EXBoss/ExBossEngine/Scheduler.lua'),'utf8');
 schedulerMethods=['RegisterTrashLocalTimer','_AdvanceTrashFixedCombatTimeline','_RemoveActiveTimerByID','GetActiveTimers'].map(name=>method(scheduler,'Scheduler',name)).join('\n');
}
function execute(code){const {lua,lauxlib,lualib,to_luastring}=fengari,L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);try{if(lauxlib.luaL_loadstring(L,to_luastring(code))!==lua.LUA_OK||lua.lua_pcall(L,0,0,0)!==lua.LUA_OK)throw Error(lua.lua_tojsstring(L,-1));}finally{lua.lua_close(L);}}
const fixture=`local ns={};local now=0;local pending={};local shown={};local current;local loaded={};local dbm={};local secrets={}
function GetTime()return now end
function GetSpecialization()return 1 end
function GetSpecializationInfo()return 264 end
function issecretvalue(value)return value==secrets end
C_AddOns={IsAddOnLoaded=function(name)return loaded[name]end}
C_SpellBook={IsSpellKnown=function()return true end}
C_Spell={GetSpellCooldown=function()return {startTime=0,duration=0,isEnabled=true}end}
C_Timer={NewTimer=function(delay,fn)local t={at=now+delay,fn=fn};function t:Cancel()self.cancelled=true end;pending[#pending+1]=t;return t end}
local function advance(time)now=time;for _,t in ipairs(pending)do if not t.cancelled and not t.fired and t.at<=now then t.fired=true;t.fn()end end end
local function hooksecurefunc(object,key,fn)local original=object[key];object[key]=function(...)local result=original(...);fn(...);return result end end
_G.hooksecurefunc=hooksecurefunc
local public={};local mod={};local CTimerAfter=function(_,fn)fn()end;local securecallfunction=function(fn,...)return fn(...)end
${bus}
BigWigsLoader=public
DBM={RegisterCallback=function(self,event,fn)dbm[event]=fn end}
local boss={engageId=3470,Debug=function()end};boss.SendMessage=public.SendMessage
local spells={};local CL={};local format=string.format;local checkFlag=function()return false end;local C={COUNTDOWN=1}
${bossMethods||`function boss:StopBar(text)self:SendMessage('BigWigs_StopBar',self,text)end
function boss:PauseBar(key,text)self:SendMessage('BigWigs_PauseBar',self,text)end
function boss:ResumeBar(key,text)self:SendMessage('BigWigs_ResumeBar',self,text)end`}
${sources.map(s=>`;(function(...)\n${s}\nend)('PztkReminders',ns);`).join('\n')}
ns.Store=function()return {active='p',profiles={p=current}}end
ns.Display=function(display)shown[#shown+1]=display end
ns.Print=function()end
local function profile()
 current={data={presets={[264]={personal={list={108271}}}},activePreset={[264]='personal'},abilityBindings={[264]={[3470]={[123]={enabled=true,preset='personal',leadTime=3}}}},integrationRules={[264]={trash={enabled=true,preset='personal',trigger={type='exboss',mapID=2813,spellID=456,timeleft=2}}}},raidReminders={}}}
 ns.Begin(3470,15,2813)
end
local function timer(module,spell,seconds,text)public:SendMessage('BigWigs_Timer',module,spell,seconds,seconds,text,1,1,false,true)end
`;

test('BigWigs text cancellation, module isolation and pause/resume use inspected provider callback arguments',()=>execute(fixture+`
profile();ns.ConnectProviders();local other={engageId=3470}
timer(boss,123,10,'One');timer(other,123,10,'Two')
boss:StopBar('One');advance(7);assert(#shown==1,'only the other module may fire')
timer(boss,123,10,'Paused');advance(9);boss:PauseBar(123,'Paused');advance(30);assert(#shown==1)
boss:ResumeBar(123,'Paused');advance(34);assert(#shown==1);advance(35);assert(#shown==2)
timer(boss,123,10,'Wipe');public:SendMessage('BigWigs_OnBossWipe',boss);advance(100);assert(#shown==2);assert(not ns.encounter)
`));

test('BigWigs mechanic messages do not cancel a countdown or duplicate its defensive; unrelated modules cannot change the phase',()=>execute(fixture+`
profile();current.data.raidReminders[3470]={message={trigger={type='bwmsg',spellID=123},display={type='text',text='Message'}}}
ns.ConnectProviders();timer(boss,123,10,'Cast');advance(2);public:SendMessage('BigWigs_Message',boss,123,'Info');advance(3)
assert(#shown==1 and shown[1].text=='Message');advance(7);assert(#shown==2 and shown[2].spellID==108271)
public:SendMessage('BigWigs_SetStage',{engageId=999},2);assert(ns.phase==1)
public:SendMessage('BigWigs_SetStage',boss,2);assert(ns.phase==2)
`));

test('the first BigWigs bars survive when its encounter-start frame runs before the addon frame',()=>execute(fixture+`
profile();ns.Reset();ns.ConnectProviders();timer(boss,123,10,'First cast')
ns.Begin(3470,15,2813);advance(7);assert(#shown==1)
ns.Reset();timer(boss,123,10,'Cancelled first cast');boss:StopBar('Cancelled first cast');ns.Begin(3470,15,2813)
advance(30);assert(#shown==1)
`));

test('provider registration failures can retry and leave DBM callbacks usable',()=>execute(fixture+`
profile();local register=public.RegisterMessage;local attempts=0
public.RegisterMessage=function(...)attempts=attempts+1;error('temporary unavailable')end
ns.ConnectProviders();dbm.DBM_TimerBegin('DBM_TimerBegin','id','Cast',10,1,'cd',123);advance(7);assert(#shown==1)
public.RegisterMessage=register;ns.ConnectProviders();timer(boss,123,10,'Ready');advance(14);assert(#shown==2);assert(attempts>0)
`));

test('DBM message/stage arguments and stop IDs stay distinct from spell IDs when BigWigs is absent',()=>execute(fixture+`
BigWigsLoader=nil;profile();current.data.raidReminders[3470]={message={trigger={type='bwmsg',spellID=123},display={type='text',text='DBM message'}}}
ns.ConnectProviders();dbm.DBM_TimerBegin('DBM_TimerBegin','timer-id','Cast',10,1,'cd',123)
dbm.DBM_TimerStop('DBM_TimerStop','timer-id');advance(10);assert(#shown==0)
dbm.DBM_Announce('DBM_Announce','Message',1,'spell',123);advance(11);assert(#shown==2)
dbm.DBM_SetStage('DBM_SetStage',{},'boss',2,3470,2);assert(ns.phase==2)
`));

const schedulerFixture=`
BigWigsLoader=nil;DBM=nil
ExBoss={Timeline={}}
local Scheduler={_active={},_nextTimerID=1};ExBoss.Timeline.Scheduler=Scheduler
function Scheduler:EnsureTrashLocalRuntime()end
local TrashRuntimeConfig=nil
local TIMERBAR_LEAD_TIME,DEFAULT_PREALERT_SECS=30,5
local SafeNum=function(value,fallback)return tonumber(value)or fallback end
local IsTrashFixedCombatTimelineSpell=function(spell)return spell.fixed==true end
local ApplyTrashTimelineMeta=function()end
local ApplyFixedVoiceTriggerConfig=function()end
local GetTrashFixedCombatTimelineStep=function(spell)return spell.step end
local ResetTrashTimerForNextFixedCombatTimeline=function(t,at)t.castTime=at end
${schedulerMethods||`function Scheduler:RegisterTrashLocalTimer(runtime,mob,spell,remaining,meta)
 runtime.localTimerIDsBySpellID=runtime.localTimerIDsBySpellID or {};local id=runtime.localTimerIDsBySpellID[spell.spellID]or self._nextTimerID
 self._nextTimerID=id+1;runtime.localTimerIDsBySpellID[spell.spellID]=id
 local t=self._active[id]or {id=id};self._active[id]=t;t.source='trash';t.spellID=spell.spellID;t.castTime=now+remaining;t.trashRuntime=runtime;t.trashSpellData=spell;t.trashFixedCombatTimeline=spell.fixed;return id
end
function Scheduler:_AdvanceTrashFixedCombatTimeline(t,time)t.castTime=t.castTime+t.trashSpellData.step;return true end
function Scheduler:_RemoveActiveTimerByID(id)self._active[id]=nil end
function Scheduler:GetActiveTimers()return self._active end`}
`;
test('ExBoss corrections, removal, existing timers and fixed next cycles do not deliver stale or repeated reminders',()=>execute(fixture+schedulerFixture+`
profile();local runtime={nextSpellAnchorAt={[456]=1}};local spell={spellID=456,name='Cast'}
local id=Scheduler:RegisterTrashLocalTimer(runtime,{npcID=1},spell,10,{})
ns.ConnectProviders();ns.ConnectProviders();advance(8);assert(#shown==1)
Scheduler:RegisterTrashLocalTimer(runtime,{npcID=1},spell,5,{});advance(11);assert(#shown==1,'same cycle correction must not repeat')
runtime.nextSpellAnchorAt[456]=2;Scheduler:RegisterTrashLocalTimer(runtime,{npcID=1},spell,10,{})
Scheduler._active[id].castTime=99;advance(30);assert(#shown==1,'a changed deadline must not deliver an obsolete alert')
Scheduler:RegisterTrashLocalTimer(runtime,{npcID=1},spell,10,{});Scheduler:_RemoveActiveTimerByID(id);advance(40);assert(#shown==1)
spell.fixed=true;spell.step=10;id=Scheduler:RegisterTrashLocalTimer(runtime,{npcID=1},spell,10,{})
advance(48);assert(#shown==2);Scheduler:_AdvanceTrashFixedCombatTimeline(Scheduler._active[id],50);advance(58);assert(#shown==3)
`));

test('opening BigWigs mechanic messages replay once after encounter start and stale messages are discarded',()=>execute(fixture+`
profile();current.data.abilityBindings={};current.data.raidReminders[3470]={message={trigger={type='bwmsg',spellID=123,delay=2},display={type='text',text='Opening'}}}
ns.Reset();ns.ConnectProviders();public:SendMessage('BigWigs_Message',boss,123,'Info');advance(0.1);assert(#shown==0)
ns.Begin(3470,15,2813);advance(2.2);assert(#shown==1 and shown[1].text=='Opening')
ns.Reset();public:SendMessage('BigWigs_Message',boss,123,'Info');advance(5);ns.Begin(3470,15,2813);advance(10);assert(#shown==1)
`));
