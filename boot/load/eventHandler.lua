local insert,remove = table.insert,table.remove
local ipairs,pairs = ipairs,pairs
local type = type
local tonumber,tostring = tonumber,tostring
local pullSignal = computer.pullSignal
local random = math.random
local setmetatable, getmetatable = setmetatable, getmetatable
local ccreate, cstatus, cresume = coroutine.create, coroutine.status, coroutine.resume


local processId = 0
local processes = {}

local registered = {}
registered = setmetatable ( registered, {
	['__index'] = function ( self, key )
		self [key] = {}
		return self [key]
	end,
})

local children = {}
local jobs = {}

local __log = false
local function log ( message )
	if __log == true then
		local handle = system.filesystem.open ('/log/event-handler.log','a')
		handle:write (tostring(message) .. '\n')
		handle:close ()
	end
end

local eventHandler = {}
local __event = {
	['id'] = nil,
	['name'] = 'default',
	['_ENV'] = {},

	['type'] = 'event',
	['__registered'] = {
		['error'] = function ( event, message )
			event:signal ( 1, 'process.error', tostring(message) )
			event:destroy ()
		end,
		['process.kill'] = function ( event )
			event:destroy ()
		end,
	},

	['on'] = function ( self, event, ... )
		local arguments = {...}
		local func = remove ( arguments, #arguments )

		if func == nil then 
			return false, 'event.on: function was not supplied' 
		end

		if self.__registered [event] == nil then self.__registered [event] = {} end
		local e = {
			['owner'] = self,
			['type'] = 'event.object',

			['once'] = false,
			['arguments'] = arguments,
			['func'] = func,
			['_thread'] = nil,
		}
		insert ( self.__registered [event], e)
		insert ( registered [event], e )

		return self
	end,
	['once'] = function ( self, event, ... )
		local arguments = {...}
		local func = remove ( arguments, #arguments )

		if func == nil then return false, 'event.once: function was not supplied' end

		if  self.__registered [event] == nil then
			self.__registered [event] = {}
		end
		local e = {
			['owner'] = self,
			['type'] = 'event.object',
			
			['once'] = true,
			['arguments'] = arguments,
			['func'] = func,
			['__thread'] = nil,
		}

		insert ( self.__registered [event], e )
		insert ( registered [event], e )

		return self
	end,
	['off'] = function ( self, event, ... )
		local arguments = {...}
		if self.__registered [ event ] == nil then return self end
		local args = {...}

		if type(args[1]) == 'table' and args[1].type == 'event.object' then
			for i, e in pairs ( registered [event] ) do
				if e == args[1] then
					remove (registered[event],i)
				end
			end

			for i, e in pairs ( self.__registered [event] ) do
				if e == args[1] then
					remove (self.__registered[event],i )
				end
			end

			return true
		end
		
		self.__registered [event] = {}
		return self
	end,
	['timer'] = function ( self, time, func )
		if func == nil then return false, 'event.timer: function was not supplied' end
		if time == nil then return false, 'event.timer: time was not supplied' end

		if  self.__registered ['timer'] == nil then
			self.__registered ['timer'] = {}
		end
		local id = #self.__registered ['timer']
		local e = {
			['owner'] = self,
			['type'] = 'event.object',

			['id'] = id,
			['once'] = true,
			['time'] = tonumber (computer.uptime () + time),
			['arguments'] = {id},
			['func'] = func,
			['__thread'] = nil,
		}
		insert ( self.__registered ['timer'],  e )
		insert ( registered ['timer'], e )

		return id
	end,

	['interval'] = function ( self, time, func )
		if func == nil then return false, 'event.timer: function was not supplied' end

		if  self.__registered ['timer'] == nil then
			self.__registered ['timer'] = {}
		end

		local id = #self.__registered ['timer']
		local e = {
			['owner'] = self,
			['type'] = 'event.object',

			['id'] = id,
			['once'] = false,
			['interval'] = time,
			['time'] = tonumber( computer.uptime () + time ),
			['arguments'] = {id},
			['func'] = func,
			['__thread'] = nil,
		}
		insert ( self.__registered ['timer'], e )
		insert ( registered ['timer'], e )

		return id
	end,
	['push'] = function ( self, ... )
		local args = {...}
		insert ( args, 2, self.id )

		
		return eventHandler.push ( table.unpack (args) )
	end,
	['pull'] = function ( self, ... )
		return coroutine.yield ( ... )
	end,
	['signal'] = function ( self, to, ... )
		local args = {...}
		insert ( args, 2, to )

		if args[#args] ~= self.id then insert ( args, self.id ) end
		return eventHandler.push ( table.unpack(args) )
	end,
	['destroy'] = function ( self )
		eventHandler.destroy ( self )
	end,

	['create'] = function ( ... ) return eventHandler.create ( ... ) end,
}
__event = setmetatable ( __event, {
	['__tostring'] = function ( self )
		return self.__lastEvent or 'none'
	end,
} )

local i = 1
eventHandler = {
	['type'] = 'eventHandler',
	['__event'] = __event,
	['__environment'] = _G,
	
	['create'] = function ( owner, name)
		local continue = true

		local e = {
			['name'] = 'default',

			['type'] = 'event',
			['__registered'] = {},

			['on'] = __event.on,
			['once'] = __event.once,
			['off'] = __event.off,

			['timer'] = __event.timer,
			['interval'] = __event.interval,

			['push'] = __event.push,
			['pull'] = __event.pull,

			['signal'] = __event.signal,

			['destroy'] = __event.destroy,
			['create'] = __event.create,
		}
		e = setmetatable ( e, getmetatable ( __event ) )
		

		repeat 
			processId = processId + 1
			if processes [processId] == nil then
				continue = false
			end
		until continue == false
		e ['id'] = processId

		for event, callback in pairs ( __event.__registered ) do
			e:on ( event, callback )
		end

		if owner ~= nil and type(owner) == 'table' and owner.name == 'event' then
			if children [owner] == nil then children [owner] = {} end
			insert ( children [owner], e)
		end

		if name ~= nil and type(name) == 'string' then
			e.name = name
		end

		processes [processId] = e
		return e
	end,
	['destroy'] = function ( __event )
		if children [__event] then
			for i = 1,#children [__event], -1 do
				children [__event][i]:destroy ()
				remove ( children [__event], i )
			end

			children [__event] = nil
			__event.children = nil
		end

		for _, objects in pairs ( registered ) do
			for i, object in pairs ( objects ) do
				if object.owner == __event then
					table.remove ( objects, i )
				end
			end
		end

		processes [ __event.id ] = nil
		return true
	end,
	['push'] = function ( ... )
		computer.pushSignal ( ... )

		return true
	end,
	['handle'] = function ()
		local _continue = true
		while _continue == true do
			local timer = {
				['time'] = computer.uptime() + 10,
			}

			for id, event in pairs ( registered ['timer'] ) do
				if event.time < timer.time then
					timer = event
				end
			end
			--

			local args = {pullSignal (timer.time - computer.uptime())}
			local event = remove ( args, 1 )

			log ( 'Caught: ' .. tostring(event) ..','.. table.concat ( args, ', ' ) )
			if event == 'event-handler.stop' then return args end

			if event == nil and timer.id ~= nil and timer.func ~= nil then
				if timer.owner == nil then
					computer.pushSignal ( 'timer', timer.id )
				else
					computer.pushSignal ( 'timer', timer.owner.id, timer.id )
				end
			else
				if processes [ args[1] ] ~= nil then
					local id = remove ( args, 1 )

					eventHandler.__trigger (id, event, args)
				else
					for id in pairs ( processes ) do
						eventHandler.__trigger ( id, event, args )
					end
				end
			end
		end
	end,

	['__trigger'] = function ( processId, e, args )
		local __event = processes [processId]
		if type(__event) ~= 'table' then return end

		local events = nil
		if event == '*' then
			events = __event.__registered
		else
			if __event.__registered [e] == nil then return end
			events = {[e] = __event.__registered [e]}
		end

		for __event, events in pairs (events) do
			for i, event in pairs (events) do
				local m = #event.arguments

				for i in ipairs ( event.arguments ) do
					if event.arguments[i] == args[i] then
						m = m - 1
					end
				end

				if m < 1 then
					if event.owner ~= nil then
						event.owner.__lastEvent = e
					end

					if  event['__thread'] == nil and type(event['func']) == 'function' then
						event['__thread'] = ccreate ( event['func'] )
					end

					if cstatus ( event['__thread'] ) ~= 'dead' then
						local reason = {cresume ( event ['__thread'], event.owner or __event, table.unpack ( args ) )}
						local state = remove ( reason, 1 )

						
						if state == false then
							event.owner:push ( 'error', table.unpack (reason) )
						else
							local state, r = cstatus ( event['__thread'] )
							if state ~= 'suspended' then
								--[[ TODO, remove this section.

								if state == 'dead' and reason [1] ~= nil then
									event.owner:push ( 'error', table.unpack (reason) )
								end
								]]

								event ['__thread'] = nil
								if  event ['once'] == false and event ['time'] ~= nil and event['interval'] ~= nil then
									event ['time'] = computer.uptime () + event ['interval']
								end
							elseif reason [1] ~= nil then
								if reason [1] ~= nil and (type(reason [1]) == 'number' or reason [1]:match ( '%d+' ) ~= nil) then
									if event.owner.__registered ['timer'] == nil then event.owner.__registered ['timer'] = {} end
									local time = (tonumber ( remove ( reason, 1 ) ) or 0)
									local __event = remove (reason,1) or '*'

									local id = random ()
									if event.owner.__registered [__event] == nil then event.owner.__registered [ __event ] = {} end
									event.owner.__pulling = event['__thread']

									event.owner:on ( __event, function ( event, ... )
										cresume ( event.__pulling, event, ... )
									end )
									event.owner:timer ( time, function ( event )
										if event ~= nil and cstatus (event.__pulling) == 'suspended' then
											cresume (event.__pulling)
											event.__pulling = nil
										end
									end )
								else
									if event.owner.__registered [ reason[1] ] == nil then event.owner.__registered [ reason[1] ] = {} end
									insert ( event.owner.__registered [ remove (reason,1) ], { 
										['owner'] = event.owner,
										['type'] = 'event.object',

										['once'] = true,
										['arguments'] = reason,
										['func'] = function ( event )
											-- Lets hope we never get this far
											-- If we are here again, then we continued the thread, that died, we didn't get removed despite
											-- being, "once". So something clearly went wrong, kill it.

											event:destroy ()
										end,
										['__thread'] = event['__thread'],
									} )
								end
							end
						end
					else
						if event ['func'] == nil then
							event.owner:off ( __event, event )
						else
							event ['__thread'] = nil
						end
					end

					if event['once'] == true then
						event.owner:off ( __event, event )
					end
				end
			end
		end	
	end,
}

local sys = eventHandler.create ( nil, 'kernel' )
sys:off ('error'):on ('error', function ( event, ... )
	local args = {...}
	if event.__errorHandler ~= nil then
		event:push ( 'event-handler.stop', 'Error handler seems to have been killed: \n  "' .. table.concat (args, ', ' ) .. '"' )
	else
		event:push ( 'event-handler.stop', 'Here: ' .. table.concat ( args, ', ' ) )
	end
end )

sys:on ( 'process.error', function ( event, message )
	if event.__errorHandler ~= nil then
		eventHandler.push ( 'error', event.__errorHandler, message )
	else
		event:push ( 'error', message )
	end
end )
sys:on ( 'error.handler', function ( event, processId ) 
	event.__errorHandler = processId
end )


sys:on ( 'process.list', function ( _, processId )
	local keys = {}
	local o = {}
	
	for k in pairs ( processes ) do
		insert ( keys, k )
	end
	table.sort ( keys )

	for _,k in ipairs ( keys ) do
		insert ( o, {
			['id'] = k,
			['name'] = processes [k].name
		})
	end

	eventHandler.push ( 'process.list', processId, system.serialize.pack(o) )
end )
sys:off ('process.kill'):on ( 'process.kill', function ( event, processId, statusId, level )
	if level == nil then level = statusId statusId = nil end
	if level == 9 then
		if processes [processId] == nil and statusId ~= nil then 
			eventHandler.push ( 'process.killed', statusId, false, 'process not found' )
		else
			processes [processId]:destroy ()

			if statusId ~= nil then
				eventHandler.push ( 'process.killed', statusId, true )
			end
		end
	elseif level == 6 then
		eventHandler.push ( 'process.kill', processId, level )

		if processes [processId] == nil then
			if statusId ~= nil then
				eventHandler.push ( 'process.killed', statusId, true )
			end

			return true
		end

		local response = event:pull ( 1, 'process.alive' )
		if response == nil then
			if processes [processId] == nil and statusId ~= nil then 
				eventHandler.push ( 'process.killed', statusId, false, 'process not found' )
			else
				processes [processId]:destroy ()

				if statusId ~= nil then
					eventHandler.push ( 'process.killed', statusId, true )
				end
			end
		end
		
	else
		eventHandler.push ( 'process.kill', processId, level )

		i = i + 1
	end
end )

local count = {
	['error'] = false,
	['process.kill'] = false,

	['n'] = 0,
}
sys:on ( 'processes.dead.clean', function ( event )
	for processId, process in pairs ( processes ) do
		count.n = 0
		for event, events in pairs ( process.__registered ) do
			if #events < 1 then
				process.__registered [event] = nil
			end

			if count [event] ~= false then
				count.n = count.n + 1
			end
		end

		if count.n < 1 then
			event:push ( 'process.kill', processId, 6 )
		end
	end
end )
sys:interval ( 5, function () sys:push ('processes.dead.clean') end )

return eventHandler