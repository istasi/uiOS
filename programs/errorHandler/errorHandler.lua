event.name = '[Error handler]'

local tostring = tostring
local ipairs,pairs = ipairs,pairs
local insert,remove = table.insert,table.remove

local errorHandler = {
	['__list'] = {},
	['add'] = function ( self, message )
		insert ( self.__list, message )
		event:push ( 'update' )

		event:push ( 'show', #self.__list )
	end,
	['remove'] = function ( self, id )
		self.__list [id] = nil

		local line = desktop:search ( 'error.' .. id )
		if #line > 0 then
			line [1].parent:remove ( line [1] )
		end

		event:push ( 'update' )
	end,
}

--
-- Create the ui
local desktop = desktop
local menu = desktop:search ('desktop.system.menu') [1]
local object = menu:create ( 'system.menu.entry', true )
:attr ({
	['width'] = 20,
	['height'] = 1,
})

local label = object:create ('label', true)
:attr ('align', 'center')
:text ( 'errors (0)' )

local window = object:create ('menu.object.window', true)
:attr ({
	['position'] = 'relative',
	['x'] = 3,
	['y'] = 3,

	['width'] = 27,
	['height'] = 0,

	['background-color'] = 0x770000,
	['visibility'] = 'hidden',
})

object:on ('touch', function ( ui )
	ui:search ( 'menu.object.window'):each ( function ( ui )
		if ui:attr ('visibility') == 'hidden' then
			ui:attr ('visibility', 'visible')
		else
			ui:attr ('visibility', 'hidden')
		end
	end )

	ui:root ():draw ()
end )

event:on ( 'update', function ( event )
	label:text ('errors (' .. #errorHandler.__list .. ')')
	label:draw ()
	window:search ('error.object'):each ( function ( ui ) ui:remove () end )

	if #errorHandler.__list < 1 then
		window:attr ('height', 0)
	else
		window:attr ('height', #errorHandler.__list + 1)
		for id, message in ipairs ( errorHandler.__list ) do
			local line = window:create ('error.object',true)
			:attr ({
				['height'] = 2,
				['vertical-align'] = 'bottom',
			})
			:text ( message )
			:on ( 'touch', function ( ui )
				event:push ( 'show', ui.__id )
			end )

			line.__id = id
		end
	end
end )

event:on ( 'show', function ( event, id )
	desktop:search ( 'error.window' ):each ( function ( ui ) ui:remove () end )
	local message = errorHandler.__list [id]
	if message == nil then return end

	local amount = 0
	for _ in message:gmatch ('\n') do amount = amount + 1 end
	local height = math.max ( amount + 1, 7 )

	local window = desktop:create ( 'error.window', true )
	:attr ({
		['position'] = 'relative',
		['x'] = (desktop:attr ('width') / 2) - 40,
		['y'] = (desktop:attr ('height') / 2) - (height / 2),

		['width']  = 80,
		['height'] = height,

		['background-color'] = 0x770000,
		['align'] = 'center',
	})

	window:create ('message', true)
	:attr ({
		['height'] = (height - 3),

		['vertical-align'] = 'center',
		['align'] = 'center',
	})
	:text ( message )

	local buttons = window:create ( 'button-holder', true )
	:attr ({
		['height'] = 3,

		['vertical-align'] = 'center',
		['align'] = 'center',
	})

	buttons:create ( 'button-remove', true )
	:attr ({
		['width'] = '25%',
		['height'] = 1,

		['align'] = 'center',
	})
	:text ( 'remove' )
	:on ( 'touch', function ( ui )
		errorHandler:remove ( ui.parent.parent.__id )
		
		ui.parent.parent:remove ()
		ui:root ():draw ()
	end )

	buttons:create ( 'button-close', true )
	:attr ({
		['width'] = '25%',
		['height'] = 1,

		['align'] = 'center',
	})
	:text ( 'close' )
	:on ( 'touch', function ( ui )
		ui.parent.parent:remove ()
		ui:root ():draw ()
	end )

	window.__id = id
	window:draw ()
end )

--
-- error recieved, throw it in the stack
event:off ('error'):on ('error', function ( event, ... )
	local message = ''
	for _, value in pairs ({...}) do
		message = message .. tostring(value) .. ', '
	end

	errorHandler:add ( message:sub (1, message:len () - 2) )
end )

event:off ('process.kill'):on ('process.kil', function ( event, level )
	-- We were asked to die, if we dont respond within 1 second, we'll be killed off
	if level == 6 then 
		event:signal ( '[Kernel]', 'process.alive', event.id )
	end
end )

--
-- tell kernel to redirect errors to me
--event:signal ( 1, 'error.handler', event.id )