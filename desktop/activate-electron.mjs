// Activate a retained official Electron archive without bypassing checksum verification.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {unzipSync} from 'fflate';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const cache=process.argv[2]||process.env.DOCTOR_ELECTRON_ZIPS;
if(!cache)throw Error('Pass a directory containing official Electron ZIPs and SHASUMS256.txt');
const manifest=await fs.readFile(path.join(cache,'SHASUMS256.txt'),'utf8');
const name=`electron-v38.8.4-${process.platform}-${process.arch}.zip`;
const line=manifest.split(/\r?\n/).find(s=>s.trim().split(/\s+/)[1]?.replace(/^\*/,'')===name);
if(!line)throw Error('Archive is absent from the official checksum manifest');
const bytes=await fs.readFile(path.join(cache,name));
if(crypto.createHash('sha256').update(bytes).digest('hex')!==line.trim().split(/\s+/)[0])throw Error('Electron SHA256 verification failed');
const target=path.join(root,'node_modules','electron','dist');await fs.mkdir(target,{recursive:true});
for(const [relative,data]of Object.entries(unzipSync(bytes))){const file=path.resolve(target,relative);if(!file.startsWith(target+path.sep))throw Error('Unsafe Electron archive path');if(relative.endsWith('/'))continue;await fs.mkdir(path.dirname(file),{recursive:true});await fs.writeFile(file,data);}
const executable=process.platform==='win32'?'electron.exe':'electron';if(process.platform!=='win32')await fs.chmod(path.join(target,executable),0o755);await fs.writeFile(path.join(root,'node_modules/electron/path.txt'),executable);console.log('Activated verified official Electron',name);
