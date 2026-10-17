import fs from 'node:fs';
import path from 'node:path';
import fengari from 'fengari';
import {deflateRawSync,inflateRawSync} from 'node:zlib';
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=fengari;
function push(L,value,depth=0){if(depth>32)throw Error('Pack is too deeply nested');if(value==null)lua.lua_pushnil(L);else if(typeof value==='string')lua.lua_pushstring(L,to_luastring(value));else if(typeof value==='number'){if(!Number.isFinite(value))throw Error('Invalid pack number');lua.lua_pushnumber(L,value);}else if(typeof value==='boolean')lua.lua_pushboolean(L,value);else if(typeof value==='object'){lua.lua_newtable(L);for(const [key,v] of Object.entries(value)){if(v===undefined)continue;if(Array.isArray(value))lua.lua_pushinteger(L,Number(key)+1);else lua.lua_pushstring(L,to_luastring(key));push(L,v,depth+1);lua.lua_settable(L,-3);}}else throw Error('Unsupported pack value');}
function read(L,index,seen=new Set(),budget={n:100000},depth=0){if(--budget.n<0||depth>32)throw Error('Decoded pack exceeds limits');index=lua.lua_absindex(L,index);switch(lua.lua_type(L,index)){case lua.LUA_TNIL:return null;case lua.LUA_TBOOLEAN:return Boolean(lua.lua_toboolean(L,index));case lua.LUA_TNUMBER:return lua.lua_tonumber(L,index);case lua.LUA_TSTRING:return lua.lua_tojsstring(L,index);case lua.LUA_TTABLE:{const pointer=lua.lua_topointer(L,index);if(seen.has(pointer))throw Error('Cyclic pack');seen.add(pointer);const result={};lua.lua_pushnil(L);while(lua.lua_next(L,index)){const key=read(L,-2,seen,budget,depth+1);if(!['string','number'].includes(typeof key)||['__proto__','constructor','prototype'].includes(String(key)))throw Error('Unsupported pack key');result[key]=read(L,-1,seen,budget,depth+1);lua.lua_pop(L,1);}seen.delete(pointer);return result;}default:throw Error('Unsupported serialized type');}}
export class PackCodec {
  constructor(resources){this.resources=resources;}
  invoke(fn,arg){const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);let ticks=0;
    lua.lua_sethook(L,()=>{if(++ticks>10000)lauxlib.luaL_error(L,to_luastring('Pack operation exceeded processing limit'));},lua.LUA_MASKCOUNT,10000);
    function execute(code){if(lauxlib.luaL_loadstring(L,to_luastring(code))!==lua.LUA_OK||lua.lua_pcall(L,0,0,0)!==lua.LUA_OK)throw Error(lua.lua_tojsstring(L,-1));}
    try{
      execute('strmatch = string.match; math.pow = math.pow or function(a,b) return a^b end; math.ldexp = math.ldexp or function(a,b) return a*2^b end; loadstring = loadstring or load; unpack = table.unpack');
      for(const file of ['LibStub.lua','LibSerialize.lua'])execute(fs.readFileSync(path.join(this.resources,'codec',file),'utf8'));
      execute(`function doctor_encode(payload) return LibStub('LibSerialize'):Serialize(payload) end
function doctor_decode(str) local ok,payload=LibStub('LibSerialize'):Deserialize(str); assert(ok,'Invalid serialization'); return payload end`);
      lua.lua_getglobal(L,to_luastring('doctor_'+fn));if(Buffer.isBuffer(arg))lua.lua_pushlstring(L,new Uint8Array(arg),arg.length);else push(L,arg);
      if(lua.lua_pcall(L,1,1,0)!==lua.LUA_OK)throw Error(lua.lua_tojsstring(L,-1));return fn==='encode'?Buffer.from(lua.lua_tolstring(L,-1)):read(L,-1);
    }finally{lua.lua_close(L);}
  }
  decode(input){const str=String(input).replace(/\s+/g,'');if(str.includes(':LIC1:'))throw Error('Account-licensed packs must be managed in the addon. This app does not remove or bypass licenses.');if(!str.startsWith('NSRPACK2:')||str.length>130000)throw Error('Expected an NSRPACK2 string under 130 KB');const pack=this.invoke('decode',inflateRawSync(decodePrint(str.slice(9)),{maxOutputLength:4000000}));if(pack?.licensed||pack?.derivedFrom)throw Error('Re-sharing licensed or derived packs is not supported');if(pack.format!==1||(!pack.data&&!pack.profiles))throw Error('Unsupported pack format');return pack;}
  encode(pack){if(pack.licensed||pack.derivedFrom)throw Error('Export of licensed or derived packs is not supported');if(pack.format!==1||!pack.data||typeof pack.name!=='string')throw Error('Invalid pack metadata');const str='NSRPACK2:'+encodePrint(deflateRawSync(this.invoke('encode',pack)));this.decode(str);return str;}
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
