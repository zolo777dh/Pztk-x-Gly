// Bake the in-game addon's animated and vector media into TGA textures.
// WoW cannot run WebGL, PixiJS, Three.js or GSAP. They run here, in headless
// Chromium, and every frame they draw is saved as a texture or atlas cell that
// Lua plays back with SetTexCoord, alpha and additive blending.
//   CHROMIUM_PATH=/opt/pw-browsers/chromium node tools/bake-addon-media.mjs
import fs from 'node:fs/promises';import path from 'node:path';import {chromium}from 'playwright-core';
const repo=path.resolve('.'),media=path.join(repo,'addon/NaowhDefensivePlanner/Media');
const files={'/three/':'node_modules/three/build/','/pixi/':'node_modules/pixi.js/dist/','/gsap/':'node_modules/gsap/dist/'};
// Uncompressed 32-bit TGA, bottom-left origin: the plainest form the client loads.
function tga(width,height,rgba){
 const out=Buffer.alloc(18+width*height*4);out[2]=2;out.writeUInt16LE(width,12);out.writeUInt16LE(height,14);out[16]=32;out[17]=8;
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){const s=((height-1-y)*width+x)*4,d=18+(y*width+x)*4;out[d]=rgba[s+2];out[d+1]=rgba[s+1];out[d+2]=rgba[s];out[d+3]=rgba[s+3];}
 return out;
}
function readTga(buffer){
 const w=buffer.readUInt16LE(12),h=buffer.readUInt16LE(14),top=(buffer[17]&0x20)!==0,out=new Uint8Array(w*h*4);
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){const s=18+(y*w+x)*4,d=((top?y:h-1-y)*w+x)*4;out[d]=buffer[s+2];out[d+1]=buffer[s+1];out[d+2]=buffer[s];out[d+3]=buffer[s+3];}
 return {width:w,height:h,rgba:out};
}
const logo=readTga(await fs.readFile(path.join(media,'Logo.tga')));
const page_=`<!doctype html><meta charset="utf-8"><body style="margin:0;background:#000">
<script src="/gsap/gsap.min.js"></script>
<script type="module">
import * as THREE from '/three/three.module.js';
import * as PIXI from '/pixi/pixi.mjs';
const LOGO=__LOGO__;
const canvas=(w,h)=>{const c=document.createElement('canvas');c.width=w;c.height=h;return c};
const pixels=c=>Array.from(c.getContext('2d').getImageData(0,0,c.width,c.height).data);
const out={};
// Animated gradient: 64 seamless frames of domain-warped noise (Three.js shader).
{
 const size=128,cols=8,frames=64,atlas=canvas(size*cols,size*cols),ctx=atlas.getContext('2d');
 const renderer=new THREE.WebGLRenderer({preserveDrawingBuffer:true,antialias:false});renderer.setSize(size,size);
 const scene=new THREE.Scene(),camera=new THREE.OrthographicCamera(-1,1,1,-1,0,1);
 const material=new THREE.ShaderMaterial({uniforms:{t:{value:0}},vertexShader:'varying vec2 vUv;void main(){vUv=uv;gl_Position=vec4(position,1.);}',
  fragmentShader:\`precision highp float;varying vec2 vUv;uniform float t;
  vec3 h3(vec3 p){p=vec3(dot(p,vec3(127.1,311.7,74.7)),dot(p,vec3(269.5,183.3,246.1)),dot(p,vec3(113.5,271.9,124.6)));return -1.+2.*fract(sin(p)*43758.5453);}
  float n3(vec3 p){vec3 i=floor(p),f=fract(p),u=f*f*(3.-2.*f);
   return mix(mix(mix(dot(h3(i),f),dot(h3(i+vec3(1,0,0)),f-vec3(1,0,0)),u.x),mix(dot(h3(i+vec3(0,1,0)),f-vec3(0,1,0)),dot(h3(i+vec3(1,1,0)),f-vec3(1,1,0)),u.x),u.y),
              mix(mix(dot(h3(i+vec3(0,0,1)),f-vec3(0,0,1)),dot(h3(i+vec3(1,0,1)),f-vec3(1,0,1)),u.x),mix(dot(h3(i+vec3(0,1,1)),f-vec3(0,1,1)),dot(h3(i+vec3(1,1,1)),f-vec3(1,1,1)),u.x),u.y),u.z);}
  float fbm(vec3 p){float s=0.,a=.5;for(int i=0;i<5;i++){s+=a*n3(p);p*=2.03;a*=.5;}return s;}
  void main(){
   // Moving around a circle in noise space makes frame 64 meet frame 0.
   float a=t*6.2831853;vec3 loop=vec3(cos(a),sin(a),0.)*.55;
   vec2 uv=vUv*2.2;
   vec2 warp=vec2(fbm(vec3(uv,0.)+loop),fbm(vec3(uv+5.2,1.3)+loop));
   float n=fbm(vec3(uv+1.6*warp,2.)+loop*1.3)*.5+.5;
   float m=fbm(vec3(uv*1.4-warp,4.)-loop)*.5+.5;
   vec3 navy=vec3(.03,.09,.2),blue=vec3(0.,.51,.83),orange=vec3(1.,.67,0.);
   vec3 c=navy*smoothstep(.25,.75,n)+blue*pow(smoothstep(.45,.9,n),2.)*.85+orange*pow(smoothstep(.55,.95,m),3.)*.55;
   gl_FragColor=vec4(c,1.);
  }\`});
 scene.add(new THREE.Mesh(new THREE.PlaneGeometry(2,2),material));
 for(let i=0;i<frames;i++){material.uniforms.t.value=i/frames;renderer.render(scene,camera);ctx.drawImage(renderer.domElement,(i%cols)*size,Math.floor(i/cols)*size)}
 out.Aurora={width:atlas.width,height:atlas.height,rgba:pixels(atlas)};
}
// Particles, trail and burst ring (PixiJS with blur filters). Drawn on black
// for additive blending in game.
{
 const app=new PIXI.Application();await app.init({width:256,height:256,background:'#000000',preference:'webgl',preserveDrawingBuffer:true,antialias:true});
 async function snap(build,w,h){
  app.renderer.resize(w,h);app.stage.removeChildren();build(app.stage);app.render();
  const c=canvas(w,h);c.getContext('2d').drawImage(app.canvas,0,0);return {width:w,height:h,rgba:pixels(c)};
 }
 const glowDot=(stage,x,y,r,blur,alpha=1)=>{const g=new PIXI.Graphics().circle(x,y,r).fill({color:0xffffff,alpha});g.filters=[new PIXI.BlurFilter({strength:blur,quality:6})];stage.addChild(g)};
 out.Spark=await snap(s=>{glowDot(s,32,32,14,10,.55);glowDot(s,32,32,7,4,.9);glowDot(s,32,32,3,1,1)},64,64);
 out.Ring=await snap(s=>{const g=new PIXI.Graphics().circle(64,64,50).stroke({color:0xffffff,width:5});g.filters=[new PIXI.BlurFilter({strength:4,quality:6})];s.addChild(g);const c=new PIXI.Graphics().circle(64,64,50).stroke({color:0xffffff,width:1.5});s.addChild(c)},128,128);
 out.Trail=await snap(s=>{
  const grad=new PIXI.FillGradient({type:'linear',start:{x:0,y:0},end:{x:1,y:0},colorStops:[{offset:0,color:'rgba(255,255,255,0)'},{offset:.75,color:'rgba(255,255,255,.55)'},{offset:1,color:'rgba(255,255,255,1)'}]});
  const g=new PIXI.Graphics().roundRect(8,12,236,8,4).fill(grad);g.filters=[new PIXI.BlurFilter({strength:3,quality:6})];s.addChild(g);glowDot(s,240,16,6,4,1);
 },256,32);
 out.Glow=await snap(s=>{glowDot(s,32,32,18,9,1)},64,64);
 app.destroy();
}
// Logo shine: a GSAP timeline drives a light sweep and an orange halo over 32 frames.
{
 const size=64,cols=8,frames=32,atlas=canvas(size*cols,size*4),actx=atlas.getContext('2d');
 const src=canvas(LOGO.width,LOGO.height);src.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(LOGO.rgba),LOGO.width,LOGO.height),0,0);
 const st={sweep:-.6,halo:0};const tl=gsap.timeline({paused:true});
 tl.to(st,{sweep:1.6,duration:.9,ease:'power2.inOut'}).to(st,{halo:1,duration:.35,ease:'sine.out'},.35).to(st,{halo:0,duration:.9,ease:'sine.in'},.7).to({},{duration:.6});
 for(let i=0;i<frames;i++){
  tl.progress(i/frames);const f=canvas(size,size),c=f.getContext('2d');
  c.drawImage(src,4,4,size-8,size-8);
  c.globalCompositeOperation='source-atop';const x=st.sweep*size,g=c.createLinearGradient(x-18,0,x+18,size*.6);
  g.addColorStop(0,'rgba(255,255,255,0)');g.addColorStop(.5,'rgba(255,255,255,.75)');g.addColorStop(1,'rgba(255,255,255,0)');c.fillStyle=g;c.fillRect(0,0,size,size);
  c.globalCompositeOperation='destination-over';c.filter='blur(3px)';c.globalAlpha=st.halo*.9;c.drawImage(src,2,2,size-4,size-4);c.globalAlpha=1;c.filter='none';
  actx.drawImage(f,(i%cols)*size,Math.floor(i/cols)*size);
 }
 out.LogoShine={width:atlas.width,height:atlas.height,rgba:pixels(atlas)};
}
// Vector UI shapes with alpha: a disc for rounded corners, and a 4x8 icon atlas.
{
 const d=canvas(64,64),c=d.getContext('2d');c.fillStyle='#fff';c.beginPath();c.arc(32,32,31.5,0,Math.PI*2);c.fill();out.Disc={width:64,height:64,rgba:pixels(d)};
 const m=canvas(64,64),mc=m.getContext('2d');mc.fillStyle='#fff';mc.beginPath();mc.roundRect(0,0,64,64,12);mc.fill();out.IconMask={width:64,height:64,rgba:pixels(m)};
 const icons=[
  ['M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z'],
  ['M10.5 13.5a4 4 0 1 1-5.66 5.66 4 4 0 0 1 5.66-5.66zM10.5 13.5L20 4M16 8l2.5 2.5M18.5 5.5L21 8'],
  ['M4 21V9h3V5h3v4h4V5h3v4h3v12zM10 21v-5h4v5'],
  ['M12 2l8 3v6c0 5-3.4 9.3-8 11-4.6-1.7-8-6-8-11V5l8-3zM8.5 12l2.5 2.5 4.5-5'],
  ['M6 3h9l4 4v14H6zM14 3v5h5M9 13h7M9 17h5'],
  ['M5 4h14a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2zM8 20h8M12 16v4'],
  ['M7 4v16M3 8l4-4 4 4M17 20V4M13 16l4 4 4-4'],
  ['M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6zM12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1M12 6a6 6 0 1 0 0 12 6 6 0 0 0 0-12z'],
  ['M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM20 20l-3.5-3.5'],
  ['M6 6l12 12M18 6L6 18'],
  ['M6 9l6 6 6-6'],
  ['M12 5v14M5 12h14'],
  ['M5 12l5 5 9-10'],
  ['M8 5l11 7-11 7z','fill'],
  ['M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 7v5l3 2'],
  ['M9 6h11M9 12h11M9 18h11M4.5 6h.01M4.5 12h.01M4.5 18h.01'],
  ['M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.94 1.94 0 0 0 3.4 0'],
  ['M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8z'],
  ['M9 11l3 3 8-8M20 12v6a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h9'],
  ['M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 0 0 5.4-5.4l-2.5 2.5-2.4-.6-.6-2.4z'],
  ['M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM22 21v-2a4 4 0 0 0-3-3.9M16 3.1a4 4 0 0 1 0 7.8'],
  ['M22 12h-4l-3 9L9 3l-3 9H2'],
  ['M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5'],
  ['M12 3a2 2 0 1 0 0 4 2 2 0 0 0 0-4zM12 7v14M5 12H3a9 9 0 0 0 18 0h-2M8 10h8'],
  ['M4 20h4L19 9l-4-4L4 16zM13.5 6.5l4 4'],
  ['M3 12a9 9 0 1 0 3-6.7L3 8M3 3v5h5'],
  ['M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3'],
  ['M6 15l6-6 6 6'],
  ['M9 9h11v11H9zM5 15H4V4h11v1'],
  ['M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12zM12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z'],
  ['M12 3L2 20h20zM12 10v4M12 17h.01'],
  ['M12 2v4M12 18v4M2 12h4M18 12h4M5 5l2.5 2.5M16.5 16.5L19 19M5 19l2.5-2.5M16.5 7.5L19 5'],
 ];
 const a=canvas(256,512),x=a.getContext('2d');x.strokeStyle='#fff';x.fillStyle='#fff';x.lineWidth=2;x.lineCap='round';x.lineJoin='round';
 icons.forEach(([p,mode],i)=>{x.save();x.translate((i%4)*64+8,Math.floor(i/4)*64+8);x.scale(2,2);const path=new Path2D(p);if(mode==='fill')x.fill(path);else x.stroke(path);x.restore()});
 out.Icons={width:256,height:512,rgba:pixels(a)};
}
window.__baked=out;
</script>`;
const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/opt/pw-browsers/chromium',headless:true,args:['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
try{
 const page=await browser.newPage();page.on('pageerror',e=>console.error('page error:',e.message));page.on('console',m=>{if(m.type()==='error')console.error(m.text())});
 await page.route('http://bake.local/**',async route=>{
  const url=new URL(route.request().url());
  if(url.pathname==='/')return route.fulfill({contentType:'text/html',body:page_.replace('__LOGO__',JSON.stringify({width:logo.width,height:logo.height,rgba:Array.from(logo.rgba)}))});
  const prefix=Object.keys(files).find(p=>url.pathname.startsWith(p));if(!prefix)return route.fulfill({status:404,body:''});
  return route.fulfill({contentType:url.pathname.endsWith('.js')||url.pathname.endsWith('.mjs')?'text/javascript':'application/octet-stream',body:await fs.readFile(path.join(repo,files[prefix],url.pathname.slice(prefix.length)))});
 });
 await page.goto('http://bake.local/');await page.waitForFunction(()=>window.__baked,null,{timeout:120000});
 const baked=await page.evaluate(()=>window.__baked);
 await fs.mkdir(path.join(media,'Anim'),{recursive:true});await fs.mkdir(path.join(media,'UI'),{recursive:true});
 const places={Aurora:'Anim',Spark:'Anim',Ring:'Anim',Trail:'Anim',Glow:'Anim',LogoShine:'Anim',Disc:'UI',IconMask:'UI',Icons:'UI'};
 for(const [name,image]of Object.entries(baked)){const file=path.join(media,places[name],name+'.tga');await fs.writeFile(file,tga(image.width,image.height,image.rgba));console.log('Baked',path.relative(repo,file),image.width+'x'+image.height)}
}finally{await browser.close()}
