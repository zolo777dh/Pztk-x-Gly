import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import fengari from 'fengari';
import {unzipSync} from 'fflate';
import {packageAddon} from '../tools/package-addon.mjs';
import {parseLua} from '../core/analyzer.mjs';
const files=['Runtime.lua','Locale.lua','Catalog.lua','Codec.lua','Profiles.lua','Display.lua','RuleRuntime.lua','AuraSounds.lua','Providers.lua','BossTimers.lua','BossTimerData.lua','Journal.lua','LogTimelines.lua','Simulate.lua','Planner.lua','Triggers.lua','Analysis.lua','Trace.lua','Editor.lua','Import.lua','Widgets.lua','UI.lua','Comms.lua','Debuffs.lua','Notes.lua','Players.lua','RaidTools.lua','QoL.lua','Combat.lua','PartyCooldowns.lua','PartyExtras.lua','PartySlash.lua','Main.lua'];
const sources=await Promise.all(files.map(f=>fs.readFile('addon/NaowhDefensivePlanner/'+f,'utf8')));
test('standalone addon bundle contains valid runtime, complete loader dependencies, codecs, media and no NSR/NSRT runtime',async t=>{
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'pztk-addon-zip-'));t.after(()=>fs.rm(dir,{recursive:true,force:true}));const archive=await packageAddon(process.cwd(),dir),entries=unzipSync(await fs.readFile(archive));for(const [i,f]of files.entries()){assert.ok(entries['NaowhDefensivePlanner/'+f]);parseLua(sources[i]);}assert.ok(entries['NaowhDefensivePlanner/Libs/LibSerialize.lua']);assert.ok(!Object.keys(entries).some(k=>k.includes('/Media/Voice/')));assert.ok(entries['NaowhDefensivePlanner/BUILD-SOURCES.json']);assert.ok(!Object.keys(entries).some(k=>k.startsWith('NaowhSmartReminders/')||k.startsWith('NorthernSkyRaidTools/')));
 const manifest=JSON.parse(Buffer.from(entries['NaowhDefensivePlanner/BUILD-SOURCES.json']).toString()),toc=Buffer.from(entries['NaowhDefensivePlanner/NaowhDefensivePlanner.toc']).toString();assert.match(toc,new RegExp('## Version: '+manifest.version.replaceAll('.','\\.')));assert.equal(path.basename(archive),'NaowhDefensivePlanner-'+manifest.version+'.zip');assert.match(sources[0],new RegExp('ns.version = "'+manifest.version.replaceAll('.','\\.')+'"'));
});
test('addon packaging rejects duplicate Lua loads through either TOC or XML',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'pztk-loader-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));
 const addon=path.join(root,'addon','NaowhDefensivePlanner'),output=path.join(root,'release');await fs.mkdir(addon,{recursive:true});
 await fs.writeFile(path.join(addon,'Catalog.lua'),'local _,ns=...;ns.Catalog={}');
 await fs.writeFile(path.join(addon,'NaowhDefensivePlanner.toc'),'## Version: 0.3.1\nCatalog.lua\n./Catalog.lua\n');
 await assert.rejects(packageAddon(root,output),/Duplicate addon file load: NaowhDefensivePlanner\/Catalog\.lua/);
 await fs.writeFile(path.join(addon,'NaowhDefensivePlanner.toc'),'## Version: 0.3.1\nCatalog.lua\nIncludes.xml\n');
 await fs.writeFile(path.join(addon,'Includes.xml'),'<Ui><Script file="Catalog.lua"/></Ui>');
 await assert.rejects(packageAddon(root,output),/Duplicate addon file load: NaowhDefensivePlanner\/Catalog\.lua/);
 await fs.writeFile(path.join(addon,'Includes.xml'),'<Ui><!-- <Script file="Catalog.lua"/> --></Ui>');
 await packageAddon(root,output);
});
test('own addon boots, opens its import window and renders basic text/icon/circle/sound previews under a controlled WoW UI harness',()=>{
 const script=`unpack=unpack or table.unpack;local ns={};local frames={};local scripts={};local sound;local build='12.1.5';local map=2813;local glowStarts,glowStops={},{}
local methods={}
local frame
frame=function()local f={};setmetatable(f,{__index=function(t,k)if methods[k]then return methods[k]end;if k:match("^[A-Z]")then return function()end end end});f.TitleText={SetText=function()end};frames[#frames+1]=f;return f end
methods.SetScript=function(self,key,fn)self._scripts=self._scripts or {};self._scripts[key]=fn end
methods.RegisterEvent=function(self,event)self._events=self._events or {};self._events[event]=true end
methods.CreateTexture=function()return frame()end
methods.CreateFontString=function()return frame()end
function CreateFrame()return frame()end
UIParent=frame();GameFontHighlightSmall={};SlashCmdList={}
function GetBuildInfo()return build,'70448','',build=='12.1.5'and 120105 or 16001 end
function GetTime()return 100 end
function GetInstanceInfo()return '',nil,15,nil,nil,nil,nil,map end
function UnitName()return 'Tester'end
function GetSpecialization()return 1 end
function GetSpecializationInfo()return 264 end
function PlaySoundFile(path)sound=path end
local libs={}
function LibStub(key)return libs[key]end
C_Spell={GetSpellInfo=function()return {name='Astral Shift',iconID=1}end}
C_Timer={NewTimer=function()return {Cancel=function()end}end}
`+sources.map(s=>`;(function(...)\n${s}\nend)('NaowhDefensivePlanner',ns);`).join('\n')+`
assert(SlashCmdList.NDP and SLASH_NDP1=='/ndp' and SLASH_NDP2=='/nwhdp' and SLASH_NDP4=='/pztkr');
-- A renamed PztkReminders.lua SavedVariables file is adopted once and dropped.
PztkRemindersDB={clients={retail={profiles={Old={name='Old',data={}}},active='Old',history={}}}}
assert(ns.Store().profiles.Old and NaowhDefensivePlannerDB.clients.retail.active=='Old' and PztkRemindersDB==nil)
NaowhDefensivePlannerDB=nil
ns.Open();assert(NaowhDefensivePlannerDB.clients.retail)
ns.Display({type='text',text='Raid assignment',dur=5})
ns.Display({type='icon',spellID=108271,text='Defensive',dur=5})
ns.Display({type='circle',spellID=108271,text='Countdown',dur=5})
local said;C_VoiceChat={GetTtsVoices=function()return{{voiceID=1}}end,SpeakText=function(_,text)said=text end}
ns.Display({type='chat',sound='voice:use-a-defensive',text=''})
assert(said=='Use a defensive' and sound==nil)
ns.Settings().voicePhrases={['voice:use-a-defensive']='Wall now'}
ns.Display({type='chat',sound='voice:use-a-defensive',text=''})
assert(said=='Wall now' and ns.SoundPath('voice:use-a-defensive')==7670701 and ns.SoundPath('sound:567397')==567397)
ns.Settings().voicePhrases=nil
assert(ns.Validate({format=1,addon='PztkReminders',name='p',client='retail',data={settings={voicePhrases={['voice:move-out']='Go'}}}}))
assert(not ns.Validate({format=1,addon='PztkReminders',name='p',client='retail',data={settings={voicePhrases={['voice:move-out']=string.rep('x',101)}}}}))
ns.HideDisplays();assert(#frames>5)
-- A failed optional name/icon lookup or unavailable voice list must not break display.
C_Spell.GetSpellInfo=function()error('not available')end
function GetSpellInfo()return 'Legacy spell',nil,2 end
C_VoiceChat={GetTtsVoices=function()error('not initialized')end,SpeakText=function()end}
ns.Display({type='icon',spellID=108271,tts=true,dur=5});ns.HideDisplays()
-- Glows use independent ownership keys, and nameplates use the nameplate API.
local unitFrame,plate=frame(),frame();local plateQueries=0
function UnitExists(token)return token=='player'end
unitFrame.GetAttribute=function(_,key)return key=='unit'and'player'or nil end;unitFrame.IsVisible=function()return true end
function EnumerateFrames(after)if not after then return unitFrame end end
libs['LibCustomGlow-1.0']={PixelGlow_Start=function(f,_,_,_,_,_,_,_,_,key)glowStarts[#glowStarts+1]={frame=f,key=key}end,PixelGlow_Stop=function(f,key)glowStops[#glowStops+1]={frame=f,key=key}end}
C_NamePlate={GetNamePlateForUnit=function()plateQueries=plateQueries+1;return {UnitFrame=plate}end}
ns.Display({type='raidframeGlow',text='First',glowTarget='Tester'})
ns.Display({type='raidframeGlow',text='Second',glowTarget='Tester'})
ns.Display({type='nameplateGlow',text='Nameplate',glowTarget='Tester'})
assert(glowStarts[1].frame==unitFrame and glowStarts[2].frame==unitFrame and glowStarts[1].key~=glowStarts[2].key)
assert(glowStarts[3].frame==plate and plateQueries==1);ns.HideDisplays();assert(#glowStops==3)
for _,stop in ipairs(glowStops)do assert(type(stop.key)=='string'and stop.key:find('NaowhDefensivePlanner:',1,true)==1)end
-- Only the called spell glows on the player's own Cooldown Manager / action bar, then stops.
local function button(spell)return {IsVisible=function()return true end,GetSpellID=function()return spell end}end
local called,other,bar=button(22812),button(61336),{IsVisible=function()return true end,action=7}
EssentialCooldownViewer={GetItemFrames=function()return {called,other}end};ActionButton1=bar
function GetActionInfo(slot)if slot==7 then return 'spell',22812 end end
local procStarts,procStops={},{}
libs['LibCustomGlow-1.0'].ProcGlow_Start=function(f,o)procStarts[#procStarts+1]={frame=f,key=o.key}end
libs['LibCustomGlow-1.0'].ProcGlow_Stop=function(f,key)procStops[#procStops+1]=f end
ns.Display({type='defensive',spells={22812},text='Barkskin',dur=5})
assert(#procStarts==2 and procStarts[1].frame==called and procStarts[2].frame==bar)
ns.HideDisplays();assert(#procStops==2)
EssentialCooldownViewer=nil;ActionButton1=nil
-- Exercise the actual lifecycle event callback, then reopen in the other client.
local eventFrame
for _,f in ipairs(frames)do if f._events and f._events.PLAYER_ENTERING_WORLD then eventFrame=f end end
assert(eventFrame)
NaowhDefensivePlannerDB.clients.retail.profiles.p={data={raidReminders={[3470]={r={trigger={type='pull',delay=30},display={type='text',text='Old zone'}}}}}}
NaowhDefensivePlannerDB.clients.retail.active='p'
ns.Begin(3470,15,2813);assert(next(ns.timers));map=999;eventFrame._scripts.OnEvent(eventFrame,'PLAYER_ENTERING_WORLD')
assert(ns.encounter==nil and ns.map==999 and next(ns.timers)==nil)
ns.Begin(3470,15,999);eventFrame._scripts.OnEvent(eventFrame,'PLAYER_SPECIALIZATION_CHANGED','player');assert(ns.encounter==nil)
map=nil;eventFrame._scripts.OnEvent(eventFrame,'PLAYER_ENTERING_WORLD');assert(ns.map==nil)
build='1.60.1';ns.Open();assert(NaowhDefensivePlannerDB.clients.forever)
local diagnostic=ns.Diagnostics();assert(diagnostic:find('Naowh Defensive Planner '..ns.version,1,true));assert(diagnostic:find('Client: forever',1,true));assert(diagnostic:find('EXBOSS-Locale:',1,true))
`;
 const {lua,lauxlib,lualib,to_luastring}=fengari,L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);try{if(lauxlib.luaL_loadstring(L,to_luastring(script))!==lua.LUA_OK||lua.lua_pcall(L,0,0,0)!==lua.LUA_OK)throw Error(lua.lua_tojsstring(L,-1));}finally{lua.lua_close(L);}
});
