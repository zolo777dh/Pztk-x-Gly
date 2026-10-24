import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import fengari from 'fengari';

const files=['BossTimers.lua','BossTimerData.lua'];
const sources=await Promise.all(files.map(f=>fs.readFile('addon/PuzatikDefensivePlanner/'+f,'utf8')));
function run(script){
 const {lua,lauxlib,lualib,to_luastring}=fengari,L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 try{if(lauxlib.luaL_loadstring(L,to_luastring(fixture+'\n'+script))!==lua.LUA_OK||lua.lua_pcall(L,0,0,0)!==lua.LUA_OK)throw Error(lua.lua_tojsstring(L,-1));}finally{lua.lua_close(L);}
}
// A mocked game: one clock, C_Timer, a scriptable encounter timeline and the runtime calls
// the engine uses. Every ns.Mechanic call is recorded as "spell|duration|identity".
const fixture=`local ns={timers={},generation=0};local now=0;local pending={};calls={};states={};providers={};settings={}
function GetTime()return now end
function CreateFrame()local f={events={}};function f:RegisterEvent(e)self.events[e]=true end;function f:RegisterUnitEvent(e)self.events[e]=true end;function f:UnregisterEvent(e)self.events[e]=nil end;function f:SetScript(_,fn)self.script=fn end;frames=frames or {};frames[#frames+1]=f;return f end
C_Timer={NewTimer=function(delay,fn)local t={at=now+delay,fn=fn};function t:Cancel()self.cancelled=true end;pending[#pending+1]=t;return t end}
C_Timer.After=function(delay,fn)C_Timer.NewTimer(delay,fn)end
C_EncounterTimeline={GetEventState=function(id)return states[id]end}
function advance(time)
 local steps=0
 while true do
  local best,at
  for i,t in ipairs(pending)do if not t.cancelled and t.at<=time and(not best or t.at<best.at)then best,at=t,i end end
  if not best then break end
  table.remove(pending,at);now=math.max(now,best.at);best.fn()
  steps=steps+1;assert(steps<20000,"timer loop")
 end
 local live={};for _,t in ipairs(pending)do if not t.cancelled then live[#live+1]=t end end;pending=live
 now=math.max(now,time)
end
function ns.Plain(v,kind)return not kind or type(v)==kind end
function ns.Settings()return settings end
function ns.ProviderStatus()return providers end
function ns.Cancel(prefix)for key,t in pairs(ns.timers)do if not prefix or key:sub(1,#prefix)==prefix then ns.timers[key]=nil;t:Cancel()end end end
function ns.Schedule(key,delay,fn)if ns.timers[key]then ns.timers[key]:Cancel()end;local t;t=C_Timer.NewTimer(math.max(0.01,delay),function()if ns.timers[key]~=t then return end;ns.timers[key]=nil;fn()end);ns.timers[key]=t end
function ns.Phase(n)ns.phase=n;calls[#calls+1]="stage|"..n end
function ns.Mechanic(spell,duration,identity,encounter,skip,again)calls[#calls+1]=spell.."|"..tostring(duration).."|"..identity..(again and "|again"or"")end
${sources.map(s=>`;(function(...)\n${s}\nend)('PuzatikDefensivePlanner',ns);`).join('\n')}
function begin(encounter,difficulty)ns.ResetBuiltinTimers();ns.Cancel();ns.encounter,ns.difficulty,ns.phase=encounter,difficulty,1;ns.StartBuiltinTimers();advance(now)end
function bar(id,duration)ns.BuiltinTimerEvent("ENCOUNTER_TIMELINE_EVENT_ADDED",{id=id,source=0,duration=duration});advance(now)end
function state(id,s)states[id]=s;ns.BuiltinTimerEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED",id)end
function has(text)for _,c in ipairs(calls)do if c==text then return true end end;return false end
function check(text)assert(has(text),"missing "..text.."; got:\\n"..table.concat(calls,"\\n"))end
function absent(text)assert(not has(text),"unexpected "..text)end`;

test('built-in timers name a timeline bar and send its message when it ends',()=>{
 run(`begin(3379,16)
 bar(1,18);check("1257717|18|PDP:1")
 advance(17);absent("1257717|nil|NDPMSG:1257717")
 advance(18);check("1257717|nil|NDPMSG:1257717")
 bar(2,22);check("1268562|22|PDP:2")`); // Mythic Nymrissa uses the Jet in place of Flurry
});

test('built-in timers stay off when a boss mod is connected unless Settings choose them, and take over without one',()=>{
 run(`providers.BigWigs=true;begin(3379,15)
 bar(1,18);absent("1257717|18|PDP:1")
 settings.bossSource="ndp";begin(3379,15)
 bar(2,18);check("1257717|18|PDP:2")
 settings.bossSource="bigwigs";begin(3379,15)
 bar(3,18);absent("1257717|18|PDP:3")
 providers.BigWigs=nil;begin(3379,15)
 bar(4,18);check("1257717|18|PDP:4")`);
});

test('paused bars resume with their remaining time and cancelled bars send nothing',()=>{
 run(`begin(3379,15)
 bar(1,18);advance(8);state(1,1);advance(30);absent("1257717|nil|NDPMSG:1257717")
 state(1,0);check("1257717|10|PDP:1|again")
 advance(40);check("1257717|nil|NDPMSG:1257717")
 calls={};bar(2,35);state(2,3);advance(80);absent("1313393|nil|NDPMSG:1313393")`);
});

test('bars added just before the pull starts are picked up',()=>{
 run(`ns.encounter=nil;ns.BuiltinTimerEvent("ENCOUNTER_TIMELINE_EVENT_ADDED",{id=7,source=0,duration=18})
 begin(3379,14);check("1257717|18|PDP:7")`);
});

test("Nek'zali starts its own pull bars and follows the ritual into stage 1.5",()=>{
 run(`begin(3470,16)
 local found=false;for _,c in ipairs(calls)do if c:match("|NDPBAR:")then found=true end end;assert(found,"no pull bar")
 local unit;for _,f in ipairs(frames)do if f.events.UNIT_SPELLCAST_INTERRUPTED then unit=f end end
 unit.script(unit,"UNIT_SPELLCAST_INTERRUPTED","boss1")
 unit.script(unit,"UNIT_SPELLCAST_CHANNEL_START","boss1");check("stage|1.5")
 unit.script(unit,"UNIT_SPELLCAST_CHANNEL_START","boss1");check("stage|2")`);
});

test("Kith'ix drops its tracked bars when a stage one bar is cancelled",()=>{
 run(`begin(3513,16)
 bar(1,47);check("1304045|47|PDP:1")
 bar(2,5);state(2,3)
 advance(60);absent("1304045|nil|NDPMSG:1304045")
 bar(3,1);check("stage|2");check("1308873|1|PDP:3")`);
});

test('every boss script handles bars of any length without errors',()=>{
 run(`for _,enc in ipairs({3379,3420,3455,3470,3445,3421,3429,3497,3492,3513})do
  for _,diff in ipairs({14,15,16,17})do
   begin(enc,diff);for i=1,240 do bar(enc*1000+i,i+0.4)end;advance(now+400)
  end
 end`);
});
