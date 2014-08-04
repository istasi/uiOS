local __log = false
local function log (message)
	if __log == true then
		local handle = system.filesystem.open ('/log/screen.log','a')
		handle:write ( tostring(message) .. '\n' )
		handle:close ()
	end
end

local screen = {
	['type'] = 'screen',
	['address'] = component.list('screen', true) (),
	['gpu'] = setmetatable ({	-- Please use the gpu lib rather than this, while this work it only takes advantage of a single gpu, where-as the gpu lib uses as many as possible, and evenly.
		['address'] = component.list('gpu') (),
		['bind'] = function ( self, address ) component.invoke ( self.address, 'bind', address ) end
	},{['__tostring'] = function ( self ) return self.address end}),
	['__use'] = nil,

	['bgColor'] = 0x000000,
	['fgColor'] = 0xFFFFFF,

	['active'] = function ( self )
		self.gpu:bind ( self.address )

		self.__use = tostring ( self.gpu )
	end,

	['clear'] = function ( self )
		self:active ()

		local size = ({self:maxResolution()})

		self:setBackground () self:setForeground ()

		log ( self.address .. ': clear: gpu: ' .. self.__use )
		component.invoke ( self.__use, 'fill', 1,1, size[1],size[2], ' ' )
		
		return self
	end,
	['set'] = function ( self, x,y, message, vertical )
		self:active ()

		self:setBackground ()
		self:setForeground ()

		log ( self.address .. ': set: gpu: ' .. self.__use )
		component.invoke ( self.__use, 'set', x,y, message )
		return self
	end,
	['fill'] = function ( self, x,y, width,height, char )
		self:active ()

		local v = function (i)
			for k,v in pairs(i) do
				if type(v) == 'string' then
					local _v = tonumber (v)

					if _v == nil then error ( 'screen:fill (), ' .. k .. ' provided is not of type number (' ..tostring(v)..')' ) end
					return _v
				elseif type(v) == 'number' then
					return v
				else
					error ( 'screen:fill (), ' .. k .. ' provided is not of type number (' ..tostring(v)..')' )
				end
			end

			error ( 'screen:fill (), recieved nil as argument' )
		end

		x = v{x=x or false}
		y = v{y=y or false}

		width = v{width=width or false}
		height = v{height=height or false}


		self:setBackground () self:setForeground ()

		log ( self.address .. ': fill: gpu: ' .. self.__use )
		component.invoke ( self.__use, 'fill', x,y, width,height, char )
		return self
	end,
	['setBackground'] = function ( self, color )
		if color == nil then
			if component.invoke ( self.__use, 'getBackground' ) ~= self.bgColor then
				log ( self.address .. ': setBackground: gpu: ' .. self.__use )
				component.invoke ( self.__use, 'setBackground', self.bgColor ) 
			end
			return true
		end
		if type(color) == 'string' then
			local tmp = color:match ( '0x([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])' )
			if tmp == nil and color:match ('^%d+$') ~= nil then
				color = tonumber(color)
			else
				assert ( tmp, 'screen.setBackground, bad color recieved, unable to parse (' .. type(color) .. ':"' .. color .. '")' )

				color = tonumber(tmp,16)
			end
		end
	
		self.bgColor = color
	end,
	['setForeground'] = function ( self, color )
		if color == nil then
			if component.invoke ( self.__use, 'getForeground' ) ~= self.fgColor then
				log ( self.address .. ': setForeground: gpu: ' .. self.__use )
				component.invoke ( self.__use, 'setForeground', self.fgColor ) 
			end
			return true
		end
		if type(color) == 'string' then
			local tmp = color:match ( '0x([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])' )
			if tmp == nil and color:match ('^%d+$') ~= nil then
				color = tonumber(color)
			else
				assert ( tmp, 'screen.setForeground, bad color recieved, unable to parse (' .. type(color) .. ':"' .. color .. '")' )

				color = tonumber(tmp,16)
			end
		end

		self.fgColor = color
	end,

	['setResolution'] = function ( self, width,height )
		self:active ()

		log ( self.address .. ': setResolution: gpu: ' .. self.__use )
		component.invoke ( self.__use, 'setResolution', width,height )

		self.__width = width
		self.__height = height

		return self
	end,
	['getResolution'] = function ( self )
		self:active ()
		
		if self.__width == nil or self.__height == nil then
			log ( self.address .. ': getResolution: gpu: ' .. self.__use )
			self.__width, self.__height = component.invoke ( self.__use, 'getResolution' )
		end

		return self.__width, self.__height
	end,
	['maxResolution'] = function ( self )
		self:active ()
		log ( self.address .. ': maxResolution: gpu: ' .. self.__use )

		return component.invoke ( self.__use, 'maxResolution' )
	end,
}

setmetatable (screen, {
	['__index'] = function ( self, key )
		if key == 'width' or key == 'height' then
			local size = ({self:getResolution ()})
			if key == 'width' then
				return size [1]
			end
			return size [2]
		else
			return nil
		end
	end,
})

return screen