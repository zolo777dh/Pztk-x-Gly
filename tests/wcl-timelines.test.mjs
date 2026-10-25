import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';import {execFileSync} from 'node:child_process';
import {aggregate,announcedCasts,bossTimerSpells,build,client,lua,median} from '../tools/build-wcl-timelines.mjs';

test('base timelines take the median time of each cast per phase and drop casts most kills never saw',()=>{
 assert.equal(median([3,1,2]),2);assert.equal(median([1,2,3,4]),2.5);
 const kills=[
  {length:300,phases:[{id:1,at:0},{id:2,at:100,name:'Intermission'}],casts:[{at:10,spell:1},{at:40,spell:1},{at:105,spell:2},{at:250,spell:9}]},
  {length:320,phases:[{id:1,at:0},{id:2,at:120,name:'Intermission'}],casts:[{at:12,spell:1},{at:42,spell:1},{at:127,spell:2}]},
  {length:280,phases:[{id:1,at:0},{id:2,at:110,name:'Intermission'}],casts:[{at:11,spell:1},{at:41,spell:1},{at:41.5,spell:1},{at:116,spell:2}]},
 ];
 const tl=aggregate(kills);
 assert.equal(tl.length,300);assert.equal(tl.kills,3);
 assert.deepEqual(tl.phases,[{id:2,name:'Intermission',at:110}]);
 // Phase 2 casts sit after the median phase start (110), at their median offset in the phase (6).
 assert.deepEqual(tl.events,[[11,1],[41,1],[116,2]],'the stray 3rd cast and the once-seen spell 9 are dropped');
 assert.equal(aggregate([]),null);
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
  else if(query.includes('gameData'))data={gameData:{ability:{name:{777:'Big Hit',888:'Swirl',1257717:'Big Hit'}[v.i]}}};
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
