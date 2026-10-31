-- All RemoteEvents and RemoteFunctions, in ReplicatedStorage.Remotes.
-- The server creates them; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	-- server -> client
	"State", -- (snapshot) your saved data and stats
	"Notify", -- (text, kind?, sound?) a small toast
	"Announce", -- (text, color?, sound?) a big banner for everyone
	"Knockback", -- (velocity) you got bonked
	"NewDragon", -- (species, mutation, isNew) an egg hatched / a fusion finished
	"Collected", -- (amount) you picked up gold from your chest
	-- client -> server
	"BuyUpgrade", -- (kind) "Speed" | "Carry" | "Perch"
	"Rebirth", -- ()
	"Fuse", -- ({slot, slot, slot})
	"TutorialDone", -- ()
	"ClaimDaily", -- ()
	"ClaimGift", -- (index)
	"ClaimQuest", -- (quest id)
}

local FUNCTIONS = {
	"RedeemCode", -- (code) -> (ok, message)
	"Spin", -- () -> (prize index or nil, message)
	"Admin", -- (action, args) -> (ok, message)   admins only
}

local Remotes = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		local e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = folder
		Remotes[name] = e
	end
	for _, name in FUNCTIONS do
		local f = Instance.new("RemoteFunction")
		f.Name = name
		f.Parent = folder
		Remotes[name] = f
	end
	folder.Parent = ReplicatedStorage
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in EVENTS do
		Remotes[name] = folder:WaitForChild(name)
	end
	for _, name in FUNCTIONS do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
