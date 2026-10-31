-- The spin wheel. You get a free spin every FreeEveryMinutes of play
-- (and from quests). Prizes use the same reward kinds as Rewards.luau.
-- Weight: how likely each slice is compared to the others.

return {
	FreeEveryMinutes = 12,
	Prizes = {
		{ Label = "Small Gold", Weight = 30, Color = Color3.fromRGB(255, 200, 60), Gold = { Seconds = 180, Min = 500 } },
		{ Label = "Rare Egg", Weight = 18, Color = Color3.fromRGB(70, 150, 255), Egg = { Rarity = "Rare" } },
		{ Label = "Big Gold", Weight = 14, Color = Color3.fromRGB(255, 150, 30), Gold = { Seconds = 900, Min = 3000 } },
		{ Label = "Lucky Fusion", Weight = 10, Color = Color3.fromRGB(80, 210, 90), LuckyFusion = 1 },
		{ Label = "Epic Egg", Weight = 12, Color = Color3.fromRGB(190, 85, 255), Egg = { Rarity = "Epic" } },
		{ Label = "2 Spins", Weight = 8, Color = Color3.fromRGB(240, 110, 180), Spins = 2 },
		{ Label = "Legendary Egg", Weight = 6, Color = Color3.fromRGB(255, 190, 40), Egg = { Rarity = "Legendary" } },
		{ Label = "JACKPOT", Weight = 2, Color = Color3.fromRGB(255, 60, 120), Egg = { Rarity = "Mythic", Mutation = "Golden" } },
	},
}
