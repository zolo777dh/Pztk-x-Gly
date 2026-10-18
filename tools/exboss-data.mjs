import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import luaparse from 'luaparse';
// Decode only table literals. Functions, calls and assignments are never run.
export function literalTables(source){
 const ast=luaparse.parse(Buffer.from(source,'utf8').toString('latin1'),{encodingMode:'pseudo-latin1'}),out=Object.create(null),constants=Object.create(null);
 const decode=n=>{
  if(!n)return null;
  if(n.type==='StringLiteral')return Buffer.from(n.value,'latin1').toString('utf8');
  if(['NumericLiteral','BooleanLiteral'].includes(n.type))return n.value;
  if(n.type==='NilLiteral')return null;
  if(n.type==='Identifier')return constants[n.name]??null;
  if(n.type==='UnaryExpression'&&n.operator==='-'&&n.argument.type==='NumericLiteral')return -n.argument.value;
  if(n.type!=='TableConstructorExpression')return null;
  const table=Object.create(null);let index=1;
  for(const field of n.fields){const key=field.type==='TableValue'?index++:field.type==='TableKeyString'?field.key.name:decode(field.key);if(key!=null&&!['__proto__','constructor','prototype'].includes(String(key)))table[key]=decode(field.value);}
  return table;
 };
 for(const s of ast.body){if(!['LocalStatement','AssignmentStatement'].includes(s.type))continue;for(let i=0;i<(s.variables||[]).length;i++){const variable=s.variables[i],name=variable.type==='Identifier'?variable.name:variable.type==='MemberExpression'&&variable.base?.name==='_G'?variable.identifier.name:null;if(!name||!s.init[i])continue;const value=decode(s.init[i]);if(s.init[i].type==='TableConstructorExpression')out[name]=value;else if(['StringLiteral','NumericLiteral','BooleanLiteral'].includes(s.init[i].type))constants[name]=value;}}
 return out;
}
export async function readExBossData(root){
 const files={};for(const name of ['EncounterData.lua','TrashCDData.lua','TrashCDLocale.lua','FixedTimelineBosses.lua']){const bytes=await fs.readFile(path.join(root,name));files[name]={sha256:createHash('sha256').update(bytes).digest('hex'),tables:literalTables(bytes.toString('utf8'))};}
 const encounter=files['EncounterData.lua'].tables.EncounterData,trash=files['TrashCDData.lua'].tables.EXBOSS_TRASH_CD_DATA,locale=files['TrashCDLocale.lua'].tables.EXBOSS_TRASH_CD_LOCALE,triggers=files['FixedTimelineBosses.lua'].tables.encounterTriggers;
 if(!encounter?.maps||!trash||!locale||!triggers)throw Error('EXBossData literal tables are missing');
 return {encounter,trash,locale,triggers,files:Object.fromEntries(Object.entries(files).map(([name,f])=>[name,f.sha256])),contract:files['EncounterData.lua'].tables.EXBOSS_ENCOUNTER_DATA_SOURCE_CONTRACTS?.mplus||null};
}

export function exBossEncounter(data,mapId,encounterId,littleWigs){
 const boss=data.encounter.maps[mapId]?.bosses?.[encounterId],config=data.triggers[encounterId];if(!boss||!config)return null;
 if(!Object.values(data.contract?.scope?.mapIDs||{}).includes(Number(mapId)))return null;
 const rules=[];function walk(n){if(!n||typeof n!=='object')return;if(Number.isInteger(n.eventID))rules.push({eventId:n.eventID,duration:Number.isFinite(n.time)?n.time:null});Object.values(n).forEach(walk);}walk(config);
 const exclusions=new Set(Object.values(data.contract?.scope?.bossEventExclusions||{}));
 const byDuration=new Map();for(const rule of littleWigs?.durationRules||[]){if(!byDuration.has(rule.duration))byDuration.set(rule.duration,new Set());byDuration.get(rule.duration).add(rule.spellId);}
 const selected=new Map();for(const rule of rules){const event=boss.events?.[rule.eventId];if(!event||exclusions.has(rule.eventId)||!Number.isInteger(event.spellID)||event.spellID<=0)continue;
  const exact=littleWigs?.options.has(event.spellID)&&(littleWigs.timers.has(event.spellID)||littleWigs.messages.has(event.spellID));
  const matches=byDuration.get(rule.duration),key=!exact&&matches?.size===1?[...matches][0]:event.spellID;
  // A unique shared timer duration is evidence for a cross-provider key, never
  // for an arbitrary source NPC or a different encounter.
  const target=selected.get(event.spellID)||{spellId:event.spellID,littleWigsSpellId:key!==event.spellID?key:null,eventIds:[],trigger:config.trigger,castType:event.castType||null,...(key!==event.spellID?{mappingEvidence:'unique literal duration in matching Mythic-compatible encounter',duration:rule.duration}:{})};
  if(target.littleWigsSpellId!=null&&key!==event.spellID&&target.littleWigsSpellId!==key)target.littleWigsSpellId=null;
  if(!target.eventIds.includes(rule.eventId))target.eventIds.push(rule.eventId);selected.set(event.spellID,target);
 }
 return {journalEncounterId:boss.journalEncounterID,events:[...selected.values()],configuredEventIds:[...new Set(rules.map(r=>r.eventId))]};
}
