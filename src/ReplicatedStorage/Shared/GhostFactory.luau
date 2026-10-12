--[[
	GhostFactory : fabrique le modèle 3D d'un fantôme avec des formes simples
	(boules, blocs, cylindres). Aucun asset externe, très léger pour les mobiles.

	GhostFactory.build("DrapMou") renvoie un Model :
	  - toutes les pièces sont ancrées (Anchored) et sans collision
	  - on le déplace avec model:PivotTo(cframe)
	  - attribut "Bottom" = distance entre le centre et le bas du fantôme
	  - attribut "Top" = distance entre le centre et le haut du fantôme
]]

local GhostData = require(script.Parent.GhostData)
local Rarities = require(script.Parent.Rarities)

local GhostFactory = {}

local BLACK = Color3.fromRGB(25, 20, 30)
local WHITE = Color3.fromRGB(255, 255, 255)
local GRAY = Color3.fromRGB(120, 125, 135)
local GOLD = Color3.fromRGB(255, 200, 40)
local PINK = Color3.fromRGB(255, 130, 170)

local ROT_UP = CFrame.Angles(0, 0, math.rad(90)) -- cylindre debout
local ROT_FRONT = CFrame.Angles(0, math.rad(90), 0) -- disque face à l'avant

local function rgb(t: { number }?, fallback: Color3): Color3
	if not t then
		return fallback
	end
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- Crée une pièce. kind = "Block", "Ball", "Cylinder" ou "Wedge"
local function newPart(ctx, kind: string, size: Vector3, cf: CFrame, color: Color3, extra: { [string]: any }?)
	local p: BasePart
	if kind == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		if kind == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif kind == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		p = part
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.CFrame = cf
	p.Color = color
	if extra then
		if extra.Material then
			p.Material = extra.Material
		end
		if extra.Transparency then
			p.Transparency = extra.Transparency
		end
		if extra.Reflectance then
			p.Reflectance = extra.Reflectance
		end
		if extra.Name then
			p.Name = extra.Name
		end
	end
	p.Parent = ctx.model
	return p
end

local function ball(ctx, d: number, pos: Vector3, color: Color3, extra: { [string]: any }?)
	return newPart(ctx, "Ball", Vector3.one * d, CFrame.new(pos), color, extra)
end

local function block(ctx, size: Vector3, cf: CFrame, color: Color3, extra: { [string]: any }?)
	return newPart(ctx, "Block", size, cf, color, extra)
end

-- Cylindre debout (axe vertical)
local function upCyl(ctx, h: number, d: number, pos: Vector3, color: Color3, extra: { [string]: any }?)
	return newPart(ctx, "Cylinder", Vector3.new(h, d, d), CFrame.new(pos) * ROT_UP, color, extra)
end

-- Disque tourné vers l'avant (axe avant-arrière)
local function frontDisc(ctx, t: number, d: number, pos: Vector3, color: Color3, extra: { [string]: any }?)
	return newPart(ctx, "Cylinder", Vector3.new(t, d, d), CFrame.new(pos) * ROT_FRONT, color, extra)
end

-- Cylindre couché (axe gauche-droite)
local function sideCyl(ctx, t: number, d: number, pos: Vector3, color: Color3, extra: { [string]: any }?)
	return newPart(ctx, "Cylinder", Vector3.new(t, d, d), CFrame.new(pos), color, extra)
end

-- Position Z de la surface avant du corps (pour coller les yeux dessus)
local function frontZ(m, x: number, y: number): number
	if m.sphere then
		local c = m.sphere.center
		local r = m.sphere.r
		local inside = r * r - (x - c.X) ^ 2 - (y - c.Y) ^ 2
		if inside <= 0 then
			return c.Z
		end
		return c.Z - math.sqrt(inside)
	elseif m.cylR then
		local inside = m.cylR * m.cylR - x * x
		if inside <= 0 then
			return 0
		end
		return -math.sqrt(inside)
	end
	return m.front
end

----------------------------------------------------------------------
-- CORPS : chaque fonction construit le corps et renvoie ses mesures
----------------------------------------------------------------------
local Bodies = {}

function Bodies.Sheet(ctx)
	local s = ctx.s
	local body = { Material = ctx.material, Transparency = ctx.transparency, Reflectance = ctx.reflectance }
	ball(ctx, 4 * s, Vector3.new(0, 0.6 * s, 0), ctx.color, body)
	upCyl(ctx, 2.2 * s, 4 * s, Vector3.new(0, -0.9 * s, 0), ctx.color, body)
	for i = 0, 2 do
		local a = math.rad(90 + i * 120)
		ball(ctx, 1.5 * s, Vector3.new(math.cos(a) * 1.25 * s, -2 * s, math.sin(a) * 1.25 * s), ctx.color, body)
	end
	return {
		top = 2.6 * s,
		bottom = -2.75 * s,
		faceY = 0.8 * s,
		faceX = 0,
		halfWidth = 2 * s,
		back = 2 * s,
		sphere = { center = Vector3.new(0, 0.6 * s, 0), r = 2 * s },
	}
end

function Bodies.Blob(ctx)
	local s = ctx.s
	ball(ctx, 4.2 * s, Vector3.zero, ctx.color, { Material = ctx.material, Transparency = ctx.transparency, Reflectance = ctx.reflectance })
	return {
		top = 2.1 * s,
		bottom = -2.1 * s,
		faceY = 0.3 * s,
		faceX = 0,
		halfWidth = 2.1 * s,
		back = 2.1 * s,
		sphere = { center = Vector3.zero, r = 2.1 * s },
	}
end

function Bodies.Block(ctx)
	local s = ctx.s
	local size = ctx.look.Size or { 3.4, 3.4, 1.2 }
	local v = Vector3.new(size[1], size[2], size[3]) * s
	block(ctx, v, CFrame.identity, ctx.color, { Material = ctx.material, Transparency = ctx.transparency, Reflectance = ctx.reflectance })
	return {
		top = v.Y / 2,
		bottom = -v.Y / 2,
		faceY = v.Y * 0.12,
		faceX = 0,
		halfWidth = v.X / 2,
		back = v.Z / 2,
		front = -v.Z / 2,
	}
end

function Bodies.Tube(ctx)
	local s = ctx.s
	local size = ctx.look.Size or { 2.6, 4 }
	local d, h = size[1] * s, size[2] * s
	upCyl(ctx, h, d, Vector3.zero, ctx.color, { Material = ctx.material, Transparency = ctx.transparency })
	return {
		top = h / 2,
		bottom = -h / 2,
		faceY = h * 0.15,
		faceX = 0,
		halfWidth = d / 2,
		back = d / 2,
		cylR = d / 2,
	}
end

function Bodies.Cloud(ctx)
	local s = ctx.s
	local body = { Material = ctx.material, Transparency = ctx.transparency }
	ball(ctx, 3.4 * s, Vector3.zero, ctx.color, body)
	ball(ctx, 2.6 * s, Vector3.new(1.8 * s, -0.3 * s, 0.2 * s), ctx.color, body)
	ball(ctx, 2.6 * s, Vector3.new(-1.8 * s, -0.3 * s, 0.2 * s), ctx.color, body)
	ball(ctx, 2.6 * s, Vector3.new(0.5 * s, 1.3 * s, 0.4 * s), ctx.color, body)
	return {
		top = 2.6 * s,
		bottom = -1.7 * s,
		faceY = 0.1 * s,
		faceX = 0,
		halfWidth = 3.1 * s,
		back = 1.7 * s,
		sphere = { center = Vector3.zero, r = 1.7 * s },
	}
end

function Bodies.Sock(ctx)
	local s = ctx.s
	local body = { Material = ctx.material, Transparency = ctx.transparency }
	block(ctx, Vector3.new(2, 3.4, 2) * s, CFrame.new(0, 0.6 * s, 0), ctx.color, body)
	block(ctx, Vector3.new(2.2, 0.6, 2.2) * s, CFrame.new(0, 2.1 * s, 0), ctx.accent)
	block(ctx, Vector3.new(2.1, 0.4, 2.1) * s, CFrame.new(0, -0.4 * s, 0), ctx.accent)
	block(ctx, Vector3.new(2, 1.5, 3.2) * s, CFrame.new(0, -1.85 * s, -0.6 * s), ctx.color, body)
	return {
		top = 2.4 * s,
		bottom = -2.6 * s,
		faceY = 0.9 * s,
		faceX = 0,
		halfWidth = 1.1 * s,
		back = 1 * s,
		front = -1 * s,
	}
end

function Bodies.Disc(ctx)
	local s = ctx.s
	frontDisc(ctx, 0.7 * s, 4.4 * s, Vector3.zero, ctx.color, { Material = ctx.material })
	-- un peu de "sirop" sur le bord
	frontDisc(ctx, 0.75 * s, 1.4 * s, Vector3.new(1.2 * s, -1.2 * s, 0), Color3.fromRGB(150, 80, 30))
	return {
		top = 2.2 * s,
		bottom = -2.2 * s,
		faceY = 0.3 * s,
		faceX = 0,
		halfWidth = 2.2 * s,
		back = 0.35 * s,
		front = -0.35 * s,
	}
end

function Bodies.Tornado(ctx)
	local s = ctx.s
	local body = { Material = ctx.material, Transparency = ctx.transparency }
	upCyl(ctx, 1.3 * s, 4.4 * s, Vector3.new(0, 1.3 * s, 0), ctx.color, body)
	upCyl(ctx, 1.3 * s, 3.4 * s, Vector3.new(0, 0, 0), ctx.accent, body)
	upCyl(ctx, 1.3 * s, 2.2 * s, Vector3.new(0, -1.3 * s, 0), ctx.color, body)
	upCyl(ctx, 1 * s, 1 * s, Vector3.new(0, -2.3 * s, 0), ctx.accent, body)
	return {
		top = 1.95 * s,
		bottom = -2.8 * s,
		faceY = 1.25 * s,
		faceX = 0,
		halfWidth = 2.2 * s,
		back = 2.2 * s,
		cylR = 2.2 * s,
		faceScale = 0.8,
	}
end

function Bodies.Pizza(ctx)
	local s = ctx.s
	local h, d = 4.6 * s, 4 * s
	newPart(
		ctx,
		"Wedge",
		Vector3.new(0.7 * s, h, d),
		CFrame.Angles(0, 0, math.pi) * CFrame.Angles(0, math.pi / 2, 0),
		ctx.color,
		{ Material = ctx.material }
	)
	-- la croûte
	block(ctx, Vector3.new(d + 0.4 * s, 0.7 * s, 1 * s), CFrame.new(0, h / 2 + 0.2 * s, 0), Color3.fromRGB(200, 130, 60))
	return {
		top = h / 2 + 0.55 * s,
		bottom = -h / 2,
		faceY = h / 6,
		faceX = -d / 6,
		halfWidth = d / 2,
		back = 0.5 * s,
		front = -0.35 * s,
	}
end

function Bodies.Candy(ctx)
	local s = ctx.s
	ball(ctx, 3.2 * s, Vector3.zero, ctx.color, { Material = ctx.material, Reflectance = 0.1 })
	block(ctx, Vector3.new(1.6, 2.2, 0.5) * s, CFrame.new(2.2 * s, 0, 0) * CFrame.Angles(0, 0, math.rad(-20)), ctx.accent)
	block(ctx, Vector3.new(1.6, 2.2, 0.5) * s, CFrame.new(-2.2 * s, 0, 0) * CFrame.Angles(0, 0, math.rad(20)), ctx.accent)
	return {
		top = 1.6 * s,
		bottom = -1.6 * s,
		faceY = 0.15 * s,
		faceX = 0,
		halfWidth = 1.6 * s,
		back = 1.6 * s,
		sphere = { center = Vector3.zero, r = 1.6 * s },
	}
end

----------------------------------------------------------------------
-- VISAGES
----------------------------------------------------------------------
local Faces = {}

local function eyeAt(ctx, m, x: number, y: number, d: number, color: Color3?, extra: { [string]: any }?)
	local z = frontZ(m, x, y) + 0.12 * ctx.s
	return ball(ctx, d, Vector3.new(x, y, z), color or BLACK, extra)
end

local function flatAt(ctx, m, size: Vector3, x: number, y: number, rotZ: number, color: Color3, extra: { [string]: any }?)
	local z = frontZ(m, x, y) - 0.02 * ctx.s
	return block(ctx, size, CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(rotZ)), color, extra)
end

local function twoEyes(ctx, m, d: number?)
	local f = ctx.f
	local eyeD = (d or 0.7) * f
	eyeAt(ctx, m, m.faceX - 0.65 * f, m.faceY + 0.35 * f, eyeD)
	eyeAt(ctx, m, m.faceX + 0.65 * f, m.faceY + 0.35 * f, eyeD)
end

local function smile(ctx, m, sad: boolean?)
	local f = ctx.f
	local y = m.faceY - 0.45 * f
	local tilt = if sad then -30 else 30
	local sideY = if sad then y - 0.12 * f else y + 0.12 * f
	flatAt(ctx, m, Vector3.new(0.6 * f, 0.2 * f, 0.3 * f), m.faceX, y, 0, BLACK)
	flatAt(ctx, m, Vector3.new(0.45 * f, 0.2 * f, 0.3 * f), m.faceX - 0.45 * f, sideY, -tilt, BLACK)
	flatAt(ctx, m, Vector3.new(0.45 * f, 0.2 * f, 0.3 * f), m.faceX + 0.45 * f, sideY, tilt, BLACK)
end

function Faces.Happy(ctx, m)
	twoEyes(ctx, m)
	smile(ctx, m)
end

function Faces.Sad(ctx, m)
	twoEyes(ctx, m)
	smile(ctx, m, true)
end

function Faces.Sleepy(ctx, m)
	local f = ctx.f
	flatAt(ctx, m, Vector3.new(0.7 * f, 0.15 * f, 0.3 * f), m.faceX - 0.65 * f, m.faceY + 0.35 * f, 0, BLACK)
	flatAt(ctx, m, Vector3.new(0.7 * f, 0.15 * f, 0.3 * f), m.faceX + 0.65 * f, m.faceY + 0.35 * f, 0, BLACK)
	eyeAt(ctx, m, m.faceX, m.faceY - 0.4 * f, 0.45 * f)
end

function Faces.Angry(ctx, m)
	local f = ctx.f
	twoEyes(ctx, m)
	flatAt(ctx, m, Vector3.new(0.7 * f, 0.18 * f, 0.3 * f), m.faceX - 0.65 * f, m.faceY + 0.85 * f, -25, BLACK)
	flatAt(ctx, m, Vector3.new(0.7 * f, 0.18 * f, 0.3 * f), m.faceX + 0.65 * f, m.faceY + 0.85 * f, 25, BLACK)
	flatAt(ctx, m, Vector3.new(0.9 * f, 0.18 * f, 0.3 * f), m.faceX, m.faceY - 0.45 * f, 0, BLACK)
end

function Faces.Shy(ctx, m)
	local f = ctx.f
	twoEyes(ctx, m, 0.5)
	eyeAt(ctx, m, m.faceX - 1.1 * f, m.faceY - 0.1 * f, 0.55 * f, PINK, { Transparency = 0.2 })
	eyeAt(ctx, m, m.faceX + 1.1 * f, m.faceY - 0.1 * f, 0.55 * f, PINK, { Transparency = 0.2 })
	eyeAt(ctx, m, m.faceX, m.faceY - 0.35 * f, 0.3 * f)
end

function Faces.Shocked(ctx, m)
	local f = ctx.f
	twoEyes(ctx, m, 0.85)
	eyeAt(ctx, m, m.faceX, m.faceY - 0.5 * f, 0.8 * f)
end

function Faces.BigMouth(ctx, m)
	local f = ctx.f
	twoEyes(ctx, m)
	flatAt(ctx, m, Vector3.new(1.6 * f, 0.7 * f, 0.4 * f), m.faceX, m.faceY - 0.55 * f, 0, BLACK)
	flatAt(ctx, m, Vector3.new(0.3 * f, 0.3 * f, 0.45 * f), m.faceX - 0.35 * f, m.faceY - 0.35 * f, 0, WHITE)
	flatAt(ctx, m, Vector3.new(0.3 * f, 0.3 * f, 0.45 * f), m.faceX + 0.35 * f, m.faceY - 0.35 * f, 0, WHITE)
end

function Faces.Cool(ctx, m)
	local f = ctx.f
	flatAt(ctx, m, Vector3.new(2.2 * f, 0.55 * f, 0.35 * f), m.faceX, m.faceY + 0.35 * f, 0, BLACK, { Reflectance = 0.3 })
	smile(ctx, m)
end

function Faces.Blank(ctx, m)
	local f = ctx.f
	local cyan = ctx.accent
	flatAt(ctx, m, Vector3.new(0.45, 0.45, 0.3) * f, m.faceX - 0.65 * f, m.faceY + 0.35 * f, 0, cyan, { Material = Enum.Material.Neon })
	flatAt(ctx, m, Vector3.new(0.45, 0.45, 0.3) * f, m.faceX + 0.65 * f, m.faceY + 0.35 * f, 0, cyan, { Material = Enum.Material.Neon })
	flatAt(ctx, m, Vector3.new(0.9, 0.15, 0.3) * f, m.faceX, m.faceY - 0.4 * f, 0, cyan, { Material = Enum.Material.Neon })
end

function Faces.Cat(ctx, m)
	local f = ctx.f
	twoEyes(ctx, m)
	eyeAt(ctx, m, m.faceX, m.faceY - 0.1 * f, 0.3 * f, PINK)
	flatAt(ctx, m, Vector3.new(0.5 * f, 0.15 * f, 0.3 * f), m.faceX - 0.22 * f, m.faceY - 0.42 * f, -30, BLACK)
	flatAt(ctx, m, Vector3.new(0.5 * f, 0.15 * f, 0.3 * f), m.faceX + 0.22 * f, m.faceY - 0.42 * f, 30, BLACK)
end

function Faces.Dizzy(ctx, m)
	local f = ctx.f
	for _, side in { -1, 1 } do
		local x = m.faceX + side * 0.65 * f
		flatAt(ctx, m, Vector3.new(0.7 * f, 0.15 * f, 0.3 * f), x, m.faceY + 0.35 * f, 45, BLACK)
		flatAt(ctx, m, Vector3.new(0.7 * f, 0.15 * f, 0.3 * f), x, m.faceY + 0.35 * f, -45, BLACK)
	end
	eyeAt(ctx, m, m.faceX, m.faceY - 0.45 * f, 0.45 * f)
end

function Faces.Monocle(ctx, m)
	local f = ctx.f
	twoEyes(ctx, m)
	local x, y = m.faceX + 0.65 * f, m.faceY + 0.35 * f
	local z = frontZ(m, x, y)
	frontDisc(ctx, 0.08 * f, 1.05 * f, Vector3.new(x, y, z + 0.02 * f), GOLD, { Transparency = 0.3, Reflectance = 0.3 })
	smile(ctx, m)
end

function Faces.Pirate(ctx, m)
	local f = ctx.f
	eyeAt(ctx, m, m.faceX - 0.65 * f, m.faceY + 0.35 * f, 0.7 * f)
	local x, y = m.faceX + 0.65 * f, m.faceY + 0.35 * f
	frontDisc(ctx, 0.25 * f, 0.85 * f, Vector3.new(x, y, frontZ(m, x, y) + 0.05 * f), BLACK)
	flatAt(ctx, m, Vector3.new(2.6 * f, 0.12 * f, 0.25 * f), m.faceX, m.faceY + 0.55 * f, -12, BLACK)
	smile(ctx, m)
end

function Faces.Skull(ctx, m)
	local f = ctx.f
	twoEyes(ctx, m, 1.0)
	flatAt(ctx, m, Vector3.new(0.25, 0.35, 0.3) * f, m.faceX, m.faceY - 0.15 * f, 0, BLACK)
	flatAt(ctx, m, Vector3.new(1.2, 0.3, 0.3) * f, m.faceX, m.faceY - 0.6 * f, 0, BLACK)
	for i = -1, 1 do
		flatAt(ctx, m, Vector3.new(0.08, 0.32, 0.35) * f, m.faceX + i * 0.3 * f, m.faceY - 0.6 * f, 0, WHITE)
	end
end

function Faces.JackO(ctx, m)
	local f = ctx.f
	local glow = Color3.fromRGB(255, 230, 80)
	local neon = { Material = Enum.Material.Neon }
	flatAt(ctx, m, Vector3.new(0.6, 0.6, 0.3) * f, m.faceX - 0.7 * f, m.faceY + 0.4 * f, 45, glow, neon)
	flatAt(ctx, m, Vector3.new(0.6, 0.6, 0.3) * f, m.faceX + 0.7 * f, m.faceY + 0.4 * f, 45, glow, neon)
	flatAt(ctx, m, Vector3.new(2, 0.45, 0.3) * f, m.faceX, m.faceY - 0.5 * f, 0, glow, neon)
	flatAt(ctx, m, Vector3.new(0.3, 0.25, 0.35) * f, m.faceX - 0.4 * f, m.faceY - 0.38 * f, 0, ctx.color)
	flatAt(ctx, m, Vector3.new(0.3, 0.25, 0.35) * f, m.faceX + 0.4 * f, m.faceY - 0.62 * f, 0, ctx.color)
end

----------------------------------------------------------------------
-- ACCESSOIRES
----------------------------------------------------------------------
local Accessories = {}

function Accessories.Jam(ctx, m)
	local s = ctx.s
	local w, h = m.halfWidth * 2 * 0.8, (m.top - m.bottom) * 0.8
	block(ctx, Vector3.new(w, h, 0.06 * s), CFrame.new(0, 0, m.front - 0.02 * s), ctx.accent, { Transparency = 0.1 })
end

function Accessories.Bun(ctx, m)
	local s = ctx.s
	ball(ctx, 1.6 * s, Vector3.new(0, m.top + 0.3 * s, 0.4 * s), ctx.accent)
	ball(ctx, 0.5 * s, Vector3.new(0.6 * s, m.top + 0.7 * s, 0.5 * s), Color3.fromRGB(255, 120, 160))
end

function Accessories.Crumbs(ctx, _m)
	local s = ctx.s
	local spots = {
		Vector3.new(1.8, -1.3, -0.8),
		Vector3.new(1.2, -2.0, 0.6),
		Vector3.new(-1.0, -2.1, -1.1),
		Vector3.new(-1.9, -0.9, 0.4),
	}
	for i, p in spots do
		block(ctx, Vector3.one * 0.4 * s, CFrame.new(p * s) * CFrame.Angles(i, i * 2, 0), ctx.accent)
	end
end

function Accessories.Spaghetti(ctx, m)
	local s = ctx.s
	local pasta = Color3.fromRGB(255, 220, 120)
	for i, z in { -0.9, -0.3, 0.3, 0.9 } do
		local tilt = if i % 2 == 0 then 25 else -20
		local cf = CFrame.new(0, m.top - 0.35 * s, z * s) * CFrame.Angles(0, 0, math.rad(tilt))
		newPart(ctx, "Cylinder", Vector3.new(3.4 * s, 0.25 * s, 0.25 * s), cf, pasta)
	end
	ball(ctx, 1 * s, Vector3.new(0.3 * s, m.top + 0.25 * s, 0), ctx.accent)
end

function Accessories.LoadingRing(ctx, m)
	local s = ctx.s
	upCyl(ctx, 0.15 * s, 2.6 * s, Vector3.new(0, m.top + 0.8 * s, 0), ctx.accent, { Material = Enum.Material.Neon, Transparency = 0.3 })
	block(ctx, Vector3.one * 0.5 * s, CFrame.new(1.5 * s, m.top - 0.3 * s, -0.5 * s), ctx.accent, { Material = Enum.Material.Neon })
end

function Accessories.ChickenComb(ctx, m)
	local s = ctx.s
	for _, z in { -0.5, 0, 0.5 } do
		ball(ctx, 0.8 * s, Vector3.new(0, m.top + 0.1 * s + (0.15 - math.abs(z) * 0.3) * s, z * s), ctx.accent)
	end
	local y = m.faceY - 0.05 * s
	newPart(ctx, "Wedge", Vector3.new(0.6, 0.4, 0.8) * s, CFrame.new(0, y, frontZ(m, 0, y) - 0.2 * s), GOLD)
end

function Accessories.FridgeHandle(ctx, m)
	local s = ctx.s
	local x = m.halfWidth - 0.35 * s
	block(ctx, Vector3.new(m.halfWidth * 2, 0.1 * s, 0.1 * s), CFrame.new(0, m.top - 0.75 * s, m.front - 0.03 * s), ctx.accent)
	block(ctx, Vector3.new(0.25, 0.6, 0.35) * s, CFrame.new(x, m.top - 0.4 * s, m.front - 0.15 * s), ctx.accent)
	block(ctx, Vector3.new(0.25, 1.2, 0.35) * s, CFrame.new(x, m.bottom + 1 * s, m.front - 0.15 * s), ctx.accent)
end

function Accessories.Stalk(ctx, m)
	local s = ctx.s
	upCyl(ctx, 1.8 * s, 1.4 * s, Vector3.new(0, m.bottom - 0.5 * s, 0), ctx.accent)
end

function Accessories.Pompom(ctx, m)
	local s = ctx.s
	ball(ctx, 1.3 * s, Vector3.new(0, m.top + 0.35 * s, m.front + 1.7 * s), ctx.accent)
end

function Accessories.Handle(ctx, m)
	local s = ctx.s
	upCyl(ctx, 3.2 * s, 0.45 * s, Vector3.new(0, m.bottom - 1.6 * s, 0), ctx.accent)
end

function Accessories.Rain(ctx, m)
	local s = ctx.s
	local emitterPart = block(ctx, Vector3.new(m.halfWidth * 1.4, 0.2, 1.5 * s), CFrame.new(0, m.bottom - 0.2 * s, 0), WHITE, { Transparency = 1 })
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(ctx.accent)
	e.Size = NumberSequence.new(0.18 * s)
	e.Speed = NumberRange.new(4, 6)
	e.Acceleration = Vector3.new(0, -25, 0)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Rate = 10
	e.Lifetime = NumberRange.new(0.4, 0.6)
	e.LightEmission = 0.3
	e.Parent = emitterPart
end

function Accessories.Antenna(ctx, m)
	local s = ctx.s
	upCyl(ctx, 1.8 * s, 0.18 * s, Vector3.new(0, m.top + 0.8 * s, 0), GRAY)
	ball(ctx, 0.55 * s, Vector3.new(0, m.top + 1.8 * s, 0), ctx.accent, { Material = Enum.Material.Neon })
end

function Accessories.ChefHat(ctx, m)
	local s = ctx.s
	upCyl(ctx, 1.1 * s, 1.9 * s, Vector3.new(0, m.top + 0.35 * s, 0), WHITE)
	ball(ctx, 2.3 * s, Vector3.new(0, m.top + 1.3 * s, 0), WHITE)
end

function Accessories.Flame(ctx, m)
	local s = ctx.s
	local flame = ball(ctx, 1.1 * s, Vector3.new(0, m.top + 0.6 * s, 0), ctx.accent, { Material = Enum.Material.Neon })
	ball(ctx, 0.6 * s, Vector3.new(0, m.top + 0.45 * s, -0.25 * s), Color3.fromRGB(255, 240, 120), { Material = Enum.Material.Neon })
	upCyl(ctx, 1 * s, 0.5 * s, Vector3.new(m.halfWidth - 0.15 * s, m.top - 0.4 * s, -0.6 * s), ctx.color)
	local light = Instance.new("PointLight")
	light.Color = ctx.accent
	light.Range = 10
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = flame
end

function Accessories.CatEars(ctx, m)
	local s = ctx.s
	local size = Vector3.new(0.35, 1.3, 1.1) * s
	newPart(ctx, "Wedge", size, CFrame.new(-0.95 * s, m.top - 0.1 * s, 0) * CFrame.Angles(0, -math.pi / 2, 0), ctx.color)
	newPart(ctx, "Wedge", size, CFrame.new(0.95 * s, m.top - 0.1 * s, 0) * CFrame.Angles(0, math.pi / 2, 0), ctx.color)
	ball(ctx, 0.5 * s, Vector3.new(-0.95 * s, m.top - 0.05 * s, -0.25 * s), ctx.accent)
	ball(ctx, 0.5 * s, Vector3.new(0.95 * s, m.top - 0.05 * s, -0.25 * s), ctx.accent)
end

function Accessories.Bumps(ctx, _m)
	local s = ctx.s
	local darker = ctx.color:Lerp(BLACK, 0.25)
	for _, p in { Vector3.new(1.15, 0.9, 0.3), Vector3.new(-1.15, -0.6, 0.2), Vector3.new(0.6, -1.5, -1.0), Vector3.new(-0.5, 1.7, 0.95) } do
		ball(ctx, 0.6 * s, p * s, darker)
	end
end

function Accessories.PirateHat(ctx, m)
	local s = ctx.s
	block(ctx, Vector3.new(3.4, 0.9, 1.6) * s, CFrame.new(0, m.top + 0.4 * s, 0), Color3.fromRGB(30, 30, 35))
	block(ctx, Vector3.new(3.45, 0.2, 1.65) * s, CFrame.new(0, m.top + 0.05 * s, 0), GOLD)
	ball(ctx, 0.5 * s, Vector3.new(0, m.top + 0.45 * s, -0.8 * s), WHITE)
end

function Accessories.String(ctx, m)
	local s = ctx.s
	upCyl(ctx, 3 * s, 0.1 * s, Vector3.new(0, m.bottom - 1.5 * s, 0), ctx.accent)
	ball(ctx, 0.45 * s, Vector3.new(0, m.bottom - 0.05 * s, 0), ctx.color)
end

function Accessories.Lumps(ctx, _m)
	local s = ctx.s
	local darker = ctx.color:Lerp(BLACK, 0.15)
	for _, p in { Vector3.new(1.6, 0.6, 0.9), Vector3.new(-1.5, -0.9, -0.5), Vector3.new(0.4, -1.6, -1.0) } do
		ball(ctx, 1.3 * s, p * s, darker)
	end
end

function Accessories.Crown(ctx, m)
	local s = ctx.s
	local gold = { Reflectance = 0.25 }
	upCyl(ctx, 0.9 * s, 2.2 * s, Vector3.new(0, m.top + 0.35 * s, 0), GOLD, gold)
	for _, p in { Vector3.new(0.9, 0, 0), Vector3.new(-0.9, 0, 0), Vector3.new(0, 0, 0.9), Vector3.new(0, 0, -0.9) } do
		ball(ctx, 0.45 * s, Vector3.new(p.X * s, m.top + 0.9 * s, p.Z * s), GOLD, gold)
	end
	ball(ctx, 0.45 * s, Vector3.new(0, m.top + 0.35 * s, -1.1 * s), Color3.fromRGB(230, 30, 60), { Reflectance = 0.3 })
end

function Accessories.Headphones(ctx, m)
	local s = ctx.s
	local w = m.halfWidth + 0.1 * s
	block(ctx, Vector3.new(w * 2 + 0.3 * s, 0.35 * s, 0.6 * s), CFrame.new(0, m.top + 0.1 * s, 0), BLACK)
	for _, side in { -1, 1 } do
		block(ctx, Vector3.new(0.3, 1.1, 0.5) * s, CFrame.new(side * (w + 0.05 * s), m.top - 0.45 * s, 0), BLACK)
		sideCyl(ctx, 0.7 * s, 1.5 * s, Vector3.new(side * w, m.faceY + 0.3 * s, 0), ctx.accent, { Material = Enum.Material.Neon })
	end
end

function Accessories.TopHat(ctx, m)
	local s = ctx.s
	local hat = Color3.fromRGB(25, 25, 30)
	upCyl(ctx, 0.2 * s, 2.8 * s, Vector3.new(0, m.top + 0.1 * s, 0), hat)
	upCyl(ctx, 1.7 * s, 1.8 * s, Vector3.new(0, m.top + 1 * s, 0), hat)
	upCyl(ctx, 0.35 * s, 1.85 * s, Vector3.new(0, m.top + 0.4 * s, 0), Color3.fromRGB(200, 40, 60))
end

function Accessories.Mustache(ctx, m)
	local s = ctx.s
	local f = ctx.f
	local y = m.faceY - 0.12 * f
	local z = frontZ(m, m.faceX, y) - 0.12 * s
	block(ctx, Vector3.new(1.5 * f, 0.3 * f, 0.25 * s), CFrame.new(m.faceX, y, z), BLACK)
	ball(ctx, 0.45 * f, Vector3.new(m.faceX - 0.8 * f, y + 0.08 * f, z), BLACK)
	ball(ctx, 0.45 * f, Vector3.new(m.faceX + 0.8 * f, y + 0.08 * f, z), BLACK)
end

function Accessories.Rocket(ctx, m)
	local s = ctx.s
	for _, side in { -1, 1 } do
		local x = side * 0.65 * s
		local z = m.back + 0.35 * s
		upCyl(ctx, 2 * s, 0.9 * s, Vector3.new(x, 0, z), GRAY, { Reflectance = 0.2 })
		local fire = ball(ctx, 0.7 * s, Vector3.new(x, -1.15 * s, z), Color3.fromRGB(255, 140, 30), { Material = Enum.Material.Neon })
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 70, 20))
		e.Size = NumberSequence.new(0.6 * s, 0)
		e.Speed = NumberRange.new(5, 7)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Rate = 15
		e.Lifetime = NumberRange.new(0.3, 0.4)
		e.LightEmission = 1
		e.Parent = fire
	end
end

function Accessories.Rings(ctx, m)
	local s = ctx.s
	newPart(
		ctx,
		"Cylinder",
		Vector3.new(0.15 * s, 7.2 * s, 7.2 * s),
		CFrame.new(0, m.faceY - 0.6 * s, 0) * CFrame.Angles(math.rad(15), 0, 0) * ROT_UP,
		ctx.accent,
		{ Material = Enum.Material.Neon, Transparency = 0.35 }
	)
end

function Accessories.Cape(ctx, m)
	local s = ctx.s
	block(ctx, Vector3.new(3.6, 3.8, 0.25) * s, CFrame.new(0, -0.3 * s, m.back + 0.15 * s) * CFrame.Angles(math.rad(-8), 0, 0), ctx.accent)
end

function Accessories.Pepperoni(ctx, m)
	local s = ctx.s
	for _, p in { Vector2.new(1.0, 1.85), Vector2.new(-1.6, -1.3), Vector2.new(-0.9, -0.65) } do
		frontDisc(ctx, 0.15 * s, 0.9 * s, Vector3.new(p.X * s, p.Y * s, m.front - 0.05 * s), ctx.accent)
	end
end

function Accessories.Stem(ctx, m)
	local s = ctx.s
	newPart(ctx, "Cylinder", Vector3.new(0.9 * s, 0.5 * s, 0.5 * s), CFrame.new(0, m.top + 0.35 * s, 0) * CFrame.Angles(math.rad(10), 0, 0) * ROT_UP, ctx.accent)
end

function Accessories.WitchHat(ctx, m)
	local s = ctx.s
	local dark = ctx.accent
	upCyl(ctx, 0.18 * s, 3.6 * s, Vector3.new(0, m.top + 0.05 * s, 0), dark)
	upCyl(ctx, 0.9 * s, 2.2 * s, Vector3.new(0, m.top + 0.55 * s, 0), dark)
	upCyl(ctx, 0.3 * s, 2.25 * s, Vector3.new(0, m.top + 0.3 * s, 0), Color3.fromRGB(255, 140, 30))
	upCyl(ctx, 0.9 * s, 1.5 * s, Vector3.new(0, m.top + 1.4 * s, 0.1 * s), dark)
	upCyl(ctx, 0.9 * s, 0.8 * s, Vector3.new(0, m.top + 2.2 * s, 0.25 * s), dark)
end

function Accessories.Scooter(ctx, m)
	local s = ctx.s
	local y = m.bottom - 0.5 * s
	block(ctx, Vector3.new(1.4, 0.3, 4) * s, CFrame.new(0, y, 0), GRAY)
	sideCyl(ctx, 0.5 * s, 1 * s, Vector3.new(0, y - 0.4 * s, 1.6 * s), BLACK)
	sideCyl(ctx, 0.5 * s, 1 * s, Vector3.new(0, y - 0.4 * s, -1.6 * s), BLACK)
	upCyl(ctx, 3.6 * s, 0.3 * s, Vector3.new(0, y + 1.8 * s, -1.9 * s), GRAY)
	sideCyl(ctx, 2.4 * s, 0.3 * s, Vector3.new(0, y + 3.6 * s, -1.9 * s), Color3.fromRGB(255, 140, 30))
end

function Accessories.DiscoBall(ctx, m)
	local s = ctx.s
	upCyl(ctx, 0.6 * s, 0.1 * s, Vector3.new(0, m.top + 0.4 * s, 0), GRAY)
	local disco = ball(ctx, 1.8 * s, Vector3.new(0, m.top + 1.6 * s, 0), Color3.fromRGB(220, 220, 240), { Material = Enum.Material.Foil, Reflectance = 0.5 })
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 200)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 80)),
	})
	e.Size = NumberSequence.new(0.3 * s)
	e.Speed = NumberRange.new(3, 5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 8
	e.Lifetime = NumberRange.new(0.6, 1)
	e.LightEmission = 1
	e.Parent = disco
end

----------------------------------------------------------------------
-- CONSTRUCTION
----------------------------------------------------------------------

-- Renvoie les mesures d'un fantôme (taille, échelle) sans le construire
function GhostFactory.scaleOf(ghostId: string): number
	local ghost = GhostData.get(ghostId)
	if not ghost then
		return 1
	end
	return ghost.Look.Scale or Rarities.Info[ghost.Rarity].Scale
end

function GhostFactory.build(ghostId: string): Model
	local ghost = GhostData.get(ghostId) or GhostData.get("DrapMou")
	local look = ghost.Look
	local rarityInfo = Rarities.Info[ghost.Rarity]

	local model = Instance.new("Model")
	model.Name = "Ghost_" .. ghost.Id

	local ctx = {
		model = model,
		look = look,
		s = look.Scale or rarityInfo.Scale,
		f = 1,
		color = rgb(look.Color, WHITE),
		accent = rgb(look.Accent, GOLD),
		material = if look.Material then Enum.Material[look.Material] else Enum.Material.SmoothPlastic,
		transparency = look.Transparency,
		reflectance = look.Reflectance,
	}

	-- La "racine" invisible : c'est elle qu'on déplace
	local root = newPart(ctx, "Block", Vector3.one, CFrame.identity, WHITE, { Transparency = 1, Name = "Root" })
	model.PrimaryPart = root

	local bodyBuilder = Bodies[look.Body] or Bodies.Sheet
	local m = bodyBuilder(ctx)
	ctx.f = ctx.s * (look.FaceScale or m.faceScale or 1)

	local faceBuilder = Faces[look.Face] or Faces.Happy
	faceBuilder(ctx, m)

	for _, accessoryName in look.Accessories or {} do
		local builder = Accessories[accessoryName]
		if builder then
			builder(ctx, m)
		else
			warn("[GhostFactory] Accessoire inconnu : " .. tostring(accessoryName))
		end
	end

	-- Effets selon la rareté : lumière dès Légendaire, étincelles dès Mythique
	local rank = rarityInfo.Rank
	local rarityColor = Rarities.color(ghost.Rarity)
	if rank >= 4 then
		local light = Instance.new("PointLight")
		light.Color = rarityColor
		light.Range = 8 + rank
		light.Brightness = 1
		light.Shadows = false
		light.Parent = root
	end
	if rank >= 5 then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "RaritySparkles"
		sparkles.Color = ColorSequence.new(rarityColor, WHITE)
		sparkles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparkles.Speed = NumberRange.new(1, 3)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Rate = 6
		sparkles.Lifetime = NumberRange.new(1, 1.6)
		sparkles.LightEmission = 1
		sparkles.Parent = root
	end

	model:SetAttribute("GhostId", ghost.Id)
	model:SetAttribute("Top", m.top)
	model:SetAttribute("Bottom", -m.bottom)
	model:SetAttribute("Spin", look.Spin or 1)
	return model
end

return GhostFactory
