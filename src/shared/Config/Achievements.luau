-- Lifetime achievements. Stat is a lifetime counter (same names QuestService
-- reports) or one of: Rebirths, Discovered, Perches, TotalEarned.
-- BadgeId: make a badge in the Creator Dashboard (your experience >
-- Associated Items > Badges) and paste its ID to also award a real Roblox
-- badge. 0 = no badge, just the in-game reward.

local Dragons = require(script.Parent.Dragons)

return {
	{ Id = "first_egg", Name = "First Grab", Text = "Grab your first egg", Stat = "GrabEggs", Goal = 1, BadgeId = 0, Reward = { Gold = { Seconds = 60, Min = 200 } } },
	{ Id = "eggs_100", Name = "Egg Hunter", Text = "Grab 100 eggs", Stat = "GrabEggs", Goal = 100, BadgeId = 0, Reward = { Egg = { Rarity = "Rare" }, Spins = 1 } },
	{ Id = "eggs_1000", Name = "Egg Hoarder", Text = "Grab 1,000 eggs", Stat = "GrabEggs", Goal = 1000, BadgeId = 0, Reward = { Egg = { Rarity = "Legendary" }, Spins = 3 } },
	{ Id = "hatch_10", Name = "Nursery", Text = "Hatch 10 eggs", Stat = "Hatch", Goal = 10, BadgeId = 0, Reward = { Gold = { Seconds = 300, Min = 1000 } } },
	{ Id = "hatch_100", Name = "Dragon Daycare", Text = "Hatch 100 eggs", Stat = "Hatch", Goal = 100, BadgeId = 0, Reward = { Egg = { Rarity = "Epic", Mutation = "Golden" } } },
	{ Id = "waves_10", Name = "Fireproof", Text = "Survive 10 fire waves in the valley", Stat = "SurviveWaves", Goal = 10, BadgeId = 0, Reward = { Gold = { Seconds = 600, Min = 3000 }, Spins = 1 } },
	{ Id = "waves_100", Name = "Dragon Dodger", Text = "Survive 100 fire waves", Stat = "SurviveWaves", Goal = 100, BadgeId = 0, Reward = { Egg = { Rarity = "Legendary", Mutation = "Golden" } } },
	{ Id = "bonk_25", Name = "Bonk Master", Text = "Bonk 25 players", Stat = "Bonk", Goal = 25, BadgeId = 0, Reward = { Spins = 3 } },
	{ Id = "steal_1", Name = "Sneaky", Text = "Steal a dragon", Stat = "Steal", Goal = 1, BadgeId = 0, Reward = { Gold = { Seconds = 300, Min = 1000 } } },
	{ Id = "steal_25", Name = "Master Thief", Text = "Steal 25 dragons", Stat = "Steal", Goal = 25, BadgeId = 0, Reward = { Egg = { Rarity = "Mythic" } } },
	{ Id = "fuse_1", Name = "Alchemist", Text = "Fuse dragons once", Stat = "Fuse", Goal = 1, BadgeId = 0, Reward = { LuckyFusion = 1 } },
	{ Id = "fuse_25", Name = "Grand Alchemist", Text = "Fuse dragons 25 times", Stat = "Fuse", Goal = 25, BadgeId = 0, Reward = { LuckyFusion = 3 } },
	{ Id = "boss_1", Name = "Dragon Slayer", Text = "Help beat the Elder Dragon", Stat = "Boss", Goal = 1, BadgeId = 0, Reward = { Egg = { Rarity = "Legendary" }, Spins = 2 } },
	{ Id = "boss_10", Name = "Legend of the Valley", Text = "Help beat the Elder Dragon 10 times", Stat = "Boss", Goal = 10, BadgeId = 0, Reward = { Egg = { Rarity = "Mythic", Mutation = "Golden" } } },
	{ Id = "level_max", Name = "All Grown Up", Text = "Raise a dragon to Lv 10", Stat = "MaxLevel", Goal = 1, BadgeId = 0, Reward = { Egg = { Rarity = "Epic", Mutation = "Shadow" } } },
	{ Id = "rebirth_1", Name = "Born Again", Text = "Rebirth once", Stat = "Rebirths", Goal = 1, BadgeId = 0, Reward = { Spins = 3 } },
	{ Id = "rebirth_4", Name = "Crown Seeker", Text = "Reach Rebirth 4", Stat = "Rebirths", Goal = 4, BadgeId = 0, Reward = { Egg = { Rarity = "Divine" } } },
	{ Id = "found_all", Name = "Collector", Text = "Find every dragon", Stat = "Discovered", Goal = #Dragons.List, BadgeId = 0, Reward = { Egg = { Rarity = "Celestial" } } },
	{ Id = "perches", Name = "Full House", Text = "Own all 20 perches", Stat = "Perches", Goal = 20, BadgeId = 0, Reward = { Spins = 5 } },
	{ Id = "million", Name = "Millionaire", Text = "Earn 1M gold in total", Stat = "TotalEarned", Goal = 1e6, BadgeId = 0, Reward = { Egg = { Rarity = "Legendary" } } },
	{ Id = "billion", Name = "Billionaire", Text = "Earn 1B gold in total", Stat = "TotalEarned", Goal = 1e9, BadgeId = 0, Reward = { Egg = { Rarity = "Divine", Mutation = "Golden" } } },
	{ Id = "playtime", Name = "Dedicated", Text = "Play for 10 hours", Stat = "Minutes", Goal = 600, BadgeId = 0, Reward = { Egg = { Rarity = "Mythic" }, Spins = 5 } },
}
