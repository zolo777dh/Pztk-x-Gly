import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {execFileSync} from 'node:child_process';
import {parseReference} from '../core/encounters.mjs';
import {referenceSetVariants} from '../core/priority-reference.mjs';
import {SPEC_NAMES} from '../core/wow-names.mjs';
import {DoctorService} from '../core/service.mjs';
import {mythicCatalog} from '../core/mythic-catalog.mjs';
import {mythicOptionIds,mechanicAbilities} from '../tools/catalog-options.mjs';
const row=(label,ids,when='')=>({label,ids,when});
const fixture={spec:'Restoration Shaman',catalog:[{id:108271,name:'Astral Shift'},{id:198103,name:'Earth Elemental'},{id:98008,name:'Spirit Link Totem'},{id:108280,name:'Healing Tide Totem'},{id:1291894,name:'Soulcoiler Ritual Vessel'}],presets:[
 {id:'personal',name:'Personal Defensive',rows:[row('Astral Shift',[108271]),row('Earth Elemental',[198103]),row('Disabled',[])]},
 {id:'mitigation',name:'Party Burst Mitigation',rows:[row('Astral Shift + Spirit Link Totem',[108271,98008]),row('Spirit Link Totem',[98008]),row('Astral Shift',[108271]),row('Earth Elemental',[198103])]},
 {id:'sustain',name:'Party Sustained Healing',note:'Keep alternative party cooldowns separate.',rows:[row('Astral Shift + Healing Tide Totem',[108271,108280],'Before repeated damage.'),row('Healing Tide Totem',[108280]),row('Astral Shift + Spirit Link Totem',[108271,98008]),row('Spirit Link Totem',[98008])]},
 {id:'selfcritical',name:'Emergency — Personal Overlap',rows:[row('Astral Shift + Earth Elemental',[108271,198103]),row('Astral Shift',[108271]),row('Earth Elemental',[198103])]},
 {id:'vessel',name:'Optional — Pre-hit Barrier',rows:[row('Astral Shift + Soulcoiler Ritual Vessel',[108271,1291894]),row('Soulcoiler Ritual Vessel',[1291894]),row('Disabled',[])]}
]};
const html=data=>'<script>throw Error("never execute")</script><script type="application/json">'+JSON.stringify(data)+'</script>';
test('ids arrays and combined ranks use document data for all 40 specializations without file or class templates',()=>{
 for(const [id,name]of Object.entries(SPEC_NAMES)){const reference=parseReference(html({...fixture,spec:name}),'any-file.html');assert.equal(reference.presets[0].specId,Number(id));assert.equal(reference.presets[0].rows[0][1],'108271');assert.equal(reference.presets[1].rows[0][1],'108271 + 98008');assert.equal(reference.presets[0].rows[2][1],'');const variants=referenceSetVariants(reference.presets[2]);assert.equal(variants.length,2);assert.deepEqual(variants[0].spells.filter(s=>s.together).map(s=>s.spellId),[108271,108280]);assert.deepEqual(variants[1].spells.filter(s=>s.together).map(s=>s.spellId),[108271,98008]);}
 assert.throws(()=>parseReference(html({presets:[{name:'Invalid',rows:[row('Bad',['not-an-id'])]}]})),/Invalid defensive ids array/);
});
test('Restoration HTML imports all sets, separates overlap alternatives, exports valid NSR and preserves source conditions',async t=>{
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'ids-reference-'));t.after(()=>fs.rm(dir,{recursive:true,force:true}));const service=await new DoctorService(dir,path.resolve('resources')).init();
 const text=process.env.DOCTOR_REFERENCE_HTML?await fs.readFile(process.env.DOCTOR_REFERENCE_HTML,'utf8'):html(fixture);
 const table=await service.handle('planner.importTable',{text,filename:'any-reference.html',options:{defaults:{specId:264}}}),profile=await service.handle('planner.createProfile'),view=await service.handle('nsr.open',{profileId:profile.id});
 const args={id:view.id,revision:0,tableId:table.id,specId:264};const preview=await service.handle('nsr.reference',args);assert.equal(preview.presets.length,6);assert.equal(preview.variants,1);assert.equal((await service.handle('nsr.read',{id:view.id})).revision,0);await assert.rejects(()=>service.handle('nsr.reference',{...args,specId:65,apply:true}),/another specialization/);
 const applied=await service.handle('nsr.reference',{...args,apply:true}),out=await service.handle('nsr.export',{id:view.id,revision:applied.view.revision}),pack=service.codec.decode(out.text);const presets=Object.values(pack.data.presets['264']);assert.equal(presets.length,6);
 const personal=presets.find(p=>p.name==='Personal Defensive');assert.deepEqual(Object.values(personal.list),[108271,198103]);
 const sustain=presets.filter(p=>p.name.startsWith('Party Sustained Healing'));assert.equal(sustain.length,2);for(const p of sustain){assert.equal(Object.keys(p.together).length,2);assert.ok(!(p.together['108280']&&p.together['98008']));assert.ok(Object.values(p.pztkReferenceNotes.rows).some(r=>r.when));}
 for(const p of presets){const ids=Object.values(p.list);assert.equal(new Set(ids).size,ids.length);assert.ok(ids.every(Number.isInteger));}
 assert.equal(applied.view.specs[0].presets.find(p=>p.name==='Personal Defensive').spells[1].name,'Earth Elemental');const reopened=await service.handle('planner.importProfile',{text:out.text}),reopenedView=await service.handle('nsr.open',{profileId:reopened.id});assert.ok(Array.isArray(reopenedView.specs[0].presets[0].referenceNotes.rows));
 if(process.env.DOCTOR_LUA51&&process.env.DOCTOR_ADDON_TEST_ROOT){const file=path.join(dir,'export.txt');await fs.writeFile(file,out.text);const resources=path.resolve('resources/codec');const script=`strmatch=string.match\ndofile(${JSON.stringify(resources+'/LibStub.lua')})\ndofile(${JSON.stringify(resources+'/LibSerialize.lua')})\ndofile(${JSON.stringify(resources+'/LibDeflate.lua')})\nNaowhUITankReminder={L=function(s)return s end,SpecName=function(s)return tostring(s)end,UI={Widgets={}},THEME={}}\nCreateFrame=function()return {SetScript=function()end,RegisterEvent=function()end}end\ndofile(${JSON.stringify(process.env.DOCTOR_ADDON_TEST_ROOT+'/NaowhUI_SmartReminders_Packs.lua')})\nlocal f=assert(io.open(${JSON.stringify(file)},'rb'));local p,e=NaowhUITankReminder.DecodePack(f:read('*a'));f:close();assert(p,e);local n=0;for _,v in pairs(p.data.presets['264']) do n=n+1;local t=0;for _ in pairs(v.together)do t=t+1 end;assert(t<=2);assert(v.pztkReferenceNotes) end;assert(n==6);print('IDS_ARRAYS_REAL_NSR_OK')`;const lua=path.join(dir,'check.lua');await fs.writeFile(lua,script);assert.match(execFileSync(process.env.DOCTOR_LUA51,[lua],{encoding:'utf8'}),/IDS_ARRAYS_REAL_NSR_OK/);}
});
test('empty references explain missing IDs without changing a working profile',async t=>{
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'empty-reference-'));t.after(()=>fs.rm(dir,{recursive:true,force:true}));const service=await new DoctorService(dir,path.resolve('resources')).init();const p=await service.handle('planner.createProfile'),v=await service.handle('nsr.open',{profileId:p.id});const table=await service.handle('planner.importTable',{text:html({presets:[{name:'Missing',rows:[row('Unknown',[])]}]}),filename:'missing.html',options:{defaults:{specId:264}}});await assert.rejects(()=>service.handle('nsr.reference',{id:v.id,revision:0,tableId:table.id,specId:264,apply:true}),/No usable defensive spell IDs/);assert.equal((await service.handle('nsr.read',{id:v.id})).revision,0);
});
test('Mythic+ selection rejects lower difficulty rows and deduplicates mechanics while retaining effect provenance',async()=>{
 const filtered=mythicCatalog({dungeons:[{npcs:[{abilities:[{id:1,difficultyIds:[1,2]},{id:2,difficultyIds:[8]},{id:2,name:'Shared'},{id:3,difficultyId:23},{id:4,difficulty:'heroic'}]}]}]});assert.deepEqual(filtered.dungeons[0].npcs[0].abilities.map(a=>a.id),[2]);
 const options=mythicOptionIds('function mod:GetOptions() if self:Mythic() then return {1218347, {1222795,"CASTBAR"}} else return {999} end end');assert.deepEqual([...options],[1218347,1222795]);
 const choices=mechanicAbilities([1218347,474545,474740],{primary:options,names:{1218347:'Murder in a Row',474545:'Murder in a Row',474740:'Murder in a Row'}});assert.deepEqual(choices.map(a=>a.id),[1218347]);assert.deepEqual(choices[0].relatedSpellIds,[474545,474740]);
 const catalog=JSON.parse(await fs.readFile('resources/npc-catalog.json','utf8'));assert.equal(catalog.difficultyId,8);const zaen=catalog.dungeons[0].npcs.find(n=>n.id===234649);assert.deepEqual(zaen.abilities.filter(a=>a.name==='Murder in a Row').map(a=>a.id),[1218347]);for(const dungeon of catalog.dungeons)for(const npc of dungeon.npcs){assert.equal(new Set(npc.abilities.map(a=>a.id)).size,npc.abilities.length);assert.ok(npc.abilities.every(a=>npc.associatedSpellIds.includes(a.id)||/^[a-f0-9]{64}$/.test(a.mechanicSourceSha256||a.exBoss?.sourceSha256||'')));const names=npc.abilities.map(a=>a.name?.toLowerCase()).filter(Boolean);assert.equal(new Set(names).size,names.length);}
});
