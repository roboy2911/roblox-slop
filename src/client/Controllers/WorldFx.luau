-- Things that move in the world (only on your screen):
-- dragons bob and flap, wild eggs spin, the fusion crystal floats,
-- rebirth gates block you, prompts show only when they make sense,
-- and bonks knock you back.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.State)

local WorldFx = {}

local player = Players.LocalPlayer
local ANIMATE_DISTANCE = 140

-- ------------------------------------------------------------ dragons

type Animated = {
	Model: Model,
	Base: CFrame,
	Parts: { { Part: BasePart, Offset: CFrame, Hinge: Vector3?, Side: number } },
	Phase: number,
}

local dragons: { [Model]: Animated } = {}
local spinners: { [Model]: { Base: CFrame, Parts: { [BasePart]: CFrame }, Phase: number, Kind: string } } = {}

local function trackDragon(model: Model)
	if not model:IsA("Model") or dragons[model] then
		return
	end
	-- Wait for parts to stream in.
	task.wait(0.2)
	if not model.Parent then
		return
	end
	local base = model:GetPivot()
	local entry: Animated = { Model = model, Base = base, Parts = {}, Phase = math.random() * 10 }
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local offset = base:ToObjectSpace(p.CFrame)
			local hinge, side = nil, 0
			if p.Name == "WingL" or p.Name == "WingR" then
				side = if offset.Position.X >= 0 then 1 else -1
				-- The hinge is the wing's edge closest to the body.
				hinge = offset.Position - Vector3.new(side * p.Size.X / 2 * 0.9, 0, 0)
			end
			table.insert(entry.Parts, { Part = p, Offset = offset, Hinge = hinge, Side = side })
		end
	end
	dragons[model] = entry
end

local function trackSpinner(model: Instance, kind: string)
	if not model:IsA("Model") or spinners[model] then
		return
	end
	task.wait(0.2)
	if not model.Parent then
		return
	end
	local base = model:GetPivot()
	local parts = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			parts[p] = base:ToObjectSpace(p.CFrame)
		end
	end
	spinners[model] = { Base = base, Parts = parts, Phase = math.random() * 10, Kind = kind }
end

local function animate(now: number)
	local camera = workspace.CurrentCamera
	local camPos = camera and camera.CFrame.Position or Vector3.zero
	for model, entry in dragons do
		if not model.Parent then
			dragons[model] = nil
			continue
		end
		if (entry.Base.Position - camPos).Magnitude > ANIMATE_DISTANCE then
			continue
		end
		local t = now + entry.Phase
		local pivot = entry.Base * CFrame.new(0, math.sin(t * 2) * 0.18 + 0.15, 0) * CFrame.Angles(0, math.sin(t * 0.7) * 0.25, 0)
		local flap = math.sin(t * 7) * 0.45
		for _, info in entry.Parts do
			local cf = pivot * info.Offset
			if info.Hinge then
				local hinge = info.Hinge
				cf = pivot * CFrame.new(hinge) * CFrame.Angles(0, 0, info.Side * flap) * CFrame.new(-hinge) * info.Offset
			end
			info.Part.CFrame = cf
		end
	end
	for model, entry in spinners do
		if not model.Parent then
			spinners[model] = nil
			continue
		end
		if (entry.Base.Position - camPos).Magnitude > ANIMATE_DISTANCE then
			continue
		end
		local t = now + entry.Phase
		local pivot
		if entry.Kind == "WildEgg" then
			pivot = entry.Base * CFrame.new(0, math.sin(t * 2.4) * 0.3 + 0.3, 0) * CFrame.Angles(0, t * 0.8, 0)
		else -- hatching egg: wobble
			pivot = entry.Base * CFrame.Angles(math.sin(t * 9) * 0.12, 0, math.cos(t * 7) * 0.12)
		end
		for p, offset in entry.Parts do
			p.CFrame = pivot * offset
		end
	end
end

-- Fusion altar crystals float and spin.
local crystals: { [BasePart]: CFrame } = {}
local function trackCrystals()
	local plots = workspace:WaitForChild("Plots")
	local function add(d: Instance)
		if d:IsA("BasePart") and d.Name == "Crystal" and d:FindFirstAncestor("Plots") then
			crystals[d] = d.CFrame
		end
	end
	for _, d in plots:GetDescendants() do
		add(d)
	end
	plots.DescendantAdded:Connect(add)
end

-- ------------------------------------------------------------ prompts

local function myPlotFolder(): Instance?
	local index = player:GetAttribute("Plot")
	local plots = workspace:FindFirstChild("Plots")
	return index and plots and plots:FindFirstChild("Plot" .. index)
end

local function plotOfOwner(ownerId: number): Instance?
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerId") == ownerId then
			return plot
		end
	end
	return nil
end

local function updatePrompt(prompt: ProximityPrompt)
	local kind = prompt:GetAttribute("Kind")
	if kind == "Sell" then
		prompt.Enabled = prompt:GetAttribute("OwnerId") == player.UserId
	elseif kind == "Steal" then
		local ownerId = prompt:GetAttribute("OwnerId")
		local plot = ownerId and plotOfOwner(ownerId)
		local locked = plot and (plot:GetAttribute("LockedUntil") or 0) > workspace:GetServerTimeNow()
		local data = State.Data
		local handsFull = data and ((data.Carrying or 0) > 0 or data.Stealing ~= nil)
		prompt.Enabled = ownerId ~= player.UserId and not locked and not handsFull
	elseif kind == "Fuse" then
		local mine = myPlotFolder()
		prompt.Enabled = mine ~= nil and prompt:GetAttribute("Plot") == mine:GetAttribute("Index")
	end
end

local prompts: { [ProximityPrompt]: boolean } = {}
local function trackPrompts()
	local function add(d: Instance)
		if d:IsA("ProximityPrompt") then
			prompts[d] = true
			updatePrompt(d)
			d.Destroying:Connect(function()
				prompts[d] = nil
			end)
		end
	end
	for _, d in workspace:GetDescendants() do
		add(d)
	end
	workspace.DescendantAdded:Connect(add)
	task.spawn(function()
		while true do
			task.wait(0.4)
			for prompt in prompts do
				if prompt.Parent then
					updatePrompt(prompt)
				else
					prompts[prompt] = nil
				end
			end
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("Kind") == "Grab" then
			Notifications.Sound("Grab", 0.6)
		end
	end)
end

-- ------------------------------------------------------------ rebirth gates

local function updateGates(data)
	for _, gate in CollectionService:GetTagged("RebirthGate") do
		if gate:IsA("BasePart") then
			local blocked = (data and data.Rebirths or 0) < (gate:GetAttribute("Rebirths") or 0)
			gate.CanCollide = blocked
			gate.Transparency = if blocked then 0.2 else 1
			for _, gui in gate:GetChildren() do
				if gui:IsA("BillboardGui") then
					gui.Enabled = blocked
				end
			end
		end
	end
end

-- ------------------------------------------------------------ knockback

local function onKnockback(velocity: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
	root.AssemblyLinearVelocity = velocity
	Notifications.Sound("Bonk", 0.8)
	-- A quick camera shake.
	local camera = workspace.CurrentCamera
	local started = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t > 0.35 then
			conn:Disconnect()
			return
		end
		local strength = (0.35 - t) * 1.2
		camera.CFrame *= CFrame.Angles(math.random(-10, 10) / 100 * strength, math.random(-10, 10) / 100 * strength, 0)
	end)
	task.delay(0.9, function()
		if humanoid.Parent and humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

function WorldFx.Start()
	for _, m in CollectionService:GetTagged("Dragon") do
		task.spawn(trackDragon, m)
	end
	CollectionService:GetInstanceAddedSignal("Dragon"):Connect(trackDragon)
	for _, m in CollectionService:GetTagged("WildEgg") do
		task.spawn(trackSpinner, m, "WildEgg")
	end
	CollectionService:GetInstanceAddedSignal("WildEgg"):Connect(function(m)
		trackSpinner(m, "WildEgg")
	end)
	for _, m in CollectionService:GetTagged("HatchingEgg") do
		task.spawn(trackSpinner, m, "Hatching")
	end
	CollectionService:GetInstanceAddedSignal("HatchingEgg"):Connect(function(m)
		trackSpinner(m, "Hatching")
	end)
	task.spawn(trackCrystals)
	task.spawn(trackPrompts)

	State.Watch(updateGates)
	CollectionService:GetInstanceAddedSignal("RebirthGate"):Connect(function()
		updateGates(State.Data)
	end)
	Remotes.Knockback.OnClientEvent:Connect(onKnockback)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		animate(now)
		for crystal, base in crystals do
			if not crystal.Parent then
				crystals[crystal] = nil
			else
				crystal.CFrame = base * CFrame.new(0, math.sin(now * 1.5) * 0.4, 0) * CFrame.Angles(0, now * 0.9, 0)
			end
		end
	end)
end

return WorldFx
