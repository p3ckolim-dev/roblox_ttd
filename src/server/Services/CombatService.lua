local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerConfig = require(ReplicatedStorage.Shared.Config.TowerConfig)
local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local BoardService = require(script.Parent.BoardService)
local SynergyService = require(script.Parent.SynergyService)

local CombatService = {}

local function distanceToPathCell(tower, enemyProgress)
	local normalized = enemyProgress % 24
	local edgeColumn = math.clamp(normalized, 1, 6)
	local edgeRow = normalized <= 6 and 0 or normalized <= 12 and normalized - 6 or normalized <= 18 and 5 or 24 - normalized
	local dx = (tower.column or 3) - edgeColumn
	local dy = (tower.row or 2) - edgeRow
	return math.sqrt(dx * dx + dy * dy) * 4
end

local function firstAliveEnemyInRange(board, tower, range)
	local best = nil
	for _, enemy in ipairs(board.enemies) do
		if enemy.alive and enemy.progress >= 0 and distanceToPathCell(tower, enemy.progress) <= range then
			if best == nil or enemy.progress > best.progress then
				best = enemy
			end
		end
	end
	return best
end

function CombatService.StepBoard(board, deltaTime)
	if board.eliminated then
		return
	end

	local synergies = SynergyService.Calculate(board)
	local towers = BoardService.GetBoardTowers(board)
	board.attackEvents = {}

	for _, enemy in ipairs(board.enemies) do
		if enemy.alive then
			enemy.progress += enemy.speed * deltaTime * 4
			if enemy.progress >= board.pathLength then
				enemy.alive = false
				board.life -= enemy.lifeDamage
				if board.life <= 0 then
					board.life = 0
					board.eliminated = true
				end
			end
		end
	end

	for _, tower in ipairs(towers) do
		local definition = TowerConfig.Towers[tower.towerId]
		tower.cooldownRemaining = math.max(0, (tower.cooldownRemaining or 0) - deltaTime)
		if tower.cooldownRemaining <= 0 then
			local range = definition.range + synergies.rangeBonus
			local target = firstAliveEnemyInRange(board, tower, range)
			if target then
				local damage = definition.damage * synergies.damageMultiplier
				target.health -= damage
				tower.cooldownRemaining = definition.cooldown / synergies.attackSpeedMultiplier
				table.insert(board.attackEvents, {
					towerId = tower.instanceId,
					targetId = target.id,
					row = tower.row,
					column = tower.column,
					damage = damage,
				})

				if target.health <= 0 then
					target.alive = false
					board.gold += EnemyConfig.Enemies[target.enemyType].reward
					board.score += math.floor(10 + damage)
				end
			end
		end
	end
end

function CombatService.IsWaveCleared(board)
	for _, enemy in ipairs(board.enemies) do
		if enemy.alive then
			return false
		end
	end
	return true
end

return CombatService
