import React from 'react';
import {SPEC_NAMES} from '../core/wow-names.mjs';
export default function SpecSelect({value,onChange,label='Specialization',extra=[],disabled=false}){
 const entries=new Map(Object.entries(SPEC_NAMES));for(const s of extra)if(!entries.has(String(s.id)))entries.set(String(s.id),s.name||'Unrecognized specialization');
 if(value&&!entries.has(String(value)))entries.set(String(value),'Unrecognized imported specialization');
 return <select aria-label={label} value={String(value??'')} disabled={disabled} onChange={e=>onChange(e.target.value)}><option value="">Choose specialization…</option>{[...entries].sort((a,b)=>a[1].localeCompare(b[1])).map(([id,name])=><option key={id} value={id}>{name}</option>)}</select>;
}
