--desktop:search ( 'debug.window' ):each ( function ( window ) window:remove () end )
--error ( 'i ran' )
--[[


local dragTimer = false
local ox, oy = nil, nil
local window = system.desktop:create ( 'debug.window', true )
:attr ({
	['position'] = 'relative',
	['x'] = 10,
	['y'] = 3,

	['width'] = 100,
	['height'] = 30,

	['background-color'] = 0x996600,
})
:on ('drag', function ( ui, event, x,y )
	if ox == nil or oy == nil then
		ox, oy = ui:__computed ('XY')

		ox = ox - x
		oy = oy - y
	end

	ui:attr ({
		['x'] = x + ox,
		['y'] = y + oy,
	})
	ui:root ():draw ()
end )
:on ('drop', function ( ui )
	ox, oy = nil, nil

	ui:root ():draw ()
end)

local bar = window:create ( 'debug.window.bar', true )
:attr ({
	['position'] = 'relative',
	['x'] = 1,
	['y'] = 1,

	['height'] =  1,

	['background-color'] = 0xBB8800,
})

local processes = bar:create ( 'bar.entry', true )
:attr ({
	['width'] = '33%',
	['height'] = 1,

	['align'] = 'center',
})
:text ( 'Processes' )
:on ('touch', function ()
	system.event:push ( 'show.processes' )
end )


local ui = bar:create ( 'bar.entry', true ) 
:attr ({
	['width'] = '33%',
	['height'] = 1,

	['align'] = 'center',
})
:text ( 'UI Elements' )
:on ('touch', function ()
	system.event:push ( 'show.ui' )
end )

local other = bar:create ( 'bar.entry', true )
:attr ({
	['width'] = '33%',
	['height'] = 1,

	['align'] = 'center',
})
:text ( 'Other' )
:on ('touch', function ()
	system.event:push ( 'show.other' )
end )

local content = window:create ( 'debug.window.content', true )
:attr ({
	['position'] = 'relative',
	['x'] = 1,
	['y'] = 2,

	['height'] = window:attr('height') - 1,
	['background-color'] = 'inherit',
})

system.event:on ( 'show.processes', function ( event )
	event:signal ( 1, 'process.list', event.id )
	local _, data = event:pull ( 1, 'process.list' )
	data = system.serialize.unpack ( data )

	content:search ('*'):each ( function ( ui ) ui:remove () end )
	local line = content:create ( 'content.line', true )
	:attr ( 'height', 1 )

	line:create ( 'line.pid', true )
	:attr ( 'width', '10%' )
	:text ( '[pid]' )

	line:create ( 'line.name', true )
	:attr ( 'width', '90%' )
	:text ( 'name' )

	for _, process in ipairs ( data ) do
		local line = content:create ( 'content.line', true )
		:attr ( 'height', 1 )
		
		line:create ( 'line.pid', true )
		:attr ('width', '10%' )
		:text ( '  ' .. tostring(process.id) )

		line:create ( 'line.name', true )
		:attr ( 'width', '90%' )
		:text ( process.name )
	end

	content:draw ()
end )

system.event:on ( 'show.ui', function ( event )
	local names = {}

	local elements = system.desktop:search ('*')
	elements:each ( function ( element )
		if names [ element.name ] == nil then 
			names [element.name] = 1 
		else
			names [element.name] = names [element.name] + 1
		end
	end )

	content:search ('*'):each ( function ( ui ) ui:remove () end )
	local line = content:create ( 'content.line', true )
	:attr ( 'height', 1 )

	line:create ( 'line.amount', true )
	:attr ( 'width', '10%' )
	:text ( 'amount' )

	line:create ( 'line.name', true )
	:attr ( 'width', '90%' )
	:text ( 'name' )
	for key, value in pairs (names) do
		local line = content:create ( 'content.line', true )
		:attr ( 'height', 1 )
		
		line:create ( 'line.amount', true )
		:attr ( 'width', '10%' )
		:text ( '  ' .. tostring(value) )

		line:create ( 'line.name', true )
		:attr ( 'width', '90%' )
		:text ( tostring(key) )
	end

	content:draw ()
end )

system.event:on ( 'show.other', function ( event )
	content:search ('*'):each ( function ( ui ) ui:remove () end )

	for i=1,20 do
		local line = content:create ( 'content.line', true )
		:attr ( 'height', 1 )
		:text ( 'GPU ' .. tostring(system.screen.gpu) )
	end

	content:draw ()
end )

window:draw ();
]]