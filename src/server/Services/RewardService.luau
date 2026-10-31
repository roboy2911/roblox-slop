-- Daily login rewards (with a streak) and playtime gifts. See Config/Rewards.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)

local RewardService = {}

local sessions: { [Player]: { Start: number, Claimed: { [number]: boolean } } } = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

-- Which streak day you'd claim today (1-7), or nil if already claimed.
local function dailyDay(data): number?
	local daily = data.Daily
	if daily.Last == today() then
		return nil
	end
	local streak = if daily.Last == today() - 1 then daily.Streak + 1 else 1
	return math.min(streak, #Rewards.Daily)
end

local function publish(player: Player)
	local data = Registry.DataService.Get(player)
	local session = sessions[player]
	if not data or not session then
		return
	end
	Registry.DataService.SetExtra(player, "DailyDay", dailyDay(data))
	Registry.DataService.SetExtra(player, "DailyStreak", data.Daily.Streak)
	Registry.DataService.SetExtra(player, "DailyLast", data.Daily.Last)
	Registry.DataService.SetExtra(player, "SessionStart", session.Start)
	local claimed = {}
	for i in session.Claimed do
		table.insert(claimed, i)
	end
	Registry.DataService.SetExtra(player, "GiftsClaimed", claimed)
end

-- Gives a reward. Returns a short description of what was given.
local function grant(player: Player, reward): string
	local data = Registry.DataService.Get(player)
	if not data then
		return ""
	end
	local parts = {}
	if reward.Gold then
		local income = Registry.BaseService.IncomePerSecond(player)
		local amount = math.floor(math.max(reward.Gold.Min, income * reward.Gold.Seconds))
		Registry.DataService.AddGold(player, amount)
		table.insert(parts, Format.Gold(amount))
	end
	if reward.Spins then
		data.Spins += reward.Spins
		Registry.DataService.Changed(player)
		table.insert(parts, reward.Spins .. (if reward.Spins == 1 then " Spin" else " Spins"))
	end
	if reward.LuckyFusion then
		data.LuckyFusions += reward.LuckyFusion
		Registry.DataService.Changed(player)
		table.insert(parts, reward.LuckyFusion .. " Lucky Fusion")
	end
	if reward.Egg then
		local rarity = Rarities.ByName[reward.Egg.Rarity]
		local species = Dragons.RollSpecies(rarity.Name)
		local slot = Registry.BaseService.AddToFreeSlot(player, {
			Species = species.Name,
			Mutation = reward.Egg.Mutation,
			HatchAt = os.time() + rarity.HatchTime,
		})
		local name = (if reward.Egg.Mutation then reward.Egg.Mutation .. " " else "") .. rarity.Name .. " Egg"
		if slot then
			table.insert(parts, name .. " (on your perch)")
		else
			-- No room: pay out what the dragon would sell for instead.
			local amount = math.floor(Dragons.BaseIncome(species.Name, reward.Egg.Mutation) * Dragons.SellSeconds)
			Registry.DataService.AddGold(player, amount)
			table.insert(parts, Format.Gold(amount) .. " (perches full, so gold instead of a " .. name .. ")")
		end
	end
	return table.concat(parts, " + ")
end

local function claimDaily(player: Player)
	local data = Registry.DataService.Get(player)
	if not data then
		return
	end
	local day = dailyDay(data)
	if not day then
		return Remotes.Notify:FireClient(player, "Come back tomorrow for your next daily reward!", "Warn")
	end
	data.Daily.Streak = if data.Daily.Last == today() - 1 then data.Daily.Streak + 1 else 1
	data.Daily.Last = today()
	local got = grant(player, Rewards.Daily[day])
	Registry.DataService.Changed(player)
	publish(player)
	Remotes.Notify:FireClient(player, ("Day %d reward: %s"):format(day, got), "Good", "Upgrade")
	task.spawn(Registry.DataService.SaveNow, player)
end

local function claimGift(player: Player, index: any)
	local session = sessions[player]
	local gift = typeof(index) == "number" and Rewards.Gifts[index]
	if not session or not gift or session.Claimed[index] then
		return
	end
	if workspace:GetServerTimeNow() - session.Start < gift.Minutes * 60 - 1 then
		return Remotes.Notify:FireClient(player, "That gift isn't ready yet!", "Error")
	end
	session.Claimed[index] = true
	local got = grant(player, gift)
	publish(player)
	Remotes.Notify:FireClient(player, "Gift: " .. got, "Good", "Upgrade")
end

RewardService.Grant = grant

function RewardService.Start()
	Remotes.ClaimDaily.OnServerEvent:Connect(claimDaily)
	Remotes.ClaimGift.OnServerEvent:Connect(claimGift)
	Registry.DataService.OnLoaded(function(player, data)
		data.Daily = data.Daily or { Last = 0, Streak = 0 }
		sessions[player] = { Start = workspace:GetServerTimeNow(), Claimed = {} }
		publish(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return RewardService
