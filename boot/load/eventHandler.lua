local registered = {}
local children = {}
local jobs = {}

local __log = false
local function log (message)
	if __log == true then
		local handle = system.filesystem.open ('/log/event-handler.log','a')
		handle:write (tostring(message) .. '\n')
		handle:close ()
	end
end

local eventHandler = {}
local _event = {
	['id'] = nil,
	['type'] = 'event',
	['owner'] = '',
	['registered'] = {},

	['on'] = function ( self, event, ... )
		local arguments = {...}
		local func = table.remove ( arguments, #arguments )

		if func == nil then return false, 'event.on: function was not supplied' end

		if self.registered [event] == nil then self.registered [event] = {} end
		if event == 'error' then table.insert ( arguments, 1, self.id ) end

		table.insert ( self.registered [event], {
			['once'] = false,
			['arguments'] = arguments,
			['func'] = func,
			['_thread'] = nil,
		})

		return self
	end,
	['once'] = function ( self, event, ... )
		local arguments = {...}
		local func = table.remove ( arguments, #arguments )

		if func == nil then return false, 'event.once: function was not supplied' end

		if  self.registered [event] == nil then
			self.registered [event] = {}
		end

		table.insert ( self.registered [event], {
			['once'] = true,
			['arguments'] = arguments,
			['func'] = func,
			['_thread'] = nil,
		})

		return self
	end,
	['off'] = function ( self, event, ... )
		local arguments = {...}
		if self.registered [ event ] == nil then return self end

		for id,e in pairs ( self.registered [ event ] ) do
			local count = #e ['arguments']

			for _,v in pairs (event) do
				if e == v then
					count = count - 1
				end
			end

			if count < 1 then
				self.registered [id] = nil
			end
		end

		return self
	end,

	['timer'] = function ( self, time, func )
		local id = math.random ()
		if func == nil then return false, 'event.timer: function was not supplied' end
		if time == nil then return false, 'event.timer: time was not supplied' end

		if  self.registered ['timer'] == nil then
			self.registered ['timer'] = {}
		end

		table.insert ( self.registered ['timer'], {
			['id'] = id,
			['once'] = true,
			['time'] = tonumber (computer.uptime () + time),
			['arguments'] = {
				id
			},
			['func'] = func,
			['_thread'] = nil,
		} )

		return id
	end,
	['interval'] = function ( self, time, func )
		local id = math.random ()
		if func == nil then return false, 'event.timer: function was not supplied' end

		if  self.registered ['timer'] == nil then
			self.registered ['timer'] = {}
		end

		table.insert (self.registered ['timer'], {
			['id'] = id,
			['once'] = false,
			['interval'] = time,
			['time'] = tonumber( computer.uptime () + time ),
			['arguments'] = {id},
			['func'] = func,
			['_thread'] = nil,
		})

		return id
	end,

	['push'] = function ( self, ... )
		return eventHandler.push ( ... )
	end,
	['pull'] = function ( self, ... )
		return coroutine.yield ( ... ) -- Whoosh
	end,
	['destroy'] = function ( self )
		eventHandler.destroy ( self )
	end,

	['create'] = function ( ... ) return eventHandler.create ( ... ) end,
}

local i = 1
eventHandler = {
	['name'] = 'eventHandler',
	['_pushed'] = {},
	
	
	['create'] = function (owner)
		local id = nil
		local continue = true

		repeat 
			id = math.random()
			if registered [id] == nil then
				continue = false
			end
		until continue == false

		registered [id] = {}

		local e = {}
		for k,v in pairs ( _event ) do e[k]=v end

		e['id'] = id
		e['registered'] = registered [id]

		if owner ~= nil and type(owner) == 'table' and owner.name == 'event' then
			if children [owner] == nil then children [owner] = {} end
			table.insert ( children [owner], e)
		end

		return e
	end,
	['destroy'] = function ( _event )
		if children [_event] then
			for i = 1,#children [_event], -1 do
				children [_event][i]:destroy ()
				table.remove( children [_event], i )
			end

			children [_event] = nil
			_event.children = nil
		end

		registered [ _event.id ] = nil
	end,
	['push'] = function ( ... )
		computer.pushSignal ( ... )
	end,
	['handle'] = function ()
		local _continue = true
		while _continue == true do
			local timer = {
				['time'] = computer.uptime() + 10,
			}

			for id, event in pairs ( registered ) do -- So much ugly
				for on, _binds in pairs ( event ) do
					if type(_binds) == 'table' then
						for _, bind in pairs ( _binds ) do
							if on == 'timer' then
								if bind.time < timer.time then
									timer = bind
								end
							end
						end
					end
				end
			end
			--

			local event, address, arg1, arg2, arg3 = computer.pullSignal (timer.time - computer.uptime())
			log ( 'Caught: ' .. tostring(event) ..','.. tostring(address) ..','.. tostring(arg1) ..','.. tostring(arg2) ..','.. tostring(arg3) )
			if event == 'event-handler.stop' then return address end

			if event == nil and timer.id ~= nil and timer.func ~= nil then
				computer.pushSignal ( 'timer', computer.getBootAddress(), timer.id )
			else
				local args = {arg1,arg2,arg3}

				for id, _event in pairs ( registered ) do -- So much ugly
					for on, _bind in pairs ( _event ) do
						if type(_bind) == 'table' then
							if on == event or on == '*' then
								for eId, event in pairs ( _bind ) do
									local m = #event.arguments

									for i in ipairs ( event.arguments ) do
										if event.arguments [i] == args[i] then
											m = m - 1
										end
									end

									if m < 1 then
										if  event['_thread'] == nil and type(event['func']) == 'function' then
											event['_thread'] = coroutine.create ( event['func'] )
										end

										if on == 'error' then arg1 = arg2 arg2 = arg3 arg3 = nil end

										if coroutine.status ( event['_thread'] ) ~= 'dead' then
											local reason = {coroutine.resume ( event['_thread'], on, address, arg1, arg2, arg3 )}
											local state = table.remove (reason, 1)

											
											if state == false then
												log ( 'Throwing error: ' .. tostring(event['id']) ..', '.. table.concat ( reason, ', ' ) )

												eventHandler.push ( 'error', event['id'], table.unpack (reason) )
											end
											
											local state, r = coroutine.status ( event['_thread'] )
											if state ~= 'suspended' then
												if state == 'dead' and reason [1] ~= nil then
													computer.pushSignal ( 'error', computer.getBootAddress (), id, reason [1] )
												end
												event['_thread'] = nil

												if  event ['once'] == false and event ['time'] ~= nil and event['interval'] ~= nil then
													event ['time'] = computer.uptime () + event ['interval']
												end
											elseif reason [1] ~= nil then
												if reason [1] ~= nil and (type(reason [1]) == 'number' or reason [1]:match ( '%d+' ) ~= nil) then
													if _event['timer'] == nil then _event['timer'] = {} end
													local time = computer.uptime() + (tonumber ( table.remove ( reason, 1 ) ) or 0)
													local on = table.remove (reason,1) or '*'

													local id = math.random ()
													if _event [on] == nil then _event [on] = {} end
													table.insert ( _event [ on ], {
														['id'] = id,

														['once'] = true,
														['arguments'] = reason,
														['func'] = function () end,
														['_thread'] = event['_thread'],
													} )

													_event['test'] = 'woosh'

													local i = #_event [on]
													table.insert ( _event['timer'], {
														['id'] = id,
														['time'] = time,

														['once'] = true,
														['arguments'] = {id},
														['func'] = function ()
															for o, b in pairs (_event) do -- Surely there's a smarter/better way to do this?, could i scope it?
																if type(_event[o]) == 'table' then
																	for eId, event in pairs (_event[o]) do
																		if event.id == id and coroutine.status (event._thread) == 'suspended' then
																			coroutine.resume ( event._thread )
																		end
																	end
																end
															end
														end,
													} )
												else
													if _event [ reason[1] ] == nil then _event [ reason[1] ] = {} end

													table.insert ( _event [ table.remove (reason,1) ], {
														['once'] = true,
														['arguments'] = reason,
														['func'] = function ()
															table.remove ( _bind, eId )
														end,
														['_thread'] = event['_thread'],
													} )
												end
											end
										else
											if event['func'] == nil then
												table.remove ( _bind, eId )
											else
												event['_thread'] = nil
											end
										end

										-- Should the triggered event we just called only be triggered once?, if so, slaughter it
										if event['once'] == true then
											table.remove ( _bind, eId )
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end,
}

return eventHandler
