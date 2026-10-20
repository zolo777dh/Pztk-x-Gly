import packager from '@electron/packager';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {zipCompatible} from '../core/archives.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const {version}=JSON.parse(await fs.readFile(path.join(root,'package.json'),'utf8'));
const paths=await packager({dir:root,name:'Pztk x Glyalith',appVersion:version,executableName:'Pztk x Glyalith',platform:'win32',arch:'x64',electronVersion:'38.8.4',out:path.join(root,'release'),overwrite:true,prune:true,asar:true,icon:path.join(root,'resources','icon.ico'),...(process.env.DOCTOR_ELECTRON_ZIPS?{electronZipDir:process.env.DOCTOR_ELECTRON_ZIPS}:{}),ignore:[/^\/(?:\.data|test-results|tests|release|src)(?:\/|$)/,/^\/test-ui.*\.png$/,/^\/vite\.config\.mjs$/,/^\/index\.html$/],win32metadata:{CompanyName:'Pztk x Glyalith',FileDescription:'Pztk x Glyalith'}});
const folder=paths[0];await fs.copyFile(path.join(root,'resources','START-HERE.txt'),path.join(folder,'START-HERE.txt'));for(const doc of ['README.md','VALIDATION.md','resources/APP-CAPABILITIES.md'])await fs.copyFile(path.join(root,doc),path.join(folder,path.basename(doc)));const files={};async function collect(dir,prefix){for(const item of await fs.readdir(dir,{withFileTypes:true})){const file=path.join(dir,item.name);if(item.isDirectory())await collect(file,prefix+item.name+'/');else files[prefix+item.name]=new Uint8Array(await fs.readFile(file));}}
await collect(folder,path.basename(folder)+'/');const zip=path.join(root,'release',`Pztk-x-Glyalith-${version}-Windows-x64.zip`);await fs.writeFile(zip,zipCompatible(files));console.log('Windows ZIP:',zip);
