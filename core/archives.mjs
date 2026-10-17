import {Zip,ZipPassThrough} from 'fflate';
import {deflateRawSync} from 'node:zlib';

// Keep fflate's ZIP container/CRC handling and use zlib's standard DEFLATE
// encoder for compatibility with Windows Explorer's built-in extractor.
class ZlibEntry extends ZipPassThrough {
  constructor(name){super(name);this.compression=8;this.chunks=[];}
  process(chunk,final){this.chunks.push(chunk);if(final)this.ondata(null,deflateRawSync(Buffer.concat(this.chunks),{level:6}),true);}
}
export function zipCompatible(files){
  const chunks=[];let failure;let complete=false;
  const zip=new Zip((error,data,final)=>{if(error)failure=error;else chunks.push(data);if(final)complete=true;});
  for(const [name,bytes]of Object.entries(files)){const entry=new ZlibEntry(name);zip.add(entry);entry.push(bytes,true);}
  zip.end();if(failure)throw failure;if(!complete)throw Error('ZIP creation did not finish');return Buffer.concat(chunks);
}
