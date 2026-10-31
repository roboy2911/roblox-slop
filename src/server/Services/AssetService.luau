-- Loads our uploaded models and textures.
--
-- Textures are uploaded as Decals, but a MeshPart needs the image ID inside
-- the Decal, so we load each Decal once and read its Texture. Effect image
-- IDs are published in ReplicatedStorage.ImageIds (as attributes) so
-- clients can use them for particles.
--
-- Loading only works if the place is owned by the same account that owns
-- the assets. An ID of 0 means "not uploaded yet". Either way callers get
-- nil and use a stand-in (see ModelFactory).

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)

local AssetService = {}

local imageCache: { [number]: string | false } = {}
local modelCache: { [string]: Model | false } = {}
local loading: { [string]: boolean } = {}
local warned = false

local function loadAsset(assetId: number): Instance?
	if assetId == 0 then
		return nil
	end
	local ok, result = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if ok then
		return result
	end
	if not warned then
		warned = true
		warn(("[AssetService] Couldn't load asset %d: %s. Models will use simple stand-ins. "
			.. "The place must be owned by the account that uploaded the assets."):format(assetId, tostring(result)))
	end
	return nil
end

-- The image ID ("rbxassetid://...") inside an uploaded Decal.
function AssetService.ImageFromDecal(decalId: number): string?
	local cached = imageCache[decalId]
	if cached ~= nil then
		return cached or nil
	end
	local id = nil
	local container = loadAsset(decalId)
	if container then
		local decal = container:FindFirstChildWhichIsA("Decal", true)
		if decal and decal.Texture ~= "" then
			id = decal.Texture
		end
		container:Destroy()
	end
	imageCache[decalId] = id or false
	return id
end

local function buildTemplate(name: string): Model | false
	local entry = Assets.Models[name]
	if not entry or entry.Model == 0 then
		return false
	end
	local container = loadAsset(entry.Model)
	if not container then
		return false
	end
	local model = Instance.new("Model")
	model.Name = name
	for _, part in container:GetDescendants() do
		if part:IsA("BasePart") then
			part.Parent = model
		end
	end
	container:Destroy()
	if not model:FindFirstChildWhichIsA("BasePart") then
		return false
	end

	local texture = AssetService.ImageFromDecal(entry.Texture)
	for _, part in model:GetChildren() do
		if part:IsA("MeshPart") then
			part.Anchored = true
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.new(1, 1, 1) -- don't tint our texture
			if texture then
				local ok, err = pcall(function()
					part.TextureID = texture
				end)
				if not ok then
					warn("[AssetService] Couldn't apply texture to " .. name .. ": " .. tostring(err))
				end
			end
		end
	end

	-- Pivot at the bottom center, facing -Z (the way models face in Blender).
	local box, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0))
	return model
end

-- A fresh copy of a textured model, or nil if it couldn't be loaded.
-- Its pivot is at the bottom center, so model:PivotTo(groundCFrame) stands it on the ground.
function AssetService.Model(name: string): Model?
	while loading[name] do
		task.wait()
	end
	if modelCache[name] == nil then
		loading[name] = true
		modelCache[name] = buildTemplate(name)
		loading[name] = nil
	end
	local template = modelCache[name]
	return if template then template:Clone() else nil
end

function AssetService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "ImageIds"
	folder.Parent = ReplicatedStorage
	for name, decalId in Assets.Images do
		if decalId ~= 0 then
			task.spawn(function()
				local id = AssetService.ImageFromDecal(decalId)
				if id then
					folder:SetAttribute(name, id)
				end
			end)
		end
	end
end

return AssetService
