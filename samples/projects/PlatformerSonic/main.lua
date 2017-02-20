-- MTE "PLATFORMER - SONIC FINALE" -----------------------------------------------------

local abs = math.abs
local mte = MTE
local Screen = Screen
local json = require("json")

-------------------------------------------------------------------------------

local background
background = display.newRect(0, 0, Screen.FullWidth, Screen.FullHeight)
background.anchorX = 0
background.anchorY = 0
background.x = Screen.Left
background.y = Screen.Top
background:setFillColor(0.12549, 0, 0.74118)

--LOAD MAP -----------------------------------------------------------------------------
mte.toggleWorldWrapX(true)
mte.toggleWorldWrapY(true)
local map = mte.loadMap("PlatformerSonic/map/SonicFinale.tmx")
local blockScale = 175
local locX = 4
local locY = 14
local mapObj = mte.setCamera({locX = locX, locY = locY, blockScale = blockScale})

--SETUP D-PAD --------------------------------------------------------------------------
local controlGroup = display.newGroup()
local DpadBack = display.newImageRect(controlGroup, "PlatformerSonic/Dpad.png", 120, 120)
DpadBack.x = Screen.Left + DpadBack.width*0.5 + 10
DpadBack.y = Screen.Bottom - DpadBack.height*0.5 - 10
DpadBack.alpha = 0.7

local jumpBtn = display.newRect(controlGroup, display.viewableContentWidth - 150, display.viewableContentHeight - 150, 120, 120)
jumpBtn.alpha = 0.6
jumpBtn.x = DpadBack.x + DpadBack.width + 10
--jumpBtn.x = Screen.Right - jumpBtn.width*0.5 - 10
jumpBtn.y = Screen.Bottom - jumpBtn.height*0.5 - 10
DpadBack:toFront()

background:toBack()

--CREATE PLAYER SPRITE -----------------------------------------------------------------
local spriteSheet = graphics.newImageSheet("PlatformerSonic/SonicSprite2.png", {width = 64, height = 70, numFrames = 224})
local sequenceData = {
    {name = "standRight", sheet = spriteSheet, frames = {1, 2, 3, 4, 5}, time = 200, loopCount = 0},
    {name = "walkRight", sheet = spriteSheet, frames = {17, 18, 19, 20, 21, 22, 23, 24}, time = 400, loopCount = 0},
    {name = "runRight", sheet = spriteSheet, frames = {49, 50, 51, 52}, time = 200, loopCount = 0},
    {name = "jumpRight", sheet = spriteSheet, frames = {65, 66, 67, 68}, time = 300, loopCount = 0},
    {name = "standLeft", sheet = spriteSheet, frames = {16, 15, 14, 13, 12}, time = 400, loopCount = 0},
    {name = "walkLeft", sheet = spriteSheet, frames = {32, 31, 30, 29, 28, 27, 26, 25}, time = 400, loopCount = 0},
    {name = "runLeft", sheet = spriteSheet, frames = {64, 63, 62, 61}, time = 200, loopCount = 0},
    {name = "jumpLeft", sheet = spriteSheet, frames = {80, 79, 78, 77}, time = 300, loopCount = 0}
}
local player = display.newSprite(spriteSheet, sequenceData)
local setup = {layer = 5, kind = "sprite", locX = locX, locY = locY, 
    levelWidth = 64, levelHeight = 70, offsetX = 0, offsetY = 0
}
mte.addSprite(player, setup)
mte.moveCamera(0, -40) --place camera above the sprite to improve the view
mte.setCameraFocus(player)
mte.moveSprite(player, -90, 40) --move the sprite so it starts on the ground instead of in the air

--CREATE 2D POSITION AND MOVEMENT VARIABLES --------------------------------------------
local mod = 60 / display.fps
local acc = 0
local velX = 0
local velY = 0
local maxVelX = 10 * mod 
local maxVelY = 10 * mod
local gravity = 0.45 * mod * mod
local friction = 0.10 * mod * mod
local isGrounded = false
local isJumping = false

--CREATE COLLISION DETECTION COORDINATES -----------------------------------------------
--[[
	This sample has just a single collision point for detecting the ground beneath Sonic
the Hedgehog's feet. There is no wall or ceiling collision detection.
]]--
local bottomOffset = {0, 16}

--COLLISION DETECTION FUNCTION----------------------------------------------------------
local surfaces = {}		--An array containing the start and end points of a collideable surface.
local surfaceData = {}	--An array containing the actual Y values of each segment of a surface.
local prevLoc = {x = 9999, y = 9999}
local detectFloor = function(sensor, vX, vY)
    local tempVY
    local loc = {x = math.ceil(sensor[1] / map.tilewidth), y = math.ceil((sensor[2] - 0) / map.tileheight)}
    
	--[[
		Each tile is 256 x 256 pixels and contains surfaces defined in arrays. These arrays
	are stored as tile properties. Because properties imported from Tiled are stored as
	strings, we must decode the surface arrays to make use of them using json.decode.
		Json.decode is a relatively expensive operation; we don't want to call it every frame.
	Instead we test the location of the collision detection point against the past location
	of the collision detect point. If the location hasn't changed there is no need to 
	reload the tile properties and perform the expensive decode operation.
		Not all collideable surfaces are in the same map layer. The for next loop checks
	each layer for surface data and adds all surfaces into the surfaces and surfaceData
	arrays.
    ]]--
    if loc.x ~= prevLoc.x or loc.y ~= prevLoc.y then
        surfaces = {}
        surfaceData = {}
        for i = 2, 4, 1 do
            local properties = mte.getTileProperties({locX = loc.x, locY = loc.y, layer = i})
            if properties then			
                if #surfaces == 0 then
                    surfaces = json.decode(properties.surfaces)
                else
                    local temp = json.decode(properties.surfaces)
                    local length = #surfaces
                    for j = 1, #temp, 1 do
                        surfaces[length + j] = temp[j]
                    end
                end
                
                if #surfaceData == 0 then
                    surfaceData = json.decode(properties.surfaceData)
                else
                    local temp = json.decode(properties.surfaceData)
                    local length = #surfaceData
                    for j = 1, #temp, 1 do
                        surfaceData[length + j] = temp[j]
                    end
                end
            end
        end
        prevLoc.x = loc.x
        prevLoc.y = loc.y
    end
    
	--[[
		Now that the surface data is decoded and loaded into local arrays we must find
	a surface for Sonic to interact with. If the surfaces array exists, a for next loop
	calculates the precise local y value of the surface at the x value of the collision
	detect point. It stores this value as well as the rest of the temporary computation
	variables, and the index of the surface, for use in calculating how the player
	sprite responds to ground beneath it's feet.
    ]]--
    local tilePos = {loc.x * map.tilewidth - map.tilewidth, loc.y * map.tileheight - map.tileheight}
    local sensorLocal = {sensor[1] - tilePos[1], sensor[2] - tilePos[2]}
    local sensorMask = math.ceil(sensorLocal[1] / 16)						
    if surfaces then	
        local surface
        local xMask
        local xLocal
        local sD1
        local sD2
        local yLocal
        for i = 1, #surfaces, 1 do
            if sensorMask >= surfaces[i][1] and sensorMask <= surfaces[i][2] then					
                if surface then
                    local txMask = sensorMask - (surfaces[i][1] - 1)
                    local txLocal = sensorLocal[1] - ((sensorMask - 1) * 16)
                    local tsD1 = surfaceData[i][txMask]
                    local tsD2 = surfaceData[i][txMask + 1]
                    local tyLocal = ((tsD2 - tsD1) / 16) * txLocal + tsD1
                    if abs(sensorLocal[2] - tyLocal) < abs(sensorLocal[2] - yLocal) then
                        surface = i
                        xMask = txMask
                        xLocal = txLocal
                        sD1 = tsD1
                        sD2 = tsD2
                        yLocal = tyLocal
                    end
                else
                    surface = i
                    xMask = sensorMask - (surfaces[i][1] - 1)
                    xLocal = sensorLocal[1] - ((sensorMask - 1) * 16)
                    sD1 = surfaceData[i][xMask]
                    sD2 = surfaceData[i][xMask + 1]
                    yLocal = ((sD2 - sD1) / 16) * xLocal + sD1
                end
            end
        end
        
        if isGrounded == false then	
			--[[
				The boolean isGrounded is false when the sprite is falling through the air
			either after jumping or running off a platform. This section of code must
			detect when the sprite reaches the ground so that the boolean can be switched
			and the code for walking on the ground can execute.
				The code checks for a surface in two ways. 
				First, if the sprite and the collision detection point are at the same 
			location, the code checks to see if the sprite and detection point are on 
			opposite sides of the surface. If the sprite is above the surface and the 
			collision detection point is below the surface, this means that, if nothing is 
			done, the sprite will move through the floor at the end of the frame. So, the 
			code calculates the necessary y velocity to place the sprite just on top of 
			the surface, and it sets isGrounded to true.
				This code cannot execute properly if the sprite and the collision detection
			point are in two different locations on the map, or if the sprite is off the
			edge of a surface. In this case a fallback routine simply tests to see whether 
			the detection point is beneath the surface. We already know that the surface is 
			the nearest surface to the sprite, so this test is usually accurate in detecting
			a surface to land on. The code calculates the precise y velocity needed to place 
			the sprite just on top of the surface and switches isGrounded to true.
            ]]--
            if surface then
                local playerLoc = {x = math.ceil((sensor[1] - vX) / map.tilewidth), y = math.ceil((sensor[2] - vY) / map.tileheight)}
                local playerLocal = {sensor[1] - vX - tilePos[1], sensor[2] - vY - tilePos[2]}
                local playerMask = math.ceil(playerLocal[1] / 16)
                if playerLoc.x == loc.x and playerLoc.y == loc.y and playerMask >= surfaces[surface][1] and playerMask <= surfaces[surface][2] then					
                    local txMask = playerMask - (surfaces[surface][1] - 1)
                    local txLocal = playerLocal[1] - ((playerMask - 1) * 16)
                    local tsD1 = surfaceData[surface][txMask]
                    local tsD2 = surfaceData[surface][txMask + 1]
                    local tyLocal = ((tsD2 - tsD1) / 16) * txLocal + tsD1
                    if playerLocal[2] < tyLocal and sensorLocal[2] > yLocal then
                        tempVY = vY - (sensorLocal[2] - yLocal)
                        isGrounded = true
                        isJumping = false
                    end
                else
                    if sensorLocal[2] > yLocal and sensorLocal[2] - yLocal <= vY then
                        tempVY = vY - (sensorLocal[2] - yLocal)
                        isGrounded = true
                        isJumping = false
                    end
                end
            end
            
        elseif isGrounded == true then
			--[[
				The boolean isGrounded is true when the sprite is on the ground. This section
			of code is relatively simple in that it need not test for collisions with a
			surface. All it does is calculate the rotation of the sprite so that the sprite
			appears to following the slope of the terrain, and then calculate the y
			velocity necessary to keep the sprite just above the nearest surface.
				The code makes the assumption that the necessary velocity will not exceed
			30 pixels. If the necessary y velocity is greater than 30, it assumes that the
			sprite has walked off a ledge and it switches the isGrounded boolean to false.
            ]]--
            if surface then
                --CALCULATE PLAYER SPRITE ROTATION
                local temp = 90 - math.deg(math.atan(xLocal/(yLocal - sD1)))
                if abs(sD1 - sD2) > 0 then
                    if sD1 < sD2 then
                        player.rotation = temp
                    elseif sD1 > sD2 then
                        player.rotation = temp - 180
                    else
                        player.rotation = 0
                    end
                else
                    player.rotation = 0
                end
                
                --CALCULATE Y VELOCITY
                if abs(sensorLocal[2] - yLocal) < 30 then
                    tempVY = yLocal - sensorLocal[2]
                else
                    isGrounded = false
                end
            else
                isGrounded = false
            end
            
        end
    end
    return tempVY
end


--MOVEMENT TOUCH EVENT------------------------------------------------------------------
--[[
	Our Dpad event does not directly move the player sprite or even set it's velocity.
Instead we set the acceleration along the X axis. Our enterframe loop will then 
increment the velocity along the X axis by this acceleration every frame.
]]--
local move = function(event)
    if event.phase == "began" then
        display.getCurrentStage():setFocus(event.target, event.id)
        event.target.isFocus = true
    end
    if event.phase == "began" or event.phase == "moved" then
        if event.x < event.target.x then
            acc = -0.2 * mod * mod
        end
        if event.x > event.target.x then
            acc = 0.2 * mod * mod
        end
    end
    if event.phase == "ended" or event.phase == "cancelled" then
        display.getCurrentStage():setFocus( event.target, nil )
        event.target.isFocus = false
        acc = 0
    end
    return true
end


--JUMP TOUCH EVENT----------------------------------------------------------------------
--[[
	Jumping is a little different from the Dpad movement in that it sets the player's
velocity along the Y axis rather than setting an acceleration. The reason for this is 
that the acceleration along the Y axis is constant: the gravity variable we set with the
rest of the 2D movement variables.
	The function also sets the isGrounded boolean to false to let the collision detection
function no that the player sprite is airborne. It sets the isJumping boolean to true
so our code will change the player sprite's animation to one of the jumping animations.
	The enterframe event will apply gravity each frame causing an apparent acceleration
towards the floor.
]]--
local jump = function(event)
    if event.phase == "began" then
        display.getCurrentStage():setFocus(event.target, event.id)
        event.target.isFocus = true
        if isGrounded then
            velY = -10 * mod
            isGrounded = false
            isJumping = true
        end
    end
    if event.phase == "ended" or event.phase == "cancelled" then
        display.getCurrentStage():setFocus( event.target, nil )
        event.target.isFocus = false
    end
    return true
end

--ENTERFRAME----------------------------------------------------------------------------
local tempVelY
local tempVelX
local alternator = 1
local currentZoom = 1.2
local gameLoop = function(event)
    --DO NON-CRITICAL TASKS EVERY OTHER FRAME
	--[[
		Performing non-time-critical calculations every frame does not make sense. For example,
	you would want to check for floors every frame because you need fine control of the
	player sprite when it lands. However changing the sprite animation is less critical,
	because players likely wouldn't notice a 0.016 second delay in switching from one animation
	to another. Similarly, we do not need to call mte.debug() every frame. The debug 
	function actually carries a noticeable overhead.
		There are many ways to defer calculations. In this sample we use a variable
	named alternator and a series of if-then statements to perform certain operations
	every other frame. For example, alternator = 1 when the project runs, so on the
	first frame the game detects and sets the correct sprite animation and then changes the 
	value of alternator to 2. On the second frame the game skips checking the animations and 
	instead updates mte.debug(), calculates the zoom factor basic on the player sprite's
	speed, and resets alternator back to 1. On the third frame the game checks the animations
	again, and so on.
		This simple technique can yield significant performance improvements on slower
	devices.
    ]]--
    if alternator == 1 then
        if not isJumping then
            if player.sequence == "jumpRight" and velX == 0 then
                player:setSequence( "standRight" )
                player:play()
            elseif player.sequence == "jumpLeft" and velX == 0 then
                player:setSequence( "standLeft" )
                player:play()
            elseif velX > maxVelX * 0.75 then
                if player.sequence ~= "runRight" then
                    player:setSequence( "runRight" )
                    player:play()
                end
            elseif velX > 0 then
                if player.sequence ~= "walkRight" then
                    player:setSequence( "walkRight" )
                    player:play()
                end
            elseif velX < maxVelX * -0.75 then
                if player.sequence ~= "runLeft" then
                    player:setSequence( "runLeft" )
                    player:play()
                end
            elseif velX < 0 then
                if player.sequence ~= "walkLeft" then
                    player:setSequence( "walkLeft" )
                    player:play()
                end
            else
                if player.sequence == "runRight" or player.sequence == "walkRight" then
                    player:setSequence( "standRight" )
                    player:play()
                end
                if player.sequence == "runLeft" or player.sequence == "walkLeft" then
                    player:setSequence( "standLeft" )
                    player:play()
                end
            end
        else
            if player.sequence ~= "jumpRight" and player.sequence ~= "jumpLeft" then
                if player.sequence == "runRight" or player.sequence == "walkRight" or player.sequence == "standRight" then
                    player:setSequence( "jumpRight" )
                    player:play()
                end
                if player.sequence == "runLeft" or player.sequence == "walkLeft" or player.sequence == "standLeft" then
                    player:setSequence( "jumpLeft" )
                    player:play()
                end
            end
        end
        alternator = 2
    elseif alternator == 2 then
        if display.fps == 60 then
            local zoomFactor = 1.5 - (abs(velX) / maxVelX * 0.3)
            if currentZoom < zoomFactor and abs(currentZoom - zoomFactor) >= 0.006 then
                currentZoom = currentZoom + 0.006
            elseif currentZoom > zoomFactor and abs(currentZoom - zoomFactor) > 0.004 then
                currentZoom = zoomFactor
            end
            mte.zoom(currentZoom, 2)
            mte.debug(30)
        end
        alternator = 1
    end
    
    if display.fps == 30 then
        local zoomFactor = 1.5 - (abs(velX) / maxVelX * 0.3)
        if currentZoom < zoomFactor and abs(currentZoom - zoomFactor) > 0.006 then
            currentZoom = currentZoom + 0.006
        elseif currentZoom > zoomFactor and abs(currentZoom - zoomFactor) > 0.004 then
            currentZoom = zoomFactor
        end
        mte.zoom(currentZoom, 0)
        mte.debug(30)
    end
    
    --UPDATE VELOCITY, CONSTRAIN TO MAX VELOCITY
	--[[
		This is where the accelerations we created are applied to the player's velocity.
	It is important to constrain the velocity to a value lower than the dimensions of our
	tiles in level coordinates, otherwise the player could pass through a tile in a single
	frame without detecting it.
    ]]--	
    velX = velX + acc
    if velX > maxVelX then
        velX = maxVelX
    elseif velX < maxVelX * -1 then
        velX = maxVelX * -1
    end	
    if not isGrounded then
        velY = velY + gravity
    end
    if velY > maxVelY then
        velY = maxVelY
    end
    
    --APPLY FRICTION
	--[[
		Friction is similar to gravity, however it acts along the X axis and always
	acts opposite to the player's direction of motion. 
    ]]--
    if velX >= friction then
        velX = velX - friction
    elseif velX > 0 and velX < friction then
        velX = 0
    end
    
    if velX <= friction * -1 then
        velX = velX - friction * -1
    elseif velX < 0 and velX > friction * -1 then
        velX = 0
    end
    
    --COLLISION DETECTION	
	--[[
		We create temporary velocity variables so that we can perform operations on the
	velocity for each of the collision detection routines without losing the original
	velocity. 
    ]]--
    tempVelY = velY
    tempVelX = velX
    local tempPlayerX = player.levelPosX + bottomOffset[1] + velX
    local tempPlayerY = player.levelPosY + bottomOffset[2] + velY
    
    --CHECK FOR FLOOR COLLISION
    local sensor1 = {tempPlayerX , tempPlayerY }
    local velY1 = detectFloor(sensor1, velX, velY)
    if velY1 then
        tempVelY = velY1
        velY = 0
    end
    
    mte.moveSprite(player, velX, tempVelY)	
    mte.update()
end

DpadBack:addEventListener("touch", move)
jumpBtn:addEventListener("touch", jump)

Runtime:addEventListener("enterFrame", gameLoop)
