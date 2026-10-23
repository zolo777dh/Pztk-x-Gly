// Capture the actual Lua control tree under the local WoW API harness.
// The PNGs are layout previews, not screenshots of a live WoW client: textures, tex coords,
// vertex colors, draw layers, blend modes and the shipped fonts are emulated in Chromium.
import fs from 'node:fs/promises';import path from 'node:path';import {execFileSync}from 'node:child_process';import {chromium}from 'playwright-core';
const root=path.resolve('addon/NaowhDefensivePlanner'),out=path.resolve('test-results/addon-layout');await fs.mkdir(out,{recursive:true});const harness=await fs.readFile('tests/helpers/wow-workspace.lua','utf8');
const sources=['Runtime','Locale','Catalog','Profiles','Display','RuleRuntime','AuraSounds','Providers','Editor','Import','Widgets','UI','Comms','Debuffs','Notes','Players','RaidTools','Main'];
const prefix=`strmatch=string.match;local env=(function()\n${harness}\nend)();local ns={};\n`+['Libs/LibStub.lua','Libs/LibSerialize.lua','Libs/LibDeflate.lua',...sources.map(x=>x+'.lua')].map(x=>x.startsWith('Libs/')?`dofile(${JSON.stringify(root+'/'+x)})`:`assert(loadfile(${JSON.stringify(root+'/'+x)}))('NaowhDefensivePlanner',ns)`).join('\n')+`\nns.Open();local m=assert(ns.SaveSet('mythic',104,nil,'Magic damage',{{spellID=22812,enabled=true},{spellID=61336,enabled=true},{spellID=200851,enabled=true}}));assert(ns.SaveSet('raid',104,nil,'Raid personal',{{spellID=22812,enabled=true},{spellID=61336,enabled=true}}));\n`;
const scenarios={
 overview:`env.click('tab:overview')`,
 mythic:`env.click('tab:mythic');env.select('group','Altar of Fangs');env.click('entity:270306');env.click('ability:1306517');env.select('rule:preset','Magic damage');env.click('save-rule')`,
 sets:`env.click('tab:mythic');env.click('mode:sets')`,
 raid:`env.click('tab:raid');env.click('new-timed');env.input('rule:name','Personal defensive');env.select('rule:action','Defensive priority set');env.select('rule:preset','Raid personal');env.input('rule:delay','45');env.click('save-rule')`,
 timeline:`env.click('tab:raid');env.click('new-timed');env.input('rule:name','Pull wall');env.input('rule:delay','20');env.click('save-rule');env.click('new-timed');env.input('rule:name','Big add');env.input('rule:delay','95');env.click('save-rule');env.click('tab:timeline')`,
 callout:`env.click('tab:mythic');env.click('mode:sets');env.click('set-callout:1')`,
 debuffs:`assert(ns.AddRacialDebuffs(104,'stoneform'));assert(ns.AddRacialDebuffs(104,'shadowmeld'));env.click('tab:mythic');env.click('mode:debuffs');local r=ns.DebuffRules(104)[1];env.click('debuff:'..r.key)`,
 raiddebuffs:`assert(ns.AddRacialDebuffs(104,'stoneform','raid'));env.click('tab:raid');env.click('mode:debuffs')`,
 notes:`assert(ns.SaveNote('shared',nil,{name='Mythic plan',text='Soak 1: Tester Other\\nKick order: A B C'}));env.click('tab:notes');local id=next(ns.Notes().shared);env.click('note:'..id)`,
 raidtools:`env.click('tab:raidtools')`,players:`env.click('tab:players')`,profiles:`env.click('tab:profiles')`,settings:`env.click('tab:settings')`,diagnostics:`env.click('tab:diag')`};
const serializer=`
local function esc(s)return '"'..tostring(s):gsub('\\\\','\\\\\\\\'):gsub('"','\\\\"'):gsub('\\n','\\\\n'):gsub('\\r','\\\\r')..'"'end
local function json(v)if type(v)=='string'then return esc(v)elseif type(v)=='number'then return tostring(v)elseif type(v)=='boolean'then return tostring(v)elseif type(v)=='table'then local p={};for k,x in pairs(v)do p[#p+1]=esc(k)..':'..json(x)end;return '{'..table.concat(p,',')..'}'else return 'null'end end
local function visible(f)if not f then return true end;if not f.shown then return false end;return visible(f.parent)end
local function rect(f)
 if not f or f==UIParent then return 0,0,1280,800 end
 local p=f.point or{};local px,py,pw,ph=rect(p.relative or f.parent);local w,h=f.w or 0,f.h or 0
 if f.kind=='Text'then h=(f.fontSize or 12)*1.3*(1+select(2,(f.text or''):gsub('\\n',''))) end
 local x,y=px+(p.x or 0),py-(p.y or 0)
 local rp=p.relativePoint or p.point
 if rp=='CENTER'then x=x+pw/2;y=y+ph/2 elseif rp=='RIGHT'then x=x+pw;y=y+ph/2 elseif rp=='BOTTOMLEFT'then y=y+ph elseif rp=='BOTTOMRIGHT'then x=x+pw;y=y+ph elseif rp=='TOPRIGHT'then x=x+pw end
 if p.point=='CENTER'then x=x-w/2;y=y-h/2 elseif p.point=='RIGHT'then x=x-w;y=y-h/2 end
 return x,y,w,h
end
local function level(f)if not f or f==UIParent then return 0 end;return 1+level(f.parent)end
local function clip(f)if not f then return nil end;if f.kind=='ScrollFrame'then local x,y,w,h=rect(f);return {x,y,w,h}end;return clip(f.parent)end
local result={};for i,f in ipairs(env.frames)do if visible(f)and(f.kind=='Texture'or f.kind=='Text'or f.kind=='EditBox')then local x,y,w,h=rect(f)
 result[#result+1]={kind=f.kind,x=x,y=y,w=w,h=h,text=f.text,fontSize=f.fontSize,font=f.font,color=f.textColor,background=f.background,texture=f.texture,vertex=f.vertex,coords=f.coords,layer=f.layer,sublevel=f.sublevel,blend=f.blend,alpha=f.alpha,justify=f.justify,wrap=f.wrap,level=level(f.parent),order=i,clip=clip(f.parent)}end end
local file=assert(io.open(OUTPUT,'wb'));file:write('[');for i,r in ipairs(result)do if i>1 then file:write(',')end;file:write(json(r))end;file:write(']');file:close()
`;
// Decode the shipped TGAs (uncompressed 32-bit) so the preview can draw them.
function readTga(buffer){
 const w=buffer.readUInt16LE(12),h=buffer.readUInt16LE(14),top=(buffer[17]&0x20)!==0,rgba=new Array(w*h*4);
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){const s=18+(y*w+x)*4,d=((top?y:h-1-y)*w+x)*4;rgba[d]=buffer[s+2];rgba[d+1]=buffer[s+1];rgba[d+2]=buffer[s];rgba[d+3]=buffer[s+3];}
 return {width:w,height:h,rgba};
}
const images={};
for(const name of['Logo','UI/Disc','UI/IconMask','UI/Icons'])images[name]=readTga(await fs.readFile(path.join(root,'Media',name+'.tga')));
const font=async f=>'data:font/ttf;base64,'+(await fs.readFile(path.join(root,'Media/Fonts',f))).toString('base64');
const fonts={book:await font('URWGothic-Book.ttf'),demi:await font('URWGothic-Demi.ttf')};
const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
// Convert the textures to PNG data URLs once.
const converter=await browser.newPage();
const urls=await converter.evaluate(images=>{const urls={};for(const [k,img]of Object.entries(images)){const c=document.createElement('canvas');c.width=img.width;c.height=img.height;c.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(img.rgba),img.width,img.height),0,0);urls[k]=c.toDataURL();}return urls},images);await converter.close();
try{for(const [name,scenario]of Object.entries(scenarios).filter(([n])=>!process.env.ONLY||process.env.ONLY.split(',').includes(n))){
 const target=path.join(out,name+'.json'),script=prefix+scenario+'\n'+serializer.replace('OUTPUT',JSON.stringify(target));await fs.writeFile(out+'/capture.lua',script);execFileSync(process.env.DOCTOR_LUA51||'lua5.1',[out+'/capture.lua']);
 const rows=JSON.parse(await fs.readFile(target,'utf8')),page=await browser.newPage({viewport:{width:1160,height:760}});
 await page.setContent(`<html><head><style>@font-face{font-family:UB;src:url(${fonts.book})}@font-face{font-family:UD;src:url(${fonts.demi})}</style></head><body style="margin:0;background:#05070b;font-family:UB"><div id="root" style="position:absolute;left:-60px;top:-30px"></div><div style="position:absolute;bottom:4px;right:10px;color:#5b6b82;font:10px sans-serif">Lua layout harness · not a live WoW client</div></body></html>`);
 await page.evaluate(()=>document.fonts.ready);
 await page.evaluate(([rows,urls])=>{
  const list=o=>o&&[o[1],o[2],o[3],o[4]];for(const r of rows){r.vertex=list(r.vertex);r.coords=list(r.coords);r.color=list(r.color);r.background=list(r.background);r.clip=list(r.clip);}
  const layers={BACKGROUND:0,BORDER:1,ARTWORK:2,OVERLAY:3,HIGHLIGHT:4};const rgba=v=>v?`rgba(${Math.round(v[0]*255)},${Math.round(v[1]*255)},${Math.round(v[2]*255)},${v[3]??1})`:undefined;
  const root=document.getElementById('root');
  for(const r of rows){
   if(r.w<=0&&r.kind!=='Text')continue;
   const d=document.createElement('div');const layer=layers[r.layer]??(r.kind==='Text'?3:2);
   Object.assign(d.style,{position:'absolute',left:r.x+'px',top:r.y+'px',width:r.w+'px',height:r.h+'px',boxSizing:'border-box',zIndex:String(r.level*1000+layer*100+((r.sublevel??0)+8)*5+(r.order%5)),opacity:String(r.alpha??1)});
   if(r.clip){const q=r.clip,top=Math.max(0,q[1]-r.y),left=Math.max(0,q[0]-r.x),bottom=Math.max(0,r.y+r.h-q[1]-q[3]),right=Math.max(0,r.x+r.w-q[0]-q[2]);d.style.clipPath=`inset(${top}px ${right}px ${bottom}px ${left}px)`;}
   if(r.kind==='Text'||r.kind==='EditBox'){
    d.textContent=r.text||'';Object.assign(d.style,{height:'auto',fontSize:(r.fontSize||12)+'px',lineHeight:'1.2',color:rgba(r.color)||'#e8eef6',fontFamily:/Demi/.test(r.font||'')?'UD':'UB',whiteSpace:r.wrap===false?'nowrap':'pre-wrap',textOverflow:'ellipsis',textAlign:r.justify==='CENTER'?'center':r.justify==='RIGHT'?'right':'left',overflow:'hidden',maxHeight:r.kind==='EditBox'?r.h+'px':undefined});
    if(r.kind==='EditBox')d.style.zIndex=String(r.level*1000+390);
   }else{
    const file=typeof r.texture==='string'?r.texture.replace(/^Interface\\AddOns\\NaowhDefensivePlanner\\Media\\/,'').replace(/\\/g,'/'):null;const img=file&&urls[file];
    const tint=rgba(r.vertex||[1,1,1,1]);const c=r.coords||[0,1,0,1];
    if(r.background){d.style.background=rgba(r.background);}
    else if(img){
     const bw=r.w/(c[1]-c[0]),bh=r.h/(c[3]-c[2]);const size=`${bw}px ${bh}px`,pos=`${-c[0]*bw}px ${-c[2]*bh}px`;
     if(file==='Logo'||r.blend==='ADD'){d.style.backgroundImage=`url(${img})`;d.style.backgroundSize=size;d.style.backgroundPosition=pos;}
     else{d.style.background=tint;d.style.webkitMaskImage=`url(${img})`;d.style.webkitMaskSize=size;d.style.webkitMaskPosition=pos;d.style.webkitMaskRepeat='no-repeat';}
    }else if(typeof r.texture==='string'&&/WHITE8X8/.test(r.texture))d.style.background=tint;
    else if(typeof r.texture==='number'){d.style.background='linear-gradient(135deg,#7a5b2e,#2f4a63)';d.style.borderRadius='6px';d.style.boxShadow='inset 0 0 0 1px rgba(255,255,255,.15)';}
    else continue;
    if(r.blend==='ADD')d.style.mixBlendMode='screen';
   }
   root.append(d);
  }
 },[rows,urls]);
 await page.screenshot({path:out+'/'+name+'.png'});await page.close();console.log('Captured',name);
}}finally{await browser.close();}
