--[[
	Wheel : la Roue de la Fortune au milieu de la map (partagé serveur + joueurs).
	Les tours s'achètent avec des Robux (Developer Products "Spin1" et "Spin5").

	Règles Roblox sur les objets aléatoires payants, respectées ici :
	  - les chances de chaque case sont affichées en % AVANT l'achat, et font 100 % au total
	  - chaque case donne quelque chose (on ne perd jamais son achat)
	  - les joueurs des pays où c'est interdit ne peuvent pas acheter de tours
	    (PolicyService.ArePaidRandomItemsRestricted, vérifié par le serveur)

	Kind = "Coins" (Minutes de revenus, au moins Min pièces), "Boost" (revenus multipliés
	par Config.WheelBoostMult pendant Seconds), "Ghost" (un fantôme au hasard de cette rareté, avec Mutation possible).
	Chance = pourcentage. Si la base est pleine, un fantôme gagné est payé en pièces.
]]

local Wheel = {}

Wheel.Segments = {
	{ Id = "Coins10", Kind = "Coins", Minutes = 10, Min = 500, Chance = 30, Icon = "🪙", Color = { 255, 200, 60 } },
	{ Id = "Epic", Kind = "Ghost", Rarity = "Epic", Chance = 14, Icon = "👻", Color = { 175, 90, 255 } },
	{ Id = "Coins30", Kind = "Coins", Minutes = 30, Min = 1500, Chance = 18, Icon = "💰", Color = { 90, 210, 110 } },
	{ Id = "Legendary", Kind = "Ghost", Rarity = "Legendary", Chance = 8, Icon = "🌟", Color = { 255, 170, 30 } },
	{ Id = "Boost", Kind = "Boost", Seconds = 900, Chance = 15, Icon = "⚡", Color = { 70, 170, 255 } },
	{ Id = "GoldEpic", Kind = "Ghost", Rarity = "Epic", Mutation = "Gold", Chance = 6, Icon = "✨", Color = { 255, 225, 90 } },
	{ Id = "Coins120", Kind = "Coins", Minutes = 120, Min = 5000, Chance = 7, Icon = "🤑", Color = { 60, 200, 200 } },
	{ Id = "Mythic", Kind = "Ghost", Rarity = "Mythic", Chance = 2, Icon = "💎", Color = { 255, 60, 130 } },
}

Wheel.SpinDuration = 6 -- secondes d'animation
Wheel.Radius = 8

function Wheel.totalChance(): number
	local total = 0
	for _, segment in Wheel.Segments do
		total += segment.Chance
	end
	return total
end

-- roll = nombre entre 0 et 1 -> index de la case gagnante
function Wheel.pick(roll: number): number
	local target = roll * Wheel.totalChance()
	local acc = 0
	for index, segment in Wheel.Segments do
		acc += segment.Chance
		if target < acc then
			return index
		end
	end
	return #Wheel.Segments
end

-- Angle du centre d'une case (0 = en haut, sens inverse des aiguilles)
function Wheel.segmentAngle(index: number): number
	return (index - 1) * (2 * math.pi / #Wheel.Segments)
end

-- Pièces gagnées sur une case "Coins"
function Wheel.coins(segment, incomePerSecond: number): number
	return math.max(segment.Min or 0, math.floor(incomePerSecond * 60 * (segment.Minutes or 0)))
end

---------------------------------------------------------------- Modèle 3D

local function part(model: Model, class: string, size: Vector3, cf: CFrame, color: Color3, extra: { [string]: any }?)
	local p = Instance.new(class) :: BasePart
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

-- Un triangle rectangle plat (dans le plan XY de la roue), fait avec une WedgePart :
-- angle droit en m, la pointe en o, le troisième coin en q. thickness = épaisseur.
local function triangle(model: Model, o: Vector3, m: Vector3, q: Vector3, z: number, thickness: number, color: Color3)
	local height = (o - m).Magnitude
	local width = (q - m).Magnitude
	local yAxis = (o - m).Unit
	local zAxis = (m - q).Unit
	local xAxis = yAxis:Cross(zAxis)
	local center = m + yAxis * (height / 2) - zAxis * (width / 2) + Vector3.new(0, 0, z)
	local cf = CFrame.fromMatrix(center, xAxis, yAxis, zAxis)
	return part(model, "WedgePart", Vector3.new(thickness, height, width), cf, color)
end

--[[
	Construit la roue (sans le support). Le centre est en (0, 0, 0), la face avant
	regarde vers -Z, la case 1 est en haut. On la fait tourner autour de l'axe Z.
	labelMaker(segment, part) peut ajouter un texte sur chaque case.
]]
function Wheel.build(labelMaker: ((any, BasePart) -> ())?): Model
	local model = Instance.new("Model")
	model.Name = "FortuneWheel"
	local root = part(model, "Part", Vector3.one, CFrame.identity, Color3.new(1, 1, 1), { Transparency = 1, Name = "Root" })
	model.PrimaryPart = root

	local r = Wheel.Radius
	local count = #Wheel.Segments
	local half = math.pi / count
	-- le cadre en bois de la roue
	part(model, "Part", Vector3.new(0.8, r * 2 + 1.6, r * 2 + 1.6), CFrame.new(0, 0, 0.5) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(140, 85, 45), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Wood,
	})
	for index, segment in Wheel.Segments do
		local c = Wheel.segmentAngle(index)
		local color = Color3.fromRGB(segment.Color[1], segment.Color[2], segment.Color[3])
		local function at(angle: number, radius: number): Vector3
			return Vector3.new(-math.sin(angle) * radius, math.cos(angle) * radius, 0)
		end
		local mid = at(c, r * math.cos(half))
		local p0 = at(c - half, r)
		local p1 = at(c + half, r)
		triangle(model, Vector3.zero, mid, p0, -0.2, 0.3, color)
		triangle(model, Vector3.zero, mid, p1, -0.2, 0.3, color)
		-- un trait blanc entre les cases
		local edge = at(c - half, r / 2)
		part(model, "Part", Vector3.new(0.25, r, 0.35), CFrame.new(edge.X, edge.Y, -0.25) * CFrame.Angles(0, 0, c - half), Color3.fromRGB(255, 255, 255))
		-- support invisible du texte
		local labelPos = at(c, r * 0.64)
		local holder = part(model, "Part", Vector3.one * 0.2, CFrame.new(labelPos.X, labelPos.Y, -0.6), Color3.new(1, 1, 1), {
			Transparency = 1,
			Name = "Label_" .. index,
		})
		holder:SetAttribute("Segment", index)
		if labelMaker then
			labelMaker(segment, holder)
		end
	end
	-- ampoules sur le bord
	for i = 0, count * 2 - 1 do
		local a = i * half
		part(model, "Part", Vector3.one * 0.7, CFrame.new(-math.sin(a) * (r + 0.1), math.cos(a) * (r + 0.1), -0.3), Color3.fromRGB(255, 240, 150), {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Neon,
			Name = "Bulb",
		})
	end
	-- moyeu
	part(model, "Part", Vector3.new(0.8, 2.6, 2.6), CFrame.new(0, 0, -0.5) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 200, 40), {
		Shape = Enum.PartType.Cylinder,
		Reflectance = 0.2,
	})
	part(model, "Part", Vector3.one * 1.2, CFrame.new(0, 0, -0.9), Color3.fromRGB(255, 90, 160), { Shape = Enum.PartType.Ball })
	return model
end

return Wheel
