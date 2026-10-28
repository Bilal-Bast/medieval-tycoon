-- Lightweight server-controlled zombies gather around the shared kingdom hub.
-- They are anchored part rigs with Humanoids, so melee/ranged tools can damage
-- them without adding a physics-heavy NPC rig for every player in the server.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ZombieService = {}

local ZOMBIE_COUNT = 12
local MAX_HEALTH = 110
local MOVE_SPEED = 7
local DETECT_RANGE = 190
local ATTACK_RANGE = 5.5
local ATTACK_DAMAGE = 9
local ATTACK_COOLDOWN = 1.35
local RESPAWN_DELAY = 9
local UPDATE_STEP = 0.15
local SPAWN_RADIUS = 165
local slots = {}
local initialized = false

local function makePart(model, name, size, color, material, localCFrame, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = name ~= "HumanoidRootPart"
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = localCFrame
	part.Parent = model
	return part
end

local function addHealthDisplay(head, humanoid)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZombieHealth"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(120, 38)
	gui.StudsOffset = Vector3.new(0, 1.1, 0)
	gui.MaxDistance = 90
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = head

	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.Size = UDim2.new(1, 0, 0, 19)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.Text = "RESTLESS DEAD"
	name.TextColor3 = Color3.fromRGB(190, 255, 151)
	name.TextStrokeTransparency = 0.45
	name.TextSize = 12
	name.Parent = gui

	local background = Instance.new("Frame")
	background.Name = "HealthBackground"
	background.Position = UDim2.new(0.12, 0, 0, 22)
	background.Size = UDim2.new(0.76, 0, 0, 8)
	background.BackgroundColor3 = Color3.fromRGB(35, 28, 24)
	background.BorderSizePixel = 0
	background.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "HealthFill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(113, 184, 77)
	fill.BorderSizePixel = 0
	fill.Parent = background

	humanoid.HealthChanged:Connect(function(health)
		if fill.Parent then
			fill.Size = UDim2.fromScale(math.clamp(health / humanoid.MaxHealth, 0, 1), 1)
		end
	end)
end

local function createZombie(slotIndex, spawnPosition)
	local model = Instance.new("Model")
	model.Name = string.format("Zombie_%02d", slotIndex)
	model:SetAttribute("IsZombie", true)
	model:SetAttribute("ZombieId", slotIndex)
	local origin = CFrame.new(spawnPosition)
	local root = makePart(model, "HumanoidRootPart", Vector3.new(1.6, 2.7, 1.2),
		Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, origin, Enum.PartType.Block)
	root.Transparency = 1
	model.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = MAX_HEALTH
	humanoid.Health = MAX_HEALTH
	humanoid.WalkSpeed = 0
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model

	local localParts = {}
	local skin = Color3.fromRGB(118, 143, 91)
	local cloth = Color3.fromRGB(67, 71, 53)
	local rags = Color3.fromRGB(87, 57, 45)
	local function bodyPart(name, size, color, material, offset, shape)
		local part = makePart(model, name, size, color, material, origin * offset, shape)
		localParts[part] = offset
		return part
	end
	bodyPart("Torso", Vector3.new(1.45, 1.65, 0.78), cloth, Enum.Material.Fabric, CFrame.new(0, 2.25, 0))
	bodyPart("TatteredShirt", Vector3.new(1.48, 0.75, 0.81), rags, Enum.Material.Fabric, CFrame.new(0, 1.95, -0.025))
	local head = bodyPart("Head", Vector3.new(1.05, 1.05, 0.95), skin, Enum.Material.SmoothPlastic, CFrame.new(0, 3.65, 0), Enum.PartType.Ball)
	bodyPart("Jaw", Vector3.new(0.65, 0.22, 0.68), Color3.fromRGB(88, 111, 69), Enum.Material.SmoothPlastic, CFrame.new(0, 3.18, -0.17))
	bodyPart("LeftArm", Vector3.new(0.42, 1.55, 0.45), skin, Enum.Material.SmoothPlastic, CFrame.new(-1.02, 2.05, -0.05) * CFrame.Angles(0, 0, math.rad(-18)))
	bodyPart("RightArm", Vector3.new(0.42, 1.55, 0.45), skin, Enum.Material.SmoothPlastic, CFrame.new(1.02, 2.05, -0.05) * CFrame.Angles(0, 0, math.rad(18)))
	bodyPart("LeftLeg", Vector3.new(0.52, 1.05, 0.58), Color3.fromRGB(61, 57, 43), Enum.Material.Fabric, CFrame.new(-0.38, 0.65, 0))
	bodyPart("RightLeg", Vector3.new(0.52, 1.05, 0.58), Color3.fromRGB(61, 57, 43), Enum.Material.Fabric, CFrame.new(0.38, 0.65, 0))
	bodyPart("LeftEye", Vector3.new(0.15, 0.15, 0.08), Color3.fromRGB(187, 255, 95), Enum.Material.Neon, CFrame.new(-0.23, 3.72, -0.47), Enum.PartType.Ball)
	bodyPart("RightEye", Vector3.new(0.15, 0.15, 0.08), Color3.fromRGB(187, 255, 95), Enum.Material.Neon, CFrame.new(0.23, 3.72, -0.47), Enum.PartType.Ball)
	bodyPart("Belt", Vector3.new(1.25, 0.2, 0.84), Color3.fromRGB(111, 78, 42), Enum.Material.Leather, CFrame.new(0, 1.43, 0))
	bodyPart("ShoulderRag", Vector3.new(0.7, 0.3, 0.83), Color3.fromRGB(118, 57, 48), Enum.Material.Fabric, CFrame.new(-0.48, 2.82, 0))

	model.WorldPivot = origin
	model.Parent = Workspace:FindFirstChild("Zombies")	
	addHealthDisplay(head, humanoid)
	local record = {
		model = model,
		slotIndex = slotIndex,
		humanoid = humanoid,
		root = root,
		localParts = localParts,
		spawnPosition = spawnPosition,
		height = 0,
		lastAttack = 0,
	}
	humanoid.Died:Connect(function()
		model:SetAttribute("IsZombie", false)
		Debris:AddItem(model, 1.6)
		local slot = slots[slotIndex]
		if slot then
			slot.record = nil
			slot.respawnAt = os.clock() + RESPAWN_DELAY
		end
	end)
	return record
end

local function insideAnyKingdom(position)
	local tycoons = Workspace:FindFirstChild("Tycoons")
	if not tycoons then return false end
	for _, plot in ipairs(tycoons:GetChildren()) do
		local base = plot:FindFirstChild("Base")
		if base and base:IsA("BasePart") then
			local localPosition = base.CFrame:PointToObjectSpace(position)
			if math.abs(localPosition.X) <= base.Size.X / 2 and math.abs(localPosition.Z) <= base.Size.Z / 2 then
				return true
			end
		end
	end
	return false
end

local function nearestTarget(position)
	local bestRoot, bestHumanoid, bestDistance
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and humanoid and humanoid.Health > 0 and not insideAnyKingdom(root.Position)
			and not character:FindFirstChildOfClass("ForceField") then
			local distance = (root.Position - position).Magnitude
			if distance <= DETECT_RANGE and (not bestDistance or distance < bestDistance) then
				bestRoot, bestHumanoid, bestDistance = root, humanoid, distance
			end
		end
	end
	return bestRoot, bestHumanoid, bestDistance
end

local function updateZombie(record, dt, now)
	if not record.model.Parent or record.humanoid.Health <= 0 then return end
	local pivot = record.model:GetPivot()
	local rootPosition = record.root.Position
	local targetRoot, targetHumanoid, distance = nearestTarget(rootPosition)
	local nextPosition = rootPosition
	local facing = pivot.LookVector
	if targetRoot and targetHumanoid then
		local offset = targetRoot.Position - rootPosition
		local horizontal = Vector3.new(offset.X, 0, offset.Z)
		if horizontal.Magnitude > ATTACK_RANGE then
			local movement = math.min(MOVE_SPEED * dt, horizontal.Magnitude - ATTACK_RANGE)
			nextPosition += horizontal.Unit * movement
			facing = horizontal.Unit
		elseif now - record.lastAttack >= ATTACK_COOLDOWN then
			record.lastAttack = now
			targetHumanoid:TakeDamage(ATTACK_DAMAGE)
		end
	elseif now - (record.lastWander or 0) > 3 then
		record.lastWander = now + math.random() * 2
		local angle = math.random() * math.pi * 2
		record.wanderTarget = record.spawnPosition + Vector3.new(math.cos(angle) * 14, 0, math.sin(angle) * 14)
	elseif record.wanderTarget then
		local offset = record.wanderTarget - rootPosition
		local horizontal = Vector3.new(offset.X, 0, offset.Z)
		if horizontal.Magnitude > 1.5 then
			nextPosition += horizontal.Unit * math.min(MOVE_SPEED * 0.45 * dt, horizontal.Magnitude)
			facing = horizontal.Unit
		end
	end

	local isMoving = (nextPosition - rootPosition).Magnitude > 0.01
	local bob = isMoving and math.sin(now * 8 + record.slotIndex) * 0.055 or math.sin(now * 2) * 0.025
	local destination = Vector3.new(nextPosition.X, record.spawnPosition.Y, nextPosition.Z)
	local newPivot = CFrame.lookAt(destination, destination + Vector3.new(facing.X, 0, facing.Z)) * CFrame.new(0, bob, 0)
	record.model:PivotTo(newPivot)
	for part, localFrame in pairs(record.localParts) do
		if part.Parent then part.CFrame = newPivot * localFrame end
	end
end

function ZombieService.Initialize()
	if initialized then return end
	initialized = true
	local folder = Workspace:FindFirstChild("Zombies")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Zombies"
		folder.Parent = Workspace
	end
	for _, child in ipairs(folder:GetChildren()) do child:Destroy() end
	for index = 1, ZOMBIE_COUNT do
		local angle = math.rad(22.5 + (index - 1) * 360 / ZOMBIE_COUNT)
		local radius = SPAWN_RADIUS + ((index % 3) - 1) * 12
		local position = Vector3.new(math.cos(angle) * radius, 1, math.sin(angle) * radius)
		slots[index] = { position = position, respawnAt = 0 }
		slots[index].record = createZombie(index, position)
	end

	task.spawn(function()
		while true do
			task.wait(UPDATE_STEP)
			local now = os.clock()
			for index, slot in ipairs(slots) do
				if slot.record and not slot.record.model.Parent then
					slot.record = nil
					slot.respawnAt = now + RESPAWN_DELAY
				end
				if not slot.record and now >= slot.respawnAt then
					slot.record = createZombie(index, slot.position)
				end
				if slot.record then updateZombie(slot.record, UPDATE_STEP, now) end
			end
		end
	end)
end

return ZombieService
