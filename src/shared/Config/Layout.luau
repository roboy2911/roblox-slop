-- Where the castles go and what's inside them.
-- Castles sit in a row along X at Z < 0, facing +Z (the valley).
-- Positions inside a castle are offsets from its center: +X right, +Z toward the gate.

local Layout = {}

Layout.PlotCount = 8
Layout.PlotSpacing = 76
Layout.CastleHalf = 32 -- the inside is 64 x 64
Layout.CastleCenterZ = -38
Layout.GateHalfWidth = 5
Layout.WallHeight = 14

function Layout.PlotCenter(index: number): Vector3
	return Vector3.new((index - (Layout.PlotCount + 1) / 2) * Layout.PlotSpacing, 0, Layout.CastleCenterZ)
end

-- Perch spots, in the order they're unlocked (front row first).
Layout.Perches = {}
for _, z in { 0, -9, -18, -27 } do
	for _, x in { 0, -11, 11, -22, 22 } do
		table.insert(Layout.Perches, Vector3.new(x, 0, z))
	end
end

Layout.Chest = Vector3.new(21, 0, 15)
Layout.Altar = Vector3.new(-21, 0, 15)
Layout.LockPad = Vector3.new(11, 0, 25)
Layout.Spawn = Vector3.new(0, 3, 20)
Layout.Sign = Vector3.new(0, 0, 32)

-- How close (studs) you need to be to the chest or lock pad to use it.
Layout.ChestRadius = 6
Layout.LockPadRadius = 3.5

-- Is a world position inside the castle at `center`?
function Layout.Inside(center: Vector3, position: Vector3): boolean
	local d = position - center
	return math.abs(d.X) < Layout.CastleHalf and math.abs(d.Z) < Layout.CastleHalf and d.Y < 40
end

-- Banner colors for each castle.
Layout.Colors = {
	Color3.fromRGB(220, 60, 60),
	Color3.fromRGB(60, 120, 230),
	Color3.fromRGB(70, 190, 90),
	Color3.fromRGB(240, 190, 40),
	Color3.fromRGB(170, 80, 220),
	Color3.fromRGB(240, 130, 40),
	Color3.fromRGB(40, 200, 200),
	Color3.fromRGB(240, 110, 180),
}

return Layout
