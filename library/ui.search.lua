return function ( self, query )
	local onlyThis = false
	if query:match ('^>') then
		onlyThis = true
		query = query:gsub ( '^>%s*', '' )
	end

	if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
		error ( 'ui.element:search (), self is missing, or not of type ui.element' )
	end
	if type (query) ~= 'string' then
		error ( 'ui.element:setAttribute (), requires argument provided to be of type string' )
	end

	local o = {}
	for _,child in ipairs ( self.children ) do
		if query == '*' then
			table.insert ( o, child )

		elseif query:match (':type%(.-%)$') then
			local match = query:match (':type%((.-)%)$')
			if child.type == match then
				table.insert ( o, child )
			end

		elseif query == ':has(zone)' and child.__zone ~= nil then
			table.insert ( o, child )

		elseif child.name == query then
			table.insert ( o, child )
			
		end

		if onlyThis == false then
			local _o = child:search ( query )
			for _, child in ipairs ( _o ) do
				table.insert ( o, child )
			end
		end
	end

	o ['each'] = function ( self, callback )
		local continue = true

		for _, element in ipairs (self) do
			if callback ( element ) == false then
				continue = false
			end
		end
	end
	o.n = #o -- wonder why im setting this?

	return o
end