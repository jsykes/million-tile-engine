-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------
display.setStatusBar( display.HiddenStatusBar )

local mte = require('mte').createMTE()								--Load and instantiate MTE.

mte.loadMap("map.tmx")

mte.setCamera({locX = 15, locY = 15, scale = 1.5, overDraw = 0.1})	--Set the initial camera position and scale.


--[[
getTilesWithProperty(key, value, level, layer)
Returns a table of all the tile objects matching the function arguments.
 
key:      	(string) The desired property. For example, “groundType”.
 
value:   	(string, optional) The value of the property. For example, “mud”.
 
level:    	(number, optional) The level of the tile map in which to search.
 
layer:   	(number, optional) The layer of the tile map in which to search.
]]--


--***Uncomment one example at a time.***


--Example 1:
--[[
local tiles = mte.getTilesWithProperty("groundType", "stonePath", 2)
for key,value in pairs(tiles) do
	local tile = value
	tile:setFillColor(1, 0, 0)
end
]]--


--Example 2:
--[[
local tiles = mte.getTilesWithProperty("groundType", "stonePath")
for key,value in pairs(tiles) do
	local tile = value
	tile:setFillColor(1, 0, 0)
end
]]--


--Example 3:
--[[
local tiles = mte.getTilesWithProperty("groundType")
for key,value in pairs(tiles) do
	local tile = value
	tile:setFillColor(1, 0, 0)
end
]]--


--Example 4:
--[[
local tiles = mte.getTilesWithProperty("plantType", "bush")
for key,value in pairs(tiles) do
	local tile = value
	tile.xScale = 2
	tile.yScale = 2
end
]]--


--Example 5:
--[[
local tiles = mte.getTilesWithProperty()
for key,value in pairs(tiles) do
	local tile = value
	if tile.properties.groundType == "stonePath" then
		tile:setFillColor(0, 1, 0)
	elseif tile.properties.groundType == "grass" then
		tile:setFillColor(1, 0, 0)
	elseif tile.properties.groundType == "dirt" then
		tile:setFillColor(0, 0, 1)
	end
	
	print(" ")
	for key,value in pairs(tile.properties) do
		print(key, value)
	end
end
]]--


local gameLoop = function(event)
	mte.update()	--Required to process camera and display map.
	mte.debug()		--Displays onscreen position/fps/memory text.
end

Runtime:addEventListener("enterFrame", gameLoop)