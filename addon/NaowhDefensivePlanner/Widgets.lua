-- Original lightweight controls. No settings framework or source-addon UI dependency.
local _,ns=...
local W={};ns.Widgets=W;ns.UIControls={};ns.UIScrolls={}
-- Palette taken from the addon logo: navy ground, blue for selection, orange for actions.
W.colors={
    background={0.02,0.043,0.08,0.97},sidebar={0.027,0.055,0.1,1},panel={0.039,0.075,0.13,1},raised={0.055,0.1,0.17,1},hover={0.075,0.135,0.22,1},
    line={0.11,0.18,0.28,1},lineStrong={0.2,0.3,0.44,1},
    accent={0.12,0.6,0.92,1},accentSoft={0.04,0.2,0.36,1},brand={1,0.67,0,1},brandDark={0.96,0.56,0,1},
    text={0.9,0.94,0.98,1},muted={0.56,0.66,0.78,1},dark={0.02,0.04,0.08,1},
    warning={1,0.62,0.3,1},danger={0.95,0.45,0.45,1},dangerLine={0.42,0.16,0.18,1},ok={0.35,0.85,0.5,1}
}
W.logo="Interface\\AddOns\\NaowhDefensivePlanner\\Media\\Logo"
-- WoW frames cannot be destroyed. Reuse dynamic controls across redraws.
local framePools,fontPool,texturePool={},{},{}
function W.Begin()
    W.building=true;W.fontIndex=0;W.textureIndex=0
    for _,pools in pairs(framePools)do for _,pool in pairs(pools)do pool.index=0;for _,f in ipairs(pool)do f:Hide()end end end
    for _,f in ipairs(fontPool)do f:Hide()end;for _,t in ipairs(texturePool)do t:Hide()end
end
function W.Finish()
    W.building=false
    for key,s in pairs(ns.UIScrolls)do s:UpdateScrollChildRect();s:SetVerticalScroll(W.scrollPositions and W.scrollPositions[key]or 0)end
end
function W.AttachScrollChild(scroll,child)
    scroll:SetScrollChild(child);child:ClearAllPoints();child:SetPoint("TOPLEFT",scroll,"TOPLEFT",0,0)
    local level=scroll.GetFrameLevel and scroll:GetFrameLevel();if type(level)=="number"then child:SetFrameLevel(level+1)end
    child:Show()
end
function W.Frame(kind,unused,parent,template)
    if not W.building then return CreateFrame(kind,nil,parent,template)end
    -- A ScrollFrame retains its scroll child. Never recycle that child into a
    -- different parent while the old ScrollFrame still owns it.
    local pools=framePools[parent];if not pools then pools={};framePools[parent]=pools end
    local key=kind..":"..(template or"");local pool=pools[key]or{index=0};pools[key]=pool;pool.index=pool.index+1
    local f=pool[pool.index];if not f then f=CreateFrame(kind,nil,parent,template);pool[pool.index]=f else
        f:SetParent(parent);f:ClearAllPoints()
        for _,event in ipairs({"OnClick","OnEnter","OnLeave","OnEscapePressed","OnEnterPressed","OnTextChanged","OnKeyDown","OnUpdate","OnEditFocusGained","OnEditFocusLost"})do if f:HasScript(event)then f:SetScript(event,nil)end end
    end
    local level=parent and parent.GetFrameLevel and parent:GetFrameLevel();if type(level)=="number"then f:SetFrameLevel(level+1)end
    f:Show();return f
end
local function Font(parent)
    if not W.building then return parent:CreateFontString(nil,"OVERLAY")end
    W.fontIndex=W.fontIndex+1;local f=fontPool[W.fontIndex]
    if not f then f=parent:CreateFontString(nil,"OVERLAY");fontPool[W.fontIndex]=f else f:SetParent(parent);f:ClearAllPoints()end;f:Show();return f
end
local function Texture(parent)
    if not W.building then return parent:CreateTexture(nil,"ARTWORK")end
    W.textureIndex=W.textureIndex+1;local t=texturePool[W.textureIndex]
    if not t then t=parent:CreateTexture(nil,"ARTWORK");texturePool[W.textureIndex]=t else t:SetParent(parent);t:ClearAllPoints()end
    t:SetTexCoord(0,1,0,1);t:SetVertexColor(1,1,1,1);t:Show();return t
end
local font=STANDARD_TEXT_FONT or"Fonts\\FRIZQT__.TTF"
local function register(control,key)if key then ns.UIControls[key]=control end;return control end
local function backdrop(f,color,border)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(unpack(color or W.colors.panel));f:SetBackdropBorderColor(unpack(border or W.colors.line))
end
function W.Panel(parent,x,y,w,h,color,border)
    local f=W.Frame("Frame",nil,parent,"BackdropTemplate");f:SetPoint("TOPLEFT",x,-y);f:SetSize(w,h);backdrop(f,color,border);return f
end
function W.Rect(parent,x,y,w,h,color)
    local t=Texture(parent);t:SetPoint("TOPLEFT",x,-y);t:SetSize(w,h);t:SetColorTexture(unpack(color or W.colors.line));return t
end
function W.Label(parent,text,x,y,w,size,color)
    local label=Font(parent);label:SetFont(font,size or 12,"");label:SetPoint("TOPLEFT",x,-y);label:SetWidth(w or 200);label:SetJustifyH("LEFT");label:SetTextColor(unpack(color or W.colors.text));label:SetText(text or"");return label
end
-- A small uppercase section caption with a hairline under it.
function W.Heading(parent,text,x,y,w)
    W.Label(parent,text,x,y,w,10,W.colors.muted);W.Rect(parent,x,y+15,w,1,W.colors.line)
end
function W.Texture(parent,file,x,y,w,h)
    local t=Texture(parent);t:SetSize(w,h);t:SetPoint("TOPLEFT",x,-y);t:SetTexture(file);return t
end
function W.SpellTexture(spell)
    local icon=134400
    if type(spell)=="number"and C_Spell and C_Spell.GetSpellTexture then local ok,v=pcall(C_Spell.GetSpellTexture,spell);if ok and ns.Plain(v,"number")then icon=v end end
    return icon
end
function W.Icon(parent,spell,x,y,size)
    local texture=W.Texture(parent,W.SpellTexture(spell),x,y,size or 24,size or 24)
    -- Trim the default icon border so icons read as clean tiles.
    texture:SetTexCoord(0.07,0.93,0.07,0.93);return texture
end
-- Count pill. Empty or zero counts draw nothing.
function W.Badge(parent,text,x,y,color,textColor)
    if text==nil or text==""or text==0 then return end
    text=tostring(text);local w=math.max(20,#text*7+10)
    local p=W.Panel(parent,x-w,y,w,18,color or W.colors.accentSoft,color or W.colors.accentSoft)
    local l=W.Label(p,text,0,3,w,10,textColor or W.colors.accent);l:SetJustifyH("CENTER");return p
end
local styles={
    normal={bg="raised",border="line",text="text",selectedBg="accentSoft",selectedBorder="accent",selectedText="text"},
    primary={bg="brand",border="brand",text="dark",selectedBg="brand",selectedBorder="brand",selectedText="dark"},
    ghost={bg="panel",border="panel",text="muted",selectedBg="accentSoft",selectedBorder="accentSoft",selectedText="text"},
    danger={bg="panel",border="dangerLine",text="danger",selectedBg="panel",selectedBorder="danger",selectedText="danger"},
    nav={bg="sidebar",border="sidebar",text="muted",selectedBg="hover",selectedBorder="hover",selectedText="text"},
}
-- opts: kind (normal|primary|ghost|danger|nav), h, icon (spell ID), texture (file), badge, align.
function W.Button(parent,text,x,y,w,callback,selected,key,opts)
    opts=opts or{};local style=styles[opts.kind or"normal"];local c=W.colors;local h=opts.h or 30
    local b=W.Frame("Button",nil,parent,"BackdropTemplate");b:SetPoint("TOPLEFT",x,-y);b:SetSize(w,h)
    local bg,border=c[selected and style.selectedBg or style.bg],c[selected and style.selectedBorder or style.border]
    backdrop(b,bg,border)
    local left=9
    if selected and(opts.kind=="nav"or opts.marker)then W.Rect(b,0,0,3,h,c.accent)end
    if opts.icon or opts.texture then local size=math.min(h-10,22);if opts.texture then W.Texture(b,opts.texture,8,(h-size)/2,size,size)else W.Icon(b,opts.icon,8,(h-size)/2,size)end;left=8+size+8 end
    local right=opts.badge and opts.badge~=""and opts.badge~=0 and 34 or 9
    b.label=W.Label(b,text,left,(h-12)/2,w-left-right,12,c[selected and style.selectedText or style.text]);if opts.align then b.label:SetJustifyH(opts.align)end
    if right>9 then W.Badge(b,opts.badge,w-6,(h-18)/2)end
    b:SetScript("OnClick",function()if W.BeforeAction then W.BeforeAction()end;if W.popup then W.popup:Hide()end;if callback then callback()end end)
    b:SetScript("OnEnter",function(self)self:SetBackdropBorderColor(unpack(opts.kind=="primary"and c.brandDark or c.lineStrong));if opts.kind=="nav"or opts.kind=="ghost"then self:SetBackdropColor(unpack(c.hover))end
        if opts.tooltip and GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(opts.tooltip,1,1,1,1,true);GameTooltip:Show()end end)
    b:SetScript("OnLeave",function(self)self:SetBackdropBorderColor(unpack(border));self:SetBackdropColor(unpack(bg));if opts.tooltip and GameTooltip then GameTooltip:Hide()end end)
    return register(b,key)
end
function W.Input(parent,value,x,y,w,key,multiline)
    local surround=W.Panel(parent,x,y,w,multiline and 180 or 30,W.colors.background)
    local input=W.Frame("EditBox",nil,surround);input:SetPoint("TOPLEFT",8,-6);input:SetSize(w-16,multiline and 165 or 20);input:SetFont(font,12,"");input:SetTextColor(unpack(W.colors.text));input:SetAutoFocus(false);input:SetMaxLetters(multiline and 130000 or 500);input:SetMultiLine(multiline==true);input:SetText(tostring(value or""))
    input:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
    input:SetScript("OnEditFocusGained",function()surround:SetBackdropBorderColor(unpack(W.colors.accent))end)
    input:SetScript("OnEditFocusLost",function()surround:SetBackdropBorderColor(unpack(W.colors.line))end)
    input.surround=surround;return register(input,key)
end
function W.Field(parent,title,value,x,y,w,key)
    W.Label(parent,title,x,y,w,10,W.colors.muted);return W.Input(parent,value,x,y+16,w,key)
end
function W.Toggle(parent,title,value,x,y,w,callback,key)
    local b=W.Frame("Button",nil,parent);b:SetPoint("TOPLEFT",x,-y);b:SetSize(w,24);b.value=value==true
    local track=Texture(b);track:SetSize(32,16);track:SetPoint("RIGHT",-2,0)
    local text=W.Label(b,title,0,6,w-40,12)
    local thumb=Texture(b);thumb:SetSize(12,12);thumb:SetColorTexture(0.94,0.97,1,1)
    local function paint()track:SetColorTexture(unpack(b.value and W.colors.accent or W.colors.lineStrong));thumb:ClearAllPoints();thumb:SetPoint("RIGHT",b,"RIGHT",b.value and -4 or -20,0)end;paint()
    b:SetScript("OnClick",function()if W.BeforeAction then W.BeforeAction()end;b.value=not b.value;paint();if callback then callback(b.value)end end);return register(b,key)
end
-- Inline choice row: one button per option, keyed prefix:value.
function W.Segmented(parent,options,value,x,y,w,callback,prefix)
    local frame=W.Panel(parent,x,y,w,30,W.colors.background);local each=(w-4)/#options
    for i,o in ipairs(options)do
        W.Button(frame,o.label,2+(i-1)*each,2,each,function()if callback then callback(o.value)end end,tostring(o.value)==tostring(value),prefix and(prefix..":"..tostring(o.value)),{kind="ghost",h=26,align="CENTER"})
    end
    return frame
end
-- title=nil draws the button only, at y.
function W.Select(parent,title,options,value,x,y,w,callback,key)
    if title then W.Label(parent,title,x,y,w,10,W.colors.muted);y=y+16 end
    local text="Choose...";for _,o in ipairs(options)do if tostring(o.value)==tostring(value)then text=o.label end end
    local b
    b=W.Button(parent,text,x,y,w,function()
        local p=W.menu
        if not p then
            p=W.Panel(UIParent,0,0,w,300,W.colors.background,W.colors.lineStrong);p:SetFrameStrata("TOOLTIP");p:SetClampedToScreen(true);p.rows={}
            p.scroll=CreateFrame("ScrollFrame",nil,p,"UIPanelScrollFrameTemplate");p.scroll:SetPoint("TOPLEFT",3,-3)
            p.child=CreateFrame("Frame",nil,p.scroll);W.AttachScrollChild(p.scroll,p.child);W.menu=p
        end
        p:ClearAllPoints();local height=math.min(300,#options*28+8);local bottom=b.GetBottom and b:GetBottom()
        if type(bottom)=="number"and bottom<height then p:SetPoint("BOTTOMLEFT",b,"TOPLEFT",0,2)else p:SetPoint("TOPLEFT",b,"BOTTOMLEFT",0,-2)end
        p:SetSize(w,height);p.scroll:SetSize(w-24,math.min(292,#options*28+2));p.child:SetSize(w-28,math.max(1,#options*28));p.scroll:SetVerticalScroll(0)
        for _,row in ipairs(p.rows)do row:Hide()end
        for i,o in ipairs(options)do
            local row=p.rows[i]
            if not row then row=W.Button(p.child,"",0,(i-1)*28,w-28,nil,false,nil,{kind="ghost",h=28});p.rows[i]=row end
            row:SetWidth(w-28);row.label:SetWidth(w-46);row.label:SetText(o.label);row:Show()
            row:SetScript("OnClick",function()if W.BeforeAction then W.BeforeAction()end;p:Hide();b.label:SetText(o.label);if callback then callback(o.value)end end)
        end
        p:Show();W.popup=p
    end,false,key)
    b.label:SetWidth(w-34);W.Label(b,"v",w-18,9,10,11,W.colors.muted)
    return b
end
function W.Scroll(parent,x,y,w,h,key,color)
    local panel=W.Panel(parent,x,y,w,h,color);local s=W.Frame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate");s:SetPoint("TOPLEFT",4,-4);s:SetSize(w-25,h-8)
    local child=W.Frame("Frame",nil,s);child:SetSize(w-28,1);W.AttachScrollChild(s,child)
    if key then ns.UIScrolls[key]=s end;s:SetVerticalScroll(key and W.scrollPositions and W.scrollPositions[key]or 0);return child,s,panel
end
function W.Clear(frame)
    if not frame then return end;frame:Hide();frame:SetParent(nil)
end
