-- Time-based boosts that both server and client can check.

local Boosts = {}

Boosts.WeekendLuck = 2 -- Golden/Shadow chance multiplier on Saturday and Sunday (UTC)
Boosts.FriendBonusEach = 0.1 -- +10% gold per friend in your server
Boosts.FriendBonusMax = 0.3

function Boosts.IsWeekend(): boolean
	local day = os.date("!*t").wday -- 1 = Sunday, 7 = Saturday
	return day == 1 or day == 7
end

-- Mutation luck right now (1 normally, 2 on weekends).
function Boosts.Luck(): number
	return if Boosts.IsWeekend() then Boosts.WeekendLuck else 1
end

return Boosts
