import React,{useEffect,useRef,useState} from 'react';
import {openAssistant} from './api';
export default function AssistantBrowser({paused=false}){
 const [provider,setProvider]=useState('chatgpt'),[opened,setOpened]=useState(false),[status,setStatus]=useState(null),[error,setError]=useState('');const host=useRef();
 useEffect(()=>{if(!opened||paused||!window.doctor?.browser)return;let live=true;
  const rect=()=>{const r=host.current.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height};};
  window.doctor.browser({action:'open',provider,rect:rect()}).catch(e=>{if(live)setError(e.message);});
  const observer=new ResizeObserver(()=>window.doctor.browser({action:'resize',rect:rect()}).catch(e=>{if(live)setError(e.message);}));observer.observe(host.current);
  const timer=setInterval(()=>window.doctor.browser({action:'status'}).then(v=>{if(live)setStatus(v);}).catch(()=>{}),1200);
  return()=>{live=false;observer.disconnect();clearInterval(timer);window.doctor.browser({action:'hide'}).catch(()=>{});};
 },[opened,provider,paused]);
 return <section className="assistant-browser"><div className="browser-bar"><select aria-label="Embedded assistant provider" value={provider} onChange={e=>{setProvider(e.target.value);setError('');}}><option value="chatgpt">ChatGPT</option><option value="claude">Claude</option></select><button className="button" onClick={()=>setOpened(v=>!v)}>{opened?'Hide browser':'Open inside app'}</button><button className="text-button" onClick={()=>openAssistant(provider)}>External browser</button></div><p className="muted browser-status">{status?.loading?'Loading…':status?.url||'Sign in on the provider’s website. Paste requests and copy replies manually.'}</p>{(error||status?.error)&&<p className="notice amber">{error||status.error}. The provider may require an external browser.</p>}<div ref={host} className="assistant-browser-host" aria-label="Embedded assistant website">{(!opened||!window.doctor?.browser)&&<div className="empty"><h3>Your assistant, in this window</h3><p>Copy the reviewed request, paste it into the website, then paste its JSON reply into the task.</p>{!window.doctor?.browser&&<p>Embedded websites are available in the Windows desktop application.</p>}</div>}</div></section>;
}
