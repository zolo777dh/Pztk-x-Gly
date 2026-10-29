import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import fengari from 'fengari';

const read=f=>fs.readFile('addon/NaowhDefensivePlanner/'+f,'utf8');
const [calls,data]=await Promise.all([read('BossCalls.lua'),read('BossTimerData.lua')]);
function run(script){
 const {lua,lauxlib,lualib,to_luastring}=fengari,L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 try{if(lauxlib.luaL_loadstring(L,to_luastring(fixture+'\n'+script))!==lua.LUA_OK||lua.lua_pcall(L,0,0,0)!==lua.LUA_OK)throw Error(lua.lua_tojsstring(L,-1));}finally{lua.lua_close(L);}
}
// A mocked game: a clock, scheduled callbacks, the player's role and threat, and every
// ns.Display call recorded as "text|style|voice".
const fixture=`local ns={timers={},BossTimers={}};local now=0;local pending={};shown={};settings={};role="DAMAGER";threat=0;entries={}
function GetTime()return now end
function UnitGroupRolesAssigned()return role end
function UnitThreatSituation()return threat end
function ns.Plain(v,kind)return v~=nil and(not kind or type(v)==kind)end
function ns.Settings()return settings end
function ns.Active()return{data={settings=settings}}end
function ns.EncounterEntries()return entries end
function ns.EditProfile(fn)return fn({settings=settings})end
function ns.Cancel(prefix)for key in pairs(ns.timers)do if key:sub(1,#prefix)==prefix then ns.timers[key]=nil end end end
function ns.Schedule(key,delay,fn)local t={at=now+delay,fn=fn,key=key};ns.timers[key]=t;pending[#pending+1]=t end
function advance(time)
 table.sort(pending,function(a,b)return a.at<b.at end)
 local left={}
 for _,t in ipairs(pending)do if t.at<=time then if ns.timers[t.key]==t then ns.timers[t.key]=nil;now=t.at;t.fn()end else left[#left+1]=t end end
 pending=left;now=time
end
function ns.Display(d)shown[#shown+1]=d.text.."|"..d.style.."|"..(d.tts and d.ttsText or"-")end
;(function(...)\n${data}\nend)('NaowhDefensivePlanner',ns);
;(function(...)\n${calls}\nend)('NaowhDefensivePlanner',ns);
function has(text)for _,c in ipairs(shown)do if c==text then return true end end;return false end
function check(text)assert(has(text),"missing "..text.."; got: "..table.concat(shown,", "))end
function absent(text)assert(not has(text),"unexpected "..text)end`;

test('every mechanic the built-in timers name has a built-in boss call',()=>{
 run(`local missing={}
 for _,id in ipairs(ns.BossTimerOrder)do
  assert(ns.BossCalls[id],"no calls for "..id)
  for _,spell in ipairs(ns.BossTimerSpells[id])do if not ns.BossCalls[id][spell]then missing[#missing+1]=id..":"..spell end end
  for spell,call in pairs(ns.BossCalls[id])do
   assert(type(call.say)=="string"and #call.say>0 and #call.say<=40,"text of "..spell)
   local listed=false;for _,s in ipairs(ns.BossTimerSpells[id])do if s==spell then listed=true end end
   assert(listed,"call for a spell the timers never name: "..id..":"..spell)
  end
 end
 assert(#missing==0,"no call for "..table.concat(missing,", "))`);
});

test('a call shows its lead seconds before the cast, as a bar when set, and speaks',()=>{
 run(`ns.difficulty=15
 ns.BossCall(1290516,30,"NDP:1",3421)
 advance(21);absent("Soak|bar|Soak");advance(22);check("Soak|bar|Soak")
 ns.BossCall(1313393,20,"NDP:2",3379);advance(40);check("Frost debuffs|text|-")
 settings.bossCallsVoice=false;ns.BossCall(1276710,10,"NDP:3",3379);advance(60);check("Adds|text|-")`);
});

test('roles, threat and difficulty pick who sees a call',()=>{
 run(`ns.difficulty=15
 ns.BossCall(1282937,10,"NDP:1",3379);advance(20);absent("Tank hit|text|-")
 role="TANK";threat=3;ns.BossCall(1282937,10,"NDP:2",3379);advance(40);check("Tank hit|text|-")
 shown={};threat=0;ns.BossCall(1282937,10,"NDP:3",3379);advance(60);absent("Tank hit|text|-")
 ns.BossCall(1282937,nil,"NDPMSG:1282937",3379);advance(61);check("Taunt|text|Taunt")
 shown={};threat=3;ns.BossCall(1282937,nil,"NDPMSG:1282937",3379);advance(70);absent("Taunt|text|Taunt")
 role="DAMAGER";ns.BossCall(1268562,10,"NDP:4",3379);advance(90);absent("Frontal|text|-")
 ns.difficulty=16;ns.BossCall(1268562,10,"NDP:5",3379);advance(110);check("Frontal|text|-")
 shown={};role="HEALER";ns.BossCall(1260837,10,"NDP:6",3379);advance(130);check("Raid damage|text|-")`);
});

test('calls can be switched off, one by one or all, and give way to your own alert',()=>{
 run(`ns.difficulty=15
 assert(ns.SetBossCallEnabled(3379,1276710,false));ns.BossCall(1276710,10,"NDP:1",3379);advance(20);absent("Adds|text|Adds")
 assert(ns.SetBossCallEnabled(3379,1276710,true));assert(settings.bossCallsOff==nil)
 ns.BossCall(1276710,10,"NDP:2",3379);advance(40);check("Adds|text|Adds")
 shown={};entries={a={trigger={spellID=1276710},alert={text="Mine"}}};ns.BossCall(1276710,10,"NDP:3",3379);advance(60);absent("Adds|text|Adds")
 entries={};settings.bossCalls=false;ns.BossCall(1276710,10,"NDP:4",3379);advance(80);absent("Adds|text|Adds")
 assert(ns.BossCallsText("Nymrissa"):find("Adds",1,true))`);
});
