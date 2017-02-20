--[[
Coronastein3D Build 48 is the furthest development build of CS3D. It supports animated walls, 
walls of varying transparency and height, multiple map layers (of walls), and angled walls.
This build is incredibly demanding on hardware and will only run at about 9fps on an iPhone 5c.
Further optimizations might be possible in the raycaster algorithm. 
]]--

local mte = require("Coronastein3D.Coronastein3D_48.mte")
local Screen = Screen

local ImgDpad = "Coronastein3D/Coronastein3D_48/Dpad.png"
local MapTest = "Coronastein3D/Coronastein3D_48/cs3Dtest9b"

local abs = math.abs
local json = require("json")

local gradient1 = graphics.newGradient( {55, 55, 55}, {0, 0, 0}, "down")
local gradient2 = graphics.newGradient( {55, 55, 55}, {0, 0, 0}, "up")

local ceiling = display.newRect(display.contentWidth / 2, -50, display.contentWidth, display.contentHeight / 2)
ceiling:setFillColor(gradient1)
ceiling:toBack()

local floor = display.newRect(display.contentWidth / 2, display.contentHeight / 1, display.contentWidth, display.contentHeight / 2)
floor:setFillColor(gradient2)
floor:toBack()

mte.toggleWorldWrapX(false)
mte.toggleWorldWrapY(false)
mte.loadMap( MapTest )
local blockScale = 106
local locX = 16
local locY = 11
mte.goto({locX = locX, locY = locY, blockScale = blockScale})

mte.fadeMap(0, 0)
mte.moveCamera(40, 0)

--SETUP D-PAD 1
local controlGroup = display.newGroup()

local DpadBackL = display.newImageRect(controlGroup, ImgDpad, 120, 120)
DpadBackL.x = Screen.Left + DpadBackL.width*0.5 + 10
DpadBackL.y = Screen.Bottom - DpadBackL.height*0.5 - 10
DpadBackL.alpha = 0.7
DpadBackL:toFront()

--SETUP D-PAD 1
local DpadBackR = display.newImageRect(controlGroup, ImgDpad, 120, 120)
DpadBackR.x = Screen.Right - DpadBackR.width*0.5 - 10
DpadBackR.y = Screen.Bottom - DpadBackR.height*0.5 - 10
DpadBackR.alpha = 0.7
DpadBackR:toFront()

--======================================================================================--

--Configures the 3D View (required function call)
--	fov: the field of view; increasing the field of view will gradually add fisheye distortion.
--	Changing fov has no performance impact.
--	slices: the number of vertical slices used to display the view, independent of fov.
--	Changing slices has an enormous performance impact; fewer slices mean fewer calculations and less overhead.
--	interpolate: turns distance interpolation on or off (broken)
--	layers: sets the number of walls a raycast will penetrate before stopping.
--	If layers = 1 and a ray hits a semi-transparent wall, the ray will stop and wall slices behind it will not render.
mte.setupView({fov = 70, slices = 175, interpolate = false, layers = 3})

--Creates data for walls of varying transparency, height, etc (required function call)
mte.processWalls()

--Creates the imagesheets used to generate the 3D perspective (required function call)
mte.createImageSheets()

--Creates the 3D View (required function call)
mte.createView()

--======================================================================================--

local vel = 0
local angularVel = 0
local direction = 10
local velX
local velY
local deflectionY = 0

local move = function(event)
	if event.phase == "began" then
		display.getCurrentStage():setFocus(event.target, event.id)
		event.target.isFocus = true
	end
	if event.phase == "began" or event.phase == "moved" then		
		local dirX = event.x - event.target.x
		local dirY = event.y - event.target.y		
		vel = dirY / 100 * -1
		angularVel = dirX / 100	
	end
	if event.phase == "ended" or event.phase == "canceled" then
		display.getCurrentStage():setFocus( event.target, nil )
		event.target.isFocus = false
		vel = 0
		angularVel = 0
	end
end

local look = function(event)
	if event.phase == "began" then
		display.getCurrentStage():setFocus(event.target, event.id)
		event.target.isFocus = true
	end
	if event.phase == "began" or event.phase == "moved" then			
		deflectionY = event.y - event.target.y
	end
	if event.phase == "ended" or event.phase == "canceled" then
		display.getCurrentStage():setFocus( event.target, nil )
		event.target.isFocus = false
		deflectionY = 0
	end
end

controlGroup:toFront()
local gameLoop = function(event)
	velX = math.cos(math.rad(direction)) * (vel * 20)
	velY = math.sin(math.rad(direction)) * (vel * 20)
	direction = direction + (angularVel * 5)
	mte.moveCamera(velX, velY)
	mte.update()
	
	--Updates the 3D View (required function call)
	mte.projection(direction, 0)
	mte.cameraZ = mte.cameraZ - deflectionY / 4
	
	mte.debug()
end

DpadBackL:addEventListener("touch", move)
DpadBackR:addEventListener("touch", look)

Runtime:addEventListener("enterFrame", gameLoop)























