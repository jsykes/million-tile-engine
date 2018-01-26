--mte 0v990-1

local M = {}

-----------------------------------------------------------

local json = require("json")
M.physics = require("physics")

-----------------------------------------------------------

local Core = require("src.Core")
local Camera = require("src.Camera")
local DebugStats = require("src.DebugStats")
local Light = require("src.Light")
local Map = require("src.Map")
local PerlinNoise = require("src.PerlinNoise")
local PhysicsData = require("src.PhysicsData")
local SaveMap = require("src.SaveMap")
local Sprites = require("src.Sprites")
local Screen = require("src.Screen")
local Xml = require("src.Xml")


-----------------------------------------------------------

local source    

-----------------------------------------------------------

local function calculateDelta( previousTouches, event )
    
    local id, touch = next( previousTouches )        
    if ( event.id == id ) then
        id, touch = next( previousTouches, id )
        assert( id ~= event.id )
    end        
    
    local dx = touch.x - event.x
    local dy = touch.y - event.y
    
    return dx, dy
end

-----------------------------------------------------------

local touchScrollPinchZoom = function(event)
    
    local result = true		
    local phase = event.phase
    local previousTouches = Map.masterGroup.previousTouches
    local numTotalTouches = 1
    
    if ( previousTouches ) then
        -- add in total from previousTouches, subtract one if event is already in the array
        numTotalTouches = numTotalTouches + Map.masterGroup.numPreviousTouches
        if ( previousTouches[ event.id ] ) then
            numTotalTouches = numTotalTouches - 1
        end
    end
    
    if ( "began" == phase ) then
        
        if ( numTotalTouches == 1 ) then
            Camera.touchScroll[2] = event.x
            Camera.touchScroll[3] = event.y
            Camera.touchScroll[4] = event.x
            Camera.touchScroll[5] = event.y
            Camera.touchScroll[6] = true
        end
        
        -- Very first "began" event
        if ( not Map.masterGroup.isFocus ) then
            
            -- Subsequent touch events will target button even if they are outside the stageBounds of button
            display.getCurrentStage():setFocus( Map.masterGroup )
            Map.masterGroup.isFocus = true
            
            previousTouches = {}
            Map.masterGroup.previousTouches = previousTouches
            Map.masterGroup.numPreviousTouches = 0
            
        elseif ( not Map.masterGroup.distance ) then
            
            local dx,dy
            
            if ( previousTouches and ( numTotalTouches ) >= 2 ) then
                dx,dy = calculateDelta( previousTouches, event )
            end
            
            -- initialize to distance between two touches
            if ( Camera.pinchZoom ) then
                if ( dx and dy ) then
                    local d = math.sqrt( dx * dx + dy * dy )
                    if ( d > 0 ) then
                        Map.masterGroup.distance = d
                        Map.masterGroup.xScaleOriginal = Map.masterGroup.xScale
                        Map.masterGroup.yScaleOriginal = Map.masterGroup.yScale
                        --print( "distance = " .. Map.masterGroup.distance )
                    end
                end
            end
        end
        
        if ( not previousTouches[ event.id ] ) then
            Map.masterGroup.numPreviousTouches = Map.masterGroup.numPreviousTouches + 1
        end
        previousTouches[ event.id ] = event
        
        --Runtime:dispatchEvent({name = "mteTouchBegan", data = {levelPosX = event.x, levelPosY = event.y, id = event.id} })
    elseif ( Map.masterGroup.isFocus ) then
        
        if ( "moved" == phase ) then
            
            if ( numTotalTouches == 1 ) then
                Camera.touchScroll[4] = event.x
                Camera.touchScroll[5] = event.y
            end
            
            if ( Map.masterGroup.distance ) then
                local dx,dy
                
                if ( previousTouches and ( numTotalTouches ) >= 2 ) then
                    dx, dy = calculateDelta( previousTouches, event )
                end			
                
                if ( dx and dy ) then
                    if ( Camera.pinchZoom ) then
                        
                        local newDistance = math.sqrt( dx*dx + dy*dy )
                        local scale = newDistance / Map.masterGroup.distance
                        --print( "newDistance(" ..newDistance .. ") / distance(" .. Map.masterGroup.distance .. ") = scale("..  scale ..")" )
                        if ( scale > 0 ) then
                            
                            local newScaleX = Map.masterGroup.xScaleOriginal * scale
                            local newScaleY = Map.masterGroup.yScaleOriginal * scale
                            
                            if ( newScaleX < Camera.minZoom ) then
                                newScaleX = Camera.minZoom
                            elseif ( newScaleX > Camera.maxZoom ) then
                                newScaleX = Camera.maxZoom
                            end
                            
                            if ( newScaleY < Camera.minZoom ) then
                                newScaleY = Camera.minZoom
                            elseif ( newScaleY > Camera.maxZoom ) then
                                newScaleY = Camera.maxZoom
                            end
                            
                            Map.masterGroup.xScale = newScaleX
                            Map.masterGroup.yScale = newScaleY
                        end
                    end
                end
            end
            
            if ( not previousTouches[ event.id ] ) then
                Map.masterGroup.numPreviousTouches = Map.masterGroup.numPreviousTouches + 1
            end
            previousTouches[ event.id ] = event
            
            --Runtime:dispatchEvent({name = "mteTouchMoved", data = {levelPosX = event.x, levelPosY = event.y, id = event.id} })
        elseif ( "ended" == phase or "cancelled" == phase ) then
            
            if ( numTotalTouches == 1 ) then
                for i=2, 5 do
                    Camera.touchScroll[i] = nil
                end
                --                    Camera.touchScroll[2], Camera.touchScroll[3], Camera.touchScroll[4], Camera.touchScroll[5] = nil, nil, nil, nil
                Camera.touchScroll[6] = false
            end
            
            if ( previousTouches[ event.id ] ) then
                Map.masterGroup.numPreviousTouches = Map.masterGroup.numPreviousTouches - 1
                previousTouches[ event.id ] = nil
            end
            
            if ( #previousTouches > 0 ) then
                -- must be at least 2 touches remaining to pinch/zoom
                Map.masterGroup.distance = nil
            else
                -- previousTouches is empty so no more fingers are touching the screen
                -- Allow touch events to be sent normally to the objects they "hit"
                display.getCurrentStage():setFocus( nil )
                
                Map.masterGroup.isFocus = false
                Map.masterGroup.distance = nil
                Map.masterGroup.xScaleOriginal = nil
                Map.masterGroup.yScaleOriginal = nil
                
                -- reset array
                Map.masterGroup.previousTouches = nil
                Map.masterGroup.numPreviousTouches = nil
            end
            --Runtime:dispatchEvent({name = "mteTouchEnded", data = {levelPosX = event.x, levelPosY = event.y, id = event.id} })
        end
    end
    
    local t = {}
    for key,value in pairs(event) do
        t[key] = value
    end
    t.name = "mteTouchScrollPinchZoom"
    t.levelPosX = M.screenToLevelPosX(event.x, Map.refLayer)
    t.levelPosY = M.screenToLevelPosY(event.y, Map.refLayer)
    t.locX = M.screenToLocX(event.x, Map.refLayer)
    t.locY = M.screenToLocY(event.y, Map.refLayer)
    t.numTotalTouches = numTotalTouches
    t.previousTouches = previousTouches
    Runtime:dispatchEvent(t)
end

-----------------------------------------------------------

-------------------------
-- Core
-------------------------

M.update = Core.update
M.updateTile = Core.updateTile
M.addPropertyListener = Core.addPropertyListener
M.addObjectDrawListener = Core.addObjectDrawListener
M.drawObjects = Core.drawObjects
M.refresh = Core.refresh
M.setLayerProperties = Core.setLayerProperties

-------------------------
-- Camera
-------------------------

M.cameraX = Camera.McameraX
M.cameraY = Camera.McameraY

M.setLightingEnabled = Camera.setLightingEnabled;
M.disablePinchZoom = Camera.disablePinchZoom
M.disableTouchScroll = Camera.disableTouchScroll
M.enablePinchZoom = Camera.enablePinchZoom
M.enableTouchScroll = Camera.enableTouchScroll
M.setCameraFocus = Camera.setCameraFocus
M.toggleWorldWrapX = Camera.toggleWorldWrapX
M.toggleWorldWrapY = Camera.toggleWorldWrapY
M.getCamera = Camera.getCamera
M.moveCameraTo = Camera.moveCameraTo
M.removeCameraConstraints = Camera.removeCameraConstraints
M.zoom = Camera.zoom

-------------------------
-- Light
-------------------------

M.setPointLightSource = Light.setPointLightSource

-------------------------
-- Map
-------------------------

M.disableHeightMaps = Map.disableHeightMaps
M.enableHeightMaps = Map.enableHeightMaps
M.enableTileFlipAndRotation = Map.enableTileFlipAndRotation
M.getLayerObj = Map.getLayerObj
M.getLayerProperties = Map.getLayerProperties
M.getLayers = Map.getLayers
M.getLevel = Map.getLevel
M.getLoadedMaps = Map.getLoadedMaps
M.getMap = Map.getMap
M.getMapObj = Map.getMapObj
M.getMapProperties = Map.getMapProperties
M.getObjectLayer = Map.getObjectLayer
M.getSpriteLayer = Map.getSpriteLayer
M.getTileAt = Map.getTileAt
M.getTileObj = Map.getTileObj
M.levelToLoc = Map.levelToLoc
M.levelToLocX = Map.levelToLocX
M.levelToLocY = Map.levelToLocY
M.setParentGroup = Map.setParentGroup
M.setTileProperties = Map.setTileProperties
M.unloadMap = Map.unloadMap

-------------------------
-- Sprite
-------------------------
M.removeSprite = Sprites.removeSprite
M.moveSpriteTo = Sprites.moveSpriteTo
M.sendSpriteTo = Sprites.sendSpriteTo

-------------------------
-- Other
-------------------------

M.debug = DebugStats.debug
M.perlinNoise = PerlinNoise.perlinNoise
M.saveMap = SaveMap.saveMap
M.enableSpriteSorting = Sprites.enableSpriteSorting

-------------------------
-- PhysicsData
-------------------------

M.enableBox2DPhysics = PhysicsData.enableBox2DPhysics

-------------------------
-- Screen
-------------------------

M.setScreenBounds = Screen.setScreenBounds


-------------------------
-- Screen
-------------------------
M.addSprite = Sprites.addSprite


-----------------------------------------------------------
-----------------------------------------------------------

M.getTilesWithProperty = function(key, value, level, layer)	
    local t = {}
    
    if ( layer ) then
        
        local camera = Map.masterGroup[layer].vars.camera
        if ( camera ~= nil ) then                
            for x = camera[1], camera[3], 1 do
                for y = camera[2], camera[4], 1 do
                    
                    local locX, locY = x, y
                    if ( Camera.layerWrapX[layer] ) then
                        if ( locX < 1 - Map.map.locOffsetX ) then
                            locX = locX + Map.map.layers[layer].width
                        end
                        if ( locX > Map.map.layers[layer].width - Map.map.locOffsetX ) then
                            locX = locX - Map.map.layers[layer].width
                        end				
                    end
                    
                    if ( Camera.layerWrapY[layer] ) then
                        if ( locY < 1 - Map.map.locOffsetY ) then
                            locY = locY + Map.map.layers[layer].height
                        end
                        if ( locY > Map.map.layers[layer].height - Map.map.locOffsetY ) then
                            locY = locY - Map.map.layers[layer].height
                        end
                    end	
                    
                    local layerLocX = Map.tileObjects[layer][locX]
                    if ( layerLocX and layerLocX[locY] and 
                        layerLocX[locY].properties and layerLocX[locY].properties[key] ) then
                        if ( value ) then
                            if ( layerLocX[locY].properties[key] == value ) then
                                t[#t + 1] = layerLocX[locY]
                            end
                        else
                            t[#t + 1] = layerLocX[locY]
                        end
                    end
                end
            end
        end
    elseif ( level ) then
        for i = 1, #Map.map.layers, 1 do
            if Map.map.layers[i].properties.level == level then
                local layer = i
                if Map.masterGroup[layer].vars.camera then
                    for x = Map.masterGroup[layer].vars.camera[1], Map.masterGroup[layer].vars.camera[3], 1 do
                        for y = Map.masterGroup[layer].vars.camera[2], Map.masterGroup[layer].vars.camera[4], 1 do
                            local locX, locY = x, y
                            if Camera.layerWrapX[layer] then
                                if locX < 1 - Map.map.locOffsetX then
                                    locX = locX + Map.map.layers[layer].width
                                end
                                if locX > Map.map.layers[layer].width - Map.map.locOffsetX then
                                    locX = locX - Map.map.layers[layer].width
                                end				
                            end
                            if Camera.layerWrapY[layer] then
                                if locY < 1 - Map.map.locOffsetY then
                                    locY = locY + Map.map.layers[layer].height
                                end
                                if locY > Map.map.layers[layer].height - Map.map.locOffsetY then
                                    locY = locY - Map.map.layers[layer].height
                                end
                            end					
                            if Map.tileObjects[layer][locX] and Map.tileObjects[layer][locX][locY] and 
                                Map.tileObjects[layer][locX][locY].properties and Map.tileObjects[layer][locX][locY].properties[key] then
                                if value then
                                    if Map.tileObjects[layer][locX][locY].properties[key] == value then
                                        t[#t + 1] = Map.tileObjects[layer][locX][locY]
                                    end
                                else
                                    t[#t + 1] = Map.tileObjects[layer][locX][locY]
                                end
                            end
                        end
                    end
                end
            end
        end
    else
        for i = 1, #Map.map.layers, 1 do
            local layer = i
            if Map.masterGroup[layer].vars.camera then
                for x = Map.masterGroup[layer].vars.camera[1], Map.masterGroup[layer].vars.camera[3], 1 do
                    for y = Map.masterGroup[layer].vars.camera[2], Map.masterGroup[layer].vars.camera[4], 1 do
                        local locX, locY = x, y
                        if Camera.layerWrapX[layer] then
                            if locX < 1 - Map.map.locOffsetX then
                                locX = locX + Map.map.layers[layer].width
                            end
                            if locX > Map.map.layers[layer].width - Map.map.locOffsetX then
                                locX = locX - Map.map.layers[layer].width
                            end				
                        end
                        if Camera.layerWrapY[layer] then
                            if locY < 1 - Map.map.locOffsetY then
                                locY = locY + Map.map.layers[layer].height
                            end
                            if locY > Map.map.layers[layer].height - Map.map.locOffsetY then
                                locY = locY - Map.map.layers[layer].height
                            end
                        end				
                        if Map.tileObjects[layer][locX] and Map.tileObjects[layer][locX][locY] and 
                            Map.tileObjects[layer][locX][locY].properties and Map.tileObjects[layer][locX][locY].properties[key] then
                            if value then
                                if Map.tileObjects[layer][locX][locY].properties[key] == value then
                                    t[#t + 1] = Map.tileObjects[layer][locX][locY]
                                end
                            else
                                t[#t + 1] = Map.tileObjects[layer][locX][locY]
                            end
                        end
                    end
                end
            end
        end
    end
    
    if ( not layer and not level and not value and not key ) then
        for i = 1, #Map.map.layers, 1 do
            local layer = i
            if Map.masterGroup[layer].vars.camera then
                for x = Map.masterGroup[layer].vars.camera[1], Map.masterGroup[layer].vars.camera[3], 1 do
                    for y = Map.masterGroup[layer].vars.camera[2], Map.masterGroup[layer].vars.camera[4], 1 do
                        local locX, locY = x, y
                        if Camera.layerWrapX[layer] then
                            if locX < 1 - Map.map.locOffsetX then
                                locX = locX + Map.map.layers[layer].width
                            end
                            if locX > Map.map.layers[layer].width - Map.map.locOffsetX then
                                locX = locX - Map.map.layers[layer].width
                            end				
                        end
                        if Camera.layerWrapY[layer] then
                            if locY < 1 - Map.map.locOffsetY then
                                locY = locY + Map.map.layers[layer].height
                            end
                            if locY > Map.map.layers[layer].height - Map.map.locOffsetY then
                                locY = locY - Map.map.layers[layer].height
                            end
                        end	
                        if Map.tileObjects[layer][locX] and Map.tileObjects[layer][locX][locY] and 
                            Map.tileObjects[layer][locX][locY].properties then
                            t[#t + 1] = Map.tileObjects[layer][locX][locY]
                        end
                    end
                end
            end
        end
    end
    
    if #t > 0 then
        return t
    end
end

-----------------------------------------------------------

M.getSprites = function(params)
    local params = params
    if not params then
        params = {}
    end
    local t = {}
    
    local processSprite = function(sprite, layer)
        local check = true
        if params.name then	
            if sprite.name ~= params.name then
                check = false
            end
        end
        if params.locX then
            if sprite.locX ~= params.locX then
                check = false
            end
        end
        if params.locY then
            if sprite.locY ~= params.locY then
                check = false
            end
        end
        if params.levelPosX then
            if sprite.levelPosX ~= params.levelPosX then
                check = false
            end
        end
        if params.levelPosY then
            if sprite.levelPosY ~= params.levelPosY then
                check = false
            end
        end
        if params.layer then
            if sprite.layer ~= params.layer then
                check = false
            end
        end
        if params.level then
            if Map.map.layers[sprite.layer].properties and Map.map.layers[sprite.layer].properties.level and Map.map.layers[sprite.layer].properties.level ~= params.level then
                check = false
            end
        end
        if check then
            t[#t + 1] = sprite
        end
    end
    
    for i = 1, #Map.map.layers, 1 do	
        if Map.map.orientation == Map.Type.Isometric then
            for j = Map.masterGroup[i].numChildren, 1, -1 do
                for k = Map.masterGroup[i][j].numChildren, 1, -1 do
                    if not Map.masterGroup[i][j][k].tiles then
                        local sprite = Map.masterGroup[i][j][k]
                        if sprite then
                            processSprite(sprite, i)
                        end
                    end
                end
            end
        else
            for j = Map.masterGroup[i].numChildren, 1, -1 do
                if not Map.masterGroup[i][j].tiles then
                    if Map.masterGroup[i][j].isDepthBuffer then
                        for k = 1, Map.masterGroup[i][j].numChildren, 1 do
                            local sprite = Map.masterGroup[i][j][k]
                            if sprite then
                                processSprite(sprite, i)
                            end
                        end
                    else
                        local sprite = Map.masterGroup[i][j]
                        if sprite then
                            if not sprite.depthBuffer then
                                processSprite(sprite, i)
                            end
                        end
                    end
                end
            end
        end
    end
    
    if #t > 0 then
        return t
    end
end

-----------------------------------------------------------

M.toggleLayerPhysicsActive = function(layer, command)
    if Map.map.orientation == Map.Type.Isometric then
        if Map.isoSort == 1 then
            PhysicsData.layer[layer].isActive = command
            for i = 1, Map.masterGroup[layer].numChildren, 1 do
                for j = 1, Map.masterGroup[layer][i].numChildren, 1 do
                    if Map.masterGroup[layer][i][j].tiles then
                        for k = 1, Map.masterGroup[layer][i][j].numChildren, 1 do
                            if Map.masterGroup[layer][i][j][k].bodyType then
                                if not Map.masterGroup[layer][i][j][k].properties or not Map.masterGroup[layer][i][j][k].properties.isBodyActive then
                                    Map.masterGroup[layer][i][j][k].isBodyActive = command
                                end
                            end
                        end
                    else
                        if Map.masterGroup[layer][i][j].bodyType then
                            if not Map.masterGroup[layer][i][j].properties or not Map.masterGroup[layer][i][j].properties.isBodyActive then
                                Map.masterGroup[layer][i][j].isBodyActive = command
                            end
                        end
                    end
                end
            end
        end
    else
        PhysicsData.layer[layer].isActive = command
        for i = 1, Map.masterGroup[layer].numChildren, 1 do
            if Map.masterGroup[layer][i].tiles then
                for j = 1, Map.masterGroup[layer][i].numChildren, 1 do
                    if Map.masterGroup[layer][i][j].bodyType then
                        if not Map.masterGroup[layer][i][j].properties or not Map.masterGroup[layer][i][j].properties.isBodyActive then
                            Map.masterGroup[layer][i][j].isBodyActive = command
                        end
                    end
                end
            elseif Map.masterGroup[layer][i].depthBuffer then
                for j = 1, Map.masterGroup[layer][i].numChildren, 1 do
                    for k = 1, Map.masterGroup[layer][i][j].numChildren, 1 do
                        if Map.masterGroup[layer][i][j][k].bodyType then
                            if not Map.masterGroup[layer][i][j][k].properties or not Map.masterGroup[layer][i][j][k].properties.isBodyActive then
                                Map.masterGroup[layer][i][j][k].isBodyActive = command
                            end
                        end
                    end
                end
            else
                if Map.masterGroup[layer][i].bodyType then
                    if not Map.masterGroup[layer][i].properties or not Map.masterGroup[layer][i].properties.isBodyActive then
                        Map.masterGroup[layer][i].isBodyActive = command
                    end
                end
            end
        end
    end
end

-----------------------------------------------------------

M.toggleLayerPhysicsAwake = function(layer, command)
    if Map.map.orientation == Map.Type.Isometric then
        PhysicsData.layer[layer].isAwake = command
        for i = 1, Map.masterGroup[layer].numChildren, 1 do
            for j = 1, Map.masterGroup[layer][i].numChildren, 1 do
                if Map.masterGroup[layer][i][j].tiles then
                    for k = 1, Map.masterGroup[layer][i][j].numChildren, 1 do
                        if Map.masterGroup[layer][i][j][k].bodyType then
                            if not Map.masterGroup[layer][i][j][k].properties or not Map.masterGroup[layer][i][j][k].properties.isAwake then
                                Map.masterGroup[layer][i][j][k].isAwake = command
                            end
                        end
                    end
                else
                    if Map.masterGroup[layer][i][j].bodyType then
                        if not Map.masterGroup[layer][i][j].properties or not Map.masterGroup[layer][i][j].properties.isAwake then
                            Map.masterGroup[layer][i][j].isAwake = command
                        end
                    end
                end
            end
        end
    else
        PhysicsData.layer[layer].isAwake = command
        for i = 1, Map.masterGroup[layer].numChildren, 1 do
            if Map.masterGroup[layer][i].tiles then
                for j = 1, Map.masterGroup[layer][i].numChildren, 1 do
                    if Map.masterGroup[layer][i][j].bodyType then
                        if not Map.masterGroup[layer][i][j].properties or not Map.masterGroup[layer][i][j].properties.isAwake then
                            Map.masterGroup[layer][i][j].isAwake = command
                        end
                    end
                end
            elseif Map.masterGroup[layer][i].depthBuffer then
                for j = 1, Map.masterGroup[layer][i].numChildren, 1 do
                    for k = 1, Map.masterGroup[layer][i][j].numChildren, 1 do
                        if Map.masterGroup[layer][i][j][k].bodyType then
                            if not Map.masterGroup[layer][i][j][k].properties or not Map.masterGroup[layer][i][j][k].properties.isAwake then
                                Map.masterGroup[layer][i][j][k].isAwake = command
                            end
                        end
                    end
                end
            else
                if Map.masterGroup[layer][i].bodyType then
                    if not Map.masterGroup[layer][i].properties or not Map.masterGroup[layer][i].properties.isAwake then
                        Map.masterGroup[layer][i].isAwake = command
                    end
                end
            end
        end
    end
end

-----------------------------------------------------------

M.getCullingBounds = function(layer, arg)
    local left = Map.masterGroup[layer].vars.camera[1]
    local top = Map.masterGroup[layer].vars.camera[2]
    local right = Map.masterGroup[layer].vars.camera[3]
    local bottom = Map.masterGroup[layer].vars.camera[4]
    if left < 1 - Map.map.locOffsetX then
        left = left + Map.map.layers[layer].width
    end
    if right > Map.map.layers[layer].width - Map.map.locOffsetX then
        right = right - Map.map.layers[layer].width
    end					
    if top < 1 - Map.map.locOffsetY then
        top = top + Map.map.layers[layer].height
    end
    if bottom > Map.map.layers[layer].height - Map.map.locOffsetY then
        bottom = bottom - Map.map.layers[layer].height
    end
    
    local value
    if not arg then
        value = {}
        value.top = top
        value.left = left
        value.bottom = bottom
        value.right = right
    elseif arg == "top" then
        value = top
    elseif arg == "bottom" then
        value = bottom
    elseif arg == "left" then
        value = left
    elseif arg == "right" then
        value = right
    end
    return value
end

-----------------------------------------------------------

M.convert = function(operation, arg1, arg2, layer)
    if not layer then
        layer = Map.refLayer
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
    
    local scaleX = Map.map.layers[layer].properties.scaleX
    local scaleY = Map.map.layers[layer].properties.scaleY
    local tempScaleX = Map.map.tilewidth * Map.map.layers[layer].properties.scaleX
    local tempScaleY = Map.map.tileheight * Map.map.layers[layer].properties.scaleY
    
    local value = {}
    
    if operation == "screenPosToLevelPos" then
        value.x, value.y = M.screenToLevelPos(arg1, arg2, layer)
    elseif operation == "screenPosToLoc" then
        value.x, value.y = M.screenToLoc(arg1, arg2, layer)
    end
    
    if operation == "levelPosToScreenPos" then
        value.x, value.y = M.levelToScreenPos(arg1, arg2, layer)
    elseif operation == "levelPosToLoc" then
        value.x, value.y = M.levelToLoc(arg1, arg2)
    end
    
    if operation == "locToScreenPos" then
        value.x, value.y = Map.locToScreenPos(arg1, arg2, layer)
    elseif operation == "locToLevelPos" then
        value.x, value.y = Map.locToLevelPos(arg1, arg2)
    end
    
    if not switch then
        return value
    elseif switch == 1 then
        return value.x
    elseif switch == 2 then
        return value.y
    end
end

-----------------------------------------------------------

M.addObject = function(layer, t)
    local layer = layer
    if Map.map.layers[layer].properties.objectLayer then
        Map.map.layers[layer].objects[#Map.map.layers[layer].objects + 1] = t
    else
        print("ERROR: Not an Object Layer.")
    end
end

-----------------------------------------------------------

M.removeObject = function(name, lyr)
    if not lyr then
        local debug = 0
        for j = 1, #Map.map.layers, 1 do
            local layer = j
            if Map.map.layers[layer].properties.objectLayer then
                for i = 1, #Map.map.layers[layer].objects, 1 do
                    local object = Map.map.layers[layer].objects[i]
                    if name == object.name then
                        table.remove(Map.map.layers[layer].objects, i)
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
        if Map.map.layers[layer].properties.objectLayer then
            for i = 1, #Map.map.layers[layer].objects, 1 do
                local object = Map.map.layers[layer].objects[i]
                if name == object.name then
                    table.remove(Map.map.layers[layer].objects, i)
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

-----------------------------------------------------------

M.getTileProperties = function(options)
    if options.levelPosX then
        options.locX, options.locY = M.levelToLoc(options.levelPosX, options.levelPosY)
    end
    if options.tile then
        local tile = options.tile
        local properties = nil
        if tile ~= 0 then
            local tileset = 1
            for i = #Map.map.tilesets, 1, -1 do
                if tile >= Map.map.tilesets[i].firstgid then
                    tileset = i
                    break
                end
            end
            local tileStr = 0
            if tileset == 1 then
                tileStr = tostring(tile - 1)
            else
                tileStr = tostring(tile - Map.map.tilesets[tileset].firstgid)
            end
            if Map.map.tilesets[tileset].tileproperties then
                if Map.map.tilesets[tileset].tileproperties[tileStr] then
                    properties = {}
                    properties = Map.map.tilesets[tileset].tileproperties[tileStr]
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
            if locX > Map.map.layers[layer].width - Map.map.locOffsetX then
                locX = locX - Map.map.layers[layer].width
            elseif locX < 1 - Map.map.locOffsetX then
                locX = locX + Map.map.layers[layer].width
            end
            if locY > Map.map.layers[layer].height - Map.map.locOffsetY then
                locY = locY - Map.map.layers[layer].height
            elseif locY < 1 - Map.map.locOffsetY then
                locY = locY + Map.map.layers[layer].height
            end
            local tile = Map.map.layers[layer].world[locX][locY]
            ------------------------------------------------------------------------------
            local properties = nil
            if tile ~= 0 then
                local tileset = 1
                for i = #Map.map.tilesets, 1, -1 do
                    if tile >= Map.map.tilesets[i].firstgid then
                        tileset = i
                        break
                    end
                end
                local tileStr = 0
                if tileset == 1 then
                    tileStr = tostring(tile - 1)
                else
                    tileStr = tostring(tile - Map.map.tilesets[tileset].firstgid)
                end
                if Map.map.tilesets[tileset].tileproperties then
                    if Map.map.tilesets[tileset].tileproperties[tileStr] then
                        properties = {}
                        properties = Map.map.tilesets[tileset].tileproperties[tileStr]
                    end
                end
            end
            
            return properties
        elseif options.level then
            local array = {}
            for i = 1, #Map.map.layers, 1 do
                if Map.map.layers[i].properties.level == options.level then
                    --local tile = getTileAt({ locX = options.locX, locY = options.locY, layer = i})
                    ------------------------------------------------------------------------------
                    local locX = options.locX
                    local locY = options.locY
                    local layer = i
                    if locX > Map.map.layers[layer].width - Map.map.locOffsetX then
                        locX = locX - Map.map.layers[layer].width
                    elseif locX < 1 - Map.map.locOffsetX then
                        locX = locX + Map.map.layers[layer].width
                    end
                    if locY > Map.map.layers[layer].height - Map.map.locOffsetY then
                        locY = locY - Map.map.layers[layer].height
                    elseif locY < 1 - Map.map.locOffsetY then
                        locY = locY + Map.map.layers[layer].height
                    end
                    local tile = Map.map.layers[layer].world[locX][locY]
                    ------------------------------------------------------------------------------
                    local tileset = 1
                    for i = #Map.map.tilesets, 1, -1 do
                        if tile >= Map.map.tilesets[i].firstgid then
                            tileset = i
                            break
                        end
                    end
                    array[#array + 1] = {}
                    array[#array].tile = tile
                    array[#array].layer = i
                    if Map.map.tilesets[tileset].tileproperties then
                        local tileStr = 0
                        if tileset == 1 then
                            tileStr = tostring(tile - 1)
                        else
                            tileStr = tostring(tile - Map.map.tilesets[tileset].firstgid)
                        end
                        array[#array].properties = Map.map.tilesets[tileset].tileproperties[tileStr]
                    else
                        array[#array].properties = nil
                    end
                    if Map.map.layers[i].properties then
                        array[#array].level = Map.map.layers[i].properties.level
                        array[#array].scaleX = Map.map.layers[i].properties.scaleX
                        array[#array].scaleY = Map.map.layers[i].properties.scaleY
                    end
                end
            end
            return array
        else
            local array = {}
            for i = 1, #Map.map.layers, 1 do
                --local tile = getTileAt({locX = options.locX, locY = options.locY, layer = i})
                ------------------------------------------------------------------------------
                local locX = options.locX
                local locY = options.locY
                local layer = i
                if locX > Map.map.layers[layer].width - Map.map.locOffsetX then
                    locX = locX - Map.map.layers[layer].width
                elseif locX < 1 - Map.map.locOffsetX then
                    locX = locX + Map.map.layers[layer].width
                end
                if locY > Map.map.layers[layer].height - Map.map.locOffsetY then
                    locY = locY - Map.map.layers[layer].height
                elseif locY < 1 - Map.map.locOffsetY then
                    locY = locY + Map.map.layers[layer].height
                end
                local tile = Map.map.layers[layer].world[locX][locY]
                ------------------------------------------------------------------------------
                local tileset = 1
                for i = #Map.map.tilesets, 1, -1 do
                    if tile >= Map.map.tilesets[i].firstgid then
                        tileset = i
                        break
                    end
                end
                array[i] = {}
                array[i].tile = tile
                if Map.map.tilesets[tileset].tileproperties then
                    local tileStr = 0
                    if tileset == 1 then
                        tileStr = tostring(tile - 1)
                    else
                        tileStr = tostring(tile - Map.map.tilesets[tileset].firstgid)
                    end
                    array[i].properties = Map.map.tilesets[tileset].tileproperties[tileStr]
                else
                    array[i].properties = nil
                end
                if Map.map.layers[i].properties then
                    array[i].level = Map.map.layers[i].properties.level
                    array[i].scaleX = Map.map.layers[i].properties.scaleX
                    array[i].scaleY = Map.map.layers[i].properties.scaleY
                end
            end
            return array
        end
    end
end

-----------------------------------------------------------

M.getObject = function(options)
    local properties = {}
    local tWorldScaleX = Map.map.tilewidth
    local tWorldScaleY = Map.map.tileheight
    if Map.map.orientation == Map.Type.Isometric then
        tWorldScaleX = Map.map.tilewidth
        tWorldScaleY = Map.map.tilewidth
    end
    if options.layer then
        local properties = {}
        local layer = options.layer
        if not Map.map.layers[layer].properties.objectLayer then
            print("ERROR(getObject): This layer is not an objectLayer.")
        end
        if options.locX and Map.map.layers[layer].properties.objectLayer then
            for i = 1, #Map.map.layers[layer].objects, 1 do
                local object = Map.map.layers[layer].objects[i]
                if options.locX >=math.ceil((object.x + 1) / tWorldScaleX) and options.locX <=math.ceil((object.x + object.width) / tWorldScaleX)
                    and options.locY >=math.ceil((object.y + 1) / tWorldScaleY) and options.locY <=math.ceil((object.y + object.height) / tWorldScaleY) then
                    object.layer = layer
                    properties[#properties + 1] = object
                end
            end
            if properties[1] then
                return properties
            end
        elseif options.levelPosX and Map.map.layers[layer].properties.objectLayer then
            for i = 1, #Map.map.layers[layer].objects, 1 do
                local object = Map.map.layers[layer].objects[i]
                if object.x == options.levelPosX and object.y == options.levelPosY then
                    object.layer = layer
                    properties[#properties + 1] = object
                end
            end
            if properties[1] then
                return properties
            end
        elseif options.name and Map.map.layers[layer].properties.objectLayer then
            for i = 1, #Map.map.layers[layer].objects, 1 do
                local object = Map.map.layers[layer].objects[i]
                if object.name == options.name then
                    object.layer = layer
                    properties[#properties + 1] = object
                end
            end
            if properties[1] then
                return properties
            end
        elseif options.type and Map.map.layers[layer].properties.objectLayer then
            for i = 1, #Map.map.layers[layer].objects, 1 do
                local object = Map.map.layers[layer].objects[i]
                if object.type == options.type then
                    object.layer = layer
                    properties[#properties + 1] = object
                end
            end
            if properties[1] then
                return properties
            end
        elseif Map.map.layers[layer].properties.objectLayer then
            for i = 1, #Map.map.layers[layer].objects, 1 do
                local object = Map.map.layers[layer].objects[i]
                object.layer = layer
                properties[#properties + 1] = object
            end
            if properties[1] then
                return properties
            end
        end
        if not properties[1] then
            --print("getObject(): These objects have no properties.")
        end
    elseif options.level then
        local properties = {}
        for j = 1, #Map.map.layers, 1 do
            if Map.map.layers[j].properties.level == options.level then
                local layer = j
                if options.locX and Map.map.layers[layer].properties.objectLayer then
                    for i = 1, #Map.map.layers[layer].objects, 1 do
                        local object = Map.map.layers[layer].objects[i]
                        if options.locX >=math.ceil((object.x + 1) / tWorldScaleX) and options.locX <=math.ceil((object.x + object.width) / tWorldScaleX)
                            and options.locY >=math.ceil((object.y + 1) / tWorldScaleY) and options.locY <=math.ceil((object.y + object.height) / tWorldScaleY) then
                            object.layer = layer
                            properties[#properties + 1] = object
                        end
                    end
                elseif options.levelPosX and Map.map.layers[layer].properties.objectLayer then
                    for i = 1, #Map.map.layers[layer].objects, 1 do
                        local object = Map.map.layers[layer].objects[i]
                        if object.x == options.levelPosX and object.y == options.levelPosY then
                            object.layer = layer
                            properties[#properties + 1] = object
                        end
                    end
                elseif options.name and Map.map.layers[layer].properties.objectLayer then
                    for i = 1, #Map.map.layers[layer].objects, 1 do
                        local object = Map.map.layers[layer].objects[i]
                        if object.name == options.name then
                            object.layer = layer
                            properties[#properties + 1] = object
                        end
                    end
                elseif options.type and Map.map.layers[layer].properties.objectLayer then
                    for i = 1, #Map.map.layers[layer].objects, 1 do
                        local object = Map.map.layers[layer].objects[i]
                        if object.type == options.type then
                            object.layer = layer
                            properties[#properties + 1] = object
                        end
                    end
                elseif Map.map.layers[layer].properties.objectLayer then
                    for i = 1, #Map.map.layers[layer].objects, 1 do
                        local object = Map.map.layers[layer].objects[i]
                        object.layer = layer
                        properties[#properties + 1] = object
                    end
                end
            end
        end
        if properties[1] then
            return properties
        else
            --print("getObject(): These objects have no properties.")
        end
    else
        local properties = {}
        for j = 1, #Map.map.layers, 1 do
            local layer = j
            if options.locX and Map.map.layers[layer].properties.objectLayer then
                for i = 1, #Map.map.layers[layer].objects, 1 do
                    local object = Map.map.layers[layer].objects[i]
                    if options.locX >=math.ceil((object.x + 1) / tWorldScaleX) and options.locX <=math.ceil((object.x + object.width) / tWorldScaleX)
                        and options.locY >=math.ceil((object.y + 1) / tWorldScaleY) and options.locY <=math.ceil((object.y + object.height) / tWorldScaleY) then
                        object.layer = layer
                        properties[#properties + 1] = object
                    end
                end
            elseif options.levelPosX and Map.map.layers[layer].properties.objectLayer then
                for i = 1, #Map.map.layers[layer].objects, 1 do
                    local object = Map.map.layers[layer].objects[i]
                    if object.x == options.levelPosX and object.y == options.levelPosY then
                        object.layer = layer
                        properties[#properties + 1] = object
                    end
                end
            elseif options.name and Map.map.layers[layer].properties.objectLayer then
                for i = 1, #Map.map.layers[layer].objects, 1 do
                    local object = Map.map.layers[layer].objects[i]
                    if object.name == options.name then
                        object.layer = layer
                        properties[#properties + 1] = object
                    end
                end
            elseif options.type and Map.map.layers[layer].properties.objectLayer then
                for i = 1, #Map.map.layers[layer].objects, 1 do
                    local object = Map.map.layers[layer].objects[i]
                    if object.type == options.type then
                        object.layer = layer
                        properties[#properties + 1] = object
                    end
                end
            elseif Map.map.layers[layer].properties.objectLayer then
                for i = 1, #Map.map.layers[layer].objects, 1 do
                    local object = Map.map.layers[layer].objects[i]
                    object.layer = layer
                    properties[#properties + 1] = object
                end
            end
        end
        if properties[1] then
            return properties
        else
            --print("getObject(): These objects have no properties.")
        end
    end
end

-----------------------------------------------------------



-----------------------------------------------------------

local loadTileSet = function(index)
    local tempTileWidth = Map.map.tilesets[index].tilewidth + (Map.map.tilesets[index].spacing)
    local tempTileHeight = Map.map.tilesets[index].tileheight + (Map.map.tilesets[index].spacing)
    Map.map.numFrames[index] = math.floor(Map.map.tilesets[index].imagewidth / tempTileWidth) * math.floor(Map.map.tilesets[index].imageheight / tempTileHeight)
    local options = {width = Map.map.tilesets[index].tilewidth, 
        height = Map.map.tilesets[index].tileheight, 
        numFrames = Map.map.numFrames[index], 
        border = Map.map.tilesets[index].margin,
        sheetContentWidth = Map.map.tilesets[index].imagewidth, 
        sheetContentHeight = Map.map.tilesets[index].imageheight
    }
    Xml.src = nil
    local name = nil
    local tsx = nil
    for key,value in pairs(Map.loadedTileSets) do
        if key == Map.map.tilesets[index].name then
            Xml.src = value[1]
            tsx = value[2]
            name = key
        end
    end
    if not Xml.src then
        Xml.src = Map.map.tilesets[index].image
        Map.tileSets[index] = graphics.newImageSheet(Xml.src, options)
        
        if not Map.tileSets[index] then
            --get tileset name with extension
            local srcString = Xml.src
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
            
            --get Map.map name with extension
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
            
            --get Map.map name
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
            Map.tileSets[index] = graphics.newImageSheet(newSource, options)
            if Map.tileSets[index] then
                success = 1
                print("Found "..tilesetStringExt.." in resource directory.")
            end
            --look in folder = Map.map filename with extension
            if success ~= 1 then
                newSource = mapStringExt.."/"..tilesetStringExt
                print("Checking "..mapStringExt.." folder...")
                Map.tileSets[index] = graphics.newImageSheet(newSource, options)
                if Map.tileSets[index] then
                    success = 1
                    print("Found "..tilesetStringExt.." in "..newSource)
                end
            end
            --look in folder = Map.map filename
            if success ~= 1 then
                newSource = mapString.."/"..tilesetStringExt
                print("Checking "..mapString.." folder...")
                Map.tileSets[index] = graphics.newImageSheet(newSource, options)
                if Map.tileSets[index] then
                    success = 1
                    print("Found "..tilesetStringExt.." in "..newSource)
                end
            end
            --look in folder = tileset name with extension
            if success ~= 1 then
                newSource = tilesetStringExt.."/"..tilesetStringExt
                print("Checking "..tilesetStringExt.." folder...")
                Map.tileSets[index] = graphics.newImageSheet(newSource, options)
                if Map.tileSets[index] then
                    success = 1
                    print("Found "..tilesetStringExt.." in "..newSource)
                end
            end
            --look in folder = tileset name
            if success ~= 1 then
                newSource = tilesetString.."/"..tilesetStringExt
                print("Checking "..tilesetString.." folder...")
                Map.tileSets[index] = graphics.newImageSheet(newSource, options)
                if Map.tileSets[index] then
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
        Map.tileSets[index] = graphics.newImageSheet(Xml.src, options)
        if not Map.tileSets[index] then
            Map.loadedTileSets[name][2] = "FILE NOT FOUND"
        end
        
        if tsx then
            --LOAD TILESET TSX and APPLY VALUES TO MAP.TILESETS
            local temp = Xml.loadFile(tsx)
            for i = 1, #temp.child, 1 do
                for key,value in pairs(temp.child[i]) do
                    if temp.child[i].properties.id then
                        if not Map.map.tilesets[index].tileproperties then
                            Map.map.tilesets[index].tileproperties = {}
                        end
                        if not Map.map.tilesets[index].tileproperties[temp.child[i].properties.id] then
                            Map.map.tilesets[index].tileproperties[temp.child[i].properties.id] = {}
                        end
                        Map.map.tilesets[index].tileproperties[temp.child[i].properties.id][temp.child[i].child[1].child[1].properties.name] = temp.child[i].child[1].child[1].properties.value
                    end
                end
            end
        end
    end
end

local loadTileSetExt = function(name, source, dataSource)
    local path = system.pathForFile(source, system.ResourcesDirectory)
    path = nil
    Map.loadedTileSets[name] = {source, dataSource}
    if Map.map.tilesets then
        for i = 1, #Map.map.tilesets, 1 do
            if name == Map.map.tilesets[i].name then
                loadTileSet(i)
            end
        end
    end
end
M.loadTileSet = loadTileSetExt

-----------------------------------------------------------

M.getTileSetNames = function(arg)
    local array = {}
    for i = 1, #Map.map.tilesets, 1 do
        array[#array + 1] = Map.map.tilesets[i].name
    end
    return array
end

-----------------------------------------------------------

M.detectSpriteLayers = function()
    local layers = {}
    for i = 1, #Map.map.layers, 1 do
        if Map.map.layers[i].properties and Map.map.layers[i].properties.spriteLayer then
            layers[#layers + 1] = i
            Map.spriteLayers[#Map.spriteLayers + 1] = i
        end
    end
    if #layers == 0 then
        print("WARNING(detectSpriteLayers): No Sprite Layers Found. Defaulting to all Map.map layers.")
        for i = 1, #Map.map.layers, 1 do
            layers[#layers + 1] = i
            Map.spriteLayers[#Map.spriteLayers + 1] = i
            Map.map.layers[i].properties.spriteLayer = "true"
        end
    end
    return layers
end

-----------------------------------------------------------

M.detectObjectLayers = function()
    local layers = {}
    for i = 1, #Map.map.layers, 1 do
        if Map.map.layers[i].properties.objectLayer then
            layers[#layers + 1] = i
            Map.objectLayers[#Map.objectLayers + 1] = i
        end
    end
    if #layers == 0 then
        print("WARNING(detectObjectLayers): No Object Layers Found.")
        layers = nil
    end
    return layers
end

-----------------------------------------------------------

M.preloadMap = function(src, dir)
    local startTime=system.getTimer()
    local storageToggle = false
    Xml.src = src
    local srcString = Xml.src
    local directory = ""
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
        directory = string.sub(srcString, 1, slashes[#slashes])
    else
        srcStringExt = srcString
    end
    if #periods > 0 then
        if periods[#periods] >= length - 6 then
            srcString = string.sub(srcString, (slashes[#slashes] or 0) + 1, (periods[#periods] or 0) - 1)
        else
            srcString = srcStringExt
        end
    else
        srcString = srcStringExt
    end
    local detectJsonExt = string.find(srcStringExt, ".json")
    if string.len(srcStringExt) ~= string.len(srcString) then
        if not detectJsonExt then
            --print("ERROR: "..Xml.src.." is not a Json file.")
        end
    else
        Xml.src = Xml.src..".json"
        detectJsonExt = true
    end	
    local path
    local base
    if dir == "Documents" then
        path = system.pathForFile(Xml.src, system.DocumentsDirectory)
        base = system.DocumentsDirectory
    elseif dir == "Temporary" then
        path = system.pathForFile(Xml.src, system.TemporaryDirectory)
        base = system.TemporaryDirectory
    elseif not dir or dir == "Resource" then
        path = system.pathForFile(Xml.src, system.ResourceDirectory)	
        base = system.ResourceDirectory
    end
    
    if detectJsonExt then
        local saveData = io.open(path, "r")
        if saveData then
            local jsonData = saveData:read("*a")
            
            if not Map.mapStorage[Xml.src] then
                Map.mapStorage[Xml.src] = json.decode(jsonData)
                print(Xml.src.." preloaded")
            else
                storageToggle = true
                print(Xml.src.." already in storage")
            end
            
            io.close(saveData)
        else
            print("ERROR: Map Not Found")
        end
    else
        if not Map.mapStorage[Xml.src] then
            Map.mapStorage[Xml.src] = {}
            ------------------------------------------------------------------------------
            ------------------------------------------------------------------------------
            --LOAD TMX FILE
            local temp = Xml.loadFile(Xml.src, base)
            if temp then
                for key,value in pairs(temp.properties) do
                    Map.mapStorage[Xml.src][key] = value
                    if key == "height" or key == "tileheight" or key == "tilewidth" or key == "width" then
                        Map.mapStorage[Xml.src][key] = tonumber(Map.mapStorage[Xml.src][key])
                    end
                end
                Map.mapStorage[Xml.src].tilesets = {}
                Map.mapStorage[Xml.src].properties = {}
                local layerIndex = 1
                local tileSetIndex = 1
                
                for i = 1, #temp.child, 1 do
                    if temp.child[i].name == "properties" then
                        for j = 1, #temp.child[i].child, 1 do
                            Map.mapStorage[Xml.src].properties[temp.child[i].child[j].properties.name] = temp.child[i].child[j].properties.value
                        end
                    end
                    
                    if temp.child[i].name == "imagelayer" then
                        for key,value in pairs(temp.child[i].properties) do
                            Map.mapStorage[Xml.src].layers[layerIndex][key] = value
                            if key == "width" or key == "height" then
                                Map.mapStorage[Xml.src].layers[layerIndex][key] = tonumber(Map.mapStorage[Xml.src].layers[layerIndex][key])
                            end
                        end
                        for j = 1, #temp.child[i].child, 1 do
                            if temp.child[i].child[j].name == "properties" then
                                for k = 1, #temp.child[i].child[j].child, 1 do
                                    Map.mapStorage[Xml.src].layers[layerIndex].properties[temp.child[i].child[j].child[k].properties.name] = temp.child[i].child[j].child[k].properties.value
                                end
                            end
                            
                            if temp.child[i].child[j].name == "image" then 
                                Map.mapStorage[Xml.src].layers[layerIndex]["image"] = temp.child[i].child[j].properties["source"]
                            end
                        end
                        
                        layerIndex = layerIndex + 1
                    end
                    
                    if temp.child[i].name == "layer" then
                        for key,value in pairs(temp.child[i].properties) do
                            Map.mapStorage[Xml.src].layers[layerIndex][key] = value
                            if key == "width" or key == "height" then
                                Map.mapStorage[Xml.src].layers[layerIndex][key] = tonumber(Map.mapStorage[Xml.src].layers[layerIndex][key])
                            end
                        end
                        for j = 1, #temp.child[i].child, 1 do
                            if temp.child[i].child[j].name == "properties" then
                                for k = 1, #temp.child[i].child[j].child, 1 do
                                    Map.mapStorage[Xml.src].layers[layerIndex].properties[temp.child[i].child[j].child[k].properties.name] = temp.child[i].child[j].child[k].properties.value
                                end
                            end
                        end
                        layerIndex = layerIndex + 1
                    end
                    
                    if temp.child[i].name == "objectgroup" then
                        for key,value in pairs(temp.child[i].properties) do
                            Map.mapStorage[Xml.src].layers[layerIndex][key] = value
                            if key == "width" or key == "height" then
                                Map.mapStorage[Xml.src].layers[layerIndex][key] = tonumber(Map.mapStorage[Xml.src].layers[layerIndex][key])
                            end
                        end	
                        Map.mapStorage[Xml.src].layers[layerIndex]["width"] = Map.mapStorage[Xml.src]["width"]
                        Map.mapStorage[Xml.src].layers[layerIndex]["height"] = Map.mapStorage[Xml.src]["height"]			
                        Map.mapStorage[Xml.src].layers[layerIndex].objects = {}
                        local firstObject = true
                        local indexMod = 0
                        for j = 1, #temp.child[i].child, 1 do
                            if temp.child[i].child[j].name == "properties" then
                                for k = 1, #temp.child[i].child[j].child, 1 do
                                    Map.mapStorage[Xml.src].layers[layerIndex].properties[temp.child[i].child[j].child[k].properties.name] = temp.child[i].child[j].child[k].properties.value
                                end
                                if not Map.mapStorage[Xml.src].layers[layerIndex].properties["width"] then
                                    Map.mapStorage[Xml.src].layers[layerIndex].properties["width"] = 0
                                end
                                if not Map.mapStorage[Xml.src].layers[layerIndex].properties["height"] then
                                    Map.mapStorage[Xml.src].layers[layerIndex].properties["height"] = 0
                                end
                            end
                            if temp.child[i].child[j].name == "object" then
                                if firstObject then
                                    firstObject = false
                                    indexMod = j - 1
                                end
                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod] = {}
                                for key,value in pairs(temp.child[i].child[j].properties) do
                                    Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod][key] = value
                                    if key == "width" or key == "height" or key == "x" or key == "y" or key == "gid" then
                                        Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod][key] = tonumber(Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod][key])
                                    end
                                end	
                                if not Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].width then
                                    Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].width = 0
                                end				
                                if not Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].height then
                                    Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].height = 0
                                end	
                                --------
                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].properties = {}
                                
                                for k = 1, #temp.child[i].child[j].child, 1 do
                                    if temp.child[i].child[j].child[k].name == "properties" then
                                        for m = 1, #temp.child[i].child[j].child[k].child, 1 do	
                                            Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].properties[temp.child[i].child[j].child[k].child[m].properties.name] = temp.child[i].child[j].child[k].child[m].properties.value								
                                        end
                                    end
                                    if temp.child[i].child[j].child[k].name == "polygon" then
                                        Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polygon = {}
                                        local pointString = temp.child[i].child[j].child[k].properties.points
                                        local codes = {string.byte(","), string.byte(" ")}
                                        local stringIndexStart = 1
                                        local pointIndex = 1
                                        
                                        for s = 1, string.len(pointString), 1 do
                                            if string.byte(pointString, s, s) == codes[1] then
                                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polygon[pointIndex] = {}
                                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polygon[pointIndex].x = tonumber(string.sub(pointString, stringIndexStart, s - 1))
                                                stringIndexStart = s + 1
                                            end
                                            if string.byte(pointString, s, s) == codes[2] then
                                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polygon[pointIndex].y = tonumber(string.sub(pointString, stringIndexStart, s - 1))
                                                stringIndexStart = s + 1
                                                pointIndex = pointIndex + 1
                                            end
                                            if s == string.len(pointString) then
                                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polygon[pointIndex].y = tonumber(string.sub(pointString, stringIndexStart, s))
                                            end
                                        end
                                    end
                                    if temp.child[i].child[j].child[k].name == "polyline" then
                                        Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polyline = {}
                                        local pointString = temp.child[i].child[j].child[k].properties.points
                                        local codes = {string.byte(","), string.byte(" ")}
                                        local stringIndexStart = 1
                                        local pointIndex = 1
                                        
                                        for s = 1, string.len(pointString), 1 do
                                            if string.byte(pointString, s, s) == codes[1] then
                                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polyline[pointIndex] = {}
                                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polyline[pointIndex].x = tonumber(string.sub(pointString, stringIndexStart, s - 1))
                                                stringIndexStart = s + 1
                                            end
                                            if string.byte(pointString, s, s) == codes[2] then
                                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polyline[pointIndex].y = tonumber(string.sub(pointString, stringIndexStart, s - 1))
                                                stringIndexStart = s + 1
                                                pointIndex = pointIndex + 1
                                            end
                                            if s == string.len(pointString) then
                                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polyline[pointIndex].y = tonumber(string.sub(pointString, stringIndexStart, s))
                                            end
                                        end
                                    end
                                    if temp.child[i].child[j].child[k].name == "ellipse" then
                                        Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].ellipse = true
                                    end
                                end
                            end
                        end
                        layerIndex = layerIndex + 1
                    end
                    
                    if temp.child[i].name == "tileset" then
                        Map.mapStorage[Xml.src].tilesets[tileSetIndex] = {}
                        
                        if temp.child[i].properties.source then
                            local tempSet = Xml.loadFile(directory..temp.child[i].properties.source, base)
                            if not tempSet.properties.spacing then 
                                tempSet.properties.spacing = 0
                            end
                            if not tempSet.properties.margin then
                                tempSet.properties.margin = 0
                            end
                            for key,value in pairs(tempSet.properties) do
                                Map.mapStorage[Xml.src].tilesets[tileSetIndex][key] = value
                                if key == "tilewidth" or key == "tileheight" or key == "spacing" or key == "margin" then
                                    Map.mapStorage[Xml.src].tilesets[tileSetIndex][key] = tonumber(Map.mapStorage[Xml.src].tilesets[tileSetIndex][key])
                                end
                            end
                            
                            
                            for j = 1, #tempSet.child, 1 do
                                if tempSet.child[j].name == "properties" then
                                    Map.mapStorage[Xml.src].tilesets[tileSetIndex].properties = {}
                                    for k = 1, #tempSet.child[j].child, 1 do
                                        Map.mapStorage[Xml.src].tilesets[tileSetIndex].properties[tempSet.child[j].child[k].properties.name] = tempSet.child[j].child[k].properties.value
                                    end
                                end
                                if tempSet.child[j].name == "image" then
                                    for key,value in pairs(tempSet.child[j].properties) do
                                        if key == "source" then
                                            Map.mapStorage[Xml.src].tilesets[tileSetIndex]["image"] = directory..value
                                        elseif key == "width" then
                                            Map.mapStorage[Xml.src].tilesets[tileSetIndex]["imagewidth"] = tonumber(value)
                                        elseif key == "height" then
                                            Map.mapStorage[Xml.src].tilesets[tileSetIndex]["imageheight"] = tonumber(value)
                                        else
                                            Map.mapStorage[Xml.src].tilesets[tileSetIndex][key] = value
                                        end															
                                    end									
                                end
                                if tempSet.child[j].name == "tile" then
                                    if not Map.mapStorage[Xml.src].tilesets[tileSetIndex].tileproperties then
                                        Map.mapStorage[Xml.src].tilesets[tileSetIndex].tileproperties = {}
                                    end
                                    Map.mapStorage[Xml.src].tilesets[tileSetIndex].tileproperties[tempSet.child[j].properties.id] = {}
                                    
                                    for k = 1, #tempSet.child[j].child, 1 do
                                        if tempSet.child[j].child[k].name == "properties" then
                                            for m = 1, #tempSet.child[j].child[k].child, 1 do
                                                local name = tempSet.child[j].child[k].child[m].properties.name
                                                local value = tempSet.child[j].child[k].child[m].properties.value
                                                Map.mapStorage[Xml.src].tilesets[tileSetIndex].tileproperties[tempSet.child[j].properties.id][name] = value
                                            end
                                        end
                                    end
                                end
                            end							
                        else
                            local tempSet = temp.child[i]
                            if not tempSet.properties.spacing then 
                                tempSet.properties.spacing = 0
                            end
                            if not tempSet.properties.margin then
                                tempSet.properties.margin = 0
                            end
                            for key,value in pairs(tempSet.properties) do
                                Map.mapStorage[Xml.src].tilesets[tileSetIndex][key] = value
                                if key == "tilewidth" or key == "tileheight" or key == "spacing" or key == "margin" then
                                    Map.mapStorage[Xml.src].tilesets[tileSetIndex][key] = tonumber(Map.mapStorage[Xml.src].tilesets[tileSetIndex][key])
                                end
                            end							
                            
                            for j = 1, #tempSet.child, 1 do
                                if tempSet.child[j].name == "properties" then
                                    Map.mapStorage[Xml.src].tilesets[tileSetIndex].properties = {}
                                    for k = 1, #tempSet.child[j].child, 1 do
                                        Map.mapStorage[Xml.src].tilesets[tileSetIndex].properties[tempSet.child[j].child[k].properties.name] = tempSet.child[j].child[k].properties.value
                                    end
                                end
                                if tempSet.child[j].name == "image" then
                                    for key,value in pairs(tempSet.child[j].properties) do
                                        if key == "source" then
                                            Map.mapStorage[Xml.src].tilesets[tileSetIndex]["image"] = directory..value
                                        elseif key == "width" then
                                            Map.mapStorage[Xml.src].tilesets[tileSetIndex]["imagewidth"] = tonumber(value)
                                        elseif key == "height" then
                                            Map.mapStorage[Xml.src].tilesets[tileSetIndex]["imageheight"] = tonumber(value)
                                        else
                                            Map.mapStorage[Xml.src].tilesets[tileSetIndex][key] = value
                                        end															
                                    end									
                                end
                                if tempSet.child[j].name == "tile" then
                                    if not Map.mapStorage[Xml.src].tilesets[tileSetIndex].tileproperties then
                                        Map.mapStorage[Xml.src].tilesets[tileSetIndex].tileproperties = {}
                                    end
                                    Map.mapStorage[Xml.src].tilesets[tileSetIndex].tileproperties[tempSet.child[j].properties.id] = {}
                                    
                                    for k = 1, #tempSet.child[j].child, 1 do
                                        if tempSet.child[j].child[k].name == "properties" then
                                            for m = 1, #tempSet.child[j].child[k].child, 1 do
                                                local name = tempSet.child[j].child[k].child[m].properties.name
                                                local value = tempSet.child[j].child[k].child[m].properties.value
                                                Map.mapStorage[Xml.src].tilesets[tileSetIndex].tileproperties[tempSet.child[j].properties.id][name] = value
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        Map.mapStorage[Xml.src].tilesets[tileSetIndex].firstgid = tonumber(temp.child[i].properties.firstgid)
                        tileSetIndex = tileSetIndex + 1
                    end
                end
            else
                print("ERROR: Map Not Found")
                debugText = "ERROR: Map Not Found"
            end
            
            print(Xml.src.." preloaded")			
        else			
            storageToggle = true
            print(Xml.src.." already in storage. Load Time: "..system.getTimer() - startTime)
        end		
    end
    
    if not storageToggle then
        Map.mapStorage[Xml.src].numLevels = 1
        
        if not Map.mapStorage[Xml.src].modified then
            if Map.mapStorage[Xml.src].orientation == "orthogonal" then
                Map.mapStorage[Xml.src].orientation = Map.Type.Orthogonal
            elseif Map.mapStorage[Xml.src].orientation == "isometric" then
                Map.mapStorage[Xml.src].orientation = Map.Type.Isometric
            elseif Map.mapStorage[Xml.src].orientation == "staggered" then
                Map.mapStorage[Xml.src].orientation = Map.Type.Staggered
            end
        end
        
        local globalID = {}
        local prevLevel = "1"
        for i = 1, #Map.mapStorage[Xml.src].layers, 1 do
            if type(Map.mapStorage[Xml.src].layers[i].properties.forceDefaultPhysics) == "string" then
                if Map.mapStorage[Xml.src].layers[i].properties.forceDefaultPhysics == "true" then
                    Map.mapStorage[Xml.src].layers[i].properties.forceDefaultPhysics = true
                else
                    Map.mapStorage[Xml.src].layers[i].properties.forceDefaultPhysics = false
                end
            end
            
            --DETECT WIDTH AND HEIGHT
            if Map.mapStorage[Xml.src].layers[i].properties.width then
                Map.mapStorage[Xml.src].layers[i].width = tonumber(Map.mapStorage[Xml.src].layers[i].properties.width)
            end
            if Map.mapStorage[Xml.src].layers[i].properties.height then
                Map.mapStorage[Xml.src].layers[i].height = tonumber(Map.mapStorage[Xml.src].layers[i].properties.height)
            end			
            --TOGGLE PARALLAX CROP
            if Map.mapStorage[Xml.src].layers[i].properties.toggleParallaxCrop == "true" then
                Map.mapStorage[Xml.src].layers[i].width = math.floor(Map.mapStorage[Xml.src].layers[i].width * Map.mapStorage[Xml.src].layers[i].parallaxX)
                Map.mapStorage[Xml.src].layers[i].height = math.floor(Map.mapStorage[Xml.src].layers[i].height * Map.mapStorage[Xml.src].layers[i].parallaxY)
                if Map.mapStorage[Xml.src].layers[i].width > Map.mapStorage[Xml.src].width then
                    Map.mapStorage[Xml.src].layers[i].width = Map.mapStorage[Xml.src].width
                end
                if Map.mapStorage[Xml.src].layers[i].height > Map.mapStorage[Xml.src].height then
                    Map.mapStorage[Xml.src].layers[i].height = Map.mapStorage[Xml.src].height
                end
            end		
            --FIT BY PARALLAX / FIT BY SCALE
            if Map.mapStorage[Xml.src].layers[i].properties.fitByParallax then
                Map.mapStorage[Xml.src].layers[i].parallaxX = Map.mapStorage[Xml.src].layers[i].width / Map.mapStorage[Xml.src].width
                Map.mapStorage[Xml.src].layers[i].parallaxY = Map.mapStorage[Xml.src].layers[i].height / Map.mapStorage[Xml.src].height
            else
                if Map.mapStorage[Xml.src].layers[i].properties.fitByScale then
                    Map.mapStorage[Xml.src].layers[i].properties.scaleX = (Map.mapStorage[Xml.src].width * Map.mapStorage[Xml.src].layers[i].properties.parallaxX) / Map.mapStorage[Xml.src].layers[i].width
                    Map.mapStorage[Xml.src].layers[i].properties.scaleY = (Map.mapStorage[Xml.src].height * Map.mapStorage[Xml.src].layers[i].properties.parallaxY) / Map.mapStorage[Xml.src].layers[i].height
                end
            end
            
            ----------------------------------------------------------------------------------
            local hex2bin = {
                ["0"] = "0000",
                ["1"] = "0001",
                ["2"] = "0010",
                ["3"] = "0011",
                ["4"] = "0100",
                ["5"] = "0101",
                ["6"] = "0110",
                ["7"] = "0111",
                ["8"] = "1000",
                ["9"] = "1001",
                ["a"] = "1010",
                ["b"] = "1011",
                ["c"] = "1100",
                ["d"] = "1101",
                ["e"] = "1110",
                ["f"] = "1111"
            }
            
            local Hex2Bin = function(s)
                local ret = ""
                local i = 0
                for i in string.gfind(s, ".") do
                    i = string.lower(i)
                    
                    ret = ret..hex2bin[i]
                end
                return ret
            end
            
            local Bin2Dec = function(s)	
                local num = 0
                local ex = string.len(s) - 1
                local l = 0
                l = ex + 1
                for i = 1, l do
                    b = string.sub(s, i, i)
                    if b == "1" then
                        num = num + 2^ex
                    end
                    ex = ex - 1
                end
                return string.format("%u", num)
            end
            
            local Dec2Bin = function(s, num)
                local n
                if (num == nil) then
                    n = 0
                else
                    n = num
                end
                s = string.format("%x", s)
                s = Hex2Bin(s)
                while string.len(s) < n do
                    s = "0"..s
                end
                return s
            end
            ----------------------------------------------------------------------------------
            
            --LOAD WORLD ARRAYS
            if not Map.mapStorage[Xml.src].modified then
                Map.mapStorage[Xml.src].layers[i].world = {}
                --Map.mapStorage[Xml.src].layers[i].Map.tileObjects = {}
                if Map.enableFlipRotation then
                    Map.mapStorage[Xml.src].layers[i].flipRotation = {}
                end
                if Camera.enableLighting and i == 1 then
                    Map.mapStorage[Xml.src].lightToggle = {}
                    Map.mapStorage[Xml.src].lightToggle2 = {}
                    Map.mapStorage[Xml.src].lightToggle3 = {}
                    Light.lightingData.lightLookup = {}
                end
                for x = 1, Map.mapStorage[Xml.src].layers[i].width, 1 do
                    Map.mapStorage[Xml.src].layers[i].world[x] = {}
                    --Map.mapStorage[Xml.src].layers[i].Map.tileObjects[x] = {}
                    if Map.mapStorage[Xml.src].layers[i].lighting then
                        Map.mapStorage[Xml.src].layers[i].lighting[x] = {}
                    end
                    if Camera.enableLighting and i == 1 then
                        Map.mapStorage[Xml.src].lightToggle[x] = {}
                        Map.mapStorage[Xml.src].lightToggle2[x] = {}
                        Map.mapStorage[Xml.src].lightToggle3[x] = {}
                    end
                    if Map.enableFlipRotation then
                        Map.mapStorage[Xml.src].layers[i].flipRotation[x] = {}
                    end
                    local lx = x
                    while lx > Map.mapStorage[Xml.src].width do
                        lx = lx - Map.mapStorage[Xml.src].width
                    end
                    for y = 1, Map.mapStorage[Xml.src].layers[i].height, 1 do
                        if Camera.enableLighting and i == 1 then
                            Map.mapStorage[Xml.src].lightToggle2[x][y] = 0
                        end
                        
                        local ly = y
                        while ly > Map.mapStorage[Xml.src].height do
                            ly = ly - Map.mapStorage[Xml.src].height
                        end
                        if Map.mapStorage[Xml.src].layers[i].data then
                            if Map.enableFlipRotation then
                                if Map.mapStorage[Xml.src].layers[i].data[(Map.mapStorage[Xml.src].width * (ly - 1)) + lx] > 1000000 then
                                    local string = tostring(Map.mapStorage[Xml.src].layers[i].data[(Map.mapStorage[Xml.src].width * (ly - 1)) + lx])
                                    if globalID[string] then
                                        Map.mapStorage[Xml.src].layers[i].flipRotation[x][y] = globalID[string][1]
                                        Map.mapStorage[Xml.src].layers[i].world[x][y] = globalID[string][2]
                                    else
                                        local binary = Dec2Bin(string)
                                        local command = string.sub(binary, 1, 3)
                                        local flipRotate = Bin2Dec(command)
                                        Map.mapStorage[Xml.src].layers[i].flipRotation[x][y] = tonumber(flipRotate)
                                        local binaryID = string.sub(binary, 4, 32)
                                        local tileID = Bin2Dec(binaryID)
                                        Map.mapStorage[Xml.src].layers[i].world[x][y] = tonumber(tileID)
                                        globalID[string] = {tonumber(flipRotate), tonumber(tileID)}
                                    end
                                else
                                    Map.mapStorage[Xml.src].layers[i].world[x][y] = Map.mapStorage[Xml.src].layers[i].data[(Map.mapStorage[Xml.src].width * (ly - 1)) + lx]
                                end
                            else
                                Map.mapStorage[Xml.src].layers[i].world[x][y] = Map.mapStorage[Xml.src].layers[i].data[(Map.mapStorage[Xml.src].width * (ly - 1)) + lx]
                            end
                            
                            if Camera.enableLighting then
                                if Map.mapStorage[Xml.src].layers[i].world[x][y] ~= 0 then
                                    local frameIndex = Map.mapStorage[Xml.src].layers[i].world[x][y]
                                    local tileSetIndex = 1
                                    for i = 1, #Map.mapStorage[Xml.src].tilesets, 1 do
                                        if frameIndex >= Map.mapStorage[Xml.src].tilesets[i].firstgid then
                                            tileSetIndex = i
                                        else
                                            break
                                        end
                                    end
                                    
                                    tileStr = tostring((frameIndex - (Map.mapStorage[Xml.src].tilesets[tileSetIndex].firstgid - 1)) - 1)
                                    local mT = Map.mapStorage[Xml.src].tilesets[tileSetIndex].tileproperties
                                    if mT then
                                        if mT[tileStr] then
                                            if mT[tileStr]["lightSource"] then
                                                local range = json.decode(mT[tileStr]["lightRange"])
                                                local maxRange = range[1]
                                                for l = 1, 3, 1 do
                                                    if range[l] > maxRange then
                                                        maxRange = range[l]
                                                    end
                                                end
                                                Map.mapStorage[Xml.src].lights[Light.lightIDs] = {locX = x, 
                                                    locY = y, 
                                                    tileSetIndex = tileSetIndex, 
                                                    tileStr = tileStr,
                                                    frameIndex = frameIndex,
                                                    source = json.decode(mT[tileStr]["lightSource"]),
                                                    falloff = json.decode(mT[tileStr]["lightFalloff"]),
                                                    range = range,
                                                    maxRange = maxRange,
                                                    layer = i,
                                                    baseLayer = i,
                                                    level = M.getLevel(i),
                                                    id = Light.lightIDs,
                                                    area = {},
                                                    areaIndex = 1
                                                }
                                                if mT[tileStr]["lightLayer"] then
                                                    Map.mapStorage[Xml.src].lights[Light.lightIDs].layer = tonumber(mT[tileStr]["lightLayer"])
                                                    Map.mapStorage[Xml.src].lights[Light.lightIDs].level = M.getLevel(Map.mapStorage[Xml.src].lights[Light.lightIDs].layer)
                                                elseif mT[tileStr]["lightLayerRelative"] then
                                                    Map.mapStorage[Xml.src].lights[Light.lightIDs].layer = Map.mapStorage[Xml.src].lights[Light.lightIDs].layer + tonumber(mT[tileStr]["lightLayerRelative"])
                                                    if Map.mapStorage[Xml.src].lights[Light.lightIDs].layer < 1 then
                                                        Map.mapStorage[Xml.src].lights[Light.lightIDs].layer = 1
                                                    end
                                                    if Map.mapStorage[Xml.src].lights[Light.lightIDs].layer > #Map.mapStorage[Xml.src].layers then
                                                        Map.mapStorage[Xml.src].lights[Light.lightIDs].layer = #Map.mapStorage[Xml.src].layers
                                                    end
                                                    Map.mapStorage[Xml.src].lights[Light.lightIDs].level = M.getLevel(Map.mapStorage[Xml.src].lights[Light.lightIDs].layer)
                                                end
                                                if mT[tileStr]["lightArc"] then
                                                    Map.mapStorage[Xml.src].lights[Light.lightIDs].arc = json.decode(
                                                    mT[tileStr]["lightArc"]
                                                    )
                                                end
                                                if mT[tileStr]["lightRays"] then
                                                    Map.mapStorage[Xml.src].lights[Light.lightIDs].rays = json.decode(
                                                    mT[tileStr]["lightRays"]
                                                    )
                                                end
                                                if mT[tileStr]["layerFalloff"] then
                                                    Map.mapStorage[Xml.src].lights[Light.lightIDs].layerFalloff = json.decode(
                                                    mT[tileStr]["layerFalloff"]
                                                    )
                                                end
                                                if mT[tileStr]["levelFalloff"] then
                                                    Map.mapStorage[Xml.src].lights[Light.lightIDs].levelFalloff = json.decode(
                                                    mT[tileStr]["levelFalloff"]
                                                    )
                                                end
                                                Light.lightIDs = Light.lightIDs + 1
                                            end
                                        end
                                    end
                                end
                            end
                        else
                            Map.mapStorage[Xml.src].layers[i].world[x][y] = 0
                        end
                    end
                end 
            end
        end
        
        if Map.mapStorage[Xml.src].orientation == 1 then
            for i = 1, #Map.mapStorage[Xml.src].layers, 1 do
                if not Map.mapStorage[Xml.src].layers[i].data and not Map.mapStorage[Xml.src].layers[i].image then
                    for j = 1, #Map.mapStorage[Xml.src].layers[i].objects, 1 do
                        Map.mapStorage[Xml.src].layers[i].objects[j].width = Map.mapStorage[Xml.src].layers[i].objects[j].width * 2
                        Map.mapStorage[Xml.src].layers[i].objects[j].height = Map.mapStorage[Xml.src].layers[i].objects[j].height * 2
                        Map.mapStorage[Xml.src].layers[i].objects[j].x = Map.mapStorage[Xml.src].layers[i].objects[j].x * 2
                        Map.mapStorage[Xml.src].layers[i].objects[j].y = Map.mapStorage[Xml.src].layers[i].objects[j].y * 2
                        if Map.mapStorage[Xml.src].layers[i].objects[j].polygon then
                            for k = 1, #Map.mapStorage[Xml.src].layers[i].objects[j].polygon, 1 do
                                Map.mapStorage[Xml.src].layers[i].objects[j].polygon[k].x = Map.mapStorage[Xml.src].layers[i].objects[j].polygon[k].x * 2
                                Map.mapStorage[Xml.src].layers[i].objects[j].polygon[k].y = Map.mapStorage[Xml.src].layers[i].objects[j].polygon[k].y * 2
                            end
                        elseif Map.mapStorage[Xml.src].layers[i].objects[j].polyline then
                            for k = 1, #Map.mapStorage[Xml.src].layers[i].objects[j].polyline, 1 do
                                Map.mapStorage[Xml.src].layers[i].objects[j].polyline[k].x = Map.mapStorage[Xml.src].layers[i].objects[j].polyline[k].x * 2
                                Map.mapStorage[Xml.src].layers[i].objects[j].polyline[k].y = Map.mapStorage[Xml.src].layers[i].objects[j].polyline[k].y * 2
                            end
                        end
                    end
                end
            end
        end
        print("Map Load Time: "..system.getTimer() - startTime)
    end
    
end

-----------------------------------------------------------

M.expandMapBounds = function(params)
    local prevMapWidth, prevMapHeight = Map.map.width, Map.map.height
    local prevMapOX, prevMapOY = Map.map.locOffsetX, Map.map.locOffsetY
    
    
    
    if params.leftBound then
        --left
        prevMapWidth = Map.map.width
        prevMapHeight = Map.map.height
        prevMapOX = Map.map.locOffsetX
        prevMapOY = Map.map.locOffsetY
        local prevOX = Map.map.locOffsetX
        local x = 1 - params.leftBound
        Map.map.locOffsetX = Map.map.locOffsetX + x
        Map.map.width = Map.map.width + x
        
        for i = 1, #Map.map.layers, 1 do
            Map.map.layers[i].width = Map.map.layers[i].width + x
            for locX = 1 - Map.map.locOffsetX, 1 - prevOX - 1, 1 do
                Map.map.layers[i].world[locX] = {}
                Map.tileObjects[i][locX] = {}
                if Map.map.layers[i].extendedObjects then
                    Map.map.layers[i].extendedObjects[locX] = {}
                end
                if Map.enableFlipRotation then
                    Map.map.layers[i].flipRotation[locX] = {}
                end
                for locY = 1, Map.map.height, 1 do
                    Map.map.layers[i].world[locX][locY - Map.map.locOffsetY] = 0
                end
            end
        end
    end
    
    if params.rightBound then
        --right
        prevMapWidth = Map.map.width
        prevMapHeight = Map.map.height
        prevMapOX = Map.map.locOffsetX
        prevMapOY = Map.map.locOffsetY
        local prevWidth = Map.map.width
        local x = params.rightBound - (prevWidth - Map.map.locOffsetX)
        Map.map.width = Map.map.width + x
        
        for i = 1, #Map.map.layers, 1 do
            Map.map.layers[i].width = Map.map.layers[i].width + x
            for locX = (prevWidth - Map.map.locOffsetX) + 1, (Map.map.width - Map.map.locOffsetX), 1 do
                Map.map.layers[i].world[locX] = {}
                Map.tileObjects[i][locX] = {}
                if Map.map.layers[i].extendedObjects then
                    Map.map.layers[i].extendedObjects[locX] = {}
                end
                if Map.enableFlipRotation then
                    Map.map.layers[i].flipRotation[locX] = {}
                end
                for locY = 1, Map.map.height, 1 do
                    Map.map.layers[i].world[locX][locY - Map.map.locOffsetY] = 0
                end
            end
        end
    end
    
    if params.topBound then
        --top
        prevMapWidth = Map.map.width
        prevMapHeight = Map.map.height
        prevMapOX = Map.map.locOffsetX
        prevMapOY = Map.map.locOffsetY
        local prevOY = Map.map.locOffsetY
        local y = 1 - params.topBound
        Map.map.locOffsetY = Map.map.locOffsetY + y
        Map.map.height = Map.map.height + y
        
        for i = 1, #Map.map.layers, 1 do
            Map.map.layers[i].height = Map.map.layers[i].height + y
            for locX = 1, Map.map.width, 1 do
                for locY = 1 - Map.map.locOffsetY, 1 - prevOY - 1, 1 do
                    Map.map.layers[i].world[locX - Map.map.locOffsetX][locY] = 0
                end
            end
        end
    end
    
    if params.bottomBound then
        --bottom
        prevMapWidth = Map.map.width
        prevMapHeight = Map.map.height
        prevMapOX = Map.map.locOffsetX
        prevMapOY = Map.map.locOffsetY
        local prevHeight = Map.map.height
        local y = params.bottomBound - (prevHeight - Map.map.locOffsetY)
        Map.map.height = Map.map.height + y
        
        for i = 1, #Map.map.layers, 1 do
            Map.map.layers[i].height = Map.map.layers[i].height + y
            for locX = 1, Map.map.width, 1 do
                for locY = (prevHeight - Map.map.locOffsetY) + 1, (Map.map.height - Map.map.locOffsetY), 1 do
                    Map.map.layers[i].world[locX - Map.map.locOffsetX][locY] = 0
                end
            end
        end
    end
    
    -------------------------
    
    if params.pushLeft and params.pushLeft > 0 then
        --left
        prevMapWidth = Map.map.width
        prevMapHeight = Map.map.height
        prevMapOX = Map.map.locOffsetX
        prevMapOY = Map.map.locOffsetY
        local prevOX = Map.map.locOffsetX
        local x = params.pushLeft
        Map.map.locOffsetX = Map.map.locOffsetX + x
        Map.map.width = Map.map.width + x
        
        for i = 1, #Map.map.layers, 1 do
            Map.map.layers[i].width = Map.map.layers[i].width + x
            for locX = 1 - Map.map.locOffsetX, 1 - prevOX - 1, 1 do
                Map.map.layers[i].world[locX] = {}
                Map.tileObjects[i][locX] = {}
                if Map.map.layers[i].extendedObjects then
                    Map.map.layers[i].extendedObjects[locX] = {}
                end
                if Map.enableFlipRotation then
                    Map.map.layers[i].flipRotation[locX] = {}
                end
                for locY = 1, Map.map.height, 1 do
                    Map.map.layers[i].world[locX][locY - Map.map.locOffsetY] = 0
                end
            end
        end
    end
    
    if params.pushRight and params.pushRight > 0 then
        --right
        prevMapWidth = Map.map.width
        prevMapHeight = Map.map.height
        prevMapOX = Map.map.locOffsetX
        prevMapOY = Map.map.locOffsetY
        local prevWidth = Map.map.width
        local x = params.pushRight
        Map.map.width = Map.map.width + x
        
        for i = 1, #Map.map.layers, 1 do
            Map.map.layers[i].width = Map.map.layers[i].width + x
            --print((prevWidth - Map.map.locOffsetX) + 1, (Map.map.width - Map.map.locOffsetX))
            for locX = (prevWidth - Map.map.locOffsetX) + 1, (Map.map.width - Map.map.locOffsetX), 1 do
                Map.map.layers[i].world[locX] = {}
                Map.tileObjects[i][locX] = {}
                if Map.map.layers[i].extendedObjects then
                    Map.map.layers[i].extendedObjects[locX] = {}
                end
                if Map.enableFlipRotation then
                    Map.map.layers[i].flipRotation[locX] = {}
                end
                for locY = 1, Map.map.height, 1 do
                    Map.map.layers[i].world[locX][locY - Map.map.locOffsetY] = 0
                end
            end
        end
    end
    
    if params.pushUp and params.pushUp > 0 then
        --top
        prevMapWidth = Map.map.width
        prevMapHeight = Map.map.height
        prevMapOX = Map.map.locOffsetX
        prevMapOY = Map.map.locOffsetY
        local prevOY = Map.map.locOffsetY
        local y = params.pushUp
        Map.map.locOffsetY = Map.map.locOffsetY + y
        Map.map.height = Map.map.height + y
        
        for i = 1, #Map.map.layers, 1 do
            Map.map.layers[i].height = Map.map.layers[i].height + y
            for locX = 1, Map.map.width, 1 do
                for locY = 1 - Map.map.locOffsetY, 1 - prevOY - 1, 1 do
                    Map.map.layers[i].world[locX - Map.map.locOffsetX][locY] = 0
                end
            end
        end
    end
    
    if params.pushDown and params.pushDown > 0 then
        --bottom
        prevMapWidth = Map.map.width
        prevMapHeight = Map.map.height
        prevMapOX = Map.map.locOffsetX
        prevMapOY = Map.map.locOffsetY
        local prevHeight = Map.map.height
        local y = params.pushDown
        Map.map.height = Map.map.height + y
        
        for i = 1, #Map.map.layers, 1 do
            Map.map.layers[i].height = Map.map.layers[i].height + y
            for locX = 1, Map.map.width, 1 do
                for locY = (prevHeight - Map.map.locOffsetY) + 1, (Map.map.height - Map.map.locOffsetY), 1 do
                    Map.map.layers[i].world[locX - Map.map.locOffsetX][locY] = 0
                end
            end
        end
    end 
    
    
    if M.enableSpriteSorting then
        for i = 1, #Map.map.layers, 1 do
            if Map.map.layers[i].properties.spriteLayer then
                if Map.masterGroup[i][2].depthBuffer then
                    if Map.masterGroup[i][2].numChildren < Map.map.height * Map.spriteSortResolution then
                        for j = Map.masterGroup[i][2].numChildren, Map.map.height * Map.spriteSortResolution , 1 do
                            local temp = display.newGroup()
                            temp.layer = i
                            temp.isDepthBuffer = true
                            Map.masterGroup[i][2]:insert(temp)
                        end
                    end
                end
            end
        end
    end
    
    
    for i = 1, #Map.map.layers, 1 do
        for x = 1 - prevMapOX, prevMapWidth - prevMapOX, 1 do
            for y = 1 - prevMapOY, prevMapHeight - prevMapOY, 1 do
                if Map.map.layers[i].largeTiles[x] and Map.map.layers[i].largeTiles[x][y] then
                    for j = #Map.map.layers[i].largeTiles[x][y], 1, -1 do
                        local frameIndex = Map.map.layers[i].largeTiles[x][y][j][1]
                        local locX = Map.map.layers[i].largeTiles[x][y][j][2]
                        local locY = Map.map.layers[i].largeTiles[x][y][j][3]
                        
                        local frameIndex = frameIndex
                        local tileSetIndex = 1
                        for i = 1, #Map.map.tilesets, 1 do
                            if frameIndex >= Map.map.tilesets[i].firstgid then
                                tileSetIndex = i
                            else
                                break
                            end
                        end
                        local mT = Map.map.tilesets[tileSetIndex]
                        
                        local width = math.ceil(mT.tilewidth / Map.map.tilewidth)
                        local height = math.ceil(mT.tileheight / Map.map.tileheight)
                        
                        local left = locX
                        if left < 1 - prevMapOX then
                            left = left + prevMapWidth
                        end
                        if left > prevMapWidth - prevMapOX then
                            left = left - prevMapWidth
                        end		
                        
                        local top = locY - height + 1
                        if top < 1 - prevMapOY then
                            top = top + prevMapHeight
                        end
                        if top > prevMapHeight - prevMapOY then
                            top = top - prevMapHeight
                        end
                        
                        local right = locX + width - 1
                        if right < 1 - prevMapOX then
                            right = right + prevMapWidth
                        end
                        if right > prevMapWidth - prevMapOX then
                            right = right - prevMapWidth
                        end	
                        
                        local bottom = locY
                        if bottom < 1 - prevMapOY then
                            bottom = bottom + prevMapHeight
                        end
                        if bottom > prevMapHeight - prevMapOY then
                            bottom = bottom - prevMapHeight
                        end
                        
                        local aTop, aRight = nil, nil
                        if right < left then
                            aRight = right + prevMapWidth
                        end
                        if top > bottom then
                            aTop = top - prevMapHeight
                        end
                        
                        local lx, ly = x, y
                        
                        if lx < locX then
                            lx = lx + prevMapWidth
                        end
                        if ly > locY then
                            ly = ly - prevMapHeight
                        end
                        
                        --print(x, y, lx, ly)
                        
                        if lx ~= x or ly ~= y then
                            if not Map.map.layers[i].largeTiles[lx] then
                                Map.map.layers[i].largeTiles[lx] = {}
                            end
                            if not Map.map.layers[i].largeTiles[lx][ly] then
                                Map.map.layers[i].largeTiles[lx][ly] = {}
                            end
                            Map.map.layers[i].largeTiles[lx][ly][#Map.map.layers[i].largeTiles[lx][ly] + 1] = {frameIndex, locX, locY}
                            table.remove(Map.map.layers[i].largeTiles[x][y], j)
                        end
                        
                    end
                end
            end
        end
    end
    
    if cheese then
        for i = 1, #Map.map.layers, 1 do
            for x = 1 - Map.map.locOffsetX, Map.map.width - Map.map.locOffsetX, 1 do
                local lx = x
                if lx < 1 - prevMapOX then
                    lx = lx + prevMapWidth
                end
                if lx > prevMapWidth - prevMapOX then
                    lx = lx - prevMapWidth
                end				
                if Map.map.layers[i].largeTiles[lx] then
                    --print(1 - Map.map.locOffsetY, Map.map.height - Map.map.locOffsetY)
                    for y = 1 - Map.map.locOffsetY, Map.map.height - Map.map.locOffsetY, 1 do
                        local ly = y
                        if ly < 1 - prevMapOY then
                            ly = ly + prevMapHeight
                        end
                        if ly > prevMapHeight - prevMapOY then
                            ly = ly - prevMapHeight
                        end
                        --print(y)
                        if Map.map.layers[i].largeTiles[lx][ly] then
                            --print(lx, ly)
                            for j = 1, #Map.map.layers[i].largeTiles[lx][ly], 1 do
                                local frameIndex = Map.map.layers[i].largeTiles[lx][ly][j][1]
                                local locX = Map.map.layers[i].largeTiles[lx][ly][j][2]
                                local locY = Map.map.layers[i].largeTiles[lx][ly][j][3]
                                
                                
                                local frameIndex = frameIndex
                                local tileSetIndex = 1
                                for i = 1, #Map.map.tilesets, 1 do
                                    if frameIndex >= Map.map.tilesets[i].firstgid then
                                        tileSetIndex = i
                                    else
                                        break
                                    end
                                end
                                local mT = Map.map.tilesets[tileSetIndex]
                                
                                local width = math.ceil(mT.tilewidth / Map.map.tilewidth)
                                local height = math.ceil(mT.tileheight / Map.map.tileheight)
                                
                                local left = locX
                                if left < 1 - prevMapOX then
                                    left = left + prevMapWidth
                                end
                                if left > prevMapWidth - prevMapOX then
                                    left = left - prevMapWidth
                                end		
                                
                                local top = locY - height + 1
                                if top < 1 - prevMapOY then
                                    top = top + prevMapHeight
                                end
                                if top > prevMapHeight - prevMapOY then
                                    top = top - prevMapHeight
                                end
                                
                                local right = locX + width - 1
                                if right < 1 - prevMapOX then
                                    right = right + prevMapWidth
                                end
                                if right > prevMapWidth - prevMapOX then
                                    right = right - prevMapWidth
                                end	
                                
                                local bottom = locY
                                if bottom < 1 - prevMapOY then
                                    bottom = bottom + prevMapHeight
                                end
                                if bottom > prevMapHeight - prevMapOY then
                                    bottom = bottom - prevMapHeight
                                end
                                
                                
                                local aTop, aRight = nil, nil
                                if right < left then
                                    aRight = right + prevMapWidth
                                end
                                if top > bottom then
                                    aTop = top - prevMapHeight
                                end
                                if locX == 49 and locY == 1 then
                                    --print(lx, ly, locX, locY, prevMapWidth, prevMapHeight)
                                end
                                print(x, y, lx, ly, locX, locY, "-------------")
                                
                                
                            end
                        end
                    end
                end
            end
        end
    end
end

-----------------------------------------------------------

M.createLayer = function(layer)		
    --CREATE LAYER
    Map.map.layers[layer] = {}
    Map.map.layers[layer].properties = {}
    
    --CHECK AND LOAD SCALE AND LEVELS
    if not Map.map.layers[layer].properties then
        Map.map.layers[layer].properties = {}
        Map.map.layers[layer].properties.level = "1"
        Map.map.layers[layer].properties.scaleX = 1
        Map.map.layers[layer].properties.scaleY = 1
        Map.map.layers[layer].properties.parallaxX = 1
        Map.map.layers[layer].properties.parallaxY = 1
    else
        if not Map.map.layers[layer].properties.level then
            Map.map.layers[layer].properties.level = "1"
        end
        if Map.map.layers[layer].properties.scale then
            Map.map.layers[layer].properties.scaleX = Map.map.layers[layer].properties.scale
            Map.map.layers[layer].properties.scaleY = Map.map.layers[layer].properties.scale
        else
            if not Map.map.layers[layer].properties.scaleX then
                Map.map.layers[layer].properties.scaleX = 1
            end
            if not Map.map.layers[layer].properties.scaleY then
                Map.map.layers[layer].properties.scaleY = 1
            end
        end
    end
    Map.map.layers[layer].properties.scaleX = tonumber(Map.map.layers[layer].properties.scaleX)
    Map.map.layers[layer].properties.scaleY = tonumber(Map.map.layers[layer].properties.scaleY)
    if Map.map.layers[layer].properties.parallax then
        Map.map.layers[layer].parallaxX = Map.map.layers[layer].properties.parallax / Map.map.layers[layer].properties.scaleX
        Map.map.layers[layer].parallaxY = Map.map.layers[layer].properties.parallax / Map.map.layers[layer].properties.scaleY
    else
        if Map.map.layers[layer].properties.parallaxX then
            Map.map.layers[layer].parallaxX = Map.map.layers[layer].properties.parallaxX / Map.map.layers[layer].properties.scaleX
        else
            Map.map.layers[layer].parallaxX = 1
        end
        if Map.map.layers[layer].properties.parallaxY then
            Map.map.layers[layer].parallaxY = Map.map.layers[layer].properties.parallaxY / Map.map.layers[layer].properties.scaleY
        else
            Map.map.layers[layer].parallaxY = 1
        end
    end	
    --DETECT WIDTH AND HEIGHT
    Map.map.layers[layer].width = Map.map.layers[Map.refLayer].width
    Map.map.layers[layer].height = Map.map.layers[Map.refLayer].height
    if Map.map.layers[layer].properties.width then
        Map.map.layers[layer].width = tonumber(Map.map.layers[layer].properties.width)
    end
    if Map.map.layers[layer].properties.height then
        Map.map.layers[layer].height = tonumber(Map.map.layers[layer].properties.height)
    end
    --DETECT LAYER WRAP
    Camera.layerWrapX[layer] = Camera.worldWrapX
    Camera.layerWrapY[layer] = Camera.worldWrapY
    if Map.map.layers[layer].properties.wrap then
        if Map.map.layers[layer].properties.wrap == "true" then
            Camera.layerWrapX[layer] = true
            Camera.layerWrapY[layer] = true
        elseif Map.map.layers[layer].properties.wrap == "false" then
            Camera.layerWrapX[layer] = false
            Camera.layerWrapY[layer] = false
        end
    end
    if Map.map.layers[layer].properties.wrapX then
        if Map.map.layers[layer].properties.wrapX == "true" then
            Camera.layerWrapX[layer] = true
        elseif Map.map.layers[layer].properties.wrapX == "false" then
            Camera.layerWrapX[layer] = false
        end
    end
    if Map.map.layers[layer].properties.wrapY then
        if Map.map.layers[layer].properties.wrapY == "true" then
            Camera.layerWrapY[layer] = true
        elseif Map.map.layers[layer].properties.wrapY == "false" then
            Camera.layerWrapY[layer] = false
        end
    end
    --TOGGLE PARALLAX CROP
    if Map.map.layers[layer].properties.toggleParallaxCrop == "true" then
        Map.map.layers[layer].width = math.floor(Map.map.layers[layer].width * Map.map.layers[layer].parallaxX)
        Map.map.layers[layer].height = math.floor(Map.map.layers[layer].height * Map.map.layers[layer].parallaxY)
        if Map.map.layers[layer].width > Map.map.width then
            Map.map.layers[layer].width = Map.map.width
        end
        if Map.map.layers[layer].height > Map.map.height then
            Map.map.layers[layer].height = Map.map.height
        end
    end		
    --FIT BY PARALLAX / FIT BY SCALE
    if Map.map.layers[layer].properties.fitByParallax then
        Map.map.layers[layer].parallaxX = Map.map.layers[layer].width / Map.map.width
        Map.map.layers[layer].parallaxY = Map.map.layers[layer].height / Map.map.height
    else
        if Map.map.layers[layer].properties.fitByScale then
            Map.map.layers[layer].properties.scaleX = (Map.map.width * Map.map.layers[layer].properties.parallaxX) / Map.map.layers[layer].width
            Map.map.layers[layer].properties.scaleY = (Map.map.height * Map.map.layers[layer].properties.parallaxY) / Map.map.layers[layer].height
        end
    end
    if Camera.enableLighting then
        if not Map.map.layers[layer].lighting then
            Map.map.layers[layer].lighting = {}
        end
    end
    
    if Camera.enableLighting then
        for x = 1, Map.map.layers[layer].width, 1 do
            if Map.map.layers[layer].lighting then
                Map.map.layers[layer].lighting[x] = {}
            end
        end
    end
    
    Map.tileObjects[layer] = {}
    for x = 1, Map.map.layers[layer].width, 1 do
        Map.tileObjects[layer][x - Map.map.locOffsetX] = {}
    end
    
    Map.map.layers[layer].world = {}
    Map.map.layers[layer].largeTiles = {}
    if Map.enableFlipRotation then
        Map.map.layers[layer].flipRotation = {}
    end
    for x = 1, Map.map.width, 1 do
        Map.map.layers[layer].world[x - Map.map.locOffsetX] = {}
        if Map.enableFlipRotation then
            Map.map.layers[layer].flipRotation[x - Map.map.locOffsetX] = {}
        end
        for y = 1, Map.map.height, 1 do
            Map.map.layers[layer].world[x - Map.map.locOffsetX][y - Map.map.locOffsetY] = 0
        end
    end
    
    --CREATE DISPLAY GROUPS
    for k = Map.masterGroup.numChildren + 1, layer, 1 do
        if not Map.masterGroup[k] then
            local group = display.newGroup()
            Map.masterGroup:insert(group)
            local tiles = display.newGroup()
            tiles.tiles = true
            Map.masterGroup[k]:insert(tiles)
            Map.masterGroup[k].vars = {alpha = 1}
            Map.masterGroup[k].vars.layer = k	
            Map.masterGroup[k].x = Map.masterGroup[Map.refLayer].x
            Map.masterGroup[k].y = Map.masterGroup[Map.refLayer].y

            table.print(Map.materGroup[k]);
        end
    end
    
    if M.enableSpriteSorting then
        if Map.map.layers[layer].properties.spriteLayer then
            Map.masterGroup[layer].vars.depthBuffer = true
            local depthBuffer = display.newGroup()
            depthBuffer.depthBuffer = true
            Map.masterGroup[layer]:insert(depthBuffer)
            for j = 1, Map.map.height * Map.spriteSortResolution, 1 do
                local temp = display.newGroup()
                temp.layer = layer
                temp.isDepthBuffer = true
                Map.masterGroup[layer][2]:insert(temp)
            end
        end
    end			
    
    local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
    local cameraX, cameraY = Map.masterGroup[layer]:contentToLocal(tempX, tempY)
    local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
    local cameraLocY = math.ceil(cameraY / Map.map.tileheight)
    
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
end

-----------------------------------------------------------

M.appendMap = function(src, dir, locX, locY, layer, overwrite)
    local layer = layer
    if not layer then
        layer = 1
    end
    Xml.src = src
    local srcString = Xml.src
    local directory = ""
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
        directory = string.sub(srcString, 1, slashes[#slashes])
    else
        srcStringExt = srcString
    end
    if #periods > 0 then
        if periods[#periods] >= length - 6 then
            srcString = string.sub(srcString, (slashes[#slashes] or 0) + 1, (periods[#periods] or 0) - 1)
        else
            srcString = srcStringExt
        end
    else
        srcString = srcStringExt
    end
    local detectJsonExt = string.find(srcStringExt, ".json")
    if string.len(srcStringExt) ~= string.len(srcString) then
        if not detectJsonExt then
            --print("ERROR: "..Xml.src.." is not a Json file.")
        end
    else
        Xml.src = Xml.src..".json"
        detectJsonExt = true
    end	
    local path
    local base
    if dir == "Documents" then
        debugText = "Directory = DocumentsDirectory"
        path = system.pathForFile(Xml.src, system.DocumentsDirectory)
        base = system.DocumentsDirectory
    elseif dir == "Temporary" then
        debugText = "Directory = TemporaryDirectory"
        path = system.pathForFile(Xml.src, system.TemporaryDirectory)
        base = system.TemporaryDirectory
    elseif not dir or dir == "Resource" then
        debugText = "Directory = ResourceDirectory"
        path = system.pathForFile(Xml.src, system.ResourceDirectory)
        base = system.ResourceDirectory
    end	
    
    M.preloadMap(Xml.src, dir)
    
    --TILESETS
		--[[
		Loop through new Map.map's tilesets and compare to parent Map.map. If tileset already exists,
		adjust new maps tileID's to conform with the index of parent Map.map's tileset.
    ]]--
    if not Map.map.adjustGID[Xml.src] then
        Map.map.adjustGID[Xml.src] = {}
    end
    for i = 1, #Map.mapStorage[Xml.src].tilesets, 1 do			
        local detect = false
        for j = 1, #Map.map.tilesets, 1 do
            if Map.map.tilesets[j].name == Map.mapStorage[Xml.src].tilesets[i].name then
                detect = j
            end
        end
        
        if detect then
            --PROCESS TILE PROPERTIES
            if Map.mapStorage[Xml.src].tilesets[i].tileproperties then
                if not Map.map.tilesets[detect].tileproperties then
                    Map.map.tilesets[detect].tileproperties = Map.mapStorage[Xml.src].tilesets[i].tileproperties
                else
                    for key,value in pairs(Map.mapStorage[Xml.src].tilesets[i].tileproperties) do
                        if not Map.map.tilesets[detect].tileproperties[key] then
                            Map.map.tilesets[detect].tileproperties[key] = value
                        else
                            for key2,value2 in pairs(Map.mapStorage[Xml.src].tilesets[i].tileproperties[key]) do
                                if not Map.map.tilesets[detect].tileproperties[key][key2] then
                                    Map.map.tilesets[detect].tileproperties[key][key2] = value2
                                end
                            end
                        end
                    end
                end
            end
            
            if i ~= detect then
                local newFirstGID = Map.map.tilesets[detect].firstgid
                local oldFirstGID = Map.mapStorage[Xml.src].tilesets[i].firstgid
                
                local tempTileWidth = Map.map.tilesets[detect].tilewidth + (Map.map.tilesets[detect].spacing)
                local tempTileHeight = Map.map.tilesets[detect].tileheight + (Map.map.tilesets[detect].spacing)
                local numFrames = math.floor(Map.map.tilesets[detect].imagewidth / tempTileWidth) * math.floor(Map.map.tilesets[detect].imageheight / tempTileHeight)
                
                Map.map.adjustGID[Xml.src][#Map.map.adjustGID[Xml.src] + 1] = {oldFirstGID, oldFirstGID + numFrames - 1, newFirstGID - oldFirstGID}
            end
            
        else
            --add tileset to table
            local tempTileWidth = Map.map.tilesets[#Map.map.tilesets].tilewidth + (Map.map.tilesets[#Map.map.tilesets].spacing)
            local tempTileHeight = Map.map.tilesets[#Map.map.tilesets].tileheight + (Map.map.tilesets[#Map.map.tilesets].spacing)
            local numFrames = math.floor(Map.map.tilesets[#Map.map.tilesets].imagewidth / tempTileWidth) * math.floor(Map.map.tilesets[#Map.map.tilesets].imageheight / tempTileHeight)
            local newFirstGID = Map.map.tilesets[#Map.map.tilesets].firstgid + numFrames
            
            local tempTileWidth = Map.mapStorage[Xml.src].tilesets[i].tilewidth + (Map.mapStorage[Xml.src].tilesets[i].spacing)
            local tempTileHeight = Map.mapStorage[Xml.src].tilesets[i].tileheight + (Map.mapStorage[Xml.src].tilesets[i].spacing)
            local oldFirstGID = Map.mapStorage[Xml.src].tilesets[i].firstgid
            local oldNumFrames = math.floor(Map.mapStorage[Xml.src].tilesets[i].imagewidth / tempTileWidth) * math.floor(Map.mapStorage[Xml.src].tilesets[i].imageheight / tempTileHeight)
            
            Map.map.adjustGID[Xml.src][#Map.map.adjustGID[Xml.src] + 1] = {oldFirstGID, oldFirstGID + oldNumFrames - 1, newFirstGID - oldFirstGID}
            
            Map.map.tilesets[#Map.map.tilesets + 1] = Map.mapStorage[Xml.src].tilesets[i]
            loadTileSet(#Map.map.tilesets)
            Map.map.tilesets[#Map.map.tilesets].firstgid = newFirstGID
            
            --PROCESS TILE PROPERTIES
            if Map.map.tilesets[#Map.map.tilesets].tileproperties then
                local tileProps = Map.map.tilesets[#Map.map.tilesets].tileproperties
                for key,value in pairs(tileProps) do
                    local tileProps2 = tileProps[key]
                    for key2,value2 in pairs(tileProps[key]) do					
                        if key2 == "animFrames" then
                            tileProps2["animFrames"] = json.decode(value2)
                            local tempFrames = json.decode(value2)
                            if tileProps2["animFrameSelect"] == "relative" then
                                local frames = {}
                                for f = 1, #tempFrames, 1 do
                                    frames[f] = (tonumber(key) + 1) + tempFrames[f]
                                end
                                tileProps2["sequenceData"] = {
                                    name="null",
                                    frames=frames,
                                    time = tonumber(tileProps2["animDelay"]),
                                    loopCount = 0
                                }
                            elseif tileProps2["animFrameSelect"] == "absolute" then
                                tileProps2["sequenceData"] = {
                                    name="null",
                                    frames=tempFrames,
                                    time = tonumber(tileProps2["animDelay"]),
                                    loopCount = 0
                                }
                            end
                            tileProps2["animSync"] = tonumber(tileProps2["animSync"]) or 1
                            if not Core.syncData[tileProps2["animSync"] ] then
                                Core.syncData[tileProps2["animSync"] ] = {}
                                Core.syncData[tileProps2["animSync"] ].time = (tileProps2["sequenceData"].time / #tileProps2["sequenceData"].frames) / Map.frameTime
                                Core.syncData[tileProps2["animSync"] ].currentFrame = 1
                                Core.syncData[tileProps2["animSync"] ].counter = Core.syncData[tileProps2["animSync"] ].time
                                Core.syncData[tileProps2["animSync"] ].frames = tileProps2["sequenceData"].frames
                            end
                        end
                        if key2 == "shape" then
                            tileProps2["shape"] = json.decode(value2)
                        end
                        if key2 == "filter" then
                            tileProps2["filter"] = json.decode(value2)
                        end
                        if key2 == "opacity" then					
                            frameIndex = tonumber(key) + (Map.map.tilesets[#Map.map.tilesets].firstgid - 1) + 1
                            
                            if not Map.map.lightingData[frameIndex] then
                                Map.map.lightingData[frameIndex] = {}
                            end
                            Map.map.lightingData[frameIndex].opacity = json.decode(value2)
                        end
                    end
                end
            end		
            if not Map.map.tilesets[#Map.map.tilesets].properties then
                Map.map.tilesets[#Map.map.tilesets].properties = {}
            end			
            if Map.map.tilesets[#Map.map.tilesets].properties.normalMapSet then
                local tempTileWidth = Map.map.tilesets[#Map.map.tilesets].tilewidth + (Map.map.tilesets[#Map.map.tilesets].spacing)
                local tempTileHeight = Map.map.tilesets[#Map.map.tilesets].tileheight + (Map.map.tilesets[#Map.map.tilesets].spacing)
                local numFrames = math.floor(Map.map.tilesets[#Map.map.tilesets].imagewidth / tempTileWidth) * math.floor(Map.map.tilesets[#Map.map.tilesets].imageheight / tempTileHeight)
                local options = {width = Map.map.tilesets[#Map.map.tilesets].tilewidth, 
                    height = Map.map.tilesets[#Map.map.tilesets].tileheight, 
                    numFrames = numFrames, 
                    border = Map.map.tilesets[#Map.map.tilesets].margin,
                    sheetContentWidth = Map.map.tilesets[#Map.map.tilesets].imagewidth, 
                    sheetContentHeight = Map.map.tilesets[#Map.map.tilesets].imageheight
                }
                Xml.src = Map.map.tilesets[#Map.map.tilesets].properties.normalMapSet
                Map.normalSets[#Map.map.tilesets] = graphics.newImageSheet(Xml.src, options)
            end
            
        end
        
    end
    
    --Expand Map Bounds
    local storageWidth = Map.mapStorage[Xml.src].width
    local storageHeight = Map.mapStorage[Xml.src].height
    local storageOffsetX = Map.mapStorage[Xml.src].locOffsetX
    local storageOffsetY = Map.mapStorage[Xml.src].locOffsetY
    local left, top, right, bottom = 0, 0, 0, 0
    if locX < 1 - Map.map.locOffsetX then
        left = (1 - Map.map.locOffsetX) - locX
    end
    if locY < 1 - Map.map.locOffsetY then
        top = (1 - Map.map.locOffsetY) - locY
    end
    if locX + Map.mapStorage[Xml.src].width > Map.map.width - Map.map.locOffsetX then
        right = (locX + Map.mapStorage[Xml.src].width - 1) - (Map.map.width - Map.map.locOffsetX)
    end
    if locY + Map.mapStorage[Xml.src].height > Map.map.height - Map.map.locOffsetY then
        bottom = (locY + Map.mapStorage[Xml.src].height - 1) - (Map.map.height - Map.map.locOffsetY)
    end
    M.expandMapBounds({pushLeft = left, pushUp = top, pushRight = right, pushDown = bottom})
    
    for key,value in pairs(Map.mapStorage[Xml.src].properties) do
        if not Map.map.properties[key] then
            Map.map.properties[key] = value
        end
    end
    
    --LAYERS
		--[[
		Loop through new maps layers and transfer the data over to the current (base) maps
		layers, adjusting for different firstgid's of tilesets. Check for new properties
		and add to current (base) layers. Check for new objects if layer is objectLayer and 
		add to current (base) Map.objectLayers.
    ]]--
    local action = {}
    local numMapLayers = #Map.map.layers
    
    for i = #Map.mapStorage[Xml.src].layers + layer - 1, 1, - 1 do
        local newIndex = i
        action[newIndex] = {}
        if newIndex > #Map.map.layers and Map.mapStorage[Xml.src].layers[i + 1 - layer] then
            action[newIndex][1] = "add"
            --print(newIndex, "1")
        elseif newIndex > #Map.map.layers then
            M.createLayer(newIndex)
            --print(newIndex, "2")
        else
            --print(newIndex, "3")
            local mapLevel = tonumber(Map.map.layers[i].properties.level)
            local srcLevel = tonumber(Map.mapStorage[Xml.src].layers[i + 1 - layer].properties.level) or 1
            if srcLevel > mapLevel then
                local newLayers = 0
                for j = i + 1 - layer, 1 + 1 - layer, -1 do
                    if Map.mapStorage[Xml.src].layers[j] and Map.mapStorage[Xml.src].layers[j].properties and Map.mapStorage[Xml.src].layers[j].properties.level and
                        tonumber(Map.mapStorage[Xml.src].layers[j].properties.level) > tonumber(Map.map.layers[#Map.map.layers].properties.level) then
                        newLayers = newLayers + 1
                    end
                end
                local newLayer = #Map.map.layers + newLayers
                --action[newIndex] = {"add", #Map.map.layers + newLayers}
                action[newIndex] = {"add", newLayer}
                local diff = newLayer - newIndex
                --print(diff)
                for j = newIndex + 1, #Map.mapStorage[Xml.src].layers + layer - 1, 1 do
                    --print(" "..j)
                    local temp1 = action[j][1]
                    local temp2 = action[j][2]
                    --print(j, temp1, temp2)
                    action[j][2] = j + diff
                end
                
            else
                action[newIndex][1] = "process"
            end
        end
        --print(newIndex, action[newIndex][1], action[newIndex][2])
    end
    
    
    for i = #Map.mapStorage[Xml.src].layers, 1, -1 do
        local newIndex = i + layer - 1
        if action[newIndex][1] == "process" then
            local newIndex = i + layer - 1
            if not Map.map.layers[newIndex] then
                Map.map.layers[newIndex] = {}
            end
            for key,value in pairs(Map.mapStorage[Xml.src].layers[i]) do
                if key == "properties" then
                    for key,value in pairs(Map.mapStorage[Xml.src].layers[i].properties) do
                        if not Map.map.layers[newIndex].properties then
                            Map.map.layers[newIndex].properties = {}
                        end
                        if not Map.map.layers[newIndex].properties[key] then
                            Map.map.layers[newIndex].properties[key] = value
                        end
                    end
                elseif key == "objects" then
                    local level = Map.map.layers[newIndex].properties.level					
                    local objectLayer = newIndex
                    if not Map.map.layers[newIndex].properties.objectLayer then
                        objectLayer = M.getObjectLayer(level)
                    end
                    
                    for j = 1, #Map.mapStorage[Xml.src].layers[i].objects, 1 do
                        Map.map.layers[objectLayer].objects[#Map.map.layers[objectLayer].objects + 1] = {}
                        for key,value in pairs(Map.mapStorage[Xml.src].layers[i].objects[j]) do
                            Map.map.layers[objectLayer].objects[#Map.map.layers[objectLayer].objects][key] = value
                            if key == "properties" then
                                Map.map.layers[objectLayer].objects[#Map.map.layers[objectLayer].objects].properties = {}
                                for key2,value2 in pairs(Map.mapStorage[Xml.src].layers[i].objects[j].properties) do
                                    Map.map.layers[objectLayer].objects[#Map.map.layers[objectLayer].objects].properties[key2] = value2
                                end
                            end
                        end
                        Map.map.layers[objectLayer].objects[#Map.map.layers[objectLayer].objects].x = Map.map.layers[objectLayer].objects[#Map.map.layers[objectLayer].objects].x + ((locX - 1) * Map.map.tilewidth)
                        Map.map.layers[objectLayer].objects[#Map.map.layers[objectLayer].objects].y = Map.map.layers[objectLayer].objects[#Map.map.layers[objectLayer].objects].y + ((locY - 1) * Map.map.tileheight)
                    end
                elseif key == "world" and #value > 1 and not Map.mapStorage[Xml.src].layers[i].objects then
                    local dataLayer = newIndex	
                    if Map.map.layers[newIndex].objects or not (Map.map.layers[newIndex].data or Map.map.layers[newIndex].world) then
                        dataLayer = Map.refLayer
                        for i = newIndex, 1, -1 do
                            if (Map.map.layers[i].data or Map.map.layers[i].world) and not Map.map.layers[i].objects then
                                dataLayer = i
                                break
                            end
                        end
                    end
                    
                    for x = locX, locX + storageWidth - 1, 1 do
                        local lx = x - locX + 1 - (Map.mapStorage[Xml.src].locOffsetX or 0)
                        for y = locY, locY + storageHeight - 1, 1 do
                            local ly = y - locY + 1 - (Map.mapStorage[Xml.src].locOffsetY or 0)
                            
                            if Map.map.layers[dataLayer].world[x][y] == 0 or overwrite then
                                --print(lx, ly, x, y, (Map.mapStorage[Xml.src].locOffsetX or 0))
                                Map.map.layers[dataLayer].world[x][y] = Map.mapStorage[Xml.src].layers[i].world[lx][ly]
                            end
                            
                            for k = 1, #Map.map.adjustGID[Xml.src], 1 do
                                if Map.map.layers[dataLayer].world[x][y] >= Map.map.adjustGID[Xml.src][k][1] and Map.map.layers[dataLayer].world[x][y] <= Map.map.adjustGID[Xml.src][k][2] then
                                    Map.map.layers[dataLayer].world[x][y] = Map.map.layers[dataLayer].world[x][y] + Map.map.adjustGID[Xml.src][k][3]
                                    break
                                end
                            end
                            
                            if Map.enableFlipRotation then
                                Map.map.layers[dataLayer].flipRotation[x][y] = Map.mapStorage[Xml.src].layers[i].flipRotation[lx][ly]
                            end
                            
                            --find static lights
                            if Camera.enableLighting then
                                for key,value in pairs(Map.mapStorage[Xml.src].lights) do
                                    Map.map.lights[Light.lightIDs] = value
                                    Light.lightIDs = Light.lightIDs + 1
                                end
                            end
                        end
                    end
                end
                --------------
            end
        elseif action[newIndex][1] == "add" then
            local newIndex = newIndex
            if action[newIndex][2] then
                newIndex = action[newIndex][2]
            end
            
            M.createLayer(newIndex)
            for key,value in pairs(Map.mapStorage[Xml.src].layers[i]) do
                if type(value) ~= "table" then
                    Map.map.layers[newIndex][key] = value
                end
            end
            Map.map.layers[newIndex].width = Map.map.layers[Map.refLayer].width
            Map.map.layers[newIndex].height = Map.map.layers[Map.refLayer].height
            
            if Map.mapStorage[Xml.src].layers[i].properties then
                for key,value in pairs(Map.mapStorage[Xml.src].layers[i].properties) do
                    Map.map.layers[newIndex].properties[key] = value
                end
            end
            
            if Map.mapStorage[Xml.src].layers[i].objects then
                Map.map.layers[newIndex].objects = {}
                for key,value in pairs(Map.mapStorage[Xml.src].layers[i].objects) do
                    Map.map.layers[newIndex].objects[key] = value
                end
                Map.map.layers[newIndex].properties.objectLayer = true
            end
            
            if not Map.map.layers[newIndex].properties.objectLayer then
                for x = locX, locX + storageWidth - 1, 1 do
                    local lx = x - locX + 1
                    for y = locY, locY + storageHeight - 1, 1 do
                        local ly = y - locY + 1
                        if Map.map.layers[newIndex].world[x][y] == 0 then
                            Map.map.layers[newIndex].world[x][y] = Map.mapStorage[Xml.src].layers[i].world[lx][ly]
                        end
                        
                        for k = 1, #Map.map.adjustGID[Xml.src], 1 do
                            if Map.map.layers[newIndex].world[x][y] >= Map.map.adjustGID[Xml.src][k][1] and Map.map.layers[newIndex].world[x][y] <= Map.map.adjustGID[Xml.src][k][2] then
                                Map.map.layers[newIndex].world[x][y] = Map.map.layers[newIndex].world[x][y] + Map.map.adjustGID[Xml.src][k][3]
                                break
                            end
                        end
                        
                        if Map.enableFlipRotation then
                            Map.map.layers[newIndex].flipRotation[x][y] = Map.mapStorage[Xml.src].layers[i].flipRotation[lx][ly]
                        end
                        
                        --find static lights
                        if Camera.enableLighting then
                            for key,value in pairs(Map.mapStorage[Xml.src].lights) do
                                Map.map.lights[Light.lightIDs] = value
                                Light.lightIDs = Light.lightIDs + 1
                            end
                        end
                    end
                end
            end
            -----
        end
    end	
    
    Map.setMapProperties(Map.map.properties)
    --for i = 1, #Map.map.layers, 1 do
    M.setLayerProperties(layer, Map.map.layers[layer].properties)
    --end
end

-----------------------------------------------------------

M.loadMap = function(src, dir, unload)
    Xml.src = src
    local startTime=system.getTimer()
    for key,value in pairs(Sprites.sprites) do
        Sprites.removeSprite(value)
    end
    if Map.masterGroup then
        if Map.map.orientation == Map.Type.Isometric then
            if Map.isoSort == 1 then
                for i = Map.masterGroup.numChildren, 1, -1 do
                    for j = Map.map.height + Map.map.width, 1, -1 do
                        if Map.masterGroup[i][j][1].tiles then
                            for k = Map.masterGroup[i][j][1].numChildren, 1, -1 do
                                local locX = Map.masterGroup[i][j][1][k].locX
                                local locY = Map.masterGroup[i][j][1][k].locY
                                Map.tileObjects[i][locX][locY]:removeSelf()
                                Map.tileObjects[i][locX][locY] = nil
                            end
                        end
                        Map.masterGroup[i][j]:removeSelf()
                        Map.masterGroup[i][j] = nil
                    end
                    Map.masterGroup[i]:removeSelf()
                    Map.masterGroup[i] = nil
                end
            end
        else
            for i = Map.masterGroup.numChildren, 1, -1 do
                if Map.masterGroup[i][1].tiles then
                    for j = Map.masterGroup[i][1].numChildren, 1, -1 do
                        local locX = Map.masterGroup[i][1][j].locX
                        local locY = Map.masterGroup[i][1][j].locY
                        Map.tileObjects[i][locX][locY]:removeSelf()
                        Map.tileObjects[i][locX][locY] = nil
                    end
                end
                if Map.masterGroup[i].vars.depthBuffer then
                    for j = Map.masterGroup[i].numChildren, 1, -1 do
                        Map.masterGroup[i][j]:removeSelf()
                        Map.masterGroup[i][j] = nil
                    end
                end
                Map.masterGroup[i]:removeSelf()
                Map.masterGroup[i] = nil
            end
        end
    end
    
    
    
    if unload and source then
        Map.mapStorage[source] = nil
    end	
    Map.tileSets = {}
    Map.map = {}		
    Map.spriteLayers = {}
    Core.syncData = {}
    Map.animatedTiles = {}
    Map.refLayer = nil	
    local storageToggle = false	
    local srcString = Xml.src
    local directory = ""
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
        directory = string.sub(srcString, 1, slashes[#slashes])
    else
        srcStringExt = srcString
    end
    if #periods > 0 then
        if periods[#periods] >= length - 6 then
            srcString = string.sub(srcString, (slashes[#slashes] or 0) + 1, (periods[#periods] or 0) - 1)
        else
            srcString = srcStringExt
        end
    else
        srcString = srcStringExt
    end
    local detectJsonExt = string.find(srcStringExt, ".json")
    if string.len(srcStringExt) ~= string.len(srcString) then
        if not detectJsonExt then
            --print("ERROR: "..Xml.src.." is not a Json file.")
        end
    else
        Xml.src = Xml.src..".json"
        detectJsonExt = true
    end	
    local path
    local base
    if dir == "Documents" then
        source = Xml.src
        debugText = "Directory = DocumentsDirectory"
        path = system.pathForFile(Xml.src, system.DocumentsDirectory)
        debugText = "Path to file = "..path
        base = system.DocumentsDirectory
    elseif dir == "Temporary" then
        source = Xml.src
        debugText = "Directory = TemporaryDirectory"
        path = system.pathForFile(Xml.src, system.TemporaryDirectory)
        debugText = "Path to file = "..path
        base = system.TemporaryDirectory
    elseif not dir or dir == "Resource" then
        source = Xml.src
        debugText = "Directory = ResourceDirectory"
        path = system.pathForFile(Xml.src, system.ResourceDirectory)
        debugText = "Path to file = "..path	
        base = system.ResourceDirectory
    end		
    if detectJsonExt then
        --LOAD JSON FILE	
        local saveData = io.open(path, "r")
        debugText = "saveData stream opened"
        if saveData then
            local jsonData = saveData:read("*a")
            debugText = "jsonData read"
            
            if not Map.mapStorage[Xml.src] then
                Map.mapStorage[Xml.src] = json.decode(jsonData)
                Map.map = Map.mapStorage[Xml.src]
            else
                Map.map = Map.mapStorage[Xml.src]
                storageToggle = true
            end
            
            debugText = "jsonData decoded"
            io.close(saveData)
            debugText = "io stream closed"
            print(Xml.src.." loaded")
            debugText = Xml.src.." loaded"
            Map.mapPath = source
        else
            print("ERROR: Map Not Found")
            debugText = "ERROR: Map Not Found"
        end
    else
        if not Map.mapStorage[Xml.src] then
            ------------------------------------------------------------------------------
            
            
            ------------------------------------------------------------------------------
            --LOAD TMX FILE
            local temp = Xml.loadFile(source, base)
            if temp then
                for key,value in pairs(temp.properties) do
                    Map.mapStorage[Xml.src][key] = value
                    if key == "height" or key == "tileheight" or key == "tilewidth" or key == "width" then
                        Map.mapStorage[Xml.src][key] = tonumber(Map.mapStorage[Xml.src][key])
                    end
                end
                Map.mapStorage[Xml.src].tilesets = {}
                Map.mapStorage[Xml.src].properties = {}
                local layerIndex = 1
                local tileSetIndex = 1
                
                for i = 1, #temp.child, 1 do
                    if temp.child[i].name == "properties" then
                        for j = 1, #temp.child[i].child, 1 do
                            Map.mapStorage[Xml.src].properties[temp.child[i].child[j].properties.name] = temp.child[i].child[j].properties.value
                        end
                    end
                    
                    if temp.child[i].name == "imagelayer" then
                        for key,value in pairs(temp.child[i].properties) do
                            Map.mapStorage[Xml.src].layers[layerIndex][key] = value
                            if key == "width" or key == "height" then
                                Map.mapStorage[Xml.src].layers[layerIndex][key] = tonumber(Map.mapStorage[Xml.src].layers[layerIndex][key])
                            end
                        end
                        for j = 1, #temp.child[i].child, 1 do
                            if temp.child[i].child[j].name == "properties" then
                                for k = 1, #temp.child[i].child[j].child, 1 do
                                    Map.mapStorage[Xml.src].layers[layerIndex].properties[temp.child[i].child[j].child[k].properties.name] = temp.child[i].child[j].child[k].properties.value
                                end
                            end
                            
                            if temp.child[i].child[j].name == "image" then 
                                Map.mapStorage[Xml.src].layers[layerIndex]["image"] = temp.child[i].child[j].properties["source"]
                            end
                        end
                        
                        layerIndex = layerIndex + 1
                    end
                    
                    if temp.child[i].name == "layer" then
                        for key,value in pairs(temp.child[i].properties) do
                            Map.mapStorage[Xml.src].layers[layerIndex][key] = value
                            if key == "width" or key == "height" then
                                Map.mapStorage[Xml.src].layers[layerIndex][key] = tonumber(Map.mapStorage[Xml.src].layers[layerIndex][key])
                            end
                        end
                        for j = 1, #temp.child[i].child, 1 do
                            if temp.child[i].child[j].name == "properties" then
                                for k = 1, #temp.child[i].child[j].child, 1 do
                                    Map.mapStorage[Xml.src].layers[layerIndex].properties[temp.child[i].child[j].child[k].properties.name] = temp.child[i].child[j].child[k].properties.value
                                end
                            end
                        end
                        layerIndex = layerIndex + 1
                    end
                    
                    if temp.child[i].name == "objectgroup" then
                        for key,value in pairs(temp.child[i].properties) do
                            Map.mapStorage[Xml.src].layers[layerIndex][key] = value
                            if key == "width" or key == "height" then
                                Map.mapStorage[Xml.src].layers[layerIndex][key] = tonumber(Map.mapStorage[Xml.src].layers[layerIndex][key])
                            end
                        end
                        Map.mapStorage[Xml.src].layers[layerIndex]["width"] = Map.mapStorage[Xml.src]["width"]
                        Map.mapStorage[Xml.src].layers[layerIndex]["height"] = Map.mapStorage[Xml.src]["height"]
                        Map.mapStorage[Xml.src].layers[layerIndex].objects = {}
                        local firstObject = true
                        local indexMod = 0
                        for j = 1, #temp.child[i].child, 1 do
                            if temp.child[i].child[j].name == "properties" then
                                for k = 1, #temp.child[i].child[j].child, 1 do
                                    Map.mapStorage[Xml.src].layers[layerIndex].properties[temp.child[i].child[j].child[k].properties.name] = temp.child[i].child[j].child[k].properties.value
                                end
                            end
                            if temp.child[i].child[j].name == "object" then
                                if firstObject then
                                    firstObject = false
                                    indexMod = j - 1
                                end
                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod] = {}
                                for key,value in pairs(temp.child[i].child[j].properties) do
                                    Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod][key] = value
                                    if key == "width" or key == "height" or key == "x" or key == "y" or key == "gid" then
                                        Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod][key] = tonumber(Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod][key])
                                    end
                                end	
                                if not Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].width then
                                    Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].width = 0
                                end				
                                if not Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].height then
                                    Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].height = 0
                                end	
                                --------
                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].properties = {}
                                
                                for k = 1, #temp.child[i].child[j].child, 1 do
                                    if temp.child[i].child[j].child[k].name == "properties" then
                                        for m = 1, #temp.child[i].child[j].child[k].child, 1 do	
                                            Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].properties[temp.child[i].child[j].child[k].child[m].properties.name] = temp.child[i].child[j].child[k].child[m].properties.value								
                                        end
                                    end
                                    if temp.child[i].child[j].child[k].name == "polygon" then
                                        Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polygon = {}
                                        local pointString = temp.child[i].child[j].child[k].properties.points
                                        local codes = {string.byte(","), string.byte(" ")}
                                        local stringIndexStart = 1
                                        local pointIndex = 1
                                        
                                        for s = 1, string.len(pointString), 1 do
                                            if string.byte(pointString, s, s) == codes[1] then
                                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polygon[pointIndex] = {}
                                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polygon[pointIndex].x = tonumber(string.sub(pointString, stringIndexStart, s - 1))
                                                stringIndexStart = s + 1
                                            end
                                            if string.byte(pointString, s, s) == codes[2] then
                                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polygon[pointIndex].y = tonumber(string.sub(pointString, stringIndexStart, s - 1))
                                                stringIndexStart = s + 1
                                                pointIndex = pointIndex + 1
                                            end
                                            if s == string.len(pointString) then
                                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polygon[pointIndex].y = tonumber(string.sub(pointString, stringIndexStart, s))
                                            end
                                        end
                                    end
                                    if temp.child[i].child[j].child[k].name == "polyline" then
                                        Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polyline = {}
                                        local pointString = temp.child[i].child[j].child[k].properties.points
                                        local codes = {string.byte(","), string.byte(" ")}
                                        local stringIndexStart = 1
                                        local pointIndex = 1
                                        
                                        for s = 1, string.len(pointString), 1 do
                                            if string.byte(pointString, s, s) == codes[1] then
                                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polyline[pointIndex] = {}
                                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polyline[pointIndex].x = tonumber(string.sub(pointString, stringIndexStart, s - 1))
                                                stringIndexStart = s + 1
                                            end
                                            if string.byte(pointString, s, s) == codes[2] then
                                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polyline[pointIndex].y = tonumber(string.sub(pointString, stringIndexStart, s - 1))
                                                stringIndexStart = s + 1
                                                pointIndex = pointIndex + 1
                                            end
                                            if s == string.len(pointString) then
                                                Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].polyline[pointIndex].y = tonumber(string.sub(pointString, stringIndexStart, s))
                                            end
                                        end
                                    end
                                    if temp.child[i].child[j].child[k].name == "ellipse" then
                                        Map.mapStorage[Xml.src].layers[layerIndex].objects[j-indexMod].ellipse = true
                                    end
                                end
                            end
                        end
                        layerIndex = layerIndex + 1
                    end
                    
                    if temp.child[i].name == "tileset" then
                        Map.mapStorage[Xml.src].tilesets[tileSetIndex] = {}
                        
                        if temp.child[i].properties.source then
                            local tempSet = Xml.loadFile(directory..temp.child[i].properties.source, base)
                            if not tempSet.properties.spacing then 
                                tempSet.properties.spacing = 0
                            end
                            if not tempSet.properties.margin then
                                tempSet.properties.margin = 0
                            end
                            for key,value in pairs(tempSet.properties) do
                                Map.mapStorage[Xml.src].tilesets[tileSetIndex][key] = value
                                if key == "tilewidth" or key == "tileheight" or key == "spacing" or key == "margin" then
                                    Map.mapStorage[Xml.src].tilesets[tileSetIndex][key] = tonumber(Map.mapStorage[Xml.src].tilesets[tileSetIndex][key])
                                end
                            end
                            
                            
                            for j = 1, #tempSet.child, 1 do
                                if tempSet.child[j].name == "properties" then
                                    Map.mapStorage[Xml.src].tilesets[tileSetIndex].properties = {}
                                    for k = 1, #tempSet.child[j].child, 1 do
                                        Map.mapStorage[Xml.src].tilesets[tileSetIndex].properties[tempSet.child[j].child[k].properties.name] = tempSet.child[j].child[k].properties.value
                                    end
                                end
                                if tempSet.child[j].name == "image" then
                                    for key,value in pairs(tempSet.child[j].properties) do
                                        if key == "source" then
                                            Map.mapStorage[Xml.src].tilesets[tileSetIndex]["image"] = directory..value
                                        elseif key == "width" then
                                            Map.mapStorage[Xml.src].tilesets[tileSetIndex]["imagewidth"] = tonumber(value)
                                        elseif key == "height" then
                                            Map.mapStorage[Xml.src].tilesets[tileSetIndex]["imageheight"] = tonumber(value)
                                        else
                                            Map.mapStorage[Xml.src].tilesets[tileSetIndex][key] = value
                                        end															
                                    end									
                                end
                                if tempSet.child[j].name == "tile" then
                                    if not Map.mapStorage[Xml.src].tilesets[tileSetIndex].tileproperties then
                                        Map.mapStorage[Xml.src].tilesets[tileSetIndex].tileproperties = {}
                                    end
                                    Map.mapStorage[Xml.src].tilesets[tileSetIndex].tileproperties[tempSet.child[j].properties.id] = {}
                                    
                                    for k = 1, #tempSet.child[j].child, 1 do
                                        if tempSet.child[j].child[k].name == "properties" then
                                            for m = 1, #tempSet.child[j].child[k].child, 1 do
                                                local name = tempSet.child[j].child[k].child[m].properties.name
                                                local value = tempSet.child[j].child[k].child[m].properties.value
                                                Map.mapStorage[Xml.src].tilesets[tileSetIndex].tileproperties[tempSet.child[j].properties.id][name] = value
                                            end
                                        end
                                    end
                                end
                            end							
                        else
                            local tempSet = temp.child[i]
                            if not tempSet.properties.spacing then 
                                tempSet.properties.spacing = 0
                            end
                            if not tempSet.properties.margin then
                                tempSet.properties.margin = 0
                            end
                            for key,value in pairs(tempSet.properties) do
                                Map.mapStorage[Xml.src].tilesets[tileSetIndex][key] = value
                                if key == "tilewidth" or key == "tileheight" or key == "spacing" or key == "margin" then
                                    Map.mapStorage[Xml.src].tilesets[tileSetIndex][key] = tonumber(Map.mapStorage[Xml.src].tilesets[tileSetIndex][key])
                                end
                            end							
                            
                            for j = 1, #tempSet.child, 1 do
                                if tempSet.child[j].name == "properties" then
                                    Map.mapStorage[Xml.src].tilesets[tileSetIndex].properties = {}
                                    for k = 1, #tempSet.child[j].child, 1 do
                                        Map.mapStorage[Xml.src].tilesets[tileSetIndex].properties[tempSet.child[j].child[k].properties.name] = tempSet.child[j].child[k].properties.value
                                    end
                                end
                                if tempSet.child[j].name == "image" then
                                    for key,value in pairs(tempSet.child[j].properties) do
                                        if key == "source" then
                                            Map.mapStorage[Xml.src].tilesets[tileSetIndex]["image"] = directory..value
                                        elseif key == "width" then
                                            Map.mapStorage[Xml.src].tilesets[tileSetIndex]["imagewidth"] = tonumber(value)
                                        elseif key == "height" then
                                            Map.mapStorage[Xml.src].tilesets[tileSetIndex]["imageheight"] = tonumber(value)
                                        else
                                            Map.mapStorage[Xml.src].tilesets[tileSetIndex][key] = value
                                        end															
                                    end									
                                end
                                if tempSet.child[j].name == "tile" then
                                    if not Map.mapStorage[Xml.src].tilesets[tileSetIndex].tileproperties then
                                        Map.mapStorage[Xml.src].tilesets[tileSetIndex].tileproperties = {}
                                    end
                                    Map.mapStorage[Xml.src].tilesets[tileSetIndex].tileproperties[tempSet.child[j].properties.id] = {}
                                    
                                    for k = 1, #tempSet.child[j].child, 1 do
                                        if tempSet.child[j].child[k].name == "properties" then
                                            for m = 1, #tempSet.child[j].child[k].child, 1 do
                                                local name = tempSet.child[j].child[k].child[m].properties.name
                                                local value = tempSet.child[j].child[k].child[m].properties.value
                                                Map.mapStorage[Xml.src].tilesets[tileSetIndex].tileproperties[tempSet.child[j].properties.id][name] = value
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        Map.mapStorage[Xml.src].tilesets[tileSetIndex].firstgid = tonumber(temp.child[i].properties.firstgid)
                        tileSetIndex = tileSetIndex + 1
                    end
                end
            else
                print("ERROR: Map Not Found")
                debugText = "ERROR: Map Not Found"
            end
            
            Map.map = Map.mapStorage[Xml.src]				
        else
            Map.map = Map.mapStorage[Xml.src]				
            storageToggle = true
        end		
    end
    
    if not Map.map.isoRatio then
        Map.map.isoRatio = Map.map.tilewidth / Map.map.tileheight
    end
    if not Map.map.locOffsetX then
        Map.map.locOffsetX = 0
    end
    if not Map.map.locOffsetY then
        Map.map.locOffsetY = 0
    end
    if not Map.map.adjustGID then
        Map.map.adjustGID = {}
    end
    Map.map.width = Map.map.width
    Map.map.height = Map.map.height
    print("World Size X: "..Map.map.width)
    print("World Size Y: "..Map.map.height)
    Map.map.numLevels = 1		
    if Map.map.properties.defaultNormalMap then
        Map.map.defaultNormalMap = Map.map.properties.defaultNormalMap
    end
    if Map.map.properties.wrap then
        if Map.map.properties.wrap == "true" then
            Camera.worldWrapX = true
            Camera.worldWrapY = true
        elseif Map.map.properties.wrap == "false" then
            Camera.worldWrapX = false
            Camera.worldWrapY = false
        end
    end
    if Map.map.properties.wrapX then
        if Map.map.properties.wrapX == "true" then
            Camera.worldWrapX = true
        elseif Map.map.properties.wrapX == "false" then
            Camera.worldWrapX = false
        end
    end
    if Map.map.properties.wrapY then
        if Map.map.properties.wrapY == "true" then
            Camera.worldWrapY = true
        elseif Map.map.properties.wrapY == "false" then
            Camera.worldWrapY = false
        end
    end
    if not Map.map.modified then
        if Map.map.properties.lightLayerFalloff then
            Map.map.properties.lightLayerFalloff = json.decode(Map.map.properties.lightLayerFalloff)
        else
            Map.map.properties.lightLayerFalloff = {0, 0, 0}
        end
        if Map.map.properties.lightLevelFalloff then
            Map.map.properties.lightLevelFalloff = json.decode(Map.map.properties.lightLevelFalloff)
        else
            Map.map.properties.lightLevelFalloff = {1, 1, 1}
        end
    end
    local globalID = {}
    local prevLevel = "1"	
    Map.map.lightingData = {}
    if Camera.enableLighting then
        Map.map.lastLightUpdate = system.getTimer()
        if not Map.map.lights then
            Map.map.lights = {}
        end
    end		
    if not storageToggle then
        if not Map.map.modified then
            if Map.map.orientation == "orthogonal" then
                Map.map.orientation = Map.Type.Orthogonal
            elseif Map.map.orientation == "isometric" then
                Map.map.orientation = Map.Type.Isometric
            elseif Map.map.orientation == "staggered" then
                Map.map.orientation = Map.Type.Staggered
            end
        end
    end		
    worldScaleX = Map.map.tilewidth
    worldScaleY = Map.map.tileheight
    if Map.map.orientation == Map.Type.Isometric then
        if Map.isoSort == 1 then
            for i = 1, #Map.map.layers, 1 do
                local group = display.newGroup()
                Map.masterGroup:insert(group)
                Map.masterGroup[i].vars = {alpha = 1}
                Map.masterGroup[i].vars.layer = i
                for j = 1, Map.map.height + Map.map.width, 1 do
                    local row = display.newGroup()
                    row.layer = i
                    Map.masterGroup[i]:insert(row)
                    local tiles = display.newGroup()
                    tiles.tiles = true
                    Map.masterGroup[i][j]:insert(tiles)
                end
            end
        end
    else
        for i = 1, #Map.map.layers, 1 do
            local group = display.newGroup()
            Map.masterGroup:insert(group)
            local tiles = display.newGroup()
            tiles.tiles = true
            Map.masterGroup[i]:insert(tiles)
            Map.masterGroup[i].vars = {alpha = 1}
            Map.masterGroup[i].vars.layer = i		
            if M.enableSpriteSorting then
                if Map.map.layers[i].properties.spriteLayer then
                    Map.masterGroup[i].vars.depthBuffer = true
                    local depthBuffer = display.newGroup()
                    depthBuffer.depthBuffer = true
                    Map.masterGroup[i]:insert(depthBuffer)
                    for j = 1, Map.map.height * Map.spriteSortResolution, 1 do
                        local temp = display.newGroup()
                        temp.layer = i
                        temp.isDepthBuffer = true
                        Map.masterGroup[i][2]:insert(temp)
                    end
                end
            end
        end
    end
    
    --TILESETS
    Map.map.numFrames = {}
    for i = 1, #Map.map.tilesets, 1 do
        loadTileSet(i)	
        --PROCESS TILE PROPERTIES
        if Map.map.tilesets[i].tileproperties then
            local tileProps = Map.map.tilesets[i].tileproperties
            for key,value in pairs(tileProps) do
                local tileProps2 = tileProps[key]
                for key2,value2 in pairs(tileProps[key]) do					
                    if key2 == "animFrames" then
                        tempFrames = value2
                        if type(value2) == "string" then
                            tileProps2["animFrames"] = json.decode(value2)
                            tempFrames = json.decode(value2)
                        end
                        if tileProps2["animFrameSelect"] == "relative" then
                            local frames = {}
                            for f = 1, #tempFrames, 1 do
                                frames[f] = (tonumber(key) + 1) + tempFrames[f]
                            end
                            tileProps2["sequenceData"] = {
                                name="null",
                                frames=frames,
                                time = tonumber(tileProps2["animDelay"]),
                                loopCount = 0
                            }
                        elseif tileProps2["animFrameSelect"] == "absolute" then
                            tileProps2["sequenceData"] = {
                                name="null",
                                frames=tempFrames,
                                time = tonumber(tileProps2["animDelay"]),
                                loopCount = 0
                            }
                        end
                        tileProps2["animSync"] = tonumber(tileProps2["animSync"]) or 1
                        if not Core.syncData[tileProps2["animSync"] ] then
                            Core.syncData[tileProps2["animSync"] ] = {}
                            Core.syncData[tileProps2["animSync"] ].time = (tileProps2["sequenceData"].time / #tileProps2["sequenceData"].frames) / Map.frameTime
                            Core.syncData[tileProps2["animSync"] ].currentFrame = 1
                            Core.syncData[tileProps2["animSync"] ].counter = Core.syncData[tileProps2["animSync"] ].time
                            Core.syncData[tileProps2["animSync"] ].frames = tileProps2["sequenceData"].frames
                        end
                    end
                    if key2 == "shape" and type(value2) == "string" then
                        tileProps2["shape"] = json.decode(value2)
                    end
                    if key2 == "filter" and type(value2) == "string" then
                        tileProps2["filter"] = json.decode(value2)
                    end
                    if key2 == "opacity" then					
                        frameIndex = tonumber(key) + (Map.map.tilesets[i].firstgid - 1) + 1
                        
                        if not Map.map.lightingData[frameIndex] then
                            Map.map.lightingData[frameIndex] = {}
                        end
                        Map.map.lightingData[frameIndex].opacity = json.decode(value2)
                    end
                end
            end
        end		
        if not Map.map.tilesets[i].properties then
            Map.map.tilesets[i].properties = {}
        end			
        if Map.map.tilesets[i].properties.normalMapSet then
            local tempTileWidth = Map.map.tilesets[i].tilewidth + (Map.map.tilesets[i].spacing)
            local tempTileHeight = Map.map.tilesets[i].tileheight + (Map.map.tilesets[i].spacing)
            local numFrames = math.floor(Map.map.tilesets[i].imagewidth / tempTileWidth) * math.floor(Map.map.tilesets[i].imageheight / tempTileHeight)
            local options = {width = Map.map.tilesets[i].tilewidth, 
                height = Map.map.tilesets[i].tileheight, 
                numFrames = numFrames, 
                border = Map.map.tilesets[i].margin,
                sheetContentWidth = Map.map.tilesets[i].imagewidth, 
                sheetContentHeight = Map.map.tilesets[i].imageheight
            }
            Xml.src = Map.map.tilesets[i].properties.normalMapSet
            Map.normalSets[i] = graphics.newImageSheet(Xml.src, options)
        end
    end
    
    local refLayer1, refLayer2
    for i = 1, #Map.map.layers, 1 do			
        --CHECK AND LOAD SCALE AND LEVELS
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
        
        if type(Map.map.layers[i].properties.forceDefaultPhysics) == "string" then
            if Map.map.layers[i].properties.forceDefaultPhysics == "true" then
                Map.map.layers[i].properties.forceDefaultPhysics = true
            else
                Map.map.layers[i].properties.forceDefaultPhysics = false
            end
        end
        
        Map.map.layers[i].toggleParallax = false
        
        Map.map.layers[i].properties.scaleX = tonumber(Map.map.layers[i].properties.scaleX)
        Map.map.layers[i].properties.scaleY = tonumber(Map.map.layers[i].properties.scaleY)
        if Map.map.layers[i].properties.parallax then
            Map.map.layers[i].parallaxX = Map.map.layers[i].properties.parallax / Map.map.layers[i].properties.scaleX
            Map.map.layers[i].parallaxY = Map.map.layers[i].properties.parallax / Map.map.layers[i].properties.scaleY
            Map.map.layers[i].toggleParallax = true
        else
            if Map.map.layers[i].properties.parallaxX then
                Map.map.layers[i].parallaxX = Map.map.layers[i].properties.parallaxX / Map.map.layers[i].properties.scaleX
                Map.map.layers[i].toggleParallax = true
            else
                Map.map.layers[i].parallaxX = 1
            end
            if Map.map.layers[i].properties.parallaxY then
                Map.map.layers[i].parallaxY = Map.map.layers[i].properties.parallaxY / Map.map.layers[i].properties.scaleY
                Map.map.layers[i].toggleParallax = true
            else
                Map.map.layers[i].parallaxY = 1
            end
        end	
        --DETECT WIDTH AND HEIGHT
        if Map.map.layers[i].properties.width then
            Map.map.layers[i].width = tonumber(Map.map.layers[i].properties.width)
        end
        if Map.map.layers[i].properties.height then
            Map.map.layers[i].height = tonumber(Map.map.layers[i].properties.height)
        end
        --DETECT LAYER WRAP
        Camera.layerWrapX[i] = Camera.worldWrapX
        Camera.layerWrapY[i] = Camera.worldWrapY
        if Map.map.layers[i].properties.wrap then
            if Map.map.layers[i].properties.wrap == "true" then
                Camera.layerWrapX[i] = true
                Camera.layerWrapY[i] = true
            elseif Map.map.layers[i].properties.wrap == "false" then
                Camera.layerWrapX[i] = false
                Camera.layerWrapY[i] = false
            end
        end
        if Map.map.layers[i].properties.wrapX then
            if Map.map.layers[i].properties.wrapX == "true" then
                Camera.layerWrapX[i] = true
            elseif Map.map.layers[i].properties.wrapX == "false" then
                Camera.layerWrapX[i] = false
            end
        end
        if Map.map.layers[i].properties.wrapY then
            if Map.map.layers[i].properties.wrapY == "true" then
                Camera.layerWrapY[i] = true
            elseif Map.map.layers[i].properties.wrapY == "false" then
                Camera.layerWrapY[i] = false
            end
        end
        --TOGGLE PARALLAX CROP
        if Map.map.layers[i].properties.toggleParallaxCrop == "true" then
            Map.map.layers[i].width = math.floor(Map.map.layers[i].width * Map.map.layers[i].parallaxX)
            Map.map.layers[i].height = math.floor(Map.map.layers[i].height * Map.map.layers[i].parallaxY)
            if Map.map.layers[i].width > Map.map.width then
                Map.map.layers[i].width = Map.map.width
            end
            if Map.map.layers[i].height > Map.map.height then
                Map.map.layers[i].height = Map.map.height
            end
            Map.map.layers[i].toggleParallax = true
        end		
        --FIT BY PARALLAX / FIT BY SCALE
        if Map.map.layers[i].properties.fitByParallax then
            Map.map.layers[i].parallaxX = (Map.map.layers[i].width / Map.map.width) * Map.map.layers[i].properties.scaleX * (Map.map.layers[i].width * Map.map.layers[i].properties.scaleX / Map.map.width)
            --Map.map.layers[i].parallaxX = ((Map.map.layers[i].width * Map.map.layers[i].properties.scaleX) / Map.map.width)
            Map.map.layers[i].parallaxY = (Map.map.layers[i].height / Map.map.height) * Map.map.layers[i].properties.scaleY * (Map.map.layers[i].height * Map.map.layers[i].properties.scaleY / Map.map.height)
            --Map.map.layers[i].parallaxY = (Map.map.layers[i].height / Map.map.height) --* Map.map.layers[i].properties.scaleY
            --Map.map.layers[i].parallaxY = ((Map.map.layers[i].height * Map.map.layers[i].properties.scaleY) / Map.map.height)
            Map.map.layers[i].toggleParallax = true
        else
            if Map.map.layers[i].properties.fitByScale then
                Map.map.layers[i].properties.scaleX = (Map.map.width * Map.map.layers[i].properties.parallaxX) / Map.map.layers[i].width
                Map.map.layers[i].properties.scaleY = (Map.map.height * Map.map.layers[i].properties.parallaxY) / Map.map.layers[i].height
                Map.map.layers[i].toggleParallax = true
            end
        end
        if Map.map.layers[i].parallaxX == 1 and Map.map.layers[i].parallaxY == 1 and Map.map.layers[i].properties.scaleX == 1 and Map.map.layers[i].properties.scaleY == 1 then
            if not refLayer1 then
                refLayer1 = tonumber(i)
            end
        elseif Map.map.layers[i].parallaxX == 1 and Map.map.layers[i].parallaxY == 1 then
            if not refLayer2 then
                refLayer2 = tonumber(i)
            end
        end		
        if Map.map.layers[i].parallaxX ~= 1 or Map.map.layers[i].parallaxY ~= 1 or Map.map.layers[i].toggleParallax == true then
            Camera.parallaxToggle[i] = true
        end
        if Camera.enableLighting then
            if not Map.map.layers[i].lighting then
                Map.map.layers[i].lighting = {}
            end
        end
        
        ----------------------------------------------------------------------------------
        local hex2bin = {
            ["0"] = "0000",
            ["1"] = "0001",
            ["2"] = "0010",
            ["3"] = "0011",
            ["4"] = "0100",
            ["5"] = "0101",
            ["6"] = "0110",
            ["7"] = "0111",
            ["8"] = "1000",
            ["9"] = "1001",
            ["a"] = "1010",
            ["b"] = "1011",
            ["c"] = "1100",
            ["d"] = "1101",
            ["e"] = "1110",
            ["f"] = "1111"
        }
        
        local Hex2Bin = function(s)
            local ret = ""
            local i = 0
            for i in string.gfind(s, ".") do
                i = string.lower(i)
                
                ret = ret..hex2bin[i]
            end
            return ret
        end
        
        local Bin2Dec = function(s)	
            local num = 0
            local ex = string.len(s) - 1
            local l = 0
            l = ex + 1
            for i = 1, l do
                b = string.sub(s, i, i)
                if b == "1" then
                    num = num + 2^ex
                end
                ex = ex - 1
            end
            return string.format("%u", num)
        end
        
        local Dec2Bin = function(s, num)
            local n
            if (num == nil) then
                n = 0
            else
                n = num
            end
            s = string.format("%x", s)
            s = Hex2Bin(s)
            while string.len(s) < n do
                s = "0"..s
            end
            return s
        end
        ----------------------------------------------------------------------------------
        
        if Camera.enableLighting then
            for x = 1, Map.map.layers[i].width, 1 do
                if Map.map.layers[i].lighting then
                    Map.map.layers[i].lighting[x] = {}
                end
            end
        end
        
        Map.tileObjects[i] = {}
        for x = 1, Map.map.layers[i].width, 1 do
            Map.tileObjects[i][x] = {}
        end
        if not Map.map.modified then
            if not Map.map.layers[i].data and not Map.map.layers[i].image then
                Map.map.layers[i].properties.objectLayer = true
            end
        end
        if not storageToggle then
            --LOAD WORLD ARRAYS
            if not Map.map.modified then
                Map.map.layers[i].world = {}
                Map.map.layers[i].largeTiles = {}
                if Map.map.layers[i].properties.objectLayer then
                    Map.map.layers[i].extendedObjects = {}
                end
                --Map.tileObjects[i] = {}
                if Map.enableFlipRotation then
                    Map.map.layers[i].flipRotation = {}
                end
                if Camera.enableLighting and i == 1 then
                    Map.map.lightToggle = {}
                    Map.map.lightToggle2 = {}
                    Map.map.lightToggle3 = {}
                    Light.lightingData.lightLookup = {}
                end
                local mL = Map.map.layers[i]
                local mD = mL.data	
                for x = 1, Map.map.layers[i].width, 1 do
                    mL.world[x] = {}
                    if not mL.largeTiles[x] then
                        mL.largeTiles[x] = {}
                    end
                    if mL.properties.objectLayer then
                        mL.extendedObjects[x] = {}
                    end
                    if mL.lighting then
                        mL.lighting[x] = {}
                    end
                    if Camera.enableLighting and i == 1 then
                        Map.map.lightToggle[x] = {}
                        Map.map.lightToggle2[x] = {}
                        Map.map.lightToggle3[x] = {}
                    end
                    if Map.enableFlipRotation then
                        mL.flipRotation[x] = {}
                    end
                    local lx = x
                    while lx > Map.map.width do
                        lx = lx - Map.map.width
                    end
                    for y = 1, Map.map.layers[i].height, 1 do
                        if Camera.enableLighting and i == 1 then
                            Map.map.lightToggle2[x][y] = 0
                        end
                        local ly = y
                        while ly > Map.map.height do
                            ly = ly - Map.map.height
                        end											
                        if mD then
                            if Map.enableFlipRotation then
                                if mD[(Map.map.width * (ly - 1)) + lx] > 1000000 then
                                    local string = tostring(mD[(Map.map.width * (ly - 1)) + lx])
                                    if globalID[string] then
                                        mL.flipRotation[x][y] = globalID[string][1]
                                        mL.world[x][y] = globalID[string][2]
                                    else
                                        local binary = Dec2Bin(string)
                                        local command = string.sub(binary, 1, 3)
                                        local flipRotate = Bin2Dec(command)
                                        mL.flipRotation[x][y] = tonumber(flipRotate)
                                        local binaryID = string.sub(binary, 4, 32)
                                        local tileID = Bin2Dec(binaryID)
                                        mL.world[x][y] = tonumber(tileID)
                                        globalID[string] = {tonumber(flipRotate), tonumber(tileID)}
                                    end
                                else
                                    mL.world[x][y] = mD[(Map.map.width * (ly - 1)) + lx]
                                end
                            else
                                mL.world[x][y] = mD[(Map.map.width * (ly - 1)) + lx]
                            end	
                            
                            if mL.world[x][y] ~= 0 then
                                local frameIndex = mL.world[x][y]
                                local tileSetIndex = 1
                                for i = 1, #Map.map.tilesets, 1 do
                                    if frameIndex >= Map.map.tilesets[i].firstgid then
                                        tileSetIndex = i
                                    else
                                        break
                                    end
                                end
                                
                                --find static lights
                                if Camera.enableLighting then
                                    tileStr = tostring((frameIndex - (Map.map.tilesets[tileSetIndex].firstgid - 1)) - 1)
                                    local mT = Map.map.tilesets[tileSetIndex].tileproperties
                                    if mT then
                                        if mT[tileStr] then
                                            if mT[tileStr]["lightSource"] then
                                                local range = json.decode(mT[tileStr]["lightRange"])
                                                local maxRange = range[1]
                                                for l = 1, 3, 1 do
                                                    if range[l] > maxRange then
                                                        maxRange = range[l]
                                                    end
                                                end
                                                Map.map.lights[Light.lightIDs] = {locX = x, 
                                                    locY = y, 
                                                    tileSetIndex = tileSetIndex, 
                                                    tileStr = tileStr,
                                                    frameIndex = frameIndex,
                                                    source = json.decode(mT[tileStr]["lightSource"]),
                                                    falloff = json.decode(mT[tileStr]["lightFalloff"]),
                                                    range = range,
                                                    maxRange = maxRange,
                                                    layer = i,
                                                    baseLayer = i,
                                                    level = M.getLevel(i),
                                                    id = Light.lightIDs,
                                                    area = {},
                                                    areaIndex = 1
                                                }
                                                if mT[tileStr]["lightLayer"] then
                                                    Map.map.lights[Light.lightIDs].layer = tonumber(mT[tileStr]["lightLayer"])
                                                    Map.map.lights[Light.lightIDs].level = M.getLevel(Map.map.lights[Light.lightIDs].layer)
                                                elseif mT[tileStr]["lightLayerRelative"] then
                                                    Map.map.lights[Light.lightIDs].layer = Map.map.lights[Light.lightIDs].layer + tonumber(mT[tileStr]["lightLayerRelative"])
                                                    if Map.map.lights[Light.lightIDs].layer < 1 then
                                                        Map.map.lights[Light.lightIDs].layer = 1
                                                    end
                                                    if Map.map.lights[Light.lightIDs].layer > #Map.map.layers then
                                                        Map.map.lights[Light.lightIDs].layer = #Map.map.layers
                                                    end
                                                    Map.map.lights[Light.lightIDs].level = M.getLevel(Map.map.lights[Light.lightIDs].layer)
                                                end
                                                if mT[tileStr]["lightArc"] then
                                                    Map.map.lights[Light.lightIDs].arc = json.decode(
                                                    mT[tileStr]["lightArc"]
                                                    )
                                                end
                                                if mT[tileStr]["lightRays"] then
                                                    Map.map.lights[Light.lightIDs].rays = json.decode(
                                                    mT[tileStr]["lightRays"]
                                                    )
                                                end
                                                if mT[tileStr]["layerFalloff"] then
                                                    Map.map.lights[Light.lightIDs].layerFalloff = json.decode(
                                                    mT[tileStr]["layerFalloff"]
                                                    )
                                                end
                                                if mT[tileStr]["levelFalloff"] then
                                                    Map.map.lights[Light.lightIDs].levelFalloff = json.decode(
                                                    mT[tileStr]["levelFalloff"]
                                                    )
                                                end
                                                Light.lightIDs = Light.lightIDs + 1
                                            end
                                        end
                                    end
                                end
                                
                                --find large tiles
                                local mT = Map.map.tilesets[tileSetIndex]
                                if mT.tilewidth > Map.map.tilewidth or mT.tileheight > Map.map.tileheight  then
                                    --print("found")
                                    local width = math.ceil(mT.tilewidth / Map.map.tilewidth)
                                    local height = math.ceil(mT.tileheight / Map.map.tileheight)
                                    
                                    for locX = x, x + width - 1, 1 do
                                        for locY = y, y - height + 1, -1 do
                                            local lx = locX
                                            local ly = locY
                                            if lx > Map.map.width then
                                                lx = lx - Map.map.width
                                            elseif lx < 1 then
                                                lx = lx + Map.map.width
                                            end
                                            if ly > Map.map.height then
                                                ly = ly - Map.map.height
                                            elseif ly < 1 then
                                                ly = ly + Map.map.height
                                            end
                                            
                                            if not mL.largeTiles[lx] then
                                                Map.map.layers[i].largeTiles[lx] = {}
                                            end
                                            if not mL.largeTiles[lx][ly] then
                                                Map.map.layers[i].largeTiles[lx][ly] = {}
                                            end
                                            
                                            mL.largeTiles[lx][ly][#mL.largeTiles[lx][ly] + 1] = {frameIndex, x, y}
                                        end
                                    end
                                    
                                end
                            end
                            
                        else
                            mL.world[x][y] = 0
                        end
                    end
                end
            end
        end
        
        --DELETE IMPORTED TILEMAP FROM MEMORY
        if not Map.map.modified then
            Map.map.layers[i].data = nil
        end
        if Map.map.layers[i].properties.level ~= prevLevel then
            prevLevel = Map.map.layers[i].properties.level
            Map.map.numLevels = Map.map.numLevels + 1
        end
        Map.map.layers[i].properties.level = tonumber(Map.map.layers[i].properties.level)		
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
                    PhysicsData.layer[i].defaultShape = json.decode(Map.map.layers[i].properties.shape)
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
                PhysicsData.layer[i].defaultShape = json.decode(Map.map.layers[i].properties.shape)
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
        Map.masterGroup[i].xScale = tonumber(Map.map.layers[i].properties.scaleX)
        Map.masterGroup[i].yScale = tonumber(Map.map.layers[i].properties.scaleY)
    end
    
    if refLayer1 then
        Map.refLayer = refLayer1
    elseif refLayer2 then
        Map.refLayer = refLayer2
    else
        Map.refLayer = 1
    end
    
    globalID = {}
    print("Levels: "..Map.map.numLevels)
    print("Reference Layer: "..Map.refLayer)
    
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
                if Map.map.layers[i].properties.lightRed then
                    Map.map.layers[i].redLight = tonumber(Map.map.layers[i].properties.lightRed)
                else
                    Map.map.layers[i].redLight = 1
                end
                if Map.map.layers[i].properties.lightGreen then
                    Map.map.layers[i].greenLight = tonumber(Map.map.layers[i].properties.lightGreen)
                else
                    Map.map.layers[i].greenLight = 1
                end
                if Map.map.layers[i].properties.lightBlue then
                    Map.map.layers[i].blueLight = tonumber(Map.map.layers[i].properties.lightBlue)
                else
                    Map.map.layers[i].blueLight = 1
                end
            end
        end
    end
    
    --CORRECT OBJECTS FOR Type.Isometric MAPS
    if Map.map.orientation == Map.Type.Isometric and not storageToggle then
        for i = 1, #Map.map.layers, 1 do
            if Map.map.layers[i].properties.objectLayer then
                for j = 1, #Map.map.layers[i].objects, 1 do
                    Map.map.layers[i].objects[j].width = Map.map.layers[i].objects[j].width * 2
                    Map.map.layers[i].objects[j].height = Map.map.layers[i].objects[j].height * 2
                    Map.map.layers[i].objects[j].x = Map.map.layers[i].objects[j].x * 2
                    Map.map.layers[i].objects[j].y = Map.map.layers[i].objects[j].y * 2
                    if Map.map.layers[i].objects[j].polygon then
                        for k = 1, #Map.map.layers[i].objects[j].polygon, 1 do
                            Map.map.layers[i].objects[j].polygon[k].x = Map.map.layers[i].objects[j].polygon[k].x * 2
                            Map.map.layers[i].objects[j].polygon[k].y = Map.map.layers[i].objects[j].polygon[k].y * 2
                        end
                    elseif Map.map.layers[i].objects[j].polyline then
                        for k = 1, #Map.map.layers[i].objects[j].polyline, 1 do
                            Map.map.layers[i].objects[j].polyline[k].x = Map.map.layers[i].objects[j].polyline[k].x * 2
                            Map.map.layers[i].objects[j].polyline[k].y = Map.map.layers[i].objects[j].polyline[k].y * 2
                        end
                    end
                end
            end
        end
    end
    
    M.detectSpriteLayers()
    M.detectObjectLayers()
    
    
    
    M.map = Map.map
    M.masterGroup = Map.masterGroup
    
    print("Map Load Time(ms): "..system.getTimer() - startTime)
    
    if Map.map.orientation == Map.Type.Isometric and not Map.map.modified then
        Map.map.tilewidth = Map.map.tilewidth --* Map.isoScaleMod
        Map.map.tileheight = Map.map.tilewidth
    end			
    for i = 1, #Map.map.tilesets, 1 do
        if Map.map.tilesets[i].properties then
            for key,value in pairs(Map.map.tilesets[i].properties) do
                if key == "physicsSource" then
                    local scaleFactor = 1
                    if Map.map.tilesets[i].properties["physicsSourceScale"] then
                        scaleFactor = tonumber(Map.map.tilesets[i].properties["physicsSourceScale"])
                    end
                    local source = value:gsub(".lua", "")
                    Map.map.tilesets[i].PhysicsData = require(source).PhysicsData(scaleFactor)
                end
            end
        end
    end
    --process static lights		
    if Camera.enableLighting then
        local startTime=system.getTimer()
        for key,value in pairs(Map.map.lights) do
            if value.rays then
                for k = 1, #value.rays, 1 do
                    Light.processLightRay(value.layer, value, value.rays[k])
                end
            else
                Light.processLight(value.layer, value)
            end
        end
        print("Light Load Time(ms): "..system.getTimer() - startTime)
    end		
    if Map.map.orientation == Map.Type.Isometric then
        for i = 1, #Map.map.layers, 1 do
            local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
            local cameraX, cameraY = Map.masterGroup[i]:contentToLocal(tempX, tempY)
            local temp = Map.isoTransform(cameraX, cameraY)
            Map.cameraXoffset[i] = temp[1] - cameraX
            Map.cameraYoffset[i] = temp[2] - cameraY
        end
    end		
    Map.map.modified = 1
    
    if Camera.touchScroll[1] or Camera.pinchZoom then
        Map.masterGroup:addEventListener("touch", Camera.touchScrollPinchZoom)
    end
    
    return Map.map
end

-----------------------------------------------------------

M.changeSpriteLayer = function(sprite, layer)
    local object = sprite
    object.layer = layer
    object.level = M.getLevel(layer)
    if Map.map.orientation == Map.Type.Isometric then
        if not object.levelPosX then
            object.levelPosX = object.x
        end
        if not object.levelPosY then
            object.levelPosY = object.y
        end
        if not object.locX then
            object.locX = math.ceil(object.levelPosX / Map.map.tilewidth)
            object.locY = math.ceil(object.levelPosY / Map.map.tileheight)
        end
        if object.locX >= 1 and object.locY >= 1 and not object.isMoving then
            if Map.isoSort == 1 then
                local temp = object.locX + object.locY - 1
                if temp > Map.map.height + Map.map.width then
                    temp = Map.map.height + Map.map.width
                end
                Map.masterGroup[layer][temp]:insert(object)
            end
        end
    else
        Map.masterGroup[layer]:insert(sprite)
    end		
    if object.lighting then
        object:setFillColor(Map.map.layers[layer].redLight, Map.map.layers[layer].greenLight, Map.map.layers[layer].blueLight)
    end		
    if Camera.enableLighting then
        if object.light then
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
            object.light.layer = layer
            object.light.level = object.level
        end
    end
end

-----------------------------------------------------------

Sprites.spritesFrozen = false
Camera.McameraFrozen = false

-----------------------------------------------------------

M.moveSprite = function(sprite, velX, velY)
    if velX ~= 0 or velY ~= 0 then
        M.moveSpriteTo({sprite = sprite, levelPosX = sprite.levelPosX + velX,
        levelPosY = sprite.levelPosY + velY, time = Map.frameTime}
        )
    end
end

-----------------------------------------------------------

M.moveCamera = function(velX, velY, layer)			
    if not layer then
        layer = Map.refLayer
    end
    local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
    local cameraX, cameraY = Map.masterGroup[layer]:contentToLocal(tempX, tempY)
    local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
    local cameraLocY = math.ceil(cameraY / Map.map.tileheight)
    M.moveCameraTo({levelPosX = cameraX + velX,
    levelPosY = cameraY + velY, time = Map.frameTime}
    )
end


M.setCamera = function(params)
    if params.overDraw then
        Map.overDraw = params.overDraw
    end		
    if params.parentGroup then
        params.parentGroup:insert(Map.masterGroup)
    end		
    if params.scale then
        Map.masterGroup.xScale = params.scale
        Map.masterGroup.yScale = params.scale
    end
    if params.scaleX then
        Map.masterGroup.xScale = params.scaleX
    end
    if params.scaleY then
        Map.masterGroup.yScale = params.scaleY
    end		
    if params.blockScale then
        Map.masterGroup.xScale = params.blockScale / Map.map.tilewidth
        Map.masterGroup.yScale = params.blockScale / Map.map.tileheight
    end
    if params.blockScaleX then
        Map.masterGroup.xScale = params.blockScaleX / Map.map.tilewidth
    end
    if params.blockScaleY then
        Map.masterGroup.yScale = params.blockScaleY / Map.map.tileheight
    end		
    local levelPosX, levelPosY = 0, 0
    if params.locX then
        levelPosX = params.locX * Map.map.tilewidth - (Map.map.tilewidth / 2)
    end
    if params.locY then
        levelPosY = params.locY * Map.map.tileheight - (Map.map.tileheight / 2)
    end
    if params.levelPosX then
        levelPosX = params.levelPosX
    end
    if params.levelPosY then
        levelPosY = params.levelPosY
    end		
    if params.sprite then
        levelPosX = params.sprite.levelPosX or params.sprite.x
        levelPosY = params.sprite.levelPosY or params.sprite.y
    end
    for i = 1, Map.masterGroup.numChildren, 1 do
        if Map.map.orientation == Map.Type.Isometric then
            Map.masterGroup[i].x = levelPosX * -1 * Map.map.layers[i].properties.scaleX 
            Map.masterGroup[i].y = levelPosY * -1 * Map.map.layers[i].properties.scaleY 
        else
            Map.masterGroup[i].x = levelPosX * -1 * Map.map.layers[i].properties.scaleX * Map.map.layers[i].parallaxX
            Map.masterGroup[i].y = levelPosY * -1 * Map.map.layers[i].properties.scaleY * Map.map.layers[i].parallaxY
        end	
    end		
    if params.cullingMargin then
        if params.cullingMargin[1] then
            Camera.cullingMargin[1] = params.cullingMargin[1]
        end
        if params.cullingMargin[2] then
            Camera.cullingMargin[2] = params.cullingMargin[2]
        end
        if params.cullingMargin[3] then
            Camera.cullingMargin[3] = params.cullingMargin[3]
        end
        if params.cullingMargin[4] then
            Camera.cullingMargin[4] = params.cullingMargin[4]
        end
    end		
    if Map.map.orientation == Map.Type.Isometric then
        for i = 1, #Map.map.layers, 1 do			
            local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
            local cameraX, cameraY = Map.masterGroup[i]:contentToLocal(tempX, tempY)
            local temp = Map.isoTransform(cameraX, cameraY)
            Map.cameraXoffset[i] = temp[1] - cameraX
            Map.cameraYoffset[i] = temp[2] - cameraY
        end
    end		
    if not Map.masterGroup[Map.refLayer].vars.camera then
        Sprites.spritesFrozen = true
        Camera.McameraFrozen = true
        Core.update()
        Sprites.spritesFrozen = false
        Camera.McameraFrozen = false
    end		
    return Map.masterGroup
end

-----------------------------------------------------------

M.cancelSpriteMove = function(sprite, onComplete)
    if Sprites.movingSprites[sprite] then
        local object = sprite
        object.isMoving = false
        object.deltaX = nil
        object.deltaY = nil
        Sprites.movingSprites[sprite] = nil
        if object.onComplete then
            if onComplete == nil or onComplete == true then
                local event = { name = "spriteMoveComplete", sprite = object}
                object.onComplete(event)
                object.onComplete = nil
            else
                object.onComplete = nil
            end
        end
    end
end

-----------------------------------------------------------

M.cancelCameraMove = function(layer)
    if Camera.refMove or not layer then
        for i = 1, #Map.map.layers, 1 do
            if Camera.deltaX[i] or deltaY[i] then
                if Camera.deltaX[i][1] or deltaY[i][1] then
                    Camera.deltaX[i] = nil
                    deltaY[i] = nil
                    Camera.isCameraMoving[i] = false
                    Camera.parallaxToggle[i] = true
                    Camera.refMove = false
                    Camera.override[i] = false
                    Sprites.holdSprite = nil
                end
            end
        end
        if Camera.cameraOnComplete[1] then
            local tempOnComplete = Camera.cameraOnComplete[1]
            Camera.cameraOnComplete = {}
            local event = { name = "cameraLayerMoveComplete", 
                levelPosX = cameraX, 
                levelPosY = cameraY, 
                locX = cameraLocX, 
                locY = cameraLocY
            }
            tempOnComplete(event)
        end
    else
        if Camera.deltaX[layer] or Camera.deltaY[layer] then
            if Camera.deltaX[layer][1] or Camera.deltaY[layer][1] then
                Camera.deltaX[layer] = nil
                Camera.deltaY[layer] = nil
                Camera.isCameraMoving[layer] = false
                Camera.parallaxToggle[layer] = true
                Camera.override[layer] = false
                Sprites.holdSprite = nil
                if Camera.cameraOnComplete[layer] then
                    local tempOnComplete = Camera.cameraOnComplete[layer]
                    Camera.cameraOnComplete[layer] = nil
                    local event = { name = "cameraLayerMoveComplete", layer = layer, 
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

-----------------------------------------------------------

M.constrainCamera = function(params)
    local params = params
    if not params then
        params = {}
    end
    local leftParam, topParam, rightParam, bottomParam
    if params.loc then
        if params.loc[1] then
            leftParam = (params.loc[1] - 1) * Map.map.tilewidth
        end
        if params.loc[2] then
            topParam = (params.loc[2] - 1) * Map.map.tileheight
        end
        if params.loc[3] then
            rightParam = (params.loc[3]) * Map.map.tilewidth
        end
        if params.loc[4] then
            bottomParam = (params.loc[4]) * Map.map.tileheight
        end
    elseif params.levelPos then
        leftParam = params.levelPos[1]
        topParam = params.levelPos[2]
        rightParam = params.levelPos[3]
        bottomParam = params.levelPos[4]
    else
        leftParam = 0 - (Map.map.locOffsetX * Map.map.tilewidth)
        topParam = 0 - (Map.map.locOffsetY * Map.map.tileheight)
        rightParam = (Map.map.width - Map.map.locOffsetX) * Map.map.tilewidth
        bottomParam = (Map.map.height - Map.map.locOffsetY) * Map.map.tileheight
    end		
    local layer = params.layer
    local xA = params.xAlign or "center"
    local yA = params.yAlign or "center"
    local time = params.time or 1
    local transition = params.transition or easing.linear		
    if params.layer and params.layer == Map.refLayer then
        params.layer = nil
    end		
    local check1 = true
    if params.layer and params.layer ~= "all" then
        if Camera.constrainTop[params.layer] == topParam and 
            Camera.constrainBottom[params.layer] == bottomParam and
            Camera.constrainLeft[params.layer] == leftParam and
            Camera.constrainRight[params.layer] == rightParam then
            check1 = false
        end
    end		
    if not params.layer or params.layer == "all" then
        if Camera.constrainTop[Map.refLayer] == topParam and 
            Camera.constrainBottom[Map.refLayer] == bottomParam and
            Camera.constrainLeft[Map.refLayer] == leftParam and
            Camera.constrainRight[Map.refLayer] == rightParam then
            check1 = false
        end
    end		
    if Map.map.orientation == Map.Type.Isometric then
        if check1 then
            Sprites.holdSprite = true
            if params.holdSprite ~= nil and params.holdSprite == false then
                Sprites.holdSprite = false
            end
            if not params.layer or params.layer == "all" then
                local check = true
                for i = 1, #Map.map.layers, 1 do
                    if Camera.override[i] then
                        check = false
                    end
                end
                if check then
                    for i = 1, #Map.map.layers, 1 do
                        M.cancelCameraMove(i)
                    end
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
                    local topLeftT, topRightT, bottomRightT, bottomLeftT = nil, nil, nil, nil
                    topLeftT = Map.isoUntransform2(topLeft[1], topLeft[2])
                    topRightT = Map.isoUntransform2(topRight[1], topRight[2])
                    bottomRightT = Map.isoUntransform2(bottomRight[1], bottomRight[2])
                    bottomLeftT = Map.isoUntransform2(bottomLeft[1], bottomLeft[2])					
                    local leftBound, topBound, rightBound, bottomBound
                    leftBound = topLeftT[1] - (Map.map.tilewidth / 2)
                    topBound = topRightT[2] - (Map.map.tileheight / 2)
                    rightBound = bottomRightT[1] - (Map.map.tilewidth / 2)
                    bottomBound = bottomLeftT[2] - (Map.map.tileheight / 2)						
                    local leftConstraint, topConstraint, rightConstraint, bottomConstraint
                    if leftParam then
                        leftConstraint = leftParam + (cameraX - leftBound)
                    end
                    if topParam then
                        topConstraint = topParam + (cameraY - topBound)
                    end
                    if rightParam then
                        rightConstraint = rightParam - (rightBound - cameraX)
                    end
                    if bottomParam then
                        bottomConstraint = bottomParam - (bottomBound - cameraY)
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
                    local velX, velY = 0, 0
                    if leftConstraint then
                        if cameraX < leftConstraint then
                            velX = (leftConstraint - cameraX)
                        end
                    end
                    if rightConstraint then
                        if cameraX > rightConstraint then
                            velX = (rightConstraint - cameraX)
                        end
                    end
                    if topConstraint then
                        if cameraY < topConstraint then
                            velY = (topConstraint - cameraY)
                        end
                    end
                    if bottomConstraint then
                        if cameraY > bottomConstraint then
                            velY = (bottomConstraint - cameraY)
                        end
                    end						
                    for i = 1, #Map.map.layers, 1 do
                        if not Map.masterGroup[i].vars.constrainLayer then
                            if Map.map.layers[i].toggleParallax == true or Map.map.layers[i].parallaxX ~= 1 or Map.map.layers[i].parallaxY ~= 1 then
                                Map.masterGroup[i].vars.alignment = {xA, yA}
                            end								
                            constrainLeft[i] = nil
                            constrainTop[i] = nil
                            constrainRight[i] = nil
                            constrainBottom[i] = nil								
                            if leftParam then
                                constrainLeft[i] = leftParam
                            end
                            if topParam then
                                constrainTop[i] = topParam
                            end
                            if rightParam then
                                constrainRight[i] = rightParam
                            end
                            if bottomParam then
                                constrainBottom[i] = bottomParam
                            end					
                            local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                            local cameraX, cameraY = Map.masterGroup[i]:contentToLocal(tempX, tempY)
                            local isoPos = Map.isoUntransform2(cameraX, cameraY)
                            cameraX = isoPos[1]
                            cameraY = isoPos[2]
                            local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
                            local cameraLocY = math.ceil(cameraY / Map.map.tileheight)							
                            Camera.override[i] = true
                            M.cancelCameraMove(i)
                            M.moveCameraTo({levelPosX = cameraX + velX, levelPosY = cameraY + velY, time = time, easing = easing, layer = i})
                        end
                    end
                    return constrainLeft, constrainTop, constrainRight, constrainBottom
                end
            else
                local layer = params.layer
                if not Camera.override[layer] then
                    Map.masterGroup[layer].vars.constrainLayer = true						
                    constrainLeft[layer] = nil
                    constrainTop[layer] = nil
                    constrainRight[layer] = nil
                    constrainBottom[layer] = nil						
                    if leftParam then
                        constrainLeft[layer] = leftParam
                    end
                    if topParam then
                        constrainTop[layer] = topParam
                    end
                    if rightParam then
                        constrainRight[layer] = rightParam
                    end
                    if bottomParam then
                        constrainBottom[layer] = bottomParam
                    end						
                    local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                    local cameraX, cameraY = Map.masterGroup[layer]:contentToLocal(tempX, tempY)
                    local isoPos = Map.isoUntransform2(cameraX, cameraY)
                    cameraX = isoPos[1]
                    cameraY = isoPos[2]
                    local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
                    local cameraLocY = math.ceil(cameraY / Map.map.tileheight)
                    
                    --calculate constraints
                    local angle = Map.masterGroup.rotation + Map.masterGroup[layer].rotation
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
                    local topLeftT, topRightT, bottomRightT, bottomLeftT = nil, nil, nil, nil
                    topLeftT = Map.isoUntransform2(topLeft[1], topLeft[2])
                    topRightT = Map.isoUntransform2(topRight[1], topRight[2])
                    bottomRightT = Map.isoUntransform2(bottomRight[1], bottomRight[2])
                    bottomLeftT = Map.isoUntransform2(bottomLeft[1], bottomLeft[2])					
                    local leftBound, topBound, rightBound, bottomBound
                    leftBound = topLeftT[1] - (Map.map.tilewidth / 2)
                    topBound = topRightT[2] - (Map.map.tileheight / 2)
                    rightBound = bottomRightT[1] - (Map.map.tilewidth / 2)
                    bottomBound = bottomLeftT[2] - (Map.map.tileheight / 2)						
                    local leftConstraint, topConstraint, rightConstraint, bottomConstraint
                    if constrainLeft[layer] then
                        leftConstraint = constrainLeft[layer] + (cameraX - leftBound)
                    end
                    if constrainTop[layer] then
                        topConstraint = constrainTop[layer] + (cameraY - topBound)
                    end
                    if constrainRight[layer] then
                        rightConstraint = constrainRight[layer] - (rightBound - cameraX)
                    end
                    if constrainBottom[layer] then
                        bottomConstraint = constrainBottom[layer] - (bottomBound - cameraY)
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
                    local velX, velY = 0, 0
                    if leftConstraint then
                        if cameraX < leftConstraint then
                            velX = (leftConstraint - cameraX)
                        end
                    end
                    if rightConstraint then
                        if cameraX > rightConstraint then
                            velX = (rightConstraint - cameraX)
                        end
                    end
                    if topConstraint then
                        if cameraY < topConstraint then
                            velY = (topConstraint - cameraY)
                        end
                    end
                    if bottomConstraint then
                        if cameraY > bottomConstraint then
                            velY = (bottomConstraint - cameraY)
                        end
                    end						
                    Camera.override[layer] = true
                    M.cancelCameraMove(layer)
                    M.moveCameraTo({levelPosX = cameraX + velX, levelPosY = cameraY + velY, time = time, easing = easing, layer = layer})
                    return constrainLeft, constrainTop, constrainRight, constrainBottom
                end
            end
        end
    else	--not isometric
        if check1 then
            Sprites.holdSprite = true
            if params.holdSprite ~= nil and params.holdSprite == false then
                Sprites.holdSprite = false
            end
            if not params.layer or params.layer == "all" then
                local check = true
                for i = 1, #Map.map.layers, 1 do
                    if Camera.override[i] then
                        check = false
                    end
                end
                if check then
                    for i = 1, #Map.map.layers, 1 do
                        M.cancelCameraMove(i)
                    end
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
                    local leftBound, topBound, rightBound, bottomBound
                    if topLeft[1] < bottomLeft[1] then
                        leftBound = topLeft[1]
                    else
                        leftBound = bottomLeft[1]
                    end
                    if topLeft[2] < topRight[2] then
                        topBound = topLeft[2]
                    else
                        topBound = topRight[2]
                    end
                    if topRight[1] > bottomRight[1] then
                        rightBound = topRight[1]
                    else
                        rightBound = bottomRight[1]
                    end
                    if bottomRight[2] > bottomLeft[2] then
                        bottomBound = bottomRight[2]
                    else
                        bottomBound = bottomLeft[2]
                    end					
                    local leftConstraint, topConstraint, rightConstraint, bottomConstraint
                    if leftParam then
                        leftConstraint = leftParam + (cameraX - leftBound)
                    end
                    if topParam then
                        topConstraint = topParam + (cameraY - topBound)
                    end
                    if rightParam then
                        rightConstraint = rightParam - (rightBound - cameraX)
                    end
                    if bottomParam then
                        bottomConstraint = bottomParam - (bottomBound - cameraY)
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
                    local velX, velY = 0, 0
                    if leftConstraint then
                        if cameraX < leftConstraint then
                            velX = (leftConstraint - cameraX)
                        end
                    end
                    if rightConstraint then
                        if cameraX > rightConstraint then
                            velX = (rightConstraint - cameraX)
                        end
                    end
                    if topConstraint then
                        if cameraY < topConstraint then
                            velY = (topConstraint - cameraY)
                        end
                    end
                    if bottomConstraint then
                        if cameraY > bottomConstraint then
                            velY = (bottomConstraint - cameraY)
                        end
                    end						
                    for i = 1, #Map.map.layers, 1 do
                        if not Map.masterGroup[i].vars.constrainLayer then
                            if Map.map.layers[i].toggleParallax == true or Map.map.layers[i].parallaxX ~= 1 or Map.map.layers[i].parallaxY ~= 1 then
                                Map.masterGroup[i].vars.alignment = {xA, yA}
                            end								
                            Camera.constrainLeft[i] = nil
                            Camera.constrainTop[i] = nil
                            Camera.constrainRight[i] = nil
                            Camera.constrainBottom[i] = nil								
                            if leftParam then
                                Camera.constrainLeft[i] = leftParam
                            end
                            if topParam then
                                Camera.constrainTop[i] = topParam
                            end
                            if rightParam then
                                Camera.constrainRight[i] = rightParam
                            end
                            if bottomParam then
                                Camera.constrainBottom[i] = bottomParam
                            end									
                            local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                            local cameraX, cameraY = Map.masterGroup[i]:contentToLocal(tempX, tempY)
                            local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
                            local cameraLocY = math.ceil(cameraY / Map.map.tileheight)
                            Camera.override[i] = true
                            M.cancelCameraMove(i)
                            M.moveCameraTo({levelPosX = cameraX + velX, levelPosY = cameraY + velY, time = time, transition = transition, layer = i})
                        end							
                    end
                    return constrainLeft, constrainTop, constrainRight, constrainBottom
                end
            else
                local layer = params.layer
                if not Camera.override[layer] then
                    Map.masterGroup[layer].vars.constrainLayer = true						
                    constrainLeft[layer] = nil
                    constrainTop[layer] = nil
                    constrainRight[layer] = nil
                    constrainBottom[layer] = nil						
                    if leftParam then
                        constrainLeft[layer] = leftParam
                    end
                    if topParam then
                        constrainTop[layer] = topParam
                    end
                    if rightParam then
                        constrainRight[layer] = rightParam
                    end
                    if bottomParam then
                        constrainBottom[layer] = bottomParam
                    end			
                    local tempX, tempY = Map.masterGroup.parent:localToContent(Screen.screenCenterX, Screen.screenCenterY)
                    local cameraX, cameraY = Map.masterGroup[layer]:contentToLocal(tempX, tempY)
                    local cameraLocX = math.ceil(cameraX / Map.map.tilewidth)
                    local cameraLocY = math.ceil(cameraY / Map.map.tileheight)
                    
                    --calculate constraints
                    local angle = Map.masterGroup.rotation + Map.masterGroup[layer].rotation
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
                    local leftBound, topBound, rightBound, bottomBound
                    if topLeft[1] < bottomLeft[1] then
                        leftBound = topLeft[1]
                    else
                        leftBound = bottomLeft[1]
                    end
                    if topLeft[2] < topRight[2] then
                        topBound = topLeft[2]
                    else
                        topBound = topRight[2]
                    end
                    if topRight[1] > bottomRight[1] then
                        rightBound = topRight[1]
                    else
                        rightBound = bottomRight[1]
                    end
                    if bottomRight[2] > bottomLeft[2] then
                        bottomBound = bottomRight[2]
                    else
                        bottomBound = bottomLeft[2]
                    end			
                    local leftConstraint, topConstraint, rightConstraint, bottomConstraint
                    if constrainLeft[layer] then
                        leftConstraint = constrainLeft[layer] + (cameraX - leftBound)
                    end
                    if constrainTop[layer] then
                        topConstraint = constrainTop[layer] + (cameraY - topBound)
                    end
                    if constrainRight[layer] then
                        rightConstraint = constrainRight[layer] - (rightBound - cameraX)
                    end
                    if constrainBottom[layer] then
                        bottomConstraint = constrainBottom[layer] - (bottomBound - cameraY)
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
                    local velX, velY = 0, 0
                    if leftConstraint then
                        if cameraX < leftConstraint then
                            velX = (leftConstraint - cameraX)
                        end
                    end
                    if rightConstraint then
                        if cameraX > rightConstraint then
                            velX = (rightConstraint - cameraX)
                        end
                    end
                    if topConstraint then
                        if cameraY < topConstraint then
                            velY = (topConstraint - cameraY)
                        end
                    end
                    if bottomConstraint then
                        if cameraY > bottomConstraint then
                            velY = (bottomConstraint - cameraY)
                        end
                    end
                    Camera.override[layer] = true
                    M.cancelCameraMove(layer)
                    M.moveCameraTo({levelPosX = cameraX + velX, levelPosY = cameraY + velY, time = time, easing = easing, layer = layer})
                    return constrainLeft, constrainTop, constrainRight, constrainBottom
                end
            end
        end
    end
end

-----------------------------------------------------------



-----------------------------------------------------------

M.alignParallaxLayer = function(layer, xAlign, yAlign)
    if Map.map.layers[layer].parallaxX ~= 1 or Map.map.layers[layer].parallaxY ~= 1 or Map.map.layers[layer].toggleParallax == true then
        if Map.map.orientation == Map.Type.Isometric then
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
            local topLeftT, topRightT, bottomRightT, bottomLeftT = nil, nil, nil, nil
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
            leftConstraint = (0 - (Map.map.locOffsetX * Map.map.tilewidth)) + (cameraX - left)
            topConstraint = (0 - (Map.map.locOffsetY * Map.map.tileheight)) + (cameraY - top)
            rightConstraint = ((Map.map.width - Map.map.locOffsetX) * Map.map.tilewidth) - (right - cameraX)
            bottomConstraint = ((Map.map.height - Map.map.locOffsetY) * Map.map.tileheight) - (bottom - cameraY)				
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
            local xA = xAlign or "center"
            local yA = yAlign or "center"	
            Map.masterGroup[layer].vars.alignment = {xA, yA}
            local levelPosX, levelPosY
            if xA == "center" then
                local adjustment1 = (((Map.map.width * Map.map.tilewidth * 0.5) - (Map.map.locOffsetX * Map.map.tilewidth * 0.5)) * Map.map.layers[layer].properties.scaleX) - ((Map.map.width * Map.map.tilewidth * 0.5) - (Map.map.locOffsetX * Map.map.tilewidth * 0.5))
                local adjustment2 = (cameraX - ((Map.map.width * Map.map.tilewidth * 0.5) - (Map.map.locOffsetX * Map.map.tilewidth * 0.5))) - ((cameraX - ((Map.map.width * Map.map.tilewidth * 0.5) - (Map.map.locOffsetX * Map.map.tilewidth * 0.5))) * Map.map.layers[layer].parallaxX)
                levelPosX = ((cameraX + adjustment1) - adjustment2)
            elseif xA == "left" then
                local adjustment = (cameraX - leftConstraint) - ((cameraX - leftConstraint) * Map.map.layers[layer].parallaxX)
                levelPosX = (cameraX - adjustment)
            elseif xA == "right" then
                local adjustment1 = (((Map.map.width - Map.map.locOffsetX) * Map.map.tilewidth) * Map.map.layers[layer].properties.scaleX) - ((Map.map.width - Map.map.locOffsetX) * Map.map.tilewidth)
                local adjustment2 = (cameraX - rightConstraint) - ((cameraX - rightConstraint) * Map.map.layers[layer].parallaxX)
                levelPosX = ((cameraX + adjustment1) - adjustment2)
            end
            
            if yA == "center" then
                local adjustment1 = (((Map.map.height * Map.map.tileheight * 0.5) - (Map.map.locOffsetY * Map.map.tileheight * 0.5)) * Map.map.layers[layer].properties.scaleY) - ((Map.map.height * Map.map.tileheight * 0.5) - (Map.map.locOffsetY * Map.map.tileheight * 0.5))
                local adjustment2 = (cameraY - ((Map.map.height * Map.map.tileheight * 0.5) - (Map.map.locOffsetY * Map.map.tileheight * 0.5))) - ((cameraY - ((Map.map.height * Map.map.tileheight * 0.5) - (Map.map.locOffsetY * Map.map.tileheight * 0.5))) * Map.map.layers[layer].parallaxY)
                levelPosY = ((cameraY + adjustment1) - adjustment2)
            elseif yA == "top" then
                local adjustment = (cameraY - topConstraint) - ((cameraY - topConstraint) * Map.map.layers[layer].parallaxY)
                levelPosY = (cameraY - adjustment)
            elseif yA == "bottom" then
                local adjustment1 = (((Map.map.height - Map.map.locOffsetY) * Map.map.tileheight) * Map.map.layers[layer].properties.scaleY) - ((Map.map.height - Map.map.locOffsetY) * Map.map.tileheight)
                local adjustment2 = (cameraY - bottomConstraint) - ((cameraY - bottomConstraint) * Map.map.layers[layer].parallaxY)
                levelPosY = ((cameraY + adjustment1) - adjustment2)
            end					
            local deltaX = levelPosX + ((Map.map.tilewidth / 2 * Map.map.layers[layer].properties.scaleX) - (Map.map.tilewidth / 2)) - cameraX * Map.map.layers[layer].properties.scaleX
            local deltaY = levelPosY + ((Map.map.tileheight / 2 * Map.map.layers[layer].properties.scaleY) - (Map.map.tileheight / 2)) - cameraY * Map.map.layers[layer].properties.scaleY	
            local isoVector = M.isoVector(deltaX, deltaY)				
            Map.masterGroup[layer].x = (Map.masterGroup[Map.refLayer].x * Map.map.layers[layer].properties.scaleX) - isoVector[1]
            Map.masterGroup[layer].y = (Map.masterGroup[Map.refLayer].y * Map.map.layers[layer].properties.scaleY) - isoVector[2]	
        else
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
            leftConstraint = (0 - (Map.map.locOffsetX * Map.map.tilewidth)) + (cameraX - left)
            topConstraint = (0 - (Map.map.locOffsetY * Map.map.tileheight)) + (cameraY - top)
            rightConstraint = ((Map.map.width - Map.map.locOffsetX) * Map.map.tilewidth) - (right - cameraX)
            bottomConstraint = ((Map.map.height - Map.map.locOffsetY) * Map.map.tileheight) - (bottom - cameraY)				
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
            local xA = xAlign or "center"
            local yA = yAlign or "center"
            Map.masterGroup[layer].vars.alignment = {xA, yA}
            
        end
    end
end

-----------------------------------------------------------

M.fadeTile = function(locX, locY, layer, alpha, time, easing)
    if not locX or not locY or not layer then
        print("ERROR: Please specify locX, locY, and layer.")
    end
    if not alpha and not time then
        local tile = Map.getTileObj(locX, locY, layer)
        if Map.fadingTiles[tile] then
            return true
        end
    else
        local tile = Map.getTileObj(locX, locY, layer)
        local currentAlpha = tile.alpha
        local distance = currentAlpha - alpha
        time = math.ceil(time / Map.frameTime)
        if not time or time < 1 then
            time = 1
        end
        tile.deltaFade = {}
        tile.deltaFade = easingHelper(distance, time, easing)
        tile.tempAlpha = currentAlpha
        Map.fadingTiles[tile] = tile
    end
end

-----------------------------------------------------------

M.fadeLayer = function(layer, alpha, time, easing)
    if not layer then
        print("ERROR: No layer specified. Defaulting to layer "..Map.refLayer..".")
        layer = Map.refLayer
    end
    if not alpha and not time then
        if Map.masterGroup[layer].vars.deltaFade then
            return true
        end
    else
        local currentAlpha = Map.masterGroup[layer].vars.alpha
        local distance = currentAlpha - alpha
        time = math.ceil(time / Map.frameTime)
        if not time or time < 1 then
            time = 1
        end
        Map.masterGroup[layer].vars.deltaFade = {}
        Map.masterGroup[layer].vars.deltaFade = Camera.easingHelper(distance, time, easing)
        Map.masterGroup[layer].vars.tempAlpha = currentAlpha
    end
end

-----------------------------------------------------------

M.fadeLevel = function(level, alpha, time, easing)
    if not level then
        print("ERROR: No level specified. Defaulting to level 1.")
        level = 1
    end
    if not alpha and not time then
        for i = 1, #Map.map.layers, 1 do
            if Map.map.layers[i].properties.level == level then
                if Map.masterGroup[i].vars.deltaFade then
                    return true
                end
            end
        end
    else
        for i = 1, #Map.map.layers, 1 do
            if Map.map.layers[i].properties.level == level then
                M.fadeLayer(i, alpha, time, easing)
            end
        end
    end
end

-----------------------------------------------------------

M.fadeMap = function(alpha, time, easing)
    if not alpha and not time then
        for i = 1, #Map.map.layers, 1 do
            if Map.masterGroup[i].vars.deltaFade then
                return true
            end
        end
    else
        for i = 1, #Map.map.layers, 1 do
            M.fadeLayer(i, alpha, time, easing)
        end
    end
end

-----------------------------------------------------------

M.cleanup = function(unload)
    if Camera.touchScroll[1] or Camera.pinchZoom then
        Map.masterGroup:removeEventListener("touch", Camera.touchScrollPinchZoom)
    end
    
    if unload then
        Map.mapStorage[source] = nil
    end		
    for key,value in pairs(Sprites.sprites) do
        Sprite.removeSprite(value)
    end
    Map.tileSets = {}	
    
    --DESTROY GROUPS
    if Map.map.orientation == Map.Type.Isometric then
        if Map.isoSort == 1 then
            for i = Map.masterGroup.numChildren, 1, -1 do
                for j = Map.map.height + Map.map.width, 1, -1 do
                    if Map.masterGroup[i][j][1].tiles then
                        for k = Map.masterGroup[i][j][1].numChildren, 1, -1 do
                            local locX = Map.masterGroup[i][j][1][k].locX
                            local locY = Map.masterGroup[i][j][1][k].locY
                            Map.tileObjects[i][locX][locY]:removeSelf()
                            Map.tileObjects[i][locX][locY] = nil
                        end
                    end
                    Map.masterGroup[i][j]:removeSelf()
                    Map.masterGroup[i][j] = nil
                end
                Map.masterGroup[i]:removeSelf()
                Map.masterGroup[i] = nil
            end
        end
    else
        for i = Map.masterGroup.numChildren, 1, -1 do
            if Map.masterGroup[i][1].tiles then
                for j = Map.masterGroup[i][1].numChildren, 1, -1 do
                    local locX = Map.masterGroup[i][1][j].locX
                    local locY = Map.masterGroup[i][1][j].locY
                    Map.tileObjects[i][locX][locY]:removeSelf()
                    Map.tileObjects[i][locX][locY] = nil
                end
            end
            for j = Map.masterGroup[i].numChildren, 1, -1 do
                if Map.masterGroup[i][j].isDepthBuffer then
                    for k = Map.masterGroup[i][j].numChildren, 1, -1 do
                        for m = Map.masterGroup[i][j][k].numChildren, 1, -1 do
                            Map.masterGroup[i][j][k][m]:removeSelf()
                            Map.masterGroup[i][j][k][m] = nil
                        end
                        Map.masterGroup[i][j][k]:removeSelf()
                        Map.masterGroup[i][j][k] = nil
                    end
                end
                Map.masterGroup[i][j]:removeSelf()
                Map.masterGroup[i][j] = nil
            end
            Map.masterGroup[i]:removeSelf()
            Map.masterGroup[i] = nil
        end
    end	
    Map.masterGroup:removeSelf()
    Map.masterGroup = nil
    Map.map = {}
    Map.map.width = nil
    Map.map.height = nil
    objects = {}
    Map.spriteLayers = {}
    Map.enableFlipRotation = false
    Sprites.holdSprite = nil
    
    --RESET CAMERA POSITION VARIABLES
    cameraX = {}
    cameraY = {}
    cameraLocX = {}
    cameraLocY = {}
    prevLocX = {}
    prevLocY = {}
    constrainTop = {}
    constrainBottom = {}
    constrainLeft = {}
    constrainRight = {}
    Camera.refMove = false
    Camera.override = {}
    Camera.cameraFocus = nil	
    for key,value in pairs(Map.animatedTiles) do
        Map.animatedTiles[key] = nil
    end	
    for key,value in pairs(Map.fadingTiles) do
        Map.fadingTiles[key] = nil
    end	
    for key,value in pairs(Map.tintingTiles) do
        Map.tintingTiles[key] = nil
    end	
    Camera.currentScale = 1
    Camera.deltaZoom = nil
end

-----------------------------------------------------------

M.createMTE = function()
    return M
end

-----------------------------------------------------------


-- Utility
table.print = function ( t )
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            print(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        print(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        print(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        print(indent.."["..pos..'] => "'..val..'"')
                    else
                        print(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                print(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        print(tostring(t).." {")
        sub_print_r(t,"  ")
        print("}")
    else
        sub_print_r(t,"  ")
    end
    print()
end

return M
