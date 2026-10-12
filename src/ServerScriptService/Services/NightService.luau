--[[
	NightService : la Nuit Hantée.
	  - toutes les 10 minutes : 8 min de jour, puis 2 min de nuit
	  - la nuit : plus de fantômes rares sur le chemin, un fantôme spécial garanti,
	    et Gloutrouille (le monstre) poursuit les joueurs qui sont HORS de leur base
	  - attrapé : "BOUH !", retour à la base, -5 % de pièces, et on lâche le fantôme volé
	  - chaque nuit a un thème : Classique, Brouillard (monstre plus rapide), Bonbons (des
	    pièces à ramasser sur le chemin), et le samedi soir la Super Nuit (monstre géant,
	    Mythique garanti, plus de variantes Dorées et Arc-en-ciel)

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
local theme = "Classic"
local monsterSpeed = Config.MonsterSpeed
local catchRange = Config.MonsterCatchRange
local candyFolder: Folder? = nil
local rng = Random.new()

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

-- Est-ce l'heure de la Super Nuit ? (samedi 17h-18h UTC par défaut)
function NightService.isSuperTime(t: number?): boolean
	local date = os.date("!*t", t or os.time())
	local super = Config.SuperNight
	return date.wday == super.WeekDay and date.hour >= super.StartHour and date.hour < super.EndHour
end

local function pickTheme(): string
	if NightService.isSuperTime() then
		return "Super"
	end
	local total = 0
	for _, weight in Config.NightThemes do
		total += weight
	end
	local roll = rng:NextNumber() * total
	for _, name in { "Classic", "Fog", "Candy" } do
		roll -= Config.NightThemes[name] or 0
		if roll < 0 then
			return name
		end
	end
	return "Classic"
end

---------------------------------------------------------------- Nuit des Bonbons

local function coinReward(player: Player): number
	return math.max(25, math.floor(EconomyService.incomePerSecond(player) * Config.CandyCoinSeconds))
end

local function spawnCoin()
	local folder = candyFolder
	if not folder then
		return
	end
	-- sur le chemin ou les allées, jamais dans une base
	local position
	for _ = 1, 10 do
		local x = rng:NextNumber(Config.PathStartX + 10, Config.PathEndX - 10)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local z = if rng:NextNumber() < 0.6 then rng:NextNumber(-6, 6) else side * rng:NextNumber(9, 13)
		local candidate = Vector3.new(x, 2, Config.PathZ + z)
		if not BaseService.baseAt(candidate) then
			position = candidate
			break
		end
	end
	if not position then
		return
	end
	local coin = Instance.new("Part")
	coin.Name = "CandyCoin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.4, 2.2, 2.2)
	coin.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(90), 0)
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CanTouch = true
	coin.CastShadow = false
	coin.Color = Color3.fromRGB(255, 205, 50)
	coin.Material = Enum.Material.Neon
	coin:SetAttribute("Base", coin.CFrame)
	local taken = false
	coin.Touched:Connect(function(hit)
		if taken then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or not Guard.root(player) then
			return
		end
		taken = true
		local amount = coinReward(player)
		EconomyService.add(player, amount, true)
		AnnounceService.effect("CoinPickup", { Position = coin.Position, Amount = amount }, player)
		coin:Destroy()
		task.delay(3, spawnCoin) -- une nouvelle pièce apparaît ailleurs
	end)
	coin.Parent = folder
end

local function startCandy()
	local folder = Instance.new("Folder")
	folder.Name = "CandyCoins"
	folder.Parent = workspace
	candyFolder = folder
	for _ = 1, Config.CandyCoinCount do
		spawnCoin()
	end
end

local function stopCandy()
	if candyFolder then
		candyFolder:Destroy()
		candyFolder = nil
	end
end

---------------------------------------------------------------- Monstre

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
	part:SetAttribute("Scale", if theme == "Super" then Config.SuperMonsterScale else 1)
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
		local stepLength = math.min(distance, monsterSpeed * dt)
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
		if gap <= catchRange + 3 then
			catch(target, root)
		end
	end
end

local START_KEYS = { Classic = "NightStart", Fog = "NightStartFog", Candy = "NightStartCandy", Super = "NightStartSuper" }

local function runNight()
	theme = pickTheme()
	monsterSpeed = if theme == "Fog" then Config.FogMonsterSpeed else Config.MonsterSpeed
	catchRange = if theme == "Super" then Config.MonsterCatchRange + 3 else Config.MonsterCatchRange
	ReplicatedStorage:SetAttribute("NightTheme", theme)
	local endsAt = now() + Config.NightDuration
	setState(true, endsAt, endsAt + Config.DayDuration)
	AnnounceService.announce(START_KEYS[theme], nil, "night")
	AnnounceService.effect("NightStart", { Theme = theme })

	-- un fantôme spécial garanti au début de chaque nuit
	if GhostService.isEventActive() then
		local list = GhostData.ByRarity.Halloween
		GhostService.spawn(list[math.random(1, #list)].Id)
	else
		local list = GhostData.ByRarity.Legendary
		GhostService.spawn(list[math.random(1, #list)].Id)
	end
	if theme == "Super" then
		local list = GhostData.ByRarity.Mythic
		GhostService.spawn(list[math.random(1, #list)].Id)
		GhostService.mutationBoost = Config.SuperMutationBoost
	elseif theme == "Candy" then
		startCandy()
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
	stopCandy()
	GhostService.mutationBoost = 1
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
