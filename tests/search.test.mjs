import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {findText} from '../core/text-search.mjs';
import {searchSources} from '../core/source-search.mjs';
test('literal search keeps Unicode/CRLF offsets, supports case and whole words and bounds results',()=>{
 const text='😀 x.* = true\r\nПривет приветствие ПРИВЕТ\r\nx.*';assert.deepEqual(findText(text,'x.*').matches.map(m=>[m.start,m.line,m.column]),[[3,1,4],[text.lastIndexOf('x.*'),3,1]]);assert.equal(findText(text,'привет',{wholeWord:true}).matches.length,2);assert.equal(findText(text,'Привет',{matchCase:true}).matches.length,1);assert.equal(findText('foobar foo foo_bar','foo',{wholeWord:true}).matches.length,1);assert.equal(findText('aaa','a',{},2).truncated,true);
});
test('all registered folders search libraries, modules and fresh files once and preserve source',async t=>{
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'pztk-search-'));t.after(()=>fs.rm(dir,{recursive:true,force:true}));const root=path.join(dir,'Addon'),module=path.join(root,'Module');await fs.mkdir(path.join(root,'Libs'),{recursive:true});await fs.mkdir(module);await fs.mkdir(path.join(root,'node_modules'));await fs.writeFile(path.join(root,'Addon.toc'),'Core.lua');await fs.writeFile(path.join(root,'Core.lua'),'-- Needle\nprint("needle")');await fs.writeFile(path.join(root,'Libs','Lib.lua'),'Needle');await fs.writeFile(path.join(module,'Part.lua'),'Needle');await fs.writeFile(path.join(root,'node_modules','skip.lua'),'Needle');await fs.writeFile(path.join(root,'bad.lua'),Buffer.from([0,255]));
 const projects=[{id:'main',name:'Addon',root},{id:'module',name:'Module',root:module}];let result=await searchSources(projects,{query:'Needle'});assert.equal(result.matches,4);assert.equal(result.groups.length,3);assert.equal(result.skippedFiles,1);assert.equal(result.groups.find(g=>g.file==='Part.lua').projectId,'module');assert.equal(await fs.readFile(path.join(root,'Core.lua'),'utf8'),'-- Needle\nprint("needle")');await fs.writeFile(path.join(module,'New.lua'),'Needle');result=await searchSources(projects,{query:'Needle',matchCase:true});assert.equal(result.matches,4);assert.ok(result.groups.some(g=>g.file==='New.lua'));result=await searchSources([projects[1]],{query:'Needle'});assert.equal(result.matches,2);
});
