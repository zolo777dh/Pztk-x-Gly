import { _electron as electron } from 'playwright-core';
import path from 'node:path';
const root=path.resolve('.');
const app=await electron.launch({executablePath:process.env.DOCTOR_ELECTRON||'./node_modules/electron/dist/electron',args:['--no-sandbox','--disable-gpu','.'],env:{...process.env,DISPLAY:':99',XDG_CONFIG_HOME:path.join(root,'test-results/electron-config'),XDG_CACHE_HOME:path.join(root,'test-results/electron-cache'),XDG_RUNTIME_DIR:path.join(root,'test-results/electron-runtime')},timeout:30000});
try{const page=await app.firstWindow();await page.getByRole('button',{name:'Open disposable demo'}).waitFor();await page.getByRole('button',{name:'Open disposable demo'}).click();await page.getByRole('button',{name:/Lua runtime error.*SetReminder/}).waitFor();await page.screenshot({path:'test-results/electron-desktop.png'});console.log('Electron desktop boot + secured IPC + demo passed');}finally{await app.close();}
