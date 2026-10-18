// Read reference data only. Page scripts are never evaluated.
import {SPELL_NAMES,SPEC_NAMES} from './wow-names.mjs';
const positive=v=>/^[1-9]\d{0,7}$/.test(String(v??'').trim());
const label=n=>n?.type==='text'?n.data:['script','style'].includes(n?.name)?'':(n?.children||[]).map(label).join(' ');
const norm=s=>String(s||'').toLowerCase().replace(/[^a-z0-9]/g,'');
const walk=(n,test,out=[])=>{if(test(n))out.push(n);for(const c of n.children||[])walk(c,test,out);return out;};
export function normalizePriorityData(value){
 const raw=value?.presets;if(!raw||typeof raw!=='object')return null;
 const spellNames={...SPELL_NAMES};for(const spell of Array.isArray(value.catalog)?value.catalog:Object.values(value.catalog||{}))if(positive(spell?.id)&&typeof spell.name==='string')spellNames[String(Number(spell.id))]=spell.name;
 const specId=value.specId||Object.entries(SPEC_NAMES).find(([,name])=>name.toLowerCase()===String(value.spec||'').toLowerCase())?.[0];
 const entries=Array.isArray(raw)?raw.map((p,i)=>[String(i+1),p]):Object.entries(raw);if(entries.length>1000)throw Error('Reference exceeds 1000 defensive sets');
 const presets=entries.map(([key,p],i)=>{
  if(!p||typeof p!=='object')throw Error('Defensive set '+(i+1)+' must contain a name and spell list');const source=p.rows??p.spells??p.list??p.abilities;
  const rows=Array.isArray(source)?source:source&&typeof source==='object'?Object.entries(source).map(([id,name])=>[name,id]):null;if(!rows)throw Error('Defensive set '+(p.name||key)+' needs rows, spells or list');if(rows.length>200)throw Error('A defensive set exceeds 200 spells');
  return {...p,...(p.specId||specId?{specId:Number(p.specId||specId)}:{}),id:String(p.id??p.key??key),name:String(p.name??p.title??p.label??'Set '+(i+1)),spellNames,rowNotes:rows.map(r=>r&&typeof r==='object'&&!Array.isArray(r)?String(r.when||''):''),rows:rows.map(r=>{
   let id,name;if(Array.isArray(r)){[name,id]=r;if(positive(name)&&!positive(id)&&typeof id==='string')[id,name]=r;}
   else if(r&&typeof r==='object'){name=r.name??r.spellName??r.ability??r.label;if(r.ids!==undefined){if(!Array.isArray(r.ids)||r.ids.length>200||r.ids.some(v=>!positive(v)))throw Error('Invalid defensive ids array in '+(p.name||key));id=[...new Set(r.ids.map(v=>String(Number(v))))].join(' + ');}else id=r.spellId??r.spellID??r.spell_id??r.spell??r.id;}
   else{id=r;}
   if(id==null||id==='')return [String(name||''),''];if(!positive(id)){if(typeof id==='string'&&id.length<=200)return [String(name||''),id];throw Error('Invalid defensive spell ID in '+(p.name||key));}id=String(Number(id));return [String(name||SPELL_NAMES[id]||'Spell '+id),id];
  })};
 });
 const assignments=(value.assignments||[]);if(!Array.isArray(assignments)||assignments.length>10000)throw Error('Reference assignments exceed supported limits');
 return {...value,presets,assignments:assignments.map(a=>({...a,encounter:String(a.encounter??a.boss??''),ability:String(a.ability??a.bossAbility??a.name??''),cast:a.cast??a.bossSpellId??a.spellId,samples:Array.isArray(a.samples)?a.samples:[]}))};
}

// NSR has one Together group per preset. Different overlap choices must be
// separate variants, otherwise independent cooldowns would all be called at once.
export function referenceSetVariants(preset){
 const names={...SPELL_NAMES,...preset.spellNames},ordered=[],groups=[],seen=new Set();
 for(const [name,raw]of preset.rows||[]){
  const value=String(raw??'').trim();if(!/^[1-9]\d{0,7}(?:\s*\+\s*[1-9]\d{0,7})*$/.test(value))continue;
  const ids=[...new Set(value.split('+').map(n=>Number(n.trim())))];
  if(ids.length===1&&name&&!/^Spell \d+$/.test(name))names[ids[0]]=name;
  if(ids.length>1&&!groups.some(g=>g.length===ids.length&&g.every(id=>ids.includes(id))))groups.push(ids);
  for(const id of ids)if(!seen.has(id)){seen.add(id);ordered.push(id);}
 }
 if(!ordered.length)return [];
 return (groups.length?groups:[[]]).map((group,index)=>{
  const ids=index?[...group,...ordered.filter(id=>!group.includes(id))]:ordered;
  let name=preset.name;if(index){name+=' · '+group.map(id=>names[id]||'Spell '+id).join(' + ');while(Buffer.byteLength(name)>120)name=Array.from(name).slice(0,-1).join('');}
  return {variant:index,name,spells:ids.map(id=>({spellId:id,name:names[id]||'Spell '+id,together:group.includes(id)})),notes:{role:preset.role||'',hint:preset.hint||'',note:preset.note||'',gate:preset.gate??null,rows:(preset.rows||[]).map(([label,ids],i)=>({label,ids,when:preset.rowNotes?.[i]||''}))}};
 });
}
export function priorityTables(doc){
 const all=walk(doc,()=>true);const presets=[];let heading='';
 for(const node of all){if(/^h[1-6]$/.test(node.name||'')){heading=label(node).trim();continue;}if(node.name!=='table')continue;
  const rows=walk(node,n=>n.name==='tr').map(r=>(r.children||[]).filter(c=>c.name==='td'||c.name==='th'));if(rows.length<2)continue;
  const headers=rows[0].map(c=>norm(label(c)));const find=names=>headers.findIndex(h=>names.includes(h));if(headers.some(h=>['defensivetime','defensivepresstime','presstime','meandefensivetime'].includes(h)))continue;const idCol=find(['spellid','defensivespellid','defensiveid','abilityid']);const nameCol=find(['defensiveability','defensivename','ability','spellname','defensive','cooldown','name']);const setCol=find(['preset','set','presetname','defensiveset']);const orderCol=find(['priority','order','rank']);
  const explicit=nameCol>=0&&(idCol>=0||headers[nameCol].includes('defensive'));
  const packed=setCol>=0&&headers.some(h=>/defensive|cooldown|spell|prioritylist|priorityorder/.test(h));
  if(!explicit&&!packed)continue;const groups=new Map();
  for(const cells of rows.slice(1)){
   const setName=(setCol>=0?label(cells[setCol]).trim():heading)||'Imported defensive set';if(!groups.has(setName))groups.set(setName,[]);const group=groups.get(setName);
   const links=walk({children:cells},n=>n.name==='a'&&/(?:spell[=/]|\/spells\/)\d+/.test(n.attribs?.href||''));const linked=links.map(a=>({id:a.attribs.href.match(/(?:spell[=/]|\/spells\/)(\d+)/)[1],name:label(a).trim()||a.attribs.title}));
   let ids=linked;if(explicit){const raw=idCol>=0?label(cells[idCol]).trim():'';const match=raw.match(/^(?:#|spell\s*)?(\d+)$/i);if(match)ids=[{id:match[1],name:label(cells[nameCol]).trim()}];}
   if(!ids.length&&packed){for(const [i,cell]of cells.entries()){const value=label(cell).trim();if(i!==setCol&&/^(?:\d{3,8})(?:\s*(?:→|>|,|\+|;|\|)\s*\d{3,8})*$/.test(value))ids.push(...value.match(/\d+/g).map(id=>({id,name:SPELL_NAMES[id]||'Spell '+id})));}const text=cells.filter((_,i)=>i!==setCol).map(label).join(' ');if(!ids.length)ids=[...text.matchAll(/([^→;|]+?)\s*\((\d{3,8})\)/g)].map(m=>({id:m[2],name:m[1].trim()}));}
   const order=orderCol>=0?Number(label(cells[orderCol])):group.length+1;for(const spell of ids)if(positive(spell.id))group.push({...spell,order:Number.isFinite(order)?order:group.length+1});
  }
  for(const [name,spells]of groups)if(spells.length){const seen=new Set();const ordered=spells.sort((a,b)=>a.order-b.order).filter(s=>!seen.has(s.id)&&seen.add(s.id));presets.push({id:'html_'+(presets.length+1),name,rows:ordered.map(s=>[s.name||SPELL_NAMES[s.id]||'Spell '+s.id,String(Number(s.id))])});}
 }
 return presets.length?{presets,assignments:[]}:null;
}
