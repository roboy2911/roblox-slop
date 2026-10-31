-- The Elder Dragon's fire waves.
--
-- The next wave's start time, type and speed are published as attributes on
-- ReplicatedStorage.Hazard, so every client can draw the same wave and the
-- countdown without extra messages. The server does the hit checks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Hazard = require(ReplicatedStorage.Shared.Config.Hazard)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)

local HazardService = {}

local state: Folder
local rng = Random.new()
local START_Z = Zones.ValleyEnd + 10
local END_Z = -2

local function pickType()
	local total = 0
	for _, t in Hazard.Types do
		total += t.Weight
	end
	local roll = rng:NextNumber() * total
	for i, t in Hazard.Types do
		roll -= t.Weight
		if roll <= 0 then
			return i, t
		end
	end
	return 1, Hazard.Types[1]
end

local function schedule(at: number)
	local index, t = pickType()
	state:SetAttribute("NextAt", at)
	state:SetAttribute("Type", index)
	state:SetAttribute("Speed", t.Speed)
	state:SetAttribute("FromZ", START_Z)
	state:SetAttribute("ToZ", END_Z)
end

local function burn(player: Player, humanoid: Humanoid)
	Registry.EggService.DropAll(player, "Burned")
	Registry.StealService.Fail(player, "Burned")
	humanoid.Health = 0
	Remotes.Notify:FireClient(player, "The Elder Dragon got you! Hide under the rock shelters next time.", "Error", "Burned")
end

local function runWave(startAt: number, speed: number)
	local duration = (START_Z - END_Z) / speed
	local half = Hazard.Thickness / 2
	local prevZ = START_Z
	while true do
		local now = workspace:GetServerTimeNow()
		local elapsed = now - startAt
		if elapsed > duration then
			break
		end
		local z = START_Z - speed * math.max(0, elapsed)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				local pz = root.Position.Z
				-- Swept check: did the fire pass over you since last frame?
				if pz > 1 and pz <= prevZ + half and pz >= z - half then
					if not Registry.WorldService.InShelter(root.Position) then
						burn(player, humanoid)
					end
				end
			end
		end
		prevZ = z
		RunService.Heartbeat:Wait()
	end
end

-- Pushes the next wave back (the Calm the Dragon purchase).
function HazardService.Calm(player: Player)
	local nextAt = state:GetAttribute("NextAt") :: number
	local now = workspace:GetServerTimeNow()
	local base = math.max(nextAt, now)
	state:SetAttribute("NextAt", base + Hazard.CalmDelay)
	Remotes.Announce:FireAllClients(("%s calmed the Elder Dragon! It sleeps for %d more seconds."):format(player.DisplayName, Hazard.CalmDelay), Color3.fromRGB(140, 220, 255))
end

-- Starts a wave right away (dev command).
function HazardService.TriggerNow()
	state:SetAttribute("NextAt", workspace:GetServerTimeNow() + Hazard.Warning)
end

function HazardService.Start()
	state = Instance.new("Folder")
	state.Name = "Hazard"
	state.Parent = ReplicatedStorage
	schedule(workspace:GetServerTimeNow() + Hazard.FirstWave)

	task.spawn(function()
		while true do
			-- Wait for the start time (it can move if someone calms the dragon).
			while workspace:GetServerTimeNow() < (state:GetAttribute("NextAt") :: number) do
				task.wait(0.1)
			end
			local startAt = state:GetAttribute("NextAt") :: number
			local speed = state:GetAttribute("Speed") :: number
			state:SetAttribute("Active", true)
			runWave(startAt, speed)
			state:SetAttribute("Active", false)
			local nextAt = math.max(startAt + Hazard.Interval, workspace:GetServerTimeNow() + 12)
			-- Someone calmed the dragon during this wave: respect that.
			local calmedTo = state:GetAttribute("NextAt") :: number
			if calmedTo > startAt then
				nextAt = math.max(nextAt, calmedTo)
			end
			schedule(nextAt)
		end
	end)
end

return HazardService
