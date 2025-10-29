-----------------------------------------------------------------------------------------
--
-- launch.lua - Launch Scene
-- RogueTower Defense Game Launch Page
--
-----------------------------------------------------------------------------------------

local composer = require("composer")
local scene = composer.newScene()

-- Forward declarations
local titleText, startButton, background

-- Get screen dimensions
local screenW, screenH = display.contentWidth, display.contentHeight
local centerX, centerY = display.contentCenterX, display.contentCenterY

-- Calculate safe margins (avoid edges that might be cut off)
local topSafeArea = display.safeScreenOriginY or 0
local leftSafeArea = display.safeScreenOriginX or 0
local rightSafeArea = screenW - leftSafeArea
local bottomSafeArea = screenH - topSafeArea

-- UI positioning constants
local UI_MARGIN = 20  -- Margin from screen edges
local TOP_UI_Y = topSafeArea + 40  -- Y position for top UI elements
local BOTTOM_UI_Y = screenH - topSafeArea - 40  -- Y position for bottom UI elements

-- Create the launch scene
function scene:create(event)
    local sceneGroup = self.view
    
    -- Create forest green gradient background
    background = display.newRect(sceneGroup, centerX, centerY, screenW, screenH)
    background:setFillColor({
        type = "gradient",
        color1 = { 0.2, 0.4, 0.3 },  -- Dark forest green
        color2 = { 0.1, 0.2, 0.1 },  -- Darker green
        direction = "down"
    })
    
    -- Add subtle texture overlay
    local overlay = display.newRect(sceneGroup, centerX, centerY, screenW, screenH)
    overlay:setFillColor(0.1, 0.1, 0.1, 0.1)
    overlay.alpha = 0.3
    
    -- Create main title "RogueTower" in upper middle
    titleText = display.newText(sceneGroup, "RogueTower", centerX, TOP_UI_Y, native.systemFontBold, 48)
    titleText:setFillColor(1, 1, 1)
    
    -- Add title glow effect
    local titleGlow = display.newText(sceneGroup, "RogueTower", centerX + 2, centerY - 148, native.systemFontBold, 48)
    titleGlow:setFillColor(0.3, 0.6, 0.3, 0.5)
    titleGlow:toBack()
    titleText:toFront()
    
    -- Create Start button
    local buttonWidth, buttonHeight = 200, 60
    local startButtonBg = display.newRoundedRect(sceneGroup, centerX, BOTTOM_UI_Y, buttonWidth, buttonHeight, 12)
    startButtonBg:setFillColor(0.2, 0.2, 0.2, 0.9)
    startButtonBg.strokeWidth = 3
    startButtonBg:setStrokeColor(1, 0.8, 0.2)
    
    local startButtonText = display.newText(sceneGroup, "START", centerX, BOTTOM_UI_Y, native.systemFontBold, 24)
    startButtonText:setFillColor(1, 0.8, 0.2)
    
    -- Group button elements for easier handling
    startButton = display.newGroup()
    sceneGroup:insert(startButton)
    startButton:insert(startButtonBg)
    startButton:insert(startButtonText)
    
    -- Button hover effect
    local function onButtonTouch(event)
        if event.phase == "began" then
            transition.to(startButton)
            print("Start button pressed")
        elseif event.phase == "ended" or event.phase == "cancelled" then
            -- Scale back up and go to menu
            transition.to(startButton, { 
                onComplete = function()
                    composer.gotoScene("menu", { effect = "slideLeft", time = 800 })
                end
            })
        end
        return true
    end
    
    startButton:addEventListener("touch", onButtonTouch)
end

-- Scene show event
function scene:show(event)
    local sceneGroup = self.view
    local phase = event.phase
    
    if phase == "will" then
        -- Scene is about to appear
    elseif phase == "did" then
        -- Scene is now on screen
        -- Add a subtle pulse animation to the title
        local function pulseTitle()
            transition.to(titleText, {
                time = 2000,
                alpha = 0.7,
                onComplete = function()
                    transition.to(titleText, {
                        time = 2000,
                        alpha = 1,
                        onComplete = pulseTitle
                    })
                    
                end
            })
        end
        pulseTitle()
        print("Screen dimensions: " .. screenW .. "x" .. screenH)
        print("Safe areas - Top: " .. topSafeArea .. ", Left: " .. leftSafeArea)
    end
end

-- Scene hide event
function scene:hide(event)
    local sceneGroup = self.view
    local phase = event.phase
    
    if phase == "will" then
        -- Scene is about to be hidden
    elseif phase == "did" then
        -- Scene is now hidden
    end
end

-- Scene destroy event
function scene:destroy(event)
    local sceneGroup = self.view
    -- Clean up any references here if needed
end

-- Add scene event listeners
scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene 