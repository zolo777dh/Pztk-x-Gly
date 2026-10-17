import React,{useEffect,useRef,useState} from 'react';
import {RefreshCw} from 'lucide-react';
import {call} from './api';

export default function AiModelPicker({mode,settings,token,value,onChange,label,placeholder}){
 const [models,setModels]=useState([]),[loading,setLoading]=useState(false),[error,setError]=useState(''),[loaded,setLoaded]=useState(false);const request=useRef(0);
 const provider=mode==='local'?'local':settings.cloudProvider||'openai';const endpoint=mode==='local'?settings.localEndpoint:provider==='compatible'?settings.compatibleEndpoint:provider;
 useEffect(()=>{request.current++;setModels([]);setError('');setLoaded(false);setLoading(false);return()=>{request.current++;};},[provider,endpoint,token]);
 async function load(){const ticket=++request.current;setLoading(true);setError('');try{const result=await call('ai.models',{mode,settings,token:token||undefined});if(ticket===request.current){setModels(result.models);setLoaded(true);}}catch(e){if(ticket===request.current)setError(e.message);}finally{if(ticket===request.current)setLoading(false);}}
 return <div className="ai-model-picker"><label>MODEL ID<input aria-label={label} value={value||''} placeholder={placeholder} onChange={e=>onChange(e.target.value)}/></label><label>AVAILABLE MODELS<select aria-label={label+' available models'} value={value||''} onChange={e=>onChange(e.target.value)}><option value="">{loaded?'Choose an available model…':'Load available models to choose…'}</option>{value&&!models.some(m=>m.id===value)&&<option value={value}>{value} · entered manually</option>}{models.map(m=><option key={m.id} value={m.id}>{m.name===m.id?m.id:m.name+' · '+m.id}</option>)}</select></label><button className="button" disabled={loading} onClick={load}><RefreshCw size={14}/>{loading?'Loading models…':'Load available models'}</button>{error&&<p className="notice amber" role="alert">{error}</p>}{loaded&&!models.length&&<p className="muted">No models were returned. Install a local model or enter a supported model ID manually.</p>}<small>Choose from the provider's list or enter an ID manually, then Save Settings. Model availability depends on your API account.</small></div>;
}
