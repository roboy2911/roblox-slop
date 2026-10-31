-- The valley in front of the castles, split into zones. The farther from
-- home, the rarer the eggs. Z runs from the castles (0) out into the valley.
--
-- Rarities: chance of each egg rarity in this zone (adds up to 1).
-- Rebirths: rebirths needed to enter (0 = open to everyone).

export type Zone = {
	Name: string,
	StartZ: number,
	EndZ: number,
	Rarities: { [string]: number },
	Rebirths: number,
	Ground: Enum.Material,
	GroundColor: Color3,
	Decor: { string },
	Fog: Color3,
}

local LENGTH = 150

local zones: { Zone } = {
	{
		Name = "Sunny Meadow",
		Rarities = { Common = 0.9, Uncommon = 0.1 },
		Rebirths = 0,
		Ground = Enum.Material.Grass,
		GroundColor = Color3.fromRGB(106, 168, 72),
		Decor = { "FlowerBush", "OakTree" },
		Fog = Color3.fromRGB(200, 230, 255),
	},
	{
		Name = "Pinewood",
		Rarities = { Uncommon = 0.88, Rare = 0.1, Common = 0.02 },
		Rebirths = 0,
		Ground = Enum.Material.LeafyGrass,
		GroundColor = Color3.fromRGB(70, 128, 58),
		Decor = { "PineTree", "Mushroom" },
		Fog = Color3.fromRGB(180, 215, 200),
	},
	{
		Name = "Crag Hills",
		Rarities = { Rare = 0.88, Epic = 0.1, Uncommon = 0.02 },
		Rebirths = 0,
		Ground = Enum.Material.Slate,
		GroundColor = Color3.fromRGB(128, 120, 110),
		Decor = { "Boulder", "PineTree" },
		Fog = Color3.fromRGB(200, 200, 205),
	},
	{
		Name = "Ember Wastes",
		Rarities = { Epic = 0.88, Legendary = 0.1, Rare = 0.02 },
		Rebirths = 0,
		Ground = Enum.Material.Basalt,
		GroundColor = Color3.fromRGB(60, 45, 42),
		Decor = { "LavaRock" },
		Fog = Color3.fromRGB(255, 160, 110),
	},
	{
		Name = "Frost Peak",
		Rarities = { Legendary = 0.88, Mythic = 0.1, Epic = 0.02 },
		Rebirths = 1,
		Ground = Enum.Material.Snow,
		GroundColor = Color3.fromRGB(235, 242, 250),
		Decor = { "IceSpire", "Boulder" },
		Fog = Color3.fromRGB(220, 235, 255),
	},
	{
		Name = "Void Rift",
		Rarities = { Mythic = 0.92, Legendary = 0.08 },
		Rebirths = 2,
		Ground = Enum.Material.Slate,
		GroundColor = Color3.fromRGB(40, 30, 60),
		Decor = { "VoidCrystal" },
		Fog = Color3.fromRGB(150, 100, 220),
	},
} :: any

for i, zone in zones do
	zone.StartZ = (i - 1) * LENGTH
	zone.EndZ = i * LENGTH
end

local Zones = {
	List = zones,
	Length = LENGTH,
	ValleyEnd = #zones * LENGTH,
	-- Half the width of the valley (it runs from -HalfWidth to HalfWidth in X).
	HalfWidth = 310,
}

-- The zone at a Z position, or nil if outside the valley.
function Zones.At(z: number): (Zone?, number?)
	if z < 0 then
		return nil, nil
	end
	local i = math.floor(z / LENGTH) + 1
	if i > #zones then
		return nil, nil
	end
	return zones[i], i
end

-- Picks an egg rarity for a zone.
function Zones.RollRarity(zone: Zone, rng: Random): string
	local roll = rng:NextNumber()
	local last = "Common"
	for rarity, chance in zone.Rarities do
		last = rarity
		roll -= chance
		if roll <= 0 then
			return rarity
		end
	end
	return last
end

return Zones
