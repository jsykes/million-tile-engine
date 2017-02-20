local composer = require( "composer" )
local scene = composer.newScene()
local mte = MTE
local Screen = Screen
local json = require ("json")
local myData = require ("RotateConstrainComposer.mydata")

----------------------------------------------------------------------------------
--      Code outside of listener functions (below) will only be executed once,
--      unless composer.removeScene() is called.
---------------------------------------------------------------------------------

-- SPRITES --------------------------------------------------------------------
local player

-- DETECT MOVEMENT ------------------------------------------------------------
myData.DpadUp.id = "up"
myData.DpadDown.id = "down"
myData.DpadLeft.id = "left"
myData.DpadRight.id = "right"
local movement = nil

local function move( event )
    if event.phase == "ended" or event.phase == "cancelled" then
        movement = nil
    elseif event.target.id then
        movement = event.target.id
    end
    return true
end

-- DETECT OBSTACLES ------------------------------------------------------------
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

-- GAME LOOP -------------------------------------------------------------------
local function gameLoop( event )
    local changeMap = false
    if not player.isMoving then
        --CHECK FOR OBJECTS
        local objects = mte.getObject({level = player.level, locX = player.locX, locY = player.locY})
        if objects then
            for key,value in pairs(objects[1].properties) do
                if key == "constraints" then
                    local temp = json.decode(value)
                    mte.constrainCamera({loc = {temp[1], temp[2], temp[3], temp[4]}, time = 1000, transition = easing.inOutQuad})
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
            local xTile, yTile = player.locX + atlas[movement][1], player.locY + atlas[movement][2]
            local result = obstacle( player.level, xTile, yTile )
            if not result then
                if player.sequence ~= movement then
                    player:setSequence( movement )
                end
                player:play()
                mte.moveSpriteTo( { sprite = player, locX = xTile, locY = yTile, time = moveTime, transition = easing.linear} )
            end
        else
            player:pause()
        end
    end
    
    --UPDATE OR GOTO NEW MAP
    if not changeMap then
        mte.debug()
        mte.update()
    else
        composer.gotoScene("RotateConstrainComposer.scene", {effect = "fade", time = 1000})
    end
end

---------------------------------------------------------------------------------

function scene:show(event)
    local group = self.view
    if event.phase == "will" then
        -- Called when the scene is still off screen (but is about to come on screen).
        
        --LOAD MAP ------------------------------------------------------------
        mte.toggleWorldWrapX(true)
        mte.toggleWorldWrapY(true)
        mte.enableTileFlipAndRotation()
        mte.loadTileSet("tinySet", "RotateConstrainComposer/tilesets/tinySet.png")
        mte.loadMap("RotateConstrainComposer/map/"..myData.nextMap..".tmx")
        local locX, locY
        if myData.nextMap == "map1" then       	
            if not myData.prevMap or myData.prevMap == "map3" then
                locX, locY = 3, 4
                mte.setCamera({ locX = locX, locY = locY, blockScaleX = 32, blockScaleY = 32})
                mte.constrainCamera({loc = {1, 1, 15, 10}, time = 10})
            else
                locX, locY = 8, 37
                mte.setCamera({ locX = locX, locY = locY, blockScaleX = 32, blockScaleY = 32})
                mte.constrainCamera({loc = {1, 31, 15, 40}})
            end
        elseif myData.nextMap == "map2" then
            if myData.prevMap == "map1" then
                locX, locY = 8, 3
                mte.setCamera({ locX = locX, locY = locY, blockScaleX = 32, blockScaleY = 32})
                mte.constrainCamera({loc = {false, 1, false, 20}})
            else
                locX, locY = 36, 18
                mte.setCamera({ locX = locX, locY = locY, blockScaleX = 32, blockScaleY = 32})
                mte.constrainCamera({loc = {false, 1, false, 20}})
            end
        elseif myData.nextMap == "map3" then
            if myData.prevMap == "map2" then
                locX, locY = 34, 33
                mte.setCamera({ locX = locX, locY = locY, blockScaleX = 32, blockScaleY = 32})
                mte.constrainCamera({loc = {31, 31, 45, 40}})
            else
                locX, locY = 3, 4
                mte.setCamera({ locX = locX, locY = locY, blockScaleX = 32, blockScaleY = 32})
                mte.constrainCamera({loc = {1, 1, 15, 20}})
            end
        end
        
        
        myData.controlGroup:toFront()
        
        --CREATE PLAYER SPRITE ---------------------------------------------------
        local spriteSheet = graphics.newImageSheet("RotateConstrainComposer/spriteSheet.png", {width = 32, height = 32, numFrames = 96})
        local sequenceData = {
            {name = "up", sheet = spriteSheet, frames = {85, 86}, time = 350, loopCount = 0},
            {name = "down", sheet = spriteSheet, frames = {49, 50}, time = 350, loopCount = 0},
            {name = "left", sheet = spriteSheet, frames = {61, 62}, time = 350, loopCount = 0},
            {name = "right", sheet = spriteSheet, frames = {73, 74}, time = 350, loopCount = 0}
        }
        player = display.newSprite(spriteSheet, sequenceData)
        local setup = {
            kind = "sprite", 
            layer =  mte.getSpriteLayer(1), 
            locX = locX, 
            locY = locY,
            levelWidth = 32,
            levelHeight = 32
        }
        mte.addSprite(player, setup)
        mte.setCameraFocus(player)
        
        group:insert(mte.getMapObj())
        
        mte.update()
    elseif event.phase == "did" then
        -- Called when the scene is now on screen.
        -- Insert code here to make the scene come alive.
        -- Example: start timers, begin animation, play audio, etc.
	
        myData.DpadUp:addEventListener("touch", move)
        myData.DpadDown:addEventListener("touch", move)
        myData.DpadLeft:addEventListener("touch", move)
        myData.DpadRight:addEventListener("touch", move)
        
        Runtime:addEventListener("enterFrame", gameLoop)
    end
end


-- Called when scene is about to move offscreen:
function scene:hide(event)
    local group = self.view
    if event.phase == "will" then
        -- Called when the scene is on screen (but is about to go off screen).
        -- Insert code here to "pause" the scene.
        -- Example: stop timers, stop animation, stop audio, etc.
        
        myData.DpadUp:removeEventListener("touch", move)
        myData.DpadDown:removeEventListener("touch", move)
        myData.DpadLeft:removeEventListener("touch", move)
        myData.DpadRight:removeEventListener("touch", move)
        
        Runtime:removeEventListener("enterFrame", gameLoop)
    end
end


-- Called prior to the removal of scene's "view" (display group)
function scene:destroy(event)
    local group = self.view
    -- Called prior to the removal of scene's view ("sceneGroup").
    -- Insert code here to clean up the scene.
    -- Example: remove display objects, save state, etc.
    
    mte.cleanup()
end


---------------------------------------------------------------------------------

-- Listener Setup
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

---------------------------------------------------------------------------------

return scene