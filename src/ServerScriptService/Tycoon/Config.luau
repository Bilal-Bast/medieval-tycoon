local Config = {
	StartingCash = 100,
	ConveyorSpeed = 22,
	MoneyBlockLifetime = 8,
	MoneyBlockSize = Vector3.new(2.2, 1.8, 2.2),
	MoneyBlockMaterial = Enum.Material.WoodPlanks,
	MoneyBlockColor = Color3.fromRGB(176, 124, 62),
	ProductionSchedulerInterval = 0.2,
	ProductionCorridors = {
		Lumber = { LaneCenter = Vector3.new(-148, 1.68, 114), LaneWidth = 5.5, LaneLength = 72, CollectorCenter = Vector3.new(-110, 3.2, 114), CollectorSize = Vector3.new(12, 6.21, 11), DropXs = { -173, -164, -155, -146 }, DropY = 8.4, ClearanceHeight = 12 },
		Quarry = { LaneCenter = Vector3.new(-130, 1.68, -150), LaneWidth = 5.5, LaneLength = 72, CollectorCenter = Vector3.new(-92, 3.2, -150), CollectorSize = Vector3.new(12, 6.21, 11), DropXs = { -155, -146, -137, -128 }, DropY = 8.4, ClearanceHeight = 12 },
		Blacksmith = { LaneCenter = Vector3.new(130, 1.68, -150), LaneWidth = 5.5, LaneLength = 72, CollectorCenter = Vector3.new(168, 3.2, -150), CollectorSize = Vector3.new(12, 6.21, 11), DropXs = { 105, 114, 123, 132 }, DropY = 8.4, ClearanceHeight = 12 },
		Farm = { LaneCenter = Vector3.new(130, 1.68, 169), LaneWidth = 5.5, LaneLength = 72, CollectorCenter = Vector3.new(168, 3.2, 169), CollectorSize = Vector3.new(12, 6.21, 11), DropXs = { 105, 114, 123, 132 }, DropY = 8.4, ClearanceHeight = 12 },
		Barracks = { LaneCenter = Vector3.new(-92, 1.68, 207), LaneWidth = 5.5, LaneLength = 72, CollectorCenter = Vector3.new(-54, 3.2, 207), CollectorSize = Vector3.new(12, 6.21, 11), DropXs = { -117, -108, -99, -90 }, DropY = 8.4, ClearanceHeight = 12 },
	},
	DevelopmentNPCDebug = false,
	KingdomLife = {
		UpdateInterval = 0.2,
		WalkSpeed = 7,
		MaxPopulation = 30,
		ProsperityPerUpgrade = 10,
		ProsperityPerLevel = 5,
		VillagerThresholds = { FarmII = 1, BarracksI = 2, CastleIII = 2, CastleIV = 2 },
		-- Optional verified assets can be filled in later. Empty IDs intentionally remain silent.
		ActivitySoundIds = {
			LumberChop = "", Saw = "", WoodCreak = "",
			Pickaxe = "", StoneImpact = "",
			Forge = "", Hammer = "", Sparks = "",
			Farm = "", Animals = "",
			Training = "", Footsteps = "", Courtyard = "",
		},
		LumberWorkerPoints = {
			Lumberjack = {
				Work = { Vector3.new(-179, 0.86, 61), Vector3.new(-177, 0.86, 71) },
				Storage = { Vector3.new(-171, 0.86, 78) },
				Idle = { Vector3.new(-181, 0.86, 76), Vector3.new(-174, 0.86, 69) },
				Carry = {},
			},
			TimberWorker = {
				Work = { Vector3.new(-169, 0.86, 79) },
				Storage = { Vector3.new(-117, 1.305, 99) },
				Idle = { Vector3.new(-128, 0.86, 84) },
				Carry = { Vector3.new(-151, 0.86, 78) },
			},
			SawmillWorker = {
				Work = { Vector3.new(-153, 1.59, 56), Vector3.new(-146, 1.59, 59) },
				Storage = { Vector3.new(-140, 0.86, 82) },
				Idle = { Vector3.new(-144, 0.86, 80) },
				Carry = { Vector3.new(-152, 0.86, 78) },
			},
			Foreman = {
				Work = { Vector3.new(-131, 1.59, 67) },
				Storage = { Vector3.new(-117, 1.305, 99) },
				Idle = { Vector3.new(-127, 0.86, 83) },
				Carry = { Vector3.new(-152, 0.86, 78) },
			},
		},
		DistrictWorkerPoints = {
			Quarry = { Work = { Vector3.new(-166, -1.95, -92), Vector3.new(-143, -1.95, -86) }, Storage = { Vector3.new(-90, 1.0, -55) }, Idle = { Vector3.new(-100, 1.0, -48) }, Carry = { Vector3.new(-112, 1.0, -72) } },
			Blacksmith = { Work = { Vector3.new(94, 1.84, -92), Vector3.new(122, 1.84, -86) }, Storage = { Vector3.new(164, 1.84, -48) }, Idle = { Vector3.new(155, 1.84, -41) }, Carry = { Vector3.new(135, 1.84, -72) } },
			Farm = { Work = { Vector3.new(93, 0.95, 63), Vector3.new(121, 0.95, 72), Vector3.new(152, 0.95, 103) }, Storage = { Vector3.new(178, 1.0, 145) }, Idle = { Vector3.new(171, 0.95, 112) }, Carry = { Vector3.new(152, 0.95, 130) } },
			Barracks = { Work = { Vector3.new(-40, 1.75, 148), Vector3.new(0, 1.75, 160), Vector3.new(40, 1.75, 148) }, Storage = { Vector3.new(48, 1.0, 182) }, Idle = { Vector3.new(0, 1.0, 102) }, Carry = { Vector3.new(0, 1.0, 116) } },
			Castle = { Work = { Vector3.new(-40, 1.0, -100), Vector3.new(40, 1.0, -100) }, Storage = { Vector3.new(0, 1.0, -52) }, Idle = { Vector3.new(65, 1.0, -65) }, Carry = { Vector3.new(0, 1.0, -65) } },
		},
		LumberWaterWheelCenter = Vector3.new(-128.7, 8.3, 59),
	},
	PurchaseBillboardMaxDistance = 58,
	MaxVisiblePurchasePads = 1,
	PurchasePad = {
		FoundationDiameter = 7.2,
		FoundationThickness = 0.45,
		RimDiameter = 6.5,
		RimThickness = 0.16,
		TouchDiameter = 5.4,
		TouchThickness = 0.16,
		BillboardSize = UDim2.fromOffset(260, 96),
	},
	PlotSize = Vector2.new(480, 480),

	-- Flip only for local Studio iteration. This changes server-side costs and
	-- production pacing; it does not grant or accept Cash from a client.
	DevelopmentFastProgression = false,
	DevelopmentCostMultiplier = 0.15,
	DevelopmentIncomeMultiplier = 3,
	DevelopmentDropIntervalMultiplier = 1,

	PlotOffsets = {
		Tycoon1 = Vector3.new(-500, 0, -500),
		Tycoon2 = Vector3.new(500, 0, -500),
		Tycoon3 = Vector3.new(-500, 0, 500),
		Tycoon4 = Vector3.new(500, 0, 500),
		Tycoon5 = Vector3.new(0, 0, -500),
		Tycoon6 = Vector3.new(500, 0, 0),
		Tycoon7 = Vector3.new(0, 0, 500),
		Tycoon8 = Vector3.new(-500, 0, 0),
	},
	-- Local +Z is each kingdom's entrance direction, pointed toward the hub.
	PlotRotations = {
		Tycoon1 = 0,
		Tycoon2 = 0,
		Tycoon3 = 180,
		Tycoon4 = 180,
		Tycoon5 = 0,
		Tycoon6 = -90,
		Tycoon7 = 180,
		Tycoon8 = 90,
	},
	-- Keep each entrance standard recognizable after its claim pad updates.
	RealmColors = {
		Tycoon1 = Color3.fromRGB(184, 74, 54),
		Tycoon2 = Color3.fromRGB(64, 122, 173),
		Tycoon3 = Color3.fromRGB(102, 148, 79),
		Tycoon4 = Color3.fromRGB(191, 145, 56),
		Tycoon5 = Color3.fromRGB(148, 94, 173),
		Tycoon6 = Color3.fromRGB(56, 148, 133),
		Tycoon7 = Color3.fromRGB(184, 102, 79),
		Tycoon8 = Color3.fromRGB(92, 115, 179),
	},
	Districts = {
		Lumber = { DisplayName = "Lumber Mill", Center = Vector3.new(-150, 0, 57), ChannelStart = Vector3.new(-148, 9, 114), Collector = Vector3.new(-110, 3, 114) },
		Farm = { DisplayName = "Farm", Center = Vector3.new(136, 0, 90), ChannelStart = Vector3.new(130, 9, 169), Collector = Vector3.new(168, 3, 169) },
		Quarry = { DisplayName = "Quarry", Center = Vector3.new(-138, 0, -100), ChannelStart = Vector3.new(-130, 9, -150), Collector = Vector3.new(-92, 3, -150) },
		Blacksmith = { DisplayName = "Blacksmith", Center = Vector3.new(126, 0, -84), ChannelStart = Vector3.new(130, 9, -150), Collector = Vector3.new(168, 3, -150) },
		Barracks = { DisplayName = "Barracks", Center = Vector3.new(0, 0, 150), ChannelStart = Vector3.new(-92, 9, 207), Collector = Vector3.new(-54, 3, 207) },
		Castle = { DisplayName = "Castle", Center = Vector3.new(0, 0, -119) },
		Walls = { DisplayName = "Walls", Center = Vector3.new(0, 0, 0) },
		Towers = { DisplayName = "Towers", Center = Vector3.new(0, 0, 0) },
	},
	DistrictSignage = {
		Lumber = { BoardName = "LumberSignBoard", Text = "LUMBER\nYARD" },
		Quarry = { BoardName = "QuarrySignBoard", Text = "QUARRY" },
		Blacksmith = { BoardName = "BlacksmithSignBoard", Text = "BLACKSMITH" },
		Farm = { BoardName = "FarmSignBoard", Text = "FARMLAND" },
		Barracks = { BoardName = "BarracksSignBoard", Text = "BARRACKS" },
		Castle = { BoardName = "CastleSignBoard", Text = "CASTLE" },
	},
	-- Local coordinates from each plot center. These eight walkable locations are
	-- shared by all four levels in each group and stay beside their district roads.
	UpgradePadLocations = {
		Lumber = Vector3.new(-90, 1, 137),
		Farm = Vector3.new(70, 1, 145),
		Quarry = Vector3.new(-67, 1, -100),
		Blacksmith = Vector3.new(205, 1, -55),
		Barracks = Vector3.new(0, 1, 100),
		Walls = Vector3.new(-30, 1, 198),
		Towers = Vector3.new(30, 1, 198),
		Castle = Vector3.new(65, 1, -55),
	},
	StructuralGroups = {
		Walls = true,
		Towers = true,
		Castle = true,
	},
	UpgradeOrder = {
		"LumberI", "LumberII", "LumberIII", "LumberIV",
		"QuarryI", "QuarryII", "QuarryIII", "QuarryIV",
		"BlacksmithI", "BlacksmithII", "BlacksmithIII", "BlacksmithIV",
		"FarmI", "FarmII", "FarmIII", "FarmIV",
		"BarracksI", "BarracksII", "BarracksIII", "BarracksIV",
		"WallsI", "WallsII", "WallsIII", "WallsIV",
		"TowerI", "TowerII", "TowerIII", "TowerIV",
		"CastleI", "CastleII", "CastleIII", "CastleIV",
	},
	Upgrades = {},
}

local production = {
	Lumber = {
		{ "LumberI", "Lumber Mill I", 50, 10, Color3.fromRGB(139, 91, 47), Enum.Material.WoodPlanks },
		{ "LumberII", "Lumber Mill II", 80, 16, Color3.fromRGB(154, 102, 53), Enum.Material.WoodPlanks },
		{ "LumberIII", "Lumber Mill III", 180, 24, Color3.fromRGB(112, 75, 41), Enum.Material.Wood },
		{ "LumberIV", "Lumber Mill IV", 600, 34, Color3.fromRGB(128, 82, 43), Enum.Material.WoodPlanks },
	},
	Quarry = {
		{ "QuarryI", "Quarry I", 160, 22, Color3.fromRGB(116, 120, 123), Enum.Material.Slate },
		{ "QuarryII", "Quarry II", 260, 34, Color3.fromRGB(129, 132, 134), Enum.Material.Rock },
		{ "QuarryIII", "Quarry III", 800, 48, Color3.fromRGB(105, 111, 116), Enum.Material.Slate },
		{ "QuarryIV", "Quarry IV", 1450, 65, Color3.fromRGB(139, 143, 145), Enum.Material.Rock },
	},
	Blacksmith = {
		{ "BlacksmithI", "Blacksmith I", 400, 50, Color3.fromRGB(75, 79, 84), Enum.Material.Metal },
		{ "BlacksmithII", "Blacksmith II", 900, 72, Color3.fromRGB(105, 110, 117), Enum.Material.Metal },
		{ "BlacksmithIII", "Blacksmith III", 1600, 100, Color3.fromRGB(83, 89, 98), Enum.Material.Metal },
		{ "BlacksmithIV", "Blacksmith IV", 2800, 135, Color3.fromRGB(126, 130, 135), Enum.Material.Metal },
	},
	Farm = {
		{ "FarmI", "Farm I", 450, 30, Color3.fromRGB(164, 131, 56), Enum.Material.WoodPlanks },
		{ "FarmII", "Farm II", 1000, 45, Color3.fromRGB(184, 150, 67), Enum.Material.WoodPlanks },
		{ "FarmIII", "Farm III", 1800, 65, Color3.fromRGB(159, 121, 54), Enum.Material.Wood },
		{ "FarmIV", "Farm IV", 3000, 90, Color3.fromRGB(198, 163, 76), Enum.Material.WoodPlanks },
	},
	Barracks = {
		{ "BarracksI", "Barracks I", 1300, 75, Color3.fromRGB(126, 78, 53), Enum.Material.WoodPlanks },
		{ "BarracksII", "Barracks II", 2000, 105, Color3.fromRGB(141, 88, 58), Enum.Material.WoodPlanks },
		{ "BarracksIII", "Barracks III", 3600, 145, Color3.fromRGB(115, 79, 61), Enum.Material.Wood },
		{ "BarracksIV", "Barracks IV", 5000, 195, Color3.fromRGB(151, 98, 63), Enum.Material.WoodPlanks },
	},
}

local prerequisites = {
	LumberII = { "LumberI" },
	LumberIII = { "LumberII" },
	LumberIV = { "LumberIII" },
	QuarryI = { "LumberIV" },
	QuarryII = { "QuarryI" },
	QuarryIII = { "QuarryII" },
	QuarryIV = { "QuarryIII" },
	BlacksmithI = { "QuarryIV" },
	BlacksmithII = { "BlacksmithI" },
	BlacksmithIII = { "BlacksmithII" },
	BlacksmithIV = { "BlacksmithIII" },
	FarmI = { "BlacksmithIV" },
	FarmII = { "FarmI" },
	FarmIII = { "FarmII" },
	FarmIV = { "FarmIII" },
	BarracksI = { "FarmIV" },
	BarracksII = { "BarracksI" },
	BarracksIII = { "BarracksII" },
	BarracksIV = { "BarracksIII" },
	WallsI = { "BarracksIV" },
	WallsII = { "WallsI" },
	WallsIII = { "WallsII" },
	WallsIV = { "WallsIII" },
	TowerI = { "WallsIV" },
	TowerII = { "TowerI" },
	TowerIII = { "TowerII" },
	TowerIV = { "TowerIII" },
	CastleI = { "TowerIV" },
	CastleII = { "CastleI" },
	CastleIII = { "CastleII" },
	CastleIV = { "CastleIII" },
}

for districtId, levels in pairs(production) do
	for level, row in ipairs(levels) do
		local id, displayName, cost, income, resourceColor, resourceMaterial = table.unpack(row)
		Config.Upgrades[id] = {
			Id = id,
			DisplayName = displayName,
			Cost = cost,
			Prerequisites = prerequisites[id] or {},
			Category = "Production",
			District = districtId,
			Level = level,
			AssetName = id,
			IncomePerDrop = income,
			DropInterval = 2,
			ResourceColor = resourceColor,
			ResourceMaterial = resourceMaterial,
			PurchasePosition = Config.UpgradePadLocations[districtId],
		}
	end
end

local structures = {
	{ "WallsI", "Timber Palisade I", 750, "Walls", 1 },
	{ "WallsII", "Timber Palisade II", 1600, "Walls", 2 },
	{ "WallsIII", "Stone Fortifications III", 3500, "Walls", 3 },
	{ "WallsIV", "Stone Kingdom Walls IV", 7000, "Walls", 4 },
	{ "TowerI", "Watchtowers I", 1200, "Towers", 1 },
	{ "TowerII", "Reinforced Towers II", 2500, "Towers", 2 },
	{ "TowerIII", "Stone Guard Towers III", 5200, "Towers", 3 },
	{ "TowerIV", "Fortified Towers IV", 10000, "Towers", 4 },
	{ "CastleI", "Wooden Manor I", 2800, "Castle", 1 },
	{ "CastleII", "Stone Keep II", 6000, "Castle", 2 },
	{ "CastleIII", "Fortified Keep III", 12000, "Castle", 3 },
	{ "CastleIV", "Royal Castle IV", 22000, "Castle", 4 },
}

for _, row in ipairs(structures) do
	local id, displayName, cost, group, level = table.unpack(row)
	Config.Upgrades[id] = {
		Id = id,
		DisplayName = displayName,
		Cost = cost,
		Prerequisites = prerequisites[id] or {},
		Category = "Structure",
		District = group,
		Level = level,
		VisualGroup = group,
		AssetName = id,
		PurchasePosition = Config.UpgradePadLocations[group],
	}
end

return Config
