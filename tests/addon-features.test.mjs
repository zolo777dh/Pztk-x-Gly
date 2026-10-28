import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';import {execFileSync} from 'node:child_process';import fengari from 'fengari';
const root=path.resolve('addon/NaowhDefensivePlanner'),files=['Runtime','Locale','Catalog','Codec','Profiles','Display','RuleRuntime','AuraSounds','Providers','BossTimers','BossTimerData','Journal','LogTimelines','Simulate','Planner','Triggers','Analysis','Trace','Editor','Import','Widgets','UI','Comms','Debuffs','Notes','Players','RaidTools','QoL','Combat','PartyCooldowns','Main'],sources=await Promise.all(files.map(f=>fs.readFile(root+'/'+f+'.lua','utf8'))),harness=await fs.readFile('tests/helpers/wow-workspace.lua','utf8');
// A recorded Heroic pull of the first raid boss, for the Timeline tests.
const pulled=`ns.Store().timelines={['retail:3379:15']={events={{8,1260837},{18,1257717},{25,1276710},{37,1313393},{41,1260837},{44,1276710},{50,1257717},{60,1268562}},length=480,kill=true}};if ns.RefreshWorkspace then ns.RefreshWorkspace()end`;
async function run(body){const script=`local env=(function()\n${harness}\nend)()\n`+(process.env.DOCTOR_LUA51?`strmatch=string.match;dofile(${JSON.stringify(root+'/Libs/LibStub.lua')});dofile(${JSON.stringify(root+'/Libs/LibSerialize.lua')});dofile(${JSON.stringify(root+'/Libs/LibDeflate.lua')})`:`local libs={};function LibStub(key)return libs[key]end;libs.LibSerialize={Serialize=function(_,p)return p.name end};libs.LibDeflate={CompressDeflate=function(_,s)return s end,EncodeForPrint=function(_,s)return s end}`)+`\nlocal function boot()local ns={}\n`+sources.map(s=>`;(function(...)\n${s}\nend)('NaowhDefensivePlanner',ns)`).join('\n')+`\nreturn ns end;local ns=boot();ns.Open();ns.RealDisplay=ns.Display;ns.Display=function(d)env.shown[#env.shown+1]=d end\nfunction env.reload()for i=#env.frames,1,-1 do local f=env.frames[i];if f.events.PLAYER_LOGOUT then f.scripts.OnEvent(f,'PLAYER_LOGOUT');break end end;ns.WorkspaceWindow:SetScript('OnHide',nil);ns.WorkspaceWindow:Hide();local lib=LibStub('LibSerialize');if lib.Deserialize then local ok,db=lib:Deserialize(lib:Serialize(NaowhDefensivePlannerDB));assert(ok);NaowhDefensivePlannerDB=db else NaowhDefensivePlannerDB=ns.Clone(NaowhDefensivePlannerDB)end;ns=boot();ns.Open();ns.Display=function(d)env.shown[#env.shown+1]=d end end\n${body}`;
 if(process.env.DOCTOR_LUA51){const d=await fs.mkdtemp(path.join(os.tmpdir(),'pztk-workspace-'));try{await fs.writeFile(d+'/test.lua',script);execFileSync(process.env.DOCTOR_LUA51,[d+'/test.lua'],{encoding:'utf8'});}finally{await fs.rm(d,{recursive:true,force:true});}return;}
 const {lua,lauxlib,lualib,to_luastring}=fengari,L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);try{if(lauxlib.luaL_loadstring(L,to_luastring(script))!==lua.LUA_OK||lua.lua_pcall(L,0,0,0)!==lua.LUA_OK)throw Error(lua.lua_tojsstring(L,-1));}finally{lua.lua_close(L);}
}

test('a defensive call-out keeps its own screen text, spoken phrase or sound, and the external step its phrase and chat line',()=>run(`
local spoken={};C_VoiceChat={GetTtsVoices=function()return{{voiceID=1}}end,SpeakText=function(_,text)spoken[#spoken+1]=text end}
env.click('tab:mythic');env.click('mode:sets');env.input('set-name','Bear');env.input('new-spell','22812');env.click('add-spell');env.input('new-spell','61336');env.click('add-spell');env.click('save-set')
env.click('set-callout:1');env.input('callout:label','BARK');env.input('callout:spoken','bark now');env.click('callout-hear');assert(spoken[#spoken]=='bark now')
env.click('callout-save');local data=ns.Active().data;assert(data.calloutOptions[22812].label=='BARK'and data.callouts[22812]=='bark now')
local label,phrase,audio=ns.Callout(22812);assert(label=='BARK'and phrase=='bark now'and audio)
env.click('set-callout:2');env.click('callout:speak');env.select('callout:sound','Say: Move out');env.click('callout:audio');env.click('callout:audio');env.click('callout-save')
local _,phrase2,_,sound=ns.Callout(61336);assert(phrase2==nil and sound=='voice:move-out')
env.click('set-callout:1');env.click('callout:audio');env.click('callout-save');assert(ns.Active().data.calloutOptions[22812].audio==false)
env.click('set-callout:2');env.click('callout-cancel');assert(ns.UIState.callout==nil)
env.click('set-external');env.input('callout:text','Need a pain sup');env.click('callout:chat');env.click('callout-save')
local s=ns.Settings();assert(ns.Active().data.voiceNone=='Need a pain sup'and s.externalChat==true)
env.click('set-external-on');assert(ns.Settings().fallbackOn==true)
-- Edited text drives the real reminder: label on screen, no voice for the muted ability, the sound of the second.
ns.Display=function(d)env.shown[#env.shown+1]=d end
local set=next(ns.ScopePresets(ns.Active(),'mythic',104));ns.RenderDefensive({defensive={specID=104,preset=set,scope='mythic'},content='mythic'})
local shown=env.shown[#env.shown];assert(shown.text:find('BARK',1,true),shown.text)
`));
test('debuff alerts: racial lists, editing, on/off, removal and copy between own specs',()=>run(`
env.click('tab:mythic');env.click('mode:debuffs');assert(ns.UIState.tab=='mythic'and ns.UIState.mode=='debuffs');env.click('debuffs-racial')
local menu=ns.Widgets.menu;for _,r in ipairs(menu.rows)do if r.shown and r.label.text:find('Stoneform',1,true)then r:Click()break end end
local rules=ns.DebuffRules(104);assert(#rules>=30,#rules)
for _,r in ipairs(rules)do assert(r.rule.display.sound=='voice:stoneform-ready'and r.rule.trigger.target=='player'and r.rule.trigger.mapID>0)end
local before=#rules;assert(ns.AddRacialDebuffs(104,'stoneform')==0);assert(#ns.DebuffRules(104)==before)
assert(ns.AddRacialDebuffs(104,'shadowmeld')>=4)
local key=rules[1].key;env.click('debuff:'..key);env.input('debuff:name','Renamed');env.select('debuff:event','Removed');env.click('debuff-save')
local r=ns.Active().data.integrationRules[104][key];assert(r.name=='Renamed'and r.trigger.auraEvent=='Removed')
env.click('debuff-on:'..key);assert(ns.Active().data.integrationRules[104][key].enabled==false)
env.click('debuff:'..key);env.click('debuff-delete');assert(ns.Active().data.integrationRules[104][key]==nil)
env.click('debuff-new');env.input('debuff:spellID','1217633');env.select('debuff:unit','Party members');env.select('debuff:sound','Encounter warning: low');env.select('debuff:map','Another instance (by ID)');env.input('debuff:mapID','0');env.click('debuff-save')
local found=false;for _,x in ipairs(ns.DebuffRules(104))do if x.rule.trigger.spellID==1217633 and x.rule.trigger.target=='party'and x.rule.trigger.mapID==0 then found=true end end;assert(found)
env.click('debuff-new');env.input('debuff:spellID','1217633');env.select('debuff:sound','Stoneform alert (only when ready)');env.select('debuff:unit','Party members');assert(ns.UIState.drafts.debuff.sound=='voice:use-a-defensive')
env.click('debuff-test')
assert(ns.CopyDebuffRules(104,105)>0);assert(#ns.DebuffRules(105)>0)
assert(not ns.CopyDebuffRules(104,71),'copy to another class must fail')
`));
test('notes: library, load and send, personal note, assignments from lines that name you, and received notes',()=>run(`
env.click('tab:notes');env.click('note-new');env.input('note:name','Boss plan');env.input('note:text','Soak 1: Tester Other\\nKick: Someone');env.click('note-save')
local n=ns.Notes();local id=next(n.shared);assert(n.shared[id].name=='Boss plan')
env.click('note-load');assert(n.live and n.live.name=='Boss plan')
local lines=ns.MyNoteLines();assert(#lines==1 and lines[1]:find('Soak 1',1,true))
env.click('assign-test');assert(env.shown[#env.shown].text:find('Soak 1',1,true))
env.click('tab:notes');env.click('note-show');assert(n.cfg.show==true);env.click('note-unlock');assert(n.cfg.unlocked==true);env.click('note-outside');env.click('note-assign');assert(n.cfg.assignOnPull==false)
env.click('note-unload');assert(n.live==nil)
env.click('note-kind:personal');env.click('note-new');env.input('note:name','Mine');env.input('note:text','Tester: wall at 1:30');env.click('note-load')
local pid=next(n.personal);assert(n.activePersonal==pid)
env.click('note:'..pid);env.click('note-delete');env.click('note-delete');assert(n.personal[pid]==nil and n.activePersonal==nil)
-- A shared note from the group leader replaces the active one; anyone else is ignored.
ns.GroupAuthority=function(name)return name=='Leader'end
ns.CommHandlers.NOTE('Sent\\nTester soaks','Random');assert(n.live==nil)
ns.CommHandlers.NOTE('Sent\\nTester soaks','Leader');assert(n.live.name=='Sent'and n.live.received)
env.click('note-kind:shared');env.click('note-received');env.click('note-save');local count=0;for _ in pairs(n.shared)do count=count+1 end;assert(count==2)
ns.CommHandlers.NOTECLR('','Leader');assert(n.live==nil)
ns.Command('note');ns.Command('clear');ns.Command('pclear')
`));
test('players and raid tools: nicknames, version answers, break timer, invites and assistants settings',()=>run(`
env.click('tab:players');env.input('players:nick','Bear');env.click('players-nick');assert(ns.MyNickname()=='Bear')
env.input('players:newName','Friend');env.input('players:newNick','Fr');env.click('players-add');assert(ns.Nickname('Friend')=='Fr')
env.click('players-del:Friend');assert(ns.Nickname('Friend')==nil)
ns.SetNickname('A','a');env.click('players-wipe');env.click('players-wipe');assert(next(ns.PlayersData().nicknames)==nil)
env.click('players-share');env.click('players-accept');assert(ns.PlayersData().accept==false)
ns.CommHandlers.NICK('Nope','Other');assert(ns.Nickname('Other')==nil)
env.click('players-check');assert(ns.PlayersData().versions.Tester==ns.version)
ns.CommHandlers.VER('0.6.0','Mate');assert(ns.PlayersData().versions.Mate=='0.6.0')
env.click('tab:raidtools');env.input('rt:breakMin','7');env.click('rt-break');assert(ns.BreakRemaining()>400)
env.click('rt-break-cancel');assert(ns.BreakRemaining()==nil)
env.input('rt:keywords','inv, 123');env.click('rt-keywords-save');assert(ns.RaidToolsConfig().keywords=='inv, 123')
env.click('rt-autoinv');assert(ns.RaidToolsConfig().autoInvite==true)
env.select('rt-rank','Up to rank 3');assert(ns.RaidToolsConfig().rank==2)
env.input('rt:promote','Friend, Fr');env.click('rt-promote-save');assert(ns.RaidToolsConfig().promote=='Friend, Fr')
env.click('rt-autopromote');env.click('rt-guildonly');env.click('rt-break-announce')
local ok,err=ns.ArrangeGroups();assert(not ok and err:find('raid',1,true))
ns.Command('break 0');ns.Command('arrange');ns.Command('inv');ns.Command('versions');assert(ns.UIState.tab=='players')
`));
test('mouse wheel scrolls a list from anywhere over it, including its buttons and long text boxes',()=>run(`
for i=1,30 do assert(ns.SaveNote('shared',nil,{name='Note '..i,text='x'}))end
env.click('tab:notes');local s=ns.UIScrolls['notes:list'];s.GetVerticalScrollRange=function()return 900 end
local row;for k,c in pairs(ns.UIControls)do if k:match('^note:note_')then row=c;break end end
assert(row.scripts.OnMouseWheel,'list buttons pass the wheel on');row.scripts.OnMouseWheel(row,-1);assert(s:GetVerticalScroll()==48)
row.scripts.OnMouseWheel(row,1);assert(s:GetVerticalScroll()==0)
env.click('note-new');local text=ns.UIControls['note:text'];assert(text.scripts.OnMouseWheel,'note text scrolls with the wheel')
env.click('tab:overview');local b=ns.UIControls['overview:go:settings'];assert(not b.scripts.OnMouseWheel)
`));
test('every control on every page responds when clicked',()=>run(`
local calls=0
local function count()calls=calls+1 end
DoReadyCheck=count;C_PartyInfo={DoCountdown=count,InviteUnit=count,ConvertToRaid=count}
C_VoiceChat={GetTtsVoices=function()return{{voiceID=1}}end,SpeakText=count}
PlaySoundFile=count;print=count
local function dump(v,seen,depth)
 seen=seen or{};depth=depth or 0
 if type(v)~='table'then return type(v)=='function'and'f'or tostring(v)end
 if seen[v]or depth>12 then return'@'end;seen[v]=true
 local keys={};for k in pairs(v)do if k~='scrolls'and k~='workspace'and k~='views'then keys[#keys+1]=k end end
 table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local out={};for _,k in ipairs(keys)do out[#out+1]=tostring(k)..'='..dump(v[k],seen,depth+1)end
 return'{'..table.concat(out,',')..'}'
end
local function fingerprint()
 local popup=ns.Widgets.popup;return dump(NaowhDefensivePlannerDB)..'|'..dump(ns.UIState)..'|'..tostring(popup and popup.shown)..'|'..#env.shown..'|'..calls..'|'..tostring(ns.WorkspaceWindow.shown)
end
-- Content on every page: sets, reminders, debuffs, notes, nicknames.
assert(ns.SaveSet('mythic',104,nil,'Magic',{{spellID=22812},{spellID=61336}}));assert(ns.SaveSet('raid',104,nil,'Raid',{{spellID=22812}}))
env.click('tab:raid');env.click('new-timed');env.input('rule:name','Pull wall');env.input('rule:delay','20');env.click('save-rule')
assert(ns.AddRacialDebuffs(104,'stoneform'));assert(ns.AddRacialDebuffs(104,'stoneform','raid'))
assert(ns.SaveNote('shared',nil,{name='Plan',text='Soak 1: Tester'}));assert(ns.SetNickname('Friend','Fr'))
local tabs={'overview','mythic','raid','timeline','mythic/sets','raid/sets','mythic/debuffs','raid/debuffs','notes','raidtools','players','qol','combat','profiles','settings','diag'}
local dead,errors,total={},{},0
-- 'mythic/debuffs' opens the Mythic+ section on its Debuffs switch; plain 'mythic' on Mechanics.
local function open(tab)local t,m=tab:match('^(%w+)/?(%w*)$');env.click('tab:'..t);if t=='mythic'or t=='raid'then local c=ns.UIControls['mode:'..(m~=''and m or'mechanics')];if c then c:Click()end end end
for pass=1,2 do for _,tab in ipairs(tabs)do
 if not ns.WorkspaceWindow.shown then ns.Open()end
 open(tab)
 local keys={}
 for k,c in pairs(ns.UIControls)do if c.scripts and c.scripts.OnClick and not k:match('^tab:')and k~='close'then keys[#keys+1]=k end end
 table.sort(keys)
 for _,k in ipairs(keys)do
  if not ns.WorkspaceWindow.shown then ns.Open()end
  open(tab)
  local c=ns.UIControls[k]
  if c then
   total=total+1;ns.UIState.message='__x'
   local before=fingerprint()
   local ok,err=pcall(function()c:Click()end)
   if not ok then errors[#errors+1]=tab..' '..k..': '..tostring(err)
   elseif fingerprint()==before then dead[#dead+1]=tab..' '..k end
   if ns.Widgets.popup then ns.Widgets.popup:Hide()end
  end
 end
end end
assert(#errors==0,'Controls raised errors:\\n'..table.concat(errors,'\\n'))
-- Controls that legitimately change nothing when clicked in the state they are already in.
local same={['top:timeline']=1,['tl-thumb']=1,['profile-import-mode:copy']=1,['tl-view:all']=1,['top:display']=1,['header-profile']=1,['top:roster']=1,['debuff-new']=1,['mode:mechanics']=1,['mode:sets']=1,['mode:debuffs']=1,['display-anchor']=1}
local unexplained={}
for _,line in ipairs(dead)do local key=line:match(' (.+)$');local chosen=key:match(':%d+$')or key:match('scope:')or key:match('^ability:')or key:match('^entity:')or key:match('^set:')or key:match('^note:')or key:match('^debuff:')or key:match('^timed:')
 if not same[key]and not chosen then unexplained[#unexplained+1]=line end end
assert(#unexplained==0,'Controls with no effect:\\n'..table.concat(unexplained,'\\n'))
assert(total>250,'Audit clicked only '..total..' controls')
`));
test('debuffs sit in Mythic+ and Raids, raids get their own racial list, /ndp debuffs opens them',()=>run(`
env.click('tab:raid');env.click('mode:debuffs');assert(ns.UIState.tab=='raid'and ns.UIState.mode=='debuffs')
assert(ns.UIControls['tab:debuffs']==nil,'Debuffs must not be a sidebar section')
ns.UIControls['debuffs-racial']:Click();for _,r in ipairs(ns.Widgets.menu.rows)do if r.shown and r.label.text:find('Stoneform',1,true)then r:Click()break end end
local raid,mythic=0,0;for _,r in ipairs(ns.DebuffRules(104))do if r.rule.trigger.scope=='raid'then raid=raid+1;assert(r.rule.trigger.mapID==0)else mythic=mythic+1 end end
assert(raid==8 and mythic==0,raid..' '..mythic)
local found=false;for k in pairs(ns.UIControls)do if k:match('^debuff%-group:Vashnik')then found=true end end;assert(found,'Raid alerts are grouped by boss')
env.click('debuff-new');env.input('debuff:spellID','1290336');env.click('debuff-save')
local saved;for _,r in ipairs(ns.DebuffRules(104))do if r.rule.trigger.spellID==1290336 then saved=r end end;assert(saved and saved.rule.trigger.scope=='raid')
env.click('tab:mythic');env.click('mode:debuffs');for k in pairs(ns.UIControls)do assert(not k:match('^debuff%-group:Vashnik'),'Raid alerts leaked into Mythic+')end
env.reload();assert(#ns.DebuffRules(104)>=9,'Raid debuff alerts did not survive a reload')
ns.WorkspaceWindow:Hide();SlashCmdList.NDP('debuffs');assert(ns.UIState.mode=='debuffs')
`));
test('an open list closes on a click anywhere outside it',()=>run(`
env.click('tab:settings');ns.UIControls['ui:theme']:Click()
local menu=ns.Widgets.menu;assert(menu.shown and menu.catcher.shown)
menu.catcher.scripts.OnMouseDown(menu.catcher,'LeftButton')
assert(not menu.shown and not menu.catcher.shown,'The list stayed open')
ns.UIControls['ui:theme']:Click();assert(menu.shown);menu.rows[1]:Click();assert(not menu.catcher.shown)
`));
test('Test set speaks the chosen ability, not a set preview line',()=>run(`
local spoken={};C_VoiceChat={GetTtsVoices=function()return{{voiceID=1}}end,SpeakText=function(_,text)spoken[#spoken+1]=text end}
env.click('tab:mythic');env.click('mode:sets');env.input('set-name','Bear');env.input('new-spell','22812');env.click('add-spell');env.click('save-set')
local n=#env.shown;env.click('test-set');local d=env.shown[#env.shown];assert(#env.shown==n+1)
assert(not d.text:find('preview',1,true),d.text);assert(d.text==ns.SpellLabel(22812),d.text);assert(d.tts~=false and d.ttsText==ns.SpellLabel(22812),tostring(d.tts)..' '..tostring(d.ttsText))
env.click('set-callout:1');env.input('callout:spoken','bark now');env.click('callout-save');env.click('test-set');assert(env.shown[#env.shown].ttsText=='bark now')
`));
test('a spell dragged from the spellbook onto the set is added to it',()=>run(`
env.click('tab:mythic');env.click('mode:sets');env.input('set-name','Drag')
local targets={};for _,f in ipairs(env.frames)do if f.dropTarget and f:IsVisible()then targets[#targets+1]=f end end;assert(#targets>=3,#targets)
local cursor;GetCursorInfo=function()if cursor then return unpack(cursor)end end;ClearCursor=function()cursor=nil end
cursor={'spell',12,'spell',22812};targets[1].scripts.OnReceiveDrag(targets[1]);assert(cursor==nil and #ns.UIState.setRows==1 and ns.UIState.setRows[1].spellID==22812)
assert(ns.UIControls['set-name']:GetText()=='Drag','The set name draft was lost')
-- Older clients give only the spellbook slot: the ID comes from the spellbook.
Enum=Enum or{};Enum.SpellBookSpellBank={Player=0,Pet=1};C_SpellBook=C_SpellBook or{};C_SpellBook.GetSpellBookItemInfo=function(i,bank)if i==7 and bank==0 then return{spellID=61336}end end
local t;for _,f in ipairs(env.frames)do if f.dropTarget and f:IsVisible()then t=f end end
cursor={'spell',7,'spell'};t.scripts.OnMouseUp(t,'LeftButton');assert(#ns.UIState.setRows==2 and ns.UIState.setRows[2].spellID==61336)
cursor={'spell',12,'spell',22812};t=nil;for _,f in ipairs(env.frames)do if f.dropTarget and f:IsVisible()then t=f end end;t.scripts.OnReceiveDrag(t);assert(#ns.UIState.setRows==2,'Duplicate added')
cursor={'item',5512};t=nil;for _,f in ipairs(env.frames)do if f.dropTarget and f:IsVisible()then t=f end end;t.scripts.OnReceiveDrag(t);assert(#ns.UIState.setRows==2 and ns.UIState.error)
t=nil;for _,f in ipairs(env.frames)do if f.dropTarget and f:IsVisible()then t=f end end;t.scripts.OnMouseUp(t,'LeftButton');assert(#ns.UIState.setRows==2)
env.click('save-set');local set=ns.ScopePresets(ns.Active(),'mythic',104);local _,p=next(set);assert(#p.list==2)
env.click('tab:overview');for _,f in ipairs(env.frames)do assert(not(f.dropTarget and f:IsVisible()),'Drop target left on another page')end
`));
test('dungeon reminders fire in every dungeon difficulty, raid ones keep their difficulty',()=>run(`
assert(ns.EditProfile(function(d)d.contentDifficulties={mythic={[8]=true},raid={[15]=true,[16]=true}}end))
local mplus={content='mythic',difficulties={[8]=true}}
for _,diff in ipairs({1,2,8,23,24})do ns.instanceType='party';ns.difficulty=diff;assert(ns.Difficulty(mplus)and ns.ContentMatches(mplus),'dungeon difficulty '..diff)end
ns.instanceType='party';ns.difficulty=2;assert(ns.ContentMatches({content='mythic'})and ns.Difficulty({}))
ns.instanceType='raid';ns.difficulty=15;assert(not ns.Difficulty({difficulties={[16]=true}}));assert(ns.Difficulty({difficulties={[15]=true}}));assert(not ns.Difficulty(mplus))
ns.instanceType='raid';ns.difficulty=17;assert(not ns.ContentMatches({content='raid'}),'LFR stays off by the raid filter')
`));
test('already covered: no call-out while a defensive of the set was just cast; the setting saves from the Settings page',()=>run(`
local now=100;GetTime=function()return now end
assert(ns.SaveSet('mythic',104,nil,'Bear',{{spellID=22812},{spellID=61336}}))
local set=next(ns.ScopePresets(ns.Active(),'mythic',104));local binding={defensive={specID=104,preset=set,scope='mythic'},content='mythic'}
ns.Display=function(d)env.shown[#env.shown+1]=d end
ns.NoteCast(61336);local n=#env.shown;ns.RenderDefensive(binding);assert(#env.shown==n+1,'Skip must be off by default')
env.click('tab:settings');env.click('setting:coveredSkip');env.input('setting:coveredCastWindow','5');env.click('save-settings')
local s=ns.Settings();assert(s.coveredSkip and s.coveredSkipDefaultOn and s.coveredCastWindow==5)
n=#env.shown;ns.RenderDefensive(binding);assert(#env.shown==n,'Covered call-out was not skipped')
now=106;ns.RenderDefensive(binding);assert(#env.shown==n+1,'Cast window did not expire')
C_UnitAuras={GetPlayerAuraBySpellID=function(id)if id==22812 then return{spellId=22812}end end};n=#env.shown;ns.RenderDefensive(binding);assert(#env.shown==n,'Active aura did not count')
local hidden={};C_UnitAuras={GetPlayerAuraBySpellID=function()return hidden end};issecretvalue=function(v)return v==hidden end;n=#env.shown;ns.RenderDefensive(binding);assert(#env.shown==n+1,'Hidden aura data must not skip')
issecretvalue=nil;env.input('setting:coveredCastWindow','99');env.click('save-settings');assert(ns.UIState.error)
`));
test('racial readiness events are only watched while a racial voice is registered',()=>run(`
local f;for _,x in ipairs(env.frames)do if x.events.SPELLS_CHANGED and x.events.PLAYER_DEAD then f=x end end;assert(f)
assert(not f.events.SPELL_UPDATE_COOLDOWN and not f.events.SPELL_UPDATE_USABLE,'Cooldown events must stay off with no racial voice')
`));
test('reminders grow right from a fixed left edge and the unlocked anchor is a sample icon at that spot',()=>run(`
assert(ns.EditProfile(function(d)d.settings.pos={point='CENTER',relPoint='CENTER',x=363,y=-65}end))
local x,y=ns.ReminderOrigin();assert(x==193 and y==-65,'old centered positions keep their left edge')
assert(ns.ToggleAnchors());local a,b;for _,f in ipairs(env.frames)do if f.icon and f.scripts.OnDragStop then if a then b=b or f else a=f end end end;assert(a and b)
assert(a.point.point=='LEFT'and a.point.relativePoint=='CENTER'and a.point.x==193 and a.point.y==-65,'anchor icon is not at the reminder origin')
assert(a.w==(ns.Settings().iconSize or 42)and a.w==a.h,'anchor must be one icon')
a.GetLeft=function()return 1000 end;a.GetCenter=function()return 1010,600 end;UIParent.GetCenter=function()return 960,540 end
a.scripts.OnDragStop(a);local p=ns.Settings().pos;assert(p.point=='LEFT'and p.x==40 and p.y==60)
x,y=ns.ReminderOrigin();assert(x==40 and y==60)
-- Boss ability alerts have their own anchor and stack there, apart from the reminders.
assert(b.point.x==200 and b.point.y==180,'ability anchor default')
b.GetLeft=function()return 700 end;b.GetCenter=function()return 710,740 end
b.scripts.OnDragStop(b);local q=ns.Settings().abilityPos;assert(q.x==-260 and q.y==200 and ns.Settings().pos.x==40)
assert(not ns.ToggleAnchors())
ns.RealDisplay({type='ability',spellID=1257717,text='Tank Hit',dur=5});ns.RealDisplay({type='icon',defensive=true,spellID=22812,text='Barkskin',dur=5})
local alert,plain;for _,f in ipairs(env.frames)do if f.group=='ability'and f.shown then alert=f elseif f.group=='main'and f.shown then plain=f end end
assert(alert and plain,'both shown');assert(alert.point.x==-260 and alert.point.y==200 and plain.point.x==40 and plain.point.y==60,'each stacks on its own anchor')
assert(alert.text.text=='Tank Hit'and alert.clock.shown and alert.clock.text=='(5)'and alert.icons[1].w==28,'ability alert: small icon, text and (seconds) as in NSRT')
ns.HideDisplays()
ns.RealDisplay({type='ability',style='bar',spellID=1257717,text='Tank Hit',dur=5});ns.RealDisplay({type='ability',style='text',spellID=1257717,text='Soak',dur=5})
local barAlert,textAlert;for _,f in ipairs(env.frames)do if f.group=='ability'and f.shown and f.text.text=='Soak'then textAlert=f elseif f.group=='bar'and f.shown then barAlert=f end end
assert(barAlert.bar.shown and barAlert.icons[1].shown,'bar style: icon and a timer bar')
assert(not textAlert.bar.shown and not textAlert.icons[1].shown and textAlert.clock.shown,'text style: no icon, no bar')
ns.HideDisplays()
`));

test('quality of life: notices, ready check, consumables, gateway and events only while switched on',()=>run(`
local function ticker(d,fn)local t={};local function arm()local x=C_Timer.NewTimer(d,function()if not t.cancelled then fn(t);if not t.cancelled then arm()end end end)end;function t:Cancel()self.cancelled=true end;arm();return t end;C_Timer.NewTicker=ticker
local q=ns.QoL();assert(q.textSize==22 and q.gateway==false)
local frame;for _,f in ipairs(env.frames)do if f.scripts.OnEvent and f.events and next(f.events)==nil then end end
-- Nothing is listened to while every option is off.
local function listening(event)for _,f in ipairs(env.frames)do if f.events[event]then return true end end end
assert(not listening('READY_CHECK')and not listening('MERCHANT_SHOW'))
env.click('tab:qol');env.click('qol:missingBuffs');env.click('qol:readyCheck');env.click('qol:autoRepair')
assert(q.missingBuffs and q.readyCheck and q.autoRepair and listening('READY_CHECK')and listening('MERCHANT_SHOW'))
-- Ready check: a mage is in the group and Arcane Intellect is missing; no flask, no food.
C_Spell=C_Spell or{};C_Spell.GetSpellName=function(id)return({[1459]='Arcane Intellect',[21562]='Power Word: Fortitude'})[id]end
local buffs={{name='Power Word: Fortitude',spellId=21562}}
C_UnitAuras={GetAuraDataByIndex=function(_,i)return buffs[i]end}
UnitClass=function(u)return 'Mage','MAGE'end;UnitExists=function()return true end
local p=ns.ReadyCheckProblems();local text=table.concat(p,'|')
assert(text:match('Missing: Arcane Intellect')and text:match('No flask')and text:match('Not well fed'),text)
buffs[#buffs+1]={name='Arcane Intellect',spellId=1459};buffs[#buffs+1]={name='Flask of Tests'};buffs[#buffs+1]={name='Well Fed'}
assert(#ns.ReadyCheckProblems()==0)
-- Text display lines come and go with their timers.
ns.Notice('x','Hello',2);assert(ns.NoticeText('x')=='Hello');env.advance(3);assert(ns.NoticeText('x')==nil)
-- Consumables: recognised by spell name, out of combat, while switched on.
env.click('qol:feast');assert(listening('UNIT_SPELLCAST_SUCCEEDED'))
C_Spell.GetSpellName=function(id)return id==99 and 'Hearty Feast'or nil end
for _,f in ipairs(env.frames)do if f.events.UNIT_SPELLCAST_SUCCEEDED and f.events.MERCHANT_SHOW then f.scripts.OnEvent(f,'UNIT_SPELLCAST_SUCCEEDED','party1','x',99)end end
assert(ns.NoticeText('consumable')=='Feast is down (Tester)',tostring(ns.NoticeText('consumable')))
-- Boss reset after a wipe, loot after a kill.
env.click('qol:resetBoss');env.click('qol:loot');IsInRaid=function()return true end
local busy=true;IsEncounterInProgress=function()return busy end
for _,f in ipairs(env.frames)do if f.events.ENCOUNTER_END and f.events.LOOT_OPENED then f.scripts.OnEvent(f,'ENCOUNTER_END',1,'Boss',16,20,0);assert(ns.NoticeText('reset')=='Boss is resetting');busy=false;env.advance(1);assert(ns.NoticeText('reset')=='Boss has reset')
 f.scripts.OnEvent(f,'ENCOUNTER_END',1,'Boss',16,20,1);assert(ns.NoticeText('loot')=='Loot the boss');f.scripts.OnEvent(f,'LOOT_OPENED');assert(ns.NoticeText('loot')==nil)end end
`));

test('raid tools: split and even/odd sorting balance roles, break bar options, abort',()=>run(`
local roster={}
for i=1,20 do roster[i]={name='P'..i,subgroup=1+math.floor((i-1)/5),class=i%2==0 and'WARRIOR'or'MAGE',role=i<=2 and'TANK'or i<=6 and'HEALER'or'DAMAGER'}end
GetRaidRosterInfo=function(i)local r=roster[i];if r then return r.name,0,r.subgroup,80,'',r.class,'',true end end
UnitGroupRolesAssigned=function(u)local r=roster[tonumber(u:match('%d+'))or 0];return r and r.role or'NONE'end
SetRaidSubgroup=function(i,g)roster[i].subgroup=g end
SwapRaidSubgroup=function(a,b)roster[a].subgroup,roster[b].subgroup=roster[b].subgroup,roster[a].subgroup end
IsInRaid=function()return true end;InCombatLockdown=function()return false end
ns.GroupAuthority=function()return true end
assert(ns.ArrangeGroups('evenodd'));for i=1,60 do env.advance(0.3)end
local tanks={}
for _,r in ipairs(roster)do if r.role=='TANK'then tanks[#tanks+1]=r.subgroup%2 end end
assert(tanks[1]~=tanks[2],'one tank in odd groups, one in even groups')
assert(ns.ArrangeGroups('split'));for i=1,60 do env.advance(0.3)end
local low=0;for _,r in ipairs(roster)do if r.role=='HEALER'and r.subgroup<=2 then low=low+1 end end
assert(low==2,'healers split two and two: '..low)
assert(not ns.AbortSorting());assert(not ns.ArrangeGroups('weird'))
local cfg=ns.RaidToolsConfig();assert(cfg.breakShow and cfg.breakSound)
env.click('tab:raidtools');env.click('rt-break-print');assert(cfg.breakPrint)
env.click('rt-break-unlock');assert(cfg.breakUnlocked)
`));

test('combat tools: kick rotation moves on interrupts, pace keeps the best pull',()=>run(`
local function ticker(d,fn)local t={};local function arm()local x=C_Timer.NewTimer(d,function()if not t.cancelled then fn(t);if not t.cancelled then arm()end end end)end;function t:Cancel()self.cancelled=true end;arm();return t end;C_Timer.NewTicker=ticker
local c=ns.CombatConfig()
env.click('tab:combat');env.input('kick:order','Alpha Bravo Charlie');env.click('kick-save');env.click('kick:enabled')
assert(#ns.KickOrder()==3 and ns.KickIndex()==1)
local frame;for _,f in ipairs(env.frames)do if f.events.UNIT_SPELLCAST_SUCCEEDED and f.events.PLAYER_REGEN_ENABLED and not f.events.PLAYER_LOGOUT then frame=f end end
assert(frame,'listens for interrupts only while on')
UnitName=function(u)return({raid1='Alpha',raid2='Bravo'})[u]end
frame.scripts.OnEvent(frame,'UNIT_SPELLCAST_SUCCEEDED','raid1','x',12345);assert(ns.KickIndex()==1,'not an interrupt')
frame.scripts.OnEvent(frame,'UNIT_SPELLCAST_SUCCEEDED','raid1','x',1766);assert(ns.KickIndex()==2)
frame.scripts.OnEvent(frame,'UNIT_SPELLCAST_SUCCEEDED','raid2','x',2139);assert(ns.KickIndex()==3)
frame.scripts.OnEvent(frame,'PLAYER_REGEN_ENABLED');assert(ns.KickIndex()==1)
-- The note's Kick line can replace the typed order.
ns.Notes().live={text='Soak: x\\nKick order: Delta Echo'};env.click('kick:fromNote');assert(ns.KickOrder()[1]=='Delta')
-- Pace: the best pull is kept and compared at the same sample.
env.click('pace:enabled')
local hp=100;UnitExists=function(u)return u=='boss1'end;UnitHealth=function()return hp end;UnitHealthMax=function()return 100 end
assert(ns.PaceStart(3001,16));hp=80;env.advance(5);hp=60;env.advance(5);ns.PaceEnd(false)
assert(c.pace.history['3001-16'].lowest==60)
ns.PaceStart(3001,16);hp=75;env.advance(5);assert(ns.NoticeText('pace'):match('%+5%.0%%'),ns.NoticeText('pace'));hp=70;env.advance(5);ns.PaceEnd(false)
assert(c.pace.history['3001-16'].lowest==60,'worse pull does not replace the best')
ns.PaceStart(3001,16);hp=50;env.advance(5);ns.PaceEnd(true);assert(c.pace.history['3001-16'].kill)
-- Private aura slots are handed to the game.
local anchors=0;C_UnitAuras={AddPrivateAuraAnchor=function(a)assert(a.unitToken=='player'and a.parent);anchors=anchors+1;return anchors end,RemovePrivateAuraAnchor=function()end}
env.click('auras:enabled');assert(anchors==3)
`));

test('timeline reminder tools: melee/ranged recipients, hide on use, spoken countdown, recorded boss lane, sending a plan',()=>run(`
assert(ns.SaveSet('raid',104,nil,'Raid',{{spellID=22812}}))
env.click('tab:raid');env.click('new-timed');env.input('rule:name','Spread');env.select('rule:action','Spell icon');env.input('rule:displaySpellID','22812')
env.select('rule:recipient','Melee or ranged');env.select('rule:role','Ranged');env.click('rule:hideOnUse');env.select('rule:voiceCountdown','Last 3 seconds');env.click('save-rule')
local found;for _,es in pairs(ns.Active().data.raidReminders)do for k,e in pairs(es)do if e.name=='Spread'then found=e end end end
assert(found and found.display.hideOnUse==true and found.display.voiceCountdown==3,'look saved')
assert(found.target.specs[62]and not found.target.specs[71],'ranged specs')
assert(ns.Active().minimumAddon=='0.6.7','needs 0.6.7')
-- Reopening keeps the choices.
env.click('tab:timeline');local key;for k in pairs(ns.UIControls)do if k:match('^tl%-marker:')then key=k end end;env.click(key);assert(ns.UIState.reference,'timeline marker reopens the reminder')
local f=ns.UIState.form;assert(f.recipient=='position'and f.role=='RANGED'and f.hideOnUse==true,'reopened form keeps the choices')
-- A recorded pull draws the boss lane; clicking an ability opens a reminder at its time.
local enc;for e in pairs(ns.Active().data.raidReminders)do enc=e end
ns.Store().timelines={[ns.Client()..':'..enc..':15']={events={{42,22812},{90,61336}},length=180}}
env.click('tab:timeline');assert(ns.UIControls['tl-ability:2'],'boss lane drawn');env.click('tl-ability:2')
-- The quick editor on the spot: a note shown 5 s, warned 4 s early, pinned to the time on the lane.
env.click('tl-quick-what:note');env.input('tl-quick-text','Spread');env.input('tl-quick-show','5');env.input('tl-quick-warn','4');env.click('tl-quick-fixed');env.click('tl-quick-save')
local quick;for _,es in pairs(ns.Active().data.raidReminders)do for _,v in pairs(es)do if v.display and v.display.text=='Spread'then quick=v end end end
assert(quick and quick.trigger.type=='pull'and quick.trigger.delay==90 and quick.trigger.leadTime==4 and quick.display.dur==5 and ns.UIState.tlPick==nil,'saved at the ability time without leaving the Timeline: '..tostring(ns.UIState.message))
for _,es in pairs(ns.Active().data.raidReminders)do for k,v in pairs(es)do if v==quick then es[k]=nil end end end
-- Sending needs a group; receiving stores the plan under the sender (real libraries only).
if LibStub('LibSerialize').Deserialize then
local ok,err=ns.SendReminders(enc,15);assert(not ok and err:match('group'),'needs a group')
local sent;ns.Send=function(kind,text)sent={kind,text};return true end;ns.GroupChannel=function()return'RAID'end;ns.GroupAuthority=function()return true end
assert(ns.SendReminders(enc,15)==1 and sent[1]=='REMS','plan sent')
ns.ShortName=function(n)return n end
local n=ns.ReceiveReminders(sent[2],'Leader');assert(n==1,'plan received')
local got=0;for k,e in pairs(ns.Active().data.raidReminders[enc])do if tostring(k):match('^recv:Leader:15:')then got=got+1;assert(e.sharedFrom=='Leader')end end
assert(got==1,'stored under sender');assert(ns.ReceiveReminders(sent[2],'Leader')==1);got=0;for k in pairs(ns.Active().data.raidReminders[enc])do if tostring(k):match('^recv:')then got=got+1 end end;assert(got==1,'a resend replaces')
assert(ns.SendReminders(enc,15)==1,'received reminders are not sent on')
end
`));
test('one !NDP1: string carries every profile, Mythic+ and raid data, and imports them all',()=>run(`
assert(ns.SaveSet('raid',104,nil,'Raid',{{spellID=22812}}))
assert(ns.CreateProfile('Second',true))
local p=ns.Active();p.data.raidReminders[3379]={x={name='Float',enabled=true,content='raid',difficulties={[16]=true},trigger={type='pull',delay=12.5,leadTime=1.25},target={all=true},display={type='text',text='Négatif',dur=4,ticks={5,10}}}}
local text,err=ns.Export();assert(text,err);assert(text:sub(1,6)=='!NDP1:','native prefix')
env.click('tab:profiles');env.click('tab:profiles');env.click('profile-export');assert(ns.UIControls['profile-string']:GetText():sub(1,6)=='!NDP1:')
env.click('profile-export-active');assert(ns.UIControls['profile-string']:GetText():sub(1,6)=='!NDP1:')
if LibStub('LibDeflate').DecompressDeflate then
  local bundle=assert(ns.DecodeProfiles(text));assert(#bundle.profiles==2 and bundle.active=='Second')
  local before=0;for _ in pairs(ns.Store().profiles)do before=before+1 end
  local name,e2,_,count=ns.Import(text);assert(name,e2);assert(count==2,'both profiles imported')
  local after=0;for _ in pairs(ns.Store().profiles)do after=after+1 end;assert(after==before+2)
  local r=ns.Active().data.raidReminders[3379].x;assert(name=='Second 2'and r.trigger.delay==12.5 and r.trigger.leadTime==1.25 and r.display.text=='Négatif'and r.display.ticks[2]==10,'values survive')
  assert(not ns.DecodeProfiles('!NDP1:AAAA'),'garbage refused')
end
`));
test('the timeline shows mechanic reminders and authors boss mod timers and messages for a chosen ability',()=>run(`
env.click('tab:raid');env.click('new-timed');env.input('rule:name','Soak');env.select('rule:trigger','Boss mod message')
assert(ns.UIControls['rule:triggerSpell'],'boss ability picker');env.click('save-rule')
local enc,found;for e,es in pairs(ns.Active().data.raidReminders)do for k,v in pairs(es)do if v.name=='Soak'then enc,found=e,v end end end
assert(found and found.trigger.type=='bwmsg'and found.trigger.spellID,'message reminder bound to an ability')
env.click('tab:timeline');local waiting=false;for k in pairs(ns.UIControls)do if k:match('^tl%-mwait:')or k:match('^tl%-mech:')then waiting=true end end;assert(waiting,'without a recorded pull the reminder still shows on the Mechanics lane')
ns.Store().timelines={[ns.Client()..':'..enc..':15']={events={{20,found.trigger.spellID},{80,found.trigger.spellID}},length=120}}
env.click('tab:timeline');local marks=0;for k in pairs(ns.UIControls)do if k:match('^tl%-mech:')then marks=marks+1 end end;assert(marks==2,'two casts on the Mechanics lane, got '..marks)
local key;for k in pairs(ns.UIControls)do if k:match('^tl%-mech:')then key=k end end;env.click(key);assert(ns.UIState.tab=='raid'and ns.UIState.reference and ns.UIState.reference.entry.name=='Soak','marker opens the reminder')
`));
test('the timeline shows the boss abilities of your recorded pull; a click plans a defensive or a note for that cast',()=>run(`
${pulled}
env.click('tab:timeline');env.click('tab:timeline')
local marks=0;for k in pairs(ns.UIControls)do if k:match('^tl%-ability:')then marks=marks+1 end end;assert(marks==8,'recorded boss casts on the Boss lane, got '..marks)
local key;for k in pairs(ns.UIControls)do if k=='tl-ability:2'then key=k end end;assert(key);env.click(key)
assert(ns.UIState.tlPick and ns.UIControls['tl-quick-save']and ns.UIControls['tl-quick-what:note'],'cast picker')
local pick=ns.UIState.tlPick
env.click('tl-quick-what:note');env.click('tl-quick-more');assert(ns.UIState.tab=='raid'and ns.UIState.ability==pick.spell,'ability opened on the Raids page')
assert(ns.UIState.form.action=='none'and ns.UIState.form.alertOn and ns.UIState.form.counter==tostring(pick.cast),'note for this cast: the text alert only')
env.input('rule:alertText','Stack in middle');env.click('save-rule')
local found;for _,es in pairs(ns.Active().data.raidReminders)do for _,v in pairs(es)do if v.display and v.display.text=='Stack in middle'then found=v end end end
assert(found and found.trigger.spellID==pick.spell and found.trigger.counterGroups[1][1].value==pick.cast,'note bound to the boss ability and cast')
assert(found.display.type=='ability'and found.display.spellID==pick.spell and found.display.style==nil and found.display.hideTimer==nil,'a boss ability alert with the ability icon and seconds left')
assert(ns.MinimumAddon(ns.Active().data)=='0.7.3')
-- The same alert as a bar with a timer, or as text only.
env.select('rule:alertStyle','Bar with timer');env.click('save-rule')
found=nil;for _,es in pairs(ns.Active().data.raidReminders)do for _,v in pairs(es)do if v.display and v.display.text=='Stack in middle'then found=v end end end
assert(found.display.style=='bar'and ns.Validate(ns.Active()),'bar style saved')
env.select('rule:alertStyle','Text only');env.click('save-rule')
found=nil;for _,es in pairs(ns.Active().data.raidReminders)do for _,v in pairs(es)do if v.display and v.display.text=='Stack in middle'then found=v end end end
assert(found.display.style=='text','text style saved')
`));
test('the timeline zooms with Ctrl + wheel and the slider moves it before and after the pull',()=>run(`
${pulled}
env.click('tab:timeline');env.click('tab:timeline')
local s=ns.UIState;assert(s.tlSpan==nil or s.tlSpan==120)
assert(not ns.UIControls['tl-zoom-in']and not ns.UIControls['tl-left'],'no extra zoom or arrow buttons')
ns.TimelineZoom(1);assert(s.tlSpan==90,'zoom in, got '..tostring(s.tlSpan))
ns.TimelineZoom(-1);ns.TimelineZoom(-1);assert(s.tlSpan==180)
s.tlStart=0;env.click('tl-track:1');assert(s.tlStart<0,'slider goes before the pull')
env.click('tl-track:20');local far=s.tlStart;assert(far>200,'track click jumps, got '..far)
-- Holding the left button on the thumb drags the view live: the thumb follows every frame, the page a few times a second.
local cx,down=500,true;function GetCursorPosition()return cx,300 end;function IsMouseButtonDown()return down end;ns.RefreshWorkspace();far=s.tlStart
local thumb=ns.UIControls['tl-thumb'];assert(thumb:GetFrameLevel()>ns.UIControls['tl-track:1']:GetFrameLevel(),'thumb above the track')
thumb.scripts.OnMouseDown(thumb,'LeftButton')
local d;for i=#env.frames,1,-1 do local f=env.frames[i];if f.scripts.OnUpdate and f.parent==nil then d=f;break end end;assert(d,'drag driver')
local draws=0;local ro=ns.RuleOptions;ns.RuleOptions=function(...)draws=draws+1;return ro(...)end
local x0=ns.UIControls['tl-thumb'].point.x
cx=300;d.scripts.OnUpdate(d,0.05);local dragged=s.tlStart;assert(dragged<far,'thumb drag moves the view, got '..dragged)
assert(draws==0 and ns.UIControls['tl-thumb'].point.x<x0,'a quick move only slides the thumb, no page redraw')
cx=290;for _=1,5 do d.scripts.OnUpdate(d,0.06)end;assert(draws>0,'the page follows within a quarter second');dragged=s.tlStart
ns.RuleOptions=ro
cx=200;down=false;d.scripts.OnUpdate(d,0.01);assert(s.tlStart<dragged and d.scripts.OnUpdate==nil,'release ends the drag at the cursor')
GetCursorPosition,IsMouseButtonDown=nil,nil
ns.TimelineZoom(1);assert(s.tlSpan==120)
`));
test('a simulated pull plays the boss timeline through the reminders outside combat',()=>run(`
${pulled}
env.click('tab:timeline');env.click('tab:timeline');env.click('tl-ability:2')
local pick=ns.UIState.tlPick;env.click('tl-quick-what:note');env.click('tl-quick-more');env.input('rule:alertText','Stack in middle');env.click('save-rule')
env.click('tab:timeline');env.click('tl-simulate');assert(ns.Simulating(),'simulation running')
assert(ns.UIControls['tl-simulate'],'stop button')
local before=#env.shown;for _=1,math.ceil(pick.at)+1 do env.advance(1)end
local seen=false;for i=before+1,#env.shown do local d=env.shown[i];if d and d.text=='Stack in middle'then seen=true end end
assert(seen,'the note fired during the simulated pull')
assert(#ns.RecordedTimeline(pick.encounter,pick.difficulty).events==8,'a simulation records nothing')
env.click('tl-simulate');assert(not ns.Simulating(),'stopped')
`));
test('the cooldowns lane predicts the spell for each defensive call and flags calls with nothing ready',()=>run(`
${pulled}
assert(ns.SaveSet('raid',104,nil,'Raid',{{spellID=22812}}))
env.click('tab:timeline');env.click('tab:timeline');env.click('tl-ability:2');env.click('tl-quick-more')
assert(ns.UIState.form.alertOn,'a defensive on a boss ability offers the ability alert by default')
env.select('rule:preset','Raid');env.input('rule:counter','');env.input('rule:alertText','Tank Hit');env.click('save-rule')
-- NSR pair: the defensive call and, separately, the boss ability with the text on its own anchor.
local saved;for _,es in pairs(ns.Active().data.raidReminders)do for _,v in pairs(es)do if v.defensive then saved=v end end end
assert(saved and saved.defensive.spell==nil and saved.alert and saved.alert.text=='Tank Hit'and saved.alert.style==nil and ns.Validate(ns.Active())and ns.MinimumAddon(ns.Active().data)=='0.7.3','alert saved with the defensive')
env.shown={};ns.ShowAbilityAlert(saved);local al=env.shown[1]
assert(al and al.type=='ability'and al.text=='Tank Hit'and al.spellID==saved.trigger.spellID and al.small and al.tts==false,'alert goes to the ability anchor with a small icon')
-- Both blocks at once, and the defensive bound to one spell of the set instead of the priority.
assert(ns.UIControls['rule:alertOn']and ns.UIControls['rule:defSpell'],'text alert and personal defensive are shown together')
env.select('rule:defSpell',ns.SpellLabel(22812));env.click('save-rule')
saved=nil;for _,es in pairs(ns.Active().data.raidReminders)do for _,v in pairs(es)do if v.defensive then saved=v end end end
assert(saved.defensive.spell==22812 and saved.alert.text=='Tank Hit'and ns.Validate(ns.Active()),'one spell of the set, alert kept')
env.shown={};ns.ShowAbilityAlert(saved);ns.RenderDefensive(saved);assert(env.shown[1]and env.shown[1].type=='ability'and env.shown[2]and env.shown[2].spellID==22812,'one fire shows the text alert and the chosen defensive')
env.click('tab:timeline');ns.UIState.tlSpan=600;ns.UIState.tlStart=0;env.click('tab:timeline')
local ok,bad=0,0
for k,c in pairs(ns.UIControls)do if k:match('^tl%-cd:')then if c.label and c.label:GetText()=='!'then bad=bad+1 else ok=ok+1 end end end
assert(ok>=1 and bad>=1,'first call gets the spell, a call inside its cooldown is flagged: ok='..ok..' bad='..bad)
local plan=ns.PlanDefensives({{at=0,preset={list={1,2}}},{at=10,preset={list={1,2}}},{at=20,preset={list={1,2}}}})
assert(plan[1].spells[1]==1 and plan[2].spells[1]==2 and #plan[3].spells==0 and plan[3].readyAt==120,'priority falls through to the next ready spell')
`));
test('targets: rotation by cast, position in a note line, raid group and class',()=>run(`
UnitName=function()return'Tester'end
local t={rotation={names={'Alpha','Tester','Gamma'}}}
assert(not ns.Target(t,1)and ns.Target(t,2)and not ns.Target(t,3)and ns.Target(t,5),'cast N goes to the N-th name, round and round')
assert(ns.SaveNote('shared',nil,{name='Plan',text='Soak: Alpha Tester\\nKick: Tester, Beta'}))
local id;for k,v in pairs(ns.Notes().shared)do if v.name=='Plan'then id=k end end;assert(ns.LoadNote('shared',id))
assert(ns.Target({rotation={note='soak'}},2)and not ns.Target({rotation={note='Soak'}},1),'rotation from a note line')
assert(ns.Target({noteSlot={note='Kick',index=1}})and not ns.Target({noteSlot={note='Kick',index=2}}),'position in a note line')
env.click('tab:raid');env.click('new-timed');env.input('rule:name','Rot');env.select('rule:action','Text');env.select('rule:recipient','Rotation by cast');env.input('rule:rotation','note:Soak');env.click('save-rule')
local found;for _,es in pairs(ns.Active().data.raidReminders)do for _,v in pairs(es)do if v.name=='Rot'then found=v end end end
assert(found and found.target.rotation.note=='Soak','rotation saved')
local text=assert(ns.Export());if LibStub('LibDeflate').DecompressDeflate then assert(ns.DecodeProfiles(text),'exports and validates')end
assert(ns.Validate(ns.Active()),'profile with a rotation validates')
`));
test('saved data stays small: history is compressed, old import copies are dropped, /ndp mem reports the parts',()=>run(`
local store=ns.Store();store.migrationSources={x=string.rep('a',100000)};store.importReports={x={}}
store=ns.Store();assert(store.migrationSources==nil and store.importReports==nil,'unused import copies dropped')
ns.Active().data.raidReminders[3379]={m={name='Keep me',enabled=true,content='raid',difficulties={[15]=true},trigger={type='pull',delay=5},target={all=true},display={type='text',text='x',dur=3}}}
store.history={{name=ns.Active().name,client='retail',time=1,reason='old',profile=ns.Clone(ns.Active())}}
ns.Snapshot(ns.Active(),'new')
for _,h in ipairs(store.history)do assert(h.packed and h.profile==nil,'snapshots kept compressed')end
local name=ns.Active().name;ns.Active().data.raidReminders[3379]=nil
assert(ns.RestoreSnapshot(2)==name and ns.Active().data.raidReminders[3379].m.name=='Keep me','a compressed snapshot restores, old ones too')
local lines=ns.MemoryReport();local found=false;for _,l in ipairs(lines)do if l:find('profiles:',1,true)then found=true end end;assert(found,'parts listed')
SlashCmdList.NDP('mem')
`));
test('imports merge into or replace a same-name profile, a boss string replaces one boss, and History restores',()=>run(`
local p=ns.Active();local n0=0;for _ in pairs(ns.Store().profiles)do n0=n0+1 end
local function rem(name)return{name=name,enabled=true,content='raid',difficulties={[15]=true},trigger={type='pull',delay=10},target={all=true},display={type='text',text=name,dur=4}}end
p.data.raidReminders[3379]={x=rem('X')}
env.click('tab:timeline');env.click('tab:timeline');env.select('tl-share','Export boss')
assert(ns.UIState.tab=='profiles'and ns.UIState.importText:sub(1,6)=='!NDP1:','boss string shown on the Profiles page')
env.click('profile-import-mode:merge');assert(ns.UIState.importMode=='merge')
assert(not ns.ExportBoss(3420),'empty boss refused')
if LibStub('LibDeflate').DecompressDeflate then
  local boss=assert(ns.ExportBoss(3379,'Nym'))
  p.data.raidReminders[3379]={y=rem('Y')};p.data.raidReminders[3420]={z=rem('Z')}
  assert(ns.Import(boss));p=ns.Active()
  assert(p.data.raidReminders[3379].x and not p.data.raidReminders[3379].y and p.data.raidReminders[3420].z,'boss import replaces only that boss')
  local h=ns.History();assert(#h==1 and h[1].reason=='before boss import')
  local all=assert(ns.Export())
  p.data.raidReminders[3379].w=rem('W')
  assert(ns.Import(all,'merge'));p=ns.Active()
  local n1=0;for _ in pairs(ns.Store().profiles)do n1=n1+1 end;assert(n1==n0,'merge adds no profile')
  assert(p.data.raidReminders[3379].w and p.data.raidReminders[3379].x,'merge keeps local entries and adds imported ones')
  assert(ns.Import(all,'replace'));p=ns.Active();assert(not p.data.raidReminders[3379].w,'replace drops local entries')
  assert(#ns.History()==3)
  env.click('tab:profiles');env.click('tab:profiles');assert(ns.UIControls['profile-restore:1'],'history row')
  env.click('profile-restore:1');assert(ns.Active().data.raidReminders[3379].w,'restore brings the replaced version back')
  for _=1,15 do ns.Snapshot(ns.Active(),'x')end;assert(#ns.History()==10,'ten snapshots kept')
end
`));
test('boss health and own aura triggers fire on the pull, once per threshold and once per aura landing',()=>run(`
local hp,aura=100,nil
UnitExists=function(u)return u=='boss1'end;UnitHealth=function()return hp end;UnitHealthMax=function()return 100 end
C_UnitAuras=C_UnitAuras or{};C_UnitAuras.GetPlayerAuraBySpellID=function(id)if id==12345 then return aura end end
env.click('tab:raid');env.click('new-timed');env.input('rule:name','Burn');env.select('rule:trigger','Boss health below')
assert(ns.UIControls['rule:percent'],'percent field');env.input('rule:percent','30');env.select('rule:action','Text');env.input('rule:text','Lust now');env.click('save-rule')
env.click('new-timed');env.input('rule:name','Debuff');env.select('rule:trigger','Aura on me');env.input('rule:triggerSpell','12345');env.select('rule:action','Text');env.input('rule:text','Run out');env.click('save-rule')
local enc,b,a;for e,es in pairs(ns.Active().data.raidReminders)do for _,v in pairs(es)do if v.name=='Burn'then enc,b=e,v elseif v.name=='Debuff'then a=v end end end
assert(b and b.trigger.type=='bosshp'and b.trigger.percent==30 and a and a.trigger.type=='aura'and a.trigger.spellID==12345,'saved')
assert(ns.Validate(ns.Active())and ns.MinimumAddon(ns.Active().data)=='0.7.1')
ns.Begin(tonumber(enc),15)
local f;for _,fr in ipairs(env.frames)do if fr.events.UNIT_HEALTH and fr.scripts.OnEvent then f=fr end end;assert(f,'health watched')
local function count(text)local n=0;for _,d in ipairs(env.shown)do if d.text==text then n=n+1 end end;return n end
hp=50;f.scripts.OnEvent(f,'UNIT_HEALTH','boss1');assert(count('Lust now')==0)
hp=29;f.scripts.OnEvent(f,'UNIT_HEALTH','boss1');hp=10;f.scripts.OnEvent(f,'UNIT_HEALTH','boss1');assert(count('Lust now')==1,'fires once')
aura={spellId=12345};f.scripts.OnEvent(f,'UNIT_AURA','player');f.scripts.OnEvent(f,'UNIT_AURA','player');assert(count('Run out')==1)
aura=nil;f.scripts.OnEvent(f,'UNIT_AURA','player');aura={};f.scripts.OnEvent(f,'UNIT_AURA','player');assert(count('Run out')==2,'again on the next landing')
env.click('tab:timeline');env.click('tab:timeline')
ns.Reset();hp=5;f.scripts.OnEvent(f,'UNIT_HEALTH','boss1');assert(count('Lust now')==1,'nothing after the pull')
`));
test('before a pull the Boss lane lists the boss abilities without times; the journal adds bosses, names and categories',()=>run(`
ns.LogTimelines[3379]=nil -- a boss without a Warcraft Logs base
local j=ns.Journal();assert(j and #j.raids==1 and #j.dungeons==1,'journal read when the window opened')
local raids=ns.CatalogGroups('raid');assert(raids[1].name=='Fixture Raid'and #raids[1].bosses==4,'raid list from the journal')
local nym=raids[1].bosses[1];assert(nym.id==3379 and nym.abilities[1].id==1276710,'built-in timer spells first')
local seen={};for _,a in ipairs(nym.abilities)do assert(not seen[a.id],'no duplicate '..a.id);seen[a.id]=true end
local only=raids[1].bosses[4];assert(only.name=='Journal Only Boss'and only.abilities[1].id==1390001,'a boss without built-in timers still gets its journal abilities')
assert(ns.AbilityCategory(1268562)=='tank'and ns.AbilityCategory(1260837)=='raid'and ns.AbilityCategory(1281907)=='dispel'and ns.AbilityCategory(1390002)=='dispel'and ns.AbilityCategory(1284434)==nil,'categories from the journal flags')
local water;for _,a in ipairs(j.raids[1].bosses[1].abilities)do if a.id==1268562 then water=a end end;assert(#water.difficulties==1 and water.difficulties[1]=='mythic','mythic-only ability')
local row;for _,g in ipairs(ns.CatalogGroups('mythic'))do for _,n in ipairs(g.npcs)do if n.encounterId==3103 then row=n end end end
local has=false;for _,a in ipairs(row.abilities)do if a.id==1390101 then has=true end end;assert(has,'dungeon bosses gain journal abilities')
assert(ns.EncounterScope(3901)=='raid')
env.click('tab:timeline');env.click('tab:timeline')
local marks=0;for k in pairs(ns.UIControls)do if k:match('^tl%-ability:')then marks=marks+1 end end;assert(marks>=7,'abilities without times, got '..marks)
env.click('tl-ability:1');local pick=ns.UIState.tlPick;assert(pick and pick.at==nil and ns.UIControls['tl-quick-save']and not ns.UIControls['tl-quick-fixed'],'untimed pick')
env.click('tl-quick-what:note');env.click('tl-quick-more');assert(ns.UIState.ability==pick.spell and ns.UIState.form.counter=='','a note for every cast')
-- The journal is read once per build; a new build reads it again.
j.raids[1].name='Old';assert(ns.ScanJournal()and ns.Journal().raids[1].name=='Old');ns.Journal().build='1';assert(ns.ScanJournal()and ns.Journal().raids[1].name=='Fixture Raid')
`));
test('the Warcraft Logs base places the abilities in time before your own pull, which replaces it',()=>run(`
assert(ns.LogTimelinesInfo.kills>=20 and ns.ExpectedTimeline(3420,16),'the shipped base covers the raid')
ns.LogTimelines[3379]={[15]={length=300,kills=20,phases={},events={{9,1260837},{19,1257717},{40,1260837}}}}
local tl=ns.ExpectedTimeline(3379,15);assert(tl and tl.expected and tl.kills==20 and #tl.events==3)
assert(ns.ExpectedTimeline(3379,14)and not ns.ExpectedTimeline(3379,16),'Normal uses the Heroic base')
assert(ns.SimulationTimeline(3379,15)==nil or ns.SimulationTimeline(3379,15).expected,'simulation plays the base')
env.click('tab:timeline');env.click('tab:timeline')
local marks=0;for k in pairs(ns.UIControls)do if k:match('^tl%-ability:')then marks=marks+1 end end;assert(marks==3,'base casts on the Boss lane, got '..marks)
env.click('tl-ability:2');assert(ns.UIState.tlPick.at==19 and ns.UIState.tlPick.cast==1 and ns.UIControls['tl-quick-fixed'])
assert(not ns.ExportBoss(3379,'x'),'nothing planned: the base alone is never exported')
${pulled}
assert(not ns.SimulationTimeline(3379,15).expected,'your pull wins')
`));
test('in a phase that starts at a different time on each pull, Timed here follows a cast of that phase, not the pull',()=>run(`
ns.LogTimelines[3379]={[15]={length=300,kills=20,phases={{id=2,name='Stage Two',at=100,vary=true}},events={{9,1260837},{98,1257717,anchor=2},{120,1260837,anchor=2},{115,1276710,spread=4}}}}
env.click('tab:timeline');env.click('tab:timeline')
assert(ns.UIControls['tl-phase:1'],'phase change drawn')
env.click('tl-ability:1');assert(ns.UIControls['tl-quick-fixed']and not ns.UIState.tlPick.anchor,'a cast before the phase stays timed from the pull')
env.click('tl-ability:2');assert(ns.UIState.tlPick.anchor and not ns.UIControls['tl-quick-fixed'],'the anchor itself: plan it by its boss timer')
env.click('tl-ability:4');assert(not ns.UIControls['tl-quick-fixed'],'a cast that moves between kills has no time to pin')
env.click('tl-ability:3');local a=ns.UIState.tlPick.anchor;assert(a and a.spell==1257717 and a.cast==1 and a.offset==22,'timed from the first steady cast of the phase')
env.click('tl-quick-what:note');env.input('tl-quick-text','Big hit soon');env.input('tl-quick-warn','2');env.click('tl-quick-fixed');env.click('tl-quick-save')
local saved;for _,v in pairs(ns.Active().data.raidReminders[3379]or{})do if v.trigger.type=='bwmsg'and v.trigger.spellID==1257717 then saved=v end end
assert(saved and saved.trigger.delay==20,'saved on the anchor message: '..tostring(ns.UIState.message))
-- On the pull it waits for the anchor, however late the phase comes.
ns.Begin(3379,15);ns.Mechanic(1257717,nil,'MSG',3379,true)
local scheduled=false;for k in pairs(ns.timers)do if k:match('^message:MSG:')then scheduled=true end end;assert(scheduled,'reminder waits 20 s after the anchor message')
ns.Reset()
`));
test('a boss export carries the recorded pull, so the receiver sees the abilities in time; their own pull replaces it',()=>run(`
${pulled}
ns.Active().data.raidReminders[3379]={m={name='Adds',enabled=true,content='raid',difficulties={[15]=true},trigger={type='bwmsg',spellID=1276710,delay=0},target={all=true},display={type='text',text='Adds up',dur=3}}}
local text=assert(ns.ExportBoss(3379,'Nymrissa'))
ns.Store().timelines={}
assert(ns.Import(text),'boss import')
local t=ns.RecordedTimeline(3379,15);assert(t and t.shared and #t.events==8 and t.length==480,'shared timeline stored')
assert(ns.SimulationTimeline(3379,15)==t)
env.click('tab:timeline');env.click('tab:timeline');local found=false;for k in pairs(ns.UIControls)do if k=='tl-ability:8'then found=true end end;assert(found)
-- A bad timeline in a string is ignored; your own pull wins over a shared one.
assert(ns.ImportTimelines(3379,{[15]={events={{-1,5}},length=10}})==0)
ns.encounter,ns.difficulty,ns.pullTime,ns.recording=3379,15,GetTime(),{{5,1260837}};assert(ns.FinishRecording(false))
t=ns.RecordedTimeline(3379,15);assert(not t.shared and #t.events==1,'own pull replaced the shared one')
assert(ns.ImportTimelines(3379,{[15]={events={{5,1}},length=10}})==0,'a shared timeline never replaces your own')
ns.encounter,ns.difficulty=nil,nil
`));
test('the last pull lane compares defensive calls with your casts; Mine hides other players reminders; templates save and apply a boss plan',()=>run(`
assert(ns.SaveSet('raid',104,nil,'Raid',{{spellID=22812}}))
local enc=3379
ns.Begin(enc,15)
ns.LogDefensiveCall({22812},'Wall');env.advance(2)
local f;for _,fr in ipairs(env.frames)do if fr.scripts.OnEvent and fr.events.UNIT_SPELLCAST_SUCCEEDED then f=fr;fr.scripts.OnEvent(fr,'UNIT_SPELLCAST_SUCCEEDED','player','x',22812)end end
env.advance(30);ns.LogDefensiveCall({22812},'Second')
ns.FinishPullLog(false);ns.Reset()
local log=assert(ns.PullLog(enc,15),'pull logged');local a,followed=ns.AnalysePull(log)
assert(f,'casts watched during the pull');assert(#a==2 and followed==1,'one call followed, got '..followed)
ns.UIState.tlBoss=nil;env.click('tab:timeline');env.click('tab:timeline')
local miss=0;for k in pairs(ns.UIControls)do if k:match('^tl%-miss:')then miss=miss+1 end end;assert(miss>=1,'missed call marked')
local p=ns.Active();p.data.raidReminders[enc]={a={name='Mine',enabled=true,content='raid',difficulties={[15]=true},trigger={type='pull',delay=10},target={all=true},display={type='text',text='a',dur=3}},b={name='Other',enabled=true,content='raid',difficulties={[15]=true},trigger={type='pull',delay=20},target={names={Nobody=true}},display={type='text',text='b',dur=3}}}
env.click('tab:timeline');assert(ns.UIControls['tl-marker:b'])
env.click('tl-view:mine');assert(ns.UIControls['tl-marker:a']and not ns.UIControls['tl-marker:b'],'Mine hides the other player')
env.click('tl-view:all');assert(ns.UIControls['tl-marker:b'])
env.select('tl-share','Templates');env.input('tl-template-name','Prog');env.click('tl-template-save')
assert(#ns.Templates(enc)==1,'template saved')
p.data.raidReminders[enc]={}
env.click('tab:timeline');env.click('tl-template-apply:1');assert(ns.Active().data.raidReminders[enc].a,'template restores the plan')
assert(#ns.History()>=1,'applying keeps a snapshot')
env.click('tl-template-delete:1');assert(#ns.Templates(enc)==0)
`));
test('list scrollbars drag with the mouse and jump where the track is pressed',()=>run(`
local W=ns.Widgets
local child,scroll=W.Scroll(UIParent,0,0,300,200,'test-list')
function scroll:GetVerticalScrollRange()return 400 end;scroll.UpdateThumb()
local grip,track=scroll.ThumbGrip,scroll.ThumbTrack;assert(grip:IsShown()and track:IsShown(),'thumb shown when the list overflows')
assert(grip:GetFrameLevel()>track:GetFrameLevel(),'thumb above its track')
local cy,down=500,true;function GetCursorPosition()return 10,cy end;function IsMouseButtonDown()return down end
grip.scripts.OnMouseDown(grip,'LeftButton')
local d;for i=#env.frames,1,-1 do local f=env.frames[i];if f.scripts.OnUpdate and f.parent==nil then d=f;break end end;assert(d,'drag driver')
cy=450;d.scripts.OnUpdate(d,0.02);local moved=scroll:GetVerticalScroll();assert(moved>0,'dragging down scrolls down, got '..moved)
cy=600;d.scripts.OnUpdate(d,0.02);assert(scroll:GetVerticalScroll()==0,'and stops at the top')
cy=0;d.scripts.OnUpdate(d,0.02);assert(scroll:GetVerticalScroll()==400,'and at the bottom')
down=false;d.scripts.OnUpdate(d,0.02);assert(d.scripts.OnUpdate==nil,'release ends the drag')
GetCursorPosition,IsMouseButtonDown=nil,nil
`));
test('text and bar look come from Settings and LibSharedMedia; NDP anchors join EllesmereUI Unlock Mode',()=>run(`
local lsm={media={font={['Expressway']='Fonts/Expressway.ttf'},statusbar={['Smooth']='Tex/Smooth'}}}
function lsm:Register(kind,name,file)self.media[kind]=self.media[kind]or{};self.media[kind][name]=file end
function lsm:List(kind)local o={};for k in pairs(self.media[kind]or{})do o[#o+1]=k end;table.sort(o);return o end
function lsm:Fetch(kind,name)return self.media[kind]and self.media[kind][name]end
local stub=LibStub;LibStub=setmetatable({},{__call=function(_,name,silent)if name=='LibSharedMedia-3.0'then return lsm end;return stub(name,silent)end,__index=stub})
ns.RegisterMedia();assert(lsm.media.font['URW Gothic Demi'],'NDP shares its font')
local fonts={};for _,o in ipairs(ns.FontChoices())do fonts[o.value]=true end;assert(fonts['lsm:Expressway'],'shared fonts listed')
local bars={};for _,o in ipairs(ns.BarTextureChoices())do bars[o.value]=true end;assert(bars['lsm:Smooth']and bars.flat,'shared textures listed')
assert(ns.EditProfile(function(data)data.settings=data.settings or{};data.settings.font='lsm:Expressway';data.settings.outline='thick';data.settings.barTexture='lsm:Smooth';data.settings.barWidth=300;data.settings.barHeight=20 end))
assert(ns.Validate(ns.Active()),'look settings validate')

ns.RealDisplay({type='bar',spellID=22812,text='Soak',dur=5,tts=false})
local bar;for i=#env.frames,1,-1 do local f=env.frames[i];if f.kind=='StatusBar'and f.shown then bar=f;break end end
assert(bar and bar.w==300 and bar.h==20,'bar size from Settings: '..tostring(bar and bar.w)..'x'..tostring(bar and bar.h)..' '..tostring(ns.Settings().barWidth))
local text;for i=#env.frames,1,-1 do local f=env.frames[i];if f.kind=='Text'and f.text=='Soak'then text=f;break end end
assert(text and text.font=='Fonts/Expressway.ttf'and text.fontFlags=='THICKOUTLINE','font and outline from Settings')
ns.HideDisplays()
-- EllesmereUI Unlock Mode: two elements; moving one saves NDP's own anchor position.
local got;EllesmereUI={RegisterUnlockElements=function(self,elements,folder)got=elements;self.folder=folder end}
assert(ns.RegisterMovers()and #got==3 and EllesmereUI.folder=='NaowhDefensivePlanner')
local main;for _,e in ipairs(got)do if e.key=='NDP_Reminders'then main=e end end
local pos=main.loadPosition('NDP_Reminders');assert(pos.point=='LEFT'and pos.relPoint=='CENTER')
local f=main.getFrame('NDP_Reminders');assert(f and f:GetWidth()>0)
function f:GetLeft()return 740 end;function f:GetCenter()return 760,350 end;function UIParent:GetCenter()return 640,400 end
main.savePosition('NDP_Reminders','LEFT','CENTER',100,-50)
local s=ns.Settings().pos;assert(s.x==100 and s.y==-50 and s.point=='LEFT','position saved: '..tostring(s.x)..','..tostring(s.y))
assert(not ns.RegisterMovers(),'registered once')
EllesmereUI=nil;LibStub=stub
`));
test('three anchors for the whole profile: defensives, text and icon, bars',()=>run(`
assert(ns.EditProfile(function(data)data.settings=data.settings or{};data.settings.pos={point='LEFT',relPoint='CENTER',x=-300,y=0};data.settings.abilityPos={x=50,y=200};data.settings.barPos={x=10,y=-100}end))
assert(ns.Validate(ns.Active()),'barPos validates')
local function region(text)for i=#env.frames,1,-1 do local f=env.frames[i];if f.kind=='Text'and f.text==text and f.parent and f.parent.point then return f.parent end end end
ns.RealDisplay(ns.DefensiveDisplay({22812},{text='Def'}))
ns.RealDisplay({type='text',text='Stack',dur=4,tts=false})
ns.RealDisplay({type='ability',spellID=1,text='Hit',dur=4,tts=false})
ns.RealDisplay({type='ability',style='bar',spellID=1,text='Soak',dur=4,tts=false})
ns.RealDisplay({type='bar',spellID=1,text='Beam',dur=4,tts=false})
local d;for i=#env.frames,1,-1 do local f=env.frames[i];if f.kind=='Text'and(f.text or''):sub(1,3)=='Def'and f.parent and f.parent.point then d=f.parent;break end end;assert(d and d.point.x==-300,'defensive on its anchor')
assert(region('Stack').point.x==50 and region('Hit').point.x==50,'text and icon reminders share one anchor')
assert(region('Soak').point.x==10 and region('Beam').point.x==10,'every bar on the bar anchor')
assert(region('Soak').point.y~=region('Beam').point.y,'bars stack')
ns.HideDisplays()
assert(ns.ToggleAnchors());local n=0;for _,f in ipairs(env.frames)do if f.text and(f.text=='Defensives · drag · /ndp anchors locks'or f.text=='Text and icon · drag'or f.text=='Bars · drag')then n=n+1 end end;assert(n==3,'three anchors to drag, got '..n)
assert(not ns.ToggleAnchors())
`));
test('pull trace: boss mod events and every reminder, shown or skipped with the reason; observed, keys, calls, bosses and cds reports',()=>run(`
env.click('tab:raid');env.click('new-timed');env.input('rule:name','Burn');env.select('rule:action','Text');env.input('rule:text','Lust now');env.click('save-rule')
local enc;for e,es in pairs(ns.Active().data.raidReminders)do for _,v in pairs(es)do if v.name=='Burn'then enc=tonumber(e)end end end;assert(enc,'saved')
assert(ns.TraceOn(),'trace is on by default')
ns.Begin(enc,15);env.advance(2);ns.Mechanic(1260837,10,'BW:1',enc);ns.Mechanic(1260837,nil,'MSG',enc,true);env.advance(30)
local frames=0;for _,f in ipairs(env.frames)do if f.events.ENCOUNTER_END and f.scripts.OnEvent then f.scripts.OnEvent(f,'ENCOUNTER_END',enc,'x',15,20,0);frames=frames+1 end end;assert(frames>0)
local text=ns.TraceText()
assert(text:find('Pull ')and text:find('wipe'),'pull header: '..text)
assert(text:find('bar 10s')and text:find('message'),'boss mod events in the trace')
assert(text:find('show')and text:find('Burn'),'the reminder that showed: '..text)
assert(ns.ObservedText():find('x2'),'observed counts both events')
assert(ns.KeysText():find('1260837')and ns.KeysText():find('1 bars, 1 messages'),'keys report')
assert(ns.CallsText(enc):find('Burn'),'calls lists the reminder')
assert(ns.BossesText():find(tostring(enc)),'bosses lists the planned boss')
-- A reminder for someone else is skipped, with the reason.
for _,es in pairs(ns.Active().data.raidReminders)do for _,v in pairs(es)do if v.name=='Burn'then v.enabled=false end end end
ns.Begin(enc,15);env.advance(30);assert(ns.TraceText():find('turned off'),'skip reason')
assert(#ns.TracePulls()==2,'two pulls kept')
for _=1,3 do ns.Begin(enc,15)end;assert(#ns.TracePulls()==3,'only the last three')
ns.Command('trace off');ns.Begin(enc,15);assert(#ns.TracePulls()==3 and not ns.TraceOn())
ns.Command('trace on');ns.Command('trace clear');assert(#ns.TracePulls()==0)
ns.Command('trace');assert(ns.UIControls['diag-text']:GetText():find('No pull traced'),'trace shown in the report box')
env.click('diag-observed');env.click('diag-calls');env.click('diag-trace')
`));
test('starter set: known personal defensives, short ones first; /ndp starter makes one for Mythic+ and raids',()=>run(`
local rows=ns.StarterRows();assert(#rows>10,'known catalog defensives')
assert(rows[1].spellID==22812,'Barkskin first');local last=rows[#rows].spellID;assert(last==642,'Divine Shield last')
for _,r in ipairs(rows)do assert(r.spellID~=33206 and r.spellID~=1022,'no externals')end
env.click('tab:mythic');env.click('mode:sets');env.click('starter-set');env.click('save-set')
local sets=ns.ScopePresets(ns.Active(),'mythic',ns.Spec());local found;for _,s in pairs(sets)do if s.name=='Starter'then found=s end end;assert(found and #found.list==#rows,'saved from the page')
local n=ns.CreateStarterSets();assert(n==1,'only raids were missing: '..tostring(n))
local ok,err=ns.CreateStarterSets();assert(not ok and err:find('already'))
`));
test('invite and arrange from the note; nicknames for unit frames through NDPAPI',()=>run(`
assert(ns.SetNickname('Healbot','Doc'))
local n=ns.Notes();n.live={text='Group 1: Tester Doc\\nG2: Tanky\\nInvite: Extra, Doc'}
local g=ns.NoteGroups();assert(g.tester==1 and g.healbot==1 and g.tanky==2,'groups with the nickname resolved')
local list=ns.NoteInvites();assert(#list==4 and list[1]=='Extra'and list[2]=='Healbot','invites: '..table.concat(list,','))
local invited={};C_PartyInfo={InviteUnit=function(name)invited[#invited+1]=name end}
assert(ns.InviteFromNote()==3,'everyone but yourself')
n.live={text='nothing'};local ok,err=ns.InviteFromNote();assert(not ok and err:find('No names'))
assert(not ns.ArrangeGroups('note'))
assert(NDPAPI:GetName('Healbot')=='Doc'and NDPAPI.GetName('Healbot-Realm')=='Doc'and NDPAPI:GetName('Nobody')=='Nobody')
assert(ns.SetMyNickname('Boss'));assert(NDPAPI:GetName('player')=='Boss','own nickname for the player unit')
env.click('tab:players');env.click('players-frames');assert(ns.PlayersData().frames==true)
env.click('tab:raidtools');assert(ns.UIControls['rt-inv-note']and ns.UIControls['rt-arrange-note'])
`));
test('party cooldowns: spec lists, real casts start timers, sent cooldowns win, hidden casts are counted, page and frames',()=>run(`
local sent={};C_ChatInfo={RegisterAddonMessagePrefix=function()return true end,SendAddonMessage=function(_,text)sent[#sent+1]=text;return 0 end}
local units={player={'Tester','DRUID'},party1={'Friend','PRIEST'},party2={'Rogue','ROGUE'}}
function IsInGroup()return true end;function IsInRaid()return false end
function UnitExists(u)return units[u]~=nil end;function UnitName(u)return units[u or'player']and units[u or'player'][1]end
function UnitClass(u)local x=units[u or'player'];return'Class',x and x[2]end;function UnitIsUnit(a,b)return a==b end
function GetInspectSpecialization(u)return u=='party2'and 261 or 0 end
function GetSpellBaseCooldown(id)return id==31224 and 120000 or 0,0 end
env.click('tab:partycds');env.click('pcd:enabled');local cfg=ns.PartyCooldownConfig();assert(cfg.enabled)
local order=ns.PartyCooldownOrder();assert(#order==3 and order[1]=='Tester',#order)
local m=ns.PartyCooldownMembers
-- Unknown spec: only what every spec of the class has; Subtlety from inspect adds Shadow Blades.
local priest=ns.PartyCooldownList(m.Friend);for _,id in ipairs(priest)do assert(id~=33206,'no Pain Suppression before the spec is known')end
local rogue=ns.PartyCooldownList(m.Rogue);local blades=false;for _,id in ipairs(rogue)do if id==121471 then blades=true end;assert(id~=13750)end;assert(blades)
-- The game's base cooldown, then the table.
assert(ns.PartyCooldownCast('party2',31224));assert(math.abs(ns.PartyCooldownLeft(m.Rogue,31224)-120)<0.01)
env.advance(30);assert(math.abs(ns.PartyCooldownLeft(m.Rogue,31224)-90)<0.01)
-- Another class's spell from that unit does not count; a hidden spell is counted, not guessed.
assert(not ns.PartyCooldownCast('party2',33206))
local real=issecretvalue;issecretvalue=function(v)return v==999999 end
assert(not ns.PartyCooldownCast('party1',999999));issecretvalue=real
assert(m.Friend.hidden==1 and m.Rogue.seen==2)
-- What a member's addon sends: exactly their spells and their talented cooldowns.
ns.CommHandlers.PCD('256;33206=150;62618=180;10060=120;1234567=90','Friend')
assert(m.Friend.spec==256 and m.Friend.ndp and m.Friend.cds[33206]==150 and m.Friend.known[1234567])
local list=ns.PartyCooldownList(m.Friend);assert(#list==4 and list[1]==10060 and list[4]==1234567,#list)
assert(ns.PartyCooldownCast('party1',33206));assert(math.abs(ns.PartyCooldownLeft(m.Friend,33206)-150)<0.01)
env.advance(151);assert(ns.PartyCooldownLeft(m.Friend,33206)==0)
-- Own cooldown learned from the cast and sent out of combat.
C_Spell.GetSpellCooldown=function(id)return{startTime=env.time,duration=id==22812 and 45 or 0}end
assert(ns.PartyCooldownCast('player',22812));assert(cfg.learned['104'][22812]==45)
local payload=ns.PartyCooldownPayload();assert(payload:find('^104;')and payload:find('22812=45',1,true),payload)
assert(ns.SharePartyCooldowns(true));assert(sent[#sent]:find('PCD',1,true))
-- List display: one row per member; beside the Blizzard frames when found.
assert(ns.DrawPartyCooldowns())
CompactPartyFrameMember2=CreateFrame('Button');CompactPartyFrameMember2.unit='party1'
env.click('tab:partycds');cfg.mode='frames';assert(ns.DrawPartyCooldowns());assert(ns.PartyCooldownFrame('party1')==CompactPartyFrameMember2)
env.click('tab:partycds');assert(ns.UIControls['pcd-unlock']and ns.UIControls['pcd:hideReady']);assert(ns.PartyCooldownLeft(m.Tester,22812)==45,'your own timer is the game cooldown');assert(ns.PartyCooldownCast('party1',33206));env.click('pcd-reset');assert(ns.PartyCooldownLeft(m.Friend,33206)==0)
C_Spell.GetSpellCooldown=function()return{startTime=0,duration=0}end
-- Abilities: switch a spell off for its class, add and remove your own.
env.click('pcd-view:abilities');env.click('pcd-class:PRIEST');env.click('pcd-spell:33206');assert(not ns.PartyCooldownTracked(33206,256)and ns.PartyCooldownTracked(33206,257),'off for Discipline only')
for _,id in ipairs(ns.PartyCooldownList(m.Friend))do assert(id~=33206)end;assert(not ns.PartyCooldownCast('party1',33206))
env.click('pcd-spell:33206');assert(ns.PartyCooldownTracked(33206,256))
-- Each spec tab lists exactly that spec's cooldowns.
env.click('pcd-spec:258');assert(ns.UIControls['pcd-spell:47585']and not ns.UIControls['pcd-spell:33206'])
env.click('pcd-spec:256')
env.input('pcd:newSpell','73325');env.click('pcd-add');assert(ns.PartyCooldownSpellInfo(73325).added and cfg.custom.PRIEST[73325])
local has=false;for _,id in ipairs(ns.PartyCooldownClassSpells('PRIEST'))do if id==73325 then has=true end end;assert(has)
env.click('pcd-del:73325');assert(ns.PartyCooldownSpellInfo(73325)==nil)
env.input('pcd:newSpell','33206');env.click('pcd-add');assert(cfg.custom.PRIEST[33206]==nil,'listed spells are not added twice')
env.click('pcd-alloff');assert(not ns.PartyCooldownTracked(10060,256)and ns.PartyCooldownTracked(10060,258));env.click('pcd-allon');assert(ns.PartyCooldownTracked(10060,256))
-- Cooldown Manager: own Essential cooldowns of a minute or more are sent too; a cast seen through the target unit counts once.
C_CooldownViewer={GetCooldownViewerCategorySet=function()return{1,2}end,GetCooldownViewerCooldownInfo=function(i)return{spellID=i==1 and 391528 or 8936}end}
GetSpellBaseCooldown=function(id)return id==391528 and 120000 or 0,0 end
local cdm=ns.CooldownManagerSpells();assert(#cdm==1 and cdm[1]==391528,#cdm)
assert(ns.PartyCooldownPayload():find('391528=120',1,true))
UnitIsUnit=function(a,b)return a==b or(a=='target'and b=='party2')end
env.advance(200);assert(ns.PartyCooldownCast('target',5277));local start=m.Rogue.used[5277];assert(ns.PartyCooldownCast('party2',5277));assert(m.Rogue.used[5277]==start)
-- Inspected talents: a talent spell they did not take is left out, a taken one stays.
C_Traits={GetConfigInfo=function()return{treeIDs={1}}end,GetTreeNodes=function()return{10,11}end,
 GetNodeInfo=function(_,n)return n==10 and{entryIDs={100},currentRank=1,activeEntry={entryID=100}}or{entryIDs={101,102},currentRank=1,activeEntry={entryID=102}}end,
 GetEntryInfo=function(_,e)return{definitionID=e}end,GetDefinitionInfo=function(d)return{spellID=d==100 and 360194 or d==101 and 5277 or 31224}end}
m.Rogue.used={};assert(ns.PartyCooldownReadTalents(m.Rogue));assert(m.Rogue.talented[5277]==false and m.Rogue.talented[31224]==true)
for _,id in ipairs(ns.PartyCooldownList(m.Rogue))do assert(id~=5277,'untaken talent hidden')end
-- An unlisted spell with a cooldown of a minute or more (a follower's, a new talent) is picked up; a short one is not.
GetSpellBaseCooldown=function(id)return id==4444444 and 90000 or id==5555555 and 8000 or 0,0 end
assert(ns.PartyCooldownCast('party2',4444444));assert(ns.PartyCooldownSpellInfo(4444444).detected and ns.PartyCooldownLeft(m.Rogue,4444444)>89)
assert(not ns.PartyCooldownCast('party2',5555555));assert(ns.PartyCooldownSpellInfo(5555555)==nil)
local found=false;for _,id in ipairs(ns.PartyCooldownClassSpells('ROGUE'))do if id==4444444 then found=true end end;assert(found,'detected spells can be switched off on Abilities')
ns.PartyCooldownConfig().detect=false;assert(not ns.PartyCooldownCast('party2',6666666))
-- Every specialization has cooldowns of its own or its class.
for class,specs in pairs(ns.ClassSpecs)do for _,spec in ipairs(specs)do
 local list=ns.PartyCooldownList({class=class,spec=spec,used={},talented={}});assert(#list>=(spec==581 and 1 or 2),class..' '..spec..' '..#list)
end end
-- Without inspect or addon, a tank or healer role gives the spec.
assert(#ns.RoleSpecs('DRUID','HEALER')==1 and ns.RoleSpecs('DRUID','HEALER')[1]==105 and #ns.RoleSpecs('PRIEST','HEALER')==2)
local roleOf=UnitGroupRolesAssigned;UnitGroupRolesAssigned=function(u)return u=='party3'and'HEALER'or'DAMAGER'end
units.party3={'Follower','SHAMAN'};ns.PartyCooldownRoster();assert(m.Follower.spec==264)
local hasLink=false;for _,id in ipairs(ns.PartyCooldownList(m.Follower))do if id==98008 then hasLink=true end end;assert(hasLink,'healer shaman gets Spirit Link')
UnitGroupRolesAssigned=roleOf
-- Any unit frame addon: a shown frame showing exactly that unit.
local custom=CreateFrame('Button');custom.unit='party3';custom.h=40
local all={custom};function EnumerateFrames(f)if not f then return all[1]end;for i,x in ipairs(all)do if x==f then return all[i+1]end end end
ns.PartyCooldownForgetFrames();assert(ns.PartyCooldownFrame('party3')==custom)
cfg.mode='list';cfg.names=true;assert(ns.DrawPartyCooldowns());cfg.names=false;assert(ns.DrawPartyCooldowns())
-- Buff sensors: a member's own defensive buff and an external on anyone start the caster's timer.
cfg.mode='frames';for _,x in pairs(m)do x.used={}end
local n=ns.RebuildPartyCooldownSensors();assert(n>0,'sensors built');env.advance(1);ns.PartyCooldownPollSensors()
local list,st=ns.PartyCooldownSensors();assert(st.available)
local function light(spell,unit)for _,x in ipairs(list)do if x.spell==spell and(not unit or x.unit==unit)then x.frame.IsMouseOver=function()return true end end end end
light(31224,'party2');ns.PartyCooldownPollSensors();assert(ns.PartyCooldownLeft(m.Rogue,31224)>100 and m.Rogue.sensed==1,'Cloak by buff')
ns.PartyCooldownPollSensors();assert(m.Rogue.sensed==1,'a buff that stays up counts once')
light(33206,'party3');ns.PartyCooldownPollSensors();assert(ns.PartyCooldownLeft(m.Friend,33206)>100,'Pain Suppression on the shaman credits the priest')
cfg.sensors=false;assert(ns.RebuildPartyCooldownSensors()==0);cfg.sensors=true
-- Strictly by spec: your own list is what your spellbook knows; one Bloodlust or Heroism by faction.
local book=C_SpellBook.IsSpellKnown;C_SpellBook.IsSpellKnown=function(id)return id==22812 or id==61336 end
m.Tester.used={};local own=ns.PartyCooldownList(m.Tester);assert(#own==2,#own);C_SpellBook.IsSpellKnown=book
UnitFactionGroup=function()return'Alliance'end;ns.PartyCooldownRoster()
local lust,hero=false,false;for _,id in ipairs(ns.PartyCooldownList(m.Follower))do if id==2825 then lust=true elseif id==32182 then hero=true end end;assert(not hero and not lust,'Bloodlust and Heroism are not tracked')
-- Talents seen in any tree are not shown for a member whose talents are not read yet.
assert(ns.PartyCooldownConfig().talentSpells[5277],'Evasion remembered as a talent')
m.Rogue.talented=nil;m.Rogue.used={};for _,id in ipairs(ns.PartyCooldownList(m.Rogue))do assert(id~=5277 and id~=31224)end
assert(ns.PartyCooldownReadTalents(m.Rogue));local cloak=false;for _,id in ipairs(ns.PartyCooldownList(m.Rogue))do if id==31224 then cloak=true end end;assert(cloak)
-- In combat a sensor answers with a hidden yes/no: the start is kept hidden through the game's
-- curve helper and drawn by bars whose range follows the clock.
local hidden={};local real=issecretvalue;issecretvalue=function(v)return v==hidden end
C_CurveUtil={EvaluateColorValueFromBoolean=function(b,y,n)if b==hidden then return y end;return b and y or n end}
for _,x in pairs(m)do x.used={};x.hiddenCd=nil end;assert(ns.RebuildPartyCooldownSensors()>0);env.advance(1);ns.PartyCooldownPollSensors()
list=ns.PartyCooldownSensors()
for _,x in ipairs(list)do if x.spell==31224 and x.unit=='party2'then x.frame.IsMouseOver=function()return hidden end end end
local drawn=0;local draw=ns.DrawPartyCooldowns;ns.DrawPartyCooldowns=function(...)drawn=drawn+1;return draw(...)end
ns.PartyCooldownPollSensors();ns.DrawPartyCooldowns=draw
local t=ns.PartyCooldownHiddenTrack(m.Rogue,31224);assert(t,'hidden timer made')
assert(ns.PartyCooldownLeft(m.Rogue,31224)<=0,'nothing plain is learned from a hidden answer')
assert(math.abs(ns.PartyCooldownHiddenLeft(t,GetTime())-t.cd)<=t.window/255,'hidden start is now: '..ns.PartyCooldownHiddenLeft(t,GetTime()))
assert(drawn==1,'icons redrawn once for the new timer')
env.advance(30);ns.PartyCooldownPollSensors();assert(math.abs(ns.PartyCooldownHiddenLeft(t,GetTime())-(t.cd-30))<=t.window/255,'a buff still up does not restart it')
-- On the icon: a dark fill by the time left, and the seconds column pushed up one line per second.
local icon=CreateFrame('Frame');icon.tex=icon:CreateTexture();icon:SetSize(26,26);icon.spellID=31224
ns.PartyCooldownShowHidden(icon,t);local parts=icon.hidden;local p=parts[t.cur]
local got={};p.fill.SetMinMaxValues=function(_,a,b)got.lo,got.hi=a,b end;p.fill.SetValue=function(_,v)got.v=v end
p.pos.SetPoint=function(_,_,_,_,_,y)got.y=y end;p.pos.SetValue=function(_,v)got.posv=v end
ns.PartyCooldownSlideHidden()
local fill=(got.v-got.lo)/(got.hi-got.lo);assert(fill>0.7 and fill<0.9,'dark part shows the time left '..fill)
local sl=t.slot[t.cur];local left=sl.wepoch+t.window*sl.whole-math.floor(GetTime());local top=got.y+got.posv*t.window*parts.step
assert(math.abs(top/parts.step-left)<0.01,'column shows '..top/parts.step..' for '..left)
assert(p.column:GetText():match('^1\\n2\\n'),'column 1, 2, 3 ... from the top')
ns.PartyCooldownShowHidden(icon,nil);assert(not parts.win:IsShown())
-- After the cooldown the bar is empty; a slot rolls over before its window runs out.
env.advance(t.cd);ns.PartyCooldownPollSensors();assert(ns.PartyCooldownHiddenLeft(t,GetTime())==0)
for i=1,6 do env.advance(t.cd);ns.PartyCooldownPollSensors()end;assert(GetTime()-t.slot[t.cur].epoch<=t.open,'slot rolled')
-- The start is the moment the unit's auras changed, kept to the fraction of a second.
assert(ns.PartyCooldownFine(),'the curve helper carries fine numbers')
for _,x in pairs(m)do x.used={};x.hiddenCd=nil end
for _,x in ipairs(list)do if x.spell==31224 and x.unit=='party2'then x.prev=false;x.frame.IsMouseOver=function()return hidden end end end
env.advance(0.37);ns.PartyCooldownAura('party2');local t0=GetTime();env.advance(0.3);ns.PartyCooldownPollSensors()
local tr=ns.PartyCooldownHiddenTrack(m.Rogue,31224);assert(math.abs(ns.PartyCooldownHiddenLeft(tr,GetTime())-(tr.cd-0.3))<0.001,'exact start '..ns.PartyCooldownHiddenLeft(tr,GetTime()))
-- Cast before the pull: a buff seen in combat while that timer runs does not restart it.
for _,x in pairs(m)do x.used={};x.hiddenCd=nil end;assert(ns.PartyCooldownCast('party2',31224));local started=m.Rogue.used[31224]
for _,x in ipairs(list)do if x.spell==31224 and x.unit=='party2'then x.prev=false;x.frame.IsMouseOver=function()return hidden end end end
env.advance(5);ns.PartyCooldownPollSensors();assert(m.Rogue.used[31224]==started and not(m.Rogue.hiddenCd and m.Rogue.hiddenCd[31224]),'running timer kept')
issecretvalue=real
local printed={};local p=print;print=function(t)printed[#printed+1]=t end;ns.Command('pcd');print=p;assert(#printed>=2 and printed[1]:find('Buff sensors',1,true),printed[1])
-- Talents change the length: Arms Die by the Sword is 10% shorter with the talent taken.
GetSpellBaseCooldown=function(id)return id==118038 and 120000 or id==107574 and 90000 or id==227847 and 90000 or 0,0 end
local war={class='WARRIOR',spec=71,used={},unit='party4'}
assert(ns.PartyCooldownLength(war,118038)==108,'talents unread: the usual build');war.ranks={};assert(ns.PartyCooldownLength(war,118038)==120);war.ranks={[391271]=1};assert(ns.PartyCooldownLength(war,118038)==108)
assert(ns.PartyCooldownWithTalents({spec=70,ranks={}},31884,120)==60,'Retribution Avenging Wrath by spec')
-- Others: cooldowns cut by what they do are left out (not exact); Spell Reflection and Shadowmeld are in.
do local function has(m,id)for _,x in ipairs(ns.PartyCooldownList(m))do if x==id then return true end end return false end
local dkm={class='DEATHKNIGHT',spec=250,used={},talented={}};assert(not has(dkm,49028)and not has(dkm,55233)and has(dkm,48707),'Blood DRW and VB left out for others')
local pal={class='PALADIN',spec=66,used={},talented={}};assert(not has(pal,31884))
assert(has({class='PALADIN',spec=65,used={},talented={}},31884),'Holy Avenging Wrath stays')
local wm={class='WARRIOR',spec=73,used={},talented={},race='NightElf'};assert(has(wm,23920)and has(wm,58984)and not has(wm,871))
wm.race='Human';assert(not has(wm,58984),'Shadowmeld only for night elves')
assert(has({class='PALADIN',spec=65,used={},talented={},race='Dwarf'},20594),'Stoneform for dwarves')
assert(ns.PartyCooldownDynamic(31884,66)and not ns.PartyCooldownDynamic(31884,70))end
-- Spending rage in combat cuts Recklessness (Anger Management) when the bar is readable.
GetSpellBaseCooldown=function(id)return id==1719 and 90000 or 0,0 end
units.party4={'Warr','WARRIOR'};ns.PartyCooldownRoster();local w=m.Warr;w.spec=72;w.ranks={[152278]=1}
local rage=100;UnitPower=function()return rage end;UnitAffectingCombat=function()return true end
assert(ns.PartyCooldownCast('party4',1719));local before=ns.PartyCooldownLeft(w,1719)
ns.PartyCooldownPower('party4');rage=40;ns.PartyCooldownPower('party4');assert(math.abs(before-ns.PartyCooldownLeft(w,1719)-3)<0.01,'60 rage = 3 s')
-- Blood: runic power spent cuts Vampiric Blood (Red Thirst, 2 s per 10).
units.party4={'Dk','DEATHKNIGHT'};ns.PartyCooldownRoster();local dk=m.Dk;dk.spec=250;dk.ranks={[205723]=1};rage=100
GetSpellBaseCooldown=function(id)return id==55233 and 90000 or id==227847 and 90000 or 0,0 end
assert(ns.PartyCooldownCast('party4',55233));before=ns.PartyCooldownLeft(dk,55233)
ns.PartyCooldownPower('party4');rage=70;ns.PartyCooldownPower('party4');assert(math.abs(before-ns.PartyCooldownLeft(dk,55233)-6)<0.01,'30 runic power = 6 s')
-- A talent the trees no longer show counts as taken; a rank of 0 does not.
dk.ranks={};dk.used={};assert(ns.PartyCooldownCast('party4',55233));rage=100;ns.PartyCooldownPower('party4');rage=90;ns.PartyCooldownPower('party4');assert(ns.PartyCooldownLeft(dk,55233)<89)
dk.ranks={[205723]=0};dk.used={};assert(ns.PartyCooldownCast('party4',55233));rage=100;ns.PartyCooldownPower('party4');rage=90;ns.PartyCooldownPower('party4');assert(ns.PartyCooldownLeft(dk,55233)>89.9)
-- Another ID of a tracked spell counts as that spell (Greater Invisibility is Invisibility).
GetSpellBaseCooldown=function(id)return id==66 and 300000 or 0,0 end
units.party4={'Mage','MAGE'};ns.PartyCooldownRoster();local mg=m.Mage;mg.spec=64;mg.ranks={}
assert(ns.PartyCooldownCast('party4',110959));assert(ns.PartyCooldownLeft(mg,66)>200)
-- In dungeons every reminder is spoken by default.
ns.instanceType='party';local before=#env.shown;ns.Fire({display={type='text',text='Stack',tts=false}});assert(#env.shown==before+1 and env.shown[#env.shown].tts==true,'mplus voice default')
local cm=ns.ContentMatches;ns.ContentMatches=function()return true end;ns.instanceType='raid';before=#env.shown;ns.Fire({display={type='text',text='Stack',tts=false}});ns.ContentMatches=cm;assert(#env.shown==before+1 and env.shown[#env.shown].tts==false,'raid stays silent')
ns.Command('party');assert(ns.UIState.tab=='partycds')
`));
test('NDP Party Cooldowns runs the same tracking on its own, with /pcd settings, and stays off next to Naowh Defensive Planner',async()=>{
 const {partyCooldownFiles}=await import('../tools/package-partycds.mjs');const {files,version}=await partyCooldownFiles(process.cwd());
 const toc=files['NDPPartyCooldowns/NDPPartyCooldowns.toc'].toString('utf8');assert.match(toc,new RegExp('## Version: '+version.replaceAll('.','\\.')));
 const order=toc.split(/\r?\n/).map(s=>s.trim()).filter(s=>s&&!s.startsWith('#'));assert.deepEqual(order,['Core.lua','Comms.lua','PartyCooldowns.lua','Slash.lua']);
 const load=order.map(n=>`;(function(...)\n${files['NDPPartyCooldowns/'+n].toString('utf8')}\nend)('NDPPartyCooldowns',p)`).join('\n');
 await run(`
C_ChatInfo={RegisterAddonMessagePrefix=function()return true end,SendAddonMessage=function()return 0 end}
local units={player={'Tester','DRUID'},party1={'Friend','PRIEST'}}
function IsInGroup()return true end;function IsInRaid()return false end
function UnitExists(u)return units[u]~=nil end;function UnitName(u)return units[u or'player']and units[u or'player'][1]end
function UnitClass(u)local x=units[u or'player'];return'Class',x and x[2]end;function UnitIsUnit(a,b)return a==b end
strtrim=strtrim or function(s)return(s:gsub('^%s+',''):gsub('%s+$',''))end
local p={}
${load}
assert(p.PartyCooldownConfig().enabled==true,'on by default')
SlashCmdList.NDPPARTYCOOLDOWNS('list');assert(p.PartyCooldownConfig().mode=='list')
SlashCmdList.NDPPARTYCOOLDOWNS('size 30');assert(p.PartyCooldownConfig().size==30)
SlashCmdList.NDPPARTYCOOLDOWNS('left');assert(p.PartyCooldownConfig().side=='LEFT')
assert(#p.PartyCooldownOrder()==2);assert(#p.PartyCooldownReport()>=2)
assert(NDPPartyCooldownsDB.partycds.size==30,'saved in its own variables')
C_AddOns.IsAddOnLoaded=function(name)return name=='NaowhDefensivePlanner'end
assert(p.PartyCooldownConfig().enabled==false,'off next to the full addon')
`);
});
