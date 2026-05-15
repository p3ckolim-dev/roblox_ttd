local WaveConfig = {}

WaveConfig.Waves = {}

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
		count = isBoss and 1 or 14 + wave * 2,
		spawnInterval = isBoss and 2.0 or math.max(0.35, 0.9 - wave * 0.012),
		healthMultiplier = 1 + (wave - 1) * 0.16,
		reward = isBoss and 8 + wave or 4 + math.floor(wave / 2),
		isBoss = isBoss,
	}
end

WaveConfig.TotalWaves = 30
WaveConfig.PreparationSeconds = 12

return WaveConfig
