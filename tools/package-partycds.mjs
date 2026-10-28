import fs from 'node:fs/promises';
import path from 'node:path';
import {zipCompatible} from '../core/archives.mjs';
// Puzatik Party Defensives: the party cooldowns of Naowh Defensive Planner as their own addon. Its
// folder holds only the glue; the tracking code, the widgets and the window media are taken from
// Naowh Defensive Planner here, so both addons always ship the same code and version.
export const SHARED=['Comms.lua','Widgets.lua','PartyCooldowns.lua','Media/UI/Disc.tga','Media/UI/IconMask.tga','Media/UI/Icons.tga',
 'Media/Fonts/URWGothic-Book.ttf','Media/Fonts/URWGothic-Demi.ttf','Media/Fonts/URWGothic-LICENSE.txt'];
export async function partyCooldownFiles(root){
 const own=path.join(root,'addon','PuzatikPartyDefensives'),full=path.join(root,'addon','NaowhDefensivePlanner'),files={};
 for(const entry of await fs.readdir(own,{recursive:true,withFileTypes:true}))if(entry.isFile()){
  const file=path.join(entry.parentPath??entry.path,entry.name);files['PuzatikPartyDefensives/'+path.relative(own,file).split(path.sep).join('/')]=await fs.readFile(file);
 }
 for(const name of SHARED)files['PuzatikPartyDefensives/'+name]=await fs.readFile(path.join(full,name));
 // The widgets find their textures and fonts in this addon's folder.
 files['PuzatikPartyDefensives/Widgets.lua']=Buffer.from(files['PuzatikPartyDefensives/Widgets.lua'].toString('utf8').replace('Interface\\\\AddOns\\\\NaowhDefensivePlanner\\\\Media','Interface\\\\AddOns\\\\PuzatikPartyDefensives\\\\Media'));
 if(!files['PuzatikPartyDefensives/Widgets.lua'].toString('utf8').includes('PuzatikPartyDefensives\\\\Media'))throw Error('Widgets media path not rewritten');
 // The addon names no other addon: the shared files lose their comment lines, the font slot for a
 // user's own font is called custom, and the group messages use this addon's own prefix.
 const rewrite=(name,fn)=>{const key='PuzatikPartyDefensives/'+name;files[key]=Buffer.from(fn(files[key].toString('utf8')))};
 for(const name of SHARED.filter(n=>n.endsWith('.lua')))rewrite(name,t=>t.split('\n').filter(l=>!/^\s*--/.test(l)).join('\n'));
 rewrite('Widgets.lua',t=>t.replace(/Naowh/g,'Custom').replace(/naowh/g,'custom'));
 rewrite('Comms.lua',t=>t.replace('local PREFIX="NDP"','local PREFIX="PuzatikPD"'));
 for(const [key,data] of Object.entries(files))if(/\.(lua|toc|txt)$/.test(key)&&!key.endsWith('LICENSE.txt')){
  const hit=data.toString('utf8').match(/naowh|\bndp\b|nsrt|\bnsr\b|kira|smart reminders|timeline reminders/i);
  if(hit)throw Error(`${key} still names another addon: ${hit[0]}`);
 }
 const version=(await fs.readFile(path.join(full,'NaowhDefensivePlanner.toc'),'utf8')).match(/^## Version:\s*(\d+\.\d+\.\d+)\s*$/m)?.[1];if(!version)throw Error('Missing addon version');
 const toc='PuzatikPartyDefensives/PuzatikPartyDefensives.toc';
 files[toc]=Buffer.from(files[toc].toString('utf8').replace(/^## Version:.*$/m,'## Version: '+version));
 for(const line of files[toc].toString('utf8').split(/\r?\n/).map(s=>s.trim()).filter(s=>s&&!s.startsWith('#')))if(!files['PuzatikPartyDefensives/'+line])throw Error('Missing addon loader reference: '+line);
 return {files,version};
}
export async function packagePartyCooldowns(root,destination){
 const {files,version}=await partyCooldownFiles(root);
 await fs.mkdir(destination,{recursive:true});const file=path.join(destination,`PuzatikPartyDefensives-${version}.zip`);await fs.writeFile(file,zipCompatible(files));return file;
}
