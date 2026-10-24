-- Puzatik Defensive Planner string codec. One !PDP1: string carries every profile of a game
-- client (Mythic+ and raid data together): "!PDP1:" .. Base64(raw Deflate(CBOR(bundle))).
-- The codec is the addon's own and does not depend on any other addon's format.
local _,ns=...
local PREFIX="!PDP1:"
-- Strings made before the 0.7.3 rename start with !NDP1: and name the old addon; both are read.
local OLD_PREFIX,ADDON,OLD_ADDON="!NDP1:","PuzatikDefensivePlanner","NaowhDefensivePlanner"
local MAX_TEXT,MAX_RAW,MAX_ITEMS,MAX_PROFILES=1000000,8000000,2000000,50
ns.ExportPrefix=PREFIX

local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local lookup={};for i=1,#alphabet do lookup[alphabet:sub(i,i)]=i-1 end
lookup["-"]=62;lookup["_"]=63
-- Accepts the standard and the URL-safe alphabet, with or without padding.
function ns.Base64Decode(input)
    assert(type(input)=="string"and input:match("^[A-Za-z0-9_=/+%-]+$")and #input%4~=1,"Invalid Base64 text")
    local out,cache,bits={},0,0
    for i=1,#input do local ch=input:sub(i,i);if ch~="="then cache=cache*64+lookup[ch];bits=bits+6;if bits>=8 then bits=bits-8;local byte=math.floor(cache/2^bits);out[#out+1]=string.char(byte);cache=cache%2^bits end end end
    return table.concat(out)
end
function ns.Base64Encode(bytes)
    local out={}
    for i=1,#bytes,3 do
        local a,b,c=bytes:byte(i,i+2);local n=a*65536+(b or 0)*256+(c or 0)
        local s1,s2,s3,s4=math.floor(n/262144),math.floor(n/4096)%64,math.floor(n/64)%64,n%64
        out[#out+1]=alphabet:sub(s1+1,s1+1)..alphabet:sub(s2+1,s2+1)..(b and alphabet:sub(s3+1,s3+1)or"=")..(c and alphabet:sub(s4+1,s4+1)or"=")
    end
    return table.concat(out)
end

function ns.ReadCBOR(bytes,maxBytes,maxItems)
    maxBytes,maxItems=maxBytes or 4000000,maxItems or 300000
    assert(type(bytes)=="string"and #bytes<=maxBytes,"CBOR size limit exceeded")
    local at,count=1,0
    local function take(n)assert(n>=0 and at+n<=#bytes+1,"Truncated CBOR");local s=bytes:sub(at,at+n-1);at=at+n;return s end
    local function uint(n)local value=0;for byte in take(n):gmatch(".")do value=value*256+byte:byte()end;assert(value<=9007199254740991,"CBOR integer exceeds safe precision");return value end
    local function argument(ai)if ai<24 then return ai elseif ai==24 then return uint(1)elseif ai==25 then return uint(2)elseif ai==26 then return uint(4)elseif ai==27 then return uint(8)elseif ai==31 then return -1 end;error("Invalid CBOR argument")end
    local function float(n)
        local raw=take(n);local first,second=raw:byte(1,2);local sign=first>=128 and -1 or 1;local exponent,mantissa,bits,bias
        if n==2 then exponent=math.floor((first%128)/4);mantissa=(first%4)*256+second;bits=10;bias=15
        elseif n==4 then exponent=(first%128)*2+math.floor(second/128);mantissa=second%128;for i=3,4 do mantissa=mantissa*256+raw:byte(i)end;bits=23;bias=127
        else exponent=(first%128)*16+math.floor(second/16);mantissa=second%16;for i=3,8 do mantissa=mantissa*256+raw:byte(i)end;bits=52;bias=1023 end
        assert(exponent~=bias*2+1,"Non-finite CBOR number")
        if exponent==0 then return sign*2^(1-bias)*(mantissa/2^bits)end
        return sign*2^(exponent-bias)*(1+mantissa/2^bits)
    end
    local item
    item=function(depth)
        count=count+1;assert(depth<=32 and count<=maxItems,"CBOR structure limit exceeded")
        local h=uint(1);local major,ai=math.floor(h/32),h%32
        if major==7 then if ai==20 then return false elseif ai==21 then return true elseif ai==22 then return nil elseif ai==25 then return float(2)elseif ai==26 then return float(4)elseif ai==27 then return float(8)end;error("Unsupported CBOR value")end
        local n=argument(ai)
        if major==0 or major==1 then assert(n>=0,"Invalid CBOR integer");return major==0 and n or -1-n end
        if major==2 or major==3 then assert(n>=0,"Indefinite CBOR strings are unsupported");return take(n)end
        if major==4 or major==5 then
            local value,seen={},{};local i=0
            while n<0 and bytes:byte(at)~=255 or n>=0 and i<n do
                i=i+1;local key=major==4 and i or item(depth+1)
                assert((type(key)=="string"or type(key)=="number")and not seen[key]and key~="__proto__"and key~="constructor"and key~="prototype","Invalid or duplicate CBOR key");seen[key]=true
                value[key]=item(depth+1)
            end
            if n<0 then assert(take(1):byte()==255,"Invalid CBOR break")end;return value
        end
        error("Unsupported CBOR type or tag")
    end
    local value=item(0);assert(at==#bytes+1,"Trailing CBOR data");return value
end

-- Lua 5.1 has no string.pack, so doubles are assembled by hand.
local function frexp(x)
    if math.frexp then return math.frexp(x)end
    local e=math.floor(math.log(x)/math.log(2))+1;local m=x/2^e
    if m>=1 then m=m/2;e=e+1 elseif m<0.5 then m=m*2;e=e-1 end;return m,e
end
local function double(x)
    if x==0 then return string.char(251,0,0,0,0,0,0,0,0)end
    local sign=x<0 and 128 or 0;x=math.abs(x)
    local m,e=frexp(x);local exponent=e+1022
    if exponent<=0 then return string.char(251,sign,0,0,0,0,0,0,0)end
    local mantissa=(m*2-1)*2^52
    local out={251,sign+math.floor(exponent/16),(exponent%16)*16+math.floor(mantissa/2^48)}
    mantissa=mantissa%2^48
    for i=5,0,-1 do out[#out+1]=math.floor(mantissa/2^(i*8))%256 end
    return string.char((unpack or table.unpack)(out))
end
local function head(major,n)
    if n<24 then return string.char(major*32+n)
    elseif n<256 then return string.char(major*32+24,n)
    elseif n<65536 then return string.char(major*32+25,math.floor(n/256),n%256)
    elseif n<4294967296 then return string.char(major*32+26,math.floor(n/16777216),math.floor(n/65536)%256,math.floor(n/256)%256,n%256)end
    local hi,lo=math.floor(n/4294967296),n%4294967296
    return string.char(major*32+27,math.floor(hi/16777216),math.floor(hi/65536)%256,math.floor(hi/256)%256,hi%256,math.floor(lo/16777216),math.floor(lo/65536)%256,math.floor(lo/256)%256,lo%256)
end
local function keyOrder(a,b)
    local ta,tb=type(a),type(b)
    if ta~=tb then return ta=="number"end
    return a<b
end
-- A table whose keys are exactly 1..n becomes a CBOR array, any other table a map with
-- sorted keys, so the same profile always encodes to the same string.
function ns.WriteCBOR(value)
    local out,count,active={},0,{}
    local function item(v,depth)
        count=count+1;assert(depth<=32 and count<=MAX_ITEMS,"Profile data is too deeply nested or too large")
        local t=type(v)
        if t=="boolean"then out[#out+1]=string.char(v and 245 or 244)
        elseif t=="number"then
            assert(v==v and v~=math.huge and v~=-math.huge,"Profile contains a non-finite number")
            if v==math.floor(v)and math.abs(v)<=9007199254740991 then out[#out+1]=v>=0 and head(0,v)or head(1,-1-v)else out[#out+1]=double(v)end
        elseif t=="string"then out[#out+1]=head(3,#v);out[#out+1]=v
        elseif t=="table"then
            assert(not active[v],"Profile contains a cyclic table");active[v]=true
            local keys,n={},0
            for k in pairs(v)do local kt=type(k);assert(kt=="string"or kt=="number","Profile contains an unsupported key");n=n+1;keys[n]=k end
            local array=n>0;for i=1,n do if v[i]==nil then array=false;break end end
            if array then out[#out+1]=head(4,n);for i=1,n do item(v[i],depth+1)end
            else table.sort(keys,keyOrder);out[#out+1]=head(5,n);for _,k in ipairs(keys)do item(k,depth+1);item(v[k],depth+1)end end
            active[v]=nil
        else error("Profile contains unsupported "..t.." data")end
    end
    item(value,0)
    return table.concat(out)
end

local function Newer(required,current)
    local a,b={},{};for n in tostring(required):gmatch("%d+")do a[#a+1]=tonumber(n)end;for n in tostring(current):gmatch("%d+")do b[#b+1]=tonumber(n)end
    for i=1,math.max(#a,#b)do if(a[i]or 0)~=(b[i]or 0)then return(a[i]or 0)>(b[i]or 0)end end
    return false
end
ns.VersionNewer=Newer

-- profiles is a list of profile tables; active names the one to select after import.
function ns.EncodeProfiles(profiles,active)
    local ok,result=pcall(function()
        assert(type(profiles)=="table"and #profiles>0,"No profiles to export")
        assert(#profiles<=MAX_PROFILES,"Export holds at most "..MAX_PROFILES.." profiles")
        local need="0.3.0"
        for _,p in ipairs(profiles)do
            assert(ns.Validate(p),"Profile "..tostring(p and p.name).." contains invalid data")
            assert(p.client==ns.Client(),"Profile "..tostring(p.name).." belongs to another game client")
            local m=p.minimumAddon or ns.MinimumAddon(p.data);if Newer(m,need)then need=m end
        end
        local bundle={v=1,addon=ADDON,version=ns.version,client=ns.Client(),minimumAddon=need,active=active,profiles=profiles}
        local text=PREFIX..ns.Base64Encode(LibStub("LibDeflate"):CompressDeflate(ns.WriteCBOR(bundle)))
        assert(#text<=MAX_TEXT,"Export exceeds 1 MB. Delete unused profiles or reminders first.")
        return text
    end)
    if not ok then return nil,(tostring(result):gsub("^.-:%d+: ",""))end
    return result
end
local function Native(text)local head=text:sub(1,#PREFIX);return head==PREFIX or head==OLD_PREFIX end
function ns.IsNativeExport(text)return type(text)=="string"and Native((text:gsub("%s+","")))end
-- Returns the bundle with its profiles validated, or nil and a reason.
function ns.DecodeProfiles(input)
    local ok,result=pcall(function()
        assert(type(input)=="string","Paste a "..PREFIX.." string")
        input=input:gsub("%s+","")
        assert(Native(input),"Expected a "..PREFIX.." string")
        assert(#input<=MAX_TEXT,"Import string exceeds 1 MB")
        local bytes=ns.Base64Decode(input:sub(#PREFIX+1))
        local raw=LibStub("LibDeflate"):DecompressDeflate(bytes)
        assert(raw and #raw<=MAX_RAW,"Invalid compressed data or size limit exceeded")
        local bundle=ns.ReadCBOR(raw,MAX_RAW,MAX_ITEMS)
        assert(type(bundle)=="table"and bundle.v==1 and(bundle.addon==ADDON or bundle.addon==OLD_ADDON),"Not a Puzatik Defensive Planner export")
        if type(bundle.minimumAddon)=="string"and type(ns.version)=="string"and Newer(bundle.minimumAddon,ns.version)then error("This export needs Puzatik Defensive Planner "..bundle.minimumAddon.." or newer")end
        assert(type(bundle.profiles)=="table"and #bundle.profiles>0 and #bundle.profiles<=MAX_PROFILES,"Export holds no profiles")
        for i,p in ipairs(bundle.profiles)do
            assert(type(p)=="table"and p.client==bundle.client,"Profile "..i.." belongs to another game client")
            if type(p.minimumAddon)=="string"and Newer(p.minimumAddon,ns.version)then error("Profile "..tostring(p.name).." needs Puzatik Defensive Planner "..p.minimumAddon.." or newer")end
            assert(ns.Validate(p),"Profile "..tostring(p.name).." contains unsupported data")
        end
        return bundle
    end)
    if not ok then return nil,(tostring(result):gsub("^.-:%d+: ",""))end
    return result
end
