import fs from 'node:fs/promises';
import path from 'node:path';
import luaparse from 'luaparse';
import { walk,readSource,sha } from './files.mjs';
import { checkApi,definedGlobals,rules as apiRules } from './api-check.mjs';
export const profiles={retail:{name:'Retail',build:'12.1.5.70448',interface:120105},forever:{name:'Forever',build:'1.60.1.70425',interface:16001}};
export function parseLua(text){return luaparse.parse(Buffer.from(text.replace(/^\uFEFF/,''),'utf8').toString('latin1'),{luaVersion:'5.1',locations:true,scope:true,encodingMode:'pseudo-latin1'});}
export async function analyze(project,profile='retail'){
  const started=Date.now();const files=await walk(project.root);const issues=[];let luaCount=0;
  const add=(severity,kind,title,file,line,detail,extra={})=>issues.push({id:sha([kind,file,line,detail].join(':')).slice(0,16),severity,kind,title,file,line,detail,...extra});
  const texts=new Map();const modules=[];const asts=new Map();
  for(const file of files){const source=await readSource(project.root,file);texts.set(file,source.text);
    if(file.endsWith('.toc')){
      const ver=source.text.match(/^##\s*Version:\s*(.+)/m)?.[1]?.trim();const display=source.text.match(/^##\s*Title:\s*(.+)/m)?.[1]?.replace(/\|c[\da-f]{8}|\|r/gi,'').trim();
      modules.push({name:display||path.basename(file,'.toc'),file,version:ver||'Unknown'});
      const declared=source.text.match(/^##\s*Interface:\s*(.+)/m)?.[1];
      const versions=declared?declared.split(/[, ]+/).map(Number).filter(Boolean):[];
      if(profile==='retail'&&versions.length&&versions.every(v=>v<120000))add('error','interface','Addon will not load on Retail',file,1,`TOC declares ${declared.trim()}. Since 12.0.0 the Retail client does not load addons below Interface 120000. Add ${profiles.retail.interface} to the ## Interface line.`,{confidence:'Confirmed: Patch 12.0.0 load rule'});
      else if(declared&&!versions.includes(profiles[profile].interface))add('warning','interface','Client interface needs review',file,1,`TOC declares ${declared.trim()}; selected target is ${profiles[profile].build} (Interface ${profiles[profile].interface}). This alone does not prove runtime incompatibility.`);
    }
    if(file.endsWith('.lua')){luaCount++;try{asts.set(file,parseLua(source.text));}catch(e){add('error','syntax','Lua syntax error',file,e.line||1,e.message);}}
  }
  // Retail API migration rules; the Forever client has its own API surface and no bundled rule set.
  if(profile==='retail'){const projectGlobals=new Set();for(const ast of asts.values())for(const name of definedGlobals(ast))projectGlobals.add(name);for(const [file,ast] of asts)checkApi(ast,texts.get(file),file,add,{projectGlobals});}
  const checked=new Set();
  async function exactFile(relative){let current=project.root;for(const part of relative.split('/')){if(!part||part==='.')continue;const entries=await fs.readdir(current);if(!entries.includes(part))return false;current=path.join(current,part);}return (await fs.stat(current)).isFile();}
  async function resolveRef(owner,ref,line){
    ref=ref.replaceAll('\\','/');const parent=path.posix.dirname(owner);const candidate=path.posix.normalize(path.posix.join(parent,ref));const rootRef=path.posix.normalize(ref);
    for(const rel of [...new Set([candidate,rootRef])]){
      if(rel.startsWith('../')||path.posix.isAbsolute(rel))continue;
      try{const actual=await fs.realpath(path.join(project.root,rel));const base=await fs.realpath(project.root);if(actual.startsWith(base+path.sep)&&await exactFile(rel)) {if(rel.endsWith('.xml'))await xml(rel);return;}}catch{}
    }
    add('error','dependency','Missing load dependency',owner,line,`Cannot resolve “${ref}” relative to the loader or addon root. Check the installed library, file name and letter case.`);
  }
  async function xml(file){if(checked.has(file))return;checked.add(file);const text=await fs.readFile(path.join(project.root,file),'utf8');const clean=text.replace(/<!--[\s\S]*?-->/g,s=>s.replace(/[^\n]/g,' '));for(const m of clean.matchAll(/<(?:Script|Include)\s+file\s*=\s*["']([^"']+)["']/g))await resolveRef(file,m[1],clean.slice(0,m.index).split('\n').length);}
  for(const [file,text] of texts)if(file.endsWith('.toc')){for(const [i,line] of text.split(/\r?\n/).entries()){const entry=line.trim();if(entry&&!entry.startsWith('#'))await resolveRef(file,entry.split(' [')[0],i+1);}}
  issues.sort((a,b)=>({error:0,warning:1,info:2}[a.severity]-{error:0,warning:1,info:2}[b.severity])||a.file.localeCompare(b.file)||a.line-b.line);
  return {issues,files,modules,luaCount,duration:Date.now()-started,scannedAt:new Date().toISOString(),profile,apiCoverage:profile==='retail'?`Retail rules from Blizzard UI source ${apiRules.build} (${Object.keys(apiRules.globals).length} functions, ${Object.keys(apiRules.events).length} events, ${Object.keys(apiRules.secret).length} secret-value APIs). Static checks only; test in game.`:'No bundled API rules for this client.'};
}
export function parseErrors(text,files){
  if(typeof text!=='string'||text.length>5e6)throw Error('Error log exceeds 5 MB');
  const issues=[];const seen=new Set();
  for(const line of text.split(/\r?\n/)){
    const m=line.match(/([^\s"\[\]]+\.lua)["\]]?:(\d+):\s*(.+)/i);if(!m)continue;
    const source=m[1].replaceAll('\\','/');const candidates=files.filter(f=>source===f||source.endsWith('/'+f)||f.endsWith('/'+source)||path.posix.basename(f)===path.posix.basename(source));
    const file=candidates.length===1?candidates[0]:null;const detail=m[3];if(/^in (?:function|main chunk|method|upvalue|local|field)\b/.test(detail))continue;const key=`${file||source}:${m[2]}:${detail}`;if(seen.has(key))continue;seen.add(key);
    issues.push({id:sha(key).slice(0,16),severity:'error',kind:'runtime',title:'Lua runtime error',file,line:Number(m[2]),detail,reportedFile:source,trace:text.slice(0,30000),confidence:file?'Matched source file':'File match unresolved'});
  }
  if(!issues.length)throw Error('No file.lua:line: message entries found. Paste the full BugSack error text, or import BugGrabber SavedVariables.');
  return issues;
}
