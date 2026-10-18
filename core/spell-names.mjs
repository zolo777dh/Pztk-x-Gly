import fs from 'node:fs/promises';
import path from 'node:path';
import {writeAtomic} from './files.mjs';
import {SPELL_NAMES} from './wow-names.mjs';
export class SpellNames{
 constructor(dir,fetcher=globalThis.fetch){this.file=path.join(dir,'spell-names.json');this.fetcher=fetcher;this.loaded=false;this.names={...SPELL_NAMES};this.pending=new Map();this.failed=new Map();this.saveQueue=Promise.resolve();}
 async load(){if(this.loaded)return;try{const saved=JSON.parse(await fs.readFile(this.file,'utf8'));for(const [id,name]of Object.entries(saved.names||{}))if(/^\d+$/.test(id)&&typeof name==='string'&&name.length<=200)this.names[id]=name;}catch(e){if(e.code!=='ENOENT')this.warning='Name cache unavailable; imported labels remain usable.';}this.loaded=true;}
 async resolve(ids,{online=true}={}){await this.load();const wanted=[...new Set((ids||[]).map(Number))];if(wanted.length>100||wanted.some(id=>!Number.isInteger(id)||id<=0||id>100000000))throw Error('Resolve 1–100 positive spell IDs at a time');
  const unknown=wanted.filter(id=>!this.names[id]);if(online){let next=0;const worker=async()=>{while(next<unknown.length){const id=unknown[next++];if(this.failed.get(id)>Date.now()-300000)continue;if(this.pending.has(id)){await this.pending.get(id);continue;}const work=(async()=>{try{const response=await this.fetcher('https://nether.wowhead.com/tooltip/spell/'+id+'?dataEnv=1&locale=0',{headers:{Accept:'application/json'},redirect:'error',signal:AbortSignal.timeout(4500)});if(!response.ok)throw Error('HTTP '+response.status);const data=await response.json();if(typeof data.name!=='string'||!data.name.trim()||data.name.length>200)throw Error('Missing spell name');this.names[id]=data.name.trim();}catch{this.failed.set(id,Date.now());}})();this.pending.set(id,work);try{await work;}finally{this.pending.delete(id);}}};await Promise.all(Array.from({length:Math.min(5,unknown.length)},worker));
   const save=this.saveQueue.catch(()=>{}).then(()=>writeAtomic(this.file,JSON.stringify({names:this.names})));this.saveQueue=save;try{await save;}catch{this.warning='Resolved names could not be cached; they remain available for this session.';}
  }
  return {names:Object.fromEntries(wanted.filter(id=>this.names[id]).map(id=>[id,this.names[id]])),unresolved:wanted.filter(id=>!this.names[id]),source:'English spell labels; imported labels take priority',warning:this.warning||''};
 }
}
