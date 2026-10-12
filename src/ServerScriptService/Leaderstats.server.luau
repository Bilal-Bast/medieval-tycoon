local Players = game:GetService("Players")
local Config = require(script.Parent.Tycoon.Config)

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
end

Players.PlayerAdded:Connect(setupLeaderstats)
for _, player in ipairs(Players:GetPlayers()) do
	setupLeaderstats(player)
end
