
-- Browse all gears

g = gh_CreateAndGivePart("SAN-X9 Buru Buru")

function QueryUser(items, title)
	gh_InitMenu()
	for i,k in ipairs(items) do
		gh_AddMenuItem(k,i)
	end
	if title==nil then 
		title=''
	end
	n = gh_QueryMenu(title)
	return items[items[n]]
end

while g~=nil do
	m = gh_InitMenu()
	options = {}
	table.insert(options,"parent")
	options.parent = g:Parent()
	for s in subcomponents(g) do
		table.insert(options,s:Name())
		options[s:Name()] = s
	end
	for s in inventory(g) do
		table.insert(options,s:Name())
		options[s:Name()] = s
	end
	table.insert(options,"Exit")
	g = QueryUser(options, g:Name())
end

