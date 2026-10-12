--[[
	AnimView : les gestes des personnages avec les objets, vus par tout le monde.
	  - coup de batte (de côté), marteau (par-dessus la tête), balai (on tourne sur soi),
	    aspirateur (recul + rayon vert vers le voleur)
	  - le voleur porte le fantôme bras levés au-dessus de la tête
	  - celui qui prend un coup part en arrière

	Pas besoin de fichier d'animation : on fait pivoter les articulations du personnage
	(épaules, bassin) par le code, image par image. Chaque joueur anime tous les
	personnages qu'il voit, à partir des messages du serveur (Effect "Swing" et "Bonk").
	Marche avec les avatars R15 et R6.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared:WaitForChild("Weapons"))

local AnimView = {}

local rad = math.rad

---------------------------------------------------------------- Articulations

type Layered = { Base: CFrame, Layers: { [string]: CFrame } }
local layered: { [Motor6D]: Layered } = setmetatable({}, { __mode = "k" }) :: any

local function findMotor(character: Model, names: { string }): Motor6D?
	for _, name in names do
		local found = character:FindFirstChild(name, true)
		if found and found:IsA("Motor6D") then
			return found
		end
	end
	return nil
end

type Joints = { Right: Motor6D?, Left: Motor6D?, Root: Motor6D? }
local jointCache: { [Model]: Joints } = setmetatable({}, { __mode = "k" }) :: any

local function jointsOf(character: Model): Joints
	local cached = jointCache[character]
	-- on recherche si une articulation manque encore (personnage en train de charger)
	if cached and cached.Right and cached.Left and cached.Root and cached.Right.Parent then
		return cached
	end
	local joints = {
		Right = findMotor(character, { "RightShoulder", "Right Shoulder" }),
		Left = findMotor(character, { "LeftShoulder", "Left Shoulder" }),
		Root = findMotor(character, { "Root", "RootJoint" }),
	}
	jointCache[character] = joints
	return joints
end

-- Pose une rotation "layer" sur une articulation (nil = l'enlève).
-- La rotation est exprimée dans les axes du torse : X à droite, Y en haut, -Z devant.
local function setLayer(motor: Motor6D?, layer: string, rotation: CFrame?)
	if not motor then
		return
	end
	local state = layered[motor]
	if not state then
		if not rotation then
			return
		end
		state = { Base = motor.C0, Layers = {} }
		layered[motor] = state
	end
	state.Layers[layer] = rotation
	local offset = CFrame.identity
	for _, r in state.Layers do
		offset *= r
	end
	local base = state.Base
	motor.C0 = CFrame.new(base.Position) * offset * base.Rotation
	if next(state.Layers) == nil then
		layered[motor] = nil
	end
end

---------------------------------------------------------------- Courbes

-- Interpolation douce entre des images clés { {temps 0..1, angle en degrés}, ... }
local function curve(keys: { { number } }, t: number): number
	if t <= keys[1][1] then
		return keys[1][2]
	end
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]
		if t <= b[1] then
			local k = (t - a[1]) / math.max(b[1] - a[1], 1e-6)
			k = k * k * (3 - 2 * k)
			return a[2] + (b[2] - a[2]) * k
		end
	end
	return keys[#keys][2]
end

-- Chaque geste : durée, et les rotations à chaque instant (t va de 0 à 1)
local MOVES = {
	-- coup de batte : on arme à droite, on balaie vers la gauche
	Batte = {
		Duration = 0.45,
		Pose = function(t: number)
			local swing = curve({ { 0, 0 }, { 0.3, -70 }, { 0.55, 85 }, { 1, 0 } }, t)
			local twist = curve({ { 0, 0 }, { 0.3, -20 }, { 0.55, 25 }, { 1, 0 } }, t)
			return { Right = CFrame.Angles(0, rad(swing), 0), Root = CFrame.Angles(0, rad(twist), 0) }
		end,
	},
	-- marteau : bras levé au-dessus de la tête, puis on écrase devant soi
	MarteauPouet = {
		Duration = 0.5,
		Pose = function(t: number)
			local lift = curve({ { 0, 0 }, { 0.4, 115 }, { 0.6, -40 }, { 1, 0 } }, t)
			local bend = curve({ { 0, 0 }, { 0.4, 10 }, { 0.6, -18 }, { 1, 0 } }, t)
			return { Right = CFrame.Angles(rad(lift), 0, 0), Root = CFrame.Angles(rad(bend), 0, 0) }
		end,
	},
	-- balai : un grand tour sur soi-même
	BalaiSorciere = {
		Duration = 0.55,
		Pose = function(t: number)
			local spin = curve({ { 0, 0 }, { 0.15, -30 }, { 0.85, 360 }, { 1, 360 } }, t) % 360
			local sweep = curve({ { 0, 0 }, { 0.15, -50 }, { 0.6, 40 }, { 1, 0 } }, t)
			return { Right = CFrame.Angles(0, rad(sweep), 0), Root = CFrame.Angles(0, rad(spin), 0) }
		end,
	},
	-- aspirateur : on tient fort, ça secoue et ça tire en arrière
	AspiraFantome = {
		Duration = 0.6,
		Pose = function(t: number)
			local shake = math.sin(t * 60) * 4 * (1 - t)
			local recoil = curve({ { 0, 0 }, { 0.15, 18 }, { 0.8, 12 }, { 1, 0 } }, t)
			return { Right = CFrame.Angles(rad(recoil + shake), rad(shake), 0), Root = CFrame.Angles(rad(-recoil * 0.4), 0, 0) }
		end,
	},
	-- on prend un coup : on part en arrière
	Hit = {
		Duration = 0.4,
		Pose = function(t: number)
			local lean = curve({ { 0, 0 }, { 0.25, 28 }, { 1, 0 } }, t)
			local arms = curve({ { 0, 0 }, { 0.25, 70 }, { 1, 0 } }, t)
			return {
				Root = CFrame.Angles(rad(lean), 0, 0),
				Right = CFrame.Angles(rad(arms), 0, rad(-arms * 0.4)),
				Left = CFrame.Angles(rad(arms), 0, rad(arms * 0.4)),
			}
		end,
	},
}

type Playing = { Character: Model, Move: any, Start: number, Layer: string }
local playing: { Playing } = {}

local function play(character: Model?, moveName: string)
	local move = MOVES[moveName]
	if not character or not move then
		return
	end
	local layer = if moveName == "Hit" then "hit" else "swing"
	-- un nouveau geste du même type remplace l'ancien
	for i = #playing, 1, -1 do
		if playing[i].Character == character and playing[i].Layer == layer then
			table.remove(playing, i)
		end
	end
	table.insert(playing, { Character = character, Move = move, Start = os.clock(), Layer = layer })
end

---------------------------------------------------------------- Effets autour des gestes

local function toolOf(character: Model, weaponId: string): Tool?
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("WeaponId") == weaponId then
			return child
		end
	end
	return nil
end

-- Traînée colorée derrière l'arme pendant le coup
local function flashTrail(character: Model, weaponId: string, duration: number)
	local tool = toolOf(character, weaponId)
	local trail = tool and tool:FindFirstChild("SwingTrail", true) :: Trail?
	if trail then
		trail.Enabled = true
		task.delay(duration, function()
			trail.Enabled = false
		end)
	end
end

-- Rayon vert de l'aspirateur, de l'arme jusqu'au voleur (ou droit devant)
local function vacuumBeam(character: Model, target: Vector3?)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local weapon = Weapons.ById.AspiraFantome
	local from = root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 0.6, 0)
	local to = target or (from + root.CFrame.LookVector * weapon.Range)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local beam = Instance.new("Part")
	beam.Name = "VacuumBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(weapon.Color[1], weapon.Color[2], weapon.Color[3])
	beam.Transparency = 0.35
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(length, 1.1, 1.1)
	beam.CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, rad(90), 0)
	beam.Parent = workspace
	TweenService:Create(beam, TweenInfo.new(0.45), { Transparency = 1, Size = Vector3.new(length, 0.2, 0.2) }):Play()
	Debris:AddItem(beam, 0.5)
end

---------------------------------------------------------------- API

local function characterOf(userId: any): Model?
	local other = type(userId) == "number" and Players:GetPlayerByUserId(userId)
	return other and other.Character or nil
end

--[[
	Un joueur frappe avec une arme.
	  animate = joue le geste (mon propre coup est joué tout de suite, sans attendre le serveur)
	  beam = dessine le rayon de l'aspirateur vers target (position du voleur visé, ou droit devant)
]]
function AnimView.swing(character: Model?, weaponId: string, target: Vector3?, animate: boolean, beam: boolean)
	if not character then
		return
	end
	local id = if MOVES[weaponId] then weaponId else "Batte"
	if animate then
		play(character, id)
		flashTrail(character, weaponId, MOVES[id].Duration)
	end
	if beam and weaponId == "AspiraFantome" then
		vacuumBeam(character, target)
	end
end

function AnimView.swingByUserId(userId: any, weaponId: string, target: Vector3?, animate: boolean, beam: boolean)
	AnimView.swing(characterOf(userId), weaponId, target, animate, beam)
end

function AnimView.hitByUserId(userId: any)
	play(characterOf(userId), "Hit")
end

function AnimView.start()
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		-- gestes en cours
		for i = #playing, 1, -1 do
			local entry = playing[i]
			local t = (now - entry.Start) / entry.Move.Duration
			local joints = if entry.Character.Parent then jointsOf(entry.Character) else nil
			if t >= 1 or not joints then
				if joints then
					for _, motor in joints do
						setLayer(motor, entry.Layer, nil)
					end
				end
				table.remove(playing, i)
			else
				local pose = entry.Move.Pose(t)
				for name, motor in joints do
					setLayer(motor, entry.Layer, pose[name])
				end
			end
		end
		-- les voleurs portent le fantôme bras levés
		for _, other in Players:GetPlayers() do
			local character = other.Character
			if character then
				local joints = jointsOf(character)
				local carrying = other:GetAttribute("CarryGhost") ~= nil
				local wave = if carrying then math.sin(now * 6) * 6 else 0
				setLayer(joints.Right, "carry", if carrying then CFrame.Angles(rad(165 + wave), 0, rad(-12)) else nil)
				setLayer(joints.Left, "carry", if carrying then CFrame.Angles(rad(165 - wave), 0, rad(12)) else nil)
			end
		end
	end)
end

return AnimView
