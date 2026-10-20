import fs from 'node:fs/promises';
import path from 'node:path';
import {unzipSync} from 'fflate';
import {createTwoFilesPatch} from 'diff';
import {zipCompatible} from './archives.mjs';
import {inside,readSource,writeAtomic,writeMany,sha,uid} from './files.mjs';
import {newSourcePath,writeNewAtomic} from './new-source.mjs';
import {parseLua} from './analyzer.mjs';

export class TaskPatches{
 constructor(dir,patches){this.dir=path.join(dir,'tasks');this.patches=patches;this.plans=new Map();}
 async preview(projects,changes,guards=[]){
  if(!Array.isArray(changes)||!changes.length||changes.length>30)throw Error('Supply 1–30 source changes.');const seen=new Set(),entries=[];
  for(const change of changes){const p=projects.find(p=>p.id===change.projectId);if(!p)throw Error('The patch refers to a project outside this task.');const key=path.resolve(p.root,change.file).toLowerCase();if(seen.has(key))throw Error('A source file may appear only once per task.');seen.add(key);
   if(!/\.(lua|toc|xml)$/i.test(change.file)||typeof change.replacement!=='string'||Buffer.byteLength(change.replacement)>8e6)throw Error('Only bounded Lua, TOC and XML changes are supported.');
   const before=change.create?(await newSourcePath(p.root,change.file),{text:'',hash:null}):await readSource(p.root,change.file);if(before.hash!==change.hash)throw Error('Source changed since context was prepared: '+change.file);
   const eol=before.text.includes('\r\n')?'\r\n':'\n',after=(before.text.startsWith('\uFEFF')?'\uFEFF':'')+change.replacement.replace(/^\uFEFF/,'').replace(/\r\n|\r|\n/g,eol);
   if(change.file.endsWith('.lua'))try{parseLua(after);}catch(e){throw Error('Lua validation failed in '+change.file+': '+e.message);}
   if(after===before.text)throw Error('No changes in '+change.file);
   entries.push({create:!!change.create,projectId:p.id,projectName:p.name,root:p.root,file:change.file,beforeHash:before.hash,afterHash:sha(Buffer.from(after)),after,diff:createTwoFilesPatch(p.name+'/'+change.file,p.name+'/'+change.file,before.text,after)});
  }
  const plan={id:uid(),created:Date.now(),entries,guards};this.plans.set(plan.id,plan);await writeAtomic(path.join(this.dir,'previews',plan.id+'.json'),JSON.stringify(plan));if(this.plans.size>30)this.plans.delete(this.plans.keys().next().value);return {id:plan.id,files:entries.map(({root,after,...e})=>e),validation:'Lua 5.1 syntax checked; source hashes must still match at apply. In-game behavior needs testing.'};
 }
 async plan(id){if(!/^[a-f\d-]{36}$/.test(id||''))throw Error('Invalid task preview ID');const plan=this.plans.get(id)||await fs.readFile(path.join(this.dir,'previews',id+'.json'),'utf8').then(JSON.parse).catch(()=>null);if(!plan||Date.now()-plan.created>3600000)throw Error('Task preview expired. Prepare it again.');return plan;}
 async apply(projects,id,selected){return this.patches.locked(async()=>{
  const plan=await this.plan(id);if(!Array.isArray(selected)||!selected.length)throw Error('Select at least one file to apply.');const entries=plan.entries.filter(e=>selected.includes(e.projectId+'/'+e.file));if(entries.length!==new Set(selected).size)throw Error('Selected files no longer match this preview.');
  // Recheck the entire dependency context, even when accepting only part of a proposal.
  for(const g of plan.guards||[]){const p=projects.find(p=>p.id===g.projectId);if(!p||(await readSource(p.root,g.file)).hash!==g.hash)throw Error('Task context changed since preview: '+g.file);}
  for(const e of plan.entries){const p=projects.find(p=>p.id===e.projectId&&p.root===e.root);if(!p)throw Error('Reconnect the original task projects first.');if(e.create)await newSourcePath(p.root,e.file);else if((await readSource(p.root,e.file)).hash!==e.beforeHash)throw Error('Source changed after preview: '+e.file);}
  const backupId=uid(),manifest={format:1,id:backupId,kind:'task',createdAt:new Date().toISOString(),files:[]},contents={};let total=0;
  for(const [i,e]of entries.entries()){const bytes=e.create?Buffer.alloc(0):await fs.readFile(await inside(e.root,e.file));total+=bytes.length;if(total>100e6)throw Error('Task backup exceeds 100 MB');if(!e.create&&sha(bytes)!==e.beforeHash)throw Error('Source changed before backup: '+e.file);const archive='files/'+i;contents[archive]=bytes;manifest.files.push({...e,after:undefined,diff:undefined,archive});}
  contents['manifest.json']=Buffer.from(JSON.stringify(manifest));const zip=zipCompatible(contents),filename=path.join(this.dir,backupId+'.zip');await writeAtomic(filename,zip);const durable=await fs.readFile(filename);if(sha(durable)!==sha(zip))throw Error('Task backup read-back failed');const extracted=unzipSync(durable);for(const e of manifest.files)if(!e.create&&sha(extracted[e.archive])!==e.beforeHash)throw Error('Task backup verification failed');
  const written=[];try{for(const e of entries){if(e.create)await writeNewAtomic(await newSourcePath(e.root,e.file),Buffer.from(e.after));else await writeMany(e.root,[{path:e.file,expectedHash:e.beforeHash,bytes:Buffer.from(e.after)}]);written.push(e);}}
  catch(error){for(const e of written.reverse()){const old=manifest.files.find(f=>f.projectId===e.projectId&&f.file===e.file);if(e.create){if((await readSource(e.root,e.file)).hash!==e.afterHash)throw Error('Rollback blocked by external edit; task backup '+backupId);await fs.rm(await inside(e.root,e.file));}else await writeMany(e.root,[{path:e.file,expectedHash:e.afterHash,bytes:extracted[old.archive]}]);}throw error;}
  this.plans.delete(id);await fs.rm(path.join(this.dir,'previews',id+'.json'),{force:true});return {backupId,files:entries.map(e=>({projectId:e.projectId,file:e.file})),applied:true};
 });}
 async list(){await fs.mkdir(this.dir,{recursive:true});const results=[];for(const file of await fs.readdir(this.dir))if(file.endsWith('.zip')){const data=unzipSync(await fs.readFile(path.join(this.dir,file)));results.push(JSON.parse(Buffer.from(data['manifest.json']).toString()));}return results.sort((a,b)=>b.createdAt.localeCompare(a.createdAt));}
 async restore(projects,id){return this.patches.locked(async()=>{
  if(!/^[a-f\d-]{36}$/.test(id))throw Error('Invalid task backup ID');const zip=unzipSync(await fs.readFile(path.join(this.dir,id+'.zip'))),manifest=JSON.parse(Buffer.from(zip['manifest.json']).toString()),entries=[];
  for(const e of manifest.files){const p=projects.find(p=>p.id===e.projectId&&p.root===e.root);if(!p)throw Error('Reconnect the original task projects first.');let current;try{current=await readSource(e.root,e.file);}catch(error){if(e.create&&error.code==='ENOENT')continue;throw error;}if(current.hash===e.beforeHash)continue;if(current.hash!==e.afterHash)throw Error('Refusing rollback: source changed after task: '+e.file);const bytes=zip[e.archive];if(!bytes||!e.create&&sha(bytes)!==e.beforeHash)throw Error('Task backup integrity failed');entries.push({e,bytes,current});}
  let checkpointId=null;if(entries.length){
   checkpointId=uid();const recovery={format:1,id:checkpointId,kind:'before-task-restore',createdAt:new Date().toISOString(),originalBackup:id,files:[]},contents={};
   for(const [i,entry]of entries.entries()){const archive='files/'+i;contents[archive]=Buffer.from(entry.current.text);recovery.files.push({projectId:entry.e.projectId,root:entry.e.root,file:entry.e.file,archive,hash:sha(contents[archive])});}
   contents['manifest.json']=Buffer.from(JSON.stringify(recovery));const packed=zipCompatible(contents),file=path.join(this.dir,'restore-checkpoints',checkpointId+'.zip');await writeAtomic(file,packed);const verified=unzipSync(await fs.readFile(file));for(const entry of recovery.files)if(sha(verified[entry.archive])!==entry.hash)throw Error('Restore checkpoint verification failed');
  }
  const restored=[];try{for(const entry of entries){if(entry.e.create)await fs.rm(await inside(entry.e.root,entry.e.file));else await writeMany(entry.e.root,[{path:entry.e.file,expectedHash:entry.e.afterHash,bytes:entry.bytes}]);restored.push(entry);}}
  catch(error){for(const entry of restored.reverse()){if(entry.e.create)await writeNewAtomic(await newSourcePath(entry.e.root,entry.e.file),Buffer.from(entry.current.text));else await writeMany(entry.e.root,[{path:entry.e.file,expectedHash:entry.e.beforeHash,bytes:Buffer.from(entry.current.text)}]);}throw error;}
  return {restored:restored.length,checkpointId};
 });}
}
