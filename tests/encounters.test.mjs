import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {parseReference} from '../core/encounters.mjs';
const htmlFile=new URL('../resources/demo/holy_paladin_priority_presets_EN.html',import.meta.url);
test('supplied HTML is parsed as data: 6 presets, 59 assignments, 119 pulls',async()=>{const reference=parseReference(await fs.readFile(htmlFile,'utf8'),'holy_paladin_priority_presets_EN.html');assert.equal(reference.presets.length,6);assert.equal(reference.assignments.length,59);assert.equal(reference.packs.length,119);assert.equal(reference.missing.length,2);assert.match(reference.warning,/No recorded press times/);});
test('HTML scripts and event handlers are not executed',()=>{global.__doctorExecuted=false;const value=parseReference('<title>Reference</title><h1 onclick="global.__doctorExecuted=true">Title</h1><script>global.__doctorExecuted=true</script><table><tr><td>safe</td></tr></table>');assert.equal(global.__doctorExecuted,false);assert.equal(value.kind,'static-html');assert.deepEqual(value.tables,[[['safe']]]);});
