-- Free rewards that bring players back and keep them playing.
--
-- Daily: claim once per day (UTC). Coming back the next day grows your
-- streak; missing a day starts it over at day 1. Day 7 repeats after that.
-- Gifts: unlock after this many minutes in one session (reset when you rejoin).
--
-- Reward kinds:
--   Gold  = { Seconds = s, Min = m }   s seconds of your income, at least m
--   Egg   = { Rarity = "Rare", Mutation = "Golden"? }   goes on a free perch
--   LuckyFusion = n

return {
	Daily = {
		{ Gold = { Seconds = 300, Min = 500 } },
		{ Gold = { Seconds = 600, Min = 1500 } },
		{ LuckyFusion = 1 },
		{ Gold = { Seconds = 1200, Min = 5000 } },
		{ Egg = { Rarity = "Epic" } },
		{ Gold = { Seconds = 1800, Min = 15000 } },
		{ Egg = { Rarity = "Legendary", Mutation = "Golden" } },
	},
	Gifts = {
		{ Minutes = 2, Gold = { Seconds = 120, Min = 300 } },
		{ Minutes = 5, Egg = { Rarity = "Uncommon" } },
		{ Minutes = 10, Gold = { Seconds = 300, Min = 1000 } },
		{ Minutes = 15, Egg = { Rarity = "Rare" } },
		{ Minutes = 25, LuckyFusion = 1 },
		{ Minutes = 40, Egg = { Rarity = "Epic", Mutation = "Golden" } },
	},
}
