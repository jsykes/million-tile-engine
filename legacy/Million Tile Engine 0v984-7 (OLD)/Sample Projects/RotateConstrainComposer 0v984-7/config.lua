local model = system.getInfo("model")

if ( string.sub( model, 1, 4 ) == "iPad" ) then
	application = 
	{
		content = 
		{
			--width = 768,
			--height = 1024,
			width = 360,
			height = 480,
			scale = "zoomEven",
			xAlign = "left",
			yAligh = "center",
			fps = 60,
		}
	}
else
	application = 
	{
		content = 
		{
			--width = 768,
			--height = 1024,
			width = 360,
			height = 480,
			scale = "zoomEven",
			xAlign = "left",
			yAligh = "center",
			fps = 30,
		}
	}
end