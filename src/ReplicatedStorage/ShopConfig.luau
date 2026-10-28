-- Create each item in Creator Dashboard > Monetization, then replace ID = 0.
-- Marketplace prices are fetched live so regional/optimized pricing is respected.
return {
	Products = {
		{ Key = "GoldPouch", Id = 0, Name = "Gold Pouch", Amount = 250,
			Description = "A small treasury boost for your kingdom." },
		{ Key = "GoldChest", Id = 0, Name = "Gold Chest", Amount = 1000,
			Description = "A generous boost for your next big upgrade." },
		{ Key = "GoldVault", Id = 0, Name = "Gold Vault", Amount = 3000,
			Description = "A royal reserve for ambitious builders." },
	},
	Passes = {
		{ Key = "DoubleGold", Id = 0, Name = "Prosperity Pass", Attribute = "OwnsPass_DoubleGold",
			Description = "Permanently doubles gold from kingdom production." },
		{ Key = "RoyalStyle", Id = 0, Name = "Royal Style", Attribute = "OwnsPass_RoyalStyle",
			Description = "Wear a golden royal aura and an exclusive nameplate." },
	},
}
