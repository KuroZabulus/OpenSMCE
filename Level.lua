local class = require "class"
local Level = class:derive("Level")

local Vec2 = require("Essentials/Vector2")
local Image = require("Essentials/Image")

local Map = require("Map")
local Shooter = require("Shooter")

function Level:new(data)
	self.name = data.name
	local data = loadJson(parsePath(data.path))
	
	self.map = Map("maps/" .. data.map)
	self.shooter = Shooter()
	
	self.colors = data.colors
	self.colorStreak = data.colorStreak
	self.powerups = data.powerups
	self.gemColors = data.gems
	if game.session.profile.data.session.ultimatelySatisfyingMode then
		self.spawnAmount = game.session.profile.data.session.level * 10
		self.target = self.spawnAmount
	else
		self.target = data.target
		self.spawnAmount = data.spawnAmount
	end
	self.spawnDistance = data.spawnDistance
	self.dangerDistance = data.dangerDistance
	self.speeds = data.speeds
	
	self:reset()
end

function Level:update(dt)
	self.map:update(dt)
	self.shooter:update(dt)
	
	self.danger = self:getDanger()
	
	-- Warning lights
	local maxDistance = self:getMaxDistance()
	if maxDistance >= self.dangerDistance and not self.lost then
		self.warningDelayMax = math.max((1 - ((maxDistance - self.dangerDistance) / (1 - self.dangerDistance))) * 3.5 + 0.5, 0.5)
	else
		self.warningDelayMax = nil
	end
	
	if self.warningDelayMax then
		self.warningDelay = self.warningDelay + dt
		if self.warningDelay >= self.warningDelayMax then
			for i, path in ipairs(self.map.paths) do
				if path:getMaxOffset() / path.length >= self.dangerDistance then
					game:spawnParticle("particles/warning.json", path:getPos(path.length))
				end
			end
			--game:playSound("warning", 1 + (4 - self.warningDelayMax) / 6)
			self.warningDelay = 0
		end
	else
		self.warningDelay = 0
	end
	
	-- Target widget
	-- TODO: HARDCODED - make it more flexible
	if game:getWidget({"main", "Frame", "Progress"}).widget.value == 1 then
		game:getWidget({"main", "Frame", "Progress_Complete"}):show()
	else
		game:getWidget({"main", "Frame", "Progress_Complete"}):hide()
		game:getWidget({"main", "Frame", "Progress_Complete"}):clean()
	end
	
	-- Level start
	-- TODO: HARDCODED - make it more flexible
	if not self.startMsg and not self.started and not game:getWidget({"main", "Banner_Intro"}).visible then
		self.startMsg = true
		game:getWidget({"main", "Banner_Intro"}):show()
		game:getWidget({"main", "Banner_LevelLose"}):clean()
	end
	
	if self.startMsg and not game:getWidget({"main", "Banner_Intro"}).visible and game:getWidget({"main", "Banner_Intro"}):getAnimationFinished() then
		self.startMsg = false
		self.started = true
		self.controlDelay = 2
		game:getMusic("level"):reset()
	end
	
	if self.controlDelay then
		self.controlDelay = self.controlDelay - dt
		if self.controlDelay <= 0 then
			self.controlDelay = nil
			self.shooter.active = true
			game:playSound("shooter_fill")
		end
	end
	
	-- Level finish
	if self:getFinish() and not self.finish and not self.finishDelay then
		self.finishDelay = 2
		self.shooter.active = false
	end
	
	if self.finishDelay then
		self.finishDelay = self.finishDelay - dt
		if self.finishDelay <= 0 then
			self.finishDelay = nil
			self.finish = true
			self.bonusDelay = 0
			self.shooter.color = 0
			self.shooter.nextColor = 0
		end
	end
	
	if self.bonusDelay and (self.bonusPathID == 1 or not self.map.paths[self.bonusPathID - 1].bonusScarab) then
		if self.map.paths[self.bonusPathID] then
			self.bonusDelay = self.bonusDelay - dt
			if self.bonusDelay <= 0 then
				self.map.paths[self.bonusPathID]:spawnBonusScarab()
				self.bonusDelay = 1.5
				self.bonusPathID = self.bonusPathID + 1
			end
		else
			self.wonDelay = 1.5
			self.bonusDelay = nil
		end
	end
	
	if self.wonDelay then
		self.wonDelay = self.wonDelay - dt
		if self.wonDelay <= 0 then
			self.wonDelay = nil
			self.won = true
			local highScore = game.session.profile:winLevel(self.score)
			game:getWidget({"main", "Banner_LevelComplete"}):show()
			if not highScore then game:getWidget({"main", "Banner_LevelComplete", "Frame", "Container", "VW_LevelScoreRecord"}):hide() end
		end
	end
	
	-- Level lose
	if self.lost and self:getEmpty() and not self.restart then
		game:getWidget({"main", "Banner_LevelLose"}):show()
		self.restart = true
	end
	
	if self.restart and not game:getWidget({"main", "Banner_LevelLose"}).visible and game:getWidget({"main", "Banner_LevelLose"}):getAnimationFinished() then
		if game.session.profile:loseLevel() then self:reset() else game.session:terminate() end
	end
	
	-- music fade in/out
	if not self.started or self.lost or self.won then
		game:getMusic("level"):setVolume(0)
		game:getMusic("danger"):setVolume(0)
	else
		if self.danger then
			game:getMusic("level"):setVolume(0)
			game:getMusic("danger"):setVolume(1)
		else
			game:getMusic("level"):setVolume(1)
			game:getMusic("danger"):setVolume(0)
		end
	end
end

function Level:newSphereColor()
	return self.colors[math.random(1, #self.colors)]
end

function Level:newPowerupData()
	local data = {type = "powerup", name = self.powerups[math.random(1, #self.powerups)]}
	if data.name == "colorbomb" then data.color = game.session:newSphereColor(true) end
	return data
end

function Level:newGemData()
	return {type = "gem", color = self.gemColors[math.random(1, #self.gemColors)]}
end

function Level:grantScore(score)
	self.score = self.score + score
	game.session.profile:grantScore(score)
end

function Level:grantCoin()
	self.coins = self.coins + 1
	game.session.profile:grantCoin()
end

function Level:grantGem()
	self.gems = self.gems + 1
end

function Level:destroySphere()
	if self.targetReached or self.lost then return end
	self.destroyedSpheres = self.destroyedSpheres + 1
	if self.destroyedSpheres == self.target then self.targetReached = true end
end

function Level:getEmpty()
	for i, path in ipairs(self.map.paths) do
		for j, sphereChain in ipairs(path.sphereChains) do
			return false
		end
	end
	return true
end

function Level:getDanger()
	for i, path in ipairs(self.map.paths) do
		for j, sphereChain in ipairs(path.sphereChains) do
			if sphereChain:getDanger() then return true end
		end
	end
	return false
end

function Level:getMaxDistance()
	local distance = 0
	for i, path in ipairs(self.map.paths) do
		distance = math.max(distance, path:getMaxOffset() / path.length)
	end
	return distance
end

function Level:getFinish()
	if not self.targetReached or self.lost then return false end
	for i, path in ipairs(self.map.paths) do
		if #path.sphereChains > 0 then return false end
	end
	for i, collectible in pairs(game.session.collectibles) do return false end
	return true
end

function Level:reset()
	self.score = 0
	self.coins = 0
	self.gems = 0
	self.combo = 0
	self.destroyedSpheres = 0
	
	self.spheresShot = 0
	self.sphereChainsSpawned = 0
	self.maxChain = 0
	self.maxCombo = 0
	
	self.targetReached = false
	self.danger = false
	self.warningDelay = 0
	self.warningDelayMax = nil
	
	self.startMsg = false
	self.started = false
	self.controlDelay = nil
	self.lost = false
	self.restart = false
	self.won = false
	self.wonDelay = nil
	self.finish = false
	self.finishDelay = nil
	self.bonusPathID = 1
	self.bonusDelay = nil
	
	self.shooter.speedShotTime = 0
end

function Level:lose()
	if self.lost then return end
	self.lost = true
	-- empty the shooter
	self.shooter.active = false
	self.shooter.color = 0
	self.shooter.nextColor = 0
	-- delete all shot balls
	game.session.shotSpheres = {}
	game:playSound("level_lose")
end



function Level:draw()
	self.map:draw()
	self.shooter:draw()
	
	-- local p = posOnScreen(Vec2(20, 500))
	-- love.graphics.setColor(1, 1, 1)
	-- love.graphics.print(tostring(self.warningDelay) .. "\n" .. tostring(self.warningDelayMax), p.x, p.y)
end

return Level