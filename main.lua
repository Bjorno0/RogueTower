-----------------------------------------------------------------------------------------
--
-- main.lua - Rogue Tower Defense Game
-- Solar2D Mobile Tower Defense Game
--
-----------------------------------------------------------------------------------------

-- Hide status bar for immersive gameplay
display.setStatusBar(display.HiddenStatusBar)

-- Load composer for scene management
local composer = require("composer")

-- Set composer recycling on unused scenes to optimize memory
composer.recycleOnSceneChange = true

-- Start with the launch scene
composer.gotoScene("launch", { effect = "fade", time = 500 })