import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {DoctorService} from '../core/service.mjs';
async function fixture(t){const dir=await fs.mkdtemp(path.join(os.tmpdir(),'browser-ai-'));t.after(()=>fs.rm(dir,{recursive:true,force:true}));const root=path.join(dir,'Addon');await fs.mkdir(root);await fs.writeFile(path.join(root,'Addon.toc'),'Core.lua\n');await fs.writeFile(path.join(root,'Core.lua'),'local addonName, ns = ...\nprint(addonName)\n');const service=await new DoctorService(path.join(dir,'data'),path.resolve('resources'),{fetcher:()=>{throw Error('Browser mode must not call an AI API');}}).init();const project=await service.handle('project.add',{root});const source=await service.handle('source',{id:project.id,file:'Core.lua'});return {service,project,source,root};}
test('browser analysis prepares context without API credentials, validates reply and requires explicit backed-up apply',async t=>{
 const {service:s,project:p,source,root}=await fixture(t);assert.equal(s.state.settings.aiMode,'browser');
 const plan=await s.handle('browser.prepare',{id:p.id,file:'Core.lua',hash:source.hash,client:'forever',kind:'analysis'});assert.match(plan.prompt,/1.60.1.70425/);assert.match(plan.prompt,/local addonName, ns/);
 const result=await s.handle('browser.reply',{id:p.id,plan:plan.id,text:'```json\n'+JSON.stringify({explanation:'Fixture',replacement:'local addonName, ns = ...\nprint("fixture")\n'})+'\n```'});
 assert.ok(result.preview.diff.includes('print("fixture")'));assert.equal(await fs.readFile(path.join(root,'Core.lua'),'utf8'),source.text);
 const applied=await s.handle('patch.apply',{id:p.id,plan:result.preview.id});assert.ok(applied.backup.filename);assert.match(await fs.readFile(path.join(root,'Core.lua'),'utf8'),/fixture/);
 await assert.rejects(()=>s.handle('browser.reply',{id:p.id,plan:plan.id,text:JSON.stringify({explanation:'stale',replacement:'print(3)'})}),/Source changed/);
});
test('browser feature replies require exact unique anchors, valid Lua, current context and correct project',async t=>{
 const {service:s,project:p,source,root}=await fixture(t);const plan=await s.handle('browser.prepare',{id:p.id,kind:'feature',description:'Add a local fixture greeting',file:'Core.lua',client:'retail'});
 assert.match(plan.prompt,/"anchor"/);const response={explanation:'Fixture only',file:'Core.lua',position:'after',anchor:'local addonName, ns = ...',code:'\nlocal greeting = "Hello"'};
 await assert.rejects(()=>s.handle('browser.reply',{id:p.id,plan:plan.id,text:JSON.stringify({...response,anchor:'missing'})}),/missing or ambiguous/);
 await assert.rejects(()=>s.handle('browser.reply',{id:p.id,plan:plan.id,text:JSON.stringify({...response,code:'\nlocal ='})}),/Lua validation/);
 await assert.rejects(()=>s.handle('browser.reply',{id:p.id,plan:plan.id,text:'not JSON'}),/JSON reply/);
 const result=await s.handle('browser.reply',{id:p.id,plan:plan.id,text:JSON.stringify(response)});assert.match(result.preview.insertion,/Core.lua:1/);assert.equal(await fs.readFile(path.join(root,'Core.lua'),'utf8'),source.text);
 await fs.writeFile(path.join(root,'Core.lua'),source.text+'-- edited\n');await assert.rejects(()=>s.handle('browser.reply',{id:p.id,plan:plan.id,text:JSON.stringify(response)}),/Source changed/);
});
