## Tile Properties

Million Tile Engine appends several useful properties and methods to each tile object. Most of these properties are intended to be read but not directly modified by the user.

### locX 
The X coordinate of the tile’s location on the map.

### locY 
The Y coordinate of the tile’s location on the map. 

### index 
The frame index used to load the tile’s image from the tileset. Tilesets are imagesheets; the index is the index of the frame in the imagesheet. 
 
### tile 
The tileID. 
 
### color 
An array holding the current red, green, and blue values applied to a tile; color[1] is red, color[2] is green, and color[3] is blue. 
 
### layer 
The layer containing the tile. 
 
### level 
The level containing the layer containing the tile. 

### properties 
The table of properties assigned to a tile in Tiled. 

### noDraw 
Boolean setting whether the tile was drawn. If noDraw is true a tile does not have a corresponding display object, however the rest of it’s data and the properties above are loaded into the tile object table. 