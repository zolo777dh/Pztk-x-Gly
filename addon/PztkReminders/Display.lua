local _, ns = ...
local pool, active, serial = {}, {}, 0
local builtins={ ["voice:use-a-defensive"]="use-a-defensive.ogg",["voice:move-out"]="move-out.ogg",["voice:dispel-me"]="dispel-me.ogg",["voice:stoneform-ready"]="stoneform-ready.ogg",["voice:shadowmeld-ready"]="shadowmeld-ready.ogg",["voice:stoneform-preview"]="stoneform-preview.ogg",["voice:shadowmeld-preview"]="shadowmeld-preview.ogg" }
function ns.SoundPath(key)
    if builtins[key]then return "Interface\\AddOns\\PztkReminders\\Media\\Voice\\"..builtins[key]end
    if type(key)~="string"or key==""or key=="none"then return nil end
    if key:match("^Interface[\\/]")then return key end
    local lsm=LibStub("LibSharedMedia-3.0",true)
    if lsm then local ok,path=pcall(lsm.Fetch,lsm,"sound",key:gsub("^lsm:",""),true);if ok and type(path)=="string"then return path end end
end
local function Spell(spell)
    if type(spell)~="number"or spell<=0 then return "Reminder",134400 end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok,info=pcall(C_Spell.GetSpellInfo,spell)
        if ok and ns.Plain(info,"table") and ns.Plain(info.name,"string") then return info.name,ns.Plain(info.iconID,"number")and info.iconID end
    end
    if GetSpellInfo then local ok,name,_,texture=pcall(GetSpellInfo,spell); if ok and ns.Plain(name,"string") then return name,ns.Plain(texture,"number")and texture end end
    return "Spell " .. tostring(spell), 134400
end
ns.SpellLabel=Spell
local function Region()
    local r = table.remove(pool)
    if r then return r end
    r = CreateFrame("Frame", nil, UIParent)
    serial=serial+1;r.glowKey="PztkReminders:"..serial
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
    local lcg=LibStub("LibCustomGlow-1.0",true)
    for _,frame in ipairs(r.glows or {})do if lcg then pcall(lcg.PixelGlow_Stop,frame,r.glowKey)end end
    r.glows=nil
    pool[#pool+1]=r
end
local function Arrange()
    local s=ns.Settings and ns.Settings()or{};local p=type(s.pos)=="table"and s.pos or{}
    local offset=0
    for _,r in ipairs(active)do r:ClearAllPoints();r:SetPoint(p.point or"CENTER",UIParent,p.relPoint or"CENTER",p.x or 0,(p.y or 100)-offset);offset=offset+(r.height or 60)+6 end
end
function ns.HideDisplays()for i=#active,1,-1 do Release(i)end end
local function GlowUnit(wanted)
    if not ns.Plain(wanted,"string")or wanted==""then return end
    if wanted=="player"or wanted:match("^raid%d+$")or wanted:match("^party%d+$")then
        local exists=UnitExists(wanted)
        if ns.Plain(exists,"boolean")and exists then return wanted end
        return
    end
    for i=0,40 do
        local token=i==0 and "player" or ((IsInRaid and IsInRaid()) and "raid"..i or "party"..i)
        if UnitExists(token) then
            local name,realm
            if UnitFullName then name,realm=UnitFullName(token) end
            if ns.Plain(name)and ns.Plain(realm)then
                name=name or UnitName(token)
                if ns.Plain(name,"string")and (name==wanted or (ns.Plain(realm,"string")and name.."-"..realm:gsub("%s+","")==wanted))then return token end
            end
        end
    end
end
local function GlowColor(color)
    if type(color)~="table"then return end
    local c={}
    for i=1,4 do local v=color[i];if v==nil and i==4 then v=1 end;if type(v)~="number"or v<0 or v>1 then return end;c[i]=v end
    return c
end
local function Glow(wanted,kind,key,color)
    local unit=GlowUnit(wanted)
    local lgf=LibStub("LibGetFrame-1.0",true)
    local ok,frame
    if unit and kind=="nameplateGlow"and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        ok,frame=pcall(C_NamePlate.GetNamePlateForUnit,unit)
        if ok and frame then frame=frame.UnitFrame or frame end
    elseif unit and lgf then ok,frame=pcall(lgf.GetUnitFrame,unit)end
    if ok and frame and LibStub("LibCustomGlow-1.0",true) then
        local started=pcall(LibStub("LibCustomGlow-1.0").PixelGlow_Start,frame,color or {1,0.75,0,1},8,0.25,nil,2,0,0,false,key)
        if started then return frame end
    end
end
function ns.Display(display)
    local settings=ns.Settings and ns.Settings()or{}
    local text=type(display.text)=="string" and display.text or ""
    local spells=display.spells or (display.spellID and {display.spellID}) or {}
    if text=="" and spells[1] and display.type~="chat"then text=Spell(spells[1])end
    local sound=ns.SoundPath(display.sound)
    if sound then pcall(PlaySoundFile,sound,"Master")end
    if display.tts and C_VoiceChat and C_VoiceChat.GetTtsVoices and C_VoiceChat.SpeakText then
        local ok,voices=pcall(C_VoiceChat.GetTtsVoices);local spoken=display.ttsText and display.ttsText~="" and display.ttsText or text
        if ok and voices and voices[1] and spoken~=""and settings.voiceOn~=false then pcall(C_VoiceChat.SpeakText,voices[1].voiceID,spoken,0,settings.voiceVol or 100,false)end
    end
    if display.type=="chat"then if text~=""then ns.Print(text)end;return end
    if #active>=6 then Release(1)end
    local r=Region();local count=(display.type=="text"or settings.showIcon==false)and 0 or math.min(6,#spells);if display.type=="circle"and count==0 and settings.showIcon~=false then count=1;spells={display.spellID or 0}end
    local iconSize=tonumber(settings.iconSize)or 42;r.height=math.max(60,iconSize+16);r:SetSize(math.max(340,count*(iconSize+4)+120),r.height)
    for i,icon in ipairs(r.icons)do if i<=count then local _,texture=Spell(spells[i]);icon:SetSize(iconSize,iconSize);icon:ClearAllPoints();icon:SetPoint("LEFT",8+(i-1)*(iconSize+4),0);icon:SetTexture(texture or 134400);icon:Show()else icon:Hide()end end
    r.text:ClearAllPoints();r.text:SetPoint("TOPLEFT",r,"TOPLEFT",count>0 and (10+(iconSize+4)*count)or 10,-8);r.text:SetPoint("RIGHT",r,"RIGHT",-8,0);r.text:SetText(text)
    if settings.showText==false then r.text:Hide()else r.text:Show()end
    if settings.textSize then local font,_,flags=r.text:GetFont();if type(font)=="string"then r.text:SetFont(font,settings.textSize,flags or"")end end
    local dur=math.max(0.1,math.min(120,tonumber(display.dur)or 5));r.expires=GetTime()+dur;if display.type=="circle"then r.swipe:SetCooldown(GetTime(),dur);r.swipe:Show()else r.swipe:Hide()end;r.bar:SetMinMaxValues(0,dur);r.bar:SetValue(dur);r:Show()
    if settings.showBar==false then r.bar:Hide()else r.bar:Show()end
    r.glows={}
    if display.type=="raidframeGlow"or display.type=="nameplateGlow"then local frame=Glow(display.glowTarget,display.type,r.glowKey);if frame then r.glows[1]=frame else ns.Print("Glow target frame unavailable; showing the reminder instead.")end end
    -- NSRT glowunit: extra raid frames glow alongside any display type.
    if type(display.glowTargets)=="table"then
        local color=GlowColor(display.glowColor)
        for _,name in ipairs(display.glowTargets)do local frame=Glow(name,"raidframeGlow",r.glowKey,color);if frame then r.glows[#r.glows+1]=frame end end
    end
    r:SetScript("OnUpdate",function(self)local left=self.expires-GetTime();if left<=0 then for i,v in ipairs(active)do if v==self then Release(i);Arrange();break end end else self.timer:SetText(string.format("%.1f",left));self.bar:SetValue(left)end end)
    active[#active+1]=r;Arrange()
end
