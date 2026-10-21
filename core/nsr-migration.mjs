import {createHash} from 'node:crypto';
import {SPEC_NAMES} from './wow-names.mjs';
const object=v=>v&&typeof v==='object'&&!Array.isArray(v);
const count=t=>Object.keys(t||{}).length;
const nested=t=>Object.values(t||{}).reduce((n,items)=>n+count(items),0);
export function parseReminderDelays(value){
 if(value==null||value==='')return [0];
 const tokens=typeof value==='number'?[String(value)]:typeof value==='string'?value.trim().split(/[,\s]+/):[];
 if(!tokens.length)throw Error('Unsupported delay');
 return tokens.map(token=>{let n;if(/^\d+(?:\.\d+)?$/.test(token))n=Number(token);else{const m=token.match(/^(\d+):(\d+(?:\.\d+)?)$/);if(m)n=Number(m[1])*60+Number(m[2]);}if(!Number.isFinite(n)||n<0||n>7200)throw Error('Unsupported delay');return n;});
}
export function parseReminderCounter(value){
 if(value==null||value==='')return [];
 if(typeof value==='number')value=String(value);
 if(typeof value!=='string'||value.length>200)throw Error('Unsupported counter');
 const groups=[];
 for(const term of value.split(',')){
  const m=term.trim().match(/^(\+)?(>=|<=|>|<|!|=)?(-?\d+(?:\.\d+)?)$/);if(!m)throw Error('Unsupported counter');
  const pred={op:m[2]||'=',value:Number(m[3])};if(m[1]&&groups.length)groups.at(-1).push(pred);else groups.push([pred]);
 }
 return groups;
}
const supportedSettings=new Set(['enabled','voiceOn','voiceVol','soundOn','soundKey','fallbackOn','voiceNone','leadTime','lingerSec','showIcon','showText','showBar','iconSize','textSize','textSide','pos','bossSource']);
export function migrateNsrData(source){
 const data={},issues=[],counts={defensiveSets:nested(source.presets),specializations:count(source.presets),abilityBindings:Object.values(source.abilityBindings||{}).reduce((n,enc)=>n+nested(enc),0),exboss:0,auraSound:0,customSource:nested(source.customReminders),customConverted:0,customSkipped:0,scheduled:nested(source.raidReminders),callouts:count(source.callouts)};
 for(const field of ['presets','activePreset','abilityBindings','integrationRules','raidReminders','bindingsBySpec','callouts','voiceNone','leadTime','settings','scopePresets','scopeActivePreset','manualCatalog','contentDifficulties'])if(source[field]!=null)data[field]=structuredClone(source[field]);
 function issue(section,key,reason,specId){issues.push({section,key:String(key),reason,...(specId?{specId:Number(specId),specName:SPEC_NAMES[specId]||String(specId)}:{})});}
 for(const key of Object.keys(source))if(!Object.hasOwn(data,key)&&!['customReminders','pztkMigrations','pztkReminders','desktopReminders'].includes(key)&&source[key]&&Object.keys(Object(source[key])).length)issue('source',key,'Section is retained in the source working copy; runtime migration is unavailable.');
 for(const [spec,rules]of Object.entries(data.integrationRules||{}))for(const [key,r]of Object.entries(rules)){
  const type=r.trigger?.type;
  if(type==='exboss')counts.exboss++;else if(type==='auraSound')counts.auraSound++;
  else{delete rules[key];issue('integrationRules',key,'Unsupported trigger '+String(type),spec);}
 }
 for(const [enc,entries]of Object.entries(data.raidReminders||{}))for(const [key,e]of Object.entries(entries))if(!['pull','stage','bwtimer','bwmsg'].includes(e.trigger?.type)||!['icon','text','bar','circle','chat','raidframeGlow','nameplateGlow'].includes(e.display?.type)){delete entries[key];issue('raidReminders',enc+'/'+key,'Unsupported trigger or display');}
 data.raidReminders||={};
 const convertedPaths=[];
 for(const [enc,entries]of Object.entries(source.customReminders||{}))for(const [key,r]of Object.entries(entries)){
  try{
   if(!object(r)||!['pull','stage','bwtimer','bwmsg'].includes(r.trigger?.type))throw Error('Unsupported custom trigger');
   if(r.defensive&&(!r.preset||!SPEC_NAMES[r.specID]))throw Error('Defensive reminder needs a named preset and specialization');
   if(r.specID!=null&&!SPEC_NAMES[r.specID])throw Error('Unknown specialization');
   if(r.trigger.type==='stage'&&(!Number.isFinite(Number(r.trigger.stage))||Number(r.trigger.stage)<=0))throw Error('Invalid phase');
   if(['bwtimer','bwmsg'].includes(r.trigger.type)&&(!Number.isInteger(r.trigger.spellID)||r.trigger.spellID<1))throw Error('Invalid mechanic spell ID');
   const delays=parseReminderDelays(r.trigger.delay),counterGroups=parseReminderCounter(r.trigger.counter),dur=Number(r.dur??3);
   if(!Number.isFinite(dur)||dur<0.1||dur>120)throw Error('Invalid display duration');
   const unknown=Object.keys(r.trigger).filter(k=>!['type','delay','counter','spellID','stage','timeleft','leadTime'].includes(k));if(unknown.length)throw Error('Unsupported trigger fields: '+unknown.join(', '));
   const staged=[];
   for(const [i,delay]of delays.entries()){
    const id='nsr_custom_'+createHash('sha256').update(JSON.stringify([enc,key,i])).digest('hex').slice(0,20);
    if(Object.hasOwn(data.raidReminders[enc]||{},id))throw Error('Reminder key collision');
    const entry={name:r.name||key,enabled:r.enabled!==false,...(typeof r.healerReminder==='boolean'?{healerReminder:r.healerReminder}:{}),trigger:{type:r.trigger.type,delay,leadTime:Number(r.trigger.timeleft??r.trigger.leadTime??0),...(r.trigger.spellID?{spellID:r.trigger.spellID}:{}),...(r.trigger.stage?{stage:Number(r.trigger.stage)}:{}),...(counterGroups.length?{counterGroups}:{})},target:r.specID?{specs:{[r.specID]:true}}:{all:true},display:{type:r.defensive?'icon':'text',text:r.defensive?'':String(r.msg||r.name||''),dur,...(typeof r.sound==='string'?{sound:r.sound}:{}),...(typeof r.tts==='boolean'?{tts:r.tts}:{})},...(r.defensive?{defensive:{preset:r.preset,specID:r.specID}}:{}),pztkOrigin:{section:'customReminders',encounterId:Number(enc),key}};
    staged.push({id,entry});
   }
   data.raidReminders[enc]||={};
   for(const {id,entry}of staged){data.raidReminders[enc][id]=entry;convertedPaths.push(['raidReminders',String(enc)]);if(r.specID)convertedPaths.push(['raidReminders',String(enc),id,'target','specs',String(r.specID)]);}
   counts.customConverted++;
  }catch(e){counts.customSkipped++;issue('customReminders',enc+'/'+key,e.message,r?.specID);}
 }
 for(const [spec,encs]of Object.entries(data.abilityBindings||{}))for(const [enc,entries]of Object.entries(encs))for(const [key,b]of Object.entries(entries))if(b.preset&&!data.presets?.[spec]?.[b.preset])issue('abilityBindings',enc+'/'+key,'Preset '+b.preset+' is missing in this specialization.',spec);
 for(const [spec,rules]of Object.entries(data.integrationRules||{}))for(const [key,r]of Object.entries(rules))if(r.preset&&!data.presets?.[spec]?.[r.preset])issue('integrationRules',key,r.trigger?.type==='exboss'&&!r.display?.text?'Preset '+r.preset+' is missing; the source ExBoss rule falls back to the active set.':'Preset '+r.preset+' is missing.',spec);
 for(const [key,value]of Object.entries(data.settings||{}))if(!supportedSettings.has(key)&&value!==false&&value!=null&&value!==0&&value!=='')issue('settings',key,'Value is retained, but this runtime feature is unavailable.');
 if(data.settings?.bossSource&&!['bigwigs','dbm'].includes(data.settings.bossSource))issue('settings','bossSource','Only BigWigs and DBM event sources are currently supported.');
 if(data.settings?.textSide&&data.settings.textSide!=='RIGHT')issue('settings','textSide','The value is retained; reminder text currently uses the right-side layout.');
 const groups=[];for(const entry of issues){let g=groups.find(g=>g.section===entry.section&&g.reason===entry.reason);if(!g){g={section:entry.section,reason:entry.reason,count:0};groups.push(g);}g.count++;}
 const warnings=groups.map(g=>g.section+': '+g.count+' · '+g.reason);
 return {data,convertedPaths,warnings,report:{counts,issues,groups,complete:issues.length===0}};
}
