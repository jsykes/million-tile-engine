-- MTE "PLATFORMER - ANGLED" -----------------------------------------------------------
local mte = MTE
local Screen = Screen

--ENABLE PHYSICS -----------------------------------------------------------------------
mte.enableBox2DPhysics()
mte.physics.start()
mte.physics.setGravity(0, 90)
mte.physics.setDrawMode("hybrid")
mte.enableTileFlipAndRotation()

--LOAD MAP -----------------------------------------------------------------------------
mte.toggleWorldWrapX(true)
mte.toggleWorldWrapY(true)
--mte.loadMap("PlatformerAngled/map/AngledPhysics1.tmx") 
--mte.loadMap("PlatformerAngled/map/AngledPhysics2.tmx") --Demonstrates physics collision filters
mte.loadMap("PlatformerAngled/map/AngledPhysics3.tmx") --Demonstrates polygon, polyline, ellipse, and square/box object physics
--mte.loadMap("PlatformerAngled/map/AngledPhysics4.tmx") --Demonstrates PhysicsEditor support
local blockScale = 36
local locX = 58
local locY = 19
local mapObj = mte.setCamera({locX = locX, locY = locY, blockScale = blockScale, cullingMargin = {200, 200, 200, 200}})
local worldScaleX = mte.worldScaleX
local worldScaleY = mte.worldScaleY
mte.drawObjects()

--SETUP D-PAD --------------------------------------------------------------------------
local controlGroup = display.newGroup()
local DpadBack = display.newImageRect(controlGroup, "PlatformerAngled/Dpad.png", 120, 120)
DpadBack.x = Screen.Left + DpadBack.width*0.5 + 10
DpadBack.y = Screen.Bottom - DpadBack.height*0.5 - 10
DpadBack.alpha = 0.7

local jumpBtn = display.newRect(controlGroup, display.viewableContentWidth - 150, display.viewableContentHeight - 150, 120, 120)
jumpBtn.alpha = 0.6
jumpBtn.x = DpadBack.x + DpadBack.width + 10
--jumpBtn.x = Screen.Right - jumpBtn.width*0.5 - 10
jumpBtn.y = Screen.Bottom - jumpBtn.height*0.5 - 10
DpadBack:toFront()

--CREATE PLAYER SPRITE -----------------------------------------------------------------
--In this example the player sprite is actually a simple imageRect, not a sprite object
local player = display.newImageRect("PlatformerAngled/playerRect.png", 30, 60)
local setup = {layer = 3, kind = "imageRect", locX = locX, locY = locY, 
    levelWidth = 32, levelHeight = 64, offsetX = 0, offsetY = -16
}	
mte.addSprite(player, setup)
mte.setCameraFocus(player)
mte.update()
mte.physics.addBody(player, "dynamic", {friction = 0.2, bounce = 0.0, density = 0.4, filter = { categoryBits = 1, maskBits = 1 } })
player.isFixedRotation = true

--CREATE BACKDROP SPRITE ---------------------------------------------------------------
--[[
	One technique for reducing the number of simultaneous onscreen tiles is to take a 
screenshot of the backdrop layer in Tiled with "show grid" disabled, edit it into
a single large image in a program such as Gimp or Photoshop, and erase the background tiles
from the map in Tiled (while keeping the background layer). The background image can then be
loaded and added to MTE in the same manner as a player or enemy sprite, but added to the
empty background map layer instead of a foreground spriteLayer. 
	This technique is most effective when the background is relatively small, i.e. less 
then 2048 by 2048 pixels in size, and worldWrap is disabled or the player is prevented
from wrapping by obstacles. 
]]--
local backdrop = display.newImageRect("PlatformerAngled/CaveBackdrop2.png", 1696, 1600)
setup.layer = 1
setup.levelWidth = 1696
setup.levelHeight = 1600
setup.offsetY = 0
mte.addSprite(backdrop, setup)

--MOVEMENT TOUCH FUNCTION----------------------------------------------------------------
local acc = 0
local move = function(event)
    if event.phase == "began" then
        display.getCurrentStage():setFocus(event.target, event.id)
        event.target.isFocus = true
    end
    if event.phase == "began" or event.phase == "moved" then
        if event.x < event.target.x then
            acc = -0.5
        end
        if event.x > event.target.x then
            acc = 0.5
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
that the acceleration along the Y axis is constant. 
	The enterframe event will apply gravity each frame causing an apparent acceleration
towards the floor.
]]--
local jump = function(event)
    if event.phase == "began" then
        display.getCurrentStage():setFocus(event.target, event.id)
        event.target.isFocus = true
        player:applyLinearImpulse(0, -30, player.x, player.y)
    end
    if event.phase == "ended" or event.phase == "cancelled" then
        display.getCurrentStage():setFocus( event.target, nil )
        event.target.isFocus = false
    end
    return true
end

--ENTERFRAME----------------------------------------------------------------------------
local gameLoop = function(event)
    mte.debug()		
    mte.update()
    player:applyForce(acc * 250, 0, player.x, player.y)
end

DpadBack:addEventListener("touch", move)
jumpBtn:addEventListener("touch", jump)

Runtime:addEventListener("enterFrame", gameLoop)























