--mte 0v990-1
             
local M2 = {}

M2.createMTE = function()
	
	local M = {}
	
	if tonumber(system.getInfo("build")) < 2013.2076 then
		print("Warning: This build of Corona SDK is not supported.")
	end
	
	local json = require("json")
	M.physics = require("physics")
	local ceil = math.ceil
	local floor = math.floor
	local abs = math.abs
	
	local mapStorage = {}
	local totalRects = {}
	local tileSets = {}
	local tileObjects = {}
	M.tileObjects = tileObjects
	local extendedObjects = {}
	M.extendedObjects = extendedObjects
	local normalSets = {}
	local loadedTileSets = {}
	local tileSetNames = {}
	local map = {}
	local masterGroup
	local parentGroup
	local refLayer		
	local objects = {}
	local sprites = {}
	local tempObjects = {}
	local spriteLayers = {}
	local objectLayers = {}
	local source
	M.mapPath = nil
	local movingSprites = {}
	local frameTime = 1 / display.fps * 1000
	local syncData = {}
	local animatedTiles = {}
	local fadingTiles = {}
	local tintingTiles = {}
	local enableFlipRotation = false
	local enableHeightMap = false
	local holdSprite = nil
	M.spriteSortResolution = 1
	local lightIDs = 0
	M.lightingData = {fadeIn = 0.25, fadeOut = 0.25, refreshStyle = 2, refreshAlternator = 4, refreshCounter = 1, resolution = 1.1}
	local pointLightSource = nil
	M.enableNormalMaps = false
	M.objectCullerAccuracy = 2
	
	local enablePhysicsByLayer = 0
	local enablePhysics = {}
	local physicsData = {}
	physicsData.defaultDensity = 1.0
	physicsData.defaultFriction = 0.1
	physicsData.defaultBounce = 0
	physicsData.defaultBodyType = "static"
	physicsData.defaultShape = nil
	physicsData.defaultRadius = nil
	physicsData.defaultFilter = nil
	physicsData.layer = {}
	M.physicsData = physicsData
	M.managePhysicsStates = true
	
	--SCREEN CONSTANTS
	local viewableContentWidth = display.viewableContentWidth
	local screenLeft, screenTop, screenRight, screenBottom, screenCenterX, screenCenterY
	if display.viewableContentWidth < display.viewableContentHeight then
		screenCenterX = display.contentWidth / 2
		screenCenterY = display.contentHeight / 2
		screenLeft = 0 + display.screenOriginX
		screenTop = 0 + display.screenOriginY
		screenRight = display.contentWidth - display.screenOriginX
		screenBottom = display.contentHeight - display.screenOriginY
		--[[
		screenLeft = display.screenOriginX
		screenTop = display.screenOriginY
		screenBottom = display.screenOriginX + (display.pixelHeight * display.contentScaleY)
		screenRight = display.screenOriginY + (display.pixelWidth * display.contentScaleX)
		screenCenterY = display.screenOriginX + (display.pixelHeight * display.contentScaleY) / 2
		screenCenterX = display.screenOriginY + (display.pixelWidth * display.contentScaleX) / 2
		]]--
	else
		screenLeft = display.screenOriginX
		screenTop = display.screenOriginY
		screenRight = display.screenOriginX + (display.pixelHeight * display.contentScaleY)
		screenBottom = display.screenOriginY + (display.pixelWidth * display.contentScaleX)
		screenCenterX = display.screenOriginX + (display.pixelHeight * display.contentScaleY) / 2
		screenCenterY = display.screenOriginY + (display.pixelWidth * display.contentScaleX) / 2
	end	
	
	--CAMERA POSITION VARIABLES
	M.cameraX, M.cameraY, M.cameraLocX, M.cameraLocY = 0, 0, 0, 0
	local cameraX = {}
	local cameraY = {}
	local cameraLocX = {}
	local cameraLocY = {}
	local constrainTop = {}
	local constrainBottom = {}
	local constrainLeft = {}
	local constrainRight = {}
	local refMove = false
	local override = {}
	local cameraOnComplete = {}	
	local cameraFocus
	local isCameraMoving = {}
	local deltaX = {}
	local deltaY = {}
	local parallaxToggle = {}
	local worldWrapX = false
	local worldWrapY = false
	local layerWrapX = {}
	local layerWrapY = {}
	local currentScale
	local deltaZoom
	local screen = {}		
	local cullingMargin = {0, 0, 0, 0}
	local touchScroll = {false, nil, nil, nil, nil, nil}
	local pinchZoom = false
	M.maxZoom = 9999
	M.minZoom = -9999
	
	--STANDARD ISO VARIABLES
	local R45 = math.rad(45)
	M.isoScaleMod = math.cos(R45)
	M.isoScaleHeight = nil
	M.cameraXoffset = {}
	M.cameraYoffset = {}
	M.isoSort = 1
	M.overDraw = 0
	
	--LISTENERS
	local propertyListeners = {}
	local objectDrawListeners = {}
	
	--XML PARSER
	local xml = {}
	
	xml.ToXmlString = function(value)
		value = string.gsub (value, "&", "&amp;");		-- '&' -> "&amp;"
		value = string.gsub (value, "<", "&lt;");		-- '<' -> "&lt;"
		value = string.gsub (value, ">", "&gt;");		-- '>' -> "&gt;"
		value = string.gsub (value, "\"", "&quot;");	-- '"' -> "&quot;"
		value = string.gsub(value, "([^%w%&%;%p%\t% ])",
			function (c) 
				return string.format("&#x%X;", string.byte(c)) 
			end);
		return value;
	end
	
	xml.FromXmlString = function(value)
		value = string.gsub(value, "&#x([%x]+)%;",
			function(h) 
				return string.char(tonumber(h,16)) 
			end);
		value = string.gsub(value, "&#([0-9]+)%;",
			function(h) 
				return string.char(tonumber(h,10)) 
			end);
		value = string.gsub (value, "&quot;", "\"");
		value = string.gsub (value, "&apos;", "'");
		value = string.gsub (value, "&gt;", ">");
		value = string.gsub (value, "&lt;", "<");
		value = string.gsub (value, "&amp;", "&");
		return value;
	end
	
	xml.ParseArgs = function(s)
		local arg = {}
		string.gsub(s, "(%w+)=([\"'])(.-)%2", function (w, _, a)
			arg[w] = xml.FromXmlString(a);
		end)
		return arg
	end
	
	-----------------------------------------------------------
	
	local function calculateDelta( previousTouches, event )
		local id,touch = next( previousTouches )
		if event.id == id then
			id,touch = next( previousTouches, id )
			assert( id ~= event.id )
		end
 
		local dx = touch.x - event.x
		local dy = touch.y - event.y
		return dx, dy
	end
	
	local touchScrollPinchZoom = function(event)
		local result = true		
		local phase = event.phase
		local previousTouches = masterGroup.previousTouches
		local numTotalTouches = 1
		if ( previousTouches ) then
			-- add in total from previousTouches, subtract one if event is already in the array
			numTotalTouches = numTotalTouches + masterGroup.numPreviousTouches
			if previousTouches[event.id] then
				numTotalTouches = numTotalTouches - 1
			end
		end
	
		if "began" == phase then
			if numTotalTouches == 1 then
				touchScroll[2] = event.x
				touchScroll[3] = event.y
				touchScroll[4] = event.x
				touchScroll[5] = event.y
				touchScroll[6] = true
			end
			-- Very first "began" event
			if ( not masterGroup.isFocus ) then
				-- Subsequent touch events will target button even if they are outside the stageBounds of button
				display.getCurrentStage():setFocus( masterGroup )
				masterGroup.isFocus = true

				previousTouches = {}
				masterGroup.previousTouches = previousTouches
				masterGroup.numPreviousTouches = 0
			elseif ( not masterGroup.distance ) then
				local dx,dy

				if previousTouches and ( numTotalTouches ) >= 2 then
					dx,dy = calculateDelta( previousTouches, event )
				end

				-- initialize to distance between two touches
				if pinchZoom then
					if ( dx and dy ) then
						local d = math.sqrt( dx*dx + dy*dy )
						if ( d > 0 ) then
							masterGroup.distance = d
							masterGroup.xScaleOriginal = masterGroup.xScale
							masterGroup.yScaleOriginal = masterGroup.yScale
							--print( "distance = " .. masterGroup.distance )
						end
					end
				end
			end

			if not previousTouches[event.id] then
				masterGroup.numPreviousTouches = masterGroup.numPreviousTouches + 1
			end
			previousTouches[event.id] = event
			
			--Runtime:dispatchEvent({name = "mteTouchBegan", data = {levelPosX = event.x, levelPosY = event.y, id = event.id} })
		elseif masterGroup.isFocus then
			if "moved" == phase then
				if numTotalTouches == 1 then
					touchScroll[4] = event.x
					touchScroll[5] = event.y
				end

				if ( masterGroup.distance ) then
					local dx,dy
					if previousTouches and ( numTotalTouches ) >= 2 then
						dx,dy = calculateDelta( previousTouches, event )
					end			
					
					if ( dx and dy ) then
						if pinchZoom then
							local newDistance = math.sqrt( dx*dx + dy*dy )
							local scale = newDistance / masterGroup.distance
							--print( "newDistance(" ..newDistance .. ") / distance(" .. masterGroup.distance .. ") = scale("..  scale ..")" )
							if ( scale > 0 ) then
								local newScaleX = masterGroup.xScaleOriginal * scale
								local newScaleY = masterGroup.yScaleOriginal * scale
								if newScaleX < M.minZoom then
									newScaleX = M.minZoom
								elseif newScaleX > M.maxZoom then
									newScaleX = M.maxZoom
								end
								if newScaleY < M.minZoom then
									newScaleY = M.minZoom
								elseif newScaleY > M.maxZoom then
									newScaleY = M.maxZoom
								end
								masterGroup.xScale = newScaleX
								masterGroup.yScale = newScaleY
							end
						end
					end
				end
			
				if not previousTouches[event.id] then
					masterGroup.numPreviousTouches = masterGroup.numPreviousTouches + 1
				end
				previousTouches[event.id] = event
 				
 				--Runtime:dispatchEvent({name = "mteTouchMoved", data = {levelPosX = event.x, levelPosY = event.y, id = event.id} })
			elseif "ended" == phase or "cancelled" == phase then
				if numTotalTouches == 1 then
					touchScroll[2], touchScroll[3], touchScroll[4], touchScroll[5] = nil, nil, nil, nil
					touchScroll[6] = false
				end
				if previousTouches[event.id] then
					masterGroup.numPreviousTouches = masterGroup.numPreviousTouches - 1
					previousTouches[event.id] = nil
				end
 
				if ( #previousTouches > 0 ) then
					-- must be at least 2 touches remaining to pinch/zoom
					masterGroup.distance = nil
				else
					-- previousTouches is empty so no more fingers are touching the screen
					-- Allow touch events to be sent normally to the objects they "hit"
					display.getCurrentStage():setFocus( nil )
 
					masterGroup.isFocus = false
					masterGroup.distance = nil
					masterGroup.xScaleOriginal = nil
					masterGroup.yScaleOriginal = nil
 
					-- reset array
					masterGroup.previousTouches = nil
					masterGroup.numPreviousTouches = nil
				end
				--Runtime:dispatchEvent({name = "mteTouchEnded", data = {levelPosX = event.x, levelPosY = event.y, id = event.id} })
			end
		end
 		
 		local table = {}
 		for key,value in pairs(event) do
 			table[key] = value
 		end
 		table["name"] = "mteTouchScrollPinchZoom"
 		table["levelPosX"] = M.screenToLevelPosX(event.x, refLayer)
 		table["levelPosY"] = M.screenToLevelPosY(event.y, refLayer)
 		table["locX"] = M.screenToLocX(event.x, refLayer)
 		table["locY"] = M.screenToLocY(event.y, refLayer)
 		table["numTotalTouches"] = numTotalTouches
 		table["previousTouches"] = previousTouches
		Runtime:dispatchEvent(table)
	end
	
	M.enableTouchScroll = function()
		touchScroll[1] = true
		if map.layers and not pinchZoom then
			masterGroup:addEventListener("touch", touchScrollPinchZoom)
		end
	end
	
	M.enablePinchZoom = function()
		pinchZoom = true
		if map.layers and not touchScroll[1] then
			masterGroup:addEventListener("touch", touchScrollPinchZoom)
		end
	end
	
	M.disableTouchScroll = function()
		touchScroll[1] = false
		if map.layers and not pinchZoom then
			masterGroup:removeEventListener("touch", touchScrollPinchZoom)
		end
	end
	
	M.disablePinchZoom = function()
		pinchZoom = false
		if map.layers and not touchScroll[1] then
			masterGroup:removeEventListener("touch", touchScrollPinchZoom)
		end
	end
	
	M.setScreenBounds = function(left, top, right, bottom)
		screenLeft = left
		screenTop = top
		screenRight = right
		screenBottom = bottom
		screenCenterX = left + ((right - left) / 2)
		screenCenterY = top + ((bottom - top) / 2)
	end
	
	M.isoVector = function(velX, velY)
		local xDelta = velX
		local yDelta = velY
		local finalX, finalY
		if xDelta == 0 and yDelta == 0 then
			finalX = 0
			finalY = 0
		else
			--find angle
			local angle = math.atan(xDelta/yDelta)
			local length = xDelta / math.sin(angle)
			if xDelta == 0 then
				length = yDelta
			elseif yDelta == 0 then
				length = xDelta
				if xDelta < 0 then
					length = length * -1
				end
			end
			angle = angle - R45

			--find new deltas
			local xDelta2 = length * math.sin(angle)
			local yDelta2 = length * math.cos(angle)

			finalX = (xDelta2 / 1)
			finalY = (yDelta2 / map.isoRatio)
		end	
		
		return {finalX, finalY}
	end
	
	M.isoVector2 = function(velX, velY)
		local xVector = velX
		local yVector = velY * 2
	
		local yX = (yVector) * math.sin(R45)
		local yY = yX
	
		local xX = (xVector) * math.sin(R45)
		local xY = xX * -1
	
		local finalX = xX + yX
		local finalY = xY + yY
		
		return {finalX, finalY}
	end
	
	M.isoTransform = function(levelPosX, levelPosY)
		--Convert world coordinates to isometric screen coordinates
		
		--find center of map
		--local centerX = map.width / 2 * map.tilewidth
		--local centerY = map.height / 2 * map.tileheight
		local centerX = ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))
		local centerY = ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))
		
		--find x,y distances from center
		local xDelta = levelPosX - centerX
		local yDelta = levelPosY - centerY
		if yDelta == 0 then
			yDelta = 0.000000001
		end
		local finalX, finalY
		if xDelta == 0 and yDelta == 0 then
			finalX = levelPosX
			finalY = levelPosY
		else
			--find angle
			local angle = math.atan(xDelta/yDelta)
			local length = xDelta / math.sin(angle)
			if xDelta == 0 then
				length = yDelta
			elseif yDelta == 0 then
				length = xDelta
				if xDelta < 0 then
					length = length * -1
				end
			end
			angle = angle - R45

			--find new deltas
			local xDelta2 = length * math.sin(angle)
			local yDelta2 = length * math.cos(angle)
	
			finalX = centerX + (xDelta2 / 1)
			finalY = centerY + (yDelta2 / map.isoRatio)
		end
	
		return {finalX, finalY}
	end

	M.isoTransform2 = function(levelPosX, levelPosY)
		--Convert world coordinates to isometric screen coordinates

		--find center of map
		--local centerX = map.width / 2 * map.tilewidth
		--local centerY = map.height / 2 * map.tileheight
		local centerX = ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))
		local centerY = ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))
		
		--find x,y distances from center
		local xDelta = levelPosX - centerX
		local yDelta = levelPosY - centerY
		if yDelta == 0 then
			yDelta = 0.000000001
		end	
		local finalX, finalY
		if xDelta == 0 and yDelta == 0 then
			finalX = levelPosX
			finalY = levelPosY
		else	
			--find angle
			local angle = math.atan(xDelta/yDelta)
			local length = xDelta / math.sin(angle)
			if xDelta == 0 then
				length = yDelta
			elseif yDelta == 0 then
				length = xDelta
			end
			angle = angle - R45

			--find new deltas
			local xDelta2 = length * math.sin(angle)
			local yDelta2 = length * math.cos(angle)
	
			finalX = centerX + xDelta2
			finalY = centerY + (yDelta2 / map.isoRatio)
		end
		
		finalX = finalX - M.cameraXoffset[refLayer]
		finalY = finalY - M.cameraYoffset[refLayer]
		
		return {finalX, finalY}
	end

	M.isoUntransform = function(levelPosX, levelPosY)
		--find center of map
		--local centerX = map.width / 2 * map.tilewidth
		--local centerY = map.height / 2 * map.tileheight
		local centerX = ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))
		local centerY = ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))

		--find x,y distances from center
		local xDelta = (levelPosX - centerX) * 1
		local yDelta = (levelPosY - centerY) * map.isoRatio
		local finalX, finalY
		if xDelta == 0 and yDelta == 0 then
			finalX = levelPosX
			finalY = levelPosY
		else
			--find angle
			local angle = math.atan(xDelta/yDelta)
			local length = xDelta / math.sin(angle)
			if xDelta == 0 then
				length = yDelta
			elseif yDelta == 0 then
				length = xDelta
				if xDelta < 0 then
					length = length * -1
				end
			end
			angle = angle + R45

			--find new deltas
			local xDelta2 = length * math.sin(angle)
			local yDelta2 = length * math.cos(angle)
		
			finalX = centerX + xDelta2
			finalY = centerY + yDelta2
		end
	
		return {finalX, finalY}
	end

	M.isoUntransform2 = function(levelPosX, levelPosY)
		--find center of map
		--local centerX = map.width / 2 * map.tilewidth
		--local centerY = map.height / 2 * map.tileheight
		local centerX = ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))
		local centerY = ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))

		--find x,y distances from center
		levelPosX = levelPosX + M.cameraXoffset[refLayer]
		levelPosY = levelPosY + M.cameraYoffset[refLayer]
		local xDelta = (levelPosX - centerX) * 1
		local yDelta = (levelPosY - centerY) * map.isoRatio
		local finalX, finalY
		if xDelta == 0 and yDelta == 0 then
			finalX = levelPosX
			finalY = levelPosY
		else
			--find angle
			local angle = math.atan(xDelta/yDelta)
			local length = xDelta / math.sin(angle)
			if xDelta == 0 then
				length = yDelta
			elseif yDelta == 0 then
				length = xDelta
			end
			angle = angle + R45

			--find new deltas
			local xDelta2 = length * math.sin(angle)
			local yDelta2 = length * math.cos(angle)
		
			finalX = centerX + xDelta2
			finalY = centerY + yDelta2
		end
		return {finalX, finalY}
	end
	
	M.enableBox2DPhysics = function(arg)
		if arg == "by layer" then
			enablePhysicsByLayer = 1
		elseif arg == "all" or arg == "map" or not arg then
			enablePhysicsByLayer = 2
		end
	end
	
	M.getTilesWithProperty = function(key, value, level, layer)	
		local table = {}
		if layer then
			if masterGroup[layer].vars.camera then
				for x = masterGroup[layer].vars.camera[1], masterGroup[layer].vars.camera[3], 1 do
					for y = masterGroup[layer].vars.camera[2], masterGroup[layer].vars.camera[4], 1 do
						local locX, locY = x, y
						if layerWrapX[layer] then
							if locX < 1 - map.locOffsetX then
								locX = locX + map.layers[layer].width
							end
							if locX > map.layers[layer].width - map.locOffsetX then
								locX = locX - map.layers[layer].width
							end				
						end
						if layerWrapY[layer] then
							if locY < 1 - map.locOffsetY then
								locY = locY + map.layers[layer].height
							end
							if locY > map.layers[layer].height - map.locOffsetY then
								locY = locY - map.layers[layer].height
							end
						end					
						if tileObjects[layer][locX] and tileObjects[layer][locX][locY] and 
						tileObjects[layer][locX][locY].properties and tileObjects[layer][locX][locY].properties[key] then
							if value then
								if tileObjects[layer][locX][locY].properties[key] == value then
									table[#table + 1] = tileObjects[layer][locX][locY]
								end
							else
								table[#table + 1] = tileObjects[layer][locX][locY]
							end
						end
					end
				end
			end
		elseif level then
			for i = 1, #map.layers, 1 do
				if map.layers[i].properties.level == level then
					local layer = i
					if masterGroup[layer].vars.camera then
						for x = masterGroup[layer].vars.camera[1], masterGroup[layer].vars.camera[3], 1 do
							for y = masterGroup[layer].vars.camera[2], masterGroup[layer].vars.camera[4], 1 do
								local locX, locY = x, y
								if layerWrapX[layer] then
									if locX < 1 - map.locOffsetX then
										locX = locX + map.layers[layer].width
									end
									if locX > map.layers[layer].width - map.locOffsetX then
										locX = locX - map.layers[layer].width
									end				
								end
								if layerWrapY[layer] then
									if locY < 1 - map.locOffsetY then
										locY = locY + map.layers[layer].height
									end
									if locY > map.layers[layer].height - map.locOffsetY then
										locY = locY - map.layers[layer].height
									end
								end					
								if tileObjects[layer][locX] and tileObjects[layer][locX][locY] and 
								tileObjects[layer][locX][locY].properties and tileObjects[layer][locX][locY].properties[key] then
									if value then
										if tileObjects[layer][locX][locY].properties[key] == value then
											table[#table + 1] = tileObjects[layer][locX][locY]
										end
									else
										table[#table + 1] = tileObjects[layer][locX][locY]
									end
								end
							end
						end
					end
				end
			end
		else
			for i = 1, #map.layers, 1 do
				local layer = i
				if masterGroup[layer].vars.camera then
					for x = masterGroup[layer].vars.camera[1], masterGroup[layer].vars.camera[3], 1 do
						for y = masterGroup[layer].vars.camera[2], masterGroup[layer].vars.camera[4], 1 do
							local locX, locY = x, y
							if layerWrapX[layer] then
								if locX < 1 - map.locOffsetX then
									locX = locX + map.layers[layer].width
								end
								if locX > map.layers[layer].width - map.locOffsetX then
									locX = locX - map.layers[layer].width
								end				
							end
							if layerWrapY[layer] then
								if locY < 1 - map.locOffsetY then
									locY = locY + map.layers[layer].height
								end
								if locY > map.layers[layer].height - map.locOffsetY then
									locY = locY - map.layers[layer].height
								end
							end				
							if tileObjects[layer][locX] and tileObjects[layer][locX][locY] and 
							tileObjects[layer][locX][locY].properties and tileObjects[layer][locX][locY].properties[key] then
								if value then
									if tileObjects[layer][locX][locY].properties[key] == value then
										table[#table + 1] = tileObjects[layer][locX][locY]
									end
								else
									table[#table + 1] = tileObjects[layer][locX][locY]
								end
							end
						end
					end
				end
			end
		end
		
		if not layer and not level and not value and not key then
			for i = 1, #map.layers, 1 do
				local layer = i
				if masterGroup[layer].vars.camera then
					for x = masterGroup[layer].vars.camera[1], masterGroup[layer].vars.camera[3], 1 do
						for y = masterGroup[layer].vars.camera[2], masterGroup[layer].vars.camera[4], 1 do
							local locX, locY = x, y
							if layerWrapX[layer] then
								if locX < 1 - map.locOffsetX then
									locX = locX + map.layers[layer].width
								end
								if locX > map.layers[layer].width - map.locOffsetX then
									locX = locX - map.layers[layer].width
								end				
							end
							if layerWrapY[layer] then
								if locY < 1 - map.locOffsetY then
									locY = locY + map.layers[layer].height
								end
								if locY > map.layers[layer].height - map.locOffsetY then
									locY = locY - map.layers[layer].height
								end
							end	
							if tileObjects[layer][locX] and tileObjects[layer][locX][locY] and 
							tileObjects[layer][locX][locY].properties then
								table[#table + 1] = tileObjects[layer][locX][locY]
							end
						end
					end
				end
			end
		end
		
		if #table > 0 then
			return table
		end
	end
	
	M.getSprites = function(parameters)
		local parameters = parameters
		if not parameters then
			parameters = {}
		end
		local table = {}
		
		local processSprite = function(sprite, layer)
			local check = true
			if parameters.name then	
				if sprite.name ~= parameters.name then
					check = false
				end
			end
			if parameters.locX then
				if sprite.locX ~= parameters.locX then
					check = false
				end
			end
			if parameters.locY then
				if sprite.locY ~= parameters.locY then
					check = false
				end
			end
			if parameters.levelPosX then
				if sprite.levelPosX ~= parameters.levelPosX then
					check = false
				end
			end
			if parameters.levelPosY then
				if sprite.levelPosY ~= parameters.levelPosY then
					check = false
				end
			end
			if parameters.layer then
				if sprite.layer ~= parameters.layer then
					check = false
				end
			end
			if parameters.level then
				if map.layers[sprite.layer].properties and map.layers[sprite.layer].properties.level and map.layers[sprite.layer].properties.level ~= parameters.level then
					check = false
				end
			end
			if check then
				table[#table + 1] = sprite
			end
		end
		
		for i = 1, #map.layers, 1 do	
			if map.orientation == 1 then
				for j = masterGroup[i].numChildren, 1, -1 do
					for k = masterGroup[i][j].numChildren, 1, -1 do
						if not masterGroup[i][j][k].tiles then
							local sprite = masterGroup[i][j][k]
							if sprite then
								processSprite(sprite, i)
							end
						end
					end
				end
			else
				for j = masterGroup[i].numChildren, 1, -1 do
					if not masterGroup[i][j].tiles then
						if masterGroup[i][j].isDepthBuffer then
							for k = 1, masterGroup[i][j].numChildren, 1 do
								local sprite = masterGroup[i][j][k]
								if sprite then
									processSprite(sprite, i)
								end
							end
						else
							local sprite = masterGroup[i][j]
							if sprite then
								if not sprite.depthBuffer then
									processSprite(sprite, i)
								end
							end
						end
					end
				end
			end
		end
		
		if #table > 0 then
			return table
		end
	end
	
	M.toggleLayerPhysicsActive = function(layer, command)
		if map.orientation == 1 then
			if M.isoSort == 1 then
				physicsData.layer[layer].isActive = command
				for i = 1, masterGroup[layer].numChildren, 1 do
					for j = 1, masterGroup[layer][i].numChildren, 1 do
						if masterGroup[layer][i][j].tiles then
							for k = 1, masterGroup[layer][i][j].numChildren, 1 do
								if masterGroup[layer][i][j][k].bodyType then
									if not masterGroup[layer][i][j][k].properties or not masterGroup[layer][i][j][k].properties.isBodyActive then
										masterGroup[layer][i][j][k].isBodyActive = command
									end
								end
							end
						else
							if masterGroup[layer][i][j].bodyType then
								if not masterGroup[layer][i][j].properties or not masterGroup[layer][i][j].properties.isBodyActive then
									masterGroup[layer][i][j].isBodyActive = command
								end
							end
						end
					end
				end
			end
		else
			physicsData.layer[layer].isActive = command
			for i = 1, masterGroup[layer].numChildren, 1 do
				if masterGroup[layer][i].tiles then
					for j = 1, masterGroup[layer][i].numChildren, 1 do
						if masterGroup[layer][i][j].bodyType then
							if not masterGroup[layer][i][j].properties or not masterGroup[layer][i][j].properties.isBodyActive then
								masterGroup[layer][i][j].isBodyActive = command
							end
						end
					end
				elseif masterGroup[layer][i].depthBuffer then
					for j = 1, masterGroup[layer][i].numChildren, 1 do
						for k = 1, masterGroup[layer][i][j].numChildren, 1 do
							if masterGroup[layer][i][j][k].bodyType then
								if not masterGroup[layer][i][j][k].properties or not masterGroup[layer][i][j][k].properties.isBodyActive then
									masterGroup[layer][i][j][k].isBodyActive = command
								end
							end
						end
					end
				else
					if masterGroup[layer][i].bodyType then
						if not masterGroup[layer][i].properties or not masterGroup[layer][i].properties.isBodyActive then
							masterGroup[layer][i].isBodyActive = command
						end
					end
				end
			end
		end
	end
	
	M.toggleLayerPhysicsAwake = function(layer, command)
		if map.orientation == 1 then
			physicsData.layer[layer].isAwake = command
			for i = 1, masterGroup[layer].numChildren, 1 do
				for j = 1, masterGroup[layer][i].numChildren, 1 do
					if masterGroup[layer][i][j].tiles then
						for k = 1, masterGroup[layer][i][j].numChildren, 1 do
							if masterGroup[layer][i][j][k].bodyType then
								if not masterGroup[layer][i][j][k].properties or not masterGroup[layer][i][j][k].properties.isAwake then
									masterGroup[layer][i][j][k].isAwake = command
								end
							end
						end
					else
						if masterGroup[layer][i][j].bodyType then
							if not masterGroup[layer][i][j].properties or not masterGroup[layer][i][j].properties.isAwake then
								masterGroup[layer][i][j].isAwake = command
							end
						end
					end
				end
			end
		else
			physicsData.layer[layer].isAwake = command
			for i = 1, masterGroup[layer].numChildren, 1 do
				if masterGroup[layer][i].tiles then
					for j = 1, masterGroup[layer][i].numChildren, 1 do
						if masterGroup[layer][i][j].bodyType then
							if not masterGroup[layer][i][j].properties or not masterGroup[layer][i][j].properties.isAwake then
								masterGroup[layer][i][j].isAwake = command
							end
						end
					end
				elseif masterGroup[layer][i].depthBuffer then
					for j = 1, masterGroup[layer][i].numChildren, 1 do
						for k = 1, masterGroup[layer][i][j].numChildren, 1 do
							if masterGroup[layer][i][j][k].bodyType then
								if not masterGroup[layer][i][j][k].properties or not masterGroup[layer][i][j][k].properties.isAwake then
									masterGroup[layer][i][j][k].isAwake = command
								end
							end
						end
					end
				else
					if masterGroup[layer][i].bodyType then
						if not masterGroup[layer][i].properties or not masterGroup[layer][i].properties.isAwake then
							masterGroup[layer][i].isAwake = command
						end
					end
				end
			end
		end
	end
	
	M.getLoadedMaps = function()
		local mapPaths = {}
		for key,value in pairs(mapStorage) do
			mapPaths[#mapPaths + 1] = key
		end
		return mapPaths
	end

	M.unloadMap = function(mapPath)
		mapStorage[mapPath] = nil
	end

	M.toggleWorldWrapX = function(command)
		if command == true or command == false then
			worldWrapX = command
		else 
			if worldWrapX then
				worldWrapX = false
			elseif not worldWrapX then
				worldWrapX = true
			end
		end
		if map.properties then
			for i = 1, #map.layers, 1 do
				layerWrapX[i] = worldWrapX
			end
		end
	end
	
	M.toggleWorldWrapY = function(command)
		if command == true or command == false then
			worldWrapY = command
		else
			if worldWrapY then
				worldWrapY = false
			elseif not worldWrapY then
				worldWrapY = true
			end
		end
		if map.properties then
			for i = 1, #map.layers, 1 do
				layerWrapY[i] = worldWrapY
			end
		end
	end

	M.setParentGroup = function(group)
		group:insert(masterGroup)
	end

	M.enableTileFlipAndRotation = function()
		enableFlipRotation = true
	end
	
	M.enableHeightMaps = function()
		enableHeightMap = true
		if map and map.layers then
			for i = 1, #map.layers, 1 do
				if not map.layers[i].heightMap then
					map.layers[i].heightMap = {}
					for x = 1, map.width, 1 do
						map.layers[i].heightMap[x - map.locOffsetX] = {}
					end
				end
			end
		end
	end
	
	M.disableHeightMaps = function()
		enableHeightMap = false
	end
	
	M.getLevel = function(layer)
		return map.layers[layer].properties.level
	end

	local findScaleX = function(native, layer, tilewidth)
		return (map.tilewidth * map.layers[layer].properties.scaleX) / native
	end

	local findScaleY = function(native, layer)
		return (map.tileheight * map.layers[layer].properties.scaleY) / native
	end
	
	M.getCullingBounds = function(layer, arg)
		local left = masterGroup[layer].vars.camera[1]
		local top = masterGroup[layer].vars.camera[2]
		local right = masterGroup[layer].vars.camera[3]
		local bottom = masterGroup[layer].vars.camera[4]
		if left < 1 - map.locOffsetX then
			left = left + map.layers[layer].width
		end
		if right > map.layers[layer].width - map.locOffsetX then
			right = right - map.layers[layer].width
		end					
		if top < 1 - map.locOffsetY then
			top = top + map.layers[layer].height
		end
		if bottom > map.layers[layer].height - map.locOffsetY then
			bottom = bottom - map.layers[layer].height
		end
		
		local value
		if not arg then
			value = {}
			value.top = top
			value.left = left
			value.bottom = bottom
			value.right = right
		elseif arg == "top" then
			value = top
		elseif arg == "bottom" then
			value = bottom
		elseif arg == "left" then
			value = left
		elseif arg == "right" then
			value = right
		end
		return value
	end
	
	M.screenToLevelPos = function(xArg, yArg, layer)
		if map.orientation == 1 then
			local tempX, tempY = masterGroup[layer or refLayer]:contentToLocal(xArg, yArg)
			local isoPos = M.isoUntransform2(tempX, tempY)
			return isoPos[1] - map.tilewidth / 2, isoPos[2] - map.tilewidth / 2
		else
			local tempX, tempY = masterGroup[layer or refLayer]:contentToLocal(xArg, yArg)
			return tempX, tempY
		end
	end
	M.screenToLevelPosX = function(xArg, layer)
		if map.orientation == 1 then
			local tempX, tempY = masterGroup[layer or refLayer]:contentToLocal(xArg, 0)
			local isoPos = M.isoUntransform2(tempX, tempY)
			return isoPos[1] - map.tilewidth / 2
		else
			local tempX, tempY = masterGroup[layer or refLayer]:contentToLocal(xArg, 0)
			return tempX
		end
	end
	M.screenToLevelPosY = function(yArg, layer)
		if map.orientation == 1 then
			local tempX, tempY = masterGroup[layer or refLayer]:contentToLocal(0, yArg)
			local isoPos = M.isoUntransform2(tempX, tempY)
			return isoPos[2] - map.tilewidth / 2
		else
			local tempX, tempY = masterGroup[layer or refLayer]:contentToLocal(0, yArg)
			return tempY
		end
	end
	
	M.screenToLoc = function(xArg, yArg, layer)
		if map.orientation == 1 then
			local tempX, tempY = masterGroup[layer or refLayer]:contentToLocal(xArg, yArg)
			local isoPos = M.isoUntransform2(tempX, tempY)			
			local locX = math.ceil((isoPos[1] - map.tilewidth / 2) / map.tilewidth)
			local locY = math.ceil((isoPos[2] - map.tileheight / 2) / map.tileheight)
			return locX, locY
		else
			local tempX, tempY = masterGroup[layer or refLayer]:contentToLocal(xArg, yArg)
			local locX = math.ceil(tempX / map.tilewidth)
			local locY = math.ceil(tempY / map.tileheight)
			return locX, locY
		end
	end
	M.screenToLocX = function(xArg, layer)
		if map.orientation == 1 then
			local tempX, tempY = masterGroup[layer or refLayer]:contentToLocal(xArg, 0)
			local isoPos = M.isoUntransform2(tempX, tempY)			
			local locX = math.ceil((isoPos[1] - map.tilewidth / 2) / map.tilewidth)
			return locX
		else
			local tempX, tempY = masterGroup[layer or refLayer]:contentToLocal(xArg, 0)
			local locX = math.ceil(tempX / map.tilewidth)
			return locX
		end
	end
	M.screenToLocY = function(yArg, layer)
		if map.orientation == 1 then
			local tempX, tempY = masterGroup[layer or refLayer]:contentToLocal(0, yArg)
			local isoPos = M.isoUntransform2(tempX, tempY)
			local locY = math.ceil((isoPos[2] - map.tileheight / 2) / map.tileheight)
			return locY
		else
			local tempX, tempY = masterGroup[layer or refLayer]:contentToLocal(0, yArg)
			local locY = math.ceil(tempY / map.tileheight)
			return locY
		end
	end
	
	M.levelToScreenPos = function(xArg, yArg, layer)
		if map.orientation == 1 then
			local isoPos = M.isoTransform2(xArg + map.tilewidth / 2, yArg + map.tileheight / 2)
			local tempX, tempY = masterGroup[layer or refLayer]:localToContent(isoPos[1], isoPos[2])
			return tempX, tempY
		else
			local tempX, tempY = masterGroup[layer or refLayer]:localToContent(xArg, yArg)
			return tempX, tempY
		end
	end
	M.levelToScreenPosX = function(xArg, layer)
		if map.orientation == 1 then
			local isoPos = M.isoTransform2(xArg + map.tilewidth / 2, 0)
			local tempX, tempY = masterGroup[layer or refLayer]:localToContent(isoPos[1], isoPos[2])
			return tempX
		else
			local tempX, tempY = masterGroup[layer or refLayer]:localToContent(xArg, 0)
			return tempX
		end
	end
	M.levelToScreenPosY = function(yArg, layer)
		if map.orientation == 1 then
			local isoPos = M.isoTransform2(0, yArg + map.tileheight / 2)
			local tempX, tempY = masterGroup[layer or refLayer]:localToContent(isoPos[1], isoPos[2])
			return tempY
		else
			local tempX, tempY = masterGroup[layer or refLayer]:localToContent(0, yArg)
			return tempY
		end
	end
	
	M.levelToLoc = function(xArg, yArg)
		local locX = math.ceil(xArg / map.tilewidth)
		local locY = math.ceil(yArg / map.tileheight)
		return locX, locY
	end
	M.levelToLocX = function(xArg)
		local locX = math.ceil(xArg / map.tilewidth)
		return locX
	end
	M.levelToLocY = function(yArg)
		local locY = math.ceil(yArg / map.tileheight)
		return locY
	end
	
	M.locToScreenPos = function(xArg, yArg, layer)
		if map.orientation == 1 then
			local levelPosX = xArg * map.tilewidth
			local levelPosY = yArg * map.tileheight
			local isoPos = M.isoTransform2(levelPosX, levelPosY)
			local tempX, tempY = masterGroup[layer or refLayer]:localToContent(isoPos[1], isoPos[2])
			return tempX, tempY
		else
			local levelPosX = xArg * map.tilewidth - (map.tilewidth / 2)
			local levelPosY = yArg * map.tileheight - (map.tileheight / 2)
			local tempX, tempY = masterGroup[layer or refLayer]:localToContent(levelPosX, levelPosY)
			return tempX, tempY
		end
	end
	M.locToScreenPosX = function(xArg, layer)
		if map.orientation == 1 then
			local levelPosX = xArg * map.tilewidth
			local isoPos = M.isoTransform2(levelPosX, 0)
			local tempX, tempY = masterGroup[layer or refLayer]:localToContent(isoPos[1], isoPos[2])
			return tempX
		else
			local levelPosX = xArg * map.tilewidth
			local tempX, tempY = masterGroup[layer or refLayer]:localToContent(levelPosX, 0)
			return tempX
		end
	end
	M.locToScreenPosY = function(yArg, layer)
		if map.orientation == 1 then
			local levelPosY = yArg * map.tileheight
			local isoPos = M.isoTransform2(0, levelPosY)
			local tempX, tempY = masterGroup[layer or refLayer]:localToContent(isoPos[1], isoPos[2])
			return tempY
		else
			local levelPosY = yArg * map.tileheight
			local tempX, tempY = masterGroup[layer or refLayer]:localToContent(0, levelPosY)
			return tempY
		end
	end
	
	M.locToLevelPos = function(xArg, yArg)
		local levelPosX = xArg * map.tilewidth - (map.tilewidth / 2)
		local levelPosY = yArg * map.tileheight - (map.tileheight / 2)
		return levelPosX, levelPosY
	end
	M.locToLevelPosX = function(xArg)
		local levelPosX = xArg * map.tilewidth - (map.tilewidth / 2)
		return levelPosX
	end
	M.locToLevelPosY = function(yArg)
		local levelPosY = yArg * map.tileheight - (map.tileheight / 2)
		return levelPosY
	end
	
	M.convert = function(operation, arg1, arg2, layer)
		if not layer then
			layer = refLayer
		end
		local switch = nil
		if not arg1 then
			arg1 = arg2
			switch = 2
		end
		if not arg2 then
			arg2 = arg1
			switch = 1
		end

		local scaleX = map.layers[layer].properties.scaleX
		local scaleY = map.layers[layer].properties.scaleY
		local tempScaleX = map.tilewidth * map.layers[layer].properties.scaleX
		local tempScaleY = map.tileheight * map.layers[layer].properties.scaleY
	
		local value = {}
		
		if operation == "screenPosToLevelPos" then
			value.x, value.y = M.screenToLevelPos(arg1, arg2, layer)
		elseif operation == "screenPosToLoc" then
			value.x, value.y = M.screenToLoc(arg1, arg2, layer)
		end
	
		if operation == "levelPosToScreenPos" then
			value.x, value.y = M.levelToScreenPos(arg1, arg2, layer)
		elseif operation == "levelPosToLoc" then
			value.x, value.y = M.levelToLoc(arg1, arg2)
		end
		
		if operation == "locToScreenPos" then
			value.x, value.y = M.locToScreenPos(arg1, arg2, layer)
		elseif operation == "locToLevelPos" then
			value.x, value.y = M.locToLevelPos(arg1, arg2)
		end
	
		if not switch then
			return value
		elseif switch == 1 then
			return value.x
		elseif switch == 2 then
			return value.y
		end
	end
	
	local removeSprite = function(sprite, destroyObject)
		if sprite.light then
			sprite.removeLight()
		end
		if cameraFocus == sprite then
			cameraFocus = nil
		end
		if pointLightSource == sprite then
			pointLightSource = nil
		end
		if movingSprites[sprite] then
			movingSprites[sprite] = nil
		end
		if sprite.name then
			if sprites[sprite.name] then
				sprites[sprite.name] = nil
			end
		end
		if destroyObject == nil or destroyObject == true then
			sprite:removeSelf()
			sprite = nil
		else
			local stage = display.getCurrentStage()
			stage:insert(sprite)
		end
	end
	M.removeSprite = removeSprite
	
	M.addSprite = function(sprite, setup)
		local layer
		if setup.level then
			layer = spriteLayers[setup.level]
			if not layer then
				--print("Warning(addSprite): No Sprite Layer at level "..setup.level..". Defaulting to "..refLayer..".")
				for i = 1, #map.layers, 1 do
					if map.layers[i].properties.level == setup.level then
						layer = i
						break
					end
				end
				if not layer then
					layer = refLayer
				end
			end
		elseif setup.layer then
			layer = setup.layer
			if layer > #map.layers then
				print("Warning(addSprite): Layer out of bounds. Defaulting to "..refLayer..".")
				layer = refLayer
			end
		else
			if sprite.parent.vars then
				layer = sprite.parent.vars.layer
			else
				--print("Warning(addSprite): You forgot to specify a Layer or level. Defaulting to "..refLayer..".")
				layer = refLayer
			end
		end
		
		if setup.color then
			sprite.color = setup.color
		end
		if sprite.lighting == nil then
			if setup.lighting ~= nil then
				sprite.lighting = setup.lighting
			else
				sprite.lighting = true
			end
		end
		
		if not setup.kind or setup.kind == "sprite" then
			sprite.objType = 1
			if sprite.lighting then
				if not sprite.color then
					sprite.color = {1, 1, 1}
				end
				local mL = map.layers[setup.layer]
				sprite:setFillColor((mL.redLight)*sprite.color[1], (mL.greenLight)*sprite.color[2], (mL.blueLight)*sprite.color[3])
			end
		elseif setup.kind == "imageRect" then
			sprite.objType = 2
			if sprite.lighting then
				if not sprite.color then
					sprite.color = {1, 1, 1}
				end
				local mL = map.layers[setup.layer]
				sprite:setFillColor((mL.redLight)*sprite.color[1], (mL.greenLight)*sprite.color[2], (mL.blueLight)*sprite.color[3])
			end
		elseif setup.kind == "group" then
			sprite.objType = 3
			if sprite.lighting then
				local mL = map.layers[setup.layer]
				for i = 1, sprite.numChildren, 1 do
					if sprite[i]._class then
						if sprite.color and not sprite[i].color then
							sprite[i].color = sprite.color
						end
						if not sprite[i].color then
							sprite[i].color = {1, 1, 1}
						end
						sprite[i]:setFillColor((mL.redLight)*sprite[i].color[1], (mL.greenLight)*sprite[i].color[2], (mL.blueLight)*sprite[i].color[3])
					end
				end
			end
		elseif setup.kind == "vector" then
			sprite.objType = 4
			if sprite.lighting then
				local mL = map.layers[setup.layer]
				for i = 1, sprite.numChildren, 1 do
					if sprite[i]._class then
						if sprite.color and not sprite[i].color then
							sprite[i].color = sprite.color
						end
						if not sprite[i].color then
							sprite[i].color = {1, 1, 1}
						end
						sprite[i]:setStrokeColor((mL.redLight)*sprite[i].color[1], (mL.greenLight)*sprite[i].color[2], (mL.blueLight)*sprite[i].color[3])
					end
				end
			end
		end
		
		if setup.followHeightMap then
			sprite.followHeightMap = setup.followHeightMap
		end
		if setup.heightMap then
			sprite.heightMap = setup.heightMap
		end
		if setup.offscreenPhysics then
			sprite.offscreenPhysics = true
		end
		if M.enableLighting then
			sprite.litBy = {}
			sprite.prevLitBy = {}
		end
		local spriteName = sprite.name or setup.name
		if not spriteName or spriteName == "" then
			spriteName = ""..sprite.x.."_"..sprite.y.."_"..layer
		end
		if sprites[spriteName] and sprites[spriteName] ~= sprite then
			local tempName = spriteName
			local counter = 1
			while sprites[tempName] do
				tempName = ""..spriteName..counter
				counter = counter + 1
			end
			spriteName = tempName
		end
		sprite.name = spriteName
		if not sprites[spriteName] then
			sprites[spriteName] = sprite
		end
		sprite.park = false
		if setup.park == true then
			sprite.park = true
		end
		
		if setup.sortSprite ~= nil then
			sprite.sortSprite = setup.sortSprite
		else
			sprite.sortSprite = false
		end
		if setup.sortSpriteOnce ~= nil then
			sprite.sortSpriteOnce = setup.sortSpriteOnce
		end
		if not sprite.constrainToMap then
			sprite.constrainToMap = {true, true, true, true}
		end
		if setup.constrainToMap ~= nil then
			sprite.constrainToMap = setup.constrainToMap
		end
		sprite.locX = nil
		sprite.locY = nil
		sprite.levelPosX = nil
		sprite.levelPosY = nil
		if setup.layer then
			sprite.layer = setup.layer
			sprite.level = map.layers[setup.layer].properties.level
		end
		sprite.deltaX = {}
		sprite.deltaY = {}
		sprite.velX = nil
		sprite.velY = nil
		sprite.isMoving = false
		if map.orientation == 1 then
			if setup.levelWidth then
				sprite.levelWidth = setup.levelWidth
				if sprite.objType ~= 3 then
					sprite.xScale = setup.levelWidth / (setup.sourceWidth or sprite.width)
				end
			else
				sprite.levelWidth = sprite.width
			end
			if setup.levelHeight then
				sprite.levelHeight = setup.levelHeight
				if sprite.objType ~= 3 then
					sprite.yScale = setup.levelHeight / (setup.sourceHeight or sprite.height)
				end
			else
				sprite.levelHeight = sprite.height
			end
			if setup.levelPosX then
				sprite.levelPosX = setup.levelPosX			
				sprite.locX = M.levelToLocX(sprite.x)			
			elseif setup.locX then
				sprite.levelPosX = M.locToLevelPosX(setup.locX)			
				sprite.locX = setup.locX			
			else
				sprite.levelPosX = sprite.x			
				sprite.locX = M.levelToLocX(sprite.x)
			end
			if setup.levelPosY then
				sprite.levelPosY = setup.levelPosY
				sprite.locY = M.levelToLocY(sprite.y)
			elseif setup.locY then
				sprite.levelPosY = M.locToLevelPosX(setup.locY)
				sprite.locY = setup.locY
			else
				sprite.levelPosY = sprite.y
				sprite.locY = M.levelToLocY(sprite.y)
			end
			local isoPos = M.isoTransform2(sprite.levelPosX, sprite.levelPosY)
			sprite.x = isoPos[1]
			sprite.y = isoPos[2]
		else
			if setup.levelWidth then
				sprite.levelWidth = setup.levelWidth
				sprite.xScale = setup.levelWidth / (setup.sourceWidth or sprite.width)
			else
				sprite.levelWidth = sprite.width
			end
			if setup.levelHeight then
				sprite.levelHeight = setup.levelHeight
				sprite.yScale = setup.levelHeight / (setup.sourceHeight or sprite.height)
			else
				sprite.levelHeight = sprite.height
			end
			if setup.levelPosX then
				sprite.x = setup.levelPosX			
				sprite.locX = M.levelToLocX(sprite.x)			
			elseif setup.locX then
				sprite.x = M.locToLevelPosX(setup.locX)			
				sprite.locX = setup.locX			
			else
				sprite.locX = M.levelToLocX(sprite.x)	
			end
			if setup.levelPosY then
				sprite.y = setup.levelPosY
				sprite.locY = M.levelToLocY(sprite.y)
			elseif setup.locY then
				sprite.y = M.locToLevelPosX(setup.locY)
				sprite.locY = setup.locY
			else
				sprite.locY = M.levelToLocY(sprite.y)
			end
			sprite.levelPosX = sprite.x
			sprite.levelPosY = sprite.y
		end
		sprite.lightingListeners = {}
		sprite.addLightingListener = function(self, name, listener)
			sprite.lightingListeners[name] = true
			sprite:addEventListener(name, listener)
		end
		sprite.addLight = function(light)
			if M.enableLighting then
				sprite.light = light
				sprite.light.created = true
				if not sprite.light.id then
					sprite.light.id = lightIDs
				end
				lightIDs = lightIDs + 1
		
				if not sprite.light.maxRange then
					local maxRange = sprite.light.range[1]
					for l = 1, 3, 1 do
						if sprite.light.range[l] > maxRange then
							maxRange = sprite.light.range[l]
						end
					end
					sprite.light.maxRange = maxRange
				end
		
				if not sprite.light.levelPosX then
					sprite.light.levelPosX = sprite.levelPosX
					sprite.light.levelPosY = sprite.levelPosY
				end
				
				if not sprite.light.alternatorCounter then
					sprite.light.alternatorCounter = 1
				end
		
				if sprite.light.rays then
					sprite.light.areaIndex = 1
				end
				
				if sprite.light.layerRelative then
					sprite.light.layer = sprite.layer + sprite.light.layerRelative
					if sprite.light.layer < 1 then
						sprite.light.layer = 1
					end
					if sprite.light.layer > #map.layers then
						sprite.light.layer = #map.layers
					end
				end				
				
				if not sprite.light.layer then
					sprite.light.layer = sprite.layer
				end
				sprite.light.level = sprite.level
				sprite.light.dynamic = true
				sprite.light.area = {}
				sprite.light.sprite = sprite
				map.lights[sprite.light.id] = sprite.light
			end
		end
		sprite.removeLight = function()
			if sprite.light.rays then
				sprite.light.areaIndex = 1
			end
		
			local length = #sprite.light.area
			for i = length, 1, -1 do
				local locX = sprite.light.area[i][1]
				local locY = sprite.light.area[i][2]
				sprite.light.area[i] = nil

				if worldWrapX then
					if locX < 1 - map.locOffsetX then
						locX = locX + map.width
					end
					if locX > map.width - map.locOffsetX then
						locX = locX - map.width
					end
				end
				if worldWrapY then
					if locY < 1 - map.locOffsetY then
						locY = locY + map.height
					end
					if locY > map.height - map.locOffsetY then
						locY = locY - map.height
					end
				end
				if sprite.light.layer then
					if map.layers[sprite.light.layer].lighting[locX] and map.layers[sprite.light.layer].lighting[locX][locY] then
						map.layers[sprite.light.layer].lighting[locX][locY][sprite.light.id] = nil
						map.lightToggle[locX][locY] = tonumber(system.getTimer())
					end	
				end
			end
			map.lights[sprite.light.id] = nil
			sprite.light = nil
		end		
		if layerWrapX[i] and (sprite.wrapX == nil or sprite.wrapX == true) then
			while sprite.levelPosX < 1 - (map.locOffsetX * map.tilewidth) do
				sprite.levelPosX = sprite.levelPosX + map.layers[i].width * map.tilewidth
			end
			while sprite.levelPosX > map.layers[i].width * map.tilewidth - (map.locOffsetX * map.tilewidth) do
				sprite.levelPosX = sprite.levelPosX - map.layers[i].width * map.tilewidth
			end		
			if cameraX - sprite.x < map.layers[i].width * map.tilewidth / -2 then
				--wrap around to the left
				sprite.x = sprite.x - map.layers[i].width * map.tilewidth
			elseif cameraX - sprite.x > map.layers[i].width * map.tilewidth / 2 then
				--wrap around to the right
				sprite.x = sprite.x + map.layers[i].width * map.tilewidth
			end
		end		
		if layerWrapY[i] and (sprite.wrapY == nil or sprite.wrapY == true) then
			while sprite.levelPosY < 1 - (map.locOffsetY * map.tileheight) do
				sprite.levelPosY = sprite.levelPosY + map.layers[i].height * map.tileheight
			end
			while sprite.levelPosY > map.layers[i].height * map.tileheight - (map.locOffsetY * map.tileheight) do
				sprite.levelPosY = sprite.levelPosY - map.layers[i].height * map.tileheight
			end		
			if cameraY - sprite.y < map.layers[i].height * map.tileheight / -2 then
				--wrap around to the left
				sprite.y = sprite.y - map.layers[i].height * map.tileheight
			elseif cameraY - sprite.y > map.layers[i].height * map.tileheight / 2 then
				--wrap around to the right
				sprite.y = sprite.y + map.layers[i].height * map.tileheight
			end
		end		
		sprite.locX = math.ceil(sprite.levelPosX / map.tilewidth)
		sprite.locY = math.ceil(sprite.levelPosY / map.tileheight)
		if setup.offsetX then
			sprite.offsetX = setup.offsetX
			--sprite.anchorX = ((sprite.width / 2) - sprite.offsetX) / sprite.width
			sprite.anchorX = (((sprite.levelWidth or sprite.width) / 2) - sprite.offsetX) / (sprite.levelWidth or sprite.width)
		else
			sprite.offsetX = 0
		end
		if setup.offsetY then
			sprite.offsetY = setup.offsetY
			--sprite.anchorY = ((sprite.height / 2) - sprite.offsetY) / sprite.height
			sprite.anchorY = (((sprite.levelHeight or sprite.height) / 2) - sprite.offsetY) / (sprite.levelHeight or sprite.height)
		else
			sprite.offsetY = 0
		end
		if map.orientation == 1 then
			if M.isoSort == 1 then
				masterGroup[setup.layer][sprite.locX + sprite.locY - 1]:insert(sprite)
				sprite.row = sprite.locX + sprite.locY - 1
			else
				masterGroup[(sprite.locX + (sprite.level - 1)) + (sprite.locY + (sprite.level - 1)) - 1].layers[setup.layer]:insert(sprite)
			end
		else
			masterGroup[layer]:insert(sprite)
		end	
		
		if setup.properties then
			if not sprite.properties then
				sprite.properties = {}
			end
			for key,value in pairs(setup.properties) do
				sprite.properties[key] = value
			end
		end
		
		if setup.managePhysicsStates ~= nil then
			sprite.managePhysicsStates = setup.managePhysicsStates
		end
		
		return sprite		
	end
	
	local addObject = function(layer, table)
		local layer = layer
		if map.layers[layer].properties.objectLayer then
			map.layers[layer].objects[#map.layers[layer].objects + 1] = table
		else
			print("ERROR: Not an Object Layer.")
		end
	end
	M.addObject = addObject

	local removeObject = function(name, lyr)
		if not lyr then
			local debug = 0
			for j = 1, #map.layers, 1 do
				local layer = j
				if map.layers[layer].properties.objectLayer then
					for i = 1, #map.layers[layer].objects, 1 do
						local object = map.layers[layer].objects[i]
						if name == object.name then
							table.remove(map.layers[layer].objects, i)
							debug = 1
							break
						end
					end
				end
				if debug == 1 then
					break
				end
			end
			if debug == 0 then
				print("ERROR: Object Not Found.")
			end
		else
			local layer = lyr
			local debug = 0
			if map.layers[layer].properties.objectLayer then
				for i = 1, #map.layers[layer].objects, 1 do
					local object = map.layers[layer].objects[i]
					if name == object.name then
						table.remove(map.layers[layer].objects, i)
						debug = 1
						break
					end
				end
			else
				print("ERROR: Not an Object Layer.")
			end
			if debug == 0 then
				print("ERROR: Object Not Found.")
			end
		end
	end
	M.removeObject = removeObject

	M.getTileAt = function(parameters)
		local locX = parameters.locX
		local locY = parameters.locY
		local layer = parameters.layer
		if parameters.levelPosX then
			locX, locY = M.levelToLoc(parameters.levelPosX, parameters.levelPosY)
		end
		if not layer then
			local values = {}
			for i = 1, #map.layers, 1 do
				if locX > map.layers[i].width - map.locOffsetX then
					locX = locX - map.layers[i].width
				elseif locX < 1 - map.locOffsetX then
					locX = locX + map.layers[i].width
				end
				if locY > map.layers[i].height - map.locOffsetY then
					locY = locY - map.layers[i].height
				elseif locY < 1 - map.locOffsetY then
					locY = locY + map.layers[i].height
				end
				values[i] = map.layers[i].world[locX][locY]
			end
			return values
		else
			if locX > map.layers[layer].width - map.locOffsetX then
				locX = locX - map.layers[layer].width
			elseif locX < 1 - map.locOffsetX then
				locX = locX + map.layers[layer].width
			end
			if locY > map.layers[layer].height - map.locOffsetY then
				locY = locY - map.layers[layer].height
			elseif locY < 1 - map.locOffsetY then
				locY = locY + map.layers[layer].height
			end
			return map.layers[layer].world[locX][locY]
		end
	end
	
	M.getTileProperties = function(options)
		if options.levelPosX then
			options.locX, options.locY = M.levelToLoc(options.levelPosX, options.levelPosY)
		end
		if options.tile then
			local tile = options.tile
			local properties = nil
			if tile ~= 0 then
				local tileset = 1
				for i = #map.tilesets, 1, -1 do
					if tile >= map.tilesets[i].firstgid then
						tileset = i
						break
					end
				end
				local tileStr = 0
				if tileset == 1 then
					tileStr = tostring(tile - 1)
				else
					tileStr = tostring(tile - map.tilesets[tileset].firstgid)
				end
				if map.tilesets[tileset].tileproperties then
					if map.tilesets[tileset].tileproperties[tileStr] then
						properties = {}
						properties = map.tilesets[tileset].tileproperties[tileStr]
					end
				end
			end
			return properties
		elseif options.locX and options.locY then
			if options.layer then
				--local tile = getTileAt({locX = options.locX, locY = options.locY, layer = options.layer})
				------------------------------------------------------------------------------
				local locX = options.locX
				local locY = options.locY
				local layer = options.layer
				if locX > map.layers[layer].width - map.locOffsetX then
					locX = locX - map.layers[layer].width
				elseif locX < 1 - map.locOffsetX then
					locX = locX + map.layers[layer].width
				end
				if locY > map.layers[layer].height - map.locOffsetY then
					locY = locY - map.layers[layer].height
				elseif locY < 1 - map.locOffsetY then
					locY = locY + map.layers[layer].height
				end
				local tile = map.layers[layer].world[locX][locY]
				------------------------------------------------------------------------------
				local properties = nil
				if tile ~= 0 then
					local tileset = 1
					for i = #map.tilesets, 1, -1 do
						if tile >= map.tilesets[i].firstgid then
							tileset = i
							break
						end
					end
					local tileStr = 0
					if tileset == 1 then
						tileStr = tostring(tile - 1)
					else
						tileStr = tostring(tile - map.tilesets[tileset].firstgid)
					end
					if map.tilesets[tileset].tileproperties then
						if map.tilesets[tileset].tileproperties[tileStr] then
							properties = {}
							properties = map.tilesets[tileset].tileproperties[tileStr]
						end
					end
				end

				return properties
			elseif options.level then
				local array = {}
				for i = 1, #map.layers, 1 do
					if map.layers[i].properties.level == options.level then
						--local tile = getTileAt({ locX = options.locX, locY = options.locY, layer = i})
						------------------------------------------------------------------------------
						local locX = options.locX
						local locY = options.locY
						local layer = i
						if locX > map.layers[layer].width - map.locOffsetX then
							locX = locX - map.layers[layer].width
						elseif locX < 1 - map.locOffsetX then
							locX = locX + map.layers[layer].width
						end
						if locY > map.layers[layer].height - map.locOffsetY then
							locY = locY - map.layers[layer].height
						elseif locY < 1 - map.locOffsetY then
							locY = locY + map.layers[layer].height
						end
						local tile = map.layers[layer].world[locX][locY]
						------------------------------------------------------------------------------
						local tileset = 1
						for i = #map.tilesets, 1, -1 do
							if tile >= map.tilesets[i].firstgid then
								tileset = i
								break
							end
						end
						array[#array + 1] = {}
						array[#array].tile = tile
						array[#array].layer = i
						if map.tilesets[tileset].tileproperties then
							local tileStr = 0
							if tileset == 1 then
								tileStr = tostring(tile - 1)
							else
								tileStr = tostring(tile - map.tilesets[tileset].firstgid)
							end
							array[#array].properties = map.tilesets[tileset].tileproperties[tileStr]
						else
							array[#array].properties = nil
						end
						if map.layers[i].properties then
							array[#array].level = map.layers[i].properties.level
							array[#array].scaleX = map.layers[i].properties.scaleX
							array[#array].scaleY = map.layers[i].properties.scaleY
						end
					end
				end
				return array
			else
				local array = {}
				for i = 1, #map.layers, 1 do
					--local tile = getTileAt({locX = options.locX, locY = options.locY, layer = i})
					------------------------------------------------------------------------------
					local locX = options.locX
					local locY = options.locY
					local layer = i
					if locX > map.layers[layer].width - map.locOffsetX then
						locX = locX - map.layers[layer].width
					elseif locX < 1 - map.locOffsetX then
						locX = locX + map.layers[layer].width
					end
					if locY > map.layers[layer].height - map.locOffsetY then
						locY = locY - map.layers[layer].height
					elseif locY < 1 - map.locOffsetY then
						locY = locY + map.layers[layer].height
					end
					local tile = map.layers[layer].world[locX][locY]
					------------------------------------------------------------------------------
					local tileset = 1
					for i = #map.tilesets, 1, -1 do
						if tile >= map.tilesets[i].firstgid then
							tileset = i
							break
						end
					end
					array[i] = {}
					array[i].tile = tile
					if map.tilesets[tileset].tileproperties then
						local tileStr = 0
						if tileset == 1 then
							tileStr = tostring(tile - 1)
						else
							tileStr = tostring(tile - map.tilesets[tileset].firstgid)
						end
						array[i].properties = map.tilesets[tileset].tileproperties[tileStr]
					else
						array[i].properties = nil
					end
					if map.layers[i].properties then
						array[i].level = map.layers[i].properties.level
						array[i].scaleX = map.layers[i].properties.scaleX
						array[i].scaleY = map.layers[i].properties.scaleY
					end
				end
				return array
			end
		end
	end

	M.getLayerProperties = function(layer)
		if not layer then
			layer = refLayer
		end
		local lyr = layer
		if lyr > #map.layers then
			print("Warning(getLayerProperties): The layer index is too high; Defaulting to top layer.")
			lyr = #map.layers
		elseif lyr < 1 then
			print("Warning(getLayerProperties): The layer index is too low; Defaulting to layer 1")
			lyr = 1
		end
		if map.layers[lyr].properties then
			return map.layers[lyr].properties
		else
			--print("getLayerProperties(): This layer has no properties.")
			return nil
		end
	end

	M.getMapProperties = function()
		if map.properties then
			return map.properties
		else
			--print("getMapProperties(): This map has no properties.")
			return nil
		end
	end
	
	M.getObject = function(options)
		local properties = {}
		local tWorldScaleX = map.tilewidth
		local tWorldScaleY = map.tileheight
		if map.orientation == 1 then
			tWorldScaleX = map.tilewidth
			tWorldScaleY = map.tilewidth
		end
		if options.layer then
			local properties = {}
			local layer = options.layer
			if not map.layers[layer].properties.objectLayer then
				print("ERROR(getObject): This layer is not an objectLayer.")
			end
			if options.locX and map.layers[layer].properties.objectLayer then
				for i = 1, #map.layers[layer].objects, 1 do
					local object = map.layers[layer].objects[i]
					if options.locX >= ceil((object.x + 1) / tWorldScaleX) and options.locX <= ceil((object.x + object.width) / tWorldScaleX)
					and options.locY >= ceil((object.y + 1) / tWorldScaleY) and options.locY <= ceil((object.y + object.height) / tWorldScaleY) then
						object.layer = layer
						properties[#properties + 1] = object
					end
				end
				if properties[1] then
					return properties
				end
			elseif options.levelPosX and map.layers[layer].properties.objectLayer then
				for i = 1, #map.layers[layer].objects, 1 do
					local object = map.layers[layer].objects[i]
					if object.x == options.levelPosX and object.y == options.levelPosY then
						object.layer = layer
						properties[#properties + 1] = object
					end
				end
				if properties[1] then
					return properties
				end
			elseif options.name and map.layers[layer].properties.objectLayer then
				for i = 1, #map.layers[layer].objects, 1 do
					local object = map.layers[layer].objects[i]
					if object.name == options.name then
						object.layer = layer
						properties[#properties + 1] = object
					end
				end
				if properties[1] then
					return properties
				end
			elseif options.type and map.layers[layer].properties.objectLayer then
				for i = 1, #map.layers[layer].objects, 1 do
					local object = map.layers[layer].objects[i]
					if object.type == options.type then
						object.layer = layer
						properties[#properties + 1] = object
					end
				end
				if properties[1] then
					return properties
				end
			elseif map.layers[layer].properties.objectLayer then
				for i = 1, #map.layers[layer].objects, 1 do
					local object = map.layers[layer].objects[i]
					object.layer = layer
					properties[#properties + 1] = object
				end
				if properties[1] then
					return properties
				end
			end
			if not properties[1] then
				--print("getObject(): These objects have no properties.")
			end
		elseif options.level then
			local properties = {}
			for j = 1, #map.layers, 1 do
				if map.layers[j].properties.level == options.level then
					local layer = j
					if options.locX and map.layers[layer].properties.objectLayer then
						for i = 1, #map.layers[layer].objects, 1 do
							local object = map.layers[layer].objects[i]
							if options.locX >= ceil((object.x + 1) / tWorldScaleX) and options.locX <= ceil((object.x + object.width) / tWorldScaleX)
							and options.locY >= ceil((object.y + 1) / tWorldScaleY) and options.locY <= ceil((object.y + object.height) / tWorldScaleY) then
								object.layer = layer
								properties[#properties + 1] = object
							end
						end
					elseif options.levelPosX and map.layers[layer].properties.objectLayer then
						for i = 1, #map.layers[layer].objects, 1 do
							local object = map.layers[layer].objects[i]
							if object.x == options.levelPosX and object.y == options.levelPosY then
								object.layer = layer
								properties[#properties + 1] = object
							end
						end
					elseif options.name and map.layers[layer].properties.objectLayer then
						for i = 1, #map.layers[layer].objects, 1 do
							local object = map.layers[layer].objects[i]
							if object.name == options.name then
								object.layer = layer
								properties[#properties + 1] = object
							end
						end
					elseif options.type and map.layers[layer].properties.objectLayer then
						for i = 1, #map.layers[layer].objects, 1 do
							local object = map.layers[layer].objects[i]
							if object.type == options.type then
								object.layer = layer
								properties[#properties + 1] = object
							end
						end
					elseif map.layers[layer].properties.objectLayer then
						for i = 1, #map.layers[layer].objects, 1 do
							local object = map.layers[layer].objects[i]
							object.layer = layer
							properties[#properties + 1] = object
						end
					end
				end
			end
			if properties[1] then
				return properties
			else
				--print("getObject(): These objects have no properties.")
			end
		else
			local properties = {}
			for j = 1, #map.layers, 1 do
				local layer = j
				if options.locX and map.layers[layer].properties.objectLayer then
					for i = 1, #map.layers[layer].objects, 1 do
						local object = map.layers[layer].objects[i]
						if options.locX >= ceil((object.x + 1) / tWorldScaleX) and options.locX <= ceil((object.x + object.width) / tWorldScaleX)
						and options.locY >= ceil((object.y + 1) / tWorldScaleY) and options.locY <= ceil((object.y + object.height) / tWorldScaleY) then
							object.layer = layer
							properties[#properties + 1] = object
						end
					end
				elseif options.levelPosX and map.layers[layer].properties.objectLayer then
					for i = 1, #map.layers[layer].objects, 1 do
						local object = map.layers[layer].objects[i]
						if object.x == options.levelPosX and object.y == options.levelPosY then
							object.layer = layer
							properties[#properties + 1] = object
						end
					end
				elseif options.name and map.layers[layer].properties.objectLayer then
					for i = 1, #map.layers[layer].objects, 1 do
						local object = map.layers[layer].objects[i]
						if object.name == options.name then
							object.layer = layer
							properties[#properties + 1] = object
						end
					end
				elseif options.type and map.layers[layer].properties.objectLayer then
					for i = 1, #map.layers[layer].objects, 1 do
						local object = map.layers[layer].objects[i]
						if object.type == options.type then
							object.layer = layer
							properties[#properties + 1] = object
						end
					end
				elseif map.layers[layer].properties.objectLayer then
					for i = 1, #map.layers[layer].objects, 1 do
						local object = map.layers[layer].objects[i]
						object.layer = layer
						properties[#properties + 1] = object
					end
				end
			end
			if properties[1] then
				return properties
			else
				--print("getObject(): These objects have no properties.")
			end
		end
	end
	
	M.setTileProperties = function(tile, table)
		if tile ~= 0 then
			local tileset = 1
			for i = 1, #map.tilesets, 1 do
				if tile >= map.tilesets[i].firstgid then
					tileset = i
					break
				end
			end
			local tileStr = tostring(tile - 1)
			if not map.tilesets[tileset].tileproperties then
				map.tilesets[tileset].tileproperties = {}
			end
			map.tilesets[tileset].tileproperties[tileStr] = table
		end
	end
	
	M.setLayerProperties = function(layer, table)
		if not layer then
			print("ERROR(setLayerProperties): No layer specified.")
		end
		local lyr = layer
		if lyr > #map.layers then
			print("Warning(setLayerProperties): The layer index is too high. Defaulting to top layer.")
			lyr = #map.layers
		elseif lyr < 1 then
			print("Warning(setLayerProperties): The layer index is too low. Defaulting to layer 1.")
			lyr = 1
		end
		local i = lyr
		map.layers[lyr].properties = table
		if not map.layers[i].properties then
			map.layers[i].properties = {}
			map.layers[i].properties.level = "1"
			map.layers[i].properties.scaleX = 1
			map.layers[i].properties.scaleY = 1
			map.layers[i].properties.parallaxX = 1
			map.layers[i].properties.parallaxY = 1
		else
			if not map.layers[i].properties.level then
				map.layers[i].properties.level = "1"
			end
			if map.layers[i].properties.scale then
				map.layers[i].properties.scaleX = map.layers[i].properties.scale
				map.layers[i].properties.scaleY = map.layers[i].properties.scale
			else
				if not map.layers[i].properties.scaleX then
					map.layers[i].properties.scaleX = 1
				end
				if not map.layers[i].properties.scaleY then
					map.layers[i].properties.scaleY = 1
				end
			end
		end
		map.layers[i].properties.scaleX = tonumber(map.layers[i].properties.scaleX)
		map.layers[i].properties.scaleY = tonumber(map.layers[i].properties.scaleY)
		if map.layers[lyr].properties.parallax then
			map.layers[lyr].parallaxX = map.layers[lyr].properties.parallax / map.layers[lyr].properties.scaleX
			map.layers[lyr].parallaxY = map.layers[lyr].properties.parallax / map.layers[lyr].properties.scaleY
		else
			if map.layers[lyr].properties.parallaxX then
				map.layers[lyr].parallaxX = map.layers[lyr].properties.parallaxX / map.layers[lyr].properties.scaleX
			else
				map.layers[lyr].parallaxX = 1
			end
			if map.layers[lyr].properties.parallaxY then
				map.layers[lyr].parallaxY = map.layers[lyr].properties.parallaxY / map.layers[lyr].properties.scaleY
			else
				map.layers[lyr].parallaxY = 1
			end
		end
		--CHECK REFERENCE LAYER
		if refLayer == lyr then
			if map.layers[lyr].parallaxX ~= 1 or map.layers[lyr].parallaxY ~= 1 then
				for i = 1, #map.layers, 1 do
					if map.layers[i].parallaxX == 1 and map.layers[i].parallaxY == 1 then
						refLayer = i
						break
					end
				end
				if not refLayer then
					refLayer = 1
				end
			end
		end
		
		--DETECT LAYER WRAP
		layerWrapX[lyr] = worldWrapX
		layerWrapY[lyr] = worldWrapY
		if map.layers[lyr].properties.wrap then
			if map.layers[lyr].properties.wrap == "true" then
				layerWrapX[lyr] = true
				layerWrapY[lyr] = true
			elseif map.layers[lyr].properties.wrap == "false" then
				layerWrapX[lyr] = false
				layerWrapY[lyr] = false
			end
		end
		if map.layers[lyr].properties.wrapX then
			if map.layers[lyr].properties.wrapX == "true" then
				layerWrapX[lyr] = true
			elseif map.layers[lyr].properties.wrapX == "false" then
				layerWrapX[lyr] = false
			end
		end
		if map.layers[lyr].properties.wrapY then
			if map.layers[lyr].properties.wrapY == "true" then
				layerWrapY[lyr] = true
			elseif map.layers[lyr].properties.wrapY == "false" then
				layerWrapX[lyr] = false
			end
		end
	
		--LOAD PHYSICS
		if enablePhysicsByLayer == 1 then
			if map.layers[i].properties.physics == "true" then
				enablePhysics[i] = true
				physicsData.layer[i] = {}
				physicsData.layer[i].defaultDensity = physicsData.defaultDensity
				physicsData.layer[i].defaultFriction = physicsData.defaultFriction
				physicsData.layer[i].defaultBounce = physicsData.defaultBounce
				physicsData.layer[i].defaultBodyType = physicsData.defaultBodyType
				physicsData.layer[i].defaultShape = physicsData.defaultShape
				physicsData.layer[i].defaultRadius = physicsData.defaultRadius
				physicsData.layer[i].defaultFilter = physicsData.defaultFilter
				physicsData.layer[i].isActive = true
				physicsData.layer[i].isAwake = true
		
				if map.layers[i].properties.density then
					physicsData.layer[i].defaultDensity = map.layers[i].properties.density
				end
				if map.layers[i].properties.friction then
					physicsData.layer[i].defaultFriction = map.layers[i].properties.friction
				end
				if map.layers[i].properties.bounce then
					physicsData.layer[i].defaultBounce = map.layers[i].properties.bounce
				end
				if map.layers[i].properties.bodyType then
					physicsData.layer[i].defaultBodyType = map.layers[i].properties.bodyType
				end
				if map.layers[i].properties.shape then
					if type(map.layers[i].properties.shape) == "string" then
						physicsData.layer[i].defaultShape = json.decode(map.layers[i].properties.shape)
					else
						physicsData.layer[i].defaultShape = map.layers[i].properties.shape
					end
				end
				if map.layers[i].properties.radius then
					physicsData.layer[i].defaultRadius = map.layers[i].properties.radius
				end
				if map.layers[i].properties.groupIndex or map.layers[i].properties.categoryBits or map.layers[i].properties.maskBits then
					physicsData.layer[i].defaultFilter = {categoryBits = tonumber(map.layers[i].properties.categoryBits),
														maskBits = tonumber(map.layers[i].properties.maskBits),
														groupIndex = tonumber(map.layers[i].properties.groupIndex)
					}
				end
			end
		elseif enablePhysicsByLayer == 2 then
			enablePhysics[i] = true
			physicsData.layer[i] = {}
			physicsData.layer[i].defaultDensity = physicsData.defaultDensity
			physicsData.layer[i].defaultFriction = physicsData.defaultFriction
			physicsData.layer[i].defaultBounce = physicsData.defaultBounce
			physicsData.layer[i].defaultBodyType = physicsData.defaultBodyType
			physicsData.layer[i].defaultShape = physicsData.defaultShape
			physicsData.layer[i].defaultRadius = physicsData.defaultRadius
			physicsData.layer[i].defaultFilter = physicsData.defaultFilter
			physicsData.layer[i].isActive = true
			physicsData.layer[i].isAwake = true
		
			if map.layers[i].properties.density then
				physicsData.layer[i].defaultDensity = map.layers[i].properties.density
			end
			if map.layers[i].properties.friction then
				physicsData.layer[i].defaultFriction = map.layers[i].properties.friction
			end
			if map.layers[i].properties.bounce then
				physicsData.layer[i].defaultBounce = map.layers[i].properties.bounce
			end
			if map.layers[i].properties.bodyType then
				physicsData.layer[i].defaultBodyType = map.layers[i].properties.bodyType
			end
			if map.layers[i].properties.shape then
				if type(map.layers[i].properties.shape) == "string" then
					physicsData.layer[i].defaultShape = json.decode(map.layers[i].properties.shape)
				else
					physicsData.layer[i].defaultShape = map.layers[i].properties.shape
				end
			end
			if map.layers[i].properties.radius then
				physicsData.layer[i].defaultRadius = map.layers[i].properties.radius
			end
			if map.layers[i].properties.groupIndex or map.layers[i].properties.categoryBits or map.layers[i].properties.maskBits then
				physicsData.layer[i].defaultFilter = {categoryBits = tonumber(map.layers[i].properties.categoryBits),
													maskBits = tonumber(map.layers[i].properties.maskBits),
													groupIndex = tonumber(map.layers[i].properties.groupIndex)
				}
			end			
		end
		
		--LIGHTING
		if map.properties then
			if map.properties.lightingStyle then
				local levelLighting = {}
				for i = 1, map.numLevels, 1 do
					levelLighting[i] = {}
				end
				if not map.properties.lightRedStart then
					map.properties.lightRedStart = "1"
				end
				if not map.properties.lightGreenStart then
					map.properties.lightGreenStart = "1"
				end
				if not map.properties.lightBlueStart then
					map.properties.lightBlueStart = "1"
				end
				if map.properties.lightingStyle == "diminish" then
					local rate = tonumber(map.properties.lightRate)
					levelLighting[map.numLevels].red = tonumber(map.properties.lightRedStart)
					levelLighting[map.numLevels].green = tonumber(map.properties.lightGreenStart)
					levelLighting[map.numLevels].blue = tonumber(map.properties.lightBlueStart)
					for i = map.numLevels - 1, 1, -1 do
						levelLighting[i].red = levelLighting[map.numLevels].red - (rate * (map.numLevels - i))
						if levelLighting[i].red < 0 then
							levelLighting[i].red = 0
						end
						levelLighting[i].green = levelLighting[map.numLevels].green - (rate * (map.numLevels - i))
						if levelLighting[i].green < 0 then
							levelLighting[i].green = 0
						end
						levelLighting[i].blue = levelLighting[map.numLevels].blue - (rate * (map.numLevels - i))
						if levelLighting[i].blue < 0 then
							levelLighting[i].blue = 0
						end
					end
				end
				for i = 1, #map.layers, 1 do
					if map.layers[i].properties.lightRed then
						map.layers[i].redLight = tonumber(map.layers[i].properties.lightRed)
					else
						map.layers[i].redLight = levelLighting[map.layers[i].properties.level].red
					end
					if map.layers[i].properties.lightGreen then
						map.layers[i].greenLight = tonumber(map.layers[i].properties.lightGreen)
					else
						map.layers[i].greenLight = levelLighting[map.layers[i].properties.level].green
					end
					if map.layers[i].properties.lightBlue then
						map.layers[i].blueLight = tonumber(map.layers[i].properties.lightBlue)
					else
						map.layers[i].blueLight = levelLighting[map.layers[i].properties.level].blue
					end
				end
			else
				for i = 1, #map.layers, 1 do
					map.layers[i].redLight = 1
					map.layers[i].greenLight = 1
					map.layers[i].blueLight = 1
				end
			end
		end
	end

	M.setMapProperties = function(table)
		map.properties = table
		--LIGHTING
		if map.properties then
			if map.properties.lightingStyle then
				local levelLighting = {}
				for i = 1, map.numLevels, 1 do
					levelLighting[i] = {}
				end
				if not map.properties.lightRedStart then
					map.properties.lightRedStart = "1"
				end
				if not map.properties.lightGreenStart then
					map.properties.lightGreenStart = "1"
				end
				if not map.properties.lightBlueStart then
					map.properties.lightBlueStart = "1"
				end
				if map.properties.lightingStyle == "diminish" then
					local rate = tonumber(map.properties.lightRate)
					levelLighting[map.numLevels].red = tonumber(map.properties.lightRedStart)
					levelLighting[map.numLevels].green = tonumber(map.properties.lightGreenStart)
					levelLighting[map.numLevels].blue = tonumber(map.properties.lightBlueStart)
					for i = map.numLevels - 1, 1, -1 do
						levelLighting[i].red = levelLighting[map.numLevels].red - (rate * (map.numLevels - i))
						if levelLighting[i].red < 0 then
							levelLighting[i].red = 0
						end
						levelLighting[i].green = levelLighting[map.numLevels].green - (rate * (map.numLevels - i))
						if levelLighting[i].green < 0 then
							levelLighting[i].green = 0
						end
						levelLighting[i].blue = levelLighting[map.numLevels].blue - (rate * (map.numLevels - i))
						if levelLighting[i].blue < 0 then
							levelLighting[i].blue = 0
						end
					end
				end
				for i = 1, #map.layers, 1 do
					if map.layers[i].properties.lightRed then
						map.layers[i].redLight = tonumber(map.layers[i].properties.lightRed)
					else
						map.layers[i].redLight = levelLighting[map.layers[i].properties.level].red
					end
					if map.layers[i].properties.lightGreen then
						map.layers[i].greenLight = tonumber(map.layers[i].properties.lightGreen)
					else
						map.layers[i].greenLight = levelLighting[map.layers[i].properties.level].green
					end
					if map.layers[i].properties.lightBlue then
						map.layers[i].blueLight = tonumber(map.layers[i].properties.lightBlue)
					else
						map.layers[i].blueLight = levelLighting[map.layers[i].properties.level].blue
					end
				end
			else
				for i = 1, #map.layers, 1 do
					map.layers[i].redLight = 1
					map.layers[i].greenLight = 1
					map.layers[i].blueLight = 1
				end
			end
		end
	end

	M.setObjectProperties = function(name, table, layer)
		if not layer then
			local debug = 0
			for j = 1, #map.layers, 1 do
				local layer = j
				if map.layers[layer].properties.objectLayer then
					for i = 1, #map.layers[layer].objects, 1 do
						local object = map.layers[layer].objects[i]
						if object.name == name then
							map.layers[layer].objects[i] = table
							debug = 1
							break
						end
					end
				end
				if debug == 1 then
					break
				end
			end
			if debug == 0 then
				print("Warning(setObjectProperties): Object Not Found.")
			end
		else
			local debug = 0
			if map.layers[layer].properties.objectLayer then
				for i = 1, #map.layers[layer].objects, 1 do
					local object = map.layers[layer].objects[i]
					if object.name == name then
						map.layers[layer].objects[i] = table
						debug = 1
					end
				end
			else
				print("ERROR(setObjectProperties): The layer is not an Object Layer.")
			end
			if debug == 0 then
				print("Warning(setObjectProperties): Object Not Found.")
			end
		end
	end
	
	M.getVisibleLayer = function(locX, locY)
		local layer = #map.layers
		for i = #map.layers, 1, -1 do
			if map.layers[i].world[locX][locY] ~= 0 
			and masterGroup[i].vars.isVisible == true
			and masterGroup[i].vars.alpha > 0
			and not map.layers[i].properties.objectLayer then
				layer = i
				break
			end
		end
		return layer
	end

	M.getVisibleLevel = function(locX, locY)
		local layer = #map.layers
		for i = #map.layers, 1, -1 do
			if map.layers[i].world[locX][locY] ~= 0 
			and masterGroup[i].vars.isVisible == true
			and masterGroup[i].vars.alpha > 0 
			and not map.layers[i].properties.objectLayer then
				layer = i
				break
			end
		end
		return map.layers[layer].properties.level
	end
	
	M.getSpriteLayer = function(level)
		for i = 1, #map.layers, 1 do
			if map.layers[i].properties.level == level and map.layers[i].properties.spriteLayer then
				return i
			end
		end
		return nil
	end
	
	M.getObjectLayer = function(level)
		for i = 1, #map.layers, 1 do
			if map.layers[i].properties.level == level and map.layers[i].properties.objectLayer then
				return i
			end
		end
	end
	
	M.getLayers = function(parameters)
		if parameters then
			if parameters.layer then
				return map.layers[parameters.layer]
			elseif parameters.level then
				local array = {}
				for i = 1, #map.layers, 1 do
					if map.layers[i].properties.level == parameters.level then
						array[#array + 1] = map.layers[i]
					end
				end
				return array
			end
		else
			local array = {}
			for i = 1, #map.layers, 1 do
				array[#array + 1] = map.layers[i]
			end
			return array
		end
	end
	
	M.getMapObj = function()
		return masterGroup
	end
	
	M.getLayerObj = function(parameters)
		if parameters then
			if parameters.layer then
				return masterGroup[parameters.layer]
			elseif parameters.level then
				local array = {}
				for i = 1, #map.layers, 1 do
					if map.layers[i].properties.level == parameters.level then
						array[#array + 1] = masterGroup[i]
					end
				end
				return array
			end
		else
			local array = {}
			for i = 1, #map.layers, 1 do
				array[#array + 1] = masterGroup[i]
			end
			return array
		end
	end
	
	local getTileObj = function(locX, locY, layer)
		if not layer then
			layer = refLayer
		end
		if tileObjects[layer][locX] and tileObjects[layer][locX][locY] and not tileObjects[layer][locX][locY].noDraw then
			return tileObjects[layer][locX][locY]
		end
	end
	M.getTileObj = getTileObj
	
	M.getMap = function()
		return map
	end
	
	M.processLightRay = function(layer, light, ray)
		local style = 3
		local blockScaleXt = map.tilewidth
		local blockScaleYt = map.tileheight
		local range = light.maxRange
	
		local levelPosX, levelPosY
		if not light.levelPosX then
			levelPosX = (light.locX * blockScaleXt - blockScaleXt * 0.5)
			levelPosY = (light.locY * blockScaleYt - blockScaleYt * 0.5)
		else
			levelPosX = light.levelPosX
			levelPosY = light.levelPosY
		end
	
		light.levelPosX = levelPosX
		light.levelPosY = levelPosY
		light.layer = layer
		local cLocX = math.round((levelPosX + (blockScaleXt * 0.5)) / blockScaleXt)
		local cLocY = math.round((levelPosY + (blockScaleYt * 0.5)) / blockScaleYt)
		local tileX = (cLocX - 1) * blockScaleXt
		local tileY = (cLocY - 1) * blockScaleYt
		local startX = levelPosX - tileX
		local startY = levelPosY - tileY
	
		local mL = map.layers[layer].lighting
		local mW = map.layers[layer].world
		local mT = map.lightToggle
		local dynamic = light.dynamic
		local area = light.area
		local areaIndex = light.areaIndex
		local worldSizeXt = map.width
		local worldSizeYt = map.height
		local worldWrapX = worldWrapX
		local worldWrapY = worldWrapY
		local id = light.id
		local falloff1 = light.falloff[1]
		local falloff2 = light.falloff[2]
		local falloff3 = light.falloff[3]
	
		if not mL[cLocX][cLocY] then
			mL[cLocX][cLocY] = {}
		end
	
		if not light.locations then
			light.locations = {}
		end
	
		local count = 0
		local time = tonumber(system.getTimer())
		light.lightToggle = time
		local toRadian = 0.01745329251994

		mL[cLocX][cLocY][id] = {}
		mL[cLocX][cLocY][id].light = {light.source[1], light.source[2], light.source[3]}
		mT[cLocX][cLocY] = time
		area[areaIndex] = {cLocX, cLocY}
		areaIndex = areaIndex + 1
	
		local i = ray
		if i == 0 then
			i = 0.00001
		end
		local breakX = false
		local breakY = false
		local angleR = i * toRadian --math.rad(i)
		local x = (5 * math.cos(angleR))
		local y = (5 * math.sin(angleR))
	
		local red = light.source[1]
		local green = light.source[2]
		local blue = light.source[3]

		if x > 0 and y < 0 then
			--top right quadrant

			local Xangle = (i - 270) * toRadian --math.rad(i - 270)
			local XcheckY = tileY
			local XcheckX = math.tan(Xangle) * startY + levelPosX
			local XdeltaY = blockScaleYt
			local XdeltaX = math.tan(Xangle) * blockScaleYt
			local XlocX, XlocY = ceil(XcheckX / blockScaleXt), ceil(XcheckY / blockScaleYt)
			local Xdistance = startY / math.cos(Xangle) / blockScaleXt
			local XdeltaV = blockScaleYt / math.cos(Xangle) / blockScaleYt
		
			local Yangle = (360 - i) * toRadian --math.rad(360 - i)
			local YcheckY = levelPosY - (math.tan(Yangle) * (tileX + blockScaleXt - levelPosX))
			local YcheckX = tileX + blockScaleXt + 1
			local YdeltaY = math.tan(Yangle) * blockScaleXt
			local YdeltaX = blockScaleXt
			local YlocX, YlocY = ceil(YcheckX / blockScaleXt), ceil(YcheckY / blockScaleYt)
			local Ydistance = (YcheckX - levelPosX) / math.cos(Yangle) / blockScaleYt
			local YdeltaV = blockScaleXt / math.cos(Yangle) / blockScaleXt
		
			for j = 1, range * 2, 1 do
				count = count + 1
			
				if worldWrapX then
					if XlocX > worldSizeXt - map.locOffsetX then
						XlocX = XlocX - worldSizeXt
					end
					if XlocX < 1 - map.locOffsetX then
						XlocX = XlocX + worldSizeXt
					end
					if YlocX > worldSizeXt - map.locOffsetX then
						YlocX = YlocX - worldSizeXt
					end
					if YlocX < 1 - map.locOffsetX then
						YlocX = YlocX + worldSizeXt
					end
				end
				if worldWrapY then
					if XlocY > worldSizeYt - map.locOffsetY then
						XlocY = XlocY - worldSizeYt
					end
					if XlocY < 1 - map.locOffsetY then
						XlocY = XlocY + worldSizeYt
					end
					if YlocY > worldSizeYt - map.locOffsetY then
						YlocY = YlocY - worldSizeYt
					end
					if YlocY < 1 - map.locOffsetY then
						YlocY = YlocY + worldSizeYt
					end
				end
			
				if XlocX < 1 - map.locOffsetX or XlocX > worldSizeXt - map.locOffsetX or XlocY < 1 - map.locOffsetY or XlocY > worldSizeYt - map.locOffsetY then
					breakX = true
				end
				if YlocX < 1 - map.locOffsetX or YlocX > worldSizeXt - map.locOffsetX or YlocY < 1 - map.locOffsetY or YlocY > worldSizeYt - map.locOffsetY then
					breakY = true
				end
				if breakX and breakY then
					break
				end
			
				local red1,green1,blue1
			
				if Xdistance < Ydistance then
					if Xdistance <= range then
						mT[XlocX][XlocY] = time
						area[areaIndex] = {XlocX, XlocY}
						areaIndex = areaIndex + 1
						red1 = red - (falloff1 * Xdistance)
						green1 = green - (falloff2 * Xdistance)
						blue1 = blue - (falloff3 * Xdistance)
						if not mL[XlocX][XlocY] then
							mL[XlocX][XlocY] = {}						
						elseif mL[XlocX][XlocY][id] then							
							if style == 1 then
								local tempLight = mL[XlocX][XlocY][id]
								red1 = (red1 + tempLight.light[1]) / 2
								green1 = (green1 + tempLight.light[2]) / 2
								blue1 = (blue1 + tempLight.light[3]) / 2
							elseif style == 2 then
								local tempLight = mL[XlocX][XlocY][id]
								if red1 > tempLight.light[1] then
									red1 = tempLight.light[1]
								end
								if green1 > tempLight.light[2] then
									green1 = tempLight.light[2]
								end
								if blue1 > tempLight.light[3] then
									blue1 = tempLight.light[3]
								end
							else
								local tempLight = mL[XlocX][XlocY][id]
								if red1 < tempLight.light[1] then
									red1 = tempLight.light[1]
								end
								if green1 < tempLight.light[2] then
									green1 = tempLight.light[2]
								end
								if blue1 < tempLight.light[3] then
									blue1 = tempLight.light[3]
								end
							end
						end
						mL[XlocX][XlocY][id] = {}
						mL[XlocX][XlocY][id].light = {red1, green1, blue1}
					
						if map.lightingData[mW[XlocX][XlocY]] then
							local temp = map.lightingData[mW[XlocX][XlocY]]
							red = red - temp.opacity[1]
							green = green - temp.opacity[2]
							blue = blue - temp.opacity[3]
						end
					
						XcheckX = XcheckX + XdeltaX
						XcheckY = XcheckY - XdeltaY
						XlocX, XlocY = ceil(XcheckX / blockScaleXt), XlocY - 1
						Xdistance = Xdistance + XdeltaV
					end
				else
					if Ydistance <= range then
						mT[YlocX][YlocY] = time
						area[areaIndex] = {YlocX, YlocY}
						areaIndex = areaIndex + 1
						red1 = red - (falloff1 * Ydistance)
						green1 = green - (falloff2 * Ydistance)
						blue1 = blue - (falloff3 * Ydistance)
						if not mL[YlocX][YlocY] then
							mL[YlocX][YlocY] = {}						
						elseif mL[YlocX][YlocY][id] then
							if style == 1 then
								local tempLight = mL[YlocX][YlocY][id]
								red1 = (red1 + tempLight.light[1]) / 2
								green1 = (green1 + tempLight.light[2]) / 2
								blue1 = (blue1 + tempLight.light[3]) / 2
							elseif style == 2 then
								local tempLight = mL[YlocX][YlocY][id]
								if red1 > tempLight.light[1] then
									red1 = tempLight.light[1]
								end
								if green1 > tempLight.light[2] then
									green1 = tempLight.light[2]
								end
								if blue1 > tempLight.light[3] then
									blue1 = tempLight.light[3]
								end
							else
								local tempLight = mL[YlocX][YlocY][id]
								if red1 < tempLight.light[1] then
									red1 = tempLight.light[1]
								end
								if green1 < tempLight.light[2] then
									green1 = tempLight.light[2]
								end
								if blue1 < tempLight.light[3] then
									blue1 = tempLight.light[3]
								end
							end
						end
						mL[YlocX][YlocY][id] = {}
						mL[YlocX][YlocY][id].light = {red1, green1, blue1}
					
						if map.lightingData[mW[YlocX][YlocY]] then
							local temp = map.lightingData[mW[YlocX][YlocY]]
							red = red - temp.opacity[1]
							green = green - temp.opacity[2]
							blue = blue - temp.opacity[3]
						end	

						YcheckX = YcheckX + YdeltaX
						YcheckY = YcheckY - YdeltaY
						YlocX, YlocY = YlocX + 1, ceil(YcheckY / blockScaleYt)
						Ydistance = Ydistance + YdeltaV
					end
				end
			
			
				if red1 <= 0 and green1 <= 0 and blue1 <= 0 then
					break
				end
			
				if Xdistance > range and Ydistance > range then
					break
				end
			end

		elseif x > 0 and y > 0 then
			--bottom right quadrant

			local Xangle = (90 - i) * toRadian --math.rad(90 - i)
			local XcheckY = tileY + blockScaleYt + 1
			local XcheckX = math.tan(Xangle) * (XcheckY - levelPosY) + levelPosX
			local XdeltaY = blockScaleYt
			local XdeltaX = math.tan(Xangle) * blockScaleYt
			local XlocX, XlocY = ceil(XcheckX / blockScaleXt), ceil(XcheckY / blockScaleYt)
			local Xdistance = (XcheckY - levelPosY) / math.cos(Xangle) / blockScaleXt
			local XdeltaV = blockScaleYt / math.cos(Xangle) / blockScaleYt
		
			local Yangle = i * toRadian --math.rad(i)
			local YcheckY = math.tan(Yangle) * (tileX + blockScaleXt - levelPosX) + levelPosY
			local YcheckX = tileX + blockScaleXt + 1
			local YdeltaY = math.tan(Yangle) * blockScaleXt
			local YdeltaX = blockScaleXt
			local YlocX, YlocY = ceil(YcheckX / blockScaleXt), ceil(YcheckY / blockScaleYt)
			local Ydistance = (YcheckX - levelPosX) / math.cos(Yangle) / blockScaleYt
			local YdeltaV = blockScaleXt / math.cos(Yangle) / blockScaleXt
		
			for j = 1, range * 2, 1 do
				count = count + 1
			
				if worldWrapX then
					if XlocX > worldSizeXt - map.locOffsetX then
						XlocX = XlocX - worldSizeXt
					end
					if XlocX < 1 - map.locOffsetX then
						XlocX = XlocX + worldSizeXt
					end
					if YlocX > worldSizeXt - map.locOffsetX then
						YlocX = YlocX - worldSizeXt
					end
					if YlocX < 1 - map.locOffsetX then
						YlocX = YlocX + worldSizeXt
					end
				end
				if worldWrapY then
					if XlocY > worldSizeYt - map.locOffsetY then
						XlocY = XlocY - worldSizeYt
					end
					if XlocY < 1 - map.locOffsetY then
						XlocY = XlocY + worldSizeYt
					end
					if YlocY > worldSizeYt - map.locOffsetY then
						YlocY = YlocY - worldSizeYt
					end
					if YlocY < 1 - map.locOffsetY then
						YlocY = YlocY + worldSizeYt
					end
				end
			
				if XlocX < 1 - map.locOffsetX or XlocX > worldSizeXt - map.locOffsetX or XlocY < 1 - map.locOffsetY or XlocY > worldSizeYt - map.locOffsetY then
					breakX = true
				end
				if YlocX < 1 - map.locOffsetX or YlocX > worldSizeXt - map.locOffsetX or YlocY < 1 - map.locOffsetY or YlocY > worldSizeYt - map.locOffsetY then
					breakY = true
				end
				if breakX and breakY then
					break
				end
			
				local red1,green1,blue1
			
				if Xdistance < Ydistance then
					if Xdistance <= range then
						mT[XlocX][XlocY] = time
						area[areaIndex] = {XlocX, XlocY}
						areaIndex = areaIndex + 1
						red1 = red - (falloff1 * Xdistance)
						green1 = green - (falloff2 * Xdistance)
						blue1 = blue - (falloff3 * Xdistance)
						if not mL[XlocX][XlocY] then
							mL[XlocX][XlocY] = {}						
						elseif mL[XlocX][XlocY][id] then
							if style == 1 then
								local tempLight = mL[XlocX][XlocY][id]
								red1 = (red1 + tempLight.light[1]) / 2
								green1 = (green1 + tempLight.light[2]) / 2
								blue1 = (blue1 + tempLight.light[3]) / 2
							elseif style == 2 then
								local tempLight = mL[XlocX][XlocY][id]
								if red1 > tempLight.light[1] then
									red1 = tempLight.light[1]
								end
								if green1 > tempLight.light[2] then
									green1 = tempLight.light[2]
								end
								if blue1 > tempLight.light[3] then
									blue1 = tempLight.light[3]
								end
							else
								local tempLight = mL[XlocX][XlocY][id]
								if red1 < tempLight.light[1] then
									red1 = tempLight.light[1]
								end
								if green1 < tempLight.light[2] then
									green1 = tempLight.light[2]
								end
								if blue1 < tempLight.light[3] then
									blue1 = tempLight.light[3]
								end
							end
						end
						mL[XlocX][XlocY][id] = {}
						mL[XlocX][XlocY][id].light = {red1, green1, blue1}
					
						if map.lightingData[mW[XlocX][XlocY]] then
							local temp = map.lightingData[mW[XlocX][XlocY]]
							red = red - temp.opacity[1]
							green = green - temp.opacity[2]
							blue = blue - temp.opacity[3]
						end
					
						XcheckX = XcheckX + XdeltaX
						XcheckY = XcheckY + XdeltaY
						XlocX, XlocY = ceil(XcheckX / blockScaleXt), XlocY + 1
						Xdistance = Xdistance + XdeltaV
					end
				else
					if Ydistance <= range then
						mT[YlocX][YlocY] = time
						area[areaIndex] = {YlocX, YlocY}
						areaIndex = areaIndex + 1
						red1 = red - (falloff1 * Ydistance)
						green1 = green - (falloff2 * Ydistance)
						blue1 = blue - (falloff3 * Ydistance)
						if not mL[YlocX][YlocY] then
							mL[YlocX][YlocY] = {}						
						elseif mL[YlocX][YlocY][id] then
							if style == 1 then
								local tempLight = mL[YlocX][YlocY][id]
								red1 = (red1 + tempLight.light[1]) / 2
								green1 = (green1 + tempLight.light[2]) / 2
								blue1 = (blue1 + tempLight.light[3]) / 2
							elseif style == 2 then
								local tempLight = mL[YlocX][YlocY][id]
								if red1 > tempLight.light[1] then
									red1 = tempLight.light[1]
								end
								if green1 > tempLight.light[2] then
									green1 = tempLight.light[2]
								end
								if blue1 > tempLight.light[3] then
									blue1 = tempLight.light[3]
								end
							else
								local tempLight = mL[YlocX][YlocY][id]
								if red1 < tempLight.light[1] then
									red1 = tempLight.light[1]
								end
								if green1 < tempLight.light[2] then
									green1 = tempLight.light[2]
								end
								if blue1 < tempLight.light[3] then
									blue1 = tempLight.light[3]
								end
							end
						end
						mL[YlocX][YlocY][id] = {}
						mL[YlocX][YlocY][id].light = {red1, green1, blue1}
					
						if map.lightingData[mW[YlocX][YlocY]] then
							local temp = map.lightingData[mW[YlocX][YlocY]]
							red = red - temp.opacity[1]
							green = green - temp.opacity[2]
							blue = blue - temp.opacity[3]
						end	

						YcheckX = YcheckX + YdeltaX
						YcheckY = YcheckY + YdeltaY
						YlocX, YlocY = YlocX + 1, ceil(YcheckY / blockScaleYt)
						Ydistance = Ydistance + YdeltaV
					end
				end
			
			
				if red1 <= 0 and green1 <= 0 and blue1 <= 0 then
					break
				end
			
				if Xdistance > range and Ydistance > range then
					break
				end
			end
		
		elseif x < 0 and y > 0 then
			--bottom left quadrant

			local Xangle = (i - 90) * toRadian --math.rad(i - 90)
			local XcheckY = tileY + blockScaleYt + 1
			local XcheckX = levelPosX - (math.tan(Xangle) * (XcheckY - levelPosY))
			local XdeltaY = blockScaleYt
			local XdeltaX = math.tan(Xangle) * blockScaleYt
			local XlocX, XlocY = ceil(XcheckX / blockScaleXt), ceil(XcheckY / blockScaleYt)
			local Xdistance = (XcheckY - levelPosY) / math.cos(Xangle) / blockScaleXt
			local XdeltaV = blockScaleYt / math.cos(Xangle) / blockScaleYt
		
			local Yangle = (180 - i) * toRadian --math.rad(180 - i)
			local YcheckY = math.tan(Yangle) * (levelPosX - tileX) + levelPosY
			local YcheckX = tileX 
			local YdeltaY = math.tan(Yangle) * blockScaleXt
			local YdeltaX = blockScaleXt
			local YlocX, YlocY = ceil(YcheckX / blockScaleXt), ceil(YcheckY / blockScaleYt)
			local Ydistance = startX / math.cos(Yangle) / blockScaleYt
			local YdeltaV = blockScaleXt / math.cos(Yangle) / blockScaleXt

			for j = 1, range * 2, 1 do
				count = count + 1
			
				if worldWrapX then
					if XlocX > worldSizeXt - map.locOffsetX then
						XlocX = XlocX - worldSizeXt
					end
					if XlocX < 1 - map.locOffsetX then
						XlocX = XlocX + worldSizeXt
					end
					if YlocX > worldSizeXt - map.locOffsetX then
						YlocX = YlocX - worldSizeXt
					end
					if YlocX < 1 - map.locOffsetX then
						YlocX = YlocX + worldSizeXt
					end
				end
				if worldWrapY then
					if XlocY > worldSizeYt - map.locOffsetY then
						XlocY = XlocY - worldSizeYt
					end
					if XlocY < 1 - map.locOffsetY then
						XlocY = XlocY + worldSizeYt
					end
					if YlocY > worldSizeYt - map.locOffsetY then
						YlocY = YlocY - worldSizeYt
					end
					if YlocY < 1 - map.locOffsetY then
						YlocY = YlocY + worldSizeYt
					end
				end
			
				if XlocX < 1 - map.locOffsetX or XlocX > worldSizeXt - map.locOffsetX or XlocY < 1 - map.locOffsetY or XlocY > worldSizeYt - map.locOffsetY then
					breakX = true
				end
				if YlocX < 1 - map.locOffsetX or YlocX > worldSizeXt - map.locOffsetX or YlocY < 1 - map.locOffsetY or YlocY > worldSizeYt - map.locOffsetY then
					breakY = true
				end
				if breakX and breakY then
					break
				end
			
				local red1, green1, blue1
			
				if Xdistance < Ydistance then
					if Xdistance <= range then
						mT[XlocX][XlocY] = time
						area[areaIndex] = {XlocX, XlocY}
						areaIndex = areaIndex + 1
						red1 = red - (falloff1 * Xdistance)
						green1 = green - (falloff2 * Xdistance)
						blue1 = blue - (falloff3 * Xdistance)
						if not mL[XlocX][XlocY] then
							mL[XlocX][XlocY] = {}						
						elseif mL[XlocX][XlocY][id] then
							if style == 1 then
								local tempLight = mL[XlocX][XlocY][id]
								red1 = (red1 + tempLight.light[1]) / 2
								green1 = (green1 + tempLight.light[2]) / 2
								blue1 = (blue1 + tempLight.light[3]) / 2
							elseif style == 2 then
								local tempLight = mL[XlocX][XlocY][id]
								if red1 > tempLight.light[1] then
									red1 = tempLight.light[1]
								end
								if green1 > tempLight.light[2] then
									green1 = tempLight.light[2]
								end
								if blue1 > tempLight.light[3] then
									blue1 = tempLight.light[3]
								end
							else
								local tempLight = mL[XlocX][XlocY][id]
								if red1 < tempLight.light[1] then
									red1 = tempLight.light[1]
								end
								if green1 < tempLight.light[2] then
									green1 = tempLight.light[2]
								end
								if blue1 < tempLight.light[3] then
									blue1 = tempLight.light[3]
								end
							end
						end
						mL[XlocX][XlocY][id] = {}
						mL[XlocX][XlocY][id].light = {red1, green1, blue1}
					
						if map.lightingData[mW[XlocX][XlocY]] then
							local temp = map.lightingData[mW[XlocX][XlocY]]
							red = red - temp.opacity[1]
							green = green - temp.opacity[2]
							blue = blue - temp.opacity[3]
						end
					
						XcheckX = XcheckX - XdeltaX
						XcheckY = XcheckY + XdeltaY
						XlocX, XlocY = ceil(XcheckX / blockScaleXt), XlocY + 1
						Xdistance = Xdistance + XdeltaV
					end
				else
					if Ydistance <= range then
						mT[YlocX][YlocY] = time
						area[areaIndex] = {YlocX, YlocY}
						areaIndex = areaIndex + 1
						red1 = red - (falloff1 * Ydistance)
						green1 = green - (falloff2 * Ydistance)
						blue1 = blue - (falloff3 * Ydistance)
						if not mL[YlocX][YlocY] then
							mL[YlocX][YlocY] = {}						
						elseif mL[YlocX][YlocY][id] then
							if style == 1 then
								local tempLight = mL[YlocX][YlocY][id]
								red1 = (red1 + tempLight.light[1]) / 2
								green1 = (green1 + tempLight.light[2]) / 2
								blue1 = (blue1 + tempLight.light[3]) / 2
							elseif style == 2 then
								local tempLight = mL[YlocX][YlocY][id]
								if red1 > tempLight.light[1] then
									red1 = tempLight.light[1]
								end
								if green1 > tempLight.light[2] then
									green1 = tempLight.light[2]
								end
								if blue1 > tempLight.light[3] then
									blue1 = tempLight.light[3]
								end
							else
								local tempLight = mL[YlocX][YlocY][id]
								if red1 < tempLight.light[1] then
									red1 = tempLight.light[1]
								end
								if green1 < tempLight.light[2] then
									green1 = tempLight.light[2]
								end
								if blue1 < tempLight.light[3] then
									blue1 = tempLight.light[3]
								end
							end
						end
						mL[YlocX][YlocY][id] = {}
						mL[YlocX][YlocY][id].light = {red1, green1, blue1}
						
						if map.lightingData[mW[YlocX][YlocY]] then
							local temp = map.lightingData[mW[YlocX][YlocY]]
							red = red - temp.opacity[1]
							green = green - temp.opacity[2]
							blue = blue - temp.opacity[3]
						end	

						YcheckX = YcheckX - YdeltaX
						YcheckY = YcheckY + YdeltaY
						YlocX, YlocY = YlocX - 1, ceil(YcheckY / blockScaleYt)
						Ydistance = Ydistance + YdeltaV
					end
				end
			
			
				if red1 <= 0 and green1 <= 0 and blue1 <= 0 then
					break
				end
			
				if Xdistance > range and Ydistance > range then
					break
				end
			end
		
		elseif x < 0 and y < 0 then
			--top left quadrant

			local Xangle = (270 - i) * toRadian --math.rad(270 - i)
			local XcheckY = tileY
			local XcheckX = levelPosX - (math.tan(Xangle) * (levelPosY - tileY))
			local XdeltaY = blockScaleYt
			local XdeltaX = math.tan(Xangle) * blockScaleYt
			local XlocX, XlocY = ceil(XcheckX / blockScaleXt), ceil(XcheckY / blockScaleYt)
			local Xdistance = startY / math.cos(Xangle) / blockScaleXt
			local XdeltaV = blockScaleYt / math.cos(Xangle) / blockScaleYt
		
			local Yangle = (i - 180) * toRadian --math.rad(i - 180)
			local YcheckY = levelPosY - (math.tan(Yangle) * (levelPosX - tileX))
			local YcheckX = tileX
			local YdeltaY = math.tan(Yangle) * blockScaleXt
			local YdeltaX = blockScaleXt
			local YlocX, YlocY = ceil(YcheckX / blockScaleXt), ceil(YcheckY / blockScaleYt)
			local Ydistance = startX / math.cos(Yangle) / blockScaleYt
			local YdeltaV = blockScaleXt / math.cos(Yangle) / blockScaleXt
		
			for j = 1, range * 2, 1 do
				count = count + 1
			
				if worldWrapX then
					if XlocX > worldSizeXt - map.locOffsetX then
						XlocX = XlocX - worldSizeXt
					end
					if XlocX < 1 - map.locOffsetX then
						XlocX = XlocX + worldSizeXt
					end
					if YlocX > worldSizeXt - map.locOffsetX then
						YlocX = YlocX - worldSizeXt
					end
					if YlocX < 1 - map.locOffsetX then
						YlocX = YlocX + worldSizeXt
					end
				end
				if worldWrapY then
					if XlocY > worldSizeYt - map.locOffsetY then
						XlocY = XlocY - worldSizeYt
					end
					if XlocY < 1 - map.locOffsetY then
						XlocY = XlocY + worldSizeYt
					end
					if YlocY > worldSizeYt - map.locOffsetY then
						YlocY = YlocY - worldSizeYt
					end
					if YlocY < 1 - map.locOffsetY then
						YlocY = YlocY + worldSizeYt
					end
				end
			
				if XlocX < 1 - map.locOffsetX or XlocX > worldSizeXt - map.locOffsetX or XlocY < 1 - map.locOffsetY or XlocY > worldSizeYt - map.locOffsetY then
					breakX = true
				end
				if YlocX < 1 - map.locOffsetX or YlocX > worldSizeXt - map.locOffsetX or YlocY < 1 - map.locOffsetY or YlocY > worldSizeYt - map.locOffsetY then
					breakY = true
				end
				if breakX and breakY then
					break
				end

				local red1, green1, blue1
			
				if Xdistance < Ydistance then
					if Xdistance <= range then
						mT[XlocX][XlocY] = time
						area[areaIndex] = {XlocX, XlocY}
						areaIndex = areaIndex + 1
						red1 = red - (falloff1 * Xdistance)
						green1 = green - (falloff2 * Xdistance)
						blue1 = blue - (falloff3 * Xdistance)
						if not mL[XlocX][XlocY] then
							mL[XlocX][XlocY] = {}						
						elseif mL[XlocX][XlocY][id] then
							if style == 1 then
								local tempLight = mL[XlocX][XlocY][id]
								red1 = (red1 + tempLight.light[1]) / 2
								green1 = (green1 + tempLight.light[2]) / 2
								blue1 = (blue1 + tempLight.light[3]) / 2
							elseif style == 2 then
								local tempLight = mL[XlocX][XlocY][id]
								if red1 > tempLight.light[1] then
									red1 = tempLight.light[1]
								end
								if green1 > tempLight.light[2] then
									green1 = tempLight.light[2]
								end
								if blue1 > tempLight.light[3] then
									blue1 = tempLight.light[3]
								end
							else
								local tempLight = mL[XlocX][XlocY][id]
								if red1 < tempLight.light[1] then
									red1 = tempLight.light[1]
								end
								if green1 < tempLight.light[2] then
									green1 = tempLight.light[2]
								end
								if blue1 < tempLight.light[3] then
									blue1 = tempLight.light[3]
								end
							end
						end
						mL[XlocX][XlocY][id] = {}
						mL[XlocX][XlocY][id].light = {red1, green1, blue1}
					
						if map.lightingData[mW[XlocX][XlocY]] then
							local temp = map.lightingData[mW[XlocX][XlocY]]
							red = red - temp.opacity[1]
							green = green - temp.opacity[2]
							blue = blue - temp.opacity[3]
						end
					
						XcheckX = XcheckX - XdeltaX
						XcheckY = XcheckY - XdeltaY
						XlocX, XlocY = ceil(XcheckX / blockScaleXt), XlocY - 1
						Xdistance = Xdistance + XdeltaV
					end
				else
					if Ydistance <= range then
						mT[YlocX][YlocY] = time
						area[areaIndex] = {YlocX, YlocY}
						areaIndex = areaIndex + 1
						red1 = red - (falloff1 * Ydistance)
						green1 = green - (falloff2 * Ydistance)
						blue1 = blue - (falloff3 * Ydistance)
						if not mL[YlocX][YlocY] then
							mL[YlocX][YlocY] = {}						
						elseif mL[YlocX][YlocY][id] then
							if style == 1 then
								local tempLight = mL[YlocX][YlocY][id]
								red1 = (red1 + tempLight.light[1]) / 2
								green1 = (green1 + tempLight.light[2]) / 2
								blue1 = (blue1 + tempLight.light[3]) / 2
							elseif style == 2 then
								local tempLight = mL[YlocX][YlocY][id]
								if red1 > tempLight.light[1] then
									red1 = tempLight.light[1]
								end
								if green1 > tempLight.light[2] then
									green1 = tempLight.light[2]
								end
								if blue1 > tempLight.light[3] then
									blue1 = tempLight.light[3]
								end
							else
								local tempLight = mL[YlocX][YlocY][id]
								if red1 < tempLight.light[1] then
									red1 = tempLight.light[1]
								end
								if green1 < tempLight.light[2] then
									green1 = tempLight.light[2]
								end
								if blue1 < tempLight.light[3] then
									blue1 = tempLight.light[3]
								end
							end
						end
						mL[YlocX][YlocY][id] = {}
						mL[YlocX][YlocY][id].light = {red1, green1, blue1}
					
						if map.lightingData[mW[YlocX][YlocY]] then
							local temp = map.lightingData[mW[YlocX][YlocY]]
							red = red - temp.opacity[1]
							green = green - temp.opacity[2]
							blue = blue - temp.opacity[3]
						end	

						YcheckX = YcheckX - YdeltaX
						YcheckY = YcheckY - YdeltaY
						YlocX, YlocY = YlocX - 1, ceil(YcheckY / blockScaleYt)
						Ydistance = Ydistance + YdeltaV
					end
				end			
			
				if red1 <= 0 and green1 <= 0 and blue1 <= 0 then
					break
				end
			
				if Xdistance > range and Ydistance > range then
					break
				end
			end		
		end	
		light.areaIndex = areaIndex
	end
	
	M.processLight = function(layer, light)
		local style = 3
		local blockScaleXt = map.tilewidth
		local blockScaleYt = map.tileheight
		local range = light.maxRange
		local steps = (2 * range * 3.14) * M.lightingData.resolution 
		local angleSteps = 360 / steps
	
		local r1, r2 = 1, 361
		if light.arc then
			r1 = light.arc[1]
			r2 = light.arc[2]
		end
	
		local levelPosX, levelPosY
		if not light.levelPosX then
			levelPosX = (light.locX * blockScaleXt - blockScaleXt * 0.5)
			levelPosY = (light.locY * blockScaleYt - blockScaleYt * 0.5)
		else
			levelPosX = light.levelPosX
			levelPosY = light.levelPosY
		end
	
		light.levelPosX = levelPosX
		light.levelPosY = levelPosY
		light.layer = layer
		local cLocX = math.round((levelPosX + (blockScaleXt * 0.5)) / blockScaleXt) --light.locX
		local cLocY = math.round((levelPosY + (blockScaleYt * 0.5)) / blockScaleYt) --light.locY
		light.locX = cLocX
		light.locY = cLocY
		local tileX = (cLocX - 1) * blockScaleXt
		local tileY = (cLocY - 1) * blockScaleYt
		local startX = levelPosX - tileX
		local startY = levelPosY - tileY

		local mL = map.layers[layer].lighting
		local mW = map.layers[layer].world
		local mT = map.lightToggle
		local dynamic = light.dynamic
		local area = light.area
		local areaIndex = 1
		local worldSizeXt = map.width
		local worldSizeYt = map.height
		local worldWrapX = worldWrapX
		local worldWrapY = worldWrapY
		local id = light.id
		local falloff1 = light.falloff[1]
		local falloff2 = light.falloff[2]
		local falloff3 = light.falloff[3]
	
		if not mL[cLocX][cLocY] then
			mL[cLocX][cLocY] = {}
		end
	
		if not light.locations then
			light.locations = {}
		end
	
		local count = 0
		local time = tonumber(system.getTimer())
		light.lightToggle = time
		local toRadian = 0.01745329251994

		mL[cLocX][cLocY][id] = {}
		mL[cLocX][cLocY][id].light = {light.source[1], light.source[2], light.source[3]}
		mT[cLocX][cLocY] = time
		area[areaIndex] = {cLocX, cLocY}
		areaIndex = areaIndex + 1
	
		for i = r1, r2, angleSteps do
			local breakX = false
			local breakY = false
			local angleR = i * toRadian --math.rad(i)
			local x = (5 * math.cos(angleR))
			local y = (5 * math.sin(angleR))
		
			local red = light.source[1]
			local green = light.source[2]
			local blue = light.source[3]
		
			if x > 0 and y < 0 then
				--top right quadrant
				
				local Xangle = (i - 270) * toRadian --math.rad(i - 270)
				local XcheckY = tileY
				local XcheckX = math.tan(Xangle) * startY + levelPosX
				local XdeltaY = blockScaleYt
				local XdeltaX = math.tan(Xangle) * blockScaleYt
				local XlocX, XlocY = ceil(XcheckX / blockScaleXt), ceil(XcheckY / blockScaleYt)
				local Xdistance = startY / math.cos(Xangle) / blockScaleXt
				local XdeltaV = blockScaleYt / math.cos(Xangle) / blockScaleYt
			
				local Yangle = (360 - i) * toRadian --math.rad(360 - i)
				local YcheckY = levelPosY - (math.tan(Yangle) * (tileX + blockScaleXt - levelPosX))
				local YcheckX = tileX + blockScaleXt + 1
				local YdeltaY = math.tan(Yangle) * blockScaleXt
				local YdeltaX = blockScaleXt
				local YlocX, YlocY = ceil(YcheckX / blockScaleXt), ceil(YcheckY / blockScaleYt)
				local Ydistance = (YcheckX - levelPosX) / math.cos(Yangle) / blockScaleYt
				local YdeltaV = blockScaleXt / math.cos(Yangle) / blockScaleXt
			
				for j = 1, range * 2, 1 do
					count = count + 1
				
					if worldWrapX then
						if XlocX > worldSizeXt - map.locOffsetX then
							XlocX = XlocX - worldSizeXt
						end
						if XlocX < 1 - map.locOffsetX then
							XlocX = XlocX + worldSizeXt
						end
						if YlocX > worldSizeXt - map.locOffsetX then
							YlocX = YlocX - worldSizeXt
						end
						if YlocX < 1 - map.locOffsetX then
							YlocX = YlocX + worldSizeXt
						end
					end
					if worldWrapY then
						if XlocY > worldSizeYt - map.locOffsetY then
							XlocY = XlocY - worldSizeYt
						end
						if XlocY < 1 - map.locOffsetY then
							XlocY = XlocY + worldSizeYt
						end
						if YlocY > worldSizeYt - map.locOffsetY then
							YlocY = YlocY - worldSizeYt
						end
						if YlocY < 1 - map.locOffsetY then
							YlocY = YlocY + worldSizeYt
						end
					end
				
					if XlocX < 1 - map.locOffsetX or XlocX > worldSizeXt - map.locOffsetX or XlocY < 1 - map.locOffsetY or XlocY > worldSizeYt - map.locOffsetY then
						breakX = true
					end
					if YlocX < 1 - map.locOffsetX or YlocX > worldSizeXt - map.locOffsetX or YlocY < 1 - map.locOffsetY or YlocY > worldSizeYt - map.locOffsetY then
						breakY = true
					end
					if breakX and breakY then
						break
					end
				
					local red1,green1,blue1
				
					if Xdistance < Ydistance then
						if Xdistance <= range then
							mT[XlocX][XlocY] = time
							area[areaIndex] = {XlocX, XlocY}
							areaIndex = areaIndex + 1
							red1 = red - (falloff1 * Xdistance)
							green1 = green - (falloff2 * Xdistance)
							blue1 = blue - (falloff3 * Xdistance)
							if not mL[XlocX][XlocY] then
								mL[XlocX][XlocY] = {}						
							elseif mL[XlocX][XlocY][id] then							
								if style == 1 then
									local tempLight = mL[XlocX][XlocY][id]
									red1 = (red1 + tempLight.light[1]) / 2
									green1 = (green1 + tempLight.light[2]) / 2
									blue1 = (blue1 + tempLight.light[3]) / 2
								elseif style == 2 then
									local tempLight = mL[XlocX][XlocY][id]
									if red1 > tempLight.light[1] then
										red1 = tempLight.light[1]
									end
									if green1 > tempLight.light[2] then
										green1 = tempLight.light[2]
									end
									if blue1 > tempLight.light[3] then
										blue1 = tempLight.light[3]
									end
								else
									local tempLight = mL[XlocX][XlocY][id]
									if red1 < tempLight.light[1] then
										red1 = tempLight.light[1]
									end
									if green1 < tempLight.light[2] then
										green1 = tempLight.light[2]
									end
									if blue1 < tempLight.light[3] then
										blue1 = tempLight.light[3]
									end
								end
							end
							mL[XlocX][XlocY][id] = {}
							mL[XlocX][XlocY][id].light = {red1, green1, blue1}
						
							if map.lightingData[mW[XlocX][XlocY]] then
								local temp = map.lightingData[mW[XlocX][XlocY]]
								red = red - temp.opacity[1]
								green = green - temp.opacity[2]
								blue = blue - temp.opacity[3]
							end
						
							XcheckX = XcheckX + XdeltaX
							XcheckY = XcheckY - XdeltaY
							XlocX, XlocY = ceil(XcheckX / blockScaleXt), XlocY - 1
							Xdistance = Xdistance + XdeltaV
						end
					else
						if Ydistance <= range then
							mT[YlocX][YlocY] = time
							area[areaIndex] = {YlocX, YlocY}
							areaIndex = areaIndex + 1
							red1 = red - (falloff1 * Ydistance)
							green1 = green - (falloff2 * Ydistance)
							blue1 = blue - (falloff3 * Ydistance)
							if not mL[YlocX][YlocY] then
								mL[YlocX][YlocY] = {}						
							elseif mL[YlocX][YlocY][id] then
								if style == 1 then
									local tempLight = mL[YlocX][YlocY][id]
									red1 = (red1 + tempLight.light[1]) / 2
									green1 = (green1 + tempLight.light[2]) / 2
									blue1 = (blue1 + tempLight.light[3]) / 2
								elseif style == 2 then
									local tempLight = mL[YlocX][YlocY][id]
									if red1 > tempLight.light[1] then
										red1 = tempLight.light[1]
									end
									if green1 > tempLight.light[2] then
										green1 = tempLight.light[2]
									end
									if blue1 > tempLight.light[3] then
										blue1 = tempLight.light[3]
									end
								else
									local tempLight = mL[YlocX][YlocY][id]
									if red1 < tempLight.light[1] then
										red1 = tempLight.light[1]
									end
									if green1 < tempLight.light[2] then
										green1 = tempLight.light[2]
									end
									if blue1 < tempLight.light[3] then
										blue1 = tempLight.light[3]
									end
								end
							end
							mL[YlocX][YlocY][id] = {}
							mL[YlocX][YlocY][id].light = {red1, green1, blue1}
						
							if map.lightingData[mW[YlocX][YlocY]] then
								local temp = map.lightingData[mW[YlocX][YlocY]]
								red = red - temp.opacity[1]
								green = green - temp.opacity[2]
								blue = blue - temp.opacity[3]
							end	

							YcheckX = YcheckX + YdeltaX
							YcheckY = YcheckY - YdeltaY
							YlocX, YlocY = YlocX + 1, ceil(YcheckY / blockScaleYt)
							Ydistance = Ydistance + YdeltaV
						end
					end				
				
					if red1 <= 0 and green1 <= 0 and blue1 <= 0 then
						break
					end
				
					if Xdistance > range and Ydistance > range then
						break
					end
				end

			elseif x > 0 and y > 0 then
				--bottom right quadrant

				local Xangle = (90 - i) * toRadian --math.rad(90 - i)
				local XcheckY = tileY + blockScaleYt + 1
				local XcheckX = math.tan(Xangle) * (XcheckY - levelPosY) + levelPosX
				local XdeltaY = blockScaleYt
				local XdeltaX = math.tan(Xangle) * blockScaleYt
				local XlocX, XlocY = ceil(XcheckX / blockScaleXt), ceil(XcheckY / blockScaleYt)
				local Xdistance = (XcheckY - levelPosY) / math.cos(Xangle) / blockScaleXt
				local XdeltaV = blockScaleYt / math.cos(Xangle) / blockScaleYt
			
				local Yangle = i * toRadian --math.rad(i)
				local YcheckY = math.tan(Yangle) * (tileX + blockScaleXt - levelPosX) + levelPosY
				local YcheckX = tileX + blockScaleXt + 1
				local YdeltaY = math.tan(Yangle) * blockScaleXt
				local YdeltaX = blockScaleXt
				local YlocX, YlocY = ceil(YcheckX / blockScaleXt), ceil(YcheckY / blockScaleYt)
				local Ydistance = (YcheckX - levelPosX) / math.cos(Yangle) / blockScaleYt
				local YdeltaV = blockScaleXt / math.cos(Yangle) / blockScaleXt
			
				for j = 1, range * 2, 1 do
					count = count + 1
				
					if worldWrapX then
						if XlocX > worldSizeXt - map.locOffsetX then
							XlocX = XlocX - worldSizeXt
						end
						if XlocX < 1 - map.locOffsetX then
							XlocX = XlocX + worldSizeXt
						end
						if YlocX > worldSizeXt - map.locOffsetX then
							YlocX = YlocX - worldSizeXt
						end
						if YlocX < 1 - map.locOffsetX then
							YlocX = YlocX + worldSizeXt
						end
					end
					if worldWrapY then
						if XlocY > worldSizeYt - map.locOffsetY then
							XlocY = XlocY - worldSizeYt
						end
						if XlocY < 1 - map.locOffsetY then
							XlocY = XlocY + worldSizeYt
						end
						if YlocY > worldSizeYt - map.locOffsetY then
							YlocY = YlocY - worldSizeYt
						end
						if YlocY < 1 - map.locOffsetY then
							YlocY = YlocY + worldSizeYt
						end
					end
				
					if XlocX < 1 - map.locOffsetX or XlocX > worldSizeXt - map.locOffsetX or XlocY < 1 - map.locOffsetY or XlocY > worldSizeYt - map.locOffsetY then
						breakX = true
					end
					if YlocX < 1 - map.locOffsetX or YlocX > worldSizeXt - map.locOffsetX or YlocY < 1 - map.locOffsetY or YlocY > worldSizeYt - map.locOffsetY then
						breakY = true
					end
					if breakX and breakY then
						break
					end
				
					local red1,green1,blue1
				
					if Xdistance < Ydistance then
						if Xdistance <= range then
							mT[XlocX][XlocY] = time
							area[areaIndex] = {XlocX, XlocY}
							areaIndex = areaIndex + 1
							red1 = red - (falloff1 * Xdistance)
							green1 = green - (falloff2 * Xdistance)
							blue1 = blue - (falloff3 * Xdistance)
							if not mL[XlocX][XlocY] then
								mL[XlocX][XlocY] = {}						
							elseif mL[XlocX][XlocY][id] then
								if style == 1 then
									local tempLight = mL[XlocX][XlocY][id]
									red1 = (red1 + tempLight.light[1]) / 2
									green1 = (green1 + tempLight.light[2]) / 2
									blue1 = (blue1 + tempLight.light[3]) / 2
								elseif style == 2 then
									local tempLight = mL[XlocX][XlocY][id]
									if red1 > tempLight.light[1] then
										red1 = tempLight.light[1]
									end
									if green1 > tempLight.light[2] then
										green1 = tempLight.light[2]
									end
									if blue1 > tempLight.light[3] then
										blue1 = tempLight.light[3]
									end
								else
									local tempLight = mL[XlocX][XlocY][id]
									if red1 < tempLight.light[1] then
										red1 = tempLight.light[1]
									end
									if green1 < tempLight.light[2] then
										green1 = tempLight.light[2]
									end
									if blue1 < tempLight.light[3] then
										blue1 = tempLight.light[3]
									end
								end
							end
							mL[XlocX][XlocY][id] = {}
							mL[XlocX][XlocY][id].light = {red1, green1, blue1}
						
							if map.lightingData[mW[XlocX][XlocY]] then
								local temp = map.lightingData[mW[XlocX][XlocY]]
								red = red - temp.opacity[1]
								green = green - temp.opacity[2]
								blue = blue - temp.opacity[3]
							end
						
							XcheckX = XcheckX + XdeltaX
							XcheckY = XcheckY + XdeltaY
							XlocX, XlocY = ceil(XcheckX / blockScaleXt), XlocY + 1
							Xdistance = Xdistance + XdeltaV
						end
					else
						if Ydistance <= range then
							mT[YlocX][YlocY] = time
							area[areaIndex] = {YlocX, YlocY}
							areaIndex = areaIndex + 1
							red1 = red - (falloff1 * Ydistance)
							green1 = green - (falloff2 * Ydistance)
							blue1 = blue - (falloff3 * Ydistance)
							if not mL[YlocX][YlocY] then
								mL[YlocX][YlocY] = {}						
							elseif mL[YlocX][YlocY][id] then
								if style == 1 then
									local tempLight = mL[YlocX][YlocY][id]
									red1 = (red1 + tempLight.light[1]) / 2
									green1 = (green1 + tempLight.light[2]) / 2
									blue1 = (blue1 + tempLight.light[3]) / 2
								elseif style == 2 then
									local tempLight = mL[YlocX][YlocY][id]
									if red1 > tempLight.light[1] then
										red1 = tempLight.light[1]
									end
									if green1 > tempLight.light[2] then
										green1 = tempLight.light[2]
									end
									if blue1 > tempLight.light[3] then
										blue1 = tempLight.light[3]
									end
								else
									local tempLight = mL[YlocX][YlocY][id]
									if red1 < tempLight.light[1] then
										red1 = tempLight.light[1]
									end
									if green1 < tempLight.light[2] then
										green1 = tempLight.light[2]
									end
									if blue1 < tempLight.light[3] then
										blue1 = tempLight.light[3]
									end
								end
							end
							mL[YlocX][YlocY][id] = {}
							mL[YlocX][YlocY][id].light = {red1, green1, blue1}
						
							if map.lightingData[mW[YlocX][YlocY]] then
								local temp = map.lightingData[mW[YlocX][YlocY]]
								red = red - temp.opacity[1]
								green = green - temp.opacity[2]
								blue = blue - temp.opacity[3]
							end	

							YcheckX = YcheckX + YdeltaX
							YcheckY = YcheckY + YdeltaY
							YlocX, YlocY = YlocX + 1, ceil(YcheckY / blockScaleYt)
							Ydistance = Ydistance + YdeltaV
						end
					end
				
				
					if red1 <= 0 and green1 <= 0 and blue1 <= 0 then
						break
					end
				
					if Xdistance > range and Ydistance > range then
						break
					end
				end
			
			elseif x < 0 and y > 0 then
				--bottom left quadrant

				local Xangle = (i - 90) * toRadian --math.rad(i - 90)
				local XcheckY = tileY + blockScaleYt + 1
				local XcheckX = levelPosX - (math.tan(Xangle) * (XcheckY - levelPosY))
				local XdeltaY = blockScaleYt
				local XdeltaX = math.tan(Xangle) * blockScaleYt
				local XlocX, XlocY = ceil(XcheckX / blockScaleXt), ceil(XcheckY / blockScaleYt)
				local Xdistance = (XcheckY - levelPosY) / math.cos(Xangle) / blockScaleXt
				local XdeltaV = blockScaleYt / math.cos(Xangle) / blockScaleYt
			
				local Yangle = (180 - i) * toRadian --math.rad(180 - i)
				local YcheckY = math.tan(Yangle) * (levelPosX - tileX) + levelPosY
				local YcheckX = tileX 
				local YdeltaY = math.tan(Yangle) * blockScaleXt
				local YdeltaX = blockScaleXt
				local YlocX, YlocY = ceil(YcheckX / blockScaleXt), ceil(YcheckY / blockScaleYt)
				local Ydistance = startX / math.cos(Yangle) / blockScaleYt
				local YdeltaV = blockScaleXt / math.cos(Yangle) / blockScaleXt

				for j = 1, range * 2, 1 do
					count = count + 1
				
					if worldWrapX then
						if XlocX > worldSizeXt - map.locOffsetX then
							XlocX = XlocX - worldSizeXt
						end
						if XlocX < 1 - map.locOffsetX then
							XlocX = XlocX + worldSizeXt
						end
						if YlocX > worldSizeXt - map.locOffsetX then
							YlocX = YlocX - worldSizeXt
						end
						if YlocX < 1 - map.locOffsetX then
							YlocX = YlocX + worldSizeXt
						end
					end
					if worldWrapY then
						if XlocY > worldSizeYt - map.locOffsetY then
							XlocY = XlocY - worldSizeYt
						end
						if XlocY < 1 - map.locOffsetY then
							XlocY = XlocY + worldSizeYt
						end
						if YlocY > worldSizeYt - map.locOffsetY then
							YlocY = YlocY - worldSizeYt
						end
						if YlocY < 1 - map.locOffsetY then
							YlocY = YlocY + worldSizeYt
						end
					end
				
					if XlocX < 1 - map.locOffsetX or XlocX > worldSizeXt - map.locOffsetX or XlocY < 1 - map.locOffsetY or XlocY > worldSizeYt - map.locOffsetY then
						breakX = true
					end
					if YlocX < 1 - map.locOffsetX or YlocX > worldSizeXt - map.locOffsetX or YlocY < 1 - map.locOffsetY or YlocY > worldSizeYt - map.locOffsetY then
						breakY = true
					end
					if breakX and breakY then
						break
					end
				
					local red1, green1, blue1
				
					if Xdistance < Ydistance then
						if Xdistance <= range then
							mT[XlocX][XlocY] = time
							area[areaIndex] = {XlocX, XlocY}
							areaIndex = areaIndex + 1
							red1 = red - (falloff1 * Xdistance)
							green1 = green - (falloff2 * Xdistance)
							blue1 = blue - (falloff3 * Xdistance)
							if not mL[XlocX][XlocY] then
								mL[XlocX][XlocY] = {}						
							elseif mL[XlocX][XlocY][id] then
								if style == 1 then
									local tempLight = mL[XlocX][XlocY][id]
									red1 = (red1 + tempLight.light[1]) / 2
									green1 = (green1 + tempLight.light[2]) / 2
									blue1 = (blue1 + tempLight.light[3]) / 2
								elseif style == 2 then
									local tempLight = mL[XlocX][XlocY][id]
									if red1 > tempLight.light[1] then
										red1 = tempLight.light[1]
									end
									if green1 > tempLight.light[2] then
										green1 = tempLight.light[2]
									end
									if blue1 > tempLight.light[3] then
										blue1 = tempLight.light[3]
									end
								else
									local tempLight = mL[XlocX][XlocY][id]
									if red1 < tempLight.light[1] then
										red1 = tempLight.light[1]
									end
									if green1 < tempLight.light[2] then
										green1 = tempLight.light[2]
									end
									if blue1 < tempLight.light[3] then
										blue1 = tempLight.light[3]
									end
								end
							end
							mL[XlocX][XlocY][id] = {}
							mL[XlocX][XlocY][id].light = {red1, green1, blue1}
						
							if map.lightingData[mW[XlocX][XlocY]] then
								local temp = map.lightingData[mW[XlocX][XlocY]]
								red = red - temp.opacity[1]
								green = green - temp.opacity[2]
								blue = blue - temp.opacity[3]
							end
						
							XcheckX = XcheckX - XdeltaX
							XcheckY = XcheckY + XdeltaY
							XlocX, XlocY = ceil(XcheckX / blockScaleXt), XlocY + 1
							Xdistance = Xdistance + XdeltaV
						end
					else
						if Ydistance <= range then
							mT[YlocX][YlocY] = time
							area[areaIndex] = {YlocX, YlocY}
							areaIndex = areaIndex + 1
							red1 = red - (falloff1 * Ydistance)
							green1 = green - (falloff2 * Ydistance)
							blue1 = blue - (falloff3 * Ydistance)
							if not mL[YlocX][YlocY] then
								mL[YlocX][YlocY] = {}						
							elseif mL[YlocX][YlocY][id] then
								if style == 1 then
									local tempLight = mL[YlocX][YlocY][id]
									red1 = (red1 + tempLight.light[1]) / 2
									green1 = (green1 + tempLight.light[2]) / 2
									blue1 = (blue1 + tempLight.light[3]) / 2
								elseif style == 2 then
									local tempLight = mL[YlocX][YlocY][id]
									if red1 > tempLight.light[1] then
										red1 = tempLight.light[1]
									end
									if green1 > tempLight.light[2] then
										green1 = tempLight.light[2]
									end
									if blue1 > tempLight.light[3] then
										blue1 = tempLight.light[3]
									end
								else
									local tempLight = mL[YlocX][YlocY][id]
									if red1 < tempLight.light[1] then
										red1 = tempLight.light[1]
									end
									if green1 < tempLight.light[2] then
										green1 = tempLight.light[2]
									end
									if blue1 < tempLight.light[3] then
										blue1 = tempLight.light[3]
									end
								end
							end
							mL[YlocX][YlocY][id] = {}
							mL[YlocX][YlocY][id].light = {red1, green1, blue1}
						
							if map.lightingData[mW[YlocX][YlocY]] then
								local temp = map.lightingData[mW[YlocX][YlocY]]
								red = red - temp.opacity[1]
								green = green - temp.opacity[2]
								blue = blue - temp.opacity[3]
							end	

							YcheckX = YcheckX - YdeltaX
							YcheckY = YcheckY + YdeltaY
							YlocX, YlocY = YlocX - 1, ceil(YcheckY / blockScaleYt)
							Ydistance = Ydistance + YdeltaV
						end
					end
				
					if red1 <= 0 and green1 <= 0 and blue1 <= 0 then
						break
					end
				
					if Xdistance > range and Ydistance > range then
						break
					end				
				end
			
			elseif x < 0 and y < 0 then
				--top left quadrant

				local Xangle = (270 - i) * toRadian --math.rad(270 - i)
				local XcheckY = tileY
				local XcheckX = levelPosX - (math.tan(Xangle) * (levelPosY - tileY))
				local XdeltaY = blockScaleYt
				local XdeltaX = math.tan(Xangle) * blockScaleYt
				local XlocX, XlocY = ceil(XcheckX / blockScaleXt), ceil(XcheckY / blockScaleYt)
				local Xdistance = startY / math.cos(Xangle) / blockScaleXt
				local XdeltaV = blockScaleYt / math.cos(Xangle) / blockScaleYt
			
				local Yangle = (i - 180) * toRadian --math.rad(i - 180)
				local YcheckY = levelPosY - (math.tan(Yangle) * (levelPosX - tileX))
				local YcheckX = tileX
				local YdeltaY = math.tan(Yangle) * blockScaleXt
				local YdeltaX = blockScaleXt
				local YlocX, YlocY = ceil(YcheckX / blockScaleXt), ceil(YcheckY / blockScaleYt)
				local Ydistance = startX / math.cos(Yangle) / blockScaleYt
				local YdeltaV = blockScaleXt / math.cos(Yangle) / blockScaleXt
			
				for j = 1, range * 2, 1 do
					count = count + 1
				
					if worldWrapX then
						if XlocX > worldSizeXt - map.locOffsetX then
							XlocX = XlocX - worldSizeXt
						end
						if XlocX < 1 - map.locOffsetX then
							XlocX = XlocX + worldSizeXt
						end
						if YlocX > worldSizeXt - map.locOffsetX then
							YlocX = YlocX - worldSizeXt
						end
						if YlocX < 1 - map.locOffsetX then
							YlocX = YlocX + worldSizeXt
						end
					end
					if worldWrapY then
						if XlocY > worldSizeYt - map.locOffsetY then
							XlocY = XlocY - worldSizeYt
						end
						if XlocY < 1 - map.locOffsetY then
							XlocY = XlocY + worldSizeYt
						end
						if YlocY > worldSizeYt - map.locOffsetY then
							YlocY = YlocY - worldSizeYt
						end
						if YlocY < 1 - map.locOffsetY then
							YlocY = YlocY + worldSizeYt
						end
					end
				
					if XlocX < 1 - map.locOffsetX or XlocX > worldSizeXt - map.locOffsetX or XlocY < 1 - map.locOffsetY or XlocY > worldSizeYt - map.locOffsetY then
						breakX = true
					end
					if YlocX < 1 - map.locOffsetX or YlocX > worldSizeXt - map.locOffsetX or YlocY < 1 - map.locOffsetY or YlocY > worldSizeYt - map.locOffsetY then
						breakY = true
					end
					if breakX and breakY then
						break
					end

					local red1, green1, blue1
				
					if Xdistance < Ydistance then
						if Xdistance <= range then
							mT[XlocX][XlocY] = time
							area[areaIndex] = {XlocX, XlocY}
							areaIndex = areaIndex + 1
							red1 = red - (falloff1 * Xdistance)
							green1 = green - (falloff2 * Xdistance)
							blue1 = blue - (falloff3 * Xdistance)
							if not mL[XlocX][XlocY] then
								mL[XlocX][XlocY] = {}						
							elseif mL[XlocX][XlocY][id] then
								if style == 1 then
									local tempLight = mL[XlocX][XlocY][id]
									red1 = (red1 + tempLight.light[1]) / 2
									green1 = (green1 + tempLight.light[2]) / 2
									blue1 = (blue1 + tempLight.light[3]) / 2
								elseif style == 2 then
									local tempLight = mL[XlocX][XlocY][id]
									if red1 > tempLight.light[1] then
										red1 = tempLight.light[1]
									end
									if green1 > tempLight.light[2] then
										green1 = tempLight.light[2]
									end
									if blue1 > tempLight.light[3] then
										blue1 = tempLight.light[3]
									end
								else
									local tempLight = mL[XlocX][XlocY][id]
									if red1 < tempLight.light[1] then
										red1 = tempLight.light[1]
									end
									if green1 < tempLight.light[2] then
										green1 = tempLight.light[2]
									end
									if blue1 < tempLight.light[3] then
										blue1 = tempLight.light[3]
									end
								end
							end
							mL[XlocX][XlocY][id] = {}
							mL[XlocX][XlocY][id].light = {red1, green1, blue1}
						
							if map.lightingData[mW[XlocX][XlocY]] then
								local temp = map.lightingData[mW[XlocX][XlocY]]
								red = red - temp.opacity[1]
								green = green - temp.opacity[2]
								blue = blue - temp.opacity[3]
							end
						
							XcheckX = XcheckX - XdeltaX
							XcheckY = XcheckY - XdeltaY
							XlocX, XlocY = ceil(XcheckX / blockScaleXt), XlocY - 1
							Xdistance = Xdistance + XdeltaV
						end
					else
						if Ydistance <= range then
							mT[YlocX][YlocY] = time
							area[areaIndex] = {YlocX, YlocY}
							areaIndex = areaIndex + 1
							red1 = red - (falloff1 * Ydistance)
							green1 = green - (falloff2 * Ydistance)
							blue1 = blue - (falloff3 * Ydistance)
							if not mL[YlocX][YlocY] then
								mL[YlocX][YlocY] = {}						
							elseif mL[YlocX][YlocY][id] then
								if style == 1 then
									local tempLight = mL[YlocX][YlocY][id]
									red1 = (red1 + tempLight.light[1]) / 2
									green1 = (green1 + tempLight.light[2]) / 2
									blue1 = (blue1 + tempLight.light[3]) / 2
								elseif style == 2 then
									local tempLight = mL[YlocX][YlocY][id]
									if red1 > tempLight.light[1] then
										red1 = tempLight.light[1]
									end
									if green1 > tempLight.light[2] then
										green1 = tempLight.light[2]
									end
									if blue1 > tempLight.light[3] then
										blue1 = tempLight.light[3]
									end
								else
									local tempLight = mL[YlocX][YlocY][id]
									if red1 < tempLight.light[1] then
										red1 = tempLight.light[1]
									end
									if green1 < tempLight.light[2] then
										green1 = tempLight.light[2]
									end
									if blue1 < tempLight.light[3] then
										blue1 = tempLight.light[3]
									end
								end
							end
							mL[YlocX][YlocY][id] = {}
							mL[YlocX][YlocY][id].light = {red1, green1, blue1}
						
							if map.lightingData[mW[YlocX][YlocY]] then
								local temp = map.lightingData[mW[YlocX][YlocY]]
								red = red - temp.opacity[1]
								green = green - temp.opacity[2]
								blue = blue - temp.opacity[3]
							end	

							YcheckX = YcheckX - YdeltaX
							YcheckY = YcheckY - YdeltaY
							YlocX, YlocY = YlocX - 1, ceil(YcheckY / blockScaleYt)
							Ydistance = Ydistance + YdeltaV
						end
					end
				
				
					if red1 <= 0 and green1 <= 0 and blue1 <= 0 then
						break
					end
				
					if Xdistance > range and Ydistance > range then
						break
					end
				end			
			end
		end
	end
	
	local count556 = 0
	local updateTile2 = function(parameters)
		--local locX, locY = parameters.locX, parameters.locY
		local locX, locY
		if parameters.locX then
			locX = parameters.locX
		elseif parameters.levelPosX then
			locX = math.ceil(parameters.levelPosX / map.tilewidth)
		end
		if parameters.locY then
			locY = parameters.locY
		elseif parameters.levelPosY then
			locY = math.ceil(parameters.levelPosY / map.tileheight)
		end
		local layer = parameters.layer
		local tile = parameters.tile
		local cameraX, cameraY, cameraLocX, cameraLocY = M.cameraX, M.cameraY, M.cameraLocX, M.cameraLocY
		if parameters.cameraX then
			cameraX = cameraX
		end
		if parameters.cameraY then
			cameraY = cameraY
		end
		if parameters.cameraLocX then
			cameraLocX = cameraLocX
		end
		if parameters.cameraLocY then
			cameraLocY = cameraLocY
		end
		local toggleBreak = false
		
		if locX < 1 - map.locOffsetX or locX > map.layers[layer].width - map.locOffsetX then
			if not layerWrapX[layer] then
				toggleBreak = true
			end
		end
		if locY < 1 - map.locOffsetY or locY > map.layers[layer].height - map.locOffsetY then
			if not layerWrapY[layer] then
				toggleBreak = true
			end
		end
		
		if not toggleBreak then
			if locX < 1 - map.locOffsetX then
				locX = locX + map.layers[layer].width
			end
			if locX > map.layers[layer].width - map.locOffsetX then
				locX = locX - map.layers[layer].width
			end				
			
			if locY < 1 - map.locOffsetY then
				locY = locY + map.layers[layer].height
			end
			if locY > map.layers[layer].height - map.locOffsetY then
				locY = locY - map.layers[layer].height
			end
			local isOwner = true
			if not tile then
				tile = map.layers[layer].world[locX][locY]
			end

			local temp = nil
			if tileObjects[layer][locX] and tileObjects[layer][locX][locY] then		
				--print("*", locX, locY, layer)		
				temp = tileObjects[layer][locX][locY].index
				if parameters.owner then
					isOwner = false
					if tileObjects[layer][locX][locY].owner == parameters.owner and tile ~= tileObjects[layer][locX][locY].index then
						isOwner = true
					end
				end
				--print("do9")
				if isOwner then
					if dont then
						if not tileObjects[layer][locX][locY].noDraw then
							if tileObjects[layer][locX][locY].sync then
								animatedTiles[tileObjects[layer][locX][locY]] = nil
							end
							tileObjects[layer][locX][locY]:removeSelf()
							totalRects[layer] = totalRects[layer] - 1
						end
					end
					
					local frameIndex = map.layers[layer].world[locX][locY]
					local tileSetIndex = 1
					for i = 1, #map.tilesets, 1 do
						if frameIndex >= map.tilesets[i].firstgid then
							tileSetIndex = i
						else
							break
						end
					end
					
					if tile == -1 then
						--print("do7")
						local mT = map.tilesets[tileSetIndex]
						if mT.tilewidth > map.tilewidth or mT.tileheight > map.tileheight  then
							--print("do2")
							local width = math.ceil(mT.tilewidth / map.tilewidth)
							local height = math.ceil(mT.tileheight / map.tileheight)
						
							local left, top, right, bottom = locX, locY - height + 1, locX + width - 1, locY
						
							if (left > masterGroup[layer].vars.camera[3] or right < masterGroup[layer].vars.camera[1]or
							top > masterGroup[layer].vars.camera[4] or bottom < masterGroup[layer].vars.camera[2]) or parameters.forceCullLargeTile then
								--print("do3")								
								--[[
								for lX = locX, locX + width - 1, 1 do
									for lY = locY, locY - height + 1, -1 do
										local lx = lX
										local ly = lY
										if lx > map.width then
											lx = lx - map.width
										elseif lx < 1 then
											lx = lx + map.width
										end
										if ly > map.height then
											ly = ly - map.height
										elseif ly < 1 then
											ly = ly + map.height
										end
								
										if not map.layers[layer].largeTiles[lx] then
											map.layers[layer].largeTiles[lx] = {}
										end
								
										--mL.largeTiles[lx][ly] = {frameIndex, x, y}
									end
								end	
								--print("offscreen")
								]]--
								--print("offscreen")
								if not tileObjects[layer][locX][locY].noDraw then
									if tileObjects[layer][locX][locY].sync then
										animatedTiles[tileObjects[layer][locX][locY]] = nil
									end
									tileObjects[layer][locX][locY]:removeSelf()
									totalRects[layer] = totalRects[layer] - 1
								end
								tileObjects[layer][locX][locY] = nil
														
							else
								--print("not offscreen")
							end
						else
							if not tileObjects[layer][locX][locY].noDraw then
								if tileObjects[layer][locX][locY].sync then
									animatedTiles[tileObjects[layer][locX][locY]] = nil
								end
								tileObjects[layer][locX][locY]:removeSelf()
								totalRects[layer] = totalRects[layer] - 1
							end
							tileObjects[layer][locX][locY] = nil
						end
					else
						--print("do8")
						if not tileObjects[layer][locX][locY].noDraw then
							if tileObjects[layer][locX][locY].sync then
								animatedTiles[tileObjects[layer][locX][locY]] = nil
							end
							tileObjects[layer][locX][locY]:removeSelf()
							totalRects[layer] = totalRects[layer] - 1
						end
						tileObjects[layer][locX][locY] = nil
					end	
					--tileObjects[layer][locX][locY] = nil
					
					--[[
					if tile == -1 then
						local frameIndex = map.layers[layer].world[locX][locY]
						local tileSetIndex = 1
						for i = 1, #map.tilesets, 1 do
							if frameIndex >= map.tilesets[i].firstgid then
								tileSetIndex = i
							else
								break
							end
						end
						
						local mT = map.tilesets[tileSetIndex]
						if mT.tilewidth > map.tilewidth or mT.tileheight > map.tileheight  then
							local width = math.ceil(mT.tilewidth / map.tilewidth)
							local height = math.ceil(mT.tileheight / map.tileheight)
							
							local left, top, right, bottom = locX, locY - height + 1, locX + width - 1, locY
							
							if left > masterGroup[layer].vars.camera[3] or right < masterGroup[layer].vars.camera[1]or
							top > masterGroup[layer].vars.camera[4] or bottom < masterGroup[layer].vars.camera[2] then								
								for lX = locX, locX + width - 1, 1 do
									for lY = locY, locY - height + 1, -1 do
										local lx = lX
										local ly = lY
										if lx > map.width then
											lx = lx - map.width
										elseif lx < 1 then
											lx = lx + map.width
										end
										if ly > map.height then
											ly = ly - map.height
										elseif ly < 1 then
											ly = ly + map.height
										end
									
										if not map.layers[layer].largeTiles[lx] then
											map.layers[layer].largeTiles[lx] = {}
										end
									
										--mL.largeTiles[lx][ly] = {frameIndex, x, y}
									end
								end	
								--print("offscreen")						
							else
								--print("not offscreen")
							end
									
						end
					else
						local frameIndex = map.layers[layer].world[locX][locY]
						local tileSetIndex = 1
						for i = 1, #map.tilesets, 1 do
							if frameIndex >= map.tilesets[i].firstgid then
								tileSetIndex = i
							else
								break
							end
						end

					
					end
					]]--
				else
					tile = 0
				end
			end
			if tile == 0 and isOwner then
				map.layers[layer].world[locX][locY] = tile
			end
			
			if tile > 0 then
				--print("do", locX, locY, layer)
				map.layers[layer].world[locX][locY] = tile	
				count556 = count556 + 1
				local levelPosX = locX * map.tilewidth - (map.tilewidth / 2)
				local levelPosY = locY * map.tileheight - (map.tileheight / 2)
				if layerWrapX[layer] then
					if cameraLocX - locX < map.layers[layer].width / -2 then
						--wrap around to the left
						levelPosX = levelPosX - map.layers[layer].width * map.tilewidth
					elseif cameraLocX - locX > map.layers[layer].width / 2 then
						--wrap around to the right
						levelPosX = levelPosX + map.layers[layer].width * map.tilewidth
					end
				end
				if layerWrapY[layer] then
					if cameraLocY - locY < map.layers[layer].height / -2 then
						--wrap around to the top
						levelPosY = levelPosY - map.layers[layer].height * map.tileheight
					elseif cameraLocY - locY > map.layers[layer].height / 2 then
						--wrap around to the bottom
						levelPosY = levelPosY + map.layers[layer].height * map.tileheight
					end
				end
				if map.orientation == 1 then
					local isoPos = M.isoTransform2(levelPosX, levelPosY)
					levelPosX = isoPos[1]
					levelPosY = isoPos[2]
				end
				local frameIndex = tile
				local tileSetIndex = 1
				for i = 1, #map.tilesets, 1 do
					if frameIndex >= map.tilesets[i].firstgid then
						tileSetIndex = i
					else
						break
					end
				end
				frameIndex = frameIndex - (map.tilesets[tileSetIndex].firstgid - 1)
				local tileStr = tostring(frameIndex - 1)
				local tempScaleX = map.tilesets[tileSetIndex].tilewidth
				local tempScaleY = map.tilesets[tileSetIndex].tileheight
				local offsetX = tempScaleX / 2 - map.tilewidth / 2
				local offsetY = tempScaleY / 2 - map.tileheight / 2			
				local listenerCheck = false
				local offsetZ = 0				
				if map.orientation == 1 then
					tempScaleX = tempScaleX / M.isoScaleMod + M.overDraw
					tempScaleY = tempScaleY / M.isoScaleMod + M.overDraw
					offsetY = offsetY / M.isoScaleMod
				else
					tempScaleX = tempScaleX + M.overDraw
					tempScaleY = tempScaleY + M.overDraw
				end				
				local tileProps
				if map.tilesets[tileSetIndex].tileproperties then
					if map.tilesets[tileSetIndex].tileproperties[tileStr] then
						tileProps = map.tilesets[tileSetIndex].tileproperties[tileStr]
						if tileProps["offsetZ"] then
							offsetZ = tonumber(tileProps["offsetZ"])
						end
					end
				end				
				local paint
				local normalMap = false
				if M.enableNormalMaps then
					if normalSets[tileSetIndex] then
						if not tileProps or not tileProps["normalMap"] or tileProps["normalMap"] ~= "false" then
							paint = {
								type = "composite",
								paint1 = {type = "image", sheet = tileSets[tileSetIndex], frame = frameIndex},
								paint2 = {type = "image", sheet = normalSets[tileSetIndex], frame = frameIndex}
							}
							normalMap = true
						else
							--paint = {type = "image", sheet = tileSets[tileSetIndex], frame = frameIndex}
						end
					elseif map.defaultNormalMap then
						paint = {
							type = "composite",
							paint1 = {type = "image", sheet = tileSets[tileSetIndex], frame = frameIndex},
							paint2 = {type = "image", filename = map.defaultNormalMap}
						}
						normalMap = true
					else
						--paint = {type = "image", sheet = tileSets[tileSetIndex], frame = frameIndex}
					end
				else
					--paint = {type = "image", sheet = tileSets[tileSetIndex], frame = frameIndex}
				end
				
				local render = true
				if (tileProps and parameters.onlyPhysics and not tileProps["physics"]) or (not tileProps and parameters.onlyPhysics) then
					render = false
				end
				
				if render then
					--[[
					if map.layers[layer].properties then
						if not map.tilesets[tileSetIndex].tileproperties then
							map.tilesets[tileSetIndex].tileproperties = {}
						end
						if not map.tilesets[tileSetIndex].tileproperties[tileStr] then
							map.tilesets[tileSetIndex].tileproperties[tileStr] = {}
						end
	
						for key,value in pairs(map.layers[layer].properties) do
							if not map.tilesets[tileSetIndex].tileproperties[tileStr][key] then
								map.tilesets[tileSetIndex].tileproperties[tileStr][key] = value
							end
						end
					end
					]]--
					--print("do")
					if tileProps then
						--print("do")
						if not tileProps["noDraw"] and not map.tilesets[tileSetIndex].properties["noDraw"] and not map.layers[layer].properties["noDraw"] then
							if tileProps["animFrames"] then
								tileObjects[layer][locX][locY] = display.newSprite(masterGroup[layer][1],tileSets[tileSetIndex], tileProps["sequenceData"])
								tileObjects[layer][locX][locY].xScale = tempScaleX / map.tilewidth
								tileObjects[layer][locX][locY].yScale = tempScaleY / map.tileheight
								tileObjects[layer][locX][locY]:setSequence("null")
								tileObjects[layer][locX][locY].sync = tileProps["animSync"]
								animatedTiles[tileObjects[layer][locX][locY]] = tileObjects[layer][locX][locY]
							else
								if normalMap then
									tileObjects[layer][locX][locY] = display.newRect(masterGroup[layer][1], 0, 0, tempScaleX, tempScaleY)
									tileObjects[layer][locX][locY].fill = paint
									tileObjects[layer][locX][locY].fill.effect = "composite.normalMapWith1PointLight"
									tileObjects[layer][locX][locY].normalMap = true
								else
									tileObjects[layer][locX][locY] = display.newImageRect(masterGroup[layer][1], 
										tileSets[tileSetIndex], frameIndex, tempScaleX, tempScaleY
									)
								end
							end
						else
							tileObjects[layer][locX][locY] = {}
							tileObjects[layer][locX][locY].noDraw = true
						end
						tileObjects[layer][locX][locY].properties = tileProps
						listenerCheck = tileObjects[layer][locX][locY]
					else
						if not map.tilesets[tileSetIndex].properties["noDraw"] and not map.layers[layer].properties["noDraw"] then
							if normalMap then
								tileObjects[layer][locX][locY] = display.newRect(masterGroup[layer][1], 0, 0, tempScaleX, tempScaleY)
								tileObjects[layer][locX][locY].fill = paint
								tileObjects[layer][locX][locY].fill.effect = "composite.normalMapWith1PointLight"
								tileObjects[layer][locX][locY].normalMap = true
							else
								--print(layer, locX, locY)
								--print(tileObjects[layer][locX])
								tileObjects[layer][locX][locY] = display.newImageRect(masterGroup[layer][1], 
									tileSets[tileSetIndex], frameIndex, tempScaleX, tempScaleY
								)
							end
						else
							tileObjects[layer][locX][locY] = {}
							tileObjects[layer][locX][locY].noDraw = true
						end
					end
					local rect = tileObjects[layer][locX][locY]
					rect.x = levelPosX + offsetX
					rect.y = levelPosY - offsetY
					--print(masterGroup[1], masterGroup[2], masterGroup[3], masterGroup[4], masterGroup[5], masterGroup[6], masterGroup[7])
					--print(locX, locY, tempScaleX, tempScaleY, rect.x, rect.y, masterGroup[layer].x, masterGroup[layer].y)
					rect.levelPosX = rect.x
					rect.levelPosY = rect.y
					rect.layer = layer
					rect.level = map.layers[layer].properties.level
					rect.locX = locX
					rect.locY = locY
					rect.index = frameIndex
					rect.tileSet = tileSetIndex
					rect.tile = tileStr
					rect.tempScaleX = tempScaleX
					rect.tempScaleY = tempScaleY
					if normalMap and pointLightSource then
						local lightX = pointLightSource.x
						local lightY = pointLightSource.y
						if pointLightSource.pointLight then
							if pointLightSource.pointLight.pointLightPos then
								rect.fill.effect.pointLightPos = {((lightX + pointLightSource.pointLight.pointLightPos[1]) - rect.x + map.tilewidth / 2) / map.tilewidth, 
									((lightY + pointLightSource.pointLight.pointLightPos[2]) - rect.y + map.tileheight / 2) / map.tileheight, 
									pointLightSource.pointLight.pointLightPos[3]
								}
							else
								rect.fill.effect.pointLightPos = {(lightX - rect.x + map.tilewidth / 2) / map.tilewidth, 
									(lightY - rect.y + map.tileheight / 2) / map.tileheight, 
									0.1
								}
							end
							if pointLightSource.pointLight.pointLightColor then
								rect.fill.effect.pointLightColor = pointLightSource.pointLight.pointLightColor
							end
							if pointLightSource.pointLight.ambientLightIntensity then
								rect.fill.effect.ambientLightIntensity = pointLightSource.pointLight.ambientLightIntensity
							end
							if pointLightSource.pointLight.attenuationFactors then
								rect.fill.effect.attenuationFactors = pointLightSource.pointLight.attenuationFactors
							end 
						else
							rect.fill.effect.pointLightPos = {(lightX - rect.x + map.tilewidth / 2) / map.tilewidth, 
								(lightY - rect.y + map.tileheight / 2) / map.tileheight, 
								0.1
							}
						end
					end
					if parameters.owner then
						rect.owner = parameters.owner
					end
					
					if not rect.noDraw then
						totalRects[layer] = totalRects[layer] + 1
						
						if map.orientation == 1 then
							if M.isoSort == 1 then
								masterGroup[layer][locX + locY - 1][1]:insert(tileObjects[layer][locX][locY])
							elseif M.isoSort == 2 then
								
							end
						end
						
						if tileProps then
							if tileProps["path"] then
								local path = json.decode(tileProps["path"])
								local rectpath = rect.path
								rect.pathToggle = true
								rectpath.x1 = path[1]
								rectpath.y1 = path[2]
								rectpath.x2 = path[3]
								rectpath.y2 = path[4]
								rectpath.x3 = path[5]
								rectpath.y3 = path[6]
								rectpath.x4 = path[7]
								rectpath.y4 = path[8]
							end
							if tileProps["heightMap"] then
								rect.heightMap = json.decode(tileProps["heightMap"])
							end
						end
					
						if M.enableLighting then
							rect.litBy = {}
							local mapLayerFalloff = map.properties.lightLayerFalloff
							local mapLevelFalloff = map.properties.lightLevelFalloff
							local redf, greenf, bluef = map.layers[layer].redLight, map.layers[layer].greenLight, map.layers[layer].blueLight
							if map.perlinLighting then
								redf = redf * map.perlinLighting[locX][locY]
								greenf = greenf * map.perlinLighting[locX][locY]
								bluef = bluef * map.perlinLighting[locX][locY]
							elseif map.layers[layer].perlinLighting then
								redf = redf * map.layers[layer].perlinLighting[locX][locY]
								greenf = greenf * map.layers[layer].perlinLighting[locX][locY]
								bluef = bluef * map.layers[layer].perlinLighting[locX][locY]
							end
							for i = 1, #map.layers, 1 do
								if map.layers[i].lighting[locX][locY] then
									local temp = map.layers[i].lighting[locX][locY]
									for key,value in pairs(temp) do
										local levelDiff = math.abs(M.getLevel(layer) - map.lights[key].level)
										local layerDiff = math.abs(layer - map.lights[key].layer)
						
										local layerFalloff, levelFalloff
										if map.lights[key].layerFalloff then
											layerFalloff = map.lights[key].layerFalloff
										else
											layerFalloff = mapLayerFalloff
										end
						
										if map.lights[key].levelFalloff then
											levelFalloff = map.lights[key].levelFalloff
										else
											levelFalloff = mapLevelFalloff
										end
										local tR = temp[key].light[1] - (levelDiff * levelFalloff[1]) - (layerDiff * layerFalloff[1])
										local tG = temp[key].light[2] - (levelDiff * levelFalloff[2]) - (layerDiff * layerFalloff[2])
										local tB = temp[key].light[3] - (levelDiff * levelFalloff[3]) - (layerDiff * layerFalloff[3])

										if tR > redf then
											redf = tR
										end
										if tG > greenf then
											greenf = tG
										end
										if tB > bluef then
											bluef = tB
										end
						
										rect.litBy[#rect.litBy + 1] = key
									end
								end
							end
							rect:setFillColor(redf, greenf, bluef)
							rect.color = {redf, greenf, bluef}
						else
							local redf, greenf, bluef = map.layers[layer].redLight, map.layers[layer].greenLight, map.layers[layer].blueLight
							if map.perlinLighting then	
								redf = redf * map.perlinLighting[locX][locY]
								greenf = greenf * map.perlinLighting[locX][locY]
								bluef = bluef * map.perlinLighting[locX][locY]
							elseif map.layers[layer].perlinLighting then
								redf = redf * map.layers[layer].perlinLighting[locX][locY]
								greenf = greenf * map.layers[layer].perlinLighting[locX][locY]
								bluef = bluef * map.layers[layer].perlinLighting[locX][locY]
							end
							rect:setFillColor(redf, greenf, bluef)
						end
						
						if enableFlipRotation then
							if map.layers[layer].flipRotation[locX][locY] or map.layers[layer].flipRotation[locX][tostring(locY)] then
								local command
								if map.layers[layer].flipRotation[locX][locY] then
									command = map.layers[layer].flipRotation[locX][locY]
								else
									command = map.layers[layer].flipRotation[locX][tostring(locY)]
									map.layers[layer].flipRotation[locX][locY] = command
									map.layers[layer].flipRotation[locX][tostring(locY)] = nil
								end
								if command == 3 then
									rect.rotation = 270
								elseif command == 5 then
									rect.rotation = 90
								elseif command == 6 then
									rect.rotation = 180
								elseif command == 2 then
									rect.yScale = -1
								elseif command == 4 then
									rect.xScale = -1
								elseif command == 1 then
									rect.rotation = 90
									rect.yScale = -1
								elseif command == 7 then
									rect.rotation = -90
									rect.yScale = -1
								end
							end
						end	
					
						rect.makeSprite = function(self)
							local kind = "imageRect"
							if rect.sync then
								kind = "sprite"
								tempObjects[#tempObjects + 1] = display.newSprite(masterGroup[layer],tileSets[tileSetIndex], 
																tileProps["sequenceData"])
								tempObjects[#tempObjects].xScale = findScaleX(worldScaleX, layer)
								tempObjects[#tempObjects].yScale = findScaleY(worldScaleY, layer)
								tempObjects[#tempObjects].layer = layer
								tempObjects[#tempObjects]:setSequence("null")
								tempObjects[#tempObjects].sync = tileProps["animSync"]
							else
								tempObjects[#tempObjects + 1] = display.newImageRect(masterGroup[layer], 
									tileSets[tileSetIndex], frameIndex, tempScaleX, tempScaleY
								)
							end
							local spriteName = ""..layer..locX..locY
							local setup = {layer = layer, kind = kind, locX = locX, locY = locY, 
								levelWidth = tempScaleX, levelHeight = tempScaleY, 
								offsetX = offsetX, offsetY = offsetY * -1, name = spriteName
							}
							M.addSprite(tempObjects[#tempObjects], setup)
							tempObjects[#tempObjects].width = tempScaleX
							tempObjects[#tempObjects].height = tempScaleY
							if tileObjects[layer][locX][locY].bodyType then
								physics.addBody( tempObjects[#tempObjects], bodyType, {density = density, 
																friction = friction, 
																bounce = bounce,
																radius = radius,
																shape = shape2,
																filter = filter
								})
								if rect.properties and rect.properties.isAwake then
									if rect.properties.isAwake == "true" then
										tempObjects[#tempObjects].isAwake = true
									else
										tempObjects[#tempObjects].isAwake = false
									end
								else
									tempObjects[#tempObjects].isAwake = physicsData.layer[layer].isAwake
								end
								if rect.properties and rect.properties.isBodyActive then
									if rect.properties.isBodyActive == "true" then
										tempObjects[#tempObjects].isBodyActive = true
									else
										tempObjects[#tempObjects].isBodyActive = false
									end
								else
									tempObjects[#tempObjects].isBodyActive = physicsData.layer[layer].isActive
								end
							end
							if tempObjects[#tempObjects].sync then
								tempObjects[#tempObjects]:setSequence("null")
								tempObjects[#tempObjects]:play()
							end
							return tempObjects[#tempObjects]
						end
					
						if enablePhysics[layer] then
							local bodyType, density, friction, bounce, radius, shape2, filter
							bodyType = physicsData.layer[layer].defaultBodyType
							density = physicsData.layer[layer].defaultDensity
							friction = physicsData.layer[layer].defaultFriction
							bounce = physicsData.layer[layer].defaultBounce
							radius = physicsData.layer[layer].defaultRadius
							filter = physicsData.layer[layer].defaultFilter
							
							if map.layers[layer].properties["forceDefaultPhysics"] or tileProps then
								if map.layers[layer].properties["forceDefaultPhysics"] or
								tileProps["physics"] == "true" or 
								tileProps["shapeID"] then
									local tempTileProps = false
									if not tileProps then
										tileProps = {}
										tempTileProps = true
									end
									local scaleFactor = 1
									
									local data = nil
									if tileProps["physicsSource"] then
										if tileProps["physicsSourceScale"] then
											scaleFactor = tonumber(tileProps["physicsSourceScale"])
										end
										local source = tileProps["physicsSource"]:gsub(".lua", "")
										data = require(source).physicsData(scaleFactor)
										bodyType = "dynamic"
									end
									if map.tilesets[tileSetIndex].physicsData then
										if tileProps["shapeID"] then
											data = true
											bodyType = "dynamic"					
										end
									end					
									if tileProps["bodyType"] then
										bodyType = tileProps["bodyType"]
									end
									if not data then
										if tileProps["density"] then
											density = tileProps["density"]
										end
										if tileProps["friction"] then
											friction = tileProps["friction"]
										end
										if tileProps["bounce"] then
											bounce = tileProps["bounce"]
										end
										if tileProps["radius"] then
											radius = tileProps["radius"]
										else
											shape2 = physicsData.layer[layer].defaultShape
										end
										if tileProps["shape"] then
											local shape = tileProps["shape"]
											shape2 = {}
											for key,value in pairs(shape) do
												shape2[key] = value
											end
										end					
										if tileProps["groupIndex"] or 
										tileProps["categoryBits"] or 
										tileProps["maskBits"] then
											filter = {categoryBits = tileProps["categoryBits"],
														maskBits = tileProps["maskBits"],
														groupIndex = tileProps["groupIndex"]
											}
										end
									end					
									if bodyType ~= "static" then
										local kind = "imageRect"
										if rect then
											if rect.sync then
												animatedTiles[rect] = nil
											end
											tempObjects[#tempObjects + 1] = rect
											if tempObjects[#tempObjects].sync then
												kind = "sprite"
											end
											tileObjects[layer][locX][locY] = nil
											totalRects[layer] = totalRects[layer] - 1
										else
											tempObjects[#tempObjects + 1] = display.newImageRect(masterGroup[layer], 
												tileSets[tileSetIndex], frameIndex, tempScaleX, tempScaleY
											)
										end
										local spriteName = ""..layer..locX..locY
										local setup = {layer = layer, kind = kind, locX = locX, locY = locY, 
											levelWidth = tempScaleX, levelHeight = tempScaleY, 
											offsetX = offsetX, offsetY = offsetY * -1, name = spriteName
										}
										if map.layers[layer].properties["noDraw"] or tileProps["offscreenPhysics"] then
											setup.offscreenPhysics = true
										end
										if tileProps["layer"] then
											setup.layer = tonumber(tileProps["layer"])
										end
										M.addSprite(tempObjects[#tempObjects], setup)
										tempObjects[#tempObjects].width = tempScaleX
										tempObjects[#tempObjects].height = tempScaleY
										if data ~= nil then
											if data == true then 
												physics.addBody( tempObjects[#tempObjects], bodyType, map.tilesets[tileSetIndex].physicsData:get(tileProps["shapeID"]) )
											else
												physics.addBody( tempObjects[#tempObjects], bodyType, data:get(tileProps["shapeID"]) )
											end
										else
											physics.addBody( tempObjects[#tempObjects], bodyType, {density = density, 
																			friction = friction, 
																			bounce = bounce,
																			radius = radius,
																			shape = shape2,
																			filter = filter
											})
										end
										map.layers[layer].world[locX][locY] = 0
										if rect.properties and rect.properties.isAwake then
											if rect.properties.isAwake == "true" then
												tempObjects[#tempObjects].isAwake = true
											else
												tempObjects[#tempObjects].isAwake = false
											end
										else
											tempObjects[#tempObjects].isAwake = physicsData.layer[layer].isAwake
										end
										if rect.properties and rect.properties.isBodyActive then
											if rect.properties.isBodyActive == "true" then
												tempObjects[#tempObjects].isBodyActive = true
											else
												tempObjects[#tempObjects].isBodyActive = false
											end
										else
											tempObjects[#tempObjects].isBodyActive = physicsData.layer[layer].isActive
										end
										if tempObjects[#tempObjects].sync then
											tempObjects[#tempObjects]:setSequence("null")
											tempObjects[#tempObjects]:play()
										end
										listenerCheck = tempObjects[#tempObjects]
									else
										rect.width = tempScaleX
										rect.height = tempScaleY
										if data ~= nil then
											if data == true then 
												physics.addBody( rect, bodyType, map.tilesets[tileSetIndex].physicsData:get(tileProps["shapeID"]) )
											else
												physics.addBody( rect, bodyType, data:get(tileProps["shapeID"]) )
											end
										else
											physics.addBody( rect, bodyType, {density = density, 
																				friction = friction, 
																				bounce = bounce,
																				radius = radius,
																				shape = shape2,
																				filter = filter
											})
										end
										rect.physics = true
										if rect.properties and rect.properties.isAwake then
											if rect.properties.isAwake == "true" then
												rect.isAwake = true
											else
												rect.isAwake = false
											end
										else
											rect.isAwake = physicsData.layer[layer].isAwake
										end
										if rect.properties and rect.properties.isBodyActive then
											if rect.properties.isBodyActive == "true" then
												rect.isBodyActive = true
											else
												rect.isBodyActive = false
											end
										else
											rect.isBodyActive = physicsData.layer[layer].isActive
										end
									end
									if tempTileProps then
										tileProps = nil
									end
								end
							end
						end
						----
					end
					
					if listenerCheck then
						for key,value in pairs(propertyListeners) do
							if tileProps[key] then
								local event = { name = key, target = listenerCheck}
								masterGroup:dispatchEvent( event )
							end
						end
					end
					-----------
					
					return isOwner
				end
			end	
		end	
	end
	M.updateTile = updateTile2
	
	local loadTileSet = function(index)
		local tempTileWidth = map.tilesets[index].tilewidth + (map.tilesets[index].spacing)
		local tempTileHeight = map.tilesets[index].tileheight + (map.tilesets[index].spacing)
		map.numFrames[index] = math.floor(map.tilesets[index].imagewidth / tempTileWidth) * math.floor(map.tilesets[index].imageheight / tempTileHeight)
		local options = {width = map.tilesets[index].tilewidth, 
			height = map.tilesets[index].tileheight, 
			numFrames = map.numFrames[index], 
			border = map.tilesets[index].margin,
			sheetContentWidth = map.tilesets[index].imagewidth, 
			sheetContentHeight = map.tilesets[index].imageheight
		}
		local src = nil
		local name = nil
		local tsx = nil
		for key,value in pairs(loadedTileSets) do
			if key == map.tilesets[index].name then
				src = value[1]
				tsx = value[2]
				name = key
			end
		end
		if not src then
			src = map.tilesets[index].image
			tileSets[index] = graphics.newImageSheet(src, options)
			
			if not tileSets[index] then
				--get tileset name with extension
				local srcString = src
				local length = string.len(srcString)
				local codes = {string.byte("/"), string.byte(".")}
				local slashes = {}
				local periods = {}
				for i = 1, length, 1 do
					local test = string.byte(srcString, i)
					if test == codes[1] then
						slashes[#slashes + 1] = i
					elseif test == codes[2] then
						periods[#periods + 1] = i
					end
				end
				local tilesetStringExt
				if #slashes > 0 then
					tilesetStringExt = string.sub(srcString, slashes[#slashes] + 1)
				else
					tilesetStringExt = srcString
				end
				print("Searching for tileset "..tilesetStringExt.."...")
				
				--get tileset name
				local tilesetString
				if periods[#periods] >= length - 6 then
					if #slashes > 0 then
						tilesetString = string.sub(srcString, slashes[#slashes] + 1, periods[#periods] - 1)
					else
						tilesetString = string.sub(srcString, 1, periods[#periods] - 1)
					end
				else
					tilesetString = tilesetStringExt
				end
		
				--get map name with extension
				srcString = source
				length = string.len(srcString)
				slashes = {}
				periods = {}
				for i = 1, length, 1 do
					local test = string.byte(srcString, i)
					if test == codes[1] then
						slashes[#slashes + 1] = i
					elseif test == codes[2] then
						periods[#periods + 1] = i
					end
				end
				local mapStringExt = string.sub(srcString, slashes[#slashes] + 1)
		
				--get map name
				local mapString
				if periods[#periods] >= length - 6 then
					mapString = string.sub(srcString, slashes[#slashes] + 1, periods[#periods] - 1)
				else
					mapString = mapStringExt
				end
		
				local success = 0
				local newSource
				--look in base resource directory
				print("Checking Resource Directory...")
				newSource = tilesetStringExt
				tileSets[index] = graphics.newImageSheet(newSource, options)
				if tileSets[index] then
					success = 1
					print("Found "..tilesetStringExt.." in resource directory.")
				end
				--look in folder = map filename with extension
				if success ~= 1 then
					newSource = mapStringExt.."/"..tilesetStringExt
					print("Checking "..mapStringExt.." folder...")
					tileSets[index] = graphics.newImageSheet(newSource, options)
					if tileSets[index] then
						success = 1
						print("Found "..tilesetStringExt.." in "..newSource)
					end
				end
				--look in folder = map filename
				if success ~= 1 then
					newSource = mapString.."/"..tilesetStringExt
					print("Checking "..mapString.." folder...")
					tileSets[index] = graphics.newImageSheet(newSource, options)
					if tileSets[index] then
						success = 1
						print("Found "..tilesetStringExt.." in "..newSource)
					end
				end
				--look in folder = tileset name with extension
				if success ~= 1 then
					newSource = tilesetStringExt.."/"..tilesetStringExt
					print("Checking "..tilesetStringExt.." folder...")
					tileSets[index] = graphics.newImageSheet(newSource, options)
					if tileSets[index] then
						success = 1
						print("Found "..tilesetStringExt.." in "..newSource)
					end
				end
				--look in folder = tileset name
				if success ~= 1 then
					newSource = tilesetString.."/"..tilesetStringExt
					print("Checking "..tilesetString.." folder...")
					tileSets[index] = graphics.newImageSheet(newSource, options)
					if tileSets[index] then
						success = 1
						print("Found "..tilesetStringExt.." in "..newSource)
					end
				end
				if success ~= 1 then
					print("Could not find "..tilesetStringExt)
					print("Use mte.getTilesetNames() and mte.loadTileset(name) to load tilesets programmatically.")
				end
				print(" ")
			end
		else
			tileSets[index] = graphics.newImageSheet(src, options)
			if not tileSets[index] then
				loadedTileSets[name][2] = "FILE NOT FOUND"
			end
			
			if tsx then
				--LOAD TILESET TSX and APPLY VALUES TO MAP.TILESETS
				local temp = xml.loadFile(tsx)
				for i = 1, #temp.child, 1 do
					for key,value in pairs(temp.child[i]) do
						if temp.child[i].properties.id then
							if not map.tilesets[index].tileproperties then
								map.tilesets[index].tileproperties = {}
							end
							if not map.tilesets[index].tileproperties[temp.child[i].properties.id] then
								map.tilesets[index].tileproperties[temp.child[i].properties.id] = {}
							end
							map.tilesets[index].tileproperties[temp.child[i].properties.id][temp.child[i].child[1].child[1].properties.name] = temp.child[i].child[1].child[1].properties.value
						end
					end
				end
			end
		end
	end
	
	local loadTileSetExt = function(name, source, dataSource)
		local path = system.pathForFile(source, system.ResourcesDirectory)
		path = nil
		loadedTileSets[name] = {source, dataSource}
		if map.tilesets then
			for i = 1, #map.tilesets, 1 do
				if name == map.tilesets[i].name then
					loadTileSet(i)
				end
			end
		end
	end
	M.loadTileSet = loadTileSetExt
	
	local getTileSetNames = function(arg)
		local array = {}
		for i = 1, #map.tilesets, 1 do
			array[#array + 1] = map.tilesets[i].name
		end
		return array
	end
	M.getTileSetNames = getTileSetNames
	
	local detectSpriteLayers = function()
		local layers = {}
		for i = 1, #map.layers, 1 do
			if map.layers[i].properties and map.layers[i].properties.spriteLayer then
				layers[#layers + 1] = i
				spriteLayers[#spriteLayers + 1] = i
			end
		end
		if #layers == 0 then
			print("WARNING(detectSpriteLayers): No Sprite Layers Found. Defaulting to all map layers.")
			for i = 1, #map.layers, 1 do
				layers[#layers + 1] = i
				spriteLayers[#spriteLayers + 1] = i
				map.layers[i].properties.spriteLayer = "true"
			end
		end
		return layers
	end
	M.detectSpriteLayers = detectSpriteLayers
	
	local detectObjectLayers = function()
		local layers = {}
		for i = 1, #map.layers, 1 do
			if map.layers[i].properties.objectLayer then
				layers[#layers + 1] = i
				objectLayers[#objectLayers + 1] = i
			end
		end
		if #layers == 0 then
			print("WARNING(detectObjectLayers): No Object Layers Found.")
			layers = nil
		end
		return layers
	end
	M.detectObjectLayers = detectObjectLayers
	
	local drawObject = function(object, i, ky)
		local lineColor = {0, 0, 0, 0}
		local lineWidth = 0
		local fillColor = {0, 0, 0, 0}
		local layer = i
		
		--[[
if map.layers[layer].properties then
	for key,value in pairs(map.layers[layer].properties) do
		if not object.properties[key] then
			object.properties[key] = value
		end
	end
end
		]]--
		
		
		if object.properties.layer then
			layer = tonumber(object.properties.layer)
		end
		local spriteName
		if object.properties.lineColor then
			lineColor = json.decode(object.properties.lineColor)
			lineWidth = 1
			if not lineColor[4] then
				lineColor[4] = 1
			end
		end
		if object.properties.lineWidth then
			lineWidth = tonumber(object.properties.lineWidth)
		end
		if object.properties.fillColor then
			fillColor = json.decode(object.properties.fillColor)
			if not fillColor[4] then
				fillColor[4] = 1
			end
		end

		local bodyType, density, friction, bounce, radius, shape2, folter
		if enablePhysics[i] then
			bodyType = physicsData.layer[i].defaultBodyType
			density = physicsData.layer[i].defaultDensity
			friction = physicsData.layer[i].defaultFriction
			bounce = physicsData.layer[i].defaultBounce
			radius = physicsData.layer[i].defaultRadius
			shape2 = physicsData.layer[i].defaultShape
			filter = physicsData.layer[i].defaultFilter
			if object.properties.bodyType then
				bodyType = object.properties.bodyType
			end
			if object.properties.density then
				density = object.properties.density
			end
			if object.properties.friction then
				friction = object.properties.friction
			end
			if object.properties.bounce then
				bounce = object.properties.bounce
			end
			if object.properties.radius then
				radius = object.properties.radius
			end
			if object.properties.shape and object.properties.shape ~= "auto" then
				shape = object.properties.shape
				shape2 = {}
				for key,value in pairs(shape) do
					shape2[key] = value
				end
			end
			if object.properties.groupIndex or 
			object.properties.categoryBits or 
			object.properties.maskBits then
				filter = {categoryBits = object.properties.categoryBits,
							maskBits = object.properties.maskBits,
							groupIndex = object.properties.groupIndex
				}
			end
		end
		local listenerCheck = false
		if object.gid then	
			if map.orientation == 1 then
				listenerCheck = true							
				local frameIndex = object.gid
				local tempScaleX = map.tilewidth * map.layers[i].properties.scaleX
				local tempScaleY = map.tileheight * map.layers[i].properties.scaleY
				local tileSetIndex = 1
				for i = 1, #map.tilesets, 1 do
					if frameIndex >= map.tilesets[i].firstgid then
						tileSetIndex = i
					else
						break
					end
				end
				local levelWidth = map.tilesets[tileSetIndex].tilewidth / M.isoScaleMod
				if object.properties.levelWidth then
					levelWidth = object.properties.levelWidth / M.isoScaleMod
				end
				local levelHeight = map.tilesets[tileSetIndex].tileheight / M.isoScaleMod
				if object.properties.levelHeight then
					levelHeight = object.properties.levelHeight / M.isoScaleMod
				end			
				frameIndex = frameIndex - (map.tilesets[tileSetIndex].firstgid - 1)		
				spriteName = object.name
				if not spriteName or spriteName == "" then
					spriteName = ""..object.x.."_"..object.y.."_"..i
				end
				if sprites[spriteName] then
					local tempName = spriteName
					local counter = 1
					while sprites[tempName] do
						tempName = ""..spriteName..counter
						counter = counter + 1
					end
					spriteName = tempName
				end
				sprites[spriteName] = display.newImageRect(masterGroup[i], 
					tileSets[tileSetIndex], frameIndex, tempScaleX, tempScaleY
				)
				local setup = {layer = layer, kind = "imageRect", levelPosX = object.x - (worldScaleX * 0.5), levelPosY = object.y - (worldScaleX * 0.5), 
					levelWidth = levelWidth, levelHeight = levelHeight, offsetX = 0, offsetY = 0, name = spriteName
				}
				if enablePhysics[i] then
					if object.properties.physics == "true" and object.properties.offscreenPhysics then
						setup.offscreenPhysics = true
					end
				end
				M.addSprite(sprites[spriteName], setup)			
				local polygon = {{x = 0, y = 0},
								 {x = levelWidth * M.isoScaleMod, y = 0},
								 {x = levelWidth * M.isoScaleMod, y = levelHeight * M.isoScaleMod},
								 {x = 0, y = levelHeight * M.isoScaleMod}
				}
				local polygon2 = {}
				for i = 1, #polygon, 1 do
					--Convert world coordinates to isometric screen coordinates
					--find x,y distances from center
					local xDelta = polygon[i].x
					local yDelta = polygon[i].y
					local finalX, finalY
					if xDelta == 0 and yDelta == 0 then
						finalX = polygon[i].x 
						finalY = polygon[i].y
					else	
						--find angle
						local angle = math.atan(xDelta/yDelta)
						local length = xDelta / math.sin(angle)
						if xDelta == 0 then
							length = yDelta
						elseif yDelta == 0 then
							length = xDelta
						end
						angle = angle - R45
						
						--find new deltas
						local xDelta2 = length * math.sin(angle)
						local yDelta2 = length * math.cos(angle)

						finalX = xDelta2 / 1
						finalY = yDelta2 / map.isoRatio
					end
				
					polygon2[i] = {}
					polygon2[i].x = finalX
					polygon2[i].y = finalY 
				end
				local minX = 999999
				local maxX = -999999
				local minY = 999999
				local maxY = -999999
				for i = 1, #polygon2, 1 do
					if polygon2[i].x > maxX then
						maxX = polygon2[i].x
					end
					if polygon2[i].x < minX then
						minX = polygon2[i].x
					end
					if polygon2[i].y > maxY then
						maxY = polygon2[i].y
					end
					if polygon2[i].y < minY then
						minY = polygon2[i].y
					end
				end
				width = math.abs(maxX - minX)
				height = math.abs(maxY - minY)				
				if enablePhysics[i] then
					if object.properties.physics == "true" then
						if not object.properties.shape or object.properties.shape == "auto" then
							local bodies = {}									
							local function det(x1,y1, x2,y2)
								return x1*y2 - y1*x2
							end
							local function ccw(p, q, r)
								return det(q.x-p.x, q.y-p.y,  r.x-p.x, r.y-p.y) >= 0
							end		
							local function areCollinear(p, q, r, eps)
								return math.abs(det(q.x-p.x, q.y-p.y,  r.x-p.x,r.y-p.y)) <= (eps or 1e-32)
							end
							local triangles = {} -- list of triangles to be returned
							local concave = {}   -- list of concave edges
							local adj = {}       -- vertex adjacencies
							local vertices = polygon2 	
							-- retrieve adjacencies as the rest will be easier to implement
							for i,p in ipairs(vertices) do
								local l = (i == 1) and vertices[#vertices] or vertices[i-1]
								local r = (i == #vertices) and vertices[1] or vertices[i+1]
								adj[p] = {p = p, l = l, r = r} -- point, left and right neighbor
								-- test if vertex is a concave edge
								if not ccw(l,p,r) then concave[p] = p end
							end
							local function onSameSide(a,b, c,d)
								local px, py = d.x-c.x, d.y-c.y
								local l = det(px,py,  a.x-c.x, a.y-c.y)
								local m = det(px,py,  b.x-c.x, b.y-c.y)
								return l*m >= 0
							end
							local function pointInTriangle(p, a,b,c)
								return onSameSide(p,a, b,c) and onSameSide(p,b, a,c) and onSameSide(p,c, a,b)
							end
							-- and ear is an edge of the polygon that contains no other
							-- vertex of the polygon
							local function isEar(p1,p2,p3)
								if not ccw(p1,p2,p3) then return false end
								for q,_ in pairs(concave) do
									if q ~= p1 and q ~= p2 and q ~= p3 and pointInTriangle(q, p1,p2,p3) then
										return false
									end
								end
								return true
							end
							-- main loop
							local nPoints, skipped = #vertices, 0
							local p = adj[ vertices[2] ]
							while nPoints > 3 do
								if not concave[p.p] and isEar(p.l, p.p, p.r) then
									-- polygon may be a 'collinear triangle', i.e.
									-- all three points are on a line. In that case
									-- the polygon constructor throws an error.
									if not areCollinear(p.l, p.p, p.r) then
										triangles[#triangles+1] = {p.l.x,p.l.y, p.p.x,p.p.y, p.r.x,p.r.y}
										bodies[#bodies + 1] = {density = density, 
															friction = friction, 
															bounce = bounce, 
															shape = {p.l.x, p.l.y, 
																	p.p.x, p.p.y, 
																	p.r.x, p.r.y
															},
															filter = filter
										}
										skipped = 0
									end
									if concave[p.l] and ccw(adj[p.l].l, p.l, p.r) then
										concave[p.l] = nil
									end
									if concave[p.r] and ccw(p.l, p.r, adj[p.r].r) then
										concave[p.r] = nil
									end
									-- remove point from list
									adj[p.p] = nil
									adj[p.l].r = p.r
									adj[p.r].l = p.l
									nPoints = nPoints - 1
									skipped = 0
									p = adj[p.l]
								else
									p = adj[p.r]
									skipped = skipped + 1
									assert(skipped <= nPoints, "Cannot triangulate polygon (is the polygon intersecting itself?)")
								end
							end
							if not areCollinear(p.l, p.p, p.r) then
								triangles[#triangles+1] = {p.l.x,p.l.y, p.p.x,p.p.y, p.r.x,p.r.y}
								bodies[#bodies + 1] = {density = density, 
													friction = friction, 
													bounce = bounce, 
													shape = {p.l.x, p.l.y, 
															p.p.x, p.p.y, 
															p.r.x, p.r.y
													},
													filter = filter
								}
							end
							physics.addBody(sprites[spriteName], bodyType, unpack(bodies))
						else
							physics.addBody(sprites[spriteName], bodyType, {density = density, 
															friction = friction, 
															bounce = bounce,
															radius = radius,
															shape = shape2,
															filter = filter
							})
						end
						if object.properties.isAwake then 
							if object.properties.isAwake == "true" then
								sprites[spriteName].isAwake = true
							else
								sprites[spriteName].isAwake = false
							end
						else
							sprites[spriteName].isAwake = physicsData.layer[i].isAwake
						end
						if object.properties.isBodyActive then
							if object.properties.isBodyActive == "true" then
								sprites[spriteName].isBodyActive = true
							else
								sprites[spriteName].isBodyActive = false
							end
						else
							sprites[spriteName].isBodyActive = physicsData.layer[i].isActive
						end
					end
				end
			else
				listenerCheck = true							
				local frameIndex = object.gid
				local tileSetIndex = 1
				for i = 1, #map.tilesets, 1 do
					if frameIndex >= map.tilesets[i].firstgid then
						tileSetIndex = i
					else
						break
					end
				end
				local levelWidth = map.tilesets[tileSetIndex].tilewidth
				if object.properties.levelWidth then
					levelWidth = object.properties.levelWidth
				end
				local levelHeight = map.tilesets[tileSetIndex].tileheight
				if object.properties.levelHeight then
					levelHeight = object.properties.levelHeight
				end		
				frameIndex = frameIndex - (map.tilesets[tileSetIndex].firstgid - 1)	
				spriteName = object.name
				if not spriteName or spriteName == "" then
					spriteName = ""..object.x.."_"..object.y.."_"..i
				end
				if sprites[spriteName] then
					local tempName = spriteName
					local counter = 1
					while sprites[tempName] do
						tempName = ""..spriteName..counter
						counter = counter + 1
					end
					spriteName = tempName
				end
				sprites[spriteName] = display.newImageRect(masterGroup[i], tileSets[tileSetIndex], frameIndex, map.tilewidth, map.tileheight)
				
				local centerX = object.x + (levelWidth * 0.5)
				local centerY = object.y - (levelHeight * 0.5)
				
				if not object.rotation then
					object.rotation = 0
				end
				
				local width = map.tilewidth / 2
				local height = map.tileheight / 2
				
				local hyp = (height) / math.sin(math.rad(45))
				
				local deltaX = hyp * math.sin(math.rad(45 + tonumber(object.rotation)))
				local deltaY = hyp * math.cos(math.rad(45 + tonumber(object.rotation))) * -1
				
				centerX = object.x + deltaX
				centerY = object.y + deltaY
				
				sprites[spriteName].rotation = tonumber(object.rotation)
				--[[
				local setup = {layer = layer, kind = "imageRect", levelPosX = object.x + (levelWidth * 0.5), levelPosY = object.y - (levelHeight * 0.5), 
					levelWidth = levelWidth, levelHeight = levelHeight, offsetX = 0, offsetY = 0, name = spriteName
				}
				]]--
				local setup = {layer = layer, kind = "imageRect", levelPosX = centerX, levelPosY = centerY, 
					levelWidth = levelWidth, levelHeight = levelHeight, offsetX = 0, offsetY = 0, name = spriteName
				}
				if enablePhysics[i] then
					if object.properties.physics == "true" and object.properties.offscreenPhysics then
						setup.offscreenPhysics = true
					end
				end
				M.addSprite(sprites[spriteName], setup)
				local maxX, minX, maxY, minY = levelWidth / 2, levelWidth / -2, levelHeight / 2, levelHeight / -2
				local centerX = (maxX - minX) / 2 + minX
				local centerY = (maxY - minY) / 2 + minY
				sprites[spriteName].bounds = {math.ceil(centerX / map.tilewidth), 
											math.ceil(centerY / map.tileheight), 
											math.ceil(minX / map.tilewidth), 
											math.ceil(minY / map.tileheight), 
											math.ceil(maxX / map.tilewidth), 
											math.ceil(maxY / map.tileheight)}
				
				if enablePhysics[i] then
					if object.properties.physics == "true" then
						if not object.properties.shape or object.properties.shape == "auto" then
							local w = levelWidth
							local h = levelHeight
							shape2 = {0 - (levelWidth / 2), 0 - (levelHeight / 2), 
										w - (levelWidth / 2), 0 - (levelHeight / 2), 
										w - (levelWidth / 2), h - (levelHeight / 2), 
										0 - (levelWidth / 2), h - (levelHeight / 2)}
						end
						physics.addBody(sprites[spriteName], bodyType, {density = density, friction = friction, bounce = bounce,
														radius = radius, shape = shape2, filter = filter})
						if object.properties.isAwake then
							if object.properties.isAwake == "true" then
								sprites[spriteName].isAwake = true
							else
								sprites[spriteName].isAwake = false
							end
						else
							sprites[spriteName].isAwake = physicsData.layer[i].isAwake
						end
						if object.properties.isBodyActive then
							if object.properties.isBodyActive == "true" then
								sprites[spriteName].isBodyActive = true
							else
								sprites[spriteName].isBodyActive = false
							end
						else
							sprites[spriteName].isBodyActive = physicsData.layer[i].isActive
						end
						--sprites[spriteName].isBodyActive = physicsData.layer[i].isActive
					end
				end
				

				
			end
		elseif object.ellipse then
			listenerCheck = true	
			local width = object.width
			local height = object.height
			spriteName = object.name
			if not spriteName or spriteName == "" then
				spriteName = ""..object.x.."_"..object.y.."_"..i
			end
			if sprites[spriteName] then
				local tempName = spriteName
				local counter = 1
				while sprites[tempName] do
					tempName = ""..spriteName..counter
					counter = counter + 1
				end
				spriteName = tempName
			end
			local startX = object.x
			local startY = object.y
			sprites[spriteName] = display.newGroup()
			masterGroup[i]:insert(sprites[spriteName])
			sprites[spriteName].x = startX
			sprites[spriteName].y = startY
			if map.orientation == 1 then
				local totalWidth = width
				local totalWidth = height
				local segments
				if width == height then
					segments = 7
				elseif width > height then
					segments = 7
				else
					segments = 8
				end
				local bodies = {}
				local a = width / 2
				local b = height / 2
				local length = width / segments
				local subLength = length / 3
				local startX = a * -1
				local polygons = {}
				local minX = 999999
				local maxX = -999999
				local minY = 999999
				local maxY = -999999
				local finalShape1 = {}
				local finalShape2 = {}
				local counter2 = 0
				for bx = 1, segments, 1 do
					local shape = {}
					for x = startX, startX + length, subLength do
						local y = math.sqrt( ((a*a)*(b*b) - (b*b)*(x*x)) / (a*a) )
						shape[#shape + 1] = x + (a)
						shape[#shape + 1] = y * -1 + (b)
						if #finalShape1 > 0 then
							if finalShape1[#finalShape1].x ~= x + (a) and finalShape1[#finalShape1].y ~= y * -1 + (b) then
								finalShape1[#finalShape1 + 1] = {x = x + (a), y = y * -1 + (b)}
							end
						else
							finalShape1[#finalShape1 + 1] = {x = x + (a), y = y * -1 + (b)}
						end
					end
					for x = startX + length, startX, subLength * -1 do
						local y = math.sqrt( ((a*a)*(b*b) - (b*b)*(x*x)) / (a*a) )
						shape[#shape + 1] = x + (a)
						shape[#shape + 1] = y + 0.1 + (b)
					end
					local polygon2 = {}
					local shape2 = {}
					for i = 2, #shape, 2 do
						--Convert world coordinates to isometric screen coordinates
						--find x,y distances from center
						local xDelta = shape[i - 1]--shape[i].x
						local yDelta = shape[i]--shape[i].y
						local finalX, finalY
						if xDelta == 0 and yDelta == 0 then
							finalX = shape[i - 1]--shape[i].x 
							finalY = shape[i]--shape[i].y
						else	
							--find angle
							local angle = math.atan(xDelta/yDelta)
							local length = xDelta / math.sin(angle)
							if xDelta == 0 then
								length = yDelta
							elseif yDelta == 0 then
								length = xDelta
							end
							angle = angle - R45

							--find new deltas
							local xDelta2 = length * math.sin(angle)
							local yDelta2 = length * math.cos(angle)

							finalX = xDelta2 / 1
							finalY = yDelta2 / map.isoRatio
						end
					
						shape2[i - 1] = finalX 
						shape2[i] = finalY + map.tilewidth / (4 * (M.isoScaleMod))
					
						polygon2[i / 2] = {}
						polygon2[i / 2].x = finalX
						polygon2[i / 2].y = finalY + map.tilewidth / (4 * (M.isoScaleMod))
					end				
					if enablePhysics[i] then
						bodies[#bodies + 1] = {density = density, 
												friction = friction, 
												bounce = bounce, 
												shape = shape2,
												filter = filter
						}
					end				
					startX = startX + length				
					for i = 1, #polygon2, 1 do
						if polygon2[i].x > maxX then
							maxX = polygon2[i].x
						end
						if polygon2[i].x < minX then
							minX = polygon2[i].x
						end
						if polygon2[i].y > maxY then
							maxY = polygon2[i].y
						end
						if polygon2[i].y < minY then
							minY = polygon2[i].y
						end
					end						
				end			
				local finalShape3 = {}
				local finalShape4 = {}
				for i = 1, #finalShape1, 1 do
					--Convert world coordinates to isometric screen coordinates
					--find x,y distances from center
					local xDelta = finalShape1[i].x
					local yDelta = finalShape1[i].y
					local finalX, finalY
					if xDelta == 0 and yDelta == 0 then
						finalX = finalShape1[i].x 
						finalY = finalShape1[i].y
					else	
						--find angle
						local angle = math.atan(xDelta/yDelta)
						local length = xDelta / math.sin(angle)
						if xDelta == 0 then
							length = yDelta
						elseif yDelta == 0 then
							length = xDelta
						end
						angle = angle - R45

						--find new deltas
						local xDelta2 = length * math.sin(angle)
						local yDelta2 = length * math.cos(angle)

						finalX = xDelta2 / 1
						finalY = yDelta2 / map.isoRatio
					end
				
					finalShape3[i] = {}
					finalShape3[i].x = finalX
					finalShape3[i].y = finalY + map.tilewidth / (4 * (M.isoScaleMod))
				end
				for i = 1, #finalShape1, 1 do
					local xDelta = finalShape1[i].x
					local yDelta = finalShape1[i].y * -1 + (object.height )
					local finalX, finalY
					if xDelta == 0 and yDelta == 0 then
						finalX = finalShape1[i].x
						finalY = finalShape1[i].y * -1 + (object.height )
					else	
						--find angle
						local angle = math.atan(xDelta/yDelta)
						local length = xDelta / math.sin(angle)
						if xDelta == 0 then
							length = yDelta
						elseif yDelta == 0 then
							length = xDelta
						end
						angle = angle - R45

						--find new deltas
						local xDelta2 = length * math.sin(angle)
						local yDelta2 = length * math.cos(angle)

						finalX = xDelta2 / 1
						finalY = yDelta2 / map.isoRatio
					end
				
					finalShape4[i] = {}
					finalShape4[i].x = finalX
					finalShape4[i].y = finalY + map.tilewidth / (4 * (M.isoScaleMod))
				end
				for i = 1, #finalShape3, 1 do
					local startX = finalShape3[i].x
					local startY = finalShape3[i].y
				
					local n = i + 1
					if n <= #finalShape3 then
						local endX = finalShape3[n].x
						local endY = finalShape3[n].y

						if i == 1 then
							display.newLine(sprites[spriteName], startX, startY, endX, endY)
						else
							sprites[spriteName][sprites[spriteName].numChildren]:append(endX, endY)
						end
						sprites[spriteName][sprites[spriteName].numChildren]:setStrokeColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
						sprites[spriteName][sprites[spriteName].numChildren].color = {lineColor[1], lineColor[2], lineColor[3], lineColor[4]}
						--sprites[spriteName][sprites[spriteName].numChildren].lighting = false
						sprites[spriteName][sprites[spriteName].numChildren].strokeWidth = lineWidth
					end
				end
				for i = #finalShape4, 1, -1 do
					local startX = finalShape4[i].x
					local startY = finalShape4[i].y
				
					local n = i - 1
					if n >= 1 then
						local endX = finalShape4[n].x
						local endY = finalShape4[n].y		

						sprites[spriteName][sprites[spriteName].numChildren]:append(endX, endY)
						sprites[spriteName][sprites[spriteName].numChildren]:setStrokeColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
						sprites[spriteName][sprites[spriteName].numChildren].color = {lineColor[1], lineColor[2], lineColor[3], lineColor[4]}
						--sprites[spriteName][sprites[spriteName].numChildren].lighting = false
						sprites[spriteName][sprites[spriteName].numChildren].strokeWidth = lineWidth
					end
				end
				local levelPosX = object.x
				local levelPosY = object.y
				local offsetX = 0
				local offsetY = 0
				if map.orientation == 1 then
					offsetY = 0 - (worldScaleX * 0.5 * M.isoScaleMod)
				end
				local setup = {layer = layer, kind = "vector", levelPosX = levelPosX, levelPosY = levelPosY, 
					levelWidth = width, levelHeight = height, sourceWidth = width, sourceHeight = height, offsetX = offsetX, offsetY = offsetY, name = spriteName
				}
				if enablePhysics[i] then
					if object.properties.physics == "true" and object.properties.offscreenPhysics then
						setup.offscreenPhysics = true
					end
				end
				sprites[spriteName].lighting = false
				M.addSprite(sprites[spriteName], setup)
				if enablePhysics[i] then
					physics.addBody(sprites[spriteName], bodyType, unpack(bodies))
				end
			else
				if width == height then
					--perfect circle
					display.newCircle(sprites[spriteName], 0, 0, width / 2)
					if object.properties.lineWidth then
						sprites[spriteName][sprites[spriteName].numChildren].strokeWidth = object.properties.lineWidth
					end
					if object.properties.lineColor then
						sprites[spriteName][sprites[spriteName].numChildren]:setStrokeColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
						sprites[spriteName][sprites[spriteName].numChildren].color = {lineColor[1], lineColor[2], lineColor[3], lineColor[4]}
					end
					if object.properties.fillColor then
						sprites[spriteName][sprites[spriteName].numChildren]:setFillColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4])
						--sprites[spriteName][sprites[spriteName].numChildren].color = {fillColor[1], fillColor[2], fillColor[3], fillColor[4]}
					else
						sprites[spriteName][sprites[spriteName].numChildren]:setFillColor(0, 0, 0, 0)
					end
					if object.rotation then
						sprites[spriteName].rotation = tonumber(object.rotation)
					end
					local setup = {layer = layer, kind = "vector", levelPosX = object.x + width / 2, levelPosY = object.y + height / 2, 
						levelWidth = width, levelHeight = height, sourceWidth = width, sourceHeight = height, offsetX = 0, offsetY = 0, name = spriteName
					}
					if enablePhysics[i] then
						if object.properties.physics == "true" and object.properties.offscreenPhysics then
							setup.offscreenPhysics = true
						end
					end
					sprites[spriteName].lighting = false
					M.addSprite(sprites[spriteName], setup)
					local maxX, minX, maxY, minY = width / 2, width / -2, height / 2, height / -2
					local centerX = (maxX - minX) / 2 + minX
					local centerY = (maxY - minY) / 2 + minY
					sprites[spriteName].bounds = {math.ceil(centerX / map.tilewidth), 
												math.ceil(centerY / map.tileheight), 
												math.ceil(minX / map.tilewidth), 
												math.ceil(minY / map.tileheight), 
												math.ceil(maxX / map.tilewidth), 
												math.ceil(maxY / map.tileheight)}
					if enablePhysics[i] then
						if object.properties.physics == "true" then
							if not object.properties.shape or object.properties.shape == "auto" then
								shape2 = nil
								radius = width / 2
							end
							physics.addBody(sprites[spriteName], bodyType, {density = density, friction = friction, bounce = bounce,
															radius = radius, shape = shape2, filter = filter})
							
							if object.properties.isAwake then
								if object.properties.isAwake == "true" then
									sprites[spriteName].isAwake = true
								else
									sprites[spriteName].isAwake = false
								end
							else
								sprites[spriteName].isAwake = physicsData.layer[i].isAwake
							end
							--sprites[spriteName].isAwake = physicsData.layer[i].isAwake
							if object.properties.isBodyActive then
								if object.properties.isBodyActive == "true" then
									sprites[spriteName].isBodyActive = true
								else
									sprites[spriteName].isBodyActive = false
								end
							else
								sprites[spriteName].isBodyActive = physicsData.layer[i].isActive
							end
							--sprites[spriteName].isBodyActive = physicsData.layer[i].isActive
						end
					end
				else
					--ellipse
					local tempC
					if width < height then
						tempC = width
					else
						tempC = height
					end
					display.newCircle(sprites[spriteName], tempC / 2, tempC / 2, tempC / 2)
					if object.properties.lineWidth then
						sprites[spriteName][sprites[spriteName].numChildren].strokeWidth = object.properties.lineWidth
					end
					if object.properties.lineColor then
						sprites[spriteName][sprites[spriteName].numChildren]:setStrokeColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
						sprites[spriteName][sprites[spriteName].numChildren].color = {lineColor[1], lineColor[2], lineColor[3], lineColor[4]}
					end
					if object.properties.fillColor then
						sprites[spriteName][sprites[spriteName].numChildren]:setFillColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4])
						--sprites[spriteName][sprites[spriteName].numChildren].color = {fillColor[1], fillColor[2], fillColor[3], fillColor[4]}
					else
						sprites[spriteName][sprites[spriteName].numChildren]:setFillColor(0, 0, 0, 0)
					end
					
					if object.rotation then
						sprites[spriteName].rotation = tonumber(object.rotation)
					end

					local setup = {layer = layer, kind = "vector", levelPosX = object.x, levelPosY = object.y, 
						levelWidth = width, levelHeight = height, sourceWidth = tempC, sourceHeight = tempC, offsetX = 0, offsetY = 0, name = spriteName
					}
					if enablePhysics[i] then
						if object.properties.physics == "true" and object.properties.offscreenPhysics then
							setup.offscreenPhysics = true
						end
					end
					sprites[spriteName].lighting = false
					M.addSprite(sprites[spriteName], setup)
					local minX = 0
					local maxX = width
					local minY = 0
					local maxY = height
					if maxX < minX then
						local temp = maxX
						maxX = minX
						minX = temp
					end
					if maxY < minY then
						local temp = maxY
						maxY = minY
						minY = temp
					end
					local centerX = (maxX - minX) / 2 + minX
					local centerY = (maxY - minY) / 2 + minY
					sprites[spriteName].bounds = {math.ceil(centerX / map.tilewidth), 
												math.ceil(centerY / map.tileheight), 
												math.ceil(minX / map.tilewidth), 
												math.ceil(minY / map.tileheight), 
												math.ceil(maxX / map.tilewidth), 
												math.ceil(maxY / map.tileheight)}
					if enablePhysics[i] then
						if object.properties.physics == "true" then
							local segments = 5
							if object.properties.physicsBodies then
								segments = tonumber(object.properties.physicsBodies)
							end
							if not object.properties.shape or object.properties.shape == "auto" then
								local bodies = {}
								local a = width / 2
								local b = height / 2
								local length = width / segments
								local subLength = length / 3
								local startX = a * -1
								for bx = 1, segments, 1 do
									local shape = {}
									for x = startX, startX + length, subLength do
										local y = math.sqrt( ((a*a)*(b*b) - (b*b)*(x*x)) / (a*a) )
										shape[#shape + 1] = x + (a)
										shape[#shape + 1] = y * -1 + (b)
									end
									for x = startX + length, startX, subLength * -1 do
										local y = math.sqrt( ((a*a)*(b*b) - (b*b)*(x*x)) / (a*a) )
										shape[#shape + 1] = x + (a)
										shape[#shape + 1] = y + 0.1 + (b)
									end
									bodies[#bodies + 1] = {density = density, 
															friction = friction, 
															bounce = bounce, 
															shape = shape,
															filter = filter
									}
									startX = startX + length
								end
								physics.addBody(sprites[spriteName], bodyType, unpack(bodies))
							else
								physics.addBody(sprites[spriteName], bodyType, {density = density, friction = friction, bounce = bounce,
																radius = radius, shape = shape2, filter = filter})
							end
							if object.properties.isAwake then
								if object.properties.isAwake == "true" then
									sprites[spriteName].isAwake = true
								else
									sprites[spriteName].isAwake = false
								end
							else
								sprites[spriteName].isAwake = physicsData.layer[i].isAwake
							end
							--sprites[spriteName].isAwake = physicsData.layer[i].isAwake
							if object.properties.isBodyActive then
								if object.properties.isBodyActive == "true" then
									sprites[spriteName].isBodyActive = true
								else
									sprites[spriteName].isBodyActive = false
								end
							else
								sprites[spriteName].isBodyActive = physicsData.layer[i].isActive
							end
							--sprites[spriteName].isBodyActive = physicsData.layer[i].isActive
						end
					end
					--------
				end
			end
		elseif object.polygon then
			listenerCheck = true	
			local polygon = object.polygon
			spriteName = object.name
			if not spriteName or spriteName == "" then
				spriteName = ""..object.x.."_"..object.y.."_"..i
			end
			if sprites[spriteName] then
				local tempName = spriteName
				local counter = 1
				while sprites[tempName] do
					tempName = ""..spriteName..counter
					counter = counter + 1
				end
				spriteName = tempName
			end
			local startX = object.x
			local startY = object.y
			sprites[spriteName] = display.newGroup()
			masterGroup[i]:insert(sprites[spriteName])
			sprites[spriteName].x = startX
			sprites[spriteName].y = startY			
			local polygon2 = {}
			for i = 1, #polygon, 1 do
				if map.orientation == 1 then
					polygon[i].x = polygon[i].x - (worldScaleX * 0.5)
					polygon[i].y = polygon[i].y - (worldScaleX * 0.5)
				
					--Convert world coordinates to isometric screen coordinates
					--find x,y distances from center
					local xDelta = polygon[i].x
					local yDelta = polygon[i].y
					local finalX, finalY
					if xDelta == 0 and yDelta == 0 then
						finalX = polygon[i].x 
						finalY = polygon[i].y
					else	
						--find angle
						local angle = math.atan(xDelta/yDelta)
						local length = xDelta / math.sin(angle)
						if xDelta == 0 then
							length = yDelta
						elseif yDelta == 0 then
							length = xDelta
						end
						angle = angle - R45

						--find new deltas
						local xDelta2 = length * math.sin(angle)
						local yDelta2 = length * math.cos(angle)
	
						finalX = xDelta2 / 1
						finalY = yDelta2 / map.isoRatio
					end
				
					polygon2[i] = {}
					polygon2[i].x = finalX
					polygon2[i].y = finalY + map.tilewidth / (4 * (M.isoScaleMod))
				else
					polygon2[i] = {}
					polygon2[i].x = polygon[i].x
					polygon2[i].y = polygon[i].y
				end
			end
			for i = 1, #polygon2, 1 do
				local startX = polygon2[i].x
				local startY = polygon2[i].y			
			
				local n = i + 1
				if n > #polygon2 then
					n = 1
				end
			
				local endX = polygon2[n].x
				local endY = polygon2[n].y			
				
				if i == 1 then
					display.newLine(sprites[spriteName], startX, startY, endX, endY)
				else
					sprites[spriteName][sprites[spriteName].numChildren]:append(endX, endY)
				end
			end		
			local minX = 999999
			local maxX = -999999
			local minY = 999999
			local maxY = -999999
			for i = 1, #polygon2, 1 do
				if polygon2[i].x > maxX then
					maxX = polygon2[i].x
				end
				if polygon2[i].x < minX then
					minX = polygon2[i].x
				end
				if polygon2[i].y > maxY then
					maxY = polygon2[i].y
				end
				if polygon2[i].y < minY then
					minY = polygon2[i].y
				end
			end
			local width = math.abs(maxX - minX)
			local height = math.abs(maxY - minY)
			sprites[spriteName][sprites[spriteName].numChildren]:setStrokeColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
			sprites[spriteName][sprites[spriteName].numChildren].color = {lineColor[1], lineColor[2], lineColor[3], lineColor[4]}
			sprites[spriteName][sprites[spriteName].numChildren].strokeWidth = lineWidth
			local levelPosX = object.x
			local levelPosY = object.y
			if map.orientation == 1 then
				levelPosX = levelPosX + (worldScaleX * 0.5)
				levelPosY = levelPosY + (worldScaleX * 0.5)
			else
				if object.rotation then
					sprites[spriteName].rotation = tonumber(object.rotation)
				end
			end
			local setup = {layer = layer, kind = "vector", levelPosX = levelPosX, levelPosY = levelPosY, 
				levelWidth = width, levelHeight = height, sourceWidth = width, sourceHeight = height, offsetX = 0, offsetY = 0, name = spriteName
			}
			if enablePhysics[i] then
				if object.properties.physics == "true" and object.properties.offscreenPhysics then
					setup.offscreenPhysics = true
				end
			end
			sprites[spriteName].lighting = false
			M.addSprite(sprites[spriteName], setup)
			local centerX = (maxX - minX) / 2 + minX
			local centerY = (maxY - minY) / 2 + minY
			sprites[spriteName].bounds = {math.ceil(centerX / map.tilewidth), 
										math.ceil(centerY / map.tileheight), 
										math.ceil(minX / map.tilewidth), 
										math.ceil(minY / map.tileheight), 
										math.ceil(maxX / map.tilewidth), 
										math.ceil(maxY / map.tileheight)}
			if enablePhysics[i] then
				if object.properties.physics == "true" then
					if not object.properties.shape or object.properties.shape == "auto" then
						local bodies = {}			
						local function det(x1,y1, x2,y2)
							return x1*y2 - y1*x2
						end
						local function ccw(p, q, r)
							return det(q.x-p.x, q.y-p.y,  r.x-p.x, r.y-p.y) >= 0
						end			
						local function areCollinear(p, q, r, eps)
							return math.abs(det(q.x-p.x, q.y-p.y,  r.x-p.x,r.y-p.y)) <= (eps or 1e-32)
						end
						local triangles = {} -- list of triangles to be returned
						local concave = {}   -- list of concave edges
						local adj = {}       -- vertex adjacencies
						local vertices = polygon2
						-- retrieve adjacencies as the rest will be easier to implement
						for i,p in ipairs(vertices) do
							local l = (i == 1) and vertices[#vertices] or vertices[i-1]
							local r = (i == #vertices) and vertices[1] or vertices[i+1]
							adj[p] = {p = p, l = l, r = r} -- point, left and right neighbor
							-- test if vertex is a concave edge
							if not ccw(l,p,r) then concave[p] = p end
						end				
						local function onSameSide(a,b, c,d)
							local px, py = d.x-c.x, d.y-c.y
							local l = det(px,py,  a.x-c.x, a.y-c.y)
							local m = det(px,py,  b.x-c.x, b.y-c.y)
							return l*m >= 0
						end
						local function pointInTriangle(p, a,b,c)
							return onSameSide(p,a, b,c) and onSameSide(p,b, a,c) and onSameSide(p,c, a,b)
						end				
						-- and ear is an edge of the polygon that contains no other
						-- vertex of the polygon
						local function isEar(p1,p2,p3)
							if not ccw(p1,p2,p3) then return false end
							for q,_ in pairs(concave) do
								if q ~= p1 and q ~= p2 and q ~= p3 and pointInTriangle(q, p1,p2,p3) then
								--if q ~= p1 and q ~= p2 and q ~= p3 then
									return false
								end
							end
							return true
						end
						-- main loop
						local nPoints, skipped = #vertices, 0
						local p = adj[ vertices[2] ]
						while nPoints > 3 do
							if not concave[p.p] and isEar(p.l, p.p, p.r) then
								-- polygon may be a 'collinear triangle', i.e.
								-- all three points are on a line. In that case
								-- the polygon constructor throws an error.
								if not areCollinear(p.l, p.p, p.r) then
									triangles[#triangles+1] = {p.l.x,p.l.y, p.p.x,p.p.y, p.r.x,p.r.y}
									bodies[#bodies + 1] = {density = density, 
														friction = friction, 
														bounce = bounce, 
														shape = {p.l.x, p.l.y, 
																p.p.x, p.p.y, 
																p.r.x, p.r.y
														},
														filter = filter
									}
									skipped = 0
								end
								if concave[p.l] and ccw(adj[p.l].l, p.l, p.r) then
									concave[p.l] = nil
								end
								if concave[p.r] and ccw(p.l, p.r, adj[p.r].r) then
									concave[p.r] = nil
								end
								-- remove point from list
								adj[p.p] = nil
								adj[p.l].r = p.r
								adj[p.r].l = p.l
								nPoints = nPoints - 1
								skipped = 0
								p = adj[p.l]
							else
								p = adj[p.r]
								skipped = skipped + 1
								assert(skipped <= nPoints, "Cannot triangulate polygon (is the polygon intersecting itself?)")
							end
						end
						if not areCollinear(p.l, p.p, p.r) then
							triangles[#triangles+1] = {p.l.x,p.l.y, p.p.x,p.p.y, p.r.x,p.r.y}
							bodies[#bodies + 1] = {density = density, 
												friction = friction, 
												bounce = bounce, 
												shape = {p.l.x, p.l.y, 
														p.p.x, p.p.y, 
														p.r.x, p.r.y
												},
												filter = filter
							}
						end
						physics.addBody(sprites[spriteName], bodyType, unpack(bodies))
					else
						physics.addBody(sprites[spriteName], bodyType, {density = density, friction = friction, bounce = bounce,
														radius = radius, shape = shape2, filter = filter})
					end
					if object.properties.isAwake then
						if object.properties.isAwake == "true" then
							sprites[spriteName].isAwake = true
						else
							sprites[spriteName].isAwake = false
						end
					else
						sprites[spriteName].isAwake = physicsData.layer[i].isAwake
					end
					--sprites[spriteName].isAwake = physicsData.layer[i].isAwake
					if object.properties.isBodyActive then
						if object.properties.isBodyActive == "true" then
							sprites[spriteName].isBodyActive = true
						else
							sprites[spriteName].isBodyActive = false
						end
					else
						sprites[spriteName].isBodyActive = physicsData.layer[i].isActive
					end
					--sprites[spriteName].isBodyActive = physicsData.layer[i].isActive
				end
			end	
		elseif object.polyline then
			listenerCheck = true	
			local polyline = object.polyline
			spriteName = object.name
			if not spriteName or spriteName == "" then
				spriteName = ""..object.x.."_"..object.y.."_"..i
			end
			if sprites[spriteName] then
				local tempName = spriteName
				local counter = 1
				while sprites[tempName] do
					tempName = ""..spriteName..counter
					counter = counter + 1
				end
				spriteName = tempName
			end
			local startX = object.x
			local startY = object.y
			sprites[spriteName] = display.newGroup()
			masterGroup[i]:insert(sprites[spriteName])
			sprites[spriteName].x = startX
			sprites[spriteName].y = startY		
			local polyline2 = {}
			for i = 1, #polyline, 1 do
				if map.orientation == 1 then
					polyline[i].x = polyline[i].x - (worldScaleX * 0.5)
					polyline[i].y = polyline[i].y - (worldScaleX * 0.5)
				
					--Convert world coordinates to isometric screen coordinates
					--find x,y distances from center
					local xDelta = polyline[i].x
					local yDelta = polyline[i].y
					local finalX, finalY
					if xDelta == 0 and yDelta == 0 then
						finalX = polyline[i].x 
						finalY = polyline[i].y
					else	
						--find angle
						local angle = math.atan(xDelta/yDelta)
						local length = xDelta / math.sin(angle)
						if xDelta == 0 then
							length = yDelta
						elseif yDelta == 0 then
							length = xDelta
						end
						angle = angle - R45

						--find new deltas
						local xDelta2 = length * math.sin(angle)
						local yDelta2 = length * math.cos(angle)
	
						finalX = xDelta2 / 1
						finalY = yDelta2 / map.isoRatio
					end
				
					polyline2[i] = {}
					polyline2[i].x = finalX
					polyline2[i].y = finalY + map.tilewidth / (4 * (M.isoScaleMod))
				else
					polyline2[i] = {}
					polyline2[i].x = polyline[i].x
					polyline2[i].y = polyline[i].y
				end
			end
			local minX = 999999
			local maxX = -999999
			local minY = 999999
			local maxY = -999999
			for i = 1, #polyline2, 1 do
				if polyline2[i].x > maxX then
					maxX = polyline2[i].x
				end
				if polyline2[i].x < minX then
					minX = polyline2[i].x
				end
				if polyline2[i].y > maxY then
					maxY = polyline2[i].y
				end
				if polyline2[i].y < minY then
					minY = polyline2[i].y
				end
			end
			local width = math.abs(maxX - minX)
			local height = math.abs(maxY - minY)
			local hW = lineWidth / 2
			local bodies = {}
			for i = 1, #polyline2, 1 do
				local startX = polyline2[i].x
				local startY = polyline2[i].y
			
				local n = i + 1
				if n > #polyline2 then
					break
				end
			
				local endX = polyline2[n].x
				local endY = polyline2[n].y
			
				if i == 1 then
					display.newLine(sprites[spriteName], startX, startY, endX, endY)
				else
					sprites[spriteName][sprites[spriteName].numChildren]:append(endX, endY)
				end
			
				local theta = math.atan((startY - endY)/(endX - startX))
				local offX = (math.sin(theta) * hW)
				local offY = (math.cos(theta) * hW)
				local x1 = (startX - offX)
				local y1 = (startY - offY)
				local x2 = (endX - offX)
				local y2 = (endY - offY)
				local x3 = (endX + offX)
				local y3 = (endY + offY)
				local x4 = (startX + offX)
				local y4 = (startY + offY)
				if enablePhysics[layer] then
					bodies[#bodies + 1] = {density = density, friction = friction, bounce = bounce, 
						shape = {x1, y1, x2, y2, x3, y3, x4, y4},filter = filter
					}
				end
			end
			sprites[spriteName][sprites[spriteName].numChildren]:setStrokeColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
			sprites[spriteName][sprites[spriteName].numChildren].color = {lineColor[1], lineColor[2], lineColor[3], lineColor[4]}
			sprites[spriteName][sprites[spriteName].numChildren].strokeWidth = lineWidth
			local levelPosX = object.x
			local levelPosY = object.y
			
			if map.orientation == 1 then
				levelPosX = levelPosX + (worldScaleX * 0.5)
				levelPosY = levelPosY + (worldScaleX * 0.5)
			else
				if object.rotation then
					sprites[spriteName].rotation = tonumber(object.rotation)
				end
			end
				
			local setup = {layer = layer, kind = "vector", levelPosX = levelPosX, levelPosY = levelPosY, 
				levelWidth = width, levelHeight = height, sourceWidth = width, sourceHeight = height, offsetX = 0, offsetY = 0, name = spriteName
			}
			if enablePhysics[i] then
				if object.properties.physics == "true" and object.properties.offscreenPhysics then
					setup.offscreenPhysics = true
				end
			end
			sprites[spriteName].lighting = false
			M.addSprite(sprites[spriteName], setup)
			local centerX = (maxX - minX) / 2 + minX
			local centerY = (maxY - minY) / 2 + minY
			sprites[spriteName].bounds = {math.ceil(centerX / map.tilewidth), 
										math.ceil(centerY / map.tileheight), 
										math.ceil(minX / map.tilewidth), 
										math.ceil(minY / map.tileheight), 
										math.ceil(maxX / map.tilewidth), 
										math.ceil(maxY / map.tileheight)}
			if enablePhysics[i] then
				if object.properties.physics == "true" then
					if not object.properties.shape or object.properties.shape == "auto" then
						physics.addBody(sprites[spriteName], bodyType, unpack(bodies))
					else
						physics.addBody(sprites[spriteName], bodyType, {density = density, friction = friction, bounce = bounce,
							radius = radius, shape = shape2, filter = filter
						})
					end
					if object.properties.isAwake then
						if object.properties.isAwake == "true" then
							sprites[spriteName].isAwake = true
						else
							sprites[spriteName].isAwake = false
						end
					else
						sprites[spriteName].isAwake = physicsData.layer[i].isAwake
					end
					--sprites[spriteName].isAwake = physicsData.layer[i].isAwake
					if object.properties.isBodyActive then
						if object.properties.isBodyActive == "true" then
							sprites[spriteName].isBodyActive = true
						else
							sprites[spriteName].isBodyActive = false
						end
					else
						sprites[spriteName].isBodyActive = physicsData.layer[i].isActive
					end
					--sprites[spriteName].isBodyActive = physicsData.layer[i].isActive
				end
			end
		else --rectangle
			listenerCheck = true
			local width = object.width
			local height = object.height
			local startX = object.x
			local startY = object.y
			spriteName = object.name
			if not spriteName or spriteName == "" then
				spriteName = ""..object.x.."_"..object.y.."_"..i
			end
			if sprites[spriteName] then
				local tempName = spriteName
				local counter = 1
				while sprites[tempName] do
					tempName = ""..spriteName..counter
					counter = counter + 1
				end
				spriteName = tempName
			end
			sprites[spriteName] = display.newGroup()
			masterGroup[i]:insert(sprites[spriteName])
			sprites[spriteName].x = startX
			sprites[spriteName].y = startY
			local polygon2 = {}
			if map.orientation == 1 then
				local polygon = {{x = 0 - (worldScaleX * 0.5), y = 0 - (worldScaleX * 0.5)},
								 {x = width - (worldScaleX * 0.5), y = 0 - (worldScaleX * 0.5)},
								 {x = width - (worldScaleX * 0.5), y = height - (worldScaleX * 0.5)},
								 {x = 0 - (worldScaleX * 0.5), y = height - (worldScaleX * 0.5)}
				}
				for i = 1, #polygon, 1 do
					--Convert world coordinates to isometric screen coordinates
					--find x,y distances from center
					local xDelta = polygon[i].x
					local yDelta = polygon[i].y
					local finalX, finalY
					if xDelta == 0 and yDelta == 0 then
						finalX = polygon[i].x 
						finalY = polygon[i].y
					else	
						--find angle
						local angle = math.atan(xDelta/yDelta)
						local length = xDelta / math.sin(angle)
						if xDelta == 0 then
							length = yDelta
						elseif yDelta == 0 then
							length = xDelta
						end
						angle = angle - R45

						--find new deltas
						local xDelta2 = length * math.sin(angle)
						local yDelta2 = length * math.cos(angle)

						finalX = xDelta2 / 1
						finalY = yDelta2 / map.isoRatio
					end
			
					polygon2[i] = {}
					polygon2[i].x = finalX
					polygon2[i].y = finalY + map.tilewidth / (4 * (M.isoScaleMod))
				end
				for i = 1, #polygon2, 1 do
					local startX = polygon2[i].x
					local startY = polygon2[i].y			
			
					local n = i + 1
					if n > #polygon2 then
						n = 1
					end
					
					local endX = polygon2[n].x
					local endY = polygon2[n].y			
					
					if i == 1 then
						display.newLine(sprites[spriteName], startX, startY, endX, endY)
					else
						sprites[spriteName][sprites[spriteName].numChildren]:append(endX, endY)
					end
				end
				local minX = 999999
				local maxX = -999999
				local minY = 999999
				local maxY = -999999
				for i = 1, #polygon2, 1 do
					if polygon2[i].x > maxX then
						maxX = polygon2[i].x
					end
					if polygon2[i].x < minX then
						minX = polygon2[i].x
					end
					if polygon2[i].y > maxY then
						maxY = polygon2[i].y
					end
					if polygon2[i].y < minY then
						minY = polygon2[i].y
					end
				end
				width = math.abs(maxX - minX)
				height = math.abs(maxY - minY)
				sprites[spriteName][sprites[spriteName].numChildren]:setStrokeColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
				sprites[spriteName][sprites[spriteName].numChildren].color = {lineColor[1], lineColor[2], lineColor[3], lineColor[4]}
				sprites[spriteName][sprites[spriteName].numChildren].strokeWidth = lineWidth
			else
				display.newRect(sprites[spriteName], width * 0.5, height * 0.5, width, height)
				if object.properties.lineWidth then
					sprites[spriteName][sprites[spriteName].numChildren].strokeWidth = object.properties.lineWidth
				end
				if object.properties.lineColor then
					sprites[spriteName][sprites[spriteName].numChildren]:setStrokeColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
					sprites[spriteName][sprites[spriteName].numChildren].color = {lineColor[1], lineColor[2], lineColor[3], lineColor[4]}
				end
				if object.properties.fillColor then
					sprites[spriteName][sprites[spriteName].numChildren]:setFillColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4])
				else
					sprites[spriteName][sprites[spriteName].numChildren]:setFillColor(0, 0, 0, 0)
				end
			end
			local levelPosX = object.x
			local levelPosY = object.y
			if map.orientation == 1 then
				levelPosX = levelPosX + (worldScaleX * 0.5)
				levelPosY = levelPosY + (worldScaleX * 0.5)
			else
				if object.rotation then
					sprites[spriteName].rotation = tonumber(object.rotation)
				end
			end
			local setup = {layer = layer, kind = "vector", levelPosX = levelPosX, levelPosY = levelPosY, 
				levelWidth = width, levelHeight = height, sourceWidth = width, sourceHeight = height, offsetX = 0, offsetY = 0, name = spriteName
			}
			if enablePhysics[i] then
				if object.properties.physics == "true" and object.properties.offscreenPhysics then
					setup.offscreenPhysics = true
				end
			end
			sprites[spriteName].lighting = false
			M.addSprite(sprites[spriteName], setup)
			local minX = 0
			local maxX = width
			local minY = 0
			local maxY = height
			if maxX < minX then
				local temp = maxX
				maxX = minX
				minX = temp
			end
			if maxY < minY then
				local temp = maxY
				maxY = minY
				minY = temp
			end
			local centerX = (maxX - minX) / 2 + minX
			local centerY = (maxY - minY) / 2 + minY
			sprites[spriteName].bounds = {math.ceil(centerX / map.tilewidth), 
										math.ceil(centerY / map.tileheight), 
										math.ceil(minX / map.tilewidth), 
										math.ceil(minY / map.tileheight), 
										math.ceil(maxX / map.tilewidth), 
										math.ceil(maxY / map.tileheight)}
			if enablePhysics[i] then
				if object.properties.physics == "true" then
					if map.orientation == 1 then
						if not object.properties.shape or object.properties.shape == "auto" then
							local bodies = {}			
							local function det(x1,y1, x2,y2)
								return x1*y2 - y1*x2
							end
							local function ccw(p, q, r)
								return det(q.x-p.x, q.y-p.y,  r.x-p.x, r.y-p.y) >= 0
							end
							local function areCollinear(p, q, r, eps)
								return math.abs(det(q.x-p.x, q.y-p.y,  r.x-p.x,r.y-p.y)) <= (eps or 1e-32)
							end
							local triangles = {} -- list of triangles to be returned
							local concave = {}   -- list of concave edges
							local adj = {}       -- vertex adjacencies
							local vertices = polygon2				
							-- retrieve adjacencies as the rest will be easier to implement
							for i,p in ipairs(vertices) do
								local l = (i == 1) and vertices[#vertices] or vertices[i-1]
								local r = (i == #vertices) and vertices[1] or vertices[i+1]
								adj[p] = {p = p, l = l, r = r} -- point, left and right neighbor
								-- test if vertex is a concave edge
								if not ccw(l,p,r) then concave[p] = p end
							end				
							local function onSameSide(a,b, c,d)
								local px, py = d.x-c.x, d.y-c.y
								local l = det(px,py,  a.x-c.x, a.y-c.y)
								local m = det(px,py,  b.x-c.x, b.y-c.y)
								return l*m >= 0
							end
							local function pointInTriangle(p, a,b,c)
								return onSameSide(p,a, b,c) and onSameSide(p,b, a,c) and onSameSide(p,c, a,b)
							end				
							-- and ear is an edge of the polygon that contains no other
							-- vertex of the polygon
							local function isEar(p1,p2,p3)
								if not ccw(p1,p2,p3) then return false end
								for q,_ in pairs(concave) do
									if q ~= p1 and q ~= p2 and q ~= p3 and pointInTriangle(q, p1,p2,p3) then
										return false
									end
								end
								return true
							end
							-- main loop
							local nPoints, skipped = #vertices, 0
							local p = adj[ vertices[2] ]
							while nPoints > 3 do
								if not concave[p.p] and isEar(p.l, p.p, p.r) then
									-- polygon may be a 'collinear triangle', i.e.
									-- all three points are on a line. In that case
									-- the polygon constructor throws an error.
									if not areCollinear(p.l, p.p, p.r) then
										triangles[#triangles+1] = {p.l.x,p.l.y, p.p.x,p.p.y, p.r.x,p.r.y}
										bodies[#bodies + 1] = {density = density, 
															friction = friction, 
															bounce = bounce, 
															shape = {p.l.x, p.l.y, 
																	p.p.x, p.p.y, 
																	p.r.x, p.r.y
															},
															filter = filter
										}
										skipped = 0
									end
									if concave[p.l] and ccw(adj[p.l].l, p.l, p.r) then
										concave[p.l] = nil
									end
									if concave[p.r] and ccw(p.l, p.r, adj[p.r].r) then
										concave[p.r] = nil
									end
									-- remove point from list
									adj[p.p] = nil
									adj[p.l].r = p.r
									adj[p.r].l = p.l
									nPoints = nPoints - 1
									skipped = 0
									p = adj[p.l]
								else
									p = adj[p.r]
									skipped = skipped + 1
									assert(skipped <= nPoints, "Cannot triangulate polygon (is the polygon intersecting itself?)")
								end
							end

							if not areCollinear(p.l, p.p, p.r) then
								triangles[#triangles+1] = {p.l.x,p.l.y, p.p.x,p.p.y, p.r.x,p.r.y}
								bodies[#bodies + 1] = {density = density, friction = friction, bounce = bounce, 
									shape = {p.l.x, p.l.y, p.p.x, p.p.y, p.r.x, p.r.y}, filter = filter
								}
							end							
							physics.addBody(sprites[spriteName], bodyType, unpack(bodies))
						else
							physics.addBody(sprites[spriteName], bodyType, {density = density, friction = friction, bounce = bounce,
								radius = radius, shape = shape2, filter = filter
							})
						end
						if object.properties.isAwake then
							if object.properties.isAwake == "true" then
								sprites[spriteName].isAwake = true
							else
								sprites[spriteName].isAwake = false
							end
						else
							sprites[spriteName].isAwake = physicsData.layer[i].isAwake
						end
						--sprites[spriteName].isAwake = physicsData.layer[i].isAwake
						if object.properties.isBodyActive then
							if object.properties.isBodyActive == "true" then
								sprites[spriteName].isBodyActive = true
							else
								sprites[spriteName].isBodyActive = false
							end
						else
							sprites[spriteName].isBodyActive = physicsData.layer[i].isActive
						end
						--sprites[spriteName].isBodyActive = physicsData.layer[i].isActive
					else
						if not object.properties.shape or object.properties.shape == "auto" then
							local w = width
							local h = height
							shape2 = {0, 0, w, 0, w, h, 0, h}
						end
						physics.addBody(sprites[spriteName], bodyType, {density = density, friction = friction, bounce = bounce,
							radius = radius, shape = shape2, filter = filter
						})
						if object.properties.isAwake then
							if object.properties.isAwake == "true" then
								sprites[spriteName].isAwake = true
							else
								sprites[spriteName].isAwake = false
							end
						else
							sprites[spriteName].isAwake = physicsData.layer[i].isAwake
						end
						--sprites[spriteName].isAwake = physicsData.layer[i].isAwake
						if object.properties.isBodyActive then
							if object.properties.isBodyActive == "true" then
								sprites[spriteName].isBodyActive = true
							else
								sprites[spriteName].isBodyActive = false
							end
						else
							sprites[spriteName].isBodyActive = physicsData.layer[i].isActive
						end
						--sprites[spriteName].isBodyActive = physicsData.layer[i].isActive
					end
				end
			end
		end
		
		if listenerCheck then
			sprites[spriteName].drawnObject = true
			sprites[spriteName].objectKey = ky
			sprites[spriteName].objectLayer = layer
			sprites[spriteName].bounds = nil
			sprites[spriteName].properties = object.properties
			sprites[spriteName].type = object.type
			object.properties.wasDrawn = true
			
			if M.enableLighting then
				if object.properties.lightSource then
					light = {source = json.decode(object.properties.lightSource),
							range = json.decode(object.properties.lightRange),
							falloff = json.decode(object.properties.lightFalloff)}
					if object.properties.lightArc then
						light.arc = json.decode(object.properties.lightArc)
					end
					if object.properties.lightRays then
						light.rays = json.decode(object.properties.lightRays)
					end
					if object.properties.lightLayerFalloff then
						light.layerFalloff = json.decode(object.properties.lightLayerFalloff)
					end
					if object.properties.lightLayerFalloff then
						light.levelFalloff = json.decode(object.properties.lightLevelFalloff)
					end
					if object.properties.lightLayer then
						light.layer = tonumber(object.properties.lightLayer)
					end
				
					tempObjects[#tempObjects].addLight(light)
				end
			end
			for key,value in pairs(objectDrawListeners) do
				if object.name == key or key == "*" then
					local event = { name = key, target = sprites[spriteName], object = object}
					masterGroup:dispatchEvent( event )
				end
			end
			
			return sprites[spriteName]
		end
	end
	
	local drawCulledObjects = function(locX, locY, layer)
		if map.layers[layer].extendedObjects then
			if locX < 1 - map.locOffsetX then
				locX = locX + map.layers[layer].width
			end
			if locX > map.layers[layer].width - map.locOffsetX then
				locX = locX - map.layers[layer].width
			end				
			
			if locY < 1 - map.locOffsetY then
				locY = locY + map.layers[layer].height
			end
			if locY > map.layers[layer].height - map.locOffsetY then
				locY = locY - map.layers[layer].height
			end
			
			if map.layers[layer].extendedObjects[locX] and map.layers[layer].extendedObjects[locX][locY] then
				for i = #map.layers[layer].extendedObjects[locX][locY], 1, -1 do
					if map.layers[layer].extendedObjects[locX][locY][i] then
						local objectLayer = map.layers[layer].extendedObjects[locX][locY][i][1]
						local objectKey =  map.layers[layer].extendedObjects[locX][locY][i][2]
						local object = map.layers[objectLayer].objects[objectKey]
						if not object.properties.wasDrawn then
							local sprite = drawObject(object, objectLayer, objectKey)
							sprite.x = object.cullData[1]
							sprite.y = object.cullData[2]
							sprite.width = object.cullData[3]
							sprite.height = object.cullData[4]
							sprite.roation = object.cullData[5]
						
							for j = #object.cullData[6], 1, -1 do
								local lx = object.cullData[6][j][1]
								local ly = object.cullData[6][j][2]
								local index = object.cullData[6][j][3]
								map.layers[objectLayer].extendedObjects[lx][ly][index] = nil
							end
						end
						map.layers[layer].extendedObjects[locX][locY][i] = nil
					end
				end
			end
		end
	end
	
	M.redrawObject = function(name)
		local layer = nil
		local key = nil	
		
		if sprites[name] and sprites[name].drawnObject then
			key = sprites[name].objectKey
			layer = sprites[name].objectLayer
			removeSprite(sprites[name])
		end
		
		local objects = map.layers[layer].objects
		return drawObject(objects[key], layer)	
	end
	
	M.drawObject = function(name)
		--find object
		for i = 1, #map.layers, 1 do
			if map.layers[i].objects then
				local objects = map.layers[i].objects
				for key,value in pairs(objects) do
					if objects[key].name == name then
						if objects[key].gid or (objects[key].properties and 
						(objects[key].properties.physics or objects[key].properties.lineColor or objects[key].properties.fillColor or objects[key].properties.lineWidth)) then
							return drawObject(objects[key], i, key)
						end
					end
				end
			end
		end
	end
	
	M.drawObjects = function(new)
		local table = {}
		for i = 1, #map.layers, 1 do
			if map.layers[i].objects then
				local objects = map.layers[i].objects
				for key,value in pairs(objects) do
					if objects[key].gid or (objects[key].properties and 
					(objects[key].properties.physics or objects[key].properties.lineColor or objects[key].properties.fillColor or objects[key].properties.lineWidth)) then
						if not objects[key].properties or ((new and not objects[key].properties.wasDrawn) or not new) then
							table[#table + 1] = drawObject(objects[key], i, key)
						end
					end
					--[[
					if new then
						if not objects[key].properties then
							if objects[key].gid or (objects[key].properties and 
							(objects[key].properties.physics or objects[key].properties.lineColor or objects[key].properties.fillColor or objects[key].properties.lineWidth)) then
								table[#table + 1] = drawObject(objects[key], i, key)
							end
						elseif not objects[key].properties.wasDrawn then
							if objects[key].gid or (objects[key].properties and 
							(objects[key].properties.physics or objects[key].properties.lineColor or objects[key].properties.fillColor or objects[key].properties.lineWidth)) then
								table[#table + 1] = drawObject(objects[key], i, key)
							end
						end
					else
						if objects[key].gid or (objects[key].properties and 
						(objects[key].properties.physics or objects[key].properties.lineColor or objects[key].properties.fillColor or objects[key].properties.lineWidth)) then
							table[#table + 1] = drawObject(objects[key], i, key)
						end
					end
					]]--
				end
			end
		end
		return table
	end
	
	M.preloadMap = function(src, dir)
		local startTime=system.getTimer()
		local storageToggle = false
		local srcString = src
		local directory = ""
		local length = string.len(srcString)
		local codes = {string.byte("/"), string.byte(".")}
		local slashes = {}
		local periods = {}
		for i = 1, length, 1 do
			local test = string.byte(srcString, i)
			if test == codes[1] then
				slashes[#slashes + 1] = i
			elseif test == codes[2] then
				periods[#periods + 1] = i
			end
		end
		if #slashes > 0 then
			srcStringExt = string.sub(srcString, slashes[#slashes] + 1)
			directory = string.sub(srcString, 1, slashes[#slashes])
		else
			srcStringExt = srcString
		end
		if #periods > 0 then
			if periods[#periods] >= length - 6 then
				srcString = string.sub(srcString, (slashes[#slashes] or 0) + 1, (periods[#periods] or 0) - 1)
			else
				srcString = srcStringExt
			end
		else
			srcString = srcStringExt
		end
		local detectJsonExt = string.find(srcStringExt, ".json")
		if string.len(srcStringExt) ~= string.len(srcString) then
			if not detectJsonExt then
				--print("ERROR: "..src.." is not a Json file.")
			end
		else
			src = src..".json"
			detectJsonExt = true
		end	
		local path
		local base
		if dir == "Documents" then
			path = system.pathForFile(src, system.DocumentsDirectory)
			base = system.DocumentsDirectory
		elseif dir == "Temporary" then
			path = system.pathForFile(src, system.TemporaryDirectory)
			base = system.TemporaryDirectory
		elseif not dir or dir == "Resource" then
			path = system.pathForFile(src, system.ResourceDirectory)	
			base = system.ResourceDirectory
		end
		
		if detectJsonExt then
			local saveData = io.open(path, "r")
			if saveData then
				local jsonData = saveData:read("*a")
		
				if not mapStorage[src] then
					mapStorage[src] = json.decode(jsonData)
					print(src.." preloaded")
				else
					storageToggle = true
					print(src.." already in storage")
				end
				
				io.close(saveData)
			else
				print("ERROR: Map Not Found")
			end
		else
			if not mapStorage[src] then
				mapStorage[src] = {}
				------------------------------------------------------------------------------
				xml.ParseXmlText = function(xmlText)
					if not mapStorage[src] then
						mapStorage[src] = {}
					end
					local layerIndex = 0
				
					local stack = {}
					local top = {name=nil,value=nil,properties={},child={}}
					table.insert(stack, top)
					local ni,c,label,xarg, empty
					local i, j = 1, 1
					local triggerBase64 = false
					local triggerXML = false
					local triggerCSV = false
					local x, y = 1, 1
					while true do
						local ni,j,c,label,xarg, empty = string.find(xmlText, "<(%/?)([%w:]+)(.-)(%/?)>", i)
						if not ni then break end
						local text = string.sub(xmlText, i, ni-1);
						if not string.find(text, "^%s*$") then
							top.value=(top.value or "")..xml.FromXmlString(text);
							if triggerBase64 then
								triggerBase64 = false
								--decode base64 directly into map array
								--------------------------------------------------------------
								local floor = math.floor
								local buffer = 0
								local pos = 1
								local bin ={}
								local mult = 1
								for i = 1,40 do
									bin[i] = mult
									mult = mult*2
								end
								local base64 = { ['A']=0,['B']=1,['C']=2,['D']=3,['E']=4,['F']=5,['G']=6,['H']=7,['I']=8,
												 ['J']=9,['K']=10,['L']=11,['M']=12,['N']=13,['O']=14,['P']=15,['Q']=16,
												 ['R']=17,['S']=18,['T']=19,['U']=20,['V']=21,['W']=22,['X']=23,['Y']=24,
												 ['Z']=25,['a']=26,['b']=27,['c']=28,['d']=29,['e']=30,['f']=31,['g']=32,
												 ['h']=33,['i']=34,['j']=35,['k']=36,['l']=37,['m']=38,['n']=39,['o']=40,
												 ['p']=41,['q']=42,['r']=43,['s']=44,['t']=45,['u']=46,['v']=47,['w']=48,
												 ['x']=49,['y']=50,['z']=51,['0']=52,['1']=53,['2']=54,['3']=55,['4']=56,
												 ['5']=57,['6']=58,['7']=59,['8']=60,['9']=61,['+']=62,['/']=63,['=']=nil
								}
								local set = "[^%a%d%+%/%=]"
								data = string.gsub(top.value, set, "")    
								local size = 32
								local val = {}
								local rawPos = 1
								local rawSize = #top.value
								local char = ""

								while rawPos <= rawSize do
									while pos <= size and rawPos <= rawSize do
										char = string.sub(top.value,rawPos,rawPos)
										if base64[char] ~= nil then
											buffer = buffer * bin[7] + base64[char]
											pos = pos + 6
										end
										rawPos = rawPos + 1
									end
									if char == "=" then 
										break 
									end

									while pos < 33 do 
										buffer = buffer * bin[2] 
										pos = pos + 1
									end
									pos = pos - 32
									mapStorage[src].layers[layerIndex].data[#mapStorage[src].layers[layerIndex].data+1] = floor((buffer%bin[33+pos-1])/bin[25+pos-1]) +
												  floor((buffer%bin[25+pos-1])/bin[17+pos-1])*bin[9] +
												  floor((buffer%bin[17+pos-1])/bin[9+pos-1])*bin[17] + 
												  floor((buffer%bin[9+pos-1])/bin[pos])*bin[25]
									buffer = buffer % bin[pos]    	
								end
								--------------------------------------------------------------
							end
							if triggerCSV then
								triggerCSV = false
								mapStorage[src].layers[layerIndex].data = json.decode("["..top.value.."]")
							end
						end
						if empty == "/" then  -- empty element tag
							if label == "tile" then
								mapStorage[src].layers[layerIndex].data[#mapStorage[src].layers[layerIndex].data + 1] = tonumber(xarg:sub(7, xarg:len() - 1))
							else
								table.insert(top.child, {name=label,value=nil,properties=xml.ParseArgs(xarg),child={}})
							end
							if label == "layer" or label == "objectgroup" or label == "imagelayer"  then
								layerIndex = layerIndex + 1
								if not mapStorage[src].layers then
									mapStorage[src].layers = {}
								end
								mapStorage[src].layers[layerIndex] = {}
								mapStorage[src].layers[layerIndex].properties = {}
							end
						elseif c == "" then   -- start tag
							local props = xml.ParseArgs(xarg)
							top = {name=label, value=nil, properties=props, child={}}
							table.insert(stack, top)   -- new level
							if label == "map" then
								--
							end
							if label == "layer" or label == "objectgroup" or label == "imagelayer" then
								layerIndex = layerIndex + 1
								x, y = 1, 1
								if not mapStorage[src].layers then
									mapStorage[src].layers = {}
								end
								mapStorage[src].layers[layerIndex] = {}
								mapStorage[src].layers[layerIndex].properties = {}
								if label == "layer" then
									mapStorage[src].layers[layerIndex].data = {}
									mapStorage[src].layers[layerIndex].world = {}
									mapStorage[src].layers[layerIndex].world[1] = {}
								end
							end
							if label == "data" then
								if props.encoding == "base64" then
									triggerBase64 = true
									if props.compression then
										print("Error(loadMap): Layer data compression is not supported. MTE supports CSV, TMX, and Base64(uncompressed).")
									end
								elseif props.encoding == "csv" then
									triggerCSV = true
								elseif not props.encoding then
									tirggerXML = true
								end
							end
						else  -- end tag
							local toclose = table.remove(stack)  -- remove top
							top = stack[#stack]
							if #stack < 1 then
								error("XmlParser: nothing to close with "..label)
							end
							if toclose.name ~= label then
								error("XmlParser: trying to close "..toclose.name.." with "..label)
							end
							table.insert(top.child, toclose)
						end
						i = j+1
					end
					local text = string.sub(xmlText, i);
					if not string.find(text, "^%s*$") then
						stack[#stack].value=(stack[#stack].value or "")..xml.FromXmlString(text);
					end
						if #stack > 1 then
							error("XmlParser: unclosed "..stack[stack.n].name)
						end
					return stack[1].child[1];
				end

				xml.loadFile = function(xmlFilename, base)
					if not base then
						base = system.ResourceDirectory
					end

					local path = system.pathForFile( xmlFilename, base )
					local hFile, err = io.open(path,"r");

					if hFile and not err then
						local xmlText=hFile:read("*a"); -- read file content
						io.close(hFile);
						return xml.ParseXmlText(xmlText),nil;
					else
						print( err )
						return nil
					end
				end
				------------------------------------------------------------------------------
				--LOAD TMX FILE
				local temp = xml.loadFile(src, base)
				if temp then
					for key,value in pairs(temp.properties) do
						mapStorage[src][key] = value
						if key == "height" or key == "tileheight" or key == "tilewidth" or key == "width" then
							mapStorage[src][key] = tonumber(mapStorage[src][key])
						end
					end
					mapStorage[src].tilesets = {}
					mapStorage[src].properties = {}
					local layerIndex = 1
					local tileSetIndex = 1
				
					for i = 1, #temp.child, 1 do
						if temp.child[i].name == "properties" then
							for j = 1, #temp.child[i].child, 1 do
								mapStorage[src].properties[temp.child[i].child[j].properties.name] = temp.child[i].child[j].properties.value
							end
						end
					
						if temp.child[i].name == "imagelayer" then
							for key,value in pairs(temp.child[i].properties) do
								mapStorage[src].layers[layerIndex][key] = value
								if key == "width" or key == "height" then
									mapStorage[src].layers[layerIndex][key] = tonumber(mapStorage[src].layers[layerIndex][key])
								end
							end
							for j = 1, #temp.child[i].child, 1 do
								if temp.child[i].child[j].name == "properties" then
									for k = 1, #temp.child[i].child[j].child, 1 do
										mapStorage[src].layers[layerIndex].properties[temp.child[i].child[j].child[k].properties.name] = temp.child[i].child[j].child[k].properties.value
									end
								end
							
								if temp.child[i].child[j].name == "image" then 
									mapStorage[src].layers[layerIndex]["image"] = temp.child[i].child[j].properties["source"]
								end
							end
						
							layerIndex = layerIndex + 1
						end
					
						if temp.child[i].name == "layer" then
							for key,value in pairs(temp.child[i].properties) do
								mapStorage[src].layers[layerIndex][key] = value
								if key == "width" or key == "height" then
									mapStorage[src].layers[layerIndex][key] = tonumber(mapStorage[src].layers[layerIndex][key])
								end
							end
							for j = 1, #temp.child[i].child, 1 do
								if temp.child[i].child[j].name == "properties" then
									for k = 1, #temp.child[i].child[j].child, 1 do
										mapStorage[src].layers[layerIndex].properties[temp.child[i].child[j].child[k].properties.name] = temp.child[i].child[j].child[k].properties.value
									end
								end
							end
							layerIndex = layerIndex + 1
						end
					
						if temp.child[i].name == "objectgroup" then
							for key,value in pairs(temp.child[i].properties) do
								mapStorage[src].layers[layerIndex][key] = value
								if key == "width" or key == "height" then
									mapStorage[src].layers[layerIndex][key] = tonumber(mapStorage[src].layers[layerIndex][key])
								end
							end	
							mapStorage[src].layers[layerIndex]["width"] = mapStorage[src]["width"]
							mapStorage[src].layers[layerIndex]["height"] = mapStorage[src]["height"]			
							mapStorage[src].layers[layerIndex].objects = {}
							local firstObject = true
							local indexMod = 0
							for j = 1, #temp.child[i].child, 1 do
								if temp.child[i].child[j].name == "properties" then
									for k = 1, #temp.child[i].child[j].child, 1 do
										mapStorage[src].layers[layerIndex].properties[temp.child[i].child[j].child[k].properties.name] = temp.child[i].child[j].child[k].properties.value
									end
									if not mapStorage[src].layers[layerIndex].properties["width"] then
										mapStorage[src].layers[layerIndex].properties["width"] = 0
									end
									if not mapStorage[src].layers[layerIndex].properties["height"] then
										mapStorage[src].layers[layerIndex].properties["height"] = 0
									end
								end
								if temp.child[i].child[j].name == "object" then
									if firstObject then
										firstObject = false
										indexMod = j - 1
									end
									mapStorage[src].layers[layerIndex].objects[j-indexMod] = {}
									for key,value in pairs(temp.child[i].child[j].properties) do
										mapStorage[src].layers[layerIndex].objects[j-indexMod][key] = value
										if key == "width" or key == "height" or key == "x" or key == "y" or key == "gid" then
											mapStorage[src].layers[layerIndex].objects[j-indexMod][key] = tonumber(mapStorage[src].layers[layerIndex].objects[j-indexMod][key])
										end
									end	
									if not mapStorage[src].layers[layerIndex].objects[j-indexMod].width then
										mapStorage[src].layers[layerIndex].objects[j-indexMod].width = 0
									end				
									if not mapStorage[src].layers[layerIndex].objects[j-indexMod].height then
										mapStorage[src].layers[layerIndex].objects[j-indexMod].height = 0
									end	
									--------
									mapStorage[src].layers[layerIndex].objects[j-indexMod].properties = {}
								
									for k = 1, #temp.child[i].child[j].child, 1 do
										if temp.child[i].child[j].child[k].name == "properties" then
											for m = 1, #temp.child[i].child[j].child[k].child, 1 do	
												mapStorage[src].layers[layerIndex].objects[j-indexMod].properties[temp.child[i].child[j].child[k].child[m].properties.name] = temp.child[i].child[j].child[k].child[m].properties.value								
											end
										end
										if temp.child[i].child[j].child[k].name == "polygon" then
											mapStorage[src].layers[layerIndex].objects[j-indexMod].polygon = {}
											local pointString = temp.child[i].child[j].child[k].properties.points
											local codes = {string.byte(","), string.byte(" ")}
											local stringIndexStart = 1
											local pointIndex = 1
									
											for s = 1, string.len(pointString), 1 do
												if string.byte(pointString, s, s) == codes[1] then
													mapStorage[src].layers[layerIndex].objects[j-indexMod].polygon[pointIndex] = {}
													mapStorage[src].layers[layerIndex].objects[j-indexMod].polygon[pointIndex].x = tonumber(string.sub(pointString, stringIndexStart, s - 1))
													stringIndexStart = s + 1
												end
												if string.byte(pointString, s, s) == codes[2] then
													mapStorage[src].layers[layerIndex].objects[j-indexMod].polygon[pointIndex].y = tonumber(string.sub(pointString, stringIndexStart, s - 1))
													stringIndexStart = s + 1
													pointIndex = pointIndex + 1
												end
												if s == string.len(pointString) then
													mapStorage[src].layers[layerIndex].objects[j-indexMod].polygon[pointIndex].y = tonumber(string.sub(pointString, stringIndexStart, s))
												end
											end
										end
										if temp.child[i].child[j].child[k].name == "polyline" then
											mapStorage[src].layers[layerIndex].objects[j-indexMod].polyline = {}
											local pointString = temp.child[i].child[j].child[k].properties.points
											local codes = {string.byte(","), string.byte(" ")}
											local stringIndexStart = 1
											local pointIndex = 1
									
											for s = 1, string.len(pointString), 1 do
												if string.byte(pointString, s, s) == codes[1] then
													mapStorage[src].layers[layerIndex].objects[j-indexMod].polyline[pointIndex] = {}
													mapStorage[src].layers[layerIndex].objects[j-indexMod].polyline[pointIndex].x = tonumber(string.sub(pointString, stringIndexStart, s - 1))
													stringIndexStart = s + 1
												end
												if string.byte(pointString, s, s) == codes[2] then
													mapStorage[src].layers[layerIndex].objects[j-indexMod].polyline[pointIndex].y = tonumber(string.sub(pointString, stringIndexStart, s - 1))
													stringIndexStart = s + 1
													pointIndex = pointIndex + 1
												end
												if s == string.len(pointString) then
													mapStorage[src].layers[layerIndex].objects[j-indexMod].polyline[pointIndex].y = tonumber(string.sub(pointString, stringIndexStart, s))
												end
											end
										end
										if temp.child[i].child[j].child[k].name == "ellipse" then
											mapStorage[src].layers[layerIndex].objects[j-indexMod].ellipse = true
										end
									end
								end
							end
							layerIndex = layerIndex + 1
						end

						if temp.child[i].name == "tileset" then
							mapStorage[src].tilesets[tileSetIndex] = {}
						
							if temp.child[i].properties.source then
								local tempSet = xml.loadFile(directory..temp.child[i].properties.source)
								if not tempSet.properties.spacing then 
									tempSet.properties.spacing = 0
								end
								if not tempSet.properties.margin then
									tempSet.properties.margin = 0
								end
								for key,value in pairs(tempSet.properties) do
									mapStorage[src].tilesets[tileSetIndex][key] = value
									if key == "tilewidth" or key == "tileheight" or key == "spacing" or key == "margin" then
										mapStorage[src].tilesets[tileSetIndex][key] = tonumber(mapStorage[src].tilesets[tileSetIndex][key])
									end
								end
							
							
								for j = 1, #tempSet.child, 1 do
									if tempSet.child[j].name == "properties" then
										mapStorage[src].tilesets[tileSetIndex].properties = {}
										for k = 1, #tempSet.child[j].child, 1 do
											mapStorage[src].tilesets[tileSetIndex].properties[tempSet.child[j].child[k].properties.name] = tempSet.child[j].child[k].properties.value
										end
									end
									if tempSet.child[j].name == "image" then
										for key,value in pairs(tempSet.child[j].properties) do
											if key == "source" then
												mapStorage[src].tilesets[tileSetIndex]["image"] = directory..value
											elseif key == "width" then
												mapStorage[src].tilesets[tileSetIndex]["imagewidth"] = tonumber(value)
											elseif key == "height" then
												mapStorage[src].tilesets[tileSetIndex]["imageheight"] = tonumber(value)
											else
												mapStorage[src].tilesets[tileSetIndex][key] = value
											end															
										end									
									end
									if tempSet.child[j].name == "tile" then
										if not mapStorage[src].tilesets[tileSetIndex].tileproperties then
											mapStorage[src].tilesets[tileSetIndex].tileproperties = {}
										end
										mapStorage[src].tilesets[tileSetIndex].tileproperties[tempSet.child[j].properties.id] = {}
									
										for k = 1, #tempSet.child[j].child, 1 do
											if tempSet.child[j].child[k].name == "properties" then
												for m = 1, #tempSet.child[j].child[k].child, 1 do
													local name = tempSet.child[j].child[k].child[m].properties.name
													local value = tempSet.child[j].child[k].child[m].properties.value
													mapStorage[src].tilesets[tileSetIndex].tileproperties[tempSet.child[j].properties.id][name] = value
												end
											end
										end
									end
								end							
							else
								local tempSet = temp.child[i]
								if not tempSet.properties.spacing then 
									tempSet.properties.spacing = 0
								end
								if not tempSet.properties.margin then
									tempSet.properties.margin = 0
								end
								for key,value in pairs(tempSet.properties) do
									mapStorage[src].tilesets[tileSetIndex][key] = value
									if key == "tilewidth" or key == "tileheight" or key == "spacing" or key == "margin" then
										mapStorage[src].tilesets[tileSetIndex][key] = tonumber(mapStorage[src].tilesets[tileSetIndex][key])
									end
								end							
							
								for j = 1, #tempSet.child, 1 do
									if tempSet.child[j].name == "properties" then
										mapStorage[src].tilesets[tileSetIndex].properties = {}
										for k = 1, #tempSet.child[j].child, 1 do
											mapStorage[src].tilesets[tileSetIndex].properties[tempSet.child[j].child[k].properties.name] = tempSet.child[j].child[k].properties.value
										end
									end
									if tempSet.child[j].name == "image" then
										for key,value in pairs(tempSet.child[j].properties) do
											if key == "source" then
												mapStorage[src].tilesets[tileSetIndex]["image"] = directory..value
											elseif key == "width" then
												mapStorage[src].tilesets[tileSetIndex]["imagewidth"] = tonumber(value)
											elseif key == "height" then
												mapStorage[src].tilesets[tileSetIndex]["imageheight"] = tonumber(value)
											else
												mapStorage[src].tilesets[tileSetIndex][key] = value
											end															
										end									
									end
									if tempSet.child[j].name == "tile" then
										if not mapStorage[src].tilesets[tileSetIndex].tileproperties then
											mapStorage[src].tilesets[tileSetIndex].tileproperties = {}
										end
										mapStorage[src].tilesets[tileSetIndex].tileproperties[tempSet.child[j].properties.id] = {}
									
										for k = 1, #tempSet.child[j].child, 1 do
											if tempSet.child[j].child[k].name == "properties" then
												for m = 1, #tempSet.child[j].child[k].child, 1 do
													local name = tempSet.child[j].child[k].child[m].properties.name
													local value = tempSet.child[j].child[k].child[m].properties.value
													mapStorage[src].tilesets[tileSetIndex].tileproperties[tempSet.child[j].properties.id][name] = value
												end
											end
										end
									end
								end
							end
							mapStorage[src].tilesets[tileSetIndex].firstgid = tonumber(temp.child[i].properties.firstgid)
							tileSetIndex = tileSetIndex + 1
						end
					end
				else
					print("ERROR: Map Not Found")
					debugText = "ERROR: Map Not Found"
				end

				print(src.." preloaded")			
			else			
				storageToggle = true
				print(src.." already in storage. Load Time: "..system.getTimer() - startTime)
			end		
		end
		
		if not storageToggle then
			mapStorage[src].numLevels = 1
			
			if not mapStorage[src].modified then
				if mapStorage[src].orientation == "orthogonal" then
					mapStorage[src].orientation = 0
				elseif mapStorage[src].orientation == "isometric" then
					mapStorage[src].orientation = 1
				elseif mapStorage[src].orientation == "staggered" then
					mapStorage[src].orientation = 2
				end
			end
	
			local globalID = {}
			local prevLevel = "1"
			for i = 1, #mapStorage[src].layers, 1 do
				if type(mapStorage[src].layers[i].properties.forceDefaultPhysics) == "string" then
					if mapStorage[src].layers[i].properties.forceDefaultPhysics == "true" then
						mapStorage[src].layers[i].properties.forceDefaultPhysics = true
					else
						mapStorage[src].layers[i].properties.forceDefaultPhysics = false
					end
				end
			
				--DETECT WIDTH AND HEIGHT
				if mapStorage[src].layers[i].properties.width then
					mapStorage[src].layers[i].width = tonumber(mapStorage[src].layers[i].properties.width)
				end
				if mapStorage[src].layers[i].properties.height then
					mapStorage[src].layers[i].height = tonumber(mapStorage[src].layers[i].properties.height)
				end			
				--TOGGLE PARALLAX CROP
				if mapStorage[src].layers[i].properties.toggleParallaxCrop == "true" then
					mapStorage[src].layers[i].width = math.floor(mapStorage[src].layers[i].width * mapStorage[src].layers[i].parallaxX)
					mapStorage[src].layers[i].height = math.floor(mapStorage[src].layers[i].height * mapStorage[src].layers[i].parallaxY)
					if mapStorage[src].layers[i].width > mapStorage[src].width then
						mapStorage[src].layers[i].width = mapStorage[src].width
					end
					if mapStorage[src].layers[i].height > mapStorage[src].height then
						mapStorage[src].layers[i].height = mapStorage[src].height
					end
				end		
				--FIT BY PARALLAX / FIT BY SCALE
				if mapStorage[src].layers[i].properties.fitByParallax then
					mapStorage[src].layers[i].parallaxX = mapStorage[src].layers[i].width / mapStorage[src].width
					mapStorage[src].layers[i].parallaxY = mapStorage[src].layers[i].height / mapStorage[src].height
				else
					if mapStorage[src].layers[i].properties.fitByScale then
						mapStorage[src].layers[i].properties.scaleX = (mapStorage[src].width * mapStorage[src].layers[i].properties.parallaxX) / mapStorage[src].layers[i].width
						mapStorage[src].layers[i].properties.scaleY = (mapStorage[src].height * mapStorage[src].layers[i].properties.parallaxY) / mapStorage[src].layers[i].height
					end
				end
				
				----------------------------------------------------------------------------------
				local hex2bin = {
					["0"] = "0000",
					["1"] = "0001",
					["2"] = "0010",
					["3"] = "0011",
					["4"] = "0100",
					["5"] = "0101",
					["6"] = "0110",
					["7"] = "0111",
					["8"] = "1000",
					["9"] = "1001",
					["a"] = "1010",
					["b"] = "1011",
					["c"] = "1100",
					["d"] = "1101",
					["e"] = "1110",
					["f"] = "1111"
				}
	
				local Hex2Bin = function(s)
					local ret = ""
					local i = 0
					for i in string.gfind(s, ".") do
						i = string.lower(i)

						ret = ret..hex2bin[i]
					end
					return ret
				end
		
				local Bin2Dec = function(s)	
					local num = 0
					local ex = string.len(s) - 1
					local l = 0
					l = ex + 1
					for i = 1, l do
						b = string.sub(s, i, i)
						if b == "1" then
							num = num + 2^ex
						end
						ex = ex - 1
					end
					return string.format("%u", num)
				end
		
				local Dec2Bin = function(s, num)
					local n
					if (num == nil) then
						n = 0
					else
						n = num
					end
					s = string.format("%x", s)
					s = Hex2Bin(s)
					while string.len(s) < n do
						s = "0"..s
					end
					return s
				end
				----------------------------------------------------------------------------------

				--LOAD WORLD ARRAYS
				if not mapStorage[src].modified then
					mapStorage[src].layers[i].world = {}
					--mapStorage[src].layers[i].tileObjects = {}
					if enableFlipRotation then
						mapStorage[src].layers[i].flipRotation = {}
					end
					if M.enableLighting and i == 1 then
						mapStorage[src].lightToggle = {}
						mapStorage[src].lightToggle2 = {}
						mapStorage[src].lightToggle3 = {}
						M.lightingData.lightLookup = {}
					end
					for x = 1, mapStorage[src].layers[i].width, 1 do
						mapStorage[src].layers[i].world[x] = {}
						--mapStorage[src].layers[i].tileObjects[x] = {}
						if mapStorage[src].layers[i].lighting then
							mapStorage[src].layers[i].lighting[x] = {}
						end
						if M.enableLighting and i == 1 then
							mapStorage[src].lightToggle[x] = {}
							mapStorage[src].lightToggle2[x] = {}
							mapStorage[src].lightToggle3[x] = {}
						end
						if enableFlipRotation then
							mapStorage[src].layers[i].flipRotation[x] = {}
						end
						local lx = x
						while lx > mapStorage[src].width do
							lx = lx - mapStorage[src].width
						end
						for y = 1, mapStorage[src].layers[i].height, 1 do
							if M.enableLighting and i == 1 then
								mapStorage[src].lightToggle2[x][y] = 0
							end
							
							local ly = y
							while ly > mapStorage[src].height do
								ly = ly - mapStorage[src].height
							end
							if mapStorage[src].layers[i].data then
								if enableFlipRotation then
									if mapStorage[src].layers[i].data[(mapStorage[src].width * (ly - 1)) + lx] > 1000000 then
										local string = tostring(mapStorage[src].layers[i].data[(mapStorage[src].width * (ly - 1)) + lx])
										if globalID[string] then
											mapStorage[src].layers[i].flipRotation[x][y] = globalID[string][1]
											mapStorage[src].layers[i].world[x][y] = globalID[string][2]
										else
											local binary = Dec2Bin(string)
											local command = string.sub(binary, 1, 3)
											local flipRotate = Bin2Dec(command)
											mapStorage[src].layers[i].flipRotation[x][y] = tonumber(flipRotate)
											local binaryID = string.sub(binary, 4, 32)
											local tileID = Bin2Dec(binaryID)
											mapStorage[src].layers[i].world[x][y] = tonumber(tileID)
											globalID[string] = {tonumber(flipRotate), tonumber(tileID)}
										end
									else
										mapStorage[src].layers[i].world[x][y] = mapStorage[src].layers[i].data[(mapStorage[src].width * (ly - 1)) + lx]
									end
								else
									mapStorage[src].layers[i].world[x][y] = mapStorage[src].layers[i].data[(mapStorage[src].width * (ly - 1)) + lx]
								end
								
								if M.enableLighting then
									if mapStorage[src].layers[i].world[x][y] ~= 0 then
										local frameIndex = mapStorage[src].layers[i].world[x][y]
										local tileSetIndex = 1
										for i = 1, #mapStorage[src].tilesets, 1 do
											if frameIndex >= mapStorage[src].tilesets[i].firstgid then
												tileSetIndex = i
											else
												break
											end
										end

										tileStr = tostring((frameIndex - (mapStorage[src].tilesets[tileSetIndex].firstgid - 1)) - 1)
										local mT = mapStorage[src].tilesets[tileSetIndex].tileproperties
										if mT then
											if mT[tileStr] then
												if mT[tileStr]["lightSource"] then
													local range = json.decode(mT[tileStr]["lightRange"])
													local maxRange = range[1]
													for l = 1, 3, 1 do
														if range[l] > maxRange then
															maxRange = range[l]
														end
													end
													mapStorage[src].lights[lightIDs] = {locX = x, 
														locY = y, 
														tileSetIndex = tileSetIndex, 
														tileStr = tileStr,
														frameIndex = frameIndex,
														source = json.decode(mT[tileStr]["lightSource"]),
														falloff = json.decode(mT[tileStr]["lightFalloff"]),
														range = range,
														maxRange = maxRange,
														layer = i,
														baseLayer = i,
														level = M.getLevel(i),
														id = lightIDs,
														area = {},
														areaIndex = 1
													}
													if mT[tileStr]["lightLayer"] then
														mapStorage[src].lights[lightIDs].layer = tonumber(mT[tileStr]["lightLayer"])
														mapStorage[src].lights[lightIDs].level = M.getLevel(mapStorage[src].lights[lightIDs].layer)
													elseif mT[tileStr]["lightLayerRelative"] then
														mapStorage[src].lights[lightIDs].layer = mapStorage[src].lights[lightIDs].layer + tonumber(mT[tileStr]["lightLayerRelative"])
														if mapStorage[src].lights[lightIDs].layer < 1 then
															mapStorage[src].lights[lightIDs].layer = 1
														end
														if mapStorage[src].lights[lightIDs].layer > #mapStorage[src].layers then
															mapStorage[src].lights[lightIDs].layer = #mapStorage[src].layers
														end
														mapStorage[src].lights[lightIDs].level = M.getLevel(mapStorage[src].lights[lightIDs].layer)
													end
													if mT[tileStr]["lightArc"] then
														mapStorage[src].lights[lightIDs].arc = json.decode(
															mT[tileStr]["lightArc"]
														)
													end
													if mT[tileStr]["lightRays"] then
														mapStorage[src].lights[lightIDs].rays = json.decode(
															mT[tileStr]["lightRays"]
														)
													end
													if mT[tileStr]["layerFalloff"] then
														mapStorage[src].lights[lightIDs].layerFalloff = json.decode(
															mT[tileStr]["layerFalloff"]
														)
													end
													if mT[tileStr]["levelFalloff"] then
														mapStorage[src].lights[lightIDs].levelFalloff = json.decode(
															mT[tileStr]["levelFalloff"]
														)
													end
													lightIDs = lightIDs + 1
												end
											end
										end
									end
								end
							else
								mapStorage[src].layers[i].world[x][y] = 0
							end
						end
					end 
				end
			end
			
			if mapStorage[src].orientation == 1 then
				for i = 1, #mapStorage[src].layers, 1 do
					if not mapStorage[src].layers[i].data and not mapStorage[src].layers[i].image then
						for j = 1, #mapStorage[src].layers[i].objects, 1 do
							mapStorage[src].layers[i].objects[j].width = mapStorage[src].layers[i].objects[j].width * 2
							mapStorage[src].layers[i].objects[j].height = mapStorage[src].layers[i].objects[j].height * 2
							mapStorage[src].layers[i].objects[j].x = mapStorage[src].layers[i].objects[j].x * 2
							mapStorage[src].layers[i].objects[j].y = mapStorage[src].layers[i].objects[j].y * 2
							if mapStorage[src].layers[i].objects[j].polygon then
								for k = 1, #mapStorage[src].layers[i].objects[j].polygon, 1 do
									mapStorage[src].layers[i].objects[j].polygon[k].x = mapStorage[src].layers[i].objects[j].polygon[k].x * 2
									mapStorage[src].layers[i].objects[j].polygon[k].y = mapStorage[src].layers[i].objects[j].polygon[k].y * 2
								end
							elseif mapStorage[src].layers[i].objects[j].polyline then
								for k = 1, #mapStorage[src].layers[i].objects[j].polyline, 1 do
									mapStorage[src].layers[i].objects[j].polyline[k].x = mapStorage[src].layers[i].objects[j].polyline[k].x * 2
									mapStorage[src].layers[i].objects[j].polyline[k].y = mapStorage[src].layers[i].objects[j].polyline[k].y * 2
								end
							end
						end
					end
				end
			end
			print("Map Load Time: "..system.getTimer() - startTime)
		end
	
	end
	
	M.expandMapBounds = function(parameters)
		local prevMapWidth, prevMapHeight = map.width, map.height
		local prevMapOX, prevMapOY = map.locOffsetX, map.locOffsetY
		
		--[[
		local mL = map.layers[object.objectLayer]
		if tright - tleft < masterGroup[i].vars.camera[3] - masterGroup[i].vars.camera[1] then
			if tbottom - ttop < masterGroup[i].vars.camera[4] - masterGroup[i].vars.camera[2] then
				--four corners
				print(tleft, ttop, tright, tbottom)
				if not mL.extendedObjects[tleft][ttop] then
					mL.extendedObjects[tleft][ttop] = {}
				end
				if not mL.extendedObjects[tright][ttop] then
					mL.extendedObjects[tright][ttop] = {}
				end
				if not mL.extendedObjects[tleft][tbottom] then
					mL.extendedObjects[tleft][tbottom] = {}
				end
				if not mL.extendedObjects[tright][tbottom] then
					mL.extendedObjects[tright][tbottom] = {}
				end
				]]--
									
		if parameters.leftBound then
			--left
			prevMapWidth = map.width
			prevMapHeight = map.height
			prevMapOX = map.locOffsetX
			prevMapOY = map.locOffsetY
			local prevOX = map.locOffsetX
			local x = 1 - parameters.leftBound
			map.locOffsetX = map.locOffsetX + x
			map.width = map.width + x
			
			for i = 1, #map.layers, 1 do
				map.layers[i].width = map.layers[i].width + x
				for locX = 1 - map.locOffsetX, 1 - prevOX - 1, 1 do
					map.layers[i].world[locX] = {}
					tileObjects[i][locX] = {}
					if map.layers[i].extendedObjects then
						map.layers[i].extendedObjects[locX] = {}
					end
					if enableFlipRotation then
						map.layers[i].flipRotation[locX] = {}
					end
					for locY = 1, map.height, 1 do
						map.layers[i].world[locX][locY - map.locOffsetY] = 0
					end
				end
			end
		end
		
		if parameters.rightBound then
			--right
			prevMapWidth = map.width
			prevMapHeight = map.height
			prevMapOX = map.locOffsetX
			prevMapOY = map.locOffsetY
			local prevWidth = map.width
			local x = parameters.rightBound - (prevWidth - map.locOffsetX)
			map.width = map.width + x
			
			for i = 1, #map.layers, 1 do
				map.layers[i].width = map.layers[i].width + x
				for locX = (prevWidth - map.locOffsetX) + 1, (map.width - map.locOffsetX), 1 do
					map.layers[i].world[locX] = {}
					tileObjects[i][locX] = {}
					if map.layers[i].extendedObjects then
						map.layers[i].extendedObjects[locX] = {}
					end
					if enableFlipRotation then
						map.layers[i].flipRotation[locX] = {}
					end
					for locY = 1, map.height, 1 do
						map.layers[i].world[locX][locY - map.locOffsetY] = 0
					end
				end
			end
		end
		
		if parameters.topBound then
			--top
			prevMapWidth = map.width
			prevMapHeight = map.height
			prevMapOX = map.locOffsetX
			prevMapOY = map.locOffsetY
			local prevOY = map.locOffsetY
			local y = 1 - parameters.topBound
			map.locOffsetY = map.locOffsetY + y
			map.height = map.height + y
			
			for i = 1, #map.layers, 1 do
				map.layers[i].height = map.layers[i].height + y
				for locX = 1, map.width, 1 do
					for locY = 1 - map.locOffsetY, 1 - prevOY - 1, 1 do
						map.layers[i].world[locX - map.locOffsetX][locY] = 0
					end
				end
			end
		end
		
		if parameters.bottomBound then
			--bottom
			prevMapWidth = map.width
			prevMapHeight = map.height
			prevMapOX = map.locOffsetX
			prevMapOY = map.locOffsetY
			local prevHeight = map.height
			local y = parameters.bottomBound - (prevHeight - map.locOffsetY)
			map.height = map.height + y
			
			for i = 1, #map.layers, 1 do
				map.layers[i].height = map.layers[i].height + y
				for locX = 1, map.width, 1 do
					for locY = (prevHeight - map.locOffsetY) + 1, (map.height - map.locOffsetY), 1 do
						map.layers[i].world[locX - map.locOffsetX][locY] = 0
					end
				end
			end
		end
		
		-------------------------
		
		if parameters.pushLeft and parameters.pushLeft > 0 then
			--left
			prevMapWidth = map.width
			prevMapHeight = map.height
			prevMapOX = map.locOffsetX
			prevMapOY = map.locOffsetY
			local prevOX = map.locOffsetX
			local x = parameters.pushLeft
			map.locOffsetX = map.locOffsetX + x
			map.width = map.width + x
			
			for i = 1, #map.layers, 1 do
				map.layers[i].width = map.layers[i].width + x
				for locX = 1 - map.locOffsetX, 1 - prevOX - 1, 1 do
					map.layers[i].world[locX] = {}
					tileObjects[i][locX] = {}
					if map.layers[i].extendedObjects then
						map.layers[i].extendedObjects[locX] = {}
					end
					if enableFlipRotation then
						map.layers[i].flipRotation[locX] = {}
					end
					for locY = 1, map.height, 1 do
						map.layers[i].world[locX][locY - map.locOffsetY] = 0
					end
				end
			end
		end
		
		if parameters.pushRight and parameters.pushRight > 0 then
			--right
			prevMapWidth = map.width
			prevMapHeight = map.height
			prevMapOX = map.locOffsetX
			prevMapOY = map.locOffsetY
			local prevWidth = map.width
			local x = parameters.pushRight
			map.width = map.width + x
			
			for i = 1, #map.layers, 1 do
				map.layers[i].width = map.layers[i].width + x
				--print((prevWidth - map.locOffsetX) + 1, (map.width - map.locOffsetX))
				for locX = (prevWidth - map.locOffsetX) + 1, (map.width - map.locOffsetX), 1 do
					map.layers[i].world[locX] = {}
					tileObjects[i][locX] = {}
					if map.layers[i].extendedObjects then
						map.layers[i].extendedObjects[locX] = {}
					end
					if enableFlipRotation then
						map.layers[i].flipRotation[locX] = {}
					end
					for locY = 1, map.height, 1 do
						map.layers[i].world[locX][locY - map.locOffsetY] = 0
					end
				end
			end
		end
		
		if parameters.pushUp and parameters.pushUp > 0 then
			--top
			prevMapWidth = map.width
			prevMapHeight = map.height
			prevMapOX = map.locOffsetX
			prevMapOY = map.locOffsetY
			local prevOY = map.locOffsetY
			local y = parameters.pushUp
			map.locOffsetY = map.locOffsetY + y
			map.height = map.height + y
			
			for i = 1, #map.layers, 1 do
				map.layers[i].height = map.layers[i].height + y
				for locX = 1, map.width, 1 do
					for locY = 1 - map.locOffsetY, 1 - prevOY - 1, 1 do
						map.layers[i].world[locX - map.locOffsetX][locY] = 0
					end
				end
			end
		end
		
		if parameters.pushDown and parameters.pushDown > 0 then
			--bottom
			prevMapWidth = map.width
			prevMapHeight = map.height
			prevMapOX = map.locOffsetX
			prevMapOY = map.locOffsetY
			local prevHeight = map.height
			local y = parameters.pushDown
			map.height = map.height + y
			
			for i = 1, #map.layers, 1 do
				map.layers[i].height = map.layers[i].height + y
				for locX = 1, map.width, 1 do
					for locY = (prevHeight - map.locOffsetY) + 1, (map.height - map.locOffsetY), 1 do
						map.layers[i].world[locX - map.locOffsetX][locY] = 0
					end
				end
			end
		end 
		
		--[[
		for i = 1, #map.layers, 1 do
			for x = 1 - map.loxOffsetX
			map.layers[i].extendedObjects
		end
		]]--
		
		if M.enableSpriteSorting then
			for i = 1, #map.layers, 1 do
				if map.layers[i].properties.spriteLayer then
					if masterGroup[i][2].depthBuffer then
						if masterGroup[i][2].numChildren < map.height * M.spriteSortResolution then
							for j = masterGroup[i][2].numChildren, map.height * M.spriteSortResolution , 1 do
								local temp = display.newGroup()
								temp.layer = i
								temp.isDepthBuffer = true
								masterGroup[i][2]:insert(temp)
							end
						end
					end
				end
			end
		end
		
		--[[
		for i = 1, #map.layers, 1 do
			for x = 1, map.width, 1 do
				if map.layers[i].largeTiles[x] then
					for y = 1, map.height, 1 do						
						if map.layers[i].largeTiles[x][y] then
							for j = 1, #map.layers[i].largeTiles[x][y], 1 do
								local frameIndex = map.layers[i].largeTiles[x][y][j][1]
								local locX = map.layers[i].largeTiles[x][y][j][2]
								local locY = map.layers[i].largeTiles[x][y][j][3]
								
								
								local frameIndex = frameIndex
								local tileSetIndex = 1
								for i = 1, #map.tilesets, 1 do
									if frameIndex >= map.tilesets[i].firstgid then
										tileSetIndex = i
									else
										break
									end
								end
								local mT = map.tilesets[tileSetIndex]
								
								local width = math.ceil(mT.tilewidth / map.tilewidth)
								local height = math.ceil(mT.tileheight / map.tileheight)
								
								print("do", x, y, frameIndex, locX, locY, width, height)
							end
							
						end
					end
				end
			end
		end
		]]--
		
		for i = 1, #map.layers, 1 do
			for x = 1 - prevMapOX, prevMapWidth - prevMapOX, 1 do
				for y = 1 - prevMapOY, prevMapHeight - prevMapOY, 1 do
					if map.layers[i].largeTiles[x] and map.layers[i].largeTiles[x][y] then
						for j = #map.layers[i].largeTiles[x][y], 1, -1 do
							local frameIndex = map.layers[i].largeTiles[x][y][j][1]
							local locX = map.layers[i].largeTiles[x][y][j][2]
							local locY = map.layers[i].largeTiles[x][y][j][3]
							
							local frameIndex = frameIndex
							local tileSetIndex = 1
							for i = 1, #map.tilesets, 1 do
								if frameIndex >= map.tilesets[i].firstgid then
									tileSetIndex = i
								else
									break
								end
							end
							local mT = map.tilesets[tileSetIndex]
							
							local width = math.ceil(mT.tilewidth / map.tilewidth)
							local height = math.ceil(mT.tileheight / map.tileheight)

							local left = locX
							if left < 1 - prevMapOX then
								left = left + prevMapWidth
							end
							if left > prevMapWidth - prevMapOX then
								left = left - prevMapWidth
							end		
							
							local top = locY - height + 1
							if top < 1 - prevMapOY then
								top = top + prevMapHeight
							end
							if top > prevMapHeight - prevMapOY then
								top = top - prevMapHeight
							end
							
							local right = locX + width - 1
							if right < 1 - prevMapOX then
								right = right + prevMapWidth
							end
							if right > prevMapWidth - prevMapOX then
								right = right - prevMapWidth
							end	
							
							local bottom = locY
							if bottom < 1 - prevMapOY then
								bottom = bottom + prevMapHeight
							end
							if bottom > prevMapHeight - prevMapOY then
								bottom = bottom - prevMapHeight
							end
							
							local aTop, aRight = nil, nil
							if right < left then
								aRight = right + prevMapWidth
							end
							if top > bottom then
								aTop = top - prevMapHeight
							end
								
							local lx, ly = x, y
							
							if lx < locX then
								lx = lx + prevMapWidth
							end
							if ly > locY then
								ly = ly - prevMapHeight
							end
							
							--print(x, y, lx, ly)
							
							if lx ~= x or ly ~= y then
								if not map.layers[i].largeTiles[lx] then
									map.layers[i].largeTiles[lx] = {}
								end
								if not map.layers[i].largeTiles[lx][ly] then
									map.layers[i].largeTiles[lx][ly] = {}
								end
								map.layers[i].largeTiles[lx][ly][#map.layers[i].largeTiles[lx][ly] + 1] = {frameIndex, locX, locY}
								table.remove(map.layers[i].largeTiles[x][y], j)
							end
							
						end
					end
				end
			end
		end
		
		if cheese then
		for i = 1, #map.layers, 1 do
			for x = 1 - map.locOffsetX, map.width - map.locOffsetX, 1 do
				local lx = x
				if lx < 1 - prevMapOX then
					lx = lx + prevMapWidth
				end
				if lx > prevMapWidth - prevMapOX then
					lx = lx - prevMapWidth
				end				
				if map.layers[i].largeTiles[lx] then
					--print(1 - map.locOffsetY, map.height - map.locOffsetY)
					for y = 1 - map.locOffsetY, map.height - map.locOffsetY, 1 do
						local ly = y
						if ly < 1 - prevMapOY then
							ly = ly + prevMapHeight
						end
						if ly > prevMapHeight - prevMapOY then
							ly = ly - prevMapHeight
						end
						--print(y)
						if map.layers[i].largeTiles[lx][ly] then
							--print(lx, ly)
							for j = 1, #map.layers[i].largeTiles[lx][ly], 1 do
								local frameIndex = map.layers[i].largeTiles[lx][ly][j][1]
								local locX = map.layers[i].largeTiles[lx][ly][j][2]
								local locY = map.layers[i].largeTiles[lx][ly][j][3]
								
								
								local frameIndex = frameIndex
								local tileSetIndex = 1
								for i = 1, #map.tilesets, 1 do
									if frameIndex >= map.tilesets[i].firstgid then
										tileSetIndex = i
									else
										break
									end
								end
								local mT = map.tilesets[tileSetIndex]
								
								local width = math.ceil(mT.tilewidth / map.tilewidth)
								local height = math.ceil(mT.tileheight / map.tileheight)
								
								local left = locX
								if left < 1 - prevMapOX then
									left = left + prevMapWidth
								end
								if left > prevMapWidth - prevMapOX then
									left = left - prevMapWidth
								end		
								
								local top = locY - height + 1
								if top < 1 - prevMapOY then
									top = top + prevMapHeight
								end
								if top > prevMapHeight - prevMapOY then
									top = top - prevMapHeight
								end
								
								local right = locX + width - 1
								if right < 1 - prevMapOX then
									right = right + prevMapWidth
								end
								if right > prevMapWidth - prevMapOX then
									right = right - prevMapWidth
								end	
								
								local bottom = locY
								if bottom < 1 - prevMapOY then
									bottom = bottom + prevMapHeight
								end
								if bottom > prevMapHeight - prevMapOY then
									bottom = bottom - prevMapHeight
								end
								
								--[[
								local left = lx
								if left < 1 - prevMapOX then
									left = left + prevMapWidth
								end
								if left > prevMapWidth - prevMapOX then
									left = left - prevMapWidth
								end		
								
								local top = ly
								if top < 1 - prevMapOY then
									top = top + prevMapHeight
								end
								if top > prevMapHeight - prevMapOY then
									top = top - prevMapHeight
								end
								
								local right = lx + width - 1
								if right < 1 - prevMapOX then
									right = right + prevMapWidth
								end
								if right > prevMapWidth - prevMapOX then
									right = right - prevMapWidth
								end	
								
								local bottom = ly + height - 1
								if bottom < 1 - prevMapOY then
									bottom = bottom + prevMapHeight
								end
								if bottom > prevMapHeight - prevMapOY then
									bottom = bottom - prevMapHeight
								end
								]]--
								
								--[[
								if top > bottom then
									--correct top
									
									if prevMapHeight ~= map.height then
										local aTop = top - prevMapHeight
										for tY = aTop, bottom, 1 do
											for tX = left, right, 1 do
												if tY + prevMapHeight <= prevMapHeight then
													if not map.layers[i].largeTiles[tX] then
														map.layers[i].largeTiles[tX] = {}
													end
													if not map.layers[i].largeTiles[tX][tY] then
														map.layers[i].largeTiles[tX][tY] = {}
													end
													map.layers[i].largeTiles[tX][tY][#map.layers[i].largeTiles[tX][tY] + 1] = {frameIndex, locX, locY}
													map.layers[i].largeTiles[lx][ly][j] = nil
												end
											end
										end
									end
								
								
								elseif right < left then
									--correct right
									
									if prevMapWidth ~= map.width then
										local aRight = right + prevMapWidth
										for tX = left, aRight, 1 do
											if tX - prevMapWidth > 0 then
												for tY = top, bottom, 1 do
													if not map.layers[i].largeTiles[tX] then
														map.layers[i].largeTiles[tX] = {}
													end
													if not map.layers[i].largeTiles[tX][tY] then
														map.layers[i].largeTiles[tX][tY] = {}
													end
													map.layers[i].largeTiles[tX][tY][#map.layers[i].largeTiles[tX][tY] + 1] = {frameIndex, locX, locY}
													map.layers[i].largeTiles[lx][ly][j] = nil
												end
											end
										end
									end
								end
								]]--
								
								local aTop, aRight = nil, nil
								if right < left then
									aRight = right + prevMapWidth
								end
								if top > bottom then
									aTop = top - prevMapHeight
								end
								if locX == 49 and locY == 1 then
									--print(lx, ly, locX, locY, prevMapWidth, prevMapHeight)
								end
								print(x, y, lx, ly, locX, locY, "-------------")
								
								--[[
								for tX = left, (aRight or right), 1 do
									for tY = (aTop or top), bottom, 1 do
										if locX == 49 and locY == 1 then
											--print("    test", tX, map.width)
										end
										--print(tX, tY)
										local tempX, tempY = tX, tY
										if tempX > prevMapWidth then
											tempX = tempX - prevMapWidth
										end
										if tempY < 1 then
											tempY = tempY + prevMapHeight
										end
										--print(tX, tY, tempX, tempY, aRight, aTop)
										
										
										local testX = (tX - prevMapWidth > 0 and aRight) and tX <= map.width
										local testY = (tY + prevMapHeight <= prevMapHeight and aTop)
										--if (tX - prevMapWidth > 0 and aRight) or (tY + prevMapHeight <= prevMapHeight and aTop) then
										if testX or testY then
											if not map.layers[i].largeTiles[tX] then
												map.layers[i].largeTiles[tX] = {}
											end
											if not map.layers[i].largeTiles[tX][tY] then
												map.layers[i].largeTiles[tX][tY] = {}
											end
											if locX == 49 and locY == 1 then
												--print(">", tX, tY)
											end
											map.layers[i].largeTiles[tX][tY][#map.layers[i].largeTiles[tX][tY] + 1] = {frameIndex, locX, locY}
											--map.layers[i].largeTiles[tX - prevMapWidth][tY + prevMapHeight][j] = nil
											
											
											--if aRight and aTop then
											if testX and testY then
												if locX == 49 and locY == 1 then
													--print("a", tX - prevMapWidth, tY + prevMapHeight)
												end
												--map.layers[i].largeTiles[tX - prevMapWidth][tY + prevMapHeight][j] = nil
												table.remove(map.layers[i].largeTiles[tX - prevMapWidth][tY + prevMapHeight], j)
											--elseif aRight then
											elseif testX then
												if locX == 49 and locY == 1 then
													--print("b", tX - prevMapWidth, tY)
												end
												--map.layers[i].largeTiles[tX - prevMapWidth][tY][j] = nil
												table.remove(map.layers[i].largeTiles[tX - prevMapWidth][tY], j)
											--elseif aTop then
											elseif testY then
												if locX == 49 and locY == 1 then
													--print("c", tX, tY + prevMapHeight)
												end
												local ttX = tX
												if ttX > map.width then
													ttX = ttX - map.width
												end
												--map.layers[i].largeTiles[tX][tY + prevMapHeight][j] = nil
												table.remove(map.layers[i].largeTiles[ttX][tY + prevMapHeight], j)
											end
											
										end
										
									end
								end
								]]--
								
								
								--[[
								local aTop, aRight = top, right
								if top > bottom then
									aTop = top - prevMapHeight
									for tY = aTop, bottom, 1 do
										if aRight < left then
											aRight = aRight + prevMapWidth
										end
										for tX = left, aRight, 1 do
											if tY + prevMapHeight <= prevMapHeight then
												local tX2 = tX
												if tX2 > prevMapWidth then
													tX2 = tX2 - prevMapWidth
												end
												if not map.layers[i].largeTiles[tX2] then
													map.layers[i].largeTiles[tX2] = {}
												end
												if not map.layers[i].largeTiles[tX2][tY] then
													map.layers[i].largeTiles[tX2][tY] = {}
												end
												map.layers[i].largeTiles[tX2][tY][#map.layers[i].largeTiles[tX2][tY] + 1] = {frameIndex, locX, locY}
												map.layers[i].largeTiles[lx][ly][j] = nil
											end
										end
									end
								end
								
								top = aTop
								]]--
								
								--[[
								if right < left then
									local aRight = right + prevMapWidth
									--print(aTop, bottom)
									for tX = left, aRight, 1 do
										for tY = top, bottom, 1 do
											
											if tX - prevMapWidth <= prevMapWidth then
												if not map.layers[i].largeTiles[tX] then
													map.layers[i].largeTiles[tX] = {}
												end
												if not map.layers[i].largeTiles[tX][tY] then
													map.layers[i].largeTiles[tX][tY] = {}
												end
												--print(tX, tY)
												map.layers[i].largeTiles[tX][tY][#map.layers[i].largeTiles[tX][tY] + 1] = {frameIndex, locX, locY}
												map.layers[i].largeTiles[lx][ly][j] = nil
											end
										end
									end
									
								end
								]]--
							end
						end
					end
				end
			end
		end
		end
	end
	
	M.createLayer = function(layer)		
		--CREATE LAYER
		map.layers[layer] = {}
		map.layers[layer].properties = {}

		--CHECK AND LOAD SCALE AND LEVELS
		if not map.layers[layer].properties then
			map.layers[layer].properties = {}
			map.layers[layer].properties.level = "1"
			map.layers[layer].properties.scaleX = 1
			map.layers[layer].properties.scaleY = 1
			map.layers[layer].properties.parallaxX = 1
			map.layers[layer].properties.parallaxY = 1
		else
			if not map.layers[layer].properties.level then
				map.layers[layer].properties.level = "1"
			end
			if map.layers[layer].properties.scale then
				map.layers[layer].properties.scaleX = map.layers[layer].properties.scale
				map.layers[layer].properties.scaleY = map.layers[layer].properties.scale
			else
				if not map.layers[layer].properties.scaleX then
					map.layers[layer].properties.scaleX = 1
				end
				if not map.layers[layer].properties.scaleY then
					map.layers[layer].properties.scaleY = 1
				end
			end
		end
		map.layers[layer].properties.scaleX = tonumber(map.layers[layer].properties.scaleX)
		map.layers[layer].properties.scaleY = tonumber(map.layers[layer].properties.scaleY)
		if map.layers[layer].properties.parallax then
			map.layers[layer].parallaxX = map.layers[layer].properties.parallax / map.layers[layer].properties.scaleX
			map.layers[layer].parallaxY = map.layers[layer].properties.parallax / map.layers[layer].properties.scaleY
		else
			if map.layers[layer].properties.parallaxX then
				map.layers[layer].parallaxX = map.layers[layer].properties.parallaxX / map.layers[layer].properties.scaleX
			else
				map.layers[layer].parallaxX = 1
			end
			if map.layers[layer].properties.parallaxY then
				map.layers[layer].parallaxY = map.layers[layer].properties.parallaxY / map.layers[layer].properties.scaleY
			else
				map.layers[layer].parallaxY = 1
			end
		end	
		--DETECT WIDTH AND HEIGHT
		map.layers[layer].width = map.layers[refLayer].width
		map.layers[layer].height = map.layers[refLayer].height
		if map.layers[layer].properties.width then
			map.layers[layer].width = tonumber(map.layers[layer].properties.width)
		end
		if map.layers[layer].properties.height then
			map.layers[layer].height = tonumber(map.layers[layer].properties.height)
		end
		--DETECT LAYER WRAP
		layerWrapX[layer] = worldWrapX
		layerWrapY[layer] = worldWrapY
		if map.layers[layer].properties.wrap then
			if map.layers[layer].properties.wrap == "true" then
				layerWrapX[layer] = true
				layerWrapY[layer] = true
			elseif map.layers[layer].properties.wrap == "false" then
				layerWrapX[layer] = false
				layerWrapY[layer] = false
			end
		end
		if map.layers[layer].properties.wrapX then
			if map.layers[layer].properties.wrapX == "true" then
				layerWrapX[layer] = true
			elseif map.layers[layer].properties.wrapX == "false" then
				layerWrapX[layer] = false
			end
		end
		if map.layers[layer].properties.wrapY then
			if map.layers[layer].properties.wrapY == "true" then
				layerWrapY[layer] = true
			elseif map.layers[layer].properties.wrapY == "false" then
				layerWrapY[layer] = false
			end
		end
		--TOGGLE PARALLAX CROP
		if map.layers[layer].properties.toggleParallaxCrop == "true" then
			map.layers[layer].width = math.floor(map.layers[layer].width * map.layers[layer].parallaxX)
			map.layers[layer].height = math.floor(map.layers[layer].height * map.layers[layer].parallaxY)
			if map.layers[layer].width > map.width then
				map.layers[layer].width = map.width
			end
			if map.layers[layer].height > map.height then
				map.layers[layer].height = map.height
			end
		end		
		--FIT BY PARALLAX / FIT BY SCALE
		if map.layers[layer].properties.fitByParallax then
			map.layers[layer].parallaxX = map.layers[layer].width / map.width
			map.layers[layer].parallaxY = map.layers[layer].height / map.height
		else
			if map.layers[layer].properties.fitByScale then
				map.layers[layer].properties.scaleX = (map.width * map.layers[layer].properties.parallaxX) / map.layers[layer].width
				map.layers[layer].properties.scaleY = (map.height * map.layers[layer].properties.parallaxY) / map.layers[layer].height
			end
		end
		if M.enableLighting then
			if not map.layers[layer].lighting then
				map.layers[layer].lighting = {}
			end
		end
		
		if M.enableLighting then
			for x = 1, map.layers[layer].width, 1 do
				if map.layers[layer].lighting then
					map.layers[layer].lighting[x] = {}
				end
			end
		end
	
		tileObjects[layer] = {}
		for x = 1, map.layers[layer].width, 1 do
			tileObjects[layer][x - map.locOffsetX] = {}
		end
		
		map.layers[layer].world = {}
		map.layers[layer].largeTiles = {}
		if enableFlipRotation then
			map.layers[layer].flipRotation = {}
		end
		for x = 1, map.width, 1 do
			map.layers[layer].world[x - map.locOffsetX] = {}
			if enableFlipRotation then
				map.layers[layer].flipRotation[x - map.locOffsetX] = {}
			end
			for y = 1, map.height, 1 do
				map.layers[layer].world[x - map.locOffsetX][y - map.locOffsetY] = 0
			end
		end
		
		--CREATE DISPLAY GROUPS
		for k = masterGroup.numChildren + 1, layer, 1 do
			if not masterGroup[k] then
				local group = display.newGroup()
				masterGroup:insert(group)
				local tiles = display.newGroup()
				tiles.tiles = true
				masterGroup[k]:insert(tiles)
				masterGroup[k].vars = {alpha = 1}
				masterGroup[k].vars.layer = k	
				masterGroup[k].x = masterGroup[refLayer].x
				masterGroup[k].y = masterGroup[refLayer].y	
			end
		end
		
		if M.enableSpriteSorting then
			if map.layers[layer].properties.spriteLayer then
				masterGroup[layer].vars.depthBuffer = true
				local depthBuffer = display.newGroup()
				depthBuffer.depthBuffer = true
				masterGroup[layer]:insert(depthBuffer)
				for j = 1, map.height * M.spriteSortResolution, 1 do
					local temp = display.newGroup()
					temp.layer = layer
					temp.isDepthBuffer = true
					masterGroup[layer][2]:insert(temp)
				end
			end
		end			
		
		local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
		local cameraX, cameraY = masterGroup[layer]:contentToLocal(tempX, tempY)
		local cameraLocX = math.ceil(cameraX / map.tilewidth)
		local cameraLocY = math.ceil(cameraY / map.tileheight)
		
		totalRects[layer] = 0
		local angle = masterGroup.rotation + masterGroup[layer].rotation
		while angle >= 360 do
			angle = angle - 360
		end
		while angle < 0 do
			angle = angle + 360
		end					
		local topLeftT, topRightT, bottomRightT, bottomLeftT
		topLeftT = {masterGroup.parent:localToContent(screenLeft - cullingMargin[1], screenTop - cullingMargin[2])}
		topRightT = {masterGroup.parent:localToContent(screenRight + cullingMargin[3], screenTop - cullingMargin[2])}
		bottomRightT = {masterGroup.parent:localToContent(screenRight + cullingMargin[3], screenBottom + cullingMargin[4])}
		bottomLeftT = {masterGroup.parent:localToContent(screenLeft - cullingMargin[1], screenBottom + cullingMargin[4])}				
		local topLeft, topRight, bottomRight, bottomLeft
		if angle >= 0 and angle < 90 then
			topLeft = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
			topRight = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
			bottomRight = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
			bottomLeft = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
		elseif angle >= 90 and angle < 180 then
			topLeft = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
			topRight = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
			bottomRight = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
			bottomLeft = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
		elseif angle >= 180 and angle < 270 then
			topLeft = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
			topRight = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
			bottomRight = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
			bottomLeft = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
		elseif angle >= 270 and angle < 360 then
			topLeft = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
			topRight = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
			bottomRight = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
			bottomLeft = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
		end
		local left, top, right, bottom
		if topLeft[1] < bottomLeft[1] then
			left = math.ceil(topLeft[1] / map.tilewidth)
		else
			left = math.ceil(bottomLeft[1] / map.tilewidth)
		end
		if topLeft[2] < topRight[2] then
			top = math.ceil(topLeft[2] / map.tileheight)
		else
			top = math.ceil(topRight[2] / map.tileheight)
		end
		if topRight[1] > bottomRight[1] then
			right = math.ceil(topRight[1] / map.tilewidth)
		else
			right = math.ceil(bottomRight[1] / map.tilewidth)
		end
		if bottomRight[2] > bottomLeft[2] then
			bottom = math.ceil(bottomRight[2] / map.tileheight)
		else
			bottom = math.ceil(bottomLeft[2] / map.tileheight)
		end				
		masterGroup[layer].vars.camera = {left, top, right, bottom}	
	end
	
	M.appendMap = function(src, dir, locX, locY, layer, overwrite)
		local layer = layer
		if not layer then
			layer = 1
		end
		
		local srcString = src
		local directory = ""
		local length = string.len(srcString)
		local codes = {string.byte("/"), string.byte(".")}
		local slashes = {}
		local periods = {}
		for i = 1, length, 1 do
			local test = string.byte(srcString, i)
			if test == codes[1] then
				slashes[#slashes + 1] = i
			elseif test == codes[2] then
				periods[#periods + 1] = i
			end
		end
		if #slashes > 0 then
			srcStringExt = string.sub(srcString, slashes[#slashes] + 1)
			directory = string.sub(srcString, 1, slashes[#slashes])
		else
			srcStringExt = srcString
		end
		if #periods > 0 then
			if periods[#periods] >= length - 6 then
				srcString = string.sub(srcString, (slashes[#slashes] or 0) + 1, (periods[#periods] or 0) - 1)
			else
				srcString = srcStringExt
			end
		else
			srcString = srcStringExt
		end
		local detectJsonExt = string.find(srcStringExt, ".json")
		if string.len(srcStringExt) ~= string.len(srcString) then
			if not detectJsonExt then
				--print("ERROR: "..src.." is not a Json file.")
			end
		else
			src = src..".json"
			detectJsonExt = true
		end	
		local path
		local base
		if dir == "Documents" then
			debugText = "Directory = DocumentsDirectory"
			path = system.pathForFile(src, system.DocumentsDirectory)
			base = system.DocumentsDirectory
		elseif dir == "Temporary" then
			debugText = "Directory = TemporaryDirectory"
			path = system.pathForFile(src, system.TemporaryDirectory)
			base = system.TemporaryDirectory
		elseif not dir or dir == "Resource" then
			debugText = "Directory = ResourceDirectory"
			path = system.pathForFile(src, system.ResourceDirectory)
			base = system.ResourceDirectory
		end	
		
		M.preloadMap(src, dir)
		
		--TILESETS
		--[[
		Loop through new map's tilesets and compare to parent map. If tileset already exists,
		adjust new maps tileID's to conform with the index of parent map's tileset.
		]]--
		if not map.adjustGID[src] then
			map.adjustGID[src] = {}
		end
		for i = 1, #mapStorage[src].tilesets, 1 do			
			local detect = false
			for j = 1, #map.tilesets, 1 do
				if map.tilesets[j].name == mapStorage[src].tilesets[i].name then
					detect = j
				end
			end
			
			if detect then
				--PROCESS TILE PROPERTIES
				if mapStorage[src].tilesets[i].tileproperties then
					if not map.tilesets[detect].tileproperties then
						map.tilesets[detect].tileproperties = mapStorage[src].tilesets[i].tileproperties
					else
						for key,value in pairs(mapStorage[src].tilesets[i].tileproperties) do
							if not map.tilesets[detect].tileproperties[key] then
								map.tilesets[detect].tileproperties[key] = value
							else
								for key2,value2 in pairs(mapStorage[src].tilesets[i].tileproperties[key]) do
									if not map.tilesets[detect].tileproperties[key][key2] then
										map.tilesets[detect].tileproperties[key][key2] = value2
									end
								end
							end
						end
					end
				end
				
				if i ~= detect then
					local newFirstGID = map.tilesets[detect].firstgid
					local oldFirstGID = mapStorage[src].tilesets[i].firstgid
					
					local tempTileWidth = map.tilesets[detect].tilewidth + (map.tilesets[detect].spacing)
					local tempTileHeight = map.tilesets[detect].tileheight + (map.tilesets[detect].spacing)
					local numFrames = math.floor(map.tilesets[detect].imagewidth / tempTileWidth) * math.floor(map.tilesets[detect].imageheight / tempTileHeight)
					
					map.adjustGID[src][#map.adjustGID[src] + 1] = {oldFirstGID, oldFirstGID + numFrames - 1, newFirstGID - oldFirstGID}
				end
				
			else
				--add tileset to table
				local tempTileWidth = map.tilesets[#map.tilesets].tilewidth + (map.tilesets[#map.tilesets].spacing)
				local tempTileHeight = map.tilesets[#map.tilesets].tileheight + (map.tilesets[#map.tilesets].spacing)
				local numFrames = math.floor(map.tilesets[#map.tilesets].imagewidth / tempTileWidth) * math.floor(map.tilesets[#map.tilesets].imageheight / tempTileHeight)
				local newFirstGID = map.tilesets[#map.tilesets].firstgid + numFrames
			
				local tempTileWidth = mapStorage[src].tilesets[i].tilewidth + (mapStorage[src].tilesets[i].spacing)
				local tempTileHeight = mapStorage[src].tilesets[i].tileheight + (mapStorage[src].tilesets[i].spacing)
				local oldFirstGID = mapStorage[src].tilesets[i].firstgid
				local oldNumFrames = math.floor(mapStorage[src].tilesets[i].imagewidth / tempTileWidth) * math.floor(mapStorage[src].tilesets[i].imageheight / tempTileHeight)
				
				map.adjustGID[src][#map.adjustGID[src] + 1] = {oldFirstGID, oldFirstGID + oldNumFrames - 1, newFirstGID - oldFirstGID}
				
				map.tilesets[#map.tilesets + 1] = mapStorage[src].tilesets[i]
				loadTileSet(#map.tilesets)
				map.tilesets[#map.tilesets].firstgid = newFirstGID
				
				--PROCESS TILE PROPERTIES
				if map.tilesets[#map.tilesets].tileproperties then
					local tileProps = map.tilesets[#map.tilesets].tileproperties
					for key,value in pairs(tileProps) do
						local tileProps2 = tileProps[key]
						for key2,value2 in pairs(tileProps[key]) do					
							if key2 == "animFrames" then
								tileProps2["animFrames"] = json.decode(value2)
								local tempFrames = json.decode(value2)
								if tileProps2["animFrameSelect"] == "relative" then
									local frames = {}
									for f = 1, #tempFrames, 1 do
										frames[f] = (tonumber(key) + 1) + tempFrames[f]
									end
									tileProps2["sequenceData"] = {
										name="null",
										frames=frames,
										time = tonumber(tileProps2["animDelay"]),
										loopCount = 0
									}
								elseif tileProps2["animFrameSelect"] == "absolute" then
									tileProps2["sequenceData"] = {
										name="null",
										frames=tempFrames,
										time = tonumber(tileProps2["animDelay"]),
										loopCount = 0
									}
								end
								tileProps2["animSync"] = tonumber(tileProps2["animSync"]) or 1
								if not syncData[tileProps2["animSync"] ] then
									syncData[tileProps2["animSync"] ] = {}
									syncData[tileProps2["animSync"] ].time = (tileProps2["sequenceData"].time / #tileProps2["sequenceData"].frames) / frameTime
									syncData[tileProps2["animSync"] ].currentFrame = 1
									syncData[tileProps2["animSync"] ].counter = syncData[tileProps2["animSync"] ].time
									syncData[tileProps2["animSync"] ].frames = tileProps2["sequenceData"].frames
								end
							end
							if key2 == "shape" then
								tileProps2["shape"] = json.decode(value2)
							end
							if key2 == "filter" then
								tileProps2["filter"] = json.decode(value2)
							end
							if key2 == "opacity" then					
								frameIndex = tonumber(key) + (map.tilesets[#map.tilesets].firstgid - 1) + 1
						
								if not map.lightingData[frameIndex] then
									map.lightingData[frameIndex] = {}
								end
								map.lightingData[frameIndex].opacity = json.decode(value2)
							end
						end
					end
				end		
				if not map.tilesets[#map.tilesets].properties then
					map.tilesets[#map.tilesets].properties = {}
				end			
				if map.tilesets[#map.tilesets].properties.normalMapSet then
					local tempTileWidth = map.tilesets[#map.tilesets].tilewidth + (map.tilesets[#map.tilesets].spacing)
					local tempTileHeight = map.tilesets[#map.tilesets].tileheight + (map.tilesets[#map.tilesets].spacing)
					local numFrames = math.floor(map.tilesets[#map.tilesets].imagewidth / tempTileWidth) * math.floor(map.tilesets[#map.tilesets].imageheight / tempTileHeight)
					local options = {width = map.tilesets[#map.tilesets].tilewidth, 
						height = map.tilesets[#map.tilesets].tileheight, 
						numFrames = numFrames, 
						border = map.tilesets[#map.tilesets].margin,
						sheetContentWidth = map.tilesets[#map.tilesets].imagewidth, 
						sheetContentHeight = map.tilesets[#map.tilesets].imageheight
					}
					local src = map.tilesets[#map.tilesets].properties.normalMapSet
					normalSets[#map.tilesets] = graphics.newImageSheet(src, options)
				end
				
			end
						
		end
		
		--Expand Map Bounds
		local storageWidth = mapStorage[src].width
		local storageHeight = mapStorage[src].height
		local storageOffsetX = mapStorage[src].locOffsetX
		local storageOffsetY = mapStorage[src].locOffsetY
		local left, top, right, bottom = 0, 0, 0, 0
		if locX < 1 - map.locOffsetX then
			left = (1 - map.locOffsetX) - locX
		end
		if locY < 1 - map.locOffsetY then
			top = (1 - map.locOffsetY) - locY
		end
		if locX + mapStorage[src].width > map.width - map.locOffsetX then
			right = (locX + mapStorage[src].width - 1) - (map.width - map.locOffsetX)
		end
		if locY + mapStorage[src].height > map.height - map.locOffsetY then
			bottom = (locY + mapStorage[src].height - 1) - (map.height - map.locOffsetY)
		end
		M.expandMapBounds({pushLeft = left, pushUp = top, pushRight = right, pushDown = bottom})
		
		for key,value in pairs(mapStorage[src].properties) do
			if not map.properties[key] then
				map.properties[key] = value
			end
		end
		
		--LAYERS
		--[[
		Loop through new maps layers and transfer the data over to the current (base) maps
		layers, adjusting for different firstgid's of tilesets. Check for new properties
		and add to current (base) layers. Check for new objects if layer is objectLayer and 
		add to current (base) objectLayers.
		]]--
		local action = {}
		local numMapLayers = #map.layers
		
		for i = #mapStorage[src].layers + layer - 1, 1, - 1 do
			local newIndex = i
			action[newIndex] = {}
			if newIndex > #map.layers and mapStorage[src].layers[i + 1 - layer] then
				action[newIndex][1] = "add"
				--print(newIndex, "1")
			elseif newIndex > #map.layers then
				M.createLayer(newIndex)
				--print(newIndex, "2")
			else
				--print(newIndex, "3")
				local mapLevel = tonumber(map.layers[i].properties.level)
				local srcLevel = tonumber(mapStorage[src].layers[i + 1 - layer].properties.level) or 1
				if srcLevel > mapLevel then
					local newLayers = 0
					for j = i + 1 - layer, 1 + 1 - layer, -1 do
						if mapStorage[src].layers[j] and mapStorage[src].layers[j].properties and mapStorage[src].layers[j].properties.level and
						tonumber(mapStorage[src].layers[j].properties.level) > tonumber(map.layers[#map.layers].properties.level) then
							newLayers = newLayers + 1
						end
					end
					local newLayer = #map.layers + newLayers
					--action[newIndex] = {"add", #map.layers + newLayers}
					action[newIndex] = {"add", newLayer}
					local diff = newLayer - newIndex
					--print(diff)
					for j = newIndex + 1, #mapStorage[src].layers + layer - 1, 1 do
						--print(" "..j)
						local temp1 = action[j][1]
						local temp2 = action[j][2]
						--print(j, temp1, temp2)
						action[j][2] = j + diff
					end
					
				else
					action[newIndex][1] = "process"
				end
			end
			--print(newIndex, action[newIndex][1], action[newIndex][2])
		end
		
		--[[
		for i = #mapStorage[src].layers + layer - 1, 1, - 1 do
			local newIndex = i
			print(newIndex, action[newIndex][1], action[newIndex][2])
		end 
		]]--
				
		for i = #mapStorage[src].layers, 1, -1 do
			local newIndex = i + layer - 1
			if action[newIndex][1] == "process" then
				local newIndex = i + layer - 1
				if not map.layers[newIndex] then
					map.layers[newIndex] = {}
				end
				for key,value in pairs(mapStorage[src].layers[i]) do
					if key == "properties" then
						for key,value in pairs(mapStorage[src].layers[i].properties) do
							if not map.layers[newIndex].properties then
								map.layers[newIndex].properties = {}
							end
							if not map.layers[newIndex].properties[key] then
								map.layers[newIndex].properties[key] = value
							end
						end
					elseif key == "objects" then
						local level = map.layers[newIndex].properties.level					
						local objectLayer = newIndex
						if not map.layers[newIndex].properties.objectLayer then
							objectLayer = M.getObjectLayer(level)
						end
						
						for j = 1, #mapStorage[src].layers[i].objects, 1 do
							map.layers[objectLayer].objects[#map.layers[objectLayer].objects + 1] = {}
							for key,value in pairs(mapStorage[src].layers[i].objects[j]) do
								map.layers[objectLayer].objects[#map.layers[objectLayer].objects][key] = value
								if key == "properties" then
									map.layers[objectLayer].objects[#map.layers[objectLayer].objects].properties = {}
									for key2,value2 in pairs(mapStorage[src].layers[i].objects[j].properties) do
										map.layers[objectLayer].objects[#map.layers[objectLayer].objects].properties[key2] = value2
									end
								end
							end
							map.layers[objectLayer].objects[#map.layers[objectLayer].objects].x = map.layers[objectLayer].objects[#map.layers[objectLayer].objects].x + ((locX - 1) * map.tilewidth)
							map.layers[objectLayer].objects[#map.layers[objectLayer].objects].y = map.layers[objectLayer].objects[#map.layers[objectLayer].objects].y + ((locY - 1) * map.tileheight)
						end
					elseif key == "world" and #value > 1 and not mapStorage[src].layers[i].objects then
						local dataLayer = newIndex	
						if map.layers[newIndex].objects or not (map.layers[newIndex].data or map.layers[newIndex].world) then
							dataLayer = refLayer
							for i = newIndex, 1, -1 do
								if (map.layers[i].data or map.layers[i].world) and not map.layers[i].objects then
									dataLayer = i
									break
								end
							end
						end
						
						for x = locX, locX + storageWidth - 1, 1 do
							local lx = x - locX + 1 - (mapStorage[src].locOffsetX or 0)
							for y = locY, locY + storageHeight - 1, 1 do
								local ly = y - locY + 1 - (mapStorage[src].locOffsetY or 0)
								
								if map.layers[dataLayer].world[x][y] == 0 or overwrite then
									--print(lx, ly, x, y, (mapStorage[src].locOffsetX or 0))
									map.layers[dataLayer].world[x][y] = mapStorage[src].layers[i].world[lx][ly]
								end

								for k = 1, #map.adjustGID[src], 1 do
									if map.layers[dataLayer].world[x][y] >= map.adjustGID[src][k][1] and map.layers[dataLayer].world[x][y] <= map.adjustGID[src][k][2] then
										map.layers[dataLayer].world[x][y] = map.layers[dataLayer].world[x][y] + map.adjustGID[src][k][3]
										break
									end
								end
								
								if enableFlipRotation then
									map.layers[dataLayer].flipRotation[x][y] = mapStorage[src].layers[i].flipRotation[lx][ly]
								end
								
								--find static lights
								if M.enableLighting then
									for key,value in pairs(mapStorage[src].lights) do
										map.lights[lightIDs] = value
										lightIDs = lightIDs + 1
									end
								end
							end
						end
					end
					--------------
				end
			elseif action[newIndex][1] == "add" then
				local newIndex = newIndex
				if action[newIndex][2] then
					newIndex = action[newIndex][2]
				end
				
				M.createLayer(newIndex)
				for key,value in pairs(mapStorage[src].layers[i]) do
					if type(value) ~= "table" then
						map.layers[newIndex][key] = value
					end
				end
				map.layers[newIndex].width = map.layers[refLayer].width
				map.layers[newIndex].height = map.layers[refLayer].height
				
				if mapStorage[src].layers[i].properties then
					for key,value in pairs(mapStorage[src].layers[i].properties) do
						map.layers[newIndex].properties[key] = value
					end
				end
				
				if mapStorage[src].layers[i].objects then
					map.layers[newIndex].objects = {}
					for key,value in pairs(mapStorage[src].layers[i].objects) do
						map.layers[newIndex].objects[key] = value
					end
					map.layers[newIndex].properties.objectLayer = true
				end
				
				if not map.layers[newIndex].properties.objectLayer then
					for x = locX, locX + storageWidth - 1, 1 do
						local lx = x - locX + 1
						for y = locY, locY + storageHeight - 1, 1 do
							local ly = y - locY + 1
							if map.layers[newIndex].world[x][y] == 0 then
								map.layers[newIndex].world[x][y] = mapStorage[src].layers[i].world[lx][ly]
							end
							
							for k = 1, #map.adjustGID[src], 1 do
								if map.layers[newIndex].world[x][y] >= map.adjustGID[src][k][1] and map.layers[newIndex].world[x][y] <= map.adjustGID[src][k][2] then
									map.layers[newIndex].world[x][y] = map.layers[newIndex].world[x][y] + map.adjustGID[src][k][3]
									break
								end
							end
						
							if enableFlipRotation then
								map.layers[newIndex].flipRotation[x][y] = mapStorage[src].layers[i].flipRotation[lx][ly]
							end
							
							--find static lights
							if M.enableLighting then
								for key,value in pairs(mapStorage[src].lights) do
									map.lights[lightIDs] = value
									lightIDs = lightIDs + 1
								end
							end
						end
					end
				end
				-----
			end
		end	
		
		M.setMapProperties(map.properties)
		--for i = 1, #map.layers, 1 do
			M.setLayerProperties(layer, map.layers[layer].properties)
		--end
	end
	
	M.loadMap = function(src, dir, unload)
		local startTime=system.getTimer()
		for key,value in pairs(sprites) do
			removeSprite(value)
		end
		if masterGroup then
			if map.orientation == 1 then
				if M.isoSort == 1 then
					for i = masterGroup.numChildren, 1, -1 do
						for j = map.height + map.width, 1, -1 do
							if masterGroup[i][j][1].tiles then
								for k = masterGroup[i][j][1].numChildren, 1, -1 do
									local locX = masterGroup[i][j][1][k].locX
									local locY = masterGroup[i][j][1][k].locY
									tileObjects[i][locX][locY]:removeSelf()
									tileObjects[i][locX][locY] = nil
								end
							end
							masterGroup[i][j]:removeSelf()
							masterGroup[i][j] = nil
						end
						masterGroup[i]:removeSelf()
						masterGroup[i] = nil
					end
				end
			else
				for i = masterGroup.numChildren, 1, -1 do
					if masterGroup[i][1].tiles then
						for j = masterGroup[i][1].numChildren, 1, -1 do
							local locX = masterGroup[i][1][j].locX
							local locY = masterGroup[i][1][j].locY
							tileObjects[i][locX][locY]:removeSelf()
							tileObjects[i][locX][locY] = nil
						end
					end
					if masterGroup[i].vars.depthBuffer then
						for j = masterGroup[i].numChildren, 1, -1 do
							masterGroup[i][j]:removeSelf()
							masterGroup[i][j] = nil
						end
					end
					masterGroup[i]:removeSelf()
					masterGroup[i] = nil
				end
			end
		end
		masterGroup = display.newGroup()
		masterGroup.x = screenCenterX
		masterGroup.y = screenCenterY		
		if unload and source then
			mapStorage[source] = nil
		end	
		tileSets = {}
		map = {}		
		spriteLayers = {}
		syncData = {}
		animatedTiles = {}
		refLayer = nil	
		local storageToggle = false	
		local srcString = src
		local directory = ""
		local length = string.len(srcString)
		local codes = {string.byte("/"), string.byte(".")}
		local slashes = {}
		local periods = {}
		for i = 1, length, 1 do
			local test = string.byte(srcString, i)
			if test == codes[1] then
				slashes[#slashes + 1] = i
			elseif test == codes[2] then
				periods[#periods + 1] = i
			end
		end
		if #slashes > 0 then
			srcStringExt = string.sub(srcString, slashes[#slashes] + 1)
			directory = string.sub(srcString, 1, slashes[#slashes])
		else
			srcStringExt = srcString
		end
		if #periods > 0 then
			if periods[#periods] >= length - 6 then
				srcString = string.sub(srcString, (slashes[#slashes] or 0) + 1, (periods[#periods] or 0) - 1)
			else
				srcString = srcStringExt
			end
		else
			srcString = srcStringExt
		end
		local detectJsonExt = string.find(srcStringExt, ".json")
		if string.len(srcStringExt) ~= string.len(srcString) then
			if not detectJsonExt then
				--print("ERROR: "..src.." is not a Json file.")
			end
		else
			src = src..".json"
			detectJsonExt = true
		end	
		local path
		local base
		if dir == "Documents" then
			source = src
			debugText = "Directory = DocumentsDirectory"
			path = system.pathForFile(src, system.DocumentsDirectory)
			debugText = "Path to file = "..path
			base = system.DocumentsDirectory
		elseif dir == "Temporary" then
			source = src
			debugText = "Directory = TemporaryDirectory"
			path = system.pathForFile(src, system.TemporaryDirectory)
			debugText = "Path to file = "..path
			base = system.TemporaryDirectory
		elseif not dir or dir == "Resource" then
			source = src
			debugText = "Directory = ResourceDirectory"
			path = system.pathForFile(src, system.ResourceDirectory)
			debugText = "Path to file = "..path	
			base = system.ResourceDirectory
		end		
		if detectJsonExt then
			--LOAD JSON FILE	
			local saveData = io.open(path, "r")
			debugText = "saveData stream opened"
			if saveData then
				local jsonData = saveData:read("*a")
				debugText = "jsonData read"
		
				if not mapStorage[src] then
					mapStorage[src] = json.decode(jsonData)
					map = mapStorage[src]
				else
					map = mapStorage[src]
					storageToggle = true
				end
			
				debugText = "jsonData decoded"
				io.close(saveData)
				debugText = "io stream closed"
				print(src.." loaded")
				debugText = src.." loaded"
				M.mapPath = source
			else
				print("ERROR: Map Not Found")
				debugText = "ERROR: Map Not Found"
			end
		else
			if not mapStorage[src] then
				------------------------------------------------------------------------------
				xml.ParseXmlText = function(xmlText)
					if not mapStorage[src] then
						mapStorage[src] = {}
					end
					local layerIndex = 0
				
					local stack = {}
					local top = {name=nil,value=nil,properties={},child={}}
					table.insert(stack, top)
					local ni,c,label,xarg, empty
					local i, j = 1, 1
					local triggerBase64 = false
					local triggerXML = false
					local triggerCSV = false
					local x, y = 1, 1
					while true do
						local ni,j,c,label,xarg, empty = string.find(xmlText, "<(%/?)([%w:]+)(.-)(%/?)>", i)
						if not ni then break end
						local text = string.sub(xmlText, i, ni-1);
						if not string.find(text, "^%s*$") then
							top.value=(top.value or "")..xml.FromXmlString(text);
							if triggerBase64 then
								triggerBase64 = false
								--decode base64 directly into map array
								--------------------------------------------------------------
								local floor = math.floor
								local buffer = 0
								local pos = 1
								local bin ={}
								local mult = 1
								for i = 1,40 do
									bin[i] = mult
									mult = mult*2
								end
								local base64 = { ['A']=0,['B']=1,['C']=2,['D']=3,['E']=4,['F']=5,['G']=6,['H']=7,['I']=8,
												 ['J']=9,['K']=10,['L']=11,['M']=12,['N']=13,['O']=14,['P']=15,['Q']=16,
												 ['R']=17,['S']=18,['T']=19,['U']=20,['V']=21,['W']=22,['X']=23,['Y']=24,
												 ['Z']=25,['a']=26,['b']=27,['c']=28,['d']=29,['e']=30,['f']=31,['g']=32,
												 ['h']=33,['i']=34,['j']=35,['k']=36,['l']=37,['m']=38,['n']=39,['o']=40,
												 ['p']=41,['q']=42,['r']=43,['s']=44,['t']=45,['u']=46,['v']=47,['w']=48,
												 ['x']=49,['y']=50,['z']=51,['0']=52,['1']=53,['2']=54,['3']=55,['4']=56,
												 ['5']=57,['6']=58,['7']=59,['8']=60,['9']=61,['+']=62,['/']=63,['=']=nil
								}
								local set = "[^%a%d%+%/%=]"
								data = string.gsub(top.value, set, "")    
								local size = 32
								local val = {}
								local rawPos = 1
								local rawSize = #top.value
								local char = ""

								while rawPos <= rawSize do
									while pos <= size and rawPos <= rawSize do
										char = string.sub(top.value,rawPos,rawPos)
										if base64[char] ~= nil then
											buffer = buffer * bin[7] + base64[char]
											pos = pos + 6
										end
										rawPos = rawPos + 1
									end
									if char == "=" then 
										break 
									end

									while pos < 33 do 
										buffer = buffer * bin[2] 
										pos = pos + 1
									end
									pos = pos - 32
									mapStorage[src].layers[layerIndex].data[#mapStorage[src].layers[layerIndex].data+1] = floor((buffer%bin[33+pos-1])/bin[25+pos-1]) +
												  floor((buffer%bin[25+pos-1])/bin[17+pos-1])*bin[9] +
												  floor((buffer%bin[17+pos-1])/bin[9+pos-1])*bin[17] + 
												  floor((buffer%bin[9+pos-1])/bin[pos])*bin[25]
									buffer = buffer % bin[pos]    	
								end
								--------------------------------------------------------------
							end
							if triggerCSV then
								triggerCSV = false
								mapStorage[src].layers[layerIndex].data = json.decode("["..top.value.."]")
							end
						end
						if empty == "/" then  -- empty element tag
							if label == "tile" then
								mapStorage[src].layers[layerIndex].data[#mapStorage[src].layers[layerIndex].data + 1] = tonumber(xarg:sub(7, xarg:len() - 1))
							else
								table.insert(top.child, {name=label,value=nil,properties=xml.ParseArgs(xarg),child={}})
							end
							if label == "layer" or label == "objectgroup" or label == "imagelayer"  then
								layerIndex = layerIndex + 1
								if not mapStorage[src].layers then
									mapStorage[src].layers = {}
								end
								mapStorage[src].layers[layerIndex] = {}
								mapStorage[src].layers[layerIndex].properties = {}
							end
						elseif c == "" then   -- start tag
							local props = xml.ParseArgs(xarg)
							top = {name=label, value=nil, properties=props, child={}}
							table.insert(stack, top)   -- new level
							if label == "map" then
								--
							end
							if label == "layer" or label == "objectgroup" or label == "imagelayer" then
								layerIndex = layerIndex + 1
								x, y = 1, 1
								if not mapStorage[src].layers then
									mapStorage[src].layers = {}
								end
								mapStorage[src].layers[layerIndex] = {}
								mapStorage[src].layers[layerIndex].properties = {}
								if label == "layer" then
									mapStorage[src].layers[layerIndex].data = {}
									mapStorage[src].layers[layerIndex].world = {}
									mapStorage[src].layers[layerIndex].world[1] = {}
								end
							end
							if label == "data" then
								if props.encoding == "base64" then
									triggerBase64 = true
									if props.compression then
										print("Error(loadMap): Layer data compression is not supported. MTE supports CSV, TMX, and Base64(uncompressed).")
									end
								elseif props.encoding == "csv" then
									triggerCSV = true
								elseif not props.encoding then
									tirggerXML = true
								end
							end
						else  -- end tag
							local toclose = table.remove(stack)  -- remove top
							top = stack[#stack]
							if #stack < 1 then
								error("XmlParser: nothing to close with "..label)
							end
							if toclose.name ~= label then
								error("XmlParser: trying to close "..toclose.name.." with "..label)
							end
							table.insert(top.child, toclose)
						end
						i = j+1
					end
					local text = string.sub(xmlText, i);
					if not string.find(text, "^%s*$") then
						stack[#stack].value=(stack[#stack].value or "")..xml.FromXmlString(text);
					end
						if #stack > 1 then
							error("XmlParser: unclosed "..stack[stack.n].name)
						end
					return stack[1].child[1];
				end

				xml.loadFile = function(xmlFilename, base)
					if not base then
						base = system.ResourceDirectory
					end

					local path = system.pathForFile( xmlFilename, base )
					local hFile, err = io.open(path,"r");

					if hFile and not err then
						local xmlText=hFile:read("*a"); -- read file content
						io.close(hFile);
						return xml.ParseXmlText(xmlText),nil;
					else
						print( err )
						return nil
					end
				end
				------------------------------------------------------------------------------
				--LOAD TMX FILE
				local temp = xml.loadFile(source, base)
				if temp then
					for key,value in pairs(temp.properties) do
						mapStorage[src][key] = value
						if key == "height" or key == "tileheight" or key == "tilewidth" or key == "width" then
							mapStorage[src][key] = tonumber(mapStorage[src][key])
						end
					end
					mapStorage[src].tilesets = {}
					mapStorage[src].properties = {}
					local layerIndex = 1
					local tileSetIndex = 1
				
					for i = 1, #temp.child, 1 do
						if temp.child[i].name == "properties" then
							for j = 1, #temp.child[i].child, 1 do
								mapStorage[src].properties[temp.child[i].child[j].properties.name] = temp.child[i].child[j].properties.value
							end
						end
					
						if temp.child[i].name == "imagelayer" then
							for key,value in pairs(temp.child[i].properties) do
								mapStorage[src].layers[layerIndex][key] = value
								if key == "width" or key == "height" then
									mapStorage[src].layers[layerIndex][key] = tonumber(mapStorage[src].layers[layerIndex][key])
								end
							end
							for j = 1, #temp.child[i].child, 1 do
								if temp.child[i].child[j].name == "properties" then
									for k = 1, #temp.child[i].child[j].child, 1 do
										mapStorage[src].layers[layerIndex].properties[temp.child[i].child[j].child[k].properties.name] = temp.child[i].child[j].child[k].properties.value
									end
								end
							
								if temp.child[i].child[j].name == "image" then 
									mapStorage[src].layers[layerIndex]["image"] = temp.child[i].child[j].properties["source"]
								end
							end
						
							layerIndex = layerIndex + 1
						end
					
						if temp.child[i].name == "layer" then
							for key,value in pairs(temp.child[i].properties) do
								mapStorage[src].layers[layerIndex][key] = value
								if key == "width" or key == "height" then
									mapStorage[src].layers[layerIndex][key] = tonumber(mapStorage[src].layers[layerIndex][key])
								end
							end
							for j = 1, #temp.child[i].child, 1 do
								if temp.child[i].child[j].name == "properties" then
									for k = 1, #temp.child[i].child[j].child, 1 do
										mapStorage[src].layers[layerIndex].properties[temp.child[i].child[j].child[k].properties.name] = temp.child[i].child[j].child[k].properties.value
									end
								end
							end
							layerIndex = layerIndex + 1
						end
					
						if temp.child[i].name == "objectgroup" then
							for key,value in pairs(temp.child[i].properties) do
								mapStorage[src].layers[layerIndex][key] = value
								if key == "width" or key == "height" then
									mapStorage[src].layers[layerIndex][key] = tonumber(mapStorage[src].layers[layerIndex][key])
								end
							end
							mapStorage[src].layers[layerIndex]["width"] = mapStorage[src]["width"]
							mapStorage[src].layers[layerIndex]["height"] = mapStorage[src]["height"]
							mapStorage[src].layers[layerIndex].objects = {}
							local firstObject = true
							local indexMod = 0
							for j = 1, #temp.child[i].child, 1 do
								if temp.child[i].child[j].name == "properties" then
									for k = 1, #temp.child[i].child[j].child, 1 do
										mapStorage[src].layers[layerIndex].properties[temp.child[i].child[j].child[k].properties.name] = temp.child[i].child[j].child[k].properties.value
									end
								end
								if temp.child[i].child[j].name == "object" then
									if firstObject then
										firstObject = false
										indexMod = j - 1
									end
									mapStorage[src].layers[layerIndex].objects[j-indexMod] = {}
									for key,value in pairs(temp.child[i].child[j].properties) do
										mapStorage[src].layers[layerIndex].objects[j-indexMod][key] = value
										if key == "width" or key == "height" or key == "x" or key == "y" or key == "gid" then
											mapStorage[src].layers[layerIndex].objects[j-indexMod][key] = tonumber(mapStorage[src].layers[layerIndex].objects[j-indexMod][key])
										end
									end	
									if not mapStorage[src].layers[layerIndex].objects[j-indexMod].width then
										mapStorage[src].layers[layerIndex].objects[j-indexMod].width = 0
									end				
									if not mapStorage[src].layers[layerIndex].objects[j-indexMod].height then
										mapStorage[src].layers[layerIndex].objects[j-indexMod].height = 0
									end	
									--------
									mapStorage[src].layers[layerIndex].objects[j-indexMod].properties = {}
								
									for k = 1, #temp.child[i].child[j].child, 1 do
										if temp.child[i].child[j].child[k].name == "properties" then
											for m = 1, #temp.child[i].child[j].child[k].child, 1 do	
												mapStorage[src].layers[layerIndex].objects[j-indexMod].properties[temp.child[i].child[j].child[k].child[m].properties.name] = temp.child[i].child[j].child[k].child[m].properties.value								
											end
										end
										if temp.child[i].child[j].child[k].name == "polygon" then
											mapStorage[src].layers[layerIndex].objects[j-indexMod].polygon = {}
											local pointString = temp.child[i].child[j].child[k].properties.points
											local codes = {string.byte(","), string.byte(" ")}
											local stringIndexStart = 1
											local pointIndex = 1
									
											for s = 1, string.len(pointString), 1 do
												if string.byte(pointString, s, s) == codes[1] then
													mapStorage[src].layers[layerIndex].objects[j-indexMod].polygon[pointIndex] = {}
													mapStorage[src].layers[layerIndex].objects[j-indexMod].polygon[pointIndex].x = tonumber(string.sub(pointString, stringIndexStart, s - 1))
													stringIndexStart = s + 1
												end
												if string.byte(pointString, s, s) == codes[2] then
													mapStorage[src].layers[layerIndex].objects[j-indexMod].polygon[pointIndex].y = tonumber(string.sub(pointString, stringIndexStart, s - 1))
													stringIndexStart = s + 1
													pointIndex = pointIndex + 1
												end
												if s == string.len(pointString) then
													mapStorage[src].layers[layerIndex].objects[j-indexMod].polygon[pointIndex].y = tonumber(string.sub(pointString, stringIndexStart, s))
												end
											end
										end
										if temp.child[i].child[j].child[k].name == "polyline" then
											mapStorage[src].layers[layerIndex].objects[j-indexMod].polyline = {}
											local pointString = temp.child[i].child[j].child[k].properties.points
											local codes = {string.byte(","), string.byte(" ")}
											local stringIndexStart = 1
											local pointIndex = 1
									
											for s = 1, string.len(pointString), 1 do
												if string.byte(pointString, s, s) == codes[1] then
													mapStorage[src].layers[layerIndex].objects[j-indexMod].polyline[pointIndex] = {}
													mapStorage[src].layers[layerIndex].objects[j-indexMod].polyline[pointIndex].x = tonumber(string.sub(pointString, stringIndexStart, s - 1))
													stringIndexStart = s + 1
												end
												if string.byte(pointString, s, s) == codes[2] then
													mapStorage[src].layers[layerIndex].objects[j-indexMod].polyline[pointIndex].y = tonumber(string.sub(pointString, stringIndexStart, s - 1))
													stringIndexStart = s + 1
													pointIndex = pointIndex + 1
												end
												if s == string.len(pointString) then
													mapStorage[src].layers[layerIndex].objects[j-indexMod].polyline[pointIndex].y = tonumber(string.sub(pointString, stringIndexStart, s))
												end
											end
										end
										if temp.child[i].child[j].child[k].name == "ellipse" then
											mapStorage[src].layers[layerIndex].objects[j-indexMod].ellipse = true
										end
									end
								end
							end
							layerIndex = layerIndex + 1
						end

						if temp.child[i].name == "tileset" then
							mapStorage[src].tilesets[tileSetIndex] = {}
						
							if temp.child[i].properties.source then
								local tempSet = xml.loadFile(directory..temp.child[i].properties.source)
								if not tempSet.properties.spacing then 
									tempSet.properties.spacing = 0
								end
								if not tempSet.properties.margin then
									tempSet.properties.margin = 0
								end
								for key,value in pairs(tempSet.properties) do
									mapStorage[src].tilesets[tileSetIndex][key] = value
									if key == "tilewidth" or key == "tileheight" or key == "spacing" or key == "margin" then
										mapStorage[src].tilesets[tileSetIndex][key] = tonumber(mapStorage[src].tilesets[tileSetIndex][key])
									end
								end
							
							
								for j = 1, #tempSet.child, 1 do
									if tempSet.child[j].name == "properties" then
										mapStorage[src].tilesets[tileSetIndex].properties = {}
										for k = 1, #tempSet.child[j].child, 1 do
											mapStorage[src].tilesets[tileSetIndex].properties[tempSet.child[j].child[k].properties.name] = tempSet.child[j].child[k].properties.value
										end
									end
									if tempSet.child[j].name == "image" then
										for key,value in pairs(tempSet.child[j].properties) do
											if key == "source" then
												mapStorage[src].tilesets[tileSetIndex]["image"] = directory..value
											elseif key == "width" then
												mapStorage[src].tilesets[tileSetIndex]["imagewidth"] = tonumber(value)
											elseif key == "height" then
												mapStorage[src].tilesets[tileSetIndex]["imageheight"] = tonumber(value)
											else
												mapStorage[src].tilesets[tileSetIndex][key] = value
											end															
										end									
									end
									if tempSet.child[j].name == "tile" then
										if not mapStorage[src].tilesets[tileSetIndex].tileproperties then
											mapStorage[src].tilesets[tileSetIndex].tileproperties = {}
										end
										mapStorage[src].tilesets[tileSetIndex].tileproperties[tempSet.child[j].properties.id] = {}
									
										for k = 1, #tempSet.child[j].child, 1 do
											if tempSet.child[j].child[k].name == "properties" then
												for m = 1, #tempSet.child[j].child[k].child, 1 do
													local name = tempSet.child[j].child[k].child[m].properties.name
													local value = tempSet.child[j].child[k].child[m].properties.value
													mapStorage[src].tilesets[tileSetIndex].tileproperties[tempSet.child[j].properties.id][name] = value
												end
											end
										end
									end
								end							
							else
								local tempSet = temp.child[i]
								if not tempSet.properties.spacing then 
									tempSet.properties.spacing = 0
								end
								if not tempSet.properties.margin then
									tempSet.properties.margin = 0
								end
								for key,value in pairs(tempSet.properties) do
									mapStorage[src].tilesets[tileSetIndex][key] = value
									if key == "tilewidth" or key == "tileheight" or key == "spacing" or key == "margin" then
										mapStorage[src].tilesets[tileSetIndex][key] = tonumber(mapStorage[src].tilesets[tileSetIndex][key])
									end
								end							
							
								for j = 1, #tempSet.child, 1 do
									if tempSet.child[j].name == "properties" then
										mapStorage[src].tilesets[tileSetIndex].properties = {}
										for k = 1, #tempSet.child[j].child, 1 do
											mapStorage[src].tilesets[tileSetIndex].properties[tempSet.child[j].child[k].properties.name] = tempSet.child[j].child[k].properties.value
										end
									end
									if tempSet.child[j].name == "image" then
										for key,value in pairs(tempSet.child[j].properties) do
											if key == "source" then
												mapStorage[src].tilesets[tileSetIndex]["image"] = directory..value
											elseif key == "width" then
												mapStorage[src].tilesets[tileSetIndex]["imagewidth"] = tonumber(value)
											elseif key == "height" then
												mapStorage[src].tilesets[tileSetIndex]["imageheight"] = tonumber(value)
											else
												mapStorage[src].tilesets[tileSetIndex][key] = value
											end															
										end									
									end
									if tempSet.child[j].name == "tile" then
										if not mapStorage[src].tilesets[tileSetIndex].tileproperties then
											mapStorage[src].tilesets[tileSetIndex].tileproperties = {}
										end
										mapStorage[src].tilesets[tileSetIndex].tileproperties[tempSet.child[j].properties.id] = {}
									
										for k = 1, #tempSet.child[j].child, 1 do
											if tempSet.child[j].child[k].name == "properties" then
												for m = 1, #tempSet.child[j].child[k].child, 1 do
													local name = tempSet.child[j].child[k].child[m].properties.name
													local value = tempSet.child[j].child[k].child[m].properties.value
													mapStorage[src].tilesets[tileSetIndex].tileproperties[tempSet.child[j].properties.id][name] = value
												end
											end
										end
									end
								end
							end
							mapStorage[src].tilesets[tileSetIndex].firstgid = tonumber(temp.child[i].properties.firstgid)
							tileSetIndex = tileSetIndex + 1
						end
					end
				else
					print("ERROR: Map Not Found")
					debugText = "ERROR: Map Not Found"
				end

				map = mapStorage[src]				
			else
				map = mapStorage[src]				
				storageToggle = true
			end		
		end
		
		if not map.isoRatio then
			map.isoRatio = map.tilewidth / map.tileheight
		end
		if not map.locOffsetX then
			map.locOffsetX = 0
		end
		if not map.locOffsetY then
			map.locOffsetY = 0
		end
		if not map.adjustGID then
			map.adjustGID = {}
		end
		map.width = map.width
		map.height = map.height
		print("World Size X: "..map.width)
		print("World Size Y: "..map.height)
		map.numLevels = 1		
		if map.properties.defaultNormalMap then
			map.defaultNormalMap = map.properties.defaultNormalMap
		end
		if map.properties.wrap then
			if map.properties.wrap == "true" then
				worldWrapX = true
				worldWrapY = true
			elseif map.properties.wrap == "false" then
				worldWrapX = false
				worldWrapY = false
			end
		end
		if map.properties.wrapX then
			if map.properties.wrapX == "true" then
				worldWrapX = true
			elseif map.properties.wrapX == "false" then
				worldWrapX = false
			end
		end
		if map.properties.wrapY then
			if map.properties.wrapY == "true" then
				worldWrapY = true
			elseif map.properties.wrapY == "false" then
				worldWrapY = false
			end
		end
		if not map.modified then
			if map.properties.lightLayerFalloff then
				map.properties.lightLayerFalloff = json.decode(map.properties.lightLayerFalloff)
			else
				map.properties.lightLayerFalloff = {0, 0, 0}
			end
			if map.properties.lightLevelFalloff then
				map.properties.lightLevelFalloff = json.decode(map.properties.lightLevelFalloff)
			else
				map.properties.lightLevelFalloff = {1, 1, 1}
			end
		end
		local globalID = {}
		local prevLevel = "1"	
		map.lightingData = {}
		if M.enableLighting then
			map.lastLightUpdate = system.getTimer()
			if not map.lights then
				map.lights = {}
			end
		end		
		if not storageToggle then
			if not map.modified then
				if map.orientation == "orthogonal" then
					map.orientation = 0
				elseif map.orientation == "isometric" then
					map.orientation = 1
				elseif map.orientation == "staggered" then
					map.orientation = 2
				end
			end
		end		
		worldScaleX = map.tilewidth
		worldScaleY = map.tileheight
		if map.orientation == 1 then
			if M.isoSort == 1 then
				for i = 1, #map.layers, 1 do
					local group = display.newGroup()
					masterGroup:insert(group)
					masterGroup[i].vars = {alpha = 1}
					masterGroup[i].vars.layer = i
					for j = 1, map.height + map.width, 1 do
						local row = display.newGroup()
						row.layer = i
						masterGroup[i]:insert(row)
						local tiles = display.newGroup()
						tiles.tiles = true
						masterGroup[i][j]:insert(tiles)
					end
				end
			end
		else
			for i = 1, #map.layers, 1 do
				local group = display.newGroup()
				masterGroup:insert(group)
				local tiles = display.newGroup()
				tiles.tiles = true
				masterGroup[i]:insert(tiles)
				masterGroup[i].vars = {alpha = 1}
				masterGroup[i].vars.layer = i		
				if M.enableSpriteSorting then
					if map.layers[i].properties.spriteLayer then
						masterGroup[i].vars.depthBuffer = true
						local depthBuffer = display.newGroup()
						depthBuffer.depthBuffer = true
						masterGroup[i]:insert(depthBuffer)
						for j = 1, map.height * M.spriteSortResolution, 1 do
							local temp = display.newGroup()
							temp.layer = i
							temp.isDepthBuffer = true
							masterGroup[i][2]:insert(temp)
						end
					end
				end
			end
		end
		
		--TILESETS
		map.numFrames = {}
		for i = 1, #map.tilesets, 1 do
			loadTileSet(i)	
			--PROCESS TILE PROPERTIES
			if map.tilesets[i].tileproperties then
				local tileProps = map.tilesets[i].tileproperties
				for key,value in pairs(tileProps) do
					local tileProps2 = tileProps[key]
					for key2,value2 in pairs(tileProps[key]) do					
						if key2 == "animFrames" then
							tempFrames = value2
							if type(value2) == "string" then
								tileProps2["animFrames"] = json.decode(value2)
								tempFrames = json.decode(value2)
							end
							if tileProps2["animFrameSelect"] == "relative" then
								local frames = {}
								for f = 1, #tempFrames, 1 do
									frames[f] = (tonumber(key) + 1) + tempFrames[f]
								end
								tileProps2["sequenceData"] = {
									name="null",
									frames=frames,
									time = tonumber(tileProps2["animDelay"]),
									loopCount = 0
								}
							elseif tileProps2["animFrameSelect"] == "absolute" then
								tileProps2["sequenceData"] = {
									name="null",
									frames=tempFrames,
									time = tonumber(tileProps2["animDelay"]),
									loopCount = 0
								}
							end
							tileProps2["animSync"] = tonumber(tileProps2["animSync"]) or 1
							if not syncData[tileProps2["animSync"] ] then
								syncData[tileProps2["animSync"] ] = {}
								syncData[tileProps2["animSync"] ].time = (tileProps2["sequenceData"].time / #tileProps2["sequenceData"].frames) / frameTime
								syncData[tileProps2["animSync"] ].currentFrame = 1
								syncData[tileProps2["animSync"] ].counter = syncData[tileProps2["animSync"] ].time
								syncData[tileProps2["animSync"] ].frames = tileProps2["sequenceData"].frames
							end
						end
						if key2 == "shape" and type(value2) == "string" then
							tileProps2["shape"] = json.decode(value2)
						end
						if key2 == "filter" and type(value2) == "string" then
							tileProps2["filter"] = json.decode(value2)
						end
						if key2 == "opacity" then					
							frameIndex = tonumber(key) + (map.tilesets[i].firstgid - 1) + 1
						
							if not map.lightingData[frameIndex] then
								map.lightingData[frameIndex] = {}
							end
							map.lightingData[frameIndex].opacity = json.decode(value2)
						end
					end
				end
			end		
			if not map.tilesets[i].properties then
				map.tilesets[i].properties = {}
			end			
			if map.tilesets[i].properties.normalMapSet then
				local tempTileWidth = map.tilesets[i].tilewidth + (map.tilesets[i].spacing)
				local tempTileHeight = map.tilesets[i].tileheight + (map.tilesets[i].spacing)
				local numFrames = math.floor(map.tilesets[i].imagewidth / tempTileWidth) * math.floor(map.tilesets[i].imageheight / tempTileHeight)
				local options = {width = map.tilesets[i].tilewidth, 
					height = map.tilesets[i].tileheight, 
					numFrames = numFrames, 
					border = map.tilesets[i].margin,
					sheetContentWidth = map.tilesets[i].imagewidth, 
					sheetContentHeight = map.tilesets[i].imageheight
				}
				local src = map.tilesets[i].properties.normalMapSet
				normalSets[i] = graphics.newImageSheet(src, options)
			end
		end
		
		local refLayer1, refLayer2
		for i = 1, #map.layers, 1 do			
			--CHECK AND LOAD SCALE AND LEVELS
			if not map.layers[i].properties then
				map.layers[i].properties = {}
				map.layers[i].properties.level = "1"
				map.layers[i].properties.scaleX = 1
				map.layers[i].properties.scaleY = 1
				map.layers[i].properties.parallaxX = 1
				map.layers[i].properties.parallaxY = 1
			else
				if not map.layers[i].properties.level then
					map.layers[i].properties.level = "1"
				end
				if map.layers[i].properties.scale then
					map.layers[i].properties.scaleX = map.layers[i].properties.scale
					map.layers[i].properties.scaleY = map.layers[i].properties.scale
				else
					if not map.layers[i].properties.scaleX then
						map.layers[i].properties.scaleX = 1
					end
					if not map.layers[i].properties.scaleY then
						map.layers[i].properties.scaleY = 1
					end
				end
			end
			
			if type(map.layers[i].properties.forceDefaultPhysics) == "string" then
				if map.layers[i].properties.forceDefaultPhysics == "true" then
					map.layers[i].properties.forceDefaultPhysics = true
				else
					map.layers[i].properties.forceDefaultPhysics = false
				end
			end
			
			map.layers[i].toggleParallax = false
			
			map.layers[i].properties.scaleX = tonumber(map.layers[i].properties.scaleX)
			map.layers[i].properties.scaleY = tonumber(map.layers[i].properties.scaleY)
			if map.layers[i].properties.parallax then
				map.layers[i].parallaxX = map.layers[i].properties.parallax / map.layers[i].properties.scaleX
				map.layers[i].parallaxY = map.layers[i].properties.parallax / map.layers[i].properties.scaleY
				map.layers[i].toggleParallax = true
			else
				if map.layers[i].properties.parallaxX then
					map.layers[i].parallaxX = map.layers[i].properties.parallaxX / map.layers[i].properties.scaleX
					map.layers[i].toggleParallax = true
				else
					map.layers[i].parallaxX = 1
				end
				if map.layers[i].properties.parallaxY then
					map.layers[i].parallaxY = map.layers[i].properties.parallaxY / map.layers[i].properties.scaleY
					map.layers[i].toggleParallax = true
				else
					map.layers[i].parallaxY = 1
				end
			end	
			--DETECT WIDTH AND HEIGHT
			if map.layers[i].properties.width then
				map.layers[i].width = tonumber(map.layers[i].properties.width)
			end
			if map.layers[i].properties.height then
				map.layers[i].height = tonumber(map.layers[i].properties.height)
			end
			--DETECT LAYER WRAP
			layerWrapX[i] = worldWrapX
			layerWrapY[i] = worldWrapY
			if map.layers[i].properties.wrap then
				if map.layers[i].properties.wrap == "true" then
					layerWrapX[i] = true
					layerWrapY[i] = true
				elseif map.layers[i].properties.wrap == "false" then
					layerWrapX[i] = false
					layerWrapY[i] = false
				end
			end
			if map.layers[i].properties.wrapX then
				if map.layers[i].properties.wrapX == "true" then
					layerWrapX[i] = true
				elseif map.layers[i].properties.wrapX == "false" then
					layerWrapX[i] = false
				end
			end
			if map.layers[i].properties.wrapY then
				if map.layers[i].properties.wrapY == "true" then
					layerWrapY[i] = true
				elseif map.layers[i].properties.wrapY == "false" then
					layerWrapY[i] = false
				end
			end
			--TOGGLE PARALLAX CROP
			if map.layers[i].properties.toggleParallaxCrop == "true" then
				map.layers[i].width = math.floor(map.layers[i].width * map.layers[i].parallaxX)
				map.layers[i].height = math.floor(map.layers[i].height * map.layers[i].parallaxY)
				if map.layers[i].width > map.width then
					map.layers[i].width = map.width
				end
				if map.layers[i].height > map.height then
					map.layers[i].height = map.height
				end
				map.layers[i].toggleParallax = true
			end		
			--FIT BY PARALLAX / FIT BY SCALE
			if map.layers[i].properties.fitByParallax then
				map.layers[i].parallaxX = (map.layers[i].width / map.width) * map.layers[i].properties.scaleX * (map.layers[i].width * map.layers[i].properties.scaleX / map.width)
				--map.layers[i].parallaxX = ((map.layers[i].width * map.layers[i].properties.scaleX) / map.width)
				map.layers[i].parallaxY = (map.layers[i].height / map.height) * map.layers[i].properties.scaleY * (map.layers[i].height * map.layers[i].properties.scaleY / map.height)
				--map.layers[i].parallaxY = (map.layers[i].height / map.height) --* map.layers[i].properties.scaleY
				--map.layers[i].parallaxY = ((map.layers[i].height * map.layers[i].properties.scaleY) / map.height)
				map.layers[i].toggleParallax = true
			else
				if map.layers[i].properties.fitByScale then
					map.layers[i].properties.scaleX = (map.width * map.layers[i].properties.parallaxX) / map.layers[i].width
					map.layers[i].properties.scaleY = (map.height * map.layers[i].properties.parallaxY) / map.layers[i].height
					map.layers[i].toggleParallax = true
				end
			end
			if map.layers[i].parallaxX == 1 and map.layers[i].parallaxY == 1 and map.layers[i].properties.scaleX == 1 and map.layers[i].properties.scaleY == 1 then
				if not refLayer1 then
					refLayer1 = tonumber(i)
				end
			elseif map.layers[i].parallaxX == 1 and map.layers[i].parallaxY == 1 then
				if not refLayer2 then
					refLayer2 = tonumber(i)
				end
			end		
			if map.layers[i].parallaxX ~= 1 or map.layers[i].parallaxY ~= 1 or map.layers[i].toggleParallax == true then
				parallaxToggle[i] = true
			end
			if M.enableLighting then
				if not map.layers[i].lighting then
					map.layers[i].lighting = {}
				end
			end
		
			----------------------------------------------------------------------------------
			local hex2bin = {
				["0"] = "0000",
				["1"] = "0001",
				["2"] = "0010",
				["3"] = "0011",
				["4"] = "0100",
				["5"] = "0101",
				["6"] = "0110",
				["7"] = "0111",
				["8"] = "1000",
				["9"] = "1001",
				["a"] = "1010",
				["b"] = "1011",
				["c"] = "1100",
				["d"] = "1101",
				["e"] = "1110",
				["f"] = "1111"
			}
	
			local Hex2Bin = function(s)
				local ret = ""
				local i = 0
				for i in string.gfind(s, ".") do
					i = string.lower(i)

					ret = ret..hex2bin[i]
				end
				return ret
			end
		
			local Bin2Dec = function(s)	
				local num = 0
				local ex = string.len(s) - 1
				local l = 0
				l = ex + 1
				for i = 1, l do
					b = string.sub(s, i, i)
					if b == "1" then
						num = num + 2^ex
					end
					ex = ex - 1
				end
				return string.format("%u", num)
			end
		
			local Dec2Bin = function(s, num)
				local n
				if (num == nil) then
					n = 0
				else
					n = num
				end
				s = string.format("%x", s)
				s = Hex2Bin(s)
				while string.len(s) < n do
					s = "0"..s
				end
				return s
			end
			----------------------------------------------------------------------------------
			
			if M.enableLighting then
				for x = 1, map.layers[i].width, 1 do
					if map.layers[i].lighting then
						map.layers[i].lighting[x] = {}
					end
				end
			end
			
			tileObjects[i] = {}
			for x = 1, map.layers[i].width, 1 do
				tileObjects[i][x] = {}
			end
			if not map.modified then
				if not map.layers[i].data and not map.layers[i].image then
					map.layers[i].properties.objectLayer = true
				end
			end
			if not storageToggle then
				--LOAD WORLD ARRAYS
				if not map.modified then
					map.layers[i].world = {}
					map.layers[i].largeTiles = {}
					if map.layers[i].properties.objectLayer then
						map.layers[i].extendedObjects = {}
					end
					--tileObjects[i] = {}
					if enableFlipRotation then
						map.layers[i].flipRotation = {}
					end
					if M.enableLighting and i == 1 then
						map.lightToggle = {}
						map.lightToggle2 = {}
						map.lightToggle3 = {}
						M.lightingData.lightLookup = {}
					end
					local mL = map.layers[i]
					local mD = mL.data	
					for x = 1, map.layers[i].width, 1 do
						mL.world[x] = {}
						if not mL.largeTiles[x] then
							mL.largeTiles[x] = {}
						end
						if mL.properties.objectLayer then
							mL.extendedObjects[x] = {}
						end
						if mL.lighting then
							mL.lighting[x] = {}
						end
						if M.enableLighting and i == 1 then
							map.lightToggle[x] = {}
							map.lightToggle2[x] = {}
							map.lightToggle3[x] = {}
						end
						if enableFlipRotation then
							mL.flipRotation[x] = {}
						end
						local lx = x
						while lx > map.width do
							lx = lx - map.width
						end
						for y = 1, map.layers[i].height, 1 do
							if M.enableLighting and i == 1 then
								map.lightToggle2[x][y] = 0
							end
							local ly = y
							while ly > map.height do
								ly = ly - map.height
							end											
							if mD then
								if enableFlipRotation then
									if mD[(map.width * (ly - 1)) + lx] > 1000000 then
										local string = tostring(mD[(map.width * (ly - 1)) + lx])
										if globalID[string] then
											mL.flipRotation[x][y] = globalID[string][1]
											mL.world[x][y] = globalID[string][2]
										else
											local binary = Dec2Bin(string)
											local command = string.sub(binary, 1, 3)
											local flipRotate = Bin2Dec(command)
											mL.flipRotation[x][y] = tonumber(flipRotate)
											local binaryID = string.sub(binary, 4, 32)
											local tileID = Bin2Dec(binaryID)
											mL.world[x][y] = tonumber(tileID)
											globalID[string] = {tonumber(flipRotate), tonumber(tileID)}
										end
									else
										mL.world[x][y] = mD[(map.width * (ly - 1)) + lx]
									end
								else
									mL.world[x][y] = mD[(map.width * (ly - 1)) + lx]
								end	
								
								if mL.world[x][y] ~= 0 then
									local frameIndex = mL.world[x][y]
									local tileSetIndex = 1
									for i = 1, #map.tilesets, 1 do
										if frameIndex >= map.tilesets[i].firstgid then
											tileSetIndex = i
										else
											break
										end
									end
									
									--find static lights
									if M.enableLighting then
										tileStr = tostring((frameIndex - (map.tilesets[tileSetIndex].firstgid - 1)) - 1)
										local mT = map.tilesets[tileSetIndex].tileproperties
										if mT then
											if mT[tileStr] then
												if mT[tileStr]["lightSource"] then
													local range = json.decode(mT[tileStr]["lightRange"])
													local maxRange = range[1]
													for l = 1, 3, 1 do
														if range[l] > maxRange then
															maxRange = range[l]
														end
													end
													map.lights[lightIDs] = {locX = x, 
														locY = y, 
														tileSetIndex = tileSetIndex, 
														tileStr = tileStr,
														frameIndex = frameIndex,
														source = json.decode(mT[tileStr]["lightSource"]),
														falloff = json.decode(mT[tileStr]["lightFalloff"]),
														range = range,
														maxRange = maxRange,
														layer = i,
														baseLayer = i,
														level = M.getLevel(i),
														id = lightIDs,
														area = {},
														areaIndex = 1
													}
													if mT[tileStr]["lightLayer"] then
														map.lights[lightIDs].layer = tonumber(mT[tileStr]["lightLayer"])
														map.lights[lightIDs].level = M.getLevel(map.lights[lightIDs].layer)
													elseif mT[tileStr]["lightLayerRelative"] then
														map.lights[lightIDs].layer = map.lights[lightIDs].layer + tonumber(mT[tileStr]["lightLayerRelative"])
														if map.lights[lightIDs].layer < 1 then
															map.lights[lightIDs].layer = 1
														end
														if map.lights[lightIDs].layer > #map.layers then
															map.lights[lightIDs].layer = #map.layers
														end
														map.lights[lightIDs].level = M.getLevel(map.lights[lightIDs].layer)
													end
													if mT[tileStr]["lightArc"] then
														map.lights[lightIDs].arc = json.decode(
															mT[tileStr]["lightArc"]
														)
													end
													if mT[tileStr]["lightRays"] then
														map.lights[lightIDs].rays = json.decode(
															mT[tileStr]["lightRays"]
														)
													end
													if mT[tileStr]["layerFalloff"] then
														map.lights[lightIDs].layerFalloff = json.decode(
															mT[tileStr]["layerFalloff"]
														)
													end
													if mT[tileStr]["levelFalloff"] then
														map.lights[lightIDs].levelFalloff = json.decode(
															mT[tileStr]["levelFalloff"]
														)
													end
													lightIDs = lightIDs + 1
												end
											end
										end
									end
									
									--find large tiles
									local mT = map.tilesets[tileSetIndex]
									if mT.tilewidth > map.tilewidth or mT.tileheight > map.tileheight  then
										--print("found")
										local width = math.ceil(mT.tilewidth / map.tilewidth)
										local height = math.ceil(mT.tileheight / map.tileheight)
										
										for locX = x, x + width - 1, 1 do
											for locY = y, y - height + 1, -1 do
												local lx = locX
												local ly = locY
												if lx > map.width then
													lx = lx - map.width
												elseif lx < 1 then
													lx = lx + map.width
												end
												if ly > map.height then
													ly = ly - map.height
												elseif ly < 1 then
													ly = ly + map.height
												end
												
												if not mL.largeTiles[lx] then
													map.layers[i].largeTiles[lx] = {}
												end
												if not mL.largeTiles[lx][ly] then
													map.layers[i].largeTiles[lx][ly] = {}
												end
												
												mL.largeTiles[lx][ly][#mL.largeTiles[lx][ly] + 1] = {frameIndex, x, y}
											end
										end
										
									end
								end
								
							else
								mL.world[x][y] = 0
							end
						end
					end
				end
			end
			
			--DELETE IMPORTED TILEMAP FROM MEMORY
			if not map.modified then
				map.layers[i].data = nil
			end
			if map.layers[i].properties.level ~= prevLevel then
				prevLevel = map.layers[i].properties.level
				map.numLevels = map.numLevels + 1
			end
			map.layers[i].properties.level = tonumber(map.layers[i].properties.level)		
			--LOAD PHYSICS
			if enablePhysicsByLayer == 1 then
				if map.layers[i].properties.physics == "true" then
					enablePhysics[i] = true
					physicsData.layer[i] = {}
					physicsData.layer[i].defaultDensity = physicsData.defaultDensity
					physicsData.layer[i].defaultFriction = physicsData.defaultFriction
					physicsData.layer[i].defaultBounce = physicsData.defaultBounce
					physicsData.layer[i].defaultBodyType = physicsData.defaultBodyType
					physicsData.layer[i].defaultShape = physicsData.defaultShape
					physicsData.layer[i].defaultRadius = physicsData.defaultRadius
					physicsData.layer[i].defaultFilter = physicsData.defaultFilter
					physicsData.layer[i].isActive = true
					physicsData.layer[i].isAwake = true			
					if map.layers[i].properties.density then
						physicsData.layer[i].defaultDensity = map.layers[i].properties.density
					end
					if map.layers[i].properties.friction then
						physicsData.layer[i].defaultFriction = map.layers[i].properties.friction
					end
					if map.layers[i].properties.bounce then
						physicsData.layer[i].defaultBounce = map.layers[i].properties.bounce
					end
					if map.layers[i].properties.bodyType then
						physicsData.layer[i].defaultBodyType = map.layers[i].properties.bodyType
					end
					if map.layers[i].properties.shape then
						physicsData.layer[i].defaultShape = json.decode(map.layers[i].properties.shape)
					end
					if map.layers[i].properties.radius then
						physicsData.layer[i].defaultRadius = map.layers[i].properties.radius
					end
					if map.layers[i].properties.groupIndex or map.layers[i].properties.categoryBits or map.layers[i].properties.maskBits then
						physicsData.layer[i].defaultFilter = {categoryBits = tonumber(map.layers[i].properties.categoryBits),
															maskBits = tonumber(map.layers[i].properties.maskBits),
															groupIndex = tonumber(map.layers[i].properties.groupIndex)
						}
					end
				end
			elseif enablePhysicsByLayer == 2 then
				enablePhysics[i] = true
				physicsData.layer[i] = {}
				physicsData.layer[i].defaultDensity = physicsData.defaultDensity
				physicsData.layer[i].defaultFriction = physicsData.defaultFriction
				physicsData.layer[i].defaultBounce = physicsData.defaultBounce
				physicsData.layer[i].defaultBodyType = physicsData.defaultBodyType
				physicsData.layer[i].defaultShape = physicsData.defaultShape
				physicsData.layer[i].defaultRadius = physicsData.defaultRadius
				physicsData.layer[i].defaultFilter = physicsData.defaultFilter
				physicsData.layer[i].isActive = true
				physicsData.layer[i].isAwake = true			
				if map.layers[i].properties.density then
					physicsData.layer[i].defaultDensity = map.layers[i].properties.density
				end
				if map.layers[i].properties.friction then
					physicsData.layer[i].defaultFriction = map.layers[i].properties.friction
				end
				if map.layers[i].properties.bounce then
					physicsData.layer[i].defaultBounce = map.layers[i].properties.bounce
				end
				if map.layers[i].properties.bodyType then
					physicsData.layer[i].defaultBodyType = map.layers[i].properties.bodyType
				end
				if map.layers[i].properties.shape then
					physicsData.layer[i].defaultShape = json.decode(map.layers[i].properties.shape)
				end
				if map.layers[i].properties.radius then
					physicsData.layer[i].defaultRadius = map.layers[i].properties.radius
				end
				if map.layers[i].properties.groupIndex or map.layers[i].properties.categoryBits or map.layers[i].properties.maskBits then
					physicsData.layer[i].defaultFilter = {categoryBits = tonumber(map.layers[i].properties.categoryBits),
														maskBits = tonumber(map.layers[i].properties.maskBits),
														groupIndex = tonumber(map.layers[i].properties.groupIndex)
					}
				end			
			end			
			masterGroup[i].xScale = tonumber(map.layers[i].properties.scaleX)
			masterGroup[i].yScale = tonumber(map.layers[i].properties.scaleY)
		end
		
		if refLayer1 then
			refLayer = refLayer1
		elseif refLayer2 then
			refLayer = refLayer2
		else
			refLayer = 1
		end
		
		globalID = {}
		print("Levels: "..map.numLevels)
		print("Reference Layer: "..refLayer)
		
		--LIGHTING
		if map.properties then
			if map.properties.lightingStyle then
				local levelLighting = {}
				for i = 1, map.numLevels, 1 do
					levelLighting[i] = {}
				end
				if not map.properties.lightRedStart then
					map.properties.lightRedStart = "1"
				end
				if not map.properties.lightGreenStart then
					map.properties.lightGreenStart = "1"
				end
				if not map.properties.lightBlueStart then
					map.properties.lightBlueStart = "1"
				end
				if map.properties.lightingStyle == "diminish" then
					local rate = tonumber(map.properties.lightRate)
					levelLighting[map.numLevels].red = tonumber(map.properties.lightRedStart)
					levelLighting[map.numLevels].green = tonumber(map.properties.lightGreenStart)
					levelLighting[map.numLevels].blue = tonumber(map.properties.lightBlueStart)
					for i = map.numLevels - 1, 1, -1 do
						levelLighting[i].red = levelLighting[map.numLevels].red - (rate * (map.numLevels - i))
						if levelLighting[i].red < 0 then
							levelLighting[i].red = 0
						end
						levelLighting[i].green = levelLighting[map.numLevels].green - (rate * (map.numLevels - i))
						if levelLighting[i].green < 0 then
							levelLighting[i].green = 0
						end
						levelLighting[i].blue = levelLighting[map.numLevels].blue - (rate * (map.numLevels - i))
						if levelLighting[i].blue < 0 then
							levelLighting[i].blue = 0
						end
					end
				end
				for i = 1, #map.layers, 1 do
					if map.layers[i].properties.lightRed then
						map.layers[i].redLight = tonumber(map.layers[i].properties.lightRed)
					else
						map.layers[i].redLight = levelLighting[map.layers[i].properties.level].red
					end
					if map.layers[i].properties.lightGreen then
						map.layers[i].greenLight = tonumber(map.layers[i].properties.lightGreen)
					else
						map.layers[i].greenLight = levelLighting[map.layers[i].properties.level].green
					end
					if map.layers[i].properties.lightBlue then
						map.layers[i].blueLight = tonumber(map.layers[i].properties.lightBlue)
					else
						map.layers[i].blueLight = levelLighting[map.layers[i].properties.level].blue
					end
				end
			else
				for i = 1, #map.layers, 1 do
					if map.layers[i].properties.lightRed then
						map.layers[i].redLight = tonumber(map.layers[i].properties.lightRed)
					else
						map.layers[i].redLight = 1
					end
					if map.layers[i].properties.lightGreen then
						map.layers[i].greenLight = tonumber(map.layers[i].properties.lightGreen)
					else
						map.layers[i].greenLight = 1
					end
					if map.layers[i].properties.lightBlue then
						map.layers[i].blueLight = tonumber(map.layers[i].properties.lightBlue)
					else
						map.layers[i].blueLight = 1
					end
				end
			end
		end
	
		--CORRECT OBJECTS FOR ISOMETRIC MAPS
		if map.orientation == 1 and not storageToggle then
			for i = 1, #map.layers, 1 do
				if map.layers[i].properties.objectLayer then
					for j = 1, #map.layers[i].objects, 1 do
						map.layers[i].objects[j].width = map.layers[i].objects[j].width * 2
						map.layers[i].objects[j].height = map.layers[i].objects[j].height * 2
						map.layers[i].objects[j].x = map.layers[i].objects[j].x * 2
						map.layers[i].objects[j].y = map.layers[i].objects[j].y * 2
						if map.layers[i].objects[j].polygon then
							for k = 1, #map.layers[i].objects[j].polygon, 1 do
								map.layers[i].objects[j].polygon[k].x = map.layers[i].objects[j].polygon[k].x * 2
								map.layers[i].objects[j].polygon[k].y = map.layers[i].objects[j].polygon[k].y * 2
							end
						elseif map.layers[i].objects[j].polyline then
							for k = 1, #map.layers[i].objects[j].polyline, 1 do
								map.layers[i].objects[j].polyline[k].x = map.layers[i].objects[j].polyline[k].x * 2
								map.layers[i].objects[j].polyline[k].y = map.layers[i].objects[j].polyline[k].y * 2
							end
						end
					end
				end
			end
		end
		
		detectSpriteLayers()
		detectObjectLayers()
		M.map = map
		M.masterGroup = masterGroup
		M.masterGroup = masterGroup
		M.map.width = map.width
		M.map.height = map.height
	
		print("Map Load Time(ms): "..system.getTimer() - startTime)
		
		if map.orientation == 1 and not map.modified then
			map.tilewidth = map.tilewidth --* M.isoScaleMod
			map.tileheight = map.tilewidth
		end			
		for i = 1, #map.tilesets, 1 do
			if map.tilesets[i].properties then
				for key,value in pairs(map.tilesets[i].properties) do
					if key == "physicsSource" then
						local scaleFactor = 1
						if map.tilesets[i].properties["physicsSourceScale"] then
							scaleFactor = tonumber(map.tilesets[i].properties["physicsSourceScale"])
						end
						local source = value:gsub(".lua", "")
						map.tilesets[i].physicsData = require(source).physicsData(scaleFactor)
					end
				end
			end
		end
		--process static lights		
		if M.enableLighting then
			local startTime=system.getTimer()
			for key,value in pairs(map.lights) do
				if value.rays then
					for k = 1, #value.rays, 1 do
						M.processLightRay(value.layer, value, value.rays[k])
					end
				else
					M.processLight(value.layer, value)
				end
			end
			print("Light Load Time(ms): "..system.getTimer() - startTime)
		end		
		if map.orientation == 1 then
			for i = 1, #map.layers, 1 do
				local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
				local cameraX, cameraY = masterGroup[i]:contentToLocal(tempX, tempY)
				local temp = M.isoTransform(cameraX, cameraY)
				M.cameraXoffset[i] = temp[1] - cameraX
				M.cameraYoffset[i] = temp[2] - cameraY
			end
		end		
		map.modified = 1
		
		if touchScroll[1] or pinchZoom then
			masterGroup:addEventListener("touch", touchScrollPinchZoom)
		end
		
		return map
	end
	
	local changeSpriteLayer = function(sprite, layer)
		local object = sprite
		object.layer = layer
		object.level = M.getLevel(layer)
		if map.orientation == 1 then
			if not object.levelPosX then
				object.levelPosX = object.x
			end
			if not object.levelPosY then
				object.levelPosY = object.y
			end
			if not object.locX then
				object.locX = math.ceil(object.levelPosX / map.tilewidth)
				object.locY = math.ceil(object.levelPosY / map.tileheight)
			end
			if object.locX >= 1 and object.locY >= 1 and not object.isMoving then
				if M.isoSort == 1 then
					local temp = object.locX + object.locY - 1
					if temp > map.height + map.width then
						temp = map.height + map.width
					end
					masterGroup[layer][temp]:insert(object)
				end
			end
		else
			masterGroup[layer]:insert(sprite)
		end		
		if object.lighting then
			object:setFillColor(map.layers[layer].redLight, map.layers[layer].greenLight, map.layers[layer].blueLight)
		end		
		if M.enableLighting then
			if object.light then
				if object.light.rays then
					object.light.areaIndex = 1
				end		
				local length = #object.light.area
				for i = length, 1, -1 do
					local locX = object.light.area[i][1]
					local locY = object.light.area[i][2]
					object.light.area[i] = nil
					if worldWrapX then
						if locX < 1 - map.locOffsetX then
							locX = locX + map.width
						end
						if locX > map.width - map.locOffsetX then
							locX = locX - map.width
						end
					end
					if worldWrapY then
						if locY < 1 - map.locOffsetY then
							locY = locY + map.height
						end
						if locY > map.height - map.locOffsetY then
							locY = locY - map.height
						end
					end
					if object.light.layer then
						if map.layers[object.light.layer].lighting[locX] and map.layers[object.light.layer].lighting[locX][locY] then
							map.layers[object.light.layer].lighting[locX][locY][object.light.id] = nil
							map.lightToggle[locX][locY] = tonumber(system.getTimer())
						end	
					end
				end
				object.light.layer = layer
				object.light.level = object.level
			end
		end
	end
	M.changeSpriteLayer = changeSpriteLayer
	
	M.setCameraFocus = function(object, offsetX, offsetY)
		if object then
			cameraFocus = object
			cameraFocus.cameraOffsetX = {}
			cameraFocus.cameraOffsetY = {}
			for i = 1, #map.layers, 1 do
				cameraFocus.cameraOffsetX[i] = offsetX or 0
				cameraFocus.cameraOffsetY[i] = offsetY or 0
			end
		else
			cameraFocus = nil
		end
	end
	
	M.setPointLightSource = function(sprite)
		pointLightSource = sprite
	end
	
	local frameLength = display.fps
	local easingHelper = function(distance, frames, kind)
		local move = {}
		local total = 0
		if not kind then
			kind = easing.linear
		end		
		for i = 1, frames, 1 do
			move[i] = kind((i - 1) * frameLength, frameLength * frames, 0, 1000)
		end		
		local move2 = {}
		local total2 = 0
		for i = 1, frames, 1 do
			if i < frames then
				move2[i] = move[i + 1] - move[i]
			else
				move2[i] = 1000 - move[i]
			end
			total2 = total2 + move2[i]
		end
		local mod2 = distance / total2
		for i = 1, frames, 1 do
			move2[i] = move2[i] * mod2
		end	
		return move2
	end
	
	local isMoving = {}
	local count = 0
	
	M.spritesFrozen = false
	M.cameraFrozen = false
	M.tileAnimsFrozen = false
	
	local drawLargeTile = function(locX, locY, layer, owner)
		--[[
		if locX > map.width then
			locX = locX - map.width
		elseif locX < 1 then
			locX = locX + map.width
		end
		if locY > map.height then
			locY = locY - map.height
		elseif locY < 1 then
			locY = locY + map.height
		end
		]]--
		if locX < 1 - map.locOffsetX then
			locX = locX + map.layers[layer].width
		end
		if locX > map.layers[layer].width - map.locOffsetX then
			locX = locX - map.layers[layer].width
		end				
		
		if locY < 1 - map.locOffsetY then
			locY = locY + map.layers[layer].height
		end
		if locY > map.layers[layer].height - map.locOffsetY then
			locY = locY - map.layers[layer].height
		end
		if map.layers[layer].largeTiles[locX] and map.layers[layer].largeTiles[locX][locY] then
			for i = 1, #map.layers[layer].largeTiles[locX][locY], 1 do
				local frameIndex = map.layers[layer].largeTiles[locX][locY][i][1]
				local lx = map.layers[layer].largeTiles[locX][locY][i][2]
				local ly = map.layers[layer].largeTiles[locX][locY][i][3]
				
				if not tileObjects[layer][lx][ly] then
					updateTile2({locX = lx, locY = ly, layer = layer})
				end
			end
		end
	end
	
	local cullLargeTile = function(locX, locY, layer, force)
		--[[
		if locX > map.width then
			locX = locX - map.width
		elseif locX < 1 then
			locX = locX + map.width
		end
		if locY > map.height then
			locY = locY - map.height
		elseif locY < 1 then
			locY = locY + map.height
		end
		]]--
		
		local tlocx, tlocy = locX, locY
		if locX < 1 - map.locOffsetX then
			locX = locX + map.layers[layer].width
		end
		if locX > map.layers[layer].width - map.locOffsetX then
			locX = locX - map.layers[layer].width
		end				
		
		if locY < 1 - map.locOffsetY then
			locY = locY + map.layers[layer].height
		end
		if locY > map.layers[layer].height - map.locOffsetY then
			locY = locY - map.layers[layer].height
		end
		
		if map.layers[layer].largeTiles[locX] and map.layers[layer].largeTiles[locX][locY] then
			for i = 1, #map.layers[layer].largeTiles[locX][locY], 1 do
				local frameIndex = map.layers[layer].largeTiles[locX][locY][i][1]
				local lx = map.layers[layer].largeTiles[locX][locY][i][2]
				local ly = map.layers[layer].largeTiles[locX][locY][i][3]
				
				if tileObjects[layer][lx][ly] then
					local frameIndex = map.layers[layer].world[lx][ly]
					local tileSetIndex = 1
					for i = 1, #map.tilesets, 1 do
						if frameIndex >= map.tilesets[i].firstgid then
							tileSetIndex = i
						else
							break
						end
					end
					
					local mT = map.tilesets[tileSetIndex]
					if mT.tilewidth > map.tilewidth or mT.tileheight > map.tileheight  then
						local width = math.ceil(mT.tilewidth / map.tilewidth)
						local height = math.ceil(mT.tileheight / map.tileheight)
						local left, top, right, bottom = lx, ly - height + 1, lx + width - 1, ly
						if (left > masterGroup[layer].vars.camera[3] or right < masterGroup[layer].vars.camera[1]or
						top > masterGroup[layer].vars.camera[4] or bottom < masterGroup[layer].vars.camera[2]) or force then
							if force then
								updateTile2({locX = lx, locY = ly, layer = layer, tile = -1, forceCullLargeTile = true})
							else
								updateTile2({locX = lx, locY = ly, layer = layer, tile = -1})
							end
						end
					end
				end
			end
		end
	end
	
	local update2 = function()
		if touchScroll[1] and touchScroll[6] then
			local velX = (touchScroll[2] - touchScroll[4]) / masterGroup.xScale
			local velY = (touchScroll[3] - touchScroll[5]) / masterGroup.yScale
		
			--print(velX, velY)
			M.moveCamera(velX, velY)
			touchScroll[2] = touchScroll[4]
			touchScroll[3] = touchScroll[5]	
		end	
		
		count556 = 0
		local lights = ""
		
		if viewableContentWidth ~= display.viewableContentWidth then
			viewableContentWidth = display.viewableContentWidth
			if display.viewableContentWidth < display.viewableContentHeight then
				print("screen is vertical")
				
				screenCenterX = display.contentWidth / 2
				screenCenterY = display.contentHeight / 2
				screenLeft = 0 + display.screenOriginX
				screenTop = 0 + display.screenOriginY
				screenRight = display.contentWidth - display.screenOriginX
				screenBottom = display.contentHeight - display.screenOriginY
				
				--[[
				screenLeft = display.screenOriginX
				screenTop = display.screenOriginY
				screenBottom = display.screenOriginX + (display.pixelHeight * display.contentScaleY)
				screenRight = display.screenOriginY + (display.pixelWidth * display.contentScaleX)
				screenCenterY = display.screenOriginX + (display.pixelHeight * display.contentScaleY) / 2
				screenCenterX = display.screenOriginY + (display.pixelWidth * display.contentScaleX) / 2
				]]--
				
			else
				print("screen is horizontal")
				screenLeft = display.screenOriginX
				screenTop = display.screenOriginY
				screenRight = display.screenOriginX + (display.pixelHeight * display.contentScaleY)
				screenBottom = display.screenOriginY + (display.pixelWidth * display.contentScaleX)
				screenCenterX = display.screenOriginX + (display.pixelHeight * display.contentScaleY) / 2
				screenCenterY = display.screenOriginY + (display.pixelWidth * display.contentScaleX) / 2
			end
			print(screenCenterX, screenCenterY)
		end
		
		--PROCESS SPRITES
		if not M.spritesFrozen then
			local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
			local cameraX, cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)
			if map.orientation == 1 then
				local isoPos = M.isoUntransform2(cameraX, cameraY)
				cameraX = isoPos[1]
				cameraY = isoPos[2]
			end
			local cameraLocX = math.ceil(cameraX / map.tilewidth)
			local cameraLocY = math.ceil(cameraY / map.tileheight)			
			M.cameraX, M.cameraY = cameraX, cameraY
			M.cameraLocX = cameraLocX
			M.cameraLocY = cameraLocY
			
			local processObject = function(object, lyr)
				if not object.layer then
					object.layer = lyr
				end
				local i = object.layer
				object.level = M.getLevel(i)				
				if not object.name then
					local spriteName = ""..object.x.."_"..object.y.."_"..i
					if sprites[spriteName] then
						local tempName = spriteName
						local counter = 1
						while sprites[tempName] do
							tempName = ""..spriteName..counter
							counter = counter + 1
						end
						spriteName = tempName
					end
					object.name = spriteName
					if not sprites[spriteName] then
						sprites[spriteName] = sprite
					end
				end	
							
				if not pointLightSource then
					pointLightSource = object
				end				
				
				if object.lighting then
					local mL = map.layers[i]
					if object.objType ~= 3 then
						if not object.color then
							object.color = {1, 1, 1}
						end
					else
						for i = 1, object.numChildren, 1 do
							if object[i]._class then
								if object.color and not object[i].color then
									object[i].color = object.color
								end
								if not object[i].color then
									object[i].color = {1, 1, 1}
								end
							end
						end
					end
				end				
				
				if object.offsetX then
					--object.anchorX = (((object.levelWidth or object.width) / 2) - object.offsetX) / (object.levelWidth or object.width)
				end
				if object.offsetY then
					--object.anchorY = (((object.levelHeight or object.height) / 2) - object.offsetY) / (object.levelHeight or object.height)		
				end		
				
				if map.orientation == 1 then
					--Clear Lighting (ISO)
					if object.light then
						if not object.light.created then
							object.light.created = true
							if not object.light.id then
								object.light.id = lightIDs
							end
							lightIDs = lightIDs + 1						
							if not object.light.maxRange then
								local maxRange = object.light.range[1]
								for l = 1, 3, 1 do
									if object.light.range[l] > maxRange then
										maxRange = object.light.range[l]
									end
								end
								object.light.maxRange = maxRange
							end		
							if not object.light.levelPosX then
								object.light.levelPosX = object.levelPosX or object.x
								object.light.levelPosY = object.levelPosY or object.y
							end		
							if not object.light.alternatorCounter then
								object.light.alternatorCounter = 1
							end		
							if object.light.rays then
								object.light.areaIndex = 1
							end		
							if object.light.layerRelative then
								object.light.layer = i + object.light.layerRelative
								if object.light.layer < 1 then
									object.light.layer = 1
								end
								if object.light.layer > #map.layers then
									object.light.layer = #map.layers
								end
							end						
							if not object.light.layer then
								object.light.layer = i
							end						
							object.light.level = object.level
							object.light.dynamic = true
							object.light.area = {}
							map.lights[object.light.id] = object.light
						else
							if M.lightingData.refreshCounter == 1 then
								if object.light.rays then
									object.light.areaIndex = 1
								end			
								local length = #object.light.area
								for i = length, 1, -1 do
									local locX = object.light.area[i][1]
									local locY = object.light.area[i][2]
									object.light.area[i] = nil
									if worldWrapX then
										if locX < 1 - map.locOffsetX then
											locX = locX + map.width
										end
										if locX > map.width - map.locOffsetX then
											locX = locX - map.width
										end
									end
									if worldWrapY then
										if locY < 1 - map.locOffsetY then
											locY = locY + map.height
										end
										if locY > map.height - map.locOffsetY then
											locY = locY - map.height
										end
									end
									if object.light.layer then
										if map.layers[object.light.layer].lighting[locX] and map.layers[object.light.layer].lighting[locX][locY] then
											map.layers[object.light.layer].lighting[locX][locY][object.light.id] = nil
											map.lightToggle[locX][locY] = tonumber(system.getTimer())
										end	
									end
								end			
								if object.toggleRemoveLight then
									object.light = nil
									object.toggleRemoveLight = false				
								end
							end
						end
					end
					
					local movingSprites = movingSprites
					if movingSprites[object] and not holdSprite then
						local index = movingSprites[object]
						local velX = object.deltaX[index]
						local velY = object.deltaY[index]
						movingSprites[object] = index - 1					
						object.levelPosX = object.levelPosX + velX
						object.levelPosY = object.levelPosY + velY					
						if movingSprites[object] == 0 then
							movingSprites[object] = nil
							object.deltaX = nil
							object.deltaY = nil
							object.isMoving = nil
							if object.onComplete then
								local temp = object.onComplete
								object.onComplete = nil
								local event = { name = "spriteMoveComplete", sprite = object}
								temp(event)
							end
						end
					end
					
					if holdSprite == object then
						if object.transition then
							transition.pause(object.transition)
						end
						object.paused = true
					elseif object.transition then
						if object.paused then
							transition.resume(object.transition)
							object.paused = nil
						end
						if object.transition._transitionHasCompleted then
							object.transition = nil
						elseif object.transitionDelta then
							object.transitionDelta = object.transitionDelta - 1
						end
					end
					
					--Update Position (ISO)
					local isoPos = M.isoTransform2(object.levelPosX, object.levelPosY)
					object.x = isoPos[1]
					object.y = isoPos[2]					
					if layerWrapX[i] and (object.wrapX == nil or object.wrapX == true) then
						while object.levelPosX < 1 - (map.locOffsetX * map.tilewidth) do
							object.levelPosX = object.levelPosX + map.layers[i].width * map.tilewidth
						end
						while object.levelPosX > map.layers[i].width * map.tilewidth - (map.locOffsetX * map.tilewidth) do
							object.levelPosX = object.levelPosX - map.layers[i].width * map.tilewidth
						end						
						if cameraX - object.levelPosX < map.layers[i].width * map.tilewidth / -2 then
							--wrap around to the left
							local vector = M.isoVector(map.layers[i].width * map.tilewidth * -1, 0)
							object:translate(vector[1], vector[2])
						elseif cameraX - object.levelPosX > map.layers[i].width * map.tilewidth / 2 then
							--wrap around to the right
							local vector = M.isoVector(map.layers[i].width * map.tilewidth * 1, 0)
							object:translate(vector[1], vector[2])
						end
					end					
					if layerWrapY[i] and (object.wrapY == nil or object.wrapY == true) then
						while object.levelPosY < 1 - (map.locOffsetY * map.tileheight) do
							object.levelPosY = object.levelPosY + map.layers[i].height * map.tileheight
						end
						while object.levelPosY > map.layers[i].height * map.tileheight - (map.locOffsetY * map.tileheight) do
							object.levelPosY = object.levelPosY - map.layers[i].height * map.tileheight
						end						
						if cameraY - object.levelPosY < map.layers[i].height * map.tileheight / -2 then
							--wrap around to the left
							local vector = M.isoVector(0, map.layers[i].height * map.tileheight * -1)
							object:translate(vector[1], vector[2])
						elseif cameraY - object.levelPosY > map.layers[i].height * map.tileheight / 2 then
							--wrap around to the right
							local vector = M.isoVector(0, map.layers[i].height * map.tileheight * 1)
							object:translate(vector[1], vector[2])
						end
					end
					
					--CONSTRAIN TO MAP (ISO)
					if object.constrainToMap then
						local constraints = object.constrainToMap
						local pushX, pushY = 0, 0						
						if constraints[1] then
							if object.levelPosX < 1 - (map.locOffsetX * map.tilewidth) then
								pushX = 1 - (map.locOffsetX * map.tilewidth) - object.levelPosX
							end
						end
						if constraints[2] then
							if object.levelPosY < 1 - (map.locOffsetY * map.tileheight) then
								pushY = 1 - (map.locOffsetY * map.tileheight) - object.levelPosY
							end
						end
						if constraints[3] then
							if object.levelPosX > (map.width - map.locOffsetX) * map.tilewidth then
								pushX = (map.width - map.locOffsetX) * map.tilewidth - object.levelPosX
							end
						end
						if constraints[4] then
							if object.levelPosY > (map.height - map.locOffsetY) * map.tileheight then
								pushY = (map.height - map.locOffsetY) * map.tileheight - object.levelPosY
							end
						end						
						object:translate(pushX, pushY)
					end
					
					object.locX = math.ceil(object.levelPosX / map.tilewidth)
					object.locY = math.ceil(object.levelPosY / map.tileheight)
					
					--Handle Offscreen Physics (ISO)
					if M.managePhysicsStates and (object.managePhysicsStates == nil or object.managePhysicsStates == true) then
						if object.bodyType and masterGroup[i].vars.camera then
							if object.offscreenPhysics then
								local topLeftX, topLeftY = M.screenToLoc(object.contentBounds.xMin, object.contentBounds.yMin)
								local topRightX, topRightY = M.screenToLoc(object.contentBounds.xMax, object.contentBounds.yMin)
								local bottomLeftX, bottomLeftY = M.screenToLoc(object.contentBounds.xMin, object.contentBounds.yMax)
								local bottomRightX, bottomRightY = M.screenToLoc(object.contentBounds.xMax, object.contentBounds.yMax)							
								local left = topLeftX - 1
								local top = topRightY - 1
								local right = bottomRightX + 1
								local bottom = bottomLeftY + 1							
								if not object.bounds or (object.bounds[1] ~= left or object.bounds[2] ~= top or object.bounds[3] ~= right or object.bounds[4] ~= bottom) then
									if object.physicsRegion then
										for p = 1, #object.physicsRegion, 1 do
											local lx = object.physicsRegion[p][1]
											local ly = object.physicsRegion[p][2]
											if (lx < masterGroup[i].vars.camera[1] or lx > masterGroup[i].vars.camera[3]) or
											(ly < masterGroup[i].vars.camera[2] or ly > masterGroup[i].vars.camera[4]) then
												updateTile2({locX = object.physicsRegion[p][1], locY = object.physicsRegion[p][2], layer = object.physicsRegion[p][3], tile = -1,
													owner = object
												})
											end
										end
									end
									object.physicsRegion = nil
									object.physicsRegion = {}
									for lx = left, right, 1 do
										for ly = top, bottom, 1 do
											for j = 1, #map.layers, 1 do
												if (lx < masterGroup[j].vars.camera[1] or lx > masterGroup[j].vars.camera[3]) or
												(ly < masterGroup[j].vars.camera[2] or ly > masterGroup[j].vars.camera[4]) then
													local owner = updateTile2({locX = lx, locY = ly, layer = j, onlyPhysics = false, owner = object})
													if owner then
														object.physicsRegion[#object.physicsRegion + 1] = {lx, ly, j}
													end
												end
											end
										end
									end
									object.bounds = {left, top, right, bottom}
								end
							else
								local locX = math.ceil(object.levelPosX / map.tilewidth)
								local locY = math.ceil(object.levelPosY / map.tilewidth)
								if (locX < masterGroup[i].vars.camera[1] or locX > masterGroup[i].vars.camera[3]) or
								(locY < masterGroup[i].vars.camera[2] or locY > masterGroup[i].vars.camera[4]) then
									if not object.properties or not object.properties.isBodyActive then
										object.isBodyActive = false
									end
								elseif (locX <= masterGroup[i].vars.camera[1] or locX >= masterGroup[i].vars.camera[3]) or
								(locY <= masterGroup[i].vars.camera[2] or locY >= masterGroup[i].vars.camera[4]) then
									if not object.properties or not object.properties.isAwake then
										object.isAwake = false
									end
									if not object.properties or not object.properties.isBodyActive then
										object.isBodyActive = true
									end
								else
									if not object.properties or not object.properties.isAwake then
										object.isAwake = true
									end
									if not object.properties or not object.properties.isBodyActive then
										object.isBodyActive = true
									end
								end
							end
						end
					end
					
					--Sort Sprites (ISO)
					if object.locX >= 1 and object.locY >= 1 and not object.isMoving then
						if M.isoSort == 1 then
							local temp = object.locX + object.locY - 1
							if temp > map.height + map.width then
								temp = map.height + map.width
							end
							if temp ~= object.row then
								masterGroup[i][temp]:insert(object)
							end
						end
					end
					
					--Apply Lighting to Non-Light Objects, Trigger Events (ISO)
					if object.lighting then
						if M.enableLighting then
							object.litBy = {}
							local locX = object.locX
							local locY = object.locY
							local mapLayerFalloff = map.properties.lightLayerFalloff
							local mapLevelFalloff = map.properties.lightLevelFalloff
							local red, green, blue = map.layers[i].redLight, map.layers[i].greenLight, map.layers[i].blueLight
							for k = 1, #map.layers, 1 do
								if map.layers[k].lighting[locX] then
									if map.layers[k].lighting[locX][locY] then
										local temp = map.layers[k].lighting[locX][locY]
										local tempSources = {}
										for key,value in pairs(object.prevLitBy) do
											tempSources[key] = true
										end
										for key,value in pairs(temp) do
											local levelDiff = math.abs(M.getLevel(i) - map.lights[key].level)
											local layerDiff = math.abs(i - map.lights[key].layer)							
											local layerFalloff, levelFalloff
											if map.lights[key].layerFalloff then
												layerFalloff = map.lights[key].layerFalloff
											else
												layerFalloff = mapLayerFalloff
											end							
											if map.lights[key].levelFalloff then
												levelFalloff = map.lights[key].levelFalloff
											else
												levelFalloff = mapLevelFalloff
											end							
											local tR = temp[key].light[1] - (levelDiff * levelFalloff[1]) - (layerDiff * layerFalloff[1])
											local tG = temp[key].light[2] - (levelDiff * levelFalloff[2]) - (layerDiff * layerFalloff[2])
											local tB = temp[key].light[3] - (levelDiff * levelFalloff[3]) - (layerDiff * layerFalloff[3])							
											if object.lightingListeners[key] then
												local event = { name = key, target = object, source = map.lights[key], light = {tR, tG, tB}}
												if not object.prevLitBy[key] then
													object.prevLitBy[key] = true
													event.phase = "began"
												else
													event.phase = "maintained"
												end
												object:dispatchEvent( event )
												tempSources[key] = nil
											end							
											if tR > red then
												red = tR
											end
											if tG > green then
												green = tG
											end
											if tB > blue then
												blue = tB
											end							
											object.litBy[#object.litBy + 1] = key							
										end
										for key,value in pairs(tempSources) do
											if object.lightingListeners[key] then
												object.prevLitBy[key] = nil
												local event = { name = key, target = object, source = map.lights[key], light = {tR, tG, tB}}
												event.phase = "ended"
												object:dispatchEvent( event )
											end
										end
									else						
										for key,value in pairs(object.prevLitBy) do
											if object.lightingListeners[key] and not map.lights[key] then
												object.prevLitBy[key] = nil
												local event = { name = key, target = object, source = map.lights[key], light = {tR, tG, tB}}
												event.phase = "ended"
												object:dispatchEvent( event )
											elseif object.lightingListeners[key] and map.lights[key].layer == k then
												object.prevLitBy[key] = nil
												local event = { name = key, target = object, source = map.lights[key], light = {tR, tG, tB}}
												event.phase = "ended"
												object:dispatchEvent( event )
											end
										end						
									end
								end
							end
							if object.objType < 3 then
								object:setFillColor(red * object.color[1], green * object.color[2], blue * object.color[3])
							elseif object.objType == 3 then
								for i = 1, object.numChildren, 1 do
									if object[i]._class then
										object[i]:setFillColor(red * object[i].color[1], green * object[i].color[2], blue * object[i].color[3])
									end
								end
							elseif object.objType == 4 then
								for i = 1, object.numChildren, 1 do
									if object[i]._class then
										object[i]:setStrokeColor(red * object[i].color[1], green * object[i].color[2], blue * object[i].color[3])
									end
								end
							end
						else
							if object.objType < 3 then
								local mL = map.layers[i]
								object:setFillColor(mL.redLight * object.color[1], mL.greenLight * object.color[2], mL.blueLight * object.color[3])
							elseif object.objType == 3 then
								local mL = map.layers[i]
								for i = 1, object.numChildren, 1 do
									if object[i]._class then
										object[i]:setFillColor(mL.redLight * object[i].color[1], mL.greenLight * object[i].color[2], mL.blueLight * object[i].color[3])
									end
								end
							elseif object.objType == 4 then
								local mL = map.layers[i]
								for i = 1, object.numChildren, 1 do
									if object[i]._class then
										object[i]:setStrokeColor(mL.redLight * object[i].color[1], mL.greenLight * object[i].color[2], mL.blueLight * object[i].color[3])
									end
								end
							end
						end
					end
					
					--Cast Light (ISO)
					if M.enableLighting and object.light then
						if M.lightingData.refreshCounter == 1 then
							object.light.levelPosX = object.levelPosX
							object.light.levelPosY = object.levelPosY
						end					
						if M.lightingData.refreshCounter == 1 then
							if object.levelPosX > 0 - (map.locOffsetX * map.tilewidth) and object.levelPosX <= (map.width - map.locOffsetX) * map.tilewidth then
								if object.levelPosY > 0 - (map.locOffsetY * map.tileheight) and object.levelPosY <= (map.height - map.locOffsetY) * map.tileheight then
									if object.light.rays then
										for k = 1, #object.light.rays, 1 do
											M.processLightRay(object.light.layer, object.light, object.light.rays[k])
										end
									else								
										M.processLight(object.light.layer, object.light)									
										local length = #object.light.area
										local tempML = {}
										local oLx = object.light.locX
										local oLy = object.light.locY
										local oLl = object.light.layer
										local oLi = object.light.id
										local mL = map.layers
										for i = length, 1, -1 do
											local locX = object.light.area[i][1]
											local locY = object.light.area[i][2]
											local locXt = locX
											local locYt = locY						
											if worldWrapX then
												if locX < 1 - map.locOffsetX then
													locX = locX + map.width
												end
												if locX > map.width - map.locOffsetX then
													locX = locX - map.width
												end
											end
											if worldWrapY then
												if locY < 1 - map.locOffsetY then
													locY = locY + map.height
												end
												if locY > map.height - map.locOffsetY then
													locY = locY - map.height
												end
											end						
											local neighbor1 = {0, 0, 0}
											local neighbor2 = {0, 0, 0}										
											if locX ~= oLx and locY ~= oLy and map.lightingData[mL[oLl].world[locX][locY]]then											
												if locXt > oLx and locYt < oLy then
													--top right
													if oLl then
														if mL[oLl].lighting[locX - 1] and mL[oLl].lighting[locX][locY] then
															if not map.lightingData[mL[oLl].world[locX - 1][locY]] then
																if mL[oLl].lighting[locX - 1][locY] then
																	if mL[oLl].lighting[locX - 1][locY][oLi] then
																		neighbor1 = mL[oLl].lighting[locX - 1][locY][oLi].light
																		neighbor1[4] = locX - 1
																		neighbor1[5] = locY
																	end
																end
															end
														end	
														if mL[oLl].lighting[locX] and mL[oLl].lighting[locX][locY + 1] then
															if not map.lightingData[mL[oLl].world[locX][locY + 1]] then
																if mL[oLl].lighting[locX][locY + 1] then
																	if mL[oLl].lighting[locX][locY + 1][oLi] then
																		neighbor2 = mL[oLl].lighting[locX][locY + 1][oLi].light
																		neighbor2[4] = locX
																		neighbor2[5] = locY + 1
																	end
																end
															end
														end	
													end
												elseif locXt > oLx and locYt > oLy then
													--bottom right
													if oLl then
														if mL[oLl].lighting[locX - 1] and mL[oLl].lighting[locX][locY] then
															if not map.lightingData[mL[oLl].world[locX - 1][locY]] then
																if mL[oLl].lighting[locX - 1][locY] then
																	if mL[oLl].lighting[locX - 1][locY][oLi] then
																		neighbor1 = mL[oLl].lighting[locX - 1][locY][oLi].light
																		neighbor1[4] = locX - 1
																		neighbor1[5] = locY
																	end
																end
															end
														end	
														if mL[oLl].lighting[locX] and mL[oLl].lighting[locX][locY - 1] then
															if not map.lightingData[mL[oLl].world[locX][locY - 1]] then
																if mL[oLl].lighting[locX][locY - 1] then
																	if mL[oLl].lighting[locX][locY - 1][oLi] then
																		neighbor2 = mL[oLl].lighting[locX][locY - 1][oLi].light
																		neighbor2[4] = locX
																		neighbor2[5] = locY - 1
																	end
																end
															end
														end	
													end
												elseif locXt < oLx and locYt > oLy then
													--bottom left
													if oLl then
														if mL[oLl].lighting[locX + 1] and mL[oLl].lighting[locX][locY] then
															if not map.lightingData[mL[oLl].world[locX + 1][locY]] then
																if mL[oLl].lighting[locX + 1][locY] then
																	if mL[oLl].lighting[locX + 1][locY][oLi] then
																		neighbor1 = mL[oLl].lighting[locX + 1][locY][oLi].light
																		neighbor1[4] = locX + 1
																		neighbor1[5] = locY
																	end
																end
															end
														end	
														if mL[oLl].lighting[locX] and mL[oLl].lighting[locX][locY - 1] then
															if not map.lightingData[mL[oLl].world[locX][locY - 1]] then
																if mL[oLl].lighting[locX][locY - 1] then
																	if mL[oLl].lighting[locX][locY - 1][oLi] then
																		neighbor2 = mL[oLl].lighting[locX][locY - 1][oLi].light
																		neighbor2[4] = locX
																		neighbor2[5] = locY - 1
																	end
																end
															end
														end	
													end
												elseif locXt < oLx and locYt < oLy then
													--top left
													if oLl then
														if mL[oLl].lighting[locX + 1] and mL[oLl].lighting[locX][locY] then
															if not map.lightingData[mL[oLl].world[locX + 1][locY]] then
																if mL[oLl].lighting[locX + 1][locY] then
																	if mL[oLl].lighting[locX + 1][locY][oLi] then
																		neighbor1 = mL[oLl].lighting[locX + 1][locY][oLi].light
																		neighbor1[4] = locX + 1
																		neighbor1[5] = locY
																	end
																end
															end
														end	
														if mL[oLl].lighting[locX] and mL[oLl].lighting[locX][locY + 1] then
															if not map.lightingData[mL[oLl].world[locX][locY + 1]] then
																if mL[oLl].lighting[locX][locY + 1] then
																	if mL[oLl].lighting[locX][locY + 1][oLi] then
																		neighbor2 = mL[oLl].lighting[locX][locY + 1][oLi].light
																		neighbor2[4] = locX
																		neighbor2[5] = locY + 1
																	end
																end
															end
														end	
													end
												end						
												local neighbor						
												if neighbor1[1] + neighbor1[2] + neighbor1[3] > neighbor2[1] + neighbor2[2] + neighbor2[3] then
													neighbor = neighbor1
												else
													neighbor = neighbor2
												end							
												if neighbor[1] + neighbor[2] + neighbor[3] > 0 then
													if math.abs( (neighbor[1] + neighbor[2] + neighbor[3]) - (mL[oLl].lighting[locX][locY][oLi].light[1] +
													mL[oLl].lighting[locX][locY][oLi].light[2] + 
													mL[oLl].lighting[locX][locY][oLi].light[3]) ) > 
													(object.light.falloff[1] + object.light.falloff[2] + object.light.falloff[3]) * 1.5 then
														local distance = math.sqrt( ((locXt - oLx) * (locXt - oLx)) + 
														((locYt - oLy) * (locYt - oLy))  )								
														local red = object.light.source[1] - (object.light.falloff[1] * distance)
														local green = object.light.source[2] - (object.light.falloff[2] * distance)
														local blue = object.light.source[3] - (object.light.falloff[3] * distance)
														tempML[#tempML + 1] = {locX, locY, red, green, blue}
													end
												end
											end						
										end					
										for i = 1, #tempML, 1 do
											mL[oLl].lighting[tempML[i][1]][tempML[i][2]][oLi].light = {tempML[i][3], 
												tempML[i][4], tempML[i][5]}
										end
									end
								end
							end				
						end	
						if object.lighting then
							if object.objType < 3 then
								local oL = object.light.source
								object:setFillColor(oL[1]*object.color[1], oL[2]*object.color[2], oL[3]*object.color[3])
							elseif object.objType == 3 then
								local oL = object.light.source
								for i = 1, object.numChildren, 1 do
									if object[i]._class then
										object[i]:setFillColor(oL[1]*object[i].color[1], oL[2]*object[i].color[2], oL[3]*object[i].color[3])
									end
								end
							elseif object.objType == 4 then
								local oL = object.light.source
								for i = 1, object.numChildren, 1 do
									if object[i]._class then
										object[i]:setStrokeColor(oL[1]*object[i].color[1], oL[2]*object[i].color[2], oL[3]*object[i].color[3])
									end
								end
							end
						end
					end
					------
				else
					--Clear Lighting
					if object.light then
						if not object.light.created then
							object.light.created = true
							if not object.light.id then
								object.light.id = lightIDs
							end
							lightIDs = lightIDs + 1						
							if not object.light.maxRange then
								local maxRange = object.light.range[1]
								for l = 1, 3, 1 do
									if object.light.range[l] > maxRange then
										maxRange = object.light.range[l]
									end
								end
								object.light.maxRange = maxRange
							end		
							if not object.light.levelPosX then
								object.light.levelPosX = object.levelPosX or object.x
								object.light.levelPosY = object.levelPosY or object.y
							end		
							if not object.light.alternatorCounter then
								object.light.alternatorCounter = 1
							end		
							if object.light.rays then
								object.light.areaIndex = 1
							end		
							if object.light.layerRelative then
								object.light.layer = i + object.light.layerRelative
								if object.light.layer < 1 then
									object.light.layer = 1
								end
								if object.light.layer > #map.layers then
									object.light.layer = #map.layers
								end
							end						
							if not object.light.layer then
								object.light.layer = i
							end						
							object.light.level = object.level
							object.light.dynamic = true
							object.light.area = {}
							map.lights[object.light.id] = object.light
						else
							if M.lightingData.refreshCounter == 1 then
								if object.light.rays then
									object.light.areaIndex = 1
								end			
								local length = #object.light.area
								for i = length, 1, -1 do
									local locX = object.light.area[i][1]
									local locY = object.light.area[i][2]
									object.light.area[i] = nil
									if worldWrapX then
										if locX < 1 - map.locOffsetX then
											locX = locX + map.width
										end
										if locX > map.width - map.locOffsetX then
											locX = locX - map.width
										end
									end
									if worldWrapY then
										if locY < 1 - map.locOffsetY then
											locY = locY + map.height
										end
										if locY > map.height - map.locOffsetY then
											locY = locY - map.height
										end
									end
									if object.light.layer then
										if map.layers[object.light.layer].lighting[locX] and map.layers[object.light.layer].lighting[locX][locY] then
											map.layers[object.light.layer].lighting[locX][locY][object.light.id] = nil
											map.lightToggle[locX][locY] = tonumber(system.getTimer())
										end	
									end
								end			
								if object.toggleRemoveLight then
									object.light = nil
									object.toggleRemoveLight = false				
								end
							end
						end
					end
					
					local movingSprites = movingSprites
					if movingSprites[object] and not holdSprite then
						local index = movingSprites[object]
						local velX = object.deltaX[index]
						local velY = object.deltaY[index]
						movingSprites[object] = index - 1						
						object:translate(velX, velY)						
						if movingSprites[object] == 0 then
							movingSprites[object] = nil
							object.deltaX = nil
							object.deltaY = nil
							object.isMoving = nil
							if object.onComplete then
								local temp = object.onComplete
								object.onComplete = nil
								local event = { name = "spriteMoveComplete", sprite = object}
								temp(event)
							end
						end
					end
					
					if holdSprite == object then
						if object.transition then
							transition.pause(object.transition)
						end
						object.paused = true
					elseif object.transition then
						if object.paused then
							transition.resume(object.transition)
							object.paused = nil
						end
						if object.transition._transitionHasCompleted then
							object.transition = nil
						elseif object.transitionDelta then
							object.transitionDelta = object.transitionDelta - 1
						end
					end
					
					--Update Position
					object.levelPosX = object.x
					object.levelPosY = object.y				
					if layerWrapX[i] and (object.wrapX == nil or object.wrapX == true) then
						while object.levelPosX < 1 - (map.locOffsetY * map.tileheight) do
							object.levelPosX = object.levelPosX + map.layers[i].width * map.tilewidth
						end
						while object.levelPosX > map.layers[i].width * map.tilewidth - (map.locOffsetY * map.tileheight) do
							object.levelPosX = object.levelPosX - map.layers[i].width * map.tilewidth
						end				
						if cameraX - object.x < map.layers[i].width * map.tilewidth / -2 then
							--wrap around to the left
							object.x = object.x - map.layers[i].width * map.tilewidth
						elseif cameraX - object.x > map.layers[i].width * map.tilewidth / 2 then
							--wrap around to the right
							object.x = object.x + map.layers[i].width * map.tilewidth
						end
					end
					if layerWrapY[i] and (object.wrapY == nil or object.wrapY == true) then
						while object.levelPosY < 1 - (map.locOffsetY * map.tileheight) do
							object.levelPosY = object.levelPosY + map.layers[i].height * map.tileheight
						end
						while object.levelPosY > map.layers[i].height * map.tileheight - (map.locOffsetY * map.tileheight) do
							object.levelPosY = object.levelPosY - map.layers[i].height * map.tileheight
						end					
						if cameraY - object.y < map.layers[i].height * map.tileheight / -2 then
							--wrap around to the left
							object.y = object.y - map.layers[i].height * map.tileheight
						elseif cameraY - object.y > map.layers[i].height * map.tileheight / 2 then
							--wrap around to the right
							object.y = object.y + map.layers[i].height * map.tileheight
						end
					end
				
					--CONSTRAIN TO MAP
					if object.constrainToMap then
						local constraints = object.constrainToMap
						local pushX, pushY = 0, 0
						if constraints[1] then
							if object.levelPosX < 1 - (map.locOffsetX * map.tilewidth) then
								pushX = 1 - (map.locOffsetX * map.tilewidth) - object.levelPosX
							end
						end
						if constraints[2] then
							if object.levelPosY < 1 - (map.locOffsetY * map.tileheight) then
								pushY = 1 - (map.locOffsetY * map.tileheight) - object.levelPosY
							end
						end
						if constraints[3] then
							if object.levelPosX > (map.width - map.locOffsetX) * map.tilewidth then
								pushX = (map.width - map.locOffsetX) * map.tilewidth - object.levelPosX
							end
						end
						if constraints[4] then
							if object.levelPosY > (map.height - map.locOffsetY) * map.tileheight then
								pushY = (map.height - map.locOffsetY) * map.tileheight - object.levelPosY
							end
						end
						object:translate(pushX, pushY)
					end
					
					object.locX = math.ceil(object.levelPosX / map.tilewidth)
					object.locY = math.ceil(object.levelPosY / map.tileheight)
					
					--Handle Offscreen Physics
					--print(object.name, M.managePhysicsStates, object.managePhysicsStates, object.managePhysicsStates)
					if M.managePhysicsStates and (object.managePhysicsStates == nil or object.managePhysicsStates == true) then
						if object.bodyType and masterGroup[i].vars.camera then
							local tempX, tempY = masterGroup.parent:localToContent(object.contentBounds.xMin, object.contentBounds.yMin)
							local leftTop = {masterGroup[i]:contentToLocal(tempX, tempY)}							
							tempX, tempY = masterGroup.parent:localToContent(object.contentBounds.xMax, object.contentBounds.yMax)
							local rightBottom = {masterGroup[i]:contentToLocal(tempX, tempY)}							
							local left = math.ceil(leftTop[1] / map.tilewidth) - 1
							local top = math.ceil(leftTop[2] / map.tileheight) - 1
							local right = math.ceil(rightBottom[1] / map.tilewidth) + 1
							local bottom = math.ceil(rightBottom[2] / map.tileheight) + 1
							
							if object.bodyType ~= "static" then
								if object.bounds and object.physicsRegion and #object.physicsRegion > 0 then
									for p = #object.physicsRegion, 1, -1 do
										local lx = object.physicsRegion[p][1]
										local ly = object.physicsRegion[p][2]
										local layer = object.physicsRegion[p][3]
										if lx < object.bounds[1] or lx > object.bounds[3] or ly < object.bounds[2] or ly > object.bounds[4] then
											if lx < masterGroup[i].vars.camera[1] or lx > masterGroup[i].vars.camera[3] or
											ly < masterGroup[i].vars.camera[2] or ly > masterGroup[i].vars.camera[4] then
												updateTile2({locX = lx, locY = ly, layer = layer, tile = -1, owner = object})
												--cullLargeTile(lx, ly, layer, nil, object)
												table.remove(object.physicsRegion, p)
											end
										end
									
									end
								else
									object.physicsRegion = {}
								end
								if not object.bounds or object.bounds[1] ~= left or object.bounds[2] ~= top or object.bounds[3] ~= right or object.bounds[4] ~= bottom then
									object.bounds = {left, top, right, bottom}
								end
								for lx = left, right, 1 do
									for ly = top, bottom, 1 do
										for j = 1, #map.layers, 1 do
											if lx < 1 - map.locOffsetX then
												lx = lx + map.layers[j].width
											end
											if lx > map.layers[j].width - map.locOffsetX then
												lx = lx - map.layers[j].width
											end				
		
											if ly < 1 - map.locOffsetY then
												ly = ly + map.layers[j].height
											end
											if ly > map.layers[j].height - map.locOffsetY then
												ly = ly - map.layers[j].height
											end
											if not tileObjects[j][lx][ly] and map.layers[j].world[lx][ly] ~= 0 then
												local owner = updateTile2({locX = lx, locY = ly, layer = j, onlyPhysics = true, owner = object})
												if owner then
													object.physicsRegion[#object.physicsRegion + 1] = {lx, ly, j}
												end
												--[[
												owner = nil
												owner = drawLargeTile(locX, locY, layer, object)
												if owner then
													object.physicsRegion[#object.physicsRegion + 1] = {owner[1], owner[2], j}
												end
												]]--
											end
											
											local tX, tY = lx, ly
											if tX < 1 - map.locOffsetX then
												tX = tX + map.layers[j].width
											end
											if tX > map.layers[j].width - map.locOffsetX then
												tX = tX - map.layers[j].width
											end				
	
											if tY < 1 - map.locOffsetY then
												tY = tY + map.layers[j].height
											end
											if tY > map.layers[j].height - map.locOffsetY then
												tY = tY - map.layers[j].height
											end
											
											if map.layers[j].largeTiles[tX] and map.layers[j].largeTiles[tX][tY] then
												for i = 1, #map.layers[j].largeTiles[tX][tY], 1 do
													local frameIndex = map.layers[j].largeTiles[tX][tY][i][1]
													local ltx = map.layers[j].largeTiles[tX][tY][i][2]
													local lty = map.layers[j].largeTiles[tX][tY][i][3]
													
													if not tileObjects[j][ltx][lty] then
														local owner = updateTile2({locX = ltx, locY = lty, layer = j, onlyPhysics = true, owner = object})
														if owner then
															object.physicsRegion[#object.physicsRegion + 1] = {ltx, lty, j}
														end
													end
												end
											end
											
											drawCulledObjects(lx, ly, j)
										end
									end
								end
							end
							if not object.offscreenPhysics then
								local tempX, tempY = masterGroup.parent:localToContent(object.contentBounds.xMin, object.contentBounds.yMin)
								local leftTop = {masterGroup[i]:contentToLocal(tempX, tempY)}							
								tempX, tempY = masterGroup.parent:localToContent(object.contentBounds.xMax, object.contentBounds.yMax)
								local rightBottom = {masterGroup[i]:contentToLocal(tempX, tempY)}							
								local left = math.ceil(leftTop[1] / map.tilewidth)
								local top = math.ceil(leftTop[2] / map.tileheight)
								local right = math.ceil(rightBottom[1] / map.tilewidth)
								local bottom = math.ceil(rightBottom[2] / map.tileheight)
								
								if left < masterGroup[i].vars.camera[1] and right > masterGroup[i].vars.camera[1] then
									left = masterGroup[i].vars.camera[1]
								end
								if top < masterGroup[i].vars.camera[2] and bottom > masterGroup[i].vars.camera[2] then
									top = masterGroup[i].vars.camera[2]
								end
								if right < masterGroup[i].vars.camera[3] and left > masterGroup[i].vars.camera[3] then
									right = masterGroup[i].vars.camera[3]
								end
								if bottom > masterGroup[i].vars.camera[4] and top < masterGroup[i].vars.camera[4] then
									bottom = masterGroup[i].vars.camera[4]
								end
								
								if (left >= masterGroup[i].vars.camera[1] and left <= masterGroup[i].vars.camera[3] and
								top >= masterGroup[i].vars.camera[2] and top <= masterGroup[i].vars.camera[4]) or
								
								(right >= masterGroup[i].vars.camera[1] and right <= masterGroup[i].vars.camera[3] and
								top >= masterGroup[i].vars.camera[2] and top <= masterGroup[i].vars.camera[4]) or
								
								(left >= masterGroup[i].vars.camera[1] and left <= masterGroup[i].vars.camera[3] and
								bottom >= masterGroup[i].vars.camera[2] and bottom <= masterGroup[i].vars.camera[4]) or
								
								(right >= masterGroup[i].vars.camera[1] and right <= masterGroup[i].vars.camera[3] and
								bottom >= masterGroup[i].vars.camera[2] and bottom <= masterGroup[i].vars.camera[4])then
									--onscreen
									if not object.properties or not object.properties.isAwake then
										object.isAwake = true
									end
									if not object.properties or not object.properties.isBodyActive then
										object.isBodyActive = true
									end
								elseif (left >= masterGroup[i].vars.camera[1] - 1 and left <= masterGroup[i].vars.camera[3] + 1 and
								top >= masterGroup[i].vars.camera[2] - 1 and top <= masterGroup[i].vars.camera[4] + 1) or
								
								(right >= masterGroup[i].vars.camera[1] - 1 and right <= masterGroup[i].vars.camera[3] + 1 and
								top >= masterGroup[i].vars.camera[2] - 1 and top <= masterGroup[i].vars.camera[4] + 1) or
								
								(left >= masterGroup[i].vars.camera[1] - 1 and left <= masterGroup[i].vars.camera[3] + 1 and
								bottom >= masterGroup[i].vars.camera[2] - 1 and bottom <= masterGroup[i].vars.camera[4] + 1) or
								
								(right >= masterGroup[i].vars.camera[1] - 1 and right <= masterGroup[i].vars.camera[3] + 1 and
								bottom >= masterGroup[i].vars.camera[2] - 1 and bottom <= masterGroup[i].vars.camera[4] + 1)then
									--edge
									if not object.properties or not object.properties.isAwake then
										object.isAwake = false
									end
									if not object.properties or not object.properties.isBodyActive then
										object.isBodyActive = true
									end
								else
									--offscreen
									if not object.properties or not object.properties.isBodyActive then
										object.isBodyActive = false
									end
								end
								
								--[[
								
								local isState = nil
								if (left >= masterGroup[i].vars.camera[1] or right <= masterGroup[i].vars.camera[3] or
								top >= masterGroup[i].vars.camera[2] or bottom <= masterGroup[i].vars.camera[4]) then
									--onscreen
									if not object.properties or not object.properties.isAwake then
										object.isAwake = true
									end
									if not object.properties or not object.properties.isBodyActive then
										object.isBodyActive = true
									end
								elseif (left >= masterGroup[i].vars.camera[1] - 1 or right <= masterGroup[i].vars.camera[3] + 1 or
								top >= masterGroup[i].vars.camera[2] - 1 or bottom <= masterGroup[i].vars.camera[4] + 1) then
									--edge
									if not object.properties or not object.properties.isAwake then
										object.isAwake = false
									end
									if not object.properties or not object.properties.isBodyActive then
										object.isBodyActive = true
									end
								else
									--offscreen
									if not object.properties or not object.properties.isBodyActive then
										object.isBodyActive = false
									end
								end
								]]--
								
								--[[
								local locX = math.ceil(object.x / map.tilewidth)
								local locY = math.ceil(object.y / map.tilewidth)
								
								if (locX < masterGroup[i].vars.camera[1] - 1 or locX > masterGroup[i].vars.camera[3] + 1) or
								(locY < masterGroup[i].vars.camera[2] - 1 or locY > masterGroup[i].vars.camera[4] + 1) then
									if not object.properties or not object.properties.isBodyActive then
										object.isBodyActive = false
									end
								elseif (locX < masterGroup[i].vars.camera[1] or locX > masterGroup[i].vars.camera[3]) or
								(locY < masterGroup[i].vars.camera[2] or locY > masterGroup[i].vars.camera[4]) then
									if not object.properties or not object.properties.isAwake then
										object.isAwake = false
									end
									if not object.properties or not object.properties.isBodyActive then
										object.isBodyActive = true
									end
								else
									if not object.properties or not object.properties.isAwake then
										object.isAwake = true
									end
									if not object.properties or not object.properties.isBodyActive then
										object.isBodyActive = true
									end
								end
								]]--
							end
						end
					end
					
					--Sort Sprites
					if object.sortSprite and M.enableSpriteSorting then
						local adjustedPosition = object.levelPosY + ((map.locOffsetY - 1) * map.tileheight)
					
						--local tempY = ceil(math.round(object.levelPosY) / (map.tileheight / M.spriteSortResolution))	
						--print(object.levelPosY, adjustedPosition)		
						
						local tempY = ceil(math.round(adjustedPosition) / (map.tileheight / M.spriteSortResolution))	
						--print(tempY)
						if tempY > (map.layers[i].height * M.spriteSortResolution) then
							while tempY > map.layers[i].height do
								tempY = tempY - (map.layers[i].height * M.spriteSortResolution)
							end
						elseif tempY < 1 then
							while tempY < 1 do
								tempY = tempY + (map.layers[i].height * M.spriteSortResolution)
							end
						end		
						if not object.depthBuffer or object.depthBuffer ~= tempY then
							if object.name == "player" then
								--print("this", object.name, tempY, masterGroup[i][tempY])
							end
							for key,value in pairs( masterGroup[i][2][tempY]) do
								--print(key,value)
							end
							--print(masterGroup[i], masterGroup[i][2], tempY, masterGroup[i][2].numChildren)
							masterGroup[i][2][tempY]:insert(object)
						end
						object.depthBuffer = tempY						
						if object.sortSpriteOnce then
							object.sortSprite = false
						end		
					end
					
					--Apply HeightMap
					if M.enableHeightMaps then
						if object.heightMap then
							if not object.nativeWidth then
								object.nativeWidth = object.width
								object.nativeHeight = object.height
							end
							local hM = object.heightMap
							local offsetX = object.nativeWidth / 2
							local offsetY = object.nativeHeight / 2
							local x = object.x
							local y = object.y
							local oP = object.path
							oP["x1"] = (((cameraX - (x - offsetX)) * (1 + (hM[1] or 0))) - (cameraX - (x - offsetX))) * -1
							oP["y1"] = (((cameraY - (y - offsetY)) * (1 + (hM[1] or 0))) - (cameraY - (y - offsetY))) * -1
							
							oP["x2"] = (((cameraX - (x - offsetX)) * (1 + (hM[2] or 0))) - (cameraX - (x - offsetX))) * -1
							oP["y2"] = (((cameraY - (y + offsetY)) * (1 + (hM[2] or 0))) - (cameraY - (y + offsetY))) * -1
							
							oP["x3"] = (((cameraX - (x + offsetX)) * (1 + (hM[3] or 0))) - (cameraX - (x + offsetX))) * -1
							oP["y3"] = (((cameraY - (y + offsetY)) * (1 + (hM[3] or 0))) - (cameraY - (y + offsetY))) * -1
							
							oP["x4"] = (((cameraX - (x + offsetX)) * (1 + (hM[4] or 0))) - (cameraX - (x + offsetX))) * -1
							oP["y4"] = (((cameraY - (y - offsetY)) * (1 + (hM[4] or 0))) - (cameraY - (y - offsetY))) * -1
						elseif (map.layers[i].heightMap or map.heightMap) and object.followHeightMap then
							if not object.nativeWidth then
								object.nativeWidth = object.width
								object.nativeHeight = object.height
							end							
							local mH
							if map.heightMap then
								mH = map.heightMap
							else
								mH = map.layers[i].heightMap
							end							
							local offsetX = object.nativeWidth / 2 
							local offsetY = object.nativeHeight / 2 
							local x = object.x
							local y = object.y							
							local lX = object.levelPosX / map.tilewidth
							local lY = object.levelPosY / map.tileheight
							local toggleX = math.round(lX)
							local toggleY = math.round(lY)
							local locX1, locX2, locY1, locY2
							if toggleX < lX then
								locX2 = math.ceil(object.levelPosX / map.tilewidth)
								locX1 = locX2 - 1
								if locX1 < 1 then
									locX1 = #mH
								end	
							else
								locX1 = math.ceil(object.levelPosX / map.tilewidth)
								locX2 = locX1 + 1
								if locX2 > #mH then
									locX2 = 1
								end	
							end
							if toggleY < lY then
								locY2 = math.ceil(object.levelPosY / map.tileheight)
								locY1 = locY2 - 1
								if locY1 < 1 then
									locY1 = #mH[1]
								end	
							else
								locY1 = math.ceil(object.levelPosY / map.tileheight)
								locY2 = locY1 + 1
								if locY2 > #mH[1] then
									locY2 = 1
								end	
							end							
							local locX = object.locX
							local locY = object.locY							
							local tX1 = locX1 * map.tilewidth - (map.tilewidth / 2)
							local tY1 = locY1 * map.tileheight - (map.tileheight / 2)
							local tX2 = locX2 * map.tilewidth - (map.tilewidth / 2)
							local tY2 = locY2 * map.tileheight - (map.tileheight / 2)
							local area1 = (object.levelPosX - tX1) * (object.levelPosY - tY1)
							local area2 = (object.levelPosX - tX1) * (tY2 - object.levelPosY)
							local area3 = (tX2 - object.levelPosX) * (tY2 - object.levelPosY)
							local area4 = (tX2 - object.levelPosX) * (object.levelPosY - tY1)
							local area = map.tilewidth * map.tileheight							
							local height1 = mH[locX1][locY1] * ((area3) / area)
							local height2 = mH[locX1][locY2] * ((area4) / area)
							local height3 = mH[locX2][locY2] * ((area1) / area)
							local height4 = mH[locX2][locY1] * ((area2) / area)							
							local tempHeight = height1 + height2 + height3 + height4
							local oP = object.path
							oP["x1"] = (((cameraX - (x - offsetX)) * (1 + tempHeight)) - (cameraX - (x - offsetX))) * -1
							oP["y1"] = (((cameraY - (y - offsetY)) * (1 + tempHeight)) - (cameraY - (y - offsetY))) * -1
							
							oP["x2"] = (((cameraX - (x - offsetX)) * (1 + tempHeight)) - (cameraX - (x - offsetX))) * -1
							oP["y2"] = (((cameraY - (y + offsetY)) * (1 + tempHeight)) - (cameraY - (y + offsetY))) * -1
							
							oP["x3"] = (((cameraX - (x + offsetX)) * (1 + tempHeight)) - (cameraX - (x + offsetX))) * -1
							oP["y3"] = (((cameraY - (y + offsetY)) * (1 + tempHeight)) - (cameraY - (y + offsetY))) * -1
							
							oP["x4"] = (((cameraX - (x + offsetX)) * (1 + tempHeight)) - (cameraX - (x + offsetX))) * -1
							oP["y4"] = (((cameraY - (y - offsetY)) * (1 + tempHeight)) - (cameraY - (y - offsetY))) * -1							
						end
					end
					
					--Apply Lighting to Non-Light Objects, Trigger Events
					if object.lighting then
						if M.enableLighting then
							object.litBy = {}
							local locX = object.locX
							local locY = object.locY
							local mapLayerFalloff = map.properties.lightLayerFalloff
							local mapLevelFalloff = map.properties.lightLevelFalloff
							local red, green, blue = map.layers[i].redLight, map.layers[i].greenLight, map.layers[i].blueLight
							if map.perlinLighting then
								red = red * map.perlinLighting[locX][locY]
								green = green * map.perlinLighting[locX][locY]
								blue = blue * map.perlinLighting[locX][locY]
							elseif map.layers[i].perlinLighting then
								red = red * map.layers[i].perlinLighting[locX][locY]
								green = green * map.layers[i].perlinLighting[locX][locY]
								blue = blue * map.layers[i].perlinLighting[locX][locY]
							end
							for k = 1, #map.layers, 1 do
								if map.layers[k].lighting[locX] then
									if map.layers[k].lighting[locX][locY] then
										local temp = map.layers[k].lighting[locX][locY]
										local tempSources = {}
										for key,value in pairs(object.prevLitBy) do
											tempSources[key] = true
										end
										for key,value in pairs(temp) do
											local levelDiff = math.abs(M.getLevel(i) - map.lights[key].level)
											local layerDiff = math.abs(i - map.lights[key].layer)							
											local layerFalloff, levelFalloff
											if map.lights[key].layerFalloff then
												layerFalloff = map.lights[key].layerFalloff
											else
												layerFalloff = mapLayerFalloff
											end							
											if map.lights[key].levelFalloff then
												levelFalloff = map.lights[key].levelFalloff
											else
												levelFalloff = mapLevelFalloff
											end							
											local tR = temp[key].light[1] - (levelDiff * levelFalloff[1]) - (layerDiff * layerFalloff[1])
											local tG = temp[key].light[2] - (levelDiff * levelFalloff[2]) - (layerDiff * layerFalloff[2])
											local tB = temp[key].light[3] - (levelDiff * levelFalloff[3]) - (layerDiff * layerFalloff[3])							
											if object.lightingListeners[key] then
												local event = { name = key, target = object, source = map.lights[key], light = {tR, tG, tB}}
												if not object.prevLitBy[key] then
													object.prevLitBy[key] = true
													event.phase = "began"
												else
													event.phase = "maintained"
												end
												object:dispatchEvent( event )
												tempSources[key] = nil
											end							
											if tR > red then
												red = tR
											end
											if tG > green then
												green = tG
											end
											if tB > blue then
												blue = tB
											end							
											object.litBy[#object.litBy + 1] = key							
										end
										for key,value in pairs(tempSources) do
											if object.lightingListeners[key] then
												object.prevLitBy[key] = nil
												local event = { name = key, target = object, source = map.lights[key], light = {tR, tG, tB}}
												event.phase = "ended"
												object:dispatchEvent( event )
											end
										end
									else						
										for key,value in pairs(object.prevLitBy) do
											if object.lightingListeners[key] and not map.lights[key] then
												object.prevLitBy[key] = nil
												local event = { name = key, target = object, source = map.lights[key], light = {tR, tG, tB}}
												event.phase = "ended"
												object:dispatchEvent( event )
											elseif object.lightingListeners[key] and map.lights[key].layer == k then
												object.prevLitBy[key] = nil
												local event = { name = key, target = object, source = map.lights[key], light = {tR, tG, tB}}
												event.phase = "ended"
												object:dispatchEvent( event )
											end
										end						
									end
								end
							end
							if object.objType < 3 then
								object:setFillColor(red*object.color[1], green*object.color[2], blue*object.color[3])
							elseif object.objType == 3 then
								for i = 1, object.numChildren, 1 do
									if object[i]._class then
										object[i]:setFillColor(red*object[i].color[1], green*object[i].color[2], blue*object[i].color[3])
									end
								end
							elseif object.objType == 4 then
								for i = 1, object.numChildren, 1 do
									if object[i]._class then
										object[i]:setStrokeColor(red*object[i].color[1], green*object[i].color[2], blue*object[i].color[3])
									end
								end
							end
						else
							local locX = object.locX
							local locY = object.locY
							local red, green, blue = map.layers[i].redLight, map.layers[i].greenLight, map.layers[i].blueLight
							if map.perlinLighting then
								red = red * map.perlinLighting[locX][locY]
								green = green * map.perlinLighting[locX][locY]
								blue = blue * map.perlinLighting[locX][locY]
							elseif map.layers[i].perlinLighting then
								red = red * map.layers[i].perlinLighting[locX][locY]
								green = green * map.layers[i].perlinLighting[locX][locY]
								blue = blue * map.layers[i].perlinLighting[locX][locY]
							end
							if object.objType < 3 then
								object:setFillColor(red*object.color[1], green*object.color[2], blue*object.color[3])
							elseif object.objType == 3 then
								for i = 1, object.numChildren, 1 do
									if object[i]._class then
										object[i]:setFillColor(red*object[i].color[1], green*object[i].color[2], blue*object[i].color[3])
									end
								end
							elseif object.objType == 4 then
								for i = 1, object.numChildren, 1 do
									if object[i]._class then
										object[i]:setStrokeColor(red*object[i].color[1], green*object[i].color[2], blue*object[i].color[3])
									end
								end
							end
						end
					end
				
					--Cast Light
					if M.enableLighting and object.light then
						if M.lightingData.refreshCounter == 1 then
							object.light.levelPosX = object.levelPosX
							object.light.levelPosY = object.levelPosY
						end					
						if M.lightingData.refreshCounter == 1 then
							if object.levelPosX > 0 - (map.locOffsetX * map.tilewidth) and object.levelPosX <= (map.width - map.locOffsetX) * map.tilewidth then
								if object.levelPosY > 0 - (map.locOffsetY * map.tileheight) and object.levelPosY <= (map.height - map.locOffsetY) * map.tileheight then
									if object.light.rays then
										for k = 1, #object.light.rays, 1 do
											M.processLightRay(object.light.layer, object.light, object.light.rays[k])
										end
									else								
										M.processLight(object.light.layer, object.light)									
										local length = #object.light.area
										local tempML = {}
										local oLx = object.light.locX
										local oLy = object.light.locY
										local oLl = object.light.layer
										local oLi = object.light.id
										local mL = map.layers
										for i = length, 1, -1 do
											local locX = object.light.area[i][1]
											local locY = object.light.area[i][2]
											local locXt = locX
											local locYt = locY						
											if worldWrapX then
												if locX < 1 - map.locOffsetX then
													locX = locX + map.width
												end
												if locX > map.width - map.locOffsetX then
													locX = locX - map.width
												end
											end
											if worldWrapY then
												if locY < 1 - map.locOffsetY then
													locY = locY + map.height
												end
												if locY > map.height - map.locOffsetY then
													locY = locY - map.height
												end
											end						
											local neighbor1 = {0, 0, 0}
											local neighbor2 = {0, 0, 0}										
											if locX ~= oLx and locY ~= oLy and map.lightingData[mL[oLl].world[locX][locY]]then											
												if locXt > oLx and locYt < oLy then
													--top right
													if oLl then
														if mL[oLl].lighting[locX - 1] and mL[oLl].lighting[locX][locY] then
															if not map.lightingData[mL[oLl].world[locX - 1][locY]] then
																if mL[oLl].lighting[locX - 1][locY] then
																	if mL[oLl].lighting[locX - 1][locY][oLi] then
																		neighbor1 = mL[oLl].lighting[locX - 1][locY][oLi].light
																		neighbor1[4] = locX - 1
																		neighbor1[5] = locY
																	end
																end
															end
														end	
														if mL[oLl].lighting[locX] and mL[oLl].lighting[locX][locY + 1] then
															if not map.lightingData[mL[oLl].world[locX][locY + 1]] then
																if mL[oLl].lighting[locX][locY + 1] then
																	if mL[oLl].lighting[locX][locY + 1][oLi] then
																		neighbor2 = mL[oLl].lighting[locX][locY + 1][oLi].light
																		neighbor2[4] = locX
																		neighbor2[5] = locY + 1
																	end
																end
															end
														end	
													end
												elseif locXt > oLx and locYt > oLy then
													--bottom right
													if oLl then
														if mL[oLl].lighting[locX - 1] and mL[oLl].lighting[locX][locY] then
															if not map.lightingData[mL[oLl].world[locX - 1][locY]] then
																if mL[oLl].lighting[locX - 1][locY] then
																	if mL[oLl].lighting[locX - 1][locY][oLi] then
																		neighbor1 = mL[oLl].lighting[locX - 1][locY][oLi].light
																		neighbor1[4] = locX - 1
																		neighbor1[5] = locY
																	end
																end
															end
														end	
														if mL[oLl].lighting[locX] and mL[oLl].lighting[locX][locY - 1] then
															if not map.lightingData[mL[oLl].world[locX][locY - 1]] then
																if mL[oLl].lighting[locX][locY - 1] then
																	if mL[oLl].lighting[locX][locY - 1][oLi] then
																		neighbor2 = mL[oLl].lighting[locX][locY - 1][oLi].light
																		neighbor2[4] = locX
																		neighbor2[5] = locY - 1
																	end
																end
															end
														end	
													end
												elseif locXt < oLx and locYt > oLy then
													--bottom left
													if oLl then
														if mL[oLl].lighting[locX + 1] and mL[oLl].lighting[locX][locY] then
															if not map.lightingData[mL[oLl].world[locX + 1][locY]] then
																if mL[oLl].lighting[locX + 1][locY] then
																	if mL[oLl].lighting[locX + 1][locY][oLi] then
																		neighbor1 = mL[oLl].lighting[locX + 1][locY][oLi].light
																		neighbor1[4] = locX + 1
																		neighbor1[5] = locY
																	end
																end
															end
														end	
														if mL[oLl].lighting[locX] and mL[oLl].lighting[locX][locY - 1] then
															if not map.lightingData[mL[oLl].world[locX][locY - 1]] then
																if mL[oLl].lighting[locX][locY - 1] then
																	if mL[oLl].lighting[locX][locY - 1][oLi] then
																		neighbor2 = mL[oLl].lighting[locX][locY - 1][oLi].light
																		neighbor2[4] = locX
																		neighbor2[5] = locY - 1
																	end
																end
															end
														end	
													end
												elseif locXt < oLx and locYt < oLy then
													--top left
													if oLl then
														if mL[oLl].lighting[locX + 1] and mL[oLl].lighting[locX][locY] then
															if not map.lightingData[mL[oLl].world[locX + 1][locY]] then
																if mL[oLl].lighting[locX + 1][locY] then
																	if mL[oLl].lighting[locX + 1][locY][oLi] then
																		neighbor1 = mL[oLl].lighting[locX + 1][locY][oLi].light
																		neighbor1[4] = locX + 1
																		neighbor1[5] = locY
																	end
																end
															end
														end	
														if mL[oLl].lighting[locX] and mL[oLl].lighting[locX][locY + 1] then
															if not map.lightingData[mL[oLl].world[locX][locY + 1]] then
																if mL[oLl].lighting[locX][locY + 1] then
																	if mL[oLl].lighting[locX][locY + 1][oLi] then
																		neighbor2 = mL[oLl].lighting[locX][locY + 1][oLi].light
																		neighbor2[4] = locX
																		neighbor2[5] = locY + 1
																	end
																end
															end
														end	
													end
												end						
												local neighbor						
												if neighbor1[1] + neighbor1[2] + neighbor1[3] > neighbor2[1] + neighbor2[2] + neighbor2[3] then
													neighbor = neighbor1
												else
													neighbor = neighbor2
												end							
												if neighbor[1] + neighbor[2] + neighbor[3] > 0 then
													if math.abs( (neighbor[1] + neighbor[2] + neighbor[3]) - (mL[oLl].lighting[locX][locY][oLi].light[1] +
													mL[oLl].lighting[locX][locY][oLi].light[2] + 
													mL[oLl].lighting[locX][locY][oLi].light[3]) ) > 
													(object.light.falloff[1] + object.light.falloff[2] + object.light.falloff[3]) * 1.5 then
														local distance = math.sqrt( ((locXt - oLx) * (locXt - oLx)) + 
														((locYt - oLy) * (locYt - oLy))  ) 									
														local red = object.light.source[1] - (object.light.falloff[1] * distance)
														local green = object.light.source[2] - (object.light.falloff[2] * distance)
														local blue = object.light.source[3] - (object.light.falloff[3] * distance)
														tempML[#tempML + 1] = {locX, locY, red, green, blue}
													end
												end
											end						
										end					
										for i = 1, #tempML, 1 do
											mL[oLl].lighting[tempML[i][1]][tempML[i][2]][oLi].light = {tempML[i][3], 
												tempML[i][4], tempML[i][5]}
										end
									end
								end
							end				
						end	
						if object.lighting then
							if object.objType < 3 then
								local oL = object.light.source
								object:setFillColor(oL[1]*object.color[1], oL[2]*object.color[2], oL[3]*object.color[3])
							elseif object.objType == 3 then
								local oL = object.light.source
								for i = 1, object.numChildren, 1 do
									if object[i]._class then
										object[i]:setFillColor(oL[1]*object[i].color[1], oL[2]*object[i].color[2], oL[3]*object[i].color[3])
									end
								end
							elseif object.objType == 4 then
								local oL = object.light.source
								for i = 1, object.numChildren, 1 do
									if object[i]._class then
										object[i]:setStrokeColor(oL[1]*object[i].color[1], oL[2]*object[i].color[2], oL[3]*object[i].color[3])
									end
								end
							end
						end
					end
					
					--Cull Object
					if masterGroup[i].vars.camera and object.objectKey and ((object.properties and object.properties.cull == "true") or (map.layers[i].properties and map.layers[i].properties.cullObjects == "true")) then
						local tempX, tempY = masterGroup.parent:localToContent(object.contentBounds.xMin, object.contentBounds.yMin)
						local leftTop = {masterGroup[i]:contentToLocal(tempX, tempY)}							
						tempX, tempY = masterGroup.parent:localToContent(object.contentBounds.xMax, object.contentBounds.yMax)
						local rightBottom = {masterGroup[i]:contentToLocal(tempX, tempY)}							
						local tleft = math.ceil(leftTop[1] / map.tilewidth)
						local ttop = math.ceil(leftTop[2] / map.tileheight)
						local tright = math.ceil(rightBottom[1] / map.tilewidth)
						local tbottom = math.ceil(rightBottom[2] / map.tileheight)
						
						local left, top, right, bottom = tleft, ttop, tright, tbottom
						if tleft < masterGroup[i].vars.camera[1] and tright > masterGroup[i].vars.camera[1] then
							left = masterGroup[i].vars.camera[1]
						end
						if ttop < masterGroup[i].vars.camera[2] and tbottom > masterGroup[i].vars.camera[2] then
							top = masterGroup[i].vars.camera[2]
						end
						if tright < masterGroup[i].vars.camera[3] and tleft > masterGroup[i].vars.camera[3] then
							right = masterGroup[i].vars.camera[3]
						end
						if tbottom > masterGroup[i].vars.camera[4] and ttop < masterGroup[i].vars.camera[4] then
							bottom = masterGroup[i].vars.camera[4]
						end
						
						if (left >= masterGroup[i].vars.camera[1] and left <= masterGroup[i].vars.camera[3] and
						top >= masterGroup[i].vars.camera[2] and top <= masterGroup[i].vars.camera[4]) or
						
						(right >= masterGroup[i].vars.camera[1] and right <= masterGroup[i].vars.camera[3] and
						top >= masterGroup[i].vars.camera[2] and top <= masterGroup[i].vars.camera[4]) or
						
						(left >= masterGroup[i].vars.camera[1] and left <= masterGroup[i].vars.camera[3] and
						bottom >= masterGroup[i].vars.camera[2] and bottom <= masterGroup[i].vars.camera[4]) or
						
						(right >= masterGroup[i].vars.camera[1] and right <= masterGroup[i].vars.camera[3] and
						bottom >= masterGroup[i].vars.camera[2] and bottom <= masterGroup[i].vars.camera[4])then
							--onscreen
						
						elseif (left >= masterGroup[i].vars.camera[1] - 1 and left <= masterGroup[i].vars.camera[3] + 1 and
						top >= masterGroup[i].vars.camera[2] - 1 and top <= masterGroup[i].vars.camera[4] + 1) or
						
						(right >= masterGroup[i].vars.camera[1] - 1 and right <= masterGroup[i].vars.camera[3] + 1 and
						top >= masterGroup[i].vars.camera[2] - 1 and top <= masterGroup[i].vars.camera[4] + 1) or
						
						(left >= masterGroup[i].vars.camera[1] - 1 and left <= masterGroup[i].vars.camera[3] + 1 and
						bottom >= masterGroup[i].vars.camera[2] - 1 and bottom <= masterGroup[i].vars.camera[4] + 1) or
						
						(right >= masterGroup[i].vars.camera[1] - 1 and right <= masterGroup[i].vars.camera[3] + 1 and
						bottom >= masterGroup[i].vars.camera[2] - 1 and bottom <= masterGroup[i].vars.camera[4] + 1)then
							--edge
						else
							--offscreen
							--sprites[spriteName].objectKey = ky
							--sprites[spriteName].objectLayer = layer
							
							local tiledObject = map.layers[i].objects[object.objectKey]
							tiledObject.cullData = {object.x, object.y, object.width, object.height, object.rotation}
							tiledObject.properties.wasDrawn = false
							
							if object.physicsRegion and #object.physicsRegion > 0 then
								for p = #object.physicsRegion, 1, -1 do
									local lx = object.physicsRegion[p][1]
									local ly = object.physicsRegion[p][2]
									local layer = object.physicsRegion[p][3]
									updateTile2({locX = lx, locY = ly, layer = layer, tile = -1, owner = object})
									table.remove(object.physicsRegion, p)							
								end
							end
							
							local mL = map.layers[object.objectLayer]
							
							tiledObject.cullData[6] = {}
							for x = tleft, tright, 1 do
								for y = ttop, tbottom, 1 do
									if not mL.extendedObjects[x][y] then
										mL.extendedObjects[x][y] = {}
									end
									
									mL.extendedObjects[x][y][#mL.extendedObjects[x][y] + 1] = {object.objectLayer, object.objectKey}
									tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = {x, y, #mL.extendedObjects[x][y]}
									
								end
							end
							
							if bob and tright - tleft < masterGroup[i].vars.camera[3] - masterGroup[i].vars.camera[1] then
								if tbottom - ttop < masterGroup[i].vars.camera[4] - masterGroup[i].vars.camera[2] then
									--four corners
									--print(tleft, ttop, tright, tbottom)
									if not mL.extendedObjects[tleft][ttop] then
										mL.extendedObjects[tleft][ttop] = {}
									end
									if not mL.extendedObjects[tright][ttop] then
										mL.extendedObjects[tright][ttop] = {}
									end
									if not mL.extendedObjects[tleft][tbottom] then
										mL.extendedObjects[tleft][tbottom] = {}
									end
									if not mL.extendedObjects[tright][tbottom] then
										mL.extendedObjects[tright][tbottom] = {}
									end
									
									mL.extendedObjects[tleft][ttop][#mL.extendedObjects[tleft][ttop] + 1] = {object.objectLayer, object.objectKey}
									mL.extendedObjects[tright][ttop][#mL.extendedObjects[tright][ttop] + 1] = {object.objectLayer, object.objectKey}
									mL.extendedObjects[tleft][tbottom][#mL.extendedObjects[tleft][tbottom] + 1] = {object.objectLayer, object.objectKey}
									mL.extendedObjects[tright][tbottom][#mL.extendedObjects[tright][tbottom] + 1] = {object.objectLayer, object.objectKey}
									
									tiledObject.cullData[6] = {
										{tleft, ttop, #mL.extendedObjects[tleft][ttop]},
										{tright, ttop, #mL.extendedObjects[tright][ttop]},
										{tleft, tbottom, #mL.extendedObjects[tleft][tbottom]},
										{tright, tbottom, #mL.extendedObjects[tright][tbottom]}
									}
									
									if q then
									tiledObject.cullData[6] = {
										mL.extendedObjects[tleft][ttop][#mL.extendedObjects[tleft][ttop]],
										mL.extendedObjects[tright][ttop][#mL.extendedObjects[tright][ttop]],
										mL.extendedObjects[tleft][tbottom][#mL.extendedObjects[tleft][tbottom]],
										mL.extendedObjects[tright][tbottom][#mL.extendedObjects[tright][tbottom]]
									}
									end
								else
									--double columns
									tiledObject.cullData[6] = {}
									
									for y = ttop, tbottom, 1 do
										if not mL.extendedObjects[tleft][y] then
											mL.extendedObjects[tleft][y] = {}
										end
										if not mL.extendedObjects[tright][y] then
											mL.extendedObjects[tright][y] = {}
										end
										
										mL.extendedObjects[tleft][y][#mL.extendedObjects[tleft][y] + 1] = {object.objectLayer, object.objectKey}
										mL.extendedObjects[tright][y][#mL.extendedObjects[tright][y] + 1] = {object.objectLayer, object.objectKey}
										
										tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = {tleft, y, #mL.extendedObjects[tleft][y]}
										tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = {tright, y, #mL.extendedObjects[tright][y]}
										
										if q then
										tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = mL.extendedObjects[tleft][y][#mL.extendedObjects[tleft][y]]
										tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = mL.extendedObjects[tright][y][#mL.extendedObjects[tright][y]]
										end
									end
								end
							elseif bob then
								if tbottom - ttop < masterGroup[i].vars.camera[4] - masterGroup[i].vars.camera[2] then
									--double rows
									tiledObject.cullData[6] = {}
									
									for x = tleft, tright, 1 do
										if not mL.extendedObjects[x][ttop] then
											mL.extendedObjects[x][ttop] = {}
										end
										if not mL.extendedObjects[x][tbottom] then
											mL.extendedObjects[x][tbottom] = {}
										end
										
										mL.extendedObjects[x][ttop][#mL.extendedObjects[x][ttop] + 1] = {object.objectLayer, object.objectKey}
										mL.extendedObjects[x][tbottom][#mL.extendedObjects[x][tbottom] + 1] = {object.objectLayer, object.objectKey}
										
										tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = {x, ttop, #mL.extendedObjects[x][ttop]}
										tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = {x, tbottom, #mL.extendedObjects[x][tbottom]}
										
										if q then
										tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = mL.extendedObjects[x][ttop][#mL.extendedObjects[x][ttop]]
										tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = mL.extendedObjects[x][tbottom][#mL.extendedObjects[x][tbottom]]
										end
									end
								else
									--rows and columns
									tiledObject.cullData[6] = {}
									
									for x = tleft, tright, 1 do
										if not mL.extendedObjects[x][ttop] then
											mL.extendedObjects[x][ttop] = {}
										end
										if not mL.extendedObjects[x][tbottom] then
											mL.extendedObjects[x][tbottom] = {}
										end
										
										mL.extendedObjects[x][ttop][#mL.extendedObjects[x][ttop] + 1] = {object.objectLayer, object.objectKey}
										mL.extendedObjects[x][tbottom][#mL.extendedObjects[x][tbottom] + 1] = {object.objectLayer, object.objectKey}
										
										tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = {x, ttop, #mL.extendedObjects[x][ttop]}
										tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = {x, tbottom, #mL.extendedObjects[x][tbottom]}
										
										if q then
										tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = mL.extendedObjects[x][ttop][#mL.extendedObjects[x][ttop]]
										tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = mL.extendedObjects[x][tbottom][#mL.extendedObjects[x][tbottom]]
										end
									end
									
									for y = ttop - 1, tbottom + 1, 1 do
										if not mL.extendedObjects[tleft][y] then
											mL.extendedObjects[tleft][y] = {}
										end
										if not mL.extendedObjects[tright][y] then
											mL.extendedObjects[tright][y] = {}
										end
										
										mL.extendedObjects[tleft][y][#mL.extendedObjects[tleft][y] + 1] = {object.objectLayer, object.objectKey}
										mL.extendedObjects[tright][y][#mL.extendedObjects[tright][y] + 1] = {object.objectLayer, object.objectKey}
										
										tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = {tleft, y, #mL.extendedObjects[tleft][y]}
										tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = {tright, y, #mL.extendedObjects[tright][y]}
										
										if q then
										tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = mL.extendedObjects[tleft][y][#mL.extendedObjects[tleft][y]]
										tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = mL.extendedObjects[tright][y][#mL.extendedObjects[tright][y]]
										end
									end
								end
							end

							M.removeSprite(object)
						end
					end
					------
				end
			end
			
			for i = 1, #map.layers, 1 do	
				if map.orientation == 1 then
					for j = masterGroup[i].numChildren, 1, -1 do
						if masterGroup[i][j].numChildren then
							for k = masterGroup[i][j].numChildren, 1, -1 do
								if not masterGroup[i][j][k].tiles then
									local object = masterGroup[i][j][k]
									if object then
										processObject(object, i)
									end
								end
							end
						end
					end
				else
					for j = masterGroup[i].numChildren, 1, -1 do
						if not masterGroup[i][j].tiles then
							if masterGroup[i][j].depthBuffer then
								for k = 1, masterGroup[i][j].numChildren, 1 do
									for m = 1, masterGroup[i][j][k].numChildren, 1 do
										local object = masterGroup[i][j][k][m]
										if object then
											processObject(object, i)
										end
									end
								end
							else
								local object = masterGroup[i][j]
								if object then
									processObject(object, i)
								end
							end
						end
					end
				end
			end
		end
		M.sprites = sprites
		
		--MOVE CAMERA
		local finalVelX = {}
		local finalVelY = {}
		local cameraVelX = {}
		local cameraVelY = {}
		if not M.cameraFrozen then
			if map.orientation == 1 then
				if refMove then
					local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
					local cameraX, cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)					
					local isoPos = M.isoUntransform2(cameraX, cameraY)
					cameraX = isoPos[1]
					cameraY = isoPos[2]
					local cameraLocX = math.ceil(cameraX / map.tilewidth)
					local cameraLocY = math.ceil(cameraY / map.tileheight)					
					local velX = deltaX[refLayer][1]
					local velY = deltaY[refLayer][1]
					local tempVelX = deltaX[refLayer][1]
					local tempVelY = deltaY[refLayer][1]					
					local check = #map.layers
					for i = 1, #map.layers, 1 do
						if isCameraMoving[i] then
							if parallaxToggle[i] then
								finalVelX[i] = tempVelX * map.layers[i].parallaxX / map.layers[i].properties.scaleX
								finalVelY[i] = tempVelY * map.layers[i].parallaxY / map.layers[i].properties.scaleY
							else
								finalVelX[i] = tempVelX
								finalVelY[i] = tempVelY
							end
						end
						table.remove(deltaX[i], 1)
						table.remove(deltaY[i], 1)
						if not deltaX[i][1] then
							check = check - 1
							isCameraMoving[i] = false
							parallaxToggle[i] = true
							refMove = false
							--holdSprite = nil
						end
					end					
					if cameraFocus and not holdSprite then
						for i = 1, #map.layers, 1 do
							cameraFocus.cameraOffsetX[i] = cameraFocus.cameraOffsetX[i] + finalVelX[refLayer]
							cameraFocus.cameraOffsetY[i] = cameraFocus.cameraOffsetY[i] + finalVelY[refLayer]
						end
					end					
					if check == 0 and cameraOnComplete[1] then
						local tempOnComplete = cameraOnComplete[1]
						cameraOnComplete = {}
						local event = { name = "cameraMoveComplete", levelPosX = cameraX, 
							levelPosY = cameraY, 
							locX = cameraLocX, 
							locY = cameraLocY
						}
						tempOnComplete(event)
					end
				else
					for i = 1, #map.layers, 1 do
						if isCameraMoving[i] then
							local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
							local cameraX, cameraY = masterGroup[i]:contentToLocal(tempX, tempY)
							local isoPos = M.isoUntransform2(cameraX, cameraY)
							cameraX = isoPos[1]
							cameraY = isoPos[2]
							local cameraLocX = math.ceil(cameraX / map.tilewidth)
							local cameraLocY = math.ceil(cameraY / map.tileheight)							
							local velX = deltaX[i][1]
							local velY = deltaY[i][1]
							local tempVelX = deltaX[i][1]
							local tempVelY = deltaY[i][1]							
							if parallaxToggle[i] or parallaxToggle[i] == nil then
								finalVelX[i] = tempVelX * map.layers[i].parallaxX / map.layers[i].properties.scaleX
								finalVelY[i] = tempVelY * map.layers[i].parallaxY / map.layers[i].properties.scaleY
							else
								finalVelX[i] = tempVelX
								finalVelY[i] = tempVelY
							end
							if cameraFocus and not holdSprite then
								cameraFocus.cameraOffsetX[i] = cameraFocus.cameraOffsetX[i] + finalVelX[i]
								cameraFocus.cameraOffsetY[i] = cameraFocus.cameraOffsetY[i] + finalVelY[i]
							end						
							table.remove(deltaX[i], 1)
							table.remove(deltaY[i], 1)
							if not deltaX[i][1] then
								isCameraMoving[i] = false
								parallaxToggle[i] = true
								--holdSprite = nil
								if cameraOnComplete[i] then
									local tempOnComplete = cameraOnComplete[i]
									cameraOnComplete[i] = nil
									local event = { name = "cameraLayerMoveComplete", layer = i, 
										levelPosX = cameraX, 
										levelPosY = cameraY, 
										locX = cameraLocX, 
										locY = cameraLocY
									}
									tempOnComplete(event)
								end
							end
						end
					end
				end
				
				--FOLLOW SPRITE
				local followingSprite = false
				if cameraFocus and not holdSprite then
					for i = 1, #map.layers, 1 do
						local tempX, tempY, cameraX, cameraY, velX, velY
						if map.layers[i].toggleParallax == true or map.layers[i].parallaxX ~= 1 or map.layers[i].parallaxY ~= 1 then
							tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
							cameraX, cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)
							velX = finalVelX[refLayer] or 0
							velY = finalVelY[refLayer] or 0
						else
							tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
							cameraX, cameraY = masterGroup[i]:contentToLocal(tempX, tempY)
							velX = finalVelX[i] or 0
							velY = finalVelY[i] or 0
						end
						local isoPos = M.isoUntransform2(cameraX, cameraY)
						cameraX = isoPos[1]
						cameraY = isoPos[2]
						local cameraLocX = math.ceil(cameraX / map.tilewidth)
						local cameraLocY = math.ceil(cameraY / map.tileheight)
						local fX = cameraFocus.levelPosX
						local fY = cameraFocus.levelPosY
						if math.abs((cameraX + velX) - (fX + cameraFocus.cameraOffsetX[i])) > 0.1 then
							finalVelX[i] = ((fX + cameraFocus.cameraOffsetX[i]) - (cameraX)) * map.layers[i].parallaxX / map.layers[i].properties.scaleX
							followingSprite = true
						end
						if math.abs((cameraY + velY) - (fY + cameraFocus.cameraOffsetY[i])) > 0.1 then
							finalVelY[i] = ((fY + cameraFocus.cameraOffsetY[i]) - (cameraY)) * map.layers[i].parallaxY / map.layers[i].properties.scaleY
							followingSprite = true
						end
					end
					--[[
					local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
					local cameraX, cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)
					local isoPos = M.isoUntransform2(cameraX, cameraY)
					cameraX = isoPos[1]
					cameraY = isoPos[2]
					local cameraLocX = math.ceil(cameraX / map.tilewidth)
					local cameraLocY = math.ceil(cameraY / map.tileheight)
					local fX = cameraFocus.levelPosX
					local fY = cameraFocus.levelPosY
					local velX = finalVelX[refLayer] or 0
					local velY = finalVelY[refLayer] or 0
					if math.abs((cameraX + velX) - (fX + cameraFocus.cameraOffsetX)) > 0.1 then
						for i = 1, #map.layers, 1 do
							finalVelX[i] = ((fX + cameraFocus.cameraOffsetX) - (cameraX)) * map.layers[i].parallaxX / map.layers[i].properties.scaleX
							followingSprite = true
						end
					end
					if math.abs((cameraY + velY) - (fY + cameraFocus.cameraOffsetY)) > 0.1 then
						for i = 1, #map.layers, 1 do
							finalVelY[i] = ((fY + cameraFocus.cameraOffsetY) - (cameraY)) * map.layers[i].parallaxY / map.layers[i].properties.scaleY
							followingSprite = true
						end
					end
					]]--
				end
				
				--Clear constraint variable: override
				local checkHoldSprite = 0
				for i = 1, #map.layers, 1 do
					if override[i] and (not deltaX[i] or not deltaX[i][1]) then
						override[i] = false
					end
					if not deltaX[i] or not deltaX[i][1] then
						checkHoldSprite = checkHoldSprite + 1
					end
				end
				if checkHoldSprite == #map.layers and holdSprite then
					holdSprite = false
				end
				
				--APPLY CONSTRAINTS CONTINUOUSLY
				local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
				local cameraX, cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)
				local isoPos = M.isoUntransform2(cameraX, cameraY)
				cameraX = isoPos[1]
				cameraY = isoPos[2]
				local cameraLocX = math.ceil(cameraX / map.tilewidth)
				local cameraLocY = math.ceil(cameraY / map.tileheight)
			
				--calculate constraints
				local angle = masterGroup.rotation + masterGroup[refLayer].rotation
				while angle >= 360 do
					angle = angle - 360
				end
				while angle < 0 do
					angle = angle + 360
				end				
				local topLeftT, topRightT, bottomRightT, bottomLeftT
				topLeftT = {masterGroup.parent:localToContent(screenLeft, screenTop)}
				topRightT = {masterGroup.parent:localToContent(screenRight, screenTop)}
				bottomRightT = {masterGroup.parent:localToContent(screenRight, screenBottom)}
				bottomLeftT = {masterGroup.parent:localToContent(screenLeft, screenBottom)}				
				local topLeft, topRight, bottomRight, bottomLeft
				if angle >= 0 and angle < 90 then
					topLeft = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
					topRight = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
					bottomRight = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
					bottomLeft = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
				elseif angle >= 90 and angle < 180 then
					topLeft = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
					topRight = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
					bottomRight = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
					bottomLeft = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
				elseif angle >= 180 and angle < 270 then
					topLeft = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
					topRight = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
					bottomRight = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
					bottomLeft = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
				elseif angle >= 270 and angle < 360 then
					topLeft = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
					topRight = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
					bottomRight = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
					bottomLeft = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
				end
				for i = 1, #map.layers, 1 do
					if (not followingSprite or masterGroup[i].vars.constrainLayer) and not masterGroup[i].vars.alignment then
						local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
						cameraX, cameraY = masterGroup[i]:contentToLocal(tempX, tempY)
						local isoPos = M.isoUntransform2(cameraX, cameraY)
						cameraX = isoPos[1]
						cameraY = isoPos[2]
						cameraLocX = math.ceil(cameraX / map.tilewidth)
						cameraLocY = math.ceil(cameraY / map.tileheight)
			
						--calculate constraints
						angle = masterGroup.rotation + masterGroup[i].rotation
						while angle >= 360 do
							angle = angle - 360
						end
						while angle < 0 do
							angle = angle + 360
						end						
						if angle >= 0 and angle < 90 then
							topLeft = {masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
							topRight = {masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
							bottomRight = {masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							bottomLeft = {masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
						elseif angle >= 90 and angle < 180 then
							topLeft = {masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
							topRight = {masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							bottomRight = {masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							bottomLeft = {masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
						elseif angle >= 180 and angle < 270 then
							topLeft = {masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							topRight = {masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							bottomRight = {masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
							bottomLeft = {masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
						elseif angle >= 270 and angle < 360 then
							topLeft = {masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							topRight = {masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
							bottomRight = {masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
							bottomLeft = {masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
						end
					end					
					local topLeftT, topRightT, bottomRightT, bottomLeftT
					topLeftT = M.isoUntransform2(topLeft[1], topLeft[2])
					topRightT = M.isoUntransform2(topRight[1], topRight[2])
					bottomRightT = M.isoUntransform2(bottomRight[1], bottomRight[2])
					bottomLeftT = M.isoUntransform2(bottomLeft[1], bottomLeft[2])					
					local left, top, right, bottom
					left = topLeftT[1] - (map.tilewidth / 2)
					top = topRightT[2] - (map.tileheight / 2)
					right = bottomRightT[1] - (map.tilewidth / 2)
					bottom = bottomLeftT[2] - (map.tileheight / 2)					
					local leftConstraint, topConstraint, rightConstraint, bottomConstraint
					if constrainLeft[i] then
						leftConstraint = constrainLeft[i] + (cameraX - left)
					end
					if constrainTop[i] then
						topConstraint = constrainTop[i] + (cameraY - top)
					end
					if constrainRight[i] then
						rightConstraint = constrainRight[i] - (right - cameraX)
					end
					if constrainBottom[i] then
						bottomConstraint = constrainBottom[i] - (bottom - cameraY)
					end						
					if (leftConstraint and rightConstraint) and (leftConstraint > rightConstraint) then
						local temp = (leftConstraint + rightConstraint) / 2
						leftConstraint = temp
						rightConstraint = temp
					end
					if (topConstraint and bottomConstraint) and (topConstraint > bottomConstraint) then
						local temp = (topConstraint + bottomConstraint) / 2
						topConstraint = temp
						bottomConstraint = temp
					end				
					if not masterGroup[i].vars.alignment then
						local velX = finalVelX[i] or 0
						local velY = finalVelY[i] or 0
						local tempVelX = velX
						local tempVelY = velY					
						if not override[i] then
							local tVelX, tVelY = tempVelX, tempVelY
							if leftConstraint then
								if cameraX + velX / map.layers[i].parallaxX < leftConstraint then
									tVelX = (leftConstraint - cameraX) / map.layers[i].parallaxX
								end
							end
							if rightConstraint then
								if cameraX + velX / map.layers[i].parallaxX > rightConstraint then
									tVelX = (rightConstraint - cameraX) / map.layers[i].parallaxX
								end
							end
							if topConstraint then
								if cameraY + velY / map.layers[i].parallaxY < topConstraint then
									tVelY = (topConstraint - cameraY) / map.layers[i].parallaxY
								end
							end
							if bottomConstraint then
								if cameraY + velY / map.layers[i].parallaxY > bottomConstraint then
									tVelY = (bottomConstraint - cameraY) / map.layers[i].parallaxY
								end
							end
							tempVelX = tVelX
							tempVelY = tVelY
						end					
						local velX = tempVelX
						local velY = tempVelY
						nXx = math.cos(R45) * velX * 1
						nXy = math.sin(R45) * velX / map.isoRatio
						nYx = math.sin(R45) * velY * -1
						nYy = math.cos(R45) * velY / map.isoRatio
						local tempVelX2 = (nXx + nYx)
						local tempVelY2 = (nXy + nYy)
						masterGroup[i]:translate(tempVelX2 * -1 * map.layers[i].properties.scaleX, tempVelY2 * -1 * map.layers[i].properties.scaleY)
					else
						if not leftConstraint then
							leftConstraint = (0 - (map.locOffsetX * map.tilewidth)) + (cameraX - left)
						end
						if not topConstraint then
							topConstraint = (0 - (map.locOffsetY * map.tileheight)) + (cameraY - top)
						end
						if not rightConstraint then
							rightConstraint = ((map.width - map.locOffsetX) * map.tilewidth) - (right - cameraX)
						end
						if not bottomConstraint then
							bottomConstraint = ((map.height - map.locOffsetY) * map.tileheight) - (bottom - cameraY)	
						end			
						if (leftConstraint and rightConstraint) and (leftConstraint > rightConstraint) then
							local temp = (leftConstraint + rightConstraint) / 2
							leftConstraint = temp
							rightConstraint = temp
						end
						if (topConstraint and bottomConstraint) and (topConstraint > bottomConstraint) then
							local temp = (topConstraint + bottomConstraint) / 2
							topConstraint = temp
							bottomConstraint = temp
						end	
						local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
						local cameraX, cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)
						local isoPos = M.isoUntransform2(cameraX, cameraY)
						cameraX = isoPos[1]
						cameraY = isoPos[2]
						local cameraLocX = math.ceil(cameraX / map.tilewidth)
						local cameraLocY = math.ceil(cameraY / map.tileheight)
						local xA = masterGroup[i].vars.alignment[1] or "center"
						local yA = masterGroup[i].vars.alignment[2] or "center"						
						local levelPosX, levelPosY
						if xA == "center" then
							local adjustment1 = (((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5)) * map.layers[i].properties.scaleX) - ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))
							local adjustment2 = (cameraX - ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))) - ((cameraX - ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))) * map.layers[i].parallaxX)
							levelPosX = ((cameraX + adjustment1) - adjustment2)
						elseif xA == "left" then
							local adjustment = (cameraX - leftConstraint) - ((cameraX - leftConstraint) * map.layers[i].parallaxX)
							levelPosX = (cameraX - adjustment)
						elseif xA == "right" then
							local adjustment1 = (((map.width - map.locOffsetX) * map.tilewidth) * map.layers[i].properties.scaleX) - ((map.width - map.locOffsetX) * map.tilewidth)
							local adjustment2 = (cameraX - rightConstraint) - ((cameraX - rightConstraint) * map.layers[i].parallaxX)
							levelPosX = ((cameraX + adjustment1) - adjustment2)
						end						
						if yA == "center" then
							local adjustment1 = (((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5)) * map.layers[i].properties.scaleY) - ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))
							local adjustment2 = (cameraY - ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))) - ((cameraY - ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))) * map.layers[i].parallaxY)
							levelPosY = ((cameraY + adjustment1) - adjustment2)
						elseif yA == "top" then
							local adjustment = (cameraY - topConstraint) - ((cameraY - topConstraint) * map.layers[i].parallaxY)
							levelPosY = (cameraY - adjustment)
						elseif yA == "bottom" then
							local adjustment1 = (((map.height - map.locOffsetY) * map.tileheight) * map.layers[i].properties.scaleY) - ((map.height - map.locOffsetY) * map.tileheight)
							local adjustment2 = (cameraY - bottomConstraint) - ((cameraY - bottomConstraint) * map.layers[i].parallaxY)
							levelPosY = ((cameraY + adjustment1) - adjustment2)
						end							
						local deltaX = levelPosX + ((map.tilewidth / 2 * map.layers[i].properties.scaleX) - (map.tilewidth / 2)) - cameraX * map.layers[i].properties.scaleX
						local deltaY = levelPosY + ((map.tileheight / 2 * map.layers[i].properties.scaleY) - (map.tileheight / 2)) - cameraY * map.layers[i].properties.scaleY	
						local isoVector = M.isoVector(deltaX, deltaY)						
						masterGroup[i].x = (masterGroup[refLayer].x * map.layers[i].properties.scaleX) - isoVector[1]
						masterGroup[i].y = (masterGroup[refLayer].y * map.layers[i].properties.scaleY) - isoVector[2]		
					end
				end	
			else
				if refMove then
					local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
					local cameraX, cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)
					local cameraLocX = math.ceil(cameraX / map.tilewidth)
					local cameraLocY = math.ceil(cameraY / map.tileheight)					
					local velX = deltaX[refLayer][1]
					local velY = deltaY[refLayer][1]
					local tempVelX = deltaX[refLayer][1]
					local tempVelY = deltaY[refLayer][1]					
					local check = #map.layers
					for i = 1, #map.layers, 1 do
						if isCameraMoving[i] then
							if parallaxToggle[i] then
								finalVelX[i] = tempVelX * map.layers[i].parallaxX
								finalVelY[i] = tempVelY * map.layers[i].parallaxY
								cameraVelX[i] = tempVelX * map.layers[i].parallaxX
								cameraVelY[i] = tempVelY * map.layers[i].parallaxY
							else
								finalVelX[i] = tempVelX
								finalVelY[i] = tempVelY
								cameraVelX[i] = tempVelX
								cameraVelY[i] = tempVelY
							end
						end						
						table.remove(deltaX[i], 1)
						table.remove(deltaY[i], 1)
						if not deltaX[i][1] then
							check = check - 1
							isCameraMoving[i] = false
							parallaxToggle[i] = true
							--refMove = false
							--holdSprite = nil
						end
					end					
					if cameraFocus and not holdSprite then
						for i = 1, #map.layers, 1 do
							cameraFocus.cameraOffsetX[i] = cameraFocus.cameraOffsetX[i] + finalVelX[refLayer]
							cameraFocus.cameraOffsetY[i] = cameraFocus.cameraOffsetY[i] + finalVelY[refLayer]
						end
					end						
					if check == 0 and cameraOnComplete[1] then
						local tempOnComplete = cameraOnComplete[1]
						cameraOnComplete = {}
						local event = { name = "cameraMoveComplete", levelPosX = cameraX, 
							levelPosY = cameraY, 
							locX = cameraLocX, 
							locY = cameraLocY
						}
						tempOnComplete(event)
					end
				else					
					for i = 1, #map.layers, 1 do
						if isCameraMoving[i] then
							local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
							local cameraX, cameraY = masterGroup[i]:contentToLocal(tempX, tempY)
							local cameraLocX = math.ceil(cameraX / map.tilewidth)
							local cameraLocY = math.ceil(cameraY / map.tileheight)						
							local velX = deltaX[i][1]
							local velY = deltaY[i][1]
							local tempVelX = deltaX[i][1]
							local tempVelY = deltaY[i][1]
							if parallaxToggle[i] or parallaxToggle[i] == nil then
								finalVelX[i] = tempVelX * map.layers[i].parallaxX
								finalVelY[i] = tempVelY * map.layers[i].parallaxY
							else
								finalVelX[i] = tempVelX
								finalVelY[i] = tempVelY
							end							
							if cameraFocus and not holdSprite then
								cameraFocus.cameraOffsetX[i] = cameraFocus.cameraOffsetX[i] + finalVelX[i]
								cameraFocus.cameraOffsetY[i] = cameraFocus.cameraOffsetY[i] + finalVelY[i]
							end						
							table.remove(deltaX[i], 1)
							table.remove(deltaY[i], 1)
							if not deltaX[i][1] then
								isCameraMoving[i] = false
								parallaxToggle[i] = true
								--holdSprite = nil
								if cameraOnComplete[i] then
									local tempOnComplete = cameraOnComplete[i]
									cameraOnComplete[i] = nil
									local event = { name = "cameraLayerMoveComplete", layer = i, 
										levelPosX = cameraX, 
										levelPosY = cameraY, 
										locX = cameraLocX, 
										locY = cameraLocY
									}
									tempOnComplete(event)
								end
							end
						end
					end
				end
				
				--FOLLOW SPRITE
				local followingSprite = false
				if cameraFocus and not holdSprite then
					for i = 1, #map.layers, 1 do
						local tempX, tempY, cameraX, cameraY, velX, velY
						if map.layers[i].toggleParallax == true or map.layers[i].parallaxX ~= 1 or map.layers[i].parallaxY ~= 1 then
							tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
							cameraX, cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)
							velX = finalVelX[refLayer] or 0
							velY = finalVelY[refLayer] or 0
						else
							tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
							cameraX, cameraY = masterGroup[i]:contentToLocal(tempX, tempY)
							velX = finalVelX[i] or 0
							velY = finalVelY[i] or 0
						end
						local cameraLocX = math.ceil(cameraX / map.tilewidth)
						local cameraLocY = math.ceil(cameraY / map.tileheight)
						local fX = cameraFocus.x
						local fY = cameraFocus.y
						if cameraX + velX ~= fX + cameraFocus.cameraOffsetX[i] then
							if not override[i] then
								finalVelX[i] = ((fX + cameraFocus.cameraOffsetX[i]) - (cameraX)) * map.layers[i].parallaxX
								followingSprite = true
							end
						end
						if cameraY + velY ~= fY + cameraFocus.cameraOffsetY[i] then
							if not override[i] then
								finalVelY[i] = ((fY + cameraFocus.cameraOffsetY[i]) - (cameraY)) * map.layers[i].parallaxY
								followingSprite = true
							end
						end
					end
				end
				
				--Clear constraint variables: override, holdSprite
				local checkHoldSprite = 0
				for i = 1, #map.layers, 1 do
					if override[i] and (not deltaX[i] or not deltaX[i][1]) then
						override[i] = false
					end
					if not deltaX[i] or not deltaX[i][1] then
						checkHoldSprite = checkHoldSprite + 1
					end
				end
				if checkHoldSprite == #map.layers and holdSprite then
					holdSprite = false
				end
				
				--APPLY CONSTRAINTS CONTINUOUSLY
				local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
				local cameraX, cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)
				local cameraLocX = math.ceil(cameraX / map.tilewidth)
				local cameraLocY = math.ceil(cameraY / map.tileheight)
				
				--calculate constraints
				local angle = masterGroup.rotation + masterGroup[refLayer].rotation
				while angle >= 360 do
					angle = angle - 360
				end
				while angle < 0 do
					angle = angle + 360
				end				
				local topLeftT, topRightT, bottomRightT, bottomLeftT
				topLeftT = {masterGroup.parent:localToContent(screenLeft, screenTop)}
				topRightT = {masterGroup.parent:localToContent(screenRight, screenTop)}
				bottomRightT = {masterGroup.parent:localToContent(screenRight, screenBottom)}
				bottomLeftT = {masterGroup.parent:localToContent(screenLeft, screenBottom)}				
				local topLeft, topRight, bottomRight, bottomLeft
				if angle >= 0 and angle < 90 then
					topLeft = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
					topRight = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
					bottomRight = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
					bottomLeft = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
				elseif angle >= 90 and angle < 180 then
					topLeft = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
					topRight = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
					bottomRight = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
					bottomLeft = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
				elseif angle >= 180 and angle < 270 then
					topLeft = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
					topRight = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
					bottomRight = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
					bottomLeft = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
				elseif angle >= 270 and angle < 360 then
					topLeft = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
					topRight = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
					bottomRight = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
					bottomLeft = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
				end
				--[[
				print(" ")
				for i = 1, #map.layers, 1 do
					if masterGroup[i].vars.alignment then
						print("a", i)
						local left, top, right, bottom
						if topLeft[1] < bottomLeft[1] then
							left = topLeft[1]
						else
							left = bottomLeft[1]
						end
						if topLeft[2] < topRight[2] then
							top = topLeft[2]
						else
							top = topRight[2]
						end
						if topRight[1] > bottomRight[1] then
							right = topRight[1]
						else
							right = bottomRight[1]
						end
						if bottomRight[2] > bottomLeft[2] then
							bottom = bottomRight[2]
						else
							bottom = bottomLeft[2]
						end	
						local leftConstraint, topConstraint, rightConstraint, bottomConstraint
						if constrainLeft[i] then
							leftConstraint = constrainLeft[i] + (cameraX - left)
						end
						if constrainTop[i] then
							topConstraint = constrainTop[i] + (cameraY - top)
						end
						if constrainRight[i] then
							rightConstraint = constrainRight[i] - (right - cameraX)
						end
						if constrainBottom[i] then
							bottomConstraint = constrainBottom[i] - (bottom - cameraY)
						end						
						if (leftConstraint and rightConstraint) and (leftConstraint > rightConstraint) then
							local temp = (leftConstraint + rightConstraint) / 2
							leftConstraint = temp
							rightConstraint = temp
						end
						if (topConstraint and bottomConstraint) and (topConstraint > bottomConstraint) then
							local temp = (topConstraint + bottomConstraint) / 2
							topConstraint = temp
							bottomConstraint = temp
						end		
						if not leftConstraint then
							leftConstraint = (0 - (map.locOffsetX * map.tilewidth)) + (cameraX - left)
						end
						if not topConstraint then
							topConstraint = (0 - (map.locOffsetY * map.tileheight)) + (cameraY - top)
						end
						if not rightConstraint then
							rightConstraint = (map.width * map.tilewidth) - (right - cameraX)
						end
						if not bottomConstraint then
							bottomConstraint = (map.height * map.tileheight) - (bottom - cameraY)	
						end			
						if (leftConstraint and rightConstraint) and (leftConstraint > rightConstraint) then
							local temp = (leftConstraint + rightConstraint) / 2
							leftConstraint = temp
							rightConstraint = temp
						end
						if (topConstraint and bottomConstraint) and (topConstraint > bottomConstraint) then
							local temp = (topConstraint + bottomConstraint) / 2
							topConstraint = temp
							bottomConstraint = temp
						end	
						local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
						local cameraX, cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)
						local cameraLocX = math.ceil(cameraX / map.tilewidth)
						local cameraLocY = math.ceil(cameraY / map.tileheight)
						local xA = masterGroup[i].vars.alignment[1]
						local yA = masterGroup[i].vars.alignment[2]						
						if xA == "center" then
							local adjustment1 = (((map.layers[i].width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5)) * map.layers[i].properties.scaleX) - ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))
							local adjustment2 = (cameraX - ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))) - ((cameraX - ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))) * map.layers[i].parallaxX)
							masterGroup[i].x = ((cameraX + adjustment1) - adjustment2) * -1
						elseif xA == "left" then
							local adjustment = (cameraX - leftConstraint) - ((cameraX - leftConstraint) * map.layers[i].parallaxX)
							masterGroup[i].x = (cameraX - adjustment) * -1
						elseif xA == "right" then
							local adjustment1 = (((map.layers[i].width - map.locOffsetX) * map.tilewidth) * map.layers[i].properties.scaleX) - ((map.width - map.locOffsetX) * map.tilewidth)
							local adjustment2 = (cameraX - rightConstraint) - ((cameraX - rightConstraint) * map.layers[i].parallaxX)
							masterGroup[i].x = ((cameraX + adjustment1) - adjustment2) * -1
						end						
						if yA == "center" then
							local adjustment1 = (((map.layers[i].height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5)) * map.layers[i].properties.scaleY) - ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))
							local adjustment2 = (cameraY - ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))) - ((cameraY - ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))) * map.layers[i].parallaxY)
							masterGroup[i].y = ((cameraY + adjustment1) - adjustment2) * -1
						elseif yA == "top" then
							local adjustment = (cameraY - topConstraint) - ((cameraY - topConstraint) * map.layers[i].parallaxY)
							masterGroup[i].y = (cameraY - adjustment) * -1
						elseif yA == "bottom" then
							local adjustment1 = (((map.layers[i].height - map.locOffsetY) * map.tileheight) * map.layers[i].properties.scaleY) - ((map.height - map.locOffsetY) * map.tileheight)
							local adjustment2 = (cameraY - bottomConstraint) - ((cameraY - bottomConstraint) * map.layers[i].parallaxY)
							masterGroup[i].y = ((cameraY + adjustment1) - adjustment2) * -1
						end		
					else
						print("b", i)
						if not refMove and ((not followingSprite or masterGroup[i].vars.constrainLayer) and not masterGroup[i].vars.alignment) then
							local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
							cameraX, cameraY = masterGroup[i]:contentToLocal(tempX, tempY)
							cameraLocX = math.ceil(cameraX / map.tilewidth)
							cameraLocY = math.ceil(cameraY / map.tileheight)
						
							--calculate constraints
							angle = masterGroup.rotation + masterGroup[i].rotation
							while angle >= 360 do
								angle = angle - 360
							end
							while angle < 0 do
								angle = angle + 360
							end						
							if angle >= 0 and angle < 90 then
								topLeft = {masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
								topRight = {masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
								bottomRight = {masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
								bottomLeft = {masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							elseif angle >= 90 and angle < 180 then
								topLeft = {masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
								topRight = {masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
								bottomRight = {masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
								bottomLeft = {masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
							elseif angle >= 180 and angle < 270 then
								topLeft = {masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
								topRight = {masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
								bottomRight = {masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
								bottomLeft = {masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
							elseif angle >= 270 and angle < 360 then
								topLeft = {masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
								topRight = {masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
								bottomRight = {masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
								bottomLeft = {masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							end
						end
						local left, top, right, bottom
						if topLeft[1] < bottomLeft[1] then
							left = topLeft[1]
						else
							left = bottomLeft[1]
						end
						if topLeft[2] < topRight[2] then
							top = topLeft[2]
						else
							top = topRight[2]
						end
						if topRight[1] > bottomRight[1] then
							right = topRight[1]
						else
							right = bottomRight[1]
						end
						if bottomRight[2] > bottomLeft[2] then
							bottom = bottomRight[2]
						else
							bottom = bottomLeft[2]
						end	
						local leftConstraint, topConstraint, rightConstraint, bottomConstraint
						if constrainLeft[i] then
							leftConstraint = constrainLeft[i] + (cameraX - left)
						end
						if constrainTop[i] then
							topConstraint = constrainTop[i] + (cameraY - top)
						end
						if constrainRight[i] then
							rightConstraint = constrainRight[i] - (right - cameraX)
						end
						if constrainBottom[i] then
							bottomConstraint = constrainBottom[i] - (bottom - cameraY)
						end						
						if (leftConstraint and rightConstraint) and (leftConstraint > rightConstraint) then
							local temp = (leftConstraint + rightConstraint) / 2
							leftConstraint = temp
							rightConstraint = temp
						end
						if (topConstraint and bottomConstraint) and (topConstraint > bottomConstraint) then
							local temp = (topConstraint + bottomConstraint) / 2
							topConstraint = temp
							bottomConstraint = temp
						end	
						local velX = finalVelX[i] or 0
						local velY = finalVelY[i] or 0
						local tempVelX = velX
						local tempVelY = velY					
						if not override[i] then
							if leftConstraint then
								if cameraX + velX / map.layers[i].parallaxX < leftConstraint then
									tempVelX = (leftConstraint - cameraX) * map.layers[i].parallaxX
								end
								if cameraFocus and cameraFocus.levelPosX + cameraFocus.cameraOffsetX[i] < leftConstraint then
									cameraFocus.cameraOffsetX[i] = leftConstraint - cameraFocus.levelPosX
									if cameraFocus.levelPosX + cameraFocus.cameraOffsetX[i] > cameraFocus.levelPosX and (cameraVelX[i] or 0) <= 0 then
										cameraFocus.cameraOffsetX[i] = 0
									end
								end
							end
							if rightConstraint then
								if cameraX + velX / map.layers[i].parallaxX > rightConstraint then
									tempVelX = (rightConstraint - cameraX) * map.layers[i].parallaxX
								end
								if cameraFocus and cameraFocus.levelPosX + cameraFocus.cameraOffsetX[i] > rightConstraint then
									cameraFocus.cameraOffsetX[i] = rightConstraint - cameraFocus.levelPosX
									if cameraFocus.levelPosX + cameraFocus.cameraOffsetX[i] < cameraFocus.levelPosX and (cameraVelX[i] or 0) >= 0 then
										cameraFocus.cameraOffsetX[i] = 0
									end
								end
							end
							if topConstraint then
								if cameraY + velY / map.layers[i].parallaxY < topConstraint then
									tempVelY = (topConstraint - cameraY) * map.layers[i].parallaxY
								end
								if cameraFocus and cameraFocus.levelPosY + cameraFocus.cameraOffsetY[i] < topConstraint then
									cameraFocus.cameraOffsetY[i] = topConstraint - cameraFocus.levelPosY
									if cameraFocus.levelPosY + cameraFocus.cameraOffsetY[i] > cameraFocus.levelPosY and (cameraVelY[i] or 0) <= 0 then
										cameraFocus.cameraOffsetY[i] = 0
									end
								end
							end
							if bottomConstraint then
								if cameraY + velY / map.layers[i].parallaxY > bottomConstraint then
									tempVelY = (bottomConstraint - cameraY) * map.layers[i].parallaxY
								end
								if cameraFocus and cameraFocus.levelPosY + cameraFocus.cameraOffsetY[i] > bottomConstraint then
									cameraFocus.cameraOffsetY[i] = bottomConstraint - cameraFocus.levelPosY
									if cameraFocus.levelPosY + cameraFocus.cameraOffsetY[i] < cameraFocus.levelPosY and (cameraVelY[i] or 0) >= 0 then
										cameraFocus.cameraOffsetY[i] = 0
									end
								end
							end
						end				
						masterGroup[i]:translate(tempVelX * -1 * map.layers[i].properties.scaleX, tempVelY * -1 * map.layers[i].properties.scaleY)
					end
				end
				]]--				
				for i = 1, #map.layers, 1 do
					if not refMove and ((not followingSprite or masterGroup[i].vars.constrainLayer) and not masterGroup[i].vars.alignment) then
						local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
						cameraX, cameraY = masterGroup[i]:contentToLocal(tempX, tempY)
						cameraLocX = math.ceil(cameraX / map.tilewidth)
						cameraLocY = math.ceil(cameraY / map.tileheight)
						
						--calculate constraints
						angle = masterGroup.rotation + masterGroup[i].rotation
						while angle >= 360 do
							angle = angle - 360
						end
						while angle < 0 do
							angle = angle + 360
						end						
						if angle >= 0 and angle < 90 then
							topLeft = {masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
							topRight = {masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
							bottomRight = {masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							bottomLeft = {masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
						elseif angle >= 90 and angle < 180 then
							topLeft = {masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
							topRight = {masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							bottomRight = {masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							bottomLeft = {masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
						elseif angle >= 180 and angle < 270 then
							topLeft = {masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							topRight = {masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							bottomRight = {masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
							bottomLeft = {masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
						elseif angle >= 270 and angle < 360 then
							topLeft = {masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							topRight = {masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
							bottomRight = {masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
							bottomLeft = {masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
						end
					end
					local left, top, right, bottom
					if topLeft[1] < bottomLeft[1] then
						left = topLeft[1]
					else
						left = bottomLeft[1]
					end
					if topLeft[2] < topRight[2] then
						top = topLeft[2]
					else
						top = topRight[2]
					end
					if topRight[1] > bottomRight[1] then
						right = topRight[1]
					else
						right = bottomRight[1]
					end
					if bottomRight[2] > bottomLeft[2] then
						bottom = bottomRight[2]
					else
						bottom = bottomLeft[2]
					end	
					local leftConstraint, topConstraint, rightConstraint, bottomConstraint
					if constrainLeft[i] then
						leftConstraint = constrainLeft[i] + (cameraX - left)
					end
					if constrainTop[i] then
						topConstraint = constrainTop[i] + (cameraY - top)
					end
					if constrainRight[i] then
						rightConstraint = constrainRight[i] - (right - cameraX)
					end
					if constrainBottom[i] then
						bottomConstraint = constrainBottom[i] - (bottom - cameraY)
					end						
					if (leftConstraint and rightConstraint) and (leftConstraint > rightConstraint) then
						local temp = (leftConstraint + rightConstraint) / 2
						leftConstraint = temp
						rightConstraint = temp
					end
					if (topConstraint and bottomConstraint) and (topConstraint > bottomConstraint) then
						local temp = (topConstraint + bottomConstraint) / 2
						topConstraint = temp
						bottomConstraint = temp
					end					
					--print(masterGroup[i].vars.alignment)
					if not masterGroup[i].vars.alignment then
						local velX = finalVelX[i] or 0
						local velY = finalVelY[i] or 0
						local tempVelX = velX
						local tempVelY = velY					
						if not override[i] then
							if leftConstraint then
								if cameraX + velX / map.layers[i].parallaxX < leftConstraint then
									tempVelX = (leftConstraint - cameraX) * map.layers[i].parallaxX
								end
								if cameraFocus and cameraFocus.levelPosX + cameraFocus.cameraOffsetX[i] < leftConstraint then
									cameraFocus.cameraOffsetX[i] = leftConstraint - cameraFocus.levelPosX
									if cameraFocus.levelPosX + cameraFocus.cameraOffsetX[i] > cameraFocus.levelPosX and (cameraVelX[i] or 0) <= 0 then
										cameraFocus.cameraOffsetX[i] = 0
									end
								end
							end
							if rightConstraint then
								if cameraX + velX / map.layers[i].parallaxX > rightConstraint then
									tempVelX = (rightConstraint - cameraX) * map.layers[i].parallaxX
								end
								if cameraFocus and cameraFocus.levelPosX + cameraFocus.cameraOffsetX[i] > rightConstraint then
									cameraFocus.cameraOffsetX[i] = rightConstraint - cameraFocus.levelPosX
									if cameraFocus.levelPosX + cameraFocus.cameraOffsetX[i] < cameraFocus.levelPosX and (cameraVelX[i] or 0) >= 0 then
										cameraFocus.cameraOffsetX[i] = 0
									end
								end
							end
							if topConstraint then
								if cameraY + velY / map.layers[i].parallaxY < topConstraint then
									tempVelY = (topConstraint - cameraY) * map.layers[i].parallaxY
								end
								if cameraFocus and cameraFocus.levelPosY + cameraFocus.cameraOffsetY[i] < topConstraint then
									cameraFocus.cameraOffsetY[i] = topConstraint - cameraFocus.levelPosY
									if cameraFocus.levelPosY + cameraFocus.cameraOffsetY[i] > cameraFocus.levelPosY and (cameraVelY[i] or 0) <= 0 then
										cameraFocus.cameraOffsetY[i] = 0
									end
								end
							end
							if bottomConstraint then
								if cameraY + velY / map.layers[i].parallaxY > bottomConstraint then
									tempVelY = (bottomConstraint - cameraY) * map.layers[i].parallaxY
								end
								if cameraFocus and cameraFocus.levelPosY + cameraFocus.cameraOffsetY[i] > bottomConstraint then
									cameraFocus.cameraOffsetY[i] = bottomConstraint - cameraFocus.levelPosY
									if cameraFocus.levelPosY + cameraFocus.cameraOffsetY[i] < cameraFocus.levelPosY and (cameraVelY[i] or 0) >= 0 then
										cameraFocus.cameraOffsetY[i] = 0
									end
								end
							end
						end				
						masterGroup[i]:translate(tempVelX * -1 * map.layers[i].properties.scaleX, tempVelY * -1 * map.layers[i].properties.scaleY)
					else
						if not leftConstraint then
							leftConstraint = (0 - (map.locOffsetX * map.tilewidth)) + (cameraX - left)
						end
						if not topConstraint then
							topConstraint = (0 - (map.locOffsetY * map.tileheight)) + (cameraY - top)
						end
						if not rightConstraint then
							rightConstraint = (map.width * map.tilewidth) - (right - cameraX)
						end
						if not bottomConstraint then
							bottomConstraint = (map.height * map.tileheight) - (bottom - cameraY)	
						end			
						if (leftConstraint and rightConstraint) and (leftConstraint > rightConstraint) then
							local temp = (leftConstraint + rightConstraint) / 2
							leftConstraint = temp
							rightConstraint = temp
						end
						if (topConstraint and bottomConstraint) and (topConstraint > bottomConstraint) then
							local temp = (topConstraint + bottomConstraint) / 2
							topConstraint = temp
							bottomConstraint = temp
						end	
						local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
						local cameraX, cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)
						local cameraLocX = math.ceil(cameraX / map.tilewidth)
						local cameraLocY = math.ceil(cameraY / map.tileheight)
						local xA = masterGroup[i].vars.alignment[1]
						local yA = masterGroup[i].vars.alignment[2]	
						--print(i, xA, yA)					
						if xA == "center" then
							--local adjustment1 = (((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5)) * map.layers[i].properties.scaleX) - ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))
							--local adjustment2 = (cameraX - ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))) - ((cameraX - ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))) * map.layers[i].parallaxX)
							--print(map.layers[i].parallaxX)
							--local adjustment1 = (((map.layers[i].width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5)) * map.layers[i].properties.scaleX) - ((map.layers[i].width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))
							local adjustment1 = (((map.layers[i].width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5)) * map.layers[i].properties.scaleX) - ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))
							local adjustment2 = (cameraX - ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))) - ((cameraX - ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))) * map.layers[i].parallaxX)
							masterGroup[i].x = ((cameraX + adjustment1) - adjustment2) * -1
						elseif xA == "left" then
							local adjustment = (cameraX - leftConstraint) - ((cameraX - leftConstraint) * map.layers[i].parallaxX)
							masterGroup[i].x = (cameraX - adjustment) * -1
						elseif xA == "right" then
							--local adjustment1 = (((map.width - map.locOffsetX) * map.tilewidth) * map.layers[i].properties.scaleX) - ((map.width - map.locOffsetX) * map.tilewidth)
							--local adjustment2 = (cameraX - rightConstraint) - ((cameraX - rightConstraint) * map.layers[i].parallaxX)
							local adjustment1 = (((map.layers[i].width - map.locOffsetX) * map.tilewidth) * map.layers[i].properties.scaleX) - ((map.width - map.locOffsetX) * map.tilewidth)
							local adjustment2 = (cameraX - rightConstraint) - ((cameraX - rightConstraint) * map.layers[i].parallaxX)
							masterGroup[i].x = ((cameraX + adjustment1) - adjustment2) * -1
						end						
						if yA == "center" then
							--local adjustment1 = (((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5)) * map.layers[i].properties.scaleY) - ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))
							--local adjustment2 = (cameraY - ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))) - ((cameraY - ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))) * map.layers[i].parallaxY)
							local adjustment1 = (((map.layers[i].height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5)) * map.layers[i].properties.scaleY) - ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))
							local adjustment2 = (cameraY - ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))) - ((cameraY - ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))) * map.layers[i].parallaxY)
							masterGroup[i].y = ((cameraY + adjustment1) - adjustment2) * -1
						elseif yA == "top" then
							local adjustment = (cameraY - topConstraint) - ((cameraY - topConstraint) * map.layers[i].parallaxY)
							masterGroup[i].y = (cameraY - adjustment) * -1
						elseif yA == "bottom" then
							--local adjustment1 = (((map.height - map.locOffsetY) * map.tileheight) * map.layers[i].properties.scaleY) - ((map.height - map.locOffsetY) * map.tileheight)
							--local adjustment2 = (cameraY - bottomConstraint) - ((cameraY - bottomConstraint) * map.layers[i].parallaxY)
							local adjustment1 = (((map.layers[i].height - map.locOffsetY) * map.tileheight) * map.layers[i].properties.scaleY) - ((map.height - map.locOffsetY) * map.tileheight)
							local adjustment2 = (cameraY - bottomConstraint) - ((cameraY - bottomConstraint) * map.layers[i].parallaxY)
							masterGroup[i].y = ((cameraY + adjustment1) - adjustment2) * -1
						end
					end
				end
				
				if refMove and not deltaX[refLayer][1] then
					refMove = false
				end				
			end
		end
		
		--WRAP CAMERA
		for i = 1, #map.layers, 1 do
			if not isCameraMoving[i] then
				local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
				local cameraX, cameraY = masterGroup[i]:contentToLocal(tempX, tempY)
				local cameraLocX = math.ceil(cameraX / map.tilewidth)
				local cameraLocY = math.ceil(cameraY / map.tileheight)				
				if map.orientation == 1 then
					local isoPos = M.isoUntransform2(cameraX, cameraY)
					cameraX = isoPos[1]
					cameraY = isoPos[2]					
					if layerWrapX[i] then
						if cameraX < 0 then
							local vector = M.isoVector(map.layers[i].width * map.tilewidth, 0)
							masterGroup[i]:translate(vector[1] * -1 * map.layers[i].properties.scaleX, vector[2] * -1 * map.layers[i].properties.scaleY)
						elseif cameraX > map.layers[i].width * map.tilewidth then
							local vector = M.isoVector(map.layers[i].width * map.tilewidth * -1, 0)
							masterGroup[i]:translate(vector[1] * -1 * map.layers[i].properties.scaleX, vector[2] * -1 * map.layers[i].properties.scaleY)
						end
					end
					if layerWrapY[i] then
						if cameraY < 0 then
							local vector = M.isoVector(0, map.layers[i].height * map.tileheight)
							masterGroup[i]:translate(vector[1] * -1 * map.layers[i].properties.scaleX, vector[2] * -1 * map.layers[i].properties.scaleY)
						elseif cameraY > map.layers[i].height * map.tileheight then
							local vector = M.isoVector(0, map.layers[i].height * map.tileheight * -1)
							masterGroup[i]:translate(vector[1] * -1 * map.layers[i].properties.scaleX, vector[2] * -1 * map.layers[i].properties.scaleY)
						end
					end
				else
					if layerWrapX[i] then
						if cameraX < 0 then
							masterGroup[i].x = masterGroup[i].x + map.layers[i].width * map.tilewidth * -1 * map.layers[i].properties.scaleX
						elseif cameraX > map.layers[i].width * map.tilewidth then
							masterGroup[i].x = masterGroup[i].x - map.layers[i].width * map.tilewidth * -1 * map.layers[i].properties.scaleX
						end
					end
					if layerWrapY[i] then
						if cameraY < 0 then
							masterGroup[i].y = masterGroup[i].y + map.layers[i].height * map.tileheight * -1 * map.layers[i].properties.scaleY
						elseif cameraY > map.layers[i].height * map.tileheight then
							masterGroup[i].y = masterGroup[i].y - map.layers[i].height * map.tileheight * -1 * map.layers[i].properties.scaleY
						end
					end
				end
			end
		end
		
		--CULL AND RENDER
		if map.orientation == 1 then
			for layer = 1, #map.layers, 1 do
				local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
				local cameraX, cameraY = masterGroup[layer]:contentToLocal(tempX, tempY)
				local isoPos = M.isoUntransform2(cameraX, cameraY)
				cameraX = isoPos[1]
				cameraY = isoPos[2]
				local cameraLocX = math.ceil(cameraX / map.tilewidth)
				local cameraLocY = math.ceil(cameraY / map.tileheight)				
				M.cameraX, M.cameraY = cameraX, cameraY
				M.cameraLocX = cameraLocX
				M.cameraLocY = cameraLocY
				if not masterGroup[layer].vars.camera then	
					--Render view if view does not exist
					totalRects[layer] = 0
					local angle = masterGroup.rotation + masterGroup[layer].rotation
					while angle >= 360 do
						angle = angle - 360
					end
					while angle < 0 do
						angle = angle + 360
					end					
					local topLeftT, topRightT, bottomRightT, bottomLeftT
					topLeftT = {masterGroup.parent:localToContent(screenLeft - cullingMargin[1], screenTop - cullingMargin[2])}
					topRightT = {masterGroup.parent:localToContent(screenRight + cullingMargin[3], screenTop - cullingMargin[2])}
					bottomRightT = {masterGroup.parent:localToContent(screenRight + cullingMargin[3], screenBottom + cullingMargin[4])}
					bottomLeftT = {masterGroup.parent:localToContent(screenLeft - cullingMargin[1], screenBottom + cullingMargin[4])}					
					local topLeft, topRight, bottomRight, bottomLeft
					if angle >= 0 and angle < 90 then
						topLeft = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
						topRight = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
						bottomRight = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
						bottomLeft = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
					elseif angle >= 90 and angle < 180 then
						topLeft = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
						topRight = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
						bottomRight = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
						bottomLeft = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
					elseif angle >= 180 and angle < 270 then
						topLeft = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
						topRight = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
						bottomRight = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
						bottomLeft = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
					elseif angle >= 270 and angle < 360 then
						topLeft = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
						topRight = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
						bottomRight = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
						bottomLeft = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
					end
					topLeft = M.isoUntransform2(topLeft[1], topLeft[2])
					topRight = M.isoUntransform2(topRight[1], topRight[2])
					bottomRight = M.isoUntransform2(bottomRight[1], bottomRight[2])
					bottomLeft = M.isoUntransform2(bottomLeft[1], bottomLeft[2])					
					local left, top, right, bottom
					left = math.ceil(topLeft[1] / map.tilewidth) - 1
					top = math.ceil(topRight[2] / map.tileheight) - 1
					right = math.ceil(bottomRight[1] / map.tilewidth) + 2
					bottom = math.ceil(bottomLeft[2] / map.tileheight) + 2					
					masterGroup[layer].vars.camera = {left, top, right, bottom}					
					for locX = left, right, 1 do
						for locY = top, bottom, 1 do										
							updateTile2({locX = locX, locY = locY, layer = layer})
							--drawLargeTile(locX, locY, layer)
						end
					end
				else		
					--Cull and Render
					local prevLeft = masterGroup[layer].vars.camera[1]
					local prevTop = masterGroup[layer].vars.camera[2]
					local prevRight = masterGroup[layer].vars.camera[3]
					local prevBottom = masterGroup[layer].vars.camera[4]							
					local angle = masterGroup.rotation + masterGroup[layer].rotation
					while angle >= 360 do
						angle = angle - 360
					end
					while angle < 0 do
						angle = angle + 360
					end					
					local topLeftT, topRightT, bottomRightT, bottomLeftT
					topLeftT = {masterGroup.parent:localToContent(screenLeft - cullingMargin[1], screenTop - cullingMargin[2])}
					topRightT = {masterGroup.parent:localToContent(screenRight + cullingMargin[3], screenTop - cullingMargin[2])}
					bottomRightT = {masterGroup.parent:localToContent(screenRight + cullingMargin[3], screenBottom + cullingMargin[4])}
					bottomLeftT = {masterGroup.parent:localToContent(screenLeft - cullingMargin[1], screenBottom + cullingMargin[4])}					
					local topLeft, topRight, bottomRight, bottomLeft
					if angle >= 0 and angle < 90 then
						topLeft = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
						topRight = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
						bottomRight = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
						bottomLeft = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
					elseif angle >= 90 and angle < 180 then
						topLeft = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
						topRight = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
						bottomRight = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
						bottomLeft = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
					elseif angle >= 180 and angle < 270 then
						topLeft = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
						topRight = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
						bottomRight = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
						bottomLeft = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
					elseif angle >= 270 and angle < 360 then
						topLeft = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
						topRight = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
						bottomRight = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
						bottomLeft = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
					end
					topLeft = M.isoUntransform2(topLeft[1], topLeft[2])
					topRight = M.isoUntransform2(topRight[1], topRight[2])
					bottomRight = M.isoUntransform2(bottomRight[1], bottomRight[2])
					bottomLeft = M.isoUntransform2(bottomLeft[1], bottomLeft[2])					
					local left, top, right, bottom
					left = math.ceil(topLeft[1] / map.tilewidth) - 1
					top = math.ceil(topRight[2] / map.tileheight) - 1
					right = math.ceil(bottomRight[1] / map.tilewidth) + 2
					bottom = math.ceil(bottomLeft[2] / map.tileheight) + 2					
					masterGroup[layer].vars.camera = {left, top, right, bottom}
					if left > prevRight or right < prevLeft or top > prevBottom or bottom < prevTop then
						for locX = prevLeft, prevRight, 1 do
							for locY = prevTop, prevBottom, 1 do										
								updateTile2({locX = locX, locY = locY, layer = layer, tile = -1})
							end
						end
						for locX = left, right, 1 do
							for locY = top, bottom, 1 do										
								updateTile2({locX = locX, locY = locY, layer = layer})
							end
						end
					else
						--left
						if left > prevLeft then		--cull
							local tLeft = left
							for locX = prevLeft, tLeft - 1, 1 do
								for locY = prevTop, prevBottom, 1 do
									updateTile2({locX = locX, locY = locY, layer = layer, tile = -1})
								end
							end
						elseif left < prevLeft then	--render
							local tLeft = prevLeft
							for locX = left, tLeft - 1, 1 do
								for locY = top, bottom, 1 do
									updateTile2({locX = locX, locY = locY, layer = layer})
								end
							end
						end				
						--top
						if top > prevTop then		--cull
							local tTop = top
							for locX = prevLeft, prevRight, 1 do
								for locY = prevTop, tTop - 1, 1 do
									updateTile2({locX = locX, locY = locY, layer = layer, tile = -1})
								end
							end
						elseif top < prevTop then	--render
							local tTop = prevTop
							for locX = left, right, 1 do
								for locY = top, tTop - 1, 1 do
									updateTile2({locX = locX, locY = locY, layer = layer})
								end
							end
						end				
						--right
						if right > prevRight then		--render
							local tRight = prevRight
							for locX = tRight + 1, right, 1 do
								for locY = top, bottom, 1 do
									updateTile2({locX = locX, locY = locY, layer = layer})
								end
							end
						elseif right < prevRight then	--cull
							local tRight = right
							for locX = tRight + 1, prevRight, 1 do
								for locY = prevTop, prevBottom, 1 do
									updateTile2({locX = locX, locY = locY, layer = layer, tile = -1})
								end
							end
						end						
						--bottom
						if bottom > prevBottom then		--render
							local tBottom = prevBottom
							for locX = left, right, 1 do
								for locY = tBottom + 1, bottom, 1 do
									updateTile2({locX = locX, locY = locY, layer = layer})
								end
							end
						elseif bottom < prevBottom then	--cull
							local tBottom = bottom
							for locX = prevLeft, prevRight, 1 do
								for locY = tBottom + 1, prevBottom, 1 do
									updateTile2({locX = locX, locY = locY, layer = layer, tile = -1})
								end
							end
						end
					end				
				end
			end
		else
			for layer = 1, #map.layers, 1 do
				local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
				local cameraX, cameraY = masterGroup[layer]:contentToLocal(tempX, tempY)
				local cameraLocX = math.ceil(cameraX / map.tilewidth)
				local cameraLocY = math.ceil(cameraY / map.tileheight)	
				
				--print(layer, cameraX)
							
				M.cameraX, M.cameraY = cameraX, cameraY
				M.cameraLocX = cameraLocX
				M.cameraLocY = cameraLocY
				if not masterGroup[layer].vars.camera then	
					--Render view if view does not exist
					totalRects[layer] = 0
					local angle = masterGroup.rotation + masterGroup[layer].rotation
					while angle >= 360 do
						angle = angle - 360
					end
					while angle < 0 do
						angle = angle + 360
					end					
					local topLeftT, topRightT, bottomRightT, bottomLeftT
					topLeftT = {masterGroup.parent:localToContent(screenLeft - cullingMargin[1], screenTop - cullingMargin[2])}
					topRightT = {masterGroup.parent:localToContent(screenRight + cullingMargin[3], screenTop - cullingMargin[2])}
					bottomRightT = {masterGroup.parent:localToContent(screenRight + cullingMargin[3], screenBottom + cullingMargin[4])}
					bottomLeftT = {masterGroup.parent:localToContent(screenLeft - cullingMargin[1], screenBottom + cullingMargin[4])}				
					local topLeft, topRight, bottomRight, bottomLeft
					if angle >= 0 and angle < 90 then
						topLeft = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
						topRight = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
						bottomRight = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
						bottomLeft = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
					elseif angle >= 90 and angle < 180 then
						topLeft = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
						topRight = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
						bottomRight = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
						bottomLeft = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
					elseif angle >= 180 and angle < 270 then
						topLeft = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
						topRight = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
						bottomRight = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
						bottomLeft = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
					elseif angle >= 270 and angle < 360 then
						topLeft = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
						topRight = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
						bottomRight = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
						bottomLeft = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
					end
					local left, top, right, bottom
					if topLeft[1] < bottomLeft[1] then
						left = math.ceil(topLeft[1] / map.tilewidth)
					else
						left = math.ceil(bottomLeft[1] / map.tilewidth)
					end
					if topLeft[2] < topRight[2] then
						top = math.ceil(topLeft[2] / map.tileheight)
					else
						top = math.ceil(topRight[2] / map.tileheight)
					end
					if topRight[1] > bottomRight[1] then
						right = math.ceil(topRight[1] / map.tilewidth)
					else
						right = math.ceil(bottomRight[1] / map.tilewidth)
					end
					if bottomRight[2] > bottomLeft[2] then
						bottom = math.ceil(bottomRight[2] / map.tileheight)
					else
						bottom = math.ceil(bottomLeft[2] / map.tileheight)
					end				
					masterGroup[layer].vars.camera = {left, top, right, bottom}	
					--print("do1", layer)
					--print(" ", left, prevLeft)
					--print(" ", top, prevTop)
					--print(" ", right, prevRight)
					--print(" ", bottom, prevBottom)				
					for locX = left, right, 1 do
						for locY = top, bottom, 1 do										
							updateTile2({locX = locX, locY = locY, layer = layer})
							drawCulledObjects(locX, locY, layer)
							drawLargeTile(locX, locY, layer)
						end
					end
					--print("=============")
					------------
					--print("do", layer)
				else	
					--print("do2", layer)
					--Cull and Render
					local prevLeft = masterGroup[layer].vars.camera[1]
					local prevTop = masterGroup[layer].vars.camera[2]
					local prevRight = masterGroup[layer].vars.camera[3]
					local prevBottom = masterGroup[layer].vars.camera[4]
					local angle = masterGroup.rotation + masterGroup[layer].rotation
					while angle >= 360 do
						angle = angle - 360
					end
					while angle < 0 do
						angle = angle + 360
					end					
					local topLeftT, topRightT, bottomRightT, bottomLeftT
					topLeftT = {masterGroup.parent:localToContent(screenLeft - cullingMargin[1], screenTop - cullingMargin[2])}
					topRightT = {masterGroup.parent:localToContent(screenRight + cullingMargin[3], screenTop - cullingMargin[2])}
					bottomRightT = {masterGroup.parent:localToContent(screenRight + cullingMargin[3], screenBottom + cullingMargin[4])}
					bottomLeftT = {masterGroup.parent:localToContent(screenLeft - cullingMargin[1], screenBottom + cullingMargin[4])}					
					local topLeft, topRight, bottomRight, bottomLeft
					if angle >= 0 and angle < 90 then
						topLeft = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
						topRight = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
						bottomRight = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
						bottomLeft = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
					elseif angle >= 90 and angle < 180 then
						topLeft = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
						topRight = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
						bottomRight = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
						bottomLeft = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
					elseif angle >= 180 and angle < 270 then
						topLeft = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
						topRight = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
						bottomRight = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
						bottomLeft = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
					elseif angle >= 270 and angle < 360 then
						topLeft = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
						topRight = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
						bottomRight = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
						bottomLeft = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
					end
					local left, top, right, bottom
					if topLeft[1] < bottomLeft[1] then
						left = math.ceil(topLeft[1] / map.tilewidth)
					else
						left = math.ceil(bottomLeft[1] / map.tilewidth)
					end
					if topLeft[2] < topRight[2] then
						top = math.ceil(topLeft[2] / map.tileheight)
					else
						top = math.ceil(topRight[2] / map.tileheight)
					end
					if topRight[1] > bottomRight[1] then
						right = math.ceil(topRight[1] / map.tilewidth)
					else
						right = math.ceil(bottomRight[1] / map.tilewidth)
					end
					if bottomRight[2] > bottomLeft[2] then
						bottom = math.ceil(bottomRight[2] / map.tileheight)
					else
						bottom = math.ceil(bottomLeft[2] / map.tileheight)
					end						
					masterGroup[layer].vars.camera = {left, top, right, bottom}
					if left > prevRight or right < prevLeft or top > prevBottom or bottom < prevTop then
						--print("do3", layer, "==================================")
						--print(" ", left, prevLeft)
						--print(" ", top, prevTop)
						--print(" ", right, prevRight)
						--print(" ", bottom, prevBottom)
						for locX = prevLeft, prevRight, 1 do
							for locY = prevTop, prevBottom, 1 do
								--print("do4")										
								updateTile2({locX = locX, locY = locY, layer = layer, tile = -1})
								cullLargeTile(locX, locY, layer)
							end
						end
						for locX = left, right, 1 do
							for locY = top, bottom, 1 do		
								--print("do5")								
								updateTile2({locX = locX, locY = locY, layer = layer})
								drawCulledObjects(locX, locY, layer)
								drawLargeTile(locX, locY, layer)
							end
						end
						--print("=============")
					else
						--left
						if left > prevLeft then		--cull
							local tLeft = left
							for locX = prevLeft, tLeft - 1, 1 do
								for locY = prevTop, prevBottom, 1 do
									updateTile2({locX = locX, locY = locY, layer = layer, tile = -1})
									cullLargeTile(locX, locY, layer)
								end
							end
						elseif left < prevLeft then	--render
							local tLeft = prevLeft
							for locX = left, tLeft - 1, 1 do
								for locY = top, bottom, 1 do
									updateTile2({locX = locX, locY = locY, layer = layer})
									drawCulledObjects(locX, locY, layer)
									drawLargeTile(locX, locY, layer)
								end
							end
						end				
						--top
						if top > prevTop then		--cull
							local tTop = top
							for locX = prevLeft, prevRight, 1 do
								for locY = prevTop, tTop - 1, 1 do
									updateTile2({locX = locX, locY = locY, layer = layer, tile = -1})
									cullLargeTile(locX, locY, layer)
								end
							end
						elseif top < prevTop then	--render
							local tTop = prevTop
							for locX = left, right, 1 do
								for locY = top, tTop - 1, 1 do
									updateTile2({locX = locX, locY = locY, layer = layer})
									drawCulledObjects(locX, locY, layer)
									drawLargeTile(locX, locY, layer)
								end
							end
						end				
						--right
						if right > prevRight then		--render
							local tRight = prevRight
							for locX = tRight + 1, right, 1 do
								for locY = top, bottom, 1 do
									updateTile2({locX = locX, locY = locY, layer = layer})
									drawCulledObjects(locX, locY, layer)
									drawLargeTile(locX, locY, layer)
								end
							end
						elseif right < prevRight then	--cull
							local tRight = right
							for locX = tRight + 1, prevRight, 1 do
								for locY = prevTop, prevBottom, 1 do
									updateTile2({locX = locX, locY = locY, layer = layer, tile = -1})
									cullLargeTile(locX, locY, layer)
								end
							end
						end				
						--bottom
						if bottom > prevBottom then		--render
							local tBottom = prevBottom
							for locX = left, right, 1 do
								for locY = tBottom + 1, bottom, 1 do
									updateTile2({locX = locX, locY = locY, layer = layer})
									drawCulledObjects(locX, locY, layer)
									drawLargeTile(locX, locY, layer)
								end
							end
						elseif bottom < prevBottom then	--cull
							local tBottom = bottom
							for locX = prevLeft, prevRight, 1 do
								for locY = tBottom + 1, prevBottom, 1 do
									updateTile2({locX = locX, locY = locY, layer = layer, tile = -1})
									cullLargeTile(locX, locY, layer)
								end
							end
						end
					end				
				end
			end
		end

		--PROCESS TILE ANIMATIONS
		if not M.tileAnimsFrozen then
			for key,value in pairs(syncData) do
				syncData[key].counter = syncData[key].counter - 1
				if syncData[key].counter <= 0 then
					syncData[key].counter = syncData[key].time
					syncData[key].currentFrame = syncData[key].currentFrame + 1
					if syncData[key].currentFrame > #syncData[key].frames then
						syncData[key].currentFrame = 1
					end
				end
			end
			for key,value in pairs(animatedTiles) do
				if syncData[animatedTiles[key].sync] then
					animatedTiles[key]:setFrame(syncData[animatedTiles[key].sync].currentFrame)
				end
			end
		end
		
		--APPLY HEIGHTMAP
		if enableHeightMap then
			for i = 1, #map.layers, 1 do
				if map.layers[i].heightMap or map.heightMap then
					local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
					local cameraX, cameraY = masterGroup[i]:contentToLocal(tempX, tempY)
					local cameraLocX = math.ceil(cameraX / map.tilewidth)
					local cameraLocY = math.ceil(cameraY / map.tileheight)
					local mH = map.layers[i].heightMap
					local gH = map.heightMap
					for x = masterGroup[i].vars.camera[1], masterGroup[i].vars.camera[3], 1 do
						for y = masterGroup[i].vars.camera[2], masterGroup[i].vars.camera[4], 1 do
							local locX = x
							local locY = y
							if locX < 1 - map.locOffsetX then
								locX = locX + map.layers[i].width
							end
							if locX > map.layers[i].width - map.locOffsetX then
								locX = locX - map.layers[i].width
							end										
							if locY < 1 - map.locOffsetY then
								locY = locY + map.layers[i].height
							end
							if locY > map.layers[i].height - map.locOffsetY then
								locY = locY - map.layers[i].height
							end
							if tileObjects[i][locX] and tileObjects[i][locX][locY] then
								local rect = tileObjects[i][locX][locY]								
								local rectX = rect.x
								local rectY = rect.y
								local tempScaleX = rect.tempScaleX / 2
								local tempScaleY = rect.tempScaleY / 2
								local rP = rect.path
								if rect.heightMap then
									local hM = rect.heightMap									
									local x1, y1, x2, y2, x3, y3, x4, y4 = "x1", "y1", "x2", "y2", "x3", "y3", "x4", "y4"
									local a1, b1, a2, b2, a3, b3, a4, b4 = -1, -1, -1, -1, -1, -1, -1, -1									
									if enableFlipRotation then
										if map.layers[i].flipRotation[locX][locY] then
											local command = map.layers[i].flipRotation[locX][locY]
											if command == 3 then
												x1, y1, x2, y2, x3, y3, x4, y4 = "y4", "x4", "y1", "x1", "y2", "x2", "y3", "x3"
												b1, b2, b3, b4 = 1, 1, 1, 1
											elseif command == 5 then
												x1, y1, x2, y2, x3, y3, x4, y4 = "y2", "x2", "y3", "x3", "y4", "x4", "y1", "x1"
												a1, a2, a3, a4 = 1, 1, 1, 1
											elseif command == 6 then
												x1, y1, x2, y2, x3, y3, x4, y4 = "x3", "y3", "x4", "y4", "x1", "y1", "x2", "y2"
												a1, b1, a2, b2, a3, b3, a4, b4 = 1, 1, 1, 1, 1, 1, 1, 1
											elseif command == 2 then
												x1, y1, x2, y2, x3, y3, x4, y4 = "x2", "y2", "x1", "y1", "x4", "y4", "x3", "y3"
												b1, b2, b3, b4 = 1, 1, 1, 1
											elseif command == 4 then
												x1, y1, x2, y2, x3, y3, x4, y4 = "x4", "y4", "x3", "y3", "x2", "y2", "x1", "y1"
												a1, a2, a3, a4 = 1, 1, 1, 1
											elseif command == 1 then
												x1, y1, x2, y2, x3, y3, x4, y4 = "y1", "x1", "y4", "x4", "y3", "x3", "y2", "x2"
											elseif command == 7 then
												x1, y1, x2, y2, x3, y3, x4, y4 = "y3", "x3", "y2", "x2", "y1", "x1", "y4", "x4"
												a1, b1, a2, b2, a3, b3, a4, b4 = 1, 1, 1, 1, 1, 1, 1, 1
											end
										end
									end									
									rP["x1"] = (((cameraX - (rectX - tempScaleX)) * (1 + (hM[1] or 0))) - (cameraX - (rectX - tempScaleX))) * a1 - M.overDraw
									rP["y1"] = (((cameraY - (rectY - tempScaleY)) * (1 + (hM[1] or 0))) - (cameraY - (rectY - tempScaleY))) * b1 - M.overDraw									
									rP["x2"] = (((cameraX - (rectX - tempScaleX)) * (1 + (hM[2] or 0))) - (cameraX - (rectX - tempScaleX))) * a2 - M.overDraw
									rP["y2"] = (((cameraY - (rectY + tempScaleY)) * (1 + (hM[2] or 0))) - (cameraY - (rectY + tempScaleY))) * b2 + M.overDraw									
									rP["x3"] = (((cameraX - (rectX + tempScaleX)) * (1 + (hM[3] or 0))) - (cameraX - (rectX + tempScaleX))) * a3 + M.overDraw
									rP["y3"] = (((cameraY - (rectY + tempScaleY)) * (1 + (hM[3] or 0))) - (cameraY - (rectY + tempScaleY))) * b3 + M.overDraw									
									rP["x4"] = (((cameraX - (rectX + tempScaleX)) * (1 + (hM[4] or 0))) - (cameraX - (rectX + tempScaleX))) * a4 + M.overDraw
									rP["y4"] = (((cameraY - (rectY - tempScaleY)) * (1 + (hM[4] or 0))) - (cameraY - (rectY - tempScaleY))) * b4 - M.overDraw
								else
									local locXminus1 = locX - 1
									local locYminus1 = locY - 1
									local locXplus1 = locX + 1
									local locYplus1 = locY + 1									
									if map.heightMap then
										mH = gH
									end									
									if locXminus1 < 1 then
										locXminus1 = #mH
									end								
									if locYminus1 < 1 then
										locYminus1 = #mH[locX]
									end	
									if locXplus1 > #mH then
										locXplus1 = 1
									end								
									if locYplus1 > #mH[locX] then
										locYplus1 = 1
									end										
									local x1, y1, x2, y2, x3, y3, x4, y4 = "x1", "y1", "x2", "y2", "x3", "y3", "x4", "y4"
									local a1, b1, a2, b2, a3, b3, a4, b4 = -1, -1, -1, -1, -1, -1, -1, -1									
									if enableFlipRotation then
										if map.layers[i].flipRotation[locX][locY] then
											local command = map.layers[i].flipRotation[locX][locY]
											if command == 3 then
												x1, y1, x2, y2, x3, y3, x4, y4 = "y4", "x4", "y1", "x1", "y2", "x2", "y3", "x3"
												b1, b2, b3, b4 = 1, 1, 1, 1
											elseif command == 5 then
												x1, y1, x2, y2, x3, y3, x4, y4 = "y2", "x2", "y3", "x3", "y4", "x4", "y1", "x1"
												a1, a2, a3, a4 = 1, 1, 1, 1
											elseif command == 6 then
												x1, y1, x2, y2, x3, y3, x4, y4 = "x3", "y3", "x4", "y4", "x1", "y1", "x2", "y2"
												a1, b1, a2, b2, a3, b3, a4, b4 = 1, 1, 1, 1, 1, 1, 1, 1
											elseif command == 2 then
												x1, y1, x2, y2, x3, y3, x4, y4 = "x2", "y2", "x1", "y1", "x4", "y4", "x3", "y3"
												b1, b2, b3, b4 = 1, 1, 1, 1
											elseif command == 4 then
												x1, y1, x2, y2, x3, y3, x4, y4 = "x4", "y4", "x3", "y3", "x2", "y2", "x1", "y1"
												a1, a2, a3, a4 = 1, 1, 1, 1
											elseif command == 1 then
												x1, y1, x2, y2, x3, y3, x4, y4 = "y1", "x1", "y4", "x4", "y3", "x3", "y2", "x2"
											elseif command == 7 then
												x1, y1, x2, y2, x3, y3, x4, y4 = "y3", "x3", "y2", "x2", "y1", "x1", "y4", "x4"
												a1, b1, a2, b2, a3, b3, a4, b4 = 1, 1, 1, 1, 1, 1, 1, 1
											end
										end
									end	 									
									local tempHeight = ((mH[locX][locY] or 0) + (mH[locXminus1][locY] or 0) + (mH[locX][locYminus1] or 0) + (mH[locXminus1][locYminus1] or 0)) / 4
									rP[x1] = (((cameraX - (rectX - tempScaleX)) * (1 + tempHeight)) - (cameraX - (rectX - tempScaleX))) * a1 - M.overDraw
									rP[y1] = (((cameraY - (rectY - tempScaleY)) * (1 + tempHeight)) - (cameraY - (rectY - tempScaleY))) * b1 - M.overDraw																
									local tempHeight = ((mH[locX][locY] or 0) + (mH[locXminus1][locY] or 0) + (mH[locX][locYplus1] or 0) + (mH[locXminus1][locYplus1] or 0)) / 4
									rP[x2] = (((cameraX - (rectX - tempScaleX)) * (1 + tempHeight)) - (cameraX - (rectX - tempScaleX))) * a2 - M.overDraw
									rP[y2] = (((cameraY - (rectY + tempScaleY)) * (1 + tempHeight)) - (cameraY - (rectY + tempScaleY))) * b2 + M.overDraw															
									local tempHeight = ((mH[locX][locY] or 0) + (mH[locXplus1][locY] or 0) + (mH[locX][locYplus1] or 0) + (mH[locXplus1][locYplus1] or 0)) / 4
									rP[x3] = (((cameraX - (rectX + tempScaleX)) * (1 + tempHeight)) - (cameraX - (rectX + tempScaleX))) * a3 + M.overDraw
									rP[y3] = (((cameraY - (rectY + tempScaleY)) * (1 + tempHeight)) - (cameraY - (rectY + tempScaleY))) * b3 + M.overDraw															
									local tempHeight = ((mH[locX][locY] or 0) + (mH[locXplus1][locY] or 0) + (mH[locX][locYminus1] or 0) + (mH[locXplus1][locYminus1] or 0)) / 4
									rP[x4] = (((cameraX - (rectX + tempScaleX)) * (1 + tempHeight)) - (cameraX - (rectX + tempScaleX))) * a4 + M.overDraw
									rP[y4] = (((cameraY - (rectY - tempScaleY)) * (1 + tempHeight)) - (cameraY - (rectY - tempScaleY))) * b4 - M.overDraw
								end
								--------
							end
						end
					end
				end
			end
		end
		
		local updated = false
		if M.enableLighting then
			if M.lightingData.refreshStyle == 1 then
				--continuous
				local mapLayerFalloff = map.properties.lightLayerFalloff
				local mapLevelFalloff = map.properties.lightLevelFalloff			
				local startLocX = masterGroup[1].vars.camera[1]
				local startLocY = masterGroup[1].vars.camera[2]
				local endLocX = masterGroup[1].vars.camera[3]
				local endLocY = masterGroup[1].vars.camera[4]				
				for x = startLocX, endLocX, 1 do
					for y = startLocY, endLocY, 1 do
						local updated = true
						local checked = false
						local locX, locY = x, y
						for i = 1, #map.layers, 1 do
							if layerWrapX[i] then
								if locX < 1 - map.locOffsetX then
									locX = locX + map.layers[i].width
								elseif locX > map.layers[i].width - map.locOffsetX then
									locX = locX - map.layers[i].width
								end
							end
							if layerWrapY[i] then
								if locY < 1 - map.locOffsetY then
									locY = locY + map.layers[i].height
								elseif locY > map.layers[i].height - map.locOffsetY then
									locY = locY - map.layers[i].height
								end
							end
							if tileObjects[i][locX] and tileObjects[i][locX][locY] then
								local rect = tileObjects[i][locX][locY]								
								if not rect.noDraw then	
									--Normal Map Point Light
									if rect.normalMap and pointLightSource then
										local lightX = pointLightSource.x
										local lightY = pointLightSource.y
										if pointLightSource.pointLight then
											if pointLightSource.pointLight.pointLightPos then
												rect.fill.effect.pointLightPos = {((lightX + pointLightSource.pointLight.pointLightPos[1]) - rect.x + map.tilewidth / 2) / map.tilewidth, 
													((lightY + pointLightSource.pointLight.pointLightPos[2]) - rect.y + map.tileheight / 2) / map.tileheight, 
													pointLightSource.pointLight.pointLightPos[3]
												}
											else
												rect.fill.effect.pointLightPos = {(lightX - rect.x + map.tilewidth / 2) / map.tilewidth, 
													(lightY - rect.y + map.tileheight / 2) / map.tileheight, 
													0.1
												}
											end
											if pointLightSource.pointLight.pointLightColor then
												rect.fill.effect.pointLightColor = pointLightSource.pointLight.pointLightColor
											end
											if pointLightSource.pointLight.ambientLightIntensity then
												rect.fill.effect.ambientLightIntensity = pointLightSource.pointLight.ambientLightIntensity
											end
											if pointLightSource.pointLight.attenuationFactors then
												rect.fill.effect.attenuationFactors = pointLightSource.pointLight.attenuationFactors
											end 
										else
											rect.fill.effect.pointLightPos = {(lightX - rect.x + map.tilewidth / 2) / map.tilewidth, 
												(lightY - rect.y + map.tileheight / 2) / map.tileheight, 
												0.1
											}
										end
									end
									
									--Tile Lighting							
									if map.lightToggle[locX][locY] and map.lightToggle[locX][locY] > map.lightToggle2[locX][locY] then
										rect.litBy = {}
										checked = true
										local layer = i
										local redf, greenf, bluef = map.layers[layer].redLight, map.layers[layer].greenLight, map.layers[layer].blueLight
										if map.perlinLighting then
											redf = redf * map.perlinLighting[locX][locY]
											greenf = greenf * map.perlinLighting[locX][locY]
											bluef = bluef * map.perlinLighting[locX][locY]
										elseif map.layers[layer].perlinLighting then
											redf = redf * map.layers[layer].perlinLighting[locX][locY]
											greenf = greenf * map.layers[layer].perlinLighting[locX][locY]
											bluef = bluef * map.layers[layer].perlinLighting[locX][locY]
										end
										for k = 1, #map.layers, 1 do									
											if map.layers[k].lighting[locX][locY] then
												local temp = map.layers[k].lighting[locX][locY]
												for key,value in pairs(temp) do
													local levelDiff = math.abs(M.getLevel(i) - map.lights[key].level)
													local layerDiff = math.abs(i - map.lights[key].layer)											
													local layerFalloff, levelFalloff
													if map.lights[key].layerFalloff then
														layerFalloff = map.lights[key].layerFalloff
													else
														layerFalloff = mapLayerFalloff
													end											
													if map.lights[key].levelFalloff then
														levelFalloff = map.lights[key].levelFalloff
													else
														levelFalloff = mapLevelFalloff
													end											
													local tR = temp[key].light[1] - (levelDiff * levelFalloff[1]) - (layerDiff * layerFalloff[1])
													local tG = temp[key].light[2] - (levelDiff * levelFalloff[2]) - (layerDiff * layerFalloff[2])
													local tB = temp[key].light[3] - (levelDiff * levelFalloff[3]) - (layerDiff * layerFalloff[3])
													if tR > redf then
														redf = tR
													end
													if tG > greenf then
														greenf = tG
													end
													if tB > bluef then
														bluef = tB
													end													
													rect.litBy[#rect.litBy + 1] = key
												end
											end
										end								
										local check = 0
										if redf > rect.color[1] then
											if redf - rect.color[1] <= M.lightingData.fadeIn then
												rect.color[1] = redf
												check = check + 1
											else
												rect.color[1] = rect.color[1] + M.lightingData.fadeIn
											end
										elseif redf < rect.color[1] then
											if rect.color[1] - redf <= M.lightingData.fadeOut then
												rect.color[1] = redf
												check = check + 1
											else
												rect.color[1] = rect.color[1] - M.lightingData.fadeOut
											end
										else
											check = check + 1
										end							
										if rect.color[1] > 1 then
											rect.color[1] = 1
										elseif rect.color[1] < 0 then
											rect.color[1] = 0
										end						
										if greenf > rect.color[2] then
											if greenf - rect.color[2] < M.lightingData.fadeIn then
												rect.color[2] = greenf
												check = check + 1
											else
												rect.color[2] = rect.color[2] + M.lightingData.fadeIn
											end
										elseif greenf < rect.color[2] then
											if rect.color[2] - greenf < M.lightingData.fadeOut then
												rect.color[2] = greenf
												check = check + 1
											else
												rect.color[2] = rect.color[2] - M.lightingData.fadeOut
											end
										else
											check = check + 1
										end							
										if rect.color[2] > 1 then
											rect.color[2] = 1
										elseif rect.color[2] < 0 then
											rect.color[2] = 0
										end													
										if bluef > rect.color[3] then
											if bluef - rect.color[3] < M.lightingData.fadeIn then
												rect.color[3] = bluef
												check = check + 1
											else
												rect.color[3] = rect.color[3] + M.lightingData.fadeIn
											end
										elseif bluef < rect.color[3] then
											if rect.color[3] - bluef < M.lightingData.fadeOut then
												rect.color[3] = bluef
												check = check + 1
											else
												rect.color[3] = rect.color[3] - M.lightingData.fadeOut
											end
										else
											check = check + 1
										end							
										if rect.color[3] > 1 then
											rect.color[3] = 1
										elseif rect.color[3] < 0 then
											rect.color[3] = 0
										end								
										if check < 3 then
											updated = false
										end										
										rect:setFillColor(rect.color[1], rect.color[2], rect.color[3])
									end								
								end
							end
						end
						if checked and updated then
							map.lightToggle2[locX][locY] = tonumber(system.getTimer())
						end
					end
				end
			elseif M.lightingData.refreshStyle == 2 then
				--columns alternator
				local mapLayerFalloff = map.properties.lightLayerFalloff
				local mapLevelFalloff = map.properties.lightLevelFalloff				
				local startLocX = masterGroup[1].vars.camera[1]
				local startLocY = masterGroup[1].vars.camera[2]
				local endLocX = masterGroup[1].vars.camera[3]
				local endLocY = masterGroup[1].vars.camera[4]						
				local startX = startLocX + (M.lightingData.refreshCounter - 1)
				for x = startX, endLocX, M.lightingData.refreshAlternator do
					for y = startLocY, endLocY, 1 do
						local updated = true
						local checked = false
						local locX, locY = x, y
						for i = 1, #map.layers, 1 do
							if layerWrapX[i] then
								if locX < 1 - map.locOffsetX then
									locX = locX + map.layers[i].width
								elseif locX > map.layers[i].width - map.locOffsetX then
									locX = locX - map.layers[i].width
								end
							end
							if layerWrapY[i] then
								if locY < 1 - map.locOffsetY then
									locY = locY + map.layers[i].height
								elseif locY > map.layers[i].height - map.locOffsetY then
									locY = locY - map.layers[i].height
								end
							end
							if tileObjects[i][locX] and tileObjects[i][locX][locY] then
								local rect = tileObjects[i][locX][locY]								
								if not rect.noDraw then		
									--Normal Map Point Light
									if rect.normalMap and pointLightSource then
										local lightX = pointLightSource.x
										local lightY = pointLightSource.y
										if pointLightSource.pointLight then
											if pointLightSource.pointLight.pointLightPos then
												rect.fill.effect.pointLightPos = {((lightX + pointLightSource.pointLight.pointLightPos[1]) - rect.x + map.tilewidth / 2) / map.tilewidth, 
													((lightY + pointLightSource.pointLight.pointLightPos[2]) - rect.y + map.tileheight / 2) / map.tileheight, 
													pointLightSource.pointLight.pointLightPos[3]
												}
											else
												rect.fill.effect.pointLightPos = {(lightX - rect.x + map.tilewidth / 2) / map.tilewidth, 
													(lightY - rect.y + map.tileheight / 2) / map.tileheight, 
													0.1
												}
											end
											if pointLightSource.pointLight.pointLightColor then
												rect.fill.effect.pointLightColor = pointLightSource.pointLight.pointLightColor
											end
											if pointLightSource.pointLight.ambientLightIntensity then
												rect.fill.effect.ambientLightIntensity = pointLightSource.pointLight.ambientLightIntensity
											end
											if pointLightSource.pointLight.attenuationFactors then
												rect.fill.effect.attenuationFactors = pointLightSource.pointLight.attenuationFactors
											end 
										else
											rect.fill.effect.pointLightPos = {(lightX - rect.x + map.tilewidth / 2) / map.tilewidth, 
												(lightY - rect.y + map.tileheight / 2) / map.tileheight, 
												0.1
											}
											
										end
									end
									
									--Tile Lighting						
									if map.lightToggle[locX][locY] and map.lightToggle[locX][locY] > map.lightToggle2[locX][locY] then
										rect.litBy = {}
										checked = true
										local layer = i
										local redf, greenf, bluef = map.layers[layer].redLight, map.layers[layer].greenLight, map.layers[layer].blueLight
										if map.perlinLighting then
											redf = redf * map.perlinLighting[locX][locY]
											greenf = greenf * map.perlinLighting[locX][locY] 
											bluef = bluef * map.perlinLighting[locX][locY] 
										elseif map.layers[layer].perlinLighting then
											redf = redf * map.layers[layer].perlinLighting[locX][locY] 
											greenf = greenf * map.layers[layer].perlinLighting[locX][locY] 
											bluef = bluef * map.layers[layer].perlinLighting[locX][locY] 
										end
										for k = 1, #map.layers, 1 do									
											if map.layers[k].lighting[locX][locY] then
												local temp = map.layers[k].lighting[locX][locY]
												for key,value in pairs(temp) do
													local levelDiff = math.abs(M.getLevel(i) - map.lights[key].level)
													local layerDiff = math.abs(i - map.lights[key].layer)											
													local layerFalloff, levelFalloff
													if map.lights[key].layerFalloff then
														layerFalloff = map.lights[key].layerFalloff
													else
														layerFalloff = mapLayerFalloff
													end											
													if map.lights[key].levelFalloff then
														levelFalloff = map.lights[key].levelFalloff
													else
														levelFalloff = mapLevelFalloff
													end											
													local tR = temp[key].light[1] - (levelDiff * levelFalloff[1]) - (layerDiff * layerFalloff[1])
													local tG = temp[key].light[2] - (levelDiff * levelFalloff[2]) - (layerDiff * layerFalloff[2])
													local tB = temp[key].light[3] - (levelDiff * levelFalloff[3]) - (layerDiff * layerFalloff[3])
													if tR > redf then
														redf = tR
													end
													if tG > greenf then
														greenf = tG
													end
													if tB > bluef then
														bluef = tB
													end													
													rect.litBy[#rect.litBy + 1] = key
												end
											end
										end								
										local check = 0
										if redf > rect.color[1] then
											if redf - rect.color[1] <= M.lightingData.fadeIn then
												rect.color[1] = redf
												check = check + 1
											else
												rect.color[1] = rect.color[1] + M.lightingData.fadeIn
											end
										elseif redf < rect.color[1] then
											if rect.color[1] - redf <= M.lightingData.fadeOut then
												rect.color[1] = redf
												check = check + 1
											else
												rect.color[1] = rect.color[1] - M.lightingData.fadeOut
											end
										else
											check = check + 1
										end							
										if rect.color[1] > 1 then
											rect.color[1] = 1
										elseif rect.color[1] < 0 then
											rect.color[1] = 0
										end						
										if greenf > rect.color[2] then
											if greenf - rect.color[2] < M.lightingData.fadeIn then
												rect.color[2] = greenf
												check = check + 1
											else
												rect.color[2] = rect.color[2] + M.lightingData.fadeIn
											end
										elseif greenf < rect.color[2] then
											if rect.color[2] - greenf < M.lightingData.fadeOut then
												rect.color[2] = greenf
												check = check + 1
											else
												rect.color[2] = rect.color[2] - M.lightingData.fadeOut
											end
										else
											check = check + 1
										end							
										if rect.color[2] > 1 then
											rect.color[2] = 1
										elseif rect.color[2] < 0 then
											rect.color[2] = 0
										end													
										if bluef > rect.color[3] then
											if bluef - rect.color[3] < M.lightingData.fadeIn then
												rect.color[3] = bluef
												check = check + 1
											else
												rect.color[3] = rect.color[3] + M.lightingData.fadeIn
											end
										elseif bluef < rect.color[3] then
											if rect.color[3] - bluef < M.lightingData.fadeOut then
												rect.color[3] = bluef
												check = check + 1
											else
												rect.color[3] = rect.color[3] - M.lightingData.fadeOut
											end
										else
											check = check + 1
										end							
										if rect.color[3] > 1 then
											rect.color[3] = 1
										elseif rect.color[3] < 0 then
											rect.color[3] = 0
										end								
										if check < 3 then
											updated = false
										end										
										rect:setFillColor(rect.color[1], rect.color[2], rect.color[3])
									end								
								end
							end
						end
						if checked and updated then
							map.lightToggle2[locX][locY] = tonumber(system.getTimer())
						end
					end
				end
				M.lightingData.refreshCounter = M.lightingData.refreshCounter + 1
				if M.lightingData.refreshCounter > M.lightingData.refreshAlternator then
					M.lightingData.refreshCounter = 1
				end
			end
		end
		
		--Fade and Tint layers
		for i = 1, #map.layers, 1 do
			if masterGroup[i].vars.deltaFade then
				masterGroup[i].vars.tempAlpha = masterGroup[i].vars.tempAlpha - masterGroup[i].vars.deltaFade[1]
				if masterGroup[i].vars.tempAlpha > 1 then
					masterGroup[i].vars.tempAlpha = 1
				end
				if masterGroup[i].vars.tempAlpha < 0 then
					masterGroup[i].vars.tempAlpha = 0
				end
				if map.orientation == 1 then
					if M.isoSort == 1 then
						masterGroup[i].alpha = masterGroup[i].vars.tempAlpha
						masterGroup[i].vars.alpha = masterGroup[i].vars.tempAlpha
					else
						for row = 1, #displayGroups, 1 do
							displayGroups[row].layers[i].alpha = masterGroup[i].vars.tempAlpha
						end
					end
				else
					masterGroup[i].alpha = masterGroup[i].vars.tempAlpha
				end
				masterGroup[i].vars.alpha = masterGroup[i].vars.tempAlpha
				table.remove(masterGroup[i].vars.deltaFade, 1)
				if not masterGroup[i].vars.deltaFade[1] then
					masterGroup[i].vars.deltaFade = nil
					masterGroup[i].vars.tempAlpha = nil
				end
			end
			if masterGroup[i].vars.deltaTint then
				map.layers[i].redLight = map.layers[i].redLight - masterGroup[i].vars.deltaTint[1][1]
				map.layers[i].greenLight = map.layers[i].greenLight - masterGroup[i].vars.deltaTint[2][1]
				map.layers[i].blueLight = map.layers[i].blueLight - masterGroup[i].vars.deltaTint[3][1]				
				for x = masterGroup[i].vars.camera[1], masterGroup[i].vars.camera[3], 1 do
					for y = masterGroup[i].vars.camera[2], masterGroup[i].vars.camera[4], 1 do
						if tileObjects[i][x] and tileObjects[i][x][y] and not tileObjects[i][x][y].noDraw then
							tileObjects[i][x][y]:setFillColor(map.layers[i].redLight, map.layers[i].greenLight, map.layers[i].blueLight)
							if not tileObjects[i][x][y].currentColor then
								tileObjects[i][x][y].currentColor = {map.layers[i].redLight, 
									map.layers[i].greenLight, 
									map.layers[i].blueLight
								}
							end
						end
					end
				end				
				table.remove(masterGroup[i].vars.deltaTint[1], 1)
				table.remove(masterGroup[i].vars.deltaTint[2], 1)
				table.remove(masterGroup[i].vars.deltaTint[3], 1)
				if not masterGroup[i].vars.deltaTint[1][1] then
					masterGroup[i].vars.deltaTint = nil
				end
			end
			if masterGroup[i].alpha <= 0 and masterGroup[i].isVisible then
				masterGroup[i].isVisible = false
				masterGroup[i].vars.isVisible = false
			elseif masterGroup[i].alpha > 0 and not masterGroup[i].isVisible then
				masterGroup[i].isVisible = true
				masterGroup[i].vars.isVisible = true
			end
		end
		
		--Fade tiles
		for key,value in pairs(fadingTiles) do
			local tile = fadingTiles[key]
			tile.tempAlpha = tile.tempAlpha - tile.deltaFade[1]
			if tile.tempAlpha > 1 then
				tile.tempAlpha = 1
			end
			if tile.tempAlpha < 0 then
				tile.tempAlpha = 0
			end
			tile.alpha = tile.tempAlpha
			table.remove(tile.deltaFade, 1)
			if not tile.deltaFade[1] then
				tile.deltaFade = nil
				tile.tempAlpha = nil
				fadingTiles[tile] = nil
			end
		end
		
		--Tint tiles
		for key,value in pairs(tintingTiles) do
			local tile = tintingTiles[key]
			if tileObjects[tile.layer][tile.locX] and tileObjects[tile.layer][tile.locX][tile.locY] then
				tile.currentColor[1] = tile.currentColor[1] - tile.deltaTint[1][1]
				tile.currentColor[2] = tile.currentColor[2] - tile.deltaTint[2][1]
				tile.currentColor[3] = tile.currentColor[3] - tile.deltaTint[3][1]
				for i = 1, 3, 1 do
					if tile.currentColor[i] > 1 then
						tile.currentColor[i] = 1
					end
					if tile.currentColor[i] < 0 then
						tile.currentColor[i] = 0
					end
				end
				tile:setFillColor(tile.currentColor[1], tile.currentColor[2], tile.currentColor[3])
				table.remove(tile.deltaTint[1], 1)
				table.remove(tile.deltaTint[2], 1)
				table.remove(tile.deltaTint[3], 1)
				if not tile.deltaTint[1][1] then
					tile.deltaTint = nil
					tintingTiles[tile] = nil
				end
			else
				tintingTiles[key] = nil
			end
		end
		
		--Zoom map
		if deltaZoom then
			currentScale = currentScale - deltaZoom[1]
			masterGroup.xScale = currentScale
			masterGroup.yScale = currentScale
			table.remove(deltaZoom, 1)
			if not deltaZoom[1] then
				deltaZoom = nil
			end
		end
		
		if masterGroup.xScale < M.minZoom then
			masterGroup.xScale = M.minZoom
		elseif masterGroup.xScale > M.maxZoom then
			masterGroup.xScale = M.maxZoom
		end
		
		if masterGroup.yScale < M.minZoom then
			masterGroup.yScale = M.minZoom
		elseif masterGroup.yScale > M.maxZoom then
			masterGroup.yScale = M.maxZoom
		end
		
		local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
		M.cameraX, M.cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)
		if map.orientation == 1 then
			local isoPos = M.isoUntransform2(M.cameraX, M.cameraY)
			M.cameraX = isoPos[1]
			M.cameraY = isoPos[2]
		end
		M.cameraLocX = math.ceil(M.cameraX / map.tilewidth)
		M.cameraLocY = math.ceil(M.cameraY / map.tileheight)
	end
	M.update = update2
	
	M.setCamera = function(parameters)
		if parameters.overDraw then
			M.overDraw = parameters.overDraw
		end		
		if parameters.parentGroup then
			parameters.parentGroup:insert(masterGroup)
		end		
		if parameters.scale then
			masterGroup.xScale = parameters.scale
			masterGroup.yScale = parameters.scale
		end
		if parameters.scaleX then
			masterGroup.xScale = parameters.scaleX
		end
		if parameters.scaleY then
			masterGroup.yScale = parameters.scaleY
		end		
		if parameters.blockScale then
			masterGroup.xScale = parameters.blockScale / map.tilewidth
			masterGroup.yScale = parameters.blockScale / map.tileheight
		end
		if parameters.blockScaleX then
			masterGroup.xScale = parameters.blockScaleX / map.tilewidth
		end
		if parameters.blockScaleY then
			masterGroup.yScale = parameters.blockScaleY / map.tileheight
		end		
		local levelPosX, levelPosY = 0, 0
		if parameters.locX then
			levelPosX = parameters.locX * map.tilewidth - (map.tilewidth / 2)
		end
		if parameters.locY then
			levelPosY = parameters.locY * map.tileheight - (map.tileheight / 2)
		end
		if parameters.levelPosX then
			levelPosX = parameters.levelPosX
		end
		if parameters.levelPosY then
			levelPosY = parameters.levelPosY
		end		
		if parameters.sprite then
			levelPosX = parameters.sprite.levelPosX or parameters.sprite.x
			levelPosY = parameters.sprite.levelPosY or parameters.sprite.y
		end
		for i = 1, masterGroup.numChildren, 1 do
			if map.orientation == 1 then
				masterGroup[i].x = levelPosX * -1 * map.layers[i].properties.scaleX 
				masterGroup[i].y = levelPosY * -1 * map.layers[i].properties.scaleY 
			else
				masterGroup[i].x = levelPosX * -1 * map.layers[i].properties.scaleX * map.layers[i].parallaxX
				masterGroup[i].y = levelPosY * -1 * map.layers[i].properties.scaleY * map.layers[i].parallaxY
			end	
		end		
		if parameters.cullingMargin then
			if parameters.cullingMargin[1] then
				cullingMargin[1] = parameters.cullingMargin[1]
			end
			if parameters.cullingMargin[2] then
				cullingMargin[2] = parameters.cullingMargin[2]
			end
			if parameters.cullingMargin[3] then
				cullingMargin[3] = parameters.cullingMargin[3]
			end
			if parameters.cullingMargin[4] then
				cullingMargin[4] = parameters.cullingMargin[4]
			end
		end		
		if map.orientation == 1 then
			for i = 1, #map.layers, 1 do			
				local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
				local cameraX, cameraY = masterGroup[i]:contentToLocal(tempX, tempY)
				local temp = M.isoTransform(cameraX, cameraY)
				M.cameraXoffset[i] = temp[1] - cameraX
				M.cameraYoffset[i] = temp[2] - cameraY
			end
		end		
		if not masterGroup[refLayer].vars.camera then
			M.spritesFrozen = true
			M.cameraFrozen = true
			M.update()
			M.spritesFrozen = false
			M.cameraFrozen = false
		end		
		return masterGroup
	end
	
	M.refresh = function()
		
		M.setMapProperties(map.properties)
		for i = 1, #map.layers, 1 do
			M.setLayerProperties(i, map.layers[i].properties)
		end
		for i = 1, #map.layers, 1 do
			for locX = masterGroup[i].vars.camera[1], masterGroup[i].vars.camera[3], 1 do
				for locY = masterGroup[i].vars.camera[2], masterGroup[i].vars.camera[4], 1 do
					--print(locX, locY)
					updateTile2({locX = locX, locY = locY, layer = i, tile = -1})
					cullLargeTile(locX, locY, i, true)
				end
			end
			masterGroup[i].vars.camera = nil
		end
		M.update()
		--PROCESS ANIMATION DATA
		for i = 1, #map.tilesets, 1 do
			if map.tilesets[i].tileproperties then
				for key,value in pairs(map.tilesets[i].tileproperties) do
					for key2,value2 in pairs(map.tilesets[i].tileproperties[key]) do
						if key2 == "animFrames" then
							local tempFrames
							if type(value2) == "string" then
								map.tilesets[i].tileproperties[key]["animFrames"] = json.decode(value2)
								tempFrames = json.decode(value2)
							else
								map.tilesets[i].tileproperties[key]["animFrames"] = value2
								tempFrames = value2
							end
							if map.tilesets[i].tileproperties[key]["animFrameSelect"] == "relative" then
								local frames = {}
								for f = 1, #tempFrames, 1 do
									frames[f] = (tonumber(key) + 1) + tempFrames[f]
								end
								map.tilesets[i].tileproperties[key]["sequenceData"] = {
									name="null",
									frames=frames,
									time = tonumber(map.tilesets[i].tileproperties[key]["animDelay"]),
									loopCount = 0
								}
							elseif map.tilesets[i].tileproperties[key]["animFrameSelect"] == "absolute" then
								map.tilesets[i].tileproperties[key]["sequenceData"] = {
									name="null",
									frames=tempFrames,
									time = tonumber(map.tilesets[i].tileproperties[key]["animDelay"]),
									loopCount = 0
								}
							end
							map.tilesets[i].tileproperties[key]["animSync"] = tonumber(map.tilesets[i].tileproperties[key]["animSync"]) or 1
							if not syncData[map.tilesets[i].tileproperties[key]["animSync"] ] then
								syncData[map.tilesets[i].tileproperties[key]["animSync"] ] = {}
								syncData[map.tilesets[i].tileproperties[key]["animSync"] ].time = (map.tilesets[i].tileproperties[key]["sequenceData"].time / #map.tilesets[i].tileproperties[key]["sequenceData"].frames) / frameTime
								syncData[map.tilesets[i].tileproperties[key]["animSync"] ].currentFrame = 1
								syncData[map.tilesets[i].tileproperties[key]["animSync"] ].counter = syncData[map.tilesets[i].tileproperties[key]["animSync"] ].time
								syncData[map.tilesets[i].tileproperties[key]["animSync"] ].frames = map.tilesets[i].tileproperties[key]["sequenceData"].frames
							end
						end
						if key2 == "shape" then
							if type(value2) == "string" then
								map.tilesets[i].tileproperties[key]["shape"] = json.decode(value2)
							else
								map.tilesets[i].tileproperties[key]["shape"] = value2
							end
						end
						if key2 == "filter" then
							if type(value2) == "string" then
								map.tilesets[i].tileproperties[key]["filter"] = json.decode(value2)
							else
								map.tilesets[i].tileproperties[key]["filter"] = value2
							end
						end
						if key2 == "opacity" then					
							frameIndex = tonumber(key) + (map.tilesets[i].firstgid - 1) + 1
						
							if not map.lightingData[frameIndex] then
								map.lightingData[frameIndex] = {}
							end
							if type(value2) == "string" then
								map.lightingData[frameIndex].opacity = json.decode(value2)
							else
								map.lightingData[frameIndex].opacity = value2
							end
						end
					end
				end
			end			
			if not map.tilesets[i].properties then
				map.tilesets[i].properties = {}
			end
		end
	end
	
	M.sendSpriteTo = function(parameters)
		local sprite = parameters.sprite
		if parameters.locX then
			sprite.locX = parameters.locX
			sprite.locY = parameters.locY
			sprite.levelPosX, sprite.levelPosY = M.locToLevelPos(parameters.locX, parameters.locY)
			sprite.x = sprite.levelPosX
			sprite.y = sprite.levelPosY
		elseif parameters.levelPosX then
			sprite.levelPosX = parameters.levelPosX
			sprite.levelPosY = parameters.levelPosY
			sprite.locX, sprite.locY = M.levelToLoc(parameters.levelPosX, parameters.levelPosY)
			sprite.x = sprite.levelPosX
			sprite.y = sprite.levelPosY
		end
	end
	
	M.moveSpriteTo = function(parameters)
		local object = parameters.sprite
		local layer = object.layer or object.parent.layer or object.parent.vars.layer
		local time = parameters.time or 0
		parameters.time = math.ceil(parameters.time / frameTime)
		local easing = parameters.transition or easing.linear		
		if parameters.locX then
			parameters.levelPosX = M.locToLevelPosX(parameters.locX)
		end
		if parameters.locY then
			parameters.levelPosY = M.locToLevelPosY(parameters.locY)
		end
		if not parameters.levelPosX then
			parameters.levelPosX = object.x
		end
		if not parameters.levelPosY then
			parameters.levelPosY = object.y
		end
		local constrain = {true, true, true, true}
		if parameters.constrainToMap ~= nil then
			constrain = parameters.constrainToMap
		elseif object.constrainToMap then
			constrain = object.constrainToMap
		end
		if parameters.override then
			if movingSprites[object] then
				movingSprites[object] = false
			end
		end		
		local easingHelper = function(distance, frames)
			local move = {}
			for i = 1, frames, 1 do
				move[i] = easing((i - 1) * frameLength, frameLength * frames, 0, 1000)
			end
			local move2 = {}
			local total2 = 0
			for i = 1, frames, 1 do
				if i < frames then
					move2[i] = move[i + 1] - move[i]
				else
					move2[i] = 1000 - move[i]
				end
				total2 = total2 + move2[i]
			end
			local mod2 = distance / total2
			local move3 = {}
			for i = 1, frames, 1 do
				move3[i] = move2[frames - (i - 1)] * mod2
			end
			return move3
		end		
		if not movingSprites[object] then
			if layerWrapX[layer] then
				local oX = object.levelPosX or object.x
				if oX - parameters.levelPosX < -0.5 * map.width * map.tilewidth then
					parameters.levelPosX = parameters.levelPosX - map.width * map.tilewidth
				end
				if oX - parameters.levelPosX > 0.5 * map.width * map.tilewidth then
					parameters.levelPosX = parameters.levelPosX + map.width * map.tilewidth
				end
				local distanceX = parameters.levelPosX - oX
				object.deltaX = easingHelper(distanceX, parameters.time, parameters.easing)
				movingSprites[parameters.sprite] = #object.deltaX
			else
				if parameters.levelPosX > map.layers[layer].width * map.tilewidth - (map.locOffsetX * map.tilewidth) and constrain[3] then
					parameters.levelPosX = map.layers[layer].width * map.tilewidth - (map.locOffsetX * map.tilewidth)
				end
				if parameters.levelPosX < 0 - (map.locOffsetX * map.tilewidth) and constrain[1] then
					parameters.levelPosX = 0 - (map.locOffsetX * map.tilewidth)
				end
				local distanceX = parameters.levelPosX - (object.levelPosX or object.x)
				object.deltaX = easingHelper(distanceX, parameters.time, parameters.easing)
				movingSprites[parameters.sprite] = #object.deltaX
			end			
			if layerWrapY[layer] then
				local oY = object.levelPosY or object.y
				if oY - parameters.levelPosY < -0.5 * map.height * map.tileheight then
					parameters.levelPosY = parameters.levelPosY - map.height * map.tileheight
				end
				if oY - parameters.levelPosY > 0.5 * map.height * map.tileheight then
					parameters.levelPosY = parameters.levelPosY + map.height * map.tileheight
				end
				local distanceY = parameters.levelPosY - oY
				object.deltaY = easingHelper(distanceY, parameters.time, parameters.easing)
				movingSprites[parameters.sprite] = #object.deltaY
			else
				if parameters.levelPosY > map.layers[layer].height * map.tileheight - (map.locOffsetY * map.tileheight) and constrain[4] then
					parameters.levelPosY = map.layers[layer].height * map.tileheight - (map.locOffsetY * map.tileheight)
				end
				if parameters.levelPosY < 0 - (map.locOffsetY * map.tileheight) and constrain[2] then
					parameters.levelPosY = 0 - (map.locOffsetY * map.tileheight)
				end
				local distanceY = parameters.levelPosY - (object.levelPosY or object.y)
				object.deltaY = easingHelper(distanceY, parameters.time, parameters.easing)
				movingSprites[parameters.sprite] = #object.deltaY
			end			
			object.onComplete = parameters.onComplete
			object.isMoving = true
		end
	end
	
	M.moveSprite = function(sprite, velX, velY)
		if velX ~= 0 or velY ~= 0 then
			M.moveSpriteTo({sprite = sprite, levelPosX = sprite.levelPosX + velX,
				levelPosY = sprite.levelPosY + velY, time = frameTime}
			)
		end
	end
	
	M.moveCameraTo = function(parameters)
		local check = true
		for i = 1, #map.layers, 1 do
			if i == parameters.layer or not parameters.layer then
				if isCameraMoving[i] then
					check = false
				else
					if parameters.disableParallax then
						parallaxToggle[i] = false
					else
						parameters.disableParallax = false
					end
					cameraOnComplete[i] = false
				end
			end
		end		
		if check and not parameters.layer then
			refMove = true
			cameraOnComplete[1] = parameters.onComplete
		end
		for i = 1, #map.layers, 1 do
			if (i == parameters.layer or not parameters.layer) and check then
				local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
				local cameraX, cameraY = masterGroup[i]:contentToLocal(tempX, tempY)
				local cameraLocX = math.ceil(cameraX / map.tilewidth)
				local cameraLocY = math.ceil(cameraY / map.tileheight)	
				
				if not parameters.time or parameters.time < 1 then
					parameters.time = 1
				end
				local time = math.ceil(parameters.time / frameTime)
				local levelPosX = parameters.levelPosX
				local levelPosY = parameters.levelPosY
				if parameters.sprite then
					if parameters.sprite.levelPosX then
						levelPosX = parameters.sprite.levelPosX + parameters.sprite.levelWidth * 0.0 + parameters.sprite.offsetX 
						levelPosY = parameters.sprite.levelPosY + parameters.sprite.levelHeight * 0.0 + parameters.sprite.offsetY 
					else
						levelPosX = parameters.sprite.x + parameters.sprite.levelWidth * 0.0 + parameters.sprite.offsetX 
						levelPosY = parameters.sprite.y + parameters.sprite.levelHeight * 0.0 + parameters.sprite.offsetY 
					end
				end
				if parameters.locX then
					levelPosX = parameters.locX * map.tilewidth - (map.tilewidth / 2)
				end
				if parameters.locY then
					levelPosY = parameters.locY * map.tileheight - (map.tileheight / 2)
				end				
				
				if not levelPosX then
					levelPosX = cameraX
				end
				if not levelPosY then
					levelPosY = cameraY
				end
					
				if not layerWrapX[i] then
					endX = levelPosX
					distanceX = endX - cameraX
					deltaX[i] = {}
					deltaX[i] = easingHelper(distanceX, time, parameters.transition)
				else
					local tempPosX = levelPosX
					if tempPosX > map.layers[i].width * map.tilewidth - (map.locOffsetX * map.tilewidth) then
						tempPosX = tempPosX - map.layers[i].width * map.tilewidth
					elseif tempPosX < 1 - (map.locOffsetX * map.tilewidth) then
						tempPosX = tempPosX + map.layers[i].width * map.tilewidth
					end			
					local tempPosX2 = tempPosX
					if tempPosX > cameraX then
						tempPosX2 = tempPosX - map.layers[i].width * map.tilewidth
					elseif tempPosX < cameraX then
						tempPosX2 = tempPosX + map.layers[i].width * map.tilewidth
					end			
					distanceXAcross = abs(cameraX - tempPosX)
					distanceXWrap = abs(cameraX - tempPosX2)
					if distanceXWrap < distanceXAcross then
						if tempPosX > cameraX then
							masterGroup[i].x = (cameraX + map.layers[i].width * map.tilewidth) * -1 * map.layers[i].properties.scaleX
						elseif tempPosX < cameraX then
							masterGroup[i].x = (cameraX - map.layers[i].width * map.tilewidth) * -1 * map.layers[i].properties.scaleX
						end
						local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
						local cameraX, cameraY = masterGroup[i]:contentToLocal(tempX, tempY)
						endX = tempPosX
						distanceX = endX - cameraX
						deltaX[i] = {}
						deltaX[i] = easingHelper(distanceX, time, parameters.transition)
					else
						endX = levelPosX
						distanceX = endX - cameraX
						deltaX[i] = {}
						deltaX[i] = easingHelper(distanceX, time, parameters.transition)
					end
				end				
				if not layerWrapY[i] then
					endY = levelPosY
					distanceY = endY - cameraY
					deltaY[i] = {}
					deltaY[i] = easingHelper(distanceY, time, parameters.transition)
				else
					local tempPosY = levelPosY
					if tempPosY > map.layers[i].height * map.tileheight then
						tempPosY = tempPosY - map.layers[i].height * map.tileheight
					elseif tempPosY < 1 then
						tempPosY = tempPosY + map.layers[i].height * map.tileheight
					end			
					local tempPosY2 = tempPosY
					if tempPosY > cameraY then
						tempPosY2 = tempPosY - map.layers[i].height * map.tileheight
					elseif tempPosY < cameraY then
						tempPosY2 = tempPosY + map.layers[i].height * map.tileheight
					end					
					distanceYAcross = abs(cameraY - tempPosY)
					distanceYWrap = abs(cameraY - tempPosY2)
					if distanceYWrap < distanceYAcross then
						if tempPosY > cameraY then
							masterGroup[i].y = (cameraY + map.layers[i].height * map.tileheight) * -1 * map.layers[i].properties.scaleY
						elseif tempPosY < cameraY then
							masterGroup[i].y = (cameraY - map.layers[i].height * map.tileheight) * -1 * map.layers[i].properties.scaleY
						end
						local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
						local cameraX, cameraY = masterGroup[i]:contentToLocal(tempX, tempY)
						endY = tempPosY
						distanceY = endY - cameraY
						deltaY[i] = {}
						deltaY[i] = easingHelper(distanceY, time, parameters.transition)
					else
						endY = levelPosY
						distanceY = endY - cameraY
						deltaY[i] = {}
						deltaY[i] = easingHelper(distanceY, time, parameters.transition)
					end
				end				
				isCameraMoving[i] = true
				if not refMove then
					cameraOnComplete[i] = parameters.onComplete
				end
			end
		end
	end
	
	M.moveCamera = function(velX, velY, layer)			
		if not layer then
			layer = refLayer
		end
		local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
		local cameraX, cameraY = masterGroup[layer]:contentToLocal(tempX, tempY)
		local cameraLocX = math.ceil(cameraX / map.tilewidth)
		local cameraLocY = math.ceil(cameraY / map.tileheight)
		M.moveCameraTo({levelPosX = cameraX + velX,
			levelPosY = cameraY + velY, time = frameTime}
		)
	end
	
	M.cancelSpriteMove = function(sprite, onComplete)
		if movingSprites[sprite] then
			local object = sprite
			object.isMoving = false
			object.deltaX = nil
			object.deltaY = nil
			movingSprites[sprite] = nil
			if object.onComplete then
				if onComplete == nil or onComplete == true then
					local event = { name = "spriteMoveComplete", sprite = object}
					object.onComplete(event)
					object.onComplete = nil
				else
					object.onComplete = nil
				end
			end
		end
	end

	
	M.cancelCameraMove = function(layer)
		if refMove or not layer then
			for i = 1, #map.layers, 1 do
				if deltaX[i] or deltaY[i] then
					if deltaX[i][1] or deltaY[i][1] then
						deltaX[i] = nil
						deltaY[i] = nil
						isCameraMoving[i] = false
						parallaxToggle[i] = true
						refMove = false
						override[i] = false
						holdSprite = nil
					end
				end
			end
			if cameraOnComplete[1] then
				local tempOnComplete = cameraOnComplete[1]
				cameraOnComplete = {}
				local event = { name = "cameraLayerMoveComplete", 
					levelPosX = cameraX, 
					levelPosY = cameraY, 
					locX = cameraLocX, 
					locY = cameraLocY
				}
				tempOnComplete(event)
			end
		else
			if deltaX[layer] or deltaY[layer] then
				if deltaX[layer][1] or deltaY[layer][1] then
					deltaX[layer] = nil
					deltaY[layer] = nil
					isCameraMoving[layer] = false
					parallaxToggle[layer] = true
					override[layer] = false
					holdSprite = nil
					if cameraOnComplete[layer] then
						local tempOnComplete = cameraOnComplete[layer]
						cameraOnComplete[layer] = nil
						local event = { name = "cameraLayerMoveComplete", layer = layer, 
							levelPosX = cameraX, 
							levelPosY = cameraY, 
							locX = cameraLocX, 
							locY = cameraLocY
						}
						tempOnComplete(event)
					end
				end
			end
		end
	end
	
	M.constrainCamera = function(parameters)
		local parameters = parameters
		if not parameters then
			parameters = {}
		end
		local leftParam, topParam, rightParam, bottomParam
		if parameters.loc then
			if parameters.loc[1] then
				leftParam = (parameters.loc[1] - 1) * map.tilewidth
			end
			if parameters.loc[2] then
				topParam = (parameters.loc[2] - 1) * map.tileheight
			end
			if parameters.loc[3] then
				rightParam = (parameters.loc[3]) * map.tilewidth
			end
			if parameters.loc[4] then
				bottomParam = (parameters.loc[4]) * map.tileheight
			end
		elseif parameters.levelPos then
			leftParam = parameters.levelPos[1]
			topParam = parameters.levelPos[2]
			rightParam = parameters.levelPos[3]
			bottomParam = parameters.levelPos[4]
		else
			leftParam = 0 - (map.locOffsetX * map.tilewidth)
			topParam = 0 - (map.locOffsetY * map.tileheight)
			rightParam = (map.width - map.locOffsetX) * map.tilewidth
			bottomParam = (map.height - map.locOffsetY) * map.tileheight
		end		
		local layer = parameters.layer
		local xA = parameters.xAlign or "center"
		local yA = parameters.yAlign or "center"
		local time = parameters.time or 1
		local transition = parameters.transition or easing.linear		
		if parameters.layer and parameters.layer == refLayer then
			parameters.layer = nil
		end		
		local check1 = true
		if parameters.layer and parameters.layer ~= "all" then
			if constrainTop[parameters.layer] == topParam and 
			constrainBottom[parameters.layer] == bottomParam and
			constrainLeft[parameters.layer] == leftParam and
			constrainRight[parameters.layer] == rightParam then
				check1 = false
			end
		end		
		if not parameters.layer or parameters.layer == "all" then
			if constrainTop[refLayer] == topParam and 
			constrainBottom[refLayer] == bottomParam and
			constrainLeft[refLayer] == leftParam and
			constrainRight[refLayer] == rightParam then
				check1 = false
			end
		end		
		if map.orientation == 1 then
			if check1 then
				holdSprite = true
				if parameters.holdSprite ~= nil and parameters.holdSprite == false then
					holdSprite = false
				end
				if not parameters.layer or parameters.layer == "all" then
					local check = true
					for i = 1, #map.layers, 1 do
						if override[i] then
							check = false
						end
					end
					if check then
						for i = 1, #map.layers, 1 do
							M.cancelCameraMove(i)
						end
						local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
						local cameraX, cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)
						local isoPos = M.isoUntransform2(cameraX, cameraY)
						cameraX = isoPos[1]
						cameraY = isoPos[2]
						local cameraLocX = math.ceil(cameraX / map.tilewidth)
						local cameraLocY = math.ceil(cameraY / map.tileheight)
						
						--calculate constraints
						local angle = masterGroup.rotation + masterGroup[refLayer].rotation
						while angle >= 360 do
							angle = angle - 360
						end
						while angle < 0 do
							angle = angle + 360
						end						
						local topLeftT, topRightT, bottomRightT, bottomLeftT
						topLeftT = {masterGroup.parent:localToContent(screenLeft, screenTop)}
						topRightT = {masterGroup.parent:localToContent(screenRight, screenTop)}
						bottomRightT = {masterGroup.parent:localToContent(screenRight, screenBottom)}
						bottomLeftT = {masterGroup.parent:localToContent(screenLeft, screenBottom)}					
						local topLeft, topRight, bottomRight, bottomLeft
						if angle >= 0 and angle < 90 then
							topLeft = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
							topRight = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
							bottomRight = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							bottomLeft = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
						elseif angle >= 90 and angle < 180 then
							topLeft = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
							topRight = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							bottomRight = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							bottomLeft = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
						elseif angle >= 180 and angle < 270 then
							topLeft = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							topRight = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							bottomRight = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
							bottomLeft = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
						elseif angle >= 270 and angle < 360 then
							topLeft = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							topRight = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
							bottomRight = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
							bottomLeft = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
						end
						local topLeftT, topRightT, bottomRightT, bottomLeftT = nil, nil, nil, nil
						topLeftT = M.isoUntransform2(topLeft[1], topLeft[2])
						topRightT = M.isoUntransform2(topRight[1], topRight[2])
						bottomRightT = M.isoUntransform2(bottomRight[1], bottomRight[2])
						bottomLeftT = M.isoUntransform2(bottomLeft[1], bottomLeft[2])					
						local leftBound, topBound, rightBound, bottomBound
						leftBound = topLeftT[1] - (map.tilewidth / 2)
						topBound = topRightT[2] - (map.tileheight / 2)
						rightBound = bottomRightT[1] - (map.tilewidth / 2)
						bottomBound = bottomLeftT[2] - (map.tileheight / 2)						
						local leftConstraint, topConstraint, rightConstraint, bottomConstraint
						if leftParam then
							leftConstraint = leftParam + (cameraX - leftBound)
						end
						if topParam then
							topConstraint = topParam + (cameraY - topBound)
						end
						if rightParam then
							rightConstraint = rightParam - (rightBound - cameraX)
						end
						if bottomParam then
							bottomConstraint = bottomParam - (bottomBound - cameraY)
						end							
						if (leftConstraint and rightConstraint) and (leftConstraint > rightConstraint) then
							local temp = (leftConstraint + rightConstraint) / 2
							leftConstraint = temp
							rightConstraint = temp
						end
						if (topConstraint and bottomConstraint) and (topConstraint > bottomConstraint) then
							local temp = (topConstraint + bottomConstraint) / 2
							topConstraint = temp
							bottomConstraint = temp
						end						
						local velX, velY = 0, 0
						if leftConstraint then
							if cameraX < leftConstraint then
								velX = (leftConstraint - cameraX)
							end
						end
						if rightConstraint then
							if cameraX > rightConstraint then
								velX = (rightConstraint - cameraX)
							end
						end
						if topConstraint then
							if cameraY < topConstraint then
								velY = (topConstraint - cameraY)
							end
						end
						if bottomConstraint then
							if cameraY > bottomConstraint then
								velY = (bottomConstraint - cameraY)
							end
						end						
						for i = 1, #map.layers, 1 do
							if not masterGroup[i].vars.constrainLayer then
								if map.layers[i].toggleParallax == true or map.layers[i].parallaxX ~= 1 or map.layers[i].parallaxY ~= 1 then
									masterGroup[i].vars.alignment = {xA, yA}
								end								
								constrainLeft[i] = nil
								constrainTop[i] = nil
								constrainRight[i] = nil
								constrainBottom[i] = nil								
								if leftParam then
									constrainLeft[i] = leftParam
								end
								if topParam then
									constrainTop[i] = topParam
								end
								if rightParam then
									constrainRight[i] = rightParam
								end
								if bottomParam then
									constrainBottom[i] = bottomParam
								end					
								local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
								local cameraX, cameraY = masterGroup[i]:contentToLocal(tempX, tempY)
								local isoPos = M.isoUntransform2(cameraX, cameraY)
								cameraX = isoPos[1]
								cameraY = isoPos[2]
								local cameraLocX = math.ceil(cameraX / map.tilewidth)
								local cameraLocY = math.ceil(cameraY / map.tileheight)							
								override[i] = true
								M.cancelCameraMove(i)
								M.moveCameraTo({levelPosX = cameraX + velX, levelPosY = cameraY + velY, time = time, easing = easing, layer = i})
							end
						end
						return constrainLeft, constrainTop, constrainRight, constrainBottom
					end
				else
					local layer = parameters.layer
					if not override[layer] then
						masterGroup[layer].vars.constrainLayer = true						
						constrainLeft[layer] = nil
						constrainTop[layer] = nil
						constrainRight[layer] = nil
						constrainBottom[layer] = nil						
						if leftParam then
							constrainLeft[layer] = leftParam
						end
						if topParam then
							constrainTop[layer] = topParam
						end
						if rightParam then
							constrainRight[layer] = rightParam
						end
						if bottomParam then
							constrainBottom[layer] = bottomParam
						end						
						local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
						local cameraX, cameraY = masterGroup[layer]:contentToLocal(tempX, tempY)
						local isoPos = M.isoUntransform2(cameraX, cameraY)
						cameraX = isoPos[1]
						cameraY = isoPos[2]
						local cameraLocX = math.ceil(cameraX / map.tilewidth)
						local cameraLocY = math.ceil(cameraY / map.tileheight)
			
						--calculate constraints
						local angle = masterGroup.rotation + masterGroup[layer].rotation
						while angle >= 360 do
							angle = angle - 360
						end
						while angle < 0 do
							angle = angle + 360
						end						
						local topLeftT, topRightT, bottomRightT, bottomLeftT
						topLeftT = {masterGroup.parent:localToContent(screenLeft, screenTop)}
						topRightT = {masterGroup.parent:localToContent(screenRight, screenTop)}
						bottomRightT = {masterGroup.parent:localToContent(screenRight, screenBottom)}
						bottomLeftT = {masterGroup.parent:localToContent(screenLeft, screenBottom)}					
						local topLeft, topRight, bottomRight, bottomLeft
						if angle >= 0 and angle < 90 then
							topLeft = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
							topRight = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
							bottomRight = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							bottomLeft = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
						elseif angle >= 90 and angle < 180 then
							topLeft = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
							topRight = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							bottomRight = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							bottomLeft = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
						elseif angle >= 180 and angle < 270 then
							topLeft = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							topRight = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							bottomRight = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
							bottomLeft = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
						elseif angle >= 270 and angle < 360 then
							topLeft = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							topRight = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
							bottomRight = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
							bottomLeft = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
						end						
						local topLeftT, topRightT, bottomRightT, bottomLeftT = nil, nil, nil, nil
						topLeftT = M.isoUntransform2(topLeft[1], topLeft[2])
						topRightT = M.isoUntransform2(topRight[1], topRight[2])
						bottomRightT = M.isoUntransform2(bottomRight[1], bottomRight[2])
						bottomLeftT = M.isoUntransform2(bottomLeft[1], bottomLeft[2])					
						local leftBound, topBound, rightBound, bottomBound
						leftBound = topLeftT[1] - (map.tilewidth / 2)
						topBound = topRightT[2] - (map.tileheight / 2)
						rightBound = bottomRightT[1] - (map.tilewidth / 2)
						bottomBound = bottomLeftT[2] - (map.tileheight / 2)						
						local leftConstraint, topConstraint, rightConstraint, bottomConstraint
						if constrainLeft[layer] then
							leftConstraint = constrainLeft[layer] + (cameraX - leftBound)
						end
						if constrainTop[layer] then
							topConstraint = constrainTop[layer] + (cameraY - topBound)
						end
						if constrainRight[layer] then
							rightConstraint = constrainRight[layer] - (rightBound - cameraX)
						end
						if constrainBottom[layer] then
							bottomConstraint = constrainBottom[layer] - (bottomBound - cameraY)
						end				
						if (leftConstraint and rightConstraint) and (leftConstraint > rightConstraint) then
							local temp = (leftConstraint + rightConstraint) / 2
							leftConstraint = temp
							rightConstraint = temp
						end
						if (topConstraint and bottomConstraint) and (topConstraint > bottomConstraint) then
							local temp = (topConstraint + bottomConstraint) / 2
							topConstraint = temp
							bottomConstraint = temp
						end			
						local velX, velY = 0, 0
						if leftConstraint then
							if cameraX < leftConstraint then
								velX = (leftConstraint - cameraX)
							end
						end
						if rightConstraint then
							if cameraX > rightConstraint then
								velX = (rightConstraint - cameraX)
							end
						end
						if topConstraint then
							if cameraY < topConstraint then
								velY = (topConstraint - cameraY)
							end
						end
						if bottomConstraint then
							if cameraY > bottomConstraint then
								velY = (bottomConstraint - cameraY)
							end
						end						
						override[layer] = true
						M.cancelCameraMove(layer)
						M.moveCameraTo({levelPosX = cameraX + velX, levelPosY = cameraY + velY, time = time, easing = easing, layer = layer})
						return constrainLeft, constrainTop, constrainRight, constrainBottom
					end
				end
			end
		else	--not isometric
			if check1 then
				holdSprite = true
				if parameters.holdSprite ~= nil and parameters.holdSprite == false then
					holdSprite = false
				end
				if not parameters.layer or parameters.layer == "all" then
					local check = true
					for i = 1, #map.layers, 1 do
						if override[i] then
							check = false
						end
					end
					if check then
						for i = 1, #map.layers, 1 do
							M.cancelCameraMove(i)
						end
						local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
						local cameraX, cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)
						local cameraLocX = math.ceil(cameraX / map.tilewidth)
						local cameraLocY = math.ceil(cameraY / map.tileheight)
						
						--calculate constraints
						local angle = masterGroup.rotation + masterGroup[refLayer].rotation
						while angle >= 360 do
							angle = angle - 360
						end
						while angle < 0 do
							angle = angle + 360
						end						
						local topLeftT, topRightT, bottomRightT, bottomLeftT
						topLeftT = {masterGroup.parent:localToContent(screenLeft, screenTop)}
						topRightT = {masterGroup.parent:localToContent(screenRight, screenTop)}
						bottomRightT = {masterGroup.parent:localToContent(screenRight, screenBottom)}
						bottomLeftT = {masterGroup.parent:localToContent(screenLeft, screenBottom)}						
						local topLeft, topRight, bottomRight, bottomLeft
						if angle >= 0 and angle < 90 then
							topLeft = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
							topRight = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
							bottomRight = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							bottomLeft = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
						elseif angle >= 90 and angle < 180 then
							topLeft = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
							topRight = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							bottomRight = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							bottomLeft = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
						elseif angle >= 180 and angle < 270 then
							topLeft = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							topRight = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							bottomRight = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
							bottomLeft = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
						elseif angle >= 270 and angle < 360 then
							topLeft = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							topRight = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
							bottomRight = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
							bottomLeft = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
						end
						local leftBound, topBound, rightBound, bottomBound
						if topLeft[1] < bottomLeft[1] then
							leftBound = topLeft[1]
						else
							leftBound = bottomLeft[1]
						end
						if topLeft[2] < topRight[2] then
							topBound = topLeft[2]
						else
							topBound = topRight[2]
						end
						if topRight[1] > bottomRight[1] then
							rightBound = topRight[1]
						else
							rightBound = bottomRight[1]
						end
						if bottomRight[2] > bottomLeft[2] then
							bottomBound = bottomRight[2]
						else
							bottomBound = bottomLeft[2]
						end					
						local leftConstraint, topConstraint, rightConstraint, bottomConstraint
						if leftParam then
							leftConstraint = leftParam + (cameraX - leftBound)
						end
						if topParam then
							topConstraint = topParam + (cameraY - topBound)
						end
						if rightParam then
							rightConstraint = rightParam - (rightBound - cameraX)
						end
						if bottomParam then
							bottomConstraint = bottomParam - (bottomBound - cameraY)
						end					
						if (leftConstraint and rightConstraint) and (leftConstraint > rightConstraint) then
							local temp = (leftConstraint + rightConstraint) / 2
							leftConstraint = temp
							rightConstraint = temp
						end
						if (topConstraint and bottomConstraint) and (topConstraint > bottomConstraint) then
							local temp = (topConstraint + bottomConstraint) / 2
							topConstraint = temp
							bottomConstraint = temp
						end				
						local velX, velY = 0, 0
						if leftConstraint then
							if cameraX < leftConstraint then
								velX = (leftConstraint - cameraX)
							end
						end
						if rightConstraint then
							if cameraX > rightConstraint then
								velX = (rightConstraint - cameraX)
							end
						end
						if topConstraint then
							if cameraY < topConstraint then
								velY = (topConstraint - cameraY)
							end
						end
						if bottomConstraint then
							if cameraY > bottomConstraint then
								velY = (bottomConstraint - cameraY)
							end
						end						
						for i = 1, #map.layers, 1 do
							if not masterGroup[i].vars.constrainLayer then
								if map.layers[i].toggleParallax == true or map.layers[i].parallaxX ~= 1 or map.layers[i].parallaxY ~= 1 then
									masterGroup[i].vars.alignment = {xA, yA}
								end								
								constrainLeft[i] = nil
								constrainTop[i] = nil
								constrainRight[i] = nil
								constrainBottom[i] = nil								
								if leftParam then
									constrainLeft[i] = leftParam
								end
								if topParam then
									constrainTop[i] = topParam
								end
								if rightParam then
									constrainRight[i] = rightParam
								end
								if bottomParam then
									constrainBottom[i] = bottomParam
								end									
								local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
								local cameraX, cameraY = masterGroup[i]:contentToLocal(tempX, tempY)
								local cameraLocX = math.ceil(cameraX / map.tilewidth)
								local cameraLocY = math.ceil(cameraY / map.tileheight)
								override[i] = true
								M.cancelCameraMove(i)
								M.moveCameraTo({levelPosX = cameraX + velX, levelPosY = cameraY + velY, time = time, transition = transition, layer = i})
							end							
						end
						return constrainLeft, constrainTop, constrainRight, constrainBottom
					end
				else
					local layer = parameters.layer
					if not override[layer] then
						masterGroup[layer].vars.constrainLayer = true						
						constrainLeft[layer] = nil
						constrainTop[layer] = nil
						constrainRight[layer] = nil
						constrainBottom[layer] = nil						
						if leftParam then
							constrainLeft[layer] = leftParam
						end
						if topParam then
							constrainTop[layer] = topParam
						end
						if rightParam then
							constrainRight[layer] = rightParam
						end
						if bottomParam then
							constrainBottom[layer] = bottomParam
						end			
						local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
						local cameraX, cameraY = masterGroup[layer]:contentToLocal(tempX, tempY)
						local cameraLocX = math.ceil(cameraX / map.tilewidth)
						local cameraLocY = math.ceil(cameraY / map.tileheight)
			
						--calculate constraints
						local angle = masterGroup.rotation + masterGroup[layer].rotation
						while angle >= 360 do
							angle = angle - 360
						end
						while angle < 0 do
							angle = angle + 360
						end						
						local topLeftT, topRightT, bottomRightT, bottomLeftT
						topLeftT = {masterGroup.parent:localToContent(screenLeft, screenTop)}
						topRightT = {masterGroup.parent:localToContent(screenRight, screenTop)}
						bottomRightT = {masterGroup.parent:localToContent(screenRight, screenBottom)}
						bottomLeftT = {masterGroup.parent:localToContent(screenLeft, screenBottom)}						
						local topLeft, topRight, bottomRight, bottomLeft
						if angle >= 0 and angle < 90 then
							topLeft = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
							topRight = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
							bottomRight = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							bottomLeft = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
						elseif angle >= 90 and angle < 180 then
							topLeft = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
							topRight = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							bottomRight = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							bottomLeft = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
						elseif angle >= 180 and angle < 270 then
							topLeft = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
							topRight = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							bottomRight = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
							bottomLeft = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
						elseif angle >= 270 and angle < 360 then
							topLeft = {masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
							topRight = {masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
							bottomRight = {masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
							bottomLeft = {masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
						end
						local leftBound, topBound, rightBound, bottomBound
						if topLeft[1] < bottomLeft[1] then
							leftBound = topLeft[1]
						else
							leftBound = bottomLeft[1]
						end
						if topLeft[2] < topRight[2] then
							topBound = topLeft[2]
						else
							topBound = topRight[2]
						end
						if topRight[1] > bottomRight[1] then
							rightBound = topRight[1]
						else
							rightBound = bottomRight[1]
						end
						if bottomRight[2] > bottomLeft[2] then
							bottomBound = bottomRight[2]
						else
							bottomBound = bottomLeft[2]
						end			
						local leftConstraint, topConstraint, rightConstraint, bottomConstraint
						if constrainLeft[layer] then
							leftConstraint = constrainLeft[layer] + (cameraX - leftBound)
						end
						if constrainTop[layer] then
							topConstraint = constrainTop[layer] + (cameraY - topBound)
						end
						if constrainRight[layer] then
							rightConstraint = constrainRight[layer] - (rightBound - cameraX)
						end
						if constrainBottom[layer] then
							bottomConstraint = constrainBottom[layer] - (bottomBound - cameraY)
						end				
						if (leftConstraint and rightConstraint) and (leftConstraint > rightConstraint) then
							local temp = (leftConstraint + rightConstraint) / 2
							leftConstraint = temp
							rightConstraint = temp
						end
						if (topConstraint and bottomConstraint) and (topConstraint > bottomConstraint) then
							local temp = (topConstraint + bottomConstraint) / 2
							topConstraint = temp
							bottomConstraint = temp
						end			
						local velX, velY = 0, 0
						if leftConstraint then
							if cameraX < leftConstraint then
								velX = (leftConstraint - cameraX)
							end
						end
						if rightConstraint then
							if cameraX > rightConstraint then
								velX = (rightConstraint - cameraX)
							end
						end
						if topConstraint then
							if cameraY < topConstraint then
								velY = (topConstraint - cameraY)
							end
						end
						if bottomConstraint then
							if cameraY > bottomConstraint then
								velY = (bottomConstraint - cameraY)
							end
						end
						override[layer] = true
						M.cancelCameraMove(layer)
						M.moveCameraTo({levelPosX = cameraX + velX, levelPosY = cameraY + velY, time = time, easing = easing, layer = layer})
						return constrainLeft, constrainTop, constrainRight, constrainBottom
					end
				end
			end
		end
	end
	
	M.removeCameraConstraints = function(layer)
		if layer then
			constrainLeft[layer] = nil
			constrainTop[layer] = nil
			constrainRight[layer] = nil
			constrainBottom[layer] = nil
			masterGroup[layer].vars.constrainLayer = nil
		else
			for i = 1, #map.layers, 1 do
				constrainLeft[i] = nil
				constrainTop[i] = nil
				constrainRight[i] = nil
				constrainBottom[i] = nil
			end
		end
	end
	
	M.alignParallaxLayer = function(layer, xAlign, yAlign)
		if map.layers[layer].parallaxX ~= 1 or map.layers[layer].parallaxY ~= 1 or map.layers[layer].toggleParallax == true then
			if map.orientation == 1 then
				local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
				local cameraX, cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)
				local isoPos = M.isoUntransform2(cameraX, cameraY)
				cameraX = isoPos[1]
				cameraY = isoPos[2]
				local cameraLocX = math.ceil(cameraX / map.tilewidth)
				local cameraLocY = math.ceil(cameraY / map.tileheight)
				
				--calculate constraints
				local angle = masterGroup.rotation + masterGroup[refLayer].rotation
				while angle >= 360 do
					angle = angle - 360
				end
				while angle < 0 do
					angle = angle + 360
				end				
				local topLeftT, topRightT, bottomRightT, bottomLeftT
				topLeftT = {masterGroup.parent:localToContent(screenLeft, screenTop)}
				topRightT = {masterGroup.parent:localToContent(screenRight, screenTop)}
				bottomRightT = {masterGroup.parent:localToContent(screenRight, screenBottom)}
				bottomLeftT = {masterGroup.parent:localToContent(screenLeft, screenBottom)}				
				local topLeft, topRight, bottomRight, bottomLeft
				if angle >= 0 and angle < 90 then
					topLeft = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
					topRight = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
					bottomRight = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
					bottomLeft = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
				elseif angle >= 90 and angle < 180 then
					topLeft = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
					topRight = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
					bottomRight = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
					bottomLeft = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
				elseif angle >= 180 and angle < 270 then
					topLeft = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
					topRight = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
					bottomRight = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
					bottomLeft = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
				elseif angle >= 270 and angle < 360 then
					topLeft = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
					topRight = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
					bottomRight = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
					bottomLeft = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
				end
				local topLeftT, topRightT, bottomRightT, bottomLeftT = nil, nil, nil, nil
				topLeftT = M.isoUntransform2(topLeft[1], topLeft[2])
				topRightT = M.isoUntransform2(topRight[1], topRight[2])
				bottomRightT = M.isoUntransform2(bottomRight[1], bottomRight[2])
				bottomLeftT = M.isoUntransform2(bottomLeft[1], bottomLeft[2])				
				local left, top, right, bottom
				left = topLeftT[1] - (map.tilewidth / 2)
				top = topRightT[2] - (map.tileheight / 2)
				right = bottomRightT[1] - (map.tilewidth / 2)
				bottom = bottomLeftT[2] - (map.tileheight / 2)				
				local leftConstraint, topConstraint, rightConstraint, bottomConstraint
				leftConstraint = (0 - (map.locOffsetX * map.tilewidth)) + (cameraX - left)
				topConstraint = (0 - (map.locOffsetY * map.tileheight)) + (cameraY - top)
				rightConstraint = ((map.width - map.locOffsetX) * map.tilewidth) - (right - cameraX)
				bottomConstraint = ((map.height - map.locOffsetY) * map.tileheight) - (bottom - cameraY)				
				if (leftConstraint and rightConstraint) and (leftConstraint > rightConstraint) then
					local temp = (leftConstraint + rightConstraint) / 2
					leftConstraint = temp
					rightConstraint = temp
				end
				if (topConstraint and bottomConstraint) and (topConstraint > bottomConstraint) then
					local temp = (topConstraint + bottomConstraint) / 2
					topConstraint = temp
					bottomConstraint = temp
				end				
				local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
				local cameraX, cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)
				local isoPos = M.isoUntransform2(cameraX, cameraY)
				cameraX = isoPos[1]
				cameraY = isoPos[2]
				local cameraLocX = math.ceil(cameraX / map.tilewidth)
				local cameraLocY = math.ceil(cameraY / map.tileheight)
				local xA = xAlign or "center"
				local yA = yAlign or "center"	
				masterGroup[layer].vars.alignment = {xA, yA}
				local levelPosX, levelPosY
				if xA == "center" then
					local adjustment1 = (((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5)) * map.layers[layer].properties.scaleX) - ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))
					local adjustment2 = (cameraX - ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))) - ((cameraX - ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))) * map.layers[layer].parallaxX)
					levelPosX = ((cameraX + adjustment1) - adjustment2)
				elseif xA == "left" then
					local adjustment = (cameraX - leftConstraint) - ((cameraX - leftConstraint) * map.layers[layer].parallaxX)
					levelPosX = (cameraX - adjustment)
				elseif xA == "right" then
					local adjustment1 = (((map.width - map.locOffsetX) * map.tilewidth) * map.layers[layer].properties.scaleX) - ((map.width - map.locOffsetX) * map.tilewidth)
					local adjustment2 = (cameraX - rightConstraint) - ((cameraX - rightConstraint) * map.layers[layer].parallaxX)
					levelPosX = ((cameraX + adjustment1) - adjustment2)
				end
				
				if yA == "center" then
					local adjustment1 = (((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5)) * map.layers[layer].properties.scaleY) - ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))
					local adjustment2 = (cameraY - ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))) - ((cameraY - ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))) * map.layers[layer].parallaxY)
					levelPosY = ((cameraY + adjustment1) - adjustment2)
				elseif yA == "top" then
					local adjustment = (cameraY - topConstraint) - ((cameraY - topConstraint) * map.layers[layer].parallaxY)
					levelPosY = (cameraY - adjustment)
				elseif yA == "bottom" then
					local adjustment1 = (((map.height - map.locOffsetY) * map.tileheight) * map.layers[layer].properties.scaleY) - ((map.height - map.locOffsetY) * map.tileheight)
					local adjustment2 = (cameraY - bottomConstraint) - ((cameraY - bottomConstraint) * map.layers[layer].parallaxY)
					levelPosY = ((cameraY + adjustment1) - adjustment2)
				end					
				local deltaX = levelPosX + ((map.tilewidth / 2 * map.layers[layer].properties.scaleX) - (map.tilewidth / 2)) - cameraX * map.layers[layer].properties.scaleX
				local deltaY = levelPosY + ((map.tileheight / 2 * map.layers[layer].properties.scaleY) - (map.tileheight / 2)) - cameraY * map.layers[layer].properties.scaleY	
				local isoVector = M.isoVector(deltaX, deltaY)				
				masterGroup[layer].x = (masterGroup[refLayer].x * map.layers[layer].properties.scaleX) - isoVector[1]
				masterGroup[layer].y = (masterGroup[refLayer].y * map.layers[layer].properties.scaleY) - isoVector[2]	
			else
				local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
				local cameraX, cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)
				local cameraLocX = math.ceil(cameraX / map.tilewidth)
				local cameraLocY = math.ceil(cameraY / map.tileheight)
				
				--calculate constraints
				local angle = masterGroup.rotation + masterGroup[refLayer].rotation
				while angle >= 360 do
					angle = angle - 360
				end
				while angle < 0 do
					angle = angle + 360
				end				
				local topLeftT, topRightT, bottomRightT, bottomLeftT
				topLeftT = {masterGroup.parent:localToContent(screenLeft, screenTop)}
				topRightT = {masterGroup.parent:localToContent(screenRight, screenTop)}
				bottomRightT = {masterGroup.parent:localToContent(screenRight, screenBottom)}
				bottomLeftT = {masterGroup.parent:localToContent(screenLeft, screenBottom)}				
				local topLeft, topRight, bottomRight, bottomLeft
				if angle >= 0 and angle < 90 then
					topLeft = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
					topRight = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
					bottomRight = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
					bottomLeft = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
				elseif angle >= 90 and angle < 180 then
					topLeft = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
					topRight = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
					bottomRight = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
					bottomLeft = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
				elseif angle >= 180 and angle < 270 then
					topLeft = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
					topRight = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
					bottomRight = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
					bottomLeft = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
				elseif angle >= 270 and angle < 360 then
					topLeft = {masterGroup[refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
					topRight = {masterGroup[refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
					bottomRight = {masterGroup[refLayer]:contentToLocal(topRightT[1], topRightT[2])}
					bottomLeft = {masterGroup[refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
				end				
				local left, top, right, bottom
				if topLeft[1] < bottomLeft[1] then
					left = topLeft[1]
				else
					left = bottomLeft[1]
				end
				if topLeft[2] < topRight[2] then
					top = topLeft[2]
				else
					top = topRight[2]
				end
				if topRight[1] > bottomRight[1] then
					right = topRight[1]
				else
					right = bottomRight[1]
				end
				if bottomRight[2] > bottomLeft[2] then
					bottom = bottomRight[2]
				else
					bottom = bottomLeft[2]
				end			
				local leftConstraint, topConstraint, rightConstraint, bottomConstraint
				leftConstraint = (0 - (map.locOffsetX * map.tilewidth)) + (cameraX - left)
				topConstraint = (0 - (map.locOffsetY * map.tileheight)) + (cameraY - top)
				rightConstraint = ((map.width - map.locOffsetX) * map.tilewidth) - (right - cameraX)
				bottomConstraint = ((map.height - map.locOffsetY) * map.tileheight) - (bottom - cameraY)				
				if (leftConstraint and rightConstraint) and (leftConstraint > rightConstraint) then
					local temp = (leftConstraint + rightConstraint) / 2
					leftConstraint = temp
					rightConstraint = temp
				end
				if (topConstraint and bottomConstraint) and (topConstraint > bottomConstraint) then
					local temp = (topConstraint + bottomConstraint) / 2
					topConstraint = temp
					bottomConstraint = temp
				end
				local xA = xAlign or "center"
				local yA = yAlign or "center"
				masterGroup[layer].vars.alignment = {xA, yA}
				--[[
				local destinationX, destinationY = masterGroup[layer].x * -1, masterGroup[layer].y * -1
				if xA == "center" then
					local adjustment1 = (((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5)) * map.layers[layer].properties.scaleX) - ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))
					local adjustment2 = (cameraX - ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))) - ((cameraX - ((map.width * map.tilewidth * 0.5) - (map.locOffsetX * map.tilewidth * 0.5))) * map.layers[layer].parallaxX)
					destinationX = ((cameraX + adjustment1) - adjustment2)
				elseif xA == "left" then
					local adjustment = (cameraX - leftConstraint) - ((cameraX - leftConstraint) * map.layers[layer].parallaxX)
					destinationX = (cameraX - adjustment)
				elseif xA == "right" then
					local adjustment1 = (((map.width - map.locOffsetX) * map.tilewidth) * map.layers[layer].properties.scaleX) - ((map.width - map.locOffsetX) * map.tilewidth)
					local adjustment2 = (cameraX - rightConstraint) - ((cameraX - rightConstraint) * map.layers[layer].parallaxX)
					destinationX = ((cameraX + adjustment1) - adjustment2)
				end				
				if yA == "center" then
					local adjustment1 = (((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5)) * map.layers[layer].properties.scaleY) - ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))
					local adjustment2 = (cameraY - ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))) - ((cameraY - ((map.height * map.tileheight * 0.5) - (map.locOffsetY * map.tileheight * 0.5))) * map.layers[layer].parallaxY)
					destinationY = ((cameraY + adjustment1) - adjustment2)
				elseif yA == "top" then
					local adjustment = (cameraY - topConstraint) - ((cameraY - topConstraint) * map.layers[layer].parallaxY)
					destinationY = (cameraY - adjustment)
				elseif yA == "bottom" then
					local adjustment1 = (((map.height - map.locOffsetY) * map.tileheight) * map.layers[layer].properties.scaleY) - ((map.height - map.locOffsetY) * map.tileheight)
					local adjustment2 = (cameraY - bottomConstraint) - ((cameraY - bottomConstraint) * map.layers[layer].parallaxY)
					destinationY = ((cameraY + adjustment1) - adjustment2)
				end				
				M.moveCameraTo({levelPosX = destinationX, levelPosY = destinationY, time = 1, layer = layer, disableParallax = true})
				]]--
			end
		end
	end

	M.getCamera = function(layer)
		if map.orientation == 1 then
			if layer then
				local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
				local cameraX, cameraY = masterGroup[layer]:contentToLocal(tempX, tempY)
				local isoPos = M.isoUntransform2(cameraX, cameraY)
				cameraX = isoPos[1]
				cameraY = isoPos[2]
				local cameraLocX = math.ceil(cameraX / map.tilewidth)
				local cameraLocY = math.ceil(cameraY / map.tileheight)
				return {levelPosX = cameraX, 
						levelPosY = cameraY, 
						locX = cameraLocX, 
						locY = cameraLocY}
			else
				local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
				M.cameraX, M.cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)
				local isoPos = M.isoUntransform2(M.cameraX, M.cameraY)
				M.cameraX = isoPos[1]
				M.cameraY = isoPos[2]
				M.cameraLocX = math.ceil(M.cameraX / map.tilewidth)
				M.cameraLocY = math.ceil(M.cameraY / map.tileheight)
				return {levelPosX = M.cameraX, 
						levelPosY = M.cameraY, 
						locX = M.cameraLocX, 
						locY = M.cameraLocY}
			end
		else
			if layer then
				local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
				local cameraX, cameraY = masterGroup[layer]:contentToLocal(tempX, tempY)
				local cameraLocX = math.ceil(cameraX / map.tilewidth)
				local cameraLocY = math.ceil(cameraY / map.tileheight)
				return {levelPosX = cameraX, 
						levelPosY = cameraY, 
						locX = cameraLocX, 
						locY = cameraLocY}
			else
				local tempX, tempY = masterGroup.parent:localToContent(screenCenterX, screenCenterY)
				M.cameraX, M.cameraY = masterGroup[refLayer]:contentToLocal(tempX, tempY)
				M.cameraLocX = math.ceil(M.cameraX / map.tilewidth)
				M.cameraLocY = math.ceil(M.cameraY / map.tileheight)
				return {levelPosX = M.cameraX, 
						levelPosY = M.cameraY, 
						locX = M.cameraLocX, 
						locY = M.cameraLocY}
			end
		end
	end
 
	M.fadeTile = function(locX, locY, layer, alpha, time, easing)
		if not locX or not locY or not layer then
			print("ERROR: Please specify locX, locY, and layer.")
		end
		if not alpha and not time then
			local tile = getTileObj(locX, locY, layer)
			if fadingTiles[tile] then
				return true
			end
		else
			local tile = getTileObj(locX, locY, layer)
			local currentAlpha = tile.alpha
			local distance = currentAlpha - alpha
			time = math.ceil(time / frameTime)
			if not time or time < 1 then
				time = 1
			end
			tile.deltaFade = {}
			tile.deltaFade = easingHelper(distance, time, easing)
			tile.tempAlpha = currentAlpha
			fadingTiles[tile] = tile
		end
	end

	M.fadeLayer = function(layer, alpha, time, easing)
		if not layer then
			print("ERROR: No layer specified. Defaulting to layer "..refLayer..".")
			layer = refLayer
		end
		if not alpha and not time then
			if masterGroup[layer].vars.deltaFade then
				return true
			end
		else
			local currentAlpha = masterGroup[layer].vars.alpha
			local distance = currentAlpha - alpha
			time = math.ceil(time / frameTime)
			if not time or time < 1 then
				time = 1
			end
			masterGroup[layer].vars.deltaFade = {}
			masterGroup[layer].vars.deltaFade = easingHelper(distance, time, easing)
			masterGroup[layer].vars.tempAlpha = currentAlpha
		end
	end

	M.fadeLevel = function(level, alpha, time, easing)
		if not level then
			print("ERROR: No level specified. Defaulting to level 1.")
			level = 1
		end
		if not alpha and not time then
			for i = 1, #map.layers, 1 do
				if map.layers[i].properties.level == level then
					if masterGroup[i].vars.deltaFade then
						return true
					end
				end
			end
		else
			for i = 1, #map.layers, 1 do
				if map.layers[i].properties.level == level then
					M.fadeLayer(i, alpha, time, easing)
				end
			end
		end
	end

	M.fadeMap = function(alpha, time, easing)
		if not alpha and not time then
			for i = 1, #map.layers, 1 do
				if masterGroup[i].vars.deltaFade then
					return true
				end
			end
		else
			for i = 1, #map.layers, 1 do
				M.fadeLayer(i, alpha, time, easing)
			end
		end
	end

	M.tintTile = function(locX, locY, layer, color, time, easing)
		if not locX or not locY or not layer then
			print("ERROR: Please specify locX, locY, and layer.")
		end
		if not color and not time then
			local tile = getTileObj(locX, locY, layer)
			if tintingTiles[tile] then
				return true
			end
		else
			local tile = getTileObj(locX, locY, layer)
			if not tile.currentColor then
				tile.currentColor = {map.layers[layer].redLight, 
					map.layers[layer].greenLight, 
					map.layers[layer].blueLight
				}
			end
			local distanceR = tile.currentColor[1] - color[1]
			local distanceG = tile.currentColor[2] - color[2]
			local distanceB = tile.currentColor[3] - color[3]
			time = math.ceil(time / frameTime)
			if not time or time < 1 then
				time = 1
			end
			local deltaR = easingHelper(distanceR, time, easing)
			local deltaG = easingHelper(distanceG, time, easing)
			local deltaB = easingHelper(distanceB, time, easing)
			tile.deltaTint = {deltaR, deltaG, deltaB}
			tintingTiles[tile] = tile
		end
	end
	
	M.tintLayer = function(layer, color, time, easing)
		if not layer then
			print("ERROR: No layer specificed. Defaulting to layer "..refLayer..".")
			layer = refLayer
		end
		if not color and not time then
			if masterGroup[layer].vars.deltaTint then
				return true
			end
		else
			local distanceR = map.layers[layer].redLight - color[1]
			local distanceG = map.layers[layer].greenLight - color[2]
			local distanceB = map.layers[layer].blueLight - color[3]
			time = math.ceil(time / frameTime)
			if not time or time < 1 then
				time = 1
			end
			local deltaR = easingHelper(distanceR, time, easing)
			local deltaG = easingHelper(distanceG, time, easing)
			local deltaB = easingHelper(distanceB, time, easing)
			masterGroup[layer].vars.deltaTint = {deltaR, deltaG, deltaB}
		end
	end

	M.tintLevel = function(level, color, time, easing)
		if not level then
			print("ERROR: No level specified. Defaulting to level 1.")
			level = 1
		end
		if not color and not time then
			for i = 1, #map.layers, 1 do
				if map.layers[i].properties.level == level then
					if masterGroup[i].vars.deltaTint then
						return true
					end
				end
			end
		else
			for i = 1, #map.layers, 1 do
				if map.layers[i].properties.level == level then
					M.tintLayer(i, color, time, easing)
				end
			end
		end
	end
	
	M.tintMap = function(color, time, easing)
		if not color and not time then
			for i = 1, #map.layers, 1 do
				if masterGroup[i].vars.deltaTint then
					return true
				end
			end
		else
			for i = 1, #map.layers, 1 do
				M.tintLayer(i, color, time, easing)
			end
		end
	end
	
	M.zoom = function(scale, time, easing)
		if not scale and not time then
			if deltaZoom then
				return true
			end
		else
			currentScale = masterGroup.xScale
			local distance = currentScale - scale
			time = math.ceil(time / frameTime)
			if not time or time < 1 then
				time = 1
			end
			local delta = easingHelper(distance, time, easing)
			deltaZoom = delta
		end
	end
	
	M.cleanup = function(unload)
		if touchScroll[1] or pinchZoom then
			masterGroup:removeEventListener("touch", touchScrollPinchZoom)
		end
	
		if unload then
			mapStorage[source] = nil
		end		
		for key,value in pairs(sprites) do
			removeSprite(value)
		end
		tileSets = {}	
			
		--DESTROY GROUPS
		if map.orientation == 1 then
			if M.isoSort == 1 then
				for i = masterGroup.numChildren, 1, -1 do
					for j = map.height + map.width, 1, -1 do
						if masterGroup[i][j][1].tiles then
							for k = masterGroup[i][j][1].numChildren, 1, -1 do
								local locX = masterGroup[i][j][1][k].locX
								local locY = masterGroup[i][j][1][k].locY
								tileObjects[i][locX][locY]:removeSelf()
								tileObjects[i][locX][locY] = nil
							end
						end
						masterGroup[i][j]:removeSelf()
						masterGroup[i][j] = nil
					end
					masterGroup[i]:removeSelf()
					masterGroup[i] = nil
				end
			end
		else
			for i = masterGroup.numChildren, 1, -1 do
				if masterGroup[i][1].tiles then
					for j = masterGroup[i][1].numChildren, 1, -1 do
						local locX = masterGroup[i][1][j].locX
						local locY = masterGroup[i][1][j].locY
						tileObjects[i][locX][locY]:removeSelf()
						tileObjects[i][locX][locY] = nil
					end
				end
				for j = masterGroup[i].numChildren, 1, -1 do
					if masterGroup[i][j].isDepthBuffer then
						for k = masterGroup[i][j].numChildren, 1, -1 do
							for m = masterGroup[i][j][k].numChildren, 1, -1 do
								masterGroup[i][j][k][m]:removeSelf()
								masterGroup[i][j][k][m] = nil
							end
							masterGroup[i][j][k]:removeSelf()
							masterGroup[i][j][k] = nil
						end
					end
					masterGroup[i][j]:removeSelf()
					masterGroup[i][j] = nil
				end
				masterGroup[i]:removeSelf()
				masterGroup[i] = nil
			end
		end	
		masterGroup:removeSelf()
		masterGroup = nil
		map = {}
		map.width = nil
		map.height = nil
		objects = {}
		spriteLayers = {}
		enableFlipRotation = false
		holdSprite = nil
				
		--RESET CAMERA POSITION VARIABLES
		cameraX = {}
		cameraY = {}
		cameraLocX = {}
		cameraLocY = {}
		prevLocX = {}
		prevLocY = {}
		constrainTop = {}
		constrainBottom = {}
		constrainLeft = {}
		constrainRight = {}
		refMove = false
		override = {}
		cameraFocus = nil	
		for key,value in pairs(animatedTiles) do
			animatedTiles[key] = nil
		end	
		for key,value in pairs(fadingTiles) do
			fadingTiles[key] = nil
		end	
		for key,value in pairs(tintingTiles) do
			tintingTiles[key] = nil
		end	
		currentScale = 1
		deltaZoom = nil
	end
	
	local prevTime = 0
	local dbTog = 0
	local dCount = 1
	local memory = "0"
	local mod
	local rectCount
	local debugX
	local debugY
	local debugLocX
	local debugLocY
	local debugVelX
	local debugVelY
	local debugAccX
	local debugAccY
	local debugLoading
	local debugMemory
	local debugFPS
	local debugText
	local frameRate
	local frameArray = {}
	local avgFrame = 1
	local lowFrame = 100
	M.debug = function(fps)
		if not fps then
			fps = display.fps
		end	
		if dbTog == 0 then
			mod = display.fps / fps
			local size = 22
			local scale = 2
			if display.viewableContentHeight < 500 then
				size = 14
				scale = 1
			end
			rectCount = display.newText("null", 50 * scale, 80 * scale, native.systemFont, size)
			debugX = display.newText("null", 50 * scale, 20 * scale, native.systemFont, size)
			debugY = display.newText("null", 50 * scale, 35 * scale, native.systemFont, size)
			debugLocX = display.newText("null", 50 * scale, 50 * scale, native.systemFont, size)
			debugLocY = display.newText("null", 50 * scale, 65 * scale, native.systemFont, size)
			debugLoading = display.newText("null", display.viewableContentWidth / 2, 10, native.systemFont, size)
			debugMemory = display.newText("null", 60 * scale, 95 * scale, native.systemFont, size)
			debugFPS = display.newText("null", 60 * scale, 110 * scale, native.systemFont, size)
			dbTog = 1		
			rectCount:setFillColor(1, 0, 0)
			debugX:setFillColor(1, 0, 0)
			debugY:setFillColor(1, 0, 0)
			debugLocX:setFillColor(1, 0, 0)
			debugLocY:setFillColor(1, 0, 0)
			debugLoading:setFillColor(1, 0, 0)
			debugMemory:setFillColor(1, 0, 0)
			debugFPS:setFillColor(1, 0, 0)
		end		
		local layer = refLayer
		local sumRects = 0
		for i = 1, #map.layers, 1 do
			if totalRects[i] then
				sumRects = sumRects + totalRects[i]
			end
		end
		if map.orientation == 1 then
			local cameraX = string.format("%g", M.cameraX)
			local cameraY = string.format("%g", M.cameraY)
			debugX.text = "cameraX: "..cameraX
			debugX:toFront()
			debugY.text = "cameraY: "..cameraY
			debugY:toFront()
			debugLocX.text = "cameraLocX: "..M.cameraLocX	
			debugLocY.text = "cameraLocY: "..M.cameraLocY
		else
			local cameraX = string.format("%g", M.cameraX)
			local cameraY = string.format("%g", M.cameraY)
			debugX.text = "cameraX: "..cameraX
			debugX:toFront()
			debugY.text = "cameraY: "..cameraY
			debugY:toFront()
			debugLocX.text = "cameraLocX: "..M.cameraLocX
			debugLocY.text = "cameraLocY: "..M.cameraLocY
		end
		debugLocX:toFront()
		debugLocY:toFront()		
		rectCount.text = "Total Tiles: "..sumRects
		rectCount:toFront()
		dCount = dCount + 1
		if dCount >= 60 / mod then
			dCount = 1
			memory = string.format("%g", collectgarbage("count") / 1000)
		end	
		debugMemory.text = "Memory: "..memory.." MB"
		debugMemory:toFront()	
		local curTime = system.getTimer()
		local dt = curTime - prevTime
		prevTime = curTime	
		local fps = math.floor(1000/dt) * mod	
		local lowDelay = 20 / mod
		if #frameArray < lowDelay then
			frameArray[#frameArray + 1] = fps
		else
			local temp = 0
			for i = 1, #frameArray, 1 do
				temp = temp + frameArray[i]	
			end
			avgFrame = temp / lowDelay
			frameArray = {}
		end	
		debugFPS.text = "FPS: "..fps.."   AVG: "..avgFrame
		debugFPS:toFront()
		debugLoading.text = debugText
		debugLoading:toFront()
	end
 	
	M.addPropertyListener = function(name, listener)
		propertyListeners[name] = true
		masterGroup:addEventListener(name, listener)
	end

	M.addObjectDrawListener = function(name, listener)
		objectDrawListeners[name] = true
		masterGroup:addEventListener(name, listener)
	end
	
	M.perlinNoise = function(parameters)
		local parameters = parameters
		if not parameters then
			parameters = {}
		end
		local width = parameters.width or map.width
		local height = parameters.height or map.height
		local freX = parameters.freqX or 0.05
		local freY = parameters.freqY or 0.05
		local amp = parameters.amp or 0.99
		local per = parameters.per or 0.65
		local oct = parameters.oct or 6
		print("Creating Perlin Noise...")
		local startTime=system.getTimer()
		local noise = {}
		if parameters.noise then
			noise = parameters.noise
			if #noise ~= width or #noise[1] ~= height then
				print("Warning(perlin): The dimensions of the noise array do not match the width and height of the output table.")
			end
		else
			for x = 1, width, 1 do
				noise[x] = {}
				for y = 1, height, 1 do
					noise[x][y] = math.random(0, 1)
				end
			end
		end		
		print("Seed Load Time(ms): "..system.getTimer() - startTime)
		local perlinData = {}
		local maxVal = 0
		local minVal = 32000
		for x = 1, width, 1 do
			perlinData[x] = {}
			for y = 1, height, 1 do			
				local freX = freX		--frequency
				local freY = freY		--frequency
				local amp = amp			--amplitude
				local per = per			--persistance
				local oct = oct			--octaves
				local finalValue = 0.0
				for k = 1, oct, 1 do
					local xx,yy
					xx = x * freX
					yy = y * freY
					local fx = floor(xx)
					local fy = floor(yy)
					local fractionX = xx - fx
					local fractionY = yy - fy
					local x1 = (fx + width) % width
					local y1 = (fy + height) % height
					local x2 = (fx + width - 1) % width
					local y2 = (fy + height - 1) % height 
					if x1 <= 0 then 
						x1 = x1 + width 
					end
					if x2 <= 0 then 
						x2 = x2 + width
					end
					if y1 <= 0 then 
						y1 = y1 + height
					end
					if y2 <= 0 then 
						y2 = y2 + height
					end			
					local finVal = 0				
					finVal = finVal + fractionX * fractionY * noise[x1][y1]
					finVal = finVal + fractionX * (1 - fractionY) * noise[x1][y2]
					finVal = finVal + (1 - fractionX) * fractionY * noise[x2][y1]
					finVal = finVal + (1 - fractionX) * (1 - fractionY) * noise[x2][y2]				
					finalValue = finalValue + finVal * amp
					freX = freX * 2.0
					freY = freY * 2.0
					amp = amp * per
				end				
				perlinData[x][y] = finalValue
				if finalValue > maxVal then
					maxVal = finalValue
				end
				if finalValue < minVal then
					minVal = finalValue
				end
			end
		end
		print("Raw Perlin Load Time(ms): "..system.getTimer() - startTime)
		
		if parameters.layer and parameters.layer.layer == "global" then
			parameters.layer.layer = 0
		end
		if parameters.heightMap and parameters.heightMap.layer == "global" then
			parameters.heightMap.layer = 0
		end
		if parameters.lighting and parameters.lighting.layer == "global" then
			parameters.lighting.layer = 0
		end		
		local perlinOutputW, perlinOutputH, perlinOutputL, perlinOutputO
		for x = 1, width, 1 do
			for y = 1, height, 1 do
				if parameters.layer then
					local perlinData = (perlinData[x][y] / maxVal) * (parameters.layer.scale or 100)
					if parameters.layer.roundResults then
						perlinData = math.round(perlinData)
					elseif parameters.layer.floorResults then
						perlinData = math.floor(perlinData)
					elseif parameters.layer.ceilResults then
						perlinData = math.ceil(perlinData)
					end
					if parameters.layer.layer == 0 then
						for i = l, #map.layers, 1 do
							if map.layers[l].world then
								perlinOutputW = map.layers[l].world
								if parameters.layer.perlinLevels then
									local perlinLevels = parameters.layer.perlinLevels
									for i = 1, #perlinLevels, 1 do
										if perlinData >= perlinLevels[i].min and perlinData < perlinLevels[i].max then
											--The value falls within this perlin level.
											if perlinLevels[i].value then
												map.layers[perlinLevels[i].layer or l].world[x][y] = perlinLevels[i].value
											elseif perlinLevels[i].masks then
												for j = 1, #perlinLevels[i].masks, 1 do
													if perlinLevels[i].masks[j].emptySpace then
														if not perlinOutputW[x][y] or perlinOutputW[x][y] == 0 then
															map.layers[perlinLevels[i].masks[j].layer or perlinLevels[i].layer or l].world[x][y] = perlinLevels[i].masks[j].value or perlinData
														end
													elseif perlinLevels[i].masks[j].anyTile then
														if perlinOutputW[x][y] and perlinOutputW[x][y] > 0 then
															map.layers[perlinLevels[i].masks[j].layer or perlinLevels[i].layer or l].world[x][y] = perlinLevels[i].masks[j].value or perlinData
														end
													elseif perlinOutputW[x][y] then
														if perlinOutputW[x][y] >= perlinLevels[i].masks[j].min and perlinOutputW[x][y] < perlinLevels[i].masks[j].max then
															map.layers[perlinLevels[i].masks[j].layer or perlinLevels[i].layer or l].world[x][y] = perlinLevels[i].masks[j].value or perlinData
														end
													end
												end
											end
										end
									end
								else
									perlinOutputW[x][y] = perlinData
								end
							end
						end
					else
						perlinOutputW = map.layers[parameters.layer.layer].world
						if parameters.layer.perlinLevels then
							local perlinLevels = parameters.layer.perlinLevels
							for i = 1, #perlinLevels, 1 do
								if perlinData >= perlinLevels[i].min and perlinData < perlinLevels[i].max then
									--The value falls within this perlin level.
									if perlinLevels[i].value then
										map.layers[perlinLevels[i].layer or parameters.layer.layer].world[x][y] = perlinLevels[i].value
									elseif perlinLevels[i].masks then
										for j = 1, #perlinLevels[i].masks, 1 do
											if perlinLevels[i].masks[j].emptySpace then
												if not perlinOutputW[x][y] or perlinOutputW[x][y] == 0 then
													map.layers[perlinLevels[i].masks[j].layer or perlinLevels[i].layer or parameters.layer.layer].world[x][y] = perlinLevels[i].masks[j].value or perlinData
												end
											elseif perlinLevels[i].masks[j].anyTile then
												if perlinOutputW[x][y] and perlinOutputW[x][y] > 0 then
													map.layers[perlinLevels[i].masks[j].layer or perlinLevels[i].layer or parameters.layer.layer].world[x][y] = perlinLevels[i].masks[j].value or perlinData
												end
											elseif perlinOutputW[x][y] then
												if perlinOutputW[x][y] >= perlinLevels[i].masks[j].min and perlinOutputW[x][y] < perlinLevels[i].masks[j].max then
													map.layers[perlinLevels[i].masks[j].layer or perlinLevels[i].layer or parameters.layer.layer].world[x][y] = perlinLevels[i].masks[j].value or perlinData
												end
											end
										end
									end
								end
							end
						else
							perlinOutputW[x][y] = perlinData
						end
					end					
					-------------------
				end
				if parameters.heightMap then
					local offset = parameters.heightMap.offset or 0
					local perlinData = ((perlinData[x][y] / maxVal) * (parameters.heightMap.scale or 1)) + offset
					if parameters.heightMap.roundResults then
						perlinData = math.round(perlinData)
					elseif parameters.heightMap.floorResults then
						perlinData = math.floor(perlinData)
					elseif parameters.heightMap.ceilResults then
						perlinData = math.ceil(perlinData)
					end
					if parameters.heightMap.layer == 0 then
						perlinOutputH = map.heightMap
						if not perlinOutputH then
							map.heightMap = {}
							for x = 1, map.width, 1 do
								map.heightMap[x - map.locOffsetX] = {}
							end
							perlinOutputH = map.heightMap
						end
					else
						perlinOutputH = map.layers[parameters.heightMap.layer].heightMap
						if not perlinOutputH then
							map.layers[parameters.heightMap.layer].heightMap = {}
							for x = 1, map.width, 1 do
								map.layers[parameters.heightMap.layer].heightMap[x - map.locOffsetX] = {}
							end
							perlinOutputH = map.layers[parameters.heightMap.layer].heightMap
						end
					end
					if parameters.heightMap.perlinLevels then
						local perlinLevels = parameters.heightMap.perlinLevels
						for i = 1, #perlinLevels, 1 do
							if perlinData >= perlinLevels[i].min and perlinData < perlinLevels[i].max then
								--The value falls within this perlin level.
								local outputTemp = perlinOutputH
								if perlinLevels[i].layer and parameters.heightMap.layer ~= 0 then
									outputTemp = map.layers[perlinLevels[i].layer].heightMap
								end
								if perlinLevels[i].value then
									outputTemp[x][y] = perlinLevels[i].value
								elseif perlinLevels[i].masks then
									for j = 1, #perlinLevels[i].masks, 1 do
										if perlinLevels[i].masks[j].layer and parameters.heightMap.layer ~= 0 then
											outputTemp = map.layers[perlinLevels[i].masks[j].layer].heightMap
										end
										if perlinLevels[i].masks[j].emptySpace then
											if not perlinOutputH[x][y] or perlinOutputH[x][y] == 0 then
												outputTemp[x][y] = perlinLevels[i].masks[j].value or perlinData
											end
										elseif perlinLevels[i].masks[j].anyTile then
											if perlinOutputH[x][y] and perlinOutputH[x][y] > 0 then
												outputTemp[x][y] = perlinLevels[i].masks[j].value or perlinData
											end
										elseif perlinOutputH[x][y] then
											if perlinOutputH[x][y] >= perlinLevels[i].masks[j].min and perlinOutputH[x][y] < perlinLevels[i].masks[j].max then
												outputTemp[x][y] = perlinLevels[i].masks[j].value or perlinData
											end
										end
									end
								else
									outputTemp[x][y] = perlinData
								end
							end
						end
					else
						perlinOutputH[x][y] = perlinData
					end
					-------------------
				end
				if parameters.lighting then
					local offset = parameters.lighting.offset or 0
					local perlinData = ((perlinData[x][y] / maxVal) * (parameters.lighting.scale or 1)) + offset
					if parameters.lighting.roundResults then
						perlinData = math.round(perlinData)
					elseif parameters.lighting.floorResults then
						perlinData = math.floor(perlinData)
					elseif parameters.lighting.ceilResults then
						perlinData = math.ceil(perlinData)
					end
					if parameters.lighting.layer == 0 then
						perlinOutputL = map.perlinLighting
						if not perlinOutputL then
							map.perlinLighting = {}
							for x = 1, map.width, 1 do
								map.perlinLighting[x - map.locOffsetX] = {}
							end
							perlinOutputL = map.perlinLighting
						end
					else
						perlinOutputL = map.layers[parameters.lighting.layer].perlinLighting
						if not perlinOutputL then
							map.layers[parameters.lighting.layer].perlinLighting = {}
							for x = 1, map.width, 1 do
								map.layers[parameters.lighting.layer].perlinLighting[x - map.locOffsetX] = {}
							end
							perlinOutputL = map.layers[parameters.lighting.layer].perlinLighting
						end
					end
					if parameters.lighting.perlinLevels then
						local perlinLevels = parameters.lighting.perlinLevels
						for i = 1, #perlinLevels, 1 do
							if perlinData >= perlinLevels[i].min and perlinData < perlinLevels[i].max then
								--The value falls within this perlin level.
								local outputTemp = perlinOutputL
								if perlinLevels[i].layer and parameters.lighting.layer ~= 0 then
									outputTemp = map.layers[perlinLevels[i].layer].perlinLighting
								end
								if perlinLevels[i].value then
									outputTemp[x][y] = perlinLevels[i].value
								elseif perlinLevels[i].masks then
									for j = 1, #perlinLevels[i].masks, 1 do
										if perlinLevels[i].masks[j].layer and parameters.lighting.layer ~= 0 then
											outputTemp = map.layers[perlinLevels[i].masks[j].layer].perlinLighting
										end
										if perlinLevels[i].masks[j].emptySpace then
											if not perlinOutputL[x][y] or perlinOutputL[x][y] == 0 then
												outputTemp[x][y] = perlinLevels[i].masks[j].value or perlinData
											end
										elseif perlinLevels[i].masks[j].anyTile then
											if perlinOutputL[x][y] and perlinOutputL[x][y] > 0 then
												outputTemp[x][y] = perlinLevels[i].masks[j].value or perlinData
											end
										elseif perlinOutputL[x][y] then
											if perlinOutputL[x][y] >= perlinLevels[i].masks[j].min and perlinOutputL[x][y] < perlinLevels[i].masks[j].max then
												outputTemp[x][y] = perlinLevels[i].masks[j].value or perlinData
											end
										end
									end
								else
									outputTemp[x][y] = perlinData
								end
							end
						end
					else
						perlinOutputL[x][y] = perlinData
					end
					-------------------
				end
				if parameters.output then
					local offset = parameters.output.offset or 0
					local perlinData = ((perlinData[x][y] / maxVal) * (parameters.output.scale or 100)) + offset
					if parameters.output.roundResults then
						perlinData = math.round(perlinData)
					elseif parameters.output.floorResults then
						perlinData = math.floor(perlinData)
					elseif parameters.output.ceilResults then
						perlinData = math.ceil(perlinData)
					end
					perlinOutputO = parameters.output.outputTable
					if not perlinOutputO then
						perlinOutputO = {}
						for x = 1, width, 1 do
							perlinOutputO[x] = {}
						end
					elseif not perlinOutputO[1] or type(perlinOutputO[1]) ~= "table" then
						for x = 1, width, 1 do
							perlinOutputO[x] = {}
						end
					end
					if parameters.output.perlinLevels then
						local perlinLevels = parameters.output.perlinLevels
						for i = 1, #perlinLevels, 1 do
							if perlinData >= perlinLevels[i].min and perlinData < perlinLevels[i].max then
								--The value falls within this perlin level.
								if perlinLevels[i].value then
									perlinOutputO[x][y] = perlinLevels[i].value
								elseif perlinLevels[i].masks then
									for j = 1, #perlinLevels[i].masks, 1 do
										if perlinLevels[i].masks[j].emptySpace then
											if not perlinOutputO[x][y] or perlinOutputO[x][y] == 0 then
												perlinOutputO[x][y] = perlinLevels[i].masks[j].value or perlinData
											end
										elseif perlinLevels[i].masks[j].anyTile then
											if perlinOutputO[x][y] and perlinOutputO[x][y] > 0 then
												perlinOutputO[x][y] = perlinLevels[i].masks[j].value or perlinData
											end
										elseif perlinOutputO[x][y] then
											if perlinOutputO[x][y] >= perlinLevels[i].masks[j].min and perlinOutputO[x][y] < perlinLevels[i].masks[j].max then
												perlinOutputO[x][y] = perlinLevels[i].masks[j].value or perlinData
											end
										end
									end
								else
									perlinOutputO[x][y] = perlinData
								end
							end
						end
					else
						perlinOutputO[x][y] = perlinData
					end
					-------------------
				end
			end
		end		
		if parameters.lighting then
			M.refresh()
		end		
		print("Total Load Time(ms): "..system.getTimer() - startTime)
		return perlinOutputO, perlinOutputW, perlinOutputH, perlinOutputL
	end
		
	M.saveMap = function(loadedMap, filePath, dir)
		if not filePath then
			if loadedMap then
				filePath = loadedMap
			else
				filePath = source
			end
		end	
		local directories = {}
		local firstIndex = 1
		for i = 1, string.len(filePath), 1 do
			if string.sub(filePath, i, i) == "/" then
				directories[#directories + 1] = string.sub(filePath, firstIndex, i - 1)
				firstIndex = i + 1
			end
		end	
		local fileName = string.sub(filePath, firstIndex, string.len(filePath))	
		local dirPath
		if dir == "Documents" or not dir then
			dirPath = system.pathForFile("", system.DocumentsDirectory)
		elseif dir == "Temporary" then
			dirPath = system.pathForFile("", system.TemporaryDirectory)
		elseif dir == "Resource" then
			dirPath = system.pathForFile("", system.ResourceDirectory)
		end	
		if #directories > 0 then
			local lfs = require "lfs"		
			for i = 1, #directories, 1 do
				lfs.chdir(dirPath)
				local exists = false
				for file in lfs.dir(dirPath) do
					if file == directories[i] then
						exists = true
						break
					end
				end
				if not exists then
					lfs.mkdir(directories[i])
				end
				dirPath = lfs.currentdir() .. "/"..directories[i]
			end		
		end
		local finalPath = dirPath.."/"..fileName	
		--[[
		for i = 1, #map.layers, 1 do
			if tileObjects[i] then
				for x = 1, map.layers[i].width, 1 do
					for y = 1, map.layers[i].height, 1 do
						updateTile2({locX = x, locY = y, layer = i, tile = -1})
					end
				end
			end
		end	
		]]--
		local jsonData
		if not loadedMap then
			jsonData = json.encode(map)
		else
			jsonData = json.encode(mapStorage[loadedMap])		
		end	
		local saveData = io.open(finalPath, "w")	
		saveData:write(jsonData)
		io.close(saveData)
		--[[
		if masterGroup[refLayer].vars.camera then
			M.refresh()
		end
		]]--
	end
	
	return M
end

return M2




































