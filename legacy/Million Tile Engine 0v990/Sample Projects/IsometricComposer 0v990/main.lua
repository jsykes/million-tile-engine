-- MTE "CASTLE DEMO" ----------------------------------------------------------
display.setStatusBar( display.HiddenStatusBar )

local composer = require("composer")
local myData = require("mydata")
display.setDefault("magTextureFilter", "nearest")
display.setDefault("minTextureFilter", "nearest")
myData.prevMap = "IsoMap3"
myData.nextMap = "IsoMap1"

--SETUP D-PAD ------------------------------------------------------------
myData.controlGroup = display.newGroup()
myData.DpadBack = display.newImageRect(myData.controlGroup, "Dpad2.png", 275, 275)
myData.DpadBack.x = 150
myData.DpadBack.y = display.viewableContentHeight - 150
myData.DpadBack:toFront()

local function move( event )
	if event.phase == "began" then
		display.getCurrentStage():setFocus(event.target, event.id)
		event.target.isFocus = true
	end
	if event.phase == "began" or event.phase == "moved" then
		local dirX = event.x - event.target.x
		local dirY = event.y - event.target.y	
		local angle = math.deg(math.atan(dirY/dirX))
		if dirX < 0 then
			angle = 90 + (90 - (angle * -1))
		end
		angle = angle + 90
		angle = math.round(angle / 45) * 45
		myData.movement = tostring(angle)
	elseif event.phase == "ended" or event.phase == "cancelled" then
		myData.movement = nil
		display.getCurrentStage():setFocus( event.target, nil )
		event.target.isFocus = false
	end
	return true
end

myData.DpadBack:addEventListener("touch", move)

composer.gotoScene("scene")

