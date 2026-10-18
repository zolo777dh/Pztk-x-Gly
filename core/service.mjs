import {mythicCatalog} from './mythic-catalog.mjs';
import fs from 'node:fs/promises';
import path from 'node:path';
import {uid,writeAtomic,readSource,walk,copyResources,sha} from './files.mjs';
import {analyze,parseErrors} from './analyzer.mjs';
import {Patches} from './patches.mjs';
import {PackCodec,noteToPack} from './packs.mjs';
import {parseSavedVariables,savedSummary} from './saved.mjs';
import {assist} from './integrations.mjs';
import {prepareContext} from './ai-context.mjs';
import {testAIConnection,listAIModels,cloudProvider,aiEndpoint,aiModel} from './network.mjs';
import {suggestFix} from './fixes.mjs';
import {prepareFeature,generateFeature,insertFeature,FEATURE_CONTRACT} from './features.mjs';
import {browserPrompt,browserReply,REVIEW_CONTRACT} from './browser-assistant.mjs';
import {discoverProjects} from './projects.mjs';
import {searchSources} from './source-search.mjs';
import {ImportantAbilities} from './important-abilities.mjs';
import {SpellNames} from './spell-names.mjs';
import {NsrEditor,readNsrAddonNames} from './nsr-editor.mjs';
import {DefensivePlanner,inspectDefenseTable} from './defensive-planner.mjs';
const {version:APP_VERSION}=JSON.parse(await fs.readFile(new URL('../package.json',import.meta.url),'utf8'));
const defaults={cloudProvider:'openai',anthropicModel:'',compatibleEndpoint:'https://api.openai.com/v1',compatibleModel:'',client:'retail',localEndpoint:'http://127.0.0.1:11434/v1',localModel:'qwen2.5-coder:7b',cloudEndpoint:'https://api.openai.com/v1',cloudModel:'',aiMode:'browser',assistantWorkflow:'browser-v1'};
export class DoctorService {
  constructor(dataDir,resources,{fetcher}={}){this.fetcher=fetcher;this.dataDir=dataDir;this.resources=resources;this.file=path.join(dataDir,'workspace.json');this.state={projects:[],knownProjects:[],notes:[],hiddenRoots:[],settings:{...defaults}};this.scans=new Map();this.aiModelLists=new Map();this.tokens={};this.features=new Map();this.patches=new Patches(dataDir);this.codec=new PackCodec(resources);this.planner=new DefensivePlanner(dataDir,this.codec);this.nsrEditor=new NsrEditor(this.planner);this.spellNames=new SpellNames(dataDir,fetcher);this.importantAbilities=new ImportantAbilities(dataDir,resources,fetcher);}
  async init(){await fs.mkdir(this.dataDir,{recursive:true});try{const s=JSON.parse(await fs.readFile(this.file,'utf8'));this.state={projects:[],knownProjects:[...new Map([...(s.knownProjects||[]),...(s.projects||[])].map(p=>[this.rootKey(p.root),p])).values()],notes:s.notes||[],hiddenRoots:[],settings:{...defaults,...s.settings}};if(!s.settings?.assistantWorkflow)this.state.settings.aiMode='browser';if(!s.settings?.cloudProvider&&s.settings?.cloudEndpoint&&s.settings.cloudEndpoint!=='https://api.openai.com/v1'){this.state.settings.cloudProvider='compatible';this.state.settings.compatibleEndpoint=s.settings.cloudEndpoint;this.state.settings.compatibleModel=s.settings.cloudModel||'';}}catch(e){if(e.code!=='ENOENT')throw Error('Workspace data could not be read. Preserve workspace.json before recovering it.');}return this;}
  cloudKey(provider=cloudProvider(this.state.settings)){return this.tokens[provider]||'';}
  tokenStatus(){return {cloud:Boolean(this.cloudKey()),cloudProviders:Object.fromEntries(['openai','anthropic','compatible'].map(p=>[p,Boolean(this.tokens[p])]))};}
  aiTarget(mode){const model=aiModel(this.state.settings,mode);if(!model?.trim())throw Error('Choose a model in Settings: load available models or enter a model ID, then Save Settings.');const provider=mode==='local'?'local':cloudProvider(this.state.settings),endpoint=aiEndpoint(this.state.settings,mode).base;if(mode==='cloud'){const listed=this.aiModelLists.get(sha(provider+'|'+endpoint+'|'+this.cloudKey(provider)));if(listed&&!listed.has(model))throw Error('This model is not in the supported model list returned for your current API key. Synchronize models in Settings and choose one from that list.');}return {provider,model,endpoint};}
  checkAiTarget(target,mode){if(target&&['provider','model','endpoint'].some(key=>target[key]!==this.aiTarget(mode)[key]))throw Error('AI provider, model or endpoint changed. Review and prepare the context again.');}
  async save(){this.state.knownProjects=[...new Map([...(this.state.knownProjects||[]),...this.state.projects].map(p=>[this.rootKey(p.root),p])).values()];await writeAtomic(this.file,JSON.stringify({...this.state,projects:[]},null,2));}
  project(id){const p=this.state.projects.find(p=>p.id===id);if(!p)throw Error('Select an addon project');return p;}
  rootKey(root){return process.platform==='win32'?root.toLowerCase():root;}
  async addMany(args){const found=await discoverProjects(args.roots);const projects=[];let added=0;for(const candidate of found){const key=this.rootKey(candidate.root);if(args.refresh&&this.state.hiddenRoots.includes(key))continue;if(!args.refresh)this.state.hiddenRoots=this.state.hiddenRoots.filter(r=>r!==key);let project=this.state.projects.find(p=>this.rootKey(p.root)===key);if(!project){const previous=this.state.knownProjects.find(p=>this.rootKey(p.root)===key);project={...previous,id:previous?.id||uid(),...candidate,client:args.client==='forever'?'forever':'retail'};this.state.projects.push(project);added++;}else project.discoveryRoots=[...new Set([...(project.discoveryRoots||[]),...candidate.discoveryRoots])];projects.push(project);}await this.save();return {projects,added,existing:projects.length-added};}
  async nsrNames(){const local=await readNsrAddonNames(this.state.projects);await this.spellNames.load();return {spells:{...this.spellNames.names,...local.spells},bosses:local.bosses,sources:{...Object.fromEntries(Object.keys(this.spellNames.names).map(id=>[id,'English spell name cache'])),...Object.fromEntries(Object.keys(local.spells).map(id=>[id,'Connected NSR addon']))}};}
  invalidate(id){this.scans.delete(id);for(const [key,plan]of this.features)if(plan.projectId===id)this.features.delete(key);for(const [key,plan]of this.patches.plans)if(plan.projectId===id)this.patches.plans.delete(key);}
  async aiContext(args){const p=this.project(args.id);const source=await readSource(p.root,args.file);if(source.hash!==args.hash)throw Error('Source changed. Refresh and reopen it before requesting AI assistance.');return prepareContext({source:source.text,file:args.file,build:args.client==='forever'?'1.60.1.70425':'12.1.5.70448',issue:args.issue,focusLine:args.focusLine});}
  async handle(method,args={}){
    switch(method){
      case 'init':return { ...this.state,version:APP_VERSION,backups:await this.patches.list(),tokens:this.tokenStatus()};
      case 'project.addMany':return this.addMany(args);
      case 'project.add':{
        if(typeof args.root!=='string'||!args.root)throw Error('Select an addon directory');const root=await fs.realpath(args.root);const existing=this.state.projects.find(p=>p.root===root);if(existing)return existing;
        this.state.hiddenRoots=this.state.hiddenRoots.filter(r=>r!==this.rootKey(root));const entries=await fs.readdir(root);const toc=entries.find(f=>f.toLowerCase().endsWith('.toc'));if(!toc)throw Error('Select the addon folder containing its .toc file, not the parent Interface/AddOns folder.');
        const previous=this.state.knownProjects.find(p=>this.rootKey(p.root)===this.rootKey(root));const project={id:previous?.id||uid(),name:path.basename(toc,'.toc'),root,discoveryRoots:[root],client:args.client==='forever'?'forever':'retail'};this.state.projects.push(project);await this.save();return project;
      }
      case 'project.remove':{const p=this.project(args.id);this.state.hiddenRoots=[...new Set([...this.state.hiddenRoots,this.rootKey(p.root)])];this.invalidate(args.id);this.state.projects=this.state.projects.filter(p=>p.id!==args.id);this.scans.delete(args.id);await this.save();return true;}
      case 'demo':{const root=path.join(this.dataDir,'demo','NaowhDoctorDemo');await fs.mkdir(path.dirname(root),{recursive:true});try{await fs.access(path.join(root,'NaowhDoctorDemo.toc'));}catch{await copyResources(path.join(this.resources,'demo','NaowhDoctorDemo'),root);}const p=await this.handle('project.add',{root});return {project:p,errorText:await fs.readFile(path.join(this.resources,'demo','error.txt'),'utf8')};}
      case 'project.refresh':{const p=this.project(args.id);this.invalidate(p.id);const discovered=await this.addMany({roots:p.discoveryRoots||[p.root],client:p.client,refresh:true});const scan=await analyze(p,args.client||p.client);this.scans.set(p.id,scan);return {...scan,addedProjects:discovered.added};}
      case 'scan':{const p=this.project(args.id);const scan=await analyze(p,args.client||p.client);this.scans.set(p.id,scan);return scan;}
      case 'source':return readSource(this.project(args.id).root,args.file);
      case 'source.search':return searchSources(this.state.projects,args);
      case 'spells.resolve':return this.spellNames.resolve(args.ids,{online:args.online!==false});
      case 'nsr.open':{const id=await this.nsrEditor.open(args);await writeAtomic(path.join(this.planner.dir,'active.json'),JSON.stringify({profileId:args.profileId,profileKey:args.profileKey||''}));return this.nsrEditor.view(id,[],await this.nsrNames());}
      case 'nsr.referenceTable':return this.planner.read('tables',args.id);
      case 'nsr.read':return this.nsrEditor.view(args.id,[],await this.nsrNames());
      case 'nsr.change':return this.nsrEditor.change(args,[],await this.nsrNames());
      case 'nsr.assignNpc':return this.nsrEditor.assignNpc(args,mythicCatalog(JSON.parse(await fs.readFile(path.join(this.resources,'npc-catalog.json'),'utf8'))),[],await this.nsrNames());
      case 'nsr.export':return this.nsrEditor.export(args);
      case 'nsr.reference':return this.nsrEditor.reference(args,[],await this.nsrNames());
      case 'raid.catalog':return JSON.parse(await fs.readFile(path.join(this.resources,'raid-catalog.json'),'utf8'));
      case 'nsr.assignRaid':return this.nsrEditor.assignRaid(args,await this.handle('raid.catalog'),await this.nsrNames());
      case 'npc.catalog':return this.importantAbilities.catalog();
      case 'npc.importantImport':return this.importantAbilities.import(args);
      case 'npc.importantMark':return this.importantAbilities.mark(args);
      case 'planner.createProfile':return this.planner.importProfile(this.codec.encode({format:1,name:'My defensive profile',data:{presets:{},activePreset:{},bindingsBySpec:true,abilityBindings:{},integrationRules:{}}}));
      case 'planner.state':return this.planner.state();
      case 'planner.importProfile':return this.planner.importProfile(args.text);
      case 'planner.importTable':return this.planner.importTable(args);
      case 'planner.inspectTable':return inspectDefenseTable(args.text,args.filename);
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
        const incoming=args.settings||{};if(incoming.cloudProvider!==undefined)cloudProvider(incoming);if(args.tokenProvider!==undefined)cloudProvider({cloudProvider:args.tokenProvider});for(const k of Object.keys(defaults))if(typeof incoming[k]==='string')this.state.settings[k]=incoming[k].slice(0,2000);
        if(args.clearCloudTokens)for(const p of ['openai','anthropic','compatible'])delete this.tokens[p];if(typeof args.cloudToken==='string')this.tokens[args.tokenProvider||cloudProvider(this.state.settings)]=args.cloudToken.trim();await this.save();return {settings:this.state.settings,tokens:this.tokenStatus()};
      }
      case 'ai.test':return testAIConnection({settings:{...this.state.settings,...args.settings},token:args.mode==='cloud'?(args.token||this.cloudKey(cloudProvider({...this.state.settings,...args.settings}))):null,mode:args.mode,fetcher:this.fetcher});
      case 'ai.models':{const settings={...this.state.settings,...args.settings},provider=args.mode==='cloud'?cloudProvider(settings):'local',token=args.mode==='cloud'?(args.token||this.cloudKey(provider)):null;const result=await listAIModels({settings,token,mode:args.mode,fetcher:this.fetcher});if(args.mode==='cloud'){if(this.aiModelLists.size>=20)this.aiModelLists.delete(this.aiModelLists.keys().next().value);this.aiModelLists.set(sha(provider+'|'+aiEndpoint(settings,args.mode).base+'|'+token),new Set(result.models.map(m=>m.id)));}return result;}
      case 'ai.preview':{const prepared=await this.aiContext(args);return {scope:prepared.scope,context:prepared.context,target:this.aiTarget(args.mode)};}
      case 'ai':{this.checkAiTarget(args.target,args.mode);const prepared=await this.aiContext(args);const result=await assist({settings:this.state.settings,token:args.mode==='cloud'?this.cloudKey():null,mode:args.mode,context:prepared.context,fetcher:this.fetcher});return {...result,replacement:prepared.expand(result.replacement),scope:prepared.scope};}
      case 'feature.preview':{const target=this.aiTarget(args.mode);const plan=await prepareFeature(this.project(args.id),args);plan.target=target;for(const [key,value]of this.features)if(Date.now()-value.created>3600000)this.features.delete(key);if(this.features.size>=20)this.features.delete(this.features.keys().next().value);this.features.set(plan.id,plan);return {id:plan.id,context:plan.context,mode:plan.mode,target:plan.target};}
      case 'feature.generate':{const p=this.project(args.id);const plan=this.features.get(args.plan);if(!plan||plan.projectId!==p.id||Date.now()-plan.created>3600000)throw Error('Feature context expired. Prepare it again.');this.checkAiTarget(plan.target,plan.mode);for(const snapshot of plan.snapshots)if((await readSource(p.root,snapshot.file)).hash!==snapshot.hash)throw Error('Source changed since this feature context was prepared. Refresh and prepare it again.');const result=await generateFeature(plan,{settings:this.state.settings,token:plan.mode==='cloud'?this.cloudKey():null,fetcher:this.fetcher});if(!result.replacement)return result;const preview=await this.patches.preview(p,result.file,result.replacement,result.source.hash);return {...result,preview:{...preview,explanation:result.explanation,insertion:`${result.file}:${result.line} · ${result.position} exact anchor`}};}
      case 'browser.prepare':{
        const p=this.project(args.id);let plan;
        if(args.kind==='feature')plan=await prepareFeature(p,{...args,mode:'browser'});
        else {const prepared=await this.aiContext(args);plan={id:uid(),projectId:p.id,created:Date.now(),context:prepared.context,args:{id:args.id,file:args.file,hash:args.hash,client:args.client,issue:args.issue,focusLine:args.focusLine}};}
        plan.kind=args.kind==='feature'?'feature':'analysis';plan.mode='browser';
        for(const [key,value]of this.features)if(Date.now()-value.created>3600000)this.features.delete(key);
        if(this.features.size>=20)this.features.delete(this.features.keys().next().value);this.features.set(plan.id,plan);
        return {id:plan.id,kind:plan.kind,context:plan.context,prompt:browserPrompt(plan.context,plan.kind==='feature'?FEATURE_CONTRACT:REVIEW_CONTRACT)};
      }
      case 'browser.reply':{
        const plan=this.features.get(args.plan),p=this.project(args.id);
        if(!plan||plan.mode!=='browser'||plan.projectId!==p.id||Date.now()-plan.created>3600000)throw Error('Browser context expired. Prepare it again.');
        const reply=browserReply(args.text);let result;
        if(plan.kind==='feature'){
          for(const snapshot of plan.snapshots)if((await readSource(p.root,snapshot.file)).hash!==snapshot.hash)throw Error('Source changed. Prepare a new browser request.');
          result=insertFeature(plan,reply);
        }else {
          const prepared=await this.aiContext(plan.args),source=await readSource(p.root,plan.args.file);
          result={explanation:reply.explanation,file:plan.args.file,line:prepared.scope.focusLine,source,replacement:prepared.expand(reply.replacement??null)};
        }
        if(!result.replacement)return result;
        const preview=await this.patches.preview(p,result.file,result.replacement,result.source.hash);
        return {...result,preview:{...preview,explanation:result.explanation,...(result.position?{insertion:result.file+':'+result.line+' · '+result.position+' exact anchor'}:{})}};
      }
      case 'fix.suggest':{const p=this.project(args.id);const source=await readSource(p.root,args.file);if(source.hash!==args.hash)throw Error('Source changed. Refresh it before preparing a fix.');return suggestFix(p,args.file,source.text,args.issue,this.state.projects);}
      case 'pack.encode':return {text:this.codec.encode(noteToPack(args.note)),payload:noteToPack(args.note)};
      case 'pack.decode':return this.codec.decode(args.text);
      default:throw Error('Unknown application command');
    }
  }
}
