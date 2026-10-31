-- Every baby dragon species. Names match the Blender models (blender/dragons.py).
-- Income: gold per second while sitting on a perch (before bonuses).
-- Weight: how often it hatches compared to others of the same rarity.
-- Color: used for the stand-in model and UI accents.

export type Species = {
	Name: string,
	Rarity: string,
	Income: number,
	Weight: number,
	Color: Color3,
	Blurb: string,
}

local list: { Species } = {
	{ Name = "Mossling", Rarity = "Common", Income = 3, Weight = 60, Color = Color3.fromRGB(82, 158, 61), Blurb = "Naps in flower beds. Smells like rain." },
	{ Name = "Pebblewing", Rarity = "Common", Income = 4, Weight = 40, Color = Color3.fromRGB(128, 128, 133), Blurb = "Eats gravel. Somehow still cute." },
	{ Name = "Emberkit", Rarity = "Uncommon", Income = 12, Weight = 60, Color = Color3.fromRGB(235, 107, 31), Blurb = "Its tail is always lit. Do not hug." },
	{ Name = "Reedscale", Rarity = "Uncommon", Income = 15, Weight = 40, Color = Color3.fromRGB(38, 140, 140), Blurb = "Swims faster than it flies." },
	{ Name = "Frostfang", Rarity = "Rare", Income = 50, Weight = 60, Color = Color3.fromRGB(140, 199, 242), Blurb = "Sneezes snowflakes." },
	{ Name = "Thornback", Rarity = "Rare", Income = 60, Weight = 40, Color = Color3.fromRGB(31, 89, 38), Blurb = "Grows a new thorn every birthday." },
	{ Name = "Magmaw", Rarity = "Epic", Income = 200, Weight = 60, Color = Color3.fromRGB(255, 115, 20), Blurb = "Born in a volcano. Still warm." },
	{ Name = "Stormtail", Rarity = "Epic", Income = 240, Weight = 40, Color = Color3.fromRGB(97, 56, 158), Blurb = "Its tail crackles before storms." },
	{ Name = "Solaris", Rarity = "Legendary", Income = 900, Weight = 60, Color = Color3.fromRGB(255, 158, 20), Blurb = "Glows brighter at noon." },
	{ Name = "Glacius", Rarity = "Legendary", Income = 1050, Weight = 40, Color = Color3.fromRGB(31, 64, 191), Blurb = "Carved from the oldest ice." },
	{ Name = "Voidwyrm", Rarity = "Mythic", Income = 4000, Weight = 60, Color = Color3.fromRGB(115, 51, 166), Blurb = "Nobody knows where it came from." },
	{ Name = "Aurora", Rarity = "Mythic", Income = 4800, Weight = 40, Color = Color3.fromRGB(77, 230, 191), Blurb = "Shimmers every color of the northern sky." },
	{ Name = "Starborn", Rarity = "Celestial", Income = 20000, Weight = 100, Color = Color3.fromRGB(40, 50, 140), Blurb = "Fell from the stars. Only falls during star showers." },
}

-- Golden and Shadow dragons earn more. Chance is per egg found in the valley.
local mutations = {
	{ Name = "Golden", Multiplier = 2, Chance = 0.05, Color = Color3.fromRGB(255, 205, 50) },
	{ Name = "Shadow", Multiplier = 3, Chance = 0.015, Color = Color3.fromRGB(150, 70, 255) },
}

local byName: { [string]: Species } = {}
local byRarity: { [string]: { Species } } = {}
for _, s in list do
	byName[s.Name] = s
	byRarity[s.Rarity] = byRarity[s.Rarity] or {}
	table.insert(byRarity[s.Rarity], s)
end

local mutationByName = {}
for _, m in mutations do
	mutationByName[m.Name] = m
end

local Dragons = {
	List = list,
	ByName = byName,
	ByRarity = byRarity,
	Mutations = mutations,
	MutationByName = mutationByName,
	-- A dragon sells for this many seconds of its income.
	SellSeconds = 40,
}

-- A random species of the given rarity, weighted.
function Dragons.RollSpecies(rarity: string, rng: Random?): Species
	local pool = byRarity[rarity]
	local total = 0
	for _, s in pool do
		total += s.Weight
	end
	local roll = (rng or Random.new()):NextNumber() * total
	for _, s in pool do
		roll -= s.Weight
		if roll <= 0 then
			return s
		end
	end
	return pool[#pool]
end

-- "Golden", "Shadow" or nil.
function Dragons.RollMutation(luckMultiplier: number?, rng: Random?): string?
	local roll = (rng or Random.new()):NextNumber()
	local luck = luckMultiplier or 1
	-- Check the rarest first.
	for i = #mutations, 1, -1 do
		local m = mutations[i]
		if roll < m.Chance * luck then
			return m.Name
		end
		roll -= m.Chance * luck
	end
	return nil
end

-- Gold per second for one dragon before player bonuses.
function Dragons.BaseIncome(species: string, mutation: string?): number
	local s = byName[species]
	if not s then
		return 0
	end
	local m = mutation and mutationByName[mutation]
	return s.Income * (if m then m.Multiplier else 1)
end

return Dragons
