-- This should not be used by anything but ui.element
-- far too limited in usage for general purpose.

local map = {}
local element = {
	['type'] = 'zone.element',

	['x'] = nil,
	['y'] = nil,
	['width'] = nil,
	['height'] = nil,
	['values'] = 'default',

	['down'] = function ( self )
		if type (self) ~= 'table' or self.type:match ('^zone%.element') == nil then
			error ( 'zone.element:down (), self is missing, or not of type zone.element' )
		end

		for i = 1,#map do
			if map[i] == self and i > 1 then
				table.remove ( map, i )
				table.insert ( map, i - 1, self )
			end
		end
	end,
	['below'] = function ( self, target )
		if type (self) ~= 'table' or self.type:match ('^zone%.element') == nil then
			error ( 'zone.element:below (), self is missing, or not of type zone.element' )
		end
		if type (target) ~= 'table' or target.type:match ('^zone%.element') == nil then
			error ( 'zone.element:below (), target is missing, or not of type zone.element' )
		end

		local targetPosition = false
		local selfPosition = false

		for i, element in ipairs ( map ) do
			if element == self then
				if targetPosition == false then
					return self
				end
				selfPosition = i
			end

			if element == target then
				targetPosition = i
			end
		end

		table.remove ( map, selfPosition )
		table.insert ( map, targetPosition, self )
		return self
	end,

	['up'] = function ( self )
		if type (self) ~= 'table' or self.type:match ('^zone%.element') == nil then
			error ( 'zone.element:up (), self is missing, or not of type zone.element' )
		end

		for i = 1,#map do
			if map[i] == self and i < #map then
				table.remove ( map, i )
				table.insert ( map, i + 1, self )

				i = i + 1
			end
		end
	end,
	['above'] = function ( self, target )
		if type (self) ~= 'table' or self.type:match ('^zone%.element') == nil then
			error ( 'zone.element:above (), self is missing, or not of type zone.element' )
		end
		if type (target) ~= 'table' or target.type:match ('^zone%.element') == nil then
			error ( 'zone.element:above (), target is missing, or not of type zone.element' )
		end

		local targetPosition = false
		local selfPosition = false

		for i, element in ipairs ( map ) do
			if element == self then
				selfPosition = i
			end

			if element == target then
				if selfPosition == false then
					return self
				end
			end
		end

		table.remove ( map, selfPosition )
		table.insert ( map, targetPosition + 1, self )
		return self
	end,

	['remove'] = function ( self )
		for i = 1,#map do
			if map[i] == self then
				table.remove ( map, i )
			end
		end
	end,
	['relate'] = function ( self, element )
		self.relation = element
	end,
	['using'] = function ( self, element )
		if (element.x == nil or element.y == nil or element.width == nil or element.height == nil) and type(element.attr) ~= 'function' then
			error ( 'zone.element.using(), element provided does not contain information regarding its location.' )
		end

		self.using = element
	end,
}

local zone = {}
zone = {
	['type'] = 'zone',

	['add'] = function ( x, y, width, height, values )
		local o = {}
		for k,v in pairs ( element ) do o[k]=v end

		if type(x) == 'table' then
			o:using(x)

			o.values = y
		else
			o.x = x
			o.y = y 
			o.width = width
			o.height = height

			o.values = values
		end

		table.insert ( map, o )
		return o
	end,
	['get'] = function ( x, y, start )
		if x == nil or y == nil then error ( 'zone.get (), x or y is missing.' ) end

		start = start or #map
		for i = start, 0, -1 do
			local element = map[i]

			if element ~= nil then
				if element.using ~= nil then
					local x,y = element.using:__computed ('XY')

					element ['x'] = math.floor(x)
					element ['y'] = math.floor(y)
					element ['width'] = element.using:__computed ('width')
					element ['height'] = element.using:__computed ('height')
				end

				element.__zIndex = i
				if element.relation ~= nil then
					if type(element.relation) ~= 'table' and element.relation.type ~= 'zone.element' then error ( 'zone.get (), attempted to access invalid zone.element.relation' ) end

					if x >= element.relation.x + element.x - 1 and x <= element.relation.x + element.x + element.width then
						if y >= elment.relation.y + element.y - 1 and y <= element.relation.y + element.y + element.height then
							return element
						end
					end

				else
					if element.x == nil then
						error ( tostring(element.values.name) )
					end
					if x >= element.x and x <= element.x + element.width - 1 then
						if y >= element.y and y <= element.y + element.height - 1 then
							return element
						end
					end
					
				end

			end
		end
	end,
	['remove'] = function ( element )
		if type(element) ~= 'table' and element.type ~= 'zone.element' then error ( 'zone.remove (), invalid element provided.' ) end

		element:remove ()
	end,
}

return zone