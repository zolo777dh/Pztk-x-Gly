import fs from 'node:fs/promises';
import path from 'node:path';
import {zipSync,unzipSync} from 'fflate';
import {createTwoFilesPatch} from 'diff';
import {inside,readSource,sha,uid,writeAtomic,writeMany,walk} from './files.mjs';
import {parseLua} from './analyzer.mjs';
export class Patches {
  constructor(dataDir){this.dir=path.join(dataDir,'backups');this.plans=new Map();this.busy=false;}
  async locked(fn){if(this.busy)throw Error('Another file operation is in progress');this.busy=true;try{return await fn();}finally{this.busy=false;}}
  async preview(project,relative,replacement,expectedHash){
    if(typeof replacement!=='string'||Buffer.byteLength(replacement)>8e6)throw Error('Patch is too large');
    const before=await readSource(project.root,relative);
    if(expectedHash!==before.hash)throw Error('Source changed since it was opened. Reload before editing.');
    if(!/\.(lua|toc|xml)$/i.test(relative))throw Error('Only Lua, TOC and XML source files can be patched');
    const bom=before.text.startsWith('\uFEFF')?'\uFEFF':''; const body=replacement.replace(/^\uFEFF/,'');
    const eol=before.text.includes('\r\n')?'\r\n':'\n';
    const after=bom+body.replace(/\r\n|\r|\n/g,eol);
    if(relative.endsWith('.lua'))try{parseLua(after);}catch(error){throw Error('Lua validation failed: '+error.message);}
    if(after===before.text)throw Error('The patch contains no changes');
    const id=uid();this.plans.set(id,{type:'patch',projectId:project.id,path:relative,hash:before.hash,after,created:Date.now()});
    return {id,path:relative,before:before.text,after,hash:before.hash,diff:createTwoFilesPatch(relative,relative,before.text,after),validation:relative.endsWith('.lua')?'Lua 5.1 syntax passed. In-game validation required.':'Text change validated. In-game loading must be checked.'};
  }
  async backup(project,entries,kind='patch'){
    const id=uid();const manifest={format:1,id,projectId:project.id,projectName:project.name,createdAt:new Date().toISOString(),kind,files:[]};const contents={};
    let size=0;
    for(const entry of entries){const bytes=await fs.readFile(await inside(project.root,entry.path));size+=bytes.length;if(size>100e6)throw Error('Source backup exceeds 100 MB');if(entry.expectedHash&&sha(bytes)!==entry.expectedHash)throw Error('Source changed before backup: '+entry.path);contents['files/'+entry.path]=bytes;manifest.files.push({path:entry.path,beforeHash:sha(bytes),afterHash:entry.afterHash||null});}
    contents['manifest.json']=Buffer.from(JSON.stringify(manifest,null,2));const zip=zipSync(contents,{level:6});const extracted=unzipSync(zip);
    for(const f of manifest.files)if(sha(extracted['files/'+f.path])!==f.beforeHash)throw Error('Backup verification failed');
    const filename=path.join(this.dir,id+'.zip');await writeAtomic(filename,zip);
    // Verify the durable archive before any source writes.
    if(sha(await fs.readFile(filename))!==sha(zip))throw Error('Backup read-back failed');
    return {...manifest,filename};
  }
  async apply(project,id){return this.locked(async()=>{
    const p=this.plans.get(id);if(!p||p.type!=='patch'||p.projectId!==project.id||Date.now()-p.created>3600000)throw Error('Patch preview expired. Validate it again.');
    const entry={path:p.path,expectedHash:p.hash,afterHash:sha(Buffer.from(p.after))};
    const backup=await this.backup(project,[entry]);
    await writeMany(project.root,[{...entry,bytes:Buffer.from(p.after)}]);this.plans.delete(id);
    return {backup,applied:true};
  });}
  async snapshot(project){return this.locked(async()=>this.backup(project,(await walk(project.root)).map(p=>({path:p})),'source-snapshot'));}
  async list(){await fs.mkdir(this.dir,{recursive:true});const list=[];for(const name of await fs.readdir(this.dir)){if(!name.endsWith('.zip'))continue;try{const data=unzipSync(await fs.readFile(path.join(this.dir,name)));list.push(JSON.parse(Buffer.from(data['manifest.json']).toString()));}catch{}}return list.sort((a,b)=>b.createdAt.localeCompare(a.createdAt));}
  async restorePreview(project,id){
    if(!/^[a-f\d-]{36}$/.test(id))throw Error('Invalid backup id');
    const packed=unzipSync(await fs.readFile(path.join(this.dir,id+'.zip')));const manifest=JSON.parse(Buffer.from(packed['manifest.json']).toString());
    if(manifest.projectId!==project.id)throw Error('Backup belongs to another project');
    const entries=[];
    for(const f of manifest.files){const bytes=packed['files/'+f.path];if(!bytes||sha(bytes)!==f.beforeHash)throw Error('Backup integrity check failed');const current=await fs.readFile(await inside(project.root,f.path));const currentHash=sha(current);if(currentHash===f.beforeHash)continue;if(manifest.kind==='patch'&&currentHash!==f.afterHash)throw Error('Refusing rollback: file changed after the patch: '+f.path);entries.push({path:f.path,expectedHash:currentHash,bytes});}
    if(!entries.length)throw Error('These files already match the backup');
    const planId=uid();this.plans.set(planId,{type:'restore',projectId:project.id,entries,created:Date.now()});return {id:planId,files:entries.map(e=>e.path),backup:manifest};
  }
  async restore(project,id){return this.locked(async()=>{const p=this.plans.get(id);if(!p||p.type!=='restore'||p.projectId!==project.id||Date.now()-p.created>3600000)throw Error('Restore preview expired');await this.backup(project,p.entries.map(e=>({...e,afterHash:sha(e.bytes)})),'restore');await writeMany(project.root,p.entries);this.plans.delete(id);return {restored:p.entries.length};});}
}
