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
		['__bound'] = nil,
		['address'] = component.list('gpu') (),
		['bind'] = function ( self, address )
			if self.__bound ~= address then
				component.invoke ( self.address, 'bind', address )
				self.__bound = address
			end
		end
	},{
		['__tostring'] = function ( self )
			return self.address 
		end,
		['__index'] = function ( self, key )
			return function ( self, ... )
				return component.invoke ( tostring(self), key, ... )
			end
		end,
	}),

	['buffer'] = nil,

	['bgColor'] = 0x000000,
	['fgColor'] = 0xFFFFFF,

	['clear'] = function ( self )
		local size = ({self:maxResolution()})
		self:setBackground () self:setForeground ()

		self.gpu:fill ( 1,1, size[1],size[2], ' ' )
		return self
	end,
	['set'] = function ( self, x,y, message, vertical )
		self:setBackground ()
		self:setForeground ()

		if self.buffer then
			if self.buffer:set ( x,y, message ) > 1 then
				self.gpu:set ( x,y, message )
			end
		else
			self.gpu:set ( x,y, message )
		end
		
		return self
	end,
	['fill'] = function ( self, x,y, width,height, char )
		local v = function (i)
			for k,v in pairs(i) do
				if type(v) == 'string' then
					local _v = tonumber (v)

					if _v == nil then error ( 'screen:fill (), ' .. k .. ' provided is not of type number (' ..tostring(v)..')\n' .. debug.traceback () ) end
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


		self:setBackground ()
		self:setForeground ()

		if self.buffer ~= nil then
			if self.buffer:fill ( x,y, width,height, char ) > 0 then
				self.gpu:fill ( x,y, width,height, char )
			end
		else
			self.gpu:fill (x,y, width,height, char )
		end

		return self
	end,
	['setBackground'] = function ( self, color )
		if color == nil then
			if self.gpu:getBackground () ~= self.bgColor then
				self.gpu:setBackground ( self.bgColor )
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
	['getBackground'] = function ( self )
		return self.gpu:getBackground ()
	end,
	['setForeground'] = function ( self, color )
		if color == nil then
			if self.gpu:getForeground () ~= self.fgColor then
				self.gpu:setForeground ( self.fgColor ) 
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
	['getForeground'] = function ( self )
		return self.gpu:getForeground ()
	end,

	['setResolution'] = function ( self, width,height )
		self.gpu:setResolution ( width,height )

		self.__width = width
		self.__height = height

		return self
	end,
	['getResolution'] = function ( self )
		if self.__width == nil or self.__height == nil then
			self.__width, self.__height = self.gpu:getResolution ()
		end

		return self.__width, self.__height
	end,
	['maxResolution'] = function ( self )
		return self.gpu:maxResolution ()
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