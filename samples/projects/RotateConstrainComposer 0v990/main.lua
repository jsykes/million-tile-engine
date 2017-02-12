-- MTE "CASTLE DEMO" ----------------------------------------------------------
display.setStatusBar( display.HiddenStatusBar )

local composer = require("composer")
local myData = require("mydata")

myData.prevMap = nil
myData.nextMap = "map1"

--SETUP D-PAD ------------------------------------------------------------
myData.controlGroup = display.newGroup()
myData.DpadBack = display.newImageRect(myData.controlGroup, "Dpad.png", 100, 100)
myData.DpadBack.x = 70
myData.DpadBack.y = display.viewableContentHeight - 70
myData.DpadUp = display.newRect(myData.controlGroup, myData.DpadBack.x - 0, myData.DpadBack.y - 31, 33, 33)
myData.DpadDown = display.newRect(myData.controlGroup, myData.DpadBack.x - 0, myData.DpadBack.y + 31, 33, 33)
myData.DpadLeft = display.newRect(myData.controlGroup, myData.DpadBack.x - 31, myData.DpadBack.y - 0, 33, 33)
myData.DpadRight = display.newRect(myData.controlGroup, myData.DpadBack.x + 31, myData.DpadBack.y - 0, 33, 33)
myData.DpadBack:toFront()

composer.gotoScene("scene")

