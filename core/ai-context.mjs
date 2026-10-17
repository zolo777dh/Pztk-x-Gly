import {parseLua} from './analyzer.mjs';
import {sha} from './files.mjs';

export function prepareContext({source,file,build,issue=null,focusLine,limit=24000}) {
  const lines=source.split('\n');const focus=Math.min(lines.length,Math.max(1,Number(focusLine||issue?.line)||1));
  let start=0,end=lines.length,kind='whole-file',allowReplacement=true;
  if(source.length>limit){
    let functions=[];
    if(source.length<2000000)try{const ast=parseLua(source);const visit=n=>{if(!n||typeof n!=='object')return;if(n.type==='FunctionDeclaration'&&n.loc?.start.line<=focus&&n.loc.end.line>=focus)functions.push(n.loc);for(const [k,v]of Object.entries(n)){if(k==='loc'||k==='globals')continue;if(Array.isArray(v))v.forEach(visit);else if(v&&typeof v==='object')visit(v);}};visit(ast);}catch{}
    functions.sort((a,b)=>(a.end.line-a.start.line)-(b.end.line-b.start.line));
    const fn=functions.find(loc=>lines.slice(loc.start.line-1,loc.end.line).join('\n').length<=limit);
    if(fn){start=fn.start.line-1;end=fn.end.line;kind='function';}
    else{start=focus-1;end=focus;let size=lines[start].length;
      if(size>limit){allowReplacement=false;kind='analysis-only';}
      else{kind='excerpt';let left=true,right=true;while(left||right){if(left&&start>0&&size+lines[start-1].length+1<=limit){start--;size+=lines[start].length+1;}else left=false;if(right&&end<lines.length&&size+lines[end].length+1<=limit){size+=lines[end].length+1;end++;}else right=false;}}
    }
  }
  const excerpt=lines.slice(start,end).join('\n');
  const scope={kind,startLine:start+1,endLine:end,totalLines:lines.length,focusLine:focus,allowReplacement,characters:Math.min(excerpt.length,limit)};
  const cleanIssue=issue?{kind:issue.kind,title:String(issue.title||'').slice(0,300),line:issue.line,detail:String(issue.detail||'').slice(0,3000),trace:String(issue.trace||'').slice(0,6000)}:null;
  const context={build,file,scope,source:excerpt.slice(0,limit),issue:cleanIssue,request:'Explain the reported issue. Return replacement code for exactly the supplied source fragment if a behavior-preserving correction is justified; otherwise return null.'};
  function expand(replacement){
    if(replacement==null)return null;
    if(!allowReplacement)throw Error('This generated-data line was clipped for analysis. Automatic replacement is disabled; inspect its generator or a smaller source fragment.');
    if(typeof replacement!=='string'||!replacement.trim())throw Error('The model returned an empty replacement. Source was not changed.');
    const eol=source.includes('\r\n')?'\r\n':'\n';
    const result=[...lines.slice(0,start),replacement.replace(/\r\n|\r|\n/g,'\n').replace(/\n$/,''),...lines.slice(end)].join('\n');
    // A trailing newline belongs to the source selection; retain it if the excerpt ended at EOF.
    return (end===lines.length&&source.endsWith('\n')&&!result.endsWith('\n')?result+'\n':result).replace(/\r?\n/g,eol);
  }
  return {context,scope,expand,sourceHash:sha(Buffer.from(source))};
}
