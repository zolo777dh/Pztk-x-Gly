import fs from 'node:fs/promises';
import path from 'node:path';
import {uid,sha,writeAtomic} from './files.mjs';
import {parseReference,stats} from './encounters.mjs';

const integer=(v,min=1,max=100000000)=>Number.isInteger(Number(v))&&Number(v)>=min&&Number(v)<=max;
const object=v=>v&&typeof v==='object'&&!Array.isArray(v);
const utf8=(value,limit)=>{let result='';for(const character of String(value)){if(Buffer.byteLength(result+character)>limit)break;result+=character;}return result;};
const spellList=v=>Array.isArray(v)?v.map(Number).filter(n=>integer(n)):Object.keys(v||{}).sort((a,b)=>Number(a)-Number(b)).map(k=>Number(v[k])).filter(n=>integer(n));
const keyFor=m=>JSON.stringify([m.dungeon,m.encounter,Number(m.bossSpellId),m.kind]);
const fieldName=s=>String(s).toLowerCase().replace(/[^a-z0-9]/g,'');
const round=n=>Math.round(n*1000)/1000;
const healers=new Set([65,105,256,257,264,270,1468]);
import {DEFENSE_COLUMNS} from './defense-columns.mjs';
export {DEFENSE_COLUMNS};
const aliases={dungeon:['instance','dungeonname'],encounter:['boss','encountername','enemy'],kind:['type','contenttype'],bossSpellId:['mechanicspellid','enemyspellid','castid','cast'],bossAbility:['mechanic','ability'],bossTime:['bosseventtime','eventtime','meanbosstime'],defensiveSpellId:['defensivespell','defensiveid','playerspellid'],defensiveTime:['presstime','defensivepresstime','meandefensivetime'],sample:['sampleid','pull','pullid','logpull'],player:['playername','actor','actorname'],specId:['spec','specializationid'],classToken:['class'],occurrence:['number','castnumber'],sampleCount:['count','samples','n']};
export function guessDefenseColumns(header){const names=header.map(fieldName);return Object.fromEntries(DEFENSE_COLUMNS.map(key=>[key,names.findIndex(n=>[key,...(aliases[key]||[])].map(fieldName).includes(n))]));}
export function inspectDefenseTable(text,filename){const ref=parseReference(text,filename);return {kind:ref.kind,tables:(ref.tables||[]).map(t=>({header:t[0]||[],preview:t.slice(1,4),rows:Math.max(0,t.length-1),columns:guessDefenseColumns(t[0]||[])})),mechanics:ref.assignments?.length||0};}
function seconds(value){if(typeof value==='number')return Number.isFinite(value)?value:null;const s=String(value??'').trim();if(/^\d+:[0-5]?\d(?:\.\d+)?$/.test(s)){const [m,sec]=s.split(':').map(Number);return m*60+sec;}if(/^-?\d+(?:[.,]\d+)?s?$/.test(s))return Number(s.replace(/s$/,'').replace(',','.'));return null;}
function mechanic(row){
  if(!row.dungeon||!row.encounter||!integer(row.bossSpellId))throw Error('Each mechanic needs dungeon, encounter and bossSpellId');
  return {dungeon:String(row.dungeon).slice(0,150),encounter:String(row.encounter).slice(0,150),kind:/trash/i.test(row.kind||'')?'trash':'boss',bossSpellId:Number(row.bossSpellId),bossAbility:String(row.bossAbility||`Spell ${row.bossSpellId}`).slice(0,150),encounterId:integer(row.encounterId)?Number(row.encounterId):0,mapId:integer(row.mapId)?Number(row.mapId):0,timerSpellId:integer(row.timerSpellId)?Number(row.timerSpellId):Number(row.bossSpellId),enabled:row.enabled!==false,bossActor:String(row.bossActor||''),referencePreset:row.referencePreset||null};
}
function observation(row,defaults,sourceId,index){
  const merged={...defaults,...Object.fromEntries(Object.entries(row).filter(([,v])=>v!==''&&v!=null))};const m=mechanic(merged);const bossTime=seconds(merged.bossTime),defensiveTime=seconds(merged.defensiveTime);
  if(!integer(merged.specId)||!integer(merged.defensiveSpellId)||bossTime==null||defensiveTime==null||bossTime<0||defensiveTime<0||bossTime>86400||defensiveTime>86400)throw Error(`Row ${index+1}: supply specId, defensiveSpellId and recorded boss/defensive times (seconds or m:ss)`);
  const count=merged.sampleCount==null||merged.sampleCount===''?1:Number(merged.sampleCount);if(!integer(count,1,100000))throw Error(`Row ${index+1}: invalid sample count`);
  const sample=String(merged.sample||(merged.report&&merged.fightId?merged.report+':'+merged.fightId:''));if(!sample)throw Error(`Row ${index+1}: an independent sample/pull identifier is required`);
  return {...m,id:sha(sourceId+':'+index).slice(0,16),sample,sourceId,player:String(merged.player||'unspecified'),specId:Number(merged.specId),classToken:String(merged.classToken||''),defensiveSpellId:Number(merged.defensiveSpellId),defensiveName:String(merged.defensiveName||`Spell ${merged.defensiveSpellId}`).slice(0,150),bossTime,defensiveTime,offset:defensiveTime-bossTime,occurrence:integer(merged.occurrence)?Number(merged.occurrence):1,difficulty:String(merged.difficulty||'unknown'),build:String(merged.build||'unknown'),count,aggregate:count>1};
}
export function parseDefenseTable(text,filename,{recorded=false,independentAggregates=false,columns,table=0,defaults={}}={}){
  if(typeof text!=='string'||Buffer.byteLength(text)>10e6)throw Error('Defense table exceeds 10 MB');
  const id=sha(JSON.stringify({text,columns,table,defaults,recorded,independentAggregates})).slice(0,16);let raw;try{if(/^\s*[\[{]/.test(text))raw=JSON.parse(text);}catch{throw Error('Invalid table JSON');}
  const reference=parseReference(text,filename);const mechanics=[],observations=[];
  if(reference.kind==='cooldown-priority-reference'){
    for(const a of reference.assignments){if(!integer(a.cast))continue;mechanics.push(mechanic({dungeon:a.dungeon,encounter:a.encounter,kind:a.type,bossSpellId:a.cast,bossAbility:a.ability,referencePreset:a.preset}));}
    // This document's samples are mechanic times and priority suggestions, never
    // defensive presses. A checkbox cannot turn those values into observations.
    return {id,filename,kind:'priority-reference',mechanics:[...new Map(mechanics.map(m=>[keyFor(m),m])).values()],observations:[],presets:reference.presets.map(p=>({...p,specId:Number(defaults.specId)||0})),recorded:false,warning:'Priority reference: no recorded defensive presses. Attach observed casts or a recorded timing table to calculate means.'};
  }
  let rows;
  if(raw?.format==='pztk-defense-observations-v1'&&Array.isArray(raw.observations))rows=raw.observations;
  else{
    const grid=reference.tables?.[Number(table)];if(!grid?.length)throw Error('Choose a table with a header row');const mapping=columns||guessDefenseColumns(grid[0]);
    rows=grid.slice(1).filter(row=>row.some(value=>String(value).trim())).map(row=>Object.fromEntries(DEFENSE_COLUMNS.map(key=>[key,Number.isInteger(Number(mapping[key]))&&Number(mapping[key])>=0?row[Number(mapping[key])]:undefined])));
  }
  if(!recorded)throw Error('Confirm that this table contains recorded defensive presses, not recommended timings');
  if(!rows.length||rows.length>10000)throw Error('Supply 1–10,000 observed rows');
  for(const [i,row]of rows.entries()){const obs=observation(row,defaults,id,i);if(obs.aggregate&&!independentAggregates)throw Error('Confirm that aggregated rows contain disjoint independent samples before using sampleCount');observations.push(obs);mechanics.push(mechanic(obs));}
  return {id,filename,kind:'recorded-presses',mechanics:[...new Map(mechanics.map(m=>[keyFor(m),m])).values()],observations,presets:[],recorded:true,warning:observations.some(o=>o.aggregate)?'Aggregated rows use count-weighted means; individual presses and within-group variance cannot be recovered. Independence is user-confirmed.':''};
}
export function profileDescription(pack){
  const profiles=pack.profiles?Object.entries(pack.profiles):[['',pack.data]];
  if(!profiles.length||profiles.some(([,data])=>!object(data)||data.presets!=null&&!object(data.presets)))throw Error('Unsupported NSR profile structure');
  return profiles.map(([key,data])=>({key,name:key||pack.name,specs:Object.entries(data.presets||{}).filter(([spec])=>integer(spec)).map(([spec,presets])=>({id:Number(spec),presets:Object.entries(presets).map(([id,p])=>({id,name:p.name||id,list:spellList(p.list)}))})),legacyBindings:data.bindingsBySpec===false&&Object.keys(data.abilityBindings||{}).length>0}));
}
function weighted(values,pick){const count=values.reduce((n,v)=>n+v.count,0);return {count,mean:values.reduce((n,v)=>n+pick(v)*v.count,0)/count};}
export function analyzeDefenses(profile,sources,config,timelines=[]){
  const data=profile.pack.profiles?profile.pack.profiles[config.profileKey]:profile.pack.data;if(!data)throw Error('Select the imported NSR profile to update');
  const mechanics=(config.mechanics||[]).filter(m=>m.enabled!==false).map(mechanic);if(!mechanics.length||mechanics.length>500)throw Error('Select 1–500 mechanics and their dungeon/encounter');
  if(new Set(mechanics.map(keyFor)).size!==mechanics.length)throw Error('Duplicate dungeon/encounter/spell mechanic');
  const byMechanic=new Map(mechanics.map(m=>[keyFor(m),m]));const records=sources.flatMap(s=>s.observations||[]).filter(o=>byMechanic.has(keyFor(o)));const warnings=sources.filter(s=>s.warning).map(s=>s.warning);const referencePresets=sources.flatMap(s=>s.presets||[]);
  const before=Number(config.windowBefore??10),after=Number(config.windowAfter??5);if(!Number.isFinite(before+after)||before<0||after<0||before>60||after>60)throw Error('Matching windows must be 0–60 seconds');
  const allDefenses=spec=>new Set(Object.values(data.presets?.[String(spec)]||{}).flatMap(p=>spellList(p.list)).concat((config.defensiveSpellIds||[]).map(Number)).filter(n=>integer(n)));
  for(const assignment of config.timelineAssignments||[]){
    if(!assignment.enabled)continue;const timeline=timelines.find(t=>t.id===assignment.timelineId);if(!timeline)throw Error('An assigned timeline is no longer cached');if(!integer(assignment.specId)||!integer(assignment.actorId))throw Error('Assign a specialization and player to each selected timeline');
    const targets=mechanics.filter(m=>m.dungeon===assignment.dungeon&&m.encounter===assignment.encounter);if(!targets.length)throw Error('Assign each selected timeline to a selected dungeon/encounter');
    const defenses=allDefenses(assignment.specId);if(!defenses.size)throw Error('The selected spec has no defensive preset. Supply defensive spell IDs for its recorded casts.');
    const sample=timeline.source?.report&&timeline.source?.fightId?timeline.source.report+':'+timeline.source.fightId:timeline.id;const candidates=[];
    for(const target of targets){const events=timeline.events.filter(e=>e.type===(config.bossEventType||'cast')&&Number(e.spellId)===target.bossSpellId&&(!target.bossActor||e.sourceName===target.bossActor)).sort((a,b)=>a.time-b.time);for(const [i,boss]of events.entries())candidates.push({target,boss,occurrence:i+1});}
    for(const event of timeline.events){if(event.type!=='cast'||Number(event.sourceId)!==Number(assignment.actorId)||!defenses.has(Number(event.spellId)))continue;let nearest=null;for(const c of candidates){const offset=event.time-c.boss.time;if(offset< -before||offset>after)continue;if(!nearest||Math.abs(offset)<Math.abs(nearest.offset))nearest={...c,offset,ambiguous:false};else if(Math.abs(offset)===Math.abs(nearest.offset))nearest.ambiguous=true;}if(!nearest)continue;if(nearest.ambiguous)throw Error('A recorded defensive cast is equally close to two mechanic events. Narrow the window or segment the fight.');
      records.push(observation({...nearest.target,specId:assignment.specId,classToken:assignment.classToken,player:event.sourceName||String(event.sourceId),sample,bossTime:nearest.boss.time,defensiveTime:event.time,defensiveSpellId:event.spellId,defensiveName:event.name,occurrence:nearest.occurrence,difficulty:timeline.difficulty||'unknown',build:timeline.build||'unknown'},{},timeline.id,records.length));
    }
  }
  // One observation per player/spell/occurrence/pull; conflicting copies are not
  // independent evidence. A press paired to two mechanics goes to the nearest.
  const unique=new Map();let duplicates=0;
  for(const record of records){if(record.offset< -before||record.offset>after||(config.difficulty&&record.difficulty!==config.difficulty)||(config.build&&record.build!==config.build))continue;const key=JSON.stringify([record.dungeon,record.encounter,record.sample,record.player,record.specId,record.bossSpellId,record.occurrence,record.defensiveSpellId]);if(unique.has(key)){const previous=unique.get(key);if(previous.bossTime!==record.bossTime||previous.defensiveTime!==record.defensiveTime||previous.count!==record.count||previous.build!==record.build||previous.difficulty!==record.difficulty)throw Error('Conflicting duplicate observation for '+record.sample);duplicates++;continue;}unique.set(key,record);}
  const attributed=new Map();for(const r of unique.values()){const key=r.aggregate?r.id:JSON.stringify([r.dungeon,r.sample,r.player,r.specId,r.defensiveSpellId,r.defensiveTime]);const previous=attributed.get(key);if(!previous||Math.abs(r.offset)<Math.abs(previous.offset))attributed.set(key,r);else if(keyFor(r)!==keyFor(previous)&&Math.abs(r.offset)===Math.abs(previous.offset))throw Error('A defensive press is equally close to two mechanics. Refine the table or matching window.');}
  const groups=new Map();for(const record of attributed.values()){const id=JSON.stringify([keyFor(record),record.specId,record.difficulty,record.build]);if(!groups.has(id))groups.set(id,[]);groups.get(id).push(record);}
  const results=[];
  for(const [key,records]of groups){const first=records[0],target=byMechanic.get(keyFor(first));const contextPeers=[...groups.keys()].filter(k=>{const a=JSON.parse(k),b=JSON.parse(key);return a[0]===b[0]&&a[1]===b[1];});const mixedContext=contextPeers.length>1;
    const candidates=new Map();for(const record of records){if(!candidates.has(record.defensiveSpellId))candidates.set(record.defensiveSpellId,[]);candidates.get(record.defensiveSpellId).push(record);}
    const priorities=[...candidates].map(([spellId,values])=>({spellId,name:values[0].defensiveName,samples:weighted(values,v=>v.offset).count,meanOffset:weighted(values,v=>v.offset).mean,meanPressTime:weighted(values,v=>v.defensiveTime).mean,pulls:new Set(values.map(v=>v.sample)).size})).sort((a,b)=>b.pulls-a.pulls||b.samples-a.samples||a.spellId-b.spellId);
    const existing=Object.values(data.presets?.[String(first.specId)]||{}).flatMap(p=>spellList(p.list));const suggestedReference=referencePresets.find(p=>p.id===target.referencePreset&&p.specId===first.specId);const fallback=suggestedReference?spellList(suggestedReference.rows.map(row=>Number(row[1])).filter(n=>integer(n))):existing;
    const list=[...new Set([...priorities.map(p=>p.spellId),...fallback])].slice(0,30);const timing=weighted(records,v=>v.offset);const aggregate=records.some(r=>r.aggregate);const offsetStats=aggregate?{count:timing.count,mean:timing.mean,median:null,min:null,max:null,stddev:null}:stats(records.map(v=>v.offset));
    const byOccurrence=[];for(const occurrence of [...new Set(records.map(r=>r.occurrence))].sort((a,b)=>a-b)){const values=records.filter(r=>r.occurrence===occurrence);byOccurrence.push({occurrence,offset:weighted(values,v=>v.offset),bossTime:weighted(values,v=>v.bossTime),pressTime:weighted(values,v=>v.defensiveTime)});}
    const bindingPeers=mechanics.filter(m=>m.kind==='boss'&&target.kind==='boss'&&m.encounterId===target.encounterId&&m.timerSpellId===target.timerSpellId);const reasons=[];if(bindingPeers.length>1)reasons.push('Several mechanics map to the same NSR encounter/timer binding. Select one to avoid overwriting it.');if(target.mapId>1000000)reasons.push('The NSR instance map ID must be at most 1,000,000.');if(mixedContext)reasons.push('Several difficulties/builds map to the same NSR ability. Export one context at a time.');if(target.kind==='boss'&&!integer(target.encounterId))reasons.push('Confirm the in-game dungeonEncounterID.');if(target.kind==='trash'&&!integer(target.mapId))reasons.push('Confirm the instance map ID, not the challenge-mode ID.');if(target.kind==='trash'&&(-timing.mean<0||-timing.mean>30))reasons.push('The trash timer supports only 0–30 seconds before its prediction; this mean cannot be exported exactly.');
    const id=sha(key).slice(0,16);results.push({id,...target,specId:first.specId,classToken:first.classToken,difficulty:first.difficulty,build:first.build,priority:list,priorities,offsets:offsetStats,meanBossTime:weighted(records,v=>v.bossTime).mean,meanPressTime:weighted(records,v=>v.defensiveTime).mean,leadTime:round(-timing.mean),pulls:new Set(records.map(r=>r.sample)).size,observations:records.length,aggregate,byOccurrence,reasons,exportable:!reasons.length,selected:true,samples:records});
  }
  const uncovered=mechanics.filter(m=>!results.some(r=>keyFor(r)===keyFor(m))).map(m=>({...m,reason:'No matched recorded defensive presses; no mean or timed binding was generated.'}));
  if(duplicates)warnings.push(`${duplicates} duplicate observations excluded.`);if(results.some(r=>r.aggregate))warnings.push('Aggregate rows are weighted by sampleCount. Disjoint samples are user-confirmed; within-group spread is unknown.');
  warnings.push('Generated lists rank observed usage, then retain reference/existing fallbacks. They are priority lists, not a proven optimal or fixed cooldown rotation.','NSR stores one lead time for an ability/preset; occurrence-specific means are shown separately and are pooled for that binding. Verify timer-key mapping, phases, talents and game behavior.');
  return {id:uid(),profileId:profile.id,profileKey:config.profileKey||'',createdAt:new Date().toISOString(),config:structuredClone(config),results,uncovered,warnings};
}
export function buildDefensePack(profile,plan,{selectedIds,confirmedIds=false,name}={}){
  if(!confirmedIds)throw Error('Confirm encounter/map IDs and the timer provider spell-ID mapping before exporting');const ids=new Set(selectedIds||[]),rows=plan.results.filter(r=>ids.has(r.id));if(!rows.length)throw Error('Select at least one analyzed mechanic to export');
  if(rows.some(r=>!r.exportable))throw Error('Resolve the selected rows’ ID/context/timing problems before exporting');
  const pack=structuredClone(profile.pack),numericKeys=structuredClone(profile.numericKeys||[]);const basePath=pack.profiles?['profiles',plan.profileKey]:['data'];const data=pack.profiles?pack.profiles[plan.profileKey]:pack.data;
  if(data.bindingsBySpec===false&&Object.keys(data.abilityBindings||{}).length)throw Error('This profile has legacy ability bindings. Import and re-export it in the current NSR addon to migrate them before generating new bindings.');
  data.presets||={};data.activePreset||={};data.abilityBindings||={};data.integrationRules||={};data.bindingsBySpec=true;const changes=[];
  for(const row of rows){const spec=String(row.specId);data.presets[spec]||={};let preset='pg_'+sha(JSON.stringify([row.dungeon,row.encounter,row.bossSpellId,row.specId,row.difficulty,row.build])).slice(0,9);const marker=`${row.dungeon}|${row.encounter}|${row.bossSpellId}|${spec}`;if(data.presets[spec][preset]&&data.presets[spec][preset].pztkSource!==marker)throw Error('A generated preset key collides with an independent preset. Rename that preset before exporting.');
    data.presets[spec][preset]={name:utf8(`${row.dungeon} · ${row.encounter} · ${row.bossAbility}`,120),list:row.priority,pztkSource:marker};if(!data.activePreset[spec])data.activePreset[spec]=preset;
    const timing={meanOffset:row.offsets.mean,meanPressTime:row.meanPressTime,samples:row.offsets.count,pulls:row.pulls,difficulty:row.difficulty,build:row.build};
    if(row.kind==='boss'){
      data.abilityBindings[spec]||={};const enc=String(row.encounterId),spell=String(row.timerSpellId);data.abilityBindings[spec][enc]||={};const before=structuredClone(data.abilityBindings[spec][enc][spell]||null);data.abilityBindings[spec][enc][spell]={...(before||{}),enabled:before?.enabled??true,mode:'defensive',preset,leadTime:row.leadTime,...(healers.has(row.specId)?{healerReminder:true}:{}),pztkTiming:timing};numericKeys.push([...basePath,'abilityBindings',spec,enc,spell]);changes.push({kind:'boss',specId:row.specId,encounter:row.encounter,spellId:row.timerSpellId,preset,before,after:data.abilityBindings[spec][enc][spell]});
    }else{
      data.integrationRules[spec]||={};const ruleId='pg_'+sha(marker+':'+row.mapId).slice(0,9);const before=structuredClone(data.integrationRules[spec][ruleId]||null);data.integrationRules[spec][ruleId]={...(before||{}),name:utf8(row.bossAbility,120),enabled:before?.enabled??true,preset,...(healers.has(row.specId)?{healerReminder:true}:{}),trigger:{type:'exboss',mapID:row.mapId,spellID:row.timerSpellId,timeleft:row.leadTime},display:{type:'text',text:utf8(row.priorities[0]?.name||'Defensive',200),dur:5},pztkTiming:timing};changes.push({kind:'trash',specId:row.specId,encounter:row.encounter,spellId:row.timerSpellId,preset,before,after:data.integrationRules[spec][ruleId]});
    }
  }
  for(const rules of Object.values(data.integrationRules))if(Object.keys(rules).length>500)throw Error('NSR accepts at most 500 imported integration rules per specialization. Reduce the selected trash rules.');
  pack.name=utf8(name||pack.name,200);pack.pztkPlanner={version:1,generatedAt:new Date().toISOString(),sourceProfile:profile.hash,mechanics:rows.length};return {pack,numericKeys,changes};
}
export class DefensivePlanner{
  constructor(dir,codec){this.dir=path.join(dir,'defensive-planner');this.codec=codec;this.plans=new Map();}
  async file(kind,id){if(!/^[a-f\d-]{16,36}$/.test(id||''))throw Error('Invalid planner item ID');return path.join(this.dir,kind,id+'.json');}
  async read(kind,id){return JSON.parse(await fs.readFile(await this.file(kind,id),'utf8'));}
  async list(kind){const dir=path.join(this.dir,kind);await fs.mkdir(dir,{recursive:true});const items=[];for(const name of await fs.readdir(dir))if(name.endsWith('.json'))items.push(JSON.parse(await fs.readFile(path.join(dir,name),'utf8')));return items;}
  async importProfile(text){const {pack,numericKeys}=this.codec.decode(text,{withKeys:true});profileDescription(pack);const item={id:uid(),hash:sha(text),name:pack.name||'Imported NSR profile',createdAt:new Date().toISOString(),pack,numericKeys};await writeAtomic(await this.file('profiles',item.id),JSON.stringify(item));await writeAtomic(path.join(this.dir,'originals',item.id+'.txt'),text);return {id:item.id,name:item.name,derivedFrom:pack.derivedFrom||null,profiles:profileDescription(pack)};}
  async state(){return {profiles:(await this.list('profiles')).map(p=>({id:p.id,name:p.name,derivedFrom:p.pack.derivedFrom||null,profiles:profileDescription(p.pack)})),tables:(await this.list('tables')).map(t=>({id:t.id,filename:t.filename,kind:t.kind,mechanics:t.mechanics,observations:t.observations.length,warning:t.warning})),analyses:(await this.list('analyses')).map(p=>({id:p.id,profileId:p.profileId,createdAt:p.createdAt,results:p.results.length}))};}
  async importTable(args){const table=parseDefenseTable(args.text,args.filename,args.options);await writeAtomic(await this.file('tables',table.id),JSON.stringify(table));return table;}
  async analyze(args,timelines){const profile=await this.read('profiles',args.profileId);const tables=await Promise.all((args.tableIds||[]).map(id=>this.read('tables',id)));const plan=analyzeDefenses(profile,tables,args,timelines);if(this.plans.size>=20)this.plans.delete(this.plans.keys().next().value);this.plans.set(plan.id,plan);await writeAtomic(await this.file('analyses',plan.id),JSON.stringify(plan));return plan;}
  async preview(args){const plan=this.plans.get(args.planId)||await this.read('analyses',args.planId);const profile=await this.read('profiles',plan.profileId);const built=buildDefensePack(profile,plan,args);const text=this.codec.encode(built.pack,{numericKeys:built.numericKeys});const id=uid();const preview={id,planId:plan.id,createdAt:new Date().toISOString(),sourceProfile:profile.id,text,changes:built.changes};await writeAtomic(await this.file('exports',id),JSON.stringify(preview));return preview;}
}
