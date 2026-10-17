import path from 'node:path';
import {request} from './network.mjs';
import {writeAtomic} from './files.mjs';
import {reportCode,normalizeTimeline} from './integrations.mjs';

async function v1(resource,key,fetcher,params={}){
  const url=new URL('https://www.warcraftlogs.com/v1/'+resource);url.searchParams.set('api_key',key);for(const [k,v]of Object.entries(params))url.searchParams.set(k,String(v));
  for(let attempt=0;attempt<3;attempt++){
    const response=await request(url.href,{headers:{Accept:'application/json'},signal:AbortSignal.timeout(45000)},{fetcher,label:'Warcraft Logs V1'});
    if(response.status===429&&attempt<2){await new Promise(r=>setTimeout(r,Math.min(Number(response.headers.get('retry-after'))||2,5)*1000));continue;}
    if(!response.ok){const reason=response.status===401||response.status===403?'Check your V1 Client Key and public-report access. A V2 OAuth token belongs in V2 mode.':response.status===404?'The V1 endpoint or report was not found. Check report visibility and API V1 availability; if V1 is unavailable, configure a V2 API client.':response.status===429?'Rate limit reached; retry later.':'Check the WCL service and network/proxy settings.';throw Error(`Warcraft Logs V1 HTTP ${response.status}. ${reason}`);}
    let body;try{body=await response.json();}catch{throw Error('Warcraft Logs V1 returned a non-JSON response. Check network/proxy settings and API V1 availability.');}
    if(body?.error)throw Error('Warcraft Logs V1 rejected the request. Check your key, report visibility and API V1 availability.');return body;
  }
}
export async function v1Report(input,key,fetcher){
  const code=reportCode(input);const data=await v1('report/fights/'+code,key,fetcher);
  if(!Array.isArray(data.fights))throw Error('Unexpected Warcraft Logs V1 report response. No report was imported.');
  const actors=[...(data.friendlies||[]).map(a=>({id:a.id,name:a.name,type:a.type==='NPC'?'NPC':'Player',subType:a.type})),...(data.enemies||[]).map(a=>({id:a.id,name:a.name,type:'NPC',subType:a.type}))];
  return {code,title:data.title||code,startTime:data.start,fights:data.fights.map(f=>({...f,startTime:f.start_time,endTime:f.end_time})),masterData:{actors,abilities:[]},apiVersion:1};
}
export async function testV1(key,fetcher){const body=await v1('zones',key,fetcher);if(!Array.isArray(body))throw Error('Unexpected Warcraft Logs V1 zones response.');return {ok:true,message:`Warcraft Logs V1 key accepted · ${body.length} zones available.`};}
export async function v1Timeline(input,fightId,key,cacheDir,fetcher){
  const report=await v1Report(input,key,fetcher);const fight=report.fights.find(f=>f.id===Number(fightId));if(!fight)throw Error('Select a valid fight.');
  let cursor=fight.startTime;const events=[];
  for(let page=0;page<100;page++){
    const data=await v1('report/events/'+report.code,key,fetcher,{start:cursor,end:fight.endTime,filter:'type = "cast" or type = "begincast"'});
    if(!Array.isArray(data.events))throw Error('Unexpected Warcraft Logs V1 events response. No partial timeline imported.');events.push(...data.events);
    if(events.length>250000)throw Error('Fight exceeds 250,000 events. Select a shorter fight.');
    if(data.nextPageTimestamp==null||data.nextPageTimestamp>fight.endTime){const timeline=normalizeTimeline(report,fight,events,report.code);timeline.source.apiVersion=1;await writeAtomic(path.join(cacheDir,timeline.id+'.json'),JSON.stringify(timeline));return timeline;}
    if(data.nextPageTimestamp<=cursor)throw Error('Warcraft Logs V1 pagination did not advance. No partial timeline imported.');cursor=data.nextPageTimestamp;
  }
  throw Error('Warcraft Logs V1 pagination limit reached. No partial timeline imported.');
}
