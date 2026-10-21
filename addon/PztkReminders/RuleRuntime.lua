local _, ns = ...

function ns.Settings()
    local profile=ns.Active()
    return profile and profile.data.settings or {}
end

function ns.Enabled()
    return ns.Active()~=nil and ns.Settings().enabled~=false and not ns.Conflict()
end
function ns.ProviderSelected(name)
    local source=ns.Settings().bossSource
    return not source or source==name
end

function ns.CounterMatches(groups, number)
    if not groups or not next(groups) then return true end
    for _,group in ipairs(groups)do
        local match=true
        for _,p in ipairs(group)do
            local ok=(p.op=="="and number==p.value)or(p.op=="!"and number~=p.value)
                or(p.op==">"and number>p.value)or(p.op=="<"and number<p.value)
                or(p.op==">="and number>=p.value)or(p.op=="<="and number<=p.value)
            if not ok then match=false;break end
        end
        if match then return true end
    end
    return false
end

local function Copy(source)
    local out={};for key,value in pairs(source or {})do out[key]=value end;return out
end

function ns.RenderDefensive(binding, trash)
    local profile,spec=ns.Active(),ns.Spec()
    if not ns.Enabled()or not spec or binding.enabled==false then return end
    local dynamic=binding.defensive
    if dynamic and dynamic.specID~=spec then return end
    local data=profile.data
    local sets=ns.Get(data.presets,spec)
    local key=dynamic and dynamic.preset or binding.preset or ns.Get(data.activePreset,spec)
    local preset=ns.Get(sets,key)
    if trash and not preset and not(binding.display and binding.display.text and binding.display.text~="")then
        preset=ns.Get(sets,ns.Get(data.activePreset,spec))
    end
    local spells=ns.Pick(preset)
    local settings=ns.Settings()
    if #spells==0 then
        local external=binding.external==true or(settings.fallbackOn==true and binding.external~=false)
        if external and ns.Display then ns.Display({type="text",text=data.voiceNone or settings.voiceNone or "Call external",dur=settings.lingerSec or 4,tts=settings.voiceOn==true})end
        return
    end
    local display=Copy(binding.display)
    display.type=display.type or "icon"
    display.spells,display.spellID=spells,spells[1]
    display.dur=display.dur or settings.lingerSec or 5
    local callouts={}
    for _,spell in ipairs(spells)do callouts[#callouts+1]=ns.Get(data.callouts,spell)or(ns.SpellLabel and ns.SpellLabel(spell))or("Spell "..spell)end
    local spoken=table.concat(callouts," and ")
    if not display.text or display.text==""then display.text=spoken end
    display.ttsText=display.ttsText or spoken
    if display.tts==nil then display.tts=settings.voiceOn==true end
    if settings.voiceOn==false then display.tts=false end
    display.sound=display.sound or binding.sound or(settings.soundOn and settings.soundKey)
    if ns.Display then ns.Display(display)end
end
