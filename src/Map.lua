local Map = {}

-----------------------------------------------------------

local Screen = require("src.Screen")

local math = math

-----------------------------------------------------------

Map.Type = {
    Orthogonal = 0,
    Isometric = 1,
    Staggered = 2
}

Map.map = {}
Map.mapStorage = {}

Map.mapPath = nil

Map.masterGroup = display.newGroup()
Map.masterGroup.x = Screen.screenCenterX
Map.masterGroup.y = Screen.screenCenterY	

Map.loadedTileSets = {}
Map.tileSets = {}
Map.normalSets = {}
Map.animatedTiles = {}
Map.fadingTiles = {}
Map.tintingTiles = {}

Map.frameTime = 1 / display.fps * 1000

Map.objectLayers = {}
Map.spriteLayers = {}

Map.refLayer = nil
Map.totalRects = {}

Map.spriteSortResolution = 1
Map.tileObjects = {}

-----------------------------------------------------------

Map.enableFlipRotation = false
Map.enableHeightMap = false
Map.enableNormalMaps = false

-----------------------------------------------------------

local R45 = math.rad(45)

Map.isoScaleMod = math.cos(R45)
Map.isoScaleHeight = nil
Map.cameraXoffset = {}
Map.cameraYoffset = {}
Map.isoSort = 1
Map.overDraw = 0

-----------------------------------------------------------

Map.isoVector = function(velX, velY)
    
    local xDelta = velX
    local yDelta = velY
    
    if ( xDelta == 0 and yDelta == 0 ) then
        return { 0, 0 }
    end
    
    --find angle
    local angle = math.atan( xDelta / yDelta )
    local length = xDelta / math.sin(angle)
    
    if ( xDelta == 0 ) then
        length = yDelta
    elseif ( yDelta == 0 ) then
        length = xDelta
        if ( xDelta < 0 ) then
            length = length * -1
        end
    end
    angle = angle - R45
    
    --find new deltas
    local xDelta2 = length * math.sin(angle)
    local yDelta2 = length * math.cos(angle)
    
    local finalX = ( xDelta2 / 1 )
    local finalY = ( yDelta2 / Map.map.isoRatio )
    
    return { finalX, finalY }
end

-----------------------------------------------------------

Map.isoTransform = function(levelPosX, levelPosY)
    --Convert world coordinates to isometric screen coordinates
    
    local w = Map.map.tilewidth * 0.5
    local h = Map.map.tileheight * 0.5
    
    --find center of Map.map
    local centerX = ( (Map.map.width * w) - (Map.map.locOffsetX * w) )
    local centerY = ( (Map.map.height * h) - (Map.map.locOffsetY * h) )
    
    --find x,y distances from center
    local xDelta = levelPosX - centerX
    local yDelta = levelPosY - centerY
    if ( yDelta == 0 ) then
        yDelta = 0.000000001
    end
    
    if ( xDelta == 0 and yDelta == 0 ) then
        return { levelPosX, levelPosY }
    end
    
    --find angle
    local angle = math.atan( xDelta / yDelta )
    local length = xDelta / math.sin(angle)
    if ( xDelta == 0 ) then
        length = yDelta
    elseif ( yDelta == 0 ) then
        length = xDelta
        if ( xDelta < 0 ) then
            length = length * -1
        end
    end
    angle = angle - R45
    
    --find new deltas
    local xDelta2 = length * math.sin(angle)
    local yDelta2 = length * math.cos(angle)
    
    local finalX = centerX + ( xDelta2 / 1 )
    local finalY = centerY + ( yDelta2 / Map.map.isoRatio )
    
    return { finalX, finalY }
end

-----------------------------------------------------------

Map.isoTransform2 = function(levelPosX, levelPosY)
    --Convert world coordinates to isometric screen coordinates
    
    local w = Map.map.tilewidth * 0.5
    local h = Map.map.tileheight * 0.5
    
    --find center of Map.map
    local centerX = ( (Map.map.width * w) - (Map.map.locOffsetX * w) )
    local centerY = ((Map.map.height * h) - (Map.map.locOffsetY * h))
    
    --find x,y distances from center
    local xDelta = levelPosX - centerX
    local yDelta = levelPosY - centerY
    
    if ( yDelta == 0 ) then
        yDelta = 0.000000001
    end	
    
    if ( xDelta == 0 and yDelta == 0 ) then
        return { levelPosX, levelPosY }
    end
    
    --find angle
    local angle = math.atan( xDelta / yDelta )
    local length = xDelta / math.sin(angle)
    if ( xDelta == 0 ) then
        length = yDelta
    elseif ( yDelta == 0 ) then
        length = xDelta
    end
    angle = angle - R45
    
    --find new deltas
    local xDelta2 = length * math.sin(angle)
    local yDelta2 = length * math.cos(angle)
    
    local finalX, finalY
    
    finalX = centerX + xDelta2
    finalY = centerY + ( yDelta2 / Map.map.isoRatio )
    
    finalX = finalX - Map.cameraXoffset[Map.refLayer]
    finalY = finalY - Map.cameraYoffset[Map.refLayer]
    
    return { finalX, finalY }
end

-----------------------------------------------------------

Map.isoUntransform = function(levelPosX, levelPosY)
    
    local w = Map.map.tilewidth * 0.5
    local h = Map.map.tileheight * 0.5
    
    --find center of Map.map
    local centerX = ((Map.map.width * w) - (Map.map.locOffsetX * w))
    local centerY = ((Map.map.height * h) - (Map.map.locOffsetY * h))
    
    --find x,y distances from center
    local xDelta = (levelPosX - centerX) * 1
    local yDelta = (levelPosY - centerY) * Map.map.isoRatio
    
    if ( xDelta == 0 and yDelta == 0 ) then
        return { levelPosX, levelPosY }
    end
    
    --find angle
    local angle = math.atan(xDelta/yDelta)
    local length = xDelta / math.sin(angle)
    if ( xDelta == 0 ) then
        length = yDelta
    elseif ( yDelta == 0 ) then
        length = xDelta
        if ( xDelta < 0 ) then
            length = length * -1
        end
    end
    angle = angle + R45
    
    --find new deltas
    local xDelta2 = length * math.sin(angle)
    local yDelta2 = length * math.cos(angle)
    
    local finalX, finalY
    
    finalX = centerX + xDelta2
    finalY = centerY + yDelta2
    
    return { finalX, finalY }
end

-----------------------------------------------------------

Map.isoUntransform2 = function(levelPosX, levelPosY)
    --find center of Map.map
    
    local w = Map.map.tilewidth * 0.5
    local h = Map.map.tileheight * 0.5
    
    local centerX = ((Map.map.width * w) - (Map.map.locOffsetX * w))
    local centerY = ((Map.map.height * h) - (Map.map.locOffsetY * h))
    
    --find x,y distances from center
    levelPosX = levelPosX + Map.cameraXoffset[Map.refLayer]
    levelPosY = levelPosY + Map.cameraYoffset[Map.refLayer]
    
    local xDelta = (levelPosX - centerX) * 1
    local yDelta = (levelPosY - centerY) * Map.map.isoRatio
    
    if ( xDelta == 0 and yDelta == 0 ) then
        return { levelPosX, levelPosY }
    end
    
    --find angle
    local angle = math.atan(xDelta/yDelta)
    local length = xDelta / math.sin(angle)
    if ( xDelta == 0 ) then
        length = yDelta
    elseif ( yDelta == 0 ) then
        length = xDelta
    end
    angle = angle + R45
    
    --find new deltas
    local xDelta2 = length * math.sin(angle)
    local yDelta2 = length * math.cos(angle)
    
    local finalX, finalY
    
    finalX = centerX + xDelta2
    finalY = centerY + yDelta2
    
    return { finalX, finalY }
end

-----------------------------------------------------------

Map.getMapObj = function()
    return Map.masterGroup
end

-----------------------------------------------------------

Map.getLayerObj = function(params)
    
    if ( not params ) then
        local array = {}
        for i = 1, #Map.map.layers, 1 do
            array[#array + 1] = Map.masterGroup[i]
        end
        return array
    end
    
    if ( params.layer ) then
        return Map.masterGroup[params.layer]
    elseif ( params.level ) then
        local array = {}
        for i=1, #Map.map.layers do
            if ( Map.map.layers[i].properties.level == params.level ) then
                array[ #array + 1 ] = Map.masterGroup[i]
            end
        end
        return array
    end    
end

-----------------------------------------------------------

Map.enableTileFlipAndRotation = function()
    Map.enableFlipRotation = true
end

-----------------------------------------------------------

Map.enableHeightMaps = function()
    
    Map.enableHeightMap = true
    if ( not ( Map.map and Map.map.layers ) ) then
        return
    end
    
    for i=1, #Map.map.layers do
        if ( not Map.map.layers[i].heightMap ) then
            Map.map.layers[i].heightMap = {}
            for x=1, Map.map.width do
                Map.map.layers[i].heightMap[ x - Map.map.locOffsetX ] = {}
            end
        end
    end    
end

-----------------------------------------------------------

Map.disableHeightMaps = function()
    Map.enableHeightMap = false
end

-----------------------------------------------------------

Map.findScaleX = function(native, layer, tilewidth)
    return ( Map.map.tilewidth * Map.map.layers[layer].properties.scaleX ) / native
end

-----------------------------------------------------------

Map.findScaleY = function(native, layer)
    return ( Map.map.tileheight * Map.map.layers[layer].properties.scaleY ) / native
end

-----------------------------------------------------------

Map.getLoadedMaps = function()
    local mapPaths = {}
    for key,value in pairs(Map.mapStorage) do
        mapPaths[#mapPaths + 1] = key
    end
    return mapPaths
end

-----------------------------------------------------------

Map.unloadMap = function(mapPath)
    Map.mapStorage[mapPath] = nil
end

-----------------------------------------------------------

Map.setParentGroup = function(group)
    group:insert(Map.masterGroup)
end

-----------------------------------------------------------

Map.setMapProperties = function(t)
    
    Map.map.properties = t or {}
    
    --LIGHTING
    
    if ( not Map.map.properties.lightingStyle ) then
        for i = 1, #Map.map.layers do
            local mapLayer = Map.map.layers[i]
            mapLayer.redLight = 1
            mapLayer.greenLight = 1
            mapLayer.blueLight = 1
        end
        return
    end
    
    local numLevels = Map.map.numLevels
    
    local levelLighting = {}
    for i = 1, numLevels do
        levelLighting[i] = {}
    end
    
    local mapProps = Map.map.properties
    
    if ( not mapProps.lightRedStart ) then
        mapProps.lightRedStart = "1"
    end
    if ( not mapProps.lightGreenStart ) then
        mapProps.lightGreenStart = "1"
    end
    if ( not mapProps.lightBlueStart ) then
        mapProps.lightBlueStart = "1"
    end
    
    if ( mapProps.lightingStyle == "diminish" ) then
        
        local rate = tonumber( mapProps.lightRate )
        levelLighting[ numLevels ].red = tonumber( mapProps.lightRedStart )
        levelLighting[ numLevels ].green = tonumber( mapProps.lightGreenStart )
        levelLighting[ numLevels ].blue = tonumber( mapProps.lightBlueStart )
        
        for i = numLevels - 1, 1, -1 do
            
            local amount = (rate * (numLevels - i) )
            
            levelLighting[i].red = levelLighting[ numLevels ].red - amount
            if ( levelLighting[i].red < 0 ) then
                levelLighting[i].red = 0
            end
            
            levelLighting[i].green = levelLighting[ numLevels ].green - amount
            if ( levelLighting[i].green < 0 ) then
                levelLighting[i].green = 0
            end
            
            levelLighting[i].blue = levelLighting[ numLevels ].blue - amount
            if ( levelLighting[i].blue < 0 ) then
                levelLighting[i].blue = 0
            end
        end
    end
    
    for i = 1, #Map.map.layers do
        
        local mapLayer = Map.map.layers[i]
        local mapLayerProps = mapLayer.properties
        
        if ( mapLayerProps.lightRed ) then
            mapLayer.redLight = tonumber( mapLayerProps.lightRed )
        else
            mapLayer.redLight = levelLighting[ mapLayerProps.level ].red
        end
        
        if ( mapLayerProps.lightGreen ) then
            mapLayer.greenLight = tonumber( mapLayerProps.lightGreen )
        else
            mapLayer.greenLight = levelLighting[ mapLayerProps.level ].green
        end
        
        if ( mapLayerProps.lightBlue ) then
            mapLayer.blueLight = tonumber( mapLayerProps.lightBlue )
        else
            mapLayer.blueLight = levelLighting[ mapLayerProps.level ].blue
        end
    end
    
end

-----------------------------------------------------------

Map.setObjectProperties = function(name, t, layer)
    
    if ( layer ) then
        local errorFound = true
        local mapLayer = Map.map.layers[layer]
        if ( mapLayer.properties.objectLayer ) then
            for i=1, #mapLayer.objects do
                local object = mapLayer.objects[i]
                if ( object.name == name ) then
                    mapLayer.objects[i] = t
                    errorFound = false
                end
            end
        else
            print("ERROR(setObjectProperties): The layer is not an Object Layer.")
        end
        if errorFound then
            print("Warning(setObjectProperties): Object Not Found.")
        end
        return
    end
    
    local errorFound = true
    for j=1, #Map.map.layers do
        local layer = j
        local mapLayer = Map.map.layers[layer]
        if ( mapLayer.properties.objectLayer ) then
            for i=1, #mapLayer.objects do
                local object = mapLayer.objects[i]
                if ( object.name == name ) then
                    mapLayer.objects[i] = t
                    errorFound = false
                    break
                end
            end
        end
        if ( not errorFound ) then
            break
        end
    end
    if ( errorFound ) then
        print("Warning(setObjectProperties): Object Not Found.")
    end
    
end

-----------------------------------------------------------

Map.getVisibleLayer = function(locX, locY)
    local layers = #Map.map.layers
    for i = #layers, 1, -1 do
        local mapLayer = layers[i]
        local vars = Map.masterGroup[i].vars
        if ( mapLayer.world[locX][locY] ~= 0 
            and vars.isVisible == true
            and vars.alpha > 0
            and not mapLayer.properties.objectLayer ) then
            return i
        end
    end
    return layers
end

Map.getVisibleLevel = function(locX, locY)
    local layer = Map.getVisibleLayer(locX, locY)
    return Map.map.layers[layer].properties.level
end

-----------------------------------------------------------

Map.getLayerProperties = function(layer)
    layer = layer or Map.refLayer
    if ( layer > #Map.map.layers ) then
        layer = #Map.map.layers
    elseif ( layer < 1 ) then
        layer = 1
    end
    return Map.map.layers[layer].properties
end

Map.getLayerProperty = function(layer, property)
    local properties = Map.getLayerProperties(layer)
    if ( properties == nil ) then
        return nil
    end
    return properties[property]
end

-----------------------------------------------------------

Map.getMapProperties = function()
    return Map.map.properties    
end

-----------------------------------------------------------

Map.getSpriteLayer = function(level)
    for i = 1, #Map.map.layers, 1 do
        local mapLayer = Map.map.layers[i]
        if ( mapLayer.properties.level == level and mapLayer.properties.spriteLayer ) then
            return i
        end
    end
    return nil
end

-----------------------------------------------------------

Map.getObjectLayer = function(level)
    for i=1, #Map.map.layers do
        local mapLayer = Map.map.layers[i]
        if ( mapLayer.properties.level == level and mapLayer.properties.objectLayer ) then
            return i
        end
    end
    return nil
end

-----------------------------------------------------------

Map.getLayers = function(params) 
    
    if ( not params ) then
        local array = {}
        for i=1, #Map.map.layers do
            array[#array + 1] = Map.map.layers[i]
        end    
        return array
    end
    
    if ( params.layer ) then            
        return Map.map.layers[ params.layer ]            
    elseif ( params.level ) then
        local array = {}
        for i=1, #Map.map.layers, 1 do
            local mapLayer = Map.map.layers[i]
            if ( mapLayer.properties.level == params.level ) then
                array[#array + 1] = mapLayer
            end
        end            
        return array            
    end        
    
    return nil    
end

-----------------------------------------------------------

Map.getLevel = function(layer)
    return Map.map.layers[layer].properties.level
end

-----------------------------------------------------------

Map.getMap = function()
    return Map.map
end

-----------------------------------------------------------

Map.getTileAt = function(params)
    
    local locX = params.locX
    local locY = params.locY
    local layer = params.layer
    
    if ( params.levelPosX ) then
        locX, locY = Map.levelToLoc(params.levelPosX, params.levelPosY)
    end
    
    if ( not layer ) then
        local values = {}
        for i=1, #Map.map.layers do
            local mapLayer = Map.map.layers[i]  
            if ( locX > mapLayer.width - Map.map.locOffsetX ) then
                locX = locX - mapLayer.width
            elseif ( locX < 1 - Map.map.locOffsetX ) then
                locX = locX + mapLayer.width
            end
            if ( locY > mapLayer.height - Map.map.locOffsetY ) then
                locY = locY - mapLayer.height
            elseif ( locY < 1 - Map.map.locOffsetY ) then
                locY = locY + mapLayer.height
            end
            values[i] = mapLayer.world[locX][locY]
        end
        
        return values
    end
    
    local mapLayer = Map.map.layers[layer]  
    
    if ( locX > mapLayer.width - Map.map.locOffsetX ) then
        locX = locX - mapLayer.width
    elseif ( locX < 1 - Map.map.locOffsetX ) then
        locX = locX + mapLayer.width
    end
    
    if ( locY > mapLayer.height - Map.map.locOffsetY ) then
        locY = locY - mapLayer.height
    elseif ( locY < 1 - Map.map.locOffsetY ) then
        locY = locY + mapLayer.height
    end
    
    return mapLayer.world[locX][locY]    
end

-----------------------------------------------------------

Map.getTileObj = function(locX, locY, layer)
    if ( not layer ) then
        layer = Map.refLayer
    end
    local xObj = Map.tileObjects[layer][locX]
    if ( xObj and xObj[locY] and not xObj[locY].noDraw ) then
        return xObj[locY]
    end
    return nil
end

-----------------------------------------------------------

Map.setTileProperties = function(tile, t)
    if ( tile == 0 ) then 
        return
    end
    local tileset = 1
    for i=1, #Map.map.tilesets, 1 do
        if ( tile >= Map.map.tilesets[i].firstgid ) then
            tileset = i
            break
        end
    end
    local tileStr = tostring(tile - 1)
    if ( not Map.map.tilesets[tileset].tileproperties ) then
        Map.map.tilesets[tileset].tileproperties = {}
    end
    Map.map.tilesets[tileset].tileproperties[tileStr] = t
end

-----------------------------------------------------------

Map.levelToLoc = function(xArg, yArg)
    local locX = math.ceil( xArg / Map.map.tilewidth )
    local locY = math.ceil( yArg / Map.map.tileheight )
    return locX, locY
end

Map.levelToLocX = function(xArg)
    local locX, locY = Map.levelToLoc(xArg, 0)
    return locX
end

Map.levelToLocY = function(yArg)
    local locX, locY = Map.levelToLoc(0, yArg)
    return locY
end

-----------------------------------------------------------

Map.screenToLevelPos = function(xArg, yArg, layer)    
    local item = Map.masterGroup[layer or Map.refLayer]
    local tempX, tempY = item:contentToLocal( xArg, yArg )
    if ( Map.map.orientation == Map.Type.Isometric ) then
        local isoPos = Map.isoUntransform2( tempX, tempY )
        local w = Map.map.tilewidth *0.5
        tempX = isoPos[1] - w
        tempY = isoPos[2] - w
    end
    return tempX, tempY
end

Map.screenToLevelPosX = function(xArg, layer)
    local tempX, tempY = Map.screenToLevelPos(xArg, 0, layer)
    return tempX
end

Map.screenToLevelPosY = function(yArg, layer)
    local tempX, tempY = Map.screenToLevelPos(0, yArg, layer)
    return tempY    
end

-----------------------------------------------------------

Map.screenToLoc = function(xArg, yArg, layer)
    local item = Map.masterGroup[layer or Map.refLayer]
    local tilewidth = Map.map.tilewidth
    local tileheight = Map.map.tileheight
    local locX, locY
    local tempX, tempY = item:contentToLocal(xArg, yArg)
    if ( Map.map.orientation == Map.Type.Isometric ) then
        local isoPos = Map.isoUntransform2(tempX, tempY)			
        tempX = isoPos[1] - tilewidth *0.5
        tempY = isoPos[2] - tileheight *0.5
    end
    locX = math.ceil( tempX / tilewidth )
    locY = math.ceil( tempY / tileheight )    
    return locX, locY
end

Map.screenToLocX = function(xArg, layer)
    local locX, locY = Map.screenToLoc(xArg, 0, layer)
    return locX
end

Map.screenToLocY = function(yArg, layer)
    local locX, locY = Map.screenToLoc(0, yArg, layer)
    return locY
end

-----------------------------------------------------------

Map.levelToScreenPos = function(xArg, yArg, layer)
    local item = Map.masterGroup[layer or Map.refLayer]
    local tempX, tempY
    if ( Map.map.orientation == Map.Type.Isometric ) then
        local x = xArg + Map.map.tilewidth *0.5
        local y = yArg + Map.map.tileheight *0.5
        local isoPos = Map.isoTransform2( x, y )
        xArg, yArg = item:localToContent(isoPos[1], isoPos[2])
    end
    tempX, tempY = item:localToContent(xArg, yArg)
    return tempX, tempY
end

Map.levelToScreenPosX = function(xArg, layer)
    local tempX, tempY = Map.levelToScreenPos(xArg, 0, layer)
    return tempX
end

Map.levelToScreenPosY = function(yArg, layer)
    local tempX, tempY = Map.levelToScreenPos(0, yArg, layer)
    return tempY
end

-----------------------------------------------------------

Map.locToScreenPos = function(xArg, yArg, layer)
    local item = Map.masterGroup[layer or Map.refLayer]
    local levelPosX, levelPosY
    if ( Map.map.orientation == Map.Type.Isometric ) then
        levelPosX = xArg * Map.map.tilewidth
        levelPosY = yArg * Map.map.tileheight
        local isoPos = Map.isoTransform2(levelPosX, levelPosY)
        levelPosX = isoPos[1]
        levelPosY = isoPos[2]
    else
        levelPosX = xArg * Map.map.tilewidth - (Map.map.tilewidth *0.5)
        levelPosY = yArg * Map.map.tileheight - (Map.map.tileheight *0.5)
    end
    local tempX, tempY = item:localToContent(levelPosX, levelPosY)
    return tempX, tempY
end

Map.locToScreenPosX = function(xArg, layer)
    local tempX, tempY = Map.locToScreenPos(xArg, 0, layer)
    return tempX
end

Map.locToScreenPosY = function(yArg, layer)
    local tempX, tempY = Map.locToScreenPos(0, yArg, layer)
    return tempX
end

-----------------------------------------------------------

Map.locToLevelPos = function(xArg, yArg)
    local tilewidth = Map.map.tilewidth
    local tileheight = Map.map.tileheight
    local levelPosX = xArg * tilewidth - (tilewidth *0.5)
    local levelPosY = yArg * tileheight - (tileheight *0.5)
    return levelPosX, levelPosY
end

Map.locToLevelPosX = function(xArg)
    local levelPosX, levelPosY = Map.locToLevelPos(xArg, 0)
    return levelPosX
end

Map.locToLevelPosY = function(yArg)
    local levelPosX, levelPosY = Map.locToLevelPos(0, yArg)
    return levelPosY
end

-----------------------------------------------------------

Map.tintLayer = function(layer, color, time, easing)
    if not layer then
        print("ERROR: No layer specificed. Defaulting to layer "..Map.refLayer..".")
        layer = Map.refLayer
    end
    if not color and not time then
        if Map.masterGroup[layer].vars.deltaTint then
            return true
        end
    else
        local distanceR = Map.map.layers[layer].redLight - color[1]
        local distanceG = Map.map.layers[layer].greenLight - color[2]
        local distanceB = Map.map.layers[layer].blueLight - color[3]
        time = math.ceil(time / Map.frameTime)
        if not time or time < 1 then
            time = 1
        end
        local deltaR = easingHelper(distanceR, time, easing)
        local deltaG = easingHelper(distanceG, time, easing)
        local deltaB = easingHelper(distanceB, time, easing)
        Map.masterGroup[layer].vars.deltaTint = {deltaR, deltaG, deltaB}
    end
end

Map.tintLevel = function(level, color, time, easing)
    if not level then
        print("ERROR: No level specified. Defaulting to level 1.")
        level = 1
    end
    if not color and not time then
        for i = 1, #Map.map.layers, 1 do
            if Map.map.layers[i].properties.level == level then
                if Map.masterGroup[i].vars.deltaTint then
                    return true
                end
            end
        end
    else
        for i = 1, #Map.map.layers, 1 do
            if Map.map.layers[i].properties.level == level then
                Map.tintLayer(i, color, time, easing)
            end
        end
    end
end

Map.tintMap = function(color, time, easing)
    if not color and not time then
        for i = 1, #Map.map.layers, 1 do
            if Map.masterGroup[i].vars.deltaTint then
                return true
            end
        end
    else
        for i = 1, #Map.map.layers, 1 do
            Map.tintLayer(i, color, time, easing)
        end
    end
end

Map.tintTile = function(locX, locY, layer, color, time, easing)
    if not locX or not locY or not layer then
        print("ERROR: Please specify locX, locY, and layer.")
    end
    if not color and not time then
        local tile = Map.getTileObj(locX, locY, layer)
        if Map.tintingTiles[tile] then
            return true
        end
    else
        local tile = Map.getTileObj(locX, locY, layer)
        if not tile.currentColor then
            tile.currentColor = {Map.map.layers[layer].redLight, 
                Map.map.layers[layer].greenLight, 
                Map.map.layers[layer].blueLight
            }
        end
        local distanceR = tile.currentColor[1] - color[1]
        local distanceG = tile.currentColor[2] - color[2]
        local distanceB = tile.currentColor[3] - color[3]
        time = math.ceil(time / Map.frameTime)
        if not time or time < 1 then
            time = 1
        end
        local deltaR = easingHelper(distanceR, time, easing)
        local deltaG = easingHelper(distanceG, time, easing)
        local deltaB = easingHelper(distanceB, time, easing)
        tile.deltaTint = {deltaR, deltaG, deltaB}
        Map.tintingTiles[tile] = tile
    end
end

-----------------------------------------------------------

return Map
