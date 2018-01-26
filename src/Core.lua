local Core = {}

local json = require("json")

local Camera = require("src.Camera")
local Map = require("src.Map")
local Screen = require("src.Screen")
local Sprites = require("src.Sprites")
local PhysicsData = require("src.PhysicsData")
local Light = require("src.Light")

Core.tileAnimsFrozen = false
Core.syncData = {}

local isMoving = {}
local count = 0

--STANDARD ISO VARIABLES
local R45 = math.rad(45)

--LISTENERS
local propertyListeners = {}
local objectDrawListeners = {}

-----------------------------------------------------------

local drawCulledObjects = function(locX, locY, layer)
    if Map.map.layers[layer].extendedObjects then
        if locX < 1 - Map.map.locOffsetX then
            locX = locX + Map.map.layers[layer].width
        end
        if locX > Map.map.layers[layer].width - Map.map.locOffsetX then
            locX = locX - Map.map.layers[layer].width
        end				
        
        if locY < 1 - Map.map.locOffsetY then
            locY = locY + Map.map.layers[layer].height
        end
        if locY > Map.map.layers[layer].height - Map.map.locOffsetY then
            locY = locY - Map.map.layers[layer].height
        end
        
        if Map.map.layers[layer].extendedObjects[locX] and Map.map.layers[layer].extendedObjects[locX][locY] then
            for i = #Map.map.layers[layer].extendedObjects[locX][locY], 1, -1 do
                if Map.map.layers[layer].extendedObjects[locX][locY][i] then
                    local objectLayer = Map.map.layers[layer].extendedObjects[locX][locY][i][1]
                    local objectKey =  Map.map.layers[layer].extendedObjects[locX][locY][i][2]
                    local object = Map.map.layers[objectLayer].objects[objectKey]
                    if not object.properties.wasDrawn then
                        local sprite = drawObject(object, objectLayer, objectKey)
                        sprite.x = object.cullData[1]
                        sprite.y = object.cullData[2]
                        sprite.width = object.cullData[3]
                        sprite.height = object.cullData[4]
                        sprite.roation = object.cullData[5]
                        
                        for j = #object.cullData[6], 1, -1 do
                            local lx = object.cullData[6][j][1]
                            local ly = object.cullData[6][j][2]
                            local index = object.cullData[6][j][3]
                            Map.map.layers[objectLayer].extendedObjects[lx][ly][index] = nil
                        end
                    end
                    Map.map.layers[layer].extendedObjects[locX][locY][i] = nil
                end
            end
        end
    end
end

-----------------------------------------------------------

local drawLargeTile = function(locX, locY, layer, owner)
    
    if locX < 1 - Map.map.locOffsetX then
        locX = locX + Map.map.layers[layer].width
    end
    if locX > Map.map.layers[layer].width - Map.map.locOffsetX then
        locX = locX - Map.map.layers[layer].width
    end				
    
    if locY < 1 - Map.map.locOffsetY then
        locY = locY + Map.map.layers[layer].height
    end
    if locY > Map.map.layers[layer].height - Map.map.locOffsetY then
        locY = locY - Map.map.layers[layer].height
    end
    if Map.map.layers[layer].largeTiles[locX] and Map.map.layers[layer].largeTiles[locX][locY] then
        for i = 1, #Map.map.layers[layer].largeTiles[locX][locY], 1 do
            local frameIndex = Map.map.layers[layer].largeTiles[locX][locY][i][1]
            local lx = Map.map.layers[layer].largeTiles[locX][locY][i][2]
            local ly = Map.map.layers[layer].largeTiles[locX][locY][i][3]
            
            if not Map.tileObjects[layer][lx][ly] then
                Core.updateTile({locX = lx, locY = ly, layer = layer})
            end
        end
    end
end

-----------------------------------------------------------

local cullLargeTile = function(locX, locY, layer, force)
    
    local tlocx, tlocy = locX, locY
    if locX < 1 - Map.map.locOffsetX then
        locX = locX + Map.map.layers[layer].width
    end
    if locX > Map.map.layers[layer].width - Map.map.locOffsetX then
        locX = locX - Map.map.layers[layer].width
    end				
    
    if locY < 1 - Map.map.locOffsetY then
        locY = locY + Map.map.layers[layer].height
    end
    if locY > Map.map.layers[layer].height - Map.map.locOffsetY then
        locY = locY - Map.map.layers[layer].height
    end
    
    if Map.map.layers[layer].largeTiles[locX] and Map.map.layers[layer].largeTiles[locX][locY] then
        for i = 1, #Map.map.layers[layer].largeTiles[locX][locY], 1 do
            local frameIndex = Map.map.layers[layer].largeTiles[locX][locY][i][1]
            local lx = Map.map.layers[layer].largeTiles[locX][locY][i][2]
            local ly = Map.map.layers[layer].largeTiles[locX][locY][i][3]
            
            if Map.tileObjects[layer][lx][ly] then
                local frameIndex = Map.map.layers[layer].world[lx][ly]
                local tileSetIndex = 1
                for i = 1, #Map.map.tilesets, 1 do
                    if frameIndex >= Map.map.tilesets[i].firstgid then
                        tileSetIndex = i
                    else
                        break
                    end
                end
                
                local mT = Map.map.tilesets[tileSetIndex]
                if mT.tilewidth > Map.map.tilewidth or mT.tileheight > Map.map.tileheight  then
                    local width = math.ceil(mT.tilewidth / Map.map.tilewidth)
                    local height = math.ceil(mT.tileheight / Map.map.tileheight)
                    local left, top, right, bottom = lx, ly - height + 1, lx + width - 1, ly
                    if (left > Map.masterGroup[layer].vars.camera[3] or right < Map.masterGroup[layer].vars.camera[1]or
                        top > Map.masterGroup[layer].vars.camera[4] or bottom < Map.masterGroup[layer].vars.camera[2]) or force then
                        if force then
                            Core.updateTile({locX = lx, locY = ly, layer = layer, tile = -1, forceCullLargeTile = true})
                        else
                            Core.updateTile({locX = lx, locY = ly, layer = layer, tile = -1})
                        end
                    end
                end
            end
        end
    end
end

-----------------------------------------------------------

Core.update = function()
    if Camera.touchScroll[1] and Camera.touchScroll[6] then
        local velX = (Camera.touchScroll[2] - Camera.touchScroll[4]) / Map.masterGroup.xScale
        local velY = (Camera.touchScroll[3] - Camera.touchScroll[5]) / Map.masterGroup.yScale
        
        --print(velX, velY)
        Camera.moveCamera(velX, velY)
        Camera.touchScroll[2] = Camera.touchScroll[4]
        Camera.touchScroll[3] = Camera.touchScroll[5]	
    end	
    
    count556 = 0
    local lights = ""
    
    Screen.UpdateScreenBounds()
    
    --PROCESS SPRITES
    if not Sprites.spritesFrozen then
        local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
        local cameraX, cameraY = Map.masterGroup[Map.refLayer]:contentToLocal(tempX, tempY)
        if Map.map.orientation == Map.Type.Isometric then
            local isoPos = Map.isoUntransform2(cameraX, cameraY)
            cameraX = isoPos[1]
            cameraY = isoPos[2]
        end
        local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
        local cameraLocY = math.ceil(cameraY / Map.map.tileheight)			
        Camera.McameraX, Camera.McameraY = cameraX, cameraY
        Camera.McameraLocX = cameraLocX
        Camera.McameraLocY = cameraLocY
        
        local processObject = function(object, lyr)
            if not object.layer then
                object.layer = lyr
            end
            local i = object.layer
            object.level = Map.getLevel(i)				
            if not object.name then
                local spriteName = ""..object.x.."_"..object.y.."_"..i
                if Sprites.sprites[spriteName] then
                    local tempName = spriteName
                    local counter = 1
                    while Sprites.sprites[tempName] do
                        tempName = ""..spriteName..counter
                        counter = counter + 1
                    end
                    spriteName = tempName
                end
                object.name = spriteName
                if not Sprites.sprites[spriteName] then
                    Sprites.sprites[spriteName] = sprite
                end
            end	
            
            if not Light.pointLightSource then
                Light.pointLightSource = object
            end				
            
            if object.lighting then
                local mL = Map.map.layers[i]
                if object.objType ~= 3 then
                    if not object.color then
                        object.color = {1, 1, 1}
                    end
                else
                    for i = 1, object.numChildren, 1 do
                        if object[i]._class then
                            if object.color and not object[i].color then
                                object[i].color = object.color
                            end
                            if not object[i].color then
                                object[i].color = {1, 1, 1}
                            end
                        end
                    end
                end
            end				
            
            if object.offsetX then
                --object.anchorX = (((object.levelWidth or object.width) / 2) - object.offsetX) / (object.levelWidth or object.width)
            end
            if object.offsetY then
                --object.anchorY = (((object.levelHeight or object.height) / 2) - object.offsetY) / (object.levelHeight or object.height)		
            end		
            
            if Map.map.orientation == Map.Type.Isometric then
                --Clear Lighting (ISO)
                if object.light then
                    if not object.light.created then
                        object.light.created = true
                        if not object.light.id then
                            object.light.id = Light.lightIDs
                        end
                        Light.lightIDs = Light.lightIDs + 1						
                        if not object.light.maxRange then
                            local maxRange = object.light.range[1]
                            for l = 1, 3, 1 do
                                if object.light.range[l] > maxRange then
                                    maxRange = object.light.range[l]
                                end
                            end
                            object.light.maxRange = maxRange
                        end		
                        if not object.light.levelPosX then
                            object.light.levelPosX = object.levelPosX or object.x
                            object.light.levelPosY = object.levelPosY or object.y
                        end		
                        if not object.light.alternatorCounter then
                            object.light.alternatorCounter = 1
                        end		
                        if object.light.rays then
                            object.light.areaIndex = 1
                        end		
                        if object.light.layerRelative then
                            object.light.layer = i + object.light.layerRelative
                            if object.light.layer < 1 then
                                object.light.layer = 1
                            end
                            if object.light.layer > #Map.map.layers then
                                object.light.layer = #Map.map.layers
                            end
                        end						
                        if not object.light.layer then
                            object.light.layer = i
                        end						
                        object.light.level = object.level
                        object.light.dynamic = true
                        object.light.area = {}
                        Map.map.lights[object.light.id] = object.light
                    else
                        if Light.lightingData.refreshCounter == 1 then
                            if object.light.rays then
                                object.light.areaIndex = 1
                            end			
                            local length = #object.light.area
                            for i = length, 1, -1 do
                                local locX = object.light.area[i][1]
                                local locY = object.light.area[i][2]
                                object.light.area[i] = nil
                                if Camera.worldWrapX then
                                    if locX < 1 - Map.map.locOffsetX then
                                        locX = locX + Map.map.width
                                    end
                                    if locX > Map.map.width - Map.map.locOffsetX then
                                        locX = locX - Map.map.width
                                    end
                                end
                                if Camera.worldWrapY then
                                    if locY < 1 - Map.map.locOffsetY then
                                        locY = locY + Map.map.height
                                    end
                                    if locY > Map.map.height - Map.map.locOffsetY then
                                        locY = locY - Map.map.height
                                    end
                                end
                                if object.light.layer then
                                    if Map.map.layers[object.light.layer].lighting[locX] and Map.map.layers[object.light.layer].lighting[locX][locY] then
                                        Map.map.layers[object.light.layer].lighting[locX][locY][object.light.id] = nil
                                        Map.map.lightToggle[locX][locY] = tonumber(system.getTimer())
                                    end	
                                end
                            end			
                            if object.toggleRemoveLight then
                                object.light = nil
                                object.toggleRemoveLight = false				
                            end
                        end
                    end
                end
                
                
                if Sprites.movingSprites[object] and not Sprites.holdSprite then
                    local index = Sprites.movingSprites[object]
                    local velX = object.deltaX[index]
                    local velY = object.deltaY[index]
                    Sprites.movingSprites[object] = index - 1					
                    object.levelPosX = object.levelPosX + velX
                    object.levelPosY = object.levelPosY + velY					
                    if Sprites.movingSprites[object] == 0 then
                        Sprites.movingSprites[object] = nil
                        object.deltaX = nil
                        object.deltaY = nil
                        object.isMoving = nil
                        if object.onComplete then
                            local temp = object.onComplete
                            object.onComplete = nil
                            local event = { name = "spriteMoveComplete", sprite = object}
                            temp(event)
                        end
                    end
                end
                
                if Sprites.holdSprite == object then
                    if object.transition then
                        transition.pause(object.transition)
                    end
                    object.paused = true
                elseif object.transition then
                    if object.paused then
                        transition.resume(object.transition)
                        object.paused = nil
                    end
                    if object.transition._transitionHasCompleted then
                        object.transition = nil
                    elseif object.transitionDelta then
                        object.transitionDelta = object.transitionDelta - 1
                    end
                end
                
                --Update Position (ISO)
                local isoPos = Map.isoTransform2(object.levelPosX, object.levelPosY)
                object.x = isoPos[1]
                object.y = isoPos[2]					
                if Camera.layerWrapX[i] and (object.wrapX == nil or object.wrapX == true) then
                    while object.levelPosX < 1 - (Map.map.locOffsetX * Map.map.tilewidth) do
                        object.levelPosX = object.levelPosX + Map.map.layers[i].width * Map.map.tilewidth
                    end
                    while object.levelPosX > Map.map.layers[i].width * Map.map.tilewidth - (Map.map.locOffsetX * Map.map.tilewidth) do
                        object.levelPosX = object.levelPosX - Map.map.layers[i].width * Map.map.tilewidth
                    end						
                    if cameraX - object.levelPosX < Map.map.layers[i].width * Map.map.tilewidth / -2 then
                        --wrap around to the left
                        local vector = Map.isoVector(Map.map.layers[i].width * Map.map.tilewidth * -1, 0)
                        object:translate(vector[1], vector[2])
                    elseif cameraX - object.levelPosX > Map.map.layers[i].width * Map.map.tilewidth / 2 then
                        --wrap around to the right
                        local vector = Map.isoVector(Map.map.layers[i].width * Map.map.tilewidth * 1, 0)
                        object:translate(vector[1], vector[2])
                    end
                end					
                if Camera.layerWrapY[i] and (object.wrapY == nil or object.wrapY == true) then
                    while object.levelPosY < 1 - (Map.map.locOffsetY * Map.map.tileheight) do
                        object.levelPosY = object.levelPosY + Map.map.layers[i].height * Map.map.tileheight
                    end
                    while object.levelPosY > Map.map.layers[i].height * Map.map.tileheight - (Map.map.locOffsetY * Map.map.tileheight) do
                        object.levelPosY = object.levelPosY - Map.map.layers[i].height * Map.map.tileheight
                    end						
                    if cameraY - object.levelPosY < Map.map.layers[i].height * Map.map.tileheight / -2 then
                        --wrap around to the left
                        local vector = Map.isoVector(0, Map.map.layers[i].height * Map.map.tileheight * -1)
                        object:translate(vector[1], vector[2])
                    elseif cameraY - object.levelPosY > Map.map.layers[i].height * Map.map.tileheight / 2 then
                        --wrap around to the right
                        local vector = Map.isoVector(0, Map.map.layers[i].height * Map.map.tileheight * 1)
                        object:translate(vector[1], vector[2])
                    end
                end
                
                --CONSTRAIN TO MAP (ISO)
                if object.constrainToMap then
                    local constraints = object.constrainToMap
                    local pushX, pushY = 0, 0						
                    if constraints[1] then
                        if object.levelPosX < 1 - (Map.map.locOffsetX * Map.map.tilewidth) then
                            pushX = 1 - (Map.map.locOffsetX * Map.map.tilewidth) - object.levelPosX
                        end
                    end
                    if constraints[2] then
                        if object.levelPosY < 1 - (Map.map.locOffsetY * Map.map.tileheight) then
                            pushY = 1 - (Map.map.locOffsetY * Map.map.tileheight) - object.levelPosY
                        end
                    end
                    if constraints[3] then
                        if object.levelPosX > (Map.map.width - Map.map.locOffsetX) * Map.map.tilewidth then
                            pushX = (Map.map.width - Map.map.locOffsetX) * Map.map.tilewidth - object.levelPosX
                        end
                    end
                    if constraints[4] then
                        if object.levelPosY > (Map.map.height - Map.map.locOffsetY) * Map.map.tileheight then
                            pushY = (Map.map.height - Map.map.locOffsetY) * Map.map.tileheight - object.levelPosY
                        end
                    end						
                    object:translate(pushX, pushY)
                end
                
                object.locX = math.ceil(object.levelPosX / Map.map.tilewidth)
                object.locY = math.ceil(object.levelPosY / Map.map.tileheight)
                
                --Handle Offscreen Physics (ISO)
                if PhysicsData.managePhysicsStates and (object.managePhysicsStates == nil or object.managePhysicsStates == true) then
                    if object.bodyType and Map.masterGroup[i].vars.camera then
                        if object.offscreenPhysics then
                            local topLeftX, topLeftY = Map.screenToLoc(object.contentBounds.xMin, object.contentBounds.yMin)
                            local topRightX, topRightY = Map.screenToLoc(object.contentBounds.xMax, object.contentBounds.yMin)
                            local bottomLeftX, bottomLeftY = Map.screenToLoc(object.contentBounds.xMin, object.contentBounds.yMax)
                            local bottomRightX, bottomRightY = Map.screenToLoc(object.contentBounds.xMax, object.contentBounds.yMax)							
                            local left = topLeftX - 1
                            local top = topRightY - 1
                            local right = bottomRightX + 1
                            local bottom = bottomLeftY + 1							
                            if not object.bounds or (object.bounds[1] ~= left or object.bounds[2] ~= top or object.bounds[3] ~= right or object.bounds[4] ~= bottom) then
                                if object.physicsRegion then
                                    for p = 1, #object.physicsRegion, 1 do
                                        local lx = object.physicsRegion[p][1]
                                        local ly = object.physicsRegion[p][2]
                                        if (lx < Map.masterGroup[i].vars.camera[1] or lx > Map.masterGroup[i].vars.camera[3]) or
                                            (ly < Map.masterGroup[i].vars.camera[2] or ly > Map.masterGroup[i].vars.camera[4]) then
                                            Core.updateTile({locX = object.physicsRegion[p][1], locY = object.physicsRegion[p][2], layer = object.physicsRegion[p][3], tile = -1,
                                                owner = object
                                            })
                                        end
                                    end
                                end
                                object.physicsRegion = nil
                                object.physicsRegion = {}
                                for lx = left, right, 1 do
                                    for ly = top, bottom, 1 do
                                        for j = 1, #Map.map.layers, 1 do
                                            if (lx < Map.masterGroup[j].vars.camera[1] or lx > Map.masterGroup[j].vars.camera[3]) or
                                                (ly < Map.masterGroup[j].vars.camera[2] or ly > Map.masterGroup[j].vars.camera[4]) then
                                                local owner = Core.updateTile({locX = lx, locY = ly, layer = j, onlyPhysics = false, owner = object})
                                                if owner then
                                                    object.physicsRegion[#object.physicsRegion + 1] = {lx, ly, j}
                                                end
                                            end
                                        end
                                    end
                                end
                                object.bounds = {left, top, right, bottom}
                            end
                        else
                            local locX = math.ceil(object.levelPosX / Map.map.tilewidth)
                            local locY = math.ceil(object.levelPosY / Map.map.tilewidth)
                            if (locX < Map.masterGroup[i].vars.camera[1] or locX > Map.masterGroup[i].vars.camera[3]) or
                                (locY < Map.masterGroup[i].vars.camera[2] or locY > Map.masterGroup[i].vars.camera[4]) then
                                if not object.properties or not object.properties.isBodyActive then
                                    object.isBodyActive = false
                                end
                            elseif (locX <= Map.masterGroup[i].vars.camera[1] or locX >= Map.masterGroup[i].vars.camera[3]) or
                                (locY <= Map.masterGroup[i].vars.camera[2] or locY >= Map.masterGroup[i].vars.camera[4]) then
                                if not object.properties or not object.properties.isAwake then
                                    object.isAwake = false
                                end
                                if not object.properties or not object.properties.isBodyActive then
                                    object.isBodyActive = true
                                end
                            else
                                if not object.properties or not object.properties.isAwake then
                                    object.isAwake = true
                                end
                                if not object.properties or not object.properties.isBodyActive then
                                    object.isBodyActive = true
                                end
                            end
                        end
                    end
                end
                
                --Sort Sprites (ISO)
                if object.locX >= 1 and object.locY >= 1 and not object.isMoving then
                    if Map.isoSort == 1 then
                        local temp = object.locX + object.locY - 1
                        if temp > Map.map.height + Map.map.width then
                            temp = Map.map.height + Map.map.width
                        end
                        if temp ~= object.row then
                            Map.masterGroup[i][temp]:insert(object)
                        end
                    end
                end
                
                --Apply Lighting to Non-Light Objects, Trigger Events (ISO)
                if object.lighting then
                    if Camera.enableLighting then
                        object.litBy = {}
                        local locX = object.locX
                        local locY = object.locY
                        local mapLayerFalloff = Map.map.properties.lightLayerFalloff
                        local mapLevelFalloff = Map.map.properties.lightLevelFalloff
                        local red, green, blue = Map.map.layers[i].redLight, Map.map.layers[i].greenLight, Map.map.layers[i].blueLight
                        for k = 1, #Map.map.layers, 1 do
                            if Map.map.layers[k].lighting[locX] then
                                if Map.map.layers[k].lighting[locX][locY] then
                                    local temp = Map.map.layers[k].lighting[locX][locY]
                                    local tempSources = {}
                                    for key,value in pairs(object.prevLitBy) do
                                        tempSources[key] = true
                                    end
                                    for key,value in pairs(temp) do
                                        local levelDiff = math.abs(Map.getLevel(i) - Map.map.lights[key].level)
                                        local layerDiff = math.abs(i - Map.map.lights[key].layer)							
                                        local layerFalloff, levelFalloff
                                        if Map.map.lights[key].layerFalloff then
                                            layerFalloff = Map.map.lights[key].layerFalloff
                                        else
                                            layerFalloff = mapLayerFalloff
                                        end							
                                        if Map.map.lights[key].levelFalloff then
                                            levelFalloff = Map.map.lights[key].levelFalloff
                                        else
                                            levelFalloff = mapLevelFalloff
                                        end							
                                        local tR = temp[key].light[1] - (levelDiff * levelFalloff[1]) - (layerDiff * layerFalloff[1])
                                        local tG = temp[key].light[2] - (levelDiff * levelFalloff[2]) - (layerDiff * layerFalloff[2])
                                        local tB = temp[key].light[3] - (levelDiff * levelFalloff[3]) - (layerDiff * layerFalloff[3])							
                                        if object.lightingListeners[key] then
                                            local event = { name = key, target = object, source = Map.map.lights[key], light = {tR, tG, tB}}
                                            if not object.prevLitBy[key] then
                                                object.prevLitBy[key] = true
                                                event.phase = "began"
                                            else
                                                event.phase = "maintained"
                                            end
                                            object:dispatchEvent( event )
                                            tempSources[key] = nil
                                        end							
                                        if tR > red then
                                            red = tR
                                        end
                                        if tG > green then
                                            green = tG
                                        end
                                        if tB > blue then
                                            blue = tB
                                        end							
                                        object.litBy[#object.litBy + 1] = key							
                                    end
                                    for key,value in pairs(tempSources) do
                                        if object.lightingListeners[key] then
                                            object.prevLitBy[key] = nil
                                            local event = { name = key, target = object, source = Map.map.lights[key], light = {tR, tG, tB}}
                                            event.phase = "ended"
                                            object:dispatchEvent( event )
                                        end
                                    end
                                else						
                                    for key,value in pairs(object.prevLitBy) do
                                        if object.lightingListeners[key] and not Map.map.lights[key] then
                                            object.prevLitBy[key] = nil
                                            local event = { name = key, target = object, source = Map.map.lights[key], light = {tR, tG, tB}}
                                            event.phase = "ended"
                                            object:dispatchEvent( event )
                                        elseif object.lightingListeners[key] and Map.map.lights[key].layer == k then
                                            object.prevLitBy[key] = nil
                                            local event = { name = key, target = object, source = Map.map.lights[key], light = {tR, tG, tB}}
                                            event.phase = "ended"
                                            object:dispatchEvent( event )
                                        end
                                    end						
                                end
                            end
                        end
                        if object.objType < 3 then
                            object:setFillColor(red * object.color[1], green * object.color[2], blue * object.color[3])
                        elseif object.objType == 3 then
                            for i = 1, object.numChildren, 1 do
                                if object[i]._class then
                                    object[i]:setFillColor(red * object[i].color[1], green * object[i].color[2], blue * object[i].color[3])
                                end
                            end
                        elseif object.objType == 4 then
                            for i = 1, object.numChildren, 1 do
                                if object[i]._class then
                                    object[i]:setStrokeColor(red * object[i].color[1], green * object[i].color[2], blue * object[i].color[3])
                                end
                            end
                        end
                    else
                        if object.objType < 3 then
                            local mL = Map.map.layers[i]
                            object:setFillColor(mL.redLight * object.color[1], mL.greenLight * object.color[2], mL.blueLight * object.color[3])
                        elseif object.objType == 3 then
                            local mL = Map.map.layers[i]
                            for i = 1, object.numChildren, 1 do
                                if object[i]._class then
                                    object[i]:setFillColor(mL.redLight * object[i].color[1], mL.greenLight * object[i].color[2], mL.blueLight * object[i].color[3])
                                end
                            end
                        elseif object.objType == 4 then
                            local mL = Map.map.layers[i]
                            for i = 1, object.numChildren, 1 do
                                if object[i]._class then
                                    object[i]:setStrokeColor(mL.redLight * object[i].color[1], mL.greenLight * object[i].color[2], mL.blueLight * object[i].color[3])
                                end
                            end
                        end
                    end
                end
                
                --Cast Light (ISO)
                if Camera.enableLighting and object.light then
                    if Light.lightingData.refreshCounter == 1 then
                        object.light.levelPosX = object.levelPosX
                        object.light.levelPosY = object.levelPosY
                    end					
                    if Light.lightingData.refreshCounter == 1 then
                        if object.levelPosX > 0 - (Map.map.locOffsetX * Map.map.tilewidth) and object.levelPosX <= (Map.map.width - Map.map.locOffsetX) * Map.map.tilewidth then
                            if object.levelPosY > 0 - (Map.map.locOffsetY * Map.map.tileheight) and object.levelPosY <= (Map.map.height - Map.map.locOffsetY) * Map.map.tileheight then
                                if object.light.rays then
                                    for k = 1, #object.light.rays, 1 do
                                        Light.processLightRay(object.light.layer, object.light, object.light.rays[k])
                                    end
                                else								
                                    Light.processLight(object.light.layer, object.light)									
                                    local length = #object.light.area
                                    local tempML = {}
                                    local oLx = object.light.locX
                                    local oLy = object.light.locY
                                    local oLl = object.light.layer
                                    local oLi = object.light.id
                                    local mL = Map.map.layers
                                    for i = length, 1, -1 do
                                        local locX = object.light.area[i][1]
                                        local locY = object.light.area[i][2]
                                        local locXt = locX
                                        local locYt = locY						
                                        if Camera.worldWrapX then
                                            if locX < 1 - Map.map.locOffsetX then
                                                locX = locX + Map.map.width
                                            end
                                            if locX > Map.map.width - Map.map.locOffsetX then
                                                locX = locX - Map.map.width
                                            end
                                        end
                                        if Camera.worldWrapY then
                                            if locY < 1 - Map.map.locOffsetY then
                                                locY = locY + Map.map.height
                                            end
                                            if locY > Map.map.height - Map.map.locOffsetY then
                                                locY = locY - Map.map.height
                                            end
                                        end						
                                        local neighbor1 = {0, 0, 0}
                                        local neighbor2 = {0, 0, 0}										
                                        if locX ~= oLx and locY ~= oLy and Map.map.lightingData[mL[oLl].world[locX][locY]]then											
                                            if locXt > oLx and locYt < oLy then
                                                --top right
                                                if oLl then
                                                    if mL[oLl].lighting[locX - 1] and mL[oLl].lighting[locX][locY] then
                                                        if not Map.map.lightingData[mL[oLl].world[locX - 1][locY]] then
                                                            if mL[oLl].lighting[locX - 1][locY] then
                                                                if mL[oLl].lighting[locX - 1][locY][oLi] then
                                                                    neighbor1 = mL[oLl].lighting[locX - 1][locY][oLi].light
                                                                    neighbor1[4] = locX - 1
                                                                    neighbor1[5] = locY
                                                                end
                                                            end
                                                        end
                                                    end	
                                                    if mL[oLl].lighting[locX] and mL[oLl].lighting[locX][locY + 1] then
                                                        if not Map.map.lightingData[mL[oLl].world[locX][locY + 1]] then
                                                            if mL[oLl].lighting[locX][locY + 1] then
                                                                if mL[oLl].lighting[locX][locY + 1][oLi] then
                                                                    neighbor2 = mL[oLl].lighting[locX][locY + 1][oLi].light
                                                                    neighbor2[4] = locX
                                                                    neighbor2[5] = locY + 1
                                                                end
                                                            end
                                                        end
                                                    end	
                                                end
                                            elseif locXt > oLx and locYt > oLy then
                                                --bottom right
                                                if oLl then
                                                    if mL[oLl].lighting[locX - 1] and mL[oLl].lighting[locX][locY] then
                                                        if not Map.map.lightingData[mL[oLl].world[locX - 1][locY]] then
                                                            if mL[oLl].lighting[locX - 1][locY] then
                                                                if mL[oLl].lighting[locX - 1][locY][oLi] then
                                                                    neighbor1 = mL[oLl].lighting[locX - 1][locY][oLi].light
                                                                    neighbor1[4] = locX - 1
                                                                    neighbor1[5] = locY
                                                                end
                                                            end
                                                        end
                                                    end	
                                                    if mL[oLl].lighting[locX] and mL[oLl].lighting[locX][locY - 1] then
                                                        if not Map.map.lightingData[mL[oLl].world[locX][locY - 1]] then
                                                            if mL[oLl].lighting[locX][locY - 1] then
                                                                if mL[oLl].lighting[locX][locY - 1][oLi] then
                                                                    neighbor2 = mL[oLl].lighting[locX][locY - 1][oLi].light
                                                                    neighbor2[4] = locX
                                                                    neighbor2[5] = locY - 1
                                                                end
                                                            end
                                                        end
                                                    end	
                                                end
                                            elseif locXt < oLx and locYt > oLy then
                                                --bottom left
                                                if oLl then
                                                    if mL[oLl].lighting[locX + 1] and mL[oLl].lighting[locX][locY] then
                                                        if not Map.map.lightingData[mL[oLl].world[locX + 1][locY]] then
                                                            if mL[oLl].lighting[locX + 1][locY] then
                                                                if mL[oLl].lighting[locX + 1][locY][oLi] then
                                                                    neighbor1 = mL[oLl].lighting[locX + 1][locY][oLi].light
                                                                    neighbor1[4] = locX + 1
                                                                    neighbor1[5] = locY
                                                                end
                                                            end
                                                        end
                                                    end	
                                                    if mL[oLl].lighting[locX] and mL[oLl].lighting[locX][locY - 1] then
                                                        if not Map.map.lightingData[mL[oLl].world[locX][locY - 1]] then
                                                            if mL[oLl].lighting[locX][locY - 1] then
                                                                if mL[oLl].lighting[locX][locY - 1][oLi] then
                                                                    neighbor2 = mL[oLl].lighting[locX][locY - 1][oLi].light
                                                                    neighbor2[4] = locX
                                                                    neighbor2[5] = locY - 1
                                                                end
                                                            end
                                                        end
                                                    end	
                                                end
                                            elseif locXt < oLx and locYt < oLy then
                                                --top left
                                                if oLl then
                                                    if mL[oLl].lighting[locX + 1] and mL[oLl].lighting[locX][locY] then
                                                        if not Map.map.lightingData[mL[oLl].world[locX + 1][locY]] then
                                                            if mL[oLl].lighting[locX + 1][locY] then
                                                                if mL[oLl].lighting[locX + 1][locY][oLi] then
                                                                    neighbor1 = mL[oLl].lighting[locX + 1][locY][oLi].light
                                                                    neighbor1[4] = locX + 1
                                                                    neighbor1[5] = locY
                                                                end
                                                            end
                                                        end
                                                    end	
                                                    if mL[oLl].lighting[locX] and mL[oLl].lighting[locX][locY + 1] then
                                                        if not Map.map.lightingData[mL[oLl].world[locX][locY + 1]] then
                                                            if mL[oLl].lighting[locX][locY + 1] then
                                                                if mL[oLl].lighting[locX][locY + 1][oLi] then
                                                                    neighbor2 = mL[oLl].lighting[locX][locY + 1][oLi].light
                                                                    neighbor2[4] = locX
                                                                    neighbor2[5] = locY + 1
                                                                end
                                                            end
                                                        end
                                                    end	
                                                end
                                            end						
                                            local neighbor						
                                            if neighbor1[1] + neighbor1[2] + neighbor1[3] > neighbor2[1] + neighbor2[2] + neighbor2[3] then
                                                neighbor = neighbor1
                                            else
                                                neighbor = neighbor2
                                            end							
                                            if neighbor[1] + neighbor[2] + neighbor[3] > 0 then
                                                if math.abs( (neighbor[1] + neighbor[2] + neighbor[3]) - (mL[oLl].lighting[locX][locY][oLi].light[1] +
                                                    mL[oLl].lighting[locX][locY][oLi].light[2] + 
                                                    mL[oLl].lighting[locX][locY][oLi].light[3]) ) > 
                                                    (object.light.falloff[1] + object.light.falloff[2] + object.light.falloff[3]) * 1.5 then
                                                    local distance = math.sqrt( ((locXt - oLx) * (locXt - oLx)) + 
                                                    ((locYt - oLy) * (locYt - oLy))  )								
                                                    local red = object.light.source[1] - (object.light.falloff[1] * distance)
                                                    local green = object.light.source[2] - (object.light.falloff[2] * distance)
                                                    local blue = object.light.source[3] - (object.light.falloff[3] * distance)
                                                    tempML[#tempML + 1] = {locX, locY, red, green, blue}
                                                end
                                            end
                                        end						
                                    end					
                                    for i = 1, #tempML, 1 do
                                        mL[oLl].lighting[tempML[i][1]][tempML[i][2]][oLi].light = {tempML[i][3], 
                                        tempML[i][4], tempML[i][5]}
                                    end
                                end
                            end
                        end				
                    end	
                    if object.lighting then
                        if object.objType < 3 then
                            local oL = object.light.source
                            object:setFillColor(oL[1]*object.color[1], oL[2]*object.color[2], oL[3]*object.color[3])
                        elseif object.objType == 3 then
                            local oL = object.light.source
                            for i = 1, object.numChildren, 1 do
                                if object[i]._class then
                                    object[i]:setFillColor(oL[1]*object[i].color[1], oL[2]*object[i].color[2], oL[3]*object[i].color[3])
                                end
                            end
                        elseif object.objType == 4 then
                            local oL = object.light.source
                            for i = 1, object.numChildren, 1 do
                                if object[i]._class then
                                    object[i]:setStrokeColor(oL[1]*object[i].color[1], oL[2]*object[i].color[2], oL[3]*object[i].color[3])
                                end
                            end
                        end
                    end
                end
                ------
            else
                --Clear Lighting
                if object.light then
                    if not object.light.created then
                        object.light.created = true
                        if not object.light.id then
                            object.light.id = Light.lightIDs
                        end
                        Light.lightIDs = Light.lightIDs + 1						
                        if not object.light.maxRange then
                            local maxRange = object.light.range[1]
                            for l = 1, 3, 1 do
                                if object.light.range[l] > maxRange then
                                    maxRange = object.light.range[l]
                                end
                            end
                            object.light.maxRange = maxRange
                        end		
                        if not object.light.levelPosX then
                            object.light.levelPosX = object.levelPosX or object.x
                            object.light.levelPosY = object.levelPosY or object.y
                        end		
                        if not object.light.alternatorCounter then
                            object.light.alternatorCounter = 1
                        end		
                        if object.light.rays then
                            object.light.areaIndex = 1
                        end		
                        if object.light.layerRelative then
                            object.light.layer = i + object.light.layerRelative
                            if object.light.layer < 1 then
                                object.light.layer = 1
                            end
                            if object.light.layer > #Map.map.layers then
                                object.light.layer = #Map.map.layers
                            end
                        end						
                        if not object.light.layer then
                            object.light.layer = i
                        end						
                        object.light.level = object.level
                        object.light.dynamic = true
                        object.light.area = {}
                        Map.map.lights[object.light.id] = object.light
                    else
                        if Light.lightingData.refreshCounter == 1 then
                            if object.light.rays then
                                object.light.areaIndex = 1
                            end			
                            local length = #object.light.area
                            for i = length, 1, -1 do
                                local locX = object.light.area[i][1]
                                local locY = object.light.area[i][2]
                                object.light.area[i] = nil
                                if Camera.worldWrapX then
                                    if locX < 1 - Map.map.locOffsetX then
                                        locX = locX + Map.map.width
                                    end
                                    if locX > Map.map.width - Map.map.locOffsetX then
                                        locX = locX - Map.map.width
                                    end
                                end
                                if Camera.worldWrapY then
                                    if locY < 1 - Map.map.locOffsetY then
                                        locY = locY + Map.map.height
                                    end
                                    if locY > Map.map.height - Map.map.locOffsetY then
                                        locY = locY - Map.map.height
                                    end
                                end
                                if object.light.layer then
                                    if Map.map.layers[object.light.layer].lighting[locX] and Map.map.layers[object.light.layer].lighting[locX][locY] then
                                        Map.map.layers[object.light.layer].lighting[locX][locY][object.light.id] = nil
                                        Map.map.lightToggle[locX][locY] = tonumber(system.getTimer())
                                    end	
                                end
                            end			
                            if object.toggleRemoveLight then
                                object.light = nil
                                object.toggleRemoveLight = false				
                            end
                        end
                    end
                end
                
                
                if Sprites.movingSprites[object] and not Sprites.holdSprite then
                    local index = Sprites.movingSprites[object]
                    local velX = object.deltaX[index]
                    local velY = object.deltaY[index]
                    Sprites.movingSprites[object] = index - 1						
                    object:translate(velX, velY)						
                    if Sprites.movingSprites[object] == 0 then
                        Sprites.movingSprites[object] = nil
                        object.deltaX = nil
                        object.deltaY = nil
                        object.isMoving = nil
                        if object.onComplete then
                            local temp = object.onComplete
                            object.onComplete = nil
                            local event = { name = "spriteMoveComplete", sprite = object}
                            temp(event)
                        end
                    end
                end
                
                if Sprites.holdSprite == object then
                    if object.transition then
                        transition.pause(object.transition)
                    end
                    object.paused = true
                elseif object.transition then
                    if object.paused then
                        transition.resume(object.transition)
                        object.paused = nil
                    end
                    if object.transition._transitionHasCompleted then
                        object.transition = nil
                    elseif object.transitionDelta then
                        object.transitionDelta = object.transitionDelta - 1
                    end
                end
                
                --Update Position
                object.levelPosX = object.x
                object.levelPosY = object.y				
                if Camera.layerWrapX[i] and (object.wrapX == nil or object.wrapX == true) then
                    while object.levelPosX < 1 - (Map.map.locOffsetY * Map.map.tileheight) do
                        object.levelPosX = object.levelPosX + Map.map.layers[i].width * Map.map.tilewidth
                    end
                    while object.levelPosX > Map.map.layers[i].width * Map.map.tilewidth - (Map.map.locOffsetY * Map.map.tileheight) do
                        object.levelPosX = object.levelPosX - Map.map.layers[i].width * Map.map.tilewidth
                    end				
                    if cameraX - object.x < Map.map.layers[i].width * Map.map.tilewidth / -2 then
                        --wrap around to the left
                        object.x = object.x - Map.map.layers[i].width * Map.map.tilewidth
                    elseif cameraX - object.x > Map.map.layers[i].width * Map.map.tilewidth / 2 then
                        --wrap around to the right
                        object.x = object.x + Map.map.layers[i].width * Map.map.tilewidth
                    end
                end
                if Camera.layerWrapY[i] and (object.wrapY == nil or object.wrapY == true) then
                    while object.levelPosY < 1 - (Map.map.locOffsetY * Map.map.tileheight) do
                        object.levelPosY = object.levelPosY + Map.map.layers[i].height * Map.map.tileheight
                    end
                    while object.levelPosY > Map.map.layers[i].height * Map.map.tileheight - (Map.map.locOffsetY * Map.map.tileheight) do
                        object.levelPosY = object.levelPosY - Map.map.layers[i].height * Map.map.tileheight
                    end					
                    if cameraY - object.y < Map.map.layers[i].height * Map.map.tileheight / -2 then
                        --wrap around to the left
                        object.y = object.y - Map.map.layers[i].height * Map.map.tileheight
                    elseif cameraY - object.y > Map.map.layers[i].height * Map.map.tileheight / 2 then
                        --wrap around to the right
                        object.y = object.y + Map.map.layers[i].height * Map.map.tileheight
                    end
                end
                
                --CONSTRAIN TO MAP
                if object.constrainToMap then
                    local constraints = object.constrainToMap
                    local pushX, pushY = 0, 0
                    if constraints[1] then
                        if object.levelPosX < 1 - (Map.map.locOffsetX * Map.map.tilewidth) then
                            pushX = 1 - (Map.map.locOffsetX * Map.map.tilewidth) - object.levelPosX
                        end
                    end
                    if constraints[2] then
                        if object.levelPosY < 1 - (Map.map.locOffsetY * Map.map.tileheight) then
                            pushY = 1 - (Map.map.locOffsetY * Map.map.tileheight) - object.levelPosY
                        end
                    end
                    if constraints[3] then
                        if object.levelPosX > (Map.map.width - Map.map.locOffsetX) * Map.map.tilewidth then
                            pushX = (Map.map.width - Map.map.locOffsetX) * Map.map.tilewidth - object.levelPosX
                        end
                    end
                    if constraints[4] then
                        if object.levelPosY > (Map.map.height - Map.map.locOffsetY) * Map.map.tileheight then
                            pushY = (Map.map.height - Map.map.locOffsetY) * Map.map.tileheight - object.levelPosY
                        end
                    end
                    object:translate(pushX, pushY)
                end
                
                object.locX = math.ceil(object.levelPosX / Map.map.tilewidth)
                object.locY = math.ceil(object.levelPosY / Map.map.tileheight)
                
                --Handle Offscreen Physics
                --print(object.name, PhysicsData.managePhysicsStates, object.managePhysicsStates, object.managePhysicsStates)
                if PhysicsData.managePhysicsStates and (object.managePhysicsStates == nil or object.managePhysicsStates == true) then
                    if object.bodyType and Map.masterGroup[i].vars.camera then
                        local tempX, tempY = Map.masterGroup.parent:localToContent(object.contentBounds.xMin, object.contentBounds.yMin)
                        local leftTop = {Map.masterGroup[i]:contentToLocal(tempX, tempY)}							
                        tempX, tempY = Map.masterGroup.parent:localToContent(object.contentBounds.xMax, object.contentBounds.yMax)
                        local rightBottom = {Map.masterGroup[i]:contentToLocal(tempX, tempY)}							
                        local left = math.ceil(leftTop[1] / Map.map.tilewidth) - 1
                        local top = math.ceil(leftTop[2] / Map.map.tileheight) - 1
                        local right = math.ceil(rightBottom[1] / Map.map.tilewidth) + 1
                        local bottom = math.ceil(rightBottom[2] / Map.map.tileheight) + 1
                        
                        if object.bodyType ~= "static" then
                            if object.bounds and object.physicsRegion and #object.physicsRegion > 0 then
                                for p = #object.physicsRegion, 1, -1 do
                                    local lx = object.physicsRegion[p][1]
                                    local ly = object.physicsRegion[p][2]
                                    local layer = object.physicsRegion[p][3]
                                    if lx < object.bounds[1] or lx > object.bounds[3] or ly < object.bounds[2] or ly > object.bounds[4] then
                                        if lx < Map.masterGroup[i].vars.camera[1] or lx > Map.masterGroup[i].vars.camera[3] or
                                            ly < Map.masterGroup[i].vars.camera[2] or ly > Map.masterGroup[i].vars.camera[4] then
                                            Core.updateTile({locX = lx, locY = ly, layer = layer, tile = -1, owner = object})
                                            --cullLargeTile(lx, ly, layer, nil, object)
                                            table.remove(object.physicsRegion, p)
                                        end
                                    end
                                    
                                end
                            else
                                object.physicsRegion = {}
                            end
                            if not object.bounds or object.bounds[1] ~= left or object.bounds[2] ~= top or object.bounds[3] ~= right or object.bounds[4] ~= bottom then
                                object.bounds = {left, top, right, bottom}
                            end
                            for lx = left, right, 1 do
                                for ly = top, bottom, 1 do
                                    for j = 1, #Map.map.layers, 1 do
                                        if lx < 1 - Map.map.locOffsetX then
                                            lx = lx + Map.map.layers[j].width
                                        end
                                        if lx > Map.map.layers[j].width - Map.map.locOffsetX then
                                            lx = lx - Map.map.layers[j].width
                                        end				
                                        
                                        if ly < 1 - Map.map.locOffsetY then
                                            ly = ly + Map.map.layers[j].height
                                        end
                                        if ly > Map.map.layers[j].height - Map.map.locOffsetY then
                                            ly = ly - Map.map.layers[j].height
                                        end
                                        if not Map.tileObjects[j][lx][ly] and Map.map.layers[j].world[lx][ly] ~= 0 then
                                            local owner = Core.updateTile({locX = lx, locY = ly, layer = j, onlyPhysics = true, owner = object})
                                            if owner then
                                                object.physicsRegion[#object.physicsRegion + 1] = {lx, ly, j}
                                            end
                                            
                                        end
                                        
                                        local tX, tY = lx, ly
                                        if tX < 1 - Map.map.locOffsetX then
                                            tX = tX + Map.map.layers[j].width
                                        end
                                        if tX > Map.map.layers[j].width - Map.map.locOffsetX then
                                            tX = tX - Map.map.layers[j].width
                                        end				
                                        
                                        if tY < 1 - Map.map.locOffsetY then
                                            tY = tY + Map.map.layers[j].height
                                        end
                                        if tY > Map.map.layers[j].height - Map.map.locOffsetY then
                                            tY = tY - Map.map.layers[j].height
                                        end
                                        
                                        if Map.map.layers[j].largeTiles[tX] and Map.map.layers[j].largeTiles[tX][tY] then
                                            for i = 1, #Map.map.layers[j].largeTiles[tX][tY], 1 do
                                                local frameIndex = Map.map.layers[j].largeTiles[tX][tY][i][1]
                                                local ltx = Map.map.layers[j].largeTiles[tX][tY][i][2]
                                                local lty = Map.map.layers[j].largeTiles[tX][tY][i][3]
                                                
                                                if not Map.tileObjects[j][ltx][lty] then
                                                    local owner = Core.updateTile({locX = ltx, locY = lty, layer = j, onlyPhysics = true, owner = object})
                                                    if owner then
                                                        object.physicsRegion[#object.physicsRegion + 1] = {ltx, lty, j}
                                                    end
                                                end
                                            end
                                        end
                                        
                                        drawCulledObjects(lx, ly, j)
                                    end
                                end
                            end
                        end
                        if not object.offscreenPhysics then
                            local tempX, tempY = Map.masterGroup.parent:localToContent(object.contentBounds.xMin, object.contentBounds.yMin)
                            local leftTop = {Map.masterGroup[i]:contentToLocal(tempX, tempY)}							
                            tempX, tempY = Map.masterGroup.parent:localToContent(object.contentBounds.xMax, object.contentBounds.yMax)
                            local rightBottom = {Map.masterGroup[i]:contentToLocal(tempX, tempY)}							
                            local left = math.ceil(leftTop[1] / Map.map.tilewidth)
                            local top = math.ceil(leftTop[2] / Map.map.tileheight)
                            local right = math.ceil(rightBottom[1] / Map.map.tilewidth)
                            local bottom = math.ceil(rightBottom[2] / Map.map.tileheight)
                            
                            if left < Map.masterGroup[i].vars.camera[1] and right > Map.masterGroup[i].vars.camera[1] then
                                left = Map.masterGroup[i].vars.camera[1]
                            end
                            if top < Map.masterGroup[i].vars.camera[2] and bottom > Map.masterGroup[i].vars.camera[2] then
                                top = Map.masterGroup[i].vars.camera[2]
                            end
                            if right < Map.masterGroup[i].vars.camera[3] and left > Map.masterGroup[i].vars.camera[3] then
                                right = Map.masterGroup[i].vars.camera[3]
                            end
                            if bottom > Map.masterGroup[i].vars.camera[4] and top < Map.masterGroup[i].vars.camera[4] then
                                bottom = Map.masterGroup[i].vars.camera[4]
                            end
                            
                            if (left >= Map.masterGroup[i].vars.camera[1] and left <= Map.masterGroup[i].vars.camera[3] and
                                top >= Map.masterGroup[i].vars.camera[2] and top <= Map.masterGroup[i].vars.camera[4]) or
                                
                                (right >= Map.masterGroup[i].vars.camera[1] and right <= Map.masterGroup[i].vars.camera[3] and
                                top >= Map.masterGroup[i].vars.camera[2] and top <= Map.masterGroup[i].vars.camera[4]) or
                                
                                (left >= Map.masterGroup[i].vars.camera[1] and left <= Map.masterGroup[i].vars.camera[3] and
                                bottom >= Map.masterGroup[i].vars.camera[2] and bottom <= Map.masterGroup[i].vars.camera[4]) or
                                
                                (right >= Map.masterGroup[i].vars.camera[1] and right <= Map.masterGroup[i].vars.camera[3] and
                                bottom >= Map.masterGroup[i].vars.camera[2] and bottom <= Map.masterGroup[i].vars.camera[4])then
                                --onscreen
                                if not object.properties or not object.properties.isAwake then
                                    object.isAwake = true
                                end
                                if not object.properties or not object.properties.isBodyActive then
                                    object.isBodyActive = true
                                end
                            elseif (left >= Map.masterGroup[i].vars.camera[1] - 1 and left <= Map.masterGroup[i].vars.camera[3] + 1 and
                                top >= Map.masterGroup[i].vars.camera[2] - 1 and top <= Map.masterGroup[i].vars.camera[4] + 1) or
                                
                                (right >= Map.masterGroup[i].vars.camera[1] - 1 and right <= Map.masterGroup[i].vars.camera[3] + 1 and
                                top >= Map.masterGroup[i].vars.camera[2] - 1 and top <= Map.masterGroup[i].vars.camera[4] + 1) or
                                
                                (left >= Map.masterGroup[i].vars.camera[1] - 1 and left <= Map.masterGroup[i].vars.camera[3] + 1 and
                                bottom >= Map.masterGroup[i].vars.camera[2] - 1 and bottom <= Map.masterGroup[i].vars.camera[4] + 1) or
                                
                                (right >= Map.masterGroup[i].vars.camera[1] - 1 and right <= Map.masterGroup[i].vars.camera[3] + 1 and
                                bottom >= Map.masterGroup[i].vars.camera[2] - 1 and bottom <= Map.masterGroup[i].vars.camera[4] + 1)then
                                --edge
                                if not object.properties or not object.properties.isAwake then
                                    object.isAwake = false
                                end
                                if not object.properties or not object.properties.isBodyActive then
                                    object.isBodyActive = true
                                end
                            else
                                --offscreen
                                if not object.properties or not object.properties.isBodyActive then
                                    object.isBodyActive = false
                                end
                            end
                            
                            
                        end
                    end
                end
                
                --Sort Sprites
                if object.sortSprite and Sprites.enableSpriteSorting then
                    local adjustedPosition = object.levelPosY + ((Map.map.locOffsetY - 1) * Map.map.tileheight)
                    
                    --local tempY =math.ceil(math.round(object.levelPosY) / (Map.map.tileheight / Map.spriteSortResolution))	
                    --print(object.levelPosY, adjustedPosition)		
                    
                    local tempY =math.ceil(math.round(adjustedPosition) / (Map.map.tileheight / Map.spriteSortResolution))	
                    --print(tempY)
                    if tempY > (Map.map.layers[i].height * Map.spriteSortResolution) then
                        while tempY > Map.map.layers[i].height do
                            tempY = tempY - (Map.map.layers[i].height * Map.spriteSortResolution)
                        end
                    elseif tempY < 1 then
                        while tempY < 1 do
                            tempY = tempY + (Map.map.layers[i].height * Map.spriteSortResolution)
                        end
                    end		
                    if not object.depthBuffer or object.depthBuffer ~= tempY then
                        if object.name == "player" then
                            --print("this", object.name, tempY, Map.masterGroup[i][tempY])
                        end
                        for key,value in pairs( Map.masterGroup[i][2][tempY]) do
                            --print(key,value)
                        end
                        --print(Map.masterGroup[i], Map.masterGroup[i][2], tempY, Map.masterGroup[i][2].numChildren)
                        Map.masterGroup[i][2][tempY]:insert(object)
                    end
                    object.depthBuffer = tempY						
                    if object.sortSpriteOnce then
                        object.sortSprite = false
                    end		
                end
                
                --Apply HeightMap
                if Map.enableHeightMaps then
                    if object.heightMap then
                        if not object.nativeWidth then
                            object.nativeWidth = object.width
                            object.nativeHeight = object.height
                        end
                        local hM = object.heightMap
                        local offsetX = object.nativeWidth / 2
                        local offsetY = object.nativeHeight / 2
                        local x = object.x
                        local y = object.y
                        local oP = object.path
                        oP["x1"] = (((cameraX - (x - offsetX)) * (1 + (hM[1] or 0))) - (cameraX - (x - offsetX))) * -1
                        oP["y1"] = (((cameraY - (y - offsetY)) * (1 + (hM[1] or 0))) - (cameraY - (y - offsetY))) * -1
                        
                        oP["x2"] = (((cameraX - (x - offsetX)) * (1 + (hM[2] or 0))) - (cameraX - (x - offsetX))) * -1
                        oP["y2"] = (((cameraY - (y + offsetY)) * (1 + (hM[2] or 0))) - (cameraY - (y + offsetY))) * -1
                        
                        oP["x3"] = (((cameraX - (x + offsetX)) * (1 + (hM[3] or 0))) - (cameraX - (x + offsetX))) * -1
                        oP["y3"] = (((cameraY - (y + offsetY)) * (1 + (hM[3] or 0))) - (cameraY - (y + offsetY))) * -1
                        
                        oP["x4"] = (((cameraX - (x + offsetX)) * (1 + (hM[4] or 0))) - (cameraX - (x + offsetX))) * -1
                        oP["y4"] = (((cameraY - (y - offsetY)) * (1 + (hM[4] or 0))) - (cameraY - (y - offsetY))) * -1
                    elseif (Map.map.layers[i].heightMap or Map.map.heightMap) and object.followHeightMap then
                        if not object.nativeWidth then
                            object.nativeWidth = object.width
                            object.nativeHeight = object.height
                        end							
                        local mH
                        if Map.map.heightMap then
                            mH = Map.map.heightMap
                        else
                            mH = Map.map.layers[i].heightMap
                        end							
                        local offsetX = object.nativeWidth / 2 
                        local offsetY = object.nativeHeight / 2 
                        local x = object.x
                        local y = object.y							
                        local lX = object.levelPosX / Map.map.tilewidth
                        local lY = object.levelPosY / Map.map.tileheight
                        local toggleX = math.round(lX)
                        local toggleY = math.round(lY)
                        local locX1, locX2, locY1, locY2
                        if toggleX < lX then
                            locX2 = math.ceil(object.levelPosX / Map.map.tilewidth)
                            locX1 = locX2 - 1
                            if locX1 < 1 then
                                locX1 = #mH
                            end	
                        else
                            locX1 = math.ceil(object.levelPosX / Map.map.tilewidth)
                            locX2 = locX1 + 1
                            if locX2 > #mH then
                                locX2 = 1
                            end	
                        end
                        if toggleY < lY then
                            locY2 = math.ceil(object.levelPosY / Map.map.tileheight)
                            locY1 = locY2 - 1
                            if locY1 < 1 then
                                locY1 = #mH[1]
                            end	
                        else
                            locY1 = math.ceil(object.levelPosY / Map.map.tileheight)
                            locY2 = locY1 + 1
                            if locY2 > #mH[1] then
                                locY2 = 1
                            end	
                        end							
                        local locX = object.locX
                        local locY = object.locY							
                        local tX1 = locX1 * Map.map.tilewidth - (Map.map.tilewidth / 2)
                        local tY1 = locY1 * Map.map.tileheight - (Map.map.tileheight / 2)
                        local tX2 = locX2 * Map.map.tilewidth - (Map.map.tilewidth / 2)
                        local tY2 = locY2 * Map.map.tileheight - (Map.map.tileheight / 2)
                        local area1 = (object.levelPosX - tX1) * (object.levelPosY - tY1)
                        local area2 = (object.levelPosX - tX1) * (tY2 - object.levelPosY)
                        local area3 = (tX2 - object.levelPosX) * (tY2 - object.levelPosY)
                        local area4 = (tX2 - object.levelPosX) * (object.levelPosY - tY1)
                        local area = Map.map.tilewidth * Map.map.tileheight							
                        local height1 = mH[locX1][locY1] * ((area3) / area)
                        local height2 = mH[locX1][locY2] * ((area4) / area)
                        local height3 = mH[locX2][locY2] * ((area1) / area)
                        local height4 = mH[locX2][locY1] * ((area2) / area)							
                        local tempHeight = height1 + height2 + height3 + height4
                        local oP = object.path
                        oP["x1"] = (((cameraX - (x - offsetX)) * (1 + tempHeight)) - (cameraX - (x - offsetX))) * -1
                        oP["y1"] = (((cameraY - (y - offsetY)) * (1 + tempHeight)) - (cameraY - (y - offsetY))) * -1
                        
                        oP["x2"] = (((cameraX - (x - offsetX)) * (1 + tempHeight)) - (cameraX - (x - offsetX))) * -1
                        oP["y2"] = (((cameraY - (y + offsetY)) * (1 + tempHeight)) - (cameraY - (y + offsetY))) * -1
                        
                        oP["x3"] = (((cameraX - (x + offsetX)) * (1 + tempHeight)) - (cameraX - (x + offsetX))) * -1
                        oP["y3"] = (((cameraY - (y + offsetY)) * (1 + tempHeight)) - (cameraY - (y + offsetY))) * -1
                        
                        oP["x4"] = (((cameraX - (x + offsetX)) * (1 + tempHeight)) - (cameraX - (x + offsetX))) * -1
                        oP["y4"] = (((cameraY - (y - offsetY)) * (1 + tempHeight)) - (cameraY - (y - offsetY))) * -1							
                    end
                end
                
                --Apply Lighting to Non-Light Objects, Trigger Events
                if object.lighting then
                    if Camera.enableLighting then
                        object.litBy = {}
                        local locX = object.locX
                        local locY = object.locY
                        local mapLayerFalloff = Map.map.properties.lightLayerFalloff
                        local mapLevelFalloff = Map.map.properties.lightLevelFalloff
                        local red, green, blue = Map.map.layers[i].redLight, Map.map.layers[i].greenLight, Map.map.layers[i].blueLight
                        if Map.map.perlinLighting then
                            red = red * map.perlinLighting[locX][locY]
                            green = green * map.perlinLighting[locX][locY]
                            blue = blue * map.perlinLighting[locX][locY]
                        elseif Map.map.layers[i].perlinLighting then
                            red = red * map.layers[i].perlinLighting[locX][locY]
                            green = green * map.layers[i].perlinLighting[locX][locY]
                            blue = blue * map.layers[i].perlinLighting[locX][locY]
                        end                        
                        for k = 1, #Map.map.layers, 1 do
                            if Map.map.layers[k].lighting[locX] then
                                if Map.map.layers[k].lighting[locX][locY] then
                                    local temp = Map.map.layers[k].lighting[locX][locY]
                                    local tempSources = {}
                                    for key,value in pairs(object.prevLitBy) do
                                        tempSources[key] = true
                                    end
                                    for key,value in pairs(temp) do
                                        local levelDiff = math.abs(Map.getLevel(i) - Map.map.lights[key].level)
                                        local layerDiff = math.abs(i - Map.map.lights[key].layer)							
                                        local layerFalloff, levelFalloff
                                        if Map.map.lights[key].layerFalloff then
                                            layerFalloff = Map.map.lights[key].layerFalloff
                                        else
                                            layerFalloff = mapLayerFalloff
                                        end							
                                        if Map.map.lights[key].levelFalloff then
                                            levelFalloff = Map.map.lights[key].levelFalloff
                                        else
                                            levelFalloff = mapLevelFalloff
                                        end							
                                        local tR = temp[key].light[1] - (levelDiff * levelFalloff[1]) - (layerDiff * layerFalloff[1])
                                        local tG = temp[key].light[2] - (levelDiff * levelFalloff[2]) - (layerDiff * layerFalloff[2])
                                        local tB = temp[key].light[3] - (levelDiff * levelFalloff[3]) - (layerDiff * layerFalloff[3])							
                                        if object.lightingListeners[key] then
                                            local event = { name = key, target = object, source = Map.map.lights[key], light = {tR, tG, tB}}
                                            if not object.prevLitBy[key] then
                                                object.prevLitBy[key] = true
                                                event.phase = "began"
                                            else
                                                event.phase = "maintained"
                                            end
                                            object:dispatchEvent( event )
                                            tempSources[key] = nil
                                        end							
                                        if tR > red then
                                            red = tR
                                        end
                                        if tG > green then
                                            green = tG
                                        end
                                        if tB > blue then
                                            blue = tB
                                        end							
                                        object.litBy[#object.litBy + 1] = key							
                                    end
                                    for key,value in pairs(tempSources) do
                                        if object.lightingListeners[key] then
                                            object.prevLitBy[key] = nil
                                            local event = { name = key, target = object, source = Map.map.lights[key], light = {tR, tG, tB}}
                                            event.phase = "ended"
                                            object:dispatchEvent( event )
                                        end
                                    end
                                else						
                                    for key,value in pairs(object.prevLitBy) do
                                        if object.lightingListeners[key] and not Map.map.lights[key] then
                                            object.prevLitBy[key] = nil
                                            local event = { name = key, target = object, source = Map.map.lights[key], light = {tR, tG, tB}}
                                            event.phase = "ended"
                                            object:dispatchEvent( event )
                                        elseif object.lightingListeners[key] and Map.map.lights[key].layer == k then
                                            object.prevLitBy[key] = nil
                                            local event = { name = key, target = object, source = Map.map.lights[key], light = {tR, tG, tB}}
                                            event.phase = "ended"
                                            object:dispatchEvent( event )
                                        end
                                    end						
                                end
                            end
                        end
                        if object.objType < 3 then
                            object:setFillColor(red*object.color[1], green*object.color[2], blue*object.color[3])
                        elseif object.objType == 3 then
                            for i = 1, object.numChildren, 1 do
                                if object[i]._class then
                                    object[i]:setFillColor(red*object[i].color[1], green*object[i].color[2], blue*object[i].color[3])
                                end
                            end
                        elseif object.objType == 4 then
                            for i = 1, object.numChildren, 1 do
                                if object[i]._class then
                                    object[i]:setStrokeColor(red*object[i].color[1], green*object[i].color[2], blue*object[i].color[3])
                                end
                            end
                        end
                    else
                        local locX = object.locX
                        local locY = object.locY
                        local red, green, blue = Map.map.layers[i].redLight, Map.map.layers[i].greenLight, Map.map.layers[i].blueLight
                        if Map.map.perlinLighting then
                            local perlinLightValue = Map.map.perlinLighting[locX][locY]
                            red = red * perlinLightValue
                            green = green * perlinLightValue
                            blue = blue * perlinLightValue
                        elseif Map.map.layers[i].perlinLighting then
                            local perlinLightValue = Map.map.layers[i].perlinLighting[locX][locY]
                            red = red * perlinLightValue
                            green = green * perlinLightValue
                            blue = blue * perlinLightValue
                        end
                        if object.objType < 3 then
                            object:setFillColor(red*object.color[1], green*object.color[2], blue*object.color[3])
                        elseif object.objType == 3 then
                            for i = 1, object.numChildren, 1 do
                                if object[i]._class then
                                    object[i]:setFillColor(red*object[i].color[1], green*object[i].color[2], blue*object[i].color[3])
                                end
                            end
                        elseif object.objType == 4 then
                            for i = 1, object.numChildren, 1 do
                                if object[i]._class then
                                    object[i]:setStrokeColor(red*object[i].color[1], green*object[i].color[2], blue*object[i].color[3])
                                end
                            end
                        end
                    end
                end
                
                --Cast Light
                if Camera.enableLighting and object.light then
                    if Light.lightingData.refreshCounter == 1 then
                        object.light.levelPosX = object.levelPosX
                        object.light.levelPosY = object.levelPosY
                    end					
                    if Light.lightingData.refreshCounter == 1 then
                        if object.levelPosX > 0 - (Map.map.locOffsetX * Map.map.tilewidth) and object.levelPosX <= (Map.map.width - Map.map.locOffsetX) * Map.map.tilewidth then
                            if object.levelPosY > 0 - (Map.map.locOffsetY * Map.map.tileheight) and object.levelPosY <= (Map.map.height - Map.map.locOffsetY) * Map.map.tileheight then
                                if object.light.rays then
                                    for k = 1, #object.light.rays, 1 do
                                        Light.processLightRay(object.light.layer, object.light, object.light.rays[k])
                                    end
                                else								
                                    Light.processLight(object.light.layer, object.light)									
                                    local length = #object.light.area
                                    local tempML = {}
                                    local oLx = object.light.locX
                                    local oLy = object.light.locY
                                    local oLl = object.light.layer
                                    local oLi = object.light.id
                                    local mL = Map.map.layers
                                    for i = length, 1, -1 do
                                        local locX = object.light.area[i][1]
                                        local locY = object.light.area[i][2]
                                        local locXt = locX
                                        local locYt = locY						
                                        if Camera.worldWrapX then
                                            if locX < 1 - Map.map.locOffsetX then
                                                locX = locX + Map.map.width
                                            end
                                            if locX > Map.map.width - Map.map.locOffsetX then
                                                locX = locX - Map.map.width
                                            end
                                        end
                                        if Camera.worldWrapY then
                                            if locY < 1 - Map.map.locOffsetY then
                                                locY = locY + Map.map.height
                                            end
                                            if locY > Map.map.height - Map.map.locOffsetY then
                                                locY = locY - Map.map.height
                                            end
                                        end						
                                        local neighbor1 = {0, 0, 0}
                                        local neighbor2 = {0, 0, 0}										
                                        if locX ~= oLx and locY ~= oLy and Map.map.lightingData[mL[oLl].world[locX][locY]]then											
                                            if locXt > oLx and locYt < oLy then
                                                --top right
                                                if oLl then
                                                    if mL[oLl].lighting[locX - 1] and mL[oLl].lighting[locX][locY] then
                                                        if not Map.map.lightingData[mL[oLl].world[locX - 1][locY]] then
                                                            if mL[oLl].lighting[locX - 1][locY] then
                                                                if mL[oLl].lighting[locX - 1][locY][oLi] then
                                                                    neighbor1 = mL[oLl].lighting[locX - 1][locY][oLi].light
                                                                    neighbor1[4] = locX - 1
                                                                    neighbor1[5] = locY
                                                                end
                                                            end
                                                        end
                                                    end	
                                                    if mL[oLl].lighting[locX] and mL[oLl].lighting[locX][locY + 1] then
                                                        if not Map.map.lightingData[mL[oLl].world[locX][locY + 1]] then
                                                            if mL[oLl].lighting[locX][locY + 1] then
                                                                if mL[oLl].lighting[locX][locY + 1][oLi] then
                                                                    neighbor2 = mL[oLl].lighting[locX][locY + 1][oLi].light
                                                                    neighbor2[4] = locX
                                                                    neighbor2[5] = locY + 1
                                                                end
                                                            end
                                                        end
                                                    end	
                                                end
                                            elseif locXt > oLx and locYt > oLy then
                                                --bottom right
                                                if oLl then
                                                    if mL[oLl].lighting[locX - 1] and mL[oLl].lighting[locX][locY] then
                                                        if not Map.map.lightingData[mL[oLl].world[locX - 1][locY]] then
                                                            if mL[oLl].lighting[locX - 1][locY] then
                                                                if mL[oLl].lighting[locX - 1][locY][oLi] then
                                                                    neighbor1 = mL[oLl].lighting[locX - 1][locY][oLi].light
                                                                    neighbor1[4] = locX - 1
                                                                    neighbor1[5] = locY
                                                                end
                                                            end
                                                        end
                                                    end	
                                                    if mL[oLl].lighting[locX] and mL[oLl].lighting[locX][locY - 1] then
                                                        if not Map.map.lightingData[mL[oLl].world[locX][locY - 1]] then
                                                            if mL[oLl].lighting[locX][locY - 1] then
                                                                if mL[oLl].lighting[locX][locY - 1][oLi] then
                                                                    neighbor2 = mL[oLl].lighting[locX][locY - 1][oLi].light
                                                                    neighbor2[4] = locX
                                                                    neighbor2[5] = locY - 1
                                                                end
                                                            end
                                                        end
                                                    end	
                                                end
                                            elseif locXt < oLx and locYt > oLy then
                                                --bottom left
                                                if oLl then
                                                    if mL[oLl].lighting[locX + 1] and mL[oLl].lighting[locX][locY] then
                                                        if not Map.map.lightingData[mL[oLl].world[locX + 1][locY]] then
                                                            if mL[oLl].lighting[locX + 1][locY] then
                                                                if mL[oLl].lighting[locX + 1][locY][oLi] then
                                                                    neighbor1 = mL[oLl].lighting[locX + 1][locY][oLi].light
                                                                    neighbor1[4] = locX + 1
                                                                    neighbor1[5] = locY
                                                                end
                                                            end
                                                        end
                                                    end	
                                                    if mL[oLl].lighting[locX] and mL[oLl].lighting[locX][locY - 1] then
                                                        if not Map.map.lightingData[mL[oLl].world[locX][locY - 1]] then
                                                            if mL[oLl].lighting[locX][locY - 1] then
                                                                if mL[oLl].lighting[locX][locY - 1][oLi] then
                                                                    neighbor2 = mL[oLl].lighting[locX][locY - 1][oLi].light
                                                                    neighbor2[4] = locX
                                                                    neighbor2[5] = locY - 1
                                                                end
                                                            end
                                                        end
                                                    end	
                                                end
                                            elseif locXt < oLx and locYt < oLy then
                                                --top left
                                                if oLl then
                                                    if mL[oLl].lighting[locX + 1] and mL[oLl].lighting[locX][locY] then
                                                        if not Map.map.lightingData[mL[oLl].world[locX + 1][locY]] then
                                                            if mL[oLl].lighting[locX + 1][locY] then
                                                                if mL[oLl].lighting[locX + 1][locY][oLi] then
                                                                    neighbor1 = mL[oLl].lighting[locX + 1][locY][oLi].light
                                                                    neighbor1[4] = locX + 1
                                                                    neighbor1[5] = locY
                                                                end
                                                            end
                                                        end
                                                    end	
                                                    if mL[oLl].lighting[locX] and mL[oLl].lighting[locX][locY + 1] then
                                                        if not Map.map.lightingData[mL[oLl].world[locX][locY + 1]] then
                                                            if mL[oLl].lighting[locX][locY + 1] then
                                                                if mL[oLl].lighting[locX][locY + 1][oLi] then
                                                                    neighbor2 = mL[oLl].lighting[locX][locY + 1][oLi].light
                                                                    neighbor2[4] = locX
                                                                    neighbor2[5] = locY + 1
                                                                end
                                                            end
                                                        end
                                                    end	
                                                end
                                            end						
                                            local neighbor						
                                            if neighbor1[1] + neighbor1[2] + neighbor1[3] > neighbor2[1] + neighbor2[2] + neighbor2[3] then
                                                neighbor = neighbor1
                                            else
                                                neighbor = neighbor2
                                            end							
                                            if neighbor[1] + neighbor[2] + neighbor[3] > 0 then
                                                if math.abs( (neighbor[1] + neighbor[2] + neighbor[3]) - (mL[oLl].lighting[locX][locY][oLi].light[1] +
                                                    mL[oLl].lighting[locX][locY][oLi].light[2] + 
                                                    mL[oLl].lighting[locX][locY][oLi].light[3]) ) > 
                                                    (object.light.falloff[1] + object.light.falloff[2] + object.light.falloff[3]) * 1.5 then
                                                    local distance = math.sqrt( ((locXt - oLx) * (locXt - oLx)) + 
                                                    ((locYt - oLy) * (locYt - oLy))  ) 									
                                                    local red = object.light.source[1] - (object.light.falloff[1] * distance)
                                                    local green = object.light.source[2] - (object.light.falloff[2] * distance)
                                                    local blue = object.light.source[3] - (object.light.falloff[3] * distance)
                                                    tempML[#tempML + 1] = {locX, locY, red, green, blue}
                                                end
                                            end
                                        end						
                                    end					
                                    for i = 1, #tempML, 1 do
                                        mL[oLl].lighting[tempML[i][1]][tempML[i][2]][oLi].light = {tempML[i][3], 
                                        tempML[i][4], tempML[i][5]}
                                    end
                                end
                            end
                        end				
                    end	
                    if object.lighting then
                        if object.objType < 3 then
                            local oL = object.light.source
                            object:setFillColor(oL[1]*object.color[1], oL[2]*object.color[2], oL[3]*object.color[3])
                        elseif object.objType == 3 then
                            local oL = object.light.source
                            for i = 1, object.numChildren, 1 do
                                if object[i]._class then
                                    object[i]:setFillColor(oL[1]*object[i].color[1], oL[2]*object[i].color[2], oL[3]*object[i].color[3])
                                end
                            end
                        elseif object.objType == 4 then
                            local oL = object.light.source
                            for i = 1, object.numChildren, 1 do
                                if object[i]._class then
                                    object[i]:setStrokeColor(oL[1]*object[i].color[1], oL[2]*object[i].color[2], oL[3]*object[i].color[3])
                                end
                            end
                        end
                    end
                end
                
                --Cull Object
                if Map.masterGroup[i].vars.camera and object.objectKey and ((object.properties and object.properties.cull == "true") or (Map.map.layers[i].properties and Map.map.layers[i].properties.cullObjects == "true")) then
                    local tempX, tempY = Map.masterGroup.parent:localToContent(object.contentBounds.xMin, object.contentBounds.yMin)
                    local leftTop = {Map.masterGroup[i]:contentToLocal(tempX, tempY)}							
                    tempX, tempY = Map.masterGroup.parent:localToContent(object.contentBounds.xMax, object.contentBounds.yMax)
                    local rightBottom = {Map.masterGroup[i]:contentToLocal(tempX, tempY)}							
                    local tleft = math.ceil(leftTop[1] / Map.map.tilewidth)
                    local ttop = math.ceil(leftTop[2] / Map.map.tileheight)
                    local tright = math.ceil(rightBottom[1] / Map.map.tilewidth)
                    local tbottom = math.ceil(rightBottom[2] / Map.map.tileheight)
                    
                    local left, top, right, bottom = tleft, ttop, tright, tbottom
                    if tleft < Map.masterGroup[i].vars.camera[1] and tright > Map.masterGroup[i].vars.camera[1] then
                        left = Map.masterGroup[i].vars.camera[1]
                    end
                    if ttop < Map.masterGroup[i].vars.camera[2] and tbottom > Map.masterGroup[i].vars.camera[2] then
                        top = Map.masterGroup[i].vars.camera[2]
                    end
                    if tright < Map.masterGroup[i].vars.camera[3] and tleft > Map.masterGroup[i].vars.camera[3] then
                        right = Map.masterGroup[i].vars.camera[3]
                    end
                    if tbottom > Map.masterGroup[i].vars.camera[4] and ttop < Map.masterGroup[i].vars.camera[4] then
                        bottom = Map.masterGroup[i].vars.camera[4]
                    end
                    
                    if (left >= Map.masterGroup[i].vars.camera[1] and left <= Map.masterGroup[i].vars.camera[3] and
                        top >= Map.masterGroup[i].vars.camera[2] and top <= Map.masterGroup[i].vars.camera[4]) or
                        
                        (right >= Map.masterGroup[i].vars.camera[1] and right <= Map.masterGroup[i].vars.camera[3] and
                        top >= Map.masterGroup[i].vars.camera[2] and top <= Map.masterGroup[i].vars.camera[4]) or
                        
                        (left >= Map.masterGroup[i].vars.camera[1] and left <= Map.masterGroup[i].vars.camera[3] and
                        bottom >= Map.masterGroup[i].vars.camera[2] and bottom <= Map.masterGroup[i].vars.camera[4]) or
                        
                        (right >= Map.masterGroup[i].vars.camera[1] and right <= Map.masterGroup[i].vars.camera[3] and
                        bottom >= Map.masterGroup[i].vars.camera[2] and bottom <= Map.masterGroup[i].vars.camera[4])then
                        --onscreen
                        
                    elseif (left >= Map.masterGroup[i].vars.camera[1] - 1 and left <= Map.masterGroup[i].vars.camera[3] + 1 and
                        top >= Map.masterGroup[i].vars.camera[2] - 1 and top <= Map.masterGroup[i].vars.camera[4] + 1) or
                        
                        (right >= Map.masterGroup[i].vars.camera[1] - 1 and right <= Map.masterGroup[i].vars.camera[3] + 1 and
                        top >= Map.masterGroup[i].vars.camera[2] - 1 and top <= Map.masterGroup[i].vars.camera[4] + 1) or
                        
                        (left >= Map.masterGroup[i].vars.camera[1] - 1 and left <= Map.masterGroup[i].vars.camera[3] + 1 and
                        bottom >= Map.masterGroup[i].vars.camera[2] - 1 and bottom <= Map.masterGroup[i].vars.camera[4] + 1) or
                        
                        (right >= Map.masterGroup[i].vars.camera[1] - 1 and right <= Map.masterGroup[i].vars.camera[3] + 1 and
                        bottom >= Map.masterGroup[i].vars.camera[2] - 1 and bottom <= Map.masterGroup[i].vars.camera[4] + 1)then
                        --edge
                    else
                        --offscreen
                        --Sprites.sprites[spriteName].objectKey = ky
                        --Sprites.sprites[spriteName].objectLayer = layer
                        
                        local tiledObject = Map.map.layers[i].objects[object.objectKey]
                        tiledObject.cullData = {object.x, object.y, object.width, object.height, object.rotation}
                        tiledObject.properties.wasDrawn = false
                        
                        if object.physicsRegion and #object.physicsRegion > 0 then
                            for p = #object.physicsRegion, 1, -1 do
                                local lx = object.physicsRegion[p][1]
                                local ly = object.physicsRegion[p][2]
                                local layer = object.physicsRegion[p][3]
                                Core.updateTile({locX = lx, locY = ly, layer = layer, tile = -1, owner = object})
                                table.remove(object.physicsRegion, p)							
                            end
                        end
                        
                        local mL = Map.map.layers[object.objectLayer]
                        
                        tiledObject.cullData[6] = {}
                        for x = tleft, tright, 1 do
                            for y = ttop, tbottom, 1 do
                                if not mL.extendedObjects[x][y] then
                                    mL.extendedObjects[x][y] = {}
                                end
                                
                                mL.extendedObjects[x][y][#mL.extendedObjects[x][y] + 1] = {object.objectLayer, object.objectKey}
                                tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = {x, y, #mL.extendedObjects[x][y]}
                                
                            end
                        end
                        
                        if bob and tright - tleft < Map.masterGroup[i].vars.camera[3] - Map.masterGroup[i].vars.camera[1] then
                            if tbottom - ttop < Map.masterGroup[i].vars.camera[4] - Map.masterGroup[i].vars.camera[2] then
                                --four corners
                                --print(tleft, ttop, tright, tbottom)
                                if not mL.extendedObjects[tleft][ttop] then
                                    mL.extendedObjects[tleft][ttop] = {}
                                end
                                if not mL.extendedObjects[tright][ttop] then
                                    mL.extendedObjects[tright][ttop] = {}
                                end
                                if not mL.extendedObjects[tleft][tbottom] then
                                    mL.extendedObjects[tleft][tbottom] = {}
                                end
                                if not mL.extendedObjects[tright][tbottom] then
                                    mL.extendedObjects[tright][tbottom] = {}
                                end
                                
                                mL.extendedObjects[tleft][ttop][#mL.extendedObjects[tleft][ttop] + 1] = {object.objectLayer, object.objectKey}
                                mL.extendedObjects[tright][ttop][#mL.extendedObjects[tright][ttop] + 1] = {object.objectLayer, object.objectKey}
                                mL.extendedObjects[tleft][tbottom][#mL.extendedObjects[tleft][tbottom] + 1] = {object.objectLayer, object.objectKey}
                                mL.extendedObjects[tright][tbottom][#mL.extendedObjects[tright][tbottom] + 1] = {object.objectLayer, object.objectKey}
                                
                                tiledObject.cullData[6] = {
                                    {tleft, ttop, #mL.extendedObjects[tleft][ttop]},
                                    {tright, ttop, #mL.extendedObjects[tright][ttop]},
                                    {tleft, tbottom, #mL.extendedObjects[tleft][tbottom]},
                                    {tright, tbottom, #mL.extendedObjects[tright][tbottom]}
                                }
                                
                                if q then
                                    tiledObject.cullData[6] = {
                                        mL.extendedObjects[tleft][ttop][#mL.extendedObjects[tleft][ttop]],
                                        mL.extendedObjects[tright][ttop][#mL.extendedObjects[tright][ttop]],
                                        mL.extendedObjects[tleft][tbottom][#mL.extendedObjects[tleft][tbottom]],
                                        mL.extendedObjects[tright][tbottom][#mL.extendedObjects[tright][tbottom]]
                                    }
                                end
                            else
                                --double columns
                                tiledObject.cullData[6] = {}
                                
                                for y = ttop, tbottom, 1 do
                                    if not mL.extendedObjects[tleft][y] then
                                        mL.extendedObjects[tleft][y] = {}
                                    end
                                    if not mL.extendedObjects[tright][y] then
                                        mL.extendedObjects[tright][y] = {}
                                    end
                                    
                                    mL.extendedObjects[tleft][y][#mL.extendedObjects[tleft][y] + 1] = {object.objectLayer, object.objectKey}
                                    mL.extendedObjects[tright][y][#mL.extendedObjects[tright][y] + 1] = {object.objectLayer, object.objectKey}
                                    
                                    tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = {tleft, y, #mL.extendedObjects[tleft][y]}
                                    tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = {tright, y, #mL.extendedObjects[tright][y]}
                                    
                                    if q then
                                        tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = mL.extendedObjects[tleft][y][#mL.extendedObjects[tleft][y]]
                                        tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = mL.extendedObjects[tright][y][#mL.extendedObjects[tright][y]]
                                    end
                                end
                            end
                        elseif bob then
                            if tbottom - ttop < Map.masterGroup[i].vars.camera[4] - Map.masterGroup[i].vars.camera[2] then
                                --double rows
                                tiledObject.cullData[6] = {}
                                
                                for x = tleft, tright, 1 do
                                    if not mL.extendedObjects[x][ttop] then
                                        mL.extendedObjects[x][ttop] = {}
                                    end
                                    if not mL.extendedObjects[x][tbottom] then
                                        mL.extendedObjects[x][tbottom] = {}
                                    end
                                    
                                    mL.extendedObjects[x][ttop][#mL.extendedObjects[x][ttop] + 1] = {object.objectLayer, object.objectKey}
                                    mL.extendedObjects[x][tbottom][#mL.extendedObjects[x][tbottom] + 1] = {object.objectLayer, object.objectKey}
                                    
                                    tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = {x, ttop, #mL.extendedObjects[x][ttop]}
                                    tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = {x, tbottom, #mL.extendedObjects[x][tbottom]}
                                    
                                    if q then
                                        tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = mL.extendedObjects[x][ttop][#mL.extendedObjects[x][ttop]]
                                        tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = mL.extendedObjects[x][tbottom][#mL.extendedObjects[x][tbottom]]
                                    end
                                end
                            else
                                --rows and columns
                                tiledObject.cullData[6] = {}
                                
                                for x = tleft, tright, 1 do
                                    if not mL.extendedObjects[x][ttop] then
                                        mL.extendedObjects[x][ttop] = {}
                                    end
                                    if not mL.extendedObjects[x][tbottom] then
                                        mL.extendedObjects[x][tbottom] = {}
                                    end
                                    
                                    mL.extendedObjects[x][ttop][#mL.extendedObjects[x][ttop] + 1] = {object.objectLayer, object.objectKey}
                                    mL.extendedObjects[x][tbottom][#mL.extendedObjects[x][tbottom] + 1] = {object.objectLayer, object.objectKey}
                                    
                                    tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = {x, ttop, #mL.extendedObjects[x][ttop]}
                                    tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = {x, tbottom, #mL.extendedObjects[x][tbottom]}
                                    
                                    if q then
                                        tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = mL.extendedObjects[x][ttop][#mL.extendedObjects[x][ttop]]
                                        tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = mL.extendedObjects[x][tbottom][#mL.extendedObjects[x][tbottom]]
                                    end
                                end
                                
                                for y = ttop - 1, tbottom + 1, 1 do
                                    if not mL.extendedObjects[tleft][y] then
                                        mL.extendedObjects[tleft][y] = {}
                                    end
                                    if not mL.extendedObjects[tright][y] then
                                        mL.extendedObjects[tright][y] = {}
                                    end
                                    
                                    mL.extendedObjects[tleft][y][#mL.extendedObjects[tleft][y] + 1] = {object.objectLayer, object.objectKey}
                                    mL.extendedObjects[tright][y][#mL.extendedObjects[tright][y] + 1] = {object.objectLayer, object.objectKey}
                                    
                                    tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = {tleft, y, #mL.extendedObjects[tleft][y]}
                                    tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = {tright, y, #mL.extendedObjects[tright][y]}
                                    
                                    if q then
                                        tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = mL.extendedObjects[tleft][y][#mL.extendedObjects[tleft][y]]
                                        tiledObject.cullData[6][#tiledObject.cullData[6] + 1] = mL.extendedObjects[tright][y][#mL.extendedObjects[tright][y]]
                                    end
                                end
                            end
                        end
                        
                        Sprite.removeSprite(object)
                    end
                end
                ------
            end
        end
        
        for i = 1, #Map.map.layers, 1 do	
            if Map.map.orientation == Map.Type.Isometric then
                for j = Map.masterGroup[i].numChildren, 1, -1 do
                    if Map.masterGroup[i][j].numChildren then
                        for k = Map.masterGroup[i][j].numChildren, 1, -1 do
                            if not Map.masterGroup[i][j][k].tiles then
                                local object = Map.masterGroup[i][j][k]
                                if object then
                                    processObject(object, i)
                                end
                            end
                        end
                    end
                end
            else
                for j = Map.masterGroup[i].numChildren, 1, -1 do
                    if not Map.masterGroup[i][j].tiles then
                        if Map.masterGroup[i][j].depthBuffer then
                            for k = 1, Map.masterGroup[i][j].numChildren, 1 do
                                for m = 1, Map.masterGroup[i][j][k].numChildren, 1 do
                                    local object = Map.masterGroup[i][j][k][m]
                                    if object then
                                        processObject(object, i)
                                    end
                                end
                            end
                        else
                            local object = Map.masterGroup[i][j]
                            if object then
                                processObject(object, i)
                            end
                        end
                    end
                end
            end
        end
    end
    
    
    --MOVE CAMERA
    local finalVelX = {}
    local finalVelY = {}
    local cameraVelX = {}
    local cameraVelY = {}
    if not Camera.McameraFrozen then
        if Map.map.orientation == Map.Type.Isometric then
            if Camera.refMove then
                local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                local cameraX, cameraY = Map.masterGroup[Map.refLayer]:contentToLocal(tempX, tempY)					
                local isoPos = Map.isoUntransform2(cameraX, cameraY)
                cameraX = isoPos[1]
                cameraY = isoPos[2]
                local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
                local cameraLocY = math.ceil(cameraY / Map.map.tileheight)					
                local velX = deltaX[Map.refLayer][1]
                local velY = deltaY[Map.refLayer][1]
                local tempVelX = deltaX[Map.refLayer][1]
                local tempVelY = deltaY[Map.refLayer][1]					
                local check = #Map.map.layers
                for i = 1, #Map.map.layers, 1 do
                    if Camera.isCameraMoving[i] then
                        if Camera.parallaxToggle[i] then
                            finalVelX[i] = tempVelX * Map.map.layers[i].parallaxX / Map.map.layers[i].properties.scaleX
                            finalVelY[i] = tempVelY * Map.map.layers[i].parallaxY / Map.map.layers[i].properties.scaleY
                        else
                            finalVelX[i] = tempVelX
                            finalVelY[i] = tempVelY
                        end
                    end
                    table.remove(deltaX[i], 1)
                    table.remove(deltaY[i], 1)
                    if not deltaX[i][1] then
                        check = check - 1
                        Camera.isCameraMoving[i] = false
                        Camera.parallaxToggle[i] = true
                        Camera.refMove = false
                        --Sprites.holdSprite = nil
                    end
                end					
                if Camera.cameraFocus and not Sprites.holdSprite then
                    for i = 1, #Map.map.layers, 1 do
                        Camera.cameraFocus.cameraOffsetX[i] = Camera.cameraFocus.cameraOffsetX[i] + finalVelX[Map.refLayer]
                        Camera.cameraFocus.cameraOffsetY[i] = Camera.cameraFocus.cameraOffsetY[i] + finalVelY[Map.refLayer]
                    end
                end					
                if check == 0 and Camera.cameraOnComplete[1] then
                    local tempOnComplete = Camera.cameraOnComplete[1]
                    Camera.cameraOnComplete = {}
                    local event = { name = "cameraMoveComplete", levelPosX = cameraX, 
                        levelPosY = cameraY, 
                        locX = cameraLocX, 
                        locY = cameraLocY
                    }
                    tempOnComplete(event)
                end
            else
                for i = 1, #Map.map.layers, 1 do
                    if Camera.isCameraMoving[i] then
                        local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                        local cameraX, cameraY = Map.masterGroup[i]:contentToLocal(tempX, tempY)
                        local isoPos = Map.isoUntransform2(cameraX, cameraY)
                        cameraX = isoPos[1]
                        cameraY = isoPos[2]
                        local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
                        local cameraLocY = math.ceil(cameraY / Map.map.tileheight)							
                        local velX = deltaX[i][1]
                        local velY = deltaY[i][1]
                        local tempVelX = deltaX[i][1]
                        local tempVelY = deltaY[i][1]							
                        if Camera.parallaxToggle[i] or Camera.parallaxToggle[i] == nil then
                            finalVelX[i] = tempVelX * Map.map.layers[i].parallaxX / Map.map.layers[i].properties.scaleX
                            finalVelY[i] = tempVelY * Map.map.layers[i].parallaxY / Map.map.layers[i].properties.scaleY
                        else
                            finalVelX[i] = tempVelX
                            finalVelY[i] = tempVelY
                        end
                        if Camera.cameraFocus and not Sprites.holdSprite then
                            Camera.cameraFocus.cameraOffsetX[i] = Camera.cameraFocus.cameraOffsetX[i] + finalVelX[i]
                            Camera.cameraFocus.cameraOffsetY[i] = Camera.cameraFocus.cameraOffsetY[i] + finalVelY[i]
                        end						
                        table.remove(deltaX[i], 1)
                        table.remove(deltaY[i], 1)
                        if not deltaX[i][1] then
                            Camera.isCameraMoving[i] = false
                            Camera.parallaxToggle[i] = true
                            --Sprites.holdSprite = nil
                            if Camera.cameraOnComplete[i] then
                                local tempOnComplete = Camera.cameraOnComplete[i]
                                Camera.cameraOnComplete[i] = nil
                                local event = { name = "cameraLayerMoveComplete", layer = i, 
                                    levelPosX = cameraX, 
                                    levelPosY = cameraY, 
                                    locX = cameraLocX, 
                                    locY = cameraLocY
                                }
                                tempOnComplete(event)
                            end
                        end
                    end
                end
            end
            
            --FOLLOW SPRITE
            local followingSprite = false
            if Camera.cameraFocus and not Sprites.holdSprite then
                for i = 1, #Map.map.layers, 1 do
                    local tempX, tempY, cameraX, cameraY, velX, velY
                    if Map.map.layers[i].toggleParallax == true or Map.map.layers[i].parallaxX ~= 1 or Map.map.layers[i].parallaxY ~= 1 then
                        tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                        cameraX, cameraY = Map.masterGroup[Map.refLayer]:contentToLocal(tempX, tempY)
                        velX = finalVelX[Map.refLayer] or 0
                        velY = finalVelY[Map.refLayer] or 0
                    else
                        tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                        cameraX, cameraY = Map.masterGroup[i]:contentToLocal(tempX, tempY)
                        velX = finalVelX[i] or 0
                        velY = finalVelY[i] or 0
                    end
                    local isoPos = Map.isoUntransform2(cameraX, cameraY)
                    cameraX = isoPos[1]
                    cameraY = isoPos[2]
                    local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
                    local cameraLocY = math.ceil(cameraY / Map.map.tileheight)
                    local fX = Camera.cameraFocus.levelPosX
                    local fY = Camera.cameraFocus.levelPosY
                    if math.abs((cameraX + velX) - (fX + Camera.cameraFocus.cameraOffsetX[i])) > 0.1 then
                        finalVelX[i] = ((fX + Camera.cameraFocus.cameraOffsetX[i]) - (cameraX)) * Map.map.layers[i].parallaxX / Map.map.layers[i].properties.scaleX
                        followingSprite = true
                    end
                    if math.abs((cameraY + velY) - (fY + Camera.cameraFocus.cameraOffsetY[i])) > 0.1 then
                        finalVelY[i] = ((fY + Camera.cameraFocus.cameraOffsetY[i]) - (cameraY)) * Map.map.layers[i].parallaxY / Map.map.layers[i].properties.scaleY
                        followingSprite = true
                    end
                end
                
            end
            
            --Clear constraint variable: override
            local checkHoldSprite = 0
            for i = 1, #Map.map.layers, 1 do
                if Camera.override[i] and (not deltaX[i] or not deltaX[i][1]) then
                    Camera.override[i] = false
                end
                if not Camera.deltaX[i] or not Camera.deltaX[i][1] then
                    checkHoldSprite = checkHoldSprite + 1
                end
            end
            if checkHoldSprite == #Map.map.layers and Sprites.holdSprite then
                Sprites.holdSprite = false
            end
            
            --APPLY CONSTRAINTS CONTINUOUSLY
            local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
            local cameraX, cameraY = Map.masterGroup[Map.refLayer]:contentToLocal(tempX, tempY)
            local isoPos = Map.isoUntransform2(cameraX, cameraY)
            cameraX = isoPos[1]
            cameraY = isoPos[2]
            local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
            local cameraLocY = math.ceil(cameraY / Map.map.tileheight)
            
            --calculate constraints
            local angle = Map.masterGroup.rotation + Map.masterGroup[Map.refLayer].rotation
            while angle >= 360 do
                angle = angle - 360
            end
            while angle < 0 do
                angle = angle + 360
            end				
            local topLeftT, topRightT, bottomRightT, bottomLeftT
            topLeftT = {Map.masterGroup.parent:localToContent(Screen.screenLeft, Screen.screenTop)}
            topRightT = {Map.masterGroup.parent:localToContent(Screen.screenRight, Screen.screenTop)}
            bottomRightT = {Map.masterGroup.parent:localToContent(Screen.screenRight, Screen.screenBottom)}
            bottomLeftT = {Map.masterGroup.parent:localToContent(Screen.screenLeft, Screen.screenBottom)}				
            local topLeft, topRight, bottomRight, bottomLeft
            if angle >= 0 and angle < 90 then
                topLeft = {Map.masterGroup[Map.refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
                topRight = {Map.masterGroup[Map.refLayer]:contentToLocal(topRightT[1], topRightT[2])}
                bottomRight = {Map.masterGroup[Map.refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                bottomLeft = {Map.masterGroup[Map.refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
            elseif angle >= 90 and angle < 180 then
                topLeft = {Map.masterGroup[Map.refLayer]:contentToLocal(topRightT[1], topRightT[2])}
                topRight = {Map.masterGroup[Map.refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                bottomRight = {Map.masterGroup[Map.refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                bottomLeft = {Map.masterGroup[Map.refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
            elseif angle >= 180 and angle < 270 then
                topLeft = {Map.masterGroup[Map.refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                topRight = {Map.masterGroup[Map.refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                bottomRight = {Map.masterGroup[Map.refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
                bottomLeft = {Map.masterGroup[Map.refLayer]:contentToLocal(topRightT[1], topRightT[2])}
            elseif angle >= 270 and angle < 360 then
                topLeft = {Map.masterGroup[Map.refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                topRight = {Map.masterGroup[Map.refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
                bottomRight = {Map.masterGroup[Map.refLayer]:contentToLocal(topRightT[1], topRightT[2])}
                bottomLeft = {Map.masterGroup[Map.refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
            end
            for i = 1, #Map.map.layers, 1 do
                if (not followingSprite or Map.masterGroup[i].vars.constrainLayer) and not Map.masterGroup[i].vars.alignment then
                    local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                    cameraX, cameraY = Map.masterGroup[i]:contentToLocal(tempX, tempY)
                    local isoPos = Map.isoUntransform2(cameraX, cameraY)
                    cameraX = isoPos[1]
                    cameraY = isoPos[2]
                    cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
                    cameraLocY = math.ceil(cameraY / Map.map.tileheight)
                    
                    --calculate constraints
                    angle = Map.masterGroup.rotation + Map.masterGroup[i].rotation
                    while angle >= 360 do
                        angle = angle - 360
                    end
                    while angle < 0 do
                        angle = angle + 360
                    end						
                    if angle >= 0 and angle < 90 then
                        topLeft = {Map.masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
                        topRight = {Map.masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
                        bottomRight = {Map.masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                        bottomLeft = {Map.masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                    elseif angle >= 90 and angle < 180 then
                        topLeft = {Map.masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
                        topRight = {Map.masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                        bottomRight = {Map.masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                        bottomLeft = {Map.masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
                    elseif angle >= 180 and angle < 270 then
                        topLeft = {Map.masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                        topRight = {Map.masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                        bottomRight = {Map.masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
                        bottomLeft = {Map.masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
                    elseif angle >= 270 and angle < 360 then
                        topLeft = {Map.masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                        topRight = {Map.masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
                        bottomRight = {Map.masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
                        bottomLeft = {Map.masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                    end
                end					
                local topLeftT, topRightT, bottomRightT, bottomLeftT
                topLeftT = Map.isoUntransform2(topLeft[1], topLeft[2])
                topRightT = Map.isoUntransform2(topRight[1], topRight[2])
                bottomRightT = Map.isoUntransform2(bottomRight[1], bottomRight[2])
                bottomLeftT = Map.isoUntransform2(bottomLeft[1], bottomLeft[2])					
                local left, top, right, bottom
                left = topLeftT[1] - (Map.map.tilewidth / 2)
                top = topRightT[2] - (Map.map.tileheight / 2)
                right = bottomRightT[1] - (Map.map.tilewidth / 2)
                bottom = bottomLeftT[2] - (Map.map.tileheight / 2)					
                local leftConstraint, topConstraint, rightConstraint, bottomConstraint
                if Camera.constrainLeft[i] then
                    leftConstraint = Camera.constrainLeft[i] + (cameraX - left)
                end
                if Camera.constrainTop[i] then
                    topConstraint = Camera.constrainTop[i] + (cameraY - top)
                end
                if Camera.constrainRight[i] then
                    rightConstraint = Camera.constrainRight[i] - (right - cameraX)
                end
                if Camera.constrainBottom[i] then
                    bottomConstraint = Camera.constrainBottom[i] - (bottom - cameraY)
                end						
                if (leftConstraint and rightConstraint) and (leftConstraint > rightConstraint) then
                    local temp = (leftConstraint + rightConstraint) / 2
                    leftConstraint = temp
                    rightConstraint = temp
                end
                if (topConstraint and bottomConstraint) and (topConstraint > bottomConstraint) then
                    local temp = (topConstraint + bottomConstraint) / 2
                    topConstraint = temp
                    bottomConstraint = temp
                end				
                if not Map.masterGroup[i].vars.alignment then
                    local velX = finalVelX[i] or 0
                    local velY = finalVelY[i] or 0
                    local tempVelX = velX
                    local tempVelY = velY					
                    if not Camera.override[i] then
                        local tVelX, tVelY = tempVelX, tempVelY
                        if leftConstraint then
                            if cameraX + velX / Map.map.layers[i].parallaxX < leftConstraint then
                                tVelX = (leftConstraint - cameraX) / Map.map.layers[i].parallaxX
                            end
                        end
                        if rightConstraint then
                            if cameraX + velX / Map.map.layers[i].parallaxX > rightConstraint then
                                tVelX = (rightConstraint - cameraX) / Map.map.layers[i].parallaxX
                            end
                        end
                        if topConstraint then
                            if cameraY + velY / Map.map.layers[i].parallaxY < topConstraint then
                                tVelY = (topConstraint - cameraY) / Map.map.layers[i].parallaxY
                            end
                        end
                        if bottomConstraint then
                            if cameraY + velY / Map.map.layers[i].parallaxY > bottomConstraint then
                                tVelY = (bottomConstraint - cameraY) / Map.map.layers[i].parallaxY
                            end
                        end
                        tempVelX = tVelX
                        tempVelY = tVelY
                    end					
                    local velX = tempVelX
                    local velY = tempVelY
                    nXx = math.cos(R45) * velX * 1
                    nXy = math.sin(R45) * velX / Map.map.isoRatio
                    nYx = math.sin(R45) * velY * -1
                    nYy = math.cos(R45) * velY / Map.map.isoRatio
                    local tempVelX2 = (nXx + nYx)
                    local tempVelY2 = (nXy + nYy)
                    Map.masterGroup[i]:translate(tempVelX2 * -1 * Map.map.layers[i].properties.scaleX, tempVelY2 * -1 * Map.map.layers[i].properties.scaleY)
                else
                    if not leftConstraint then
                        leftConstraint = (0 - (Map.map.locOffsetX * Map.map.tilewidth)) + (cameraX - left)
                    end
                    if not topConstraint then
                        topConstraint = (0 - (Map.map.locOffsetY * Map.map.tileheight)) + (cameraY - top)
                    end
                    if not rightConstraint then
                        rightConstraint = ((Map.map.width - Map.map.locOffsetX) * Map.map.tilewidth) - (right - cameraX)
                    end
                    if not bottomConstraint then
                        bottomConstraint = ((Map.map.height - Map.map.locOffsetY) * Map.map.tileheight) - (bottom - cameraY)	
                    end			
                    if (leftConstraint and rightConstraint) and (leftConstraint > rightConstraint) then
                        local temp = (leftConstraint + rightConstraint) / 2
                        leftConstraint = temp
                        rightConstraint = temp
                    end
                    if (topConstraint and bottomConstraint) and (topConstraint > bottomConstraint) then
                        local temp = (topConstraint + bottomConstraint) / 2
                        topConstraint = temp
                        bottomConstraint = temp
                    end	
                    local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                    local cameraX, cameraY = Map.masterGroup[Map.refLayer]:contentToLocal(tempX, tempY)
                    local isoPos = Map.isoUntransform2(cameraX, cameraY)
                    cameraX = isoPos[1]
                    cameraY = isoPos[2]
                    local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
                    local cameraLocY = math.ceil(cameraY / Map.map.tileheight)
                    local xA = Map.masterGroup[i].vars.alignment[1] or "center"
                    local yA = Map.masterGroup[i].vars.alignment[2] or "center"						
                    local levelPosX, levelPosY
                    if xA == "center" then
                        local adjustment1 = (((Map.map.width * Map.map.tilewidth * 0.5) - (Map.map.locOffsetX * Map.map.tilewidth * 0.5)) * Map.map.layers[i].properties.scaleX) - ((Map.map.width * Map.map.tilewidth * 0.5) - (Map.map.locOffsetX * Map.map.tilewidth * 0.5))
                        local adjustment2 = (cameraX - ((Map.map.width * Map.map.tilewidth * 0.5) - (Map.map.locOffsetX * Map.map.tilewidth * 0.5))) - ((cameraX - ((Map.map.width * Map.map.tilewidth * 0.5) - (Map.map.locOffsetX * Map.map.tilewidth * 0.5))) * Map.map.layers[i].parallaxX)
                        levelPosX = ((cameraX + adjustment1) - adjustment2)
                    elseif xA == "left" then
                        local adjustment = (cameraX - leftConstraint) - ((cameraX - leftConstraint) * Map.map.layers[i].parallaxX)
                        levelPosX = (cameraX - adjustment)
                    elseif xA == "right" then
                        local adjustment1 = (((Map.map.width - Map.map.locOffsetX) * Map.map.tilewidth) * Map.map.layers[i].properties.scaleX) - ((Map.map.width - Map.map.locOffsetX) * Map.map.tilewidth)
                        local adjustment2 = (cameraX - rightConstraint) - ((cameraX - rightConstraint) * Map.map.layers[i].parallaxX)
                        levelPosX = ((cameraX + adjustment1) - adjustment2)
                    end						
                    if yA == "center" then
                        local adjustment1 = (((Map.map.height * Map.map.tileheight * 0.5) - (Map.map.locOffsetY * Map.map.tileheight * 0.5)) * Map.map.layers[i].properties.scaleY) - ((Map.map.height * Map.map.tileheight * 0.5) - (Map.map.locOffsetY * Map.map.tileheight * 0.5))
                        local adjustment2 = (cameraY - ((Map.map.height * Map.map.tileheight * 0.5) - (Map.map.locOffsetY * Map.map.tileheight * 0.5))) - ((cameraY - ((Map.map.height * Map.map.tileheight * 0.5) - (Map.map.locOffsetY * Map.map.tileheight * 0.5))) * Map.map.layers[i].parallaxY)
                        levelPosY = ((cameraY + adjustment1) - adjustment2)
                    elseif yA == "top" then
                        local adjustment = (cameraY - topConstraint) - ((cameraY - topConstraint) * Map.map.layers[i].parallaxY)
                        levelPosY = (cameraY - adjustment)
                    elseif yA == "bottom" then
                        local adjustment1 = (((Map.map.height - Map.map.locOffsetY) * Map.map.tileheight) * Map.map.layers[i].properties.scaleY) - ((Map.map.height - Map.map.locOffsetY) * Map.map.tileheight)
                        local adjustment2 = (cameraY - bottomConstraint) - ((cameraY - bottomConstraint) * Map.map.layers[i].parallaxY)
                        levelPosY = ((cameraY + adjustment1) - adjustment2)
                    end							
                    local deltaX = levelPosX + ((Map.map.tilewidth / 2 * Map.map.layers[i].properties.scaleX) - (Map.map.tilewidth / 2)) - cameraX * Map.map.layers[i].properties.scaleX
                    local deltaY = levelPosY + ((Map.map.tileheight / 2 * Map.map.layers[i].properties.scaleY) - (Map.map.tileheight / 2)) - cameraY * Map.map.layers[i].properties.scaleY	
                    local isoVector = Map.isoVector(deltaX, deltaY)						
                    Map.masterGroup[i].x = (Map.masterGroup[Map.refLayer].x * Map.map.layers[i].properties.scaleX) - isoVector[1]
                    Map.masterGroup[i].y = (Map.masterGroup[Map.refLayer].y * Map.map.layers[i].properties.scaleY) - isoVector[2]		
                end
            end	
        else
            if Camera.refMove then
                local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                local cameraX, cameraY = Map.masterGroup[Map.refLayer]:contentToLocal(tempX, tempY)
                local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
                local cameraLocY = math.ceil(cameraY / Map.map.tileheight)					
                local velX = Camera.deltaX[Map.refLayer][1]
                local velY = Camera.deltaY[Map.refLayer][1]
                local tempVelX = Camera.deltaX[Map.refLayer][1]
                local tempVelY = Camera.deltaY[Map.refLayer][1]					
                local check = #Map.map.layers
                for i = 1, #Map.map.layers, 1 do
                    if Camera.isCameraMoving[i] then
                        if Camera.parallaxToggle[i] then
                            finalVelX[i] = tempVelX * Map.map.layers[i].parallaxX
                            finalVelY[i] = tempVelY * Map.map.layers[i].parallaxY
                            cameraVelX[i] = tempVelX * Map.map.layers[i].parallaxX
                            cameraVelY[i] = tempVelY * Map.map.layers[i].parallaxY
                        else
                            finalVelX[i] = tempVelX
                            finalVelY[i] = tempVelY
                            cameraVelX[i] = tempVelX
                            cameraVelY[i] = tempVelY
                        end
                    end						
                    table.remove(Camera.deltaX[i], 1)
                    table.remove(Camera.deltaY[i], 1)
                    if not Camera.deltaX[i][1] then
                        check = check - 1
                        Camera.isCameraMoving[i] = false
                        Camera.parallaxToggle[i] = true
                        --Camera.refMove = false
                        --Sprites.holdSprite = nil
                    end
                end					
                if Camera.cameraFocus and not Sprites.holdSprite then
                    for i = 1, #Map.map.layers, 1 do
                        Camera.cameraFocus.cameraOffsetX[i] = Camera.cameraFocus.cameraOffsetX[i] + finalVelX[Map.refLayer]
                        Camera.cameraFocus.cameraOffsetY[i] = Camera.cameraFocus.cameraOffsetY[i] + finalVelY[Map.refLayer]
                    end
                end						
                if check == 0 and Camera.cameraOnComplete[1] then
                    local tempOnComplete = Camera.cameraOnComplete[1]
                    Camera.cameraOnComplete = {}
                    local event = { name = "cameraMoveComplete", levelPosX = cameraX, 
                        levelPosY = cameraY, 
                        locX = cameraLocX, 
                        locY = cameraLocY
                    }
                    tempOnComplete(event)
                end
            else					
                for i = 1, #Map.map.layers, 1 do
                    if Camera.isCameraMoving[i] then
                        local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                        local cameraX, cameraY = Map.masterGroup[i]:contentToLocal(tempX, tempY)
                        local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
                        local cameraLocY = math.ceil(cameraY / Map.map.tileheight)						
                        local velX = Camera.deltaX[i][1]
                        local velY = Camera.deltaY[i][1]
                        local tempVelX = Camera.deltaX[i][1]
                        local tempVelY = Camera.deltaY[i][1]
                        if Camera.parallaxToggle[i] or Camera.parallaxToggle[i] == nil then
                            finalVelX[i] = tempVelX * Map.map.layers[i].parallaxX
                            finalVelY[i] = tempVelY * Map.map.layers[i].parallaxY
                        else
                            finalVelX[i] = tempVelX
                            finalVelY[i] = tempVelY
                        end							
                        if Camera.cameraFocus and not Sprites.holdSprite then
                            Camera.cameraFocus.cameraOffsetX[i] = Camera.cameraFocus.cameraOffsetX[i] + finalVelX[i]
                            Camera.cameraFocus.cameraOffsetY[i] = Camera.cameraFocus.cameraOffsetY[i] + finalVelY[i]
                        end						
                        table.remove(Camera.deltaX[i], 1)
                        table.remove(Camera.deltaY[i], 1)
                        if not Camera.deltaX[i][1] then
                            Camera.isCameraMoving[i] = false
                            Camera.parallaxToggle[i] = true
                            --Sprites.holdSprite = nil
                            if Camera.cameraOnComplete[i] then
                                local tempOnComplete = Camera.cameraOnComplete[i]
                                Camera.cameraOnComplete[i] = nil
                                local event = { name = "cameraLayerMoveComplete", layer = i, 
                                    levelPosX = cameraX, 
                                    levelPosY = cameraY, 
                                    locX = cameraLocX, 
                                    locY = cameraLocY
                                }
                                tempOnComplete(event)
                            end
                        end
                    end
                end
            end
            
            --FOLLOW SPRITE
            local followingSprite = false
            if Camera.cameraFocus and not Sprites.holdSprite then
                for i = 1, #Map.map.layers, 1 do
                    local tempX, tempY, cameraX, cameraY, velX, velY
                    if Map.map.layers[i].toggleParallax == true or Map.map.layers[i].parallaxX ~= 1 or Map.map.layers[i].parallaxY ~= 1 then
                        tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                        cameraX, cameraY = Map.masterGroup[Map.refLayer]:contentToLocal(tempX, tempY)
                        velX = finalVelX[Map.refLayer] or 0
                        velY = finalVelY[Map.refLayer] or 0
                    else
                        tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                        cameraX, cameraY = Map.masterGroup[i]:contentToLocal(tempX, tempY)
                        velX = finalVelX[i] or 0
                        velY = finalVelY[i] or 0
                    end
                    local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
                    local cameraLocY = math.ceil(cameraY / Map.map.tileheight)
                    local fX = Camera.cameraFocus.x
                    local fY = Camera.cameraFocus.y
                    if cameraX + velX ~= fX + Camera.cameraFocus.cameraOffsetX[i] then
                        if not Camera.override[i] then
                            finalVelX[i] = ((fX + Camera.cameraFocus.cameraOffsetX[i]) - (cameraX)) * Map.map.layers[i].parallaxX
                            followingSprite = true
                        end
                    end
                    if cameraY + velY ~= fY + Camera.cameraFocus.cameraOffsetY[i] then
                        if not Camera.override[i] then
                            finalVelY[i] = ((fY + Camera.cameraFocus.cameraOffsetY[i]) - (cameraY)) * Map.map.layers[i].parallaxY
                            followingSprite = true
                        end
                    end
                end
            end
            
            --Clear constraint variables: Camera.override, Sprites.holdSprite
            local checkHoldSprite = 0
            for i = 1, #Map.map.layers, 1 do
                if Camera.override[i] and (not Camera.deltaX[i] or not Camera.deltaX[i][1]) then
                    Camera.override[i] = false
                end
                if not Camera.deltaX[i] or not Camera.deltaX[i][1] then
                    checkHoldSprite = checkHoldSprite + 1
                end
            end
            if checkHoldSprite == #Map.map.layers and Sprites.holdSprite then
                Sprites.holdSprite = false
            end
            
            --APPLY CONSTRAINTS CONTINUOUSLY
            local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
            local cameraX, cameraY = Map.masterGroup[Map.refLayer]:contentToLocal(tempX, tempY)
            local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
            local cameraLocY = math.ceil(cameraY / Map.map.tileheight)
            
            --calculate constraints
            local angle = Map.masterGroup.rotation + Map.masterGroup[Map.refLayer].rotation
            while angle >= 360 do
                angle = angle - 360
            end
            while angle < 0 do
                angle = angle + 360
            end				
            local topLeftT, topRightT, bottomRightT, bottomLeftT
            topLeftT = {Map.masterGroup.parent:localToContent(Screen.screenLeft, Screen.screenTop)}
            topRightT = {Map.masterGroup.parent:localToContent(Screen.screenRight, Screen.screenTop)}
            bottomRightT = {Map.masterGroup.parent:localToContent(Screen.screenRight, Screen.screenBottom)}
            bottomLeftT = {Map.masterGroup.parent:localToContent(Screen.screenLeft, Screen.screenBottom)}				
            local topLeft, topRight, bottomRight, bottomLeft
            if angle >= 0 and angle < 90 then
                topLeft = {Map.masterGroup[Map.refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
                topRight = {Map.masterGroup[Map.refLayer]:contentToLocal(topRightT[1], topRightT[2])}
                bottomRight = {Map.masterGroup[Map.refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                bottomLeft = {Map.masterGroup[Map.refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
            elseif angle >= 90 and angle < 180 then
                topLeft = {Map.masterGroup[Map.refLayer]:contentToLocal(topRightT[1], topRightT[2])}
                topRight = {Map.masterGroup[Map.refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                bottomRight = {Map.masterGroup[Map.refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                bottomLeft = {Map.masterGroup[Map.refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
            elseif angle >= 180 and angle < 270 then
                topLeft = {Map.masterGroup[Map.refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                topRight = {Map.masterGroup[Map.refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                bottomRight = {Map.masterGroup[Map.refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
                bottomLeft = {Map.masterGroup[Map.refLayer]:contentToLocal(topRightT[1], topRightT[2])}
            elseif angle >= 270 and angle < 360 then
                topLeft = {Map.masterGroup[Map.refLayer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                topRight = {Map.masterGroup[Map.refLayer]:contentToLocal(topLeftT[1], topLeftT[2])}
                bottomRight = {Map.masterGroup[Map.refLayer]:contentToLocal(topRightT[1], topRightT[2])}
                bottomLeft = {Map.masterGroup[Map.refLayer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
            end
            
            for i = 1, #Map.map.layers, 1 do
                if not Camera.refMove and ((not followingSprite or Map.masterGroup[i].vars.constrainLayer) and not Map.masterGroup[i].vars.alignment) then
                    local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                    cameraX, cameraY = Map.masterGroup[i]:contentToLocal(tempX, tempY)
                    cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
                    cameraLocY = math.ceil(cameraY / Map.map.tileheight)
                    
                    --calculate constraints
                    angle = Map.masterGroup.rotation + Map.masterGroup[i].rotation
                    while angle >= 360 do
                        angle = angle - 360
                    end
                    while angle < 0 do
                        angle = angle + 360
                    end						
                    if angle >= 0 and angle < 90 then
                        topLeft = {Map.masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
                        topRight = {Map.masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
                        bottomRight = {Map.masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                        bottomLeft = {Map.masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                    elseif angle >= 90 and angle < 180 then
                        topLeft = {Map.masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
                        topRight = {Map.masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                        bottomRight = {Map.masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                        bottomLeft = {Map.masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
                    elseif angle >= 180 and angle < 270 then
                        topLeft = {Map.masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                        topRight = {Map.masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                        bottomRight = {Map.masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
                        bottomLeft = {Map.masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
                    elseif angle >= 270 and angle < 360 then
                        topLeft = {Map.masterGroup[i]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                        topRight = {Map.masterGroup[i]:contentToLocal(topLeftT[1], topLeftT[2])}
                        bottomRight = {Map.masterGroup[i]:contentToLocal(topRightT[1], topRightT[2])}
                        bottomLeft = {Map.masterGroup[i]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                    end
                end
                local left, top, right, bottom
                if topLeft[1] < bottomLeft[1] then
                    left = topLeft[1]
                else
                    left = bottomLeft[1]
                end
                if topLeft[2] < topRight[2] then
                    top = topLeft[2]
                else
                    top = topRight[2]
                end
                if topRight[1] > bottomRight[1] then
                    right = topRight[1]
                else
                    right = bottomRight[1]
                end
                if bottomRight[2] > bottomLeft[2] then
                    bottom = bottomRight[2]
                else
                    bottom = bottomLeft[2]
                end	
                local leftConstraint, topConstraint, rightConstraint, bottomConstraint
                if Camera.constrainLeft[i] then
                    leftConstraint = Camera.constrainLeft[i] + (cameraX - left)
                end
                if Camera.constrainTop[i] then
                    topConstraint = Camera.constrainTop[i] + (cameraY - top)
                end
                if Camera.constrainRight[i] then
                    rightConstraint = Camera.constrainRight[i] - (right - cameraX)
                end
                if Camera.constrainBottom[i] then
                    bottomConstraint = Camera.constrainBottom[i] - (bottom - cameraY)
                end						
                if (leftConstraint and rightConstraint) and (leftConstraint > rightConstraint) then
                    local temp = (leftConstraint + rightConstraint) / 2
                    leftConstraint = temp
                    rightConstraint = temp
                end
                if (topConstraint and bottomConstraint) and (topConstraint > bottomConstraint) then
                    local temp = (topConstraint + bottomConstraint) / 2
                    topConstraint = temp
                    bottomConstraint = temp
                end					
                --print(Map.masterGroup[i].vars.alignment)
                if not Map.masterGroup[i].vars.alignment then
                    local velX = finalVelX[i] or 0
                    local velY = finalVelY[i] or 0
                    local tempVelX = velX
                    local tempVelY = velY					
                    if not Camera.override[i] then
                        if leftConstraint then
                            if cameraX + velX / Map.map.layers[i].parallaxX < leftConstraint then
                                tempVelX = (leftConstraint - cameraX) * Map.map.layers[i].parallaxX
                            end
                            if Camera.cameraFocus and Camera.cameraFocus.levelPosX + Camera.cameraFocus.cameraOffsetX[i] < leftConstraint then
                                Camera.cameraFocus.cameraOffsetX[i] = leftConstraint - Camera.cameraFocus.levelPosX
                                if Camera.cameraFocus.levelPosX + Camera.cameraFocus.cameraOffsetX[i] > Camera.cameraFocus.levelPosX and (cameraVelX[i] or 0) <= 0 then
                                    Camera.cameraFocus.cameraOffsetX[i] = 0
                                end
                            end
                        end
                        if rightConstraint then
                            if cameraX + velX / Map.map.layers[i].parallaxX > rightConstraint then
                                tempVelX = (rightConstraint - cameraX) * Map.map.layers[i].parallaxX
                            end
                            if Camera.cameraFocus and Camera.cameraFocus.levelPosX + Camera.cameraFocus.cameraOffsetX[i] > rightConstraint then
                                Camera.cameraFocus.cameraOffsetX[i] = rightConstraint - Camera.cameraFocus.levelPosX
                                if Camera.cameraFocus.levelPosX + Camera.cameraFocus.cameraOffsetX[i] < Camera.cameraFocus.levelPosX and (cameraVelX[i] or 0) >= 0 then
                                    Camera.cameraFocus.cameraOffsetX[i] = 0
                                end
                            end
                        end
                        if topConstraint then
                            if cameraY + velY / Map.map.layers[i].parallaxY < topConstraint then
                                tempVelY = (topConstraint - cameraY) * Map.map.layers[i].parallaxY
                            end
                            if Camera.cameraFocus and Camera.cameraFocus.levelPosY + Camera.cameraFocus.cameraOffsetY[i] < topConstraint then
                                Camera.cameraFocus.cameraOffsetY[i] = topConstraint - Camera.cameraFocus.levelPosY
                                if Camera.cameraFocus.levelPosY + Camera.cameraFocus.cameraOffsetY[i] > Camera.cameraFocus.levelPosY and (cameraVelY[i] or 0) <= 0 then
                                    Camera.cameraFocus.cameraOffsetY[i] = 0
                                end
                            end
                        end
                        if bottomConstraint then
                            if cameraY + velY / Map.map.layers[i].parallaxY > bottomConstraint then
                                tempVelY = (bottomConstraint - cameraY) * Map.map.layers[i].parallaxY
                            end
                            if Camera.cameraFocus and Camera.cameraFocus.levelPosY + Camera.cameraFocus.cameraOffsetY[i] > bottomConstraint then
                                Camera.cameraFocus.cameraOffsetY[i] = bottomConstraint - Camera.cameraFocus.levelPosY
                                if Camera.cameraFocus.levelPosY + Camera.cameraFocus.cameraOffsetY[i] < Camera.cameraFocus.levelPosY and (cameraVelY[i] or 0) >= 0 then
                                    Camera.cameraFocus.cameraOffsetY[i] = 0
                                end
                            end
                        end
                    end				
                    Map.masterGroup[i]:translate(tempVelX * -1 * Map.map.layers[i].properties.scaleX, tempVelY * -1 * Map.map.layers[i].properties.scaleY)
                else
                    if not leftConstraint then
                        leftConstraint = (0 - (Map.map.locOffsetX * Map.map.tilewidth)) + (cameraX - left)
                    end
                    if not topConstraint then
                        topConstraint = (0 - (Map.map.locOffsetY * Map.map.tileheight)) + (cameraY - top)
                    end
                    if not rightConstraint then
                        rightConstraint = (Map.map.width * Map.map.tilewidth) - (right - cameraX)
                    end
                    if not bottomConstraint then
                        bottomConstraint = (Map.map.height * Map.map.tileheight) - (bottom - cameraY)	
                    end			
                    if (leftConstraint and rightConstraint) and (leftConstraint > rightConstraint) then
                        local temp = (leftConstraint + rightConstraint) / 2
                        leftConstraint = temp
                        rightConstraint = temp
                    end
                    if (topConstraint and bottomConstraint) and (topConstraint > bottomConstraint) then
                        local temp = (topConstraint + bottomConstraint) / 2
                        topConstraint = temp
                        bottomConstraint = temp
                    end	
                    local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                    local cameraX, cameraY = Map.masterGroup[Map.refLayer]:contentToLocal(tempX, tempY)
                    local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
                    local cameraLocY = math.ceil(cameraY / Map.map.tileheight)
                    local xA = Map.masterGroup[i].vars.alignment[1]
                    local yA = Map.masterGroup[i].vars.alignment[2]	
                    --print(i, xA, yA)					
                    if xA == "center" then
                        --local adjustment1 = (((Map.map.width * Map.map.tilewidth * 0.5) - (Map.map.locOffsetX * Map.map.tilewidth * 0.5)) * Map.map.layers[i].properties.scaleX) - ((Map.map.width * Map.map.tilewidth * 0.5) - (Map.map.locOffsetX * Map.map.tilewidth * 0.5))
                        --local adjustment2 = (cameraX - ((Map.map.width * Map.map.tilewidth * 0.5) - (Map.map.locOffsetX * Map.map.tilewidth * 0.5))) - ((cameraX - ((Map.map.width * Map.map.tilewidth * 0.5) - (Map.map.locOffsetX * Map.map.tilewidth * 0.5))) * Map.map.layers[i].parallaxX)
                        --print(Map.map.layers[i].parallaxX)
                        --local adjustment1 = (((Map.map.layers[i].width * Map.map.tilewidth * 0.5) - (Map.map.locOffsetX * Map.map.tilewidth * 0.5)) * Map.map.layers[i].properties.scaleX) - ((Map.map.layers[i].width * Map.map.tilewidth * 0.5) - (Map.map.locOffsetX * Map.map.tilewidth * 0.5))
                        local adjustment1 = (((Map.map.layers[i].width * Map.map.tilewidth * 0.5) - (Map.map.locOffsetX * Map.map.tilewidth * 0.5)) * Map.map.layers[i].properties.scaleX) - ((Map.map.width * Map.map.tilewidth * 0.5) - (Map.map.locOffsetX * Map.map.tilewidth * 0.5))
                        local adjustment2 = (cameraX - ((Map.map.width * Map.map.tilewidth * 0.5) - (Map.map.locOffsetX * Map.map.tilewidth * 0.5))) - ((cameraX - ((Map.map.width * Map.map.tilewidth * 0.5) - (Map.map.locOffsetX * Map.map.tilewidth * 0.5))) * Map.map.layers[i].parallaxX)
                        Map.masterGroup[i].x = ((cameraX + adjustment1) - adjustment2) * -1
                    elseif xA == "left" then
                        local adjustment = (cameraX - leftConstraint) - ((cameraX - leftConstraint) * Map.map.layers[i].parallaxX)
                        Map.masterGroup[i].x = (cameraX - adjustment) * -1
                    elseif xA == "right" then
                        --local adjustment1 = (((Map.map.width - Map.map.locOffsetX) * Map.map.tilewidth) * Map.map.layers[i].properties.scaleX) - ((Map.map.width - Map.map.locOffsetX) * Map.map.tilewidth)
                        --local adjustment2 = (cameraX - rightConstraint) - ((cameraX - rightConstraint) * Map.map.layers[i].parallaxX)
                        local adjustment1 = (((Map.map.layers[i].width - Map.map.locOffsetX) * Map.map.tilewidth) * Map.map.layers[i].properties.scaleX) - ((Map.map.width - Map.map.locOffsetX) * Map.map.tilewidth)
                        local adjustment2 = (cameraX - rightConstraint) - ((cameraX - rightConstraint) * Map.map.layers[i].parallaxX)
                        Map.masterGroup[i].x = ((cameraX + adjustment1) - adjustment2) * -1
                    end						
                    if yA == "center" then
                        --local adjustment1 = (((Map.map.height * Map.map.tileheight * 0.5) - (Map.map.locOffsetY * Map.map.tileheight * 0.5)) * Map.map.layers[i].properties.scaleY) - ((Map.map.height * Map.map.tileheight * 0.5) - (Map.map.locOffsetY * Map.map.tileheight * 0.5))
                        --local adjustment2 = (cameraY - ((Map.map.height * Map.map.tileheight * 0.5) - (Map.map.locOffsetY * Map.map.tileheight * 0.5))) - ((cameraY - ((Map.map.height * Map.map.tileheight * 0.5) - (Map.map.locOffsetY * Map.map.tileheight * 0.5))) * Map.map.layers[i].parallaxY)
                        local adjustment1 = (((Map.map.layers[i].height * Map.map.tileheight * 0.5) - (Map.map.locOffsetY * Map.map.tileheight * 0.5)) * Map.map.layers[i].properties.scaleY) - ((Map.map.height * Map.map.tileheight * 0.5) - (Map.map.locOffsetY * Map.map.tileheight * 0.5))
                        local adjustment2 = (cameraY - ((Map.map.height * Map.map.tileheight * 0.5) - (Map.map.locOffsetY * Map.map.tileheight * 0.5))) - ((cameraY - ((Map.map.height * Map.map.tileheight * 0.5) - (Map.map.locOffsetY * Map.map.tileheight * 0.5))) * Map.map.layers[i].parallaxY)
                        Map.masterGroup[i].y = ((cameraY + adjustment1) - adjustment2) * -1
                    elseif yA == "top" then
                        local adjustment = (cameraY - topConstraint) - ((cameraY - topConstraint) * Map.map.layers[i].parallaxY)
                        Map.masterGroup[i].y = (cameraY - adjustment) * -1
                    elseif yA == "bottom" then
                        --local adjustment1 = (((Map.map.height - Map.map.locOffsetY) * Map.map.tileheight) * Map.map.layers[i].properties.scaleY) - ((Map.map.height - Map.map.locOffsetY) * Map.map.tileheight)
                        --local adjustment2 = (cameraY - bottomConstraint) - ((cameraY - bottomConstraint) * Map.map.layers[i].parallaxY)
                        local adjustment1 = (((Map.map.layers[i].height - Map.map.locOffsetY) * Map.map.tileheight) * Map.map.layers[i].properties.scaleY) - ((Map.map.height - Map.map.locOffsetY) * Map.map.tileheight)
                        local adjustment2 = (cameraY - bottomConstraint) - ((cameraY - bottomConstraint) * Map.map.layers[i].parallaxY)
                        Map.masterGroup[i].y = ((cameraY + adjustment1) - adjustment2) * -1
                    end
                end
            end
            
            if Camera.refMove and not Camera.deltaX[Map.refLayer][1] then
                Camera.refMove = false
            end				
        end
    end
    
    --WRAP CAMERA
    for i = 1, #Map.map.layers, 1 do
        if not Camera.isCameraMoving[i] then
            local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
            local cameraX, cameraY = Map.masterGroup[i]:contentToLocal(tempX, tempY)
            local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
            local cameraLocY = math.ceil(cameraY / Map.map.tileheight)				
            if Map.map.orientation == Map.Type.Isometric then
                local isoPos = Map.isoUntransform2(cameraX, cameraY)
                cameraX = isoPos[1]
                cameraY = isoPos[2]					
                if Camera.layerWrapX[i] then
                    if cameraX < 0 then
                        local vector = Map.isoVector(Map.map.layers[i].width * Map.map.tilewidth, 0)
                        Map.masterGroup[i]:translate(vector[1] * -1 * Map.map.layers[i].properties.scaleX, vector[2] * -1 * Map.map.layers[i].properties.scaleY)
                    elseif cameraX > Map.map.layers[i].width * Map.map.tilewidth then
                        local vector = Map.isoVector(Map.map.layers[i].width * Map.map.tilewidth * -1, 0)
                        Map.masterGroup[i]:translate(vector[1] * -1 * Map.map.layers[i].properties.scaleX, vector[2] * -1 * Map.map.layers[i].properties.scaleY)
                    end
                end
                if Camera.layerWrapY[i] then
                    if cameraY < 0 then
                        local vector = Map.isoVector(0, Map.map.layers[i].height * Map.map.tileheight)
                        Map.masterGroup[i]:translate(vector[1] * -1 * Map.map.layers[i].properties.scaleX, vector[2] * -1 * Map.map.layers[i].properties.scaleY)
                    elseif cameraY > Map.map.layers[i].height * Map.map.tileheight then
                        local vector = Map.isoVector(0, Map.map.layers[i].height * Map.map.tileheight * -1)
                        Map.masterGroup[i]:translate(vector[1] * -1 * Map.map.layers[i].properties.scaleX, vector[2] * -1 * Map.map.layers[i].properties.scaleY)
                    end
                end
            else
                if Camera.layerWrapX[i] then
                    if cameraX < 0 then
                        Map.masterGroup[i].x = Map.masterGroup[i].x + Map.map.layers[i].width * Map.map.tilewidth * -1 * Map.map.layers[i].properties.scaleX
                    elseif cameraX > Map.map.layers[i].width * Map.map.tilewidth then
                        Map.masterGroup[i].x = Map.masterGroup[i].x - Map.map.layers[i].width * Map.map.tilewidth * -1 * Map.map.layers[i].properties.scaleX
                    end
                end
                if Camera.layerWrapY[i] then
                    if cameraY < 0 then
                        Map.masterGroup[i].y = Map.masterGroup[i].y + Map.map.layers[i].height * Map.map.tileheight * -1 * Map.map.layers[i].properties.scaleY
                    elseif cameraY > Map.map.layers[i].height * Map.map.tileheight then
                        Map.masterGroup[i].y = Map.masterGroup[i].y - Map.map.layers[i].height * Map.map.tileheight * -1 * Map.map.layers[i].properties.scaleY
                    end
                end
            end
        end
    end
    
    --CULL AND RENDER
    if Map.map.orientation == Map.Type.Isometric then
        for layer = 1, #Map.map.layers, 1 do
            local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
            local cameraX, cameraY = Map.masterGroup[layer]:contentToLocal(tempX, tempY)
            local isoPos = Map.isoUntransform2(cameraX, cameraY)
            cameraX = isoPos[1]
            cameraY = isoPos[2]
            local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
            local cameraLocY = math.ceil(cameraY / Map.map.tileheight)				
            Camera.McameraX, Camera.McameraY = cameraX, cameraY
            Camera.McameraLocX = cameraLocX
            Camera.McameraLocY = cameraLocY
            if not Map.masterGroup[layer].vars.camera then	
                --Render view if view does not exist
                Map.totalRects[layer] = 0
                local angle = Map.masterGroup.rotation + Map.masterGroup[layer].rotation
                while angle >= 360 do
                    angle = angle - 360
                end
                while angle < 0 do
                    angle = angle + 360
                end					
                local topLeftT, topRightT, bottomRightT, bottomLeftT
                topLeftT = {Map.masterGroup.parent:localToContent(Screen.screenLeft - Camera.cullingMargin[1], Screen.screenTop - Camera.cullingMargin[2])}
                topRightT = {Map.masterGroup.parent:localToContent(Screen.screenRight + Camera.cullingMargin[3], Screen.screenTop - Camera.cullingMargin[2])}
                bottomRightT = {Map.masterGroup.parent:localToContent(Screen.screenRight + Camera.cullingMargin[3], Screen.screenBottom + Camera.cullingMargin[4])}
                bottomLeftT = {Map.masterGroup.parent:localToContent(Screen.screenLeft - Camera.cullingMargin[1], Screen.screenBottom + Camera.cullingMargin[4])}					
                local topLeft, topRight, bottomRight, bottomLeft
                if angle >= 0 and angle < 90 then
                    topLeft = {Map.masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
                    topRight = {Map.masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
                    bottomRight = {Map.masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                    bottomLeft = {Map.masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                elseif angle >= 90 and angle < 180 then
                    topLeft = {Map.masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
                    topRight = {Map.masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                    bottomRight = {Map.masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                    bottomLeft = {Map.masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
                elseif angle >= 180 and angle < 270 then
                    topLeft = {Map.masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                    topRight = {Map.masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                    bottomRight = {Map.masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
                    bottomLeft = {Map.masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
                elseif angle >= 270 and angle < 360 then
                    topLeft = {Map.masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                    topRight = {Map.masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
                    bottomRight = {Map.masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
                    bottomLeft = {Map.masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                end
                topLeft = Map.isoUntransform2(topLeft[1], topLeft[2])
                topRight = Map.isoUntransform2(topRight[1], topRight[2])
                bottomRight = Map.isoUntransform2(bottomRight[1], bottomRight[2])
                bottomLeft = Map.isoUntransform2(bottomLeft[1], bottomLeft[2])					
                local left, top, right, bottom
                left = math.ceil(topLeft[1] / Map.map.tilewidth) - 1
                top = math.ceil(topRight[2] / Map.map.tileheight) - 1
                right = math.ceil(bottomRight[1] / Map.map.tilewidth) + 2
                bottom = math.ceil(bottomLeft[2] / Map.map.tileheight) + 2					
                Map.masterGroup[layer].vars.camera = {left, top, right, bottom}					
                for locX = left, right, 1 do
                    for locY = top, bottom, 1 do										
                        Core.updateTile({locX = locX, locY = locY, layer = layer})
                        --drawLargeTile(locX, locY, layer)
                    end
                end
            else		
                --Cull and Render
                local prevLeft = Map.masterGroup[layer].vars.camera[1]
                local prevTop = Map.masterGroup[layer].vars.camera[2]
                local prevRight = Map.masterGroup[layer].vars.camera[3]
                local prevBottom = Map.masterGroup[layer].vars.camera[4]							
                local angle = Map.masterGroup.rotation + Map.masterGroup[layer].rotation
                while angle >= 360 do
                    angle = angle - 360
                end
                while angle < 0 do
                    angle = angle + 360
                end					
                local topLeftT, topRightT, bottomRightT, bottomLeftT
                topLeftT = {Map.masterGroup.parent:localToContent(Screen.screenLeft - Camera.cullingMargin[1], Screen.screenTop - Camera.cullingMargin[2])}
                topRightT = {Map.masterGroup.parent:localToContent(Screen.screenRight + Camera.cullingMargin[3], Screen.screenTop - Camera.cullingMargin[2])}
                bottomRightT = {Map.masterGroup.parent:localToContent(Screen.screenRight + Camera.cullingMargin[3], Screen.screenBottom + Camera.cullingMargin[4])}
                bottomLeftT = {Map.masterGroup.parent:localToContent(Screen.screenLeft - Camera.cullingMargin[1], Screen.screenBottom + Camera.cullingMargin[4])}					
                local topLeft, topRight, bottomRight, bottomLeft
                if angle >= 0 and angle < 90 then
                    topLeft = {Map.masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
                    topRight = {Map.masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
                    bottomRight = {Map.masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                    bottomLeft = {Map.masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                elseif angle >= 90 and angle < 180 then
                    topLeft = {Map.masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
                    topRight = {Map.masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                    bottomRight = {Map.masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                    bottomLeft = {Map.masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
                elseif angle >= 180 and angle < 270 then
                    topLeft = {Map.masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                    topRight = {Map.masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                    bottomRight = {Map.masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
                    bottomLeft = {Map.masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
                elseif angle >= 270 and angle < 360 then
                    topLeft = {Map.masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                    topRight = {Map.masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
                    bottomRight = {Map.masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
                    bottomLeft = {Map.masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                end
                topLeft = Map.isoUntransform2(topLeft[1], topLeft[2])
                topRight = Map.isoUntransform2(topRight[1], topRight[2])
                bottomRight = Map.isoUntransform2(bottomRight[1], bottomRight[2])
                bottomLeft = Map.isoUntransform2(bottomLeft[1], bottomLeft[2])					
                local left, top, right, bottom
                left = math.ceil(topLeft[1] / Map.map.tilewidth) - 1
                top = math.ceil(topRight[2] / Map.map.tileheight) - 1
                right = math.ceil(bottomRight[1] / Map.map.tilewidth) + 2
                bottom = math.ceil(bottomLeft[2] / Map.map.tileheight) + 2					
                Map.masterGroup[layer].vars.camera = {left, top, right, bottom}
                if left > prevRight or right < prevLeft or top > prevBottom or bottom < prevTop then
                    for locX = prevLeft, prevRight, 1 do
                        for locY = prevTop, prevBottom, 1 do										
                            Core.updateTile({locX = locX, locY = locY, layer = layer, tile = -1})
                        end
                    end
                    for locX = left, right, 1 do
                        for locY = top, bottom, 1 do										
                            Core.updateTile({locX = locX, locY = locY, layer = layer})
                        end
                    end
                else
                    --left
                    if left > prevLeft then		--cull
                        local tLeft = left
                        for locX = prevLeft, tLeft - 1, 1 do
                            for locY = prevTop, prevBottom, 1 do
                                Core.updateTile({locX = locX, locY = locY, layer = layer, tile = -1})
                            end
                        end
                    elseif left < prevLeft then	--render
                        local tLeft = prevLeft
                        for locX = left, tLeft - 1, 1 do
                            for locY = top, bottom, 1 do
                                Core.updateTile({locX = locX, locY = locY, layer = layer})
                            end
                        end
                    end				
                    --top
                    if top > prevTop then		--cull
                        local tTop = top
                        for locX = prevLeft, prevRight, 1 do
                            for locY = prevTop, tTop - 1, 1 do
                                Core.updateTile({locX = locX, locY = locY, layer = layer, tile = -1})
                            end
                        end
                    elseif top < prevTop then	--render
                        local tTop = prevTop
                        for locX = left, right, 1 do
                            for locY = top, tTop - 1, 1 do
                                Core.updateTile({locX = locX, locY = locY, layer = layer})
                            end
                        end
                    end				
                    --right
                    if right > prevRight then		--render
                        local tRight = prevRight
                        for locX = tRight + 1, right, 1 do
                            for locY = top, bottom, 1 do
                                Core.updateTile({locX = locX, locY = locY, layer = layer})
                            end
                        end
                    elseif right < prevRight then	--cull
                        local tRight = right
                        for locX = tRight + 1, prevRight, 1 do
                            for locY = prevTop, prevBottom, 1 do
                                Core.updateTile({locX = locX, locY = locY, layer = layer, tile = -1})
                            end
                        end
                    end						
                    --bottom
                    if bottom > prevBottom then		--render
                        local tBottom = prevBottom
                        for locX = left, right, 1 do
                            for locY = tBottom + 1, bottom, 1 do
                                Core.updateTile({locX = locX, locY = locY, layer = layer})
                            end
                        end
                    elseif bottom < prevBottom then	--cull
                        local tBottom = bottom
                        for locX = prevLeft, prevRight, 1 do
                            for locY = tBottom + 1, prevBottom, 1 do
                                Core.updateTile({locX = locX, locY = locY, layer = layer, tile = -1})
                            end
                        end
                    end
                end				
            end
        end
    else
        for layer = 1, #Map.map.layers, 1 do
            local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
            local cameraX, cameraY = Map.masterGroup[layer]:contentToLocal(tempX, tempY)
            local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
            local cameraLocY = math.ceil(cameraY / Map.map.tileheight)	
            
            --print(layer, cameraX)
            
            Camera.McameraX, Camera.McameraY = cameraX, cameraY
            Camera.McameraLocX = cameraLocX
            Camera.McameraLocY = cameraLocY
            if not Map.masterGroup[layer].vars.camera then	
                --Render view if view does not exist
                Map.totalRects[layer] = 0
                local angle = Map.masterGroup.rotation + Map.masterGroup[layer].rotation
                while angle >= 360 do
                    angle = angle - 360
                end
                while angle < 0 do
                    angle = angle + 360
                end					
                local topLeftT, topRightT, bottomRightT, bottomLeftT
                topLeftT = {Map.masterGroup.parent:localToContent(Screen.screenLeft - Camera.cullingMargin[1], Screen.screenTop - Camera.cullingMargin[2])}
                topRightT = {Map.masterGroup.parent:localToContent(Screen.screenRight + Camera.cullingMargin[3], Screen.screenTop - Camera.cullingMargin[2])}
                bottomRightT = {Map.masterGroup.parent:localToContent(Screen.screenRight + Camera.cullingMargin[3], Screen.screenBottom + Camera.cullingMargin[4])}
                bottomLeftT = {Map.masterGroup.parent:localToContent(Screen.screenLeft - Camera.cullingMargin[1], Screen.screenBottom + Camera.cullingMargin[4])}				
                local topLeft, topRight, bottomRight, bottomLeft
                if angle >= 0 and angle < 90 then
                    topLeft = {Map.masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
                    topRight = {Map.masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
                    bottomRight = {Map.masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                    bottomLeft = {Map.masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                elseif angle >= 90 and angle < 180 then
                    topLeft = {Map.masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
                    topRight = {Map.masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                    bottomRight = {Map.masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                    bottomLeft = {Map.masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
                elseif angle >= 180 and angle < 270 then
                    topLeft = {Map.masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                    topRight = {Map.masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                    bottomRight = {Map.masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
                    bottomLeft = {Map.masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
                elseif angle >= 270 and angle < 360 then
                    topLeft = {Map.masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                    topRight = {Map.masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
                    bottomRight = {Map.masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
                    bottomLeft = {Map.masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                end
                local left, top, right, bottom
                if topLeft[1] < bottomLeft[1] then
                    left = math.ceil(topLeft[1] / Map.map.tilewidth)
                else
                    left = math.ceil(bottomLeft[1] / Map.map.tilewidth)
                end
                if topLeft[2] < topRight[2] then
                    top = math.ceil(topLeft[2] / Map.map.tileheight)
                else
                    top = math.ceil(topRight[2] / Map.map.tileheight)
                end
                if topRight[1] > bottomRight[1] then
                    right = math.ceil(topRight[1] / Map.map.tilewidth)
                else
                    right = math.ceil(bottomRight[1] / Map.map.tilewidth)
                end
                if bottomRight[2] > bottomLeft[2] then
                    bottom = math.ceil(bottomRight[2] / Map.map.tileheight)
                else
                    bottom = math.ceil(bottomLeft[2] / Map.map.tileheight)
                end				
                Map.masterGroup[layer].vars.camera = {left, top, right, bottom}	
                --print("do1", layer)
                --print(" ", left, prevLeft)
                --print(" ", top, prevTop)
                --print(" ", right, prevRight)
                --print(" ", bottom, prevBottom)				
                for locX = left, right, 1 do
                    for locY = top, bottom, 1 do										
                        Core.updateTile({locX = locX, locY = locY, layer = layer})
                        drawCulledObjects(locX, locY, layer)
                        drawLargeTile(locX, locY, layer)
                    end
                end
                --print("=============")
                ------------
                --print("do", layer)
            else	
                --print("do2", layer)
                --Cull and Render
                local prevLeft = Map.masterGroup[layer].vars.camera[1]
                local prevTop = Map.masterGroup[layer].vars.camera[2]
                local prevRight = Map.masterGroup[layer].vars.camera[3]
                local prevBottom = Map.masterGroup[layer].vars.camera[4]
                local angle = Map.masterGroup.rotation + Map.masterGroup[layer].rotation
                while angle >= 360 do
                    angle = angle - 360
                end
                while angle < 0 do
                    angle = angle + 360
                end					
                local topLeftT, topRightT, bottomRightT, bottomLeftT
                topLeftT = {Map.masterGroup.parent:localToContent(Screen.screenLeft - Camera.cullingMargin[1], Screen.screenTop - Camera.cullingMargin[2])}
                topRightT = {Map.masterGroup.parent:localToContent(Screen.screenRight + Camera.cullingMargin[3], Screen.screenTop - Camera.cullingMargin[2])}
                bottomRightT = {Map.masterGroup.parent:localToContent(Screen.screenRight + Camera.cullingMargin[3], Screen.screenBottom + Camera.cullingMargin[4])}
                bottomLeftT = {Map.masterGroup.parent:localToContent(Screen.screenLeft - Camera.cullingMargin[1], Screen.screenBottom + Camera.cullingMargin[4])}					
                local topLeft, topRight, bottomRight, bottomLeft
                if angle >= 0 and angle < 90 then
                    topLeft = {Map.masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
                    topRight = {Map.masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
                    bottomRight = {Map.masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                    bottomLeft = {Map.masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                elseif angle >= 90 and angle < 180 then
                    topLeft = {Map.masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
                    topRight = {Map.masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                    bottomRight = {Map.masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                    bottomLeft = {Map.masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
                elseif angle >= 180 and angle < 270 then
                    topLeft = {Map.masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                    topRight = {Map.masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                    bottomRight = {Map.masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
                    bottomLeft = {Map.masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
                elseif angle >= 270 and angle < 360 then
                    topLeft = {Map.masterGroup[layer]:contentToLocal(bottomLeftT[1], bottomLeftT[2])}
                    topRight = {Map.masterGroup[layer]:contentToLocal(topLeftT[1], topLeftT[2])}
                    bottomRight = {Map.masterGroup[layer]:contentToLocal(topRightT[1], topRightT[2])}
                    bottomLeft = {Map.masterGroup[layer]:contentToLocal(bottomRightT[1], bottomRightT[2])}
                end
                local left, top, right, bottom
                if topLeft[1] < bottomLeft[1] then
                    left = math.ceil(topLeft[1] / Map.map.tilewidth)
                else
                    left = math.ceil(bottomLeft[1] / Map.map.tilewidth)
                end
                if topLeft[2] < topRight[2] then
                    top = math.ceil(topLeft[2] / Map.map.tileheight)
                else
                    top = math.ceil(topRight[2] / Map.map.tileheight)
                end
                if topRight[1] > bottomRight[1] then
                    right = math.ceil(topRight[1] / Map.map.tilewidth)
                else
                    right = math.ceil(bottomRight[1] / Map.map.tilewidth)
                end
                if bottomRight[2] > bottomLeft[2] then
                    bottom = math.ceil(bottomRight[2] / Map.map.tileheight)
                else
                    bottom = math.ceil(bottomLeft[2] / Map.map.tileheight)
                end						
                Map.masterGroup[layer].vars.camera = {left, top, right, bottom}
                if left > prevRight or right < prevLeft or top > prevBottom or bottom < prevTop then
                    --print("do3", layer, "==================================")
                    --print(" ", left, prevLeft)
                    --print(" ", top, prevTop)
                    --print(" ", right, prevRight)
                    --print(" ", bottom, prevBottom)
                    for locX = prevLeft, prevRight, 1 do
                        for locY = prevTop, prevBottom, 1 do
                            --print("do4")										
                            Core.updateTile({locX = locX, locY = locY, layer = layer, tile = -1})
                            cullLargeTile(locX, locY, layer)
                        end
                    end
                    for locX = left, right, 1 do
                        for locY = top, bottom, 1 do		
                            --print("do5")								
                            Core.updateTile({locX = locX, locY = locY, layer = layer})
                            drawCulledObjects(locX, locY, layer)
                            drawLargeTile(locX, locY, layer)
                        end
                    end
                    --print("=============")
                else
                    --left
                    if left > prevLeft then		--cull
                        local tLeft = left
                        for locX = prevLeft, tLeft - 1, 1 do
                            for locY = prevTop, prevBottom, 1 do
                                Core.updateTile({locX = locX, locY = locY, layer = layer, tile = -1})
                                cullLargeTile(locX, locY, layer)
                            end
                        end
                    elseif left < prevLeft then	--render
                        local tLeft = prevLeft
                        for locX = left, tLeft - 1, 1 do
                            for locY = top, bottom, 1 do
                                Core.updateTile({locX = locX, locY = locY, layer = layer})
                                drawCulledObjects(locX, locY, layer)
                                drawLargeTile(locX, locY, layer)
                            end
                        end
                    end				
                    --top
                    if top > prevTop then		--cull
                        local tTop = top
                        for locX = prevLeft, prevRight, 1 do
                            for locY = prevTop, tTop - 1, 1 do
                                Core.updateTile({locX = locX, locY = locY, layer = layer, tile = -1})
                                cullLargeTile(locX, locY, layer)
                            end
                        end
                    elseif top < prevTop then	--render
                        local tTop = prevTop
                        for locX = left, right, 1 do
                            for locY = top, tTop - 1, 1 do
                                Core.updateTile({locX = locX, locY = locY, layer = layer})
                                drawCulledObjects(locX, locY, layer)
                                drawLargeTile(locX, locY, layer)
                            end
                        end
                    end				
                    --right
                    if right > prevRight then		--render
                        local tRight = prevRight
                        for locX = tRight + 1, right, 1 do
                            for locY = top, bottom, 1 do
                                Core.updateTile({locX = locX, locY = locY, layer = layer})
                                drawCulledObjects(locX, locY, layer)
                                drawLargeTile(locX, locY, layer)
                            end
                        end
                    elseif right < prevRight then	--cull
                        local tRight = right
                        for locX = tRight + 1, prevRight, 1 do
                            for locY = prevTop, prevBottom, 1 do
                                Core.updateTile({locX = locX, locY = locY, layer = layer, tile = -1})
                                cullLargeTile(locX, locY, layer)
                            end
                        end
                    end				
                    --bottom
                    if bottom > prevBottom then		--render
                        local tBottom = prevBottom
                        for locX = left, right, 1 do
                            for locY = tBottom + 1, bottom, 1 do
                                Core.updateTile({locX = locX, locY = locY, layer = layer})
                                drawCulledObjects(locX, locY, layer)
                                drawLargeTile(locX, locY, layer)
                            end
                        end
                    elseif bottom < prevBottom then	--cull
                        local tBottom = bottom
                        for locX = prevLeft, prevRight, 1 do
                            for locY = tBottom + 1, prevBottom, 1 do
                                Core.updateTile({locX = locX, locY = locY, layer = layer, tile = -1})
                                cullLargeTile(locX, locY, layer)
                            end
                        end
                    end
                end				
            end
        end
    end
    
    --PROCESS TILE ANIMATIONS
    if not Core.tileAnimsFrozen then
        for key,value in pairs(Core.syncData) do
            Core.syncData[key].counter = Core.syncData[key].counter - 1
            if Core.syncData[key].counter <= 0 then
                Core.syncData[key].counter = Core.syncData[key].time
                Core.syncData[key].currentFrame = Core.syncData[key].currentFrame + 1
                if Core.syncData[key].currentFrame > #Core.syncData[key].frames then
                    Core.syncData[key].currentFrame = 1
                end
            end
        end
        for key,value in pairs(Map.animatedTiles) do
            if Core.syncData[Map.animatedTiles[key].sync] then
                Map.animatedTiles[key]:setFrame(Core.syncData[Map.animatedTiles[key].sync].currentFrame)
            end
        end
    end
    
    --APPLY HEIGHTMAP
    if Map.enableHeightMap then
        for i = 1, #Map.map.layers, 1 do
            if Map.map.layers[i].heightMap or Map.map.heightMap then
                local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                local cameraX, cameraY = Map.masterGroup[i]:contentToLocal(tempX, tempY)
                local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
                local cameraLocY = math.ceil(cameraY / Map.map.tileheight)
                local mH = Map.map.layers[i].heightMap
                local gH = Map.map.heightMap
                for x = Map.masterGroup[i].vars.camera[1], Map.masterGroup[i].vars.camera[3], 1 do
                    for y = Map.masterGroup[i].vars.camera[2], Map.masterGroup[i].vars.camera[4], 1 do
                        local locX = x
                        local locY = y
                        if locX < 1 - Map.map.locOffsetX then
                            locX = locX + Map.map.layers[i].width
                        end
                        if locX > Map.map.layers[i].width - Map.map.locOffsetX then
                            locX = locX - Map.map.layers[i].width
                        end										
                        if locY < 1 - Map.map.locOffsetY then
                            locY = locY + Map.map.layers[i].height
                        end
                        if locY > Map.map.layers[i].height - Map.map.locOffsetY then
                            locY = locY - Map.map.layers[i].height
                        end
                        if Map.tileObjects[i][locX] and Map.tileObjects[i][locX][locY] then
                            local rect = Map.tileObjects[i][locX][locY]								
                            local rectX = rect.x
                            local rectY = rect.y
                            local tempScaleX = rect.tempScaleX / 2
                            local tempScaleY = rect.tempScaleY / 2
                            local rP = rect.path
                            if rect.heightMap then
                                local hM = rect.heightMap									
                                local x1, y1, x2, y2, x3, y3, x4, y4 = "x1", "y1", "x2", "y2", "x3", "y3", "x4", "y4"
                                local a1, b1, a2, b2, a3, b3, a4, b4 = -1, -1, -1, -1, -1, -1, -1, -1									
                                if Map.enableFlipRotation then
                                    if Map.map.layers[i].flipRotation[locX][locY] then
                                        local command = Map.map.layers[i].flipRotation[locX][locY]
                                        if command == 3 then
                                            x1, y1, x2, y2, x3, y3, x4, y4 = "y4", "x4", "y1", "x1", "y2", "x2", "y3", "x3"
                                            b1, b2, b3, b4 = 1, 1, 1, 1
                                        elseif command == 5 then
                                            x1, y1, x2, y2, x3, y3, x4, y4 = "y2", "x2", "y3", "x3", "y4", "x4", "y1", "x1"
                                            a1, a2, a3, a4 = 1, 1, 1, 1
                                        elseif command == 6 then
                                            x1, y1, x2, y2, x3, y3, x4, y4 = "x3", "y3", "x4", "y4", "x1", "y1", "x2", "y2"
                                            a1, b1, a2, b2, a3, b3, a4, b4 = 1, 1, 1, 1, 1, 1, 1, 1
                                        elseif command == 2 then
                                            x1, y1, x2, y2, x3, y3, x4, y4 = "x2", "y2", "x1", "y1", "x4", "y4", "x3", "y3"
                                            b1, b2, b3, b4 = 1, 1, 1, 1
                                        elseif command == 4 then
                                            x1, y1, x2, y2, x3, y3, x4, y4 = "x4", "y4", "x3", "y3", "x2", "y2", "x1", "y1"
                                            a1, a2, a3, a4 = 1, 1, 1, 1
                                        elseif command == 1 then
                                            x1, y1, x2, y2, x3, y3, x4, y4 = "y1", "x1", "y4", "x4", "y3", "x3", "y2", "x2"
                                        elseif command == 7 then
                                            x1, y1, x2, y2, x3, y3, x4, y4 = "y3", "x3", "y2", "x2", "y1", "x1", "y4", "x4"
                                            a1, b1, a2, b2, a3, b3, a4, b4 = 1, 1, 1, 1, 1, 1, 1, 1
                                        end
                                    end
                                end									
                                rP["x1"] = (((cameraX - (rectX - tempScaleX)) * (1 + (hM[1] or 0))) - (cameraX - (rectX - tempScaleX))) * a1 - Map.overDraw
                                rP["y1"] = (((cameraY - (rectY - tempScaleY)) * (1 + (hM[1] or 0))) - (cameraY - (rectY - tempScaleY))) * b1 - Map.overDraw									
                                rP["x2"] = (((cameraX - (rectX - tempScaleX)) * (1 + (hM[2] or 0))) - (cameraX - (rectX - tempScaleX))) * a2 - Map.overDraw
                                rP["y2"] = (((cameraY - (rectY + tempScaleY)) * (1 + (hM[2] or 0))) - (cameraY - (rectY + tempScaleY))) * b2 + Map.overDraw									
                                rP["x3"] = (((cameraX - (rectX + tempScaleX)) * (1 + (hM[3] or 0))) - (cameraX - (rectX + tempScaleX))) * a3 + Map.overDraw
                                rP["y3"] = (((cameraY - (rectY + tempScaleY)) * (1 + (hM[3] or 0))) - (cameraY - (rectY + tempScaleY))) * b3 + Map.overDraw									
                                rP["x4"] = (((cameraX - (rectX + tempScaleX)) * (1 + (hM[4] or 0))) - (cameraX - (rectX + tempScaleX))) * a4 + Map.overDraw
                                rP["y4"] = (((cameraY - (rectY - tempScaleY)) * (1 + (hM[4] or 0))) - (cameraY - (rectY - tempScaleY))) * b4 - Map.overDraw
                            else
                                local locXminus1 = locX - 1
                                local locYminus1 = locY - 1
                                local locXplus1 = locX + 1
                                local locYplus1 = locY + 1									
                                if Map.map.heightMap then
                                    mH = gH
                                end									
                                if locXminus1 < 1 then
                                    locXminus1 = #mH
                                end								
                                if locYminus1 < 1 then
                                    locYminus1 = #mH[locX]
                                end	
                                if locXplus1 > #mH then
                                    locXplus1 = 1
                                end								
                                if locYplus1 > #mH[locX] then
                                    locYplus1 = 1
                                end										
                                local x1, y1, x2, y2, x3, y3, x4, y4 = "x1", "y1", "x2", "y2", "x3", "y3", "x4", "y4"
                                local a1, b1, a2, b2, a3, b3, a4, b4 = -1, -1, -1, -1, -1, -1, -1, -1									
                                if Map.enableFlipRotation then
                                    if Map.map.layers[i].flipRotation[locX][locY] then
                                        local command = Map.map.layers[i].flipRotation[locX][locY]
                                        if command == 3 then
                                            x1, y1, x2, y2, x3, y3, x4, y4 = "y4", "x4", "y1", "x1", "y2", "x2", "y3", "x3"
                                            b1, b2, b3, b4 = 1, 1, 1, 1
                                        elseif command == 5 then
                                            x1, y1, x2, y2, x3, y3, x4, y4 = "y2", "x2", "y3", "x3", "y4", "x4", "y1", "x1"
                                            a1, a2, a3, a4 = 1, 1, 1, 1
                                        elseif command == 6 then
                                            x1, y1, x2, y2, x3, y3, x4, y4 = "x3", "y3", "x4", "y4", "x1", "y1", "x2", "y2"
                                            a1, b1, a2, b2, a3, b3, a4, b4 = 1, 1, 1, 1, 1, 1, 1, 1
                                        elseif command == 2 then
                                            x1, y1, x2, y2, x3, y3, x4, y4 = "x2", "y2", "x1", "y1", "x4", "y4", "x3", "y3"
                                            b1, b2, b3, b4 = 1, 1, 1, 1
                                        elseif command == 4 then
                                            x1, y1, x2, y2, x3, y3, x4, y4 = "x4", "y4", "x3", "y3", "x2", "y2", "x1", "y1"
                                            a1, a2, a3, a4 = 1, 1, 1, 1
                                        elseif command == 1 then
                                            x1, y1, x2, y2, x3, y3, x4, y4 = "y1", "x1", "y4", "x4", "y3", "x3", "y2", "x2"
                                        elseif command == 7 then
                                            x1, y1, x2, y2, x3, y3, x4, y4 = "y3", "x3", "y2", "x2", "y1", "x1", "y4", "x4"
                                            a1, b1, a2, b2, a3, b3, a4, b4 = 1, 1, 1, 1, 1, 1, 1, 1
                                        end
                                    end
                                end	 									
                                local tempHeight = ((mH[locX][locY] or 0) + (mH[locXminus1][locY] or 0) + (mH[locX][locYminus1] or 0) + (mH[locXminus1][locYminus1] or 0)) / 4
                                rP[x1] = (((cameraX - (rectX - tempScaleX)) * (1 + tempHeight)) - (cameraX - (rectX - tempScaleX))) * a1 - Map.overDraw
                                rP[y1] = (((cameraY - (rectY - tempScaleY)) * (1 + tempHeight)) - (cameraY - (rectY - tempScaleY))) * b1 - Map.overDraw																
                                local tempHeight = ((mH[locX][locY] or 0) + (mH[locXminus1][locY] or 0) + (mH[locX][locYplus1] or 0) + (mH[locXminus1][locYplus1] or 0)) / 4
                                rP[x2] = (((cameraX - (rectX - tempScaleX)) * (1 + tempHeight)) - (cameraX - (rectX - tempScaleX))) * a2 - Map.overDraw
                                rP[y2] = (((cameraY - (rectY + tempScaleY)) * (1 + tempHeight)) - (cameraY - (rectY + tempScaleY))) * b2 + Map.overDraw															
                                local tempHeight = ((mH[locX][locY] or 0) + (mH[locXplus1][locY] or 0) + (mH[locX][locYplus1] or 0) + (mH[locXplus1][locYplus1] or 0)) / 4
                                rP[x3] = (((cameraX - (rectX + tempScaleX)) * (1 + tempHeight)) - (cameraX - (rectX + tempScaleX))) * a3 + Map.overDraw
                                rP[y3] = (((cameraY - (rectY + tempScaleY)) * (1 + tempHeight)) - (cameraY - (rectY + tempScaleY))) * b3 + Map.overDraw															
                                local tempHeight = ((mH[locX][locY] or 0) + (mH[locXplus1][locY] or 0) + (mH[locX][locYminus1] or 0) + (mH[locXplus1][locYminus1] or 0)) / 4
                                rP[x4] = (((cameraX - (rectX + tempScaleX)) * (1 + tempHeight)) - (cameraX - (rectX + tempScaleX))) * a4 + Map.overDraw
                                rP[y4] = (((cameraY - (rectY - tempScaleY)) * (1 + tempHeight)) - (cameraY - (rectY - tempScaleY))) * b4 - Map.overDraw
                            end
                            --------
                        end
                    end
                end
            end
        end
    end
    
    local updated = false
    if Camera.enableLighting then
        if Light.lightingData.refreshStyle == 1 then
            --continuous
            local mapLayerFalloff = Map.map.properties.lightLayerFalloff
            local mapLevelFalloff = Map.map.properties.lightLevelFalloff			
            local startLocX = Map.masterGroup[1].vars.camera[1]
            local startLocY = Map.masterGroup[1].vars.camera[2]
            local endLocX = Map.masterGroup[1].vars.camera[3]
            local endLocY = Map.masterGroup[1].vars.camera[4]				
            for x = startLocX, endLocX, 1 do
                for y = startLocY, endLocY, 1 do
                    local updated = true
                    local checked = false
                    local locX, locY = x, y
                    for i = 1, #Map.map.layers, 1 do
                        if Camera.layerWrapX[i] then
                            if locX < 1 - Map.map.locOffsetX then
                                locX = locX + Map.map.layers[i].width
                            elseif locX > Map.map.layers[i].width - Map.map.locOffsetX then
                                locX = locX - Map.map.layers[i].width
                            end
                        end
                        if Camera.layerWrapY[i] then
                            if locY < 1 - Map.map.locOffsetY then
                                locY = locY + Map.map.layers[i].height
                            elseif locY > Map.map.layers[i].height - Map.map.locOffsetY then
                                locY = locY - Map.map.layers[i].height
                            end
                        end
                        if Map.tileObjects[i][locX] and Map.tileObjects[i][locX][locY] then
                            local rect = Map.tileObjects[i][locX][locY]								
                            if not rect.noDraw then	
                                --Normal Map Point Light
                                if rect.normalMap and Light.pointLightSource then
                                    local lightX = Light.pointLightSource.x
                                    local lightY = Light.pointLightSource.y
                                    if Light.pointLightSource.pointLight then
                                        if Light.pointLightSource.pointLight.pointLightPos then
                                            rect.fill.effect.pointLightPos = {((lightX + Light.pointLightSource.pointLight.pointLightPos[1]) - rect.x + Map.map.tilewidth / 2) / Map.map.tilewidth, 
                                                ((lightY + Light.pointLightSource.pointLight.pointLightPos[2]) - rect.y + Map.map.tileheight / 2) / Map.map.tileheight, 
                                                Light.pointLightSource.pointLight.pointLightPos[3]
                                            }
                                        else
                                            rect.fill.effect.pointLightPos = {(lightX - rect.x + Map.map.tilewidth / 2) / Map.map.tilewidth, 
                                                (lightY - rect.y + Map.map.tileheight / 2) / Map.map.tileheight, 
                                                0.1
                                            }
                                        end
                                        if Light.pointLightSource.pointLight.pointLightColor then
                                            rect.fill.effect.pointLightColor = Light.pointLightSource.pointLight.pointLightColor
                                        end
                                        if Light.pointLightSource.pointLight.ambientLightIntensity then
                                            rect.fill.effect.ambientLightIntensity = Light.pointLightSource.pointLight.ambientLightIntensity
                                        end
                                        if Light.pointLightSource.pointLight.attenuationFactors then
                                            rect.fill.effect.attenuationFactors = Light.pointLightSource.pointLight.attenuationFactors
                                        end 
                                    else
                                        rect.fill.effect.pointLightPos = {(lightX - rect.x + Map.map.tilewidth / 2) / Map.map.tilewidth, 
                                            (lightY - rect.y + Map.map.tileheight / 2) / Map.map.tileheight, 
                                            0.1
                                        }
                                    end
                                end
                                
                                --Tile Lighting							
                                if Map.map.lightToggle[locX][locY] and Map.map.lightToggle[locX][locY] > Map.map.lightToggle2[locX][locY] then
                                    rect.litBy = {}
                                    checked = true
                                    local layer = i
                                    local redf, greenf, bluef = Map.map.layers[layer].redLight, Map.map.layers[layer].greenLight, Map.map.layers[layer].blueLight
                                    if Map.map.perlinLighting then
                                        redf = redf * Map.map.perlinLighting[locX][locY]
                                        greenf = greenf * Map.map.perlinLighting[locX][locY]
                                        bluef = bluef * Map.map.perlinLighting[locX][locY]
                                    elseif Map.map.layers[layer].perlinLighting then
                                        redf = redf * Map.map.layers[layer].perlinLighting[locX][locY]
                                        greenf = greenf * Map.map.layers[layer].perlinLighting[locX][locY]
                                        bluef = bluef * Map.map.layers[layer].perlinLighting[locX][locY]
                                    end
                                    for k = 1, #Map.map.layers, 1 do									
                                        if Map.map.layers[k].lighting[locX][locY] then
                                            local temp = Map.map.layers[k].lighting[locX][locY]
                                            for key,value in pairs(temp) do
                                                local levelDiff = math.abs(Map.getLevel(i) - Map.map.lights[key].level)
                                                local layerDiff = math.abs(i - Map.map.lights[key].layer)											
                                                local layerFalloff, levelFalloff
                                                if Map.map.lights[key].layerFalloff then
                                                    layerFalloff = Map.map.lights[key].layerFalloff
                                                else
                                                    layerFalloff = mapLayerFalloff
                                                end											
                                                if Map.map.lights[key].levelFalloff then
                                                    levelFalloff = Map.map.lights[key].levelFalloff
                                                else
                                                    levelFalloff = mapLevelFalloff
                                                end											
                                                local tR = temp[key].light[1] - (levelDiff * levelFalloff[1]) - (layerDiff * layerFalloff[1])
                                                local tG = temp[key].light[2] - (levelDiff * levelFalloff[2]) - (layerDiff * layerFalloff[2])
                                                local tB = temp[key].light[3] - (levelDiff * levelFalloff[3]) - (layerDiff * layerFalloff[3])
                                                if tR > redf then
                                                    redf = tR
                                                end
                                                if tG > greenf then
                                                    greenf = tG
                                                end
                                                if tB > bluef then
                                                    bluef = tB
                                                end													
                                                rect.litBy[#rect.litBy + 1] = key
                                            end
                                        end
                                    end								
                                    local check = 0
                                    if redf > rect.color[1] then
                                        if redf - rect.color[1] <= Light.lightingData.fadeIn then
                                            rect.color[1] = redf
                                            check = check + 1
                                        else
                                            rect.color[1] = rect.color[1] + Light.lightingData.fadeIn
                                        end
                                    elseif redf < rect.color[1] then
                                        if rect.color[1] - redf <= Light.lightingData.fadeOut then
                                            rect.color[1] = redf
                                            check = check + 1
                                        else
                                            rect.color[1] = rect.color[1] - Light.lightingData.fadeOut
                                        end
                                    else
                                        check = check + 1
                                    end							
                                    if rect.color[1] > 1 then
                                        rect.color[1] = 1
                                    elseif rect.color[1] < 0 then
                                        rect.color[1] = 0
                                    end						
                                    if greenf > rect.color[2] then
                                        if greenf - rect.color[2] < Light.lightingData.fadeIn then
                                            rect.color[2] = greenf
                                            check = check + 1
                                        else
                                            rect.color[2] = rect.color[2] + Light.lightingData.fadeIn
                                        end
                                    elseif greenf < rect.color[2] then
                                        if rect.color[2] - greenf < Light.lightingData.fadeOut then
                                            rect.color[2] = greenf
                                            check = check + 1
                                        else
                                            rect.color[2] = rect.color[2] - Light.lightingData.fadeOut
                                        end
                                    else
                                        check = check + 1
                                    end							
                                    if rect.color[2] > 1 then
                                        rect.color[2] = 1
                                    elseif rect.color[2] < 0 then
                                        rect.color[2] = 0
                                    end													
                                    if bluef > rect.color[3] then
                                        if bluef - rect.color[3] < Light.lightingData.fadeIn then
                                            rect.color[3] = bluef
                                            check = check + 1
                                        else
                                            rect.color[3] = rect.color[3] + Light.lightingData.fadeIn
                                        end
                                    elseif bluef < rect.color[3] then
                                        if rect.color[3] - bluef < Light.lightingData.fadeOut then
                                            rect.color[3] = bluef
                                            check = check + 1
                                        else
                                            rect.color[3] = rect.color[3] - Light.lightingData.fadeOut
                                        end
                                    else
                                        check = check + 1
                                    end							
                                    if rect.color[3] > 1 then
                                        rect.color[3] = 1
                                    elseif rect.color[3] < 0 then
                                        rect.color[3] = 0
                                    end								
                                    if check < 3 then
                                        updated = false
                                    end										
                                    rect:setFillColor(rect.color[1], rect.color[2], rect.color[3])
                                end								
                            end
                        end
                    end
                    if checked and updated then
                        Map.map.lightToggle2[locX][locY] = tonumber(system.getTimer())
                    end
                end
            end
        elseif Light.lightingData.refreshStyle == 2 then
            --columns alternator
            local mapLayerFalloff = Map.map.properties.lightLayerFalloff
            local mapLevelFalloff = Map.map.properties.lightLevelFalloff				
            local startLocX = Map.masterGroup[1].vars.camera[1]
            local startLocY = Map.masterGroup[1].vars.camera[2]
            local endLocX = Map.masterGroup[1].vars.camera[3]
            local endLocY = Map.masterGroup[1].vars.camera[4]						
            local startX = startLocX + (Light.lightingData.refreshCounter - 1)
            for x = startX, endLocX, Light.lightingData.refreshAlternator do
                for y = startLocY, endLocY, 1 do
                    local updated = true
                    local checked = false
                    local locX, locY = x, y
                    for i = 1, #Map.map.layers, 1 do
                        if Camera.layerWrapX[i] then
                            if locX < 1 - Map.map.locOffsetX then
                                locX = locX + Map.map.layers[i].width
                            elseif locX > Map.map.layers[i].width - Map.map.locOffsetX then
                                locX = locX - Map.map.layers[i].width
                            end
                        end
                        if Camera.layerWrapY[i] then
                            if locY < 1 - Map.map.locOffsetY then
                                locY = locY + Map.map.layers[i].height
                            elseif locY > Map.map.layers[i].height - Map.map.locOffsetY then
                                locY = locY - Map.map.layers[i].height
                            end
                        end
                        if Map.tileObjects[i][locX] and Map.tileObjects[i][locX][locY] then
                            local rect = Map.tileObjects[i][locX][locY]								
                            if not rect.noDraw then		
                                --Normal Map Point Light
                                if rect.normalMap and Light.pointLightSource then
                                    local lightX = Light.pointLightSource.x
                                    local lightY = Light.pointLightSource.y
                                    if Light.pointLightSource.pointLight then
                                        if Light.pointLightSource.pointLight.pointLightPos then
                                            rect.fill.effect.pointLightPos = {((lightX + Light.pointLightSource.pointLight.pointLightPos[1]) - rect.x + Map.map.tilewidth / 2) / Map.map.tilewidth, 
                                                ((lightY + Light.pointLightSource.pointLight.pointLightPos[2]) - rect.y + Map.map.tileheight / 2) / Map.map.tileheight, 
                                                Light.pointLightSource.pointLight.pointLightPos[3]
                                            }
                                        else
                                            rect.fill.effect.pointLightPos = {(lightX - rect.x + Map.map.tilewidth / 2) / Map.map.tilewidth, 
                                                (lightY - rect.y + Map.map.tileheight / 2) / Map.map.tileheight, 
                                                0.1
                                            }
                                        end
                                        if Light.pointLightSource.pointLight.pointLightColor then
                                            rect.fill.effect.pointLightColor = Light.pointLightSource.pointLight.pointLightColor
                                        end
                                        if Light.pointLightSource.pointLight.ambientLightIntensity then
                                            rect.fill.effect.ambientLightIntensity = Light.pointLightSource.pointLight.ambientLightIntensity
                                        end
                                        if Light.pointLightSource.pointLight.attenuationFactors then
                                            rect.fill.effect.attenuationFactors = Light.pointLightSource.pointLight.attenuationFactors
                                        end 
                                    else
                                        rect.fill.effect.pointLightPos = {(lightX - rect.x + Map.map.tilewidth / 2) / Map.map.tilewidth, 
                                            (lightY - rect.y + Map.map.tileheight / 2) / Map.map.tileheight, 
                                            0.1
                                        }
                                        
                                    end
                                end
                                
                                --Tile Lighting						
                                if Map.map.lightToggle[locX][locY] and Map.map.lightToggle[locX][locY] > Map.map.lightToggle2[locX][locY] then
                                    rect.litBy = {}
                                    checked = true
                                    local layer = i
                                    local redf, greenf, bluef = Map.map.layers[layer].redLight, Map.map.layers[layer].greenLight, Map.map.layers[layer].blueLight
                                    if Map.map.perlinLighting then
                                        redf = redf * Map.map.perlinLighting[locX][locY]
                                        greenf = greenf * Map.map.perlinLighting[locX][locY] 
                                        bluef = bluef * Map.map.perlinLighting[locX][locY] 
                                    elseif Map.map.layers[layer].perlinLighting then
                                        redf = redf * Map.map.layers[layer].perlinLighting[locX][locY] 
                                        greenf = greenf * Map.map.layers[layer].perlinLighting[locX][locY] 
                                        bluef = bluef * Map.map.layers[layer].perlinLighting[locX][locY] 
                                    end
                                    for k = 1, #Map.map.layers, 1 do									
                                        if Map.map.layers[k].lighting[locX][locY] then
                                            local temp = Map.map.layers[k].lighting[locX][locY]
                                            for key,value in pairs(temp) do
                                                local levelDiff = math.abs(Map.getLevel(i) - Map.map.lights[key].level)
                                                local layerDiff = math.abs(i - Map.map.lights[key].layer)											
                                                local layerFalloff, levelFalloff
                                                if Map.map.lights[key].layerFalloff then
                                                    layerFalloff = Map.map.lights[key].layerFalloff
                                                else
                                                    layerFalloff = mapLayerFalloff
                                                end											
                                                if Map.map.lights[key].levelFalloff then
                                                    levelFalloff = Map.map.lights[key].levelFalloff
                                                else
                                                    levelFalloff = mapLevelFalloff
                                                end											
                                                local tR = temp[key].light[1] - (levelDiff * levelFalloff[1]) - (layerDiff * layerFalloff[1])
                                                local tG = temp[key].light[2] - (levelDiff * levelFalloff[2]) - (layerDiff * layerFalloff[2])
                                                local tB = temp[key].light[3] - (levelDiff * levelFalloff[3]) - (layerDiff * layerFalloff[3])
                                                if tR > redf then
                                                    redf = tR
                                                end
                                                if tG > greenf then
                                                    greenf = tG
                                                end
                                                if tB > bluef then
                                                    bluef = tB
                                                end													
                                                rect.litBy[#rect.litBy + 1] = key
                                            end
                                        end
                                    end								
                                    local check = 0
                                    if redf > rect.color[1] then
                                        if redf - rect.color[1] <= Light.lightingData.fadeIn then
                                            rect.color[1] = redf
                                            check = check + 1
                                        else
                                            rect.color[1] = rect.color[1] + Light.lightingData.fadeIn
                                        end
                                    elseif redf < rect.color[1] then
                                        if rect.color[1] - redf <= Light.lightingData.fadeOut then
                                            rect.color[1] = redf
                                            check = check + 1
                                        else
                                            rect.color[1] = rect.color[1] - Light.lightingData.fadeOut
                                        end
                                    else
                                        check = check + 1
                                    end							
                                    if rect.color[1] > 1 then
                                        rect.color[1] = 1
                                    elseif rect.color[1] < 0 then
                                        rect.color[1] = 0
                                    end						
                                    if greenf > rect.color[2] then
                                        if greenf - rect.color[2] < Light.lightingData.fadeIn then
                                            rect.color[2] = greenf
                                            check = check + 1
                                        else
                                            rect.color[2] = rect.color[2] + Light.lightingData.fadeIn
                                        end
                                    elseif greenf < rect.color[2] then
                                        if rect.color[2] - greenf < Light.lightingData.fadeOut then
                                            rect.color[2] = greenf
                                            check = check + 1
                                        else
                                            rect.color[2] = rect.color[2] - Light.lightingData.fadeOut
                                        end
                                    else
                                        check = check + 1
                                    end							
                                    if rect.color[2] > 1 then
                                        rect.color[2] = 1
                                    elseif rect.color[2] < 0 then
                                        rect.color[2] = 0
                                    end													
                                    if bluef > rect.color[3] then
                                        if bluef - rect.color[3] < Light.lightingData.fadeIn then
                                            rect.color[3] = bluef
                                            check = check + 1
                                        else
                                            rect.color[3] = rect.color[3] + Light.lightingData.fadeIn
                                        end
                                    elseif bluef < rect.color[3] then
                                        if rect.color[3] - bluef < Light.lightingData.fadeOut then
                                            rect.color[3] = bluef
                                            check = check + 1
                                        else
                                            rect.color[3] = rect.color[3] - Light.lightingData.fadeOut
                                        end
                                    else
                                        check = check + 1
                                    end							
                                    if rect.color[3] > 1 then
                                        rect.color[3] = 1
                                    elseif rect.color[3] < 0 then
                                        rect.color[3] = 0
                                    end								
                                    if check < 3 then
                                        updated = false
                                    end										
                                    rect:setFillColor(rect.color[1], rect.color[2], rect.color[3])
                                end								
                            end
                        end
                    end
                    if checked and updated then
                        Map.map.lightToggle2[locX][locY] = tonumber(system.getTimer())
                    end
                end
            end
            Light.lightingData.refreshCounter = Light.lightingData.refreshCounter + 1
            if Light.lightingData.refreshCounter > Light.lightingData.refreshAlternator then
                Light.lightingData.refreshCounter = 1
            end
        end
    end
    
    --Fade and Tint layers
    for i = 1, #Map.map.layers, 1 do
        if Map.masterGroup[i].vars.deltaFade then
            Map.masterGroup[i].vars.tempAlpha = Map.masterGroup[i].vars.tempAlpha - Map.masterGroup[i].vars.deltaFade[1]
            if Map.masterGroup[i].vars.tempAlpha > 1 then
                Map.masterGroup[i].vars.tempAlpha = 1
            end
            if Map.masterGroup[i].vars.tempAlpha < 0 then
                Map.masterGroup[i].vars.tempAlpha = 0
            end
            if Map.map.orientation == Map.Type.Isometric then
                if Map.isoSort == 1 then
                    Map.masterGroup[i].alpha = Map.masterGroup[i].vars.tempAlpha
                    Map.masterGroup[i].vars.alpha = Map.masterGroup[i].vars.tempAlpha
                else
                    for row = 1, #displayGroups, 1 do
                        displayGroups[row].layers[i].alpha = Map.masterGroup[i].vars.tempAlpha
                    end
                end
            else
                Map.masterGroup[i].alpha = Map.masterGroup[i].vars.tempAlpha
            end
            Map.masterGroup[i].vars.alpha = Map.masterGroup[i].vars.tempAlpha
            table.remove(Map.masterGroup[i].vars.deltaFade, 1)
            if not Map.masterGroup[i].vars.deltaFade[1] then
                Map.masterGroup[i].vars.deltaFade = nil
                Map.masterGroup[i].vars.tempAlpha = nil
            end
        end
        if Map.masterGroup[i].vars.deltaTint then
            Map.map.layers[i].redLight = Map.map.layers[i].redLight - Map.masterGroup[i].vars.deltaTint[1][1]
            Map.map.layers[i].greenLight = Map.map.layers[i].greenLight - Map.masterGroup[i].vars.deltaTint[2][1]
            Map.map.layers[i].blueLight = Map.map.layers[i].blueLight - Map.masterGroup[i].vars.deltaTint[3][1]				
            for x = Map.masterGroup[i].vars.camera[1], Map.masterGroup[i].vars.camera[3], 1 do
                for y = Map.masterGroup[i].vars.camera[2], Map.masterGroup[i].vars.camera[4], 1 do
                    if Map.tileObjects[i][x] and Map.tileObjects[i][x][y] and not Map.tileObjects[i][x][y].noDraw then
                        Map.tileObjects[i][x][y]:setFillColor(Map.map.layers[i].redLight, Map.map.layers[i].greenLight, Map.map.layers[i].blueLight)
                        if not Map.tileObjects[i][x][y].currentColor then
                            Map.tileObjects[i][x][y].currentColor = {Map.map.layers[i].redLight, 
                                Map.map.layers[i].greenLight, 
                                Map.map.layers[i].blueLight
                            }
                        end
                    end
                end
            end				
            table.remove(Map.masterGroup[i].vars.deltaTint[1], 1)
            table.remove(Map.masterGroup[i].vars.deltaTint[2], 1)
            table.remove(Map.masterGroup[i].vars.deltaTint[3], 1)
            if not Map.masterGroup[i].vars.deltaTint[1][1] then
                Map.masterGroup[i].vars.deltaTint = nil
            end
        end
        if Map.masterGroup[i].alpha <= 0 and Map.masterGroup[i].isVisible then
            Map.masterGroup[i].isVisible = false
            Map.masterGroup[i].vars.isVisible = false
        elseif Map.masterGroup[i].alpha > 0 and not Map.masterGroup[i].isVisible then
            Map.masterGroup[i].isVisible = true
            Map.masterGroup[i].vars.isVisible = true
        end
    end
    
    --Fade tiles
    for key,value in pairs(Map.fadingTiles) do
        local tile = Map.fadingTiles[key]
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
            Map.fadingTiles[tile] = nil
        end
    end
    
    --Tint tiles
    for key,value in pairs(Map.tintingTiles) do
        local tile = Map.tintingTiles[key]
        if Map.tileObjects[tile.layer][tile.locX] and Map.tileObjects[tile.layer][tile.locX][tile.locY] then
            tile.currentColor[1] = tile.currentColor[1] - tile.deltaTint[1][1]
            tile.currentColor[2] = tile.currentColor[2] - tile.deltaTint[2][1]
            tile.currentColor[3] = tile.currentColor[3] - tile.deltaTint[3][1]
            for i = 1, 3, 1 do
                if tile.currentColor[i] > 1 then
                    tile.currentColor[i] = 1
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
                Map.tintingTiles[tile] = nil
            end
        else
            Map.tintingTiles[key] = nil
        end
    end
    
    --Zoom Map.map
    if Camera.deltaZoom then
        Camera.currentScale = Camera.currentScale - Camera.deltaZoom[1]
        Map.masterGroup.xScale = Camera.currentScale
        Map.masterGroup.yScale = Camera.currentScale
        table.remove(Camera.deltaZoom, 1)
        if not Camera.deltaZoom[1] then
            Camera.deltaZoom = nil
        end
    end
    
    if Map.masterGroup.xScale < Camera.minZoom then
        Map.masterGroup.xScale = Camera.minZoom
    elseif Map.masterGroup.xScale > Camera.maxZoom then
        Map.masterGroup.xScale = Camera.maxZoom
    end
    
    if Map.masterGroup.yScale < Camera.minZoom then
        Map.masterGroup.yScale = Camera.minZoom
    elseif Map.masterGroup.yScale > Camera.maxZoom then
        Map.masterGroup.yScale = Camera.maxZoom
    end
    
    local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
    Camera.McameraX, Camera.McameraY = Map.masterGroup[Map.refLayer]:contentToLocal(tempX, tempY)
    if Map.map.orientation == Map.Type.Isometric then
        local isoPos = Map.isoUntransform2(Camera.McameraX, Camera.McameraY)
        Camera.McameraX = isoPos[1]
        Camera.McameraY = isoPos[2]
    end
    Camera.McameraLocX = math.ceil(Camera.McameraX / Map.map.tilewidth)
    Camera.McameraLocY = math.ceil(Camera.McameraY / Map.map.tileheight)
end

-----------------------------------------------------------

local count556 = 0
Core.updateTile = function(params)
    --local locX, locY = params.locX, params.locY
    local locX, locY
    if params.locX then
        locX = params.locX
    elseif params.levelPosX then
        locX = math.ceil(params.levelPosX / Map.map.tilewidth)
    end
    if params.locY then
        locY = params.locY
    elseif params.levelPosY then
        locY = math.ceil(params.levelPosY / Map.map.tileheight)
    end
    local layer = params.layer
    local tile = params.tile
    local cameraX, cameraY, cameraLocX, cameraLocY = Camera.McameraX, Camera.McameraY, Camera.McameraLocX, Camera.McameraLocY
    if params.cameraX then
        cameraX = cameraX
    end
    if params.cameraY then
        cameraY = cameraY
    end
    if params.cameraLocX then
        cameraLocX = cameraLocX
    end
    if params.cameraLocY then
        cameraLocY = cameraLocY
    end
    Camera.McameraX, Camera.McameraY, Camera.McameraLocX, Camera.McameraLocY = cameraX, cameraY, cameraLocX, cameraLocY
    
    local toggleBreak = false
    
    if locX < 1 - Map.map.locOffsetX or locX > Map.map.layers[layer].width - Map.map.locOffsetX then
        if not Camera.layerWrapX[layer] then
            toggleBreak = true
        end
    end
    if locY < 1 - Map.map.locOffsetY or locY > Map.map.layers[layer].height - Map.map.locOffsetY then
        if not Camera.layerWrapY[layer] then
            toggleBreak = true
        end
    end
    
    if not toggleBreak then
        if locX < 1 - Map.map.locOffsetX then
            locX = locX + Map.map.layers[layer].width
        end
        if locX > Map.map.layers[layer].width - Map.map.locOffsetX then
            locX = locX - Map.map.layers[layer].width
        end				
        
        if locY < 1 - Map.map.locOffsetY then
            locY = locY + Map.map.layers[layer].height
        end
        if locY > Map.map.layers[layer].height - Map.map.locOffsetY then
            locY = locY - Map.map.layers[layer].height
        end
        local isOwner = true
        if not tile then
            tile = Map.map.layers[layer].world[locX][locY]
        end
        
        local temp = nil
        if Map.tileObjects[layer][locX] and Map.tileObjects[layer][locX][locY] then		
            --print("*", locX, locY, layer)		
            temp = Map.tileObjects[layer][locX][locY].index
            if params.owner then
                isOwner = false
                if Map.tileObjects[layer][locX][locY].owner == params.owner and tile ~= Map.tileObjects[layer][locX][locY].index then
                    isOwner = true
                end
            end
            --print("do9")
            if isOwner then
                if dont then
                    if not Map.tileObjects[layer][locX][locY].noDraw then
                        if Map.tileObjects[layer][locX][locY].sync then
                            Map.animatedTiles[Map.tileObjects[layer][locX][locY]] = nil
                        end
                        Map.tileObjects[layer][locX][locY]:removeSelf()
                        Map.totalRects[layer] = Map.totalRects[layer] - 1
                    end
                end
                
                local frameIndex = Map.map.layers[layer].world[locX][locY]
                local tileSetIndex = 1
                for i = 1, #Map.map.tilesets, 1 do
                    if frameIndex >= Map.map.tilesets[i].firstgid then
                        tileSetIndex = i
                    else
                        break
                    end
                end
                
                if tile == -1 then
                    --print("do7")
                    local mT = Map.map.tilesets[tileSetIndex]
                    if mT.tilewidth > Map.map.tilewidth or mT.tileheight > Map.map.tileheight  then
                        --print("do2")
                        local width = math.ceil(mT.tilewidth / Map.map.tilewidth)
                        local height = math.ceil(mT.tileheight / Map.map.tileheight)
                        
                        local left, top, right, bottom = locX, locY - height + 1, locX + width - 1, locY
                        
                        if (left > Map.masterGroup[layer].vars.camera[3] or right < Map.masterGroup[layer].vars.camera[1]or
                            top > Map.masterGroup[layer].vars.camera[4] or bottom < Map.masterGroup[layer].vars.camera[2]) or params.forceCullLargeTile then
                            --print("do3")								
                            
                            --print("offscreen")
                            if not Map.tileObjects[layer][locX][locY].noDraw then
                                if Map.tileObjects[layer][locX][locY].sync then
                                    Map.animatedTiles[Map.tileObjects[layer][locX][locY]] = nil
                                end
                                Map.tileObjects[layer][locX][locY]:removeSelf()
                                Map.totalRects[layer] = Map.totalRects[layer] - 1
                            end
                            Map.tileObjects[layer][locX][locY] = nil
                            
                        else
                            --print("not offscreen")
                        end
                    else
                        if not Map.tileObjects[layer][locX][locY].noDraw then
                            if Map.tileObjects[layer][locX][locY].sync then
                                Map.animatedTiles[Map.tileObjects[layer][locX][locY]] = nil
                            end
                            Map.tileObjects[layer][locX][locY]:removeSelf()
                            Map.totalRects[layer] = Map.totalRects[layer] - 1
                        end
                        Map.tileObjects[layer][locX][locY] = nil
                    end
                else
                    --print("do8")
                    if not Map.tileObjects[layer][locX][locY].noDraw then
                        if Map.tileObjects[layer][locX][locY].sync then
                            Map.animatedTiles[Map.tileObjects[layer][locX][locY]] = nil
                        end
                        Map.tileObjects[layer][locX][locY]:removeSelf()
                        Map.totalRects[layer] = Map.totalRects[layer] - 1
                    end
                    Map.tileObjects[layer][locX][locY] = nil
                end	
                --Map.tileObjects[layer][locX][locY] = nil
                
                
            else
                tile = 0
            end
        end
        if tile == 0 and isOwner then
            Map.map.layers[layer].world[locX][locY] = tile
        end
        
        if tile > 0 then
            --print("do", locX, locY, layer)
            Map.map.layers[layer].world[locX][locY] = tile	
            count556 = count556 + 1
            local levelPosX = locX * Map.map.tilewidth - (Map.map.tilewidth / 2)
            local levelPosY = locY * Map.map.tileheight - (Map.map.tileheight / 2)
            if Camera.layerWrapX[layer] then
                if cameraLocX - locX < Map.map.layers[layer].width / -2 then
                    --wrap around to the left
                    levelPosX = levelPosX - Map.map.layers[layer].width * Map.map.tilewidth
                elseif cameraLocX - locX > Map.map.layers[layer].width / 2 then
                    --wrap around to the right
                    levelPosX = levelPosX + Map.map.layers[layer].width * Map.map.tilewidth
                end
            end
            if Camera.layerWrapY[layer] then
                if cameraLocY - locY < Map.map.layers[layer].height / -2 then
                    --wrap around to the top
                    levelPosY = levelPosY - Map.map.layers[layer].height * Map.map.tileheight
                elseif cameraLocY - locY > Map.map.layers[layer].height / 2 then
                    --wrap around to the bottom
                    levelPosY = levelPosY + Map.map.layers[layer].height * Map.map.tileheight
                end
            end
            if Map.map.orientation == Map.Type.Isometric then
                local isoPos = Map.isoTransform2(levelPosX, levelPosY)
                levelPosX = isoPos[1]
                levelPosY = isoPos[2]
            end
            local frameIndex = tile
            local tileSetIndex = 1
            for i = 1, #Map.map.tilesets, 1 do
                if frameIndex >= Map.map.tilesets[i].firstgid then
                    tileSetIndex = i
                else
                    break
                end
            end
            frameIndex = frameIndex - (Map.map.tilesets[tileSetIndex].firstgid - 1)
            local tileStr = tostring(frameIndex - 1)
            local tempScaleX = Map.map.tilesets[tileSetIndex].tilewidth
            local tempScaleY = Map.map.tilesets[tileSetIndex].tileheight
            local offsetX = tempScaleX / 2 - Map.map.tilewidth / 2
            local offsetY = tempScaleY / 2 - Map.map.tileheight / 2			
            local listenerCheck = false
            local offsetZ = 0				
            if Map.map.orientation == Map.Type.Isometric then
                tempScaleX = tempScaleX / Map.isoScaleMod + Map.overDraw
                tempScaleY = tempScaleY / Map.isoScaleMod + Map.overDraw
                offsetY = offsetY / Map.isoScaleMod
            else
                tempScaleX = tempScaleX + Map.overDraw
                tempScaleY = tempScaleY + Map.overDraw
            end				
            local tileProps
            if Map.map.tilesets[tileSetIndex].tileproperties then
                if Map.map.tilesets[tileSetIndex].tileproperties[tileStr] then
                    tileProps = Map.map.tilesets[tileSetIndex].tileproperties[tileStr]
                    if tileProps["offsetZ"] then
                        offsetZ = tonumber(tileProps["offsetZ"])
                    end
                end
            end				
            local paint
            local normalMap = false
            if Map.enableNormalMaps then
                if Map.normalSets[tileSetIndex] then
                    if not tileProps or not tileProps["normalMap"] or tileProps["normalMap"] ~= "false" then
                        paint = {
                            type = "composite",
                            paint1 = {type = "image", sheet = Map.tileSets[tileSetIndex], frame = frameIndex},
                            paint2 = {type = "image", sheet = Map.normalSets[tileSetIndex], frame = frameIndex}
                        }
                        normalMap = true
                    else
                        --paint = {type = "image", sheet = Map.tileSets[tileSetIndex], frame = frameIndex}
                    end
                elseif Map.map.defaultNormalMap then
                    paint = {
                        type = "composite",
                        paint1 = {type = "image", sheet = Map.tileSets[tileSetIndex], frame = frameIndex},
                        paint2 = {type = "image", filename = Map.map.defaultNormalMap}
                    }
                    normalMap = true
                else
                    --paint = {type = "image", sheet = Map.tileSets[tileSetIndex], frame = frameIndex}
                end
            else
                --paint = {type = "image", sheet = Map.tileSets[tileSetIndex], frame = frameIndex}
            end
            
            local render = true
            if (tileProps and params.onlyPhysics and not tileProps["physics"]) or (not tileProps and params.onlyPhysics) then
                render = false
            end
            
            if render then
                
                --print("do")
                if tileProps then
                    --print("do")
                    if not tileProps["noDraw"] and not Map.map.tilesets[tileSetIndex].properties["noDraw"] and not Map.map.layers[layer].properties["noDraw"] then
                        if tileProps["animFrames"] then
                            Map.tileObjects[layer][locX][locY] = display.newSprite(Map.masterGroup[layer][1],Map.tileSets[tileSetIndex], tileProps["sequenceData"])
                            Map.tileObjects[layer][locX][locY].xScale = tempScaleX / Map.map.tilewidth
                            Map.tileObjects[layer][locX][locY].yScale = tempScaleY / Map.map.tileheight
                            Map.tileObjects[layer][locX][locY]:setSequence("null")
                            Map.tileObjects[layer][locX][locY].sync = tileProps["animSync"]
                            Map.animatedTiles[Map.tileObjects[layer][locX][locY]] = Map.tileObjects[layer][locX][locY]
                        else
                            if normalMap then
                                Map.tileObjects[layer][locX][locY] = display.newRect(Map.masterGroup[layer][1], 0, 0, tempScaleX, tempScaleY)
                                Map.tileObjects[layer][locX][locY].fill = paint
                                Map.tileObjects[layer][locX][locY].fill.effect = "composite.normalMapWith1PointLight"
                                Map.tileObjects[layer][locX][locY].normalMap = true
                            else
                                Map.tileObjects[layer][locX][locY] = display.newImageRect(Map.masterGroup[layer][1], 
                                Map.tileSets[tileSetIndex], frameIndex, tempScaleX, tempScaleY
                                )
                            end
                        end
                    else
                        Map.tileObjects[layer][locX][locY] = {}
                        Map.tileObjects[layer][locX][locY].noDraw = true
                    end
                    Map.tileObjects[layer][locX][locY].properties = tileProps
                    listenerCheck = Map.tileObjects[layer][locX][locY]
                else
                    if not Map.map.tilesets[tileSetIndex].properties["noDraw"] and not Map.map.layers[layer].properties["noDraw"] then
                        if normalMap then
                            Map.tileObjects[layer][locX][locY] = display.newRect(Map.masterGroup[layer][1], 0, 0, tempScaleX, tempScaleY)
                            Map.tileObjects[layer][locX][locY].fill = paint
                            Map.tileObjects[layer][locX][locY].fill.effect = "composite.normalMapWith1PointLight"
                            Map.tileObjects[layer][locX][locY].normalMap = true
                        else
                            --print(layer, locX, locY)
                            --print(Map.tileObjects[layer][locX])
                            Map.tileObjects[layer][locX][locY] = display.newImageRect(Map.masterGroup[layer][1], 
                            Map.tileSets[tileSetIndex], frameIndex, tempScaleX, tempScaleY
                            )
                        end
                    else
                        Map.tileObjects[layer][locX][locY] = {}
                        Map.tileObjects[layer][locX][locY].noDraw = true
                    end
                end
                local rect = Map.tileObjects[layer][locX][locY]
                rect.x = levelPosX + offsetX
                rect.y = levelPosY - offsetY
                --print(Map.masterGroup[1], Map.masterGroup[2], Map.masterGroup[3], Map.masterGroup[4], Map.masterGroup[5], Map.masterGroup[6], Map.masterGroup[7])
                --print(locX, locY, tempScaleX, tempScaleY, rect.x, rect.y, Map.masterGroup[layer].x, Map.masterGroup[layer].y)
                rect.levelPosX = rect.x
                rect.levelPosY = rect.y
                rect.layer = layer
                rect.level = Map.map.layers[layer].properties.level
                rect.locX = locX
                rect.locY = locY
                rect.index = frameIndex
                rect.tileSet = tileSetIndex
                rect.tile = tileStr
                rect.tempScaleX = tempScaleX
                rect.tempScaleY = tempScaleY
                if normalMap and Light.pointLightSource then
                    local lightX = Light.pointLightSource.x
                    local lightY = Light.pointLightSource.y
                    if Light.pointLightSource.pointLight then
                        if Light.pointLightSource.pointLight.pointLightPos then
                            rect.fill.effect.pointLightPos = {((lightX + Light.pointLightSource.pointLight.pointLightPos[1]) - rect.x + Map.map.tilewidth / 2) / Map.map.tilewidth, 
                                ((lightY + Light.pointLightSource.pointLight.pointLightPos[2]) - rect.y + Map.map.tileheight / 2) / Map.map.tileheight, 
                                Light.pointLightSource.pointLight.pointLightPos[3]
                            }
                        else
                            rect.fill.effect.pointLightPos = {(lightX - rect.x + Map.map.tilewidth / 2) / Map.map.tilewidth, 
                                (lightY - rect.y + Map.map.tileheight / 2) / Map.map.tileheight, 
                                0.1
                            }
                        end
                        if Light.pointLightSource.pointLight.pointLightColor then
                            rect.fill.effect.pointLightColor = Light.pointLightSource.pointLight.pointLightColor
                        end
                        if Light.pointLightSource.pointLight.ambientLightIntensity then
                            rect.fill.effect.ambientLightIntensity = Light.pointLightSource.pointLight.ambientLightIntensity
                        end
                        if Light.pointLightSource.pointLight.attenuationFactors then
                            rect.fill.effect.attenuationFactors = Light.pointLightSource.pointLight.attenuationFactors
                        end 
                    else
                        rect.fill.effect.pointLightPos = {(lightX - rect.x + Map.map.tilewidth / 2) / Map.map.tilewidth, 
                            (lightY - rect.y + Map.map.tileheight / 2) / Map.map.tileheight, 
                            0.1
                        }
                    end
                end
                if params.owner then
                    rect.owner = params.owner
                end
                
                if not rect.noDraw then
                    Map.totalRects[layer] = Map.totalRects[layer] + 1
                    
                    if Map.map.orientation == Map.Type.Isometric then
                        if Map.isoSort == 1 then
                            Map.masterGroup[layer][locX + locY - 1][1]:insert(Map.tileObjects[layer][locX][locY])
                        elseif Map.isoSort == 2 then
                            
                        end
                    end
                    
                    if tileProps then
                        if tileProps["path"] then
                            local path = json.decode(tileProps["path"])
                            local rectpath = rect.path
                            rect.pathToggle = true
                            rectpath.x1 = path[1]
                            rectpath.y1 = path[2]
                            rectpath.x2 = path[3]
                            rectpath.y2 = path[4]
                            rectpath.x3 = path[5]
                            rectpath.y3 = path[6]
                            rectpath.x4 = path[7]
                            rectpath.y4 = path[8]
                        end
                        if tileProps["heightMap"] then
                            rect.heightMap = json.decode(tileProps["heightMap"])
                        end
                    end
                    
                    if Camera.enableLighting then
                        rect.litBy = {}
                        local mapLayerFalloff = Map.map.properties.lightLayerFalloff
                        local mapLevelFalloff = Map.map.properties.lightLevelFalloff
                        local redf, greenf, bluef = Map.map.layers[layer].redLight, Map.map.layers[layer].greenLight, Map.map.layers[layer].blueLight
                        if Map.map.perlinLighting then
                            redf = redf * Map.map.perlinLighting[locX][locY]
                            greenf = greenf * Map.map.perlinLighting[locX][locY]
                            bluef = bluef * Map.map.perlinLighting[locX][locY]
                        elseif Map.map.layers[layer].perlinLighting then
                            redf = redf * Map.map.layers[layer].perlinLighting[locX][locY]
                            greenf = greenf * Map.map.layers[layer].perlinLighting[locX][locY]
                            bluef = bluef * Map.map.layers[layer].perlinLighting[locX][locY]
                        end
                        for i = 1, #Map.map.layers, 1 do
                            if Map.map.layers[i].lighting[locX][locY] then
                                local temp = Map.map.layers[i].lighting[locX][locY]
                                for key,value in pairs(temp) do
                                    local levelDiff = math.abs(Map.getLevel(layer) - Map.map.lights[key].level)
                                    local layerDiff = math.abs(layer - Map.map.lights[key].layer)
                                    
                                    local layerFalloff, levelFalloff
                                    if Map.map.lights[key].layerFalloff then
                                        layerFalloff = Map.map.lights[key].layerFalloff
                                    else
                                        layerFalloff = mapLayerFalloff
                                    end
                                    
                                    if Map.map.lights[key].levelFalloff then
                                        levelFalloff = Map.map.lights[key].levelFalloff
                                    else
                                        levelFalloff = mapLevelFalloff
                                    end
                                    local tR = temp[key].light[1] - (levelDiff * levelFalloff[1]) - (layerDiff * layerFalloff[1])
                                    local tG = temp[key].light[2] - (levelDiff * levelFalloff[2]) - (layerDiff * layerFalloff[2])
                                    local tB = temp[key].light[3] - (levelDiff * levelFalloff[3]) - (layerDiff * layerFalloff[3])
                                    
                                    if tR > redf then
                                        redf = tR
                                    end
                                    if tG > greenf then
                                        greenf = tG
                                    end
                                    if tB > bluef then
                                        bluef = tB
                                    end
                                    
                                    rect.litBy[#rect.litBy + 1] = key
                                end
                            end
                        end
                        rect:setFillColor(redf, greenf, bluef)
                        rect.color = {redf, greenf, bluef}
                    else
                        local redf, greenf, bluef = Map.map.layers[layer].redLight, Map.map.layers[layer].greenLight, Map.map.layers[layer].blueLight
                        if Map.map.perlinLighting then	
                            redf = redf * Map.map.perlinLighting[locX][locY]
                            greenf = greenf * Map.map.perlinLighting[locX][locY]
                            bluef = bluef * Map.map.perlinLighting[locX][locY]
                        elseif Map.map.layers[layer].perlinLighting then
                            redf = redf * Map.map.layers[layer].perlinLighting[locX][locY]
                            greenf = greenf * Map.map.layers[layer].perlinLighting[locX][locY]
                            bluef = bluef * Map.map.layers[layer].perlinLighting[locX][locY]
                        end
                        rect:setFillColor(redf, greenf, bluef)
                    end
                    
                    if Map.enableFlipRotation then
                        if Map.map.layers[layer].flipRotation[locX][locY] or Map.map.layers[layer].flipRotation[locX][tostring(locY)] then
                            local command
                            if Map.map.layers[layer].flipRotation[locX][locY] then
                                command = Map.map.layers[layer].flipRotation[locX][locY]
                            else
                                command = Map.map.layers[layer].flipRotation[locX][tostring(locY)]
                                Map.map.layers[layer].flipRotation[locX][locY] = command
                                Map.map.layers[layer].flipRotation[locX][tostring(locY)] = nil
                            end
                            if command == 3 then
                                rect.rotation = 270
                            elseif command == 5 then
                                rect.rotation = 90
                            elseif command == 6 then
                                rect.rotation = 180
                            elseif command == 2 then
                                rect.yScale = -1
                            elseif command == 4 then
                                rect.xScale = -1
                            elseif command == 1 then
                                rect.rotation = 90
                                rect.yScale = -1
                            elseif command == 7 then
                                rect.rotation = -90
                                rect.yScale = -1
                            end
                        end
                    end	
                    
                    rect.makeSprite = function(self)
                        local kind = "imageRect"
                        if rect.sync then
                            kind = "sprite"
                            Sprites.tempObjects[#Sprites.tempObjects + 1] = display.newSprite(Map.masterGroup[layer],Map.tileSets[tileSetIndex], 
                            tileProps["sequenceData"])
                            Sprites.tempObjects[#Sprites.tempObjects].xScale = Map.findScaleX(worldScaleX, layer)
                            Sprites.tempObjects[#Sprites.tempObjects].yScale = Map.findScaleY(worldScaleY, layer)
                            Sprites.tempObjects[#Sprites.tempObjects].layer = layer
                            Sprites.tempObjects[#Sprites.tempObjects]:setSequence("null")
                            Sprites.tempObjects[#Sprites.tempObjects].sync = tileProps["animSync"]
                        else
                            Sprites.tempObjects[#Sprites.tempObjects + 1] = display.newImageRect(Map.masterGroup[layer], 
                            Map.tileSets[tileSetIndex], frameIndex, tempScaleX, tempScaleY
                            )
                        end
                        local spriteName = ""..layer..locX..locY
                        local setup = {layer = layer, kind = kind, locX = locX, locY = locY, 
                            levelWidth = tempScaleX, levelHeight = tempScaleY, 
                            offsetX = offsetX, offsetY = offsetY * -1, name = spriteName
                        }
                        Sprites.addSprite(Sprites.tempObjects[#Sprites.tempObjects], setup)
                        Sprites.tempObjects[#Sprites.tempObjects].width = tempScaleX
                        Sprites.tempObjects[#Sprites.tempObjects].height = tempScaleY
                        if Map.tileObjects[layer][locX][locY].bodyType then
                            physics.addBody( Sprites.tempObjects[#Sprites.tempObjects], bodyType, {density = density, 
                                friction = friction, 
                                bounce = bounce,
                                radius = radius,
                                shape = shape2,
                                filter = filter
                            })
                            if rect.properties and rect.properties.isAwake then
                                if rect.properties.isAwake == "true" then
                                    Sprites.tempObjects[#Sprites.tempObjects].isAwake = true
                                else
                                    Sprites.tempObjects[#Sprites.tempObjects].isAwake = false
                                end
                            else
                                Sprites.tempObjects[#Sprites.tempObjects].isAwake = PhysicsData.layer[layer].isAwake
                            end
                            if rect.properties and rect.properties.isBodyActive then
                                if rect.properties.isBodyActive == "true" then
                                    Sprites.tempObjects[#Sprites.tempObjects].isBodyActive = true
                                else
                                    Sprites.tempObjects[#Sprites.tempObjects].isBodyActive = false
                                end
                            else
                                Sprites.tempObjects[#Sprites.tempObjects].isBodyActive = PhysicsData.layer[layer].isActive
                            end
                        end
                        if Sprites.tempObjects[#Sprites.tempObjects].sync then
                            Sprites.tempObjects[#Sprites.tempObjects]:setSequence("null")
                            Sprites.tempObjects[#Sprites.tempObjects]:play()
                        end
                        return Sprites.tempObjects[#Sprites.tempObjects]
                    end
                    
                    if PhysicsData.enablePhysics[layer] then
                        local bodyType, density, friction, bounce, radius, shape2, filter
                        bodyType = PhysicsData.layer[layer].defaultBodyType
                        density = PhysicsData.layer[layer].defaultDensity
                        friction = PhysicsData.layer[layer].defaultFriction
                        bounce = PhysicsData.layer[layer].defaultBounce
                        radius = PhysicsData.layer[layer].defaultRadius
                        filter = PhysicsData.layer[layer].defaultFilter
                        
                        if Map.map.layers[layer].properties["forceDefaultPhysics"] or tileProps then
                            if Map.map.layers[layer].properties["forceDefaultPhysics"] or
                                tileProps["physics"] == "true" or 
                                tileProps["shapeID"] then
                                local tempTileProps = false
                                if not tileProps then
                                    tileProps = {}
                                    tempTileProps = true
                                end
                                local scaleFactor = 1
                                
                                local data = nil
                                if tileProps["physicsSource"] then
                                    if tileProps["physicsSourceScale"] then
                                        scaleFactor = tonumber(tileProps["physicsSourceScale"])
                                    end
                                    local source = tileProps["physicsSource"]:gsub(".lua", "")
                                    data = require(source).PhysicsData(scaleFactor)
                                    bodyType = "dynamic"
                                end
                                if Map.map.tilesets[tileSetIndex].PhysicsData then
                                    if tileProps["shapeID"] then
                                        data = true
                                        bodyType = "dynamic"					
                                    end
                                end					
                                if tileProps["bodyType"] then
                                    bodyType = tileProps["bodyType"]
                                end
                                if not data then
                                    if tileProps["density"] then
                                        density = tileProps["density"]
                                    end
                                    if tileProps["friction"] then
                                        friction = tileProps["friction"]
                                    end
                                    if tileProps["bounce"] then
                                        bounce = tileProps["bounce"]
                                    end
                                    if tileProps["radius"] then
                                        radius = tileProps["radius"]
                                    else
                                        shape2 = PhysicsData.layer[layer].defaultShape
                                    end
                                    if tileProps["shape"] then
                                        local shape = tileProps["shape"]
                                        shape2 = {}
                                        for key,value in pairs(shape) do
                                            shape2[key] = value
                                        end
                                    end					
                                    if tileProps["groupIndex"] or 
                                        tileProps["categoryBits"] or 
                                        tileProps["maskBits"] then
                                        filter = {categoryBits = tileProps["categoryBits"],
                                            maskBits = tileProps["maskBits"],
                                            groupIndex = tileProps["groupIndex"]
                                        }
                                    end
                                end					
                                if bodyType ~= "static" then
                                    local kind = "imageRect"
                                    if rect then
                                        if rect.sync then
                                            Map.animatedTiles[rect] = nil
                                        end
                                        Sprites.tempObjects[#Sprites.tempObjects + 1] = rect
                                        if Sprites.tempObjects[#Sprites.tempObjects].sync then
                                            kind = "sprite"
                                        end
                                        Map.tileObjects[layer][locX][locY] = nil
                                        Map.totalRects[layer] = Map.totalRects[layer] - 1
                                    else
                                        Sprites.tempObjects[#Sprites.tempObjects + 1] = display.newImageRect(Map.masterGroup[layer], 
                                        Map.tileSets[tileSetIndex], frameIndex, tempScaleX, tempScaleY
                                        )
                                    end
                                    local spriteName = ""..layer..locX..locY
                                    local setup = {layer = layer, kind = kind, locX = locX, locY = locY, 
                                        levelWidth = tempScaleX, levelHeight = tempScaleY, 
                                        offsetX = offsetX, offsetY = offsetY * -1, name = spriteName
                                    }
                                    if Map.map.layers[layer].properties["noDraw"] or tileProps["offscreenPhysics"] then
                                        setup.offscreenPhysics = true
                                    end
                                    if tileProps["layer"] then
                                        setup.layer = tonumber(tileProps["layer"])
                                    end
                                    Sprites.addSprite(Sprites.tempObjects[#Sprites.tempObjects], setup)
                                    Sprites.tempObjects[#Sprites.tempObjects].width = tempScaleX
                                    Sprites.tempObjects[#Sprites.tempObjects].height = tempScaleY
                                    if data ~= nil then
                                        if data == true then 
                                            physics.addBody( Sprites.tempObjects[#Sprites.tempObjects], bodyType, Map.map.tilesets[tileSetIndex].PhysicsData:get(tileProps["shapeID"]) )
                                        else
                                            physics.addBody( Sprites.tempObjects[#Sprites.tempObjects], bodyType, data:get(tileProps["shapeID"]) )
                                        end
                                    else
                                        physics.addBody( Sprites.tempObjects[#Sprites.tempObjects], bodyType, {density = density, 
                                            friction = friction, 
                                            bounce = bounce,
                                            radius = radius,
                                            shape = shape2,
                                            filter = filter
                                        })
                                    end
                                    Map.map.layers[layer].world[locX][locY] = 0
                                    if rect.properties and rect.properties.isAwake then
                                        if rect.properties.isAwake == "true" then
                                            Sprites.tempObjects[#Sprites.tempObjects].isAwake = true
                                        else
                                            Sprites.tempObjects[#Sprites.tempObjects].isAwake = false
                                        end
                                    else
                                        Sprites.tempObjects[#Sprites.tempObjects].isAwake = PhysicsData.layer[layer].isAwake
                                    end
                                    if rect.properties and rect.properties.isBodyActive then
                                        if rect.properties.isBodyActive == "true" then
                                            Sprites.tempObjects[#Sprites.tempObjects].isBodyActive = true
                                        else
                                            Sprites.tempObjects[#Sprites.tempObjects].isBodyActive = false
                                        end
                                    else
                                        Sprites.tempObjects[#Sprites.tempObjects].isBodyActive = PhysicsData.layer[layer].isActive
                                    end
                                    if Sprites.tempObjects[#Sprites.tempObjects].sync then
                                        Sprites.tempObjects[#Sprites.tempObjects]:setSequence("null")
                                        Sprites.tempObjects[#Sprites.tempObjects]:play()
                                    end
                                    listenerCheck = Sprites.tempObjects[#Sprites.tempObjects]
                                else
                                    rect.width = tempScaleX
                                    rect.height = tempScaleY
                                    if data ~= nil then
                                        if data == true then 
                                            physics.addBody( rect, bodyType, Map.map.tilesets[tileSetIndex].PhysicsData:get(tileProps["shapeID"]) )
                                        else
                                            physics.addBody( rect, bodyType, data:get(tileProps["shapeID"]) )
                                        end
                                    else
                                        physics.addBody( rect, bodyType, {density = density, 
                                            friction = friction, 
                                            bounce = bounce,
                                            radius = radius,
                                            shape = shape2,
                                            filter = filter
                                        })
                                    end
                                    rect.physics = true
                                    if rect.properties and rect.properties.isAwake then
                                        if rect.properties.isAwake == "true" then
                                            rect.isAwake = true
                                        else
                                            rect.isAwake = false
                                        end
                                    else
                                        rect.isAwake = PhysicsData.layer[layer].isAwake
                                    end
                                    if rect.properties and rect.properties.isBodyActive then
                                        if rect.properties.isBodyActive == "true" then
                                            rect.isBodyActive = true
                                        else
                                            rect.isBodyActive = false
                                        end
                                    else
                                        rect.isBodyActive = PhysicsData.layer[layer].isActive
                                    end
                                end
                                if tempTileProps then
                                    tileProps = nil
                                end
                            end
                        end
                    end
                    ----
                end
                
                if listenerCheck then
                    for key,value in pairs(propertyListeners) do
                        if tileProps[key] then
                            local event = { name = key, target = listenerCheck}
                            Map.masterGroup:dispatchEvent( event )
                        end
                    end
                end
                -----------
                
                return isOwner
            end
        end	
    end	
end

-----------------------------------------------------------

local drawObject = function(object, i, ky)
    local lineColor = {0, 0, 0, 0}
    local lineWidth = 0
    local fillColor = {0, 0, 0, 0}
    local layer = i
    
    if object.properties.layer then
        layer = tonumber(object.properties.layer)
    end
    local spriteName
    if object.properties.lineColor then
        lineColor = json.decode(object.properties.lineColor)
        lineWidth = 1
        if not lineColor[4] then
            lineColor[4] = 1
        end
    end
    if object.properties.lineWidth then
        lineWidth = tonumber(object.properties.lineWidth)
    end
    if object.properties.fillColor then
        fillColor = json.decode(object.properties.fillColor)
        if not fillColor[4] then
            fillColor[4] = 1
        end
    end
    
    local bodyType, density, friction, bounce, radius, shape2, folter
    if PhysicsData.enablePhysics[i] then
        bodyType = PhysicsData.layer[i].defaultBodyType
        density = PhysicsData.layer[i].defaultDensity
        friction = PhysicsData.layer[i].defaultFriction
        bounce = PhysicsData.layer[i].defaultBounce
        radius = PhysicsData.layer[i].defaultRadius
        shape2 = PhysicsData.layer[i].defaultShape
        filter = PhysicsData.layer[i].defaultFilter
        if object.properties.bodyType then
            bodyType = object.properties.bodyType
        end
        if object.properties.density then
            density = object.properties.density
        end
        if object.properties.friction then
            friction = object.properties.friction
        end
        if object.properties.bounce then
            bounce = object.properties.bounce
        end
        if object.properties.radius then
            radius = object.properties.radius
        end
        if object.properties.shape and object.properties.shape ~= "auto" then
            shape = object.properties.shape
            shape2 = {}
            for key,value in pairs(shape) do
                shape2[key] = value
            end
        end
        if object.properties.groupIndex or 
            object.properties.categoryBits or 
            object.properties.maskBits then
            filter = {categoryBits = object.properties.categoryBits,
                maskBits = object.properties.maskBits,
                groupIndex = object.properties.groupIndex
            }
        end
    end
    local listenerCheck = false
    if object.gid then	
        if Map.map.orientation == Map.Type.Isometric then
            listenerCheck = true							
            local frameIndex = object.gid
            local tempScaleX = Map.map.tilewidth * Map.map.layers[i].properties.scaleX
            local tempScaleY = Map.map.tileheight * Map.map.layers[i].properties.scaleY
            local tileSetIndex = 1
            for i = 1, #Map.map.tilesets, 1 do
                if frameIndex >= Map.map.tilesets[i].firstgid then
                    tileSetIndex = i
                else
                    break
                end
            end
            local levelWidth = Map.map.tilesets[tileSetIndex].tilewidth / Map.isoScaleMod
            if object.properties.levelWidth then
                levelWidth = object.properties.levelWidth / Map.isoScaleMod
            end
            local levelHeight = Map.map.tilesets[tileSetIndex].tileheight / Map.isoScaleMod
            if object.properties.levelHeight then
                levelHeight = object.properties.levelHeight / Map.isoScaleMod
            end			
            frameIndex = frameIndex - (Map.map.tilesets[tileSetIndex].firstgid - 1)		
            spriteName = object.name
            if not spriteName or spriteName == "" then
                spriteName = ""..object.x.."_"..object.y.."_"..i
            end
            if Sprites.sprites[spriteName] then
                local tempName = spriteName
                local counter = 1
                while Sprites.sprites[tempName] do
                    tempName = ""..spriteName..counter
                    counter = counter + 1
                end
                spriteName = tempName
            end
            Sprites.sprites[spriteName] = display.newImageRect(Map.masterGroup[i], 
            Map.tileSets[tileSetIndex], frameIndex, tempScaleX, tempScaleY
            )
            local setup = {layer = layer, kind = "imageRect", levelPosX = object.x - (worldScaleX * 0.5), levelPosY = object.y - (worldScaleX * 0.5), 
                levelWidth = levelWidth, levelHeight = levelHeight, offsetX = 0, offsetY = 0, name = spriteName
            }
            if PhysicsData.enablePhysics[i] then
                if object.properties.physics == "true" and object.properties.offscreenPhysics then
                    setup.offscreenPhysics = true
                end
            end
            Sprites.addSprite(Sprites.sprites[spriteName], setup, object.properties);			
                local polygon = {{x = 0, y = 0},
                {x = levelWidth * Map.isoScaleMod, y = 0},
                {x = levelWidth * Map.isoScaleMod, y = levelHeight * Map.isoScaleMod},
                {x = 0, y = levelHeight * Map.isoScaleMod}
            }
            local polygon2 = {}
            for i = 1, #polygon, 1 do
                --Convert world coordinates to isometric screen coordinates
                --find x,y distances from center
                local xDelta = polygon[i].x
                local yDelta = polygon[i].y
                local finalX, finalY
                if xDelta == 0 and yDelta == 0 then
                    finalX = polygon[i].x 
                    finalY = polygon[i].y
                else	
                    --find angle
                    local angle = math.atan(xDelta/yDelta)
                    local length = xDelta / math.sin(angle)
                    if xDelta == 0 then
                        length = yDelta
                    elseif yDelta == 0 then
                        length = xDelta
                    end
                    angle = angle - R45
                    
                    --find new deltas
                    local xDelta2 = length * math.sin(angle)
                    local yDelta2 = length * math.cos(angle)
                    
                    finalX = xDelta2 / 1
                    finalY = yDelta2 / Map.map.isoRatio
                end
                
                polygon2[i] = {}
                polygon2[i].x = finalX
                polygon2[i].y = finalY 
            end
            local minX = 999999
            local maxX = -999999
            local minY = 999999
            local maxY = -999999
            for i = 1, #polygon2, 1 do
                if polygon2[i].x > maxX then
                    maxX = polygon2[i].x
                end
                if polygon2[i].x < minX then
                    minX = polygon2[i].x
                end
                if polygon2[i].y > maxY then
                    maxY = polygon2[i].y
                end
                if polygon2[i].y < minY then
                    minY = polygon2[i].y
                end
            end
            width = math.abs(maxX - minX)
            height = math.abs(maxY - minY)				
            if PhysicsData.enablePhysics[i] then
                if object.properties.physics == "true" then
                    if not object.properties.shape or object.properties.shape == "auto" then
                        local bodies = {}									
                        local function det(x1,y1, x2,y2)
                            return x1*y2 - y1*x2
                        end
                        local function ccw(p, q, r)
                            return det(q.x-p.x, q.y-p.y,  r.x-p.x, r.y-p.y) >= 0
                        end		
                        local function areCollinear(p, q, r, eps)
                            return math.abs(det(q.x-p.x, q.y-p.y,  r.x-p.x,r.y-p.y)) <= (eps or 1e-32)
                        end
                        local triangles = {} -- list of triangles to be returned
                        local concave = {}   -- list of concave edges
                        local adj = {}       -- vertex adjacencies
                        local vertices = polygon2 	
                        -- retrieve adjacencies as the rest will be easier to implement
                        for i,p in ipairs(vertices) do
                            local l = (i == 1) and vertices[#vertices] or vertices[i-1]
                            local r = (i == #vertices) and vertices[1] or vertices[i+1]
                            adj[p] = {p = p, l = l, r = r} -- point, left and right neighbor
                            -- test if vertex is a concave edge
                            if not ccw(l,p,r) then concave[p] = p end
                        end
                        local function onSameSide(a,b, c,d)
                            local px, py = d.x-c.x, d.y-c.y
                            local l = det(px,py,  a.x-c.x, a.y-c.y)
                            local m = det(px,py,  b.x-c.x, b.y-c.y)
                            return l*m >= 0
                        end
                        local function pointInTriangle(p, a,b,c)
                            return onSameSide(p,a, b,c) and onSameSide(p,b, a,c) and onSameSide(p,c, a,b)
                        end
                        -- and ear is an edge of the polygon that contains no other
                        -- vertex of the polygon
                        local function isEar(p1,p2,p3)
                            if not ccw(p1,p2,p3) then return false end
                            for q,_ in pairs(concave) do
                                if q ~= p1 and q ~= p2 and q ~= p3 and pointInTriangle(q, p1,p2,p3) then
                                    return false
                                end
                            end
                            return true
                        end
                        -- main loop
                        local nPoints, skipped = #vertices, 0
                        local p = adj[ vertices[2] ]
                        while nPoints > 3 do
                            if not concave[p.p] and isEar(p.l, p.p, p.r) then
                                -- polygon may be a 'collinear triangle', i.e.
                                -- all three points are on a line. In that case
                                -- the polygon constructor throws an error.
                                if not areCollinear(p.l, p.p, p.r) then
                                    triangles[#triangles+1] = {p.l.x,p.l.y, p.p.x,p.p.y, p.r.x,p.r.y}
                                    bodies[#bodies + 1] = {density = density, 
                                        friction = friction, 
                                        bounce = bounce, 
                                        shape = {p.l.x, p.l.y, 
                                            p.p.x, p.p.y, 
                                            p.r.x, p.r.y
                                        },
                                        filter = filter
                                    }
                                    skipped = 0
                                end
                                if concave[p.l] and ccw(adj[p.l].l, p.l, p.r) then
                                    concave[p.l] = nil
                                end
                                if concave[p.r] and ccw(p.l, p.r, adj[p.r].r) then
                                    concave[p.r] = nil
                                end
                                -- remove point from list
                                adj[p.p] = nil
                                adj[p.l].r = p.r
                                adj[p.r].l = p.l
                                nPoints = nPoints - 1
                                skipped = 0
                                p = adj[p.l]
                            else
                                p = adj[p.r]
                                skipped = skipped + 1
                                assert(skipped <= nPoints, "Cannot triangulate polygon (is the polygon intersecting itself?)")
                            end
                        end
                        if not areCollinear(p.l, p.p, p.r) then
                            triangles[#triangles+1] = {p.l.x,p.l.y, p.p.x,p.p.y, p.r.x,p.r.y}
                            bodies[#bodies + 1] = {density = density, 
                                friction = friction, 
                                bounce = bounce, 
                                shape = {p.l.x, p.l.y, 
                                    p.p.x, p.p.y, 
                                    p.r.x, p.r.y
                                },
                                filter = filter
                            }
                        end
                        physics.addBody(Sprites.sprites[spriteName], bodyType, unpack(bodies))
                    else
                        physics.addBody(Sprites.sprites[spriteName], bodyType, {density = density, 
                            friction = friction, 
                            bounce = bounce,
                            radius = radius,
                            shape = shape2,
                            filter = filter
                        })
                    end
                    if object.properties.isAwake then 
                        if object.properties.isAwake == "true" then
                            Sprites.sprites[spriteName].isAwake = true
                        else
                            Sprites.sprites[spriteName].isAwake = false
                        end
                    else
                        Sprites.sprites[spriteName].isAwake = PhysicsData.layer[i].isAwake
                    end
                    if object.properties.isBodyActive then
                        if object.properties.isBodyActive == "true" then
                            Sprites.sprites[spriteName].isBodyActive = true
                        else
                            Sprites.sprites[spriteName].isBodyActive = false
                        end
                    else
                        Sprites.sprites[spriteName].isBodyActive = PhysicsData.layer[i].isActive
                    end
                end
            end
        else
            listenerCheck = true							
            local frameIndex = object.gid
            local tileSetIndex = 1
            for i = 1, #Map.map.tilesets, 1 do
                if frameIndex >= Map.map.tilesets[i].firstgid then
                    tileSetIndex = i
                else
                    break
                end
            end
            local levelWidth = Map.map.tilesets[tileSetIndex].tilewidth
            if object.properties.levelWidth then
                levelWidth = object.properties.levelWidth
            end
            local levelHeight = Map.map.tilesets[tileSetIndex].tileheight
            if object.properties.levelHeight then
                levelHeight = object.properties.levelHeight
            end		
            frameIndex = frameIndex - (Map.map.tilesets[tileSetIndex].firstgid - 1)	
            spriteName = object.name
            if not spriteName or spriteName == "" then
                spriteName = ""..object.x.."_"..object.y.."_"..i
            end
            if Sprites.sprites[spriteName] then
                local tempName = spriteName
                local counter = 1
                while Sprites.sprites[tempName] do
                    tempName = ""..spriteName..counter
                    counter = counter + 1
                end
                spriteName = tempName
            end
            Sprites.sprites[spriteName] = display.newImageRect(Map.masterGroup[i], Map.tileSets[tileSetIndex], frameIndex, Map.map.tilewidth, Map.map.tileheight)
            
            local centerX = object.x + (levelWidth * 0.5)
            local centerY = object.y - (levelHeight * 0.5)
            
            if not object.rotation then
                object.rotation = 0
            end
            
            local width = Map.map.tilewidth / 2
            local height = Map.map.tileheight / 2
            
            local hyp = (height) / math.sin(math.rad(45))
            
            local deltaX = hyp * math.sin(math.rad(45 + tonumber(object.rotation)))
            local deltaY = hyp * math.cos(math.rad(45 + tonumber(object.rotation))) * -1
            
            centerX = object.x + deltaX
            centerY = object.y + deltaY
            
            Sprites.sprites[spriteName].rotation = tonumber(object.rotation)
            
            local setup = {layer = layer, kind = "imageRect", levelPosX = centerX, levelPosY = centerY, 
                levelWidth = levelWidth, levelHeight = levelHeight, offsetX = 0, offsetY = 0, name = spriteName
            }
            if PhysicsData.enablePhysics[i] then
                if object.properties.physics == "true" and object.properties.offscreenPhysics then
                    setup.offscreenPhysics = true
                end
            end
            Sprites.addSprite(Sprites.sprites[spriteName], setup, object.properties);

            local maxX, minX, maxY, minY = levelWidth / 2, levelWidth / -2, levelHeight / 2, levelHeight / -2
            local centerX = (maxX - minX) / 2 + minX
            local centerY = (maxY - minY) / 2 + minY
            Sprites.sprites[spriteName].bounds = {math.ceil(centerX / Map.map.tilewidth), 
                math.ceil(centerY / Map.map.tileheight), 
                math.ceil(minX / Map.map.tilewidth), 
                math.ceil(minY / Map.map.tileheight), 
                math.ceil(maxX / Map.map.tilewidth), 
            math.ceil(maxY / Map.map.tileheight)}
            
            if PhysicsData.enablePhysics[i] then
                if object.properties.physics == "true" then
                    if not object.properties.shape or object.properties.shape == "auto" then
                        local w = levelWidth
                        local h = levelHeight
                        shape2 = {0 - (levelWidth / 2), 0 - (levelHeight / 2), 
                            w - (levelWidth / 2), 0 - (levelHeight / 2), 
                            w - (levelWidth / 2), h - (levelHeight / 2), 
                        0 - (levelWidth / 2), h - (levelHeight / 2)}
                    end
                    physics.addBody(Sprites.sprites[spriteName], bodyType, {density = density, friction = friction, bounce = bounce,
                    radius = radius, shape = shape2, filter = filter})
                    if object.properties.isAwake then
                        if object.properties.isAwake == "true" then
                            Sprites.sprites[spriteName].isAwake = true
                        else
                            Sprites.sprites[spriteName].isAwake = false
                        end
                    else
                        Sprites.sprites[spriteName].isAwake = PhysicsData.layer[i].isAwake
                    end
                    if object.properties.isBodyActive then
                        if object.properties.isBodyActive == "true" then
                            Sprites.sprites[spriteName].isBodyActive = true
                        else
                            Sprites.sprites[spriteName].isBodyActive = false
                        end
                    else
                        Sprites.sprites[spriteName].isBodyActive = PhysicsData.layer[i].isActive
                    end
                    --Sprites.sprites[spriteName].isBodyActive = PhysicsData.layer[i].isActive
                end
            end
            
            
            
        end
    elseif object.ellipse then
        listenerCheck = true	
        local width = object.width
        local height = object.height
        spriteName = object.name
        if not spriteName or spriteName == "" then
            spriteName = ""..object.x.."_"..object.y.."_"..i
        end
        if Sprites.sprites[spriteName] then
            local tempName = spriteName
            local counter = 1
            while Sprites.sprites[tempName] do
                tempName = ""..spriteName..counter
                counter = counter + 1
            end
            spriteName = tempName
        end
        local startX = object.x
        local startY = object.y
        Sprites.sprites[spriteName] = display.newGroup()
        Map.masterGroup[i]:insert(Sprites.sprites[spriteName])
        Sprites.sprites[spriteName].x = startX
        Sprites.sprites[spriteName].y = startY
        if Map.map.orientation == Map.Type.Isometric then
            local totalWidth = width
            local totalWidth = height
            local segments
            if width == height then
                segments = 7
            elseif width > height then
                segments = 7
            else
                segments = 8
            end
            local bodies = {}
            local a = width / 2
            local b = height / 2
            local length = width / segments
            local subLength = length / 3
            local startX = a * -1
            local polygons = {}
            local minX = 999999
            local maxX = -999999
            local minY = 999999
            local maxY = -999999
            local finalShape1 = {}
            local finalShape2 = {}
            local counter2 = 0
            for bx = 1, segments, 1 do
                local shape = {}
                for x = startX, startX + length, subLength do
                    local y = math.sqrt( ((a*a)*(b*b) - (b*b)*(x*x)) / (a*a) )
                    shape[#shape + 1] = x + (a)
                    shape[#shape + 1] = y * -1 + (b)
                    if #finalShape1 > 0 then
                        if finalShape1[#finalShape1].x ~= x + (a) and finalShape1[#finalShape1].y ~= y * -1 + (b) then
                            finalShape1[#finalShape1 + 1] = {x = x + (a), y = y * -1 + (b)}
                        end
                    else
                        finalShape1[#finalShape1 + 1] = {x = x + (a), y = y * -1 + (b)}
                    end
                end
                for x = startX + length, startX, subLength * -1 do
                    local y = math.sqrt( ((a*a)*(b*b) - (b*b)*(x*x)) / (a*a) )
                    shape[#shape + 1] = x + (a)
                    shape[#shape + 1] = y + 0.1 + (b)
                end
                local polygon2 = {}
                local shape2 = {}
                for i = 2, #shape, 2 do
                    --Convert world coordinates to isometric screen coordinates
                    --find x,y distances from center
                    local xDelta = shape[i - 1]--shape[i].x
                    local yDelta = shape[i]--shape[i].y
                    local finalX, finalY
                    if xDelta == 0 and yDelta == 0 then
                        finalX = shape[i - 1]--shape[i].x 
                        finalY = shape[i]--shape[i].y
                    else	
                        --find angle
                        local angle = math.atan(xDelta/yDelta)
                        local length = xDelta / math.sin(angle)
                        if xDelta == 0 then
                            length = yDelta
                        elseif yDelta == 0 then
                            length = xDelta
                        end
                        angle = angle - R45
                        
                        --find new deltas
                        local xDelta2 = length * math.sin(angle)
                        local yDelta2 = length * math.cos(angle)
                        
                        finalX = xDelta2 / 1
                        finalY = yDelta2 / Map.map.isoRatio
                    end
                    
                    shape2[i - 1] = finalX 
                    shape2[i] = finalY + Map.map.tilewidth / (4 * (Map.isoScaleMod))
                    
                    polygon2[i / 2] = {}
                    polygon2[i / 2].x = finalX
                    polygon2[i / 2].y = finalY + Map.map.tilewidth / (4 * (Map.isoScaleMod))
                end				
                if PhysicsData.enablePhysics[i] then
                    bodies[#bodies + 1] = {density = density, 
                        friction = friction, 
                        bounce = bounce, 
                        shape = shape2,
                        filter = filter
                    }
                end				
                startX = startX + length				
                for i = 1, #polygon2, 1 do
                    if polygon2[i].x > maxX then
                        maxX = polygon2[i].x
                    end
                    if polygon2[i].x < minX then
                        minX = polygon2[i].x
                    end
                    if polygon2[i].y > maxY then
                        maxY = polygon2[i].y
                    end
                    if polygon2[i].y < minY then
                        minY = polygon2[i].y
                    end
                end						
            end			
            local finalShape3 = {}
            local finalShape4 = {}
            for i = 1, #finalShape1, 1 do
                --Convert world coordinates to isometric screen coordinates
                --find x,y distances from center
                local xDelta = finalShape1[i].x
                local yDelta = finalShape1[i].y
                local finalX, finalY
                if xDelta == 0 and yDelta == 0 then
                    finalX = finalShape1[i].x 
                    finalY = finalShape1[i].y
                else	
                    --find angle
                    local angle = math.atan(xDelta/yDelta)
                    local length = xDelta / math.sin(angle)
                    if xDelta == 0 then
                        length = yDelta
                    elseif yDelta == 0 then
                        length = xDelta
                    end
                    angle = angle - R45
                    
                    --find new deltas
                    local xDelta2 = length * math.sin(angle)
                    local yDelta2 = length * math.cos(angle)
                    
                    finalX = xDelta2 / 1
                    finalY = yDelta2 / Map.map.isoRatio
                end
                
                finalShape3[i] = {}
                finalShape3[i].x = finalX
                finalShape3[i].y = finalY + Map.map.tilewidth / (4 * (Map.isoScaleMod))
            end
            for i = 1, #finalShape1, 1 do
                local xDelta = finalShape1[i].x
                local yDelta = finalShape1[i].y * -1 + (object.height )
                local finalX, finalY
                if xDelta == 0 and yDelta == 0 then
                    finalX = finalShape1[i].x
                    finalY = finalShape1[i].y * -1 + (object.height )
                else	
                    --find angle
                    local angle = math.atan(xDelta/yDelta)
                    local length = xDelta / math.sin(angle)
                    if xDelta == 0 then
                        length = yDelta
                    elseif yDelta == 0 then
                        length = xDelta
                    end
                    angle = angle - R45
                    
                    --find new deltas
                    local xDelta2 = length * math.sin(angle)
                    local yDelta2 = length * math.cos(angle)
                    
                    finalX = xDelta2 / 1
                    finalY = yDelta2 / Map.map.isoRatio
                end
                
                finalShape4[i] = {}
                finalShape4[i].x = finalX
                finalShape4[i].y = finalY + Map.map.tilewidth / (4 * (Map.isoScaleMod))
            end
            for i = 1, #finalShape3, 1 do
                local startX = finalShape3[i].x
                local startY = finalShape3[i].y
                
                local n = i + 1
                if n <= #finalShape3 then
                    local endX = finalShape3[n].x
                    local endY = finalShape3[n].y
                    
                    if i == 1 then
                        display.newLine(Sprites.sprites[spriteName], startX, startY, endX, endY)
                    else
                        Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:append(endX, endY)
                    end
                    Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:setStrokeColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
                    Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].color = {lineColor[1], lineColor[2], lineColor[3], lineColor[4]}
                    --Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].lighting = false
                    Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].strokeWidth = lineWidth
                end
            end
            for i = #finalShape4, 1, -1 do
                local startX = finalShape4[i].x
                local startY = finalShape4[i].y
                
                local n = i - 1
                if n >= 1 then
                    local endX = finalShape4[n].x
                    local endY = finalShape4[n].y		
                    
                    Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:append(endX, endY)
                    Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:setStrokeColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
                    Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].color = {lineColor[1], lineColor[2], lineColor[3], lineColor[4]}
                    --Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].lighting = false
                    Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].strokeWidth = lineWidth
                end
            end
            local levelPosX = object.x
            local levelPosY = object.y
            local offsetX = 0
            local offsetY = 0
            if Map.map.orientation == Map.Type.Isometric then
                offsetY = 0 - (worldScaleX * 0.5 * Map.isoScaleMod)
            end
            local setup = {layer = layer, kind = "vector", levelPosX = levelPosX, levelPosY = levelPosY, 
                levelWidth = width, levelHeight = height, sourceWidth = width, sourceHeight = height, offsetX = offsetX, offsetY = offsetY, name = spriteName
            }
            if PhysicsData.enablePhysics[i] then
                if object.properties.physics == "true" and object.properties.offscreenPhysics then
                    setup.offscreenPhysics = true
                end
            end
            Sprites.sprites[spriteName].lighting = false
            Sprites.addSprite(Sprites.sprites[spriteName], setup, object.properties);
            if PhysicsData.enablePhysics[i] then
                physics.addBody(Sprites.sprites[spriteName], bodyType, unpack(bodies))
            end
        else
            if width == height then
                --perfect circle
                display.newCircle(Sprites.sprites[spriteName], 0, 0, width / 2)
                if object.properties.lineWidth then
                    Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].strokeWidth = object.properties.lineWidth
                end
                if object.properties.lineColor then
                    Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:setStrokeColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
                    Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].color = {lineColor[1], lineColor[2], lineColor[3], lineColor[4]}
                end
                if object.properties.fillColor then
                    Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:setFillColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4])
                    --Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].color = {fillColor[1], fillColor[2], fillColor[3], fillColor[4]}
                else
                    Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:setFillColor(0, 0, 0, 0)
                end
                if object.rotation then
                    Sprites.sprites[spriteName].rotation = tonumber(object.rotation)
                end
                local setup = {layer = layer, kind = "vector", levelPosX = object.x + width / 2, levelPosY = object.y + height / 2, 
                    levelWidth = width, levelHeight = height, sourceWidth = width, sourceHeight = height, offsetX = 0, offsetY = 0, name = spriteName
                }
                if PhysicsData.enablePhysics[i] then
                    if object.properties.physics == "true" and object.properties.offscreenPhysics then
                        setup.offscreenPhysics = true
                    end
                end
                Sprites.sprites[spriteName].lighting = false
                Sprites.addSprite(Sprites.sprites[spriteName], setup, object.properties);
                local maxX, minX, maxY, minY = width / 2, width / -2, height / 2, height / -2
                local centerX = (maxX - minX) / 2 + minX
                local centerY = (maxY - minY) / 2 + minY
                Sprites.sprites[spriteName].bounds = {math.ceil(centerX / Map.map.tilewidth), 
                    math.ceil(centerY / Map.map.tileheight), 
                    math.ceil(minX / Map.map.tilewidth), 
                    math.ceil(minY / Map.map.tileheight), 
                    math.ceil(maxX / Map.map.tilewidth), 
                math.ceil(maxY / Map.map.tileheight)}
                if PhysicsData.enablePhysics[i] then
                    if object.properties.physics == "true" then
                        if not object.properties.shape or object.properties.shape == "auto" then
                            shape2 = nil
                            radius = width / 2
                        end
                        physics.addBody(Sprites.sprites[spriteName], bodyType, {density = density, friction = friction, bounce = bounce,
                        radius = radius, shape = shape2, filter = filter})
                        
                        if object.properties.isAwake then
                            if object.properties.isAwake == "true" then
                                Sprites.sprites[spriteName].isAwake = true
                            else
                                Sprites.sprites[spriteName].isAwake = false
                            end
                        else
                            Sprites.sprites[spriteName].isAwake = PhysicsData.layer[i].isAwake
                        end
                        --Sprites.sprites[spriteName].isAwake = PhysicsData.layer[i].isAwake
                        if object.properties.isBodyActive then
                            if object.properties.isBodyActive == "true" then
                                Sprites.sprites[spriteName].isBodyActive = true
                            else
                                Sprites.sprites[spriteName].isBodyActive = false
                            end
                        else
                            Sprites.sprites[spriteName].isBodyActive = PhysicsData.layer[i].isActive
                        end
                        --Sprites.sprites[spriteName].isBodyActive = PhysicsData.layer[i].isActive
                    end
                end
            else
                --ellipse
                local tempC
                if width < height then
                    tempC = width
                else
                    tempC = height
                end
                display.newCircle(Sprites.sprites[spriteName], tempC / 2, tempC / 2, tempC / 2)
                if object.properties.lineWidth then
                    Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].strokeWidth = object.properties.lineWidth
                end
                if object.properties.lineColor then
                    Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:setStrokeColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
                    Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].color = {lineColor[1], lineColor[2], lineColor[3], lineColor[4]}
                end
                if object.properties.fillColor then
                    Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:setFillColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4])
                    --Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].color = {fillColor[1], fillColor[2], fillColor[3], fillColor[4]}
                else
                    Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:setFillColor(0, 0, 0, 0)
                end
                
                if object.rotation then
                    Sprites.sprites[spriteName].rotation = tonumber(object.rotation)
                end
                
                local setup = {layer = layer, kind = "vector", levelPosX = object.x, levelPosY = object.y, 
                    levelWidth = width, levelHeight = height, sourceWidth = tempC, sourceHeight = tempC, offsetX = 0, offsetY = 0, name = spriteName
                }
                if PhysicsData.enablePhysics[i] then
                    if object.properties.physics == "true" and object.properties.offscreenPhysics then
                        setup.offscreenPhysics = true
                    end
                end
                Sprites.sprites[spriteName].lighting = false
                Sprites.addSprite(Sprites.sprites[spriteName], setup, object.properties);
                local minX = 0
                local maxX = width
                local minY = 0
                local maxY = height
                if maxX < minX then
                    local temp = maxX
                    maxX = minX
                    minX = temp
                end
                if maxY < minY then
                    local temp = maxY
                    maxY = minY
                    minY = temp
                end
                local centerX = (maxX - minX) / 2 + minX
                local centerY = (maxY - minY) / 2 + minY
                Sprites.sprites[spriteName].bounds = {math.ceil(centerX / Map.map.tilewidth), 
                    math.ceil(centerY / Map.map.tileheight), 
                    math.ceil(minX / Map.map.tilewidth), 
                    math.ceil(minY / Map.map.tileheight), 
                    math.ceil(maxX / Map.map.tilewidth), 
                math.ceil(maxY / Map.map.tileheight)}
                if PhysicsData.enablePhysics[i] then
                    if object.properties.physics == "true" then
                        local segments = 5
                        if object.properties.physicsBodies then
                            segments = tonumber(object.properties.physicsBodies)
                        end
                        if not object.properties.shape or object.properties.shape == "auto" then
                            local bodies = {}
                            local a = width / 2
                            local b = height / 2
                            local length = width / segments
                            local subLength = length / 3
                            local startX = a * -1
                            for bx = 1, segments, 1 do
                                local shape = {}
                                for x = startX, startX + length, subLength do
                                    local y = math.sqrt( ((a*a)*(b*b) - (b*b)*(x*x)) / (a*a) )
                                    shape[#shape + 1] = x + (a)
                                    shape[#shape + 1] = y * -1 + (b)
                                end
                                for x = startX + length, startX, subLength * -1 do
                                    local y = math.sqrt( ((a*a)*(b*b) - (b*b)*(x*x)) / (a*a) )
                                    shape[#shape + 1] = x + (a)
                                    shape[#shape + 1] = y + 0.1 + (b)
                                end
                                bodies[#bodies + 1] = {density = density, 
                                    friction = friction, 
                                    bounce = bounce, 
                                    shape = shape,
                                    filter = filter
                                }
                                startX = startX + length
                            end
                            physics.addBody(Sprites.sprites[spriteName], bodyType, unpack(bodies))
                        else
                            physics.addBody(Sprites.sprites[spriteName], bodyType, {density = density, friction = friction, bounce = bounce,
                            radius = radius, shape = shape2, filter = filter})
                        end
                        if object.properties.isAwake then
                            if object.properties.isAwake == "true" then
                                Sprites.sprites[spriteName].isAwake = true
                            else
                                Sprites.sprites[spriteName].isAwake = false
                            end
                        else
                            Sprites.sprites[spriteName].isAwake = PhysicsData.layer[i].isAwake
                        end
                        --Sprites.sprites[spriteName].isAwake = PhysicsData.layer[i].isAwake
                        if object.properties.isBodyActive then
                            if object.properties.isBodyActive == "true" then
                                Sprites.sprites[spriteName].isBodyActive = true
                            else
                                Sprites.sprites[spriteName].isBodyActive = false
                            end
                        else
                            Sprites.sprites[spriteName].isBodyActive = PhysicsData.layer[i].isActive
                        end
                        --Sprites.sprites[spriteName].isBodyActive = PhysicsData.layer[i].isActive
                    end
                end
                --------
            end
        end
    elseif object.polygon then
        listenerCheck = true	
        local polygon = object.polygon
        spriteName = object.name
        if not spriteName or spriteName == "" then
            spriteName = ""..object.x.."_"..object.y.."_"..i
        end
        if Sprites.sprites[spriteName] then
            local tempName = spriteName
            local counter = 1
            while Sprites.sprites[tempName] do
                tempName = ""..spriteName..counter
                counter = counter + 1
            end
            spriteName = tempName
        end
        local startX = object.x
        local startY = object.y
        Sprites.sprites[spriteName] = display.newGroup()
        Map.masterGroup[i]:insert(Sprites.sprites[spriteName])
        Sprites.sprites[spriteName].x = startX
        Sprites.sprites[spriteName].y = startY			
        local polygon2 = {}
        for i = 1, #polygon, 1 do
            if Map.map.orientation == Map.Type.Isometric then
                polygon[i].x = polygon[i].x - (worldScaleX * 0.5)
                polygon[i].y = polygon[i].y - (worldScaleX * 0.5)
                
                --Convert world coordinates to isometric screen coordinates
                --find x,y distances from center
                local xDelta = polygon[i].x
                local yDelta = polygon[i].y
                local finalX, finalY
                if xDelta == 0 and yDelta == 0 then
                    finalX = polygon[i].x 
                    finalY = polygon[i].y
                else	
                    --find angle
                    local angle = math.atan(xDelta/yDelta)
                    local length = xDelta / math.sin(angle)
                    if xDelta == 0 then
                        length = yDelta
                    elseif yDelta == 0 then
                        length = xDelta
                    end
                    angle = angle - R45
                    
                    --find new deltas
                    local xDelta2 = length * math.sin(angle)
                    local yDelta2 = length * math.cos(angle)
                    
                    finalX = xDelta2 / 1
                    finalY = yDelta2 / Map.map.isoRatio
                end
                
                polygon2[i] = {}
                polygon2[i].x = finalX
                polygon2[i].y = finalY + Map.map.tilewidth / (4 * (Map.isoScaleMod))
            else
                polygon2[i] = {}
                polygon2[i].x = polygon[i].x
                polygon2[i].y = polygon[i].y
            end
        end
        for i = 1, #polygon2, 1 do
            local startX = polygon2[i].x
            local startY = polygon2[i].y			
            
            local n = i + 1
            if n > #polygon2 then
                n = 1
            end
            
            local endX = polygon2[n].x
            local endY = polygon2[n].y			
            
            if i == 1 then
                display.newLine(Sprites.sprites[spriteName], startX, startY, endX, endY)
            else
                Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:append(endX, endY)
            end
        end		
        local minX = 999999
        local maxX = -999999
        local minY = 999999
        local maxY = -999999
        for i = 1, #polygon2, 1 do
            if polygon2[i].x > maxX then
                maxX = polygon2[i].x
            end
            if polygon2[i].x < minX then
                minX = polygon2[i].x
            end
            if polygon2[i].y > maxY then
                maxY = polygon2[i].y
            end
            if polygon2[i].y < minY then
                minY = polygon2[i].y
            end
        end
        local width = math.abs(maxX - minX)
        local height = math.abs(maxY - minY)
        Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:setStrokeColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
        Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].color = {lineColor[1], lineColor[2], lineColor[3], lineColor[4]}
        Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].strokeWidth = lineWidth
        local levelPosX = object.x
        local levelPosY = object.y
        if Map.map.orientation == Map.Type.Isometric then
            levelPosX = levelPosX + (worldScaleX * 0.5)
            levelPosY = levelPosY + (worldScaleX * 0.5)
        else
            if object.rotation then
                Sprites.sprites[spriteName].rotation = tonumber(object.rotation)
            end
        end
        local setup = {layer = layer, kind = "vector", levelPosX = levelPosX, levelPosY = levelPosY, 
            levelWidth = width, levelHeight = height, sourceWidth = width, sourceHeight = height, offsetX = 0, offsetY = 0, name = spriteName
        }
        if PhysicsData.enablePhysics[i] then
            if object.properties.physics == "true" and object.properties.offscreenPhysics then
                setup.offscreenPhysics = true
            end
        end
        Sprites.sprites[spriteName].lighting = false
        Sprites.addSprite(Sprites.sprites[spriteName], setup, object.properties);
        local centerX = (maxX - minX) / 2 + minX
        local centerY = (maxY - minY) / 2 + minY
        Sprites.sprites[spriteName].bounds = {math.ceil(centerX / Map.map.tilewidth), 
            math.ceil(centerY / Map.map.tileheight), 
            math.ceil(minX / Map.map.tilewidth), 
            math.ceil(minY / Map.map.tileheight), 
            math.ceil(maxX / Map.map.tilewidth), 
        math.ceil(maxY / Map.map.tileheight)}
        if PhysicsData.enablePhysics[i] then
            if object.properties.physics == "true" then
                if not object.properties.shape or object.properties.shape == "auto" then
                    local bodies = {}			
                    local function det(x1,y1, x2,y2)
                        return x1*y2 - y1*x2
                    end
                    local function ccw(p, q, r)
                        return det(q.x-p.x, q.y-p.y,  r.x-p.x, r.y-p.y) >= 0
                    end			
                    local function areCollinear(p, q, r, eps)
                        return math.abs(det(q.x-p.x, q.y-p.y,  r.x-p.x,r.y-p.y)) <= (eps or 1e-32)
                    end
                    local triangles = {} -- list of triangles to be returned
                    local concave = {}   -- list of concave edges
                    local adj = {}       -- vertex adjacencies
                    local vertices = polygon2
                    -- retrieve adjacencies as the rest will be easier to implement
                    for i,p in ipairs(vertices) do
                        local l = (i == 1) and vertices[#vertices] or vertices[i-1]
                        local r = (i == #vertices) and vertices[1] or vertices[i+1]
                        adj[p] = {p = p, l = l, r = r} -- point, left and right neighbor
                        -- test if vertex is a concave edge
                        if not ccw(l,p,r) then concave[p] = p end
                    end				
                    local function onSameSide(a,b, c,d)
                        local px, py = d.x-c.x, d.y-c.y
                        local l = det(px,py,  a.x-c.x, a.y-c.y)
                        local m = det(px,py,  b.x-c.x, b.y-c.y)
                        return l*m >= 0
                    end
                    local function pointInTriangle(p, a,b,c)
                        return onSameSide(p,a, b,c) and onSameSide(p,b, a,c) and onSameSide(p,c, a,b)
                    end				
                    -- and ear is an edge of the polygon that contains no other
                    -- vertex of the polygon
                    local function isEar(p1,p2,p3)
                        if not ccw(p1,p2,p3) then return false end
                        for q,_ in pairs(concave) do
                            if q ~= p1 and q ~= p2 and q ~= p3 and pointInTriangle(q, p1,p2,p3) then
                                --if q ~= p1 and q ~= p2 and q ~= p3 then
                                return false
                            end
                        end
                        return true
                    end
                    -- main loop
                    local nPoints, skipped = #vertices, 0
                    local p = adj[ vertices[2] ]
                    while nPoints > 3 do
                        if not concave[p.p] and isEar(p.l, p.p, p.r) then
                            -- polygon may be a 'collinear triangle', i.e.
                            -- all three points are on a line. In that case
                            -- the polygon constructor throws an error.
                            if not areCollinear(p.l, p.p, p.r) then
                                triangles[#triangles+1] = {p.l.x,p.l.y, p.p.x,p.p.y, p.r.x,p.r.y}
                                bodies[#bodies + 1] = {density = density, 
                                    friction = friction, 
                                    bounce = bounce, 
                                    shape = {p.l.x, p.l.y, 
                                        p.p.x, p.p.y, 
                                        p.r.x, p.r.y
                                    },
                                    filter = filter
                                }
                                skipped = 0
                            end
                            if concave[p.l] and ccw(adj[p.l].l, p.l, p.r) then
                                concave[p.l] = nil
                            end
                            if concave[p.r] and ccw(p.l, p.r, adj[p.r].r) then
                                concave[p.r] = nil
                            end
                            -- remove point from list
                            adj[p.p] = nil
                            adj[p.l].r = p.r
                            adj[p.r].l = p.l
                            nPoints = nPoints - 1
                            skipped = 0
                            p = adj[p.l]
                        else
                            p = adj[p.r]
                            skipped = skipped + 1
                            assert(skipped <= nPoints, "Cannot triangulate polygon (is the polygon intersecting itself?)")
                        end
                    end
                    if not areCollinear(p.l, p.p, p.r) then
                        triangles[#triangles+1] = {p.l.x,p.l.y, p.p.x,p.p.y, p.r.x,p.r.y}
                        bodies[#bodies + 1] = {density = density, 
                            friction = friction, 
                            bounce = bounce, 
                            shape = {p.l.x, p.l.y, 
                                p.p.x, p.p.y, 
                                p.r.x, p.r.y
                            },
                            filter = filter
                        }
                    end
                    physics.addBody(Sprites.sprites[spriteName], bodyType, unpack(bodies))
                else
                    physics.addBody(Sprites.sprites[spriteName], bodyType, {density = density, friction = friction, bounce = bounce,
                    radius = radius, shape = shape2, filter = filter})
                end
                if object.properties.isAwake then
                    if object.properties.isAwake == "true" then
                        Sprites.sprites[spriteName].isAwake = true
                    else
                        Sprites.sprites[spriteName].isAwake = false
                    end
                else
                    Sprites.sprites[spriteName].isAwake = PhysicsData.layer[i].isAwake
                end
                --Sprites.sprites[spriteName].isAwake = PhysicsData.layer[i].isAwake
                if object.properties.isBodyActive then
                    if object.properties.isBodyActive == "true" then
                        Sprites.sprites[spriteName].isBodyActive = true
                    else
                        Sprites.sprites[spriteName].isBodyActive = false
                    end
                else
                    Sprites.sprites[spriteName].isBodyActive = PhysicsData.layer[i].isActive
                end
                --Sprites.sprites[spriteName].isBodyActive = PhysicsData.layer[i].isActive
            end
        end	
    elseif object.polyline then
        listenerCheck = true	
        local polyline = object.polyline
        spriteName = object.name
        if not spriteName or spriteName == "" then
            spriteName = ""..object.x.."_"..object.y.."_"..i
        end
        if Sprites.sprites[spriteName] then
            local tempName = spriteName
            local counter = 1
            while Sprites.sprites[tempName] do
                tempName = ""..spriteName..counter
                counter = counter + 1
            end
            spriteName = tempName
        end
        local startX = object.x
        local startY = object.y
        Sprites.sprites[spriteName] = display.newGroup()
        Map.masterGroup[i]:insert(Sprites.sprites[spriteName])
        Sprites.sprites[spriteName].x = startX
        Sprites.sprites[spriteName].y = startY		
        local polyline2 = {}
        for i = 1, #polyline, 1 do
            if Map.map.orientation == Map.Type.Isometric then
                polyline[i].x = polyline[i].x - (worldScaleX * 0.5)
                polyline[i].y = polyline[i].y - (worldScaleX * 0.5)
                
                --Convert world coordinates to isometric screen coordinates
                --find x,y distances from center
                local xDelta = polyline[i].x
                local yDelta = polyline[i].y
                local finalX, finalY
                if xDelta == 0 and yDelta == 0 then
                    finalX = polyline[i].x 
                    finalY = polyline[i].y
                else	
                    --find angle
                    local angle = math.atan(xDelta/yDelta)
                    local length = xDelta / math.sin(angle)
                    if xDelta == 0 then
                        length = yDelta
                    elseif yDelta == 0 then
                        length = xDelta
                    end
                    angle = angle - R45
                    
                    --find new deltas
                    local xDelta2 = length * math.sin(angle)
                    local yDelta2 = length * math.cos(angle)
                    
                    finalX = xDelta2 / 1
                    finalY = yDelta2 / Map.map.isoRatio
                end
                
                polyline2[i] = {}
                polyline2[i].x = finalX
                polyline2[i].y = finalY + Map.map.tilewidth / (4 * (Map.isoScaleMod))
            else
                polyline2[i] = {}
                polyline2[i].x = polyline[i].x
                polyline2[i].y = polyline[i].y
            end
        end
        local minX = 999999
        local maxX = -999999
        local minY = 999999
        local maxY = -999999
        for i = 1, #polyline2, 1 do
            if polyline2[i].x > maxX then
                maxX = polyline2[i].x
            end
            if polyline2[i].x < minX then
                minX = polyline2[i].x
            end
            if polyline2[i].y > maxY then
                maxY = polyline2[i].y
            end
            if polyline2[i].y < minY then
                minY = polyline2[i].y
            end
        end
        local width = math.abs(maxX - minX)
        local height = math.abs(maxY - minY)
        local hW = lineWidth / 2
        local bodies = {}
        for i = 1, #polyline2, 1 do
            local startX = polyline2[i].x
            local startY = polyline2[i].y
            
            local n = i + 1
            if n > #polyline2 then
                break
            end
            
            local endX = polyline2[n].x
            local endY = polyline2[n].y
            
            if i == 1 then
                display.newLine(Sprites.sprites[spriteName], startX, startY, endX, endY)
            else
                Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:append(endX, endY)
            end
            
            local theta = math.atan((startY - endY)/(endX - startX))
            local offX = (math.sin(theta) * hW)
            local offY = (math.cos(theta) * hW)
            local x1 = (startX - offX)
            local y1 = (startY - offY)
            local x2 = (endX - offX)
            local y2 = (endY - offY)
            local x3 = (endX + offX)
            local y3 = (endY + offY)
            local x4 = (startX + offX)
            local y4 = (startY + offY)
            if PhysicsData.enablePhysics[layer] then
                bodies[#bodies + 1] = {density = density, friction = friction, bounce = bounce, 
                    shape = {x1, y1, x2, y2, x3, y3, x4, y4},filter = filter
                }
            end
        end
        Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:setStrokeColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
        Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].color = {lineColor[1], lineColor[2], lineColor[3], lineColor[4]}
        Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].strokeWidth = lineWidth
        local levelPosX = object.x
        local levelPosY = object.y
        
        if Map.map.orientation == Map.Type.Isometric then
            levelPosX = levelPosX + (worldScaleX * 0.5)
            levelPosY = levelPosY + (worldScaleX * 0.5)
        else
            if object.rotation then
                Sprites.sprites[spriteName].rotation = tonumber(object.rotation)
            end
        end
        
        local setup = {layer = layer, kind = "vector", levelPosX = levelPosX, levelPosY = levelPosY, 
            levelWidth = width, levelHeight = height, sourceWidth = width, sourceHeight = height, offsetX = 0, offsetY = 0, name = spriteName
        }
        if PhysicsData.enablePhysics[i] then
            if object.properties.physics == "true" and object.properties.offscreenPhysics then
                setup.offscreenPhysics = true
            end
        end
        Sprites.sprites[spriteName].lighting = false
        Sprites.addSprite(Sprites.sprites[spriteName], setup, object.properties);
        local centerX = (maxX - minX) / 2 + minX
        local centerY = (maxY - minY) / 2 + minY
        Sprites.sprites[spriteName].bounds = {math.ceil(centerX / Map.map.tilewidth), 
            math.ceil(centerY / Map.map.tileheight), 
            math.ceil(minX / Map.map.tilewidth), 
            math.ceil(minY / Map.map.tileheight), 
            math.ceil(maxX / Map.map.tilewidth), 
        math.ceil(maxY / Map.map.tileheight)}
        if PhysicsData.enablePhysics[i] then
            if object.properties.physics == "true" then
                if not object.properties.shape or object.properties.shape == "auto" then
                    physics.addBody(Sprites.sprites[spriteName], bodyType, unpack(bodies))
                else
                    physics.addBody(Sprites.sprites[spriteName], bodyType, {density = density, friction = friction, bounce = bounce,
                        radius = radius, shape = shape2, filter = filter
                    })
                end
                if object.properties.isAwake then
                    if object.properties.isAwake == "true" then
                        Sprites.sprites[spriteName].isAwake = true
                    else
                        Sprites.sprites[spriteName].isAwake = false
                    end
                else
                    Sprites.sprites[spriteName].isAwake = PhysicsData.layer[i].isAwake
                end
                --Sprites.sprites[spriteName].isAwake = PhysicsData.layer[i].isAwake
                if object.properties.isBodyActive then
                    if object.properties.isBodyActive == "true" then
                        Sprites.sprites[spriteName].isBodyActive = true
                    else
                        Sprites.sprites[spriteName].isBodyActive = false
                    end
                else
                    Sprites.sprites[spriteName].isBodyActive = PhysicsData.layer[i].isActive
                end
                --Sprites.sprites[spriteName].isBodyActive = PhysicsData.layer[i].isActive
            end
        end
    else --rectangle
        listenerCheck = true
        local width = object.width
        local height = object.height
        local startX = object.x
        local startY = object.y
        spriteName = object.name
        if not spriteName or spriteName == "" then
            spriteName = ""..object.x.."_"..object.y.."_"..i
        end
        if Sprites.sprites[spriteName] then
            local tempName = spriteName
            local counter = 1
            while Sprites.sprites[tempName] do
                tempName = ""..spriteName..counter
                counter = counter + 1
            end
            spriteName = tempName
        end
        Sprites.sprites[spriteName] = display.newGroup()
        Map.masterGroup[i]:insert(Sprites.sprites[spriteName])
        Sprites.sprites[spriteName].x = startX
        Sprites.sprites[spriteName].y = startY
        local polygon2 = {}
        if Map.map.orientation == Map.Type.Isometric then
                local polygon = {{x = 0 - (worldScaleX * 0.5), y = 0 - (worldScaleX * 0.5)},
                {x = width - (worldScaleX * 0.5), y = 0 - (worldScaleX * 0.5)},
                {x = width - (worldScaleX * 0.5), y = height - (worldScaleX * 0.5)},
                {x = 0 - (worldScaleX * 0.5), y = height - (worldScaleX * 0.5)}
            }
            for i = 1, #polygon, 1 do
                --Convert world coordinates to isometric screen coordinates
                --find x,y distances from center
                local xDelta = polygon[i].x
                local yDelta = polygon[i].y
                local finalX, finalY
                if xDelta == 0 and yDelta == 0 then
                    finalX = polygon[i].x 
                    finalY = polygon[i].y
                else	
                    --find angle
                    local angle = math.atan(xDelta/yDelta)
                    local length = xDelta / math.sin(angle)
                    if xDelta == 0 then
                        length = yDelta
                    elseif yDelta == 0 then
                        length = xDelta
                    end
                    angle = angle - R45
                    
                    --find new deltas
                    local xDelta2 = length * math.sin(angle)
                    local yDelta2 = length * math.cos(angle)
                    
                    finalX = xDelta2 / 1
                    finalY = yDelta2 / Map.map.isoRatio
                end
                
                polygon2[i] = {}
                polygon2[i].x = finalX
                polygon2[i].y = finalY + Map.map.tilewidth / (4 * (Map.isoScaleMod))
            end
            for i = 1, #polygon2, 1 do
                local startX = polygon2[i].x
                local startY = polygon2[i].y			
                
                local n = i + 1
                if n > #polygon2 then
                    n = 1
                end
                
                local endX = polygon2[n].x
                local endY = polygon2[n].y			
                
                if i == 1 then
                    display.newLine(Sprites.sprites[spriteName], startX, startY, endX, endY)
                else
                    Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:append(endX, endY)
                end
            end
            local minX = 999999
            local maxX = -999999
            local minY = 999999
            local maxY = -999999
            for i = 1, #polygon2, 1 do
                if polygon2[i].x > maxX then
                    maxX = polygon2[i].x
                end
                if polygon2[i].x < minX then
                    minX = polygon2[i].x
                end
                if polygon2[i].y > maxY then
                    maxY = polygon2[i].y
                end
                if polygon2[i].y < minY then
                    minY = polygon2[i].y
                end
            end
            width = math.abs(maxX - minX)
            height = math.abs(maxY - minY)
            Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:setStrokeColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
            Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].color = {lineColor[1], lineColor[2], lineColor[3], lineColor[4]}
            Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].strokeWidth = lineWidth
        else
            display.newRect(Sprites.sprites[spriteName], width * 0.5, height * 0.5, width, height)
            if object.properties.lineWidth then
                Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].strokeWidth = object.properties.lineWidth
            end
            if object.properties.lineColor then
                Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:setStrokeColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
                Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren].color = {lineColor[1], lineColor[2], lineColor[3], lineColor[4]}
            end
            if object.properties.fillColor then
                Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:setFillColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4])
            else
                Sprites.sprites[spriteName][Sprites.sprites[spriteName].numChildren]:setFillColor(0, 0, 0, 0)
            end
        end
        local levelPosX = object.x
        local levelPosY = object.y
        if Map.map.orientation == Map.Type.Isometric then
            levelPosX = levelPosX + (worldScaleX * 0.5)
            levelPosY = levelPosY + (worldScaleX * 0.5)
        else
            if object.rotation then
                Sprites.sprites[spriteName].rotation = tonumber(object.rotation)
            end
        end
        local setup = {layer = layer, kind = "vector", levelPosX = levelPosX, levelPosY = levelPosY, 
            levelWidth = width, levelHeight = height, sourceWidth = width, sourceHeight = height, offsetX = 0, offsetY = 0, name = spriteName
        }
        if PhysicsData.enablePhysics[i] then
            if object.properties.physics == "true" and object.properties.offscreenPhysics then
                setup.offscreenPhysics = true
            end
        end
        Sprites.sprites[spriteName].lighting = false
        Sprites.addSprite(Sprites.sprites[spriteName], setup, object.properties);
        local minX = 0
        local maxX = width
        local minY = 0
        local maxY = height
        if maxX < minX then
            local temp = maxX
            maxX = minX
            minX = temp
        end
        if maxY < minY then
            local temp = maxY
            maxY = minY
            minY = temp
        end
        local centerX = (maxX - minX) / 2 + minX
        local centerY = (maxY - minY) / 2 + minY
        Sprites.sprites[spriteName].bounds = {math.ceil(centerX / Map.map.tilewidth), 
            math.ceil(centerY / Map.map.tileheight), 
            math.ceil(minX / Map.map.tilewidth), 
            math.ceil(minY / Map.map.tileheight), 
            math.ceil(maxX / Map.map.tilewidth), 
        math.ceil(maxY / Map.map.tileheight)}
        if PhysicsData.enablePhysics[i] then
            if object.properties.physics == "true" then
                if Map.map.orientation == Map.Type.Isometric then
                    if not object.properties.shape or object.properties.shape == "auto" then
                        local bodies = {}			
                        local function det(x1,y1, x2,y2)
                            return x1*y2 - y1*x2
                        end
                        local function ccw(p, q, r)
                            return det(q.x-p.x, q.y-p.y,  r.x-p.x, r.y-p.y) >= 0
                        end
                        local function areCollinear(p, q, r, eps)
                            return math.abs(det(q.x-p.x, q.y-p.y,  r.x-p.x,r.y-p.y)) <= (eps or 1e-32)
                        end
                        local triangles = {} -- list of triangles to be returned
                        local concave = {}   -- list of concave edges
                        local adj = {}       -- vertex adjacencies
                        local vertices = polygon2				
                        -- retrieve adjacencies as the rest will be easier to implement
                        for i,p in ipairs(vertices) do
                            local l = (i == 1) and vertices[#vertices] or vertices[i-1]
                            local r = (i == #vertices) and vertices[1] or vertices[i+1]
                            adj[p] = {p = p, l = l, r = r} -- point, left and right neighbor
                            -- test if vertex is a concave edge
                            if not ccw(l,p,r) then concave[p] = p end
                        end				
                        local function onSameSide(a,b, c,d)
                            local px, py = d.x-c.x, d.y-c.y
                            local l = det(px,py,  a.x-c.x, a.y-c.y)
                            local m = det(px,py,  b.x-c.x, b.y-c.y)
                            return l*m >= 0
                        end
                        local function pointInTriangle(p, a,b,c)
                            return onSameSide(p,a, b,c) and onSameSide(p,b, a,c) and onSameSide(p,c, a,b)
                        end				
                        -- and ear is an edge of the polygon that contains no other
                        -- vertex of the polygon
                        local function isEar(p1,p2,p3)
                            if not ccw(p1,p2,p3) then return false end
                            for q,_ in pairs(concave) do
                                if q ~= p1 and q ~= p2 and q ~= p3 and pointInTriangle(q, p1,p2,p3) then
                                    return false
                                end
                            end
                            return true
                        end
                        -- main loop
                        local nPoints, skipped = #vertices, 0
                        local p = adj[ vertices[2] ]
                        while nPoints > 3 do
                            if not concave[p.p] and isEar(p.l, p.p, p.r) then
                                -- polygon may be a 'collinear triangle', i.e.
                                -- all three points are on a line. In that case
                                -- the polygon constructor throws an error.
                                if not areCollinear(p.l, p.p, p.r) then
                                    triangles[#triangles+1] = {p.l.x,p.l.y, p.p.x,p.p.y, p.r.x,p.r.y}
                                    bodies[#bodies + 1] = {density = density, 
                                        friction = friction, 
                                        bounce = bounce, 
                                        shape = {p.l.x, p.l.y, 
                                            p.p.x, p.p.y, 
                                            p.r.x, p.r.y
                                        },
                                        filter = filter
                                    }
                                    skipped = 0
                                end
                                if concave[p.l] and ccw(adj[p.l].l, p.l, p.r) then
                                    concave[p.l] = nil
                                end
                                if concave[p.r] and ccw(p.l, p.r, adj[p.r].r) then
                                    concave[p.r] = nil
                                end
                                -- remove point from list
                                adj[p.p] = nil
                                adj[p.l].r = p.r
                                adj[p.r].l = p.l
                                nPoints = nPoints - 1
                                skipped = 0
                                p = adj[p.l]
                            else
                                p = adj[p.r]
                                skipped = skipped + 1
                                assert(skipped <= nPoints, "Cannot triangulate polygon (is the polygon intersecting itself?)")
                            end
                        end
                        
                        if not areCollinear(p.l, p.p, p.r) then
                            triangles[#triangles+1] = {p.l.x,p.l.y, p.p.x,p.p.y, p.r.x,p.r.y}
                            bodies[#bodies + 1] = {density = density, friction = friction, bounce = bounce, 
                                shape = {p.l.x, p.l.y, p.p.x, p.p.y, p.r.x, p.r.y}, filter = filter
                            }
                        end							
                        physics.addBody(Sprites.sprites[spriteName], bodyType, unpack(bodies))
                    else
                        physics.addBody(Sprites.sprites[spriteName], bodyType, {density = density, friction = friction, bounce = bounce,
                            radius = radius, shape = shape2, filter = filter
                        })
                    end
                    if object.properties.isAwake then
                        if object.properties.isAwake == "true" then
                            Sprites.sprites[spriteName].isAwake = true
                        else
                            Sprites.sprites[spriteName].isAwake = false
                        end
                    else
                        Sprites.sprites[spriteName].isAwake = PhysicsData.layer[i].isAwake
                    end
                    --Sprites.sprites[spriteName].isAwake = PhysicsData.layer[i].isAwake
                    if object.properties.isBodyActive then
                        if object.properties.isBodyActive == "true" then
                            Sprites.sprites[spriteName].isBodyActive = true
                        else
                            Sprites.sprites[spriteName].isBodyActive = false
                        end
                    else
                        Sprites.sprites[spriteName].isBodyActive = PhysicsData.layer[i].isActive
                    end
                    --Sprites.sprites[spriteName].isBodyActive = PhysicsData.layer[i].isActive
                else
                    if not object.properties.shape or object.properties.shape == "auto" then
                        local w = width
                        local h = height
                        shape2 = {0, 0, w, 0, w, h, 0, h}
                    end
                    physics.addBody(Sprites.sprites[spriteName], bodyType, {density = density, friction = friction, bounce = bounce,
                        radius = radius, shape = shape2, filter = filter
                    })
                    if object.properties.isAwake then
                        if object.properties.isAwake == "true" then
                            Sprites.sprites[spriteName].isAwake = true
                        else
                            Sprites.sprites[spriteName].isAwake = false
                        end
                    else
                        Sprites.sprites[spriteName].isAwake = PhysicsData.layer[i].isAwake
                    end
                    --Sprites.sprites[spriteName].isAwake = PhysicsData.layer[i].isAwake
                    if object.properties.isBodyActive then
                        if object.properties.isBodyActive == "true" then
                            Sprites.sprites[spriteName].isBodyActive = true
                        else
                            Sprites.sprites[spriteName].isBodyActive = false
                        end
                    else
                        Sprites.sprites[spriteName].isBodyActive = PhysicsData.layer[i].isActive
                    end
                    --Sprites.sprites[spriteName].isBodyActive = PhysicsData.layer[i].isActive
                end
            end
        end
    end
    
    if listenerCheck then
        Sprites.sprites[spriteName].drawnObject = true
        Sprites.sprites[spriteName].objectKey = ky
        Sprites.sprites[spriteName].objectLayer = layer
        Sprites.sprites[spriteName].bounds = nil
        Sprites.sprites[spriteName].properties = object.properties
        Sprites.sprites[spriteName].type = object.type
        object.properties.wasDrawn = true
        
        if Camera.enableLighting then
            if object.properties.lightSource then
                light = {source = json.decode(object.properties.lightSource),
                    range = json.decode(object.properties.lightRange),
                falloff = json.decode(object.properties.lightFalloff)}
                if object.properties.lightArc then
                    light.arc = json.decode(object.properties.lightArc)
                end
                if object.properties.lightRays then
                    light.rays = json.decode(object.properties.lightRays)
                end
                if object.properties.lightLayerFalloff then
                    light.layerFalloff = json.decode(object.properties.lightLayerFalloff)
                end
                if object.properties.lightLayerFalloff then
                    light.levelFalloff = json.decode(object.properties.lightLevelFalloff)
                end
                if object.properties.lightLayer then
                    light.layer = tonumber(object.properties.lightLayer)
                end
                
                Sprites.tempObjects[#Sprites.tempObjects].addLight(light)
            end
        end
        for key,value in pairs(objectDrawListeners) do
            if object.name == key or key == "*" then
                local event = { name = key, target = Sprites.sprites[spriteName], object = object}
                Map.masterGroup:dispatchEvent( event )
            end
        end
        
        return Sprites.sprites[spriteName]
    end
end

-----------------------------------------------------------

Core.redrawObject = function(name)
    local layer = nil
    local key = nil	
    
    if Sprites.sprites[name] and Sprites.sprites[name].drawnObject then
        key = Sprites.sprites[name].objectKey
        layer = Sprites.sprites[name].objectLayer
        Sprite.removeSprite(Sprites.sprites[name])
    end
    
    local objects = Map.map.layers[layer].objects
    return drawObject(objects[key], layer)	
end

-----------------------------------------------------------

Core.drawObject = function(name)
    --find object
    for i = 1, #Map.map.layers, 1 do
        if Map.map.layers[i].objects then
            local objects = Map.map.layers[i].objects
            for key,value in pairs(objects) do
                if objects[key].name == name then
                    if objects[key].gid or (objects[key].properties and 
                        (objects[key].properties.physics or objects[key].properties.lineColor or objects[key].properties.fillColor or objects[key].properties.lineWidth)) then
                        return drawObject(objects[key], i, key)
                    end
                end
            end
        end
    end
end

-----------------------------------------------------------

Core.drawObjects = function(new)
    local t = {}
    for i = 1, #Map.map.layers, 1 do
        if Map.map.layers[i].objects then
            local objects = Map.map.layers[i].objects
            for key,value in pairs(objects) do
                if objects[key].gid or (objects[key].properties and 
                    (objects[key].properties.physics or objects[key].properties.lineColor or objects[key].properties.fillColor or objects[key].properties.lineWidth)) then
                    if not objects[key].properties or ((new and not objects[key].properties.wasDrawn) or not new) then
                        t[#t + 1] = drawObject(objects[key], i, key)
                    end
                end
                
            end
        end
    end
    return t
end

-----------------------------------------------------------

Core.addPropertyListener = function(name, listener)
    propertyListeners[name] = true
    Map.masterGroup:addEventListener(name, listener)
end

-----------------------------------------------------------

Core.addObjectDrawListener = function(name, listener)
    objectDrawListeners[name] = true
    Map.masterGroup:addEventListener(name, listener)
end

-----------------------------------------------------------

Core.refresh = function()
    
    Map.setMapProperties(Map.map.properties)
    for i = 1, #Map.map.layers, 1 do
        Core.setLayerProperties(i, Map.map.layers[i].properties)
    end
    for i = 1, #Map.map.layers, 1 do
        for locX = Map.masterGroup[i].vars.camera[1], Map.masterGroup[i].vars.camera[3], 1 do
            for locY = Map.masterGroup[i].vars.camera[2], Map.masterGroup[i].vars.camera[4], 1 do
                --print(locX, locY)
                Core.updateTile({locX = locX, locY = locY, layer = i, tile = -1})
                cullLargeTile(locX, locY, i, true)
            end
        end
        Map.masterGroup[i].vars.camera = nil
    end
    Core.update()
    --PROCESS ANIMATION DATA
    for i = 1, #Map.map.tilesets, 1 do
        if Map.map.tilesets[i].tileproperties then
            for key,value in pairs(Map.map.tilesets[i].tileproperties) do
                for key2,value2 in pairs(Map.map.tilesets[i].tileproperties[key]) do
                    if key2 == "animFrames" then
                        local tempFrames
                        if type(value2) == "string" then
                            Map.map.tilesets[i].tileproperties[key]["animFrames"] = json.decode(value2)
                            tempFrames = json.decode(value2)
                        else
                            Map.map.tilesets[i].tileproperties[key]["animFrames"] = value2
                            tempFrames = value2
                        end
                        if Map.map.tilesets[i].tileproperties[key]["animFrameSelect"] == "relative" then
                            local frames = {}
                            for f = 1, #tempFrames, 1 do
                                frames[f] = (tonumber(key) + 1) + tempFrames[f]
                            end
                            Map.map.tilesets[i].tileproperties[key]["sequenceData"] = {
                                name="null",
                                frames=frames,
                                time = tonumber(Map.map.tilesets[i].tileproperties[key]["animDelay"]),
                                loopCount = 0
                            }
                        elseif Map.map.tilesets[i].tileproperties[key]["animFrameSelect"] == "absolute" then
                            Map.map.tilesets[i].tileproperties[key]["sequenceData"] = {
                                name="null",
                                frames=tempFrames,
                                time = tonumber(Map.map.tilesets[i].tileproperties[key]["animDelay"]),
                                loopCount = 0
                            }
                        end
                        Map.map.tilesets[i].tileproperties[key]["animSync"] = tonumber(Map.map.tilesets[i].tileproperties[key]["animSync"]) or 1
                        if not Core.syncData[Map.map.tilesets[i].tileproperties[key]["animSync"] ] then
                            Core.syncData[Map.map.tilesets[i].tileproperties[key]["animSync"] ] = {}
                            Core.syncData[Map.map.tilesets[i].tileproperties[key]["animSync"] ].time = (Map.map.tilesets[i].tileproperties[key]["sequenceData"].time / #Map.map.tilesets[i].tileproperties[key]["sequenceData"].frames) / Map.frameTime
                            Core.syncData[Map.map.tilesets[i].tileproperties[key]["animSync"] ].currentFrame = 1
                            Core.syncData[Map.map.tilesets[i].tileproperties[key]["animSync"] ].counter = Core.syncData[Map.map.tilesets[i].tileproperties[key]["animSync"] ].time
                            Core.syncData[Map.map.tilesets[i].tileproperties[key]["animSync"] ].frames = Map.map.tilesets[i].tileproperties[key]["sequenceData"].frames
                        end
                    end
                    if key2 == "shape" then
                        if type(value2) == "string" then
                            Map.map.tilesets[i].tileproperties[key]["shape"] = json.decode(value2)
                        else
                            Map.map.tilesets[i].tileproperties[key]["shape"] = value2
                        end
                    end
                    if key2 == "filter" then
                        if type(value2) == "string" then
                            Map.map.tilesets[i].tileproperties[key]["filter"] = json.decode(value2)
                        else
                            Map.map.tilesets[i].tileproperties[key]["filter"] = value2
                        end
                    end
                    if key2 == "opacity" then					
                        frameIndex = tonumber(key) + (Map.map.tilesets[i].firstgid - 1) + 1
                        
                        if not Map.map.lightingData[frameIndex] then
                            Map.map.lightingData[frameIndex] = {}
                        end
                        if type(value2) == "string" then
                            Map.map.lightingData[frameIndex].opacity = json.decode(value2)
                        else
                            Map.map.lightingData[frameIndex].opacity = value2
                        end
                    end
                end
            end
        end			
        if not Map.map.tilesets[i].properties then
            Map.map.tilesets[i].properties = {}
        end
    end
end

-----------------------------------------------------------

Core.setLayerProperties = function(layer, t)
    if not layer then
        print("ERROR(setLayerProperties): No layer specified.")
    end
    local lyr = layer
    if lyr > #Map.map.layers then
        print("Warning(setLayerProperties): The layer index is too high. Defaulting to top layer.")
        lyr = #Map.map.layers
    elseif lyr < 1 then
        print("Warning(setLayerProperties): The layer index is too low. Defaulting to layer 1.")
        lyr = 1
    end
    local i = lyr
    Map.map.layers[lyr].properties = t
    if not Map.map.layers[i].properties then
        Map.map.layers[i].properties = {}
        Map.map.layers[i].properties.level = "1"
        Map.map.layers[i].properties.scaleX = 1
        Map.map.layers[i].properties.scaleY = 1
        Map.map.layers[i].properties.parallaxX = 1
        Map.map.layers[i].properties.parallaxY = 1
    else
        if not Map.map.layers[i].properties.level then
            Map.map.layers[i].properties.level = "1"
        end
        if Map.map.layers[i].properties.scale then
            Map.map.layers[i].properties.scaleX = Map.map.layers[i].properties.scale
            Map.map.layers[i].properties.scaleY = Map.map.layers[i].properties.scale
        else
            if not Map.map.layers[i].properties.scaleX then
                Map.map.layers[i].properties.scaleX = 1
            end
            if not Map.map.layers[i].properties.scaleY then
                Map.map.layers[i].properties.scaleY = 1
            end
        end
    end
    Map.map.layers[i].properties.scaleX = tonumber(Map.map.layers[i].properties.scaleX)
    Map.map.layers[i].properties.scaleY = tonumber(Map.map.layers[i].properties.scaleY)
    if Map.map.layers[lyr].properties.parallax then
        Map.map.layers[lyr].parallaxX = Map.map.layers[lyr].properties.parallax / Map.map.layers[lyr].properties.scaleX
        Map.map.layers[lyr].parallaxY = Map.map.layers[lyr].properties.parallax / Map.map.layers[lyr].properties.scaleY
    else
        if Map.map.layers[lyr].properties.parallaxX then
            Map.map.layers[lyr].parallaxX = Map.map.layers[lyr].properties.parallaxX / Map.map.layers[lyr].properties.scaleX
        else
            Map.map.layers[lyr].parallaxX = 1
        end
        if Map.map.layers[lyr].properties.parallaxY then
            Map.map.layers[lyr].parallaxY = Map.map.layers[lyr].properties.parallaxY / Map.map.layers[lyr].properties.scaleY
        else
            Map.map.layers[lyr].parallaxY = 1
        end
    end
    --CHECK REFERENCE LAYER
    if Map.refLayer == lyr then
        if Map.map.layers[lyr].parallaxX ~= 1 or Map.map.layers[lyr].parallaxY ~= 1 then
            for i = 1, #Map.map.layers, 1 do
                if Map.map.layers[i].parallaxX == 1 and Map.map.layers[i].parallaxY == 1 then
                    Map.refLayer = i
                    break
                end
            end
            if not Map.refLayer then
                Map.refLayer = 1
            end
        end
    end
    
    --DETECT LAYER WRAP
    Camera.layerWrapX[lyr] = Camera.worldWrapX
    Camera.layerWrapY[lyr] = Camera.worldWrapY
    if Map.map.layers[lyr].properties.wrap then
        if Map.map.layers[lyr].properties.wrap == "true" then
            Camera.layerWrapX[lyr] = true
            Camera.layerWrapY[lyr] = true
        elseif Map.map.layers[lyr].properties.wrap == "false" then
            Camera.layerWrapX[lyr] = false
            Camera.layerWrapY[lyr] = false
        end
    end
    if Map.map.layers[lyr].properties.wrapX then
        if Map.map.layers[lyr].properties.wrapX == "true" then
            Camera.layerWrapX[lyr] = true
        elseif Map.map.layers[lyr].properties.wrapX == "false" then
            Camera.layerWrapX[lyr] = false
        end
    end
    if Map.map.layers[lyr].properties.wrapY then
        if Map.map.layers[lyr].properties.wrapY == "true" then
            Camera.layerWrapY[lyr] = true
        elseif Map.map.layers[lyr].properties.wrapY == "false" then
            Camera.layerWrapX[lyr] = false
        end
    end
    
    --LOAD PHYSICS
    if PhysicsData.enablePhysicsByLayer == 1 then
        if Map.map.layers[i].properties.physics == "true" then
            PhysicsData.enablePhysics[i] = true
            PhysicsData.layer[i] = {}
            PhysicsData.layer[i].defaultDensity = PhysicsData.defaultDensity
            PhysicsData.layer[i].defaultFriction = PhysicsData.defaultFriction
            PhysicsData.layer[i].defaultBounce = PhysicsData.defaultBounce
            PhysicsData.layer[i].defaultBodyType = PhysicsData.defaultBodyType
            PhysicsData.layer[i].defaultShape = PhysicsData.defaultShape
            PhysicsData.layer[i].defaultRadius = PhysicsData.defaultRadius
            PhysicsData.layer[i].defaultFilter = PhysicsData.defaultFilter
            PhysicsData.layer[i].isActive = true
            PhysicsData.layer[i].isAwake = true
            
            if Map.map.layers[i].properties.density then
                PhysicsData.layer[i].defaultDensity = Map.map.layers[i].properties.density
            end
            if Map.map.layers[i].properties.friction then
                PhysicsData.layer[i].defaultFriction = Map.map.layers[i].properties.friction
            end
            if Map.map.layers[i].properties.bounce then
                PhysicsData.layer[i].defaultBounce = Map.map.layers[i].properties.bounce
            end
            if Map.map.layers[i].properties.bodyType then
                PhysicsData.layer[i].defaultBodyType = Map.map.layers[i].properties.bodyType
            end
            if Map.map.layers[i].properties.shape then
                if type(Map.map.layers[i].properties.shape) == "string" then
                    PhysicsData.layer[i].defaultShape = json.decode(Map.map.layers[i].properties.shape)
                else
                    PhysicsData.layer[i].defaultShape = Map.map.layers[i].properties.shape
                end
            end
            if Map.map.layers[i].properties.radius then
                PhysicsData.layer[i].defaultRadius = Map.map.layers[i].properties.radius
            end
            if Map.map.layers[i].properties.groupIndex or Map.map.layers[i].properties.categoryBits or Map.map.layers[i].properties.maskBits then
                PhysicsData.layer[i].defaultFilter = {categoryBits = tonumber(Map.map.layers[i].properties.categoryBits),
                    maskBits = tonumber(Map.map.layers[i].properties.maskBits),
                    groupIndex = tonumber(Map.map.layers[i].properties.groupIndex)
                }
            end
        end
    elseif PhysicsData.enablePhysicsByLayer == 2 then
        PhysicsData.enablePhysics[i] = true
        PhysicsData.layer[i] = {}
        PhysicsData.layer[i].defaultDensity = PhysicsData.defaultDensity
        PhysicsData.layer[i].defaultFriction = PhysicsData.defaultFriction
        PhysicsData.layer[i].defaultBounce = PhysicsData.defaultBounce
        PhysicsData.layer[i].defaultBodyType = PhysicsData.defaultBodyType
        PhysicsData.layer[i].defaultShape = PhysicsData.defaultShape
        PhysicsData.layer[i].defaultRadius = PhysicsData.defaultRadius
        PhysicsData.layer[i].defaultFilter = PhysicsData.defaultFilter
        PhysicsData.layer[i].isActive = true
        PhysicsData.layer[i].isAwake = true
        
        if Map.map.layers[i].properties.density then
            PhysicsData.layer[i].defaultDensity = Map.map.layers[i].properties.density
        end
        if Map.map.layers[i].properties.friction then
            PhysicsData.layer[i].defaultFriction = Map.map.layers[i].properties.friction
        end
        if Map.map.layers[i].properties.bounce then
            PhysicsData.layer[i].defaultBounce = Map.map.layers[i].properties.bounce
        end
        if Map.map.layers[i].properties.bodyType then
            PhysicsData.layer[i].defaultBodyType = Map.map.layers[i].properties.bodyType
        end
        if Map.map.layers[i].properties.shape then
            if type(Map.map.layers[i].properties.shape) == "string" then
                PhysicsData.layer[i].defaultShape = json.decode(Map.map.layers[i].properties.shape)
            else
                PhysicsData.layer[i].defaultShape = Map.map.layers[i].properties.shape
            end
        end
        if Map.map.layers[i].properties.radius then
            PhysicsData.layer[i].defaultRadius = Map.map.layers[i].properties.radius
        end
        if Map.map.layers[i].properties.groupIndex or Map.map.layers[i].properties.categoryBits or Map.map.layers[i].properties.maskBits then
            PhysicsData.layer[i].defaultFilter = {categoryBits = tonumber(Map.map.layers[i].properties.categoryBits),
                maskBits = tonumber(Map.map.layers[i].properties.maskBits),
                groupIndex = tonumber(Map.map.layers[i].properties.groupIndex)
            }
        end			
    end
    
    --LIGHTING
    if Map.map.properties then
        if Map.map.properties.lightingStyle then
            local levelLighting = {}
            for i = 1, Map.map.numLevels, 1 do
                levelLighting[i] = {}
            end
            if not Map.map.properties.lightRedStart then
                Map.map.properties.lightRedStart = "1"
            end
            if not Map.map.properties.lightGreenStart then
                Map.map.properties.lightGreenStart = "1"
            end
            if not Map.map.properties.lightBlueStart then
                Map.map.properties.lightBlueStart = "1"
            end
            if Map.map.properties.lightingStyle == "diminish" then
                local rate = tonumber(Map.map.properties.lightRate)
                levelLighting[Map.map.numLevels].red = tonumber(Map.map.properties.lightRedStart)
                levelLighting[Map.map.numLevels].green = tonumber(Map.map.properties.lightGreenStart)
                levelLighting[Map.map.numLevels].blue = tonumber(Map.map.properties.lightBlueStart)
                for i = Map.map.numLevels - 1, 1, -1 do
                    levelLighting[i].red = levelLighting[Map.map.numLevels].red - (rate * (Map.map.numLevels - i))
                    if levelLighting[i].red < 0 then
                        levelLighting[i].red = 0
                    end
                    levelLighting[i].green = levelLighting[Map.map.numLevels].green - (rate * (Map.map.numLevels - i))
                    if levelLighting[i].green < 0 then
                        levelLighting[i].green = 0
                    end
                    levelLighting[i].blue = levelLighting[Map.map.numLevels].blue - (rate * (Map.map.numLevels - i))
                    if levelLighting[i].blue < 0 then
                        levelLighting[i].blue = 0
                    end
                end
            end
            for i = 1, #Map.map.layers, 1 do
                if Map.map.layers[i].properties.lightRed then
                    Map.map.layers[i].redLight = tonumber(Map.map.layers[i].properties.lightRed)
                else
                    Map.map.layers[i].redLight = levelLighting[Map.map.layers[i].properties.level].red
                end
                if Map.map.layers[i].properties.lightGreen then
                    Map.map.layers[i].greenLight = tonumber(Map.map.layers[i].properties.lightGreen)
                else
                    Map.map.layers[i].greenLight = levelLighting[Map.map.layers[i].properties.level].green
                end
                if Map.map.layers[i].properties.lightBlue then
                    Map.map.layers[i].blueLight = tonumber(Map.map.layers[i].properties.lightBlue)
                else
                    Map.map.layers[i].blueLight = levelLighting[Map.map.layers[i].properties.level].blue
                end
            end
        else
            for i = 1, #Map.map.layers, 1 do
                Map.map.layers[i].redLight = 1
                Map.map.layers[i].greenLight = 1
                Map.map.layers[i].blueLight = 1
            end
        end
    end
end

return Core