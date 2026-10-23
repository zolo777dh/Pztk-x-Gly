import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';import {execFileSync} from 'node:child_process';import {PackCodec} from '../core/packs.mjs';import {NsrtCodec} from '../core/nsrt.mjs';import {ReminderPack} from '../core/reminder-pack.mjs';import {encodeCbor} from '../core/cbor.mjs';import {deflateRawSync} from 'node:zlib';
const root=path.resolve('addon/NaowhDefensivePlanner');const codec=new PackCodec(path.resolve('resources'));
async function run(t,input,body){if(!process.env.DOCTOR_LUA51){t.diagnostic('Native Lua importer integration requires DOCTOR_LUA51; portable model/UI tests run separately.');return;}
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'pztk-game-import-'));t.after(()=>fs.rm(dir,{recursive:true,force:true}));await fs.writeFile(dir+'/input.txt',input);const script=`unpack=unpack or table.unpack;strmatch=string.match;function GetBuildInfo()return'12.1.5','70448','',120105 end;function GetTime()return 100 end;local ns={};dofile(${JSON.stringify(root+'/Libs/LibStub.lua')});dofile(${JSON.stringify(root+'/Libs/LibSerialize.lua')});dofile(${JSON.stringify(root+'/Libs/LibDeflate.lua')})\n`+['Runtime','Catalog','Profiles','Editor','Import'].map(f=>`assert(loadfile(${JSON.stringify(root+'/'+f+'.lua')}))('NaowhDefensivePlanner',ns)`).join('\n')+`\nlocal f=assert(io.open(${JSON.stringify(dir+'/input.txt')},'rb'));local input=f:read('*a');f:close();\n${body}\nlocal out=assert(ns.Export());local f=assert(io.open(${JSON.stringify(dir+'/output.txt')},'wb'));f:write(out);f:close()`;
 await fs.writeFile(dir+'/check.lua',script);execFileSync(process.env.DOCTOR_LUA51,[dir+'/check.lua'],{encoding:'utf8'});const output=await fs.readFile(dir+'/output.txt','utf8');return new ReminderPack(codec).decode(output).pack;
}
test('native in-game NSR importer preserves sets, aura rules, custom conditions and attribution; refuses licensed data',async t=>{
 const text=codec.encode({format:1,name:'NSR migration',derivedFrom:{author:'Fixture'},data:{presets:{104:{p:{name:'Dungeon',list:[22812,61336]}}},activePreset:{104:'p'},integrationRules:{104:{a:{enabled:true,trigger:{type:'auraSound',mapID:2813,spellID:600,target:'player',auraEvent:'Added'},display:{sound:'voice:stoneform-ready'}}}},customReminders:{3102:{r:{enabled:true,name:'Defensive',specID:104,defensive:true,preset:'p',dur:4,trigger:{type:'bwmsg',spellID:474765,delay:'2',counter:'>1'}}}}}});
 const out=await run(t,text,`local name,error,report=ns.Import(input);assert(name,error);assert(report.converted==1 and #report.issues==0);assert(ns.Active().derivedFrom.author=='Fixture');local r=next(ns.Get(ns.Active().data.raidReminders,3102));assert(ns.Get(ns.Active().data.raidReminders,3102)[r].trigger.counterGroups[1][1].value==1);assert(not ns.DecodeImport(input..':LIC1:test'));assert(ns.EditProfile(function(data)data.settings={voiceOn=true}end));assert(ns.ScopePresets(ns.Active(),'mythic',104).p.list[1]==22812);assert(ns.ScopePresets(ns.Active(),'raid',104).p.list[1]==22812)`);if(out){assert.equal(out.data.scopePresets.mythic['104'].p.name,'Dungeon');assert.equal(out.data.integrationRules['104'].a.trigger.type,'auraSound');}
});
test('native in-game NSRT importer decodes real CBOR/Deflate, OR recipients, Heroic/Mythic phases and custom voice text',async t=>{
 const text=new NsrtCodec().encode({type:'Profile',payload:{profileName:'NSRT fixture',data:{ReminderSettings:{SpellDuration:4}},sharedData:{EncounterAlerts:{3379:{15:{r:{enabled:true,DisplayType:'Icon',spellID:22812,text:'Defensive',TTS:'Barkskin now',phaseTimers:{1:[20.5],2:[8]},loadConditions:{SpecIDs:{104:true},Roles:{HEALER:true}}}},16:{r:{DisplayType:'Text',text:'Move',timers:[30],phase:1}}}}}},numericKeys:[]});
 const out=await run(t,text,`local name,error,report=ns.Import(input);assert(name,error);assert(report.converted==3);local count=0;for _,e in pairs(ns.Active().data.raidReminders[3379])do count=count+1;if e.display.type=='icon'then assert(e.target.matchAny and e.target.specs['104']and e.target.roles.HEALER and e.display.ttsText=='Barkskin now')end end;assert(count==3)`);if(out){assert.equal(Object.values(out.data.raidReminders['3379']).length,3);assert.ok(Object.values(out.data.raidReminders['3379']).some(r=>r.trigger.delay===20.5));}
});
test('current private unlicensed NSR input imports through the published-format game adapter and remains exportable after scope initialization',async t=>{
 if(!process.env.DOCTOR_NSR_MIGRATION_INPUT)return;const input=await fs.readFile(process.env.DOCTOR_NSR_MIGRATION_INPUT,'utf8'),source=codec.decode(input),custom=Object.values(source.data.customReminders||{}).flatMap(Object.values).length;
 const out=await run(t,input,`local name,error,report=ns.Import(input);assert(name,error);assert(report.converted==${custom});local ok,error=ns.EditProfile(function(data)data.settings.showIcon=true end);assert(ok,error)`);if(out)assert.equal(Object.keys(out.data.scopePresets.mythic).length,40);
});
test('native in-game NSRT importer accepts single-alert and group exports, glow units and pre-pull times',async t=>{
 const alert={enabled:true,DisplayType:'Icon',spellID:22812,text:'Pot',dur:3,timers:[-5,20],phase:1,glowunit:'Tankadin Healbot glowunit',glowColors:[0,1,0,1],loadConditions:{}};
 const single=new NsrtCodec().encode({type:'EncounterAlert',payload:{version:1,type:'single_alert',alertType:'user',encID:3379,diffID:16,alertKey:'pot',data:alert},numericKeys:[]});
 const out=await run(t,single,`local name,error,report=ns.Import(input);assert(name,error);assert(report.converted==2,report.converted);local pre,pull
  for _,e in pairs(ns.Active().data.raidReminders[3379])do if e.trigger.type=='prepull'then pre=e else pull=e end end
  assert(pre and pre.trigger.delay==5 and pre.trigger.leadTime==3 and pre.display.dur==3);assert(pull and pull.trigger.type=='pull'and pull.trigger.delay==20)
  assert(#pre.display.glowTargets==2 and pre.display.glowTargets[1]=='Tankadin'and pre.display.glowColor[2]==1);assert(ns.Active().minimumAddon=='0.3.3')
  assert(ns.EditProfile(function(data)data.settings.voiceOn=false end));assert(ns.Active().minimumAddon=='0.3.3')`);
 if(out){const rs=Object.values(out.data.raidReminders['3379']);assert.equal(out.minimumAddon,'0.3.3');assert.ok(rs.some(r=>r.trigger.type==='prepull'&&r.trigger.delay===5));}
 const group=new NsrtCodec().encode({type:'EncounterAlert',payload:{version:1,type:'alert_group',groupName:'G',groupEncID:3379,diffID:15,encounterAlerts:{3379:{15:{a:{DisplayType:'Text',text:'Soak',timers:[30],phase:1}},16:{b:{DisplayType:'Text',text:'Other',timers:[40],phase:1}}}}},numericKeys:[]});
 await run(t,group,`local name,error,report=ns.Import(input);assert(name,error);assert(report.converted==1);local _,e=next(ns.Active().data.raidReminders[3379]);assert(e.difficulties[15]and e.display.text=='Soak');assert(ns.Active().minimumAddon=='0.3.0')`);
});

test('native in-game importer reads Timeline Reminders !TR2: strings: pull and spell-relative times, looks, recipients',async t=>{
 const reminder=(o)=>({load:{type:'ALL'},trigger:{time:30,duration:5,linger:0},display:{region:'TEXT',type:'TEXT',text:'Move',spellID:0,spellText:'',ticks:[],color:{r:1,g:1,b:1}},tts:{enabled:false},sound:{enabled:false},countdown:{enabled:false},glow:{enabled:false,names:[]},...o});
 const chunk=(id,d,r)=>'!TR2:'+deflateRawSync(encodeCbor({v:60,id,d,r})).toString('base64');
 const text=chunk(3176,2,{
  a:reminder({load:{type:'CLASS_SPEC',class:'DRUID',spec:3},trigger:{time:45,duration:8,linger:2},display:{region:'BAR',type:'SPELL',spellID:22812,spellText:'Bark',ticks:[2,4],color:{r:1,g:0,b:0}},tts:{enabled:true,alias:'Barkskin'},glow:{enabled:true,names:['Tankadin'],color:{r:0,g:1,b:0}}}),
  b:reminder({load:{type:'ROLE',role:'HEALER'},trigger:{time:10,duration:4,linger:0,relativeTo:{event:'SPELL_CAST_START',value:1249262,count:2}}}),
  c:reminder({trigger:{time:5,duration:3,linger:0,relativeTo:{event:'UNIT_DIED',value:12345,count:1}}}),
  d:reminder({load:{type:'POSITION',position:'MELEE'},countdown:{enabled:true},sound:{enabled:true,file:'Interface\\Addons\\TimelineReminders\\Media\\Sounds\\TR_Beep.mp3'}})
 })+'\n'+chunk(3177,1,{e:reminder({load:{type:'GROUP',group:3}})});
 const out=await run(t,text,`local name,error,report=ns.Import(input);assert(name,error);assert(report.converted==4,report.converted)
 local issues=table.concat(report.issues,'|');assert(issues:match('UNIT_DIED'),issues);assert(issues:match('Sound from the Timeline'),issues)
 local found={}
 for _,e in pairs(ns.Active().data.raidReminders[3176])do found[e.pztkMigration.key]=e end
 local a,b,d=found.a,found.b,found.d
 assert(a.difficulties[16]and a.trigger.type=='pull'and a.trigger.delay==45 and a.trigger.leadTime==8)
 assert(a.display.type=='bar'and a.display.spellID==22812 and a.display.text=='Bark'and a.display.sticky==2 and a.display.ticks[2]==4 and a.display.barColor[1]==1 and a.display.ttsText=='Barkskin')
 assert(a.target.specs[104]and a.display.glowTargets[1]=='Tankadin'and a.display.glowColor[2]==1)
 assert(b.trigger.type=='bwmsg'and b.trigger.spellID==1249262 and b.trigger.delay==6 and b.trigger.counterGroups[1][1].value==2 and b.target.roles.HEALER)
 assert(d.target.matchAny and d.target.specs[71]and not d.target.specs[62]and d.display.countdown and d.display.sound==nil)
 local e=next(ns.Active().data.raidReminders[3177]);e=ns.Active().data.raidReminders[3177][e];assert(e.difficulties[15]and e.target.subgroups[3])
 assert(ns.Active().minimumAddon=='0.6.5')`);
 if(out)assert.equal(Object.keys(out.data.raidReminders['3176']).length,3);
});

test('native in-game importer reads the older Timeline Reminders !TR: (LibSerialize) strings',async t=>{
 await run(t,'unused',`local ser,ld=LibStub('LibSerialize'),LibStub('LibDeflate')
 local r={load={type='NAME',name='Healbot'},trigger={time=20,duration=6},display={region='ICON',type='SPELL',spellID=61336,spellText='',text='',color={r=1,g=1,b=1}}}
 local s='!TR:'..ld:EncodeForPrint(ld:CompressDeflate(ser:Serialize({v=50,id=3176,d=1,r={x=r}})))
 local name,error,report=ns.Import(s);assert(name,error);assert(report.converted==1)
 local _,e=next(ns.Active().data.raidReminders[3176]);assert(e.display.type=='icon'and e.display.spellID==61336 and e.target.names.Healbot and e.difficulties[15])
 assert(not ns.DecodeImport('!TR2:notbase64!'))`);
});
