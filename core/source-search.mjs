import fs from 'node:fs/promises';
import path from 'node:path';
import {inside,readSource} from './files.mjs';
import {findText,matchSnippet,searchPattern} from './text-search.mjs';

const extensions=/\.(lua|toc|xml|txt|md|json|ya?ml|ini|cfg|[cm]?js|jsx|tsx?|css|html?|csv|py|ps1|bat|sh|sql)$/i;
export async function searchSources(projects,{query,matchCase=false,wholeWord=false}={}){
  searchPattern(query,{matchCase,wholeWord});
  const result={query,matchCase:Boolean(matchCase),wholeWord:Boolean(wholeWord),groups:[],matches:0,searchedFiles:0,skippedFiles:0,warnings:[],truncated:false,reason:'',bytes:0};
  const seen=new Set(),start=Date.now();let candidates=0,entries=0;
  const warn=message=>{if(result.warnings.length<20)result.warnings.push(message);};
  const stop=()=>{if(result.truncated)return true;if(Date.now()-start>15000){result.truncated=true;result.reason='Search reached 15 seconds. Narrow the query and search again.';return true;}return false;};
  // Assign a nested module to its most specific registered folder once.
  for(const project of [...projects].sort((a,b)=>b.root.length-a.root.length)){
    if(stop())break;
    const visit=async(dir,prefix='',depth=0)=>{
      if(stop())return;if(depth>60){warn(`${project.name}: skipped a folder deeper than 60 levels`);return;}
      let list;try{list=await fs.readdir(dir,{withFileTypes:true});}catch{warn(`${project.name}/${prefix}: folder unavailable`);return;}
      list.sort((a,b)=>a.name.localeCompare(b.name));
      for(const entry of list){
        if(stop())return;if(++entries>100000){result.truncated=true;result.reason='Search reached 100,000 directory entries. Connect more specific addon folders.';return;}
        if(entry.isSymbolicLink())continue;const relative=prefix+entry.name;
        if(entry.isDirectory()){if(!['.git','node_modules','.cache'].includes(entry.name))await visit(path.join(dir,entry.name),relative+'/',depth+1);continue;}
        if(!entry.isFile()||!extensions.test(entry.name))continue;
        if(++candidates>20000){result.truncated=true;result.reason='Search reached 20,000 text files. Connect more specific addon folders.';return;}
        try{
          const file=await inside(project.root,relative);const key=process.platform==='win32'?file.toLowerCase():file;if(seen.has(key))continue;seen.add(key);
          const stat=await fs.stat(file);if(stat.size>8*1024*1024){result.skippedFiles++;continue;}
          if(result.bytes+stat.size>256*1024*1024){result.truncated=true;result.reason='Search reached 256 MiB of source. Narrow the connected folders.';return;}
          const source=await readSource(project.root,relative);result.bytes+=source.size;result.searchedFiles++;
          const found=findText(source.text,query,{matchCase,wholeWord},3000-result.matches);
          if(found.matches.length)result.groups.push({projectId:project.id,projectName:project.name,file:relative,hash:source.hash,matches:found.matches.map(match=>({...match,...matchSnippet(source.text,match)}))});
          result.matches+=found.matches.length;
          if(found.truncated){result.truncated=true;result.reason='More than 3,000 matches. Refine the search to see the remaining matches.';return;}
        }catch{result.skippedFiles++;warn(`${project.name}/${relative}: unavailable, binary or not valid UTF-8`);}
      }
    };
    await visit(project.root);
  }
  result.duration=Date.now()-start;return result;
}
