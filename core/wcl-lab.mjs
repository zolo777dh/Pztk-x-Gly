import fs from 'node:fs/promises';
import {createReadStream} from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';
import {spawn} from 'node:child_process';
import {gunzipSync} from 'node:zlib';
import {StringDecoder} from 'node:string_decoder';
import {inside,sha,uid,writeAtomic} from './files.mjs';

const modes=new Set(['validate','selfTest','reanalyze','fixture','live','top','survey']);
const liveModes=new Set(['live','top','survey']);
const reports={validate:'validate_install_report.json',selfTest:'self_test_report.json',reanalyze:'reanalysis_report.json',fixture:'fixture_export_report.json',live:'live_export_report.json',top:'top_logs_report.json'};
const publicRun=run=>{const {child,timer,done,...result}=run;return structuredClone(result);};
const integer=(value,min,max,name)=>{const n=Number(value);if(!Number.isInteger(n)||n<min||n>max)throw Error(`${name} must be between ${min} and ${max}`);return String(n);};

export function redactLab(text){return String(text).replace(/((?:client[_-]?secret|access[_-]?token|refresh[_-]?token|api[_-]?key|token)\s*["']?\s*[:=]\s*["']?)[^\s,"'}]+/gi,'$1[redacted]').replace(/\b(Bearer|Basic)\s+[A-Za-z0-9._~+/=-]+/gi,'$1 [redacted]');}
export function labArguments(input,output){
  if(!modes.has(input.mode))throw Error('Select a supported WCL Lab operation');
  const args=[];
  if(input.mode==='validate')args.push('--validate-install');
  if(input.mode==='selfTest')args.push('--self-test');
  if(input.mode==='fixture')args.push('--fixture-export');
  if(input.mode==='reanalyze'){
    if(typeof input.input!=='string'||!path.isAbsolute(input.input)||input.input.includes('\0'))throw Error('Select an absolute export folder or ZIP path');
    args.push('--reanalyze',input.input);
  }
  if(input.mode==='live'){
    const links=String(input.links||'').trim().split(/\s+/).filter(Boolean);
    if(!links.length||links.length>30)throw Error('Enter 1–30 Warcraft Logs report links');
    for(const link of links){let u;try{u=new URL(link);}catch{throw Error('Enter complete Warcraft Logs HTTPS report URLs');}if(u.protocol!=='https:'||!/(^|\.)warcraftlogs\.com$/i.test(u.hostname)||!/^\/reports\/[a-z0-9]{16}\/?$/i.test(u.pathname)||u.username||u.password||u.port)throw Error('Use official Warcraft Logs HTTPS report links');if([...u.searchParams.keys()].some(k=>/token|secret|key/i.test(k)))throw Error('Do not include credentials in report URLs');}
    args.push('--live-export-url',[...new Set(links)].join('\n'));
  }
  if(input.mode==='top'){
    const targets=String(input.targets||'').trim();
    if(!/^(?:e?\d+)(?:[\s,]+e?\d+)*$/i.test(targets)||targets.length>500)throw Error('Enter zone IDs or encounter IDs prefixed with e, for example 47,e3159');
    args.push('--top-logs',targets,'--top',integer(input.top??10,1,100,'Top count'),'--rank-from',integer(input.rankFrom??1,1,10000,'Starting rank'),'--max-per-run',integer(input.maxPerRun??5,1,30,'Maximum logs per run'));
  }
  if(input.mode==='survey'){
    const targets=String(input.survey||'').trim();
    if(!/^[a-z ]+:[a-z ]+(?::(?:dps|hps))?(?:,[a-z ]+:[a-z ]+(?::(?:dps|hps))?)*$/i.test(targets)||targets.length>1000)throw Error('Use Class:Spec[:dps|hps], for example Paladin:Holy:hps');
    const encounters=String(input.encounters||'').trim();if(!/^\d+(?:\s*,\s*\d+)*$/.test(encounters)||encounters.length>500)throw Error('Enter comma-separated numeric encounter IDs');
    args.push('--spec-survey',targets,'--encounters',encounters);
  }
  if(input.spec){if(typeof input.spec!=='string'||!/^[a-z][a-z0-9_-]{0,48}$/i.test(input.spec))throw Error('Invalid specialization key');args.push('--spec',input.spec);}
  return [...args,'--output',output];
}

// A fixed PowerShell command handles only DPAPI. Client secrets arrive on stdin,
// never in process arguments, environment variables, stdout or the run history.
export async function protectLabSecret(secret){
  if(process.platform!=='win32')throw Error('The WCL Lab engine requires Windows');
  const script="$ErrorActionPreference='Stop'; Add-Type -AssemblyName System.Security; [Console]::InputEncoding=[Text.Encoding]::UTF8; $s=[Console]::In.ReadToEnd(); $b=[Text.Encoding]::UTF8.GetBytes($s); $p=[Security.Cryptography.ProtectedData]::Protect($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser); [Console]::Out.Write([Convert]::ToBase64String($p))";
  const executable=path.join(process.env.SystemRoot||'C:\\Windows','System32','WindowsPowerShell','v1.0','powershell.exe');
  return new Promise((resolve,reject)=>{const child=spawn(executable,['-NoProfile','-NonInteractive','-EncodedCommand',Buffer.from(script,'utf16le').toString('base64')],{windowsHide:true,stdio:['pipe','pipe','pipe'],shell:false});let out='';const timer=setTimeout(()=>{child.kill();reject(Error('Windows DPAPI timed out'));},30000);child.stdout.on('data',b=>{out+=b.toString();if(out.length>50000)child.kill();});child.stderr.resume();child.stdin.on('error',()=>{});child.on('error',()=>{clearTimeout(timer);reject(Error('Windows DPAPI could not start'));});child.on('close',code=>{clearTimeout(timer);if(code!==0||!/^[A-Za-z0-9+/=]+$/.test(out))reject(Error('Windows DPAPI could not encrypt the Lab client secret'));else resolve(out);});child.stdin.end(secret,'utf8');});
}

export class WclLab {
  constructor(dataDir,resources,{platform=process.platform,spawnProcess=spawn,protect=protectLabSecret,credentialFile}={}){
    this.platform=platform;this.spawn=spawnProcess;this.protect=protect;this.resources=path.join(resources,'wcl-lab');this.dir=path.join(dataDir,'wcl-lab');this.runsDir=path.join(this.dir,'runs');this.engineDir=path.join(this.dir,'engine');this.jobs=new Map();this.indexing=false;
    this.credentialFile=credentialFile||(platform==='win32'&&process.env.LOCALAPPDATA?path.join(process.env.LOCALAPPDATA,'bgmt x warcraftlogs lab','credentials.dat'):null);this.linkFile=path.join(this.dir,'credential-link.json');
  }
  async init(){
    this.manifest=JSON.parse(await fs.readFile(path.join(this.resources,'manifest.json'),'utf8'));
    await fs.mkdir(this.runsDir,{recursive:true});
    for(const name of (await fs.readdir(this.runsDir)).slice(-200)){
      if(!/^[a-f\d-]{36}$/.test(name))continue;
      try{const run=JSON.parse(await fs.readFile(path.join(this.runsDir,name,'run.json'),'utf8'));run.id=name;run.output=path.join(this.runsDir,name,'output');if(run.status==='running'||run.status==='finishing'){run.status='interrupted';run.finishedAt=new Date().toISOString();run.message='The application closed before this operation finished. Partial files were kept.';try{run.files=(await this.scanFiles(run)).files;}catch{run.files=[];}await writeAtomic(path.join(this.runsDir,name,'run.json'),JSON.stringify(run));}this.jobs.set(name,run);}catch{}
    }
    return this;
  }
  active(){return [...this.jobs.values()].find(r=>r.status==='running'||r.status==='finishing');}
  async status(id){const jobs=[...this.jobs.values()].sort((a,b)=>b.startedAt.localeCompare(a.startedAt));const selected=id||jobs[0]?.id;return {available:this.platform==='win32',engine:{name:this.manifest.name,version:this.manifest.version,sha256:this.manifest.sha256},credentials:await this.credentialStatus(),runs:jobs.map(run=>{if(run.id===selected)return publicRun(run);const {files,summary,log,...metadata}=publicRun({...run,files:[],summary:null,log:''});return metadata;})};}
  async credentialStatus(){let saved=false,linked=false;try{saved=(await fs.stat(this.credentialFile)).isFile();}catch{}try{const link=JSON.parse(await fs.readFile(this.linkFile,'utf8'));linked=saved&&sha(await fs.readFile(this.credentialFile))===link.hash;}catch{}return {saved,linked,path:this.credentialFile};}
  async connect(credentials){
    if(this.platform!=='win32'||!this.credentialFile)throw Error('WCL Lab credentials require Windows');if(this.active()||this.starting)throw Error('Stop the active Lab operation before changing its client');
    if(credentials?.mode!=='oauth'||!credentials.clientId||!credentials.clientSecret)throw Error('Save a V2 Client ID and Client Secret in Settings first. A V1 key or Access Token cannot configure this engine.');
    const protectedSecret=await this.protect(credentials.clientSecret);const data=JSON.stringify({ClientId:credentials.clientId,ProtectedSecret:protectedSecret,CreatedUtc:new Date().toISOString()},null,2);
    let previous=null;try{const stat=await fs.stat(this.credentialFile);if(stat.size>100000)throw Error('Existing engine credential file exceeds its limit');previous=await fs.readFile(this.credentialFile);}catch(e){if(e.code!=='ENOENT')throw e;}
    try{const old=JSON.parse(await fs.readFile(this.linkFile,'utf8'));if(previous&&sha(previous)===old.hash)previous=old.previous===null?null:Buffer.from(old.previous,'base64');}catch{}
    // Save recovery metadata first, then the new encrypted record. A previous
    // independent engine profile is restored on disconnect, not discarded.
    await writeAtomic(this.linkFile,JSON.stringify({hash:sha(data),previous:previous?.toString('base64')??null}));
    await writeAtomic(this.credentialFile,data);return this.credentialStatus();
  }
  async disconnect(){
    if(this.active()||this.starting)throw Error('Stop the active Lab operation before disconnecting its client');
    let link;try{link=JSON.parse(await fs.readFile(this.linkFile,'utf8'));}catch(e){if(e.code==='ENOENT')return this.credentialStatus();throw e;}
    let current;try{current=await fs.readFile(this.credentialFile);}catch(e){if(e.code!=='ENOENT')throw e;}
    if(current&&sha(current)!==link.hash)throw Error('The Lab credential profile changed outside this application. It was preserved; reconnect or restore it in the original parser.');
    if(link.previous!==null)await writeAtomic(this.credentialFile,Buffer.from(link.previous,'base64'));else await fs.rm(this.credentialFile,{force:true});
    await fs.rm(this.linkFile,{force:true});return this.credentialStatus();
  }
  async executable(){
    if(this.platform!=='win32')throw Error('The bundled WCL Lab engine runs in the Windows desktop app. Saved result inspection is available here.');
    const file=path.join(this.engineDir,this.manifest.executable);await fs.mkdir(this.engineDir,{recursive:true});
    try{const st=await fs.lstat(file);if(st.isSymbolicLink())throw Error('Engine path is a symbolic link');if(st.isFile()&&st.size===this.manifest.size&&sha(await fs.readFile(file))===this.manifest.sha256)return file;}catch(e){if(e.code!=='ENOENT'&&e.message==='Engine path is a symbolic link')throw e;}
    const packed=await fs.readFile(path.join(this.resources,this.manifest.file));if(packed.length!==this.manifest.compressedSize||sha(packed)!==this.manifest.compressedSha256)throw Error('Bundled WCL engine checksum mismatch');
    const bytes=gunzipSync(packed,{maxOutputLength:this.manifest.size});if(bytes.length!==this.manifest.size||sha(bytes)!==this.manifest.sha256)throw Error('Unpacked WCL engine checksum mismatch');
    await writeAtomic(file,bytes);return file;
  }
  async persist(run){await writeAtomic(path.join(this.runsDir,run.id,'run.json'),JSON.stringify(publicRun(run)));}
  async start(input){
    if(this.active()||this.starting)throw Error('A WCL Lab operation is already running');this.starting=true;
    try{
      const id=uid(),output=path.join(this.runsDir,id,'output');const args=labArguments(input,output);
      if(liveModes.has(input.mode)&&!(await this.credentialStatus()).saved)throw Error('Connect a V2 OAuth client for the Lab engine first');
      if(input.mode==='reanalyze'){const stat=await fs.stat(input.input);if(!stat.isDirectory()&&!(stat.isFile()&&/\.zip$/i.test(input.input)))throw Error('Select an existing export folder or ZIP');}
      const executable=await this.executable();await fs.mkdir(output,{recursive:true});
      const run={id,mode:input.mode,spec:String(input.spec||'shadow'),status:'running',startedAt:new Date().toISOString(),finishedAt:null,output,log:'',exitCode:null,files:[],summary:null,message:'Starting bundled WCL Lab engine…'};
      await this.persist(run);this.jobs.set(id,run);
      let child;try{child=this.spawn(executable,args,{cwd:this.engineDir,windowsHide:true,shell:false,stdio:['ignore','pipe','pipe']});}catch{run.status='failed';run.message='The WCL Lab process could not start';run.finishedAt=new Date().toISOString();await this.persist(run);throw Error(run.message);}run.child=child;run.done=new Promise(resolve=>{run.resolve=resolve;});
      // resolve is an internal callback, excluded from persisted/public state.
      const resolve=run.resolve;delete run.resolve;
      const stdout=new StringDecoder('utf8'),stderr=new StringDecoder('utf8');
      const append=text=>{run.log=redactLab(run.log+text).slice(-32000);};
      child.stdout.on('data',b=>append(stdout.write(b)));child.stderr.on('data',b=>append(stderr.write(b)));
      child.on('error',()=>{run.spawnError=true;append('\nThe WCL Lab process could not start.');});
      run.timer=setTimeout(()=>{run.timedOut=true;child.kill();},60*60*1000);run.timer.unref?.();
      child.once('close',(code,signal)=>{append(stdout.end()+stderr.end());void this.finish(run,code,signal).finally(resolve);});
      return publicRun(run);
    }finally{this.starting=false;}
  }
  async finish(run,code,signal){
    clearTimeout(run.timer);run.exitCode=code;run.signal=signal;run.status='finishing';
    try{
      const scan=await this.scanFiles(run);run.files=scan.files;run.filesTruncated=scan.truncated;
      const report=reports[run.mode];const found=run.files.find(f=>f.path===report);
      if(found&&found.size<=2e6){try{run.summary=JSON.parse(redactLab(await fs.readFile(await inside(run.output,found.path),'utf8')));}catch{}}
      const failed=Number(run.summary?.failed??run.summary?.Failed??run.summary?.CompletedWithErrors??run.summary?.completedWithErrors??run.summary?.Export?.Failed??0);
      const reportMissing=Boolean(report&&!run.summary);
      run.status=run.cancelled?'cancelled':run.timedOut?'timedOut':code===0&&!run.spawnError&&failed===0&&!reportMissing?'completed':'failed';
      run.message=run.cancelled?'Operation cancelled; partial files were kept.':run.timedOut?'Operation exceeded one hour; partial files were kept.':run.status==='completed'?'Operation completed. Inspect the report and data-quality warnings.':'Engine reported an error. Inspect its log and result reports; partial outputs are not treated as complete.';
    }catch(e){run.status='failed';run.message=redactLab(e.message);}
    run.finishedAt=new Date().toISOString();delete run.child;delete run.timer;await this.persist(run);
  }
  run(id){if(typeof id!=='string'||!/^[a-f\d-]{36}$/.test(id)||!this.jobs.has(id))throw Error('Select a WCL Lab run');return this.jobs.get(id);}
  async cancel(id){const run=this.run(id);if(run.status==='running'){run.cancelled=true;run.child?.kill();}return publicRun(run);}
  async close(){const run=this.active();if(run?.child){await this.cancel(run.id);await run.done;}}
  async scanFiles(run){
    const files=[];let truncated=false,visited=0;
    const visit=async(dir,prefix='',depth=0)=>{if(depth>12){truncated=true;return;}for(const entry of await fs.readdir(dir,{withFileTypes:true})){if(++visited>12000||files.length>=5000){truncated=true;return;}if(entry.isSymbolicLink())continue;const relative=prefix+entry.name;if(entry.isDirectory())await visit(path.join(dir,entry.name),relative+'/',depth+1);else if(entry.isFile())files.push({path:relative,size:(await fs.stat(path.join(dir,entry.name))).size});}};
    await visit(run.output);return {files:files.sort((a,b)=>a.path.localeCompare(b.path)),truncated};
  }
  async file(id,relative){const run=this.run(id);if(!run.files.some(f=>f.path===relative))throw Error('Select a file from this run');return inside(run.output,relative);}
  async preview(id,relative){
    if(!/\.(json|jsonl|csv|txt|md)$/i.test(relative))throw Error('Only JSON, JSONL, CSV and text results can be previewed');
    const file=await this.file(id,relative);const handle=await fs.open(file,'r');let size,buffer;
    try{size=(await handle.stat()).size;buffer=Buffer.alloc(Math.min(size,160000));const {bytesRead}=await handle.read(buffer,0,buffer.length,0);buffer=buffer.subarray(0,bytesRead);}finally{await handle.close();}
    let text=redactLab(buffer.toString('utf8').replace(/^\uFEFF/,''));if(/\.json$/i.test(relative)&&size<=160000){try{text=JSON.stringify(JSON.parse(text),null,2);}catch{}}
    return {path:relative,size,truncated:size>buffer.length,text};
  }
  async timeline(id,relative){
    const run=this.run(id);if(run.status!=='completed')throw Error('Import casts only from a completed run');
    if(path.posix.basename(relative)!=='fight.json')throw Error('Select fight.json from the exported log');
    const directory=path.posix.dirname(relative),prefix=directory==='.'?'':directory+'/';
    const read=async name=>{const file=await this.file(id,prefix+name);if((await fs.stat(file)).size>8e6)throw Error('Log metadata exceeds 8 MB');return JSON.parse((await fs.readFile(file,'utf8')).replace(/^\uFEFF/,''));};
    const get=(obj,...names)=>{if(!obj||typeof obj!=='object')return undefined;for(const name of names){const key=Object.keys(obj).find(k=>k.toLowerCase()===name.toLowerCase());if(key!==undefined)return obj[key];}};
    const fight=await read('fight.json'),metadata=await read('metadata.json');const start=Number(get(fight,'startTime','start_time')),end=Number(get(fight,'endTime','end_time'));
    if(!Number.isFinite(start)||!Number.isFinite(end)||end<=start)throw Error('Export has no valid fight start/end timestamps in milliseconds');
    const asArray=value=>Array.isArray(value)?value:[];const actors=new Map(asArray(await read('actors.json')).map(a=>[Number(get(a,'id')),a]));const abilities=new Map(asArray(await read('abilities.json')).map(a=>[Number(get(a,'gameID','id')),get(a,'name')]));
    const code=String(get(metadata,'reportCode','code')||''),fightId=Number(get(fight,'id')??get(metadata,'fightId'));
    if(!/^[a-z0-9]{16}$/i.test(code)||!Number.isInteger(fightId)||fightId<1)throw Error('Export lacks a real WCL report/fight identity; fixtures cannot become encounter samples');
    const source=get(metadata,'player');const sourceId=get(metadata,'sourceId')??get(source,'id');const candidateNames=['events_hostile_casts.jsonl','events_selected_player_casts.jsonl'];const candidates=candidateNames.filter(name=>run.files.some(f=>f.path===prefix+name));
    if(!candidates.length)throw Error('This export contains no recorded cast JSONL files');
    const events=[],seen=new Set();let skipped=0,total=0;
    for(const name of candidates){const file=await this.file(id,prefix+name);if((await fs.stat(file)).size>512e6)throw Error('Cast file exceeds 512 MB');const stream=createReadStream(file,{encoding:'utf8'}),lines=readline.createInterface({input:stream,crlfDelay:Infinity});try{for await(const line of lines){if(!line.trim())continue;if(++total>500000||line.length>2e6)throw Error('Cast event input exceeds the import limit');let event;try{event=JSON.parse(line.replace(/^\uFEFF/,''));}catch{throw Error('Malformed cast JSONL record; no partial timeline was imported');}const type=get(event,'type');if(!['cast','begincast'].includes(type))continue;const timestamp=Number(get(event,'timestamp'));const spellId=Number(get(event,'abilityGameID')??get(get(event,'ability'),'guid','gameID'));if(!Number.isFinite(timestamp)||timestamp<start||timestamp>end||!Number.isInteger(spellId)||spellId<=0){skipped++;continue;}const actorId=Number(get(event,'sourceID'));const targetId=get(event,'targetID');const key=JSON.stringify([type,timestamp,spellId,actorId,targetId]);if(seen.has(key))continue;seen.add(key);const actor=actors.get(actorId);events.push({id:String(events.length),time:(timestamp-start)/1000,type,spellId,name:String(abilities.get(spellId)||get(get(event,'ability'),'name')||`Spell ${spellId}`),sourceId:actorId,sourceName:String(get(actor,'name')||''),sourceType:String(get(actor,'type')||''),targetId,provenance:'WCL Lab recorded cast; original JSONL timestamp'});if(events.length>250000)throw Error('Timeline exceeds 250,000 cast events');}}finally{lines.close();stream.destroy();}}
    if(!events.length)throw Error('No in-fight cast events with valid timestamps were found');
    return {format:'pztk-timeline-v1',id:sha(`${code}:${fightId}:lab:${sourceId??''}`).slice(0,16),name:String(get(fight,'name')||'WCL Lab fight'),encounterId:Number(get(fight,'encounterID','boss')||0),difficulty:Number(get(fight,'difficulty')||0),duration:(end-start)/1000,build:null,source:{type:'warcraftlogs',report:code,fightId,url:`https://www.warcraftlogs.com/reports/${code}?fight=${fightId}`,importedAt:new Date().toISOString(),engine:this.manifest.version,run:id,sourceId,scope:'Hostile and selected-player casts only; not a complete raid cast stream',skippedEvents:skipped},events:events.sort((a,b)=>a.time-b.time)};
  }
}
