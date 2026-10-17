import {readSource,walk} from './files.mjs';
import path from 'node:path';

// Narrow compatibility proposal: only the verified call and loaded macro settings.
// This rule never writes to the addon, and never pretends to repair its core loader.
export async function suggestFix(project,file,source,issue,projects=[]){
  const unavailable={replacement:null,explanation:'No verified local repair rule matches this source and error. Use Analyze selected file to review a bounded fragment with your configured model. No files were changed.'};
  if(!issue||!/attempt to call a nil value/i.test(issue.detail||issue.trace||''))return unavailable;
  const pattern=/function CB\.MacrosOn\(\)\s*\r?\n[ \t]*return ns\.ModuleOn\(MACROS_ADDON\)[ \t]*\r?\nend/;
  const match=pattern.exec(source);if(!match)return unavailable;
  const start=source.slice(0,match.index).split('\n').length;
  if(Number(issue.line)<start||Number(issue.line)>start+2)return unavailable;
  if(!/local MACROS_ADDON\s*=\s*["']NaowhForever_Macros["']/.test(source))return unavailable;
  let owner=project;let macrosFile=(await walk(owner.root)).find(f=>/(?:^|\/)Macros\/Macros\.lua$/.test(f));
  if(!macrosFile){const sibling=projects.find(p=>p.id!==project.id&&p.name==='NaowhForever_Utilities'&&path.dirname(p.root)===path.dirname(project.root));if(sibling){const found=(await walk(sibling.root)).find(f=>/(?:^|\/)Macros\/Macros\.lua$/.test(f));if(found){owner=sibling;macrosFile=found;}}}
  if(!macrosFile)return {...unavailable,explanation:'The failing call is ns.ModuleOn(MACROS_ADDON). To verify a compatibility proposal, connect the complete NaowhForever source directory or its sibling NaowhForever_Utilities addon folder containing Macros/Macros.lua, then retry this proposal. Also inspect earlier core-loading errors or mixed addon versions.'};
  const macros=(await readSource(owner.root,macrosFile)).text;
  if(!/function S\.Get\(key\)/.test(macros)||!/Settings\s*=\s*S/.test(macros)||!/ns\.Macros\s*=\s*M/.test(macros))return unavailable;
  const fragment=`function CB.MacrosOn()
    if type(ns.ModuleOn) == "function" then
        return ns.ModuleOn(MACROS_ADDON)
    end
    local macros = ns.Macros
    local settings = macros and macros.Settings
    return settings and type(settings.Get) == "function"
        and settings.Get("enabled") == true or false
end`;
  const eol=source.includes('\r\n')?'\r\n':'\n';
  return {replacement:source.replace(pattern,fragment.replace(/\n/g,eol)),rule:'naowh-consumable-macros-compat',evidence:[file,owner.name+'/'+macrosFile],explanation:'The nil call is the internal ns.ModuleOn function, not a confirmed WoW API removal. This compatibility proposal keeps ModuleOn when available; otherwise it reads the loaded ns.Macros.Settings.Get("enabled") implementation verified in '+owner.name+'/'+macrosFile+'. Without loaded macro settings it returns false. Review the diff and test ConsumableBar in game. This does not repair a failed core loader: check earlier errors and consistent addon versions, especially when the imported log and installed CODE_BUILD differ.'};
}
