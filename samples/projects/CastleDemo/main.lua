-------------------------
-- CastleDemo
-------------------------

-------------------------
-- Localisation
-------------------------

local mte = MTE
local Screen = Screen

-------------------------
-- Constants
-------------------------

local ImgDpad = "CastleDemo/Dpad.png"
local ImgSpritesheet = "CastleDemo/spritesheet.png"
local MapCastleDemo = "CastleDemo/map/CastleDemo.tmx"

local MoveTime = 300

local Atlas = {
    left = {-1, 0}, 
    right = {1, 0}, 
    up = {0, -1}, 
    down = {0, 1}
}

local Scale = 1

-------------------------
-- Variables
-------------------------

local background, player, Dpad, movement

-------------------------
-- Functions
-------------------------

local _updateLevel = function( layers, value )    
    mte.changeSpriteLayer( player, mte.getSpriteLayer( tonumber(value) ) )
    local zoomScale = ( Scale / layers[ player.layer ].properties.scale ) + 0.5
    mte.zoom( zoomScale, MoveTime, easing.inOutQuad )  
end

-------------------------

local _updateLevelVisibility = function( layers, value, alpha )
    local alpha = alpha or 1
    for i=1, #layers do
        local level = layers[i].properties.level
        if ( ( value == "above" and level > player.level ) or
            ( value == "below" and level < player.level ) or 
            ( level == tonumber(value) ) ) then
            mte.fadeLayer( i, alpha, MoveTime )
        end
    end
end

-------------------------

local _updateLayerVisibility = function( layers, value, alpha )
    local alpha = alpha or 1
    for i=1, #layers do
        if ( layers[i].name == value ) then
            mte.fadeLayer( i, alpha, MoveTime*0.5 )
        end
    end
end

-------------------------

local _doMoveToLocX = function( layers, value )
    if ( value == "random" ) then
        return player.locX + math.random(1, 3) - 2
    end
    return tonumber(value)
end

-------------------------

local _doMoveToLocY = function( layers, value )
    if ( value == "random" ) then
        return player.locY + math.random(1, 3) - 2
    end
    return tonumber(value)
end

-------------------------

local _checkObjects = function()
    
    local objects = mte.getObject( { 
        level = player.level, 
        locX = player.locX, 
        locY = player.locY
    } )
    
    if ( objects == nil ) then return end
    
    local layers = mte.getLayers()
    local locX = player.locX
    local locY = player.locY
    local time = 250
    local gotoX = player.locX
    local gotoY = player.locY
    
    local properties = objects[1].properties
    
    for key, value in pairs( properties ) do
        if ( key == "change level" ) then
            _updateLevel( layers, value )
        elseif ( key == "show level" ) then
            _updateLevelVisibility( layers, value, 1 )
        elseif ( key == "hide level" ) then
            _updateLevelVisibility( layers, value, 0 )
        elseif ( key == "show layer" ) then
            _updateLayerVisibility( layers, value, 1 )
        elseif ( key == "hide layer" ) then
            _updateLayerVisibility( layers, value, 0 )
        elseif ( key == "move to locX" ) then
            locX = _doMoveToLocX( layers, value )
        elseif ( key == "move to locY" ) then
            locY = _doMoveToLocY( layers, value )
        elseif ( key == "teleport to locX" ) then
            gotoX = tonumber(value)
        elseif ( key == "teleport to locY" ) then
            gotoY = tonumber(value)
        end
    end
    
    if ( math.abs( locX - player.locX ) > 3 or math.abs( locY - player.locY ) > 3 ) then
        time = 500
    end
    
    if ( locX ~= player.locX or locY ~= player.locY ) then
        mte.moveSpriteTo( { sprite = player, 
            locX = locX, locY = locY, 
            time = time, transition = easing.inOutQuad
        } )
    end
    
    if ( gotoX ~= player.locX or gotoY ~= player.locY ) then
        mte.sendSpriteTo( { sprite = player, 
            locX = gotoX, locY = gotoY 
        } )
        mte.setCamera( { locX = gotoX, locY = gotoY } )
    end
end

-------------------------

local _checkObstacles = function( level, locX, locY )
    
    local tileProperties = mte.getTileProperties( {
        level = level, locX = locX, locY = locY
    } )
    
    for i=1, #tileProperties do
        local properties = tileProperties[i].properties
        if ( properties ~= nil and properties.solid and i == 1 ) then
            return true
        end
    end
    
    return false
end

-------------------------

local _movePlayer = function()
    
    if ( player.isMoving ) then return end
    
    _checkObjects()
    
    if ( movement == nil ) then player:pause(); return end
    
    local xTile = player.locX + Atlas[ movement ][1]
    local yTile = player.locY + Atlas[ movement ][2]
    local isFacingObstacle = _checkObstacles( player.level, xTile, yTile )
    
    if ( isFacingObstacle ) then return end
    
    if ( player.sequence ~= movement ) then player:setSequence( movement ) end
    player:play()
    
    mte.moveSpriteTo( { sprite = player, 
        locX = xTile, locY = yTile, 
        time = MoveTime, transition = easing.linear
    } )
end

local move = function( event )
    if event.phase == "began" then
        display.getCurrentStage():setFocus(event.target, event.id)
        event.target.isFocus = true
    end
    if event.phase == "began" or event.phase == "moved" then
        local dirX = event.x - event.target.x
        local dirY = event.y - event.target.y	
        local angle = math.deg(math.atan(dirY/dirX))
        if dirX < 0 then
            angle = 90 + (90 - (angle * -1))
        end
        angle = angle + 90
        angle = math.round(angle / 90) * 90
        
        if angle == 360 then
            angle = 0
        end
        
        if ( angle == 0 ) then
            movement = "up"
        elseif ( angle == 90 ) then
            movement = "right"
        elseif ( angle == 180 ) then
            movement = "down"
        elseif ( angle == 270 ) then
            movement = "left"
        else
            movement = nil
        end

    elseif event.phase == "ended" or event.phase == "cancelled" then
        movement = nil
        display.getCurrentStage():setFocus( event.target, nil )
        event.target.isFocus = false
    end
    
    return true
end

-------------------------

local _update = function(event)      
    _movePlayer()    
    mte.debug()
    mte.update()
end

local _addUpdateListener = function()
    Runtime:addEventListener( "enterFrame", _update )
end

local _removeUpdateListener = function()
    Runtime:removeEventListener( "enterFrame", _update )
end

-------------------------

local _getBackground = function()    
    background = display.newRect(0, 0, Screen.FullWidth, Screen.FullHeight)
    background.id = "background"
    background.x, background.y = Screen.CenterX, Screen.CenterY
    background:setFillColor( 0.309, 0.264, 0.335 )    
    background:toBack()
end

-------------------------

local _getPlayer = function()
    
    local spriteSheet = graphics.newImageSheet( ImgSpritesheet, { 
        width = 32, height = 32, numFrames = 96
    } )
    local sequenceData = { 		
        { name = "up", sheet = spriteSheet, frames = { 85, 86 }, time = 400, loopCount = 0 },
        { name = "right", sheet = spriteSheet, frames = { 73, 74 }, time = 400, loopCount = 0 },
        { name = "down", sheet = spriteSheet, frames = { 49, 50 }, time = 400, loopCount = 0 },
        { name = "left", sheet = spriteSheet, frames = { 61, 62 }, time = 400, loopCount = 0}
    }
    player = display.newSprite( spriteSheet, sequenceData )
    player.id = "player"
    
end

-------------------------

local _loadMap = function()
    
    mte.toggleWorldWrapX( true )
    mte.toggleWorldWrapY( true )
    mte.loadMap( MapCastleDemo )
    
    mte.setCamera( { locX = 53, locY = 40, scale = Scale } )
    
    local map = mte.getMapObj()
    map.id = "map"
    
    local layers = mte.getLayers()
    for i = 1, #layers, 1 do
        if ( layers[i].properties.level > 2 ) then
            mte.fadeLayer( i, 0, 0 )
        end
    end
    
    local zoomScale = ( Scale / layers[1].properties.scale ) + 0.5
    mte.zoom( zoomScale, 0, easing.inOutQuad )
end

-------------------------

local _addPlayerToMap = function()
    
    local setup = {
        kind = "sprite", 
        layer =  mte.getSpriteLayer(1), 
        locX = 53, 
        locY = 40,
        levelWidth = 32,
        levelHeight = 32,
        name = "player"
    }
    
    mte.addSprite( player, setup )
    mte.setCameraFocus( player )
end

-------------------------

local _addControls = function()
    
    Dpad = display.newImageRect( ImgDpad, 120, 120)
    Dpad.x = Screen.Left + Dpad.width*0.5 + 10
    Dpad.y = Screen.Bottom - Dpad.height*0.5 - 10
    
    Dpad:addEventListener("touch", move)
end

-------------------------

_getBackground()
_getPlayer() 
_loadMap()
_addPlayerToMap()
_addControls()

_addUpdateListener()
