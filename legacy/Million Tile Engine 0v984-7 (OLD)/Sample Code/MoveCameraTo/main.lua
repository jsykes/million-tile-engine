-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------
display.setStatusBar( display.HiddenStatusBar )

local mte = require('mte').createMTE()								--Load and instantiate MTE.

mte.loadMap("map.tmx")												--Load a map.

mte.setCamera({locX = 10, locY = 10, scale = 2, overDraw = 0.1})	--Set the initial camera position and scale.

--[[
moveCameraTo(parameters):
Transitions the camera from one position to another optionally using easing functions. 
Movement is not processed until update() executes. 
Calling update() once every frame in an enterFrame event is recommended.
 
parameters:    (table) Data describing the destination, duration, and easing.

Format for parameters
 
levelPosX:       The X coordinate of the camera’s destination position.
 
levelPosY:       The Y coordinate of the camera’s destination position.
 
sprite:          (optional) A sprite to which the camera should move.
 
locX:            (optional) The X coordinate of the camera’s destination location.
 
locY:            (optional) The Y coordinate of the camera’s destination location.
                       
time:            (optional) The duration of the movement in milliseconds.
 
transition:      (easing, optional) Desired easing function for camera movement i.e. easing.inOutQuad

onComplete:   (listener) Creates a temporary event listener for the camera. 
The listener is triggered when the camera’s current movement is complete.
]]--

--***Uncomment one example at a time.***


--Example 1: 
--mte.moveCameraTo({locX = 20, locY = 20, time = 2000})


--Example 2: 
--mte.moveCameraTo({levelPosX = 624, levelPosY = 624, time = 4000, transition = easing.inOutExpo})


--Example 3: 
--[[
local mySprite = display.newRect(0, 0, 32, 32)
mte.addSprite(mySprite, {layer = 3, locX = 20, locY = 20})

mte.moveCameraTo({sprite = mySprite, time = 2000, transition = easing.outInCubic})
]]--


--Example 4:
--[[
local moveBack = function(event)
	mte.moveCameraTo({locX = 10, locY = 10, time = 2500})
end

mte.moveCameraTo({locX = 20, locY = 20, time = 2500, onComplete = moveBack})
]]--


--Example 5:
--[[
local move1, move2

move1 = function(event)
	mte.moveCameraTo({locX = 20, locY = 20, time = 2500, transition = easing.inOutExpo, onComplete = move2})
end

move2 = function(event)
	mte.moveCameraTo({locX = 10, locY = 10, time = 2500, transition = easing.inOutExpo, onComplete = move1})
end

move1()
]]--


--Example 6:
--[[
mte.moveCameraTo({locX = 20, locY = 20, time = 3000})

local cancelMovement = function(event)
	mte.cancelCameraMove()
	mte.moveCameraTo({locX = 20, locY = 10, time = 1500})
end

timer.performWithDelay(1500, cancelMovement)
]]--


local gameLoop = function(event)
	mte.update()	--Required to process camera movement.
	mte.debug()		--Displays onscreen position/fps/memory text.
end

Runtime:addEventListener("enterFrame", gameLoop)