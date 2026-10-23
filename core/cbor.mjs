// Bounded RFC 8949 codec. Numeric map keys are preserved separately for Lua tables.
export function encodeCbor(value,numericKeys=[],{maxBytes=4e6}={}){
 const numeric=new Set(numericKeys.map(p=>JSON.stringify(p))),chunks=[],seen=new Set();let count=0,bytes=0;
 const append=b=>{bytes+=b.length;if(bytes>maxBytes)throw Error('CBOR exceeds '+maxBytes/1e6+' MB');chunks.push(b);};
 function head(major,n){let b;if(n<24)b=Buffer.from([(major<<5)|n]);else if(n<256)b=Buffer.from([(major<<5)|24,n]);else if(n<65536){b=Buffer.alloc(3);b[0]=(major<<5)|25;b.writeUInt16BE(n,1);}else if(n<=0xffffffff){b=Buffer.alloc(5);b[0]=(major<<5)|26;b.writeUInt32BE(n,1);}else{b=Buffer.alloc(9);b[0]=(major<<5)|27;b.writeBigUInt64BE(BigInt(n),1);}append(b);}
 function item(v,depth=0,p=[]){if(++count>2e6||depth>48)throw Error('CBOR structure exceeds limits');
  if(v==null){append(Buffer.from([246]));return;}if(typeof v==='boolean'){append(Buffer.from([v?245:244]));return;}
  if(typeof v==='number'){if(!Number.isFinite(v))throw Error('Non-finite CBOR number');if(Number.isSafeInteger(v)){head(v>=0?0:1,v>=0?v:-1-v);}else{const b=Buffer.alloc(9);b[0]=251;b.writeDoubleBE(v,1);append(b);}return;}
  if(typeof v==='string'){const b=Buffer.from(v);head(3,b.length);append(b);return;}
  if(Buffer.isBuffer(v)||v instanceof Uint8Array){head(2,v.length);append(Buffer.from(v));return;}
  if(typeof v!=='object'||seen.has(v))throw Error('Unsupported or cyclic CBOR value');seen.add(v);
  if(Array.isArray(v)){head(4,v.length);v.forEach((x,i)=>item(x,depth+1,[...p,String(i)]));}
  else{const entries=Object.entries(v).filter(([,x])=>x!==undefined);head(5,entries.length);for(const [key,x]of entries){if(['__proto__','constructor','prototype'].includes(key))throw Error('Unsafe CBOR map key');const q=[...p,key];item(numeric.has(JSON.stringify(q))?Number(key):key,depth+1);item(x,depth+1,q);}}
  seen.delete(v);
 }
 item(value);return Buffer.concat(chunks);
}
export function decodeCbor(input,{maxBytes=4e6,maxItems=300000}={}){
 const b=Buffer.from(input);if(b.length>maxBytes)throw Error('CBOR exceeds 4 MB');let at=0,count=0;const numericKeys=[];
 const take=n=>{if(n<0||at+n>b.length)throw Error('Truncated CBOR');const s=b.subarray(at,at+n);at+=n;return s;};
 function arg(ai){if(ai<24)return ai;if(ai===24)return take(1)[0];if(ai===25)return take(2).readUInt16BE();if(ai===26)return take(4).readUInt32BE();if(ai===27){const v=take(8).readBigUInt64BE();if(v>BigInt(Number.MAX_SAFE_INTEGER))throw Error('CBOR integer exceeds safe precision');return Number(v);}if(ai===31)return -1;throw Error('Invalid CBOR argument');}
 function item(depth=0,p=[]){if(++count>maxItems||depth>48)throw Error('CBOR structure exceeds limits');const h=take(1)[0],major=h>>5,ai=h&31;
  if(major===7){if(ai===20)return false;if(ai===21)return true;if(ai===22)return null;if(ai===25){const x=take(2).readUInt16BE(),sign=x&0x8000?-1:1,e=(x>>10)&31,f=x&1023;const v=sign*(e===0?2**-14*f/1024:e===31?NaN:2**(e-15)*(1+f/1024));if(!Number.isFinite(v))throw Error('Non-finite CBOR number');return v;}if(ai===26||ai===27){const raw=take(ai===26?4:8),n=ai===26?raw.readFloatBE():raw.readDoubleBE();if(!Number.isFinite(n))throw Error('Non-finite CBOR number');return n;}throw Error('Unsupported CBOR simple value');}
  const n=arg(ai);if(major===0||major===1){if(n<0)throw Error('Invalid CBOR integer');return major===0?n:-1-n;}
  if(major===2||major===3){if(n<0)throw Error('Indefinite CBOR strings are unsupported');const raw=take(n);return major===2?raw:new TextDecoder('utf-8',{fatal:true}).decode(raw);}
  if(major===4){const v=[];for(let i=0;n<0?b[at]!==255:i<n;i++)v.push(item(depth+1,[...p,String(i)]));if(n<0)take(1);return v;}
  if(major===5){const v={};for(let i=0;n<0?b[at]!==255:i<n;i++){const key=item(depth+1);if(!['string','number'].includes(typeof key)||['__proto__','constructor','prototype'].includes(String(key))||Object.hasOwn(v,String(key)))throw Error('Unsafe or colliding CBOR map key');const q=[...p,String(key)];if(typeof key==='number')numericKeys.push(q);v[key]=item(depth+1,q);}if(n<0)take(1);return v;}
  throw Error('Unsupported CBOR type/tag');
 }
 const data=item();if(at!==b.length)throw Error('Trailing CBOR data');return {data,numericKeys};
}
