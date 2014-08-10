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

		local line = system.desktop:search ('error.' .. id) 
		if #line > 0 then
			line [1].parent:remove ( line[1] )
		end

		system.event:push ( 'update' )
	end,
}

-- error recieved, throw it in the stack
system.event:off ('error'):on ('error', function ( event, message )
	errorHandler:add ( message )
end )

-- kernel wants to kill me, but i am alive!
system.event:off ('process.kill'):on ('process.kill', function ( event, level )	
	event:signal ( 1, 'process.alive' )
end )

local uiError = system.desktop:search ('desktop.bar')[1]:create ('bar.error')
uiError:attr ('background-color','transparent')

uiError:search ('window') [1]:attr ({
	['width'] = 27,
	['height'] = 0,

	['vertical-align'] = 'center',

	['background-color'] = 0x770000,
})

system.event:on ('update', function ()
	local window = uiError:search ('window')[1]

	local keys = {}
	for k in pairs ( errorHandler.__list ) do
		insert ( keys, k )
	end
	table.sort ( keys )
	if #keys > 0 then
		window:attr ( 'height', #keys + 2 )
	else
		window:attr ( 'height', 0 )
	end

	uiError:search ('label')[1]:text ( 'errors (' .. #keys ..')' )
	for _,k in ipairs ( keys ) do
		uiError:search ('label')[1]:text ( 'errors (' .. #keys ..')' )
		if #window:search ( 'error.' .. k ) < 1 then
			local line = window:create ( 'error.' .. k, true )
			line:attr ({
				['height'] = 1,

				['align'] = 'center',
			})

			local str = tostring(errorHandler.__list [k]):match ('^([^:]*:[^:]*):.*') or errorHandler.__list [k]
			line:text ( '"...' .. str:sub(-20) .. '"' )
			line.__id = k

			line:on ('touch', function ( ui )
				system.event:push ('show', ui.__id )
			end )
		end
	end

	uiError:draw ()
end )
system.event:push ( 'update' )

system.event:on ('show', function ( _, id )

	local window = system.desktop:search ( 'error.window' )
	if #window < 1 then
		window = system.desktop:create ( 'error.window', true )
		window:attr ({
			['position'] = 'relative',
			['x'] = system.desktop:__computed ('width') / 2 - 40,
			['y'] = system.desktop:__computed ('height') / 2 - 4,
			['z-index'] = 100,

			['width'] = 80,
			['height'] = 6,

			['align'] = 'center',
			['background-color'] = 0x770000,
		})

		window:create ('textarea', true):attr ({
			['position'] = 'inline',
			['height'] = 4,

			['align'] = 'center',
			['vertical-align'] = 'center',
		})

		window:create ('button.remove',true):attr ({
			['height'] = 3,
			['width'] = 22,

			['align'] = 'center',
		}):text ( 'remove' ):on ('touch', function ( ui )
			errorHandler:remove ( ui.parent.__id )

			local window = system.desktop:search ('error.window')
			if #window > 0 then
				window [1]:remove ()

				ui:root ():draw ()
			end
		end)

		window:create ('button.close',true):attr ({
			['height'] = 3,
			['width'] = 22,

			['align'] = 'center',
		}):text ( 'close' ):on ('touch', function ( ui )
			local window = system.desktop:search ('error.window')
			if #window > 0 then
				window [1]:remove ()

				ui:root ():draw ()
			end
		end )
	else
		window = window [1]
		window:attr ( 'visibility', 'visible')
	end

	window.__id = id
	window:search ('textarea')[1]:text ( errorHandler.__list [id] )
	window:draw ()
end )


-- tell kernel to redirect errors to me
system.event:signal ( 1, 'error.handler', system.event.id )
return errorHandler