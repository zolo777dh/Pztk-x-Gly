import {chromium} from 'playwright-core';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {DoctorService} from '../core/service.mjs';
const dir=await fs.mkdtemp(path.join(os.tmpdir(),'pztk-migration-ui-')),s=await new DoctorService(dir,path.resolve('resources')).init();
const text=process.env.DOCTOR_NSR_MIGRATION_INPUT?await fs.readFile(process.env.DOCTOR_NSR_MIGRATION_INPUT,'utf8'):s.codec.encode({format:1,name:'UI migration fixture',data:{presets:{264:{p1:{name:'Fixture set',list:[100]}}},activePreset:{264:'p1'},customReminders:{123:{r:{name:'Fixture delayed defensive',enabled:true,specID:264,defensive:true,preset:'p1',dur:3,trigger:{type:'bwmsg',spellID:400,delay:'2',counter:'>1'}}}},integrationRules:{264:{a:{name:'Fixture aura',enabled:true,trigger:{type:'auraSound',mapID:456,spellID:600,target:'player',auraEvent:'Added'},display:{sound:'voice:stoneform-ready',type:'icon',text:'',dur:3}}}},settings:{enabled:true,coveredSkip:true}}});
const b=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']}),page=await b.newPage({viewport:{width:1672,height:1000}}),errors=[];page.setDefaultTimeout(60000);page.on('pageerror',e=>errors.push(e.message));await fs.mkdir('test-results',{recursive:true});
await page.route('**/api/call',async r=>{const {method,args}=r.request().postDataJSON();try{await r.fulfill({contentType:'application/json',body:JSON.stringify({data:await s.handle(method,args)})});}catch(e){await r.fulfill({status:400,contentType:'application/json',body:JSON.stringify({error:e.message})});}});
const button=name=>page.getByRole('button',{name,exact:true}),box=name=>page.getByRole('textbox',{name,exact:true}),combo=name=>page.getByRole('combobox',{name,exact:true});
try{
 await page.goto('http://127.0.0.1:5173');await button('Import / migrate').click();await box('Unified import text').fill(text);await button('Import into reminder workspace').click();await page.getByRole('dialog',{name:'Import unified reminder data',exact:true}).waitFor({state:'hidden'});
 const state=await s.handle('planner.state',{client:'retail'}),original=await s.planner.read('profiles',state.profiles[0].id),before=JSON.stringify(original.pack);
 await button('Export complete profile').click();let exported=await box('Complete reminder export string').inputValue(),pack=s.reminderPack.decode(exported).pack;assert.ok(Object.values(pack.data.raidReminders).flatMap(Object.values).some(e=>e.defensive&&e.trigger.counterGroups));assert.ok(Object.values(pack.data.integrationRules).flatMap(Object.values).some(r=>r.trigger.type==='auraSound'));
 assert.equal(await page.getByText(/Integration rule .* needs manual migration/).count(),0);
 await button('Open editable migrated copy').click();await page.getByRole('status').filter({hasText:'Editable migrated copy created'}).waitFor();
 assert.equal(JSON.stringify((await s.planner.read('profiles',original.id)).pack),before);
 const state2=await s.handle('planner.state',{client:'retail'}),draft=await s.handle('nsr.open',{profileId:state2.active.profileId,resume:true}),view=await s.handle('reminders.read',{id:draft.id});
 const reminder=view.reminders.find(e=>e.defensive&&e.trigger.counterGroups);assert.ok(reminder);
 await page.getByRole('button',{name:new RegExp('^'+reminder.name.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+'.*Encounter '+reminder.encounterId)}).first().click();
 assert.equal(await combo('Reminder action').inputValue(),'defensive');assert.equal(await combo('Reminder defensive set').inputValue(),reminder.defensive.preset);assert.equal(await combo('Reminder specialization').inputValue(),String(reminder.defensive.specID));
 await box('Reminder trigger counterCondition').fill('>2');await box('Reminder trigger delay').fill('4');await button('Save reminder').click();await page.getByRole('status').filter({hasText:'Reminder saved'}).waitFor();
 await button('Export complete profile').click();exported=await box('Complete reminder export string').inputValue();pack=s.reminderPack.decode(exported).pack;const edited=pack.data.raidReminders[reminder.encounterId][reminder.key];assert.equal(edited.trigger.delay,4);assert.equal(edited.trigger.counterGroups['1']['1'].value,2);assert.equal(edited.defensive.preset,reminder.defensive.preset);
 await page.screenshot({path:'test-results/migration-review.png'});assert.deepEqual(errors,[]);console.log('Migration UI passed: source import → scoped review → native copy → defensive set/counter/delay edit → export; source unchanged.');
}catch(e){await page.screenshot({path:'test-results/migration-ui-failure.png'});throw e;}finally{await b.close();await fs.rm(dir,{recursive:true,force:true});}
