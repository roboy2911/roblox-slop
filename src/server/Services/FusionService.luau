-- The Fusion Altar: three dragons of one rarity become one dragon of the
-- next rarity (three Mythics make a Celestial). Fused dragons are more likely
-- to be Golden or Shadow, and a Lucky Fusion charge guarantees one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)

local FusionService = {}

local rng = Random.new()

local function fuse(player: Player, picked: any)
	local data = Registry.DataService.Get(player)
	if not data or typeof(picked) ~= "table" then
		return
	end
	-- Only trust the first three entries of what the client sent.
	local slots = {}
	for n = 1, Economy.FuseCount do
		if typeof(picked[n]) ~= "number" then
			return
		end
		slots[n] = picked[n]
	end
	if not Registry.PlotService.IsHome(player) then
		return Remotes.Notify:FireClient(player, "Fuse at the altar in your castle.", "Error")
	end

	-- Check: different slots, all hatched dragons of the same rarity.
	local seen = {}
	local rarity: string? = nil
	for _, i in slots do
		if typeof(i) ~= "number" or seen[i] or i < 1 or i > data.Perches then
			return
		end
		seen[i] = true
		local slot = data.Slots[tostring(i)]
		if not slot or slot.HatchAt or slot.Stolen then
			return Remotes.Notify:FireClient(player, "Only hatched dragons can be fused.", "Error")
		end
		local r = Dragons.ByName[slot.Species].Rarity
		if rarity and r ~= rarity then
			return Remotes.Notify:FireClient(player, "Pick 3 dragons of the same rarity.", "Error")
		end
		rarity = r
	end
	local nextRarity = Rarities.Next(rarity :: string)
	if not nextRarity then
		return Remotes.Notify:FireClient(player, "These dragons are already the rarest!", "Error")
	end

	local species = Dragons.RollSpecies(nextRarity.Name, rng)
	local mutation
	if data.LuckyFusions > 0 then
		data.LuckyFusions -= 1
		mutation = if rng:NextNumber() < 0.3 then "Shadow" else "Golden"
	else
		mutation = Dragons.RollMutation(Economy.FuseMutationLuck, rng)
	end

	for _, i in slots do
		data.Slots[tostring(i)] = nil
	end
	table.sort(slots)
	local target = tostring(slots[1])
	data.Slots[target] = { Species = species.Name, Mutation = mutation }
	local isNew = Registry.BaseService.Discover(player, species.Name)
	Registry.DataService.Changed(player)
	for _, i in slots do
		Registry.BaseService.RenderSlot(player, i)
	end
	Registry.BaseService.RefreshLabels(player)
	Remotes.NewDragon:FireClient(player, species.Name, mutation, isNew, "Fused")
	Registry.QuestService.Add(player, "Fuse")
	if nextRarity.Order >= 5 then
		Remotes.Announce:FireAllClients(("%s fused a %s%s!"):format(player.DisplayName, if mutation then mutation .. " " else "", species.Name), nextRarity.Color)
	end
end

function FusionService.Start()
	Remotes.Fuse.OnServerEvent:Connect(fuse)
end

return FusionService
