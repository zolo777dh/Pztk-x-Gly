// Builds the addon's base boss timelines (addon/NaowhDefensivePlanner/LogTimelines.lua) from
// public kills on Warcraft Logs, through its v2 API. For each raid boss with built-in timers
// and each difficulty, the top kills are read; every boss cast is timed from the start of its
// phase, casts are grouped by time across the kills, and each group gets its median time,
// placed after the median start of its phase. Casts in a phase that starts at a different
// time in each kill (boss health) are tied to a cast of that phase instead of the pull. Casts
// seen in fewer than half of the kills are left out. Spell IDs from the logs are matched by name to the spells the built-in
// timers announce, and only those spells are kept, so every cast on the Timeline is one a
// reminder can bind to and that fires on a real pull.
//
// Usage: WCL_CLIENT_ID=... WCL_CLIENT_SECRET=... node tools/build-wcl-timelines.mjs [kills=20] [--raw file.json]
//        node tools/build-wcl-timelines.mjs --from-raw file.json   (rebuild without the API)
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

// One kill: {length, phases:[{id,name,at}], casts:[{at,spell}]} in seconds from the pull.
// Phases can come back (stage 1, intermission, stage 1 again), so each stretch of the fight
// is a segment by its order: the k-th phase change, kept when most kills have the same phase
// there. Casts are timed from the start of their segment and grouped by time across the kills
// (at most one cast of each kill per group, within 3 s), so a kill with one cast more or less
// does not shift the later ones. A group seen in at least half of the kills is one cast on the
// timeline, at its median time.
// A phase that starts at a different time in each kill (spread over 0.75 s: boss health,
// healing) is not timed from the pull in the game: each cast in it names an anchor, the first
// steady cast of that phase (or the cast that starts it), and a reminder on it waits for that
// cast instead of a time from the pull.
const WINDOW=3,STEADY=0.75,MOVING=1.5;
const spread=list=>{const m=median(list);return median(list.map(x=>Math.abs(x-m)));};
function groups(items,field,need){
 const all=[];
 for(const it of [...items].sort((a,b)=>a[field]-b[field])){
  const g=all.find(g=>it[field]-g.first<=WINDOW&&!g.kills.has(it.kill));
  if(g){g.items.push(it);g.kills.add(it.kill);}else all.push({first:it[field],items:[it],kills:new Set([it.kill])});
 }
 const kept=[],left=[];for(const g of all)if(g.kills.size>=need)kept.push(g);else left.push(...g.items);
 return {kept,left};
}
// What no group took, by its order in each kill: a cast that moves more than the window.
function byOrder(items,field,need){
 const seen=new Map(),all=new Map();
 for(const it of [...items].sort((a,b)=>a[field]-b[field])){const n=(seen.get(it.kill)||0)+1;seen.set(it.kill,n);if(!all.has(n))all.set(n,[]);all.get(n).push(it);}
 return [...all.values()].filter(g=>g.length>=need).map(items=>({items}));
}
export function aggregate(kills,{share=0.5}={}){
 if(!kills.length)return null;
 const need=Math.max(1,Math.ceil(kills.length*share));
 const segs=kills.map(k=>{const p=[...k.phases].sort((a,b)=>a.at-b.at);return p.length?p:[{id:1,at:0}];});
 const segments=[];
 for(let n=0;n<Math.max(...segs.map(p=>p.length));n++){
  const ids=new Map();for(const p of segs)if(p[n])ids.set(p[n].id,(ids.get(p[n].id)||0)+1);
  const [id,count]=[...ids].sort((a,b)=>b[1]-a[1])[0];if(count<need)break;
  const at=segs.filter(p=>p[n]?.id===id).map(p=>p[n].at);
  segments.push({id,at:n===0?0:median(at),vary:n>0&&spread(at)>STEADY,name:segs.find(p=>p[n]?.id===id&&p[n].name)?.[n].name||'Phase '+id});
 }
 const pools=new Map();
 kills.forEach((k,ki)=>{
  const phases=segs[ki];
  for(const c of k.casts){
   let n=0;for(let x=0;x<phases.length;x++)if(phases[x].at<=c.at)n=x;
   if(!segments[n]||segments[n].id!==phases[n].id)continue;
   const next=segments[n+1]&&phases[n+1]?.id===segments[n+1].id?c.at-phases[n+1].at:null;
   const key=n+':'+c.spell;if(!pools.has(key))pools.set(key,{seg:n,spell:c.spell,items:[]});
   pools.get(key).items.push({kill:ki,rel:c.at-phases[n].at,next});
  }
 });
 const events=[];
 for(const p of pools.values()){
  const {kept,left}=groups(p.items,'rel',need);
  for(const g of kept){const rel=g.items.map(i=>i.rel);events.push({at:round(segments[p.seg].at+median(rel)),spell:p.spell,seg:p.seg,spread:spread(rel)});}
  // A cast whose time follows the next phase (the cast that starts it) is timed from that phase.
  const after=groups(left.filter(i=>i.next!==null),'next',need);
  for(const g of after.kept){const rel=g.items.map(i=>i.next);events.push({at:round(segments[p.seg+1].at+median(rel)),spell:p.spell,seg:p.seg+1,spread:spread(rel)});}
  const rest=left.filter(i=>!after.kept.some(g=>g.items.includes(i)));
  for(const g of byOrder(rest,'rel',need)){const rel=g.items.map(i=>i.rel);events.push({at:round(segments[p.seg].at+median(rel)),spell:p.spell,seg:p.seg,spread:spread(rel)});}
 }
 events.sort((a,b)=>a.at-b.at||a.spell-b.spell);
 // A repeat of one spell within 2 s of the last is the same cast seen twice.
 const out=[];for(const e of events){const last=out.findLast(x=>x.spell===e.spell);if(!last||e.at-last.at>=2)out.push(e);}
 // Anchors: the first steady cast of each phase whose start varies.
 const anchor=new Map();
 out.forEach((e,i)=>{if(segments[e.seg].vary&&e.spread<=1&&!anchor.has(e.seg))anchor.set(e.seg,i);});
 const timeline=out.map(e=>{const x=[e.at,e.spell];const a=segments[e.seg].vary?anchor.get(e.seg):undefined;if(a!==undefined)x.anchor=a+1;if(e.spread>MOVING)x.spread=round(e.spread);return x;});
 const phases=segments.slice(1).map(p=>{const x={id:p.id,name:p.name,at:round(p.at)};if(p.vary)x.vary=true;return x;});
 return {length:Math.round(median(kills.map(k=>k.length))),kills:kills.length,phases,events:timeline};
}

// The casts of one kill as announced spells: a log spell ID named like an announced spell
// takes its ID, other spells are dropped, and a repeat within 3 s (two log spells of one
// ability, or a cast and its channel) counts once.
export function announcedCasts(casts,announced,names){
 const set=new Set(announced),byName=new Map();
 for(const id of announced){const n=names[id]?.toLowerCase();if(n&&!byName.has(n))byName.set(n,id);}
 const last=new Map(),out=[];
 for(const c of [...casts].sort((a,b)=>a.at-b.at)){
  const spell=set.has(c.spell)?c.spell:byName.get(names[c.spell]?.toLowerCase());if(!spell)continue;
  if(last.has(spell)&&c.at-last.get(spell)<3)continue;last.set(spell,c.at);out.push({at:c.at,spell});
 }
 return out;
}
// Raw kills ({bosses:[{id,name,spells,difficulties:{15:[kill...]}}], names}) to timelines.
export function timelinesFrom(raw,log=()=>{}){
 const timelines={};
 for(const boss of raw.bosses)for(const diff of DIFFICULTIES){
  const kills=(boss.difficulties[diff.game]||[]).map(k=>({...k,casts:announcedCasts(k.casts,boss.spells,raw.names)}));
  const tl=aggregate(kills);log(boss.name+' '+diff.name+': '+kills.length+' kills, '+(tl?tl.events.length:0)+' casts');
  if(tl&&tl.events.length)(timelines[boss.id]??={})[diff.game]=tl;
 }
 return timelines;
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
  fights(fightIDs:$f){id encounterID startTime endTime kill phaseTransitions{id startTime}}
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
 const named={};for(const e of report.phases||[])if(e.encounterID===f.encounterID)for(const p of e.phases||[])named[p.id]=p.name;
 const phases=(f.phaseTransitions||[]).map(p=>({id:p.id,name:named[p.id],at:Math.max(0,(p.startTime-f.startTime)/1000)}));
 return {length:(f.endTime-f.startTime)/1000,phases:phases.length?phases:[{id:1,at:0}],casts};
}

async function abilityNames(api,ids){
 const names={};
 for(const id of ids){const d=await api.query('query($i:Int!){gameData{ability(id:$i){name}}}',{i:id});if(d.gameData.ability?.name)names[id]=d.gameData.ability.name;}
 return names;
}

export function lua(timelines,info){
 const t=x=>'{'+x.map(e=>'{'+e[0]+','+e[1]+(e.anchor?',anchor='+e.anchor:'')+(e.spread?',spread='+e.spread:'')+'}').join(',')+'}';
 const lines=['-- Generated by tools/build-wcl-timelines.mjs: base boss timelines from public kills on',
  '-- Warcraft Logs (median cast times over the top kills of each boss and difficulty). Your own',
  '-- recorded pull, or one shared in a boss export, always replaces them. Spell IDs are the ones',
  '-- the built-in timers announce where the names match.','local _, ns = ...',
  'ns.LogTimelinesInfo = { built = '+JSON.stringify(info.built)+', kills = '+info.kills+' }','ns.LogTimelines = {'];
 for(const [enc,byDiff]of Object.entries(timelines)){
  const parts=Object.entries(byDiff).map(([d,x])=>'['+d+']={length='+x.length+',kills='+x.kills+',phases={'+x.phases.map(p=>'{id='+p.id+',name='+JSON.stringify(p.name)+',at='+p.at+(p.vary?',vary=true':'')+'}').join(',')+'},events='+t(x.events)+'}');
  lines.push('    ['+enc+'] = {'+parts.join(',')+'},');
 }
 lines.push('}','');return lines.join('\n');
}

// Reads the kills through the API; returns the raw set for timelinesFrom.
export async function fetchRaw({api,bosses,kills=20,log=()=>{}}){
 const raw={bosses:[],names:{}},ids=new Set();
 for(const boss of bosses){
  const entry={...boss,difficulties:{}};raw.bosses.push(entry);boss.spells.forEach(s=>ids.add(s));
  for(const diff of DIFFICULTIES){
   const list=[];
   for(const r of await rankings(api,boss.id,diff.wcl,kills)){const k=await kill(api,r).catch(e=>{log('  skipped '+r.code+': '+e.message);return null;});if(k){list.push(k);k.casts.forEach(c=>ids.add(c.spell));}}
   entry.difficulties[diff.game]=list;log(boss.name+' '+diff.name+': '+list.length+' kills read');
  }
 }
 raw.names=await abilityNames(api,[...ids]);
 return raw;
}
export async function build(opts){return timelinesFrom(await fetchRaw(opts),opts.log);}

if(import.meta.url===pathToFileURL(process.argv[1]).href){
 const args=process.argv.slice(2),flag=name=>{const i=args.indexOf(name);return i>=0?args.splice(i,2)[1]:null;};
 const fromRaw=flag('--from-raw'),rawOut=flag('--raw');let raw,kills;
 if(fromRaw){raw=JSON.parse(await fs.readFile(fromRaw,'utf8'));kills=raw.kills||0;}
 else{
  const id=process.env.WCL_CLIENT_ID,secret=process.env.WCL_CLIENT_SECRET;
  if(!id||!secret){console.error('Set WCL_CLIENT_ID and WCL_CLIENT_SECRET (https://www.warcraftlogs.com/api/clients).');process.exit(1);}
  kills=Math.max(3,Math.min(100,Number(args[0])||20));
  const bosses=bossTimerSpells(await fs.readFile('addon/NaowhDefensivePlanner/BossTimerData.lua','utf8'));
  raw=await fetchRaw({api:client({id,secret}),bosses,kills,log:console.log});raw.kills=kills;raw.built=new Date().toISOString().slice(0,10);
  if(rawOut){await fs.writeFile(rawOut,JSON.stringify(raw));console.log('Wrote '+rawOut);}
 }
 const timelines=timelinesFrom(raw,console.log);
 await fs.writeFile('addon/NaowhDefensivePlanner/LogTimelines.lua',lua(timelines,{built:raw.built||new Date().toISOString().slice(0,10),kills}));
 console.log('Wrote addon/NaowhDefensivePlanner/LogTimelines.lua');
}
