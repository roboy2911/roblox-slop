-- The castles. Builds all of them when the server starts, gives each player
-- one, spawns them inside it, and runs the gate lock.
--
-- Locking: step on the lock pad in your castle. For a while, a glowing wall
-- blocks your gate. You can walk through it (collision groups); nobody else can,
-- and anyone else inside is pushed out.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Layout = require(ReplicatedStorage.Shared.Config.Layout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ModelFactory = require(script.Parent.ModelFactory)
local Registry = require(script.Parent.Registry)

local PlotService = {}

export type Plot = {
	Index: number,
	Center: Vector3,
	Folder: Folder,
	Gate: Part,
	Chest: Model,
	Altar: Model,
	LockPad: Model,
	SignLabel: TextLabel,
	Flags: { BasePart },
	Owner: Player?,
}

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}

local function local3(plot: Plot, offset: Vector3): Vector3
	return plot.Center + offset
end

local function registerGroups()
	for i = 1, Layout.PlotCount do
		local gate, owner = "Gate" .. i, "Owner" .. i
		pcall(function()
			PhysicsService:RegisterCollisionGroup(gate)
			PhysicsService:RegisterCollisionGroup(owner)
		end)
		PhysicsService:CollisionGroupSetCollidable(gate, owner, false)
	end
end

local function setCharacterGroup(character: Model, group: string)
	for _, p in character:GetDescendants() do
		if p:IsA("BasePart") then
			p.CollisionGroup = group
		end
	end
end

local function buildWalls(plot: Plot, folder: Folder)
	local h = Layout.CastleHalf
	local c = plot.Center
	-- Corner towers.
	for _, x in { -h, h } do
		for _, z in { -h, h } do
			ModelFactory.Place("CastleTower", c + Vector3.new(x, 0, z), Vector3.new(0, 0, 1), 24, folder)
			ModelFactory.Collider(Vector3.new(8, 24, 8), CFrame.new(c + Vector3.new(x, 12, z)), folder)
			-- A flag on top in the castle's color.
			local flag = Instance.new("Part")
			flag.Name = "Flag"
			flag.Anchored = true
			flag.CanCollide = false
			flag.Size = Vector3.new(0.2, 2.2, 3.6)
			flag.CFrame = CFrame.new(c + Vector3.new(x, 22.4, z + 1.8))
			flag.Material = Enum.Material.Fabric
			flag.Color = Color3.fromRGB(200, 200, 200)
			flag.Parent = folder
			table.insert(plot.Flags, flag)
		end
	end
	-- Side and back walls: 5 segments of 12 between the towers.
	local function wallRun(from: Vector3, to: Vector3, count: number)
		local dir = (to - from).Unit
		local length = (to - from).Magnitude
		local step = length / count
		for i = 0, count - 1 do
			local pos = from + dir * (step * (i + 0.5))
			ModelFactory.Place("CastleWall", pos, Vector3.new(-dir.Z, 0, dir.X), 14, folder)
		end
		local mid = (from + to) / 2
		local size = if math.abs(dir.X) > 0.5 then Vector3.new(length, Layout.WallHeight, 3) else Vector3.new(3, Layout.WallHeight, length)
		ModelFactory.Collider(size, CFrame.new(mid + Vector3.new(0, Layout.WallHeight / 2, 0)), folder)
	end
	wallRun(c + Vector3.new(-h, 0, -h), c + Vector3.new(h, 0, -h), 5) -- back
	wallRun(c + Vector3.new(-h, 0, -h), c + Vector3.new(-h, 0, h), 5) -- left
	wallRun(c + Vector3.new(h, 0, -h), c + Vector3.new(h, 0, h), 5) -- right
	-- Front: gatehouse in the middle, walls either side.
	local gw = Layout.GateHalfWidth
	wallRun(c + Vector3.new(-h, 0, h), c + Vector3.new(-9, 0, h), 2)
	wallRun(c + Vector3.new(9, 0, h), c + Vector3.new(h, 0, h), 2)
	ModelFactory.Place("Gatehouse", c + Vector3.new(0, 0, h), Vector3.new(0, 0, -1), 17, folder)
	for _, x in { -(gw + 2.2), gw + 2.2 } do
		ModelFactory.Collider(Vector3.new(4.4, 16, 4), CFrame.new(c + Vector3.new(x, 8, h)), folder)
	end
	ModelFactory.Collider(Vector3.new(18, 4, 4), CFrame.new(c + Vector3.new(0, 14, h)), folder)

	-- The lock wall in the gate.
	local gate = Instance.new("Part")
	gate.Name = "LockWall"
	gate.Anchored = true
	gate.CanCollide = false
	gate.Transparency = 1
	gate.Size = Vector3.new(gw * 2 + 0.6, 12, 1)
	gate.CFrame = CFrame.new(c + Vector3.new(0, 6, h))
	gate.Material = Enum.Material.ForceField
	gate.Color = Color3.fromRGB(255, 70, 70)
	gate.CollisionGroup = "Gate" .. plot.Index
	gate.Parent = folder
	plot.Gate = gate
end

local function buildPlot(index: number): Plot
	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. index
	folder:SetAttribute("Index", index)
	folder:SetAttribute("OwnerId", 0)
	folder:SetAttribute("LockedUntil", 0)
	local plot: Plot = {
		Index = index,
		Center = Layout.PlotCenter(index),
		Folder = folder,
		Flags = {},
	} :: any

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(Layout.CastleHalf * 2, 1, Layout.CastleHalf * 2)
	floor.Position = plot.Center + Vector3.new(0, -0.4, 0)
	floor.Material = Enum.Material.Cobblestone
	floor.Color = Color3.fromRGB(150, 145, 135)
	floor.Parent = folder

	buildWalls(plot, folder)

	plot.Chest = ModelFactory.Place("TreasureChest", local3(plot, Layout.Chest), Vector3.new(-1, 0, 0), 4, folder)
	ModelFactory.Collider(Vector3.new(5, 3, 4), CFrame.new(local3(plot, Layout.Chest) + Vector3.new(0, 1.5, 0)), folder)
	plot.Altar = ModelFactory.Place("FusionAltar", local3(plot, Layout.Altar), Vector3.new(1, 0, 0), 8, folder)
	ModelFactory.Collider(Vector3.new(8, 1.6, 8), CFrame.new(local3(plot, Layout.Altar) + Vector3.new(0, 0.8, 0)), folder)
	ModelFactory.Collider(Vector3.new(2.4, 5, 2.4), CFrame.new(local3(plot, Layout.Altar) + Vector3.new(0, 2.5, 0)), folder)
	plot.LockPad = ModelFactory.Place("LockPad", local3(plot, Layout.LockPad), Vector3.new(0, 0, -1), 1.6, folder)

	-- Fusion prompt (only the owner sees it; the client hides the rest).
	local altarPart = plot.Altar:FindFirstChildWhichIsA("BasePart") :: BasePart
	local attach = Instance.new("Attachment")
	attach.Name = "PromptPoint"
	attach.WorldPosition = local3(plot, Layout.Altar) + Vector3.new(0, 3, 0)
	attach.Parent = altarPart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FusePrompt"
	prompt.ActionText = "Fuse Dragons"
	prompt.ObjectText = "Fusion Altar"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Kind", "Fuse")
	prompt:SetAttribute("Plot", index)
	prompt.Parent = attach

	-- Labels: the owner's name over the gate, gold waiting at the chest.
	local signGui = Instance.new("BillboardGui")
	signGui.Name = "OwnerSign"
	signGui.Size = UDim2.fromOffset(360, 70)
	signGui.StudsOffsetWorldSpace = Vector3.new(0, 21, 0)
	signGui.MaxDistance = 260
	local signPart = ModelFactory.Collider(Vector3.new(1, 1, 1), CFrame.new(local3(plot, Vector3.new(0, 0, Layout.CastleHalf))), folder, "SignAnchor")
	signPart.CanCollide = false
	signPart.CanQuery = false
	signGui.Adornee = signPart
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.1
	label.Text = "Empty Castle"
	label.Parent = signGui
	signGui.Parent = signPart
	plot.SignLabel = label

	folder.Parent = workspace:WaitForChild("Plots")
	return plot
end

-- ------------------------------------------------------------ lock

local function isLocked(plot: Plot): boolean
	return (plot.Folder:GetAttribute("LockedUntil") or 0) > workspace:GetServerTimeNow()
end

local function setLocked(plot: Plot, untilTime: number)
	plot.Folder:SetAttribute("LockedUntil", untilTime)
	local locked = untilTime > workspace:GetServerTimeNow()
	plot.Gate.CanCollide = locked
	plot.Gate.Transparency = if locked then 0.35 else 1
	if plot.Owner then
		Registry.DataService.SetExtra(plot.Owner, "LockedUntil", untilTime)
	end
end

local function pushOutIntruders(plot: Plot)
	for _, player in Players:GetPlayers() do
		if player ~= plot.Owner and player.Character then
			local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and Layout.Inside(plot.Center, root.Position) then
				player.Character:PivotTo(CFrame.new(plot.Center + Vector3.new(0, 4, Layout.CastleHalf + 8)))
			end
		end
	end
end

local function lockLoop()
	local wasLocked: { [Plot]: boolean } = {}
	local onPad: { [Player]: boolean } = {}
	while true do
		task.wait(0.25)
		for _, plot in plots do
			local owner = plot.Owner
			local locked = isLocked(plot)
			if owner and owner.Character then
				local root = owner.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local padPos = plot.Center + Layout.LockPad
				local standing = root ~= nil and (Vector3.new(root.Position.X, 0, root.Position.Z) - padPos).Magnitude < Layout.LockPadRadius and root.Position.Y < 8
				if standing and not onPad[owner] and not locked then
					local data = Registry.DataService.Get(owner)
					local duration = Economy.LockDuration(data and data.Rebirths or 0)
					setLocked(plot, workspace:GetServerTimeNow() + duration)
					locked = true
					pushOutIntruders(plot)
					Remotes.Notify:FireClient(owner, ("Castle locked for %d seconds!"):format(duration), "Good", "Lock")
				end
				onPad[owner] = standing
			end
			if wasLocked[plot] and not locked then
				setLocked(plot, 0)
				if owner then
					Remotes.Notify:FireClient(owner, "Your castle is unlocked! Step on the lock pad again.", "Warn")
				end
			end
			wasLocked[plot] = locked
		end
	end
end

-- ------------------------------------------------------------ assignment

local function spawnCFrame(plot: Plot): CFrame
	local pos = plot.Center + Layout.Spawn
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
end

local function onCharacter(player: Player, character: Model)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	setCharacterGroup(character, "Owner" .. plot.Index)
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = "Owner" .. plot.Index
		end
	end)
	task.spawn(function()
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait()
		if character.Parent and byPlayer[player] == plot then
			character:PivotTo(spawnCFrame(plot))
		end
	end)
end

local function assign(player: Player)
	for _, plot in plots do
		if not plot.Owner then
			plot.Owner = player
			byPlayer[player] = plot
			plot.Folder:SetAttribute("OwnerId", player.UserId)
			plot.Folder:SetAttribute("OwnerName", player.DisplayName)
			plot.SignLabel.Text = player.DisplayName .. "'s Castle"
			for _, flag in plot.Flags do
				flag.Color = Layout.Colors[plot.Index]
			end
			player:SetAttribute("Plot", plot.Index)
			setLocked(plot, 0)
			if player.Character then
				onCharacter(player, player.Character)
			end
			return plot
		end
	end
	warn("[PlotService] No free castle for " .. player.Name)
	return nil
end

local function release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	byPlayer[player] = nil
	plot.Owner = nil
	plot.Folder:SetAttribute("OwnerId", 0)
	plot.Folder:SetAttribute("OwnerName", nil)
	plot.SignLabel.Text = "Empty Castle"
	for _, flag in plot.Flags do
		flag.Color = Color3.fromRGB(200, 200, 200)
	end
	setLocked(plot, 0)
end

-- ------------------------------------------------------------ API

function PlotService.Get(player: Player): Plot?
	return byPlayer[player]
end

function PlotService.All(): { Plot }
	return plots
end

function PlotService.IsLocked(plot: Plot): boolean
	return isLocked(plot)
end

function PlotService.Unlock(plot: Plot)
	setLocked(plot, 0)
end

-- Is this player standing inside their own castle?
function PlotService.IsHome(player: Player): boolean
	local plot = byPlayer[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return plot ~= nil and root ~= nil and Layout.Inside(plot.Center, root.Position)
end

function PlotService.SpawnCFrame(player: Player): CFrame?
	local plot = byPlayer[player]
	return plot and spawnCFrame(plot)
end

function PlotService.Start()
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace
	registerGroups()
	for i = 1, Layout.PlotCount do
		plots[i] = buildPlot(i)
	end

	Players.CharacterAutoLoads = true
	Players.RespawnTime = 3
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	Registry.DataService.OnLoaded(function(player)
		if not byPlayer[player] then
			assign(player)
		end
	end)
	Players.PlayerRemoving:Connect(release)
	task.spawn(lockLoop)
end

return PlotService
