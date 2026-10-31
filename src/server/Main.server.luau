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
	"LeaderboardService",
	"DevCommands",
}

-- Load them all first so they can find each other through the Registry.
for _, name in ORDER do
	Registry[name] = require(Services:WaitForChild(name))
end

Registry.AssetService.Start()
require(Services.ModelFactory).PublishTemplates()
Registry.WorldService.Build()
for _, name in ORDER do
	local service = Registry[name]
	if name ~= "AssetService" and service.Start then
		local ok, err = pcall(service.Start)
		if not ok then
			warn(("[Main] %s failed to start: %s"):format(name, tostring(err)))
		end
	end
end

print("[Dragon Egg Heist] Server ready")
