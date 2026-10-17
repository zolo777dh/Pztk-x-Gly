import fs from 'node:fs';
import path from 'node:path';
import fengari from 'fengari';
import {deflateRawSync,inflateRawSync} from 'node:zlib';
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=fengari;
export const PACK_LIMITS=Object.freeze({inputCharacters:130000,decompressedBytes:4000000,expandedBytes:16000000,totalEntries:1000000,depth:64,profileEntries:100000,profileDepth:32,processingMilliseconds:10000});

function dataBounds(data,label){
  let entries=0;const pending=[{value:data,depth:0}];
  while(pending.length){const {value,depth}=pending.pop();if(!value||typeof value!=='object')continue;
    if(depth>PACK_LIMITS.profileDepth)throw Error(`Pack ${label} exceeds the NSR data nesting limit (${PACK_LIMITS.profileDepth} table levels).`);
    for(const key of Object.keys(value)){if(++entries>PACK_LIMITS.profileEntries)throw Error(`Pack ${label} exceeds the NSR data limit (${PACK_LIMITS.profileEntries.toLocaleString('en-US')} table entries per profile).`);const child=value[key];if(child&&typeof child==='object')pending.push({value:child,depth:depth+1});}
  }
}
export function validatePackBounds(pack){
  const table=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
  if(!table(pack)||pack.format!==1)throw Error('Unsupported pack format');
  const profiles=table(pack.profiles)?Object.entries(pack.profiles):[];
  if(profiles.length){for(const [name,data]of profiles){if(!name||!table(data))throw Error('Invalid pack profile');dataBounds(data,'profile');}}
  else{if(!table(pack.data))throw Error('Unsupported pack format: expected data or named profiles');dataBounds(pack.data,'data');}
  return pack;
}

function push(L,value,depth=0,numericKeys=null,treePath=[]){
  if(!lua.lua_checkstack(L,8))throw Error('Pack operation exceeded the Lua stack limit');if(depth>PACK_LIMITS.depth)throw Error(`Pack exceeds the inspection nesting limit (${PACK_LIMITS.depth} table levels)`);
  if(value==null)lua.lua_pushnil(L);else if(typeof value==='string')lua.lua_pushstring(L,to_luastring(value));else if(typeof value==='number'){if(!Number.isFinite(value))throw Error('Invalid pack number');lua.lua_pushnumber(L,value);}else if(typeof value==='boolean')lua.lua_pushboolean(L,value);else if(typeof value==='object'){
    lua.lua_newtable(L);for(const [key,v]of Object.entries(value)){if(v===undefined)continue;const childPath=numericKeys?[...treePath,String(key)]:[];if(Array.isArray(value))lua.lua_pushinteger(L,Number(key)+1);else if(numericKeys?.has(JSON.stringify(childPath))){if(!Number.isFinite(Number(key)))throw Error('Invalid numeric Lua key');lua.lua_pushnumber(L,Number(key));}else lua.lua_pushstring(L,to_luastring(key));push(L,v,depth+1,numericKeys,childPath);lua.lua_settable(L,-3);}
  }else throw Error('Unsupported pack value');
}
function read(L,index,state,depth=0,treePath=[]){
  if(!lua.lua_checkstack(L,8))throw Error('Pack inspection exceeded the Lua stack limit');
  index=lua.lua_absindex(L,index);
  const addBytes=n=>{state.bytes+=n;if(state.bytes>PACK_LIMITS.expandedBytes)throw Error(`Decoded pack exceeds the expanded JSON limit (${PACK_LIMITS.expandedBytes.toLocaleString('en-US')} bytes). Split the pack into smaller exports.`);};
  switch(lua.lua_type(L,index)){
    case lua.LUA_TNIL:addBytes(4);return null;
    case lua.LUA_TBOOLEAN:{const value=Boolean(lua.lua_toboolean(L,index));addBytes(value?4:5);return value;}
    case lua.LUA_TNUMBER:{const value=lua.lua_tonumber(L,index);if(!Number.isFinite(value))throw Error('Invalid pack number');addBytes(String(value).length);return value;}
    case lua.LUA_TSTRING:{const value=lua.lua_tojsstring(L,index);addBytes(Buffer.byteLength(JSON.stringify(value)));return value;}
    case lua.LUA_TTABLE:{
      if(depth>PACK_LIMITS.depth)throw Error(`Decoded pack exceeds the inspection nesting limit (${PACK_LIMITS.depth} table levels).`);
      const pointer=lua.lua_topointer(L,index);if(state.seen.has(pointer))throw Error('Cyclic pack');state.seen.add(pointer);addBytes(2);const result={};let first=true;
      lua.lua_pushnil(L);
      while(lua.lua_next(L,index)){
        if(++state.entries>PACK_LIMITS.totalEntries)throw Error(`Decoded pack exceeds the total inspection limit (${PACK_LIMITS.totalEntries.toLocaleString('en-US')} table entries). Split the pack into smaller exports.`);
        if(state.entries%1024===0&&Date.now()>state.deadline)throw Error('Pack inspection exceeded its processing time limit. Split the pack into smaller exports.');
        const kind=lua.lua_type(L,-2);if(kind!==lua.LUA_TSTRING&&kind!==lua.LUA_TNUMBER)throw Error('Unsupported pack key');
        const key=kind===lua.LUA_TSTRING?lua.lua_tojsstring(L,-2):lua.lua_tonumber(L,-2);
        if((typeof key==='number'&&!Number.isFinite(key))||['__proto__','constructor','prototype'].includes(String(key)))throw Error('Unsupported pack key');
        addBytes(Buffer.byteLength(JSON.stringify(String(key)))+1+(first?0:1));first=false;
        if(Object.hasOwn(result,String(key)))throw Error('Pack has colliding numeric and string Lua keys; editable import is unsupported');const childPath=state.numericKeys?[...treePath,String(key)]:[];if(state.numericKeys&&kind===lua.LUA_TNUMBER)state.numericKeys.push(childPath);result[key]=read(L,-1,state,depth+1,childPath);lua.lua_pop(L,1);
      }
      state.seen.delete(pointer);return result;
    }
    default:throw Error('Unsupported serialized type');
  }
}
export class PackCodec {
  constructor(resources){this.resources=resources;}
  invoke(fn,arg,options={}){const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);let ticks=0;const deadline=Date.now()+PACK_LIMITS.processingMilliseconds;
    lua.lua_sethook(L,()=>{if(++ticks>20000||Date.now()>deadline)lauxlib.luaL_error(L,to_luastring('Pack operation exceeded processing limit'));},lua.LUA_MASKCOUNT,10000);
    function execute(code){if(lauxlib.luaL_loadstring(L,to_luastring(code))!==lua.LUA_OK||lua.lua_pcall(L,0,0,0)!==lua.LUA_OK)throw Error(lua.lua_tojsstring(L,-1));}
    try{
      execute('strmatch = string.match; math.pow = math.pow or function(a,b) return a^b end; math.ldexp = math.ldexp or function(a,b) return a*2^b end; loadstring = loadstring or load; unpack = table.unpack');
      for(const file of ['LibStub.lua','LibSerialize.lua'])execute(fs.readFileSync(path.join(this.resources,'codec',file),'utf8'));
      execute(`function doctor_encode(payload) return LibStub('LibSerialize'):Serialize(payload) end
function doctor_decode(str) local ok,payload=LibStub('LibSerialize'):Deserialize(str); assert(ok,'Invalid serialization'); return payload end`);
      lua.lua_getglobal(L,to_luastring('doctor_'+fn));if(Buffer.isBuffer(arg))lua.lua_pushlstring(L,new Uint8Array(arg),arg.length);else push(L,arg,0,options.numericKeys?.length?new Set(options.numericKeys.map(p=>JSON.stringify(p))):null);
      if(lua.lua_pcall(L,1,1,0)!==lua.LUA_OK)throw Error(lua.lua_tojsstring(L,-1));if(fn==='encode')return Buffer.from(lua.lua_tolstring(L,-1));const state={seen:new Set(),entries:0,bytes:0,deadline,numericKeys:options.trackKeys?[]:null};const pack=read(L,-1,state);return options.trackKeys?{pack,numericKeys:state.numericKeys}:pack;
    }finally{lua.lua_close(L);}
  }
  decode(input,{withKeys=false}={}){
    const str=String(input).replace(/\s+/g,'');
    if(str.includes(':LIC1:'))throw Error('Account-licensed packs must be managed in the addon. This app does not remove or bypass licenses.');
    if(!str.startsWith('NSRPACK2:')||str.length>PACK_LIMITS.inputCharacters)throw Error('Expected an NSRPACK2 string under 130 KB');
    let serialized;try{serialized=inflateRawSync(decodePrint(str.slice(9)),{maxOutputLength:PACK_LIMITS.decompressedBytes});}catch(error){if(error.code==='ERR_BUFFER_TOO_LARGE')throw Error('Pack exceeds the decompressed-data limit (4,000,000 bytes). Split the pack into smaller exports.');throw Error('Invalid or damaged pack compression/encoding.');}
    const result=this.invoke('decode',serialized,{trackKeys:withKeys});const pack=withKeys?result.pack:result;
    if(pack?.licensed||pack?.derivedFrom)throw Error('Re-sharing licensed or derived packs is not supported');
    validatePackBounds(pack);return withKeys?result:pack;
  }
  encode(pack,{numericKeys=[]}={}){if(pack.licensed||pack.derivedFrom)throw Error('Export of licensed or derived packs is not supported');if(pack.format!==1||!(pack.data||pack.profiles)||typeof pack.name!=='string')throw Error('Invalid pack metadata');validatePackBounds(pack);const str='NSRPACK2:'+encodePrint(deflateRawSync(this.invoke('encode',pack,{numericKeys})));this.decode(str);return str;}
}
const alphabet='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789()';
function encodePrint(bytes){let cache=0,bits=0,result='';for(const byte of bytes){cache+=byte*2**bits;bits+=8;while(bits>=6){result+=alphabet[cache%64];cache=Math.floor(cache/64);bits-=6;}}if(bits>0)result+=alphabet[cache%64];return result;}
function decodePrint(text){let cache=0,bits=0,result=[];if(text.length%4===1)throw Error('Invalid print encoding');for(const char of text){const value=alphabet.indexOf(char);if(value<0)throw Error('Invalid print encoding');cache+=value*2**bits;bits+=6;while(bits>=8){result.push(cache%256);cache=Math.floor(cache/256);bits-=8;}}return Buffer.from(result);}
export function noteToPack(note){
  if(note.client==='forever')throw Error('Smart Reminders pack export is currently verified only for the supplied Retail addon. Notes can still be exported as JSON/text.');
  if(!Number.isInteger(Number(note.encounterId))||Number(note.encounterId)<=0)throw Error('Set and confirm the in-game encounter ID before exporting a pack');
  const reminders={};
  for(const [i,event]of (note.events||[]).entries()){
    if(event.include===false)continue;
    if(!Number.isFinite(Number(event.time))||Number(event.time)<0||Number(event.time)>7200)throw Error('Reminder time must be 0–7200 seconds');
    if(!event.text?.trim())continue;
    if(!Number.isFinite(Number(event.lead||0))||Number(event.lead||0)<0||Number(event.lead||0)>120)throw Error('Reminder lead must be 0–120 seconds');
    if(!['ALL','TANK','HEALER','DAMAGER'].includes(event.role||'ALL'))throw Error('Unsupported reminder role');
    if(event.text.length>2000)throw Error('Reminder text exceeds 2000 characters');
    const target=event.role&&event.role!=='ALL'?{roles:{[event.role]:true}}:{all:true};
    reminders['pztk_'+i]={name:event.text.slice(0,120),enabled:true,trigger:{type:'pull',delay:Number(event.time),leadTime:Number(event.lead||0)},target,display:{type:'text',text:event.text,dur:Number(event.duration||5)}};
  }
  if(!Object.keys(reminders).length)throw Error('Add at least one reminder row');
  return {format:1,name:note.title||'Pztk encounter notes',author:note.author||'Pztk x Glyalith',made:new Date().toISOString().slice(0,10),data:{raidReminders:{[String(note.encounterId)]:reminders}}};
}
