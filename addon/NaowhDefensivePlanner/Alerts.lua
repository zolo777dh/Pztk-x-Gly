-- Boss alerts: every saved reminder of this profile in one list, grouped by encounter,
-- with an on/off switch, a test and a jump to its editor.
local _,ns=...
local W=ns.Widgets
local C=W.colors
local L=ns.L
local kit=ns.UIKit

function ns.EncounterName(encounter)
    encounter=tonumber(encounter)
    for _,r in ipairs(ns.Catalog.raids or{})do for _,b in ipairs(r.bosses or{})do if b.id==encounter then return b.name,"raid",r,b end end end
    for _,d in ipairs(ns.Catalog.dungeons or{})do for _,n in ipairs(d.npcs or{})do if n.encounterId==encounter then return n.name,"mythic",d,n end end end
    return L("Encounter").." "..tostring(encounter)
end
local function summary(e)
    local t=e.trigger or{}
    local when=t.type=="pull"and(tostring(t.delay or 0).."s "..L("after pull"))or t.type=="prepull"and(tostring(t.delay).."s "..L("before pull"))
        or t.type=="stage"and(L("phase").." "..tostring(t.stage).." +"..tostring(t.delay or 0).."s")
        or t.type=="exboss"and(tostring(t.timeleft or 3).."s "..L("before the trash cast"))
        or t.spellID and(ns.SpellLabel(t.spellID)..(t.type=="bwmsg"and(" · "..L("message"))or(" · "..tostring(t.leadTime or 3).."s "..L("before"))))
        or L("mechanic")
    local what=e.defensive and L("defensive set")or e.preset and L("defensive set")or(e.display and e.display.type)or L("defensive set")
    return when.."  ·  "..what
end
-- All reminders of this profile that belong to the current specialization or to everyone.
function ns.AllAlerts(spec,scope)
    local data=ns.Active()and ns.Active().data or{};local out={}
    for enc,entries in pairs(data.raidReminders or{})do for key,e in pairs(entries)do
        local content=e.content or ns.EncounterScope(tonumber(enc))or"raid"
        if(not e.defensive or e.defensive.specID==spec)and(scope=="all"or scope==content)then out[#out+1]={section="raidReminders",encounter=tonumber(enc),key=key,entry=e,scope=content}end
    end end
    for enc,bindings in pairs(ns.Get(data.abilityBindings,spec)or{})do for key,b in pairs(bindings)do
        local content=b.content or ns.EncounterScope(tonumber(enc))or"mythic"
        if scope=="all"or scope==content then out[#out+1]={section="abilityBindings",encounter=tonumber(enc),key=key,entry=b,scope=content,spell=tonumber(key)}end
    end end
    if scope~="raid"then for key,r in pairs(ns.Get(data.integrationRules,spec)or{})do
        if r.trigger and r.trigger.type=="exboss"then out[#out+1]={section="integrationRules",map=r.trigger.mapID,key=key,entry=r,scope="mythic"}end
    end end
    table.sort(out,function(a,b)return tostring(a.entry.name or a.key)<tostring(b.entry.name or b.key)end)
    return out
end
local function preview(item,spec)
    local e=item.entry
    if e.defensive or item.section~="raidReminders"then
        local key=e.defensive and e.defensive.preset or e.preset or ns.ScopeActive(ns.Active(),item.scope,spec)
        local spells=ns.Pick(ns.Get(ns.ScopePresets(ns.Active(),item.scope,spec),key))
        if #spells==0 then ns.CallExternal(true)else ns.Display({type="icon",spells=spells,text=nil,dur=4})end
    else ns.Display(e.display or{type="text",text=e.name})end
end
local function open(item)
    local state=kit.state;local e=item.entry;local c=e.catalog or{}
    local tab=item.scope=="raid"and"raid"or"mythic"
    state.tab=tab;kit.loadView();state.mode="mechanics";state.form=nil;state.timed=false;state.filter=""
    if item.section=="integrationRules"then state.group=c.groupId or item.map;state.entity=c.npcID;state.ability=e.trigger.spellID;state.ruleKey=item.key
    else
        local _,_,g,n=ns.EncounterName(item.encounter)
        state.group=c.groupId or(g and g.id);state.entity=c.npcID or(n and n.id)
        local t=e.trigger or{}
        if item.section=="abilityBindings"then state.ability=item.spell;state.ruleKey=item.key
        elseif t.type=="bwtimer"or t.type=="bwmsg"then state.ability=t.spellID;state.ruleKey=item.key
        else state.timed=true;state.ruleKey=item.key end
        if tab=="raid"and e.difficulties then state.difficulty=ns.Get(e.difficulties,16)and not ns.Get(e.difficulties,15)and 16 or 15 end
    end
    kit.refresh()
end
local function DrawAlerts(parent)
    local state=kit.state;local spec=state.spec;local d=state.drafts
    d.alertScope=d.alertScope or"all"
    kit.header(parent,L("Boss alerts"),L("Every reminder for your spec: switch off, test or edit."))
    W.Segmented(parent,{{value="all",label=L("All")},{value="mythic",label="Mythic+"},{value="raid",label=L("Raid")}},d.alertScope,620,0,300,function(v)d.alertScope=v;kit.refresh()end,"alerts-scope")
    local items=ns.AllAlerts(spec,d.alertScope)
    local groups,order={},{}
    for _,it in ipairs(items)do
        local title=it.section=="integrationRules"and((function()for _,g in ipairs(ns.Catalog.dungeons or{})do if g.mapID==it.map then return g.name..L(" · trash")end end;return L("Trash")end)())or ns.EncounterName(it.encounter)
        if not groups[title]then groups[title]={};order[#order+1]=title end;table.insert(groups[title],it)
    end
    table.sort(order)
    local list=W.Scroll(parent,0,56,920,536,"alerts:list");local y=6
    if #items==0 then W.Label(list,L("No reminders yet. Add them on the Mythic+, Raids or Timeline pages."),12,12,800,13,C.muted)end
    for _,title in ipairs(order)do
        W.Caption(list,title.."  ("..#groups[title]..")",8,y+4,600);y=y+26
        for _,it in ipairs(groups[title])do
            local id=it.section..":"..tostring(it.encounter or it.map)..":"..tostring(it.key)
            local row=W.Panel(list,4,y,884,40,C.raised,C.clear,8)
            W.Toggle(row,"",it.entry.enabled~=false,10,8,40,function(v)kit.done(ns.SetReminderEnabled(it.section,spec,it.encounter,it.key,v),nil,v and L("Reminder on")or L("Reminder off"))end,"alert-on:"..id)
            local spell=it.spell or(it.entry.trigger and it.entry.trigger.spellID);if spell then W.Icon(row,spell,58,8,24)end
            W.Label(row,it.entry.name or(spell and ns.SpellLabel(spell))or L("Reminder"),90,6,420,13,it.entry.enabled~=false and C.text or C.muted,true)
            W.Label(row,summary(it.entry),90,23,520,11,C.muted)
            W.Button(row,L("Test"),700,6,80,function()preview(it,spec);kit.notify(L("Display preview only"))end,false,"alert-test:"..id,{glyph="play",h=28})
            W.Button(row,L("Edit"),788,6,86,function()open(it)end,false,"alert-edit:"..id,{glyph="edit",h=28,kind="outline"})
            y=y+44
        end
        y=y+6
    end
    list:SetHeight(math.max(1,y))
end
ns.ExtraPages.alerts=DrawAlerts
