import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import fengari from 'fengari';
import {DoctorService} from '../core/service.mjs';
import {NsrtCodec} from '../core/nsrt.mjs';
import {decodePrint} from '../core/packs.mjs';
import {inflateRawSync} from 'node:zlib';

const {lua,lauxlib,lualib,to_luastring,to_jsstring}=fengari;
const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const addon=path.join(root,'addon','NaowhDefensivePlanner');

// Loads the addon's real Lua (plus the real LibStub/LibDeflate/LibSerialize) over WoW stubs and runs a Lua test body.
function runLua(body,globals={}){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const run=(code,name)=>{if(lauxlib.luaL_loadbuffer(L,to_luastring(code),null,to_luastring(name))!==lua.LUA_OK||lua.lua_pcall(L,0,lua.LUA_MULTRET,0)!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));};
 for(const [k,v]of Object.entries(globals)){lua.lua_pushstring(L,to_luastring(v));lua.lua_setglobal(L,to_luastring(k));}
 run(fs.readFileSync(path.join(root,'tests','helpers','wow-runtime.lua'),'utf8'),'stubs');
 // Real libraries register through the real LibStub; glow/frame libraries stay stubbed.
 run(`local stub=_G.LibStub;_G.LibStub=nil;${fs.readFileSync(path.join(addon,'Libs','LibStub.lua'),'utf8')}\nlocal real=_G.LibStub;_G.LibStub=setmetatable({},{__call=function(_,name,silent)return stub(name)or real(name,silent)end,__index=real})`,'LibStub');
 // LibDeflate's bit arithmetic needs Lua 5.1; under fengari, PZTK1 bodies travel as hex of the inflated bytes instead.
 run(`LibStub:NewLibrary("LibDeflate",1)`,'LibDeflate');run(`local ld=LibStub("LibDeflate")
  function ld:DecodeForPrint(s)return (s:gsub("..",function(h)return string.char(tonumber(h,16))end))end
  function ld:EncodeForPrint(s)return (s:gsub(".",function(c)return string.format("%02x",c:byte())end))end
  function ld:DecompressDeflate(s)return s end
  function ld:CompressDeflate(s)return s end`,'LibDeflate shim');
 for(const lib of ['LibSerialize.lua'])run(fs.readFileSync(path.join(addon,'Libs',lib),'utf8'),lib);
 run('NS={}','ns');
 const files=fs.readFileSync(path.join(addon,'NaowhDefensivePlanner.toc'),'utf8').split(/\r?\n/).filter(l=>l.endsWith('.lua')&&!l.startsWith('Libs'));
 for(const file of files)run(`local chunk=assert(loadstring and loadstring(...) or load(...));chunk("NaowhDefensivePlanner",NS)`.replace(/\.\.\./g,JSON.stringify(fs.readFileSync(path.join(addon,file),'utf8'))),file);
 run(body,'test');
}

async function exportFor(alerts){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'pztk-addon-'));
 const service=await new DoctorService(dir,path.join(root,'resources')).init();
 const profile=await service.handle('planner.createProfile',{client:'retail'});
 const opened=await service.handle('nsr.open',{profileId:profile.id,profileKey:''});
 const view=await service.handle('reminders.read',{id:opened.id??opened});
 const text=new NsrtCodec().encode({type:'EncounterAlert',payload:{version:1,type:'alerts',encounterAlerts:alerts},numericKeys:[]});
 const {view:after}=await service.handle('reminders.migrateNsrt',{id:view.id,revision:view.revision,text});
 const exported=(await service.handle('reminders.export',{id:after.id,revision:after.revision})).text;
 return 'PZTK1:'+inflateRawSync(decodePrint(exported.slice(6))).toString('hex');
}
const alert=extra=>({name:'Pot',text:'Pot',enabled:true,IsAlert:true,DisplayType:'Text',dur:3,phase:1,timers:[-5],loadConditions:{},...extra});

test('addon imports a migrated pre-pull + glow profile and fires it from the pull countdown',async()=>{
 const text=await exportFor({3176:{16:{p:alert({glowunit:'Tankadin player',glowColors:[0,1,0,1]})}},3183:{16:{q:alert({text:'Wrong boss'})}}});
 runLua(`
  local name,err=NS.Import(PZTK); assert(name,err)
  NS.Countdown(10)
  assert(NS.pullEncounter==3176,"nearest planned boss expected, got "..tostring(NS.pullEncounter))
  local shown={};local display=NS.Display;NS.Display=function(d)shown[#shown+1]=d;display(d)end
  T.Advance(1.9);assert(#shown==0,"fired too early")
  T.Advance(0.2);assert(#shown==1,"expected one reminder at pull-5-3s, got "..#shown)
  assert(shown[1].text=="Pot",shown[1].text);assert(math.abs(shown[1].dur-3)<0.2,"duration "..shown[1].dur)
  assert(#T.glows==2,"expected two glows, got "..#T.glows)
  assert(T.glows[1].color[2]==1 and T.glows[1].color[1]==0,"glow colour kept")
  NS.HideDisplays();assert(#T.stopped==2,"glows stopped on release")
 `,{PZTK:text});
});

test('short countdowns show at once for the time left; cancel and ENCOUNTER_START stop pending reminders',async()=>{
 const text=await exportFor({3176:{16:{p:alert({timers:[-2],dur:5})}}});
 runLua(`
  assert(NS.Import(PZTK))
  local shown={};NS.Display=function(d)shown[#shown+1]=d end
  NS.Countdown(4);T.Advance(0.01);assert(#shown==1 and math.abs(shown[1].dur-2)<0.1,"truncated duration expected")
  shown={};NS.Countdown(10);NS.Countdown(nil);T.Advance(20);assert(#shown==0,"cancelled countdown must not fire")
  NS.Countdown(10);NS.Begin(3176,16,2900);T.Advance(20);assert(#shown==0,"pull must clear pre-pull timers")
  NS.Countdown(1);T.Advance(5);assert(#shown==0,"countdown shorter than the pre-pull time does nothing")
 `,{PZTK:text});
});

test('ambiguous bosses without a map position are not guessed',async()=>{
 const text=await exportFor({3176:{16:{p:alert()}},3183:{16:{q:alert()}}});
 runLua(`
  assert(NS.Import(PZTK));T.position=nil
  local enc,why=NS.PullEncounter();assert(enc==nil and why:match("several"),tostring(why))
  T.pins={T.pins[2]};assert(NS.PullEncounter()==3176)
  assert(NS.Diagnostics():match("Pre%-pull encounter: 3176"))
 `,{PZTK:text});
});

test('addon validation accepts the new fields and refuses malformed ones',()=>{
 runLua(`
  local function profile(trigger,display)return{format=1,addon="PztkReminders",name="t",client="retail",data={raidReminders={[1]={a={trigger=trigger,display=display}}}}}end
  assert(NS.Validate(profile({type="prepull",delay=5},{type="text",glowTargets={"A","B"},glowColor={1,0,0,1}})))
  assert(not NS.Validate(profile({type="prepull",delay=0},{type="text"})),"zero pre-pull")
  assert(not NS.Validate(profile({type="pull",delay=1},{type="text",glowTargets={"A",[3]="C"}})),"gappy list")
  assert(not NS.Validate(profile({type="pull",delay=1},{type="text",glowTargets={5}})),"non-string name")
  assert(not NS.Validate(profile({type="pull",delay=1},{type="text",glowColor={1,0,0}})),"short colour")
  local ser,ld=LibStub("LibSerialize"),LibStub("LibDeflate")
  local p=profile({type="pull",delay=1},{type="text"});p.minimumAddon="9.0.0"
  local _,err=NS.Decode("PZTK1:"..ld:EncodeForPrint(ld:CompressDeflate(ser:Serialize(p))));assert(err:match("9%.0%.0"),err)
 `);
});
