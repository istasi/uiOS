local base = {
	['pairs'] = pairs,
	['ipairs'] = ipairs,

	['tostring'] = tostring,
	['tonumber'] = tonumber,

	['type'] = type,
	['next'] = next,

	['error'] = error,

	['load'] = load,
	['pcall'] = pcall,

	['setmetatable'] = setmetatable,
	['getmetatable'] = getmetatable,

	['table'] = {
		['insert'] = table.insert,
		['remove'] = table.remove,
		['concat'] = table.concat,
		['unpack'] = table.unpack,
		['pack'] = table.pack,
		['sort'] = table.sort,
	},
	['string'] = {
		['rep'] = string.rep,
		['match'] = string.match,
		['char'] = string.char,
		['byte'] = string.byte,
		['find'] = string.find,
		['format'] = string.format,
		['len'] = string.len,
		['gmatch'] = string.gmatch,
		['sub'] = string.sub,
		['gsub'] = string.gsub,
		['lower'] = string.lower,
		['upper'] = string.upper,
		['match'] = string.match,
		['reverse'] = string.reverse,
	},

	['computer'] = {
		['totalMemory'] = computer.totalMemory,
		['freeMemory'] = computer.freeMemory,

		['uptime'] = computer.uptime,
		['shutdown'] = computer.shutdown,
		['pullSignal'] = computer.pullSignal,
		['pushSignal'] = computer.pushSignal,
	},

	['coroutine'] = {
		['create'] = coroutine.create,
		['resume'] = coroutine.resume,
		['status'] = coroutine.status,
		['running'] = coroutine.running,
		['wrap'] = coroutine.wrap,
	},

	['unicode'] = {
		['len'] = unicode.len,
		['char'] = unicode.char,
		['byte'] = unicode.byte,
	},

	['math'] = {
		['abs'] = math.abs,
		['acos'] = math.acos,
		['asin'] = math.asin, 
		['atan'] = math.atan,
		['atan2'] = math.atan2,
		['ceil'] = math.ceil,
		['cos'] = math.cos, 
		['cosh'] = math.cosh,
		['deg'] = math.deg,
		['exp'] = math.exp,
		['floor'] = math.floor, 
		['fmod'] = math.fmod,
		['frexp'] = math.frexp,
		['huge'] = math.huge, 
		['ldexp'] = math.ldexp,
		['log'] = math.log,
		['log10'] = math.log10,
		['max'] = math.max, 
		['min'] = math.min,
		['modf'] = math.modf,
		['pi'] = math.pi,
		['pow'] = math.pow, 
		['rad'] = math.rad,
		['random'] = math.random,
		['sin'] = math.sin,
		['sinh'] = math.sinh, 
		['sqrt'] = math.sqrt,
		['tan'] = math.tan,
		['tanh'] = math.tanh
	},
}
local custom = {}

local function c ( t, o )
	o = o or {}

	for k,v in pairs ( t ) do
		if type(v) == 'table' and v.type == nil then
			o[k] = c(v)
		else
			o[k] = v
		end
	end

	return o
end


local environment = {}
function environment.base ( merge )
	merge = merge or {}
	local b = {}
	
	b = c(b,base)
	b = c(b,custom)
	b = c(b,merge)
	
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

--[[
function environment.build ( merge )
	local b = environment.base ( merge )

	environment [ (#environment + 1) ] = b
	return #environment
end
]]



return environment