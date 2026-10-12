--[[
	MapBuilder : construit toute la map avec du code au démarrage du serveur.
	  - le sol, le chemin hanté au centre, les 2 portails
	  - au milieu : la Roue de la Fortune (côté nord) et la Boutique (côté sud)
	  - 12 bases (6 de chaque côté du chemin) avec 10 socles par étage
	  - la déco Halloween (citrouilles, arbres morts, tombes, lanternes)
	  - l'ambiance (lumière, brume)

	Astuce : si tu veux modifier la map à la main dans Studio, lance le jeu, copie le
	dossier Workspace > Map, arrête le jeu et colle-le dans Workspace. Ce script
	verra qu'une map existe déjà et ne la reconstruira pas (garde bien les noms).
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Traps = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Traps"))

local MapBuilder = {}

MapBuilder.BASE_WIDTH = 36
MapBuilder.BASE_DEPTH = 40
MapBuilder.BASE_Z = 37
MapBuilder.WALL_HEIGHT = 12
MapBuilder.FLOOR2_Y = 14 -- hauteur du sol de l'étage 2
MapBuilder.FLOOR2_WALL = 10
MapBuilder.BASE_XS = { -120, -76, -32, 32, 76, 120 } -- un espace au milieu pour la roue et la boutique
MapBuilder.FLOOR_Y = 0.6
MapBuilder.PEDESTAL_HEIGHT = 2
MapBuilder.PER_FLOOR = 10

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

-- Positions des socles dans une base : 5 à gauche, 5 à droite, une allée au milieu.
-- L'avant de la base (côté chemin) est en -Z. Socles 1-10 au rez-de-chaussée, 11-20 à l'étage.
-- Side = -1 (gauche) ou 1 (droite) : le fantôme regarde vers l'allée.
MapBuilder.PEDESTAL_SPOTS = {}
MapBuilder.ROW_Z = { -8, -2, 4, 10, 16 }
for floor = 1, 2 do
	for sideIndex, side in { -1, 1 } do
		for row, z in MapBuilder.ROW_Z do
			local slot = (floor - 1) * MapBuilder.PER_FLOOR + (sideIndex - 1) * 5 + row
			MapBuilder.PEDESTAL_SPOTS[slot] = { X = side * 13, Z = z, Side = side, Floor = floor }
		end
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

-- Pièces de l'étage 2 : cachées tant que le joueur ne l'a pas acheté.
-- On retient leur apparence normale pour pouvoir les réafficher.
local function hideUntilBought(p: BasePart)
	p:SetAttribute("BaseTransparency", p.Transparency)
	p:SetAttribute("BaseCollide", p.CanCollide)
	p:SetAttribute("BaseTouch", p.CanTouch)
	p.Transparency = 1
	p.CanCollide = false
	p.CanTouch = false
	p:SetAttribute("Floor", 2)
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

local function wallSegment(parent: Instance, origin: CFrame, center: Vector3, size: Vector3, color: Color3, baseY: number?, glassOnly: boolean?)
	-- bas plein (3 studs) + haut en "verre fantôme" pour voir les fantômes à l'intérieur
	local y0 = baseY or 0
	local lowH = if glassOnly then 0 else 3
	local highH = (if glassOnly then MapBuilder.FLOOR2_WALL else MapBuilder.WALL_HEIGHT) - lowH
	local made = {}
	if lowH > 0 then
		table.insert(made, part({
			Name = "Wall",
			Size = Vector3.new(size.X, lowH, size.Z),
			CFrame = origin * CFrame.new(center.X, y0 + lowH / 2, center.Z),
			Color = color:Lerp(Color3.new(0, 0, 0), 0.35),
			Material = Enum.Material.Brick,
			Parent = parent,
		}))
	end
	table.insert(made, part({
		Name = "Glass",
		Size = Vector3.new(size.X, highH, size.Z),
		CFrame = origin * CFrame.new(center.X, y0 + lowH + highH / 2, center.Z),
		Color = color,
		Material = Enum.Material.Glass,
		Transparency = 0.75,
		CastShadow = false,
		Parent = parent,
	}))
	return made
end

-- Un socle + sa plaque de récolte (devant, côté allée)
local function buildPedestal(parent: Instance, origin: CFrame, index: number, slot: number, color: Color3)
	local spot = MapBuilder.PEDESTAL_SPOTS[slot]
	local floorY = if spot.Floor == 2 then MapBuilder.FLOOR2_Y else 0
	-- le fantôme regarde vers l'allée (vers +X à gauche, vers -X à droite)
	local facing = CFrame.Angles(0, spot.Side * math.pi / 2, 0)
	local top = origin * CFrame.new(spot.X, floorY + MapBuilder.PEDESTAL_HEIGHT, spot.Z) * facing
	local ped = part({
		Name = "P" .. slot,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(MapBuilder.PEDESTAL_HEIGHT, 5, 5),
		CFrame = origin * CFrame.new(spot.X, floorY + MapBuilder.PEDESTAL_HEIGHT / 2, spot.Z) * ROT_UP,
		Color = Color3.fromRGB(60, 50, 75),
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	local rim = part({
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, 5.3, 5.3),
		CFrame = origin * CFrame.new(spot.X, floorY + MapBuilder.PEDESTAL_HEIGHT, spot.Z) * ROT_UP,
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
		Parent = ped,
	})
	local pad = part({
		Name = "CollectPad",
		Size = Vector3.new(3.4, 0.3, 4.4),
		CFrame = origin * CFrame.new(spot.X - spot.Side * 4.8, floorY + 0.15, spot.Z),
		Color = Color3.fromRGB(80, 230, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanTouch = true,
		CastShadow = false,
		Parent = ped,
	})
	ped:SetAttribute("Slot", slot)
	ped:SetAttribute("BaseIndex", index)
	ped:SetAttribute("GhostCFrame", top)
	ped:SetAttribute("GhostId", "")
	ped:SetAttribute("Stolen", false)
	ped:SetAttribute("Unlocked", false)
	ped:SetAttribute("Stored", 0)
	ped:SetAttribute("Floor", spot.Floor)
	if spot.Floor == 2 then
		hideUntilBought(ped)
		hideUntilBought(rim)
		hideUntilBought(pad)
	end
	return ped
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

	-- Allée centrale (on y court entre les deux rangées de socles)
	part({
		Name = "Aisle",
		Size = Vector3.new(9, 0.05, d - 2),
		CFrame = origin * CFrame.new(0, 0.03, 0),
		Color = color:Lerp(Color3.new(0, 0, 0), 0.55),
		Material = Enum.Material.Fabric,
		CanCollide = false,
		CastShadow = false,
		Parent = model,
	})

	-- Murs du rez-de-chaussée (avec une entrée de 10 studs à l'avant)
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
			Size = Vector3.new(1.2, 17, 1.2),
			CFrame = origin * CFrame.new(x, 8.5, -d / 2),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
	end
	part({
		Name = "Sign",
		Size = Vector3.new(14, 3.2, 0.8),
		CFrame = origin * CFrame.new(0, 16.4, -d / 2 - 0.6),
		Color = Color3.fromRGB(35, 25, 45),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})

	-- Tapis d'entrée (zone de dépôt des fantômes volés)
	part({
		Name = "Mat",
		Size = Vector3.new(9, 0.1, 5),
		CFrame = origin * CFrame.new(0, 0.06, -d / 2 + 4),
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
		CFrame = origin * CFrame.new(0, 0.1, -d / 2 + 9),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
		Neutral = true,
		Duration = 0,
		Enabled = true,
		Parent = model,
	})
	spawn:SetAttribute("BaseSpawn", true)

	-- Au fond : le poste de verrouillage (gros bouton + petite barrière rouge et blanche)
	local lockButton = part({
		Name = "LockButton",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 4, 4),
		CFrame = origin * CFrame.new(-3.2, 0.4, d / 2 - 4) * ROT_UP,
		Color = Color3.fromRGB(255, 70, 90),
		Material = Enum.Material.Neon,
		CastShadow = false,
		Parent = model,
	})
	lockButton:SetAttribute("BaseIndex", index)
	local lockStation = Instance.new("Folder")
	lockStation.Name = "LockStation"
	lockStation.Parent = model
	for _, x in { -6, -0.4 } do
		part({
			Name = "BarrierPost",
			Size = Vector3.new(0.6, 3.2, 0.6),
			CFrame = origin * CFrame.new(x, 1.6, d / 2 - 1.8),
			Color = Color3.fromRGB(240, 240, 240),
			Parent = lockStation,
		})
	end
	for i = 0, 3 do
		part({
			Name = "BarrierStripe",
			Size = Vector3.new(1.4, 0.6, 0.4),
			CFrame = origin * CFrame.new(-5.3 + i * 1.4, 2.7, d / 2 - 1.8),
			Color = if i % 2 == 0 then Color3.fromRGB(230, 40, 50) else Color3.fromRGB(250, 250, 250),
			Material = if i % 2 == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			CastShadow = false,
			Parent = lockStation,
		})
	end

	-- Les pièges dans l'allée : on voit l'emplacement d'achat, le piège apparaît une fois acheté
	local trapsFolder = Instance.new("Folder")
	trapsFolder.Name = "Traps"
	trapsFolder.Parent = model
	for _, trap in Traps.List do
		local trapModel = Traps.build(trap.Id, origin * CFrame.new(trap.Position))
		for _, p in trapModel:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "Spot" then
				p:SetAttribute("TrapLook", true)
				p:SetAttribute("BaseTransparency", p.Transparency)
				p.Transparency = 1
			end
		end
		trapModel.Parent = trapsFolder
	end

	-- Ascenseur vers l'étage 2 (au fond, à droite du bouton de verrou)
	part({
		Name = "UpPad",
		Size = Vector3.new(5, 0.3, 5),
		CFrame = origin * CFrame.new(3.2, 0.15, d / 2 - 4),
		Color = Color3.fromRGB(150, 90, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanTouch = true,
		CastShadow = false,
		Parent = model,
	})

	-- Étage 2 (caché tant qu'il n'est pas acheté)
	local floor2 = Instance.new("Folder")
	floor2.Name = "Floor2"
	floor2.Parent = model
	local y2 = MapBuilder.FLOOR2_Y
	local platform = part({
		Name = "Floor2Platform",
		Size = Vector3.new(w, 1, d),
		CFrame = origin * CFrame.new(0, y2 - 0.5, 0),
		Color = Color3.fromRGB(70, 55, 80),
		Material = Enum.Material.WoodPlanks,
		Parent = floor2,
	})
	hideUntilBought(platform)
	local upperWalls = {}
	for _, info in {
		{ Vector3.new(0, 0, d / 2), Vector3.new(w, 0, 1) },
		{ Vector3.new(0, 0, -d / 2), Vector3.new(w, 0, 1) },
		{ Vector3.new(-w / 2, 0, 0), Vector3.new(1, 0, d) },
		{ Vector3.new(w / 2, 0, 0), Vector3.new(1, 0, d) },
	} do
		for _, p in wallSegment(floor2, origin, info[1], info[2], color, y2, true) do
			table.insert(upperWalls, p)
		end
	end
	for _, p in upperWalls do
		hideUntilBought(p)
	end
	local downPad = part({
		Name = "DownPad",
		Size = Vector3.new(5, 0.3, 5),
		CFrame = origin * CFrame.new(3.2, y2 + 0.15, d / 2 - 4),
		Color = Color3.fromRGB(150, 90, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanTouch = true,
		CastShadow = false,
		Parent = floor2,
	})
	hideUntilBought(downPad)

	-- Socles (1-10 en bas, 11-20 à l'étage)
	local pedestals = Instance.new("Folder")
	pedestals.Name = "Pedestals"
	pedestals.Parent = model
	for slot = 1, MapBuilder.PER_FLOOR * 2 do
		buildPedestal(pedestals, origin, index, slot, color)
	end

	model:SetAttribute("Index", index)
	model:SetAttribute("Origin", origin)
	model:SetAttribute("HalfSize", Vector3.new(MapBuilder.BASE_WIDTH / 2, 0, MapBuilder.BASE_DEPTH / 2))
	model:SetAttribute("Color", color)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")
	model:SetAttribute("LockedUntil", 0)
	model:SetAttribute("LockReadyAt", 0)
	model:SetAttribute("Floors", 1)
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

-- Le support de la Roue de la Fortune. La roue elle-même est dessinée par chaque joueur
-- (pour qu'elle tourne en douceur) autour de la pièce invisible "FortuneWheelAnchor".
MapBuilder.WHEEL_POSITION = Vector3.new(0, 11.5, 28)
local function wheelStand(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "FortuneWheelStand"
	folder.Parent = parent
	local pos = MapBuilder.WHEEL_POSITION
	local dark = Color3.fromRGB(45, 35, 60)
	local gold = Color3.fromRGB(255, 200, 40)
	-- estrade ronde avec une marche
	part({
		Name = "WheelStage",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 22, 22),
		CFrame = CFrame.new(pos.X, 0.6, pos.Z) * ROT_UP,
		Color = Color3.fromRGB(90, 50, 130),
		Material = Enum.Material.SmoothPlastic,
		Parent = folder,
	})
	part({
		Name = "WheelStageRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.3, 22.6, 22.6),
		CFrame = CFrame.new(pos.X, 0.55, pos.Z) * ROT_UP,
		Color = gold,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.4,
		Parent = folder,
	})
	-- deux pieds en A derrière la roue
	for _, side in { -1, 1 } do
		part({
			Name = "WheelLeg",
			Size = Vector3.new(1.4, pos.Y + 1, 1.4),
			CFrame = CFrame.new(pos.X + side * 4, pos.Y / 2 + 0.6, pos.Z + 1.6) * CFrame.Angles(0, 0, math.rad(side * -18)),
			Color = dark,
			Material = Enum.Material.Metal,
			Parent = folder,
		})
	end
	part({
		Name = "WheelAxle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4, 1.8, 1.8),
		CFrame = CFrame.new(pos.X, pos.Y, pos.Z + 1.2) * CFrame.Angles(0, math.rad(90), 0),
		Color = gold,
		Material = Enum.Material.Metal,
		Parent = folder,
	})
	-- la flèche rouge en haut qui montre la case gagnante
	part({
		ClassName = "WedgePart",
		Name = "WheelPointer",
		Size = Vector3.new(0.6, 2.2, 1.6),
		CFrame = CFrame.new(pos.X, pos.Y + 9.4, pos.Z - 0.9) * CFrame.Angles(math.rad(180), math.rad(90), 0),
		Color = gold,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = folder,
	})
	local anchor = part({
		Name = "FortuneWheelAnchor",
		Size = Vector3.one,
		CFrame = CFrame.new(pos),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = folder,
	})
	anchor:SetAttribute("SpinId", 0)
	-- l'endroit où on se met pour jouer (le bouton "Tourner" apparaît ici)
	part({
		Name = "WheelSpot",
		Size = Vector3.new(6, 0.3, 4),
		CFrame = CFrame.new(pos.X, 1.35, pos.Z - 7),
		Color = gold,
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		CanCollide = false,
		Parent = folder,
	})
end

-- La Boutique : un stand avec un chaudron (on y achète armes, tours de roue, monstres...)
MapBuilder.SHOP_POSITION = Vector3.new(0, 0, -28)
local function shopStand(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "ShopStand"
	folder.Parent = parent
	local pos = MapBuilder.SHOP_POSITION
	local wood = Color3.fromRGB(110, 70, 45)
	-- comptoir
	part({
		Name = "ShopCounter",
		Size = Vector3.new(14, 3.4, 3),
		CFrame = CFrame.new(pos.X, 1.7, pos.Z + 2),
		Color = wood,
		Material = Enum.Material.WoodPlanks,
		Parent = folder,
	})
	-- poteaux et toit rayé violet et orange
	for _, x in { -6.5, 6.5 } do
		part({
			Name = "ShopPost",
			Size = Vector3.new(0.9, 10, 0.9),
			CFrame = CFrame.new(pos.X + x, 5, pos.Z + 3.2),
			Color = wood,
			Material = Enum.Material.Wood,
			Parent = folder,
		})
	end
	for i = 0, 6 do
		part({
			Name = "ShopAwning",
			Size = Vector3.new(2, 0.4, 6),
			CFrame = CFrame.new(pos.X - 6 + i * 2, 10.4, pos.Z + 1.6) * CFrame.Angles(math.rad(-15), 0, 0),
			Color = if i % 2 == 0 then Color3.fromRGB(150, 70, 230) else Color3.fromRGB(255, 140, 40),
			Material = Enum.Material.Fabric,
			Parent = folder,
		})
	end
	-- le chaudron des monstres qui bouillonne
	part({
		Name = "Cauldron",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 4.6,
		CFrame = CFrame.new(pos.X + 9.5, 2.1, pos.Z + 1),
		Color = Color3.fromRGB(35, 30, 40),
		Material = Enum.Material.Metal,
		Parent = folder,
	})
	local brew = part({
		Name = "CauldronBrew",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 3.8, 3.8),
		CFrame = CFrame.new(pos.X + 9.5, 3.6, pos.Z + 1) * ROT_UP,
		Color = Color3.fromRGB(120, 255, 90),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = folder,
	})
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Color = ColorSequence.new(Color3.fromRGB(150, 255, 120))
	bubbles.Size = NumberSequence.new(0.6, 0)
	bubbles.Speed = NumberRange.new(2, 4)
	bubbles.Rate = 6
	bubbles.Lifetime = NumberRange.new(0.8, 1.2)
	bubbles.LightEmission = 0.6
	bubbles.Parent = brew
	-- le point où apparaît le bouton "Boutique"
	part({
		Name = "ShopSpot",
		Size = Vector3.new(14, 0.3, 4),
		CFrame = CFrame.new(pos.X, 0.15, pos.Z + 6),
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		CanCollide = false,
		Parent = folder,
	})
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

	wheelStand(map)
	shopStand(map)

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
		local z = (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(62, 86)
		pumpkin(decor, Vector3.new(x, 0, z), rng:NextNumber(2, 5))
	end
	for _ = 1, 10 do
		local x = rng:NextNumber(-175, 175)
		local z = (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(64, 86)
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
