local Config = {
	StartingCash = 100,
	ConveyorSpeed = 22,
	MoneyBlockLifetime = 8,
	MoneyBlockSize = Vector3.new(2.2, 1.8, 2.2),
	MoneyBlockMaterial = Enum.Material.WoodPlanks,
	MoneyBlockColor = Color3.fromRGB(176, 124, 62),
	ProductionSchedulerInterval = 0.2,
	PurchaseBillboardMaxDistance = 48,
	MaxVisiblePurchasePads = 3,
	PurchasePad = {
		FoundationDiameter = 6.2,
		FoundationThickness = 0.3,
		RimDiameter = 5.5,
		RimThickness = 0.1,
		TouchDiameter = 4.4,
		TouchThickness = 0.12,
		MarkerHeight = 8,
		MarkerDiameter = 0.18,
		MarkerMaxDistance = 180,
		MarkerOffset = Vector3.new(2.5, 0, 0),
		BillboardSize = UDim2.fromOffset(190, 56),
		BillboardWorldOffset = Vector3.new(0, 2.45, 0),
	},
	PlotSize = Vector2.new(120, 120),

	-- Flip only for local Studio iteration. This changes server-side costs and
	-- production pacing; it does not grant or accept Cash from a client.
	DevelopmentFastProgression = false,
	DevelopmentCostMultiplier = 0.15,
	DevelopmentIncomeMultiplier = 3,
	DevelopmentDropIntervalMultiplier = 1,

	PlotOffsets = {
		Tycoon1 = Vector3.new(-300, 0, -300),
		Tycoon2 = Vector3.new(300, 0, -300),
		Tycoon3 = Vector3.new(-300, 0, 300),
		Tycoon4 = Vector3.new(300, 0, 300),
	},
	-- Local +Z is each kingdom's entrance direction, pointed toward the hub.
	PlotRotations = {
		Tycoon1 = 45,
		Tycoon2 = -45,
		Tycoon3 = 135,
		Tycoon4 = -135,
	},
	Districts = {
		Lumber = { DisplayName = "Lumber Camp", Center = Vector3.new(-39, 0, 37), ChannelStart = Vector3.new(-39, 4.5, 43), Collector = Vector3.new(-20, 1.5, 43) },
		Farm = { DisplayName = "Farm", Center = Vector3.new(39, 0, 37), ChannelStart = Vector3.new(39, 4.5, 43), Collector = Vector3.new(20, 1.5, 43) },
		Quarry = { DisplayName = "Quarry", Center = Vector3.new(-39, 0, 0), ChannelStart = Vector3.new(-39, 4.5, 6), Collector = Vector3.new(-20, 1.5, 6) },
		Blacksmith = { DisplayName = "Blacksmith", Center = Vector3.new(39, 0, 0), ChannelStart = Vector3.new(39, 4.5, 6), Collector = Vector3.new(20, 1.5, 6) },
		Barracks = { DisplayName = "Barracks", Center = Vector3.new(-35, 0, -36), ChannelStart = Vector3.new(-35, 4.5, -30), Collector = Vector3.new(-16, 1.5, -30) },
	},
	DistrictSignage = {
		Lumber = { BoardName = "LumberSignBoard", Text = "LUMBER\nYARD" },
		Quarry = { BoardName = "QuarrySignBoard", Text = "QUARRY" },
		Blacksmith = { BoardName = "BlacksmithSignBoard", Text = "BLACKSMITH" },
		Farm = { BoardName = "FarmSignBoard", Text = "FARMLAND" },
		Barracks = { BoardName = "BarracksSignBoard", Text = "BARRACKS" },
		Castle = { BoardName = "CastleSignBoard", Text = "CASTLE" },
	},
	-- Local coordinates from the plot center. These eight walkable locations are
	-- shared by the four levels in each group and remain beside their district roads.
	UpgradePadLocations = {
		Lumber = Vector3.new(-14.5, 1, 34),
		Farm = Vector3.new(14.5, 1, 34),
		Quarry = Vector3.new(-18, 1, -7),
		Blacksmith = Vector3.new(18, 1, 15),
		Barracks = Vector3.new(-35, 1.14, -24),
		Walls = Vector3.new(-14.5, 1, 49),
		Towers = Vector3.new(14.5, 1, 49),
		Castle = Vector3.new(17, 1, -12),
	},
	StructuralGroups = {
		Walls = true,
		Towers = true,
		Castle = true,
	},
	UpgradeOrder = {
		"LumberI", "LumberII", "QuarryI", "LumberIII", "QuarryII",
		"BlacksmithI", "FarmI", "LumberIV", "QuarryIII", "BlacksmithII",
		"FarmII", "BarracksI", "WallsI", "QuarryIV", "BlacksmithIII",
		"FarmIII", "BarracksII", "WallsII", "TowerI", "BlacksmithIV",
		"FarmIV", "BarracksIII", "CastleI", "TowerII", "WallsIII",
		"CastleII", "TowerIII", "BarracksIV", "CastleIII", "WallsIV",
		"TowerIV", "CastleIV",
	},
	Upgrades = {},
}

local production = {
	Lumber = {
		{ "LumberI", "Lumber Camp I", 50, 10, Color3.fromRGB(139, 91, 47), Enum.Material.WoodPlanks },
		{ "LumberII", "Lumber Camp II", 80, 16, Color3.fromRGB(154, 102, 53), Enum.Material.WoodPlanks },
		{ "LumberIII", "Lumber Camp III", 180, 24, Color3.fromRGB(112, 75, 41), Enum.Material.Wood },
		{ "LumberIV", "Lumber Camp IV", 600, 34, Color3.fromRGB(128, 82, 43), Enum.Material.WoodPlanks },
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
	QuarryI = { "LumberII" },
	LumberIII = { "QuarryI" },
	QuarryII = { "QuarryI" },
	BlacksmithI = { "LumberIII", "QuarryII" },
	FarmI = { "BlacksmithI" },
	LumberIV = { "LumberIII", "FarmI" },
	QuarryIII = { "QuarryII", "BlacksmithI" },
	BlacksmithII = { "BlacksmithI" },
	FarmII = { "FarmI", "LumberIV" },
	BarracksI = { "FarmI", "BlacksmithII" },
	WallsI = { "BarracksI" },
	QuarryIV = { "QuarryIII", "BarracksI" },
	BlacksmithIII = { "BlacksmithII", "FarmII" },
	FarmIII = { "FarmII", "BarracksI" },
	BarracksII = { "BarracksI", "WallsI" },
	WallsII = { "WallsI", "QuarryIII" },
	TowerI = { "WallsI" },
	BlacksmithIV = { "BlacksmithIII", "BarracksII" },
	FarmIV = { "FarmIII", "WallsII" },
	BarracksIII = { "BarracksII", "TowerI" },
	CastleI = { "BarracksII", "WallsI" },
	TowerII = { "TowerI", "WallsII" },
	WallsIII = { "WallsII", "CastleI" },
	CastleII = { "CastleI", "TowerII" },
	TowerIII = { "TowerII", "CastleII" },
	BarracksIV = { "BarracksIII", "CastleII" },
	CastleIII = { "CastleII", "WallsIII", "TowerIII" },
	WallsIV = { "WallsIII", "CastleIII" },
	TowerIV = { "TowerIII", "WallsIV" },
	CastleIV = { "CastleIII", "WallsIV", "TowerIV", "BarracksIV" },
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
