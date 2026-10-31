-- A tiny UI kit: chunky cartoon buttons, panels and labels, all in one style.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UI = {}

UI.Font = Enum.Font.FredokaOne
UI.Colors = {
	Panel = Color3.fromRGB(34, 38, 66),
	PanelLight = Color3.fromRGB(52, 58, 98),
	Stroke = Color3.fromRGB(16, 18, 34),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(175, 182, 215),
	Gold = Color3.fromRGB(255, 205, 50),
	Green = Color3.fromRGB(80, 210, 90),
	Red = Color3.fromRGB(235, 70, 70),
	Blue = Color3.fromRGB(70, 150, 255),
	Purple = Color3.fromRGB(170, 95, 255),
	Orange = Color3.fromRGB(255, 145, 40),
}

local player = Players.LocalPlayer

function UI.Screen(name: string, order: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order or 0
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

function UI.Corner(parent: Instance, radius: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
	return c
end

function UI.Stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or UI.Colors.Stroke
	s.Thickness = thickness or 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function UI.TextStroke(parent: Instance, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = UI.Colors.Stroke
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
	return s
end

function UI.Gradient(parent: Instance, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = parent
	return g
end

function UI.Padding(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
	return p
end

function UI.Frame(parent: Instance, size: UDim2, position: UDim2?, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = position or UDim2.new()
	f.BackgroundColor3 = color or UI.Colors.Panel
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

function UI.Label(parent: Instance, text: string, size: UDim2, position: UDim2?, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position or UDim2.new()
	l.Font = UI.Font
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color or UI.Colors.Text
	l.Parent = parent
	UI.TextStroke(l)
	return l
end

-- Pops a GuiObject with a quick bounce.
function UI.Pop(gui: GuiObject, amount: number?)
	local scale = gui:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = gui
	scale.Scale = amount or 1.15
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- A chunky button. Returns the button; its Text is the label.
function UI.Button(parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2?, onClick: (() -> ())?): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = position or UDim2.new()
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = false
	b.Font = UI.Font
	b.Text = text
	b.TextScaled = true
	b.TextColor3 = UI.Colors.Text
	b.Parent = parent
	UI.Corner(b, 12)
	UI.Stroke(b, UI.Colors.Stroke, 3)
	b.TextStrokeTransparency = 0.25
	b.TextStrokeColor3 = UI.Colors.Stroke
	local gradient = UI.Gradient(b, color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.15))
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1.05 }):Play()
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	b:SetAttribute("BaseColor", color)
	b:SetAttribute("GradientName", gradient.Name)
	return b
end

-- Changes a button's color (e.g. grey when you can't afford it).
function UI.SetButtonColor(b: TextButton, color: Color3)
	local g = b:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.15))
	end
end

-- ------------------------------------------------------------ panels
-- One panel is open at a time.

export type Panel = {
	Frame: Frame,
	Body: Frame,
	Open: () -> (),
	Close: () -> (),
	Toggle: () -> (),
	IsOpen: () -> boolean,
	OnOpen: BindableEvent,
}

local current: Panel? = nil
local panelGui: ScreenGui? = nil

function UI.Panel(title: string, color: Color3, size: UDim2?): Panel
	panelGui = panelGui or UI.Screen("Panels", 5)
	local frame = UI.Frame(panelGui :: ScreenGui, size or UDim2.fromScale(0.5, 0.62), UDim2.fromScale(0.5, 0.5))
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Visible = false
	UI.Corner(frame, 18)
	UI.Stroke(frame, UI.Colors.Stroke, 4)
	UI.Gradient(frame, UI.Colors.PanelLight, UI.Colors.Panel)
	local ratio = Instance.new("UISizeConstraint")
	ratio.MinSize = Vector2.new(320, 300)
	ratio.MaxSize = Vector2.new(760, 560)
	ratio.Parent = frame

	local header = UI.Frame(frame, UDim2.new(1, 0, 0, 54), UDim2.new(), color)
	UI.Corner(header, 18)
	UI.Gradient(header, color:Lerp(Color3.new(1, 1, 1), 0.2), color:Lerp(Color3.new(0, 0, 0), 0.2))
	UI.Label(header, title, UDim2.new(1, -120, 0, 38), UDim2.new(0, 18, 0, 8))
	local close = UI.Button(header, "X", UI.Colors.Red, UDim2.fromOffset(44, 44), UDim2.new(1, -52, 0, 5))

	local body = UI.Frame(frame, UDim2.new(1, -24, 1, -70), UDim2.new(0, 12, 0, 62))
	body.BackgroundTransparency = 1

	local onOpen = Instance.new("BindableEvent")
	local panel: Panel
	panel = {
		Frame = frame,
		Body = body,
		OnOpen = onOpen,
		IsOpen = function()
			return frame.Visible
		end,
		Open = function()
			if current and current ~= panel then
				current.Close()
			end
			current = panel
			frame.Visible = true
			UI.Pop(frame, 0.85)
			onOpen:Fire()
		end,
		Close = function()
			frame.Visible = false
			if current == panel then
				current = nil
			end
		end,
		Toggle = function()
			if frame.Visible then
				panel.Close()
			else
				panel.Open()
			end
		end,
	}
	close.Activated:Connect(panel.Close)
	return panel
end

-- A scrolling grid inside a panel body.
function UI.Grid(parent: Instance, cellSize: UDim2, position: UDim2?, size: UDim2?): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = size or UDim2.fromScale(1, 1)
	scroll.Position = position or UDim2.new()
	scroll.ScrollBarThickness = 8
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = parent
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = cellSize
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	UI.Padding(scroll, 6)
	return scroll
end

return UI
