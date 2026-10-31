-- Admin actions for the F4 panel. Only user IDs in Config/Admins.luau can use
-- them; every request is checked here, so the client panel can't be faked.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Admins = require(ReplicatedStorage.Shared.Config.Admins)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Layout = require(ReplicatedStorage.Shared.Config.Layout)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)

local AdminService = {}

function AdminService.IsAdmin(player: Player): boolean
	return table.find(Admins, player.UserId) ~= nil
end

local function target(args): Player?
	local id = typeof(args) == "table" and tonumber(args.Target)
	return id and Players:GetPlayerByUserId(id) or nil
end

local function number(value: any, default: number, min: number, max: number): number
	local n = tonumber(value) or default
	return math.clamp(math.floor(n), min, max)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Each action returns (ok, message).
local actions: { [string]: (admin: Player, args: any) -> (boolean, string) } = {
	Gold = function(_admin, args)
		local p = target(args)
		if not p then
			return false, "Pick a player."
		end
		local amount = number(args.Amount, 100000, -1e15, 1e15)
		Registry.DataService.AddGold(p, amount)
		return true, ("Gave %s to %s"):format(Format.Gold(amount), p.DisplayName)
	end,
	Dragon = function(_admin, args)
		local p = target(args)
		local species = Dragons.ByName[tostring(args.Species)]
		if not p or not species then
			return false, "Pick a player and a dragon."
		end
		local mutation = if Dragons.MutationByName[tostring(args.Mutation)] then tostring(args.Mutation) else nil
		local hatchAt = if args.Egg then os.time() + Rarities.ByName[species.Rarity].HatchTime else nil
		local slot = Registry.BaseService.AddToFreeSlot(p, { Species = species.Name, Mutation = mutation, HatchAt = hatchAt })
		if not slot then
			return false, p.DisplayName .. " has no free perch."
		end
		return true, ("Gave %s%s %s to %s"):format(if mutation then mutation .. " " else "", species.Name, if args.Egg then "egg" else "", p.DisplayName)
	end,
	Spins = function(_admin, args)
		local p = target(args)
		local data = p and Registry.DataService.Get(p)
		if not p or not data then
			return false, "Pick a player."
		end
		local n = number(args.Amount, 5, -1000, 1000)
		data.Spins = math.max(0, data.Spins + n)
		Registry.DataService.Changed(p)
		return true, ("%s now has %d spins"):format(p.DisplayName, data.Spins)
	end,
	Lucky = function(_admin, args)
		local p = target(args)
		local data = p and Registry.DataService.Get(p)
		if not p or not data then
			return false, "Pick a player."
		end
		data.LuckyFusions += number(args.Amount, 1, 0, 100)
		Registry.DataService.Changed(p)
		return true, ("%s now has %d Lucky Fusions"):format(p.DisplayName, data.LuckyFusions)
	end,
	SetRebirths = function(_admin, args)
		local p = target(args)
		local data = p and Registry.DataService.Get(p)
		if not p or not data then
			return false, "Pick a player."
		end
		data.Rebirths = number(args.Amount, data.Rebirths + 1, 0, 100)
		Registry.DataService.Changed(p)
		Registry.UpgradeService.ApplySpeed(p)
		Registry.BaseService.RefreshLabels(p)
		Registry.LeaderboardService.Update(p)
		return true, ("%s is now Rebirth %d"):format(p.DisplayName, data.Rebirths)
	end,
	MaxUpgrades = function(_admin, args)
		local p = target(args)
		local data = p and Registry.DataService.Get(p)
		if not p or not data then
			return false, "Pick a player."
		end
		data.SpeedLevel = Economy.MaxSpeedLevel
		data.CarryLevel = #Economy.CarryCosts
		data.Perches = Economy.MaxPerches
		Registry.DataService.Changed(p)
		Registry.BaseService.AddPerch(p)
		Registry.BaseService.RefreshLabels(p)
		Registry.UpgradeService.ApplySpeed(p)
		Registry.DataService.SetExtra(p, "Capacity", Registry.EggService.Capacity(p))
		return true, "Maxed upgrades for " .. p.DisplayName
	end,
	HatchAll = function(_admin, args)
		local p = target(args)
		if not p then
			return false, "Pick a player."
		end
		Registry.BaseService.HatchAll(p)
		return true, "Hatched all eggs for " .. p.DisplayName
	end,
	Wave = function()
		Registry.HazardService.TriggerNow()
		return true, "Fire wave in a few seconds"
	end,
	Calm = function(admin)
		Registry.HazardService.Calm(admin)
		return true, "Calmed the dragon"
	end,
	Boss = function()
		if Registry.BossService.IsActive() then
			return false, "The Elder Dragon is already here."
		end
		Registry.BossService.Land()
		return true, "The Elder Dragon is landing"
	end,
	Star = function()
		Registry.EventService.StarShower()
		return true, "Star Shower started"
	end,
	Announce = function(admin, args)
		local text = tostring(args.Text or "")
		if #text == 0 or #text > 200 then
			return false, "Type a message (up to 200 characters)."
		end
		-- Roblox requires filtering text that other players will see.
		local ok, filtered = pcall(function()
			local result = TextService:FilterStringAsync(text, admin.UserId)
			return result:GetNonChatStringForBroadcastAsync()
		end)
		if not ok then
			return false, "Couldn't filter that message, try again."
		end
		Remotes.Announce:FireAllClients("📢 " .. filtered, Color3.fromRGB(255, 220, 90))
		return true, "Announced"
	end,
	GoTo = function(admin, args)
		local p = target(args)
		local from, to = rootOf(admin), p and rootOf(p)
		if not from or not to then
			return false, "Pick a player who has spawned."
		end
		local character = admin.Character :: Model
		character:PivotTo(to.CFrame * CFrame.new(0, 0, 4))
		return true, "Teleported to " .. (p :: Player).DisplayName
	end,
	Bring = function(admin, args)
		local p = target(args)
		local from, to = rootOf(admin), p and rootOf(p)
		if not from or not to or not p then
			return false, "Pick a player who has spawned."
		end
		local character = p.Character :: Model
		character:PivotTo(from.CFrame * CFrame.new(0, 0, -4))
		return true, "Brought " .. p.DisplayName
	end,
	Zone = function(admin, args)
		local i = number(args.Zone, 1, 0, #Zones.List)
		local root = rootOf(admin)
		if not root then
			return false, "Spawn first."
		end
		local pos
		if i == 0 then
			local plot = Registry.PlotService.Get(admin)
			pos = (if plot then plot.Center else Layout.PlotCenter(1)) + Vector3.new(0, 4, 20)
		else
			pos = Vector3.new(0, 6, Zones.List[i].StartZ + 12)
		end
		local character = admin.Character :: Model
		character:PivotTo(CFrame.new(pos))
		return true, if i == 0 then "Teleported home" else "Teleported to " .. Zones.List[i].Name
	end,
	Kick = function(_admin, args)
		local p = target(args)
		if not p then
			return false, "Pick a player."
		end
		if AdminService.IsAdmin(p) then
			return false, "Can't kick an admin."
		end
		p:Kick("Kicked by an admin." .. (if args.Text and #tostring(args.Text) > 0 then " Reason: " .. tostring(args.Text):sub(1, 100) else ""))
		return true, "Kicked " .. p.DisplayName
	end,
	ResetData = function(_admin, args)
		local p = target(args)
		if not p then
			return false, "Pick a player."
		end
		local name = p.DisplayName
		Registry.DataService.Reset(p)
		return true, "Wiped " .. name .. "'s data (they were kicked)"
	end,
}

local function handle(admin: Player, action: any, args: any): (boolean, string)
	if not AdminService.IsAdmin(admin) then
		warn(("[AdminService] %s (%d) tried to use admin action %s"):format(admin.Name, admin.UserId, tostring(action)))
		return false, "Not allowed."
	end
	local fn = typeof(action) == "string" and actions[action]
	if not fn then
		return false, "Unknown action."
	end
	local ok, success, message = pcall(fn, admin, if typeof(args) == "table" then args else {})
	if not ok then
		warn("[AdminService] " .. tostring(action) .. " failed: " .. tostring(success))
		return false, "That failed: " .. tostring(success)
	end
	print(("[AdminService] %s: %s -> %s"):format(admin.Name, action, message))
	return success, message
end

function AdminService.Start()
	Remotes.Admin.OnServerInvoke = handle
end

return AdminService
