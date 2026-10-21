import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import fengari from 'fengari';
import {unzipSync} from 'fflate';
import {packageAddon} from '../tools/package-addon.mjs';
import {parseLua} from '../core/analyzer.mjs';
const files=['Runtime.lua','Profiles.lua','Display.lua','Main.lua'];
const sources=await Promise.all(files.map(f=>fs.readFile('addon/PztkReminders/'+f,'utf8')));
test('standalone addon bundle contains valid runtime, complete loader dependencies, codecs, media and no NSR/NSRT runtime',async t=>{
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'pztk-addon-zip-'));t.after(()=>fs.rm(dir,{recursive:true,force:true}));const archive=await packageAddon(process.cwd(),dir),entries=unzipSync(await fs.readFile(archive));for(const [i,f]of files.entries()){assert.ok(entries['PztkReminders/'+f]);parseLua(sources[i]);}assert.ok(entries['PztkReminders/Libs/LibSerialize.lua']);assert.ok(entries['PztkReminders/Media/Voice/use-a-defensive.ogg']);assert.ok(entries['PztkReminders/BUILD-SOURCES.json']);assert.ok(!Object.keys(entries).some(k=>k.startsWith('NaowhSmartReminders/')||k.startsWith('NorthernSkyRaidTools/')));
});
test('own addon boots, opens its import window and renders basic text/icon/circle/sound previews under a controlled WoW UI harness',()=>{
 const script=`local ns={};local frames={};local scripts={};local sound
local methods={}
local frame
frame=function()local f={};setmetatable(f,{__index=function(t,k)if methods[k]then return methods[k]end;if k:match("^[A-Z]")then return function()end end end});f.TitleText={SetText=function()end};frames[#frames+1]=f;return f end
methods.SetScript=function(self,key,fn)self._scripts=self._scripts or {};self._scripts[key]=fn end
methods.CreateTexture=function()return frame()end
methods.CreateFontString=function()return frame()end
function CreateFrame()return frame()end
UIParent=frame();GameFontHighlightSmall={};SlashCmdList={}
function GetBuildInfo()return '12.1.5','70448','',120105 end
function GetTime()return 100 end
function GetInstanceInfo()return '',nil,15,nil,nil,nil,nil,2813 end
function UnitName()return 'Tester'end
function GetSpecialization()return 1 end
function GetSpecializationInfo()return 264 end
function PlaySoundFile(path)sound=path end
function LibStub()return nil end
C_Spell={GetSpellInfo=function()return {name='Astral Shift',iconID=1}end}
C_Timer={NewTimer=function()return {Cancel=function()end}end}
`+sources.map(s=>`;(function(...)\n${s}\nend)('PztkReminders',ns);`).join('\n')+`
assert(SlashCmdList.PZTKREMINDERS);ns.Open();assert(PztkRemindersDB.clients.retail)
ns.Display({type='text',text='Raid assignment',dur=5})
ns.Display({type='icon',spellID=108271,text='Defensive',dur=5})
ns.Display({type='circle',spellID=108271,text='Countdown',dur=5})
ns.Display({type='chat',sound='voice:use-a-defensive',text=''})
assert(sound=='Interface\\\\AddOns\\\\PztkReminders\\\\Media\\\\Voice\\\\use-a-defensive.ogg')
ns.HideDisplays();assert(#frames>5)
`;
 const {lua,lauxlib,lualib,to_luastring}=fengari,L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);try{if(lauxlib.luaL_loadstring(L,to_luastring(script))!==lua.LUA_OK||lua.lua_pcall(L,0,0,0)!==lua.LUA_OK)throw Error(lua.lua_tojsstring(L,-1));}finally{lua.lua_close(L);}
});
