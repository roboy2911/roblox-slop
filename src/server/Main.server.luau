-- Starts every server service, in order.

local Services = script.Parent:WaitForChild("Services")
local Registry = require(Services.Registry)

local ORDER = {
	"AssetService",
	"DataService",
	"ShopService",
	"UpgradeService",
	"WorldService",
	"PlotService",
	"BaseService",
	"EggService",
	"StealService",
	"FusionService",
	"RebirthService",
	"HazardService",
	"BonkService",
	"EventService",
	"RewardService",
	"BossService",
	"SocialService",
	"SpinService",
	"QuestService",
	"LeaderboardService",
	"DevCommands",
	"AdminService",
}

-- Load them all first so they can find each other through the Registry.
for _, name in ORDER do
	local module = Services:WaitForChild(name, 10)
	if not module then
		warn("[Main] Missing service script: " .. name .. " (is Rojo connected and synced?)")
		Registry[name] = {}
		continue
	end
	local ok, result = pcall(require, module)
	if ok then
		Registry[name] = result
	else
		warn("[Main] " .. name .. " failed to load: " .. tostring(result))
		Registry[name] = {}
	end
end

print("[Dragon Egg Heist] Server starting...")

-- Each step is protected, so one failure can't leave you standing on an empty baseplate.
local function step(label: string, fn: () -> ())
	if typeof(fn) ~= "function" then
		warn("[Main] " .. label .. " skipped (service didn't load)")
		return
	end
	local ok, err = xpcall(fn, function(e)
		return tostring(e) .. "\n" .. debug.traceback()
	end)
	if not ok then
		warn(("[Main] %s failed: %s"):format(label, err))
	end
end

step("AssetService.Start", Registry.AssetService.Start)
step("AssetService.Preload", function()
	Registry.AssetService.Preload(45)
end)
step("PublishTemplates", require(Services.ModelFactory).PublishTemplates)
step("WorldService.Build", Registry.WorldService.Build)
for _, name in ORDER do
	local service = Registry[name]
	if name ~= "AssetService" and service.Start ~= nil then
		step(name .. ".Start", service.Start)
	end
end

print("[Dragon Egg Heist] Server ready")
