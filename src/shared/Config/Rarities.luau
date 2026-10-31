-- Rarity tiers, from most common to rarest.
-- HatchTime: seconds an egg of this rarity takes to hatch on a perch.
-- Scale: how much bigger dragons of this rarity look on the perch.

export type Rarity = {
	Name: string,
	Order: number,
	Color: Color3,
	HatchTime: number,
	EggModel: string,
	Scale: number,
}

local list: { Rarity } = {
	{ Name = "Common", Order = 1, Color = Color3.fromRGB(190, 190, 190), HatchTime = 5, EggModel = "EggCommon", Scale = 1.0 },
	{ Name = "Uncommon", Order = 2, Color = Color3.fromRGB(95, 215, 90), HatchTime = 10, EggModel = "EggUncommon", Scale = 1.08 },
	{ Name = "Rare", Order = 3, Color = Color3.fromRGB(70, 150, 255), HatchTime = 20, EggModel = "EggRare", Scale = 1.16 },
	{ Name = "Epic", Order = 4, Color = Color3.fromRGB(190, 85, 255), HatchTime = 40, EggModel = "EggEpic", Scale = 1.25 },
	{ Name = "Legendary", Order = 5, Color = Color3.fromRGB(255, 190, 40), HatchTime = 75, EggModel = "EggLegendary", Scale = 1.35 },
	{ Name = "Mythic", Order = 6, Color = Color3.fromRGB(255, 60, 120), HatchTime = 120, EggModel = "EggMythic", Scale = 1.45 },
	{ Name = "Celestial", Order = 7, Color = Color3.fromRGB(120, 230, 255), HatchTime = 180, EggModel = "EggCelestial", Scale = 1.6 },
}

local byName: { [string]: Rarity } = {}
for _, r in list do
	byName[r.Name] = r
end

return {
	List = list,
	ByName = byName,
	-- The rarity one step up (for fusing), or nil at the top.
	Next = function(name: string): Rarity?
		local r = byName[name]
		return r and list[r.Order + 1]
	end,
}
