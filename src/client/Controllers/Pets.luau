-- Draws everyone's pet dragon (player attribute "Pet"), flying along beside them.
-- Purely visual, so each client draws them itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Pets = {}

local PET_HEIGHT = 2.4
local DRAW_DISTANCE = 160

type Pet = {
	Species: string,
	Model: Model,
	Parts: { { Part: BasePart, Offset: CFrame, Hinge: Vector3?, Side: number } },
	Pivot: CFrame,
	Phase: number,
}

local pets: { [Player]: Pet } = {}

local function make(species: string): Pet?
	local templates = ReplicatedStorage:FindFirstChild("Templates")
	local template = templates and templates:FindFirstChild(species)
	if not template then
		return nil
	end
	local model = template:Clone() :: Model
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * PET_HEIGHT / math.max(size.Y, 0.1))
	model:PivotTo(CFrame.new())
	local base = model:GetPivot()
	local parts = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			local offset = base:ToObjectSpace(p.CFrame)
			local hinge, side = nil, 0
			if p.Name == "WingL" or p.Name == "WingR" then
				side = if offset.Position.X >= 0 then 1 else -1
				hinge = offset.Position - Vector3.new(side * p.Size.X / 2 * 0.9, 0, 0)
			end
			table.insert(parts, { Part = p, Offset = offset, Hinge = hinge, Side = side })
		end
	end
	model.Name = "Pet"
	model.Parent = workspace
	return { Species = species, Model = model, Parts = parts, Pivot = CFrame.new(0, -500, 0), Phase = math.random() * 10 }
end

local function sync(player: Player)
	local species = player:GetAttribute("Pet")
	local current = pets[player]
	if current and current.Species ~= species then
		current.Model:Destroy()
		pets[player] = nil
		current = nil
	end
	if species and not current then
		pets[player] = make(species) :: any
	end
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	local camPos = camera and camera.CFrame.Position or Vector3.zero
	local now = os.clock()
	for player, pet in pets do
		if not player.Parent then
			pet.Model:Destroy()
			pets[player] = nil
			continue
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or (root.Position - camPos).Magnitude > DRAW_DISTANCE then
			pet.Model.Parent = nil
			continue
		end
		pet.Model.Parent = workspace
		local t = now + pet.Phase
		-- Float behind your right shoulder, facing where you face.
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude < 0.01 then
			look = Vector3.new(0, 0, -1)
		end
		local goalPos = (root.CFrame * CFrame.new(3, 1.2 + math.sin(t * 2.5) * 0.35, 2.5)).Position
		local goal = CFrame.lookAt(goalPos, goalPos + look.Unit)
		if (pet.Pivot.Position - goalPos).Magnitude > 40 then
			pet.Pivot = goal -- teleported or respawned: snap
		else
			pet.Pivot = pet.Pivot:Lerp(goal, math.min(1, dt * 6))
		end
		local flap = math.sin(t * 9) * 0.55
		for _, info in pet.Parts do
			local cf = pet.Pivot * info.Offset
			if info.Hinge then
				cf = pet.Pivot * CFrame.new(info.Hinge) * CFrame.Angles(0, 0, info.Side * flap) * CFrame.new(-info.Hinge) * info.Offset
			end
			info.Part.CFrame = cf
		end
	end
end

function Pets.Start()
	local function hook(player: Player)
		sync(player)
		player:GetAttributeChangedSignal("Pet"):Connect(function()
			sync(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerAdded:Connect(hook)
	RunService.RenderStepped:Connect(update)
end

return Pets
