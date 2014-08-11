system.desktop:create ('test', true)
:attr ({
	['position'] = 'relative',
	['x'] = 30,
	['y'] = 30,

	['width'] = 20,
	['height'] = 6,

	['align'] = 'center',
	['vertical-align'] = 'center',

	['background-color'] = 0x990000,
})
:text ('Drag me')
:on ('drag', function ( ui, event, x,y )
	ui:attr ('x',x)
	ui:attr ('y',y)

	ui:draw ()
end )
:on ('drop', function ( ui )
	ui:root ():draw ()
end)
:draw ();

system.desktop:create ('data', true)
:attr ({
	['position'] = 'relative',
	['x'] = 30,
	['y'] = 30,

	['width'] = 40,
	['height'] = 1,

	['background-color'] = 0x000099,
})
:on ('touch', function ( ui )
	local names = {}

	local elements = ui:root ():search ('*')
	elements:each ( function ( element )
		if names [ element.name ] == nil then 
			names [element.name] = 1 
		else
			names [element.name] = names [element.name] + 1
		end
	end )

	local lines = 1
	local content = ''
	for key, value in pairs (names) do
		content = content .. '[' .. key .. '] = ' .. value .. "\n"
		lines = lines + 1
	end

	ui:attr ( 'height', lines )
	ui:text ( content )
	ui:draw ()
end )