-- Daily quests. Everyone gets 3 from this list each day (UTC), picked at random
-- per player. Stat: what counts toward it (see QuestService.Add calls).
-- Rewards use the same kinds as Rewards.luau, plus Spins.

return {
	PerDay = 3,
	List = {
		{ Id = "grab", Stat = "GrabEggs", Goal = 15, Text = "Grab %d eggs", Reward = { Gold = { Seconds = 600, Min = 2000 }, Spins = 1 } },
		{ Id = "grabrare", Stat = "GrabRare", Goal = 5, Text = "Grab %d Rare or better eggs", Reward = { Egg = { Rarity = "Epic" }, Spins = 1 } },
		{ Id = "hatch", Stat = "Hatch", Goal = 8, Text = "Hatch %d eggs", Reward = { Gold = { Seconds = 600, Min = 2000 }, Spins = 1 } },
		{ Id = "survive", Stat = "SurviveWaves", Goal = 3, Text = "Survive %d fire waves in the valley", Reward = { Egg = { Rarity = "Rare", Mutation = "Golden" }, Spins = 1 } },
		{ Id = "bonk", Stat = "Bonk", Goal = 2, Text = "Bonk %d players", Reward = { Gold = { Seconds = 300, Min = 1000 }, Spins = 1 } },
		{ Id = "steal", Stat = "Steal", Goal = 1, Text = "Steal %d dragon", Reward = { LuckyFusion = 1, Spins = 1 } },
		{ Id = "fuse", Stat = "Fuse", Goal = 1, Text = "Fuse dragons %d time", Reward = { Gold = { Seconds = 900, Min = 3000 }, Spins = 1 } },
		{ Id = "upgrade", Stat = "Upgrade", Goal = 3, Text = "Buy %d upgrades", Reward = { Gold = { Seconds = 300, Min = 1000 }, Spins = 1 } },
		{ Id = "collect", Stat = "Collect", Goal = 20, Text = "Collect gold from your chest %d times", Reward = { Gold = { Seconds = 600, Min = 2000 }, Spins = 1 } },
		{ Id = "play", Stat = "Minutes", Goal = 20, Text = "Play for %d minutes", Reward = { Egg = { Rarity = "Epic" }, Spins = 2 } },
	},
}
