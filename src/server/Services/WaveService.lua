local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local WaveConfig = require(ReplicatedStorage.Shared.Config.WaveConfig)

local WaveService = {}

function WaveService.GetWave(waveNumber)
	return WaveConfig.Waves[waveNumber]
end

function WaveService.SpawnWave(board, waveNumber)
	local wave = WaveService.GetWave(waveNumber)
	if wave == nil then
		return false, "Invalid wave"
	end

	board.wave = waveNumber

	local enemyDefinition = EnemyConfig.Enemies[wave.enemyType]
	for index = 1, wave.count do
		local health = math.floor(enemyDefinition.health * wave.healthMultiplier)
		local spawnDelay = (index - 1) * wave.spawnInterval
		table.insert(board.enemies, {
			id = `{waveNumber}:{index}`,
			enemyType = wave.enemyType,
			health = health,
			maxHealth = health,
			speed = enemyDefinition.speed * EnemyConfig.SpeedMultiplier,
			reward = enemyDefinition.reward,
			lifeDamage = enemyDefinition.lifeDamage,
			progress = -spawnDelay * enemyDefinition.speed * EnemyConfig.SpeedMultiplier * 4,
			alive = true,
		})
	end

	return true, board.enemies
end

function WaveService.ApplyWaveReward(board, waveNumber)
	local wave = WaveService.GetWave(waveNumber)
	if wave == nil then
		return 0
	end

	local interest = math.min(5, math.floor(board.gold / 10))
	board.interest = interest
	local reward = wave.reward + interest
	board.gold += reward
	board.score += waveNumber * 100 + board.life * 2
	return reward
end

function WaveService.IsComplete()
	return false
end

return WaveService
