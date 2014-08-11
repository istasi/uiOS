_G['system'] = {}
system.event = eventHandler:create ('system')
system.filesystem = filesystem
system.serialize = serialize
system.unicode = unicode
system.environment = environment

filesystem = nil
serialize = nil
unicode = nil
environment = nil

system.environment.remove ('filesystem')
system.environment.remove ('eventHandler')
system.environment.remove ('serialize')
system.environment.remove ('unicode')
system.environment.remove ('component')
system.environment.set ( '_G', {} )

eventHandler.__environment = system.environment.base ()


function print ( message )
	message = tostring(message)
	component.invoke ( component.list('gpu')(), 'copy', 1, 1, 160,50, 0, 1 )
	component.invoke ( component.list('gpu')(), 'set', 1, 1, message .. string.rep ( ' ', 160 - message:len () ) )
end

function loadfile ( _file, mode, env )
	if type(_file) ~= 'string' then error ( 'loadfile (), #1 argument should be a string path toa file' ) end
	if system.filesystem.exists ( _file ) == false then error ( 'loadfile (), supplied file does not exist' ) end
	if system.filesystem.isDirectory ( _file ) == true then error ( 'loadfile (), supplied file is a directory' ) end

	local file, reason = system.filesystem.open ( _file, 'r' )
	if reason ~= nil then error ( 'loadfile (), Error while trying to open file ' .. tostring(_file) .. ', reason given: ' .. tostring(reason) ) end
	local content = file:read ( '*a' )
	file:close ()

	local load, reason = load ( content, '=' .. _file, mode or 't', env or _G )
	if reason ~= nil then error ( 'loadfile (), error caught: ' .. tostring(reason) ) end

	return load
end

function dofile ( _file, mode, env )
	local _function = loadfile ( _file, mode or 't', env )
	local state, result = pcall ( _function )
	if state == false then error ( 'dofile (' .. tostring(_file) .. '):\n' .. tostring(result) .. '\n' ) end

	return result
end

system.environment.set ( 'dofile', dofile )
system.environment.set ( 'loadfile', loadfile )
system.environment.set ( 'class', 'lcs' )

if system.filesystem.exists ('/log/') == false then
	system.filesystem.makeDirectory ('/log/')
end


system.config 	= dofile ('/library/config.lua')
system.gpu 		= dofile ('/library/gpu.lua')
system.screens 	= dofile ('/library/difference.lua') -- Wonder if this one even saves me anything?, it seemed like a great idea in my mind, i wonder i wonder.
system.screens:setDefault (dofile ('/library/screen.lua'))

system.event:timer (0, function ()
	system.event:on ( 'component_added', function ( e, address, _type )
		if _type ~= 'screen' then return end

		local i = false
		system.screens:each ( function ( screen, _i ) if screen.address == address then i = _i end end )
		
		if i == false then
			i = system.screens:add ({
				['address'] = address,
				['gpu'] = system.gpu:get ()
			})
			system.event:push ( 'screen_added', i )
		else
			system.event:push ( 'screen_reconnect', i )
		end
	end )
	for address in component.list ('screen', true) do system.event:push ( 'component_added', address, 'screen' ) end


	system.event:on ( 'component_added', function ( _, address, _type ) 
		

		if _type ~= 'gpu' then return end
		system.gpu:addGPU (address)
	end )
	system.event:on ( 'component_removed', function ( _, address, _type )
		if _type ~= 'gpu' then return end
		system.gpu:removeGPU (address)

		local handle = system.filesystem.open ('log','a')
		handle:write ( 'here\n' )
		handle:close ()
	end )


	if system.config.screens == nil then system.config.screens = {} end
	system.event:on ( 'screen_added', function ( e, id )
		local o = {}
		for k,v in pairs (system) do o[k]=v end
		o.event = system.event:create ('desktop: ' .. system.screens[id].address )

		system.config.screens [system.screens[id].address] = dofile ('/system/buildDesktop.lua', 't', system.environment.base ({
			['system'] = o,
			['id'] = id,
		}) )
	end )

	system.event:on ( 'screen_reconnect', function ( _, id )
		local desktop = system.config.screens [system.screens [id].address]

		if type (desktop) == 'table' and desktop.type == 'ui.element' then
			desktop:draw ()
		end
	end )
end )

system.event:off ('error'):on ( 'error', function ( event, ... )
	event:signal ( 1, 'error', ({...})[1] )
	event:destroy ()
end )


return eventHandler.handle ()