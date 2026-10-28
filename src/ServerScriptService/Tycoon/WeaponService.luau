local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WeaponService = {}

WeaponService.Weapons = {
	KnightSword = {
		DisplayName = "Knight's Sword",
		Price = 350,
		Kind = "Melee",
		Damage = 26,
		Range = 7,
		Cooldown = 0.8,
		BladeColor = Color3.fromRGB(190, 199, 204),
		AccentColor = Color3.fromRGB(211, 166, 78),
		Description = "A reliable steel blade",
	},
	ForceLaser = {
		DisplayName = "Force Laser",
		Price = 1800,
		Kind = "Ranged",
		Damage = 20,
		Range = 150,
		Cooldown = 1.1,
		BladeColor = Color3.fromRGB(63, 215, 255),
		AccentColor = Color3.fromRGB(68, 155, 212),
		Knockback = 52,
		Description = "A long-range blast with a force pulse",
	},
	PlasmaSword = {
		DisplayName = "Plasma Sword",
		Price = 5000,
		Kind = "Melee",
		Damage = 38,
		Range = 7.5,
		Cooldown = 0.72,
		BladeColor = Color3.fromRGB(190, 80, 255),
		AccentColor = Color3.fromRGB(110, 62, 170),
		Description = "A powerful energized blade",
	},
}

local weaponOrder = { "KnightSword", "ForceLaser", "PlasmaSword" }
local initialized = false
local actionRemote
local noticeRemote
local lastUse = {}

local function makePart(parent, name, size, color, material, cframe, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CFrame = cframe
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function formatGold(amount)
	local text = tostring(math.floor(amount))
	while true do
		local updated, replacements = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		text = updated
		if replacements == 0 then return text end
	end
end

local function makeWeaponPart(tool, handle, name, size, offset, color, material, shape)
	local part = makePart(tool, name, size, color, material, handle.CFrame * offset, shape)
	part.Anchored = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function createWeaponTool(player, weaponId)
	local definition = WeaponService.Weapons[weaponId]
	if not definition then return nil end

	local tool = Instance.new("Tool")
	tool.Name = definition.DisplayName
	tool.ToolTip = definition.Description
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("WeaponId", weaponId)
	tool:SetAttribute("OwnerUserId", player.UserId)
	tool:SetAttribute("WeaponKind", definition.Kind)
	local handle = makePart(tool, "Handle", Vector3.new(0.32, 1.05, 0.32),
		Color3.fromRGB(91, 57, 34), Enum.Material.Wood, CFrame.new())
	handle.Anchored = false
	handle.Massless = true
	handle.CanCollide = false
	handle.CanTouch = false

	if weaponId == "KnightSword" or weaponId == "PlasmaSword" then
		makeWeaponPart(tool, handle, "Crossguard", Vector3.new(1.05, 0.16, 0.24),
			CFrame.new(0, 0.62, 0), definition.AccentColor, Enum.Material.Metal)
		local blade = makeWeaponPart(tool, handle, "Blade", Vector3.new(0.38, 2.15, 0.14),
			CFrame.new(0, 1.76, 0), definition.BladeColor,
			weaponId == "PlasmaSword" and Enum.Material.Neon or Enum.Material.Metal)
		blade.CanTouch = false
		makeWeaponPart(tool, handle, "Pommel", Vector3.new(0.42, 0.36, 0.38),
			CFrame.new(0, -0.66, 0), definition.AccentColor, Enum.Material.Metal, Enum.PartType.Ball)
		if weaponId == "PlasmaSword" then
			local light = Instance.new("PointLight")
			light.Color = definition.BladeColor
			light.Brightness = 1.4
			light.Range = 9
			light.Parent = blade
			local sparks = Instance.new("Sparkles")
			sparks.SparkleColor = Color3.fromRGB(235, 185, 255)
			sparks.Parent = blade
		end
	else
		tool.Grip = CFrame.new(0, -0.35, -0.12)
		makeWeaponPart(tool, handle, "Receiver", Vector3.new(0.65, 0.56, 1.25),
			CFrame.new(0, 0.14, -0.62), Color3.fromRGB(56, 68, 78), Enum.Material.Metal)
		makeWeaponPart(tool, handle, "LaserBarrel", Vector3.new(0.34, 0.34, 1.5),
			CFrame.new(0, 0.2, -1.72), definition.AccentColor, Enum.Material.Metal)
		local emitter = makeWeaponPart(tool, handle, "LaserEmitter", Vector3.new(0.42, 0.42, 0.22),
			CFrame.new(0, 0.2, -2.55), definition.BladeColor, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = definition.BladeColor
		light.Brightness = 1.1
		light.Range = 7
		light.Parent = emitter
		makeWeaponPart(tool, handle, "GripGuard", Vector3.new(0.8, 0.13, 0.3),
			CFrame.new(0, -0.35, -0.12), definition.AccentColor, Enum.Material.Metal)
	end

	return tool
end

function WeaponService.GiveWeapon(player, weaponId)
	local definition = WeaponService.Weapons[weaponId]
	if not definition or not player or player.Parent ~= Players then return false end
	local attributeName = "OwnsWeapon_" .. weaponId
	if player:GetAttribute(attributeName) then return false end

	local tool = createWeaponTool(player, weaponId)
	if not tool then return false end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local starterGear = player:FindFirstChild("StarterGear")
	if not backpack then
		tool:Destroy()
		return false
	end

	player:SetAttribute(attributeName, true)
	tool.Parent = backpack
	local respawnTool = tool:Clone()
	respawnTool.Parent = starterGear or backpack
	return true
end

local function setCardOwned(card, owned)
	local status = card:FindFirstChild("Status", true)
	local prompt = card:FindFirstChild("BuyWeapon", true)
	local priceText = card:GetAttribute("PriceText")
	if status then status.Text = owned and "OWNED  •  READY TO EQUIP" or priceText end
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = card:GetAttribute("ArmoryAvailable") == true and not owned
		prompt.ActionText = owned and "Owned" or "Buy"
	end
end

local function createArmoryLabel(parent, name, position, size, text, font, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = font
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function createDisplayWeapon(parent, definition, weaponId, frame)
	if definition.Kind == "Melee" then
		makePart(parent, "DisplayGrip_" .. weaponId, Vector3.new(0.28, 0.88, 0.28),
			Color3.fromRGB(92, 58, 34), Enum.Material.Wood, frame * CFrame.new(0, 1.0, 0))
		makePart(parent, "DisplayGuard_" .. weaponId, Vector3.new(1.05, 0.16, 0.24),
			definition.AccentColor, Enum.Material.Metal, frame * CFrame.new(0, 1.45, 0))
		local blade = makePart(parent, "DisplayBlade_" .. weaponId, Vector3.new(0.38, 2.05, 0.13),
			definition.BladeColor, weaponId == "PlasmaSword" and Enum.Material.Neon or Enum.Material.Metal,
			frame * CFrame.new(0, 2.55, 0))
		if weaponId == "PlasmaSword" then
			local glow = Instance.new("PointLight")
			glow.Color = definition.BladeColor
			glow.Brightness = 0.7
			glow.Range = 6
			glow.Parent = blade
		end
	else
		makePart(parent, "DisplayBlaster_" .. weaponId, Vector3.new(0.75, 0.6, 1.5),
			Color3.fromRGB(56, 68, 78), Enum.Material.Metal, frame * CFrame.new(0, 1.9, 0))
		makePart(parent, "DisplayEmitter_" .. weaponId, Vector3.new(0.42, 0.42, 1.0),
			definition.BladeColor, Enum.Material.Neon, frame * CFrame.new(0, 1.95, -1.1))
	end
end

local function createWeaponCard(plot, plotFrame, weaponId, index, onPurchase)
	local definition = WeaponService.Weapons[weaponId]
	-- Give each anchored display its own visual lane so world-space cards stay readable.
	local center = Vector3.new(-96 + (index - 1) * 18, 1.85, 176)
	local frame = plotFrame * CFrame.new(center)
	local color = definition.BladeColor
	local pedestal = makePart(plot, "ArmoryPedestal_" .. weaponId, Vector3.new(0.7, 8.3, 8.3),
		Color3.fromRGB(62, 60, 56), Enum.Material.Slate,
		frame * CFrame.new(0, -0.7, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
	local ring = makePart(plot, "ArmoryRune_" .. weaponId, Vector3.new(0.17, 7.1, 7.1),
		color, Enum.Material.Neon, frame * CFrame.new(0, -0.265, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
	ring.Transparency = 0.2
	local touchPad = makePart(plot, "ArmoryPurchase_" .. weaponId, Vector3.new(0.65, 6.3, 6.3),
		Color3.fromRGB(39, 32, 25), Enum.Material.WoodPlanks,
		frame * CFrame.new(0, 0.125, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
	touchPad.CanTouch = true
	touchPad:SetAttribute("WeaponId", weaponId)
	createDisplayWeapon(plot, definition, weaponId, frame)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 0.7
	light.Range = 11
	light.Parent = touchPad

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ArmoryCard_" .. weaponId
	billboard.Adornee = touchPad
	billboard.Size = UDim2.fromOffset(214, 104)
	billboard.StudsOffset = Vector3.zero
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 5.1, 0)
	billboard.MaxDistance = 48
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.Parent = touchPad
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromRGB(34, 27, 21)
	card.BorderSizePixel = 0
	card.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 1.8
	stroke.Parent = card
	local definitionType = definition.Kind == "Ranged" and "FORCE LASER" or "MELEE WEAPON"
	createArmoryLabel(card, "WeaponType", UDim2.fromScale(0.04, 0.03), UDim2.new(0.92, 0, 0.16, 0),
		definitionType, Enum.Font.GothamBold, 11, color)
	createArmoryLabel(card, "WeaponName", UDim2.fromScale(0.04, 0.2), UDim2.new(0.92, 0, 0.30, 0),
		definition.DisplayName, Enum.Font.Garamond, 22, Color3.fromRGB(255, 244, 215))
	createArmoryLabel(card, "WeaponDescription", UDim2.fromScale(0.04, 0.52), UDim2.new(0.92, 0, 0.16, 0),
		definition.Description, Enum.Font.Gotham, 11, Color3.fromRGB(202, 190, 170))
	local priceText = string.format("%s GOLD  •  PRESS E / TAP TO BUY", formatGold(definition.Price))
	local status = createArmoryLabel(card, "Status", UDim2.fromScale(0.04, 0.72), UDim2.new(0.92, 0, 0.23, 0),
		priceText, Enum.Font.GothamBold, 12, Color3.fromRGB(242, 207, 124))
	card:SetAttribute("PriceText", priceText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyWeapon"
	prompt.ActionText = "Buy"
	prompt.ObjectText = string.format("%s — %s gold", definition.DisplayName, formatGold(definition.Price))
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Enabled = false
	prompt.Parent = touchPad
	prompt.Triggered:Connect(function(player)
		local outcome = onPurchase(player, weaponId, definition)
		if outcome == "Purchased" or outcome == "Owned" then
			setCardOwned(card, true)
		elseif outcome == "InsufficientFunds" then
			status.Text = "NOT ENOUGH GOLD"
			task.delay(1.8, function()
				if status.Parent then setCardOwned(card, false) end
			end)
		end
	end)
	card:SetAttribute("WeaponId", weaponId)
	return { pad = touchPad, card = card, status = status, prompt = prompt,
		definition = definition, pedestal = pedestal, weaponId = weaponId }
end

function WeaponService.CreateArmory(plot, plotFrame, onPurchase)
	local old = plot:FindFirstChild("RoyalArmory")
	if old then old:Destroy() end
	local armory = Instance.new("Model")
	armory.Name = "RoyalArmory"
	armory.Parent = plot
	local center = plotFrame * CFrame.new(-92, 0, 176)
	local platform = makePart(armory, "ArmoryFloor", Vector3.new(36, 0.7, 11),
		Color3.fromRGB(91, 78, 57), Enum.Material.WoodPlanks, center * CFrame.new(11, 1.15, 0))
	platform.CanCollide = true
	local back = makePart(armory, "ArmoryCounter", Vector3.new(35, 4, 1.1),
		Color3.fromRGB(73, 47, 29), Enum.Material.Wood, center * CFrame.new(11, 3.7, -4.8))
	back.CanCollide = true
	local sign = makePart(armory, "ArmorySign", Vector3.new(28, 3.2, 0.45),
		Color3.fromRGB(42, 31, 21), Enum.Material.WoodPlanks, center * CFrame.new(11, 7.6, -4.1))
	local signGui = Instance.new("SurfaceGui")
	signGui.Name = "ArmorySignGui"
	signGui.Face = Enum.NormalId.Front
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 30
	signGui.LightInfluence = 0
	signGui.Parent = sign
	local signText = createArmoryLabel(signGui, "ArmoryTitle", UDim2.fromScale(0.02, 0.04), UDim2.fromScale(0.96, 0.92),
		"ROYAL ARMORY  •  WEAPONS FOR GOLD", Enum.Font.Garamond, 34, Color3.fromRGB(244, 204, 120))
	signText.TextScaled = true
	local signStroke = Instance.new("UIStroke")
	signStroke.Color = Color3.fromRGB(176, 129, 53)
	signStroke.Thickness = 1.3
	signStroke.Parent = signText

	local cards = {}
	for index, weaponId in ipairs(weaponOrder) do
		cards[weaponId] = createWeaponCard(armory, plotFrame, weaponId, index, onPurchase)
	end
	return cards
end

function WeaponService.SetArmoryOwner(cards, player)
	for _, record in pairs(cards or {}) do
		local owned = player ~= nil and player:GetAttribute("OwnsWeapon_" .. record.weaponId) == true
		record.card:SetAttribute("ArmoryAvailable", player ~= nil)
		setCardOwned(record.card, owned)
	end
end

local function setWeaponNotice(player, message, style)
	if noticeRemote and player.Parent == Players then
		noticeRemote:FireClient(player, message, style)
	end
end

local function getTargetPlayerFromPart(part)
	local model = part and part:FindFirstAncestorOfClass("Model")
	if not model then return nil end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local target = Players:GetPlayerFromCharacter(model)
	return target, humanoid, model
end

local function playLaserVisual(origin, destination, color)
	local distance = (destination - origin).Magnitude
	if distance < 0.1 then return end
	local beam = Instance.new("Part")
	beam.Name = "ForceLaserBeam"
	beam.Size = Vector3.new(0.16, 0.16, distance)
	beam.CFrame = CFrame.lookAt((origin + destination) / 2, destination)
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Parent = Workspace
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.5
	light.Range = 6
	light.Parent = beam
	Debris:AddItem(beam, 0.11)
end

local function isInsideOwnKingdom(player)
	local tycoonId = player:GetAttribute("TycoonId")
	local plots = Workspace:FindFirstChild("Tycoons")
	local plot = typeof(tycoonId) == "string" and plots and plots:FindFirstChild(tycoonId)
	local base = plot and plot:FindFirstChild("Base")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not base or not base:IsA("BasePart") or not root then return false end
	local localPosition = base.CFrame:PointToObjectSpace(root.Position)
	return math.abs(localPosition.X) <= base.Size.X / 2 and math.abs(localPosition.Z) <= base.Size.Z / 2
end

local function canDamageTarget(attacker, target, humanoid)
	return target ~= nil and target ~= attacker and humanoid ~= nil and humanoid.Health > 0
		and target.Character ~= nil and not target.Character:FindFirstChildOfClass("ForceField")
		and not isInsideOwnKingdom(target)
end

local function isZombieModel(model)
	return model ~= nil and model:GetAttribute("IsZombie") == true
end

local function damageCharacter(attacker, target, humanoid, model, definition, direction)
	local validTarget = target and canDamageTarget(attacker, target, humanoid)
		or not target and isZombieModel(model) and humanoid ~= nil and humanoid.Health > 0
	if not validTarget then return false end
	humanoid:TakeDamage(definition.Damage)
	if not target and isZombieModel(model) and humanoid.Health <= 0
		and model:GetAttribute("KillRewarded") ~= true then
		model:SetAttribute("KillRewarded", true)
		local leaderstats = attacker:FindFirstChild("leaderstats")
		local cash = leaderstats and leaderstats:FindFirstChild("Cash")
		local zombieKills = leaderstats and leaderstats:FindFirstChild("ZombieKills")
		if cash and cash:IsA("IntValue") then cash.Value += 40 end
		if zombieKills and zombieKills:IsA("IntValue") then zombieKills.Value += 1 end
		setWeaponNotice(attacker, "+40 gold — zombie defeated!", "Success")
	end
	if definition.Knockback and model then
		local targetRoot = model:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			local impulseDirection = direction.Magnitude > 0.01 and direction.Unit or Vector3.new(0, 0, -1)
			targetRoot:ApplyImpulse((impulseDirection * definition.Knockback + Vector3.new(0, 14, 0)) * targetRoot.AssemblyMass)
		end
	end
	return true
end

local function handleLaser(player, definition, targetPoint, character)
	if typeof(targetPoint) ~= "Vector3" or targetPoint.X ~= targetPoint.X
		or targetPoint.Y ~= targetPoint.Y or targetPoint.Z ~= targetPoint.Z
		or math.abs(targetPoint.X) > 100000 or math.abs(targetPoint.Y) > 100000 or math.abs(targetPoint.Z) > 100000 then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head then return end
	local direction = targetPoint - head.Position
	if direction.Magnitude < 1 then return end
	direction = direction.Unit * definition.Range
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	local result = Workspace:Raycast(head.Position, direction, params)
	local endPosition = result and result.Position or (head.Position + direction)
	playLaserVisual(head.Position, endPosition, definition.BladeColor)
	if result then
		local target, humanoid, model = getTargetPlayerFromPart(result.Instance)
		if model and (target or isZombieModel(model)) then
			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			local push = targetRoot and (targetRoot.Position - head.Position).Unit or direction.Unit
			damageCharacter(player, target, humanoid, model, definition, push)
		end
	end
end

local function handleMelee(player, definition, character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local facing = root.CFrame.LookVector
	local bestTarget, bestHumanoid, bestModel, bestDirection, bestDistance
	local candidates = {}
	for _, target in ipairs(Players:GetPlayers()) do
		if target.Character then
			table.insert(candidates, { player = target, model = target.Character })
		end
	end
	local zombieFolder = Workspace:FindFirstChild("Zombies")
	if zombieFolder then
		for _, model in ipairs(zombieFolder:GetChildren()) do
			if model:IsA("Model") and model:GetAttribute("IsZombie") then
				table.insert(candidates, { model = model })
			end
		end
	end
	for _, candidate in ipairs(candidates) do
		local model = candidate.model
		local target = candidate.player
		if target ~= player or isZombieModel(model) then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			if humanoid and targetRoot and humanoid.Health > 0 then
				local offset = targetRoot.Position - root.Position
				local distance = offset.Magnitude
				local direction = distance > 0 and offset.Unit or facing
				if distance <= definition.Range and facing:Dot(direction) > 0.15
					and (not bestDistance or distance < bestDistance) then
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { character }
					local sight = Workspace:Raycast(root.Position + Vector3.new(0, 1, 0),
						targetRoot.Position - root.Position, params)
					if sight and sight.Instance:IsDescendantOf(model) then
						bestTarget, bestHumanoid, bestModel, bestDirection, bestDistance = target, humanoid, model, direction, distance
					end
				end
			end
		end
	end
	if bestHumanoid then damageCharacter(player, bestTarget, bestHumanoid, bestModel, definition, bestDirection) end
end

local function onWeaponAction(player, tool, targetPoint)
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then return end
	local weaponId = tool:GetAttribute("WeaponId")
	local definition = typeof(weaponId) == "string" and WeaponService.Weapons[weaponId] or nil
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not definition or not character or tool.Parent ~= character or not humanoid or humanoid.Health <= 0
		or tool:GetAttribute("OwnerUserId") ~= player.UserId
		or player:GetAttribute("OwnsWeapon_" .. weaponId) ~= true
		or not player:GetAttribute("TycoonId") then
		return
	end
	local now = os.clock()
	lastUse[player] = lastUse[player] or {}
	if now - (lastUse[player][weaponId] or 0) < definition.Cooldown then return end
	lastUse[player][weaponId] = now
	if definition.Kind == "Ranged" then
		handleLaser(player, definition, targetPoint, character)
	else
		handleMelee(player, definition, character)
	end
end

function WeaponService.TryPurchase(player, weaponId, state)
	local definition = WeaponService.Weapons[weaponId]
	if not definition or not player or not state or not state.active or state.owner ~= player then
		return "NotYourKingdom"
	end
	if player:GetAttribute("EconomyReady") ~= true then return "Unavailable" end
	if player:GetAttribute("OwnsWeapon_" .. weaponId) then return "Owned" end
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if not cash or not cash:IsA("IntValue") then return "Unavailable" end
	if cash.Value < definition.Price then
		setWeaponNotice(player, string.format("You need %s more gold for the %s.",
			formatGold(definition.Price - cash.Value), definition.DisplayName), "Warning")
		return "InsufficientFunds"
	end
	cash.Value -= definition.Price
	if not WeaponService.GiveWeapon(player, weaponId) then
		cash.Value += definition.Price
		return "Unavailable"
	end
	setWeaponNotice(player, string.format("Purchased %s for %s gold!", definition.DisplayName,
		formatGold(definition.Price)), "Success")
	return "Purchased"
end

function WeaponService.Initialize()
	if initialized then return end
	initialized = true
	actionRemote = ReplicatedStorage:FindFirstChild("WeaponAction")
	if not actionRemote then
		actionRemote = Instance.new("RemoteEvent")
		actionRemote.Name = "WeaponAction"
		actionRemote.Parent = ReplicatedStorage
	end
	noticeRemote = ReplicatedStorage:FindFirstChild("WeaponNotice")
	if not noticeRemote then
		noticeRemote = Instance.new("RemoteEvent")
		noticeRemote.Name = "WeaponNotice"
		noticeRemote.Parent = ReplicatedStorage
	end
	actionRemote.OnServerEvent:Connect(onWeaponAction)
	Players.PlayerRemoving:Connect(function(player) lastUse[player] = nil end)
end

return WeaponService
