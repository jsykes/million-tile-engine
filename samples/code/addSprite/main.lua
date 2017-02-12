-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------
display.setStatusBar( display.HiddenStatusBar )

local mte = require('mte').createMTE()								--Load and instantiate MTE.

mte.enableSpriteSorting = true										--Needed for Example 5.
mte.spriteSortResolution = 10

mte.loadMap("map.tmx")												--Load a map.

mte.setCamera({locX = 11, locY = 11, scale = 2, overDraw = 0.1})	--Set the initial camera position and scale.

--[[
addSprite(sprite, setup)
Adds a sprite such as a player character or an enemy to MTE’s sprite arrays. 
This allows the engine to manage the movement, position, and scale of the sprite in relation to the world around it.
 
Returns a displayObject reference.
 
sprite:             (object) The displayObject reference to a sprite, imageRect, vector object, or groupObject.
 
setup:             	(table) Data used by MTE to position and scale the sprite in the world.
 
Format for setup:
 
layer:              (number, optional) A map layer.
 
kind:               (string, optional) Specifies the type of displayObject being added. 
Possible values are “sprite”, “imageRect”, “group”, or “vector”.
 
name:              	(string, optional) The name of the sprite, used to retrieve sprites with getSprites().  
The engine will assign a name to a sprite if none is supplied. 
The generated name is based on the x and y position of the sprite and the layer to which it is added.
 
levelPosX:          (optional) The X coordinate of the sprite’s starting position.
 
levelPosY:          (optional) The Y coordinate of the sprite’s starting position.
 
locX:               (optional) The X coordinate of the sprite’s starting tile map location.
 
locY:               (optional) The Y coordinate of the sprite’s starting tile map location.
 
levelWidth:      	(optional) The desired width of the sprite. The sprite will be scaled to this width.
 
levelHeight:      	(optional) The desired height of the sprite. The sprite will be scaled to this height.
 
offsetX:            (optional) Alters the rendered position of the sprite without affecting its position on the map. 
The engine will alter the sprite’s anchorX property.
 
offsetY:            (optional) Alters the rendered position of the sprite without affecting its position on the map. 
The engine will alter the sprite’s anchorY property.
 
lighting:           (boolean) Sets whether MTE is allowed to control the sprite’s color.
 
constrainToMap:    	(table) Specifies whether the sprite will leave the left, top, right, or bottom of the map if moveSprite or moveSpriteTo are given destinations outside of the map. 
For example {true, false, true, true} will prevent the sprite from leaving the left, right, or bottom edge of the map, but allow the sprite to leave the top edge of the map.
 
sortSprite:       	(boolean) If true, allows MTE to control the render order of the sprite. 
The MTE flag enableSpriteSorting must be ‘true’ in order for this to work.
 
sortSpriteOnce: 	(boolean) If both sortSprite and sortSpriteOnce are true, MTE will sort the sprite a single time and then set sortSprite to false. 
The user can set sortSprite back to true to sort the sprite again whenever needed; the engine will sort the sprite again and set sortSprite back to false each time.
 
offscreenPhysics: 	(boolean) If true, the sprite will spawn a tiny area of the map immediately around itself while offscreen, 
allowing the physics simulation to continue no matter where the sprite is on the map. 
This will allow physics objects to remain active anywhere on the map, without the objects falling through the world or moving through walls.
 
heightMap: 			(table) The effective height of each of the sprite's four corners. 
Positive values will make the corner appear closer (coming out of the screen). Negative values will make the corner appear farther away (going into the screen). For example; {1, 1, -1, -1}
 
followHeightMap:  	(boolean) Sets whether the sprite conforms to the heightMap of the layer it is on. 
If true, the sprite will alter it's path (shape) to appear larger or smaller as the height of the terrain changes.
]]--


--***Uncomment one example at a time.***


--Example 1: 
--[[
local mySprite = display.newRect(0, 0, 32, 32)
mySprite:setFillColor(1, 0, 0)
mte.addSprite(mySprite, {layer = 3, locX = 11, locY = 11, lighting = false})
]]--


--Example 2: 
--[[
local mySprite = display.newRect(0, 0, 32, 32)
mySprite:setFillColor(1, 0, 0)
local setup = {layer = 3, locX = 11, locY = 11, lighting = false, constrainToMap = {false, false, false, false}}
--setup.constrainToMap = {true, true, true, true}
mte.addSprite(mySprite, setup)
mte.setCameraFocus(mySprite)	--Sets the camera to follow the sprite

--ConstrainToMap controls whether the sprite is allowed to leave the map
mte.moveSpriteTo({sprite = mySprite, locX = -5, locY = -5, time = 3000})
]]--


--Example 3: 
--[[
local spriteSheet = graphics.newImageSheet("spriteSheet.png", {width = 32, height = 32, numFrames = 96})
local sequenceData = {		
		{name = "up", sheet = spriteSheet, frames = {85, 86}, time = 400, loopCount = 0},
		{name = "right", sheet = spriteSheet, frames = {73, 74}, time = 400, loopCount = 0},
		{name = "down", sheet = spriteSheet, frames = {49, 50}, time = 400, loopCount = 0},
		{name = "left", sheet = spriteSheet, frames = {61, 62}, time = 400, loopCount = 0}
		}
local player = display.newSprite(spriteSheet, sequenceData)
local setup = {
		kind = "sprite", 
		layer =  mte.getSpriteLayer(1), 
		locX = 11, 
		locY = 11,
		levelWidth = 32,
		levelHeight = 32,
		name = "player"
		}
mte.addSprite(player, setup)
player:setSequence("down")
player:play()
]]--


--Example 4:
--[[
local mySprite = display.newRect(0, 0, 32, 32)
mySprite:setFillColor(1, 0, 0)
mte.addSprite(mySprite, {layer = 3, locX = 11, locY = 11, lighting = false})

local mySprite2 = display.newRect(0, 0, 32, 32)
mySprite2:setFillColor(0, 1, 1)
mte.addSprite(mySprite2, {layer = 3, locX = 12, locY = 11, lighting = false, offsetY = -16})

--The offsetY of mySprite2 changes the apparent position without changing the true position
print(mySprite.y, mySprite.levelPosY, mySprite2.levelPosY, mySprite2.y)
]]--


--Example 5:
--[[
local setup = {layer = 3, locX = 11, locY = 11, levelHeight = 64, lighting = false, sortSprite = true, offsetY = -16}

local mySprite = display.newRect(0, 0, 32, 32)
mySprite:setFillColor(1, 0, 0)
mte.addSprite(mySprite, setup)

local mySprite2 = display.newRect(0, 0, 32, 32)
mySprite2:setFillColor(0, 1, 1)
setup.locY = 8
setup.levelPosX = 352
mte.addSprite(mySprite2, setup)

--As the blue sprite moves past the red sprite, the blue sprite moves into the foreground.
mte.moveSpriteTo({sprite = mySprite2, levelPosY = mySprite2.levelPosY + 200, time = 4000})
]]--


--Example 6: 
--[[
local spriteSheet = graphics.newImageSheet("spriteSheet.png", {width = 32, height = 32, numFrames = 96})
--The sprite is a group to which we'll add other display objects.
local player = display.newGroup()

local sequenceData = {		
		{name = "up", sheet = spriteSheet, frames = {85, 86}, time = 400, loopCount = 0},
		{name = "right", sheet = spriteSheet, frames = {73, 74}, time = 400, loopCount = 0},
		{name = "down", sheet = spriteSheet, frames = {49, 50}, time = 400, loopCount = 0},
		{name = "left", sheet = spriteSheet, frames = {61, 62}, time = 400, loopCount = 0}
		}
display.newSprite(player, spriteSheet, sequenceData)
sequenceData = {		
		{name = "up", sheet = spriteSheet, frames = {88, 89}, time = 400, loopCount = 0},
		{name = "right", sheet = spriteSheet, frames = {76, 77}, time = 400, loopCount = 0},
		{name = "down", sheet = spriteSheet, frames = {52, 53}, time = 400, loopCount = 0},
		{name = "left", sheet = spriteSheet, frames = {64, 65}, time = 400, loopCount = 0}
		}
display.newSprite(player, spriteSheet, sequenceData)
sequenceData = {		
		{name = "up", sheet = spriteSheet, frames = {91, 92}, time = 400, loopCount = 0},
		{name = "right", sheet = spriteSheet, frames = {79, 80}, time = 400, loopCount = 0},
		{name = "down", sheet = spriteSheet, frames = {55, 56}, time = 400, loopCount = 0},
		{name = "left", sheet = spriteSheet, frames = {67, 68}, time = 400, loopCount = 0}
		}
display.newSprite(player, spriteSheet, sequenceData)
sequenceData = {		
		{name = "up", sheet = spriteSheet, frames = {94, 95}, time = 400, loopCount = 0},
		{name = "right", sheet = spriteSheet, frames = {82, 83}, time = 400, loopCount = 0},
		{name = "down", sheet = spriteSheet, frames = {58, 59}, time = 400, loopCount = 0},
		{name = "left", sheet = spriteSheet, frames = {70, 71}, time = 400, loopCount = 0}
		}
display.newSprite(player, spriteSheet, sequenceData)

--Position sprites inside the group, set animations
player[1].x = -16
player[1].y = -16
player[1]:setSequence("down")
player[1]:play()

player[2].x = -16
player[2].y = 16
player[2]:setSequence("down")
player[2]:play()

player[3].x = 16
player[3].y = 16
player[3]:setSequence("down")
player[3]:play()

player[4].x = 16
player[4].y = -16
player[4]:setSequence("down")
player[4]:play()

local setup = {
		kind = "group", 
		layer =  mte.getSpriteLayer(1), 
		locX = 11, 
		locY = 11,
		levelWidth = 32,	
		levelHeight = 32,
		name = "player"
		}
mte.addSprite(player, setup)

--The player group is treated as a single sprite by MTE
mte.moveSpriteTo({sprite = player, locX = 15, locY = 15, time = 2000})
]]--


local gameLoop = function(event)
	mte.update()	--Required to process MTE-managed sprite movement.
	mte.debug()		--Displays onscreen position/fps/memory text.
end

Runtime:addEventListener("enterFrame", gameLoop)


























