-- The latest snapshot of your data from the server, plus a Changed signal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local State = {}

State.Data = nil :: any
local changed = Instance.new("BindableEvent")
State.Changed = changed.Event

function State.Start()
	Remotes.State.OnClientEvent:Connect(function(snapshot)
		State.Data = snapshot
		changed:Fire(snapshot)
	end)
end

-- Calls `callback(data)` now (if loaded) and whenever data changes.
function State.Watch(callback: (any) -> ())
	if State.Data then
		task.spawn(callback, State.Data)
	end
	return State.Changed:Connect(callback)
end

return State
