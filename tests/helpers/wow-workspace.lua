unpack=unpack or table.unpack
local env={frames={},time=100,combat=false,spec=104,class='DRUID',version='12.1.5',map=2813,difficulty=8,instance='party',shown={}}
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
function methods:RegisterUnitEvent(k)self.events[k]=true end
function methods:UnregisterEvent(k)self.events[k]=nil end
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
function methods:CreateTexture(_,layer,_,sub)local t=node('Texture',self);t.layer=layer;t.sublevel=sub or 0;return t end
function methods:CreateFontString(_,layer)local t=node('Text',self);t.layer=layer or'OVERLAY';return t end
function methods:SetTexture(texture)self.texture=texture end
function methods:SetVertexColor(r,g,b,a)self.vertex={r,g,b,a or 1}end
function methods:SetTexCoord(a,b,c,d)self.coords={a,b,c,d}end
function methods:SetDrawLayer(layer,sub)self.layer=layer;self.sublevel=sub or 0 end
function methods:SetBlendMode(mode)self.blend=mode end
function methods:SetAlpha(a)self.alpha=a end
function methods:SetJustifyH(j)self.justify=j end
function methods:SetWordWrap(v)self.wrap=v end
function methods:GetParent()return self.parent end
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
function UnitClass()return 'Class',env.class end
function UnitName()return 'Tester'end
function UnitFullName()return 'Tester','Realm'end
function PlaySoundFile()end
function issecretvalue()return false end
C_SpellBook={IsSpellKnown=function()return true end}
C_Spell={GetSpellCooldown=function()return{startTime=0,duration=0,isEnabled=true,isActive=false}end,GetSpellInfo=function(id)return {name=(NaowhDefensivePlanner and NaowhDefensivePlanner.Catalog.spellNames[id])or('Spell '..id),iconID=134400}end,GetSpellTexture=function()return 134400 end}
C_AddOns={IsAddOnLoaded=function()return false end,GetAddOnMetadata=function()return'test'end}
-- A small Encounter Journal for Journal.lua: one raid and one dungeon. Each ability is
-- {spellID, title, icon flags, mythic only}.
env.journal={
 raids={{id=1300,name='Fixture Raid',bosses={
  {enc=3379,name='Nymrissa Wavecaller',abilities={{1260837,'Abyssal Rain',{2}},{1268562,'Water Jet',{0},true},{1313393,'Chilling Frost',{2,7}}}},
  {enc=3455,name='Vashnik the Malignant',abilities={{1280935,'Dripping Fangs',{0}},{1281907,'Plague Froth',{2,9}},{1282117,'Adaptive Infection',{10}},{1294994,'Stygian Infection',{9},true}}},
  {enc=3445,name='Entombed Sentinels',abilities={{1284487,'Bloodvenom Injection',{0,9}},{1284483,'Blighted Blood',{9}},{1296878,'Shifting Protovenom',{9},true},{1284458,'Empowering Slam',{0}},{1284434,'Toxic Droplets',{}}}},
  {enc=3901,name='Journal Only Boss',abilities={{1390001,'Fixture Smash',{0}},{1390002,'Fixture Curse',{8}}}},
 }}},
 dungeons={{id=1310,name='Murder Row',mapID=2813,bosses={{enc=3103,name='Xathuux the Annihilator',abilities={{1390101,'Fixture Fel Blast',{6}}}}}}},
}
do
 local tier,diff=1,14
 local function find(instance)for _,list in pairs(env.journal)do for _,x in ipairs(list)do if x.id==instance then return x end end end end
 local function ability(id)for _,list in pairs(env.journal)do for _,x in ipairs(list)do for _,b in ipairs(x.bosses)do
  if math.floor(id/1000)==b.enc then return b,id%1000 end end end end end
 function EJ_GetNumTiers()return 2 end
 function EJ_GetCurrentTier()return tier end
 function EJ_SelectTier(t)tier=t end
 function EJ_GetDifficulty()return diff end
 function EJ_SetDifficulty(d)diff=d end
 function EJ_SelectInstance()end
 function EJ_GetInstanceByIndex(i,raid)if tier~=2 then return nil end;local x=(raid and env.journal.raids or env.journal.dungeons)[i];if x then return x.id,x.name,'',0,0,0,0,0,'',true,x.mapID end end
 function EJ_GetEncounterInfoByIndex(i,instance)local x=find(instance);local b=x and x.bosses[i];if b then return b.name,'',b.enc+100000,b.enc*1000,'',instance,b.enc,instance end end
 C_EncounterJournal={
  GetSectionInfo=function(id)local b,k=ability(id);if not b then return nil end
   if k==0 then return{spellID=0,title=b.name,headerType=0,abilityIcon=0,firstChildSectionID=b.enc*1000+1}end
   local a=b.abilities[k];if not a then return nil end
   return{spellID=a[1],title=a[2],headerType=1,abilityIcon=5000+k,filteredByDifficulty=a[4]==true and diff~=16,siblingSectionID=b.abilities[k+1]and id+1 or nil}end,
  GetSectionIconFlags=function(id)local b,k=ability(id);local a=b and b.abilities[k];return a and a[3]end,
 }
end
SlashCmdList={}
local timers={}
C_Timer={NewTimer=function(delay,fn)local t={at=env.time+delay,fn=fn};function t:Cancel()self.cancelled=true end;timers[#timers+1]=t;return t end}
function env.advance(seconds)env.time=env.time+seconds;for _,t in ipairs(timers)do if not t.cancelled and not t.fired and t.at<=env.time then t.fired=true;t.fn()end end end
function env.click(key)assert(NaowhDefensivePlanner.UIControls[key],'Missing control '..key):Click()end
function env.input(key,text)assert(NaowhDefensivePlanner.UIControls[key],'Missing input '..key):SetText(text)end
function env.select(key,value)
 env.click(key);local menu=NaowhDefensivePlanner.Widgets.menu
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
 for key,f in pairs(NaowhDefensivePlanner.UIControls)do assert(f:IsVisible(),'Control is hidden: '..key)end
end
return env
