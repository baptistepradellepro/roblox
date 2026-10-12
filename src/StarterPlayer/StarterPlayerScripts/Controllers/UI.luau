--[[
	UI : petite boîte à outils pour créer l'interface (couleurs, coins arrondis,
	gros boutons qui rebondissent, mise à l'échelle automatique pour les mobiles).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Lang = require(script.Parent.Lang)

local UI = {}

UI.Font = Enum.Font.FredokaOne
UI.Colors = {
	Panel = Color3.fromRGB(38, 24, 58),
	PanelLight = Color3.fromRGB(70, 45, 105),
	Stroke = Color3.fromRGB(20, 10, 30),
	Text = Color3.fromRGB(255, 255, 255),
	Gold = Color3.fromRGB(255, 205, 60),
	Good = Color3.fromRGB(80, 220, 120),
	Bad = Color3.fromRGB(255, 80, 90),
	Info = Color3.fromRGB(120, 190, 255),
	Purple = Color3.fromRGB(170, 100, 255),
	Orange = Color3.fromRGB(255, 140, 30),
	Gray = Color3.fromRGB(110, 105, 120),
}

local player = Players.LocalPlayer

function UI.isMobile(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Crée une instance avec ses propriétés et ses enfants en une seule fois
function UI.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance: any = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UI.corner(radius: number?): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 14) })
end

function UI.stroke(color: Color3?, thickness: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color or UI.Colors.Stroke,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.textStroke(thickness: number?): UIStroke
	return UI.new("UIStroke", {
		Color = UI.Colors.Stroke,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

-- Un texte qui s'adapte à sa boîte (taille max pour rester lisible)
function UI.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
		Text = "",
	}
	for key, value in props do
		defaults[key] = value
	end
	local maxSize = defaults.MaxTextSize
	defaults.MaxTextSize = nil
	local label = UI.new("TextLabel", defaults)
	UI.new("UITextSizeConstraint", { MaxTextSize = maxSize or 40, MinTextSize = 8, Parent = label })
	UI.textStroke(2).Parent = label
	return label
end

-- Le conteneur principal de l'interface, mis à l'échelle selon l'écran
function UI.screen(name: string, displayOrder: number?): ScreenGui
	local gui = UI.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
		AutoLocalize = Lang.autoLocalize,
	})
	local scale = UI.new("UIScale", { Parent = gui })
	local function update()
		-- la place vraiment libre (sans la barre du haut de Roblox)
		local size = gui.AbsoluteSize
		if typeof(size) ~= "Vector2" or size.X < 10 or size.Y < 10 then
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end
			size = camera.ViewportSize - Vector2.new(0, 58)
		end
		-- l'interface a besoin d'environ 1150 x 640 points : on rapetisse sur les petits
		-- écrans (téléphone en paysage), sans descendre trop bas pour rester lisible
		scale.Scale = math.clamp(math.min(size.X / 1150, size.Y / 640), 0.45, 1.35)
	end
	update()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(update)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	gui.Parent = player:WaitForChild("PlayerGui")
	task.defer(update)
	return gui
end

-- Gros bouton rond ou carré avec une icône (emoji) et un texte en dessous
function UI.bigButton(props: {
	Name: string,
	Icon: string,
	Text: string,
	Color: Color3,
	Size: number?,
	Parent: Instance?,
	LayoutOrder: number?,
}): (TextButton, TextLabel, TextLabel)
	local size = props.Size or 104
	local button = UI.new("TextButton", {
		Name = props.Name,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = props.Color,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	}, { UI.corner(math.floor(size * 0.28)), UI.stroke(nil, 4) })
	local icon = UI.label({
		Name = "Icon",
		Size = UDim2.fromScale(1, 0.58),
		Position = UDim2.fromScale(0, 0.04),
		Text = props.Icon,
		MaxTextSize = 60,
		Parent = button,
	})
	local text = UI.label({
		Name = "Caption",
		Size = UDim2.fromScale(0.92, 0.32),
		Position = UDim2.fromScale(0.04, 0.62),
		Text = props.Text,
		MaxTextSize = 22,
		Parent = button,
	})
	local scaler = UI.new("UIScale", { Parent = button })
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scaler, TweenInfo.new(0.08), { Scale = 0.9 }):Play()
	end)
	local function release()
		TweenService:Create(scaler, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	return button, icon, text
end

-- Petit rebond pour attirer l'œil
function UI.pop(guiObject: GuiObject)
	local scaler = guiObject:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = guiObject })
	scaler.Scale = 1.25
	TweenService:Create(scaler, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

return UI
