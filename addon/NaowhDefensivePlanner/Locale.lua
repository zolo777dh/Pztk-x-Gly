-- Interface strings. The addon ships in English; UI text goes through ns.L so a
-- translation table can be added later without touching the pages.
local _,ns=...
local translations={}
function ns.L(text)return translations[text]or text end
function ns.Upper(text)return tostring(text):upper()end
