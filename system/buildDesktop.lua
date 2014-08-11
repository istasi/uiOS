--
-- Initialize desktop variables
system.gui = dofile ('/library/gui.lua')

local screen = system.screens [id]
screen:clear ()

local ui = dofile ('/library/ui.lua')
ui.setScreen ( screen )
ui.setZone ( dofile ('/library/zone.lua') )
ui.setEvent ( system.event:create ('ui') )


--
-- Create the dekstop element
-- this will contain everything on the screen
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

--
-- Create the bar which will serve as main method of access programs
system.gui.useUI(desktop)
local bar = system.gui.system.bar:create ('desktop.bar')
desktop:append ( bar )
bar:attr ({
	['position'] = 'relative',
	['y'] = 1,
	['y'] = 1,

	['background-color'] = 0xDD8800,
	['z-index'] = 10,
})


--
-- The Programs
-- this should contain all installed programs, 
-- Figure a format for them?
local programs = bar:create ( 'Programs' )
local window = programs:search('window')[1]
window:attr ('vertical-align', 'center')

local list = system.filesystem.list ('/programs/')
for _,file in ipairs (list) do
	if system.filesystem.isDirectory ( '/programs/' .. file ) == true then
		system.event:push ('programs.add', file )
	else
		local unsortedFile = file:match ('(.-)%.lua')
		if unsortedFile ~= nil then
			system.event:push ('programs.add', unsortedFile, file )
		end
	end
end

system.event:on ( 'programs.add', function ( event, name, file )
	if name == nil then return end

	local result = bar:search ( 'program.' .. name )
	if #result < 1 then
		if system.filesystem.exists ( '/programs/' .. name .. '/setup.lua' ) == true then
			local file = system.filesystem.open ( '/programs/' .. name .. '/setup.lua', 'r' )
			local settings = system.serialize.unpack ( file:read ('*a') )
			file:close ();

			if type(settings) ~= 'table' then return end
			if settings.file == nil then
				system.event:push ( 'error', 'building menu, no file provided for me to run ('.. name ..')' )

				return;
			end
			if system.filesystem.exists ( '/programs/' .. name ..'/' .. settings.file ) == false then
				system.event:push ( 'error', 'building menu, /programs/' .. name .. '/' .. settings.file .. ' was not found (' .. name .. ')' )

				return;
			end

			local result = bar:search ( 'programs.' .. name )
			if #result < 1 then
				result = window:create ( 'programs.' .. name )
				result:attr ( 'height', 2 )

				local label = result:create ('label', true)

				label:text ( name )

				result:on ( 'touch', function ( ui, event )
					--system.event:push ( 'program.execute', ui.__file )
				end )

				label.__file = settings.file

				--[[
				local children = {}
				local childrenNames = {}

				for k,v in pairs ( window.children ) do
					local label = v:search ('label')

					if #label > 0 and label[1].name ~= 'programs.unsorted' then
						table.insert ( childrenNames, label[1]:text () )
						table.insert ( children, v )

						v:remove ()
					end
				end

				table.sort ( childrenNames )
				for i = #childrenNames, 1, -1 do
					local element = nil

					for k,v in pairs ( children ) do

					end
				end
				]]
			end

			window:attr ( 'height', (#window.children * 2) + 1 )
		else
			local unsorted = nil
			local result = bar:search ( 'programs.unsorted' )
			if #result < 1 then
				unsorted = window:create ('programs.unsorted',true)
				unsorted:attr ({
					['height'] = 1,
				})

				unsorted:create ('label',true):attr('align','center'):text ( 'unsorted >' )
				unsorted:search ('label') [1]:on ('touch', function ( ui, e )
					e:stopPropagation ( true )

					local window = ui.parent:search ('unsorted.window')
					if #window < 1 then
						error ( 'unsorted.window is missing.')
					else
						if window [1]:attr ('visibility') == 'hidden' then
							window [1]:attr ( 'visibility', 'visible' )
							window [1]:draw ()
						else
							window [1]:attr ('visibility', 'hidden' )
							window [1]:root ():draw ()
						end
					end
				end )

				unsorted:create ('unsorted.window',true):attr ({
					['position'] = 'relative',
					['x'] = unsorted:__computed ('width') + 3,

					['width'] = 20,
					['height'] = 1,

					['visibility'] = 'hidden',
					['vertical-align'] = 'top',

					['background-color'] = 'inherit',
				})

				unsorted.__programs = {}
			else
				unsorted = result [1]
			end

			local window = unsorted:search ('unsorted.window')
			if #window < 1 then
				error ( 'unsorted.window is missing.')
			end

			window = window [1]

			local line = window:create ( 'program.' .. name, true )
			line:attr ({
				['height'] = 2,

				['align'] = 'center',
				['vertical-align'] = 'bottom',
			}):text ( name )

			line.__file = file
			line:on ('touch', function ( ui, e )
				system.event:push ( 'program.execute', ui.__file )
			end )
			
			window:attr ('height', (#window:search ('*') * 2) + 1)
		end
	end
end )

system.event:on ('program.execute', function ( event, file )
	if system.filesystem.exists ( '/programs/' .. file ) == false then 
		event:push('error', 'file not found') 
	end

	local sys = {}
	for k,v in pairs ( system ) do sys [k] = v end

	sys.event = system.event:create ()
	sys.desktop = desktop
	local env = system.environment.base ({
		['system'] = sys
	})

	local f, message = env.loadfile ( '/programs/' .. file, 't', env )
	if message ~= nil then
		return sys.event:push ('error', message)
	end

	sys.event:timer (0, function () f () end )
end )

--
-- Initialize the error handler, or ask it to get ready
do
	local _sys = {}
	for k,v in pairs(system) do _sys[k]=v end

	_sys.environment = ni
	_sys.desktop = desktop

	_sys.event = system.event:create ( 'Error handling' )
	system.errorHandler = dofile ('/system/errorHandler.lua', 't', system.environment.base ({
		['system'] = _sys
	}) )
end

desktop:draw ()
return desktop