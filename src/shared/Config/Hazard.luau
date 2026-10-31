-- The Elder Dragon. Every so often it sweeps the valley with a wall of fire,
-- starting at the far end and racing toward the castles. Anyone caught in the
-- open is knocked out and drops what they carry. Hide under a rock shelter.

return {
	-- Seconds between waves (start to start).
	Interval = 55,
	-- First wave after the server starts.
	FirstWave = 40,
	-- Warning shown before a wave starts.
	Warning = 6,
	-- The fire wall's thickness (studs) for hit checks.
	Thickness = 8,
	-- A "Calm the Dragon" purchase pushes the next wave back this long.
	CalmDelay = 90,

	Types = {
		{ Name = "Ember Breath", Speed = 75, Weight = 60, Color = Color3.fromRGB(255, 120, 30), Height = 34 },
		{ Name = "Swift Dive", Speed = 125, Weight = 25, Color = Color3.fromRGB(255, 50, 40), Height = 26 },
		{ Name = "Blue Inferno", Speed = 55, Weight = 15, Color = Color3.fromRGB(70, 140, 255), Height = 50 },
	},

	-- Safe spot under each shelter (relative to the shelter's base). Half sizes.
	ShelterHalfSize = Vector3.new(6.5, 9, 5.5),
}
