local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Config = require(script.Parent.Config)

local TycoonService = {}

local template = ServerStorage:WaitForChild("TycoonTemplate")
local tycoonsFolder = Workspace:WaitForChild("Tycoons")
local moneyBlocksFolder = Workspace:FindFirstChild("MoneyBlocks")
if not moneyBlocksFolder then
	moneyBlocksFolder = Instance.new("Folder")
	moneyBlocksFolder.Name = "MoneyBlocks"
	moneyBlocksFolder.Parent = Workspace
end

local plotStates = {}
local playerToTycoon = {}
local characterConnections = {}

local function getCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		return cash
	end
	return nil
end

local function getPlayerFromHit(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function getClaimLabel(plot)
	local claimPad = plot:FindFirstChild("ClaimPad")
	local billboard = claimPad and claimPad:FindFirstChildOfClass("BillboardGui")
	return billboard and billboard:FindFirstChildWhichIsA("TextLabel", true)
end

local function setClaimDisplay(plot, state, player)
	local banner = plot:FindFirstChild("ClaimBanner", true)
	if banner and banner:IsA("BasePart") then
		banner.Color = player and Color3.fromRGB(83, 119, 75) or Color3.fromRGB(143, 64, 46)
	end

	local claimPad = plot:FindFirstChild("ClaimPad")
	local billboard = claimPad and claimPad:FindFirstChildOfClass("BillboardGui")
	local label = getClaimLabel(plot)
	if label then
		if player then
			label.Text = string.format(
				'<font size="18"><b>%s\'s</b></font>\n<font size="14">Kingdom</font>',
				player.Name
			)
			label.BackgroundTransparency = 0.3
			if billboard then
				billboard.MaxDistance = 42
			end
		else
			label.Text = state.unclaimedText
			label.BackgroundTransparency = 0.12
			if billboard then
				billboard.MaxDistance = 55
			end
		end
	end
end

local function setPurchaseSignVisible(plot, buttonName, visible)
	local signName = buttonName == "BuyDropperButton" and "Dropper1PurchaseSign" or "Dropper2PurchaseSign"
	local sign = plot:FindFirstChild(signName, true)
	if not sign then
		return
	end

	for _, descendant in ipairs(sign:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = visible and 0 or 1
		end
	end
end

local function setButtonVisible(button, visible)
	if not button or not button:IsA("BasePart") then
		return
	end

	button.Transparency = 1
	button.CanCollide = false
	button.CanTouch = visible
	button.CanQuery = false
	setPurchaseSignVisible(button.Parent, button.Name, visible)

	local billboard = button:FindFirstChildOfClass("BillboardGui")
	if billboard then
		billboard.Enabled = visible
	end
end

local function ensurePurchaseButton(plot, state, buttonName, visible)
	local button = plot:FindFirstChild(buttonName)
	if not button then
		local templateButton = template:FindFirstChild(buttonName)
		if not templateButton then
			warn("Missing tycoon template purchase button: " .. buttonName)
			return nil
		end

		button = templateButton:Clone()
		if button:IsA("BasePart") then
			button.CFrame = button.CFrame + state.offset
		end
		button.Parent = plot
	end

	setButtonVisible(button, visible)
	return button
end

local function disconnectPurchaseConnection(state, upgradeName)
	local connection = state.purchaseConnections[upgradeName]
	if connection then
		connection:Disconnect()
		state.purchaseConnections[upgradeName] = nil
	end
end

local function createMoneyBlock(plot, player, dropPoint, upgrade)
	if not plot.Parent or not player.Parent or not dropPoint.Parent then
		return
	end

	local block = Instance.new("Part")
	block.Name = "MoneyBlock"
	block.Size = Config.MoneyBlockSize
	block.Material = upgrade.ResourceMaterial or Config.MoneyBlockMaterial
	block.Color = upgrade.ResourceColor or Config.MoneyBlockColor.Color
	block.Anchored = false
	block.CanCollide = true
	block.CFrame = dropPoint.CFrame
	block:SetAttribute("CashValue", upgrade.MoneyPerDrop)
	block:SetAttribute("OwnerUserId", player.UserId)
	block:SetAttribute("TycoonId", plot.Name)
	block.Parent = moneyBlocksFolder

	pcall(function()
		block:SetNetworkOwner(nil)
	end)
	Debris:AddItem(block, Config.MoneyBlockLifetime)
end

local function startDropper(plot, state, player, upgradeName, dropper)
	local upgrade = Config.Upgrades[upgradeName]
	local dropPoint = dropper:FindFirstChild("DropPoint", true)
	if not upgrade or not dropPoint or not dropPoint:IsA("BasePart") then
		warn("Dropper is missing its configured DropPoint: " .. upgradeName)
		return
	end

	task.spawn(function()
		while state.active
			and state.owner == player
			and state.purchased[upgradeName]
			and plot.Parent
			and dropper.Parent == plot
		do
			task.wait(upgrade.DropInterval)
			if state.active and state.owner == player and dropper.Parent == plot then
				createMoneyBlock(plot, player, dropPoint, upgrade)
			end
		end
	end)
end

local connectPurchaseButton

local function onPurchaseTouched(plot, state, upgradeName, button, hit)
	local upgrade = Config.Upgrades[upgradeName]
	if not upgrade or state.purchaseLocks[upgradeName] then
		return
	end
	state.purchaseLocks[upgradeName] = true

	local player = getPlayerFromHit(hit)
	local owner = plot:FindFirstChild("Owner")
	local playerOwnsPlot = player ~= nil
		and playerToTycoon[player] == plot
		and state.owner == player
		and owner ~= nil
		and owner.Value == player
	local prerequisiteMet = not upgrade.Requires or state.purchased[upgrade.Requires] == true
	local alreadyPurchased = state.purchased[upgradeName] == true
	local cash = player and getCash(player)
	local dropperTemplate = ServerStorage:FindFirstChild(upgradeName)

	if not playerOwnsPlot
		or not prerequisiteMet
		or alreadyPurchased
		or not cash
		or cash.Value < upgrade.Cost
		or not dropperTemplate
		or not dropperTemplate:IsA("Model")
	then
		state.purchaseLocks[upgradeName] = nil
		return
	end

	local dropper = dropperTemplate:Clone()
	for _, descendant in ipairs(dropper:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		end
	end
	dropper:PivotTo(dropper:GetPivot() + state.offset)
	dropper:SetAttribute("OwnerUserId", player.UserId)
	dropper:SetAttribute("TycoonId", plot.Name)
	dropper.Parent = plot

	-- No yields occur between validation and this debit, so simultaneous touches
	-- cannot spend the same balance or purchase the same upgrade twice.
	cash.Value -= upgrade.Cost
	state.purchased[upgradeName] = true
	disconnectPurchaseConnection(state, upgradeName)
	setPurchaseSignVisible(plot, upgrade.ButtonName, false)
	button:Destroy()

	if upgradeName == "Dropper1" then
		local nextUpgrade = Config.Upgrades.Dropper2
		local nextButton = ensurePurchaseButton(plot, state, nextUpgrade.ButtonName, true)
		if nextButton then
			connectPurchaseButton(plot, state, "Dropper2", nextButton)
		end
	end

	startDropper(plot, state, player, upgradeName, dropper)
	state.purchaseLocks[upgradeName] = nil
end

connectPurchaseButton = function(plot, state, upgradeName, button)
	disconnectPurchaseConnection(state, upgradeName)
	state.purchaseConnections[upgradeName] = button.Touched:Connect(function(hit)
		onPurchaseTouched(plot, state, upgradeName, button, hit)
	end)
end

local function connectCollector(plot, state)
	local collector = plot:FindFirstChild("Collector")
	if not collector or not collector:IsA("BasePart") then
		warn("Tycoon is missing a Collector: " .. plot.Name)
		return
	end

	state.collectorConnection = collector.Touched:Connect(function(hit)
		if not hit:IsA("BasePart") or hit.Name ~= "MoneyBlock" then
			return
		end
		if hit:GetAttribute("Collected") == true then
			return
		end
		hit:SetAttribute("Collected", true)

		local ownerUserId = hit:GetAttribute("OwnerUserId")
		local player = typeof(ownerUserId) == "number" and Players:GetPlayerByUserId(ownerUserId) or nil
		local owner = plot:FindFirstChild("Owner")
		local cash = player and getCash(player)
		local value = hit:GetAttribute("CashValue")
		local validBlock = state.active
			and player ~= nil
			and state.owner == player
			and playerToTycoon[player] == plot
			and owner ~= nil
			and owner:IsA("ObjectValue")
			and owner.Value == player
			and hit:GetAttribute("TycoonId") == plot.Name
			and cash ~= nil
			and typeof(value) == "number"
			and value > 0
			and value < 1000000

		if validBlock then
			cash.Value += math.floor(value)
		end
		hit:Destroy()
	end)
end

local function connectConveyor(plot, state)
	local conveyor = plot:FindFirstChild("Conveyor")
	if not conveyor or not conveyor:IsA("BasePart") then
		warn("Tycoon is missing a Conveyor: " .. plot.Name)
		return
	end

	state.conveyorConnection = conveyor.Touched:Connect(function(hit)
		if hit:IsA("BasePart") and hit.Name == "MoneyBlock"
			and hit:GetAttribute("TycoonId") == plot.Name then
			hit.AssemblyLinearVelocity = conveyor.CFrame.LookVector * Config.ConveyorSpeed
		end
	end)
end

local function clearTycoonMoney(plot)
	for _, block in ipairs(moneyBlocksFolder:GetChildren()) do
		if block:GetAttribute("TycoonId") == plot.Name then
			block:Destroy()
		end
	end
end

local function bindPurchaseButtons(plot, state)
	for upgradeName, upgrade in pairs(Config.Upgrades) do
		local visible = upgradeName == "Dropper1"
			or (upgrade.Requires and state.purchased[upgrade.Requires] == true)
		local button = ensurePurchaseButton(plot, state, upgrade.ButtonName, visible)
		if button then
			connectPurchaseButton(plot, state, upgradeName, button)
		end
	end
end

local function createPlot(plotName, offset)
	local plot = tycoonsFolder:FindFirstChild(plotName)
	if not plot or not plot:IsA("Folder") then
		warn("Missing Workspace/Tycoons plot folder: " .. plotName)
		return nil
	end

	local spawn = plot:FindFirstChild("Spawn")
	if spawn and spawn:IsA("SpawnLocation") then
		spawn.Enabled = false
	end

	local owner = plot:FindFirstChild("Owner")
	if owner and owner:IsA("ObjectValue") then
		owner.Value = nil
	end

	local claimPad = plot:FindFirstChild("ClaimPad")
	local claimLabel = getClaimLabel(plot)
	local state = {
		owner = nil,
		active = true,
		offset = offset,
		purchased = {},
		purchaseLocks = {},
		purchaseConnections = {},
		claimConnection = nil,
		collectorConnection = nil,
		conveyorConnection = nil,
		unclaimedText = claimLabel and claimLabel.Text or "CLAIM KINGDOM",
	}
	plotStates[plot] = state

	if claimPad and claimPad:IsA("BasePart") then
		state.claimConnection = claimPad.Touched:Connect(function(hit)
			local player = getPlayerFromHit(hit)
			local ownerValue = plot:FindFirstChild("Owner")
			if not player or not ownerValue or ownerValue.Value ~= nil
				or state.owner ~= nil or playerToTycoon[player] ~= nil
			then
				return
			end

			-- Claim updates are synchronous and contain no yielding calls, so two
			-- players touching the same pad cannot both acquire the plot.
			state.owner = player
			playerToTycoon[player] = plot
			ownerValue.Value = player
			setClaimDisplay(plot, state, player)
		end)
	else
		warn("Tycoon is missing a ClaimPad: " .. plot.Name)
	end

	connectCollector(plot, state)
	connectConveyor(plot, state)
	bindPurchaseButtons(plot, state)
	return plot
end

local function resetPlot(plot, state)
	local previousOwner = state.owner
	state.active = false
	if previousOwner and playerToTycoon[previousOwner] == plot then
		playerToTycoon[previousOwner] = nil
	end

	for upgradeName in pairs(state.purchaseConnections) do
		disconnectPurchaseConnection(state, upgradeName)
	end
	clearTycoonMoney(plot)
	for _, child in ipairs(plot:GetChildren()) do
		if child.Name == "Dropper1" or child.Name == "Dropper2" then
			child:Destroy()
		end
	end

	local ownerValue = plot:FindFirstChild("Owner")
	if ownerValue and ownerValue:IsA("ObjectValue") then
		ownerValue.Value = nil
	end
	state.owner = nil
	state.active = true
	state.purchased = {}
	state.purchaseLocks = {}
	setClaimDisplay(plot, state, nil)
	bindPurchaseButtons(plot, state)
end

local function positionCharacterAtOwnedSpawn(player, character)
	task.spawn(function()
		local rootPart = character:WaitForChild("HumanoidRootPart", 10)
		if not rootPart or player.Character ~= character then
			return
		end

		local plot = playerToTycoon[player]
		local state = plot and plotStates[plot]
		local spawn = plot and plot:FindFirstChild("Spawn")
		if state and state.owner == player and spawn and spawn:IsA("BasePart") then
			character:PivotTo(spawn.CFrame * CFrame.new(0, 4, 0))
		end
	end)
end

local function onPlayerAdded(player)
	if characterConnections[player] then
		characterConnections[player]:Disconnect()
	end
	characterConnections[player] = player.CharacterAdded:Connect(function(character)
		positionCharacterAtOwnedSpawn(player, character)
	end)
	if player.Character then
		positionCharacterAtOwnedSpawn(player, player.Character)
	end
end

function TycoonService.Initialize()
	for plotName, offset in pairs(Config.PlotOffsets) do
		createPlot(plotName, offset)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		local plot = playerToTycoon[player]
		local state = plot and plotStates[plot]
		if plot and state and state.owner == player then
			resetPlot(plot, state)
		end
		playerToTycoon[player] = nil
		if characterConnections[player] then
			characterConnections[player]:Disconnect()
			characterConnections[player] = nil
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
end

return TycoonService
