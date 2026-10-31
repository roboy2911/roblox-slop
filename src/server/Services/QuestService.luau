-- Daily quests: 3 per player per day (UTC), from Config/Quests.luau.
-- Other services report progress with QuestService.Add(player, stat, amount).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Quests = require(ReplicatedStorage.Shared.Config.Quests)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)

local QuestService = {}

local byId = {}
for _, q in Quests.List do
	byId[q.Id] = q
end

local function today(): number
	return math.floor(os.time() / 86400)
end

-- Makes sure the player has today's quests (new ones each day).
local function refresh(player: Player, data)
	local quests = data.Quests
	if quests.Day == today() and #quests.List > 0 then
		return
	end
	local rng = Random.new(today() * 7919 + player.UserId)
	local pool = table.clone(Quests.List)
	local picked = {}
	for _ = 1, math.min(Quests.PerDay, #pool) do
		local q = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(picked, q.Id)
	end
	data.Quests = { Day = today(), List = picked, Progress = {}, Claimed = {} }
	Registry.DataService.Changed(player)
end

function QuestService.Add(player: Player, stat: string, amount: number?)
	local data = Registry.DataService.Get(player)
	if not data or not data.Quests then
		return
	end
	refresh(player, data)
	local quests = data.Quests
	for _, id in quests.List do
		local q = byId[id]
		if q and q.Stat == stat and not quests.Claimed[id] then
			local before = quests.Progress[id] or 0
			if before < q.Goal then
				local after = math.min(q.Goal, before + (amount or 1))
				quests.Progress[id] = after
				Registry.DataService.Changed(player)
				if after >= q.Goal then
					Remotes.Notify:FireClient(player, "📜 Quest done: " .. q.Text:format(q.Goal) .. "! Claim it in Quests.", "Good", "Upgrade")
				end
			end
		end
	end
end

local function claim(player: Player, id: any)
	local data = Registry.DataService.Get(player)
	if not data or typeof(id) ~= "string" then
		return
	end
	refresh(player, data)
	local quests = data.Quests
	local q = byId[id]
	if not q or not table.find(quests.List, id) or quests.Claimed[id] or (quests.Progress[id] or 0) < q.Goal then
		return
	end
	quests.Claimed[id] = true
	local got = Registry.RewardService.Grant(player, q.Reward)
	Registry.DataService.Changed(player)
	Remotes.Notify:FireClient(player, "Quest reward: " .. got, "Good", "Sell")
end

function QuestService.Start()
	Remotes.ClaimQuest.OnServerEvent:Connect(claim)
	Registry.DataService.OnLoaded(function(player, data)
		data.Quests = data.Quests or { Day = 0, List = {}, Progress = {}, Claimed = {} }
		refresh(player, data)
	end)
	-- "Play for N minutes", and a new set of quests at midnight UTC.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				QuestService.Add(player, "Minutes", 1)
			end
		end
	end)
end

return QuestService
