-- Works out a player's gold per second from their saved data.
-- Used by the server (to pay out) and the client (to show numbers).

local Dragons = require(script.Parent.Config.Dragons)
local Economy = require(script.Parent.Config.Economy)
local Levels = require(script.Parent.Levels)
local Rarities = require(script.Parent.Config.Rarities)

local Income = {}

-- Rarities where every species has been discovered.
function Income.CompletedRarities(discovered: { [string]: boolean }): number
	local count = 0
	for _, rarity in Rarities.List do
		local pool = Dragons.ByRarity[rarity.Name]
		if pool then
			local all = true
			for _, species in pool do
				if not discovered[species.Name] then
					all = false
					break
				end
			end
			if all then
				count += 1
			end
		end
	end
	return count
end

-- Everything that multiplies income.
function Income.Multiplier(data: any, hasDoubleGold: boolean): number
	local m = Economy.IncomeMultiplier(data.Rebirths or 0)
	m *= 1 + Income.CompletedRarities(data.Discovered or {}) * Economy.IndexBonusPerRarity
	if hasDoubleGold then
		m *= 2
	end
	return m
end

-- One slot's gold per second (0 for eggs and dragons being stolen).
function Income.Slot(slot: any): number
	if not slot or slot.HatchAt or slot.Stolen then
		return 0
	end
	return Dragons.BaseIncome(slot.Species, slot.Mutation) * Levels.Multiplier(Levels.FromAge(slot.Age))
end

function Income.PerSecond(data: any, hasDoubleGold: boolean): number
	local total = 0
	for _, slot in data.Slots or {} do
		total += Income.Slot(slot)
	end
	return total * Income.Multiplier(data, hasDoubleGold)
end

return Income
