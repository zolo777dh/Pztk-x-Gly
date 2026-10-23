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

-- Icons, text and voice of the chosen abilities: each one has its own text, spoken phrase,
-- voice switch or sound (Defensives page, gear button). Also used by the Test set button.
function ns.DefensiveDisplay(spells,base,bindingSound)
    local settings=ns.Settings()
    local display=Copy(base)
    display.type="icon"
    display.spells,display.spellID=spells,spells[1]
    display.dur=display.dur or settings.lingerSec or 5
    local spoken,labels,sound={},{},nil
    for _,spell in ipairs(spells)do
        local label,phrase,audio,own=ns.Callout(spell)
        labels[#labels+1]=label
        if audio then if phrase then spoken[#spoken+1]=phrase elseif own and not sound then sound=own end end
    end
    local label=table.concat(labels," and ")
    if not display.text or display.text==""then display.text=label
    elseif not display.text:find(label,1,true)then display.text=display.text.."\n"..label end
    display.ttsText=display.ttsText or table.concat(spoken," and ")
    if display.tts==nil then display.tts=settings.voiceOn~=false end
    if settings.voiceOn==false or display.ttsText==""then display.tts=false end
    display.sound=display.sound or bindingSound or sound or(settings.soundOn and settings.soundKey)
    return display
end

-- "Already covered" (NSR coveredSkip): no call-out while a defensive of the set is active on you
-- or was cast within coveredCastWindow seconds. Aura or cast data the game hides counts as not covered.
local lastCast={}
-- Fed by UNIT_SPELLCAST_SUCCEEDED for the player (Main.lua).
function ns.NoteCast(spell)if ns.Plain(spell,"number")then lastCast[spell]=GetTime()end end
function ns.Covered(preset)
    local settings=ns.Settings()
    if settings.coveredSkip~=true or settings.coveredSkipDefaultOn==false or type(preset)~="table"then return false end
    local window=tonumber(settings.coveredCastWindow)or 3
    for _,spell in ipairs(preset.list or{})do
        if lastCast[spell]and GetTime()-lastCast[spell]<=window then return true,spell end
        if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            local ok,aura=pcall(C_UnitAuras.GetPlayerAuraBySpellID,spell)
            if ok and ns.Plain(aura,"table")then return true,spell end
        end
    end
    return false
end

function ns.RenderDefensive(binding, trash)
    local profile,spec=ns.Active(),ns.Spec()
    if not ns.Enabled()or not spec or binding.enabled==false then return end
    local dynamic=binding.defensive
    if dynamic and dynamic.specID~=spec then return end
    local data=profile.data
    local scope=ns.ContentScope and ns.ContentScope(binding)or(trash and"mythic"or"raid")
    local sets=ns.ScopePresets and ns.ScopePresets(profile,scope,spec)or ns.Get(data.presets,spec)
    local active=ns.ScopeActive and ns.ScopeActive(profile,scope,spec)or ns.Get(data.activePreset,spec)
    local key=dynamic and dynamic.preset or binding.preset or active
    local preset=ns.Get(sets,key)
    if trash and not preset and not(binding.display and binding.display.text and binding.display.text~="")then
        preset=ns.Get(sets,active)
    end
    local settings=ns.Settings()
    if trash and(not binding.preset or not preset)and binding.display and binding.display.text and binding.display.text~=""then
        local custom=Copy(binding.display);custom.type=custom.type or"text"
        if custom.tts==nil then custom.tts=settings.voiceOn~=false end
        if settings.voiceOn==false then custom.tts=false end
        if ns.Display then ns.Display(custom)end;return
    end
    if ns.Covered(preset)then return end
    local spells=ns.Pick(preset)
    if #spells==0 then
        local external=binding.external==true or(settings.fallbackOn==true and binding.external~=false)
        if external then ns.CallExternal()end
        return
    end
    local display=ns.DefensiveDisplay(spells,binding.display,binding.sound)
    if ns.Display then ns.Display(display)end
end

-- Text on screen, spoken phrase (nil when the ability uses a sound), voice switch and sound of one ability.
function ns.Callout(spell)
    local data=ns.Active()and ns.Active().data or{}
    local o=ns.Get(data.calloutOptions,spell)or{}
    local name=(ns.SpellLabel and ns.SpellLabel(spell))or("Spell "..spell)
    local label=type(o.label)=="string"and o.label~=""and o.label or name
    local phrase=nil;if o.speak~=false then phrase=ns.Get(data.callouts,spell)or label end
    return label,phrase,o.audio~=false,o.speak==false and o.sound or nil
end
-- Fallback when no own defensive is ready: text, voice and an optional EXTERNAL! line in group chat.
local lastChat=0
function ns.CallExternal(preview)
    local data=ns.Active()and ns.Active().data or{};local settings=ns.Settings()
    local text=data.voiceNone or settings.voiceNone or"Call external"
    if ns.Display then ns.Display({type="text",text=text,dur=settings.lingerSec or 4,tts=settings.voiceOn~=false and settings.externalAudio~=false})end
    if settings.externalChat and not preview and SendChatMessage and GetTime()-lastChat>=3 then
        local channel=IsInRaid and IsInRaid()and"RAID"or IsInGroup and IsInGroup()and"PARTY"or nil
        if channel then lastChat=GetTime();pcall(SendChatMessage,"EXTERNAL!",channel)end
    end
end
