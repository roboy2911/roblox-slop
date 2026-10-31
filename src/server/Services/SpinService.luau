-- The prize wheel. Spins come from playtime (one every few minutes), quests
-- and the 5-spin pack. The server picks the prize; the client spins the
-- wheel to land on it, then the prize is given.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spin = require(ReplicatedStorage.Shared.Config.Spin)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)

local SpinService = {}

local SPIN_TIME = 4 -- seconds the wheel spins on screen before the prize is given

local rng = Random.new()
local spinning: { [Player]: boolean } = {}
local played: { [Player]: number } = {} -- seconds played toward the next free spin

local function pick(): number
	local total = 0
	for _, prize in Spin.Prizes do
		total += prize.Weight
	end
	local roll = rng:NextNumber() * total
	for i, prize in Spin.Prizes do
		roll -= prize.Weight
		if roll <= 0 then
			return i
		end
	end
	return 1
end

local function spin(player: Player): (number?, string)
	local data = Registry.DataService.Get(player)
	if not data or spinning[player] then
		return nil, "Wait for the wheel to stop!"
	end
	if data.Spins <= 0 then
		return nil, "No spins left! You get a free one every " .. Spin.FreeEveryMinutes .. " minutes."
	end
	data.Spins -= 1
	Registry.DataService.Changed(player)
	spinning[player] = true
	local index = pick()
	local prize = Spin.Prizes[index]
	task.delay(SPIN_TIME, function()
		spinning[player] = nil
		if not player.Parent then
			return
		end
		local got = Registry.RewardService.Grant(player, prize)
		local big = prize.Label == "JACKPOT" or prize.Label == "Legendary Egg"
		Remotes.Notify:FireClient(player, "You won: " .. got, "Good", if big then "NewDragon" else "Upgrade")
		if big then
			Remotes.Announce:FireAllClients(("%s won %s on the wheel!"):format(player.DisplayName, prize.Label), prize.Color, "Star")
		end
	end)
	return index, prize.Label
end

function SpinService.Start()
	Remotes.Spin.OnServerInvoke = spin
	Players.PlayerRemoving:Connect(function(player)
		spinning[player] = nil
		played[player] = nil
	end)
	-- Free spins for playing.
	task.spawn(function()
		while true do
			task.wait(10)
			for _, player in Players:GetPlayers() do
				local data = Registry.DataService.Get(player)
				if data then
					played[player] = (played[player] or 0) + 10
					local nextIn = Spin.FreeEveryMinutes * 60 - played[player]
					if nextIn <= 0 then
						played[player] = 0
						nextIn = Spin.FreeEveryMinutes * 60
						data.Spins += 1
						Registry.DataService.Changed(player)
						Remotes.Notify:FireClient(player, "🎡 Free spin earned! Open the wheel.", "Good", "Upgrade")
					end
					Registry.DataService.SetExtra(player, "NextSpinIn", nextIn)
				end
			end
		end
	end)
end

return SpinService
