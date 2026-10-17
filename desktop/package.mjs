import packager from '@electron/packager';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {zipSync} from 'fflate';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const paths=await packager({dir:root,name:'Pztk x Glyalith',appVersion:'0.1.0',executableName:'Pztk x Glyalith',platform:'win32',arch:'x64',electronVersion:'38.8.4',out:path.join(root,'release'),overwrite:true,prune:true,asar:false,icon:path.join(root,'resources','icon.ico'),...(process.env.DOCTOR_ELECTRON_ZIPS?{electronZipDir:process.env.DOCTOR_ELECTRON_ZIPS}:{}),ignore:[/^\/(?:\.data|test-results|tests|release|src)(?:\/|$)/,/^\/test-ui.*\.png$/,/^\/vite\.config\.mjs$/,/^\/index\.html$/],win32metadata:{CompanyName:'Pztk x Glyalith',FileDescription:'Pztk x Glyalith — WoW Lua Addon Doctor'}});
const folder=paths[0];await fs.copyFile(path.join(root,'resources','START-HERE.txt'),path.join(folder,'START-HERE.txt'));const files={};async function collect(dir,prefix){for(const item of await fs.readdir(dir,{withFileTypes:true})){const file=path.join(dir,item.name);if(item.isDirectory())await collect(file,prefix+item.name+'/');else files[prefix+item.name]=new Uint8Array(await fs.readFile(file));}}
await collect(folder,path.basename(folder)+'/');const zip=path.join(root,'release','Pztk-x-Glyalith-0.1.0-Windows-x64.zip');await fs.writeFile(zip,zipSync(files,{level:6}));console.log('Windows ZIP:',zip);
