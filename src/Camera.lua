local Camera = {}

local Map = require("src.Map")
local Screen = require("src.Screen")

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

Camera.enableLighting = false;
Camera.setLightingEnabled = function(isEnabled)
    Camera.enableLighting = isEnabled or false;
end

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

-----------------------------------------------------------

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

Camera.getCamera = function(layer)
    if Map.map.orientation == Map.Type.Isometric then
        if layer then
            local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
            local cameraX, cameraY = Map.masterGroup[layer]:contentToLocal(tempX, tempY)
            local isoPos = Map.isoUntransform2(cameraX, cameraY)
            cameraX = isoPos[1]
            cameraY = isoPos[2]
            local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
            local cameraLocY = math.ceil(cameraY / Map.map.tileheight)
            return {levelPosX = cameraX, 
                levelPosY = cameraY, 
                locX = cameraLocX, 
            locY = cameraLocY}
        else
            local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
            Camera.McameraX, Camera.McameraY = Map.masterGroup[Map.refLayer]:contentToLocal(tempX, tempY)
            local isoPos = Map.isoUntransform2(Camera.McameraX, Camera.McameraY)
            Camera.McameraX = isoPos[1]
            Camera.McameraY = isoPos[2]
            Camera.McameraLocX = math.ceil(Camera.McameraX / Map.map.tilewidth)
            Camera.McameraLocY = math.ceil(Camera.McameraY / Map.map.tileheight)
            return {levelPosX = Camera.McameraX, 
                levelPosY = Camera.McameraY, 
                locX = Camera.McameraLocX, 
            locY = Camera.McameraLocY}
        end
    else
        if layer then
            local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
            local cameraX, cameraY = Map.masterGroup[layer]:contentToLocal(tempX, tempY)
            local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
            local cameraLocY = math.ceil(cameraY / Map.map.tileheight)
            return {levelPosX = cameraX, 
                levelPosY = cameraY, 
                locX = cameraLocX, 
            locY = cameraLocY}
        else
            local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
            Camera.McameraX, Camera.McameraY = Map.masterGroup[Map.refLayer]:contentToLocal(tempX, tempY)
            Camera.McameraLocX = math.ceil(Camera.McameraX / Map.map.tilewidth)
            Camera.McameraLocY = math.ceil(Camera.McameraY / Map.map.tileheight)
            return {levelPosX = Camera.McameraX, 
                levelPosY = Camera.McameraY, 
                locX = Camera.McameraLocX, 
            locY = Camera.McameraLocY}
        end
    end
end


-----------------------------------------------------------

Camera.moveCameraTo = function(params)
    local check = true
    for i = 1, #Map.map.layers, 1 do
        if i == params.layer or not params.layer then
            if Camera.isCameraMoving[i] then
                check = false
            else
                if params.disableParallax then
                    Camera.parallaxToggle[i] = false
                else
                    params.disableParallax = false
                end
                Camera.cameraOnComplete[i] = false
            end
        end
    end		
    if check and not params.layer then
        Camera.refMove = true
        Camera.cameraOnComplete[1] = params.onComplete
    end
    for i = 1, #Map.map.layers, 1 do
        if (i == params.layer or not params.layer) and check then
            local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
            local cameraX, cameraY = Map.masterGroup[i]:contentToLocal(tempX, tempY)
            local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
            local cameraLocY = math.ceil(cameraY / Map.map.tileheight)	
            
            if not params.time or params.time < 1 then
                params.time = 1
            end
            local time = math.ceil(params.time / Map.frameTime)
            local levelPosX = params.levelPosX
            local levelPosY = params.levelPosY
            if params.sprite then
                if params.sprite.levelPosX then
                    levelPosX = params.sprite.levelPosX + params.sprite.levelWidth * 0.0 + params.sprite.offsetX 
                    levelPosY = params.sprite.levelPosY + params.sprite.levelHeight * 0.0 + params.sprite.offsetY 
                else
                    levelPosX = params.sprite.x + params.sprite.levelWidth * 0.0 + params.sprite.offsetX 
                    levelPosY = params.sprite.y + params.sprite.levelHeight * 0.0 + params.sprite.offsetY 
                end
            end
            if params.locX then
                levelPosX = params.locX * Map.map.tilewidth - (Map.map.tilewidth / 2)
            end
            if params.locY then
                levelPosY = params.locY * Map.map.tileheight - (Map.map.tileheight / 2)
            end				
            
            if not levelPosX then
                levelPosX = cameraX
            end
            if not levelPosY then
                levelPosY = cameraY
            end
            
            if not Camera.layerWrapX[i] then
                endX = levelPosX
                distanceX = endX - cameraX
                Camera.deltaX[i] = {}
                Camera.deltaX[i] = Camera.easingHelper(distanceX, time, params.transition)
            else
                local tempPosX = levelPosX
                if tempPosX > Map.map.layers[i].width * Map.map.tilewidth - (Map.map.locOffsetX * Map.map.tilewidth) then
                    tempPosX = tempPosX - Map.map.layers[i].width * Map.map.tilewidth
                elseif tempPosX < 1 - (Map.map.locOffsetX * Map.map.tilewidth) then
                    tempPosX = tempPosX + Map.map.layers[i].width * Map.map.tilewidth
                end			
                local tempPosX2 = tempPosX
                if tempPosX > cameraX then
                    tempPosX2 = tempPosX - Map.map.layers[i].width * Map.map.tilewidth
                elseif tempPosX < cameraX then
                    tempPosX2 = tempPosX + Map.map.layers[i].width * Map.map.tilewidth
                end			
                distanceXAcross = math.abs(cameraX - tempPosX)
                distanceXWrap = math.abs(cameraX - tempPosX2)
                if distanceXWrap < distanceXAcross then
                    if tempPosX > cameraX then
                        Map.masterGroup[i].x = (cameraX + Map.map.layers[i].width * Map.map.tilewidth) * -1 * Map.map.layers[i].properties.scaleX
                    elseif tempPosX < cameraX then
                        Map.masterGroup[i].x = (cameraX - Map.map.layers[i].width * Map.map.tilewidth) * -1 * Map.map.layers[i].properties.scaleX
                    end
                    local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                    local cameraX, cameraY = Map.masterGroup[i]:contentToLocal(tempX, tempY)
                    endX = tempPosX
                    distanceX = endX - cameraX
                    Camera.deltaX[i] = {}
                    Camera.deltaX[i] = Camera.easingHelper(distanceX, time, params.transition)
                else
                    endX = levelPosX
                    distanceX = endX - cameraX
                    Camera.deltaX[i] = {}
                    Camera.deltaX[i] = Camera.easingHelper(distanceX, time, params.transition)
                end
            end				
            if not Camera.layerWrapY[i] then
                endY = levelPosY
                distanceY = endY - cameraY
                Camera.deltaY[i] = {}
                Camera.deltaY[i] = Camera.easingHelper(distanceY, time, params.transition)
            else
                local tempPosY = levelPosY
                if tempPosY > Map.map.layers[i].height * Map.map.tileheight then
                    tempPosY = tempPosY - Map.map.layers[i].height * Map.map.tileheight
                elseif tempPosY < 1 then
                    tempPosY = tempPosY + Map.map.layers[i].height * Map.map.tileheight
                end			
                local tempPosY2 = tempPosY
                if tempPosY > cameraY then
                    tempPosY2 = tempPosY - Map.map.layers[i].height * Map.map.tileheight
                elseif tempPosY < cameraY then
                    tempPosY2 = tempPosY + Map.map.layers[i].height * Map.map.tileheight
                end					
                distanceYAcross = math.abs(cameraY - tempPosY)
                distanceYWrap = math.abs(cameraY - tempPosY2)
                if distanceYWrap < distanceYAcross then
                    if tempPosY > cameraY then
                        Map.masterGroup[i].y = (cameraY + Map.map.layers[i].height * Map.map.tileheight) * -1 * Map.map.layers[i].properties.scaleY
                    elseif tempPosY < cameraY then
                        Map.masterGroup[i].y = (cameraY - Map.map.layers[i].height * Map.map.tileheight) * -1 * Map.map.layers[i].properties.scaleY
                    end
                    local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                    local cameraX, cameraY = Map.masterGroup[i]:contentToLocal(tempX, tempY)
                    endY = tempPosY
                    distanceY = endY - cameraY
                    Camera.deltaY[i] = {}
                    Camera.deltaY[i] = Camera.easingHelper(distanceY, time, params.transition)
                else
                    endY = levelPosY
                    distanceY = endY - cameraY
                    Camera.deltaY[i] = {}
                    Camera.deltaY[i] = Camera.easingHelper(distanceY, time, params.transition)
                end
            end				
            Camera.isCameraMoving[i] = true
            if not Camera.refMove then
                Camera.cameraOnComplete[i] = params.onComplete
            end
        end
    end
end

-----------------------------------------------------------

Camera.removeCameraConstraints = function(layer)
    if layer then
        constrainLeft[layer] = nil
        constrainTop[layer] = nil
        constrainRight[layer] = nil
        constrainBottom[layer] = nil
        Map.masterGroup[layer].vars.constrainLayer = nil
    else
        for i = 1, #Map.map.layers, 1 do
            constrainLeft[i] = nil
            constrainTop[i] = nil
            constrainRight[i] = nil
            constrainBottom[i] = nil
        end
    end
end

return Camera