local composer = require( "composer" )
local scene = composer.newScene()
local mte = require("MTE.mte").createMTE()
local json = require ("json")
local myData = require ("mydata")
system.activate("multitouch")

---------------------------------------------------------------------------------
-- All code outside of the listener functions will only be executed ONCE
-- unless "composer.removeScene()" is called.
---------------------------------------------------------------------------------

-- SPRITES --------------------------------------------------------------------
local player

-- DETECT MOVEMENT ------------------------------------------------------------
local movement = nil
local lastMovement = 45

-- DETECT OBSTACLES ------------------------------------------------------------
local obstacle = function(locX, locY)
	local map = mte.getMap()			
	local camera = mte.getCamera()
	local destX, destY, ascent, descent	--return values
	
	local isSlope = false
	local detectCurrent = mte.getTileProperties({layer = player.layer, locX = player.locX, locY = player.locY})
	if detectCurrent then
		if detectCurrent.slope then
			isSlope = true
		end
	end
	
	local isSolid = false
	local isSlopeNext = false
	local detectNext = mte.getTileProperties({layer = player.layer, locX = locX, locY = locY})
	if detectNext then
		if detectNext.solid then
			isSolid = true
		end
		if detectNext.slope then
			isSlopeNext = true
		end
	end
	
	local isSolidAbove = false
	local detectNext2 = mte.getTileProperties({layer = mte.getSpriteLayer(player.level + 1), locX = locX - 1, locY = locY - 1})
	if detectNext2 then
		if detectNext2.solid then
			isSolidAbove = true
		end
	end
				
	local isVoid = false
	if player.level > 1 then
		if mte.getSpriteLayer(player.level - 1) then
			if map.layers[mte.getSpriteLayer(player.level - 1)].world[locX + 1][locY + 1] == 0 then
				isVoid = true
			end
		end
	end
	
	local isDescent = false
	if player.level > 1 then
		local detectNext = mte.getTileProperties({layer = mte.getSpriteLayer(player.level - 1), locX = locX + 1, locY = locY + 1})
		if detectNext then
			if detectNext.slope then
				isDescent = true
			end
		end
	end
	
	if isSlope then				
		if isSolid then
			if not isSolidAbove then
				ascent = true
				destX = locX - 1
				destY = locY - 1
			else
				--stop
			end
		elseif isVoid then
			--stop
		elseif isDescent then
			descent = true
			destX = locX + 1
			destY = locY + 1
		elseif isSlopeNext then
			destX = locX - 0.45
			destY = locY - 0.45
		elseif not isSlopeNext then
			destX = locX
			destY = locY
		else
			destX = locX
			destY = locY
		end			
	elseif not isSlope then				
		if isSolid then
			--stop
		elseif isVoid then
			--stop
		elseif isDescent then
			descent = true
			destX = locX + 1 - 0.45
			destY = locY + 1 - 0.45
			--move = true
		elseif isSlopeNext then
			destX = locX - 0.45
			destY = locY - 0.45						
		else
			destX = locX
			destY = locY
		end				
	end
	
	return destX, destY, ascent, descent
end

-- DESCEND LEVEL -----------------------------------------------------------------
local dropLevel = function(event)
	mte.changeSpriteLayer(event.sprite, mte.getSpriteLayer(event.sprite.level - 1))
end

-- PROPERTY LISTENERS ------------------------------------------------------------
local onTint = function(event)
	local red = math.random(200,255) / 255
	local green = 1
	local blue = math.random(200,255) / 255
	event.target:setFillColor(red, green, blue)
end
local onSize = function(event)
	local xScale = math.random(50, 125) / 100
	event.target.xScale = xScale
end

local counter = 0
local toggle = 1
local moveTime = 150

local atlas = {}
atlas["0"]     	= {  -1, -1, 1, 315, 45}
atlas["45"]     = {  0, -1, 1, 0, 90}
atlas["90"]  	= {  1,  -1, 1.8, 45, 135 }
atlas["135"]  	= {  1,  0, 1, 90, 180}
atlas["180"]   	= {  1,  1, 1, 135, 225 }
atlas["225"]   	= {  0,  1, 1, 180, 270 }
atlas["270"] 	= { -1,  1, 1.8, 225, 315 }
atlas["315"] 	= { -1,  0, 1, 270, 360 }
atlas["360"] 	= { -1,  -1, 1, 45, 315 }

-- GAME LOOP --------------------------------------------------------------------
local function gameLoop( event )
	local changeMap = false
	if not player.isMoving then
		movement = myData.movement
		--CHECK FOR OBJECTS
		local objects = mte.getObject({level = player.level, locX = player.locX, locY = player.locY})

		if objects then
			for key,value in pairs(objects[1].properties) do
				if key == "level" then
					mte.changeSpriteLayer(player, mte.getSpriteLayer(tonumber(value)))
				end
				if key == "show Level" then
					local layerObjects = mte.getLayerObj()
					local layers = mte.getLayers()
					if value == "above" then
						for i = 1, #layers, 1 do
							if layers[i].properties.level > player.level then
								mte.fadeLayer(i, 1, moveTime)
							end
						end
					elseif value == "below" then
						for i = 1, #layers, 1 do
							if layers[i].properties.level < player.level then
								mte.fadeLayer(i, 1, moveTime)
							end
						end
					else
						for i = 1, #layers, 1 do
							if layers[i].properties.level == tonumber(value) then
								mte.fadeLayer(i, 1, moveTime)
							end
						end
					end
				end
				if key == "hide Level" then
					local layerObjects = mte.getLayerObj()
					local layers = mte.getLayers()
					if value == "above" then
						for i = 1, #layers, 1 do
							if layers[i].properties.level > player.level then
								mte.fadeLayer(i, 0, moveTime)
							end
						end
					elseif value == "below" then
						for i = 1, #layers, 1 do
							if layers[i].properties.level < player.level then
								mte.fadeLayer(i, 0, moveTime)
							end
						end
					else
						for i = 1, #layers, 1 do
							if layers[i].properties.level == tonumber(value) then
								mte.fadeLayer(i, 0, moveTime)
							end
						end
					end
				end
				if key == "map" then
					print(value)
					myData.prevMap = myData.nextMap
					myData.nextMap = value
					changeMap = true
				end
			end
		end
		
		--MOVE PLAYER CHARACTER
		if movement and not stopMovement then
			--find destination
			local xTile, yTile = player.locX + atlas[movement][1], player.locY + atlas[movement][2]
			local destX, destY, ascent, descent = obstacle(xTile, yTile)
			local tempMoveTime = atlas[movement][3] * moveTime
			local tempMovement = movement
			if not destX then
				--if solid ahead of hero, check 45 degrees counter-clockwise
				xTile, yTile = player.locX + atlas[tostring(atlas[movement][4])][1], player.locY + atlas[tostring(atlas[movement][4])][2]
				destX, destY, ascent, descent = obstacle(xTile, yTile)
				tempMoveTime = atlas[tostring(atlas[movement][4])][3] * moveTime
				tempMovement = tostring(atlas[movement][4])
			end
			if not destX then
				--if solid ahead and counter-clockwise, check 45 degrees clockwise
				xTile, yTile = player.locX + atlas[tostring(atlas[movement][5])][1], player.locY + atlas[tostring(atlas[movement][5])][2]
				destX, destY, ascent, descent = obstacle(xTile, yTile)
				tempMoveTime = atlas[tostring(atlas[movement][5])][3] * moveTime
				tempMovement = tostring(atlas[movement][5])
			end
			
			if destX then
				if ascent then
					mte.changeSpriteLayer(player, mte.getSpriteLayer(player.level + 1))
					mte.moveSpriteTo( { sprite = player, locX = destX, locY = destY, time = tempMoveTime * 1.2} )
				elseif descent then
					mte.moveSpriteTo( { sprite = player, locX = destX, locY = destY, time = tempMoveTime * 1.2, onComplete = dropLevel } )
				else
					mte.moveSpriteTo( { sprite = player, locX = destX, locY = destY, time = tempMoveTime} )
				end
			
				if player.sequence ~= "run"..tempMovement then
					player:setSequence( "run"..tempMovement )
				end
				player:play()
				lastMovement = movement
			end
		else
			if player.sequence ~= "stand"..lastMovement then
				player:setSequence( "stand"..lastMovement )
				player:play()
			end
		end
	end
	
	--UPDATE OR GOTO NEW MAP
	if not changeMap then
		mte.debug()
		mte.update()
	else
		composer.gotoScene("scene", {effect = "fade", time = 1000})
	end
end

---------------------------------------------------------------------------------

function scene:show(event)
	local group = self.view
	if event.phase == "will" then
		-- Called when the scene is still off screen (but is about to come on screen).
	
		-- LOAD MAP ------------------------------------------------------------
		mte.toggleWorldWrapX(false)
		mte.toggleWorldWrapY(false)
		mte.isoSort = 1
		mte.loadTileSet("tiled_cave_2", "map/tilesets/tiled_cave_2.png")
		mte.loadTileSet("iso-64x64-outside", "map/tilesets/iso-64x64-outside.png")
		mte.loadMap("map/"..myData.nextMap..".tmx")
		mte.addPropertyListener("randomTint", onTint)
		mte.addPropertyListener("randomSize", onSize)
	
		local locX, locY
		local blockScale = myData.blockScale --128
		local isoOverDraw = 1
		if myData.nextMap == "IsoMap1" then       	
			if not myData.prevMap or myData.prevMap == "IsoMap3" then
				locX, locY = 40, 72
				mte.setCamera({ locX = locX, locY = locY, blockScale = blockScale, isoOverDraw = isoOverDraw})
				lastMovement = 45
			else
				locX, locY = 13, 28
				mte.setCamera({ locX = locX, locY = locY, blockScale = blockScale, isoOverDraw = isoOverDraw})
				lastMovement = 225
			end
		elseif myData.nextMap == "IsoMap2" then
			if myData.prevMap == "IsoMap1" then
				locX, locY = 4, 49
				mte.setCamera({ locX = locX, locY = locY, blockScale = blockScale, isoOverDraw = isoOverDraw})
				lastMovement = 45
			else
				locX, locY = 47, 61
				mte.setCamera({ locX = locX, locY = locY, blockScale = blockScale, isoOverDraw = isoOverDraw})
				lastMovement = 315
			end
		elseif myData.nextMap == "IsoMap3" then
			if myData.prevMap == "IsoMap2" then
				locX, locY = 3, 30
				mte.setCamera({ locX = locX, locY = locY, blockScale = blockScale, isoOverDraw = isoOverDraw})
				lastMovement = 135
			else
				locX, locY = 56, 61
				mte.setCamera({ locX = locX, locY = locY, blockScale = blockScale, isoOverDraw = isoOverDraw})
				lastMovement = 225
			end
		end
	
		myData.controlGroup:toFront()
		
		-- CREATE PLAYER SPRITE ----------------------------------------------------
		local spriteSheet = graphics.newImageSheet("SirFudnik.png", {width = 128, height = 128, numFrames = 96})
		local sequenceData = {
				{name = "stand45", sheet = spriteSheet, frames = {37, 38, 39, 40, 39, 38}, time = 500, loopCount = 0},
				{name = "stand90", sheet = spriteSheet, frames = {49, 50, 51, 52, 51, 50}, time = 500, loopCount = 0},
				{name = "stand135", sheet = spriteSheet, frames = {61, 62, 63, 64, 63, 62}, time = 500, loopCount = 0},
				{name = "stand180", sheet = spriteSheet, frames = {73, 74, 75, 76, 75, 74}, time = 500, loopCount = 0},
				{name = "stand225", sheet = spriteSheet, frames = {85, 86, 87, 88, 87, 86}, time = 500, loopCount = 0},
				{name = "stand270", sheet = spriteSheet, frames = {1, 2, 3, 4, 3, 2}, time = 500, loopCount = 0},
				{name = "stand315", sheet = spriteSheet, frames = {13, 14, 15, 16, 15, 14}, time = 500, loopCount = 0},
				{name = "stand360", sheet = spriteSheet, frames = {25, 26, 27, 28, 27, 26}, time = 500, loopCount = 0},
				{name = "stand0", sheet = spriteSheet, frames = {25, 26, 27, 28, 27, 26}, time = 500, loopCount = 0},
	
				{name = "run45", sheet = spriteSheet, frames = {41, 42, 43, 44, 45, 46, 47, 48}, time = 500, loopCount = 0},
				{name = "run90", sheet = spriteSheet, frames = {53, 54, 55, 56, 57, 58, 59, 60}, time = 500, loopCount = 0},
				{name = "run135", sheet = spriteSheet, frames = {65, 66, 67, 68, 69, 70, 71, 72}, time = 500, loopCount = 0},
				{name = "run180", sheet = spriteSheet, frames = {77, 78, 79, 80, 81, 82, 83, 84}, time = 500, loopCount = 0},
				{name = "run225", sheet = spriteSheet, frames = {89, 90, 91, 92, 93, 94, 95, 96}, time = 500, loopCount = 0},
				{name = "run270", sheet = spriteSheet, frames = {5, 6, 7, 8, 9, 10, 11, 12}, time = 500, loopCount = 0},
				{name = "run315", sheet = spriteSheet, frames = {17, 18, 19, 20, 21, 22, 23, 24}, time = 500, loopCount = 0},
				{name = "run360", sheet = spriteSheet, frames = {29, 30, 31, 32, 33, 34, 35, 36}, time = 500, loopCount = 0},
				{name = "run0", sheet = spriteSheet, frames = {29, 30, 31, 32, 33, 34, 35, 36}, time = 500, loopCount = 0}
		}
		player = display.newSprite(spriteSheet, sequenceData)
		local setup = {
				kind = "sprite", 
				layer =  2, 
				locX = locX, 
				locY = locY,
				levelWidth = 192,
				levelHeight = 192,
				offsetY = -12,
				lighting = "on"
				}
		mte.addSprite(player, setup)
		player:play()
		mte.setCameraFocus(player)
		
		group:insert(mte.getMapObj())
	elseif event.phase == "did" then
		-- Called when the scene is now on screen.
		-- Insert code here to make the scene come alive.
		-- Example: start timers, begin animation, play audio, etc.
		
		Runtime:addEventListener("enterFrame", gameLoop)
	end
end


function scene:hide( event )
	local group = self.view
	if event.phase == "will" then
		-- Called when the scene is on screen (but is about to go off screen).
		-- Insert code here to "pause" the scene.
		-- Example: stop timers, stop animation, stop audio, etc.
		
		Runtime:removeEventListener("enterFrame", gameLoop)		
		mte.cleanup()
	end
end


---------------------------------------------------------------------------------

-- Listener setup
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )

---------------------------------------------------------------------------------

return scene