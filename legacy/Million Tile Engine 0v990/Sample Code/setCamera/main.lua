-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------
display.setStatusBar( display.HiddenStatusBar )

local mte = require('mte').createMTE()								--Load and instantiate MTE.

mte.loadMap("map.tmx")												--Load a map.

--[[
setCamera(parameters)
Changes the position of the camera and the display scale. This function is usually called
just after a map loads to set the initial camera position. For moving the camera during gameplay
see moveCamera() and moveCameraTo(). This function is optional- MTE will automatically
display a map at locX = 1, locY = 1, scale = 1 on the first update() if setCamera isn't
called. This function cannot be called before loadMap(). 
 
parameters:    		(table) Configuration information.
 
Format for parameters
 
levelPosX:       	The X coordinate of the camera's desired position.
 
levelPosY:       	The Y coordinate of the camera's desired position.
 
locX:               (optional) The X coordinate of the camera's desired location.
 
locY:               (optional) The Y coordinate of the camera's desired location.
 
sprite:             (reference, optional) Centers the initial camera view on the specified sprite. 
Call setCameraFocus(sprite) to have the camera continue to follow the sprite.
 
scale:              Sets the scale of the map tiles. 
If the map’s tiles are 32x32 in size and the scale is set to 2.25, the tiles will appear to be 72 pixels in content space. 
In fact it is the master group object which is changing in scale, not the tiles.
 
scaleX:            	Sets the scale of map tiles on the X axis, stretching or shrinking them horizontally. 
In fact it is the master group object which is changing in scale, not the tiles.
 
scaleY:             Sets the scale of map tiles on the Y axis, stretching or shrinking them vertically. 
In fact it is the master group object which is changing in scale, not the tiles.
 
blockScale:     	(optional) Sets the size of map tiles in pixels, scaling the camera view as needed. 
For example, if the map has 32x32 resolution tiles and the user sets blockScale to 72, the sprites will be scaled by 2.25.
 
blockScaleX:   		(optional) Sets the width of map tiles in pixels.
 
blockScaleY:   		(optional) Sets the height of map tiles in pixels.
 
cullingMargin: 		(table, optional) Alters the culling region boundaries. 
Positive values increase the size of the active culling region, the result being that the engine spawns more tiles offscreen than it normally would. 
The table is an array of four values. Index 1 is the left margin, index 2 is the top margin, index 3 is the right margin, index 4 is the bottom margin. 
For example, this table will increase the size of the culling region by 200 pixels on every side: {200, 200, 200, 200}
 
overDraw:       	(number, optional) Increases the size of the tiles by the specified number of pixels, without altering the blockScale of the map, to help hide the edge artifacts of non-extruded tilesets. 
For example, an overDraw of 2 will increase the width and height of tiles by 2.
 
parentGroup:   		(group) Inserts MTE’s masterGroup into the specified parentGroup. 
The parentGroup can be either a group object or a container object.
]]--


--***Uncomment one example at a time.***


--Example 1: 
--mte.setCamera({locX = 11, locY = 11, scale = 2})


--Example 2:
--mte.setCamera({levelPosX = 500, levelPosY = 500, blockScale = 72})


--Example 3:
--mte.setCamera({locX = 11, levelPosY = 600, scaleX = 1.5, scaleY = 3})


--Example 4:
--mte.setCamera({locX = 10, locY = 15, blockScaleX = 128, blockScaleY = 16})


--Example 5a: Negative overDraw will shrink tiles and create borders
--mte.setCamera({locX = 11, locY = 11, scale = 2, overDraw = -2})


--Example 5b: Gaps between tiles can be corrected by very small overDraw values
--mte.setCamera({locX = 11, locY = 11, scale = 2, overDraw = 0.5})


--Example 6:
--[[
local mySprite = display.newRect(0, 0, 32, 32)
mte.addSprite(mySprite, {layer = 3, locX = 11, locY = 11})
mte.setCamera({sprite = mySprite, scale = 2})
]]--


local gameLoop = function(event)
	mte.update()	--Required to process camera and display map.
	mte.debug()		--Displays onscreen position/fps/memory text.
end

Runtime:addEventListener("enterFrame", gameLoop)


























