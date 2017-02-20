-- MTE "CASTLE DEMO" ----------------------------------------------------------
display.setStatusBar( display.HiddenStatusBar )
local mte = require("MTE.mte").createMTE()
local json = require "json"
system.activate( "multitouch" )

--CREATE BACKDROP------------------------------------------------------
local backDrop = display.newRect(512, 384, 1024, 768)
backDrop:setFillColor(0.309, 0.264, 0.335)

--LOAD MAP ------------------------------------------------------------
mte.toggleWorldWrapX(true)
mte.toggleWorldWrapY(true)
mte.loadMap("map/CastleDemo.tmx")
local scale = 2
mte.setCamera({ locX = 53, locY = 40, scale = scale})

--SETUP D-PAD ------------------------------------------------------------
local controlGroup = display.newGroup()
local Dpad = display.newImageRect(controlGroup, "Dpad.png", 200, 200)
Dpad.x = 120
Dpad.y = display.viewableContentHeight - 120
Dpad:toFront()

--HIDE LEVELS ------------------------------------------------------------
local layers = mte.getLayers()
local layerObjects = mte.getLayerObj()
for i = 1, #layers, 1 do
	if not layers[i].properties.objectLayer then
	end
	if layers[i].properties.level > 2 then
		mte.fadeLayer(i, 0, 0)
	end
end

local tempS = layers[#layers].properties.scale
local tempM = (1 / 1) / tempS
mte.zoom((scale / layers[1].properties.scale) + 0.5, 0, easing.inOutQuad)

--CREATE PLAYER SPRITE ------------------------------------------------------------
local spriteSheet = graphics.newImageSheet("spriteSheet.png", {width = 32, height = 32, numFrames = 96})
local sequenceData = {		
		{name = "0", sheet = spriteSheet, frames = {85, 86}, time = 400, loopCount = 0},
		{name = "90", sheet = spriteSheet, frames = {73, 74}, time = 400, loopCount = 0},
		{name = "180", sheet = spriteSheet, frames = {49, 50}, time = 400, loopCount = 0},
		{name = "270", sheet = spriteSheet, frames = {61, 62}, time = 400, loopCount = 0}
		}
local player = display.newSprite(spriteSheet, sequenceData)
local setup = {
		kind = "sprite", 
		layer =  mte.getSpriteLayer(1), 
		locX = 53, 
		locY = 40,
		levelWidth = 32,
		levelHeight = 32,
		name = "player"
		}
mte.addSprite(player, setup)
mte.setCameraFocus(player)

-- DETECT MOVEMENT ------------------------------------------------------------
local movement = nil

local function move( event )
	if event.phase == "began" then
		display.getCurrentStage():setFocus(event.target, event.id)
		event.target.isFocus = true
	end
	if event.phase == "began" or event.phase == "moved" then
		local dirX = event.x - event.target.x
		local dirY = event.y - event.target.y	
		local angle = math.deg(math.atan(dirY/dirX))
		if dirX < 0 then
			angle = 90 + (90 - (angle * -1))
		end
		angle = angle + 90
		angle = math.round(angle / 90) * 90
		if angle == 360 then
			angle = 0
		end
		if angle % 90 ~= 0 then
			movement = nil
		else
			movement = tostring(angle)
		end
	elseif event.phase == "ended" or event.phase == "cancelled" then
		movement = nil
		display.getCurrentStage():setFocus( event.target, nil )
		event.target.isFocus = false
	end
	return true
end

--DETECT OBSTACLES ------------------------------------------------------------
local obstacle = function(level, locX, locY)
	local detect = mte.getTileProperties({level = level, locX = locX, locY = locY})
	for i = 1, #detect, 1 do
		if detect[i].properties then
			if detect[i].properties.solid and i == 1 then
				detect = "stop"
				player:pause()
				return detect
			end
		end
	end
end

local counter = 0
local toggle = 1
local moveTime = 300

local atlas = {}
atlas["0"] = {0, -1}
atlas["90"] = {1, 0}
atlas["180"] = {0, 1}
atlas["270"] = {-1, 0}
atlas["360"] = {0, -1}

--PINCH ZOOM / TOUCH SCROLL VARIABLES ----------------------------------------------------
local startX, startY, currentX, currentY, isDragging
local mapObj = mte.getMapObj()

local function gameLoop( event )
	if not player.isMoving then
		--UNCOMMENT TO RANDOMLY TINT LAYERS		
		--[[
		for i = 1, #layers, 1 do
			if not mte.tintLayer(i) then
				mte.tintLayer(i, {math.random(0, 1), math.random(0, 1), math.random(0, 1)}, moveTime, easing.linear)
			end
		end
		]]--
		
		--CHECK FOR OBJECTS
		local objects = mte.getObject({level = player.level, locX = player.locX, locY = player.locY})
		if objects then
			local locX, locY, time, gotoX, gotoY = player.locX, player.locY, 250, player.locX, player.locY
			for key,value in pairs(objects[1].properties) do
				if key == "change level" then
					mte.changeSpriteLayer(player, mte.getSpriteLayer(tonumber(value)))
					mte.zoom((scale / layers[player.layer].properties.scale) + 0.5, moveTime, easing.inOutQuad)
				end
				if key == "show level" then
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
				if key == "hide level" then
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
				if key == "show layer" then
					local layerObjects = mte.getLayerObj()
					local layers = mte.getLayers()
					for i = 1, #layers, 1 do
						if layers[i].name == value then
							mte.fadeLayer(i, 1, moveTime / 2)
						end
					end
				end
				if key == "hide layer" then
					local layerObjects = mte.getLayerObj()
					local layers = mte.getLayers()
					for i = 1, #layers, 1 do
						if layers[i].name == value then
							mte.fadeLayer(i, 0, moveTime / 2)
						end
					end
				end
				if key == "move to locX" then
					if value == "random" then
						locX = player.locX + math.random(1, 3) - 2
					else
						locX = tonumber(value)
					end
				end
				if key == "move to locY" then
					if value == "random" then
						locY = player.locY + math.random(1, 3) - 2
					else
						locY = tonumber(value)
					end
				end
				if key == "teleport to locX" then
					gotoX = tonumber(value)
				end
				if key == "teleport to locY" then
					gotoY = tonumber(value)
				end
			end
			if math.abs(locX - player.locX) > 3 or math.abs(locY - player.locY) > 3 then
				time = 500
			end
			if locX ~= player.locX or locY ~= player.locY then
				mte.moveSpriteTo({sprite = player, locX = locX, locY = locY, time = time, transition = easing.inOutQuad})
			end
			if gotoX ~= player.locX or gotoY ~= player.locY then
				mte.sendSpriteTo({sprite = player, locX = gotoX, locY = gotoY})
				mte.setCamera({locX = gotoX, locY = gotoY})
			end
		end
		
		--MOVE PLAYER CHARACTER
		if movement then
			local xTile, yTile = player.locX + atlas[movement][1], player.locY + atlas[movement][2]
			local result = obstacle( player.level, xTile, yTile )
			if not result then
				if player.sequence ~= movement then
					player:setSequence( movement )
				end
				player:play()
				mte.moveSpriteTo( { sprite = player, locX = xTile, locY = yTile, time = moveTime, transition = easing.linear } )
			end
		else
			player:pause()
		end
	end
	
	--Uncomment code block at line 341 to enable pinch zoom / touch scroll
	if isDragging then
		local velX = (startX - currentX) / mapObj.xScale
		local velY = (startY - currentY) / mapObj.yScale
		
		--print(velX, velY)
		mte.moveCamera(velX, velY)
		startX = currentX
		startY = currentY	
	end	
	
	collectgarbage("step", 20)
	
	mte.debug()
	mte.update()
end

Dpad:addEventListener("touch", move)
Runtime:addEventListener("enterFrame", gameLoop)

--UNCOMMENT TO TEST CONVERT FUNCTIONS
--[[
local screenTouch = function(event)
	if event.phase ~= "ended" then
		local layer = 1				
		local levelFromScreenX, levelFromScreenY = mte.screenToLevelPos(event.x, event.y, layer)
		local locFromScreenX, locFromScreenY = mte.screenToLoc(event.x, event.y, layer)		
		local screenFromLevelX, screenFromLevelY = mte.levelToScreenPos(levelFromScreenX, levelFromScreenY, layer)
		local locFromLevelX, locFromLevelY = mte.levelToLoc(levelFromScreenX, levelFromScreenY)		
		local levelFromLocX, levelFromLocY = mte.locToLevelPos(locFromScreenX, locFromScreenY)
		local screenFromLocX, screenFromLocY = mte.locToScreenPos(locFromScreenX, locFromScreenY, layer)
		print("=======================================================")
		print(" ")
		print("Screen Position (click event): "..event.x.." "..event.y)
		print(" ")
		print("Screen Position (location): "..screenFromLocX.." "..screenFromLocY)
		print("Screen Position (level position): "..screenFromLevelX.." "..screenFromLevelY)
		print(" ")
		print("Level Position (screen position): "..levelFromScreenX.." "..levelFromScreenY)
		print("Level Position (location): "..levelFromLocX.." "..levelFromLocY)
		print(" ")
		print("Location (screen position): "..locFromScreenX.." "..locFromScreenY)
		print("Location (level position): "..locFromLevelX.." "..locFromLevelY)
		print(" ")		
	end
end
Runtime:addEventListener("touch", screenTouch)
]]--

--UNCOMMENT TO TEST PINCH ZOOM / TOUCH SCROLL
--[[
mte.maxZoom = 4
mte.minZoom = 1
mte.enableTouchScroll()
mte.enablePinchZoom()

local mteScrollZoom = function(event)
	print(event.name, event.phase, event.id, event.levelPosX, event.levelPosY, event.locX, event.locY, event.numTotalTouches, event.previousTouches)
end

Runtime:addEventListener("mteTouchScrollPinchZoom", mteScrollZoom)
]]--