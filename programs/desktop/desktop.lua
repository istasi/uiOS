event.name = '[Desktop]'

local ui = dofile ('/library/ui.lua')
ui:setScreen ( screen )
ui:setEvent ( event:create ('ui') )
ui:setZone ( dofile ('/library/zone.lua') )

-- 
-- the root element from which all other elements spring.
local desktop = ui:create ( 'desktop' )
:isRoot ( true )
:attr ({
	['position'] = 'absolute',
	['x'] = 1,
	['y'] = 1,

	['width'] = screen.width,
	['height'] = screen.height,

	['background-color'] = 0x111111,
})

desktop:create ( 'redraw', true )
:attr ({
	['position'] = 'relative',
	['x'] = 100,
	['y'] = 30,

	['background-color'] = 0x990000,

	['width'] = 30,
	['height'] = 10,

	['align'] = 'center',
	['vertical-align'] = 'center',
})
:text ( 'redraw' )
:on ( 'touch', function ( ui )
	desktop:draw ()
end )

--
-- Create the system menu
local menu = desktop:create ('desktop.system.bar', true)
:attr ({
	['position'] = 'relative',
	['x'] = 1,
	['y'] = 1,

	['height'] = 1,

	['background-color'] = 0xdd8800,
})

-- 
-- Memory usage display
local mode = 1
local mem = menu:create ( 'system.bar.memory', true )
:attr ({
	['position'] = 'relative',
	['x'] = desktop:attr('width') - 30,
	['y'] = 1,

	['width'] = 30,

	['align'] = 'right',
})
:on ( 'touch', function ()
	mode = mode + 1

	if mode == 4 then
		mode = 0
	end
end )

event:interval ( 1, function ()
	local str = ''
	if mode == 0 then
		str = math.floor ( ((computer.totalMemory () - computer.freeMemory ()) / 1024) * 10 ) / 10 .. 'KB / ' .. math.floor(computer.totalMemory () / 1024) .. 'KB'
	elseif mode == 1 then
		str = 'used ' .. (100 - math.floor ( (computer.freeMemory () / computer.totalMemory ()) * 1000 ) / 10) .. '%'
	elseif mode == 2 then
		str = 'free ' .. math.floor ( (computer.freeMemory () / 1024) * 10 ) / 10 .. 'KB'
	elseif mode == 3 then
		str = 'used ' .. math.floor ( ( (computer.totalMemory () - computer.freeMemory ()) / 1024) * 10 ) / 10 .. 'KB'
	end

	mem:text ( 'Memory: ' .. str )
	mem:draw ()
end )


--
-- Add the programs folder to the system menu
local object = menu:create ( 'system.bar.menu', true )
object:attr ({
	['width'] = 20,
	['height'] = 1,
})
:create ( 'label', true )
:attr ( 'align', 'center' )
:text ( 'Menu' )

local menuClose = function ( ui, event )
	event:stopPropagation ( true )
	
	ui:search ( '> menu.object.window' ):each ( function ( ui ) 
		if ui:attr ('visibility') == 'hidden' then
			ui:attr ('visibility', 'visible' )
		else
			ui:attr ('visibility', 'hidden' )

			ui:search ('menu.object.window'):each ( function ( ui )
				ui:attr ( 'visibility', 'hidden' )
			end )
		end
	end )

	ui:root ():draw ()
end

object:on('touch', menuClose )


--
-- The window containing all the programs
local window = object:create ( 'menu.object.window', true )
:attr ({
	['position'] = 'relative',
	['x'] = 3,
	['y'] = 3,

	['width'] = 25,
	['height'] = 3,

	['background-color'] = 'inherit',
	['visibility'] = 'hidden',
})

--
-- Default, lets tell thats theres no programs added.
window:attr ('height', 3)
:create ( 'program.entry', true )
:attr ({
	['height'] = 2,

	['align'] = 'center',
	['vertical-align'] = 'bottom',
})
:text ( 'No programs added.' )



-- 
-- Program container, any programs added to the menu will be added though here.
local programs = {
	['__keys'] = {},
	['add'] = function ( self, key, value )
		self [key] = value

		table.insert ( self.__keys, key )
	end,
	['remove'] = function ( self, key )
		self [key] = nil

		for i, __key in ipairs ( self.__keys ) do
			if __key == key then
				table.remove ( self.__keys, i )
			end
		end
	end,
	['each'] = function ( self, callback )
		table.sort ( self.__keys )
		for _, key in pairs ( self.__keys ) do
			callback ( key, self [key] )
		end
	end,
}

event:on ( 'system.bar.menu.program.add', function ( event, name, file )
	window:search ( 'program.entry' ):each ( function ( ui ) ui:remove () end )

	programs:add ( name, {name, file} )
	programs:each ( function ( _, value )
		local name,file = value [1],value[2]

		local parts = {}
		for part in name:gmatch ( '([^/]*)' ) do
			if part ~= '' then
				table.insert ( parts, part )
			end
		end

		for i, part in ipairs (parts) do
			local line = window:create ( 'program.entry', true )
			:attr ({
				['height'] = 2,
				['vertical-align'] = 'bottom',
			})

			local label = line:create ('label',true)
			:attr ({
				['align'] = 'center',
				['height'] = 1,
			})
			:text ( part )
				
			if i == #parts then
				line:on ( 'touch', function ( ui )
					event:signal ( '[System]', 'program.execute', ui.__file )
				end )
				line.__file = file
			else
				window = line:create ('menu.object.window', true)
				:attr ({
					['position'] = 'relative',
					['x'] = window:attr('width') + 3,
					['y'] = 3,

					['width'] = 25,
					['height'] = 3,

					['background-color'] = 'inherit',
					['visibility'] = 'hidden',
				})

				line:on ('touch', menuClose )
			end
		end
	end )

	window:attr ( 'height', (#programs.__keys * 2) + 1 )
	:draw ()
end )

event:on ( 'system.bar.menu.program.remove', function ( event, name )
	window:search ( 'program.entry' ):each ( function ( ui ) ui:remove () end )

	programs:remove ( name )
	programs:each ( function ( name, file )
		local line = window:create ( 'program.entry', true )
		:attr ({
			['height'] = 2,

			['align'] = 'center',
			['vertical-align'] = 'bottom',
		})
		:text ( name )
	end )

	if #programs.__keys > 0 then
		window:attr ( 'height', (#programs.__keys * 2) + 1 )
	else
		window:attr ( 'height', 3 )
		:create ( 'program.entry', true )
		:attr ({
			['height'] = 2,

			['align'] = 'center',
			['vertical-align'] = 'bottom',
		})
		:text ( 'No programs added.' )
	end
	window:draw ()
end )

for _, entry in ipairs ( filesystem.list ('/programs/' ) ) do
	local path = '/programs/' .. entry
	if filesystem.isDirectory (path) == true and filesystem.exists (path .. '/setup.lua') == true and filesystem.isDirectory (path .. '/setup.lua') == false then
		local config = serialize.fromFile ( path .. '/setup.lua' )

		if type(config) == 'table' and config.menu ~= nil then
			if type(config.menu) == 'string' then
				event:push ('system.bar.menu.program.add', config.menu, path .. '/' .. config.file, config.name)
			elseif type(config.menu) == 'table' then
				event:push ('system.bar.menu.program.add', config.menu[1], path .. '/' .. config.menu[2], config.name)
			end
		end
	end
end



desktop:draw ()
environment.set ( 'desktop', desktop )