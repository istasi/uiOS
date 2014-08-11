_G = nil
--_G ['pairs'] = 'asd'
for k,v in pairs ({1,2,3}) do i = 1 + 1 end

system.event:timer ( 10, function ()
	error ( 'trololol, delayed error ()')
end )