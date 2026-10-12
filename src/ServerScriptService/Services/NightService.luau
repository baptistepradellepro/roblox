--[[
	NightService : la Nuit Hantée.
	  - toutes les 10 minutes : 8 min de jour, puis 2 min de nuit
	  - la nuit : plus de fantômes rares sur le chemin, un fantôme spécial garanti,
	    et Gloutrouille (le monstre) poursuit les joueurs qui sont HORS de leur base
	  - attrapé : "BOUH !", retour à la base, -5 % de pièces, et on lâche le fantôme volé

	Le serveur calcule la position du monstre (anti-triche) et la publie sur une pièce
	invisible "GloutrouilleAnchor". Chaque joueur dessine le vrai monstre et le fait glisser
	en douceur vers cette position.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local GhostData = require(Shared:WaitForChild("GhostData"))

local AnnounceService = require(script.Parent.AnnounceService)
local BaseService = require(script.Parent.BaseService)
local EconomyService = require(script.Parent.EconomyService)
local GhostService = require(script.Parent.GhostService)
local Guard = require(script.Parent.Guard)
local StealService = require(script.Parent.StealService)

local NightService = {}

local HOVER = 5 -- hauteur du monstre au-dessus du sol
local TICK = 1 / 15
local CATCH_IMMUNITY = 6 -- secondes de répit après avoir été attrapé

local anchor: BasePart? = nil
local immuneUntil: { [Player]: number } = {}
local patrolDir = 1

local function now(): number
	return workspace:GetServerTimeNow()
end

local function setState(active: boolean, endsAt: number, nextAt: number)
	ReplicatedStorage:SetAttribute("NightActive", active)
	ReplicatedStorage:SetAttribute("NightEndsAt", endsAt)
	ReplicatedStorage:SetAttribute("NextNightAt", nextAt)
end

function NightService.isNight(): boolean
	return ReplicatedStorage:GetAttribute("NightActive") == true
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Un point est-il interdit au monstre ? (dans une base, avec une marge)
local function blocked(position: Vector3): boolean
	for _, base in BaseService.allBases() do
		local localPos = base.Origin:PointToObjectSpace(position)
		if math.abs(localPos.X) < 20 and math.abs(localPos.Z) < 18 then
			return true
		end
	end
	return false
end

-- Choisit la proie : le joueur le plus proche hors de sa base (les voleurs attirent plus)
local function pickTarget(from: Vector3): (Player?, BasePart?)
	local t = os.clock()
	local best, bestRoot, bestScore = nil, nil, math.huge
	for _, player in Players:GetPlayers() do
		local root = Guard.root(player)
		if root and (immuneUntil[player] or 0) < t and not BaseService.baseAt(root.Position) then
			local score = (flat(root.Position) - flat(from)).Magnitude
			if player:GetAttribute("CarryGhost") then
				score *= 0.6
			end
			if score < bestScore then
				best, bestRoot, bestScore = player, root, score
			end
		end
	end
	return best, bestRoot
end

local function catch(player: Player, root: BasePart)
	immuneUntil[player] = os.clock() + CATCH_IMMUNITY
	AnnounceService.effect("MonsterCatch", { Position = root.Position, PlayerId = player.UserId })
	if StealService.isCarrying(player) then
		StealService.failCarry(player, "Monster")
	end
	local lost = EconomyService.takePercent(player, Config.MonsterCoinPenalty)
	AnnounceService.notify(player, "MonsterCaughtYou", { coins = Format.short(lost) }, "bad")
	AnnounceService.announce("AnnCaught", { player = player.DisplayName }, "night")
	BaseService.teleportHome(player)
end

local function spawnMonster()
	if anchor then
		anchor:Destroy()
	end
	local part = Instance.new("Part")
	part.Name = "GloutrouilleAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one
	-- il sort du portail de départ
	part.CFrame = CFrame.new(Config.PathStartX, HOVER, Config.PathZ)
	part.Parent = workspace
	anchor = part
end

local function removeMonster()
	if anchor then
		anchor:Destroy()
		anchor = nil
	end
end

-- Un pas de déplacement du monstre
local function stepMonster(dt: number)
	local part = anchor
	if not part then
		return
	end
	local pos = part.Position
	local target, root = pickTarget(pos)
	local goal: Vector3
	if target and root then
		goal = Vector3.new(root.Position.X, HOVER, root.Position.Z)
		part:SetAttribute("TargetUserId", target.UserId)
	else
		-- personne dehors : il patrouille sur le chemin
		part:SetAttribute("TargetUserId", 0)
		if pos.X > Config.PathEndX - 20 then
			patrolDir = -1
		elseif pos.X < Config.PathStartX + 20 then
			patrolDir = 1
		end
		goal = Vector3.new(pos.X + patrolDir * 30, HOVER, Config.PathZ)
	end

	local offset = flat(goal - pos)
	local distance = offset.Magnitude
	if distance > 0.1 then
		local stepLength = math.min(distance, Config.MonsterSpeed * dt)
		local dir = offset.Unit
		local candidate = pos + dir * stepLength
		-- il ne rentre jamais dans les bases : il glisse le long des murs
		if blocked(candidate) then
			-- on longe le mur à pleine vitesse, du côté de la cible
			local sideX = if dir.X >= 0 then 1 else -1
			local sideZ = if dir.Z >= 0 then 1 else -1
			local alongX = pos + Vector3.new(sideX, 0, 0) * stepLength
			local alongZ = pos + Vector3.new(0, 0, sideZ) * stepLength
			if not blocked(alongX) then
				candidate = alongX
			elseif not blocked(alongZ) then
				candidate = alongZ
			else
				candidate = pos
			end
		end
		candidate = Vector3.new(math.clamp(candidate.X, -180, 180), HOVER, math.clamp(candidate.Z, -80, 80))
		part.CFrame = CFrame.lookAt(candidate, candidate + dir)
	end

	if target and root then
		local gap = (flat(root.Position) - flat(part.Position)).Magnitude
		if gap <= Config.MonsterCatchRange + 3 then
			catch(target, root)
		end
	end
end

local function runNight()
	local endsAt = now() + Config.NightDuration
	setState(true, endsAt, endsAt + Config.DayDuration)
	AnnounceService.announce("NightStart", nil, "night")
	AnnounceService.effect("NightStart", {})

	-- un fantôme spécial garanti au début de chaque nuit
	if GhostService.isEventActive() then
		local list = GhostData.ByRarity.Halloween
		GhostService.spawn(list[math.random(1, #list)].Id)
	else
		local list = GhostData.ByRarity.Legendary
		GhostService.spawn(list[math.random(1, #list)].Id)
	end

	spawnMonster()
	local last = os.clock()
	while now() < endsAt do
		task.wait(TICK)
		local t = os.clock()
		stepMonster(math.min(t - last, 0.2))
		last = t
	end
	removeMonster()
	immuneUntil = {}
end

function NightService.start()
	setState(false, 0, now() + Config.DayDuration)
	task.spawn(function()
		while true do
			local nextAt = ReplicatedStorage:GetAttribute("NextNightAt") or (now() + Config.DayDuration)
			-- jour : on attend, avec une alerte juste avant la nuit
			local warnAt = nextAt - Config.NightWarning
			if now() < warnAt then
				task.wait(warnAt - now())
			end
			AnnounceService.announce("NightSoon", { time = Format.time(Config.NightWarning) }, "night")
			if now() < nextAt then
				task.wait(nextAt - now())
			end
			runNight()
			setState(false, 0, now() + Config.DayDuration)
			AnnounceService.announce("NightEnd", nil, "info")
			AnnounceService.effect("NightEnd", {})
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		immuneUntil[player] = nil
	end)
end

return NightService
