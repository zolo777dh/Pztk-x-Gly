import fs from 'node:fs/promises';
import path from 'node:path';
import {uid,sha,writeAtomic} from './files.mjs';
import {SPEC_NAMES,SPELL_NAMES} from './wow-names.mjs';
import {parseReference} from './encounters.mjs';
const integer=(v,min=1,max=100000000)=>Number.isInteger(Number(v))&&Number(v)>=min&&Number(v)<=max;
const object=v=>v&&typeof v==='object'&&!Array.isArray(v);
const spellList=v=>Array.isArray(v)?v.map(Number).filter(n=>integer(n)):Object.keys(v||{}).sort((a,b)=>Number(a)-Number(b)).map(k=>Number(v[k])).filter(n=>integer(n));
export function inspectDefenseTable(text,filename){const ref=parseReference(text,filename);return {kind:ref.kind,mechanics:ref.assignments?.length||0};}
export function parseDefenseTable(text,filename,{defaults={}}={}){
 const reference=parseReference(text,filename);
 if(reference.kind!=='cooldown-priority-reference')throw Error('No supported defensive sets with spell IDs were found in this HTML / JSON reference.');
 const mechanics=reference.assignments.filter(a=>integer(a.cast)).map(a=>({dungeon:a.dungeon||'',encounter:a.encounter,kind:/trash/i.test(a.type||'')?'trash':'boss',bossSpellId:Number(a.cast),bossAbility:a.ability,referencePreset:a.preset,timerSpellId:Number(a.cast)}));
 return {id:sha(JSON.stringify({text,specId:defaults.specId||0})).slice(0,16),filename,kind:'priority-reference',mechanics,presets:reference.presets.map(p=>({...p,specId:Number(p.specId)||Number(defaults.specId)||0})),observations:[],warning:''};
}
export function profileDescription(pack){
  const profiles=pack.profiles?Object.entries(pack.profiles):[['',pack.data]];
  if(!profiles.length||profiles.some(([,data])=>!object(data)||data.presets!=null&&!object(data.presets)))throw Error('Unsupported NSR profile structure');
  return profiles.map(([key,data])=>({key,name:key||pack.name,specs:Object.entries(data.presets||{}).filter(([spec])=>integer(spec)).map(([spec,presets])=>({id:Number(spec),name:SPEC_NAMES[spec]||'Imported specialization',presets:Object.entries(presets).map(([id,p])=>({id,name:p.name||id,list:spellList(p.list),spells:spellList(p.list).map(spellId=>({spellId,name:SPELL_NAMES[spellId]||null}))}))})),legacyBindings:data.bindingsBySpec===false&&Object.keys(data.abilityBindings||{}).length>0}));
}
export class DefensivePlanner{
  constructor(dir,codec){this.dir=path.join(dir,'defensive-planner');this.codec=codec;}
  async file(kind,id){if(!/^[a-f\d-]{16,36}$/.test(id||''))throw Error('Invalid planner item ID');return path.join(this.dir,kind,id+'.json');}
  async read(kind,id){return JSON.parse(await fs.readFile(await this.file(kind,id),'utf8'));}
  async list(kind){const dir=path.join(this.dir,kind);await fs.mkdir(dir,{recursive:true});const items=[];for(const name of await fs.readdir(dir))if(name.endsWith('.json'))items.push(JSON.parse(await fs.readFile(path.join(dir,name),'utf8')));return items;}
  async importProfile(text){const {pack,numericKeys}=this.codec.decode(text,{withKeys:true});profileDescription(pack);const item={id:uid(),hash:sha(text),name:pack.name||'Imported NSR profile',createdAt:new Date().toISOString(),pack,numericKeys};await writeAtomic(await this.file('profiles',item.id),JSON.stringify(item));await writeAtomic(path.join(this.dir,'originals',item.id+'.txt'),text);return {id:item.id,name:item.name,derivedFrom:pack.derivedFrom||null,profiles:profileDescription(pack)};}
  async state(){return {profiles:(await this.list('profiles')).sort((a,b)=>b.createdAt.localeCompare(a.createdAt)).map(p=>({id:p.id,name:p.name,derivedFrom:p.pack.derivedFrom||null,profiles:profileDescription(p.pack)})),tables:(await this.list('tables')).map(t=>({id:t.id,filename:t.filename,kind:t.kind,mechanics:t.mechanics,observations:0,warning:t.warning})),active:await fs.readFile(path.join(this.dir,'active.json'),'utf8').then(JSON.parse).catch(e=>{if(e.code==='ENOENT')return null;throw e;})};}
  async importTable(args){const table=parseDefenseTable(args.text,args.filename,args.options);await writeAtomic(await this.file('tables',table.id),JSON.stringify(table));return table;}
}
