-- Rebirth: pay gold to reset your gold, speed and carry upgrades. You keep
-- your dragons and perches, earn more gold forever, walk faster, lock your
-- castle longer, and unlock Frost Peak (1) and the Void Rift (2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)

local RebirthService = {}

function RebirthService.Rebirth(player: Player)
	local data = Registry.DataService.Get(player)
	if not data then
		return
	end
	local cost = Economy.RebirthCost(data.Rebirths)
	if data.Gold < cost then
		return Remotes.Notify:FireClient(player, "You need " .. Format.Gold(cost) .. " to rebirth.", "Error")
	end
	data.Gold = 0
	data.Pending = 0
	data.SpeedLevel = 0
	data.CarryLevel = 0
	data.Rebirths += 1
	Registry.DataService.Changed(player)
	Registry.EggService.TrimToCapacity(player)
	Registry.UpgradeService.ApplySpeed(player)
	Registry.BaseService.RefreshLabels(player)
	Registry.LeaderboardService.Update(player)
	Registry.AchievementService.Check(player)
	Remotes.Announce:FireAllClients(("%s reached Rebirth %d!"):format(player.DisplayName, data.Rebirths), Color3.fromRGB(200, 140, 255))
	Remotes.Notify:FireClient(player, ("Rebirth %d! Income is now x%s."):format(data.Rebirths, tostring(Economy.IncomeMultiplier(data.Rebirths))), "Good", "Rebirth")
end

function RebirthService.Start()
	Remotes.Rebirth.OnServerEvent:Connect(RebirthService.Rebirth)
end

return RebirthService
