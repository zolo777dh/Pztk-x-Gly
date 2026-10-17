import fs from 'node:fs/promises';
import path from 'node:path';
import {writeAtomic} from './files.mjs';
import {request} from './network.mjs';

export const WCL_API='https://www.warcraftlogs.com/api/v2/client';
export function wclEndpoint(input=WCL_API){
  let url;try{url=new URL(input);}catch{throw Error('Enter a valid Warcraft Logs API URL.');}
  if(url.protocol!=='https:'||url.username||url.password||!/(^|\.)warcraftlogs\.com$/i.test(url.hostname)||!/^\/api\/v2\/(client|user)\/?$/.test(url.pathname)||url.search||url.hash)throw Error('Use an official Warcraft Logs HTTPS API endpoint ending in /api/v2/client or /api/v2/user.');
  return url.href.replace(/\/$/,'');
}
export class WclAuth {
  constructor(dir,{fetcher,secureStore}={}){this.file=path.join(dir,'warcraftlogs.credentials.json');this.fetcher=fetcher;this.secureStore=secureStore;this.credentials={mode:'token',token:'',clientId:'',clientSecret:'',v1Key:''};this.remembered=false;this.cached=null;this.storageError='';}
  async init(){try{const saved=JSON.parse(await fs.readFile(this.file,'utf8'));if(!this.secureStore)throw Error('System encryption is unavailable. Saved Warcraft Logs credentials were not opened.');this.credentials=JSON.parse(await this.secureStore.open(saved.encrypted));this.remembered=true;}catch(e){if(e.code!=='ENOENT')this.storageError='Saved Warcraft Logs credentials could not be decrypted. Re-enter them or use Forget saved key. No plaintext fallback is used.';}return this;}
  status(){const c=this.credentials;return {mode:c.mode,connected:c.mode==='oauth'?Boolean(c.clientId&&c.clientSecret):c.mode==='v1'?Boolean(c.v1Key):Boolean(c.token),remembered:this.remembered,secureAvailable:Boolean(this.secureStore),expiresAt:this.cached?.expiresAt||null,error:this.storageError};}
  async configure(args={}){
    if(args.forget){await fs.rm(this.file,{force:true});this.credentials={mode:'token',token:'',clientId:'',clientSecret:'',v1Key:''};this.cached=null;this.remembered=false;this.storageError='';return this.status();}
    if(this.storageError&&!['token','v1Key','clientId','clientSecret'].some(k=>typeof args[k]==='string'&&args[k].trim()))throw Error('Saved Warcraft Logs credentials could not be decrypted. Re-enter them or use Forget saved key before changing their storage.');
    const next={...this.credentials};if(args.mode!==undefined){if(!['v1','token','oauth'].includes(args.mode))throw Error('Choose V1 Client Key, V2 Access Token or V2 Client ID / Secret.');next.mode=args.mode;}
    for(const key of ['token','clientId','clientSecret','v1Key'])if(typeof args[key]==='string'&&args[key].trim())next[key]=args[key].trim().replace(key==='token'?/^Bearer\s+/i:/^$/,'');
    if(Object.values(next).some(v=>typeof v==='string'&&v.length>12000))throw Error('Warcraft Logs credential exceeds its size limit.');
    const connected=next.mode==='oauth'?Boolean(next.clientId&&next.clientSecret):next.mode==='v1'?Boolean(next.v1Key):Boolean(next.token);
    if(next.mode==='oauth'&&(next.clientId||next.clientSecret)&&!connected)throw Error('Enter both Warcraft Logs Client ID and Client Secret.');
    const remember=Boolean(args.remember&&connected);
    if(remember){if(!this.secureStore)throw Error('Secure system storage is unavailable. Turn off Remember key to connect for this session. Credentials will never be saved as plaintext.');const encrypted=await this.secureStore.seal(JSON.stringify(next));await writeAtomic(this.file,JSON.stringify({format:1,encrypted}));}
    else await fs.rm(this.file,{force:true});
    this.credentials=next;this.remembered=remember;this.cached=null;this.storageError='';return this.status();
  }
  async accessToken(){
    const c=this.credentials;
    if(c.mode==='v1')throw Error('Use the Warcraft Logs V1 importer for a V1 Client Key.');
    if(c.mode==='token'){if(!c.token)throw Error('Connect Warcraft Logs in Settings. Use an OAuth Access Token, or Client ID and Client Secret; a v1 API key is not a bearer token.');return c.token;}
    if(!c.clientId||!c.clientSecret)throw Error('Enter both Warcraft Logs Client ID and Client Secret in Settings.');
    if(this.cached&&this.cached.expiresAt>Date.now()+30000)return this.cached.token;
    const response=await request('https://www.warcraftlogs.com/oauth/token',{method:'POST',headers:{Authorization:'Basic '+Buffer.from(c.clientId+':'+c.clientSecret).toString('base64'),'Content-Type':'application/x-www-form-urlencoded',Accept:'application/json'},body:'grant_type=client_credentials',signal:AbortSignal.timeout(30000)},{fetcher:this.fetcher,label:'Warcraft Logs OAuth'});
    if(!response.ok)throw Error(`Warcraft Logs OAuth HTTP ${response.status}. Check Client ID and Client Secret from your WCL API client, not a v1 API key. No report was imported.`);
    let body;try{body=await response.json();}catch{throw Error('Warcraft Logs OAuth returned a non-JSON response. Check proxy/VPN settings.');}
    if(typeof body.access_token!=='string'||!body.access_token)throw Error('Warcraft Logs OAuth returned no access token.');
    const lifetime=Number(body.expires_in);if(!Number.isFinite(lifetime)||lifetime<=0)throw Error('Warcraft Logs OAuth returned an invalid token lifetime.');
    this.cached={token:body.access_token,expiresAt:Date.now()+lifetime*1000};return this.cached.token;
  }
  v1Key(){if(this.credentials.mode!=='v1'||!this.credentials.v1Key)throw Error('Enter your V1 Client Key in Settings and choose V1 Client Key mode.');return this.credentials.v1Key;}
  invalidate(){this.cached=null;}
}
