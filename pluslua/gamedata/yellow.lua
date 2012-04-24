
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
		print(gh_ChineseName(g))
	end
	print()
end
