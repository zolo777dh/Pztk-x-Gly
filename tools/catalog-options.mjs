import luaparse from 'luaparse';
// Inspect literals and known difficulty branches; never evaluate addon Lua.
function truth(n){
 if(n?.type==='BooleanLiteral')return n.value;
 if(n?.type==='UnaryExpression'&&n.operator==='not'){const v=truth(n.argument);return v==null?null:!v;}
 if(n?.type==='LogicalExpression'){const a=truth(n.left),b=truth(n.right);return n.operator==='and'?(a===false||b===false?false:a===true&&b===true?true:null):(a===true||b===true?true:a===false&&b===false?false:null);}
 if(n?.type==='CallExpression'&&n.base?.type==='MemberExpression'&&['self','mod'].includes(n.base.base?.name)){const name=n.base.identifier.name;if(['Mythic','MythicPlus','Retail'].includes(name))return true;if(['Normal','Heroic','Classic','Cata','Mists','TBC','Wrath'].includes(name))return false;}
 return null;
}
function visit(node,fn){if(!node||typeof node!=='object')return;if(Array.isArray(node)){node.forEach(n=>visit(n,fn));return;}fn(node);if(node.type==='IfStatement'){for(const clause of node.clauses){const value=clause.condition?truth(clause.condition):true;if(value!==false)visit(clause.body,fn);if(value===true)break;}return;}for(const [k,v]of Object.entries(node))if(k!=='identifier')visit(v,fn);}
export function mythicOptionIds(source){
 return readLittleWigsModule(source).options;
}

const method=n=>n?.type==='CallExpression'&&n.base?.type==='MemberExpression'&&['self','mod'].includes(n.base.base?.name)?n.base.identifier.name:null;
const field=(table,name)=>table?.fields?.find(f=>(f.key?.name??f.key?.value)===name)?.value;
const first=table=>table?.fields?.find(f=>f.type==='TableValue')?.value;
export function readLittleWigsModule(source){
 const ast=luaparse.parse(source,{encodingMode:'pseudo-latin1',locations:true}),methods=new Map(),options=new Set(),timers=new Set(),messages=new Set(),names={},auras=[];
 const lines=source.split('\n'),commentAt=n=>lines[(n?.loc?.start?.line||1)-1]?.match(/--\s*(.+)$/)?.[1]?.trim()||'',clean=s=>s.replace(/\s*\([^)]*\)\s*$/,'').trim();
 const comments=new Map();for(const line of source.split('\n')){const m=line.match(/^\s*(?:\[(\d+)\]\s*=|\{(\d+)\s*[,}]|(\d+)\s*,).*?--\s*(.+)$/);if(m){const id=Number(m[1]||m[2]||m[3]),label=m[4].trim();if(!/^(TODO|removed|was |see |replaced|\d)/i.test(label)){comments.set(id,label);names[id]=label.replace(/\s*\([^)]*\)\s*$/,'').trim();}}}
 // Later Retail definitions replace legacy handlers/options in these modules.
 visit(ast,n=>{if(n.type==='FunctionDeclaration'&&['self','mod'].includes(n.identifier?.base?.name))methods.set(n.identifier.identifier.name,n);});
 visit(methods.get('GetOptions')?.body,n=>{if(n.type!=='ReturnStatement')return;for(const f of n.arguments[0]?.fields||[]){const entry=f.value,id=entry?.type==='NumericLiteral'?entry.value:first(entry)?.value;if(Number.isInteger(id)&&id>0){options.add(id);const name=clean(commentAt(f));if(name)names[id]=name;}}});
 visit(ast,n=>{if(method(n)!=='SetRenames')return;for(const f of n.arguments[0]?.fields||[]){const id=f.key?.value,name=clean(commentAt(f));if(Number.isInteger(id)&&name)names[id]=name;}});
 const visited=new Set(),queue=['OnBossEnable','OnEncounterStart','OnEngage'];
 while(queue.length){const name=queue.shift();if(visited.has(name)||!methods.has(name))continue;visited.add(name);
  visit(methods.get(name).body,n=>{const called=method(n);if(!called)return;if(methods.has(called))queue.push(called);
   if(['Log','Death','RegisterEvent','RegisterUnitEvent','RegisterMessage','RegisterUnitEvent','ScheduleTimer','ScheduleRepeatingTimer','RegisterWidgetEvent'].includes(called))for(const arg of n.arguments||[]){const handler=arg.type==='StringLiteral'?arg.value:arg.type==='MemberExpression'?arg.identifier.name:null;if(methods.has(handler))queue.push(handler);}
   const id=n.arguments?.[0]?.value;if(!Number.isInteger(id)||id<=0)return;
   if(['Bar','CDBar','BarAllowDuplicate','CDBarAllowDuplicate'].includes(called))timers.add(id);
   if(['Message','PersonalMessage','TargetMessage','TargetsMessage','StackMessage'].includes(called))messages.add(id);
  });
 }
 visit(ast,n=>{if(method(n)!=='SetAuraData')return;let header=null;for(const f of n.arguments[0]?.fields||[]){const table=f.value,id=first(table)?.value;if(!Number.isInteger(id))continue;const difficulty=field(table,'difficulty')?.value;if(difficulty&&['normal','heroic'].includes(difficulty))continue;
  const h=field(table,'header');if(h)header=h.type==='NumericLiteral'?h.value:null;
  const references=new Set();visit(field(table,'tip'),v=>{if(method(v)==='SpellName'&&Number.isInteger(v.arguments?.[0]?.value)&&v.arguments[0].value!==id)references.add(v.arguments[0].value);});
  const label=commentAt(f)||comments.get(id)||'',npcName=label.match(/\(([^)]+)\)\s*$/)?.[1]||null;
  auras.push({id,name:clean(label)||names[id]||null,parentId:references.size===1?[...references][0]:null,npcId:header,npcName});
 }});
 const durationRules=[];
 const timerKeys=name=>{const ids=new Set();visit(methods.get(name)?.body,n=>{if(['Bar','CDBar'].includes(method(n))&&Number.isInteger(n.arguments?.[0]?.value))ids.add(n.arguments[0].value);});return [...ids];};
 const durationValues=condition=>{const values=new Set();function collect(n){if(!n||truth(n)===false)return;if(n.type==='LogicalExpression'){collect(n.left);collect(n.right);}else if(n.type==='BinaryExpression'&&n.operator==='=='){if(n.left?.name==='duration'&&n.right?.type==='NumericLiteral')values.add(n.right.value);if(n.right?.name==='duration'&&n.left?.type==='NumericLiteral')values.add(n.left.value);}}collect(condition);return [...values];};
 function durationWalk(node,durations=[]){if(!node||typeof node!=='object')return;if(Array.isArray(node)){node.forEach(n=>durationWalk(n,durations));return;}if(node.type==='IfStatement'){for(const clause of node.clauses){const value=clause.condition?truth(clause.condition):true;if(value!==false){const own=durationValues(clause.condition);durationWalk(clause.body,own.length?own:durations);}if(value===true)break;}return;}const called=method(node);if(called&&methods.has(called)&&durations.length){const ids=timerKeys(called);for(const duration of durations)for(const id of ids)if(timers.has(id))durationRules.push({duration,spellId:id});}for(const [k,v]of Object.entries(node))if(k!=='identifier')durationWalk(v,durations);}
 durationWalk(methods.get('ENCOUNTER_TIMELINE_EVENT_ADDED')?.body);
 return {options,timers,messages,names,auras,durationRules,reachableMethods:[...visited]};
}
export function mechanicAbilities(spellIds,{primary=[],names={},bars=new Set(),source,verifiedPrimary=false}={}){
 const canonical=[...primary],mythicIds=new Set(spellIds),ids=canonical.length?(verifiedPrimary?canonical:canonical.filter(id=>mythicIds.has(id))):spellIds,groups=new Map();
 for(const id of ids){const name=names[id]||null,key=name?name.toLowerCase().replace(/[^a-z0-9]/g,''):'id:'+id;if(groups.has(key)){groups.get(key).relatedSpellIds.push(id);continue;}groups.set(key,{id,name,selectionKind:canonical.length?'mechanic':'associated-spell',timerEvidence:bars.has(id)?'LittleWigs numeric bar':canonical.length?'LittleWigs Mythic-compatible mechanic option':null,relatedSpellIds:[],...(source?{mechanicSource:source}:{})});}
 for(const id of spellIds){const name=names[id],entry=name&&groups.get(name.toLowerCase().replace(/[^a-z0-9]/g,''));if(entry&&entry.id!==id&&!entry.relatedSpellIds.includes(id))entry.relatedSpellIds.push(id);}
 return [...groups.values()].sort((a,b)=>a.id-b.id);
}
