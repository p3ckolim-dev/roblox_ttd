local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerConfig = require(ReplicatedStorage.Shared.Config.TowerConfig)
local BoardService = require(script.Parent.BoardService)

local MergeService = {}

local MERGE_COUNT = 3
local MAX_MERGE_EVENTS = 6
MergeService.MERGE_COUNT = MERGE_COUNT

local function collectByTowerId(board)
	local groups = {}
	for instanceId, tower in pairs(board.towersByInstanceId) do
		if tower.instanceId == instanceId then
			groups[tower.towerId] = groups[tower.towerId] or {}
			table.insert(groups[tower.towerId], tower)
		end
	end
	return groups
end

local function firstBoardPosition(towers)
	for _, tower in ipairs(towers) do
		if tower.row and tower.column then
			return tower.row, tower.column
		end
	end
	return nil, nil
end

function MergeService.AutoMerge(board, random)
	local mergedAny = false

	while true do
		local didMerge = false
		local groups = collectByTowerId(board)

		for towerId, towers in pairs(groups) do
			if #towers >= MERGE_COUNT then
				table.sort(towers, function(a, b)
					return a.createdAt < b.createdAt
				end)

				local consumed = { towers[1], towers[2], towers[3] }
				local row, column = firstBoardPosition(consumed)
				for _, tower in ipairs(consumed) do
					BoardService.RemoveTower(board, tower.instanceId)
				end

				local nextRarity = TowerConfig.GetNextRarity(TowerConfig.Towers[towerId].rarity)
				local candidates = TowerConfig.GetTowerIdsByRarity(nextRarity)
				local resultTowerId = candidates[random:NextInteger(1, #candidates)]
				local result = BoardService.CreateTowerInstance(resultTowerId, nextRarity)

				if row and column and board.grid[row][column] == nil then
					result.row = row
					result.column = column
					board.grid[row][column] = result
					board.towersByInstanceId[result.instanceId] = result
				else
					BoardService.AddToBench(board, result)
				end

				board.mergeEvents = board.mergeEvents or {}
				table.insert(board.mergeEvents, {
					eventId = `{os.clock()}:{result.instanceId}`,
					consumedTowerId = towerId,
					resultTowerId = resultTowerId,
					resultRarity = nextRarity,
					row = result.row,
					column = result.column,
				})
				while #board.mergeEvents > MAX_MERGE_EVENTS do
					table.remove(board.mergeEvents, 1)
				end

				mergedAny = true
				didMerge = true
				break
			end
		end

		if not didMerge then
			break
		end
	end

	return mergedAny
end

return MergeService
