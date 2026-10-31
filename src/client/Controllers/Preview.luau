-- Shows a 3D model (dragon or egg) inside a UI frame, using the copies the
-- server puts in ReplicatedStorage.Templates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Preview = {}

function Preview.Make(parent: Instance, modelName: string, silhouette: boolean?): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = Color3.fromRGB(200, 200, 200)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-1, -1, -0.5)
	vp.Parent = parent

	local templates = ReplicatedStorage:FindFirstChild("Templates")
	local template = templates and templates:FindFirstChild(modelName)
	if not template then
		return vp
	end
	local model = template:Clone() :: Model
	model:PivotTo(CFrame.new())
	if silhouette then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.Color = Color3.new(0, 0, 0)
				if p:IsA("MeshPart") then
					p.TextureID = ""
				end
			elseif p:IsA("Decal") or p:IsA("ParticleEmitter") or p:IsA("Light") then
				p:Destroy()
			end
		end
		vp.ImageColor3 = Color3.fromRGB(20, 20, 30)
	end
	model.Parent = vp

	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
	-- Models face -Z: look at them from the front-right.
	local dir = Vector3.new(0.55, 0.35, -1).Unit
	camera.CFrame = CFrame.lookAt(cf.Position + dir * distance, cf.Position)
	camera.Parent = vp
	vp.CurrentCamera = camera
	return vp
end

return Preview
