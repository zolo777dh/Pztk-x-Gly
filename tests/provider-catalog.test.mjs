import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {execFileSync} from 'node:child_process';
import {readLittleWigsModule} from '../tools/catalog-options.mjs';
import {literalTables,exBossEncounter} from '../tools/exboss-data.mjs';
import {DoctorService} from '../core/service.mjs';
const catalog=JSON.parse(await fs.readFile('resources/npc-catalog.json','utf8'));
const npc=(map,id)=>catalog.dungeons.find(d=>d.mapId===map).npcs.find(n=>n.id===id);
test('LittleWigs follows reachable Mythic handlers and Retail overrides without treating cast bars or unused handlers as cooldowns',()=>{
 const source=`function mod:GetOptions() return {1} end
 if mod:Retail() then function mod:GetOptions() return {101,102,103,104} end end
 function mod:OnEncounterStart() self:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED") end
 function mod:ENCOUNTER_TIMELINE_EVENT_ADDED(_,info) if self:Mythic() then if duration == 13 then self:MythicSpell() end else self:NormalSpell() end end
 function mod:MythicSpell() self:CDBar(101,13);self:CastBar(102,4) end
 function mod:NormalSpell() self:CDBar(103,13) end
 function mod:Unused() self:CDBar(104,13) end`;
 const data=readLittleWigsModule(source);assert.deepEqual([...data.options],[101,102,103,104]);assert.deepEqual([...data.timers],[101]);assert.deepEqual(data.durationRules,[{duration:13,spellId:101}]);assert.ok(!data.reachableMethods.includes('NormalSpell'));assert.ok(!data.reachableMethods.includes('Unused'));
 const alternate=source.replace('if duration == 13 then','if (self:Mythic() and duration == 13) or (not self:Mythic() and duration == 99) then');assert.deepEqual(readLittleWigsModule(alternate).durationRules,[{duration:13,spellId:101}]);
});
test('spell labels come from mechanic options/renames rather than boss section headers; aura references keep creature identity',()=>{
 const source=`mod:SetRenames({
 [1311804]={1311804}, -- Overload
 })
 mod:SetAuraData({
 {200,header=99,tip=CL.afterCast:format(mod:SpellName(100))}, -- Bleed (Creature)
 })
 function mod:GetOptions() return {
 1311804, -- Overload
 },{
 [1311804]=CL.stage, -- Adderis
 } end`;
 const data=readLittleWigsModule(source);assert.equal(data.names[1311804],'Overload');assert.deepEqual(data.auras[0],{id:200,name:'Bleed',parentId:100,npcId:99,npcName:'Creature'});
});
test('EXBoss extraction reads Unicode literals and constants without executing Lua or importing generated defensive packs',()=>{
 globalThis.__exbossExecuted=false;const tables=literalTables('local MODE="AI"\nlocal Data={name="诸王之眠",trigger=MODE,values={1,2},notData=os.execute("bad")}\n_G.Root={spellID=123}\nfunction Run() __exbossExecuted=true end');assert.equal(globalThis.__exbossExecuted,false);assert.equal(tables.Data.name,'诸王之眠');assert.equal(tables.Data.trigger,'AI');assert.deepEqual(Object.values(tables.Data.values),[1,2]);assert.equal(tables.Data.notData,null);assert.equal(tables.Root.spellID,123);delete globalThis.__exbossExecuted;
});
test('EXBoss selects configured Mythic events, separates event IDs and spell IDs, and maps only unambiguous duration keys',()=>{
 const data={contract:{scope:{mapIDs:{1:2813},bossEventExclusions:{1:513}}},encounter:{maps:{2813:{bosses:{3102:{journalEncounterID:2680,events:{17:{eventID:17,spellID:200},18:{eventID:18,spellID:999},513:{eventID:513,spellID:666}}}}}}},triggers:{3102:{trigger:'AI',durationRules:{1:{time:13,eventID:17},2:{time:5,eventID:513}}}}};
 const little={options:new Set([100]),timers:new Set([100]),messages:new Set(),durationRules:[{duration:13,spellId:100}]};const mapped=exBossEncounter(data,2813,3102,little);assert.equal(mapped.events.length,1);assert.equal(mapped.events[0].spellId,200);assert.deepEqual(mapped.events[0].eventIds,[17]);assert.equal(mapped.events[0].littleWigsSpellId,100);assert.equal(exBossEncounter(data,2993,3102,little),null);
 const ambiguous=exBossEncounter(data,2813,3102,{...little,durationRules:[...little.durationRules,{duration:13,spellId:300}]});assert.equal(ambiguous.events[0].littleWigsSpellId,null);
 const exact=exBossEncounter(data,2813,3102,{...little,options:new Set([200]),timers:new Set([200])});assert.equal(exact.events[0].littleWigsSpellId,null);
});
test('catalog uses both uploaded archives, restores real broadcast keys absent from MDT, and scopes grouped boss creatures',()=>{
 assert.equal(catalog.sources.find(s=>s.name==='EXBossData').uploadedArchive.sha256,'610f39c75ad7a87c4d1f5fa94c17c7e9800ef738573eb585f2e0b697684a8a42');assert.equal(catalog.sources.find(s=>s.name==='LittleWigs').uploadedArchive.mapIds.length,5);
 const zaen=npc(2813,234649),delivery=zaen.abilities.find(a=>a.id===474765);assert.ok(delivery);assert.equal(delivery.sourceKind,'uploaded LittleWigs');assert.equal(delivery.mythicEvidence,'reachable LittleWigs timer');assert.equal(zaen.associatedSpellIds.includes(474765),false);assert.deepEqual(zaen.abilities.filter(a=>a.name==='Murder in a Row').map(a=>a.id),[1218347]);assert.ok(!zaen.abilities.some(a=>[1218465,1218466].includes(a.id)));
 const nalorakk=npc(2825,246404);assert.equal(nalorakk.encounterId,3209);assert.equal(nalorakk.abilities.find(a=>a.id===1243569).exBoss.events[0].spellId,1297792);
 const trinity=[243028,243029,243030].map(id=>npc(2859,id));for(const creature of trinity){assert.equal(creature.encounterId,3199);assert.ok(creature.abilities.every(a=>creature.associatedSpellIds.includes(a.id)));}assert.ok(!trinity[0].abilities.some(a=>a.id===1235564));assert.equal(npc(1877,133392).encounterId,2127);
});
test('NSR export uses the EXBoss timer alias and instance map rather than challenge mode or timeline event ID',async t=>{
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'provider-keys-'));t.after(()=>fs.rm(dir,{recursive:true,force:true}));const s=await new DoctorService(dir,path.resolve('resources')).init();const p=await s.handle('planner.createProfile');let view=await s.handle('nsr.open',{profileId:p.id});view=await s.handle('nsr.change',{id:view.id,revision:view.revision,operation:{kind:'preset.save',args:{specId:264,key:'defense',name:'Defense',spells:[{spellId:108271}]}}});
 view=await s.handle('nsr.assignNpc',{id:view.id,revision:view.revision,specId:264,mapId:2825,npcId:245855,spellId:1238725,preset:'defense'});const trash=view.specs[0].trash[0];assert.equal(trash.mapId,2825);assert.equal(trash.spellId,1238687);assert.equal(trash.catalog.spellId,1238725);
 view=await s.handle('nsr.assignNpc',{id:view.id,revision:view.revision,specId:264,mapId:2813,npcId:234649,spellId:474765,preset:'defense'});const out=await s.handle('nsr.export',{id:view.id,revision:view.revision}),decoded=s.codec.decode(out.text);assert.equal(decoded.data.abilityBindings['264']['3102']['474765'].preset,'defense');assert.ok(!decoded.data.abilityBindings['264']['3102']['124']);const rule=Object.values(decoded.data.integrationRules['264'])[0];assert.equal(rule.trigger.mapID,2825);assert.equal(rule.trigger.spellID,1238687);
 if(process.env.DOCTOR_LUA51&&process.env.DOCTOR_ADDON_TEST_ROOT){const file=path.join(dir,'export.txt');await fs.writeFile(file,out.text);const r=path.resolve('resources/codec');const script=`strmatch=string.match\ndofile(${JSON.stringify(r+'/LibStub.lua')})\ndofile(${JSON.stringify(r+'/LibSerialize.lua')})\ndofile(${JSON.stringify(r+'/LibDeflate.lua')})\nNaowhUITankReminder={L=function(s)return s end,SpecName=function(s)return tostring(s)end,UI={Widgets={}},THEME={}}\nCreateFrame=function()return {SetScript=function()end,RegisterEvent=function()end}end\ndofile(${JSON.stringify(process.env.DOCTOR_ADDON_TEST_ROOT+'/NaowhUI_SmartReminders_Integrations.lua')})\ndofile(${JSON.stringify(process.env.DOCTOR_ADDON_TEST_ROOT+'/NaowhUI_SmartReminders_Packs.lua')})\nlocal f=assert(io.open(${JSON.stringify(file)},'rb'));local p,e=NaowhUITankReminder.DecodePack(f:read('*a'));assert(p,e);assert(p.data.abilityBindings['264']['3102'][474765].preset=='defense');for _,rule in pairs(p.data.integrationRules['264'])do assert(NaowhUITankReminder.Integrations.ValidRule(rule));assert(rule.trigger.mapID==2825);assert(rule.trigger.spellID==1238687)end;print('PROVIDER_KEYS_NATIVE_NSR_OK')`;const lua=path.join(dir,'check.lua');await fs.writeFile(lua,script);assert.match(execFileSync(process.env.DOCTOR_LUA51,[lua],{encoding:'utf8'}),/PROVIDER_KEYS_NATIVE_NSR_OK/);}
});
