import fs from 'node:fs/promises';
import path from 'node:path';

export async function discoverProjects(roots){
  if(!Array.isArray(roots)||!roots.length||roots.length>100||roots.some(r=>typeof r!=='string'||!r.trim()))throw Error('Choose 1–100 addon folders or a common directory containing them.');
  const found=new Map();
  async function inspect(folder,discoveryRoot){
    const root=await fs.realpath(folder);const entries=await fs.readdir(root,{withFileTypes:true});const tocs=entries.filter(e=>e.isFile()&&e.name.toLowerCase().endsWith('.toc')).map(e=>e.name).sort();
    if(tocs.length){const base=path.basename(root);const main=tocs.find(t=>t.toLowerCase()===base.toLowerCase()+'.toc')||tocs[0];const key=process.platform==='win32'?root.toLowerCase():root;const existing=found.get(key);found.set(key,{root,name:main.slice(0,-4),discoveryRoots:[...new Set([...(existing?.discoveryRoots||[]),discoveryRoot])]});}
    return entries;
  }
  for(const input of roots){const discoveryRoot=await fs.realpath(input.trim());const entries=await inspect(discoveryRoot,discoveryRoot);for(const child of entries){if(!child.isDirectory()||child.isSymbolicLink()||['.git','node_modules','Libs','Tools','Media'].includes(child.name))continue;await inspect(path.join(discoveryRoot,child.name),discoveryRoot);}}
  if(!found.size)throw Error('No addon .toc files found in the selected folders or their immediate subfolders.');
  if(found.size>200)throw Error('More than 200 addons found. Select fewer folders.');
  return [...found.values()];
}
