local o = {
	['element'] = __ui:create ('system.bar'),

	['create'] = function ( self, name )
		local o = c(self.element)
		o.name = name
		
		return o
	end
}

local element = o['element']
element ['type'] = 'ui.element.system.bar'
element:attr ({
	['align'] = 'left',

	['height'] = 1,
	['width'] = 'inherit',
})


element ['create'] = function ( self, name )
	local child = __ui:create ('object')
	self:append ( child )
	child.type = 'ui.element.system.bar.object'
	child:attr ({
		['position'] = 'inline',
		['align'] = 'left',

		['width'] = 20,
		['height'] = 1,
	})

	local label = __ui:create ('label')
	child:append ( label )

	label.type = 'ui.element.system.bar.object.label'
	label:attr ({
		['align'] = 'center',
		['height'] = 1,
	})
	label:text ( name )
	

	local window = __ui:create ('window')
	child:append ( window )

	window.type = 'ui.element.system.bar.object.window'
	window:attr ({
		['position'] = 'relative',
		['x'] = 3,
		['y'] = 3,

		['background-color'] = 'inherit',

		['width'] = 20,
		['height'] = 3,

		['visibility'] = 'hidden',
	})
	

	child:on ('touch', function ( ui, e, x,y, button )
		if ui:search('window') [1]:attr ('visibility') == 'hidden' then
			ui.parent:search(':type(ui.element.system.bar.object.window)'):each ( function ( ui ) ui:attr ('visibility', 'hidden') end )

			ui:search('window') [1]:attr ('visibility','visible')
		else
			ui:search('window') [1]:attr ('visibility','hidden')
		end

		ui.parent.parent:draw ()
	end)
	
	return child
end

return o