-- MTE "CASTLE DEMO" ----------------------------------------------------------
local mte = MTE
local Screen = Screen

--LOAD MAP ------------------------------------------------------------
mte.toggleWorldWrapX(true)
mte.toggleWorldWrapY(true)
mte.enableBox2DPhysics()
mte.physics.start()

mte.loadMap("LineOfSight/map/Nightmare.tmx")
local mapObj = mte.setCamera({ locX = 53, locY = 42, blockScaleX = 64, blockScaleY = 64, overDraw = 1})

--SETUP D-PAD ------------------------------------------------------------
local controlGroup = display.newGroup()
local DpadBack = display.newImageRect(controlGroup, "LineOfSight/Dpad.png", 120, 120)

DpadBack.x = Screen.Left + DpadBack.width*0.5 + 10
DpadBack.y = Screen.Bottom - DpadBack.height*0.5 - 10

local DpadUp, DpadDown, DpadLeft, DpadRight
DpadUp = display.newRect(controlGroup, DpadBack.x - 0, DpadBack.y - 36, 36, 36)
DpadDown = display.newRect(controlGroup, DpadBack.x - 0, DpadBack.y + 36, 36, 36)
DpadLeft = display.newRect(controlGroup, DpadBack.x - 36, DpadBack.y - 0, 36, 36)
DpadRight = display.newRect(controlGroup, DpadBack.x + 36, DpadBack.y - 0, 36, 36)
DpadBack:toFront()

--CREATE PLAYER SPRITE ------------------------------------------------------------
local spriteSheet = graphics.newImageSheet("LineOfSight/spriteSheet.png", {width = 32, height = 32, numFrames = 96})
local sequenceData = {
    {name = "up", sheet = spriteSheet, frames = {85, 86}, time = 400, loopCount = 0},
    {name = "down", sheet = spriteSheet, frames = {49, 50}, time = 400, loopCount = 0},
    {name = "left", sheet = spriteSheet, frames = {61, 62}, time = 400, loopCount = 0},
    {name = "right", sheet = spriteSheet, frames = {73, 74}, time = 400, loopCount = 0}
}
local player = display.newSprite(spriteSheet, sequenceData)
local setup = {
    kind = "sprite", 
    layer =  mte.getSpriteLayer(1), 
    locX = 53, 
    locY = 42,
    levelWidth = 32,
    levelHeight = 32
}
mte.addSprite(player, setup)
mte.setCameraFocus(player)

-- DETECT MOVEMENT ------------------------------------------------------------
DpadUp.id = "up"
DpadDown.id = "down"
DpadLeft.id = "left"
DpadRight.id = "right"
local movement = nil

local function move( event )
    if event.phase == "ended" or event.phase == "cancelled" then
        movement = nil
    elseif event.target.id then
        movement = event.target.id
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
local moveTime = 200

local atlas = {}
atlas["left"] 	= { -1,  0 }
atlas["right"]  = {  1,  0 }
atlas["up"]     = {  0, -1 }
atlas["down"]   = {  0,  1 }

local lines = {}
local darkLines = {}

local function gameLoop( event )
    if not player.isMoving then
        --MOVE PLAYER CHARACTER
        if movement then
            local xTile, yTile = player.locX + atlas[movement][1], player.locY + atlas[movement][2]
            local result = obstacle( player.level, xTile, yTile )
            if not result then
                if player.sequence ~= movement then
                    player:setSequence( movement )
                end
                player:play()
                mte.moveSpriteTo( { sprite = player, locX = xTile, locY = yTile, time = moveTime, easing = "linear" } )
            end
        else
            player:pause()
        end
    end
    
    --RAYCAST CALCULATIONS AND DISPLAY
	--[[
	This code draws 720 lines each frame as a visual demonstration of raycasting. The player is the origin. 
	Thin white lines extend from the player position until they hit an obstacle, where they end.
	Thick black lines extend from the first obstacle hit out past the edge of the screen to create the
	shadow effect. 
	
	In practice drawing 720 lines is inefficient and eats performance. This is a quick-and-dirty demo.
	More elegant methods of generating shadow are likely possible with a little clever coding.
    ]]--
    
    local castDistance = 1000
    for i = 1, 360, 1 do
        local startX, startY = player.x, player.y
        local endX = player.x + (castDistance * math.cos(math.rad(i)))
        local endY = player.y + (castDistance * math.sin(math.rad(i)))
        local hits = mte.physics.rayCast(startX, startY, endX, endY)
        
        if hits then
            local contentStartX, contentStartY = 0, 0 --player:localToContent(0, 0)
            local deltaX = player.x - hits[1].position.x
            local deltaY = player.y - hits[1].position.y
            local contentEndX, contentEndY = 0 + (castDistance * math.cos(math.rad(i))), 0 + (castDistance * math.sin(math.rad(i)))
            
            if lines[i] then
                lines[i]:removeSelf()
                lines[i] = nil
            end			
            lines[i] = display.newLine(mapObj, contentStartX, contentStartY, contentStartX - deltaX, contentStartY - deltaY)
            lines[i].alpha = 0.3
            lines[i].strokeWidth = 1
            lines[i]:setStrokeColor(0, 1, 0)
            --Green lines are intersecting with a solid object
            
            if darkLines[i] then
                darkLines[i]:removeSelf()
                darkLines[i] = nil
            end
            darkLines[i] = display.newLine(mapObj, contentStartX - deltaX, contentStartY - deltaY, contentEndX, contentEndY)
            darkLines[i].alpha = 0.7
            darkLines[i].strokeWidth = 6
            darkLines[i]:setStrokeColor(0, 0, 0)
            --Black lines form shadow
            
        else
            local contentStartX, contentStartY = 0, 0
            local contentEndX, contentEndY = 0 + (castDistance * math.cos(math.rad(i))), 0 + (castDistance * math.sin(math.rad(i)))
            
            if lines[i] then
                lines[i]:removeSelf()
                lines[i] = nil
            end
            if darkLines[i] then
                darkLines[i]:removeSelf()
                darkLines[i] = nil
            end
            lines[i] = display.newLine(mapObj, contentStartX, contentStartY, contentEndX, contentEndY)
            lines[i].alpha = 0.3
            lines[i].strokeWidth = 1
            lines[i]:setStrokeColor(0, 0, 1)
            --Blue lines are not intersecting anything
        end
        
    end
    
    mte.debug()
    mte.update()
end

DpadUp:addEventListener("touch", move)
DpadDown:addEventListener("touch", move)
DpadLeft:addEventListener("touch", move)
DpadRight:addEventListener("touch", move)

Runtime:addEventListener("enterFrame", gameLoop)

