local model = system.getInfo("model")
local myData = require ("mydata")

if ( string.sub( model, 1, 4 ) == "iPad" ) then
	application = 
	{
		content = 
		{
			width = 768,
			height = 1024,
			--width = 360,
			--height = 480,
			scale = "zoomEven",
			xAlign = "left",
			yAligh = "center",
			fps = 30,
		}
	}
	myData.blockScale = 128
else
	application = 
	{
		content = 
		{
			width = 768,
			height = 1024,
			--width = 360,
			--height = 480,
			scale = "zoomEven",
			xAlign = "left",
			yAligh = "center",
			fps = 30,
		}
	}
	myData.blockScale = 160
end