local DataStoreService = game:GetService("DataStoreService")

local AchievementConfig = require(game:GetService("ReplicatedStorage").Shared.Config.AchievementConfig)

local PlayerDataService = {}

local store = nil
local storeUnavailable = false
local profiles = {}

local function getStore()
	if storeUnavailable then
		return nil
	end

	if store ~= nil then
		return store
	end

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("TacticalTowerDefenseProfileV1")
	end)

	if ok then
		store = result
		return store
	end

	storeUnavailable = true
	warn("DataStore unavailable; using session memory for local Studio testing.")
	return nil
end

local function defaultProfile()
	return {
		bestWave = 0,
		bestScore = 0,
		wins = 0,
		matches = 0,
		achievements = {},
		cosmetics = {
			equippedTowerSkin = "Default",
			unlockedTowerSkins = { Default = true },
		},
	}
end

function PlayerDataService.Load(player)
	local key = `player:{player.UserId}`
	local activeStore = getStore()
	local ok = false
	local data = nil

	if activeStore ~= nil then
		ok, data = pcall(function()
			return activeStore:GetAsync(key)
		end)
	end

	local profile = ok and data or nil
	if type(profile) ~= "table" then
		profile = defaultProfile()
	end

	profiles[player] = profile
	return profile
end

function PlayerDataService.Save(player)
	local profile = profiles[player]
	if profile == nil then
		return
	end

	local key = `player:{player.UserId}`
	local activeStore = getStore()
	if activeStore ~= nil then
		pcall(function()
			activeStore:SetAsync(key, profile)
		end)
	end
end

function PlayerDataService.RecordMatch(player, result)
	local profile = profiles[player] or PlayerDataService.Load(player)
	profile.matches += 1
	profile.bestWave = math.max(profile.bestWave, result.wave or 0)
	profile.bestScore = math.max(profile.bestScore, result.score or 0)
	if result.rank == 1 then
		profile.wins += 1
		PlayerDataService.UnlockAchievement(player, "LastBoardStanding")
	end
	if (result.wave or 0) >= 5 then
		PlayerDataService.UnlockAchievement(player, "FirstDefense")
	end
	return profile
end

function PlayerDataService.UnlockAchievement(player, achievementId)
	if AchievementConfig.Achievements[achievementId] == nil then
		return false
	end

	local profile = profiles[player] or PlayerDataService.Load(player)
	profile.achievements[achievementId] = true
	return true
end

function PlayerDataService.GetProfile(player)
	return profiles[player]
end

function PlayerDataService.Release(player)
	PlayerDataService.Save(player)
	profiles[player] = nil
end

return PlayerDataService
