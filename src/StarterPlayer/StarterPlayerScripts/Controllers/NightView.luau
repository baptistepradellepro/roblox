--[[
	NightView : l'ambiance de la Nuit Hantée côté joueur.
	  - le ciel devient violet et sombre (transition douce)
	  - le minuteur "Nuit dans 5:12" / "Nuit : 1:23" sous les pièces
	  - les pièces de la Nuit des Bonbons qui tournent
	(Gloutrouille est dessiné par MonsterView.)
]]

local Lighting = game:GetService("Lighting")
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

local NIGHT_LIGHTING = {
	ClockTime = 22.5,
	Brightness = 1,
	Ambient = Color3.fromRGB(90, 60, 140),
	OutdoorAmbient = Color3.fromRGB(80, 50, 130),
}
local NIGHT_ATMOSPHERE = {
	Density = 0.42,
	Haze = 1.5,
	Color = Color3.fromRGB(120, 80, 180),
	Decay = Color3.fromRGB(60, 30, 100),
}
local NIGHT_CC = {
	TintColor = Color3.fromRGB(215, 195, 255),
	Saturation = 0.25,
	Contrast = 0.12,
}

-- Ce qui change selon le thème de la nuit
local THEME_OVERRIDES = {
	Fog = { Atmosphere = { Density = 0.78, Haze = 4 } },
	Candy = { CC = { TintColor = Color3.fromRGB(255, 205, 235), Saturation = 0.45 } },
	Super = { CC = { TintColor = Color3.fromRGB(255, 180, 180), Contrast = 0.22 } },
}
local THEME_ICONS = { Classic = "🌙", Fog = "🌫️", Candy = "🍬", Super = "🔥" }

local dayLighting, dayAtmosphere, dayCC = {}, {}, {}
local music: Sound? = nil
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
		local override = THEME_OVERRIDES[ReplicatedStorage:GetAttribute("NightTheme") or "Classic"] or {}
		local atmosphereGoals = table.clone(NIGHT_ATMOSPHERE)
		for key, value in override.Atmosphere or {} do
			atmosphereGoals[key] = value
		end
		local ccGoals = table.clone(NIGHT_CC)
		for key, value in override.CC or {} do
			ccGoals[key] = value
		end
		tweenTo(Lighting, NIGHT_LIGHTING, duration)
		tweenTo(atmosphere, atmosphereGoals, duration)
		tweenTo(cc, ccGoals, duration)
	else
		tweenTo(Lighting, dayLighting, duration)
		tweenTo(atmosphere, dayAtmosphere, duration)
		tweenTo(cc, dayCC, duration)
	end
end

---------------------------------------------------------------- Démarrage

function NightView.start()
	snapshot(Lighting, NIGHT_LIGHTING, dayLighting)
	snapshot(Lighting:FindFirstChildOfClass("Atmosphere"), NIGHT_ATMOSPHERE, dayAtmosphere)
	snapshot(Lighting:FindFirstChild("SAG_ColorCorrection"), NIGHT_CC, dayCC)

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

	local timerKey = ""
	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local t = os.clock()

		-- minuteur (le texte n'est refait que quand la seconde affichée change)
		local night = ReplicatedStorage:GetAttribute("NightActive") == true
		local target = if night then ReplicatedStorage:GetAttribute("NightEndsAt") else ReplicatedStorage:GetAttribute("NextNightAt")
		local left = math.max(0, math.ceil((target or now) - now))
		local key = (if night then "N" else "D") .. left .. (ReplicatedStorage:GetAttribute("NightTheme") or "")
		if key ~= timerKey then
			timerKey = key
			if night then
				local icon = THEME_ICONS[ReplicatedStorage:GetAttribute("NightTheme") or "Classic"] or "🌙"
				timerLabel.Text = icon .. " " .. Lang.t("NightTimer", { time = Format.time(left) })
			else
				timerLabel.Text = "🌙 " .. Lang.t("DayTimer", { time = Format.time(left) })
			end
		end

		-- Nuit des Bonbons : les pièces tournent sur elles-mêmes
		local coins = workspace:FindFirstChild("CandyCoins")
		if coins then
			for _, coin in coins:GetChildren() do
				local base = coin:GetAttribute("Base")
				if coin:IsA("BasePart") and typeof(base) == "CFrame" then
					coin.CFrame = CFrame.new(base.Position + Vector3.new(0, math.sin(t * 3) * 0.3, 0)) * CFrame.Angles(0, t * 3, 0)
				end
			end
		end
	end)
end

return NightView
