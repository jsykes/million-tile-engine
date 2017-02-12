-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------
display.setStatusBar( display.HiddenStatusBar )

local mte = require('mte').createMTE()				--Load and instantiate MTE.

mte.loadMap("map.tmx")								--Load a map.

local mapObj = mte.setCamera({locX = 15, locY = 15, scale = 2})		--Set initial camera position and map scale.

--[[
updateTile(parameters)
Changes a map tile.
 
parameters:    	(table) Describes the change to be made and where.
 
Format for parameters
 
locX:           The X coordinate of the tile’s location.
 
locY:           The Y coordinate of the tile’s location.
 
layer:          (number) A layer in the tile map.
 
tile:           (optional) The new tile index. Use 0 to remove the tile from the map and display.
 
levelPosX:      (optional) The X coordinate of the tile’s position.
 
levelPosY:   	(optional) The Y coordinate of the tile’s position.
]]--


--***Uncomment one example at a time.***


--Example 1:
--mte.updateTile({locX = 15, locY = 15, layer = 1, tile = 1})


--Example 2:
--[[
mte.updateTile({levelPosX = 500, levelPosY = 500, layer = 1, tile = 1})
mte.updateTile({levelPosX = 550, levelPosY = 550, layer = 1, tile = 4})
mte.updateTile({levelPosX = 600, levelPosY = 600, layer = 1, tile = 7})
]]--


--Example 3:
--[[
--Setting tile = 0 removes the tile from the screen AND erases it from the map.
mte.updateTile({locX = 15, locY = 15, layer = 1, tile = 0})

--Setting tile = -1 removes the tile from the screen but leaves it in the map.
mte.updateTile({locX = 17, locY = 15, layer = 1, tile = -1})

--The location at locX = 15 remains empty, the location at locX = 17 is redrawn.
local refresh = function()
	mte.refresh()
end

timer.performWithDelay(1500, refresh)
]]--


--Example 4:
--[[
local map = mte.getMap()

--Change a tile in the map data
map.layers[1].world[15][15] = 7

--Calling updateTile with tile = nil will redraw the location without altering the map.
mte.updateTile({locX = 15, locY = 15, layer = 1})
]]--


local gameLoop = function(event)
	mte.update()	--Required to process the camera and display the map.
	mte.debug()		--Displays onscreen position/fps/memory text.
end

Runtime:addEventListener("enterFrame", gameLoop)


























