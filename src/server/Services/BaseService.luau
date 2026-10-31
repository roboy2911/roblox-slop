-- Your castle's perches and the dragons on them.
--
-- Eggs you bring home go on a free perch and hatch after a while. Hatched
-- dragons earn gold every second into your treasure chest; walk up to the
-- chest to collect it. Hold E on a dragon to sell it. Other players see a
-- Steal prompt instead (see StealService).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Layout = require(ReplicatedStorage.Shared.Config.Layout)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Format = require(ReplicatedStorage.Shared.Format)
local Fx = require(ReplicatedStorage.Shared.Fx)
local Income = require(ReplicatedStorage.Shared.Income)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ModelFactory = require(script.Parent.ModelFactory)
local Registry = require(script.Parent.Registry)

local BaseService = {}

local PERCH_HEIGHT = 3.2
local DRAGON_HEIGHT = 3.4
local EGG_HEIGHT = 2.6

type Visuals = {
	Folder: Folder,
	Perches: { [number]: Model },
	Occupants: { [number]: Instance },
	Labels: { [number]: TextLabel },
	ChestLabel: TextLabel?,
}

local visuals: { [Player]: Visuals } = {}

local function key(i: number): string
	return tostring(i)
end

local function perchCFrame(center: Vector3, i: number): CFrame
	local pos = center + Layout.Perches[i]
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
end

-- ------------------------------------------------------------ labels

local function billboard(adornee: Instance, height: number): (BillboardGui, TextLabel, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(170, 62)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.55)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextStrokeTransparency = 0.15
	title.Parent = gui
	local sub = title:Clone()
	sub.Name = "Sub"
	sub.Position = UDim2.fromScale(0, 0.55)
	sub.Size = UDim2.fromScale(1, 0.45)
	sub.TextColor3 = Color3.fromRGB(120, 255, 120)
	sub.Parent = gui
	gui.Parent = adornee
	return gui, title, sub
end

-- ------------------------------------------------------------ rendering

local function clearSlot(v: Visuals, i: number)
	local old = v.Occupants[i]
	if old then
		old:Destroy()
		v.Occupants[i] = nil
	end
	v.Labels[i] = nil
end

local function addPrompt(parent: Instance, name: string, action: string, object: string, hold: number, owner: Player, i: number)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = if name == "StealPrompt" then Enum.KeyCode.F else Enum.KeyCode.E
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OneGlobally
	prompt:SetAttribute("Kind", if name == "StealPrompt" then "Steal" else "Sell")
	prompt:SetAttribute("OwnerId", owner.UserId)
	prompt:SetAttribute("Slot", i)
	prompt.Parent = parent
end

function BaseService.RenderSlot(player: Player, i: number)
	local v = visuals[player]
	local data = Registry.DataService.Get(player)
	local plot = Registry.PlotService.Get(player)
	if not v or not data or not plot then
		return
	end
	clearSlot(v, i)
	local slot = data.Slots[key(i)]
	if not slot or i > data.Perches then
		return
	end
	local species = Dragons.ByName[slot.Species]
	if not species then
		return
	end
	local rarity = Rarities.ByName[species.Rarity]
	local base = perchCFrame(plot.Center, i) * CFrame.new(0, PERCH_HEIGHT, 0)

	local holder = Instance.new("Folder")
	holder.Name = "Slot" .. i
	holder.Parent = v.Folder
	v.Occupants[i] = holder

	-- Something to hang the label and prompts on.
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = base * CFrame.new(0, 1.5, 0)
	anchor.Parent = holder

	if slot.Stolen then
		local _, title, sub = billboard(anchor, 3)
		title.Text = "STOLEN!"
		title.TextColor3 = Color3.fromRGB(255, 70, 70)
		sub.Text = "Bonk the thief!"
		sub.TextColor3 = Color3.fromRGB(255, 200, 200)
		return
	end

	if slot.HatchAt then
		local egg = ModelFactory.Make(rarity.EggModel, EGG_HEIGHT)
		egg:PivotTo(base)
		egg.Parent = holder
		local main = Fx.MainPart(egg)
		if main then
			Fx.Mutation(main, slot.Mutation)
		end
		CollectionService:AddTag(egg, "HatchingEgg")
		local _, title, sub = billboard(anchor, 3)
		title.Text = (if slot.Mutation then slot.Mutation .. " " else "") .. rarity.Name .. " Egg"
		title.TextColor3 = rarity.Color
		sub.TextColor3 = Color3.fromRGB(255, 255, 255)
		sub.Text = "Hatching " .. Format.Time(slot.HatchAt - os.time())
		v.Labels[i] = sub
		return
	end

	local dragon = ModelFactory.Make(species.Name, DRAGON_HEIGHT * rarity.Scale)
	dragon:PivotTo(base)
	dragon:SetAttribute("Species", species.Name)
	dragon.Parent = holder
	CollectionService:AddTag(dragon, "Dragon")
	local main = Fx.MainPart(dragon)
	if main then
		Fx.Mutation(main, slot.Mutation)
	end

	local income = Income.Slot(slot) * Income.Multiplier(data, Registry.ShopService.HasPass(player, "DoubleGold"))
	local _, title, sub = billboard(anchor, DRAGON_HEIGHT * rarity.Scale + 0.5)
	title.Text = (if slot.Mutation then slot.Mutation .. " " else "") .. species.Name
	title.TextColor3 = if slot.Mutation then Dragons.MutationByName[slot.Mutation].Color else rarity.Color
	sub.Text = Format.Gold(income) .. "/s"

	local sellPrice = math.floor(Income.Slot(slot) * Dragons.SellSeconds)
	addPrompt(anchor, "SellPrompt", "Sell for " .. Format.Gold(sellPrice), species.Name, 1.2, player, i)
	local hold = Economy.StealHoldBase + (rarity.Order - 1) * Economy.StealHoldPerRarity
	addPrompt(anchor, "StealPrompt", "Steal", (if slot.Mutation then slot.Mutation .. " " else "") .. species.Name, hold, player, i)
end

local function ensurePerches(player: Player)
	local v = visuals[player]
	local data = Registry.DataService.Get(player)
	local plot = Registry.PlotService.Get(player)
	if not v or not data or not plot then
		return
	end
	for i = 1, math.min(data.Perches, #Layout.Perches) do
		if not v.Perches[i] then
			local perch = ModelFactory.Make("Perch", PERCH_HEIGHT)
			perch:PivotTo(perchCFrame(plot.Center, i))
			perch.Parent = v.Folder
			v.Perches[i] = perch
			ModelFactory.Collider(Vector3.new(3, PERCH_HEIGHT, 3), perchCFrame(plot.Center, i) * CFrame.new(0, PERCH_HEIGHT / 2, 0), perch)
		end
	end
end

function BaseService.RenderAll(player: Player)
	ensurePerches(player)
	for i = 1, #Layout.Perches do
		BaseService.RenderSlot(player, i)
	end
end

local function setupChest(player: Player)
	local v = visuals[player]
	local plot = Registry.PlotService.Get(player)
	if not v or not plot then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "ChestLabel"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = plot.Center + Layout.Chest + Vector3.new(0, 4, 0)
	anchor.Parent = v.Folder
	local gui, title, sub = billboard(anchor, 2.5)
	gui.Size = UDim2.fromOffset(220, 74)
	gui.MaxDistance = 120
	title.TextColor3 = Color3.fromRGB(255, 215, 60)
	title.Text = "$0"
	sub.TextColor3 = Color3.fromRGB(255, 255, 255)
	sub.Text = "Walk here to collect"
	v.ChestLabel = title
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 200, 80)
	glow.Range = 12
	glow.Brightness = 1.2
	glow.Parent = anchor
	Fx.Emitter(anchor, { Image = "FxCoin", Rate = 2, Size = 0.8, Speed = NumberRange.new(2, 4), Acceleration = Vector3.new(0, -6, 0), SpreadAngle = Vector2.new(30, 30) })
end

-- ------------------------------------------------------------ API

function BaseService.IncomePerSecond(player: Player): number
	local data = Registry.DataService.Get(player)
	if not data then
		return 0
	end
	return Income.PerSecond(data, Registry.ShopService.HasPass(player, "DoubleGold"))
end

local function refreshIncome(player: Player)
	Registry.DataService.SetExtra(player, "Income", BaseService.IncomePerSecond(player))
end

function BaseService.FreeSlots(player: Player): number
	local data = Registry.DataService.Get(player)
	if not data then
		return 0
	end
	local free = 0
	for i = 1, data.Perches do
		if not data.Slots[key(i)] then
			free += 1
		end
	end
	return free
end

-- Marks a species as found. Returns true the first time.
function BaseService.Discover(player: Player, species: string): boolean
	local data = Registry.DataService.Get(player)
	if not data or data.Discovered[species] then
		return false
	end
	data.Discovered[species] = true
	Registry.DataService.Changed(player)
	return true
end

-- Puts an egg or dragon on the first free perch. Returns the slot, or nil if full.
function BaseService.AddToFreeSlot(player: Player, slot: { Species: string, Mutation: string?, HatchAt: number? }): number?
	local data = Registry.DataService.Get(player)
	if not data then
		return nil
	end
	for i = 1, data.Perches do
		if not data.Slots[key(i)] then
			data.Slots[key(i)] = { Species = slot.Species, Mutation = slot.Mutation, HatchAt = slot.HatchAt }
			if not slot.HatchAt then
				BaseService.Discover(player, slot.Species)
			end
			Registry.DataService.Changed(player)
			BaseService.RenderSlot(player, i)
			refreshIncome(player)
			return i
		end
	end
	return nil
end

function BaseService.RemoveSlot(player: Player, i: number)
	local data = Registry.DataService.Get(player)
	if not data then
		return
	end
	data.Slots[key(i)] = nil
	Registry.DataService.Changed(player)
	BaseService.RenderSlot(player, i)
	refreshIncome(player)
end

function BaseService.SetStolen(player: Player, i: number, stolen: boolean)
	local data = Registry.DataService.Get(player)
	local slot = data and data.Slots[key(i)]
	if not slot then
		return
	end
	slot.Stolen = if stolen then true else nil
	Registry.DataService.Changed(player)
	BaseService.RenderSlot(player, i)
	refreshIncome(player)
end

local function hatch(player: Player, i: number, slot)
	slot.HatchAt = nil
	local isNew = BaseService.Discover(player, slot.Species)
	Registry.DataService.Changed(player)
	BaseService.RenderSlot(player, i)
	refreshIncome(player)
	Remotes.NewDragon:FireClient(player, slot.Species, slot.Mutation, isNew, "Hatched")
end

function BaseService.HatchAll(player: Player)
	local data = Registry.DataService.Get(player)
	if not data then
		return
	end
	for i = 1, #Layout.Perches do
		local slot = data.Slots[key(i)]
		if slot and slot.HatchAt then
			hatch(player, i, slot)
		end
	end
end

function BaseService.AddPerch(player: Player)
	ensurePerches(player)
	local data = Registry.DataService.Get(player)
	if data then
		BaseService.RenderSlot(player, data.Perches)
	end
end

-- Recalculates every label (after a rebirth or pass purchase changes income).
function BaseService.RefreshLabels(player: Player)
	BaseService.RenderAll(player)
	refreshIncome(player)
end

-- ------------------------------------------------------------ loops

local function collect(player: Player, data)
	local amount = math.floor(data.Pending)
	if amount < 1 then
		return
	end
	data.Pending -= amount
	Registry.DataService.AddGold(player, amount)
	Remotes.Collected:FireClient(player, amount)
end

local function tick()
	local now = os.time()
	for player, v in visuals do
		local data = Registry.DataService.Get(player)
		if not data then
			continue
		end
		-- Hatch eggs whose time is up; update the countdowns.
		for i = 1, #Layout.Perches do
			local slot = data.Slots[key(i)]
			if slot and slot.HatchAt and not slot.Stolen then
				if now >= slot.HatchAt then
					hatch(player, i, slot)
				elseif v.Labels[i] then
					v.Labels[i].Text = "Hatching " .. Format.Time(slot.HatchAt - now)
				end
			end
		end
		-- Pay out.
		local income = BaseService.IncomePerSecond(player)
		if Registry.ShopService.HasPass(player, "AutoCollect") then
			Registry.DataService.AddGold(player, income)
		else
			data.Pending += income
			Registry.DataService.Changed(player)
		end
		if v.ChestLabel then
			v.ChestLabel.Text = Format.Gold(data.Pending)
		end
		Registry.DataService.SetExtra(player, "Income", income)
	end
end

local function chestLoop()
	while true do
		task.wait(0.2)
		for player in visuals do
			local data = Registry.DataService.Get(player)
			local plot = Registry.PlotService.Get(player)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if data and plot and root then
				local chest = plot.Center + Layout.Chest
				if (Vector3.new(root.Position.X, 0, root.Position.Z) - chest).Magnitude < Layout.ChestRadius then
					collect(player, data)
				end
			end
		end
	end
end

local function onPrompt(prompt: ProximityPrompt, player: Player)
	if prompt:GetAttribute("Kind") ~= "Sell" or prompt:GetAttribute("OwnerId") ~= player.UserId then
		return
	end
	local i = prompt:GetAttribute("Slot")
	local data = Registry.DataService.Get(player)
	local slot = data and data.Slots[key(i)]
	if not slot or slot.HatchAt or slot.Stolen then
		return
	end
	local price = math.floor(Income.Slot(slot) * Dragons.SellSeconds)
	BaseService.RemoveSlot(player, i)
	Registry.DataService.AddGold(player, price)
	Remotes.Notify:FireClient(player, ("Sold %s for %s"):format(slot.Species, Format.Gold(price)), "Good")
end

local function onLoaded(player: Player, data)
	-- Wait for PlotService to hand out a castle.
	local plot = nil
	for _ = 1, 50 do
		plot = Registry.PlotService.Get(player)
		if plot or not player.Parent then
			break
		end
		task.wait(0.1)
	end
	if not plot or not player.Parent then
		return
	end

	-- Clean up anything odd left over from a crash.
	for k, slot in data.Slots do
		slot.Stolen = nil
		if not Dragons.ByName[slot.Species] then
			data.Slots[k] = nil
		end
	end

	-- First time playing: a free dragon so gold starts flowing right away.
	if not data.Starter then
		data.Starter = true
		data.Slots["1"] = data.Slots["1"] or { Species = Economy.StarterDragon }
		data.Discovered[Economy.StarterDragon] = true
	end

	local folder = Instance.new("Folder")
	folder.Name = "Base"
	folder.Parent = plot.Folder
	visuals[player] = { Folder = folder, Perches = {}, Occupants = {}, Labels = {} }
	setupChest(player)

	-- Hatch eggs that finished while you were away.
	local now = os.time()
	for _, slot in data.Slots do
		if slot.HatchAt and slot.HatchAt <= now then
			slot.HatchAt = nil
			data.Discovered[slot.Species] = true
		end
	end
	BaseService.RenderAll(player)
	refreshIncome(player)

	-- Offline earnings.
	if data.LastSeen and data.LastSeen > 0 then
		local seconds = math.clamp(now - data.LastSeen, 0, Economy.MaxOfflineHours * 3600)
		local earned = math.floor(BaseService.IncomePerSecond(player) * seconds * Economy.OfflineRate)
		if earned > 0 then
			data.Pending += earned
			task.delay(4, function()
				if player.Parent then
					Remotes.Notify:FireClient(player, ("Your dragons earned %s while you were away! Collect it at your chest."):format(Format.Gold(earned)), "Good")
				end
			end)
		end
	end
	Registry.DataService.Changed(player)
end

function BaseService.Start()
	Registry.DataService.OnLoaded(onLoaded)
	Players.PlayerRemoving:Connect(function(player)
		local v = visuals[player]
		visuals[player] = nil
		if v then
			v.Folder:Destroy()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(onPrompt)
	Remotes.TutorialDone.OnServerEvent:Connect(function(player)
		local data = Registry.DataService.Get(player)
		if data and not data.Tutorial then
			data.Tutorial = true
			Registry.DataService.Changed(player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			tick()
		end
	end)
	task.spawn(chestLoop)
end

return BaseService
