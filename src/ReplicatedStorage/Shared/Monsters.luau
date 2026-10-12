--[[
	Monsters : les monstres (partagé entre le serveur et les joueurs).
	  - Gloutrouille sort pendant la Nuit Hantée
	  - les joueurs peuvent aussi lâcher un monstre avec des Robux (Developer Product)

	Un monstre lâché avec des Robux :
	  - poursuit les joueurs qui sont HORS de leur base (il n'entre jamais dans les bases)
	  - ne touche pas celui qui l'a lâché
	  - attrapé : retour à la base et on lâche le fantôme volé, mais on ne perd PAS de pièces
	  - un seul à la fois par serveur : les suivants attendent leur tour

	Speed = vitesse, CatchRange = distance pour attraper, Duration = durée en secondes,
	Hover = hauteur au-dessus du sol. L'avant du modèle est en -Z.
]]

local Monsters = {}

Monsters.List = {
	{
		Id = "Gloutrouille",
		Icon = "🎃",
		Name = { fr = "Gloutrouille", en = "Gloutrouille" },
		Desc = { fr = "La citrouille en gelée qui a toujours faim.", en = "The jelly pumpkin who is always hungry." },
		Product = "MonsterGloutrouille",
		Speed = 15,
		CatchRange = 5,
		Duration = 40,
		Hover = 5,
		Color = { 255, 125, 25 },
	},
	{
		Id = "MamieToile",
		Icon = "🕷️",
		Name = { fr = "Mamie Toile", en = "Granny Web" },
		Desc = { fr = "Une araignée géante à lunettes. Elle lance sa toile de loin.", en = "A giant spider with glasses. She throws her web from far away." },
		Product = "MonsterSpider",
		Speed = 12,
		CatchRange = 9,
		Duration = 45,
		Hover = 4,
		Color = { 170, 90, 255 },
	},
	{
		Id = "ChauveSourisTurbo",
		Icon = "🦇",
		Name = { fr = "Chauve-Souris Turbo", en = "Turbo Bat" },
		Desc = { fr = "Petite, mais beaucoup trop rapide.", en = "Small, but way too fast." },
		Product = "MonsterBat",
		Speed = 20,
		CatchRange = 4,
		Duration = 30,
		Hover = 7,
		Color = { 90, 200, 255 },
	},
	-- Le monstre des nuits de l'Hiver Hanté (pas en vente)
	{
		Id = "BonhommeGrelot",
		Icon = "☃️",
		Name = { fr = "Bonhomme Grelot", en = "Shiverman" },
		Desc = { fr = "Le bonhomme de neige qui remplace Gloutrouille les nuits d'hiver.", en = "The snowman who replaces Gloutrouille on winter nights." },
		Speed = 14,
		CatchRange = 6,
		Duration = 120,
		Hover = 5,
		Color = { 170, 220, 255 },
	},
}

Monsters.ById = {}
for order, monster in Monsters.List do
	monster.Order = order
	Monsters.ById[monster.Id] = monster
end

function Monsters.get(id: any)
	return if type(id) == "string" then Monsters.ById[id] else nil
end

---------------------------------------------------------------- Modèles 3D

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

local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder
local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(25, 20, 30)

-- Un gros œil brillant avec pupille et reflet (regarde vers -Z)
local function eye(model: Model, pos: Vector3, d: number, iris: Color3?)
	part(model, BALL, Vector3.one * d, CFrame.new(pos), WHITE)
	local pupil = d * 0.55
	local pupilPos = pos + Vector3.new(0, -0.05 * d, -d * 0.32)
	part(model, BALL, Vector3.one * pupil, CFrame.new(pupilPos), iris or BLACK)
	part(model, BALL, Vector3.one * pupil * 0.35, CFrame.new(pupilPos + Vector3.new(0.12 * d, 0.12 * d, -pupil * 0.4)), WHITE)
end

local Builders = {}

-- Gloutrouille : une citrouille en gelée avec des dents en bonbons
function Builders.Gloutrouille(model: Model)
	local orange = Color3.fromRGB(255, 125, 25)
	local darker = orange:Lerp(Color3.new(0, 0, 0), 0.15)
	part(model, BALL, Vector3.one * 9, CFrame.identity, orange)
	-- côtes de citrouille
	for _, x in { -2.8, 2.8 } do
		part(model, BALL, Vector3.new(7.2, 8.6, 7.2), CFrame.new(x, 0, 0.5), darker)
	end
	part(model, BALL, Vector3.one * 10.3, CFrame.identity, Color3.fromRGB(170, 80, 255), {
		Transparency = 0.7,
		Material = Enum.Material.Glass,
	})
	-- yeux qui brillent, sourcils froncés
	local glow = Color3.fromRGB(190, 255, 80)
	for _, x in { -1.8, 1.8 } do
		part(model, nil, Vector3.new(1.7, 1.7, 0.6), CFrame.new(x, 1.4, -4.2) * CFrame.Angles(0, 0, math.rad(45)), glow, {
			Material = Enum.Material.Neon,
		})
		part(model, nil, Vector3.new(2, 0.4, 0.5), CFrame.new(x, 2.6, -4.05) * CFrame.Angles(0, 0, math.rad(x > 0 and 20 or -20)), BLACK)
	end
	-- grande bouche + dents en bonbons + langue
	part(model, nil, Vector3.new(5.6, 1.9, 0.6), CFrame.new(0, -1.4, -4.05), Color3.fromRGB(40, 10, 45))
	part(model, BALL, Vector3.new(2.2, 0.8, 1), CFrame.new(0.6, -2, -4.1), Color3.fromRGB(255, 90, 130))
	local candy = { Color3.fromRGB(255, 255, 240), Color3.fromRGB(255, 210, 60), Color3.fromRGB(255, 130, 30) }
	for i = 0, 4 do
		part(model, nil, Vector3.new(0.75, 0.85, 0.5), CFrame.new(-2.1 + i * 1.05, -0.75, -4.35), candy[i % 3 + 1])
	end
	-- tige, feuille et petits bras
	part(model, CYL, Vector3.new(2, 1, 1), CFrame.new(0, 5.2, 0) * CFrame.Angles(0, 0, math.rad(80)), Color3.fromRGB(70, 140, 40))
	part(model, BALL, Vector3.new(2.2, 0.4, 1.4), CFrame.new(1, 5.2, 0) * CFrame.Angles(0, 0, math.rad(-25)), Color3.fromRGB(90, 180, 60))
	for _, x in { -5, 5 } do
		part(model, BALL, Vector3.one * 2.4, CFrame.new(x, -1.5, -1), orange, { Name = "Arm" })
	end
end

-- Mamie Toile : une araignée violette avec un chignon blanc, de grands yeux et 8 pattes
function Builders.MamieToile(model: Model)
	local purple = Color3.fromRGB(120, 60, 170)
	local dark = Color3.fromRGB(70, 35, 100)
	part(model, BALL, Vector3.new(7, 6, 8), CFrame.new(0, 0.6, 2.6), dark) -- abdomen
	part(model, BALL, Vector3.one * 5.2, CFrame.new(0, 0.4, -1.6), purple) -- tête
	-- motif sur le dos
	part(model, BALL, Vector3.new(2.4, 1, 2.4), CFrame.new(0, 3.4, 2.8), Color3.fromRGB(255, 120, 200))
	-- chignon blanc de mamie
	part(model, BALL, Vector3.new(2.8, 1.8, 2.6), CFrame.new(0, 2.9, -1.2), Color3.fromRGB(245, 245, 250))
	part(model, BALL, Vector3.one * 1.5, CFrame.new(0, 3.8, -1.1), Color3.fromRGB(245, 245, 250))
	-- deux grands yeux de dessin animé
	for _, x in { -1.15, 1.15 } do
		eye(model, Vector3.new(x, 1, -3.6), 1.9, Color3.fromRGB(120, 70, 30))
	end
	-- petits yeux en plus (c'est une araignée !)
	for _, x in { -0.5, 0.5 } do
		part(model, BALL, Vector3.one * 0.5, CFrame.new(x, 2.1, -3.7), BLACK)
	end
	-- sourire avec deux dents de lapin
	part(model, nil, Vector3.new(1.6, 0.25, 0.3), CFrame.new(0, -0.6, -4.1), BLACK)
	for _, x in { -0.2, 0.2 } do
		part(model, nil, Vector3.new(0.36, 0.5, 0.25), CFrame.new(x, -0.9, -4.1), WHITE)
	end
	-- 8 pattes (4 de chaque côté)
	for side = -1, 1, 2 do
		for i = 0, 3 do
			local z = -1.8 + i * 1.6
			local upper = part(model, CYL, Vector3.new(4, 0.6, 0.6), CFrame.new(side * 3.6, 1.6, z) * CFrame.Angles(0, 0, math.rad(side * 30)), purple, { Name = "Leg" })
			upper:SetAttribute("Side", side)
			part(model, CYL, Vector3.new(4.4, 0.5, 0.5), CFrame.new(side * 6.4, -0.8, z) * CFrame.Angles(0, 0, math.rad(side * -60)), dark, { Name = "Leg" })
		end
	end
	-- un fil de toile au-dessus
	part(model, CYL, Vector3.new(14, 0.08, 0.08), CFrame.new(0, 9, 2.6) * CFrame.Angles(0, 0, math.rad(90)), WHITE, { Transparency = 0.3 })
end

-- Chauve-Souris Turbo : une petite boule bleue avec de grandes ailes et des lunettes d'aviateur
function Builders.ChauveSourisTurbo(model: Model)
	local blue = Color3.fromRGB(70, 90, 160)
	local wing = Color3.fromRGB(45, 55, 110)
	part(model, BALL, Vector3.one * 4.2, CFrame.identity, blue)
	part(model, BALL, Vector3.new(3, 2.2, 1), CFrame.new(0, -0.6, -1.8), Color3.fromRGB(140, 160, 230)) -- ventre
	-- oreilles pointues
	for _, x in { -1.1, 1.1 } do
		local ear = CFrame.new(x, 2.3, 0) * CFrame.Angles(0, 0, math.rad(x > 0 and -15 or 15))
		part(model, nil, Vector3.new(0.9, 1.8, 0.5), ear, blue)
		part(model, nil, Vector3.new(0.5, 1.2, 0.2), ear * CFrame.new(0, -0.1, -0.2), Color3.fromRGB(255, 140, 190))
	end
	-- lunettes d'aviateur
	part(model, nil, Vector3.new(4.4, 0.35, 0.35), CFrame.new(0, 0.7, -1.2), Color3.fromRGB(120, 70, 30))
	for _, x in { -0.85, 0.85 } do
		part(model, CYL, Vector3.new(0.3, 1.4, 1.4), CFrame.new(x, 0.7, -1.95) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(150, 230, 255), {
			Transparency = 0.25,
			Reflectance = 0.4,
		})
		part(model, BALL, Vector3.one * 0.55, CFrame.new(x, 0.65, -2.05), BLACK)
	end
	-- petits crocs
	for _, x in { -0.35, 0.35 } do
		part(model, nil, Vector3.new(0.25, 0.45, 0.25), CFrame.new(x, -0.55, -2.05), WHITE)
	end
	-- grandes ailes en trois morceaux
	for side = -1, 1, 2 do
		for i = 1, 3 do
			local wingPart = part(model, nil, Vector3.new(2.4, 0.25, 2.2 - i * 0.3), CFrame.new(side * (1.6 + i * 1.9), 0.4 + i * 0.15, 0.3) * CFrame.Angles(0, 0, math.rad(side * (8 + i * 6))), wing, { Name = "Wing" })
			wingPart:SetAttribute("Side", side)
		end
	end
	-- une traînée de vitesse
	part(model, nil, Vector3.new(0.3, 0.3, 4), CFrame.new(0, 0, 3.6), Color3.fromRGB(150, 220, 255), { Material = Enum.Material.Neon, Transparency = 0.4 })
end

-- Bonhomme Grelot : un bonhomme de neige grognon, nez carotte, chapeau et écharpe
function Builders.BonhommeGrelot(model: Model)
	local snow = Color3.fromRGB(245, 250, 255)
	part(model, BALL, Vector3.one * 7, CFrame.new(0, -2.6, 0), snow)
	part(model, BALL, Vector3.one * 5.2, CFrame.new(0, 2, 0), snow)
	part(model, BALL, Vector3.one * 3.8, CFrame.new(0, 5.6, 0), snow)
	-- écharpe rouge
	part(model, CYL, Vector3.new(0.9, 4.2, 4.2), CFrame.new(0, 4.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(220, 40, 60))
	part(model, nil, Vector3.new(0.9, 2.2, 0.3), CFrame.new(1.2, 3, -1.9) * CFrame.Angles(0, 0, math.rad(-10)), Color3.fromRGB(220, 40, 60))
	-- yeux de charbon, sourcils froncés, nez carotte
	for _, x in { -0.7, 0.7 } do
		part(model, BALL, Vector3.one * 0.6, CFrame.new(x, 6, -1.7), BLACK)
		part(model, nil, Vector3.new(0.9, 0.2, 0.2), CFrame.new(x, 6.6, -1.75) * CFrame.Angles(0, 0, math.rad(x > 0 and 20 or -20)), BLACK)
	end
	part(model, CYL, Vector3.new(1.8, 0.5, 0.5), CFrame.new(0, 5.6, -2.5) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 140, 30))
	-- boutons
	for _, y in { 2.8, 1.6, 0.4 } do
		part(model, BALL, Vector3.one * 0.5, CFrame.new(0, y, -2.5), BLACK)
	end
	-- chapeau haut-de-forme
	part(model, CYL, Vector3.new(0.3, 3.6, 3.6), CFrame.new(0, 7.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(30, 30, 35))
	part(model, CYL, Vector3.new(2.2, 2.4, 2.4), CFrame.new(0, 8.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(30, 30, 35))
	-- bras en branches
	for _, side in { -1, 1 } do
		part(model, CYL, Vector3.new(3.6, 0.35, 0.35), CFrame.new(side * 3.8, 2.6, 0) * CFrame.Angles(0, 0, math.rad(side * -25)), Color3.fromRGB(110, 70, 40), { Name = "Arm" })
	end
end

-- Fabrique le modèle d'un monstre (avec son nom au-dessus)
function Monsters.build(id: string): Model
	local monster = Monsters.ById[id] or Monsters.ById.Gloutrouille
	local model = Instance.new("Model")
	model.Name = monster.Id
	local root = part(model, nil, Vector3.one, CFrame.identity, WHITE, { Transparency = 1, Name = "Root" })
	model.PrimaryPart = root
	local builder = Builders[monster.Id] or Builders.Gloutrouille
	builder(model)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(monster.Color[1], monster.Color[2], monster.Color[3])
	light.Range = 22
	light.Brightness = 2
	light.Shadows = false
	light.Parent = root
	return model
end

return Monsters
