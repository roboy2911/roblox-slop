-- Sound effects. They're made by tools/sounds.py and uploaded by
-- tools/build_assets.py, which puts their IDs in Assets.luau.
-- To use a different sound, put its ID in Overrides (e.g. Collect = "rbxassetid://123").

local Assets = require(script.Parent.Assets)

local Overrides: { [string]: string } = {}

-- How loud each sound plays (0-1).
local Volumes = {
	Collect = 0.5, Hatch = 0.6, NewDragon = 0.6, Grab = 0.5, Place = 0.5, Bonk = 0.7, Swing = 0.35,
	Roar = 0.9, Fire = 0.8, Warning = 0.45, Click = 0.3, Error = 0.25, Announce = 0.45, Upgrade = 0.4,
	Rebirth = 0.6, Alarm = 0.35, Sneak = 0.5, Lock = 0.55, Sell = 0.5, Star = 0.6, Burned = 0.6,
}

local ids: { [string]: string } = {}
for name, id in (Assets :: any).Sounds or {} do
	if id ~= 0 then
		ids[name] = "rbxassetid://" .. id
	end
end
for name, id in Overrides do
	ids[name] = id
end

return { Ids = ids, Volumes = Volumes }
