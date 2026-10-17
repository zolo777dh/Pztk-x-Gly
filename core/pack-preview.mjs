// UI sampling only: callers keep the complete decoded payload for export/use.
export function packPreview(pack,{maxValues=2000,maxCharacters=120000,maxChildren=80,maxDepth=12,maxString=4000}={}){
  let values=0,truncated=false;
  function sample(value,depth){
    if(++values>maxValues){truncated=true;return '… preview value limit reached';}
    if(typeof value==='string'&&value.length>maxString){truncated=true;return value.slice(0,maxString)+'…';}
    if(!value||typeof value!=='object')return value;
    if(depth>=maxDepth){truncated=true;return '… deeper fields omitted from preview';}
    const result={};let count=0;
    for(const key in value){if(!Object.hasOwn(value,key))continue;if(count++>=maxChildren||values>=maxValues){result['…']='More entries omitted from preview';truncated=true;break;}
      const displayKey=key.length>200?key.slice(0,200)+'…':key;if(displayKey!==key)truncated=true;
      Object.defineProperty(result,displayKey,{value:sample(value[key],depth+1),enumerable:true,configurable:true,writable:true});
    }
    return result;
  }
  let text=JSON.stringify(sample(pack,0),null,2);
  if(text.length>maxCharacters){truncated=true;text=text.slice(0,Math.max(0,maxCharacters-80))+'\n… Preview clipped; use Save decoded JSON for the complete payload.';}
  return {text,truncated};
}
