# Introduction
This is the official repository for the Million Tile Engine (MTE) originally 
developed by dyson122 https://forums.coronalabs.com/user/315031-dyson122/
and has since been open sourced under the MIT license.

This is a tile based engine for the CoronaSDK Game Development Framework.

## File Structure
```
mte/
 ├──dist/                      * compiled output of the source
 |──docs/                      * documents on usage of the engine
 |──legacy/                    * houses older code before this repository
 ├──samples/                   * an assortment of various code samples and projects used with this engine
 │
 ├──src/                       * our source files that will be compiled
 │   ├──folder/                * each folder is a 'standalone' module
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
./amalg.lua -o ./dist/mte.lua -s ./src/mte.lua

# Compiled project will be at dist/mte.lua
```

# Frequently asked questions
* questions
  * answers
