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
 const ast=luaparse.parse(source,{encodingMode:'pseudo-latin1'}),ids=new Set();
 visit(ast,n=>{if(n.type!=='FunctionDeclaration'||n.identifier?.identifier?.name!=='GetOptions')return;
  visit(n.body,r=>{if(r.type!=='ReturnStatement')return;const table=r.arguments[0];if(table?.type!=='TableConstructorExpression')return;for(const field of table.fields){const entry=field.value;const id=entry?.type==='NumericLiteral'?entry.value:entry?.type==='TableConstructorExpression'?entry.fields.find(f=>f.type==='TableValue')?.value?.value:null;if(Number.isInteger(id)&&id>0)ids.add(id);}});
 });return ids;
}
export function mechanicAbilities(spellIds,{primary=[],names={},bars=new Set(),source}={}){
 const canonical=[...primary],mythicIds=new Set(spellIds),ids=canonical.length?canonical.filter(id=>mythicIds.has(id)):spellIds,groups=new Map();
 for(const id of ids){const name=names[id]||null,key=name?name.toLowerCase().replace(/[^a-z0-9]/g,''):'id:'+id;if(groups.has(key)){groups.get(key).relatedSpellIds.push(id);continue;}groups.set(key,{id,name,selectionKind:canonical.length?'mechanic':'associated-spell',timerEvidence:bars.has(id)?'LittleWigs numeric bar':canonical.length?'LittleWigs Mythic-compatible mechanic option':null,relatedSpellIds:[],...(source?{mechanicSource:source}:{})});}
 for(const id of spellIds){const name=names[id],entry=name&&groups.get(name.toLowerCase().replace(/[^a-z0-9]/g,''));if(entry&&entry.id!==id&&!entry.relatedSpellIds.includes(id))entry.relatedSpellIds.push(id);}
 return [...groups.values()].sort((a,b)=>a.id-b.id);
}
