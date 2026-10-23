-- Playback of the animations baked by tools/bake-addon-media.mjs (Three.js aurora, PixiJS
-- sparks/rings/trails/glow, GSAP logo shine). WoW cannot run WebGL, so the frames live in
-- Media/Anim/*.tga and this file plays them: flipbooks, additive blending and an OnUpdate
-- that only runs while the window is shown. Modes: full, reduced (glow only), off.
local _,ns=...
local W=ns.Widgets
local A={mode="full"};ns.Anim=A
local anim=W.media.."Anim\\"
local FPS=1/60
local AURORA_FRAMES,AURORA_SECONDS=64,9
local SHINE_FRAMES,SHINE_SECONDS,SHINE_EVERY=32,0.9,6
local window,top,aurora,sparks,trail,shine,cursor,clock,lastCursor
local function cell(tex,index,cols,rows)
    local c,r=index%cols,math.floor(index/cols)%rows
    tex:SetTexCoord(c/cols,(c+1)/cols,r/rows,(r+1)/rows)
end
local function additive(parent,file,layer,sublevel)
    local t=parent:CreateTexture(nil,layer or"ARTWORK",nil,sublevel or 0);t:SetTexture(file);t:SetBlendMode("ADD");t:Hide();return t
end
local function accent(alpha)local c=W.colors.accent;return c[1],c[2],c[3],alpha or 1 end
local function resetSpark(s,width,height,fresh)
    s.x=176+math.random()*width;s.y=fresh and(60+math.random()*height)or(60+height);s.vy=-(10+math.random()*22);s.vx=(math.random()-0.5)*8
    s.life=0;s.span=5+math.random()*6;s.size=6+math.random()*10;s.orange=math.random()<0.3
end
function A.Attach(frame)
    window=frame;clock=0
    -- Aurora: two stacked flipbook frames crossfaded, on the window's own BACKGROUND layer
    -- (above its fill, below every child frame), so it shows between the cards.
    aurora={additive(window,anim.."Aurora","BACKGROUND",1),additive(window,anim.."Aurora","BACKGROUND",2)}
    for _,t in ipairs(aurora)do t:SetPoint("TOPLEFT",window,"TOPLEFT",177,-61);t:SetSize(932,650)end
    sparks={}
    for i=1,24 do local s={tex=additive(window,anim.."Spark","BACKGROUND",3)};resetSpark(s,932,650,true);sparks[i]=s end
    -- Effects above the controls: header trail, logo shine and the cursor trail.
    top=CreateFrame("Frame",nil,window);top:SetAllPoints(window)
    trail=additive(top,anim.."Trail","OVERLAY");trail:SetSize(220,16)
    shine=additive(top,anim.."LogoShine","OVERLAY");shine:SetSize(56,56)
    cursor={}
    for i=1,18 do cursor[i]={tex=additive(top,anim.."Spark","OVERLAY",2),life=1}end
    top:SetScript("OnUpdate",function(_,elapsed)A.Step(elapsed)end)
    A.Apply()
end
-- Called after each redraw: keep the effect layer above the freshly built controls.
function A.Layout(frame,header)
    if not top then return end
    local level=frame.GetFrameLevel and frame:GetFrameLevel();if type(level)=="number"then top:SetFrameLevel(level+40)end
    if header and header.logo then shine:ClearAllPoints();shine:SetPoint("CENTER",header.logo,"CENTER",0,0)end
    A.Apply()
end
function A.SetMode(mode)
    A.mode=(mode=="reduced"or mode=="off")and mode or"full";A.Apply()
end
function A.Apply()
    if not window then return end
    local full=A.mode=="full"
    for i,t in ipairs(aurora)do if A.mode=="off"then t:Hide()else t:Show();t:SetVertexColor(1,1,1,1);cell(t,0,8,8);t:SetAlpha(i==1 and 0.55 or 0)end end
    for _,s in ipairs(sparks)do if full then s.tex:Show()else s.tex:Hide()end end
    if not full then trail:Hide();shine:Hide();for _,c in ipairs(cursor)do c.tex:Hide()end end
    for _,g in ipairs(W.pulses)do g:SetAlpha(A.mode=="off"and 0 or 0.14)end
end
local acc=0
function A.Step(elapsed)
    acc=acc+elapsed;if acc<FPS then return end
    local dt=acc;acc=0;clock=clock+dt
    if A.mode=="off"then return end
    -- Selection glow pulse (reduced and full).
    local pulse=0.12+0.08*(0.5+0.5*math.sin(clock*2.4))
    for _,g in ipairs(W.pulses)do g:SetAlpha(pulse)end
    if A.mode~="full"then return end
    -- Aurora flipbook with crossfade between neighbouring frames: smooth at 60 fps from 64 frames.
    local pos=(clock/AURORA_SECONDS*AURORA_FRAMES)%AURORA_FRAMES;local index=math.floor(pos);local mix=pos-index
    cell(aurora[1],index,8,8);cell(aurora[2],(index+1)%AURORA_FRAMES,8,8);aurora[1]:SetAlpha(0.55*(1-mix));aurora[2]:SetAlpha(0.55*mix)
    -- Drifting particles in the content area.
    for _,s in ipairs(sparks)do
        s.life=s.life+dt;s.x=s.x+s.vx*dt;s.y=s.y+s.vy*dt
        if s.life>=s.span or s.y<62 then resetSpark(s,932,650,false)end
        local fade=math.min(1,s.life/1.2,(s.span-s.life)/1.2)
        local t=s.tex;t:ClearAllPoints();t:SetPoint("CENTER",window,"TOPLEFT",s.x,-s.y);t:SetSize(s.size,s.size)
        if s.orange then t:SetVertexColor(0.95,0.72,0.29,1)else t:SetVertexColor(accent())end;t:SetAlpha(0.55*math.max(0,fade))
    end
    -- Light trail running along the bottom edge of the top bar every few seconds.
    local run=(clock%7)/1.6
    if run<=1 then trail:Show();trail:ClearAllPoints();trail:SetPoint("CENTER",window,"TOPLEFT",-110+run*1340,-59);trail:SetVertexColor(accent());trail:SetAlpha(math.sin(run*math.pi))else trail:Hide()end
    -- GSAP-timed logo shine, replayed every few seconds.
    local t=clock%SHINE_EVERY
    if t<SHINE_SECONDS then shine:Show();cell(shine,math.floor(t/SHINE_SECONDS*SHINE_FRAMES),8,4)else shine:Hide()end
    -- Cursor trail while the pointer is over the window.
    if GetCursorPosition and window:IsMouseOver()then
        local x,y=GetCursorPosition();local scale=top:GetEffectiveScale()
        if type(x)=="number"and scale and scale>0 then
            x,y=x/scale,y/scale
            if not lastCursor or math.abs(lastCursor[1]-x)+math.abs(lastCursor[2]-y)>6 then
                for _,c in ipairs(cursor)do if c.life>=1 then c.life=0;c.x=x;c.y=y;break end end
                lastCursor={x,y}
            end
        end
    end
    for _,c in ipairs(cursor)do
        if c.life<1 then
            c.life=c.life+dt/0.45;local t=c.tex;t:Show();t:ClearAllPoints();t:SetPoint("CENTER",UIParent,"BOTTOMLEFT",c.x,c.y)
            local size=14*(1-c.life*0.6);t:SetSize(size,size);t:SetVertexColor(accent());t:SetAlpha(0.7*(1-c.life))
        else c.tex:Hide()end
    end
end
local bursts=setmetatable({},{__mode="k"})
-- Burst on a reminder: an expanding ring and sparks thrown outward. Runs only for its 0.5 s.
function A.Burst(region,anchor)
    local prefs=ns.UIPrefs and ns.Store and ns.UIPrefs()or{}
    if(prefs.anim or"full")~="full"or not region then return end
    local b=bursts[region]
    if not b then
        b=CreateFrame("Frame",nil,region);b:SetAllPoints(region);b.ring=additive(b,anim.."Ring","OVERLAY");b.sparks={}
        for i=1,10 do b.sparks[i]=additive(b,anim.."Spark","OVERLAY",1)end;bursts[region]=b
    end
    local level=region.GetFrameLevel and region:GetFrameLevel();if type(level)=="number"then b:SetFrameLevel(level+5)end
    b.anchor=anchor or region;b.time=0;b:Show()
    for i,s in ipairs(b.sparks)do s.angle=(i/#b.sparks)*math.pi*2+math.random()*0.4;s.speed=60+math.random()*50 end
    b:SetScript("OnUpdate",function(self,elapsed)
        self.time=self.time+elapsed;local p=self.time/0.5
        if p>=1 then self.ring:Hide();for _,s in ipairs(self.sparks)do s:Hide()end;self:SetScript("OnUpdate",nil);return end
        local ease=1-(1-p)^3;local r,g,bl=accent()
        local ring=self.ring;ring:Show();ring:ClearAllPoints();ring:SetPoint("CENTER",self.anchor,"CENTER",0,0);local size=40+90*ease;ring:SetSize(size,size);ring:SetVertexColor(r,g,bl,1);ring:SetAlpha(0.9*(1-p))
        for i,s in ipairs(self.sparks)do
            s:Show();s:ClearAllPoints();s:SetPoint("CENTER",self.anchor,"CENTER",math.cos(s.angle)*s.speed*ease,math.sin(s.angle)*s.speed*ease)
            s:SetSize(10,10);if i%2==0 then s:SetVertexColor(0.95,0.72,0.29,1)else s:SetVertexColor(r,g,bl,1)end;s:SetAlpha(1-p)
        end
    end)
end
