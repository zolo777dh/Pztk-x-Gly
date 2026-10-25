// Builds the addon's base boss timelines (addon/NaowhDefensivePlanner/LogTimelines.lua) from
// public kills on Warcraft Logs, through its v2 API. For each raid boss with built-in timers
// and each difficulty, the top kills are read; every boss cast is timed from the start of its
// phase, and each cast (the 1st, 2nd... of an ability in a phase) gets its median time over
// the kills, placed after the median start of its phase. Casts seen in fewer than half of the
// kills are left out. Spell IDs from the logs are matched by name to the spells the built-in
// timers announce, so reminders bound on the Timeline fire on a real pull.
//
// Usage: WCL_CLIENT_ID=... WCL_CLIENT_SECRET=... node tools/build-wcl-timelines.mjs [kills=20]
// Create the API client at https://www.warcraftlogs.com/api/clients (free).
import fs from 'node:fs/promises';
import {pathToFileURL} from 'node:url';

const API='https://www.warcraftlogs.com/api/v2/client',TOKEN='https://www.warcraftlogs.com/oauth/token';
// Game difficulty IDs and the Warcraft Logs ones.
export const DIFFICULTIES=[{game:15,wcl:4,name:'Heroic'},{game:16,wcl:5,name:'Mythic'}];

export function bossTimerSpells(source){
 const order=source.match(/ns\.BossTimerOrder = \{([^}]*)\}/)?.[1].split(',').map(Number).filter(Boolean)||[];
 const spells={};for(const m of source.matchAll(/\[(\d+)\] = \{ ([\d, ]+) \},/g))spells[m[1]]=m[2].split(',').map(Number);
 const names={};for(const m of source.matchAll(/B\[(\d+)\] = \{ name = "([^"]+)"/g))names[m[1]]=m[2];
 return order.map(id=>({id,name:names[id]||String(id),spells:spells[id]||[]}));
}

export function median(list){
 const s=[...list].sort((a,b)=>a-b),n=s.length;if(!n)return null;
 return n%2?s[(n-1)/2]:(s[n/2-1]+s[n/2])/2;
}
const round=x=>Math.round(x*10)/10;

// One kill: {length, phases:[{id,at}], casts:[{at,spell}]} in seconds from the pull.
export function aggregate(kills,{share=0.5}={}){
 if(!kills.length)return null;
 const need=Math.max(1,Math.ceil(kills.length*share));
 // Phase starts: the median over the kills that reached each phase.
 const phaseIds=[...new Set(kills.flatMap(k=>k.phases.map(p=>p.id)))].sort((a,b)=>a-b);
 const phaseStart={};
 for(const id of phaseIds){const at=kills.map(k=>k.phases.find(p=>p.id===id)?.at).filter(v=>v!=null);if(at.length>=need)phaseStart[id]=id===phaseIds[0]?0:median(at);}
 const slots=new Map();
 for(const k of kills){
  const phases=[...k.phases].sort((a,b)=>a.at-b.at),count=new Map();
  for(const c of [...k.casts].sort((a,b)=>a.at-b.at)){
   let ph=phases[0]||{id:1,at:0};for(const p of phases)if(p.at<=c.at)ph=p;
   const n=(count.get(ph.id+':'+c.spell)||0)+1;count.set(ph.id+':'+c.spell,n);
   const key=ph.id+':'+c.spell+':'+n;if(!slots.has(key))slots.set(key,{phase:ph.id,spell:c.spell,rel:[]});
   slots.get(key).rel.push(c.at-ph.at);
  }
 }
 const events=[];
 for(const s of slots.values()){if(s.rel.length<need||phaseStart[s.phase]==null)continue;events.push([round(phaseStart[s.phase]+median(s.rel)),s.spell]);}
 events.sort((a,b)=>a[0]-b[0]||a[1]-b[1]);
 // A repeat of one spell within 2 s of the last is the same cast seen twice.
 const out=[];for(const e of events){const last=out.findLast(x=>x[1]===e[1]);if(!last||e[0]-last[0]>=2)out.push(e);}
 const phaseName=id=>kills.flatMap(k=>k.phases).find(p=>p.id===id&&p.name)?.name||'Phase '+id;
 const phases=phaseIds.filter((id,i)=>i>0&&phaseStart[id]!=null).map(id=>({id,name:phaseName(id),at:round(phaseStart[id])}));
 return {length:Math.round(median(kills.map(k=>k.length))),kills:kills.length,phases,events:out};
}

// Log spell IDs named like an announced spell take the announced ID.
export function mapSpells(timeline,announced,names){
 const byName=new Map();for(const id of announced){const n=names[id];if(n&&!byName.has(n.toLowerCase()))byName.set(n.toLowerCase(),id);}
 const set=new Set(announced);
 return {...timeline,events:timeline.events.map(([at,spell])=>{if(set.has(spell))return [at,spell];const n=names[spell];return [at,(n&&byName.get(n.toLowerCase()))||spell];})};
}

export function client({id,secret,fetch=globalThis.fetch}){
 let token;
 async function query(q,variables={}){
  if(!token){
   const r=await fetch(TOKEN,{method:'POST',headers:{authorization:'Basic '+Buffer.from(id+':'+secret).toString('base64'),'content-type':'application/x-www-form-urlencoded'},body:'grant_type=client_credentials'});
   if(!r.ok)throw Error('Warcraft Logs token request failed: HTTP '+r.status);token=(await r.json()).access_token;
  }
  const r=await fetch(API,{method:'POST',headers:{authorization:'Bearer '+token,'content-type':'application/json'},body:JSON.stringify({query:q,variables})});
  if(!r.ok)throw Error('Warcraft Logs query failed: HTTP '+r.status);
  const body=await r.json();if(body.errors?.length)throw Error('Warcraft Logs: '+body.errors.map(e=>e.message).join('; '));
  return body.data;
 }
 return {query};
}

async function rankings(api,encounter,difficulty,limit){
 const d=await api.query('query($e:Int!,$d:Int!){worldData{encounter(id:$e){name fightRankings(difficulty:$d,metric:execution)}}}',{e:encounter,d:difficulty});
 const list=d.worldData.encounter?.fightRankings?.rankings||[];
 const seen=new Set(),out=[];
 for(const r of list){const key=r.report?.code+':'+r.report?.fightID;if(!r.report?.code||seen.has(key))continue;seen.add(key);out.push({code:r.report.code,fight:r.report.fightID});if(out.length>=limit)break;}
 return out;
}

async function kill(api,{code,fight}){
 const head=await api.query(`query($c:String!,$f:[Int]!){reportData{report(code:$c){
  fights(fightIDs:$f){id startTime endTime kill phaseTransitions{id startTime}}
  phases{encounterID phases{id name}}
  masterData{actors(type:"NPC"){id subType}}}}}`,{c:code,f:[fight]});
 const report=head.reportData.report,f=report?.fights?.[0];if(!f||!f.kill)return null;
 const bosses=new Set((report.masterData?.actors||[]).filter(a=>a.subType==='Boss').map(a=>a.id));
 const raw=[];let start=f.startTime;
 for(let page=0;page<20&&start!=null;page++){
  const d=await api.query(`query($c:String!,$f:[Int]!,$s:Float!,$e:Float!){reportData{report(code:$c){
   events(fightIDs:$f,dataType:Casts,hostilityType:Enemies,startTime:$s,endTime:$e,limit:10000){data nextPageTimestamp}}}}`,{c:code,f:[fight],s:start,e:f.endTime});
  const ev=d.reportData.report.events;raw.push(...(ev.data||[]));start=ev.nextPageTimestamp;
 }
 // Boss mods time most abilities to the cast start: an ability with cast starts uses them.
 const fromBoss=raw.filter(e=>(e.type==='begincast'||e.type==='cast')&&(!bosses.size||bosses.has(e.sourceID)));
 const begins=new Set(fromBoss.filter(e=>e.type==='begincast').map(e=>e.abilityGameID));
 const casts=fromBoss.filter(e=>begins.has(e.abilityGameID)?e.type==='begincast':e.type==='cast').map(e=>({at:(e.timestamp-f.startTime)/1000,spell:e.abilityGameID}));
 const named={};for(const e of report.phases||[])for(const p of e.phases||[])named[p.id]=p.name;
 const phases=(f.phaseTransitions||[]).map(p=>({id:p.id,name:named[p.id],at:Math.max(0,(p.startTime-f.startTime)/1000)}));
 return {length:(f.endTime-f.startTime)/1000,phases:phases.length?phases:[{id:1,at:0}],casts};
}

async function abilityNames(api,ids){
 const names={};
 for(const id of ids){const d=await api.query('query($i:Int!){gameData{ability(id:$i){name}}}',{i:id});if(d.gameData.ability?.name)names[id]=d.gameData.ability.name;}
 return names;
}

export function lua(timelines,info){
 const t=x=>'{'+x.map(([a,s])=>'{'+a+','+s+'}').join(',')+'}';
 const lines=['-- Generated by tools/build-wcl-timelines.mjs: base boss timelines from public kills on',
  '-- Warcraft Logs (median cast times over the top kills of each boss and difficulty). Your own',
  '-- recorded pull, or one shared in a boss export, always replaces them. Spell IDs are the ones',
  '-- the built-in timers announce where the names match.','local _, ns = ...',
  'ns.LogTimelinesInfo = { built = '+JSON.stringify(info.built)+', kills = '+info.kills+' }','ns.LogTimelines = {'];
 for(const [enc,byDiff]of Object.entries(timelines)){
  const parts=Object.entries(byDiff).map(([d,x])=>'['+d+']={length='+x.length+',kills='+x.kills+',phases={'+x.phases.map(p=>'{id='+p.id+',name='+JSON.stringify(p.name)+',at='+p.at+'}').join(',')+'},events='+t(x.events)+'}');
  lines.push('    ['+enc+'] = {'+parts.join(',')+'},');
 }
 lines.push('}','');return lines.join('\n');
}

export async function build({api,bosses,kills=20,log=()=>{}}){
 const timelines={},ids=new Set();const raw=[];
 for(const boss of bosses)for(const diff of DIFFICULTIES){
  const list=[];
  for(const r of await rankings(api,boss.id,diff.wcl,kills)){const k=await kill(api,r).catch(e=>{log('  skipped '+r.code+': '+e.message);return null;});if(k)list.push(k);}
  const tl=aggregate(list);log(boss.name+' '+diff.name+': '+list.length+' kills, '+(tl?tl.events.length:0)+' casts');
  if(tl&&tl.events.length){raw.push({boss,diff,tl});for(const e of tl.events)ids.add(e[1]);boss.spells.forEach(s=>ids.add(s));}
 }
 const names=await abilityNames(api,[...ids]);
 for(const {boss,diff,tl}of raw)(timelines[boss.id]??={})[diff.game]=mapSpells(tl,boss.spells,names);
 return timelines;
}

if(import.meta.url===pathToFileURL(process.argv[1]).href){
 const id=process.env.WCL_CLIENT_ID,secret=process.env.WCL_CLIENT_SECRET;
 if(!id||!secret){console.error('Set WCL_CLIENT_ID and WCL_CLIENT_SECRET (https://www.warcraftlogs.com/api/clients).');process.exit(1);}
 const kills=Math.max(3,Math.min(100,Number(process.argv[2])||20));
 const bosses=bossTimerSpells(await fs.readFile('addon/NaowhDefensivePlanner/BossTimerData.lua','utf8'));
 const timelines=await build({api:client({id,secret}),bosses,kills,log:console.log});
 await fs.writeFile('addon/NaowhDefensivePlanner/LogTimelines.lua',lua(timelines,{built:new Date().toISOString().slice(0,10),kills}));
 console.log('Wrote addon/NaowhDefensivePlanner/LogTimelines.lua');
}
