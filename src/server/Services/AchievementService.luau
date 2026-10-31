-- Lifetime achievements (Config/Achievements.luau). Progress comes from the
-- same events as quests: QuestService.Add forwards everything here.
-- Finishing one gives its reward automatically, and a Roblox badge if it has one.

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements = require(ReplicatedStorage.Shared.Config.Achievements)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)

local AchievementService = {}

-- Current value of a stat for a player.
local function value(data, stat: string): number
	if stat == "Rebirths" then
		return data.Rebirths
	elseif stat == "Discovered" then
		local n = 0
		for _ in data.Discovered do
			n += 1
		end
		return n
	elseif stat == "Perches" then
		return data.Perches
	elseif stat == "TotalEarned" then
		return data.TotalEarned
	end
	return data.Stats[stat] or 0
end

local function award(player: Player, data, a)
	data.Achievements[a.Id] = true
	Registry.DataService.Changed(player)
	local got = Registry.RewardService.Grant(player, a.Reward)
	Remotes.Notify:FireClient(player, ("🏅 Achievement: %s! %s"):format(a.Name, got), "Good", "NewDragon")
	if a.BadgeId and a.BadgeId ~= 0 then
		task.spawn(function()
			local ok, err = pcall(function()
				BadgeService:AwardBadge(player.UserId, a.BadgeId)
			end)
			if not ok then
				warn("[AchievementService] Couldn't award badge " .. a.BadgeId .. ": " .. tostring(err))
			end
		end)
	end
end

-- Awards anything newly finished.
function AchievementService.Check(player: Player)
	local data = Registry.DataService.Get(player)
	if not data then
		return
	end
	for _, a in Achievements do
		if not data.Achievements[a.Id] and value(data, a.Stat) >= a.Goal then
			award(player, data, a)
		end
	end
end

function AchievementService.Record(player: Player, stat: string, amount: number?)
	local data = Registry.DataService.Get(player)
	if not data then
		return
	end
	data.Stats[stat] = (data.Stats[stat] or 0) + (amount or 1)
	AchievementService.Check(player)
end

function AchievementService.Start()
	Registry.DataService.OnLoaded(function(player, data)
		data.Stats = data.Stats or {}
		data.Achievements = data.Achievements or {}
		task.delay(5, AchievementService.Check, player)
	end)
end

return AchievementService
