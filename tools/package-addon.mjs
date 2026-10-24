import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {zipCompatible} from '../core/archives.mjs';
export async function packageAddon(root,destination){
 const files={},source=path.join(root,'addon','PuzatikDefensivePlanner');
 // A user's own licensed Media/Fonts/Naowh.ttf is never redistributed.
 async function collect(dir,prefix=''){for(const item of await fs.readdir(dir,{withFileTypes:true})){const full=path.join(dir,item.name),relative=prefix+item.name;if(item.isDirectory())await collect(full,relative+'/');else if(item.isFile()&&!(prefix==='Media/Fonts/'&&/^naowh\.ttf$/i.test(item.name)))files['PuzatikDefensivePlanner/'+relative]=await fs.readFile(full);else throw Error('Unexpected addon package entry');}}
 await collect(source);
 const version=files['PuzatikDefensivePlanner/PuzatikDefensivePlanner.toc'].toString('utf8').match(/^## Version:\s*(\d+\.\d+\.\d+)\s*$/m)?.[1];if(!version)throw Error('Missing addon version');
 // Follow the actual TOC/XML load graph, including Lua files. A repeated load
 // resets module state in game even though every referenced file exists.
 const pending=[{name:'PuzatikDefensivePlanner/PuzatikDefensivePlanner.toc',from:'root'}],seen=new Map();
 while(pending.length){
  const {name,from}=pending.pop(),key=name.toLowerCase();
  if(seen.has(key))throw Error('Duplicate addon file load: '+name+' (from '+seen.get(key)+' and '+from+')');
  seen.set(key,from);
  if(!/\.(toc|xml)$/i.test(name))continue;
  const text=files[name].toString('utf8').replace(/<!--[\s\S]*?-->/g,'');
  const refs=name.endsWith('.toc')?text.split(/\r?\n/).map(s=>s.trim().split(' [')[0]).filter(s=>s&&!s.startsWith('#')):[...text.matchAll(/<(?:Script|Include)\s+file\s*=\s*["']([^"']+)/g)].map(m=>m[1]);
  for(let ref of refs){
   ref=ref.replaceAll('\\','/');
   const target=[path.posix.normalize(path.posix.join(path.posix.dirname(name),ref)),path.posix.normalize('PuzatikDefensivePlanner/'+ref)].find(p=>files[p]);
   if(!target)throw Error('Missing addon loader reference: '+name+' → '+ref);
   pending.push({name:target,from:name});
  }
 }
 files['PuzatikDefensivePlanner/BUILD-SOURCES.json']=Buffer.from(JSON.stringify({addon:'PuzatikDefensivePlanner',version,files:Object.fromEntries(Object.entries(files).map(([k,v])=>[k,createHash('sha256').update(v).digest('hex')]))},null,2));await fs.mkdir(destination,{recursive:true});const file=path.join(destination,`PuzatikDefensivePlanner-${version}.zip`);await fs.writeFile(file,zipCompatible(files));return file;
}
