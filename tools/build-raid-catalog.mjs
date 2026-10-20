import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import luaparse from 'luaparse';
import {literalTables} from './exboss-data.mjs';

// Read literal facts only; no uploaded Lua is evaluated or bundled.
export function namedFacts(source){
 const ast=luaparse.parse(source,{ranges:true}),result={};
 for(const node of ast.body){if(!['AssignmentStatement','LocalStatement'].includes(node.type))continue;
  node.variables.forEach((variable,index)=>{const value=node.init[index];if(value?.type!=='TableConstructorExpression')return;
   const name=variable.type==='Identifier'?variable.name:variable.type==='MemberExpression'?variable.identifier.name:null;
   if(name)result[name]=literalTables('local facts = '+source.slice(...value.range)).facts;
  });
 }
 return result;
}
export async function buildRaidCatalog(root,nsrRoot){
 const metadata=await fs.readFile(path.join(root,'BossData.lua'),'utf8'),facts=namedFacts(metadata),sources={};
 const abilities=await fs.readFile(path.join(nsrRoot,'NaowhUI_SmartReminders_Abilities.lua'),'utf8'),aliases=namedFacts(abilities);
 const canonical={...aliases.DBM_TO_BIGWIGS};for(const [timer,journal]of Object.entries(aliases.BOSSMOD_KEY_TO_JOURNAL||{}))canonical[journal]=Number(timer);
 const seasons=[];
 for(const [folder,ids,title]of [['MidnightS2',facts.currentEncounterIDs,'Midnight · Season 2'],['MidnightS1',facts.oldEncounterIDs,'Midnight · Season 1']]){
  const bosses=[];
  for(const file of (await fs.readdir(path.join(root,'BossTimelines',folder))).filter(f=>f.endsWith('.lua')).sort()){
   const relative='BossTimelines/'+folder+'/'+file,source=await fs.readFile(path.join(root,relative),'utf8'),tables=namedFacts(source);
   const encounterId=Number(source.match(/NSI\.BossTimelines\[(\d+)\]/)?.[1]);if(!encounterId||!facts.BossNames[encounterId])throw Error('Missing encounter metadata: '+file);
   sources[relative]=createHash('sha256').update(source).digest('hex');const bySpell=new Map();
   for(const [difficulty,key]of [['heroic','heroicData'],['mythic','mythicData']]){
    if(!tables[key]?.abilities)throw Error('Missing difficulty in '+file);
    for(const row of Object.values(tables[key].abilities)){
     const id=Number(row.spellID);if(!Number.isInteger(id)||id<=0||!row.name)continue;
     const a=bySpell.get(id)||{id,name:row.name,timerSpellId:Number(canonical[id]||id),timerSource:canonical[id]?'NSR explicit alias':'NSRT spell ID; verify boss-mod broadcast',difficulties:[],categories:[],phases:{},nsrtSchedule:{}};
     if(!a.difficulties.includes(difficulty))a.difficulties.push(difficulty);
     for(const category of String(row.category||'').split(',').map(c=>c.trim()).filter(Boolean))if(!a.categories.includes(category))a.categories.push(category);
     a.phases[difficulty]||=[];if(row.phase!=null&&!a.phases[difficulty].includes(row.phase))a.phases[difficulty].push(row.phase);
     a.nsrtSchedule[difficulty]||={};const phase=String(row.phase||1);a.nsrtSchedule[difficulty][phase]||=[];for(const time of Object.values(row.times||{}))if(Number.isFinite(time)&&time>=0&&!a.nsrtSchedule[difficulty][phase].includes(time))a.nsrtSchedule[difficulty][phase].push(time);a.nsrtSchedule[difficulty][phase].sort((x,y)=>x-y);
     bySpell.set(id,a);
    }
   }
   bosses.push({id:encounterId,name:facts.BossNames[encounterId],source:relative,abilities:[...bySpell.values()]});
  }
  bosses.sort((a,b)=>Object.values(ids).indexOf(a.id)-Object.values(ids).indexOf(b.id));seasons.push({id:folder,name:title,bosses});
 }
 return {format:1,client:'retail',source:{name:'NorthernSkyRaidTools',version:'12.1.31',files:sources,metadataSha256:createHash('sha256').update(metadata).digest('hex'),aliasesSha256:createHash('sha256').update(abilities).digest('hex'),scope:'Factual spell IDs, encounter IDs, names, categories and difficulty membership only. Phase-relative schedule facts for native NSRT alerts; no executable addon code.'},seasons};
}
if(process.argv[1]===new URL(import.meta.url).pathname){const [root,nsrRoot]=process.argv.slice(2);if(!root||!nsrRoot)throw Error('Usage: node tools/build-raid-catalog.mjs NSRT_ROOT NSR_ROOT');await fs.writeFile('resources/raid-catalog.json',JSON.stringify(await buildRaidCatalog(root,nsrRoot),null,2)+'\n');}
