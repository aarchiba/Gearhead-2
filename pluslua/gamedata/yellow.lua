
GG = {}

function startswith(pre, s)
    return string.find(s, pre) == 1
end
for k,v in pairs(_G) do
    if startswith("GG_", k) then
        GG[v] = k
    end
end

print("Yellow button!")

for _,g in ipairs({"M", "F", nil}) do
	for i=1,10 do
		print(gh_MakePirate(gh_GHARName(g)))
	end
	print()
end
--[[
for k,v in pairs(gh_GetFilenameConstants()) do
	print(k.."\t"..v)
end
]]

--buruburu = gh_CreateAndGivePartMatching{DESIG="SAN-X9"}
--buruburu = gh_CreateAndGivePart( "SAN-X9 Buru Buru" )
--[[
buruburu = gh_CreatePartMatching{DESIG="SAN-X9"}
]]
--[[
print(string.format("%s\tS:%d\tV:%d",
    GG[buruburu:GetG()],
    buruburu:GetS(),
    buruburu:GetV()));

function printSAtts(v)
    S = gh_GetSAtts(v)
    if S ~= nil then 
        for k2, v2 in pairs(S) do
            print(k2 .. " " .. v2)
        end
    else
        print("nil")
    end
end

S = gh_GetSAtts(buruburu)
S["FOO"] = "Bar"
gh_SetSAtts(buruburu, S)

printSAtts(buruburu)

print()

]]
--[[
for g in siblings(gh_StockList(LIST_STANDARD)) do
    print(gh_GetName(g))
end
]]

--[[
for g in geartree(buruburu) do
    print(gh_GetName(g))
end
]]

--[[
for k,v in pairs(gh_FindGears{DESIG="SAN-X9"}) do
    printSAtts(v)
    print()
end
]]
-- gh_Print(type(buruburu)) -- it's a table

--[[
p = gh[gh_RawFollowLink(buruburu, LINK_SUBCOM)]
print(type(p))
print(string.format("%s\tS:%d\tV:%d",
    GG[p:GetG()],
    p:GetS(),
    p:GetV()));
]]

--[[
S = gh_GetSAtts(buruburu)
for k,v in pairs(S) do
    print(k .. " " .. v)
end
]]

--[[
print()
EL = gh[gh_GetStandardEquipmentList()]
while EL ~= nil do
    print(gh_GetSAtts(EL).DESIG)
    EL = gh[gh_RawFollowLink(EL, LINK_NEXT)]
end
]]

--[[
for k,v in pairs(gh) do
    print(k)
    printSAtts(v)
    print()
end
]]

--[[
orig = nil
for k,v in pairs(gh_FindGears{NAME="Crystal Skull"}) do
    printSAtts(v)
    print()
    orig = v
end
]]

--[[
print "Cloning that object"
w = gh_CloneGear(orig)
printSAtts(w)
]]


-- buruburu has three entries:
-- ptr is a userdata
-- stat is a table
-- v is a table
--[[
for k in pairs(buruburu) do
    print(k)
    print(type(buruburu[k]))
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


