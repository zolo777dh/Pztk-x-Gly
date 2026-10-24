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
 // LibDeflate's bit arithmetic needs Lua 5.1; under fengari, PZTK1 bodies travel as hex and !NDP1: bodies as Base64 of the inflated bytes instead.
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
 return '!NDP1:'+inflateRawSync(Buffer.from(exported.slice(6),'base64')).toString('base64');
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

test('NSRT-style look: colours, ticks, sticky time and timers validate, gate the version and draw',()=>{
 runLua(`
  local function profile(display)return{format=1,addon="PztkReminders",name="t",client="retail",data={raidReminders={[1]={a={trigger={type="pull",delay=10},display=display}}}}}end
  local look={type="bar",dur=8,textColor={1,1,0,1},barColor={1,0,0,1},ticks={2,5},sticky=3,hideTimer=false,countdown=true}
  assert(NS.Validate(profile(look)))
  assert(NS.MinimumAddon(profile(look).data)=="0.6.5")
  assert(NS.MinimumAddon(profile({type="text"}).data)=="0.3.0")
  assert(not NS.Validate(profile({type="bar",ticks={130}})),"tick past 120 s")
  assert(not NS.Validate(profile({type="bar",sticky=61})),"sticky past 60 s")
  assert(not NS.Validate(profile({type="text",countdown="yes"})),"non-boolean countdown")
  assert(not NS.Validate(profile({type="text",textColor={1,2,0,1}})),"colour out of range")
  -- A bar redraws from one ticker, and sticky time keeps it up after the countdown.
  local tickers={}
  C_Timer.NewTicker=function(_,fn)local t={fn=fn};function t:Cancel()self.cancelled=true end;tickers[#tickers+1]=t;return t end
  NS.Display({type="bar",spellID=1,text="Soak",dur=8,sticky=3,ticks={2,5}})
  assert(#tickers==1,"one ticker for the bar")
  NS.Display({type="text",text="Plain",dur=8})
  assert(#tickers==1,"plain text has no ticker")
  T.Advance(8.5);assert(not tickers[1].cancelled,"still shown in sticky time")
  T.Advance(3);assert(tickers[1].cancelled,"released after sticky time")
 `);
});

test('reminder editor turns look fields into display settings',()=>{
 runLua(`
  local d=NS.ApplyLook({type="bar"},{showTimer=false,sticky="2",ticks="10, 3",textColor="yellow",barColor="red",glowNames="Tankadin Healbot",glowColor="blue"})
  assert(d.hideTimer==true and d.sticky==2 and d.ticks[1]==3 and d.ticks[2]==10)
  assert(d.textColor[2]==0.85 and d.barColor[1]==1 and d.glowTargets[2]=="Healbot" and d.glowColor[3]==1)
  local t=NS.ApplyLook({type="text"},{showTimer=true,sticky="",textColor="imported",glowNames=""},{textColor={0.1,0.2,0.3,1}})
  assert(t.countdown==true and t.sticky==nil and t.textColor[1]==0.1 and t.glowTargets==nil and t.ticks==nil)
  assert(NS.LookColorKey({1,0.85,0.1,1})=="yellow" and NS.LookColorKey({0.1,0.2,0.3,1})=="imported" and NS.LookColorKey(nil)=="")
  assert(not pcall(NS.ApplyLook,{type="bar"},{ticks="5, 500"}),"tick limit")
  assert(not pcall(NS.ApplyLook,{type="text"},{textColor="pink"}),"unknown colour")
 `);
});

test('Timeline Reminders features: note timers, hide on use, spoken countdown, recorded boss timeline',()=>{
 runLua(`
  assert(NS.CreateProfile("Raid plan",false))
  local said={};C_VoiceChat={GetTtsVoices=function()return{{voiceID=1}}end,SpeakText=function(_,text)said[#said+1]=text end}
  -- Note lines in the common raid note format.
  local text=table.concat({
   "{time:0:20} Soak - Healbot {text}Soak now{/text}  Tankadin {spell:871}",
   "{time:1:05,p2} {everyone} {spell:22812}@Tankadin,Other",
   "{time:0:08,SCS:1249262:2} role:healer {text}Heal{/text}",
   "{time:0:30} type:melee {text}Melee move{/text}  group:3 {text}G3{/text}  spec:druid:4 {text}Tree{/text}",
   "plain line without a timer"},"\\n")
  local list=NS.ParseNoteTimers(text,"healbot",nil,6);local by={};local n=0
  for _,e in pairs(list)do n=n+1;by[e.display.text~=""and e.display.text or tostring(e.display.spellID)]=e end
  assert(n==6,"six reminders for this character: "..n)
  assert(by["Soak now"].trigger.type=="pull"and by["Soak now"].trigger.delay==20 and by["Soak now"].trigger.leadTime==6)
  assert(not by["871"],"another player's line is skipped")
  local p2=by["22812"];assert(p2.trigger.type=="stage"and p2.trigger.stage==2 and p2.trigger.delay==65 and p2.display.glowTargets[2]=="Other")
  local h=by["Heal"];assert(h.trigger.type=="bwmsg"and h.trigger.spellID==1249262 and h.trigger.delay==2 and h.trigger.counterGroups[1][1].value==2 and h.target.roles.HEALER)
  assert(by["Melee move"].target.matchAny and by["Melee move"].target.specs[71]and by.G3.target.subgroups[3]and by.Tree.target.specs[105])
  -- NSRT-style lines: time from the start of the phase, tag names, glowunit, dur.
  local ns2=NS.ParseNoteTimers(table.concat({"time:90;ph:2;text:Soak;tag:Healbot Other;glowunit:Tankadin;dur:5","time:12.5;spellid:22812;tag:Someone","time:30;text:Everyone go","time:-5;text:Pre"},"\\n"),"healbot",nil,6)
  local nb={};local nn=0;for _,e in pairs(ns2)do nn=nn+1;nb[e.display.text]=e end
  assert(nn==2,"two NSRT lines for this character: "..nn)
  assert(nb.Soak.trigger.type=="stage"and nb.Soak.trigger.stage==2 and nb.Soak.trigger.delay==90 and nb.Soak.trigger.leadTime==5 and nb.Soak.display.dur==5 and nb.Soak.display.glowTargets[1]=="Tankadin")
  assert(nb["Everyone go"].trigger.type=="pull"and nb["Everyone go"].trigger.delay==30 and nb["Everyone go"].target.all)
  -- They fire on the pull without being saved in a profile.
  local shown={};local display=NS.Display;NS.Display=function(d)shown[#shown+1]=d end
  NS.Notes().live={name="Plan",text="{time:0:20} Healbot {text}Soak now{/text}"}
  NS.Begin(3176,16,2900);T.Advance(14.5);assert(#shown==1 and shown[1].text=="Soak now",#shown)
  NS.Notes().cfg.timers=false;NS.Begin(3176,16,2900);T.Advance(30);assert(#shown==1,"note timers can be switched off")
  NS.Display=display
  -- Hide on use and spoken countdown.
  NS.Display({type="icon",spellID=871,dur=8,hideOnUse=true,tts=false})
  assert(NS.HideSpell(871)and not NS.HideSpell(871))
  said={};NS.Display({type="text",text="Go",dur=5,voiceCountdown=3});T.Advance(5)
  assert(table.concat(said,",")=="3,2,1",table.concat(said,","))
  -- Boss timeline recorded from boss mod timers during a pull; the longer pull or the kill is kept.
  NS.Begin(3176,16,2900);NS.Mechanic(1249262,10,"bar1");NS.Mechanic(1249262,9.8,"bar1");T.Advance(20);NS.Mechanic(1250000,nil,"msg")
  assert(NS.FinishRecording(false))
  local tl=NS.RecordedTimeline(3176,16);assert(#tl.events==2 and tl.events[1][1]==10 and tl.events[2][1]==20)
  NS.Begin(3176,16,2900);NS.Mechanic(1,5,"x");assert(not NS.FinishRecording(false),"a shorter wipe does not replace it")
 `);
});
