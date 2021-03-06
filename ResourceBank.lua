local class = require "class"
local ResourceBank = class:derive("ResourceBank")

local Image = require("Essentials/Image")
local Sound = require("Essentials/Sound")
local Music = require("Essentials/Music")
local Font = require("Essentials/Font")

function ResourceBank:new()
	self.images = {}
	self.sounds = {}
	self.music = {}
	-- This holds all raw data from files, excluding "config" and "runtime" files, which are critical and handled directly by the game.
	-- Widgets are excluded from doing so as well, because widgets are loaded only once and don't need to have their source data stored.
	self.legacySprites = {}
	self.legacyParticles = {}
	self.particles = {}
	self.fonts = {}
	
	
	-- Step load variables
	self.stepLoading = false
	self.stepLoadQueue = {}
	self.stepLoadTotalObjs = 0
	self.stepLoadTotalObjsFrac = 0
	self.stepLoadProcessedObjs = 0
	self.STEP_LOAD_FACTOR = 2 -- objects processed per frame; lower values can slow down the loading process significantly, while higher values can lag the progress bar
end

function ResourceBank:update(dt)
	for i, music in pairs(self.music) do
		music:update(dt)
	end
	
	if self.stepLoading then
		self.stepLoadTotalObjsFrac = self.stepLoadTotalObjsFrac + self.STEP_LOAD_FACTOR
		while self.stepLoadTotalObjsFrac >= 1 do
			self:stepLoadNext()
			self.stepLoadTotalObjsFrac = self.stepLoadTotalObjsFrac - 1
			
			-- exit if no more assets to load
			if not self.stepLoading then break end
		end
	end
end

function ResourceBank:loadImage(path, frames)
	-- we need sprites to convey images as objects as well, that shouldn't really be a problem because the number of frames is always constant for each given image
	print("[RB] Loading image: " .. path .. "...")
	self.images[path] = Image(parsePath(path), parseVec2(frames))
end

function ResourceBank:getImage(path)
	return self.images[path]
end

function ResourceBank:loadSound(path, loop)
	print("[RB] Loading sound: " .. path .. "...")
	self.sounds[path] = Sound(parsePath(path), loop)
end

function ResourceBank:getSound(path)
	return self.sounds[path]
end

function ResourceBank:loadMusic(path)
	print("[RB] Loading music: " .. path .. "...")
	self.music[path] = Music(parsePath(path))
end

function ResourceBank:getMusic(path)
	return self.music[path]
end

function ResourceBank:loadLegacySprite(path)
	print("[RB] Loading LEGACY sprite: " .. path .. "...")
	self.legacySprites[path] = loadJson(parsePath(path))
end

function ResourceBank:getLegacySprite(path)
	return self.legacySprites[path]
end

function ResourceBank:loadLegacyParticle(path)
	print("[RB] Loading LEGACY particle: " .. path .. "...")
	self.legacyParticles[path] = loadJson(parsePath(path))
end

function ResourceBank:getLegacyParticle(path)
	return self.legacyParticles[path]
end

function ResourceBank:loadParticle(path)
	print("[RB] Loading particle: " .. path .. "...")
	self.particles[path] = loadJson(parsePath(path))
end

function ResourceBank:getParticle(path)
	return self.particles[path]
end

function ResourceBank:loadFont(path)
	print("[RB] Loading font: " .. path .. "...")
	self.fonts[path] = Font(parsePath(path))
end

function ResourceBank:getFont(path)
	return self.fonts[path]
end



function ResourceBank:loadList(list)
	if list.images then
		for i, data in ipairs(list.images) do self:loadImage(data.path, data.frames) end
	end
	if list.sounds then
		for i, data in ipairs(list.sounds) do self:loadSound(data.path, data.loop) end
	end
	if list.music then
		for i, path in ipairs(list.music) do self:loadMusic(path) end
	end
	if list.legacySprites then
		for i, path in ipairs(list.legacySprites) do self:loadLegacySprite(path) end
	end
	if list.legacyParticles then
		for i, path in ipairs(list.legacyParticles) do self:loadLegacyParticle(path) end
	end
	if list.particles then
		for i, path in ipairs(list.particles) do self:loadParticle(path) end
	end
	if list.fonts then
		for i, path in ipairs(list.fonts) do self:loadFont(path) end
	end
end

function ResourceBank:stepLoadList(list)
	for objectType, objects in pairs(list) do
		-- set up a queue for a particular type if it doesn't exist there
		if not self.stepLoadQueue[objectType] then self.stepLoadQueue[objectType] = {} end
		for j, object in ipairs(objects) do
			-- load an object descriptor(?)
			table.insert(self.stepLoadQueue[objectType], object)
			self.stepLoadTotalObjs = self.stepLoadTotalObjs + 1
		end
	end
	self.stepLoading = true
end

function ResourceBank:stepLoadNext()
	local objectType = nil
	for k, v in pairs(self.stepLoadQueue) do objectType = k; break end -- loading a first object type that it comes
	-- get data
	local data = self.stepLoadQueue[objectType][1]
	print("[RB] Processing item " .. tostring(self.stepLoadProcessedObjs + 1) .. " from " .. tostring(self.stepLoadTotalObjs) .. "...")
	-- load
	if objectType == "images" then
		self:loadImage(data.path, data.frames)
	elseif objectType == "sounds" then
		self:loadSound(data.path, data.loop)
	elseif objectType == "music" then
		self:loadMusic(data)
	elseif objectType == "legacySprites" then
		self:loadLegacySprite(data)
	elseif objectType == "legacyParticles" then
		self:loadLegacyParticle(data)
	elseif objectType == "particles" then
		self:loadParticle(data)
	elseif objectType == "fonts" then
		self:loadFont(data)
	end
	-- remove from the list
	table.remove(self.stepLoadQueue[objectType], 1)
	-- if the type is depleted, remove it
	if #self.stepLoadQueue[objectType] == 0 then self.stepLoadQueue[objectType] = nil end
	self.stepLoadProcessedObjs = self.stepLoadProcessedObjs + 1
	-- end if all resources loaded
	if self.stepLoadProcessedObjs == self.stepLoadTotalObjs then self.stepLoading = false end
end

return ResourceBank