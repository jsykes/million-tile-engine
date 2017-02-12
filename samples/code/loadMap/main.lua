-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------
display.setStatusBar( display.HiddenStatusBar )

local mte = require('mte').createMTE()								--Load and instantiate MTE.


--[[
loadMap(src, dir, unload)
Loads a tile map into memory, optionally unloading the previous tile map. 
MTE supports orthographic and isometric maps in Json or TMX format. 
TMX maps may use XML or CSV layer encoding. Generally Json maps are the most space-efficient 
and load the quickest. TMX maps using CSV layer data are somewhat larger and just a little 
slower to load. The advantage of using a TMX map is that the map is easily opened in Tiled, 
modified, saved, and the changes are reflected the next time the map runs; no need to 
export maps as Json files each time.
 
src:        (string) The path to the map file.
 
dir:        (string, optional): “Documents”, “Temporary”, or “Resource”. Defaults to “Resource” if nil.
 
unload:  	(boolean, optional) Specifies whether to unload the previously active map from memory. 
Loading a map stored in memory is far faster than loading a map from device storage.
]]--


--***Uncomment one example at a time.***
--Sample maps have been enlarged to 300x300 tiles to demonstrate memory usage for examples 3a, 3b, and 4.


--Example 1:
--mte.loadMap("forest.tmx")


--Example 2a:
--[[
--Note the terminal output. MTE will search for misplaced tilesets. 
mte.loadMap("map/desert.tmx")
]]--


--Example 2b:
--[[
mte.loadTileSet("worldFlat", "worldFlat.png")
mte.loadMap("map/desert.tmx")
]]--


--Example 3a:
--[[
mte.loadMap("forest.tmx")
mte.loadMap("map/desert.tmx")

collectgarbage()
print("Memory used (MB):", collectgarbage("count") / 1000)
--Note the total memory used with both maps loaded.
]]--


--Example 3b:
--[[
mte.loadMap("forest.tmx")
mte.loadMap("map/desert.tmx", nil, true)	--Unload is set to true.

collectgarbage()
print("Memory used (MB):", collectgarbage("count") / 1000)
--Note the memory used when the previous map is unloaded.
]]--


--Example 4:
--[[
mte.loadTileSet("worldFlat", "worldFlat.png")
print("Load Maps from Device Storage ==========================================")
--Note the Map Load Time(ms) for forest.tmx and desert.tmx in the terminal output.
mte.loadMap("forest.tmx")
mte.loadMap("map/desert.tmx")
print(" ")

local goBack = function()
	print("Load Maps from Active Memory ==========================================")
	--Note the Map Load Time(ms) for forest.tmx and desert.tmx in the terminal output.
	--Each map takes just a tiny fraction of the time to load from active memory.
	mte.loadMap("forest.tmx")
	mte.loadMap("map/desert.tmx")
	mte.setCamera({locX = 11, locY = 11, scale = 2, overDraw = 0.1})
end

timer.performWithDelay(2000, goBack)
]]--


--Example 5:
--[[
mte.loadMap("forest.tmx")
mte.saveMap("forest.tmx", "forest2.json", "Documents")
mte.loadMap("forest2.json", "Documents", true)
]]--


if mte.getMap().layers then
	mte.setCamera({locX = 11, locY = 11, scale = 2, overDraw = 0.1})	--Set the initial camera position and scale.
end

























