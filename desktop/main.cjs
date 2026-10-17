const {app,BrowserWindow,ipcMain,dialog,shell}=require('electron');
const path=require('node:path');
let window,service;
app.setName('Pztk x Glyalith');
app.whenReady().then(async()=>{
  const {DoctorService}=await import('../core/service.mjs');
  service=await new DoctorService(path.join(app.getPath('userData'),'workspace'),path.join(app.getAppPath(),'resources')).init();
  window=new BrowserWindow({width:1560,height:980,minWidth:1100,minHeight:720,backgroundColor:'#07101a',title:'Pztk x Glyalith',autoHideMenuBar:true,webPreferences:{preload:path.join(__dirname,'preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true}});
  const entry=path.join(app.getAppPath(),'dist','index.html');
  const permitted=event=>{if(event.sender!==window.webContents||event.senderFrame!==window.webContents.mainFrame)throw Error('Untrusted application frame');const url=new URL(event.senderFrame.url);if(url.protocol!=='file:'||decodeURIComponent(url.pathname).replace(/^\/(\w:)/,'$1')!==entry.replaceAll('\\','/'))throw Error('Untrusted application origin');};
  ipcMain.handle('doctor:call',async(event,method,args)=>{permitted(event);return service.handle(method,args);});
  ipcMain.handle('doctor:folder',async event=>{permitted(event);const result=await dialog.showOpenDialog(window,{title:'Select addon folder',properties:['openDirectory']});return result.canceled?null:result.filePaths[0];});
  ipcMain.handle('doctor:export',async(event,{name,text})=>{permitted(event);if(typeof text!=='string'||text.length>20e6)throw Error('Export exceeds size limit');const result=await dialog.showSaveDialog(window,{defaultPath:path.basename(name)});if(result.canceled)return false;await require('node:fs/promises').writeFile(result.filePath,text,'utf8');return true;});
  ipcMain.handle('doctor:backups',async event=>{permitted(event);await shell.openPath(service.patches.dir);});
  window.webContents.setWindowOpenHandler(()=>({action:'deny'}));
  window.webContents.on('will-navigate',event=>event.preventDefault());
  window.loadFile(entry);
}).catch(error=>{dialog.showErrorBox('Pztk x Glyalith could not start',error.message);app.quit();});
app.on('window-all-closed',()=>app.quit());
