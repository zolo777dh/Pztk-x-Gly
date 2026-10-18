import {parseDocument} from 'htmlparser2';
import {normalizePriorityData,priorityTables} from './priority-reference.mjs';
import {sha} from './files.mjs';
function text(node){return node.type==='text'?node.data:(node.children||[]).map(text).join('');}
function find(node,match,result=[]){if(match(node))result.push(node);for(const child of node.children||[])find(child,match,result);return result;}
export function parseReference(html,filename='reference.html'){
  if(typeof html!=='string'||Buffer.byteLength(html)>10e6)throw Error('Reference HTML exceeds 10 MB');
  const doc=parseDocument(html);const title=text(find(doc,n=>n.name==='title')[0]||{}).trim()||filename;
  const scripts=find(doc,n=>n.name==='script'&&n.attribs?.type==='application/json');let data;const candidates=[];
  if(/^[\s]*[\[{]/.test(html)){try{candidates.push(JSON.parse(html));}catch{throw Error('Invalid JSON reference');}}
  for(const node of scripts){try{candidates.push(JSON.parse(text(node)));}catch{}}
  for(const value of candidates)if(value?.presets&&typeof value.presets==='object'){data=normalizePriorityData(value);break;}
  if(!data)data=priorityTables(doc);
  if(!data){const tables=find(doc,n=>n.name==='table').map(n=>find(n,c=>c.name==='tr').map(row=>(row.children||[]).filter(c=>c.name==='td'||c.name==='th').map(cell=>text(cell).trim())));const headings=find(doc,n=>/^h[1-6]$/.test(n.name||'')).map(text);
    for(const value of candidates){const arrays=Array.isArray(value)?[value]:Object.values(value||{}).filter(Array.isArray);for(const array of arrays){if(!array.length||!array.every(row=>row&&typeof row==='object'&&!Array.isArray(row)))continue;const keys=[...new Set(array.flatMap(Object.keys))].slice(0,50);tables.push([keys,...array.slice(0,10000).map(row=>keys.map(k=>row[k]==null?'':typeof row[k]==='object'?JSON.stringify(row[k]):String(row[k])))]);}}
    if(/\.csv$/i.test(filename))tables.push(parseCSV(html));
    if(!tables.length&&!headings.length)throw Error('No supported structured reference data or static tables/headings found. HTML scripts are never executed.');return {id:sha(html).slice(0,16),format:'pztk-reference-v1',kind:'static-html',filename,title,tables,headings,importedAt:new Date().toISOString()};}
  if(data.presets.length>1000||data.assignments.length>10000)throw Error('Reference exceeds preset/assignment limits');
  if(data.presets.some(p=>typeof p.id!=='string'||typeof p.name!=='string'||!Array.isArray(p.rows)||p.rows.some(r=>!Array.isArray(r)||typeof r[0]!=='string'||(r[1]!=null&&typeof r[1]!=='string'))))throw Error('Unsupported priority preset schema');
  return {id:sha(html).slice(0,16),format:'pztk-reference-v1',kind:'cooldown-priority-reference',filename,title,importedAt:new Date().toISOString(),presets:data.presets,assignments:data.assignments,missing:data.missing||[],packs:data.packs||[],warning:'Defensive sets are imported as priorities. No recorded press times are required or calculated.'};
}
function parseCSV(content){const delimiter=content.split('\n')[0].includes(';')?';':',';const rows=[];let row=[],cell='',quoted=false;for(let i=0;i<content.length;i++){const char=content[i];if(char==='"'){if(quoted&&content[i+1]==='"'){cell+='"';i++;}else quoted=!quoted;}else if(char===delimiter&&!quoted){row.push(cell);cell='';}else if(char==='\n'&&!quoted){row.push(cell.replace(/\r$/,''));if(row.some(Boolean))rows.push(row);row=[];cell='';}else cell+=char;}if(quoted)throw Error('Unclosed CSV quote');row.push(cell.replace(/\r$/,''));if(row.some(Boolean))rows.push(row);if(rows.length>10000)throw Error('CSV exceeds 10000 rows');return rows;}
