import {chromium} from 'playwright-core';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {DoctorService} from '../core/service.mjs';
import {plannerFlow,browserFlow,nsrtFlow} from './helpers/planner-flow.mjs';
const dir=await fs.mkdtemp(path.join(os.tmpdir(),'pztk-unified-ui-'));let service=await new DoctorService(dir,path.resolve('resources'),{fetcher:async()=>({ok:false,status:403})}).init();
await fs.mkdir('test-results',{recursive:true});
const browser=await chromium.launch({executablePath:process.env.DOCTOR_CHROMIUM||'/usr/bin/chromium',headless:true,args:['--no-sandbox']}),page=await browser.newPage({viewport:{width:1672,height:941}}),errors=[];page.on('pageerror',e=>errors.push(e.message));
await page.route('**/api/call',async route=>{const {method,args}=route.request().postDataJSON();try{await route.fulfill({contentType:'application/json',body:JSON.stringify({data:await service.handle(method,args)})});}catch(e){await route.fulfill({status:400,contentType:'application/json',body:JSON.stringify({error:e.message})});}});
try{
 await page.goto('http://127.0.0.1:5173');await plannerFlow(page,(method,args)=>service.handle(method,args));await browserFlow(page,(method,args)=>service.handle(method,args));await nsrtFlow(page,(method,args)=>service.handle(method,args));
 service=await new DoctorService(dir,path.resolve('resources'),{fetcher:async()=>({ok:false,status:403})}).init();await page.reload();await page.getByRole('button',{name:'Raid Planner',exact:true}).click();await page.getByRole('combobox',{name:'Planner specialization',exact:true}).selectOption('264');await page.getByRole('listbox',{name:'Raid bosses',exact:true}).getByRole('option',{name:"Nek'zali the Soulcoiler Boss",exact:true}).click();await page.getByRole('listbox',{name:'Raid boss abilities',exact:true}).getByRole('option',{name:'Possession Barrage 1284103',exact:true}).click();assert.equal(await page.getByRole('combobox',{name:'Assigned defensive set',exact:true}).locator('option:checked').innerText(),'Edited Shaman set');assert.equal((await service.handle('init')).projects.length,0);assert.deepEqual(errors,[]);console.log('Unified UI passed: HTML → M+ boss/trash + raid H/M → shared export → editor → resume; browser analysis/feature reply → validate → backup/apply/restore.');
}finally{await browser.close();await fs.rm(dir,{recursive:true,force:true});}
