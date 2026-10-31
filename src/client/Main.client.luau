-- Starts every client controller.

local Controllers = script.Parent:WaitForChild("Controllers")

local ORDER = {
	"SoundFx",
	"State",
	"HUD",
	"Notifications",
	"Panels",
	"AdminPanel",
	"WorldFx",
	"Pets",
	"HazardFx",
	"Tutorial",
	"LikePrompt",
}

-- In order (Panels needs the HUD's buttons). The tutorial waits for data, so it runs on its own.
for _, name in ORDER do
	local controller = require(Controllers:WaitForChild(name))
	local function start()
		local ok, err = pcall(controller.Start)
		if not ok then
			warn(("[Client] %s failed to start: %s"):format(name, tostring(err)))
		end
	end
	if name == "Tutorial" then
		task.spawn(start)
	else
		start()
	end
end
