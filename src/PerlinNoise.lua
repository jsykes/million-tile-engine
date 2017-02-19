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
