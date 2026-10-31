-- The always-on screen: gold, income, carried eggs, speed, lock timer,
-- the Elder Dragon countdown, and the menu buttons on the left.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Hazard = require(ReplicatedStorage.Shared.Config.Hazard)
local Boosts = require(ReplicatedStorage.Shared.Boosts)
local Format = require(ReplicatedStorage.Shared.Format)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local HUD = {}

-- Other controllers register their panels here so the menu can open them.
HUD.Buttons = {} :: { [string]: TextButton }

local gui: ScreenGui
local goldLabel: TextLabel
local incomeLabel: TextLabel
local carryLabel: TextLabel
local speedLabel: TextLabel
local lockLabel: TextLabel
local waveBar: Frame
local waveFill: Frame
local waveText: TextLabel
local shownGold = 0

local function pill(parent: Instance, size: UDim2, position: UDim2, color: Color3): Frame
	local f = UI.Frame(parent, size, position, color)
	UI.Corner(f, 14)
	UI.Stroke(f, UI.Colors.Stroke, 3)
	UI.Gradient(f, color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(0, 0, 0), 0.25))
	return f
end

local function buildGold()
	local box = pill(gui, UDim2.fromOffset(280, 86), UDim2.new(0.5, -140, 1, -100), UI.Colors.Panel)
	local coin = UI.Label(box, "💰", UDim2.fromOffset(56, 56), UDim2.fromOffset(10, 6))
	coin.TextStrokeTransparency = 1
	goldLabel = UI.Label(box, "$0", UDim2.new(1, -80, 0, 50), UDim2.fromOffset(70, 4), UI.Colors.Gold)
	goldLabel.TextXAlignment = Enum.TextXAlignment.Left
	incomeLabel = UI.Label(box, "+$0/s", UDim2.new(1, -80, 0, 26), UDim2.fromOffset(72, 54), UI.Colors.Green)
	incomeLabel.TextXAlignment = Enum.TextXAlignment.Left
	goldLabel.Name = "Gold"
end

local function buildStats()
	-- Top-left (the bottom-right corner is under the jump button on phones).
	local box = pill(gui, UDim2.fromOffset(170, 112), UDim2.fromOffset(12, 8), UI.Colors.Panel)
	carryLabel = UI.Label(box, "🥚 0/1", UDim2.new(1, -20, 0, 30), UDim2.fromOffset(10, 8))
	carryLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedLabel = UI.Label(box, "👟 22", UDim2.new(1, -20, 0, 30), UDim2.fromOffset(10, 42))
	speedLabel.TextXAlignment = Enum.TextXAlignment.Left
	lockLabel = UI.Label(box, "🔓 Unlocked", UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 78), UI.Colors.Muted)
	lockLabel.TextXAlignment = Enum.TextXAlignment.Left
end

local boostBox: Frame
local boostLabel: TextLabel

local function buildBoosts()
	boostBox = pill(gui, UDim2.fromOffset(170, 34), UDim2.fromOffset(12, 128), UI.Colors.Green)
	boostLabel = UI.Label(boostBox, "", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4))
	boostBox.Visible = false
end

local function updateBoosts(data)
	local parts = {}
	if Boosts.IsWeekend() then
		table.insert(parts, "🍀 2x Luck")
	end
	if (data.FriendBonus or 0) > 0 then
		table.insert(parts, ("👥 +%d%%"):format(math.floor(data.FriendBonus * 100 + 0.5)))
	end
	boostBox.Visible = #parts > 0
	boostLabel.Text = table.concat(parts, "  ")
end

local function buildWave()
	waveBar = pill(gui, UDim2.fromOffset(420, 46), UDim2.new(0.5, -210, 0, 12), UI.Colors.Panel)
	waveFill = UI.Frame(waveBar, UDim2.new(0, 0, 1, -10), UDim2.fromOffset(5, 5), UI.Colors.Orange)
	UI.Corner(waveFill, 10)
	waveText = UI.Label(waveBar, "", UDim2.new(1, -20, 1, -12), UDim2.fromOffset(10, 6))
	waveText.ZIndex = 2
end

local MENU = {
	{ Name = "Upgrades", Icon = "⚡ Upgrades", Color = UI.Colors.Blue },
	{ Name = "Rebirth", Icon = "♻️ Rebirth", Color = UI.Colors.Purple },
	{ Name = "Index", Icon = "📖 Index", Color = UI.Colors.Green },
	{ Name = "Shop", Icon = "🛒 Shop", Color = UI.Colors.Gold },
	{ Name = "Rewards", Icon = "🎁 Rewards", Color = UI.Colors.Red },
	{ Name = "Spin", Icon = "🎡 Spin", Color = Color3.fromRGB(240, 110, 180) },
	{ Name = "Quests", Icon = "📜 Quests", Color = UI.Colors.Orange },
	{ Name = "Achievements", Icon = "🏅 Goals", Color = Color3.fromRGB(80, 190, 200) },
}

local function buildMenu()
	-- Below the stats and boost boxes (top-left), so they never overlap.
	local holder = UI.Frame(gui, UDim2.fromOffset(150, #MENU * 52), UDim2.new(0, 12, 0.5, -#MENU * 26 + 40))
	holder.BackgroundTransparency = 1
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = holder
	for i, item in MENU do
		local b = UI.Button(holder, item.Icon, item.Color, UDim2.fromOffset(150, 46))
		b.LayoutOrder = i
		HUD.Buttons[item.Name] = b
	end
end

-- A red bubble with a number on a menu button ("2 rewards ready").
function HUD.SetBadge(name: string, count: number)
	local button = HUD.Buttons[name]
	if not button then
		return
	end
	local badge = button:FindFirstChild("Badge") :: TextLabel?
	if not badge then
		local b = UI.Label(button, "", UDim2.fromOffset(28, 28), UDim2.fromScale(1, 0), UI.Colors.Text)
		b.Name = "Badge"
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.BackgroundTransparency = 0
		b.BackgroundColor3 = UI.Colors.Red
		b.ZIndex = 5
		UI.Corner(b, 14)
		badge = b
	end
	local b = badge :: TextLabel
	if count > 0 and not b.Visible then
		UI.Pop(b, 1.6)
	end
	b.Visible = count > 0
	b.Text = tostring(count)
end

local function updateWave()
	if workspace:GetAttribute("BossActive") then
		local now = workspace:GetServerTimeNow()
		waveText.Text = "🐉 THE ELDER DRAGON LANDED! Bonk it for treasure!"
		waveFill.Size = UDim2.new(1, -10, 1, -10)
		waveFill.BackgroundColor3 = if math.floor(now * 2) % 2 == 0 then UI.Colors.Red else UI.Colors.Orange
		return
	end
	local state = ReplicatedStorage:FindFirstChild("Hazard")
	if not state then
		waveText.Text = "🐉 The Elder Dragon sleeps..."
		return
	end
	local nextAt = state:GetAttribute("NextAt") or 0
	local speed = state:GetAttribute("Speed") or 45
	local typeInfo = Hazard.Types[state:GetAttribute("Type") or 1] or Hazard.Types[1]
	local now = workspace:GetServerTimeNow()
	local untilWave = nextAt - now
	local duration = ((state:GetAttribute("FromZ") or 900) - (state:GetAttribute("ToZ") or 0)) / speed
	if untilWave > Hazard.Warning then
		waveText.Text = ("🐉 Elder Dragon wakes in %s"):format(Format.Time(untilWave))
		waveFill.Size = UDim2.new(math.clamp(1 - untilWave / Hazard.Interval, 0, 1), -10, 1, -10)
		waveFill.BackgroundColor3 = UI.Colors.Orange
		waveBar.BackgroundColor3 = UI.Colors.Panel
	elseif untilWave > 0 then
		waveText.Text = ("🔥 %s in %d! HIDE UNDER A ROCK!"):format(typeInfo.Name:upper(), math.ceil(untilWave))
		waveFill.Size = UDim2.new(1, -10, 1, -10)
		waveFill.BackgroundColor3 = if math.floor(now * 4) % 2 == 0 then UI.Colors.Red else typeInfo.Color
	elseif -untilWave < duration then
		waveText.Text = ("🔥 %s!"):format(typeInfo.Name:upper())
		waveFill.Size = UDim2.new(math.clamp(1 + untilWave / duration, 0, 1), -10, 1, -10)
		waveFill.BackgroundColor3 = typeInfo.Color
	else
		waveText.Text = "🐉 The dragon is resting..."
		waveFill.Size = UDim2.new(0, 0, 1, -10)
	end
end

local function onState(data)
	updateBoosts(data)
	incomeLabel.Text = "+" .. Format.Gold(data.Income or 0) .. "/s"
	carryLabel.Text = ("🥚 %d/%d"):format(data.Carrying or 0, data.Capacity or 1)
	if data.Stealing then
		carryLabel.Text = "🐉 Stealing!"
	end
	speedLabel.Text = "👟 " .. tostring(data.Speed or 22)
end

function HUD.Start()
	gui = UI.Screen("HUD", 1)
	buildGold()
	buildStats()
	buildBoosts()
	buildWave()
	buildMenu()
	State.Watch(onState)

	RunService.RenderStepped:Connect(function(dt)
		local data = State.Data
		if data then
			-- Count the gold up smoothly.
			local target = data.Gold
			if math.abs(target - shownGold) < 1 then
				shownGold = target
			else
				shownGold += (target - shownGold) * math.min(1, dt * 8)
			end
			goldLabel.Text = Format.Gold(shownGold)
			local lockedUntil = data.LockedUntil or 0
			local left = lockedUntil - workspace:GetServerTimeNow()
			if left > 0 then
				lockLabel.Text = "🔒 " .. Format.Time(left)
				lockLabel.TextColor3 = UI.Colors.Green
			else
				lockLabel.Text = "🔓 Unlocked"
				lockLabel.TextColor3 = UI.Colors.Muted
			end
		end
		updateWave()
	end)
end

-- Makes the gold box bounce (used when you collect).
function HUD.Bump()
	if goldLabel then
		UI.Pop(goldLabel.Parent :: GuiObject, 1.12)
	end
end

function HUD.GoldPosition(): Vector2
	if not goldLabel then
		return Vector2.zero
	end
	return goldLabel.AbsolutePosition + goldLabel.AbsoluteSize / 2
end

return HUD
