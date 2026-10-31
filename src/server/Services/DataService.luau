-- Loads and saves player data with DataStores.
--
-- Each player's data is locked to one server while they play (so two servers
-- can't overwrite each other). Saves every 90 seconds, when they leave, and
-- when the server shuts down.
--
-- Other services change data with DataService.Get(player) and then call
-- DataService.Changed(player); the client gets a fresh snapshot shortly after.
-- Services can add live (unsaved) info to the snapshot with SetExtra.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService = {}

local STORE_NAME = "DragonEggHeist_v1"
local AUTOSAVE = 90
local LOCK_EXPIRES = 120

export type Slot = { Species: string, Mutation: string?, HatchAt: number?, Stolen: boolean? }

type Profile = {
	Data: any,
	NoSave: boolean,
	Extra: { [string]: any },
	Dirty: boolean,
	Leaving: boolean?,
}

local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (Player, any) -> () } = {}
local leavingCallbacks: { (Player, any) -> () } = {}

local function defaults()
	return {
		Version = 1,
		Gold = Economy.StartingGold,
		Pending = 0,
		TotalEarned = 0,
		Rebirths = 0,
		SpeedLevel = 0,
		CarryLevel = 0,
		Perches = Economy.StartingPerches,
		Slots = {}, -- ["1"] = { Species, Mutation, HatchAt }
		Discovered = {}, -- [species] = true
		LuckyFusions = 0,
		Codes = {},
		Receipts = {}, -- recent purchase IDs, so a purchase is never granted twice
		Tutorial = false,
		LastSeen = 0,
		Starter = false,
		Daily = { Last = 0, Streak = 0 },
		Spins = 1, -- one free spin to start
		Quests = { Day = 0, List = {}, Progress = {}, Claimed = {} }, -- day number (UTC) of the last daily claim
	}
end

local function reconcile(data)
	for key, value in defaults() do
		if data[key] == nil then
			data[key] = value
		end
	end
	return data
end

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function load(player: Player): (any, boolean)
	if not store then
		return defaults(), true
	end
	local force = false
	for attempt = 1, 6 do
		local locked = false
		local ok, result = pcall(function()
			return (store :: DataStore):UpdateAsync(key(player), function(old)
				old = old or defaults()
				local lock = old.Lock
				if not force and lock and lock.Job ~= game.JobId and os.time() - lock.Time < LOCK_EXPIRES then
					locked = true
					return nil
				end
				old.Lock = { Job = game.JobId, Time = os.time() }
				return old
			end)
		end)
		if ok and not locked and result then
			return reconcile(result), false
		end
		if not player.Parent then
			return nil, true
		end
		if locked then
			-- Another server still has it (they probably just switched servers).
			if attempt >= 4 then
				force = true
			end
			task.wait(4)
		else
			warn(("[DataService] Load attempt %d for %s failed: %s"):format(attempt, player.Name, tostring(result)))
			task.wait(2)
		end
	end
	return defaults(), true
end

local function save(player: Player, release: boolean)
	local profile = profiles[player]
	if not profile or profile.NoSave or not store then
		return
	end
	local data = profile.Data
	data.LastSeen = os.time()
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(player), function(old)
			if old and old.Lock and old.Lock.Job ~= game.JobId then
				-- Another server took over; don't overwrite its newer data.
				return nil
			end
			data.Lock = if release then nil else { Job = game.JobId, Time = os.time() }
			return data
		end)
	end)
	if not ok then
		warn("[DataService] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

-- ------------------------------------------------------------ API

function DataService.Get(player: Player): any?
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Waits until a player's data is loaded (or they leave). Returns the data or nil.
function DataService.Wait(player: Player): any?
	while player.Parent and not profiles[player] do
		task.wait(0.1)
	end
	return DataService.Get(player)
end

function DataService.Changed(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Dirty = true
	end
end

-- Live info shown on the client but not saved (lock timer, carried eggs...).
function DataService.SetExtra(player: Player, name: string, value: any)
	local profile = profiles[player]
	if profile then
		profile.Extra[name] = value
		profile.Dirty = true
	end
end

function DataService.GetExtra(player: Player, name: string): any
	local profile = profiles[player]
	return profile and profile.Extra[name]
end

-- Called once a player's data is ready.
function DataService.OnLoaded(callback: (Player, any) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
end

-- Called just before a player's data is saved for the last time.
function DataService.OnLeaving(callback: (Player, any) -> ())
	table.insert(leavingCallbacks, callback)
end

function DataService.AddGold(player: Player, amount: number)
	local data = DataService.Get(player)
	if data then
		data.Gold += amount
		if amount > 0 then
			data.TotalEarned += amount
		end
		DataService.Changed(player)
	end
end

function DataService.SpendGold(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if not data or data.Gold < amount then
		return false
	end
	data.Gold -= amount
	DataService.Changed(player)
	return true
end

-- Remembers a purchase so it's never granted twice. False if already granted.
function DataService.RecordReceipt(player: Player, purchaseId: string): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	for _, id in data.Receipts do
		if id == purchaseId then
			return false
		end
	end
	table.insert(data.Receipts, purchaseId)
	while #data.Receipts > 50 do
		table.remove(data.Receipts, 1)
	end
	return true
end

-- Wipes a player's data (Studio testing) and kicks them so they rejoin fresh.
function DataService.Reset(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Data = defaults()
	save(player, true)
	profile.NoSave = true -- nothing else gets written before they leave
	player:Kick("Data reset. Rejoin to start fresh.")
end

function DataService.SaveNow(player: Player)
	save(player, false)
end

-- ------------------------------------------------------------ lifecycle

local function snapshot(profile: Profile)
	local data = profile.Data
	local snap = {
		Gold = data.Gold,
		Pending = data.Pending,
		TotalEarned = data.TotalEarned,
		Rebirths = data.Rebirths,
		SpeedLevel = data.SpeedLevel,
		CarryLevel = data.CarryLevel,
		Perches = data.Perches,
		Slots = data.Slots,
		Discovered = data.Discovered,
		LuckyFusions = data.LuckyFusions,
		Spins = data.Spins,
		Quests = data.Quests,
		Tutorial = data.Tutorial,
		NoSave = profile.NoSave,
	}
	for name, value in profile.Extra do
		snap[name] = value
	end
	return snap
end

local function playerAdded(player: Player)
	local data, noSave = load(player)
	if not data or not player.Parent then
		return
	end
	profiles[player] = { Data = data, NoSave = noSave, Extra = {}, Dirty = true }
	if noSave then
		task.delay(3, function()
			if player.Parent then
				Remotes.Notify:FireClient(player, "Progress is not saving this session (Studio API access is off?).", "Error")
			end
		end)
	end
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

local function playerRemoving(player: Player)
	local profile = profiles[player]
	if not profile or profile.Leaving then
		return
	end
	-- PlayerRemoving and BindToClose can both get here; only save once.
	profile.Leaving = true
	for _, callback in leavingCallbacks do
		local ok, err = pcall(callback, player, profile.Data)
		if not ok then
			warn("[DataService] Leaving callback failed: " .. tostring(err))
		end
	end
	save(player, true)
	profiles[player] = nil
end

function DataService.Start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable: " .. tostring(result))
	end

	Players.PlayerAdded:Connect(playerAdded)
	Players.PlayerRemoving:Connect(playerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(playerAdded, player)
	end

	-- Send changed snapshots to clients a few times a second.
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.15 then
			return
		end
		acc = 0
		for player, profile in profiles do
			if profile.Dirty then
				profile.Dirty = false
				Remotes.State:FireClient(player, snapshot(profile))
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for player in profiles do
				task.spawn(save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				playerRemoving(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
