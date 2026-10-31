-- Makes models: the uploaded Blender model if it loads, otherwise a stand-in
-- built from plain parts (so the game works before you upload anything).
-- Stand-ins use the same part names the game looks for (WingL, WingR,
-- Crystal, Handle, Board).
--
-- Every model comes back anchored, non-colliding, with its pivot at the
-- bottom center, facing -Z. Use Colliders to add invisible walls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local AssetService = require(script.Parent.AssetService)

local ModelFactory = {}

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- An ellipsoid (a block with a sphere mesh, since Ball parts must be round).
local function ball(model, name, size, pos, color, material)
	local p = part(model, name, size, CFrame.new(pos), color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function cylinder(model, name, height, diameter, pos, color, material)
	-- Roblox cylinders run along X; turn them upright.
	return part(model, name, Vector3.new(height, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
end

local function lighter(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), amount)
end

local function darker(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), amount)
end

-- ------------------------------------------------------------ stand-ins

local function dragonStandIn(model: Model, color: Color3, big: boolean)
	local s = if big then 3 else 1
	local belly = lighter(color, 0.55)
	ball(model, "Body", Vector3.new(2.6, 2.4, 3.0) * s, Vector3.new(0, 1.4, 0.2) * s, color)
	ball(model, "Belly", Vector3.new(2.0, 1.9, 1.6) * s, Vector3.new(0, 1.3, -0.6) * s, belly)
	ball(model, "Head", Vector3.new(2.0, 1.9, 2.0) * s, Vector3.new(0, 3.0, -1.4) * s, color)
	ball(model, "Snout", Vector3.new(1.2, 0.9, 1.2) * s, Vector3.new(0, 2.7, -2.3) * s, color)
	for _, side in { -1, 1 } do
		ball(model, "Eye", Vector3.new(0.6, 0.6, 0.6) * s, Vector3.new(0.45 * side, 3.3, -2.2) * s, Color3.new(1, 1, 1))
		ball(model, "Pupil", Vector3.new(0.35, 0.35, 0.35) * s, Vector3.new(0.48 * side, 3.3, -2.45) * s, Color3.new(0.05, 0.05, 0.05))
		part(model, "Horn", Vector3.new(0.3, 0.8, 0.3) * s, CFrame.new(Vector3.new(0.45 * side, 4.0, -1.1) * s) * CFrame.Angles(math.rad(-25), 0, 0), lighter(color, 0.7))
		for _, z in { -0.6, 0.9 } do
			part(model, "Leg", Vector3.new(0.6, 0.9, 0.6) * s, CFrame.new(Vector3.new(0.75 * side, 0.45, z) * s), color)
		end
		local wing = part(model, if side < 0 then "WingL" else "WingR", Vector3.new(2.6, 0.15, 1.6) * s,
			CFrame.new(Vector3.new(1.9 * side, 3.0, 0.4) * s) * CFrame.Angles(0, 0, math.rad(25 * side)), darker(color, 0.15))
		wing.Transparency = 0.1
	end
	part(model, "Tail", Vector3.new(0.7, 0.7, 2.6) * s, CFrame.new(Vector3.new(0, 1.0, 2.4) * s) * CFrame.Angles(math.rad(15), 0, 0), color)
end

local function eggStandIn(model: Model, color: Color3)
	local egg = part(model, "Egg", Vector3.new(2, 2.8, 2), CFrame.new(0, 1.4, 0), color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
end

local STONE = Color3.fromRGB(160, 155, 145)
local WOOD = Color3.fromRGB(130, 85, 45)

local builders: { [string]: (Model) -> () } = {
	CastleWall = function(m)
		part(m, "Wall", Vector3.new(12, 12, 3), CFrame.new(0, 6, 0), STONE, Enum.Material.Brick)
		for i = 0, 2 do
			part(m, "Merlon", Vector3.new(2, 2, 3.2), CFrame.new(-5 + i * 4, 13, 0), STONE, Enum.Material.Brick)
		end
	end,
	CastleTower = function(m)
		cylinder(m, "Tower", 16, 9, Vector3.new(0, 8, 0), STONE, Enum.Material.Brick)
		cylinder(m, "Rim", 1, 10, Vector3.new(0, 16.5, 0), STONE, Enum.Material.Slate)
		ball(m, "Roof", Vector3.new(10, 9, 10), Vector3.new(0, 20, 0), Color3.fromRGB(180, 45, 35))
		part(m, "Spire", Vector3.new(1.4, 5, 1.4), CFrame.new(0, 25, 0), Color3.fromRGB(180, 45, 35))
	end,
	Gatehouse = function(m)
		for _, x in { -7, 7 } do
			part(m, "Pillar", Vector3.new(4, 14, 4), CFrame.new(x, 7, 0), STONE, Enum.Material.Brick)
		end
		part(m, "Top", Vector3.new(18, 3.2, 4), CFrame.new(0, 12.4, 0), STONE, Enum.Material.Brick)
	end,
	Perch = function(m)
		cylinder(m, "Base", 0.5, 4, Vector3.new(0, 0.25, 0), STONE, Enum.Material.Slate)
		cylinder(m, "Column", 2, 2.6, Vector3.new(0, 1.5, 0), STONE, Enum.Material.Slate)
		cylinder(m, "Nest", 0.6, 3.8, Vector3.new(0, 2.8, 0), Color3.fromRGB(215, 185, 100), Enum.Material.Fabric)
	end,
	WildNest = function(m)
		cylinder(m, "Nest", 0.8, 5, Vector3.new(0, 0.4, 0), Color3.fromRGB(150, 115, 60), Enum.Material.Fabric)
	end,
	FusionAltar = function(m)
		cylinder(m, "Base", 1.6, 10, Vector3.new(0, 0.8, 0), Color3.fromRGB(95, 90, 115), Enum.Material.Slate)
		cylinder(m, "Column", 3, 2.4, Vector3.new(0, 3.1, 0), Color3.fromRGB(95, 90, 115), Enum.Material.Slate)
		local crystal = part(m, "Crystal", Vector3.new(1.6, 3.4, 1.6), CFrame.new(0, 6.2, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(110, 190, 255), Enum.Material.Neon)
		crystal.Transparency = 0.15
	end,
	TreasureChest = function(m)
		part(m, "Chest", Vector3.new(5, 2.4, 3), CFrame.new(0, 1.2, 0), WOOD, Enum.Material.WoodPlanks)
		part(m, "Gold", Vector3.new(4.4, 0.8, 2.4), CFrame.new(0, 2.6, 0), Color3.fromRGB(255, 200, 50), Enum.Material.Metal)
		part(m, "Lid", Vector3.new(5, 0.4, 3), CFrame.new(0, 3.4, 1.8) * CFrame.Angles(math.rad(-60), 0, 0), WOOD, Enum.Material.WoodPlanks)
	end,
	LockPad = function(m)
		cylinder(m, "Pad", 0.6, 6, Vector3.new(0, 0.3, 0), STONE, Enum.Material.Slate)
		cylinder(m, "Rune", 0.2, 4.6, Vector3.new(0, 0.65, 0), Color3.fromRGB(255, 190, 50), Enum.Material.Neon)
	end,
	Shelter = function(m)
		for _, x in { -6, 6 } do
			part(m, "Pillar", Vector3.new(4, 7, 8), CFrame.new(x, 3.5, 0), Color3.fromRGB(125, 118, 108), Enum.Material.Slate)
		end
		part(m, "Roof", Vector3.new(17, 2.4, 10), CFrame.new(0, 8.2, 0), Color3.fromRGB(125, 118, 108), Enum.Material.Slate)
		part(m, "Moss", Vector3.new(16, 0.4, 9), CFrame.new(0, 9.5, 0), Color3.fromRGB(70, 120, 50), Enum.Material.Grass)
	end,
	ZoneSign = function(m)
		for _, x in { -3.4, 3.4 } do
			part(m, "Post", Vector3.new(0.4, 6, 0.4), CFrame.new(x, 3, 0), WOOD, Enum.Material.Wood)
		end
		part(m, "Board", Vector3.new(8, 3, 0.4), CFrame.new(0, 4.6, -0.2), Color3.fromRGB(160, 115, 65), Enum.Material.Wood)
	end,
	Tablet = function(m)
		part(m, "Base", Vector3.new(16, 1.5, 4), CFrame.new(0, 0.75, 0), Color3.fromRGB(105, 100, 115), Enum.Material.Slate)
		part(m, "Tablet", Vector3.new(14, 15, 1.4), CFrame.new(0, 9, 0.6), Color3.fromRGB(105, 100, 115), Enum.Material.Slate)
	end,
	Club = function(m)
		part(m, "Handle", Vector3.new(0.6, 4.5, 0.6), CFrame.new(0, 2.25, 0), WOOD, Enum.Material.Wood)
		part(m, "Knob", Vector3.new(1.2, 1.4, 1.2), CFrame.new(0, 4.2, 0), WOOD, Enum.Material.Wood)
	end,
	PineTree = function(m)
		cylinder(m, "Trunk", 5, 1.2, Vector3.new(0, 2.5, 0), Color3.fromRGB(95, 65, 40), Enum.Material.Wood)
		for i, w in { 8, 6.4, 4.6, 2.8 } do
			part(m, "Needles", Vector3.new(w, 3, w), CFrame.new(0, 3.5 + i * 2.6, 0) * CFrame.Angles(0, math.rad(i * 20), 0), Color3.fromRGB(35, 90, 45), Enum.Material.Grass)
		end
	end,
	OakTree = function(m)
		cylinder(m, "Trunk", 6, 1.8, Vector3.new(0, 3, 0), Color3.fromRGB(95, 65, 40), Enum.Material.Wood)
		ball(m, "Leaves", Vector3.new(8, 7, 8), Vector3.new(0, 8, 0), Color3.fromRGB(85, 150, 55), Enum.Material.Grass)
	end,
	Boulder = function(m)
		ball(m, "Rock", Vector3.new(6, 3.6, 5), Vector3.new(0, 1.6, 0), Color3.fromRGB(130, 125, 118), Enum.Material.Slate)
	end,
	LavaRock = function(m)
		ball(m, "Rock", Vector3.new(4.5, 3, 4), Vector3.new(0, 1.4, 0), Color3.fromRGB(40, 32, 30), Enum.Material.Basalt)
		ball(m, "Glow", Vector3.new(2.5, 1.6, 2.2), Vector3.new(1.4, 0.8, 0.4), Color3.fromRGB(255, 110, 20), Enum.Material.CrackedLava)
	end,
	IceSpire = function(m)
		part(m, "Ice", Vector3.new(1.6, 9, 1.6), CFrame.new(0, 4.5, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(170, 220, 255), Enum.Material.Ice)
		part(m, "Ice", Vector3.new(1.1, 5, 1.1), CFrame.new(1.4, 2.3, 0.4) * CFrame.Angles(0, 0, math.rad(-15)), Color3.fromRGB(170, 220, 255), Enum.Material.Ice)
	end,
	VoidCrystal = function(m)
		part(m, "Crystal", Vector3.new(1.4, 7, 1.4), CFrame.new(0, 3.5, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(150, 60, 230), Enum.Material.Neon)
		part(m, "Crystal", Vector3.new(1, 4.5, 1), CFrame.new(1.2, 2, 0.3) * CFrame.Angles(0, 0, math.rad(-25)), Color3.fromRGB(150, 60, 230), Enum.Material.Neon)
		ball(m, "Rock", Vector3.new(4.5, 1.2, 4), Vector3.new(0, 0.4, 0), Color3.fromRGB(40, 32, 55), Enum.Material.Slate)
	end,
	RuinPillar = function(m)
		part(m, "Base", Vector3.new(3.4, 0.8, 3.4), CFrame.new(0, 0.4, 0), Color3.fromRGB(235, 230, 220), Enum.Material.Marble)
		cylinder(m, "Column", 8, 2.4, Vector3.new(0, 4.8, 0), Color3.fromRGB(235, 230, 220), Enum.Material.Marble)
		cylinder(m, "Band", 0.3, 2.6, Vector3.new(0, 6, 0), Color3.fromRGB(255, 200, 70), Enum.Material.Metal)
	end,
	SunCrystal = function(m)
		part(m, "Crystal", Vector3.new(1.4, 6, 1.4), CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(255, 200, 60), Enum.Material.Neon)
		part(m, "Crystal", Vector3.new(1, 4, 1), CFrame.new(1.2, 2, 0.3) * CFrame.Angles(0, 0, math.rad(-22)), Color3.fromRGB(255, 200, 60), Enum.Material.Neon)
		ball(m, "Rock", Vector3.new(4.5, 1.2, 4), Vector3.new(0, 0.4, 0), Color3.fromRGB(220, 200, 160), Enum.Material.Sandstone)
	end,
	FlowerBush = function(m)
		ball(m, "Bush", Vector3.new(3.8, 2.4, 3.4), Vector3.new(0, 1.1, 0), Color3.fromRGB(80, 150, 55), Enum.Material.Grass)
		for i, c in { Color3.fromRGB(255, 130, 180), Color3.fromRGB(255, 225, 70), Color3.fromRGB(250, 250, 245) } do
			ball(m, "Flower", Vector3.new(0.5, 0.5, 0.5), Vector3.new(math.cos(i * 2) * 1.2, 2.2, math.sin(i * 2) * 1.1), c)
		end
	end,
	Mushroom = function(m)
		cylinder(m, "Stem", 2.2, 1, Vector3.new(0, 1.1, 0), Color3.fromRGB(235, 225, 200))
		ball(m, "Cap", Vector3.new(3, 1.6, 3), Vector3.new(0, 2.4, 0), Color3.fromRGB(200, 40, 30))
	end,
}

local function standIn(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local species = Dragons.ByName[name]
	if species then
		dragonStandIn(model, species.Color, false)
	elseif name == "ElderDragon" then
		dragonStandIn(model, Color3.fromRGB(110, 25, 20), true)
	elseif name:sub(1, 3) == "Egg" then
		local rarity = Rarities.ByName[name:sub(4)]
		eggStandIn(model, if rarity then rarity.Color else Color3.new(1, 1, 1))
	elseif builders[name] then
		builders[name](model)
	else
		part(model, name, Vector3.new(2, 2, 2), CFrame.new(0, 1, 0), Color3.fromRGB(200, 0, 200))
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- ------------------------------------------------------------ API

-- A model, scaled so it's `height` studs tall (or as built if nil).
function ModelFactory.Make(name: string, height: number?): Model
	local ok, loaded = pcall(AssetService.Model, name)
	if not ok then
		warn("[ModelFactory] Loading " .. name .. " failed, using a stand-in: " .. tostring(loaded))
	end
	local model = if ok then loaded else nil
	if not model then
		model = standIn(name)
		model:SetAttribute("StandIn", true)
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CastShadow = true
		end
	end
	if height then
		local _, size = model:GetBoundingBox()
		if size.Y > 0.01 then
			model:ScaleTo(model:GetScale() * height / size.Y)
		end
	end
	return model
end

-- Places a model standing at `position`, facing `facing` (a direction; default -Z).
function ModelFactory.Place(name: string, position: Vector3, facing: Vector3?, height: number?, parent: Instance?): Model
	local model = ModelFactory.Make(name, height)
	local look = facing and Vector3.new(facing.X, 0, facing.Z)
	if look and look.Magnitude > 0.01 then
		model:PivotTo(CFrame.lookAt(position, position + look))
	else
		model:PivotTo(CFrame.new(position))
	end
	model.Parent = parent
	return model
end

-- An invisible, anchored, colliding box (walls, tree trunks, rocks).
function ModelFactory.Collider(size: Vector3, cf: CFrame, parent: Instance, name: string?): Part
	local p = Instance.new("Part")
	p.Name = name or "Collider"
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = true
	p.Transparency = 1
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- Copies of the dragon, egg and Elder Dragon models into ReplicatedStorage.Templates,
-- so clients can show them in the UI and draw the Elder Dragon.
function ModelFactory.PublishTemplates()
	local folder = Instance.new("Folder")
	folder.Name = "Templates"
	local names = { "ElderDragon" }
	for _, s in Dragons.List do
		table.insert(names, s.Name)
	end
	for _, r in Rarities.List do
		table.insert(names, r.EggModel)
	end
	for _, name in names do
		local ok, err = pcall(function()
			local model = ModelFactory.Make(name, if name == "ElderDragon" then 30 else 4)
			model.Parent = folder
		end)
		if not ok then
			warn("[ModelFactory] Couldn't make template " .. name .. ": " .. tostring(err))
		end
	end
	folder.Parent = ReplicatedStorage
end

return ModelFactory
