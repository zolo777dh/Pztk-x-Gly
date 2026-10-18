import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {parseReference} from '../core/encounters.mjs';
import {execFileSync} from 'node:child_process';
import {DoctorService} from '../core/service.mjs';
async function serviceFixture(t){const dir=await fs.mkdtemp(path.join(os.tmpdir(),'simple-planner-'));t.after(()=>fs.rm(dir,{recursive:true,force:true}));const service=await new DoctorService(dir,path.resolve('resources')).init();return service;}
test('priority HTML accepts numeric IDs, object spells, dictionary sets and standalone sets without Holy Paladin structure',()=>{
 const formats=[{presets:[{id:1,name:'Priest set',rows:[['Pain Suppression',33206],['Power Word: Barrier','62618']]}]},{presets:{disc:{name:'Discipline',spells:[{spellId:33206,name:'Pain Suppression'},{spell_id:62618,ability:'Power Word: Barrier'}]}}},{presets:[{key:'warrior',title:'Warrior',list:[871,12975]}]},{presets:[{id:'druid',name:'Druid',rows:{22812:'Barkskin',61336:'Survival Instincts'}}]}];
 for(const data of formats){const r=parseReference('<script>throw Error("never execute")</script><script type="application/json">'+JSON.stringify(data)+'</script>','other-class.html');assert.equal(r.kind,'cooldown-priority-reference');assert.equal(r.presets[0].rows.length,2);assert.ok(r.presets[0].rows.every(s=>typeof s[1]==='string'));assert.deepEqual(r.assignments,[]);}
});
test('static HTML discovers defensive sets across all tables while keeping enemy and recorded timing tables separate',()=>{
 const html='<h2>Boss mechanics</h2><table><tr><th>Enemy ability</th><th>Representative cast</th><th>Priority</th></tr><tr><td>Strike</td><td>123</td><td>High</td></tr></table><h2>Discipline defensives</h2><table><tr><th>Preset</th><th>Priority</th><th>Defensive ability</th><th>Spell ID</th></tr><tr><td>Personal</td><td>2</td><td>Power Word: Barrier</td><td>62618</td></tr><tr><td>Personal</td><td>1</td><td>Pain Suppression</td><td>33206</td></tr></table>';
 const r=parseReference(html);assert.equal(r.presets.length,1);assert.deepEqual(r.presets[0].rows.map(s=>s[1]),['33206','62618']);assert.deepEqual(r.assignments,[]);
 const records=parseReference('<table><tr><th>defensiveName</th><th>defensiveSpellId</th><th>defensiveTime</th></tr><tr><td>Barkskin</td><td>22812</td><td>3</td></tr></table>');assert.equal(records.kind,'static-html');
});
test('every dungeon restricts NPC and timer spells before assignment; exports preserve original profile data',async t=>{
 const s=await serviceFixture(t),catalog=await s.handle('npc.catalog');const p=await s.handle('planner.importProfile',{text:s.codec.encode({format:1,name:'Original',data:{presets:{'256':{disc:{name:'Disc',list:[33206,62618]}}},settings:{keep:true}}})});let view=await s.handle('nsr.open',{profileId:p.id});
 for(const dungeon of catalog.dungeons){const npc=dungeon.npcs.find(n=>n.kind==='trash'&&n.abilities.length),spell=npc.abilities[0].id;const args={id:view.id,revision:view.revision,mapId:dungeon.mapId,npcId:npc.id,spellId:spell,specId:256,preset:'disc'};
 await assert.rejects(()=>s.handle('nsr.assignNpc',{...args,spellId:1}),/belonging to this NPC/);await assert.rejects(()=>s.handle('nsr.assignNpc',{...args,timerSpellId:1}),/timer spell must belong/);assert.equal((await s.handle('nsr.read',{id:view.id})).revision,view.revision);
 view=await s.handle('nsr.assignNpc',args);assert.ok(view.specs.find(p=>p.id==='256').trash.some(r=>r.mapId===dungeon.mapId&&r.spellId===spell&&r.preset==='disc'));
 }
 const exported=await s.handle('nsr.export',{id:view.id,revision:view.revision});const p2=s.codec.decode(exported.text);assert.equal(p2.data.settings.keep,true);assert.equal(Object.keys(p2.data.integrationRules['256']).length,8);assert.deepEqual(Object.values(p2.data.presets['256'].disc.list),[33206,62618]);if(process.env.DOCTOR_LUA51&&process.env.DOCTOR_ADDON_TEST_ROOT){const file=path.join(s.dataDir,'catalog-export.txt');await fs.writeFile(file,exported.text);const res=path.resolve('resources/codec');const script=`strmatch=string.match\ndofile(${JSON.stringify(res+'/LibStub.lua')})\ndofile(${JSON.stringify(res+'/LibSerialize.lua')})\ndofile(${JSON.stringify(res+'/LibDeflate.lua')})\nNaowhUITankReminder={L=function(s)return s end,SpecName=function(s)return tostring(s)end,UI={Widgets={}},THEME={}}\nCreateFrame=function()return {SetScript=function()end,RegisterEvent=function()end}end\ndofile(${JSON.stringify(process.env.DOCTOR_ADDON_TEST_ROOT+'/NaowhUI_SmartReminders_Integrations.lua')})\ndofile(${JSON.stringify(process.env.DOCTOR_ADDON_TEST_ROOT+'/NaowhUI_SmartReminders_Packs.lua')})\nlocal f=assert(io.open(${JSON.stringify(file)},'r'));local p,e=NaowhUITankReminder.DecodePack(f:read('*a'));assert(p,e);local n=0;for _,r in pairs(p.data.integrationRules['256'])do assert(NaowhUITankReminder.Integrations.ValidRule(r));assert(r.pztkNpc);n=n+1 end;assert(n==8);print('SCOPED_NPC_EXPORT_OK')`;const lua=path.join(s.dataDir,'catalog-check.lua');await fs.writeFile(lua,script);assert.match(execFileSync(process.env.DOCTOR_LUA51,[lua],{encoding:'utf8'}),/SCOPED_NPC_EXPORT_OK/);}
});
