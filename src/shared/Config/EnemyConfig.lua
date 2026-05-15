local EnemyConfig = {}

EnemyConfig.Enemies = {
	Basic = {
		displayName = "Drifter",
		health = 35,
		speed = 1.0,
		reward = 1,
		lifeDamage = 1,
	},
	Fast = {
		displayName = "Skitter",
		health = 24,
		speed = 1.45,
		reward = 1,
		lifeDamage = 1,
	},
	Tank = {
		displayName = "Brute",
		health = 90,
		speed = 0.72,
		reward = 2,
		lifeDamage = 2,
	},
	Boss = {
		displayName = "Prime",
		health = 620,
		speed = 0.55,
		reward = 12,
		lifeDamage = 8,
	},
}

return EnemyConfig
