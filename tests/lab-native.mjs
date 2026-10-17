import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {WclLab} from '../core/wcl-lab.mjs';
if(process.platform!=='win32')throw Error('Run this integration check on Windows');
const root=path.resolve('test-results/native-wcl-lab');await fs.mkdir(root,{recursive:true});
const lab=await new WclLab(root,fileURLToPath(new URL('../resources',import.meta.url)),{credentialFile:path.join(root,'fixture-credentials.dat')}).init();
try{
 async function run(input){const start=await lab.start(input);await lab.run(start.id).done;const result=lab.run(start.id);if(result.status!=='completed'){console.error('::error::'+JSON.stringify({mode:input.mode,status:result.status,log:result.log,summary:result.summary}).slice(0,10000));}assert.equal(result.status,'completed',input.mode);return result;}
 const validate=await run({mode:'validate'});assert.ok(validate.summary.outputWritable??validate.summary.OutputWritable);
 await lab.connect({mode:'oauth',clientId:'native-fixture-client',clientSecret:'native-fixture-secret'});const encrypted=await fs.readFile(lab.credentialFile,'utf8');assert.ok(!encrypted.includes('native-fixture-secret'));assert.ok(JSON.parse(encrypted).ProtectedSecret.length>20);assert.equal((await lab.credentialStatus()).linked,true);await lab.disconnect();await assert.rejects(()=>fs.access(lab.credentialFile));
 const selfTest=await run({mode:'selfTest'});assert.ok(Number(selfTest.summary.passed??selfTest.summary.Passed)>0);assert.equal(Number(selfTest.summary.failed??selfTest.summary.Failed),0);
 const fixture=await run({mode:'fixture'});assert.ok(fixture.files.some(f=>f.path.endsWith('/fight.json')));assert.ok(fixture.files.some(f=>f.path.endsWith('.csv')));
 const batch=fixture.summary.BatchDirectory??fixture.summary.batchDirectory;assert.ok(batch,'Fixture export must report its output directory');
 const reanalysis=await run({mode:'reanalyze',input:batch,spec:'shadow'});assert.ok(reanalysis.files.some(f=>f.path.endsWith('data_quality_report.json')));assert.ok(reanalysis.files.some(f=>f.path.endsWith('.csv')));
 const fight=fixture.files.find(f=>f.path.endsWith('/fight.json'));const preview=await lab.preview(fixture.id,fight.path);assert.ok(preview.text.includes('Start')||preview.text.includes('start'));await assert.rejects(()=>lab.timeline(fixture.id,fight.path),/fixtures cannot become/);
 console.log('Native WCL Lab passed: bundled EXE launch, DPAPI link/forget, built-in self-tests, fixture export, offline reanalysis and synthetic sample refusal. No live WCL credentials used.');
}catch(error){for(const r of lab.jobs.values()){for(const file of r.files.filter(f=>/\/(fight|metadata)\.json$/.test(f.path)).slice(0,2)){console.error('::error::Fixture schema '+JSON.stringify(await lab.preview(r.id,file.path)).slice(0,4500));}}throw error;}finally{await lab.close();}
