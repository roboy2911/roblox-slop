-- Buying upgrades (speed, carry, perches) and setting your walk speed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)

local UpgradeService = {}

function UpgradeService.BaseSpeed(player: Player): number
	local data = Registry.DataService.Get(player)
	if not data then
		return Economy.BaseSpeed
	end
	local speed = Economy.BaseSpeed + data.SpeedLevel * Economy.SpeedPerLevel + data.Rebirths * Economy.SpeedPerRebirth
	if Registry.ShopService.HasPass(player, "VipSpeed") then
		speed += Economy.VipSpeedBonus
	end
	return speed
end

function UpgradeService.ApplySpeed(player: Player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local speed = UpgradeService.BaseSpeed(player)
	local carried = Registry.EggService.Count(player)
	if carried > 0 then
		speed *= Economy.CarrySlowdown ^ carried
	end
	if Registry.StealService.IsStealing(player) then
		speed *= Economy.StolenSlowdown
	end
	humanoid.WalkSpeed = speed
	Registry.DataService.SetExtra(player, "Speed", math.floor(speed + 0.5))
end

local function buy(player: Player, kind: any)
	local data = Registry.DataService.Get(player)
	if not data then
		return
	end
	if kind == "Speed" then
		if data.SpeedLevel >= Economy.MaxSpeedLevel then
			return Remotes.Notify:FireClient(player, "Speed is maxed! Rebirth for more.", "Warn")
		end
		local cost = Economy.SpeedCost(data.SpeedLevel)
		if not Registry.DataService.SpendGold(player, cost) then
			return Remotes.Notify:FireClient(player, "Not enough gold! You need " .. Format.Gold(cost), "Error")
		end
		data.SpeedLevel += 1
		UpgradeService.ApplySpeed(player)
	elseif kind == "Carry" then
		local cost = Economy.CarryCosts[data.CarryLevel + 1]
		if not cost then
			return Remotes.Notify:FireClient(player, "Carry is maxed!", "Warn")
		end
		if not Registry.DataService.SpendGold(player, cost) then
			return Remotes.Notify:FireClient(player, "Not enough gold! You need " .. Format.Gold(cost), "Error")
		end
		data.CarryLevel += 1
		Registry.DataService.SetExtra(player, "Capacity", Registry.EggService.Capacity(player))
	elseif kind == "Perch" then
		if data.Perches >= Economy.MaxPerches then
			return Remotes.Notify:FireClient(player, "Your castle is full of perches!", "Warn")
		end
		local cost = Economy.PerchCost(data.Perches)
		if not Registry.DataService.SpendGold(player, cost) then
			return Remotes.Notify:FireClient(player, "Not enough gold! You need " .. Format.Gold(cost), "Error")
		end
		data.Perches += 1
		Registry.BaseService.AddPerch(player)
	else
		return
	end
	Registry.DataService.Changed(player)
	Remotes.Notify:FireClient(player, "Upgraded!", "Good")
end

function UpgradeService.Start()
	Remotes.BuyUpgrade.OnServerEvent:Connect(buy)
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			UpgradeService.ApplySpeed(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Registry.DataService.OnLoaded(function(player)
		UpgradeService.ApplySpeed(player)
	end)
end

return UpgradeService
