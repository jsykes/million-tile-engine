local PhysicsData = {}

-----------------------------------------------------------

PhysicsData.defaultDensity = 1.0
PhysicsData.defaultFriction = 0.1
PhysicsData.defaultBounce = 0
PhysicsData.defaultBodyType = "static"
PhysicsData.defaultShape = nil
PhysicsData.defaultRadius = nil
PhysicsData.defaultFilter = nil
PhysicsData.layer = {}

PhysicsData.managePhysicsStates = true

PhysicsData.enablePhysicsByLayer = 0
PhysicsData.enablePhysics = {}

-----------------------------------------------------------

PhysicsData.enableBox2DPhysics = function(arg)
    if ( arg == "by layer" ) then
        PhysicsData.enablePhysicsByLayer = 1
    elseif ( arg == "all" or arg == "Map.map" or not arg ) then
        PhysicsData.enablePhysicsByLayer = 2
    end
end

-----------------------------------------------------------

return PhysicsData
