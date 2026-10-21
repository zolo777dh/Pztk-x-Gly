import {SPEC_NAMES} from '../core/wow-names.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {execFileSync} from 'node:child_process';
import {deflateRawSync} from 'node:zlib';
import {encodePrint} from '../core/packs.mjs';
import {DoctorService} from '../core/service.mjs';
const resources=path.resolve('resources');
async function fixture(t,client='retail'){const dir=await fs.mkdtemp(path.join(os.tmpdir(),'pztk-unified-reminders-'));t.after(()=>fs.rm(dir,{recursive:true,force:true}));const s=await new DoctorService(dir,resources).init(),p=await s.handle('planner.createProfile',{client}),v=await s.handle('nsr.open',{profileId:p.id});return {s,p,v};}
const reminder=(v,extra={})=>({id:v.id,revision:v.revision,key:'test',encounterId:3470,name:'Use Astral Shift',difficulty:'15',trigger:{type:'pull',delay:30,leadTime:3},target:{specs:{264:true}},display:{type:'icon',spellID:108271,text:'Use defensive',dur:5},...extra});
test('one native Pztk export includes defensive sets, mechanic bindings and timed/phase/message assignments with numeric keys',async t=>{
 const {s,v}=await fixture(t);let n=await s.handle('nsr.change',{id:v.id,revision:v.revision,operation:{kind:'preset.save',args:{specId:264,key:'personal',name:'Personal',spells:[{spellId:108271}]}}});n=await s.handle('nsr.assignRaid',{id:n.id,revision:n.revision,specId:264,seasonId:'MidnightS2',encounterId:3470,spellId:1284103,difficulty:'heroic',preset:'personal'});
 let u=await s.handle('reminders.save',reminder(n));u=await s.handle('reminders.save',reminder(u,{key:'phase',trigger:{type:'stage',stage:2,delay:15,leadTime:0},target:{roles:{HEALER:true}},display:{type:'text',text:'Healing assignment',dur:5}}));u=await s.handle('reminders.save',reminder(u,{key:'mechanic',difficulty:'16',trigger:{type:'bwmsg',spellID:1292036,leadTime:0},target:{names:{'Tester-Realm':true}},display:{type:'raidframeGlow',glowTarget:'Tester',text:'External',dur:5}}));
 const out=await s.handle('reminders.export',{id:u.id,revision:u.revision}),{pack,numericKeys}=s.reminderPack.decode(out.text);assert.deepEqual(pack.data.presets['264'].personal.list,{'1':108271});assert.equal(pack.data.abilityBindings['264']['3470']['1292036'].preset,'personal');assert.equal(pack.data.raidReminders['3470'].test.trigger.delay,30);assert.equal(pack.data.raidReminders['3470'].phase.trigger.stage,2);assert.equal(pack.data.raidReminders['3470'].mechanic.target.names['Tester-Realm'],true);assert.equal(pack.addon,'PztkReminders');assert.ok(numericKeys.some(p=>p.join('/')==='data/raidReminders/3470/test/target/specs/264'));assert.equal((await s.handle('reminders.read',{id:u.id})).reminders.length,3);
 if(process.env.DOCTOR_LUA51){const f=path.join(s.dataDir,'combined.txt');await fs.writeFile(f,out.text);const addon=path.resolve('addon/PztkReminders');const script=`strmatch=string.match
 dofile(${JSON.stringify(addon+'/Libs/LibStub.lua')})
 dofile(${JSON.stringify(addon+'/Libs/LibSerialize.lua')})
 dofile(${JSON.stringify(addon+'/Libs/LibDeflate.lua')})
 function GetBuildInfo()return '12.1.5','70448','',120105 end
 local ns={}
 assert(loadfile(${JSON.stringify(addon+'/Runtime.lua')}))('PztkReminders',ns)
 assert(loadfile(${JSON.stringify(addon+'/Profiles.lua')}))('PztkReminders',ns)
 local f=assert(io.open(${JSON.stringify(f)},'rb'));local input=f:read('*a');f:close()
 local profile,error=ns.Decode(input);assert(profile,error);assert(profile.data.raidReminders[3470].test.target.specs[264])
 local name,error=ns.Import(input);assert(name,error);assert(ns.Active().data.raidReminders[3470].mechanic.difficulties[16])
 local output,error=ns.Export();assert(output,error);local back=assert(ns.Decode(output));assert(ns.Get(back.data.presets,264).personal.list[1]==108271)
 function GetBuildInfo()return '1.60.1','70425','',16001 end
 local bad,error=ns.Import(input);assert(not bad and error:find('belongs to retail',1,true))
 print('PZTK_NATIVE_PROFILE_ACCEPTED')`;const file=path.join(s.dataDir,'native.lua');await fs.writeFile(file,script);assert.match(execFileSync(process.env.DOCTOR_LUA51,[file],{encoding:'utf8'}),/PZTK_NATIVE_PROFILE_ACCEPTED/);}

});
test('NSRT schedules migrate to native Pztk reminders with OR filters, custom TTS, difficulty gates, stable keys and reviewable exclusions',async t=>{
 const {s,v}=await fixture(t);const profile={type:'Profile',payload:{profileName:'Reference',sharedData:{EncounterAlerts:{3470:{15:{a:{enabled:true,DisplayType:'Icon',spellID:108271,TTS:'Use Astral Shift',loadConditions:{SpecIDs:{264:true},Roles:{TANK:true},Difficulties:{15:true},EncounterIDs:{3470:true}},phaseTimers:{1:[30,60],2:[10]}},bad:{enabled:true,DisplayType:'Unknown',timers:[3]},excluded:{enabled:true,loadConditions:{Difficulties:{16:true}},timers:[3]}}}}}},numericKeys:[]};
 const text=s.nsrt.codec.encode(profile),result=await s.handle('reminders.migrateNsrt',{id:v.id,revision:v.revision,text});assert.equal(result.report.created,3);assert.equal(result.report.skipped.length,2);assert.equal(result.view.reminders.length,3);const a=result.view.reminders.find(r=>r.trigger.type==='stage');assert.equal(a.trigger.stage,2);assert.equal(a.trigger.leadTime,10);assert.equal(a.display.dur,10);assert.equal(a.target.matchAny,true);assert.equal(a.target.specs['264'],true);assert.equal(a.target.roles.TANK,true);assert.equal(a.display.ttsText,'Use Astral Shift');assert.equal(a.difficulties['15'],true);
 const repeated=await s.handle('reminders.migrateNsrt',{id:v.id,revision:result.view.revision,text});assert.equal(repeated.view.reminders.length,3);assert.ok((await fs.readdir(path.join(s.planner.dir,'migration-originals'))).length);const encoded=await s.handle('reminders.export',{id:v.id,revision:repeated.view.revision});assert.match(encoded.text,/^PZTK1:/);
});
test('generic HTML/JSON sets join the active profile for any known specialization and survive restart by client',async t=>{
 const {s,p,v}=await fixture(t,'forever'),source={presets:[{id:'personal',name:'Personal',rows:[{label:'Barkskin',ids:[22812]}]}]};const view=await s.handle('reminders.reference',{id:v.id,revision:v.revision,specId:104,filename:'arbitrary.html',text:'<script type="application/json">'+JSON.stringify(source)+'</script>'});assert.equal(view.sets[0].specId,104);assert.deepEqual(view.sets[0].spells,[22812]);const again=await new DoctorService(s.dataDir,resources).init(),state=await again.handle('planner.state',{client:'forever'});assert.equal(state.active.profileId,p.id);const native=await again.handle('nsr.open',{profileId:p.id,resume:true});assert.equal((await again.handle('reminders.read',{id:native.id})).sets[0].spells[0],22812);assert.equal((await again.handle('planner.state',{client:'retail'})).profiles.length,0);
});
test('invalid targets, IDs, difficulty and stale revisions cannot overwrite a working reminder',async t=>{
 const {s,v}=await fixture(t);await assert.rejects(()=>s.handle('reminders.save',reminder(v,{difficulty:'normal'})),/difficulty/);await assert.rejects(()=>s.handle('reminders.save',reminder(v,{target:{specs:{999:true}}})),/specialization/);await assert.rejects(()=>s.handle('reminders.save',reminder(v,{trigger:{type:'script',code:'print(1)'}})),/Choose time/);const u=await s.handle('reminders.save',reminder(v));await assert.rejects(()=>s.handle('reminders.save',reminder(v,{name:'stale'})),/changed elsewhere/);assert.equal((await s.handle('reminders.read',{id:u.id})).reminders[0].name,'Use Astral Shift');
});

test('native PZTK1 profiles retain all 40 specialization sets and enforce client separation on import',async t=>{
 const {s}=await fixture(t),sets=Object.fromEntries(Object.keys(SPEC_NAMES).map(spec=>[spec,{personal:{name:'Personal '+spec,list:[498],together:{}}}]));const input=s.reminderPack.encode({format:1,addon:'PztkReminders',name:'All specs',client:'retail',data:{presets:sets,activePreset:Object.fromEntries(Object.keys(sets).map(spec=>[spec,'personal'])),raidReminders:{}}});
 const imported=await s.handle('reminders.import',{text:input,client:'retail'}),draft=await s.handle('nsr.open',{profileId:imported.id}),out=await s.handle('reminders.export',{id:draft.id,revision:draft.revision}),pack=s.reminderPack.decode(out.text).pack;assert.equal(Object.keys(pack.data.presets).length,40);assert.equal(pack.build,'12.1.5.70448');await assert.rejects(()=>s.handle('reminders.import',{text:input,client:'forever'}),/belongs to retail/);assert.equal((await s.handle('planner.state',{client:'forever'})).profiles.length,0);
});

test('desktop and game refuse malformed binding displays and target flags before they can reach runtime callbacks',async t=>{
 const {s}=await fixture(t),base={format:1,addon:'PztkReminders',name:'Invalid data test',client:'retail',data:{}},bad=[];
 for(const binding of [{enabled:'false'},{display:42},{display:{dur:'five'}},{display:{text:{}}}])bad.push({...structuredClone(base),data:{abilityBindings:{264:{3470:{123:binding}}}}});
 for(const target of [{all:'false'},{matchAny:42}])bad.push({...structuredClone(base),data:{raidReminders:{3470:{r:{trigger:{type:'pull',delay:10},target,display:{type:'text',text:'Invalid'}}}}}});
 for(const pack of bad)assert.throws(()=>s.reminderPack.encode(pack),/Invalid/);
 if(process.env.DOCTOR_LUA51){
  const addon=path.resolve('addon/PztkReminders'),inputs=[];
  for(const [i,pack]of bad.entries()){const file=path.join(s.dataDir,'invalid-'+i+'.txt');await fs.writeFile(file,'PZTK1:'+encodePrint(deflateRawSync(s.codec.invoke('encode',pack))));inputs.push(file);}
  const script=`strmatch=string.match
  dofile(${JSON.stringify(addon+'/Libs/LibStub.lua')})
  dofile(${JSON.stringify(addon+'/Libs/LibSerialize.lua')})
  dofile(${JSON.stringify(addon+'/Libs/LibDeflate.lua')})
  local ns={};assert(loadfile(${JSON.stringify(addon+'/Profiles.lua')}))('PztkReminders',ns)
  for _,path in ipairs({${inputs.map(p=>JSON.stringify(p)).join(',')}})do local f=assert(io.open(path,'rb'));local text=f:read('*a');f:close();local profile,error=ns.Decode(text);assert(profile==nil and error=='Unsupported profile data')end
  print('MALFORMED_PROFILE_REFUSED')`;
  const file=path.join(s.dataDir,'invalid.lua');await fs.writeFile(file,script);assert.match(execFileSync(process.env.DOCTOR_LUA51,[file],{encoding:'utf8'}),/MALFORMED_PROFILE_REFUSED/);
 }
});

test('text reminders omit blank spell IDs and 0.4.0 exports recover that optional sentinel in desktop and native Lua',async t=>{
 const {s,v}=await fixture(t),view=await s.handle('reminders.save',reminder(v,{display:{type:'text',text:'Text only',dur:5,spellID:'',sound:'',glowTarget:''}}));
 let exported=await s.handle('reminders.export',{id:view.id,revision:view.revision}),pack=s.reminderPack.decode(exported.text).pack;
 assert.equal(pack.data.raidReminders['3470'].test.display.spellID,undefined);
 const draft=await s.nsrEditor.read(view.id),data=draft.pack.data||draft.pack.profiles[draft.profileKey];data.raidReminders['3470'].test.display.spellID='';await s.nsrEditor.save(draft);
 exported=await s.handle('reminders.export',{id:view.id,revision:view.revision});assert.equal(s.reminderPack.decode(exported.text).pack.data.raidReminders['3470'].test.display.spellID,undefined);
 assert.equal((await s.nsrEditor.read(view.id)).pack.data.raidReminders['3470'].test.display.spellID,'','source working copy is retained');
 pack.data.raidReminders['3470'].test.display.spellID='';const legacy='PZTK1:'+encodePrint(deflateRawSync(s.codec.invoke('encode',pack)));
 assert.equal(s.reminderPack.decode(legacy).pack.data.raidReminders['3470'].test.display.spellID,undefined);
 if(process.env.DOCTOR_LUA51){const addon=path.resolve('addon/PztkReminders'),file=path.join(s.dataDir,'legacy.txt');await fs.writeFile(file,legacy);const script=`strmatch=string.match
 dofile(${JSON.stringify(addon+'/Libs/LibStub.lua')});dofile(${JSON.stringify(addon+'/Libs/LibSerialize.lua')});dofile(${JSON.stringify(addon+'/Libs/LibDeflate.lua')})
 local ns={};assert(loadfile(${JSON.stringify(addon+'/Profiles.lua')}))('PztkReminders',ns)
 local f=assert(io.open(${JSON.stringify(file)},'rb'));local text=f:read('*a');f:close();local pack,error=ns.Decode(text);assert(pack,error)
 local entries=pack.data.raidReminders[3470]or pack.data.raidReminders['3470'];assert(entries.test.display.spellID==nil);print('LEGACY_BLANK_ID_RECOVERED')`;
 const lua=path.join(s.dataDir,'legacy.lua');await fs.writeFile(lua,script);assert.match(execFileSync(process.env.DOCTOR_LUA51,[lua],{encoding:'utf8'}),/LEGACY_BLANK_ID_RECOVERED/);}
});

test('an authored dynamic defensive prevents deleting the preset it still references',async t=>{
 const {s,v}=await fixture(t);const n=await s.handle('nsr.change',{id:v.id,revision:v.revision,operation:{kind:'preset.save',args:{specId:264,key:'personal',name:'Personal',spells:[{spellId:108271}]}}});
 const u=await s.handle('reminders.save',reminder(n,{defensive:{specID:264,preset:'personal'},display:{type:'icon',text:'',dur:3}}));
 await assert.rejects(()=>s.handle('nsr.change',{id:u.id,revision:u.revision,operation:{kind:'preset.delete',args:{specId:264,key:'personal'}}}),/still assigned/);
 assert.equal((await s.handle('reminders.read',{id:u.id})).sets[0].key,'personal');
});

test('native scoped sets retain both content collections through desktop editing, reference imports and complete export',async t=>{
 const {s}=await fixture(t);const input=s.reminderPack.encode({format:1,addon:'PztkReminders',name:'In-game profile',client:'retail',data:{scopePresets:{mythic:{104:{p:{name:'Dungeon',list:[22812]}}},raid:{104:{p:{name:'Raid',list:[61336]}}}},scopeActivePreset:{mythic:{104:'p'},raid:{104:'p'}},raidReminders:{3470:{r:{name:'Raid defensive',content:'raid',trigger:{type:'bwmsg',spellID:1284103,delay:0},target:{specs:{104:true}},defensive:{specID:104,preset:'p',scope:'raid'},display:{type:'icon',text:'',dur:4}}}}}});
 const p=await s.handle('reminders.import',{text:input,client:'retail'}),draft=await s.handle('nsr.open',{profileId:p.id}),view=await s.handle('reminders.read',{id:draft.id});assert.equal(view.hasScopedSets,true);assert.equal(view.sets.length,2);const e=view.reminders[0];let edited=await s.handle('reminders.save',{...e,id:view.id,revision:view.revision,difficulty:'16',enabled:true,defensive:{...e.defensive,scope:'raid'},trigger:{...e.trigger,delay:2}});
 const ref={presets:[{id:'new',name:'New raid set',rows:[{label:'Barkskin',ids:[22812]}]}]};edited=await s.handle('reminders.reference',{id:edited.id,revision:edited.revision,specId:104,scope:'raid',filename:'reference.json',text:JSON.stringify(ref)});const out=await s.handle('reminders.export',{id:edited.id,revision:edited.revision}),back=s.reminderPack.decode(out.text).pack;assert.equal(back.minimumAddon,'0.3.0');assert.equal(Object.keys(back.data.scopePresets.mythic['104']).length,1);assert.equal(Object.keys(back.data.scopePresets.raid['104']).length,2);assert.equal(back.data.raidReminders['3470'].r.defensive.scope,'raid');assert.equal(back.data.raidReminders['3470'].r.trigger.delay,2);
});
