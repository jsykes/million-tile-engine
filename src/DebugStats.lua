local DebugStats = {}

local Camera = require("src.Camera")
local Map = require("src.Map")

-----------------------------------------------------------
local displayGroup = display.newGroup();
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
local debugMemory
local debugFPS
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
        local size = 14
        local boxHeight = 20
        local boxWidth = 180

        if display.viewableContentHeight > 512 then
            size = 18
            boxHeight = 30
            boxWidth = 220
        end

        if display.viewableContentHeight > 1024 then
            size = 36
            boxHeight = 50
            boxWidth = 360
        end

        rectCount = native.newTextBox( 0, display.contentHeight * .05, boxWidth, boxHeight );
        rectCount.font = native.newFont( "Helvetica", size );
        rectCount:setTextColor( 1, 1, 1);
        rectCount.alpha = 1.0;
        rectCount.hasBackground = false;
        rectCount.text = 'null';

        debugX = native.newTextBox( 0, rectCount.y + rectCount.height, boxWidth, boxHeight );
        debugX.font = native.newFont( "Helvetica", size );
        debugX:setTextColor( 1, 1, 1);
        debugX.alpha = 1.0;
        debugX.hasBackground = false;
        debugX.text = 'null';

        debugY = native.newTextBox( 0, debugX.y + debugX.height, boxWidth, boxHeight );
        debugY.font = native.newFont( "Helvetica", size );
        debugY:setTextColor( 1, 1, 1);
        debugY.alpha = 1.0;
        debugY.hasBackground = false;
        debugY.text = 'null';

        debugLocX = native.newTextBox( 0, debugY.y + debugY.height, boxWidth, boxHeight );
        debugLocX.font = native.newFont( "Helvetica", size );
        debugLocX:setTextColor( 1, 1, 1);
        debugLocX.alpha = 1.0;
        debugLocX.hasBackground = false;
        debugLocX.text = 'null';

        debugLocY = native.newTextBox( 0, debugLocX.y + debugLocX.height, boxWidth, boxHeight );
        debugLocY.font = native.newFont( "Helvetica", size );
        debugLocY:setTextColor( 1, 1, 1);
        debugLocY.alpha = 1.0;
        debugLocY.hasBackground = false;
        debugLocY.text = 'null';

        debugMemory = native.newTextBox( 0, debugLocY.y + debugLocY.height, boxWidth, boxHeight );
        debugMemory.font = native.newFont( "Helvetica", size );
        debugMemory:setTextColor( 1, 1, 1);
        debugMemory.alpha = 1.0;
        debugMemory.hasBackground = false;
        debugMemory.text = 'null';

        debugFPS = native.newTextBox( 0, debugMemory.y + debugMemory.height, boxWidth, boxHeight );
        debugFPS.font = native.newFont( "Helvetica", size );
        debugFPS:setTextColor( 1, 1, 1);
        debugFPS.alpha = 1.0;
        debugFPS.hasBackground = false;
        debugFPS.text = 'null';

        displayGroup:insert(rectCount);
        displayGroup:insert(debugX);
        displayGroup:insert(debugY);
        displayGroup:insert(debugLocX);
        displayGroup:insert(debugLocY);
        displayGroup:insert(debugMemory);
        displayGroup:insert(debugFPS);

        displayGroup.anchorX = 0;
        displayGroup.anchorY = 0;

        displayGroup.x = -math.abs(display.screenOriginX);
        displayGroup.y = -math.abs(display.screenOriginY);
        displayGroup.anchorChildren = true;

        dbTog = 1
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
end

-----------------------------------------------------------

return DebugStats
