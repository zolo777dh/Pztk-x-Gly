import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {DoctorService} from '../core/service.mjs';
import {parseDefenseTable} from '../core/defensive-planner.mjs';
import {namedFacts} from '../tools/build-raid-catalog.mjs';
import {SPEC_NAMES} from '../core/wow-names.mjs';
const resources=path.resolve('resources');
async function fixture(t){const dir=await fs.mkdtemp(path.join(os.tmpdir(),'unified-planner-'));t.after(()=>fs.rm(dir,{recursive:true,force:true}));return new DoctorService(dir,resources).init();}
const reference=(name,spells)=>'<script>throw Error("never run")</script><script type="application/json">'+JSON.stringify({spec:name,presets:[{id:'personal',name:'Personal',rows:spells.map(([label,id])=>({label,ids:[id]}))}]})+'</script>';

test('raid facts preserve separate difficulty membership, deduplicate phases and use confirmed NSR timer aliases',async t=>{
 const s=await fixture(t),c=await s.handle('raid.catalog');assert.equal(c.seasons.length,2);assert.equal(c.seasons.flatMap(s=>s.bosses).length,20);
 for(const season of c.seasons)for(const boss of season.bosses){assert.equal(new Set(boss.abilities.map(a=>a.id)).size,boss.abilities.length);assert.ok(boss.abilities.some(a=>a.difficulties.includes('heroic')));assert.ok(boss.abilities.some(a=>a.difficulties.includes('mythic')));for(const a of boss.abilities){assert.ok(a.name);assert.ok(a.timerSpellId>0);assert.ok(a.difficulties.every(d=>['heroic','mythic'].includes(d)));assert.equal(a.times,undefined);}}
 const boss=c.seasons[0].bosses.find(b=>b.id===3470);assert.equal(boss.abilities.find(a=>a.id===1284103).timerSpellId,1292036);assert.deepEqual(boss.abilities.find(a=>a.id===1285623).difficulties,['mythic']);
 assert.deepEqual({...namedFacts('local values = {1,2}; ns.Names = {[123]="Example"}; os.execute("must not execute")').Names},{123:'Example'});
});

test('one profile imports arbitrary class HTML, assigns M+ boss/trash and raid H/M, resumes and roundtrips through NSR',async t=>{
 const s=await fixture(t),original={format:1,name:'Combined',derivedFrom:{name:'Source',author:'Curator'},data:{settings:{keep:true},presets:{},activePreset:{},bindingsBySpec:true,abilityBindings:{},raidReminders:{'777':{keep:{name:'Keep',trigger:{type:'pull',delay:12},display:{type:'text',text:'Keep',dur:5}}}}}};
 const imported=await s.handle('planner.importProfile',{text:s.codec.encode(original)});let v=await s.handle('nsr.open',{profileId:imported.id,resume:true});
 for(const [specId,spells]of [[264,[['Astral Shift',108271],['Spirit Link Totem',98008]]],[256,[['Pain Suppression',33206],['Power Word: Barrier',62618]]]]){
  const table=await s.handle('planner.importTable',{text:reference(SPEC_NAMES[specId],spells),filename:'any-filename-'+specId+'.html',options:{defaults:{specId}}});
  const result=await s.handle('nsr.reference',{id:v.id,revision:v.revision,tableId:table.id,specId,apply:true});v=result.view;const preset=v.specs.find(x=>x.id===String(specId)).presets[0].key;
  v=await s.handle('nsr.assignNpc',{id:v.id,revision:v.revision,specId,mapId:2813,npcId:234649,spellId:474765,preset});
  const dungeon=(await s.handle('npc.catalog')).dungeons.find(d=>d.mapId===2825),npc=dungeon.npcs.find(n=>n.name==='Spirit of Hunger');
  v=await s.handle('nsr.assignNpc',{id:v.id,revision:v.revision,specId,mapId:2825,npcId:npc.id,spellId:1238725,preset});
  const args={id:v.id,revision:v.revision,specId,seasonId:'MidnightS2',encounterId:3470,spellId:1284103,preset,difficulty:'heroic'};
  await assert.rejects(()=>s.handle('nsr.assignRaid',{...args,spellId:1285623}),/belonging/);
  await assert.rejects(()=>s.handle('nsr.assignRaid',{...args,difficulty:'normal'}),/Heroic or Mythic/);
  await assert.rejects(()=>s.handle('nsr.assignRaid',{...args,encounterId:3513}),/belonging/);
  v=await s.handle('nsr.assignRaid',args);
  v=await s.handle('nsr.assignRaid',{...args,id:v.id,revision:v.revision,difficulty:'mythic'});
  v=await s.handle('nsr.assignRaid',{...args,id:v.id,revision:v.revision,difficulty:'mythic',spellId:1285623});
 }
 const restarted=await new DoctorService(s.dataDir,resources).init(),state=await restarted.handle('planner.state');assert.equal(state.active.profileId,imported.id);
 const resumed=await restarted.handle('nsr.open',{...state.active,resume:true});assert.equal(resumed.id,v.id);assert.equal(resumed.revision,v.revision);
 const output=await s.handle('nsr.export',{id:v.id,revision:v.revision}),pack=s.codec.decode(output.text);
 assert.deepEqual(pack.derivedFrom,original.derivedFrom);assert.deepEqual(pack.data.settings,original.data.settings);assert.ok(pack.data.raidReminders['777']);
 for(const spec of ['264','256']){assert.ok(pack.data.abilityBindings[spec]['3102']['474765'].preset);assert.equal(Object.keys(pack.data.abilityBindings[spec]['3470']).length,2);assert.ok(pack.data.abilityBindings[spec]['3470']['1292036'].preset);assert.ok(pack.data.abilityBindings[spec]['3470']['1285623'].preset);assert.equal(pack.data.abilityBindings[spec]['3470']['1284103'],undefined);const rule=Object.values(pack.data.integrationRules[spec])[0];assert.equal(rule.trigger.mapID,2825);assert.equal(rule.trigger.spellID,1238687);}
 if(process.env.DOCTOR_LUA51&&process.env.DOCTOR_ADDON_TEST_ROOT){
  const textfile=path.join(s.dataDir,'unified.txt');await fs.writeFile(textfile,output.text);const script=`strmatch=string.match\ndofile(${JSON.stringify(resources+'/codec/LibStub.lua')})\ndofile(${JSON.stringify(resources+'/codec/LibSerialize.lua')})\ndofile(${JSON.stringify(resources+'/codec/LibDeflate.lua')})\nNaowhUITankReminder={L=function(s)return s end,SpecName=function(s)return tostring(s)end,UI={Widgets={}},THEME={}}\nCreateFrame=function()return {SetScript=function()end,RegisterEvent=function()end}end\ndofile(${JSON.stringify(process.env.DOCTOR_ADDON_TEST_ROOT+'/NaowhUI_SmartReminders_Integrations.lua')})\ndofile(${JSON.stringify(process.env.DOCTOR_ADDON_TEST_ROOT+'/NaowhUI_SmartReminders_Packs.lua')})\nlocal f=assert(io.open(${JSON.stringify(textfile)},'rb'));local p,e=NaowhUITankReminder.DecodePack(f:read('*a'));assert(p,e);assert(p.derivedFrom.author=='Curator');for _,spec in ipairs({'264','256'})do local d=p.data;assert(d.abilityBindings[spec]['3102'][474765].preset);assert(d.abilityBindings[spec]['3470'][1292036].preset);assert(d.abilityBindings[spec]['3470'][1285623].preset);assert(not d.abilityBindings[spec]['3470'][1284103]);for _,r in pairs(d.integrationRules[spec])do assert(NaowhUITankReminder.Integrations.ValidRule(r));assert(r.trigger.spellID==1238687)end end;print('UNIFIED_NSR_ACCEPTED')`;
  const lua=path.join(s.dataDir,'unified.lua');await fs.writeFile(lua,script);assert.match(execFileSync(process.env.DOCTOR_LUA51,[lua],{encoding:'utf8'}),/UNIFIED_NSR_ACCEPTED/);
 }
});

test('all 40 specs use the same HTML import and raid assignment pipeline without class-specific templates',async t=>{
 const s=await fixture(t),p=await s.handle('planner.createProfile');let v=await s.handle('nsr.open',{profileId:p.id});
 // Spell 100 is a serializer fixture, not a recommendation for these classes.
 for(const [specId,name]of Object.entries(SPEC_NAMES)){
  const table=await s.handle('planner.importTable',{text:reference(name,[['Fixture spell',100]]),filename:name+'.html',options:{defaults:{specId:Number(specId)}}});
  v=(await s.handle('nsr.reference',{id:v.id,revision:v.revision,tableId:table.id,specId,apply:true})).view;
  const preset=v.specs.find(x=>x.id===specId).presets[0].key;
  v=await s.handle('nsr.assignRaid',{id:v.id,revision:v.revision,specId,seasonId:'MidnightS2',encounterId:3470,spellId:1284103,difficulty:'heroic',preset});
 }
 const pack=s.codec.decode((await s.handle('nsr.export',{id:v.id,revision:v.revision})).text);assert.equal(Object.keys(pack.data.presets).length,40);for(const specId of Object.keys(SPEC_NAMES))assert.ok(pack.data.abilityBindings[specId]['3470']['1292036'].preset);
 assert.throws(()=>parseDefenseTable('<table><tr><th>Boss</th><th>Time</th></tr><tr><td>A</td><td>10</td></tr></table>','no-sets.html'),/No supported defensive sets/);
 for(const method of ['wcl.report','lab.status','planner.analyze','timeline.import','notes.save'])await assert.rejects(()=>s.handle(method,{}),/Unknown application command/);
});

test('raid alias migration retains existing custom binding fields and lead time instead of orphaning an imported journal ID',async t=>{
 const s=await fixture(t),p=await s.handle('planner.importProfile',{text:s.codec.encode({format:1,name:'Alias import',data:{presets:{'264':{personal:{name:'Personal',list:[108271]}}},bindingsBySpec:true,abilityBindings:{'264':{'3470':{'1284103':{enabled:true,preset:'personal',mode:'defensive',leadTime:7,healerReminder:false,customField:'retain'}}}}}})});const v=await s.handle('nsr.open',{profileId:p.id});
 const next=await s.handle('nsr.assignRaid',{id:v.id,revision:v.revision,specId:264,seasonId:'MidnightS2',encounterId:3470,spellId:1284103,difficulty:'heroic',preset:'personal'}),pack=s.codec.decode((await s.handle('nsr.export',{id:next.id,revision:next.revision})).text),bindings=pack.data.abilityBindings['264']['3470'];
 assert.equal(bindings['1284103'],undefined);assert.equal(bindings['1292036'].leadTime,7);assert.equal(bindings['1292036'].customField,'retain');assert.equal(bindings['1292036'].healerReminder,false);
});
