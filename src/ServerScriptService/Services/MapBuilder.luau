--[[
	MapBuilder : construit toute la map avec du code au démarrage du serveur.
	  - le sol, le chemin hanté au centre, les 2 portails
	  - 12 bases (6 de chaque côté du chemin) avec 12 socles chacune
	  - la déco Halloween (citrouilles, arbres morts, tombes, lanternes)
	  - l'ambiance (lumière, brume)

	Astuce : si tu veux modifier la map à la main dans Studio, lance le jeu, copie le
	dossier Workspace > Map, arrête le jeu et colle-le dans Workspace. Ce script
	verra qu'une map existe déjà et ne la reconstruira pas (garde bien les noms).
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MapBuilder = {}

MapBuilder.BASE_WIDTH = 36
MapBuilder.BASE_DEPTH = 32
MapBuilder.BASE_Z = 33
MapBuilder.WALL_HEIGHT = 12
MapBuilder.BASE_XS = { -110, -66, -22, 22, 66, 110 }
MapBuilder.FLOOR_Y = 0.6
MapBuilder.PEDESTAL_HEIGHT = 2

-- Couleur de chaque base
MapBuilder.BASE_COLORS = {
	Color3.fromRGB(170, 110, 255),
	Color3.fromRGB(255, 150, 50),
	Color3.fromRGB(90, 220, 120),
	Color3.fromRGB(70, 200, 255),
	Color3.fromRGB(255, 110, 180),
	Color3.fromRGB(255, 220, 70),
	Color3.fromRGB(255, 90, 90),
	Color3.fromRGB(90, 120, 255),
	Color3.fromRGB(170, 240, 70),
	Color3.fromRGB(60, 220, 200),
	Color3.fromRGB(230, 90, 255),
	Color3.fromRGB(255, 180, 140),
}

local ROT_UP = CFrame.Angles(0, 0, math.rad(90))

-- Positions des 12 socles dans une base (x, z). L'avant de la base (côté chemin) est en -Z.
MapBuilder.PEDESTAL_SPOTS = {}
for row, z in { -3, 4.5, 12 } do
	for col, x in { -12, -4, 4, 12 } do
		MapBuilder.PEDESTAL_SPOTS[(row - 1) * 4 + col] = Vector2.new(x, z)
	end
end

local function part(props: { [string]: any }): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local writable: any = p
	if props.Shape then
		writable.Shape = props.Shape -- la forme d'abord, la taille ensuite
	end
	for key, value in props do
		if key ~= "ClassName" and key ~= "Parent" and key ~= "Shape" then
			writable[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

-- Le repère d'une base : origine au centre du sol, -Z = vers le chemin
function MapBuilder.baseOrigin(index: number): CFrame
	local col = (index - 1) % 6 + 1
	local x = MapBuilder.BASE_XS[col]
	if index <= 6 then
		return CFrame.new(x, MapBuilder.FLOOR_Y, MapBuilder.BASE_Z)
	end
	return CFrame.new(x, MapBuilder.FLOOR_Y, -MapBuilder.BASE_Z) * CFrame.Angles(0, math.pi, 0)
end

local function wallSegment(parent: Instance, origin: CFrame, center: Vector3, size: Vector3, color: Color3)
	-- bas plein (3 studs) + haut en "verre fantôme" pour voir les fantômes à l'intérieur
	local lowH = 3
	local highH = MapBuilder.WALL_HEIGHT - lowH
	part({
		Name = "Wall",
		Size = Vector3.new(size.X, lowH, size.Z),
		CFrame = origin * CFrame.new(center.X, lowH / 2, center.Z),
		Color = color:Lerp(Color3.new(0, 0, 0), 0.35),
		Material = Enum.Material.Brick,
		Parent = parent,
	})
	part({
		Name = "Glass",
		Size = Vector3.new(size.X, highH, size.Z),
		CFrame = origin * CFrame.new(center.X, lowH + highH / 2, center.Z),
		Color = color,
		Material = Enum.Material.Glass,
		Transparency = 0.75,
		CastShadow = false,
		Parent = parent,
	})
end

function MapBuilder.buildBase(index: number, parent: Instance): Model
	local origin = MapBuilder.baseOrigin(index)
	local color = MapBuilder.BASE_COLORS[index]
	local w, d = MapBuilder.BASE_WIDTH, MapBuilder.BASE_DEPTH

	local model = Instance.new("Model")
	model.Name = "Base_" .. index

	local floor = part({
		Name = "Floor",
		Size = Vector3.new(w, 0.6, d),
		CFrame = origin * CFrame.new(0, -0.3, 0),
		Color = Color3.fromRGB(70, 55, 80),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	model.PrimaryPart = floor

	-- Murs (avec une entrée de 10 studs à l'avant)
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = model
	wallSegment(walls, origin, Vector3.new(0, 0, d / 2), Vector3.new(w, 0, 1), color)
	wallSegment(walls, origin, Vector3.new(-w / 2, 0, 0), Vector3.new(1, 0, d), color)
	wallSegment(walls, origin, Vector3.new(w / 2, 0, 0), Vector3.new(1, 0, d), color)
	wallSegment(walls, origin, Vector3.new(-11.5, 0, -d / 2), Vector3.new(13, 0, 1), color)
	wallSegment(walls, origin, Vector3.new(11.5, 0, -d / 2), Vector3.new(13, 0, 1), color)

	-- Portique d'entrée + panneau avec le nom du propriétaire
	for _, x in { -5.5, 5.5 } do
		part({
			Name = "Post",
			Size = Vector3.new(1.2, 15, 1.2),
			CFrame = origin * CFrame.new(x, 7.5, -d / 2),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
	end
	part({
		Name = "Sign",
		Size = Vector3.new(14, 3.2, 0.8),
		CFrame = origin * CFrame.new(0, 14.2, -d / 2),
		Color = Color3.fromRGB(35, 25, 45),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})

	-- Tapis d'entrée (zone de dépôt des fantômes volés)
	part({
		Name = "Mat",
		Size = Vector3.new(9, 0.1, 6),
		CFrame = origin * CFrame.new(0, 0.05, -11.5),
		Color = color,
		Material = Enum.Material.Fabric,
		CanCollide = false,
		CastShadow = false,
		Parent = model,
	})

	-- Point d'apparition du propriétaire
	local spawn = part({
		ClassName = "SpawnLocation",
		Name = "Spawn",
		Size = Vector3.new(6, 0.2, 6),
		CFrame = origin * CFrame.new(0, 0.1, -8),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
		Neutral = true,
		Duration = 0,
		Enabled = true,
		Parent = model,
	})
	spawn:SetAttribute("BaseSpawn", true)

	-- Bouton de verrouillage
	local lockButton = part({
		Name = "LockButton",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 4, 4),
		CFrame = origin * CFrame.new(12, 0.4, -11) * ROT_UP,
		Color = Color3.fromRGB(255, 70, 90),
		Material = Enum.Material.Neon,
		CastShadow = false,
		Parent = model,
	})
	lockButton:SetAttribute("BaseIndex", index)

	-- Socles
	local pedestals = Instance.new("Folder")
	pedestals.Name = "Pedestals"
	pedestals.Parent = model
	for slot, spot in MapBuilder.PEDESTAL_SPOTS do
		local top = origin * CFrame.new(spot.X, MapBuilder.PEDESTAL_HEIGHT, spot.Y)
		local ped = part({
			Name = "P" .. slot,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(MapBuilder.PEDESTAL_HEIGHT, 5, 5),
			CFrame = origin * CFrame.new(spot.X, MapBuilder.PEDESTAL_HEIGHT / 2, spot.Y) * ROT_UP,
			Color = Color3.fromRGB(60, 50, 75),
			Material = Enum.Material.Slate,
			Parent = pedestals,
		})
		part({
			Name = "Rim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15, 5.3, 5.3),
			CFrame = top * ROT_UP,
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
			Parent = ped,
		})
		ped:SetAttribute("Slot", slot)
		ped:SetAttribute("BaseIndex", index)
		ped:SetAttribute("GhostCFrame", top)
		ped:SetAttribute("GhostId", "")
		ped:SetAttribute("Stolen", false)
		ped:SetAttribute("Unlocked", false)
	end

	model:SetAttribute("Index", index)
	model:SetAttribute("Origin", origin)
	model:SetAttribute("Color", color)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")
	model:SetAttribute("LockedUntil", 0)
	model:SetAttribute("LockReadyAt", 0)
	model.Parent = parent
	return model
end

local function pumpkin(parent: Instance, pos: Vector3, size: number)
	part({
		Name = "Pumpkin",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		CFrame = CFrame.new(pos + Vector3.new(0, size * 0.4, 0)),
		Color = Color3.fromRGB(255, 130, 20),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	part({
		Name = "Stem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(size * 0.3, size * 0.18, size * 0.18),
		CFrame = CFrame.new(pos + Vector3.new(0, size * 0.95, 0)) * ROT_UP,
		Color = Color3.fromRGB(70, 130, 40),
		CastShadow = false,
		Parent = parent,
	})
end

local function deadTree(parent: Instance, pos: Vector3, rng: Random)
	local h = rng:NextNumber(10, 16)
	local bark = Color3.fromRGB(60, 45, 40)
	part({
		Name = "Trunk",
		Size = Vector3.new(1.6, h, 1.6),
		CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
		Color = bark,
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	for i = 1, 3 do
		local y = h * (0.5 + i * 0.13)
		local angle = rng:NextNumber(0, math.pi * 2)
		local len = rng:NextNumber(3, 6)
		part({
			Name = "Branch",
			Size = Vector3.new(len, 0.7, 0.7),
			CFrame = CFrame.new(pos + Vector3.new(0, y, 0))
				* CFrame.Angles(0, angle, math.rad(rng:NextNumber(20, 45)))
				* CFrame.new(len / 2, 0, 0),
			Color = bark,
			Material = Enum.Material.Wood,
			CastShadow = false,
			Parent = parent,
		})
	end
end

local function grave(parent: Instance, pos: Vector3, rng: Random)
	part({
		Name = "Grave",
		Size = Vector3.new(3, 4, 0.8),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.8, 0)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), math.rad(rng:NextNumber(-8, 8))),
		Color = Color3.fromRGB(120, 120, 135),
		Material = Enum.Material.Slate,
		Parent = parent,
	})
end

local function lantern(parent: Instance, pos: Vector3, withLight: boolean)
	part({
		Name = "LanternPost",
		Size = Vector3.new(0.6, 7, 0.6),
		CFrame = CFrame.new(pos + Vector3.new(0, 3.5, 0)),
		Color = Color3.fromRGB(40, 35, 45),
		Material = Enum.Material.Metal,
		CastShadow = false,
		Parent = parent,
	})
	local head = part({
		Name = "Lantern",
		Size = Vector3.new(1.4, 1.6, 1.4),
		CFrame = CFrame.new(pos + Vector3.new(0, 7.6, 0)),
		Color = Color3.fromRGB(255, 190, 80),
		Material = Enum.Material.Neon,
		CastShadow = false,
		Parent = parent,
	})
	if withLight then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 170, 80)
		light.Range = 18
		light.Brightness = 1.5
		light.Shadows = false
		light.Parent = head
	end
end

local function portal(parent: Instance, x: number, color: Color3)
	local z = Config.PathZ
	for _, dz in { -7, 7 } do
		part({
			Name = "PortalPillar",
			Size = Vector3.new(2, 14, 2),
			CFrame = CFrame.new(x, 7, z + dz),
			Color = Color3.fromRGB(45, 35, 60),
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
	part({
		Name = "PortalTop",
		Size = Vector3.new(2.4, 2, 16),
		CFrame = CFrame.new(x, 14.5, z),
		Color = Color3.fromRGB(45, 35, 60),
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	local swirl = part({
		Name = "PortalSwirl",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 12, 12),
		CFrame = CFrame.new(x, 7, z),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		CastShadow = false,
		Parent = parent,
	})
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.Size = NumberSequence.new(0.6, 0)
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 10
	e.Lifetime = NumberRange.new(1, 1.5)
	e.LightEmission = 1
	e.Parent = swirl
end

function MapBuilder.setupLighting()
	Lighting.ClockTime = 18.3
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(70, 60, 95)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 105, 150)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(200, 170, 225)
	atmosphere.Decay = Color3.fromRGB(110, 90, 145)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	local cc = Lighting:FindFirstChild("SAG_ColorCorrection") :: ColorCorrectionEffect?
	if not cc then
		local newCc = Instance.new("ColorCorrectionEffect")
		newCc.Name = "SAG_ColorCorrection"
		newCc.Parent = Lighting
		cc = newCc
	end
	local colorCorrection = cc :: ColorCorrectionEffect
	colorCorrection.Saturation = 0.15
	colorCorrection.Contrast = 0.05
	colorCorrection.TintColor = Color3.new(1, 1, 1)
end

function MapBuilder.build(): Model
	MapBuilder.setupLighting()

	local existing = workspace:FindFirstChild("Map")
	if existing and existing:FindFirstChild("Bases") then
		return existing :: Model
	end

	local map = Instance.new("Model")
	map.Name = "Map"
	local rng = Random.new(31102026)

	-- Sol
	part({
		Name = "Ground",
		Size = Vector3.new(380, 2, 180),
		CFrame = CFrame.new(0, -1, 0),
		Color = Color3.fromRGB(62, 82, 58),
		Material = Enum.Material.Grass,
		Parent = map,
	})

	-- Chemin hanté
	local pathLength = Config.PathEndX - Config.PathStartX + 20
	part({
		Name = "Path",
		Size = Vector3.new(pathLength, 0.3, 14),
		CFrame = CFrame.new((Config.PathStartX + Config.PathEndX) / 2, 0.15, Config.PathZ),
		Color = Color3.fromRGB(95, 85, 115),
		Material = Enum.Material.Cobblestone,
		Parent = map,
	})
	part({
		Name = "PathGlow",
		Size = Vector3.new(pathLength, 0.05, 1),
		CFrame = CFrame.new((Config.PathStartX + Config.PathEndX) / 2, 0.32, Config.PathZ),
		Color = Color3.fromRGB(160, 90, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
		Parent = map,
	})

	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = map

	-- Petites bougies le long du chemin
	for x = Config.PathStartX + 10, Config.PathEndX - 10, 20 do
		for _, z in { -7.6, 7.6 } do
			part({
				Name = "Candle",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.4, 0.8, 0.8),
				CFrame = CFrame.new(x, 0.7, Config.PathZ + z) * ROT_UP,
				Color = Color3.fromRGB(245, 235, 210),
				CastShadow = false,
				Parent = decor,
			})
			part({
				Name = "CandleFlame",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.5,
				CFrame = CFrame.new(x, 1.6, Config.PathZ + z),
				Color = Color3.fromRGB(255, 170, 60),
				Material = Enum.Material.Neon,
				CanCollide = false,
				CastShadow = false,
				Parent = decor,
			})
		end
	end

	-- Grand écran du classement, suspendu au-dessus du milieu du chemin
	for _, z in { -8.6, 8.6 } do
		part({
			Name = "BoardPost",
			Size = Vector3.new(1.4, 32, 1.4),
			CFrame = CFrame.new(0, 16, Config.PathZ + z),
			Color = Color3.fromRGB(45, 35, 60),
			Material = Enum.Material.Metal,
			Parent = decor,
		})
	end
	part({
		Name = "Leaderboard",
		Size = Vector3.new(30, 15, 1),
		CFrame = CFrame.new(0, 27, Config.PathZ),
		Color = Color3.fromRGB(25, 15, 40),
		Material = Enum.Material.SmoothPlastic,
		CastShadow = false,
		Parent = map,
	})

	portal(decor, Config.PathStartX - 5, Color3.fromRGB(150, 80, 255))
	portal(decor, Config.PathEndX + 5, Color3.fromRGB(80, 255, 170))

	-- Lanternes (seulement quelques vraies lumières : c'est meilleur pour les mobiles)
	for i, x in { -132, -88, -44, 0, 44, 88, 132 } do
		lantern(decor, Vector3.new(x, 0, 11), i % 2 == 1)
		lantern(decor, Vector3.new(x, 0, -11), i % 2 == 0)
	end

	-- Citrouilles, arbres morts et tombes autour de la map
	for _ = 1, 26 do
		local x = rng:NextNumber(-180, 180)
		local z = (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(55, 85)
		pumpkin(decor, Vector3.new(x, 0, z), rng:NextNumber(2, 5))
	end
	for _ = 1, 10 do
		local x = rng:NextNumber(-175, 175)
		local z = (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(60, 85)
		deadTree(decor, Vector3.new(x, 0, z), rng)
	end
	for _, x in { -168, -162, -172, 162, 168, 172 } do
		for _, z in { -20, -12, 12, 20 } do
			grave(decor, Vector3.new(x + rng:NextNumber(-2, 2), 0, z + rng:NextNumber(-2, 2)), rng)
		end
	end

	-- Murs invisibles autour de la map
	for _, info in {
		{ Vector3.new(0, 30, 91), Vector3.new(384, 60, 2) },
		{ Vector3.new(0, 30, -91), Vector3.new(384, 60, 2) },
		{ Vector3.new(191, 30, 0), Vector3.new(2, 60, 184) },
		{ Vector3.new(-191, 30, 0), Vector3.new(2, 60, 184) },
	} do
		part({
			Name = "Boundary",
			Size = info[2],
			CFrame = CFrame.new(info[1]),
			Transparency = 1,
			CastShadow = false,
			Parent = map,
		})
	end

	-- Point d'apparition neutre (au cas où)
	part({
		ClassName = "SpawnLocation",
		Name = "LobbySpawn",
		Size = Vector3.new(6, 0.2, 6),
		CFrame = CFrame.new(0, 0.4, Config.PathZ),
		Transparency = 1,
		CanCollide = false,
		Neutral = true,
		Duration = 0,
		Parent = map,
	})

	-- Les 12 bases
	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	bases.Parent = map
	for index = 1, Config.BaseCount do
		MapBuilder.buildBase(index, bases)
	end

	map.Parent = workspace
	return map
end

return MapBuilder
