--[[
	BaseService : les bases des joueurs.
	  - donne une base libre à chaque joueur qui arrive
	  - gère les socles (quel fantôme est posé où) et l'étage 2 achetable
	  - l'ascenseur entre le rez-de-chaussée et l'étage
	  - gère le verrou (45 s, recharge 2 min) et le bouclier débutant
	  - la barrière du verrou bloque tout le monde sauf le propriétaire (groupes de collision)
	  - fait apparaître le joueur dans sa base

	Le serveur écrit l'état dans des "attributs" (sur les modèles de base et les socles),
	et chaque joueur affiche les fantômes de son côté. Le client ne décide jamais rien.
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local AnnounceService = require(script.Parent.AnnounceService)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Guard)
local Hooks = require(script.Parent.Hooks)
local MapBuilder = require(script.Parent.MapBuilder)

local BaseService = {}

export type Base = {
	Index: number,
	Model: Model,
	Origin: CFrame,
	Pedestals: { [number]: BasePart },
	Spawn: SpawnLocation,
	Owner: Player?,
	LockedUntil: number,
	LockReadyAt: number,
	Barrier: Instance?,
	StolenOut: { [number]: boolean },
}

local bases: { [number]: Base } = {}
local byPlayer: { [Player]: Base } = {}

-- Ordre d'attribution : d'abord les bases du centre (plus d'action)
local ASSIGN_ORDER = { 3, 9, 4, 10, 2, 8, 5, 11, 1, 7, 6, 12 }

local PEDESTAL_COLOR = Color3.fromRGB(60, 50, 75)

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Groupes de collision : la barrière de la base N ("GateN") ne bloque pas le personnage
-- de son propriétaire ("OwnerN"), mais bloque tous les autres. C'est le serveur qui décide,
-- donc ça marche même si le joueur a un écran lent à charger.
local collisionGroupsReady = false

local function gateGroup(index: number): string
	return "Gate" .. index
end

local function ownerGroup(index: number): string
	return "Owner" .. index
end

local function setupCollisionGroups()
	local ok, err = pcall(function()
		for index in bases do
			for _, name in { gateGroup(index), ownerGroup(index) } do
				if not PhysicsService:IsCollisionGroupRegistered(name) then
					PhysicsService:RegisterCollisionGroup(name)
				end
			end
			PhysicsService:CollisionGroupSetCollidable(gateGroup(index), ownerGroup(index), false)
		end
	end)
	collisionGroupsReady = ok
	if not ok then
		warn("[BaseService] Groupes de collision indisponibles : " .. tostring(err))
	end
end

-- Range toutes les pièces du personnage dans le groupe du propriétaire de la base
local function applyOwnerGroup(player: Player, character: Model)
	local base = byPlayer[player]
	if not collisionGroupsReady or not base then
		return
	end
	local group = ownerGroup(base.Index)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
	-- les accessoires et le fantôme porté arrivent parfois après
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end)
end

function BaseService.init(map: Model)
	local folder = map:WaitForChild("Bases")
	for _, model in folder:GetChildren() do
		if model:IsA("Model") then
			local index = model:GetAttribute("Index")
			local pedestals = {}
			for _, ped in model:WaitForChild("Pedestals"):GetChildren() do
				pedestals[ped:GetAttribute("Slot")] = ped
			end
			bases[index] = {
				Index = index,
				Model = model,
				Origin = model:GetAttribute("Origin") or MapBuilder.baseOrigin(index),
				Pedestals = pedestals,
				Spawn = model:WaitForChild("Spawn") :: SpawnLocation,
				Owner = nil,
				LockedUntil = 0,
				LockReadyAt = 0,
				Barrier = nil,
				StolenOut = {},
			}
		end
	end
	setupCollisionGroups()
end

function BaseService.getBase(player: Player): Base?
	return byPlayer[player]
end

function BaseService.getBaseByIndex(index: number): Base?
	return bases[index]
end

function BaseService.allBases(): { [number]: Base }
	return bases
end

---------------------------------------------------------------- Socles

function BaseService.floorsOf(player: Player): number
	local data = DataService.get(player)
	return math.clamp(if data then data.Floors or 1 else 1, 1, 2)
end

function BaseService.unlockedSlots(player: Player): number
	return math.min(Config.PedestalsPerFloor * BaseService.floorsOf(player), Config.MaxPedestals)
end

-- Affiche ou cache l'étage 2 d'une base (sol, murs, socles, plaques, ascenseur)
local function setFloorVisible(base: Base, visible: boolean)
	local parts = {}
	local floor2 = base.Model:FindFirstChild("Floor2")
	if floor2 then
		for _, d in floor2:GetDescendants() do
			table.insert(parts, d)
		end
	end
	for _, ped in base.Pedestals do
		if ped:GetAttribute("Floor") == 2 then
			table.insert(parts, ped)
			for _, d in ped:GetDescendants() do
				table.insert(parts, d)
			end
		end
	end
	for _, p in parts do
		if p:IsA("BasePart") and p:GetAttribute("BaseTransparency") ~= nil then
			p.Transparency = if visible then p:GetAttribute("BaseTransparency") else 1
			p.CanCollide = visible and p:GetAttribute("BaseCollide") == true
			p.CanTouch = visible and p:GetAttribute("BaseTouch") == true
		end
	end
	base.Model:SetAttribute("Floors", if visible then 2 else 1)
end

-- Met à jour les attributs des socles d'après les données sauvegardées
function BaseService.refreshSlots(player: Player)
	local base = byPlayer[player]
	local data = DataService.get(player)
	if not base or not data then
		return
	end
	setFloorVisible(base, BaseService.floorsOf(player) >= 2)
	local unlocked = BaseService.unlockedSlots(player)
	for slot, ped in base.Pedestals do
		ped:SetAttribute("GhostId", data.Slots[tostring(slot)] or "")
		ped:SetAttribute("Stolen", base.StolenOut[slot] == true)
		ped:SetAttribute("Unlocked", slot <= unlocked)
		ped:SetAttribute("Stored", math.floor(data.Stored and data.Stored[tostring(slot)] or 0))
	end
end

-- Pièces en attente sur un socle (affichées au-dessus de la plaque verte)
function BaseService.showStored(player: Player, slot: number, amount: number)
	local base = byPlayer[player]
	local ped = base and base.Pedestals[slot]
	if ped then
		local shown = math.floor(amount)
		if ped:GetAttribute("Stored") ~= shown then
			ped:SetAttribute("Stored", shown)
		end
	end
end

function BaseService.getGhost(player: Player, slot: number): string?
	local data = DataService.get(player)
	return data and data.Slots[tostring(slot)]
end

function BaseService.findFreeSlot(player: Player): number?
	local base = byPlayer[player]
	local data = DataService.get(player)
	if not base or not data then
		return nil
	end
	for slot = 1, BaseService.unlockedSlots(player) do
		if data.Slots[tostring(slot)] == nil and not base.StolenOut[slot] then
			return slot
		end
	end
	return nil
end

-- Appelé à chaque fois qu'un joueur reçoit un fantôme (branché sur le Fantômédex dans Main)
BaseService.onGhostPlaced = nil :: ((Player, string) -> ())?

-- Pose un fantôme sur un socle libre (ou sur le socle donné). Renvoie le numéro du socle.
function BaseService.placeGhost(player: Player, ghostId: string, slot: number?): number?
	local base = byPlayer[player]
	local data = DataService.get(player)
	if not base or not data then
		return nil
	end
	local target = slot or BaseService.findFreeSlot(player)
	if not target then
		return nil
	end
	data.Slots[tostring(target)] = ghostId
	base.StolenOut[target] = nil
	local ped = base.Pedestals[target]
	ped:SetAttribute("GhostId", ghostId)
	ped:SetAttribute("Stolen", false)
	if BaseService.onGhostPlaced then
		BaseService.onGhostPlaced(player, ghostId)
	end
	return target
end

-- Retire le fantôme d'un socle. Renvoie son Id.
function BaseService.removeGhost(player: Player, slot: number): string?
	local base = byPlayer[player]
	local data = DataService.get(player)
	if not base or not data then
		return nil
	end
	local key = tostring(slot)
	local ghostId = data.Slots[key]
	data.Slots[key] = nil
	base.StolenOut[slot] = nil
	local ped = base.Pedestals[slot]
	if ped then
		ped:SetAttribute("GhostId", "")
		ped:SetAttribute("Stolen", false)
	end
	return ghostId
end

function BaseService.clearAllGhosts(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.Slots = {}
	data.Stored = {}
	local base = byPlayer[player]
	if base then
		base.StolenOut = {}
	end
	BaseService.refreshSlots(player)
end

-- "Volé" = en train d'être porté par un voleur (il ne rapporte plus rien)
function BaseService.setStolenOut(player: Player, slot: number, value: boolean)
	local base = byPlayer[player]
	if not base then
		return
	end
	base.StolenOut[slot] = if value then true else nil
	local ped = base.Pedestals[slot]
	if ped then
		ped:SetAttribute("Stolen", value)
	end
end

function BaseService.isStolenOut(player: Player, slot: number): boolean
	local base = byPlayer[player]
	return base ~= nil and base.StolenOut[slot] == true
end

-- Les fantômes qui rapportent (posés et pas en train d'être volés)
function BaseService.activeGhostIds(player: Player): { string }
	local base = byPlayer[player]
	local data = DataService.get(player)
	local list = {}
	if not base or not data then
		return list
	end
	for key, ghostId in data.Slots do
		local slot = tonumber(key)
		if slot and not base.StolenOut[slot] then
			table.insert(list, ghostId)
		end
	end
	return list
end

function BaseService.pedestalPosition(base: Base, slot: number): Vector3
	local ped = base.Pedestals[slot]
	local cf = ped and ped:GetAttribute("GhostCFrame")
	if typeof(cf) == "CFrame" then
		return cf.Position
	end
	return base.Origin.Position
end

-- Est-ce que cette position est à l'intérieur de la base ?
function BaseService.isInside(base: Base, position: Vector3): boolean
	local localPos = base.Origin:PointToObjectSpace(position)
	return math.abs(localPos.X) < MapBuilder.BASE_WIDTH / 2
		and math.abs(localPos.Z) < MapBuilder.BASE_DEPTH / 2
		and localPos.Y > -5
		and localPos.Y < MapBuilder.FLOOR2_Y + MapBuilder.FLOOR2_WALL + 6
end

function BaseService.baseAt(position: Vector3): Base?
	for _, base in bases do
		if BaseService.isInside(base, position) then
			return base
		end
	end
	return nil
end

---------------------------------------------------------------- Verrou

function BaseService.isLocked(base: Base): boolean
	return now() < base.LockedUntil
end

-- Une barrière à barreaux rouges et blancs ferme l'entrée de la base
local function makeBarrierPart(model: Model, size: Vector3, cf: CFrame, color: Color3, neon: boolean, name: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Parent = model
	return p
end

local RED = Color3.fromRGB(230, 40, 50)
local WHITE = Color3.fromRGB(250, 250, 250)

local function setBarrier(base: Base, on: boolean)
	if on and not base.Barrier then
		local front = base.Origin * CFrame.new(0, 0, -MapBuilder.BASE_DEPTH / 2)
		local barrier = Instance.new("Model")
		barrier.Name = "Barrier"
		-- le "mur" invisible qui bloque vraiment (les barreaux sont décoratifs)
		local wallSize = Vector3.new(10, MapBuilder.WALL_HEIGHT, 1)
		local collider = makeBarrierPart(barrier, wallSize, front * CFrame.new(0, MapBuilder.WALL_HEIGHT / 2, 0), WHITE, false, "Collider")
		collider.Transparency = 1
		collider.CanCollide = true
		if collisionGroupsReady then
			collider.CollisionGroup = gateGroup(base.Index)
		end
		barrier.PrimaryPart = collider
		for i = 0, 6 do
			local red = i % 2 == 0
			local barCf = front * CFrame.new(-4.5 + i * 1.5, 5.5, 0) * CFrame.Angles(0, 0, math.rad(90))
			local bar = makeBarrierPart(barrier, Vector3.new(11, 0.5, 0.5), barCf, if red then RED else WHITE, red, "Bar")
			bar.Shape = Enum.PartType.Cylinder
		end
		for _, y in { 2.5, 8.5 } do
			for i = 0, 4 do
				local red = i % 2 == 0
				makeBarrierPart(barrier, Vector3.new(2, 0.7, 0.7), front * CFrame.new(-4 + i * 2, y, 0), if red then RED else WHITE, red, "Rail")
			end
		end
		barrier.Parent = base.Model
		base.Barrier = barrier
	elseif not on and base.Barrier then
		base.Barrier:Destroy()
		base.Barrier = nil
	end
end

local function applyLock(base: Base, duration: number, isShield: boolean)
	local t = now()
	base.LockedUntil = t + duration
	base.LockReadyAt = if isShield then base.LockedUntil else base.LockedUntil + Config.LockCooldown
	base.Model:SetAttribute("LockedUntil", base.LockedUntil)
	base.Model:SetAttribute("LockReadyAt", base.LockReadyAt)
	base.Model:SetAttribute("Shield", isShield)
	setBarrier(base, true)
end

local function unlock(base: Base)
	base.LockedUntil = 0
	base.Model:SetAttribute("LockedUntil", 0)
	base.Model:SetAttribute("Shield", false)
	setBarrier(base, false)
end

-- Le joueur demande à verrouiller sa base. Renvoie (ok, cléDeMessage, paramètres)
function BaseService.lock(player: Player): (boolean, string?, { [string]: any }?)
	local base = byPlayer[player]
	if not base then
		return false, "NotAllowed"
	end
	local t = now()
	if BaseService.isLocked(base) then
		return false, "LockOn"
	end
	if t < base.LockReadyAt then
		return false, "LockNotReady", { time = Format.time(base.LockReadyAt - t) }
	end
	local duration = if player:GetAttribute("LongLock") then Config.LockDurationPass else Config.LockDuration
	applyLock(base, duration, false)
	return true, "LockOn"
end

function BaseService.giveShield(player: Player, duration: number)
	local base = byPlayer[player]
	if base then
		applyLock(base, duration, true)
	end
end

-- Renvoie hors de la base les intrus quand elle est verrouillée
local function pushIntruders(base: Base)
	for _, other in Players:GetPlayers() do
		if other ~= base.Owner then
			local character = other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and BaseService.isInside(base, root.Position) then
				local outside = base.Origin * CFrame.new(math.random(-4, 4), 3, -MapBuilder.BASE_DEPTH / 2 - 6)
				character:PivotTo(outside)
			end
		end
	end
end

---------------------------------------------------------------- Joueurs

function BaseService.teleportHome(player: Player)
	local base = byPlayer[player]
	local character = player.Character
	if base and character then
		character:PivotTo(base.Spawn.CFrame * CFrame.new(0, 3.5, 0))
	end
end

function BaseService.spawnCharacter(player: Player)
	if not player.Parent then
		return
	end
	local ok, err = pcall(function()
		player:LoadCharacter()
	end)
	if not ok then
		warn("[BaseService] LoadCharacter a échoué : " .. tostring(err))
	end
end

local function onCharacterAdded(player: Player, character: Model)
	applyOwnerGroup(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = Config.NormalWalkSpeed
	humanoid.Died:Connect(function()
		task.delay(Config.RespawnDelay, function()
			if player.Parent and player.Character == character then
				BaseService.spawnCharacter(player)
			end
		end)
	end)
	-- Sécurité : si le joueur n'est pas apparu dans sa base, on l'y amène
	task.delay(0.3, function()
		local base = byPlayer[player]
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if base and root and not BaseService.isInside(base, root.Position) then
			BaseService.teleportHome(player)
		end
	end)
end

function BaseService.assign(player: Player): Base?
	local chosen: Base? = nil
	for _, index in ASSIGN_ORDER do
		local base = bases[index]
		if base and not base.Owner then
			chosen = base
			break
		end
	end
	if not chosen then
		warn("[BaseService] Plus de base libre pour " .. player.Name)
		return nil
	end
	local base = chosen :: Base
	base.Owner = player
	base.StolenOut = {}
	byPlayer[player] = base
	base.Model:SetAttribute("OwnerUserId", player.UserId)
	base.Model:SetAttribute("OwnerName", player.DisplayName)
	player:SetAttribute("BaseIndex", base.Index)
	player.RespawnLocation = base.Spawn
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	BaseService.refreshSlots(player)
	return base
end

function BaseService.release(player: Player)
	local base = byPlayer[player]
	if not base then
		return
	end
	byPlayer[player] = nil
	base.Owner = nil
	base.StolenOut = {}
	unlock(base)
	base.LockReadyAt = 0
	base.Model:SetAttribute("LockReadyAt", 0)
	base.Model:SetAttribute("OwnerUserId", 0)
	base.Model:SetAttribute("OwnerName", "")
	for _, ped in base.Pedestals do
		ped:SetAttribute("GhostId", "")
		ped:SetAttribute("Stolen", false)
		ped:SetAttribute("Unlocked", false)
		ped:SetAttribute("Stored", 0)
		ped.Color = PEDESTAL_COLOR
	end
	setFloorVisible(base, false)
end

-- Ascenseur : la plaque violette du fond monte à l'étage, celle de l'étage redescend
local elevatorCooldown: { [Player]: number } = {}

local function useElevator(base: Base, hit: BasePart, up: boolean)
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player or not base.Owner or base.Model:GetAttribute("Floors") ~= 2 then
		return
	end
	if (elevatorCooldown[player] or 0) > os.clock() or not Guard.root(player) then
		return
	end
	elevatorCooldown[player] = os.clock() + 1
	local y = if up then MapBuilder.FLOOR2_Y + 3 else 3
	character:PivotTo(base.Origin * CFrame.new(0, y, 6))
	AnnounceService.effect("Elevator", { Position = base.Origin.Position }, player)
end

-- Débloque l'étage 2 d'un joueur (appelé par EconomyService après le paiement)
function BaseService.unlockFloor(player: Player)
	local data = DataService.get(player)
	if data then
		data.Floors = 2
		BaseService.refreshSlots(player)
	end
end

function BaseService.start()
	for _, base in bases do
		local upPad = base.Model:FindFirstChild("UpPad") :: BasePart?
		local floor2 = base.Model:FindFirstChild("Floor2")
		local downPad = floor2 and floor2:FindFirstChild("DownPad") :: BasePart?
		if upPad then
			upPad.Touched:Connect(function(hit)
				useElevator(base, hit, true)
			end)
		end
		if downPad then
			downPad.Touched:Connect(function(hit)
				useElevator(base, hit, false)
			end)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		elevatorCooldown[player] = nil
	end)

	-- Le joueur appuie sur "Verrouiller"
	Remotes.get("RequestLock").OnServerEvent:Connect(function(player)
		if not Guard.rate(player, "Lock", 0.5) then
			return
		end
		local ok, key, params = BaseService.lock(player)
		if ok then
			Hooks.fire("Lock", player, 1)
			AnnounceService.notify(player, "LockOn", nil, "good")
			AnnounceService.effect("Lock", { Position = BaseService.getBase(player).Origin.Position }, nil)
		elseif key then
			AnnounceService.notify(player, key, params, "bad")
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local t = now()
			for _, base in bases do
				if base.LockedUntil > 0 then
					if t >= base.LockedUntil then
						unlock(base)
					elseif base.Owner then
						pushIntruders(base)
					end
				end
			end
		end
	end)
end

return BaseService
