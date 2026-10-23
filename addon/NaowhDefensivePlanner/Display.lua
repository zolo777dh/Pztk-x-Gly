local _, ns = ...
local pool, active, serial = {}, {}, 0
local builtins={ ["voice:use-a-defensive"]="use-a-defensive.ogg",["voice:move-out"]="move-out.ogg",["voice:dispel-me"]="dispel-me.ogg",["voice:stoneform-ready"]="stoneform-ready.ogg",["voice:shadowmeld-ready"]="shadowmeld-ready.ogg",["voice:stoneform-preview"]="stoneform-preview.ogg",["voice:shadowmeld-preview"]="shadowmeld-preview.ogg" }
function ns.SoundPath(key)
    if builtins[key]then return "Interface\\AddOns\\NaowhDefensivePlanner\\Media\\Voice\\"..builtins[key]end
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
-- Reminder look follows Naowh Smart Reminders: spell icons in a row and the call-out text
-- beside them. Only countdown bars and reminders with a visible timer redraw while shown.
local function Region()
    local r = table.remove(pool)
    if r then return r end
    r = CreateFrame("Frame", nil, UIParent)
    serial=serial+1;r.glowKey="NaowhDefensivePlanner:"..serial
    r:SetSize(340, 48); r:SetFrameStrata("HIGH")
    r.text = r:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");r.text:SetJustifyH("LEFT");r.text:SetTextColor(1,1,1,1)
    r.text:SetShadowColor(0,0,0,1);r.text:SetShadowOffset(1,-1)
    r.icons = {}
    for i=1,6 do local icon=r:CreateTexture(nil,"ARTWORK");icon:SetSize(42,42);icon:SetPoint("LEFT",(i-1)*46,0);icon:SetTexCoord(0.07,0.93,0.07,0.93);r.icons[i]=icon end
    r.swipe=CreateFrame("Cooldown",nil,r,"CooldownFrameTemplate");r.swipe:SetAllPoints(r.icons[1]);r.swipe:Hide()
    -- Countdown bar (NSRT "Bar" alerts): drains from right to left, ticks mark seconds left.
    r.bar=CreateFrame("StatusBar",nil,r);r.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");r.bar:SetMinMaxValues(0,1);r.bar:Hide()
    r.bar.bg=r.bar:CreateTexture(nil,"BACKGROUND");r.bar.bg:SetAllPoints();r.bar.bg:SetColorTexture(0,0,0,0.55)
    r.ticks={};r.ticker=false;r.voice=false;r.hideSpells=false
    r.clock=r:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");r.clock:SetJustifyH("RIGHT");r.clock:SetShadowColor(0,0,0,1);r.clock:SetShadowOffset(1,-1);r.clock:Hide()
    return r
end
-- Buttons that can show a spell: the Cooldown Manager first, then Blizzard and common action bar addons.
local barNames={"ActionButton","MultiBarBottomLeftButton","MultiBarBottomRightButton","MultiBarRightButton","MultiBarLeftButton","MultiBar5Button","MultiBar6Button","MultiBar7Button","DominosActionButton"}
local function ButtonSpell(button)
    local slot=button.action or(button.GetAttribute and button:GetAttribute("action"))
    if type(slot)=="number"and GetActionInfo then
        local ok,kind,id=pcall(GetActionInfo,slot)
        if ok and ns.Plain(kind,"string")and ns.Plain(id,"number")and(kind=="spell"or kind=="macro")then return id end
    end
end
local function CooldownSpell(item)
    local spell
    if item.GetSpellID then local ok,v=pcall(item.GetSpellID,item);if ok then spell=v end end
    if not ns.Plain(spell,"number")and item.cooldownID and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
        local ok,info=pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo,item.cooldownID)
        if ok and ns.Plain(info,"table")then spell=ns.Plain(info.overrideSpellID,"number")and info.overrideSpellID or info.spellID end
    end
    return ns.Plain(spell,"number")and spell or nil
end
-- Every visible button showing one of the spells; a spell's base and override IDs both match.
function ns.SpellButtons(spells)
    local wanted={}
    for _,spell in ipairs(spells or{})do if type(spell)=="number"then wanted[spell]=true
        if C_Spell and C_Spell.GetOverrideSpell then local ok,o=pcall(C_Spell.GetOverrideSpell,spell);if ok and ns.Plain(o,"number")then wanted[o]=true end end
    end end
    local found={}
    local function add(frame,spell)if spell and wanted[spell]and frame.IsVisible and frame:IsVisible()then found[#found+1]=frame end end
    for _,name in ipairs({"EssentialCooldownViewer","UtilityCooldownViewer"})do
        local viewer=_G[name]
        if viewer then
            local items=viewer.GetItemFrames and viewer:GetItemFrames()or{viewer:GetChildren()}
            for _,item in ipairs(items or{})do add(item,CooldownSpell(item))end
        end
    end
    for _,prefix in ipairs(barNames)do for i=1,12 do local b=_G[prefix..i];if b then add(b,ButtonSpell(b))end end end
    -- Bartender and ElvUI bars are walked only when that addon is loaded.
    if _G.Bartender4 then for i=1,180 do local b=_G["BT4Button"..i];if b then add(b,ButtonSpell(b))end end end
    if _G.ElvUI then for bar=1,15 do for i=1,12 do local b=_G["ElvUI_Bar"..bar.."Button"..i];if b then add(b,ButtonSpell(b))end end end end
    return found
end
local function StopGlow(frame,key)
    local lcg=LibStub("LibCustomGlow-1.0",true);if not lcg then return end
    pcall(lcg.PixelGlow_Stop,frame,key);if lcg.ProcGlow_Stop then pcall(lcg.ProcGlow_Stop,frame,key)end
end
local function Release(index)
    local r=table.remove(active,index);r:Hide();r:SetScript("OnUpdate",nil);if r.timer then r.timer:Cancel();r.timer=nil end
    if r.ticker then r.ticker:Cancel();r.ticker=false end
    for _,t in ipairs(r.voice or{})do t:Cancel()end;r.voice=false;r.hideSpells=false
    r.bar:Hide();r.clock:Hide();for _,t in ipairs(r.ticks)do t:Hide()end
    for _,frame in ipairs(r.glows or {})do StopGlow(frame,r.glowKey)end
    r.glows=nil
    pool[#pool+1]=r
end
-- Reminders grow to the right from a fixed left edge, so one icon sits where the first of two would.
-- Positions saved before 0.6.4 were the center of a 340 px anchor box: its left edge is 170 px to the left.
function ns.ReminderOrigin()
    local s=ns.Settings and ns.Settings()or{};local p=type(s.pos)=="table"and s.pos or{}
    local x,y=tonumber(p.x)or 0,tonumber(p.y)or 100
    if p.point~="LEFT"then x=x-170 end
    return x,y
end
local function Arrange()
    local x,y=ns.ReminderOrigin()
    local offset=0
    for _,r in ipairs(active)do r:ClearAllPoints();r:SetPoint("LEFT",UIParent,"CENTER",x,y-offset);offset=offset+(r.height or 42)+6 end
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
-- Text to speech through the game's own voices. Used by reminders and by "Hear it" buttons.
function ns.Speak(text)
    if type(text)~="string"or text==""or not(C_VoiceChat and C_VoiceChat.GetTtsVoices and C_VoiceChat.SpeakText)then return false end
    local settings=ns.Settings and ns.Settings()or{}
    local ok,voices=pcall(C_VoiceChat.GetTtsVoices)
    if not ok or type(voices)~="table"or not voices[1]then return false end
    local voice=voices[1].voiceID;for _,v in ipairs(voices)do if v.voiceID==settings.voiceID then voice=v.voiceID end end
    return(pcall(C_VoiceChat.SpeakText,voice,text,0,tonumber(settings.voiceVol)or 100,false))
end
function ns.Display(display)
    local settings=ns.Settings and ns.Settings()or{}
    local text=type(display.text)=="string" and display.text or ""
    local spells=display.spells or (display.spellID and {display.spellID}) or {}
    if text=="" and spells[1] and display.type~="chat"then text=Spell(spells[1])end
    local sound=ns.SoundPath(display.sound)
    if sound then pcall(PlaySoundFile,sound,"Master")end
    -- Spoken call-out: the reminder text (spell names for defensives) unless voice is turned off.
    local speak=display.tts;if speak==nil then speak=#spells>0 end
    if speak and settings.voiceOn~=false then ns.Speak(display.ttsText and display.ttsText~="" and display.ttsText or text)end
    if display.type=="chat"then if text~=""then ns.Print(text)end;return end
    if #active>=6 then Release(1)end
    local bar=display.type=="bar"
    local r=Region();local count=(display.type=="text"or settings.showIcon==false)and 0 or math.min(bar and 1 or 6,#spells);if(display.type=="circle"or bar)and count==0 and settings.showIcon~=false and display.spellID then count=1;spells={display.spellID}end
    if display.type=="circle"and count==0 and settings.showIcon~=false then count=1;spells={0}end
    local iconSize=tonumber(settings.iconSize)or 42;local gap=4
    for i,icon in ipairs(r.icons)do if i<=count then local _,texture=Spell(spells[i]);icon:SetSize(iconSize,iconSize);icon:ClearAllPoints();icon:SetPoint("LEFT",r,"LEFT",(i-1)*(iconSize+gap),0);icon:SetTexture(texture or 134400);icon:Show()else icon:Hide()end end
    local font,_,flags=r.text:GetFont();if ns.Widgets then font=ns.Widgets.Font(true)end
    local size=tonumber(settings.textSize)or 18
    if type(font)=="string"then r.text:SetFont(font,size,"OUTLINE");r.clock:SetFont(font,size,"OUTLINE")end
    local tc=GlowColor(display.textColor)or{1,1,1,1};r.text:SetTextColor(tc[1],tc[2],tc[3],tc[4]);r.clock:SetTextColor(tc[1],tc[2],tc[3],tc[4])
    local left=count>0 and count*(iconSize+gap)+(bar and 0 or 6)or 0
    local dur=math.max(0.1,math.min(120,tonumber(display.dur)or 5))
    local sticky=math.max(0,math.min(60,tonumber(display.sticky)or 0))
    -- Seconds left: always on bars unless hidden, on other types only when the countdown is switched on.
    local clock=display.hideTimer~=true and(bar or display.countdown==true)and display.type~="circle"
    r.text:ClearAllPoints()
    if bar then
        local width=math.max(120,tonumber(settings.barWidth)or 240)
        r.bar:ClearAllPoints();r.bar:SetPoint("LEFT",r,"LEFT",left,0);r.bar:SetSize(width,iconSize)
        local bc=GlowColor(display.barColor)or{1,0.55,0.1,1};r.bar:SetStatusBarColor(bc[1],bc[2],bc[3],bc[4]);r.bar:SetValue(1);r.bar:Show()
        local n=0
        for _,t in ipairs(type(display.ticks)=="table"and display.ticks or{})do
            if type(t)=="number"and t>0 and t<dur then
                n=n+1;local mark=r.ticks[n]
                if not mark then mark=r.bar:CreateTexture(nil,"OVERLAY");mark:SetColorTexture(1,1,1,0.9);r.ticks[n]=mark end
                mark:ClearAllPoints();mark:SetSize(2,iconSize);mark:SetPoint("LEFT",r.bar,"LEFT",math.floor(t/dur*width),0);mark:Show()
            end
        end
        for i=n+1,#r.ticks do r.ticks[i]:Hide()end
        r.text:SetPoint("LEFT",r.bar,"LEFT",6,0);r.text:SetText(text)
        r.clock:ClearAllPoints();r.clock:SetPoint("RIGHT",r.bar,"RIGHT",-6,0)
        r.height=iconSize;r:SetSize(left+width,r.height)
    else
        r.text:SetPoint("LEFT",r,"LEFT",left,0);r.text:SetText(text)
        r.clock:ClearAllPoints();r.clock:SetPoint("LEFT",r.text,"RIGHT",6,0)
        local width=r.text.GetStringWidth and r.text:GetStringWidth()or 0;if type(width)~="number"then width=0 end
        r.height=math.max(iconSize,24);r:SetSize(math.max(40,left+width+(clock and size*2 or 0)),r.height)
    end
    if settings.showText==false then r.text:Hide()else r.text:Show()end
    if display.type=="circle"then if r.swipe.SetHideCountdownNumbers then r.swipe:SetHideCountdownNumbers(display.hideTimer==true)end;r.swipe:SetCooldown(GetTime(),dur);r.swipe:Show()else r.swipe:Hide()end;r:Show()
    -- One cheap ticker per bar or visible timer; the text is rewritten only when the whole second changes.
    local ends=GetTime()+dur;local shown
    local function tick()
        local remain=math.max(0,ends-GetTime())
        if bar then r.bar:SetValue(remain/dur)end
        if clock then local s=remain>0 and math.ceil(remain)or nil;if s~=shown then shown=s;r.clock:SetText(s and tostring(s)or"")end end
        if remain<=0 and r.ticker then r.ticker:Cancel();r.ticker=false end
    end
    if clock then r.clock:Show()end
    if(bar or clock)then tick();if C_Timer and C_Timer.NewTicker then r.ticker=C_Timer.NewTicker(bar and 0.05 or 0.2,tick)end end
    r.glows={}
    if display.type=="raidframeGlow"or display.type=="nameplateGlow"then local frame=Glow(display.glowTarget,display.type,r.glowKey);if frame then r.glows[1]=frame else ns.Print("Glow target frame unavailable; showing the reminder instead.")end end
    -- Like NSR: only the called defensive glows, on the player's own Cooldown Manager or action bar button.
    if settings.cdmGlow~=false and count>0 and display.type~="circle"then
        local lcg=LibStub("LibCustomGlow-1.0",true)
        for i=1,count do for _,button in ipairs(ns.SpellButtons({spells[i]}))do
            local started=lcg and lcg.ProcGlow_Start and pcall(lcg.ProcGlow_Start,button,{key=r.glowKey,color={1,0.82,0.2,1}})
            if not started and lcg then started=pcall(lcg.PixelGlow_Start,button,{1,0.82,0.2,1},8,0.25,nil,2,0,0,false,r.glowKey)end
            if started then r.glows[#r.glows+1]=button end
        end end
    end
    -- NSRT glowunit: extra raid frames glow alongside any display type.
    if type(display.glowTargets)=="table"then
        local color=GlowColor(display.glowColor)
        for _,name in ipairs(display.glowTargets)do local frame=Glow(name,"raidframeGlow",r.glowKey,color);if frame then r.glows[#r.glows+1]=frame end end
    end
    -- One timer per reminder instead of a per-frame OnUpdate.
    local function expire()for i,v in ipairs(active)do if v==r then Release(i);Arrange();break end end end
    -- Spoken countdown: the last seconds are read out by the game's text to speech.
    local voice=math.min(10,math.floor(tonumber(display.voiceCountdown)or 0))
    if voice>0 and settings.voiceOn~=false and C_Timer and C_Timer.NewTimer then
        r.voice={};for i=math.min(voice,math.floor(dur)),1,-1 do r.voice[#r.voice+1]=C_Timer.NewTimer(dur-i,function()ns.Speak(tostring(i))end)end
    end
    -- Hide on use: casting one of the shown spells takes the reminder off.
    if display.hideOnUse and count>0 then r.hideSpells={};for i=1,count do if type(spells[i])=="number"then r.hideSpells[spells[i]]=true end end end
    -- Sticky time keeps the reminder up after its countdown runs out.
    if C_Timer and C_Timer.NewTimer then r.timer=C_Timer.NewTimer(dur+sticky,expire)else r.expires=GetTime()+dur+sticky;r:SetScript("OnUpdate",function(self)if GetTime()>=self.expires then expire()end end)end
    active[#active+1]=r;Arrange()
end
function ns.HideSpell(spell)
    if not ns.Plain(spell,"number")then return false end
    local hidden=false
    for i=#active,1,-1 do local r=active[i];if r.hideSpells and r.hideSpells[spell]then Release(i);hidden=true end end
    if hidden then Arrange()end
    return hidden
end
-- Movable anchor: a sample icon exactly where a reminder's first icon appears. Dragging it saves the position.
local anchor
function ns.AnchorsUnlocked()return anchor~=nil and anchor:IsShown()end
local function AnchorSpell()
    local profile,spec=ns.Active and ns.Active(),ns.Spec and ns.Spec()
    local key=profile and ns.ScopeActive and ns.ScopeActive(profile,"mythic",spec)
    local set=key and ns.ScopePresets and ns.Get(ns.ScopePresets(profile,"mythic",spec),key)
    return set and set.list and set.list[1]or 22812
end
function ns.ToggleAnchors()
    if not anchor then
        anchor=CreateFrame("Frame",nil,UIParent);anchor:SetFrameStrata("DIALOG");anchor:SetMovable(true);anchor:EnableMouse(true);anchor:RegisterForDrag("LeftButton");anchor:SetClampedToScreen(true)
        anchor.icon=anchor:CreateTexture(nil,"ARTWORK");anchor.icon:SetAllPoints();anchor.icon:SetTexCoord(0.07,0.93,0.07,0.93)
        anchor.edge={}
        for i,side in ipairs({{"TOPLEFT","TOPRIGHT"},{"BOTTOMLEFT","BOTTOMRIGHT"},{"TOPLEFT","BOTTOMLEFT"},{"TOPRIGHT","BOTTOMRIGHT"}})do
            local t=anchor:CreateTexture(nil,"OVERLAY");t:SetColorTexture(0.2,0.76,0.65,1);t:SetPoint(side[1]);t:SetPoint(side[2]);if i<=2 then t:SetHeight(2)else t:SetWidth(2)end;anchor.edge[i]=t
        end
        anchor.text=anchor:CreateFontString(nil,"OVERLAY","GameFontHighlight");anchor.text:SetPoint("LEFT",anchor,"RIGHT",6,0)
        anchor.text:SetText(ns.L and ns.L("Drag the icon · /ndp anchors locks")or"Drag the icon · /ndp anchors locks")
        anchor:SetScript("OnDragStart",function(self)self:StartMoving()end)
        anchor:SetScript("OnDragStop",function(self)
            self:StopMovingOrSizing();local left=self:GetLeft();local _,y=self:GetCenter();local ux,uy=UIParent:GetCenter()
            if not(left and y and ux)then return end
            local ok,error=ns.EditProfile(function(data)data.settings=data.settings or{};data.settings.pos={point="LEFT",relPoint="CENTER",x=math.floor(left-ux+0.5),y=math.floor(y-uy+0.5)}end)
            if not ok then ns.Print(error)end;if ns.RefreshWorkspace then ns.RefreshWorkspace()end
        end)
        anchor:Hide()
    end
    if anchor:IsShown()then anchor:Hide();return false end
    local settings=ns.Settings and ns.Settings()or{};local size=tonumber(settings.iconSize)or 42
    local _,texture=Spell(AnchorSpell());anchor.icon:SetTexture(texture or 134400);anchor:SetSize(size,size)
    local x,y=ns.ReminderOrigin()
    anchor:ClearAllPoints();anchor:SetPoint("LEFT",UIParent,"CENTER",x,y);anchor:Show();return true
end
