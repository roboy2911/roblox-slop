-- Robux purchases. Make these in the Creator Dashboard (your experience >
-- Monetization > Passes / Developer Products), then paste the IDs here.
-- An ID of 0 hides that item from the shop.

return {
	GamePasses = {
		DoubleGold = { Id = 2060359822, Name = "2x Gold", Description = "All your dragons earn double gold, forever.", Icon = "💰" },
		VipSpeed = { Id = 2063286602, Name = "VIP Speed", Description = "+8 walk speed, forever.", Icon = "👟" },
		ExtraCarry = { Id = 2062602781, Name = "Big Backpack", Description = "Carry 1 more egg at a time.", Icon = "🎒" },
		AutoCollect = { Id = 2058662521, Name = "Auto Collect", Description = "Gold goes straight into your pocket. No chest trips.", Icon = "🧲" },
	},
	Products = {
		GoldSmall = { Id = 3724789714, Name = "Gold Pouch", Description = "10 minutes of your income (at least 1K).", Icon = "🪙" },
		GoldLarge = { Id = 3724789928, Name = "Gold Hoard", Description = "1 hour of your income (at least 15K).", Icon = "👑" },
		InstantHatch = { Id = 3724790032, Name = "Instant Hatch", Description = "Hatch every egg on your perches right now.", Icon = "🐣" },
		LuckyFusion = { Id = 3724790238, Name = "Lucky Fusion", Description = "Your next fusion is guaranteed Golden or Shadow.", Icon = "🍀" },
		CalmDragon = { Id = 3724790441, Name = "Calm the Dragon", Description = "Puts the Elder Dragon to sleep for 90 seconds for the whole server.", Icon = "😴" },
	},
	-- How many seconds of income the gold packs give, and their minimums.
	GoldSmallSeconds = 600,
	GoldSmallMin = 1000,
	GoldLargeSeconds = 3600,
	GoldLargeMin = 15000,
}
