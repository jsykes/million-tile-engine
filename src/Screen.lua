local Screen = {}

-----------------------------------------------------------

Screen.screenLeft = nil
Screen.screenTop = nil
Screen.screenRight = nil
Screen.screenBottom = nil
Screen.screenCenterX = nil
Screen.screenCenterY = nil

-----------------------------------------------------------

Screen.setScreenBounds = function(left, top, right, bottom)
    Screen.screenLeft = left
    Screen.screenTop = top
    Screen.screenRight = right
    Screen.screenBottom = bottom
    Screen.screenCenterX = left + ((right - left) * 0.5 )
    Screen.screenCenterY = top + ((bottom - top) * 0.5 )
end

Screen.UpdateScreenBounds = function()
    if ( Screen.viewableContentWidth == display.viewableContentWidth ) then
        return
    end
    Screen.viewableContentWidth = display.viewableContentWidth
    if display.viewableContentWidth < display.viewableContentHeight then
        print("screen is vertical")                
        Screen.screenCenterX = display.contentWidth * 0.5
        Screen.screenCenterY = display.contentHeight * 0.5
        Screen.screenLeft = 0 + display.screenOriginX
        Screen.screenTop = 0 + display.screenOriginY
        Screen.screenRight = display.contentWidth - display.screenOriginX
        Screen.screenBottom = display.contentHeight - display.screenOriginY
        
    else
        print("screen is horizontal")
        Screen.screenLeft = display.screenOriginX
        Screen.screenTop = display.screenOriginY
        Screen.screenRight = display.screenOriginX + ( display.pixelHeight * display.contentScaleY )
        Screen.screenBottom = display.screenOriginY + ( display.pixelWidth * display.contentScaleX )
        Screen.screenCenterX = display.screenOriginX + ( display.pixelHeight * display.contentScaleY ) * 0.5
        Screen.screenCenterY = display.screenOriginY + ( display.pixelWidth * display.contentScaleX ) * 0.5
    end
    print(Screen.screenCenterX, Screen.screenCenterY)        
end

-----------------------------------------------------------

Screen.UpdateScreenBounds()

-----------------------------------------------------------

return Screen
