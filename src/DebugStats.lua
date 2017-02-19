local DebugStats = {}

local Camera = require("src.Camera")
local Map = require("src.Map")

-----------------------------------------------------------

local prevTime = 0
local dbTog = 0
local dCount = 1
local memory = "0"
local mod
local rectCount
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

DebugStats.debug = function(fps)
    
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
        debugX = display.newText("null", 50 * scale, 20 * scale, native.systemFont, size)
        debugY = display.newText("null", 50 * scale, 35 * scale, native.systemFont, size)
        debugLocX = display.newText("null", 50 * scale, 50 * scale, native.systemFont, size)
        debugLocY = display.newText("null", 50 * scale, 65 * scale, native.systemFont, size)
        debugLoading = display.newText("null", display.viewableContentWidth / 2, 10, native.systemFont, size)
        debugMemory = display.newText("null", 60 * scale, 95 * scale, native.systemFont, size)
        debugFPS = display.newText("null", 60 * scale, 110 * scale, native.systemFont, size)
        dbTog = 1		
        rectCount:setFillColor(1, 1, 1)
        debugX:setFillColor(1, 1, 1)
        debugY:setFillColor(1, 1, 1)
        debugLocX:setFillColor(1, 1, 1)
        debugLocY:setFillColor(1, 1, 1)
        debugLoading:setFillColor(1, 1, 1)
        debugMemory:setFillColor(1, 1, 1)
        debugFPS:setFillColor(1, 1, 1)
    end		
    
    local layer = Map.refLayer
    local sumRects = 0
    
    for i = 1, #Map.map.layers, 1 do
        if Map.totalRects[i] then
            sumRects = sumRects + Map.totalRects[i]
        end
    end
    
    if Map.map.orientation == Map.Type.Isometric then
        local cameraX = string.format("%g", Camera.McameraX)
        local cameraY = string.format("%g", Camera.McameraY)
        debugX.text = "cameraX: "..cameraX
        debugX:toFront()
        debugY.text = "cameraY: "..cameraY
        debugY:toFront()
        debugLocX.text = "cameraLocX: "..Camera.McameraLocX	
        debugLocY.text = "cameraLocY: "..Camera.McameraLocY
    else
        local cameraX = string.format("%g", Camera.McameraX)
        local cameraY = string.format("%g", Camera.McameraY)
        debugX.text = "cameraX: "..cameraX
        debugX:toFront()
        debugY.text = "cameraY: "..cameraY
        debugY:toFront()
        debugLocX.text = "cameraLocX: "..Camera.McameraLocX
        debugLocY.text = "cameraLocY: "..Camera.McameraLocY
    end
    
    debugLocX:toFront()
    debugLocY:toFront()	
    
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

-----------------------------------------------------------

return DebugStats
