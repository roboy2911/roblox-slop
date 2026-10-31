-- Particle helpers shared by server and client.
-- Uses our uploaded effect images when they're ready (ReplicatedStorage.ImageIds),
-- otherwise Roblox's built-in particle textures.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fx = {}

local FALLBACK = {
	FxSpark = "rbxasset://textures/particles/sparkles_main.dds",
	FxGlow = "rbxasset://textures/particles/sparkles_main.dds",
	FxStar = "rbxasset://textures/particles/sparkles_main.dds",
	FxFlame = "rbxasset://textures/particles/fire_main.dds",
	FxSmoke = "rbxasset://textures/particles/smoke_main.dds",
	FxCoin = "rbxasset://textures/particles/sparkles_main.dds",
}

function Fx.Image(name: string): string
	local folder = ReplicatedStorage:FindFirstChild("ImageIds")
	local id = folder and folder:GetAttribute(name)
	return id or FALLBACK[name] or FALLBACK.FxSpark
end

export type EmitterOptions = {
	Image: string?,
	Color: Color3?,
	Rate: number?,
	Lifetime: NumberRange?,
	Speed: NumberRange?,
	Size: number?,
	SpreadAngle: Vector2?,
	LightEmission: number?,
	Acceleration: Vector3?,
	Transparency: NumberSequence?,
}

function Fx.Emitter(parent: Instance, o: EmitterOptions): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = Fx.Image(o.Image or "FxSpark")
	e.Color = ColorSequence.new(o.Color or Color3.new(1, 1, 1))
	e.Rate = o.Rate or 6
	e.Lifetime = o.Lifetime or NumberRange.new(0.8, 1.4)
	e.Speed = o.Speed or NumberRange.new(1, 3)
	local size = o.Size or 0.6
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.SpreadAngle = o.SpreadAngle or Vector2.new(180, 180)
	e.LightEmission = o.LightEmission or 0.8
	e.Acceleration = o.Acceleration or Vector3.zero
	e.Transparency = o.Transparency or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = parent
	return e
end

-- Sparkles and a glow for Golden / Shadow dragons and eggs.
function Fx.Mutation(part: BasePart, mutation: string?)
	if mutation == "Golden" then
		Fx.Emitter(part, { Image = "FxSpark", Color = Color3.fromRGB(255, 215, 70), Rate = 8, Size = 0.7 })
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 210, 90)
		light.Range = 9
		light.Brightness = 1.5
		light.Parent = part
	elseif mutation == "Shadow" then
		Fx.Emitter(part, {
			Image = "FxSmoke",
			Color = Color3.fromRGB(110, 40, 190),
			Rate = 10,
			Size = 1.4,
			Speed = NumberRange.new(0.5, 1.5),
			LightEmission = 0.3,
			Acceleration = Vector3.new(0, 2, 0),
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(150, 60, 255)
		light.Range = 9
		light.Brightness = 1.5
		light.Parent = part
	end
end

-- The biggest part of a model (to hang effects and lights on).
function Fx.MainPart(model: Model): BasePart?
	local best, bestSize = nil, -1
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local s = p.Size.X * p.Size.Y * p.Size.Z
			if s > bestSize then
				best, bestSize = p, s
			end
		end
	end
	return best
end

return Fx
