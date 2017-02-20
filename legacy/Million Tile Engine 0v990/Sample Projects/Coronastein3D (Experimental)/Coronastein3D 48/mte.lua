--mte 0v728

local M = {}
 
local json = require("json")
local ceil = math.ceil
local floor = math.floor
local abs = math.abs

local tileSets = {}
local loadedTileSets = {}
local tileSetNames = {}
local map = {}
local worldSizeX
local worldSizeY
local layerWidth = {}
local layerHeight = {}
local imageDirectory = ""
local displayGroups = {}
local masterGroup
local refLayer
local objects = {}
local numObjects = 0
local spriteLayers = {}
local objectLayers = {}
local source
local movingSprites = {}
--local worldScale
local worldScaleX
local worldScaleY
--local scaleFactor
local scaleFactorX
local scaleFactorY
local prevScaleFactorX
local prevScaleFactorY
local frameMod = display.fps / 30
local frameTime = 1 / display.fps * 1000
local syncData = {}
local animatedTiles = {}
local correctTileSetSources = false
local fadingTiles = {}
local tintingTiles = {}

--CAMERA POSITION VARIABLES
local cameraX = {}
local cameraY = {}
M.cameraZ = 53
local cameraLocX = {}
local cameraLocY = {}
local prevLocX = {}
local prevLocY = {}
local tempLocX = {}
local tempLocY = {}

local displayWidth
local displayHeight
local cameraFocus
local isCameraMoving
local deltaX
local deltaY
local cameraBusy = 0
local worldWrapX = false
local worldWrapY = false
local layerWrapX = {}
local layerWrapY = {}
local currentScale
local deltaZoom

--DISPLAY GRID VARIABLES
--local blockScale
local blockScaleX
local blockScaleY
local rectsLeft
local rectsOffsetX = {}
local rectsTop
local rectsOffsetY = {}
local rectsWidth = {}
local rectsHeight = {}
local totalRects = {}
local rectCount
local rects = {}
local rect1LocX = {}
local rect1LocY = {}

--GRID SHIFT VARIABLES
local shiftHorizontal
local shiftVertical
local isShifting
local anchorX = {}
local anchorY = {}
 
--DEBUG
local debugX
local debugY
local debugLocX
local debugLocY
local debugVelX
local debugVelY
local debugAccX
local debugAccY
local debugLoading
local debugMemory
local debugFPS
local debugText
local frameRate
local frameArray = {}
local avgFrame = 1
local lowFrame = 100

--FUNCTIONS
local moveCamera 
local moveCameraProc
local goto
local convert
 
-----------------------------------------------------------
--CoronaStein3D

local interpolate = false
local viewLayers = 1
local view = {}
local viewParams = {}
viewParams.width = display.contentWidth
viewParams.height = display.contentHeight
viewParams.left = display.contentWidth / 2 - (viewParams.width / 2)
viewParams.y = display.contentHeight / 2 -- - (viewParams.height / 2)
viewParams.layers = 1
local propLookup = {}
 
local fov = 90
local cameraDirection = 0
local slices = 100
local gcStep = slices / 8 + 10
local sliceSize = fov / slices
local sliceGroup = display.newGroup()
local distGroup = {}
--local sliceWidth = display.viewableContentWidth / slices
local sliceWidth = viewParams.width / slices
local sliceSchedule = {}
local sliceSchedule2 = {}
local sliceSeq = {}
local sliceFrame = {}
local sliceDistance = {}
local sliceLoc = {}
local sliceIndex3 = {}
local sliceIndex4 = {}
local sliceTile = {}
local sliceData = {}
local sliceAlpha = {}
local sliceHeight = {}
local sliceY = {}
local sliceWallID = {}
local sliceOrientation = {}
local distToProjection = (slices * 0.5) / math.tan(math.rad(fov))

local blockScaleZ = {}
--local sliceSheets = {}
local wallSheet = {}
local wallSheetFrames

--local contentHeight = viewHeight
--local halfContentHeight = viewHeight / 2
local toRadian = 0.01745329251994
local toWidth = math.tan(math.rad(sliceSize * 0.5)) * 2
local renderDistance = 20
--local widthMod
--local toAngleD = {}
local constant = {}

local getCamera = function()
	return {cameraX[refLayer], cameraY[refLayer], cameraLocX[refLayer], cameraLocY[refLayer]}
end
M.getCamera = getCamera

local setupView = function(parameters)
	if parameters.width then
		viewParams.width = parameters.width
	end
	if parameters.height then
		viewParams.height = parameters.height
	end
	if parameters.x then
		viewParams.left = parameters.x - (viewParams.width / 2)
	else
		viewParams.left = display.contentWidth / 2 - (viewParams.width / 2)
	end
	if parameters.y then
		viewParams.y = parameters.y
	else
		viewParams.y = display.contentHeight / 2 -- - (viewParams.height / 2)
	end
	if parameters.interpolate then
		interpolate = parameters.interpolate
	end
	if parameters.layers then
		viewParams.layers = parameters.layers
		viewLayers = parameters.layers
	end
	
	--blockScaleZ = blockScaleX
	fov = parameters.fov
	slices = parameters.slices
	sliceSize = fov/slices
	sliceWidth = viewParams.width / slices
	distToProjection = (viewParams.width * 0.5) / math.tan(math.rad(fov * 0.5))
	toWidth = math.tan(math.rad(sliceSize * 0.5)) * 2

	for i = 1, 36000, 1 do
		constant[i] = {}
		constant[i].angleR = (i / 100) * toRadian
		constant[i].slope = math.tan(constant[i].angleR)
		constant[i].x = (5 * math.cos(constant[i].angleR))
		constant[i].y = (5 * math.sin(constant[i].angleR))
	end
		
	gcStep = slices / 8 + 10
		
	if not map.layers[2] then
		map.layers[2] = {}
		map.layers[2].objects = nil
		map.layers[2].properties = {}
		map.layers[2].properties.level = 1
	end
	
	map.gridWallData = {}
	
	for layer = 1, #map.layers, 1 do
		if map.layers[layer].objects then

			map.layers[layer].walls = {}
			for x = 1, worldSizeX, 1 do
				map.layers[layer].walls[x] = {}
			end
			
		end
	end
		
	local endgids = {999}
	for i = 1, #map.tilesets, 1 do
		if i > 1 then
			endgids[i - 1] = map.tilesets[i].firstgid
		end
	end
	
	for i = 1, #map.tilesets, 1 do
		if not map.tilesets[i].tileproperties then
			map.tilesets[i].tileproperties = {}
		end
		
		for j = map.tilesets[i].firstgid, endgids[i], 1 do
			if not map.tilesets[i].tileproperties[tostring(j - 1)] then
				map.tilesets[i].tileproperties[tostring(j - 1)] = {}
			end
			
			if not map.tilesets[i].tileproperties[tostring(j - 1)].renderThrough then
				map.tilesets[i].tileproperties[tostring(j - 1)].renderThrough = false
			end
			if not map.tilesets[i].tileproperties[tostring(j - 1)].zHeight then
				map.tilesets[i].tileproperties[tostring(j - 1)].zHeight = 1
			end
			if not map.tilesets[i].tileproperties[tostring(j - 1)].alpha then
				map.tilesets[i].tileproperties[tostring(j - 1)].alpha = 1
			end
			--[[
			if not map.tilesets[i].tileproperties[tostring(j - 1)].zPosition then
				map.tilesets[i].tileproperties[tostring(j - 1)].zPosition = 1
			end
			]]--
			
			map.gridWallData[j + 0] = {}
			map.gridWallData[j + 0][7] = map.tilesets[i].tileproperties[tostring(j - 1)].renderThrough
			map.gridWallData[j + 0][11] = map.tilesets[i].tileproperties[tostring(j - 1)].zHeight
			map.gridWallData[j + 0][12] = map.tilesets[i].tileproperties[tostring(j - 1)].alpha
		end
	end

	--DETECT NUMBER OF LEVELS
	local levels = 1
	local level = 1
	map.levels = {}
	map.levels[1] = 1
	if map.layers[1].properties.zHeight then
		blockScaleZ[tonumber(map.layers[1].properties.level)] = tonumber(map.layers[1].properties.zHeight)
	else
		blockScaleZ[tonumber(map.layers[1].properties.level)] = blockScaleX
	end
	for i = 1, #map.layers, 1 do
		if map.layers[i].properties then
			if map.layers[i].properties.level then				
				if tonumber(map.layers[i].properties.level) > level then
					levels = levels + 1
					map.levels[levels] = i
					level = tonumber(map.layers[i].properties.level)
					if map.layers[i].properties.zHeight then
						blockScaleZ[level] = tonumber(map.layers[i].properties.zHeight)
					else
						blockScaleZ[level] = blockScaleX
					end
				end
			end
		end
	end
	map.numLevels = levels
	--print(map.numLevels)
	
	--local interpolate = true
	if interpolate then
		--print("A", slices)
		local testMod = slices%8
		if testMod ~= 0 then
			slices = math.floor(slices / 8) * 8 + 1
		else
			slices = slices + 1
		end
		sliceSize = fov/slices
		sliceWidth = viewParams.width / slices
		distToProjection = (viewParams.width * 0.5) / math.tan(math.rad(fov * 0.5))
		toWidth = math.tan(math.rad(sliceSize * 0.5)) * 2
		--print("B", slices)
		
		local count = 1
		for i = 1, slices, 8 do
			sliceSchedule2[count] = {}
			sliceSchedule2[count].slice = i
			sliceSchedule2[count].left = nil
			sliceSchedule2[count].right = nil
			
			sliceSchedule[count] = {}
			sliceSchedule[count].slice = {}
			sliceSchedule[count].left = {}
			sliceSchedule[count].right = {}
			sliceSchedule[count].master = true
			for j = 1, map.numLevels, 1 do
				sliceSchedule[count].slice[j] = {}
				sliceSchedule[count].left[j] = {}
				sliceSchedule[count].right[j] = {}
				for k = 1, viewLayers, 1 do
					sliceSchedule[count].slice[j][k] = i
					sliceSchedule[count].left[j][k] = nil
					sliceSchedule[count].right[j][k] = nil
				end
			end
			
			count = count + 1
		end
		for i = 1, slices, 4 do
			local check = false
			for slice = 1, #sliceSchedule2, 1 do
				if sliceSchedule2[slice].slice == i then
					check = true
					break
				end
			end
			if not check then
				sliceSchedule2[count] = {}
				sliceSchedule2[count].slice = i
				sliceSchedule2[count].left = i - 4
				sliceSchedule2[count].right = i + 4
				
				sliceSchedule[count] = {}
				sliceSchedule[count].slice = {}
				sliceSchedule[count].left = {}
				sliceSchedule[count].right = {}
				for j = 1, map.numLevels, 1 do
					sliceSchedule[count].slice[j] = {}
					sliceSchedule[count].left[j] = {}
					sliceSchedule[count].right[j] = {}
					for k = 1, viewLayers, 1 do
						sliceSchedule[count].slice[j][k] = i
						sliceSchedule[count].left[j][k] = i - 4
						sliceSchedule[count].right[j][k] = i + 4
					end
				end
			
				count = count + 1
			end

			--[[
			local check2 = false
			sliceSchedule[count] = {}
			sliceSchedule[count].slice = {}
			sliceSchedule[count].left = {}
			sliceSchedule[count].right = {}
			for j = 1, map.numLevels, 1 do
				sliceSchedule[count].slice[j] = {}
				sliceSchedule[count].left[j] = {}
				sliceSchedule[count].right[j] = {}
				for k = 1, viewLayers, 1 do
					local check = false
					for slice = 1, #sliceSchedule, 1 do
						if sliceSchedule[slice].slice[j][k] == i then
							check = true
							break
						end
					end
					if not check then
						sliceSchedule[count].slice[j][k] = i
						sliceSchedule[count].left[j][k] = i - 4
						sliceSchedule[count].right[j][k] = i + 4
						check2 = true
					end
				end
			end
			if check2 then
				count = count + 1
			end
			]]--
		end
		for i = 1, slices, 2 do
			local check = false
			for slice = 1, #sliceSchedule2, 1 do
				if sliceSchedule2[slice].slice == i then
					check = true
					break
				end
			end
			if not check then
				sliceSchedule2[count] = {}
				sliceSchedule2[count].slice = i
				sliceSchedule2[count].left = i - 2
				sliceSchedule2[count].right = i + 2
				
				sliceSchedule[count] = {}
				sliceSchedule[count].slice = {}
				sliceSchedule[count].left = {}
				sliceSchedule[count].right = {}
				for j = 1, map.numLevels, 1 do
					sliceSchedule[count].slice[j] = {}
					sliceSchedule[count].left[j] = {}
					sliceSchedule[count].right[j] = {}
					for k = 1, viewLayers, 1 do
						sliceSchedule[count].slice[j][k] = i
						sliceSchedule[count].left[j][k] = i - 2
						sliceSchedule[count].right[j][k] = i + 2
					end
				end
			
				count = count + 1
			end

			--[[
			local check2 = false
			sliceSchedule[count] = {}
			sliceSchedule[count].slice = {}
			sliceSchedule[count].left = {}
			sliceSchedule[count].right = {}
			for j = 1, map.numLevels, 1 do
				sliceSchedule[count].slice[j] = {}
				sliceSchedule[count].left[j] = {}
				sliceSchedule[count].right[j] = {}
				for k = 1, viewLayers, 1 do
					local check = false
					for slice = 1, #sliceSchedule, 1 do
						if sliceSchedule[slice].slice[j][k] == i then
							check = true
							break
						end
					end
					if not check then
						sliceSchedule[count].slice[j][k] = i
						sliceSchedule[count].left[j][k] = i - 2
						sliceSchedule[count].right[j][k] = i + 2
						check2 = true
					end
				end
			end
			if check2 then
				count = count + 1
			end
			]]--
		end
		for i = 1, slices, 1 do
			local check = false
			for slice = 1, #sliceSchedule2, 1 do
				if sliceSchedule2[slice].slice == i then
					check = true
					break
				end
			end
			if not check then
				sliceSchedule2[count] = {}
				sliceSchedule2[count].slice = i
				sliceSchedule2[count].left = i - 1
				sliceSchedule2[count].right = i + 1
				
				sliceSchedule[count] = {}
				sliceSchedule[count].slice = {}
				sliceSchedule[count].left = {}
				sliceSchedule[count].right = {}
				for j = 1, map.numLevels, 1 do
					sliceSchedule[count].slice[j] = {}
					sliceSchedule[count].left[j] = {}
					sliceSchedule[count].right[j] = {}
					for k = 1, viewLayers, 1 do
						sliceSchedule[count].slice[j][k] = i
						sliceSchedule[count].left[j][k] = i - 1
						sliceSchedule[count].right[j][k] = i + 1
					end
				end
			
				count = count + 1
			end

			--[[
			local check2 = false
			sliceSchedule[count] = {}
			sliceSchedule[count].slice = {}
			sliceSchedule[count].left = {}
			sliceSchedule[count].right = {}
			for j = 1, map.numLevels, 1 do
				sliceSchedule[count].slice[j] = {}
				sliceSchedule[count].left[j] = {}
				sliceSchedule[count].right[j] = {}
				for k = 1, viewLayers, 1 do
					local check = false
					for slice = 1, #sliceSchedule, 1 do
						--print("1", i, sliceSchedule[slice].slice[j][k])
						if sliceSchedule[slice].slice[j][k] == i then
							check = true
							break
						end
					end
					if not check then
						sliceSchedule[count].slice[j][k] = i
						sliceSchedule[count].left[j][k] = i - 1
						sliceSchedule[count].right[j][k] = i + 1
						check2 = true
					end
				end
			end
			if check2 then
				count = count + 1
			end
			]]--
		end
		
		--[[
		for i = 1, #sliceSchedule2, 1 do
			print(sliceSchedule2[i].slice, sliceSchedule2[i].left, sliceSchedule2[i].right)
		end
		]]--
		--[[
		for i = 1, #sliceSchedule, 1 do
			for j = 1, map.numLevels, 1 do
				for k = 1, viewLayers, 1 do
					print(sliceSchedule[i].slice[j][k], sliceSchedule[i].left[j][k], sliceSchedule[i].right[j][k])
				end
			end
		end
		]]--
		--print("---")
	end
	
	for i = 1, slices, 1 do
		sliceSeq[i] = {}
		sliceFrame[i] = {}
		sliceDistance[i] = {}
		sliceLoc[i] = {}
		sliceIndex3[i] = {}
		sliceIndex4[i] = {}
		sliceTile[i] = {}
		sliceData[i] = {}
		sliceOrientation[i] = {}
		sliceAlpha[i] = {}
		sliceHeight[i] = {}
		sliceY[i] = {}
		sliceWallID[i] = {}
		for j = 1, map.numLevels, 1 do
			sliceSeq[i][j] = {}
			sliceFrame[i][j] = {}
			sliceDistance[i][j] = {}
			sliceLoc[i][j] = {}
			sliceIndex3[i][j] = {}
			sliceIndex4[i][j] = {}
			sliceTile[i][j] = {}
			sliceData[i][j] = {}
			sliceOrientation[i][j] = {}
			sliceAlpha[i][j] = {}
			sliceHeight[i][j] = {}
			sliceY[i][j] = {}
			sliceWallID[i][j] = {}
		end
	end
end
M.setupView = setupView
 
local count = 0
local createImageSheets = function()
	wallSheet = {}
	local realFrames = (map.tilesets[1].imagewidth / map.tilesets[1].tilewidth) * (map.tilesets[1].imageheight / map.tilesets[1].tileheight)
	local tileX = 0
	local tileY = 0
	for i = 1, realFrames, 1 do
		wallSheet[i] = {}
		wallSheet[i].bookmarks = {}
		local src = map.tilesets[1].image
		local options = {}
		options.sheetContentWidth = map.tilesets[1].imagewidth
		options.sheetContentHeight = map.tilesets[1].imageheight
		options.frames = {}
		
		for j = 1, blockScaleX, 1 do
			local frameWidth = map.tilesets[1].tilewidth / j
			local frameHeight = map.tilesets[1].tileheight
			local frames = j
			wallSheet[i].bookmarks[j] = #options.frames + 1
			local frameX = 0.00000001 + tileX
			local frameY = 0 + tileY
			for k = 1, frames, 1 do
				local fWidth = frameWidth
				options.frames[#options.frames + 1] = {x = frameX, y = frameY, width = fWidth, height = frameHeight}
				frameX = frameX + frameWidth
				if k == frames - 1 then
					fWidth = fWidth - 0.000001
				end
			end
		end
		
		wallSheet[i].sheet = graphics.newImageSheet(src, options)
		wallSheetFrames = #options.frames

		tileX = tileX + map.tilesets[1].tilewidth
		if tileX >= map.tilesets[1].imagewidth then
			tileX = 0
			tileY = tileY + map.tilesets[1].tileheight
		end
		
	end
	
	--[[
	local src = map.tilesets[1].image
	local options = {}
	options.sheetContentWidth = map.tilesets[1].imagewidth
	options.sheetContentHeight = map.tilesets[1].imageheight
	local realFrames = (map.tilesets[1].imagewidth / map.tilesets[1].tilewidth) * (map.tilesets[1].imageheight / map.tilesets[1].tileheight)
	print(map.tilesets[1].imagewidth, map.tilesets[1].imageheight, map.tilesets[1].tilewidth, map.tilesets[1].tileheight, realFrames )
	wallSheet.bookmarks = {}
	options.frames = {}
	for i = 1, blockScaleX, 1 do
		local frameWidth = map.tilesets[1].tilewidth / i
		local frameHeight = map.tilesets[1].tileheight
		local frames = i * realFrames
		wallSheet.bookmarks[i] = #options.frames + 1		
		local numFramesAcross = map.tilesets[1].imagewidth / frameWidth
		local frameX = 0.00000001
		local frameY = 0
		for j = 1, frames, 1 do
			local fWidth = frameWidth
			options.frames[#options.frames + 1] = {x = frameX, y = frameY, width = fWidth, height = frameHeight}
			count = count + 1
			frameX = frameX + frameWidth
			if i == frames - 1 then
				fWidth = fWidth - 0.000001
			end
			if frameX / frameWidth > numFramesAcross then
				frameX = 0
				frameY = frameY + frameHeight
			end
		end
	end
	wallSheet.sheet = graphics.newImageSheet(src, options)
	wallSheetFrames = #options.frames
	--print(count, #options.frames, wallSheetFrames)
	]]--
end
M.createImageSheets = createImageSheets

local createView = function()
	for i = 1, blockScaleX * ( (worldSizeX + worldSizeY) / 2 ), 1 do
		distGroup[i] = display.newGroup()
		sliceGroup:insert(distGroup[i])
		distGroup[i]:toBack()
	end

	if view[1] then
		--destroy view
		for i = 1, slices, 1 do
			view:removSelf()
		end
		view = {}
	end
	
	--local sequenceData = {name = "main", start = 1, count = wallSheetFrames}
	local sequenceData = {}
	local realFrames = (map.tilesets[1].imagewidth / map.tilesets[1].tilewidth) * (map.tilesets[1].imageheight / map.tilesets[1].tileheight)
	for i = 1, realFrames, 1 do
		sequenceData[i] = {}
		sequenceData[i].name = i --tostring(i)
		sequenceData[i].start = 1
		sequenceData[i].count = wallSheetFrames
		sequenceData[i].sheet = wallSheet[i].sheet
	end
	

	for i = 1, slices, 1 do
		view[i] = {}
		view[i][99] = 1
		view[i][98] = viewLayers - 1
		sliceSeq[i] = {}
		sliceFrame[i] = {}
		for j = 1, map.numLevels, 1 do
			view[i][j] = {}
			sliceSeq[i][j] = {}
			sliceFrame[i][j] = {}
			for k = viewLayers, 1, -1 do
				local left = viewParams.left + sliceWidth * (i - 1) + (sliceWidth * 0.5)
				local top = viewParams.height / 2
				local sliceHeight = viewParams.height
				view[i][j][k] = display.newSprite(sliceGroup, wallSheet[1].sheet, sequenceData)
				view[i][j][k].x = left
				view[i][j][k].y = viewParams.y --top
				view[i][j][k].width = sliceWidth
				view[i][j][k].height = sliceHeight
				view[i][j][k]:setSequence(1)
				sliceSeq[i][j][k] = 0
				sliceFrame[i][j][k] = 0
			end
		end
	end
	
	--print(slices * map.numLevels * viewLayers)
end
M.createView = createView

M.totalTests = 0
local projection = function(direction, directionY)
	--print(M.temptotal)
	--M.temptotal = 0
	local round = math.round
	local ceil = math.ceil
	cameraDirection = math.round(direction * 100) / 100
	while cameraDirection < 0 do
		cameraDirection = cameraDirection + 360
	end
	while cameraDirection > 360 do
		cameraDirection = cameraDirection - 360
	end
	M.totalTests = 0
	local cameraX = cameraX[refLayer] - blockScaleX / 2
	local cameraY = cameraY[refLayer] - blockScaleY / 2
	local cLocX = floor(cameraX / blockScaleX)
	local cLocY = floor(cameraY / blockScaleY)
	local tileX = (cLocX - 0) * blockScaleX
	local tileY = (cLocY - 0) * blockScaleY
	local startX = cameraX - tileX
	local startY = cameraY - tileY
	local tileWidth = map.tilesets[1].tilewidth
	local tempSliceDirs = {}
	local numLevels = map.numLevels
	M.numCasts = 0
	if not interpolate then
		for i = 1, slices, 1 do	
			local temp = {}
			local stopXt = {}
			local stopYt = {}
			local wallX = {}
			local wallY = {}
			for j = 1, map.numLevels, 1 do
				wallX[j] = {}
				wallY[j] = {}
				temp[j] = {}
				stopXt[j] = false
				stopYt[j] = false
				for k = 1, viewLayers, 1 do
					view[i][j][k].alpha = 0
				end
			end
			local angleD = sliceSize * (i - (slices / 2)) + cameraDirection
			if angleD == 0 then
				angleD = 0.1
			end
			if angleD < 0 then
				angleD = angleD + 360
			elseif angleD > 360 then
				angleD = angleD - 360
			end
			
			local constIndex =  math.ceil(angleD * 100) -- --angleD * 100
			local angleR = constant[constIndex].angleR
			local slope = constant[constIndex].slope
			local x = constant[constIndex].x
			local y = constant[constIndex].y
			local tempAngle = angleD
			local count = 0			
			local layers = map.layers
			local firstLayer = map.layers[map.levels[1]]
			
			local worldScaleX = worldScaleX
			local worldScaleY = worldScaleY
			local blockScaleX = blockScaleX
			local blockScaleY = blockScaleY
			local toRadian = toRadian
			local mL = map.layers
			local mG = map.gridWallData
			local mLe = map.levels
			local vI = view[i]
			
			local stopX = map.numLevels
			local stopY = map.numLevels
			if x > 0 and y < 0 then
				local angle = (angleD - 270) * toRadian
				local tanAngle = math.tan(angle)
				local checkY = tileY
				local checkX = tanAngle * startY + cameraX
				local deltaY = blockScaleY
				local deltaX = tanAngle * blockScaleY
				local locX, locY = ceil(checkX / blockScaleX), ceil(checkY / blockScaleY)
				if cLocX + 1 <= worldSizeX and cLocX + 1 > 0 and cLocY + 1 <= worldSizeY and cLocY + 1 > 0 then
					for j = 1, map.numLevels, 1 do
						if mL[mLe[j] + 1].walls[cLocX + 1][cLocY + 1] then
							temp[j][#temp[j] + 1] = {cLocX + 1, cLocY + 1, cameraX, cameraY, checkX, checkY, nil, 0}
							M.totalTests = M.totalTests + 1
						end
					end
				end
				
				if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
					for j = 1, map.numLevels, 1 do
						if mL[mLe[j]].world[locX][locY] ~= 0 then					
							wallX[j][#wallX[j] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
							M.totalTests = M.totalTests + 1
							if not mG[mL[mLe[j]].world[locX][locY]][7] then
								stopX = stopX - 1
								stopXt[j] = true
							end
						end
						if mL[mLe[j] + 1].walls[locX][locY] then
							temp[j][#temp[j] + 1] = {locX, locY, checkX, checkY, checkX + deltaX, checkY - deltaY}
							M.totalTests = M.totalTests + 1
						end
					end
				end
				
				if stopX > 0 then
					for j = 1, renderDistance, 1 do
						checkX = checkX + deltaX
						checkY = checkY - deltaY
						locX, locY = ceil(checkX / blockScaleX), locY - 1
						if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
							if numLevels == 1 then
								if mL[mLe[1]].world[locX][locY] ~= 0 then
									wallX[1][#wallX[1] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
									M.totalTests = M.totalTests + 1
									if not mG[mL[mLe[1]].world[locX][locY]][7] then
										break
									end
								end
								if mL[mLe[1] + 1].walls[locX][locY] then
									temp[1][#temp[1] + 1] = {locX, locY, checkX, checkY, checkX + deltaX, checkY - deltaY}
									M.totalTests = M.totalTests + 1
								end
							else
								for k = 1, map.numLevels, 1 do
									if not stopXt[k] then
										if mL[mLe[k]].world[locX][locY] ~= 0 then
											wallX[k][#wallX[k] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
											M.totalTests = M.totalTests + 1
											if not mG[mL[mLe[k]].world[locX][locY]][7] then
												stopX = stopX - 1
												stopXt[k] = true
											end
										end
										if mL[mLe[k] + 1].walls[locX][locY] then
											temp[k][#temp[k] + 1] = {locX, locY, checkX, checkY, checkX + deltaX, checkY - deltaY}
											M.totalTests = M.totalTests + 1
										end
										if stopX <= 0 then
											break
										end
									end
								end
								if stopX <= 0 then
									break
								end
							end
						else
							break
						end	
		
					end
				end
			 
				local angle = (360 - angleD) * toRadian
				local tanAngle = math.tan(angle)
				local checkY = cameraY - (tanAngle * (tileX + blockScaleX - cameraX))
				local checkX = tileX + blockScaleX + 1
				local deltaY = tanAngle * blockScaleX
				local deltaX = blockScaleX
				locX, locY = ceil(checkX / blockScaleX), ceil(checkY / blockScaleY)
				if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
					for j = 1, map.numLevels, 1 do
						if mL[mLe[j]].world[locX][locY] ~= 0 then
							wallY[j][#wallY[j] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
							M.totalTests = M.totalTests + 1
							if not mG[mL[mLe[j]].world[locX][locY]][7] then
								stopY = stopY - 1
								stopYt[j] = true
							end
						end
						if mL[mLe[j] + 1].walls[locX][locY] then
							temp[j][#temp[j] + 1] = {locX, locY, checkX, checkY, checkX + deltaX, checkY - deltaY}
							M.totalTests = M.totalTests + 1
						end
					end
				end

				if stopY > 0 then
					for j = 1, renderDistance, 1 do					
						checkX = checkX + deltaX
						checkY = checkY - deltaY
						locX, locY = locX + 1, ceil(checkY / blockScaleY)
						if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
							if numLevels == 1 then
								if mL[mLe[1]].world[locX][locY] ~= 0 then
									wallY[1][#wallY[1] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
									M.totalTests = M.totalTests + 1
									if not mG[mL[mLe[1]].world[locX][locY]][7] then
										break
									end
								end
								if mL[mLe[1] + 1].walls[locX][locY] then
									temp[1][#temp[1] + 1] = {locX, locY, checkX, checkY, checkX + deltaX, checkY - deltaY}
									M.totalTests = M.totalTests + 1
								end
							else
								for k = 1, map.numLevels, 1 do
									if not stopYt[k] then
										if mL[mLe[k]].world[locX][locY] ~= 0 then
											wallY[k][#wallY[k] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
											M.totalTests = M.totalTests + 1
											if not mG[mL[mLe[k]].world[locX][locY]][7] then
												stopY = stopY - 1
												stopYt[k] = true
											end
										end
										if mL[mLe[k] + 1].walls[locX][locY] then
											temp[k][#temp[k] + 1] = {locX, locY, checkX, checkY, checkX + deltaX, checkY - deltaY}
											M.totalTests = M.totalTests + 1
										end
										if stopY <= 0 then
											break
										end
									end
								end
								if stopY <= 0 then
									break
								end
							end
						else
							break
						end
					end
				end
			end
			if x > 0 and y > 0 then		
				local angle = (90 - angleD) * toRadian
				local checkY = tileY + blockScaleY + 1
				local checkX = math.tan(angle) * (checkY - cameraY) + cameraX
				local deltaY = blockScaleY
				local deltaX = math.tan(angle) * blockScaleY
				local locX, locY = ceil(checkX / blockScaleX), ceil(checkY / blockScaleY)
				local tileXt = locX * blockScaleX
				if cLocX + 1 <= worldSizeX and cLocX + 1 > 0 and cLocY + 1 <= worldSizeY and cLocY + 1 > 0 then
					for j = 1, map.numLevels, 1 do
						if mL[mLe[j] + 1].walls[cLocX + 1][cLocY + 1] then
							temp[j][#temp[j] + 1] = {cLocX + 1, cLocY + 1, cameraX, cameraY, checkX, checkY, nil, 0}
							M.totalTests = M.totalTests + 1
						end
					end
				end 
				
				if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
					for j = 1, map.numLevels, 1 do
						if mL[mLe[j]].world[locX][locY] ~= 0 then
							wallX[j][#wallX[j] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
							M.totalTests = M.totalTests + 1
							if not mG[mL[mLe[j]].world[locX][locY]][7] then
								stopX = stopX - 1
								stopXt[j] = true
							end
						end
						if mL[mLe[j] + 1].walls[locX][locY] then
							temp[j][#temp[j] + 1] = {locX, locY, checkX - 1, checkY, checkX + deltaX - 0, checkY + deltaY, nil, 1}
							M.totalTests = M.totalTests + 1
						end
					end
				end
			
				if stopX > 0 then
					for j = 1, renderDistance, 1 do
						checkX = checkX + deltaX
						checkY = checkY + deltaY
						locX, locY = ceil(checkX / blockScaleX), locY + 1
						if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
							if numLevels == 1 then
								if mL[mLe[1]].world[locX][locY] ~= 0 then
									wallX[1][#wallX[1] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
									M.totalTests = M.totalTests + 1
									if not mG[mL[mLe[1]].world[locX][locY]][7] then
										break
									end
								end
								if mL[mLe[1] + 1].walls[locX][locY] then
									temp[1][#temp[1] + 1] = {locX, locY, checkX - 1, checkY, checkX + deltaX - 0, checkY + deltaY, nil, 2}
									M.totalTests = M.totalTests + 1
								end
							else
								for k = 1, numLevels, 1 do
									if not stopXt[k] then
										if mL[mLe[k]].world[locX][locY] ~= 0 then
											wallX[k][#wallX[k] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
											M.totalTests = M.totalTests + 1
											if not mG[mL[mLe[k]].world[locX][locY]][7] then
												stopX = stopX - 1
												stopXt[k] = true
											end
										end
										if mL[mLe[k] + 1].walls[locX][locY] then
											temp[k][#temp[k] + 1] = {locX, locY, checkX - 1, checkY, checkX + deltaX - 0, checkY + deltaY, nil, 2}
											M.totalTests = M.totalTests + 1
										end
										if stopX <= 0 then
											break
										end
									end
								end
								if stopX <= 0 then
									break
								end
							end
						else
							break
						end		
								
					end
				end

				local angle = angleD * toRadian
				local checkY = math.tan(angle) * (tileX + blockScaleX - cameraX) + cameraY
				local checkX = tileX + blockScaleX + 1
				local deltaY = math.tan(angle) * blockScaleX
				local deltaX = blockScaleX
				locX, locY = ceil(checkX / blockScaleX), ceil(checkY / blockScaleY)
				local tileYt = locY * blockScaleY
				if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
					for j = 1, map.numLevels, 1 do
						if mL[mLe[j]].world[locX][locY] ~= 0 then
							wallY[j][#wallY[j] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
							M.totalTests = M.totalTests + 1
							if not mG[mL[mLe[j]].world[locX][locY]][7] then
								stopY = stopY - 1
								stopYt[j] = true
							end
						end
						if mL[mLe[j] + 1].walls[locX][locY] then
							temp[j][#temp[j] + 1] = {locX, locY, checkX - 1, checkY + 1, checkX + deltaX, checkY + deltaY, nil, 3}
							M.totalTests = M.totalTests + 1
						end
					end
				end
			
				if stopY > 0 then
					for j = 1, renderDistance, 1 do
						checkX = checkX + deltaX
						checkY = checkY + deltaY				
						locX, locY = locX + 1, ceil(checkY / blockScaleY)			
						if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
							if numLevels == 1 then
								if mL[mLe[1]].world[locX][locY] ~= 0 then
									wallY[1][#wallY[1] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
									M.totalTests = M.totalTests + 1
									if not mG[mL[mLe[1]].world[locX][locY]][7] then
										break
									end
								end
								if mL[mLe[1] + 1].walls[locX][locY] then
									temp[1][#temp[1] + 1] = {locX, locY, checkX - 1, checkY + 1, checkX + deltaX, checkY + deltaY, nil, 4}
									M.totalTests = M.totalTests + 1
								end
							else
								for k = 1, numLevels, 1 do
									if not stopYt[k] then
										if mL[mLe[k]].world[locX][locY] ~= 0 then
											wallY[k][#wallY[k] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
											M.totalTests = M.totalTests + 1
											if not mG[mL[mLe[k]].world[locX][locY]][7] then
												stopY = stopY - 1
												stopYt[k] = true
											end
										end
										if mL[mLe[k] + 1].walls[locX][locY] then
											temp[k][#temp[k] + 1] = {locX, locY, checkX - 1, checkY + 1, checkX + deltaX, checkY + deltaY, nil, 4}
											M.totalTests = M.totalTests + 1
										end
										if stopY <= 0 then
											break
										end
									end
								end
								if stopY <= 0 then
									break
								end
							end
						else
							break
						end
					end
				end
			end
			if x < 0 and y > 0 then		
				local angle = (angleD - 90) * toRadian
				local checkY = tileY + blockScaleY + 1
				local checkX = cameraX - (math.tan(angle) * (checkY - cameraY))
				local deltaY = blockScaleY
				local deltaX = math.tan(angle) * blockScaleY
				local locX, locY = ceil(checkX / blockScaleX), ceil(checkY / blockScaleY)
				if cLocX + 1 <= worldSizeX and cLocX + 1 > 0 and cLocY + 1 <= worldSizeY and cLocY + 1 > 0 then
					for j = 1, map.numLevels, 1 do
						if mL[mLe[j] + 1].walls[cLocX + 1][cLocY + 1] then
							temp[j][#temp[j] + 1] = {cLocX + 1, cLocY + 1, cameraX, cameraY, checkX, checkY, nil, 0}
							M.totalTests = M.totalTests + 1
						end
					end
				end 
				
				if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
					for j = 1, map.numLevels, 1 do
						if mL[mLe[j]].world[locX][locY] ~= 0 then
							wallX[j][#wallX[j] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
							M.totalTests = M.totalTests + 1
							if not mG[mL[mLe[j]].world[locX][locY]][7] then
								stopX = stopX - 1
								stopXt[j] = true
							end
						end
						if mL[mLe[j] + 1].walls[locX][locY] then
							temp[j][#temp[j] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY + deltaY}
							M.totalTests = M.totalTests + 1
						end
					end
				end
			
				if stopX > 0 then
					for j = 1, renderDistance, 1 do
						checkX = checkX - deltaX
						checkY = checkY + deltaY
						locX, locY = ceil(checkX / blockScaleX), locY + 1
						if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
							if numLevels == 1 then
								if mL[mLe[1]].world[locX][locY] ~= 0 then
									wallX[1][#wallX[1] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
									M.totalTests = M.totalTests + 1
									if not mG[mL[mLe[1]].world[locX][locY]][7] then
										break
									end
								end
								if mL[mLe[1] + 1].walls[locX][locY] then
									temp[1][#temp[1] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY + deltaY}
									M.totalTests = M.totalTests + 1
								end
							else
								for k = 1, map.numLevels, 1 do
									if not stopXt[k] then
										if mL[mLe[k]].world[locX][locY] ~= 0 then
											wallX[k][#wallX[k] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
											M.totalTests = M.totalTests + 1
											if not mG[mL[mLe[k]].world[locX][locY]][7] then
												stopX = stopX - 1
												stopXt[k] = true
											end
										end
										if mL[mLe[k] + 1].walls[locX][locY] then
											temp[k][#temp[k] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY + deltaY}
											M.totalTests = M.totalTests + 1
										end
										if stopX <= 0 then
											break
										end
									end
								end
								if stopX <= 0 then
									break
								end
							end
						else
							break
						end	
									
					end
				end

				local angle = (180 - angleD) * toRadian
				local checkY = math.tan(angle) * (cameraX - tileX) + cameraY
				local checkX = tileX 
				local deltaY = math.tan(angle) * blockScaleX
				local deltaX = blockScaleX
				locX, locY = ceil(checkX / blockScaleX), ceil(checkY / blockScaleY)
				if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
					for j = 1, map.numLevels, 1 do
						if mL[mLe[j]].world[locX][locY] ~= 0 then
							wallY[j][#wallY[j] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
							M.totalTests = M.totalTests + 1
							if not mG[mL[mLe[j]].world[locX][locY]][7] then
								stopY = stopY - 1
								stopYt[j] = true
							end
						end
						if mL[mLe[j] + 1].walls[locX][locY] then
							temp[j][#temp[j] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY + deltaY}
							M.totalTests = M.totalTests + 1
						end
					end
				end
			
				if stopY > 0 then
					for j = 1, renderDistance, 1 do
						checkX = checkX - deltaX
						checkY = checkY + deltaY
						locX, locY = locX - 1, ceil(checkY / blockScaleY)
						if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
							if numLevels == 1 then
								if mL[mLe[k]].world[locX][locY] ~= 0 then
									wallY[1][#wallY[1] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
									M.totalTests = M.totalTests + 1
									if not mG[mL[mLe[1]].world[locX][locY]][7] then
										break
									end
								end
								if mL[mLe[1] + 1].walls[locX][locY] then
									temp[1][#temp[1] + 1] = {locX, locY, checkX, checkY, checkX - deltaX + 1, checkY + deltaY - 1, nil, 4}
									M.totalTests = M.totalTests + 1
								end
							else
								for k = 1, map.numLevels, 1 do
									if not stopYt[k] then
										if mL[mLe[k]].world[locX][locY] ~= 0 then
											wallY[k][#wallY[k] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
											M.totalTests = M.totalTests + 1
											if not mG[mL[mLe[k]].world[locX][locY]][7] then
												stopY = stopY - 1
												stopYt[k] = true
											end
										end
										if mL[mLe[k] + 1].walls[locX][locY] then
											temp[k][#temp[k] + 1] = {locX, locY, checkX, checkY, checkX - deltaX + 1, checkY + deltaY - 1, nil, 4}
											M.totalTests = M.totalTests + 1
										end
										if stopY <= 0 then
											break
										end
									end
								end
								if stopY <= 0 then
									break
								end
							end
						else
							break
						end					
					end
				end
			end
			if x < 0 and y < 0 then
				local angle = (270 - angleD) * toRadian
				local checkY = tileY
				local checkX = cameraX - (math.tan(angle) * (cameraY - tileY))
				local deltaY = blockScaleY
				local deltaX = math.tan(angle) * blockScaleY
				local locX, locY = ceil(checkX / blockScaleX), ceil(checkY / blockScaleY)
				if cLocX + 1 <= worldSizeX and cLocX + 1 > 0 and cLocY + 1 <= worldSizeY and cLocY + 1 > 0 then
					for j = 1, map.numLevels, 1 do
						if mL[mLe[j] + 1].walls[cLocX + 1][cLocY + 1] then
							temp[j][#temp[j] + 1] = {cLocX + 1, cLocY + 1, cameraX, cameraY, checkX, checkY, nil, 0}
							M.totalTests = M.totalTests + 1
						end
					end
				end 
				
				if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
					for j = 1, map.numLevels, 1 do
						if mL[mLe[j]].world[locX][locY] ~= 0 then
							wallX[j][#wallX[j] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
							M.totalTests = M.totalTests + 1
							if not mG[mL[mLe[j]].world[locX][locY]][7] then
								stopX = stopX - 1
								stopXt[j] = true
							end
						end
						if mL[mLe[j] + 1].walls[locX][locY] then
							temp[j][#temp[j] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY - deltaY}
							M.totalTests = M.totalTests + 1
						end
					end
				end
			
				if stopX > 0 then
					for j = 1, renderDistance, 1 do
						checkX = checkX - deltaX
						checkY = checkY - deltaY
						locX, locY = ceil(checkX / blockScaleX), locY - 1
						if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
							if numLevels == 1 then
								if mL[mLe[1]].world[locX][locY] ~= 0 then
									wallX[1][#wallX[1] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
									M.totalTests = M.totalTests + 1
									if not mG[mL[mLe[1]].world[locX][locY]][7] then
										break
									end
								end
								if mL[mLe[1] + 1].walls[locX][locY] then
									temp[1][#temp[1] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY - deltaY}
									M.totalTests = M.totalTests + 1
								end
							else
								for k = 1, map.numLevels, 1 do
									if not stopXt[k] then
										if mL[mLe[k]].world[locX][locY] ~= 0 then
											wallX[k][#wallX[k] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
											M.totalTests = M.totalTests + 1
											if not mG[mL[mLe[k]].world[locX][locY]][7] then
												stopX = stopX - 1
												stopXt[k] = true
											end
										end
										if mL[mLe[k] + 1].walls[locX][locY] then
											temp[k][#temp[k] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY - deltaY}
											M.totalTests = M.totalTests + 1
										end
										if stopX <= 0 then
											break
										end
									end
								end
								if stopX <= 0 then
									break
								end
							end
						else
							break
						end
										
					end
				end

				local angle = (angleD - 180) * toRadian
				local checkY = cameraY - (math.tan(angle) * (cameraX - tileX))
				local checkX = tileX
				local deltaY = math.tan(angle) * blockScaleX
				local deltaX = blockScaleX
				locX, locY = ceil(checkX / blockScaleX), ceil(checkY / blockScaleY)
				if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
					for j = 1, map.numLevels, 1 do
						if mL[mLe[j]].world[locX][locY] ~= 0 then
							wallY[j][#wallY[j] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
							M.totalTests = M.totalTests + 1
							if not mG[mL[mLe[j]].world[locX][locY]][7] then
								stopY = stopY - 1
								stopYt[j] = true
							end
						end
						if mL[mLe[j] + 1].walls[locX][locY] then
							temp[j][#temp[j] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY - deltaY}
							M.totalTests = M.totalTests + 1
						end
					end
				end
			
				if stopY > 0 then
					for j = 1, renderDistance, 1 do
						checkX = checkX - deltaX
						checkY = checkY - deltaY
						locX, locY = locX - 1, ceil(checkY / blockScaleY)					
						if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
							if numLevels == 1 then
								if mL[mLe[1]].world[locX][locY] ~= 0 then
									wallY[1][#wallY[1] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
									M.totalTests = M.totalTests + 1
									if not mG[mL[mLe[1]].world[locX][locY]][7] then
										break
									end
								end
								if mL[mLe[1] + 1].walls[locX][locY] then
									temp[1][#temp[1] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY - deltaY}
									M.totalTests = M.totalTests + 1
								end
							else
								for k = 1, map.numLevels, 1 do
									if not stopYt[k] then
										if mL[mLe[k]].world[locX][locY] ~= 0 then
											wallY[k][#wallY[k] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
											M.totalTests = M.totalTests + 1
											if not mG[mL[mLe[k]].world[locX][locY]][7] then
												stopY = stopY - 1
												stopYt[k] = true
											end
										end
										if mL[mLe[k] + 1].walls[locX][locY] then
											temp[k][#temp[k] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY - deltaY}
											M.totalTests = M.totalTests + 1
										end
										if stopY <= 0 then
											break
										end
									end
								end
								if stopY <= 0 then
									break
								end
							end
						else
							break
						end
					end
				end
			end
			
			for j = 1, map.numLevels, 1 do
				local distance = {}
				local walls = {}
				local toggle = {}
				local nonRenderThroughExists = false
				local nearestSolid = nil
				
				--FIND TILE WALLS			
				local temp1
				if #wallX[j] > #wallY[j] then
					temp1 = #wallX[j]
				else
					temp1 = #wallY[j]
				end
				for k = 1, temp1, 1 do
					local height = 1
					if wallX[j][k] and wallY[j][k] then
						local distanceH = ((wallX[j][k][3] - cameraX) * (wallX[j][k][3] - cameraX)) + ((wallX[j][k][4] - cameraY) * (wallX[j][k][4] - cameraY))
						local distanceV = ((wallY[j][k][3] - cameraX) * (wallY[j][k][3] - cameraX)) + ((wallY[j][k][4] - cameraY) * (wallY[j][k][4] - cameraY))
						if distanceH < distanceV then
							distance[#distance + 1] = math.sqrt(distanceH)
							walls[#walls + 1] = {}
							walls[#walls][1] = wallX[j][k][1]
							walls[#walls][2] = wallX[j][k][2]
							walls[#walls][3] = wallX[j][k][3]
							walls[#walls][4] = wallX[j][k][4]
							walls[#walls][5] = wallX[j][k][5]
							walls[#walls][6] = wallX[j][k][6]
							walls[#walls][7] = mG[mL[mLe[j]].world[wallX[j][k][1]][wallX[j][k][2]]][7]
							walls[#walls][11] = mG[mL[mLe[j]].world[wallX[j][k][1]][wallX[j][k][2]]][11]
							walls[#walls][12] = mG[mL[mLe[j]].world[wallX[j][k][1]][wallX[j][k][2]]][12]
							walls[#walls][13] = blockScaleZ[j - 1] or 0
							if not walls[#walls][7] then
								nonRenderThroughExists = true
								if nearestSolid then
									if distance[#walls] < distance[nearestSolid] then
										nearestSolid = #walls
									end
								else
									nearestSolid = #walls
								end
							end
							toggle[#toggle + 1] = 1
							sliceOrientation[i] = 1
						else
							distance[#distance + 1] = math.sqrt(distanceV)
							walls[#walls + 1] = {}
							walls[#walls][1] = wallY[j][k][1]
							walls[#walls][2] = wallY[j][k][2]
							walls[#walls][3] = wallY[j][k][3]
							walls[#walls][4] = wallY[j][k][4]
							walls[#walls][5] = wallY[j][k][5]
							walls[#walls][6] = wallY[j][k][6]
							walls[#walls][7] = mG[mL[mLe[j]].world[wallY[j][k][1]][wallY[j][k][2]]][7]
							walls[#walls][11] = mG[mL[mLe[j]].world[wallY[j][k][1]][wallY[j][k][2]]][11]
							walls[#walls][12] = mG[mL[mLe[j]].world[wallY[j][k][1]][wallY[j][k][2]]][12]
							walls[#walls][13] = blockScaleZ[j - 1] or 0
							if not walls[#walls][7] then
								nonRenderThroughExists = true
								if nearestSolid then
									if distance[#walls] < distance[nearestSolid] then
										nearestSolid = #walls
									end
								else
									nearestSolid = #walls
								end
							end
							toggle[#toggle + 1] = 2
							sliceOrientation[i] = 2
						end 
					elseif wallX[j][k] then
						distance[#distance + 1] = math.sqrt( ((wallX[j][k][3] - cameraX) * (wallX[j][k][3] - cameraX)) + ((wallX[j][k][4] - cameraY) * (wallX[j][k][4] - cameraY)) )
						walls[#walls + 1] = {}
						walls[#walls][1] = wallX[j][k][1]
						walls[#walls][2] = wallX[j][k][2]
						walls[#walls][3] = wallX[j][k][3]
						walls[#walls][4] = wallX[j][k][4]
						walls[#walls][5] = wallX[j][k][5]
						walls[#walls][6] = wallX[j][k][6]
						walls[#walls][7] = mG[mL[mLe[j]].world[wallX[j][k][1]][wallX[j][k][2]]][7]
						walls[#walls][11] = mG[mL[mLe[j]].world[wallX[j][k][1]][wallX[j][k][2]]][11]
						walls[#walls][12] = mG[mL[mLe[j]].world[wallX[j][k][1]][wallX[j][k][2]]][12]
						walls[#walls][13] = blockScaleZ[j - 1] or 0
						if not walls[#walls][7] then
							nonRenderThroughExists = true
							if nearestSolid then
								if distance[#walls] < distance[nearestSolid] then
									nearestSolid = #walls
								end
							else
								nearestSolid = #walls
							end
						end
						toggle[#toggle + 1] = 1
						sliceOrientation[i] = 1
					elseif wallY[j][k] then
						distance[#distance + 1] = math.sqrt( ((wallY[j][k][3] - cameraX) * (wallY[j][k][3] - cameraX)) + ((wallY[j][k][4] - cameraY) * (wallY[j][k][4] - cameraY)) )
						walls[#walls + 1] = {}
						walls[#walls][1] = wallY[j][k][1]
						walls[#walls][2] = wallY[j][k][2]
						walls[#walls][3] = wallY[j][k][3]
						walls[#walls][4] = wallY[j][k][4]
						walls[#walls][5] = wallY[j][k][5]
						walls[#walls][6] = wallY[j][k][6]
						walls[#walls][7] = mG[mL[mLe[j]].world[wallY[j][k][1]][wallY[j][k][2]]][7]
						walls[#walls][11] = mG[mL[mLe[j]].world[wallY[j][k][1]][wallY[j][k][2]]][11]
						walls[#walls][12] = mG[mL[mLe[j]].world[wallY[j][k][1]][wallY[j][k][2]]][12]
						walls[#walls][13] = blockScaleZ[j - 1] or 0
						if not walls[#walls][7] then
							nonRenderThroughExists = true
							if nearestSolid then
								if distance[#walls] < distance[nearestSolid] then
									nearestSolid = #walls
								end
							else
								nearestSolid = #walls
							end
						end
						toggle[#toggle + 1] = 2
						sliceOrientation[i] = 2
					else
						sliceOrientation[i] = nil
					end
				end
			 	
				--FIND OBJECT WALLS
				for k = 1, #temp[j], 1 do
					local locX = temp[j][k][1]
					local locY = temp[j][k][2]
					local gridPosX = (locX - 1) * blockScaleX
					local gridPosY = (locY - 1) * blockScaleY
					local x1, y1 = temp[j][k][3] - gridPosX, temp[j][k][4] - gridPosY
					local x2, y2 = temp[j][k][5] - gridPosX, temp[j][k][6] - gridPosY
					local top1, bottom1, left1, right1
					if x1 < x2 then
						left1 = x1 
						right1 = x2 + 100
					else
						left1 = x2 - 100
						right1 = x1 
					end
					if y1 < y2 then
						top1 = y1 
						bottom1 = y2 + 100
					else
						top1 = y2 - 100
						bottom1 = y1 
					end
				
					for m = 1, #mL[mLe[j] + 1].walls[locX][locY], 1 do
						local data = mL[mLe[j] + 1].walls[locX][locY][m]

						local x3, x4 = data[1], data[2]
						local y3, y4 = data[3], data[4]
						local top2, bottom2, left2, right2
						if x3 < x4 then
							left2 = x3
							right2 = x4
						else
							left2 = x4
							right2 = x3
						end
						if y3 < y4 then
							top2 = y3
							bottom2 = y4
						else
							top2 = y4
							bottom2 = y3
						end
						local x12 = x1 - x2
						local x34 = x3 - x4
						local y12 = y1 - y2
						local y34 = y3 - y4
						local c = x12 * y34 - y12 * x34

						--if math.abs(c) >= 0.01 then
						if c >= 0.01 or c <= -0.01 then
							--intersection
							local a = x1 * y2 - y1 * x2
							local b = x3 * y4 - y3 * x4
							local x = (a * x34 - b * x12) / c
							local y = (a * y34 - b * y12) / c
						
							local offset
							if not data[5] then
								local length = math.sqrt(((x3 - x4) * (x3 - x4)) + ((y3 - y4) * (y3 - y4)))
								local offsetLength = data[8] - data[7]
								local factor = offsetLength / length
								local subLength = math.sqrt(((x3 - x) * (x3 - x)) + ((y3 - y) * (y3 - y)))
								offset = blockScaleX - ((subLength * factor) + data[7])
							else
								local length = math.sqrt(((x3 - x4) * (x3 - x4)) + ((y3 - y4) * (y3 - y4)))
								local offsetLength = data[8] - data[7]
								local factor = offsetLength / length
								local subLength = math.sqrt(((x4 - x) * (x4 - x)) + ((y4 - y) * (y4 - y)))
								offset = blockScaleX - ((subLength * factor) + data[7])
							end
							if offset > blockScaleX then
								offset = blockScaleX
							end
						
							local height = 1
							if not data[5] then
								local length = math.sqrt(((x3 - x4) * (x3 - x4)) + ((y3 - y4) * (y3 - y4)))
								local subLength = math.sqrt(((x3 - x) * (x3 - x)) + ((y3 - y) * (y3 - y)))
								height = data[11] + (data[12] - data[11]) * ((subLength - 0) / (length - 0))
							else
								local length = math.sqrt(((x3 - x4) * (x3 - x4)) + ((y3 - y4) * (y3 - y4)))
								local subLength = math.sqrt(((x3 - x) * (x3 - x)) + ((y3 - y) * (y3 - y)))
								height = data[12] + (data[11] - data[12]) * ((subLength - 0) / (length - 0))
							end
						
							local alpha = 1
							if not data[5] then
								local length = math.sqrt(((x3 - x4) * (x3 - x4)) + ((y3 - y4) * (y3 - y4)))
								local subLength = math.sqrt(((x3 - x) * (x3 - x)) + ((y3 - y) * (y3 - y)))
								alpha = data[13] + (data[14] - data[13]) * ((subLength - 0) / (length - 0))
							else
								local length = math.sqrt(((x3 - x4) * (x3 - x4)) + ((y3 - y4) * (y3 - y4)))
								local subLength = math.sqrt(((x3 - x) * (x3 - x)) + ((y3 - y) * (y3 - y)))
								alpha = data[14] + (data[13] - data[14]) * ((subLength - 0) / (length - 0))
							end
							
							local position = blockScaleZ[j - 1] or 0
							if not data[5] then
								local length = math.sqrt(((x3 - x4) * (x3 - x4)) + ((y3 - y4) * (y3 - y4)))
								local subLength = math.sqrt(((x3 - x) * (x3 - x)) + ((y3 - y) * (y3 - y)))
								position = data[15] + (data[16] - data[15]) * ((subLength - 0) / (length - 0))
							else
								local length = math.sqrt(((x3 - x4) * (x3 - x4)) + ((y3 - y4) * (y3 - y4)))
								local subLength = math.sqrt(((x3 - x) * (x3 - x)) + ((y3 - y) * (y3 - y)))
								position = data[16] + (data[15] - data[16]) * ((subLength - 0) / (length - 0))
							end
						
							if temp[j][k][8] ~= 0 then
								if y > top2 - 1 and y < bottom2 + 1  and x > left2 - 1 and x < right2 + 1 then
									distance[#distance + 1] = math.sqrt(((x + gridPosX - cameraX) * (x + gridPosX - cameraX)) + ((y + gridPosY - cameraY) * (y + gridPosY - cameraY)))
									walls[#walls + 1] = {}
									walls[#walls][1] = temp[j][k][1]
									walls[#walls][2] = temp[j][k][2]
									walls[#walls][3] = temp[j][k][3]
									walls[#walls][4] = temp[j][k][4]
									walls[#walls][5] = temp[j][k][5]
									walls[#walls][6] = temp[j][k][6]
									walls[#walls][7] = data[6]
									walls[#walls][8] = offset
									walls[#walls][9] = data[9]
									walls[#walls][10] = data[10]
									walls[#walls][11] = height
									walls[#walls][12] = alpha
									walls[#walls][13] = position
									if not data[6] then
										nonRenderThroughExists = true
										if nearestSolid then
											if distance[#walls] < distance[nearestSolid] then
												nearestSolid = #walls
											end
										else
											nearestSolid = #walls
										end
									end
									toggle[#toggle + 1] = nil
								end
							else
								if y > top2 - 1 and y < bottom2 + 1  and x > left2 - 1 and x < right2 + 1 and
								y > top1 and y < bottom1 and x > left1 and x < right1 then						
									distance[#distance + 1] = math.sqrt(((x + gridPosX - cameraX) * (x + gridPosX - cameraX)) + ((y + gridPosY - cameraY) * (y + gridPosY - cameraY)))
									walls[#walls + 1] = {}
									walls[#walls][1] = temp[j][k][1]
									walls[#walls][2] = temp[j][k][2]
									walls[#walls][3] = temp[j][k][3]
									walls[#walls][4] = temp[j][k][4]
									walls[#walls][5] = temp[j][k][5]
									walls[#walls][6] = temp[j][k][6]
									walls[#walls][7] = data[6]
									walls[#walls][8] = offset
									walls[#walls][9] = data[9]
									walls[#walls][10] = data[10]
									walls[#walls][11] = height
									walls[#walls][12] = alpha
									walls[#walls][13] = position
									if not data[6] then
										nonRenderThroughExists = true
										if nearestSolid then
											if distance[#walls] < distance[nearestSolid] then
												nearestSolid = #walls
											end
										else
											nearestSolid = #walls
										end
									end
									toggle[#toggle + 1] = nil
								end
							end
						end				
					end
				end
			
				local tCount1 = 0
			
				if distance then
					--SORT WALLS
					local order = {}
					for k = 1, #walls, 1 do
						order[k] = k
						--tCount1 = tCount1 + 1
					end
					for k = 1, #walls, 1 do
						for m = 1, #order - 1, 1 do
							if distance[order[m + 1]] < distance[order[m]] then
								local temp = order[m]
								order[m] = order[m + 1]
								order[m + 1] = temp
							end
							tCount1 = tCount1 + 1
						end
					end
					local limit = viewLayers
					if #walls < viewLayers then
						limit = #walls
					end
					for k = 1, #order, 1 do
						--tCount1 = tCount1 + 1
						if order[k] == nearestSolid then
							if k > viewLayers then
								order[viewLayers] = nearestSolid
								limit = viewLayers
							else
								limit = k
							end
							break
						end
					end
					--print(i, tCount1)
				
					for k = 1, limit, 1 do					
						--sliceLoc[i] = {wall[1], wall[2]}
						local index = order[k]
						--print(viewLayers, k, #walls)
						local distance = distance[index]
						local temp = sliceSize * (i - (slices / 2))
						local dist = distance * math.cos(temp * toRadian)
						distance = dist
						local sliceHeight = (blockScaleZ[j] / distance) * distToProjection
						local brightness = (150 * (((blockScaleZ[1] / distance) * distToProjection) / viewParams.height * 0.85) + (255 * 0.15)) + 105
						if brightness > 255 then
							brightness = 255
						end
					
						local wall = walls[index]
						local offset
						local tileID
						local toIndex
						local width
						local index1
					
						if toggle[index] then
							--FIND TILESET FRAME
							local toggle = toggle[index]						
							if x > 0 and y < 0 then
								if toggle == 1 then
									offset = wall[3] % blockScaleX
								elseif toggle == 2 then
									offset = wall[4] % blockScaleY
								end
							end
							if x > 0 and y > 0 then
								if toggle == 1 then
									offset = ((worldSizeX * blockScaleX) - wall[3]) % blockScaleX
								elseif toggle == 2 then
									offset = wall[4] % blockScaleY
								end
							end
							if x < 0 and y > 0 then
								if toggle == 1 then
									offset = ((worldSizeX * blockScaleX) - wall[3]) % blockScaleX
								elseif toggle == 2 then
									offset = ((worldSizeY * blockScaleY) - wall[4]) % blockScaleY
								end
							end
							if x < 0 and y < 0 then
								if toggle == 1 then
									offset = wall[3] % blockScaleX
								elseif toggle == 2 then
									offset = ((worldSizeY * blockScaleY) - wall[4]) % blockScaleY
								end
							end
							tileID = mL[mLe[j]].world[wall[1]][wall[2]]
							toIndex = blockScaleX
							width = distance * toWidth / (toIndex / blockScaleX)
							if width < 1 then
								width = 1
							end
							if width > blockScaleX then
								width = blockScaleX
							end
							index1 = math.ceil(blockScaleX / width)
							if index1 > blockScaleX then
								index1 = blockScaleX
							end
						else
							offset = wall[8]
							tileID = wall[9]
							toIndex = wall[10]
							width = distance * toWidth / (toIndex / blockScaleX)
							if width < 1 then
								width = 1
							end
							if width > blockScaleX then
								width = blockScaleX
							end
							index1 = math.ceil(blockScaleX / width)
							if index1 > blockScaleX then
								index1 = blockScaleX
							end
						end
						
						if syncData[tileID] then
							tileID = syncData[tileID].trueFrames[syncData[tileID].currentFrame]
						end
						
						local index2 = math.ceil(offset / width)
						local index3 = wallSheet[tileID].bookmarks[index1]
						local index4 = math.round(index3 + index2 - 1)
						sliceIndex3[i] = index3
						sliceIndex4[i] = index4

						--DRAW WALL SEGMENT
						local tempDist = math.ceil(distance)
						if tempDist < 1 then
							tempDist = 1
						end
						distGroup[tempDist]:insert(vI[j][k])

						if tileID ~= sliceSeq[i][j][k] then
							vI[j][k]:setSequence(tileID)
							sliceSeq[i][j][k] = tileID
							vI[j][k]:setFrame(index4)
							sliceFrame[i][j][k] = index4
						elseif index4 ~= sliceFrame[i][j][k] then
							vI[j][k]:setFrame(index4)
							sliceFrame[i][j][k] = index4
						end
						
						vI[j][k].alpha = wall[12]
						vI[j][k].height = sliceHeight * wall[11]
						--local posY = blockScaleZ[j - 1] or 0
						--local deltaY = posY - wall[13]
						--local deltaY2 = deltaY * (sliceHeight / blockScaleZ[j])
						vI[j][k].y = (display.contentHeight / 2 - 
										( (sliceHeight * wall[11]/2) - (sliceHeight/2))) - 
										( ((j - 1) * (blockScaleZ[j - 1] or 0)) * (sliceHeight / blockScaleZ[j]) ) - 
										((blockScaleZ[j] / 2 - M.cameraZ) * (sliceHeight / blockScaleZ[j])) - 
										- (((blockScaleZ[j - 1] or 0) - wall[13]) * (sliceHeight / blockScaleZ[j]))     --deltaY2
										
						vI[j][k].width = sliceWidth
						vI[j][k]:setFillColor(brightness, brightness, brightness)
					end
				end	
			
			end		
		end
	else
		local testCount = 0
		for j = 1, #sliceSchedule, 1 do
			--print(sliceSchedule2[j].slice, "-----------------------------------------")
			local cast = false
			local cast2 = {}
			local castExclude = {}

			for k = 1, map.numLevels, 1 do
				for m = 1, viewLayers, 1 do
					view[sliceSchedule[j].slice[k][m]][k][m].alpha = 0
					sliceAlpha[sliceSchedule[j].slice[k][m]][k][m] = 0
					--print(view[sliceSchedule[j].slice[k][m]][k][m])
				end
			end
				
			for k = 1, map.numLevels, 1 do
				castExclude[k] = {}
				for m = 1, viewLayers, 1 do
					local i = sliceSchedule[j].slice[k][m]
					if sliceSchedule[j].left[k][m] and sliceSchedule[j].right[k][m] then
						--compare adjacent rays
						
						if sliceOrientation[sliceSchedule[j].left[k][m]][k][m] and sliceOrientation[sliceSchedule[j].right[k][m]][k][m] and
						sliceOrientation[sliceSchedule[j].left[k][m]][k][m] == sliceOrientation[sliceSchedule[j].right[k][m]][k][m] then

							if (sliceOrientation[sliceSchedule[j].left[k][m]][k][m] == 3 and sliceWallID[sliceSchedule[j].left[k][m]][k][m] == sliceWallID[sliceSchedule[j].right[k][m]][k][m]) or
							(sliceLoc[sliceSchedule[j].left[k][m]][k][m][1] == sliceLoc[sliceSchedule[j].right[k][m]][k][m][1] and
							sliceLoc[sliceSchedule[j].left[k][m]][k][m][2] == sliceLoc[sliceSchedule[j].right[k][m]][k][m][2] ) then 

								local i = sliceSchedule[j].slice[k][m]
								local left = sliceSchedule[j].left[k][m]
								sliceOrientation[i][k][m] = sliceOrientation[left][k][m]
								sliceLoc[i][k][m] = {sliceLoc[left][k][m][1], sliceLoc[left][k][m][2]}
								
								--interpolate distance
								local distance = (sliceDistance[left][k][m] + sliceDistance[sliceSchedule[j].right[k][m]][k][m]) / 2
								sliceDistance[i][k][m] = distance
								
								--local sliceHeight = (blockScaleZ[k] / distance) * distToProjection
								local brightness = (150 * (((blockScaleZ[1] / distance) * distToProjection) / viewParams.height * 0.85) + (255 * 0.15)) + 105
								if brightness > 255 then
									brightness = 255
								end
							
								--interpolate index4
								--sliceData[i] = {width, offset, index1, index2, index3, index4}
						
								local width, offset, index1, index2, index3, index4, tileID
								if sliceData[left][k][m][5] ~= sliceData[sliceSchedule[j].right[k][m]][k][m][5] then
									width = (sliceData[left][k][m][1] + sliceData[sliceSchedule[j].right[k][m]][k][m][1]) / 2
									offset = (sliceData[left][k][m][2] + sliceData[sliceSchedule[j].right[k][m]][k][m][2]) / 2
									tileID = sliceTile[left][k][m]
									index = math.ceil(blockScaleX / width)
									if index > blockScaleX then
										index = blockScaleX
									end
									index2 = math.ceil(offset / width)
									index3 = wallSheet[tileID].bookmarks[index]
									index4 = round(index3 + index2 - 1)
								else
									width = sliceData[left][k][m][1]
									offset = sliceData[left][k][m][2]
									index1 = sliceData[left][k][m][3]
									index2 = sliceData[left][k][m][4]
									index3 = sliceIndex3[left][k][m]
									index4 = (sliceIndex4[left][k][m] + sliceIndex4[sliceSchedule[j].right[k][m]][k][m]) / 2
									tileID = sliceTile[left][k][m]
								end
								sliceIndex3[i][k][m] = index3
								sliceIndex4[i][k][m] = index4
								sliceTile[i][k][m] = tileID
								sliceData[i][k][m] = {width, offset, index1, index2, index3, index4}
								
								if sliceWallID[sliceSchedule[j].left[k][m]][k][m] then
									sliceWallID[i][k][m] = sliceWallID[sliceSchedule[j].left[k][m]][k][m]
								end
								--DRAW WALL SEGMENT
								local tempDist = math.ceil(distance)
								if tempDist < 1 then
									tempDist = 1
								end
								distGroup[tempDist]:insert(view[i][k][m])
								
								if tileID ~= sliceSeq[i][k][m] then
									view[i][k][m]:setSequence(tileID)
									sliceSeq[i][k][m] = tileID
									view[i][k][m]:setFrame(index4)
									sliceFrame[i][k][m] = index4
								elseif index4 ~= sliceFrame[i][k][m] then
									view[i][k][m]:setFrame(index4)
									sliceFrame[i][k][m] = index4
								end
								
								--view[i][k][m].alpha = wall[12]
								local alpha = (sliceAlpha[left][k][m] + sliceAlpha[sliceSchedule[j].right[k][m]][k][m]) / 2
								sliceAlpha[i][k][m] = alpha
								view[i][k][m].alpha = alpha	--* 0.5							
								
								--view[i][k][m].height = sliceHeight * wall[11]
								local height = (sliceHeight[left][k][m] + sliceHeight[sliceSchedule[j].right[k][m]][k][m]) / 2
								sliceHeight[i][k][m] = height
								view[i][k][m].height = height
	
								local y = (sliceY[left][k][m] + sliceY[sliceSchedule[j].right[k][m]][k][m]) / 2
								sliceY[i][k][m] = y
								view[i][k][m].y = y
													
								view[i][k][m].width = sliceWidth
								view[i][k][m]:setFillColor(brightness, brightness, brightness)
								--view[i][k][m]:setFillColor(0, 255, 0)

								castExclude[k][m] = true

							else
								--cast ray
								cast = true
								cast2[k] = true
								--M.numCasts = M.numCasts + 1
								--print(" ", "a", " ",k, m)
								if i == 53 then
									--print("cast1")
								end
							end
						elseif sliceOrientation[sliceSchedule[j].left[k][m]][k][m] and sliceOrientation[sliceSchedule[j].right[k][m]][k][m] then
							--cast ray
							--M.numCasts = M.numCasts + 1
							cast = true
							cast2[k] = true
							--print(" ", "b", " ", k, m)
							if i == 53 then
								--print("cast2", k, m)
							end
						end
					else
						--cast ray
						cast = true
						cast2[k] = true
						--M.numCasts = M.numCasts + 1
						--print(" ", "c", " ", k, m)
					end
					if cast then
						--M.numCasts = M.numCasts + 1
						if i == 49 then
							--print(cast2[k], castExclude[k][m])
						end
						break
					end
				end
			end
			
			if cast then
				M.numCasts = M.numCasts + 1
				testCount = testCount + 1
				i = sliceSchedule[j].slice[1][1]
				--print(i)
				--print("casting ray "..i)
				local temp = {}
				local stopXt = {}
				local stopYt = {}
				local wallX = {}
				local wallY = {}
				for j = 1, map.numLevels, 1 do
					wallX[j] = {}
					wallY[j] = {}
					temp[j] = {}
					stopXt[j] = false
					stopYt[j] = false
					for k = 1, viewLayers, 1 do
						--print(i, view[i])
						--view[i][j][k].alpha = 0
						--sliceAlpha[i][j][k] = 0
					end
				end
				local angleD = sliceSize * (i - (slices / 2)) + cameraDirection
				if angleD == 0 then
					angleD = 0.1
				end
				if angleD < 0 then
					angleD = angleD + 360
				elseif angleD > 360 then
					angleD = angleD - 360
				end
		
				local constIndex =  math.ceil(angleD * 100) -- --angleD * 100
				local angleR = constant[constIndex].angleR
				local slope = constant[constIndex].slope
				local x = constant[constIndex].x
				local y = constant[constIndex].y
				local tempAngle = angleD
				local count = 0			
				local layers = map.layers
				local firstLayer = map.layers[map.levels[1]]
			
				local stopX = map.numLevels
				local stopY = map.numLevels
				if x > 0 and y < 0 then
					local angle = (angleD - 270) * toRadian
					local tanAngle = math.tan(angle)
					local checkY = tileY
					local checkX = tanAngle * startY + cameraX
					local deltaY = blockScaleY
					local deltaX = tanAngle * blockScaleY
					local locX, locY = ceil(checkX / blockScaleX), ceil(checkY / blockScaleY)
					if cLocX + 1 <= worldSizeX and cLocX + 1 > 0 and cLocY + 1 <= worldSizeY and cLocY + 1 > 0 then
						for j = 1, map.numLevels, 1 do
							if not cast2[j] then
								stopXt[j] = true
								stopYt[j] = true
							end
							if map.layers[map.levels[j] + 1].walls[cLocX + 1][cLocY + 1] then
								temp[j][#temp[j] + 1] = {cLocX + 1, cLocY + 1, cameraX, cameraY, checkX, checkY, nil, 0}
								M.totalTests = M.totalTests + 1
							end
						end
					end
				
					if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
						for j = 1, map.numLevels, 1 do
							if map.layers[map.levels[j]].world[locX][locY] ~= 0 then					
								wallX[j][#wallX[j] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
								M.totalTests = M.totalTests + 1
								if not map.gridWallData[map.layers[map.levels[j]].world[locX][locY]][7] then
									stopX = stopX - 1
									stopXt[j] = true
								end
							end
							if map.layers[map.levels[j] + 1].walls[locX][locY] then
								temp[j][#temp[j] + 1] = {locX, locY, checkX, checkY, checkX + deltaX, checkY - deltaY}
								M.totalTests = M.totalTests + 1
							end
						end
					end
				
					if stopX > 0 then
						for j = 1, renderDistance, 1 do
							checkX = checkX + deltaX
							checkY = checkY - deltaY
							locX, locY = ceil(checkX / blockScaleX), locY - 1
							if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
								if numLevels == 1 then
									if cast2[1] then
										if map.layers[map.levels[1]].world[locX][locY] ~= 0 then
											wallX[1][#wallX[1] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
											M.totalTests = M.totalTests + 1
											if not map.gridWallData[map.layers[map.levels[1]].world[locX][locY]][7] then
												break
											end
										end
										if map.layers[map.levels[1] + 1].walls[locX][locY] then
											temp[1][#temp[1] + 1] = {locX, locY, checkX, checkY, checkX + deltaX, checkY - deltaY}
											M.totalTests = M.totalTests + 1
										end
									end
								else
									for k = 1, map.numLevels, 1 do
										if not stopXt[k] then
											if map.layers[map.levels[k]].world[locX][locY] ~= 0 then
												wallX[k][#wallX[k] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
												M.totalTests = M.totalTests + 1
												if not map.gridWallData[map.layers[map.levels[k]].world[locX][locY]][7] then
													stopX = stopX - 1
													stopXt[k] = true
												end
											end
											if map.layers[map.levels[k] + 1].walls[locX][locY] then
												temp[k][#temp[k] + 1] = {locX, locY, checkX, checkY, checkX + deltaX, checkY - deltaY}
												M.totalTests = M.totalTests + 1
											end
											if stopX <= 0 then
												break
											end
										end
									end
									if stopX <= 0 then
										break
									end
								end
							else
								break
							end	
		
						end
					end
			 
					local angle = (360 - angleD) * toRadian
					local tanAngle = math.tan(angle)
					local checkY = cameraY - (tanAngle * (tileX + blockScaleX - cameraX))
					local checkX = tileX + blockScaleX + 1
					local deltaY = tanAngle * blockScaleX
					local deltaX = blockScaleX
					locX, locY = ceil(checkX / blockScaleX), ceil(checkY / blockScaleY)
					if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
						for j = 1, map.numLevels, 1 do
							if map.layers[map.levels[j]].world[locX][locY] ~= 0 then
								wallY[j][#wallY[j] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
								M.totalTests = M.totalTests + 1
								if not map.gridWallData[map.layers[map.levels[j]].world[locX][locY]][7] then
									stopY = stopY - 1
									stopYt[j] = true
								end
							end
							if map.layers[map.levels[j] + 1].walls[locX][locY] then
								temp[j][#temp[j] + 1] = {locX, locY, checkX, checkY, checkX + deltaX, checkY - deltaY}
								M.totalTests = M.totalTests + 1
							end
						end
					end

					if stopY > 0 then
						for j = 1, renderDistance, 1 do					
							checkX = checkX + deltaX
							checkY = checkY - deltaY
							locX, locY = locX + 1, ceil(checkY / blockScaleY)
							if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
								if numLevels == 1 then
									if cast2[1] then
										if map.layers[map.levels[1]].world[locX][locY] ~= 0 then
											wallY[1][#wallY[1] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
											M.totalTests = M.totalTests + 1
											if not map.gridWallData[map.layers[map.levels[1]].world[locX][locY]][7] then
												break
											end
										end
										if map.layers[map.levels[1] + 1].walls[locX][locY] then
											temp[1][#temp[1] + 1] = {locX, locY, checkX, checkY, checkX + deltaX, checkY - deltaY}
											M.totalTests = M.totalTests + 1
										end
									end
								else
									for k = 1, map.numLevels, 1 do
										if not stopYt[k] then
											if map.layers[map.levels[k]].world[locX][locY] ~= 0 then
												wallY[k][#wallY[k] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
												M.totalTests = M.totalTests + 1
												if not map.gridWallData[map.layers[map.levels[k]].world[locX][locY]][7] then
													stopY = stopY - 1
													stopYt[k] = true
												end
											end
											if map.layers[map.levels[k] + 1].walls[locX][locY] then
												temp[k][#temp[k] + 1] = {locX, locY, checkX, checkY, checkX + deltaX, checkY - deltaY}
												M.totalTests = M.totalTests + 1
											end
											if stopY <= 0 then
												break
											end
										end
									end
									if stopY <= 0 then
										break
									end
								end
							else
								break
							end
						end
					end
				end
				if x > 0 and y > 0 then		
					local angle = (90 - angleD) * toRadian
					local checkY = tileY + blockScaleY + 1
					local checkX = math.tan(angle) * (checkY - cameraY) + cameraX
					local deltaY = blockScaleY
					local deltaX = math.tan(angle) * blockScaleY
					local locX, locY = ceil(checkX / blockScaleX), ceil(checkY / blockScaleY)
					local tileXt = locX * blockScaleX
					if cLocX + 1 <= worldSizeX and cLocX + 1 > 0 and cLocY + 1 <= worldSizeY and cLocY + 1 > 0 then
						for j = 1, map.numLevels, 1 do
							if not cast2[j] then
								stopXt[j] = true
								stopYt[j] = true
							end
							if map.layers[map.levels[j] + 1].walls[cLocX + 1][cLocY + 1] then
								temp[j][#temp[j] + 1] = {cLocX + 1, cLocY + 1, cameraX, cameraY, checkX, checkY, nil, 0}
								M.totalTests = M.totalTests + 1
							end
						end
					end 
				
					if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
						for j = 1, map.numLevels, 1 do
							if map.layers[map.levels[j]].world[locX][locY] ~= 0 then
								wallX[j][#wallX[j] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
								M.totalTests = M.totalTests + 1
								if not map.gridWallData[map.layers[map.levels[j]].world[locX][locY]][7] then
									stopX = stopX - 1
									stopXt[j] = true
								end
							end
							if map.layers[map.levels[j] + 1].walls[locX][locY] then
								temp[j][#temp[j] + 1] = {locX, locY, checkX - 1, checkY, checkX + deltaX - 0, checkY + deltaY, nil, 1}
								M.totalTests = M.totalTests + 1
							end
						end
					end
			
					if stopX > 0 then
						for j = 1, renderDistance, 1 do
							checkX = checkX + deltaX
							checkY = checkY + deltaY
							locX, locY = ceil(checkX / blockScaleX), locY + 1
							if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
								if numLevels == 1 then
									if cast2[1] then
										if map.layers[map.levels[1]].world[locX][locY] ~= 0 then
											wallX[1][#wallX[1] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
											M.totalTests = M.totalTests + 1
											if not map.gridWallData[map.layers[map.levels[1]].world[locX][locY]][7] then
												break
											end
										end
										if map.layers[map.levels[1] + 1].walls[locX][locY] then
											temp[1][#temp[1] + 1] = {locX, locY, checkX - 1, checkY, checkX + deltaX - 0, checkY + deltaY, nil, 2}
											M.totalTests = M.totalTests + 1
										end
									end
								else
									for k = 1, numLevels, 1 do
										if not stopXt[k] then
											if map.layers[map.levels[k]].world[locX][locY] ~= 0 then
												wallX[k][#wallX[k] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
												M.totalTests = M.totalTests + 1
												if not map.gridWallData[map.layers[map.levels[k]].world[locX][locY]][7] then
													stopX = stopX - 1
													stopXt[k] = true
												end
											end
											if map.layers[map.levels[k] + 1].walls[locX][locY] then
												temp[k][#temp[k] + 1] = {locX, locY, checkX - 1, checkY, checkX + deltaX - 0, checkY + deltaY, nil, 2}
												M.totalTests = M.totalTests + 1
											end
											if stopX <= 0 then
												break
											end
										end
									end
									if stopX <= 0 then
										break
									end
								end
							else
								break
							end		
								
						end
					end

					local angle = angleD * toRadian
					local checkY = math.tan(angle) * (tileX + blockScaleX - cameraX) + cameraY
					local checkX = tileX + blockScaleX + 1
					local deltaY = math.tan(angle) * blockScaleX
					local deltaX = blockScaleX
					locX, locY = ceil(checkX / blockScaleX), ceil(checkY / blockScaleY)
					local tileYt = locY * blockScaleY
					if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
						for j = 1, map.numLevels, 1 do
							if map.layers[map.levels[j]].world[locX][locY] ~= 0 then
								wallY[j][#wallY[j] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
								M.totalTests = M.totalTests + 1
								if not map.gridWallData[map.layers[map.levels[j]].world[locX][locY]][7] then
									stopY = stopY - 1
									stopYt[j] = true
								end
							end
							if map.layers[map.levels[j] + 1].walls[locX][locY] then
								temp[j][#temp[j] + 1] = {locX, locY, checkX - 1, checkY + 1, checkX + deltaX, checkY + deltaY, nil, 3}
								M.totalTests = M.totalTests + 1
							end
						end
					end
			
					if stopY > 0 then
						for j = 1, renderDistance, 1 do
							checkX = checkX + deltaX
							checkY = checkY + deltaY				
							locX, locY = locX + 1, ceil(checkY / blockScaleY)			
							if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
								if numLevels == 1 then
									if cast2[1] then
										if map.layers[map.levels[1]].world[locX][locY] ~= 0 then
											wallY[1][#wallY[1] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
											M.totalTests = M.totalTests + 1
											if not map.gridWallData[map.layers[map.levels[1]].world[locX][locY]][7] then
												break
											end
										end
										if map.layers[map.levels[1] + 1].walls[locX][locY] then
											temp[1][#temp[1] + 1] = {locX, locY, checkX - 1, checkY + 1, checkX + deltaX, checkY + deltaY, nil, 4}
											M.totalTests = M.totalTests + 1
										end
									end
								else
									for k = 1, numLevels, 1 do
										if not stopYt[k] then
											if map.layers[map.levels[k]].world[locX][locY] ~= 0 then
												wallY[k][#wallY[k] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
												M.totalTests = M.totalTests + 1
												if not map.gridWallData[map.layers[map.levels[k]].world[locX][locY]][7] then
													stopY = stopY - 1
													stopYt[k] = true
												end
											end
											if map.layers[map.levels[k] + 1].walls[locX][locY] then
												temp[k][#temp[k] + 1] = {locX, locY, checkX - 1, checkY + 1, checkX + deltaX, checkY + deltaY, nil, 4}
												M.totalTests = M.totalTests + 1
											end
											if stopY <= 0 then
												break
											end
										end
									end
									if stopY <= 0 then
										break
									end
								end
							else
								break
							end
						end
					end
				end
				if x < 0 and y > 0 then		
					local angle = (angleD - 90) * toRadian
					local checkY = tileY + blockScaleY + 1
					local checkX = cameraX - (math.tan(angle) * (checkY - cameraY))
					local deltaY = blockScaleY
					local deltaX = math.tan(angle) * blockScaleY
					local locX, locY = ceil(checkX / blockScaleX), ceil(checkY / blockScaleY)
					if cLocX + 1 <= worldSizeX and cLocX + 1 > 0 and cLocY + 1 <= worldSizeY and cLocY + 1 > 0 then
						for j = 1, map.numLevels, 1 do
							if not cast2[j] then
								stopXt[j] = true
								stopYt[j] = true
							end
							if map.layers[map.levels[j] + 1].walls[cLocX + 1][cLocY + 1] then
								temp[j][#temp[j] + 1] = {cLocX + 1, cLocY + 1, cameraX, cameraY, checkX, checkY, nil, 0}
								M.totalTests = M.totalTests + 1
							end
						end
					end 
				
					if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
						for j = 1, map.numLevels, 1 do
							if map.layers[map.levels[j]].world[locX][locY] ~= 0 then
								wallX[j][#wallX[j] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
								M.totalTests = M.totalTests + 1
								if not map.gridWallData[map.layers[map.levels[j]].world[locX][locY]][7] then
									stopX = stopX - 1
									stopXt[j] = true
								end
							end
							if map.layers[map.levels[j] + 1].walls[locX][locY] then
								temp[j][#temp[j] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY + deltaY}
								M.totalTests = M.totalTests + 1
							end
						end
					end
			
					if stopX > 0 then
						for j = 1, renderDistance, 1 do
							checkX = checkX - deltaX
							checkY = checkY + deltaY
							locX, locY = ceil(checkX / blockScaleX), locY + 1
							if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
								if numLevels == 1 then
									if cast2[1] then
										if map.layers[map.levels[1]].world[locX][locY] ~= 0 then
											wallX[1][#wallX[1] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
											M.totalTests = M.totalTests + 1
											if not map.gridWallData[map.layers[map.levels[1]].world[locX][locY]][7] then
												break
											end
										end
										if map.layers[map.levels[1] + 1].walls[locX][locY] then
											temp[1][#temp[1] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY + deltaY}
											M.totalTests = M.totalTests + 1
										end
									end
								else
									for k = 1, map.numLevels, 1 do
										if not stopXt[k] then
											if map.layers[map.levels[k]].world[locX][locY] ~= 0 then
												wallX[k][#wallX[k] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
												M.totalTests = M.totalTests + 1
												if not map.gridWallData[map.layers[map.levels[k]].world[locX][locY]][7] then
													stopX = stopX - 1
													stopXt[k] = true
												end
											end
											if map.layers[map.levels[k] + 1].walls[locX][locY] then
												temp[k][#temp[k] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY + deltaY}
												M.totalTests = M.totalTests + 1
											end
											if stopX <= 0 then
												break
											end
										end
									end
									if stopX <= 0 then
										break
									end
								end
							else
								break
							end	
									
						end
					end

					local angle = (180 - angleD) * toRadian
					local checkY = math.tan(angle) * (cameraX - tileX) + cameraY
					local checkX = tileX 
					local deltaY = math.tan(angle) * blockScaleX
					local deltaX = blockScaleX
					locX, locY = ceil(checkX / blockScaleX), ceil(checkY / blockScaleY)
					if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
						for j = 1, map.numLevels, 1 do
							if map.layers[map.levels[j]].world[locX][locY] ~= 0 then
								wallY[j][#wallY[j] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
								M.totalTests = M.totalTests + 1
								if not map.gridWallData[map.layers[map.levels[j]].world[locX][locY]][7] then
									stopY = stopY - 1
									stopYt[j] = true
								end
							end
							if map.layers[map.levels[j] + 1].walls[locX][locY] then
								temp[j][#temp[j] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY + deltaY}
								M.totalTests = M.totalTests + 1
							end
						end
					end
			
					if stopY > 0 then
						for j = 1, renderDistance, 1 do
							checkX = checkX - deltaX
							checkY = checkY + deltaY
							locX, locY = locX - 1, ceil(checkY / blockScaleY)
							if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
								if numLevels == 1 then
									if cast2[1] then
										if map.layers[map.levels[k]].world[locX][locY] ~= 0 then
											wallY[1][#wallY[1] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
											M.totalTests = M.totalTests + 1
											if not map.gridWallData[map.layers[map.levels[1]].world[locX][locY]][7] then
												break
											end
										end
										if map.layers[map.levels[1] + 1].walls[locX][locY] then
											temp[1][#temp[1] + 1] = {locX, locY, checkX, checkY, checkX - deltaX + 1, checkY + deltaY - 1, nil, 4}
											M.totalTests = M.totalTests + 1
										end
									end
								else
									for k = 1, map.numLevels, 1 do
										if not stopYt[k] then
											if map.layers[map.levels[k]].world[locX][locY] ~= 0 then
												wallY[k][#wallY[k] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
												M.totalTests = M.totalTests + 1
												if not map.gridWallData[map.layers[map.levels[k]].world[locX][locY]][7] then
													stopY = stopY - 1
													stopYt[k] = true
												end
											end
											if map.layers[map.levels[k] + 1].walls[locX][locY] then
												temp[k][#temp[k] + 1] = {locX, locY, checkX, checkY, checkX - deltaX + 1, checkY + deltaY - 1, nil, 4}
												M.totalTests = M.totalTests + 1
											end
											if stopY <= 0 then
												break
											end
										end
									end
									if stopY <= 0 then
										break
									end
								end
							else
								break
							end					
						end
					end
				end
				if x < 0 and y < 0 then
					local angle = (270 - angleD) * toRadian
					local checkY = tileY
					local checkX = cameraX - (math.tan(angle) * (cameraY - tileY))
					local deltaY = blockScaleY
					local deltaX = math.tan(angle) * blockScaleY
					local locX, locY = ceil(checkX / blockScaleX), ceil(checkY / blockScaleY)
					if cLocX + 1 <= worldSizeX and cLocX + 1 > 0 and cLocY + 1 <= worldSizeY and cLocY + 1 > 0 then
						for j = 1, map.numLevels, 1 do
							if not cast2[j] then
								stopXt[j] = true
								stopYt[j] = true
							end
							if map.layers[map.levels[j] + 1].walls[cLocX + 1][cLocY + 1] then
								temp[j][#temp[j] + 1] = {cLocX + 1, cLocY + 1, cameraX, cameraY, checkX, checkY, nil, 0}
								M.totalTests = M.totalTests + 1
							end
						end
					end 
				
					if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
						for j = 1, map.numLevels, 1 do
							if map.layers[map.levels[j]].world[locX][locY] ~= 0 then
								wallX[j][#wallX[j] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
								M.totalTests = M.totalTests + 1
								if not map.gridWallData[map.layers[map.levels[j]].world[locX][locY]][7] then
									stopX = stopX - 1
									stopXt[j] = true
								end
							end
							if map.layers[map.levels[j] + 1].walls[locX][locY] then
								temp[j][#temp[j] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY - deltaY}
							end
						end
					end
			
					if stopX > 0 then
						for j = 1, renderDistance, 1 do
							checkX = checkX - deltaX
							checkY = checkY - deltaY
							locX, locY = ceil(checkX / blockScaleX), locY - 1
							if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
								if numLevels == 1 then
									if cast2[1] then
										if map.layers[map.levels[1]].world[locX][locY] ~= 0 then
											wallX[1][#wallX[1] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
											M.totalTests = M.totalTests + 1
											if not map.gridWallData[map.layers[map.levels[1]].world[locX][locY]][7] then
												break
											end
										end
										if map.layers[map.levels[1] + 1].walls[locX][locY] then
											temp[1][#temp[1] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY - deltaY}
											M.totalTests = M.totalTests + 1
										end
									end
								else
									for k = 1, map.numLevels, 1 do
										if not stopXt[k] then
											if map.layers[map.levels[k]].world[locX][locY] ~= 0 then
												wallX[k][#wallX[k] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
												M.totalTests = M.totalTests + 1
												if not map.gridWallData[map.layers[map.levels[k]].world[locX][locY]][7] then
													stopX = stopX - 1
													stopXt[k] = true
												end
											end
											if map.layers[map.levels[k] + 1].walls[locX][locY] then
												temp[k][#temp[k] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY - deltaY}
												M.totalTests = M.totalTests + 1
											end
											if stopX <= 0 then
												break
											end
										end
									end
									if stopX <= 0 then
										break
									end
								end
							else
								break
							end
										
						end
					end

					local angle = (angleD - 180) * toRadian
					local checkY = cameraY - (math.tan(angle) * (cameraX - tileX))
					local checkX = tileX
					local deltaY = math.tan(angle) * blockScaleX
					local deltaX = blockScaleX
					locX, locY = ceil(checkX / blockScaleX), ceil(checkY / blockScaleY)
					if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
						for j = 1, map.numLevels, 1 do
							if map.layers[map.levels[j]].world[locX][locY] ~= 0 then
								wallY[j][#wallY[j] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
								M.totalTests = M.totalTests + 1
								if not map.gridWallData[map.layers[map.levels[j]].world[locX][locY]][7] then
									stopY = stopY - 1
									stopYt[j] = true
								end
							end
							if map.layers[map.levels[j] + 1].walls[locX][locY] then
								temp[j][#temp[j] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY - deltaY}
								M.totalTests = M.totalTests + 1
							end
						end
					end
			
					if stopY > 0 then
						for j = 1, renderDistance, 1 do
							checkX = checkX - deltaX
							checkY = checkY - deltaY
							locX, locY = locX - 1, ceil(checkY / blockScaleY)					
							if locX <= worldSizeX and locX > 0 and locY <= worldSizeY and locY > 0 then
								if numLevels == 1 then
									if cast2[1] then
										if map.layers[map.levels[1]].world[locX][locY] ~= 0 then
											wallY[1][#wallY[1] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
											M.totalTests = M.totalTests + 1
											if not map.gridWallData[map.layers[map.levels[1]].world[locX][locY]][7] then
												break
											end
										end
										if map.layers[map.levels[1] + 1].walls[locX][locY] then
											temp[1][#temp[1] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY - deltaY}
											M.totalTests = M.totalTests + 1
										end
									end
								else
									for k = 1, map.numLevels, 1 do
										if not stopYt[k] then
											if map.layers[map.levels[k]].world[locX][locY] ~= 0 then
												wallY[k][#wallY[k] + 1] = {locX, locY, checkX, checkY, nil, nil, false}
												M.totalTests = M.totalTests + 1
												if not map.gridWallData[map.layers[map.levels[k]].world[locX][locY]][7] then
													stopY = stopY - 1
													stopYt[k] = true
												end
											end
											if map.layers[map.levels[k] + 1].walls[locX][locY] then
												temp[k][#temp[k] + 1] = {locX, locY, checkX, checkY, checkX - deltaX, checkY - deltaY}
												M.totalTests = M.totalTests + 1
											end
											if stopY <= 0 then
												break
											end
										end
									end
									if stopY <= 0 then
										break
									end
								end
							else
								break
							end
						end
					end
				end
			
				for j = 1, map.numLevels, 1 do

					if cast2[j] then

						local distance = {}
						local walls = {}
						local toggle = {}
						local nonRenderThroughExists = false
						local nearestSolid = nil
				
						--FIND TILE WALLS			
						local temp1
						if #wallX[j] > #wallY[j] then
							temp1 = #wallX[j]
						else
							temp1 = #wallY[j]
						end
						for k = 1, temp1, 1 do
							local height = 1
							if wallX[j][k] and wallY[j][k] then
								local distanceH = ((wallX[j][k][3] - cameraX) * (wallX[j][k][3] - cameraX)) + ((wallX[j][k][4] - cameraY) * (wallX[j][k][4] - cameraY))
								local distanceV = ((wallY[j][k][3] - cameraX) * (wallY[j][k][3] - cameraX)) + ((wallY[j][k][4] - cameraY) * (wallY[j][k][4] - cameraY))
								if distanceH < distanceV then
									distance[#distance + 1] = math.sqrt(distanceH)
									walls[#walls + 1] = {}
									walls[#walls][1] = wallX[j][k][1]
									walls[#walls][2] = wallX[j][k][2]
									walls[#walls][3] = wallX[j][k][3]
									walls[#walls][4] = wallX[j][k][4]
									walls[#walls][5] = wallX[j][k][5]
									walls[#walls][6] = wallX[j][k][6]
									walls[#walls][7] = map.gridWallData[map.layers[map.levels[j]].world[wallX[j][k][1]][wallX[j][k][2]]][7]
									walls[#walls][11] = map.gridWallData[map.layers[map.levels[j]].world[wallX[j][k][1]][wallX[j][k][2]]][11]
									walls[#walls][12] = map.gridWallData[map.layers[map.levels[j]].world[wallX[j][k][1]][wallX[j][k][2]]][12]
									walls[#walls][13] = blockScaleZ[j - 1] or 0
									walls[#walls][14] = 1
									if not walls[#walls][7] then
										nonRenderThroughExists = true
										if nearestSolid then
											if distance[#walls] < distance[nearestSolid] then
												nearestSolid = #walls
											end
										else
											nearestSolid = #walls
										end
									end
									toggle[#toggle + 1] = 1
									--sliceOrientation[i][j][k] = 1
									if i == 29 and j == 1 then
										--print("found tile wall", distance[#distance])
									end
								else
									distance[#distance + 1] = math.sqrt(distanceV)
									walls[#walls + 1] = {}
									walls[#walls][1] = wallY[j][k][1]
									walls[#walls][2] = wallY[j][k][2]
									walls[#walls][3] = wallY[j][k][3]
									walls[#walls][4] = wallY[j][k][4]
									walls[#walls][5] = wallY[j][k][5]
									walls[#walls][6] = wallY[j][k][6]
									walls[#walls][7] = map.gridWallData[map.layers[map.levels[j]].world[wallY[j][k][1]][wallY[j][k][2]]][7]
									walls[#walls][11] = map.gridWallData[map.layers[map.levels[j]].world[wallY[j][k][1]][wallY[j][k][2]]][11]
									walls[#walls][12] = map.gridWallData[map.layers[map.levels[j]].world[wallY[j][k][1]][wallY[j][k][2]]][12]
									walls[#walls][13] = blockScaleZ[j - 1] or 0
									walls[#walls][14] = 2
									if not walls[#walls][7] then
										nonRenderThroughExists = true
										if nearestSolid then
											if distance[#walls] < distance[nearestSolid] then
												nearestSolid = #walls
											end
										else
											nearestSolid = #walls
										end
									end
									toggle[#toggle + 1] = 2
									--sliceOrientation[i][j][k] = 2
									if i == 29 and j == 1 then
										--print("found tile wall", distance[#distance])
									end
								end 
							elseif wallX[j][k] then
								distance[#distance + 1] = math.sqrt( ((wallX[j][k][3] - cameraX) * (wallX[j][k][3] - cameraX)) + ((wallX[j][k][4] - cameraY) * (wallX[j][k][4] - cameraY)) )
								walls[#walls + 1] = {}
								walls[#walls][1] = wallX[j][k][1]
								walls[#walls][2] = wallX[j][k][2]
								walls[#walls][3] = wallX[j][k][3]
								walls[#walls][4] = wallX[j][k][4]
								walls[#walls][5] = wallX[j][k][5]
								walls[#walls][6] = wallX[j][k][6]
								walls[#walls][7] = map.gridWallData[map.layers[map.levels[j]].world[wallX[j][k][1]][wallX[j][k][2]]][7]
								walls[#walls][11] = map.gridWallData[map.layers[map.levels[j]].world[wallX[j][k][1]][wallX[j][k][2]]][11]
								walls[#walls][12] = map.gridWallData[map.layers[map.levels[j]].world[wallX[j][k][1]][wallX[j][k][2]]][12]
								walls[#walls][13] = blockScaleZ[j - 1] or 0
								walls[#walls][14] = 1
								if not walls[#walls][7] then
									nonRenderThroughExists = true
									if nearestSolid then
										if distance[#walls] < distance[nearestSolid] then
											nearestSolid = #walls
										end
									else
										nearestSolid = #walls
									end
								end
								toggle[#toggle + 1] = 1
								--sliceOrientation[i][j][k] = 1
								if i == 29 and j == 1 then
									--print("found tile wall", distance[#distance])
								end
							elseif wallY[j][k] then
								distance[#distance + 1] = math.sqrt( ((wallY[j][k][3] - cameraX) * (wallY[j][k][3] - cameraX)) + ((wallY[j][k][4] - cameraY) * (wallY[j][k][4] - cameraY)) )
								walls[#walls + 1] = {}
								walls[#walls][1] = wallY[j][k][1]
								walls[#walls][2] = wallY[j][k][2]
								walls[#walls][3] = wallY[j][k][3]
								walls[#walls][4] = wallY[j][k][4]
								walls[#walls][5] = wallY[j][k][5]
								walls[#walls][6] = wallY[j][k][6]
								walls[#walls][7] = map.gridWallData[map.layers[map.levels[j]].world[wallY[j][k][1]][wallY[j][k][2]]][7]
								walls[#walls][11] = map.gridWallData[map.layers[map.levels[j]].world[wallY[j][k][1]][wallY[j][k][2]]][11]
								walls[#walls][12] = map.gridWallData[map.layers[map.levels[j]].world[wallY[j][k][1]][wallY[j][k][2]]][12]
								walls[#walls][13] = blockScaleZ[j - 1] or 0
								walls[#walls][14] = 2
								if not walls[#walls][7] then
									nonRenderThroughExists = true
									if nearestSolid then
										if distance[#walls] < distance[nearestSolid] then
											nearestSolid = #walls
										end
									else
										nearestSolid = #walls
									end
								end
								toggle[#toggle + 1] = 2
								--sliceOrientation[i][j][k] = 2
								if i == 29 and j == 1 then
									--print("found tile wall", distance[#distance])
								end
							else
								sliceOrientation[i][j][k] = nil
							end
						end
				
						--FIND OBJECT WALLS
						for k = 1, #temp[j], 1 do
							local locX = temp[j][k][1]
							local locY = temp[j][k][2]
							local gridPosX = (locX - 1) * blockScaleX
							local gridPosY = (locY - 1) * blockScaleY
							local x1, y1 = temp[j][k][3] - gridPosX, temp[j][k][4] - gridPosY
							local x2, y2 = temp[j][k][5] - gridPosX, temp[j][k][6] - gridPosY
							local top1, bottom1, left1, right1
							if x1 < x2 then
								left1 = x1 
								right1 = x2 + 100
							else
								left1 = x2 - 100
								right1 = x1 
							end
							if y1 < y2 then
								top1 = y1 
								bottom1 = y2 + 100
							else
								top1 = y2 - 100
								bottom1 = y1 
							end
				
							for m = 1, #map.layers[map.levels[j] + 1].walls[locX][locY], 1 do
								local data = map.layers[map.levels[j] + 1].walls[locX][locY][m]

								local x3, x4 = data[1], data[2]
								local y3, y4 = data[3], data[4]
								local top2, bottom2, left2, right2
								if x3 < x4 then
									left2 = x3
									right2 = x4
								else
									left2 = x4
									right2 = x3
								end
								if y3 < y4 then
									top2 = y3
									bottom2 = y4
								else
									top2 = y4
									bottom2 = y3
								end
								local x12 = x1 - x2
								local x34 = x3 - x4
								local y12 = y1 - y2
								local y34 = y3 - y4
								local c = x12 * y34 - y12 * x34

								--if math.abs(c) >= 0.01 then
								if c >= 0.01 or c <= -0.01 then
									--intersection
									local a = x1 * y2 - y1 * x2
									local b = x3 * y4 - y3 * x4
									local x = (a * x34 - b * x12) / c
									local y = (a * y34 - b * y12) / c
						
									local offset
									if not data[5] then
										local length = math.sqrt(((x3 - x4) * (x3 - x4)) + ((y3 - y4) * (y3 - y4)))
										local offsetLength = data[8] - data[7]
										local factor = offsetLength / length
										local subLength = math.sqrt(((x3 - x) * (x3 - x)) + ((y3 - y) * (y3 - y)))
										offset = blockScaleX - ((subLength * factor) + data[7])
									else
										local length = math.sqrt(((x3 - x4) * (x3 - x4)) + ((y3 - y4) * (y3 - y4)))
										local offsetLength = data[8] - data[7]
										local factor = offsetLength / length
										local subLength = math.sqrt(((x4 - x) * (x4 - x)) + ((y4 - y) * (y4 - y)))
										offset = blockScaleX - ((subLength * factor) + data[7])
									end
									if offset > blockScaleX then
										offset = blockScaleX
									end
						
									local height = 1
									if not data[5] then
										local length = math.sqrt(((x3 - x4) * (x3 - x4)) + ((y3 - y4) * (y3 - y4)))
										local subLength = math.sqrt(((x3 - x) * (x3 - x)) + ((y3 - y) * (y3 - y)))
										height = data[11] + (data[12] - data[11]) * ((subLength - 0) / (length - 0))
									else
										local length = math.sqrt(((x3 - x4) * (x3 - x4)) + ((y3 - y4) * (y3 - y4)))
										local subLength = math.sqrt(((x3 - x) * (x3 - x)) + ((y3 - y) * (y3 - y)))
										height = data[12] + (data[11] - data[12]) * ((subLength - 0) / (length - 0))
									end
						
									local alpha = 1
									if not data[5] then
										local length = math.sqrt(((x3 - x4) * (x3 - x4)) + ((y3 - y4) * (y3 - y4)))
										local subLength = math.sqrt(((x3 - x) * (x3 - x)) + ((y3 - y) * (y3 - y)))
										alpha = data[13] + (data[14] - data[13]) * ((subLength - 0) / (length - 0))
									else
										local length = math.sqrt(((x3 - x4) * (x3 - x4)) + ((y3 - y4) * (y3 - y4)))
										local subLength = math.sqrt(((x3 - x) * (x3 - x)) + ((y3 - y) * (y3 - y)))
										alpha = data[14] + (data[13] - data[14]) * ((subLength - 0) / (length - 0))
									end
							
									local position = blockScaleZ[j - 1] or 0
									if not data[5] then
										local length = math.sqrt(((x3 - x4) * (x3 - x4)) + ((y3 - y4) * (y3 - y4)))
										local subLength = math.sqrt(((x3 - x) * (x3 - x)) + ((y3 - y) * (y3 - y)))
										position = data[15] + (data[16] - data[15]) * ((subLength - 0) / (length - 0))
									else
										local length = math.sqrt(((x3 - x4) * (x3 - x4)) + ((y3 - y4) * (y3 - y4)))
										local subLength = math.sqrt(((x3 - x) * (x3 - x)) + ((y3 - y) * (y3 - y)))
										position = data[16] + (data[15] - data[16]) * ((subLength - 0) / (length - 0))
									end
						
									if temp[j][k][8] ~= 0 then
										if y > top2 - 1 and y < bottom2 + 1  and x > left2 - 1 and x < right2 + 1 then
											distance[#distance + 1] = math.sqrt(((x + gridPosX - cameraX) * (x + gridPosX - cameraX)) + ((y + gridPosY - cameraY) * (y + gridPosY - cameraY)))
											walls[#walls + 1] = {}
											walls[#walls][1] = temp[j][k][1]
											walls[#walls][2] = temp[j][k][2]
											walls[#walls][3] = temp[j][k][3]
											walls[#walls][4] = temp[j][k][4]
											walls[#walls][5] = temp[j][k][5]
											walls[#walls][6] = temp[j][k][6]
											walls[#walls][7] = data[6]
											walls[#walls][8] = offset
											walls[#walls][9] = data[9]
											walls[#walls][10] = data[10]
											walls[#walls][11] = height
											walls[#walls][12] = alpha
											walls[#walls][13] = position
											walls[#walls][14] = 3
											walls[#walls][15] = data[17]
											if not data[6] then
												nonRenderThroughExists = true
												if nearestSolid then
													if distance[#walls] < distance[nearestSolid] then
														nearestSolid = #walls
													end
												else
													nearestSolid = #walls
												end
											end
											toggle[#toggle + 1] = nil
											--sliceOrientation[i][j][k] = 3
											if i == 29 and j == 1 then
												--print("found object wall", distance[#distance])
											end
										end
									else
										if y > top2 - 1 and y < bottom2 + 1  and x > left2 - 1 and x < right2 + 1 and
										y > top1 and y < bottom1 and x > left1 and x < right1 then						
											distance[#distance + 1] = math.sqrt(((x + gridPosX - cameraX) * (x + gridPosX - cameraX)) + ((y + gridPosY - cameraY) * (y + gridPosY - cameraY)))
											walls[#walls + 1] = {}
											walls[#walls][1] = temp[j][k][1]
											walls[#walls][2] = temp[j][k][2]
											walls[#walls][3] = temp[j][k][3]
											walls[#walls][4] = temp[j][k][4]
											walls[#walls][5] = temp[j][k][5]
											walls[#walls][6] = temp[j][k][6]
											walls[#walls][7] = data[6]
											walls[#walls][8] = offset
											walls[#walls][9] = data[9]
											walls[#walls][10] = data[10]
											walls[#walls][11] = height
											walls[#walls][12] = alpha
											walls[#walls][13] = position
											walls[#walls][14] = 3
											walls[#walls][15] = data[17]
											if not data[6] then
												nonRenderThroughExists = true
												if nearestSolid then
													if distance[#walls] < distance[nearestSolid] then
														nearestSolid = #walls
													end
												else
													nearestSolid = #walls
												end
											end
											toggle[#toggle + 1] = nil
											--sliceOrientation[i][j][k] = 3
											if i == 29 and j == 1 then
												--print("found object wall", distance[#distance])
											end
										end
									end
								end				
							end
						end
						
						local tCount1 = 0
			
						if distance then
							--SORT WALLS
							local order = {}
							for k = 1, #walls, 1 do
								order[k] = k
								--tCount1 = tCount1 + 1
							end
							for k = 1, #walls, 1 do
								for m = 1, #order - 1, 1 do
									if distance[order[m + 1]] < distance[order[m]] then
										local temp = order[m]
										order[m] = order[m + 1]
										order[m + 1] = temp
									end
									tCount1 = tCount1 + 1
								end
							end
							local limit = viewLayers
							if #walls < viewLayers then
								limit = #walls
							end
							for k = 1, #order, 1 do
								--tCount1 = tCount1 + 1
								if order[k] == nearestSolid then
									if k > viewLayers then
										order[viewLayers] = nearestSolid
										limit = viewLayers
									else
										limit = k
									end
									break
								end
							end
							--print(i, tCount1)

							for k = 1, limit, 1 do	
								if not castExclude[j][k] then
		
									--sliceLoc[i] = {wall[1], wall[2]}
									local index = order[k]
									--print(viewLayers, k, #walls)
									local distance = distance[index]
									local temp = sliceSize * (i - (slices / 2))
									local dist = distance * math.cos(temp * toRadian)
									distance = dist
									local sliceHeight1 = (blockScaleZ[j] / distance) * distToProjection
									local brightness = (150 * (((blockScaleZ[1] / distance) * distToProjection) / viewParams.height * 0.85) + (255 * 0.15)) + 105
									if brightness > 255 then
										brightness = 255
									end
					
									local wall = walls[index]
									local offset
									local tileID
									local toIndex
									local width
									local index1
					
									if toggle[index] then
										--FIND TILESET FRAME
										local toggle = toggle[index]						
										if x > 0 and y < 0 then
											if toggle == 1 then
												offset = wall[3] % blockScaleX
											elseif toggle == 2 then
												offset = wall[4] % blockScaleY
											end
										end
										if x > 0 and y > 0 then
											if toggle == 1 then
												offset = ((worldSizeX * blockScaleX) - wall[3]) % blockScaleX
											elseif toggle == 2 then
												offset = wall[4] % blockScaleY
											end
										end
										if x < 0 and y > 0 then
											if toggle == 1 then
												offset = ((worldSizeX * blockScaleX) - wall[3]) % blockScaleX
											elseif toggle == 2 then
												offset = ((worldSizeY * blockScaleY) - wall[4]) % blockScaleY
											end
										end
										if x < 0 and y < 0 then
											if toggle == 1 then
												offset = wall[3] % blockScaleX
											elseif toggle == 2 then
												offset = ((worldSizeY * blockScaleY) - wall[4]) % blockScaleY
											end
										end
										tileID = map.layers[map.levels[j]].world[wall[1]][wall[2]]
										toIndex = blockScaleX
										width = distance * toWidth / (toIndex / blockScaleX)
										if width < 1 then
											width = 1
										end
										if width > blockScaleX then
											width = blockScaleX
										end
										index1 = math.ceil(blockScaleX / width)
										if index1 > blockScaleX then
											index1 = blockScaleX
										end
									else
										offset = wall[8]
										tileID = wall[9]
										toIndex = wall[10]
										width = distance * toWidth / (toIndex / blockScaleX)
										if width < 1 then
											width = 1
										end
										if width > blockScaleX then
											width = blockScaleX
										end
										index1 = math.ceil(blockScaleX / width)
										if index1 > blockScaleX then
											index1 = blockScaleX
										end
									end
						
									if syncData[tileID] then
										tileID = syncData[tileID].trueFrames[syncData[tileID].currentFrame]
									end
						
									local index2 = math.ceil(offset / width)
									local index3 = wallSheet[tileID].bookmarks[index1]
									local index4 = math.round(index3 + index2 - 1)
								
									sliceLoc[i][j][k] = {wall[1], wall[2]}

									sliceDistance[i][j][k] = distance
									sliceIndex3[i][j][k] = index3
									sliceIndex4[i][j][k] = index4
									sliceTile[i][j][k] = tileID
									sliceData[i][j][k] = {width, offset, index1, index2, index3, index4}
									sliceOrientation[i][j][k] = wall[14]
									sliceWallID[i][j][k] = wall[15]
									sliceAlpha[i][j][k] = wall[12]
									sliceHeight[i][j][k] = sliceHeight1 * wall[11]
									sliceY[i][j][k] = (display.contentHeight / 2 - 
													( (sliceHeight1 * wall[11]/2) - (sliceHeight1/2))) - 
													( ((j - 1) * (blockScaleZ[j - 1] or 0)) * (sliceHeight1 / blockScaleZ[j]) ) - 
													((blockScaleZ[j] / 2 - M.cameraZ) * (sliceHeight1 / blockScaleZ[j])) - 
													- (((blockScaleZ[j - 1] or 0) - wall[13]) * (sliceHeight1 / blockScaleZ[j]))     --deltaY2
								
								
									--DRAW WALL SEGMENT
									local tempDist = math.ceil(distance)
									if tempDist < 1 then
										tempDist = 1
									end
									distGroup[tempDist]:insert(view[i][j][k])

									if tileID ~= sliceSeq[i][j][k] then
										view[i][j][k]:setSequence(tileID)
										sliceSeq[i][j][k] = tileID
										view[i][j][k]:setFrame(index4)
										sliceFrame[i][j][k] = index4
									elseif index4 ~= sliceFrame[i][j][k] then
										view[i][j][k]:setFrame(index4)
										sliceFrame[i][j][k] = index4
									end
									
									
									view[i][j][k].alpha = wall[12] -- * 0.5
									view[i][j][k].height = sliceHeight1 * wall[11]
									--local posY = blockScaleZ[j - 1] or 0
									--local deltaY = posY - wall[13]
									--local deltaY2 = deltaY * (sliceHeight / blockScaleZ[j])
									--view[i][j][k].y = (display.contentHeight / 2 - 
									--				( (sliceHeight * wall[11]/2) - (sliceHeight/2))) - 
									--				( ((j - 1) * (blockScaleZ[j - 1] or 0)) * (sliceHeight / blockScaleZ[j]) ) - 
									--				((blockScaleZ[j] / 2 - M.cameraZ) * (sliceHeight / blockScaleZ[j])) - 
									--				- (((blockScaleZ[j - 1] or 0) - wall[13]) * (sliceHeight / blockScaleZ[j]))     --deltaY2
									view[i][j][k].y = sliceY[i][j][k] --+ 100 * k
									view[i][j][k].width = sliceWidth
									view[i][j][k]:setFillColor(brightness, brightness, brightness)
									--[[
									if k == 1 then
										view[i][j][k]:setFillColor(255, 0, 0)
									elseif k == 2 then
										view[i][j][k]:setFillColor(0, 0, 255)
									elseif k == 3 then
										view[i][j][k]:setFillColor(255, 255, 0)
									end
									]]--
								end
							end
						end	
					end
				end		
			end
		end
		--print("Rays cast: "..testCount.." out of "..slices)
		--print(M.numCasts)
	end
	--FIND VERTICAL DEFLECTION
	local deflectY = directionY * 3
	
	sliceGroup.y = 0 - deflectY
	collectgarbage("step", gcStep / 2)	
end
M.projection = projection

M.processWalls = function()

	--map.layers[i].walls = {}
	--map.layers[1].wallData = {}
	
	--for x = 1, worldSizeX, 1 do
		--map.layers[i].walls[x] = {}
		--map.layers[1].wallData[x] = {}
		--map.layers[1].walls2[x] = {}
		--for y = 1, worldSizeY, 1 do
			--map.layers[1].walls[x][y] = {}
		--end
	--end

	
	
	for layer = 1, #map.layers, 1 do
		if map.layers[layer].objects then
			--[[
			map.layers[layer].walls = {}
			for x = 1, worldSizeX, 1 do
				map.layers[layer].walls[x] = {}
				for y = 1, worldSizeY, 1 do
					--map.layers[1].walls[x][y] = {}
				end
			end
			]]--
			for key,value in pairs(map.layers[layer].objects) do
				local object = map.layers[layer].objects[key]
				if object.properties then
					if object.properties.type then
						if object.properties.type == "wall" then
							if object.polygon then
								local height = {}
								if object.properties.zHeight then
									local data = json.decode(object.properties.zHeight)
									if type(data) ~= "table" then
										for i = 1, #object.polygon, 1 do
											height[i] = tonumber(data)
										end
									elseif #data == 1 or #data ~= #object.polygon then
										for i = 1, #object.polygon, 1 do
											height[i] = data[1]
										end
									else
										for i = 1, #object.polygon, 1 do
											height[i] = data[i]
										end
									end
								else
									for i = 1, #object.polygon, 1 do
										height[i] = 1
									end
								end
								
								local position = {}
								if object.properties.zPosition then
									local data = json.decode(object.properties.zPosition)
									if type(data) ~= "table" then
										for i = 1, #object.polygon, 1 do
											position[i] = tonumber(data)
										end
									elseif #data == 1 or #data ~= #object.polygon then
										for i = 1, #object.polygon, 1 do
											position[i] = data[1]
										end
									else
										for i = 1, #object.polygon, 1 do
											position[i] = data[i]
										end
									end
								else
									for i = 1, #object.polygon, 1 do
										position[i] = blockScaleZ[tonumber(map.layers[layer].properties.level) - 1] or 0
									end
								end
						
								local alpha = {}
								if object.properties.alpha then
									local data = json.decode(object.properties.alpha)
									if type(data) ~= "table" then
										for i = 1, #object.polygon, 1 do
											alpha[i] = tonumber(data)
										end
									elseif #data == 1 or #data ~= #object.polygon then
										for i = 1, #object.polygon, 1 do
											alpha[i] = data[1]
										end
									else
										for i = 1, #object.polygon, 1 do
											alpha[i] = data[i]
										end
									end
								else
									for i = 1, #object.polygon, 1 do
										alpha[i] = 1
									end
								end
							
								for i = 1, #object.polygon, 1 do
									local wallID = math.random(1,32000)
									local posX1 = object.polygon[i].x + object.x
									local posY1 = object.polygon[i].y + object.y							
									local locX1 = ceil(posX1 / worldScaleX)
									local locY1 = ceil(posY1 / worldScaleY)							
									local lPosX1 = posX1 - ((locX1 - 1) * worldScaleX)
									local lPosY1 = posY1 - ((locY1 - 1) * worldScaleY)
								
									local n = i + 1
									if n > #object.polygon then
										n = 1
									end
									local posX2 = object.polygon[n].x + object.x
									local posY2 = object.polygon[n].y + object.y							
									local locX2 = ceil(posX2 / worldScaleX)
									local locY2 = ceil(posY2 / worldScaleY)							
									local lPosX2 = posX2 - ((locX2 - 1) * worldScaleX)
									local lPosY2 = posY2 - ((locY2 - 1) * worldScaleY)
								
									local m = (posY2 - posY1) / (posX2 - posX1)
									local m2 = (posX2 - posX1) / (posY2 - posY1)
								
									local backwards
									if posX2 < posX1 then
										backwards = true
									end								
								
									local length = math.sqrt( ((posX1 - posX2) * (posX1 - posX2)) + ((posY1 - posY2) * (posY1 - posY2)) )
									local factor = blockScaleX / length
								
									local tileID = tonumber(object.properties.gid)
								
									local tempLocX = locX1
									local tempLocY = locY1
									local templPosX = lPosX1
									local templPosY = lPosY1
									local tempOffset = 0
									local tempHeight = height[i]
									local toggleBreak = false
									if not backwards then
										for j = 1, 1000, 1 do
											local nextY, nextX
											local distToTop = templPosY
											local distToLeft = worldScaleX - templPosX
											nextY = templPosY + (m * distToLeft)
											if tempLocX == locX2 and tempLocY == locY2 then
												nextX = lPosX2
												nextY = lPosY2
												local subLength = math.sqrt( ((templPosX - nextX) * (templPosX - nextX)) + ((templPosY - nextY) * (templPosY - nextY)) )
												local offset1 = tempOffset * factor
												local offset2 = (tempOffset + subLength) * factor
												local height1 = height[i] + (height[n] - height[i]) * ((tempOffset - 0) / (length - 0))
												local height2 = height[i] + (height[n] - height[i]) * (((tempOffset + subLength) - 0) / (length - 0))
												local alpha1 = alpha[i] + (alpha[n] - alpha[i]) * ((tempOffset - 0) / (length - 0))
												local alpha2 = alpha[i] + (alpha[n] - alpha[i]) * (((tempOffset + subLength) - 0) / (length - 0))
												local position1 = position[i] + (position[n] - position[i]) * ((tempOffset - 0) / (length - 0))
												local position2 = position[i] + (position[n] - position[i]) * (((tempOffset + subLength) - 0) / (length - 0))
												if not map.layers[layer].walls[tempLocX][tempLocY] then
													map.layers[layer].walls[tempLocX][tempLocY] = {}
												end
												--map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {templPosX + 1, nextX + 1, templPosY + 1, nextY + 1, backwards, true}
												map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {templPosX, 
														nextX, templPosY, nextY, backwards, true, offset1, offset2, tileID, length, height1, height2, alpha1, alpha2, position1, position2, wallID
												}
											else
												if nextY < 0 then
													nextY = 0
													nextX = (templPosX + (m2 * -1 * distToTop))
													local subLength = math.sqrt( ((templPosX - nextX) * (templPosX - nextX)) + ((templPosY - nextY) * (templPosY - nextY)) )
													local offset1 = tempOffset * factor
													local offset2 = (tempOffset + subLength) * factor
													local height1 = height[i] + (height[n] - height[i]) * ((tempOffset - 0) / (length - 0))
													local height2 = height[i] + (height[n] - height[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local alpha1 = alpha[i] + (alpha[n] - alpha[i]) * ((tempOffset - 0) / (length - 0))
													local alpha2 = alpha[i] + (alpha[n] - alpha[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local position1 = position[i] + (position[n] - position[i]) * ((tempOffset - 0) / (length - 0))
													local position2 = position[i] + (position[n] - position[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													if not map.layers[layer].walls[tempLocX][tempLocY] then
														map.layers[layer].walls[tempLocX][tempLocY] = {}
													end
													--map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {templPosX + 1, nextX + 1, templPosY + 1, nextY + 1, backwards, true}
													map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {templPosX, 
															nextX, templPosY, nextY, backwards, true, offset1, offset2, tileID, length, height1, height2, alpha1, alpha2, position1, position2, wallID
													}
													tempLocX = tempLocX
													tempLocY = tempLocY - 1
													templPosX = nextX
													templPosY = worldScaleY
													tempOffset = tempOffset + subLength
												elseif nextY > worldScaleY then
													nextY = worldScaleY
													nextX = templPosX + (m2 * (worldScaleY - distToTop))
													local subLength = math.sqrt( ((templPosX - nextX) * (templPosX - nextX)) + ((templPosY - nextY) * (templPosY - nextY)) )
													local offset1 = tempOffset * factor
													local offset2 = (tempOffset + subLength) * factor
													local height1 = height[i] + (height[n] - height[i]) * ((tempOffset - 0) / (length - 0))
													local height2 = height[i] + (height[n] - height[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local alpha1 = alpha[i] + (alpha[n] - alpha[i]) * ((tempOffset - 0) / (length - 0))
													local alpha2 = alpha[i] + (alpha[n] - alpha[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local position1 = position[i] + (position[n] - position[i]) * ((tempOffset - 0) / (length - 0))
													local position2 = position[i] + (position[n] - position[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													if not map.layers[layer].walls[tempLocX][tempLocY] then
														map.layers[layer].walls[tempLocX][tempLocY] = {}
													end
													--map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {templPosX + 1, nextX + 1, templPosY + 1, nextY + 1, backwards, true}
													map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {templPosX, 
															nextX, templPosY, nextY, backwards, true, offset1, offset2, tileID, length, height1, height2, alpha1, alpha2, position1, position2, wallID
													}
													tempLocX = tempLocX
													tempLocY = tempLocY + 1
													templPosX = nextX
													templPosY = 0
													tempOffset = tempOffset + subLength
												else
													nextX = worldScaleX
													local subLength = math.sqrt( ((templPosX - nextX) * (templPosX - nextX)) + ((templPosY - nextY) * (templPosY - nextY)) )
													local offset1 = tempOffset * factor
													local offset2 = (tempOffset + subLength) * factor
													local height1 = height[i] + (height[n] - height[i]) * ((tempOffset - 0) / (length - 0))
													local height2 = height[i] + (height[n] - height[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local alpha1 = alpha[i] + (alpha[n] - alpha[i]) * ((tempOffset - 0) / (length - 0))
													local alpha2 = alpha[i] + (alpha[n] - alpha[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local position1 = position[i] + (position[n] - position[i]) * ((tempOffset - 0) / (length - 0))
													local position2 = position[i] + (position[n] - position[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													if not map.layers[layer].walls[tempLocX][tempLocY] then
														map.layers[layer].walls[tempLocX][tempLocY] = {}
													end
													--map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {templPosX + 1, nextX + 1, templPosY + 1, nextY + 1, backwards, true}
													map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {templPosX, 
															nextX, templPosY, nextY, backwards, true, offset1, offset2, tileID, length, height1, height2, alpha1, alpha2, position1, position2, wallID
													}
													tempLocX = tempLocX + 1
													tempLocY = tempLocY
													templPosX = 0
													templPosY = nextY
													tempOffset = tempOffset + subLength
												end
											end
											if toggleBreak then
												break
											end
											if tempLocX == locX2 and tempLocY == locY2 then
												toggleBreak = true
											end
										end
									else
										for j = 1, 1000, 1 do
											local nextY, nextX
											local distToTop = templPosY
											local distToRight = templPosX
											nextY = templPosY + (m * -1 * distToRight)
											if tempLocX == locX2 and tempLocY == locY2 then
												nextX = lPosX2
												nextY = lPosY2
												local subLength = math.sqrt( ((templPosX - nextX) * (templPosX - nextX)) + ((templPosY - nextY) * (templPosY - nextY)) )
												local offset1 = tempOffset * factor
												local offset2 = (tempOffset + subLength) * factor
												local height1 = height[i] + (height[n] - height[i]) * ((tempOffset - 0) / (length - 0))
												local height2 = height[i] + (height[n] - height[i]) * (((tempOffset + subLength) - 0) / (length - 0))
												local alpha1 = alpha[i] + (alpha[n] - alpha[i]) * ((tempOffset - 0) / (length - 0))
												local alpha2 = alpha[i] + (alpha[n] - alpha[i]) * (((tempOffset + subLength) - 0) / (length - 0))
												local position1 = position[i] + (position[n] - position[i]) * ((tempOffset - 0) / (length - 0))
												local position2 = position[i] + (position[n] - position[i]) * (((tempOffset + subLength) - 0) / (length - 0))
												if not map.layers[layer].walls[tempLocX][tempLocY] then
													map.layers[layer].walls[tempLocX][tempLocY] = {}
												end
												--map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {nextX + 1, templPosX + 1, nextY + 1, templPosY + 1, backwards, true}
												map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {nextX, 
														templPosX, nextY, templPosY, backwards, true, offset1, offset2, tileID, length, height1, height2, alpha1, alpha2, position1, position2, wallID
												}
											else
												if nextY < 0 then
													nextY = 0 
													nextX = (templPosX + (m2 * -1 * distToTop))
													local subLength = math.sqrt( ((templPosX - nextX) * (templPosX - nextX)) + ((templPosY - nextY) * (templPosY - nextY)) )
													local offset1 = tempOffset * factor
													local offset2 = (tempOffset + subLength) * factor
													local height1 = height[i] + (height[n] - height[i]) * ((tempOffset - 0) / (length - 0))
													local height2 = height[i] + (height[n] - height[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local alpha1 = alpha[i] + (alpha[n] - alpha[i]) * ((tempOffset - 0) / (length - 0))
													local alpha2 = alpha[i] + (alpha[n] - alpha[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local position1 = position[i] + (position[n] - position[i]) * ((tempOffset - 0) / (length - 0))
													local position2 = position[i] + (position[n] - position[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													if not map.layers[layer].walls[tempLocX][tempLocY] then
														map.layers[layer].walls[tempLocX][tempLocY] = {}
													end
													--map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {nextX + 1, templPosX + 1, nextY + 1, templPosY + 1, backwards, true}
													map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {nextX, 
															templPosX, nextY, templPosY, backwards, true, offset1, offset2, tileID, length, height1, height2, alpha1, alpha2, position1, position2, wallID
													}
													tempLocX = tempLocX
													tempLocY = tempLocY - 1
													templPosX = nextX
													templPosY = worldScaleY
													tempOffset = tempOffset + subLength
												elseif nextY > worldScaleY then
													nextY = worldScaleY
													nextX = templPosX + (m2 * (worldScaleY - distToTop))
													local subLength = math.sqrt( ((templPosX - nextX) * (templPosX - nextX)) + ((templPosY - nextY) * (templPosY - nextY)) )
													local offset1 = tempOffset * factor
													local offset2 = (tempOffset + subLength) * factor
													local height1 = height[i] + (height[n] - height[i]) * ((tempOffset - 0) / (length - 0))
													local height2 = height[i] + (height[n] - height[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local alpha1 = alpha[i] + (alpha[n] - alpha[i]) * ((tempOffset - 0) / (length - 0))
													local alpha2 = alpha[i] + (alpha[n] - alpha[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local position1 = position[i] + (position[n] - position[i]) * ((tempOffset - 0) / (length - 0))
													local position2 = position[i] + (position[n] - position[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													if not map.layers[layer].walls[tempLocX][tempLocY] then
														map.layers[layer].walls[tempLocX][tempLocY] = {}
													end
													--map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {nextX + 1, templPosX + 1, nextY + 1, templPosY + 1, backwards, true}
													map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {nextX, 
															templPosX, nextY, templPosY, backwards, true, offset1, offset2, tileID, length, height1, height2, alpha1, alpha2, position1, position2, wallID
													}
													tempLocX = tempLocX
													tempLocY = tempLocY + 1
													templPosX = nextX
													templPosY = 0
													tempOffset = tempOffset + subLength
												else
													nextX = 0
													local subLength = math.sqrt( ((templPosX - nextX) * (templPosX - nextX)) + ((templPosY - nextY) * (templPosY - nextY)) )
													local offset1 = tempOffset * factor
													local offset2 = (tempOffset + subLength) * factor
													local height1 = height[i] + (height[n] - height[i]) * ((tempOffset - 0) / (length - 0))
													local height2 = height[i] + (height[n] - height[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local alpha1 = alpha[i] + (alpha[n] - alpha[i]) * ((tempOffset - 0) / (length - 0))
													local alpha2 = alpha[i] + (alpha[n] - alpha[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local position1 = position[i] + (position[n] - position[i]) * ((tempOffset - 0) / (length - 0))
													local position2 = position[i] + (position[n] - position[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													if not map.layers[layer].walls[tempLocX][tempLocY] then
														map.layers[layer].walls[tempLocX][tempLocY] = {}
													end
													--map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {nextX + 1, templPosX + 1, nextY + 1, templPosY + 1, backwards, true}
													map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {nextX, 
															templPosX, nextY, templPosY, backwards, true, offset1, offset2, tileID, length, height1, height2, alpha1, alpha2, position1, position2, wallID
													}
													tempLocX = tempLocX - 1
													tempLocY = tempLocY
													templPosX = 106
													templPosY = nextY
													tempOffset = tempOffset + subLength
												end
											end
											if toggleBreak then
												break
											end
											if tempLocX == locX2 and tempLocY == locY2 then
												toggleBreak = true
											end
										end
									end								
								
								end							
							end
						
							if object.polyline then
								local height = {}
								if object.properties.zHeight then
									local data = json.decode(object.properties.zHeight)
									if type(data) ~= "table" then
										for i = 1, #object.polyline, 1 do
											height[i] = tonumber(data)
										end
									elseif #data == 1 or #data ~= #object.polyline then
										for i = 1, #object.polyline, 1 do
											height[i] = data[1]
										end
									else
										for i = 1, #object.polyline, 1 do
											height[i] = data[i]
										end
									end
								else
									for i = 1, #object.polyline, 1 do
										height[i] = 1
									end
								end
								
								local position = {}
								if object.properties.zPosition then
									local data = json.decode(object.properties.zPosition)
									if type(data) ~= "table" then
										for i = 1, #object.polyline, 1 do
											position[i] = tonumber(data)
										end
									elseif #data == 1 or #data ~= #object.polyline then
										for i = 1, #object.polyline, 1 do
											position[i] = data[1]
										end
									else
										for i = 1, #object.polyline, 1 do
											position[i] = data[i]
										end
									end
								else
									for i = 1, #object.polyline, 1 do
										--position[i] = 1
										position[i] = blockScaleZ[tonumber(map.layers[layer].properties.level) - 1] or 0
									end
								end
								
								local alpha = {}
								if object.properties.alpha then
									local data = json.decode(object.properties.alpha)
									if type(data) ~= "table" then
										for i = 1, #object.polyline, 1 do
											alpha[i] = tonumber(data)
										end
									elseif #data == 1 or #data ~= #object.polyline then
										for i = 1, #object.polyline, 1 do
											alpha[i] = data[1]
										end
									else
										for i = 1, #object.polyline, 1 do
											alpha[i] = data[i]
										end
									end
								else
									for i = 1, #object.polyline, 1 do
										alpha[i] = 1
									end
								end
								--print(object.polygon[3].x)
								for i = 1, #object.polyline, 1 do
									local wallID = math.random(1, 32000)
									--print(" ")
									local posX1 = object.polyline[i].x + object.x
									local posY1 = object.polyline[i].y + object.y							
									local locX1 = ceil(posX1 / worldScaleX)
									local locY1 = ceil(posY1 / worldScaleY)							
									local lPosX1 = posX1 - ((locX1 - 1) * worldScaleX)
									local lPosY1 = posY1 - ((locY1 - 1) * worldScaleY)
								
									local n = i + 1
									if n > #object.polyline then
										--n = 1
										break
									end
								
									local posX2 = object.polyline[n].x + object.x
									local posY2 = object.polyline[n].y + object.y							
									local locX2 = ceil(posX2 / worldScaleX)
									local locY2 = ceil(posY2 / worldScaleY)							
									local lPosX2 = posX2 - ((locX2 - 1) * worldScaleX)
									local lPosY2 = posY2 - ((locY2 - 1) * worldScaleY)
								
									if posX2 == posX1 then
										posX2 = posX2 - 0.001
									end
									local m = (posY2 - posY1) / (posX2 - posX1)
									local m2 = (posX2 - posX1) / (posY2 - posY1)
								
									local backwards
									if posX2 < posX1 then
										backwards = true
									end								
								
									local length = math.sqrt( ((posX1 - posX2) * (posX1 - posX2)) + ((posY1 - posY2) * (posY1 - posY2)) )
									local factor = blockScaleX / length
								
									local tileID = tonumber(object.properties.gid)
								
									local tempLocX = locX1
									local tempLocY = locY1
									local templPosX = lPosX1
									local templPosY = lPosY1
									local tempOffset = 0
									local toggleBreak = false
									--print(templPosX, templPosY)
									if not backwards then
										for j = 1, 1000, 1 do
											--print("before", tempLocX, locX2, tempLocY, locY2)
											local nextY, nextX
											local distToTop = templPosY
											local distToLeft = worldScaleX - templPosX
											nextY = templPosY + (m * distToLeft)
											if tempLocX == locX2 and tempLocY == locY2 then
												--[[
												nextX = lPosX2
												nextY = lPosY2
												map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {templPosX, nextX, templPosY, nextY}
												--print("0a", templPosX, nextX, templPosY, nextY)
												]]--
												nextX = lPosX2
												nextY = lPosY2
												local subLength = math.sqrt( ((templPosX - nextX) * (templPosX - nextX)) + ((templPosY - nextY) * (templPosY - nextY)) )
												local offset1 = tempOffset * factor
												local offset2 = (tempOffset + subLength) * factor
												local height1 = height[i] + (height[n] - height[i]) * ((tempOffset - 0) / (length - 0))
												local height2 = height[i] + (height[n] - height[i]) * (((tempOffset + subLength) - 0) / (length - 0))
												local alpha1 = alpha[i] + (alpha[n] - alpha[i]) * ((tempOffset - 0) / (length - 0))
												local alpha2 = alpha[i] + (alpha[n] - alpha[i]) * (((tempOffset + subLength) - 0) / (length - 0))
												local position1 = position[i] + (position[n] - position[i]) * ((tempOffset - 0) / (length - 0))
												local position2 = position[i] + (position[n] - position[i]) * (((tempOffset + subLength) - 0) / (length - 0))
												if not map.layers[layer].walls[tempLocX][tempLocY] then
													map.layers[layer].walls[tempLocX][tempLocY] = {}
												end
												--map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {templPosX + 1, nextX + 1, templPosY + 1, nextY + 1, backwards, true}
												map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {templPosX, 
														nextX, templPosY, nextY, backwards, true, offset1, offset2, tileID, length, height1, height2, alpha1, alpha2, position1, position2, wallID
												}
											else
												--print(nextY)
												if nextY < 0 then
													nextY = 0
													nextX = (templPosX + (m2 * -1 * distToTop))
													local subLength = math.sqrt( ((templPosX - nextX) * (templPosX - nextX)) + ((templPosY - nextY) * (templPosY - nextY)) )
													local offset1 = tempOffset * factor
													local offset2 = (tempOffset + subLength) * factor
													local height1 = height[i] + (height[n] - height[i]) * ((tempOffset - 0) / (length - 0))
													local height2 = height[i] + (height[n] - height[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local alpha1 = alpha[i] + (alpha[n] - alpha[i]) * ((tempOffset - 0) / (length - 0))
													local alpha2 = alpha[i] + (alpha[n] - alpha[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local position1 = position[i] + (position[n] - position[i]) * ((tempOffset - 0) / (length - 0))
													local position2 = position[i] + (position[n] - position[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													if not map.layers[layer].walls[tempLocX][tempLocY] then
														map.layers[layer].walls[tempLocX][tempLocY] = {}
													end
													--map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {templPosX + 1, nextX + 1, templPosY + 1, nextY + 1, backwards, true}
													map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {templPosX, 
															nextX, templPosY, nextY, backwards, true, offset1, offset2, tileID, length, height1, height2, alpha1, alpha2, position1, position2, wallID
													}
													tempLocX = tempLocX
													tempLocY = tempLocY - 1
													templPosX = nextX
													templPosY = worldScaleY
													tempOffset = tempOffset + subLength
												elseif nextY > worldScaleY then
													nextY = worldScaleY
													nextX = templPosX + (m2 * (worldScaleY - distToTop))
													local subLength = math.sqrt( ((templPosX - nextX) * (templPosX - nextX)) + ((templPosY - nextY) * (templPosY - nextY)) )
													local offset1 = tempOffset * factor
													local offset2 = (tempOffset + subLength) * factor
													local height1 = height[i] + (height[n] - height[i]) * ((tempOffset - 0) / (length - 0))
													local height2 = height[i] + (height[n] - height[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local alpha1 = alpha[i] + (alpha[n] - alpha[i]) * ((tempOffset - 0) / (length - 0))
													local alpha2 = alpha[i] + (alpha[n] - alpha[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local position1 = position[i] + (position[n] - position[i]) * ((tempOffset - 0) / (length - 0))
													local position2 = position[i] + (position[n] - position[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													if not map.layers[layer].walls[tempLocX][tempLocY] then
														map.layers[layer].walls[tempLocX][tempLocY] = {}
													end
													--map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {templPosX + 1, nextX + 1, templPosY + 1, nextY + 1, backwards, true}
													map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {templPosX, 
															nextX, templPosY, nextY, backwards, true, offset1, offset2, tileID, length, height1, height2, alpha1, alpha2, position1, position2, wallID
													}
													tempLocX = tempLocX
													tempLocY = tempLocY + 1
													templPosX = nextX
													templPosY = 0
													tempOffset = tempOffset + subLength
												else
													nextX = worldScaleX
													local subLength = math.sqrt( ((templPosX - nextX) * (templPosX - nextX)) + ((templPosY - nextY) * (templPosY - nextY)) )
													local offset1 = tempOffset * factor
													local offset2 = (tempOffset + subLength) * factor
													local height1 = height[i] + (height[n] - height[i]) * ((tempOffset - 0) / (length - 0))
													local height2 = height[i] + (height[n] - height[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local alpha1 = alpha[i] + (alpha[n] - alpha[i]) * ((tempOffset - 0) / (length - 0))
													local alpha2 = alpha[i] + (alpha[n] - alpha[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local position1 = position[i] + (position[n] - position[i]) * ((tempOffset - 0) / (length - 0))
													local position2 = position[i] + (position[n] - position[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													if not map.layers[layer].walls[tempLocX][tempLocY] then
														map.layers[layer].walls[tempLocX][tempLocY] = {}
													end
													--map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {templPosX + 1, nextX + 1, templPosY + 1, nextY + 1, backwards, true}
													map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {templPosX, 
															nextX, templPosY, nextY, backwards, true, offset1, offset2, tileID, length, height1, height2, alpha1, alpha2, position1, position2, wallID
													}
													tempLocX = tempLocX + 1
													tempLocY = tempLocY
													templPosX = 0
													templPosY = nextY
													tempOffset = tempOffset + subLength
												end
											end
											--print("after ", tempLocX, locX2, tempLocY, locY2)
											if toggleBreak then
												--print(j)
												break
											end
											if tempLocX == locX2 and tempLocY == locY2 then
												toggleBreak = true
											end
										end
									else
										for j = 1, 1000, 1 do
											--print("before", tempLocX, locX2, tempLocY, locY2)
											local nextY, nextX
											local distToTop = templPosY
											--local distToLeft = worldScaleX - templPosX
											local distToRight = templPosX
											--print(m)
											--nextY = templPosY + (m * distToLeft)
											nextY = templPosY + (m * -1 * distToRight)
											if tempLocX == locX2 and tempLocY == locY2 then
												nextX = lPosX2
												nextY = lPosY2
												local subLength = math.sqrt( ((templPosX - nextX) * (templPosX - nextX)) + ((templPosY - nextY) * (templPosY - nextY)) )
												local offset1 = tempOffset * factor
												local offset2 = (tempOffset + subLength) * factor
												local height1 = height[i] + (height[n] - height[i]) * ((tempOffset - 0) / (length - 0))
												local height2 = height[i] + (height[n] - height[i]) * (((tempOffset + subLength) - 0) / (length - 0))
												local alpha1 = alpha[i] + (alpha[n] - alpha[i]) * ((tempOffset - 0) / (length - 0))
												local alpha2 = alpha[i] + (alpha[n] - alpha[i]) * (((tempOffset + subLength) - 0) / (length - 0))
												local position1 = position[i] + (position[n] - position[i]) * ((tempOffset - 0) / (length - 0))
												local position2 = position[i] + (position[n] - position[i]) * (((tempOffset + subLength) - 0) / (length - 0))
												if not map.layers[layer].walls[tempLocX][tempLocY] then
													map.layers[layer].walls[tempLocX][tempLocY] = {}
												end
												--map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {nextX + 1, templPosX + 1, nextY + 1, templPosY + 1, backwards, true}
												map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {nextX, 
														templPosX, nextY, templPosY, backwards, true, offset1, offset2, tileID, length, height1, height2, alpha1, alpha2, position1, position2, wallID
												}
											else
												--print(nextY)
												if nextY < 0 then
													nextY = 0 
													nextX = (templPosX + (m2 * -1 * distToTop))
													local subLength = math.sqrt( ((templPosX - nextX) * (templPosX - nextX)) + ((templPosY - nextY) * (templPosY - nextY)) )
													local offset1 = tempOffset * factor
													local offset2 = (tempOffset + subLength) * factor
													local height1 = height[i] + (height[n] - height[i]) * ((tempOffset - 0) / (length - 0))
													local height2 = height[i] + (height[n] - height[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local alpha1 = alpha[i] + (alpha[n] - alpha[i]) * ((tempOffset - 0) / (length - 0))
													local alpha2 = alpha[i] + (alpha[n] - alpha[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local position1 = position[i] + (position[n] - position[i]) * ((tempOffset - 0) / (length - 0))
													local position2 = position[i] + (position[n] - position[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													if not map.layers[layer].walls[tempLocX][tempLocY] then
														map.layers[layer].walls[tempLocX][tempLocY] = {}
													end
													--map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {nextX + 1, templPosX + 1, nextY + 1, templPosY + 1, backwards, true}
													map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {nextX, 
															templPosX, nextY, templPosY, backwards, true, offset1, offset2, tileID, length, height1, height2, alpha1, alpha2, position1, position2, wallID
													}
													tempLocX = tempLocX
													tempLocY = tempLocY - 1
													templPosX = nextX
													templPosY = worldScaleY
													tempOffset = tempOffset + subLength
												elseif nextY > worldScaleY then
													nextY = worldScaleY
													nextX = templPosX + (m2 * (worldScaleY - distToTop))
													local subLength = math.sqrt( ((templPosX - nextX) * (templPosX - nextX)) + ((templPosY - nextY) * (templPosY - nextY)) )
													local offset1 = tempOffset * factor
													local offset2 = (tempOffset + subLength) * factor
													local height1 = height[i] + (height[n] - height[i]) * ((tempOffset - 0) / (length - 0))
													local height2 = height[i] + (height[n] - height[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local alpha1 = alpha[i] + (alpha[n] - alpha[i]) * ((tempOffset - 0) / (length - 0))
													local alpha2 = alpha[i] + (alpha[n] - alpha[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local position1 = position[i] + (position[n] - position[i]) * ((tempOffset - 0) / (length - 0))
													local position2 = position[i] + (position[n] - position[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													if not map.layers[layer].walls[tempLocX][tempLocY] then
														map.layers[layer].walls[tempLocX][tempLocY] = {}
													end
													--map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {nextX + 1, templPosX + 1, nextY + 1, templPosY + 1, backwards, true}
													map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {nextX, 
															templPosX, nextY, templPosY, backwards, true, offset1, offset2, tileID, length, height1, height2, alpha1, alpha2, position1, position2, wallID
													}
													tempLocX = tempLocX
													tempLocY = tempLocY + 1
													templPosX = nextX
													templPosY = 0
													tempOffset = tempOffset + subLength
												else
													nextX = 0
													local subLength = math.sqrt( ((templPosX - nextX) * (templPosX - nextX)) + ((templPosY - nextY) * (templPosY - nextY)) )
													local offset1 = tempOffset * factor
													local offset2 = (tempOffset + subLength) * factor
													local height1 = height[i] + (height[n] - height[i]) * ((tempOffset - 0) / (length - 0))
													local height2 = height[i] + (height[n] - height[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local alpha1 = alpha[i] + (alpha[n] - alpha[i]) * ((tempOffset - 0) / (length - 0))
													local alpha2 = alpha[i] + (alpha[n] - alpha[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													local position1 = position[i] + (position[n] - position[i]) * ((tempOffset - 0) / (length - 0))
													local position2 = position[i] + (position[n] - position[i]) * (((tempOffset + subLength) - 0) / (length - 0))
													if not map.layers[layer].walls[tempLocX][tempLocY] then
														map.layers[layer].walls[tempLocX][tempLocY] = {}
													end
													--map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {nextX + 1, templPosX + 1, nextY + 1, templPosY + 1, backwards, true}
													map.layers[layer].walls[tempLocX][tempLocY][#map.layers[layer].walls[tempLocX][tempLocY] + 1] = {nextX, 
															templPosX, nextY, templPosY, backwards, true, offset1, offset2, tileID, length, height1, height2, alpha1, alpha2, position1, position2, wallID
													}
													tempLocX = tempLocX - 1
													tempLocY = tempLocY
													templPosX = 106
													templPosY = nextY
													tempOffset = tempOffset + subLength
												end
											end
											--print("after ", tempLocX, locX2, tempLocY, locY2)
											if toggleBreak then
												--print(j)
												break
											end
											if tempLocX == locX2 and tempLocY == locY2 then
												toggleBreak = true
											end
										end
									end								
								
								end							
							end
						
						end
					end
				end
			end
		
			for x = 1, worldSizeX, 1 do
				for y = 1, worldSizeY, 1 do
					--print(x, y)
					if map.layers[layer].walls[x][y] then
						for key,value in pairs(map.layers[layer].walls[x][y]) do
							--print(x, y, key, value[1], value[2], value[3], value[4], value[7], value[8])
							--print(x, y, value[11], value[12])
						end
					end
				end
			end
		end
	end
end

-----------------------------------------------------------

--[[
local coordX = function(levelPosX)
	return levelPosX * scaleFactorX
end
]]--

--[[
local coordY = function(levelPosY)
	return levelPosY * scaleFactorY
end
]]--

--[[
local levelX = function(coordX)
	return coordX / scaleFactorX
end
]]--

--[[
local levelY = function(coordY)
	return coordY / scaleFactorY
end
]]--

--[[
local wuX2 = function(x, layer)
	if x > layerWidth[layer] then
		while x > layerWidth[layer] do
			x = x - layerWidth[layer]
		end
	elseif x < 1 then
		while x < 1 do
			x = x + layerWidth[layer]
		end
	end
	return x
end
]]--

--[[
local wuY2 = function(y, layer)
	if y > layerHeight[layer] then
		while y > layerHeight[layer] do
			y = y - layerHeight[layer]
		end
	elseif y < 1 then
		while y < 1 do
			y = y + layerHeight[layer]
		end
	end
	return y
end
]]--

--[[
local wrapX = function(x, layer)
	if x > (layerWidth[layer] * blockScaleX) then
		x = x - (layerWidth[layer] * blockScaleX)
	elseif x < 0 then
		x = x + (layerWidth[layer] * blockScaleX)
	end
	return x
end
]]--

--[[
local wrapY = function(y, layer)
	if y > (layerHeight[layer] * blockScaleY) then
		y = y - (layerHeight[layer] * blockScaleY)
	elseif y < 0 then
		y = y + (layerHeight[layer] * blockScaleY)
	end
	return y
end
]]--
 
--[[
local blockToRectX = function(blockX, rect1LocX)
	local temp = blockX - rect1LocX + 1
	rectX = temp
	if rectX > worldSizeX then
		rectX = rectX - worldSizeX
	elseif rectX < 1 then
		rectX = rectX + worldSizeX
	end
	return rectX
end
]]--
local blockToRectX2 = function(blockX, rect1LocX, layer)
	local temp = blockX - rect1LocX + 1
	rectX = temp
	if rectX > layerWidth[layer] then
		rectX = rectX - layerWidth[layer]
	elseif rectX < 1 then
		rectX = rectX + layerWidth[layer]
	end
	return rectX
end

local blockToRectY = function(blockY, rect1LocY)
	local temp = blockY - rect1LocY + 1
	rectY = temp
	if rectY > worldSizeY then
		rectY = rectY - worldSizeY
	elseif rectY < 1 then
		rectY = rectY + worldSizeY
	end
	return rectY
end

local blockToRectY2 = function(blockY, rect1LocY, layer)
	local temp = blockY - rect1LocY + 1
	rectY = temp
	if rectY > layerHeight[layer] then
		rectY = rectY - layerHeight[layer]
	elseif rectY < 1 then
		rectY = rectY + layerHeight[layer]
	end
	return rectY
end

local toggleWorldWrapX = function(command)
	if command == true or command == false then
		worldWrapX = command
	else 
		if worldWrapX then
			worldWrapX = false
		elseif not worldWrapX then
			worldWrapX = true
		end
	end
	if map.properties then
		for i = 1, #map.layers, 1 do
			if not map.layers[i].properties.wrapX and not map.layers[i].properties.wrap then
				layerWrapX[i] = worldWrapX
			end
		end
	end
end
M.toggleWorldWrapX = toggleWorldWrapX

local toggleWorldWrapY = function(command)
	if command == true or command == false then
		worldWrapY = command
	else
		if worldWrapY then
			worldWrapY = false
		elseif not worldWrapY then
			worldWrapY = true
		end
	end
	if map.properties then
		for i = 1, #map.layers, 1 do
			if not map.layers[i].properties.wrapY and not map.layers[i].properties.wrap then
				layerWrapY[i] = worldWrapY
			end
		end
	end
end
M.toggleWorldWrapY = toggleWorldWrapY

local getLevel = function(layer)
	return map.layers[layer].properties.level
end
M.getLevel = getLevel

local findScaleX = function(native, layer)
	return (blockScaleX * map.layers[layer].properties.scaleX) / native
end

local findScaleY = function(native, layer)
	return (blockScaleY * map.layers[layer].properties.scaleY) / native
end

local getGridExtent = function(layer, arg)
	if not layer then
		layer = refLayer
	end
	local value
	local topLeft = convert("screenPosToLoc", 0, 0, layer)
	local bottomRight = convert("screenPosToLoc", display.viewableContentWidth, display.viewableContentHeight, layer)
	if not arg then
		value = {}
		value.top = topLeft.y
		value.left = topLeft.x
		value.bottom = bottomRight.y
		value.right = bottomRight.x
	elseif arg == "top" then
		value = topLeft.y
	elseif arg == "bottom" then
		value = bottomRight.y
	elseif arg == "left" then
		value = topLeft.x
	elseif arg == "right" then
		value = bottomRight.x
	end
	return value
end
M.getScreenExtent = getGridExtent

convert = function(operation, arg1, arg2, layer, noWrapX, noWrapY)
	if not layer then
		layer = refLayer
	end
	local switch = nil
	if not arg1 then
		arg1 = arg2
		switch = 2
	end
	if not arg2 then
		arg2 = arg1
		switch = 1
	end
	local scaleX = map.layers[layer].properties.scaleX
	local scaleY = map.layers[layer].properties.scaleY
	local tempScaleX = blockScaleX * map.layers[layer].properties.scaleX
	local tempScaleY = blockScaleY * map.layers[layer].properties.scaleY
	--local tempScaleX = blockScaleX * scaleX
	--local tempScaleY = blockScaleY * scaleY
	
	local value = {}
	
	if operation == "screenPosToLevelPos" then
	--screenPos to levelPos *WORKS 3D*
		--[[
		local gridPosX = (arg1 - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX
		local gridLocX = floor(gridPosX)
		local gridRemainderX = (gridPosX - gridLocX) * tempScaleX
		local deflectionX = (gridRemainderX - (tempScaleX * 0.5)) / scaleX
		local locX = ceil((arg1 - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX) + rect1LocX[layer] - 1
		local levelPosX = locX * blockScaleX - blockScaleX * 0.5
		local tempX = levelPosX + deflectionX
		
		local gridPosY = (arg2 - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY
		local gridLocY = floor(gridPosY)
		local gridRemainderY = (gridPosY - gridLocY) * tempScaleY
		local deflectionY = (gridRemainderY - (tempScaleY * 0.5)) / scaleY
		local locY = ceil((arg2 - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY) + rect1LocY[layer] - 1
		local levelPosY = locY * blockScaleY - blockScaleY * 0.5
		local tempY = levelPosY + deflectionY
		
		if not noWrapX then
			wrapX(tempX, layer)
		end
		if not noWrapY then
			wrapY(tempY, layer)
		end
		value = {x = tempX, y = tempY}
		]]--
		local gridPosX = (arg1 - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX
		local tempX = ((ceil(gridPosX) + rect1LocX[layer] - 1) * blockScaleX - blockScaleX * 0.5) + ((((gridPosX - floor(gridPosX)) * tempScaleX) - (tempScaleX * 0.5)) / scaleX)		
		
		local gridPosY = (arg2 - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY
		local tempY = ((ceil(gridPosY) + rect1LocY[layer] - 1) * blockScaleY - blockScaleY * 0.5) + ((((gridPosY - floor(gridPosY)) * tempScaleY) - (tempScaleY * 0.5)) / scaleY)
		
		value = {x = tempX, y = tempY}
	elseif operation == "screenPosToLoc" then
	--screenPos to Loc *WORKS 3D*
		--[[
		local tempX = ceil((arg1 - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX) + rect1LocX[layer] - 1
		local tempY = ceil((arg2 - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY) + rect1LocY[layer] - 1
		
		if not noWrapX then
			tempX = wuX2(tempX, layer)
		end
		if not noWrapY then
			tempY = wuY2(tempY, layer)
		end
		
		value = {x = tempX, y = tempY}
		]]--
		local tempX = ceil((arg1 - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX) + rect1LocX[layer] - 1
		local tempY = ceil((arg2 - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY) + rect1LocY[layer] - 1
		
		if not noWrapX then
			if tempX > layerWidth[layer] then
				while tempX > layerWidth[layer] do
					tempX = tempX - layerWidth[layer]
				end
			elseif tempX < 1 then
				while tempX < 1 do
					tempX = tempX + layerWidth[layer]
				end
			end
		end
		if not noWrapY then
			if tempY > layerHeight[layer] then
				while tempY > layerHeight[layer] do
					tempY = tempY - layerHeight[layer]
				end
			elseif tempY < 1 then
				while tempY < 1 do
					tempY = tempY + layerHeight[layer]
				end
			end
		end
		
		value = {x = tempX, y = tempY}
	elseif operation == "screenPosToGrid" then
	--screenPos to Grid *WORKS 3D*
		local tempX = ceil((arg1 - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX)
		local tempY = ceil((arg2 - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY)
		value = {x = tempX, y = tempY}
		--[[
		if rects[layer][tempX][tempY] ~= 9999 then
			rects[layer][tempX][tempY]:setFillColor(255, 0, 0)
		end
		]]--
	end
	
	if operation == "levelPosToScreenPos" then
	--levelPos to screenPos *WORKS 3D*
		--[[
		local tempX1 = arg1 / blockScaleX
		local floorX = floor(tempX1)
		local remainderX = (tempX1 - floorX) * tempScaleX
		local deflectionX = (remainderX - (tempScaleX * 0.5))
		local locX = floor(arg1 / blockScaleX) + 1
		local screenPosX = ((locX - rect1LocX[layer]) * tempScaleX) + anchorX[layer]
		local tempX = screenPosX + deflectionX

		local tempY1 = arg2 / blockScaleY
		local floorY = floor(tempY1)
		local remainderY = (tempY1 - floorY) * tempScaleY
		local deflectionY = (remainderY - (tempScaleY * 0.5))
		local locY = floor(arg2 / blockScaleY) + 1
		local screenPosY = ((locY - rect1LocY[layer]) * tempScaleY) + anchorY[layer]
		local tempY = screenPosY + deflectionY
		
		value = {x = tempX, y = tempY}
		]]--
		
		local tempX
		if switch == 1 or not switch then
			local tempX1 = arg1 / blockScaleX
			tempX = ((((floor(arg1 / blockScaleX) + 1) - rect1LocX[layer]) * tempScaleX) + anchorX[layer]) + ((((tempX1 - floor(tempX1)) * tempScaleX) - (tempScaleX * 0.5)))
		end
		
		local tempY
		if switch == 2 or not switch then
			local tempY1 = arg2 / blockScaleY
			tempY = ((((floor(arg2 / blockScaleY) + 1) - rect1LocY[layer]) * tempScaleY) + anchorY[layer]) + ((((tempY1 - floor(tempY1)) * tempScaleY) - (tempScaleY * 0.5)))
		end
		
		value = {x = tempX, y = tempY}
	elseif operation == "levelPosToLoc" then
	--levelPos to Loc *WORKS 3D*
		--[[
		local tempX = ceil(math.round(arg1) / blockScaleX)
		local tempY = ceil(math.round(arg2) / blockScaleY)
		if not noWrapX then
			--tempX = wuX2(tempX, layer)
			if tempX > layerWidth[layer] then
				while tempX > layerWidth[layer] do
					tempX = tempX - layerWidth[layer]
				end
			elseif tempX < 1 then
				while tempX < 1 do
					tempX = tempX + layerWidth[layer]
				end
			end
		end
		if not noWrapY then
			--tempY = wuY2(tempY, layer)
			if tempY > layerHeight[layer] then
				while tempY > layerHeight[layer] do
					tempY = tempY - layerHeight[layer]
				end
			elseif tempY < 1 then
				while tempY < 1 do
					tempY = tempY + layerHeight[layer]
				end
			end
		end
		value = {x = tempX, y = tempY}
		]]--
		
		local tempX
		if switch == 1 or not switch then
			tempX = ceil(math.round(arg1) / blockScaleX)
			if not noWrapX then
				if tempX > layerWidth[layer] then
					while tempX > layerWidth[layer] do
						tempX = tempX - layerWidth[layer]
					end
				elseif tempX < 1 then
					while tempX < 1 do
						tempX = tempX + layerWidth[layer]
					end
				end
			end
		end
		
		local tempY
		if switch == 2 or not switch then
			tempY = ceil(math.round(arg2) / blockScaleY)
			if not noWrapY then
				if tempY > layerHeight[layer] then
					while tempY > layerHeight[layer] do
						tempY = tempY - layerHeight[layer]
					end
				elseif tempY < 1 then
					while tempY < 1 do
						tempY = tempY + layerHeight[layer]
					end
				end
			end
		end
		
		value = {x = tempX, y = tempY}
	elseif operation == "levelPosToGrid" then
	--levelPos to Grid *WORKS 3D*
		--[[
		local tempX1 = arg1 / blockScaleX
		local floorX = floor(tempX1)
		local remainderX = (tempX1 - floorX) * tempScaleX
		local deflectionX = (remainderX - (tempScaleX * 0.5))
		local locX = ceil(arg1 / blockScaleX)
		local screenPosX = ((locX - rect1LocX[layer]) * tempScaleX) + anchorX[layer]
		local tempX = ceil((screenPosX + deflectionX - anchorX[layer] + tempScaleX * 0.5) / tempScaleX)
		
		local tempY1 = arg2 / blockScaleY
		local floorY = floor(tempY1)
		local remainderY = (tempY1 - floorY) * tempScaleY
		local deflectionY = (remainderY - (tempScaleY * 0.5))
		local locY = ceil(arg2 / blockScaleY)
		local screenPosY = ((locY - rect1LocY[layer]) * tempScaleY) + anchorY[layer]
		local tempY = ceil((screenPosY + deflectionY - anchorY[layer] + tempScaleY * 0.5) / tempScaleY)
		
		if not noWrapX then
			wrapX(tempX, layer)
		end
		if not noWrapY then
			wrapY(tempY, layer)
		end
		value = {x = tempX, y = tempY}
		]]--
		
		local tempX1 = arg1 / blockScaleX
		local tempX = ceil((((((ceil(arg1 / blockScaleX)) - rect1LocX[layer]) * tempScaleX) + anchorX[layer]) + ((((tempX1 - floor(tempX1)) * tempScaleX) - (tempScaleX * 0.5))) - anchorX[layer] + tempScaleX * 0.5) / tempScaleX)
		
		local tempY1 = arg2 / blockScaleY
		local tempY = ceil((((((ceil(arg2 / blockScaleY)) - rect1LocY[layer]) * tempScaleY) + anchorY[layer]) + ((((tempY1 - floor(tempY1)) * tempScaleY) - (tempScaleY * 0.5))) - anchorY[layer] + tempScaleY * 0.5) / tempScaleY)
		
		value = {x = tempX, y = tempY}
	end
	
	if operation == "locToScreenPos" then
	--Loc to screenPos *WORKS 3D*
		--[[
		local tempX = ((wuX2(arg1, layer) - rect1LocX[layer]) * tempScaleX) + anchorX[layer]
		local tempY = ((wuY2(arg2, layer) - rect1LocY[layer]) * tempScaleY) + anchorY[layer]
		value = {x = tempX, y = tempY}
		]]--
		if arg1 > layerWidth[layer] then
			while arg1 > layerWidth[layer] do
				arg1 = arg1 - layerWidth[layer]
			end
		elseif arg1 < 1 then
			while arg1 < 1 do
				arg1 = arg1 + layerWidth[layer]
			end
		end
		
		if arg2 > layerHeight[layer] then
			while arg2 > layerHeight[layer] do
				arg2 = arg2 - layerHeight[layer]
			end
		elseif arg2 < 1 then
			while arg2 < 1 do
				arg2 = arg2 + layerHeight[layer]
			end
		end
		
		local tempX = ((arg1 - rect1LocX[layer]) * tempScaleX) + anchorX[layer]
		local tempY = ((arg2 - rect1LocY[layer]) * tempScaleY) + anchorY[layer]
		value = {x = tempX, y = tempY}
	elseif operation == "locToLevelPos" then
	--Loc to levelPos *WORKS 3D*
		--[[
		local tempX = arg1 * blockScaleX - blockScaleX * 0.5
		local tempY = arg2 * blockScaleY - blockScaleY * 0.5
		if not noWrapX then
			wrapX(tempX, layer)
		end
		if not noWrapY then
			wrapY(tempY, layer)
		end
		value = {x = tempX, y = tempY}
		]]--
		local tempX = arg1 * blockScaleX - blockScaleX * 0.5
		local tempY = arg2 * blockScaleY - blockScaleY * 0.5

		value = {x = tempX, y = tempY}
	elseif operation == "locToGrid" then
	--Loc to Grid *WORKS 3D*
		local tempX = arg1 - rect1LocX[layer] + 1
		local tempY = arg2 - rect1LocY[layer] + 1
		if tempX > rectsWidth[layer] or tempX < 0 then
			tempX = nil
			tempY = nil
		elseif tempY > rectsHeight[layer] or tempY < 0 then
			tempY = nil
			tempX = nil
		end
		value = {x = tempX, y = tempY}
	end
	
	if operation == "gridToScreenPos" then
	--Grid to screenPos *WORKS 3D*
		local tempX = anchorX[layer] + ((arg1 - 1) * tempScaleX)
		local tempY = anchorY[layer] + ((arg2 - 1) * tempScaleY)
		value = {x = tempX, y = tempY}
	elseif operation == "gridToLevelPos" then
	--Grid to levelPos *WORKS 3D*
		--[[
		local screenX = anchorX[layer] + ((arg1 - 1) * tempScaleX)
		local gridPosX = (screenX - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX
		local gridLocX = floor(gridPosX)
		local gridRemainderX = (gridPosX - gridLocX) * tempScaleX
		local deflectionX = (gridRemainderX - (tempScaleX * 0.5)) / scaleX
		local locX = ceil((screenX - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX) + rect1LocX[layer] - 1
		local levelPosX = locX * blockScaleX - blockScaleX * 0.5
		local tempX = levelPosX + deflectionX
		
		local screenY = anchorY[layer] + ((arg2 - 1) * tempScaleY)
		local gridPosY = (screenY - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY
		local gridLocY = floor(gridPosY)
		local gridRemainderY = (gridPosY - gridLocY) * tempScaleY
		local deflectionY = (gridRemainderY - (tempScaleY * 0.5)) / scaleY
		local locY = ceil((screenY - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY) + rect1LocY[layer] - 1
		local levelPosY = locY * blockScaleY - blockScaleY * 0.5
		local tempY = levelPosY + deflectionY
		
		if not noWrapX then
			wrapX(tempX, layer)
		end
		if not noWrapY then
			wrapY(tempY, layer)
		end
		value = {x = tempX, y = tempY}
		]]--
		local screenX = anchorX[layer] + ((arg1 - 1) * tempScaleX)
		local gridPosX = (screenX - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX
		local tempX = ((ceil((screenX - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX) + rect1LocX[layer] - 1) * blockScaleX - blockScaleX * 0.5) + ((((gridPosX - floor(gridPosX)) * tempScaleX) - (tempScaleX * 0.5)) / scaleX)
		
		local screenY = anchorY[layer] + ((arg2 - 1) * tempScaleY)
		local gridPosY = (screenY - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY
		local tempY = ((ceil((screenY - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY) + rect1LocY[layer] - 1) * blockScaleY - blockScaleY * 0.5) + ((((gridPosY - floor(gridPosY)) * tempScaleY) - (tempScaleY * 0.5)) / scaleY)
	
		value = {x = tempX, y = tempY}
	elseif operation == "gridToLoc" then
	--Grid to Loc *WORKS 3D*
		--[[
		local tempX = arg1 + rect1LocX[layer] - 1
		local tempY = arg2 + rect1LocY[layer] - 1
		
		if not noWrapX then
			tempX = wuX2(tempX, layer)
		end
		if not noWrapY then
			tempY = wuY2(tempY, layer)
		end
		
		value = {x = tempX, y = tempY}
		]]--
		local tempX = arg1 + rect1LocX[layer] - 1
		local tempY = arg2 + rect1LocY[layer] - 1
		
		if not noWrapX then
			if tempX > layerWidth[layer] then
				while tempX > layerWidth[layer] do
					tempX = tempX - layerWidth[layer]
				end
			elseif tempX < 1 then
				while tempX < 1 do
					tempX = tempX + layerWidth[layer]
				end
			end
		end
		if not noWrapY then
			if tempY > layerHeight[layer] then
				while tempY > layerHeight[layer] do
					tempY = tempY - layerHeight[layer]
				end
			elseif tempY < 1 then
				while tempY < 1 do
					tempY = tempY + layerHeight[layer]
				end
			end
		end
		
		value = {x = tempX, y = tempY}
	end
	
	if not switch then
		return value
	elseif switch == 1 then
		return value.x
	elseif switch == 2 then
		return value.y
	end
end
M.IntCon = convert

local convertExt = function(operation, arg1, arg2, layer)
	if not layer then
		layer = refLayer
	end
	local switch = nil
	if not arg1 then
		arg1 = arg2
		switch = 2
	end
	if not arg2 then
		arg2 = arg1
		switch = 1
	end
	local scaleX = map.layers[layer].properties.scaleX
	local scaleY = map.layers[layer].properties.scaleY
	local tempScaleX = blockScaleX * map.layers[layer].properties.scaleX
	local tempScaleY = blockScaleY * map.layers[layer].properties.scaleY
	--local tempScaleX = blockScaleX * scaleX
	--local tempScaleY = blockScaleY * scaleY
	
	local value = {}
	
	if operation == "screenPosToLevelPos" then
	--screenPos to levelPos *WORKS 3D*
		--[[
		local gridPosX = (arg1 - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX
		local gridLocX = floor(gridPosX)
		local gridRemainderX = (gridPosX - gridLocX) * tempScaleX
		local deflectionX = (gridRemainderX - (tempScaleX * 0.5)) / scaleX
		local locX = ceil((arg1 - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX) + rect1LocX[layer] - 1
		local levelPosX = locX * blockScaleX - blockScaleX * 0.5
		local tempX = levelPosX + deflectionX
		
		local gridPosY = (arg2 - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY
		local gridLocY = floor(gridPosY)
		local gridRemainderY = (gridPosY - gridLocY) * tempScaleY
		local deflectionY = (gridRemainderY - (tempScaleY * 0.5)) / scaleY
		local locY = ceil((arg2 - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY) + rect1LocY[layer] - 1
		local levelPosY = locY * blockScaleY - blockScaleY * 0.5
		local tempY = levelPosY + deflectionY
		
		wrapX(tempX, layer)
		wrapY(tempY, layer)
		value = {x = levelX(tempX), y = levelY(tempY)}
		]]--

		local gridPosX = (arg1 - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX
		local tempX = ((ceil(gridPosX) + rect1LocX[layer] - 1) * blockScaleX - blockScaleX * 0.5) + ((((gridPosX - floor(gridPosX)) * tempScaleX) - (tempScaleX * 0.5)) / scaleX)		
		if tempX > (layerWidth[layer] * blockScaleX) then
			tempX = tempX - (layerWidth[layer] * blockScaleX)
		elseif tempX < 0 then
			tempX = tempX + (layerWidth[layer] * blockScaleX)
		end
		tempX = tempX / scaleFactorX
		
		local gridPosY = (arg2 - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY
		local tempY = ((ceil(gridPosY) + rect1LocY[layer] - 1) * blockScaleY - blockScaleY * 0.5) + ((((gridPosY - floor(gridPosY)) * tempScaleY) - (tempScaleY * 0.5)) / scaleY)
		if tempY > (layerHeight[layer] * blockScaleY) then
			tempY = tempY - (layerHeight[layer] * blockScaleY)
		elseif tempY < 0 then
			tempY = tempY + (layerHeight[layer] * blockScaleY)
		end
		tempY = tempY / scaleFactorY

		value = {x = tempX, y = tempY}
	elseif operation == "screenPosToLoc" then
	--screenPos to Loc *WORKS 3D*
		local tempX = ceil((arg1 - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX) + rect1LocX[layer] - 1
		local tempY = ceil((arg2 - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY) + rect1LocY[layer] - 1

		if tempX > layerWidth[layer] then
			while tempX > layerWidth[layer] do
				tempX = tempX - layerWidth[layer]
			end
		elseif tempX < 1 then
			while tempX < 1 do
				tempX = tempX + layerWidth[layer]
			end
		end
		
		if tempY > layerHeight[layer] then
			while tempY > layerHeight[layer] do
				tempY = tempY - layerHeight[layer]
			end
		elseif tempY < 1 then
			while tempY < 1 do
				tempY = tempY + layerHeight[layer]
			end
		end
		
		value = {x = tempX, y = tempY}

		--value = {x = wuX2(tempX, layer), y = wuY2(tempY, layer)}
	elseif operation == "screenPosToGrid" then
	--screenPos to Grid *WORKS 3D*
		local tempX = ceil((arg1 - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX)
		local tempY = ceil((arg2 - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY)
		value = {x = tempX, y = tempY}
		--[[
		if rects[layer][tempX][tempY] ~= 9999 then
			rects[layer][tempX][tempY]:setFillColor(255, 0, 0)
		end
		]]--
	end
	
	if operation == "levelPosToScreenPos" then
	--levelPos to screenPos *WORKS 3D*
		--[[
		arg1 = coordX(arg1)
		arg2 = coordY(arg2)
		
		local tempX1 = arg1 / blockScaleX
		local floorX = floor(tempX1)
		local remainderX = (tempX1 - floorX) * tempScaleX
		local deflectionX = (remainderX - (tempScaleX * 0.5))
		local locX = floor(arg1 / blockScaleX) + 1
		local screenPosX = ((locX - rect1LocX[layer]) * tempScaleX) + anchorX[layer]
		local tempX = screenPosX + deflectionX
		
		local tempY1 = arg2 / blockScaleY
		local floorY = floor(tempY1)
		local remainderY = (tempY1 - floorY) * tempScaleY
		local deflectionY = (remainderY - (tempScaleY * 0.5))
		local locY = floor(arg2 / blockScaleY) + 1
		local screenPosY = ((locY - rect1LocY[layer]) * tempScaleY) + anchorY[layer]
		local tempY = screenPosY + deflectionY
		
		value = {x = tempX, y = tempY}
		]]--
		local tempX
		if switch == 1 or not switch then
			arg1 = arg1 * scaleFactorX
			local tempX1 = arg1 / blockScaleX
			tempX = ((((floor(arg1 / blockScaleX) + 1) - rect1LocX[layer]) * tempScaleX) + anchorX[layer]) + ((((tempX1 - floor(tempX1)) * tempScaleX) - (tempScaleX * 0.5)))
		end
		
		local tempY
		if switch == 2 or not switch then
			arg2 = arg2 * scaleFactorY
			local tempY1 = arg2 / blockScaleY
			tempY = ((((floor(arg2 / blockScaleY) + 1) - rect1LocY[layer]) * tempScaleY) + anchorY[layer]) + ((((tempY1 - floor(tempY1)) * tempScaleY) - (tempScaleY * 0.5)))
		end
		
		value = {x = tempX, y = tempY}
	elseif operation == "levelPosToLoc" then
	--levelPos to Loc *WORKS 3D*
		--arg1 = arg1 * scaleFactorX --coordX(arg1)
		--arg2 = arg2 * scaleFactorY --coordY(arg2)
		----arg1 = coordX(arg1)
		----arg2 = coordY(arg2)
		--local tempX = ceil(arg1 / blockScaleX)
		--local tempY = ceil(arg2 / blockScaleY)
		
		local tempX
		if switch == 1 or not switch then
			tempX = ceil((arg1 * scaleFactorX) / blockScaleX)
			if tempX > layerWidth[layer] then
				while tempX > layerWidth[layer] do
					tempX = tempX - layerWidth[layer]
				end
			elseif tempX < 1 then
				while tempX < 1 do
					tempX = tempX + layerWidth[layer]
				end
			end
		end
		
		local tempY
		if switch == 2 or not switch then
			tempY = ceil((arg2 * scaleFactorY) / blockScaleY)
			if tempY > layerHeight[layer] then
				while tempY > layerHeight[layer] do
					tempY = tempY - layerHeight[layer]
				end
			elseif tempY < 1 then
				while tempY < 1 do
					tempY = tempY + layerHeight[layer]
				end
			end
		end
		
		--value = {x = wuX2(tempX, layer), y = wuY2(tempY, layer)}
		value = {x = tempX, y = tempY}
		--value = {x = wuX2(ceil((arg1 * scaleFactorX) / blockScaleX), layer), 
		--	y = wuY2(ceil((arg2 * scaleFactorY) / blockScaleY), layer)
		--}
	elseif operation == "levelPosToGrid" then
	--levelPos to Grid *WORKS 3D*
		--[[
		arg1 = coordX(arg1)
		arg2 = coordY(arg2)
		local tempX1 = arg1 / blockScaleX
		local floorX = floor(tempX1)
		local remainderX = (tempX1 - floorX) * tempScaleX
		local deflectionX = (remainderX - (tempScaleX * 0.5))
		local locX = ceil(arg1 / blockScaleX)
		local screenPosX = ((locX - rect1LocX[layer]) * tempScaleX) + anchorX[layer]
		local tempX = ceil((screenPosX + deflectionX - anchorX[layer] + tempScaleX * 0.5) / tempScaleX)
		
		local tempY1 = arg2 / blockScaleY
		local floorY = floor(tempY1)
		local remainderY = (tempY1 - floorY) * tempScaleY
		local deflectionY = (remainderY - (tempScaleY * 0.5))
		local locY = ceil(arg2 / blockScaleY)
		local screenPosY = ((locY - rect1LocY[layer]) * tempScaleY) + anchorY[layer]
		local tempY = ceil((screenPosY + deflectionY - anchorY[layer] + tempScaleY * 0.5) / tempScaleY)
		
		wrapX(tempX, layer)
		wrapY(tempY, layer)
		value = {x = tempX, y = tempY}
		]]--
		arg1 = arg1 * scaleFactorX
		arg2 = arg2 * scaleFactorY
		
		local tempX1 = arg1 / blockScaleX
		local tempX = ceil((((((ceil(arg1 / blockScaleX)) - rect1LocX[layer]) * tempScaleX) + anchorX[layer]) + ((((tempX1 - floor(tempX1)) * tempScaleX) - (tempScaleX * 0.5))) - anchorX[layer] + tempScaleX * 0.5) / tempScaleX)
		
		local tempY1 = arg2 / blockScaleY
		local tempY = ceil((((((ceil(arg2 / blockScaleY)) - rect1LocY[layer]) * tempScaleY) + anchorY[layer]) + ((((tempY1 - floor(tempY1)) * tempScaleY) - (tempScaleY * 0.5))) - anchorY[layer] + tempScaleY * 0.5) / tempScaleY)
		
		value = {x = tempX, y = tempY}
	end
	
	if operation == "locToScreenPos" then
	--Loc to screenPos *WORKS 3D*
		--local tempX = ((wuX2(arg1, layer) - rect1LocX[layer]) * tempScaleX) + anchorX[layer]
		--local tempY = ((wuY2(arg2, layer) - rect1LocY[layer]) * tempScaleY) + anchorY[layer]
		--value = {x = tempX, y = tempY}
		
		if arg1 > layerWidth[layer] then
			while arg1 > layerWidth[layer] do
				arg1 = arg1 - layerWidth[layer]
			end
		elseif arg1 < 1 then
			while arg1 < 1 do
				arg1 = arg1 + layerWidth[layer]
			end
		end
		
		if arg2 > layerHeight[layer] then
			while arg2 > layerHeight[layer] do
				arg2 = arg2 - layerHeight[layer]
			end
		elseif arg2 < 1 then
			while arg2 < 1 do
				arg2 = arg2 + layerHeight[layer]
			end
		end
		
		local tempX = ((arg1 - rect1LocX[layer]) * tempScaleX) + anchorX[layer]
		local tempY = ((arg2 - rect1LocY[layer]) * tempScaleY) + anchorY[layer]
		value = {x = tempX, y = tempY}
	elseif operation == "locToLevelPos" then
	--Loc to levelPos *WORKS 3D*
		local tempX = arg1 * blockScaleX - blockScaleX * 0.5
		local tempY = arg2 * blockScaleY - blockScaleY * 0.5
		--wrapX(tempX, layer)
		if tempX > (layerWidth[layer] * blockScaleX) then
			tempX = tempX - (layerWidth[layer] * blockScaleX)
		elseif tempX < 0 then
			tempX = tempX + (layerWidth[layer] * blockScaleX)
		end
		--wrapY(tempY, layer)
		if tempY > (layerHeight[layer] * blockScaleY) then
			tempY = tempY - (layerHeight[layer] * blockScaleY)
		elseif tempY < 0 then
			tempY = tempY + (layerHeight[layer] * blockScaleY)
		end
		tempX = tempX / scaleFactorX
		tempY = tempY / scaleFactorY
		value = {x = tempX, y = tempY}
		--value = {x = levelX(tempX), y = levelY(tempY)}
	elseif operation == "locToGrid" then
	--Loc to Grid *WORKS 3D*
		local tempX = arg1 - rect1LocX[layer] + 1
		local tempY = arg2 - rect1LocY[layer] + 1
		if tempX > rectsWidth[layer] or tempX < 0 then
			tempX = nil
			tempY = nil
		elseif tempY > rectsHeight[layer] or tempY < 0 then
			tempY = nil
			tempX = nil
		end
		value = {x = tempX, y = tempY}
	end
	
	if operation == "gridToScreenPos" then
	--Grid to screenPos *WORKS 3D*
		local tempX = anchorX[layer] + ((arg1 - 1) * tempScaleX)
		local tempY = anchorY[layer] + ((arg2 - 1) * tempScaleY)
		value = {x = tempX, y = tempY}
		--[[
		for x = 1, rectsWidth[layer], 1 do
			for y = 1, rectsHeight[layer], 1 do
				if rects[layer][x][y] ~= 9999 then
					if abs(rects[layer][x][y].sX - tempX) < 2 and abs(rects[layer][x][y].sY - tempY) < 2 then
						rects[layer][x][y]:setFillColor(0, 0, 255)
					end
				end
			end
		end
		]]--
	elseif operation == "gridToLevelPos" then
	--Grid to levelPos *WORKS 3D*
		--[[
		local screenX = anchorX[layer] + ((arg1 - 1) * tempScaleX)
		local gridPosX = (screenX - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX
		local gridLocX = floor(gridPosX)
		local gridRemainderX = (gridPosX - gridLocX) * tempScaleX
		local deflectionX = (gridRemainderX - (tempScaleX * 0.5)) / scaleX
		local locX = ceil((screenX - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX) + rect1LocX[layer] - 1
		local levelPosX = locX * blockScaleX - blockScaleX * 0.5
		local tempX = levelPosX + deflectionX
		
		local screenY = anchorY[layer] + ((arg2 - 1) * tempScaleY)
		local gridPosY = (screenY - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY
		local gridLocY = floor(gridPosY)
		local gridRemainderY = (gridPosY - gridLocY) * tempScaleY
		local deflectionY = (gridRemainderY - (tempScaleY * 0.5)) / scaleY
		local locY = ceil((screenY - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY) + rect1LocY[layer] - 1
		local levelPosY = locY * blockScaleY - blockScaleY * 0.5
		local tempY = levelPosY + deflectionY
	
		wrapX(tempX, layer)
		wrapY(tempY, layer)
		value = {x = levelX(tempX), y = levelY(tempY)}
		]]--
		local screenX = anchorX[layer] + ((arg1 - 1) * tempScaleX)
		local gridPosX = (screenX - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX
		local tempX = ((ceil((screenX - (anchorX[layer] - (tempScaleX * 0.5))) / tempScaleX) + rect1LocX[layer] - 1) * blockScaleX - blockScaleX * 0.5) + ((((gridPosX - floor(gridPosX)) * tempScaleX) - (tempScaleX * 0.5)) / scaleX)
		
		local screenY = anchorY[layer] + ((arg2 - 1) * tempScaleY)
		local gridPosY = (screenY - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY
		local tempY = ((ceil((screenY - (anchorY[layer] - (tempScaleY * 0.5))) / tempScaleY) + rect1LocY[layer] - 1) * blockScaleY - blockScaleY * 0.5) + ((((gridPosY - floor(gridPosY)) * tempScaleY) - (tempScaleY * 0.5)) / scaleY)
	
		tempX = tempX / scaleFactorX
		tempY = tempY / scaleFactorY
		value = {x = tempX, y = tempY}
	elseif operation == "gridToLoc" then
	--Grid to Loc *WORKS 3D*
		local tempX = arg1 + rect1LocX[layer] - 1
		local tempY = arg2 + rect1LocY[layer] - 1
		
		if tempX > layerWidth[layer] then
			while tempX > layerWidth[layer] do
				tempX = tempX - layerWidth[layer]
			end
		elseif tempX < 1 then
			while tempX < 1 do
				tempX = tempX + layerWidth[layer]
			end
		end
		
		if tempY > layerHeight[layer] then
			while tempY > layerHeight[layer] do
				tempY = tempY - layerHeight[layer]
			end
		elseif tempY < 1 then
			while tempY < 1 do
				tempY = tempY + layerHeight[layer]
			end
		end
	
		value = {x = tempX, y = tempY}
		--value = {x = wuX2(tempX, layer), y = wuY2(tempY, layer)}
	end
	
	if not switch then
		return value
	elseif switch == 1 then
		return value.x
	elseif switch == 2 then
		return value.y
	end
end
M.convert = convertExt

local removeSprite = function(object)
	if objects[object].isMoving then
		objects[object].isMoving = false
	end
	--[[
	if objects[object].isMoving2 then
		objects[object].isMoving2 = false
	end
	]]--
	if movingSprites[objects[object]] == objects[object] then
		movingSprites[objects[object]] = nil
	end
	objects[object]:removeSelf()
	objects[object] = nil
end
M.removeSprite = removeSprite

local addSprite = function(sprite, setup)
	local layer
	if setup.level then
		layer = spriteLayers[setup.level]
		if not layer then
			print("ERROR: No Sprite Layer at level "..setup.level..". Defaulting to "..refLayer..".")
			layer = refLayer
		end
	elseif setup.layer then
		layer = setup.layer
		if layer > #map.layers then
			print("ERROR: Layer out of bounds. Defaulting to "..refLayer..".")
			layer = refLayer
		end
	else
		print("ERROR: You forgot to specify a Layer or level. Defaulting to "..refLayer..".")
		layer = refLayer
	end
	if setup.kind == "sprite" then
		objects[sprite] = sprite
		objects[sprite].kind = true
		objects[sprite].locX = nil
		objects[sprite].locY = nil
		objects[sprite].levelPosX = nil
		objects[sprite].levelPosY = nil
		if setup.offsetX then
			objects[sprite].offsetX = setup.offsetX
		else
			objects[sprite].offsetX = 0
		end
		if setup.offsetY then
			objects[sprite].offsetY = setup.offsetY
		else
			objects[sprite].offsetY = 0
		end
		objects[sprite].layer = setup.layer
		displayGroups[layer]:insert(sprite)
		objects[sprite].level = getLevel(setup.layer)
		if setup.sourceWidth then
			objects[sprite].sourceWidth = setup.sourceWidth
		else
			objects[sprite].sourceWidth = sprite.width
		end
		if setup.sourceHeight then
			objects[sprite].sourceHeight = setup.sourceHeight
		else
			objects[sprite].sourceHeight = sprite.height
		end
		objects[sprite].levelWidth = setup.levelWidth
		objects[sprite].levelHeight = setup.levelHeight
		objects[sprite].xScale = (setup.levelWidth * scaleFactorX / objects[sprite].sourceWidth) * map.layers[layer].properties.scaleX
		objects[sprite].yScale = (setup.levelHeight * scaleFactorY / objects[sprite].sourceHeight) * map.layers[layer].properties.scaleY
		objects[sprite].deltaX = {}
		objects[sprite].deltaY = {}
		objects[sprite].velX = nil
		objects[sprite].velY = nil
		objects[sprite].isMoving = false
		--objects[sprite].isMoving2 = false
		if setup.levelPosX and setup.levelPosY then
			setup.levelPosX = setup.levelPosX * scaleFactorX --coordX(setup.levelPosX)
			setup.levelPosY = setup.levelPosY * scaleFactorY --coordY(setup.levelPosY)
			objects[sprite].levelPosX = setup.levelPosX
			objects[sprite].levelPosY = setup.levelPosY
			local loc = convert("levelPosToLoc", setup.levelPosX, setup.levelPosY, setup.layer)
			objects[sprite].locX = loc.x
			objects[sprite].locY = loc.y
			local screenPos = convert("levelPosToScreenPos", setup.levelPosX, setup.levelPosY, setup.layer)
			objects[sprite].sX = screenPos.x
			objects[sprite].sY = screenPos.y
		elseif setup.locX and setup.locY then
			objects[sprite].locX = setup.locX
			objects[sprite].locY = setup.locY
			local levelPos = convert("locToLevelPos", setup.locX, setup.locY, setup.layer)
			objects[sprite].levelPosX = levelPos.x
			objects[sprite].levelPosY = levelPos.y
			local screenPos = convert("locToScreenPos", setup.locX, setup.locY, setup.layer)
			objects[sprite].sX = screenPos.x
			objects[sprite].sY = screenPos.y
		end
		objects[sprite].getLevelPosX = function()
			return objects[sprite].levelPosX / scaleFactorX --levelX(objects[sprite].levelPosX)
		end
		objects[sprite].getLevelPosY = function()
			return objects[sprite].levelPosY / scaleFactorY --levelY(objects[sprite].levelPosY)
		end
		objects[sprite]:setFillColor(map.layers[setup.layer].redLight, 
									map.layers[setup.layer].greenLight, 
									map.layers[setup.layer].blueLight)
		objects[sprite].sX = objects[sprite].sX + (objects[sprite].offsetX * scaleFactorX * map.layers[layer].properties.scaleX)
		objects[sprite].sY = objects[sprite].sY + (objects[sprite].offsetY * scaleFactorY * map.layers[layer].properties.scaleY)
		objects[sprite].getX = function()
			return objects[sprite].sX
		end
		objects[sprite].getY = function()
			return objects[sprite].sY
		end		
		return objects[sprite]		
	elseif setup.kind == "imageRect" then
		local temp = nil
		objects[sprite] = sprite
		objects[sprite].kind = true
		objects[sprite].locX = nil
		objects[sprite].locY = nil
		objects[sprite].levelPosX = nil
		objects[sprite].levelPosY = nil
		if setup.offsetX then
			objects[sprite].offsetX = setup.offsetX
		else
			objects[sprite].offsetX = 0
		end
		if setup.offsetY then
			objects[sprite].offsetY = setup.offsetY
		else
			objects[sprite].offsetY = 0
		end
		objects[sprite].layer = setup.layer
		displayGroups[layer]:insert(sprite)
		objects[sprite].level = getLevel(setup.layer)
		if setup.sourceWidth then
			objects[sprite].sourceWidth = setup.sourceWidth
		else
			objects[sprite].sourceWidth = sprite.width
		end
		if setup.sourceHeight then
			objects[sprite].sourceHeight = setup.sourceHeight
		else
			objects[sprite].sourceHeight = sprite.height
		end
		objects[sprite].levelWidth = setup.levelWidth
		objects[sprite].levelHeight = setup.levelHeight
		objects[sprite].xScale = (setup.levelWidth * scaleFactorX / objects[sprite].sourceWidth) * map.layers[layer].properties.scaleX
		objects[sprite].yScale = (setup.levelHeight * scaleFactorY / objects[sprite].sourceHeight) * map.layers[layer].properties.scaleY
		objects[sprite].deltaX = {}
		objects[sprite].deltaY = {}
		objects[sprite].velX = nil
		objects[sprite].velY = nil
		objects[sprite].isMoving = false
		--objects[sprite].isMoving2 = false
		if setup.levelPosX and setup.levelPosY then
			setup.levelPosX = setup.levelPosX * scaleFactorX --coordX(setup.levelPosX)
			setup.levelPosY = setup.levelPosY * scaleFactorY --coordY(setup.levelPosY)
			objects[sprite].levelPosX = setup.levelPosX
			objects[sprite].levelPosY = setup.levelPosY
			local loc = convert("levelPosToLoc", setup.levelPosX, setup.levelPosY, setup.layer)
			objects[sprite].locX = loc.x
			objects[sprite].locY = loc.y
			local screenPos = convert("levelPosToScreenPos", setup.levelPosX, setup.levelPosY, setup.layer)
			objects[sprite].sX = screenPos.x
			objects[sprite].sY = screenPos.y
		elseif setup.locX and setup.locY then
			objects[sprite].locX = setup.locX
			objects[sprite].locY = setup.locY
			local levelPos = convert("locToLevelPos", setup.locX, setup.locY, setup.layer)
			objects[sprite].levelPosX = levelPos.x
			objects[sprite].levelPosY = levelPos.y
			local screenPos = convert("locToScreenPos", setup.locX, setup.locY, setup.layer)
			objects[sprite].sX = screenPos.x
			objects[sprite].sY = screenPos.y
		end
		objects[sprite].getLevelPosX = function()
			return objects[sprite].levelPosX / scaleFactorX --levelX(objects[sprite].levelPosX)
		end
		objects[sprite].getLevelPosY = function()
			return objects[sprite].levelPosY / scaleFactorY --levelY(objects[sprite].levelPosY)
		end
		objects[sprite]:setFillColor(map.layers[setup.layer].redLight, 
									map.layers[setup.layer].greenLight, 
									map.layers[setup.layer].blueLight)
		objects[sprite].sX = objects[sprite].sX + (objects[sprite].offsetX * scaleFactorX * map.layers[layer].properties.scaleX)
		objects[sprite].sY = objects[sprite].sY + (objects[sprite].offsetY * scaleFactorY * map.layers[layer].properties.scaleY)
		objects[sprite].getX = function()
			return objects[sprite].sX
		end
		objects[sprite].getY = function()
			return objects[sprite].sY
		end
		
		return objects[sprite]
	end
end
M.addSprite = addSprite

local addObject = function(layer, table)
	local layer = layer
	if map.layers[layer].properties.objectLayer then
		map.layers[layer].objects[#map.layers[layer].objects + 1] = table
	else
		print("ERROR: Not an Object Layer.")
	end
end
M.addObject = addObject

local removeObject = function(name, lyr)
	if not lyr then
		local debug = 0
		for j = 1, #map.layers, 1 do
			local layer = j
			if map.layers[layer].properties.objectLayer then
				for i = 1, #map.layers[layer].objects, 1 do
					local object = map.layers[layer].objects[i]
					if name == object.name then
						table.remove(map.layers[layer].objects, i)
						debug = 1
						break
					end
				end
			end
			if debug == 1 then
				break
			end
		end
		if debug == 0 then
			print("ERROR: Object Not Found.")
		end
	else
		local layer = lyr
		local debug = 0
		if map.layers[layer].properties.objectLayer then
			for i = 1, #map.layers[layer].objects, 1 do
				local object = map.layers[layer].objects[i]
				if name == object.name then
					table.remove(map.layers[layer].objects, i)
					debug = 1
					break
				end
			end
		else
			print("ERROR: Not an Object Layer.")
		end
		if debug == 0 then
			print("ERROR: Object Not Found.")
		end
	end
end
M.removeObject = removeObject

--[[
local getTileAt = function(lX, lY, layer)
	local locX = wuX2(lX, layer)
	local locY = wuY2(lY, layer)
	if not layer then
		local values = {}
		for i = 1, #map.layers, 1 do
			values[i] = map.layers[i].world[locX][locY]
		end
		return values
	else
		return map.layers[layer].world[locX][locY]
	end
end
M.getTileAt = getTileAt
]]--

local getTileAt = function(parameters)
	local locX
	local locY
	local layer = parameters.layer
	if parameters.levelPosX then
		locX = convertExt("levelPosToLoc", parameters.levelPosX)
		locY = convertExt("levelPosToLoc", nil, parameters.levelPosY)
	elseif parameters.locX then
		locX = parameters.locX
		locY = parameters.locY
	end
	--locX = wuX2(locX, layer)
	if locX > layerWidth[layer] then
		while locX > layerWidth[layer] do
			locX = locX - layerWidth[layer]
		end
	elseif locX < 1 then
		while locX < 1 do
			locX = locX + layerWidth[layer]
		end
	end
	--locY = wuY2(locY, layer)
	if locY > layerHeight[layer] then
		while locY > layerHeight[layer] do
			locY = locY - layerHeight[layer]
		end
	elseif locY < 1 then
		while locY < 1 do
			locY = locY + layerHeight[layer]
		end
	end
	if not layer then
		local values = {}
		for i = 1, #map.layers, 1 do
			values[i] = map.layers[i].world[locX][locY]
		end
		return values
	else
		return map.layers[layer].world[locX][locY]
	end
end
M.getTileAt = getTileAt

local getTileProperties = function(options)
	if options.levelPosX then
		local loc = convertExt("levelPosToLoc", options.levelPosX, options.levelPosY)
		--options.locX = convertExt("levelPosToLoc", options.levelPosX)
		--options.locY = convertExt("levelPosToLoc", nil, options.levelPosY)
		options.locX = loc.x
		options.locY = loc.y
	end
	if options.tile then
		local tile = options.tile
		local properties = nil
		if tile ~= 0 then
			local tileset = 1
			for i = #map.tilesets, 1, -1 do
				if tile > map.tilesets[i].firstgid then
					tileset = i
					break
				end
			end
			local tileStr = 0
			if tileset == 1 then
				tileStr = tostring(tile - 1)
			else
				tileStr = tostring(tile - map.tilesets[tileset].firstgid)
			end
			if map.tilesets[tileset].tileproperties then
				if map.tilesets[tileset].tileproperties[tileStr] then
					properties = {}
					properties = map.tilesets[tileset].tileproperties[tileStr]
				end
			end
		end
		return properties
	elseif options.locX and options.locY then
		if options.layer then
			--local tile = getTileAt({locX = options.locX, locY = options.locY, layer = options.layer})
			------------------------------------------------------------------------------
				local locX = options.locX
				local locY = options.locY
				local layer = options.layer
				if locX > layerWidth[layer] then
					while locX > layerWidth[layer] do
						locX = locX - layerWidth[layer]
					end
				elseif locX < 1 then
					while locX < 1 do
						locX = locX + layerWidth[layer]
					end
				end
				if locY > layerHeight[layer] then
					while locY > layerHeight[layer] do
						locY = locY - layerHeight[layer]
					end
				elseif locY < 1 then
					while locY < 1 do
						locY = locY + layerHeight[layer]
					end
				end
				local tile = map.layers[layer].world[locX][locY]
			------------------------------------------------------------------------------
			local properties = nil
			if tile ~= 0 then
				local tileset = 1
				for i = #map.tilesets, 1, -1 do
					if tile > map.tilesets[i].firstgid then
						tileset = i
						break
					end
				end
				local tileStr = 0
				if tileset == 1 then
					tileStr = tostring(tile - 1)
				else
					tileStr = tostring(tile - map.tilesets[tileset].firstgid)
				end
				if map.tilesets[tileset].tileproperties then
					if map.tilesets[tileset].tileproperties[tileStr] then
						properties = {}
						properties = map.tilesets[tileset].tileproperties[tileStr]
					end
				end
			end
			return properties
		elseif options.level then
			local array = {}
			for i = 1, #map.layers, 1 do
				if map.layers[i].properties.level == options.level then
					--local tile = getTileAt({ locX = options.locX, locY = options.locY, layer = i})
					------------------------------------------------------------------------------
						local locX = options.locX
						local locY = options.locY
						local layer = i
						if locX > layerWidth[layer] then
							while locX > layerWidth[layer] do
								locX = locX - layerWidth[layer]
							end
						elseif locX < 1 then
							while locX < 1 do
								locX = locX + layerWidth[layer]
							end
						end
						if locY > layerHeight[layer] then
							while locY > layerHeight[layer] do
								locY = locY - layerHeight[layer]
							end
						elseif locY < 1 then
							while locY < 1 do
								locY = locY + layerHeight[layer]
							end
						end
						local tile = map.layers[layer].world[locX][locY]
					------------------------------------------------------------------------------
					local tileset = 1
					for i = #map.tilesets, 1, -1 do
						if tile > map.tilesets[i].firstgid then
							tileset = i
							break
						end
					end
					array[#array + 1] = {}
					array[#array].tile = tile
					array[#array].layer = i
					if map.tilesets[tileset].tileproperties then
						local tileStr = 0
						if tileset == 1 then
							tileStr = tostring(tile - 1)
						else
							tileStr = tostring(tile - map.tilesets[tileset].firstgid)
						end
						array[#array].properties = map.tilesets[tileset].tileproperties[tileStr]
					else
						array[#array].properties = nil
					end
					if map.layers[i].properties then
						array[#array].level = map.layers[i].properties.level
						array[#array].scaleX = map.layers[i].properties.scaleX
						array[#array].scaleY = map.layers[i].properties.scaleY
					end
				end
			end
			return array
		else
			local array = {}
			for i = 1, #map.layers, 1 do
				--local tile = getTileAt({locX = options.locX, locY = options.locY, layer = i})
				------------------------------------------------------------------------------
					local locX = options.locX
					local locY = options.locY
					local layer = i
					if locX > layerWidth[layer] then
						while locX > layerWidth[layer] do
							locX = locX - layerWidth[layer]
						end
					elseif locX < 1 then
						while locX < 1 do
							locX = locX + layerWidth[layer]
						end
					end
					if locY > layerHeight[layer] then
						while locY > layerHeight[layer] do
							locY = locY - layerHeight[layer]
						end
					elseif locY < 1 then
						while locY < 1 do
							locY = locY + layerHeight[layer]
						end
					end
					local tile = map.layers[layer].world[locX][locY]
				------------------------------------------------------------------------------
				local tileset = 1
				for i = #map.tilesets, 1, -1 do
					if tile > map.tilesets[i].firstgid then
						tileset = i
						break
					end
				end
				array[i] = {}
				array[i].tile = tile
				if map.tilesets[tileset].tileproperties then
					local tileStr = 0
					if tileset == 1 then
						tileStr = tostring(tile - 1)
					else
						tileStr = tostring(tile - map.tilesets[tileset].firstgid)
					end
					array[i].properties = map.tilesets[tileset].tileproperties[tileStr]
				else
					array[i].properties = nil
				end
				if map.layers[i].properties then
					array[i].level = map.layers[i].properties.level
					array[i].scaleX = map.layers[i].properties.scaleX
					array[i].scaleY = map.layers[i].properties.scaleY
				end
			end
			return array
		end
	end
end
M.getTileProperties = getTileProperties

local getLayerProperties = function(layer)
	if not layer then
		layer = refLayer
		print("ERROR: no layer specified. Defaulting to layer "..refLayer..".")
	end
	local lyr = layer
	if lyr > #map.layers then
		print("ERROR: layer too high. Defaulting to top layer.")
		lyr = #map.layers
	elseif lyr < 1 then
		print("ERROR: layer too low. Defaulting to layer 1")
		lyr = 1
	end
	if map.layers[lyr].properties then
		return map.layers[lyr].properties
	else
		print("WARNING(getTileProperties): No layer properties.")
		return nil
	end
end
M.getLayerProperties = getLayerProperties

local getMapProperties = function()
	if map.properties then
		return map.properties
	else
		print("WARNING(getMapProperties): No map properties detected.")
		return nil
	end
end
M.getMapProperties = getMapProperties

local getObject = function(options)
	local properties = {}
	if options.layer then
		local properties = {}
		local layer = options.layer
		if not map.layers[layer].properties.objectLayer then
			print("ERROR: layer not an objectLayer.")
		end
		if options.locX and map.layers[layer].properties.objectLayer then
			for i = 1, #map.layers[layer].objects, 1 do
				local object = map.layers[layer].objects[i]
				local nativeSize = map.tilesets[1].tilewidth
				if options.locX >= ceil((object.x + 1) / worldScaleX) and options.locX <= ceil((object.x + object.width) / worldScaleX)
				and options.locY >= ceil((object.y + 1) / worldScaleY) and options.locY <= ceil((object.y + object.height) / worldScaleY) then
					object.layer = layer
					properties[#properties + 1] = object
				end
			end
			if properties[1] then
				return properties
			end
		elseif options.levelPosX and map.layers[layer].properties.objectLayer then
			for i = 1, #map.layers[layer].objects, 1 do
				local object = map.layers[layer].objects[i]
				if object.x == options.levelPosX and object.y == options.levelPosY then
					object.layer = layer
					properties[#properties + 1] = object
				end
			end
			if properties[1] then
				return properties
			end
		elseif options.name and map.layers[layer].properties.objectLayer then
			for i = 1, #map.layers[layer].objects, 1 do
				local object = map.layers[layer].objects[i]
				if object.name == options.name then
					object.layer = layer
					properties[#properties + 1] = object
				end
			end
			if properties[1] then
				return properties
			end
		elseif options.type and map.layers[layer].properties.objectLayer then
			for i = 1, #map.layers[layer].objects, 1 do
				local object = map.layers[layer].objects[i]
				if object.type == options.type then
					object.layer = layer
					properties[#properties + 1] = object
				end
			end
			if properties[1] then
				return properties
			end
		elseif map.layers[layer].properties.objectLayer then
			for i = 1, #map.layers[layer].objects, 1 do
				local object = map.layers[layer].objects[i]
				object.layer = layer
				properties[#properties + 1] = object
			end
			if properties[1] then
				return properties
			end
		end
	elseif options.level then
		local properties = {}
		for j = 1, #map.layers, 1 do
			if getLevel(j) == options.level then
				local layer = j
				if options.locX and map.layers[layer].properties.objectLayer then
					for i = 1, #map.layers[layer].objects, 1 do
						local object = map.layers[layer].objects[i]
						local nativeSize = map.tilesets[1].tilewidth
						if options.locX >= ceil((object.x + 1) / worldScaleX) and options.locX <= ceil((object.x + object.width) / worldScaleX)
						and options.locY >= ceil((object.y + 1) / worldScaleY) and options.locY <= ceil((object.y + object.height) / worldScaleY) then
							object.layer = layer
							properties[#properties + 1] = object
						end
					end
				elseif options.levelPosX and map.layers[layer].properties.objectLayer then
					for i = 1, #map.layers[layer].objects, 1 do
						local object = map.layers[layer].objects[i]
						if object.x == options.levelPosX and object.y == options.levelPosY then
							object.layer = layer
							properties[#properties + 1] = object
						end
					end
				elseif options.name and map.layers[layer].properties.objectLayer then
					for i = 1, #map.layers[layer].objects, 1 do
						local object = map.layers[layer].objects[i]
						if object.name == options.name then
							object.layer = layer
							properties[#properties + 1] = object
						end
					end
				elseif options.type and map.layers[layer].properties.objectLayer then
					for i = 1, #map.layers[layer].objects, 1 do
						local object = map.layers[layer].objects[i]
						if object.type == options.type then
							object.layer = layer
							properties[#properties + 1] = object
						end
					end
				elseif map.layers[layer].properties.objectLayer then
					for i = 1, #map.layers[layer].objects, 1 do
						local object = map.layers[layer].objects[i]
						object.layer = layer
						properties[#properties + 1] = object
					end
				end
			end
		end
		if properties[1] then
			return properties
		end
	else
		local properties = {}
		for j = 1, #map.layers, 1 do
			local layer = j
			if options.locX and map.layers[layer].properties.objectLayer then
				for i = 1, #map.layers[layer].objects, 1 do
					local object = map.layers[layer].objects[i]
					local nativeSize = map.tilesets[1].tilewidth
					if options.locX >= ceil((object.x + 1) / worldScaleX) and options.locX <= ceil((object.x + object.width) / worldScaleX)
					and options.locY >= ceil((object.y + 1) / worldScaleY) and options.locY <= ceil((object.y + object.height) / worldScaleY) then
						object.layer = layer
						properties[#properties + 1] = object
					end
				end
			elseif options.levelPosX and map.layers[layer].properties.objectLayer then
				for i = 1, #map.layers[layer].objects, 1 do
					local object = map.layers[layer].objects[i]
					if object.x == options.levelPosX and object.y == options.levelPosY then
						object.layer = layer
						properties[#properties + 1] = object
					end
				end
			elseif options.name and map.layers[layer].properties.objectLayer then
				for i = 1, #map.layers[layer].objects, 1 do
					local object = map.layers[layer].objects[i]
					if object.name == options.name then
						object.layer = layer
						properties[#properties + 1] = object
					end
				end
			elseif options.type and map.layers[layer].properties.objectLayer then
				for i = 1, #map.layers[layer].objects, 1 do
					local object = map.layers[layer].objects[i]
					if object.type == options.type then
						object.layer = layer
						properties[#properties + 1] = object
					end
				end
			elseif map.layers[layer].properties.objectLayer then
				for i = 1, #map.layers[layer].objects, 1 do
					local object = map.layers[layer].objects[i]
					object.layer = layer
					properties[#properties + 1] = object
				end
			end
		end
		if properties[1] then
			return properties
		else
			print("WARNING(getObjectProperties): No properties found.")
		end
	end
end
M.getObject = getObject

local setTileProperties = function(tile, table)
	if tile ~= 0 then
		local tileset = 1
		for i = 1, #map.tilesets, 1 do
			if tile > map.tilesets[i].firstgid then
				tileset = i
				break
			end
		end
		local tileStr = 0
		if tileset == 1 then
			tileStr = tostring(tile - 1)
		else
			tileStr = tostring(tile - 1)
		end
		if map.tilesets[tileset].tileproperties then
			map.tilesets[tileset].tileproperties = {}
		end
		map.tilesets[tileset].tileproperties[tileStr] = table
	end
end
M.setTileProperties = setTileProperties

local setLayerProperties = function(layer, table)
	if not layer then
		print("ERROR: No layer specified.")
	end
	local lyr = layer
	if lyr > #map.layers then
		print("ERROR: layer too high. Defaulting to top layer.")
		lyr = #map.layers
	elseif lyr < 1 then
		print("ERROR: layer too low. Defaulting to layer 1.")
		lyr = 1
	end
	map.layers[lyr].properties = table
	if not map.layers[lyr].properties then
		map.layers[lyr].properties = {}
		map.layers[lyr].properties.level = 1
		map.layers[lyr].properties.scaleX = 1
		map.layers[lyr].properties.scaleY = 1
	else
		if not map.layers[lyr].properties.level then
			map.layers[lyr].properties.level = 1
		end
		if map.layers[lyr].properties.scale then
			map.layers[lyr].properties.scaleX = map.layers[lyr].properties.scale
			map.layers[lyr].properties.scaleY = map.layers[lyr].properties.scale
		else
			if not map.layers[lyr].properties.scaleX then
				map.layers[lyr].properties.scaleX = 1
			end
			if not map.layers[lyr].properties.scaleY then
				map.layers[lyr].properties.scaleY = 1
			end
		end
	end
	if map.layers[lyr].properties.parallax then
		map.layers[lyr].parallaxX = map.layers[lyr].properties.parallax / map.layers[lyr].properties.scaleX
		map.layers[lyr].parallaxY = map.layers[lyr].properties.parallax / map.layers[lyr].properties.scaleY
	else
		if map.layers[lyr].properties.parallaxX then
			map.layers[lyr].parallaxX = map.layers[lyr].properties.parallaxX / map.layers[lyr].properties.scaleX
		else
			map.layers[lyr].parallaxX = 1
		end
		if map.layers[lyr].properties.parallaxY then
			map.layers[lyr].parallaxY = map.layers[lyr].properties.parallaxY / map.layers[lyr].properties.scaleY
		else
			map.layers[lyr].parallaxY = 1
		end
	end
	--CHECK REFERENCE LAYER
	if refLayer == lyr then
		if map.layers[lyr].parallaxX ~= 1 or map.layers[lyr].parallaxY ~= 1 then
			for i = 1, #map.layers, 1 do
				if map.layers[i].parallaxX == 1 and map.layers[i].parallaxY == 1 then
					refLayer = i
					break
				end
			end
			if not refLayer then
				refLayer = 1
			end
		end
	end
	
	--DETECT LAYER WRAP
	layerWrapX[lyr] = worldWrapX
	layerWrapY[lyr] = worldWrapY
	if map.layers[lyr].properties.wrap then
		if map.layers[lyr].properties.wrap == "true" then
			layerWrapX[lyr] = true
			layerWrapY[lyr] = true
		elseif map.layers[lyr].properties.wrap == "false" then
			layerWrapX[lyr] = false
			layerWrapY[lyr] = false
		end
	end
	if map.layers[lyr].properties.wrapX then
		if map.layers[lyr].properties.wrapX == "true" then
			layerWrapX[lyr] = true
		elseif map.layers[lyr].properties.wrapX == "false" then
			layerWrapX[lyr] = false
		end
	end
	if map.layers[lyr].properties.wrapY then
		if map.layers[lyr].properties.wrapY == "true" then
			layerWrapY[lyr] = true
		elseif map.layers[lyr].properties.wrapY == "false" then
			layerWrapX[lyr] = false
		end
	end
	--LIGHTING
	if map.properties then
		if map.properties.lightingStyle then
			local levelLighting = {}
			for i = 1, map.numLevels, 1 do
				levelLighting[i] = {}
			end
			if not map.properties.lightRedStart then
				map.properties.lightRedStart = "255"
			end
			if not map.properties.lightGreenStart then
				map.properties.lightGreenStart = "255"
			end
			if not map.properties.lightBlueStart then
				map.properties.lightBlueStart = "255"
			end
			if map.properties.lightingStyle == "diminish" then
				local rate = tonumber(map.properties.lightRate)
				levelLighting[map.numLevels].red = tonumber(map.properties.lightRedStart)
				levelLighting[map.numLevels].green = tonumber(map.properties.lightGreenStart)
				levelLighting[map.numLevels].blue = tonumber(map.properties.lightBlueStart)
				for i = map.numLevels - 1, 1, -1 do
					levelLighting[i].red = levelLighting[map.numLevels].red - (rate * (map.numLevels - i))
					if levelLighting[i].red < 0 then
						levelLighting[i].red = 0
					end
					levelLighting[i].green = levelLighting[map.numLevels].green - (rate * (map.numLevels - i))
					if levelLighting[i].green < 0 then
						levelLighting[i].green = 0
					end
					levelLighting[i].blue = levelLighting[map.numLevels].blue - (rate * (map.numLevels - i))
					if levelLighting[i].blue < 0 then
						levelLighting[i].blue = 0
					end
				end
			end
			for i = 1, #map.layers, 1 do
				if map.layers[i].properties.lightRed then
					map.layers[i].redLight = tonumber(map.layers[i].properties.lightRed)
				else
					map.layers[i].redLight = levelLighting[map.layers[i].properties.level].red
				end
				if map.layers[i].properties.lightGreen then
					map.layers[i].greenLight = tonumber(map.layers[i].properties.lightGreen)
				else
					map.layers[i].greenLight = levelLighting[map.layers[i].properties.level].green
				end
				if map.layers[i].properties.lightBlue then
					map.layers[i].blueLight = tonumber(map.layers[i].properties.lightBlue)
				else
					map.layers[i].blueLight = levelLighting[map.layers[i].properties.level].blue
				end
			end
		else
			for i = 1, #map.layers, 1 do
				map.layers[i].redLight = 255
				map.layers[i].greenLight = 255
				map.layers[i].blueLight = 255
			end
		end
	end
end
M.setLayerProperties = setLayerProperties

local setMapProperties = function(table)
	map.properties = table
	--LIGHTING
	if map.properties then
		if map.properties.lightingStyle then
			local levelLighting = {}
			for i = 1, map.numLevels, 1 do
				levelLighting[i] = {}
			end
			if not map.properties.lightRedStart then
				map.properties.lightRedStart = "255"
			end
			if not map.properties.lightGreenStart then
				map.properties.lightGreenStart = "255"
			end
			if not map.properties.lightBlueStart then
				map.properties.lightBlueStart = "255"
			end
			if map.properties.lightingStyle == "diminish" then
				local rate = tonumber(map.properties.lightRate)
				levelLighting[map.numLevels].red = tonumber(map.properties.lightRedStart)
				levelLighting[map.numLevels].green = tonumber(map.properties.lightGreenStart)
				levelLighting[map.numLevels].blue = tonumber(map.properties.lightBlueStart)
				for i = map.numLevels - 1, 1, -1 do
					levelLighting[i].red = levelLighting[map.numLevels].red - (rate * (map.numLevels - i))
					if levelLighting[i].red < 0 then
						levelLighting[i].red = 0
					end
					levelLighting[i].green = levelLighting[map.numLevels].green - (rate * (map.numLevels - i))
					if levelLighting[i].green < 0 then
						levelLighting[i].green = 0
					end
					levelLighting[i].blue = levelLighting[map.numLevels].blue - (rate * (map.numLevels - i))
					if levelLighting[i].blue < 0 then
						levelLighting[i].blue = 0
					end
				end
			end
			for i = 1, #map.layers, 1 do
				if map.layers[i].properties.lightRed then
					map.layers[i].redLight = tonumber(map.layers[i].properties.lightRed)
				else
					map.layers[i].redLight = levelLighting[map.layers[i].properties.level].red
				end
				if map.layers[i].properties.lightGreen then
					map.layers[i].greenLight = tonumber(map.layers[i].properties.lightGreen)
				else
					map.layers[i].greenLight = levelLighting[map.layers[i].properties.level].green
				end
				if map.layers[i].properties.lightBlue then
					map.layers[i].blueLight = tonumber(map.layers[i].properties.lightBlue)
				else
					map.layers[i].blueLight = levelLighting[map.layers[i].properties.level].blue
				end
			end
		else
			for i = 1, #map.layers, 1 do
				map.layers[i].redLight = 255
				map.layers[i].greenLight = 255
				map.layers[i].blueLight = 255
			end
		end
	end
end
M.setMapProperties = setMapProperties

local setObjectProperties = function(name, table, layer)
	if not layer then
		local debug = 0
		for j = 1, #map.layers, 1 do
			local layer = j
			if map.layers[layer].properties.objectLayer then
				for i = 1, #map.layers[layer].objects, 1 do
					local object = map.layers[layer].objects[i]
					if object.name == name then
						map.layers[layer].objects[i] = table
						debug = 1
						break
					end
				end
			end
			if debug == 1 then
				break
			end
		end
		if debug == 0 then
			print("ERROR: Object Not Found.")
		end
	else
		local debug = 0
		if map.layers[layer].properties.objectLayer then
			for i = 1, #map.layers[layer].objects, 1 do
				local object = map.layers[layer].objects[i]
				if object.name == name then
					map.layers[layer].objects[i] = table
					debug = 1
				end
			end
		else
			print("ERROR: Not an Object Layer.")
		end
		if debug == 0 then
			print("ERROR: Object Not Found.")
		end
	end
end
M.setObjectProperties = setObjectProperties

local refresh = function()
	setMapProperties(map.properties)
	for i = 1, #map.layers, 1 do
		setLayerProperties(i, map.layers[i].properties)
	end
	for i = 1, #map.layers, 1 do
		goto({layer = i, levelPosX = cameraX[i], levelPosY = cameraY[i], blockScaleX = blockScaleX, blockScaleY = blockScaleY})
	end
end
M.refresh = refresh

local getVisibleLayer = function(locX, locY)
	local layer = #map.layers
	for i = #map.layers, 1, -1 do
		if map.layers[i].world[locX][locY] ~= 0 
		and displayGroups[i].isVisible 
		and displayGroups[i].alpha > 0 
		and not map.layers[i].properties.objectLayer then
			layer = i
			break
		end
	end
	return layer
end
M.getVisibleLayer = getVisibleLayer

local getVisibleLevel = function(locX, locY)
	local layer = #map.layers
	for i = #map.layers, 1, -1 do
		if map.layers[i].world[locX][locY] ~= 0 
		and displayGroups[i].isVisible 
		and displayGroups[i].alpha > 0 
		and not map.layers[i].properties.objectLayer then
			layer = i
			break
		end
	end
	return map.layers[layer].properties.level
end
M.getVisibleLevel = getVisibleLevel

local getSpriteLayer = function(level)
	for i = 1, #map.layers, 1 do
		if map.layers[i].properties.level == level and map.layers[i].properties.spriteLayer == "true" then
			return i
		end
	end
end
M.getSpriteLayer = getSpriteLayer

local getObjectLayer = function(level)
	for i = 1, #map.layers, 1 do
		if map.layers[i].properties.level == level and map.layers[i].properties.objectLayer then
			return i
		end
	end
end
M.getObjectLayer = getObjectLayer

local getLayers = function(parameters)
	if parameters then
		if parameters.layer then
			return map.layers[parameters.layer]
		elseif parameters.level then
			local array = {}
			for i = 1, #map.layers, 1 do
				if map.layers[i].properties.level == parameters.level then
					array[#array + 1] = map.layers[i]
				end
			end
			return array
		end
	else
		local array = {}
		for i = 1, #map.layers, 1 do
			array[#array + 1] = map.layers[i]
		end
		return array
	end
end
M.getLayers = getLayers

local getMapObj = function()
	return masterGroup
end
M.getMapObj = getMapObj

local getLayerObj = function(parameters)
	if parameters then
		if parameters.layer then
			return displayGroups[parameters.layer]
		elseif parameters.level then
			local array = {}
			for i = 1, #map.layers, 1 do
				if map.layers[i].properties.level == parameters.level then
					array[#array + 1] = displayGroups[i]
				end
			end
			return array
		end
	else
		local array = {}
		for i = 1, #map.layers, 1 do
			array[#array + 1] = displayGroups[i]
		end
		return array
	end
end
M.getLayerObj = getLayerObj

local getTileObj = function(locX, locY, layer)
	if not layer then
		layer = refLayer
	end
	local rect = convert("locToGrid", locX, locY, layer)
	if rect.x and rect.y then
		if rects[layer][rect.x][rect.y] ~= 9999 then
			return rects[layer][rect.x][rect.y]
		end
	else
		return nil
	end
end
M.getTileObj = getTileObj

local getMap = function()
	return map
end
M.getMap = getMap

local updateBlockExt = function(input)
	local wrappingX = false
	local wrappingY = false
	local locX = input.locX
	local locY = input.locY
	local block = input.tile
	local posX = input.posX
	local posY = input.posY
	local rectX = input.gridX
	local rectY = input.gridY
	local isShifting = input.isShifting
	local layer = input.layer
	if not layer then
		layer = refLayer
	elseif layer > #map.layers then
		print("WARNING(updateTile): Layer doesn't exist. Defaulting to #map.layers.")
		layer = #map.layers
	elseif layer <= 0 then
		print("WARNING(updateTile): Layer doesn't exist. Defaulting to 1.")
		layer = 1
	end
	if not rect1LocXt then
		rect1LocXt = rect1LocX[layer]
	end
	if not rect1LocYt then
		rect1LocYt = rect1LocY[layer]
	end
	if locX > layerWidth[layer] then
		wrappingX = true
		while locX > layerWidth[layer] do
			locX = locX - layerWidth[layer]
			rect1LocXt = rect1LocXt - layerWidth[layer]
		end
	elseif locX < 1 then
		wrappingX = true
		while locX < 1 do
			locX = locX + layerWidth[layer]
			rect1LocXt = rect1LocXt + layerWidth[layer]
		end
	end
	if locY > layerHeight[layer] then
		wrappingY = true
		while locY > layerHeight[layer] do
			locY = locY - layerHeight[layer]
			rect1LocYt = rect1LocYt - layerHeight[layer]
		end
	elseif locY < 1 then
		wrappingY = true
		while locY < 1 do
			locY = locY + layerHeight[layer]
			rect1LocYt = rect1LocYt + layerHeight[layer]
		end
	end
	if not rectX or not rectY then
		local rect = convert("locToGrid", locX, locY, layer)
		if rect.x and rect.y then
			rectX = rect.x
			rectY = rect.y
		else
			rectX = 9999
			rectY = 9999
		end
	end
	local tempScaleX = blockScaleX * map.layers[layer].properties.scaleX
	local tempScaleY = blockScaleY * map.layers[layer].properties.scaleY
	local frameIndex
	if not block then
		frameIndex = map.layers[layer].world[locX][locY]
	else
		frameIndex = block
		map.layers[layer].world[locX][locY] = block
	end
	if wrappingX and not layerWrapX[layer] then
		frameIndex = 0
	end
	if wrappingY and not layerWrapY[layer] then
		frameIndex = 0
	end
	if rectX > 0 and rectX <= rectsWidth[layer] and rectY > 0 and rectY <= rectsHeight[layer] then
		local tileSetIndex = 1
		for i = 1, #map.tilesets, 1 do
			if frameIndex >= map.tilesets[i].firstgid then
				--tileSetIndex = tileSetIndex + (i - 1)
				tileSetIndex = i
			else
				break
			end
		end
		if frameIndex == 0 then
			if rects[layer][rectX][rectY] ~= 9999 then
				rects[layer][rectX][rectY]:removeSelf()
				if rects[layer][rectX][rectY].sync then
					animatedTiles[rects[layer][rectX][rectY]] = nil
				end
				rects[layer][rectX][rectY] = 9999
				totalRects[layer] = totalRects[layer] - 1
			end
		elseif frameIndex > 0 then
			frameIndex = frameIndex - (map.tilesets[tileSetIndex].firstgid - 1)
			if tileSetIndex == 1 then
				tileStr = tostring(frameIndex - 1)
			else
				--tileStr = tostring(frameIndex - map.tilesets[tileSetIndex].firstgid)
				tileStr = tostring(frameIndex - 1)
			end
			if not posX then
				local temp = convert("gridToScreenPos", rectX, rectY, layer)
				posX = temp.x
			end
			if not posY then
				local temp = convert("gridToScreenPos", rectX, rectY, layer)
				posY = temp.y
			end
			if rects[layer][rectX][rectY] ~= 9999 then
				rects[layer][rectX][rectY]:removeSelf()
				if rects[layer][rectX][rectY].sync then
					animatedTiles[rects[layer][rectX][rectY]] = nil
				end
				rects[layer][rectX][rectY] = 9999
				totalRects[layer] = totalRects[layer] - 1
			end
			if map.tilesets[tileSetIndex].tileproperties then
				if map.tilesets[tileSetIndex].tileproperties[tileStr] then
					if map.tilesets[tileSetIndex].tileproperties[tileStr]["animFrames"] then
						rects[layer][rectX][rectY] = display.newSprite(displayGroups[layer],tileSets[tileSetIndex], 
														map.tilesets[tileSetIndex].tileproperties[tileStr]["sequenceData"])
						--rects[layer][rectX][rectY].xScale = findScale(worldScale, layer)
						--rects[layer][rectX][rectY].yScale = findScale(worldScale, layer)
						rects[layer][rectX][rectY].xScale = findScaleX(worldScaleX, layer)
						rects[layer][rectX][rectY].yScale = findScaleY(worldScaleY, layer)
						rects[layer][rectX][rectY].layer = layer
						rects[layer][rectX][rectY]:setSequence("null")
						rects[layer][rectX][rectY].sync = map.tilesets[tileSetIndex].tileproperties[tileStr]["animSync"]
						animatedTiles[rects[layer][rectX][rectY]] = rects[layer][rectX][rectY]
					else
						rects[layer][rectX][rectY] = display.newImageRect(displayGroups[layer], 
							tileSets[tileSetIndex], frameIndex, tempScaleX, tempScaleY
						)
					end
				else
					rects[layer][rectX][rectY] = display.newImageRect(displayGroups[layer], 
						tileSets[tileSetIndex], frameIndex, tempScaleX, tempScaleY
					)
				end
			else
				rects[layer][rectX][rectY] = display.newImageRect(displayGroups[layer], 
					tileSets[tileSetIndex], frameIndex, tempScaleX, tempScaleY
				)
			end
			rects[layer][rectX][rectY]:setFillColor(map.layers[layer].redLight, 
												map.layers[layer].greenLight,
												map.layers[layer].blueLight)
			totalRects[layer] = totalRects[layer] + 1
			rects[layer][rectX][rectY].layer = layer
			rects[layer][rectX][rectY].sX = posX
			rects[layer][rectX][rectY].sY = posY
			rects[layer][rectX][rectY].x = displayGroups[layer].sX + rects[layer][rectX][rectY].sX
			rects[layer][rectX][rectY].y = displayGroups[layer].sY + rects[layer][rectX][rectY].sY
			rects[layer][rectX][rectY].locX = locX
			rects[layer][rectX][rectY].locY = locY
			--rects[layer][rectX][rectY].index = tileStr
			rects[layer][rectX][rectY].index = frameIndex
			rects[layer][rectX][rectY].tile = tileStr
			rects[layer][rectX][rectY].getX = function(self)
				local temp1, temp2 = self:localToContent(0, 0)
				return temp1
			end
			rects[layer][rectX][rectY].getY = function(self)
				local temp1, temp2 = self:localToContent(0, 0)
				return temp2
			end
		end
	end
end
M.updateTile = updateBlockExt

local updateBlock = function(locX, locY, block, posX, posY, rectX, rectY, isShifting, layer)
	local wrappingX = false
	local wrappingY = false
	if not layer then
		layer = refLayer
	end
	if not rect1LocXt then
		rect1LocXt = rect1LocX[layer]
	end
	if not rect1LocYt then
		rect1LocYt = rect1LocY[layer]
	end
	if locX > layerWidth[layer] then
		wrappingX = true
		while locX > layerWidth[layer] do
			locX = locX - layerWidth[layer]
			rect1LocXt = rect1LocXt - layerWidth[layer]
		end
	elseif locX < 1 then
		wrappingX = true
		while locX < 1 do
			locX = locX + layerWidth[layer]
			rect1LocXt = rect1LocXt + layerWidth[layer]
		end
	end
	if locY > layerHeight[layer] then
		wrappingY = true
		while locY > layerHeight[layer] do
			locY = locY - layerHeight[layer]
			rect1LocYt = rect1LocYt - layerHeight[layer]
		end
	elseif locY < 1 then
		wrappingY = true
		while locY < 1 do
			locY = locY + layerHeight[layer]
			rect1LocYt = rect1LocYt + layerHeight[layer]
		end
	end
	if not rectX or not rectY then
		local rect = convert("locToGrid", locX, locY, layer)
		if rect.sX and rect.sY then
			rectX = rect.sX
			rectY = rect.sY
		else
			rectX = 9999
			rectY = 9999
		end
	end
	local tempScaleX = blockScaleX * map.layers[layer].properties.scaleX
	local tempScaleY = blockScaleY * map.layers[layer].properties.scaleY
	local frameIndex
	if not block then
		frameIndex = map.layers[layer].world[locX][locY]
	else
		frameIndex = block
	end
	local tileSetIndex = 1
	for i = 1, #map.tilesets, 1 do
		if frameIndex >= map.tilesets[i].firstgid then
			--tileSetIndex = tileSetIndex + (i - 1)
			tileSetIndex = i
		else
			break
		end
	end
	if wrappingX and not layerWrapX[layer] then
		frameIndex = 0
	end
	if wrappingY and not layerWrapY[layer] then
		frameIndex = 0
	end
	if frameIndex == 0 then
		if rects[layer][rectX][rectY] ~= 9999 then
			rects[layer][rectX][rectY]:removeSelf()
			if rects[layer][rectX][rectY].sync then
				animatedTiles[rects[layer][rectX][rectY]] = nil
			end
			rects[layer][rectX][rectY] = 9999
			totalRects[layer] = totalRects[layer] - 1
		end
	elseif frameIndex > 0 then
		frameIndex = frameIndex - (map.tilesets[tileSetIndex].firstgid - 1)
		if tileSetIndex == 1 then
			tileStr = tostring(frameIndex - 1)
		else
			--tileStr = tostring(frameIndex - map.tilesets[tileSetIndex].firstgid)
			tileStr = tostring(frameIndex - 1)
		end
		if not posX then
			local temp = convert("gridToScreenPos", rectX, rectY, layer)
			posX = temp.sX
		end
		if not posY then
			local temp = convert("gridToScreenPos", rectX, rectY, layer)
			posY = temp.sY
		end
		if rects[layer][rectX][rectY] ~= 9999 then
			rects[layer][rectX][rectY]:removeSelf()
			if rects[layer][rectX][rectY].sync then
				animatedTiles[rects[layer][rectX][rectY]] = nil
			end
			rects[layer][rectX][rectY] = 9999
			totalRects[layer] = totalRects[layer] - 1
		end
		if map.tilesets[tileSetIndex].tileproperties then
			if map.tilesets[tileSetIndex].tileproperties[tileStr] then
				if map.tilesets[tileSetIndex].tileproperties[tileStr]["animFrames"] then
					rects[layer][rectX][rectY] = display.newSprite(displayGroups[layer],tileSets[tileSetIndex], 
													map.tilesets[tileSetIndex].tileproperties[tileStr]["sequenceData"])
					--rects[layer][rectX][rectY].xScale = findScale(worldScale, layer)
					--rects[layer][rectX][rectY].yScale = findScale(worldScale, layer)
					--rects[layer][rectX][rectY].xScale, rects[layer][rectX][rectY].yScale = findScale(worldScale, layer)
					rects[layer][rectX][rectY].xScale = findScaleX(worldScaleX, layer)
					rects[layer][rectX][rectY].yScale = findScaleY(worldScaleY, layer)
					rects[layer][rectX][rectY].layer = layer
					rects[layer][rectX][rectY]:setSequence("null")
					rects[layer][rectX][rectY].sync = map.tilesets[tileSetIndex].tileproperties[tileStr]["animSync"]
					animatedTiles[rects[layer][rectX][rectY]] = rects[layer][rectX][rectY]
				else
					rects[layer][rectX][rectY] = display.newImageRect(displayGroups[layer], 
						tileSets[tileSetIndex], frameIndex, tempScaleX, tempScaleY
					)
				end
			else
				rects[layer][rectX][rectY] = display.newImageRect(displayGroups[layer], 
					tileSets[tileSetIndex], frameIndex, tempScaleX, tempScaleY
				)
			end
		else
			rects[layer][rectX][rectY] = display.newImageRect(displayGroups[layer], 
				tileSets[tileSetIndex], frameIndex, tempScaleX, tempScaleY
			)
		end
		rects[layer][rectX][rectY]:setFillColor(map.layers[layer].redLight, 
												map.layers[layer].greenLight,
												map.layers[layer].blueLight)
		totalRects[layer] = totalRects[layer] + 1
		rects[layer][rectX][rectY].sX = posX
		rects[layer][rectX][rectY].sY = posY
		rects[layer][rectX][rectY].x = displayGroups[layer].sX + rects[layer][rectX][rectY].sX
		rects[layer][rectX][rectY].y = displayGroups[layer].sY + rects[layer][rectX][rectY].sY
		rects[layer][rectX][rectY].layer = layer
		rects[layer][rectX][rectY].locX = locX
		rects[layer][rectX][rectY].locY = locY
		rects[layer][rectX][rectY].index = frameIndex
		rects[layer][rectX][rectY].tile = tileStr
		rects[layer][rectX][rectY].getX = function(self)
			local temp1, temp2 = self:localToContent(0, 0)
			return temp1
		end
		rects[layer][rectX][rectY].getY = function(self)
			local temp1, temp2 = self:localToContent(0, 0)
			return temp2
		end
	end
end

goto = function(parameters)
	local layer = parameters.layer
	if not layer or layer < 1 or layer > #map.layers then
		print("WARNING(goto): Layer out of bounds. Defaulting to layer 1.")
		layer = refLayer
	end
	
	for key,value in pairs(animatedTiles) do
		if animatedTiles[key].layer == parameters.layer then
			animatedTiles[key] = nil
		end
	end
	
	if parameters.blockScaleX then
		blockScaleX = parameters.blockScaleX
	elseif parameters.blockScale then
		blockScaleX = parameters.blockScale
	end
	if parameters.blockScaleY then
		blockScaleY = parameters.blockScaleY
	elseif parameters.blockScale then
		blockScaleY = parameters.blockScale
	end

	M.blockScaleX = blockScaleX
	M.blockScaleY = blockScaleY
	
	scaleFactorX = blockScaleX / worldScaleX
	scaleFactorY = blockScaleY / worldScaleY
	
	local i = layer

	local locX
	local locY
	local offsetX = 0
	local offsetY = 0
	if parameters.levelPosX and parameters.levelPosY then
		parameters.levelPosX = parameters.levelPosX-- - blockScaleX * 0.5
		parameters.levelPosY = parameters.levelPosY-- - blockScaleY * 0.5
		local location = convert("levelPosToLoc", parameters.levelPosX, parameters.levelPosY, nil, true, true)
		locX = location.x
		locY = location.y
		local levelPos = convert("locToLevelPos", locX, locY, nil, true, true)
		offsetX = parameters.levelPosX - levelPos.x - blockScaleX * 0.5
		offsetY = parameters.levelPosY - levelPos.y - blockScaleY * 0.5
	elseif parameters.sprite then
		locX = objects[parameters.sprite].locX
		locY = objects[parameters.sprite].locY
	elseif parameters.locX and parameters.locY then
		locX = parameters.locX
		locY = parameters.locY
	else
		--print("ERROR: No position data. Please specify a location, level position, or object.")
	end

	local prevPosX
	local prevPosY
	if cameraX[i] ~= 0 and cameraX[i] then
		prevPosX = cameraX[i]
		prevPosY = cameraY[i]
	end
	
	for key,value in pairs(objects) do
		if objects[key].layer == layer then
			if prevScaleFactorX then
				objects[key].levelPosX = (objects[key].levelPosX / prevScaleFactorX) * scaleFactorX
				objects[key].levelPosY = (objects[key].levelPosY / prevScaleFactorY) * scaleFactorY
			end
			objects[key].xScale = (objects[key].levelWidth * scaleFactorX / objects[key].sourceWidth) * map.layers[objects[key].layer].properties.scaleX
			objects[key].yScale = (objects[key].levelHeight * scaleFactorY / objects[key].sourceHeight) * map.layers[objects[key].layer].properties.scaleY
			local screenPos = convert("levelPosToScreenPos", objects[key].levelPosX, objects[key].levelPosY, objects[key].layer)
			objects[key].sX = screenPos.x + objects[key].offsetX * scaleFactorX
			objects[key].sY = screenPos.y + objects[key].offsetY * scaleFactorY
			--objects[key].x = objects[key].sX - displayGroups[objects[key].layer].sX
			--objects[key].y = objects[key].sY - displayGroups[objects[key].layer].sY
		end
	end
	
	
	--CLEAR CAMERA POSITION VARIABLES
	cameraX[i] = 0
	cameraY[i] = 0
	cameraLocX[i] = 0
	cameraLocY[i] = 0
	prevLocX[i] = 0
	prevLocY[i] = 0
	displayWidth = display.viewableContentWidth
	displayHeight = display.viewableContentHeight
	
	--DESTROY GRID
	if rects[i] then
		for x = 1, rectsWidth[i], 1 do
			for y = 1, rectsHeight[i], 1 do
				if rects[i][x][y] ~= 9999 then
					rects[i][x][y]:removeSelf()
				end
			end
		end
	end
	
	rectsWidth[i] = nil
	rectsHeight[i] = nil

	--DETERMINE RECT GRID SIZE AND POSITION
	rectsLeft = displayWidth / 2 - (ceil(displayWidth / 2 / blockScaleX) * blockScaleX - (blockScaleX * 0.5))
	if rectsLeft >= (blockScaleX * -0.5) then
		rectsLeft = rectsLeft - (blockScaleX * 2)
	end
	
	rectsTop = (displayHeight / 2) - (ceil((displayHeight / 2) / blockScaleY) * blockScaleY - (blockScaleY * 0.5))
	if rectsTop >= (blockScaleY * -0.5) then
		rectsTop = rectsTop - blockScaleY
	end
	totalRects[layer] = 0

	rects[i] = nil

	--DETERMINE RECT GRID OFFSETS
	local tempScaleX = blockScaleX * map.layers[i].properties.scaleX
	local tempScaleY = blockScaleY * map.layers[i].properties.scaleY
	--print(tempScaleX, tempScaleY)
	local rectsLeft = displayWidth / 2 - (ceil(displayWidth / 2 / tempScaleX) * tempScaleX - (tempScaleX * 0.5))
	if rectsLeft >= (tempScaleX * -0.5) then
		rectsLeft = rectsLeft - (tempScaleX * 2)
	end
	rectsOffsetX[i] = math.round((tempScaleX * 0.5 + (displayWidth / 2 - rectsLeft)) / tempScaleX)
	
	local rectsTop = (displayHeight / 2) - (ceil((displayHeight / 2) / tempScaleY) * tempScaleY - (tempScaleY * 0.5))
	if rectsTop >= (tempScaleY * -0.5) then
		rectsTop = rectsTop - tempScaleY
	end
	rectsOffsetY[i] = math.round((tempScaleY * 0.5 + ((displayHeight / 2) - rectsTop)) / tempScaleY)
	
	rectsWidth[i] = ceil((displayWidth + (rectsLeft * -1)) / tempScaleX) * tempScaleX
	if rectsWidth[i] < displayWidth + (rectsLeft * -1) - (tempScaleX * 0.5) then
		rectsWidth[i] = rectsWidth[i] + tempScaleX
	end
	rectsWidth[i] = rectsWidth[i] / tempScaleX
	if rectsWidth[i] % 2 ~= 0 then
		rectsWidth[i] = rectsWidth[i] + 1
	end
	rectsWidth[i] = rectsWidth[i] + 1
	rectsWidth[i] = math.round(rectsWidth[i])
	
	rectsHeight[i] = ceil((displayHeight - rectsTop + (tempScaleY * 2)) / tempScaleY)
	rectsHeight[i] = math.round(rectsHeight[i])

	anchorX[i] = (1 * tempScaleX - (tempScaleX * 0.5)) + rectsLeft
	anchorY[i] = (1 * tempScaleY - (tempScaleY * 0.5)) + rectsTop
	
	--CREATE GRIDS
	rects[i] = {}
	for x = 1, rectsWidth[i], 1 do
		rects[i][x] = {}
		for y = 1, rectsHeight[i], 1 do
			rects[i][x][y] = 9999
		end
	end
	
	--position camera, fill grid
	cameraLocX[i] = locX
	cameraLocY[i] = locY
	cameraX[i] = cameraLocX[i] * blockScaleX
	cameraY[i] = cameraLocY[i] * blockScaleY
	prevLocX[i] = cameraLocX[i]
	prevLocY[i] = cameraLocY[i]
	tempLocX[i] = cameraLocX[i]
	tempLocY[i] = cameraLocY[i]

	rect1LocX[i] = 1 + cameraLocX[i] - rectsOffsetX[i]
	rect1LocY[i] = 1 + cameraLocY[i] - rectsOffsetY[i]

	for x = 1, rectsWidth[i], 1 do
		for y = 1, rectsHeight[i], 1 do
			local tempScaleX = blockScaleX * map.layers[i].properties.scaleX
			local tempScaleY = blockScaleY * map.layers[i].properties.scaleY
			updateBlock(x + cameraLocX[i] - rectsOffsetX[i], y + cameraLocY[i] - rectsOffsetY[i], nil, 
				anchorX[i] + (tempScaleX * (x - 1)), anchorY[i] + (tempScaleY * (y-1)), x, y, nil, i
			)
		end
	end
	
	--move objects
	if prevPosX then
		local deltaX = cameraX[i] - prevPosX
		local deltaY = cameraY[i] - prevPosY
		for key,value in pairs(objects) do
			if objects[key] then
				if objects[key].layer == layer then
					local tempX = objects[key].sX - deltaX
					local distXWrap = tempX - cameraX[i]
					local distXAcross = objects[key].sX - cameraX[i]
					if distXWrap < distXAcross then
						objects[key].sX = objects[key].sX - deltaX
					end
				
					local tempY = objects[key].sY - deltaY
					local distYWrap = tempY - cameraY[i]
					local distYAcross = objects[key].sY - cameraY[i]
					if distYWrap < distXAcross then
						objects[key].sY = objects[key].sY - deltaY
					end
				end
			end
		end
	end
	
	--move camera
	if offsetX ~= 0 or offsetY ~= 0 then
		local velX = offsetX
		local velY = offsetY
		local remainingVelX = abs(velX)
		local remainingVelY = abs(velY)
		local velXSign = 1
		local velYSign = 1
		if velX < 0 then
			velXSign = -1
		else
			velXSign = 1
		end
		if velY < 0 then
			velYSign = -1
		else
			velYSign = 1
		end
		while remainingVelX > 0 or remainingVelY > 0 do
			local vX
			local vY
			if remainingVelX > blockScaleX / 5 then
				vX = blockScaleX / 5
				remainingVelX = remainingVelX - blockScaleX / 5
			else
				vX = remainingVelX
				remainingVelX = 0
			end
			if remainingVelY > blockScaleY / 5 then
				vY = blockScaleY / 5
				remainingVelY = remainingVelY - blockScaleY / 5
			else
				vY = remainingVelY
				remainingVelY = 0
			end
			moveCameraProc(i, vX * velXSign, vY * velYSign)
		end
	end
end

local gotoAll = function(parameters)
	if parameters.blockScaleX then
		blockScaleX = parameters.blockScaleX
	elseif parameters.blockScale then
		blockScaleX = parameters.blockScale
	end
	if parameters.blockScaleY then
		blockScaleY = parameters.blockScaleY
	elseif parameters.blockScale then
		blockScaleY = parameters.blockScale
	end
	if not parameters.ext then
		if scaleFactorX then
			prevScaleFactorX = scaleFactorX
		end
		if scaleFactorY then
			prevScaleFactorY = scaleFactorY
		end
	end
	scaleFactorX = blockScaleX / worldScaleX
	scaleFactorY = blockScaleY / worldScaleY	
	for i = 1, #map.layers, 1 do
		local para2 = {}
		for key,value in pairs(parameters) do
			para2[key] = value
		end
		--local temp = "1"
		--print(temp, parameters.levelPosX, parameters.levelPosY)
		if parameters.locX or parameters.sprite then
			local locX, locY
			if parameters.sprite then
				locX, locY = objects[parameters.sprite].locX, objects[parameters.sprite].locY
				--parameters.sprite = nil
			elseif parameters.locX then
				locX, locY = parameters.locX, parameters.locY
				--parameters.locX = nil
				--parameters.locY = nil
			end
			local levelPos = convert("locToLevelPos", locX, locY, nil, true, true)
			--parameters.levelPosX = levelPos.x + blockScaleX * 0.5
			--parameters.levelPosY = levelPos.y + blockScaleY * 0.5
			para2.levelPosX = levelPos.x + blockScaleX * 0.5
			para2.levelPosY = levelPos.y + blockScaleY * 0.5
		end
		--parameters.levelPosX = parameters.levelPosX * map.layers[i].parallaxX
		--parameters.levelPosY = parameters.levelPosY * map.layers[i].parallaxY
		--temp = "2"
		--parameters.layer = i
		
		para2.levelPosX = para2.levelPosX * map.layers[i].parallaxX
		para2.levelPosY = para2.levelPosY * map.layers[i].parallaxY
		para2.layer = i
		--print(temp, para2.levelPosX, para2.levelPosY)
		--goto(parameters)
		goto(para2)
	end
end

local gotoExt = function(parameters)
	if parameters.blockScaleX then
		blockScaleX = parameters.blockScaleX
	elseif parameters.blockScale then
		blockScaleX = parameters.blockScale
	end
	if parameters.blockScaleY then
		blockScaleY = parameters.blockScaleY
	elseif parameters.blockScale then
		blockScaleY = parameters.blockScale
	end
	if scaleFactorX then
		prevScaleFactorX = scaleFactorX
	end
	if scaleFactorY then
		prevScaleFactorY = scaleFactorY
	end
	scaleFactorX = blockScaleX / worldScaleX
	scaleFactorY = blockScaleY / worldScaleY
	if parameters.levelPosX or parameters.levelPosY then
		--parameters.levelPosX = coordX(parameters.levelPosX) + blockScaleX * 0.5
		--parameters.levelPosY = coordY(parameters.levelPosY) + blockScaleY * 0.5
		parameters.levelPosX = parameters.levelPosX * scaleFactorX + blockScaleX * 0.5
		parameters.levelPosY = parameters.levelPosY * scaleFactorY + blockScaleY * 0.5
	end
	parameters.ext = true
	gotoAll(parameters)
end
M.goto = gotoExt

local loadTileSet = function(index)
	local tempTileWidth = map.tilesets[index].tilewidth + (map.tilesets[index].spacing)
	local tempTileHeight = map.tilesets[index].tileheight + (map.tilesets[index].spacing)
	map.numFrames[index] = (map.tilesets[index].imagewidth / tempTileWidth) * (map.tilesets[index].imageheight / tempTileHeight)
	local options = {width = map.tilesets[index].tilewidth, 
		height = map.tilesets[index].tileheight, 
		numFrames = map.numFrames[index], 
		border = map.tilesets[index].margin,
		sheetContentWidth = map.tilesets[index].imagewidth, 
		sheetContentHeight = map.tilesets[index].imageheight
	}
	local src = nil
	local name = nil
	print(#loadedTileSets)
	for key,value in pairs(loadedTileSets) do
		if key == map.tilesets[index].name then
			src = value[1]
			name = key
		end
	end
	if not src then
		src = map.tilesets[index].image
		tileSets[index] = graphics.newImageSheet(src, options)
		if not tileSets[index] then
			--get tileset name with extension
			local srcString = src
			local length = string.len(srcString)
			local codes = {string.byte("/"), string.byte(".")}
			local slashes = {}
			local periods = {}
			for i = 1, length, 1 do
				local test = string.byte(srcString, i)
				if test == codes[1] then
					slashes[#slashes + 1] = i
				elseif test == codes[2] then
					periods[#periods + 1] = i
				end
			end
		
			local tilesetStringExt
			if #slashes > 0 then
				tilesetStringExt = string.sub(srcString, slashes[#slashes] + 1)
			else
				tilesetStringExt = srcString
			end
		
			print("Searching for tileset "..tilesetStringExt.."...")
		
			--get tileset name
			local tilesetString
			if periods[#periods] >= length - 6 then
				if #slashes > 0 then
					tilesetString = string.sub(srcString, slashes[#slashes] + 1, periods[#periods] - 1)
				else
					tilesetString = string.sub(srcString, 1, periods[#periods] - 1)
				end
			else
				tilesetString = tilesetStringExt
			end
		
			--get map name with extension
			srcString = source
			length = string.len(srcString)
			slashes = {}
			periods = {}
			for i = 1, length, 1 do
				local test = string.byte(srcString, i)
				if test == codes[1] then
					slashes[#slashes + 1] = i
				elseif test == codes[2] then
					periods[#periods + 1] = i
				end
			end
			local mapStringExt = string.sub(srcString, slashes[#slashes] + 1)
		
			--get map name
			local mapString
			if periods[#periods] >= length - 6 then
				mapString = string.sub(srcString, slashes[#slashes] + 1, periods[#periods] - 1)
			else
				mapString = mapStringExt
			end
		
			local success = 0
			local newSource
			--look in base resource directory
			print("Checking Resource Directory...")
			newSource = tilesetStringExt
			tileSets[index] = graphics.newImageSheet(newSource, options)
			if tileSets[index] then
				success = 1
				print("Found "..tilesetStringExt.." in resource directory.")
			end
			--look in folder = map filename with extension
			if success ~= 1 then
				newSource = mapStringExt.."/"..tilesetStringExt
				print("Checking "..mapStringExt.." folder...")
				tileSets[index] = graphics.newImageSheet(newSource, options)
				if tileSets[index] then
					success = 1
					print("Found "..tilesetStringExt.." in "..newSource)
				end
			end
			--look in folder = map filename
			if success ~= 1 then
				newSource = mapString.."/"..tilesetStringExt
				print("Checking "..mapString.." folder...")
				tileSets[index] = graphics.newImageSheet(newSource, options)
				if tileSets[index] then
					success = 1
					print("Found "..tilesetStringExt.." in "..newSource)
				end
			end
			--look in folder = tileset name with extension
			if success ~= 1 then
				newSource = tilesetStringExt.."/"..tilesetStringExt
				print("Checking "..tilesetStringExt.." folder...")
				tileSets[index] = graphics.newImageSheet(newSource, options)
				if tileSets[index] then
					success = 1
					print("Found "..tilesetStringExt.." in "..newSource)
				end
			end
			--look in folder = tileset name
			if success ~= 1 then
				newSource = tilesetString.."/"..tilesetStringExt
				print("Checking "..tilesetString.." folder...")
				tileSets[index] = graphics.newImageSheet(newSource, options)
				if tileSets[index] then
					success = 1
					print("Found "..tilesetStringExt.." in "..newSource)
				end
			end
			if success ~= 1 then
				print("Could not find "..tilesetStringExt)
				print("Use mte.getTilesetNames() and mte.loadTileset(name) to load tilesets programmatically.")
			end
			print(" ")
		end
	else
		tileSets[index] = graphics.newImageSheet(src, options)
		if not tileSets[index] then
			--print("ERROR: Image file "..src.." not found.")
			loadedTileSets[name][2] = "FILE NOT FOUND"
		end
	end
end

local loadTileSetExt = function(name, source)
	loadedTileSets[name] = {source, " "}
	if map.tilesets then
		for i = 1, #map.tilesets, 1 do
			if name == map.tilesets[i].name then
				loadTileSet(i)
			end
		end
	end
end
M.loadTileSet = loadTileSetExt

local getTileSetNames = function(arg)
	local array = {}
	for i = 1, #map.tilesets, 1 do
		array[#array + 1] = map.tilesets[i].name
	end
	return array
end
M.getTileSetNames = getTileSetNames

local detectSpriteLayers = function()
	local layers = {}
	for i = 1, #map.layers, 1 do
		if map.layers[i].properties then
			if map.layers[i].properties.spriteLayer then
				if map.layers[i].properties.spriteLayer == "true" then
					layers[#layers + 1] = i
					spriteLayers[#spriteLayers + 1] = i
				end
			end
		end
	end
	if #layers == 0 then
		print("WARNING(detectSpriteLayers): No Sprite Layers Found. Defaulting to all map layers.")
		for i = 1, #map.layers, 1 do
			layers[#layers + 1] = i
			spriteLayers[#spriteLayers + 1] = i
			map.layers[i].properties.spriteLayer = "true"
		end
	end
	return layers
end
M.detectSpriteLayers = detectSpriteLayers
	
local detectObjectLayers = function()
	local layers = {}
	for i = 1, #map.layers, 1 do
		if map.layers[i].properties.objectLayer then
			layers[#layers + 1] = i
			objectLayers[#objectLayers + 1] = i
		end
	end
	if #layers == 0 then
		print("WARNING(detectObjectLayers): No Object Layers Found.")
		layers = nil
	end
	return layers
end
M.detectObjectLayers = detectObjectLayers

M.loadMap = function(src, dir)
	for key,value in pairs(objects) do
		removeSprite(key)
	end
	tileSets = {}
	map = {}
	worldSizeX = nil
	worldSizeY = nil
	layerWidth = {}
	layerHeight = {}
	imageDirectory = ""
	displayGroups = {}
	masterGroup = display.newGroup()
	spriteLayers = {}
	syncData = {}
	animatedTiles = {}
	refLayer = nil
	
	local srcString = src
	local length = string.len(srcString)
	local codes = {string.byte("/"), string.byte(".")}
	local slashes = {}
	local periods = {}
	for i = 1, length, 1 do
		local test = string.byte(srcString, i)
		if test == codes[1] then
			slashes[#slashes + 1] = i
		elseif test == codes[2] then
			periods[#periods + 1] = i
		end
	end
	if #slashes > 0 then
		srcStringExt = string.sub(srcString, slashes[#slashes] + 1)
	else
		srcStringExt = srcString
	end
	if #periods > 0 then
		if periods[#periods] >= length - 6 then
			srcString = string.sub(srcString, slashes[#slashes] + 1, periods[#periods] - 1)
		else
			srcString = srcStringExt
		end
	else
		srcString = srcStringExt
	end
	local detectJsonExt = string.find(srcStringExt, ".json")
	if string.len(srcStringExt) ~= string.len(srcString) then
		if not detectJsonExt then
			print("ERROR: "..src.." is not a Json file.")
		end
	else
		src = src..".json"
	end
		
	local path
	if dir == "Documents" then
		source = src
		debugText = "Directory = DocumentsDirectory"
		path = system.pathForFile(src, system.DocumentsDirectory)
		debugText = "Path to file = "..path
	elseif dir == "Temporary" then
		source = src
		debugText = "Directory = TemporaryDirectory"
		path = system.pathForFile(src, system.TemporaryDirectory)
		debugText = "Path to file = "..path
	elseif not dir or dir == "Resource" then
		source = src
		debugText = "Directory = ResourceDirectory"
		path = system.pathForFile(src, system.ResourceDirectory)
		debugText = "Path to file = "..path	
	end
	local saveData = io.open(path, "r")
	debugText = "saveData stream opened"
	if saveData then
		local jsonData = saveData:read("*a")
		debugText = "jsonData read"
		map = json.decode(jsonData)
		debugText = "jsonData decoded"
		io.close(saveData)
		debugText = "io stream closed"
		print(src.." loaded")
		debugText = src.." loaded"
	else
		print("ERROR: Map Not Found")
		debugText = "ERROR: Map Not Found"
	end
		
	--LAYERS
	worldSizeX = map.width --map.layers[1].width
	worldSizeY = map.height --map.layers[1].height
	print("World Size X: "..worldSizeX)
	print("World Size Y: "..worldSizeY)
	map.numLevels = 1
	
	if map.properties.wrap then
		if map.properties.wrap == "true" then
			worldWrapX = true
			worldWrapY = true
		elseif map.properties.wrap == "false" then
			worldWrapX = false
			worldWrapY = false
		end
	end
	if map.properties.wrapX then
		if map.properties.wrapX == "true" then
			worldWrapX = true
		elseif map.properties.wrapX == "false" then
			worldWrapX = false
		end
	end
	if map.properties.wrapY then
		if map.properties.wrapY == "true" then
			worldWrapY = true
		elseif map.properties.wrapY == "false" then
			worldWrapY = false
		end
	end

	
	local prevLevel = "1"
	for i = 1, #map.layers, 1 do
		--CHECK AND LOAD SCALE AND LEVELS
		if not map.layers[i].properties then
			map.layers[i].properties = {}
			map.layers[i].properties.level = "1"
			map.layers[i].properties.scaleX = 1
			map.layers[i].properties.scaleY = 1
			map.layers[i].properties.parallaxX = 1
			map.layers[i].properties.parallaxY = 1
		else
			if not map.layers[i].properties.level then
				map.layers[i].properties.level = "1"
			end
			if map.layers[i].properties.scale then
				map.layers[i].properties.scaleX = map.layers[i].properties.scale
				map.layers[i].properties.scaleY = map.layers[i].properties.scale
			else
				if not map.layers[i].properties.scaleX then
					map.layers[i].properties.scaleX = 1
				end
				if not map.layers[i].properties.scaleY then
					map.layers[i].properties.scaleY = 1
				end
			end
		end
		if map.layers[i].properties.parallax then
			map.layers[i].parallaxX = map.layers[i].properties.parallax / map.layers[i].properties.scaleX
			map.layers[i].parallaxY = map.layers[i].properties.parallax / map.layers[i].properties.scaleY
		else
			if map.layers[i].properties.parallaxX then
				map.layers[i].parallaxX = map.layers[i].properties.parallaxX / map.layers[i].properties.scaleX
			else
				map.layers[i].parallaxX = 1
			end
			if map.layers[i].properties.parallaxY then
				map.layers[i].parallaxY = map.layers[i].properties.parallaxY / map.layers[i].properties.scaleY
			else
				map.layers[i].parallaxY = 1
			end
		end
		
		--DETECT WIDTH AND HEIGHT
		if map.layers[i].properties.width then
			map.layers[i].width = tonumber(map.layers[i].properties.width)
		end
		if map.layers[i].properties.height then
			map.layers[i].height = tonumber(map.layers[i].properties.height)
		end
		layerWidth[i] = map.layers[i].width
		layerHeight[i] = map.layers[i].height
		
		--DETECT LAYER WRAP
		layerWrapX[i] = worldWrapX
		layerWrapY[i] = worldWrapY
		if map.layers[i].properties.wrap then
			if map.layers[i].properties.wrap == "true" then
				layerWrapX[i] = true
				layerWrapY[i] = true
			elseif map.layers[i].properties.wrap == "false" then
				layerWrapX[i] = false
				layerWrapY[i] = false
			end
		end
		if map.layers[i].properties.wrapX then
			if map.layers[i].properties.wrapX == "true" then
				layerWrapX[i] = true
			elseif map.layers[i].properties.wrapX == "false" then
				layerWrapX[i] = false
			end
		end
		if map.layers[i].properties.wrapY then
			if map.layers[i].properties.wrapY == "true" then
				layerWrapY[i] = true
			elseif map.layers[i].properties.wrapY == "false" then
				layerWrapY[i] = false
			end
		end

		--TOGGLE PARALLAX CROP
		if map.layers[i].properties.toggleParallaxCrop == "true" then
			map.layers[i].width = math.floor(map.layers[i].width * map.layers[i].parallaxX)
			map.layers[i].height = math.floor(map.layers[i].height * map.layers[i].parallaxY)
			if map.layers[i].width <= map.width then
				layerWidth[i] = map.layers[i].width
			else
				map.layers[i].width = map.width
				layerWidth[i] = map.width
			end
			if map.layers[i].height <= map.height then
				layerHeight[i] = map.layers[i].height
			else
				map.layers[i].height = map.height
				layerHeight[i] = map.height
			end
		end
		
		--FIT BY PARALLAX / FIT BY SCALE
		if map.layers[i].properties.fitByParallax then
			map.layers[i].parallaxX = map.layers[i].width / worldSizeX
			map.layers[i].parallaxY = map.layers[i].height / worldSizeY
		else
			if map.layers[i].properties.fitByScale then
				map.layers[i].properties.scaleX = (worldSizeX * map.layers[i].properties.parallaxX) / layerWidth[i]
				map.layers[i].properties.scaleY = (worldSizeY * map.layers[i].properties.parallaxY) / layerHeight[i]
			end
		end
		
		if map.layers[i].parallaxX == 1 and map.layers[i].parallaxY == 1 then
			if not refLayer then
				refLayer = tonumber(i)
			end
		end
		
		--LOAD WORLD ARRAYS
		if not map.modified then
			map.layers[i].world = {}
			for x = 1, layerWidth[i], 1 do
				map.layers[i].world[x] = {}
				local lx = x
				while lx > worldSizeX do
					lx = lx - worldSizeX
				end
				for y = 1, layerHeight[i], 1 do
					local ly = y
					while ly > worldSizeY do
						ly = ly - worldSizeY
					end
					if map.layers[i].data then
						map.layers[i].world[x][y] = map.layers[i].data[(worldSizeX * (ly - 1)) + lx]
						--[[
						if y == layerHeight[i] then
							break
						end
						]]--
					else
						map.layers[i].world[x][y] = 0
					end
				end
				--[[
				if x == layerWidth[i] then
					break
				end
				]]--
			end 
		end

		--[[
		if not map.modified then
			map.layers[i].world = {}
			for x = 1, worldSizeX, 1 do
				map.layers[i].world[x] = {}
				for y = 1, worldSizeY, 1 do
					if map.layers[i].data then
						map.layers[i].world[x][y] = map.layers[i].data[(worldSizeX * (y - 1)) + x]
						if y == map.layers[i].height then
							break
						end
					else
						map.layers[i].world[x][y] = 0
					end
				end
				if x == map.layers[i].width then
					break
				end
			end 
		end
		]]--
		if not map.modified then
			if not map.layers[i].data then
				map.layers[i].properties.objectLayer = true
			end
		end
		--DELETE IMPORTED TILEMAP FROM MEMORY
		if not map.modified then
			map.layers[i].data = nil
		end
		if map.layers[i].properties.level ~= prevLevel then
			prevLevel = map.layers[i].properties.level
			map.numLevels = map.numLevels + 1
		end
		map.layers[i].properties.level = tonumber(map.layers[i].properties.level)
	end
	if not refLayer then
		refLayer = 1
	end
	print("Levels: "..map.numLevels)
	print("Reference Layer: "..refLayer)
	
	--DISPLAYGROUPS
	for i = 1, #map.layers, 1 do
		displayGroups[i] = display.newGroup()
		displayGroups[i].sX = displayGroups[i].x
		displayGroups[i].sY = displayGroups[i].y
		displayGroups[i].xReference = display.viewableContentWidth * 0.5
		displayGroups[i].yReference = display.viewableContentHeight * 0.5
		masterGroup:insert(displayGroups[i])
		masterGroup.xReference = display.viewableContentWidth * 0.5
		masterGroup.yReference = display.viewableContentHeight * 0.5
	end
	
	--LIGHTING
	if map.properties then
		if map.properties.lightingStyle then
			local levelLighting = {}
			for i = 1, map.numLevels, 1 do
				levelLighting[i] = {}
			end
			if not map.properties.lightRedStart then
				map.properties.lightRedStart = "255"
			end
			if not map.properties.lightGreenStart then
				map.properties.lightGreenStart = "255"
			end
			if not map.properties.lightBlueStart then
				map.properties.lightBlueStart = "255"
			end
			if map.properties.lightingStyle == "diminish" then
				local rate = tonumber(map.properties.lightRate)
				levelLighting[map.numLevels].red = tonumber(map.properties.lightRedStart)
				levelLighting[map.numLevels].green = tonumber(map.properties.lightGreenStart)
				levelLighting[map.numLevels].blue = tonumber(map.properties.lightBlueStart)
				for i = map.numLevels - 1, 1, -1 do
					levelLighting[i].red = levelLighting[map.numLevels].red - (rate * (map.numLevels - i))
					if levelLighting[i].red < 0 then
						levelLighting[i].red = 0
					end
					levelLighting[i].green = levelLighting[map.numLevels].green - (rate * (map.numLevels - i))
					if levelLighting[i].green < 0 then
						levelLighting[i].green = 0
					end
					levelLighting[i].blue = levelLighting[map.numLevels].blue - (rate * (map.numLevels - i))
					if levelLighting[i].blue < 0 then
						levelLighting[i].blue = 0
					end
				end
			end
			for i = 1, #map.layers, 1 do
				if map.layers[i].properties.lightRed then
					map.layers[i].redLight = tonumber(map.layers[i].properties.lightRed)
				else
					map.layers[i].redLight = levelLighting[map.layers[i].properties.level].red
				end
				if map.layers[i].properties.lightGreen then
					map.layers[i].greenLight = tonumber(map.layers[i].properties.lightGreen)
				else
					map.layers[i].greenLight = levelLighting[map.layers[i].properties.level].green
				end
				if map.layers[i].properties.lightBlue then
					map.layers[i].blueLight = tonumber(map.layers[i].properties.lightBlue)
				else
					map.layers[i].blueLight = levelLighting[map.layers[i].properties.level].blue
				end
			end
		else
			for i = 1, #map.layers, 1 do
				if map.layers[i].properties.lightRed then
					map.layers[i].redLight = tonumber(map.layers[i].properties.lightRed)
				else
					map.layers[i].redLight = 255
				end
				if map.layers[i].properties.lightGreen then
					map.layers[i].greenLight = tonumber(map.layers[i].properties.lightGreen)
				else
					map.layers[i].greenLight = 255
				end
				if map.layers[i].properties.lightBlue then
					map.layers[i].blueLight = tonumber(map.layers[i].properties.lightBlue)
				else
					map.layers[i].blueLight = 255
				end
			end
		end
	end
	
	--TILESETS
	map.numFrames = {}
	for i = 1, #map.tilesets, 1 do
		loadTileSet(i)
		
		--PROCESS ANIMATION DATA
		if map.tilesets[i].tileproperties then
			for key,value in pairs(map.tilesets[i].tileproperties) do
				for key2,value2 in pairs(map.tilesets[i].tileproperties[key]) do
					if key2 == "animFrames" then
						map.tilesets[i].tileproperties[key]["animFrames"] = json.decode(value2)
						local tempFrames = json.decode(value2)
						local tempFrames2 = {}
						if map.tilesets[i].tileproperties[key]["animFrameSelect"] == "relative" then
							--print("1:")
							local frames = {}
							for f = 1, #tempFrames, 1 do
								frames[f] = (tonumber(key) + 1) + tempFrames[f]
								tempFrames2[f] = (tonumber(key) + 1) + tempFrames[f]
							end
							map.tilesets[i].tileproperties[key]["sequenceData"] = {
								name="null",
								frames=frames,
								time = tonumber(map.tilesets[i].tileproperties[key]["animDelay"]),
								loopCount = 0
							}
						elseif map.tilesets[i].tileproperties[key]["animFrameSelect"] == "absolute" then
							map.tilesets[i].tileproperties[key]["sequenceData"] = {
								name="null",
								frames=tempFrames,
								time = tonumber(map.tilesets[i].tileproperties[key]["animDelay"]),
								loopCount = 0
							}
						end
						map.tilesets[i].tileproperties[key]["animSync"] = tonumber(map.tilesets[i].tileproperties[key]["animSync"]) or 1
						local tileID = tonumber(key) + 1
						syncData[tileID] = {}
						syncData[tileID] = {}
						syncData[tileID].time = (map.tilesets[i].tileproperties[key]["sequenceData"].time / #map.tilesets[i].tileproperties[key]["sequenceData"].frames) / frameTime
						syncData[tileID].currentFrame = 1
						syncData[tileID].counter = syncData[tileID].time
						syncData[tileID].frames = map.tilesets[i].tileproperties[key]["sequenceData"].frames
						if map.tilesets[i].tileproperties[key]["animFrameSelect"] == "relative" then
							syncData[tileID].trueFrames = tempFrames2
						elseif map.tilesets[i].tileproperties[key]["animFrameSelect"] == "absolute" then
							syncData[tileID].trueFrames = tempFrames
						end
						--[[
						if not syncData[map.tilesets[i].tileproperties[key]["animSync"] ] then
							syncData[map.tilesets[i].tileproperties[key]["animSync"] ] = {}
							syncData[map.tilesets[i].tileproperties[key]["animSync"] ].time = (map.tilesets[i].tileproperties[key]["sequenceData"].time / #map.tilesets[i].tileproperties[key]["sequenceData"].frames) / frameTime
							syncData[map.tilesets[i].tileproperties[key]["animSync"] ].currentFrame = 1
							syncData[map.tilesets[i].tileproperties[key]["animSync"] ].counter = syncData[map.tilesets[i].tileproperties[key]["animSync"] ].time
							syncData[map.tilesets[i].tileproperties[key]["animSync"] ].frames = map.tilesets[i].tileproperties[key]["sequenceData"].frames
							if map.tilesets[i].tileproperties[key]["animFrameSelect"] == "relative" then
								syncData[map.tilesets[i].tileproperties[key]["animSync"] ].trueFrames = tempFrames2
							elseif map.tilesets[i].tileproperties[key]["animFrameSelect"] == "absolute" then
								syncData[map.tilesets[i].tileproperties[key]["animSync"] ].trueFrames = tempFrames
							end
						end
						]]--
					end
				end
			end
		end
	end
	worldScaleX = map.tilesets[1].tilewidth
	worldScaleY = map.tilesets[1].tileheight
	M.worldScaleX = worldScaleX
	M.worldScaleY = worldScaleY
	
	map.modified = 1
	
	detectSpriteLayers()
	detectObjectLayers()
	M.map = map
	M.displayGroups = displayGroups
	M.masterGroup = masterGroup
	M.worldSizeX = worldSizeX
	M.worldSizeY = worldSizeY
	return masterGroup
end
--M.loadMap = loadMap

M.changeSpriteLayer = function(object, layer)
	local object = objects[object]
	object.layer = layer
	object.level = getLevel(layer)
	object.xScale = (object.levelWidth * scaleFactorX / object.sourceWidth) * map.layers[layer].properties.scaleX
	object.yScale = (object.levelHeight * scaleFactorY / object.sourceHeight) * map.layers[layer].properties.scaleY
	local screenPos = convert("levelPosToScreenPos", object.levelPosX, object.levelPosY, object.layer)
	object.sX = screenPos.x + object.offsetX * scaleFactorX * map.layers[layer].properties.scaleX
	object.sY = screenPos.y + object.offsetY * scaleFactorY * map.layers[layer].properties.scaleY
	object:setFillColor(map.layers[layer].redLight, 
									map.layers[layer].greenLight, 
									map.layers[layer].blueLight)
	displayGroups[layer]:insert(object)
end
--M.changeSpriteLayer = changeSpriteLayer

M.setCameraFocus = function(object)
	cameraFocus = object
end
--M.setCameraFocus = setCameraFocus

local frameLength = display.fps
local easingHelper = function(distance, frames, kind)
	local move = {}
	local total = 0
	if not kind then
		kind = "linear"
	end
	
	for i = 1, frames, 1 do
		if kind == "inExpo" then
			move[i] = easing.inExpo((i - 1) * frameLength, frameLength * frames, 0, 1000)
		elseif kind == "inOutExpo" then
			move[i] = easing.inOutExpo((i - 1) * frameLength, frameLength * frames, 0, 1000)
		elseif kind == "inOutQuad" then
			move[i] = easing.inOutQuad((i - 1) * frameLength, frameLength * frames, 0, 1000)
		elseif kind == "inQuad" then
			move[i] = easing.inQuad((i - 1) * frameLength, frameLength * frames, 0, 1000)
		elseif kind == "linear" then
			move[i] = easing.linear((i - 1) * frameLength, frameLength * frames, 0, 1000)
		elseif kind == "outExpo" then
			move[i] = easing.outExpo((i - 1) * frameLength, frameLength * frames, 0, 1000)
		elseif kind == "outQuad" then
			move[i] = easing.outQuad((i - 1) * frameLength, frameLength * frames, 0, 1000)
		end
	end
	
	local move2 = {}
	local total2 = 0
	for i = 1, frames, 1 do
		if i < frames then
			move2[i] = move[i + 1] - move[i]
		else
			move2[i] = 1000 - move[i]
		end
		total2 = total2 + move2[i]
	end
	local mod2 = distance / total2
	for i = 1, frames, 1 do
		move2[i] = move2[i] * mod2
	end
	
	return move2
end

local isMoving = {}
local count = 0
moveCameraProc = function(layer, velX, velY)
	local i = layer
	isMoving[i] = true

	local cameraVelX = velX
	local cameraVelY = velY
	cameraX[i] = cameraX[i] + cameraVelX
	cameraY[i] = cameraY[i] + cameraVelY

	prevLocX[i] = cameraLocX[i]
	prevLocY[i] = cameraLocY[i]

	cameraLocX[i] = floor(cameraX[i] / blockScaleX)
	cameraLocY[i] = floor(cameraY[i] / blockScaleY)

	local scaleX = map.layers[i].properties.scaleX
	local scaleY = map.layers[i].properties.scaleY
	
	local tempVelX = cameraVelX * -1 * scaleX
	local tempVelY = cameraVelY * -1 * scaleY
	
	displayGroups[i].sX = displayGroups[i].sX - tempVelX
	displayGroups[i].sY = displayGroups[i].sY - tempVelY
	displayGroups[i]:translate(tempVelX, tempVelY)

	anchorX[i] = anchorX[i] + tempVelX
	anchorY[i] = anchorY[i] + tempVelY
	
	shiftHorizontal = "no"
	shiftVertical = "no"

	if prevLocY[i] == layerHeight[i] and cameraLocY[i] == 0 then
		prevLocY[i] = 0
	end
	if prevLocY[i] ~= cameraLocY[i] then
		if prevLocY[i] == 0 and cameraLocY[i] == layerHeight[i] - 1 then
			shiftVertical = "up"
			tempLocY[i] = cameraLocY[i]
		elseif prevLocY[i] == layerHeight[i] - 1 and cameraLocY[i] == 0 then
			shiftVertical = "down"
			tempLocY[i] = cameraLocY[i]
		else
			if prevLocY[i] > cameraLocY[i] then
				shiftVertical = "up"
				tempLocY[i] = cameraLocY[i]
			elseif prevLocY[i] < cameraLocY[i] then
				shiftVertical = "down"
				tempLocY[i] = cameraLocY[i]
			end
		end
	end
	
	if prevLocX[i] == layerWidth[i] and cameraLocX[i] == 0 then
		prevLocX[i] = 0
	end
	if prevLocX[i] ~= cameraLocX[i] then
		if prevLocX[i] == 0 and cameraLocX[i] == layerWidth[i] - 1 then
			shiftHorizontal = "left"
			tempLocX[i] = cameraLocX[i]
		elseif prevLocX[i] == layerWidth[i] - 1 and cameraLocX[i] == 0 then
			shiftHorizontal = "right"
			tempLocX[i] = cameraLocX[i]
		else
			if prevLocX[i] > cameraLocX[i] then
				shiftHorizontal = "left"
				tempLocX[i] = cameraLocX[i]
			elseif prevLocX[i] < cameraLocX[i] then
				shiftHorizontal = "right"
				tempLocX[i] = cameraLocX[i]
			end
		end
	end
	
	local value = 0
	if shiftHorizontal ~= "no" or shiftVertical ~= "no" then
		value = 1
	end
	
	return value
end

moveCamera = function(velX, velY)
	for i = 1, #map.layers, 1 do
		moveCameraProc(i, velX * map.layers[i].parallaxX, velY * map.layers[i].parallaxY)
	end
end

local moveSprite = function(object, x, y)
	local object = objects[object]
	object.levelPosX = object.levelPosX + x
	object.levelPosY = object.levelPosY + y
	if cameraFocus == object then
		moveCamera(x, y)
	end
end

local spritesFrozen = false
local cameraFrozen = false
local tileAnimsFrozen = false
M.update = function()
	for i = 1, #map.layers, 1 do
		isMoving[i] = false
	end
	
	if not spriteFrozen then
		--UPDATE SPRITES
		for key,value in pairs(movingSprites) do
			if key and objects and objects[key].isMoving then
				local object = objects[key]
				local velX = object.deltaX[1]
				local velY = object.deltaY[1]
				local remainingVelX = abs(object.deltaX[1])
				local remainingVelY = abs(object.deltaY[1])
				local velXSign = 1
				local velYSign = 1
				if velX < 0 then
					velXSign = -1
				else
					velXSign = 1
				end
				if velY < 0 then
					velYSign = -1
				else
					velYSign = 1
				end
				while remainingVelX > 0 or remainingVelY > 0 do
					local vX
					local vY
					if remainingVelX > blockScaleX / 5 then
						vX = blockScaleX / 5
						remainingVelX = remainingVelX - blockScaleX / 5
					else
						vX = remainingVelX
						remainingVelX = 0
					end
					if remainingVelY > blockScaleY / 5 then
						vY = blockScaleY / 5
						remainingVelY = remainingVelY - blockScaleY / 5
					else
						vY = remainingVelY
						remainingVelY = 0
					end
					moveSprite(key, vX * velXSign, vY * velYSign)
				end
				table.remove(object.deltaX, 1)
				table.remove(object.deltaY, 1)
				if not object.deltaX[1] then
					object.isMoving = false
					--local location = convert("levelPosToLoc", object.levelPosX, object.levelPosY, object.layer)
					
					----------------------------------------------------------------------
					local layer = object.layer
					local tempX = ceil(math.round(object.levelPosX) / blockScaleX)
					if not noWrapX then
						if tempX > layerWidth[layer] then
							while tempX > layerWidth[layer] do
								tempX = tempX - layerWidth[layer]
							end
						elseif tempX < 1 then
							while tempX < 1 do
								tempX = tempX + layerWidth[layer]
							end
						end
					end
					local tempY = ceil(math.round(object.levelPosY) / blockScaleY)
					if not noWrapY then
						if tempY > layerHeight[layer] then
							while tempY > layerHeight[layer] do
								tempY = tempY - layerHeight[layer]
							end
						elseif tempY < 1 then
							while tempY < 1 do
								tempY = tempY + layerHeight[layer]
							end
						end
					end
					object.locX, object.locY = tempX, tempY
					----------------------------------------------------------------------
					
					--object.locX = location.x
					--object.locY = location.y
					
					--[[
					if not object.isMoving2 then
						movingSprites[key] = nil
					end
					]]--
				end
			end
			--[[
			if objects[key].isMoving2 then
				moveSprite(key, objects[key].velX, objects[key].velY)
			end
			]]--
		end
	end

	if not cameraFrozen then
		if isCameraMoving then
			local velX = deltaX[1]
			local velY = deltaY[1]
			local remainingVelX = abs(deltaX[1])
			local remainingVelY = abs(deltaY[1])
			local velXSign = 1
			local velYSign = 1
			if velX < 0 then
				velXSign = -1
			else
				velXSign = 1
			end
			if velY < 0 then
				velYSign = -1
			else
				velYSign = 1
			end
			while remainingVelX > 0 or remainingVelY > 0 do
				local vX
				local vY
				if remainingVelX > blockScaleX / 5 then
					vX = blockScaleX / 5
					remainingVelX = remainingVelX - blockScaleX / 5
				else
					vX = remainingVelX
					remainingVelX = 0
				end
				if remainingVelY > blockScaleY / 5 then
					vY = blockScaleY / 5
					remainingVelY = remainingVelY - blockScaleY / 5
				else
					vY = remainingVelY
					remainingVelY = 0
				end
				moveCamera(vX * velXSign, vY * velYSign)
			end
			table.remove(deltaX, 1)
			table.remove(deltaY, 1)
			if not deltaX[1] then
				isCameraMoving = false
			end
		end
	end
	
	if not tileAnimsFrozen then
		for key,value in pairs(syncData) do
			syncData[key].counter = syncData[key].counter - 1
			if syncData[key].counter <= 0 then
				syncData[key].counter = syncData[key].time
				syncData[key].currentFrame = syncData[key].currentFrame + 1
				if syncData[key].currentFrame > #syncData[key].frames then
					syncData[key].currentFrame = 1
				end
			end
			--print(key, syncData[key].trueFrames[syncData[key].currentFrame] )
		end
	end
	
	numObjects = 0
	for key,value in pairs(objects) do
		--Update Sprite Positions
		numObjects = numObjects + 1
		local object = objects[key]
		local tempPosX = object.levelPosX
		local tempPosY = object.levelPosY
		local i = object.layer
		if worldWrapX then
			if cameraX[i] < tempPosX then
				local distXAcross = tempPosX - cameraX[i]
				if distXAcross > (layerWidth[i] - 1) * blockScaleX * 0.5 then
					tempPosX = tempPosX - (layerWidth[i] * blockScaleX)
				end
			elseif cameraX[i] > tempPosX then
				local distXAcross = cameraX[i] - tempPosX
				if distXAcross > (layerWidth[i] - 1) * blockScaleX * 0.5 then
					tempPosX = tempPosX + (layerWidth[i] * blockScaleX)
				end
			end
		end
		if worldWrapY then
			if cameraY[i] < tempPosY then
				local distYAcross = tempPosY - cameraY[i]
				if distYAcross > layerHeight[i] * blockScaleY * 0.5 then
					tempPosY = tempPosY - (layerHeight[i] * blockScaleY)
				end
			elseif cameraY[i] > tempPosY then
				local distYAcross = cameraY[i] - tempPosY
				if distYAcross > layerHeight[i] * blockScaleY * 0.5 then
					tempPosY = tempPosY + (layerHeight[i] * blockScaleY)
				end
			end
		end
		
		--local screenPos = convert("levelPosToScreenPos", tempPosX, tempPosY, object.layer)
		----------------------------------------------------------------------------------
		local layer = object.layer
		local tempScaleX = blockScaleX * map.layers[layer].properties.scaleX
		local tempScaleY = blockScaleY * map.layers[layer].properties.scaleY
		
		local tempX1 = tempPosX / blockScaleX
		local tempX = ((((floor(tempPosX / blockScaleX) + 1) - rect1LocX[layer]) * tempScaleX) + anchorX[layer]) + ((((tempX1 - floor(tempX1)) * tempScaleX) - (tempScaleX * 0.5)))

		local tempY1 = tempPosY / blockScaleY
		local tempY = ((((floor(tempPosY / blockScaleY) + 1) - rect1LocY[layer]) * tempScaleY) + anchorY[layer]) + ((((tempY1 - floor(tempY1)) * tempScaleY) - (tempScaleY * 0.5)))
		
		local screenPos = {x = tempX, y = tempY}
		----------------------------------------------------------------------------------
		
		local modX = scaleFactorX * map.layers[object.layer].properties.scaleX
		local modY = scaleFactorY * map.layers[object.layer].properties.scaleY

		screenPos.x = screenPos.x + (object.offsetX * modX)
		screenPos.y = screenPos.y + (object.offsetY * modY)

		if object.sX + object.levelWidth * modX > 0 and 
		object.sX - object.levelWidth * modX < displayWidth then
			if object.sY + object.levelHeight * modY > 0 and
			object.sY - object.levelHeight * modY < displayHeight then
				--if object is currently onscreen
				object.sX = screenPos.x
				object.sY = screenPos.y
			end
		end
		if screenPos.x + object.levelWidth * modX > 0 and 
		screenPos.x - object.levelWidth * modX < displayWidth then
			if screenPos.y + object.levelHeight * modY > 0 and
			screenPos.y - object.levelHeight * modY < displayHeight then
				--if object should be onscreen
				object.sX = screenPos.x
				object.sY = screenPos.y
			end
		end
		
		object.x = object.sX + displayGroups[object.layer].sX
		object.y = object.sY + displayGroups[object.layer].sY
		
		object:setFillColor(map.layers[object.layer].redLight, map.layers[object.layer].greenLight, map.layers[object.layer].blueLight)
	end
	
	for key,value in pairs(animatedTiles) do
		if syncData[animatedTiles[key].sync] then
			animatedTiles[key]:setFrame(syncData[animatedTiles[key].sync].currentFrame)
		end
	end
	
	for i = 1, #map.layers, 1 do
		if displayGroups[i].deltaFade then
			displayGroups[i].tempAlpha = displayGroups[i].tempAlpha - displayGroups[i].deltaFade[1]
			if displayGroups[i].tempAlpha > 1 then
				displayGroups[i].tempAlpha = 1
			end
			if displayGroups[i].tempAlpha < 0 then
				displayGroups[i].tempAlpha = 0
			end
			displayGroups[i].alpha = displayGroups[i].tempAlpha
			table.remove(displayGroups[i].deltaFade, 1)
			if not displayGroups[i].deltaFade[1] then
				displayGroups[i].deltaFade = nil
				displayGroups[i].tempAlpha = nil
			end
		end
		if displayGroups[i].deltaTint then
			local layer = displayGroups[i]
			map.layers[i].redLight = map.layers[i].redLight - layer.deltaTint[1][1]
			map.layers[i].greenLight = map.layers[i].greenLight - layer.deltaTint[2][1]
			map.layers[i].blueLight = map.layers[i].blueLight - layer.deltaTint[3][1]
			for x = 1, rectsWidth[i], 1 do
				for y = 1, rectsHeight[i], 1 do
					if rects[i][x][y] ~= 9999 then
						rects[i][x][y]:setFillColor(map.layers[i].redLight, map.layers[i].greenLight, map.layers[i].blueLight)
						if not rects[i][x][y].currentColor then
							rects[i][x][y].currentColor = {map.layers[i].redLight, 
								map.layers[i].greenLight, 
								map.layers[i].blueLight
							}
						end
					end
				end
			end
			table.remove(layer.deltaTint[1], 1)
			table.remove(layer.deltaTint[2], 1)
			table.remove(layer.deltaTint[3], 1)
			if not layer.deltaTint[1][1] then
				layer.deltaTint = nil
			end
		end
		if displayGroups[i].alpha <= 0 and displayGroups[i].isVisible then
			displayGroups[i].isVisible = false
		elseif displayGroups[i].alpha > 0 and not displayGroups[i].isVisible then
			displayGroups[i].isVisible = true
		end
	end
	
	for key,value in pairs(fadingTiles) do
		local tile = fadingTiles[key]
		tile.tempAlpha = tile.tempAlpha - tile.deltaFade[1]
		if tile.tempAlpha > 1 then
			tile.tempAlpha = 1
		end
		if tile.tempAlpha < 0 then
			tile.tempAlpha = 0
		end
		tile.alpha = tile.tempAlpha
		table.remove(tile.deltaFade, 1)
		if not tile.deltaFade[1] then
			tile.deltaFade = nil
			tile.tempAlpha = nil
			fadingTiles[tile] = nil
		end
	end
	
	for key,value in pairs(tintingTiles) do
		local tile = tintingTiles[key]
		tile.currentColor[1] = tile.currentColor[1] - tile.deltaTint[1][1]
		tile.currentColor[2] = tile.currentColor[2] - tile.deltaTint[2][1]
		tile.currentColor[3] = tile.currentColor[3] - tile.deltaTint[3][1]
		for i = 1, 3, 1 do
			if tile.currentColor[i] > 255 then
				tile.currentColor[i] = 255
			end
			if tile.currentColor[i] < 0 then
				tile.currentColor[i] = 0
			end
		end
		tile:setFillColor(tile.currentColor[1], tile.currentColor[2], tile.currentColor[3])
		table.remove(tile.deltaTint[1], 1)
		table.remove(tile.deltaTint[2], 1)
		table.remove(tile.deltaTint[3], 1)
		if not tile.deltaTint[1][1] then
			tile.deltaTint = nil
			tintingTiles[tile] = nil
		end
	end
	
	if deltaZoom then
		currentScale = currentScale - deltaZoom[1]
		masterGroup.xScale = currentScale
		masterGroup.yScale = currentScale
		table.remove(deltaZoom, 1)
		if not deltaZoom[1] then
			deltaZoom = nil
		end
	end
	--collectgarbage("step", 30)
end
--M.update = update

local sendSpriteTo = function(parameters)
	local object = objects[parameters.sprite]
	if parameters.locX then
		object.locX = parameters.locX
		object.locY = parameters.locY
		local levelPos = convert("locToLevelPos", parameters.locX, parameters.locY, nil, true, true)
		object.levelPosX = levelPos.x
		object.levelPosY = levelPos.y
		local screenPos = convert("locToScreenPos", parameters.locX, parameters.locY, object.layer, true, true)
		object.sX = screenPos.x
		object.sY = screenPos.y
		object.sX = object.sX + (object.offsetX * scaleFactorX * map.layers[object.layer].properties.scaleX)
		object.sY = object.sY + (object.offsetY * scaleFactorY * map.layers[object.layer].properties.scaleY)
	elseif parameters.levelPosX then
		object.levelPosX = parameters.levelPosX
		object.levelPosY = parameters.levelPosY
		local loc = convert("levelPosToLoc", parameters.levelPosX, parameters.levelPosY, nil, true, true)
		object.locX = loc.x
		object.locY = loc.y
		local screenPos = convert("locToScreenPos", object.locX, object.locY, object.layer, true, true)
		object.sX = screenPos.x
		object.sY = screenPos.y
		object.sX = object.sX + (object.offsetX * scaleFactorX * map.layers[object.layer].properties.scaleX)
		object.sY = object.sY + (object.offsetY * scaleFactorY * map.layers[object.layer].properties.scaleY)
	end
end

local sendSpriteToExt = function(parameters)
	local object = objects[parameters.sprite]
	if parameters.locX then
		object.locX = parameters.locX
		object.locY = parameters.locY
		local levelPos = convert("locToLevelPos", parameters.locX, parameters.locY, nil, true, true)
		object.levelPosX = levelPos.x
		object.levelPosY = levelPos.y
		local screenPos = convert("locToScreenPos", parameters.locX, parameters.locY, object.layer, true, true)
		object.sX = screenPos.x
		object.sY = screenPos.y
		object.sX = object.sX + (object.offsetX * scaleFactorX * map.layers[object.layer].properties.scaleX)
		object.sY = object.sY + (object.offsetY * scaleFactorY * map.layers[object.layer].properties.scaleY)
	elseif parameters.levelPosX then
		object.levelPosX = parameters.levelPosX * scaleFactorX --coordX(parameters.levelPosX) -- + blockScaleX * 0.5
		object.levelPosY = parameters.levelPosY * scaleFactorY --coordY(parameters.levelPosY) -- + blockScaleY * 0.5
		parameters.levelPosX = object.levelPosX
		parameters.levelPosY = object.levelPosY
		local loc = convert("levelPosToLoc", parameters.levelPosX, parameters.levelPosY, nil, true, true)
		object.locX = loc.x
		object.locY = loc.y
		local screenPos = convert("locToScreenPos", object.locX, object.locY, object.layer, true, true)
		object.sX = screenPos.x
		object.sY = screenPos.y
		object.sX = object.sX + (object.offsetX * scaleFactorX * map.layers[object.layer].properties.scaleX)
		object.sY = object.sY + (object.offsetY * scaleFactorY * map.layers[object.layer].properties.scaleY)
	end
end
M.sendSpriteTo = sendSpriteToExt

local moveSpriteTo = function(parameters)
	if not objects[parameters.sprite].isMoving then
		local object = objects[parameters.sprite]
		local layer = object.layer
		if not parameters.time or parameters.time < 1 then
			parameters.time = 1
		end
		parameters.time = math.ceil(parameters.time / frameTime)
		if parameters.locX then
			levelPos = convert("locToLevelPos", parameters.locX, parameters.locY)
			parameters.levelPosX = levelPos.x
			parameters.levelPosY = levelPos.y
		end
		local startX = object.levelPosX
		local startY = object.levelPosY
		local endX = startX
		local endY = startY
		local distanceXAcross = 0
		local distanceXWrap = 0
		local distanceYAcross = 0
		local distanceYWrap = 0
		local distanceX = 0
		local distanceY = 0
		if parameters.levelPosX then
			if not worldWrapX then
				if parameters.levelPosX > layerWidth[layer] * blockScaleX - object.levelWidth * scaleFactorX * 0.5 - object.offsetX * scaleFactorX then
					parameters.levelPosX = layerWidth[layer] * blockScaleX - object.levelWidth * scaleFactorX * 0.5 - object.offsetX * scaleFactorX
				end
				if parameters.levelPosX < 0 + object.levelWidth * scaleFactorX * 0.5 - object.offsetX * scaleFactorX then
					parameters.levelPosX = 0 + object.levelWidth * scaleFactorX * 0.5 - object.offsetX * scaleFactorX
				end
				endX = parameters.levelPosX
				distanceX = endX - startX
				--MOVE OR GOTO
				if abs(distanceX) > blockScaleX * 4 and parameters.time < 2 then
					object.deltaX = {0}
					local destX = cameraX[layer] - (object.levelPosX + blockScaleX * 0.5)
					local destY = cameraY[layer] - (object.levelPosY + blockScaleY * 0.5)
					sendSpriteTo({sprite = parameters.sprite, levelPosX = parameters.levelPosX, levelPosY = object.levelPosY})
					if cameraFocus == object then
						gotoAll({levelPosX = object.levelPosX + blockScaleX * 0.5 + destX, levelPosY = object.levelPosY + blockScaleY * 0.5 + destY})
					end
				else
					object.deltaX = {}
					object.deltaX = easingHelper(distanceX, parameters.time, parameters.easing)
					object.isMoving = true
				end
			else
				if parameters.locX then
					parameters.levelPosX = convert("locToLevelPos", parameters.locX, nil, nil, true)
				end
				
				local tempPosX = parameters.levelPosX
				if tempPosX > layerWidth[layer] * blockScaleX then
					tempPosX = tempPosX - layerWidth[layer] * blockScaleX
				end
				if tempPosX < 1 then
					tempPosX = tempPosX + layerWidth[layer] * blockScaleX
				end
				
				local tempPosX2 = tempPosX
				if tempPosX > startX then
					tempPosX2 = tempPosX - layerWidth[layer] * blockScaleX
				elseif tempPosX < startX then
					tempPosX2 = tempPosX + layerWidth[layer] * blockScaleX
				end
				
				distanceXAcross = abs(startX - tempPosX)
				distanceXWrap = abs(startX - tempPosX2)
				if distanceXWrap < distanceXAcross then
					if tempPosX > startX then
						local offsetX = cameraX[layer] - object.levelPosX - blockScaleX * 0.5
						local offsetY = cameraY[layer] - object.levelPosY - blockScaleY * 0.5
						sendSpriteTo({sprite = parameters.sprite, levelPosX = object.levelPosX + layerWidth[layer] * blockScaleX, 
							levelPosY = object.levelPosY}
						)
						if cameraFocus == object then
							gotoAll({levelPosX = object.levelPosX + blockScaleX * 0.5 + offsetX, levelPosY = object.levelPosY + blockScaleY * 0.5 + offsetY})
						end
					elseif tempPosX < startX then
						local offsetX = cameraX[layer] - object.levelPosX - blockScaleX * 0.5
						local offsetY = cameraY[layer] - object.levelPosY - blockScaleY * 0.5
						sendSpriteTo({sprite = parameters.sprite, levelPosX = object.levelPosX - layerWidth[layer] * blockScaleX, 
							levelPosY = object.levelPosY}
						)
						if cameraFocus == object then
							gotoAll({levelPosX = object.levelPosX + blockScaleX * 0.5 + offsetX, levelPosY = object.levelPosY + blockScaleY * 0.5 + offsetY})
						end
					end
					startX = object.levelPosX
					endX = tempPosX
					distanceX = endX - startX
					object.deltaX = {}
					object.deltaX = easingHelper(distanceX, parameters.time, parameters.easing)
					object.isMoving = true
				else
					endX = parameters.levelPosX
					distanceX = endX - startX
					--MOVE OR GOTO
					if abs(distanceX) > blockScaleX * 4 and parameters.time < 2 then
						object.deltaX = {0}
						local destX = cameraX[layer] - (object.levelPosX + blockScaleX * 0.5)
						local destY = cameraY[layer] - (object.levelPosY + blockScaleY * 0.5)
						sendSpriteTo({sprite = parameters.sprite, levelPosX = parameters.levelPosX, levelPosY = object.levelPosY})
						if cameraFocus == object then
							gotoAll({levelPosX = object.levelPosX + blockScaleX * 0.5 + destX, levelPosY = object.levelPosY + blockScaleY * 0.5 + destY})
						end
					else
						object.deltaX = {}
						object.deltaX = easingHelper(distanceX, parameters.time, parameters.easing)
						object.isMoving = true
					end
				end
			end
			
			if not worldWrapY then
				if parameters.levelPosY > layerHeight[layer] * blockScaleY - object.levelHeight * scaleFactorY * 0.5 - object.offsetY * scaleFactorY then
					parameters.levelPosY = layerHeight[layer] * blockScaleY - object.levelHeight * scaleFactorY * 0.5 - object.offsetY * scaleFactorY
				end
				if parameters.levelPosY < 0 + object.levelHeight * scaleFactorY * 0.5 - object.offsetY * scaleFactorY then
					parameters.levelPosY = 0 + object.levelHeight * scaleFactorY * 0.5 - object.offsetY * scaleFactorY
				end
				endY = parameters.levelPosY
				distanceY = endY - startY
				--MOVE OR GOTO
				if abs(distanceY) > blockScaleY * 4 and parameters.time < 2 then
					object.deltaY = {0}
					local destX = cameraX[layer] - (object.levelPosX + blockScaleX * 0.5)
					local destY = cameraY[layer] - (object.levelPosY + blockScaleY * 0.5)
					sendSpriteTo({sprite = parameters.sprite, levelPosX = object.levelPosX, levelPosY = parameters.levelPosY})
					if cameraFocus == object then
						gotoAll({levelPosX = object.levelPosX + blockScaleX * 0.5 + destX, levelPosY = object.levelPosY + blockScaleY * 0.5 + destY})
					end
				else
					object.deltaY = {}
					object.deltaY = easingHelper(distanceY, parameters.time, parameters.easing)
					object.isMoving = true
				end
			else
				if parameters.locY then
					parameters.levelPosY = convert("locToLevelPos", nil, parameters.locY, nil, nil, true)
				end
				
				local tempPosY = parameters.levelPosY
				if tempPosY > layerHeight[layer] * blockScaleY then
					tempPosY = tempPosY - layerHeight[layer] * blockScaleY
				end
				if tempPosY < 1 then
					tempPosY = tempPosY + layerHeight[layer] * blockScaleY
				end
				
				local tempPosY2 = tempPosY
				if tempPosY > startY then
					tempPosY2 = tempPosY - layerHeight[layer] * blockScaleY
				elseif tempPosY < startY then
					tempPosY2 = tempPosY + layerHeight[layer] * blockScaleY
				end
				
				distanceYAcross = abs(startY - tempPosY)
				distanceYWrap = abs(startY - tempPosY2)
				
				if distanceYWrap < distanceYAcross then
					if tempPosY > startY then
						local offsetX = cameraX[layer] - object.levelPosX - blockScaleX * 0.5
						local offsetY = cameraY[layer] - object.levelPosY - blockScaleY * 0.5
						sendSpriteTo({sprite = parameters.sprite, levelPosX = object.levelPosX, 
							levelPosY = object.levelPosY + layerHeight[layer] * blockScaleY}
						)
						if cameraFocus == object then
							gotoAll({levelPosX = object.levelPosX + blockScaleX * 0.5 + offsetX, levelPosY = object.levelPosY + blockScaleY * 0.5 + offsetY})
						end
					elseif tempPosY < startY then
						local offsetX = cameraX[layer] - object.levelPosX - blockScaleX * 0.5
						local offsetY = cameraY[layer] - object.levelPosY - blockScaleY * 0.5
						sendSpriteTo({sprite = parameters.sprite, levelPosX = object.levelPosX, 
							levelPosY = object.levelPosY - layerHeight[layer] * blockScaleY}
						)
						if cameraFocus == object then
							gotoAll({levelPosX = object.levelPosX + blockScaleX * 0.5 + offsetX, levelPosY = object.levelPosY + blockScaleY * 0.5 + offsetY})
						end
					end
					startY = object.levelPosY
					endY = tempPosY
					distanceY = endY - startY
					object.deltaY = {}
					object.deltaY = easingHelper(distanceY, parameters.time, parameters.easing)
					object.isMoving = true
				else
					endY = parameters.levelPosY
					distanceY = endY - startY
					--MOVE OR GOTO
					if abs(distanceY) > blockScaleY * 4 and parameters.time < 2 then
						object.deltaY = {0}
						local destX = cameraX[layer] - (object.levelPosX + blockScaleX * 0.5)
						local destY = cameraY[layer] - (object.levelPosY + blockScaleY * 0.5)
						sendSpriteTo({sprite = parameters.sprite, levelPosX = object.levelPosX, levelPosY = parameters.levelPosY})
						if cameraFocus == object then
							gotoAll({levelPosX = object.levelPosX + blockScaleX * 0.5 + destX, levelPosY = object.levelPosY + blockScaleY * 0.5 + destY})
						end
					else
						object.deltaY = {}
						object.deltaY = easingHelper(distanceY, parameters.time, parameters.easing)
						object.isMoving = true
					end
				end
			end
		else
			print("WARNING(moveSpriteTo): No destination specified.")
		end
		movingSprites[parameters.sprite] = object
	end
end

local moveSpriteToExt = function(parameters)
	local layer = objects[parameters.sprite].layer
	if parameters.levelPosX then
		parameters.levelPosX = parameters.levelPosX * scaleFactorX --coordX(parameters.levelPosX)
		if not worldWrapX then
			if parameters.levelPosX > layerWidth[layer] * blockScaleX then
				parameters.levelPosX = layerWidth[layer] * blockScaleX
			end
			if parameters.levelPosX < 1 then
				parameters.levelPosX = 1
			end
		end
	end
	if parameters.levelPosY then
		parameters.levelPosY = parameters.levelPosY * scaleFactorY --coordY(parameters.levelPosY)
		if not worldWrapY then
			if parameters.levelPosY > layerHeight[layer] * blockScaleY then
				parameters.levelPosY = layerHeight[layer] * blockScaleY
			end
			if parameters.levelPosY < 1 then
				parameters.levelPosY = 1
			end
		end
	end
	if parameters.locX and not worldWrapX then
		if parameters.locX > layerWidth[layer] then
			parameters.locX = layerWidth[layer]
		end
		if parameters.locX < 1 then
			parameters.locX = 1
		end
	end
	if parameters.locY and not worldWrapY then
		if parameters.locY > layerHeight[layer] then
			parameters.locY = layerHeight[layer]
		end
		if parameters.locY < 1 then
			parameters.locY = 1
		end
	end
	
	moveSpriteTo(parameters)
end
M.moveSpriteTo = moveSpriteToExt

local moveSpriteExt = function(sprite, velX, velY)
	--ENABLED FPS INDEPENDENCE
	--velX = coordX(velX) -- / frameMod
	--velY = coordY(velY) -- / frameMod
	velX = velX * scaleFactorX
	velY = velY * scaleFactorY
	--[[
	if not worldWrapX then
		if objects[sprite].levelPosX + velX > worldSizeX * blockScale then
			velX = worldSizeX * blockScale - objects[sprite].levelPosX
		end
	end
	if not worldWrapY then
		if objects[sprite].levelPosY + velY > worldSizeY * blockScale then
			velY = worldSizeY * blockScale - objects[sprite].levelPosY
		end
	end
	]]--
	if velX ~= 0 or velY ~= 0 then
	moveSpriteTo({sprite = sprite, levelPosX = objects[sprite].levelPosX + velX,
		levelPosY = objects[sprite].levelPosY + velY, time = frameTime}
	)
	end
end
M.moveSprite = moveSpriteExt

local moveCameraTo2 = function(parameters)
	if not isCameraMoving then
		if not parameters.time or parameters.time < 1 then
			parameters.time = 1
		end
		parameters.time = math.ceil(parameters.time / frameTime)
		local levelPosX
		local levelPosY
		local layer = parameters.layer
		if parameters.levelPosX then
			levelPosX = parameters.levelPosX + blockScaleX * 0.5
			levelPosY = parameters.levelPosY + blockScaleY * 0.5
		end
		if parameters.sprite then
			levelPosX = objects[parameters.sprite].levelPosX + objects[parameters.sprite].levelWidth * scaleFactorX * 0.5 + objects[parameters.sprite].offsetX * scaleFactorX
			levelPosY = objects[parameters.sprite].levelPosY + objects[parameters.sprite].levelHeight * scaleFactorY * 0.5 + objects[parameters.sprite].offsetY * scaleFactorY
			layer = objects[parameters.sprite].layer
		end
		if parameters.locX then
			levelPos = convert("locToLevelPos", parameters.locX, parameters.locY)
			levelPosX = levelPos.x + blockScaleX * 0.5
			levelPosY = levelPos.y + blockScaleY * 0.5
		end
		if not layer or layer < 0 or layer > #map.layers then
			--print("WARNING(moveCameraTo): Layer out of bounds. Defaulting to layer 1.")
			layer = refLayer
		end
		local startX = cameraX[layer]-- - blockScaleX * 0.5
		local startY = cameraY[layer]-- - blockScaleY * 0.5
		local startLocX = cameraLocX[layer]
		local startLocY = cameraLocY[layer]
		local endX = startX
		local endY = startY
		local distanceXAcross = 0
		local distanceXWrap = 0
		local distanceYAcross = 0
		local distanceYWrap = 0
		local distanceX = 0
		local distanceY = 0
		if levelPosX then
			if not worldWrapX then
				if levelPosX > layerWidth[layer] * blockScaleX then
					levelPosX = layerWidth[layer] * blockScaleX
				end
				if levelPosX < 1 then
					levelPosX = 1 
				end
				endX = levelPosX
				distanceX = endX - startX
				if abs(distanceX) > blockScaleX * 4 and parameters.time < 2 then
					deltaX = {0}
					gotoAll({levelPosX = levelPosX, levelPosY = levelPosY})
				else
					deltaX = {}
					deltaX = easingHelper(distanceX, parameters.time, parameters.easing)
				end
			else
				if parameters.locX then
					parameters.levelPosX = convert("locToLevelPos", parameters.locX, nil, nil, true)
				end

				local tempPosX = levelPosX -- + blockScaleX * 0.5
				if tempPosX > layerWidth[layer] * blockScaleX then
					tempPosX = tempPosX - layerWidth[layer] * blockScaleX
				elseif tempPosX < 1 then
					tempPosX = tempPosX + layerWidth[layer] * blockScaleX
				end
				
				local tempPosX2 = tempPosX
				if tempPosX > startX then
					tempPosX2 = tempPosX - layerWidth[layer] * blockScaleX
				elseif tempPosX < startX then
					tempPosX2 = tempPosX + layerWidth[layer] * blockScaleX
				end
				
				distanceXAcross = abs(startX - tempPosX)
				distanceXWrap = abs(startX - tempPosX2)
				
				if distanceXWrap < distanceXAcross then
					if tempPosX > startX then
						gotoAll({levelPosX = startX + layerWidth[layer] * blockScaleX, levelPosY = startY})
					elseif tempPosX < startX then
						gotoAll({levelPosX = startX - layerWidth[layer] * blockScaleX, levelPosY = startY})
					end
					startX = cameraX[layer]
					endX = tempPosX
					distanceX = endX - startX
					deltaX = {}
					deltaX = easingHelper(distanceX, parameters.time, parameters.easing)
				else
					if levelPosX > layerWidth[layer] * blockScaleX then
						levelPosX = layerWidth[layer] * blockScaleX
					end
					if levelPosX < 1 then
						levelPosX = 1
					end
					endX = levelPosX -- + blockScaleX * 0.5
					distanceX = endX - startX
					if abs(distanceX) > blockScaleX * 4 and parameters.time < 2 then
						deltaX = {0}
						gotoAll({levelPosX = levelPosX, levelPosY = levelPosY})
					else
						deltaX = {}
						deltaX = easingHelper(distanceX, parameters.time, parameters.easing)
					end
				end
			end
			
			if not worldWrapY then
				if levelPosY > layerHeight[layer] * blockScaleY then
					levelPosY = layerHeight[layer] * blockScaleY
				end
				if levelPosY < 1 then
					levelPosY = 1
				end
				endY = levelPosY
				distanceY = endY - startY
				if abs(distanceY) > blockScaleY * 4 and parameters.time < 2 then
					deltaY = {0}
					gotoAll({levelPosX = levelPosX, levelPosY = levelPosY})
				else
					deltaY = {}
					deltaY = easingHelper(distanceY, parameters.time, parameters.easing)
				end
			else
				if parameters.locY then
					parameters.levelPosY = convert("locToLevelPos", nil, parameters.locY, nil, nil, true)
				end
				
				local tempPosY = levelPosY -- + blockScaleY * 0.5
				if tempPosY > layerHeight[layer] * blockScaleY then
					tempPosY = tempPosY - layerHeight[layer] * blockScaleY
				elseif tempPosY < 1 then
					tempPosY = tempPosY + layerHeight[layer] * blockScaleY
				end
				
				local tempPosY2 = tempPosY
				if tempPosY > startY then
					tempPosY2 = tempPosY - layerHeight[layer] * blockScaleY
				elseif tempPosY < startY then
					tempPosY2 = tempPosY + layerHeight[layer] * blockScaleY
				end
				
				distanceYAcross = abs(startY - tempPosY)
				distanceYWrap = abs(startY - tempPosY2)

				if distanceYWrap < distanceYAcross then
					if tempPosY > startY then
						gotoAll({levelPosX = startX, levelPosY = startY + layerHeight[layer] * blockScaleY})
					elseif tempPosX < startX then
						gotoAll({levelPosX = startX, levelPosY = startY - layerHeight[layer] * blockScaleY})
					end
					startY = cameraY[layer]
					endY = tempPosY
					distanceY = endY - startY
					deltaY = {}
					deltaY = easingHelper(distanceY, parameters.time, parameters.easing)
				else
					if levelPosY > layerHeight[layer] * blockScaleY then
						levelPosY = layerHeight[layer] * blockScaleY
					end
					if levelPosY < 1 then
						levelPosY = 1
					end
					endY = levelPosY -- + blockScaleY * 0.5
					distanceY = endY - startY
					if abs(distanceY) > blockScaleY * 4 and parameters.time < 2 then
						deltaY = {0}
						gotoAll({levelPosX = levelPosX, levelPosY = levelPosY})
					else
						deltaY = {}
						deltaY = easingHelper(distanceY, parameters.time, parameters.easing)
					end
				end
			end
		else
			print("WARNING(moveCameraTo): No destination specified.")
		end
		isCameraMoving = true
	end
end

local moveCameraToExt = function(parameters)
	if not parameters.layer and not parameters.sprite then
		parameters.layer = refLayer
	end
	if parameters.levelPosX then
		parameters.levelPosX = parameters.levelPosX * scaleFactorX --coordX(parameters.levelPosX)
	end
	if parameters.levelPosY then
		parameters.levelPosY = parameters.levelPosY * scaleFactorY --coordY(parameters.levelPosY)
	end
	moveCameraTo2(parameters)
end
M.moveCameraTo = moveCameraToExt

local moveCameraExt = function(velX, velY, layer)
	--ENABLED FPS INDEPENDENCE
	--velX = coordX(velX) / frameMod - blockScale * 0.5
	--velY = coordY(velY) / frameMod - blockScale * 0.5
	--velX = velX * scaleFactorX --coordX(velX)
	--velY = velY * scaleFactorY --coordY(velY)
	
	if not layer then
		layer = refLayer
	end
	
	--velX = coordX(velX) - blockScaleX * 0.5
	--velY = coordY(velY) - blockScaleY * 0.5
	velX = (velX * scaleFactorX) - blockScaleX * 0.5
	velY = (velY * scaleFactorY) - blockScaleY * 0.5
	moveCameraTo2({levelPosX = cameraX[layer] + velX,
		levelPosY = cameraY[layer] + velY, time = frameTime}
	)
end
M.moveCamera = moveCameraExt

M.fadeTile = function(locX, locY, layer, alpha, time, easing)
	if not locX or not locY or not layer then
		print("ERROR: Please specify locX, locY, and layer.")
	end
	if not alpha and not time then
		local tile = getTileObj(locX, locY, layer)
		if fadingTiles[tile] then
			return true
		end
	else
		local tile = getTileObj(locX, locY, layer)
		local currentAlpha = tile.alpha
		local distance = currentAlpha - alpha
		time = math.ceil(time / frameTime)
		if not time or time < 1 then
			time = 1
		end
		tile.deltaFade = {}
		tile.deltaFade = easingHelper(distance, time, easing)
		tile.tempAlpha = currentAlpha
		fadingTiles[tile] = tile
	end
end
--M.fadeTile = fadeTile

M.fadeLayer = function(layer, alpha, time, easing)
	if not layer then
		print("ERROR: No layer specified. Defaulting to layer "..refLayer..".")
		layer = refLayer
	end
	if not alpha and not time then
		if displayGroups[layer].deltaFade then
			return true
		end
	else
		local currentAlpha = displayGroups[layer].alpha
		local distance = currentAlpha - alpha
		time = math.ceil(time / frameTime)
		if not time or time < 1 then
			time = 1
		end
		displayGroups[layer].deltaFade = {}
		displayGroups[layer].deltaFade = easingHelper(distance, time, easing)
		displayGroups[layer].tempAlpha = currentAlpha
	end
end
--M.fadeLayer = fadeLayer

M.fadeLevel = function(level, alpha, time, easing)
	if not level then
		print("ERROR: No level specified. Defaulting to level 1.")
		level = 1
	end
	if not alpha and not time then
		for i = 1, #map.layers, 1 do
			if map.layers[i].properties.level == level then
				if displayGroups[i].deltaFade then
					return true
				end
			end
		end
	else
		for i = 1, #map.layers, 1 do
			if map.layers[i].properties.level == level then
				M.fadeLayer(i, alpha, time, easing)
			end
		end
	end
end
--M.fadeLevel = fadeLevel

M.fadeMap = function(alpha, time, easing)
	if not alpha and not time then
		for i = 1, #map.layers, 1 do
			if displayGroups[i].deltaFade then
				return true
			end
		end
	else
		for i = 1, #map.layers, 1 do
			M.fadeLayer(i, alpha, time, easing)
		end
	end
end
--M.fadeMap = fadeMap

M.tintTile = function(locX, locY, layer, color, time, easing)
	if not locX or not locY or not layer then
		print("ERROR: Please specify locX, locY, and layer.")
	end
	if not color and not time then
		local tile = getTileObj(locX, locY, layer)
		if tintingTiles[tile] then
			return true
		end
	else
		local tile = getTileObj(locX, locY, layer)
		if not tile.currentColor then
			tile.currentColor = {map.layers[layer].redLight, 
				map.layers[layer].greenLight, 
				map.layers[layer].blueLight
			}
		end
		local distanceR = tile.currentColor[1] - color[1]
		local distanceG = tile.currentColor[2] - color[2]
		local distanceB = tile.currentColor[3] - color[3]
		time = math.ceil(time / frameTime)
		if not time or time < 1 then
			time = 1
		end
		local deltaR = easingHelper(distanceR, time, easing)
		local deltaG = easingHelper(distanceG, time, easing)
		local deltaB = easingHelper(distanceB, time, easing)
		tile.deltaTint = {deltaR, deltaG, deltaB}
		tintingTiles[tile] = tile
	end
end
--M.tintTile = tintTile

M.tintLayer = function(layer, color, time, easing)
	if not layer then
		print("ERROR: No layer specificed. Defaulting to layer "..refLayer..".")
		layer = refLayer
	end
	if not color and not time then
		if displayGroups[layer].deltaTint then
			return true
		end
	else
		local distanceR = map.layers[layer].redLight - color[1]
		local distanceG = map.layers[layer].greenLight - color[2]
		local distanceB = map.layers[layer].blueLight - color[3]
		time = math.ceil(time / frameTime)
		if not time or time < 1 then
			time = 1
		end
		local deltaR = easingHelper(distanceR, time, easing)
		local deltaG = easingHelper(distanceG, time, easing)
		local deltaB = easingHelper(distanceB, time, easing)
		displayGroups[layer].deltaTint = {deltaR, deltaG, deltaB}
	end
end
--M.tintLayer = tintLayer

M.tintLevel = function(level, color, time, easing)
	if not level then
		print("ERROR: No level specified. Defaulting to level 1.")
		level = 1
	end
	if not color and not time then
		for i = 1, #map.layers, 1 do
			if map.layers[i].properties.level == level then
				if displayGroups[i].deltaTint then
					return true
				end
			end
		end
	else
		for i = 1, #map.layers, 1 do
			if map.layers[i].properties.level == level then
				tintLayer(i, color, time, easing)
			end
		end
	end
end
--M.tintLevel = tintLevel

M.tintMap = function(color, time, easing)
	if not color and not time then
		for i = 1, #map.layers, 1 do
			if displayGroups[i].deltaTint then
				return true
			end
		end
	else
		for i = 1, #map.layers, 1 do
			tintLayer(i, color, time, easing)
		end
	end
end
--M.tintMap = tintMap

M.zoom = function(scale, time, easing)
	if not scale and not time then
		if deltaZoom then
			return true
		end
	else
		currentScale = masterGroup.xScale
		local distance = currentScale - scale
		time = math.ceil(time / frameTime)
		if not time or time < 1 then
			time = 1
		end
		local delta = easingHelper(distance, time, easing)
		deltaZoom = delta
	end
end
--M.zoom = zoom

M.cleanup = function()
	--DESTROY GRID
	for i = 1, #rects, 1 do
		for x = 1, rectsWidth[i], 1 do
			for y = 1, rectsHeight[i], 1 do
				if rects[i][x][y] ~= 9999 then
					rects[i][x][y]:removeSelf()
				end
			end
		end
	end
	rects = {}
	
	--CLEAR WORLD ARRAYS
	for key,value in pairs(objects) do
		removeSprite(key)
	end
	tileSets = {}
	map = {}
	worldSizeX = nil
	worldSizeY = nil
	layerWidth = {}
	layerHeight = {}
	imageDirectory = ""
	displayGroups = {}
	masterGroup = nil
	objects = {}
	spriteLayers = {}
	
	--RESET CAMERA POSITION VARIABLES
	cameraX = {}
	cameraY = {}
	cameraLocX = {}
	cameraLocY = {}
	prevLocX = {}
	prevLocY = {}
	--cameraVelX = 0
	--cameraVelY = 0
	displayWidth = display.viewableContentWidth
	displayHeight = display.viewableContentHeight
	
	for key,value in pairs(animatedTiles) do
		animatedTiles[key] = nil
	end
	
	for key,value in pairs(fadingTiles) do
		fadingTiles[key] = nil
	end
	
	for key,value in pairs(tintingTiles) do
		tintingTiles[key] = nil
	end
	
	currentScale = 1
	deltaZoom = nil
end
--M.cleanup = cleanup

local prevTime = 0
local dbTog = 0
local dCount = 1
local memory = "0"
local mod
M.debug = function(fps)
	if not fps then
		fps = display.fps
	end
	if dbTog == 0 then
		mod = display.fps / fps
		local size = 22
		local scale = 2
		if display.viewableContentHeight < 500 then
			size = 14
			scale = 1
		end
		rectCount = display.newText("null", 50 * scale, 80 * scale, native.systemFont, size)
		rectCount:setTextColor(255,0,0)
		debugX = display.newText("null", 50 * scale, 20 * scale, native.systemFont, size)
		debugX:setTextColor(255,0,0)
		debugY = display.newText("null", 50 * scale, 35 * scale, native.systemFont, size)
		debugY:setTextColor(255,0,0)
		debugLocX = display.newText("null", 50 * scale, 50 * scale, native.systemFont, size)
		debugLocX:setTextColor(255,0,0)
		debugLocY = display.newText("null", 50 * scale, 65 * scale, native.systemFont, size)
		debugLocY:setTextColor(255,0,0)
		--[[
		debugVelX = display.newText("null", 50 * scale, 80 * scale, native.systemFont, size)
		debugVelX:setTextColor(255,0,0)
		debugVelY = display.newText("null", 50 * scale, 95 * scale, native.systemFont, size)
		debugVelY:setTextColor(255,0,0)
		debugAccX = display.newText("null", 50 * scale, 110 * scale, native.systemFont, size)
		debugAccX:setTextColor(255,0,0)
		debugAccY = display.newText("null", 50 * scale, 125 * scale, native.systemFont, size)
		debugAccY:setTextColor(255,0,0)
		]]--
		debugLoading = display.newText("null", display.viewableContentWidth / 2, 10, native.systemFont, size)
		debugLoading:setTextColor(255,0,0)
		debugMemory = display.newText("null", 60 * scale, 95 * scale, native.systemFont, size)
		debugMemory:setTextColor(255, 0, 0)
		debugFPS = display.newText("null", 60 * scale, 110 * scale, native.systemFont, size)
		debugFPS:setTextColor(255, 0, 0)
		dbTog = 1
	end
	
	local layer = refLayer
	local sumRects = 0
	for i = 1, #map.layers, 1 do
		if totalRects[i] then
			sumRects = sumRects + totalRects[i]
		end
	end
	debugX.text = "cameraX: "..(cameraX[layer] / scaleFactorX) - (worldScaleX * 0.5)
	debugX:toFront()
	debugY.text = "cameraY: "..(cameraY[layer] / scaleFactorY) - (worldScaleY * 0.5)
	debugY:toFront()
	debugLocX.text = "cameraLocX: "..ceil(((cameraX[layer] / scaleFactorX) - (worldScaleX * 0.5)) / worldScaleX)     
	debugLocX:toFront()
	debugLocY.text = "cameraLocY: "..ceil(((cameraY[layer] / scaleFactorY) - (worldScaleY * 0.5)) / worldScaleY)	 
	debugLocY:toFront()
	--[[
	debugVelX.text = "cameraVelX: "..levelX(cameraVelX)
	debugVelX:toFront()
	debugVelY.text = "cameraVelY: "..levelY(cameraVelY)
	debugVelY:toFront()
	debugAccX.text = "cameraAccX: "..levelX(playerAccX)
	debugAccX:toFront()
	debugAccY.text = "cameraAccY: "..levelY(playerAccY)
	debugAccY:toFront()
	]]--
	rectCount.text = "Total Tiles: "..sumRects
	rectCount:toFront()
	dCount = dCount + 1
	if dCount >= 60 / mod then
		dCount = 1
		memory = string.format("%g", collectgarbage("count") / 1000)
	end
	
	debugMemory.text = "Memory: "..memory.." MB"
	debugMemory:toFront()
	
	local curTime = system.getTimer()
	local dt = curTime - prevTime
	prevTime = curTime
	
	local fps = math.floor(1000/dt) * mod
	
	local lowDelay = 20 / mod
	if #frameArray < lowDelay then
		frameArray[#frameArray + 1] = fps
	else
		local temp = 0
		for i = 1, #frameArray, 1 do
			temp = temp + frameArray[i]	
		end
		avgFrame = temp / lowDelay
		frameArray = {}
	end
	
	debugFPS.text = "FPS: "..fps.."   AVG: "..avgFrame
	debugFPS:toFront()
	debugLoading.text = debugText
	debugLoading:toFront()
end
--M.debug = debug

return M













