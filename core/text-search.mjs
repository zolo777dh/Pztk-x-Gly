// Literal searches share UTF-16 offsets with textarea selection APIs.
export function searchPattern(query,{matchCase=false,wholeWord=false}={}){
  if(typeof query!=='string'||!query||query.length>500)throw Error('Enter 1–500 characters to find');
  const literal=query.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
  return new RegExp(wholeWord?'(?<![\\p{L}\\p{N}_])'+literal+'(?![\\p{L}\\p{N}_])':literal,matchCase?'gu':'giu');
}
export function findText(text,query,options={},limit=3000){
  if(!query)return {matches:[],truncated:false};
  const pattern=searchPattern(query,options),matches=[];let line=1,lineStart=0;
  for(const match of text.matchAll(pattern)){
    if(matches.length>=limit)return {matches,truncated:true};
    let next;while((next=text.indexOf('\n',lineStart))>=0&&next<match.index){line++;lineStart=next+1;}
    matches.push({start:match.index,end:match.index+match[0].length,line,column:match.index-lineStart+1});
  }
  return {matches,truncated:false};
}
export function matchSnippet(text,match){
  const lineStart=match.start-match.column+1;const newline=text.indexOf('\n',match.start);let lineEnd=newline<0?text.length:newline;if(text[lineEnd-1]==='\r')lineEnd--;
  const start=Math.max(lineStart,match.start-90),end=Math.min(lineEnd,Math.max(start+240,match.end));
  return {snippet:text.slice(start,end),highlightStart:match.start-start,highlightEnd:Math.min(match.end,end)-start,clipLeft:start>lineStart,clipRight:end<lineEnd};
}
