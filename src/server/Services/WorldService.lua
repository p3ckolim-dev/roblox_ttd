local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local TowerConfig = require(ReplicatedStorage.Shared.Config.TowerConfig)
local BoardService = require(script.Parent.BoardService)

local WorldService = {}

local GRID_COLUMNS = BoardService.GRID_COLUMNS
local GRID_ROWS = BoardService.GRID_ROWS
local CELL_SIZE = 6
local TILE_GAP = 0.35
local TILE_HEIGHT = 0.45
local SURFACE_Y = 0.35
local BOARD_SPACING = 120
local ENEMY_Y = 2.25
local BENCH_Z = (GRID_ROWS + 2) * CELL_SIZE

local ENEMY_COLORS = {
	Basic = Color3.fromRGB(226, 232, 240),
	Fast = Color3.fromRGB(80, 220, 140),
	Tank = Color3.fromRGB(255, 188, 72),
	Boss = Color3.fromRGB(255, 88, 88),
}

local ENEMY_SIZES = {
	Basic = Vector3.new(2.2, 2.2, 2.2),
	Fast = Vector3.new(1.7, 1.7, 1.7),
	Tank = Vector3.new(3.0, 3.0, 3.0),
	Boss = Vector3.new(5.0, 5.0, 5.0),
}

local rootFolder = Workspace:FindFirstChild("TacticalTowerDefense")
if rootFolder == nil then
	rootFolder = Instance.new("Folder")
	rootFolder.Name = "TacticalTowerDefense"
	rootFolder.Parent = Workspace
end

local function createPart(name, size, position, color, parent, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function originForSlot(slot)
	local x = ((slot - 1) % 3) * BOARD_SPACING
	local z = math.floor((slot - 1) / 3) * BOARD_SPACING
	return Vector3.new(x, 0, z)
end

local function boardCenter(origin)
	local boardWidth = (GRID_COLUMNS + 1) * CELL_SIZE
	local boardDepth = (GRID_ROWS + 3) * CELL_SIZE
	return origin + Vector3.new(boardWidth / 2, 0, boardDepth / 2 - CELL_SIZE / 2)
end

local function pathPosition(origin, progress, pathLength)
	local loopProgress = math.clamp(progress / pathLength, 0, 1)
	local perimeter = 2 * ((GRID_COLUMNS + 1) + (GRID_ROWS + 1))
	local units = loopProgress * perimeter
	local rightEdge = (GRID_COLUMNS + 1) * CELL_SIZE
	local bottomEdge = (GRID_ROWS + 1) * CELL_SIZE

	if units <= GRID_COLUMNS + 1 then
		return origin + Vector3.new(units * CELL_SIZE, ENEMY_Y, 0)
	end

	units -= GRID_COLUMNS + 1
	if units <= GRID_ROWS + 1 then
		return origin + Vector3.new(rightEdge, ENEMY_Y, units * CELL_SIZE)
	end

	units -= GRID_ROWS + 1
	if units <= GRID_COLUMNS + 1 then
		return origin + Vector3.new(rightEdge - units * CELL_SIZE, ENEMY_Y, bottomEdge)
	end

	units -= GRID_COLUMNS + 1
	return origin + Vector3.new(0, ENEMY_Y, bottomEdge - units * CELL_SIZE)
end

local function getBoardOrigin(board)
	if board.worldOrigin then
		return board.worldOrigin
	end

	return Vector3.new(0, 0, 0)
end

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

function WorldService.CreateBoardModel(player, slot)
	local folder = Instance.new("Folder")
	folder.Name = `{player.UserId}_Board`
	folder.Parent = rootFolder

	local origin = originForSlot(slot)
	folder:SetAttribute("OriginX", origin.X)
	folder:SetAttribute("OriginZ", origin.Z)
	local boardWidth = (GRID_COLUMNS + 1) * CELL_SIZE
	local boardDepth = (GRID_ROWS + 3) * CELL_SIZE
	local center = boardCenter(origin)
	createPart("Base", Vector3.new(boardWidth + CELL_SIZE * 2, 0.6, boardDepth + CELL_SIZE), center + Vector3.new(0, -0.3, 0), Color3.fromRGB(24, 28, 35), folder)

	local startPoint = createPart("StartPoint", Vector3.new(4.2, 0.18, 4.2), center + Vector3.new(0, SURFACE_Y + 0.18, 0), Color3.fromRGB(120, 210, 255), folder, Enum.Material.Neon)
	startPoint.CanQuery = false
	startPoint:SetAttribute("StartPoint", true)

	for row = 1, GRID_ROWS do
		for column = 1, GRID_COLUMNS do
			local position = origin + Vector3.new(column * CELL_SIZE, SURFACE_Y, row * CELL_SIZE)
			local cell = createPart(`Cell_{row}_{column}`, Vector3.new(CELL_SIZE - TILE_GAP, TILE_HEIGHT, CELL_SIZE - TILE_GAP), position, Color3.fromRGB(47, 57, 70), folder)
			cell:SetAttribute("GridRow", row)
			cell:SetAttribute("GridColumn", column)
			createPart(`CellMarker_{row}_{column}`, Vector3.new(1.2, 0.08, 1.2), position + Vector3.new(0, TILE_HEIGHT / 2 + 0.08, 0), Color3.fromRGB(91, 160, 255), folder, Enum.Material.Neon)
		end
	end

	local pathColor = Color3.fromRGB(91, 99, 112)
	for column = 0, GRID_COLUMNS + 1 do
		createPart(`PathTop_{column}`, Vector3.new(CELL_SIZE - 1, 0.32, 3.2), origin + Vector3.new(column * CELL_SIZE, 0.18, 0), pathColor, folder)
		createPart(`PathBottom_{column}`, Vector3.new(CELL_SIZE - 1, 0.32, 3.2), origin + Vector3.new(column * CELL_SIZE, 0.18, (GRID_ROWS + 1) * CELL_SIZE), pathColor, folder)
	end
	for row = 1, GRID_ROWS do
		createPart(`PathLeft_{row}`, Vector3.new(3.2, 0.32, CELL_SIZE - 1), origin + Vector3.new(0, 0.18, row * CELL_SIZE), pathColor, folder)
		createPart(`PathRight_{row}`, Vector3.new(3.2, 0.32, CELL_SIZE - 1), origin + Vector3.new((GRID_COLUMNS + 1) * CELL_SIZE, 0.18, row * CELL_SIZE), pathColor, folder)
	end

	for slotIndex = 1, BoardService.BENCH_SIZE do
		local benchColumn = ((GRID_COLUMNS - BoardService.BENCH_SIZE) / 2) + slotIndex
		local position = origin + Vector3.new(benchColumn * CELL_SIZE, SURFACE_Y, BENCH_Z)
		local benchSlot = createPart(`BenchSlot_{slotIndex}`, Vector3.new(CELL_SIZE - TILE_GAP, TILE_HEIGHT, CELL_SIZE - TILE_GAP), position, Color3.fromRGB(58, 48, 72), folder)
		benchSlot:SetAttribute("BenchSlot", slotIndex)
		createPart(`BenchMarker_{slotIndex}`, Vector3.new(1.1, 0.08, 1.1), position + Vector3.new(0, TILE_HEIGHT / 2 + 0.08, 0), Color3.fromRGB(255, 190, 96), folder, Enum.Material.Neon)
	end

	return folder
end

function WorldService.AttachBoard(board, folder)
	board.worldFolder = folder
	board.worldOrigin = Vector3.new(folder:GetAttribute("OriginX") or 0, 0, folder:GetAttribute("OriginZ") or 0)
end

function WorldService.BoardCenter(board)
	return boardCenter(getBoardOrigin(board))
end

local function pivotCharacterToBoardCenter(character, board)
	if character == nil or character.Parent == nil then
		return
	end

	local center = WorldService.BoardCenter(board)
	character:PivotTo(CFrame.new(center + Vector3.new(0, 6, 0)))
end

function WorldService.SpawnPlayerAtBoardCenter(player, board)
	local character = player.Character
	if character then
		pivotCharacterToBoardCenter(character, board)
		return
	end

	task.spawn(function()
		pivotCharacterToBoardCenter(player.CharacterAdded:Wait(), board)
	end)
end

function WorldService.CreateTowerVisual(board, tower)
	if board.worldFolder == nil or tower.row == nil or tower.column == nil then
		return
	end

	local existing = board.worldFolder:FindFirstChild(tower.instanceId)
	if existing then
		existing:Destroy()
	end

	local definition = TowerConfig.Towers[tower.towerId]
	local originColor = TowerConfig.Origins[definition.origin].color
	local cell = board.worldFolder:FindFirstChild(`Cell_{tower.row}_{tower.column}`)
	if cell == nil then
		return
	end

	local part = createPart(tower.instanceId, Vector3.new(3.5, 5, 3.5), cell.Position + Vector3.new(0, 2.6, 0), originColor, board.worldFolder)
	part.Shape = Enum.PartType.Cylinder
	part:SetAttribute("TowerId", tower.towerId)
	part:SetAttribute("TowerInstanceId", tower.instanceId)
	part:SetAttribute("Rarity", tower.rarity)
end

function WorldService.CreateBenchTowerVisual(board, tower, slot)
	if board.worldFolder == nil then
		return
	end

	local existing = board.worldFolder:FindFirstChild(`BenchTower_{tower.instanceId}`)
	if existing then
		existing:Destroy()
	end

	local definition = TowerConfig.Towers[tower.towerId]
	local originColor = TowerConfig.Origins[definition.origin].color
	local benchSlot = board.worldFolder:FindFirstChild(`BenchSlot_{slot}`)
	if benchSlot == nil then
		return
	end

	local part = createPart(`BenchTower_{tower.instanceId}`, Vector3.new(3.0, 3.0, 3.0), benchSlot.Position + Vector3.new(0, 1.9, 0), originColor, board.worldFolder)
	part.Shape = Enum.PartType.Cylinder
	part:SetAttribute("TowerId", tower.towerId)
	part:SetAttribute("TowerInstanceId", tower.instanceId)
	part:SetAttribute("BenchSlot", slot)
	part:SetAttribute("Rarity", tower.rarity)
end

local function createEnemyVisual(enemy, parent)
	local part = createPart(enemy.id, ENEMY_SIZES[enemy.enemyType] or ENEMY_SIZES.Basic, Vector3.new(0, ENEMY_Y, 0), ENEMY_COLORS[enemy.enemyType] or ENEMY_COLORS.Basic, parent, Enum.Material.Neon)
	part.Shape = Enum.PartType.Ball
	part:SetAttribute("EnemyId", enemy.id)
	part:SetAttribute("EnemyType", enemy.enemyType)

	local hp = Instance.new("BillboardGui")
	hp.Name = "HealthBar"
	hp.Size = UDim2.fromOffset(44, 6)
	hp.StudsOffset = Vector3.new(0, 2.8, 0)
	hp.AlwaysOnTop = true
	hp.Parent = part

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(80, 220, 140)
	fill.BorderSizePixel = 0
	fill.Parent = hp

	return part
end

function WorldService.UpdateEnemyVisuals(board)
	if board.worldFolder == nil then
		return
	end

	local enemyFolder = getOrCreateFolder(board.worldFolder, "EnemyVisuals")
	local alive = {}
	local origin = getBoardOrigin(board)

	for _, enemy in ipairs(board.enemies) do
		if enemy.alive and enemy.progress >= 0 then
			alive[enemy.id] = true
			local visual = enemyFolder:FindFirstChild(enemy.id) or createEnemyVisual(enemy, enemyFolder)
			visual.Position = pathPosition(origin, enemy.progress, board.pathLength)
			local fill = visual:FindFirstChild("HealthBar") and visual.HealthBar:FindFirstChild("Fill")
			if fill then
				fill.Size = UDim2.fromScale(math.clamp(enemy.health / enemy.maxHealth, 0, 1), 1)
			end
		end
	end

	for _, child in ipairs(enemyFolder:GetChildren()) do
		if child:GetAttribute("EnemyId") and not alive[child.Name] then
			child:Destroy()
		end
	end
end

local function towerPosition(board, row, column)
	local cell = board.worldFolder and board.worldFolder:FindFirstChild(`Cell_{row}_{column}`)
	if cell then
		return cell.Position + Vector3.new(0, 4.6, 0)
	end
	return getBoardOrigin(board)
end

local function enemyPosition(board, event)
	local enemyFolder = board.worldFolder and board.worldFolder:FindFirstChild("EnemyVisuals")
	local enemy = enemyFolder and enemyFolder:FindFirstChild(event.targetId)
	if enemy then
		return enemy.Position
	end
	if event.targetProgress then
		return pathPosition(getBoardOrigin(board), event.targetProgress, board.pathLength)
	end
	return nil
end

function WorldService.CreateAttackBeam(board, event)
	if board.worldFolder == nil then
		return
	end

	local startPosition = towerPosition(board, event.row, event.column)
	local endPosition = enemyPosition(board, event)
	if endPosition == nil then
		return
	end

	local midpoint = (startPosition + endPosition) / 2
	local distance = (startPosition - endPosition).Magnitude
	local beam = createPart("AttackBeam", Vector3.new(0.32, 0.32, distance), midpoint, Color3.fromRGB(120, 210, 255), board.worldFolder, Enum.Material.Neon)
	beam.CFrame = CFrame.lookAt(midpoint, endPosition)
	Debris:AddItem(beam, 0.22)

	local impact = createPart("AttackImpact", Vector3.new(1.6, 1.6, 1.6), endPosition, Color3.fromRGB(255, 245, 150), board.worldFolder, Enum.Material.Neon)
	impact.Shape = Enum.PartType.Ball
	Debris:AddItem(impact, 0.18)
end

function WorldService.CreateMergeBurst(board)
	if board.worldFolder == nil then
		return
	end

	for _, event in ipairs(board.mergeEvents or {}) do
		local position = getBoardOrigin(board) + Vector3.new(24.5, 6, 17.5)
		if event.row and event.column then
			position = towerPosition(board, event.row, event.column) + Vector3.new(0, 1.5, 0)
		end

		local burst = createPart("MergeBurst", Vector3.new(5.5, 0.22, 5.5), position, Color3.fromRGB(255, 235, 120), board.worldFolder, Enum.Material.Neon)
		burst.Shape = Enum.PartType.Ball
		Debris:AddItem(burst, 0.45)
	end
end

function WorldService.RefreshCombat(board)
	WorldService.UpdateEnemyVisuals(board)
	for _, event in ipairs(board.attackEvents) do
		WorldService.CreateAttackBeam(board, event)
	end
	board.attackEvents = {}
end

function WorldService.RefreshBoard(board)
	if board.worldFolder == nil then
		return
	end

	for _, child in ipairs(board.worldFolder:GetChildren()) do
		if child:GetAttribute("TowerId") ~= nil then
			child:Destroy()
		end
	end

	for _, tower in ipairs(BoardService.GetBoardTowers(board)) do
		WorldService.CreateTowerVisual(board, tower)
	end

	for slot = 1, BoardService.BENCH_SIZE do
		local tower = board.bench[slot]
		if tower then
			WorldService.CreateBenchTowerVisual(board, tower, slot)
		end
	end
end

function WorldService.Clear()
	rootFolder:ClearAllChildren()
end

return WorldService
