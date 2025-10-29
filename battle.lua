-----------------------------------------------------------------------------------------
--
-- battle.lua - Battle Scene
-- RogueTower Defense Game Battle Scene
--
-----------------------------------------------------------------------------------------

local composer = require("composer")
local scene = composer.newScene()

-- Forward declarations
local background, healthCounter, waveCounter, coinCounter, enemyCounter
local enemyHealthDisplay, enemyDamageDisplay
local towerSprite, towerNameText, speedButton, upgradeButton
local debugButton, debugMenu, debugMenuVisible
local upgradeMenu, upgradeMenuVisible
local pathLine
local enemies = {}
local projectiles = {}
local gameTimer
local lastDamageTime = 0
local lastShootTime = 0
local towerRange = 150  -- Tower attack range in pixels
local gameSpeed = 1  -- Current game speed multiplier
local speedMode = "play"  -- play | pause | fast
local pendingNextWave = false  -- waiting between waves when in pause mode
local betweenWaveTimer = nil  -- timer handle for between-wave pause
local sceneActive = false  -- Track if scene is active

-- Forward declare the spawn function to avoid scoping issues
local spawnEnemyFunc

-- Get screen dimensions and safe areas
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
local BOTTOM_UI_Y = bottomSafeArea - 40  -- Y position for bottom UI elements

-- Wave progression constants (easily changeable for balance)
local WAVE_PROGRESSION = {
    baseEnemyCount = 20,           -- Starting number of enemies in wave 1
    enemyCountIncrease = 5,        -- Additional enemies per wave
    baseEnemyHealth = 5,           -- Starting enemy health in wave 1
    healthMultiplier = 1.10,       -- Health multiplier per wave (10% increase)
    baseEnemyDamage = 5,           -- Starting enemy damage in wave 1
    damageMultiplier = 1.10,       -- Damage multiplier per wave (10% increase)
    baseEnemySpeed = 30,           -- Starting enemy speed in wave 1
    speedMultiplier = 1.05,        -- Speed multiplier per wave (5% increase)
    baseSpawnInterval = 1000,      -- Milliseconds between enemy spawns
    baseCoinReward = 1,            -- Base coins per enemy
    bonusCoinWaves = 10,           -- Every N waves, enemies give +1 coin
    baseWaveReward = 25,           -- Base wave reward
    bonusWaveRewardWaves = 5,      -- Every N waves, wave reward increases by bonusWaveReward
    bonusWaveReward = 25,          -- Amount increased every N waves
}

-- Hard-coded waves 1-20. Each entry can define any of the fields used in currentWaveStats
-- Fields: enemyCount, enemyHealth, enemyDamage, enemySpeed, spawnInterval, coinReward, waveReward
local HARD_CODED_WAVES = {
    [1]  = { enemyCount = 50, enemyHealth = 5,  enemyDamage = 5,  enemySpeed = 50, spawnInterval = 1000, coinReward = 1, waveReward = 25 },
    [2]  = { enemyCount = 14, enemyHealth = 6,  enemyDamage = 3,  enemySpeed = 30, spawnInterval = 1000, coinReward = 1, waveReward = 25 },
    [3]  = { enemyCount = 16, enemyHealth = 7,  enemyDamage = 4,  enemySpeed = 30, spawnInterval = 1000, coinReward = 1, waveReward = 25 },
    [4]  = { enemyCount = 18, enemyHealth = 8,  enemyDamage = 4,  enemySpeed = 32, spawnInterval = 1000, coinReward = 1, waveReward = 25 },
    [5]  = { enemyCount = 20, enemyHealth = 9,  enemyDamage = 5,  enemySpeed = 32, spawnInterval = 1000, coinReward = 2, waveReward = 50 },
    [6]  = { enemyCount = 22, enemyHealth = 10, enemyDamage = 5,  enemySpeed = 33, spawnInterval = 1000, coinReward = 2, waveReward = 25 },
    [7]  = { enemyCount = 24, enemyHealth = 11, enemyDamage = 5,  enemySpeed = 34, spawnInterval = 1000, coinReward = 2, waveReward = 25 },
    [8]  = { enemyCount = 26, enemyHealth = 12, enemyDamage = 6,  enemySpeed = 35, spawnInterval = 950,  coinReward = 2, waveReward = 25 },
    [9]  = { enemyCount = 28, enemyHealth = 13, enemyDamage = 6,  enemySpeed = 35, spawnInterval = 950,  coinReward = 2, waveReward = 25 },
    [10] = { enemyCount = 30, enemyHealth = 14, enemyDamage = 7,  enemySpeed = 36, spawnInterval = 950,  coinReward = 3, waveReward = 75 },
    [11] = { enemyCount = 32, enemyHealth = 15, enemyDamage = 7,  enemySpeed = 37, spawnInterval = 900,  coinReward = 3, waveReward = 25 },
    [12] = { enemyCount = 34, enemyHealth = 16, enemyDamage = 8,  enemySpeed = 38, spawnInterval = 900,  coinReward = 3, waveReward = 25 },
    [13] = { enemyCount = 36, enemyHealth = 18, enemyDamage = 8,  enemySpeed = 39, spawnInterval = 900,  coinReward = 3, waveReward = 25 },
    [14] = { enemyCount = 38, enemyHealth = 20, enemyDamage = 9,  enemySpeed = 40, spawnInterval = 850,  coinReward = 3, waveReward = 25 },
    [15] = { enemyCount = 40, enemyHealth = 22, enemyDamage = 9,  enemySpeed = 40, spawnInterval = 850,  coinReward = 4, waveReward = 100 },
    [16] = { enemyCount = 42, enemyHealth = 24, enemyDamage = 10, enemySpeed = 41, spawnInterval = 850,  coinReward = 4, waveReward = 25 },
    [17] = { enemyCount = 44, enemyHealth = 26, enemyDamage = 11, enemySpeed = 42, spawnInterval = 800,  coinReward = 4, waveReward = 25 },
    [18] = { enemyCount = 46, enemyHealth = 28, enemyDamage = 11, enemySpeed = 43, spawnInterval = 800,  coinReward = 4, waveReward = 25 },
    [19] = { enemyCount = 48, enemyHealth = 30, enemyDamage = 12, enemySpeed = 44, spawnInterval = 800,  coinReward = 4, waveReward = 25 },
    [20] = { enemyCount = 50, enemyHealth = 32, enemyDamage = 12, enemySpeed = 45, spawnInterval = 800,  coinReward = 5, waveReward = 150 },
}

-- Game data
local gameData = {
    health = 100,  -- Player health
    coins = 0,  -- Player coins (will be loaded from menu data)
    currentWave = 1,  -- Current wave number
    isGameOver = false,
    
    -- Current wave stats (calculated dynamically)
    currentWaveStats = {
        enemyCount = 0,
        enemyHealth = 0,
        enemyDamage = 0,
        enemySpeed = 0,
        spawnInterval = 0,
        coinReward = 0,
        enemiesSpawned = 0,
        enemiesRemaining = 0
    },
    
    -- Tower information (using the same tower from menu)
    towers = {
        {
            name = "Crossbow Tower",
            key = "CrossbowTower",
            sprite = "sprites/crossbowTurret.png",
            unlocked = true,
            cost = 0,
            baseDamage = 5,
            baseFireRate = 1000,  -- milliseconds between shots
            baseProjectileHits = 2,  -- number of enemies projectile can hit before being destroyed
            -- Current stats (affected by upgrades)
            damage = 5,
            fireRate = 1000,
            projectileHits = 2,
            -- Upgrade tracking
            upgrades = {
                piercingBolts = false,  -- doubles piercing
                sharperBolts = false,   -- doubles damage
                rapidFire = false       -- 1.5x fire rate
            }
        }
    },
    
    currentTowerIndex = 1
}

-- Upgrades configuration (extensible for future towers)
-- Each tower defines an ordered list of upgrade keys and a map of upgrade definitions
local TOWERS_CONFIG = {
    CrossbowTower = {
        upgradeOrder = { "piercingBolts", "sharperBolts", "rapidFire" },
        upgrades = {
            piercingBolts = {
                name = "Piercing",
                cost = 50,
                colors = { fill = {0.3, 0.5, 0.3, 0.9}, stroke = {0.4, 0.7, 0.4} },
                apply = function(stats)
                    stats.projectileHits = stats.projectileHits * 2
                    return stats
                end
            },
            sharperBolts = {
                name = "Sharper",
                cost = 100,
                colors = { fill = {0.5, 0.3, 0.3, 0.9}, stroke = {0.7, 0.4, 0.4} },
                apply = function(stats)
                    stats.damage = stats.damage * 2
                    return stats
                end
            },
            rapidFire = {
                name = "Rapid Fire",
                cost = 100,
                colors = { fill = {0.3, 0.3, 0.5, 0.9}, stroke = {0.4, 0.4, 0.7} },
                apply = function(stats)
                    stats.fireRate = math.floor(stats.fireRate / 1.5)
                    return stats
                end
            },
        }
    }
}

-- Calculate wave stats based on wave number
local function calculateWaveStats(waveNumber)
    -- If within hard-coded waves, return those values
    local preset = HARD_CODED_WAVES[waveNumber]
    if preset then
        local stats = {
            enemyCount = preset.enemyCount,
            enemyHealth = preset.enemyHealth,
            enemyDamage = preset.enemyDamage,
            enemySpeed = preset.enemySpeed,
            spawnInterval = preset.spawnInterval,
            coinReward = preset.coinReward,
            waveReward = preset.waveReward,
            enemiesSpawned = 0,
            enemiesRemaining = preset.enemyCount,
        }
        return stats
    end

    -- Dynamic growth after wave 20
    local stats = {}
    
    -- Calculate enemy count (base + additional per wave)
    stats.enemyCount = WAVE_PROGRESSION.baseEnemyCount + ((waveNumber - 1) * WAVE_PROGRESSION.enemyCountIncrease)
    
    -- Calculate enemy health (base * multiplier^(wave-1))
    stats.enemyHealth = math.floor(WAVE_PROGRESSION.baseEnemyHealth * (WAVE_PROGRESSION.healthMultiplier ^ (waveNumber - 1)))
    
    -- Calculate enemy damage (base * multiplier^(wave-1))
    stats.enemyDamage = math.floor(WAVE_PROGRESSION.baseEnemyDamage * (WAVE_PROGRESSION.damageMultiplier ^ (waveNumber - 1)))
    
    -- Calculate enemy speed (base * multiplier^(wave-1))
    stats.enemySpeed = math.floor(WAVE_PROGRESSION.baseEnemySpeed * (WAVE_PROGRESSION.speedMultiplier ^ (waveNumber - 1)))
    
    -- Spawn interval stays the same
    stats.spawnInterval = WAVE_PROGRESSION.baseSpawnInterval
    
    -- Calculate coin reward (base (1) + bonus every 10 waves)
    stats.coinReward = WAVE_PROGRESSION.baseCoinReward + math.floor((waveNumber - 1) / WAVE_PROGRESSION.bonusCoinWaves)

    --Calculate wave reward (base (25) + 25 every 5 waves)
    stats.waveReward = WAVE_PROGRESSION.baseWaveReward + math.floor((waveNumber - 1) / WAVE_PROGRESSION.bonusWaveRewardWaves)
    
    -- Initialize tracking values
    stats.enemiesSpawned = 0
    stats.enemiesRemaining = stats.enemyCount
    
    return stats
end

-- Print current tower stats
local function printTowerStats()
    local currentTower = gameData.towers[gameData.currentTowerIndex]
    print("=== CROSSBOW TOWER STATS ===")
    print("Tower Name: " .. currentTower.name)
    print("Damage: " .. currentTower.damage .. " (Base: " .. currentTower.baseDamage .. ")")
    print("Fire Rate: " .. currentTower.fireRate .. "ms (Base: " .. currentTower.baseFireRate .. "ms)")
    print("Piercing: " .. currentTower.projectileHits .. " hits (Base: " .. currentTower.baseProjectileHits .. ")")
    print("Upgrades Owned:")
    print("  • Piercing Bolts: " .. tostring(currentTower.upgrades.piercingBolts))
    print("  • Sharper Bolts: " .. tostring(currentTower.upgrades.sharperBolts))  
    print("  • Rapid Fire: " .. tostring(currentTower.upgrades.rapidFire))
    print("===========================")
end

-- Initialize wave stats
local function initializeWave(waveNumber)
    gameData.currentWave = waveNumber
    gameData.currentWaveStats = calculateWaveStats(waveNumber)
    
    print("=== WAVE " .. waveNumber .. " INITIALIZATION ===")
    print("Enemies: " .. gameData.currentWaveStats.enemyCount)
    print("Enemy Health: " .. gameData.currentWaveStats.enemyHealth)
    print("Enemy Damage: " .. gameData.currentWaveStats.enemyDamage)
    print("Enemy Speed: " .. gameData.currentWaveStats.enemySpeed)
    print("Coin Reward: " .. gameData.currentWaveStats.coinReward)
    print("Enemies Spawned: " .. gameData.currentWaveStats.enemiesSpawned)
    print("Enemies Remaining: " .. gameData.currentWaveStats.enemiesRemaining)
    print("Game Over Status: " .. tostring(gameData.isGameOver))
    print("===================================")
    
    -- Print tower stats alongside wave info
    printTowerStats()
end

-- Helper function to update UI elements
local function updateHealthDisplay()
    if healthCounter and healthCounter.text then
        healthCounter.text.text = "Health: " .. gameData.health
    end
end

local function updateWaveDisplay()
    if waveCounter and waveCounter.text then
        waveCounter.text.text = "Wave: " .. gameData.currentWave
    end
end

local function updateCoinDisplay()
    if coinCounter and coinCounter.text then
        coinCounter.text.text = "Coins: " .. gameData.coins
    end
    -- Also update upgrade buttons' enabled/disabled state if menu exists
    if upgradeMenu and upgradeMenu.updateButtonsState then
        upgradeMenu.updateButtonsState()
    end
end

local function updateEnemyCounter()
    if enemyCounter and enemyCounter.text then
        enemyCounter.text.text = "Enemies: " .. gameData.currentWaveStats.enemiesRemaining
    end
end

local function updateEnemyStatsDisplay()
    if enemyHealthDisplay and enemyHealthDisplay.text then
        enemyHealthDisplay.text.text = "Enemy HP: " .. gameData.currentWaveStats.enemyHealth
    end
    if enemyDamageDisplay and enemyDamageDisplay.text then
        enemyDamageDisplay.text.text = "Enemy DMG: " .. gameData.currentWaveStats.enemyDamage
    end
end

-- Start the next wave immediately (used by between-wave controller and speed toggle)
local function startNextWave()
    if gameData.isGameOver then return end
    -- Cancel any pending between-wave timer
    if betweenWaveTimer then
        timer.cancel(betweenWaveTimer)
        betweenWaveTimer = nil
    end
    pendingNextWave = false
    print("=== PROGRESSING TO NEXT WAVE ===")
    initializeWave(gameData.currentWave + 1)
    updateWaveDisplay()
    updateEnemyCounter()
    updateEnemyStatsDisplay()
    local spawnDelay = math.floor(1000 / gameSpeed)
    print("Starting enemy spawn in " .. spawnDelay .. "ms for wave " .. gameData.currentWave)
    timer.performWithDelay(spawnDelay, function()
        if spawnEnemyFunc then
            spawnEnemyFunc()
        else
            print("ERROR: spawnEnemyFunc is nil!")
        end
    end)
end

local function updateTowerDisplay()
    local currentTower = gameData.towers[gameData.currentTowerIndex]
    
    -- Update tower name text
    if towerNameText then
        towerNameText.text = currentTower.name
        towerNameText:setFillColor(1, 1, 1)  -- White for unlocked
        -- Update glow text too
        if towerNameText.glowText then
            towerNameText.glowText.text = currentTower.name
        end
    end
    
    -- Update tower sprite
    if towerSprite then
        towerSprite:removeSelf()
        towerSprite = nil
    end
    
    local towerY = centerY - 100  -- Position tower in upper center area
    
    -- Create tower range indicator (transparent ring)
    local rangeCircle = display.newCircle(scene.view, centerX, towerY, towerRange)
    rangeCircle:setFillColor(0.3, 0.8, 0.3, 0.1)  -- Very transparent green
    rangeCircle.strokeWidth = 2
    rangeCircle:setStrokeColor(0.3, 0.8, 0.3, 0.3)  -- Semi-transparent green border
    
    -- Show actual tower sprite (32x32 pixels, scale up for visibility)
    towerSprite = display.newImageRect(scene.view, currentTower.sprite, 64, 64)  -- 2x scale for 32x32
    towerSprite.x = centerX
    towerSprite.y = towerY
    
    -- Store range circle reference with tower sprite for cleanup
    towerSprite.rangeCircle = rangeCircle
end

-- Enemy object creation
local function createEnemy()
    
    -- Safety checks
    if not scene or not scene.view then
        print("ERROR in createEnemy: scene or scene.view is nil!")
        return nil
    end
    
    if not centerX or not centerY or not screenH then
        print("ERROR in createEnemy: display dimensions not available")
        print("centerX:", centerX, "centerY:", centerY, "screenH:", screenH)
        return nil
    end
    
    if not gameData or not gameData.currentWaveStats then
        print("ERROR in createEnemy: gameData or currentWaveStats is nil!")
        return nil
    end

    local enemy = display.newRect(scene.view, centerX, screenH - 10, 20, 20)  -- Blue square, 20x20 pixels
    
    if not enemy then
        print("ERROR: display.newRect returned nil!")
        return nil
    end
    
    enemy:setFillColor(0.2, 0.2, 0.8)  -- Blue color
    enemy.strokeWidth = 1
    enemy:setStrokeColor(0.1, 0.1, 0.6)  -- Darker blue border
 
    -- Enemy properties (using current wave stats)
    enemy.health = gameData.currentWaveStats.enemyHealth
    enemy.maxHealth = gameData.currentWaveStats.enemyHealth
    enemy.damage = gameData.currentWaveStats.enemyDamage
    enemy.speed = gameData.currentWaveStats.enemySpeed
    enemy.targetY = centerY - 100 + 32  -- Tower position + half tower height
    enemy.isDealingDamage = false

    return enemy
end

-- Projectile object creation
local function createProjectile(targetEnemy)
    if not targetEnemy or not targetEnemy.x or not targetEnemy.y then return nil end
    
    local towerX, towerY = centerX, centerY - 100
    local projectile = display.newRect(scene.view, towerX, towerY, 8, 8)  -- Small brown square projectile
    projectile:setFillColor(0.6, 0.4, 0.2)  -- Brown color
    projectile.strokeWidth = 1
    projectile:setStrokeColor(0.4, 0.2, 0.1)  -- Darker brown border
    
    -- Projectile properties
    projectile.damage = gameData.towers[gameData.currentTowerIndex].damage
    projectile.hitsRemaining = gameData.towers[gameData.currentTowerIndex].projectileHits
    projectile.speed = 200  -- pixels per second
    projectile.targetX = targetEnemy.x
    projectile.targetY = targetEnemy.y
    
    -- Calculate direction
    local dx = targetEnemy.x - towerX
    local dy = targetEnemy.y - towerY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 0 then
        projectile.dirX = dx / distance
        projectile.dirY = dy / distance
    else
        projectile.dirX = 0
        projectile.dirY = 0
    end
    
    return projectile
end

-- Find target enemy within range
local function findTargetEnemy()
    local towerX, towerY = centerX, centerY - 100
    local closestEnemy = nil
    local closestDistance = towerRange + 1
    
    for _, enemy in ipairs(enemies) do
        if enemy and enemy.x and enemy.y and enemy.health > 0 then
            local dx = enemy.x - towerX
            local dy = enemy.y - towerY
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance <= towerRange and distance < closestDistance then
                closestDistance = distance
                closestEnemy = enemy
            end
        end
    end
    
    return closestEnemy
end

-- Tower shooting logic
local function towerShoot()
    if gameData.isGameOver then return end
    
    local currentTime = system.getTimer()
    local currentTower = gameData.towers[gameData.currentTowerIndex]
    
    -- Check if enough time has passed since last shot (affected by game speed)
    local adjustedFireRate = currentTower.fireRate / gameSpeed
    if currentTime - lastShootTime >= adjustedFireRate then
        local target = findTargetEnemy()
        
        if target then
            local projectile = createProjectile(target)
            if projectile then
                table.insert(projectiles, projectile)
                lastShootTime = currentTime
            end
        end
    end
end

-- Move projectiles and handle collisions
local function moveProjectiles()
    if gameData.isGameOver then return end
    
    for i = #projectiles, 1, -1 do
        local projectile = projectiles[i]
        if projectile and projectile.removeSelf then
            -- Move projectile towards its target (affected by game speed)
            local speedMod = gameSpeed * (1/30)  -- Assuming 30 FPS
            projectile.x = projectile.x + (projectile.dirX * projectile.speed * speedMod)
            projectile.y = projectile.y + (projectile.dirY * projectile.speed * speedMod)
            
            -- Check for collisions with enemies
            local hitEnemy = false
            for j, enemy in ipairs(enemies) do
                if enemy and enemy.x and enemy.y and enemy.health > 0 then
                    local dx = projectile.x - enemy.x
                    local dy = projectile.y - enemy.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    
                    if distance < 15 then  -- Collision threshold
                        -- Deal damage to enemy
                        enemy.health = enemy.health - projectile.damage
                        projectile.hitsRemaining = projectile.hitsRemaining - 1
                        hitEnemy = true
                        break
                    end
                end
            end
            
            -- Remove projectile if it ran out of hits or went off screen
            if projectile.hitsRemaining <= 0 or hitEnemy and projectile.hitsRemaining <= 0 or 
               projectile.x < 0 or projectile.x > screenW or projectile.y < 0 or projectile.y > screenH then
                projectile:removeSelf()
                table.remove(projectiles, i)
            end
        end
    end
end

-- Move enemies along the path
local function moveEnemies()
    if gameData.isGameOver then return end
    
    for i = #enemies, 1, -1 do
        local enemy = enemies[i]
        if enemy and enemy.removeSelf then
            -- Check if enemy reached the tower
            if enemy.y <= enemy.targetY then
                enemy.isDealingDamage = true
                -- Stop moving when reached tower
            else
                -- Move enemy up the path towards the tower (affected by game speed)
                local speedMod = gameSpeed * (1/30)  -- Assuming 30 FPS
                enemy.y = enemy.y - (enemy.speed * speedMod)
            end
            
            -- Remove dead enemies
            if enemy.health <= 0 then
                -- Add coins for destroying enemy (using current wave reward)
                gameData.coins = gameData.coins + gameData.currentWaveStats.coinReward
                updateCoinDisplay()
                
                -- Remove enemy from screen and array
                enemy:removeSelf()
                table.remove(enemies, i)
                
                -- Update enemies remaining
                gameData.currentWaveStats.enemiesRemaining = gameData.currentWaveStats.enemiesRemaining - 1
                updateEnemyCounter()
                
                -- Check if wave is complete
                if gameData.currentWaveStats.enemiesRemaining <= 0 and gameData.currentWaveStats.enemiesSpawned >= gameData.currentWaveStats.enemyCount then
                    print("Wave " .. gameData.currentWave .. " completed! Coins: " .. gameData.coins)
                    gameData.coins = gameData.coins + gameData.currentWaveStats.waveReward
                    updateCoinDisplay()
                    
                    -- Clean up remaining projectiles
                    for j = #projectiles, 1, -1 do
                        if projectiles[j] and projectiles[j].removeSelf then
                            projectiles[j]:removeSelf()
                        end
                        projectiles[j] = nil
                    end
                    
                    -- Handle between-wave progression based on speed mode
                    local BETWEEN_WAVE_PAUSE_MS = 2000
                    
                    local function progressToNextWave()
                        if gameData.isGameOver then return end
                        print("=== PROGRESSING TO NEXT WAVE ===")
                        initializeWave(gameData.currentWave + 1)
                        updateWaveDisplay()
                        updateEnemyCounter()
                        updateEnemyStatsDisplay()
                        
                        local spawnDelay = math.floor(1000 / gameSpeed)
                        print("Starting enemy spawn in " .. spawnDelay .. "ms for wave " .. gameData.currentWave)
                        timer.performWithDelay(spawnDelay, function()
                            if spawnEnemyFunc then
                                spawnEnemyFunc()
                            else
                                print("ERROR: spawnEnemyFunc is nil!")
                            end
                        end)
                    end
                    
                    -- Cancel any existing between-wave timer
                    if betweenWaveTimer then
                        timer.cancel(betweenWaveTimer)
                        betweenWaveTimer = nil
                    end
                    
                    if speedMode == "fast" then
                        -- Skip pauses between waves
                        progressToNextWave()
                    elseif speedMode == "play" then
                        -- Normal pause between waves
                        print("Progressing to next wave in " .. BETWEEN_WAVE_PAUSE_MS .. "ms")
                        betweenWaveTimer = timer.performWithDelay(BETWEEN_WAVE_PAUSE_MS, function()
                            betweenWaveTimer = nil
                            progressToNextWave()
                        end)
                    else -- pause
                        -- Indefinite pause until user toggles
                        pendingNextWave = true
                        print("Between-wave pause engaged. Awaiting user input.")
                    end
                end
            end
        end
    end
end

-- Deal damage to tower from enemies that have reached it
local function dealDamageToTower()
    if gameData.isGameOver then return end
    
    local currentTime = system.getTimer()
    
    -- Only deal damage once per second (affected by game speed)
    local adjustedDamageInterval = 1000 / gameSpeed
    if currentTime - lastDamageTime >= adjustedDamageInterval then
        local damageDealt = 0
        
        for _, enemy in ipairs(enemies) do
            if enemy.isDealingDamage and enemy.health > 0 then
                damageDealt = damageDealt + enemy.damage
            end
        end
        
        if damageDealt > 0 then
            gameData.health = gameData.health - damageDealt
            updateHealthDisplay()
            lastDamageTime = currentTime
            
            -- Check for game over
            if gameData.health <= 0 then
                gameOver()
            end
        end
    end
end

-- Spawn enemies for current wave
spawnEnemyFunc = function()
    
    -- Safety check: ensure we have valid game data
    if not gameData then
        print("ERROR: gameData is nil!")
        return
    end
    
    if not gameData.currentWaveStats then
        print("ERROR: gameData.currentWaveStats is nil!")
        return
    end
    
    -- Safety check: ensure scene is still valid and active
    if not scene or not scene.view then
        print("ERROR: scene or scene.view is nil!")
        return
    end
    
    if not sceneActive then
        print("ERROR: Scene is not active, cancelling spawn")
        return
    end
    
    if gameData.isGameOver then 
        print("Cannot spawn - game is over")
        return 
    end
    
    if gameData.currentWaveStats.enemiesSpawned < gameData.currentWaveStats.enemyCount then
        
        -- Wrap createEnemy call in pcall for error handling
        local success, enemy = pcall(createEnemy)
        if not success then
            print("ERROR in createEnemy: " .. tostring(enemy))
            return
        end
        
        if not enemy then
            print("ERROR: createEnemy returned nil!")
            return
        end

        table.insert(enemies, enemy)
        
        gameData.currentWaveStats.enemiesSpawned = gameData.currentWaveStats.enemiesSpawned + 1
        
        
        -- Schedule next enemy spawn
        if gameData.currentWaveStats.enemiesSpawned < gameData.currentWaveStats.enemyCount then
            local spawnDelay = math.floor(gameData.currentWaveStats.spawnInterval / gameSpeed)
            timer.performWithDelay(spawnDelay, function()
                if spawnEnemyFunc then
                    spawnEnemyFunc()
                else
                    print("ERROR: spawnEnemyFunc is nil in recursive call!")
                end
            end)
        else
            print("All enemies spawned for wave " .. gameData.currentWave)
        end
    else
        print("All enemies already spawned for this wave")
    end
end

-- Confirm function is assigned
print("spawnEnemyFunc assigned:", spawnEnemyFunc ~= nil)

-- Tower upgrade functions
local function calculateTowerStats()
    local currentTower = gameData.towers[gameData.currentTowerIndex]
    
    -- Reset to base values
    currentTower.damage = currentTower.baseDamage
    currentTower.fireRate = currentTower.baseFireRate
    currentTower.projectileHits = currentTower.baseProjectileHits
    
    -- Apply upgrades from config for this tower
    local towerConfig = TOWERS_CONFIG[currentTower.key]
    if towerConfig and towerConfig.upgrades then
        for upgradeKey, isOwned in pairs(currentTower.upgrades) do
            if isOwned then
                local def = towerConfig.upgrades[upgradeKey]
                if def and def.apply then
                    def.apply(currentTower)
                end
            end
        end
    end
end

local function purchaseUpgrade(upgradeType)
    local currentTower = gameData.towers[gameData.currentTowerIndex]
    local towerConfig = TOWERS_CONFIG[currentTower.key]
    local def = towerConfig and towerConfig.upgrades and towerConfig.upgrades[upgradeType]
    if not def then
        print("Unknown upgrade type:", tostring(upgradeType))
        return false
    end
    local upgradeCost = def.cost or 0
    
    -- Check if player has enough coins
    if gameData.coins < upgradeCost then
        print("Not enough coins! Need:", upgradeCost, "Have:", gameData.coins)
        return false
    end
    
    -- Check if upgrade is already purchased
    if currentTower.upgrades[upgradeType] then
        print("Upgrade already purchased:", upgradeType)
        return false
    end
    
    -- Purchase upgrade
    gameData.coins = gameData.coins - upgradeCost
    currentTower.upgrades[upgradeType] = true
    
    -- Recalculate tower stats
    calculateTowerStats()
    
    -- Update coin display
    updateCoinDisplay()
    
    -- Refresh upgrade buttons UI state and show placeholder for next upgrade
    if upgradeMenu and upgradeMenu.updateButtonsState then
        upgradeMenu.updateButtonsState()
    end
    
    print("Upgrade purchased: " .. upgradeType .. " for " .. upgradeCost .. " coins. Remaining: " .. gameData.coins)
    return true
end

-- Update the visual state of upgrade buttons based on coins and ownership
local function updateUpgradeButtonsState()
    if not upgradeMenu or not upgradeMenu.buttons then return end
    local coins = gameData.coins or 0
    local currentTower = gameData.towers[gameData.currentTowerIndex]
    local towerConfig = TOWERS_CONFIG[currentTower.key]
    for upgradeKey, entry in pairs(upgradeMenu.buttons) do
        local owned = currentTower.upgrades[upgradeKey]
        local def = towerConfig and towerConfig.upgrades and towerConfig.upgrades[upgradeKey]
        local cost = def and def.cost or 0
        local canAfford = coins >= cost
        local button = entry.button
        local text = entry.text
        if owned then
            -- Owned: gray and indicate next placeholder
            if button then
                button:setFillColor(0.35, 0.35, 0.35, 0.9)
                button:setStrokeColor(0.6, 0.6, 0.6)
            end
            if text then
                text.text = "Owned\nNext Soon"
                text:setFillColor(0.85, 0.85, 0.85)
            end
        else
            -- Not owned: enable color if affordable, otherwise gray
            if canAfford then
                if button then
                    button:setFillColor(unpack(entry.enabledFill))
                    button:setStrokeColor(unpack(entry.enabledStroke))
                end
                if text then
                    text.text = entry.label .. "\n" .. tostring(cost) .. "c"
                    text:setFillColor(1, 1, 1)
                end
            else
                if button then
                    button:setFillColor(0.4, 0.4, 0.4, 0.9)
                    button:setStrokeColor(0.65, 0.65, 0.65)
                end
                if text then
                    text.text = entry.label .. "\n" .. tostring(cost) .. "c"
                    text:setFillColor(0.9, 0.9, 0.9)
                end
            end
        end
    end
end

-- Expose the updater on the upgradeMenu once it exists

local function toggleUpgradeMenu()
    if not upgradeMenu then return end
    
    if upgradeMenuVisible then
        -- Hide menu
        upgradeMenu.isVisible = false
        upgradeMenuVisible = false
        print("Upgrade menu hidden")
    else
        -- Show menu
        upgradeMenu.isVisible = true
        upgradeMenuVisible = true
        if upgradeMenu.updateButtonsState then upgradeMenu.updateButtonsState() end
        print("Upgrade menu shown")
    end
end

-- Toggle the developer debug menu visibility
local function toggleDebugMenu()
    if not debugMenu then return end
    if debugMenuVisible then
        debugMenu.isVisible = false
        debugMenuVisible = false
        print("Debug menu hidden")
    else
        debugMenu.isVisible = true
        debugMenuVisible = true
        print("Debug menu shown")
    end
end

-- Game over function
local function gameOver()
    gameData.isGameOver = true
    
    -- Stop game timer
    if gameTimer then
        timer.cancel(gameTimer)
        gameTimer = nil
    end
    
    -- Clean up enemies
    for i = #enemies, 1, -1 do
        if enemies[i] and enemies[i].removeSelf then
            enemies[i]:removeSelf()
        end
        enemies[i] = nil
    end
    
    -- Clean up projectiles
    for i = #projectiles, 1, -1 do
        if projectiles[i] and projectiles[i].removeSelf then
            projectiles[i]:removeSelf()
        end
        projectiles[i] = nil
    end
    
    print("Game Over! Final coins: " .. gameData.coins .. " | Waves completed: " .. (gameData.currentWave - 1))
    
    -- Return to menu after a brief delay
    timer.performWithDelay(2000, function()
        composer.gotoScene("menu", { effect = "slideRight", time = 500 })
    end)
end

-- Create the battle scene
function scene:create(event)
    local sceneGroup = self.view
    sceneActive = false  -- Initialize scene as inactive
    upgradeMenuVisible = false  -- Initialize upgrade menu as hidden
    
    -- Create forest green gradient background (consistent with menu)
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
    
    -- Create pathway from bottom of screen to tower sprite
    local towerY = centerY - 100
    pathLine = display.newLine(sceneGroup, centerX, screenH, centerX, towerY + 32)  -- Line from bottom to tower
    pathLine:setStrokeColor(0.6, 0.4, 0.2)  -- Brown path color
    pathLine.strokeWidth = 20
    
    -- Add path edges for better visibility
    local pathEdge1 = display.newLine(sceneGroup, centerX - 10, screenH, centerX - 10, towerY + 32)
    pathEdge1:setStrokeColor(0.4, 0.2, 0.1)  -- Darker brown edge
    pathEdge1.strokeWidth = 2
    
    local pathEdge2 = display.newLine(sceneGroup, centerX + 10, screenH, centerX + 10, towerY + 32)
    pathEdge2:setStrokeColor(0.4, 0.2, 0.1)  -- Darker brown edge
    pathEdge2.strokeWidth = 2
    
    -- Developer Debug Button (blue square with 'D', to the right of the tower)
    local debugButtonX = centerX + 80
    local debugButtonY = towerY
    debugButton = display.newRoundedRect(sceneGroup, debugButtonX, debugButtonY, 28, 28, 4)
    debugButton:setFillColor(0.2, 0.4, 0.9, 0.95)
    debugButton.strokeWidth = 2
    debugButton:setStrokeColor(0.2, 0.3, 0.6)
    local debugButtonText = display.newText(sceneGroup, "D", debugButtonX, debugButtonY, native.systemFontBold, 16)
    debugButtonText:setFillColor(1, 1, 1)
    
    -- Debug menu (centered)
    debugMenuVisible = false
    debugMenu = display.newGroup()
    sceneGroup:insert(debugMenu)
    local dbgBg = display.newRoundedRect(debugMenu, centerX, centerY, 260, 210, 10)
    dbgBg:setFillColor(0.1, 0.1, 0.15, 0.95)
    dbgBg.strokeWidth = 3
    dbgBg:setStrokeColor(0.3, 0.5, 0.9)
    local dbgTitle = display.newText(debugMenu, "Developer Debug", centerX, centerY - 80, native.systemFontBold, 16)
    dbgTitle:setFillColor(1, 1, 1)
    
    -- Helper to create debug buttons
    local function createDbgBtn(label, x, y, onTap)
        local w, h, r = 100, 30, 6
        local btn = display.newRoundedRect(debugMenu, x, y, w, h, r)
        btn:setFillColor(0.18, 0.18, 0.22, 0.95)
        btn.strokeWidth = 2
        btn:setStrokeColor(0.5, 0.6, 0.9)
        local txt = display.newText(debugMenu, label, x, y, native.systemFontBold, 12)
        txt:setFillColor(0.9, 0.9, 0.95)
        btn:addEventListener("tap", function()
            if type(onTap) == "function" then onTap() end
            return true
        end)
        return btn, txt
    end
    
    -- Debug actions
    local function dbgAddCoins()
        gameData.coins = (gameData.coins or 0) + 10
        updateCoinDisplay()
    end
    local function dbgRemoveCoins()
        gameData.coins = math.max(0, (gameData.coins or 0) - 10)
        updateCoinDisplay()
    end
    local function dbgChangeWave(delta)
        local newWave = math.max(1, (gameData.currentWave or 1) + delta)
        -- Clear existing enemies
        for i = #enemies, 1, -1 do
            if enemies[i] and enemies[i].removeSelf then enemies[i]:removeSelf() end
            enemies[i] = nil
        end
        -- Clear existing projectiles
        for i = #projectiles, 1, -1 do
            if projectiles[i] and projectiles[i].removeSelf then projectiles[i]:removeSelf() end
            projectiles[i] = nil
        end
        initializeWave(newWave)
        updateWaveDisplay()
        updateEnemyCounter()
        updateEnemyStatsDisplay()
        -- Start spawning shortly
        timer.performWithDelay(200, function()
            if spawnEnemyFunc then spawnEnemyFunc() end
        end)
    end
    local function dbgEndRun()
        gameOver()
    end
    
    -- Layout buttons in a grid
    local row1Y = centerY - 40
    local row2Y = centerY + 0
    local row3Y = centerY + 40
    local colL = centerX - 70
    local colR = centerX + 70
    
    createDbgBtn("+10 Coins", colL, row1Y, dbgAddCoins)
    createDbgBtn("-10 Coins", colR, row1Y, dbgRemoveCoins)
    createDbgBtn("Wave +1", colL, row2Y, function() dbgChangeWave(1) end)
    createDbgBtn("Wave -1", colR, row2Y, function() dbgChangeWave(-1) end)
    createDbgBtn("End Run", centerX, row3Y, dbgEndRun)
    
    debugMenu.isVisible = false
    
    -- Toggle handlers for debug button and its label
    local function onDebugTouch(event)
        if event.phase == "ended" then
            toggleDebugMenu()
        end
        return true
    end
    debugButton:addEventListener("touch", onDebugTouch)
    debugButtonText:addEventListener("touch", onDebugTouch)
    
    -- Create coin counter at top left (uppermost)
    local coinX = leftSafeArea + UI_MARGIN + 70  -- Position safely from left edge
    local coinBg = display.newRoundedRect(sceneGroup, coinX, TOP_UI_Y - 30, 140, 35, 8)
    coinBg:setFillColor(0.2, 0.2, 0.2, 0.9)
    coinBg.strokeWidth = 2
    coinBg:setStrokeColor(1, 0.8, 0.2)  -- Gold border
    
    local coinText = display.newText(sceneGroup, "Coins: " .. gameData.coins, coinX, TOP_UI_Y - 30, native.systemFont, 16)
    coinText:setFillColor(1, 0.8, 0.2)  -- Gold text
    
    -- Group coin elements
    coinCounter = display.newGroup()
    sceneGroup:insert(coinCounter)
    coinCounter:insert(coinBg)
    coinCounter:insert(coinText)
    coinCounter.text = coinText  -- Store reference for updates
    
    -- Create enemy counter at top left (below coins)
    local enemyBg = display.newRoundedRect(sceneGroup, coinX, TOP_UI_Y + 10, 140, 35, 8)
    enemyBg:setFillColor(0.2, 0.2, 0.2, 0.9)
    enemyBg.strokeWidth = 2
    enemyBg:setStrokeColor(0.8, 0.4, 0.4)  -- Reddish border
    
    local enemyText = display.newText(sceneGroup, "Enemies: " .. gameData.currentWaveStats.enemiesRemaining, coinX, TOP_UI_Y + 10, native.systemFont, 16)
    enemyText:setFillColor(0.8, 0.4, 0.4)  -- Reddish text
    
    -- Group enemy counter elements
    enemyCounter = display.newGroup()
    sceneGroup:insert(enemyCounter)
    enemyCounter:insert(enemyBg)
    enemyCounter:insert(enemyText)
    enemyCounter.text = enemyText  -- Store reference for updates
    
    -- Create enemy health display at top right (upper)
    local enemyStatsX = rightSafeArea - UI_MARGIN - 70  -- Position safely from right edge
    local enemyHealthBg = display.newRoundedRect(sceneGroup, enemyStatsX, TOP_UI_Y - 15, 140, 30, 6)
    enemyHealthBg:setFillColor(0.2, 0.2, 0.2, 0.9)
    enemyHealthBg.strokeWidth = 2
    enemyHealthBg:setStrokeColor(0.8, 0.2, 0.2)  -- Red border
    
    local enemyHealthText = display.newText(sceneGroup, "Enemy HP: " .. gameData.currentWaveStats.enemyHealth, enemyStatsX, TOP_UI_Y - 15, native.systemFont, 14)
    enemyHealthText:setFillColor(0.8, 0.2, 0.2)  -- Red text
    
    -- Group enemy health elements
    enemyHealthDisplay = display.newGroup()
    sceneGroup:insert(enemyHealthDisplay)
    enemyHealthDisplay:insert(enemyHealthBg)
    enemyHealthDisplay:insert(enemyHealthText)
    enemyHealthDisplay.text = enemyHealthText  -- Store reference for updates
    
    -- Create enemy damage display at top right (lower)
    local enemyDamageBg = display.newRoundedRect(sceneGroup, enemyStatsX, TOP_UI_Y + 25, 140, 30, 6)
    enemyDamageBg:setFillColor(0.2, 0.2, 0.2, 0.9)
    enemyDamageBg.strokeWidth = 2
    enemyDamageBg:setStrokeColor(0.8, 0.5, 0.2)  -- Orange border
    
    local enemyDamageText = display.newText(sceneGroup, "Enemy DMG: " .. gameData.currentWaveStats.enemyDamage, enemyStatsX, TOP_UI_Y + 25, native.systemFont, 14)
    enemyDamageText:setFillColor(0.8, 0.5, 0.2)  -- Orange text
    
    -- Group enemy damage elements
    enemyDamageDisplay = display.newGroup()
    sceneGroup:insert(enemyDamageDisplay)
    enemyDamageDisplay:insert(enemyDamageBg)
    enemyDamageDisplay:insert(enemyDamageText)
    enemyDamageDisplay.text = enemyDamageText  -- Store reference for updates
    
    -- Create three-state speed toggle button at left side (above wave counter area)
    local speedY = BOTTOM_UI_Y - 80
    local speedX = leftSafeArea + UI_MARGIN + 70
    speedButton = display.newRoundedRect(sceneGroup, speedX, speedY, 120, 40, 8)
    speedButton.strokeWidth = 2
    
    local speedButtonText = display.newText(sceneGroup, "▶ PLAY", speedX, speedY, native.systemFontBold, 14)
    
    local function applySpeedMode()
        if speedMode == "play" then
            gameSpeed = 1
            speedButton:setFillColor(0.2, 0.55, 0.25, 0.9)
            speedButton:setStrokeColor(0.3, 0.8, 0.35)
            speedButtonText.text = "▶ PLAY"
            -- If there is a pending next wave (from pause), start it now
            if pendingNextWave then
                startNextWave()
            end
        elseif speedMode == "pause" then
            gameSpeed = 1
            speedButton:setFillColor(0.35, 0.35, 0.35, 0.9)
            speedButton:setStrokeColor(0.55, 0.55, 0.55)
            speedButtonText.text = "■ PAUSE"
            -- Do not auto-start next wave; wait until mode changes
        elseif speedMode == "fast" then
            gameSpeed = 2
            speedButton:setFillColor(0.55, 0.35, 0.15, 0.9)
            speedButton:setStrokeColor(0.85, 0.55, 0.25)
            speedButtonText.text = "⏩ FAST"
            -- If a pause timer exists, skip it and start immediately
            if pendingNextWave or betweenWaveTimer then
                startNextWave()
            end
        end
    end
    
    local function cycleSpeedMode()
        if speedMode == "play" then
            speedMode = "pause"
        elseif speedMode == "pause" then
            speedMode = "fast"
        else
            speedMode = "play"
        end
        applySpeedMode()
        print("Speed mode:", speedMode, "gameSpeed:", gameSpeed)
    end
    
    speedButton:addEventListener("tap", function()
        cycleSpeedMode()
        return true
    end)
    speedButtonText:addEventListener("tap", function()
        cycleSpeedMode()
        return true
    end)
    
    -- Initialize UI for current speed mode
    applySpeedMode()
    
    -- Create upgrade button at right side (same Y as speed button)
    local upgradeButtonX = rightSafeArea - UI_MARGIN - 70  -- Right side positioning
    upgradeButton = display.newRoundedRect(sceneGroup, upgradeButtonX, speedY, 120, 40, 8)
    upgradeButton:setFillColor(0.6, 0.4, 0.2, 0.8)  -- Brown background
    upgradeButton.strokeWidth = 2
    upgradeButton:setStrokeColor(0.8, 0.6, 0.4)  -- Brighter brown border
    
    -- Upgrade button text
    local upgradeButtonText = display.newText(sceneGroup, "UPGRADES", upgradeButtonX, speedY, native.systemFontBold, 14)
    upgradeButtonText:setFillColor(1, 1, 1)  -- White text
    
    -- Upgrade button touch handler
    local function onUpgradeTouch(event)
        if event.phase == "ended" then
            toggleUpgradeMenu()
        end
        return true
    end
    upgradeButton:addEventListener("touch", onUpgradeTouch)
    upgradeButtonText:addEventListener("touch", onUpgradeTouch)
    
    -- Create upgrade menu (initially hidden)
    -- Centered upgrade menu
    local menuX = centerX
    local menuY = centerY
    upgradeMenu = display.newGroup()
    sceneGroup:insert(upgradeMenu)
    
    -- Menu background
    local menuBg = display.newRoundedRect(upgradeMenu, menuX, menuY, 320, 140, 8)
    menuBg:setFillColor(0.2, 0.2, 0.2, 0.95)  -- Dark background
    menuBg.strokeWidth = 3
    menuBg:setStrokeColor(0.8, 0.6, 0.4)  -- Brown border
    
    -- Menu title
    local menuTitle = display.newText(upgradeMenu, "Crossbow Upgrades", menuX, menuY - 55, native.systemFontBold, 16)
    menuTitle:setFillColor(1, 1, 1)
    
    -- Upgrade buttons (3 equal sized buttons)
    local buttonWidth = 90
    local buttonSpacing = 100
    local startX = menuX - 100
    local buttonY = menuY + 10
    
    -- Store references to buttons for state updates
    upgradeMenu.buttons = {}
    
    -- Piercing Bolts upgrade
    local piercingButton = display.newRoundedRect(upgradeMenu, startX, buttonY, buttonWidth, 35, 5)
    piercingButton:setFillColor(0.3, 0.5, 0.3, 0.9)  -- Green
    piercingButton.strokeWidth = 2
    piercingButton:setStrokeColor(0.4, 0.7, 0.4)
    
    local piercingCost = (TOWERS_CONFIG[gameData.towers[gameData.currentTowerIndex].key].upgrades.piercingBolts.cost)
    local piercingText = display.newText(upgradeMenu, "Piercing\n" .. tostring(piercingCost) .. "c", startX, buttonY, native.systemFont, 10)
    piercingText:setFillColor(1, 1, 1)
    
    upgradeMenu.buttons.piercingBolts = {
        button = piercingButton,
        text = piercingText,
        label = "Piercing",
        enabledFill = TOWERS_CONFIG[gameData.towers[gameData.currentTowerIndex].key].upgrades.piercingBolts.colors.fill,
        enabledStroke = TOWERS_CONFIG[gameData.towers[gameData.currentTowerIndex].key].upgrades.piercingBolts.colors.stroke
    }
    
    local function onPiercingTouch(event)
        if event.phase == "ended" then
            if purchaseUpgrade("piercingBolts") then
                toggleUpgradeMenu()
            end
        end
        return true
    end
    piercingButton:addEventListener("touch", onPiercingTouch)
    piercingText:addEventListener("touch", onPiercingTouch)
    
    -- Sharper Bolts upgrade
    local sharperButton = display.newRoundedRect(upgradeMenu, startX + buttonSpacing, buttonY, buttonWidth, 35, 5)
    sharperButton:setFillColor(0.5, 0.3, 0.3, 0.9)  -- Red
    sharperButton.strokeWidth = 2
    sharperButton:setStrokeColor(0.7, 0.4, 0.4)
    
    local sharperCost = (TOWERS_CONFIG[gameData.towers[gameData.currentTowerIndex].key].upgrades.sharperBolts.cost)
    local sharperText = display.newText(upgradeMenu, "Sharper\n" .. tostring(sharperCost) .. "c", startX + buttonSpacing, buttonY, native.systemFont, 10)
    sharperText:setFillColor(1, 1, 1)
    
    upgradeMenu.buttons.sharperBolts = {
        button = sharperButton,
        text = sharperText,
        label = "Sharper",
        enabledFill = TOWERS_CONFIG[gameData.towers[gameData.currentTowerIndex].key].upgrades.sharperBolts.colors.fill,
        enabledStroke = TOWERS_CONFIG[gameData.towers[gameData.currentTowerIndex].key].upgrades.sharperBolts.colors.stroke
    }
    
    local function onSharperTouch(event)
        if event.phase == "ended" then
            if purchaseUpgrade("sharperBolts") then
                toggleUpgradeMenu()
            end
        end
        return true
    end
    sharperButton:addEventListener("touch", onSharperTouch)
    sharperText:addEventListener("touch", onSharperTouch)
    
    -- Rapid Fire upgrade
    local rapidButton = display.newRoundedRect(upgradeMenu, startX + (buttonSpacing * 2), buttonY, buttonWidth, 35, 5)
    rapidButton:setFillColor(0.3, 0.3, 0.5, 0.9)  -- Blue
    rapidButton.strokeWidth = 2
    rapidButton:setStrokeColor(0.4, 0.4, 0.7)
    
    local rapidCost = (TOWERS_CONFIG[gameData.towers[gameData.currentTowerIndex].key].upgrades.rapidFire.cost)
    local rapidText = display.newText(upgradeMenu, "Rapid Fire\n" .. tostring(rapidCost) .. "c", startX + (buttonSpacing * 2), buttonY, native.systemFont, 10)
    rapidText:setFillColor(1, 1, 1)
    
    upgradeMenu.buttons.rapidFire = {
        button = rapidButton,
        text = rapidText,
        label = "Rapid Fire",
        enabledFill = TOWERS_CONFIG[gameData.towers[gameData.currentTowerIndex].key].upgrades.rapidFire.colors.fill,
        enabledStroke = TOWERS_CONFIG[gameData.towers[gameData.currentTowerIndex].key].upgrades.rapidFire.colors.stroke
    }
    
    local function onRapidTouch(event)
        if event.phase == "ended" then
            if purchaseUpgrade("rapidFire") then
                toggleUpgradeMenu()
            end
        end
        return true
    end
    rapidButton:addEventListener("touch", onRapidTouch)
    rapidText:addEventListener("touch", onRapidTouch)
    
    -- Hook up state updater
    upgradeMenu.updateButtonsState = updateUpgradeButtonsState
    -- Initialize button visual state
    updateUpgradeButtonsState()
    
    -- Initially hide the upgrade menu
    upgradeMenu.isVisible = false
    upgradeMenuVisible = false
    
    -- Create health counter at bottom left
    local healthX = leftSafeArea + UI_MARGIN + 70  -- Position safely from left edge
    local healthBg = display.newRoundedRect(sceneGroup, healthX, BOTTOM_UI_Y, 140, 35, 8)
    healthBg:setFillColor(0.2, 0.2, 0.2, 0.9)
    healthBg.strokeWidth = 2
    healthBg:setStrokeColor(0.8, 0.2, 0.2)  -- Red border
    
    local healthText = display.newText(sceneGroup, "Health: " .. gameData.health, healthX, BOTTOM_UI_Y, native.systemFont, 16)
    healthText:setFillColor(0.8, 0.2, 0.2)  -- Red text
    
    -- Group health elements
    healthCounter = display.newGroup()
    sceneGroup:insert(healthCounter)
    healthCounter:insert(healthBg)
    healthCounter:insert(healthText)
    healthCounter.text = healthText  -- Store reference for updates
    
    -- Create wave counter at bottom right
    local waveX = rightSafeArea - UI_MARGIN - 70  -- Position safely from right edge
    local waveBg = display.newRoundedRect(sceneGroup, waveX, BOTTOM_UI_Y, 140, 35, 8)
    waveBg:setFillColor(0.2, 0.2, 0.2, 0.9)
    waveBg.strokeWidth = 2
    waveBg:setStrokeColor(0.2, 0.2, 0.8)  -- Blue border
    
    local waveText = display.newText(sceneGroup, "Wave: " .. gameData.currentWave, waveX, BOTTOM_UI_Y, native.systemFont, 16)
    waveText:setFillColor(0.2, 0.2, 0.8)  -- Blue text
    
    -- Group wave elements
    waveCounter = display.newGroup()
    sceneGroup:insert(waveCounter)
    waveCounter:insert(waveBg)
    waveCounter:insert(waveText)
    waveCounter.text = waveText  -- Store reference for updates
    
    -- Create tower name text (above sprite, positioned relative to center)
    local towerTextY = centerY - 150  -- Above the tower sprite
    towerNameText = display.newText(sceneGroup, "", centerX, towerTextY, native.systemFontBold, 20)
    towerNameText:setFillColor(1, 1, 1)
    
    -- Add tower name glow effect
    local towerNameGlow = display.newText(sceneGroup, "", centerX + 1, towerTextY + 1, native.systemFontBold, 20)
    towerNameGlow:setFillColor(0.3, 0.6, 0.3, 0.5)
    towerNameGlow:toBack()
    towerNameText:toFront()
    
    -- Store reference to update glow text
    towerNameText.glowText = towerNameGlow
    
    -- Initialize wave 1
    initializeWave(1)
    
    -- Initialize tower stats
    calculateTowerStats()
    
    -- Initial display updates
    updateTowerDisplay()
    updateHealthDisplay()
    updateWaveDisplay()
    updateCoinDisplay()
    updateEnemyCounter()
    updateEnemyStatsDisplay()
end

-- Scene show event
function scene:show(event)
    local sceneGroup = self.view
    local phase = event.phase
    
    if phase == "will" then
        -- Scene is about to appear
    elseif phase == "did" then
        -- Scene is now on screen
        sceneActive = true  -- Mark scene as active
        print("Battle Scene loaded")
        print("Player health: " .. gameData.health)
        print("Player coins: " .. gameData.coins)
        print("Current wave: " .. gameData.currentWave)
        print("Starting Wave " .. gameData.currentWave .. " with " .. gameData.currentWaveStats.enemyCount .. " enemies")
        
        -- Start the game timer for enemy movement, projectiles, tower shooting and damage dealing
        gameTimer = timer.performWithDelay(33, function()  -- ~30 FPS
            moveEnemies()
            moveProjectiles()
            towerShoot()
            dealDamageToTower()
        end, 0)  -- Repeat indefinitely
        
        -- Start spawning enemies after a brief delay
        local initialSpawnDelay = math.floor(1000 / gameSpeed)
        print("Starting initial enemy spawn in " .. initialSpawnDelay .. "ms")
        print("spawnEnemyFunc exists at initial spawn:", spawnEnemyFunc ~= nil)
        timer.performWithDelay(initialSpawnDelay, function()
            print("Initial spawn timer fired!")
            if spawnEnemyFunc then
                spawnEnemyFunc()
            else
                print("ERROR: spawnEnemyFunc is nil in initial call!")
            end
        end)
    end
end

-- Scene hide event
function scene:hide(event)
    local sceneGroup = self.view
    local phase = event.phase
    
    if phase == "will" then
        -- Scene is about to be hidden
        sceneActive = false  -- Mark scene as inactive
        gameData.isGameOver = true
        
        -- Stop game timer
        if gameTimer then
            timer.cancel(gameTimer)
            gameTimer = nil
        end
    elseif phase == "did" then
        -- Scene is now hidden
        -- Clean up enemies
        for i = #enemies, 1, -1 do
            if enemies[i] and enemies[i].removeSelf then
                enemies[i]:removeSelf()
            end
            enemies[i] = nil
        end
        
        -- Clean up projectiles
        for i = #projectiles, 1, -1 do
            if projectiles[i] and projectiles[i].removeSelf then
                projectiles[i]:removeSelf()
            end
            projectiles[i] = nil
        end
    end
end

-- Scene destroy event
function scene:destroy(event)
    local sceneGroup = self.view
    sceneActive = false  -- Mark scene as inactive
    
    -- Clean up any references here if needed
    if towerSprite then
        -- Clean up range circle
        if towerSprite.rangeCircle then
            towerSprite.rangeCircle:removeSelf()
        end
        towerSprite:removeSelf()
        towerSprite = nil
    end
    
    -- Clean up upgrade menu
    if upgradeMenu then
        upgradeMenu:removeSelf()
        upgradeMenu = nil
    end
    upgradeMenuVisible = false
    
    -- Clean up game timer
    if gameTimer then
        timer.cancel(gameTimer)
        gameTimer = nil
    end
    
    -- Clean up enemies
    for i = #enemies, 1, -1 do
        if enemies[i] and enemies[i].removeSelf then
            enemies[i]:removeSelf()
        end
        enemies[i] = nil
    end
    
    -- Clean up projectiles
    for i = #projectiles, 1, -1 do
        if projectiles[i] and projectiles[i].removeSelf then
            projectiles[i]:removeSelf()
        end
        projectiles[i] = nil
    end
end

-- Add scene event listeners
scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene