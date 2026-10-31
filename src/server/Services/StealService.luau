-- Stealing dragons from other castles.
--
-- Walk into someone's castle (if it isn't locked), hold F on a dragon, and run
-- it home. It rides over your head and slows you down. If the owner bonks you,
-- you die, you leave, or you take too long, it flies back to its perch.
-- The dragon only changes hands when you make it inside your own castle.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Fx = require(ReplicatedStorage.Shared.Fx)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ModelFactory = require(script.Parent.ModelFactory)
local Registry = require(script.Parent.Registry)

local StealService = {}

type Theft = {
	Owner: Player,
	Slot: number,
	Species: string,
	Mutation: string?,
	Model: Model?,
	Started: number,
}

local thefts: { [Player]: Theft } = {}

function StealService.IsStealing(player: Player): boolean
	return thefts[player] ~= nil
end

local function updateExtras(thief: Player)
	local theft = thefts[thief]
	Registry.DataService.SetExtra(thief, "Stealing", theft and theft.Species or nil)
	Registry.UpgradeService.ApplySpeed(thief)
end

local function carryModel(thief: Player, species: string, mutation: string?): Model?
	local head = thief.Character and thief.Character:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local model = ModelFactory.Make(species, 3)
	model:PivotTo(head.CFrame * CFrame.new(0, 1.3, 0))
	local main = Fx.MainPart(model) :: BasePart
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.Massless = true
			if p ~= main then
				local w = Instance.new("WeldConstraint")
				w.Part0 = main
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = main
	weld.Parent = main
	Fx.Mutation(main, mutation)
	-- A red glow so everyone can see who the thief is.
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 60, 60)
	light.Range = 14
	light.Brightness = 2
	light.Parent = main
	model.Parent = thief.Character
	return model
end

-- Sends the dragon home. Called when the thief fails for any reason.
function StealService.Fail(thief: Player, reason: string?)
	local theft = thefts[thief]
	if not theft then
		return
	end
	thefts[thief] = nil
	if theft.Model then
		theft.Model:Destroy()
	end
	if theft.Owner.Parent then
		Registry.BaseService.SetStolen(theft.Owner, theft.Slot, false)
		if reason == "Bonk" then
			Remotes.Notify:FireClient(theft.Owner, ("You got your %s back!"):format(theft.Species), "Good")
		end
	end
	if thief.Parent then
		updateExtras(thief)
		if reason == "Timeout" then
			Remotes.Notify:FireClient(thief, "Too slow! The dragon flew home.", "Error")
		elseif reason == "Bonk" then
			Remotes.Notify:FireClient(thief, "BONK! The dragon flew home.", "Error")
		end
	end
end

local function start(thief: Player, owner: Player, i: number)
	if thief == owner or thefts[thief] then
		return
	end
	local humanoid = thief.Character and thief.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local plot = Registry.PlotService.Get(owner)
	if not plot or Registry.PlotService.IsLocked(plot) then
		Remotes.Notify:FireClient(thief, "That castle is locked!", "Error")
		return
	end
	if Registry.EggService.Count(thief) > 0 then
		Remotes.Notify:FireClient(thief, "Drop off your eggs first! You need empty hands to steal.", "Error")
		return
	end
	if not Registry.PlotService.Get(thief) then
		return
	end
	if Registry.BaseService.FreeSlots(thief) <= 0 then
		Remotes.Notify:FireClient(thief, "You have no free perch for a stolen dragon!", "Error")
		return
	end
	local data = Registry.DataService.Get(owner)
	local slot = data and data.Slots[tostring(i)]
	if not slot or slot.HatchAt or slot.Stolen then
		return
	end

	local theft: Theft = {
		Owner = owner,
		Slot = i,
		Species = slot.Species,
		Mutation = slot.Mutation,
		Started = os.clock(),
	}
	thefts[thief] = theft
	Registry.BaseService.SetStolen(owner, i, true)
	theft.Model = carryModel(thief, slot.Species, slot.Mutation)
	updateExtras(thief)

	local rarity = Rarities.ByName[Dragons.ByName[slot.Species].Rarity]
	Remotes.Notify:FireClient(thief, "Run home before they bonk you!", "Warn")
	Remotes.Notify:FireClient(owner, ("%s is stealing your %s! Bonk them!"):format(thief.DisplayName, slot.Species), "Error")
	if rarity.Order >= 4 then
		Remotes.Announce:FireAllClients(("%s is stealing %s's %s!"):format(thief.DisplayName, owner.DisplayName, slot.Species), Color3.fromRGB(255, 90, 90))
	end
end

local function complete(thief: Player, theft: Theft)
	local owner = theft.Owner
	local ownerData = Registry.DataService.Get(owner)
	local slot = ownerData and ownerData.Slots[tostring(theft.Slot)]
	if not owner.Parent or not slot or not slot.Stolen or slot.Species ~= theft.Species then
		StealService.Fail(thief)
		return
	end
	if Registry.BaseService.FreeSlots(thief) <= 0 then
		-- Filled up on the way; can't keep it.
		StealService.Fail(thief)
		Remotes.Notify:FireClient(thief, "No free perch! The dragon flew home.", "Error")
		return
	end
	thefts[thief] = nil
	if theft.Model then
		theft.Model:Destroy()
	end
	Registry.BaseService.RemoveSlot(owner, theft.Slot)
	Registry.BaseService.AddToFreeSlot(thief, { Species = theft.Species, Mutation = theft.Mutation })
	updateExtras(thief)
	Remotes.Notify:FireClient(thief, ("You stole a %s!"):format(theft.Species), "Good")
	Remotes.Notify:FireClient(owner, ("%s stole your %s!"):format(thief.DisplayName, theft.Species), "Error")
	Remotes.NewDragon:FireClient(thief, theft.Species, theft.Mutation, false, "Stolen")
end

local function onPrompt(prompt: ProximityPrompt, player: Player)
	if prompt:GetAttribute("Kind") ~= "Steal" then
		return
	end
	local owner = Players:GetPlayerByUserId(prompt:GetAttribute("OwnerId") or 0)
	local i = prompt:GetAttribute("Slot")
	if owner and typeof(i) == "number" then
		start(player, owner, i)
	end
end

function StealService.Start()
	ProximityPromptService.PromptTriggered:Connect(onPrompt)

	task.spawn(function()
		while true do
			task.wait(0.2)
			for thief, theft in thefts do
				if not thief.Parent then
					StealService.Fail(thief)
				elseif os.clock() - theft.Started > Economy.StealTimeout then
					StealService.Fail(thief, "Timeout")
				elseif Registry.PlotService.IsHome(thief) then
					complete(thief, theft)
				end
			end
		end
	end)

	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				StealService.Fail(player)
			end)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		StealService.Fail(player)
	end)
	-- If the owner leaves mid-theft, the dragon stays theirs (it's saved with them).
	Registry.DataService.OnLeaving(function(owner, data)
		for thief, theft in thefts do
			if theft.Owner == owner then
				StealService.Fail(thief)
			end
		end
		for _, slot in data.Slots do
			slot.Stolen = nil
		end
	end)
end

return StealService
