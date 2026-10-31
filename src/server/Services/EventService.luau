-- Star Showers: every few minutes a Celestial egg falls somewhere in the
-- valley, with a beam of light everyone can see. First to grab it wins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)

local EventService = {}

local EVERY = 9 * 60
local LIFETIME = 150
local rng = Random.new()

function EventService.StarShower()
	-- Somewhere in the middle zones, so everyone has a shot.
	local zoneIndex = rng:NextInteger(2, 4)
	local zone = Zones.List[zoneIndex]
	local pos = Vector3.new(rng:NextNumber(-250, 250), 0.5, rng:NextNumber(zone.StartZ + 20, zone.EndZ - 20))
	local mutation = Dragons.RollMutation(3, rng)
	local egg = Registry.EggService.SpawnSpecial("Starborn", mutation, CFrame.new(pos), LIFETIME)

	-- A tall beam of light so people can find it.
	local beam = Instance.new("Part")
	beam.Name = "StarBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(150, 230, 255)
	beam.Transparency = 0.45
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(400, 3, 3)
	beam.CFrame = CFrame.new(pos + Vector3.new(0, 200, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = egg
	egg:SetAttribute("Celestial", true)

	Remotes.Announce:FireAllClients(("⭐ A Celestial Egg fell in %s! Grab it before it fades!"):format(zone.Name), Color3.fromRGB(150, 230, 255))
end

function EventService.Start()
	task.spawn(function()
		while true do
			task.wait(EVERY)
			EventService.StarShower()
		end
	end)
end

return EventService
