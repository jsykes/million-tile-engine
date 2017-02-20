-- MTE "CASTLE DEMO" ---------------------------------------------------------------------

local mte = MTE
local Screen = Screen

--LOAD MAP -------------------------------------------------------------------------------
mte.toggleWorldWrapX(false)
mte.toggleWorldWrapY(false)
mte.enableLighting = true --Enables Tile Lighting System
mte.enableSpriteSorting = true
mte.enableTileFlipAndRotation()

mte.loadMap("Lighting/map/CastleDemo3.tmx")
mte.setCamera({ locX = 30, locY = 45, blockScaleX = 48, blockScaleY = 48})

--SETUP D-PAD ----------------------------------------------------------------------------
local controlGroup = display.newGroup()
local DpadBack = display.newImageRect(controlGroup, "Lighting/Dpad.png", 120, 120)
DpadBack.x = Screen.Left + DpadBack.width*0.5 + 10
DpadBack.y = Screen.Bottom - DpadBack.height*0.5 - 10

local DpadUp, DpadDown, DpadLeft, DpadRight
DpadUp = display.newRect(controlGroup, DpadBack.x - 0, DpadBack.y - 36, 36, 36)
DpadDown = display.newRect(controlGroup, DpadBack.x - 0, DpadBack.y + 36, 36, 36)
DpadLeft = display.newRect(controlGroup, DpadBack.x - 36, DpadBack.y - 0, 36, 36)
DpadRight = display.newRect(controlGroup, DpadBack.x + 36, DpadBack.y - 0, 36, 36)
DpadBack:toFront()

--CREATE PLAYER SPRITE -------------------------------------------------------------------
local spriteSheet = graphics.newImageSheet("Lighting/spriteSheet.png", {width = 32, height = 32, numFrames = 96})
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
    locX = 30, 
    locY = 45,
    levelWidth = 32,
    levelHeight = 32,
    name = "player",
    constrainToMap = {false, false, false, false}
}
mte.addSprite(player, setup)
mte.setCameraFocus(player)
    local light = {source = {1, 1, 1},
    range = {6, 6, 6},
    falloff = {0.13, 0.13, 0.13},
    layerRelative = -1,
    layerFalloff = {0.03, 0.03, 0.03},
    levelFalloff = {0.19, 0.19, 0.19},
id = "player"}	

player.addLight(light)

local alert = audio.loadSound("alert.mp3")

--LIGHTING EVENTS-------------------------------------------------------------------------
--If the player is lit by the first six robots
local onLighting = function(event)
    if event.phase == "began" then
        audio.play(alert)
        event.source.sprite.light.source = {1, 1, 1}
        event.source.sprite:setSequence("alert")
        event.source.sprite:play()
    elseif event.phase == "maintained" then
        if not event.source.sprite.isPlaying then
            event.source.sprite:setSequence("aware")
        end
    elseif event.phase == "ended" then
        event.source.sprite.light.source = {0.4, 0.4, 0.4}
        event.source.sprite:setSequence("passive")
    end
end

--If the last six robots are lit by the player
local onLighting2 = function(event)
    if event.phase == "began" then
        audio.play(alert)
        event.target:setSequence("alert")
        event.target:play()
    elseif event.phase == "maintained" then
        if not event.target.isPlaying then
            event.target:setSequence("aware")
        end
    elseif event.phase == "ended" then
        event.target:setSequence("passive")
    end
end

--CREATE ROBOT SPRITES--------------------------------------------------------------------
local spriteSheet2 = graphics.newImageSheet("Lighting/sentry.png", {width = 32, height = 64, numFrames = 3})
local sequenceData2 = {
    {name = "alert", frames = {1}, time = 700, loopCount = 1},
    {name = "aware", frames = {2}, time = 700, loopCount = 0},
    {name = "passive", frames = {3}, time = 700, loopCount = 0}
}
local setup2 = {
    kind = "sprite",
    layer =  mte.getSpriteLayer(1), 
    locX = 40, 
    locY = 60,
    levelWidth = 32,
    levelHeight = 64,
    offsetY = -24
}

local robots = {}
for i = 1, 6, 1 do
	local light2 = {source = {0.4, 0.4, 0.4},
        range = {4, 4, 4},
        falloff = {0.04, 0.04, 0.04},
        layerRelative = -1,
        layerFalloff = {0.04, 0.04, 0.04},
        levelFalloff = {0.2, 0.2, 0.2},
        rays = {270},
    id = "robots"..i}	
    robots[i] = display.newSprite(spriteSheet2, sequenceData2)
    robots[i]:setSequence("passive")
    mte.addSprite(robots[i], setup2)
    robots[i].addLight(light2)
    player:addLightingListener("robots"..i, onLighting)	--player registers being lit by the robots
    setup2.locX = setup2.locX + 3
end

setup2.locX = 34
setup2.locY = 11
for i = 7, 12, 1 do
    robots[i] = display.newSprite(spriteSheet2, sequenceData2)
    robots[i]:setSequence("passive")
    mte.addSprite(robots[i], setup2)
    robots[i]:addLightingListener("player", onLighting2) --Robots register being lit by the player
    setup2.locX = setup2.locX + 3
end

-- DETECT MOVEMENT -----------------------------------------------------------------------
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

--DETECT OBSTACLES -----------------------------------------------------------------------
local obstacle = function(level, locX, locY)
    local detect = mte.getTileProperties({level = level, locX = locX, locY = locY})
    for i = 1, #detect, 1 do
        if detect[i].properties then
            if detect[i].properties.solid then
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
atlas["left"] 	= { -1,  0 }
atlas["right"]  = {  1,  0 }
atlas["up"]     = {  0, -1 }
atlas["down"]   = {  0,  1 }

--TOGGLE PLAYER LIGHT---------------------------------------------------------------------
local toggleLight = function(event)
    if event.phase == "ended" then
        if player.light then
            player.removeLight()
        elseif not player.light then
            player.addLight(light)
        end		
    end
    return true
end


--Uncomment to test moveCameraTo()'s new onComplete parameter.
--The following code sets up a wave-like oscillation of each layer's camera.
--[[
moveBack2 = function(event)
	print("done1", event.levelPosX, event.levelPosY, event.layer)
	mte.moveCameraTo({levelPosX = player.levelPosX + 32, levelPosY = player.levelPosY + 32, time = 1500, layer = event.layer, transition = easing.inOutQuad, onComplete = moveBack1})
end

moveBack1 = function(event)
	print("done2", event.levelPosX, event.levelPosY, event.layer)
	mte.moveCameraTo({levelPosX = player.levelPosX - 32, levelPosY = player.levelPosY - 32, time = 1500, layer = event.layer, transition = easing.inOutQuad, onComplete = moveBack2})
end

mte.moveCameraTo({levelPosX = player.levelPosX + 32, levelPosY = player.levelPosY + 32, time = 1000, layer = 1, onComplete = moveBack1})
timer.performWithDelay(50, function() return mte.moveCameraTo({levelPosX = player.levelPosX + 32, levelPosY = player.levelPosY + 32, time = 1000, layer = 2, onComplete = moveBack1}) end)
timer.performWithDelay(150, function() return mte.moveCameraTo({levelPosX = player.levelPosX + 32, levelPosY = player.levelPosY + 32, time = 1000, layer = 3, onComplete = moveBack1}) end)
timer.performWithDelay(200, function() return mte.moveCameraTo({levelPosX = player.levelPosX + 32, levelPosY = player.levelPosY + 32, time = 1000, layer = 4, onComplete = moveBack1}) end)
timer.performWithDelay(300, function() return mte.moveCameraTo({levelPosX = player.levelPosX + 32, levelPosY = player.levelPosY + 32, time = 1000, layer = 5, onComplete = moveBack1}) end)
]]--

------------------------------------------------------------------------------------------
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
    
    mte.debug()
    mte.update()
end

DpadUp:addEventListener("touch", move)
DpadDown:addEventListener("touch", move)
DpadLeft:addEventListener("touch", move)
DpadRight:addEventListener("touch", move)
player:addEventListener("touch", toggleLight)

Runtime:addEventListener("enterFrame", gameLoop)
