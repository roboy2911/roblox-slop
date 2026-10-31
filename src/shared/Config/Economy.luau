-- Prices and numbers for upgrades, rebirths, carrying, stealing and locking.

local Economy = {}

Economy.StartingGold = 100
-- The first time someone plays they get this dragon for free, so gold starts flowing right away.
Economy.StarterDragon = "Mossling"

-- Walking speed.
Economy.BaseSpeed = 22
Economy.SpeedPerLevel = 2
Economy.MaxSpeedLevel = 20
Economy.SpeedPerRebirth = 3
Economy.VipSpeedBonus = 8
-- Each extra egg you carry slows you down a little; a stolen dragon slows you a lot.
Economy.CarrySlowdown = 0.94
Economy.StolenSlowdown = 0.72

function Economy.SpeedCost(level: number): number
	-- Price to go from `level` to `level + 1`.
	return math.floor(100 * 1.6 ^ level)
end

-- How many eggs you can carry at once, by carry level (index 1 = level 0).
Economy.CarryCapacity = { 1, 2, 3, 4, 5 }
Economy.CarryCosts = { 2500, 40000, 600000, 8000000 } -- price of level 1, 2, 3, 4

-- Perches (dragon slots) at your castle.
Economy.StartingPerches = 6
Economy.MaxPerches = 20
function Economy.PerchCost(owned: number): number
	-- Price of the next perch when you own `owned`.
	return math.floor(1500 * 2.2 ^ (owned - Economy.StartingPerches))
end

-- Rebirth: costs gold, resets gold, speed and carry upgrades.
-- Keeps your dragons and perches. Each rebirth multiplies income.
function Economy.RebirthCost(rebirths: number): number
	return math.floor(250000 * 6 ^ rebirths)
end
Economy.RebirthIncomeBonus = 0.5 -- +50% income per rebirth

function Economy.IncomeMultiplier(rebirths: number): number
	return 1 + rebirths * Economy.RebirthIncomeBonus
end

-- Finding every species of one rarity in the Index gives a permanent bonus.
Economy.IndexBonusPerRarity = 0.05

-- Gold earned while offline: this share of your normal income, for up to MaxOfflineHours.
Economy.OfflineRate = 0.25
Economy.MaxOfflineHours = 4

-- Stealing.
Economy.StealHoldBase = 2 -- seconds to hold the Steal prompt
Economy.StealHoldPerRarity = 0.5 -- + this per rarity tier above Common
Economy.StealTimeout = 75 -- a stolen dragon goes home if not delivered in time
-- Revenge: while someone steals from you, you're this much faster...
Economy.RevengeSpeed = 1.35
-- ...and bonking your own thief pays this many seconds of your income (at least RevengeMin).
Economy.RevengeSeconds = 120
Economy.RevengeMin = 1000

-- Locking your gate.
function Economy.LockDuration(rebirths: number): number
	return math.min(120, 45 + rebirths * 10)
end

-- Bonking.
Economy.BonkCooldown = 0.9
Economy.BonkRange = 8
Economy.BonkKnockback = 55

-- Fusing 3 dragons of one rarity into 1 of the next rarity.
Economy.FuseCount = 3
Economy.FuseMutationLuck = 2 -- fused dragons are twice as likely to be Golden or Shadow

return Economy
