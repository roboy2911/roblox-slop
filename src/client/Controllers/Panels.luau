-- The menu windows: Upgrades, Rebirth, Index, Shop and the Fusion Altar.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Format = require(ReplicatedStorage.Shared.Format)
local Income = require(ReplicatedStorage.Shared.Income)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HUD = require(script.Parent.HUD)
local Preview = require(script.Parent.Preview)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Panels = {}

local player = Players.LocalPlayer

local function card(parent: Instance, height: number, order: number): Frame
	local f = UI.Frame(parent, UDim2.new(1, -8, 0, height), nil, UI.Colors.PanelLight)
	f.LayoutOrder = order
	UI.Corner(f, 14)
	UI.Stroke(f, UI.Colors.Stroke, 2)
	return f
end

local function list(parent: Instance): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.ScrollBarThickness = 8
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = scroll
	UI.Padding(scroll, 4)
	return scroll
end

-- ------------------------------------------------------------ upgrades

local function buildUpgrades()
	local panel = UI.Panel("⚡ Upgrades", UI.Colors.Blue)
	local scroll = list(panel.Body)
	local rows = {}
	local function row(order: number, icon: string, title: string, kind: string)
		local c = card(scroll, 92, order)
		local i = UI.Label(c, icon, UDim2.fromOffset(62, 62), UDim2.fromOffset(12, 15))
		i.TextStrokeTransparency = 1
		local t = UI.Label(c, title, UDim2.new(0.55, -80, 0, 34), UDim2.fromOffset(84, 10))
		t.TextXAlignment = Enum.TextXAlignment.Left
		local d = UI.Label(c, "", UDim2.new(0.6, -84, 0, 26), UDim2.fromOffset(84, 52), UI.Colors.Muted)
		d.TextXAlignment = Enum.TextXAlignment.Left
		local b = UI.Button(c, "", UI.Colors.Green, UDim2.new(0.36, 0, 0, 58), UDim2.new(0.62, 0, 0, 17), function()
			Remotes.BuyUpgrade:FireServer(kind)
		end)
		rows[kind] = { Desc = d, Button = b }
	end
	row(1, "👟", "Speed", "Speed")
	row(2, "🎒", "Carry", "Carry")
	row(3, "🪺", "Perches", "Perch")

	local function refresh(data)
		if not panel.IsOpen() or not data then
			return
		end
		local function set(kind: string, desc: string, cost: number?)
			local r = rows[kind]
			r.Desc.Text = desc
			if cost then
				r.Button.Text = Format.Gold(cost)
				UI.SetButtonColor(r.Button, if data.Gold >= cost then UI.Colors.Green else Color3.fromRGB(120, 120, 130))
			else
				r.Button.Text = "MAX"
				UI.SetButtonColor(r.Button, Color3.fromRGB(120, 120, 130))
			end
		end
		local speedMaxed = data.SpeedLevel >= Economy.MaxSpeedLevel
		set("Speed", ("Lv %d/%d  •  %d → %d speed"):format(data.SpeedLevel, Economy.MaxSpeedLevel, data.Speed or 0, (data.Speed or 0) + Economy.SpeedPerLevel),
			if speedMaxed then nil else Economy.SpeedCost(data.SpeedLevel))
		local cap = data.Capacity or 1
		set("Carry", ("Carry %d egg%s → %d"):format(cap, if cap == 1 then "" else "s", cap + 1), Economy.CarryCosts[data.CarryLevel + 1])
		set("Perch", ("%d/%d perches"):format(data.Perches, Economy.MaxPerches),
			if data.Perches >= Economy.MaxPerches then nil else Economy.PerchCost(data.Perches))
	end
	State.Changed:Connect(refresh)
	panel.OnOpen.Event:Connect(function()
		refresh(State.Data)
	end)
	HUD.Buttons.Upgrades.Activated:Connect(panel.Toggle)
	Panels.Upgrades = panel
end

-- ------------------------------------------------------------ rebirth

local function buildRebirth()
	local panel = UI.Panel("♻️ Rebirth", UI.Colors.Purple)
	local body = panel.Body
	local title = UI.Label(body, "", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 0))
	local bar = UI.Frame(body, UDim2.new(1, -20, 0, 34), UDim2.fromOffset(10, 50), UI.Colors.Stroke)
	UI.Corner(bar, 12)
	local fill = UI.Frame(bar, UDim2.fromScale(0, 1), nil, UI.Colors.Purple)
	UI.Corner(fill, 12)
	local barText = UI.Label(bar, "", UDim2.new(1, -10, 1, -6), UDim2.fromOffset(5, 3))
	barText.ZIndex = 2
	local keep = UI.Label(body, "", UDim2.new(1, -20, 0, 120), UDim2.fromOffset(10, 96), UI.Colors.Text)
	keep.TextScaled = false
	keep.TextSize = 20
	keep.TextWrapped = true
	keep.TextXAlignment = Enum.TextXAlignment.Left
	keep.TextYAlignment = Enum.TextYAlignment.Top
	keep.RichText = true
	local button = UI.Button(body, "REBIRTH", UI.Colors.Purple, UDim2.new(0.6, 0, 0, 62), UDim2.new(0.2, 0, 1, -70), function()
		Remotes.Rebirth:FireServer()
	end)

	local function refresh(data)
		if not panel.IsOpen() or not data then
			return
		end
		local cost = Economy.RebirthCost(data.Rebirths)
		title.Text = ("Rebirth %d → %d"):format(data.Rebirths, data.Rebirths + 1)
		fill.Size = UDim2.fromScale(math.clamp(data.Gold / cost, 0, 1), 1)
		barText.Text = Format.Gold(data.Gold) .. " / " .. Format.Gold(cost)
		local unlock = ""
		for _, zone in Zones.List do
			if zone.Rebirths == data.Rebirths + 1 then
				unlock = "\n🗺️ Unlocks <b>" .. zone.Name .. "</b>"
			end
		end
		keep.Text = ("<font color='#7CFC7C'>✔ Income x%s → x%s, +%d speed, longer castle lock</font>%s\n"
			.. "<font color='#7CFC7C'>✔ You keep your dragons and perches</font>\n"
			.. "<font color='#FF8080'>✘ Gold, speed and carry upgrades reset</font>"):format(
			tostring(Economy.IncomeMultiplier(data.Rebirths)), tostring(Economy.IncomeMultiplier(data.Rebirths + 1)), Economy.SpeedPerRebirth, unlock)
		UI.SetButtonColor(button, if data.Gold >= cost then UI.Colors.Purple else Color3.fromRGB(120, 120, 130))
	end
	State.Changed:Connect(refresh)
	panel.OnOpen.Event:Connect(function()
		refresh(State.Data)
	end)
	HUD.Buttons.Rebirth.Activated:Connect(panel.Toggle)
	Panels.Rebirth = panel
end

-- ------------------------------------------------------------ index

local function buildIndex()
	local panel = UI.Panel("📖 Dragon Index", UI.Colors.Green, UDim2.fromScale(0.6, 0.7))
	local header = UI.Label(panel.Body, "", UDim2.new(1, 0, 0, 30), UDim2.new(), UI.Colors.Muted)
	local grid = UI.Grid(panel.Body, UDim2.fromOffset(130, 160), UDim2.fromOffset(0, 36), UDim2.new(1, 0, 1, -36))
	local shownFor: { [string]: boolean } = {}
	local cards: { [string]: Frame } = {}

	local function refresh(data)
		if not panel.IsOpen() or not data then
			return
		end
		local found = 0
		for _ in data.Discovered do
			found += 1
		end
		local done = Income.CompletedRarities(data.Discovered)
		header.Text = ("Found %d/%d  •  Complete a rarity for +%d%% income (now +%d%%)"):format(found, #Dragons.List,
			math.floor(Economy.IndexBonusPerRarity * 100), math.floor(done * Economy.IndexBonusPerRarity * 100))
		for order, species in Dragons.List do
			local discovered = data.Discovered[species.Name] == true
			if shownFor[species.Name] == discovered and cards[species.Name] then
				continue
			end
			shownFor[species.Name] = discovered
			if cards[species.Name] then
				cards[species.Name]:Destroy()
			end
			local rarity = Rarities.ByName[species.Rarity]
			local c = UI.Frame(grid, UDim2.new(), nil, UI.Colors.PanelLight)
			c.LayoutOrder = order
			UI.Corner(c, 12)
			UI.Stroke(c, rarity.Color, 3)
			local view = UI.Frame(c, UDim2.new(1, -8, 0, 92), UDim2.fromOffset(4, 4))
			view.BackgroundTransparency = 1
			Preview.Make(view, species.Name, not discovered)
			UI.Label(c, if discovered then species.Name else "???", UDim2.new(1, -8, 0, 24), UDim2.fromOffset(4, 98))
			UI.Label(c, rarity.Name, UDim2.new(1, -8, 0, 18), UDim2.fromOffset(4, 120), rarity.Color)
			UI.Label(c, if discovered then Format.Gold(species.Income) .. "/s" else "", UDim2.new(1, -8, 0, 16), UDim2.fromOffset(4, 140), UI.Colors.Green)
			cards[species.Name] = c
		end
	end
	State.Changed:Connect(refresh)
	panel.OnOpen.Event:Connect(function()
		refresh(State.Data)
	end)
	HUD.Buttons.Index.Activated:Connect(panel.Toggle)
	Panels.Index = panel
end

-- ------------------------------------------------------------ shop

local function priceText(id: number, infoType: Enum.InfoType, label: TextButton)
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		if ok and info and info.PriceInRobux then
			label.Text = "R$ " .. tostring(info.PriceInRobux)
		end
	end)
end

local function buildShop()
	local panel = UI.Panel("🛒 Shop", UI.Colors.Gold, UDim2.fromScale(0.55, 0.7))
	local scroll = list(panel.Body)
	local order = 0
	local passButtons: { [string]: TextButton } = {}

	local function section(text: string)
		order += 1
		local l = UI.Label(scroll, text, UDim2.new(1, -8, 0, 32), nil, UI.Colors.Gold)
		l.LayoutOrder = order
		l.TextXAlignment = Enum.TextXAlignment.Left
	end
	local function item(info, onBuy: () -> (), infoType: Enum.InfoType): TextButton
		order += 1
		local c = card(scroll, 84, order)
		local icon = UI.Label(c, info.Icon, UDim2.fromOffset(56, 56), UDim2.fromOffset(12, 14))
		icon.TextStrokeTransparency = 1
		local t = UI.Label(c, info.Name, UDim2.new(0.6, -80, 0, 32), UDim2.fromOffset(78, 8))
		t.TextXAlignment = Enum.TextXAlignment.Left
		local d = UI.Label(c, info.Description, UDim2.new(0.66, -80, 0, 32), UDim2.fromOffset(78, 44), UI.Colors.Muted)
		d.TextXAlignment = Enum.TextXAlignment.Left
		d.TextWrapped = true
		local b = UI.Button(c, "Buy", UI.Colors.Green, UDim2.new(0.28, 0, 0, 54), UDim2.new(0.7, 0, 0, 15), onBuy)
		priceText(info.Id, infoType, b)
		return b
	end

	local anyPass, anyProduct = false, false
	for _, info in Products.GamePasses do
		anyPass = anyPass or info.Id ~= 0
	end
	for _, info in Products.Products do
		anyProduct = anyProduct or info.Id ~= 0
	end
	if anyPass then
		section("Game Passes (forever)")
		for name, info in Products.GamePasses do
			if info.Id ~= 0 then
				passButtons[name] = item(info, function()
					MarketplaceService:PromptGamePassPurchase(player, info.Id)
				end, Enum.InfoType.GamePass)
			end
		end
	end
	if anyProduct then
		section("Boosts")
		for _, info in Products.Products do
			if info.Id ~= 0 then
				item(info, function()
					MarketplaceService:PromptProductPurchase(player, info.Id)
				end, Enum.InfoType.Product)
			end
		end
	end

	-- Codes.
	section("Codes")
	order += 1
	local c = card(scroll, 74, order)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.62, -10, 0, 50)
	box.Position = UDim2.fromOffset(12, 12)
	box.BackgroundColor3 = UI.Colors.Panel
	box.Font = UI.Font
	box.PlaceholderText = "Enter code..."
	box.Text = ""
	box.TextScaled = true
	box.TextColor3 = UI.Colors.Text
	box.ClearTextOnFocus = false
	box.Parent = c
	UI.Corner(box, 10)
	UI.Stroke(box, UI.Colors.Stroke, 2)
	local redeem = UI.Button(c, "Redeem", UI.Colors.Blue, UDim2.new(0.34, 0, 0, 50), UDim2.new(0.64, 0, 0, 12))
	redeem.Activated:Connect(function()
		local ok, message = Remotes.RedeemCode:InvokeServer(box.Text)
		box.Text = ""
		box.PlaceholderText = message
		if ok then
			UI.Pop(c)
		end
	end)

	State.Changed:Connect(function(data)
		local passes = data.Passes or {}
		for name, b in passButtons do
			if passes[name] then
				b.Text = "Owned ✓"
				UI.SetButtonColor(b, Color3.fromRGB(120, 120, 130))
				b.Active = false
			end
		end
	end)
	HUD.Buttons.Shop.Activated:Connect(panel.Toggle)
	Panels.Shop = panel
end

-- ------------------------------------------------------------ fusion

local function buildFusion()
	local panel = UI.Panel("✨ Fusion Altar", Color3.fromRGB(80, 170, 230), UDim2.fromScale(0.62, 0.72))
	local info = UI.Label(panel.Body, "Pick 3 dragons of the same rarity to fuse them into 1 of the next rarity.",
		UDim2.new(1, 0, 0, 26), UDim2.new(), UI.Colors.Muted)
	local grid = UI.Grid(panel.Body, UDim2.fromOffset(118, 138), UDim2.fromOffset(0, 32), UDim2.new(1, 0, 1, -112))
	local footer = UI.Frame(panel.Body, UDim2.new(1, 0, 0, 70), UDim2.new(0, 0, 1, -72), UI.Colors.PanelLight)
	UI.Corner(footer, 14)
	local status = UI.Label(footer, "", UDim2.new(0.6, -10, 0, 30), UDim2.fromOffset(12, 6))
	status.TextXAlignment = Enum.TextXAlignment.Left
	local lucky = UI.Label(footer, "", UDim2.new(0.6, -10, 0, 24), UDim2.fromOffset(12, 40), UI.Colors.Green)
	lucky.TextXAlignment = Enum.TextXAlignment.Left
	local selected: { number } = {}
	local fuseButton: TextButton
	local lastSignature = ""

	local function selectedRarity(data): string?
		local first = selected[1]
		local slot = first and data.Slots[tostring(first)]
		return slot and Dragons.ByName[slot.Species].Rarity
	end

	local function refresh(data)
		if not panel.IsOpen() or not data then
			return
		end
		-- Drop selections that are no longer valid.
		for i = #selected, 1, -1 do
			local slot = data.Slots[tostring(selected[i])]
			if not slot or slot.HatchAt or slot.Stolen then
				table.remove(selected, i)
			end
		end
		-- Only rebuild the cards when the dragons or the selection changed.
		local parts = { table.concat(selected, ",") }
		for i = 1, data.Perches do
			local slot = data.Slots[tostring(i)]
			if slot and not slot.HatchAt and not slot.Stolen then
				table.insert(parts, i .. slot.Species .. (slot.Mutation or ""))
			end
		end
		local signature = table.concat(parts, "|")
		local rebuild = signature ~= lastSignature
		lastSignature = signature
		if rebuild then
			for _, child in grid:GetChildren() do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
		end
		local rarityPick = selectedRarity(data)
		for i = 1, if rebuild then data.Perches else 0 do
			local slot = data.Slots[tostring(i)]
			if slot and not slot.HatchAt and not slot.Stolen then
				local species = Dragons.ByName[slot.Species]
				local rarity = Rarities.ByName[species.Rarity]
				local isSelected = table.find(selected, i) ~= nil
				local usable = rarity.Name ~= "Celestial" and (rarityPick == nil or rarityPick == rarity.Name)
				local b = Instance.new("TextButton")
				b.Text = ""
				b.AutoButtonColor = false
				b.BackgroundColor3 = if isSelected then Color3.fromRGB(70, 130, 90) else UI.Colors.PanelLight
				b.BackgroundTransparency = if usable or isSelected then 0 else 0.6
				b.LayoutOrder = rarity.Order * 100 + i
				b.Parent = grid
				UI.Corner(b, 12)
				UI.Stroke(b, if isSelected then UI.Colors.Green else rarity.Color, if isSelected then 4 else 2)
				local view = UI.Frame(b, UDim2.new(1, -8, 0, 80), UDim2.fromOffset(4, 4))
				view.BackgroundTransparency = 1
				Preview.Make(view, species.Name)
				UI.Label(b, (if slot.Mutation then slot.Mutation .. " " else "") .. species.Name, UDim2.new(1, -8, 0, 22), UDim2.fromOffset(4, 86),
					if slot.Mutation then Dragons.MutationByName[slot.Mutation].Color else UI.Colors.Text)
				UI.Label(b, rarity.Name, UDim2.new(1, -8, 0, 18), UDim2.fromOffset(4, 110), rarity.Color)
				b.Activated:Connect(function()
					local at = table.find(selected, i)
					if at then
						table.remove(selected, at)
					elseif usable and #selected < Economy.FuseCount then
						table.insert(selected, i)
					end
					refresh(State.Data)
				end)
			end
		end
		local rarity = selectedRarity(data)
		local nextRarity = rarity and Rarities.Next(rarity)
		if rarity and nextRarity then
			status.Text = ("%d/3 %s  →  1 %s"):format(#selected, rarity, nextRarity.Name)
			status.TextColor3 = nextRarity.Color
		else
			status.Text = ("%d/3 selected"):format(#selected)
			status.TextColor3 = UI.Colors.Text
		end
		lucky.Text = if data.LuckyFusions > 0 then ("🍀 Lucky Fusions: %d (next one is Golden or Shadow!)"):format(data.LuckyFusions) else "Fused dragons are 2x more likely to be Golden or Shadow"
		UI.SetButtonColor(fuseButton, if #selected == Economy.FuseCount then UI.Colors.Blue else Color3.fromRGB(120, 120, 130))
	end

	fuseButton = UI.Button(footer, "FUSE!", UI.Colors.Blue, UDim2.new(0.36, 0, 0, 54), UDim2.new(0.62, 0, 0, 8), function()
		if #selected == Economy.FuseCount then
			Remotes.Fuse:FireServer(selected)
			selected = {}
		end
	end)
	info.TextXAlignment = Enum.TextXAlignment.Left

	State.Changed:Connect(refresh)
	panel.OnOpen.Event:Connect(function()
		selected = {}
		lastSignature = ""
		refresh(State.Data)
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("Kind") == "Fuse" then
			panel.Open()
		end
	end)
	Panels.Fusion = panel
end

function Panels.Start()
	buildUpgrades()
	buildRebirth()
	buildIndex()
	buildShop()
	buildFusion()
end

return Panels
