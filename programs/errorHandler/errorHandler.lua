local tostring = tostring
local ipairs,pairs = ipairs,pairs
local insert,remove = table.insert,table.remove

local errorHandler = {
	['__list'] = {},
	['add'] = function ( self, message )
		insert ( self.__list, message )
		system.event:push ( 'update' )

		system.event:push ( 'show', #self.__list )
	end,
	['remove'] = function ( self, id )
		self.__list [id] = nil

		local line = system.desktop:search ( 'error.' .. id )
		if #line > 0 then
			line [1].parent:remove ( line [1] )
		end

		system.event:push ( 'update' )
	end,
}

-- error recieved, throw it in the stack
--[[
event:off ('error'):on ('error', function ( event, ... )
	local message = ''
	for _, value in pairs ({...}) do
		message = message .. tostring(value) .. ', '
	end

	errorHandler:add ( message:sub (1, message:len () - 2) )
end )

-- tell kernel to redirect errors to me
event:signal ( 1, 'error.handler', event.id )
--]]
return errorHandler