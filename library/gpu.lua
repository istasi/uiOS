local __log = false
local handle = nil

local function log (message)
	if __log == true then
		if handle == nil then handle = system.filesystem.open ('/log/gpu.log','a') end
		handle:write ( tostring(message) .. '\n' )

		system.event:off('timer'):timer ( 1, function ()
			handle:close ()
			handle = nil
		end )
	end
end

-- Land of C-call boundary errors
-- Most errors in here, unless they happen while loading, will simply cast a C-call boundary error, without as much as a hint that its in here its wrong
local gpuBoundTo = {}
local addresses = {}
local assigned = {}


local _cinvoke = component.invoke
local cinvoke = function ( address, call, ... )
	local args = {...}
	log ( tostring(address) ..', '.. tostring(call) ..', '.. table.concat ( args, ', ' ) )

	local result = table.pack (pcall ( _cinvoke, address, call, table.unpack (args) ))
	local state = result [1]
	result = table.pack (select ( 2, table.unpack ( result ) )) -- cause retarded table.remove breaks table.unpack

	if state == true then
		return table.unpack ( result )
	else
		local arg = '"' .. address .. '", "' .. call .. '", '
		for _,value in ipairs (args) do
			arg = arg .. '"' .. tostring(value) .. '", '
		end
		arg = arg:sub ( 1, -3 )

		system.event:signal ( 1, 'error', 'GPU (' .. address ..') attempted to do "gpu.' .. call .. '" resulted in:\n   "' .. result[1] .. '"\n\nArguments given: ' .. arg .. '\n          count: ' .. #{...}  .. '\n\n' .. debug.traceback () )
	end
end

local gpu = {
	['get'] = function ( self )
		local o = setmetatable ({
			['__last'] = 1,
			['__address'] = {addresses[1]},
			['__screen'] = false,

			['getScreen'] = function ( self )
				return self.__screen
			end,

			['bind'] = function ( self, address )
				self.__screen = address

				for _, __address in ipairs ( self.__address ) do
					if gpuBoundTo [__address] ~= address then
						cinvoke ( __address, 'bind', address )
						gpuBoundTo [__address] = address
					end
				end
			end,

			['setBackground'] = function ( self, color )
				for _,address in pairs ( self.__address ) do
					cinvoke ( address, 'setBackground', color )
				end
			end,
			['setForeground'] = function ( self, color )
				for _,address in pairs ( self.__address ) do
					cinvoke ( address, 'setForeground', color )
				end
			end,
		}, {
			['__tostring'] = function ( self )
				self.__last = self.__last + 1
				if self.__last > #self.__address then
					self.__last = 1
				end

				return self.__address [self.__last]
			end,

			['__index'] = function ( self, key )
				return function ( self, ... )
					if type(self.__screen) ~= 'string' then
						error ( 'trying to call gpu.' .. key .. ', but no screen have been bound yet' )
					end

					self:bind ( self.__screen )

					self.__current = tostring(self)
					return cinvoke ( self.__current, key, ... )
				end
			end,
		})

		table.insert ( assigned, o )
		self:refresh ()

		return o
	end,
	['refresh'] = function ( self )
		local gpu = {}
		for k,v in pairs (addresses) do table.insert (gpu,v) end

		for _,o in ipairs(assigned) do o.__address = {} end
		while gpu[1] ~= nil do
			local c = #gpu
			for _,o in ipairs (assigned) do
				local address = table.remove (gpu, #gpu)
				
				table.insert ( o.__address, address )
			end

			if c == #gpu then
				gpu [1] = nil
			end
		end

		return self
	end,
	['addGPU'] = function ( self, _address )
		table.insert ( addresses, _address )

		return self:refresh ()
	end,
	['removeGPU'] = function ( self, _address )
		for i,address in ipairs ( addresses ) do
			if address == _address then
				table.remove ( addresses, i )
			end
		end

		gpuBoundTo [_address] = nil
		return self:refresh ()
	end,
}

for address in component.list ('gpu') do 
	gpu:addGPU (address) 
end

return gpu