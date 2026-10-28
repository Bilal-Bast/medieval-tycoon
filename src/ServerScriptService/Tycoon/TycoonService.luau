local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.Config)
local KingdomNPCService = require(script.Parent.KingdomNPCService)
local WeaponService = require(script.Parent.WeaponService)
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
			local corridor = Config.ProductionCorridors[upgrade.District]
			assert(corridor, "Missing production corridor: " .. upgrade.District)
			local dropPoints = {}
			for _, descendant in ipairs(asset:GetDescendants()) do
				if descendant.Name == "DropPoint" and descendant:IsA("BasePart") then table.insert(dropPoints, descendant) end
			end
			assert(#dropPoints == 1, "Each production snapshot must contain one active DropPoint: " .. upgradeId)
			local point = dropPoints[1].Position
			assert(math.abs(point.X - corridor.DropXs[upgrade.Level]) < 0.05
				and math.abs(point.Y - corridor.DropY) < 0.05
				and math.abs(point.Z - corridor.LaneCenter.Z) < 0.05,
				"Producer is not aligned above its reserved transport lane: " .. upgradeId)
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

local function formatCurrency(amount)
	local reversed = tostring(math.floor(amount)):reverse()
	return (reversed:gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function getClaimLabel(plot)
	local pad = plot:FindFirstChild("ClaimPad")
	local billboard = pad and pad:FindFirstChildOfClass("BillboardGui")
	return billboard and billboard:FindFirstChild("ClaimStatus", true)
end

local function makeBillboardText(parent, name, position, size, text, font, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = font
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextWrapped = false
	label.Parent = parent
	return label
end

local function createPurchaseBillboard(button, upgrade, cost, style)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PurchaseBillboard"
	billboard.Adornee = button
	billboard.Size = style.BillboardSize
	billboard.StudsOffset = Vector3.zero
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = Config.PurchaseBillboardMaxDistance
	billboard.Parent = button

	local panel = Instance.new("Frame")
	panel.Name = "Card"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(34, 27, 21)
	panel.BackgroundTransparency = 0.035
	panel.BorderSizePixel = 0
	panel.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(191, 145, 56)
	outline.Thickness = 1.8
	outline.Transparency = 0.04
	outline.Parent = panel

	local action = upgrade.Level == 1 and "NEW ROYAL PROJECT" or "KINGDOM UPGRADE"
	local level = ({ "I", "II", "III", "IV" })[upgrade.Level] or tostring(upgrade.Level)
	makeBillboardText(panel, "Action", UDim2.fromScale(0.04, 0.04), UDim2.new(0.92, 0, 0.22, 0),
		action, Enum.Font.GothamBold, 12, Color3.fromRGB(226, 183, 91))
	makeBillboardText(panel, "UpgradeName", UDim2.fromScale(0.04, 0.27), UDim2.new(0.92, 0, 0.38, 0),
		upgrade.DisplayName, Enum.Font.Garamond, 23, Color3.fromRGB(255, 245, 219))
	makeBillboardText(panel, "Price", UDim2.fromScale(0.04, 0.68), UDim2.new(0.92, 0, 0.26, 0),
		string.format("LEVEL %s   •   %s GOLD", level, formatCurrency(cost)),
		Enum.Font.GothamBold, 14, Color3.fromRGB(246, 211, 126))
end

local function prepareClaimBillboard(plot)
	local pad = plot:FindFirstChild("ClaimPad")
	local billboard = pad and pad:FindFirstChildOfClass("BillboardGui")
	if not billboard then return end

	billboard.Name = "KingdomClaimBillboard"
	billboard.Adornee = pad
	billboard.Size = UDim2.fromOffset(260, 102)
	billboard.StudsOffset = Vector3.zero
	billboard.StudsOffsetWorldSpace = Vector3.zero
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 100
	billboard.ClipsDescendants = false
	for _, child in ipairs(billboard:GetChildren()) do child:Destroy() end

	local index = tonumber(plot.Name:match("(%d+)$")) or 0
	local accent = Config.RealmColors[plot.Name] or Color3.fromRGB(184, 145, 78)
	local panel = Instance.new("Frame")
	panel.Name = "Plaque"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(35, 27, 21)
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = panel
	local outline = Instance.new("UIStroke")
	outline.Color = accent
	outline.Thickness = 2
	outline.Transparency = 0.08
	outline.Parent = panel
	local inset = Instance.new("UIPadding")
	inset.PaddingTop = UDim.new(0, 6)
	inset.PaddingBottom = UDim.new(0, 5)
	inset.PaddingLeft = UDim.new(0, 12)
	inset.PaddingRight = UDim.new(0, 12)
	inset.Parent = panel
	makeBillboardText(panel, "RealmNumber", UDim2.fromScale(0, 0), UDim2.new(1, 0, 0.22, 0),
		string.format("✦  REALM %02d  ✦", index), Enum.Font.GothamBold, 13, accent)
	makeBillboardText(panel, "ClaimStatus", UDim2.new(0, 0, 0.24, 0), UDim2.new(1, 0, 0.43, 0),
		"UNCLAIMED KINGDOM", Enum.Font.Garamond, 25, Color3.fromRGB(250, 239, 211))
	makeBillboardText(panel, "ClaimPrompt", UDim2.new(0, 0, 0.70, 0), UDim2.new(1, 0, 0.24, 0),
		"TOUCH SEAL TO CLAIM", Enum.Font.GothamMedium, 13, Color3.fromRGB(227, 209, 174))
end

local function setClaimDisplay(plot, state, player)
	local banner = plot:FindFirstChild("ClaimBanner", true)
		or plot:FindFirstChild("KingdomStandardCloth", true)
		or plot:FindFirstChild("RealmBannerCloth", true)
	if banner and banner:IsA("BasePart") then
		banner.Color = Config.RealmColors[plot.Name] or Color3.fromRGB(184, 74, 54)
	end
	local label = getClaimLabel(plot)
	local pad = plot:FindFirstChild("ClaimPad")
	local billboard = pad and pad:FindFirstChildOfClass("BillboardGui")
	if not label then
		return
	end
	local prompt = billboard and billboard:FindFirstChild("ClaimPrompt", true)
	if player then
		label.Text = player.DisplayName .. "'s Kingdom"
		if prompt then prompt.Text = "CLAIMED BY " .. string.upper(player.DisplayName) end
	else
		label.Text = "UNCLAIMED KINGDOM"
		if prompt then prompt.Text = "TOUCH SEAL TO CLAIM" end
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
			surface.LightInfluence = 0
			surface.Adornee = board
			surface.Parent = board

			local label = Instance.new("TextLabel")
			label.Name = "DistrictName"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundColor3 = Color3.fromRGB(39, 29, 21)
			label.BackgroundTransparency = 0.04
			label.BorderSizePixel = 0
			label.Font = Enum.Font.Garamond
			label.Text = signage.Text
			label.TextColor3 = Color3.fromRGB(250, 229, 181)
			label.TextScaled = true
			label.TextStrokeColor3 = Color3.fromRGB(20, 15, 11)
			label.TextStrokeTransparency = 0.2
			label.TextWrapped = true
			label.Parent = surface
			local outline = Instance.new("UIStroke")
			outline.Color = Color3.fromRGB(177, 132, 61)
			outline.Thickness = 1.2
			outline.Transparency = 0.12
			outline.Parent = label
			local inset = Instance.new("UIPadding")
			inset.PaddingLeft = UDim.new(0, 8)
			inset.PaddingRight = UDim.new(0, 8)
			inset.PaddingTop = UDim.new(0, 2)
			inset.PaddingBottom = UDim.new(0, 2)
			inset.Parent = label
		end
	end
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
		Color3.fromRGB(145, 103, 47), Enum.Material.Neon, padFrame, 0.35, false)

	local button = buttonTemplate:Clone()
	button.Name = "TouchSurface"
	button:SetAttribute("UpgradeId", upgrade.Id)
	button:SetAttribute("OwnerUserId", state.owner.UserId)
	button:SetAttribute("TycoonId", plot.Name)
	button.Shape = Enum.PartType.Cylinder
	button.Size = Vector3.new(style.TouchThickness, style.TouchDiameter, style.TouchDiameter)
	button.CFrame = padFrame * CFrame.new(0, 0.47, 0) * CFrame.Angles(0, 0, math.rad(90))
	button.Anchored = true
	button.CanCollide = true
	button.CanTouch = true
	button.CanQuery = false
	button.CastShadow = false
	button.Material = Enum.Material.Neon
	button.Color = Color3.fromRGB(229, 166, 63)
	button.Reflectance = 0
	button.Transparency = 0
	button.TopSurface = Enum.SurfaceType.Smooth
	button.BottomSurface = Enum.SurfaceType.Smooth
	button.Parent = model
	local pulse = TweenService:Create(button, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Transparency = 0.28,
	})
	pulse:Play()

	local light = Instance.new("PointLight")
	light.Name = "RuneGlow"
	light.Color = Color3.fromRGB(255, 176, 72)
	light.Brightness = 0.95
	light.Range = 9
	light.Parent = button
	local lightPulse = TweenService:Create(light, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Brightness = 1.8,
		Range = 13,
	})
	lightPulse:Play()

	local billboard = button:FindFirstChildOfClass("BillboardGui")
	if billboard then billboard:Destroy() end
	createPurchaseBillboard(button, upgrade, getUpgradeCost(upgrade), style)

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
	local nextUpgrade = getAvailableUpgrades(state)[1]
	local targetPad = nextUpgrade and state.purchasePads[nextUpgrade.Id]
	state.owner:SetAttribute("NextUpgradeId", nextUpgrade and nextUpgrade.Id or nil)
	state.owner:SetAttribute("NextUpgradeName", nextUpgrade and nextUpgrade.DisplayName or nil)
	state.owner:SetAttribute("NextUpgradeCost", nextUpgrade and getUpgradeCost(nextUpgrade) or nil)
	state.owner:SetAttribute("NextUpgradeTarget", targetPad and targetPad.button.Position or nil)
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
	block.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.08, 0, 1, 1)
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
		and player:GetAttribute("EconomyReady") == true
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
	if upgrade.Category == "Production" then
		-- Replace the district artwork with its current full version, while keeping
		-- each earlier producer's server-owned output anchor alive.
		for oldId, oldInstance in pairs(state.upgradeInstances) do
			local oldUpgrade = Config.Upgrades[oldId]
			if oldUpgrade and oldUpgrade.Category == "Production"
				and oldUpgrade.District == upgrade.District and oldInstance:IsA("Model")
			then
				local oldDropPoint = oldInstance:FindFirstChild("DropPoint", true)
				if oldDropPoint and oldDropPoint:IsA("BasePart") then
					oldDropPoint.Name = "ProductionNode_" .. oldId
					oldDropPoint.Parent = plot
					state.productionPoints[oldId] = oldDropPoint
					state.upgradeInstances[oldId] = oldDropPoint
				end
				oldInstance:Destroy()
			end
		end
	end
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
	KingdomNPCService.Reconcile(plot, state)
	if upgrade.Category == "Production" then
		state.nextProductionAt[upgradeId] = os.clock() + getUpgradeInterval(upgrade)
		state.productionPoints[upgradeId] = building:FindFirstChild("DropPoint", true)
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
	KingdomNPCService.Cleanup(plot, state)
	if previousOwner and playerToTycoon[previousOwner] == plot then
		playerToTycoon[previousOwner] = nil
		if previousOwner:GetAttribute("TycoonId") == plot.Name then previousOwner:SetAttribute("TycoonId", nil) end
	end
	WeaponService.SetArmoryOwner(state.armoryCards, nil)
	clearPurchasePads(state)
	clearTycoonMoney(plot)
	for _, key in ipairs({ "NextUpgradeId", "NextUpgradeName", "NextUpgradeCost", "NextUpgradeTarget" }) do
		if previousOwner then previousOwner:SetAttribute(key, nil) end
	end
	for _, instance in pairs(state.upgradeInstances) do
		if instance.Parent then instance:Destroy() end
	end
	local ownerValue = plot:FindFirstChild("Owner")
	if ownerValue and ownerValue:IsA("ObjectValue") then ownerValue.Value = nil end
	state.owner = nil
	state.purchased = {}
	state.upgradeInstances = {}
	state.productionPoints = {}
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
						if cash then
							local income = getUpgradeIncome(upgrade)
							if player:GetAttribute("OwnsPass_DoubleGold") == true then income *= 2 end
							cash.Value += income
						end
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
	for district, corridor in pairs(Config.ProductionCorridors) do
		local conveyor = plot:FindFirstChild("Conveyor_" .. district, true)
		local collector = plot:FindFirstChild("Collector_" .. district, true)
		assert(conveyor and conveyor:IsA("BasePart"), "Missing " .. district .. " conveyor: " .. plotName)
		assert(collector and collector:IsA("BasePart"), "Missing " .. district .. " collector: " .. plotName)
		assert((conveyor.Position - plotFrame:PointToWorldSpace(corridor.LaneCenter)).Magnitude < 0.3,
			district .. " conveyor is not at its configured local lane position: " .. plotName)
		assert(math.abs(conveyor.Size.X - corridor.LaneWidth) < 0.05
			and math.abs(conveyor.Size.Z - corridor.LaneLength) < 0.05,
			district .. " conveyor dimensions disagree with the shared corridor standard: " .. plotName)
		assert(conveyor.CFrame.LookVector:Dot(plotFrame.RightVector) > 0.99,
			district .. " conveyor points away from its collector: " .. plotName)
		assert((collector.Position - plotFrame:PointToWorldSpace(corridor.CollectorCenter)).Magnitude < 0.3
			and collector.CanTouch and not collector.CanCollide,
			district .. " collector is misplaced or cannot collect resources: " .. plotName)
		local laneEnd = corridor.LaneCenter + Vector3.new(corridor.LaneLength / 2, 0, 0)
		local collectorLocal = plotFrame:PointToObjectSpace(collector.Position)
		assert(math.abs(laneEnd.X - collectorLocal.X) <= corridor.CollectorSize.X / 2
			and math.abs(laneEnd.Z - collectorLocal.Z) <= corridor.CollectorSize.Z / 2,
			district .. " collector does not cover the end of its route: " .. plotName)
	end
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
	prepareClaimBillboard(plot)
	local claimLabel = getClaimLabel(plot)
	createDistrictLabels(plot)
	local state = {
		owner = nil,
		active = true,
		plotFrame = plotFrame,
		purchased = {},
		upgradeInstances = {},
		productionPoints = {},
		structureInstances = {},
		nextProductionAt = {},
		purchaseLocks = {},
		purchasePads = {},
	}
	plotStates[plot] = state
	state.armoryCards = WeaponService.CreateArmory(plot, plotFrame, function(player, weaponId)
		if not state.active or state.owner ~= player or playerToTycoon[player] ~= plot then
			return "NotYourKingdom"
		end
		return WeaponService.TryPurchase(player, weaponId, state)
	end)

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
			player:SetAttribute("TycoonId", plot.Name)
			currentOwner.Value = player
			WeaponService.SetArmoryOwner(state.armoryCards, player)
			setClaimDisplay(plot, state, player)
			KingdomNPCService.Reconcile(plot, state)
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
	local dropPoint = state.productionPoints[upgradeId]
	if upgrade and state.purchased[upgradeId] and state.active and dropPoint and dropPoint:IsA("BasePart") then
		createMoneyBlock(plot, state, upgrade, dropPoint)
	end
end

local function transportProductionResources(plot, state)
	if not state.owner or not state.owner.Parent then return end
	for district, lane in pairs(Config.ProductionCorridors) do
		local conveyor = plot:FindFirstChild("Conveyor_" .. district, true)
		if conveyor and conveyor:IsA("BasePart") then
			local direction = conveyor.CFrame.LookVector
			local horizontalDirection = Vector3.new(direction.X, 0, direction.Z)
			if horizontalDirection.Magnitude > 0.9 then
				horizontalDirection = horizontalDirection.Unit
				for _, block in ipairs(moneyBlocksFolder:GetChildren()) do
					if block:IsA("BasePart") and block.Name == "MoneyBlock"
						and block:GetAttribute("DistrictId") == district
						and block:GetAttribute("TycoonId") == plot.Name
						and block:GetAttribute("OwnerUserId") == state.owner.UserId
					then
						local localPosition = conveyor.CFrame:PointToObjectSpace(block.Position)
						local halfWidth = lane.LaneWidth / 2 + block.Size.Z / 2
						local halfLength = lane.LaneLength / 2 + block.Size.X / 2
						local halfHeight = conveyor.Size.Y / 2 + block.Size.Y / 2 + 0.25
						if math.abs(localPosition.X) <= halfWidth and math.abs(localPosition.Z) <= halfLength
							and math.abs(localPosition.Y) <= halfHeight
						then
							local velocity = block.AssemblyLinearVelocity
							block.AssemblyLinearVelocity = horizontalDirection * Config.ConveyorSpeed + Vector3.new(0, velocity.Y, 0)
						end
					end
				end
			end
		end
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
					transportProductionResources(plot, state)
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
	KingdomNPCService.Initialize()
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
