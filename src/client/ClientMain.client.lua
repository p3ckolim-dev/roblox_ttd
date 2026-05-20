local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RemoteNames = require(ReplicatedStorage.Shared.Net.RemoteNames)
local TowerConfig = require(ReplicatedStorage.Shared.Config.TowerConfig)

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local playerGui = player:WaitForChild("PlayerGui")
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local readyRemote = remotesFolder:WaitForChild(RemoteNames.Ready)
local purchaseRemote = remotesFolder:WaitForChild(RemoteNames.PurchaseTower)
local rerollRemote = remotesFolder:WaitForChild(RemoteNames.RerollShop)
local placeRemote = remotesFolder:WaitForChild(RemoteNames.PlaceTower)
local stateUpdateRemote = remotesFolder:WaitForChild(RemoteNames.StateUpdate)
local requestSnapshot = remotesFolder:WaitForChild(RemoteNames.RequestSnapshot)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TacticalTowerDefenseHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = screenGui

local latestSnapshot = nil
local ready = false
local selectedBenchSlot = nil
local selectedBenchTowerId = nil
local lastMergeEventId = nil
local render = nil

local shopButtons = {}
local clientEnemyVisuals = {}

local RARITY_COLORS = {
	Common = Color3.fromRGB(64, 78, 94),
	Rare = Color3.fromRGB(48, 112, 210),
	Epic = Color3.fromRGB(142, 82, 210),
	Legendary = Color3.fromRGB(218, 157, 54),
	Mythic = Color3.fromRGB(216, 70, 94),
}

local ORIGIN_BADGES = {
	Astral = "AST",
	Ember = "EMB",
	Mech = "MCH",
	Wild = "WLD",
}

local CLASS_BADGES = {
	Marksman = "MRK",
	Arcanist = "ARC",
	Guardian = "GRD",
}

local GRID_COLUMNS = 10
local GRID_ROWS = 10
local CELL_SIZE = 6
local ENEMY_Y = 2.25
local PLACEMENT_Y = 0.9
local ENEMY_PROGRESS_SCALE = 4
local ENEMY_CORRECTION_RATE = 5
local BOARD_CAMERA_FOV = 50
local CAMERA_PADDING = 1.28
local MIN_CAMERA_HEIGHT = 110

local PLACEMENT_VALID_COLOR = Color3.fromRGB(58, 132, 92)
local PLACEMENT_OCCUPIED_COLOR = Color3.fromRGB(112, 54, 58)
local PLACEMENT_NEUTRAL_COLOR = Color3.fromRGB(34, 42, 53)
local SELECTED_STROKE_COLOR = Color3.fromRGB(132, 205, 255)

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

local clientRenderFolder = Instance.new("Folder")
clientRenderFolder.Name = `TacticalTowerDefenseClient_{player.UserId}`
clientRenderFolder.Parent = Workspace

local enemyRenderFolder = Instance.new("Folder")
enemyRenderFolder.Name = "EnemyVisuals"
enemyRenderFolder.Parent = clientRenderFolder

local placementPreviewFolder = Instance.new("Folder")
placementPreviewFolder.Name = "PlacementPreview"
placementPreviewFolder.Parent = clientRenderFolder

local function styleBox(instance, color)
	instance.BackgroundColor3 = color
	instance.BackgroundTransparency = 0.08
	instance.BorderSizePixel = 0
end

local function addStroke(instance, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Transparency = 0.45
	stroke.Parent = instance
	return stroke
end

local function makeFrame(name, position, size)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = position
	frame.Size = size
	styleBox(frame, Color3.fromRGB(18, 22, 28))
	frame.Parent = root
	return frame
end

local function makeLabel(parent, name, text, position, size, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(235, 241, 247)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = textSize or 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function makeButton(parent, name, text, position, size)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Position = position
	button.Size = size
	button.AutoButtonColor = true
	button.TextColor3 = Color3.fromRGB(248, 250, 252)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 11
	button.TextWrapped = true
	styleBox(button, Color3.fromRGB(39, 48, 61))
	button.Parent = parent
	return button
end

local topBar = makeFrame("TopBar", UDim2.fromOffset(16, 16), UDim2.fromOffset(840, 48))
local readyButton = makeButton(topBar, "ReadyButton", "Ready", UDim2.fromOffset(8, 7), UDim2.fromOffset(120, 34))
local waveLabel = makeLabel(topBar, "WaveLabel", "Wave: -", UDim2.fromOffset(144, 0), UDim2.fromOffset(92, 48))
local timerLabel = makeLabel(topBar, "TimerLabel", "Timer: -", UDim2.fromOffset(246, 0), UDim2.fromOffset(132, 48))
local lifeLabel = makeLabel(topBar, "LifeLabel", "Enemies: -", UDim2.fromOffset(388, 0), UDim2.fromOffset(106, 48))
local goldLabel = makeLabel(topBar, "GoldLabel", "Gold: -", UDim2.fromOffset(504, 0), UDim2.fromOffset(86, 48))
local interestLabel = makeLabel(topBar, "InterestLabel", "Interest: -", UDim2.fromOffset(600, 0), UDim2.fromOffset(120, 48))
local rerollButton = makeButton(topBar, "RerollButton", "Reroll -2g", UDim2.fromOffset(730, 7), UDim2.fromOffset(100, 34))

local shopPanel = makeFrame("ShopPanel", UDim2.new(1, -220, 0, 204), UDim2.fromOffset(204, 300))
makeLabel(shopPanel, "ShopTitle", "Shop", UDim2.fromOffset(10, 7), UDim2.fromOffset(184, 20), 14)
for slot = 1, 5 do
	local y = 36 + (slot - 1) * 52
	local button = makeButton(shopPanel, `ShopSlotButton_{slot}`, `Shop {slot}`, UDim2.fromOffset(10, y), UDim2.fromOffset(184, 44))
	button.TextSize = 9
	shopButtons[slot] = button
	button.Activated:Connect(function()
		if latestSnapshot and latestSnapshot.board then
			purchaseRemote:FireServer(slot)
		end
	end)
end

local selectionStatusLabel = makeLabel(root, "SelectionStatusLabel", "", UDim2.fromOffset(0, 0), UDim2.fromOffset(0, 0), 1)
selectionStatusLabel.Visible = false

local synergyPanel = makeFrame("SynergyPanel", UDim2.new(1, -252, 0, 16), UDim2.fromOffset(236, 170))
local synergyLabel = makeLabel(synergyPanel, "SynergiesLabel", "Synergies", UDim2.fromOffset(10, 8), UDim2.fromOffset(216, 154), 14)

local mergeToast = makeLabel(root, "MergeToast", "", UDim2.new(0.5, -180, 0, 78), UDim2.fromOffset(360, 42), 16)
mergeToast.BackgroundTransparency = 0.08
mergeToast.BackgroundColor3 = Color3.fromRGB(58, 45, 18)
mergeToast.TextColor3 = Color3.fromRGB(255, 235, 120)
mergeToast.TextXAlignment = Enum.TextXAlignment.Center
mergeToast.Visible = false

local function shortTowerId(towerId)
	if towerId == nil then
		return "-"
	end
	local text = string.gsub(towerId, "(%l)(%u)", "%1\n%2")
	return text
end

local function towerDefinition(towerId)
	return towerId and TowerConfig.Towers[towerId] or nil
end

local function rarityColor(rarity)
	return RARITY_COLORS[rarity] or Color3.fromRGB(39, 48, 61)
end

local function originVector(origin)
	if origin == nil then
		return Vector3.new(0, 0, 0)
	end
	return Vector3.new(origin.x or origin.X or 0, origin.y or origin.Y or 0, origin.z or origin.Z or 0)
end

local function boardFrameSize()
	local boardWidth = (GRID_COLUMNS + 1) * CELL_SIZE
	local boardDepth = (GRID_ROWS + 3) * CELL_SIZE
	return boardWidth + CELL_SIZE * 2, boardDepth + CELL_SIZE
end

local function boardCameraCenter(origin)
	local originPosition = originVector(origin)
	local boardWidth = (GRID_COLUMNS + 1) * CELL_SIZE
	local boardDepth = (GRID_ROWS + 3) * CELL_SIZE
	return originPosition + Vector3.new(boardWidth / 2, 0, boardDepth / 2 - CELL_SIZE / 2)
end

local function cameraHeightForBoard(camera)
	local framedWidth, framedDepth = boardFrameSize()
	local viewportSize = camera.ViewportSize
	local aspectRatio = math.max(viewportSize.X / math.max(viewportSize.Y, 1), 0.1)
	local verticalFov = math.rad(BOARD_CAMERA_FOV)
	local verticalHeight = (framedDepth / 2) / math.tan(verticalFov / 2)
	local horizontalHeight = (framedWidth / 2) / (math.tan(verticalFov / 2) * aspectRatio)
	return math.max(math.max(verticalHeight, horizontalHeight) * CAMERA_PADDING, MIN_CAMERA_HEIGHT)
end

local function updateBoardCamera(board)
	if board == nil or board.worldOrigin == nil then
		return
	end

	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = BOARD_CAMERA_FOV

	local center = boardCameraCenter(board.worldOrigin)
	local height = cameraHeightForBoard(camera)
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0, height, 0), center, Vector3.new(0, 0, -1))
end

local function pathPosition(origin, progress, pathLength)
	local originPosition = originVector(origin)
	local safePathLength = math.max(pathLength or 128, 1)
	local loopProgress = math.clamp((progress or 0) / safePathLength, 0, 1)
	local perimeter = 2 * ((GRID_COLUMNS + 1) + (GRID_ROWS + 1))
	local units = loopProgress * perimeter
	local rightEdge = (GRID_COLUMNS + 1) * CELL_SIZE
	local bottomEdge = (GRID_ROWS + 1) * CELL_SIZE

	if units <= GRID_COLUMNS + 1 then
		return originPosition + Vector3.new(units * CELL_SIZE, ENEMY_Y, 0)
	end

	units -= GRID_COLUMNS + 1
	if units <= GRID_ROWS + 1 then
		return originPosition + Vector3.new(rightEdge, ENEMY_Y, units * CELL_SIZE)
	end

	units -= GRID_ROWS + 1
	if units <= GRID_COLUMNS + 1 then
		return originPosition + Vector3.new(rightEdge - units * CELL_SIZE, ENEMY_Y, bottomEdge)
	end

	units -= GRID_COLUMNS + 1
	return originPosition + Vector3.new(0, ENEMY_Y, bottomEdge - units * CELL_SIZE)
end

local function cellPosition(origin, row, column)
	return originVector(origin) + Vector3.new(column * CELL_SIZE, PLACEMENT_Y, row * CELL_SIZE)
end

local function createClientPart(name, size, position, color, parent, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function createClientEnemyVisual(enemy)
	local part = createClientPart(enemy.id, ENEMY_SIZES[enemy.enemyType] or ENEMY_SIZES.Basic, Vector3.new(0, ENEMY_Y, 0), ENEMY_COLORS[enemy.enemyType] or ENEMY_COLORS.Basic, enemyRenderFolder, Enum.Material.Neon)
	part.Shape = Enum.PartType.Ball
	part:SetAttribute("EnemyId", enemy.id)

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

local function hideReplicatedEnemyVisuals()
	local worldRoot = Workspace:FindFirstChild("TacticalTowerDefense")
	if worldRoot == nil then
		return
	end

	for _, descendant in ipairs(worldRoot:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("EnemyId") then
			descendant.LocalTransparencyModifier = 1
		elseif descendant:IsA("BillboardGui") and descendant.Name == "HealthBar" then
			descendant.Enabled = false
		end
	end
end

local function syncClientEnemyTargets(board)
	local alive = {}
	for _, enemy in ipairs(board.enemies or {}) do
		alive[enemy.id] = true
		local visualState = clientEnemyVisuals[enemy.id]
		if visualState == nil then
			visualState = {
				part = createClientEnemyVisual(enemy),
				currentProgress = enemy.progress,
				targetProgress = enemy.progress,
				speed = enemy.speed or 1,
				health = enemy.health,
				maxHealth = enemy.maxHealth,
			}
			clientEnemyVisuals[enemy.id] = visualState
		else
			visualState.targetProgress = enemy.progress
			visualState.speed = enemy.speed or visualState.speed
			visualState.health = enemy.health
			visualState.maxHealth = enemy.maxHealth
			if visualState.currentProgress > enemy.progress + 4 and visualState.currentProgress < (latestSnapshot.board.pathLength or 128) - 4 then
				visualState.currentProgress = enemy.progress
			end
		end
	end

	for enemyId, visualState in pairs(clientEnemyVisuals) do
		if not alive[enemyId] then
			visualState.part:Destroy()
			clientEnemyVisuals[enemyId] = nil
		end
	end
end

local function updateClientEnemyVisuals(deltaTime)
	local board = latestSnapshot and latestSnapshot.board
	if board == nil or board.worldOrigin == nil then
		return
	end

	for _, visualState in pairs(clientEnemyVisuals) do
		local simulatedProgress = visualState.currentProgress + visualState.speed * deltaTime * ENEMY_PROGRESS_SCALE
		local progressDelta = visualState.targetProgress - simulatedProgress
		if math.abs(progressDelta) > (board.pathLength or 128) / 2 then
			progressDelta = 0
		end
		local correction = progressDelta * ENEMY_CORRECTION_RATE * deltaTime
		visualState.currentProgress = simulatedProgress + correction
		if visualState.currentProgress >= board.pathLength then
			visualState.currentProgress %= board.pathLength
		end
		visualState.part.Position = pathPosition(board.worldOrigin, visualState.currentProgress, board.pathLength)

		local fill = visualState.part:FindFirstChild("HealthBar") and visualState.part.HealthBar:FindFirstChild("Fill")
		if fill then
			fill.Size = UDim2.fromScale(math.clamp((visualState.health or 0) / math.max(visualState.maxHealth or 1, 1), 0, 1), 1)
		end
	end
end

local function clearPlacementPreview()
	placementPreviewFolder:ClearAllChildren()
end

local function updatePlacementPreview(board)
	clearPlacementPreview()
	if board == nil or board.worldOrigin == nil or selectedBenchSlot == nil then
		return
	end

	for row = 1, GRID_ROWS do
		for column = 1, GRID_COLUMNS do
			local occupied = board.grid and board.grid[row] and board.grid[row][column]
			local color = occupied and PLACEMENT_OCCUPIED_COLOR or PLACEMENT_VALID_COLOR
			local preview = createClientPart(`PlacementPreview_{row}_{column}`, Vector3.new(CELL_SIZE - 1, 0.08, CELL_SIZE - 1), cellPosition(board.worldOrigin, row, column), color, placementPreviewFolder, Enum.Material.Neon)
			preview.Transparency = occupied and 0.55 or 0.28
		end
	end
end

local function formatTowerCard(towerId, cost)
	local definition = towerDefinition(towerId)
	if definition == nil then
		return "-"
	end

	local origin = ORIGIN_BADGES[definition.origin] or definition.origin
	local className = CLASS_BADGES[definition.class] or definition.class
	local price = cost and ` ${cost}g` or ""
	return `{definition.displayName}\n{definition.rarity}{price}\n{origin} / {className}`
end

local function summarizeSynergies(synergies)
	if synergies == nil then
		return "Synergies\nNone"
	end

	local parts = { "Synergies" }
	for origin, data in pairs(synergies.Origins or {}) do
		table.insert(parts, `ACTIVE {origin} {data.count}/{data.threshold}`)
	end
	for className, data in pairs(synergies.Classes or {}) do
		table.insert(parts, `ACTIVE {className} {data.count}/{data.threshold}`)
	end
	if #parts == 1 then
		table.insert(parts, "None active")
	end
	return table.concat(parts, "\n")
end

local function updateShop(board)
	for slot, button in ipairs(shopButtons) do
		local offer = board and board.shop and board.shop[slot]
		if offer then
			local definition = towerDefinition(offer.towerId)
			button.Text = formatTowerCard(offer.towerId, offer.cost)
			button.BackgroundColor3 = rarityColor(definition and definition.rarity)
		else
			button.Text = "Sold"
			button.BackgroundColor3 = Color3.fromRGB(25, 30, 38)
		end
	end
end

local function updateBench(board)
	local selectedTower = nil
	if board and board.bench and selectedBenchTowerId then
		for slot = 1, 8 do
			local tower = board.bench[slot]
			if tower and tower.instanceId == selectedBenchTowerId then
				selectedTower = tower
				selectedBenchSlot = slot
				break
			end
		end
	end

	if selectedTower then
		local definition = towerDefinition(selectedTower.towerId)
		selectionStatusLabel.Text = definition and `Selected: {definition.displayName}` or "Selected tower"
	else
		if selectedBenchTowerId then
			selectedBenchTowerId = nil
			selectedBenchSlot = nil
		end
		selectionStatusLabel.Text = ""
	end
end

local function updateGrid(_board)
end

local function updateMergeToast(board)
	local events = board and board.mergeEvents
	local event = events and events[#events]
	if event == nil or event.eventId == lastMergeEventId then
		return
	end

	lastMergeEventId = event.eventId
	local result = towerDefinition(event.resultTowerId)
	mergeToast.Text = result and `Merged into {result.displayName} ({event.resultRarity})` or "Merged"
	mergeToast.Visible = true
	task.delay(2.2, function()
		if lastMergeEventId == event.eventId then
			mergeToast.Visible = false
		end
	end)
end

local function formatTimer(snapshot)
	if snapshot == nil or snapshot.status == "Lobby" then
		return "Timer: -"
	end

	local seconds = math.max(0, math.ceil(snapshot.timeRemaining or 0))
	if snapshot.phase == "Intermission" then
		return `Timer: Next {snapshot.nextWave or "-"} in {seconds}s`
	end
	if snapshot.phase == "Results" then
		return "Timer: Results"
	end
	return `Timer: {seconds}s`
end

local function findWorldInputPart(target)
	local current = target
	while current and current ~= Workspace do
		if current:GetAttribute("TowerInstanceId") or current:GetAttribute("GridRow") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function handleWorldClick()
	local target = findWorldInputPart(mouse.Target)
	if target == nil then
		return
	end

	local towerInstanceId = target:GetAttribute("TowerInstanceId")
	local benchSlot = target:GetAttribute("BenchSlot")
	if towerInstanceId and benchSlot then
		selectedBenchTowerId = towerInstanceId
		selectedBenchSlot = benchSlot
		if latestSnapshot and render then
			render(latestSnapshot)
		end
		return
	end

	local row = target:GetAttribute("GridRow")
	local column = target:GetAttribute("GridColumn")
	if row == nil or column == nil then
		return
	end

	local board = latestSnapshot and latestSnapshot.board
	local occupied = board and board.grid and board.grid[row] and board.grid[row][column]
	if occupied then
		selectionStatusLabel.Text = "That cell is occupied."
	elseif selectedBenchTowerId then
		placeRemote:FireServer(selectedBenchTowerId, row, column)
		selectedBenchTowerId = nil
		selectedBenchSlot = nil
		if latestSnapshot and render then
			render(latestSnapshot)
		end
	else
		selectionStatusLabel.Text = ""
	end
end

function render(snapshot)
	latestSnapshot = snapshot
	local board = snapshot and snapshot.board
	if board == nil then
		waveLabel.Text = "Wave: -"
		timerLabel.Text = formatTimer(snapshot)
		lifeLabel.Text = "Enemies: -"
		goldLabel.Text = "Gold: -"
		interestLabel.Text = "Interest: -"
		updateShop(nil)
		updateBench(nil)
		updateGrid(nil)
		syncClientEnemyTargets({})
		clearPlacementPreview()
		synergyLabel.Text = "Synergies\nWaiting for match"
		return
	end

	waveLabel.Text = `Wave: {board.wave}`
	timerLabel.Text = formatTimer(snapshot)
	lifeLabel.Text = `Enemies: {board.aliveEnemyCount or 0}/{board.enemyLimit or 100}`
	goldLabel.Text = `Gold: {board.gold}`
	interestLabel.Text = `Interest: {board.interest}`
	updateBoardCamera(board)
	updateShop(board)
	updateBench(board)
	updateGrid(board)
	syncClientEnemyTargets(board)
	hideReplicatedEnemyVisuals()
	updatePlacementPreview(board)
	synergyLabel.Text = summarizeSynergies(board.synergies)
	synergyLabel.TextColor3 = string.find(synergyLabel.Text, "ACTIVE") and Color3.fromRGB(78, 160, 255) or Color3.fromRGB(235, 241, 247)
	updateMergeToast(board)
end

readyButton.Activated:Connect(function()
	ready = not ready
	readyButton.Text = ready and "Ready On" or "Ready"
	readyRemote:FireServer(ready)
end)

rerollButton.Activated:Connect(function()
	rerollRemote:FireServer()
end)

mouse.Button1Down:Connect(handleWorldClick)
stateUpdateRemote.OnClientEvent:Connect(render)

local function onRenderStep(deltaTime)
	updateClientEnemyVisuals(deltaTime)
	updateBoardCamera(latestSnapshot and latestSnapshot.board)
end

RunService.RenderStepped:Connect(onRenderStep)

local ok, snapshot = pcall(function()
	return requestSnapshot:InvokeServer()
end)
if ok then
	render(snapshot)
end
