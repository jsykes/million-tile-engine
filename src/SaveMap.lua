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