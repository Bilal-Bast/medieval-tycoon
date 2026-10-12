local Config = {
	StartingCash = 100,
	ConveyorSpeed = 25,
	MoneyBlockLifetime = 30,
	MoneyBlockSize = Vector3.new(2, 2, 2),
	MoneyBlockColor = BrickColor.new("Bright green"),
	MoneyBlockMaterial = Enum.Material.Neon,
	PlotOffsets = {
		Tycoon1 = Vector3.new(-110, 0, -110),
		Tycoon2 = Vector3.new(110, 0, -110),
		Tycoon3 = Vector3.new(-110, 0, 110),
		Tycoon4 = Vector3.new(110, 0, 110),
	},
	Upgrades = {
		Dropper1 = {
			Cost = 50,
			ButtonName = "BuyDropperButton",
			MoneyPerDrop = 10,
			DropInterval = 2,
		},
		Dropper2 = {
			Cost = 150,
			ButtonName = "BuyDropper2Button",
			MoneyPerDrop = 20,
			DropInterval = 2,
			Requires = "Dropper1",
		},
	},
}

return Config
