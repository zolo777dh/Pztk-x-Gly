import {deflateRawSync,inflateRawSync} from 'node:zlib';
import {encodePrint,decodePrint,validatePackBounds} from './packs.mjs';
import {migrateNsrData} from './nsr-migration.mjs';
import {encodeCbor,decodeCbor} from './cbor.mjs';
// Native string: one !NDP1: carries every profile of a client, Mythic+ and raids:
// '!NDP1:' + Base64(raw Deflate(CBOR({v:1,addon,client,minimumAddon,active,profiles:[…]}))).
export const NDP_PREFIX='!NDP1:';
const newer=(a,b)=>{const x=String(a).split('.').map(Number),y=String(b).split('.').map(Number);for(let i=0;i<Math.max(x.length,y.length);i++)if((x[i]||0)!==(y[i]||0))return (x[i]||0)>(y[i]||0);return false;};
export const REMINDER_CLIENTS={retail:'12.1.5.70448',forever:'1.60.1.70425'};
const object=v=>v&&typeof v==='object'&&!Array.isArray(v);
const table=(v,label)=>{if(!object(v)&&!Array.isArray(v))throw Error('Invalid '+label+' table');return v;};
const number=(v,min,max)=>typeof v==='number'&&Number.isFinite(v)&&v>=min&&v<=max;
const flags=v=>v==null||object(v)&&Object.values(v).every(n=>typeof n==='boolean');
export const TRIGGER_TYPES=['pull','prepull','stage','bwtimer','bwmsg'];
const LOOK_KEYS=['textColor','barColor','ticks','sticky','hideTimer','countdown'];
const anyReminder=(data,test)=>Object.values(object(data?.raidReminders)?data.raidReminders:{}).some(entries=>object(entries)&&Object.values(entries).some(test));
// Hide on use and spoken countdowns need addon 0.6.7; NSRT-style colours, ticks, sticky time and countdowns need 0.6.5; pre-pull countdown triggers and
// multi-frame glows need 0.3.3; other profiles keep their older minimum.
export const minimumAddonFor=data=>anyReminder(data,e=>e?.display?.hideOnUse!=null||e?.display?.voiceCountdown!=null)?'0.6.7':anyReminder(data,e=>LOOK_KEYS.some(k=>e?.display?.[k]!=null))?'0.6.5':anyReminder(data,e=>e?.trigger?.type==='prepull'||e?.display?.glowTargets!=null||e?.display?.glowColor!=null)?'0.3.3':data?.scopePresets?'0.3.0':'0.2.0';
// Lua tables decode as arrays or as {1:…,2:…} objects depending on the codec path.
const sequence=v=>Array.isArray(v)?v:object(v)&&Object.keys(v).every((k,i)=>k===String(i+1))?Object.values(v):null;
const glowTargetsValid=v=>{const list=sequence(v);return !!list&&list.length>0&&list.length<=40&&list.every(n=>typeof n==='string'&&n.length>0&&n.length<=100);};
const glowColorValid=v=>{const list=sequence(v);return !!list&&list.length===4&&list.every(n=>number(n,0,1));};
function normalizeOptionalIds(data){
 if(!object(data)||!object(data.raidReminders))return;
 for(const entries of Object.values(data.raidReminders))if(object(entries))for(const entry of Object.values(entries))if(object(entry)){
  if(object(entry.display)&&entry.display.spellID==='')delete entry.display.spellID;
  if(object(entry.trigger)&&entry.trigger.spellID===''&&!['bwtimer','bwmsg'].includes(entry.trigger.type))delete entry.trigger.spellID;
 }
}
function binding(b){
 if(!object(b)||(b.enabled!=null&&typeof b.enabled!=='boolean')||(b.preset!=null&&typeof b.preset!=='string')||(b.leadTime!=null&&!number(b.leadTime,-120,120))||(b.sound!=null&&typeof b.sound!=='string'))throw Error('Invalid defensive binding');
 if(b.display!=null&&(!object(b.display)||(b.display.text!=null&&typeof b.display.text!=='string')||(b.display.dur!=null&&!number(b.display.dur,0.1,120))))throw Error('Invalid defensive display');
 if(b.display)for(const key of ['sound','ttsText'])if(b.display[key]!=null&&typeof b.display[key]!=='string')throw Error('Invalid defensive '+key);
 if(b.display?.tts!=null&&typeof b.display.tts!=='boolean')throw Error('Invalid defensive TTS flag');
}
function settings(s){
 if(s==null)return;if(!object(s))throw Error('Invalid settings');
 for(const key of ['enabled','voiceOn','soundOn','fallbackOn','showIcon','showText','showBar'])if(s[key]!=null&&typeof s[key]!=='boolean')throw Error('Invalid setting '+key);
 for(const [key,min,max]of [['voiceVol',0,100],['iconSize',8,256],['textSize',6,80],['leadTime',0,120],['lingerSec',0.1,120]])if(s[key]!=null&&!number(s[key],min,max))throw Error('Invalid setting '+key);
 for(const key of ['soundKey','voiceNone','textSide','bossSource'])if(s[key]!=null&&typeof s[key]!=='string')throw Error('Invalid setting '+key);
 if(s.pos!=null){if(!object(s.pos))throw Error('Invalid display position');for(const key of ['x','y'])if(s.pos[key]!=null&&!number(s.pos[key],-10000,10000))throw Error('Invalid display position');for(const key of ['point','relPoint'])if(s.pos[key]!=null&&!['CENTER','TOP','BOTTOM','LEFT','RIGHT','TOPLEFT','TOPRIGHT','BOTTOMLEFT','BOTTOMRIGHT'].includes(s.pos[key]))throw Error('Invalid display anchor');}
}
function validateRuntime(data){
 if(!object(data))throw Error('Invalid reminder profile data');
 settings(data.settings);
 const scope=v=>v==null||['mythic','raid'].includes(v);
 if(data.contentDifficulties!=null){if(!object(data.contentDifficulties))throw Error('Invalid content difficulties');for(const [key,value]of Object.entries(data.contentDifficulties))if(!scope(key)||!flags(value))throw Error('Invalid content difficulties');}
 if(data.scopePresets!=null){if(!object(data.scopePresets))throw Error('Invalid scoped presets');for(const [key,presets]of Object.entries(data.scopePresets)){if(!scope(key))throw Error('Invalid content scope');validateRuntime({presets});}}
 if(data.scopeActivePreset!=null){if(!object(data.scopeActivePreset))throw Error('Invalid scoped active sets');for(const [key,activePreset]of Object.entries(data.scopeActivePreset)){if(!scope(key))throw Error('Invalid content scope');validateRuntime({activePreset});}}
 if(data.manualCatalog!=null){if(!object(data.manualCatalog))throw Error('Invalid manual catalog');for(const [key,groups]of Object.entries(data.manualCatalog)){if(!scope(key))throw Error('Invalid catalog scope');for(const g of Object.values(table(groups,'catalog groups'))){if(!object(g)||typeof g.name!=='string'||!['string','number'].includes(typeof g.id)||(g.mapID!=null&&!number(g.mapID,1,1e8)))throw Error('Invalid catalog group');for(const n of [...Object.values(g.npcs||{}),...Object.values(g.bosses||{})]){if(!object(n)||!number(n.id,1,1e8)||typeof n.name!=='string')throw Error('Invalid catalog NPC');for(const a of Object.values(table(n.abilities,'catalog abilities')))if(!object(a)||!number(a.id,1,1e8)||(a.name!=null&&typeof a.name!=='string'))throw Error('Invalid catalog ability');}}}}

 for(const k of ['presets','activePreset','abilityBindings','integrationRules','raidReminders','callouts','settings'])if(data[k]!=null)table(data[k],k);
 for(const value of Object.values(data.callouts||{}))if(typeof value!=='string')throw Error('Invalid callout text');
 if(data.voiceNone!=null&&typeof data.voiceNone!=='string')throw Error('Invalid fallback text');
 if(data.leadTime!=null&&!number(data.leadTime,0,120))throw Error('Invalid default lead time');
 for(const sets of Object.values(data.presets||{}))for(const p of Object.values(table(sets,'specialization presets'))){if(!object(p)||!flags(p.together)||!flags(p.disabled))throw Error('Invalid defensive preset');const list=table(p.list,'spell list'),keys=Object.keys(list),offset=Array.isArray(list)?0:1;if(keys.length>200||keys.some((k,i)=>Number(k)!==i+offset)||Object.values(list).some(n=>!number(n,1,1e8)||!Number.isInteger(n)))throw Error('Invalid defensive spell list');}
 for(const value of Object.values(data.activePreset||{}))if(typeof value!=='string')throw Error('Invalid active defensive set');
 for(const encounters of Object.values(data.abilityBindings||{}))for(const entries of Object.values(table(encounters,'defensive encounters')))for(const b of Object.values(table(entries,'defensive bindings'))){binding(b);if(!scope(b.content)||!flags(b.difficulties))throw Error('Invalid defensive content filters');}
 for(const rules of Object.values(data.integrationRules||{}))for(const rule of Object.values(table(rules,'integration rules'))){binding(rule);if(!scope(rule.content)||!flags(rule.difficulties))throw Error('Invalid rule scope');const t=rule.trigger;if(!object(t)||!['exboss','auraSound'].includes(t.type)||!number(t.mapID,0,1e8)||!Number.isInteger(t.mapID)||!number(t.spellID,1,1e8)||!Number.isInteger(t.spellID)||(t.timeleft!=null&&!number(t.timeleft,0,120)))throw Error('Invalid integration rule');if(t.type==='auraSound'&&(!['player','party'].includes(t.target)||!['Added','ApplicationsIncreased','Removed'].includes(t.auraEvent)||!object(rule.display)||typeof rule.display.sound!=='string'||!rule.display.sound||rule.display.sound==='none'))throw Error('Invalid aura sound rule');}
 for(const entries of Object.values(data.raidReminders||{}))for(const e of Object.values(table(entries,'encounter reminders'))){
  if(!scope(e?.content))throw Error('Invalid reminder scope');
  if(e?.defensive!=null&&(!object(e.defensive)||!scope(e.defensive.scope)||typeof e.defensive.preset!=='string'||!number(e.defensive.specID,1,1e8)))throw Error('Invalid dynamic defensive set');
  if(e.trigger?.counterGroups!=null)for(const group of Object.values(table(e.trigger.counterGroups,'counter groups')))for(const pred of Object.values(table(group,'counter conditions')))if(!object(pred)||!['=','!','>','<','>=','<='].includes(pred.op)||!number(pred.value,-1e6,1e6))throw Error('Invalid counter condition');
 }
 for(const entries of Object.values(data.raidReminders||{}))for(const e of Object.values(table(entries,'encounter reminders'))){if(!object(e)||!object(e.trigger)||!object(e.display)||!TRIGGER_TYPES.includes(e.trigger.type))throw Error('Unsupported reminder trigger');if(!['icon','text','bar','circle','chat','raidframeGlow','nameplateGlow'].includes(e.display.type)||!flags(e.difficulties))throw Error('Unsupported reminder display or difficulty');if(e.target!=null&&!object(e.target))throw Error('Invalid reminder target');for(const k of ['roles','specs','classes','names','subgroups'])if(!flags(e.target?.[k]))throw Error('Invalid recipient flags');for(const k of ['all','matchAny'])if(e.target?.[k]!=null&&typeof e.target[k]!=='boolean')throw Error('Invalid recipient flag '+k);if(e.enabled!=null&&typeof e.enabled!=='boolean')throw Error('Invalid reminder enabled flag');for(const [key,min,max]of [['delay',0,7200],['leadTime',0,120],['stage',0.01,100]])if(e.trigger[key]!=null&&!number(e.trigger[key],min,max))throw Error('Invalid trigger '+key);if(e.trigger.type==='stage'&&e.trigger.stage==null)throw Error('Choose a phase number');if(e.trigger.type==='prepull'&&!number(e.trigger.delay,0.1,3600))throw Error('Invalid seconds before pull');if(['bwtimer','bwmsg'].includes(e.trigger.type)&&(!number(e.trigger.spellID,1,1e8)||!Number.isInteger(e.trigger.spellID)))throw Error('Invalid timer spell ID');if(e.display.dur!=null&&!number(e.display.dur,0.1,120))throw Error('Invalid display duration');for(const k of ['text','sound','ttsText','glowTarget'])if(e.display[k]!=null&&typeof e.display[k]!=='string')throw Error('Invalid display '+k);if(e.display.tts!=null&&typeof e.display.tts!=='boolean')throw Error('Invalid TTS flag');if(e.display.glowTargets!=null&&!glowTargetsValid(e.display.glowTargets))throw Error('Invalid glow targets');if(e.display.glowColor!=null&&!glowColorValid(e.display.glowColor))throw Error('Invalid glow colour');for(const k of ['textColor','barColor'])if(e.display[k]!=null&&!glowColorValid(e.display[k]))throw Error('Invalid display '+k);if(e.display.ticks!=null){const t=sequence(e.display.ticks);if(!t||t.length>20||!t.every(n=>number(n,0,120)))throw Error('Invalid bar ticks');}if(e.display.sticky!=null&&!number(e.display.sticky,0,60))throw Error('Invalid sticky duration');for(const k of ['hideTimer','countdown','hideOnUse'])if(e.display[k]!=null&&typeof e.display[k]!=='boolean')throw Error('Invalid display '+k);if(e.display.voiceCountdown!=null&&!number(e.display.voiceCountdown,0,10))throw Error('Invalid spoken countdown');if(e.display.spellID!=null&&(!number(e.display.spellID,1,1e8)||!Number.isInteger(e.display.spellID)))throw Error('Invalid display spell ID');}
}
export class ReminderPack{
 constructor(codec){this.codec=codec;}
 validate(p){if(!p||p.format!==1||p.addon!=='PztkReminders'||typeof p.name!=='string'||p.name.length>200||!REMINDER_CLIENTS[p.client])throw Error('Expected a Naowh Defensive Planner profile for Retail or Forever');if(p.licensed)throw Error('Licensed source packs cannot be migrated');validatePackBounds(p);validateRuntime(p.data);return p;}
 // Older PZTK1 strings (one profile, LibSerialize) are still read.
 decodeLegacy(input){if(input.length>130000)throw Error('Expected PZTK1 string under 130 KB');let raw;try{raw=inflateRawSync(decodePrint(input.slice(6)),{maxOutputLength:4e6});}catch{throw Error('Invalid Naowh Defensive Planner compression or size limit exceeded');}const result=this.codec.invoke('decode',raw,{trackKeys:true});normalizeOptionalIds(result.pack?.data);this.validate(result.pack);return result;}
 decodeBundle(text){
  const input=String(text).replace(/\s+/g,'');
  if(input.startsWith('PZTK1:')){const r=this.decodeLegacy(input);return {client:r.pack.client,active:r.pack.name,profiles:[r]};}
  if(!input.startsWith(NDP_PREFIX)||input.length>1e6)throw Error('Expected a '+NDP_PREFIX+' string under 1 MB');
  let raw;try{raw=inflateRawSync(Buffer.from(input.slice(NDP_PREFIX.length),'base64'),{maxOutputLength:8e6});}catch{throw Error('Invalid Naowh Defensive Planner compression or size limit exceeded');}
  const {data,numericKeys}=decodeCbor(raw,{maxBytes:8e6,maxItems:2e6});
  if(!object(data)||data.v!==1||data.addon!=='NaowhDefensivePlanner'||!REMINDER_CLIENTS[data.client])throw Error('Not a Naowh Defensive Planner export');
  const list=sequence(data.profiles);if(!list||!list.length||list.length>50)throw Error('The export holds no profiles');
  const profiles=list.map((pack,i)=>{if(pack?.client!==data.client)throw Error('Profile '+(i+1)+' belongs to another game client');normalizeOptionalIds(pack.data);this.validate(pack);return {pack,numericKeys:numericKeys.filter(p=>p[0]==='profiles'&&p[1]===String(i)).map(p=>p.slice(2))};});
  return {client:data.client,active:typeof data.active==='string'?data.active:null,profiles};
 }
 // The active profile of a bundle (or its first).
 decode(text){const b=this.decodeBundle(text);return b.profiles.find(p=>p.pack.name===b.active)||b.profiles[0];}
 encodeBundle(list,active){
  if(!list.length||list.length>50)throw Error('Export holds 1 to 50 profiles');
  let need='0.2.0';const client=list[0].pack.client;
  for(const {pack}of list){this.validate(pack);if(pack.client!==client)throw Error('All profiles of one export belong to one game client');const m=pack.minimumAddon||minimumAddonFor(pack.data);if(newer(m,need))need=m;}
  const bundle={v:1,addon:'NaowhDefensivePlanner',client,minimumAddon:need,...(active!=null?{active}:{}),profiles:list.map(x=>x.pack)};
  const keys=list.flatMap((x,i)=>(x.numericKeys||[]).map(p=>['profiles',String(i),...p]));
  const text=NDP_PREFIX+deflateRawSync(encodeCbor(bundle,keys,{maxBytes:8e6})).toString('base64');
  if(text.length>1e6)throw Error('Export exceeds 1 MB');this.decodeBundle(text);return text;
 }
 encode(pack,numericKeys=[]){return this.encodeBundle([{pack,numericKeys}],pack.name);}
 fromDraft(draft,client){if(draft.pack.licensed)throw Error('Licensed source packs cannot be migrated');const source=draft.pack.profiles?draft.pack.profiles[draft.profileKey]:draft.pack.data;if(!source)throw Error('Choose one working profile');if(source.bindingsBySpec===false&&Object.keys(source.abilityBindings||{}).length)throw Error('Migrate legacy non-spec NSR bindings in current NSR before importing');const {data,warnings,report,convertedPaths}=migrateNsrData(source);
 normalizeOptionalIds(data);
 const pack={format:1,addon:'PztkReminders',name:draft.pack.name||'Reminder profile',client,build:REMINDER_CLIENTS[client],minimumAddon:minimumAddonFor(data),data,...(draft.pack.pztkLabels?{pztkLabels:structuredClone(draft.pack.pztkLabels)}:{}),...(draft.pack.derivedFrom?{derivedFrom:structuredClone(draft.pack.derivedFrom)}:{})};const prefix=draft.pack.profiles?['profiles',draft.profileKey]:['data'],numericKeys=draft.numericKeys.filter(p=>prefix.every((k,i)=>p[i]===k)&&Object.hasOwn(data,p[prefix.length])).map(p=>['data',...p.slice(prefix.length)]);numericKeys.push(...convertedPaths.map(p=>['data',...p]));return {text:this.encode(pack,numericKeys),warnings,payload:pack,report};
 }
}
