import http from 'node:http';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {DoctorService} from '../core/service.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const service=await new DoctorService(path.join(root,'.data'),path.join(root,'resources')).init();
http.createServer(async(req,res)=>{
  res.setHeader('Content-Type','application/json');res.setHeader('Cache-Control','no-store');
  try{
    if(req.method!=='POST'||req.url!=='/api/call'||req.headers['content-type']!=='application/json'||req.headers.origin!=='http://127.0.0.1:5173')throw Error('Only the local development UI may call this endpoint');
    let raw='';for await(const chunk of req){raw+=chunk;if(Buffer.byteLength(raw)>25e6)throw Error('Request too large');}
    const {method,args}=JSON.parse(raw);res.end(JSON.stringify({data:await service.handle(method,args)}));
  }catch(error){res.statusCode=400;res.end(JSON.stringify({error:error.message}));}
}).listen(4318,'127.0.0.1',()=>process.stdout.write('Doctor development backend: 127.0.0.1:4318\n'));
