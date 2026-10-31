-- Draws the Elder Dragon's fire wave from the timing the server publishes
-- (ReplicatedStorage.Hazard attributes). The server does the actual hit checks.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Hazard = require(ReplicatedStorage.Shared.Config.Hazard)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Fx = require(ReplicatedStorage.Shared.Fx)
local Notifications = require(script.Parent.Notifications)

local HazardFx = {}

local WIDTH = Zones.HalfWidth * 2 + 20
local EMITTERS = 14

local wall: Part
local glow: Part
local emitters: { ParticleEmitter } = {}
local dragon: Model? = nil
local dragonParts: { { Part: BasePart, Offset: CFrame, Hinge: Vector3?, Side: number } } = {}
local tint: ColorCorrectionEffect
local warnedFor = 0
local roaredFor = 0

local function buildWall()
	local folder = Instance.new("Folder")
	folder.Name = "HazardFx"
	folder.Parent = workspace

	wall = Instance.new("Part")
	wall.Name = "FireWall"
	wall.Anchored = true
	wall.CanCollide = false
	wall.CanQuery = false
	wall.CanTouch = false
	wall.CastShadow = false
	wall.Material = Enum.Material.Neon
	wall.Transparency = 1
	wall.Size = Vector3.new(WIDTH, 30, 6)
	wall.CFrame = CFrame.new(0, -200, 0)
	wall.Parent = folder

	glow = wall:Clone()
	glow.Name = "FireGlow"
	glow.Size = Vector3.new(WIDTH, 0.4, 40)
	glow.Parent = folder

	for i = 1, EMITTERS do
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(-WIDTH / 2 + (i - 0.5) * WIDTH / EMITTERS, -10, 0)
		a.Parent = wall
		local e = Fx.Emitter(a, {
			Image = "FxFlame",
			Rate = 0,
			Size = 9,
			Lifetime = NumberRange.new(0.6, 1.1),
			Speed = NumberRange.new(14, 26),
			SpreadAngle = Vector2.new(20, 20),
			Acceleration = Vector3.new(0, 10, 0),
			LightEmission = 1,
		})
		e.EmissionDirection = Enum.NormalId.Top
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(0.6, 14), NumberSequenceKeypoint.new(1, 2) })
		table.insert(emitters, e)
	end
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 4
	light.Parent = wall

	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "FireTint"
	tint.TintColor = Color3.new(1, 1, 1)
	tint.Parent = Lighting
end

local function loadDragon()
	local templates = ReplicatedStorage:WaitForChild("Templates", 30)
	local template = templates and templates:WaitForChild("ElderDragon", 30)
	if not template then
		return
	end
	local model = template:Clone() :: Model
	model:PivotTo(CFrame.new(0, -300, 0))
	model.Parent = workspace:WaitForChild("HazardFx")
	local base = model:GetPivot()
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local offset = base:ToObjectSpace(p.CFrame)
			local hinge, side = nil, 0
			if p.Name == "WingL" or p.Name == "WingR" then
				side = if offset.Position.X >= 0 then 1 else -1
				hinge = offset.Position - Vector3.new(side * p.Size.X / 2 * 0.9, 0, 0)
			end
			table.insert(dragonParts, { Part = p, Offset = offset, Hinge = hinge, Side = side })
		end
	end
	dragon = model
end

local function poseDragon(pivot: CFrame, flap: number)
	for _, info in dragonParts do
		local cf = pivot * info.Offset
		if info.Hinge then
			cf = pivot * CFrame.new(info.Hinge) * CFrame.Angles(0, 0, info.Side * flap) * CFrame.new(-info.Hinge) * info.Offset
		end
		info.Part.CFrame = cf
	end
end

local function setFire(on: boolean, color: Color3, height: number)
	for _, e in emitters do
		e.Rate = if on then 30 else 0
		e.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 0.6), 0.5), color)
	end
	wall.Color = color
	glow.Color = color
	wall.Transparency = if on then 0.35 else 1
	glow.Transparency = if on then 0.5 else 1
	wall.Size = Vector3.new(WIDTH, height, 6)
	local light = wall:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = color
		light.Enabled = on
	end
end

local markers: { BasePart }? = nil

local function setShelterGlow(level: number)
	if not markers then
		local world = workspace:FindFirstChild("World")
		if not world then
			return
		end
		local found = {}
		for _, d in world:GetDescendants() do
			if d.Name == "SafeZone" and d:IsA("BasePart") then
				table.insert(found, d)
			end
		end
		markers = found
	end
	for _, marker in markers :: { BasePart } do
		marker.Transparency = 0.75 - level * 0.45
	end
end

local lastShelterLevel = -1

local function update()
	local state = ReplicatedStorage:FindFirstChild("Hazard")
	if not state then
		return
	end
	local nextAt = state:GetAttribute("NextAt") or 0
	local speed = state:GetAttribute("Speed") or 45
	local fromZ = state:GetAttribute("FromZ") or Zones.ValleyEnd
	local toZ = state:GetAttribute("ToZ") or 0
	local info = Hazard.Types[state:GetAttribute("Type") or 1] or Hazard.Types[1]
	local now = workspace:GetServerTimeNow()
	local t = now - nextAt
	local duration = (fromZ - toZ) / speed
	local camera = workspace.CurrentCamera

	-- Warning: shelters glow, the dragon roars.
	local warning = t > -Hazard.Warning and t < duration
	local shelterLevel = if warning then 0.6 + math.sin(now * 8) * 0.4 else 0
	if math.abs(shelterLevel - lastShelterLevel) > 0.05 then
		lastShelterLevel = shelterLevel
		setShelterGlow(shelterLevel)
	end
	if t > -Hazard.Warning and t < 0 and warnedFor ~= nextAt then
		warnedFor = nextAt
		markers = nil -- rescan; more of the map may have streamed in
		Notifications.Banner(("🐉 %s INCOMING! Hide under a glowing rock shelter!"):format(info.Name:upper()), info.Color)
	end

	if t >= 0 and t <= duration then
		if roaredFor ~= nextAt then
			roaredFor = nextAt
			Notifications.Sound("Roar", 0.9)
			Notifications.Sound("Fire", 0.6)
		end
		local z = fromZ - speed * t
		setFire(true, info.Color, info.Height)
		wall.CFrame = CFrame.new(0, info.Height / 2, z)
		glow.CFrame = CFrame.new(0, 0.3, z + 18)
		if dragon then
			local x = math.sin(t * 0.9) * (Zones.HalfWidth * 0.6)
			local pivot = CFrame.lookAt(Vector3.new(x, info.Height + 22, z + 25), Vector3.new(x + math.cos(t * 0.9) * 40, info.Height + 10, z - 40))
			poseDragon(pivot, math.sin(now * 5) * 0.55)
		end
		-- Red screen when the fire is close.
		local camZ = camera and camera.CFrame.Position.Z or 0
		local closeness = math.clamp(1 - math.abs(camZ - z) / 80, 0, 1)
		tint.TintColor = Color3.new(1, 1 - closeness * 0.35, 1 - closeness * 0.5)
	else
		if wall.Transparency < 1 then
			setFire(false, info.Color, info.Height)
			wall.CFrame = CFrame.new(0, -200, 0)
			glow.CFrame = CFrame.new(0, -200, 0)
			tint.TintColor = Color3.new(1, 1, 1)
		end
		if dragon then
			if t < 0 and t > -Hazard.Warning then
				-- Swooping in over the far end.
				local k = 1 + t / Hazard.Warning -- 0 → 1
				local pivot = CFrame.lookAt(Vector3.new(0, 140 - k * 90, fromZ + 160 - k * 130), Vector3.new(0, 30, fromZ - 100))
				poseDragon(pivot, math.sin(now * 4) * 0.6)
			elseif t > duration and t < duration + 6 then
				-- Flying away into the sky.
				local k = (t - duration) / 6
				local pivot = CFrame.lookAt(Vector3.new(0, 60 + k * 200, toZ - k * 150), Vector3.new(0, 200, toZ - 400))
				poseDragon(pivot, math.sin(now * 4) * 0.6)
			else
				poseDragon(CFrame.new(0, -300, 0), 0)
			end
		end
	end
end

function HazardFx.Start()
	buildWall()
	task.spawn(loadDragon)
	RunService.RenderStepped:Connect(update)
end

return HazardFx
