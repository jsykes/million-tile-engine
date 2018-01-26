
-------------------------
-- Main
-------------------------
-- A simple application for exploring the MTE sample projects.

------------------------- 
-- Require
-------------------------

_G.MTE = require("mte").createMTE()
_G.Screen = require("Screen")

-------------------------
-- Setup
-------------------------

display.setDefault( "magTextureFilter", "nearest" )
display.setDefault( "minTextureFilter", "nearest" )
display.setStatusBar( display.HiddenStatusBar )    
system.activate( "multitouch" )

-------------------------
-- Sample Projects
------------------------- 
-- Comment / uncomment to sample each project.

-- require("AppendMap.main")
-- require("CastleDemo.main")
-- require("IsometricComposer.main")
require("Lighting.main")
-- require("LineOfSight.main")
-- require("PlatformerAngled.main")
-- require("PlatformerBasic.main")
-- require("PlatformerSonic.main")
-- require("RotateConstrainComposer.main")
-- require("Sledge.main")

-- Experimental! --
--require("Coronastein3D.main") -- See Notes, below.

-------------------------
-- Notes
------------------------- 
--[[

"Coronastein3D.main" 
Coronastein3D is experimental and uses a self-contained legacy version of MTE: 0v728

]]--
-------------------------
