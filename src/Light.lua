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
