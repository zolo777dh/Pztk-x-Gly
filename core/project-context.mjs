import path from 'node:path';
import {walk,readSource,sha} from './files.mjs';
import {prepareContext} from './ai-context.mjs';
import {parseLua,profiles} from './analyzer.mjs';

const symbol=n=>!n?'':n.type==='Identifier'?n.name:n.type==='MemberExpression'?symbol(n.base)+'.'+n.identifier.name:'';
function luaFacts(text){const definitions=[],calls=[];try{const ast=parseLua(text);function visit(n){if(!n||typeof n!=='object')return;
 if(n.type==='FunctionDeclaration'&&n.identifier)definitions.push({symbol:symbol(n.identifier),line:n.loc.start.line});
 if(['CallExpression','TableCallExpression','StringCallExpression'].includes(n.type)&&symbol(n.base))calls.push({symbol:symbol(n.base),line:n.loc.start.line});
 for(const [k,v]of Object.entries(n)){if(['loc','globals','comments'].includes(k))continue;if(Array.isArray(v))v.forEach(visit);else if(v&&typeof v==='object')visit(v);}}
 visit(ast);}catch{}return {definitions,calls};}
export async function projectIndex(projects){
 const files=[],warnings=[],started=Date.now(),seen=new Set();let bytes=0;
 for(const project of [...projects].sort((a,b)=>b.root.length-a.root.length))for(const file of await walk(project.root)){
  if(files.length>=6000||bytes>64e6||Date.now()-started>20000){warnings.push('Context indexing reached its limit. Select fewer modules to inspect the remaining files.');break;}
  const absolute=path.resolve(project.root,file),key=process.platform==='win32'?absolute.toLowerCase():absolute;if(seen.has(key))continue;seen.add(key);
  try{const source=await readSource(project.root,file);bytes+=source.size;const parse=source.size<300000&&file.endsWith('.lua')?luaFacts(source.text):{definitions:[],calls:[]};
   files.push({projectId:project.id,projectName:project.name,root:project.root,file,hash:source.hash,size:source.size,text:source.text,...parse});
  }catch(e){warnings.push(project.name+'/'+file+': '+e.message);}
 }
 const loaders=files.filter(f=>/\.(toc|xml)$/i.test(f.file)).map(f=>({projectId:f.projectId,file:f.file,dependencies:[...f.text.matchAll(/^##\s*(?:Dependencies|RequiredDeps|OptionalDeps):\s*(.+)$/gmi)].flatMap(m=>m[1].split(/[, ]+/).filter(Boolean)),references:f.file.endsWith('.toc')?f.text.split(/\r?\n/).map((s,i)=>({file:s.trim().split(' [')[0].replaceAll('\\','/'),line:i+1})).filter(r=>r.file&&!r.file.startsWith('#')):[...f.text.matchAll(/<(?:Script|Include)\s+file\s*=\s*["']([^"']+)/g)].map(m=>({file:m[1].replaceAll('\\','/'),line:f.text.slice(0,m.index).split('\n').length}))}));
 return {files,loaders,warnings:warnings.slice(0,30),bytes};
}
export async function buildProjectContext(projects,{client='retail',message='',issue=null,file='',projectId='',focusLine=1,history=[]}={}){
 if(!profiles[client])throw Error('Choose Retail or Forever.');if(!projects.length)throw Error('Connect and select addon projects first.');
 const index=await projectIndex(projects),words=String(message+' '+(issue?.detail||'')).toLowerCase().match(/[a-z_][a-z0-9_.]{2,}/g)||[];
 const target=index.files.find(f=>f.projectId===projectId&&f.file===file);
 const trace=String(issue?.trace||'');const candidates=index.files.map(f=>{const referenced=trace.includes(f.file)||trace.includes(f.projectName+'/'+f.file);const mentioned=words.filter(w=>f.text.toLowerCase().includes(w)||f.file.toLowerCase().includes(w));return {f,score:(f===target?10000:0)+(referenced?500:0)+mentioned.length*4+(/\.(toc|xml)$/.test(f.file)?1:0)};});
 const seed=candidates.filter(c=>c.score>1).sort((a,b)=>b.score-a.score).slice(0,3);
 const identifiers=new Set(seed.flatMap(c=>[...c.f.calls,...c.f.definitions].map(x=>x.symbol)));
 for(const c of candidates)if(c.f!==target){c.score+=c.f.definitions.filter(d=>identifiers.has(d.symbol)).length*50;c.score+=c.f.calls.filter(d=>target?.definitions.some(x=>x.symbol===d.symbol)).length*15;}
 candidates.sort((a,b)=>b.score-a.score||a.f.file.localeCompare(b.f.file));
 const snapshots=[],sources=[];let total=0;
 for(const {f,score}of candidates){if(sources.length>=10||total>=68000)break;if(score<=1&&sources.length>=3)continue;
  let line=f===target?focusLine:1;const relevant=f.definitions.find(d=>identifiers.has(d.symbol)||words.some(w=>d.symbol.toLowerCase().includes(w)));if(f!==target&&relevant)line=relevant.line;
  const prepared=prepareContext({source:f.text,file:f.file,build:profiles[client].build,issue:f===target?issue:null,focusLine:line,limit:Math.min(f===target?14000:7500,68000-total)});
  snapshots.push({projectId:f.projectId,file:f.file,hash:f.hash,scope:prepared.scope,excerpt:prepared.context.source});sources.push({projectId:f.projectId,project:f.projectName,file:f.file,scope:prepared.scope,source:prepared.context.source,definitions:f.definitions.slice(0,30),reason:f===target?'selected file':score>=50?'matching symbols or stack trace':'request keywords / loader'});total+=prepared.context.source.length;
 }
 const graph=seed.flatMap(c=>c.f.calls.flatMap(call=>index.files.flatMap(f=>f.definitions.filter(d=>d.symbol===call.symbol).map(d=>({symbol:call.symbol,caller:{projectId:c.f.projectId,file:c.f.file,line:call.line},definition:{projectId:f.projectId,file:f.file,line:d.line}}))))).slice(0,80);
 const context={client,build:profiles[client].build,request:String(message).slice(0,12000),issue:issue?{detail:String(issue.detail||'').slice(0,4000),trace:trace.slice(0,12000),line:issue.line}:null,projects:projects.map(p=>({id:p.id,name:p.name,registeredClient:p.client})),loaders:index.loaders.slice(0,60),sources,relationships:graph,relationshipNote:'Symbol matches are lexical candidates, not proof of shared runtime namespace. Check loaders and initialization order.',apiReference:{source:'Bundled analyzer advisory rules and connected addon source',exactBuildCoverage:'partial',rule:'Do not assert API availability without source evidence; request missing API declarations or in-game checks.'},history:history.slice(-8).map(m=>({role:m.role,text:m.text.slice(0,4000)})),index:{files:index.files.length,omitted:index.files.length-sources.length,warnings:index.warnings}};
 // Trim supporting context before rejecting a large real addon workspace.
 while(JSON.stringify(context).length>112000&&sources.length>1){sources.pop();snapshots.pop();context.index.omitted++;}
 if(JSON.stringify(context).length>112000){context.loaders=context.loaders.map(l=>({...l,omittedReferences:Math.max(0,l.references.length-15),references:l.references.slice(0,15)}));context.relationships=context.relationships.slice(0,20);}
 if(JSON.stringify(context).length>112000)context.history=context.history.slice(-4);
 if(JSON.stringify(context).length>120000)throw Error('Project context is too large. Select fewer modules.');
 return {context,snapshots,indexSummary:{files:index.files.length,loaders:index.loaders,relationships:graph,warnings:index.warnings},fingerprint:sha(JSON.stringify(snapshots.map(s=>[s.projectId,s.file,s.hash])))};
}
