local window = desktop:create ( 'control.errorHandler', true )
:attr ({
	['position'] = 'relative',
	['y'] = 3,
	['x'] = 3,

	['width'] = 100,
	['height'] = 30,

	['background-color'] = 0x88dd00,
})

window:draw ()