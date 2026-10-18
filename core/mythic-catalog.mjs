// The bundled source is the MDT seasonal Mythic+ dataset, not Encounter Journal
// data pooled across difficulties. Keep shared Mythic+ spells, exclude rows
// explicitly restricted to Normal (1) / Heroic (2) / Mythic zero (23).
export function mythicAbilities(abilities=[]){
 const found=new Map();for(const ability of abilities){
  const ids=ability.difficultyIds??(ability.difficultyId==null?null:[ability.difficultyId]);
  if(ids&&!ids.some(id=>Number(id)===8))continue;
  if(ability.difficulty&&!['mythic-plus','mythic+','challenge'].includes(String(ability.difficulty).toLowerCase()))continue;
  if(!Number.isInteger(Number(ability.id))||Number(ability.id)<=0)continue;
  const id=Number(ability.id),previous=found.get(id);
  found.set(id,previous?{...ability,...previous,name:previous.name||ability.name}: {...ability,id});
 }return [...found.values()];
}
export function mythicCatalog(catalog){return {...catalog,difficulty:'mythic-plus',difficultyId:8,dungeons:catalog.dungeons.map(d=>({...d,npcs:d.npcs.map(n=>({...n,abilities:mythicAbilities(n.abilities)})).filter(n=>n.abilities.length)}))};}
