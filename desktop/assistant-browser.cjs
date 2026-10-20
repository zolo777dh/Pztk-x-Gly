const {WebContentsView,ipcMain}=require('electron');
const sites={chatgpt:'https://chatgpt.com/',claude:'https://claude.ai/'};
function installAssistantBrowser(window,permitted){
 const views=new Map();let active=null;
 const https=url=>{try{const u=new URL(url);return u.protocol==='https:'&&!u.username&&!u.password;}catch{return false;}};
 function hide(){if(active){window.contentView.removeChildView(active.view);active=null;}}
 function bounds(input){const area=window.getContentBounds(),x=Math.max(0,Math.floor(Number(input?.x)||0)),y=Math.max(0,Math.floor(Number(input?.y)||0)),width=Math.min(area.width-x,Math.floor(Number(input?.width)||0)),height=Math.min(area.height-y,Math.floor(Number(input?.height)||0));if(width<100||height<100)throw Error('Assistant panel is too small');return {x,y,width,height};}
 ipcMain.handle('doctor:browser',async(event,{action,provider,rect}={})=>{permitted(event);
  if(action==='hide'){hide();return true;}
  if(action==='status')return active?{provider:active.provider,url:active.view.webContents.getURL(),loading:active.view.webContents.isLoading(),error:active.error||''}:null;
  if(action==='resize'){if(active)active.view.setBounds(bounds(rect));return true;}
  if(action!=='open'||!Object.hasOwn(sites,provider))throw Error('Choose ChatGPT or Claude');
  let record=views.get(provider);
  if(!record){
   const view=new WebContentsView({webPreferences:{partition:'persist:pztk-assistant-'+provider,nodeIntegration:false,contextIsolation:true,sandbox:true,webSecurity:true,allowRunningInsecureContent:false}});record={provider,view,error:''};views.set(provider,record);
   const session=view.webContents.session;session.setPermissionRequestHandler((_wc,_permission,callback)=>callback(false));session.setPermissionCheckHandler(()=>false);
   view.webContents.on('will-navigate',(e,url)=>{if(!https(url))e.preventDefault();});
   view.webContents.setWindowOpenHandler(details=>https(details.url)?{action:'allow',overrideBrowserWindowOptions:{parent:window,width:900,height:760,autoHideMenuBar:true,webPreferences:{partition:'persist:pztk-assistant-'+provider,preload:undefined,nodeIntegration:false,contextIsolation:true,sandbox:true}}}:{action:'deny'});
   view.webContents.on('did-create-window',popup=>{popup.webContents.on('will-navigate',(e,url)=>{if(!https(url))e.preventDefault();});popup.webContents.setWindowOpenHandler(()=>({action:'deny'}));});
   view.webContents.on('did-fail-load',(_event,code,description,_url,isMainFrame)=>{if(isMainFrame&&code!==-3)record.error=description;});
   // Loading remote content never receives the app preload, filesystem bridge or context.
   view.webContents.loadURL(sites[provider]).catch(error=>{record.error=error.message;});
  }
  if(active!==record){hide();window.contentView.addChildView(record.view);active=record;}
  record.view.setBounds(bounds(rect));return {provider,url:sites[provider]};
 });
 window.on('closed',()=>{for(const {view}of views.values())if(!view.webContents.isDestroyed())view.webContents.close();views.clear();});
 return {hide};
}
module.exports={installAssistantBrowser};
