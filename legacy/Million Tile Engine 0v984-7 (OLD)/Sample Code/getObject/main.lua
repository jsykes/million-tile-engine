-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------
display.setStatusBar( display.HiddenStatusBar )

local mte = require('mte').createMTE()				--Load and instantiate MTE.

mte.loadMap("map.tmx")								--Load a map.

local mapObj = mte.setCamera({locX = 15, locY = 15, scale = 2})		--Set initial camera position and map scale.

mte.drawObjects()									--Draw the pot and the red polygon.

--[[
getObject(options)
Searches a map’s Tiled objects and returns those objects which match the options set. 
The output will always be a table, even if the table contains just one object.
 
options:        (table) A table of data used to find a specific object to get properties from.
 
Format for options
 
layer:          (number, optional) An Object Layer of the tile map.
 
level:          (number, optional) A level of the tile map which contains an Object Layer.
 
locX:           (optional) The X coordinate of the map location to search for objects.
 
locY:           (optional) The Y coordinate of the map location to search for objects.
 
levelPosX:    	(optional) The X coordinate to search for objects.
 
levelPosY:      (optional) The Y coordinate to search for objects.
 
name:           (string, optional) The unique named assigned to an object in Tiled.
 
type:           (string, optional) The unique type assigned to an object in Tiled.
]]--


--***Uncomment one example at a time.***


--Example 1:
--[[
local potObject = mte.getObject({name = "pot1"})

--getObject() always returns a table, even if the table only contains 1 object.
for key,value in pairs(potObject) do
	print(key,value)
end

print(potObject[1].properties.myProperty)
]]--


--Example 2:
--[[
local potObject = mte.getObject({name = "pot1"})[1]
print(potObject.properties.myProperty)
]]--


--Example 3:
--[[
local objects = mte.getObject({})
for key,value in pairs(objects) do
	print(value.name, value.properties)
end
]]--


--Example 4:
--[[
local objects = mte.getObject({locX = 16, locY = 15})
print(objects[1].name)
]]--


--Example 5a:
--[[
--Retrieving an object by level position requires absolute precision.
local objects = mte.getObject({levelPosX = 498, levelPosY = 467})
--There are no objects at 498,467.
print(objects)
]]--


--Example 5b:
--[[
--Retrieving an object by level position requires absolute precision.
local objects = mte.getObject({levelPosX = 497, levelPosY = 467})
--There is an object at 497,467; the ceramic pot. 
print(objects[1].name)
]]--


--Example 6:
--[[
local polygon = mte.getObject({name = "polygon1"})[1] 
for key,value in pairs(polygon.properties) do
	print(key,value)
end

local newProperties = {lineWidth = "8", lineColor = "[0, 255, 0]"}
polygon.properties = newProperties

mte.redrawObject("polygon1")
]]--


--Example 7:
--[[
local potObject = mte.getObject({name = "pot1"})[1]
potObject.properties.levelWidth = 64
mte.redrawObject("pot1")
]]--



local gameLoop = function(event)
	mte.update()	--Required to process the camera and display the map.
	mte.debug()		--Displays onscreen position/fps/memory text.
end

Runtime:addEventListener("enterFrame", gameLoop)


























