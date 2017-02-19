-- MTE "CASTLE DEMO" ----------------------------------------------------------
local composer = require("composer")

local myData = require("RotateConstrainComposer.mydata")
myData.prevMap = nil
myData.nextMap = "map1"

--SETUP D-PAD ------------------------------------------------------------
myData.controlGroup = display.newGroup()
myData.DpadBack = display.newImageRect(myData.controlGroup, "RotateConstrainComposer/Dpad.png", 100, 100)

myData.DpadBack.x = Screen.Left + myData.DpadBack.width*0.5 + 10
myData.DpadBack.y = Screen.Bottom - myData.DpadBack.height*0.5 - 10

myData.DpadUp = display.newRect(myData.controlGroup, myData.DpadBack.x - 0, myData.DpadBack.y - 31, 33, 33)
myData.DpadDown = display.newRect(myData.controlGroup, myData.DpadBack.x - 0, myData.DpadBack.y + 31, 33, 33)
myData.DpadLeft = display.newRect(myData.controlGroup, myData.DpadBack.x - 31, myData.DpadBack.y - 0, 33, 33)
myData.DpadRight = display.newRect(myData.controlGroup, myData.DpadBack.x + 31, myData.DpadBack.y - 0, 33, 33)
myData.DpadBack:toFront()

composer.gotoScene("RotateConstrainComposer.scene")

