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
