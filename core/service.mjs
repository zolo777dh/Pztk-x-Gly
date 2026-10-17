import fs from 'node:fs/promises';
import path from 'node:path';
import {uid,writeAtomic,readSource,walk,copyResources} from './files.mjs';
import {analyze,parseErrors} from './analyzer.mjs';
import {Patches} from './patches.mjs';
import {PackCodec,noteToPack} from './packs.mjs';
import {parseSavedVariables,savedSummary} from './saved.mjs';
import {reportCode,wclQuery,reportQuery,fetchTimeline,validateTimeline,assist} from './integrations.mjs';
import {parseReference,comparePulls,mapReferenceTable} from './encounters.mjs';
import {prepareContext} from './ai-context.mjs';
import {testAIConnection} from './network.mjs';
import {suggestFix} from './fixes.mjs';
import {prepareFeature,generateFeature} from './features.mjs';
import {discoverProjects} from './projects.mjs';
const defaults={client:'retail',localEndpoint:'http://127.0.0.1:11434/v1',localModel:'qwen2.5-coder:7b',cloudEndpoint:'https://api.openai.com/v1',cloudModel:'',aiMode:'local'};
export class DoctorService {
  constructor(dataDir,resources,{fetcher}={}){this.fetcher=fetcher;this.dataDir=dataDir;this.resources=resources;this.file=path.join(dataDir,'workspace.json');this.state={projects:[],notes:[],hiddenRoots:[],settings:{...defaults}};this.scans=new Map();this.tokens={};this.features=new Map();this.patches=new Patches(dataDir);this.codec=new PackCodec(resources);}
  async init(){await fs.mkdir(this.dataDir,{recursive:true});try{const s=JSON.parse(await fs.readFile(this.file,'utf8'));this.state={projects:s.projects||[],notes:s.notes||[],hiddenRoots:s.hiddenRoots||[],settings:{...defaults,...s.settings}};}catch(e){if(e.code!=='ENOENT')throw Error('Workspace data could not be read. Preserve workspace.json before recovering it.');}return this;}
  async save(){await writeAtomic(this.file,JSON.stringify(this.state,null,2));}
  project(id){const p=this.state.projects.find(p=>p.id===id);if(!p)throw Error('Select an addon project');return p;}
  rootKey(root){return process.platform==='win32'?root.toLowerCase():root;}
  async addMany(args){const found=await discoverProjects(args.roots);const projects=[];let added=0;for(const candidate of found){const key=this.rootKey(candidate.root);if(args.refresh&&this.state.hiddenRoots.includes(key))continue;if(!args.refresh)this.state.hiddenRoots=this.state.hiddenRoots.filter(r=>r!==key);let project=this.state.projects.find(p=>this.rootKey(p.root)===key);if(!project){project={id:uid(),...candidate,client:args.client==='forever'?'forever':'retail'};this.state.projects.push(project);added++;}else project.discoveryRoots=[...new Set([...(project.discoveryRoots||[]),...candidate.discoveryRoots])];projects.push(project);}await this.save();return {projects,added,existing:projects.length-added};}
  invalidate(id){this.scans.delete(id);for(const [key,plan]of this.features)if(plan.projectId===id)this.features.delete(key);for(const [key,plan]of this.patches.plans)if(plan.projectId===id)this.patches.plans.delete(key);}
  async aiContext(args){const p=this.project(args.id);const source=await readSource(p.root,args.file);if(source.hash!==args.hash)throw Error('Source changed. Refresh and reopen it before requesting AI assistance.');return prepareContext({source:source.text,file:args.file,build:args.client==='forever'?'1.60.1.70425':'12.1.5.70448',issue:args.issue,focusLine:args.focusLine});}
  async handle(method,args={}){
    switch(method){
      case 'init':return { ...this.state,version:'0.1.2',backups:await this.patches.list(),tokens:{cloud:Boolean(this.tokens.cloud),wcl:Boolean(this.tokens.wcl)}};
      case 'project.addMany':return this.addMany(args);
      case 'project.add':{
        if(typeof args.root!=='string'||!args.root)throw Error('Select an addon directory');const root=await fs.realpath(args.root);const existing=this.state.projects.find(p=>p.root===root);if(existing)return existing;
        this.state.hiddenRoots=this.state.hiddenRoots.filter(r=>r!==this.rootKey(root));const entries=await fs.readdir(root);const toc=entries.find(f=>f.toLowerCase().endsWith('.toc'));if(!toc)throw Error('Select the addon folder containing its .toc file, not the parent Interface/AddOns folder.');
        const project={id:uid(),name:path.basename(toc,'.toc'),root,client:args.client==='forever'?'forever':'retail'};this.state.projects.push(project);await this.save();return project;
      }
      case 'project.remove':{const p=this.project(args.id);this.state.hiddenRoots=[...new Set([...this.state.hiddenRoots,this.rootKey(p.root)])];this.invalidate(args.id);this.state.projects=this.state.projects.filter(p=>p.id!==args.id);this.scans.delete(args.id);await this.save();return true;}
      case 'demo':{const root=path.join(this.dataDir,'demo','NaowhDoctorDemo');await fs.mkdir(path.dirname(root),{recursive:true});try{await fs.access(path.join(root,'NaowhDoctorDemo.toc'));}catch{await copyResources(path.join(this.resources,'demo','NaowhDoctorDemo'),root);}const p=await this.handle('project.add',{root});return {project:p,errorText:await fs.readFile(path.join(this.resources,'demo','error.txt'),'utf8')};}
      case 'project.refresh':{const p=this.project(args.id);this.invalidate(p.id);const discovered=await this.addMany({roots:p.discoveryRoots||[p.root],client:p.client,refresh:true});const scan=await analyze(p,args.client||p.client);this.scans.set(p.id,scan);return {...scan,addedProjects:discovered.added};}
      case 'scan':{const p=this.project(args.id);const scan=await analyze(p,args.client||p.client);this.scans.set(p.id,scan);return scan;}
      case 'source':return readSource(this.project(args.id).root,args.file);
      case 'errors':{const p=this.project(args.id);const scan=this.scans.get(p.id);const files=scan?.files||await walk(p.root);let text=args.text;let summary=null;
        if(args.saved){const saved=parseSavedVariables(args.text);summary=savedSummary(saved);text=summary.filter(s=>s.type==='error').map(s=>s.text).join('\n');if(!text)return {issues:[],summary};}
        return {issues:parseErrors(text,files),summary};
      }
      case 'saved':{const data=parseSavedVariables(args.text);return {summary:savedSummary(data),variables:Object.keys(data),importedAt:new Date().toISOString(),freshness:'Last client save only — /reload, logout or exit. Not live memory.'};}
      case 'patch.preview':return this.patches.preview(this.project(args.id),args.file,args.replacement,args.hash);
      case 'patch.apply':return this.patches.apply(this.project(args.id),args.plan);
      case 'backup':return this.patches.snapshot(this.project(args.id));
      case 'backups':return this.patches.list();
      case 'restore.preview':return this.patches.restorePreview(this.project(args.id),args.backup);
      case 'restore.apply':return this.patches.restore(this.project(args.id),args.plan);
      case 'settings':{
        const incoming=args.settings||{};for(const k of Object.keys(defaults))if(typeof incoming[k]==='string')this.state.settings[k]=incoming[k].slice(0,2000);
        if(typeof args.cloudToken==='string')this.tokens.cloud=args.cloudToken.trim();if(typeof args.wclToken==='string')this.tokens.wcl=args.wclToken.trim();await this.save();return {settings:this.state.settings,tokens:{cloud:Boolean(this.tokens.cloud),wcl:Boolean(this.tokens.wcl)}};
      }
      case 'ai.test':return testAIConnection({settings:{...this.state.settings,...args.settings},token:args.mode==='cloud'?(args.token||this.tokens.cloud):null,mode:args.mode,fetcher:this.fetcher});
      case 'ai.preview':{const prepared=await this.aiContext(args);return {scope:prepared.scope,context:prepared.context};}
      case 'ai':{const prepared=await this.aiContext(args);const result=await assist({settings:this.state.settings,token:args.mode==='cloud'?this.tokens.cloud:null,mode:args.mode,context:prepared.context,fetcher:this.fetcher});return {...result,replacement:prepared.expand(result.replacement),scope:prepared.scope};}
      case 'feature.preview':{const plan=await prepareFeature(this.project(args.id),args);for(const [key,value]of this.features)if(Date.now()-value.created>3600000)this.features.delete(key);if(this.features.size>=20)this.features.delete(this.features.keys().next().value);this.features.set(plan.id,plan);return {id:plan.id,context:plan.context,mode:plan.mode};}
      case 'feature.generate':{const p=this.project(args.id);const plan=this.features.get(args.plan);if(!plan||plan.projectId!==p.id||Date.now()-plan.created>3600000)throw Error('Feature context expired. Prepare it again.');for(const snapshot of plan.snapshots)if((await readSource(p.root,snapshot.file)).hash!==snapshot.hash)throw Error('Source changed since this feature context was prepared. Refresh and prepare it again.');const result=await generateFeature(plan,{settings:this.state.settings,token:plan.mode==='cloud'?this.tokens.cloud:null,fetcher:this.fetcher});if(!result.replacement)return result;const preview=await this.patches.preview(p,result.file,result.replacement,result.source.hash);return {...result,preview:{...preview,explanation:result.explanation,insertion:`${result.file}:${result.line} · ${result.position} exact anchor`}};}
      case 'fix.suggest':{const p=this.project(args.id);const source=await readSource(p.root,args.file);if(source.hash!==args.hash)throw Error('Source changed. Refresh it before preparing a fix.');return suggestFix(p,args.file,source.text,args.issue);}
      case 'notes.save':{
        const note=args.note;if(!note||typeof note.title!=='string'||note.title.length>200||JSON.stringify(note).length>2e6)throw Error('Invalid note or note exceeds 2 MB');
        const existing=this.state.notes.find(n=>n.id===note.id);const history=existing?[{at:existing.updatedAt,title:existing.title,body:existing.body,events:existing.events},...(existing.history||[])].slice(0,20):[];
        const saved={...note,id:existing?.id||uid(),history,updatedAt:new Date().toISOString()};this.state.notes=this.state.notes.filter(n=>n.id!==saved.id);this.state.notes.unshift(saved);await this.save();return saved;
      }
      case 'notes.delete':this.state.notes=this.state.notes.filter(n=>n.id!==args.id);await this.save();return true;
      case 'pack.encode':return {text:this.codec.encode(noteToPack(args.note)),payload:noteToPack(args.note)};
      case 'pack.decode':return this.codec.decode(args.text);
      case 'wcl.report':{const code=reportCode(args.code);const report=await wclQuery(reportQuery,{code},this.tokens.wcl,this.fetcher);if(!report)throw Error('Report not accessible');return {code,...report};}
      case 'wcl.fight':return fetchTimeline(args.code,args.fightId,this.tokens.wcl,path.join(this.dataDir,'timelines'),this.fetcher);
      case 'wcl.batchReports':{const codes=[...new Set(String(args.links).split(/\s+/).filter(Boolean).map(reportCode))];if(!codes.length||codes.length>20)throw Error('Enter between 1 and 20 report links');const reports=[];for(const code of codes){const report=await wclQuery(reportQuery,{code},this.tokens.wcl,this.fetcher);if(!report)throw Error('Report unavailable: '+code);reports.push({code,...report});}return reports;}
      case 'wcl.batchFights':{if(!Array.isArray(args.fights)||!args.fights.length||args.fights.length>30)throw Error('Select 1–30 fights');const timelines=[];for(const fight of args.fights)timelines.push(await fetchTimeline(fight.code,fight.id,this.tokens.wcl,path.join(this.dataDir,'timelines'),this.fetcher));return timelines;}
      case 'encounters.compare':{const cached=await this.handle('timelines');const selected=cached.filter(t=>(args.ids||[]).includes(t.id));return comparePulls(selected,args.options);}
      case 'reference.import':{const ref=parseReference(args.text,args.filename);await writeAtomic(path.join(this.dataDir,'references',ref.id+'.json'),JSON.stringify(ref));return ref;}
      case 'reference.example':return this.handle('reference.import',{text:await fs.readFile(path.join(this.resources,'demo','holy_paladin_priority_presets_EN.html'),'utf8'),filename:'holy_paladin_priority_presets_EN.html'});
      case 'reference.map':{if(!/^[a-f\d]{16}$/.test(args.id))throw Error('Invalid reference id');const ref=JSON.parse(await fs.readFile(path.join(this.dataDir,'references',args.id+'.json'),'utf8'));return mapReferenceTable(ref,args.options);}
      case 'references':{const dir=path.join(this.dataDir,'references');await fs.mkdir(dir,{recursive:true});const list=[];for(const file of await fs.readdir(dir))if(file.endsWith('.json'))list.push(JSON.parse(await fs.readFile(path.join(dir,file),'utf8')));return list;}
      case 'timeline.import':{const value=validateTimeline(JSON.parse(args.text));await writeAtomic(path.join(this.dataDir,'timelines',value.id+'.json'),JSON.stringify(value));return value;}
      case 'timelines':{const dir=path.join(this.dataDir,'timelines');await fs.mkdir(dir,{recursive:true});const list=[];for(const file of await fs.readdir(dir))if(file.endsWith('.json')){try{list.push(JSON.parse(await fs.readFile(path.join(dir,file),'utf8')));}catch{}}return list;}
      default:throw Error('Unknown application command');
    }
  }
}
