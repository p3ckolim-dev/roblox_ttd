local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Net.RemoteNames)
local TowerConfig = require(ReplicatedStorage.Shared.Config.TowerConfig)

local player = Players.LocalPlayer
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
local lastMergeEventId = nil

local shopButtons = {}
local benchButtons = {}
local gridButtons = {}

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

local function styleBox(instance, color)
	instance.BackgroundColor3 = color
	instance.BackgroundTransparency = 0.08
	instance.BorderSizePixel = 0
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

local topBar = makeFrame("TopBar", UDim2.fromOffset(16, 16), UDim2.fromOffset(710, 48))
local readyButton = makeButton(topBar, "ReadyButton", "Ready", UDim2.fromOffset(8, 7), UDim2.fromOffset(120, 34))
local waveLabel = makeLabel(topBar, "WaveLabel", "Wave: -", UDim2.fromOffset(144, 0), UDim2.fromOffset(100, 48))
local lifeLabel = makeLabel(topBar, "LifeLabel", "Life: -", UDim2.fromOffset(254, 0), UDim2.fromOffset(100, 48))
local goldLabel = makeLabel(topBar, "GoldLabel", "Gold: -", UDim2.fromOffset(364, 0), UDim2.fromOffset(100, 48))
local interestLabel = makeLabel(topBar, "InterestLabel", "Interest: -", UDim2.fromOffset(474, 0), UDim2.fromOffset(120, 48))
local rerollButton = makeButton(topBar, "RerollButton", "Reroll -2g", UDim2.fromOffset(600, 7), UDim2.fromOffset(100, 34))

local shopPanel = makeFrame("ShopPanel", UDim2.new(0, 16, 1, -184), UDim2.fromOffset(510, 168))
makeLabel(shopPanel, "ShopTitle", "Shop", UDim2.fromOffset(10, 4), UDim2.fromOffset(120, 24), 16)
for slot = 1, 5 do
	local x = 10 + (slot - 1) * 98
	local button = makeButton(shopPanel, `ShopSlotButton_{slot}`, `Shop {slot}`, UDim2.fromOffset(x, 36), UDim2.fromOffset(88, 104))
	shopButtons[slot] = button
	button.Activated:Connect(function()
		if latestSnapshot and latestSnapshot.board then
			purchaseRemote:FireServer(slot)
		end
	end)
end

local benchPanel = makeFrame("BenchPanel", UDim2.new(0.5, -300, 1, -116), UDim2.fromOffset(600, 100))
makeLabel(benchPanel, "BenchTitle", "Bench: select a tower, then choose a board cell", UDim2.fromOffset(10, 4), UDim2.fromOffset(420, 24), 14)
for slot = 1, 8 do
	local x = 10 + (slot - 1) * 72
	local button = makeButton(benchPanel, `BenchSlotButton_{slot}`, `Bench {slot}`, UDim2.fromOffset(x, 32), UDim2.fromOffset(64, 58))
	benchButtons[slot] = button
	button.Activated:Connect(function()
		local board = latestSnapshot and latestSnapshot.board
		if board and board.bench and board.bench[slot] then
			selectedBenchSlot = slot
		else
			selectedBenchSlot = nil
		end
		if latestSnapshot then
			task.defer(function()
				for index, benchButton in ipairs(benchButtons) do
					benchButton.BackgroundColor3 = index == selectedBenchSlot and Color3.fromRGB(55, 132, 255) or Color3.fromRGB(39, 48, 61)
				end
			end)
		end
	end)
end

local boardPanel = makeFrame("BoardPanel", UDim2.new(1, -350, 1, -280), UDim2.fromOffset(334, 264))
makeLabel(boardPanel, "BoardTitle", "Board", UDim2.fromOffset(10, 4), UDim2.fromOffset(120, 24), 16)
makeLabel(boardPanel, "BoardHint", "Click a bench slot, then click a cell.", UDim2.fromOffset(78, 4), UDim2.fromOffset(240, 24), 12)
for row = 1, 4 do
	gridButtons[row] = {}
	for column = 1, 6 do
		local button = makeButton(boardPanel, `GridCellButton_{row}_{column}`, "", UDim2.fromOffset(10 + (column - 1) * 52, 34 + (row - 1) * 52), UDim2.fromOffset(46, 46))
		gridButtons[row][column] = button
		button.Activated:Connect(function()
			local board = latestSnapshot and latestSnapshot.board
			local tower = board and board.bench and selectedBenchSlot and board.bench[selectedBenchSlot]
			if tower then
				placeRemote:FireServer(tower.instanceId, row, column)
				selectedBenchSlot = nil
			end
		end)
	end
end

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
	for slot, button in ipairs(benchButtons) do
		local tower = board and board.bench and board.bench[slot]
		if tower then
			local definition = towerDefinition(tower.towerId)
			button.Text = formatTowerCard(tower.towerId)
			button.BackgroundColor3 = slot == selectedBenchSlot and Color3.fromRGB(78, 160, 255) or rarityColor(definition and definition.rarity)
		else
			button.Text = "Empty"
			button.BackgroundColor3 = Color3.fromRGB(25, 30, 38)
		end
	end
end

local function updateGrid(board)
	for row = 1, 4 do
		for column = 1, 6 do
			local button = gridButtons[row][column]
			local tower = board and board.grid and board.grid[row] and board.grid[row][column]
			if tower then
				local definition = towerDefinition(tower.towerId)
				button.Text = definition and shortTowerId(definition.displayName) or shortTowerId(tower.towerId)
				button.BackgroundColor3 = rarityColor(definition and definition.rarity)
			else
				button.Text = `{row},{column}`
				button.BackgroundColor3 = selectedBenchSlot and Color3.fromRGB(44, 68, 58) or Color3.fromRGB(34, 42, 53)
			end
		end
	end
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

local function render(snapshot)
	latestSnapshot = snapshot
	local board = snapshot and snapshot.board
	if board == nil then
		waveLabel.Text = "Wave: -"
		lifeLabel.Text = "Life: -"
		goldLabel.Text = "Gold: -"
		interestLabel.Text = "Interest: -"
		updateShop(nil)
		updateBench(nil)
		updateGrid(nil)
		synergyLabel.Text = "Synergies\nWaiting for match"
		return
	end

	waveLabel.Text = `Wave: {board.wave}`
	lifeLabel.Text = `Life: {board.life}`
	goldLabel.Text = `Gold: {board.gold}`
	interestLabel.Text = `Interest: {board.interest}`
	updateShop(board)
	updateBench(board)
	updateGrid(board)
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

stateUpdateRemote.OnClientEvent:Connect(render)

local ok, snapshot = pcall(function()
	return requestSnapshot:InvokeServer()
end)
if ok then
	render(snapshot)
end
