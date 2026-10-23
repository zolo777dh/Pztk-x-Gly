import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {DoctorService} from '../core/service.mjs';
import {NsrtCodec} from '../core/nsrt.mjs';
import {nsrtEncounterAlerts} from '../core/reminder-planner.mjs';

const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const codec=new NsrtCodec();
const nsrt=(type,payload)=>codec.encode({type,payload,numericKeys:[]});
const alert=(extra={})=>({name:'Soak',text:'Soak',enabled:true,IsAlert:true,DisplayType:'Text',dur:5,phase:1,timers:[30],loadConditions:{},...extra});

async function planner(){
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'pztk-nsrt-'));
 const service=await new DoctorService(dir,path.join(root,'resources')).init();
 const profile=await service.handle('planner.createProfile',{client:'retail'});
 const opened=await service.handle('nsr.open',{profileId:profile.id,profileKey:''});
 const view=await service.handle('reminders.read',{id:opened.id??opened});
 return {service,view};
}
async function migrate(text){
 const {service,view}=await planner();
 const result=await service.handle('reminders.migrateNsrt',{id:view.id,revision:view.revision,text});
 return {service,...result};
}
const migrated=(view,enc='3183')=>view.reminders.filter(r=>String(r.encounterId)===enc&&r.pztkMigration?.source==='NSRT');

test('single alert export migrates its one alert',async()=>{
 const {view,report}=await migrate(nsrt('EncounterAlert',{version:1,type:'single_alert',alertType:'user',encID:3183,diffID:16,alertKey:'soak1',data:alert()}));
 assert.equal(report.created,1);
 const [r]=migrated(view);
 assert.equal(r.trigger.type,'pull');assert.equal(r.trigger.delay,30);assert.deepEqual(r.difficulties,{16:true});
});

test('single alert export without encounter or difficulty is refused',()=>{
 assert.throws(()=>nsrtEncounterAlerts(codec.decode(nsrt('EncounterAlert',{version:1,type:'single_alert',data:alert()}))),/single alert/);
});

test('alert group export migrates the group encounter and honours diffID',async()=>{
 const {view,report}=await migrate(nsrt('EncounterAlert',{version:1,type:'alert_group',groupName:'Soaks',groupEncID:3183,diffID:15,groupMeta:{},encounterAlerts:{3183:{15:{a:alert({group:'Soaks'})},16:{b:alert({group:'Soaks'})}}}}));
 assert.equal(report.created,1);assert.deepEqual(migrated(view)[0].difficulties,{15:true});
});

test('encounter-scoped alerts export without diffID is keyed by difficulty, not encounter',()=>{
 const alerts=nsrtEncounterAlerts(codec.decode(nsrt('EncounterAlert',{version:1,type:'alerts',encID:3183,encounterAlerts:{16:{a:alert()}}})));
 assert.deepEqual(Object.keys(alerts),['3183']);assert.deepEqual(Object.keys(alerts['3183']),['16']);
});

test('glowunit becomes glow targets alongside the original display',async()=>{
 const {view,report}=await migrate(nsrt('EncounterAlert',{version:1,type:'alerts',encounterAlerts:{3183:{16:{g:alert({DisplayType:'Icon',spellID:370597,glowunit:'Healbot Tankadin glowunit',glowColors:[1,0,0,1]})}}}}));
 const [r]=migrated(view);
 assert.equal(r.display.type,'icon');
 assert.deepEqual(r.display.glowTargets,['Healbot','Tankadin']);
 assert.deepEqual(r.display.glowColor,[1,0,0,1]);
 assert.ok(report.warnings.some(w=>/glow targets/.test(w)));
 assert.ok(!report.skipped.length);
});

test('negative phase-1 times become pre-pull countdown triggers',async()=>{
 const {service,view,report}=await migrate(nsrt('Profile',{profileName:'x',data:{ReminderSettings:{}},sharedData:{EncounterAlerts:{3183:{16:{p:alert({dur:4,timers:[-10,20]})}}}}}));
 const rs=migrated(view).sort((a,b)=>a.trigger.delay-b.trigger.delay);
 assert.equal(rs.length,2);
 const pre=rs.find(r=>r.trigger.type==='prepull'),pull=rs.find(r=>r.trigger.type==='pull');
 assert.deepEqual(pre.trigger,{type:'prepull',delay:10,leadTime:4});assert.equal(pre.display.dur,4);
 assert.equal(pull.trigger.delay,20);
 assert.equal(report.warnings.filter(w=>/pre-pull/.test(w)).length,1);
 const exported=await service.handle('reminders.export',{id:view.id,revision:view.revision});
 assert.equal(exported.payload.minimumAddon,'0.3.3');
 const decoded=service.reminderPack.decode(exported.text).pack;
 assert.ok(Object.values(decoded.data.raidReminders['3183']).some(e=>e.trigger.type==='prepull'&&e.trigger.delay===10));
});

test('negative times outside phase 1 are skipped with a warning',async()=>{
 await assert.rejects(migrate(nsrt('EncounterAlert',{version:1,type:'alerts',encounterAlerts:{3183:{16:{p:alert({phaseTimers:{2:[-5]}})}}}})),/No supported NSRT reminders/);
});

test('glow targets survive PZTK1 export and decode',async()=>{
 const {service,view}=await migrate(nsrt('EncounterAlert',{version:1,type:'single_alert',encID:3183,diffID:16,alertKey:'g',data:alert({glowunit:'Healbot'})}));
 const exported=await service.handle('reminders.export',{id:view.id,revision:view.revision});
 const entry=Object.values(service.reminderPack.decode(exported.text).pack.data.raidReminders['3183'])[0];
 // The Lua codec returns sequences as {1:…} tables.
 assert.deepEqual(Object.values(entry.display.glowTargets),['Healbot']);assert.equal(exported.payload.minimumAddon,'0.3.3');
});

test('profiles without the new features keep their older addon minimum',async()=>{
 const {service,view}=await migrate(nsrt('EncounterAlert',{version:1,type:'single_alert',encID:3183,diffID:16,alertKey:'s',data:alert()}));
 assert.notEqual((await service.handle('reminders.export',{id:view.id,revision:view.revision})).payload.minimumAddon,'0.3.3');
});

test('editor saves pre-pull triggers and glow targets, and rejects bad values',async()=>{
 const {service,view}=await planner();
 const base={id:view.id,encounterId:3183,name:'Pre-pot',difficulty:'16',target:{all:true}};
 let v=await service.handle('reminders.save',{...base,revision:view.revision,key:'pot',trigger:{type:'prepull',delay:'3',leadTime:'2'},display:{type:'text',text:'Pot',dur:'2',glowTargets:'Healbot  Tankadin',glowColor:'0 1 0'}});
 const e=v.reminders.find(r=>r.key==='pot');
 assert.deepEqual(e.trigger,{type:'prepull',delay:3,leadTime:2});
 assert.deepEqual(e.display.glowTargets,['Healbot','Tankadin']);assert.deepEqual(e.display.glowColor,[0,1,0,1]);
 await assert.rejects(service.handle('reminders.save',{...base,revision:v.revision,key:'bad',trigger:{type:'prepull',delay:'0'},display:{type:'text',text:'x'}}),/0\.1 to 3600/);
 await assert.rejects(service.handle('reminders.save',{...base,revision:v.revision,key:'bad',trigger:{type:'pull',delay:'1'},display:{type:'text',text:'x',glowTargets:'a',glowColor:'2 0 0'}}),/Glow colour/);
 v=await service.handle('reminders.save',{...base,revision:v.revision,key:'pot',trigger:{type:'prepull',delay:'3'},display:{type:'text',text:'Pot',glowTargets:''}});
 const cleared=v.reminders.find(r=>r.key==='pot');
 assert.equal(cleared.display.glowTargets,undefined);assert.equal(cleared.display.glowColor,undefined);
});
