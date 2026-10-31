-- Robux purchases (game passes and developer products) and codes.
-- IDs live in Config/Products.luau; anything with ID 0 is turned off.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codes = require(ReplicatedStorage.Shared.Config.Codes)
local Format = require(ReplicatedStorage.Shared.Format)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)

local ShopService = {}

local owned: { [Player]: { [string]: boolean } } = {}

local function refreshPasses(player: Player)
	local passes = owned[player] or {}
	owned[player] = passes
	for name, info in Products.GamePasses do
		if info.Id ~= 0 and not passes[name] then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, info.Id)
			end)
			passes[name] = ok and has or false
		end
	end
	Registry.DataService.SetExtra(player, "Passes", passes)
	Registry.UpgradeService.ApplySpeed(player)
end

function ShopService.HasPass(player: Player, name: string): boolean
	local passes = owned[player]
	return passes ~= nil and passes[name] == true
end

-- ------------------------------------------------------------ products

local handlers: { [string]: (Player) -> boolean } = {
	GoldSmall = function(player)
		local income = Registry.BaseService.IncomePerSecond(player)
		local amount = math.max(Products.GoldSmallMin, income * Products.GoldSmallSeconds)
		Registry.DataService.AddGold(player, amount)
		Remotes.Notify:FireClient(player, "Thanks! +" .. Format.Gold(amount), "Good")
		return true
	end,
	GoldLarge = function(player)
		local income = Registry.BaseService.IncomePerSecond(player)
		local amount = math.max(Products.GoldLargeMin, income * Products.GoldLargeSeconds)
		Registry.DataService.AddGold(player, amount)
		Remotes.Notify:FireClient(player, "Thanks! +" .. Format.Gold(amount), "Good")
		return true
	end,
	InstantHatch = function(player)
		Registry.BaseService.HatchAll(player)
		return true
	end,
	LuckyFusion = function(player)
		local data = Registry.DataService.Get(player)
		data.LuckyFusions += 1
		Registry.DataService.Changed(player)
		Remotes.Notify:FireClient(player, "Lucky Fusion ready! Your next fusion will be Golden or Shadow.", "Good")
		return true
	end,
	CalmDragon = function(player)
		Registry.HazardService.Calm(player)
		return true
	end,
}

local productById: { [number]: string } = {}
for name, info in Products.Products do
	if info.Id ~= 0 then
		productById[info.Id] = name
	end
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = Registry.DataService.Wait(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local name = productById[receipt.ProductId]
	if not name then
		warn("[ShopService] Unknown product " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Already granted (e.g. Roblox retried)? Then it's done.
	if not Registry.DataService.RecordReceipt(player, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local ok, granted = pcall(handlers[name], player)
	if not ok or not granted then
		warn("[ShopService] Failed to grant " .. name .. ": " .. tostring(granted))
		-- Forget the receipt so Roblox can retry it.
		for i, id in data.Receipts do
			if id == receipt.PurchaseId then
				table.remove(data.Receipts, i)
				break
			end
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Save right away so the purchase isn't lost if the server crashes.
	task.spawn(Registry.DataService.SaveNow, player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ------------------------------------------------------------ codes

local function redeem(player: Player, code: any): (boolean, string)
	if typeof(code) ~= "string" or #code > 40 then
		return false, "That's not a code."
	end
	local data = Registry.DataService.Get(player)
	if not data then
		return false, "Still loading, try again."
	end
	code = (code:upper():gsub("%s", ""))
	local reward = Codes[code]
	if not reward then
		return false, "That code doesn't exist."
	end
	if data.Codes[code] then
		return false, "You already used that code."
	end
	data.Codes[code] = true
	local parts = {}
	if reward.Gold then
		Registry.DataService.AddGold(player, reward.Gold)
		table.insert(parts, "$" .. reward.Gold)
	end
	if reward.LuckyFusion then
		data.LuckyFusions += reward.LuckyFusion
		table.insert(parts, reward.LuckyFusion .. " Lucky Fusion")
	end
	Registry.DataService.Changed(player)
	return true, "Redeemed! You got " .. table.concat(parts, " + ")
end

function ShopService.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			for name, info in Products.GamePasses do
				if info.Id == passId then
					owned[player] = owned[player] or {}
					owned[player][name] = true
					Remotes.Notify:FireClient(player, "Thanks for buying " .. info.Name .. "!", "Good")
				end
			end
			refreshPasses(player)
		end
	end)
	Registry.DataService.OnLoaded(function(player)
		refreshPasses(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
	Remotes.RedeemCode.OnServerInvoke = function(player, code)
		return redeem(player, code)
	end
end

return ShopService
