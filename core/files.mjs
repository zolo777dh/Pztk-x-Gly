import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
export const sha = value => crypto.createHash('sha256').update(value).digest('hex');
export const uid = () => crypto.randomUUID();
export async function inside(root, relative) {
  if(typeof relative!=='string'||!relative||relative.includes('\\')||path.isAbsolute(relative)||relative.split('/').some(p=>p==='..'||p==='.'||!p)) throw Error('Invalid relative file path');
  const base=await fs.realpath(root); const target=path.resolve(base,relative);
  if(!target.startsWith(base+path.sep)) throw Error('Path is outside the selected addon');
  let current=base;
  for(const part of relative.split('/')) {current=path.join(current,part); const st=await fs.lstat(current); if(st.isSymbolicLink()) throw Error('Symbolic links are not supported for editable files');}
  return target;
}
export async function walk(root, {all=false}={}) {
  const result=[];
  async function visit(dir, prefix='') {
    const list=await fs.readdir(dir,{withFileTypes:true});
    for(const item of list) {
      const relative=prefix+item.name;
      if(item.isSymbolicLink()) continue;
      if(item.isDirectory()) {if(['.git','node_modules','.release','.claude','Tools'].includes(item.name))continue; if(!all&&['Media','media','Libs'].includes(item.name))continue; await visit(path.join(dir,item.name),relative+'/');}
      else if(item.isFile() && (all||/\.(lua|toc|xml)$/i.test(item.name))) result.push(relative);
      if(result.length>20000)throw Error('Too many files in the selected folder. Select an addon folder.');
    }
  }
  await visit(root); return result.sort();
}
export async function readSource(root,relative) {
  const file=await inside(root,relative); const stat=await fs.stat(file);
  if(stat.size>8*1024*1024) throw Error('Source file exceeds the 8 MB limit');
  const bytes=await fs.readFile(file);
  if(bytes.includes(0))throw Error('This is not a supported UTF-8 source file');
  const text=new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(bytes);
  return {text,hash:sha(bytes),size:bytes.length};
}
export async function writeAtomic(file,data) {
  await fs.mkdir(path.dirname(file),{recursive:true});
  const temp=file+'.doctor-'+uid()+'.tmp';
  try {const h=await fs.open(temp,'wx'); try{await h.writeFile(data);await h.sync();}finally{await h.close();} await fs.rename(temp,file);}finally{await fs.rm(temp,{force:true}).catch(()=>{});}
}
export async function writeMany(root,entries) {
  const originals=[];
  for(const entry of entries){const file=await inside(root,entry.path); const data=await fs.readFile(file); if(sha(data)!==entry.expectedHash)throw Error('File changed since preview: '+entry.path); originals.push({file,data});}
  try {for(let i=0;i<entries.length;i++)await writeAtomic(originals[i].file,entries[i].bytes);}catch(error){for(const old of originals)await writeAtomic(old.file,old.data);throw error;}
}
// fs.cp uses opendir, which Electron does not support inside app.asar.
export async function copyResources(source,destination){
  await fs.mkdir(destination,{recursive:true});
  for(const entry of await fs.readdir(source,{withFileTypes:true})){
    const from=path.join(source,entry.name),to=path.join(destination,entry.name);
    if(entry.isDirectory())await copyResources(from,to);
    else if(entry.isFile())await fs.writeFile(to,await fs.readFile(from));
  }
}
