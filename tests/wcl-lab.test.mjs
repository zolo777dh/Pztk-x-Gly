import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {WclLab,labArguments,redactLab} from '../core/wcl-lab.mjs';
const resources=fileURLToPath(new URL('../resources',import.meta.url));
async function temporary(t){const dir=await fs.mkdtemp(path.join(os.tmpdir(),'pztk-wcl-lab-'));t.after(()=>fs.rm(dir,{force:true,recursive:true}));return dir;}
async function fakeEngine(t,script){const dir=await temporary(t),helper=path.join(dir,'helper.cjs');await fs.writeFile(helper,script);const calls=[];const lab=await new WclLab(dir,resources,{platform:'win32',spawnProcess:(exe,args,options)=>{calls.push({exe,args,options});return spawn(process.execPath,[helper,...args],options);},credentialFile:path.join(dir,'credentials.dat')}).init();lab.executable=async()=>{await fs.mkdir(lab.engineDir,{recursive:true});return process.execPath;};t.after(()=>lab.close());return {lab,dir,calls};}

test('Lab builds fixed CLI argument arrays, preserves paths and rejects unsafe URLs/flags',()=>{
 const input=path.resolve('saved exports','test & data.zip');const args=labArguments({mode:'reanalyze',input,spec:'holypaladin'},'/out');assert.deepEqual(args,['--reanalyze',input,'--spec','holypaladin','--output','/out']);
 const link='https://www.warcraftlogs.com/reports/6dXM3p91Pv4ZVTfq?fight=57&source=12';assert.equal(labArguments({mode:'live',links:link+'\n'+link},'/out')[1],link);
 assert.throws(()=>labArguments({mode:'live',links:'https://evil.example/reports/6dXM3p91Pv4ZVTfq'},'/out'),/official/);assert.throws(()=>labArguments({mode:'live',links:link+'&token=secret'},'/out'),/credentials/);
 assert.throws(()=>labArguments({mode:'top',targets:'e3159; calc.exe'},'/out'),/zone IDs/);assert.throws(()=>labArguments({mode:'top',targets:'e3159',maxPerRun:100},'/out'),/Maximum logs/);assert.throws(()=>labArguments({mode:'validate',spec:'--command'},'/out'),/specialization/);assert.throws(()=>labArguments({mode:'shell'},'/out'),/supported/);
 assert.deepEqual(labArguments({mode:'survey',survey:'Paladin:Holy:hps,Priest:Shadow:dps',encounters:'3420,12813'},'/out'),['--spec-survey','Paladin:Holy:hps,Priest:Shadow:dps','--encounters','3420,12813','--output','/out']);
});
test('Lab runs a child without a shell, persists success, redacts secrets and bounds result preview',async t=>{
 const {lab,calls}=await fakeEngine(t,`const fs=require('node:fs'),path=require('node:path');const out=process.argv[process.argv.indexOf('--output')+1];console.log('Authorization: Bearer fixture-secret');console.log('client_secret=fixture-secret');fs.writeFileSync(path.join(out,'validate_install_report.json'),'\\uFEFF'+JSON.stringify({app:'fixture',outputWritable:true,access_token:'fixture-secret'}));fs.writeFileSync(path.join(out,'large.csv'),'time,name\\n'+('1,cast\\n'.repeat(40000)));setTimeout(()=>{},80);`);
 const started=await lab.start({mode:'validate'});await assert.rejects(()=>lab.start({mode:'validate'}),/already running/);assert.ok(!('child'in started));await lab.run(started.id).done;
 const run=lab.run(started.id);assert.equal(run.status,'completed');assert.equal(calls[0].options.shell,false);assert.equal(calls[0].options.windowsHide,true);assert.ok(!JSON.stringify(await lab.status()).includes('fixture-secret'));assert.ok(!(await fs.readFile(path.join(lab.runsDir,run.id,'run.json'),'utf8')).includes('fixture-secret'));
 const preview=await lab.preview(run.id,'large.csv');assert.equal(preview.truncated,true);assert.ok(preview.text.length<=160000);await assert.rejects(()=>lab.preview(run.id,'../run.json'),/Select a file/);
 const reopened=await new WclLab(path.dirname(lab.dir),resources,{platform:'win32'}).init();assert.equal(reopened.run(run.id).status,'completed');
});
test('Lab cancellation, child failure and missing result reports do not become successful analyses',async t=>{
 const {lab}=await fakeEngine(t,"setInterval(()=>{},1000)");const r=await lab.start({mode:'validate'});await lab.cancel(r.id);await lab.run(r.id).done;assert.equal(lab.run(r.id).status,'cancelled');
 const failed=await fakeEngine(t,'process.exitCode=7');const f=await failed.lab.start({mode:'validate'});await failed.lab.run(f.id).done;assert.equal(failed.lab.run(f.id).status,'failed');assert.equal(failed.lab.run(f.id).exitCode,7);
 const missing=await fakeEngine(t,'process.exitCode=0');const m=await missing.lab.start({mode:'validate'});await missing.lab.run(m.id).done;assert.equal(missing.lab.run(m.id).status,'failed');
});
test('Lab credential linking uses protected data, restores independent profiles and detects outside edits',async t=>{
 const dir=await temporary(t);let protectedInput='';const credentialFile=path.join(dir,'engine-profile','credentials.dat');await fs.mkdir(path.dirname(credentialFile));const original=JSON.stringify({ClientId:'independent',ProtectedSecret:'encrypted-old'});await fs.writeFile(credentialFile,original);
 const lab=await new WclLab(dir,resources,{platform:'win32',credentialFile,protect:async secret=>{protectedInput=secret;return 'encrypted-new';}}).init();await assert.rejects(()=>lab.connect({mode:'v1',v1Key:'key'}),/V2 Client ID/);
 await lab.connect({mode:'oauth',clientId:'new-client',clientSecret:'do-not-persist'});assert.equal(protectedInput,'do-not-persist');assert.equal((await lab.credentialStatus()).linked,true);assert.ok(!(await fs.readFile(credentialFile,'utf8')).includes('do-not-persist'));assert.ok(!(await fs.readFile(lab.linkFile,'utf8')).includes('do-not-persist'));
 await lab.connect({mode:'oauth',clientId:'newer-client',clientSecret:'next-secret'});await lab.disconnect();assert.equal(await fs.readFile(credentialFile,'utf8'),original);assert.equal((await lab.credentialStatus()).linked,false);
 await lab.connect({mode:'oauth',clientId:'new-client',clientSecret:'other'});await fs.writeFile(credentialFile,'outside-change');await assert.rejects(()=>lab.disconnect(),/changed outside/);assert.equal(await fs.readFile(credentialFile,'utf8'),'outside-change');
});
test('Lab recovers interrupted runs and streams recorded casts with strict provenance and timestamp bounds',async t=>{
 const {lab}=await fakeEngine(t,"setInterval(()=>{},1000)");const r=await lab.start({mode:'validate'}),run=lab.run(r.id);await lab.cancel(r.id);await run.done;
 const log=path.join(run.output,'batch','log-1');await fs.mkdir(log,{recursive:true});const write=(file,value)=>fs.writeFile(path.join(log,file),JSON.stringify(value));
 await write('fight.json',{Id:57,Name:'Boss',EncounterId:123,Difficulty:16,StartTime:10000,EndTime:40000});await write('metadata.json',{reportCode:'6dXM3p91Pv4ZVTfq',sourceId:1});await write('actors.json',[{Id:1,Name:'Healer',Type:'Player'},{Id:2,Name:'Boss',Type:'NPC'}]);await write('abilities.json',[{GameID:498,Name:'Divine Protection'},{GameID:999,Name:'Boss blast'}]);
 const cast={timestamp:11000,type:'cast',sourceID:1,targetID:1,abilityGameID:498};await fs.writeFile(path.join(log,'events_selected_player_casts.jsonl'),[cast,cast,{...cast,timestamp:9999}].map(JSON.stringify).join('\n'));await fs.writeFile(path.join(log,'events_hostile_casts.jsonl'),JSON.stringify({timestamp:14000,type:'cast',sourceID:2,abilityGameID:999})+'\n');
 run.files=(await lab.scanFiles(run)).files;run.status='completed';const timeline=await lab.timeline(run.id,'batch/log-1/fight.json');assert.deepEqual(timeline.events.map(e=>e.time),[1,4]);assert.equal(timeline.events[0].sourceName,'Healer');assert.equal(timeline.events[0].name,'Divine Protection');assert.equal(timeline.source.skippedEvents,1);assert.equal(timeline.encounterId,123);
 await write('metadata.json',{reportCode:'FIXTURE',sourceId:1});await assert.rejects(()=>lab.timeline(run.id,'batch/log-1/fight.json'),/fixtures cannot/);await write('metadata.json',{reportCode:'6dXM3p91Pv4ZVTfq',sourceId:1});await fs.writeFile(path.join(log,'events_hostile_casts.jsonl'),'{broken');await assert.rejects(()=>lab.timeline(run.id,'batch/log-1/fight.json'),/no partial timeline/);
 run.status='running';await lab.persist(run);const reopened=await new WclLab(path.dirname(lab.dir),resources).init();assert.equal(reopened.run(run.id).status,'interrupted');
});
test('Bundled Lab executable is verified before extraction and a tampered cache is repaired',async t=>{
 const dir=await temporary(t);const lab=await new WclLab(dir,resources,{platform:'win32'}).init();const file=await lab.executable();assert.equal((await fs.stat(file)).size,lab.manifest.size);assert.equal((await fs.readFile(file)).subarray(0,2).toString(),'MZ');await fs.writeFile(file,'changed');assert.equal(await lab.executable(),file);assert.equal((await fs.stat(file)).size,lab.manifest.size);
 assert.ok(!redactLab('token=secret Authorization: Bearer abc').includes('secret'));
});
