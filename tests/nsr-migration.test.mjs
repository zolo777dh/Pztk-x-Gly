import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {PackCodec} from '../core/packs.mjs';
import {ReminderPack} from '../core/reminder-pack.mjs';
import {encodeCbor,decodeCbor} from '../core/cbor.mjs';
import {deflateRawSync,inflateRawSync} from 'node:zlib';
import {migrateNsrData,parseReminderCounter,parseReminderDelays} from '../core/nsr-migration.mjs';
const codec=new PackCodec(path.resolve('resources')),native=new ReminderPack(codec);
const data=()=>({presets:{264:{personal:{name:'Fixture set',list:[100,200]}}},activePreset:{264:'personal'},bindingsBySpec:true,voiceNone:'Fixture fallback',leadTime:2,settings:{enabled:true,voiceOn:true,showIcon:true,showText:true,showBar:false,voiceVol:80,pos:{point:'CENTER',relPoint:'CENTER',x:12,y:18}},callouts:{100:'Fixture callout'},abilityBindings:{264:{123:{400:{enabled:true,preset:'personal'}}}},integrationRules:{264:{a:{name:'Fixture aura',enabled:true,trigger:{type:'auraSound',mapID:456,spellID:600,target:'player',auraEvent:'Added'},display:{type:'icon',dur:3,text:'',sound:'voice:stoneform-ready'}},b:{name:'Fixture trash',enabled:true,preset:'personal',trigger:{type:'exboss',mapID:456,spellID:700,timeleft:3},display:{type:'icon',text:'',dur:3,tts:true}}}},customReminders:{123:{custom:{name:'Fixture delayed defensive',enabled:true,specID:264,defensive:true,preset:'personal',dur:3,trigger:{type:'bwmsg',spellID:400,counter:'>1',delay:'2'}}}}});

test('NSR migration includes aura sounds, authored defensives, settings and callouts without changing source or attribution',()=>{
 const source=data(),before=structuredClone(source),r=migrateNsrData(source);assert.deepEqual(source,before);assert.equal(r.report.counts.auraSound,1);assert.equal(r.report.counts.exboss,1);assert.equal(r.report.counts.customConverted,1);assert.equal(r.report.counts.customSkipped,0);assert.equal(r.warnings.length,0);
 assert.equal(r.data.callouts[100],'Fixture callout');assert.deepEqual(r.data.settings,source.settings);
 const entry=Object.values(r.data.raidReminders[123])[0];assert.equal(entry.defensive.preset,'personal');assert.equal(entry.trigger.delay,2);assert.deepEqual(entry.trigger.counterGroups,[[{op:'>',value:1}]]);assert.equal(entry.target.specs[264],true);
 const decoded=codec.decode(codec.encode({format:1,name:'Fixture',derivedFrom:{author:'Fixture author'},data:source}),{withKeys:true});const out=native.fromDraft(decoded,'retail');assert.equal(native.decode(out.text).pack.derivedFrom.author,'Fixture author');assert.equal(out.payload.minimumAddon,'0.2.0');
 // Strings exported before the 0.7.3 rename (!NDP1:, addon NaowhDefensivePlanner) still decode.
 {const old='!NDP1:'+deflateRawSync(encodeCbor({...decodeCbor(inflateRawSync(Buffer.from(out.text.slice(6),'base64'))).data,addon:'NaowhDefensivePlanner'})).toString('base64');assert.equal(native.decode(old).pack.derivedFrom.author,native.decode(out.text).pack.derivedFrom.author);}
 assert.throws(()=>native.fromDraft({...decoded,pack:{...decoded.pack,licensed:true}},'retail'),/Licensed/);
});

test('scoped reports distinguish the same rule IDs in different specs and identify absent presets and unavailable settings',()=>{
 const source=data();source.integrationRules[65]={a:{enabled:true,trigger:{type:'unknown'}}};source.integrationRules[264].bad={enabled:true,trigger:{type:'unknown'}};source.abilityBindings[264][123][400].preset='absent';source.settings.coveredSkip=true;
 const r=migrateNsrData(source);assert.equal(r.report.counts.auraSound,1);assert.equal(r.report.issues.filter(i=>i.section==='integrationRules').length,2);assert.ok(r.report.issues.some(i=>i.specId===65&&i.key==='a'));assert.ok(r.report.issues.some(i=>i.specId===264&&i.key==='bad'));assert.ok(r.report.issues.some(i=>i.section==='abilityBindings'&&i.reason.includes('absent')));assert.ok(r.report.issues.some(i=>i.section==='settings'&&i.key==='coveredSkip'));assert.equal(source.integrationRules[65].a.trigger.type,'unknown');
});

test('counter and delay parsing preserves OR/AND and clock notation; unknown conditions are reported instead of widened',()=>{
 assert.deepEqual(parseReminderDelays('2, 1:30.5'),[2,90.5]);assert.deepEqual(parseReminderCounter('>3,+<7,10'),[[{op:'>',value:3},{op:'<',value:7}],[{op:'=',value:10}]]);assert.throws(()=>parseReminderCounter('sometimes'),/Unsupported counter/);
 const source=data();source.customReminders[123].custom.trigger.counter='sometimes';const result=migrateNsrData(source);assert.equal(result.report.counts.customSkipped,1);assert.equal(Object.keys(result.data.raidReminders).length,0);assert.ok(result.report.issues[0].reason.includes('counter'));
});

test('native Lua accepts and roundtrips migrated profiles, including the private user fixture when explicitly available',async t=>{
 const input=process.env.DOCTOR_NSR_MIGRATION_INPUT?await fs.readFile(process.env.DOCTOR_NSR_MIGRATION_INPUT,'utf8'):codec.encode({format:1,name:'Migration fixture',data:data()});
 const decoded=codec.decode(input,{withKeys:true}),out=native.fromDraft(decoded,'retail'),back=native.decode(out.text).pack;
 assert.equal(out.report.counts.customConverted,out.report.counts.customSource);assert.equal(out.report.counts.customSkipped,0);assert.equal(Object.values(back.data.integrationRules).flatMap(Object.values).filter(r=>r.trigger.type==='auraSound').length,out.report.counts.auraSound);
 const original=decoded.pack.data;assert.equal(out.report.counts.specializations,Object.keys(original.presets).length);assert.equal(out.report.counts.defensiveSets,Object.values(original.presets).flatMap(Object.values).length);assert.equal(out.report.counts.callouts,Object.keys(original.callouts||{}).length);
 if(!process.env.DOCTOR_LUA51)return;
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'pztk-nsr-migration-'));t.after(()=>fs.rm(dir,{recursive:true,force:true}));const file=path.join(dir,'pack.txt');await fs.writeFile(file,out.text);const addon=path.resolve('addon/PuzatikDefensivePlanner');
 const script=`strmatch=string.match
 dofile(${JSON.stringify(addon+'/Libs/LibStub.lua')});dofile(${JSON.stringify(addon+'/Libs/LibSerialize.lua')});dofile(${JSON.stringify(addon+'/Libs/LibDeflate.lua')})
 local ns={};function GetBuildInfo()return '12.1.5','70448','',120105 end
 assert(loadfile(${JSON.stringify(addon+'/Runtime.lua')}))('PuzatikDefensivePlanner',ns)
 assert(loadfile(${JSON.stringify(addon+'/Codec.lua')}))('PuzatikDefensivePlanner',ns);assert(loadfile(${JSON.stringify(addon+'/Profiles.lua')}))('PuzatikDefensivePlanner',ns)
 local f=assert(io.open(${JSON.stringify(file)},'rb'));local input=f:read('*a');f:close();local p,e=ns.Decode(input);assert(p,e)
 local name,error=ns.Import(input);assert(name,error);local output=assert(ns.Export());assert(ns.Decode(output));local aura,trash,timed=0,0,0
 for _,rules in pairs(p.data.integrationRules)do for _,r in pairs(rules)do if r.trigger.type=='auraSound'then aura=aura+1 else trash=trash+1 end end end
 for _,entries in pairs(p.data.raidReminders)do for _,r in pairs(entries)do if r.pztkOrigin then timed=timed+1 end end end
 assert(aura==${out.report.counts.auraSound} and trash==${out.report.counts.exboss} and timed==${out.report.counts.customConverted})
 print('MIGRATED_NATIVE_PROFILE_ACCEPTED')`;
 const lua=path.join(dir,'check.lua');await fs.writeFile(lua,script);assert.match(execFileSync(process.env.DOCTOR_LUA51,[lua],{encoding:'utf8'}),/MIGRATED_NATIVE_PROFILE_ACCEPTED/);
});
