local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerConfig = require(ReplicatedStorage.Shared.Config.TowerConfig)
local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local BoardService = require(script.Parent.BoardService)
local SynergyService = require(script.Parent.SynergyService)

local CombatService = {}

local GRID_COLUMNS = BoardService.GRID_COLUMNS
local GRID_ROWS = BoardService.GRID_ROWS

local function pathGridPosition(enemyProgress, pathLength)
	local perimeter = 2 * ((GRID_COLUMNS + 1) + (GRID_ROWS + 1))
	local units = ((enemyProgress % pathLength) / pathLength) * perimeter

	if units <= GRID_COLUMNS + 1 then
		return units, 0
	end

	units -= GRID_COLUMNS + 1
	if units <= GRID_ROWS + 1 then
		return GRID_COLUMNS + 1, units
	end

	units -= GRID_ROWS + 1
	if units <= GRID_COLUMNS + 1 then
		return GRID_COLUMNS + 1 - units, GRID_ROWS + 1
	end

	units -= GRID_COLUMNS + 1
	return 0, GRID_ROWS + 1 - units
end

local function distanceToPathCell(tower, enemyProgress)
	local edgeColumn, edgeRow = pathGridPosition(enemyProgress, tower.pathLength or 128)
	local dx = (tower.column or 3) - edgeColumn
	local dy = (tower.row or 2) - edgeRow
	return math.sqrt(dx * dx + dy * dy) * 4
end

local function firstAliveEnemyInRange(board, tower, range)
	local best = nil
	for _, enemy in ipairs(board.enemies) do
		if enemy.alive and enemy.progress >= 0 and distanceToPathCell(tower, enemy.progress) <= range then
			if best == nil or (enemy.progress % board.pathLength) > (best.progress % board.pathLength) then
				best = enemy
			end
		end
	end
	return best
end

function CombatService.CountVisibleEnemies(board)
	return BoardService.CountVisibleEnemies(board)
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
				enemy.progress %= board.pathLength
			end
		end
	end

	for _, tower in ipairs(towers) do
		local definition = TowerConfig.Towers[tower.towerId]
		tower.cooldownRemaining = math.max(0, (tower.cooldownRemaining or 0) - deltaTime)
		if tower.cooldownRemaining <= 0 then
			local range = definition.range + synergies.rangeBonus
			tower.pathLength = board.pathLength
			local target = firstAliveEnemyInRange(board, tower, range)
			if target then
				local damage = definition.damage * synergies.damageMultiplier
				target.health -= damage
				tower.cooldownRemaining = definition.cooldown / synergies.attackSpeedMultiplier
				table.insert(board.attackEvents, {
					towerId = tower.instanceId,
					targetId = target.id,
					targetProgress = target.progress,
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

	board.aliveEnemyCount = CombatService.CountVisibleEnemies(board)
	if board.aliveEnemyCount >= board.enemyLimit then
		board.eliminated = true
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
