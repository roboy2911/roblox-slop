-- Builds the world: lighting, the ground, the valley zones, rock shelters,
-- wild nests, decorations, zone signs, rebirth gates and the map edges.
-- Castles are built by PlotService.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hazard = require(ReplicatedStorage.Shared.Config.Hazard)
local Layout = require(ReplicatedStorage.Shared.Config.Layout)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local ModelFactory = require(script.Parent.ModelFactory)
local Registry = require(script.Parent.Registry)

local WorldService = {}

-- Rock shelter positions (base center).
WorldService.Shelters = {} :: { Vector3 }
-- Nest CFrames per zone index.
WorldService.Nests = {} :: { { CFrame } }

local world: Folder
local rng = Random.new(20261031)

-- Rows of shelters in each zone (Z is distance into the zone). About 65 studs
-- apart, so you can always reach one during the warning if you're paying attention.
local SHELTER_ROWS = {
	{ Z = 40, X = { -220, -60, 100, 240 } },
	{ Z = 105, X = { -150, 20, 180 } },
	{ Z = 170, X = { -240, -80, 80, 230 } },
	{ Z = 235, X = { -160, 10, 170 } },
}
local NESTS_PER_ZONE = 20
local DECOR_PER_ZONE = 45

local function groundPart(name: string, size: Vector3, position: Vector3, material: Enum.Material, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Anchored = true
	p.Material = material
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = world
	return p
end

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(70, 70, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(200, 225, 255)
	atmosphere.Decay = Color3.fromRGB(110, 130, 170)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.18
	color.Contrast = 0.06
	color.Parent = Lighting

	if not Lighting:FindFirstChildOfClass("Sky") then
		Instance.new("Sky").Parent = Lighting
	end
end

local function farFromAll(pos: Vector3, list: { Vector3 }, distance: number): boolean
	for _, other in list do
		if (Vector3.new(other.X, 0, other.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < distance then
			return false
		end
	end
	return true
end

local function buildShelters(zoneIndex: number, zone: Zones.Zone, folder: Folder)
	for _, row in SHELTER_ROWS do
		for _, x in row.X do
			-- Stagger rows a little per zone so the path isn't a straight line.
			local offset = if zoneIndex % 2 == 0 then 35 else 0
			local pos = Vector3.new(x + offset, 0, zone.StartZ + row.Z)
			local model = ModelFactory.Place("Shelter", pos, Vector3.new(0, 0, -1), 10, folder)
			CollectionService:AddTag(model, "Shelter")
			table.insert(WorldService.Shelters, pos)
			-- Pillars and roof you can't walk through; the middle is open.
			ModelFactory.Collider(Vector3.new(3.5, 7, 7), CFrame.new(pos + Vector3.new(-6.3, 3.5, 0)), folder)
			ModelFactory.Collider(Vector3.new(3.5, 7, 7), CFrame.new(pos + Vector3.new(6.3, 3.5, 0)), folder)
			ModelFactory.Collider(Vector3.new(16, 2.2, 9), CFrame.new(pos + Vector3.new(0, 8.6, 0)), folder)
			-- A soft glow so shelters are easy to spot when the warning hits.
			local marker = Instance.new("Part")
			marker.Name = "SafeZone"
			marker.Anchored = true
			marker.CanCollide = false
			marker.CanQuery = false
			marker.CanTouch = false
			marker.Size = Vector3.new(0.2, 9, 9)
			marker.CFrame = CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
			marker.Shape = Enum.PartType.Cylinder
			marker.Material = Enum.Material.Neon
			marker.Color = Color3.fromRGB(120, 255, 160)
			marker.Transparency = 0.75
			marker.Parent = folder
		end
	end
end

local function buildNests(zoneIndex: number, zone: Zones.Zone, folder: Folder)
	local nests = {}
	local placed: { Vector3 } = {}
	local tries = 0
	while #nests < NESTS_PER_ZONE and tries < 500 do
		tries += 1
		local pos = Vector3.new(rng:NextNumber(-Zones.HalfWidth + 20, Zones.HalfWidth - 20), 0, rng:NextNumber(zone.StartZ + 10, zone.EndZ - 10))
		if farFromAll(pos, WorldService.Shelters, 16) and farFromAll(pos, placed, 26) then
			table.insert(placed, pos)
			local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			local model = ModelFactory.Make("WildNest", 1.4)
			model:PivotTo(cf)
			model.Parent = folder
			table.insert(nests, cf)
		end
	end
	WorldService.Nests[zoneIndex] = nests
end

local DECOR_SIZE = {
	FlowerBush = { Height = 3, Collide = nil },
	OakTree = { Height = 14, Collide = Vector3.new(2, 8, 2) },
	PineTree = { Height = 18, Collide = Vector3.new(2, 8, 2) },
	Mushroom = { Height = 4, Collide = Vector3.new(1.2, 3, 1.2) },
	Boulder = { Height = 5, Collide = Vector3.new(6, 4, 5) },
	LavaRock = { Height = 4, Collide = Vector3.new(4.5, 3, 4) },
	IceSpire = { Height = 12, Collide = Vector3.new(2.5, 10, 2.5) },
	VoidCrystal = { Height = 9, Collide = Vector3.new(3, 7, 3) },
}

local function buildDecor(zoneIndex: number, zone: Zones.Zone, folder: Folder)
	local avoid: { Vector3 } = {}
	for _, cf in WorldService.Nests[zoneIndex] do
		table.insert(avoid, cf.Position)
	end
	local placed = 0
	local tries = 0
	while placed < DECOR_PER_ZONE and tries < 600 do
		tries += 1
		local pos = Vector3.new(rng:NextNumber(-Zones.HalfWidth + 6, Zones.HalfWidth - 6), 0, rng:NextNumber(zone.StartZ + 6, zone.EndZ - 6))
		if farFromAll(pos, WorldService.Shelters, 15) and farFromAll(pos, avoid, 11) then
			table.insert(avoid, pos)
			placed += 1
			local name = zone.Decor[rng:NextInteger(1, #zone.Decor)]
			local info = DECOR_SIZE[name]
			local height = info.Height * rng:NextNumber(0.8, 1.3)
			local model = ModelFactory.Make(name, height)
			model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
			model.Parent = folder
			if info.Collide then
				local scale = height / info.Height
				ModelFactory.Collider(info.Collide * scale, CFrame.new(pos + Vector3.new(0, info.Collide.Y * scale / 2, 0)), folder)
			end
		end
	end
end

local function zoneSign(zone: Zones.Zone, folder: Folder)
	local best, bestChance = "Common", 0
	for rarity, chance in zone.Rarities do
		if chance > bestChance then
			best, bestChance = rarity, chance
		end
	end
	for _, x in { -Zones.HalfWidth + 30, 0, Zones.HalfWidth - 30 } do
		local pos = Vector3.new(x, 0, zone.StartZ + 5)
		local model = ModelFactory.Place("ZoneSign", pos, Vector3.new(0, 0, -1), 6, folder)
		local board = model:FindFirstChild("Board") :: BasePart?
		if not board then
			continue
		end
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.2
		gui.Parent = board
		-- The board faces -Z in model space; make sure text shows on the castle-facing side.
		local look = model:GetPivot().LookVector
		local front = board.CFrame:VectorToObjectSpace(look)
		if math.abs(front.X) > math.abs(front.Z) then
			gui.Face = if front.X > 0 then Enum.NormalId.Right else Enum.NormalId.Left
		else
			gui.Face = if front.Z > 0 then Enum.NormalId.Back else Enum.NormalId.Front
		end
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 0.6)
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 245, 220)
		title.TextStrokeTransparency = 0.3
		title.Text = zone.Name
		title.Parent = gui
		local sub = title:Clone()
		sub.Position = UDim2.fromScale(0, 0.58)
		sub.Size = UDim2.fromScale(1, 0.38)
		sub.Text = best .. " eggs" .. (if zone.Rebirths > 0 then ("  •  Rebirth %d"):format(zone.Rebirths) else "")
		sub.TextColor3 = Rarities.ByName[best].Color
		sub.Parent = gui
	end
end

local function rebirthGate(zone: Zones.Zone, folder: Folder)
	local gate = Instance.new("Part")
	gate.Name = "RebirthGate"
	gate.Anchored = true
	gate.CanCollide = false -- each client turns this on for itself if it can't enter
	gate.Size = Vector3.new(Zones.HalfWidth * 2, 40, 1)
	gate.Position = Vector3.new(0, 20, zone.StartZ)
	gate.Material = Enum.Material.ForceField
	gate.Color = Color3.fromRGB(170, 120, 255)
	gate.Transparency = 0.2
	gate:SetAttribute("Rebirths", zone.Rebirths)
	CollectionService:AddTag(gate, "RebirthGate")
	gate.Parent = folder

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(420, 80)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 200
	gui.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(230, 210, 255)
	label.TextStrokeTransparency = 0.2
	label.Text = ("🔒 %s — needs Rebirth %d"):format(zone.Name, zone.Rebirths)
	label.Parent = gui
	for _, x in { -200, 0, 200 } do
		local anchor = Instance.new("Attachment")
		anchor.Position = Vector3.new(x, -12, 0)
		anchor.Parent = gate
		local g = gui:Clone()
		g.Adornee = anchor
		g.Parent = gate
	end
	gui:Destroy()
end

local function buildEdges()
	local rock = Color3.fromRGB(110, 100, 92)
	local length = Zones.ValleyEnd + 220
	local centerZ = (Zones.ValleyEnd - 110) / 2
	for _, side in { -1, 1 } do
		groundPart("Cliff", Vector3.new(40, 90, length), Vector3.new(side * (Zones.HalfWidth + 20), 45, centerZ), Enum.Material.Slate, rock)
	end
	groundPart("BackCliff", Vector3.new(Zones.HalfWidth * 2 + 80, 90, 40), Vector3.new(0, 45, -120), Enum.Material.Slate, rock)
	groundPart("EndCliff", Vector3.new(Zones.HalfWidth * 2 + 80, 120, 40), Vector3.new(0, 60, Zones.ValleyEnd + 20), Enum.Material.Slate, Color3.fromRGB(45, 35, 65))
	-- An invisible ceiling-ish wall so nobody climbs out over the cliffs.
	for _, side in { -1, 1 } do
		ModelFactory.Collider(Vector3.new(4, 300, length), CFrame.new(side * (Zones.HalfWidth + 2), 240, centerZ), world, "Barrier")
	end
end

local function enforceRebirthGates()
	-- The client blocks you with a wall; this catches anyone who gets past it.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local data = Registry.DataService.Get(player)
				if root and data then
					for _, zone in Zones.List do
						if zone.Rebirths > (data.Rebirths or 0) and root.Position.Z > zone.StartZ + 2 then
							character:PivotTo(CFrame.new(root.Position.X, 4, zone.StartZ - 8))
							Remotes.Notify:FireClient(player, ("%s needs Rebirth %d!"):format(zone.Name, zone.Rebirths), "Error")
							break
						end
					end
				end
			end
		end
	end)
end

function WorldService.Build()
	setupLighting()
	local old = workspace:FindFirstChild("Baseplate")
	if old then
		old:Destroy()
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	-- Hidden spawn behind the castles; PlotService moves you into your castle.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, -88)
	spawn.Transparency = 1
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Duration = 0
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = world

	-- Grass behind and around the castles.
	groundPart("CastleGround", Vector3.new(Zones.HalfWidth * 2 + 40, 4, 120), Vector3.new(0, -2, -60), Enum.Material.Grass, Color3.fromRGB(96, 158, 66))
	-- A dirt road in front of the castles.
	groundPart("Road", Vector3.new(Zones.HalfWidth * 2, 0.2, 10), Vector3.new(0, 0.05, 2), Enum.Material.Ground, Color3.fromRGB(140, 110, 75))

	for i, zone in Zones.List do
		local folder = Instance.new("Folder")
		folder.Name = zone.Name
		folder.Parent = world
		local ground = groundPart("Ground", Vector3.new(Zones.HalfWidth * 2 + 40, 4, Zones.Length), Vector3.new(0, -2, (zone.StartZ + zone.EndZ) / 2), zone.Ground, zone.GroundColor)
		ground.Parent = folder
		ground:SetAttribute("Zone", i)
		if zone.Name == "Ember Wastes" then
			-- Lava cracks here and there (just for looks).
			for _ = 1, 12 do
				local lava = groundPart("Lava", Vector3.new(rng:NextNumber(10, 30), 0.3, rng:NextNumber(4, 10)),
					Vector3.new(rng:NextNumber(-280, 280), 0.05, rng:NextNumber(zone.StartZ + 10, zone.EndZ - 10)),
					Enum.Material.CrackedLava, Color3.fromRGB(255, 110, 30))
				lava.CanCollide = false
				lava.Parent = folder
			end
		end
		-- Shelters and nests matter for gameplay; the rest is decoration.
		local function try(label: string, fn: () -> ())
			local ok, err = pcall(fn)
			if not ok then
				warn(("[WorldService] %s in %s failed: %s"):format(label, zone.Name, tostring(err)))
			end
		end
		try("Shelters", function()
			buildShelters(i, zone, folder)
		end)
		try("Nests", function()
			buildNests(i, zone, folder)
		end)
		try("Decor", function()
			buildDecor(i, zone, folder)
		end)
		try("Sign", function()
			zoneSign(zone, folder)
		end)
		if zone.Rebirths > 0 then
			try("Rebirth gate", function()
				rebirthGate(zone, folder)
			end)
		end
	end
	buildEdges()
	enforceRebirthGates()
end

-- True if a position is safely under a rock shelter.
function WorldService.InShelter(position: Vector3): boolean
	local half = Hazard.ShelterHalfSize
	for _, base in WorldService.Shelters do
		local d = position - base
		if math.abs(d.X) < half.X and math.abs(d.Z) < half.Z and d.Y > -2 and d.Y < half.Y * 2 then
			return true
		end
	end
	return false
end

-- Keep Layout referenced for anyone reading this file: castles live at Z < 0.
WorldService.CastleRowZ = Layout.CastleCenterZ

return WorldService
