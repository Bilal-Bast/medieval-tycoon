local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.Config)
local TycoonService = {}

local tycoonsFolder = Workspace:WaitForChild("Tycoons")
local moneyBlocksFolder = Workspace:FindFirstChild("MoneyBlocks") or Instance.new("Folder")
moneyBlocksFolder.Name = "MoneyBlocks"
moneyBlocksFolder.Parent = Workspace

local plotStates = {}
local playerToTycoon = {}
local characterConnections = {}
local schedulerStarted = false
local initialized = false

local function validateProgressionConfig()
	assert(Config.MaxVisiblePurchasePads >= 1 and Config.MaxVisiblePurchasePads <= 3,
		"Visible purchase pad count must stay between one and three")
	local visited = {}
	for _, upgradeId in ipairs(Config.UpgradeOrder) do
		local upgrade = Config.Upgrades[upgradeId]
		assert(upgrade and upgrade.Id == upgradeId, "Missing configured upgrade: " .. upgradeId)
		assert(not visited[upgradeId], "Duplicate upgrade in progression: " .. upgradeId)
		assert(type(upgrade.Cost) == "number" and upgrade.Cost > 0, "Invalid upgrade cost: " .. upgradeId)
		assert(typeof(upgrade.PurchasePosition) == "Vector3", "Missing purchase pad location: " .. upgradeId)
		for _, prerequisite in ipairs(upgrade.Prerequisites) do
			assert(visited[prerequisite], "Prerequisite must appear earlier: " .. upgradeId .. " -> " .. prerequisite)
		end
		if upgrade.Category == "Production" then
			assert(Config.Districts[upgrade.District], "Unknown production district: " .. upgradeId)
			assert(upgrade.IncomePerDrop > 0 and upgrade.DropInterval > 0, "Invalid production values: " .. upgradeId)
			local asset = ServerStorage:FindFirstChild(upgrade.AssetName)
			assert(asset and asset:IsA("Model") and asset:FindFirstChild("DropPoint", true), "Missing production model/drop point: " .. upgradeId)
		elseif upgrade.Category == "Structure" then
			assert(Config.StructuralGroups[upgrade.VisualGroup], "Unknown structural group: " .. upgradeId)
			local asset = ServerStorage:FindFirstChild(upgrade.AssetName)
			assert(asset and asset:IsA("Model"), "Missing structural model: " .. upgradeId)
		end
		visited[upgradeId] = true
	end
	for upgradeId in pairs(Config.Upgrades) do
		assert(visited[upgradeId], "Upgrade missing from configured order: " .. upgradeId)
	end
end

local function getCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	return cash and cash:IsA("IntValue") and cash or nil
end

local function getPlayerFromHit(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	return character and Players:GetPlayerFromCharacter(character) or nil
end

local function getClaimLabel(plot)
	local pad = plot:FindFirstChild("ClaimPad")
	local billboard = pad and pad:FindFirstChildOfClass("BillboardGui")
	return billboard and billboard:FindFirstChildWhichIsA("TextLabel", true)
end

local function setClaimDisplay(plot, state, player)
	local banner = plot:FindFirstChild("ClaimBanner", true) or plot:FindFirstChild("KingdomStandardCloth", true)
	if banner and banner:IsA("BasePart") then
		banner.Color = player and Color3.fromRGB(83, 119, 75) or Color3.fromRGB(143, 64, 46)
	end
	local label = getClaimLabel(plot)
	local pad = plot:FindFirstChild("ClaimPad")
	local billboard = pad and pad:FindFirstChildOfClass("BillboardGui")
	if not label then
		return
	end
	if player then
		label.Text = string.format('<font size="18"><b>%s\'s</b></font>\n<font size="14">Kingdom</font>', player.Name)
		label.BackgroundTransparency = 0.3
		if billboard then billboard.MaxDistance = 42 end
	else
		label.Text = state.unclaimedText
		label.BackgroundTransparency = 0.12
		if billboard then billboard.MaxDistance = 55 end
	end
end

local function createDistrictLabels(plot)
	for _, signage in pairs(Config.DistrictSignage) do
		local board = plot:FindFirstChild(signage.BoardName, true)
		if board and board:IsA("BasePart") and not board:FindFirstChild("DistrictSurfaceGui") then
			local surface = Instance.new("SurfaceGui")
			surface.Name = "DistrictSurfaceGui"
			surface.Face = Enum.NormalId.Front
			surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			surface.PixelsPerStud = 34
			surface.MaxDistance = 38
			surface.LightInfluence = 0.25
			surface.Adornee = board
			surface.Parent = board

			local label = Instance.new("TextLabel")
			label.Name = "DistrictName"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundColor3 = Color3.fromRGB(61, 39, 24)
			label.BackgroundTransparency = 0.12
			label.BorderSizePixel = 0
			label.Font = Enum.Font.GothamBold
			label.Text = signage.Text
			label.TextColor3 = Color3.fromRGB(242, 218, 166)
			label.TextScaled = true
			label.TextStrokeColor3 = Color3.fromRGB(37, 27, 20)
			label.TextStrokeTransparency = 0.45
			label.TextWrapped = true
			label.Parent = surface
		end
	end
end

local function formatCurrency(amount)
	local reversed = tostring(math.floor(amount)):reverse()
	return (reversed:gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function getUpgradeCost(upgrade)
	local multiplier = Config.DevelopmentFastProgression and Config.DevelopmentCostMultiplier or 1
	return math.max(1, math.floor(upgrade.Cost * multiplier + 0.5))
end

local function getUpgradeIncome(upgrade)
	local multiplier = Config.DevelopmentFastProgression and Config.DevelopmentIncomeMultiplier or 1
	return math.max(1, math.floor(upgrade.IncomePerDrop * multiplier + 0.5))
end

local function getUpgradeInterval(upgrade)
	local multiplier = Config.DevelopmentFastProgression and Config.DevelopmentDropIntervalMultiplier or 1
	return math.max(0.25, upgrade.DropInterval * multiplier)
end

local function prerequisitesMet(state, upgrade)
	for _, prerequisite in ipairs(upgrade.Prerequisites) do
		if state.purchased[prerequisite] ~= true then
			return false
		end
	end
	return true
end

local function getAvailableUpgrades(state)
	local available = {}
	for _, upgradeId in ipairs(Config.UpgradeOrder) do
		local upgrade = Config.Upgrades[upgradeId]
		if not state.purchased[upgradeId] and prerequisitesMet(state, upgrade) then
			table.insert(available, upgrade)
		end
	end
	return available
end

local onPurchaseTouched

local function clearPurchasePads(state)
	for _, record in pairs(state.purchasePads) do
		if record.connection then record.connection:Disconnect() end
		local instance = record.model or record.button
		if instance and instance.Parent then instance:Destroy() end
	end
	table.clear(state.purchasePads)
end

local function makePadDisk(parent, name, diameter, thickness, color, material, padFrame, heightOffset, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(thickness, diameter, diameter)
	part.CFrame = padFrame * CFrame.new(0, heightOffset, 0) * CFrame.Angles(0, 0, math.rad(90))
	part.Anchored = true
	part.CanCollide = canCollide
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = material
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function getPadTitle(upgrade)
	local labels = { Walls = "WALLS", Towers = "TOWERS", Castle = "CASTLE" }
	local group = upgrade.Category == "Production" and upgrade.District or upgrade.VisualGroup
	local level = ({ "I", "II", "III", "IV" })[upgrade.Level]
	return string.format("BUILD %s %s", labels[group] or string.upper(group), level)
end

local function createPurchasePad(plot, state, upgrade, buttonTemplate)
	local style = Config.PurchasePad
	local padFrame = state.plotFrame * CFrame.new(upgrade.PurchasePosition)
	local model = Instance.new("Model")
	model.Name = "PurchasePad_" .. upgrade.Id
	model:SetAttribute("UpgradeId", upgrade.Id)
	model:SetAttribute("OwnerUserId", state.owner.UserId)
	model:SetAttribute("TycoonId", plot.Name)
	model.Parent = plot

	makePadDisk(model, "StoneFoundation", style.FoundationDiameter, style.FoundationThickness,
		Color3.fromRGB(76, 78, 75), Enum.Material.Slate, padFrame, 0.15, false)
	makePadDisk(model, "BronzeRim", style.RimDiameter, style.RimThickness,
		Color3.fromRGB(145, 103, 47), Enum.Material.Metal, padFrame, 0.35, false)

	local button = buttonTemplate:Clone()
	button.Name = "TouchSurface"
	button:SetAttribute("UpgradeId", upgrade.Id)
	button:SetAttribute("OwnerUserId", state.owner.UserId)
	button:SetAttribute("TycoonId", plot.Name)
	button.Shape = Enum.PartType.Cylinder
	button.Size = Vector3.new(style.TouchThickness, style.TouchDiameter, style.TouchDiameter)
	button.CFrame = padFrame * CFrame.new(0, 0.46, 0) * CFrame.Angles(0, 0, math.rad(90))
	button.Anchored = true
	button.CanCollide = true
	button.CanTouch = true
	button.CanQuery = false
	button.CastShadow = false
	button.Material = Enum.Material.Metal
	button.Color = Color3.fromRGB(201, 154, 64)
	button.Reflectance = 0.04
	button.Transparency = 0
	button.TopSurface = Enum.SurfaceType.Smooth
	button.BottomSurface = Enum.SurfaceType.Smooth
	button.Parent = model

	local markerAnchor = Instance.new("Part")
	markerAnchor.Name = "MarkerAnchor"
	markerAnchor.Size = Vector3.new(style.MarkerDiameter, style.MarkerDiameter, style.MarkerDiameter)
	markerAnchor.CFrame = padFrame * CFrame.new(style.MarkerOffset.X, 0.52, style.MarkerOffset.Z)
	markerAnchor.Anchored = true
	markerAnchor.Transparency = 1
	markerAnchor.CanCollide = false
	markerAnchor.CanTouch = false
	markerAnchor.CanQuery = false
	markerAnchor.CastShadow = false
	markerAnchor.Parent = model

	local marker = Instance.new("BillboardGui")
	marker.Name = "AvailabilityMarker"
	marker.Adornee = markerAnchor
	marker.MaxDistance = style.MarkerMaxDistance
	marker.Size = UDim2.new(1, 0, style.MarkerHeight / style.MarkerDiameter, 0)
	marker.StudsOffsetWorldSpace = Vector3.new(0, style.MarkerHeight / 2, 0)
	marker.AlwaysOnTop = false
	marker.LightInfluence = 0.15
	marker.Parent = markerAnchor

	local beam = Instance.new("Frame")
	beam.Name = "GoldBeam"
	beam.Size = UDim2.fromScale(1, 1)
	beam.BackgroundColor3 = Color3.fromRGB(232, 178, 79)
	beam.BackgroundTransparency = 0.48
	beam.BorderSizePixel = 0
	beam.Parent = marker

	local billboard = button:FindFirstChildOfClass("BillboardGui")
	local label = billboard and billboard:FindFirstChildWhichIsA("TextLabel", true)
	if billboard then
		billboard.MaxDistance = Config.PurchaseBillboardMaxDistance
		billboard.Size = style.BillboardSize
		billboard.StudsOffset = Vector3.zero
		billboard.StudsOffsetWorldSpace = style.BillboardWorldOffset
		billboard.AlwaysOnTop = false
		billboard.LightInfluence = 0.25
	end
	if label then
		label.RichText = true
		label.TextWrapped = true
		label.TextScaled = false
		label.TextSize = 15
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Text = string.format('<font size="15"><b>%s</b></font>\n<font size="13">$%s</font>', getPadTitle(upgrade), formatCurrency(getUpgradeCost(upgrade)))
	end

	local record = { button = button, model = model }
	record.connection = button.Touched:Connect(function(hit)
		onPurchaseTouched(plot, state, upgrade.Id, button, hit)
	end)
	return record
end

local function refreshPurchasePads(plot, state)
	local desired = {}
	if state.active and state.owner then
		for index, upgrade in ipairs(getAvailableUpgrades(state)) do
			if index > Config.MaxVisiblePurchasePads then break end
			desired[upgrade.Id] = upgrade
		end
	end

	for upgradeId, record in pairs(state.purchasePads) do
		if not desired[upgradeId] or not record.model or record.model.Parent ~= plot then
			if record.connection then record.connection:Disconnect() end
			local instance = record.model or record.button
			if instance and instance.Parent then instance:Destroy() end
			state.purchasePads[upgradeId] = nil
		end
	end
	if not state.active or not state.owner then return end

	local template = ServerStorage:FindFirstChild("TycoonTemplate")
	local buttonTemplate = template and template:FindFirstChild("BuyDropperButton")
	if not buttonTemplate or not buttonTemplate:IsA("BasePart") then
		warn("Missing ServerStorage/TycoonTemplate/BuyDropperButton")
		return
	end

	for upgradeId, upgrade in pairs(desired) do
		if not state.purchasePads[upgradeId] then
			state.purchasePads[upgradeId] = createPurchasePad(plot, state, upgrade, buttonTemplate)
		end
	end
end

local function stripEmbeddedScripts(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		end
	end
end

local function scheduleBuildReveal(model)
	local records = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local targetCFrame = descendant.CFrame
			table.insert(records, {
				part = descendant,
				cframe = targetCFrame,
				transparency = descendant.Transparency,
				canCollide = descendant.CanCollide,
			})
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CFrame = targetCFrame + Vector3.new(0, 2, 0)
			descendant.Transparency = 1
		end
	end
	local tweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, record in ipairs(records) do
		if record.part.Parent then
			TweenService:Create(record.part, tweenInfo, {
				CFrame = record.cframe,
				Transparency = record.transparency,
			}):Play()
		end
	end
	task.delay(0.5, function()
		for _, record in ipairs(records) do
			if record.part.Parent then record.part.CanCollide = record.canCollide end
		end
	end)
end

local function createMoneyBlock(plot, state, upgrade, dropPoint)
	local player = state.owner
	if not plot.Parent or not player or not player.Parent or not dropPoint.Parent then
		return
	end
	local block = Instance.new("Part")
	block.Name = "MoneyBlock"
	block.Size = upgrade.ResourceSize or Config.MoneyBlockSize
	block.Material = upgrade.ResourceMaterial or Config.MoneyBlockMaterial
	block.Color = upgrade.ResourceColor or Config.MoneyBlockColor
	block.Anchored = false
	block.CanCollide = true
	block.CFrame = dropPoint.CFrame
	block:SetAttribute("CashValue", getUpgradeIncome(upgrade))
	block:SetAttribute("UpgradeId", upgrade.Id)
	block:SetAttribute("DistrictId", upgrade.District)
	block:SetAttribute("OwnerUserId", player.UserId)
	block:SetAttribute("TycoonId", plot.Name)
	block.Parent = moneyBlocksFolder
	pcall(function() block:SetNetworkOwner(nil) end)
	Debris:AddItem(block, Config.MoneyBlockLifetime)
end

local function getUpgradeAsset(upgrade)
	local asset = ServerStorage:FindFirstChild(upgrade.AssetName)
	return asset and asset:IsA("Model") and asset or nil
end

onPurchaseTouched = function(plot, state, upgradeId, button, hit)
	local upgrade = Config.Upgrades[upgradeId]
	if not upgrade or state.purchaseLocks[upgradeId] then return end
	state.purchaseLocks[upgradeId] = true

	local player = getPlayerFromHit(hit)
	local ownerValue = plot:FindFirstChild("Owner")
	local cash = player and getCash(player)
	local ownsPlot = player ~= nil
		and playerToTycoon[player] == plot
		and state.owner == player
		and ownerValue ~= nil
		and ownerValue:IsA("ObjectValue")
		and ownerValue.Value == player
	local padRecord = state.purchasePads[upgradeId]
	local padIsCurrent = padRecord ~= nil
		and padRecord.button == button
		and padRecord.model ~= nil
		and padRecord.model.Parent == plot
		and button:IsDescendantOf(padRecord.model)
	local asset = getUpgradeAsset(upgrade)
	local dropPoint = upgrade.Category == "Production" and asset and asset:FindFirstChild("DropPoint", true) or nil
	local valid = state.active
		and ownsPlot
		and padIsCurrent
		and not state.purchased[upgradeId]
		and prerequisitesMet(state, upgrade)
		and cash ~= nil
		and cash.Value >= getUpgradeCost(upgrade)
		and asset ~= nil
		and (upgrade.Category ~= "Production" or (dropPoint and dropPoint:IsA("BasePart")))
	if not valid then
		state.purchaseLocks[upgradeId] = nil
		return
	end

	local building = asset:Clone()
	stripEmbeddedScripts(building)
	building:PivotTo(state.plotFrame)
	building.Name = upgrade.AssetName
	building:SetAttribute("UpgradeId", upgradeId)
	building:SetAttribute("OwnerUserId", player.UserId)
	building:SetAttribute("TycoonId", plot.Name)
	building:SetAttribute("DistrictId", upgrade.District)
	if upgrade.Category == "Structure" then
		local previous = state.structureInstances[upgrade.VisualGroup]
		if previous then
			local previousId = previous:GetAttribute("UpgradeId")
			if previousId then state.upgradeInstances[previousId] = nil end
			previous:Destroy()
		end
		state.structureInstances[upgrade.VisualGroup] = building
	end
	building.Parent = plot

	-- All validation and the debit happen before any yielding work, so concurrent
	-- touches cannot buy one upgrade twice or spend the same balance twice.
	cash.Value -= getUpgradeCost(upgrade)
	state.purchased[upgradeId] = true
	state.upgradeInstances[upgradeId] = building
	state.purchaseLocks[upgradeId] = nil
	if upgrade.Category == "Production" then
		state.nextProductionAt[upgradeId] = os.clock() + getUpgradeInterval(upgrade)
	end
	if padRecord.connection then padRecord.connection:Disconnect() end
	if padRecord.model.Parent then padRecord.model:Destroy() end
	state.purchasePads[upgradeId] = nil
	refreshPurchasePads(plot, state)
	scheduleBuildReveal(building)
end

local function clearTycoonMoney(plot)
	for _, block in ipairs(moneyBlocksFolder:GetChildren()) do
		if block:GetAttribute("TycoonId") == plot.Name then block:Destroy() end
	end
end

local function resetPlot(plot, state)
	local previousOwner = state.owner
	state.active = false
	if previousOwner and playerToTycoon[previousOwner] == plot then playerToTycoon[previousOwner] = nil end
	clearPurchasePads(state)
	clearTycoonMoney(plot)
	for _, instance in pairs(state.upgradeInstances) do
		if instance.Parent then instance:Destroy() end
	end
	local ownerValue = plot:FindFirstChild("Owner")
	if ownerValue and ownerValue:IsA("ObjectValue") then ownerValue.Value = nil end
	state.owner = nil
	state.purchased = {}
	state.upgradeInstances = {}
	state.structureInstances = {}
	state.nextProductionAt = {}
	state.purchaseLocks = {}
	state.active = true
	setClaimDisplay(plot, state, nil)
	refreshPurchasePads(plot, state)
end

local function connectDistrictCollectorsAndConveyors(plot, state)
	for _, descendant in ipairs(plot:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local collectorDistrict = descendant.Name:match("^Collector_(%w+)$")
			if collectorDistrict and Config.Districts[collectorDistrict] then
				local district = collectorDistrict
				descendant.Touched:Connect(function(hit)
					if not hit:IsA("BasePart") or hit.Name ~= "MoneyBlock"
						or hit:GetAttribute("TycoonId") ~= plot.Name
						or hit:GetAttribute("DistrictId") ~= district
						or hit:GetAttribute("Collected") == true
					then
						return
					end
					hit:SetAttribute("Collected", true)
					local ownerUserId = hit:GetAttribute("OwnerUserId")
					local player = typeof(ownerUserId) == "number" and Players:GetPlayerByUserId(ownerUserId) or nil
					local ownerValue = plot:FindFirstChild("Owner")
					local upgradeId = hit:GetAttribute("UpgradeId")
					local upgrade = typeof(upgradeId) == "string" and Config.Upgrades[upgradeId] or nil
					local valid = state.active
						and player ~= nil
						and state.owner == player
						and playerToTycoon[player] == plot
						and ownerValue ~= nil
						and ownerValue:IsA("ObjectValue")
						and ownerValue.Value == player
						and hit:GetAttribute("OwnerUserId") == player.UserId
						and upgrade ~= nil
						and upgrade.Category == "Production"
						and upgrade.District == district
						and state.purchased[upgradeId] == true
					if valid then
						local cash = getCash(player)
						if cash then cash.Value += getUpgradeIncome(upgrade) end
						hit:Destroy()
					elseif hit:GetAttribute("OwnerUserId") == (state.owner and state.owner.UserId or -1) then
						-- Stale resources from a reset or a removed producer are discarded.
						hit:Destroy()
					end
				end)
			end

			local conveyorDistrict = descendant.Name:match("^Conveyor_(%w+)$")
			if conveyorDistrict and Config.Districts[conveyorDistrict] then
				local district = conveyorDistrict
				local conveyor = descendant
				conveyor.Touched:Connect(function(hit)
					if not hit:IsA("BasePart") or hit.Name ~= "MoneyBlock"
						or hit:GetAttribute("TycoonId") ~= plot.Name
						or hit:GetAttribute("DistrictId") ~= district
						or hit:GetAttribute("OwnerUserId") ~= (state.owner and state.owner.UserId or -1)
					then
						return
					end
					local upgradeId = hit:GetAttribute("UpgradeId")
					local upgrade = typeof(upgradeId) == "string" and Config.Upgrades[upgradeId] or nil
					if state.active and upgrade and upgrade.District == district and state.purchased[upgradeId] then
						hit.AssemblyLinearVelocity = conveyor.CFrame.LookVector * Config.ConveyorSpeed
					end
				end)
			end
		end
	end
end

local function createPlot(plotName, offset, rotation)
	local plot = tycoonsFolder:FindFirstChild(plotName)
	if not plot or not plot:IsA("Folder") then
		warn("Missing Workspace/Tycoons plot folder: " .. plotName)
		return nil
	end
	local plotFrame = CFrame.new(offset) * CFrame.Angles(0, math.rad(rotation), 0)
	local spawn = plot:FindFirstChild("Spawn")
	if spawn and spawn:IsA("SpawnLocation") then spawn.Enabled = false end
	local ownerValue = plot:FindFirstChild("Owner")
	if ownerValue and ownerValue:IsA("ObjectValue") then ownerValue.Value = nil end
	for _, oldPadName in ipairs({ "BuyDropperButton", "BuyDropper2Button", "UpgradePurchaseButton" }) do
		local oldPad = plot:FindFirstChild(oldPadName)
		if oldPad then oldPad:Destroy() end
	end
	for _, child in ipairs(plot:GetChildren()) do
		if (child:IsA("Model") and child.Name:match("^PurchasePad_"))
			or (child:IsA("BasePart") and child.Name:match("^Purchase_"))
		then
			child:Destroy()
		end
	end
	local claimLabel = getClaimLabel(plot)
	createDistrictLabels(plot)
	local state = {
		owner = nil,
		active = true,
		plotFrame = plotFrame,
		purchased = {},
		upgradeInstances = {},
		structureInstances = {},
		nextProductionAt = {},
		purchaseLocks = {},
		purchasePads = {},
		unclaimedText = claimLabel and claimLabel.Text or "CLAIM KINGDOM\nTOUCH TO CLAIM",
	}
	plotStates[plot] = state

	local claimPad = plot:FindFirstChild("ClaimPad")
	if claimPad and claimPad:IsA("BasePart") then
		claimPad.Touched:Connect(function(hit)
			local player = getPlayerFromHit(hit)
			local currentOwner = plot:FindFirstChild("Owner")
			if not player or not currentOwner or not currentOwner:IsA("ObjectValue")
				or currentOwner.Value ~= nil or state.owner ~= nil or playerToTycoon[player] ~= nil
			then
				return
			end
			state.owner = player
			playerToTycoon[player] = plot
			currentOwner.Value = player
			setClaimDisplay(plot, state, player)
			refreshPurchasePads(plot, state)
		end)
	else
		warn("Tycoon is missing ClaimPad: " .. plot.Name)
	end
	setClaimDisplay(plot, state, nil)
	connectDistrictCollectorsAndConveyors(plot, state)
	return plot
end

local function emitProduction(plot, state, upgradeId)
	local upgrade = Config.Upgrades[upgradeId]
	local building = state.upgradeInstances[upgradeId]
	local dropPoint = building and building:FindFirstChild("DropPoint", true)
	if upgrade and state.purchased[upgradeId] and state.active and dropPoint and dropPoint:IsA("BasePart") then
		createMoneyBlock(plot, state, upgrade, dropPoint)
	end
end

local function startProductionScheduler()
	if schedulerStarted then return end
	schedulerStarted = true
	task.spawn(function()
		while true do
			task.wait(Config.ProductionSchedulerInterval)
			local now = os.clock()
			for plot, state in pairs(plotStates) do
				if state.active and state.owner and state.owner.Parent then
					for _, upgradeId in ipairs(Config.UpgradeOrder) do
						local upgrade = Config.Upgrades[upgradeId]
						local nextAt = state.nextProductionAt[upgradeId]
						if upgrade.Category == "Production" and state.purchased[upgradeId] and nextAt and now >= nextAt then
							state.nextProductionAt[upgradeId] = now + getUpgradeInterval(upgrade)
							emitProduction(plot, state, upgradeId)
						end
					end
				end
			end
		end
	end)
end

local function positionCharacterAtOwnedSpawn(player, character)
	task.spawn(function()
		local rootPart = character:WaitForChild("HumanoidRootPart", 10)
		if not rootPart or player.Character ~= character then return end
		local plot = playerToTycoon[player]
		local state = plot and plotStates[plot]
		local spawn = plot and plot:FindFirstChild("Spawn")
		if state and state.owner == player and spawn and spawn:IsA("BasePart") then
			character:PivotTo(spawn.CFrame * CFrame.new(0, 4, 0))
		end
	end)
end

local function onPlayerAdded(player)
	if characterConnections[player] then characterConnections[player]:Disconnect() end
	characterConnections[player] = player.CharacterAdded:Connect(function(character)
		positionCharacterAtOwnedSpawn(player, character)
	end)
	if player.Character then positionCharacterAtOwnedSpawn(player, player.Character) end
end

function TycoonService.Initialize()
	if initialized then return end
	initialized = true
	validateProgressionConfig()
	for plotName, offset in pairs(Config.PlotOffsets) do
		createPlot(plotName, offset, Config.PlotRotations[plotName] or 0)
	end
	startProductionScheduler()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		local plot = playerToTycoon[player]
		local state = plot and plotStates[plot]
		if plot and state and state.owner == player then resetPlot(plot, state) end
		playerToTycoon[player] = nil
		if characterConnections[player] then
			characterConnections[player]:Disconnect()
			characterConnections[player] = nil
		end
	end)
	for _, player in ipairs(Players:GetPlayers()) do onPlayerAdded(player) end
end

return TycoonService
