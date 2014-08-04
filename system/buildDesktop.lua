system.gui = dofile ('/library/gui.lua')


local screen = system.screens [id]
screen:clear ()

local ui = dofile ('/library/ui.lua')
ui.setScreen ( screen )
ui.setZone ( dofile ('/library/zone.lua') )
ui.setEvent ( system.event )

local desktop = ui.create ('desktop')
desktop:isRoot (true)

desktop:attr ({
	['position'] = 'absolute',
	['x'] = 1,
	['y'] = 1,

	['width'] = screen.width,
	['height'] = screen.height,

	['align'] = 'left',
	['vertical-align'] = 'top',

	['color'] = 0xFFFFFF,
	['background-color'] = 0x111111,
})
system.gui.useUI(desktop)



local bar = system.gui.system.bar:create ()
bar:attr ({
	['background-color'] = 0xDD8800,
	['z-index'] = 10,
})
desktop:append ( bar )
bar:on ('drag', function ( ui, e, x,y )	
	for _,ui in ipairs (ui:root ():search(':type(ui.element.system.bar.object.window)')) do ui:attr ('visibility', 'hidden') end

	ui:attr ({
		['position'] = 'relative',
		['y'] = y,
	})
	ui:root ():draw ()
end )
bar:on ('drop', function ( ui, e, x,y )
	if y < ui.parent:attr ('height') / 2 then
		ui:attr ( 'y', 1 )
	else
		ui:attr ( 'y', ui.parent:attr('height') )
	end

	ui:root ():draw ()
end )

local drawAll = false
local settings = bar:create ('settings')
settings:search('window'):attr ({
	['position'] = 'relative',
	['width'] = 25,
	['height'] = 4,

	['align'] = 'center',
	['vertical-align'] = 'center',
})
local line = settings:search('window'):create ('line')
settings:search('window'):append ( line )
line:text ( 'drag me: draw: local' )
line:attr ({
	['position'] = 'inline',
	['align'] = 'center',

	['height'] = 1,
})
line:on ('touch', function ( ui, e )
	if drawAll == false then
		ui:text ( 'drag me: draw(root) ' )
		drawAll = true
	else
		ui:text ( 'drag me: draw(local)' )
		drawAll = false
	end

	ui:draw ()
end )

local line = settings:search('window'):create ('line')
settings:search('window'):append ( line )
line:text ( 'reboot' )
line:attr ({
	['position'] = 'inline',
	['align'] = 'center',

	['height'] = 1,
})
line:on('touch', function ()
	computer.shutdown ( true )
end)

local test = desktop:create ('test')
desktop:append ( test )

test:attr ({
	['position'] = 'absolute',
	['x'] = 30,
	['y'] = 4,

	['width'] = 18,
	['height'] = 7,

	['background-color'] = 0xAA3300,

	['align'] = 'center',
	['vertical-align'] = 'center',
})
test:text  ('Drag me')
test:on('drag', function ( ui, e, x,y )
	ui:attr ({
		['x'] = x,
		['y'] = y,
	})

	if drawAll == true then
		ui:root ():draw ()
	else
		ui:draw ()
	end
end )
test:on('drop', function ( ui )
	ui:root ():draw ()
end )

local __log = true
if __log == true then
	local gpu = bar:create ( 'gpu' )
	gpu:search('window'):attr ({
		['width'] = 40,
		['height'] = #screen.gpu.__address + 7,

		['align'] = 'center',
		['vertical-align'] = 'center',
	})

	local gpuContent = function ()
		local str = ' Assigned GPUS:\n'
		for _,address in ipairs ( screen.gpu.__address ) do
			str = str .. address .. '\n'
		end

		str = str .. 'Requesting gpu, 4 times.\n'
		for i = 1,4 do
			screen:active ()
			str = str .. tostring( screen.__use ) .. '\n'
		end

		gpu:search('window'):attr('height', #screen.gpu.__address + 7)
		gpu:search('window'):text ( str )
		gpu:draw ()
	end
	system.event:timer ( 1, gpuContent )
	gpu:on ('touch', function ( ui )
		gpuContent ()
	end )

	local mem = desktop:create ( 'memory' )
	desktop:append ( mem )
	mem:attr ({
		['position'] = 'absolute',
		['y'] = screen.height,

		['height'] = 1,
		['z-index'] = 100,
	})
	system.event:interval (1, function ()
		mem:text ( tostring(math.floor((computer.totalMemory() - computer.freeMemory ()) / 1024)) .. 'KB / ' .. tostring(math.floor(computer.totalMemory()/1024)) .. 'KB' )
		mem:attr ({
			['width'] = mem:text():len(),
			['x'] = screen.width - mem:text():len(),
		})

		mem:draw ()
	end)
end

desktop:draw ()
return desktop