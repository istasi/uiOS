local function c ( t ) -- lazy
	local o = {}
	for k,v in pairs ( t ) do
		if type(v) == 'table' then
			o[k] = c(v)
		else
			o[k] = v
		end
	end

	return o
end

local __list = system.filesystem.list ('/library/')
local __ui = nil
local __keys = {}
local __objects = {}

local o = {
	['useUI'] = function ( ui )
		if type(ui) ~= 'table' or (ui.type ~= 'ui' and ui.type ~= 'ui.element') then
			error ( 'gui.setUI (), argument provided is not of type ui or ui.element' )
		end

		__ui = ui
	end,

	['update'] = function ()
		__list = system.filesystem.list ('/library/')
	end,
}

return setmetatable (o, {
	['__index'] = function ( self, key )
		local valid = false
		for _,file in ipairs (__list) do
			local match = 'gui.' .. key
			if file:sub ( 1, match:len() ) == match then
				valid = true
			end
		end
		if valid == false then return nil, 'No such gui.tree found.' end


		if __keys [key] == nil then
			__keys [key] = setmetatable ({['__key'] = key}, {
				['__index'] = function ( self, key )
					local valid = false
					for _,file in ipairs (__list) do
						local match = 'gui.' .. self.__key ..'.'.. key ..'.lua'
						if file:sub ( 1, match:len() ) == match then
							valid = true
						end
					end
					if valid == false then return nil, 'No such gui.tree.object found.' end

					if __objects [self.__key ..'.'.. key] == nil then
						__objects [self.__key ..'.'.. key] = dofile ('/library/gui.'.. self.__key ..'.'.. key ..'.lua', 't', system.environment.base ({
							['system'] = system,
							['__ui'] = __ui,
							['c'] = c,
						}))
					end

					if __objects [self.__key ..'.'.. key] ~= nil and __objects [self.__key ..'.'.. key].create ~= nil then
						return __objects [self.__key ..'.'.. key]
					end
					return nil
				end,
			})
		end

		return __keys [key]
	end,
})