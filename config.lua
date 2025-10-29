--
-- For more information on config.lua see the Project Configuration Guide at:
-- https://docs.coronalabs.com/guide/basics/configSettings
--

application =
{
	content =
	{
		width = 320,
		height = 568, 
		scale = "letterboxInside",
		fps = 60,
		
		-- Enable anti-aliasing for better graphics
		antialias = true,
		
		-- Image suffixes for different screen densities
		imageSuffix =
		{
			    ["@2x"] = 2,
			    ["@3x"] = 3,
			    ["@4x"] = 4,
		},
	},
}
