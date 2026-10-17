export function cloudProvider(settings){const provider=settings.cloudProvider||'compatible';if(!['openai','anthropic','compatible'].includes(provider))throw Error('Choose OpenAI, Anthropic Claude or an OpenAI-compatible provider.');return provider;}
export function aiModel(settings,mode){if(mode==='local')return settings.localModel;const provider=cloudProvider(settings);return provider==='anthropic'?settings.anthropicModel:provider==='compatible'?(settings.compatibleModel??settings.cloudModel):settings.cloudModel;}
export function aiHeaders(provider,token){if(!token)return {};return provider==='anthropic'?{'x-api-key':token,'anthropic-version':'2023-06-01'}:{Authorization:'Bearer '+token};}
export function aiEndpoint(settings,mode){
  const provider=mode==='local'?'local':cloudProvider(settings);const input=provider==='local'?settings.localEndpoint:provider==='anthropic'?'https://api.anthropic.com/v1':provider==='openai'?'https://api.openai.com/v1':(settings.compatibleEndpoint||settings.cloudEndpoint);
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
export async function listAIModels({settings,token,mode,fetcher}){
  if(!['local','cloud'].includes(mode))throw Error('Choose local or cloud AI.');
  const endpoint=aiEndpoint(settings,mode);if(mode==='cloud'&&!token)throw Error('Add your cloud API key for this session before testing.');
  const provider=mode==='local'?'local':cloudProvider(settings);const choices=new Map();let after='';const cursors=new Set();
  for(let page=0;page<10;page++){
    const response=await request(endpoint.base+'/models'+(after?'?after_id='+encodeURIComponent(after):''),{headers:aiHeaders(provider,token),signal:AbortSignal.timeout(15000)},{fetcher,label:'AI provider',mode});
    if(!response.ok)throw Error(`AI models endpoint returned HTTP ${response.status}. Check the API URL and credentials; some providers do not expose a model list. You can enter a model ID manually.`);
    let body;try{body=await response.json();}catch{throw Error('The server did not return a JSON model list. Check the selected provider and API URL.');}
    if(!Array.isArray(body.data))throw Error('Unexpected model list. Check the selected provider and its /v1 API endpoint.');
    for(const entry of body.data){if(typeof entry?.id!=='string'||!entry.id.trim()||entry.id.length>300)continue;const id=entry.id.trim();choices.set(id,{id,name:String(entry.display_name||entry.name||id).slice(0,300)});if(choices.size>2000)throw Error('The provider model list exceeds 2,000 entries. Enter a model ID manually.');}
    if(provider!=='anthropic'||!body.has_more)return {provider,models:[...choices.values()].sort((a,b)=>a.id.localeCompare(b.id))};
    after=body.last_id;if(typeof after!=='string'||!after||cursors.has(after))throw Error('The provider model list pagination did not advance');cursors.add(after);
  }
  throw Error('The provider model list exceeds its page limit. Enter a model ID manually.');
}
export async function testAIConnection(options){
  const {settings,mode}=options;const {models:choices}=await listAIModels(options);const model=aiModel(settings,mode);const models=choices.map(m=>m.id);
  if(model&&!models.includes(model))return {ok:true,modelFound:false,models:models.slice(0,30),message:`Server is reachable, but model “${model}” is not listed. Choose an installed model${mode==='local'?' or run ollama pull '+model:''}.`};
  return {ok:true,modelFound:true,models:models.slice(0,30),message:`Connection successful${model?' · '+model:''}. ${models.length} models available.`};
}
