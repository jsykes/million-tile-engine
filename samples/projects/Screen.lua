-------------------------
-- Screen
-------------------------

local object = {}

-------------------------
-- Constants
-------------------------

local ScreenSize = {    
    ActiveWidth = 320,    
    ActiveHeight = 480,    
    FullWidth = 420,    
    FullHeight = 854    
}

-------------------------
-- Localisation
-------------------------

local system = system

-------------------------
-- Public
-------------------------

object.Left = display.screenOriginX
object.Right = display.contentWidth - display.screenOriginX
object.Top = display.screenOriginY
object.Bottom = display.contentHeight - display.screenOriginY

object.OffsetX = display.screenOriginX * -1
object.OffsetY = display.screenOriginY * -1

object.CenterX = display.contentCenterX
object.CenterY = display.contentCenterY

object.Width = object.Right + object.OffsetX
object.Height = object.Bottom + object.OffsetY

object.ContentWidth = display.contentWidth
object.ContentHeight = display.contentHeight

object.IsPortrait = ( 
system.orientation == "portrait" or 
system.orientation == "portraitUpsideDown" 
)

object.ActiveWidth = ScreenSize.ActiveWidth
object.ActiveHeight = ScreenSize.ActiveHeight
object.FullWidth = ScreenSize.FullWidth
object.FullHeight = ScreenSize.FullHeight

if ( not object.IsPortrait ) then
    object.ActiveWidth = ScreenSize.ActiveHeight
    object.ActiveHeight = ScreenSize.ActiveWidth
    object.FullWidth = ScreenSize.FullHeight
    object.FullHeight = ScreenSize.FullWidth 
end

-------------------------

return object
