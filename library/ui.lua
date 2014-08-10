local __log = false
local function log (message)
	if __log == true then
		local handle = system.filesystem.open ('/log/ui.log','a')
		handle:write (tostring(message) .. '\n')
		handle:close ()
	end
end


local ui = {}

local _event
local _zone
local _screen


local enum = {
	['type'] = 'enum',
	['__valid'] = {''},
	['__value'] = '',
}

function enum.add ( self, value )
	if type (self) ~= 'table' or self.type ~= 'enum' then
		error ( 'enum:add (), self is missing, or not of type enum' )
	end

	table.insert ( self.__valid, value )
	return self
end
function enum.remove ( self, value )
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
end
function enum.set ( self, value )
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
end
function enum.test ( self, value )
	if type (self) ~= 'table' or self.type ~= 'enum' then
		error ( 'enum:set (), self is missing, or not of type enum' )
	end

	local found = false
	for _,option in ipairs ( self.__valid ) do
		if value == option then
			return true
		end
	end
	return false
end

enum = setmetatable ( enum, {
	['__call'] = function ( self, ... )
		local o = {}
		for k,v in pairs ( self ) do o[k]=v end
		o.__value = {''}

		for k,v in pairs ({...}) do 
			o:add ( v )
		end

		o = setmetatable ( o, {
			['__tostring'] = function ( self )
				return self.__value
			end,
		} )

		return o
	end,
} )

local style = {
	['type'] = 'style',

	['__default'] = {
		['position'] = enum ('absolute', 'relative', 'inline', 'block'):set( 'inline' ),
		['x'] = 'auto',
		['y'] = 'auto',

		['z-index'] = 0,

		['width'] = 'inherit',
		['height'] = 'inherit',

		['color'] = 0xFFFFFF,
		['background-color'] = 'transparent',

		['align'] = 'left', enum ('left','center','right'):set( 'left' ),
		['vertical-align'] = enum ('top','center','bottom'):set( 'top' ),

		['visibility'] = enum ('visible','hidden'):set('visible'),
	},
	['__values'] = {},

	['set'] = function ( self, key, value )
		if type ( self.__default [key] ) == 'table' and self.__default [key].type == 'enum' then
			local state, message = self.__default [key]:test ( value ) 
			if state == false then
				return false, message
			end

			if tostring(value) ~= tostring(self.__default[key]) then
				self.__values [key] = value
			else
				self.__values [key] = nil
			end
		else
			if value ~= self.__default [key] then
				self.__values [key] = value
			else
				self.__values [key] = nil
			end
		end
		return true
	end,
	['get'] = function ( self, key )
		if self.__values [key] == nil then
			if type(self.__default [key]) == 'table' and self.__default [key].type == 'enum' then
				return tostring(self.__default [key])
			end
			return self.__default [key]
		end

		return self.__values [key]
	end,
	['test'] = function ( self, key )
		if self.__default [key] == nil then 
			return false
		end
		return true
	end,
	['default'] = function ( self, key, value )
		if value == nil then
			return self.__default [key]
		end

		if type(self.__default [key]) == 'table' and self.__default [key].type == 'enum' then
			local state, message = self.__default [key]:set ( value )
			if state == false then
				return false, message
			end
		else
			self.__default [key] = value
		end
		return true
	end,
}

style = setmetatable ( style, {
	['__call'] = function  ( self )
		local o = {}
		for k,v in pairs (self) do o[k]=v end
		o.__values = {}

		return o
	end,
})


local element = {
	['type'] = 'ui.element',
}

element.search = dofile ('/library/ui.search.lua')
element.__computed = dofile ('/library/ui.__computed.lua')

function element.append ( self, element )
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
end
function element.prepend ( self, element )
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
end
function element.remove ( self, element )
	if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
		error ( 'ui.element:remove (), self is missing, or not of type ui.element' )
	end

	if element == nil then
		self.parent:remove ( self )

	elseif type(element) == 'number' then
		if self.children [element] ~= nil then
			error ( 'ui.element.remove (), index provided is out of bounds.\n index: ' .. tostring(element) )
		end
		self:remove ( self.children [element] )

	else
		if type(element) ~= 'table' or element.type:match ('^ui%.element') == nil then
			error ( 'ui.element.remove (), element provided is not of type ui.element\n type: ' .. type(element) )
		end

		for i, child in ipairs ( self.children ) do
			if child == element then
				table.remove ( self.children, i )
				if child.__zone ~= nil then
					child.__zone:remove ()
				end

				for i, child in ipairs ( element.children ) do
					element:remove ( child )
				end
			end
		end
	end

	return self
end

function element.create ( self, name, append )
	if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
		error ( 'ui.element:create (), self is missing, or not of type ui.element' )
	end

	local element = ui.create ( name )
	if append == true then self:append ( element ) end
	return element
end


function element.attr ( self, key, value )
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
end
function element.getAttribute ( self, key )
	if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
		error ( 'ui.element:getAttribute (), self is missing, or not of type ui.element' )
	end

	--if type(self.style) ~= 'table' then self.style = } end
	if self.style.get ~= nil then
		return self.style:get ( key )
	else
		return tostring(self.style [key])
	end
end
function element.setAttribute ( self, key, value )
	if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
		error ( 'ui.element:setAttribute (), self is missing, or not of type ui.element' )
	end
	
	if type(key) ~= 'string' then
		error ( 'ui.element:setAttribute (), key provided is not of type string\n  type: ' .. type(key) )
	end
	
	if self.style:test (key) == nil then
		error ( 'ui.element:setAttribute (), key provided is not a valid style option\n  key: ' .. tostring(key) )
	end

	if type(value) == 'table' then
		error ( 'ui.element:setAttribute (), trying to assign table as value\n key: ' .. tostring(key) .. '\n' .. debug.traceback () )
	end

	if self.style:set ( key, value ) == false then
		error ( 'ui.element.setAttribute (), trying toa ssign invalid value to "' .. tostring(key) .. '"\n   value:' .. tostring(value) )
	end
	
	return self
end
function element.text ( self, text )
	if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
		error ( 'ui.element:text (), self is missing, or not of type ui.element' )
	end

	if text == nil then return self.message end
	self.message = text

	return self
end
function element.draw ( self, ignore )
	ignore = ignore or false
	if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
		error ( 'ui.element:search (), self is missing, or not of type ui.element' )
	end
	if self:attr ( 'visibility' ) == 'hidden' then return self end

	if self.__root == true and ignore ~= true then
		self.__drawAll = _event:off('timer',self.__drawAll):timer (0.01, function ()
			self:draw ( true )

			self.__drawAll = nil
		end )

		return self
	end

	local background = self:attr ('background-color')
	local x,y = nil,nil
	if background ~= 'transparent' then
		x,y = self:__computed ('XY')
		--error ( 'here:' .. tostring(x) )

		_screen:setBackground ( self:__computed('background-color') )

		local width, height = self:attr ('width'), self:attr ('height')
		log ( tostring (self.name .. ':fill') )
		_screen:fill ( x,y, self:__computed ('width'),self:__computed ('height'), ' ' )
	end

	if self.message ~= nil and system.unicode.len (tostring(self.message)) > 1 then
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
		_screen:setForeground ( self:__computed ('color') )

		for offsetY, line in ipairs ( lines ) do
			local offsetX = 0
			if self:attr ('align') == 'center' then
				offsetX = (width / 2) - (system.unicode.len (line) / 2)
				line = line .. string.rep ( ' ', tonumber (offsetX) or 0 )

			elseif self:attr ('align') == 'right' then
				offsetX = width - system.unicode.len (line)
			end
			line = string.rep ( ' ', tonumber(offsetX) or 0 ) .. line

			log ( tostring (self.name .. ':set') )
			_screen:set ( tonumber(x), (y + offsetY - 1), line )
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
end
function element.on ( self, event, callback )
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

		-- TODO: Fix here, doesn't seem to respect this completely.
		self:search (':has(zone)'):each ( function ( element )
			self.__zone:below ( element.__zone )
		end )
	end

	if _event.uiActive == nil then
		_event.uiActive = true

		_event:on ( 'touch', function ( e, address, x,y, button, who )
			if _screen.address ~= address then return end

			local zone = nil
			repeat
				local z = nil
				if zone ~= nil and zone.__zIndex ~= nil then z = zone.__zIndex - 1 end

				zone = _zone.get ( x,y, z )
				_event.__drag = zone

				if zone ~= nil and zone.values:__computed ('visibility') ~= 'hidden' then
					zone.values:trigger ( e, x,y, button, who )

					zone = nil
				end
			until zone == nil 
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
end
function element.off ( self, event, callback )
	if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
		error ( 'ui.element:off (), self is missing, or not of type ui.element' )
	end
	if self.__events == nil then return self end
	if self.__events [event] == nil then return self end

	self.__events [event]:remove ( callback )
	return self
end
function element.trigger ( self, event, ... )
	if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
		error ( 'ui.element:trigger (), self is missing, or not of type ui.element' )
	end

	local __event = tostring(event)
	local e = nil
	local args = {...}

	if type(args [1]) == 'table' and args[1].type == 'ui.element.__trigger.event' then
		e = table.remove ( args, 1 )
	else
		e = {}
		for k,v in pairs(element.__trigger.event) do e[k]=v end

		e.target = self
		e.event = __event
	end


	if self.__events ~= nil and self.__events [ __event ] ~= nil then
		local call = true
		for _,callback in ipairs ( self.__events [ __event ] ) do
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
			if p.__events ~= nil and p.__events [ __event ] ~= nil then

				local call = true
				for _,callback in ipairs ( p.__events [ __event ] ) do
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
end
element.__trigger = {
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
}

function element.isRoot ( self, bool )
	if type (self) ~= 'table' or self.type:match ('^ui%.element') == nil then
		error ( 'ui.element:isRoot (), self is missing, or not of type ui.element' )
	end

	if type(bool) ~= 'boolean' then
		error ( 'ui.element:isRoot (), provided argument is not of type boolean' )
	end

	self.__root = bool
end
function element.root ( self )
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
end

ui = {
	['type'] = 'ui',
	['element'] = element,
}

function ui.create ( name )
	local o = {
		['type'] = element.type,
		['name'] = name,

		['style'] = style (),
		['children'] = {},

		['append'] = element.append,
		['prepend'] = element.prepend,

		['remove'] = element.remove,
		['create'] = element.create,

		['attr'] = element.attr,
		['getAttribute'] = element.getAttribute,
		['setAttribute'] = element.setAttribute,

		['text'] = element.text,

		['on'] = element.on,
		['off'] = element.off,
		['trigger'] = element.trigger,

		['root'] = element.root,
		['isRoot'] = element.isRoot,

		['draw'] = element.draw,

		['search'] = element.search,
		['__computed'] = element.__computed,
	}

	return o
end

function ui.setEvent ( event ) _event = event end
function ui.setScreen ( screen ) _screen = screen end
function ui.setZone ( zone ) _zone = zone end

return ui