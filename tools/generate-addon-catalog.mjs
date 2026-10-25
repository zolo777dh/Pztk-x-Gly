import fs from 'node:fs/promises';
import {SPEC_NAMES,SPELL_NAMES} from '../core/wow-names.mjs';
import {npcTimerChoices,mythicAbilities} from '../core/mythic-catalog.mjs';
const npc=JSON.parse(await fs.readFile('resources/npc-catalog.json'));
const catalog={specs:SPEC_NAMES,spellNames:SPELL_NAMES,dungeons:npc.dungeons.map(d=>({id:d.mapId,mapID:d.mapId,name:d.name,npcs:d.npcs.map(n=>({id:n.id,name:n.name,kind:n.kind,encounterId:n.encounterId||undefined,abilities:npcTimerChoices({...n,abilities:mythicAbilities(n.abilities).filter(a=>a.timerEvidence||a.messageEvidence===true)}).map(a=>({id:a.id,name:a.name||undefined}))})).filter(n=>n.abilities.length)}))};
function lua(v){if(v==null)return 'nil';if(typeof v==='string')return '"'+v.replaceAll('\\','\\\\').replaceAll('"','\\"').replaceAll('\n','\\n').replaceAll('\r','\\r')+'"';if(typeof v!=='object')return String(v);return '{'+Object.entries(v).filter(([,x])=>x!==undefined).map(([k,x])=>'['+(Array.isArray(v)?Number(k)+1:/^\d+$/.test(k)?k:lua(k))+']='+lua(x)).join(',')+'}';}
await fs.writeFile('addon/NaowhDefensivePlanner/Catalog.lua','-- Generated factual catalog from resources/npc-catalog.json (Mythic+ dungeons, checked against\n-- LittleWigs). Raid bosses come from the game\'s Encounter Journal (Journal.lua). Retail only.\nlocal _,ns=...\nns.Catalog='+lua(catalog)+'\n');
console.log(catalog.dungeons.length+' dungeons, '+Object.keys(catalog.specs).length+' specializations');
