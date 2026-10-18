import {chromium} from 'playwright-core';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
import {DoctorService} from '../core/service.mjs';
import {SPEC_NAMES} from '../core/wow-names.mjs';
const dir=await fs.mkdtemp(path.join(os.tmpdir(),'planner-all-specs-')),service=await new DoctorService(dir,path.resolve('resources'),{fetcher:async()=>({ok:false,status:403})}).init();
const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']}),page=await browser.newPage({viewport:{width:1672,height:941}}),errors=[];page.on('pageerror',e=>errors.push(e.message));await page.route('**/api/call',async route=>{const {method,args}=route.request().postDataJSON();try{await route.fulfill({contentType:'application/json',body:JSON.stringify({data:await service.handle(method,args)})});}catch(e){await route.fulfill({status:400,contentType:'application/json',body:JSON.stringify({error:e.message})});}});
// Input fixtures exercise format/selection isolation. They are not built-in game recommendations.
const classSpells=[['Demon Hunter',198589],['Death Knight',48707],['Mage',45438],['Paladin',498],['Warrior',871],['Druid',22812],['Hunter',186265],['Priest',19236],['Rogue',1966],['Shaman',108271],['Warlock',104773],['Monk',115203],['Evoker',363916]];
try{
 await page.goto('http://127.0.0.1:5173');await page.getByRole('button',{name:'Defensive Planner',exact:true}).click();const spec=page.getByRole('combobox',{name:'Planner specialization',exact:true}),assigned=page.getByRole('combobox',{name:'Assigned defensive set',exact:true});let first=true;
 for(const [id,name]of Object.entries(SPEC_NAMES)){
  await spec.selectOption(id);const spell=classSpells.find(([cls])=>name.endsWith(cls))?.[1];assert.ok(spell);const data={spec:name,presets:{personal:{name:'Fixture '+name,rows:[{label:'Fixture defensive',ids:[spell]},{label:'Disabled',ids:[]}]}}};const html='<script type="application/json">'+JSON.stringify(data)+'</script>';await page.getByRole('button',{name:'Import profile / HTML',exact:true}).click();await page.getByRole('dialog',{name:'Import defensive profile',exact:true}).locator('input[type=file]').setInputFiles({name:id+'-defenses.html',mimeType:'text/html',buffer:Buffer.from(html)});await page.getByRole('dialog',{name:'Import defensive profile',exact:true}).waitFor({state:'hidden'});
  if(first){await page.getByRole('combobox',{name:'Planner dungeon',exact:true}).selectOption('2813');await page.getByRole('listbox',{name:'Dungeon creatures',exact:true}).getByRole('option',{name:'Zaen Bladesorrow Boss',exact:true}).click();await page.getByRole('listbox',{name:'Creature abilities',exact:true}).getByRole('option',{name:'Envenom 1222795',exact:true}).click();first=false;}
  const options=await assigned.locator('option').allTextContents();assert.deepEqual(options,['No reminder','Fixture '+name]);await assigned.selectOption({label:'Fixture '+name});await page.getByRole('status').filter({hasText:'Defensive set assigned'}).waitFor();
 }
 await page.getByRole('button',{name:'Export NSR',exact:true}).click();const out=page.getByRole('textbox',{name:'Simple NSR export string',exact:true});await out.waitFor();const p=service.codec.decode(await out.inputValue());assert.equal(Object.keys(p.data.presets).length,40);assert.equal(Object.keys(p.data.abilityBindings).length,40);for(const [id,name]of Object.entries(SPEC_NAMES)){const b=p.data.abilityBindings[id]['3102']['1222795'];assert.equal(p.data.presets[id][b.preset].name,'Fixture '+name);}assert.deepEqual(errors,[]);console.log('All 40 specialization UI flows passed: generic HTML import per selected spec, isolated available sets, boss ability assignment and one NSR export retaining all 40 specs.');
}finally{await browser.close();await fs.rm(dir,{recursive:true,force:true});}
