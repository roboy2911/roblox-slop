-- First-time guide: a glowing line shows where to go.
--   1. Grab an egg in the meadow   2. Bring it home   3. Collect gold at your chest

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Config.Layout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Tutorial = {}

local player = Players.LocalPlayer
local marker: Part
local beam: Beam
local label: TextLabel
local box: Frame
local finished = false

local function nearestEgg(from: Vector3): Vector3?
	local best, bestDist = nil, math.huge
	for _, egg in CollectionService:GetTagged("WildEgg") do
		if egg:IsA("Model") and egg.Parent then
			local pos = egg:GetPivot().Position
			local d = (pos - from).Magnitude
			if pos.Z < 150 and d < bestDist then
				best, bestDist = pos, d
			end
		end
	end
	return best
end

local function build()
	marker = Instance.new("Part")
	marker.Name = "TutorialTarget"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.new(1, 1, 1)
	marker.Parent = workspace
	local target = Instance.new("Attachment")
	target.Parent = marker
	local arrowGui = Instance.new("BillboardGui")
	arrowGui.Size = UDim2.fromOffset(80, 80)
	arrowGui.StudsOffset = Vector3.new(0, 6, 0)
	arrowGui.AlwaysOnTop = true
	arrowGui.Parent = marker
	local arrow = UI.Label(arrowGui, "⬇", UDim2.fromScale(1, 1), nil, UI.Colors.Gold)
	arrow.Name = "Arrow"

	beam = Instance.new("Beam")
	beam.Attachment1 = target
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80))
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Transparency = NumberSequence.new(0.3)
	beam.Segments = 20
	beam.Parent = marker

	local gui = UI.Screen("Tutorial", 3)
	box = UI.Frame(gui, UDim2.fromOffset(520, 56), UDim2.new(0.5, -260, 0, 120), UI.Colors.Panel)
	UI.Corner(box, 14)
	UI.Stroke(box, UI.Colors.Gold, 3)
	label = UI.Label(box, "", UDim2.new(1, -20, 1, -12), UDim2.fromOffset(10, 6), UI.Colors.Gold)
end

local function finish()
	if finished then
		return
	end
	finished = true
	Remotes.TutorialDone:FireServer()
	label.Text = "You're a Dragon Keeper! Buy Speed to reach rarer eggs."
	marker:Destroy()
	task.delay(6, function()
		box.Parent:Destroy()
	end)
end

function Tutorial.Start()
	local data = State.Data
	while not data do
		State.Changed:Wait()
		data = State.Data
	end
	if data.Tutorial then
		return
	end
	build()
	Remotes.Collected.OnClientEvent:Connect(function()
		if (State.Data and State.Data.TutorialStep) == 3 then
			finish()
		end
	end)
	while not finished do
		task.wait(0.2)
		local d = State.Data
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local plotIndex = player:GetAttribute("Plot")
		if not d or not root or not plotIndex then
			continue
		end
		local rootAttach = root:FindFirstChild("TutorialAttach") :: Attachment?
		if not rootAttach then
			rootAttach = Instance.new("Attachment")
			rootAttach.Name = "TutorialAttach"
			rootAttach.Parent = root
		end
		beam.Attachment0 = rootAttach
		local center = Layout.PlotCenter(plotIndex)
		local target: Vector3?
		if d.TutorialStep == 3 then
			label.Text = "Your egg is hatching! Dragons make gold — grab it at your chest!"
			target = center + Layout.Chest
		elseif (d.Carrying or 0) > 0 then
			label.Text = "Bring the egg home to your castle!"
			target = center + Vector3.new(0, 0, Layout.CastleHalf - 6)
		else
			label.Text = "Run into the meadow and grab an egg! (Hold E)"
			target = nearestEgg(root.Position)
		end
		if target then
			marker.Position = target + Vector3.new(0, 2, 0)
			beam.Enabled = true
		else
			beam.Enabled = false
		end
	end
end

return Tutorial
