### API

### addObject(layer, table)

Adds a Tiled Object to an Object Layer in the tile map. Object Layers are layers created in Tiled and used to store various non-tile data. This function inserts the contents of the table argument without modifying them, and as such can be used to store just about any kind of data on the Object Layer. It is recommended that all objects have the following parameters: “x”, “y”, “name”, “width”, and “height”. The getObject() function uses these parameters to find and retrieve objects.
 
layer:               (number) An Object Layer in the tile map.
 
table:               (table) The table of data you would like to load into the Object Layer. Tiled Objects generally include an “x” and “y” level position, a “name”, a “type”, and a subtable named“properties”.

### addObjectDrawListener(name, listener)

Adds an event listener to the map which monitors the Tiled Object draw functions for the creation of an object with the matching name. Dispatches an event to the specified listener function containing the object name, the display object, and the Tiled Object.
 
name:              (string) The name of a Tiled Object.
 
listener:           (function) The listener to receive the event.
 
 
Example:
 
local onTestRectObject = function(event)
            event.target.rotation = 45
end
mte.addObjectDrawListener("testRect1", onTestRectObject)

### addPropertyListener(name, listener)

Adds an event listener to the map which monitors the tile display grid for the creation of new tiles with the matching property. Dispatches an event to the specified listener function containing the property name and the tile’s display object.
 
name:              (string) The name of a property.
 
listener:           (function) The listener to receive the event.
 
 
Example:
 
local onOrientationProperty = function(event)
            event.target:setFillColor(1, 0, 0)
end
mte.addPropertyListener("orientation", onOrientationProperty)

### addSprite(sprite, setup)

Adds a sprite such as a player character or an enemy to MTE’s sprite arrays. This allows the engine to manage the movement, position, and scale of the sprite in relation to the world around it.
 
Returns a displayObject reference.
 
sprite:              (object) The displayObject reference to a sprite, imageRect, vector object, or groupObject.
 
setup:             (table) Data used by MTE to position and scale the sprite in the world.
 
Format for setup:
 
layer:               (number, optional) A map layer.
 
kind:                 (string, optional) Specifies the type of displayObject being added. Possible values are “sprite”, “imageRect”, “group”, or “vector”. The “vector” kind is deprecated and will be removed in a future MTE update; it is functionally identical to “group”.
 
name:              (string, optional) The name of the sprite, used to retrieve sprites with getSprites().  The engine will assign a name to a sprite if none is supplied. The generated name is based on the x and y position of the sprite and the layer to which it is added.
 
levelPosX:                   (optional) The X coordinate of the sprite’s starting position.
 
levelPosY:                   (optional) The Y coordinate of the sprite’s starting position.
 
locX:                (optional) The X coordinate of the sprite’s starting tile map location.
 
locY:                (optional) The Y coordinate of the sprite’s starting tile map location.
 
levelWidth:      (optional) The desired width of the sprite. The sprite will be scaled to this width.
 
levelHeight:      (optional) The desired height of the sprite. The sprite will be scaled to this height.
 
offsetX:            (optional) Alters the rendered position of the sprite without affecting its position on the map. The engine will alter the sprite’s anchorX property.
 
offsetY:            (optional) Alters the rendered position of the sprite without affecting its position on the map. The engine will alter the sprite’s anchorY property.
 
lighting:            (boolean) Sets whether MTE is allowed to control the sprite’s color.
 
constrainToMap:         (table) Specifies whether the sprite will leave the left, top, right, or bottom of the map if moveSprite or moveSpriteTo are given destinations outside of the map. For example {true, false, true, true} will prevent the sprite from leaving the left, right, or bottom edge of the map, but allow the sprite to leave the top edge of the map.
 
sortSprite:       (boolean) If true, allows MTE to control the render order of the sprite. The MTE flag enableSpriteSorting must be ‘true’ in order for this to work.
 
sortSpriteOnce: (boolean) If both sortSprite and sortSpriteOnce are true, MTE will sort the sprite a single time and then set sortSprite to false. The user can set sortSprite back to true to sort the sprite again whenever needed; the engine will sort the sprite again and set sortSprite back to false each time.
 
offscreenPhysics: (boolean) If true, the sprite will spawn a tiny area of the map immediately around itself while offscreen, allowing the physics simulation to continue no matter where the sprite is on the map. This will allow physics objects to remain active anywhere on the map, without the objects falling through the world or moving through walls.
 
heightMap: (table) The effective height of each of the sprite's four corners. Positive values will make the corner appear closer (coming out of the screen). Negative values will make the corner appear farther away (going into the screen). For example; {1, 1, -1, -1}
 
followHeightMap: (boolean) Sets whether the sprite conforms to the heightMap of the layer it is on. If true, the sprite will alter it's path (shape) to appear larger or smaller as the height of the terrain changes.
 
color:                (table) Sets the true color of the sprite so that tinting sprites will not lose their color when layer and tile lighting is applied to them. For example; {1, 0.6, 0.3}
Example:         local spriteSheet = graphics.newImageSheet("spriteSheetTall.png",
                                    {width = 32, height = 64, numFrames = 96})
                        local sequenceData = {
                                    {name = "up", sheet = spriteSheet, frames = {85, 86}, time = 400, loopCount = 0},
                                    {name = "down", sheet = spriteSheet, frames = {49, 50}, time = 400, loopCount = 0},
                                    {name = "left", sheet = spriteSheet, frames = {61, 62}, time = 400, loopCount = 0},
                                    {name = "right", sheet = spriteSheet, frames = {73, 74}, time = 400, loopCount = 0}
                        }
                        local player = display.newSprite(spriteSheet, sequenceData)
                        local setup = {
                                    kind = "sprite",
                                    layer =  mte.getSpriteLayer(1),
                                    locX = 53,
                                    locY = 43,
                                    levelWidth = 40,
                                    levelHeight = 40,
                        }
                        mte.addSprite(player, setup)


### alignParallaxLayer(layer, xAlign, yAlign)

Aligns the parallax layer with the rest of the map according to xAlign and yAlign. For example, if xAlign and yAlign are both set to “center” then the center of the parallax layer and the center of the other map layers will all line up when the camera reaches the center of the map. If xAlign is “left” and yAlign is “top” the parallax layer’s top left edge will line up with the top left edge of the rest of the map layers when the camera reaches the top left edge of the map.
 
layer:               (number) A parallax layer in the tilemap.
 
xAlign:              (string) “center”, “left”, or “right”
 
yAlign:              (string) “center”, “top”, or “bottom”

### appendMap(src, dir, locX, locY, layer, overwrite)

Loads the map with the specified source from the specified directory and inserts it into the currently active map at the specified location, at the specified layer. For example, if you load a map with 4 layers, and you append a second map with 4 layers on layer 2, the resulting combined map will have 5 layers. The location parameters will set where the map is inserted. For example, if locX = 10 and locY = 10, the top left corner of the new map will begin at that location. MTE will automatically increase the dimensions of the current map to accommodate any new map appended to it.
Appended maps will be stored in active memory unless unloaded. The developer can append the same new map multiple times without having to access a file in device storage, improving performance where large maps are built from smaller maps.
 
src:                  (string) The path to the map file.
 
dir:                   (string, optional): “Documents”, “Temporary”, or “Resource”. Defaults to “Resource” if nil.
locX:                The X location in the current map where the new map should begin.
locY:                The Y location in the current map where the new map should begin.
layer:                The layer of the current map onto which the new map’s layers will be stacked. If layer is set to 2, the first layer of the new map will be inserted into layer 2, the second layer of the new map will be inserted into layer 3, and so on.
overwrite:        (boolean) If false, MTE will not replace old tile data with new tile data. The appended map will only be copied into empty space on the current map. If true, MTE will replace old tile data with new tile data when a conflict occurs. MTE will not replace current tile data with empty space from the new map.

### cameraFrozen

This boolean MTE flag sets whether the engine can update the camera position. Freezing the camera has the effect of pausing any movements started by moveCameraTo or moveCamera
.

### cameraLocX

This MTE property is the X coordinate of the camera’s location on the tile map. This is intended as a read-only property. Users should not alter this property; use setCamera() instead.
 

### cameraLocY

This MTE property is the Y coordinate of the camera’s location on the tile map. This is intended as a read-only property. Users should not alter this property; use setCamera() instead.

### cameraX

This MTE property is the X coordinate of the camera’s position. This is intended as a read-only property. Users should not alter this property; use setCamera() instead.

### cameraY

This MTE property is the Y coordinate of the camera’s position. This is intended as a read-only property. Users should not alter this property, use setCamera() instead.

### cancelSpriteMove(sprite)

Cancels a camera move initiated by moveCameraTo. Moving a layer camera is treated differently from moving the master camera. If a moveCameraTo command was issued without a layer parameter, cancelCameraMove will always stop all camera movement; it will ignore the own layer argument.
 
layer:                (number, optional) A layer in the tile map.

### cancelCameraMove(layer)

Cancels a sprite move initiated by moveSpriteTo.
 
sprite:                A displayObject.

### changeSpriteLayer(sprite, layer)

Sends a sprite to a different layer in the map and rescales the sprite to match the scale of the new layer.
 
sprite:             A displayObject.
 
layer:               The destination layer in the tile map.
 
           
Example:         local layer = 9
                        mte.changeSpriteLayer(mySprite, layer)

### cleanup(unload)

Empties MTE’s world arrays and camera position variables, removes all sprites, and removes all tile objects.
 
unload:            (boolean, optional) Sets whether MTE should unload the map from memory.
The default behavior is for the map to be kept in memory. The next time loadMap is called for this map it will already be in memory, significantly reducing loading time. If the app is not going to return to the map it should be unloaded to conserve device memory.

### constrainCamera(parameters)

Constrains the camera to an area on the tilemap. The field of view will stay within this area unless it is too small for the field of view to fit inside of it, in which case the camera will center on the constraint area.
 
Alternatively, you can choose to leave some edges unconstrained. For example, you can set a top constraint and a bottom constraint, but leave left and right unconstrained. The camera will move freely back and forth along the X axis, but it will only move up and down along the Y axis to the extent possible without leaving the constraints.
 
If the camera is outside of the new constraint area it will automatically move into it. You may set the movement time in milliseconds and the movement easing function to use during this camera transition. An important gotcha is that no other camera movement can be active when this move takes place. Furthermore, a sprite on which the camera is focused (setCameraFocus) must be stationary. An optional parameter will automatically freeze the sprite while the move takes place and unfreeze it when the move is finished.
 
Calling constrainCamera() with no parameters will automatically constrain the camera to the map area. The camera will stop when it reaches the edges of the map so no black borders appear.
Returns a table of the four constraint tables: constrainTop, constrainLeft, constrainRight, and constrainBottom.
 
parameters:    (table, optional) Defines the constraints, configures the camera’s movement into the constrain area, sets the alignment of parallax layers. This table is optional. The default behavior is to constrain the camera to the boundaries of the tile map.
 
Format for parameters:
 
loc:                  (table, optional) A table containing the constraints; {left, top, right, bottom}. Constraints may be numbers or the boolean “false,” or nil.
 
levelPos:              (table, optional) A table containing the constraints; {left, top, right, bottom}. Constraints may be numbers or the boolean “false,” or nil.
 
xAlign:                  (string) Aligns the map’s parallax layers to the map’s non-parallax layers. Possible values: “center”, “left”, “right”
 
yAlign:              (string) See xAlign. Possible values: “center”, “top”, “bottom”
 
layer:               (number) A layer in the tilemap. Use nil to constrain all layers simultaneously.
 
time:                (number) Camera movement time in milliseconds.
 
transition:        (easing) Desired easing function for camera movement i.e. easing.inOutQuad
 
holdSprite:       (boolean) Freezes the sprite on which the camera is focused- the sprite passed to the setCameraFocus(sprite) function- while the camera is moving into the constraint area, unfreezing the sprite when the movement is complete. Default is ‘true’.
 
 
 Examples:
 
mte.constrainCamera()
 
mte.constrainCamera({ levelPos = {256, 352, 704, 1088} })
 
mte.constrainCamera({ loc = {1, false, 10, false}, time = 1000, transition = easing.inOutExpo })
 
mte.constrainCamera({
            levelPos = {100, 100, 1000, 1000},
            layer = 5,
            time = 1200,
            transition = easing.inOutQuad,
            xAlign = “center”,
            yAlign = “top”
})

### convert(operation, xArg, yArg, layer)

Converts a coordinate from one coordinate system to another. For example, converts map location coordinates to screen position coordinates. Returns a table of the x and y output coordinates if both xArg and yArg exist. If either xArg or yArg are nil the function will return only the coordinate whose corresponding argument exists.
 
operation:        (string) The type of conversion to perform. Possible values are:
                                    “screenPosToLevelPos”
                                    “screenPosToLoc”
                                    “levelPosToScreenPos”
                                    “levelPosToLoc”
                                    “locToScreenPos”
                                    “locToLevelPos”
 
xArg:                (number) The x coordinate to convert.
 
yArg:                (number) The y coordinate to convert.
 
layers:             (number) A layer on the tile map. The layer will alter the result of convert operations involving screen coordinates where scaled layers are in use. For example, the same level position will give a different screen position on two layers if one lay has a scale of 1 and the other has a scale of 1.1
           
Example:         local scrX = 100
                        local scrY = 150
                        local layer = 1
                        local levelPos = mte.convert("screenPosToLevelPos", scrX, scrY, layer)
                        print(levelPos.x)
                        print(levelPos.y)
 
Example2:       local levelPosX = 2400
                        local layer = 2
                        local locX = mte.convert(“levelPosToLoc”, levelPosX, nil, layer)
                        print(locX)

 
### debug(fps)

Displays onscreen debug information about camera position, camera movement, total tile objects, memory use, and frame-rate. This function must be called every frame or the output will not update.
 
fps:                  (number, optional) The effective frames per second of the debug statement, useful when debug is called every ’n’ frames. For example, if your app is set to run at 60fps, but you only call debug every other frame, the effective fps of the debug statement is 30fps.

### detectObjectLayers()

Searches the map for Object Layers. Returns an array of layer indexes.
 
Example:         local objLayers = mte.detectObjectLayers()
                        mte.getObjectProperties({locX = 10, locY = 20, layer = objLayers[1]})

### detectSpriteLayers()

Searches the map for Sprite Layers. A Sprite Layer is any layer with a property named spriteLayer.
 
Example:         local spriteLayers = mte.detectSpriteLayers()
                        mte.changeObjectLayer(myObject, spriteLayers[1])

### disableHeightMaps()

Disables the engine’s height map system. Height maps are disabled by default. Use enableHeightMaps() to enable the engine’s height map system.

### disablePinchZoom()

Disables the engine’s built-in PinchZoom routine.

### disableTouchScroll()

Disables the engine’s built-in TouchScroll routine.

### drawObject(name)

Draws the Tiled Object with the matching name if its properties include physics properties, display properties, or both.
 
name:                (string) The name of the object, set in Tiled.

### drawObjects(new)

Draws all Tiled Objects which have physics properties or display properties, or both.
new:                (boolean) If true, the function will only draw objects which haven’t already been drawn. For example, if a map is loaded and drawObjects is called, and then a map is appended to the current map and drawObjects is called again, this parameter controls whether MTE redraws all objects or only draws the objects imported as a result of appending a new map.

 
### enableBox2DPhysics(arg)

By default MTE ignores physics properties assigned to tiles and layers in Tiled. Calling this function sets the engine to read those properties and create physics bodies for tiles automatically. This function must be called before loadMap().
 
Physics is accessible from whatever require assignment was used to load MTE, but the user is not required to send physics calls through MTE. The user can also require physics and make direct calls. For example, mte.physics.setGravity and physics.setGravity are identical and both lead to the same instance of Corona’s physics simulation.
 
arg:                  (string) “by layer” or “all”, or nil.
 
 
Example:         local mte = require("MTE.mte")
                        mte.enableBox2DPhysics(“all”)
                        mte.physics.start()
                        mte.physics.setGravity(0, 150)
                        mte.physics.setDrawMode("hybrid")

### enableHeightMaps()

Enables the engine’s height map system. The height map system is disabled by default. This will negatively impact performance on weaker hardware. This feature requires Corona Pro or Corona Enterprise.

### enableNormalMaps

Enables the engine’s normal map system. The normal map system is disabled by default.
This will negatively impact performance on weaker hardware. This feature requires Corona Pro or Corona Enterprise.

### enablePinchZoom()

Enables the engine’s built-in PinchZoom routine. Placing two fingers on the screen and moving them together will zoom the map out. Doing the reverse will zoom the map in. Note: you must call system.activate( "multitouch" ) to enable multitouch before calling this function.
MTE’s pinch zoom routine fires an event named mteTouchScrollPinchZoom whenever the routine receives a touch event. Pinch Zoom and Touch Scroll send the same event, not two seperate events.
Example:
mte.enablePinchZoom()
local mteScrollZoom = function(event)
        print(event.name, event.phase, event.id, event.levelPosX, event.levelPosY, event.locX, event.locY, event.numTotalTouches, event.previousTouches)
end
Runtime:addEventListener("mteTouchScrollPinchZoom", mteScrollZoom)

### enableSpriteSorting

Set this boolean to true before calling loadMap() to enable the sprite sorting feature. The sprites on a spriteLayer will be arranged by their Y location on the map. A sprite at locY = 20 will render in front of a sprite at locY = 19 and behind a sprite at locY = 21. This is useful for games with a forced perspective view, a good example being Double Dragon and other classic beat-em-up games. This feature is intended for orthographic maps; Isometric maps sort sprites automatically using a different algorithm.
 
This function must be called before loadMap()
 
Example:        mte.enableSpriteSorting = true

### enableTileFlipAndRotation()

Individual tiles can be flipped or rotated in the Tiled map editor. MTE ignores these operations by default, displaying flipped and rotated tiles as if they haven’t been flipped or rotated. Call enableTileFlipAndRotation() to set MTE to display the tiles in their flipped and/or rotated states. This may have a minor impact on memory usage.
 
This function must be called before loadMap().

### enableTouchScroll()

Enables the engine’s built-in TouchScroll routine. Swiping or dragging a finger across the screen will scroll the map.
MTE’s touch scroll routine fires an event named mteTouchScrollPinchZoom whenever the routine receives a touch event. Pinch Zoom and Touch Scroll send the same event, not two seperate events.
Example:
mte.enableTouchScroll()
local mteScrollZoom = function(event)
        print(event.name, event.phase, event.id, event.levelPosX, event.levelPosY, event.locX, event.locY, event.numTotalTouches, event.previousTouches)
end
Runtime:addEventListener("mteTouchScrollPinchZoom", mteScrollZoom)

 
### fadeLayer(layer, alpha, time, transition)

Changes the alpha of a map layer over time using the specified easing function. If transition is nil it will default to easing.linear If alpha and time are nil the function will check the current status of the layer, returning true if the layer is busy fading or nil if the layer is finished/idle. Starting a new fade operation will seamlessly override the old fade operation. This function alters the layer object, not the individual tiles on that layer.
 
layer:               A layer in the tile map.
 
alpha:              The desired alpha, from 0 to 1.
 
time:                The duration in milliseconds.
 
transition:        (easing) The desired easing function i.e. easing.inOutQuad or easing.linear.
 
 
Example:         --checks status of layer and initiates fade if not already fading
                        if not mte.fadeLayer(1) then
                                    mte.fadeLayer(1, 0.5, 2000, easing.inOutExpo)
                        end

### fadeLevel(level, alpha, time, transition)

Changes the alpha of all the layers in a map level over time using the specified easing function. If transition is nil it will default to easing.linear. If alpha and time are nil the function will check the current status of the level’s layers, returning true if any one layer is busy fading or nil if they are all finished/idle. Starting a new fade operation will seamlessly override the old fade operation. This function alters the layer objects contained in a level, not the individual tiles on those layers.
 
level:                A level in the tile map.
 
alpha:              The desired alpha, from 0 to 1.
 
time:                The duration in milliseconds.
 
transition:        (easing) The desired easing function i.e. easing.inOutQuad or easing.linear.
 
 
Example:         --checks status of level and initiates fade if not already fading
                        if not mte.fadeLevel(3) then
                                    mte.fadeLevel(3, 0.4, 33, easing.outQuad)
                        end

### fadeMap(alpha, time, transition)

Changes the alpha of all the layers in the map over time using the specified easing function. If transition is nil it will default to easing.linear. If alpha and time are nil the function will check the current status of the map’s layers, returning true if any one layer is busy fading or nil if they are all finished/idle. Starting a new fade operation will seamlessly override the old fade operation. This function alters the layer objects contained in the map, not the individual tiles on those layers, nor the master group containing those layers.
 
alpha:              The desired alpha, from 0 to 1.
 
time:                The duration in milliseconds.
 
transition:        (easing) The desired easing function i.e. easing.inOutQuad or easing.linear.
 
 
Example:         --checks status of map and initiates fade if not already fading
                        if not mte.fadeMap() then
                                    mte.fadeMap(0.9, 16, easing.inExpo)
                        end

### fadeTile(locX, locY, layer, alpha, time, transition)

Changes the alpha of a map tile over time using the specified easing function. If transition is nil it will default to easing.linear. If alpha and time are nil the function will check the current status of the tile, returning true if the tile is busy fading or nil if the tile is finished/idle. Starting a new fade operation will seamlessly override the old fade operation.
 
locX:                The X coordinate of the tile’s location on the map.
 
locY:                The Y coordinate of the tile’s location on the map.
 
layer:               The map layer containing the tile.
 
alpha:              The desired alpha, from 0 to 1.
 
time:                The duration in milliseconds.
 
transition:        (easing) The desired easing function i.e. easing.inOutQuad or easing.linear.
 
 
Example:         --checks status of tile and initiates fade if not already fading
                        if not mte.fadeTile(10, 10, 1) then
                                    mte.fadeTile(10, 10, 1, 0.1, 200, “inOutExpo”)
                        end
 
### getCamera(layer)

Returns a table containing the camera’s position and location for the given layer.
 
layer:               (number, optional) A layer in the tilemap. Defaults to the reference layer.

### getCullingBounds(layer, arg)

Returns the boundary of the active culling region specified in arg. If arg is nil, returns a table containing the left, top, right, and bottom boundaries of the culling region. The culling region contains the tile displayObjects spawned by the engine. In other words, it is the active region of the map in which you can address tile objects. The area outside of the culling region contains no tile objects, just data.
 
layer:   (number) A layer in the tile map.
 
arg:      (string, optional) “top”, “bottom”, “left”, “right”, or nil.
 
 
Example:         local top = mte.getScreenExtent(“top”)
                        print(top)
                       
Example2:       local bounds = mte.getScreenExtent()
                        print(bounds.top)

### getLayerObj(parameters)

Returns a layer’s displayGroup, an array of displayGroups of a given level, or an array of every layers’ displayGroups, depending on parameters. The user can then directly access and modify the displayGroup through all the usual group properties.
 
parameters:    (table)
 
Format for parameters:
 
layer:               (number) A layer of the tile map.
 
level:                (number) A level of the tile map.
 
 
Example:         local displayGroup = mte.getLayerObj({layer = 1})
                        print("Children: "..displayGroup.numChildren)

### getLayerProperties(layer)

Returns the table of layer properties exactly as it appears within MTE's world arrays.
 
layer: (number) A layer in the tile map.
 
           
Example:         local layer = 1
                        local layerProperties = mte.getLayerProperties(layer)
                        print("Scale = "..layerProperties.Scale)

### getLayers(parameters)

Returns a layer table, or an array of the map’s layer tables, depending on parameters. These tables contain the layer’s properties and the world array for that layer.
 
parameters:    (table) Specifies whether to return one or more layer tables. If nil the function will return an array of every layer table.
 
Format for parameters
 
layer:               (number) A layer in the tile map. The function will return a single layer table.
 
level:                (number) A level in the tile map, if layer is not specified. The function will return an array of layer tables.
 
 
Example:         local layers = mte.getLayers()
                        local layerObjects = mte.getLayerObj()
                        if layers[1].properties.Level > playerSprite.level then
                                    layerObjects[1].isVisible = false
                        end

### getLevel()

Returns a layer’s assigned level.

### getLoadedMaps()

Returns a table of the source paths of the currently loaded maps. These strings are valid arguments for the unloadMap() function.

### getMap()

Returns the MTE map array including world data and all changes made via other functions like setMapProperties, setLayerProperties, and etc. Sprites are not included in the arrays. The typical use scenario would be saving a map after the user has made changes. Note: The engine modifies the structure of Tiled tile maps on loading, and these changes are maintained when the map is retrieved with getMap(). This was a performance-improving compromise. The function loadMap() will detect whether a map was previously modified by MTE and load it properly without user intervention.
 
           
Example:         local mapArray = {}
                        mapArray = mte.getMap()

### getMapObj()

Returns the parent group of all the layer display groups. Useful for inserting maps into storyboard scenes.

### getMapProperties()

Returns the table of map properties exactly as it appears within MTE's world arrays.
 
Example:         local mapProperties = mte.getMapProperties()
                        print("LightingStyle = "..mapProperties.LightingStyle)

### getObject(options)

Searches a map’s Tiled objects and returns those objects which match the options set. The output will always be a table, even if the table contains just one object.
 
options:           (table) A table of data used to find a specific object to get properties from.
 
Format for options
 
layer:               (number, optional) An Object Layer of the tile map.
 
level:                (number, optional) A level of the tile map which contains an Object Layer.
 
locX:                (optional) The X coordinate of the map location to search for objects.
 
locY:                (optional) The Y coordinate of the map location to search for objects.
 
levelPosX:       (optional) The X coordinate to search for objects.
 
levelPosY:       (optional) The Y coordinate to search for objects.
 
name:             (string, optional) The unique named assigned to an object in Tiled.
 
type:                (string, optional) The unique type assigned to an object in Tiled.
 
Example 1:      local properties = mte.getObject({
                                    levelPosX = 288,
                                    levelPosY = 192,
                                    layer = 4
                        })
                        local objName = properties[1].name
 
Example 2:      local properties2 = mte.getObject({name = objName})
                        print(properties2[1].type)

### getObjectLayer(level)

Returns the table index of an Object Layer within a specific level.
 
level:                (number) A level of the tile map which contains an Object Layer.
 
           
Example:         local level = 1
                        local objLayer = mte.getObjectLayer(level)
                        mte.getObjectProperties({locX = 10, locY = 20, layer = objLayer})

### getSprites(parameters)

Searches for sprites which match the specified parameters. All parameters are optional. Returns a table of sprite references.
 
parameters: (table) Describes the specific sprite(s).
 
Format for parameters:
 
name:             (string) The name specified in addSprite, or the name of a Tiled Object converted into a sprite.
 
locX:                (optional) The X coordinate of the map location to search for sprites.
 
locY:                (optional) The Y coordinate of the map location to search for sprites.
 
levelPosX:       (optional) The X coordinate to search for sprites.
 
levelPosY:       (optional) The Y coordinate to search for sprites.
 
layer:               (number) A layer of the tile map.
 
level:                (number) A level of the tile map.

### getSpriteLayer(level)

Returns the index of a layer in the tile map with a layer property of spriteLayer set to "true", within a specified level. See the intro to multi-level maps for more on maps, levels, layers, and how the hierarchy is arranged.
 
level: (number) A level of the tile map which contains a Sprite Layer.
 
           
Example:         local level = 1
                        local layer = mte.getSpriteLayer(level)
                        mte.changeSpriteLayer(mySprite, layer)

### getTileAt(parameters)

Returns the tile ID at the location on the tile map. Returns an array of tile ID’s if layer is nil.
 
parameters: (table) Describes the specific tile or the location to look for tiles.
 
Format for parameters:
 
locX:                An X location on the tile map.
 
locY:                A Y location on the tile map.
 
levelPosX:       (optional) The X coordinate of a position on the map.
 
levelPosY:       (optional) The Y coordinate of a position on the map.
 
layer:               (number) A layer in the tile map.
 
 
Example 1:      local parameters = {locX = 18, locY = 54, layer = 1}
                        local tile = mte.getTileAt(parameters)
                        local properties = mte.getTileProperties({tile = tile})
 
Example 2:      local parameters = {locX = 18, locY = 54}
                        local tiles = mte.getTileAt(parameters)
                        local properties = mte.getTileProperties({ tile = tiles[1] })

### getTileObj(locX, locY, layer)

Returns a direct reference to one of the tile display objects used in MTE’s tile display grid. The user can then directly modify the object by accessing all the usual object properties and methods, such as width, height, scale, alpha, and etc. Modifications will only last until MTE culls the tile, shortly after it leaves the screen or immediately after mte.refresh is called. Returns nil if locX and locY are not within the on-screen grid; tile display objects do not exist for offscreen tiles.
 
locX:                The X location of the tile on the map.
 
locY:                The Y location of the tile on the map.
 
layer:               (number) A layer in the tile map.
 
           
Example:         local screenPosX = 100
                        local screenPosY = 150
                        local layer = 1
                        local loc = mte.convert("screenPosToLoc", screenPosX,
                                    screenPosY,   layer)
                        local tile = mte.getTileObj(loc.x, loc.y, layer)
                        tile:setFillColor(123, 201, 0)

### getTileProperties(options)

Returns a table containing all of a tile's properties based on parameters. If parameters yields more than one tile, returns an array of tiles and their properties.
 
parameters: (table) Describes the specific tile or the location to look for tiles.
 
Format for parameters
           
tile:                   A tile index.
 
locX:                An X location on the tile map.
 
locY:                A Y location on the tile map.
 
layer:               (number) A layer of the tile map.
 
level:                (number) A level of the tile map.
 
 
Example 1:      local properties = mte.getTileProperties({tile = 1})
                        print(properties.myProperty)
 
Example 2:      local properties = mte.getTileProperties({locX = 1, locY = 1, layer = 1})
                        print(properties.myProperty)
           
Example 3:      local layer = 1
                        local properties = mte.getTileProperties({locX = 1, locY = 1})
                        print(properties[layer].myProperty)

### getTileSetNames(arg)

This function returns an array of all the tileset names specified in the json map file. A typical usage scenario would be to detect the tileset names with this function and then use those names to manually load tilesets with loadTileSet().
 
 
Example:         mte.loadMap(“map/myMap”)
                        local tilesets = mte.getTileSetNames()
                        mte.loadTileSet({name = tilesets[1], source = “sets/outsideV2_5.png”})
                        mte.setCamera({locX = 10, locY = 10, blockScale = 64})

### getTilesWithProperty(key, value, level, layer)

Returns a table of all the tile objects matching the function arguments.
 
key:      (string) The desired property. For example, “groundType”.
 
value:   (string, optional) The value of the property. For example, “mud”.
 
level:    (number, optional) The level of the tile map in which to search.
 
layer:   (number, optional) The layer of the tile map in which to search.

### getVisibleLayer(locX, locY)

Returns the lowest layer visible from directly above at the specified location. This function does not take into account the offset caused by layer scaling.
 
locX:                The X location on the tile map.
 
locY:                The Y location on the tile map.
 
 
Example:         local locX = 14
                        local locY = 28
                        local layer = mte.getVisibleLayer(locX, locY)
                        mte.changeSpriteLayer(mySprite, layer)      


### getVisibleLevel(locX, locY)

Returns the lowest level visible from directly above at the specified location. This function does not take into account the offset caused by layer scaling.
 
locX:                The X location on the tile map.
 
locY:                The Y location on the tile map.
 
 
Example:         local locX = 14
                        local locY = 28
                        local level = mte.getVisibleLevel(locX, locY)
                        local layer = mte.getSpriteLayer(level)
                        mte.changeSpriteLayer(mySprite, layer)  

 
### isoTransform2(levelPosX, levelPosY)

Transforms a position in the map data to isometric coordinates in the screen space in relation to the center of the map. Returns an array in which the X output is at index 1 and the Y output is at index 2.

### isoUntransform2(levelPosX, levelPosY)

Transforms isometric coordinates back into orthogonal coordinates in relation to the center of the map. Returns an array in which the X output is at index 1 and the Y output is at index 2.

### isoVector(velX, velY)

Transforms a vector in relation to the map data into a vector in relation to the isometric screen space. For example, moving a sprite upward on an orthographic map will result in the character moving towards the top of the screen. However in Isometric Maps, the direction of “up” on the map is actually approximately towards the top right corner of the screen. This function will convert the vector so that it’s output can be used to translate an object and get the correct results. Returns an array in which the X output is at index 1 and the Y output is at index 2.
 
Example:         local velX, velY = 32, 0
                        local isoVector = mte.isoVector(velX, velY)
                        mySprite:translate(isoVector[1], isoVector[2])

### isoVector2(velX, velY)

Tranforms an isometric vector into X and Y vectors that can be used in mte.moveCamera to move the camera through the screen space. For example, calling mte.moveCamera(10, 0) on an isometric map will move the camera towards the bottom right of the screen, following the isometric view. In order to move the camera 10 pixels to the right across the screen, pass the desired velocity vectors into isoVector2 and use it's output instead,
 
Example:         local velX, velY = 32, 0
                        local isoVector2 = mte.isoVector2(velX, velY)
                        mte.moveCamera(isoVector2[1], isoVector2[2])

 
### levelToLoc(xArg, yArg)

Converts the supplied level position coordinates into map location coordinates.
 
 
Example:         local levelPosX, levelPosY = 64, 64
                        local locX, locY = levelToLoc(levelPosX, levelPosY)
                        print(locX, locY)

### levelToLocX(xArg)

Converts the supplied X coordinate of a level position into the X coordinate of a map location.
 
 
Example:         local levelPosX, levelPosY = 64, 64
                        local locX = levelToLocX(levelPosX)
                        print(locX)

### levelToLocY(yArg)

Converts the supplied Y coordinate of a level position into the Y coordinate of a map location.
 
 
Example:         local levelPosX, levelPosY = 64, 64
                        local locY = levelToLocY(levelPosY)
                        print(locY)

### levelToScreenPos(xArg, yArg, layer)

Converts the supplied level position coordinates into screen coordinates.
 
 
Example:         local levelPosX, levelPosY = 64, 64
                        local screenX, screenY = levelToScreenPos(levelPosX, levelPosY)
                        print(screenX, screenY)

### levelToScreenPosX(xArg, layer)

Converts the supplied X coordinate of a level position into the X coordinate of a screen position.
 
 
Example:         local levelPosX, levelPosY = 64, 64
                        local screenX = levelToScreenPosX(levelPosX)
                        print(screenX)

### levelToScreenPosY(yArg, layer)

Converts the supplied Y coordinate of a level position into the Y coordinate of a screen position.
 
 
Example:         local levelPosX, levelPosY = 64, 64
                        local screenY = levelToScreenPosY(levelPosY)
                        print(screenY)

### lightingData

This table contains configuration data for MTE’s tile lighting system.
 
Format for lightingData:
 
fadeIn:             (number) The amount of light intensity the system will apply to any tile during each lighting pass. Any number less than 1 will cause the tile to gradually light until the full value is reached. The default value is 0.25.
 
fadeOut:          (number) The amount of light intensity the system will remove from any tile during each lighting pass. Any number less than 1 will cause the tile to gradually fade until the layer lighting value is reached. The default value is 0.25. For example, if a tile is fully lit and the layer lighting for the layer is 0.4 per color channel, when the light source is removed the tile will take 3 frames to drop from a light intensity of 1 to a light intensity of 0.4.
 
refreshStyle:    (number) Sets the lighting algorithm to be used. A value of 1 will set the engine to process every location’s lighting on each frame. A value of 2 will set the engine to process a number of columns of tiles every frame, alternative from one frame to the next, in order to improve performance. The default value is 2.
 
refreshAlternator: (number) Determines how many columns of tiles to skip each frame. For example, a value of will cause the engine to process lighting for every fourth column in a frame, every fourth + 1 column in the next frame, and so on until the algorithm returns to every fourth column. The result is that it takes 4 frames for all onscreen tiles to update. The default value is 4.
 
refreshCounter: (number) Sets the starting column when refreshStyle is 2. The refreshCounter value should not be set higher than the refreshAlternator or lower than 0. The default value is 1. This parameter serves as a counter; changing it is not recommended.
 
resolution:       (number) The tile lighting system calculates light by casting rays from the source. This parameter adjusts the number of rays. Casting more rays improves accuracy, while casting fewer rays improves performance. The default value is 1.1.

### loadMap(src, dir, unload)

Loads a tile map into memory, optionally unloading the previous tile map. MTE supports orthographic and isometric maps in Json or TMX format. TMX maps may use XML or CSV layer encoding. Generally Json maps are the most space-efficient and load the quickest. TMX maps using CSV layer data are somewhat larger and just a little slower to load. The advantage of using a TMX map is that the map is easily opened in Tiled, modified, saved, and the changes are reflected the next time the map runs; no need to export maps as Json files each time.
 
src:                  (string) The path to the map file.
 
dir:                   (string, optional): “Documents”, “Temporary”, or “Resource”. Defaults to “Resource” if nil.
 
unload:            (boolean, optional) Specifies whether to unload the previously active map from memory. Loading a map stored in memory is far faster than loading a map from device storage.
 
           
Example:         mte.loadMap("maps/robotRoom.json")
 
Example2:       mte.loadMap(“maps/level1/cliffside.tmx”, “Documents”)

### loadTileSet(name, source, dataSource)

Manually loads a tileset. Changing the tileset image file specified in a map file is not always convenient. This function allows other images to be loaded and assigned as the image for a map’s tileset.
 
name:              (string) The name of the tileset. This name must match a tileset name in the map file.
 
source:            (string) The path for the tileset image. The filename of the tileset does not have to match the filename in the map file.
 
dataSource:    (string, optional) The path to the TSX file containing the tileset properties and tile properties.
 
 
Example:         mte.loadTileSet(“outside”, “sets/outsideV2_5.png”)

### locToLevelPos(xArg, yArg)

Converts the supplied map location coordinates into level position coordinates.
 
 
Example:         local locX, locY = 4, 8
                        local levelPosX, levelPosY = locToLevelPos(locX, locY)
                        print(levelPosX, levelPosY)

### locToLevelPosX(xArg)

Converts the supplied X coordinate of a map location into the X coordinate of a level position.
 
 
Example:         local locX, locY = 4, 8
                        local levelPosX = locToLevelPos(locX)
                        print(levelPosX)


### locToLevelPosY(yArg)

Converts the supplied Y coordinate of a map location into the Y coordinate of a level position.
 
 
Example:         local locX, locY = 4, 8
                        local levelPosY = locToLevelPos(locY)
                        print(levelPosY)

### locToScreenPos(xArg, yArg, layer)

Converts the supplied map location coordinates into screen position coordinates.
 
 
Example:         local locX, locY = 4, 8
                        local screenPosX, screenPosY = locToLevelPos(locX, locY)
                        print(screenPosX, screenPosY)

### locToScreenPosX(xArg, layer)

Converts the supplied X coordinate of a map location into the X coordinate of a screen position.
 
 
Example:         local locX, locY = 4, 8
                        local screenPosX = locToLevelPos(locX)
                        print(screenPosX)

### locToScreenPosY(yArg, layer)

Converts the supplied Y coordinate of a map location into the Y coordinate of a screen position.
 
 
Example:         local locX, locY = 4, 8
                        local screenPosY = locToLevelPos(locY)
                        print(screenPosY)

 
### mapPath

The path to the map currently in use.

### managePhysicsStates

This MTE parameter allows or disallows the engine from changing any sprite’s .isBodyActive or .isAwake physics properties. If set to false, the engine will not manage the physics states of sprites. If set to true, the engine will manage the physics states of sprites.
For example, if set to true, a physics object moving offscreen will be put to sleep and then set to inactive. If set to false, the physics object will retain whatever states you assign to it, regardless of position relative to the screen.
The default value is true.

### maxZoom

The maximum map scale allowed by any operation which changes the scale of the map. For example, if maxZoom = 4 a user will only be able to pinchZoom in until the map scale is 4. Similiarly, any mte.zoom() call will only increase the scale of the map until it is 4 even when the function’s scale argument is greater than 4.

### minZoom

The minimum map scale allowed by any operation which changes the scale of the map. For example, if minZoom = 0.25 a user will only be able to pinchZoom in until the map scale is 0.25. Calling mte.zoom() will only decrease the map scale until it is 0.25 even when the function’s scale argument is less than 0.25.

### moveCamera(deltaX, deltaY, layer)

Sets the camera to move a distance across the map. Movement is not processed until update() executes. Calling update() once every frame in an enterFrame event is recommended.
 
deltaX:             The change in X coordinate of the camera's level position.
 
deltaY:             The change in Y coordinate of the camera's level position.
 
layer:               (number, optional) The layer of the camera to be moved. The default value is the reference layer; moving the reference layer camera moves all layer cameras simultaneously and is the default behavior of MTE. Setting layer to any other value will have the effect of moving only that one layer of the map.
 
           
Example:         local deltaX = 10
                        local deltaY = 10
                        mte.moveCamera(deltaX, deltaY)

### moveCameraTo(parameters)

Transitions the camera from one position to another optionally using easing functions. Movement is not processed until update() executes. Calling update() once every frame in an enterFrame event is recommended.
 
parameters:    (table) Data describing the destination, duration, and easing.
 
Format for parameters
 
levelPosX:       The X coordinate of the camera’s destination position.
 
levelPosY:       The Y coordinate of the camera’s destination position.
 
sprite:             (optional) A sprite to which the camera should move.
 
locX:                (optional) The X coordinate of the camera’s destination location.
 
locY:                (optional) The Y coordinate of the camera’s destination location.
                       
time:                (optional) The duration of the movement in milliseconds.
 
transition:        (easing, optional) Desired easing function for camera movement i.e. easing.inOutQuad
 
 
Example1:       mte.moveCameraTo({sprite = mySprite, time = 50, transition = easing.inOutExpo})
 
Example2:       mte.moveCameraTo({locX = 110, locY = 60, time = 50, transition = easing.inOutQuad})
 
Example3:       mte.moveCameraTo({levelPosX = 2000, levelPosY = 500, time = 50, transition = easing.inExpo})

### moveSprite(sprite, deltaX, deltaY)

Sets the sprite to move a distance across the map. Movement is not processed until update() executes. Calling update() once every frame in an enterFrame event is recommended.
 
 
sprite:             A sprite object reference.
 
deltaX:             The change in X coordinate of the sprite’s level position.
 
deltaY:             The change in Y coordinate of the sprite’s level position.
 
 
Example:         mte.moveSprite(mySprite, 100, 120)

### moveSpriteTo(parameters)

Transitions the sprite from one position to another optionally using easing functions. Movement is not processed until update() executes. Calling update() once every frame in an enterFrame event is recommended.
 
 
parameters:    (table) Data describing the destination, duration, and easing.
 
Format for parameters
 
sprite:              A sprite object reference.
 
levelPosX:       The X coordinate of the sprite’s destination position.
 
levelPosY:       The Y coordinate of the sprite’s destination position.
 
locX:                (optional) The X coordinate of the sprite’s destination location.
 
locY:                (optional) The Y coordinate of the sprite’s destination location.
                       
time:                (optional) The duration of the movement in milliseconds.
 
transition:        (easing, optional) Desired easing function for sprite movement i.e. easing.inOutQuad
 
onComplete:   (listener) Creates a temporary event listener for the sprite. The listener is triggered when the sprite’s current movement is complete, and then removed.
 
 
Example:         mte.moveSpriteTo({sprite = mySprite, locX = 20, locY = 15, time = 30, transition = easing.inQuad})

 
### overDraw

Adjusts the size of tiles to help hide edge artifacts on some tilesets. The default value is 0; tiles spawn at the size specified in the map file. Setting a value of 2, for example, will increase the width and height of every tile by 2. Setting a value of five will increase the width and height of every tile by 5, and so on. The scale of the map does not change; the tiles do not spawn further apart.

 
### perlinNoise(parameters)

The perlin noise function will generate pseudo-random noise, process that noise based on input you give it, and load the results into either a world data (tile) table, a heightMap table, a perlinLighting table (which takes precedent over the layer lighting configured in Tiled), or an output table you specify- or any combination of the above.
 
Within each of these outputs you can set the scale of the output. For example, layer data is scaled so that the noise falls between the values of 0 and 100 by default. In the example above I've changed it to a scale of 6, because I want to assign six possible tiles to the layer based on the perlin noise value. The result is that the noise is scaled so that it falls into a range of from 0 to 6. You can offset the scale if you'd like as well. An offset of 3 and a scale of 6 will give you data ranging from 3 to 9. Tile data likes to be in whole numbers. You can use the roundResults, floorResults, and ceilResults boolean parameters to get whole number values from the noise, otherwise the noise will have a decimal value. These parameters are available for all output modes, and can be set individually for each mode.
 
A perlinLevel is a table assigning an arbitrary output value to a range in the perlin data. In the above example the output is scaled to 0 to 6. I assign the tileID of my water tile to the lower perlin values and various other tiles to the upper perlin values. PerlinLevels can be set independently for each of the four output modes.
 
Within perlinLevels you can set masks. A mask is a table assigning an arbitrary output to a range of PRE-EXISTING DATA. If you call a perlin operation on a world table which already contains tiles, masks can be setup to produce an output based on the pre-existing tileID's, within each perlinLevel. Say you've generated a world with sandy beaches, grassy midlands, and rocky mountains, and now you want to add forests to this world. You could run the perlin noise function a second time to determine the location of forests, using perlinLevels to define forests and voids. You could then use masks within those levels to choose the type of tree tile; palm trees on sand tiles, leafy trees on grasslands, and scraggly mountain trees on mountains.
 
All this is optional. If you call perlinNoise({}) with an empty set of parameters it'll spit out a 2D table of noise ranging from 0 to 100, the size of the map array.
 
parameters:    (table) Configuration data for the noise function and its output.
 
Format for parameters:
 
width:               The width of the output.
 
height:             The height of the output.
 
freqX:               The frequency of the noise along the X axis. The default value is 0.05.
 
freqY:               The frequency of the noise along the Y axis. High frequency noise produces smaller features while lower frequency noise produces larger features. The default value is 0.05.
 
amp:                The amplitude of the noise. This has the effect of increasing the largest noise values. The default value is 0.99.
 
per:                  The persistence of the noise within the algorithm. The default value is 0.65.
 
oct:                  The octaves of the noise algorithm. Each octave reprocesses the output using noise on a smaller scale. Increasing the octaves will generate more complicated, intricate structures in the noise, but the operation as a whole will take longer to complete. The default value is 6.
 
layer:               (table, optional) Configuration data for the layer output.
 
Format for layer:
 
layer:               (number or string) The layer to which the perlin noise should be written. The perlin noise is stored as tileID’s. Setting layer equal to “global” will save the perlin noise to every layer.
 
scale:              (number, optional) Sets the range of the noise. A scale of 6 will produce noise ranging between 0 and 6.
 
roundResults: (boolean) Setting this parameter will round the perlin noise output to whole numbers.
 
floorResults:    (boolean) Setting this parameter will perform a math.floor operation on the perlin noise output.
 
ceilResults:     (boolean) Setting this parameter will perform a math.ceil operation on the perlin noise output.
 
perlinLevels:    (table) Assigns an arbitrary output value to a range in the perlin data.
 
Format for perlinLevels:
 
min:                 The lower bound of the perlinLevel, inclusive.
 
max:                The upper bound of the perlinLevel.
 
value:               The value to assign in the perlin noise output.
 
mask:              (table) Alters the output of the perlinLevel based on the pre-existing layer data.
 
Format for mask:
 
min:                 The lower bound of the mask, inclusive.
 
max:                The upper bound of the mask.
 
emptySpace:   (boolean, replaces max and min) Sets the mask as any empty space on the tile layer. Empty space on the layer is any location with a tile ID of 0. The result is that the empty places on the tile map layer will be filled with perlin noise output while any pre-existing tiles will be left in place.
 
anyTile:            (boolean, replaces max and min) Sets the mask as any tile on the layer. The result is that empty space on the tile layer will remain empty while any tiles present will be replaced by the perlin noise output.
 
value:               (optional) The value to assign in the perlin noise output.
 
—————————————————
 
heightMap:       (table) Configuration data for the heightMap output.
 
Format for heightMap:
 
layer:               (number or string) The heightMap to which the perlin noise should be written. The perlin noise is stored on map.layers[layer].heightMap, a two-dimensional array corresponding to the layer’s world array. Setting layer equal to “global” will save the perlin noise to a global heightMap affecting every layer on the map.
 
scale:              (number, optional) Sets the range of the noise. A scale of 6 will produce noise ranging between 0 and 6.
 
offset:              (number) Moves the output range. A scale of 6 and offset of 3 will produce noise ranging from 3 to 9.
 
roundResults: (boolean) Setting this parameter will round the perlin noise output to whole numbers.
 
floorResults:    (boolean) Setting this parameter will perform a math.floor operation on the perlin noise output.
 
ceilResults:     (boolean) Setting this parameter will perform a math.ceil operation on the perlin noise output.
 
perlinLevels:    (table) Assigns an arbitrary output value to a range in the perlin data.
 
Format for perlinLevels:
 
min:                 The lower bound of the perlinLevel, inclusive.
 
max:                The upper bound of the perlinLevel.
 
value:               (optional) The value to assign in the perlin noise output.
 
mask:              (table) Alters the output of the perlinLevel based on the pre-existing heightMap data.
 
Format for mask:
 
min:                 The lower bound of the mask, inclusive.
 
max:                The upper bound of the mask.
 
emptySpace:   (boolean, replaces max and min) Sets the mask as any empty space on the heightMap. Empty space on the heightMap is any location with a value of 0. The result is that the empty places on the heightMap will be filled with perlin noise output while any pre-existing height data will be left in place.
 
anyTile:            (boolean, replaces max and min) Sets the mask as any value on the heightMap. The result is that empty space on the heightMap will remain empty while any locations with a value other than 0 will be overwritten.
 
value:               (optional) The value to assign in the perlin noise output.
 
—————————————————
 
 
lighting:            (table) Configuration data for the lighting output.
 
Format for lighting:
 
layer:               (number or string) The layer to which the perlin noise should be written as lighting data. The perlin noise is stored on map.layers[layer].perlinLighting, a two-dimensional array corresponding to the layer’s world array. Setting layer equal to “global” will save the perlin noise to a global lighting table affecting every layer on the map.
 
scale:              (number, optional) Sets the range of the noise. A scale of 1 will produce noise ranging between 0 and 1.
 
offset:              (number) Moves the output range. A scale of 0.5 and offset of 0.25 will produce noise ranging from 0.25 to 0.75.
 
roundResults: (boolean) Setting this parameter will round the perlin noise output to whole numbers.
 
floorResults:    (boolean) Setting this parameter will perform a math.floor operation on the perlin noise output.
 
ceilResults:     (boolean) Setting this parameter will perform a math.ceil operation on the perlin noise output.
 
perlinLevels:    (table) Assigns an arbitrary output value to a range in the perlin data.
 
Format for perlinLevels:
 
min:                 The lower bound of the perlinLevel, inclusive.
 
max:                The upper bound of the perlinLevel.
 
value:               (optional) The value to assign in the perlin noise output.
 
mask:              (table) Alters the output of the perlinLevel based on the pre-existing lighting data.
 
Format for mask:
 
min:                 The lower bound of the mask, inclusive.
 
max:                The upper bound of the mask.
 
emptySpace:   (boolean, replaces max and min) Sets the mask as any empty space on the lighting table. Empty space on the lighting table is any location with a value of 0. The result is that the empty places on the lighting table will be filled with perlin noise output while any pre-existing lighting data will be left in place.
 
anyTile:            (boolean, replaces max and min) Sets the mask as any value on the lighting table other than 0. The result is that empty space on the lighting table will remain empty while any locations with a value other than 0 will be overwritten.
 
value:               (optional) The value to assign in the perlin noise output.
 
—————————————————
 
output:             (table) Configuration data for the user-defined output table.
 
Format for output:
 
outputTable:    (table, optional) The two-dimensional output table supplied by the user. The dimensions of this table must match the width and height parameters of the perlin noise function. If a table isn’t set, the function will generate a table of the correct size.
 
scale:              (number, optional) Sets the range of the noise. A scale of 100 will produce noise ranging between 0 and 100.
 
offset:              (number) Moves the output range. A scale of 20 and offset of 5 will produce noise ranging from 5 to 25.
 
roundResults: (boolean) Setting this parameter will round the perlin noise output to whole numbers.
 
floorResults:    (boolean) Setting this parameter will perform a math.floor operation on the perlin noise output.
 
ceilResults:     (boolean) Setting this parameter will perform a math.ceil operation on the perlin noise output.
 
perlinLevels:    (table) Assigns an arbitrary output value to a range in the perlin data.
 
Format for perlinLevels:
 
min:                 The lower bound of the perlinLevel, inclusive.
 
max:                The upper bound of the perlinLevel.
 
value:               (optional) The value to assign in the perlin noise output.
 
mask:              (table) Alters the output of the perlinLevel based on the pre-existing table data.
 
Format for mask:
 
min:                 The lower bound of the mask, inclusive.
 
max:                The upper bound of the mask.
 
emptySpace:   (boolean, replaces max and min) Sets the mask as any empty space on the output table. Empty space on the output table is any location with a value of 0. The result is that the empty places on the output table will be filled with perlin noise output while any pre-existing output data will be left in place.
 
anyTile:            (boolean, replaces max and min) Sets the mask as any value on the output table other than 0. The result is that empty space on the output table will remain empty while any locations with a value other than 0 will be overwritten.
 
value:               (optional) The value to assign in the perlin noise output.
 
—————————————————
 
Example:        
 
mte1.enableHeightMaps()
 
local layer = {layer = 1,
                        scale = 6,
                        roundResults = true,
                        perlinLevels = {{min = 0, max = 1, value = 33},
                                                {min = 1, max = 2, value = 33},
                                                {min = 2, max = 3, value = 33},
                                                {min = 3, max = 4, value = 36},
                                                {min = 4, max = 5, value = 37},
                                                {min = 5, max = 7, value = 38}
                                                }
                }
               
local heightMap = {layer = 1,
                        scale = 1,
                        offset = -0.5,
                        perlinLevels = {{min = -0.5, max = 0, value = 0},
                                                {min = 0, max = 1.1}
                                                }
                        }
                       
local lighting = {layer = 1,
                        scale = 1,
                        offset = 0.35
                        }
 
mte1.perlinNoise({freqX = 0.05, freqY = 0.05, oct = 4, layer = layer, heightMap = heightMap, lighting = lighting})

### physics

MTE’s reference to Corona SDK’s physics API. Physics calls can be made through MTE’s reference or the user can use a require statement elsewhere in the code and make direct calls.

### physicsData

This table stores the default physics properties for tiles, globally and on individual layers. These do not have to be configured by the user. The user can set the default layer properties using Tiled layer properties, otherwise the layers will load the global defaults when the map loads.
 
Format for physicsData:
 
defaultDensity:            The global default density of physics objects.
 
defaultFriction:            The global default friction of physics objects.
 
defaultBounce:            The global default bounce of physics objects.
 
defaultBodyType:        The global default bodyType of physics objects.
 
defaultShape:              The global default shape of physics objects.
 
defaultRadius:             The global default radius of physics objects.
 
defaultFilter:                The global default collision filter data for physics objects.
 
layer:                           (table) Stores the default physics properties for individual layers. When the map loads the global defaults above are copied into the layer defaults below. Users can also configure Tiled layer properties to load their own layer defaults. For example, MTE will copy the value of a property named “density” into the layer defaults automatically when the map loads.
 
Format for layer:
 
defaultDensity:            The layer default density of physics objects.
 
defaultFriction:            The layer default friction of physics objects.
 
defaultBounce:            The layer default bounce of physics objects.
 
defaultBodyType:        The layer default bodyType of physics objects.
 
defaultShape:              The layer default shape of physics objects.
 
defaultRadius:             The layer default radius of physics objects.
 
defaultFilter:                The layer default collision filter data for physics objects.

### preloadMap(src, dir)

Loads a tile map into memory to be used by loadMap() at a later time. A map stored in active memory will load far more quickly then a map stored in device storage.
 
src:                  (string) The path to the map file.
 
dir:                   (string) Optional: “Documents”, “Temporary”, or “Resource”. Defaults to “Resource” if nil.

### processLight(layer, light)

Casts light from a light source, creating areas of light and shadow depending on the surroundings. This function is called by the engine in the update() function and does not need user intervention unless the user wishes to process the lighting without calling update().
 
layer:               The layer on which to run the ray-casting simulation. The light will respond to obstacles on this layer but not others.
 
light:                 The light to be processed.

### processLightRay(layer, light, ray)

Casts a single ray from a light source in any direction. This function is called by the engine in the update() function and does not need user intervention unless the user wishes to process the lighting without calling update().
 
layer:               The layer on which to run the ray-casting simulation. The light will respond to obstacles on this layer but not others.
 
light:                 The light to be processed.
 
ray:                  The light ray as defined by an angle. The function will cast a ray in the direction specified by the ray parameter.

 
### redrawObject(name)

Destroys and redraws the display object counterpart of the Tiled Object with the matching name, if the Tiled Object has physics properties or display properties, or both.
Applies changes made to the Tiled Object’s properties.
 
name: (string) The name of the object, set in Tiled.

### refresh()

Redraws all tiles in the active culling region. Useful for updating the display to reflect changes made with mte.setLayerProperties and other methods. This is a relatively expensive task which should not be called often.
 
 
Example:         mte.setLayerProperties(layer, myNewProperties)
                        mte.refresh()

### removeCameraConstraints(layer)

Removes the camera constraints from the specified layer. If layer is nil, removes constraints from all layers.
 
layer:               (number) A layer in the tilemap.

### removeObject(name, layer)

Removes a Tiled Object from an Object Layer in the tile map.
 
name:              (string) The name of the object. This is usually the name assigned to the object in Tiled.
 
layer:               (number) An Object Layer in the tile map.
 
 
Example:         local level = 1
                        local layer = mte.getObjectLayer(level)
                        mte.removeObject(“goto1”, layer)

### removeSprite(sprite, destroyObject)

Removes a sprite such as a player character or an enemy. It is recommended that removeSprite() be used to remove any sprite added to MTE’s display groups.
 
sprite:              (object) The displayObject reference.
destroyObject:        (boolean) If true, the displayObject is destroyed. If false, the displayObject is removed from MTE-managed groups and inserted into the Stage (see display.getCurrentStage() in the Corona SDK documentation).

 
### saveMap(loadedMap, filePath, dir)

Converts the specified map into json data and saves that data to a file at the specified filePath, in the specified directory. All arguments are optional.
 
loadedMap:      (string) The label of the map to be saved. Labels can be retrieved with getLoadedMaps(). If nil, defaults to the current map.
 
filePath:           (string) The path and filename of the file to be created. For example, “maps/myMap.json”. If nil, defaults to the loadedMap string, which is usually a filePath.
 
dir:                   (string) “Documents”, “Temporary”, or “Resource”. If nil, defaults to “Documents”.
 
Example:
 
mte.saveMap(“maps/map3.json”, “maps/savedMap3.json”, “Documents”)

### screenToLevelPos(xArg, yArg, layer)

Converts the supplied screen position coordinates into level position coordinates.
 
 
Example:         local layer = 1
                        local screenPosX, screenPosY = 4, 8
                        local levelPosX, levelPosY = screenToLevelPos(screenPosX, screenPosY, layer)
                        print(levelPosX, levelPosY)

### screenToLevelPosX(xArg, layer)

Converts the supplied X coordinate of a screen position into the X coordinate of a level position.
 
 
Example:         local layer = 1
                        local screenPosX, screenPosY = 4, 8
                        local levelPosX = screenToLevelPosX(screenPosX, layer)
                        print(levelPosX)

### screenToLevelPosY(yArg, layer)

Converts the supplied Y coordinate of a screen position into the Y coordinate of a level position.
 
 
Example:         local layer = 1
                        local screenPosX, screenPosY = 4, 8
                        local levelPosY = screenToLevelPosY(screenPosY, layer)
                        print(levelPosY)

### screenToLoc(xArg, yArg, layer)

Converts the supplied screen position coordinates into map location coordinates.
 
 
Example:         local layer = 1
                        local screenPosX, screenPosY = 4, 8
                        local locX, locY = screenToLoc(screenPosX, screenPosY, layer)
                        print(locX, locY)

### screenToLocX(xArg, layer)

Converts the supplied X coordinate of a screen position into the X coordinate of a map location.
 
 
Example:         local layer = 1
                        local screenPosX, screenPosY = 4, 8
                        local locX = screenToLocX(screenPosX, layer)
                        print(locX)

### screenToLocY(yArg, layer)

Converts the supplied Y coordinate of a screen position into the Y coordinate of a map location.
 
 
Example:         local layer = 1
                        local screenPosX, screenPosY = 4, 8
                        local locY = screenToLocY(screenPosY, layer)
                        print(locY)

### sendSpriteTo(parameters)

Sends a sprite to a new location or level position on the map.
 
parameters:    (table)
 
Format for parameters
 
sprite:              A sprite object.
 
levelPosX:       The X coordinate of the sprite’s destination position.
 
levelPosY:       The Y coordinate of the sprite’s destination position.
 
locX:                (optional) The X coordinate of the sprite’s destination location.
 
locY:                (optional) The Y coordinate of the sprite’s destination location.
 
 
Example:         mte.sendSpriteTo({sprite = enemySprite, locX = 10, locY = 30})
 
Example2:       mte.sendSpriteTo({sprite = player, levelPosX = 1100, levelPosY = 920})

### setCamera(parameters)

Changes the position of the camera and the scale of the map display. This function is usually called just after a map loads to set the initial camera position. For moving the camera during gameplay see moveCamera() and moveCameraTo(). This function is optional- MTE will automatically display a map at locX = 1, locY = 1, scale = 1 on the first update() if setCamera isn’t called. This function cannot be called before loadMap().
 
parameters:    (table) Configuration information.
 
Format for parameters
 
levelPosX:       The X coordinate of the camera's desired position.
 
levelPosY:       The Y coordinate of the camera's desired position.
 
locX:                (optional) The X coordinate of the camera's desired location.
 
locY:                (optional) The Y coordinate of the camera's desired location.
 
sprite:             (reference, optional) Centers the initial camera view on the specified sprite. Call setCameraFocus(sprite) to have the camera continue to follow the sprite.
 
scale:              Sets the scale of the map tiles. If the map’s tiles are 32x32 in size and the scale is set to 2.25, the tiles will appear to be 72 pixels in content space. In fact it is the master group object which is changing in scale, not the tiles.
 
scaleX:            Sets the scale of map tiles on the X axis, stretching or shrinking them horizontally. In fact it is the master group object which is changing in scale, not the tiles.
 
scaleY:                        Sets the scale of map tiles on the Y axis, stretching or shrinking them vertically. In fact it is the master group object which is changing in scale, not the tiles.
 
blockScale:     (optional) Sets the size of map tiles in pixels, scaling the camera view as needed. For example, if the map has 32x32 resolution tiles and the user sets blockScale to 72, the sprites will be scaled by 2.25.
 
blockScaleX:   (optional) Sets the width of map tiles in pixels.
 
blockScaleY:   (optional) Sets the height of map tiles in pixels.
 
cullingMargin: (table, optional) Alters the culling region boundaries. Positive values increase the size of the active culling region, the result being that the engine spawns more tiles offscreen than it normally would. The table is an array of four values. Index 1 is the left margin, index 2 is the top margin, index 3 is the right margin, index 4 is the bottom margin. For example, this table will increase the size of the culling region by 200 pixels on every side: {200, 200, 200, 200}
 
overDraw:       (number, optional) Increases the size of the tiles by the specified number of pixels, without altering the blockScale of the map, to help hide the edge artifacts of non-extruded tilesets. For example, an overDraw of 2 will increase the width and height of tiles by 2.
 
parentGroup:   (group) Inserts MTE’s masterGroup into the specified parentGroup. The parentGroup can be either a group object or a container object.
 
Example 1:      mte.setCamera({locX = 10, locY = 20, blockScale = 64})
 
Example 2:      local locX = 10
                        local locY = 20
                        local layer = 2
                        local tileObj = mte.getTileObj(locX, locY, layer)
                        mte.setCamera({object = tileObj, blockScale = 64})
 
Example 3:      mte.setCamera({levelPosX = 1200, levelPosY = 23789, blockScale = 64})
 
Example 4:      mte.setCamera({locX = 10, locY = 12, blockScaleX = 64, blockScaleY = 32}

### setCameraFocus(object, offsetX, offsetY)

Locks the camera to the specified sprite, for example the player character. The camera will follow the specified sprite’s movements.
 
sprite:             A sprite display object.
 
offsetX:            (optional) The initial horizontal offset of the camera from the sprite. For example, if the focus of the camera should be somewhat ahead of the sprite an offsetX of 100 might be used.
 
offsetY:            (optional) The initial vertical offset of the camera from the sprite.
 
 
Example:         mte.setCameraFocus(myPlayerSprite)


### setLayerProperties(layer, table)

Sets the properties of a layer to the values in table. Care must be taken to maintain the properties used by MTE such as Scale and Level, but otherwise the developer is free to add whatever properties he or she needs. The original property table for the layer will be erased in favor of the new table. Changes affecting the appearance of tiles will not manifest until the camera moves and new tiles are drawn, or the user calls refresh() to redraw all onscreen tiles. It is recommended that users retrieve a layer’s properties table, modify it, and reload it using setLayerProperties rather than replacing the layer properties table entirely. This helps to mitigate accidental changes to the table structure.
 
layer:               (number) A layer in the tile map.
 
table:               (table) The table of properties to be assigned to the layer.
 
           
Example:         local layer = 1
                        local layerProperties = mte.getLayerProperties(layer)
                        print("Scale = "..layerProperties.scale)
                        local newScale = 1.5
                        layerProperties.scale = newScale
                        mte.setLayerProperties(layer, layerProperties)
                        mte.refresh()

### setMapProperties(table)

Sets the properties of the map to the values in table. Care must be taken to maintain the properties used by MTE such as LightingStyle, but otherwise the developer may add whatever is necessary. The original property table for the map will be erased in favor of the new table. Changes affecting the appearance of tiles will not manifest until the camera moves and new tiles are drawn, or the user calls refresh() to redraw all onscreen tiles. It is recommended that users retrieve a map’s properties table, modify it, and reload it using setMapProperties rather than replacing the map properties table entirely. This helps to mitigate accidental changes to the table structure.
 
table: (table) The table of properties to be assigned to the map.
 
 
Example:         local mapProperties = mte.getMapProperties()
                        print("lightRedStart = "..mapProperties.lightRedStart)
                        local newRedStart = 150
                        mapProperties.lightRedStart = newRedStart
                        mte.setMapProperties(mapProperties)
                        mte.refresh()

### setObjectProperties(name, table, layer)

Sets the data of an object to the values in table. Note that this function replaces all data held by an object, not just the object’s properties subtable. It is essentially the same as addObject, but it replaces a current object rather than adding a new one.
 
name:              (string) The unique name assigned to an object in Tiled.
 
table:               (table) The data to be placed into the object.
 
layer:               (number) The object layer containing the object.
 
 
Example:         local level = 1
                        local layer = mte.getObjectLayer(level)
                        local table = {
                                    height = 32,
                                    width = 32,
                                    name = “goto1”,
                                    type = “goto”,
                                    x = 288,
                                    y = 192
                                    properties = {
                                                locX = 20,
                                                locY = 30
                                    }
                        }
                        mte.setObjectProperties({layer = layer, name = “goto1”}, table)

### setParentGroup(group)

Changes the parent group of MTE’s masterGroup. This is functionally the same as retrieving the master group with getMapObj() and inserting it into another group or container.
 
group:              (group) A group object or a container object.

### setPointLightSource(sprite)

Sets the current point light source for normal mapping. MTE will only process one point light source at a time. Normal mapping requires Corona Pro or Corona Enterprise.
 
sprite:              A sprite object. The sprite should be configured with point light data before setting it as the point light source. See the Sprite Properties documentation for more information.

### setScreenBounds(left, top, right, bottom)

The engine automatically detects the edges of the hardware screen at startup. This function allows the user to change those variables. Changing the screen bound variables is necessary when inserting MTE into a group or container whose origin is not the top left corner of the screen.
 
left:                  The left edge of the screen.
 
top:                  The top edge of the screen.
 
right:                The right edge of the screen.
 
bottom:            The bottom edge of the screen.

### setTileProperties(tile, table)

Sets the properties of a tile to the values in table. The original property table for the tile will be erased in favor of the new table. It is recommended that the user retrieve and amend the pre-existing property table rather than setting an entirely new one. This helps to prevent accidentally removing important properties or corrupting the format of the table.
 
tile:                   (number) The tile index.
 
table:               (table) The table of properties to be assigned to the tile.
 
           
Example:         local properties = mte.getTileProperties({tile = 1})
                        properties.myNewProperty = 123
                        mte.setTileProperties(1, properties)

### spritesFrozen

This boolean MTE flag sets whether the engine can update sprites added to the map. Freezing the sprites has the effect of pausing any movements started by moveSpriteTo or moveSprite.

### spriteSortResolution

MTE parameter specifying the resolution of the depth buffer created by enableSpriteSorting as a multiple of map height. If spriteSortResolution = 1, each Y location on the map will have one position in the depthBuffer. If spriteSortResolution = 10, as an example, each Y location on the map will have 10 positions in the depthBuffer. Increasing this value may negatively impact performance.
 
Example:         mte.spriteSortResolution = 4
 
### tileAnimsFrozen

This boolean MTE flag sets whether the engine can update the animations of animated tiles. Freezing the tile animations has the effect of pausing the animation of every animated tile.

### tintLayer(layer, color, time, transition)

Changes the color of the tiles in a layer over time using the easing function specified. If transition is nil it will default to easing.linear. If color and time are nil the function will check the current status of the layer, returning true if the layer is busy tinting or nil if the layer is finished/idle. Starting a new tint operation will seamlessly override the old tint operation. This function alters the colors of the tiles in a layer, not the layer object itself.
 
layer:               The map layer containing the tile.
 
color:               (array) An array of the desired R, G, B values. For example, {1,1,1} for white; {0, 1, 0} for green; {0, 0, 0} for black.
 
time:                The duration in milliseconds.
 
transition:        (easing) The desired easing function i.e. easing.inOutQuad or easing.linear.
 
 
Example:         --checks status of layer and turns layer red
                        layer = 2
                        if not mte.tintLayer(layer) then
                                    mte.tintLayer(layer, {1, 0.2, 0.2}, 1000, easing.inOutExpo)
                        end

### tintLevel(level, color, time, transition)

Changes the color of the tiles in each of a level’s layers over time using the easing function specified. If transition is nil it will default to easing.linear. If color and time are nil the function will check the current status of the level’s layers, returning true if any one layer is busy tinting or nil if all the layers are finished/idle. Starting a new tint operation will seamlessly override the old tint operation. This function alters the colors of the tiles in multiple layers, not the layer objects themselves. Depending on your map scale and the number of layers in your map, this function may be computationally expensive.
 
layer:               The map layer containing the tile.
 
color:               (array) An array of the desired R, G, B values. For example, {1,1,1} for white; {0, 1, 0} for green; {0, 0, 0} for black.
 
time:                The duration in milliseconds.
 
transition:        (easing) The desired easing function i.e. easing.inOutQuad or easing.linear.
 
 
Example:         --checks status of level and turns it red
                        level = 1
                        if not mte.tintLevel(level) then
                                    mte.tintLevel(level, {1, 0.2, 0.2}, 1000, easing.inExpo)
                        end

### tintMap(color, time, transition)

Changes the color of the tiles in each of the map’s layers over time using the easing function specified. If transition is nil it will default to easing.linear. If color and time are nil the function will check the current status of the map’s layers, returning true if any one layer is busy tinting or nil if all the layers are finished/idle. Starting a new tint operation will seamlessly override the old tint operation. This function alters the colors of the tiles in multiple layers, not the layer objects themselves, nor the master group object. Depending on your map scale and the number of layers in your map, this function may be computationally expensive.
 
color:               (array) An array of the desired R, G, B values. For example, {1,1,1} for white; {0, 1, 0} for green; {0, 0, 0} for black.
 
time:                The duration in milliseconds.
 
transition:        (easing) The desired easing function i.e. easing.inOutQuad or easing.linear.
 
 
Example:         --checks status of the map and turns it blue
                        if not mte.tintMap() then
                                    mte.tintMap({0, 0, 0.8}, 1000, easing.inOutQuad)
                        end

### tileObjects

This multidimensional array contains the displayObjects of all the active map tiles. The table follows the format tileObjects[layer][locX][locY]. For example, the displayObject for the tile at locX = 11, locY = 21, on layer 1 can be found at tileObjects[1][11][21].

### tintTile(locX, locY, layer, color, time, transition)

Changes the color of a tile over time using the easing function specified. If transition is nil it will default to easing.linear. If color and time are nil the function will check the current status of the tile, returning true if the tile is busy tinting or nil if the tile is finished/idle. Starting a new tint operation will seamlessly override the old tint operation.
 
locX:                The X location of the tile.
 
locY:                The Y location of the tile.
 
layer:               The map layer containing the tile.
 
color:               (array) An array of the desired R, G, B values. For example, {1,1,1} for white; {0, 1, 0} for green; {0, 0, 0} for black.
 
time:                The duration in milliseconds.
 
transition:        (easing) The desired easing function i.e. easing.inOutQuad or easing.linear.
 
 
Example:         --checks status of tile and turns tile dark blue
                        local locX, locY, layer = 50, 20, 3
                        if not mte.tintTile(locX, locY, layer) then
                                    mte.tintTile(locX, locY, layer, {0, 0, 150}, 1000, easing.inOutQuad)
                        end

### toggleLayerPhysicsActive(layer, command)

Changes the isBodyActive flag of every physics body in the specified layer.
 
layer:               (number) A layer in the tile map.
 
command:       (boolean) The desired value.

### toggleLayerPhysicsAwake(layer, command)

Changes the isAwake flag of every physics body in the specified layer.
 
layer:               (number) A layer in the tile map.
 
command:       (boolean) The desired value.

### toggleWorldWrapX(boolean)

Turns world wrapping on the X axis on or off if command is the boolean value true or false. If command is nil, blindly toggles between true and false depending on the current world wrap setting.

### toggleWorldWrapY(boolean)

See toggleWorldWrapX(command).
 
### update()

This function updates the engines managed movement, camera, and tile animation functions. This function should be called once every frame.

### updateTile(parameters)

Changes a map tile.
 
parameters:    (table) Describes the change to be made and where.
 
Format for parameters
 
locX:                The X coordinate of the tile’s location.
 
locY:                The Y coordinate of the tile’s location.
 
layer:               (number) A layer in the tile map.
 
tile:                   (optional) The new tile index. Use 0 to remove the tile from the map and display.
 
levelPosX:       (optional) The X coordinate of the tile’s position.
 
levelPosY:       (optional) The Y coordinate of the tile’s position.
           
           
Example:         mte.updateTile({locX = 21, locY = 19, tile = 7, layer = 1})

### unloadMap(mapPath)

Removes the specified map from memory. This function is intended for inactive maps stored in memory. The user should not use this function on the currently active map.
 
mapPath:        The path of the map to remove from memory.
 
### zoom(scale, time, transition)

Changes the scale of the map’s master group over time using the easing function specified. Transition defaults to easing.linear. If scale and time are nil, returns true if a zoom is in progress or nil otherwise. Zooming out will spawn more tiles to fill in the screen, zooming in will cull unneeded tiles.
 
scale:              The desired scale of the map.
 
time:                The duration in milliseconds.
 
transition:        (easing) The desired easing function i.e. easing.inOutQuad or easing.linear.
 
Example:         --checks whether the map is zooming and zooms the map
                        if not mte.zoom() then
                                    mte.zoom(0.5, 200, easing.outQuad)
                        end
