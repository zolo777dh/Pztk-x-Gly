import {useEffect,useState} from 'react';
import {call} from './api';
import {SPELL_NAMES} from '../core/wow-names.mjs';
const cache={...SPELL_NAMES},pending=new Set(),failed=new Set();
export function useSpellNames(ids=[]){
 const [names,setNames]=useState(()=>({...cache}));
 const key=[...new Set(ids.map(Number).filter(n=>Number.isInteger(n)&&n>0&&n<=100000000))].sort((a,b)=>a-b).join(',');
 useEffect(()=>{let alive=true;const timer=setTimeout(async()=>{const wanted=key.split(',').map(Number).filter(Boolean),missing=wanted.filter(id=>!cache[id]&&!pending.has(id)&&!failed.has(id));
  for(let i=0;i<missing.length;i+=100){const batch=missing.slice(i,i+100);batch.forEach(id=>pending.add(id));try{const result=await call('spells.resolve',{ids:batch});Object.assign(cache,result.names);for(const id of result.unresolved||[])failed.add(id);}catch{batch.forEach(id=>failed.add(id));}finally{batch.forEach(id=>pending.delete(id));}if(!alive)return;}
  if(alive)setNames({...cache});
 },650);return()=>{alive=false;clearTimeout(timer);};},[key]);return names;
}
export const spellLabel=(id,names,name)=>`${id} = ${(name&&!/^Spell \d+$/.test(name)?name:null)||names?.[id]||'Name unavailable'}`;
