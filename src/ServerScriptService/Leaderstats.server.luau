local Players = game:GetService("Players")
local Config = require(script.Parent.Tycoon.Config)
local MonetizationService = require(script.Parent.Tycoon.MonetizationService)

local function setupLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local cash = leaderstats:FindFirstChild("Cash")
	if not cash then
		cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = Config.StartingCash
		cash.Parent = leaderstats
	end

	local prosperity = leaderstats:FindFirstChild("Prosperity")
	if not prosperity then
		prosperity = Instance.new("IntValue")
		prosperity.Name = "Prosperity"
		prosperity.Value = 0
		prosperity.Parent = leaderstats
	end

	local zombieKills = leaderstats:FindFirstChild("ZombieKills")
	if not zombieKills then
		zombieKills = Instance.new("IntValue")
		zombieKills.Name = "ZombieKills"
		zombieKills.Value = 0
		zombieKills.Parent = leaderstats
	end

	MonetizationService.RegisterPlayer(player, cash)
end

Players.PlayerAdded:Connect(setupLeaderstats)
for _, player in ipairs(Players:GetPlayers()) do
	setupLeaderstats(player)
end
