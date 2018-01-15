
## Map Properties

### lightingStyle

Applies a lighting effect to the entire map. Currently Diminish is the only valid value. Diminish reduces the red, green, and blue brightness of tiles and sprites by the amount specified in lightRate for each layer. The result is that lower map levels look darker than higher map levels.
 
Lighting applied to a layer by lightingStyle can be overridden with the lightRed, lightGreen, and lightBlue layer properties.

### lightRate

Sets the brightness drop-off per layer when lightingStyle is used.

### lightRedStart, lightGreenStart, lightBlueStart

The starting values used by lightingStyle.

### lightLayerFalloff

(Lighting System) The decrease in red, green, and blue brightness when light from a source moves from one layer to an adjacent layer above or below it. Set as an array of three values, one each for red, green, and blue, in square brackets. For example, say we have a light source on layer 1 giving off max brightness white light [1, 1, 1] and our lightLayerFalloff is [0.1, 0.1, 0.1]; tiles on layer 2 will only receive a maximum of [0.9, 0.9, 0.9] from the light source, no matter how close to the source they are.

### lightLevelFalloff

(Lighting System) This works the same as lightLayerFalloff above, however the decrease is applied when light from a source moves from one level to an adjacent level above or below it. This is useful for when you want a dynamic light source to only light tiles on the level it is moving through, leaving levels above and below dark.

### defaultNormalMap

The path to the default normalMap imagesheet to apply to all tilesets. Normal maps are used in conjunction with point light sources to create appearance of raised textures in 3D space. Users should take caution when using this if tilesets are not all the same size.
 
Example:
 
Map Properties
 
| Name | Value |
|---|---|
| lightingStyle       | diminish |
| lightRate           | 0.04 |
| lightRedStart       | 1 |
| lightGreenStart     | 0.4 |
| lightBlueStart      | 0.9 |
| defaultNormalMapSet | tilesets/normalSet.png |
 
 
## Layer Properties

### level

Sets a layer’s map level. Map levels are abstract groupings of layers that can be manipulated together using some MTE functions. As an example, the first floor of a house might be map level 1, containing a ground layer, an object and sprite layer, and a roof layer. The second floor of a house would be level 2, and so on.

### scale

The scale factor of the layer. The scale factor makes the layer as a whole appear larger. Using successively higher scales can be used to create perspective effects.

### scaleX, scaleY

See “scale.” Allows independent X and Y scale to be set for each layer.

### lightRed, lightGreen, lightBlue

Adjusts the brightness of a layer, overriding the brightness set by the map property lightingStyle.

### spriteLayer

Designates a layer for rendering sprites. This can be either a Tile layer or an Object layer.

### width

Overrides the width of the layer set by Tiled.

### height

Overrides the height of the layer set by Tiled.

### wrap

Sets the world wrap of the layer. Layers ignore MTE’s toggleWorldWrap functions if the wrap property exists. Value must be “true” or “false”.

### wrapX, wrapY

See “wrap.” Allows independent X and Y wrap to be set for each layer.

### parallax

Sets the movement speed as a multiple of the speed of a layer with scale = 1. Parallax = 0.5 will move the layer half as many pixels as a layer whose scale is set to “1”, regardless of the parallaxing layer’s scale. Parallax layers are not meant for direct player interaction but rather as containers for foreground and background elements such as clouds overhead or backdrops far in the background of a level.

### parallaxX, parallaxY

See “parallax.” Allows independent X and Y parallax to be set for each layer.

### toggleParalaxCrop

Reduces the layer’s width and height so that the parallaxing layer fits within the world. This function in combination with fitByParallax is useful when parallax is less than 1 and world wrap is enabled.

### fitByParallax

Adjusts the parallax of a layer so that the edges of the layer will meet up properly at the edge of the map.

### physics

Optional boolean used to enable physic in MTE on a layer-by-layer basis.

### bodyType

Sets the default physics bodyType of a layer. Any tile in the layer and with physics enabled will assume this bodyType unless that tile has a bodyType property of its own.

### density

Sets the default physics density of a layer. Any tile in the layer and with physics enabled will assume this density unless that tile has a density property of its own.

### friction

Sets the default physics friction of a layer. Any tile in the layer and with physics enabled will assume this friction unless that tile has a friction property of its own.

### bounce

Sets the default physics bounce of a layer. Any tile in the layer and with physics enabled will assume this bounce unless that tile has a bounce property of its own.

### shape

Sets the default physics shape of tiles in a layer. Any tile in the layer and with physics enabled will assume this physics shape unless that tile has a shape property of its own.

### radius

Sets the default physics radius of tiles in a layer. Any tile in the layer and with physics enabled will assume this physics radius unless that tile has a radius property of its own.

### groupIndex

Sets the default physics groupIndex of a layer, used for collision filtering. Any tile in the layer and with physics enabled will assume this groupIndex unless that tile has a groupIndex property of its own.

### categoryBits

Sets the default physics categoryBits of a layer, used for collision filtering. Any tile in the layer and with physics enabled will assume these categoryBits unless that tile has a categoryBits property of its own.

### maskBits

Sets the default physics maskBits of a layer, used for collision filtering. Any tile in the layer and with physics enabled will assume these maskBits unless that tile has a maskBits property of its own.

### noDraw

If true, prevents MTE from rendering any of the tiles on the layer.

### cullObjects

If true, all Tiled objects on the layer will be culled when they move offscreen and respawned when they move onscreen, to conserve device memory and improve performance.

 
## Tileset Properties

### physicsSource

Specifies the PhysicsEditor output file from which to load physics bodies for the tile tileset’s tiles.. The source path is relative to the root directory of your project folder.

### physicsSourceScale

Sets the scaleFactor of PhysicsEditor data imported into MTE for all tiles in the tileset.

### noDraw

If true, prevents MTE from rendering any of the tiles from the tileset.

### normalMapSet

The path to the normalMap imagesheet for use with this tileset. The normalMap sheet should have the same physical dimensions as the tileset.

 
| Name | Value |
|---|---|
| physicsSource  | shapes.lua |
| noDraw         | false |
| normalMapSet   | tilesets/normalMap1.png |

 
## Tile Properties

### animDelay

Sets the length in milliseconds of a tile animation.

### animFrameSelect

Changes how the animFrames property is read, either as a table of “absolute” animation frames or “relative” values added to the master tile’s index to get the animation frames.

### animFrames

The list of animation frames used to animate a tile. Either absolute tile indexes of relative values to be added to the master tile’s index. This property must be entered as a list inside square brackets (see examples).

### animSync

This value is used to keep all like animated tiles synchronized with each other. Every tile with the same animSync will display the same frame at the same time. Other animated tiles may use the same animSync only if they have the same number of animFrames and the same animDelay.

### physics

Boolean enabling physics on this tile.

### bodyType

(optional) Sets the physics bodyType of the tile. “static” tiles are useful for platforms and terrain. “dynamic” tiles are automatically converted from tiles into sprites when they enter the active map region.

### density

(optional) Sets the physics density of the tile.

### friction

(optional) Sets the physics friction of the tile.

### bounce

(optional) Sets the physics bounce of the tile.

### shape

(optional) Sets the physics shape of the tile.

### radius

(optional) Sets the physics radius of the tile.

### groupIndex

(optional) Sets the physics groupIndex of the tile, used for collision filtering.

### categoryBits

(optional) Sets the physics categoryBits of the tile, used for collision filtering.

### maskBits

(optional) Sets the physics maskBits of the tile, used for collision filtering.

### physicsSource

(optional) Specifies the PhysicsEditor output file from which to load the physics body defined by the tile’s shapeID property, if the physicsSource property of the tileset has not been set. The source path is relative to the root directory of your project folder.

### physicsSourceScale

(optional) Sets the scaleFactor of PhysicsEditor data imported into MTE for the tile.

### shapeID

(optional) The shape to load from the specified physicsSource, usually this is the filename of the image file loaded into PhysicsEditor (without the extension). For example, if you load two images into PhysicsEditor named "square.png" and "triangle.png", the output file will contain two shapes named "square" and "triangle".

### lightSource

(Lighting System) Specifies the red, green, and blue brightness of a light source as an array of three values. For example, a source of [1, 1, 1] will produce white light of maximum brightness while [0, 0.2, 0] will produce a very dim green light.

### lightArc

(Lighting System) Light sources emit light in 360 degrees by default. This properties is an array of two values defining the start and stop angle of a limited arc. A value of [0, 90] will constrain a light source to only emit light directly right, directly down, and in the angles in between.

### lightRays

(Lighting System) Light sources emit light in 360 degrees by default. This property is an array of rays. A value of [0, 90] will cause a light source to emit exactly two rays of light, one aimed at 0 degrees (directly to the right), and another aimed at 90 degrees (directly down towards the bottom of the screen). The array may contain as many rays as desired.

### lightRange

(Lighting System) Specifies the range of the red, green, and blue light emitted from a source as an array of three values between square brackets. The unit of measure is 1 tile and defines a radius around a source. A light with a range of [10, 5, 1] will cast red light up to 10 tiles, green light up to 5 tiles, and blue light up to 1 tile from the source.

### lightFalloff

(Lighting System) The decrease in red, green, and blue brightness when light from a source moves 1 tile in any direction. The distance light travels is measured in a straight line along the light ray emitted by the source. This property is useful for creating lights which dim towards darkness along their edges. For example, a source of [1, 1, 1] with a range of [10, 10, 10] and a falloff of [0.1, 0.1, 0.1] will create a circle of light which is very bright at the center but gradually diminishes towards darkness at its maximum range.

### lightLayer

(Lighting System) Each light source can only react to opaque tiles on one layer of a map at a time. This property specifies the layer as an absolute value. A light with a layer of 1 will be impeded by opaque tiles on layer 1, but continue uninterrupted through opaque tiles on layer 2. The lightLayer can be different from the layer of the source object.

### lightLayerRelative

(Lighting System) Similar to lightLayer above, but defined in relation to the source of the light. If a light-emitting tile is on layer 2 and its lightLayerRelative property is -1, the light will react to tiles on layer 1.

### opacity

(Lighting System) Sets the red, green, and blue opacity of a tile. A tile with an opacity of [1, 1, 1] will block all light- the tile will be lit, but the light will not continue past the tile. A tile with an opacity of [0.4, 0, 0.4] will block some red and some blue light, allowing the remainder and all green light to pass through.

### noDraw

If true, prevents MTE from rendering the tile.

### path

A list of eight values in square brackets defining the path of the tile’s shape object when rendered in MTE. The table is formatted as [x1, y1, x2, y2, x3, y3, x4, y4] with each number representing one of the tile’s corners. x1, y1 are the coordinates of the top left corner, x2 and y2 are the bottom left corner, and so on counterclockwise around the tile. This functionality requires Corona Pro or Corona Enterprise.

### heightMap

A list of four values in square brackets defining the height of each of the tile’s four corners along the Z axis. Positive values will make a corner appear closer to the camera (coming out of the screen) while negative values will make a corner appear further from the camera (going into the screen). This functionality requires Corona Pro or Corona Enterprise.

### offscreenPhysics

If true, the dynamic tile will spawn a tiny area of the map immediately around itself while offscreen, allowing the physics simulation to continue no matter where the tile is on the map. This will allow physics objects to remain active anywhere on the map, without the objects falling through the world or moving through walls. This property is only relevant for dynamic physics objects.

Tile Properties

| Name | Value |
|---|---|
| animDelay       | 1000 |
| animFrameSelect | relative |
| animFrames      | [-2, -1, 0, 1, 2] |
| animSync        | 1 |
| path            | [-2, -2, -2, 2, 4, 0, 2, -4] |

Tile Properties

| Name | Value |
|---|---|
| animDelay       | 750 |
| animFrameSelect | absolute |
| animFrames      | [45, 46, 47, 48] |
| animSync        | 2 |
| heightMap       | [1, 0, 1, 0] |

Tile Properties

| Name | Value |
|---|---|
| physics       | true |
| bodyType      | dynamic |
| density       | 0.9 |
| friction      | 0.8 |
| bounce        | 0 |
| radius        | 16 |
| categoryBits  | 3 |
| maskBits      | 4 |

Tile Properties

| Name | Value |
|---|---|
| physicsSource | shapes.lua |
| shapeID       | triangle |


 
## Object Properties

### fillColor

(optional) Sets the fill color of Ellipse and Square/Box Tiled Objects. Polylines and polygons are not supported. The color values are stored between square brackets and may include the alpha channel. Example: [1, 1, 1, 0.5]

### lineColor

(optional) Sets the line color of Tiled Objects. The color values are stored between square brackets and may include the alpha channel. Example: [1, 0, 1, 0.2]

### lineWidth

(optional) Sets the line stroke width of Tiled Objects.

### levelWidth

(optional) Specifies the width of a gid/tile based Tiled Object when drawn.

### levelHeight

(optional) Specifies the height of a gid/tile based Tiled Object when drawn.

### physics

Boolean enabling physics on this object. Tiled Objects must have a gid (global tile ID) property in order to function as a physics body. Using Tiled’s Insert Tile object tool on an Object Layer will create an object which includes a gid. The MTE command loadPhysicsObjects() searches all map objects and converts any physics objects into sprites.

### bodyType

(optional) Sets the physics bodyType of the object. “static” pbjects are useful for platforms and terrain. Because they are objects instead of tiles, they may be placed with per-pixel precision anywhere on a map. “dynamic” objects will be subject to gravity and other forces.

### density

(optional) Sets the physics density of the object.

### friction

(optional) Sets the physics friction of the object.

### bounce

(optional) Sets the physics bounce of the object.

### shape

(optional) Sets the physics shape of the object. If shape is "auto" or nil (and physics is true), MTE will generate a matching physics shape at runtime.

### radius

(optional) Sets the physics radius of the object.

### groupIndex

(optional) Sets the physics groupIndex of the object, used for collision filtering.

### categoryBits

(optional) Sets the physics categoryBits of the object, used for collision filtering.

### maskBits

(optional) Sets the physics maskBits of the object, used for collision filtering.

### lightSource

(Lighting System) Specifies the red, green, and blue brightness of a light source as an array of three values. For example, a source of [1, 1, 1] will produce white light of maximum brightness while [0, 0.2, 0] will produce a very dim green light.

### lightArc

(Lighting System) Light sources emit light in 360 degrees by default. This properties is an array of two values defining the start and stop angle of a limited arc. A value of [0, 90] will constrain a light source to only emit light directly right, directly down, and in the angles in between.

### lightRays

(Lighting System) Light sources emit light in 360 degrees by default. This property is an array of rays. A value of [0, 90] will cause a light source to emit exactly two rays of light, one aimed at 0 degrees (directly to the right), and another aimed at 90 degrees (directly down towards the bottom of the screen). The array may contain as many rays as desired.

### lightRange

(Lighting System) Specifies the range of the red, green, and blue light emitted from a source as an array of three values between square brackets. The unit of measure is 1 tile and defines a radius around a source. A light with a range of [10, 5, 1] will cast red light up to 10 tiles, green light up to 5 tiles, and blue light up to 1 tile from the source.

### lightFalloff

(Lighting System) The decrease in red, green, and blue brightness when light from a source moves 1 tile in any direction. The distance light travels is measured in a straight line along the light ray emitted by the source. This property is useful for creating lights which dim towards darkness along their edges. For example, a source of [1, 1, 1] with a range of [10, 10, 10] and a falloff of [0.1, 0.1, 0.1] will create a circle of light which is very bright at the center but gradually diminishes towards darkness at its maximum range.

### lightLayer

(Lighting System) Each light source can only react to opaque tiles on one layer of a map at a time. This property specifies the layer as an absolute value. A light with a layer of 1 will be impeded by opaque tiles on layer 1, but continue uninterrupted through opaque tiles on layer 2. The lightLayer can be different from the layer of the source object.

### lightLayerRelative

(Lighting System) Similar to lightLayer above, but defined in relation to the source of the light. If a light-emitting tile is on layer 2 and its lightLayerRelative property is -1, the light will react to tiles on layer 1.

### offscreenPhysics

If true, the object will spawn a tiny area of the map immediately around itself while offscreen, allowing the physics simulation to continue no matter where the object is on the map. This will allow physics objects to remain active anywhere on the map, without the objects falling through the world or moving through walls. This property is only relevant for Tiled Objects with physics properties.

### cull

If true, the Tiled object will be culled when it moves offscreen and respawned when it moves back onscreen, to conserve device memory and improve performance.

| Name | Value |
|---|---|
| physics    | true |
| bodyType   | dynamic |
| density    | 0.5 |
| friction   | 0.1 |
| bounce     | 0.95 |
| shape      | auto |
| fillColor  | [1, 0, 1, 0.6] |
| lineWidth  | 4 |

