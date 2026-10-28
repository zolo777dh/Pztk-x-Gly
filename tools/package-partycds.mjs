import fs from 'node:fs/promises';
import path from 'node:path';
import {zipCompatible} from '../core/archives.mjs';
// NDP Party Cooldowns: the party cooldowns of Naowh Defensive Planner as their own addon. Its
// folder holds only the glue; Comms.lua and PartyCooldowns.lua are taken from Naowh Defensive
// Planner here, so both addons always ship the same tracking code and version.
export const SHARED=['Comms.lua','PartyCooldowns.lua'];
export async function partyCooldownFiles(root){
 const own=path.join(root,'addon','NDPPartyCooldowns'),full=path.join(root,'addon','NaowhDefensivePlanner'),files={};
 for(const name of await fs.readdir(own))files['NDPPartyCooldowns/'+name]=await fs.readFile(path.join(own,name));
 for(const name of SHARED)files['NDPPartyCooldowns/'+name]=await fs.readFile(path.join(full,name));
 const version=(await fs.readFile(path.join(full,'NaowhDefensivePlanner.toc'),'utf8')).match(/^## Version:\s*(\d+\.\d+\.\d+)\s*$/m)?.[1];if(!version)throw Error('Missing addon version');
 const toc='NDPPartyCooldowns/NDPPartyCooldowns.toc';
 files[toc]=Buffer.from(files[toc].toString('utf8').replace(/^## Version:.*$/m,'## Version: '+version));
 for(const line of files[toc].toString('utf8').split(/\r?\n/).map(s=>s.trim()).filter(s=>s&&!s.startsWith('#')))if(!files['NDPPartyCooldowns/'+line])throw Error('Missing addon loader reference: '+line);
 return {files,version};
}
export async function packagePartyCooldowns(root,destination){
 const {files,version}=await partyCooldownFiles(root);
 await fs.mkdir(destination,{recursive:true});const file=path.join(destination,`NDPPartyCooldowns-${version}.zip`);await fs.writeFile(file,zipCompatible(files));return file;
}
