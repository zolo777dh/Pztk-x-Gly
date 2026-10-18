// Extract factual identifiers only; never execute downloaded Lua.
// node tools/build-npc-catalog.mjs MDT LittleWigs [uploaded-overlay-root] [archive-sha256]
import fs from 'node:fs/promises';
import path from 'node:path';
import luaparse from 'luaparse';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {DUNGEONS} from '../core/dungeons.mjs';
import {mythicCatalog} from '../core/mythic-catalog.mjs';
import {readLittleWigsModule,mechanicAbilities} from './catalog-options.mjs';
import {readExBossData,exBossEncounter} from './exboss-data.mjs';
const [mdt,lw,overlay,archiveSha256,exBossRoot,exBossArchiveSha256]=process.argv.slice(2);
if(!mdt||!lw)throw Error('Supply MDT and LittleWigs source checkout paths');
const revision=root=>execFileSync('git',['-C',root,'rev-parse','HEAD'],{encoding:'utf8'}).trim();
const hash=s=>createHash('sha256').update(s).digest('hex');
const norm=s=>String(s||'').toLowerCase().replace(/[^a-z0-9]/g,'');
const files={2813:['MurderRow','Midnight/MurderRow'],2825:['DenOfNalorakk','Midnight/DenOfNalorakk'],2859:['TheBlindingVale','Midnight/TheBlindingVale'],2923:['VoidscarArena','Midnight/VoidscarArena'],2993:['AltarOfFangs','Midnight/AltarOfFangs'],2521:['RubyLifePools','Dragonflight/RubyLifePools'],1877:['TempleOfSethraliss','BfA/TempleOfSethraliss'],1762:['KingsRest','BfA/KingsRest']};
const literal=node=>node?.type==='TableConstructorExpression'?Object.fromEntries(node.fields.filter(f=>f.type==='TableKey'||f.type==='TableKeyString').map(f=>[f.key.name??f.key.value,literal(f.value)])):node?.value;
const dungeons=[],overlayMaps=[];
const exBoss=exBossRoot?await readExBossData(exBossRoot):null;
async function modulesFor(dungeon,folder){
 const modules=[];let uploaded=[];if(overlay){try{uploaded=await fs.readdir(path.join(overlay,folder));}catch(e){if(e.code!=='ENOENT')throw e;}}
 const names=[...new Set([...(await fs.readdir(path.join(lw,folder))),...uploaded])].filter(n=>n.endsWith('.lua')).sort();
 for(const file of names){
  const fromUpload=uploaded.includes(file),sourcePath=folder+'/'+file,bytes=await fs.readFile(path.join(fromUpload?overlay:lw,sourcePath)),source=bytes.toString('utf8');
  const boss=source.match(/NewBoss\("([^"]+)",\s*(\d+)(?:,\s*(\d+))?/),enc=source.match(/SetEncounterID\((\d+)\)/);
  if(!boss||Number(boss[2])!==dungeon.mapId)continue;
  const data=readLittleWigsModule(source),enabled=source.match(/RegisterEnableMob\(([\s\S]*?)\)/)?.[1]?.replace(/--[^\n]*/g,'')||'';
  const aliases=(source.match(/RegisterEnableMob\([^)]*\)\s*--([^\n]+)/)?.[1]||'').split(',').map(norm);
  modules.push({...data,fileStem:path.basename(file,'.lua'),aliases,npcIds:new Set((enabled.match(/\d+/g)||[]).map(Number)),name:boss[1],encounterId:enc?Number(enc[1]):null,journalEncounterId:boss[3]?Number(boss[3]):null,source:sourcePath,sourceSha256:hash(bytes),fromUpload});
 }
 if(modules.some(m=>m.fromUpload))overlayMaps.push(dungeon.mapId);
 return modules;
}
function proof(ability,module){return {...ability,mechanicSource:module.source,mechanicSourceSha256:module.sourceSha256,sourceKind:module.fromUpload?'uploaded LittleWigs':'LittleWigs snapshot',mythicEvidence:module.timers.has(ability.id)?'reachable LittleWigs timer':module.messages.has(ability.id)?'reachable LittleWigs message':'LittleWigs cast/creature reference',timerEvidence:module.timers.has(ability.id)?'LittleWigs Bar/CDBar key':null,messageEvidence:module.messages.has(ability.id)};}
for(const dungeon of DUNGEONS){
 const [stem,folder]=files[dungeon.mapId],sourceFile='Midnight/'+stem+'.lua',text=await fs.readFile(path.join(mdt,sourceFile),'utf8'),ast=luaparse.parse(text,{encodingMode:'pseudo-latin1'});
 const statement=ast.body.find(n=>n.type==='AssignmentStatement'&&n.variables.some(v=>v.type==='IndexExpression'&&v.base?.type==='MemberExpression'&&v.base.identifier.name==='dungeonEnemies'));
 if(!statement)throw Error('Missing MDT enemy table '+stem);
 const enemies=literal(statement.init[0]),modules=await modulesFor(dungeon,folder),allNames=Object.assign({},...modules.map(m=>m.names)),npcs=[];
 const trash=exBoss?.trash[dungeon.challengeModeId]?.mobs||{};
 const rawEnemies=Object.values(enemies);for(const mob of Object.values(trash))if(!rawEnemies.some(n=>n.id===mob.npcID))rawEnemies.push({id:mob.npcID,name:exBoss.locale[mob.npcID]?.enUS||'NPC '+mob.npcID,spells:{}});
 function ownerFor(enemy){if(!enemy.isBoss)return null;const direct=modules.find(m=>m.encounterId&&(m.npcIds.has(enemy.id)||m.aliases.includes(norm(enemy.name))||norm(m.name)===norm(enemy.name)||norm(m.fileStem)===norm(enemy.name)));if(direct)return direct;const spellIds=Object.keys(enemy.spells||{}).map(Number),matches=modules.filter(m=>m.encounterId&&m.journalEncounterId===enemy.encounterID&&[...m.options].some(id=>spellIds.includes(id)));return matches.length===1?matches[0]:null;}
 const ownerCounts=new Map();for(const e of rawEnemies){const owner=ownerFor(e);if(owner)ownerCounts.set(owner,(ownerCounts.get(owner)||0)+1);}
 for(const enemy of rawEnemies){
  if(!Number.isInteger(enemy.id)||!enemy.name||npcs.some(n=>n.id===enemy.id))continue;
  const ids=Object.keys(enemy.spells||{}).map(Number).sort((a,b)=>a-b),owner=ownerFor(enemy);
  if(!ids.length&&!owner&&!trash[enemy.id])continue;
  let abilities;
  if(owner){
   // A reachable Mythic-compatible LittleWigs broadcast is valid on its own.
   // MDT is an NPC association source, not a complete allowlist of timer keys.
   const encounter=exBoss&&exBossEncounter(exBoss,dungeon.mapId,owner.encounterId,owner);
   const primary=[...owner.options].filter(id=>(owner.timers.has(id)||owner.messages.has(id))&&(ownerCounts.get(owner)===1||ids.includes(id)||owner.auras.some(a=>a.parentId===id&&ids.includes(a.id))||encounter?.events.some(e=>e.littleWigsSpellId===id&&ids.includes(e.spellId)))).sort((a,b)=>Number(owner.timers.has(b))-Number(owner.timers.has(a)));
   abilities=mechanicAbilities(ids,{primary,names:allNames,bars:owner.timers,source:owner.source,verifiedPrimary:true}).map(a=>proof(a,owner));
   for(const aura of owner.auras){const target=abilities.find(a=>a.id===aura.parentId||norm(a.name)===norm(aura.name));if(target&&target.id!==aura.id&&!target.relatedSpellIds.includes(aura.id))target.relatedSpellIds.push(aura.id);}
   for(const event of encounter?.events||[]){let target=abilities.find(a=>a.id===event.littleWigsSpellId||a.id===event.spellId||a.relatedSpellIds.includes(event.spellId));if(!target){if(ownerCounts.get(owner)>1&&!ids.includes(event.spellId))continue;target={id:event.spellId,name:allNames[event.spellId]||null,selectionKind:'mechanic',timerEvidence:null,relatedSpellIds:[],mythicEvidence:'EXBoss configured Mythic+ encounter event'};abilities.push(target);}target.exBoss||={mapId:dungeon.mapId,encounterId:owner.encounterId,source:'EncounterData.lua',sourceSha256:exBoss.files['EncounterData.lua'],events:[]};target.exBoss.events.push(event);}
  }else{
   const candidates=new Map(ids.map(id=>[id,{id,name:allNames[id]||null,selectionKind:'associated-spell',timerEvidence:null,relatedSpellIds:[]}]));
   for(const spell of Object.values(trash[enemy.id]?.spells||{})){if(!Number.isInteger(spell.spellID)||spell.spellID<=0)continue;const old=candidates.get(spell.spellID);candidates.set(spell.spellID,{...old,id:spell.spellID,name:old?.name||spell.nameEN||null,selectionKind:'mechanic',relatedSpellIds:old?.relatedSpellIds||[],timerEvidence:'EXBoss trash cooldown key',exBoss:{mapId:dungeon.mapId,challengeModeId:dungeon.challengeModeId,npcId:enemy.id,spellId:spell.spellID,first:spell.first??null,cd:Object.values(spell.cd||{}),castTime:spell.castTime??null,source:'TrashCDData.lua',sourceSha256:exBoss.files['TrashCDData.lua']}});}
   for(const module of modules.filter(m=>!m.encounterId))for(const aura of module.auras){
    const named=aura.npcName&&norm(aura.npcName)===norm(enemy.name),headed=aura.npcId===enemy.id;
    if(!named&&!headed&&!ids.includes(aura.id)&&!ids.includes(aura.parentId))continue;
    if(aura.npcName&&!named&&aura.npcId&&!headed)continue;
    const id=aura.parentId||aura.id,old=candidates.get(id),auraOld=candidates.get(aura.id),related=[...(old?.relatedSpellIds||[])];
    if(id!==aura.id){if(!related.includes(aura.id))related.push(aura.id);candidates.delete(aura.id);}
    const verified=proof({id,name:module.names[id]||aura.name||old?.name||null,selectionKind:aura.parentId?'mechanic':'aura',relatedSpellIds:related},module),exTimer=old?.exBoss||auraOld?.exBoss;
    if(exTimer){verified.exBoss=exTimer;verified.timerEvidence='EXBoss trash cooldown key';if(exTimer.spellId!==id)verified.timerSpellId=exTimer.spellId;}
    candidates.set(id,verified);
   }
   const grouped=new Map();for(const a of [...candidates.values()].sort((a,b)=>Number(b.selectionKind==='mechanic')-Number(a.selectionKind==='mechanic'))){const k=a.name?norm(a.name):'id:'+a.id,previous=grouped.get(k);if(previous){previous.relatedSpellIds=[...new Set([...previous.relatedSpellIds,a.id,...a.relatedSpellIds])];}else grouped.set(k,a);}abilities=[...grouped.values()].sort((a,b)=>a.id-b.id);
  }
  npcs.push({id:enemy.id,name:enemy.name,kind:enemy.isBoss?'boss':'trash',encounterId:owner?.encounterId||null,journalEncounterId:owner?.journalEncounterId||null,abilities,associatedSpellIds:ids,source:sourceFile,...(owner?{bossSource:owner.source,bossSourceSha256:owner.sourceSha256}:{})});
 }
 dungeons.push({...dungeon,npcs});
}
const sources=[{name:'Mythic Dungeon Tools',url:'https://github.com/Nnoggie/MythicDungeonTools',revision:revision(mdt),fields:'Seasonal Mythic+ NPC identities and associated spell IDs; not an exhaustive timer-key allowlist'},{name:'LittleWigs',url:'https://github.com/BigWigsMods/LittleWigs',revision:revision(lw),fields:'Encounter IDs, reachable Mythic/Retail Bar/CDBar and message keys, creature/aura/cast references',...(overlay?{uploadedArchive:{name:'Midnight.zip',sha256:archiveSha256||null,mapIds:overlayMaps}}:{})}];
if(exBoss)sources.push({name:'EXBossData',version:'1.0.0',uploadedArchive:{name:'EXBossData.zip',sha256:exBossArchiveSha256||null},files:exBoss.files,fields:'Configured Mythic+ event/spell relations, instance/challenge maps, NPC names and trash cooldown keys; no defensive presets or executable code'});
const output=mythicCatalog({format:'pztk-npc-catalog-v1',verifiedAt:'2026-10-18',client:'Retail 12.1.5',sources,dungeons});
await fs.writeFile('resources/npc-catalog.json',JSON.stringify(output,null,2)+'\n');
console.log(output.dungeons.map(d=>({name:d.name,npcs:d.npcs.length,abilities:d.npcs.reduce((n,e)=>n+e.abilities.length,0),bossesWithEncounterId:d.npcs.filter(e=>e.encounterId).length})));
