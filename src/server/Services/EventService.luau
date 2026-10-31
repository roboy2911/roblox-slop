-- Events: Egg Rain (below) and Star Showers. Star Showers: every few minutes a Celestial egg falls somewhere in the
-- valley, with a beam of light everyone can see. First to grab it wins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Boosts = require(ReplicatedStorage.Shared.Boosts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ModelFactory = require(script.Parent.ModelFactory)
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

	Remotes.Announce:FireAllClients(("⭐ A Celestial Egg fell in %s! Grab it before it fades!"):format(zone.Name), Color3.fromRGB(150, 230, 255), "Star")
end

-- Egg Rain: for a short while eggs fall from the sky over one of the first
-- zones. Mostly that zone's eggs, sometimes one rarity better.
local RAIN_EVERY = { 6 * 60, 11 * 60 } -- random gap between rains (seconds)
local RAIN_LENGTH = 30
local RAIN_EGGS = 40
local rainActive = false

local function cloud(pos: Vector3, parent: Instance)
	for i = 1, 5 do
		local puff = Instance.new("Part")
		puff.Name = "RainCloud"
		puff.Anchored = true
		puff.CanCollide = false
		puff.CanQuery = false
		puff.CanTouch = false
		puff.CastShadow = false
		puff.Shape = Enum.PartType.Ball
		puff.Material = Enum.Material.SmoothPlastic
		puff.Color = Color3.fromRGB(120, 125, 145)
		puff.Transparency = 0.25
		local size = rng:NextNumber(40, 70)
		puff.Size = Vector3.new(size, size, size)
		puff.Position = pos + Vector3.new((i - 3) * 38 + rng:NextNumber(-10, 10), rng:NextNumber(-6, 6), rng:NextNumber(-25, 25))
		puff.Parent = parent
	end
end

function EventService.EggRain()
	if rainActive then
		return
	end
	rainActive = true
	local zoneIndex = rng:NextInteger(1, 3)
	local zone = Zones.List[zoneIndex]
	local center = Vector3.new(rng:NextNumber(-150, 150), 0, (zone.StartZ + zone.EndZ) / 2)
	local folder = Instance.new("Folder")
	folder.Name = "EggRain"
	folder.Parent = workspace
	cloud(center + Vector3.new(0, 85, 0), folder)
	Remotes.Announce:FireAllClients(("🌧️ EGG RAIN in %s! Grab what falls!"):format(zone.Name), Color3.fromRGB(150, 200, 255), "Star")

	for _ = 1, RAIN_EGGS do
		task.wait(RAIN_LENGTH / RAIN_EGGS)
		local rarity = Zones.RollRarity(zone, rng)
		if rng:NextNumber() < 0.15 then
			local up = Rarities.List[math.min(Rarities.ByName[rarity].Order + 1, 6)]
			rarity = up.Name
		end
		local species = Dragons.RollSpecies(rarity, rng)
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, 80)
		local ground = center + Vector3.new(math.cos(angle) * r, 0.5, math.sin(angle) * r * 0.6)
		local mutation = Dragons.RollMutation(Boosts.Luck(), rng)
		-- A look-alike egg falls first; the real (grabbable) egg appears where it lands.
		task.spawn(function()
			local falling = ModelFactory.Make(Rarities.ByName[rarity].EggModel, 3)
			falling.Name = "FallingEgg"
			falling:PivotTo(CFrame.new(ground + Vector3.new(0, 70, 0)))
			falling.Parent = folder
			local t0 = os.clock()
			while os.clock() - t0 < 1.1 do
				local k = ((os.clock() - t0) / 1.1) ^ 2
				falling:PivotTo(CFrame.new(ground + Vector3.new(0, 70 * (1 - k), 0)) * CFrame.Angles(0, k * 6, 0))
				task.wait()
			end
			falling:Destroy()
			Registry.EggService.SpawnSpecial(species.Name, mutation, CFrame.new(ground), 60)
		end)
	end
	task.wait(2)
	folder:Destroy()
	rainActive = false
end

function EventService.Start()
	task.spawn(function()
		while true do
			task.wait(rng:NextInteger(RAIN_EVERY[1], RAIN_EVERY[2]))
			EventService.EggRain()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(EVERY)
			EventService.StarShower()
		end
	end)
end

return EventService
