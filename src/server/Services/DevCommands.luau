-- Chat commands for testing. Only work in Roblox Studio.
--
--   /gold 100000        add gold
--   /rebirth            rebirth for free
--   /give Solaris       put a dragon on a free perch (/give Solaris Golden)
--   /egg Magmaw         put an egg on a free perch
--   /hatch              hatch all eggs now
--   /wave               start a fire wave in a few seconds
--   /star               start a Star Shower (Celestial egg)
--   /speed 10           set speed level
--   /spins 5            add wheel spins
--   /quests             finish all of today's quests
--   /reset              wipe your data (kicks you; rejoin to start fresh)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)

local DevCommands = {}

local function findSpecies(name: string?)
	if not name then
		return nil
	end
	for _, s in Dragons.List do
		if s.Name:lower() == name:lower() then
			return s
		end
	end
	return nil
end

local function run(player: Player, message: string)
	local args = message:split(" ")
	local command = (args[1] or ""):lower()
	local data = Registry.DataService.Get(player)
	if not data then
		return
	end
	if command == "/gold" then
		Registry.DataService.AddGold(player, tonumber(args[2]) or 100000)
	elseif command == "/rebirth" then
		data.Gold += Economy.RebirthCost(data.Rebirths)
		Registry.RebirthService.Rebirth(player)
	elseif command == "/give" or command == "/egg" then
		local species = findSpecies(args[2])
		if not species then
			return Remotes.Notify:FireClient(player, "Unknown dragon: " .. tostring(args[2]), "Error")
		end
		local mutation = Dragons.MutationByName[args[3] or ""] and args[3] or nil
		local hatchAt = if command == "/egg" then os.time() + Rarities.ByName[species.Rarity].HatchTime else nil
		if not Registry.BaseService.AddToFreeSlot(player, { Species = species.Name, Mutation = mutation, HatchAt = hatchAt }) then
			Remotes.Notify:FireClient(player, "No free perch.", "Error")
		end
	elseif command == "/hatch" then
		Registry.BaseService.HatchAll(player)
	elseif command == "/wave" then
		Registry.HazardService.TriggerNow()
	elseif command == "/star" then
		Registry.EventService.StarShower()
	elseif command == "/speed" then
		data.SpeedLevel = math.clamp(tonumber(args[2]) or 10, 0, Economy.MaxSpeedLevel)
		Registry.UpgradeService.ApplySpeed(player)
	elseif command == "/spins" then
		data.Spins += tonumber(args[2]) or 5
	elseif command == "/quests" then
		for _, stat in { "GrabEggs", "GrabRare", "Hatch", "SurviveWaves", "Bonk", "Steal", "Fuse", "Upgrade", "Collect", "Minutes" } do
			Registry.QuestService.Add(player, stat, 999)
		end
	elseif command == "/reset" then
		Registry.DataService.Reset(player)
		return
	else
		return
	end
	Registry.DataService.Changed(player)
end

function DevCommands.Start()
	if not RunService:IsStudio() then
		return
	end
	local function hook(player: Player)
		player.Chatted:Connect(function(message)
			run(player, message)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return DevCommands
