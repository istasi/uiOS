-- Lazy depth fix

local serialize = {}
function serialize.pack ( _table, level, pretty )
	level = level or 0
	if level > 100 then return '{}' end

	pretty = pretty or false
	local t,n = '',''
	if pretty == true then t,n = '\t', '\n' end

	local str = '{ ' .. n
	for k,v in pairs ( _table ) do
		if tostring(k):match ( '^%d+$') then
			str = str .. string.rep( t, level ) .. t .. '[' .. tostring(k) .. ']'
		else
			str = str .. string.rep( t, level ) .. t .. '["' .. tostring(k) .. '"]'
		end

		str = str .. ' = '
		if type(v) == 'number' then
			str = str .. tostring(v) .. ', ' 
		elseif type(v) == 'string' then
			str = str .. '"' .. tostring(v) .. '", '
		elseif type(v) == 'table' then
			str = str .. serialize.pack (v, level + 1, pretty) .. ', ' 
		elseif type(v) == 'boolean' then
			if v == true then str = str .. 'true, ' else str = str .. 'false, ' end
		else
			str = str .. '"", '
		end

		str = str .. n
	end

	return str .. string.rep (t, level) .. '}'
end

function serialize.unpack ( str )
	local _table = {}

	if str:match ('^%{.*%}[ \r\n]*$') == nil then
		return false, 'not a valid string supplied.'
	end

	_table, reason = load('return ' .. str)
	if reason ~= nil then
		return false, 'issues loading string supplied.'
	end

	return _table ()
end

function serialize.fromFile ( _file )
	local file = nil
	if _OSVERSION and _OSVERSION:match ( '^OpenOS' ) then
		if require('filesystem').exists ( _file ) == false then error ( 'serialize.fromFile, File does not exist.' ) end
		file = io.open ( _file, 'r' )
	else
		if filesystem.exists ( file ) == false then error ( 'serialize.fromFile, File does not exist.' ) end
		file = filesystem.open ( _file, 'r' )
	end

	local content = file:read ( '*all' )
	file:close ()

	return serialize.unpack ( content )
end

function serialize.toFile ( _file, _table, pretty )
	local str = serialize.pack ( _table, 0, pretty )
	local file = nil
	if _OSVERSION and _OSVERSION:match ( '^OpenOS' ) then
		if require('filesystem').exists ( _file ) == false then error ( 'serialize.toFile, File does not exist.' ) end
		file = io.open ( _file, 'w' )
	else
		if filesystem.exists ( file ) == false then error ( 'serialize.toFile, File does not exist.' ) end
		file = filesystem.open ( _file, 'w' )
	end

	local content = file:write ( str )
	file:close ()

	return true
end

return serialize
