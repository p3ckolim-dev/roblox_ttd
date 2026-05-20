local WaveConfig = {}

WaveConfig.Waves = {}
WaveConfig.RoundDurationSeconds = 45
WaveConfig.SpawnIntervalSeconds = 1

for wave = 1, 30 do
	local isBoss = wave % 5 == 0
	local enemyType = "Basic"
	if isBoss then
		enemyType = "Boss"
	elseif wave % 4 == 0 then
		enemyType = "Tank"
	elseif wave % 3 == 0 then
		enemyType = "Fast"
	end

	WaveConfig.Waves[wave] = {
		wave = wave,
		enemyType = enemyType,
		count = wave == 1 and 12 or isBoss and 1 or 14 + wave * 2,
		spawnInterval = WaveConfig.SpawnIntervalSeconds,
		healthMultiplier = 1 + (wave - 1) * 0.16,
		reward = isBoss and 8 + wave or 4 + math.floor(wave / 2),
		durationSeconds = WaveConfig.RoundDurationSeconds,
		isBoss = isBoss,
	}
end

WaveConfig.TotalWaves = 30
WaveConfig.PreparationSeconds = 12

return WaveConfig
