import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';import {execFileSync} from 'node:child_process';import fengari from 'fengari';
const root=path.resolve('addon/PztkReminders'),files=['Runtime','Catalog','Profiles','Display','RuleRuntime','AuraSounds','Providers','Editor','Import','Widgets','UI','Main'],sources=await Promise.all(files.map(f=>fs.readFile(root+'/'+f+'.lua','utf8'))),harness=await fs.readFile('tests/helpers/wow-workspace.lua','utf8');
async function run(body){const script=`local env=(function()\n${harness}\nend)()\n`+(process.env.DOCTOR_LUA51?`strmatch=string.match;dofile(${JSON.stringify(root+'/Libs/LibStub.lua')});dofile(${JSON.stringify(root+'/Libs/LibSerialize.lua')});dofile(${JSON.stringify(root+'/Libs/LibDeflate.lua')})`:`local libs={};function LibStub(key)return libs[key]end;libs.LibSerialize={Serialize=function(_,p)return p.name end};libs.LibDeflate={CompressDeflate=function(_,s)return s end,EncodeForPrint=function(_,s)return s end}`)+`\nlocal ns={}\n`+sources.map(s=>`;(function(...)\n${s}\nend)('PztkReminders',ns)`).join('\n')+`\nns.Open();ns.Display=function(d)env.shown[#env.shown+1]=d end\n${body}`;
 if(process.env.DOCTOR_LUA51){const d=await fs.mkdtemp(path.join(os.tmpdir(),'pztk-workspace-'));try{await fs.writeFile(d+'/test.lua',script);execFileSync(process.env.DOCTOR_LUA51,[d+'/test.lua'],{encoding:'utf8'});}finally{await fs.rm(d,{recursive:true,force:true});}return;}
 const {lua,lauxlib,lualib,to_luastring}=fengari,L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);try{if(lauxlib.luaL_loadstring(L,to_luastring(script))!==lua.LUA_OK||lua.lua_pcall(L,0,0,0)!==lua.LUA_OK)throw Error(lua.lua_tojsstring(L,-1));}finally{lua.lua_close(L);}
}
test('in-game UI creates, orders and saves independent M+ and raid defensive sets and refuses combat edits',()=>run(`
assert(ns.WorkspaceWindow:IsShown());assert(ns.Active().name=='Default')
env.click('mode:sets');env.input('set-name','M+ personal');env.input('new-spell','22812');env.click('add-spell');env.input('new-spell','61336');env.click('add-spell');env.click('set-up:2');env.click('set-together:1');env.click('save-set')
local m=ns.ScopePresets(ns.Active(),'mythic',104);local key,preset=next(m);assert(preset.name=='M+ personal'and preset.list[1]==61336 and preset.together[61336])
assert(next(ns.ScopePresets(ns.Active(),'raid',104))==nil)
env.click('tab:raid');env.click('mode:sets');env.input('set-name','Raid personal');env.input('new-spell','22812');env.click('add-spell');env.click('save-set')
assert(ns.ScopePresets(ns.Active(),'mythic',104)[key].name=='M+ personal');local rkey=next(ns.ScopePresets(ns.Active(),'raid',104));assert(rkey and rkey~=key)
env.combat=true;local result,error=ns.SaveSet('raid',104,rkey,'Not saved',{});assert(not result and error:find('combat'));env.combat=false
local before=#env.frames;for i=1,12 do env.click('tab:mythic');env.click('mode:sets');env.click('tab:raid');env.click('mode:sets')end;assert(#env.frames-before<120,'UI redraw is leaking frames')
`));
test('saved mechanic bindings dispatch the correct content-scoped set and trash rules require Mythic+',()=>run(`
local m=assert(ns.SaveSet('mythic',104,nil,'Dungeon set',{{spellID=22812,enabled=true}}));local r=assert(ns.SaveSet('raid',104,nil,'Raid set',{{spellID=61336,enabled=true}}))
local ctx={scope='mythic',spec=104,map=2813,npc=236071,group=2813,kind='trash',spell=1216529,difficulty=8}
local key=assert(ns.SaveRule(ctx,{name='Shield Bash defensive',action='defensive',preset=m,leadTime=2,duration=4}));ns.map=2813;ns.difficulty=8;ns.instanceType='party';ns.Trash(1216529,5,'cast');env.advance(3);assert(#env.shown==1 and env.shown[1].spellID==22812 and env.shown[1].text=='Barkskin')
ns.difficulty=2;ns.Trash(1216529,5,'heroic');env.advance(3);assert(#env.shown==1)
ns.difficulty=16;ns.instanceType='raid';ns.RenderDefensive({defensive={specID=104,preset=r,scope='raid'},display={}});assert(env.shown[2].spellID==61336 and env.shown[2].text=='Survival Instincts')
local result,error=ns.DeleteSet('mythic',104,m);assert(not result and error:find('assigned'))
`));
test('raid UI authors pull and phase reminders, preserves recipients and exports the edited profile',()=>run(`
env.click('tab:raid');env.select('group','Midnight · Season 2');env.click('new-timed');env.input('rule:name','Raid movement');env.input('rule:delay','10');env.click('inspector:display');env.input('rule:text','Move now');env.click('inspector:filters');env.select('rule:recipient','Role');env.select('rule:role','Tank');env.click('save-rule')
local entries=ns.Get(ns.Active().data.raidReminders,3379);local key,e=next(entries);assert(e.trigger.type=='pull'and e.trigger.delay==10 and e.target.roles.TANK and e.content=='raid'and e.difficulties[15])
ns.instanceType='raid';ns.Begin(3379,15,1);env.advance(7);assert(#env.shown==0);env.advance(1);assert(#env.shown==1 and env.shown[1].text=='Move now');ns.Reset()
env.click('timed:'..key);env.select('rule:trigger','Time from phase');env.input('rule:phase','2');env.input('rule:delay','5');env.click('save-rule');e=ns.Get(ns.Active().data.raidReminders,3379)[key];assert(e.trigger.type=='stage'and e.trigger.stage==2)
ns.Begin(3379,15,1);env.advance(10);local before=#env.shown;ns.Phase(2);env.advance(3);assert(#env.shown==before+1);ns.Reset()
env.click('tab:profiles');env.click('profile-export');local text=ns.UIControls['profile-string']:GetText();assert(text:sub(1,6)=='PZTK1:')
`));
test('profile operations, manual Forever encounters and all 40 named specs work without mutating another client',()=>run(`
assert(ns.CreateProfile('Copy',true));assert(ns.RenameProfile('Renamed'));assert(ns.SelectProfile('Default'));assert(ns.Store().profiles.Renamed)
local count=0;for _ in pairs(ns.Catalog.specs)do count=count+1 end;assert(count==40)
env.version='1.60.1';assert(ns.CreateProfile('Forever',false));assert(#ns.CatalogGroups('mythic')==0)
assert(ns.AddManualMechanic({scope='mythic',groupName='My dungeon',npcName='My boss',npcID=123,mapID=456,encounterId=789,spellID=999,spellName='My mechanic',kind='boss'}));local groups=ns.CatalogGroups('mythic');assert(#groups==1 and groups[1].npcs[1].abilities[1].id==999)
assert(PztkRemindersDB.clients.retail.profiles.Default and PztkRemindersDB.clients.forever.profiles.Forever)
`));
test('legacy shared presets split into independent copies on first edit, with exact IDs and no aliasing',()=>run(`
ns.Active().data.presets={[104]={p={name='Legacy',list={22812},together={}}}};ns.Active().data.activePreset={[104]='p'}
assert(ns.EditProfile(function(data)data.settings.voiceOn=true end));local p=ns.Active();assert(ns.ScopePresets(p,'mythic',104).p.list[1]==22812);assert(ns.ScopePresets(p,'raid',104).p.list[1]==22812)
assert(ns.SaveSet('mythic',104,'p','Changed',{{spellID=61336,enabled=false}}));assert(ns.ScopePresets(ns.Active(),'raid',104).p.name=='Legacy');assert(ns.Active().data.presets[104].p.name=='Legacy');assert(#ns.Pick(ns.ScopePresets(ns.Active(),'mythic',104).p)==0)
`));

test('a boss mechanic produces a Together callout with both defensive icons and names, and content filters isolate the event',()=>run(`
local set=assert(ns.SaveSet('mythic',104,nil,'Together',{{spellID=22812,enabled=true,together=true},{spellID=61336,enabled=true,together=true}}))
local ctx={scope='mythic',spec=104,encounter=3456,npc=259445,kind='boss',spell=1296050,difficulty=8}
assert(ns.SaveRule(ctx,{name='Boss defensive',action='defensive',preset=set,trigger='bwmsg',delay=0,leadTime=0,duration=4}))
ns.instanceType='party';ns.Begin(3456,8,1);ns.Mechanic(1296050,nil,'boss');env.advance(0.1)
assert(#env.shown==1 and #env.shown[1].spells==2 and env.shown[1].spells[1]==22812 and env.shown[1].spells[2]==61336)
assert(env.shown[1].text=='Barkskin and Survival Instincts');ns.Reset();ns.instanceType='raid';ns.Begin(3456,16,1);ns.Mechanic(1296050,nil,'wrong-content');env.advance(1);assert(#env.shown==1)
`));
