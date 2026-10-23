import test from 'node:test';
import assert from 'node:assert/strict';
import {minimumAddonFor} from '../core/reminder-pack.mjs';

const pack=display=>({raidReminders:{3379:{a:{trigger:{type:'pull',delay:10},display}}},scopePresets:{}});

test('NSRT-style look fields raise the minimum addon to 0.6.5',()=>{
 for(const key of['textColor','barColor','ticks','sticky','hideTimer','countdown'])assert.equal(minimumAddonFor(pack({type:'bar',[key]:key==='ticks'?[5]:key==='sticky'?2:key.endsWith('Color')?[1,0,0,1]:true})),'0.6.5',key);
 assert.equal(minimumAddonFor(pack({type:'text',glowTargets:['A']})),'0.3.3');
 assert.equal(minimumAddonFor(pack({type:'text'})),'0.3.0');
});
