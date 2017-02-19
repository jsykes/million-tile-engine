local model = system.getInfo("platformName")
print(model)
if ( string.sub( model, 1, 3 ) ~= "And" ) then
	application = 
	{
		content = 
		{
			width = 768,
			height = 1024,
			--width = 320,
			--height = 480,
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
			width = 768,
			height = 1024,
			--width = 320,
			--height = 480,
			scale = "zoomEven",
			xAlign = "left",
			yAligh = "center",
			fps = 30,
		}
	}
end