--[[
	WinterView : l'Hiver Hanté côté joueur.
	  - pendant l'événement (1er déc - 5 janv) : il neige et le sol devient blanc
	  - la semaine d'avant : quelques flocons et un message « l'Hiver Hanté arrive »
	Le serveur dit ce qui est en cours (attributs EventWinter et WinterTeaser).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HUD = require(script.Parent.HUD)
local Lang = require(script.Parent.Lang)

local WinterView = {}

local snowPart: Part? = nil
local emitter: ParticleEmitter? = nil
local groundColor: Color3? = nil
local groundMaterial: Enum.Material? = nil
local toldTeaser, toldWinter = false, false

local SNOW_GROUND = Color3.fromRGB(225, 235, 245)

local function setSnow(rate: number)
	if rate <= 0 then
		if snowPart then
			snowPart:Destroy()
			snowPart, emitter = nil, nil
		end
		return
	end
	if not snowPart then
		local p = Instance.new("Part")
		p.Name = "SnowCloud"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Size = Vector3.new(140, 1, 140)
		p.Parent = workspace
		local e = Instance.new("ParticleEmitter")
		e.Name = "Snow"
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		e.Size = NumberSequence.new(0.35)
		e.Speed = NumberRange.new(5, 8)
		e.Lifetime = NumberRange.new(7, 9)
		e.SpreadAngle = Vector2.new(25, 25)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-40, 40)
		e.LightEmission = 0.4
		e.Parent = p
		snowPart, emitter = p, e
	end
	if emitter then
		emitter.Rate = rate
	end
end

-- Le sol blanc pendant l'hiver (seulement sur mon écran)
local function setSnowyGround(on: boolean)
	local map = workspace:FindFirstChild("Map")
	local ground = map and map:FindFirstChild("Ground") :: BasePart?
	if not ground then
		return
	end
	if on then
		if not groundColor then
			groundColor, groundMaterial = ground.Color, ground.Material
		end
		ground.Color = SNOW_GROUND
		ground.Material = Enum.Material.Snow
	elseif groundColor then
		ground.Color = groundColor
		ground.Material = groundMaterial or Enum.Material.Grass
		groundColor, groundMaterial = nil, nil
	end
end

local function update()
	local winter = ReplicatedStorage:GetAttribute("EventWinter") == true
	local teaser = ReplicatedStorage:GetAttribute("WinterTeaser") == true
	setSnow(if winter then 90 elseif teaser then 15 else 0)
	setSnowyGround(winter)
	if winter and not toldWinter then
		toldWinter = true
		HUD.toast(Lang.t("WinterOn"), "info")
	elseif teaser and not toldTeaser then
		toldTeaser = true
		local startsAt = ReplicatedStorage:GetAttribute("WinterStartsAt") or 0
		local days = math.max(1, math.ceil((startsAt - workspace:GetServerTimeNow()) / 86400))
		HUD.toast(Lang.t("WinterSoon", { days = days }), "info")
	end
end

function WinterView.start()
	ReplicatedStorage:GetAttributeChangedSignal("EventWinter"):Connect(update)
	ReplicatedStorage:GetAttributeChangedSignal("WinterTeaser"):Connect(update)
	update()
	-- le nuage de neige suit la caméra
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if snowPart and camera then
			snowPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 35, 0))
		end
	end)
end

return WinterView
