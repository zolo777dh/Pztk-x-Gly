import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';import {execFileSync} from 'node:child_process';import fengari from 'fengari';
const root=path.resolve('addon/NaowhDefensivePlanner'),files=['Runtime','Locale','Catalog','Codec','Profiles','Display','RuleRuntime','AuraSounds','Providers','Editor','Import','Widgets','UI','Comms','Debuffs','Notes','Players','RaidTools','QoL','Combat','Main'],sources=await Promise.all(files.map(f=>fs.readFile(root+'/'+f+'.lua','utf8'))),harness=await fs.readFile('tests/helpers/wow-workspace.lua','utf8');
async function run(body){const script=`local env=(function()\n${harness}\nend)()\n`+(process.env.DOCTOR_LUA51?`strmatch=string.match;dofile(${JSON.stringify(root+'/Libs/LibStub.lua')});dofile(${JSON.stringify(root+'/Libs/LibSerialize.lua')});dofile(${JSON.stringify(root+'/Libs/LibDeflate.lua')})`:`local libs={};function LibStub(key)return libs[key]end;libs.LibSerialize={Serialize=function(_,p)return p.name end};libs.LibDeflate={CompressDeflate=function(_,s)return s end,EncodeForPrint=function(_,s)return s end}`)+`\nlocal function boot()local ns={}\n`+sources.map(s=>`;(function(...)\n${s}\nend)('NaowhDefensivePlanner',ns)`).join('\n')+`\nreturn ns end;local ns=boot();ns.Open();ns.Display=function(d)env.shown[#env.shown+1]=d end\nfunction env.reload()for i=#env.frames,1,-1 do local f=env.frames[i];if f.events.PLAYER_LOGOUT then f.scripts.OnEvent(f,'PLAYER_LOGOUT');break end end;ns.WorkspaceWindow:SetScript('OnHide',nil);ns.WorkspaceWindow:Hide();local lib=LibStub('LibSerialize');if lib.Deserialize then local ok,db=lib:Deserialize(lib:Serialize(NaowhDefensivePlannerDB));assert(ok);NaowhDefensivePlannerDB=db else NaowhDefensivePlannerDB=ns.Clone(NaowhDefensivePlannerDB)end;ns=boot();ns.Open();ns.Display=function(d)env.shown[#env.shown+1]=d end end\n${body}`;
 if(process.env.DOCTOR_LUA51){const d=await fs.mkdtemp(path.join(os.tmpdir(),'pztk-workspace-'));try{await fs.writeFile(d+'/test.lua',script);execFileSync(process.env.DOCTOR_LUA51,[d+'/test.lua'],{encoding:'utf8'});}finally{await fs.rm(d,{recursive:true,force:true});}return;}
 const {lua,lauxlib,lualib,to_luastring}=fengari,L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);try{if(lauxlib.luaL_loadstring(L,to_luastring(script))!==lua.LUA_OK||lua.lua_pcall(L,0,0,0)!==lua.LUA_OK)throw Error(lua.lua_tojsstring(L,-1));}finally{lua.lua_close(L);}
}

test('a defensive call-out keeps its own screen text, spoken phrase or sound, and the external step its phrase and chat line',()=>run(`
local spoken={};C_VoiceChat={GetTtsVoices=function()return{{voiceID=1}}end,SpeakText=function(_,text)spoken[#spoken+1]=text end}
env.click('tab:mythic');env.click('mode:sets');env.input('set-name','Bear');env.input('new-spell','22812');env.click('add-spell');env.input('new-spell','61336');env.click('add-spell');env.click('save-set')
env.click('set-callout:1');env.input('callout:label','BARK');env.input('callout:spoken','bark now');env.click('callout-hear');assert(spoken[#spoken]=='bark now')
env.click('callout-save');local data=ns.Active().data;assert(data.calloutOptions[22812].label=='BARK'and data.callouts[22812]=='bark now')
local label,phrase,audio=ns.Callout(22812);assert(label=='BARK'and phrase=='bark now'and audio)
env.click('set-callout:2');env.click('callout:speak');env.select('callout:sound','Move out');env.click('callout:audio');env.click('callout:audio');env.click('callout-save')
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
env.click('debuff-new');env.input('debuff:spellID','1217633');env.select('debuff:unit','Party members');env.select('debuff:sound','Dispel me');env.select('debuff:map','Another instance (by ID)');env.input('debuff:mapID','0');env.click('debuff-save')
local found=false;for _,x in ipairs(ns.DebuffRules(104))do if x.rule.trigger.spellID==1217633 and x.rule.trigger.target=='party'and x.rule.trigger.mapID==0 then found=true end end;assert(found)
env.click('debuff-new');env.input('debuff:spellID','1217633');env.select('debuff:sound','Stoneform (only when ready)');env.select('debuff:unit','Party members');assert(ns.UIState.drafts.debuff.sound=='voice:use-a-defensive')
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
local same={['top:timeline']=1,['top:display']=1,['header-profile']=1,['top:roster']=1,['debuff-new']=1,['mode:mechanics']=1,['mode:sets']=1,['mode:debuffs']=1,['display-anchor']=1}
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
assert(raid>=15 and mythic==0,raid..' '..mythic)
local found=false;for k in pairs(ns.UIControls)do if k:match('^debuff%-group:Vashnik')then found=true end end;assert(found,'Raid alerts are grouped by boss')
env.click('debuff-new');env.input('debuff:spellID','1290336');env.click('debuff-save')
local saved;for _,r in ipairs(ns.DebuffRules(104))do if r.rule.trigger.spellID==1290336 then saved=r end end;assert(saved and saved.rule.trigger.scope=='raid')
env.click('tab:mythic');env.click('mode:debuffs');for k in pairs(ns.UIControls)do assert(not k:match('^debuff%-group:Vashnik'),'Raid alerts leaked into Mythic+')end
env.reload();assert(#ns.DebuffRules(104)>=16,'Raid debuff alerts did not survive a reload')
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
assert(ns.ToggleAnchors());local a;for _,f in ipairs(env.frames)do if f.icon and f.scripts.OnDragStop then a=f end end;assert(a)
assert(a.point.point=='LEFT'and a.point.relativePoint=='CENTER'and a.point.x==193 and a.point.y==-65,'anchor icon is not at the reminder origin')
assert(a.w==(ns.Settings().iconSize or 42)and a.w==a.h,'anchor must be one icon')
a.GetLeft=function()return 1000 end;a.GetCenter=function()return 1010,600 end;UIParent.GetCenter=function()return 960,540 end
a.scripts.OnDragStop(a);local p=ns.Settings().pos;assert(p.point=='LEFT'and p.x==40 and p.y==60)
x,y=ns.ReminderOrigin();assert(x==40 and y==60)
assert(not ns.ToggleAnchors())
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
local frame;for _,f in ipairs(env.frames)do if f.events.UNIT_SPELLCAST_SUCCEEDED and f.events.PLAYER_REGEN_ENABLED then frame=f end end
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
assert(ns.UIState.tab=='raid'and tonumber(ns.UIState.form.delay)==90,'ability time prefilled')
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
ns.Store().timelines={[ns.Client()..':'..enc..':15']={events={{20,found.trigger.spellID},{80,found.trigger.spellID}},length=120}}
env.click('tab:timeline');local marks=0;for k in pairs(ns.UIControls)do if k:match('^tl%-mech:')then marks=marks+1 end end;assert(marks==2,'two casts on the Mechanics lane, got '..marks)
local key;for k in pairs(ns.UIControls)do if k:match('^tl%-mech:')then key=k end end;env.click(key);assert(ns.UIState.tab=='raid'and ns.UIState.reference and ns.UIState.reference.entry.name=='Soak','marker opens the reminder')
`));
