local _, ns = ...
function ns.Client()
    local version, _, _, interface = GetBuildInfo()
    return (interface == 16001 or (type(version) == "string" and version:match("^1%.60%."))) and "forever" or "retail"
end
function ns.Store()
    PztkRemindersDB = PztkRemindersDB or { clients = {} }
    PztkRemindersDB.clients = PztkRemindersDB.clients or {}
    local client = ns.Client()
    PztkRemindersDB.clients[client] = PztkRemindersDB.clients[client] or {profiles={},history={}}
    return PztkRemindersDB.clients[client]
end
local function Data(value, seen, depth, budget)
    if depth > 32 then return false end
    local kind = type(value)
    if kind == "number" then return value == value and math.abs(value) < math.huge end
    if kind ~= "table" then return kind == "string" or kind == "boolean" or kind == "nil" end
    if seen[value] then return false end
    seen[value] = true
    for key, child in pairs(value) do
        budget[1] = budget[1] - 1
        if budget[1] < 0 or (type(key) ~= "string" and type(key) ~= "number") or not Data(child, seen, depth+1,budget) then return false end
    end
    seen[value] = nil; return true
end
local function Number(v, min, max, optional)
    return (optional and v == nil) or (type(v) == "number" and v >= min and v <= max)
end
local function ID(v)return Number(v,1,100000000) and v % 1 == 0 end
local function Flags(t)
    if t == nil then return true end
    if type(t) ~= "table" then return false end
    for _,v in pairs(t)do if type(v) ~= "boolean" then return false end end
    return true
end
local function Binding(b)
    return type(b)=="table" and (b.enabled==nil or type(b.enabled)=="boolean") and (b.preset==nil or type(b.preset)=="string") and Number(b.leadTime,-120,120,true)
end
function ns.Validate(profile)
    if type(profile) ~= "table" or profile.format ~= 1 or profile.addon ~= "PztkReminders" or type(profile.name) ~= "string" or #profile.name > 200 or type(profile.data) ~= "table" then return false end
    if profile.client ~= "retail" and profile.client ~= "forever" then return false end
    if not Data(profile, {}, 0, {100000}) then return false end
    for _, key in ipairs({"presets","activePreset","abilityBindings","integrationRules","raidReminders"}) do if profile.data[key] ~= nil and type(profile.data[key]) ~= "table" then return false end end
    for _, presets in pairs(profile.data.presets or {})do
        if type(presets) ~= "table" then return false end
        for _,preset in pairs(presets)do
            if type(preset) ~= "table" or type(preset.list) ~= "table" or not Flags(preset.together) then return false end
            local count=0
            for index,spell in pairs(preset.list)do if not ID(index)or not ID(spell)then return false end;count=count+1 end
            if count>200 then return false end
            for i=1,count do if not preset.list[i]then return false end end
        end
    end
    for _,value in pairs(profile.data.activePreset or {})do if type(value)~="string"then return false end end
    for _,encounters in pairs(profile.data.abilityBindings or {})do
        if type(encounters)~="table"then return false end
        for _,bindings in pairs(encounters)do if type(bindings)~="table"then return false end;for _,binding in pairs(bindings)do if not Binding(binding)then return false end end end
    end
    for _,rules in pairs(profile.data.integrationRules or {})do
        if type(rules)~="table"then return false end
        for _,rule in pairs(rules)do if not Binding(rule)or type(rule.trigger)~="table"or rule.trigger.type~="exboss"or not ID(rule.trigger.mapID)or not ID(rule.trigger.spellID)or not Number(rule.trigger.timeleft,0,120,true)then return false end end
    end
    for _, entries in pairs(profile.data.raidReminders or {}) do
        if type(entries) ~= "table" then return false end
        for _, entry in pairs(entries) do
            if type(entry) ~= "table" or type(entry.trigger) ~= "table" or type(entry.display) ~= "table" then return false end
            local trigger = entry.trigger
            if trigger.type ~= "pull" and trigger.type ~= "stage" and trigger.type ~= "bwtimer" and trigger.type ~= "bwmsg" then return false end
            if not Number(trigger.delay,0,7200,true)or not Number(trigger.leadTime,0,120,true)or not Number(trigger.stage,0.01,100,true)then return false end
            if (trigger.type=="bwtimer"or trigger.type=="bwmsg")and not ID(trigger.spellID)then return false end
            if trigger.type=="stage"and not trigger.stage then return false end
            if not Flags(entry.difficulties)then return false end
            local display=entry.display
            local types={icon=true,text=true,bar=true,circle=true,chat=true,raidframeGlow=true,nameplateGlow=true}
            if not types[display.type]or not Number(display.dur,0.1,120,true)or (display.spellID and not ID(display.spellID))then return false end
            for _,key in ipairs({"text","sound","ttsText","glowTarget"})do if display[key]~=nil and type(display[key])~="string"then return false end end
            if display.tts~=nil and type(display.tts)~="boolean"then return false end
            if entry.target and type(entry.target) ~= "table" then return false end
            for _, key in ipairs({"roles","specs","classes","names","subgroups"}) do if entry.target and entry.target[key] and not Flags(entry.target[key]) then return false end end
        end
    end
    return true
end
function ns.Decode(input)
    if type(input) ~= "string" then return nil, "Paste a PZTK1 string" end
    input = input:gsub("%s+", "")
    if input:sub(1,6) ~= "PZTK1:" or #input > 130000 then return nil, "Expected PZTK1 string under 130 KB" end
    local ld, ser = LibStub("LibDeflate"), LibStub("LibSerialize")
    local bytes = ld:DecodeForPrint(input:sub(7))
    local raw = bytes and ld:DecompressDeflate(bytes)
    if not raw or #raw > 4000000 then return nil, "Invalid compressed profile or size limit exceeded" end
    local ok, profile = ser:Deserialize(raw)
    if not ok or not ns.Validate(profile) then return nil, "Unsupported profile data" end
    return profile
end
function ns.Import(input)
    local profile, error = ns.Decode(input)
    if not profile then return nil, error end
    if profile.client ~= ns.Client() then return nil, "Profile belongs to " .. profile.client .. "; use the matching game client" end
    local store = ns.Store()
    local name, index = profile.name, 2
    while store.profiles[name] do name = profile.name .. " " .. index; index = index+1 end
    profile.name = name; store.profiles[name] = profile; store.active = name; ns.Reset()
    return name
end
function ns.Export()
    local profile = ns.Active()
    if not profile then return nil, "No active profile" end
    local raw = LibStub("LibSerialize"):Serialize(profile)
    local ld = LibStub("LibDeflate")
    return "PZTK1:" .. ld:EncodeForPrint(ld:CompressDeflate(raw))
end
