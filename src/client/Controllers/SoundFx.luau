-- Plays sound effects (see Config/Sounds.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local SoundFx = {}

local cache: { [string]: Sound } = {}

local function template(name: string): Sound?
	local id = Sounds.Ids[name]
	if not id or id == "" then
		return nil
	end
	local s = cache[name]
	if not s then
		s = Instance.new("Sound")
		s.Name = "Sfx" .. name
		s.SoundId = id
		s.Volume = Sounds.Volumes[name] or 0.5
		s.Parent = SoundService
		cache[name] = s
	end
	return s
end

-- Plays a sound once. `volume` multiplies the default volume.
function SoundFx.Play(name: string, volume: number?, pitch: number?)
	local base = template(name)
	if not base then
		return
	end
	local s = base:Clone()
	s.Volume = base.Volume * (volume or 1)
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(12, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- A looping 3D sound attached to a part (louder when you're close).
function SoundFx.Attach(name: string, part: Instance, range: number): Sound?
	local base = template(name)
	if not base then
		return nil
	end
	local s = base:Clone()
	s.Looped = true
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 10
	s.RollOffMaxDistance = range
	s.Parent = part
	return s
end

-- Preload everything so the first play isn't silent.
function SoundFx.Start()
	local list = {}
	for name in Sounds.Ids do
		local s = template(name)
		if s then
			table.insert(list, s)
		end
	end
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(list)
		end)
	end)
end

return SoundFx
