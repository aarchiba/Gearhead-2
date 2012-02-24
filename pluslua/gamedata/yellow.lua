
GG = {}

function startswith(pre, s)
    return string.find(s, pre) == 1
end
for k,v in pairs(_G) do
    if startswith("GG_", k) then
        GG[v] = k
    end
end

gh_Print("Yellow button!")

buruburu = gh_CreateAndGivePart( "SAN-X9 Buru Buru" )

gh_Print(string.format("%s\tS:%d\tV:%d",
    GG[buruburu:GetG()],
    buruburu:GetS(),
    buruburu:GetV()));

-- gh_Print(type(buruburu)) -- it's a table

p = gh[gh_RawFollowLink(buruburu, LINK_SUBCOM)]
gh_Print(type(p))
gh_Print(string.format("%s\tS:%d\tV:%d",
    GG[p:GetG()],
    p:GetS(),
    p:GetV()));

-- buruburu has three entries:
-- ptr is a userdata
-- stat is a table
-- v is a table
--[[
for k in pairs(buruburu) do
    gh_Print(k)
    gh_Print(type(buruburu[k]))
end
]]

-- buruburu.stat has just one element:
-- ptr is a userdata
--[[
for k in pairs(buruburu.stat) do
    gh_Print(k)
    gh_Print(type(buruburu.stat[k]))
end
]]

-- buruburu.v is an empty table
--[[
for k in pairs(buruburu.v) do
    gh_Print(k)
    gh_Print(type(buruburu.v[k]))
end
]]


