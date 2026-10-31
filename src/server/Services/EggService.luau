-- Wild eggs in the valley, and carrying them home.
--
-- Eggs appear on nests (rarer the farther the zone). Hold E to grab one; it
-- stacks over your head. Walk into your castle and they go onto free perches.
-- Get bonked and your eggs fall on the ground for anyone to grab; get burned
-- by the Elder Dragon and they're gone.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Format = require(ReplicatedStorage.Shared.Format)
local Fx = require(ReplicatedStorage.Shared.Fx)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ModelFactory = require(script.Parent.ModelFactory)
local Registry = require(script.Parent.Registry)

local EggService = {}

local MAX_PER_ZONE = 13
local SPAWN_EVERY = 1.5
local WILD_LIFETIME = 240
local DROPPED_LIFETIME = 60
local WILD_HEIGHT = 3
local CARRIED_HEIGHT = 2.2

type EggInfo = { Species: string, Mutation: string? }
type Carried = { Info: EggInfo, Model: Model }

local folder: Folder
local rng = Random.new()
local carrying: { [Player]: { Carried } } = {}
local zoneCounts: { [number]: number } = {}
local nestTaken: { [number]: boolean } = {} -- zone * 1000 + nest index

-- ------------------------------------------------------------ wild eggs

local function rarityOf(species: string)
	return Rarities.ByName[Dragons.ByName[species].Rarity]
end

local function addLabel(model: Model, info: EggInfo)
	local rarity = rarityOf(info.Species)
	local main = Fx.MainPart(model)
	if not main then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, WILD_HEIGHT * 0.5 + 2, 0)
	gui.MaxDistance = if rarity.Order >= 5 then 220 else 90
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0.15
	label.Text = (if info.Mutation then info.Mutation .. " " else "") .. rarity.Name .. " Egg"
	label.TextColor3 = if info.Mutation then Dragons.MutationByName[info.Mutation].Color else rarity.Color
	label.Parent = gui
	gui.Parent = main
	if rarity.Order >= 3 then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = 6 + rarity.Order * 2
		light.Brightness = 1.2
		light.Parent = main
	end
	Fx.Mutation(main, info.Mutation)
end

-- Puts a wild egg at a spot. `zone` (index) counts it toward that zone's limit.
local function spawnWild(info: EggInfo, cf: CFrame, zone: number?, lifetime: number, nest: number?): Model
	local rarity = rarityOf(info.Species)
	local model = ModelFactory.Make(rarity.EggModel, WILD_HEIGHT * (if rarity.Order >= 6 then 1.25 else 1))
	model:PivotTo(cf)
	model:SetAttribute("Species", info.Species)
	model:SetAttribute("Mutation", info.Mutation)
	model:SetAttribute("Rarity", rarity.Name)
	CollectionService:AddTag(model, "WildEgg")
	addLabel(model, info)

	local main = Fx.MainPart(model) :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabPrompt"
	prompt.ActionText = "Grab"
	prompt.ObjectText = rarity.Name .. " Egg"
	prompt.HoldDuration = if rarity.Order >= 7 then 1 else 0.2
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Kind", "Grab")
	prompt.Parent = main

	model.Parent = folder
	if zone then
		zoneCounts[zone] = (zoneCounts[zone] or 0) + 1
	end
	if nest then
		nestTaken[nest] = true
	end
	model.Destroying:Connect(function()
		if zone then
			zoneCounts[zone] -= 1
		end
		if nest then
			nestTaken[nest] = nil
		end
	end)
	task.delay(lifetime, function()
		if model.Parent then
			model:Destroy()
		end
	end)
	return model
end

local function spawnInZone(zoneIndex: number)
	local zone = Zones.List[zoneIndex]
	local nests = Registry.WorldService.Nests[zoneIndex]
	if not nests or #nests == 0 then
		return
	end
	local free = {}
	for i in nests do
		if not nestTaken[zoneIndex * 1000 + i] then
			table.insert(free, i)
		end
	end
	if #free == 0 then
		return
	end
	local nestIndex = free[rng:NextInteger(1, #free)]
	local rarity = Zones.RollRarity(zone, rng)
	local species = Dragons.RollSpecies(rarity, rng)
	local info = { Species = species.Name, Mutation = Dragons.RollMutation(1, rng) }
	spawnWild(info, nests[nestIndex] * CFrame.new(0, 0.5, 0), zoneIndex, WILD_LIFETIME, zoneIndex * 1000 + nestIndex)
end

-- A special egg (like the Celestial event). Returns the model.
function EggService.SpawnSpecial(species: string, mutation: string?, cf: CFrame, lifetime: number): Model
	return spawnWild({ Species = species, Mutation = mutation }, cf, nil, lifetime, nil)
end

-- ------------------------------------------------------------ carrying

function EggService.Capacity(player: Player): number
	local data = Registry.DataService.Get(player)
	local level = data and data.CarryLevel or 0
	local cap = Economy.CarryCapacity[level + 1] or Economy.CarryCapacity[#Economy.CarryCapacity]
	if Registry.ShopService.HasPass(player, "ExtraCarry") then
		cap += 1
	end
	return cap
end

function EggService.Count(player: Player): number
	local list = carrying[player]
	return list and #list or 0
end

local function updateCarry(player: Player)
	local list = carrying[player] or {}
	Registry.DataService.SetExtra(player, "Carrying", #list)
	Registry.DataService.SetExtra(player, "Capacity", EggService.Capacity(player))
	Registry.UpgradeService.ApplySpeed(player)
end

local function attach(player: Player, model: Model, index: number): boolean
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not head then
		return false
	end
	model:PivotTo(head.CFrame * CFrame.new(0, 1.2 + (index - 1) * (CARRIED_HEIGHT + 0.1), 0))
	local main = Fx.MainPart(model) :: BasePart
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.Massless = true
			if p ~= main then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = main
				weld.Part1 = p
				weld.Parent = p
			end
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = main
	weld.Parent = main
	model.Parent = character
	return true
end

local function grab(player: Player, egg: Model)
	if not egg.Parent or egg:GetAttribute("Taken") then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if Registry.StealService.IsStealing(player) then
		Remotes.Notify:FireClient(player, "Your hands are full with a stolen dragon!", "Error")
		return
	end
	local list = carrying[player] or {}
	carrying[player] = list
	if #list >= EggService.Capacity(player) then
		Remotes.Notify:FireClient(player, "You can't carry more! Take your eggs home or upgrade Carry.", "Error")
		return
	end
	egg:SetAttribute("Taken", true)
	local info = { Species = egg:GetAttribute("Species"), Mutation = egg:GetAttribute("Mutation") }
	local rarity = rarityOf(info.Species)
	egg:Destroy()

	local model = ModelFactory.Make(rarity.EggModel, CARRIED_HEIGHT)
	local main = Fx.MainPart(model)
	if main then
		Fx.Mutation(main, info.Mutation)
	end
	if not attach(player, model, #list + 1) then
		model:Destroy()
		return
	end
	table.insert(list, { Info = info, Model = model })
	updateCarry(player)
	if rarity.Order >= 5 then
		Remotes.Announce:FireAllClients(("%s grabbed a %s%s Egg!"):format(player.DisplayName, if info.Mutation then info.Mutation .. " " else "", rarity.Name), rarity.Color)
	end
end

-- Drops everything you carry. "Bonk" leaves eggs on the ground; anything else destroys them.
function EggService.DropAll(player: Player, reason: string)
	local list = carrying[player]
	if not list or #list == 0 then
		return
	end
	carrying[player] = {}
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for i, c in list do
		c.Model:Destroy()
		if reason == "Bonk" and root and root.Position.Z > 0 then
			local angle = (i / #list) * math.pi * 2
			local pos = root.Position + Vector3.new(math.cos(angle) * 4, 0, math.sin(angle) * 4)
			spawnWild(c.Info, CFrame.new(pos.X, 0.5, pos.Z), nil, DROPPED_LIFETIME, nil)
		end
	end
	updateCarry(player)
	if reason == "Bonk" then
		Remotes.Notify:FireClient(player, "BONK! You dropped your eggs!", "Error")
	end
end

-- After a rebirth lowers your capacity, drop the extras.
function EggService.TrimToCapacity(player: Player)
	local list = carrying[player]
	if not list then
		return
	end
	local cap = EggService.Capacity(player)
	while #list > cap do
		local c = table.remove(list) :: Carried
		c.Model:Destroy()
	end
	updateCarry(player)
end

local function deliver(player: Player)
	local list = carrying[player]
	if not list or #list == 0 or not Registry.PlotService.IsHome(player) then
		return
	end
	local placed = 0
	while #list > 0 do
		local c = list[1]
		local rarity = rarityOf(c.Info.Species)
		local slot = Registry.BaseService.AddToFreeSlot(player, {
			Species = c.Info.Species,
			Mutation = c.Info.Mutation,
			HatchAt = os.time() + rarity.HatchTime,
		})
		if not slot then
			break
		end
		table.remove(list, 1)
		c.Model:Destroy()
		placed += 1
	end
	-- Re-stack whatever is left.
	for i, c in list do
		local main = Fx.MainPart(c.Model)
		local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
		if main and head then
			for _, w in main:GetChildren() do
				if w:IsA("WeldConstraint") and w.Part0 == head then
					w:Destroy()
				end
			end
			main.CFrame = head.CFrame * CFrame.new(0, 1.2 + (i - 1) * (CARRIED_HEIGHT + 0.1), 0)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = main
			weld.Parent = main
		end
	end
	if placed > 0 then
		updateCarry(player)
		Remotes.Notify:FireClient(player, ("%d egg%s placed on your perches!"):format(placed, if placed == 1 then "" else "s"), "Good")
		local data = Registry.DataService.Get(player)
		if data and not data.Tutorial then
			Registry.DataService.SetExtra(player, "TutorialStep", 3)
		end
	end
	if #list > 0 then
		local last = Registry.DataService.GetExtra(player, "FullWarned") or 0
		if os.clock() - last > 6 then
			Registry.DataService.SetExtra(player, "FullWarned", os.clock())
			Remotes.Notify:FireClient(player, "Your perches are full! Buy more perches or sell a dragon.", "Error")
		end
	end
end

local function onPrompt(prompt: ProximityPrompt, player: Player)
	if prompt:GetAttribute("Kind") ~= "Grab" then
		return
	end
	local egg = prompt:FindFirstAncestorOfClass("Model")
	if egg and CollectionService:HasTag(egg, "WildEgg") then
		grab(player, egg)
	end
end

function EggService.Start()
	folder = Instance.new("Folder")
	folder.Name = "WildEggs"
	folder.Parent = workspace

	ProximityPromptService.PromptTriggered:Connect(onPrompt)

	-- Fill each zone at the start, then top up over time.
	for z = 1, #Zones.List do
		for _ = 1, MAX_PER_ZONE - 2 do
			spawnInZone(z)
		end
	end
	task.spawn(function()
		while true do
			task.wait(SPAWN_EVERY)
			for z = 1, #Zones.List do
				if (zoneCounts[z] or 0) < MAX_PER_ZONE then
					spawnInZone(z)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.2)
			for player in carrying do
				deliver(player)
			end
		end
	end)

	local function hookCharacter(player: Player)
		player.CharacterAdded:Connect(function(character)
			-- Respawned: whatever you carried is gone.
			carrying[player] = {}
			updateCarry(player)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				EggService.DropAll(player, "Died")
			end)
		end)
	end
	Players.PlayerAdded:Connect(hookCharacter)
	for _, player in Players:GetPlayers() do
		hookCharacter(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local list = carrying[player]
		carrying[player] = nil
		if list then
			for _, c in list do
				c.Model:Destroy()
			end
		end
	end)
	Registry.DataService.OnLoaded(function(player)
		carrying[player] = carrying[player] or {}
		updateCarry(player)
	end)
end

-- Used by HUD text: "Common Egg" etc.
function EggService.Describe(info: EggInfo): string
	local rarity = rarityOf(info.Species)
	return (if info.Mutation then info.Mutation .. " " else "") .. rarity.Name .. " Egg (" .. Format.Gold(Dragons.BaseIncome(info.Species, info.Mutation)) .. "/s)"
end

return EggService
