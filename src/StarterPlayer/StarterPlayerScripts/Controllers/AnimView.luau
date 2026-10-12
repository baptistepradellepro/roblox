--[[
	AnimView : les gestes des personnages avec les objets.

	Coups d'arme : on utilise les animations OFFICIELLES de Roblox, déjà présentes dans
	chaque personnage (le script "Animate" que Roblox met dans tous les avatars). On lui
	envoie le message "toolanim" = "Slash" (coup d'épée classique) ou "Lunge" (coup en
	avant), exactement comme l'épée classique de Roblox. L'animation est jouée par le
	joueur qui frappe et Roblox la montre à tout le monde.

	En plus, pour tout le monde : traînée colorée derrière l'arme, et rayon vert de
	l'Aspira-Fantôme vers le voleur visé.

	Le voleur porte le fantôme bras levés : là, on pivote les épaules par le code
	(pas d'animation officielle pour ça). La position de repos de chaque épaule est
	gardée sur l'épaule elle-même (attribut "RestC0"), pour toujours y revenir.
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

---------------------------------------------------------------- Coups d'arme

local function toolOf(character: Model, weaponId: string): Tool?
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("WeaponId") == weaponId then
			return child
		end
	end
	return nil
end

-- Demande au script "Animate" de Roblox de jouer le coup ("Slash" ou "Lunge").
-- À faire sur l'écran du joueur qui frappe : c'est lui qui joue l'animation.
function AnimView.playToolAnim(tool: Tool, animName: string)
	local old = tool:FindFirstChild("toolanim")
	if old then
		old:Destroy()
	end
	local message = Instance.new("StringValue")
	message.Name = "toolanim"
	message.Value = animName
	message.Parent = tool
end

-- Traînée colorée derrière l'arme pendant le coup
local function flashTrail(character: Model, weaponId: string)
	local tool = toolOf(character, weaponId)
	local trail = tool and tool:FindFirstChild("SwingTrail", true) :: Trail?
	if trail then
		trail.Enabled = true
		task.delay(0.35, function()
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

local function characterOf(userId: any): Model?
	local other = type(userId) == "number" and Players:GetPlayerByUserId(userId)
	return other and other.Character or nil
end

--[[
	Les effets autour d'un coup d'arme (traînée, rayon de l'aspirateur).
	  trail = allume la traînée (mon propre coup l'allume tout de suite, sans attendre)
	  beam = dessine le rayon de l'aspirateur vers target (le voleur visé, ou droit devant)
]]
function AnimView.swing(character: Model?, weaponId: string, target: Vector3?, trail: boolean, beam: boolean)
	if not character then
		return
	end
	if trail then
		flashTrail(character, weaponId)
	end
	if beam and weaponId == "AspiraFantome" then
		vacuumBeam(character, target)
	end
end

function AnimView.swingByUserId(userId: any, weaponId: string, target: Vector3?, trail: boolean, beam: boolean)
	AnimView.swing(characterOf(userId), weaponId, target, trail, beam)
end

---------------------------------------------------------------- Porter le fantôme

local function findMotor(character: Model, names: { string }): Motor6D?
	for _, name in names do
		local found = character:FindFirstChild(name, true)
		if found and found:IsA("Motor6D") then
			return found
		end
	end
	return nil
end

-- Tourne une épaule (dans les axes du torse) ; nil = position de repos
local function pose(motor: Motor6D?, rotation: CFrame?)
	if not motor then
		return
	end
	local rest = motor:GetAttribute("RestC0")
	if rotation then
		if typeof(rest) ~= "CFrame" then
			rest = motor.C0
			motor:SetAttribute("RestC0", rest)
		end
		motor.C0 = CFrame.new(rest.Position) * rotation * rest.Rotation
	elseif typeof(rest) == "CFrame" then
		motor.C0 = rest
		motor:SetAttribute("RestC0", nil)
	end
end

-- Les épaules de chaque personnage, cherchées une seule fois (pas à chaque image)
type Shoulders = { Character: Model, Right: Motor6D?, Left: Motor6D? }
local shoulders: { [Player]: Shoulders } = {}

local function shouldersOf(other: Player, character: Model): Shoulders
	local entry = shoulders[other]
	if not entry or entry.Character ~= character or (entry.Right and not entry.Right.Parent) then
		entry = {
			Character = character,
			Right = findMotor(character, { "RightShoulder", "Right Shoulder" }),
			Left = findMotor(character, { "LeftShoulder", "Left Shoulder" }),
		}
		shoulders[other] = entry
	end
	return entry
end

function AnimView.start()
	local raised: { [Player]: boolean } = {}
	Players.PlayerRemoving:Connect(function(other)
		shoulders[other] = nil
		raised[other] = nil
	end)
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, other in Players:GetPlayers() do
			local character = other.Character
			local carrying = other:GetAttribute("CarryGhost") ~= nil
			if character and (carrying or raised[other]) then
				local entry = shouldersOf(other, character)
				local right, left = entry.Right, entry.Left
				if carrying then
					local wave = math.sin(now * 6) * 5
					pose(right, CFrame.Angles(rad(160 + wave), 0, rad(-10)))
					pose(left, CFrame.Angles(rad(160 - wave), 0, rad(10)))
					raised[other] = true
				else
					pose(right, nil)
					pose(left, nil)
					raised[other] = nil
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(other)
		raised[other] = nil
	end)
end

return AnimView
