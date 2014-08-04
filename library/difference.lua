local data = {}
local default = {}

local difference = {
	['type'] = 'difference',
	['default'] = nil,

	['setDefault'] = function ( self, _table )
		if type (_table) ~= 'table' then error ( 'Supplied argument is not a table' ) end

		default = _table
	end,
	['each'] = function ( self, callback )
		for i in ipairs ( data ) do
			local o = {}
			for k,v in pairs ( default ) do o[k]=v end
			for k,v in pairs ( data[i] ) do o[k]=v end

			local mt = getmetatable(default)
			o = setmetatable(o,mt)

			callback (o)
		end
	end,
	['add'] = function ( self, _table )
		for k,v in pairs ( default ) do
			if v == _table[k] then
				_table[k] = nil
			end
		end

		table.insert ( data, _table )
		return #data
	end,
	['rawget'] = function ( self, key )
		return data [key]
	end,
}

setmetatable (difference, {
	['__index'] = function ( self, key )
		if data [key] == nil then return nil end

		local o = {}
		for k,v in pairs ( default ) do o[k]=v end
		for k,v in pairs ( data[key] ) do o[k]=v end

		local mt = getmetatable(default)
		o = setmetatable(o,mt)

		return o
	end,
	['__newindex'] = function ( self, key, value )
		if type(value) == 'table' then
			for k,v in pairs ( default ) do
				if v == value[k] then
					value[k] = nil
				end
			end

			data [key] = value
		end
	end,
})

return difference
