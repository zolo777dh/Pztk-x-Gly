const {contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('doctor',{call:(method,args)=>ipcRenderer.invoke('doctor:call',method,args),pickFolder:()=>ipcRenderer.invoke('doctor:folder'),exportFile:(name,text)=>ipcRenderer.invoke('doctor:export',{name,text}),openBackups:()=>ipcRenderer.invoke('doctor:backups')});
