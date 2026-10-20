import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {encodeCbor,decodeCbor} from '../core/cbor.mjs';
import {NsrtCodec} from '../core/nsrt.mjs';
import {DoctorService} from '../core/service.mjs';
const resources=path.resolve('resources');
async function fixture(t){const dir=await fs.mkdtemp(path.join(os.tmpdir(),'pztk-nsrt-'));t.after(()=>fs.rm(dir,{recursive:true,force:true}));return new DoctorService(dir,resources).init();}
test('CBOR matches RFC encodings and preserves float phases, booleans, byte strings and numeric Lua map keys',()=>{
 for(const [value,hex]of [[0,'00'],[24,'1818'],[-1,'20'],[false,'f4'],[true,'f5'],[null,'f6'],['a','6161'],[[1,2],'820102']]){assert.equal(encodeCbor(value).toString('hex'),hex);assert.deepEqual(decodeCbor(Buffer.from(hex,'hex')).data,value);}
 const value={a:{15:{1.5:[3.2,true,Buffer.from([1,2])]}}},paths=[['a','15'],['a','15','1.5']],decoded=decodeCbor(encodeCbor(value,paths));assert.deepEqual(decoded.data,value);assert.deepEqual(decoded.numericKeys,paths);assert.throws(()=>decodeCbor(Buffer.from('a16161','hex')),/Truncated/);assert.throws(()=>decodeCbor(Buffer.from('a2695f5f70726f746f5f5f00','hex')),/Unsafe/);
});
test('NSRT current profiles roundtrip unknown fields and binary values through persistent storage and visual editing',async t=>{
 const s=await fixture(t),codec=new NsrtCodec();
 const original={type:'Profile',payload:{profileName:'Original',data:{Settings:{marker:'keep'},customBytes:Buffer.from([255,0,123])},sharedData:{AuraSounds:{retain:true},EncounterAlerts:{}}},numericKeys:[['sharedData','EncounterAlerts','3470'],['sharedData','EncounterAlerts','3470','15'],['sharedData','EncounterAlerts','3470','15','custom','loadConditions','SpecIDs','264']]};
 original.payload.sharedData.EncounterAlerts['3470']={'15':{custom:{name:'Keep',enabled:true,spellID:108271,phase:1,timers:[30],loadConditions:{SpecIDs:{264:true}},unknown:'preserve'}}};

 let v=await s.handle('nsrt.import',{text:codec.encode(original),client:'forever'});assert.equal(v.client,'forever');assert.equal(v.entries[0].specIds[0],264);
 v=await s.handle('nsrt.edit',{id:v.id,revision:v.revision,encounterId:3470,difficulty:15,key:'custom',name:'Edited',spellId:98008,specId:264,text:'Spirit Link',timers:{1:[25,55],1.5:[10]},enabled:true});
 const output=await s.handle('nsrt.export',{id:v.id}),decoded=codec.decode(output.text);assert.equal(decoded.payload.data.Settings.marker,'keep');assert.deepEqual(decoded.payload.data.customBytes,Buffer.from([255,0,123]));assert.equal(decoded.payload.sharedData.AuraSounds.retain,true);assert.equal(decoded.payload.sharedData.EncounterAlerts['3470']['15'].custom.unknown,'preserve');assert.ok(decoded.numericKeys.some(p=>p.at(-1)==='1.5'));await assert.rejects(()=>s.handle('nsrt.edit',{id:v.id,revision:0,encounterId:3470,difficulty:15,key:'custom',remove:true}),/changed elsewhere/);
});
test('shared raid assignments generate native NSRT profile with numeric encounter/difficulty/spec keys and separate schedules',async t=>{
 const s=await fixture(t),p=await s.handle('planner.createProfile');let v=await s.handle('nsr.open',{profileId:p.id});v=await s.handle('nsr.change',{id:v.id,revision:v.revision,operation:{kind:'preset.save',args:{specId:264,key:'personal',name:'Shaman',spells:[{spellId:108271,name:'Astral Shift'},{spellId:98008,name:'Spirit Link Totem'}]}}});v=await s.handle('nsr.assignRaid',{id:v.id,revision:v.revision,specId:264,seasonId:'MidnightS2',encounterId:3470,spellId:1284103,difficulty:'heroic',preset:'personal'});
 const result=await s.handle('nsrt.fromNsr',{id:v.id,revision:v.revision,client:'retail'});assert.equal(result.generated,2);assert.equal(result.profile.entries.length,2);const out=await s.handle('nsrt.export',{id:result.profile.id}),decoded=s.nsrt.codec.decode(out.text);assert.match(out.text,/^!NSRT:Profile:/);const a=decoded.payload.sharedData.EncounterAlerts['3470']['15'].pztk_264_1284103;assert.equal(a.spellID,108271);assert.deepEqual(a.pztkDefensiveSet,[108271,98008]);assert.equal(a.loadConditions.SpecIDs['264'],true);assert.ok(a.phaseTimers['1'].length>0);assert.equal(a.ReloeReminder,false);assert.ok(decoded.numericKeys.some(p=>p.at(-1)==='3470'));await assert.rejects(()=>s.handle('nsrt.fromNsr',{id:v.id,revision:v.revision,client:'forever'}),/Retail data/);
 if(process.env.DOCTOR_LUA51&&process.env.DOCTOR_NSRT_TEST_ROOT){await validateInAddon(s.dataDir,out.text,process.env.DOCTOR_NSRT_TEST_ROOT);}
});
async function validateInAddon(dir,text,root){
 const input=path.join(dir,'native-nsrt.txt');await fs.writeFile(input,text);
 const script=`strmatch=string.match
 dofile(${JSON.stringify(resources+'/codec/LibStub.lua')})
 dofile(${JSON.stringify(resources+'/codec/LibDeflate.lua')})
 local function cbor(s)
  local at=1
  local function read(n)local r=s:sub(at,at+n-1);assert(#r==n);at=at+n;return r end
  local function uint(n)local v=0;for i=1,n do v=v*256+read(1):byte()end;return v end
  local function arg(n)if n<24 then return n end;return uint(({[24]=1,[25]=2,[26]=4,[27]=8})[n])end
  local item
  item=function()local h=read(1):byte();local m,a=math.floor(h/32),h%32
   if m==7 then if a==20 then return false elseif a==21 then return true elseif a==22 then return nil elseif a==27 then local hi,lo=uint(4),uint(4);local sign=hi>=2147483648 and -1 or 1;local e=math.floor(hi/1048576)%2048;local f=(hi%1048576)*4294967296+lo;return sign*2^(e-1023)*(1+f/4503599627370496)end end
   local n=arg(a);if m==0 then return n elseif m==1 then return -1-n elseif m==3 then return read(n) elseif m==4 then local t={};for i=1,n do t[i]=item()end;return t elseif m==5 then local t={};for i=1,n do local k=item();t[k]=item()end;return t end;error('Unsupported test CBOR')
  end
  return item()
 end
 local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'
 local function base64(s)local bits,count,result=0,0,{};for ch in s:gmatch('.')do local at=alphabet:find(ch,1,true);if at then bits=bits*64+at-1;count=count+6;if count>=8 then count=count-8;local n=math.floor(bits/2^count);result[#result+1]=string.char(n);bits=bits-n*2^count end end end;return table.concat(result)end
 C_EncodingUtil={DecodeBase64=base64,DecompressString=function(s)return LibStub('LibDeflate'):DecompressDeflate(s)end,DeserializeCBOR=cbor}
 Enum={CompressionMethod={Deflate=1},Base64Variant={StandardUrlSafe=1}}
 NSAPI={};NSRT={Profiles={}}
 function CopyTable(t)local o={};for k,v in pairs(t)do o[k]=type(v)=='table' and CopyTable(v)or v end;return o end
 local ns={Callbacks={}}
 assert(loadfile(${JSON.stringify(root+'/Functions.lua')}))('NorthernSkyRaidTools',ns)
 assert(loadfile(${JSON.stringify(root+'/Profiles.lua')}))('NorthernSkyRaidTools',ns)
 function ns:LoadProfile(name)self.loaded=name end
 function ns:AddMissingDefaults()end
 function ns:FireCallback()end
 local f=assert(io.open(${JSON.stringify(input)},'rb'));local encoded=f:read('*a');f:close()
 local decoded=assert(ns:DecodeExportData(encoded,'Profile'))
 assert(decoded.sharedData.EncounterAlerts[3470][15].pztk_264_1284103.loadConditions.SpecIDs[264])
 local name=assert(NSAPI:ImportProfileString(encoded,'Desktop test',true));assert(ns.loaded==name)
 local alert=NSRT.EncounterAlerts[3470][15].pztk_264_1284103
 assert(alert.spellID==108271 and alert.IsAlert and alert.enabled)
 assert(alert.phaseTimers[1][1]>0 and alert.loadConditions.SpecIDs[264])
 assert(loadfile(${JSON.stringify(root+'/Reminders.lua')}))('NorthernSkyRaidTools',ns)
 function ns:DifficultyCheck()return 15 end
 function ns:GetMySpecID()return 264 end
 assert(ns:EvaluateLoad(alert,true,true))
 function ns:GetMySpecID()return 256 end
 assert(not ns:EvaluateLoad(alert,true,true))
 print('NATIVE_NSRT_PROFILE_ACCEPTED')
 `;
 const file=path.join(dir,'native-nsrt.lua');await fs.writeFile(file,script);assert.match(execFileSync(process.env.DOCTOR_LUA51,[file],{encoding:'utf8'}),/NATIVE_NSRT_PROFILE_ACCEPTED/);
}

test('NSRT edits retain imported load filters unless explicitly changed; moving an alert and undo do not duplicate it',async t=>{
 const s=await fixture(t);let v=await s.handle('nsrt.create',{client:'forever'});v=await s.handle('nsrt.edit',{id:v.id,revision:v.revision,encounterId:123,difficulty:15,key:'test',name:'First',spellId:498,specId:65,text:'First',timers:{1:[20]}});
 v=await s.handle('nsrt.edit',{id:v.id,revision:v.revision,encounterId:124,difficulty:16,originalEncounterId:123,originalDifficulty:15,key:'test',name:'Moved',spellId:498,text:'Moved',timers:{1:[25]}});assert.equal(v.entries.length,1);assert.equal(v.entries[0].encounterId,124);assert.deepEqual(v.entries[0].specIds,[65]);v=await s.handle('nsrt.undo',{id:v.id,revision:v.revision});assert.equal(v.entries.length,1);assert.equal(v.entries[0].encounterId,123);assert.equal(v.entries[0].text,'First');
});
