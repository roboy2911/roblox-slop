-- The admin panel. Press F4 (only for user IDs in Config/Admins.luau).
-- Pick a player on the left, then use the buttons. The server re-checks
-- that you're an admin for every action.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Admins = require(ReplicatedStorage.Shared.Config.Admins)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.UI)

local AdminPanel = {}

local player = Players.LocalPlayer
local selected: Player = player
local status: TextLabel
local targetLabel: TextLabel

local GREY = Color3.fromRGB(110, 115, 135)

local function run(action: string, args: { [string]: any }?)
	local a = args or {}
	a.Target = selected.UserId
	status.Text = "..."
	status.TextColor3 = UI.Colors.Muted
	local ok, message = Remotes.Admin:InvokeServer(action, a)
	status.Text = message or ""
	status.TextColor3 = if ok then UI.Colors.Green else UI.Colors.Red
end

local function textBox(parent: Instance, placeholder: string, width: number): TextBox
	local box = Instance.new("TextBox")
	box.Size = UDim2.fromOffset(width, 40)
	box.BackgroundColor3 = UI.Colors.Panel
	box.Font = UI.Font
	box.PlaceholderText = placeholder
	box.Text = ""
	box.TextScaled = true
	box.TextColor3 = UI.Colors.Text
	box.ClearTextOnFocus = false
	box.Parent = parent
	UI.Corner(box, 8)
	UI.Stroke(box, UI.Colors.Stroke, 2)
	return box
end

local function row(parent: Instance, order: number, title: string?): Frame
	local holder = UI.Frame(parent, UDim2.new(1, -8, 0, if title then 70 else 44), nil, UI.Colors.PanelLight)
	holder.BackgroundTransparency = if title then 0 else 1
	holder.LayoutOrder = order
	UI.Corner(holder, 10)
	local y = 2
	if title then
		local l = UI.Label(holder, title, UDim2.new(1, -12, 0, 20), UDim2.fromOffset(8, 3), UI.Colors.Gold)
		l.TextXAlignment = Enum.TextXAlignment.Left
		y = 24
	end
	local inner = UI.Frame(holder, UDim2.new(1, -12, 0, 42), UDim2.fromOffset(6, y))
	inner.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = inner
	return inner
end

local function button(parent: Instance, text: string, color: Color3, width: number, onClick: () -> ()): TextButton
	return UI.Button(parent, text, color, UDim2.fromOffset(width, 38), nil, onClick)
end

-- A button that cycles through a list of choices when clicked.
local function cycler(parent: Instance, choices: { string }, width: number, color: Color3?): () -> string
	local index = 1
	local b = UI.Button(parent, choices[1], color or GREY, UDim2.fromOffset(width, 38))
	b.Activated:Connect(function()
		index = index % #choices + 1
		b.Text = choices[index]
	end)
	b.MouseButton2Click:Connect(function()
		index = (index - 2) % #choices + 1
		b.Text = choices[index]
	end)
	return function()
		return choices[index]
	end
end

local function build()
	local panel = UI.Panel("🛠️ Admin Panel", Color3.fromRGB(60, 60, 75), UDim2.fromScale(0.72, 0.82))
	local body = panel.Body

	-- Players list.
	local left = UI.Frame(body, UDim2.new(0, 180, 1, -34), UDim2.new(), UI.Colors.PanelLight)
	UI.Corner(left, 10)
	local playersTitle = UI.Label(left, "Players", UDim2.new(1, -10, 0, 24), UDim2.fromOffset(5, 4), UI.Colors.Gold)
	playersTitle.TextXAlignment = Enum.TextXAlignment.Left
	local playerList = Instance.new("ScrollingFrame")
	playerList.BackgroundTransparency = 1
	playerList.BorderSizePixel = 0
	playerList.Size = UDim2.new(1, -8, 1, -34)
	playerList.Position = UDim2.fromOffset(4, 30)
	playerList.ScrollBarThickness = 6
	playerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	playerList.CanvasSize = UDim2.new()
	playerList.Parent = left
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.SortOrder = Enum.SortOrder.Name
	listLayout.Parent = playerList

	local function refreshPlayers()
		for _, child in playerList:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		if not selected.Parent then
			selected = player
		end
		for _, p in Players:GetPlayers() do
			local isSelected = p == selected
			local b = UI.Button(playerList, p.DisplayName, if isSelected then UI.Colors.Green else GREY, UDim2.new(1, -8, 0, 36))
			b.Name = p.DisplayName
			b.Activated:Connect(function()
				selected = p
				targetLabel.Text = ("Target: %s (@%s)"):format(p.DisplayName, p.Name)
				refreshPlayers()
			end)
		end
		targetLabel.Text = ("Target: %s (@%s)"):format(selected.DisplayName, selected.Name)
	end

	-- Actions.
	local right = Instance.new("ScrollingFrame")
	right.BackgroundTransparency = 1
	right.BorderSizePixel = 0
	right.Size = UDim2.new(1, -192, 1, -34)
	right.Position = UDim2.fromOffset(190, 0)
	right.ScrollBarThickness = 8
	right.AutomaticCanvasSize = Enum.AutomaticSize.Y
	right.CanvasSize = UDim2.new()
	right.Parent = body
	local rightLayout = Instance.new("UIListLayout")
	rightLayout.Padding = UDim.new(0, 8)
	rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rightLayout.Parent = right

	targetLabel = UI.Label(right, "", UDim2.new(1, -8, 0, 28), nil, UI.Colors.Text)
	targetLabel.LayoutOrder = 0
	targetLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- Player stats.
	local r1 = row(right, 1, "Give (to the target)")
	local amount = textBox(r1, "Amount", 110)
	button(r1, "Gold", UI.Colors.Gold, 80, function()
		run("Gold", { Amount = amount.Text })
	end)
	button(r1, "Spins", Color3.fromRGB(240, 110, 180), 80, function()
		run("Spins", { Amount = amount.Text })
	end)
	button(r1, "Lucky", UI.Colors.Green, 80, function()
		run("Lucky", { Amount = amount.Text })
	end)
	button(r1, "Set Rebirths", UI.Colors.Purple, 120, function()
		run("SetRebirths", { Amount = amount.Text })
	end)

	-- Dragons.
	local names = {}
	for _, s in Dragons.List do
		table.insert(names, s.Name)
	end
	local r2 = row(right, 2, "Dragon (click to change, right-click to go back)")
	local species = cycler(r2, names, 130, UI.Colors.Blue)
	local mutation = cycler(r2, { "Normal", "Golden", "Shadow" }, 100)
	button(r2, "Give Dragon", UI.Colors.Green, 120, function()
		run("Dragon", { Species = species(), Mutation = mutation() })
	end)
	button(r2, "Give Egg", UI.Colors.Orange, 100, function()
		run("Dragon", { Species = species(), Mutation = mutation(), Egg = true })
	end)

	local r3 = row(right, 3, "Target's base")
	button(r3, "Max Upgrades", UI.Colors.Blue, 140, function()
		run("MaxUpgrades")
	end)
	button(r3, "Hatch All", UI.Colors.Green, 110, function()
		run("HatchAll")
	end)

	-- Server.
	local r4 = row(right, 4, "Server")
	button(r4, "Fire Wave", UI.Colors.Red, 110, function()
		run("Wave")
	end)
	button(r4, "Calm Dragon", UI.Colors.Blue, 120, function()
		run("Calm")
	end)
	button(r4, "Star Shower", Color3.fromRGB(120, 200, 255), 120, function()
		run("Star")
	end)
	button(r4, "Summon Boss", Color3.fromRGB(200, 60, 40), 130, function()
		run("Boss")
	end)

	local r5 = row(right, 5, "Announce to everyone")
	local message = textBox(r5, "Message...", 300)
	button(r5, "Announce", UI.Colors.Gold, 110, function()
		run("Announce", { Text = message.Text })
		message.Text = ""
	end)

	-- Teleports.
	local r6 = row(right, 6, "Teleport")
	button(r6, "Go To Target", UI.Colors.Blue, 120, function()
		run("GoTo")
	end)
	button(r6, "Bring Target", UI.Colors.Blue, 120, function()
		run("Bring")
	end)
	local zoneNames = { "Home" }
	for _, z in Zones.List do
		table.insert(zoneNames, z.Name)
	end
	local zone = cycler(r6, zoneNames, 130)
	button(r6, "Go", UI.Colors.Green, 60, function()
		run("Zone", { Zone = (table.find(zoneNames, zone()) or 1) - 1 })
	end)

	-- Danger zone.
	local r7 = row(right, 7, "Danger")
	local reason = textBox(r7, "Kick reason (optional)", 200)
	button(r7, "Kick", UI.Colors.Red, 80, function()
		run("Kick", { Text = reason.Text })
	end)
	local wipeArmed = false
	local wipe: TextButton
	wipe = button(r7, "Wipe Data", UI.Colors.Red, 120, function()
		if not wipeArmed then
			wipeArmed = true
			wipe.Text = "Sure? Click again"
			task.delay(3, function()
				wipeArmed = false
				wipe.Text = "Wipe Data"
			end)
			return
		end
		wipeArmed = false
		wipe.Text = "Wipe Data"
		run("ResetData")
	end)

	status = UI.Label(body, "Pick a player, then an action.", UDim2.new(1, -10, 0, 26), UDim2.new(0, 5, 1, -28), UI.Colors.Muted)
	status.TextXAlignment = Enum.TextXAlignment.Left

	Players.PlayerAdded:Connect(refreshPlayers)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshPlayers)
	end)
	panel.OnOpen.Event:Connect(refreshPlayers)
	refreshPlayers()
	return panel
end

function AdminPanel.Start()
	if not table.find(Admins, player.UserId) then
		return
	end
	local panel = build()
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.F4 and not processed then
			panel.Toggle()
		end
	end)
end

return AdminPanel
