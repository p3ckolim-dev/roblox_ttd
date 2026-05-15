local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerConfig = require(ReplicatedStorage.Shared.Config.TowerConfig)
local SynergyConfig = require(ReplicatedStorage.Shared.Config.SynergyConfig)
local BoardService = require(script.Parent.BoardService)

local SynergyService = {}

local function bestThreshold(thresholds, count)
	local best = nil
	for threshold, bonus in pairs(thresholds) do
		if count >= threshold and (best == nil or threshold > best.threshold) then
			best = {
				threshold = threshold,
				bonus = bonus,
			}
		end
	end
	return best
end

function SynergyService.Calculate(board)
	-- Bench units do not count; only placed board towers activate Origins and Classes.
	local counts = {
		Origins = {},
		Classes = {},
	}

	for _, towerInstance in ipairs(BoardService.GetBoardTowers(board)) do
		local definition = TowerConfig.Towers[towerInstance.towerId]
		counts.Origins[definition.origin] = (counts.Origins[definition.origin] or 0) + 1
		counts.Classes[definition.class] = (counts.Classes[definition.class] or 0) + 1
	end

	local active = {
		Origins = {},
		Classes = {},
		damageMultiplier = 1,
		attackSpeedMultiplier = 1,
		rangeBonus = 0,
		splashBonus = 0,
		slowBonus = 0,
	}

	for origin, count in pairs(counts.Origins) do
		local config = SynergyConfig.Origins[origin]
		local threshold = config and bestThreshold(config.thresholds, count)
		if threshold then
			active.Origins[origin] = {
				count = count,
				threshold = threshold.threshold,
				bonus = threshold.bonus,
			}
			active.damageMultiplier *= threshold.bonus.damageMultiplier or 1
			active.attackSpeedMultiplier *= threshold.bonus.attackSpeedMultiplier or 1
			active.rangeBonus += threshold.bonus.rangeBonus or 0
			active.splashBonus += threshold.bonus.splashBonus or 0
			active.slowBonus += threshold.bonus.slowBonus or 0
		end
	end

	for className, count in pairs(counts.Classes) do
		local config = SynergyConfig.Classes[className]
		local threshold = config and bestThreshold(config.thresholds, count)
		if threshold then
			active.Classes[className] = {
				count = count,
				threshold = threshold.threshold,
				bonus = threshold.bonus,
			}
			active.damageMultiplier *= threshold.bonus.damageMultiplier or 1
			active.attackSpeedMultiplier *= threshold.bonus.attackSpeedMultiplier or 1
			active.rangeBonus += threshold.bonus.rangeBonus or 0
			active.splashBonus += threshold.bonus.splashBonus or 0
			active.slowBonus += threshold.bonus.slowBonus or 0
		end
	end

	board.synergies = active
	return active
end

return SynergyService
