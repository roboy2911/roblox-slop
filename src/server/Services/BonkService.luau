-- The Bonk Club. Everyone gets one. Click to swing; hitting someone knocks
-- them back and makes them drop their eggs (which land on the ground) and
-- any dragon they're stealing (which flies home).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ModelFactory = require(script.Parent.ModelFactory)
local Registry = require(script.Parent.Registry)

local BonkService = {}

local lastSwing: { [Player]: number } = {}
local template: Tool? = nil

local function makeTemplate(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Bonk Club"
	tool.ToolTip = "Bonk thieves and egg carriers!"
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local model = ModelFactory.Make("Club", 4.5)
	local handle = model:FindFirstChild("Handle") :: BasePart
	if not handle then
		handle = model:FindFirstChildWhichIsA("BasePart") :: BasePart
		handle.Name = "Handle"
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
			if p ~= handle then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = p
				weld.Parent = p
				p.Parent = handle
			end
		end
	end
	handle.Parent = tool
	model:Destroy()
	-- The club is long along its Y axis, knob at the top. Hold it near the bottom.
	local size = handle.Size
	tool.Grip = CFrame.fromMatrix(Vector3.new(0, -size.Y * 0.32, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1))
	return tool
end

local function swing(player: Player, tool: Tool)
	local now = os.clock()
	if now - (lastSwing[player] or 0) < Economy.BonkCooldown then
		return
	end
	lastSwing[player] = now

	-- Plays the default "slash" arm animation.
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local best, bestDist = nil, Economy.BonkRange
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			local otherRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = other.Character:FindFirstChildOfClass("Humanoid")
			if otherRoot and humanoid and humanoid.Health > 0 then
				local offset = otherRoot.Position - root.Position
				local dist = offset.Magnitude
				if dist < bestDist and (dist < 3 or root.CFrame.LookVector:Dot(offset.Unit) > 0.2) then
					best, bestDist = other, dist
				end
			end
		end
	end
	if not best then
		return
	end
	local otherRoot = (best.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
	local dir = (otherRoot.Position - root.Position) * Vector3.new(1, 0, 1)
	if dir.Magnitude < 0.01 then
		dir = root.CFrame.LookVector
	end
	Remotes.Knockback:FireClient(best, dir.Unit * Economy.BonkKnockback + Vector3.new(0, 28, 0))
	Registry.EggService.DropAll(best, "Bonk")
	Registry.StealService.Fail(best, "Bonk")
	Remotes.Notify:FireClient(player, "BONK!", "Good", "Bonk")
	Registry.QuestService.Add(player, "Bonk")
end

local function give(player: Player)
	if not template then
		template = makeTemplate()
	end
	local backpack = player:WaitForChild("Backpack", 10)
	if not backpack or backpack:FindFirstChild("Bonk Club") then
		return
	end
	local tool = (template :: Tool):Clone()
	tool.Activated:Connect(function()
		swing(player, tool)
	end)
	tool.Parent = backpack
end

function BonkService.Start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			give(player)
		end)
		if player.Character then
			task.spawn(give, player)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
end

return BonkService
