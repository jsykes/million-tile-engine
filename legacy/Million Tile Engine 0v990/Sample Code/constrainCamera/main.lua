-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------
display.setStatusBar( display.HiddenStatusBar )

local mte = require('mte').createMTE()				--Load and instantiate MTE.

mte.loadMap("map.tmx")								--Load a map.

local mapObj = mte.setCamera({locX = 1, locY = 1, scale = 2})		--Set initial camera position and map scale.

--Hide parallax layers for now. We'll use these in examples 9, 10, and 11.
mte.getLayerObj({layer = 5}).alpha = 0
mte.getLayerObj({layer = 6}).alpha = 0

--[[
constrainCamera(parameters)
Constrains the camera to an area on the tilemap. The field of view will stay within this area 
unless it is too small for the field of view to fit inside of it, in which case the camera 
will center on the constraint area.
 
Alternatively, you can choose to leave some edges unconstrained. For example, you can set 
a top constraint and a bottom constraint, but leave left and right unconstrained. 
The camera will move freely back and forth along the X axis, but it will only move up and 
down along the Y axis to the extent possible without leaving the constraints.
 
If the camera is outside of the new constraint area it will automatically move into it. 
You may set the movement time in milliseconds and the movement easing function to use during 
this camera transition. An important gotcha is that no other camera movement can be active 
when this move takes place. Furthermore, a sprite on which the camera is focused (setCameraFocus) 
must be stationary. An optional parameter will automatically freeze the sprite while the 
move takes place and unfreeze it when the move is finished.
 
Returns a table of the four constraint tables: constrainTop, constrainLeft, constrainRight, and constrainBottom.
 
parameters:    	(table, optional) Defines the constraints, configures the camera’s movement 
into the constrain area, sets the alignment of parallax layers. This table is optional. 
The default behavior is to constrain the camera to the boundaries of the tile map.
 
Format for parameters:
 
loc:            (table, optional) A table containing the constraints; {left, top, right, bottom}.
Constraints may be numbers or the boolean “false,” or nil.
 
levelPos:            (table, optional) A table containing the constraints; {left, top, right, bottom}.
Constraints may be numbers or the boolean “false,” or nil.
 
xAlign:         (string) Aligns the map’s parallax layers to the map’s non-parallax layers. 
Possible values: “center”, “left”, “right”
 
yAlign:         (string) See xAlign. Possible values: “center”, “top”, “bottom”
 
layer:          (number) A layer in the tilemap. Use nil to constrain all layers simultaneously.
 
time:           (number) Camera movement time in milliseconds.
 
transition:     (easing) Desired easing function for camera movement i.e. easing.inOutQuad
 
holdSprite:		(boolean) Freezes the sprite on which the camera is focused- the sprite passed 
to the setCameraFocus(sprite) function- while the camera is moving into the constraint area, 
unfreezing the sprite when the movement is complete. Default is ‘true’.
]]--


--***Uncomment one example at a time.***


--Example 1:
--mte.constrainCamera()


--Example 2:
--mte.constrainCamera({time = 1000})


--Example 3:
--mte.constrainCamera({time = 2000, transition = easing.inOutExpo})


--Example 4:
--[[
mte.constrainCamera({loc = {3, 3, 28, 28}})
mte.update()
mte.moveCameraTo({locX = 30, locY = 30, time = 3000})
]]--


--Example 5:
--mte.constrainCamera({loc = {9, 9, 22, 22}})


--Example 6:
--mte.constrainCamera({levelPos = {400, 400, 560, 560}, time = 1000})


--Example 7:
--[[
mte.constrainCamera()

--The camera moves to remain within the constraint during rotation until an equilibrium is found.
local rotate = function()
	mapObj.rotation = mapObj.rotation + 0.2
end

timer.performWithDelay(16, rotate, 0)
]]--


--Example 8:
--[[
mte.constrainCamera()

--The camera moves to remain within the constraint as the map changes scale.
--When the constraint area is too small to fill the screen, the camera centers the constraint area on the screen.
local scale = function()
	if mapObj.xScale > 0.5 then
		mapObj.xScale = mapObj.xScale - 0.002
		mapObj.yScale = mapObj.yScale - 0.002
	end
end

timer.performWithDelay(16, scale, 0)
]]--


--Example 9:
--[[
--Show parallax layers.
mte.getLayerObj({layer = 5}).alpha = 1
mte.getLayerObj({layer = 6}).alpha = 1

mte.constrainCamera({time = 2000, xAlign = "left", yAlign = "top"})
]]--


--Example 10:
--[[
--Show parallax layers.
mte.getLayerObj({layer = 5}).alpha = 1
mte.getLayerObj({layer = 6}).alpha = 1

mte.constrainCamera({xAlign = "right", yAlign = "bottom"})
mte.update()
mte.moveCameraTo({locX = 30, locY = 30, time = 2000})
]]--


--Example 11:
--[[
--Show parallax layers.
mte.getLayerObj({layer = 5}).alpha = 1
mte.getLayerObj({layer = 6}).alpha = 1

mte.constrainCamera({xAlign = "center", yAlign = "center"})
mte.update()
mte.moveCameraTo({levelPosX = 480, levelPosY = 480, time = 2000})
]]--


--Example 12:
--[[
local mySprite = display.newRect(0, 0, 32, 32)
mte.addSprite(mySprite, {layer = 3, locX = 1, locY = 1})
mte.setCameraFocus(mySprite)
mte.moveSpriteTo({sprite = mySprite, locX = 30, locY = 30, time = 20000})

--By default, the sprite with camera focus pauses during constraint operation.
local constrain = function()
	mte.constrainCamera({time = 1500})
end

timer.performWithDelay(1500, constrain)
]]--


local gameLoop = function(event)
	mte.update()	--Required to process the camera and display the map.
	mte.debug()		--Displays onscreen position/fps/memory text.
end

Runtime:addEventListener("enterFrame", gameLoop)


























