import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';import {execFileSync} from 'node:child_process';import fengari from 'fengari';
const root=path.resolve('addon/NaowhDefensivePlanner'),files=['Runtime','Locale','Catalog','Profiles','Display','RuleRuntime','AuraSounds','Providers','Editor','Import','Widgets','UI','Comms','Debuffs','Notes','Players','RaidTools','QoL','Combat','Main'],sources=await Promise.all(files.map(f=>fs.readFile(root+'/'+f+'.lua','utf8'))),harness=await fs.readFile('tests/helpers/wow-workspace.lua','utf8');
async function run(body){const script=`local env=(function()\n${harness}\nend)()\n`+(process.env.DOCTOR_LUA51?`strmatch=string.match;dofile(${JSON.stringify(root+'/Libs/LibStub.lua')});dofile(${JSON.stringify(root+'/Libs/LibSerialize.lua')});dofile(${JSON.stringify(root+'/Libs/LibDeflate.lua')})`:`local libs={};function LibStub(key)return libs[key]end;libs.LibSerialize={Serialize=function(_,p)return p.name end};libs.LibDeflate={CompressDeflate=function(_,s)return s end,EncodeForPrint=function(_,s)return s end}`)+`\nlocal function boot()local ns={}\n`+sources.map(s=>`;(function(...)\n${s}\nend)('NaowhDefensivePlanner',ns)`).join('\n')+`\nreturn ns end;local ns=boot();ns.Open();ns.Display=function(d)env.shown[#env.shown+1]=d end\nfunction env.reload()for i=#env.frames,1,-1 do local f=env.frames[i];if f.events.PLAYER_LOGOUT then f.scripts.OnEvent(f,'PLAYER_LOGOUT');break end end;ns.WorkspaceWindow:SetScript('OnHide',nil);ns.WorkspaceWindow:Hide();local lib=LibStub('LibSerialize');if lib.Deserialize then local ok,db=lib:Deserialize(lib:Serialize(NaowhDefensivePlannerDB));assert(ok);NaowhDefensivePlannerDB=db else NaowhDefensivePlannerDB=ns.Clone(NaowhDefensivePlannerDB)end;ns=boot();ns.Open();ns.Display=function(d)env.shown[#env.shown+1]=d end end\n${body}`;
 if(process.env.DOCTOR_LUA51){const d=await fs.mkdtemp(path.join(os.tmpdir(),'pztk-workspace-'));try{await fs.writeFile(d+'/test.lua',script);execFileSync(process.env.DOCTOR_LUA51,[d+'/test.lua'],{encoding:'utf8'});}finally{await fs.rm(d,{recursive:true,force:true});}return;}
 const {lua,lauxlib,lualib,to_luastring}=fengari,L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);try{if(lauxlib.luaL_loadstring(L,to_luastring(script))!==lua.LUA_OK||lua.lua_pcall(L,0,0,0)!==lua.LUA_OK)throw Error(lua.lua_tojsstring(L,-1));}finally{lua.lua_close(L);}
}
test('unsaved set names, ability inputs and chosen encounters survive navigation and reopening',()=>run(`
env.select('group','Altar of Fangs');local group=ns.UIState.group
env.click('mode:sets');env.input('set-name','Unfinished set');env.input('new-spell','22812')
env.click('mode:mechanics');assert(ns.UIState.group==group)
env.click('tab:raid');env.click('tab:mythic');assert(ns.UIState.group==group)
env.click('mode:sets');assert(ns.UIControls['set-name']:GetText()=='Unfinished set');assert(ns.UIControls['new-spell']:GetText()=='22812')
env.click('add-spell');env.input('new-spell','61336');ns.WorkspaceWindow:Hide();ns.Open()
assert(ns.UIControls['set-name']:GetText()=='Unfinished set');assert(ns.UIControls['new-spell']:GetText()=='61336')
env.click('add-spell');env.click('save-set');local key=ns.UIState.setKey;assert(key)
env.click('tab:settings');env.click('tab:mythic');env.click('mode:sets')
assert(ns.UIControls['set-name']:GetText()=='Unfinished set');assert(#ns.ScopePresets(ns.Active(),'mythic',104)[key].list==2)
`));
test('settings drafts survive a source dropdown, page changes and closing, then save exactly',()=>run(`
env.click('tab:settings');env.input('setting:iconSize','57');env.input('setting:x','125');if ns.UIControls['setting:voiceOn'].value then env.click('setting:voiceOn')end;env.click('setting:voiceOn');env.select('setting:bossSource','DBM')
assert(ns.UIControls['setting:bossSource'].label:GetText()=='DBM')
env.click('tab:profiles');env.click('tab:settings');assert(ns.UIControls['setting:iconSize']:GetText()=='57');assert(ns.UIControls['setting:voiceOn'].value)
ns.WorkspaceWindow:Hide();ns.Open();assert(ns.UIControls['setting:x']:GetText()=='125');env.click('save-settings')
assert(ns.Settings().iconSize==57 and ns.Settings().pos.x==125 and ns.Settings().voiceOn and ns.Settings().bossSource=='dbm')
`));
test('scroll viewports keep their visible anchored content through repeated page changes',()=>run(`
for i=1,8 do
 for _,tab in ipairs({'mythic','raid','profiles','settings'})do
  env.click('tab:'..tab);env.assertLayout()
  if tab=='mythic'or tab=='raid'then
   env.click('mode:sets');env.assertLayout();env.click('mode:mechanics');env.assertLayout()
  end
 end
end
`));
test('mechanic drafts keep exact inputs per ability, specialization and difficulty, and save after returning',()=>run(`
local preset=assert(ns.SaveSet('mythic',104,nil,'Personal',{{spellID=22812,enabled=true}}))
env.select('group','Murder Row');env.click('entity:236071');env.click('ability:1216529')
env.input('rule:name','My trash shield');env.select('rule:preset','Personal');env.input('rule:leadTime','3.5')
env.input('rule:text','Shield now');env.input('rule:duration','6')
env.click('tab:raid');env.click('tab:mythic');assert(ns.UIState.entity==236071 and ns.UIState.ability==1216529)
assert(ns.UIControls['rule:text']:GetText()=='Shield now');assert(ns.UIControls['rule:name']:GetText()=='My trash shield')
env.spec=105;ns.Open();env.click('mode:sets');env.input('set-name','Restoration draft')
env.spec=104;ns.Open();assert(ns.UIState.mode=='mechanics');assert(ns.UIControls['rule:leadTime']:GetText()=='3.5')
env.click('save-rule');local key=ns.UIState.ruleKey;local e=ns.Get(ns.Active().data.integrationRules,104)[key]
assert(e.name=='My trash shield'and e.preset==preset and e.trigger.timeleft==3.5 and e.display.text=='Shield now')
env.click('tab:raid');env.click('new-timed');env.input('rule:name','Heroic draft');env.input('rule:delay','45');env.click('difficulty:16')
env.click('new-timed');env.input('rule:name','Mythic draft');env.click('difficulty:15');env.click('new-timed');assert(ns.UIControls['rule:name']:GetText()=='Heroic draft')
env.click('difficulty:16');env.click('new-timed');assert(ns.UIControls['rule:name']:GetText()=='Mythic draft')
`));
test('drafts and navigation survive a fresh addon load, remain profile-local and stay outside exports',()=>run(`
env.click('mode:sets');env.input('set-name','Not active yet');env.input('new-spell','22812');env.click('add-spell')
env.reload();assert(ns.UIState.mode=='sets');assert(ns.UIControls['set-name']:GetText()=='Not active yet');assert(#ns.UIState.setRows==1)
assert(next(ns.ScopePresets(ns.Active(),'mythic',104))==nil)
env.click('save-set');local saved=ns.UIState.setKey;env.click('tab:profiles');env.input('profile-name','Other');env.click('profile-create')
env.click('mode:sets');assert(ns.UIControls['set-name']:GetText()~='Not active yet');env.input('set-name','Other draft')
env.click('tab:profiles');env.select('profile-select','Default');env.click('tab:mythic');assert(ns.UIState.mode=='sets');assert(ns.UIState.setKey==saved)
env.reload();assert(ns.ScopePresets(ns.Active(),'mythic',104)[saved].name=='Not active yet')
env.click('tab:profiles');env.click('profile-export');local output=ns.UIControls['profile-string']:GetText()
if ns.DecodeImport then
 -- The native codec is available in the Lua 5.1 run. Portable codec fixtures
 -- deliberately do not implement decoding.
 local lib=LibStub('LibSerialize')
 if lib.Deserialize then local p=assert(ns.Decode(output));assert(not p.workspace and not p.data.workspace);env.input('profile-string',output);env.click('profile-import');assert(ns.ScopePresets(ns.Active(),'mythic',104)[saved].name=='Not active yet')end
end
`));
test('every specialization of every class keeps independent M+ and raid set editors',()=>run(`
local ids={};for id in pairs(ns.Catalog.specs)do ids[#ids+1]=id end;table.sort(ids);assert(#ids==40)
for _,id in ipairs(ids)do
 env.spec=id;env.class=ns.SpecClass(id);ns.Open();env.click('tab:mythic');env.click('mode:sets')
 env.input('set-name','Dungeon '..id);env.input('new-spell','22812');env.click('add-spell');env.click('save-set')
 env.click('tab:raid');env.click('mode:sets');env.input('set-name','Raid '..id);env.input('new-spell','61336');env.click('add-spell');env.click('save-set')
end
env.reload()
for _,id in ipairs(ids)do
 env.spec=id;env.class=ns.SpecClass(id);ns.Open();env.click('tab:mythic');assert(ns.UIControls['set-name']:GetText()=='Dungeon '..id)
 env.click('tab:raid');assert(ns.UIControls['set-name']:GetText()=='Raid '..id)
 local _,m=next(ns.ScopePresets(ns.Active(),'mythic',id));local _,r=next(ns.ScopePresets(ns.Active(),'raid',id));assert(m.list[1]==22812 and r.list[1]==61336)
end
`));
test('client workspaces, profile rename and manual encounter drafts retain the correct context',()=>run(`
env.click('mode:sets');env.input('set-name','Retail draft');env.click('tab:profiles');env.input('profile-name','Renamed');env.click('profile-rename')
env.click('tab:mythic');assert(ns.UIControls['set-name']:GetText()=='Retail draft')
env.version='1.60.1';ns.Open();env.click('add-mechanic');env.input('manual:groupName','Forever dungeon');env.input('manual:npcName','Forever boss')
env.click('tab:raid');env.click('tab:mythic');assert(ns.UIControls['manual:groupName']:GetText()=='Forever dungeon');assert(ns.UIControls['manual:npcName']:GetText()=='Forever boss')
env.reload();assert(ns.UIControls['manual:groupName']:GetText()=='Forever dungeon')
env.version='12.1.5';ns.Open();assert(ns.Active().name=='Renamed');assert(ns.UIControls['set-name']:GetText()=='Retail draft')
`));
test('a failed save preserves the draft and viewport offset survives navigation',()=>run(`
env.click('mode:sets');env.input('set-name','');env.input('new-spell','22812');env.click('add-spell');env.click('save-set')
assert(ns.UIState.error);assert(#ns.UIState.setRows==1);assert(next(ns.ScopePresets(ns.Active(),'mythic',104))==nil)
env.click('tab:profiles');env.click('tab:mythic');assert(ns.UIControls['set-name']:GetText()=='');assert(#ns.UIState.setRows==1)
env.input('set-name','Recovered');env.click('save-set');assert(not ns.UIState.error)
env.click('tab:raid');env.click('new-timed');env.select('rule:trigger','Time from phase')
ns.UIScrolls['inspector']:SetVerticalScroll(40);env.click('tab:settings');env.click('tab:raid')
assert(ns.UIScrolls['inspector']:GetVerticalScroll()==40);env.assertLayout()
`));
test('all workspace pages and multiline inputs supply the flags required by EditBox:SetFont',()=>run(`
local bad=CreateFrame('EditBox',nil,UIParent);local ok,error=pcall(bad.SetFont,bad,'Fonts/FRIZQT__.TTF',12);assert(not ok and error:find("bad argument #3"))
for _,version in ipairs({'12.1.5','1.60.1'})do
 env.version=version;ns.Open()
 for _,tab in ipairs({'mythic','raid','profiles','settings'})do
  env.click('tab:'..tab)
  for _,frame in ipairs(env.frames)do if frame.kind=='EditBox'and frame~=bad then assert(type(frame.fontFlags)=='string','EditBox font flags are missing')end end
 end
 local input=ns.Widgets.Input(UIParent,'first\\nsecond',0,0,300,'multiline-font-test',true);assert(input.fontFlags=='')
end
`));
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
test('saved mechanic bindings dispatch the correct content-scoped set and trash rules fire in every dungeon difficulty',()=>run(`
local m=assert(ns.SaveSet('mythic',104,nil,'Dungeon set',{{spellID=22812,enabled=true}}));local r=assert(ns.SaveSet('raid',104,nil,'Raid set',{{spellID=61336,enabled=true}}))
local ctx={scope='mythic',spec=104,map=2813,npc=236071,group=2813,kind='trash',spell=1216529,difficulty=8}
local key=assert(ns.SaveRule(ctx,{name='Shield Bash defensive',action='defensive',preset=m,leadTime=2,duration=4}));ns.map=2813;ns.difficulty=8;ns.instanceType='party';ns.Trash(1216529,5,'cast');env.advance(3);assert(#env.shown==1 and env.shown[1].spellID==22812 and env.shown[1].text=='Barkskin')
ns.difficulty=2;ns.Trash(1216529,5,'heroic');env.advance(3);assert(#env.shown==2 and env.shown[2].spellID==22812)
ns.difficulty=23;ns.Trash(1216529,5,'mythic0');env.advance(3);assert(#env.shown==3)
ns.difficulty=16;ns.instanceType='raid';ns.Trash(1216529,5,'raid');env.advance(3);assert(#env.shown==3,'Dungeon trash must not fire in a raid')
ns.RenderDefensive({defensive={specID=104,preset=r,scope='raid'},display={}});assert(env.shown[4].spellID==61336 and env.shown[4].text=='Survival Instincts')
local result,error=ns.DeleteSet('mythic',104,m);assert(not result and error:find('assigned'))
`));
test('raid UI authors pull and phase reminders, preserves recipients and exports the edited profile',()=>run(`
env.click('tab:raid');env.select('group','Midnight · Season 2');env.click('new-timed');env.input('rule:name','Raid movement');env.input('rule:delay','10');env.input('rule:text','Move now');env.select('rule:recipient','Role');env.select('rule:role','Tank');env.click('save-rule')
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
assert(NaowhDefensivePlannerDB.clients.retail.profiles.Default and NaowhDefensivePlannerDB.clients.forever.profiles.Forever)
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

test('search narrows encounters and mechanics, and counts follow saved reminders',()=>run(`
local set=assert(ns.SaveSet('mythic',104,nil,'Personal',{{spellID=22812,enabled=true}}))
env.select('group','Murder Row');env.click('entity:236071');env.click('ability:1216529');env.select('rule:preset','Personal');env.click('save-rule')
local group=ns.UIState.group;env.click('tab:overview');env.assertLayout();assert(ns.UIControls['tab:mythic'],'Sidebar is missing Mythic+')
env.click('overview:mythic:'..group);assert(ns.UIState.tab=='mythic'and ns.UIState.mode=='mechanics')
local search=ns.UIControls.search;search:SetText('Blood Sacrifice');search.scripts.OnEnterPressed(search)
assert(ns.UIState.filter=='Blood Sacrifice');assert(ns.UIControls['ability:1306517'],'Search hit is missing');assert(not ns.UIControls['entity:236071'],'Non-matching encounter is still listed')
env.click('search-clear');assert(ns.UIState.filter=='');env.select('group','Murder Row');assert(ns.UIControls['entity:236071'])
`));
test('suggested defensives add to the set and a spec setup copies onto another specialization',()=>run(`
env.click('mode:sets');env.input('set-name','Copied set');env.click('suggest:22812');assert(#ns.UIState.setRows==1 and ns.UIState.setRows[1].spellID==22812)
assert(not ns.UIControls['suggest:22812'],'A spell already in the set is still suggested');env.click('save-set');local key=ns.UIState.setKey
local ctx={scope='mythic',spec=104,encounter=3456,npc=259445,kind='boss',spell=1296050,difficulty=8}
assert(ns.SaveRule(ctx,{name='Boss defensive',action='defensive',preset=key,trigger='bwmsg',delay=0,leadTime=0,duration=4}))
env.select('copy-spec','Copy setup to Restoration Druid');env.click('copy-spec-confirm')
assert(ns.ScopePresets(ns.Active(),'mythic',105)[key].name=='Copied set');local copies=0
for _,e in pairs(ns.Get(ns.Active().data.raidReminders,3456))do if e.defensive and e.defensive.specID==105 then copies=copies+1 end end;assert(copies==1)
env.select('copy-spec','Copy setup to Restoration Druid');env.click('copy-spec-confirm');copies=0
for _,e in pairs(ns.Get(ns.Active().data.raidReminders,3456))do if e.defensive and e.defensive.specID==105 then copies=copies+1 end end;assert(copies==1,'Copying twice duplicated reminders')
assert(ns.SetUses('mythic',104,key)==1 and ns.SetUses('mythic',105,key)==1 and ns.SetUses('raid',104,key)==0)
`));

test('the window shows only the current specialization and refuses edits for another class',()=>run(`
assert(not ns.UIControls.specialization,'A spec picker is still shown')
assert(ns.SpecClass(104)=='DRUID' and ns.SpecClass(62)=='MAGE' and ns.SpecClass(250)=='DEATHKNIGHT')
local ok,error=ns.SaveSet('mythic',62,nil,'Mage set',{{spellID=45438,enabled=true}});assert(not ok and error:find('another class'))
assert(ns.SaveSet('mythic',105,nil,'Resto set',{{spellID=22812,enabled=true}}))
env.click('mode:sets');env.click('copy-spec');for _,r in ipairs(ns.Widgets.menu.rows)do if r.shown then assert(r.label.text:find('Druid'),'Copy offers another class: '..r.label.text)end end
env.spec=105;for i=#env.frames,1,-1 do local f=env.frames[i];if f.events.PLAYER_SPECIALIZATION_CHANGED then f.scripts.OnEvent(f,'PLAYER_SPECIALIZATION_CHANGED','player');break end end
assert(ns.UIState.spec==105,'Window did not follow the spec change')
env.class='MAGE';env.spec=62;ns.Open();assert(ns.UIState.spec==62);assert(ns.SaveSet('mythic',62,nil,'Mage set',{{spellID=45438,enabled=true}}))
`));
test('every sidebar section draws with visible, anchored controls',()=>run(`
for _,tab in ipairs({'overview','mythic','raid','timeline','notes','raidtools','players','profiles','settings','diag'})do
 env.click('tab:'..tab);env.assertLayout();assert(ns.UIState.tab==tab)
end
env.click('tab:raid');env.click('mode:sets');env.input('set-name','Raid from Defensives');env.input('new-spell','22812');env.click('add-spell');env.click('save-set')
assert(next(ns.ScopePresets(ns.Active(),'raid',104)))
env.click('tab:timeline');env.click('tl-new');assert(ns.UIState.tab=='raid'and ns.UIState.timed)
for _,old in ipairs({'alerts','assign','display','sets'})do assert(ns.UIControls['tab:'..old]==nil,old..' must not be a sidebar section')end
env.click('top:display');assert(ns.AnchorsUnlocked());env.click('top:display');assert(not ns.AnchorsUnlocked());env.click('header-profile');assert(ns.UIState.tab=='profiles')
env.click('tab:settings');env.select('ui:theme','Logo blue');assert(ns.UIPrefs().theme=='logo')
`));
test('/ndp opens sections and old slash aliases keep working',()=>run(`
assert(SLASH_NDP1=='/ndp' and SLASH_NDP2=='/nwhdp' and SLASH_NDP4=='/pztkr')
SlashCmdList.NDP('notes');assert(ns.UIState.tab=='notes')
SlashCmdList.NDP('tl');assert(ns.UIState.tab=='timeline')
SlashCmdList.NDP('');assert(not ns.WorkspaceWindow:IsShown());SlashCmdList.NDP('');assert(ns.WorkspaceWindow:IsShown())
SlashCmdList.NDP('wipe confirm');assert(NaowhDefensivePlannerDB,'wipe ran without the first confirmation step')
`));
