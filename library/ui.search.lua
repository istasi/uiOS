return function ( self, query )
	if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
		error ( 'ui.element:search (), self is missing, or not of type ui.element' )
	end
	if type (query) ~= 'string' then
		error ( 'ui.element:setAttribute (), requires argument provided to be of type string' )
	end

	local o = {}
	for _,child in ipairs ( self.children ) do
		if query:match (':type%(.-%)$') then
			local match = query:match (':type%((.-)%)$')
			if child.type == match then
				table.insert ( o, child )
			end
		elseif query == ':has(zone)' and child.__zone ~= nil then
			table.insert ( o, child )
		elseif child.name == query then
			table.insert ( o, child )
		end

		local _o = child:search ( query )
		for _, child in ipairs ( _o ) do
			table.insert ( o, child )
		end
	end

	o.n = #o
	return setmetatable (o, {		-- to enable the syntax of :search ('program'):attr ( 'background-color', '0x000000' ) despite returning a table with posible multiply elements
		['__index'] = function ( self, key )
			if o.n < 1 then return nil end

			if type(o[1][key]) == 'function' then
				return function ( ... )
					local args = {...}
					table.remove ( args, 1 )

					for _,element in ipairs (self) do
						local r = element [key] ( element, table.unpack ( args ) )

						if (r ~= nil and r ~= element) or r == false then return r end
					end

					return self
				end
			end
		end,
	})
end