-- Friends and pets.
--
-- Friend bonus: +10% gold for each Roblox friend in your server (max +30%).
-- Pet: pick any dragon you've discovered (Index menu) and it follows you
-- around. The choice is saved; clients draw the pets (player attribute "Pet").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Boosts = require(ReplicatedStorage.Shared.Boosts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)

local SocialService = {}

local friends: { [Player]: { [Player]: boolean } } = {}

function SocialService.FriendBonus(player: Player): number
	local count = 0
	for other, isFriend in friends[player] or {} do
		if isFriend and other.Parent then
			count += 1
		end
	end
	return math.min(Boosts.FriendBonusMax, count * Boosts.FriendBonusEach)
end

local function publish(player: Player)
	local bonus = SocialService.FriendBonus(player)
	Registry.DataService.SetExtra(player, "FriendBonus", bonus)
	Registry.BaseService.RefreshIncome(player)
end

local function checkFriends(newcomer: Player)
	friends[newcomer] = friends[newcomer] or {}
	for _, other in Players:GetPlayers() do
		if other ~= newcomer then
			local ok, isFriend = pcall(function()
				return newcomer:IsFriendsWith(other.UserId)
			end)
			isFriend = ok and isFriend
			friends[newcomer][other] = isFriend
			friends[other] = friends[other] or {}
			friends[other][newcomer] = isFriend
			if isFriend then
				Remotes.Notify:FireClient(other, ("Your friend %s joined! +%d%% gold while you play together."):format(newcomer.DisplayName, Boosts.FriendBonusEach * 100), "Good", "Upgrade")
				Remotes.Notify:FireClient(newcomer, ("Playing with your friend %s: +%d%% gold!"):format(other.DisplayName, Boosts.FriendBonusEach * 100), "Good")
				publish(other)
			end
		end
	end
	publish(newcomer)
end

local function setPet(player: Player, species: any)
	local data = Registry.DataService.Get(player)
	if not data then
		return
	end
	if species == nil then
		data.Pet = nil
	elseif typeof(species) == "string" and Dragons.ByName[species] and data.Discovered[species] then
		data.Pet = species
	else
		return
	end
	player:SetAttribute("Pet", data.Pet)
	Registry.DataService.Changed(player)
end

function SocialService.Start()
	Remotes.SetPet.OnServerEvent:Connect(setPet)
	Registry.DataService.OnLoaded(function(player, data)
		if data.Pet and data.Discovered[data.Pet] then
			player:SetAttribute("Pet", data.Pet)
		end
		checkFriends(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		friends[player] = nil
		for other, list in friends do
			if list[player] then
				list[player] = nil
				task.defer(publish, other)
			end
		end
	end)
end

return SocialService
