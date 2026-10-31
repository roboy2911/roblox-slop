-- The Elder Dragon lands. Every Boss.Interval seconds it comes down in one of
-- the middle zones for Boss.Duration seconds. Players bonk it with their club;
-- it stomps every few seconds (get out of the red circle). Beat it and it drops
-- a shower of eggs, and everyone who hit it gets a reward. Fire waves pause
-- while it's on the ground.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Boss = require(ReplicatedStorage.Shared.Config.Boss)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Boosts = require(ReplicatedStorage.Shared.Boosts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ModelFactory = require(script.Parent.ModelFactory)
local Registry = require(script.Parent.Registry)

local BossService = {}

type Fight = {
	Model: Model,
	Position: Vector3,
	Zone: number,
	Health: number,
	MaxHealth: number,
	Hits: { [Player]: number },
	Fill: Frame,
	Label: TextLabel,
	Ends: number,
	Over: boolean,
}

local current: Fight? = nil
local rng = Random.new()
local nextLanding = 0

local function healthBar(anchor: BasePart): (Frame, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(360, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 38, 0)
	gui.MaxDistance = 400
	gui.AlwaysOnTop = true
	gui.Adornee = anchor
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 30)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 120, 90)
	title.TextStrokeTransparency = 0.1
	title.Text = "🐉 ELDER DRAGON — bonk it!"
	title.Parent = gui
	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, 0, 0, 30)
	back.Position = UDim2.fromOffset(0, 36)
	back.BackgroundColor3 = Color3.fromRGB(30, 20, 20)
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 10)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 60, 50)
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 10)
	local label = title:Clone()
	label.Size = UDim2.fromScale(1, 1)
	label.Position = UDim2.new()
	label.TextColor3 = Color3.new(1, 1, 1)
	label.ZIndex = 2
	label.Parent = back
	gui.Parent = anchor
	return fill, label
end

local function updateBar(fight: Fight)
	fight.Fill.Size = UDim2.fromScale(math.clamp(fight.Health / fight.MaxHealth, 0, 1), 1)
	fight.Label.Text = ("%d / %d"):format(math.max(0, fight.Health), fight.MaxHealth)
end

local function stomp(fight: Fight)
	-- A red circle grows on the ground, then the stomp knocks back anyone inside.
	local ring = Instance.new("Part")
	ring.Name = "StompWarning"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 50, 40)
	ring.Transparency = 0.45
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(fight.Position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	local d = Boss.StompRadius * 2
	TweenService:Create(ring, TweenInfo.new(Boss.StompWarning, Enum.EasingStyle.Linear), { Size = Vector3.new(0.3, d, d) }):Play()
	task.wait(Boss.StompWarning)
	ring:Destroy()
	if fight.Over then
		return
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local offset = (root.Position - fight.Position) * Vector3.new(1, 0, 1)
			if offset.Magnitude < Boss.StompRadius and root.Position.Y < fight.Position.Y + 14 then
				local dir = if offset.Magnitude > 0.1 then offset.Unit else Vector3.new(0, 0, -1)
				Remotes.Knockback:FireClient(player, dir * 70 + Vector3.new(0, 45, 0))
				Registry.EggService.DropAll(player, "Bonk")
				Registry.StealService.Fail(player, "Bonk")
			end
		end
	end
end

local function finish(fight: Fight, beaten: boolean)
	if fight.Over then
		return
	end
	fight.Over = true
	current = nil
	workspace:SetAttribute("BossActive", false)
	if beaten then
		Remotes.Announce:FireAllClients("🎉 The Elder Dragon was beaten! Treasure is raining down!", Color3.fromRGB(255, 215, 80), "NewDragon")
		-- Egg rain around where it fell: one rarity better than the zone.
		local zone = Zones.List[fight.Zone]
		for i = 1, Boss.EggRain do
			task.delay(i * 0.12, function()
				local rarity = Zones.RollRarity(zone, rng)
				local better = Rarities.ByName[rarity]
				local up = Rarities.List[math.min(better.Order + 1, 6)]
				local species = Dragons.RollSpecies(up.Name, rng)
				local angle = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(6, 22)
				local pos = fight.Position + Vector3.new(math.cos(angle) * r, 0.5, math.sin(angle) * r)
				Registry.EggService.SpawnSpecial(species.Name, Dragons.RollMutation(Boosts.Luck() * 2, rng), CFrame.new(pos), 90)
			end)
		end
		-- Rewards for everyone who helped; the top hitter's egg is Golden.
		local top, topHits = nil, 0
		for player, hits in fight.Hits do
			if hits > topHits then
				top, topHits = player, hits
			end
		end
		-- Zone 2 -> Epic, 3 -> Legendary, 4 -> Mythic.
		local eggRarity = Rarities.List[math.min(fight.Zone + 2, 6)].Name
		for player in fight.Hits do
			if player.Parent then
				local reward = table.clone(Boss.Reward)
				reward.Egg = { Rarity = eggRarity, Mutation = if player == top then "Golden" else nil }
				local got = Registry.RewardService.Grant(player, reward)
				Remotes.Notify:FireClient(player, (if player == top then "🏆 Top bonker! " else "Boss reward: ") .. got, "Good", "Sell")
				Registry.QuestService.Add(player, "Boss")
			end
		end
	else
		Remotes.Announce:FireAllClients("🐉 The Elder Dragon flew away... be faster next time!", Color3.fromRGB(255, 140, 90), "Roar")
	end
	-- Fly up and away.
	local model = fight.Model
	local start = model:GetPivot()
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < 3 and model.Parent do
			local k = (os.clock() - t0) / 3
			model:PivotTo(start * CFrame.new(0, k * k * 160, -k * 120))
			task.wait()
		end
		model:Destroy()
	end)
end

-- Called by BonkService when a player swings. True if they hit the boss.
function BossService.TryHit(player: Player, root: BasePart): boolean
	local fight = current
	if not fight or fight.Over then
		return false
	end
	local offset = (root.Position - fight.Position) * Vector3.new(1, 0, 1)
	if offset.Magnitude > Boss.HitRange then
		return false
	end
	fight.Health -= 1
	fight.Hits[player] = (fight.Hits[player] or 0) + 1
	updateBar(fight)
	Remotes.BossHit:FireClient(player, math.max(0, fight.Health))
	if fight.Health <= 0 then
		finish(fight, true)
	end
	return true
end

function BossService.IsActive(): boolean
	return current ~= nil
end

function BossService.Land()
	if current then
		return
	end
	local zoneIndex = Boss.Zones[rng:NextInteger(1, #Boss.Zones)]
	local zone = Zones.List[zoneIndex]
	local pos = Vector3.new(rng:NextNumber(-160, 160), 0, rng:NextNumber(zone.StartZ + 50, zone.EndZ - 50))

	local model = ModelFactory.Make("ElderDragon", 26)
	model.Name = "ElderBoss"
	local landed = CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
	-- Build everything at the landing spot first, then lift it all into the sky for the swoop.
	model:PivotTo(landed)

	local anchor = ModelFactory.Collider(Vector3.new(16, 18, 30), CFrame.new(pos + Vector3.new(0, 9, 0)), model, "BossBody")
	local players = #Players:GetPlayers()
	local health = Boss.Health + Boss.HealthPerPlayer * math.max(1, players)
	local fill, label = healthBar(anchor)
	local fight: Fight = {
		Model = model,
		Position = pos,
		Zone = zoneIndex,
		Health = health,
		MaxHealth = health,
		Hits = {},
		Fill = fill,
		Label = label,
		Ends = os.clock() + Boss.Duration,
		Over = false,
	}
	updateBar(fight)
	workspace:SetAttribute("BossActive", true)
	workspace:SetAttribute("BossPosition", pos)

	-- A red beam so everyone can find it.
	local beam = Instance.new("Part")
	beam.Name = "BossBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 70, 50)
	beam.Transparency = 0.6
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(500, 4, 4)
	beam.CFrame = CFrame.new(pos + Vector3.new(0, 250, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = model
	model:PivotTo(landed * CFrame.new(0, 160, 120))
	model.Parent = workspace

	-- Swoop down.
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 2.5 and model.Parent do
			local k = 1 - (1 - (os.clock() - t0) / 2.5) ^ 3
			model:PivotTo(landed * CFrame.new(0, 160 * (1 - k), 120 * (1 - k)))
			task.wait()
		end
		model:PivotTo(landed)
	end)

	-- No fire waves while it's on the ground.
	Registry.HazardService.Delay(Boss.Duration + 15)
	Remotes.Announce:FireAllClients(("🐉 The Elder Dragon landed in %s! Bonk it together for treasure!"):format(zone.Name), Color3.fromRGB(255, 110, 80), "Roar")
	current = fight

	task.spawn(function()
		task.wait(3)
		while not fight.Over and os.clock() < fight.Ends do
			stomp(fight)
			task.wait(Boss.StompEvery - Boss.StompWarning)
		end
		if not fight.Over then
			finish(fight, false)
		end
	end)
end

function BossService.Start()
	workspace:SetAttribute("BossActive", false)
	nextLanding = os.clock() + Boss.FirstLanding
	task.spawn(function()
		while true do
			task.wait(5)
			if not current and os.clock() >= nextLanding then
				nextLanding = os.clock() + Boss.Interval
				BossService.Land()
			end
		end
	end)
end

return BossService
