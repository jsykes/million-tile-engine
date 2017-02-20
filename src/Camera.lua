local Camera = {}

local Map = require("src.Map")

-----------------------------------------------------------

Camera.McameraX, Camera.McameraY = 0, 0
Camera.McameraLocX, Camera.McameraLocY = 0, 0

Camera.cameraX = 0
Camera.cameraY = 0
Camera.cameraLocX = 0
Camera.cameraLocY = 0
Camera.constrainTop = {}
Camera.constrainBottom = {}
Camera.constrainLeft = {}
Camera.constrainRight = {}
Camera.refMove = false
Camera.override = {}
Camera.cameraOnComplete = {}	
Camera.cameraFocus = nil
Camera.isCameraMoving = {}
Camera.deltaX = {}
Camera.deltaY = {}
Camera.maxZoom = 9999
Camera.minZoom = -9999
Camera.parallaxToggle = {}
Camera.worldWrapX = false
Camera.worldWrapY = false
Camera.layerWrapX = {}
Camera.layerWrapY = {}
Camera.currentScale = nil
Camera.deltaZoom = nil
Camera.screen = {}		
Camera.cullingMargin = {0, 0, 0, 0}
Camera.touchScroll = { false, nil, nil, nil, nil, nil }
Camera.pinchZoom = false

-----------------------------------------------------------

Camera.enableTouchScroll = function()
    Camera.touchScroll[1] = true
    if ( Map.map.layers and not Camera.pinchZoom ) then
        Map.masterGroup:addEventListener("touch", Camera.touchScrollPinchZoom)
    end
end

-----------------------------------------------------------

Camera.enablePinchZoom = function()
    Camera.pinchZoom = true
    if ( Map.map.layers and not Camera.touchScroll[1] ) then
        Map.masterGroup:addEventListener("touch", Camera.touchScrollPinchZoom)
    end
end

-----------------------------------------------------------

Camera.disableTouchScroll = function()
    Camera.touchScroll[1] = false
    if ( Map.map.layers and not Camera.pinchZoom ) then
        Map.masterGroup:removeEventListener("touch", Camera.touchScrollPinchZoom)
    end
end

-----------------------------------------------------------

Camera.disablePinchZoom = function()
    Camera.pinchZoom = false
    if ( Map.map.layers and not Camera.touchScroll[1] ) then
        Map.masterGroup:removeEventListener("touch", Camera.touchScrollPinchZoom)
    end
end

-----------------------------------------------------------

Camera.toggleWorldWrapX = function(command)
    if command == true or command == false then
        Camera.worldWrapX = command
    else 
        if Camera.worldWrapX then
            Camera.worldWrapX = false
        elseif not Camera.worldWrapX then
            Camera.worldWrapX = true
        end
    end
    if Map.map.properties then
        for i = 1, #Map.map.layers, 1 do
            Camera.layerWrapX[i] = Camera.worldWrapX
        end
    end
end

-----------------------------------------------------------

Camera.toggleWorldWrapY = function(command)
    if command == true or command == false then
        Camera.worldWrapY = command
    else
        if Camera.worldWrapY then
            Camera.worldWrapY = false
        elseif not Camera.worldWrapY then
            Camera.worldWrapY = true
        end
    end
    if Map.map.properties then
        for i = 1, #Map.map.layers, 1 do
            Camera.layerWrapY[i] = Camera.worldWrapY
        end
    end
end

-----------------------------------------------------------

Camera.easingHelper = function(distance, frames, kind)
    local frameLength = display.fps
    local move = {}
    local total = 0
    if not kind then
        kind = easing.linear
    end		
    for i = 1, frames, 1 do
        move[i] = kind((i - 1) * frameLength, frameLength * frames, 0, 1000)
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

-----------------------------------------------------------

Camera.setCameraFocus = function(object, offsetX, offsetY)
    if object then
        Camera.cameraFocus = object
        Camera.cameraFocus.cameraOffsetX = {}
        Camera.cameraFocus.cameraOffsetY = {}
        for i = 1, #Map.map.layers, 1 do
            Camera.cameraFocus.cameraOffsetX[i] = offsetX or 0
            Camera.cameraFocus.cameraOffsetY[i] = offsetY or 0
        end
    else
        Camera.cameraFocus = nil
    end
end

Camera.zoom = function(scale, time, easing)
    if not scale and not time then
        if Camera.deltaZoom then
            return true
        end
    else
        Camera.currentScale = Map.masterGroup.xScale
        local distance = Camera.currentScale - scale
        time = math.ceil(time / Map.frameTime)
        if not time or time < 1 then
            time = 1
        end
        local delta = Camera.easingHelper(distance, time, easing)
        Camera.deltaZoom = delta
    end
end

-----------------------------------------------------------

return Camera