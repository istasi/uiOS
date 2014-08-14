local insert,remove = table.insert,table.remove
local ipairs,pairs = ipairs,pairs
local type = type
local tonumber,tostring = tonumber,tostring
local pullSignal = computer.pullSignal
local random = math.random
local setmetatable, getmetatable = setmetatable, getmetatable
local ccreate, cstatus, cresume = coroutine.create, coroutine.status, coroutine.resume

local start = false
local lastPull = computer.uptime ()
local processId = 0
local processes = {}

--
-- I should use this, atm im using it for what?, timers?
-- despite it containing every event being listened on
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
		insert ( self.__registered [event], e )
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

		if self.__main == nil then self.__main = e end
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
	['has'] = function ( self, event, callback )
		if callback == nil then
			if self.__registered [event] ~= nil and #self.__registered[event] > 0 then
				return true
			else
				return false
			end
		end

		if self.__registered [event] == nil or #self.__registered [event] < 1 then
			return false
		end

		for _, object in ipairs ( self.__registered [event] ) do
			if type(object) == 'table' and object.func == callback then
				return true
			end
		end
		return false
	end,
	['push'] = function ( self, ... )
		local args = {...}

		if args [1] ~= 'event-handler.stop' and self.__registered [ args[1] ] ~= nil and math.ceil (lastPull * 10) / 10 > computer.uptime () then
			local event = table.remove ( args, 1 )
			eventHandler.__trigger ( self.id, event, args )

		else
			insert ( args, 2, self.id )
			eventHandler.push ( table.unpack (args) )
		end

		return self
	end,
	['pull'] = function ( self, ... )
		return coroutine.yield ( ... )
	end,
	['signal'] = function ( self, to, ... )
		local args = {...}
		if args[#args] ~= self.id then insert ( args, self.id ) end

		if type(to) == 'string' then
			local found = false
			for _, process in pairs ( processes ) do
				if found == false and process.name == to then
					to = process.id

					found = true
				end
			end
		end

		local hasObject = false
		for _, value in pairs ( args ) do
			if type(value) == 'table' then hasObject = true end
		end

		if args[1] == 'desktop.response' then
		--	error ( tostring(hasObject) )
		end

		if args [1] ~= 'event-handler.stop' and processes [to] ~= nil and processes[to].__registered [ args[1] ] ~= nil and (math.ceil (lastPull * 10) / 10 > computer.uptime () or hasObject) then
			local event = table.remove ( args, 1 )
			eventHandler.__trigger ( to, event, args )

		else
			insert ( args, 2, to )
			return eventHandler.push ( table.unpack(args) )
		end
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

		--[[
		if owner ~= nil and type(owner) == 'table' and owner.name == 'event' then
			if children [owner.id] == nil then children [owner.id] = {} end
			insert ( children [owner.id], e)
		end
		]]

		if name ~= nil and type(name) == 'string' then
			e.name = name
		end

		processes [processId] = e
		return e
	end,
	['destroy'] = function ( __event )
		if children [__event] then
			for i = 1,#children [__event], -1 do
				log ( 'Destroying child: ' .. children [__event][i].id )

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

		log ( 'direct destroy: ' .. __event.id )
		log ( debug.traceback () )
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
			lastPull = computer.uptime ()
			local event = remove ( args, 1 )


			log ( computer.uptime () .. ': Caught: ' .. tostring(event) ..','.. table.concat ( args, ', ' ) .. ': timer:' .. tostring(timer.id) )
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
						eventHandler.__trigger (id, event, args)
					end
				end
			end
		end
	end,

	['__trigger'] = function ( processId, e, args )
		local __event = processes [processId]
		if type(__event) ~= 'table' then return nil, 'process not found' end

		local events = nil
		if e == '*' then

			events = __event.__registered
		else
			if __event.__registered [e] == nil then return nil, 'event not found in process' end
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
						local reason = nil
						if event ['nil'] == true then
							reason = {cresume ( event ['__thread'] )}
						else
							reason = {cresume ( event ['__thread'], event.owner or __event, table.unpack ( args ) )}
						end
						local state = remove ( reason, 1 )

						
						if state == false then
							if reason [1] == 'too long without yielding' then
								if event.owner.__main == event then
									reason [1] = event.owner.name .. ': main: ' .. reason [1]
								else
									reason [1] = event.owner.name .. ': ' .. e .. ': ' .. reason [1]
								end
							end
							event.owner:push ( 'error', reason [1] )
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

									insert ( event.owner.__registered [ __event ], { 
										['owner'] = event.owner,
										['type'] = 'event.object',

										['once'] = true,
										['arguments'] = reason,
										['func'] = function () end,
										['__thread'] = event['__thread'],
									} )
									insert ( registered [__event], event.owner.__registered [__event][#event.owner.__registered [__event]] )

									insert ( event.owner.__registered ['timer'], { 
										['owner'] = event.owner,
										['type'] = 'event.object',

										['id'] = math.random (),

										['nil'] = true,
										['once'] = true,
										['time'] = time + computer.uptime (),
										['arguments'] = reason,
										['func'] = function () end,
										['__thread'] = event['__thread'],
									} )
									insert ( registered ['timer'], event.owner.__registered ['timer'][#event.owner.__registered ['timer']] )
									
								else
									local __event = remove (reason,1)
									if event.owner.__registered [ __event ] == nil then event.owner.__registered [ __event ] = {} end

									insert ( event.owner.__registered [ __event ], { 
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
									insert ( registered [__event], event.owner.__registered [__event][#event.owner.__registered [__event]] )
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

		return true
	end,
}

local sys = eventHandler.create ( nil, 'kernel' )
sys:off ('error'):on ('error', function ( event, ... )
	local args = {...}
	if event.__errorHandler ~= nil and args[1] == event.__errorHandler then
		event:push ( 'event-handler.stop', 'Error handler seems to have been killed: \n  "' .. table.concat (args, ', ' ) .. '"' )
	else
		if type(args[2]) == 'number' then
			event:push ( 'event-handler.stop', '\n   Kernel: pid ' .. args[2] .. ' reports: \n' .. args[1] )
		else
			event:push ( 'event-handler.stop', args[1] )
		end
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
		} )
	end

	eventHandler.push ( 'process.list', processId, system.serialize.pack(o) )
end )
sys:off ('process.kill'):on ( 'process.kill', function ( event, processId, statusId, level )
	if level == nil then level = statusId statusId = nil end

	if level == 9 then
		if processes [processId] == nil and statusId ~= nil then 
			eventHandler.push ( 'process.killed', statusId, false, 'process not found' )
		else
			log ( 'Level 9 destroy ' .. processId )
			processes [processId]:destroy ()

			if statusId ~= nil then
				eventHandler.push ( 'process.killed', statusId, true )
			end
		end
	elseif level == 6 then
		if processId ~= 1 and processes [processId] ~= nil then
			log ( 'Telling process ' .. processId .. ' to please die.' )
			eventHandler.push ( 'process.kill', processId, level )

			-- Yeahh this code here is rather useless?
			if processes [processId] == nil then
				if statusId ~= nil then
					eventHandler.push ( 'process.killed', statusId, true )
				end

				return true
			end

			log ( 'Waiting to hear if it got anything to say for itself.' )
			local response, id = event:pull ( 1, 'process.alive' )
			if response == nil or id ~= processId then -- Note, this may cause errors, check here first if wierd shit
				log ( 'It didnt' )
				if processes [processId] == nil then
					log ( 'no response, slaughter it, wait, it disapeared?' )
					if statusId ~= nil then 
						eventHandler.push ( 'process.killed', statusId, false, 'process not found' )
					end
				else
					log ( 'We are slaughtering it, ' .. processId )
					processes [processId]:destroy ()

					if statusId ~= nil then
						eventHandler.push ( 'process.killed', statusId, true )
					end
				end
			elseif statusId ~= nil then
				eventHandler.push ( 'process.killed', statusId, false, 'process.alive received' )
			end

		end
	else
		eventHandler.push ( 'process.kill', processId, level )

		i = i + 1
	end

	log ( 'The end' )
end )

local count = {
	['error'] = false,
	['process.kill'] = false,
	['main'] = false,

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

			if event == 'main' and type(events[1].__thread) == 'thread' and cstatus (events[1].__thread) ~= 'dead' then
				count.n = count.n + 1
			end
		end

		if count.n < 1 then
			event:push ( 'process.kill', processId, 6 )
			event:timer ( 1, function ( event ) event:push ( 'processes.dead.clean' ) end )

			return 
		end
	end

	event:timer ( 5, function (event) event:push ('processes.dead.clean') end )
end )
sys:timer ( 5, function () sys:push ('processes.dead.clean') end )

return eventHandler