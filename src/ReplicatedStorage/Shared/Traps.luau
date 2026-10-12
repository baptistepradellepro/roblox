--[[
	Traps : les pièges à poser dans sa base (partagé serveur + joueurs).
	Ils s'achètent avec des PIÈCES (jamais avec des Robux), une fois pour toutes,
	sur leur emplacement dans l'allée de la base (bouton E). Prix et réglages : Config.Traps.

	Ils ne touchent jamais le propriétaire de la base, seulement les intrus :
	  - Peau de banane : l'intrus glisse, reste étourdi et lâche le fantôme volé.
	    Elle met un moment à revenir après avoir servi.
	  - Toile d'araignée : l'intrus qui la traverse marche au ralenti quelques secondes.
	  - Alarme : sonne dès qu'un intrus entre dans la base, et le propriétaire est
	    prévenu même s'il est loin.

	Position = place dans la base (repère de la base : -Z = vers l'entrée, X = côtés).
]]

local Traps = {}

Traps.List = {
	{
		Id = "Banana",
		Icon = "🍌",
		Name = { fr = "Peau de banane", en = "Banana peel" },
		Desc = { fr = "Le voleur glisse, tombe et lâche le fantôme volé.", en = "The thief slips, falls and drops the stolen ghost." },
		Position = Vector3.new(0, 0, -3),
		Radius = 2.6, -- distance pour glisser
	},
	{
		Id = "Web",
		Icon = "🕸️",
		Name = { fr = "Toile d'araignée", en = "Spider web" },
		Desc = { fr = "Les intrus qui la traversent marchent au ralenti.", en = "Intruders who cross it walk in slow motion." },
		Position = Vector3.new(0, 0, 5),
		HalfSize = Vector2.new(6, 1.8), -- la toile couvre l'allée en largeur
	},
	{
		Id = "Alarm",
		Icon = "🚨",
		Name = { fr = "Alarme", en = "Alarm" },
		Desc = { fr = "Sonne dès qu'un intrus entre dans ta base, même si tu es loin.", en = "Rings as soon as an intruder enters your base, even if you are far away." },
		Position = Vector3.new(0, 0, 11.5),
	},
}

Traps.ById = {}
for order, trap in Traps.List do
	trap.Order = order
	Traps.ById[trap.Id] = trap
end

function Traps.get(id: any)
	return if type(id) == "string" then Traps.ById[id] else nil
end

---------------------------------------------------------------- Modèles 3D

local function part(model: Instance, shape: Enum.PartType?, size: Vector3, cf: CFrame, color: Color3, extra: { [string]: any }?)
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
	p.Name = "Look"
	if extra then
		local writable: any = p
		for key, value in extra do
			writable[key] = value
		end
	end
	p.Parent = model
	return p
end

local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- cylindre posé à plat

local Builders = {}

function Builders.Banana(model: Model, at: CFrame)
	local yellow = Color3.fromRGB(255, 220, 60)
	part(model, Enum.PartType.Cylinder, Vector3.new(0.35, 1.4, 1.4), at * CFrame.new(0, 0.18, 0) * FLAT, yellow)
	-- les trois bouts de peau étalés
	for i = 0, 2 do
		local angle = math.rad(i * 120 + 20)
		part(model, nil, Vector3.new(0.7, 0.18, 1.6), at * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.1, 1.1), yellow)
		part(model, nil, Vector3.new(0.4, 0.2, 0.3), at * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.12, 1.85), Color3.fromRGB(120, 80, 30))
	end
end

function Builders.Web(model: Model, at: CFrame)
	local white = Color3.fromRGB(245, 245, 255)
	-- fils qui traversent l'allée, et quelques cercles
	for i = -2, 2 do
		part(model, nil, Vector3.new(12, 0.06, 0.12), at * CFrame.new(0, 0.05, i * 0.8) * CFrame.Angles(0, math.rad(i * 6), 0), white, { Transparency = 0.15 })
	end
	for _, x in { -4.5, -1.5, 1.5, 4.5 } do
		part(model, nil, Vector3.new(0.12, 0.06, 3.6), at * CFrame.new(x, 0.06, 0), white, { Transparency = 0.15 })
	end
	part(model, Enum.PartType.Cylinder, Vector3.new(0.04, 3.4, 3.4), at * CFrame.new(0, 0.04, 0) * FLAT, white, { Transparency = 0.6 })
	-- une petite araignée au milieu
	part(model, Enum.PartType.Ball, Vector3.one * 0.7, at * CFrame.new(0.4, 0.3, 0.2), Color3.fromRGB(40, 30, 50))
end

function Builders.Alarm(model: Model, at: CFrame)
	part(model, Enum.PartType.Cylinder, Vector3.new(4.5, 0.35, 0.35), at * CFrame.new(0, 2.25, 0) * FLAT, Color3.fromRGB(80, 80, 95))
	part(model, Enum.PartType.Cylinder, Vector3.new(0.3, 1.6, 1.6), at * CFrame.new(0, 0.15, 0) * FLAT, Color3.fromRGB(60, 60, 70))
	local siren = part(model, Enum.PartType.Ball, Vector3.one * 1.3, at * CFrame.new(0, 4.9, 0), Color3.fromRGB(200, 40, 50), {
		Material = Enum.Material.Neon,
		Name = "Siren",
	})
	local light = Instance.new("PointLight")
	light.Name = "SirenLight"
	light.Color = Color3.fromRGB(255, 40, 40)
	light.Range = 24
	light.Brightness = 3
	light.Enabled = false
	light.Parent = siren
end

--[[
	Fabrique un piège à la position "at" (repère du monde) :
	  - "Spot" : l'emplacement d'achat (visible tant que le piège n'est pas acheté)
	  - les pièces "Look" : le piège lui-même (cachées tant qu'il n'est pas acheté)
]]
function Traps.build(id: string, at: CFrame): Model
	local trap = Traps.ById[id]
	local model = Instance.new("Model")
	model.Name = "Trap_" .. id
	model:SetAttribute("TrapId", id)
	local spot = part(model, Enum.PartType.Cylinder, Vector3.new(0.12, 3.6, 3.6), at * CFrame.new(0, 0.06, 0) * FLAT, Color3.fromRGB(150, 150, 165), {
		Name = "Spot",
		Transparency = 0.35,
		Material = Enum.Material.Neon,
	})
	model.PrimaryPart = spot
	local builder = Builders[trap.Id]
	if builder then
		builder(model, at)
	end
	return model
end

return Traps
