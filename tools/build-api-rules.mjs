// Builds core/api-rules.json from Blizzard's shipped UI source (a wow-ui-source checkout).
// Usage: node tools/build-api-rules.mjs --live <Interface dir> --history <tag>=<dir> ... [--manual tools/api-rules-manual.json] [--out core/api-rules.json]
// Each history dir only needs its Deprecated addons and Blizzard_APIDocumentationGenerated. Never evaluates Lua.
import fs from 'node:fs/promises';
import path from 'node:path';

const args=process.argv.slice(2),opt=(k,d)=>{const i=args.indexOf(k);return i<0?d:args[i+1];};
const live=opt('--live'),out=opt('--out','core/api-rules.json'),manualFile=opt('--manual','tools/api-rules-manual.json');
const history=args.flatMap((a,i)=>a==='--history'?[args[i+1]]:[]).map(s=>{const [tag,dir]=s.split('=');return {tag,dir};}).sort((a,b)=>cmpTag(a.tag,b.tag));
if(!live)throw Error('--live <Interface dir> is required');
function cmpTag(a,b){const x=a.split('.').map(Number),y=b.split('.').map(Number);for(let i=0;i<3;i++)if(x[i]!==y[i])return x[i]-y[i];return 0;}

async function files(dir,test){const result=[];async function visit(d){let list;try{list=await fs.readdir(d,{withFileTypes:true});}catch{return;}for(const e of list){const p=path.join(d,e.name);if(e.isDirectory())await visit(p);else if(e.isFile()&&test(p))result.push(p);}}await visit(dir);return result.sort();}
const isClassic=p=>/[\\/]Classic[\\/]|Classic|_(Vanilla|TBC|Wrath|Cata|Mists)\.lua$/i.test(p);
const isDeprecated=p=>/Deprecat/i.test(p)&&p.endsWith('.lua')&&!isClassic(p);
const isDoc=p=>/Blizzard_APIDocumentationGenerated[\\/][^\\/]+\.lua$/.test(p);

// Generated API documentation: functions (with restriction flags), events and widget methods.
async function readDocs(dir){
  const fns=new Map(),events=new Set(),methods=new Map();
  for(const file of await files(dir,isDoc)){
    const text=await fs.readFile(file,'utf8');const ns=text.match(/^\s*Namespace\s*=\s*"([^"]+)"/m)?.[1];const type=text.match(/^\t\tType\s*=\s*"([^"]+)"/m)?.[1];const sys=text.match(/^\t\tName\s*=\s*"([^"]+)"/m)?.[1];
    const section=text.match(/\n\tFunctions\s*=\s*\n\t\{([\s\S]*?)\n\t\},/)?.[1]||'';
    for(const m of section.matchAll(/\n\t\t\{\n\t\t\tName = "([^"]+)",\n\t\t\tType = "Function",([\s\S]*?)\n\t\t\},/g)){
      const flags=[...new Set([...m[2].matchAll(/\n\t\t\t(\w+) = (?:true|"[^"]*")/g)].map(f=>f[1]))].sort();
      if(type==='ScriptObject')methods.set(m[1],sys);else fns.set(ns?ns+'.'+m[1]:m[1],flags);
    }
    for(const m of text.matchAll(/LiteralName = "([^"]+)"/g))events.add(m[1]);
  }
  return {fns,events,methods};
}

// Top-level definitions. In a Deprecated file these are compatibility shims; elsewhere they are live UI globals.
const API=/^(?:C_\w+\.\w+|[A-Z]\w*(?:\.[A-Za-z]\w*)?|getglobal|setglobal)$/,BUILTIN=new Set(['GetCVarBool','ipairs','pairs','unpack','select','type','error','assert','tostring','tonumber','pcall','securecallfunction','forceinsecure','GetAppropriateTooltip']);
function definitions(text){
  const lines=text.split(/\r?\n/),defs=[];
  for(let i=0;i<lines.length;i++){
    const m=lines[i].match(/^(\s*)(?:function\s+([A-Za-z_][\w.]*)\s*\(.*|([A-Za-z_][\w.]*)\s*=\s*(.*))$/);if(!m)continue;
    const indent=m[1],name=m[2]||m[3];let value=(m[4]||'').replace(/;?\s*(--.*)?$/,'').trim();
    if(!API.test(name)||/^[A-Z0-9_]+$/.test(name)||/^(Enum|Constants)\./.test(name)||/Mixin$/.test(name))continue;
    if(m[3]&&!/^function\b/.test(value)&&!API.test(value))continue; // constants, tables, literals
    let target=m[3]&&API.test(value)?value:'';
    if(!target){const body=[];for(let j=i+1;j<lines.length&&!new RegExp('^'+indent+'end\\b').test(lines[j]);j++)body.push(lines[j]);
      for(const c of body.join('\n').matchAll(/\b((?:C_\w+\.)?[A-Z]\w*(?:[.:][A-Za-z]\w*)?)\s*\(/g))if(c[1]!==name&&!BUILTIN.has(c[1])&&!c[1].startsWith('original')){target=c[1];break;}}
    defs.push({name,target});
  }
  return defs;
}
async function readShims(dir){const map=new Map();for(const file of await files(dir,isDeprecated)){for(const d of definitions(await fs.readFile(file,'utf8')))if(!map.has(d.name))map.set(d.name,{...d,file:path.relative(dir,file).replaceAll('\\','/')});}return map;}
async function readLiveGlobals(dir){const set=new Set();for(const file of await files(dir,p=>p.endsWith('.lua')&&!/Deprecat/i.test(p)&&!isClassic(p)&&!isDoc(p))){const text=await fs.readFile(file,'utf8');for(const m of text.matchAll(/^\s*(?:function\s+([A-Za-z_][\w.:]*)\s*\(|([A-Za-z_][\w.]*)\s*=)/gm)){const n=m[1]||m[2];if(!/^local\b/.test(m[0].trim()))set.add(n.replace(':','.'));}}return set;}

// Blizzard's 11.0.0 spell transition guide: "Old(args) = New(args)" lines; the spellID/name form wins.
async function readGuide(dir){const map=new Map();const [file]=await files(dir,p=>p.endsWith('SpellBookAPITransitionGuide.lua'));if(!file)return map;
  for(const line of (await fs.readFile(file,'utf8')).split(/\r?\n/)){const m=line.match(/^([A-Za-z/]+)\(([^)]*)\)\s*=?\s*([\w.]+)\(/);if(!m)continue;for(const old of m[1].split('/'))if(!map.has(old)||/spellID|name/.test(m[2]))map.set(old,m[3]);}
  return map;}

const now=await readDocs(live),liveGlobals=await readLiveGlobals(live),liveShims=await readShims(live),guide=await readGuide(live);
const exists=n=>now.fns.has(n)||liveGlobals.has(n.replace(':','.'));
const seen=new Map(),seenEvents=new Map();
for(const {tag,dir} of history){
  for(const [name,d] of await readShims(dir)){const prev=seen.get(name);seen.set(name,{...d,first:prev?.first||tag,last:tag,target:d.target||prev?.target||''});}
  const docs=await readDocs(dir);
  for(const e of docs.events){const prev=seenEvents.get(e);seenEvents.set(e,{first:prev?.first||tag,last:tag});}
}
const next=tag=>history[history.findIndex(h=>h.tag===tag)+1]?.tag||'12.1';
const manual=JSON.parse(await fs.readFile(manualFile,'utf8').catch(()=>'{}'));
const rules={},dropped=[];
const replacement=(name,target)=>{const r=guide.get(name)||target||'';return r&&exists(r)?r:'';};

for(const [name,d] of seen){
  if(exists(name)||liveShims.has(name))continue;
  rules[name]={group:'removed',severity:'error',replacement:replacement(name,d.target),removedIn:next(d.last),source:'Shim in '+d.file+' until '+d.last};
}
for(const [name,target] of guide){
  if(rules[name]||exists(name)||liveShims.has(name))continue;
  rules[name]={group:'removed',severity:'error',replacement:exists(target)?target:'',removedIn:'11.0.0',source:'Blizzard_Deprecated/11_0_0_SpellBookAPITransitionGuide.lua'};
}
for(const [name,d] of liveShims){
  if(exists(name))continue;
  const target=guide.get(name)||d.target,ok=target&&exists(target);
  if(target&&!ok&&/^C_CombatLog\./.test(target))rules[name]={group:'combatlog',severity:'error',replacement:'',removedIn:'12.0.0',source:'Shim in '+d.file+' points to '+target+', which moved to the secure environment'};
  else rules[name]={group:'deprecated',severity:'warning',replacement:ok?target:'',deprecatedIn:seen.get(name)?.first||'12.1.5',source:'Shim in '+d.file+' (loads only while loadDeprecationFallbacks is on)'};
}
for(const [name,m] of Object.entries(manual.globals||{})){
  if(exists(name)){dropped.push(name+' (still exists)');continue;}
  if(m.replacement&&!/[:[]/.test(m.replacement)&&!exists(m.replacement))dropped.push(name+' replacement '+m.replacement+' (not in this build)');
  rules[name]={...rules[name],...m};
}

const events={};
for(const [e,v] of seenEvents)if(!now.events.has(e))events[e]={group:'event',severity:'error',removedIn:next(v.last),replacement:manual.eventReplacements?.[e]||''};
for(const [e,v] of Object.entries(manual.events||{}))events[e]={...events[e],...v};

const secret={};
// Only the restrictions addons hit in combat and instances: cooldowns, auras, health, power, casts, threat.
// Identity, name and stat secrecy applies to restricted units (for example enemy players) and is left out to keep the check quiet.
const SECRET_FLAGS=/^(SecretReturns|SecretWhenInCombat|SecretWhen(Spell)?Cooldowns?Restricted|SecretWhenUnit(Aura|HealthMax|Power|PowerMax|SpellCast|ThreatValues)Restricted)$/;
for(const [name,flags] of now.fns){const s=flags.filter(f=>SECRET_FLAGS.test(f));if(s.length)secret[name]=s;}

const result={
  generatedAt:new Date().toISOString().slice(0,10),build:manual.build||'',
  sources:['Blizzard UI source '+(manual.build||'live')+' (Blizzard_APIDocumentationGenerated, Blizzard_Deprecated*)','History tags '+history.map(h=>h.tag).join(', '),...(manual.sources||[])],
  globals:Object.fromEntries(Object.entries(rules).sort(([a],[b])=>a.localeCompare(b))),
  events:Object.fromEntries(Object.entries(events).sort(([a],[b])=>a.localeCompare(b))),
  methods:Object.fromEntries(Object.entries(manual.methods||{}).filter(([m,v])=>v.group==='lockdown'||!now.methods.has(m)||(dropped.push(m+' (method still documented)'),false))),
  secret:Object.fromEntries(Object.entries(secret).sort(([a],[b])=>a.localeCompare(b))),
  lockdown:manual.lockdown||{}
};
await fs.writeFile(out,JSON.stringify(result,null,1)+'\n');
const count=g=>Object.values(rules).filter(r=>r.group===g).length;
console.log(`removed ${count('removed')}, deprecated ${count('deprecated')}, combatlog ${count('combatlog')}, events ${Object.keys(events).length}, methods ${Object.keys(result.methods).length}, secret ${Object.keys(secret).length}`);
if(dropped.length)console.log('Manual rules dropped: '+dropped.join(', '));
