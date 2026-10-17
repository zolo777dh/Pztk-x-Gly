import {parseLua} from './analyzer.mjs';
export function parseSavedVariables(text){
  if(Buffer.byteLength(text)>20e6)throw Error('SavedVariables exceeds 20 MB');
  const ast=parseLua(text);let budget=250000;
  function value(node,depth=0){if(!node||depth>40||--budget<0)throw Error('Saved data exceeds parsing limits');
    switch(node.type){case 'StringLiteral':try{return new TextDecoder('utf8',{fatal:true}).decode(Buffer.from(node.value,'latin1'));}catch{return node.value;}case 'NumericLiteral':return node.value;case 'BooleanLiteral':return node.value;case 'NilLiteral':return null;
      case 'UnaryExpression':if(node.operator==='-'&&node.argument.type==='NumericLiteral')return -node.argument.value;break;
      case 'TableConstructorExpression':{const object={};let index=1;for(const field of node.fields){const key=field.type==='TableValue'?index++:field.type==='TableKeyString'?field.key.name:value(field.key,depth+1);if(!['string','number'].includes(typeof key)||['__proto__','constructor','prototype'].includes(String(key)))throw Error('Unsupported saved table key');object[key]=value(field.value,depth+1);}return object;}
    }throw Error('SavedVariables contains executable or unsupported expressions. Only literal tables are accepted');
  }
  const result={};for(const node of ast.body){if(node.type!=='AssignmentStatement')throw Error('Only data assignments are accepted');for(let i=0;i<node.variables.length;i++){const key=node.variables[i];if(key.type!=='Identifier'||['__proto__','constructor','prototype'].includes(key.name))throw Error('Unsupported saved assignment');result[key.name]=value(node.init[i]);}}
  return result;
}
export function savedSummary(data){const summary=[];function visit(v,p='',depth=0){if(depth>8||!v||typeof v!=='object')return;for(const [key,val]of Object.entries(v)){const current=p?p+'.'+key:key;if(['message','stack','error'].includes(key)&&typeof val==='string')summary.push({type:'error',path:current,text:val});if(key==='observed'&&val&&typeof val==='object')summary.push({type:'observed',path:current,encounters:Object.keys(val).filter(k=>k!=='v').length,data:val});if(depth<3&&['profiles','profileKeys'].includes(key))summary.push({type:'profiles',path:current,count:Object.keys(val||{}).length});visit(val,current,depth+1);}}
  visit(data);return summary.slice(0,2000);
}
