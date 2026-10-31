-- Dragon levels. A hatched dragon on a perch gains 1 point of "Age" per
-- second (and some while you're offline). Each level adds income.

local Levels = {}

Levels.Max = 10
Levels.BonusPerLevel = 0.1 -- +10% income per level above 1 (Lv 10 = +90%)
-- Seconds of age needed for each level (index = level).
Levels.Needed = { 0, 120, 400, 900, 1800, 3600, 6000, 9000, 14000, 20000 }
-- While you're offline, dragons age at this rate (for up to 4 hours).
Levels.OfflineRate = 0.5

function Levels.FromAge(age: number?): number
	local a = age or 0
	local level = 1
	for i = 2, Levels.Max do
		if a >= Levels.Needed[i] then
			level = i
		end
	end
	return level
end

function Levels.Multiplier(level: number): number
	return 1 + (level - 1) * Levels.BonusPerLevel
end

-- 0..1 progress toward the next level.
function Levels.Progress(age: number?): number
	local a = age or 0
	local level = Levels.FromAge(a)
	if level >= Levels.Max then
		return 1
	end
	local from, to = Levels.Needed[level], Levels.Needed[level + 1]
	return math.clamp((a - from) / (to - from), 0, 1)
end

return Levels
