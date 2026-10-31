-- Toasts, server-wide banners, the "NEW DRAGON!" popup, and gold-collect effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Format = require(ReplicatedStorage.Shared.Format)
local Income = require(ReplicatedStorage.Shared.Income)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HUD = require(script.Parent.HUD)
local Preview = require(script.Parent.Preview)
local SoundFx = require(script.Parent.SoundFx)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Notifications = {}

local gui: ScreenGui
local toastHolder: Frame
local bannerHolder: Frame

local KIND_COLORS = {
	Good = Color3.fromRGB(70, 190, 90),
	Warn = Color3.fromRGB(240, 170, 40),
	Error = Color3.fromRGB(220, 65, 65),
	Info = Color3.fromRGB(70, 130, 230),
}

function Notifications.Sound(name: string, volume: number?, pitch: number?)
	SoundFx.Play(name, volume, pitch)
end

function Notifications.Toast(text: string, kind: string?, sound: string?)
	local color = KIND_COLORS[kind or "Info"] or KIND_COLORS.Info
	local f = UI.Frame(toastHolder, UDim2.new(1, 0, 0, 44), nil, color)
	f.LayoutOrder = -math.floor(os.clock() * 100)
	UI.Corner(f, 12)
	UI.Stroke(f, UI.Colors.Stroke, 3)
	UI.Gradient(f, color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(0, 0, 0), 0.2))
	local l = UI.Label(f, text, UDim2.new(1, -16, 1, -10), UDim2.fromOffset(8, 5))
	l.TextWrapped = true
	UI.Pop(f, 1.2)
	if sound then
		Notifications.Sound(sound)
	elseif kind == "Error" then
		Notifications.Sound("Error")
	end
	task.delay(4, function()
		TweenService:Create(f, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		task.wait(0.3)
		f:Destroy()
	end)
	-- Keep at most 4.
	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder -- newest first
	end)
	for i = 5, #toasts do
		toasts[i]:Destroy()
	end
end

function Notifications.Banner(text: string, color: Color3?, sound: string?)
	local f = UI.Frame(bannerHolder, UDim2.new(1, 0, 0, 52), nil, UI.Colors.Panel)
	f.BackgroundTransparency = 0.15
	UI.Corner(f, 14)
	UI.Stroke(f, color or UI.Colors.Gold, 3)
	local l = UI.Label(f, text, UDim2.new(1, -20, 1, -12), UDim2.fromOffset(10, 6), color or UI.Colors.Gold)
	l.TextWrapped = true
	UI.Pop(f, 1.3)
	Notifications.Sound(sound or "Announce")
	task.delay(6, function()
		f:Destroy()
	end)
end

-- Big center popup when a dragon hatches, gets fused or stolen.
local popupBusy = false
local queue = {}

local function showDragon(species: string, mutation: string?, isNew: boolean, how: string)
	popupBusy = true
	local s = Dragons.ByName[species]
	local rarity = Rarities.ByName[s.Rarity]
	local frame = UI.Frame(gui, UDim2.fromOffset(340, 400), UDim2.fromScale(0.5, 0.45), UI.Colors.Panel)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	UI.Corner(frame, 20)
	UI.Stroke(frame, rarity.Color, 5)
	UI.Gradient(frame, rarity.Color:Lerp(UI.Colors.Panel, 0.55), UI.Colors.Panel)

	-- Spinning rays behind the dragon.
	local rays = Instance.new("ImageLabel")
	rays.BackgroundTransparency = 1
	rays.Image = "rbxasset://textures/particles/sparkles_main.dds"
	rays.ImageColor3 = rarity.Color
	rays.Size = UDim2.fromOffset(300, 300)
	rays.Position = UDim2.new(0.5, -150, 0, 30)
	rays.ImageTransparency = 0.3
	rays.Parent = frame

	local headline = if isNew then "NEW DRAGON!" elseif how == "Fused" then "FUSED!" elseif how == "Stolen" then "STOLEN!" else "HATCHED!"
	UI.Label(frame, headline, UDim2.new(1, -20, 0, 48), UDim2.fromOffset(10, 10), if isNew then UI.Colors.Gold else UI.Colors.Text)
	local view = UI.Frame(frame, UDim2.fromOffset(240, 200), UDim2.new(0.5, -120, 0, 64))
	view.BackgroundTransparency = 1
	local vp = Preview.Make(view, species)
	UI.Label(frame, (if mutation then mutation .. " " else "") .. species, UDim2.new(1, -20, 0, 40), UDim2.fromOffset(10, 270),
		if mutation then Dragons.MutationByName[mutation].Color else UI.Colors.Text)
	UI.Label(frame, rarity.Name, UDim2.new(1, -20, 0, 28), UDim2.fromOffset(10, 312), rarity.Color)
	local data = State.Data
	local perSecond = Dragons.BaseIncome(species, mutation) * (if data then Income.Multiplier(data, (data.Passes or {}).DoubleGold == true) else 1)
	UI.Label(frame, "+" .. Format.Gold(perSecond) .. "/s", UDim2.new(1, -20, 0, 30), UDim2.fromOffset(10, 346), UI.Colors.Green)

	UI.Pop(frame, 0.3)
	Notifications.Sound(if isNew or how == "Fused" then "NewDragon" elseif how == "Stolen" then "Sneak" else "Hatch")

	local camera = vp.CurrentCamera
	local model = vp:FindFirstChildWhichIsA("Model")
	local spin = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation += dt * 40
		if model and camera then
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, dt * 1.2, 0))
		end
	end)
	task.wait(if isNew then 3 else 2)
	TweenService:Create(frame, TweenInfo.new(0.25), { Position = UDim2.fromScale(0.5, 1.4) }):Play()
	task.wait(0.25)
	spin:Disconnect()
	frame:Destroy()
	popupBusy = false
	local nextOne = table.remove(queue, 1)
	if nextOne then
		task.spawn(showDragon, table.unpack(nextOne))
	end
end

function Notifications.Dragon(species: string, mutation: string?, isNew: boolean, how: string)
	if not Dragons.ByName[species] then
		return
	end
	if popupBusy then
		if #queue < 4 then
			table.insert(queue, { species, mutation, isNew, how })
		end
		return
	end
	task.spawn(showDragon, species, mutation, isNew, how)
end

-- "+$1.2K" flying up from the gold counter.
function Notifications.Collected(amount: number)
	HUD.Bump()
	Notifications.Sound("Collect", 1, 0.95 + math.random() * 0.1)
	local pos = HUD.GoldPosition()
	local l = UI.Label(gui, "+" .. Format.Gold(amount), UDim2.fromOffset(240, 50), UDim2.fromOffset(pos.X - 120, pos.Y - 90), UI.Colors.Gold)
	l.ZIndex = 10
	TweenService:Create(l, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { Position = UDim2.fromOffset(pos.X - 120, pos.Y - 190), TextTransparency = 1 }):Play()
	-- A few coins popping out.
	for i = 1, math.clamp(math.floor(math.log10(amount + 1) * 2), 2, 10) do
		local coin = UI.Label(gui, "🪙", UDim2.fromOffset(30, 30), UDim2.fromOffset(pos.X - 15, pos.Y - 15))
		coin.TextStrokeTransparency = 1
		coin.ZIndex = 9
		local angle = (i / 10) * math.pi * 2
		TweenService:Create(coin, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(pos.X - 15 + math.cos(angle) * 90, pos.Y - 15 + math.sin(angle) * 60 - 40),
			TextTransparency = 1,
		}):Play()
		task.delay(0.7, function()
			coin:Destroy()
		end)
	end
	task.delay(1.2, function()
		l:Destroy()
	end)
end

function Notifications.Start()
	gui = UI.Screen("Notifications", 10)
	toastHolder = UI.Frame(gui, UDim2.fromOffset(340, 230), UDim2.new(1, -352, 0, 70))
	toastHolder.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = toastHolder

	bannerHolder = UI.Frame(gui, UDim2.fromOffset(560, 180), UDim2.new(0.5, -280, 0, 66))
	bannerHolder.BackgroundTransparency = 1
	local bannerLayout = Instance.new("UIListLayout")
	bannerLayout.Padding = UDim.new(0, 6)
	bannerLayout.Parent = bannerHolder

	Remotes.Notify.OnClientEvent:Connect(Notifications.Toast)
	Remotes.Announce.OnClientEvent:Connect(Notifications.Banner)
	Remotes.NewDragon.OnClientEvent:Connect(Notifications.Dragon)
	Remotes.Collected.OnClientEvent:Connect(Notifications.Collected)

	-- Bonking the Elder Dragon boss: a big "BONK!" with hits left.
	local bonkLabel = UI.Label(gui, "", UDim2.fromOffset(420, 60), UDim2.new(0.5, -210, 0.28, 0), UI.Colors.Orange)
	bonkLabel.Visible = false
	local shownAt = 0
	Remotes.BossHit.OnClientEvent:Connect(function(left)
		Notifications.Sound("Bonk", 1, 0.8 + math.random() * 0.4)
		bonkLabel.Text = if left > 0 then ("💥 BONK! %d to go"):format(left) else "💥 FINAL BONK!"
		bonkLabel.Visible = true
		bonkLabel.Rotation = math.random(-8, 8)
		UI.Pop(bonkLabel, 1.4)
		shownAt = os.clock()
		task.delay(0.9, function()
			if os.clock() - shownAt >= 0.85 then
				bonkLabel.Visible = false
			end
		end)
	end)
end

return Notifications
