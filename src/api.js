export async function call(method,args={}){
  if(window.doctor)return window.doctor.call(method,args);
  const response=await fetch('/api/call',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({method,args})});const result=await response.json();if(!response.ok||result.error)throw Error(result.error||'Application request failed');return result.data;
}
export async function exportFile(name,text){if(window.doctor)return window.doctor.exportFile(name,text);const a=document.createElement('a');const url=URL.createObjectURL(new Blob([text],{type:'text/plain;charset=utf-8'}));a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);return true;}
