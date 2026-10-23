-- Quality of life, like the NSRT QoL page: a movable text display for short notices (gateway, boss
-- reset, loot, consumables, ready check), spell IDs in tooltips, auto-repair and guild invites.
-- Each notice listens to its events only while it is switched on.
local _,ns=...
local W=ns.Widgets
local C=W.colors
local L=ns.L
local kit=ns.UIKit

local defaults={textSize=22,outline="OUTLINE",pos={x=0,y=220},gateway=false,resetBoss=false,loot=false,
    soulwell=false,feast=false,cauldron=false,repairBot=false,vantus=false,missingBuffs=false,readyCheck=false,
    tooltipIDs=false,autoRepair=false,guildRepair=false,acceptGuild=false}
function ns.QoL()
    local store=ns.Store();store.qol=store.qol or{}
    local q=store.qol;for k,v in pairs(defaults)do if q[k]==nil then q[k]=type(v)=="table"and ns.Clone(v)or v end end
    return q
end
---------------------------------------------------------------------------
-- Text display: up to five short lines, one per notice, each with its own timer.
local frame
local lines,order={},{}
local function Arrange()
    if not frame then return end
    local q=ns.QoL();local size=tonumber(q.textSize)or 22;local font=ns.Widgets.Font and ns.Widgets.Font(true)
    local y,shown=0,0
    for _,key in ipairs(order)do local line=lines[key]
        if line and line.text then
            if type(font)=="string"then line.fs:SetFont(font,size,q.outline~="NONE"and q.outline or"")end
            line.fs:ClearAllPoints();line.fs:SetPoint("TOP",frame,"TOP",0,-y);line.fs:SetText(line.text);line.fs:Show()
            y=y+size+6;shown=shown+1
        elseif line then line.fs:Hide()end
    end
    frame:SetSize(420,math.max(size+6,y))
    if shown>0 or q.unlocked then frame:Show()else frame:Hide()end
end
local function Frame()
    if frame then return frame end
    local q=ns.QoL()
    frame=CreateFrame("Frame",nil,UIParent);frame:SetFrameStrata("HIGH");frame:SetSize(420,30);frame:SetClampedToScreen(true);frame:SetMovable(true)
    frame:SetPoint("CENTER",UIParent,"CENTER",tonumber(q.pos.x)or 0,tonumber(q.pos.y)or 220)
    frame.bg=frame:CreateTexture(nil,"BACKGROUND");frame.bg:SetAllPoints();frame.bg:SetColorTexture(0,0.6,1,0.25);frame.bg:Hide()
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",function(self)if ns.QoL().unlocked then self:StartMoving()end end)
    frame:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing()
        local x,y=self:GetCenter();local ux,uy=UIParent:GetCenter()
        if type(x)=="number"and type(ux)=="number"then ns.QoL().pos={x=math.floor(x-ux+0.5),y=math.floor(y-uy+0.5)}end
    end)
    frame:Hide();return frame
end
-- Shows text under a key for dur seconds (nil keeps it until cleared); text nil clears the key.
function ns.Notice(key,text,dur,r,g,b)
    Frame()
    local line=lines[key]
    if not line then line={fs=frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")};line.fs:SetShadowColor(0,0,0,1);line.fs:SetShadowOffset(1,-1);lines[key]=line;order[#order+1]=key end
    if line.timer then line.timer:Cancel();line.timer=nil end
    line.text=text;line.fs:SetTextColor(r or 1,g or 0.82,b or 0.2,1)
    if text and dur and C_Timer and C_Timer.NewTimer then line.timer=C_Timer.NewTimer(dur,function()line.timer=nil;line.text=nil;Arrange()end)end
    Arrange()
    return true
end
function ns.NoticeText(key)return lines[key]and lines[key].text end
function ns.UnlockNotices(on)
    local q=ns.QoL();q.unlocked=on==true;Frame()
    frame:EnableMouse(q.unlocked);if q.unlocked then frame.bg:Show()else frame.bg:Hide()end
    ns.Notice("preview",q.unlocked and L("Text display: drag to move")or nil)
    return q.unlocked
end
---------------------------------------------------------------------------
-- Ready check: Vantus rune, missing raid buffs, flask, food and durability for yourself.
local raidBuffs={{1459,"MAGE"},{21562,"PRIEST"},{6673,"WARRIOR"},{1126,"DRUID"},{462854,"SHAMAN"},{381748,"EVOKER"}}
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then local ok,name=pcall(C_Spell.GetSpellName,id);if ok and ns.Plain(name,"string")then return name end end
    if GetSpellInfo then local ok,name=pcall(GetSpellInfo,id);if ok and ns.Plain(name,"string")then return name end end
end
-- Names and IDs of your own buffs, read out of combat only; hidden values are skipped.
local function MyBuffs()
    local names,ids={},{}
    if not(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex)then return names,ids end
    for i=1,80 do
        local ok,aura=pcall(C_UnitAuras.GetAuraDataByIndex,"player",i,"HELPFUL")
        if not ok or not aura then break end
        if ns.Plain(aura,"table")then
            if ns.Plain(aura.name,"string")then names[#names+1]=aura.name end
            if ns.Plain(aura.spellId,"number")then ids[aura.spellId]=true end
        end
    end
    return names,ids
end
local function GroupClasses()
    local classes={}
    local function add(unit)if UnitExists and UnitExists(unit)then local _,class=UnitClass(unit);if ns.Plain(class,"string")then classes[class]=true end end end
    add("player")
    local raid=IsInRaid and IsInRaid();local n=GetNumGroupMembers and GetNumGroupMembers()or 0
    for i=1,raid and n or math.max(0,n-1)do add((raid and"raid"or"party")..i)end
    return classes
end
local function hasName(names,pattern)for _,n in ipairs(names)do if n:find(pattern)then return true end end;return false end
function ns.ReadyCheckProblems()
    local q=ns.QoL();local problems={}
    if InCombatLockdown and InCombatLockdown()then return problems end
    local names,ids=MyBuffs()
    if q.missingBuffs then
        local classes=GroupClasses()
        for _,b in ipairs(raidBuffs)do
            local name=SpellName(b[1])
            if classes[b[2]]and not ids[b[1]]and not(name and hasName(names,"^"..name:gsub("%p","%%%0").."$"))then problems[#problems+1]=L("Missing")..": "..(name or("spell "..b[1]))end
        end
    end
    if q.vantus and IsInRaid and IsInRaid()and not hasName(names,"Vantus")then problems[#problems+1]=L("No Vantus rune")end
    if q.readyCheck then
        if not hasName(names,"Flask")and not hasName(names,"Phial")then problems[#problems+1]=L("No flask")end
        if not hasName(names,"Well Fed")then problems[#problems+1]=L("Not well fed")end
        local low=100
        if GetInventoryItemDurability then for slot=1,18 do local ok,cur,max=pcall(GetInventoryItemDurability,slot);if ok and ns.Plain(cur,"number")and ns.Plain(max,"number")and max>0 then low=math.min(low,math.floor(cur/max*100))end end end
        if low<30 then problems[#problems+1]=L("Low durability")..": "..low.."%"end
    end
    return problems
end
local function ReadyCheck()
    local problems=ns.ReadyCheckProblems()
    if #problems>0 then ns.Notice("readycheck",table.concat(problems,"  ·  "),20,1,0.35,0.3)else ns.Notice("readycheck",nil)end
end
---------------------------------------------------------------------------
-- Consumables put down by a group member, recognised by the spell name, out of combat only.
local consumables={
    {key="soulwell",words={"Soulwell"},text="Soulwell is down"},
    {key="feast",words={"Feast","Banquet","Spread"},text="Feast is down"},
    {key="cauldron",words={"Cauldron"},text="Cauldron is down"},
    {key="repairBot",words={"Jeeves","Repair","Reaves","Auto%-Hammer"},text="Repair bot is down"},
}
local function Consumable(unit,spell)
    if InCombatLockdown and InCombatLockdown()then return end
    if not ns.Plain(unit,"string")or not(unit=="player"or unit:match("^raid%d+$")or unit:match("^party%d+$"))then return end
    local name=ns.Plain(spell,"number")and SpellName(spell);if not name then return end
    local q=ns.QoL()
    for _,c in ipairs(consumables)do if q[c.key]then for _,w in ipairs(c.words)do if name:find(w)then
        local who=UnitName(unit);ns.Notice("consumable",L(c.text)..(ns.Plain(who,"string")and(" ("..who..")")or""),12,0.4,1,0.5);return
    end end end end
end
---------------------------------------------------------------------------
-- Gateway Control Shard is usable only next to a Demonic Gateway.
local SHARD=188152
local function Gateway()
    local usable=false
    local api=C_Item and C_Item.IsUsableItem or IsUsableItem
    if api then local ok,v=pcall(api,SHARD);usable=ok and ns.Plain(v,"boolean")and v or false end
    ns.Notice("gateway",usable and L("Gateway usable")or nil,nil,0.7,0.5,1)
end
local function HasShard()
    local api=C_Item and C_Item.GetItemCount or GetItemCount
    if not api then return false end
    local ok,n=pcall(api,SHARD);return ok and ns.Plain(n,"number")and n>0
end
---------------------------------------------------------------------------
-- After a wipe the boss is not attackable until it resets; say so, and say when it has reset.
local resetTicker
local function WatchReset()
    if resetTicker then resetTicker:Cancel();resetTicker=nil end
    ns.Notice("reset",L("Boss is resetting"),nil,1,0.35,0.3)
    if not(C_Timer and C_Timer.NewTicker)then return end
    local started=GetTime()
    resetTicker=C_Timer.NewTicker(1,function()
        local busy=IsEncounterInProgress and IsEncounterInProgress()
        if not ns.Plain(busy,"boolean")or not busy or GetTime()-started>120 then
            resetTicker:Cancel();resetTicker=nil;ns.Notice("reset",L("Boss has reset"),4,0.4,1,0.5)
        end
    end)
end
---------------------------------------------------------------------------
-- Spell IDs in tooltips: one hook added the first time it is switched on.
local hooked
local function HookTooltips()
    if hooked or not(TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType)then return end
    hooked=true
    local function add(tooltip,data)
        if not ns.QoL().tooltipIDs or not ns.Plain(data,"table")then return end
        local id=data.id;if not ns.Plain(id,"number")then return end
        if tooltip.AddLine then tooltip:AddLine("Spell ID: "..id,0.6,0.8,1)end
    end
    for _,kind in ipairs({"Spell","UnitAura","Macro"})do
        if Enum.TooltipDataType[kind]then pcall(TooltipDataProcessor.AddTooltipPostCall,Enum.TooltipDataType[kind],add)end
    end
end
---------------------------------------------------------------------------
local function Repair()
    if not(CanMerchantRepair and CanMerchantRepair()and GetRepairAllCost and RepairAllItems)then return end
    local cost,can=GetRepairAllCost();if not ns.Plain(cost,"number")or cost<=0 or not can then return end
    local guild=ns.QoL().guildRepair and CanGuildBankRepair and CanGuildBankRepair()
    pcall(RepairAllItems,guild and true or false)
    ns.Print(string.format("Repaired for %dg %ds%s",math.floor(cost/10000),math.floor(cost/100)%100,guild and" (guild bank)"or""))
end
local function GuildInvite(name)
    if not ns.Plain(name,"string")then return end
    local ok,member=false,false
    if C_GuildInfo and C_GuildInfo.MemberExistsByName then ok,member=pcall(C_GuildInfo.MemberExistsByName,name)end
    if ok and member==true and AcceptGroup then
        pcall(AcceptGroup);if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE")end
    end
end
---------------------------------------------------------------------------
local events=CreateFrame("Frame")
local wanted={}
local function want(event,on)
    if(wanted[event]or false)==on then return end
    wanted[event]=on
    if on then pcall(events.RegisterEvent,events,event)elseif events.UnregisterEvent then events:UnregisterEvent(event)end
end
-- Registers only what the switched-on options need; called when an option changes and on login.
function ns.RefreshQoL()
    local q=ns.QoL()
    local combat=InCombatLockdown and InCombatLockdown()
    want("ENCOUNTER_END",q.resetBoss or q.loot)
    want("LOOT_OPENED",q.loot)
    want("READY_CHECK",q.vantus or q.missingBuffs or q.readyCheck)
    want("MERCHANT_SHOW",q.autoRepair)
    want("PARTY_INVITE_REQUEST",q.acceptGuild)
    want("BAG_UPDATE_DELAYED",q.gateway)
    local shard=q.gateway and HasShard()
    want("SPELL_UPDATE_USABLE",shard and true or false)
    if not shard then ns.Notice("gateway",nil)end
    local consume=q.soulwell or q.feast or q.cauldron or q.repairBot
    want("PLAYER_REGEN_DISABLED",consume);want("PLAYER_REGEN_ENABLED",consume)
    want("UNIT_SPELLCAST_SUCCEEDED",consume and not combat or false)
    if q.tooltipIDs then HookTooltips()end
end
local lastGateway=0
events:SetScript("OnEvent",function(_,event,a,b,c,d,e)
    if event=="SPELL_UPDATE_USABLE"then if GetTime()-lastGateway>0.2 then lastGateway=GetTime();Gateway()end
    elseif event=="BAG_UPDATE_DELAYED"then ns.RefreshQoL()
    elseif event=="UNIT_SPELLCAST_SUCCEEDED"then Consumable(a,c)
    elseif event=="PLAYER_REGEN_DISABLED"then want("UNIT_SPELLCAST_SUCCEEDED",false)
    elseif event=="PLAYER_REGEN_ENABLED"then ns.RefreshQoL()
    elseif event=="READY_CHECK"then ReadyCheck()
    elseif event=="MERCHANT_SHOW"then Repair()
    elseif event=="PARTY_INVITE_REQUEST"then GuildInvite(a)
    elseif event=="LOOT_OPENED"then ns.Notice("loot",nil)
    elseif event=="ENCOUNTER_END"then
        local q=ns.QoL()
        if e==1 and q.loot and IsInRaid and IsInRaid()then ns.Notice("loot",L("Loot the boss"),30,0.4,1,0.5)
        elseif e==0 and q.resetBoss then WatchReset()end
    end
end)
local login=CreateFrame("Frame");login:RegisterEvent("PLAYER_LOGIN");login:SetScript("OnEvent",function()ns.RefreshQoL()end)
---------------------------------------------------------------------------
local function DrawQoL(parent)
    local q=ns.QoL()
    local function toggle(card,label,key,y,w)W.Toggle(card,L(label),q[key]==true,12,y,w or 274,function(v)q[key]=v;ns.RefreshQoL()end,"qol:"..key)end
    kit.header(parent,L("Quality of life"),L("Short notices on a movable text line, ready check and convenience. Saved for all characters."))
    local a=W.Card(parent,0,56,298,536,L("Text display"))
    local sizes={};for _,s in ipairs({14,18,22,26,30,36})do sizes[#sizes+1]={value=s,label=tostring(s)}end
    W.Select(a,L("FONT SIZE"),sizes,tonumber(q.textSize)or 22,12,34,130,function(v)q.textSize=v;Arrange();kit.refresh()end,"qol:textSize")
    W.Select(a,L("OUTLINE"),{{value="NONE",label=L("None")},{value="OUTLINE",label=L("Outline")},{value="THICKOUTLINE",label=L("Thick")}},q.outline or"OUTLINE",150,34,136,function(v)q.outline=v;Arrange();kit.refresh()end,"qol:outline")
    W.Button(a,q.unlocked and L("Lock text display")or L("Unlock and preview"),12,92,274,function()ns.UnlockNotices(not q.unlocked);kit.refresh()end,false,"qol-unlock",{align="CENTER"})
    W.Heading(a,L("Notices"),12,138,274)
    toggle(a,"Gateway usable","gateway",160)
    toggle(a,"Boss reset after a wipe","resetBoss",190)
    toggle(a,"Loot the boss after a kill","loot",220)
    W.Heading(a,L("Consumables put down"),12,258,274)
    toggle(a,"Soulwell","soulwell",280);toggle(a,"Feast","feast",310);toggle(a,"Cauldron","cauldron",340);toggle(a,"Repair bot","repairBot",370)
    W.Label(a,L("Recognised by the English spell name, out of combat."),12,404,274,11,C.muted)
    local b=W.Card(parent,310,56,298,536,L("Ready check"))
    toggle(b,"Missing raid buffs","missingBuffs",34)
    toggle(b,"Vantus rune check (raids)","vantus",64)
    toggle(b,"Flask, food and durability","readyCheck",94)
    W.Button(b,L("Check me now"),12,132,274,function()local p=ns.ReadyCheckProblems();ns.Notice("readycheck",#p>0 and table.concat(p,"  ·  ")or L("All good"),10);kit.notify(#p>0 and table.concat(p,", ")or L("Nothing missing"))end,false,"qol-check",{glyph="check",align="CENTER"})
    W.Label(b,L("On a ready check the text display lists what you are missing. Buffs are only expected when a class in the group can give them."),12,176,274,11,C.muted)
    local c=W.Card(parent,620,56,300,536,L("Convenience"))
    toggle(c,"Spell ID in tooltips","tooltipIDs",34,276)
    toggle(c,"Auto-repair at merchants","autoRepair",64,276)
    toggle(c,"Use guild bank for repairs","guildRepair",94,276)
    toggle(c,"Accept guild group invites","acceptGuild",124,276)
    W.Label(c,L("Raid tools has invites, assistants, group sorting and the break timer."),12,166,276,11,C.muted)
end
ns.ExtraPages.qol=DrawQoL
