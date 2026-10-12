--[[
	Weapons : les armes pour chasser les voleurs (partagé entre le serveur et les joueurs).
	  - la Batte est offerte à tout le monde
	  - les autres s'achètent avec un Game Pass (ID dans Config.GamePasses)

	Ce qu'une arme fait quand on frappe (le serveur vérifie tout) :
	  - un voleur qui porte un fantôme : il le lâche (le fantôme rentre chez lui),
	    il est repoussé et étourdi un moment
	  - un intrus dans TA base : il est repoussé dehors
	  - les autres joueurs : rien (pas de bagarre gratuite)
	On ne peut pas frapper en portant un fantôme volé : les armes servent à défendre.

	Range = portée en studs, Cooldown = temps entre deux coups, Stun = étourdissement,
	Knock = force du recul, Sweep = touche tous les voleurs à portée (sinon le plus proche)
]]

local Weapons = {}

Weapons.List = {
	{
		Id = "Batte",
		Icon = "🏏",
		Name = { fr = "Batte", en = "Bat" },
		Desc = { fr = "Offerte. Un bon coup et le voleur lâche tout !", en = "Free. One good hit and the thief drops everything!" },
		Free = true,
		Range = 9,
		Cooldown = 1.6,
		Stun = 1.5,
		Knock = 45,
		Sound = "Bonk",
		Color = { 190, 130, 70 },
	},
	{
		Id = "MarteauPouet",
		Icon = "🔨",
		Name = { fr = "Marteau Pouet Géant", en = "Giant Squeaky Hammer" },
		Desc = { fr = "Plus loin, plus fort, et ça fait POUET.", en = "Longer reach, stronger, and it goes SQUEAK." },
		Pass = "WeaponHammer",
		Range = 11,
		Cooldown = 1.3,
		Stun = 2.2,
		Knock = 70,
		Sound = "Bonk",
		Color = { 255, 90, 160 },
	},
	{
		Id = "BalaiSorciere",
		Icon = "🧹",
		Name = { fr = "Balai de Sorcière", en = "Witch Broom" },
		Desc = { fr = "Un grand coup de balai : touche tous les voleurs autour.", en = "A big sweep: hits every thief around you." },
		Pass = "WeaponBroom",
		Range = 12,
		Cooldown = 1.5,
		Stun = 1.6,
		Knock = 55,
		Sweep = true,
		Sound = "Bonk",
		Color = { 170, 90, 255 },
	},
	{
		Id = "AspiraFantome",
		Icon = "🌀",
		Name = { fr = "Aspira-Fantôme", en = "Ghost Vacuum" },
		Desc = { fr = "Aspire le fantôme volé de très loin.", en = "Sucks the stolen ghost back from far away." },
		Pass = "WeaponVacuum",
		Range = 20,
		Cooldown = 2.5,
		Stun = 0.8,
		Knock = 25,
		Sound = "Vacuum",
		Color = { 80, 255, 170 },
	},
}

Weapons.ById = {}
for order, weapon in Weapons.List do
	weapon.Order = order
	Weapons.ById[weapon.Id] = weapon
end

function Weapons.get(id: any)
	return if type(id) == "string" then Weapons.ById[id] else nil
end

---------------------------------------------------------------- Modèles 3D

local function newPart(tool: Instance, shape: Enum.PartType?, size: Vector3, offset: CFrame, color: Color3, handle: BasePart?, extra: { [string]: any }?)
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	if extra then
		local writable: any = p
		for key, value in extra do
			writable[key] = value
		end
	end
	if handle then
		p.CFrame = handle.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
	end
	p.Parent = tool
	return p
end

-- Les cylindres de Roblox sont couchés sur X : on les tourne pour suivre l'axe Z de l'arme
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0)

local Builders = {}

-- L'arme est dessinée le long de l'axe Z de la poignée ("Handle"), le manche vers -Z
function Builders.Batte(tool: Tool, handle: BasePart)
	local wood = Color3.fromRGB(205, 145, 80)
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(1.6, 0.42, 0.42), CFrame.new(0, 0, -1.2) * ALONG_Z, Color3.fromRGB(40, 40, 50), handle)
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(1.6, 0.55, 0.55), CFrame.new(0, 0, 0.2) * ALONG_Z, wood, handle)
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(2, 0.85, 0.85), CFrame.new(0, 0, 1.8) * ALONG_Z, wood, handle)
	-- le bout noir et le pommeau
	newPart(tool, Enum.PartType.Ball, Vector3.one * 0.95, CFrame.new(0, 0, 2.8), Color3.fromRGB(35, 35, 45), handle)
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(0.25, 0.65, 0.65), CFrame.new(0, 0, -2.05) * ALONG_Z, Color3.fromRGB(150, 80, 40), handle)
	-- une grande bande rouge pour faire "batte de champion"
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(0.8, 0.9, 0.9), CFrame.new(0, 0, 0.9) * ALONG_Z, Color3.fromRGB(230, 50, 60), handle)
end

function Builders.MarteauPouet(tool: Tool, handle: BasePart)
	local pink = Color3.fromRGB(255, 90, 160)
	local yellow = Color3.fromRGB(255, 220, 60)
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(4, 0.45, 0.45), CFrame.new(0, 0, 0) * ALONG_Z, yellow, handle)
	-- la tête du marteau, en travers
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(2.6, 1.7, 1.7), CFrame.new(0, 0, 2.4), pink, handle)
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(0.3, 1.8, 1.8), CFrame.new(1.3, 0, 2.4), Color3.fromRGB(255, 255, 255), handle)
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(0.3, 1.8, 1.8), CFrame.new(-1.3, 0, 2.4), Color3.fromRGB(255, 255, 255), handle)
	-- une étoile jaune sur le côté (un rond, vu de loin)
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(0.12, 0.9, 0.9), CFrame.new(0, 0.86, 2.4) * CFrame.Angles(0, 0, math.rad(90)), yellow, handle)
end

function Builders.BalaiSorciere(tool: Tool, handle: BasePart)
	local wood = Color3.fromRGB(120, 75, 40)
	local straw = Color3.fromRGB(255, 190, 70)
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(4.6, 0.35, 0.35), CFrame.new(0, 0, 0.3) * ALONG_Z, wood, handle)
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(0.4, 0.75, 0.75), CFrame.new(0, 0, 2.4) * ALONG_Z, Color3.fromRGB(150, 70, 230), handle)
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(1.6, 1.3, 1.3), CFrame.new(0, 0, 3.3) * ALONG_Z, straw, handle)
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(0.9, 1.7, 1.7), CFrame.new(0, 0, 4.3) * ALONG_Z, straw, handle)
	-- petites étincelles magiques
	newPart(tool, Enum.PartType.Ball, Vector3.one * 0.35, CFrame.new(0.6, 0.5, 4.6), Color3.fromRGB(200, 140, 255), handle, { Material = Enum.Material.Neon })
end

function Builders.AspiraFantome(tool: Tool, handle: BasePart)
	local body = Color3.fromRGB(60, 70, 90)
	local neon = Color3.fromRGB(80, 255, 170)
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(1.4, 0.5, 0.5), CFrame.new(0, -0.1, -0.9) * ALONG_Z, Color3.fromRGB(40, 40, 50), handle)
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(2.2, 1.2, 1.2), CFrame.new(0, 0.5, 0.6) * ALONG_Z, body, handle)
	-- la grosse bouche qui aspire, avec son anneau vert lumineux
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(0.9, 1.5, 1.5), CFrame.new(0, 0.5, 2) * ALONG_Z, body, handle)
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(0.2, 1.2, 1.2), CFrame.new(0, 0.5, 2.48) * ALONG_Z, neon, handle, { Material = Enum.Material.Neon })
	newPart(tool, Enum.PartType.Cylinder, Vector3.new(0.22, 0.6, 0.6), CFrame.new(0, 0.5, 2.5) * ALONG_Z, Color3.fromRGB(230, 255, 240), handle, { Material = Enum.Material.Neon })
	-- le tuyau vert qui fait une boucle sous l'appareil
	local hose = Color3.fromRGB(60, 200, 120)
	for i = 0, 4 do
		local a = math.rad(-30 - i * 60)
		newPart(tool, Enum.PartType.Cylinder, Vector3.new(0.8, 0.35, 0.35), CFrame.new(0, -0.3 + math.sin(a) * 0.7, -0.6 + math.cos(a) * 0.7) * CFrame.Angles(a + math.pi / 2, 0, 0) * ALONG_Z, hose, handle)
	end
end

-- Fabrique l'outil (Tool) à mettre dans le sac du joueur
function Weapons.buildTool(id: string): Tool
	local weapon = Weapons.ById[id] or Weapons.ById.Batte
	local tool = Instance.new("Tool")
	tool.Name = weapon.Name.fr
	tool.ToolTip = weapon.Icon
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("WeaponId", weapon.Id)

	local handle = newPart(tool, nil, Vector3.new(0.5, 0.5, 1.2), CFrame.identity, Color3.fromRGB(40, 40, 50), nil, {
		Name = "Handle",
		Transparency = 1,
	})
	handle.CFrame = CFrame.new()
	local builder = Builders[weapon.Id] or Builders.Batte
	builder(tool, handle)
	-- la main tient le manche, l'arme pointe vers l'avant de la main
	tool.Grip = CFrame.new(0, 0, -1.2)
	tool:SetAttribute("BaseGrip", tool.Grip)
	return tool
end

return Weapons
