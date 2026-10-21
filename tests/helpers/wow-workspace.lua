unpack=unpack or table.unpack
local env={frames={},time=100,combat=false,spec=104,version='12.1.5',map=2813,difficulty=8,instance='party',shown={}}
local methods={}
local function node(kind,parent)
 local f={kind=kind,parent=parent,shown=true,scripts={},events={},w=0,h=0};env.frames[#env.frames+1]=f
 return setmetatable(f,{__index=function(_,key)if methods[key]then return methods[key]end;if key:match('^[A-Z]')then return function()end end end})
end
function CreateFrame(kind,_,parent,template)local f=node(kind,parent);f.template=template;return f end
UIParent=node('Root');UIParent.w=1280;UIParent.h=800
function methods:SetScript(k,v)self.scripts[k]=v end
function methods:HasScript()return true end
function methods:RegisterEvent(k)self.events[k]=true end
function methods:SetParent(p)local cursor=p;while cursor do assert(cursor~=self,'Cyclic frame parenting');cursor=cursor.parent end;self.parent=p end
function methods:Show()local changed=not self.shown;self.shown=true;if changed and self.scripts.OnShow then self.scripts.OnShow(self)end end
function methods:Hide()local changed=self.shown;self.shown=false;if changed and self.scripts.OnHide then self.scripts.OnHide(self)end end
function methods:IsShown()return self.shown end
function methods:IsVisible()return self.shown and(not self.parent or self.parent:IsVisible())end
function methods:GetFrameLevel()return self.level or(self.parent and self.parent:GetFrameLevel()+1)or 0 end
function methods:SetFrameLevel(level)assert(type(level)=='number');self.level=level end
function methods:SetSize(w,h)self.w=w;self.h=h end
function methods:SetWidth(w)self.w=w end
function methods:SetHeight(h)self.h=h end
function methods:GetWidth()return self.w end
function methods:GetHeight()return self.h end
function methods:SetText(t)self.text=tostring(t or'')end
function methods:GetText()return self.text or''end
function methods:GetObjectType()return self.kind=='Text'and'FontString'or self.kind end
function methods:SetFont(file,size,flags)
 assert(type(file)=='string'and type(size)=='number','SetFont requires a font file and height')
 -- EditBox requires flags in the game API; permissive no-op mocks hid this error.
 if self.kind=='EditBox'then assert(type(flags)=='string',"bad argument #3 to 'SetFont'")end
 self.font=file;self.fontSize=size;self.fontFlags=flags;return true
end
function methods:GetFont()return self.font or'Fonts/FRIZQT__.TTF',self.fontSize or 14,''end
function methods:SetTextColor(r,g,b)self.textColor={r,g,b}end
function methods:SetBackdropColor(r,g,b,a)self.background={r,g,b,a}end
function methods:SetBackdropBorderColor(r,g,b,a)self.border={r,g,b,a}end
function methods:ClearAllPoints()self.point=nil end
function methods:SetPoint(point,a,b,c,d)
 if type(a)=='number'then self.point={point=point,relative=self.parent,x=a,y=b or 0}
 elseif type(a)=='table'then self.point={point=point,relative=a,relativePoint=b,x=c or 0,y=d or 0}
 else self.point={point=point,relative=self.parent,x=0,y=0}end
end
function methods:SetScrollChild(child)
 if self.scrollChild and self.scrollChild~=child then self.scrollChild.scrollOwner=nil end
 self.scrollChild=child;child.scrollOwner=self;child:SetParent(self)
end
function methods:GetScrollChild()return self.scrollChild end
function methods:SetVerticalScroll(v)self.scroll=v end
function methods:GetVerticalScroll()return self.scroll or 0 end
function methods:CreateTexture()return node('Texture',self)end
function methods:CreateFontString()return node('Text',self)end
function methods:SetTexture(texture)self.texture=texture end
function methods:SetColorTexture(r,g,b,a)self.background={r,g,b,a}end
function methods:Click()assert(self.scripts.OnClick,'Control has no click handler');self.scripts.OnClick(self)end
function methods:SetFocus()self.focus=true end
function GetTime()return env.time end
function GetBuildInfo()return env.version,'70448','',env.version=='12.1.5'and 120105 or 16001 end
function GetScreenWidth()return 1280 end
function GetScreenHeight()return 800 end
function GetSpecialization()return 1 end
function GetSpecializationInfo()return env.spec end
function InCombatLockdown()return env.combat end
function GetInstanceInfo()return 'Test',env.instance,env.difficulty,nil,nil,nil,nil,env.map end
function UnitGroupRolesAssigned()return 'TANK'end
function UnitClass()return 'Druid','DRUID'end
function UnitName()return 'Tester'end
function UnitFullName()return 'Tester','Realm'end
function PlaySoundFile()end
function issecretvalue()return false end
C_SpellBook={IsSpellKnown=function()return true end}
C_Spell={GetSpellCooldown=function()return{startTime=0,duration=0,isEnabled=true,isActive=false}end,GetSpellInfo=function(id)return {name=(PztkReminders and PztkReminders.Catalog.spellNames[id])or('Spell '..id),iconID=134400}end,GetSpellTexture=function()return 134400 end}
C_AddOns={IsAddOnLoaded=function()return false end,GetAddOnMetadata=function()return'test'end}
SlashCmdList={}
local timers={}
C_Timer={NewTimer=function(delay,fn)local t={at=env.time+delay,fn=fn};function t:Cancel()self.cancelled=true end;timers[#timers+1]=t;return t end}
function env.advance(seconds)env.time=env.time+seconds;for _,t in ipairs(timers)do if not t.cancelled and not t.fired and t.at<=env.time then t.fired=true;t.fn()end end end
function env.click(key)assert(PztkReminders.UIControls[key],'Missing control '..key):Click()end
function env.input(key,text)assert(PztkReminders.UIControls[key],'Missing input '..key):SetText(text)end
function env.select(key,value)
 env.click(key);local menu=PztkReminders.Widgets.menu
 for _,r in ipairs(menu.rows)do if r.shown and r.label.text==value then r:Click();return end end
 error('Missing option '..value..' for '..key)
end
function env.assertLayout()
 for _,f in ipairs(env.frames)do
  if f.kind=='ScrollFrame'and f:IsVisible()then
   local child=assert(f.scrollChild,'Visible scroll frame has no content')
   assert(child.parent==f and child.scrollOwner==f,'Scroll child was recycled into another viewport')
   assert(child.shown and child.point and child.point.relative==f,'Scroll content is hidden or unanchored')
   assert(child:GetFrameLevel()>f:GetFrameLevel(),'Scroll content is below its background')
  end
 end
 for key,f in pairs(PztkReminders.UIControls)do assert(f:IsVisible(),'Control is hidden: '..key)end
end
return env
