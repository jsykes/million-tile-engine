-----------------------------------------------------------------------------------------
-- main.lua
-----------------------------------------------------------------------------------------

local mte = MTE
local Screen = Screen

local physics = require("physics")

mte.enableBox2DPhysics()
physics.start()
physics.setGravity(0, 0)

mte.loadMap("AppendMap/map/Template.tmx")

for y = 1, 10, 1 do
    if y < 4 then
        for x = 1, 10, 1 do
            local toggle = math.random(1, 3)
            if toggle == 1 then
                mte.appendMap("AppendMap/map/House1.tmx", nil, (x - 5) * 16 + 1, (y - 5) * 16 + 1, nil, true)
            elseif toggle == 2 then
                mte.appendMap("AppendMap/map/House2.tmx", nil, (x - 5) * 16 + 1, (y - 5) * 16 + 1, nil, true)
            else
                mte.appendMap("AppendMap/map/Fountain.tmx", nil, (x - 5) * 16 + 1, (y - 5) * 16 + 1, nil, true)
            end
        end
    elseif y == 4 then
        for x = 1, 10, 1 do
            if x == 2 or x == 5 or x == 8 then
                mte.appendMap("AppendMap/map/wallStairs.tmx", nil, (x - 5) * 16 + 1, (y - 5) * 16 + 1, nil, true)
            else
                mte.appendMap("AppendMap/map/wallHorizontal.tmx", nil, (x - 5) * 16 + 1, (y - 5) * 16 + 1, nil, true)
            end
        end
    elseif y > 4 then
        for x = 1, 10, 1 do
            local toggle = math.random(1, 10)
            if toggle <= 4 then
                mte.appendMap("AppendMap/map/Farm.tmx", nil, (x - 5) * 16 + 1, (y - 5) * 16 + 1, nil, true)
            elseif toggle > 4 and toggle <= 6 then
                mte.appendMap("AppendMap/map/Fountain.tmx", nil, (x - 5) * 16 + 1, (y - 5) * 16 + 1, nil, true)
            else
                mte.appendMap("AppendMap/map/House1.tmx", nil, (x - 5) * 16 + 1, (y - 5) * 16 + 1, nil, true)
            end
        end
    end
end
mte.setCamera({locX = 1, locY = 1, scale = 1.2})

mte.constrainCamera({})

local spriteSheet = graphics.newImageSheet("AppendMap/spriteSheet.png", {width = 32, height = 32, numFrames = 96})
local sequenceData = {
    {name = "up", sheet = spriteSheet, frames = {85, 86}, time = 400, loopCount = 0},
    {name = "right", sheet = spriteSheet, frames = {73, 74}, time = 400, loopCount = 0},
    {name = "down", sheet = spriteSheet, frames = {49, 50}, time = 400, loopCount = 0},
    {name = "left", sheet = spriteSheet, frames = {61, 62}, time = 400, loopCount = 0}
}
local player = display.newSprite(spriteSheet, sequenceData)

local setup = {locX = 1, locY = 1, layer = mte.getSpriteLayer(1)}
mte.addSprite(player, setup)
mte.setCameraFocus(player)
--local s = {-8, -16, 8, -16, 8, 16, -8, 16}
local s = { -8,-13, -6,-14 , 6,-14 , 8,-13 , 8,15 , 6,16 , -6,16 , -8,15}
physics.addBody(player, "dynamic", {bounce = 0.0, shape = s})
player.isFixedRotation = true

local Dpad = display.newImageRect("AppendMap/Dpad.png", 120, 120)
Dpad.x = Screen.Left + Dpad.width*0.5 + 10
Dpad.y = Screen.Bottom - Dpad.height*0.5 - 10

local velX, velY = 0, 0
local sequence = "up"
local move = function(event)
    if event.phase == "began" or event.phase == "moved" then
        local touchX = event.x - event.target.x
        local touchY = event.y - event.target.y
        
        if touchX < -15 then
            velX = -5
            sequence = "left"
        elseif touchX > 15 then
            velX = 5
            sequence = "right"
        else
            velX = 0
        end
        
        if touchY < -15 then
            velY = -5
            sequence = "up"
        elseif touchY > 15 then
            velY = 5
            sequence = "down"
        else
            velY = 0
        end
        
        if player.sequence ~= sequence then
            player:setSequence(sequence)
        end
        
        player:play()
    elseif event.phase == "ended" then
        velX, velY = 0, 0
        player:pause()
    end
end

Dpad:addEventListener("touch", move)

local gameLoop = function(event)
    player:setLinearVelocity(velX * 30, velY * 30)
    mte.update()
    mte.debug()
end

Runtime:addEventListener("enterFrame", gameLoop)