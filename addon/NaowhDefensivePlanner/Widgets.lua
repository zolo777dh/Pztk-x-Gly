-- Original lightweight controls. No settings framework or source-addon UI dependency.
local _,ns=...
local W={};ns.Widgets=W;ns.UIControls={};ns.UIScrolls={}
W.colors={background={0.025,0.035,0.055,1},panel={0.045,0.065,0.09,1},raised={0.065,0.09,0.12,1},line={0.13,0.2,0.27,1},accent={0.04,0.74,0.88,1},text={0.87,0.92,0.96,1},muted={0.52,0.65,0.73,1},warning={1,0.7,0.25,1}}
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
        for _,event in ipairs({"OnClick","OnEnter","OnLeave","OnEscapePressed","OnEnterPressed","OnTextChanged","OnKeyDown","OnUpdate"})do if f:HasScript(event)then f:SetScript(event,nil)end end
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
    if not t then t=parent:CreateTexture(nil,"ARTWORK");texturePool[W.textureIndex]=t else t:SetParent(parent);t:ClearAllPoints()end;t:Show();return t
end
local font=STANDARD_TEXT_FONT or"Fonts\\FRIZQT__.TTF"
local function register(control,key)if key then ns.UIControls[key]=control end;return control end
function W.Panel(parent,x,y,w,h,color)
    local f=W.Frame("Frame",nil,parent,"BackdropTemplate");f:SetPoint("TOPLEFT",x,-y);f:SetSize(w,h)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1});f:SetBackdropColor(unpack(color or W.colors.panel));f:SetBackdropBorderColor(unpack(W.colors.line));return f
end
function W.Label(parent,text,x,y,w,size,color)
    local label=Font(parent);label:SetFont(font,size or 12,"");label:SetPoint("TOPLEFT",x,-y);label:SetWidth(w or 200);label:SetJustifyH("LEFT");label:SetTextColor(unpack(color or W.colors.text));label:SetText(text or"");return label
end
function W.Button(parent,text,x,y,w,callback,selected,key)
    local b=W.Frame("Button",nil,parent,"BackdropTemplate");b:SetPoint("TOPLEFT",x,-y);b:SetSize(w,30)
    b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1});b:SetBackdropColor(unpack(selected and{0.025,0.23,0.3,1}or W.colors.raised));b:SetBackdropBorderColor(unpack(selected and W.colors.accent or W.colors.line))
    b.label=W.Label(b,text,9,8,w-18,12,selected and W.colors.accent or W.colors.text)
    b:SetScript("OnClick",function()if W.BeforeAction then W.BeforeAction()end;if W.popup then W.popup:Hide()end;if callback then callback()end end)
    b:SetScript("OnEnter",function(self)self:SetBackdropBorderColor(unpack(W.colors.accent))end)
    b:SetScript("OnLeave",function(self)self:SetBackdropBorderColor(unpack(selected and W.colors.accent or W.colors.line))end)
    return register(b,key)
end
function W.Input(parent,value,x,y,w,key,multiline)
    local surround=W.Panel(parent,x,y,w,multiline and 180 or 28,W.colors.background)
    local input=W.Frame("EditBox",nil,surround);input:SetPoint("TOPLEFT",7,-5);input:SetSize(w-14,multiline and 165 or 20);input:SetFont(font,12,"");input:SetTextColor(unpack(W.colors.text));input:SetAutoFocus(false);input:SetMaxLetters(multiline and 130000 or 500);input:SetMultiLine(multiline==true);input:SetText(tostring(value or""));input:SetScript("OnEscapePressed",function(self)self:ClearFocus()end);return register(input,key)
end
function W.Field(parent,title,value,x,y,w,key)
    W.Label(parent,title,x,y,w,10,W.colors.muted);return W.Input(parent,value,x,y+17,w,key)
end
function W.Toggle(parent,title,value,x,y,w,callback,key)
    local b=W.Frame("Button",nil,parent);b:SetPoint("TOPLEFT",x,-y);b:SetSize(w,25);b.value=value==true
    local mark=Texture(b);mark:SetSize(28,14);mark:SetPoint("RIGHT",-2,0)
    local text=W.Label(b,title,0,5,w-36,12)
    local thumb=Texture(b);thumb:SetSize(10,10);thumb:SetColorTexture(0.91,0.95,0.98,1)
    local function paint()mark:SetColorTexture(unpack(b.value and W.colors.accent or W.colors.line));thumb:ClearAllPoints();thumb:SetPoint("RIGHT",b,"RIGHT",b.value and -4 or -15,0)end;paint()
    b:SetScript("OnClick",function()if W.BeforeAction then W.BeforeAction()end;b.value=not b.value;paint();if callback then callback(b.value)end end);return register(b,key)
end
function W.Select(parent,title,options,value,x,y,w,callback,key)
    W.Label(parent,title,x,y,w,10,W.colors.muted)
    local text="Choose...";for _,o in ipairs(options)do if tostring(o.value)==tostring(value)then text=o.label end end
    local b
    b=W.Button(parent,text.."  v",x,y+17,w,function()
        local p=W.menu
        if not p then
            p=W.Panel(UIParent,0,0,w,300,W.colors.background);p:SetFrameStrata("TOOLTIP");p:SetClampedToScreen(true);p.rows={}
            p.scroll=CreateFrame("ScrollFrame",nil,p,"UIPanelScrollFrameTemplate");p.scroll:SetPoint("TOPLEFT",3,-3)
            p.child=CreateFrame("Frame",nil,p.scroll);W.AttachScrollChild(p.scroll,p.child);W.menu=p
        end
        p:ClearAllPoints();local height=math.min(300,#options*28+8);local bottom=b.GetBottom and b:GetBottom()
        if type(bottom)=="number"and bottom<height then p:SetPoint("BOTTOMLEFT",b,"TOPLEFT",0,2)else p:SetPoint("TOPLEFT",b,"BOTTOMLEFT",0,-2)end
        p:SetSize(w,height);p.scroll:SetSize(w-24,math.min(292,#options*28+2));p.child:SetSize(w-28,math.max(1,#options*28));p.scroll:SetVerticalScroll(0)
        for _,row in ipairs(p.rows)do row:Hide()end
        for i,o in ipairs(options)do
            local row=p.rows[i]
            if not row then row=W.Button(p.child,"",0,(i-1)*28,w-28,nil);p.rows[i]=row end
            row:SetWidth(w-28);row.label:SetWidth(w-46);row.label:SetText(o.label);row:Show()
            row:SetScript("OnClick",function()if W.BeforeAction then W.BeforeAction()end;p:Hide();b.label:SetText(o.label.."  v");if callback then callback(o.value)end end)
        end
        p:Show();W.popup=p
    end,false,key);return b
end
function W.Scroll(parent,x,y,w,h,key)
    local panel=W.Panel(parent,x,y,w,h);local s=W.Frame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate");s:SetPoint("TOPLEFT",4,-4);s:SetSize(w-25,h-8)
    local child=W.Frame("Frame",nil,s);child:SetSize(w-28,1);W.AttachScrollChild(s,child)
    if key then ns.UIScrolls[key]=s end;s:SetVerticalScroll(key and W.scrollPositions and W.scrollPositions[key]or 0);return child,s,panel
end
function W.Icon(parent,spell,x,y,size)
    local texture=Texture(parent);texture:SetSize(size or 24,size or 24);texture:SetPoint("TOPLEFT",x,-y)
    local icon=134400;if C_Spell and C_Spell.GetSpellTexture then local ok,v=pcall(C_Spell.GetSpellTexture,spell);if ok and ns.Plain(v,"number")then icon=v end end;texture:SetTexture(icon);return texture
end
function W.Clear(frame)
    if not frame then return end;frame:Hide();frame:SetParent(nil)
end
