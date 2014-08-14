return function ( self, key )
	if type (self) ~= 'table' or self.type:match ( '^ui%.element' ) == nil then
		error ( 'ui.element:__computed (), self is missing, or not of type ui.element' )
	end

		if key == 'visibility' then
		if self:attr('visibility') == 'hidden' then
			return 'hidden'
		else
			if self.parent == nil then
				return 'visible'
			else
				return self.parent:__computed ('visibility')
			end
		end

	elseif self:attr (key) ~= nil then
		local o = self:attr (key)
		if o == nil or o == 'inherit' or o == 'transparent' then
			if self.parent ~= nil then
				o = self.parent:__computed (key)
			else
				local result = self.style.default ( key )
				if result ~= nil then return result end

				if key == 'background-color' then
					return 0x000000
				elseif key == 'color' then
					return 0xFFFFFF
				elseif key == 'width' or key == 'height' then
					return 0
				end
			end
		end

		if type(o) == 'string' and o:sub (-1) == '%' then
			if self.parent == nil then return 0 end

			local width = self.parent:__computed (key)
			local p = tonumber(o:sub(1,-2)) / 100

			return width * p
		end

		return o
	elseif key == 'XY' then
		if self.parent == nil or self:attr ('position') == 'absolute' then
			local x = self:attr ('x')
			if tostring(x) == nil or x == nil or x == 'auto' then x = 1 end

			local y = self:attr ('y')
			if tonumber(y) == nil or y == nil or y == 'auto' then y = 1 end


			return x,y
		end


		local x,y = self.parent:__computed ('XY')
		local offsetX = 0
		local offsetY = 0


		if self:attr ('position') == 'relative' then
			offsetX,offsetY = tonumber(self:attr ('x')) or 1, tonumber(self:attr ('y')) or 1

			offsetX = offsetX - 1
			offsetY = offsetY - 1

		elseif self:attr ('position') == 'inline' or self:attr ('position') == 'block' then
			if self.parent ~= nil then
				function calcAlign ( element, annoy )
					local found = false

					local offsetX = 0
					local offsetY = 0

					local align = element.parent:attr ('align')


					if align == 'center' then
						local startElement = false
						local endElement = false
						local high = 0

						for i = 1, #element.parent.children do
							local child = element.parent.children [i]

							if endElement == false then
								if child:attr ('position') == 'inline' then
									offsetX = offsetX + child:__computed ('width')
									high = math.max ( high, child:__computed ('height') )

									if offsetX > tonumber(element.parent:__computed ('width')) then
										if found ~= false then
											endElement = i - 1
										else
											startElement = i

											offsetY = offsetY + high
										end
										offsetX = child:__computed ('width')

										high = 0
									end
								end
							end

							if child == element then
								found = i
							end
						end


						if startElement == false then startElement = 1 end
						if endElement == false then endElement = #element.parent.children end
						offsetX = offsetX - element.parent.children [startElement]:__computed ('width')
						offsetX = element.parent:__computed ('width') / 2

						local width = 0
						for i = startElement, endElement, 1 do width = width + element.parent.children [i]:__computed ('width') end
						offsetX = offsetX - (width / 2)
						
						for i = startElement, found, 1 do
							offsetX = offsetX + element.parent.children [i]:__computed ('width')
						end
						offsetX = offsetX - element.parent.children [found]:__computed ('width')

					elseif align == 'right' then
						offsetX = element.parent:__computed ('width')
						local high = 0
						
						for i = 1, #element.parent.children do
							local child = element.parent.children [i]

							if found == false then
								if child:attr ('position') == 'inline' then
									offsetX = offsetX - child:__computed ('width')
									high = math.max ( high, child:__computed ('height') )

									if offsetX < 1 then
										offsetX = element.parent:__computed ('width') - child:__computed ('width')
										offsetY = offsetY + high

										high = 0
									end
								end
							end

							if child == element then
								found = true
							end
						end
					else
						local high = 0

						for i = 1, #element.parent.children do
							local child = element.parent.children [i]

							if found == false then
								if child:attr ('position') == 'inline' then
									offsetX = offsetX + tonumber (child:__computed ('width'))
									high = math.max ( high, child:__computed ('height') )

									if offsetX > tonumber(element.parent:__computed ('width')) then
										offsetX = child:__computed ('width')
										offsetY = offsetY + high

										high = 0
									end
								end
							end

							if child == element then
								found = true
							end
						end
						offsetX = offsetX - element:__computed ('width')

					end

					if annoy == true then
						error ( tostring(element.name) .. ':' .. tostring (offsetX) .. 'x' .. tostring(offsetY) )
					end
					return offsetX, offsetY
				end
				offsetX, offsetY = calcAlign ( self )

				local valign = self.parent:attr ('vertical-align')
				if valign == 'bottom' then
					local last = self.parent.children [1]
					for _,child in ipairs ( self.parent.children ) do
						if child:attr ('position') == 'inline' or child:attr ('position') == 'block' then
							last = child
						end
					end

					if last ~= nil then
						local _,maxY = calcAlign ( last )
						offsetY = (self.parent:__computed ('height') - maxY) + (offsetY - 1)
					end
				elseif valign == 'center' then
					local last = self.parent.children [1]
					for _,child in ipairs ( self.parent.children ) do
						if child:attr ('position') == 'inline' or child:attr ('position') == 'block' then
							last = child
						end
					end

					if last ~= nil then
						local _,maxY = calcAlign ( last )
						offsetY = (self.parent:__computed ('height') / 2) - (maxY / 2) + offsetY - 1
					end
				end
			end
		end

		return x + offsetX, y + offsetY
	end
end