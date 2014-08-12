local tostring, tonumber = tostring, tonumber
local pairs, ipairs = pairs, ipairs
local error = error
local cinvoke = component.invoke
local insert,remove,concat = table.insert, table.remove, table.concat


local mounts = {}
local filesystem = {}

local fileStream = {
	['handler'] = nil,
	['address'] = nil,
	['file'] = nil,

	['read'] = function ( self, length )
		if length == nil then return nil, 'fileStream:read ([length|*all|*line]) arguement missing.' end
		if self.handler == nil then return nil, tostring(self.file) .. ' ('.. tostring(self.address) ..'): read: handle missing' end

		if length == '*a' or length == '*all' then
			cinvoke (self.address, 'seek', self.handler, 'set', 0 )
			local content = self.buffer or ''

			local continue = true
			while continue == true do
				local line = cinvoke (self.address, 'read', self.handler, 1024 )
				if line == nil then
					cinvoke (self.address, 'close', self.handler )
					continue = false
				else
					content = content .. line
				end
			end

			return content
		elseif length == '*line' then
			if self.buffer == nil then self.buffer = '' end

			local continue = true
			while continue == true do
				local pos = self.buffer:find ('\n')
				if pos == nil then
					local line = cinvoke (self.address, 'read', self.handler, 1024 )
					if line == nil then
						if self.buffer == '' then return nil end
						out = self.buffer
						self.buffer = nil

						return out
					end

					self.buffer = self.buffer .. line
				else
					local out = unicode.sub (self.buffer, 1, pos - 1)
					self.buffer = unicode.sub (self.buffer, out:len() + 2)

					return out
				end
			end
			return nil
		else
			length = tonumber (length:match ('%d+'))
			if length == nil then return nil, tostring(self.file) .. ': read: unable to determine length' end

			local read = ''
			if self.buffer ~= nil then
				if self.buffer:len () >= length then
					local out = self.buffer:sub(1,length)
					self.buffer = self.buffer:sub(length+1)
					return out
				else
					length = length - self.buffer:len ()
					read = self.buffer
					self.buffer = nil
				end
			end

			read = read .. cinvoke (self.address, 'read', self.handler, length )
			return read
		end
	end,
	['write'] = function ( self, message )
		if self.handler == nil then return nil, self.file .. ': write: handle missing' end

		return cinvoke (self.address, 'write', self.handler, message)
	end,
	['seek'] = function ( self, number )
		if self.handler == nil then return nil, self.file .. ': seek: handle missing' end

		if number:match('%d+') == nil then
			return false, 'bad argument #2, number'
		end

		return cinvoke (self.address, 'write', self.handler, number)
	end,
	['close'] = function ( self )
		if self.handler == nil then return nil, tostring(self.file) .. ': close: handle missing' end

		return cinvoke (self.address, 'close', self.handler)
	end,
}

local function getPoint ( file )
	if type(file) ~= 'string' then error ( 'filesystem.getPoint (), protected, recieved ' .. type(file) .. '\n' .. debug.traceback () ) end
	if file:sub (1,1) ~= '/' then file = '/' .. file end
	file = filesystem.canonical ( file )


	while true do
		if file == nil or file:len () == 0 then 
			return computer.getBootAddress (), '/'
		end

		file = file:sub ( 1, -2 - file:match("[^%/]*$"):len() )
		
		if mounts [file] ~= nil then
			return mounts [file], file:sub (2)
		end
	end
end

filesystem = {
	['touch'] = function ( file )
		if file == nil then return nil, 'filesystem.touch: filename is nil' end
		if filesystem.exists (file) == true then 
			return true, 'filesystem.touch: filename already exists.' 
		end

		filesystem.open ( file, 'w' ):close ()
		return true
	end,
	['open'] = function ( file, mode )
		if file == nil then return nil, 'filesystem.open: filename is nil' end

		local address, path = getPoint ( file )
		newFile = file:sub ( path:len () )

		if newFile == nil then
			error ( 'open: ' .. file .. ' ('..path..'), i got a bloody nil' )
		end

		local read = {}
		for k,v in pairs (fileStream) do read [k]=v end
		read ['address'] = address
		read ['file'] = newFile

		read ['handler'] = cinvoke (address, 'open', newFile, mode)
		return read
	end,
	['remove'] = function ( file )
		local address, path = getPoint ( file )
		file = file:sub ( path:len () )

		if file == '' or file == '/' then error ( 'Action would destroy the filesystem.' ) end

		return cinvoke (address, 'remove', file)
	end,
	['mount'] = function ( address, path )
		if path == nil or tostring(path) ~= 'string' then
			return nil, 'bad argument #2, path (string)'
		end

		mounts [path] = address
	end,
	['exists'] = function ( file )
		local address, path = getPoint ( file )
		file = file:sub ( path:len () )

		return cinvoke (address, 'exists', file)
	end,
	['isDirectory'] = function ( file )
		local address, path = getPoint ( file )
		
		return cinvoke (address, 'isDirectory', file)
	end,
	['makeDirectory'] = function ( file )
		local address, path = getPoint ( file )

		if path == ' ' then path = '' end
		if path == nil then path = '' end
		file = file:sub ( path:len () )

		return cinvoke ( address, 'makeDirectory', file )
	end,
	['list'] = function ( path )
		local address, _path = getPoint ( path )
		path = path:sub ( _path:len () )

		if path == ' ' then path = '' end
		if path == nil then path = '' end

		return cinvoke (address, 'list', path)
	end,
	['canonical'] = function ( path )
		path = path:gsub ( '\\', '/' )
		path = path:gsub ( '/+', '/' )

		local result = {}
		for k in path:gmatch ( '([^/]*)/?' ) do
			if k ~= '.' then
				if k == '..' and #result > 1 then
					remove ( result, #result )
				elseif k ~= '..' then
					insert ( result, k )
				end
			end
		end

		if result [#result] == '' then	remove ( result, #result ) end

		result, _ = concat ( result, '/' )
		return result
	end
}

return filesystem