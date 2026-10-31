-- After 10 minutes of play, once per player ever, a friendly reminder to
-- like and favorite the game (likes and favorites help it get recommended).
-- No reward is given for it: Roblox doesn't allow paying players for likes.

local AvatarEditorService = game:GetService("AvatarEditorService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local LikePrompt = {}

local AFTER_SECONDS = 10 * 60

local function show()
	local gui = UI.Screen("LikePrompt", 8)
	local card = UI.Frame(gui, UDim2.fromOffset(440, 210), UDim2.fromScale(0.5, 0.5), UI.Colors.Panel)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	UI.Corner(card, 18)
	UI.Stroke(card, UI.Colors.Gold, 4)
	UI.Gradient(card, UI.Colors.PanelLight, UI.Colors.Panel)
	UI.Label(card, "🐉 Enjoying Dragon Egg Heist?", UDim2.new(1, -30, 0, 40), UDim2.fromOffset(15, 14), UI.Colors.Gold)
	local text = UI.Label(card, "A 👍 like and a ⭐ favorite really help new players find the game. Thanks for playing!",
		UDim2.new(1, -30, 0, 60), UDim2.fromOffset(15, 60), UI.Colors.Text)
	text.TextWrapped = true
	UI.Button(card, "⭐ Favorite", UI.Colors.Gold, UDim2.new(0.44, 0, 0, 52), UDim2.new(0.04, 0, 0, 140), function()
		pcall(function()
			AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)
		gui:Destroy()
	end)
	UI.Button(card, "Maybe later", Color3.fromRGB(110, 115, 135), UDim2.new(0.44, 0, 0, 52), UDim2.new(0.52, 0, 0, 140), function()
		gui:Destroy()
	end)
	UI.Pop(card, 0.6)
	Remotes.LikeAsked:FireServer()
end

function LikePrompt.Start()
	task.spawn(function()
		local data = State.Data
		while not data do
			State.Changed:Wait()
			data = State.Data
		end
		if data.LikeAsked then
			return
		end
		task.wait(AFTER_SECONDS)
		local now = State.Data
		if now and not now.LikeAsked and now.Tutorial then
			show()
		end
	end)
end

return LikePrompt
