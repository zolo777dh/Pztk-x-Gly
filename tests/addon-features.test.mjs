import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';import {execFileSync} from 'node:child_process';import fengari from 'fengari';
const root=path.resolve('addon/NaowhDefensivePlanner'),files=['Runtime','Locale','Catalog','Profiles','Display','RuleRuntime','AuraSounds','Providers','Editor','Import','Widgets','UI','Comms','Debuffs','Notes','Players','RaidTools','Alerts','Main'],sources=await Promise.all(files.map(f=>fs.readFile(root+'/'+f+'.lua','utf8'))),harness=await fs.readFile('tests/helpers/wow-workspace.lua','utf8');
async function run(body){const script=`local env=(function()\n${harness}\nend)()\n`+(process.env.DOCTOR_LUA51?`strmatch=string.match;dofile(${JSON.stringify(root+'/Libs/LibStub.lua')});dofile(${JSON.stringify(root+'/Libs/LibSerialize.lua')});dofile(${JSON.stringify(root+'/Libs/LibDeflate.lua')})`:`local libs={};function LibStub(key)return libs[key]end;libs.LibSerialize={Serialize=function(_,p)return p.name end};libs.LibDeflate={CompressDeflate=function(_,s)return s end,EncodeForPrint=function(_,s)return s end}`)+`\nlocal function boot()local ns={}\n`+sources.map(s=>`;(function(...)\n${s}\nend)('NaowhDefensivePlanner',ns)`).join('\n')+`\nreturn ns end;local ns=boot();ns.Open();ns.Display=function(d)env.shown[#env.shown+1]=d end\nfunction env.reload()for i=#env.frames,1,-1 do local f=env.frames[i];if f.events.PLAYER_LOGOUT then f.scripts.OnEvent(f,'PLAYER_LOGOUT');break end end;ns.WorkspaceWindow:SetScript('OnHide',nil);ns.WorkspaceWindow:Hide();local lib=LibStub('LibSerialize');if lib.Deserialize then local ok,db=lib:Deserialize(lib:Serialize(NaowhDefensivePlannerDB));assert(ok);NaowhDefensivePlannerDB=db else NaowhDefensivePlannerDB=ns.Clone(NaowhDefensivePlannerDB)end;ns=boot();ns.Open();ns.Display=function(d)env.shown[#env.shown+1]=d end end\n${body}`;
 if(process.env.DOCTOR_LUA51){const d=await fs.mkdtemp(path.join(os.tmpdir(),'pztk-workspace-'));try{await fs.writeFile(d+'/test.lua',script);execFileSync(process.env.DOCTOR_LUA51,[d+'/test.lua'],{encoding:'utf8'});}finally{await fs.rm(d,{recursive:true,force:true});}return;}
 const {lua,lauxlib,lualib,to_luastring}=fengari,L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);try{if(lauxlib.luaL_loadstring(L,to_luastring(script))!==lua.LUA_OK||lua.lua_pcall(L,0,0,0)!==lua.LUA_OK)throw Error(lua.lua_tojsstring(L,-1));}finally{lua.lua_close(L);}
}

test('a defensive call-out keeps its own screen text, spoken phrase or sound, and the external step its phrase and chat line',()=>run(`
local spoken={};C_VoiceChat={GetTtsVoices=function()return{{voiceID=1}}end,SpeakText=function(_,text)spoken[#spoken+1]=text end}
env.click('tab:sets');env.input('set-name','Bear');env.input('new-spell','22812');env.click('add-spell');env.input('new-spell','61336');env.click('add-spell');env.click('save-set')
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
env.click('tab:assign');env.click('assign-test');assert(env.shown[#env.shown].text:find('Soak 1',1,true))
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
test('boss alerts list every reminder with on/off, test and a jump to its editor',()=>run(`
assert(ns.SaveSet('raid',104,nil,'Raid',{{spellID=22812}}))
env.click('tab:raid');env.click('new-timed');env.input('rule:name','Pull wall');env.input('rule:delay','20');env.click('save-rule')
env.click('tab:alerts');local items=ns.AllAlerts(104,'all');assert(#items==1)
local it=items[1];local id=it.section..':'..tostring(it.encounter)..':'..tostring(it.key)
env.click('alert-on:'..id);assert(ns.AllAlerts(104,'all')[1].entry.enabled==false)
env.click('alert-test:'..id);assert(#env.shown>0)
env.click('alerts-scope:mythic');assert(#ns.AllAlerts(104,'mythic')==0)
env.click('alerts-scope:all');env.click('alert-edit:'..id);assert(ns.UIState.tab=='raid'and ns.UIState.timed and ns.UIState.ruleKey==it.key)
`));
test('mouse wheel scrolls a list from anywhere over it, including its buttons and long text boxes',()=>run(`
for i=1,30 do assert(ns.SaveNote('shared',nil,{name='Note '..i,text='x'}))end
env.click('tab:notes');local s=ns.UIScrolls['notes:list'];s.GetVerticalScrollRange=function()return 900 end
local row;for k,c in pairs(ns.UIControls)do if k:match('^note:note_')then row=c;break end end
assert(row.scripts.OnMouseWheel,'list buttons pass the wheel on');row.scripts.OnMouseWheel(row,-1);assert(s:GetVerticalScroll()==48)
row.scripts.OnMouseWheel(row,1);assert(s:GetVerticalScroll()==0)
env.click('note-new');local text=ns.UIControls['note:text'];assert(text.scripts.OnMouseWheel,'note text scrolls with the wheel')
env.click('tab:overview');local b=ns.UIControls['overview:go:display'];assert(not b.scripts.OnMouseWheel)
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
local tabs={'overview','mythic','raid','sets','timeline','mythic/sets','mythic/debuffs','raid/debuffs','notes','alerts','assign','raidtools','players','display','profiles','settings','diag'}
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
env.click('tab:sets');env.input('set-name','Bear');env.input('new-spell','22812');env.click('add-spell');env.click('save-set')
local n=#env.shown;env.click('test-set');local d=env.shown[#env.shown];assert(#env.shown==n+1)
assert(not d.text:find('preview',1,true),d.text);assert(d.text==ns.SpellLabel(22812),d.text);assert(d.tts~=false and d.ttsText==ns.SpellLabel(22812),tostring(d.tts)..' '..tostring(d.ttsText))
env.click('set-callout:1');env.input('callout:spoken','bark now');env.click('callout-save');env.click('test-set');assert(env.shown[#env.shown].ttsText=='bark now')
`));
