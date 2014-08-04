local __log = false
local function log (message)
	if __log == true then
		local handle = system.filesystem.open ('/log/ui.log','a')
		handle:write (tostring(message) .. '\n')
		handle:close ()
	end
end


local function c ( t ) -- lazy
	local o = {}
	for k,v in pairs ( t ) do
		if type(v) == 'table' then
			o[k] = c(v)
		else
			o[k] = v
		end
	end

	return o
end

local ui = {}

local _event
local _zone
local _screen


local enum = {
	['type'] = 'enum',
	
	['__valid'] = {''},
	['__value'] = '',
	['__zone'] = nil,
	['__events'] = {},

	['add'] = function ( self, value )
		if type (self) ~= 'table' or self.type ~= 'enum' then
			error ( 'enum:add (), self is missing, or not of type enum' )
		end

		table.insert ( self.__valid, value )
		return self
	end,
	['remove'] = function ( self, value )
		if type (self) ~= 'table' or self.type ~= 'enum' then
			error ( 'enum:remove (), self is missing, or not of type enum' )
		end

		local i = false
		for _i, option in ipairs ( self.__valid ) do
			if option == value then
				i = _i
			end
		end

		if i ~= false then
			table.remove ( self.__valid, value )
		end

		return self
	end,
	['set'] = function ( self, value )
		if type (self) ~= 'table' or self.type ~= 'enum' then
			error ( 'enum:set (), self is missing, or not of type enum' )
		end

		local found = false
		for _,option in ipairs ( self.__valid ) do
			if value == option then
				found = true
			end
		end

		if found == false then
			return false, 'not a valid option'
		end

		self.__value = value
		return self
	end,
}
enum = setmetatable ( enum, {
	['__call'] = function ( self, ... )
		local o = {}
		for k,v in pairs ( self ) do o[k]=v end
		o.__value = {''}

		o = setmetatable (o, {
			['__tostring'] = function ( self )
				return self.__value
			end,
		})

		return o
	end,
})


local element = {
	['type'] = 'ui.element',

	['style'] = {},
	['children'] = {},

	['append'] = function ( self, element )
		if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
			error ( 'ui.element:append (), self is missing, or not of type ui.element' )
		end
		if type (element) ~= 'table' or element.type:match ('^ui%.element') == nil then
			error ( 'ui.element:append (), element provided is not of type ui.element' )
		end

		if element.parent ~= nil then
			element.parent:remove ( element )
		end
		element.parent = self
		table.insert ( self.children, element )

		return self
	end,
	['prepend'] = function ( self, element )
		if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
			error ( 'ui.element:prepend (), self is missing, or not of type ui.element' )
		end
		if type (element) ~= 'table' or element.type:match ('^ui%.element') == nil then
			error ( 'ui.element:prepend (), element provided is not of type ui.element' )
		end

		if element.parent ~= nil then
			element.parent:remove ( element )
		end
		element.parent = self
		table.insert ( self.children, 1, element )

		return self
	end,
	['remove'] = function ( self, element )
		if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
			error ( 'ui.element:remove (), self is missing, or not of type ui.element' )
		end

		if type(element) == 'number' then
			if self.children [element] ~= nil then
				error ( 'ui.element.remove (), index provided is out of bounds.\n index: ' .. tostring(element) )
			end

			table.remove ( self.children, element )
		else
			if type(element) ~= 'table' or element.type:match ('^ui%.element') == nil then
				error ( 'ui.element.remove (), element provided is not of type ui.element\n type: ' .. type(element) )
			end

			local i = false
			for _i, child in ipairs ( self.children ) do
				if child == element then
					i = _i
				end

				if i ~= false then
					table.remove ( self.children, i )
				end
			end
		end

		return self
	end,

	['create'] = function ( self, name, append )
		if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
			error ( 'ui.element:create (), self is missing, or not of type ui.element' )
		end

		local element = ui.create ( name )
		if append == true then self:append ( element ) end
		return element
	end,


	['attr'] = function ( self, key, value )
		if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
			error ( 'ui.element:attr (), self is missing, or not of type ui.element' )
		end

		if type(key) == 'table' then
			for k,v in pairs ( key ) do
				self:setAttribute (k,v)
			end

			return self
		end

		if value == nil then return self:getAttribute ( key ) end
		return self:setAttribute (key,value)
	end,
	['getAttribute'] = function ( self, key )
		if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
			error ( 'ui.element:getAttribute (), self is missing, or not of type ui.element' )
		end
		if type(self.style) ~= 'table' then self.style = {} end

		return tostring(self.style [key])
	end,
	['setAttribute'] = function ( self, key, value )
		if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
			error ( 'ui.element:setAttribute (), self is missing, or not of type ui.element' )
		end
		
		if type(key) ~= 'string' then
			error ( 'ui.element:setAttribute (), key provided is not of type string\n  type: ' .. type(key) )
		end
		
		if self.style [key] == nil then
			error ( 'ui.element:setAttribute (), key provided is not a valid style option\n  key: ' .. tostring(key) )
		end

		if type(value) == 'table' then
			error ( 'ui.element:setAttribute (), trying to assign table as value\n key: ' .. tostring(key) .. '\n' .. debug.traceback () )
		end

		if type(self.style [key]) == 'table' then
			if self.style [key].set == nil then
				error ( tostring(key) .. '\n'.. self.style [key].type .. "\n" .. debug.traceback () )
			end
			if self.style [key]:set ( value ) == false then
				error ( 'ui.element:setAttribute (), trying to assign invalid value to "' .. tostring(key) .. '"', '   value:' .. tostring(value) )
			end
		else
			self.style [key] = value
		end

		return self
	end,
	['text'] = function ( self, text )
		if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
			error ( 'ui.element:text (), self is missing, or not of type ui.element' )
		end

		if text == nil then return self.message end
		self.message = text
	end,

	['search'] = dofile ('/library/ui.search.lua'),
	['__computed'] = dofile ('/library/ui.__computed.lua'),

	['draw'] = function ( self )
		if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
			error ( 'ui.element:search (), self is missing, or not of type ui.element' )
		end
		if self:attr ( 'visibility' ) == 'hidden' then return self end
		self:trigger ('draw')

		local background = self:attr ('background-color')

		local x,y = nil,nil
		if background ~= 'transparent' then
			x,y = self:__computed ('XY')

			_screen:setBackground ( self:__computed('background-color') )

			local width, height = self:attr ('width'), self:attr ('height')
			log ( tostring (self.name .. ':fill') )
			_screen:fill ( x,y, self:__computed ('width'),self:__computed ('height'), ' ' )
		end

		if self.message ~= nil and tostring(self.message):len () > 1 then
			local x,y = self:__computed ('XY')
			local width = tonumber( self:__computed ('width') )

			local lines = {}
			for line in self.message:gmatch ('([^\n]*)\n?') do table.insert ( lines, line ) end
		
			if self:attr ('vertical-align') == 'center' then
				local height = self:__computed ('height')
				y = y + ((height / 2) - (#lines / 2))
			elseif self:attr ('vertical-align') == 'bottom' then
				local height = self:__computed ('height')
				y = y + (height - #lines) + 1
			end

			if lines [#lines]:match ( '[ \t\r\n]*') ~= nil then lines [#lines] = nil end

			_screen:setBackground ( self:__computed ('background-color') )
			--_screen:setBackground ( self:__computed ('color') )

			for offsetY, line in ipairs ( lines ) do
				local offsetX = 0
				if self:attr ('align') == 'center' then
					offsetX = (width / 2) - (line:len() / 2)
				elseif self:attr ('align') == 'right' then
					offsetX = width - line:len()
				end

				log ( tostring (self.name .. ':set') )
				_screen:set ( (x + offsetX), (y + offsetY - 1), line )
			end

		else
			local zMap = {}
			local zIndexes = {}

			for _,child in ipairs ( self.children ) do
				local z = child:attr ('z-index')

				if zIndexes [z] == nil then zIndexes [z] = {} end
				table.insert ( zIndexes [z], child )

				table.insert ( zMap, z )
			end

			table.sort ( zMap )
			for _,z in ipairs ( zMap ) do
				for _,child in ipairs ( zIndexes [z] ) do
					child:draw ()
				end
			end
		end

	end,

	['__getZone'] = function ( self )
		return self.__zone
	end,
	['on'] = function ( self, event, callback )
		if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
			error ( 'ui.element:on (), self is missing, or not of type ui.element' )
		end

		if self.__events == nil then self.__events = {} end

		if self.__events [event] == nil then
			self.__events [event] = {
				['add'] = function ( self, callback )
					table.insert ( self, callback )
				end,
				['remove'] = function ( self, callback )
					for i = #self, 1, -1 do
						if callback == nil or callback == self [i] then
							table.remove ( self, i )
						end
					end
				end,
			}
		end

		self.__events [event]:add ( callback )
		if self.__zone == nil then
			self.__zone = _zone.add ( self, self )

			local o = self:search (':has(zone)')
			for _,c in ipairs (o) do
				self.__zone:below(c.__zone)
			end
		end

		if _event.uiActive == nil then
			_event.uiActive = true

			_event:on ( 'touch', function ( e, address, x,y, button, who )
				if _screen.address ~= address then return end

				local zone = _zone.get ( x,y )
				_event.__drag = zone

				if zone ~= nil and zone.values:__computed ('visibility') ~= 'hidden' then
					zone.values:trigger ( e, x,y, button, who )
				end
			end )

			_event:on ( 'drag', function ( e, address, x,y, button, who )
				if _screen.address ~= address then return end

				if _event.__drag ~= nil and _event.__drag.values:__computed ('visibility') == 'visible' then
					_event.__drag.values:trigger ( e, x,y, button, who )
				end
			end )

			_event:on ( 'drop', function ( e, address, x,y, button, who )
				if _screen.address ~= address then return end

				if _event.__drag ~= nil and _event.__drag.values:__computed ('visibility') == 'visible' then
					_event.__drag.values:trigger ( e, x,y, button, who )
				end
				_event.__drag = nil
			end )
		end

		return self
	end,
	['off'] = function ( self, event, callback )
		if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
			error ( 'ui.element:off (), self is missing, or not of type ui.element' )
		end
		if self.__events == nil then return self end
		if self.__events [event] == nil then return self end

		self.__events [event]:remove ( callback )
		return self
	end,
	['trigger'] = function  ( self, event, ... )
		if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
			error ( 'ui.element:trigger (), self is missing, or not of type ui.element' )
		end

		local e = nil
		local args = {...}

		if type(args [1]) == 'table' and args[1].type == 'ui.element.__trigger.event' then
			e = table.remove ( args, 1 )
		else
			e = c(self.__trigger.event)
			e.target = self
			e.event = event
		end


		if self.__events ~= nil and self.__events [event] ~= nil then
			local call = true
			for _,callback in ipairs ( self.__events [event] ) do
				if call == true then
					local r = callback ( self, e, table.unpack ( args ) )

					if r == false then
						call = false 
					end
				end
			end
		end

		if e.__propagate == true and self.parent ~= nil then
			local p = self.parent

			while p ~= nil and e.__propagate == true do
				if p.__events ~= nil and p.__events [event] ~= nil then
					for _,callback in ipairs ( p.__events [event] ) do
						if call == true then
							local r = callback ( p, e, table.unpack ( args ) )

							if r == false then
								call = false 
							end
						end
					end
				end

				p = p.parent
			end
		end
		return self
	end,
	['__trigger'] = {
		['event'] = {
			['type'] = 'ui.element.__trigger.event',
			['__propagate'] = true,
			['stopPropagation'] = function ( self, bool )
				if type (self) ~= 'table' or self.type:match ('^ui%.element%.__trigger%.event') == nil then
					error ( 'ui.element.__trigger.event.stopPropagation (), self is missing, or not of type ui.element.__trigger.event' )
				end

				if type(bool) ~= 'boolean' then
					error ( 'ui.element.__trigger.event.stopPropagation (), provided argument is not of type boolean' )
				end

				self.__propagate = not bool
			end,
		}
	},

	['isRoot'] = function ( self, bool )
		if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
			error ( 'ui.element:isRoot (), self is missing, or not of type ui.element' )
		end

		if type(bool) ~= 'boolean' then
			error ( 'ui.element:isRoot (), provided argument is not of type boolean' )
		end

		self.__root = bool
	end,
	['root'] = function ( self )
		if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
			error ( 'ui.element:getRoot (), self is missing, or not of type ui.element' )
		end

		if self.__root == true then return self end
		if self.parent == nil then return self end

		local p = self.parent
		while p.__root == nil or p.__root == false do
			if p.parent == nil then return p end
			p = p.parent
		end

		return p
	end,
}

ui = {
	['type'] = 'ui',
	['element'] = element,

	['create'] = function ( name )
		local o = c(element)
		o.name = name
		o.style = {
			['position'] = enum ('absolute', 'relative', 'inline', 'block'):set( 'inline' ),
			['x'] = 'auto',
			['y'] = 'auto',

			['z-index'] = 0,

			['width'] = 'inherit',
			['height'] = 'inherit',

			['color'] = 0xFFFFFF,
			['background-color'] = 'transparent',

			['align'] = enum ('left','center','right'):set( 'left' ),
			['vertical-align'] = enum ('top','center','button'):set( 'top' ),

			['visibility'] = enum('visible','hidden'):set('visible'),
		}

		return o
	end,

	['setEvent'] = function ( event ) _event = event end,
	['setScreen'] = function ( screen ) _screen = screen end,
	['setZone'] = function ( zone ) _zone = zone end,
}

return ui