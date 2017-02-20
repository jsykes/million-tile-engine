display.setStatusBar( display.HiddenStatusBar )
system.activate("multitouch")
local mte = require("MTE.mte").createMTE()

mte.toggleWorldWrapX(true)
mte.toggleWorldWrapY(true)
mte.enableHeightMaps()
local map = mte.loadMap("map/sledge.tmx")
local locX, locY = 200, 200
local mapObj = mte.setCamera({locX = locX, locY = locY, scale = 2.5, overDraw = 0})

--CREATE WORLD -------------------------------------------------------------------------
local layer = {layer = 1,
		scale = 6,
		roundResults = true,
		perlinLevels = {{min = 0, max = 1, value = 38},
						{min = 1, max = 2, value = 38},
						{min = 2, max = 3, value = 38},
						{min = 3, max = 4, value = 38},
						{min = 4, max = 5, value = 71},
						{min = 5, max = 7, value = 374}
						}
	    }
	    
local heightMap = {layer = "global",
		scale = 1,
		offset = 0
		}
		
local lighting = {layer = 1, 
		scale = 1,
		offset = 0.35
		}

mte.perlinNoise({freqX = 0.07, freqY = 0.07, oct = 4, layer = layer, heightMap = heightMap, lighting = lighting})
mte.refresh()

--CREATE PLAYER SPRITE / SHADOW -------------------------------------------------------
local shadow = display.newImageRect("shadow.png", 75, 75)
shadow.alpha = 0.5
local setup = {layer = 1, kind = "imageRect", locX = locX, locY = locY, 
	levelWidth = 75, levelHeight = 75, offsetX = 0, offsetY = 0, followHeightMap = true
}	
mte.addSprite(shadow, setup)

local player = display.newImageRect("player.png", 32, 64)
local setup = {layer = 1, kind = "imageRect", locX = locX, locY = locY, 
	levelWidth = 32, levelHeight = 64, offsetX = 0, offsetY = 0
}	
mte.addSprite(player, setup)
mte.setCameraFocus(player)

--SETUP CONTROLS ----------------------------------------------------------------------
local Dpad = display.newImageRect("Dpad.png", 240, 240)
Dpad.x = 140
Dpad.y = display.viewableContentHeight - 140
Dpad.alpha = 0.7
Dpad:toFront()
local Gas = display.newRect(display.viewableContentWidth - 150, display.viewableContentHeight - 150, 125, 125)
Gas.alpha = 0.6

--MOVEMENT VARIABLES ------------------------------------------------------------------
local gravity = 0.002
local groundSpeed = 0
local acceleration = 0
local angularVelocity = 0
local angle = 0

--STEER TOUCH FUNCTION----------------------------------------------------------------
local steer = function(event)
	if event.phase == "began" then
		display.getCurrentStage():setFocus(event.target, event.id)
		event.target.isFocus = true
	end
	if event.phase == "began" or event.phase == "moved" then
		if event.x < event.target.x then
			angularVelocity = 2
		end
		if event.x > event.target.x then
			angularVelocity = -2
		end
	end
	if event.phase == "ended" or event.phase == "cancelled" then
		display.getCurrentStage():setFocus( event.target, nil )
		event.target.isFocus = false
		angularVelocity = 0
	end
	return true
end

Dpad:addEventListener("touch", steer)

--ACCELERATE TOUCH FUNCTION-------------------------------------------------------------
local accelerate = function(event)
	if event.phase == "began" then
		display.getCurrentStage():setFocus(event.target, event.id)
		event.target.isFocus = true
		acceleration = 0.12
	end
	if event.phase == "ended" or event.phase == "cancelled" then
		display.getCurrentStage():setFocus( event.target, nil )
		event.target.isFocus = false
		acceleration = 0
	end
	return true
end

Gas:addEventListener("touch", accelerate)

--ENTERFRAME----------------------------------------------------------------------------
local gameLoop = function(event)
	--Calculate ground speed
	groundSpeed = groundSpeed + acceleration
	if groundSpeed > 20 then
		groundSpeed = 20
	end
	if groundSpeed > 0 and acceleration == 0 then
		groundSpeed = groundSpeed - 0.15
	end
	if groundSpeed < 0 then
		groundSpeed = 0
	end
	
	--Apply angle
	angle = angle + angularVelocity
	mapObj.rotation = angle
	player.rotation = angle * -1
	shadow.rotation = angle * -1
	
	--Calculate movement vector of player and shadow sprites
	local velX = math.sin(math.rad(angle)) * (groundSpeed * -1)
	local velY = math.cos(math.rad(angle)) * (groundSpeed * -1)
	shadow:translate(velX, velY)
	player:translate(velX, velY)
	
	--Calculate apparent size of player sprite
	--[[
		The shadow sprite is assigned to follow the heightMap up in it's setup table.
	The followHeightMap parameters controls this behavior. However, we want our player
	sprite to soar through the air a little after going over steep bumps in the terrain,
	so we calculate this ourselves in the code below. 
	]]--
	if not player.nativeWidth then
		player.nativeWidth = player.width
		player.nativeHeight = player.height
	end							
	local mH
	if map.heightMap then
		mH = map.heightMap
	else
		mH = map.layers[i].heightMap
	end							
	local offsetX = player.nativeWidth / 2 
	local offsetY = player.nativeHeight / 2 
	local x = player.x
	local y = player.y							
	local lX = player.levelPosX / map.tilewidth
	local lY = player.levelPosY / map.tileheight
	local toggleX = math.round(lX)
	local toggleY = math.round(lY)
	local locX1, locX2, locY1, locY2
	if toggleX < lX then
		locX2 = math.ceil(player.levelPosX / map.tilewidth)
		locX1 = locX2 - 1
		if locX1 < 1 then
			locX1 = #mH
		end	
	else
		locX1 = math.ceil(player.levelPosX / map.tilewidth)
		locX2 = locX1 + 1
		if locX2 > #mH then
			locX2 = 1
		end	
	end
	if toggleY < lY then
		locY2 = math.ceil(player.levelPosY / map.tileheight)
		locY1 = locY2 - 1
		if locY1 < 1 then
			locY1 = #mH[1]
		end	
	else
		locY1 = math.ceil(player.levelPosY / map.tileheight)
		locY2 = locY1 + 1
		if locY2 > #mH[1] then
			locY2 = 1
		end	
	end		
	local cameraX, cameraY = mte.cameraX, mte.cameraY
	local locX = player.locX
	local locY = player.locY							
	local tX1 = locX1 * map.tilewidth - (map.tilewidth / 2)
	local tY1 = locY1 * map.tileheight - (map.tileheight / 2)
	local tX2 = locX2 * map.tilewidth - (map.tilewidth / 2)
	local tY2 = locY2 * map.tileheight - (map.tileheight / 2)
	local area1 = (player.levelPosX - tX1) * (player.levelPosY - tY1)
	local area2 = (player.levelPosX - tX1) * (tY2 - player.levelPosY)
	local area3 = (tX2 - player.levelPosX) * (tY2 - player.levelPosY)
	local area4 = (tX2 - player.levelPosX) * (player.levelPosY - tY1)
	local area = map.tilewidth * map.tileheight							
	local height1 = mH[locX1][locY1] * ((area3) / area)
	local height2 = mH[locX1][locY2] * ((area4) / area)
	local height3 = mH[locX2][locY2] * ((area1) / area)
	local height4 = mH[locX2][locY1] * ((area2) / area)							
	local tempHeight = height1 + height2 + height3 + height4		
	
	--[[
		The tempHeight variable stores the height of the map immediately beneath the
	player sprite. If the heightMap is above the player sprite, we move the player sprite
	upwards because it is running into a hillside. If the tempHeight is below the player
	sprite we subtract only a small value from it's upward motion to simulate gravity.
	]]--
	if not player.offsetZ then
		velocityZ = 0
		player.offsetZ = tempHeight
	else
		if tempHeight > player.offsetZ then
			velocityZ = tempHeight - player.offsetZ
			player.offsetZ = tempHeight
		else
			velocityZ = velocityZ - gravity
			player.offsetZ = player.offsetZ + velocityZ
		end
	end
	if player.offsetZ > 2 then
		player.offsetZ = 2
		velocityZ = 0
	end
	
	
	--[[
		The following code alters the path of the sprite. The path has nothing to do with
	movement, rather it is the shape of the polygon representing the sprite. We're 
	distorting the polygon to make the sprite appear larger or smaller without changing
	the sprite's true position on the map or the xScale or yScale properties of the 
	sprite.
	]]--
	local oP = player.path
	oP["x1"] = (((cameraX - (x - offsetX)) * (1 + player.offsetZ)) - (cameraX - (x - offsetX))) * -1
	oP["y1"] = (((cameraY - (y - offsetY)) * (1 + player.offsetZ)) - (cameraY - (y - offsetY))) * -1
	
	oP["x2"] = (((cameraX - (x - offsetX)) * (1 + player.offsetZ)) - (cameraX - (x - offsetX))) * -1
	oP["y2"] = (((cameraY - (y + offsetY)) * (1 + player.offsetZ)) - (cameraY - (y + offsetY))) * -1
	
	oP["x3"] = (((cameraX - (x + offsetX)) * (1 + player.offsetZ)) - (cameraX - (x + offsetX))) * -1
	oP["y3"] = (((cameraY - (y + offsetY)) * (1 + player.offsetZ)) - (cameraY - (y + offsetY))) * -1
	
	oP["x4"] = (((cameraX - (x + offsetX)) * (1 + player.offsetZ)) - (cameraX - (x + offsetX))) * -1
	oP["y4"] = (((cameraY - (y - offsetY)) * (1 + player.offsetZ)) - (cameraY - (y - offsetY))) * -1		
	
	--[[
		Here we increase the transparency of the shadow the further it is from the
	underside of the sprite. That is to say, we use the difference in value between 
	the player.offsetZ and tempHeight variables to calculate the alpha of the shadow
	sprite. This helps to reinforce the sensation of terrain depth and the altitude of
	the player passing over it.
	]]--
	local shadowAlpha = 1 / (player.offsetZ / tempHeight)
	if shadowAlpha > 1 or shadowAlpha < 0 then
		shadowAlpha = 1
	end
	shadow.alpha = shadowAlpha * 0.75
	
	mapObj.xScale = 2.5 / (player.offsetZ + 1)
	mapObj.yScale = 2.5 / (player.offsetZ + 1)
	
	mte.debug()		
	mte.update()
	
	player:setFillColor(0.5 + (player.offsetZ / 2), 0.5 + (player.offsetZ / 2), 0.5 + (player.offsetZ / 2))
end

Runtime:addEventListener("enterFrame", gameLoop)
