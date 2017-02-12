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

--Create four sprites, two on layer 1, two on layer 2
local spriteSheet = graphics.newImageSheet("spriteSheet.png", {width = 32, height = 32, numFrames = 96})
local sequenceData = {		
		{name = "up", sheet = spriteSheet, frames = {85, 86}, time = 400, loopCount = 0},
		{name = "right", sheet = spriteSheet, frames = {73, 74}, time = 400, loopCount = 0},
		{name = "down", sheet = spriteSheet, frames = {49, 50}, time = 400, loopCount = 0},
		{name = "left", sheet = spriteSheet, frames = {61, 62}, time = 400, loopCount = 0}
		}
local sprite1 = display.newSprite(spriteSheet, sequenceData)
local setup = {
		kind = "sprite", 
		layer =  1, 
		locX = 10, 
		locY = 11,
		levelWidth = 32,
		levelHeight = 32,
		name = "robot"
		}
mte.addSprite(sprite1, setup)
sprite1:setSequence("down")

local sequenceData = {		
		{name = "up", sheet = spriteSheet, frames = {88, 89}, time = 400, loopCount = 0},
		{name = "right", sheet = spriteSheet, frames = {76, 77}, time = 400, loopCount = 0},
		{name = "down", sheet = spriteSheet, frames = {52, 53}, time = 400, loopCount = 0},
		{name = "left", sheet = spriteSheet, frames = {64, 65}, time = 400, loopCount = 0}
		}
local sprite2 = display.newSprite(spriteSheet, sequenceData)
local setup = {
		kind = "sprite", 
		layer =  1, 
		locX = 11, 
		locY = 11,
		levelWidth = 32,
		levelHeight = 32,
		name = "fairy"
		}
mte.addSprite(sprite2, setup)
sprite2:setSequence("down")

local sequenceData = {		
		{name = "up", sheet = spriteSheet, frames = {91, 92}, time = 400, loopCount = 0},
		{name = "right", sheet = spriteSheet, frames = {79, 80}, time = 400, loopCount = 0},
		{name = "down", sheet = spriteSheet, frames = {55, 56}, time = 400, loopCount = 0},
		{name = "left", sheet = spriteSheet, frames = {67, 68}, time = 400, loopCount = 0}
		}
local sprite3 = display.newSprite(spriteSheet, sequenceData)
local setup = {
		kind = "sprite", 
		layer =  2, 
		locX = 12, 
		locY = 11,
		levelWidth = 32,
		levelHeight = 32,
		name = "dog"
		}
mte.addSprite(sprite3, setup)
sprite3:setSequence("down")

local sequenceData = {		
		{name = "up", sheet = spriteSheet, frames = {94, 95}, time = 400, loopCount = 0},
		{name = "right", sheet = spriteSheet, frames = {82, 83}, time = 400, loopCount = 0},
		{name = "down", sheet = spriteSheet, frames = {58, 59}, time = 400, loopCount = 0},
		{name = "left", sheet = spriteSheet, frames = {70, 71}, time = 400, loopCount = 0}
		}
local sprite4 = display.newSprite(spriteSheet, sequenceData)
local setup = {
		kind = "sprite", 
		layer =  2, 
		locX = 12, 
		locY = 12,
		levelWidth = 32,
		levelHeight = 32,
		name = "cat"
		}
mte.addSprite(sprite4, setup)
sprite4:setSequence("down")

--[[
getSprites(parameters)
Searches for sprites which match the specified parameters. All parameters are optional. 
Returns a table of sprite references.
 
parameters: 	(table) Describes the specific sprite(s).
 
Format for parameters:
 
name:       	(string) The name specified in addSprite, or the name of a Tiled Object converted into a sprite.
 
locX:           (optional) The X coordinate of the map location to search for sprites.
 
locY:           (optional) The Y coordinate of the map location to search for sprites.
 
levelPosX:      (optional) The X coordinate to search for sprites.
 
levelPosY:      (optional) The Y coordinate to search for sprites.
 
layer:          (number) A layer of the tile map.
 
level:           (number) A level of the tile map.
]]--


--***Uncomment one example at a time.***



--Example 1:
--[[
--getSprites() always returns a table, even if the table only contains 1 sprite.
local sprites = mte.getSprites({name = "robot"})
for key, value in pairs(sprites) do
	print(key, value)
end
]]--


--Example 2:
--[[
local sprite = mte.getSprites({name = "robot"})[1]
mte.moveSpriteTo({sprite = sprite, locY = sprite.locY + 1, time = 1000})
]]--


--Example 3:
--[[
local sprite = mte.getSprites({locX = 11, locY = 11})[1]
mte.moveSpriteTo({sprite = sprite, locY = sprite.locY + 1, time = 1000})
]]--


--Example 4:
--[[
local sprite = mte.getSprites({levelPosX = 368, levelPosY = 336})[1]
mte.moveSpriteTo({sprite = sprite, locY = sprite.locY + 1, time = 1000})
]]--


--Example 5:
--[[
local sprites = mte.getSprites({layer = 2})
for i = 1, #sprites, 1 do
	mte.moveSpriteTo({sprite = sprites[i], locY = sprites[i].locY + 1, time = 1000})
end
]]--


--Example 6:
--[[
local sprites = mte.getSprites({locY = 11})
for i = 1, #sprites, 1 do
	mte.moveSpriteTo({sprite = sprites[i], locY = sprites[i].locY + 2, time = 1000})
end
]]--


--Example 7:
--[[
local sprites = mte.getSprites()
for i = 1, #sprites, 1 do
	mte.moveSpriteTo({sprite = sprites[i], locX = sprites[i].locX + 1, locY = sprites[i].locY + 1, time = 1000})
end
]]--



local gameLoop = function(event)
	mte.update()	--Required to process MTE-managed sprite movement.
	mte.debug()		--Displays onscreen position/fps/memory text.
end

Runtime:addEventListener("enterFrame", gameLoop)


























