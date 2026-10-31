-- Player list stats (Gold, Rebirths) and the stone leaderboard in the meadow
-- (all-time top earners, saved with an OrderedDataStore).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local ModelFactory = require(script.Parent.ModelFactory)
local Registry = require(script.Parent.Registry)

local LeaderboardService = {}

local REFRESH = 120
local BOARD_POSITION = Vector3.new(0, 0, 24)

local ordered: OrderedDataStore? = nil
local rows: { TextLabel } = {}

local function setupStats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local gold = Instance.new("StringValue")
	gold.Name = "Gold"
	gold.Value = "$0"
	gold.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = stats
	stats.Parent = player
end

function LeaderboardService.Update(player: Player)
	local data = Registry.DataService.Get(player)
	local stats = player:FindFirstChild("leaderstats")
	if not data or not stats then
		return
	end
	(stats:FindFirstChild("Gold") :: StringValue).Value = Format.Gold(data.Gold);
	(stats:FindFirstChild("Rebirths") :: IntValue).Value = data.Rebirths
end

local function buildBoard()
	local model = ModelFactory.Place("Tablet", BOARD_POSITION, Vector3.new(0, 0, -1), 16, workspace:WaitForChild("World"))
	ModelFactory.Collider(Vector3.new(15, 16, 3), CFrame.new(BOARD_POSITION + Vector3.new(0, 8, 0)), model)
	local anchor = Instance.new("Part")
	anchor.Name = "Screen"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(12, 13, 0.2)
	-- Facing the castles (-Z), just in front of the stone.
	anchor.CFrame = CFrame.lookAt(BOARD_POSITION + Vector3.new(0, 9, -1.2), BOARD_POSITION + Vector3.new(0, 9, -10))
	anchor.Parent = model

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.1
	gui.Parent = anchor
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 52)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 210, 70)
	title.TextStrokeTransparency = 0.2
	title.Text = "🏆 Top Dragon Keepers"
	title.Parent = gui
	for i = 1, 10 do
		local row = title:Clone()
		row.Size = UDim2.new(1, -20, 0, 30)
		row.TextColor3 = if i == 1 then Color3.fromRGB(255, 215, 80) elseif i <= 3 then Color3.fromRGB(230, 230, 240) else Color3.fromRGB(255, 255, 255)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = ""
		row.LayoutOrder = i
		row.Parent = gui
		rows[i] = row
	end
end

local function refreshBoard()
	if not ordered then
		return
	end
	for _, player in Players:GetPlayers() do
		local data = Registry.DataService.Get(player)
		if data and data.TotalEarned > 0 then
			pcall(function()
				(ordered :: OrderedDataStore):SetAsync("u_" .. player.UserId, math.floor(data.TotalEarned))
			end)
		end
	end
	local ok, pages = pcall(function()
		return (ordered :: OrderedDataStore):GetSortedAsync(false, 10)
	end)
	if not ok then
		return
	end
	local entries = pages:GetCurrentPage()
	for i = 1, 10 do
		local entry = entries[i]
		if entry then
			local userId = tonumber((entry.key :: string):sub(3)) or 0
			local nameOk, name = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			rows[i].Text = ("%d. %s — %s"):format(i, if nameOk then name else "???", Format.Gold(entry.value))
		else
			rows[i].Text = ""
		end
	end
end

function LeaderboardService.Start()
	Players.PlayerAdded:Connect(setupStats)
	for _, player in Players:GetPlayers() do
		setupStats(player)
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore("DragonEggHeist_TopEarned_v1")
	end)
	if ok then
		ordered = result
	end
	buildBoard()
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				LeaderboardService.Update(player)
			end
			task.wait(1)
		end
	end)
	task.spawn(function()
		task.wait(10)
		while true do
			refreshBoard()
			task.wait(REFRESH)
		end
	end)
end

return LeaderboardService
