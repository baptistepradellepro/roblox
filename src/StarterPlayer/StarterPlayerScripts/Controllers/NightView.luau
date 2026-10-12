--[[
	NightView : l'ambiance de la Nuit Hantée côté joueur.
	  - le ciel devient violet et sombre (transition douce)
	  - le minuteur "Nuit dans 5:12" / "Nuit : 1:23" sous les pièces
	  - Gloutrouille, le monstre : on le dessine et on le fait glisser vers la position
	    calculée par le serveur
	  - quand il te poursuit : bords de l'écran rouges + battements de cœur
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))

local Effects = require(script.Parent.Effects)
local HUD = require(script.Parent.HUD)
local Lang = require(script.Parent.Lang)
local UI = require(script.Parent.UI)

local NightView = {}

local player = Players.LocalPlayer

local NIGHT_LIGHTING = {
	ClockTime = 22.5,
	Brightness = 1,
	Ambient = Color3.fromRGB(90, 60, 140),
	OutdoorAmbient = Color3.fromRGB(80, 50, 130),
}
local NIGHT_ATMOSPHERE = {
	Density = 0.42,
	Color = Color3.fromRGB(120, 80, 180),
	Decay = Color3.fromRGB(60, 30, 100),
}
local NIGHT_CC = {
	TintColor = Color3.fromRGB(215, 195, 255),
	Saturation = 0.25,
	Contrast = 0.12,
}

local dayLighting, dayAtmosphere, dayCC = {}, {}, {}
local music: Sound? = nil
local monster: Model? = nil
local monsterAnchor: BasePart? = nil
local vignette: Frame
local timerLabel: TextLabel

local function snapshot(target: Instance?, keys: { [string]: any }, into: { [string]: any })
	if not target then
		return
	end
	for key in keys do
		into[key] = (target :: any)[key]
	end
end

local function tweenTo(target: Instance?, goals: { [string]: any }, duration: number)
	if target and next(goals) then
		TweenService:Create(target, TweenInfo.new(duration, Enum.EasingStyle.Sine), goals):Play()
	end
end

local function applyNight(active: boolean, duration: number)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local cc = Lighting:FindFirstChild("SAG_ColorCorrection")
	if active then
		tweenTo(Lighting, NIGHT_LIGHTING, duration)
		tweenTo(atmosphere, NIGHT_ATMOSPHERE, duration)
		tweenTo(cc, NIGHT_CC, duration)
	else
		tweenTo(Lighting, dayLighting, duration)
		tweenTo(atmosphere, dayAtmosphere, duration)
		tweenTo(cc, dayCC, duration)
	end
end

---------------------------------------------------------------- Le monstre

local function part(model: Model, shape: Enum.PartType?, size: Vector3, cf: CFrame, color: Color3, extra: { [string]: any }?)
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	if extra then
		local writable: any = p
		for key, value in extra do
			writable[key] = value
		end
	end
	p.Parent = model
	return p
end

-- Gloutrouille : une citrouille en gelée avec des dents en bonbons (l'avant est en -Z)
local function buildMonster(): Model
	local model = Instance.new("Model")
	model.Name = "Gloutrouille"
	local root = part(model, nil, Vector3.one, CFrame.identity, Color3.new(1, 1, 1), { Transparency = 1, Name = "Root" })
	model.PrimaryPart = root

	local orange = Color3.fromRGB(255, 125, 25)
	part(model, Enum.PartType.Ball, Vector3.one * 9, CFrame.identity, orange)
	part(model, Enum.PartType.Ball, Vector3.one * 10.2, CFrame.identity, Color3.fromRGB(170, 80, 255), {
		Transparency = 0.65,
		Material = Enum.Material.Glass,
	})
	-- côtes de citrouille
	for _, x in { -2.6, 2.6 } do
		part(model, Enum.PartType.Ball, Vector3.one * 7.4, CFrame.new(x, 0, 0.6), orange:Lerp(Color3.new(0, 0, 0), 0.12))
	end
	-- yeux qui brillent
	local glow = Color3.fromRGB(190, 255, 80)
	for _, x in { -1.7, 1.7 } do
		part(model, nil, Vector3.new(1.6, 1.6, 0.6), CFrame.new(x, 1.3, -4.2) * CFrame.Angles(0, 0, math.rad(45)), glow, {
			Material = Enum.Material.Neon,
		})
	end
	-- grande bouche + dents en bonbons
	part(model, nil, Vector3.new(5.4, 1.6, 0.6), CFrame.new(0, -1.3, -4.1), Color3.fromRGB(40, 10, 45))
	local candy = { Color3.fromRGB(255, 255, 240), Color3.fromRGB(255, 210, 60), Color3.fromRGB(255, 130, 30) }
	for i = 0, 4 do
		part(model, nil, Vector3.new(0.7, 0.8, 0.5), CFrame.new(-2 + i, -0.75, -4.35), candy[i % 3 + 1])
	end
	-- tige et petits bras
	part(model, Enum.PartType.Cylinder, Vector3.new(2, 1, 1), CFrame.new(0, 5.2, 0) * CFrame.Angles(0, 0, math.rad(80)), Color3.fromRGB(70, 140, 40))
	for _, x in { -5, 5 } do
		part(model, Enum.PartType.Ball, Vector3.one * 2.4, CFrame.new(x, -1.5, -1), orange, { Name = "Arm" })
	end

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 60)
	light.Range = 22
	light.Brightness = 2
	light.Shadows = false
	light.Parent = root

	local tag = UI.new("BillboardGui", {
		Size = UDim2.fromOffset(240, 46),
		StudsOffsetWorldSpace = Vector3.new(0, 8, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 400,
		AutoLocalize = false,
		Adornee = root,
		Parent = root,
	})
	UI.label({
		Size = UDim2.fromScale(1, 1),
		Text = "👹 GLOUTROUILLE",
		TextColor3 = Color3.fromRGB(255, 120, 60),
		MaxTextSize = 34,
		Parent = tag,
	})
	return model
end

local function onAnchorAdded(anchor: Instance)
	if anchor.Name ~= "GloutrouilleAnchor" or not anchor:IsA("BasePart") then
		return
	end
	if monster then
		monster:Destroy()
	end
	monsterAnchor = anchor
	local model = buildMonster()
	model:PivotTo(anchor.CFrame)
	model.Parent = workspace
	monster = model
	Effects.poof(anchor.Position, Color3.fromRGB(255, 140, 30))
end

local function onAnchorRemoved(anchor: Instance)
	if anchor == monsterAnchor then
		if monster then
			Effects.poof(monster:GetPivot().Position, Color3.fromRGB(170, 80, 255))
			monster:Destroy()
		end
		monster = nil
		monsterAnchor = nil
	end
end

---------------------------------------------------------------- Démarrage

function NightView.start()
	snapshot(Lighting, NIGHT_LIGHTING, dayLighting)
	snapshot(Lighting:FindFirstChildOfClass("Atmosphere"), NIGHT_ATMOSPHERE, dayAtmosphere)
	snapshot(Lighting:FindFirstChild("SAG_ColorCorrection"), NIGHT_CC, dayCC)

	-- Bords rouges quand le monstre te poursuit
	local vignetteGui = UI.new("ScreenGui", {
		Name = "SAG_Vignette",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = -1,
		Parent = player:WaitForChild("PlayerGui"),
	})
	vignette = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 0, 40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = vignetteGui,
	}, {
		UI.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.2, 0.9),
				NumberSequenceKeypoint.new(0.8, 0.9),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}),
	})

	local pill = HUD.pill(UI.Colors.Purple, 1)
	pill.Visible = true
	timerLabel = pill:FindFirstChild("Text") :: TextLabel

	local function onNightChanged()
		local active = ReplicatedStorage:GetAttribute("NightActive") == true
		applyNight(active, 3)
		if active then
			music = Effects.music("NightMusic")
		elseif music then
			music:Destroy()
			music = nil
		end
	end
	ReplicatedStorage:GetAttributeChangedSignal("NightActive"):Connect(onNightChanged)
	if ReplicatedStorage:GetAttribute("NightActive") then
		applyNight(true, 0.1)
	end

	workspace.ChildAdded:Connect(onAnchorAdded)
	workspace.ChildRemoved:Connect(onAnchorRemoved)
	local existing = workspace:FindFirstChild("GloutrouilleAnchor")
	if existing then
		onAnchorAdded(existing)
	end

	local nextHeartbeat = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		local t = os.clock()

		-- minuteur
		if ReplicatedStorage:GetAttribute("NightActive") then
			timerLabel.Text = "🌙 " .. Lang.t("NightTimer", { time = Format.time((ReplicatedStorage:GetAttribute("NightEndsAt") or now) - now) })
		else
			timerLabel.Text = "🌙 " .. Lang.t("DayTimer", { time = Format.time((ReplicatedStorage:GetAttribute("NextNightAt") or now) - now) })
		end

		-- monstre : il glisse vers la position du serveur, rebondit et agite les bras
		local chased = false
		if monster and monsterAnchor then
			local alpha = 1 - math.exp(-dt * 10)
			local goal = monsterAnchor.CFrame * CFrame.new(0, math.abs(math.sin(t * 5)) * 1.2, 0)
			monster:PivotTo(monster:GetPivot():Lerp(goal, alpha))
			if monsterAnchor:GetAttribute("TargetUserId") == player.UserId then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				chased = root ~= nil and (root.Position - monsterAnchor.Position).Magnitude < 50
			end
		end
		if chased then
			vignette.BackgroundTransparency = 0.35 + math.abs(math.sin(t * 4)) * 0.4
			if t >= nextHeartbeat then
				nextHeartbeat = t + 0.6
				Effects.sound("Heartbeat")
			end
		else
			vignette.BackgroundTransparency = 1
		end
	end)
end

return NightView
