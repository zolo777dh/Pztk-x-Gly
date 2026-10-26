import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';import {execFileSync} from 'node:child_process';
import {aggregate,announcedCasts,bossTimerSpells,build,client,fetchRaw,lua,median} from '../tools/build-wcl-timelines.mjs';

const ev=(at,spell,extra={})=>Object.assign([at,spell],extra);
test('base timelines take the median time of each cast per phase and drop casts most kills never saw',()=>{
 assert.equal(median([3,1,2]),2);assert.equal(median([1,2,3,4]),2.5);
 const kills=[
  {length:300,phases:[{id:1,at:0},{id:2,at:100,name:'Intermission'}],casts:[{at:10,spell:1},{at:40,spell:1},{at:105,spell:2},{at:250,spell:9}]},
  {length:320,phases:[{id:1,at:0},{id:2,at:120,name:'Intermission'}],casts:[{at:12,spell:1},{at:42,spell:1},{at:127,spell:2}]},
  {length:280,phases:[{id:1,at:0},{id:2,at:110,name:'Intermission'}],casts:[{at:11,spell:1},{at:41,spell:1},{at:41.5,spell:1},{at:116,spell:2}]},
 ];
 const tl=aggregate(kills);
 assert.equal(tl.length,300);assert.equal(tl.kills,3);
 assert.deepEqual(tl.phases,[{id:2,name:'Intermission',at:110,vary:true}],'a phase starting at 100-120 s depends on the raid');
 // Phase 2 casts sit after the median phase start (110), at their median offset in the phase (6),
 // and the first steady cast of that phase is the anchor of its casts.
 assert.deepEqual(tl.events,[ev(11,1),ev(41,1),ev(116,2,{anchor:3})],'the stray 3rd cast and the once-seen spell 9 are dropped');
 assert.equal(aggregate([]),null);
});
test('a phase that comes back is its own stretch of the fight, timed from its own start',()=>{
 const k=(p2,p3,extra=[])=>({length:200,phases:[{id:1,at:0},{id:2,at:p2,name:'Maelstrom'},{id:1,at:p3}],casts:[{at:30,spell:7},{at:p3+30,spell:7},...extra]});
 const tl=aggregate([k(100,130),k(110,140),k(120,150,[{at:10,spell:8}])]);
 assert.deepEqual(tl.phases,[{id:2,name:'Maelstrom',at:110,vary:true},{id:1,name:'Phase 1',at:140,vary:true}]);
 assert.deepEqual(tl.events,[ev(30,7),ev(170,7,{anchor:2})],'the second stage-1 cast sits 30 s after the second stage 1, not at 30 s');
});
test('a phase on a timer stays timed from the pull, and casts are grouped by time, not by their number',()=>{
 // Kill 2 has one cast of spell 5 more at 20 s; counting by number would put its later casts a slot off.
 const k=(casts)=>({length:120,phases:[{id:1,at:0},{id:2,at:60,name:'Stage Two'}],casts:casts.map(at=>({at,spell:5}))});
 const tl=aggregate([k([10,30,70]),k([10,20,30.5,70.5]),k([10.5,30,70])]);
 assert.deepEqual(tl.phases,[{id:2,name:'Stage Two',at:60}],'the same start in every kill: no anchor needed');
 assert.deepEqual(tl.events,[ev(10,5),ev(30,5),ev(70,5)]);
});
test('a cast that starts a health phase is timed from that phase, and a cast that moves is marked',()=>{
 const k=(p2,pyre)=>({length:300,phases:[{id:1,at:0},{id:2,at:p2,name:'Eclipse'}],casts:[{at:p2-4,spell:3},{at:p2+10,spell:4},{at:p2+pyre,spell:6}]});
 const tl=aggregate([k(130,36),k(180,41),k(230,46),k(200,51),k(160,56)]);
 assert.deepEqual(tl.phases,[{id:2,name:'Eclipse',at:180,vary:true}]);
 // Spell 3 wanders between 126 and 226 s from the pull but always comes 4 s before stage two.
 assert.deepEqual(tl.events,[ev(176,3,{anchor:1}),ev(190,4,{anchor:1}),ev(226,6,{anchor:1,spread:5})],'spell 6 is kept by its order and marked as moving by 5 s');
});
test('casts are kept only as announced spells, matched by name, and a repeat within 3 s counts once',()=>{
 const out=announcedCasts([{at:5,spell:100},{at:5.2,spell:999},{at:9,spell:200},{at:12,spell:300},{at:20,spell:100}],[200,999],{100:'Tank Smash',999:'tank smash',200:'Other',300:'Unknown'});
 assert.deepEqual(out,[{at:5,spell:999},{at:9,spell:200},{at:20,spell:999}]);
});
test('the boss list and spells come from BossTimerData.lua',async()=>{
 const bosses=bossTimerSpells(await fs.readFile('addon/NaowhDefensivePlanner/BossTimerData.lua','utf8'));
 assert.equal(bosses.length,10);assert.equal(bosses[0].id,3379);assert.equal(bosses[0].name,'Nymrissa Wavecaller');assert.ok(bosses[0].spells.includes(1257717));
});
test('build reads rankings, kills and cast events through the Warcraft Logs API and writes loadable Lua',async()=>{
 const calls=[];
 const fetch=async(url,opts)=>{
  calls.push(url);
  if(url.endsWith('/oauth/token')){assert.match(opts.headers.authorization,/^Basic /);return {ok:true,json:async()=>({access_token:'t'})};}
  assert.equal(opts.headers.authorization,'Bearer t');
  const {query,variables:v}=JSON.parse(opts.body);let data;
  if(query.includes('fightRankings'))data={worldData:{encounter:{name:'B',fightRankings:{rankings:v.d===4?[{report:{code:'A',fightID:1}},{report:{code:'B',fightID:2}},{report:{code:'A',fightID:1}}]:[]}}}};
  else if(query.includes('phaseTransitions'))data={reportData:{report:{fights:[{id:v.f[0],encounterID:3379,startTime:1000,endTime:201000,kill:true,phaseTransitions:[{id:1,startTime:1000},{id:2,startTime:101000}]}],phases:[{encounterID:9999,phases:[{id:2,name:'Other boss phase'}]},{encounterID:3379,phases:[{id:2,name:'Stage Two'}]}],masterData:{actors:[{id:5,subType:'Boss'},{id:6,subType:'NPC'}]}}}};
  else if(query.includes('events('))data={reportData:{report:{events:{data:[{type:'begincast',timestamp:11000,sourceID:5,abilityGameID:777},{type:'cast',timestamp:12000,sourceID:5,abilityGameID:777},{type:'cast',timestamp:31000,sourceID:5,abilityGameID:888},{type:'cast',timestamp:15000,sourceID:6,abilityGameID:555}],nextPageTimestamp:null}}}};
  else if(query.includes('gameData')){const known={777:'Big Hit',888:'Swirl',1257717:'Big Hit'};data={gameData:Object.fromEntries([...query.matchAll(/a(\d+):ability/g)].map(m=>[m[0].slice(0,-8),known[m[1]]?{name:known[m[1]]}:null]))};}
  else throw Error('unexpected query');
  return {ok:true,json:async()=>({data})};
 };
 const bosses=[{id:3379,name:'Nymrissa',spells:[1257717]}];
 const timelines=await build({api:client({id:'x',secret:'y',fetch}),bosses,kills:5});
 assert.equal(calls.filter(u=>u.endsWith('/oauth/token')).length,1,'one token');
 assert.deepEqual(timelines[3379][15].events,[[10,1257717]],'cast start for an ability with one, adds and unannounced spells dropped, IDs mapped');
 assert.deepEqual(timelines[3379][15].phases,[{id:2,name:'Stage Two',at:100}],'phase names of this encounter only');
 assert.equal(timelines[3379][16],undefined,'no Mythic kills, no Mythic timeline');
 const text=lua(timelines,{built:'2026-10-25',kills:5});
 const d=await fs.mkdtemp(path.join(os.tmpdir(),'wcl-'));
 try{await fs.writeFile(d+'/t.lua',text+'\nlocal tl=ns.LogTimelines[3379][15];assert(#tl.events==1 and tl.events[1][2]==1257717 and tl.kills==2 and tl.length==200)');
  if(process.env.DOCTOR_LUA51)execFileSync(process.env.DOCTOR_LUA51,['-e','ns={};local f=assert(loadfile("'+d+'/t.lua"));f(nil,ns)']);}
 finally{await fs.rm(d,{recursive:true,force:true});}
 const shipped=await fs.readFile('addon/NaowhDefensivePlanner/LogTimelines.lua','utf8');assert.match(shipped,/ns\.LogTimelines = \{/);
});
test('a rate limited query waits and retries, and a cut off run keeps the bosses it already read',async()=>{
 let limited=2;const waits=[];
 const fetch=async(url,opts)=>{
  if(url.endsWith('/oauth/token'))return {ok:true,json:async()=>({access_token:'t'})};
  if(limited>0){limited--;return {ok:false,status:429,headers:{get:()=>'45'}};}
  return {ok:true,json:async()=>({data:{worldData:{encounter:{fightRankings:{rankings:[]}}}}})};
 };
 const api=client({id:'x',secret:'y',fetch,sleep:async ms=>{waits.push(ms);}});
 const done={kills:3,names:{1:'Old'},bosses:[{id:7,difficulties:{15:[{length:1,phases:[{id:1,at:0}],casts:[]},{length:1,phases:[{id:1,at:0}],casts:[]},{length:1,phases:[{id:1,at:0}],casts:[]}]}}]};
 const saved=[];
 const raw=await fetchRaw({api,bosses:[{id:7,name:'B',spells:[]}],kills:3,done,save:async r=>{saved.push(r.bosses[0].difficulties[16]?.length);}});
 assert.deepEqual(waits,[45000,45000],'waits as long as the API asks, then retries');
 assert.equal(raw.bosses[0].difficulties[15],done.bosses[0].difficulties[15],'Heroic kept from the earlier run');
 assert.deepEqual(raw.bosses[0].difficulties[16],[],'Mythic read again');
 assert.deepEqual(saved,[0],'saved after the boss and difficulty it read');
 assert.equal(raw.names[1],'Old');
});
