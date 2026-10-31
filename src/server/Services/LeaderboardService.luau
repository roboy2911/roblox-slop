-- Player list stats (Gold, Rebirths) and the stone leaderboards in the meadow
-- (all-time bests, saved with OrderedDataStores).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local ModelFactory = require(script.Parent.ModelFactory)
local Registry = require(script.Parent.Registry)

local LeaderboardService = {}

local REFRESH = 120

type Board = {
	Title: string,
	Store: string,
	Position: Vector3,
	Color: Color3,
	Value: (data: any) -> number,
	Show: (value: number) -> string,
	Ordered: OrderedDataStore?,
	Rows: { TextLabel },
}

local boards: { Board } = {
	{
		Title = "🏆 Top Dragon Keepers",
		Store = "DragonEggHeist_TopEarned_v1",
		Position = Vector3.new(-20, 0, 24),
		Color = Color3.fromRGB(255, 210, 70),
		Value = function(data)
			return math.floor(data.TotalEarned)
		end,
		Show = function(v)
			return Format.Gold(v)
		end,
		Rows = {},
	},
	{
		Title = "♻️ Most Rebirths",
		Store = "DragonEggHeist_TopRebirths_v1",
		Position = Vector3.new(20, 0, 24),
		Color = Color3.fromRGB(200, 140, 255),
		Value = function(data)
			return data.Rebirths
		end,
		Show = function(v)
			return "Rebirth " .. v
		end,
		Rows = {},
	},
}

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
	local gold = stats:FindFirstChild("Gold") :: StringValue
	gold.Value = Format.Gold(data.Gold)
	local rebirths = stats:FindFirstChild("Rebirths") :: IntValue
	rebirths.Value = data.Rebirths
end

local function buildBoard(board: Board)
	local model = ModelFactory.Place("Tablet", board.Position, Vector3.new(0, 0, -1), 16, workspace:WaitForChild("World"))
	ModelFactory.Collider(Vector3.new(15, 16, 3), CFrame.new(board.Position + Vector3.new(0, 8, 0)), model)
	local anchor = Instance.new("Part")
	anchor.Name = "Screen"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(12, 13, 0.2)
	-- Facing the castles (-Z), just in front of the stone.
	anchor.CFrame = CFrame.lookAt(board.Position + Vector3.new(0, 9, -1.2), board.Position + Vector3.new(0, 9, -10))
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
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 52)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = board.Color
	title.TextStrokeTransparency = 0.2
	title.Text = board.Title
	title.LayoutOrder = 0
	title.Parent = gui
	for i = 1, 10 do
		local row = title:Clone()
		row.Size = UDim2.new(1, -20, 0, 30)
		row.TextColor3 = if i == 1 then board.Color elseif i <= 3 then Color3.fromRGB(230, 230, 240) else Color3.fromRGB(255, 255, 255)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = ""
		row.LayoutOrder = i
		row.Parent = gui
		board.Rows[i] = row
	end
end

local names: { [number]: string } = {}

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok then
		names[userId] = name
		return name
	end
	return "???"
end

local function refreshBoard(board: Board)
	local store = board.Ordered
	if not store then
		return
	end
	for _, player in Players:GetPlayers() do
		local data = Registry.DataService.Get(player)
		local v = data and board.Value(data)
		if v and v > 0 then
			pcall(function()
				store:SetAsync("u_" .. player.UserId, v)
			end)
		end
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, 10)
	end)
	if not ok then
		return
	end
	local entries = pages:GetCurrentPage()
	for i = 1, 10 do
		local entry = entries[i]
		if entry then
			local userId = tonumber((entry.key :: string):sub(3)) or 0
			board.Rows[i].Text = ("%d. %s — %s"):format(i, nameOf(userId), board.Show(entry.value))
		else
			board.Rows[i].Text = ""
		end
	end
end

function LeaderboardService.Start()
	Players.PlayerAdded:Connect(setupStats)
	for _, player in Players:GetPlayers() do
		setupStats(player)
	end
	for _, board in boards do
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore(board.Store)
		end)
		if ok then
			board.Ordered = result
		end
		buildBoard(board)
	end
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
			for _, board in boards do
				refreshBoard(board)
			end
			task.wait(REFRESH)
		end
	end)
end

return LeaderboardService
