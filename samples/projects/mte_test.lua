#!/usr/bin/env lua

do

do
local _ENV = _ENV
package.preload[ "src.Sprites" ] = function( ... ) local arg = _G.arg;
local Sprites = {}

local Camera = require("src.Camera")
local Map = require("src.Map")
local Light = require("src.Light")

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

----------------------------------------------

Sprites.moveSpriteTo = function(params)
    local object = params.sprite
    local layer = object.layer or object.parent.layer or object.parent.vars.layer
    local time = params.time or 0
    params.time = math.ceil(params.time / Map.frameTime)
    local easing = params.transition or easing.linear		
    if params.locX then
        params.levelPosX = Map.locToLevelPosX(params.locX)
    end
    if params.locY then
        params.levelPosY = Map.locToLevelPosY(params.locY)
    end
    if not params.levelPosX then
        params.levelPosX = object.x
    end
    if not params.levelPosY then
        params.levelPosY = object.y
    end
    local constrain = {true, true, true, true}
    if params.constrainToMap ~= nil then
        constrain = params.constrainToMap
    elseif object.constrainToMap then
        constrain = object.constrainToMap
    end
    if params.override then
        if Sprites.movingSprites[object] then
            Sprites.movingSprites[object] = false
        end
    end		
    local easingHelper = function(distance, frames)
        local frameLength = display.fps
        local move = {}
        for i = 1, frames, 1 do
            move[i] = easing((i - 1) * frameLength, frameLength * frames, 0, 1000)
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
        local move3 = {}
        for i = 1, frames, 1 do
            move3[i] = move2[frames - (i - 1)] * mod2
        end
        return move3
    end		
    if not Sprites.movingSprites[object] then
        if Camera.layerWrapX[layer] then
            local oX = object.levelPosX or object.x
            if oX - params.levelPosX < -0.5 * Map.map.width * Map.map.tilewidth then
                params.levelPosX = params.levelPosX - Map.map.width * Map.map.tilewidth
            end
            if oX - params.levelPosX > 0.5 * Map.map.width * Map.map.tilewidth then
                params.levelPosX = params.levelPosX + Map.map.width * Map.map.tilewidth
            end
            local distanceX = params.levelPosX - oX
            object.deltaX = easingHelper(distanceX, params.time, params.easing)
            Sprites.movingSprites[params.sprite] = #object.deltaX
        else
            if params.levelPosX > Map.map.layers[layer].width * Map.map.tilewidth - (Map.map.locOffsetX * Map.map.tilewidth) and constrain[3] then
                params.levelPosX = Map.map.layers[layer].width * Map.map.tilewidth - (Map.map.locOffsetX * Map.map.tilewidth)
            end
            if params.levelPosX < 0 - (Map.map.locOffsetX * Map.map.tilewidth) and constrain[1] then
                params.levelPosX = 0 - (Map.map.locOffsetX * Map.map.tilewidth)
            end
            local distanceX = params.levelPosX - (object.levelPosX or object.x)
            object.deltaX = easingHelper(distanceX, params.time, params.easing)
            Sprites.movingSprites[params.sprite] = #object.deltaX
        end			
        if Camera.layerWrapY[layer] then
            local oY = object.levelPosY or object.y
            if oY - params.levelPosY < -0.5 * Map.map.height * Map.map.tileheight then
                params.levelPosY = params.levelPosY - Map.map.height * Map.map.tileheight
            end
            if oY - params.levelPosY > 0.5 * Map.map.height * Map.map.tileheight then
                params.levelPosY = params.levelPosY + Map.map.height * Map.map.tileheight
            end
            local distanceY = params.levelPosY - oY
            object.deltaY = easingHelper(distanceY, params.time, params.easing)
            Sprites.movingSprites[params.sprite] = #object.deltaY
        else
            if params.levelPosY > Map.map.layers[layer].height * Map.map.tileheight - (Map.map.locOffsetY * Map.map.tileheight) and constrain[4] then
                params.levelPosY = Map.map.layers[layer].height * Map.map.tileheight - (Map.map.locOffsetY * Map.map.tileheight)
            end
            if params.levelPosY < 0 - (Map.map.locOffsetY * Map.map.tileheight) and constrain[2] then
                params.levelPosY = 0 - (Map.map.locOffsetY * Map.map.tileheight)
            end
            local distanceY = params.levelPosY - (object.levelPosY or object.y)
            object.deltaY = easingHelper(distanceY, params.time, params.easing)
            Sprites.movingSprites[params.sprite] = #object.deltaY
        end			
        object.onComplete = params.onComplete
        object.isMoving = true
    end
end

---------------------------------------------

Sprites.sendSpriteTo = function(params)
    local sprite = params.sprite
    if params.locX then
        sprite.locX = params.locX
        sprite.locY = params.locY
        sprite.levelPosX, sprite.levelPosY = Map.locToLevelPos(params.locX, params.locY)
        sprite.x = sprite.levelPosX
        sprite.y = sprite.levelPosY
    elseif params.levelPosX then
        sprite.levelPosX = params.levelPosX
        sprite.levelPosY = params.levelPosY
        sprite.locX, sprite.locY = Map.levelToLoc(params.levelPosX, params.levelPosY)
        sprite.x = sprite.levelPosX
        sprite.y = sprite.levelPosY
    end
end

return Sprites

end
end

do
local _ENV = _ENV
package.preload[ "src.PhysicsData" ] = function( ... ) local arg = _G.arg;
local PhysicsData = {}

-----------------------------------------------------------

PhysicsData.defaultDensity = 1.0
PhysicsData.defaultFriction = 0.1
PhysicsData.defaultBounce = 0
PhysicsData.defaultBodyType = "static"
PhysicsData.defaultShape = nil
PhysicsData.defaultRadius = nil
PhysicsData.defaultFilter = nil
PhysicsData.layer = {}

PhysicsData.managePhysicsStates = true

PhysicsData.enablePhysicsByLayer = 0
PhysicsData.enablePhysics = {}

-----------------------------------------------------------

PhysicsData.enableBox2DPhysics = function(arg)
    if ( arg == "by layer" ) then
        PhysicsData.enablePhysicsByLayer = 1
    elseif ( arg == "all" or arg == "Map.map" or not arg ) then
        PhysicsData.enablePhysicsByLayer = 2
    end
end

-----------------------------------------------------------

return PhysicsData

end
end

do
local _ENV = _ENV
package.preload[ "src.Light" ] = function( ... ) local arg = _G.arg;
local Light = {}

local Map = require("src.Map")
local Camera = require("src.Camera")

-----------------------------------------------------------

Light.pointLightSource = nil  

Light.lightIDs = 0

Light.lightingData = { 
    fadeIn = 0.25, 
    fadeOut = 0.25, 
    refreshStyle = 2, 
    refreshAlternator = 4, 
    refreshCounter = 1, 
    resolution = 1.1
}

-----------------------------------------------------------

Light.processLight = function(layer, light)
    local style = 3
    local blockScaleXt = Map.map.tilewidth
    local blockScaleYt = Map.map.tileheight
    local range = light.maxRange
    local steps = (2 * range * 3.14) * Light.lightingData.resolution 
    local angleSteps = 360 / steps
    
    local r1, r2 = 1, 361
    if light.arc then
        r1 = light.arc[1]
        r2 = light.arc[2]
    end
    
    local levelPosX, levelPosY
    if not light.levelPosX then
        levelPosX = (light.locX * blockScaleXt - blockScaleXt * 0.5)
        levelPosY = (light.locY * blockScaleYt - blockScaleYt * 0.5)
    else
        levelPosX = light.levelPosX
        levelPosY = light.levelPosY
    end
    
    light.levelPosX = levelPosX
    light.levelPosY = levelPosY
    light.layer = layer
    local cLocX = math.round((levelPosX + (blockScaleXt * 0.5)) / blockScaleXt) --light.locX
    local cLocY = math.round((levelPosY + (blockScaleYt * 0.5)) / blockScaleYt) --light.locY
    light.locX = cLocX
    light.locY = cLocY
    local tileX = (cLocX - 1) * blockScaleXt
    local tileY = (cLocY - 1) * blockScaleYt
    local startX = levelPosX - tileX
    local startY = levelPosY - tileY
    
    local mL = Map.map.layers[layer].lighting
    local mW = Map.map.layers[layer].world
    local mT = Map.map.lightToggle
    local dynamic = light.dynamic
    local area = light.area
    local areaIndex = 1
    local worldSizeXt = Map.map.width
    local worldSizeYt = Map.map.height
    
    local id = light.id
    local falloff1 = light.falloff[1]
    local falloff2 = light.falloff[2]
    local falloff3 = light.falloff[3]
    
    if not mL[cLocX][cLocY] then
        mL[cLocX][cLocY] = {}
    end
    
    if not light.locations then
        light.locations = {}
    end
    
    local count = 0
    local time = tonumber(system.getTimer())
    light.lightToggle = time
    local toRadian = 0.01745329251994
    
    mL[cLocX][cLocY][id] = {}
    mL[cLocX][cLocY][id].light = {light.source[1], light.source[2], light.source[3]}
    mT[cLocX][cLocY] = time
    area[areaIndex] = {cLocX, cLocY}
    areaIndex = areaIndex + 1
    
    for i = r1, r2, angleSteps do
        local breakX = false
        local breakY = false
        local angleR = i * toRadian --math.rad(i)
        local x = (5 * math.cos(angleR))
        local y = (5 * math.sin(angleR))
        
        local red = light.source[1]
        local green = light.source[2]
        local blue = light.source[3]
        
        if x > 0 and y < 0 then
            --top right quadrant
            
            local Xangle = (i - 270) * toRadian --math.rad(i - 270)
            local XcheckY = tileY
            local XcheckX = math.tan(Xangle) * startY + levelPosX
            local XdeltaY = blockScaleYt
            local XdeltaX = math.tan(Xangle) * blockScaleYt
            local XlocX, XlocY =math.ceil(XcheckX / blockScaleXt),math.ceil(XcheckY / blockScaleYt)
            local Xdistance = startY / math.cos(Xangle) / blockScaleXt
            local XdeltaV = blockScaleYt / math.cos(Xangle) / blockScaleYt
            
            local Yangle = (360 - i) * toRadian --math.rad(360 - i)
            local YcheckY = levelPosY - (math.tan(Yangle) * (tileX + blockScaleXt - levelPosX))
            local YcheckX = tileX + blockScaleXt + 1
            local YdeltaY = math.tan(Yangle) * blockScaleXt
            local YdeltaX = blockScaleXt
            local YlocX, YlocY =math.ceil(YcheckX / blockScaleXt),math.ceil(YcheckY / blockScaleYt)
            local Ydistance = (YcheckX - levelPosX) / math.cos(Yangle) / blockScaleYt
            local YdeltaV = blockScaleXt / math.cos(Yangle) / blockScaleXt
            
            for j = 1, range * 2, 1 do
                count = count + 1
                
                if Camera.worldWrapX then
                    if XlocX > worldSizeXt - Map.map.locOffsetX then
                        XlocX = XlocX - worldSizeXt
                    end
                    if XlocX < 1 - Map.map.locOffsetX then
                        XlocX = XlocX + worldSizeXt
                    end
                    if YlocX > worldSizeXt - Map.map.locOffsetX then
                        YlocX = YlocX - worldSizeXt
                    end
                    if YlocX < 1 - Map.map.locOffsetX then
                        YlocX = YlocX + worldSizeXt
                    end
                end
                if Camera.worldWrapY then
                    if XlocY > worldSizeYt - Map.map.locOffsetY then
                        XlocY = XlocY - worldSizeYt
                    end
                    if XlocY < 1 - Map.map.locOffsetY then
                        XlocY = XlocY + worldSizeYt
                    end
                    if YlocY > worldSizeYt - Map.map.locOffsetY then
                        YlocY = YlocY - worldSizeYt
                    end
                    if YlocY < 1 - Map.map.locOffsetY then
                        YlocY = YlocY + worldSizeYt
                    end
                end
                
                if XlocX < 1 - Map.map.locOffsetX or XlocX > worldSizeXt - Map.map.locOffsetX or XlocY < 1 - Map.map.locOffsetY or XlocY > worldSizeYt - Map.map.locOffsetY then
                    breakX = true
                end
                if YlocX < 1 - Map.map.locOffsetX or YlocX > worldSizeXt - Map.map.locOffsetX or YlocY < 1 - Map.map.locOffsetY or YlocY > worldSizeYt - Map.map.locOffsetY then
                    breakY = true
                end
                if breakX and breakY then
                    break
                end
                
                local red1,green1,blue1
                
                if Xdistance < Ydistance then
                    if Xdistance <= range then
                        mT[XlocX][XlocY] = time
                        area[areaIndex] = {XlocX, XlocY}
                        areaIndex = areaIndex + 1
                        red1 = red - (falloff1 * Xdistance)
                        green1 = green - (falloff2 * Xdistance)
                        blue1 = blue - (falloff3 * Xdistance)
                        if not mL[XlocX][XlocY] then
                            mL[XlocX][XlocY] = {}						
                        elseif mL[XlocX][XlocY][id] then							
                            if style == 1 then
                                local tempLight = mL[XlocX][XlocY][id]
                                red1 = (red1 + tempLight.light[1]) / 2
                                green1 = (green1 + tempLight.light[2]) / 2
                                blue1 = (blue1 + tempLight.light[3]) / 2
                            elseif style == 2 then
                                local tempLight = mL[XlocX][XlocY][id]
                                if red1 > tempLight.light[1] then
                                    red1 = tempLight.light[1]
                                end
                                if green1 > tempLight.light[2] then
                                    green1 = tempLight.light[2]
                                end
                                if blue1 > tempLight.light[3] then
                                    blue1 = tempLight.light[3]
                                end
                            else
                                local tempLight = mL[XlocX][XlocY][id]
                                if red1 < tempLight.light[1] then
                                    red1 = tempLight.light[1]
                                end
                                if green1 < tempLight.light[2] then
                                    green1 = tempLight.light[2]
                                end
                                if blue1 < tempLight.light[3] then
                                    blue1 = tempLight.light[3]
                                end
                            end
                        end
                        mL[XlocX][XlocY][id] = {}
                        mL[XlocX][XlocY][id].light = {red1, green1, blue1}
                        
                        if Map.map.lightingData[mW[XlocX][XlocY]] then
                            local temp = Map.map.lightingData[mW[XlocX][XlocY]]
                            red = red - temp.opacity[1]
                            green = green - temp.opacity[2]
                            blue = blue - temp.opacity[3]
                        end
                        
                        XcheckX = XcheckX + XdeltaX
                        XcheckY = XcheckY - XdeltaY
                        XlocX, XlocY =math.ceil(XcheckX / blockScaleXt), XlocY - 1
                        Xdistance = Xdistance + XdeltaV
                    end
                else
                    if Ydistance <= range then
                        mT[YlocX][YlocY] = time
                        area[areaIndex] = {YlocX, YlocY}
                        areaIndex = areaIndex + 1
                        red1 = red - (falloff1 * Ydistance)
                        green1 = green - (falloff2 * Ydistance)
                        blue1 = blue - (falloff3 * Ydistance)
                        if not mL[YlocX][YlocY] then
                            mL[YlocX][YlocY] = {}						
                        elseif mL[YlocX][YlocY][id] then
                            if style == 1 then
                                local tempLight = mL[YlocX][YlocY][id]
                                red1 = (red1 + tempLight.light[1]) / 2
                                green1 = (green1 + tempLight.light[2]) / 2
                                blue1 = (blue1 + tempLight.light[3]) / 2
                            elseif style == 2 then
                                local tempLight = mL[YlocX][YlocY][id]
                                if red1 > tempLight.light[1] then
                                    red1 = tempLight.light[1]
                                end
                                if green1 > tempLight.light[2] then
                                    green1 = tempLight.light[2]
                                end
                                if blue1 > tempLight.light[3] then
                                    blue1 = tempLight.light[3]
                                end
                            else
                                local tempLight = mL[YlocX][YlocY][id]
                                if red1 < tempLight.light[1] then
                                    red1 = tempLight.light[1]
                                end
                                if green1 < tempLight.light[2] then
                                    green1 = tempLight.light[2]
                                end
                                if blue1 < tempLight.light[3] then
                                    blue1 = tempLight.light[3]
                                end
                            end
                        end
                        mL[YlocX][YlocY][id] = {}
                        mL[YlocX][YlocY][id].light = {red1, green1, blue1}
                        
                        if Map.map.lightingData[mW[YlocX][YlocY]] then
                            local temp = Map.map.lightingData[mW[YlocX][YlocY]]
                            red = red - temp.opacity[1]
                            green = green - temp.opacity[2]
                            blue = blue - temp.opacity[3]
                        end	
                        
                        YcheckX = YcheckX + YdeltaX
                        YcheckY = YcheckY - YdeltaY
                        YlocX, YlocY = YlocX + 1,math.ceil(YcheckY / blockScaleYt)
                        Ydistance = Ydistance + YdeltaV
                    end
                end				
                
                if red1 <= 0 and green1 <= 0 and blue1 <= 0 then
                    break
                end
                
                if Xdistance > range and Ydistance > range then
                    break
                end
            end
            
        elseif x > 0 and y > 0 then
            --bottom right quadrant
            
            local Xangle = (90 - i) * toRadian --math.rad(90 - i)
            local XcheckY = tileY + blockScaleYt + 1
            local XcheckX = math.tan(Xangle) * (XcheckY - levelPosY) + levelPosX
            local XdeltaY = blockScaleYt
            local XdeltaX = math.tan(Xangle) * blockScaleYt
            local XlocX, XlocY =math.ceil(XcheckX / blockScaleXt),math.ceil(XcheckY / blockScaleYt)
            local Xdistance = (XcheckY - levelPosY) / math.cos(Xangle) / blockScaleXt
            local XdeltaV = blockScaleYt / math.cos(Xangle) / blockScaleYt
            
            local Yangle = i * toRadian --math.rad(i)
            local YcheckY = math.tan(Yangle) * (tileX + blockScaleXt - levelPosX) + levelPosY
            local YcheckX = tileX + blockScaleXt + 1
            local YdeltaY = math.tan(Yangle) * blockScaleXt
            local YdeltaX = blockScaleXt
            local YlocX, YlocY =math.ceil(YcheckX / blockScaleXt),math.ceil(YcheckY / blockScaleYt)
            local Ydistance = (YcheckX - levelPosX) / math.cos(Yangle) / blockScaleYt
            local YdeltaV = blockScaleXt / math.cos(Yangle) / blockScaleXt
            
            for j = 1, range * 2, 1 do
                count = count + 1
                
                if Camera.worldWrapX then
                    if XlocX > worldSizeXt - Map.map.locOffsetX then
                        XlocX = XlocX - worldSizeXt
                    end
                    if XlocX < 1 - Map.map.locOffsetX then
                        XlocX = XlocX + worldSizeXt
                    end
                    if YlocX > worldSizeXt - Map.map.locOffsetX then
                        YlocX = YlocX - worldSizeXt
                    end
                    if YlocX < 1 - Map.map.locOffsetX then
                        YlocX = YlocX + worldSizeXt
                    end
                end
                if Camera.worldWrapY then
                    if XlocY > worldSizeYt - Map.map.locOffsetY then
                        XlocY = XlocY - worldSizeYt
                    end
                    if XlocY < 1 - Map.map.locOffsetY then
                        XlocY = XlocY + worldSizeYt
                    end
                    if YlocY > worldSizeYt - Map.map.locOffsetY then
                        YlocY = YlocY - worldSizeYt
                    end
                    if YlocY < 1 - Map.map.locOffsetY then
                        YlocY = YlocY + worldSizeYt
                    end
                end
                
                if XlocX < 1 - Map.map.locOffsetX or XlocX > worldSizeXt - Map.map.locOffsetX or XlocY < 1 - Map.map.locOffsetY or XlocY > worldSizeYt - Map.map.locOffsetY then
                    breakX = true
                end
                if YlocX < 1 - Map.map.locOffsetX or YlocX > worldSizeXt - Map.map.locOffsetX or YlocY < 1 - Map.map.locOffsetY or YlocY > worldSizeYt - Map.map.locOffsetY then
                    breakY = true
                end
                if breakX and breakY then
                    break
                end
                
                local red1,green1,blue1
                
                if Xdistance < Ydistance then
                    if Xdistance <= range then
                        mT[XlocX][XlocY] = time
                        area[areaIndex] = {XlocX, XlocY}
                        areaIndex = areaIndex + 1
                        red1 = red - (falloff1 * Xdistance)
                        green1 = green - (falloff2 * Xdistance)
                        blue1 = blue - (falloff3 * Xdistance)
                        if not mL[XlocX][XlocY] then
                            mL[XlocX][XlocY] = {}						
                        elseif mL[XlocX][XlocY][id] then
                            if style == 1 then
                                local tempLight = mL[XlocX][XlocY][id]
                                red1 = (red1 + tempLight.light[1]) / 2
                                green1 = (green1 + tempLight.light[2]) / 2
                                blue1 = (blue1 + tempLight.light[3]) / 2
                            elseif style == 2 then
                                local tempLight = mL[XlocX][XlocY][id]
                                if red1 > tempLight.light[1] then
                                    red1 = tempLight.light[1]
                                end
                                if green1 > tempLight.light[2] then
                                    green1 = tempLight.light[2]
                                end
                                if blue1 > tempLight.light[3] then
                                    blue1 = tempLight.light[3]
                                end
                            else
                                local tempLight = mL[XlocX][XlocY][id]
                                if red1 < tempLight.light[1] then
                                    red1 = tempLight.light[1]
                                end
                                if green1 < tempLight.light[2] then
                                    green1 = tempLight.light[2]
                                end
                                if blue1 < tempLight.light[3] then
                                    blue1 = tempLight.light[3]
                                end
                            end
                        end
                        mL[XlocX][XlocY][id] = {}
                        mL[XlocX][XlocY][id].light = {red1, green1, blue1}
                        
                        if Map.map.lightingData[mW[XlocX][XlocY]] then
                            local temp = Map.map.lightingData[mW[XlocX][XlocY]]
                            red = red - temp.opacity[1]
                            green = green - temp.opacity[2]
                            blue = blue - temp.opacity[3]
                        end
                        
                        XcheckX = XcheckX + XdeltaX
                        XcheckY = XcheckY + XdeltaY
                        XlocX, XlocY =math.ceil(XcheckX / blockScaleXt), XlocY + 1
                        Xdistance = Xdistance + XdeltaV
                    end
                else
                    if Ydistance <= range then
                        mT[YlocX][YlocY] = time
                        area[areaIndex] = {YlocX, YlocY}
                        areaIndex = areaIndex + 1
                        red1 = red - (falloff1 * Ydistance)
                        green1 = green - (falloff2 * Ydistance)
                        blue1 = blue - (falloff3 * Ydistance)
                        if not mL[YlocX][YlocY] then
                            mL[YlocX][YlocY] = {}						
                        elseif mL[YlocX][YlocY][id] then
                            if style == 1 then
                                local tempLight = mL[YlocX][YlocY][id]
                                red1 = (red1 + tempLight.light[1]) / 2
                                green1 = (green1 + tempLight.light[2]) / 2
                                blue1 = (blue1 + tempLight.light[3]) / 2
                            elseif style == 2 then
                                local tempLight = mL[YlocX][YlocY][id]
                                if red1 > tempLight.light[1] then
                                    red1 = tempLight.light[1]
                                end
                                if green1 > tempLight.light[2] then
                                    green1 = tempLight.light[2]
                                end
                                if blue1 > tempLight.light[3] then
                                    blue1 = tempLight.light[3]
                                end
                            else
                                local tempLight = mL[YlocX][YlocY][id]
                                if red1 < tempLight.light[1] then
                                    red1 = tempLight.light[1]
                                end
                                if green1 < tempLight.light[2] then
                                    green1 = tempLight.light[2]
                                end
                                if blue1 < tempLight.light[3] then
                                    blue1 = tempLight.light[3]
                                end
                            end
                        end
                        mL[YlocX][YlocY][id] = {}
                        mL[YlocX][YlocY][id].light = {red1, green1, blue1}
                        
                        if Map.map.lightingData[mW[YlocX][YlocY]] then
                            local temp = Map.map.lightingData[mW[YlocX][YlocY]]
                            red = red - temp.opacity[1]
                            green = green - temp.opacity[2]
                            blue = blue - temp.opacity[3]
                        end	
                        
                        YcheckX = YcheckX + YdeltaX
                        YcheckY = YcheckY + YdeltaY
                        YlocX, YlocY = YlocX + 1,math.ceil(YcheckY / blockScaleYt)
                        Ydistance = Ydistance + YdeltaV
                    end
                end
                
                
                if red1 <= 0 and green1 <= 0 and blue1 <= 0 then
                    break
                end
                
                if Xdistance > range and Ydistance > range then
                    break
                end
            end
            
        elseif x < 0 and y > 0 then
            --bottom left quadrant
            
            local Xangle = (i - 90) * toRadian --math.rad(i - 90)
            local XcheckY = tileY + blockScaleYt + 1
            local XcheckX = levelPosX - (math.tan(Xangle) * (XcheckY - levelPosY))
            local XdeltaY = blockScaleYt
            local XdeltaX = math.tan(Xangle) * blockScaleYt
            local XlocX, XlocY =math.ceil(XcheckX / blockScaleXt),math.ceil(XcheckY / blockScaleYt)
            local Xdistance = (XcheckY - levelPosY) / math.cos(Xangle) / blockScaleXt
            local XdeltaV = blockScaleYt / math.cos(Xangle) / blockScaleYt
            
            local Yangle = (180 - i) * toRadian --math.rad(180 - i)
            local YcheckY = math.tan(Yangle) * (levelPosX - tileX) + levelPosY
            local YcheckX = tileX 
            local YdeltaY = math.tan(Yangle) * blockScaleXt
            local YdeltaX = blockScaleXt
            local YlocX, YlocY =math.ceil(YcheckX / blockScaleXt),math.ceil(YcheckY / blockScaleYt)
            local Ydistance = startX / math.cos(Yangle) / blockScaleYt
            local YdeltaV = blockScaleXt / math.cos(Yangle) / blockScaleXt
            
            for j = 1, range * 2, 1 do
                count = count + 1
                
                if Camera.worldWrapX then
                    if XlocX > worldSizeXt - Map.map.locOffsetX then
                        XlocX = XlocX - worldSizeXt
                    end
                    if XlocX < 1 - Map.map.locOffsetX then
                        XlocX = XlocX + worldSizeXt
                    end
                    if YlocX > worldSizeXt - Map.map.locOffsetX then
                        YlocX = YlocX - worldSizeXt
                    end
                    if YlocX < 1 - Map.map.locOffsetX then
                        YlocX = YlocX + worldSizeXt
                    end
                end
                if Camera.worldWrapY then
                    if XlocY > worldSizeYt - Map.map.locOffsetY then
                        XlocY = XlocY - worldSizeYt
                    end
                    if XlocY < 1 - Map.map.locOffsetY then
                        XlocY = XlocY + worldSizeYt
                    end
                    if YlocY > worldSizeYt - Map.map.locOffsetY then
                        YlocY = YlocY - worldSizeYt
                    end
                    if YlocY < 1 - Map.map.locOffsetY then
                        YlocY = YlocY + worldSizeYt
                    end
                end
                
                if XlocX < 1 - Map.map.locOffsetX or XlocX > worldSizeXt - Map.map.locOffsetX or XlocY < 1 - Map.map.locOffsetY or XlocY > worldSizeYt - Map.map.locOffsetY then
                    breakX = true
                end
                if YlocX < 1 - Map.map.locOffsetX or YlocX > worldSizeXt - Map.map.locOffsetX or YlocY < 1 - Map.map.locOffsetY or YlocY > worldSizeYt - Map.map.locOffsetY then
                    breakY = true
                end
                if breakX and breakY then
                    break
                end
                
                local red1, green1, blue1
                
                if Xdistance < Ydistance then
                    if Xdistance <= range then
                        mT[XlocX][XlocY] = time
                        area[areaIndex] = {XlocX, XlocY}
                        areaIndex = areaIndex + 1
                        red1 = red - (falloff1 * Xdistance)
                        green1 = green - (falloff2 * Xdistance)
                        blue1 = blue - (falloff3 * Xdistance)
                        if not mL[XlocX][XlocY] then
                            mL[XlocX][XlocY] = {}						
                        elseif mL[XlocX][XlocY][id] then
                            if style == 1 then
                                local tempLight = mL[XlocX][XlocY][id]
                                red1 = (red1 + tempLight.light[1]) / 2
                                green1 = (green1 + tempLight.light[2]) / 2
                                blue1 = (blue1 + tempLight.light[3]) / 2
                            elseif style == 2 then
                                local tempLight = mL[XlocX][XlocY][id]
                                if red1 > tempLight.light[1] then
                                    red1 = tempLight.light[1]
                                end
                                if green1 > tempLight.light[2] then
                                    green1 = tempLight.light[2]
                                end
                                if blue1 > tempLight.light[3] then
                                    blue1 = tempLight.light[3]
                                end
                            else
                                local tempLight = mL[XlocX][XlocY][id]
                                if red1 < tempLight.light[1] then
                                    red1 = tempLight.light[1]
                                end
                                if green1 < tempLight.light[2] then
                                    green1 = tempLight.light[2]
                                end
                                if blue1 < tempLight.light[3] then
                                    blue1 = tempLight.light[3]
                                end
                            end
                        end
                        mL[XlocX][XlocY][id] = {}
                        mL[XlocX][XlocY][id].light = {red1, green1, blue1}
                        
                        if Map.map.lightingData[mW[XlocX][XlocY]] then
                            local temp = Map.map.lightingData[mW[XlocX][XlocY]]
                            red = red - temp.opacity[1]
                            green = green - temp.opacity[2]
                            blue = blue - temp.opacity[3]
                        end
                        
                        XcheckX = XcheckX - XdeltaX
                        XcheckY = XcheckY + XdeltaY
                        XlocX, XlocY =math.ceil(XcheckX / blockScaleXt), XlocY + 1
                        Xdistance = Xdistance + XdeltaV
                    end
                else
                    if Ydistance <= range then
                        mT[YlocX][YlocY] = time
                        area[areaIndex] = {YlocX, YlocY}
                        areaIndex = areaIndex + 1
                        red1 = red - (falloff1 * Ydistance)
                        green1 = green - (falloff2 * Ydistance)
                        blue1 = blue - (falloff3 * Ydistance)
                        if not mL[YlocX][YlocY] then
                            mL[YlocX][YlocY] = {}						
                        elseif mL[YlocX][YlocY][id] then
                            if style == 1 then
                                local tempLight = mL[YlocX][YlocY][id]
                                red1 = (red1 + tempLight.light[1]) / 2
                                green1 = (green1 + tempLight.light[2]) / 2
                                blue1 = (blue1 + tempLight.light[3]) / 2
                            elseif style == 2 then
                                local tempLight = mL[YlocX][YlocY][id]
                                if red1 > tempLight.light[1] then
                                    red1 = tempLight.light[1]
                                end
                                if green1 > tempLight.light[2] then
                                    green1 = tempLight.light[2]
                                end
                                if blue1 > tempLight.light[3] then
                                    blue1 = tempLight.light[3]
                                end
                            else
                                local tempLight = mL[YlocX][YlocY][id]
                                if red1 < tempLight.light[1] then
                                    red1 = tempLight.light[1]
                                end
                                if green1 < tempLight.light[2] then
                                    green1 = tempLight.light[2]
                                end
                                if blue1 < tempLight.light[3] then
                                    blue1 = tempLight.light[3]
                                end
                            end
                        end
                        mL[YlocX][YlocY][id] = {}
                        mL[YlocX][YlocY][id].light = {red1, green1, blue1}
                        
                        if Map.map.lightingData[mW[YlocX][YlocY]] then
                            local temp = Map.map.lightingData[mW[YlocX][YlocY]]
                            red = red - temp.opacity[1]
                            green = green - temp.opacity[2]
                            blue = blue - temp.opacity[3]
                        end	
                        
                        YcheckX = YcheckX - YdeltaX
                        YcheckY = YcheckY + YdeltaY
                        YlocX, YlocY = YlocX - 1,math.ceil(YcheckY / blockScaleYt)
                        Ydistance = Ydistance + YdeltaV
                    end
                end
                
                if red1 <= 0 and green1 <= 0 and blue1 <= 0 then
                    break
                end
                
                if Xdistance > range and Ydistance > range then
                    break
                end				
            end
            
        elseif x < 0 and y < 0 then
            --top left quadrant
            
            local Xangle = (270 - i) * toRadian --math.rad(270 - i)
            local XcheckY = tileY
            local XcheckX = levelPosX - (math.tan(Xangle) * (levelPosY - tileY))
            local XdeltaY = blockScaleYt
            local XdeltaX = math.tan(Xangle) * blockScaleYt
            local XlocX, XlocY =math.ceil(XcheckX / blockScaleXt),math.ceil(XcheckY / blockScaleYt)
            local Xdistance = startY / math.cos(Xangle) / blockScaleXt
            local XdeltaV = blockScaleYt / math.cos(Xangle) / blockScaleYt
            
            local Yangle = (i - 180) * toRadian --math.rad(i - 180)
            local YcheckY = levelPosY - (math.tan(Yangle) * (levelPosX - tileX))
            local YcheckX = tileX
            local YdeltaY = math.tan(Yangle) * blockScaleXt
            local YdeltaX = blockScaleXt
            local YlocX, YlocY =math.ceil(YcheckX / blockScaleXt),math.ceil(YcheckY / blockScaleYt)
            local Ydistance = startX / math.cos(Yangle) / blockScaleYt
            local YdeltaV = blockScaleXt / math.cos(Yangle) / blockScaleXt
            
            for j = 1, range * 2, 1 do
                count = count + 1
                
                if Camera.worldWrapX then
                    if XlocX > worldSizeXt - Map.map.locOffsetX then
                        XlocX = XlocX - worldSizeXt
                    end
                    if XlocX < 1 - Map.map.locOffsetX then
                        XlocX = XlocX + worldSizeXt
                    end
                    if YlocX > worldSizeXt - Map.map.locOffsetX then
                        YlocX = YlocX - worldSizeXt
                    end
                    if YlocX < 1 - Map.map.locOffsetX then
                        YlocX = YlocX + worldSizeXt
                    end
                end
                if Camera.worldWrapY then
                    if XlocY > worldSizeYt - Map.map.locOffsetY then
                        XlocY = XlocY - worldSizeYt
                    end
                    if XlocY < 1 - Map.map.locOffsetY then
                        XlocY = XlocY + worldSizeYt
                    end
                    if YlocY > worldSizeYt - Map.map.locOffsetY then
                        YlocY = YlocY - worldSizeYt
                    end
                    if YlocY < 1 - Map.map.locOffsetY then
                        YlocY = YlocY + worldSizeYt
                    end
                end
                
                if XlocX < 1 - Map.map.locOffsetX or XlocX > worldSizeXt - Map.map.locOffsetX or XlocY < 1 - Map.map.locOffsetY or XlocY > worldSizeYt - Map.map.locOffsetY then
                    breakX = true
                end
                if YlocX < 1 - Map.map.locOffsetX or YlocX > worldSizeXt - Map.map.locOffsetX or YlocY < 1 - Map.map.locOffsetY or YlocY > worldSizeYt - Map.map.locOffsetY then
                    breakY = true
                end
                if breakX and breakY then
                    break
                end
                
                local red1, green1, blue1
                
                if Xdistance < Ydistance then
                    if Xdistance <= range then
                        mT[XlocX][XlocY] = time
                        area[areaIndex] = {XlocX, XlocY}
                        areaIndex = areaIndex + 1
                        red1 = red - (falloff1 * Xdistance)
                        green1 = green - (falloff2 * Xdistance)
                        blue1 = blue - (falloff3 * Xdistance)
                        if not mL[XlocX][XlocY] then
                            mL[XlocX][XlocY] = {}						
                        elseif mL[XlocX][XlocY][id] then
                            if style == 1 then
                                local tempLight = mL[XlocX][XlocY][id]
                                red1 = (red1 + tempLight.light[1]) / 2
                                green1 = (green1 + tempLight.light[2]) / 2
                                blue1 = (blue1 + tempLight.light[3]) / 2
                            elseif style == 2 then
                                local tempLight = mL[XlocX][XlocY][id]
                                if red1 > tempLight.light[1] then
                                    red1 = tempLight.light[1]
                                end
                                if green1 > tempLight.light[2] then
                                    green1 = tempLight.light[2]
                                end
                                if blue1 > tempLight.light[3] then
                                    blue1 = tempLight.light[3]
                                end
                            else
                                local tempLight = mL[XlocX][XlocY][id]
                                if red1 < tempLight.light[1] then
                                    red1 = tempLight.light[1]
                                end
                                if green1 < tempLight.light[2] then
                                    green1 = tempLight.light[2]
                                end
                                if blue1 < tempLight.light[3] then
                                    blue1 = tempLight.light[3]
                                end
                            end
                        end
                        mL[XlocX][XlocY][id] = {}
                        mL[XlocX][XlocY][id].light = {red1, green1, blue1}
                        
                        if Map.map.lightingData[mW[XlocX][XlocY]] then
                            local temp = Map.map.lightingData[mW[XlocX][XlocY]]
                            red = red - temp.opacity[1]
                            green = green - temp.opacity[2]
                            blue = blue - temp.opacity[3]
                        end
                        
                        XcheckX = XcheckX - XdeltaX
                        XcheckY = XcheckY - XdeltaY
                        XlocX, XlocY =math.ceil(XcheckX / blockScaleXt), XlocY - 1
                        Xdistance = Xdistance + XdeltaV
                    end
                else
                    if Ydistance <= range then
                        mT[YlocX][YlocY] = time
                        area[areaIndex] = {YlocX, YlocY}
                        areaIndex = areaIndex + 1
                        red1 = red - (falloff1 * Ydistance)
                        green1 = green - (falloff2 * Ydistance)
                        blue1 = blue - (falloff3 * Ydistance)
                        if not mL[YlocX][YlocY] then
                            mL[YlocX][YlocY] = {}						
                        elseif mL[YlocX][YlocY][id] then
                            if style == 1 then
                                local tempLight = mL[YlocX][YlocY][id]
                                red1 = (red1 + tempLight.light[1]) / 2
                                green1 = (green1 + tempLight.light[2]) / 2
                                blue1 = (blue1 + tempLight.light[3]) / 2
                            elseif style == 2 then
                                local tempLight = mL[YlocX][YlocY][id]
                                if red1 > tempLight.light[1] then
                                    red1 = tempLight.light[1]
                                end
                                if green1 > tempLight.light[2] then
                                    green1 = tempLight.light[2]
                                end
                                if blue1 > tempLight.light[3] then
                                    blue1 = tempLight.light[3]
                                end
                            else
                                local tempLight = mL[YlocX][YlocY][id]
                                if red1 < tempLight.light[1] then
                                    red1 = tempLight.light[1]
                                end
                                if green1 < tempLight.light[2] then
                                    green1 = tempLight.light[2]
                                end
                                if blue1 < tempLight.light[3] then
                                    blue1 = tempLight.light[3]
                                end
                            end
                        end
                        mL[YlocX][YlocY][id] = {}
                        mL[YlocX][YlocY][id].light = {red1, green1, blue1}
                        
                        if Map.map.lightingData[mW[YlocX][YlocY]] then
                            local temp = Map.map.lightingData[mW[YlocX][YlocY]]
                            red = red - temp.opacity[1]
                            green = green - temp.opacity[2]
                            blue = blue - temp.opacity[3]
                        end	
                        
                        YcheckX = YcheckX - YdeltaX
                        YcheckY = YcheckY - YdeltaY
                        YlocX, YlocY = YlocX - 1,math.ceil(YcheckY / blockScaleYt)
                        Ydistance = Ydistance + YdeltaV
                    end
                end
                
                
                if red1 <= 0 and green1 <= 0 and blue1 <= 0 then
                    break
                end
                
                if Xdistance > range and Ydistance > range then
                    break
                end
            end			
        end
    end
end



-----------------------------------------------------------



Light.processLightRay = function(layer, light, ray)
    local style = 3
    local blockScaleXt = Map.map.tilewidth
    local blockScaleYt = Map.map.tileheight
    local range = light.maxRange
    
    local levelPosX, levelPosY
    if not light.levelPosX then
        levelPosX = (light.locX * blockScaleXt - blockScaleXt * 0.5)
        levelPosY = (light.locY * blockScaleYt - blockScaleYt * 0.5)
    else
        levelPosX = light.levelPosX
        levelPosY = light.levelPosY
    end
    
    light.levelPosX = levelPosX
    light.levelPosY = levelPosY
    light.layer = layer
    local cLocX = math.round((levelPosX + (blockScaleXt * 0.5)) / blockScaleXt)
    local cLocY = math.round((levelPosY + (blockScaleYt * 0.5)) / blockScaleYt)
    local tileX = (cLocX - 1) * blockScaleXt
    local tileY = (cLocY - 1) * blockScaleYt
    local startX = levelPosX - tileX
    local startY = levelPosY - tileY
    
    local mL = Map.map.layers[layer].lighting
    local mW = Map.map.layers[layer].world
    local mT = Map.map.lightToggle
    local dynamic = light.dynamic
    local area = light.area
    local areaIndex = light.areaIndex
    local worldSizeXt = Map.map.width
    local worldSizeYt = Map.map.height
    
    local id = light.id
    local falloff1 = light.falloff[1]
    local falloff2 = light.falloff[2]
    local falloff3 = light.falloff[3]
    
    if not mL[cLocX][cLocY] then
        mL[cLocX][cLocY] = {}
    end
    
    if not light.locations then
        light.locations = {}
    end
    
    local count = 0
    local time = tonumber(system.getTimer())
    light.lightToggle = time
    local toRadian = 0.01745329251994
    
    mL[cLocX][cLocY][id] = {}
    mL[cLocX][cLocY][id].light = {light.source[1], light.source[2], light.source[3]}
    mT[cLocX][cLocY] = time
    area[areaIndex] = {cLocX, cLocY}
    areaIndex = areaIndex + 1
    
    local i = ray
    if i == 0 then
        i = 0.00001
    end
    local breakX = false
    local breakY = false
    local angleR = i * toRadian --math.rad(i)
    local x = (5 * math.cos(angleR))
    local y = (5 * math.sin(angleR))
    
    local red = light.source[1]
    local green = light.source[2]
    local blue = light.source[3]
    
    if x > 0 and y < 0 then
        --top right quadrant
        
        local Xangle = (i - 270) * toRadian --math.rad(i - 270)
        local XcheckY = tileY
        local XcheckX = math.tan(Xangle) * startY + levelPosX
        local XdeltaY = blockScaleYt
        local XdeltaX = math.tan(Xangle) * blockScaleYt
        local XlocX, XlocY =math.ceil(XcheckX / blockScaleXt),math.ceil(XcheckY / blockScaleYt)
        local Xdistance = startY / math.cos(Xangle) / blockScaleXt
        local XdeltaV = blockScaleYt / math.cos(Xangle) / blockScaleYt
        
        local Yangle = (360 - i) * toRadian --math.rad(360 - i)
        local YcheckY = levelPosY - (math.tan(Yangle) * (tileX + blockScaleXt - levelPosX))
        local YcheckX = tileX + blockScaleXt + 1
        local YdeltaY = math.tan(Yangle) * blockScaleXt
        local YdeltaX = blockScaleXt
        local YlocX, YlocY =math.ceil(YcheckX / blockScaleXt),math.ceil(YcheckY / blockScaleYt)
        local Ydistance = (YcheckX - levelPosX) / math.cos(Yangle) / blockScaleYt
        local YdeltaV = blockScaleXt / math.cos(Yangle) / blockScaleXt
        
        for j = 1, range * 2, 1 do
            count = count + 1
            
            if Camera.worldWrapX then
                if XlocX > worldSizeXt - Map.map.locOffsetX then
                    XlocX = XlocX - worldSizeXt
                end
                if XlocX < 1 - Map.map.locOffsetX then
                    XlocX = XlocX + worldSizeXt
                end
                if YlocX > worldSizeXt - Map.map.locOffsetX then
                    YlocX = YlocX - worldSizeXt
                end
                if YlocX < 1 - Map.map.locOffsetX then
                    YlocX = YlocX + worldSizeXt
                end
            end
            if Camera.worldWrapY then
                if XlocY > worldSizeYt - Map.map.locOffsetY then
                    XlocY = XlocY - worldSizeYt
                end
                if XlocY < 1 - Map.map.locOffsetY then
                    XlocY = XlocY + worldSizeYt
                end
                if YlocY > worldSizeYt - Map.map.locOffsetY then
                    YlocY = YlocY - worldSizeYt
                end
                if YlocY < 1 - Map.map.locOffsetY then
                    YlocY = YlocY + worldSizeYt
                end
            end
            
            if XlocX < 1 - Map.map.locOffsetX or XlocX > worldSizeXt - Map.map.locOffsetX or XlocY < 1 - Map.map.locOffsetY or XlocY > worldSizeYt - Map.map.locOffsetY then
                breakX = true
            end
            if YlocX < 1 - Map.map.locOffsetX or YlocX > worldSizeXt - Map.map.locOffsetX or YlocY < 1 - Map.map.locOffsetY or YlocY > worldSizeYt - Map.map.locOffsetY then
                breakY = true
            end
            if breakX and breakY then
                break
            end
            
            local red1,green1,blue1
            
            if Xdistance < Ydistance then
                if Xdistance <= range then
                    mT[XlocX][XlocY] = time
                    area[areaIndex] = {XlocX, XlocY}
                    areaIndex = areaIndex + 1
                    red1 = red - (falloff1 * Xdistance)
                    green1 = green - (falloff2 * Xdistance)
                    blue1 = blue - (falloff3 * Xdistance)
                    if not mL[XlocX][XlocY] then
                        mL[XlocX][XlocY] = {}						
                    elseif mL[XlocX][XlocY][id] then							
                        if style == 1 then
                            local tempLight = mL[XlocX][XlocY][id]
                            red1 = (red1 + tempLight.light[1]) / 2
                            green1 = (green1 + tempLight.light[2]) / 2
                            blue1 = (blue1 + tempLight.light[3]) / 2
                        elseif style == 2 then
                            local tempLight = mL[XlocX][XlocY][id]
                            if red1 > tempLight.light[1] then
                                red1 = tempLight.light[1]
                            end
                            if green1 > tempLight.light[2] then
                                green1 = tempLight.light[2]
                            end
                            if blue1 > tempLight.light[3] then
                                blue1 = tempLight.light[3]
                            end
                        else
                            local tempLight = mL[XlocX][XlocY][id]
                            if red1 < tempLight.light[1] then
                                red1 = tempLight.light[1]
                            end
                            if green1 < tempLight.light[2] then
                                green1 = tempLight.light[2]
                            end
                            if blue1 < tempLight.light[3] then
                                blue1 = tempLight.light[3]
                            end
                        end
                    end
                    mL[XlocX][XlocY][id] = {}
                    mL[XlocX][XlocY][id].light = {red1, green1, blue1}
                    
                    if Map.map.lightingData[mW[XlocX][XlocY]] then
                        local temp = Map.map.lightingData[mW[XlocX][XlocY]]
                        red = red - temp.opacity[1]
                        green = green - temp.opacity[2]
                        blue = blue - temp.opacity[3]
                    end
                    
                    XcheckX = XcheckX + XdeltaX
                    XcheckY = XcheckY - XdeltaY
                    XlocX, XlocY =math.ceil(XcheckX / blockScaleXt), XlocY - 1
                    Xdistance = Xdistance + XdeltaV
                end
            else
                if Ydistance <= range then
                    mT[YlocX][YlocY] = time
                    area[areaIndex] = {YlocX, YlocY}
                    areaIndex = areaIndex + 1
                    red1 = red - (falloff1 * Ydistance)
                    green1 = green - (falloff2 * Ydistance)
                    blue1 = blue - (falloff3 * Ydistance)
                    if not mL[YlocX][YlocY] then
                        mL[YlocX][YlocY] = {}						
                    elseif mL[YlocX][YlocY][id] then
                        if style == 1 then
                            local tempLight = mL[YlocX][YlocY][id]
                            red1 = (red1 + tempLight.light[1]) / 2
                            green1 = (green1 + tempLight.light[2]) / 2
                            blue1 = (blue1 + tempLight.light[3]) / 2
                        elseif style == 2 then
                            local tempLight = mL[YlocX][YlocY][id]
                            if red1 > tempLight.light[1] then
                                red1 = tempLight.light[1]
                            end
                            if green1 > tempLight.light[2] then
                                green1 = tempLight.light[2]
                            end
                            if blue1 > tempLight.light[3] then
                                blue1 = tempLight.light[3]
                            end
                        else
                            local tempLight = mL[YlocX][YlocY][id]
                            if red1 < tempLight.light[1] then
                                red1 = tempLight.light[1]
                            end
                            if green1 < tempLight.light[2] then
                                green1 = tempLight.light[2]
                            end
                            if blue1 < tempLight.light[3] then
                                blue1 = tempLight.light[3]
                            end
                        end
                    end
                    mL[YlocX][YlocY][id] = {}
                    mL[YlocX][YlocY][id].light = {red1, green1, blue1}
                    
                    if Map.map.lightingData[mW[YlocX][YlocY]] then
                        local temp = Map.map.lightingData[mW[YlocX][YlocY]]
                        red = red - temp.opacity[1]
                        green = green - temp.opacity[2]
                        blue = blue - temp.opacity[3]
                    end	
                    
                    YcheckX = YcheckX + YdeltaX
                    YcheckY = YcheckY - YdeltaY
                    YlocX, YlocY = YlocX + 1,math.ceil(YcheckY / blockScaleYt)
                    Ydistance = Ydistance + YdeltaV
                end
            end
            
            
            if red1 <= 0 and green1 <= 0 and blue1 <= 0 then
                break
            end
            
            if Xdistance > range and Ydistance > range then
                break
            end
        end
        
    elseif x > 0 and y > 0 then
        --bottom right quadrant
        
        local Xangle = (90 - i) * toRadian --math.rad(90 - i)
        local XcheckY = tileY + blockScaleYt + 1
        local XcheckX = math.tan(Xangle) * (XcheckY - levelPosY) + levelPosX
        local XdeltaY = blockScaleYt
        local XdeltaX = math.tan(Xangle) * blockScaleYt
        local XlocX, XlocY =math.ceil(XcheckX / blockScaleXt),math.ceil(XcheckY / blockScaleYt)
        local Xdistance = (XcheckY - levelPosY) / math.cos(Xangle) / blockScaleXt
        local XdeltaV = blockScaleYt / math.cos(Xangle) / blockScaleYt
        
        local Yangle = i * toRadian --math.rad(i)
        local YcheckY = math.tan(Yangle) * (tileX + blockScaleXt - levelPosX) + levelPosY
        local YcheckX = tileX + blockScaleXt + 1
        local YdeltaY = math.tan(Yangle) * blockScaleXt
        local YdeltaX = blockScaleXt
        local YlocX, YlocY =math.ceil(YcheckX / blockScaleXt),math.ceil(YcheckY / blockScaleYt)
        local Ydistance = (YcheckX - levelPosX) / math.cos(Yangle) / blockScaleYt
        local YdeltaV = blockScaleXt / math.cos(Yangle) / blockScaleXt
        
        for j = 1, range * 2, 1 do
            count = count + 1
            
            if Camera.worldWrapX then
                if XlocX > worldSizeXt - Map.map.locOffsetX then
                    XlocX = XlocX - worldSizeXt
                end
                if XlocX < 1 - Map.map.locOffsetX then
                    XlocX = XlocX + worldSizeXt
                end
                if YlocX > worldSizeXt - Map.map.locOffsetX then
                    YlocX = YlocX - worldSizeXt
                end
                if YlocX < 1 - Map.map.locOffsetX then
                    YlocX = YlocX + worldSizeXt
                end
            end
            if Camera.worldWrapY then
                if XlocY > worldSizeYt - Map.map.locOffsetY then
                    XlocY = XlocY - worldSizeYt
                end
                if XlocY < 1 - Map.map.locOffsetY then
                    XlocY = XlocY + worldSizeYt
                end
                if YlocY > worldSizeYt - Map.map.locOffsetY then
                    YlocY = YlocY - worldSizeYt
                end
                if YlocY < 1 - Map.map.locOffsetY then
                    YlocY = YlocY + worldSizeYt
                end
            end
            
            if XlocX < 1 - Map.map.locOffsetX or XlocX > worldSizeXt - Map.map.locOffsetX or XlocY < 1 - Map.map.locOffsetY or XlocY > worldSizeYt - Map.map.locOffsetY then
                breakX = true
            end
            if YlocX < 1 - Map.map.locOffsetX or YlocX > worldSizeXt - Map.map.locOffsetX or YlocY < 1 - Map.map.locOffsetY or YlocY > worldSizeYt - Map.map.locOffsetY then
                breakY = true
            end
            if breakX and breakY then
                break
            end
            
            local red1,green1,blue1
            
            if Xdistance < Ydistance then
                if Xdistance <= range then
                    mT[XlocX][XlocY] = time
                    area[areaIndex] = {XlocX, XlocY}
                    areaIndex = areaIndex + 1
                    red1 = red - (falloff1 * Xdistance)
                    green1 = green - (falloff2 * Xdistance)
                    blue1 = blue - (falloff3 * Xdistance)
                    if not mL[XlocX][XlocY] then
                        mL[XlocX][XlocY] = {}						
                    elseif mL[XlocX][XlocY][id] then
                        if style == 1 then
                            local tempLight = mL[XlocX][XlocY][id]
                            red1 = (red1 + tempLight.light[1]) / 2
                            green1 = (green1 + tempLight.light[2]) / 2
                            blue1 = (blue1 + tempLight.light[3]) / 2
                        elseif style == 2 then
                            local tempLight = mL[XlocX][XlocY][id]
                            if red1 > tempLight.light[1] then
                                red1 = tempLight.light[1]
                            end
                            if green1 > tempLight.light[2] then
                                green1 = tempLight.light[2]
                            end
                            if blue1 > tempLight.light[3] then
                                blue1 = tempLight.light[3]
                            end
                        else
                            local tempLight = mL[XlocX][XlocY][id]
                            if red1 < tempLight.light[1] then
                                red1 = tempLight.light[1]
                            end
                            if green1 < tempLight.light[2] then
                                green1 = tempLight.light[2]
                            end
                            if blue1 < tempLight.light[3] then
                                blue1 = tempLight.light[3]
                            end
                        end
                    end
                    mL[XlocX][XlocY][id] = {}
                    mL[XlocX][XlocY][id].light = {red1, green1, blue1}
                    
                    if Map.map.lightingData[mW[XlocX][XlocY]] then
                        local temp = Map.map.lightingData[mW[XlocX][XlocY]]
                        red = red - temp.opacity[1]
                        green = green - temp.opacity[2]
                        blue = blue - temp.opacity[3]
                    end
                    
                    XcheckX = XcheckX + XdeltaX
                    XcheckY = XcheckY + XdeltaY
                    XlocX, XlocY =math.ceil(XcheckX / blockScaleXt), XlocY + 1
                    Xdistance = Xdistance + XdeltaV
                end
            else
                if Ydistance <= range then
                    mT[YlocX][YlocY] = time
                    area[areaIndex] = {YlocX, YlocY}
                    areaIndex = areaIndex + 1
                    red1 = red - (falloff1 * Ydistance)
                    green1 = green - (falloff2 * Ydistance)
                    blue1 = blue - (falloff3 * Ydistance)
                    if not mL[YlocX][YlocY] then
                        mL[YlocX][YlocY] = {}						
                    elseif mL[YlocX][YlocY][id] then
                        if style == 1 then
                            local tempLight = mL[YlocX][YlocY][id]
                            red1 = (red1 + tempLight.light[1]) / 2
                            green1 = (green1 + tempLight.light[2]) / 2
                            blue1 = (blue1 + tempLight.light[3]) / 2
                        elseif style == 2 then
                            local tempLight = mL[YlocX][YlocY][id]
                            if red1 > tempLight.light[1] then
                                red1 = tempLight.light[1]
                            end
                            if green1 > tempLight.light[2] then
                                green1 = tempLight.light[2]
                            end
                            if blue1 > tempLight.light[3] then
                                blue1 = tempLight.light[3]
                            end
                        else
                            local tempLight = mL[YlocX][YlocY][id]
                            if red1 < tempLight.light[1] then
                                red1 = tempLight.light[1]
                            end
                            if green1 < tempLight.light[2] then
                                green1 = tempLight.light[2]
                            end
                            if blue1 < tempLight.light[3] then
                                blue1 = tempLight.light[3]
                            end
                        end
                    end
                    mL[YlocX][YlocY][id] = {}
                    mL[YlocX][YlocY][id].light = {red1, green1, blue1}
                    
                    if Map.map.lightingData[mW[YlocX][YlocY]] then
                        local temp = Map.map.lightingData[mW[YlocX][YlocY]]
                        red = red - temp.opacity[1]
                        green = green - temp.opacity[2]
                        blue = blue - temp.opacity[3]
                    end	
                    
                    YcheckX = YcheckX + YdeltaX
                    YcheckY = YcheckY + YdeltaY
                    YlocX, YlocY = YlocX + 1,math.ceil(YcheckY / blockScaleYt)
                    Ydistance = Ydistance + YdeltaV
                end
            end
            
            
            if red1 <= 0 and green1 <= 0 and blue1 <= 0 then
                break
            end
            
            if Xdistance > range and Ydistance > range then
                break
            end
        end
        
    elseif x < 0 and y > 0 then
        --bottom left quadrant
        
        local Xangle = (i - 90) * toRadian --math.rad(i - 90)
        local XcheckY = tileY + blockScaleYt + 1
        local XcheckX = levelPosX - (math.tan(Xangle) * (XcheckY - levelPosY))
        local XdeltaY = blockScaleYt
        local XdeltaX = math.tan(Xangle) * blockScaleYt
        local XlocX, XlocY =math.ceil(XcheckX / blockScaleXt),math.ceil(XcheckY / blockScaleYt)
        local Xdistance = (XcheckY - levelPosY) / math.cos(Xangle) / blockScaleXt
        local XdeltaV = blockScaleYt / math.cos(Xangle) / blockScaleYt
        
        local Yangle = (180 - i) * toRadian --math.rad(180 - i)
        local YcheckY = math.tan(Yangle) * (levelPosX - tileX) + levelPosY
        local YcheckX = tileX 
        local YdeltaY = math.tan(Yangle) * blockScaleXt
        local YdeltaX = blockScaleXt
        local YlocX, YlocY =math.ceil(YcheckX / blockScaleXt),math.ceil(YcheckY / blockScaleYt)
        local Ydistance = startX / math.cos(Yangle) / blockScaleYt
        local YdeltaV = blockScaleXt / math.cos(Yangle) / blockScaleXt
        
        for j = 1, range * 2, 1 do
            count = count + 1
            
            if Camera.worldWrapX then
                if XlocX > worldSizeXt - Map.map.locOffsetX then
                    XlocX = XlocX - worldSizeXt
                end
                if XlocX < 1 - Map.map.locOffsetX then
                    XlocX = XlocX + worldSizeXt
                end
                if YlocX > worldSizeXt - Map.map.locOffsetX then
                    YlocX = YlocX - worldSizeXt
                end
                if YlocX < 1 - Map.map.locOffsetX then
                    YlocX = YlocX + worldSizeXt
                end
            end
            if Camera.worldWrapY then
                if XlocY > worldSizeYt - Map.map.locOffsetY then
                    XlocY = XlocY - worldSizeYt
                end
                if XlocY < 1 - Map.map.locOffsetY then
                    XlocY = XlocY + worldSizeYt
                end
                if YlocY > worldSizeYt - Map.map.locOffsetY then
                    YlocY = YlocY - worldSizeYt
                end
                if YlocY < 1 - Map.map.locOffsetY then
                    YlocY = YlocY + worldSizeYt
                end
            end
            
            if XlocX < 1 - Map.map.locOffsetX or XlocX > worldSizeXt - Map.map.locOffsetX or XlocY < 1 - Map.map.locOffsetY or XlocY > worldSizeYt - Map.map.locOffsetY then
                breakX = true
            end
            if YlocX < 1 - Map.map.locOffsetX or YlocX > worldSizeXt - Map.map.locOffsetX or YlocY < 1 - Map.map.locOffsetY or YlocY > worldSizeYt - Map.map.locOffsetY then
                breakY = true
            end
            if breakX and breakY then
                break
            end
            
            local red1, green1, blue1
            
            if Xdistance < Ydistance then
                if Xdistance <= range then
                    mT[XlocX][XlocY] = time
                    area[areaIndex] = {XlocX, XlocY}
                    areaIndex = areaIndex + 1
                    red1 = red - (falloff1 * Xdistance)
                    green1 = green - (falloff2 * Xdistance)
                    blue1 = blue - (falloff3 * Xdistance)
                    if not mL[XlocX][XlocY] then
                        mL[XlocX][XlocY] = {}						
                    elseif mL[XlocX][XlocY][id] then
                        if style == 1 then
                            local tempLight = mL[XlocX][XlocY][id]
                            red1 = (red1 + tempLight.light[1]) / 2
                            green1 = (green1 + tempLight.light[2]) / 2
                            blue1 = (blue1 + tempLight.light[3]) / 2
                        elseif style == 2 then
                            local tempLight = mL[XlocX][XlocY][id]
                            if red1 > tempLight.light[1] then
                                red1 = tempLight.light[1]
                            end
                            if green1 > tempLight.light[2] then
                                green1 = tempLight.light[2]
                            end
                            if blue1 > tempLight.light[3] then
                                blue1 = tempLight.light[3]
                            end
                        else
                            local tempLight = mL[XlocX][XlocY][id]
                            if red1 < tempLight.light[1] then
                                red1 = tempLight.light[1]
                            end
                            if green1 < tempLight.light[2] then
                                green1 = tempLight.light[2]
                            end
                            if blue1 < tempLight.light[3] then
                                blue1 = tempLight.light[3]
                            end
                        end
                    end
                    mL[XlocX][XlocY][id] = {}
                    mL[XlocX][XlocY][id].light = {red1, green1, blue1}
                    
                    if Map.map.lightingData[mW[XlocX][XlocY]] then
                        local temp = Map.map.lightingData[mW[XlocX][XlocY]]
                        red = red - temp.opacity[1]
                        green = green - temp.opacity[2]
                        blue = blue - temp.opacity[3]
                    end
                    
                    XcheckX = XcheckX - XdeltaX
                    XcheckY = XcheckY + XdeltaY
                    XlocX, XlocY =math.ceil(XcheckX / blockScaleXt), XlocY + 1
                    Xdistance = Xdistance + XdeltaV
                end
            else
                if Ydistance <= range then
                    mT[YlocX][YlocY] = time
                    area[areaIndex] = {YlocX, YlocY}
                    areaIndex = areaIndex + 1
                    red1 = red - (falloff1 * Ydistance)
                    green1 = green - (falloff2 * Ydistance)
                    blue1 = blue - (falloff3 * Ydistance)
                    if not mL[YlocX][YlocY] then
                        mL[YlocX][YlocY] = {}						
                    elseif mL[YlocX][YlocY][id] then
                        if style == 1 then
                            local tempLight = mL[YlocX][YlocY][id]
                            red1 = (red1 + tempLight.light[1]) / 2
                            green1 = (green1 + tempLight.light[2]) / 2
                            blue1 = (blue1 + tempLight.light[3]) / 2
                        elseif style == 2 then
                            local tempLight = mL[YlocX][YlocY][id]
                            if red1 > tempLight.light[1] then
                                red1 = tempLight.light[1]
                            end
                            if green1 > tempLight.light[2] then
                                green1 = tempLight.light[2]
                            end
                            if blue1 > tempLight.light[3] then
                                blue1 = tempLight.light[3]
                            end
                        else
                            local tempLight = mL[YlocX][YlocY][id]
                            if red1 < tempLight.light[1] then
                                red1 = tempLight.light[1]
                            end
                            if green1 < tempLight.light[2] then
                                green1 = tempLight.light[2]
                            end
                            if blue1 < tempLight.light[3] then
                                blue1 = tempLight.light[3]
                            end
                        end
                    end
                    mL[YlocX][YlocY][id] = {}
                    mL[YlocX][YlocY][id].light = {red1, green1, blue1}
                    
                    if Map.map.lightingData[mW[YlocX][YlocY]] then
                        local temp = Map.map.lightingData[mW[YlocX][YlocY]]
                        red = red - temp.opacity[1]
                        green = green - temp.opacity[2]
                        blue = blue - temp.opacity[3]
                    end	
                    
                    YcheckX = YcheckX - YdeltaX
                    YcheckY = YcheckY + YdeltaY
                    YlocX, YlocY = YlocX - 1,math.ceil(YcheckY / blockScaleYt)
                    Ydistance = Ydistance + YdeltaV
                end
            end
            
            
            if red1 <= 0 and green1 <= 0 and blue1 <= 0 then
                break
            end
            
            if Xdistance > range and Ydistance > range then
                break
            end
        end
        
    elseif x < 0 and y < 0 then
        --top left quadrant
        
        local Xangle = (270 - i) * toRadian --math.rad(270 - i)
        local XcheckY = tileY
        local XcheckX = levelPosX - (math.tan(Xangle) * (levelPosY - tileY))
        local XdeltaY = blockScaleYt
        local XdeltaX = math.tan(Xangle) * blockScaleYt
        local XlocX, XlocY =math.ceil(XcheckX / blockScaleXt),math.ceil(XcheckY / blockScaleYt)
        local Xdistance = startY / math.cos(Xangle) / blockScaleXt
        local XdeltaV = blockScaleYt / math.cos(Xangle) / blockScaleYt
        
        local Yangle = (i - 180) * toRadian --math.rad(i - 180)
        local YcheckY = levelPosY - (math.tan(Yangle) * (levelPosX - tileX))
        local YcheckX = tileX
        local YdeltaY = math.tan(Yangle) * blockScaleXt
        local YdeltaX = blockScaleXt
        local YlocX, YlocY =math.ceil(YcheckX / blockScaleXt),math.ceil(YcheckY / blockScaleYt)
        local Ydistance = startX / math.cos(Yangle) / blockScaleYt
        local YdeltaV = blockScaleXt / math.cos(Yangle) / blockScaleXt
        
        for j = 1, range * 2, 1 do
            count = count + 1
            
            if Camera.worldWrapX then
                if XlocX > worldSizeXt - Map.map.locOffsetX then
                    XlocX = XlocX - worldSizeXt
                end
                if XlocX < 1 - Map.map.locOffsetX then
                    XlocX = XlocX + worldSizeXt
                end
                if YlocX > worldSizeXt - Map.map.locOffsetX then
                    YlocX = YlocX - worldSizeXt
                end
                if YlocX < 1 - Map.map.locOffsetX then
                    YlocX = YlocX + worldSizeXt
                end
            end
            if Camera.worldWrapY then
                if XlocY > worldSizeYt - Map.map.locOffsetY then
                    XlocY = XlocY - worldSizeYt
                end
                if XlocY < 1 - Map.map.locOffsetY then
                    XlocY = XlocY + worldSizeYt
                end
                if YlocY > worldSizeYt - Map.map.locOffsetY then
                    YlocY = YlocY - worldSizeYt
                end
                if YlocY < 1 - Map.map.locOffsetY then
                    YlocY = YlocY + worldSizeYt
                end
            end
            
            if XlocX < 1 - Map.map.locOffsetX or XlocX > worldSizeXt - Map.map.locOffsetX or XlocY < 1 - Map.map.locOffsetY or XlocY > worldSizeYt - Map.map.locOffsetY then
                breakX = true
            end
            if YlocX < 1 - Map.map.locOffsetX or YlocX > worldSizeXt - Map.map.locOffsetX or YlocY < 1 - Map.map.locOffsetY or YlocY > worldSizeYt - Map.map.locOffsetY then
                breakY = true
            end
            if breakX and breakY then
                break
            end
            
            local red1, green1, blue1
            
            if Xdistance < Ydistance then
                if Xdistance <= range then
                    mT[XlocX][XlocY] = time
                    area[areaIndex] = {XlocX, XlocY}
                    areaIndex = areaIndex + 1
                    red1 = red - (falloff1 * Xdistance)
                    green1 = green - (falloff2 * Xdistance)
                    blue1 = blue - (falloff3 * Xdistance)
                    if not mL[XlocX][XlocY] then
                        mL[XlocX][XlocY] = {}						
                    elseif mL[XlocX][XlocY][id] then
                        if style == 1 then
                            local tempLight = mL[XlocX][XlocY][id]
                            red1 = (red1 + tempLight.light[1]) / 2
                            green1 = (green1 + tempLight.light[2]) / 2
                            blue1 = (blue1 + tempLight.light[3]) / 2
                        elseif style == 2 then
                            local tempLight = mL[XlocX][XlocY][id]
                            if red1 > tempLight.light[1] then
                                red1 = tempLight.light[1]
                            end
                            if green1 > tempLight.light[2] then
                                green1 = tempLight.light[2]
                            end
                            if blue1 > tempLight.light[3] then
                                blue1 = tempLight.light[3]
                            end
                        else
                            local tempLight = mL[XlocX][XlocY][id]
                            if red1 < tempLight.light[1] then
                                red1 = tempLight.light[1]
                            end
                            if green1 < tempLight.light[2] then
                                green1 = tempLight.light[2]
                            end
                            if blue1 < tempLight.light[3] then
                                blue1 = tempLight.light[3]
                            end
                        end
                    end
                    mL[XlocX][XlocY][id] = {}
                    mL[XlocX][XlocY][id].light = {red1, green1, blue1}
                    
                    if Map.map.lightingData[mW[XlocX][XlocY]] then
                        local temp = Map.map.lightingData[mW[XlocX][XlocY]]
                        red = red - temp.opacity[1]
                        green = green - temp.opacity[2]
                        blue = blue - temp.opacity[3]
                    end
                    
                    XcheckX = XcheckX - XdeltaX
                    XcheckY = XcheckY - XdeltaY
                    XlocX, XlocY =math.ceil(XcheckX / blockScaleXt), XlocY - 1
                    Xdistance = Xdistance + XdeltaV
                end
            else
                if Ydistance <= range then
                    mT[YlocX][YlocY] = time
                    area[areaIndex] = {YlocX, YlocY}
                    areaIndex = areaIndex + 1
                    red1 = red - (falloff1 * Ydistance)
                    green1 = green - (falloff2 * Ydistance)
                    blue1 = blue - (falloff3 * Ydistance)
                    if not mL[YlocX][YlocY] then
                        mL[YlocX][YlocY] = {}						
                    elseif mL[YlocX][YlocY][id] then
                        if style == 1 then
                            local tempLight = mL[YlocX][YlocY][id]
                            red1 = (red1 + tempLight.light[1]) / 2
                            green1 = (green1 + tempLight.light[2]) / 2
                            blue1 = (blue1 + tempLight.light[3]) / 2
                        elseif style == 2 then
                            local tempLight = mL[YlocX][YlocY][id]
                            if red1 > tempLight.light[1] then
                                red1 = tempLight.light[1]
                            end
                            if green1 > tempLight.light[2] then
                                green1 = tempLight.light[2]
                            end
                            if blue1 > tempLight.light[3] then
                                blue1 = tempLight.light[3]
                            end
                        else
                            local tempLight = mL[YlocX][YlocY][id]
                            if red1 < tempLight.light[1] then
                                red1 = tempLight.light[1]
                            end
                            if green1 < tempLight.light[2] then
                                green1 = tempLight.light[2]
                            end
                            if blue1 < tempLight.light[3] then
                                blue1 = tempLight.light[3]
                            end
                        end
                    end
                    mL[YlocX][YlocY][id] = {}
                    mL[YlocX][YlocY][id].light = {red1, green1, blue1}
                    
                    if Map.map.lightingData[mW[YlocX][YlocY]] then
                        local temp = Map.map.lightingData[mW[YlocX][YlocY]]
                        red = red - temp.opacity[1]
                        green = green - temp.opacity[2]
                        blue = blue - temp.opacity[3]
                    end	
                    
                    YcheckX = YcheckX - YdeltaX
                    YcheckY = YcheckY - YdeltaY
                    YlocX, YlocY = YlocX - 1,math.ceil(YcheckY / blockScaleYt)
                    Ydistance = Ydistance + YdeltaV
                end
            end			
            
            if red1 <= 0 and green1 <= 0 and blue1 <= 0 then
                break
            end
            
            if Xdistance > range and Ydistance > range then
                break
            end
        end		
    end	
    light.areaIndex = areaIndex
end

-----------------------------------------------------------

Light.setPointLightSource = function(sprite)
    Light.pointLightSource = sprite
end

-----------------------------------------------------------

return Light

end
end

do
local _ENV = _ENV
package.preload[ "src.Xml" ] = function( ... ) local arg = _G.arg;
local Xml = {}

-----------------------------------------------------------

local json = require("json")

local Map = require("src.Map")

-----------------------------------------------------------

Xml.data = nil

-----------------------------------------------------------

Xml.ToXmlString = function(value)
    value = string.gsub (value, "&", "&amp;");		-- '&' -> "&amp;"
    value = string.gsub (value, "<", "&lt;");		-- '<' -> "&lt;"
    value = string.gsub (value, ">", "&gt;");		-- '>' -> "&gt;"
    value = string.gsub (value, "\"", "&quot;");	-- '"' -> "&quot;"
    value = string.gsub(value, "([^%w%&%;%p%\t% ])",
    function (c) 
        return string.format("&#x%X;", string.byte(c)) 
    end);
    return value;
end

-----------------------------------------------------------

Xml.FromXmlString = function(value)
    value = string.gsub(value, "&#x([%x]+)%;",
    function(h) 
        return string.char(tonumber(h,16)) 
    end);
    value = string.gsub(value, "&#([0-9]+)%;",
    function(h) 
        return string.char(tonumber(h,10)) 
    end);
    value = string.gsub (value, "&quot;", "\"");
    value = string.gsub (value, "&apos;", "'");
    value = string.gsub (value, "&gt;", ">");
    value = string.gsub (value, "&lt;", "<");
    value = string.gsub (value, "&amp;", "&");
    return value;
end

-----------------------------------------------------------

Xml.ParseArgs = function(s)
    local arg = {}
    string.gsub(s, "(%w+)=([\"'])(.-)%2", function (w, _, a)
        arg[w] = Xml.FromXmlString(a);
    end)
    return arg
end

-----------------------------------------------------------

Xml.loadFile = function(xmlFilename, base)
    if not base then
        base = system.ResourceDirectory
    end
    
    local path = system.pathForFile( xmlFilename, base )
    local hFile, err = io.open(path,"r");
    
    if hFile and not err then
        local xmlText=hFile:read("*a"); -- read file content
        io.close(hFile);
        return Xml.ParseXmlText(xmlText),nil;
    else
        print( err )
        return nil
    end
end

-----------------------------------------------------------

Xml.ParseXmlText = function(xmlText)
    if not Map.mapStorage[Xml.src] then
        Map.mapStorage[Xml.src] = {}
    end
    local layerIndex = 0
    
    local stack = {}
    local top = {name=nil,value=nil,properties={},child={}}
    table.insert(stack, top)
    local ni,c,label,xarg, empty
    local i, j = 1, 1
    local triggerBase64 = false
    local triggerXML = false
    local triggerCSV = false
    local x, y = 1, 1
    while true do
        local ni,j,c,label,xarg, empty = string.find(xmlText, "<(%/?)([%w:]+)(.-)(%/?)>", i)
        if not ni then break end
        local text = string.sub(xmlText, i, ni-1);
        if not string.find(text, "^%s*$") then
            top.value=(top.value or "")..Xml.FromXmlString(text);
            if triggerBase64 then
                triggerBase64 = false
                --decode base64 directly into Map.map array
                --------------------------------------------------------------
                
                local buffer = 0
                local pos = 1
                local bin ={}
                local mult = 1
                for i = 1,40 do
                    bin[i] = mult
                    mult = mult*2
                end
                local base64 = { ['A']=0,['B']=1,['C']=2,['D']=3,['E']=4,['F']=5,['G']=6,['H']=7,['I']=8,
                    ['J']=9,['K']=10,['L']=11,['M']=12,['N']=13,['O']=14,['P']=15,['Q']=16,
                    ['R']=17,['S']=18,['T']=19,['U']=20,['V']=21,['W']=22,['X']=23,['Y']=24,
                    ['Z']=25,['a']=26,['b']=27,['c']=28,['d']=29,['e']=30,['f']=31,['g']=32,
                    ['h']=33,['i']=34,['j']=35,['k']=36,['l']=37,['m']=38,['n']=39,['o']=40,
                    ['p']=41,['q']=42,['r']=43,['s']=44,['t']=45,['u']=46,['v']=47,['w']=48,
                    ['x']=49,['y']=50,['z']=51,['0']=52,['1']=53,['2']=54,['3']=55,['4']=56,
                    ['5']=57,['6']=58,['7']=59,['8']=60,['9']=61,['+']=62,['/']=63,['=']=nil
                }
                local set = "[^%a%d%+%/%=]"
                
                Xml.data = string.gsub(top.value, set, "")    
                
                local size = 32
                local val = {}
                local rawPos = 1
                local rawSize = #top.value
                local char = ""
                
                while rawPos <= rawSize do
                    while pos <= size and rawPos <= rawSize do
                        char = string.sub(top.value,rawPos,rawPos)
                        if base64[char] ~= nil then
                            buffer = buffer * bin[7] + base64[char]
                            pos = pos + 6
                        end
                        rawPos = rawPos + 1
                    end
                    if char == "=" then 
                        break 
                    end
                    
                    while pos < 33 do 
                        buffer = buffer * bin[2] 
                        pos = pos + 1
                    end
                    pos = pos - 32
                    Map.mapStorage[Xml.src].layers[layerIndex].data[#Map.mapStorage[Xml.src].layers[layerIndex].data+1] = math.floor((buffer%bin[33+pos-1])/bin[25+pos-1]) +
                    math.floor((buffer%bin[25+pos-1])/bin[17+pos-1])*bin[9] +
                    math.floor((buffer%bin[17+pos-1])/bin[9+pos-1])*bin[17] + 
                    math.floor((buffer%bin[9+pos-1])/bin[pos])*bin[25]
                    buffer = buffer % bin[pos]    	
                end
                --------------------------------------------------------------
            end
            if triggerCSV then
                triggerCSV = false
                Map.mapStorage[Xml.src].layers[layerIndex].data = json.decode("["..top.value.."]")
            end
        end
        if empty == "/" then  -- empty element tag
            if label == "tile" then
                Map.mapStorage[Xml.src].layers[layerIndex].data[#Map.mapStorage[Xml.src].layers[layerIndex].data + 1] = tonumber(xarg:sub(7, xarg:len() - 1))
            else
                table.insert(top.child, {name=label,value=nil,properties=Xml.ParseArgs(xarg),child={}})
            end
            if label == "layer" or label == "objectgroup" or label == "imagelayer"  then
                layerIndex = layerIndex + 1
                if not Map.mapStorage[Xml.src].layers then
                    Map.mapStorage[Xml.src].layers = {}
                end
                Map.mapStorage[Xml.src].layers[layerIndex] = {}
                Map.mapStorage[Xml.src].layers[layerIndex].properties = {}
            end
        elseif c == "" then   -- start tag
            local props = Xml.ParseArgs(xarg)
            top = {name=label, value=nil, properties=props, child={}}
            table.insert(stack, top)   -- new level
            if label == "Map.map" then
                --
            end
            if label == "layer" or label == "objectgroup" or label == "imagelayer" then
                layerIndex = layerIndex + 1
                x, y = 1, 1
                if not Map.mapStorage[Xml.src].layers then
                    Map.mapStorage[Xml.src].layers = {}
                end
                Map.mapStorage[Xml.src].layers[layerIndex] = {}
                Map.mapStorage[Xml.src].layers[layerIndex].properties = {}
                if label == "layer" then
                    Map.mapStorage[Xml.src].layers[layerIndex].data = {}
                    Map.mapStorage[Xml.src].layers[layerIndex].world = {}
                    Map.mapStorage[Xml.src].layers[layerIndex].world[1] = {}
                end
            end
            if label == "data" then
                if props.encoding == "base64" then
                    triggerBase64 = true
                    if props.compression then
                        print("Error(loadMap): Layer data compression is not supported. MTE supports CSV, TMX, and Base64(uncompressed).")
                    end
                elseif props.encoding == "csv" then
                    triggerCSV = true
                elseif not props.encoding then
                    triggerXML = true
                end
            end
        else  -- end tag
            local toclose = table.remove(stack)  -- remove top
            top = stack[#stack]
            if #stack < 1 then
                error("XmlParser: nothing to close with "..label)
            end
            if toclose.name ~= label then
                error("XmlParser: trying to close "..toclose.name.." with "..label)
            end
            table.insert(top.child, toclose)
        end
        i = j+1
    end
    local text = string.sub(xmlText, i);
    if not string.find(text, "^%s*$") then
        stack[#stack].value=(stack[#stack].value or "")..Xml.FromXmlString(text);
    end
    if #stack > 1 then
        error("XmlParser: unclosed "..stack[stack.n].name)
    end
    return stack[1].child[1];
end

-----------------------------------------------------------

return Xml

end
end

do
local _ENV = _ENV
package.preload[ "src.Screen" ] = function( ... ) local arg = _G.arg;
local Screen = {}

-----------------------------------------------------------

Screen.screenLeft = nil
Screen.screenTop = nil
Screen.screenRight = nil
Screen.screenBottom = nil
Screen.screenCenterX = nil
Screen.screenCenterY = nil

-----------------------------------------------------------

Screen.setScreenBounds = function(left, top, right, bottom)
    Screen.screenLeft = left
    Screen.screenTop = top
    Screen.screenRight = right
    Screen.screenBottom = bottom
    Screen.screenCenterX = left + ((right - left) * 0.5 )
    Screen.screenCenterY = top + ((bottom - top) * 0.5 )
end

Screen.UpdateScreenBounds = function()
    if ( Screen.viewableContentWidth == display.viewableContentWidth ) then
        return
    end
    Screen.viewableContentWidth = display.viewableContentWidth
    if display.viewableContentWidth < display.viewableContentHeight then
        print("screen is vertical")                
        Screen.screenCenterX = display.contentWidth * 0.5
        Screen.screenCenterY = display.contentHeight * 0.5
        Screen.screenLeft = 0 + display.screenOriginX
        Screen.screenTop = 0 + display.screenOriginY
        Screen.screenRight = display.contentWidth - display.screenOriginX
        Screen.screenBottom = display.contentHeight - display.screenOriginY
        
    else
        print("screen is horizontal")
        Screen.screenLeft = display.screenOriginX
        Screen.screenTop = display.screenOriginY
        Screen.screenRight = display.screenOriginX + ( display.pixelHeight * display.contentScaleY )
        Screen.screenBottom = display.screenOriginY + ( display.pixelWidth * display.contentScaleX )
        Screen.screenCenterX = display.screenOriginX + ( display.pixelHeight * display.contentScaleY ) * 0.5
        Screen.screenCenterY = display.screenOriginY + ( display.pixelWidth * display.contentScaleX ) * 0.5
    end
    print(Screen.screenCenterX, Screen.screenCenterY)        
end

-----------------------------------------------------------

Screen.UpdateScreenBounds()

-----------------------------------------------------------

return Screen

end
end

do
local _ENV = _ENV
package.preload[ "src.Core" ] = function( ... ) local arg = _G.arg;
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
            Sprites.addSprite(Sprites.sprites[spriteName], setup)			
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
            Sprites.addSprite(Sprites.sprites[spriteName], setup)
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
            Sprites.addSprite(Sprites.sprites[spriteName], setup)
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
                Sprites.addSprite(Sprites.sprites[spriteName], setup)
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
                Sprites.addSprite(Sprites.sprites[spriteName], setup)
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
        Sprites.addSprite(Sprites.sprites[spriteName], setup)
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
        Sprites.addSprite(Sprites.sprites[spriteName], setup)
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
        Sprites.addSprite(Sprites.sprites[spriteName], setup)
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
end
end

do
local _ENV = _ENV
package.preload[ "src.Map" ] = function( ... ) local arg = _G.arg;
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

end
end

do
local _ENV = _ENV
package.preload[ "src.PerlinNoise" ] = function( ... ) local arg = _G.arg;
local PerlinNoise = {}

local Map = require("src.Map")

-----------------------------------------------------------

PerlinNoise.perlinNoise = function(params)
    local params = params
    if not params then
        params = {}
    end
    local width = params.width or Map.map.width
    local height = params.height or Map.map.height
    local freX = params.freqX or 0.05
    local freY = params.freqY or 0.05
    local amp = params.amp or 0.99
    local per = params.per or 0.65
    local oct = params.oct or 6
    print("Creating Perlin Noise...")
    local startTime=system.getTimer()
    local noise = {}
    if params.noise then
        noise = params.noise
        if #noise ~= width or #noise[1] ~= height then
            print("Warning(perlin): The dimensions of the noise array do not match the width and height of the output table.")
        end
    else
        for x = 1, width, 1 do
            noise[x] = {}
            for y = 1, height, 1 do
                noise[x][y] = math.random(0, 1)
            end
        end
    end		
    print("Seed Load Time(ms): "..system.getTimer() - startTime)
    local perlinData = {}
    local maxVal = 0
    local minVal = 32000
    for x = 1, width, 1 do
        perlinData[x] = {}
        for y = 1, height, 1 do			
            local freX = freX		--frequency
            local freY = freY		--frequency
            local amp = amp			--amplitude
            local per = per			--persistance
            local oct = oct			--octaves
            local finalValue = 0.0
            for k = 1, oct, 1 do
                local xx,yy
                xx = x * freX
                yy = y * freY
                local fx = math.floor(xx)
                local fy = math.floor(yy)
                local fractionX = xx - fx
                local fractionY = yy - fy
                local x1 = (fx + width) % width
                local y1 = (fy + height) % height
                local x2 = (fx + width - 1) % width
                local y2 = (fy + height - 1) % height 
                if x1 <= 0 then 
                    x1 = x1 + width 
                end
                if x2 <= 0 then 
                    x2 = x2 + width
                end
                if y1 <= 0 then 
                    y1 = y1 + height
                end
                if y2 <= 0 then 
                    y2 = y2 + height
                end			
                local finVal = 0				
                finVal = finVal + fractionX * fractionY * noise[x1][y1]
                finVal = finVal + fractionX * (1 - fractionY) * noise[x1][y2]
                finVal = finVal + (1 - fractionX) * fractionY * noise[x2][y1]
                finVal = finVal + (1 - fractionX) * (1 - fractionY) * noise[x2][y2]				
                finalValue = finalValue + finVal * amp
                freX = freX * 2.0
                freY = freY * 2.0
                amp = amp * per
            end				
            perlinData[x][y] = finalValue
            if finalValue > maxVal then
                maxVal = finalValue
            end
            if finalValue < minVal then
                minVal = finalValue
            end
        end
    end
    print("Raw Perlin Load Time(ms): "..system.getTimer() - startTime)
    
    if params.layer and params.layer.layer == "global" then
        params.layer.layer = 0
    end
    if params.heightMap and params.heightMap.layer == "global" then
        params.heightMap.layer = 0
    end
    if params.lighting and params.lighting.layer == "global" then
        params.lighting.layer = 0
    end		
    local perlinOutputW, perlinOutputH, perlinOutputL, perlinOutputO
    for x = 1, width, 1 do
        for y = 1, height, 1 do
            if params.layer then
                local perlinData = (perlinData[x][y] / maxVal) * (params.layer.scale or 100)
                if params.layer.roundResults then
                    perlinData = math.round(perlinData)
                elseif params.layer.floorResults then
                    perlinData = math.floor(perlinData)
                elseif params.layer.ceilResults then
                    perlinData = math.ceil(perlinData)
                end
                if params.layer.layer == 0 then
                    for i = l, #Map.map.layers, 1 do
                        if Map.map.layers[l].world then
                            perlinOutputW = Map.map.layers[l].world
                            if params.layer.perlinLevels then
                                local perlinLevels = params.layer.perlinLevels
                                for i = 1, #perlinLevels, 1 do
                                    if perlinData >= perlinLevels[i].min and perlinData < perlinLevels[i].max then
                                        --The value falls within this perlin level.
                                        if perlinLevels[i].value then
                                            Map.map.layers[perlinLevels[i].layer or l].world[x][y] = perlinLevels[i].value
                                        elseif perlinLevels[i].masks then
                                            for j = 1, #perlinLevels[i].masks, 1 do
                                                if perlinLevels[i].masks[j].emptySpace then
                                                    if not perlinOutputW[x][y] or perlinOutputW[x][y] == 0 then
                                                        Map.map.layers[perlinLevels[i].masks[j].layer or perlinLevels[i].layer or l].world[x][y] = perlinLevels[i].masks[j].value or perlinData
                                                    end
                                                elseif perlinLevels[i].masks[j].anyTile then
                                                    if perlinOutputW[x][y] and perlinOutputW[x][y] > 0 then
                                                        Map.map.layers[perlinLevels[i].masks[j].layer or perlinLevels[i].layer or l].world[x][y] = perlinLevels[i].masks[j].value or perlinData
                                                    end
                                                elseif perlinOutputW[x][y] then
                                                    if perlinOutputW[x][y] >= perlinLevels[i].masks[j].min and perlinOutputW[x][y] < perlinLevels[i].masks[j].max then
                                                        Map.map.layers[perlinLevels[i].masks[j].layer or perlinLevels[i].layer or l].world[x][y] = perlinLevels[i].masks[j].value or perlinData
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            else
                                perlinOutputW[x][y] = perlinData
                            end
                        end
                    end
                else
                    perlinOutputW = Map.map.layers[params.layer.layer].world
                    if params.layer.perlinLevels then
                        local perlinLevels = params.layer.perlinLevels
                        for i = 1, #perlinLevels, 1 do
                            if perlinData >= perlinLevels[i].min and perlinData < perlinLevels[i].max then
                                --The value falls within this perlin level.
                                if perlinLevels[i].value then
                                    Map.map.layers[perlinLevels[i].layer or params.layer.layer].world[x][y] = perlinLevels[i].value
                                elseif perlinLevels[i].masks then
                                    for j = 1, #perlinLevels[i].masks, 1 do
                                        if perlinLevels[i].masks[j].emptySpace then
                                            if not perlinOutputW[x][y] or perlinOutputW[x][y] == 0 then
                                                Map.map.layers[perlinLevels[i].masks[j].layer or perlinLevels[i].layer or params.layer.layer].world[x][y] = perlinLevels[i].masks[j].value or perlinData
                                            end
                                        elseif perlinLevels[i].masks[j].anyTile then
                                            if perlinOutputW[x][y] and perlinOutputW[x][y] > 0 then
                                                Map.map.layers[perlinLevels[i].masks[j].layer or perlinLevels[i].layer or params.layer.layer].world[x][y] = perlinLevels[i].masks[j].value or perlinData
                                            end
                                        elseif perlinOutputW[x][y] then
                                            if perlinOutputW[x][y] >= perlinLevels[i].masks[j].min and perlinOutputW[x][y] < perlinLevels[i].masks[j].max then
                                                Map.map.layers[perlinLevels[i].masks[j].layer or perlinLevels[i].layer or params.layer.layer].world[x][y] = perlinLevels[i].masks[j].value or perlinData
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    else
                        perlinOutputW[x][y] = perlinData
                    end
                end					
                -------------------
            end
            if params.heightMap then
                local offset = params.heightMap.offset or 0
                local perlinData = ((perlinData[x][y] / maxVal) * (params.heightMap.scale or 1)) + offset
                if params.heightMap.roundResults then
                    perlinData = math.round(perlinData)
                elseif params.heightMap.floorResults then
                    perlinData = math.floor(perlinData)
                elseif params.heightMap.ceilResults then
                    perlinData = math.ceil(perlinData)
                end
                if params.heightMap.layer == 0 then
                    perlinOutputH = Map.map.heightMap
                    if not perlinOutputH then
                        Map.map.heightMap = {}
                        for x = 1, Map.map.width, 1 do
                            Map.map.heightMap[x - Map.map.locOffsetX] = {}
                        end
                        perlinOutputH = Map.map.heightMap
                    end
                else
                    perlinOutputH = Map.map.layers[params.heightMap.layer].heightMap
                    if not perlinOutputH then
                        Map.map.layers[params.heightMap.layer].heightMap = {}
                        for x = 1, Map.map.width, 1 do
                            Map.map.layers[params.heightMap.layer].heightMap[x - Map.map.locOffsetX] = {}
                        end
                        perlinOutputH = Map.map.layers[params.heightMap.layer].heightMap
                    end
                end
                if params.heightMap.perlinLevels then
                    local perlinLevels = params.heightMap.perlinLevels
                    for i = 1, #perlinLevels, 1 do
                        if perlinData >= perlinLevels[i].min and perlinData < perlinLevels[i].max then
                            --The value falls within this perlin level.
                            local outputTemp = perlinOutputH
                            if perlinLevels[i].layer and params.heightMap.layer ~= 0 then
                                outputTemp = Map.map.layers[perlinLevels[i].layer].heightMap
                            end
                            if perlinLevels[i].value then
                                outputTemp[x][y] = perlinLevels[i].value
                            elseif perlinLevels[i].masks then
                                for j = 1, #perlinLevels[i].masks, 1 do
                                    if perlinLevels[i].masks[j].layer and params.heightMap.layer ~= 0 then
                                        outputTemp = Map.map.layers[perlinLevels[i].masks[j].layer].heightMap
                                    end
                                    if perlinLevels[i].masks[j].emptySpace then
                                        if not perlinOutputH[x][y] or perlinOutputH[x][y] == 0 then
                                            outputTemp[x][y] = perlinLevels[i].masks[j].value or perlinData
                                        end
                                    elseif perlinLevels[i].masks[j].anyTile then
                                        if perlinOutputH[x][y] and perlinOutputH[x][y] > 0 then
                                            outputTemp[x][y] = perlinLevels[i].masks[j].value or perlinData
                                        end
                                    elseif perlinOutputH[x][y] then
                                        if perlinOutputH[x][y] >= perlinLevels[i].masks[j].min and perlinOutputH[x][y] < perlinLevels[i].masks[j].max then
                                            outputTemp[x][y] = perlinLevels[i].masks[j].value or perlinData
                                        end
                                    end
                                end
                            else
                                outputTemp[x][y] = perlinData
                            end
                        end
                    end
                else
                    perlinOutputH[x][y] = perlinData
                end
                -------------------
            end
            if params.lighting then
                local offset = params.lighting.offset or 0
                local perlinData = ((perlinData[x][y] / maxVal) * (params.lighting.scale or 1)) + offset
                if params.lighting.roundResults then
                    perlinData = math.round(perlinData)
                elseif params.lighting.floorResults then
                    perlinData = math.floor(perlinData)
                elseif params.lighting.ceilResults then
                    perlinData = math.ceil(perlinData)
                end
                if params.lighting.layer == 0 then
                    perlinOutputL = Map.map.perlinLighting
                    if not perlinOutputL then
                        Map.map.perlinLighting = {}
                        for x = 1, Map.map.width, 1 do
                            Map.map.perlinLighting[x - Map.map.locOffsetX] = {}
                        end
                        perlinOutputL = Map.map.perlinLighting
                    end
                else
                    perlinOutputL = Map.map.layers[params.lighting.layer].perlinLighting
                    if not perlinOutputL then
                        Map.map.layers[params.lighting.layer].perlinLighting = {}
                        for x = 1, Map.map.width, 1 do
                            Map.map.layers[params.lighting.layer].perlinLighting[x - Map.map.locOffsetX] = {}
                        end
                        perlinOutputL = Map.map.layers[params.lighting.layer].perlinLighting
                    end
                end
                if params.lighting.perlinLevels then
                    local perlinLevels = params.lighting.perlinLevels
                    for i = 1, #perlinLevels, 1 do
                        if perlinData >= perlinLevels[i].min and perlinData < perlinLevels[i].max then
                            --The value falls within this perlin level.
                            local outputTemp = perlinOutputL
                            if perlinLevels[i].layer and params.lighting.layer ~= 0 then
                                outputTemp = Map.map.layers[perlinLevels[i].layer].perlinLighting
                            end
                            if perlinLevels[i].value then
                                outputTemp[x][y] = perlinLevels[i].value
                            elseif perlinLevels[i].masks then
                                for j = 1, #perlinLevels[i].masks, 1 do
                                    if perlinLevels[i].masks[j].layer and params.lighting.layer ~= 0 then
                                        outputTemp = Map.map.layers[perlinLevels[i].masks[j].layer].perlinLighting
                                    end
                                    if perlinLevels[i].masks[j].emptySpace then
                                        if not perlinOutputL[x][y] or perlinOutputL[x][y] == 0 then
                                            outputTemp[x][y] = perlinLevels[i].masks[j].value or perlinData
                                        end
                                    elseif perlinLevels[i].masks[j].anyTile then
                                        if perlinOutputL[x][y] and perlinOutputL[x][y] > 0 then
                                            outputTemp[x][y] = perlinLevels[i].masks[j].value or perlinData
                                        end
                                    elseif perlinOutputL[x][y] then
                                        if perlinOutputL[x][y] >= perlinLevels[i].masks[j].min and perlinOutputL[x][y] < perlinLevels[i].masks[j].max then
                                            outputTemp[x][y] = perlinLevels[i].masks[j].value or perlinData
                                        end
                                    end
                                end
                            else
                                outputTemp[x][y] = perlinData
                            end
                        end
                    end
                else
                    perlinOutputL[x][y] = perlinData
                end
                -------------------
            end
            if params.output then
                local offset = params.output.offset or 0
                local perlinData = ((perlinData[x][y] / maxVal) * (params.output.scale or 100)) + offset
                if params.output.roundResults then
                    perlinData = math.round(perlinData)
                elseif params.output.floorResults then
                    perlinData = math.floor(perlinData)
                elseif params.output.ceilResults then
                    perlinData = math.ceil(perlinData)
                end
                perlinOutputO = params.output.outputTable
                if not perlinOutputO then
                    perlinOutputO = {}
                    for x = 1, width, 1 do
                        perlinOutputO[x] = {}
                    end
                elseif not perlinOutputO[1] or type(perlinOutputO[1]) ~= "table" then
                    for x = 1, width, 1 do
                        perlinOutputO[x] = {}
                    end
                end
                if params.output.perlinLevels then
                    local perlinLevels = params.output.perlinLevels
                    for i = 1, #perlinLevels, 1 do
                        if perlinData >= perlinLevels[i].min and perlinData < perlinLevels[i].max then
                            --The value falls within this perlin level.
                            if perlinLevels[i].value then
                                perlinOutputO[x][y] = perlinLevels[i].value
                            elseif perlinLevels[i].masks then
                                for j = 1, #perlinLevels[i].masks, 1 do
                                    if perlinLevels[i].masks[j].emptySpace then
                                        if not perlinOutputO[x][y] or perlinOutputO[x][y] == 0 then
                                            perlinOutputO[x][y] = perlinLevels[i].masks[j].value or perlinData
                                        end
                                    elseif perlinLevels[i].masks[j].anyTile then
                                        if perlinOutputO[x][y] and perlinOutputO[x][y] > 0 then
                                            perlinOutputO[x][y] = perlinLevels[i].masks[j].value or perlinData
                                        end
                                    elseif perlinOutputO[x][y] then
                                        if perlinOutputO[x][y] >= perlinLevels[i].masks[j].min and perlinOutputO[x][y] < perlinLevels[i].masks[j].max then
                                            perlinOutputO[x][y] = perlinLevels[i].masks[j].value or perlinData
                                        end
                                    end
                                end
                            else
                                perlinOutputO[x][y] = perlinData
                            end
                        end
                    end
                else
                    perlinOutputO[x][y] = perlinData
                end
                -------------------
            end
        end
    end		
    if params.lighting then
        --        M.refresh()
    end		
    print("Total Load Time(ms): "..system.getTimer() - startTime)
    return perlinOutputO, perlinOutputW, perlinOutputH, perlinOutputL
end




-----------------------------------------------------------

return PerlinNoise

end
end

do
local _ENV = _ENV
package.preload[ "src.DebugStats" ] = function( ... ) local arg = _G.arg;
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

end
end

do
local _ENV = _ENV
package.preload[ "src.Camera" ] = function( ... ) local arg = _G.arg;
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
Camera.enableLighting = false
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
end
end

do
local _ENV = _ENV
package.preload[ "src.SaveMap" ] = function( ... ) local arg = _G.arg;
local SaveMap = {}

local json = require("json")
local lfs = require("lfs")

-----------------------------------------------------------

SaveMap.saveMap = function(loadedMap, filePath, dir)
    if not filePath then
        if loadedMap then
            filePath = loadedMap
        else
            filePath = source
        end
    end	
    local directories = {}
    local firstIndex = 1
    for i = 1, string.len(filePath), 1 do
        if string.sub(filePath, i, i) == "/" then
            directories[#directories + 1] = string.sub(filePath, firstIndex, i - 1)
            firstIndex = i + 1
        end
    end	
    local fileName = string.sub(filePath, firstIndex, string.len(filePath))	
    local dirPath
    if dir == "Documents" or not dir then
        dirPath = system.pathForFile("", system.DocumentsDirectory)
    elseif dir == "Temporary" then
        dirPath = system.pathForFile("", system.TemporaryDirectory)
    elseif dir == "Resource" then
        dirPath = system.pathForFile("", system.ResourceDirectory)
    end	
    if #directories > 0 then
        
        for i = 1, #directories, 1 do
            lfs.chdir(dirPath)
            local exists = false
            for file in lfs.dir(dirPath) do
                if file == directories[i] then
                    exists = true
                    break
                end
            end
            if not exists then
                lfs.mkdir(directories[i])
            end
            dirPath = lfs.currentdir() .. "/"..directories[i]
        end		
    end
    local finalPath = dirPath.."/"..fileName	
    
    local jsonData
    if not loadedMap then
        jsonData = json.encode(Map.map)
    else
        jsonData = json.encode(Map.mapStorage[loadedMap])		
    end	
    local saveData = io.open(finalPath, "w")	
    saveData:write(jsonData)
    io.close(saveData)
    
end

-----------------------------------------------------------

return SaveMap
end
end

end

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

M.enableLighting = Camera.enableLighting
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
                if M.enableLighting and i == 1 then
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
                    if M.enableLighting and i == 1 then
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
                        if M.enableLighting and i == 1 then
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
                            
                            if M.enableLighting then
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
    if M.enableLighting then
        if not Map.map.layers[layer].lighting then
            Map.map.layers[layer].lighting = {}
        end
    end
    
    if M.enableLighting then
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
                            if M.enableLighting then
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
                        if M.enableLighting then
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
    if M.enableLighting then
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
        if M.enableLighting then
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
        
        if M.enableLighting then
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
                if M.enableLighting and i == 1 then
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
                    if M.enableLighting and i == 1 then
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
                        if M.enableLighting and i == 1 then
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
                                if M.enableLighting then
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
    if M.enableLighting then
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
    if M.enableLighting then
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

return M
