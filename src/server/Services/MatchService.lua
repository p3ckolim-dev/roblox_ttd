local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Net.RemoteNames)
local BoardService = require(script.Parent.BoardService)
local ShopService = require(script.Parent.ShopService)
local MergeService = require(script.Parent.MergeService)
local SynergyService = require(script.Parent.SynergyService)
local WaveService = require(script.Parent.WaveService)
local CombatService = require(script.Parent.CombatService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local WorldService = require(script.Parent.WorldService)

local MatchService = {}

local MAX_PLAYERS = 6
local MIN_PLAYERS = 1
local START_COUNTDOWN = 3
local COMBAT_STEP = 0.05
local STATE_BROADCAST_INTERVAL = 0.2

local state = {
	status = "Lobby",
	ready = {},
	boards = {},
	random = Random.new(),
	currentWave = 0,
	phase = "Lobby",
	timeRemaining = 0,
	phaseDuration = 0,
	nextWave = 1,
}

local remotes = {}

local function getRemote(name, className)
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	local remote = folder:FindFirstChild(name)
	if remote == nil then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
	end
	return remote
end

local function snapshotFor(player)
	local board = state.boards[player]
	return {
		status = state.status,
		phase = state.phase,
		timeRemaining = state.timeRemaining,
		phaseDuration = state.phaseDuration,
		nextWave = state.nextWave,
		ready = state.ready[player] == true,
		board = board and BoardService.Serialize(board) or nil,
		rankings = MatchService.GetRankings(),
	}
end

local function stepActiveBoards(deltaTime)
	for _, board in pairs(state.boards) do
		if not board.eliminated then
			CombatService.StepBoard(board, deltaTime)
			WorldService.RefreshCombat(board)
		end
	end
end

function MatchService.GetRankings()
	local rankings = {}
	for player, board in pairs(state.boards) do
		table.insert(rankings, {
			playerName = player.Name,
			userId = player.UserId,
			wave = board.wave,
			score = board.score,
			life = board.life,
			aliveEnemyCount = board.aliveEnemyCount,
			eliminated = board.eliminated,
		})
	end

	table.sort(rankings, function(a, b)
		if a.wave ~= b.wave then
			return a.wave > b.wave
		end
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.life > b.life
	end)

	for index, entry in ipairs(rankings) do
		entry.rank = index
	end

	return rankings
end

function MatchService.Broadcast()
	for _, player in ipairs(Players:GetPlayers()) do
		remotes.StateUpdate:FireClient(player, snapshotFor(player))
	end
end

function MatchService.SetReady(player, ready)
	if state.status ~= "Lobby" then
		return false, "Match already running"
	end

	state.ready[player] = ready == true
	MatchService.Broadcast()
	return true
end

function MatchService.CanStart()
	local count = 0
	local readyCount = 0
	for _, player in ipairs(Players:GetPlayers()) do
		count += 1
		if state.ready[player] then
			readyCount += 1
		end
	end
	return count >= MIN_PLAYERS and readyCount >= math.min(count, MAX_PLAYERS)
end

function MatchService.StartMatch()
	state.status = "Running"
	state.currentWave = 0
	state.phase = "Wave"
	state.timeRemaining = 0
	state.phaseDuration = 0
	state.nextWave = 1
	state.boards = {}
	WorldService.Clear()

	for index, player in ipairs(Players:GetPlayers()) do
		if index <= MAX_PLAYERS then
			local board = BoardService.CreateBoard(player)
			WorldService.AttachBoard(board, WorldService.CreateBoardModel(player, index))
			state.boards[player] = board
			WorldService.SpawnPlayerAtBoardCenter(player, board)
			ShopService.RollShop(board, state.random)
			SynergyService.Calculate(board)
		end
	end

	MatchService.Broadcast()
	task.spawn(MatchService.RunMatch)
	return true
end

function MatchService.RunMatch()
	for wave = 1, 30 do
		state.currentWave = wave
		state.phase = "Wave"
		local broadcastElapsed = STATE_BROADCAST_INTERVAL
		local waveElapsed = 0
		local waveConfig = WaveService.GetWave(wave)
		local waveDuration = waveConfig.durationSeconds or 45
		state.timeRemaining = waveDuration
		state.phaseDuration = waveDuration
		state.nextWave = wave

		for _, board in pairs(state.boards) do
			if not board.eliminated then
				WaveService.SpawnWave(board, wave)
			end
		end
		MatchService.Broadcast()

		while state.status == "Running" and waveElapsed < waveDuration do
			stepActiveBoards(COMBAT_STEP)
			waveElapsed += COMBAT_STEP
			state.timeRemaining = math.max(0, waveDuration - waveElapsed)
			broadcastElapsed += COMBAT_STEP
			if broadcastElapsed >= STATE_BROADCAST_INTERVAL then
				broadcastElapsed = 0
				MatchService.Broadcast()
			end
			task.wait(COMBAT_STEP)
		end

		for _, board in pairs(state.boards) do
			if not board.eliminated then
				WaveService.ApplyWaveReward(board, wave)
				ShopService.RollShop(board, state.random)
				WorldService.RefreshCombat(board)
			end
		end

		MatchService.Broadcast()
		if wave < 30 then
			local intermissionElapsed = 0
			broadcastElapsed = STATE_BROADCAST_INTERVAL
			state.phase = "Intermission"
			state.timeRemaining = START_COUNTDOWN
			state.phaseDuration = START_COUNTDOWN
			state.nextWave = wave + 1
			MatchService.Broadcast()

			while state.status == "Running" and intermissionElapsed < START_COUNTDOWN do
				stepActiveBoards(COMBAT_STEP)
				intermissionElapsed += COMBAT_STEP
				state.timeRemaining = math.max(0, START_COUNTDOWN - intermissionElapsed)
				broadcastElapsed += COMBAT_STEP
				if broadcastElapsed >= STATE_BROADCAST_INTERVAL then
					broadcastElapsed = 0
					MatchService.Broadcast()
				end
				task.wait(COMBAT_STEP)
			end
		end
	end

	MatchService.EndMatch()
end

function MatchService.EndMatch()
	state.status = "Results"
	state.phase = "Results"
	state.timeRemaining = 0
	state.phaseDuration = 0
	local rankings = MatchService.GetRankings()
	local rankByUserId = {}
	for _, entry in ipairs(rankings) do
		rankByUserId[entry.userId] = entry.rank
	end

	for player, board in pairs(state.boards) do
		PlayerDataService.RecordMatch(player, {
			wave = board.wave,
			score = board.score,
			rank = rankByUserId[player.UserId],
		})
	end

	MatchService.Broadcast()
	task.wait(8)
	state.status = "Lobby"
	state.phase = "Lobby"
	state.timeRemaining = 0
	state.phaseDuration = 0
	state.nextWave = 1
	state.ready = {}
	state.boards = {}
	WorldService.Clear()
	MatchService.Broadcast()
end

function MatchService.Purchase(player, slot)
	local board = state.boards[player]
	if board == nil or board.eliminated then
		return false, "No active board"
	end

	local ok, result = ShopService.Purchase(board, slot)
	if ok then
		MergeService.AutoMerge(board, state.random)
		SynergyService.Calculate(board)
		WorldService.RefreshBoard(board)
		WorldService.CreateMergeBurst(board)
		MatchService.Broadcast()
	end
	return ok, result
end

function MatchService.Reroll(player)
	local board = state.boards[player]
	if board == nil or board.eliminated then
		return false, "No active board"
	end

	local ok, result = ShopService.Reroll(board, state.random)
	if ok then
		MatchService.Broadcast()
	end
	return ok, result
end

function MatchService.PlaceTower(player, instanceId, row, column)
	local board = state.boards[player]
	if board == nil or board.eliminated then
		return false, "No active board"
	end

	local ok, result = BoardService.PlaceTower(board, instanceId, row, column)
	if ok then
		MergeService.AutoMerge(board, state.random)
		SynergyService.Calculate(board)
		WorldService.RefreshBoard(board)
		WorldService.CreateMergeBurst(board)
		MatchService.Broadcast()
	end
	return ok, result
end

function MatchService.Init()
	remotes.Ready = getRemote(RemoteNames.Ready, "RemoteEvent")
	remotes.PurchaseTower = getRemote(RemoteNames.PurchaseTower, "RemoteEvent")
	remotes.RerollShop = getRemote(RemoteNames.RerollShop, "RemoteEvent")
	remotes.PlaceTower = getRemote(RemoteNames.PlaceTower, "RemoteEvent")
	remotes.StateUpdate = getRemote(RemoteNames.StateUpdate, "RemoteEvent")
	remotes.RequestSnapshot = getRemote(RemoteNames.RequestSnapshot, "RemoteFunction")

	remotes.Ready.OnServerEvent:Connect(function(player, ready)
		MatchService.SetReady(player, ready)
		if MatchService.CanStart() then
			MatchService.StartMatch()
		end
	end)

	remotes.PurchaseTower.OnServerEvent:Connect(function(player, slot)
		MatchService.Purchase(player, slot)
	end)

	remotes.RerollShop.OnServerEvent:Connect(function(player)
		MatchService.Reroll(player)
	end)

	remotes.PlaceTower.OnServerEvent:Connect(function(player, instanceId, row, column)
		MatchService.PlaceTower(player, instanceId, row, column)
	end)

	remotes.RequestSnapshot.OnServerInvoke = snapshotFor
end

return MatchService
