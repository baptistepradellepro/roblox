--[[
	BaseService : les bases des joueurs.
	  - donne une base libre à chaque joueur qui arrive
	  - gère les socles (quel fantôme est posé où)
	  - gère le verrou (60 s, recharge 2 min) et le bouclier débutant
	  - fait apparaître le joueur dans sa base

	Le serveur écrit l'état dans des "attributs" (sur les modèles de base et les socles),
	et chaque joueur affiche les fantômes de son côté. Le client ne décide jamais rien.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local AnnounceService = require(script.Parent.AnnounceService)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Guard)
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
	Barrier: BasePart?,
	StolenOut: { [number]: boolean },
}

local bases: { [number]: Base } = {}
local byPlayer: { [Player]: Base } = {}

-- Ordre d'attribution : d'abord les bases du centre (plus d'action)
local ASSIGN_ORDER = { 3, 9, 4, 10, 2, 8, 5, 11, 1, 7, 6, 12 }

local LOCKED_SLOT_COLOR = Color3.fromRGB(35, 30, 40)
local PEDESTAL_COLOR = Color3.fromRGB(60, 50, 75)

local function now(): number
	return workspace:GetServerTimeNow()
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

function BaseService.unlockedSlots(player: Player): number
	local data = DataService.get(player)
	local rebirths = if data then data.Rebirths else 0
	return math.min(Config.StartPedestals + rebirths, Config.MaxPedestals)
end

-- Met à jour les attributs des socles d'après les données sauvegardées
function BaseService.refreshSlots(player: Player)
	local base = byPlayer[player]
	local data = DataService.get(player)
	if not base or not data then
		return
	end
	local unlocked = BaseService.unlockedSlots(player)
	for slot, ped in base.Pedestals do
		ped:SetAttribute("GhostId", data.Slots[tostring(slot)] or "")
		ped:SetAttribute("Stolen", base.StolenOut[slot] == true)
		local isUnlocked = slot <= unlocked
		ped:SetAttribute("Unlocked", isUnlocked)
		ped.Color = if isUnlocked then PEDESTAL_COLOR else LOCKED_SLOT_COLOR
		local rim = ped:FindFirstChild("Rim") :: BasePart?
		if rim then
			rim.Transparency = if isUnlocked then 0 else 0.85
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
		and localPos.Y < MapBuilder.WALL_HEIGHT + 8
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

local function setBarrier(base: Base, on: boolean)
	if on and not base.Barrier then
		local barrier = Instance.new("Part")
		barrier.Name = "Barrier"
		barrier.Anchored = true
		barrier.CanCollide = true
		barrier.CanTouch = false
		barrier.CastShadow = false
		barrier.Size = Vector3.new(10, MapBuilder.WALL_HEIGHT, 0.6)
		barrier.CFrame = base.Origin * CFrame.new(0, MapBuilder.WALL_HEIGHT / 2, -MapBuilder.BASE_DEPTH / 2)
		barrier.Color = base.Model:GetAttribute("Color") or Color3.fromRGB(255, 80, 80)
		barrier.Material = Enum.Material.ForceField
		barrier.Transparency = 0.1
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
		ped.Color = PEDESTAL_COLOR
	end
end

function BaseService.start()
	-- Le joueur appuie sur "Verrouiller"
	Remotes.get("RequestLock").OnServerEvent:Connect(function(player)
		if not Guard.rate(player, "Lock", 0.5) then
			return
		end
		local ok, key, params = BaseService.lock(player)
		if ok then
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
