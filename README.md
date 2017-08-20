# Introduction
This is a tile based engine for the CoronaSDK Game Development Framework.

This is the official repository for the Million Tile Engine (MTE) originally 
developed by dyson122 https://forums.coronalabs.com/user/315031-dyson122/
and has since been open sourced under the MIT license.

See below for video demonstrations

## File Structure
```
mte/
 ├──dist/                      * compiled output of the source
 |──docs/                      * documents on usage of the engine
 |──legacy/                    * houses older code before this repository
 ├──samples/                   * an assortment of various code samples and projects used with this engine
 │
 ├──src/                       * our source files that will be compiled
 │   ├──folder/                * each folder is generally a 'standalone' module
 │
 │
 └──license.txt                * copy of this engines license
```

# Getting Started

## Installing
* Install lua (tested with v5.2.4) (brew install lua, lua for windows) for building the source.

## Building
```bash
# At the root of the project
./amalg.lua -o ./dist/mte.lua -s ./src/mte.lua -c

# Compiled project will be at dist/mte.lua
```

# Roadmap
  Current Goal: Refactor the single file library that was given as the original state and split it up across various files and components.

# Demos

### Sonic the Hedgehog - Finale:
High speed platforming action utilizing very large, detailed tiles! One of three platforming 
samples included with Million Tile Engine version 0.8

[![Sonic Sample](https://img.youtube.com/vi/sZ5I1zI5HmM/0.jpg)](https://www.youtube.com/watch?v=sZ5I1zI5HmM)

### Castle Demo:
A multilayered castle map using the Million Tile Engine's advanced perspective effect. 
Locking the camera to a sprite is as easy as calling mte.setCameraFocus(). 
Moving a sprite in relation to the map with easing, independent of screen pixel 
resolution or even app resolution, is also just a single line: mte.moveSpriteTo(). 
This demo is included in the Million Tile Engine download.

[![Castle Demo](https://img.youtube.com/vi/0ILi0haOYco/0.jpg)](https://www.youtube.com/watch?v=0ILi0haOYco)

### Tile Lighting:
This MTE sample project demonstrates the Tile Lighting system new in version 0.943. 
This sample is included in the MTE download along with the others.

[![Tile Lighting](https://img.youtube.com/vi/tFliqQ25VkI/0.jpg)](https://www.youtube.com/watch?v=tFliqQ25VkI)

### Physics Support:
A demonstration of newly enabled physics support for the ellipse, polygon, polyline, and box objects in Tiled, 
as well as the optional vector display of those objects. The physics forces have been amped up in this video for effect.

[![Physics Support](https://img.youtube.com/vi/9m044O8W-Xc/0.jpg)](https://www.youtube.com/watch?v=9m044O8W-Xc)

### Isometric Maps:
A quick run-through of one of MTE's newest sample projects: IsometricStoryboardTMX. The new project demonstrates 
the new Isometric map support, changing maps via Corona's storyboard API, and loading directly from Tiled TMX files.

[![Isometric Maps](https://img.youtube.com/vi/kXKHlhMDlfg/0.jpg)](https://www.youtube.com/watch?v=kXKHlhMDlfg)

### Performance Video:
Castle Demo runs at 60fps on the iPad2 and 30fps on the iPhone4 and the iPhone3GS. 
The Million Tile Engine can reach all segments of the market regardless of device performance. 

[![Performance Video](https://img.youtube.com/vi/whF-4FqN-8w/0.jpg)](https://www.youtube.com/watch?v=whF-4FqN-8w)

### 120,000 tiles… on an iPhone 3GS:
Tile culling is the magic behind a successful tile engine. This 120,000 tile map was only possible because of 
the Million Tile Engine's sophisticated culling system. Maps can be made much larger, too. The only limit to 
map size is the device's memory.

[![120,000 tiles… on an iPhone 3GS](https://img.youtube.com/vi/8Aw0v7z1_tM/0.jpg)](https://www.youtube.com/watch?v=8Aw0v7z1_tM)

### Multilayered map with traditional flat view:
Everything in this video is in a single map, including the underground portions. 
The Million Tile Engine stores map layers in display groups, allowing developers to hide and reveal entire layers as needed.

[![Multilayered map with traditional flat view](https://img.youtube.com/vi/Hv0EMzgr5vQ/0.jpg)](https://www.youtube.com/watch?v=Hv0EMzgr5vQ)

### Animated Tiles:
The Million Tile Engine doesn’t merely animate tiles, it synchronizes those animations.

[![Animated Tiles](https://img.youtube.com/vi/LoUtI1JnAh4/0.jpg)](https://www.youtube.com/watch?v=LoUtI1JnAh4)

### Advanced Perspective and Layer Lighting:
It's Corona SDK, yet it has a 3D effect. Make your game stand out!

[![Advanced Perspective and Layer Lighting](https://img.youtube.com/vi/ajkAaYqA5r8/0.jpg)](https://www.youtube.com/watch?v=ajkAaYqA5r8)

### Zooming, Fading, and Tinting:
MTE includes convenient functions for altering the alpha channel and color of tiles, layers, levels or the 
whole map simultaneously, and a convenient function for zooming in and out on the map.

[![Zooming, Fading, and Tinting](https://img.youtube.com/vi/cuPQHOP2Zz4/0.jpg)](https://www.youtube.com/watch?v=cuPQHOP2Zz4)