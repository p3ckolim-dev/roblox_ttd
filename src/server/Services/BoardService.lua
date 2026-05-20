local HttpService = game:GetService("HttpService")

local BoardService = {}

local GRID_COLUMNS = 10
local GRID_ROWS = 10
local BENCH_SIZE = 8
local PATH_LENGTH = 2 * ((GRID_COLUMNS + 1) + (GRID_ROWS + 1)) * 4

BoardService.GRID_COLUMNS = GRID_COLUMNS
BoardService.GRID_ROWS = GRID_ROWS
BoardService.BENCH_SIZE = BENCH_SIZE
BoardService.PATH_LENGTH = PATH_LENGTH

local function emptyGrid()
	local grid = {}
	for row = 1, GRID_ROWS do
		grid[row] = {}
		for column = 1, GRID_COLUMNS do
			grid[row][column] = nil
		end
	end
	return grid
end

function BoardService.CreateBoard(player)
	return {
		player = player,
		life = 25,
		gold = 10,
		interest = 0,
		wave = 0,
		score = 0,
		eliminated = false,
		bench = table.create(BENCH_SIZE),
		grid = emptyGrid(),
		shop = {},
		synergies = {},
		towersByInstanceId = {},
		enemies = {},
		attackEvents = {},
		mergeEvents = {},
		pathLength = PATH_LENGTH,
		enemyLimit = 100,
		aliveEnemyCount = 0,
	}
end

function BoardService.CreateTowerInstance(towerId, rarity)
	return {
		instanceId = HttpService:GenerateGUID(false),
		towerId = towerId,
		rarity = rarity,
		createdAt = os.clock(),
	}
end

function BoardService.FindBenchSlot(board)
	for index = 1, BENCH_SIZE do
		if board.bench[index] == nil then
			return index
		end
	end
	return nil
end

function BoardService.AddToBench(board, towerInstance)
	local slot = BoardService.FindBenchSlot(board)
	if slot == nil then
		return false, "Bench is full"
	end

	board.bench[slot] = towerInstance
	board.towersByInstanceId[towerInstance.instanceId] = towerInstance
	return true, slot
end

function BoardService.PlaceTower(board, instanceId, row, column)
	if row < 1 or row > GRID_ROWS or column < 1 or column > GRID_COLUMNS then
		return false, "Invalid board cell"
	end

	if board.grid[row][column] ~= nil then
		return false, "Cell is occupied"
	end

	local towerInstance = board.towersByInstanceId[instanceId]
	if towerInstance == nil then
		return false, "Tower not found"
	end

	for index = 1, BENCH_SIZE do
		if board.bench[index] and board.bench[index].instanceId == instanceId then
			board.bench[index] = nil
			towerInstance.row = row
			towerInstance.column = column
			board.grid[row][column] = towerInstance
			return true
		end
	end

	return false, "Tower must be on bench before placement"
end

function BoardService.GetBoardTowers(board)
	local towers = {}
	for row = 1, GRID_ROWS do
		for column = 1, GRID_COLUMNS do
			local tower = board.grid[row][column]
			if tower ~= nil then
				table.insert(towers, tower)
			end
		end
	end
	return towers
end

function BoardService.SerializeEnemies(board)
	local enemies = {}
	for _, enemy in ipairs(board.enemies) do
		if enemy.alive and enemy.progress >= 0 then
			table.insert(enemies, {
				id = enemy.id,
				enemyType = enemy.enemyType,
				health = enemy.health,
				maxHealth = enemy.maxHealth,
				progress = enemy.progress,
				speed = enemy.speed,
			})
		end
	end
	return enemies
end

function BoardService.CountVisibleEnemies(board)
	local count = 0
	for _, enemy in ipairs(board.enemies) do
		if enemy.alive and enemy.progress >= 0 then
			count += 1
		end
	end
	return count
end

function BoardService.SerializeWorldOrigin(board)
	if board.worldOrigin == nil then
		return nil
	end

	return {
		x = board.worldOrigin.X,
		y = board.worldOrigin.Y,
		z = board.worldOrigin.Z,
	}
end

function BoardService.RemoveTower(board, instanceId)
	for index = 1, BENCH_SIZE do
		if board.bench[index] and board.bench[index].instanceId == instanceId then
			board.towersByInstanceId[instanceId] = nil
			board.bench[index] = nil
			return true
		end
	end

	for row = 1, GRID_ROWS do
		for column = 1, GRID_COLUMNS do
			local tower = board.grid[row][column]
			if tower and tower.instanceId == instanceId then
				board.towersByInstanceId[instanceId] = nil
				board.grid[row][column] = nil
				return true
			end
		end
	end

	return false
end

function BoardService.Serialize(board)
	return {
		life = board.life,
		gold = board.gold,
		interest = board.interest,
		wave = board.wave,
		score = board.score,
		eliminated = board.eliminated,
		bench = board.bench,
		grid = board.grid,
		shop = board.shop,
		synergies = board.synergies,
		enemies = BoardService.SerializeEnemies(board),
		mergeEvents = board.mergeEvents,
		pathLength = board.pathLength,
		worldOrigin = BoardService.SerializeWorldOrigin(board),
		enemyLimit = board.enemyLimit,
		aliveEnemyCount = board.aliveEnemyCount,
	}
end

return BoardService
