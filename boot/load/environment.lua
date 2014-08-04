local base = {}
local custom = {}

local environment = {}
function environment.base ( merge )
	local b = {}
	for k,v in pairs (base) do  b[k]=v end
	for k,v in pairs (custom) do b[k]=v end
	for k,v in pairs (merge) do b[k]=v end

	return b
end

function environment.set ( key, value )
	custom [key] = value return true
end
function environment.get ( key )
	return custom [key]
end

function environment.remove ( key )
	if base [key] ~= nil then base [key] = nil end
	if custom [key] ~= nil then custom [key] = nil end
end

for k,v in pairs (_G) do base [k]=v end

return environment