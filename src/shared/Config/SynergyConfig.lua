local SynergyConfig = {}

SynergyConfig.Origins = {
	Astral = {
		displayName = "Astral",
		thresholds = {
			[2] = { damageMultiplier = 1.08 },
			[4] = { damageMultiplier = 1.18 },
			[6] = { damageMultiplier = 1.32 },
		},
	},
	Ember = {
		displayName = "Ember",
		thresholds = {
			[2] = { splashBonus = 1 },
			[4] = { splashBonus = 2, damageMultiplier = 1.08 },
			[6] = { splashBonus = 3, damageMultiplier = 1.18 },
		},
	},
	Mech = {
		displayName = "Mech",
		thresholds = {
			[2] = { attackSpeedMultiplier = 1.08 },
			[4] = { attackSpeedMultiplier = 1.18 },
			[6] = { attackSpeedMultiplier = 1.30 },
		},
	},
	Wild = {
		displayName = "Wild",
		thresholds = {
			[2] = { slowBonus = 0.04 },
			[4] = { slowBonus = 0.08, damageMultiplier = 1.08 },
			[6] = { slowBonus = 0.12, damageMultiplier = 1.18 },
		},
	},
}

SynergyConfig.Classes = {
	Marksman = {
		displayName = "Marksman",
		thresholds = {
			[2] = { rangeBonus = 2 },
			[4] = { rangeBonus = 4, damageMultiplier = 1.08 },
			[6] = { rangeBonus = 6, damageMultiplier = 1.16 },
		},
	},
	Arcanist = {
		displayName = "Arcanist",
		thresholds = {
			[2] = { splashBonus = 1 },
			[4] = { splashBonus = 2, damageMultiplier = 1.10 },
			[6] = { splashBonus = 4, damageMultiplier = 1.20 },
		},
	},
	Guardian = {
		displayName = "Guardian",
		thresholds = {
			[2] = { slowBonus = 0.03 },
			[4] = { slowBonus = 0.07, damageMultiplier = 1.06 },
			[6] = { slowBonus = 0.11, damageMultiplier = 1.12 },
		},
	},
}

return SynergyConfig
