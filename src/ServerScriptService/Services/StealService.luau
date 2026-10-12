--[[
	StealService : voler un fantôme dans la base d'un autre joueur.

	Déroulé :
	  1. Le voleur maintient "Voler" 1,5 s sur un socle (le serveur chronomètre)
	  2. Le serveur vérifie tout (base pas verrouillée, distance, place libre...)
	  3. Le voleur porte le fantôme : ralenti, surligné en rouge pour tout le monde
	  4. Réussite : il entre dans SA base -> le fantôme change de propriétaire + annonce
	     Échec : le propriétaire le touche, un coup d'arme, 45 s écoulées, mort,
	             monstre de la Nuit Hantée -> le fantôme rentre chez lui
	  Pendant le vol, le fantôme reste sauvegardé chez son propriétaire (aucune perte
	  possible si un serveur plante).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local AnnounceService = require(script.Parent.AnnounceService)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Guard = require(script.Parent.Guard)
local Hooks = require(script.Parent.Hooks)
local LeaderboardService = require(script.Parent.LeaderboardService)

local StealService = {}

type Carry = {
	Thief: Player,
	Owner: Player,
	Base: any,
	Slot: number,
	GhostId: string,
	StartedAt: number,
	WindowStart: number,
	WindowPos: Vector3,
	Violations: number,
	LastTick: number,
	LastPos: Vector3,
	LeftBases: boolean, -- vu hors des deux bases (on ne livre pas à travers un mur)
	MinTime: number, -- temps minimum pour rentrer chez soi en marchant
	WindowSpeed: number?,
}

local carries: { [Player]: Carry } = {}
local holdStarts: { [Player]: { BaseIndex: number, Slot: number, Time: number } } = {}
local stunnedUntil: { [Player]: number } = {}
local slowedUntil: { [Player]: { Until: number, Speed: number } } = {}

local function setSpeed(player: Player, speed: number)
	local humanoid = Guard.humanoid(player)
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

local function normalSpeedFor(player: Player): number
	if (stunnedUntil[player] or 0) > os.clock() then
		return 4
	end
	local speed = if carries[player] then Config.CarrierWalkSpeed else Config.NormalWalkSpeed
	local slow = slowedUntil[player]
	if slow and slow.Until > os.clock() then
		speed = math.min(speed, slow.Speed)
	end
	return speed
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function StealService.isCarrying(player: Player): boolean
	return carries[player] ~= nil
end

function StealService.isBeingStolenFrom(player: Player): boolean
	for _, carry in carries do
		if carry.Owner == player then
			return true
		end
	end
	return false
end

local function clearCarry(carry: Carry)
	carries[carry.Thief] = nil
	carry.Thief:SetAttribute("CarryGhost", nil)
	carry.Thief:SetAttribute("CarryOwner", nil)
	carry.Thief:SetAttribute("CarryUntil", nil)
	setSpeed(carry.Thief, normalSpeedFor(carry.Thief))
end

-- Le fantôme rentre chez son propriétaire. reason = "Timeout", "Caught", "Bonk", "Monster", "Died", "Left", "Cheat", "NoSpace", "Trap"
function StealService.failCarry(thief: Player, reason: string, by: Player?)
	local carry = carries[thief]
	if not carry then
		return
	end
	clearCarry(carry)
	local owner = carry.Owner
	if owner.Parent and BaseService.getBase(owner) == carry.Base then
		BaseService.setStolenOut(owner, carry.Slot, false)
		EconomyService.refresh(owner)
		AnnounceService.notify(owner, "Recovered", { ghost = carry.GhostId }, "good")
		AnnounceService.effect("Recovered", { Position = BaseService.pedestalPosition(carry.Base, carry.Slot) })
	end

	local params = { ghost = carry.GhostId, owner = owner.DisplayName }
	if reason == "Timeout" then
		AnnounceService.notify(thief, "StealFailTimeout", params, "bad")
	elseif reason == "Caught" then
		AnnounceService.notify(thief, "StealFailCaught", params, "bad")
	elseif reason == "Bonk" then
		AnnounceService.notify(thief, "StealFailBonk", params, "bad")
		if by then
			AnnounceService.notify(by, "BonkHit", params, "good")
		end
	elseif reason == "Monster" then
		AnnounceService.notify(thief, "StealFailMonster", params, "bad")
	elseif reason == "Trap" then
		AnnounceService.notify(thief, "StealFailTrap", params, "bad")
	elseif reason == "NoSpace" then
		AnnounceService.notify(thief, "StealFailNoSpace", params, "bad")
	end
	if thief.Parent then
		AnnounceService.effect("StealFail", {}, thief)
	end
end

-- Le voleur est rentré dans sa base : le fantôme est à lui !
local function deliver(carry: Carry)
	local thief, owner = carry.Thief, carry.Owner
	if BaseService.getGhost(owner, carry.Slot) ~= carry.GhostId then
		clearCarry(carry) -- le fantôme n'existe plus chez le propriétaire : on annule sans rien donner
		return
	end
	local freeSlot = BaseService.findFreeSlot(thief)
	if not freeSlot then
		StealService.failCarry(thief, "NoSpace")
		return
	end
	clearCarry(carry)
	BaseService.removeGhost(owner, carry.Slot)
	BaseService.placeGhost(thief, carry.GhostId, freeSlot)

	local thiefData = DataService.get(thief)
	if thiefData then
		thiefData.TotalSteals += 1
	end
	LeaderboardService.recordSteal(thief)
	Hooks.fire("Steal", thief, 1)
	EconomyService.refresh(thief)
	EconomyService.refresh(owner)

	local thiefBase = BaseService.getBase(thief)
	AnnounceService.announce("AnnSteal", {
		thief = thief.DisplayName,
		owner = owner.DisplayName,
		ghost = carry.GhostId,
	}, "steal")
	AnnounceService.effect("StealSuccess", {
		Position = if thiefBase then BaseService.pedestalPosition(thiefBase, freeSlot) else nil,
		ThiefId = thief.UserId,
		OwnerId = owner.UserId,
		GhostId = carry.GhostId,
	})
end

local function onHoldBegin(player: Player, baseIndex: any, slot: any)
	if not Guard.isInt(baseIndex, 1, Config.BaseCount) or not Guard.isInt(slot, 1, Config.MaxPedestals) then
		return
	end
	-- limite très courte : un joueur peut relâcher et réappuyer vite sans être bloqué
	if not Guard.rate(player, "StealBegin", 0.05) then
		return
	end
	holdStarts[player] = { BaseIndex = baseIndex, Slot = slot, Time = os.clock() }
end

local function onSteal(player: Player, baseIndex: any, slot: any)
	if not Guard.isInt(baseIndex, 1, Config.BaseCount) or not Guard.isInt(slot, 1, Config.MaxPedestals) then
		return
	end
	if not Guard.rate(player, "Steal", 0.3) then
		return
	end
	-- Le maintien a-t-il vraiment duré assez longtemps ? (anti-triche)
	local hold = holdStarts[player]
	holdStarts[player] = nil
	if not hold or hold.BaseIndex ~= baseIndex or hold.Slot ~= slot then
		return
	end
	if os.clock() - hold.Time < Config.StealHoldDuration - 0.4 then
		return
	end

	if carries[player] then
		AnnounceService.notify(player, "AlreadyCarrying", nil, "bad")
		return
	end
	if not BaseService.getBase(player) or not DataService.get(player) then
		return
	end
	local base = BaseService.getBaseByIndex(baseIndex)
	local owner = base and base.Owner
	if not base or not owner or owner == player then
		return
	end
	if BaseService.isLocked(base) then
		AnnounceService.notify(player, "BaseIsLocked", nil, "bad")
		return
	end
	local ghostId = BaseService.getGhost(owner, slot)
	if not ghostId or BaseService.isStolenOut(owner, slot) then
		AnnounceService.notify(player, "AlreadyGone", nil, "bad")
		return
	end
	local root = Guard.root(player)
	if not root then
		return
	end
	-- il faut être dans la base volée, au même étage, près du socle (pas à travers un mur)
	local pedestal = BaseService.pedestalPosition(base, slot)
	local offset = root.Position - pedestal
	if offset.Magnitude > Config.StealRange + 2 or math.abs(offset.Y) > 7 or not BaseService.isInside(base, root.Position) then
		AnnounceService.notify(player, "TooFar", nil, "bad")
		return
	end
	if not BaseService.findFreeSlot(player) then
		AnnounceService.notify(player, "NoFreePedestalThief", nil, "bad")
		return
	end

	-- C'est parti !
	local t = os.clock()
	local home = BaseService.getBase(player)
	local walk = if home then (flat(home.Origin.Position) - flat(pedestal)).Magnitude else 0
	BaseService.setStolenOut(owner, slot, true)
	carries[player] = {
		Thief = player,
		Owner = owner,
		Base = base,
		Slot = slot,
		GhostId = ghostId,
		StartedAt = t,
		WindowStart = t,
		WindowPos = flat(root.Position),
		Violations = 0,
		LastTick = t,
		LastPos = flat(root.Position),
		LeftBases = false,
		MinTime = walk / (Config.CarrierWalkSpeed * 1.5),
	}
	player:SetAttribute("CarryGhost", ghostId)
	player:SetAttribute("CarryOwner", owner.UserId)
	player:SetAttribute("CarryUntil", workspace:GetServerTimeNow() + Config.StealTimeout)
	setSpeed(player, normalSpeedFor(player))
	EconomyService.refresh(owner)

	AnnounceService.notify(player, "StealGo", nil, "good")
	AnnounceService.notify(owner, "StealAlert", { thief = player.DisplayName, ghost = ghostId }, "bad")
	AnnounceService.effect("StealStart", {}, player)
	AnnounceService.effect("StealAlert", {}, owner)
end

-- Étourdit un joueur (il marche très lentement pendant "seconds" secondes)
function StealService.stun(player: Player, seconds: number)
	stunnedUntil[player] = os.clock() + seconds
	setSpeed(player, 4)
	task.delay(seconds, function()
		if player.Parent and (stunnedUntil[player] or 0) <= os.clock() then
			setSpeed(player, normalSpeedFor(player))
		end
	end)
end

-- Ralentit un joueur (toile d'araignée) pendant "seconds" secondes
function StealService.slow(player: Player, speed: number, seconds: number)
	slowedUntil[player] = { Until = os.clock() + seconds, Speed = speed }
	setSpeed(player, normalSpeedFor(player))
	task.delay(seconds, function()
		if player.Parent then
			setSpeed(player, normalSpeedFor(player))
		end
	end)
end

function StealService.isStunned(player: Player): boolean
	return (stunnedUntil[player] or 0) > os.clock()
end

-- Annule un vol en préparation (le joueur maintenait "Voler" sur un socle)
function StealService.cancelHold(player: Player)
	holdStarts[player] = nil
end

-- Les voleurs en cours (pour les armes)
function StealService.thieves(): { Player }
	local list = {}
	for thief in carries do
		table.insert(list, thief)
	end
	return list
end

-- Vérifie un vol en cours
local function check(carry: Carry, t: number)
	local thief = carry.Thief
	local root = Guard.root(thief)
	if not root then
		StealService.failCarry(thief, "Died")
		return
	end
	if t - carry.StartedAt > Config.StealTimeout then
		StealService.failCarry(thief, "Timeout")
		return
	end
	local pos = flat(root.Position)
	if Guard.teleportedWithin(thief, 0.5) then
		-- le serveur vient de le déplacer (ascenseur...) : on repart de sa nouvelle place
		carry.WindowStart, carry.WindowPos = t, pos
	else
		-- Anti-triche : un saut énorme d'un coup = téléportation
		local dt = t - carry.LastTick
		if (pos - carry.LastPos).Magnitude > Config.CarrierWalkSpeed * dt * 2 + 5 then
			StealService.failCarry(thief, "Cheat")
			return
		end
		-- Anti-triche vitesse : la distance parcourue chaque seconde
		if t - carry.WindowStart >= 1 then
			local elapsed = t - carry.WindowStart
			local speed = (pos - carry.WindowPos).Magnitude / elapsed
			local allowed = math.max(normalSpeedFor(thief), carry.WindowSpeed or 0) * 1.25 + 2
			if speed > allowed then
				carry.Violations += 1
			else
				carry.Violations = math.max(0, carry.Violations - 0.5)
			end
			carry.WindowStart = t
			carry.WindowPos = pos
			if carry.Violations >= 2 then
				StealService.failCarry(thief, "Cheat")
				return
			end
		end
	end
	carry.WindowSpeed = normalSpeedFor(thief)
	carry.LastTick, carry.LastPos = t, pos

	local thiefBase = BaseService.getBase(thief)
	local inThiefBase = thiefBase ~= nil and BaseService.isInside(thiefBase, root.Position)
	if not inThiefBase and not BaseService.isInside(carry.Base, root.Position) then
		carry.LeftBases = true
	end
	-- Arrivé dans sa base ? (en étant vraiment sorti de la base volée, et pas plus vite qu'à pied)
	if inThiefBase and carry.LeftBases and t - carry.StartedAt >= carry.MinTime then
		deliver(carry)
		return
	end
	-- Rattrapé par le propriétaire ?
	local ownerRoot = Guard.root(carry.Owner)
	if ownerRoot and (ownerRoot.Position - root.Position).Magnitude <= Config.RecoverRange then
		StealService.failCarry(thief, "Caught")
	end
end

-- Vérifie tous les vols en cours (10 fois par seconde). Une erreur sur un vol ne bloque pas les autres.
local function monitor()
	local t = os.clock()
	local list = {}
	for _, carry in carries do
		table.insert(list, carry)
	end
	for _, carry in list do
		if carries[carry.Thief] == carry then
			Guard.safely("StealCheck", check, carry, t)
		end
	end
end

-- Appelé quand un joueur quitte le jeu (AVANT la sauvegarde de ses données)
function StealService.onPlayerRemoving(player: Player)
	holdStarts[player] = nil
	stunnedUntil[player] = nil
	slowedUntil[player] = nil
	-- Le voleur part : le fantôme rentre chez lui
	if carries[player] then
		StealService.failCarry(player, "Left")
	end
	-- Le propriétaire part pendant qu'on le vole : cadeau pour le voleur !
	for thief, carry in carries do
		if carry.Owner == player then
			local freeSlot = BaseService.findFreeSlot(thief)
			clearCarry(carry)
			if freeSlot and BaseService.getGhost(player, carry.Slot) == carry.GhostId then
				BaseService.removeGhost(player, carry.Slot)
				BaseService.placeGhost(thief, carry.GhostId, freeSlot)
				EconomyService.refresh(thief)
				AnnounceService.notify(thief, "OwnerLeftGift", { owner = player.DisplayName, ghost = carry.GhostId }, "good")
				AnnounceService.effect("Gift", {}, thief)
			end
		end
	end
end

function StealService.start()
	Remotes.get("StealBegin").OnServerEvent:Connect(onHoldBegin)
	Remotes.get("Steal").OnServerEvent:Connect(onSteal)
	Players.PlayerRemoving:Connect(function(player)
		-- sécurité si l'ordre des événements change
		if carries[player] then
			StealService.failCarry(player, "Left")
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			Guard.safely("StealMonitor", monitor)
		end
	end)
end

return StealService
