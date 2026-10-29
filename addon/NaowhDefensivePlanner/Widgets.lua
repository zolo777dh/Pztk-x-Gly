-- Original lightweight controls. No settings framework or source-addon UI dependency.
-- Shapes are built from baked textures (Media/UI) so the window matches the design mockup:
-- rounded fills on BACKGROUND/BORDER, icons and the logo on ARTWORK, text on OVERLAY.
local _,ns=...
local W={};ns.Widgets=W;ns.UIControls={};ns.UIScrolls={}
local media="Interface\\AddOns\\NaowhDefensivePlanner\\Media\\"
W.media=media
W.logo=media.."Logo"
local DISC,WHITE,MASK,ICONS=media.."UI\\Disc",media.."UI\\Disc",media.."UI\\IconMask",media.."UI\\Icons"
WHITE="Interface\\Buttons\\WHITE8X8"
local function hex(h,a)return{tonumber(h:sub(1,2),16)/255,tonumber(h:sub(3,4),16)/255,tonumber(h:sub(5,6),16)/255,a or 1}end
-- Mockup palette. Tables are updated in place so modules holding W.colors see theme changes.
W.colors={
    background=hex("0a0e15"),sidebar=hex("0d131d"),panel=hex("111827"),raised=hex("182131"),hover=hex("1e293b"),
    line=hex("243044"),lineStrong=hex("3a4a63"),
    accent=hex("33c3a6"),accentSoft=hex("15312d"),accentText=hex("7fe3cc"),brand=hex("f2b84b"),brandDark=hex("d99a2b"),
    text=hex("e8eef6"),soft=hex("b4c2d3"),muted=hex("93a3b8"),faint=hex("5b6b82"),iconIdle=hex("7d8ea5"),dark=hex("0a0e15"),
    warning=hex("f2b84b"),danger=hex("f09a9a"),dangerLine=hex("5a2a2a"),ok=hex("4ade80"),clear={0,0,0,0},
}
local themes={
    mockup={accent="33c3a6",accentSoft="15312d",accentText="7fe3cc"},
    logo={accent="1e9be9",accentSoft="0a2a45",accentText="8fd0ff"},
}
function W.SetTheme(name)
    local t=themes[name]or themes.mockup;W.theme=themes[name]and name or"mockup"
    for key,value in pairs(t)do local c=hex(value);for i=1,4 do W.colors[key][i]=c[i]end end
end
-- Glyphs in Media/UI/Icons.tga, a 4x8 grid of 64 px cells.
local glyphs={"overview","mythic","raid","sets","notes","display","profiles","settings","search","close","chevron","plus","check","play","clock","list",
    "alerts","auras","assign","raidtools","players","diag","export","anchor","edit","reset","trash","up","copy","eye","warning","burst"}
W.glyphs={};for i,name in ipairs(glyphs)do W.glyphs[name]=i-1 end
---------------------------------------------------------------------------
-- Fonts. URW Gothic ships with the addon; a user's own Media/Fonts/Naowh.ttf wins when present.
W.fonts={book=media.."Fonts\\URWGothic-Book.ttf",demi=media.."Fonts\\URWGothic-Demi.ttf",naowh=media.."Fonts\\Naowh.ttf"}
local fallback=STANDARD_TEXT_FONT or"Fonts\\FRIZQT__.TTF"
local fontBook,fontDemi=W.fonts.book,W.fonts.demi
-- choice: "urw" (default), "naowh" (the user's own Media/Fonts/Naowh.ttf) or "game".
-- A missing font file renders no text at all, so Naowh.ttf is only used when chosen explicitly.
function W.SetFont(choice)
    W.fontChoice=(choice=="naowh"or choice=="game")and choice or"urw"
    if W.fontChoice=="game"then fontBook,fontDemi=fallback,fallback
    elseif W.fontChoice=="naowh"then fontBook,fontDemi=W.fonts.naowh,W.fonts.naowh
    else fontBook,fontDemi=W.fonts.book,W.fonts.demi end
end
function W.Font(bold)return bold and fontDemi or fontBook end
---------------------------------------------------------------------------
-- WoW frames cannot be destroyed. Reuse dynamic controls across redraws.
local framePools,fontPool,texturePool,iconPool={},{},{},{}
function W.Begin()
    W.building=true;W.fontIndex=0;W.textureIndex=0;W.iconIndex=0;    for _,pools in pairs(framePools)do for _,pool in pairs(pools)do pool.index=0;for _,f in ipairs(pool)do f:Hide()end end end
    for _,f in ipairs(fontPool)do f:Hide()end;for _,t in ipairs(texturePool)do t:Hide()end;for _,t in ipairs(iconPool)do t:Hide()end
end
function W.Finish()
    W.building=false
    for key,s in pairs(ns.UIScrolls)do s:UpdateScrollChildRect();s:SetVerticalScroll(W.scrollPositions and W.scrollPositions[key]or 0);if s.UpdateThumb then s.UpdateThumb()end end
end
function W.AttachScrollChild(scroll,child)
    scroll:SetScrollChild(child);child:ClearAllPoints();child:SetPoint("TOPLEFT",scroll,"TOPLEFT",0,0)
    local level=scroll.GetFrameLevel and scroll:GetFrameLevel();if type(level)=="number"then child:SetFrameLevel(level+1)end
    child:Show()
end
-- Controls inside a scroll list pass the mouse wheel on to it, so the list scrolls wherever the pointer is.
local function scrollAbove(frame)
    local cursor=frame
    for _=1,30 do
        if not cursor then return nil end
        if cursor.wheelScroll then return cursor.wheelScroll end
        if cursor.wheelHandler or(cursor.GetObjectType and cursor:GetObjectType()=="ScrollFrame")then return cursor end
        cursor=cursor.GetParent and cursor:GetParent()or nil
    end
end
local function forwardWheel(f,parent)
    if f.EnableMouseWheel==nil then return end
    if scrollAbove(parent)then
        f:EnableMouseWheel(true)
        f:SetScript("OnMouseWheel",function(self,delta)local s=scrollAbove(self:GetParent());if s and s.wheelHandler then s.wheelHandler(s,delta)end end)
    else f:EnableMouseWheel(false)end
end
W.ForwardWheel=forwardWheel
-- Follows what is typed into a reused field: one hook per field for good, and the handler of the
-- latest drawing, so redrawing never stacks handlers.
function W.OnText(field,fn)
    if not(field and field.HookScript)then return end
    field.onTextHandler=fn
    if not field.onTextHooked then field.onTextHooked=true;field:HookScript("OnTextChanged",function(self,...)if self.onTextHandler then self.onTextHandler(self,...)end end)end
end
local resetScripts={"OnClick","OnEnter","OnLeave","OnEscapePressed","OnEnterPressed","OnTextChanged","OnKeyDown","OnUpdate","OnEditFocusGained","OnEditFocusLost","OnMouseWheel","OnVerticalScroll","OnScrollRangeChanged","OnReceiveDrag","OnMouseUp","OnMouseDown"}
function W.Frame(kind,unused,parent,template)
    if not W.building then local f=CreateFrame(kind,nil,parent,template);if kind=="Button"or kind=="EditBox"then forwardWheel(f,parent)end;return f end
    -- A ScrollFrame retains its scroll child. Never recycle that child into a
    -- different parent while the old ScrollFrame still owns it.
    local pools=framePools[parent];if not pools then pools={};framePools[parent]=pools end
    local key=kind..":"..(template or"");local pool=pools[key]or{index=0};pools[key]=pool;pool.index=pool.index+1
    local f=pool[pool.index];if not f then f=CreateFrame(kind,nil,parent,template);pool[pool.index]=f else
        f:SetParent(parent);f:ClearAllPoints()
        for _,event in ipairs(resetScripts)do if f:HasScript(event)then f:SetScript(event,nil)end end
        if f.dropTarget then f.dropTarget=nil;f:EnableMouse(false)end
        -- A field handed out again follows nothing until its new drawing says what.
        f.onTextHandler=nil
    end
    f.surface=nil;f.rest=nil
    if kind=="Button"or kind=="EditBox"then forwardWheel(f,parent)end
    local level=parent and parent.GetFrameLevel and parent:GetFrameLevel();if type(level)=="number"then f:SetFrameLevel(level+1)end
    f:Show();return f
end
local function Font(parent)
    if not W.building then return parent:CreateFontString(nil,"OVERLAY")end
    W.fontIndex=W.fontIndex+1;local f=fontPool[W.fontIndex]
    if not f then f=parent:CreateFontString(nil,"OVERLAY");fontPool[W.fontIndex]=f else f:SetParent(parent);f:ClearAllPoints()end
    f:SetDrawLayer("OVERLAY");f:SetAlpha(1);f:Show();return f
end
local function Texture(parent,layer,sublevel)
    local t
    if not W.building then t=parent:CreateTexture(nil,layer or"ARTWORK")else
        W.textureIndex=W.textureIndex+1;t=texturePool[W.textureIndex]
        if not t then t=parent:CreateTexture(nil,layer or"ARTWORK");texturePool[W.textureIndex]=t else t:SetParent(parent);t:ClearAllPoints()end
    end
    t:SetDrawLayer(layer or"ARTWORK",sublevel or 0);t:SetTexCoord(0,1,0,1);t:SetVertexColor(1,1,1,1);t:SetBlendMode("BLEND");t:SetAlpha(1)
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false);t:SetTexelSnappingBias(0)end
    t:Show();return t
end
W.NewTexture=Texture
local function register(control,key)if key then ns.UIControls[key]=control end;return control end
---------------------------------------------------------------------------
-- Rounded rectangle from a disc's four quarters and three strips. Any radius works.
local quarters={{0,0.5,0,0.5,"TOPLEFT"},{0.5,1,0,0.5,"TOPRIGHT"},{0,0.5,0.5,1,"BOTTOMLEFT"},{0.5,1,0.5,1,"BOTTOMRIGHT"}}
local function shape(parent,x,y,w,h,r,color,layer,sublevel)
    local s={};r=math.max(0,math.min(r or 0,math.floor(math.min(w,h)/2)))
    local function piece(file,px,py,pw,ph)
        if pw<=0 or ph<=0 then return end
        local t=Texture(parent,layer or"BACKGROUND",sublevel);t:SetTexture(file);t:SetSize(pw,ph);t:SetPoint("TOPLEFT",x+px,-(y+py));s[#s+1]=t;return t
    end
    if r<1 then piece(WHITE,0,0,w,h)else
        for _,q in ipairs(quarters)do
            local t=piece(DISC,q[5]:find("RIGHT")and w-r or 0,q[5]:find("BOTTOM")and h-r or 0,r,r);t:SetTexCoord(q[1],q[2],q[3],q[4])
        end
        piece(WHITE,r,0,w-2*r,r);piece(WHITE,0,r,w,h-2*r);piece(WHITE,r,h-r,w-2*r,r)
    end
    function s.Paint(c)for _,t in ipairs(s)do t:SetVertexColor(unpack(c))end end
    s.Paint(color or W.colors.panel);return s
end
W.Shape=shape
-- A filled rounded box with a 1 px outline: outline on BACKGROUND, inset fill on BORDER.
-- A transparent fill would expose the whole outline shape, so outlined boxes without a fill
-- take the colour of the surface they sit on. f.rest is the fill to restore after hover.
local function surfaceOf(frame)
    while frame do if frame.surface then return frame.surface end;frame=frame.GetParent and frame:GetParent()or frame.parent end
    return W.colors.background
end
W.SurfaceOf=surfaceOf
local function box(f,w,h,color,border,r)
    color=color or W.colors.panel;r=r or 8
    local hasBorder=border and border[4]~=0
    if hasBorder and color[4]==0 then color=surfaceOf(f.GetParent and f:GetParent()or f.parent)end
    f.rest=color;if color[4]~=0 then f.surface=color end
    f.edge=hasBorder and shape(f,0,0,w,h,r,border,"BACKGROUND",-6)or nil
    f.fill=shape(f,hasBorder and 1 or 0,hasBorder and 1 or 0,hasBorder and w-2 or w,hasBorder and h-2 or h,hasBorder and math.max(0,r-1)or r,color,"BACKGROUND",-4)
    function f.SetColors(fill,edge)if fill then f.fill.Paint(fill)end;if edge and f.edge then f.edge.Paint(edge)end end
    return f
end
function W.Panel(parent,x,y,w,h,color,border,radius)
    local f=W.Frame("Frame",nil,parent);f:SetPoint("TOPLEFT",x,-y);f:SetSize(w,h)
    return box(f,w,h,color,border==nil and W.colors.line or border,radius or 10)
end
-- Card from the mockup: panel, outline, small uppercase caption.
function W.Card(parent,x,y,w,h,title,color)
    local f=W.Panel(parent,x,y,w,h,color or W.colors.panel,W.colors.line,10)
    if title then W.Caption(f,title,12,12,w-24)end;return f
end
function W.Rect(parent,x,y,w,h,color,layer)
    local t=Texture(parent,layer or"BORDER");t:SetTexture(WHITE);t:SetPoint("TOPLEFT",x,-y);t:SetSize(w,h);t:SetVertexColor(unpack(color or W.colors.line));return t
end
function W.RoundRect(parent,x,y,w,h,color,radius,layer)return shape(parent,x,y,w,h,radius or 4,color,layer or"BORDER")end
function W.Dot(parent,x,y,color,size)
    size=size or 8;local t=Texture(parent,"ARTWORK");t:SetTexture(DISC);t:SetSize(size,size);t:SetPoint("TOPLEFT",x,-y);t:SetVertexColor(unpack(color or W.colors.ok));return t
end
function W.Label(parent,text,x,y,w,size,color,bold)
    local label=Font(parent);label:SetFont(W.Font(bold),size or 13,"");label:SetPoint("TOPLEFT",x,-y);label:SetWidth(w or 200);label:SetJustifyH("LEFT");label:SetJustifyV("TOP")
    label:SetWordWrap(true);label:SetTextColor(unpack(color or W.colors.text));label:SetText(text or"");return label
end
-- Captions translate themselves and use ns.Upper, which also handles Cyrillic.
function W.Caption(parent,text,x,y,w,color)
    text=tostring(text or"");local t=ns.L and ns.L(text)or text
    return W.Label(parent,ns.Upper and ns.Upper(t)or t:upper(),x,y,w,10,color or W.colors.muted,true)
end
-- A small uppercase section caption with a hairline under it.
function W.Heading(parent,text,x,y,w)
    W.Caption(parent,text,x,y,w);W.Rect(parent,x,y+16,w,1,W.colors.line)
end
function W.Texture(parent,file,x,y,w,h,layer)
    local t=Texture(parent,layer or"ARTWORK");t:SetSize(w,h);t:SetPoint("TOPLEFT",x,-y);t:SetTexture(file);return t
end
function W.Glyph(parent,name,x,y,size,color)
    local i=W.glyphs[name]or W.glyphs.list;local t=W.Texture(parent,ICONS,x,y,size or 16,size or 16)
    local col,row=i%4,math.floor(i/4);t:SetTexCoord(col/4,(col+1)/4,row/8,(row+1)/8);t:SetVertexColor(unpack(color or W.colors.soft));return t
end
function W.SpellTexture(spell)
    local icon=134400
    if type(spell)=="number"and C_Spell and C_Spell.GetSpellTexture then local ok,v=pcall(C_Spell.GetSpellTexture,spell);if ok and ns.Plain(v,"number")then return v end end
    -- A boss ability the client has no spell icon for uses its Encounter Journal icon.
    return ns.AbilityIcon and ns.AbilityIcon(spell)or icon
end
-- Masked tiles keep their own pool: a mask stays attached to its texture.
function W.MaskedTexture(parent,file,x,y,size,mask)
    local t
    if W.building then
        W.iconIndex=W.iconIndex+1;t=iconPool[W.iconIndex]
        if not t then t=parent:CreateTexture(nil,"ARTWORK");iconPool[W.iconIndex]=t;t.mask=parent.CreateMaskTexture and parent:CreateMaskTexture()
            if t.mask then t.mask:SetAllPoints(t);t:AddMaskTexture(t.mask)end
        else t:SetParent(parent);t:ClearAllPoints();if t.mask then t.mask:SetParent(parent)end end
    else t=parent:CreateTexture(nil,"ARTWORK")end
    t:SetDrawLayer("ARTWORK",1);t:SetVertexColor(1,1,1,1);t:SetSize(size,size);t:SetPoint("TOPLEFT",x,-y);t:SetTexture(file)
    if t.mask then t.mask:SetTexture(mask or MASK,"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE");t.mask:Show()end
    -- Trim the default icon border so icons read as clean tiles.
    t:SetTexCoord(0.07,0.93,0.07,0.93);t:Show();return t
end
function W.Icon(parent,spell,x,y,size)return W.MaskedTexture(parent,W.SpellTexture(spell),x,y,size or 24)end
function W.Avatar(parent,file,x,y,size,text)
    if file then return W.MaskedTexture(parent,file,x,y,size,DISC)end
    W.Dot(parent,x,y,W.colors.accent,size);local l=W.Label(parent,text or"",x,y+(size-11)/2,size,10,W.colors.dark,true);l:SetJustifyH("CENTER");return l
end
-- Count pill. Empty or zero counts draw nothing.
function W.Badge(parent,text,x,y,color,textColor)
    if text==nil or text==""or text==0 then return end
    text=tostring(text);local w=math.max(20,#text*7+10)
    local p=W.Panel(parent,x-w,y,w,18,color or W.colors.accentSoft,W.colors.clear,9)
    local l=W.Label(p,text,0,4,w,10,textColor or W.colors.accentText,true);l:SetJustifyH("CENTER");return p
end
-- Rounded progress bar, 0..1.
function W.Bar(parent,x,y,w,value,color,h)
    h=h or 6;W.RoundRect(parent,x,y,w,h,W.colors.line,h/2)
    local filled=math.floor(w*math.max(0,math.min(1,value or 0)))
    if filled>=h then W.RoundRect(parent,x,y,filled,h,color or W.colors.accent,h/2,"ARTWORK")end
end
local styles={
    normal={bg="raised",border="line",text="text",hover="hover",selectedBg="accentSoft",selectedBorder="accent",selectedText="text"},
    primary={bg="accent",border="clear",text="dark",hover="accentText",selectedBg="accent",selectedBorder="clear",selectedText="dark",bold=true},
    ghost={bg="clear",border="clear",text="soft",hover="raised",selectedBg="raised",selectedBorder="clear",selectedText="text"},
    outline={bg="clear",border="line",text="soft",hover="raised",selectedBg="accentSoft",selectedBorder="accent",selectedText="text"},
    segment={bg="clear",border="clear",text="soft",hover="raised",selectedBg="accent",selectedBorder="clear",selectedText="dark",bold=true},
    danger={bg="clear",border="dangerLine",text="danger",hover="raised",selectedBg="clear",selectedBorder="danger",selectedText="danger"},
    nav={bg="clear",border="clear",text="soft",hover="panel",selectedBg="raised",selectedBorder="clear",selectedText="text"},
}
-- opts: kind (normal|primary|ghost|outline|segment|danger|nav), h, radius, icon (spell ID), texture (file),
-- glyph (atlas name), badge, count, align, tooltip, marker, border (color).
function W.Button(parent,text,x,y,w,callback,selected,key,opts)
    opts=opts or{};local style=styles[opts.kind or"normal"];local c=W.colors;local h=opts.h or 30
    local b=W.Frame("Button",nil,parent);b:SetPoint("TOPLEFT",x,-y);b:SetSize(w,h)
    local bg,border=c[selected and style.selectedBg or style.bg],opts.border or c[selected and style.selectedBorder or style.border]
    box(b,w,h,bg,border,opts.radius or(h>=34 and 8 or 6))
    local left=10
    if selected and(opts.kind=="nav"or opts.marker)then W.RoundRect(b,0,4,3,h-8,c.accent,1.5,"ARTWORK")end
    if opts.glyph then local size=16;W.Glyph(b,opts.glyph,10,(h-size)/2,size,selected and c.accent or(opts.kind=="nav"and c.iconIdle or c[style.text]));left=10+size+9
    elseif opts.icon or opts.texture then local size=math.min(h-8,24);if opts.texture then W.Texture(b,opts.texture,7,(h-size)/2,size,size)else W.Icon(b,opts.icon,7,(h-size)/2,size)end;left=7+size+8 end
    if text==""and(opts.glyph or opts.icon)and not opts.align then left=w end
    local right=(opts.badge and opts.badge~=""and opts.badge~=0)and 34 or opts.count and 30 or 10
    b.left=left
    b.label=W.Label(b,text,left,(h-13)/2,math.max(1,w-left-right),13,c[selected and style.selectedText or style.text],selected and opts.kind=="nav"or style.bold)
    b.label:SetWordWrap(false);if opts.align then b.label:SetJustifyH(opts.align)end
    if opts.glyph and text==""then b.label:Hide()end
    if opts.count and opts.count~=""then local n=W.Label(b,tostring(opts.count),w-34,(h-11)/2,26,11,c.muted);n:SetJustifyH("RIGHT")
    elseif right>10 then W.Badge(b,opts.badge,w-6,(h-18)/2)end
    b:SetScript("OnClick",function()if W.BeforeAction then W.BeforeAction()end;if W.popup then W.popup:Hide()end;if callback then callback()end end)
    b:SetScript("OnEnter",function(self)
        if not selected or opts.kind=="primary"then self.SetColors(c[style.hover],c[style.border]~=c.clear and c.lineStrong or nil)end
        if opts.tooltip and GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(opts.tooltip,1,1,1,1,true);GameTooltip:Show()end
    end)
    b:SetScript("OnLeave",function(self)self.SetColors(self.rest,border);if opts.tooltip and GameTooltip then GameTooltip:Hide()end end)
    return register(b,key)
end
-- Square icon button from the top bar.
function W.IconButton(parent,glyph,x,y,callback,key,tooltip,size)
    size=size or 34;local b=W.Button(parent,"",x,y,size,callback,false,key,{h=size,tooltip=tooltip,radius=8})
    W.Glyph(b,glyph,(size-16)/2,(size-16)/2,16,W.colors.soft);return b
end
local function editFont(input,size)input:SetFont(W.Font(false),size or 13,"")end
function W.Input(parent,value,x,y,w,key,multiline,opts)
    opts=opts or{};local h=multiline and 180 or(opts.h or 30)
    local surround=W.Panel(parent,x,y,w,h,W.colors.background,W.colors.line,opts.radius or 6)
    local pad=opts.glyph and 32 or 10
    if opts.glyph then W.Glyph(surround,opts.glyph,11,(h-15)/2,15,W.colors.muted)end
    local holder=surround
    if multiline then
        -- Long text scrolls with the mouse wheel inside the box.
        local scroll=W.Frame("ScrollFrame",nil,surround);scroll:SetPoint("TOPLEFT",pad,-8);scroll:SetSize(w-pad-14,h-16)
        local child=W.Frame("Frame",nil,scroll);child:SetSize(w-pad-14,h-16);W.AttachScrollChild(scroll,child);child.wheelScroll=scroll;W.Wheel(scroll,surround,w-6,8,h-16);holder=child
    end
    local input=W.Frame("EditBox",nil,holder);input:SetPoint("TOPLEFT",multiline and 0 or pad,multiline and 0 or-(h-18)/2);input:SetSize(w-pad-(multiline and 14 or 10),multiline and h-16 or 18);editFont(input,12);input:SetTextColor(unpack(W.colors.text))
    if multiline then input:SetScript("OnTextChanged",function(self)
        if self.GetNumLines then local ok,n=pcall(self.GetNumLines,self);if ok and type(n)=="number"then local height=math.max(h-16,n*15+8);self:SetHeight(height);holder:SetHeight(height);local sf=holder:GetParent();if sf and sf.UpdateScrollChildRect then sf:UpdateScrollChildRect()end end end
    end)end
    input:SetAutoFocus(false);input:SetMaxLetters(multiline and 130000 or 500);input:SetMultiLine(multiline==true);input:SetText(tostring(value or""))
    input:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
    input:SetScript("OnEditFocusGained",function()surround.SetColors(nil,W.colors.accent)end)
    input:SetScript("OnEditFocusLost",function()surround.SetColors(nil,W.colors.line)end)
    input.surround=surround;return register(input,key)
end
function W.Field(parent,title,value,x,y,w,key)
    W.Caption(parent,title,x,y,w);return W.Input(parent,value,x,y+16,w,key)
end
function W.Toggle(parent,title,value,x,y,w,callback,key)
    local b=W.Frame("Button",nil,parent);b:SetPoint("TOPLEFT",x,-y);b:SetSize(w,24);b.value=value==true
    local text=W.Label(b,title,0,5,math.max(1,w-40),13,W.colors.text);text:SetWordWrap(false)
    local track=shape(b,w-30,3,30,18,9,W.colors.line,"BORDER")
    local knob=Texture(b,"ARTWORK");knob:SetTexture(DISC);knob:SetSize(14,14);knob:SetVertexColor(unpack(W.colors.dark))
    local function paint()track.Paint(b.value and W.colors.accent or W.colors.line);knob:ClearAllPoints();knob:SetPoint("TOPLEFT",b,"TOPLEFT",b.value and w-16 or w-28,-5)end;paint()
    b:SetScript("OnClick",function()if W.BeforeAction then W.BeforeAction()end;b.value=not b.value;paint();if callback then callback(b.value)end end);return register(b,key)
end
-- Inline choice row: one button per option, keyed prefix:value. The chosen one fills with the accent.
function W.Segmented(parent,options,value,x,y,w,callback,prefix)
    local frame=W.Panel(parent,x,y,w,32,W.colors.background,W.colors.line,8);local each=(w-6)/#options
    for i,o in ipairs(options)do
        W.Button(frame,o.label,3+(i-1)*each,3,each,function()if callback then callback(o.value)end end,tostring(o.value)==tostring(value),prefix and(prefix..":"..tostring(o.value)),{kind="segment",h=26,align="CENTER"})
    end
    return frame
end
---------------------------------------------------------------------------
-- Dragging with the left button held: move(dx,dy) gets the cursor travel in UI units since
-- the press, every frame, until the button is let go (then finish). One lasting frame drives
-- it, so a page redrawn under the cursor does not end the drag.
local dragDriver
function W.Drag(scale,move,finish)
    if not(GetCursorPosition and CreateFrame)then return end
    dragDriver=dragDriver or CreateFrame("Frame")
    scale=(type(scale)=="number"and scale>0)and scale or 1
    local sx,sy=GetCursorPosition()
    dragDriver:SetScript("OnUpdate",function(self,elapsed)
        local x,y=GetCursorPosition();local dx,dy=(x-sx)/scale,(y-sy)/scale
        if not(IsMouseButtonDown and IsMouseButtonDown("LeftButton"))then self:SetScript("OnUpdate",nil);if finish then finish(dx,dy)end;return end
        move(dx,dy,elapsed or 0)
    end)
end
-- Plain scroll frame with mouse wheel and a thin thumb instead of the stock template. The
-- thumb can be dragged, and a press on its track jumps there and keeps dragging.
local function wheel(scroll,thumbParent,x,top,h)
    local level=thumbParent.GetFrameLevel and thumbParent:GetFrameLevel()or 1
    local track=W.Frame("Button",nil,thumbParent);track:SetWidth(12);track:SetPoint("TOPLEFT",thumbParent,"TOPLEFT",x-5,-top);track:SetHeight(h);track:SetFrameLevel(level+20)
    local grip=W.Frame("Button",nil,thumbParent);grip:SetWidth(12);grip:SetFrameLevel(level+21)
    local thumb=Texture(grip,"ARTWORK");thumb:SetTexture(WHITE);thumb:SetVertexColor(unpack(W.colors.lineStrong));thumb:SetWidth(3);thumb:SetPoint("TOP",grip,"TOP",0,0);thumb:SetPoint("BOTTOM",grip,"BOTTOM",0,0)
    local size=h
    local function range()local r=scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange()or 0;return type(r)=="number"and r or 0 end
    local function update()
        local r=range();local view=scroll:GetHeight()or h
        if r<=1 then grip:Hide();track:Hide();return end
        size=math.max(24,h*view/(view+r));local offset=(h-size)*math.min(1,(scroll:GetVerticalScroll()or 0)/r)
        grip:Show();track:Show();grip:ClearAllPoints();grip:SetHeight(size);grip:SetPoint("TOPLEFT",thumbParent,"TOPLEFT",x-5,-(top+offset))
    end
    local function set(v)local r=range();scroll:SetVerticalScroll(math.max(0,math.min(r,v)));update()end
    local function drag(start)
        local per=range()/math.max(1,h-size)
        W.Drag(grip:GetEffectiveScale(),function(_,dy)set(start-dy*per)end)
    end
    grip:SetScript("OnMouseDown",function(_,button)if button and button~="LeftButton"then return end;drag(scroll:GetVerticalScroll()or 0)end)
    track:SetScript("OnMouseDown",function(self,button)
        if button and button~="LeftButton"then return end
        local _,cy=GetCursorPosition();local t=self:GetTop();local s=self:GetEffectiveScale()or 1
        if type(cy)=="number"and type(t)=="number"then set(range()*((t-cy/s-size/2)/math.max(1,h-size)))end
        drag(scroll:GetVerticalScroll()or 0)
    end)
    scroll:EnableMouseWheel(true)
    scroll.wheelHandler=function(self,delta)
        local r=self.GetVerticalScrollRange and self:GetVerticalScrollRange()or 0;if type(r)~="number"then r=0 end
        self:SetVerticalScroll(math.max(0,math.min(r,(self:GetVerticalScroll()or 0)-delta*48)))
        if self.UpdateThumb then self.UpdateThumb()end
    end
    scroll:SetScript("OnMouseWheel",scroll.wheelHandler)
    scroll:SetScript("OnVerticalScroll",update);scroll:SetScript("OnScrollRangeChanged",update)
    scroll.UpdateThumb=update;scroll.ThumbGrip=grip;scroll.ThumbTrack=track;update()
end
W.Wheel=wheel
function W.Scroll(parent,x,y,w,h,key,color)
    local panel=W.Panel(parent,x,y,w,h,color,W.colors.line,10)
    local s=W.Frame("ScrollFrame",nil,panel);s:SetPoint("TOPLEFT",4,-4);s:SetSize(w-14,h-8)
    local child=W.Frame("Frame",nil,s);child:SetSize(w-16,1);W.AttachScrollChild(s,child);child.surface=panel.surface;child.wheelScroll=s
    wheel(s,panel,w-7,6,h-12)
    if key then ns.UIScrolls[key]=s end;s:SetVerticalScroll(key and W.scrollPositions and W.scrollPositions[key]or 0);return child,s,panel
end
-- Spell dragged from the spellbook or an action bar: its spell ID, or nil and the cursor kind.
function W.CursorSpell()
    if not GetCursorInfo then return nil end
    local kind,index,book,spell=GetCursorInfo()
    if kind~="spell"then return nil,kind end
    spell=tonumber(spell)
    if not spell and C_SpellBook and C_SpellBook.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank then
        local ok,info=pcall(C_SpellBook.GetSpellBookItemInfo,index,book=="pet"and Enum.SpellBookSpellBank.Pet or Enum.SpellBookSpellBank.Player)
        if ok and type(info)=="table"then spell=tonumber(info.spellID)end
    end
    return spell,kind
end
-- Lets a frame take a spell dropped on it: a drag release, or a click while a spell is held.
function W.DropTarget(frame,callback)
    frame:EnableMouse(true);frame.dropTarget=true
    local function drop()
        local spell,kind=W.CursorSpell();if not spell and not kind then return end
        if ClearCursor then ClearCursor()end;callback(spell,kind)
    end
    frame:SetScript("OnReceiveDrag",drop);frame:SetScript("OnMouseUp",drop)
    return frame
end
-- title=nil draws the button only, at y. opts are passed to the button (pill, avatar...).
function W.Select(parent,title,options,value,x,y,w,callback,key,opts)
    if title then W.Caption(parent,title,x,y,w);y=y+16 end
    local text="Choose...";for _,o in ipairs(options)do if tostring(o.value)==tostring(value)then text=o.label end end
    local b
    b=W.Button(parent,text,x,y,w,function()
        local p=W.menu
        if not p then
            p=W.Panel(UIParent,0,0,w,300,W.colors.panel,W.colors.lineStrong,8);p:SetFrameStrata("TOOLTIP");p:SetClampedToScreen(true);p.rows={};p.boxes={[w..":300"]={fill=p.fill,edge=p.edge}}
            p.scroll=CreateFrame("ScrollFrame",nil,p);p.scroll:SetPoint("TOPLEFT",4,-4)
            p.child=CreateFrame("Frame",nil,p.scroll);W.AttachScrollChild(p.scroll,p.child);p.child.wheelScroll=p.scroll;W.menu=p
            wheel(p.scroll,p,0,6,288)
            -- A click anywhere outside the open list closes it, like a click on one of its rows.
            local catcher=CreateFrame("Frame",nil,UIParent);catcher:SetAllPoints(UIParent);catcher:SetFrameStrata("FULLSCREEN_DIALOG");catcher:EnableMouse(true);catcher:Hide()
            catcher:SetScript("OnMouseDown",function()p:Hide()end);p.catcher=catcher
            p:SetScript("OnShow",function()catcher:Show()end);p:SetScript("OnHide",function()catcher:Hide()end)
        end
        p:ClearAllPoints();local height=math.min(300,#options*28+8);local bottom=b.GetBottom and b:GetBottom()
        if type(bottom)=="number"and bottom<height then p:SetPoint("BOTTOMLEFT",b,"TOPLEFT",0,2)else p:SetPoint("TOPLEFT",b,"BOTTOMLEFT",0,-2)end
        -- The menu is reused at many widths; keep one rounded box per size.
        p.boxes=p.boxes or{}
        for _,cached in pairs(p.boxes)do for _,t in ipairs(cached.fill)do t:Hide()end;for _,t in ipairs(cached.edge)do t:Hide()end end
        local size=w..":"..height;local cached=p.boxes[size]
        if not cached then box(p,w,height,W.colors.panel,W.colors.lineStrong,8);cached={fill=p.fill,edge=p.edge};p.boxes[size]=cached end
        for _,t in ipairs(cached.fill)do t:Show()end;for _,t in ipairs(cached.edge)do t:Show()end
        p:SetSize(w,height);p.scroll:SetSize(w-10,math.min(292,#options*28+2));p.child:SetSize(w-12,math.max(1,#options*28));p.scroll:SetVerticalScroll(0)
        for _,row in ipairs(p.rows)do row:Hide()end
        for i,o in ipairs(options)do
            local row=p.rows[i]
            if not row then row=W.Button(p.child,"",0,(i-1)*28,w-12,nil,false,nil,{kind="ghost",h=28});p.rows[i]=row end
            row:SetWidth(w-12);row.label:SetWidth(w-30);row.label:SetText(o.label);row.label:SetTextColor(unpack(tostring(o.value)==tostring(value)and W.colors.accentText or W.colors.text));row:Show()
            row:SetScript("OnClick",function()if W.BeforeAction then W.BeforeAction()end;p:Hide();b.label:SetText(o.label);if callback then callback(o.value)end end)
        end
        if p.scroll.UpdateThumb then p.scroll.UpdateThumb()end
        p:Show();p.catcher:Show();W.popup=p
    end,false,key,opts)
    local h=opts and opts.h or 30
    b.label:SetWidth(math.max(1,w-b.left-30));W.Glyph(b,"chevron",w-24,(h-12)/2,12,W.colors.muted)
    return b
end
function W.Clear(frame)
    if not frame then return end;frame:Hide();frame:SetParent(nil)
end
W.SetTheme("mockup");W.SetFont("urw")
