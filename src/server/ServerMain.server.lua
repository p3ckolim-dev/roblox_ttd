local Players = game:GetService("Players")

local MatchService = require(script.Parent.Services.MatchService)
local PlayerDataService = require(script.Parent.Services.PlayerDataService)

Players.PlayerAdded:Connect(function(player)
	PlayerDataService.Load(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerDataService.Release(player)
end)

MatchService.Init()
