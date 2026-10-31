-- The Elder Dragon boss. Every so often it lands in the valley; everyone
-- bonks it together. Beat it before it flies off and it drops treasure.

return {
	Interval = 20 * 60, -- seconds between landings
	FirstLanding = 8 * 60, -- after the server starts
	Duration = 100, -- seconds it stays before flying away
	Zones = { 2, 3, 4 }, -- zones it can land in (open to everyone)
	Health = 25, -- base hits to beat it...
	HealthPerPlayer = 15, -- ...plus this per player in the server
	HitRange = 18, -- how close you must be to bonk it
	StompEvery = 7, -- seconds between stomps
	StompWarning = 1.6, -- seconds the red circle shows before it lands
	StompRadius = 20,
	EggRain = 14, -- wild eggs that fall around it when beaten
	-- Everyone who hit it gets this; the top hitter's egg is Golden.
	Reward = { Gold = { Seconds = 900, Min = 5000 } },
}
