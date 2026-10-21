local _, ns = ...
local pool, active = {}, {}
local function Spell(spell)
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spell)
    if info and ns.Plain(info.name, "string") then return info.name, ns.Plain(info.iconID) and info.iconID end
    if GetSpellInfo then local name, _, texture = GetSpellInfo(spell); if ns.Plain(name, "string") then return name, ns.Plain(texture) and texture end end
    return "Spell " .. tostring(spell), 134400
end
local function Region()
    local r = table.remove(pool)
    if r then return r end
    r = CreateFrame("Frame", nil, UIParent)
    r:SetSize(340, 60); r:SetFrameStrata("HIGH")
    r.background = r:CreateTexture(nil,"BACKGROUND"); r.background:SetAllPoints(); r.background:SetColorTexture(0.02,0.07,0.12,0.9)
    r.text = r:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); r.text:SetPoint("TOPLEFT",r,"TOPLEFT",60,-7);r.text:SetPoint("RIGHT",r,"RIGHT",-8,0);r.text:SetJustifyH("LEFT")
    r.timer = r:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); r.timer:SetPoint("BOTTOMRIGHT",-8,7)
    r.icons = {}
    for i=1,6 do local icon=r:CreateTexture(nil,"ARTWORK");icon:SetSize(42,42);icon:SetPoint("LEFT",8+(i-1)*46,0);r.icons[i]=icon end
    r.swipe=CreateFrame("Cooldown",nil,r,"CooldownFrameTemplate");r.swipe:SetAllPoints(r.icons[1]);r.swipe:Hide()
    r.bar = CreateFrame("StatusBar",nil,r);r.bar:SetPoint("BOTTOMLEFT",8,6);r.bar:SetPoint("BOTTOMRIGHT",-8,6);r.bar:SetHeight(4);r.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");r.bar:SetStatusBarColor(0,0.6,1)
    return r
end
local function Release(index)
    local r=table.remove(active,index);r:Hide();r:SetScript("OnUpdate",nil)
    if r.glow and LibStub("LibCustomGlow-1.0",true) then LibStub("LibCustomGlow-1.0").PixelGlow_Stop(r.glow);r.glow=nil end
    pool[#pool+1]=r
end
local function Arrange()
    for i,r in ipairs(active)do r:ClearAllPoints();r:SetPoint("CENTER",UIParent,"CENTER",0,100-(i-1)*66)end
end
function ns.HideDisplays()for i=#active,1,-1 do Release(i)end end
local function Glow(display)
    local wanted=display.glowTarget
    if not wanted then return end
    local lgf=LibStub("LibGetFrame-1.0",true)
    local unit
    for i=0,40 do
        local token=i==0 and "player" or ((IsInRaid and IsInRaid()) and "raid"..i or "party"..i)
        if UnitExists(token) then
            local name,realm
            if UnitFullName then name,realm=UnitFullName(token) end
            name=name or UnitName(token)
            if ns.Plain(name) and ns.Plain(realm) and (name==wanted or (name and realm and name.."-"..realm:gsub("%s+","")==wanted)) then unit=token;break end
        end
    end
    local ok,frame
    if unit and lgf then ok,frame=pcall(lgf.GetUnitFrame,unit)end
    if ok and frame and LibStub("LibCustomGlow-1.0",true) then
        LibStub("LibCustomGlow-1.0").PixelGlow_Start(frame,{1,0.75,0,1});return frame
    end
end
function ns.Display(display)
    local text=type(display.text)=="string" and display.text or ""
    local spells=display.spells or (display.spellID and {display.spellID}) or {}
    if text=="" and spells[1] and display.type~="chat"then text=Spell(spells[1])end
    local sound=display.sound
    local builtins={ ["voice:use-a-defensive"]="use-a-defensive.ogg",["voice:move-out"]="move-out.ogg",["voice:dispel-me"]="dispel-me.ogg" }
    if builtins[sound]then sound="Interface\\AddOns\\PztkReminders\\Media\\Voice\\"..builtins[sound]end
    if type(sound)=="string" and sound:match("^Interface[\\/]")then pcall(PlaySoundFile,sound,"Master")
    elseif type(sound)=="string" and sound~="" and sound~="none"then local lsm=LibStub("LibSharedMedia-3.0",true);if lsm then local file=lsm:Fetch("sound",sound:gsub("^lsm:",""),true);if file then pcall(PlaySoundFile,file,"Master")end end end
    if display.tts and C_VoiceChat and C_VoiceChat.GetTtsVoices and C_VoiceChat.SpeakText then
        local voices=C_VoiceChat.GetTtsVoices();local spoken=display.ttsText and display.ttsText~="" and display.ttsText or text
        if voices and voices[1] and spoken~=""then pcall(C_VoiceChat.SpeakText,voices[1].voiceID,spoken,0,100,false)end
    end
    if display.type=="chat"then if text~=""then ns.Print(text)end;return end
    if #active>=6 then Release(1)end
    local r=Region();local count=display.type=="text"and 0 or math.min(6,#spells);if display.type=="circle"and count==0 then count=1;spells={display.spellID or 0}end
    for i,icon in ipairs(r.icons)do if i<=count then local _,texture=Spell(spells[i]);icon:SetTexture(texture or 134400);icon:Show()else icon:Hide()end end
    r.text:ClearAllPoints();r.text:SetPoint("TOPLEFT",r,"TOPLEFT",count>0 and (10+46*count)or 10,-8);r.text:SetPoint("RIGHT",r,"RIGHT",-8,0);r.text:SetText(text)
    local dur=math.max(0.1,math.min(120,tonumber(display.dur)or 5));r.expires=GetTime()+dur;if display.type=="circle"then r.swipe:SetCooldown(GetTime(),dur);r.swipe:Show()else r.swipe:Hide()end;r.bar:SetMinMaxValues(0,dur);r.bar:SetValue(dur);r:Show()
    if display.type=="raidframeGlow"or display.type=="nameplateGlow"then r.glow=Glow(display);if not r.glow then ns.Print("Glow target frame unavailable; showing the reminder instead.")end end
    r:SetScript("OnUpdate",function(self)local left=self.expires-GetTime();if left<=0 then for i,v in ipairs(active)do if v==self then Release(i);Arrange();break end end else self.timer:SetText(string.format("%.1f",left));self.bar:SetValue(left)end end)
    active[#active+1]=r;Arrange()
end
