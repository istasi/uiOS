local window = system.desktop:create ('confirmation',true)

window:attr ({
	['position'] = 'relative',
	['x'] = (system.desktop:__computed ('width') / 2) - 20,
	['y'] = (system.desktop:__computed ('height') / 2) - 3,

	['width'] = 40,
	['height'] = 5,

	['background-color'] = 0xBB8800,

	['align'] = 'center',
})
local label = window:create ('label', true)
label:attr ({
	['height'] = 3,
	['align'] = 'center',
	['vertical-align'] = 'center',
})
label:text ('Are you sure you want to reboot?')

local yes = window:create ( 'button', true )
yes:attr ({
	['width'] = 10,
	['height'] = 1,

	['align'] = 'center',
})
yes:text ( 'yes (3)' )

system.event:interval ( 1, function ()
	local count = yes:text ():match ('%d+')
	count = count - 1

	if tonumber(count) < 1 then
		computer.shutdown (true)
	end

	yes:text ( 'yes (' .. tostring(count) .. ')' )
	yes:draw ()
end)
yes:on ('touch', function ( ui, e )
	computer.shutdown (true)
end )

local no = window:create ( 'button', true )
no:attr({
	['width'] = 10,
	['height'] = 1,

	['align'] = 'center',
})
no:text ( 'no' )
no:on ('touch', function ( ui, e )
	system.event:destroy ()

	window.parent:remove(window)
	ui:root():draw ()
end )

window:draw ()