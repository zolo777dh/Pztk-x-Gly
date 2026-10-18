import {parseDocument} from 'htmlparser2';
import {normalizePriorityData,priorityTables} from './priority-reference.mjs';
import {sha} from './files.mjs';
function text(node){return node.type==='text'?node.data:(node.children||[]).map(text).join('');}
function find(node,match,result=[]){if(match(node))result.push(node);for(const child of node.children||[])find(child,match,result);return result;}
export function stats(values){if(!values.length)return null;const sorted=[...values].sort((a,b)=>a-b);const mean=values.reduce((a,b)=>a+b,0)/values.length;const median=sorted.length%2?sorted[(sorted.length-1)/2]:(sorted[sorted.length/2-1]+sorted[sorted.length/2])/2;return {count:values.length,mean,median,min:sorted[0],max:sorted.at(-1),stddev:Math.sqrt(values.reduce((sum,v)=>sum+(v-mean)**2,0)/values.length)};}
export function parseReference(html,filename='reference.html'){
  if(typeof html!=='string'||Buffer.byteLength(html)>10e6)throw Error('Reference HTML exceeds 10 MB');
  const doc=parseDocument(html);const title=text(find(doc,n=>n.name==='title')[0]||{}).trim()||filename;
  const scripts=find(doc,n=>n.name==='script'&&n.attribs?.type==='application/json');let data;const candidates=[];
  if(/^[\s]*[\[{]/.test(html)){try{candidates.push(JSON.parse(html));}catch{throw Error('Invalid JSON reference');}}
  for(const node of scripts){try{candidates.push(JSON.parse(text(node)));}catch{}}
  for(const value of candidates)if(value?.presets&&typeof value.presets==='object'){data=normalizePriorityData(value);break;}
  if(!data)data=priorityTables(doc);
  if(!data){const tables=find(doc,n=>n.name==='table').map(n=>find(n,c=>c.name==='tr').map(row=>(row.children||[]).filter(c=>c.name==='td'||c.name==='th').map(cell=>text(cell).trim())));const headings=find(doc,n=>/^h[1-6]$/.test(n.name||'')).map(text);
    for(const value of candidates){const arrays=Array.isArray(value)?[value]:Object.values(value||{}).filter(Array.isArray);for(const array of arrays){if(!array.length||!array.every(row=>row&&typeof row==='object'&&!Array.isArray(row)))continue;const keys=[...new Set(array.flatMap(Object.keys))].slice(0,50);tables.push([keys,...array.slice(0,10000).map(row=>keys.map(k=>row[k]==null?'':typeof row[k]==='object'?JSON.stringify(row[k]):String(row[k])))]);}}
    if(/\.csv$/i.test(filename))tables.push(parseCSV(html));
    if(!tables.length&&!headings.length)throw Error('No supported structured reference data or static tables/headings found. HTML scripts are never executed.');return {id:sha(html).slice(0,16),format:'pztk-reference-v1',kind:'static-html',filename,title,tables,headings,importedAt:new Date().toISOString()};}
  if(data.presets.length>1000||data.assignments.length>10000)throw Error('Reference exceeds preset/assignment limits');
  if(data.presets.some(p=>typeof p.id!=='string'||typeof p.name!=='string'||!Array.isArray(p.rows)||p.rows.some(r=>!Array.isArray(r)||typeof r[0]!=='string'||(r[1]!=null&&typeof r[1]!=='string'))))throw Error('Unsupported priority preset schema');
  const rows=[];
  for(const assignment of data.assignments){if(typeof assignment.encounter!=='string'||typeof assignment.ability!=='string'||!Array.isArray(assignment.samples))throw Error('Unsupported assignment schema');
    const groups=new Map();for(const sample of assignment.samples){if(!Number.isFinite(sample.time)||sample.time<0)continue;const key=String(sample.number??'unknown')+':'+Boolean(sample.phase);if(!groups.has(key))groups.set(key,new Map());const id=`${sample.log}:${sample.pull}`;const existing=groups.get(key).get(id);if(existing!==undefined&&existing!==sample.time)throw Error('Conflicting duplicate sample in reference');groups.get(key).set(id,sample.time);}
    for(const [key,samples]of groups){const [occurrence,phase]=key.split(':');rows.push({dungeon:assignment.dungeon||'',encounter:assignment.encounter,ability:assignment.ability,spellId:assignment.cast||null,type:assignment.type||'Unknown',occurrence,phaseMarker:phase==='true',preset:assignment.preset,bossTimes:stats([...samples.values()]),samples:[...samples].map(([id,time])=>({id,time}))});}
  }
  return {id:sha(html).slice(0,16),format:'pztk-reference-v1',kind:'cooldown-priority-reference',filename,title,importedAt:new Date().toISOString(),presets:data.presets,assignments:data.assignments,missing:data.missing||[],packs:data.packs||[],rows,warning:'This file contains suggested priorities and boss-event times, not recorded player defensive presses. Defensive timing offsets cannot be calculated from it alone.'};
}
function parseCSV(content){const delimiter=content.split('\n')[0].includes(';')?';':',';const rows=[];let row=[],cell='',quoted=false;for(let i=0;i<content.length;i++){const char=content[i];if(char==='"'){if(quoted&&content[i+1]==='"'){cell+='"';i++;}else quoted=!quoted;}else if(char===delimiter&&!quoted){row.push(cell);cell='';}else if(char==='\n'&&!quoted){row.push(cell.replace(/\r$/,''));if(row.some(Boolean))rows.push(row);row=[];cell='';}else cell+=char;}if(quoted)throw Error('Unclosed CSV quote');row.push(cell.replace(/\r$/,''));if(row.some(Boolean))rows.push(row);if(rows.length>10000)throw Error('CSV exceeds 10000 rows');return rows;}
export function mapReferenceTable(reference,options){
 const table=reference.tables?.[Number(options.table)];if(!table)throw Error('Select a source table');
 const {encounter,ability,bossTime,defensiveTime=-1,occurrence=-1,sample=-1,difficulty=-1}=options.columns||{};
 const valid=i=>Number.isInteger(Number(i))&&Number(i)>=0&&Number(i)<50;
 if(![encounter,ability,bossTime].every(valid))throw Error('Map encounter, ability and boss-time columns');
 if(valid(defensiveTime)&&!options.recordedPresses)throw Error('Confirm that the defensive column contains recorded presses, not recommendations');
 function time(value){const s=String(value??'').trim();if(/^\d+:[0-5]?\d(?:\.\d+)?$/.test(s)){const [min,sec]=s.split(':').map(Number);return min*60+sec;}if(/^\d+(?:[.,]\d+)?\s*s?$/.test(s))return Number(s.replace(/s$/,'').trim().replace(',','.'));return null;}
 const groups=new Map();let skipped=0;
 for(const [index,row]of table.entries()){if(index===0&&options.header!==false)continue;const encounterName=String(row[Number(encounter)]??'').trim(),abilityName=String(row[Number(ability)]??'').trim(),boss=time(row[Number(bossTime)]);const press=valid(defensiveTime)?time(row[Number(defensiveTime)]):null;
  if(!encounterName||!abilityName||boss==null||(valid(defensiveTime)&&press==null)){skipped++;continue;}
  const occ=valid(occurrence)?String(row[Number(occurrence)]):'unspecified';const diff=valid(difficulty)?String(row[Number(difficulty)]):'unknown';const key=JSON.stringify([encounterName,abilityName,occ,diff]);if(!groups.has(key))groups.set(key,{encounter:encounterName,ability:abilityName,occurrence:occ,difficulty:diff,samples:new Map()});
  const id=valid(sample)?String(row[Number(sample)]):'row '+(index+1);const group=groups.get(key);if(group.samples.has(id)){const old=group.samples.get(id);if(old.boss!==boss||old.press!==press)throw Error('Conflicting duplicate sample '+id);continue;}group.samples.set(id,{id,boss,press});
 }
 const rows=[...groups.values()].map(g=>({...g,samples:[...g.samples.values()],bossTimes:stats([...g.samples.values()].map(v=>v.boss)),defensiveOffsets:valid(defensiveTime)?stats([...g.samples.values()].map(v=>v.press-v.boss)):null}));
 if(!rows.length)throw Error('No usable timing rows. Check the mapping and time format (seconds or m:ss).');
 return {format:'pztk-mapped-reference-v1',title:reference.title,reference:reference.id,rows,skipped,warning:valid(sample)?'Rows are grouped by your sample key. Confirm independent pulls, difficulty and occurrence alignment.':'No independent pull key was supplied. Counts represent table rows, not verified independent logs.'};
}
export function comparePulls(timelines,{bossSpellId,defensiveSpellIds,actor='',windowBefore=10,windowAfter=5,bossEventType='cast',bossSourceId=null}={}){
  if(timelines.length<2)throw Error('Select at least two distinct pulls of one encounter');
  const ids=new Set(timelines.map(t=>t.source?.report+':'+t.source?.fightId));if(ids.size!==timelines.length)throw Error('Duplicate pulls are not independent samples');
  const encounters=new Set(timelines.map(t=>Number(t.encounterId)));if(encounters.size!==1||encounters.has(0)||[...encounters].some(n=>!Number.isInteger(n)))throw Error('All pulls must have the same confirmed encounter ID');
  if(new Set(timelines.map(t=>String(t.difficulty??'unknown'))).size!==1)throw Error('Select pulls of the same difficulty');
  if(new Set(timelines.map(t=>t.build).filter(Boolean)).size>1)throw Error('Do not average pulls from different known client builds');
  if(!Number.isInteger(Number(bossSpellId))||Number(bossSpellId)<=0)throw Error('Enter the boss ability spell ID');
  const defensiveIds=new Set((defensiveSpellIds||[]).map(Number));if(!defensiveIds.size||[...defensiveIds].some(n=>!Number.isInteger(n)||n<=0))throw Error('Enter defensive spell IDs');
  windowBefore=Number(windowBefore);windowAfter=Number(windowAfter);if(windowBefore<0||windowAfter<0||windowBefore>60||windowAfter>60||!Number.isFinite(windowBefore+windowAfter))throw Error('Matching window must be 0–60 seconds');
  const groups=new Map();let unmatched=0;const seenBoss=new Map();
  for(const timeline of timelines){
    const bosses=timeline.events.filter(e=>Number(e.spellId)===Number(bossSpellId)&&e.type===bossEventType&&(bossSourceId==null||String(e.sourceId)===String(bossSourceId))).sort((a,b)=>a.time-b.time);
    bosses.forEach((e,i)=>{if(!seenBoss.has(i+1))seenBoss.set(i+1,[]);seenBoss.get(i+1).push({time:e.time,pull:timeline.id});});
    const matches=new Map();
    for(const event of timeline.events){if(event.type!=='cast'||!defensiveIds.has(Number(event.spellId))||(actor&&!String(event.sourceName||'').toLowerCase().includes(actor.toLowerCase())))continue;
      let best=null;for(const [index,boss]of bosses.entries()){const offset=event.time-boss.time;if(offset< -windowBefore||offset>windowAfter)continue;if(!best||Math.abs(offset)<Math.abs(best.offset))best={offset,index,boss};}
      if(!best){unmatched++;continue;}
      const player=event.sourceName||`actor ${event.sourceId??'unknown'}`;const identity=`${best.index}:${event.spellId}:${event.sourceId??player}`;const prior=matches.get(identity);
      if(!prior||Math.abs(best.offset)<Math.abs(prior.offset))matches.set(identity,{...best,event,player});
    }
    for(const match of matches.values()){const key=`${match.index+1}:${match.event.spellId}`;if(!groups.has(key))groups.set(key,[]);groups.get(key).push({pull:timeline.id,report:timeline.source.report,fightId:timeline.source.fightId,occurrence:match.index+1,player:match.player,offset:match.offset,bossTime:match.boss.time,defensiveTime:match.event.time,spellId:match.event.spellId,name:match.event.name});}
  }
  const rows=[...groups.entries()].map(([key,samples])=>({key,occurrence:samples[0].occurrence,spellId:samples[0].spellId,name:samples[0].name,offsets:stats(samples.map(s=>s.offset)),bossTimes:stats(seenBoss.get(samples[0].occurrence).map(s=>s.time)),coveredPulls:new Set(samples.map(s=>s.pull)).size,eligiblePulls:seenBoss.get(samples[0].occurrence).length,samples})).sort((a,b)=>a.occurrence-b.occurrence||a.spellId-b.spellId);
  return {format:'pztk-comparison-v1',encounterId:[...encounters][0],totalPulls:timelines.length,bossSpellId:Number(bossSpellId),rows,unmatched,warning:'Correlation, not proof of a required cooldown. Cast occurrences are aligned by ordinal within each pull; verify phase alignment and actor selection. Unknown builds remain unverified. Each defensive cast is assigned to the nearest boss event in the chosen window; at most one sample per player/spell/boss occurrence per pull.'};
}
