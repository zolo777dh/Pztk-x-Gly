import {_electron as electron} from 'playwright-core';
import path from 'node:path';
import http from 'node:http';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {plannerFlow,browserFlow,nsrtFlow} from './helpers/planner-flow.mjs';
await fs.mkdir('test-results',{recursive:true});
const server=http.createServer((req,res)=>{assert.equal(req.headers.authorization,undefined);res.setHeader('Content-Type','application/json');res.end(JSON.stringify({data:[{id:'test-model'}]}));});await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const root=path.resolve('.'),profile=process.env.DOCTOR_PROFILE||'unified-'+Date.now();
const launch=()=>electron.launch({executablePath:process.env.DOCTOR_ELECTRON||path.resolve('node_modules/electron/dist',process.platform==='win32'?'electron.exe':'electron'),args:['--no-sandbox','--disable-gpu',process.env.DOCTOR_APP||'.'],env:{...process.env,DISPLAY:':99',XDG_CONFIG_HOME:path.join(root,'test-results/'+profile+'-config'),XDG_CACHE_HOME:path.join(root,'test-results/'+profile+'-cache'),XDG_RUNTIME_DIR:path.join(root,'test-results/'+profile+'-runtime')},timeout:30000});
let app;
try{
 app=await launch();let page=await app.firstWindow();const errors=[];page.on('pageerror',e=>errors.push(e.message));await page.getByRole('button',{name:'Open disposable demo',exact:true}).waitFor();const version=await app.evaluate(({app})=>app.getVersion()),call=(method,args)=>page.evaluate(({method,args})=>window.doctor.call(method,args),{method,args});const startup=await call('init');assert.equal(startup.version,version);assert.equal(startup.projects.length,0);assert.equal(await page.getByLabel('Application version',{exact:true}).innerText(),'v'+version);assert.equal(startup.wcl,undefined);await assert.rejects(()=>call('lab.status'),/Unknown application command/);
 const tested=await call('ai.test',{mode:'local',settings:{localEndpoint:`http://127.0.0.1:${server.address().port}/v1`,localModel:'test-model'}});assert.equal(tested.modelFound,true);
 // Intercept OS browser launch: verify only the two fixed websites can be opened.
 await app.evaluate(({shell})=>{globalThis.openedAssistants=[];shell.openExternal=async url=>{globalThis.openedAssistants.push(url);};});
 await page.evaluate(()=>window.doctor.openAssistant('chatgpt'));await page.evaluate(()=>window.doctor.openAssistant('claude'));await assert.rejects(()=>page.evaluate(()=>window.doctor.openAssistant('file:///etc/passwd')),/Choose ChatGPT or Claude/);assert.deepEqual(await app.evaluate(()=>globalThis.openedAssistants),['https://chatgpt.com/','https://claude.ai/']);
 await page.evaluate(()=>window.doctor.browser({action:'open',provider:'chatgpt',rect:{x:10,y:10,width:600,height:500}}));
 const embedded=await app.evaluate(({BrowserWindow})=>{const view=BrowserWindow.getAllWindows()[0].contentView.children[0];const prefs=view.webContents.getLastWebPreferences();return {sandbox:prefs.sandbox,nodeIntegration:prefs.nodeIntegration,contextIsolation:prefs.contextIsolation,preload:prefs.preload||null};});assert.deepEqual(embedded,{sandbox:true,nodeIntegration:false,contextIsolation:true,preload:null});await page.evaluate(()=>window.doctor.browser({action:'hide'}));
 await plannerFlow(page,call);await browserFlow(page,call);await nsrtFlow(page,call);assert.deepEqual(errors,[]);await app.close();app=await launch();page=await app.firstWindow();await page.getByRole('button',{name:'Open disposable demo',exact:true}).waitFor();const reopened=await page.evaluate(()=>window.doctor.call('init'));assert.equal(reopened.projects.length,0);await page.getByRole('button',{name:'Raid Planner',exact:true}).click();await page.getByRole('combobox',{name:'Planner specialization',exact:true}).selectOption('264');await page.getByRole('listbox',{name:'Raid bosses',exact:true}).getByRole('option',{name:"Nek'zali the Soulcoiler Boss",exact:true}).click();await page.getByRole('listbox',{name:'Raid boss abilities',exact:true}).getByRole('option',{name:'Possession Barrage 1284103',exact:true}).click();assert.equal(await page.getByRole('combobox',{name:'Assigned defensive set',exact:true}).locator('option:checked').innerText(),'Edited Shaman set');
 assert.ok((await page.evaluate(()=>window.doctor.call('nsrt.list'))).length>=1);
 console.log('Native desktop passed: startup/version, secured IPC, net.fetch, browser allowlist, combined NSR import/edit/export, browser replies → backup/apply/restore, restart with persisted profile and empty addon list.');
}finally{if(app)await app.close();server.close();}
