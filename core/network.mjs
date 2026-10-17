export function aiEndpoint(settings,mode){
  const input=mode==='local'?settings.localEndpoint:settings.cloudEndpoint;
  let url;try{url=new URL(input);}catch{throw Error('Enter a valid AI API URL in Settings, including http:// or https://.');}
  if(!['http:','https:'].includes(url.protocol)||url.username||url.password)throw Error('AI endpoints must use HTTP(S) without credentials in the URL.');
  if(mode==='local'&&!['127.0.0.1','localhost','[::1]'].includes(url.hostname))throw Error('Local AI endpoint must use localhost.');
  if(mode==='cloud'&&url.protocol!=='https:')throw Error('Cloud AI must use HTTPS.');
  if(mode==='local'&&url.hostname==='localhost')url.hostname='127.0.0.1';
  let pathname=url.pathname.replace(/\/$/,'');
  if(pathname.endsWith('/chat/completions'))pathname=pathname.slice(0,-'/chat/completions'.length);
  if(!pathname)pathname='/v1';
  url.pathname=pathname;url.search='';url.hash='';
  return {base:url.href.replace(/\/$/,''),host:url.host};
}
export async function request(url,options,{fetcher=globalThis.fetch,label='AI provider',mode='cloud'}={}){
  try{return await fetcher(url,options);}catch(error){
    const code=error.cause?.code||error.code||'';const reason=String(error.cause?.message||error.message||'');
    if(error.name==='TimeoutError'||error.name==='AbortError'||/TIMEOUT|ETIMEDOUT/.test(code))throw Error(`${label} request timed out. Check the server; a local model may still be loading. Try Test connection in Settings.`);
    if(/CERT|TLS|SSL|certificate/i.test(code+' '+reason))throw Error(`${label}: TLS certificate verification failed. Check your system clock and trusted proxy certificate; verification remains enabled.`);
    if(/ENOTFOUND|EAI_AGAIN/.test(code))throw Error(`${label}: server name could not be resolved. Check the API address, DNS and network connection.`);
    if(mode==='local')throw Error(`Cannot connect to the local AI server at ${new URL(url).host}. Start Ollama or your local server, load the selected model, then use Settings → Test local connection. No model is bundled with this app.`);
    throw Error(`${label} could not be reached. Check Internet access, the API address, firewall and system proxy/VPN settings. Use Test connection in Settings.`);
  }
}
export async function testAIConnection({settings,token,mode,fetcher}){
  if(!['local','cloud'].includes(mode))throw Error('Choose local or cloud AI.');
  const endpoint=aiEndpoint(settings,mode);if(mode==='cloud'&&!token)throw Error('Add your cloud API key for this session before testing.');
  const response=await request(endpoint.base+'/models',{headers:token?{Authorization:'Bearer '+token}:{},signal:AbortSignal.timeout(15000)},{fetcher,label:'AI provider',mode});
  if(!response.ok)throw Error(`AI models endpoint returned HTTP ${response.status}. Check the API URL and credentials; some providers do not expose a model list.`);
  let body;try{body=await response.json();}catch{throw Error('The server did not return a JSON model list. Check the OpenAI-compatible API URL.');}
  if(!Array.isArray(body.data))throw Error('Unexpected model list. Use an OpenAI-compatible /v1 API endpoint.');
  const model=mode==='local'?settings.localModel:settings.cloudModel;const models=body.data.map(m=>m.id).filter(m=>typeof m==='string');
  if(model&&!models.includes(model))return {ok:true,modelFound:false,models:models.slice(0,30),message:`Server is reachable, but model “${model}” is not listed. Choose an installed model${mode==='local'?' or run ollama pull '+model:''}.`};
  return {ok:true,modelFound:true,models:models.slice(0,30),message:`Connection successful${model?' · '+model:''}. ${models.length} models available.`};
}
