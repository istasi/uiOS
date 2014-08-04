-- Speed shitty written, do a proper rewrite

local config = {
	['type'] = 'config',

	['buffer'] = {},
	['keys'] = {},
	['values'] = {},
	['file'] = '',
	['error'] = nil,

	['load'] = function ( self, file )
		if system.filesystem.exists ( file ) == false or system.filesystem.isDirectory ( file ) then
			self.file = 'dev/null' return false, '' 
		end

		self.file = file
		local fileHandler = system.filesystem.open (file, 'r')
		local whitespace = {'\t', '\r'}

		local lineNumber = 1
		local continue = true
		while continue == true do
			local line = fileHandler:read ('*line')
			if line == nil then
				continue = false
			else
				table.insert (self.buffer, line)

				if line:sub(1,1) ~= ';' then
					for _,char in ipairs(whitespace) do line = line:gsub (char, '') end
					local key, value =  line:match ( '^([^=:]*) ?[=:] ?(.*)' )


					if value == 'true' then
						value = true
					elseif value == 'false' then
						value = false
					elseif value ~= nil and value:match ('^{.*}$') ~= nil then
						value = system.serialize.unpack(value)
					end


					if key ~= nil then
						key = key:gsub('^%s*(.-)%s*$', '%1')

						self.keys [key] = lineNumber
						self.values[lineNumber] = value
					end
				end
			end
			lineNumber = lineNumber + 1
		end
		fileHandler:close ()

		return true
	end,
	['save'] = function ( self )
		local content = table.concat ( self.buffer, "\n" )
		if self.file == 'dev/null' then return false, 'no config loaded.' end
		if self.file == '' then return false, 'no config loaded.' end
		if self.file == '/' then return false, 'no config loaded.' end

		system.filesystem.remove ( self.file )
		local fileHandler, reason = system.filesystem.open ( self.file, 'w' )
		if reason ~= nil then error ( reason ) end

		fileHandler:write ( content )
		fileHandler:close ()

		return true
	end,
	['list'] = function ( self, filter )
		local tmpTable = {}
		if filter == nil then
			for k in pairs ( self.keys ) do
				table.insert ( tmpTable,k )
			end
		else
			for k in pairs ( self.keys ) do
				if k:sub ( 1, filter:len () ) == filter then
					table.insert ( tmpTable, k )
				end
			end
		end

		local i = 0
		return function () i = i + 1; return tmpTable [i] end
	end,
}

local mt = {
	['__newindex'] = function ( self, key, value )
		if self.keys [key] == nil then
			self.keys [key] = #self.buffer + 1

			self.values [ self.keys [key] ] = value

			if type(value) == 'table' then value = system.serialize.pack (value) end
			self.buffer [#self.buffer+1] = key .. ' : ' .. value
		else

			self.values [ self.keys[key] ] = value

			if type(value) == 'table' then value = system.serialize.pack (value) end
			self.buffer [ self.keys[key] ] = key .. ' : ' .. value
		end
	end,
	['__index'] = function ( self, key )
		if self.keys [key] == nil then
			return nil, 'no such setting'
		end

		return self.values [ self.keys[key] ]
	end,
}

function config.new ( file )
	local o = {}
	for k,v in pairs(config) do o[k]=v end
	setmetatable ( o, mt )

	if file ~= nil then
		local b = {}
		for k in file:gmatch ( '([^/]*)/?' ) do table.insert (b,k) end

		local s = ''
		for i = 1, #b - 2 do
			s = system.filesystem.canonical (s .. '/' .. b[i])

			if system.filesystem.exists ( s ) == false then
				local state = system.filesystem.makeDirectory ( s )
				if state == false then error ( 'config.new (), unable to create directory: ' .. tostring(s) ) end
			end
		end

		if system.filesystem.exists ( file ) == false then
			system.filesystem.touch ( file )
		end

		o:load ( file ) 
	end
	return o
end

setmetatable ( config, mt )

return config