-- Land of C-call boundary errors
-- Most errors in here, unless they happen while loading, will simply cast a C-call boundary error, without as much as a hint that its in here its wrong
local gpuBoundTo = {}
local addresses = {}
local assigned = {}

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
				if self:getScreen () == address then return end 
				self.__screen = address

				for _, __address in ipairs ( self.__address ) do
					component.invoke ( __address, 'bind', address )
					gpuBoundTo [__address] = address
				end
			end,

			['setBackground'] = function ( self, color )
				for _,address in pairs ( self.__address ) do
					component.invoke ( address, 'setBackground', color )
				end
			end,
			['setForeground'] = function ( self, color )
				for _,address in pairs ( self.__address ) do
					component.invoke ( address, 'setForeground', color )
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
					self.__current = tostring(self)
					return component.invoke ( self.__current, key, ... )
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
				if o.__screen ~= false then
					component.invoke ( address, 'bind', o.__screen ) 
				end

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

		return self:refresh ()
	end,
}

for address in component.list ('gpu') do 
	gpu:addGPU (address) 
end

return gpu