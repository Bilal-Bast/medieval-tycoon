-- One server-owned scheduler and a small, deterministic state machine drive all
-- kingdom workers. NPCs are lightweight anchored part rigs; no NPC contains a Script.
local Config = require(script.Parent.Config)
local Players = game:GetService("Players")

local KingdomNPCService = {}
local activePlots = {}
local workerSerial = 0
local schedulerStarted = false
local movingParts = setmetatable({}, { __mode = "k" })

local roleLooks = {
	Lumberjack = { shirt = Color3.fromRGB(71, 91, 55), pants = Color3.fromRGB(86, 59, 39), tool = "Axe" },
	TimberWorker = { shirt = Color3.fromRGB(126, 79, 43), pants = Color3.fromRGB(73, 54, 40), tool = "Log" },
	SawmillWorker = { shirt = Color3.fromRGB(94, 65, 43), pants = Color3.fromRGB(58, 49, 40), tool = "Hammer" },
	Foreman = { shirt = Color3.fromRGB(81, 73, 49), pants = Color3.fromRGB(54, 47, 39), tool = "Clipboard" },
	Miner = { shirt = Color3.fromRGB(69, 70, 70), pants = Color3.fromRGB(51, 49, 47), tool = "Pickaxe" },
	StoneWorker = { shirt = Color3.fromRGB(105, 101, 93), pants = Color3.fromRGB(62, 59, 54), tool = "Stone" },
	CartWorker = { shirt = Color3.fromRGB(112, 73, 44), pants = Color3.fromRGB(57, 49, 41), tool = "Stone" },
	Blacksmith = { shirt = Color3.fromRGB(63, 60, 57), pants = Color3.fromRGB(48, 44, 40), apron = true, tool = "Hammer" },
	Apprentice = { shirt = Color3.fromRGB(95, 74, 55), pants = Color3.fromRGB(57, 47, 39), apron = true, tool = "Hammer" },
	Armorer = { shirt = Color3.fromRGB(91, 94, 91), pants = Color3.fromRGB(57, 58, 55), apron = true, tool = "Hammer" },
	Farmer = { shirt = Color3.fromRGB(114, 94, 49), pants = Color3.fromRGB(79, 63, 38), tool = "Hoe" },
	Harvester = { shirt = Color3.fromRGB(141, 112, 58), pants = Color3.fromRGB(83, 65, 40), tool = "Sickle" },
	Herder = { shirt = Color3.fromRGB(98, 112, 63), pants = Color3.fromRGB(77, 61, 43), tool = "Staff" },
	Recruit = { shirt = Color3.fromRGB(106, 69, 48), pants = Color3.fromRGB(54, 52, 48), tool = "PracticeSword" },
	Soldier = { shirt = Color3.fromRGB(92, 91, 80), pants = Color3.fromRGB(48, 50, 49), armor = true, tool = "PracticeSword" },
	Trainer = { shirt = Color3.fromRGB(113, 88, 54), pants = Color3.fromRGB(49, 49, 45), armor = true, tool = "PracticeSword" },
	WallGuard = { shirt = Color3.fromRGB(84, 88, 81), pants = Color3.fromRGB(48, 50, 48), armor = true, tool = "Spear" },
	TowerGuard = { shirt = Color3.fromRGB(83, 89, 96), pants = Color3.fromRGB(46, 48, 51), armor = true, tool = "Spear" },
	CastleGuard = { shirt = Color3.fromRGB(100, 84, 60), pants = Color3.fromRGB(47, 48, 47), armor = true, tool = "Spear" },
	Attendant = { shirt = Color3.fromRGB(133, 105, 66), pants = Color3.fromRGB(61, 53, 44), tool = "Tray" },
	Villager = { shirt = Color3.fromRGB(117, 77, 58), pants = Color3.fromRGB(68, 58, 48), tool = "Basket" },
}

local rosters = {
	Lumber = {
		[1] = { "Lumberjack" },
		[2] = { "Lumberjack", "TimberWorker" },
		[3] = { "Lumberjack", "SawmillWorker", "TimberWorker" },
		[4] = { "Lumberjack", "Lumberjack", "SawmillWorker", "TimberWorker", "Foreman" },
	},
	Quarry = {
		[1] = { "Miner" },
		[2] = { "Miner", "StoneWorker" },
		[3] = { "Miner", "StoneWorker", "CartWorker" },
		[4] = { "Miner", "Miner", "StoneWorker", "CartWorker" },
	},
	Blacksmith = {
		[1] = { "Blacksmith" },
		[2] = { "Blacksmith", "Apprentice" },
		[3] = { "Blacksmith", "Apprentice", "Armorer" },
		[4] = { "Blacksmith", "Blacksmith", "Apprentice", "Armorer" },
	},
	Farm = {
		[1] = { "Farmer" },
		[2] = { "Farmer", "Harvester" },
		[3] = { "Farmer", "Farmer", "Harvester" },
		[4] = { "Farmer", "Farmer", "Harvester", "Herder" },
	},
	Barracks = {
		[1] = { "Recruit" },
		[2] = { "Recruit", "Trainer" },
		[3] = { "Recruit", "Soldier", "Trainer" },
		[4] = { "Recruit", "Soldier", "Soldier", "Trainer" },
	},
	Walls = { [3] = { "WallGuard" }, [4] = { "WallGuard", "WallGuard" } },
	Towers = {
		[1] = { "TowerGuard" }, [2] = { "TowerGuard", "TowerGuard" },
		[3] = { "TowerGuard", "TowerGuard", "TowerGuard" },
		[4] = { "TowerGuard", "TowerGuard", "TowerGuard" },
	},
	Castle = { [1] = { "CastleGuard" }, [2] = { "CastleGuard" }, [3] = { "CastleGuard", "Attendant" }, [4] = { "CastleGuard", "Attendant" } },
}

local function createPart(model, name, size, color, material, pivot, localFrame, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = pivot * localFrame
	part.Parent = model
	return part
end

local function makeTool(model, pivot, toolName, palette)
	local brown = Color3.fromRGB(101, 69, 42)
	local metal = Color3.fromRGB(126, 131, 133)
	local handle = createPart(model, "ToolHandle", Vector3.new(0.16, 1.15, 0.16), brown, Enum.Material.Wood, pivot, CFrame.new(0.78, 2.45, -0.12))
	local head
	if toolName == "Axe" or toolName == "Pickaxe" or toolName == "Hammer" or toolName == "PracticeSword" then
		local width = toolName == "PracticeSword" and 0.18 or 0.62
		local height = toolName == "Hammer" and 0.25 or 0.38
		head = createPart(model, "ToolHead", Vector3.new(width, height, 0.22), toolName == "PracticeSword" and Color3.fromRGB(172, 150, 101) or metal,
			toolName == "PracticeSword" and Enum.Material.Wood or Enum.Material.Metal, pivot, CFrame.new(0.78, 3.08, -0.12))
	elseif toolName == "Spear" then
		head = createPart(model, "ToolHead", Vector3.new(0.2, 0.45, 0.2), metal, Enum.Material.Metal, pivot, CFrame.new(0.78, 3.19, -0.12))
	elseif toolName == "Hoe" or toolName == "Sickle" or toolName == "Staff" then
		head = createPart(model, "ToolHead", Vector3.new(0.48, 0.16, 0.2), Color3.fromRGB(147, 141, 113), Enum.Material.Metal, pivot, CFrame.new(0.78, 3.02, -0.12))
	elseif toolName == "Log" or toolName == "Stone" or toolName == "Basket" or toolName == "Tray" then
		local size = toolName == "Log" and Vector3.new(1.45, 0.36, 0.38) or Vector3.new(0.78, 0.52, 0.62)
		local color = toolName == "Log" and Color3.fromRGB(126, 82, 46) or palette.resource
		head = createPart(model, "CarryProp", size, color, toolName == "Stone" and Enum.Material.Slate or Enum.Material.Wood,
			pivot, CFrame.new(0.72, 2.32, -0.35))
		if handle then handle:Destroy() end
	elseif toolName == "Clipboard" then
		head = createPart(model, "ToolHead", Vector3.new(0.5, 0.62, 0.12), Color3.fromRGB(137, 103, 62), Enum.Material.Wood, pivot, CFrame.new(0.78, 2.62, -0.12))
	end
	return handle, head
end

local function createWorker(plot, state, folder, district, role, index, seed, workPoints, storage, idlePoints, carryPoints, route)
	workerSerial += 1
	local look = roleLooks[role]
	local palette = { resource = district == "Farm" and Color3.fromRGB(181, 146, 60) or Color3.fromRGB(137, 133, 125) }
	local start = workPoints[((index - 1) % #workPoints) + 1]
	local pivot = CFrame.new(start + Vector3.new(0, 0.05, 0))
	local model = Instance.new("Model")
	model.Name = string.format("%s_%02d", role, index)
	model:SetAttribute("OwnerUserId", state.owner.UserId)
	model:SetAttribute("TycoonId", plot.Name)
	model:SetAttribute("DistrictId", district)
	model:SetAttribute("Role", role)
	model:SetAttribute("NPCId", string.format("%s:%s:%02d", district, role, index))
	model:SetAttribute("State", "Work")
	model.WorldPivot = pivot

	local skin = Color3.fromRGB(207, 168, 126)
	local boot = Color3.fromRGB(57, 43, 32)
	local shirtMaterial = look.armor and Enum.Material.Metal or Enum.Material.Fabric
	createPart(model, "LeftBoot", Vector3.new(0.32, 0.32, 0.42), boot, Enum.Material.SmoothPlastic, pivot, CFrame.new(-0.23, 0.18, 0.02))
	createPart(model, "RightBoot", Vector3.new(0.32, 0.32, 0.42), boot, Enum.Material.SmoothPlastic, pivot, CFrame.new(0.23, 0.18, 0.02))
	createPart(model, "LeftLeg", Vector3.new(0.3, 0.78, 0.34), look.pants, Enum.Material.Fabric, pivot, CFrame.new(-0.2, 0.67, 0))
	createPart(model, "RightLeg", Vector3.new(0.3, 0.78, 0.34), look.pants, Enum.Material.Fabric, pivot, CFrame.new(0.2, 0.67, 0))
	createPart(model, "Torso", Vector3.new(0.82, 1.04, 0.43), look.shirt, shirtMaterial, pivot, CFrame.new(0, 2.05, 0))
	createPart(model, "Head", Vector3.new(0.58, 0.62, 0.56), skin, Enum.Material.SmoothPlastic, pivot, CFrame.new(0, 2.94, 0))
	createPart(model, "Cap", Vector3.new(0.66, 0.2, 0.62), look.shirt, Enum.Material.Fabric, pivot, CFrame.new(0, 3.33, 0))
	createPart(model, "LeftArm", Vector3.new(0.28, 0.86, 0.3), look.shirt, shirtMaterial, pivot, CFrame.new(-0.57, 2.04, 0))
	createPart(model, "RightArm", Vector3.new(0.28, 0.86, 0.3), look.shirt, shirtMaterial, pivot, CFrame.new(0.57, 2.04, 0))
	if look.apron then
		createPart(model, "Apron", Vector3.new(0.62, 0.68, 0.13), Color3.fromRGB(54, 42, 32), Enum.Material.Fabric, pivot, CFrame.new(0, 1.88, -0.25))
	end
	if look.armor then
		createPart(model, "ChestPlate", Vector3.new(0.88, 0.78, 0.14), Color3.fromRGB(117, 119, 112), Enum.Material.Metal, pivot, CFrame.new(0, 2.14, -0.25))
	end
	local handle, head = makeTool(model, pivot, look.tool, palette)
	if not model:FindFirstChild("CarryProp") and (district == "Lumber" or district == "Blacksmith" or district == "Farm" or district == "Barracks") then
		local cargoSize = district == "Lumber" and Vector3.new(1.45, 0.36, 0.38)
			or (district == "Blacksmith" and Vector3.new(0.9, 0.12, 0.12) or Vector3.new(0.72, 0.48, 0.54))
		local cargoColor = district == "Blacksmith" and Color3.fromRGB(161, 153, 129)
			or (district == "Farm" and Color3.fromRGB(171, 135, 62) or Color3.fromRGB(126, 82, 46))
		createPart(model, "CarryProp", cargoSize, cargoColor,
			district == "Blacksmith" and Enum.Material.Metal or Enum.Material.Wood,
			pivot, CFrame.new(0.72, 2.32, -0.35))
	end
	model.Parent = folder

	local points = table.clone(route or workPoints)
	local work = workPoints[((index - 1) % #workPoints) + 1]
	local drop = storage[((index - 1) % #storage) + 1]
	local idle = idlePoints[((index - 1) % #idlePoints) + 1]
	local isPatrol = district == "Walls" or district == "Towers" or role:find("Guard") ~= nil
	local record = {
		model = model,
		plot = plot,
		state = state,
		ownerUserId = state.owner.UserId,
		district = district,
		role = role,
		seed = seed,
		phase = 2,
		phaseTime = 0.35 + (seed % 7) * 0.31,
		position = start,
		segmentStart = start,
		segmentTarget = work,
		segmentTime = 0,
		segmentDuration = 0,
		work = work,
		storage = drop,
		idle = idle,
		workPoints = workPoints,
		storagePoints = storage,
		idlePoints = idlePoints,
		carryPoints = carryPoints,
		carryRoute = {},
		carryRouteIndex = 0,
		patrolPoints = points,
		patrolIndex = ((index - 1) % #points) + 1,
		mode = isPatrol and "Patrol" or "Work",
		toolHandle = handle,
		toolHead = head,
		carryProp = model:FindFirstChild("CarryProp"),
		debugLabel = nil,
		facing = Vector3.new(0, 0, -1),
	}
	if record.carryProp then record.carryProp.Transparency = 1 end
	if Config.DevelopmentNPCDebug then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "NPCDebug"
		billboard.Size = UDim2.fromOffset(170, 52)
		billboard.StudsOffset = Vector3.new(0, 4.1, 0)
		billboard.MaxDistance = 85
		billboard.AlwaysOnTop = true
		billboard.Adornee = model:FindFirstChild("Head")
		billboard.Parent = model
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(38, 31, 23)
		label.BackgroundTransparency = 0.2
		label.TextColor3 = Color3.fromRGB(255, 232, 187)
		label.TextScaled = true
		label.Font = Enum.Font.GothamMedium
		label.Parent = billboard
		record.debugLabel = label
	end
	return record
end

local function getDistrictPoints(district, index, role)
	local definition = district == "Lumber" and Config.KingdomLife.LumberWorkerPoints[role]
		or Config.KingdomLife.DistrictWorkerPoints[district]
	if definition then
		local function atIndex(points)
			return points[((index - 1) % #points) + 1]
		end
		return { atIndex(definition.Work) }, { atIndex(definition.Storage) }, { atIndex(definition.Idle) }, definition.Carry
	end
	local definition = Config.Districts[district]
	local center = definition and definition.Center or Vector3.zero
	local slot = ((index - 1) % 5)
	local offsets = {
		Vector3.new(-7, 0, 7), Vector3.new(0, 0, 8), Vector3.new(7, 0, 7),
		Vector3.new(-5, 0, 13), Vector3.new(5, 0, 13),
	}
	local work = center + offsets[slot + 1]
	local workPoints = { work }
	local storageOffsets = {
		Vector3.new(-15, 0, 16), Vector3.new(15, 0, 16), Vector3.new(-13, 0, -10),
		Vector3.new(13, 0, -10), Vector3.new(0, 0, -14),
	}
	local storage = { center + storageOffsets[slot + 1] }
	return workPoints, storage, storage, {}
end

local function worldPoint(plotFrame, localPoint)
	return (plotFrame * CFrame.new(localPoint)).Position
end

local function roleCountsFor(state)
	local groupLevels = {}
	for upgradeId in pairs(state.purchased) do
		local upgrade = Config.Upgrades[upgradeId]
		if upgrade then
			local group = upgrade.Category == "Production" and upgrade.District or upgrade.VisualGroup
			groupLevels[group] = math.max(groupLevels[group] or 0, upgrade.Level)
		end
	end
	local desired = {}
	local total = 0
	for district, levels in pairs(rosters) do
		local roster = levels[groupLevels[district] or 0]
		if roster then
			for index, role in ipairs(roster) do
				desired[string.format("%s:%s:%02d", district, role, index)] = { district = district, role = role, index = index }
				total += 1
			end
		end
	end
	local villagerCount = 0
	for upgradeId, count in pairs(Config.KingdomLife.VillagerThresholds) do
		if state.purchased[upgradeId] then villagerCount = math.max(villagerCount, count) end
	end
	for index = 1, villagerCount do
		desired[string.format("Villagers:Villager:%02d", index)] = { district = "Villagers", role = "Villager", index = index }
		total += 1
	end
	local ids = {}
	for npcId in pairs(desired) do table.insert(ids, npcId) end
	table.sort(ids)
	for index = Config.KingdomLife.MaxPopulation + 1, #ids do desired[ids[index]] = nil end
	return desired, math.min(total, Config.KingdomLife.MaxPopulation)
end

function KingdomNPCService.GetProsperity(purchased)
	local prosperity = 0
	for upgradeId, isPurchased in pairs(purchased) do
		local upgrade = Config.Upgrades[upgradeId]
		if isPurchased and upgrade then
			prosperity += Config.KingdomLife.ProsperityPerUpgrade + upgrade.Level * Config.KingdomLife.ProsperityPerLevel
		end
	end
	return prosperity
end

local function ensureActivityEffects(state, folder, groupLevels)
	local wanted = {}
	if (groupLevels.Lumber or 0) >= 3 then wanted.LumberSmoke = { position = Vector3.new(-144, 13, 51), color = Color3.fromRGB(146, 144, 138) } end
	if (groupLevels.Blacksmith or 0) >= 1 then wanted.ForgeGlow = { position = Vector3.new(134, 4, -102), color = Color3.fromRGB(255, 132, 49) } end
	if (groupLevels.Blacksmith or 0) >= 3 then wanted.ForgeSmoke = { position = Vector3.new(174, 24, -72), color = Color3.fromRGB(83, 79, 73) } end
	for _, child in ipairs(folder:GetChildren()) do
		if not wanted[child.Name] then child:Destroy() end
	end
	for name, effect in pairs(wanted) do
		if not folder:FindFirstChild(name) then
			local anchor = Instance.new("Part")
			anchor.Name = name
			anchor.Size = Vector3.new(0.2, 0.2, 0.2)
			anchor.Transparency = 1
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.CanTouch = false
			anchor.CFrame = state.plotFrame * CFrame.new(effect.position)
			anchor.Parent = folder
			if name:find("Smoke") then
				local smoke = Instance.new("Smoke")
				smoke.Color = effect.color
				smoke.Opacity = 0.13
				smoke.RiseVelocity = 2.5
				smoke.Size = 5
				smoke.Parent = anchor
			else
				local light = Instance.new("PointLight")
				light.Color = effect.color
				light.Brightness = 1.15
				light.Range = 13
				light.Parent = anchor
			end
		end
	end
	local light = folder:FindFirstChild("ForgeGlow") and folder.ForgeGlow:FindFirstChildOfClass("PointLight")
	if light then light.Brightness = 0.9 + 0.35 * math.abs(math.sin(os.clock() * 2.7)) end
end

local function groupLevelsFor(state)
	local result = {}
	for upgradeId in pairs(state.purchased) do
		local upgrade = Config.Upgrades[upgradeId]
		if upgrade then
			local group = upgrade.Category == "Production" and upgrade.District or upgrade.VisualGroup
			result[group] = math.max(result[group] or 0, upgrade.Level)
		end
	end
	return result
end

local function getVillagerRoute(plotFrame, index)
	local routes = {
		{ Vector3.new(75, 1.1, 86), Vector3.new(0, 1.1, 100), Vector3.new(-80, 1.1, 86), Vector3.new(-66, 1.1, -55), Vector3.new(0, 1.1, -55) },
		{ Vector3.new(-80, 1.1, 86), Vector3.new(-90, 1.1, 137), Vector3.new(-66, 1.1, 86), Vector3.new(-63, 1.1, -100), Vector3.new(-63, 1.1, -180), Vector3.new(65, 1.1, 0), Vector3.new(215, 1.1, 0), Vector3.new(215, 1.1, -55), Vector3.new(215, 1.1, -171) },
		{ Vector3.new(65, 1.1, 0), Vector3.new(75, 1.1, 86), Vector3.new(65, 1.1, 145), Vector3.new(0, 1.1, 100), Vector3.new(-66, 1.1, -55), Vector3.new(65, 1.1, -55) },
		{ Vector3.new(0, 1.1, 100), Vector3.new(0, 1.1, 60), Vector3.new(75, 1.1, 86), Vector3.new(-80, 1.1, 86), Vector3.new(-63, 1.1, -180), Vector3.new(0, 1.1, -55) },
	}
	local points = routes[((index - 1) % #routes) + 1]
	local world = {}
	for _, point in ipairs(points) do table.insert(world, worldPoint(plotFrame, point)) end
	return world
end

function KingdomNPCService.Reconcile(plot, state)
	if not state.owner or not state.owner.Parent then return end
	local folder = plot:FindFirstChild("KingdomNPCs")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "KingdomNPCs"
		folder.Parent = plot
	end
	state.kingdomLife = state.kingdomLife or {}
	local desired, population = roleCountsFor(state)
	local groups = groupLevelsFor(state)
	for npcId, record in pairs(state.kingdomLife) do
		if not desired[npcId] or not record.model or not record.model.Parent then
			if record.model and record.model.Parent then record.model:Destroy() end
			state.kingdomLife[npcId] = nil
		end
	end
	for npcId, description in pairs(desired) do
		if not state.kingdomLife[npcId] and population <= Config.KingdomLife.MaxPopulation then
			local district, role, index = description.district, description.role, description.index
			local workLocal, storageLocal, idleLocal, carryLocal
			local routeLocal
			if district == "Villagers" then
				routeLocal = getVillagerRoute(state.plotFrame, index)
				workLocal = { state.plotFrame:PointToObjectSpace(routeLocal[1]) }
				storageLocal = { state.plotFrame:PointToObjectSpace(routeLocal[3]) }
				idleLocal = storageLocal
				carryLocal = {}
			else
				workLocal, storageLocal, idleLocal, carryLocal = getDistrictPoints(district, index, role)
			end
			local workPoints = {}
			local storagePoints = {}
			local idlePoints = {}
			local carryPoints = {}
			for _, point in ipairs(workLocal) do table.insert(workPoints, worldPoint(state.plotFrame, point)) end
			for _, point in ipairs(storageLocal) do table.insert(storagePoints, worldPoint(state.plotFrame, point)) end
			for _, point in ipairs(idleLocal) do table.insert(idlePoints, worldPoint(state.plotFrame, point)) end
			for _, point in ipairs(carryLocal) do table.insert(carryPoints, worldPoint(state.plotFrame, point)) end
			local route = nil
			if district == "Walls" then
				route = {}
				for _, p in ipairs({ Vector3.new(-215, 1, -215), Vector3.new(215, 1, -215), Vector3.new(215, 1, 215), Vector3.new(-215, 1, 215) }) do table.insert(route, worldPoint(state.plotFrame, p)) end
			elseif district == "Towers" then
				route = {}
				for _, p in ipairs({ Vector3.new(222, 1, -210), Vector3.new(210, 1, -222), Vector3.new(222, 1, 210), Vector3.new(210, 1, 222) }) do table.insert(route, worldPoint(state.plotFrame, p)) end
			elseif district == "Castle" then
				route = {}
				for _, p in ipairs({ Vector3.new(-68, 1, -64), Vector3.new(0, 1, -50), Vector3.new(68, 1, -64), Vector3.new(68, 1, -120), Vector3.new(0, 1, -186), Vector3.new(-68, 1, -120) }) do table.insert(route, worldPoint(state.plotFrame, p)) end
			elseif district == "Villagers" then
				route = routeLocal
			end
			local ok, record = xpcall(function()
				return createWorker(plot, state, folder, district, role, index, workerSerial + index * 3, workPoints, storagePoints, idlePoints, carryPoints, route)
			end, debug.traceback)
			if ok and record and record.model and record.model.Parent == folder then
				state.kingdomLife[npcId] = record
			elseif Config.DevelopmentNPCDebug then
				warn(string.format("[KingdomNPC] Failed to create %s for %s: %s", npcId, plot.Name, tostring(record)))
			end
		end
	end
	ensureActivityEffects(state, folder, groups)
	local prosperity = KingdomNPCService.GetProsperity(state.purchased)
	state.owner:SetAttribute("Prosperity", prosperity)
	local leaderstats = state.owner:FindFirstChild("leaderstats")
	local prosperityStat = leaderstats and leaderstats:FindFirstChild("Prosperity")
	if prosperityStat and prosperityStat:IsA("IntValue") then prosperityStat.Value = prosperity end
	local actual = 0
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("OwnerUserId") == state.owner.UserId
			and typeof(model:GetAttribute("NPCId")) == "string"
		then actual += 1 end
	end
	state.owner:SetAttribute("Population", actual)
	if Config.DevelopmentNPCDebug then
		print(string.format("[KingdomNPC] %s owner=%d desired=%d actual=%d", plot.Name, state.owner.UserId, population, actual))
	end
	activePlots[plot] = state
end

function KingdomNPCService.Cleanup(plot, state)
	activePlots[plot] = nil
	local owner = state.owner
	if owner and owner.Parent then
		owner:SetAttribute("Prosperity", nil)
		owner:SetAttribute("Population", nil)
		local leaderstats = owner:FindFirstChild("leaderstats")
		local prosperityStat = leaderstats and leaderstats:FindFirstChild("Prosperity")
		if prosperityStat and prosperityStat:IsA("IntValue") then prosperityStat.Value = 0 end
	end
	if state.kingdomLife then
		for _, record in pairs(state.kingdomLife) do
			if record.model and record.model.Parent then record.model:Destroy() end
		end
	end
	state.kingdomLife = {}
	local folder = plot:FindFirstChild("KingdomNPCs")
	if folder then folder:Destroy() end
end

local function durationFor(record, destination)
	local distance = (destination - record.position).Magnitude
	return math.max(0.45, distance / Config.KingdomLife.WalkSpeed)
end

local function beginWalk(record, destination, nextPhase)
	record.segmentStart = record.position
	record.segmentTarget = destination
	record.segmentTime = 0
	record.segmentDuration = durationFor(record, destination)
	record.phase = nextPhase
	record.phaseTime = 0
	local direction = destination - record.position
	if direction.Magnitude > 0.1 then record.facing = direction.Unit end
end

local function beginCarryRoute(record)
	record.carryRoute = table.clone(record.carryPoints)
	table.insert(record.carryRoute, record.storage)
	record.carryRouteIndex = 1
	beginWalk(record, record.carryRoute[record.carryRouteIndex], 3)
end

local function updateDebug(record)
	if not record.debugLabel then return end
	local target = record.phase == 3 and record.storage or record.work
	local stateName = record.mode == "Patrol"
		and (record.phase == 1 and "Patrol" or "Observe")
		or ({ [1] = "Travel", [2] = "Work", [3] = "Carry", [4] = "Deliver", [5] = "Travel idle", [6] = "Idle" })[record.phase] or "Work"
	record.model:SetAttribute("State", stateName)
	record.model:SetAttribute("Target", target)
	record.debugLabel.Text = string.format("%s | %s\n%s · %.0f, %.0f", record.role, stateName, record.district, target.X, target.Z)
end

local function playActivitySound(record)
	local soundKey
	if record.role == "Lumberjack" then soundKey = "LumberChop"
	elseif record.role == "SawmillWorker" then soundKey = "Saw"
	elseif record.role == "TimberWorker" then soundKey = "WoodCreak"
	elseif record.role == "Miner" then soundKey = "Pickaxe"
	elseif record.role == "StoneWorker" or record.role == "CartWorker" then soundKey = "StoneImpact"
	elseif record.district == "Blacksmith" then
		soundKey = record.role == "Armorer" and "Sparks" or (record.role == "Blacksmith" and "Forge" or "Hammer")
	elseif record.district == "Farm" then soundKey = record.role == "Herder" and "Animals" or "Farm"
	elseif record.district == "Barracks" then soundKey = "Training"
	elseif record.district == "Castle" then soundKey = "Courtyard"
	elseif record.role:find("Guard") then soundKey = "Footsteps" end
	local soundId = soundKey and Config.KingdomLife.ActivitySoundIds[soundKey]
	if not soundId or soundId == "" then return end
	local head = record.model:FindFirstChild("Head")
	if not head then return end
	local sound = Instance.new("Sound")
	sound.Name = "KingdomActivitySound"
	sound.SoundId = soundId
	sound.Volume = 0.22
	sound.RollOffMaxDistance = 46
	sound.Parent = head
	sound.Ended:Connect(function() sound:Destroy() end)
	sound:Play()
end

local function poseWorker(record, now)
	local model = record.model
	if not model.Parent then return end
	local direction = record.facing
	local facing = Vector3.new(direction.X, 0, direction.Z)
	if facing.Magnitude < 0.1 then facing = Vector3.new(0, 0, -1) end
	local pivot = CFrame.lookAt(record.position + Vector3.new(0, 0.05, 0), record.position + facing + Vector3.new(0, 0.05, 0))
	model:PivotTo(pivot)
	local working = record.phase == 2
	local carrying = record.phase == 3
	local traveling = record.phase == 1 or record.phase == 3 or record.phase == 5
	local swing = working and math.sin(now * 8 + record.seed) or 0
	local stride = traveling and math.sin(now * 7 + record.seed) * 0.22 or 0
	local leftArm = model:FindFirstChild("LeftArm")
	local rightArm = model:FindFirstChild("RightArm")
	local leftLeg = model:FindFirstChild("LeftLeg")
	local rightLeg = model:FindFirstChild("RightLeg")
	if leftArm then leftArm.CFrame = pivot * CFrame.new(-0.57, 2.04 + (carrying and 0.12 or 0), 0) * CFrame.Angles(0, 0, carrying and math.rad(-35) or math.rad(8)) end
	if rightArm then rightArm.CFrame = pivot * CFrame.new(0.57, 2.04 + (carrying and 0.12 or 0), 0) * CFrame.Angles(0, 0, math.rad(-swing * 55)) end
	if leftLeg then leftLeg.CFrame = pivot * CFrame.new(-0.2, 0.67, 0) * CFrame.Angles(stride, 0, 0) end
	if rightLeg then rightLeg.CFrame = pivot * CFrame.new(0.2, 0.67, 0) * CFrame.Angles(-stride, 0, 0) end
	if record.toolHandle and record.toolHandle.Parent then
		record.toolHandle.CFrame = pivot * CFrame.new(0.78, 2.45, -0.12) * CFrame.Angles(0, 0, math.rad(-swing * 80))
	end
	if record.toolHead and record.toolHead.Parent then
		record.toolHead.CFrame = pivot * CFrame.new(0.78, 3.08 - math.max(0, swing) * 0.38, -0.12) * CFrame.Angles(0, 0, math.rad(-swing * 80))
	end
	if record.carryProp and record.carryProp.Parent then
		record.carryProp.Transparency = carrying and 0 or 1
		record.carryProp.CFrame = pivot * CFrame.new(0.65, carrying and 2.15 or 2.4, -0.34)
	end
end

local function updateRecord(record, dt, now)
	local model = record.model
	if not model or not model.Parent or not record.plot.Parent
		or not record.state.active or record.state.owner == nil
		or record.state.owner.UserId ~= record.ownerUserId
		or record.state.owner.Parent ~= Players
	then
		if model and model.Parent then model:Destroy() end
		return false
	end
	if record.mode == "Patrol" then
		if record.phase == 1 then
			record.segmentTime += dt
			local alpha = math.clamp(record.segmentTime / record.segmentDuration, 0, 1)
			record.position = record.segmentStart:Lerp(record.segmentTarget, alpha)
			if alpha >= 1 then
				record.patrolIndex = record.patrolIndex % #record.patrolPoints + 1
				record.phase = 2
				record.phaseTime = 1.1 + (record.seed % 5) * 0.35
			end
		elseif record.phase == 2 then
			record.phaseTime -= dt
			if record.phaseTime <= 0 then
				beginWalk(record, record.patrolPoints[record.patrolIndex], 1)
			end
		end
	else
		record.phaseTime -= dt
		if record.phase == 1 then
			record.segmentTime += dt
			local alpha = math.clamp(record.segmentTime / record.segmentDuration, 0, 1)
			record.position = record.segmentStart:Lerp(record.segmentTarget, alpha)
			if alpha >= 1 then
				record.phase = 2
				record.phaseTime = 1.8 + (record.seed % 6) * 0.55
				playActivitySound(record)
			end
		elseif record.phase == 2 and record.phaseTime <= 0 then
			local target = record.role == "Villager" and record.patrolPoints[record.patrolIndex] or record.storage
			if record.role == "Villager" then
				record.carryRoute = { target }
				record.carryRouteIndex = 1
				beginWalk(record, target, 3)
			else
				beginCarryRoute(record)
			end
		elseif record.phase == 3 then
			record.segmentTime += dt
			local alpha = math.clamp(record.segmentTime / record.segmentDuration, 0, 1)
			record.position = record.segmentStart:Lerp(record.segmentTarget, alpha)
			if alpha >= 1 then
				if record.carryRouteIndex < #record.carryRoute then
					record.carryRouteIndex += 1
					beginWalk(record, record.carryRoute[record.carryRouteIndex], 3)
				else
					record.phase = 4
					record.phaseTime = 0.7 + (record.seed % 4) * 0.25
				end
			end
		elseif record.phase == 4 and record.phaseTime <= 0 then
			beginWalk(record, record.idle, 5)
		elseif record.phase == 5 then
			record.segmentTime += dt
			local alpha = math.clamp(record.segmentTime / record.segmentDuration, 0, 1)
			record.position = record.segmentStart:Lerp(record.segmentTarget, alpha)
			if alpha >= 1 then record.phase = 6; record.phaseTime = 1.0 + (record.seed % 5) * 0.4 end
		elseif record.phase == 6 and record.phaseTime <= 0 then
			if record.role == "Villager" then
				record.patrolIndex = record.patrolIndex % #record.patrolPoints + 1
				record.work = record.patrolPoints[record.patrolIndex]
			else
				record.work = record.workPoints[((record.seed + record.patrolIndex) % #record.workPoints) + 1]
			end
			beginWalk(record, record.work, 1)
		end
	end
	poseWorker(record, now)
	updateDebug(record)
	return true
end

local function animateProductionArt(state, now)
	local current = {}
	for upgradeId in pairs(state.purchased) do
		local upgrade = Config.Upgrades[upgradeId]
		local instance = state.upgradeInstances[upgradeId]
		if upgrade and instance and instance:IsA("Model") then
			local group = upgrade.Category == "Production" and upgrade.District or upgrade.VisualGroup
			local entry = current[group]
			if not entry or upgrade.Level > entry.level then current[group] = { level = upgrade.Level, model = instance } end
		end
	end
	for group, entry in pairs(current) do
		for _, part in ipairs(entry.model:GetDescendants()) do
			if part:IsA("BasePart") and (part.Name:match("^LumberWaterWheel") or part.Name:match("^MainCircularSaw")
				or part.Name:match("^SawBlade") or part.Name:match("^CuttingWheel")
				or part.Name:match("^QuarryCart") or part.Name:match("^LogFeeder"))
			then
				local base = movingParts[part]
				if not base then base = part.CFrame; movingParts[part] = base end
				if part.Name:match("^LumberWaterWheel") then
					local pivot = state.plotFrame * CFrame.new(Config.KingdomLife.LumberWaterWheelCenter)
					part.CFrame = pivot * CFrame.Angles(now * 1.15, 0, 0) * pivot:ToObjectSpace(base)
				elseif part.Name:match("^QuarryCartWheel") then
					part.CFrame = base * CFrame.Angles(now * 3.2, 0, 0)
				elseif part.Name:match("^QuarryCart") then
					part.CFrame = base * CFrame.new(0, 0, math.sin(now * 0.72 + state.owner.UserId) * 1.35)
				elseif part.Name:match("^LogFeeder") then
					part.CFrame = base * CFrame.new(0, 0, math.sin(now * 1.6 + state.owner.UserId) * 0.55)
				else
					local speed = group == "Lumber" and 3.8 or 2.4
					part.CFrame = base * CFrame.Angles(now * speed, 0, 0)
				end
			end
		end
	end
end

local function startScheduler()
	if schedulerStarted then return end
	schedulerStarted = true
	task.spawn(function()
		while true do
			task.wait(Config.KingdomLife.UpdateInterval)
			local now = os.clock()
			for plot, state in pairs(activePlots) do
				if not plot.Parent or not state.owner or state.owner.Parent ~= Players then
					KingdomNPCService.Cleanup(plot, state)
				else
					if now >= (state.nextNPCAuditAt or 0) then
						state.nextNPCAuditAt = now + 2
						local ok, err = pcall(KingdomNPCService.Reconcile, plot, state)
						if not ok and Config.DevelopmentNPCDebug then
							warn(string.format("[KingdomNPC] Reconcile failed for %s: %s", plot.Name, tostring(err)))
						end
					end
					animateProductionArt(state, now)
					for id, record in pairs(state.kingdomLife or {}) do
						if not updateRecord(record, Config.KingdomLife.UpdateInterval, now) then state.kingdomLife[id] = nil end
					end
					local folder = plot:FindFirstChild("KingdomNPCs")
					if folder then
						local glow = folder:FindFirstChild("ForgeGlow") and folder.ForgeGlow:FindFirstChildOfClass("PointLight")
						if glow then glow.Brightness = 0.9 + 0.35 * math.abs(math.sin(now * 2.7)) end
					end
				end
			end
		end
	end)
end

function KingdomNPCService.Initialize()
	startScheduler()
end

return KingdomNPCService
