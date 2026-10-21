import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {zipCompatible} from '../core/archives.mjs';
export async function packageAddon(root,destination){
 const files={},source=path.join(root,'addon','PztkReminders');
 async function collect(dir,prefix=''){for(const item of await fs.readdir(dir,{withFileTypes:true})){const full=path.join(dir,item.name),relative=prefix+item.name;if(item.isDirectory())await collect(full,relative+'/');else if(item.isFile())files['PztkReminders/'+relative]=await fs.readFile(full);else throw Error('Unexpected addon package entry');}}
 await collect(source);
 const pending=['PztkReminders/PztkReminders.toc'],seen=new Set();while(pending.length){const name=pending.pop();if(seen.has(name))continue;seen.add(name);const text=files[name].toString('utf8').replace(/<!--[\s\S]*?-->/g,'');const refs=name.endsWith('.toc')?text.split(/\r?\n/).map(s=>s.trim().split(' [')[0]).filter(s=>s&&!s.startsWith('#')):[...text.matchAll(/<(?:Script|Include)\s+file\s*=\s*["']([^"']+)/g)].map(m=>m[1]);for(let ref of refs){ref=ref.replaceAll('\\','/');const target=[path.posix.normalize(path.posix.join(path.posix.dirname(name),ref)),'PztkReminders/'+ref].find(p=>files[p]);if(!target)throw Error('Missing addon loader reference: '+name+' → '+ref);if(target.endsWith('.xml'))pending.push(target);}}
 files['PztkReminders/BUILD-SOURCES.json']=Buffer.from(JSON.stringify({addon:'PztkReminders',version:'0.1.0',files:Object.fromEntries(Object.entries(files).map(([k,v])=>[k,createHash('sha256').update(v).digest('hex')]))},null,2));await fs.mkdir(destination,{recursive:true});const file=path.join(destination,'PztkReminders-0.1.0.zip');await fs.writeFile(file,zipCompatible(files));return file;
}
