local Sprites = {}

local Camera = require("src.Camera")
local Map = require("src.Map")

Sprites.sprites = {}

Sprites.movingSprites = {}

Sprites.tempObjects = {}

Sprites.holdSprite = nil

Sprites.enableSpriteSorting = false

-----------------------------------------------------------

Sprites.removeSprite = function(sprite, destroyObject)
    if sprite.light then
        sprite.removeLight()
    end
    if Camera.cameraFocus == sprite then
        Camera.cameraFocus = nil
    end
    if Light.pointLightSource == sprite then
        Light.pointLightSource = nil
    end
    if Sprites.movingSprites[sprite] then
        Sprites.movingSprites[sprite] = nil
    end
    if sprite.name then
        if Sprites.sprites[sprite.name] then
            Sprites.sprites[sprite.name] = nil
        end
    end
    if destroyObject == nil or destroyObject == true then
        sprite:removeSelf()
        sprite = nil
    else
        local stage = display.getCurrentStage()
        stage:insert(sprite)
    end
end

-----------------------------------------------------------

Sprites.addSprite = function(sprite, setup)
    local layer
    if setup.level then
        layer = Map.spriteLayers[setup.level]
        if not layer then
            --print("Warning(addSprite): No Sprite Layer at level "..setup.level..". Defaulting to "..Map.refLayer..".")
            for i = 1, #Map.map.layers, 1 do
                if Map.map.layers[i].properties.level == setup.level then
                    layer = i
                    break
                end
            end
            if not layer then
                layer = Map.refLayer
            end
        end
    elseif setup.layer then
        layer = setup.layer
        if layer > #Map.map.layers then
            print("Warning(addSprite): Layer out of bounds. Defaulting to "..Map.refLayer..".")
            layer = Map.refLayer
        end
    else
        if sprite.parent.vars then
            layer = sprite.parent.vars.layer
        else
            --print("Warning(addSprite): You forgot to specify a Layer or level. Defaulting to "..Map.refLayer..".")
            layer = Map.refLayer
        end
    end
    
    if setup.color then
        sprite.color = setup.color
    end
    if sprite.lighting == nil then
        if setup.lighting ~= nil then
            sprite.lighting = setup.lighting
        else
            sprite.lighting = true
        end
    end
    
    if not setup.kind or setup.kind == "sprite" then
        sprite.objType = 1
        if sprite.lighting then
            if not sprite.color then
                sprite.color = {1, 1, 1}
            end
            local mL = Map.map.layers[setup.layer]
            sprite:setFillColor((mL.redLight)*sprite.color[1], (mL.greenLight)*sprite.color[2], (mL.blueLight)*sprite.color[3])
        end
    elseif setup.kind == "imageRect" then
        sprite.objType = 2
        if sprite.lighting then
            if not sprite.color then
                sprite.color = {1, 1, 1}
            end
            local mL = Map.map.layers[setup.layer]
            sprite:setFillColor((mL.redLight)*sprite.color[1], (mL.greenLight)*sprite.color[2], (mL.blueLight)*sprite.color[3])
        end
    elseif setup.kind == "group" then
        sprite.objType = 3
        if sprite.lighting then
            local mL = Map.map.layers[setup.layer]
            for i = 1, sprite.numChildren, 1 do
                if sprite[i]._class then
                    if sprite.color and not sprite[i].color then
                        sprite[i].color = sprite.color
                    end
                    if not sprite[i].color then
                        sprite[i].color = {1, 1, 1}
                    end
                    sprite[i]:setFillColor((mL.redLight)*sprite[i].color[1], (mL.greenLight)*sprite[i].color[2], (mL.blueLight)*sprite[i].color[3])
                end
            end
        end
    elseif setup.kind == "vector" then
        sprite.objType = 4
        if sprite.lighting then
            local mL = Map.map.layers[setup.layer]
            for i = 1, sprite.numChildren, 1 do
                if sprite[i]._class then
                    if sprite.color and not sprite[i].color then
                        sprite[i].color = sprite.color
                    end
                    if not sprite[i].color then
                        sprite[i].color = {1, 1, 1}
                    end
                    sprite[i]:setStrokeColor((mL.redLight)*sprite[i].color[1], (mL.greenLight)*sprite[i].color[2], (mL.blueLight)*sprite[i].color[3])
                end
            end
        end
    end
    
    if setup.followHeightMap then
        sprite.followHeightMap = setup.followHeightMap
    end
    if setup.heightMap then
        sprite.heightMap = setup.heightMap
    end
    if setup.offscreenPhysics then
        sprite.offscreenPhysics = true
    end
    if Camera.enableLighting then
        sprite.litBy = {}
        sprite.prevLitBy = {}
    end
    local spriteName = sprite.name or setup.name
    if not spriteName or spriteName == "" then
        spriteName = ""..sprite.x.."_"..sprite.y.."_"..layer
    end
    if Sprites.sprites[spriteName] and Sprites.sprites[spriteName] ~= sprite then
        local tempName = spriteName
        local counter = 1
        while Sprites.sprites[tempName] do
            tempName = ""..spriteName..counter
            counter = counter + 1
        end
        spriteName = tempName
    end
    sprite.name = spriteName
    if not Sprites.sprites[spriteName] then
        Sprites.sprites[spriteName] = sprite
    end
    sprite.park = false
    if setup.park == true then
        sprite.park = true
    end
    
    if setup.sortSprite ~= nil then
        sprite.sortSprite = setup.sortSprite
    else
        sprite.sortSprite = false
    end
    if setup.sortSpriteOnce ~= nil then
        sprite.sortSpriteOnce = setup.sortSpriteOnce
    end
    if not sprite.constrainToMap then
        sprite.constrainToMap = {true, true, true, true}
    end
    if setup.constrainToMap ~= nil then
        sprite.constrainToMap = setup.constrainToMap
    end
    sprite.locX = nil
    sprite.locY = nil
    sprite.levelPosX = nil
    sprite.levelPosY = nil
    if setup.layer then
        sprite.layer = setup.layer
        sprite.level = Map.map.layers[setup.layer].properties.level
    end
    sprite.deltaX = {}
    sprite.deltaY = {}
    sprite.velX = nil
    sprite.velY = nil
    sprite.isMoving = false
    if Map.map.orientation == Map.Type.Isometric then
        if setup.levelWidth then
            sprite.levelWidth = setup.levelWidth
            if sprite.objType ~= 3 then
                sprite.xScale = setup.levelWidth / (setup.sourceWidth or sprite.width)
            end
        else
            sprite.levelWidth = sprite.width
        end
        if setup.levelHeight then
            sprite.levelHeight = setup.levelHeight
            if sprite.objType ~= 3 then
                sprite.yScale = setup.levelHeight / (setup.sourceHeight or sprite.height)
            end
        else
            sprite.levelHeight = sprite.height
        end
        if setup.levelPosX then
            sprite.levelPosX = setup.levelPosX			
            sprite.locX = Map.levelToLocX(sprite.x)			
        elseif setup.locX then
            sprite.levelPosX = Map.locToLevelPosX(setup.locX)			
            sprite.locX = setup.locX			
        else
            sprite.levelPosX = sprite.x			
            sprite.locX = Map.levelToLocX(sprite.x)
        end
        if setup.levelPosY then
            sprite.levelPosY = setup.levelPosY
            sprite.locY = Map.levelToLocY(sprite.y)
        elseif setup.locY then
            sprite.levelPosY = Map.locToLevelPosX(setup.locY)
            sprite.locY = setup.locY
        else
            sprite.levelPosY = sprite.y
            sprite.locY = Map.levelToLocY(sprite.y)
        end
        local isoPos = Map.isoTransform2(sprite.levelPosX, sprite.levelPosY)
        sprite.x = isoPos[1]
        sprite.y = isoPos[2]
    else
        if setup.levelWidth then
            sprite.levelWidth = setup.levelWidth
            sprite.xScale = setup.levelWidth / (setup.sourceWidth or sprite.width)
        else
            sprite.levelWidth = sprite.width
        end
        if setup.levelHeight then
            sprite.levelHeight = setup.levelHeight
            sprite.yScale = setup.levelHeight / (setup.sourceHeight or sprite.height)
        else
            sprite.levelHeight = sprite.height
        end
        if setup.levelPosX then
            sprite.x = setup.levelPosX			
            sprite.locX = Map.levelToLocX(sprite.x)			
        elseif setup.locX then
            sprite.x = Map.locToLevelPosX(setup.locX)			
            sprite.locX = setup.locX			
        else
            sprite.locX = MaplevelToLocX(sprite.x)	
        end
        if setup.levelPosY then
            sprite.y = setup.levelPosY
            sprite.locY = Map.levelToLocY(sprite.y)
        elseif setup.locY then
            sprite.y = Map.locToLevelPosX(setup.locY)
            sprite.locY = setup.locY
        else
            sprite.locY = Map.levelToLocY(sprite.y)
        end
        sprite.levelPosX = sprite.x
        sprite.levelPosY = sprite.y
    end
    sprite.lightingListeners = {}
    sprite.addLightingListener = function(self, name, listener)
        sprite.lightingListeners[name] = true
        sprite:addEventListener(name, listener)
    end
    sprite.addLight = function(light)
        if Camera.enableLighting then
            sprite.light = light
            sprite.light.created = true
            if not sprite.light.id then
                sprite.light.id = Light.lightIDs
            end
            Light.lightIDs = Light.lightIDs + 1
            
            if not sprite.light.maxRange then
                local maxRange = sprite.light.range[1]
                for l = 1, 3, 1 do
                    if sprite.light.range[l] > maxRange then
                        maxRange = sprite.light.range[l]
                    end
                end
                sprite.light.maxRange = maxRange
            end
            
            if not sprite.light.levelPosX then
                sprite.light.levelPosX = sprite.levelPosX
                sprite.light.levelPosY = sprite.levelPosY
            end
            
            if not sprite.light.alternatorCounter then
                sprite.light.alternatorCounter = 1
            end
            
            if sprite.light.rays then
                sprite.light.areaIndex = 1
            end
            
            if sprite.light.layerRelative then
                sprite.light.layer = sprite.layer + sprite.light.layerRelative
                if sprite.light.layer < 1 then
                    sprite.light.layer = 1
                end
                if sprite.light.layer > #Map.map.layers then
                    sprite.light.layer = #Map.map.layers
                end
            end				
            
            if not sprite.light.layer then
                sprite.light.layer = sprite.layer
            end
            sprite.light.level = sprite.level
            sprite.light.dynamic = true
            sprite.light.area = {}
            sprite.light.sprite = sprite
            Map.map.lights[sprite.light.id] = sprite.light
        end
    end
    sprite.removeLight = function()
        if sprite.light.rays then
            sprite.light.areaIndex = 1
        end
        
        local length = #sprite.light.area
        for i = length, 1, -1 do
            local locX = sprite.light.area[i][1]
            local locY = sprite.light.area[i][2]
            sprite.light.area[i] = nil
            
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
            if sprite.light.layer then
                if Map.map.layers[sprite.light.layer].lighting[locX] and Map.map.layers[sprite.light.layer].lighting[locX][locY] then
                    Map.map.layers[sprite.light.layer].lighting[locX][locY][sprite.light.id] = nil
                    Map.map.lightToggle[locX][locY] = tonumber(system.getTimer())
                end	
            end
        end
        Map.map.lights[sprite.light.id] = nil
        sprite.light = nil
    end		
    if Camera.layerWrapX[i] and (sprite.wrapX == nil or sprite.wrapX == true) then
        while sprite.levelPosX < 1 - (Map.map.locOffsetX * Map.map.tilewidth) do
            sprite.levelPosX = sprite.levelPosX + Map.map.layers[i].width * Map.map.tilewidth
        end
        while sprite.levelPosX > Map.map.layers[i].width * Map.map.tilewidth - (Map.map.locOffsetX * Map.map.tilewidth) do
            sprite.levelPosX = sprite.levelPosX - Map.map.layers[i].width * Map.map.tilewidth
        end		
        if cameraX - sprite.x < Map.map.layers[i].width * Map.map.tilewidth / -2 then
            --wrap around to the left
            sprite.x = sprite.x - Map.map.layers[i].width * Map.map.tilewidth
        elseif cameraX - sprite.x > Map.map.layers[i].width * Map.map.tilewidth / 2 then
            --wrap around to the right
            sprite.x = sprite.x + Map.map.layers[i].width * Map.map.tilewidth
        end
    end		
    if Camera.layerWrapY[i] and (sprite.wrapY == nil or sprite.wrapY == true) then
        while sprite.levelPosY < 1 - (Map.map.locOffsetY * Map.map.tileheight) do
            sprite.levelPosY = sprite.levelPosY + Map.map.layers[i].height * Map.map.tileheight
        end
        while sprite.levelPosY > Map.map.layers[i].height * Map.map.tileheight - (Map.map.locOffsetY * Map.map.tileheight) do
            sprite.levelPosY = sprite.levelPosY - Map.map.layers[i].height * Map.map.tileheight
        end		
        if cameraY - sprite.y < Map.map.layers[i].height * Map.map.tileheight / -2 then
            --wrap around to the left
            sprite.y = sprite.y - Map.map.layers[i].height * Map.map.tileheight
        elseif cameraY - sprite.y > Map.map.layers[i].height * Map.map.tileheight / 2 then
            --wrap around to the right
            sprite.y = sprite.y + Map.map.layers[i].height * Map.map.tileheight
        end
    end		
    sprite.locX = math.ceil(sprite.levelPosX / Map.map.tilewidth)
    sprite.locY = math.ceil(sprite.levelPosY / Map.map.tileheight)
    if setup.offsetX then
        sprite.offsetX = setup.offsetX
        --sprite.anchorX = ((sprite.width / 2) - sprite.offsetX) / sprite.width
        sprite.anchorX = (((sprite.levelWidth or sprite.width) / 2) - sprite.offsetX) / (sprite.levelWidth or sprite.width)
    else
        sprite.offsetX = 0
    end
    if setup.offsetY then
        sprite.offsetY = setup.offsetY
        --sprite.anchorY = ((sprite.height / 2) - sprite.offsetY) / sprite.height
        sprite.anchorY = (((sprite.levelHeight or sprite.height) / 2) - sprite.offsetY) / (sprite.levelHeight or sprite.height)
    else
        sprite.offsetY = 0
    end
    if Map.map.orientation == Map.Type.Isometric then
        if Map.isoSort == 1 then
            Map.masterGroup[setup.layer][sprite.locX + sprite.locY - 1]:insert(sprite)
            sprite.row = sprite.locX + sprite.locY - 1
        else
            Map.masterGroup[(sprite.locX + (sprite.level - 1)) + (sprite.locY + (sprite.level - 1)) - 1].layers[setup.layer]:insert(sprite)
        end
    else
        Map.masterGroup[layer]:insert(sprite)
    end	
    
    if setup.properties then
        if not sprite.properties then
            sprite.properties = {}
        end
        for key,value in pairs(setup.properties) do
            sprite.properties[key] = value
        end
    end
    
    if setup.managePhysicsStates ~= nil then
        sprite.managePhysicsStates = setup.managePhysicsStates
    end
    
    return sprite		
end

return Sprites
