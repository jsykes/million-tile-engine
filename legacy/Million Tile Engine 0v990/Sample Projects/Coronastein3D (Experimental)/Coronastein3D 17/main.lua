--[[
Coronastein3D Build 17 is the most stable, fastest, and most efficient build of CS3D. 
It is limited to a single map layer of perfectly perpendicular walls. This build will
run on iPhone 3GS and weaker Android devices if the resolution (see below) is set
bellow down around 75 and the size of the rooms is kept modest (to control view distance).
]]--

display.setStatusBar( display.HiddenStatusBar )
display.setDefault( "magTextureFilter", "nearest" )
display.setDefault( "minTextureFilter", "nearest" )
system.activate("multitouch")
local abs = math.abs
local mte = require("mte")
local json = require("json")

mte.toggleWorldWrapX(false)
mte.toggleWorldWrapY(false)
--mte.loadMap("cs3Dtest")
mte.loadMap("cs3Dtest2")
local blockScale = 106
local locX = 16
local locY = 11
mte.goto({locX = locX, locY = locY, blockScale = blockScale})
mte.fadeMap(0, 0)
mte.moveCamera(40, 0)

--SETUP D-PAD 1
local controlGroup = display.newGroup()
local DpadBackL = display.newImageRect(controlGroup, "Dpad.png", 200, 200)
DpadBackL.x = 140
DpadBackL.y = display.viewableContentHeight - 140
DpadBackL.alpha = 0.7
DpadBackL:toFront()

--SETUP D-PAD 2
local DpadBackR = display.newImageRect(controlGroup, "Dpad.png", 200, 200)
DpadBackR.x = 884
DpadBackR.y = display.viewableContentHeight - 140
DpadBackR.alpha = 0.7
DpadBackR:toFront()

--======================================================================================--

--Configures the 3D View (required function call)
--	FOV is the field of view; increasing the field of view will gradually add fisheye distortion.
--	Resolution is the number of vertical slices used to display the view, independent of FOV.
--	Changing FOV has no performance impact.
--	Changing Resolution has an enormous performance impact; fewer slices mean fewer calculations and less overhead.
local resolution = 200
local FOV = 60
mte.setupView(FOV, resolution)

--Creates the imagesheets used to generate the 3D perspective (required function call)
mte.createImageSheets()

--Creates the 3D View (required function call)
mte.createView()

--======================================================================================--

local vel = 0
local angularVel = 0
local direction = 0
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
		vel = 0
		angularVel = 0
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
	mte.projection(direction, deflectionY)
		
	mte.debug()

end

DpadBackL:addEventListener("touch", move)
DpadBackR:addEventListener("touch", look)

Runtime:addEventListener("enterFrame", gameLoop)























