local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerConfig = require(ReplicatedStorage.Shared.Config.TowerConfig)
local BoardService = require(script.Parent.BoardService)

local ShopService = {}

local SHOP_SIZE = 5
local REROLL_COST = 2
local BENCH_SIZE = BoardService.BENCH_SIZE

ShopService.SHOP_SIZE = SHOP_SIZE
ShopService.REROLL_COST = REROLL_COST

local rarityOddsByWave = {
	{ maxWave = 4, odds = { Common = 78, Rare = 22, Epic = 0, Legendary = 0, Mythic = 0 } },
	{ maxWave = 10, odds = { Common = 58, Rare = 32, Epic = 10, Legendary = 0, Mythic = 0 } },
	{ maxWave = 18, odds = { Common = 38, Rare = 36, Epic = 20, Legendary = 6, Mythic = 0 } },
	{ maxWave = 25, odds = { Common = 24, Rare = 32, Epic = 28, Legendary = 14, Mythic = 2 } },
	{ maxWave = 30, odds = { Common = 14, Rare = 26, Epic = 32, Legendary = 22, Mythic = 6 } },
}

local function oddsForWave(wave)
	for _, entry in ipairs(rarityOddsByWave) do
		if wave <= entry.maxWave then
			return entry.odds
		end
	end
	return rarityOddsByWave[#rarityOddsByWave].odds
end

function ShopService.RollRarity(wave, random)
	local odds = oddsForWave(wave)
	local roll = random:NextInteger(1, 100)
	local accumulated = 0
	for _, rarity in ipairs(TowerConfig.Rarities) do
		accumulated += odds[rarity] or 0
		if roll <= accumulated then
			return rarity
		end
	end
	return "Common"
end

function ShopService.RollShop(board, random)
	local shop = {}
	for slot = 1, SHOP_SIZE do
		local rarity = ShopService.RollRarity(board.wave, random)
		local candidates = TowerConfig.GetTowerIdsByRarity(rarity)
		local towerId = candidates[random:NextInteger(1, #candidates)]
		shop[slot] = {
			slot = slot,
			towerId = towerId,
			rarity = rarity,
			cost = TowerConfig.Towers[towerId].cost,
		}
	end
	board.shop = shop
	return shop
end

function ShopService.Reroll(board, random)
	if board.gold < REROLL_COST then
		return false, "Not enough gold"
	end

	board.gold -= REROLL_COST
	return true, ShopService.RollShop(board, random)
end

function ShopService.Purchase(board, slot)
	local offer = board.shop[slot]
	if offer == nil then
		return false, "Invalid shop slot"
	end

	if board.gold < offer.cost then
		return false, "Not enough gold"
	end

	local benchSlot = BoardService.FindBenchSlot(board)
	if benchSlot == nil then
		return false, "Bench is full"
	end

	board.gold -= offer.cost
	local towerInstance = BoardService.CreateTowerInstance(offer.towerId, offer.rarity)
	board.bench[benchSlot] = towerInstance
	board.towersByInstanceId[towerInstance.instanceId] = towerInstance
	board.shop[slot] = nil
	return true, towerInstance
end

return ShopService
