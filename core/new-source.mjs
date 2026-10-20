import fs from 'node:fs/promises';
import path from 'node:path';
export async function newSourcePath(root,relative){
 if(typeof relative!=='string'||!relative||relative.includes('\\')||path.isAbsolute(relative)||relative.split('/').some(p=>!p||p==='..'||p==='.'))throw Error('Invalid relative file path');
 const base=await fs.realpath(root),parts=relative.split('/');let parent=base;
 for(const part of parts.slice(0,-1)){parent=path.join(parent,part);const st=await fs.lstat(parent);if(st.isSymbolicLink()||!st.isDirectory())throw Error('New files require an existing non-symbolic directory');}
 const target=path.join(parent,parts.at(-1));try{await fs.lstat(target);throw Error('New source file already exists: '+relative);}catch(e){if(e.code!=='ENOENT')throw e;}return target;
}
export async function writeNewAtomic(file,bytes){
 const temporary=file+'.pztk-'+Date.now()+'-'+Math.random().toString(16).slice(2)+'.tmp';
 try{const handle=await fs.open(temporary,'wx');try{await handle.writeFile(bytes);await handle.sync();}finally{await handle.close();}await fs.link(temporary,file);}finally{await fs.rm(temporary,{force:true}).catch(()=>{});}
}
