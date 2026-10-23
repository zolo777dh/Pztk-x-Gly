import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { analyze } from '../core/analyzer.mjs';
import { rules } from '../core/api-check.mjs';

async function scan(files,profile='retail'){
  const root=await fs.mkdtemp(path.join(os.tmpdir(),'api-rules-'));
  for(const [name,text] of Object.entries({'Test.toc':'## Interface: 120105\n## Title: Test\nMain.lua\n',...files}))await fs.writeFile(path.join(root,name),text);
  const result=await analyze({root},profile);await fs.rm(root,{recursive:true,force:true});
  return result.issues.filter(i=>i.kind==='api'||i.kind==='interface');
}
const find=(issues,title)=>issues.filter(i=>i.title===title);

test('rule table covers the main groups',()=>{
  assert.equal(rules.globals.GetSpellInfo.group,'removed');
  assert.equal(rules.globals.GetSpellInfo.replacement,'C_Spell.GetSpellInfo');
  assert.equal(rules.globals.UnitAura.group,'removed');
  assert.equal(rules.globals.GetSpecialization.group,'deprecated');
  assert.equal(rules.globals.CombatLogGetCurrentEventInfo.group,'combatlog');
  assert.equal(rules.events.COMBAT_LOG_EVENT_UNFILTERED.severity,'error');
  assert.ok(rules.secret.UnitHealth);
  for(const name of ['C_Spell.GetSpellInfo','UnitHealth','CreateFrame','C_AddOns.IsAddOnLoaded'])assert.equal(rules.globals[name],undefined,name+' must not be flagged');
});

test('direct calls and references to removed globals are errors',async()=>{
  const issues=await scan({'Main.lua':'local name = GetSpellInfo(133)\nlocal cache = UnitAura\nlocal ok = pcall(GetItemInfo, 6948)\n'});
  assert.equal(find(issues,'Removed API: GetSpellInfo')[0].severity,'error');
  assert.equal(find(issues,'Removed API: UnitAura')[0].severity,'error');
  assert.equal(find(issues,'Removed API: GetItemInfo')[0].severity,'warning');
  assert.match(find(issues,'Removed API: GetSpellInfo')[0].detail,/C_Spell\.GetSpellInfo/);
});

test('guarded fallbacks are info only',async()=>{
  const issues=await scan({'Main.lua':[
    'local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded',
    'if GetSpellInfo then local n = GetSpellInfo(1) end',
    'local t = GetSpellTexture and GetSpellTexture(1)',
    'local function f() if not GetSpellLink then return end return GetSpellLink(1) end',
    'local spec = GetSpecialization or C_SpecializationInfo.GetSpecialization'
  ].join('\n')});
  for(const i of issues.filter(i=>i.kind==='api'))assert.equal(i.severity,'info',i.title+' line '+i.line);
  assert.ok(find(issues,'Guarded fallback: GetSpecialization').length);
});

test('locals, fields and polyfills are not the global',async()=>{
  const issues=await scan({'Main.lua':'local GetSpellInfo = function() end\nGetSpellInfo(1)\nlocal ns = {}\nns.UnitAura(1)\nfunction GetItemCount() return 0 end\nGetItemCount()\n'});
  assert.deepEqual(issues.filter(i=>i.kind==='api'),[]);
});

test('combat log, events, methods and lockdown',async()=>{
  const issues=await scan({'Main.lua':[
    'local f = CreateFrame("Frame")',
    'f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")',
    'f:SetScript("OnEvent", function(_, event) if event == "LEARNED_SPELL_IN_TAB" then end local a = CombatLogGetCurrentEventInfo() end)',
    'Minimap:SetBlipTexture("x")',
    'C_ChatInfo.SendAddonMessage("P", "m", "RAID")'
  ].join('\n')});
  assert.equal(find(issues,'Removed event: COMBAT_LOG_EVENT_UNFILTERED')[0].severity,'error');
  assert.equal(find(issues,'Handler for removed event: LEARNED_SPELL_IN_TAB')[0].severity,'info');
  assert.equal(find(issues,'Combat log API unavailable: CombatLogGetCurrentEventInfo')[0].severity,'error');
  assert.equal(find(issues,'Removed method: SetBlipTexture')[0].severity,'warning');
  assert.equal(find(issues,'Messaging blocked in lockdown: C_ChatInfo.SendAddonMessage')[0].severity,'info');
});

test('lockdown note is skipped when the file already checks it',async()=>{
  const issues=await scan({'Main.lua':'if not C_ChatInfo.InChatMessagingLockdown() then C_ChatInfo.SendAddonMessage("P","m","RAID") end\n'});
  assert.equal(find(issues,'Messaging blocked in lockdown: C_ChatInfo.SendAddonMessage').length,0);
});

test('secret values in comparisons and arithmetic',async()=>{
  const issues=await scan({'Main.lua':[
    'if UnitHealth("target") < 100 then end',
    'local cd = C_Spell.GetSpellCooldown(1)',
    'if cd.duration > 0 then end',
    'local hp = UnitHealth("player")',
    'print(hp)'
  ].join('\n')});
  const secret=issues.filter(i=>i.rule==='secret');
  assert.deepEqual(secret.map(i=>[i.line,i.severity]),[[1,'warning'],[3,'warning']]);
  const aware=await scan({'Main.lua':'local hp = UnitHealth("player")\nif not issecretvalue(hp) and hp < 10 then end\n'});
  assert.equal(aware.find(i=>i.rule==='secret').severity,'info');
});

test('TOC below 120000 does not load on Retail',async()=>{
  const issues=await scan({'Test.toc':'## Interface: 110207\nMain.lua\n','Main.lua':''});
  assert.equal(find(issues,'Addon will not load on Retail')[0].severity,'error');
  const forever=await scan({'Test.toc':'## Interface: 16001\nMain.lua\n','Main.lua':'GetSpellInfo(1)\n'},'forever');
  assert.deepEqual(forever,[]);
});
