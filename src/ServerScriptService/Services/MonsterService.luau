--[[
	MonsterService : les monstres qui poursuivent les joueurs.
	  - Gloutrouille pendant la Nuit Hantée (lancé par NightService)
	  - les monstres lâchés avec des Robux : un seul à la fois, les suivants attendent
	    leur tour ; celui qui l'a lâché n'est jamais poursuivi ; pas de pièces perdues

	Les monstres n'entrent jamais dans les bases. Le serveur calcule leur position
	(anti-triche) et la publie sur une pièce invisible "<Id>Anchor" dans le Workspace.
	Chaque joueur dessine le vrai monstre et le fait glisser vers cette position.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Monsters = require(Shared:WaitForChild("Monsters"))

local AnnounceService = require(script.Parent.AnnounceService)
local BaseService = require(script.Parent.BaseService)
local EconomyService = require(script.Parent.EconomyService)
local Guard = require(script.Parent.Guard)
local StealService = require(script.Parent.StealService)

local MonsterService = {}

local TICK = 1 / 15
local CATCH_IMMUNITY = 6 -- secondes de répit après avoir été attrapé

export type Monster = {
	Id: string,
	Anchor: BasePart,
	Speed: number,
	CatchRange: number,
	Hover: number,
	Penalty: number,
	Summoner: Player?,
	EndsAt: number?,
	PatrolDir: number,
	OnEnd: (() -> ())?,
}

local active: { Monster } = {}
local immuneUntil: { [Player]: number } = {}
local queue: { { Id: string, Player: Player, Name: string } } = {}
local paidMonster: Monster? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Un point est-il interdit aux monstres ? (dans une base, avec une marge)
local function blocked(position: Vector3): boolean
	for _, base in BaseService.allBases() do
		local localPos = base.Origin:PointToObjectSpace(position)
		if math.abs(localPos.X) < 20 and math.abs(localPos.Z) < 18 then
			return true
		end
	end
	return false
end

-- La proie : le joueur le plus proche hors de sa base (les voleurs attirent plus)
local function pickTarget(monster: Monster, from: Vector3): (Player?, BasePart?)
	local t = os.clock()
	local best, bestRoot, bestScore = nil, nil, math.huge
	for _, player in Players:GetPlayers() do
		local root = Guard.root(player)
		if root and player ~= monster.Summoner and (immuneUntil[player] or 0) < t and not BaseService.baseAt(root.Position) then
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

local function catch(monster: Monster, player: Player, root: BasePart)
	immuneUntil[player] = os.clock() + CATCH_IMMUNITY
	AnnounceService.effect("MonsterCatch", { Position = root.Position, PlayerId = player.UserId, Monster = monster.Id })
	if StealService.isCarrying(player) then
		StealService.failCarry(player, "Monster")
	end
	if monster.Penalty > 0 then
		local lost = EconomyService.takePercent(player, monster.Penalty)
		AnnounceService.notify(player, "MonsterCaughtYou", { coins = Format.short(lost) }, "bad")
	else
		AnnounceService.notify(player, "MonsterCaughtYouFree", { monster = monster.Id }, "bad")
	end
	AnnounceService.announce("AnnCaught", { player = player.DisplayName, monster = monster.Id }, "night")
	BaseService.teleportHome(player)
end

-- Un pas de déplacement d'un monstre
local function step(monster: Monster, dt: number)
	local part = monster.Anchor
	local pos = part.Position
	local target, root = pickTarget(monster, pos)
	local goal: Vector3
	if target and root then
		goal = Vector3.new(root.Position.X, monster.Hover, root.Position.Z)
		part:SetAttribute("TargetUserId", target.UserId)
	else
		-- personne dehors : il patrouille sur le chemin
		part:SetAttribute("TargetUserId", 0)
		if pos.X > Config.PathEndX - 20 then
			monster.PatrolDir = -1
		elseif pos.X < Config.PathStartX + 20 then
			monster.PatrolDir = 1
		end
		goal = Vector3.new(pos.X + monster.PatrolDir * 30, monster.Hover, Config.PathZ)
	end

	local offset = flat(goal - pos)
	local distance = offset.Magnitude
	if distance > 0.1 then
		local stepLength = math.min(distance, monster.Speed * dt)
		local dir = offset.Unit
		local candidate = pos + dir * stepLength
		-- il ne rentre jamais dans les bases : il glisse le long des murs
		if blocked(candidate) then
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
		candidate = Vector3.new(math.clamp(candidate.X, -180, 180), monster.Hover, math.clamp(candidate.Z, -80, 80))
		part.CFrame = CFrame.lookAt(candidate, candidate + dir)
	end

	if target and root then
		local gap = (flat(root.Position) - flat(part.Position)).Magnitude
		if gap <= monster.CatchRange + 3 then
			catch(monster, target, root)
		end
	end
end

--[[
	Fait apparaître un monstre. options :
	  Speed, CatchRange, Scale, Penalty (part des pièces perdues, 0 = rien),
	  Duration (nil = jusqu'à MonsterService.remove), Summoner (joueur jamais poursuivi)
]]
function MonsterService.spawn(id: string, options: { [string]: any }?): Monster
	local def = Monsters.get(id) or Monsters.ById.Gloutrouille
	local opts = options or {}
	local part = Instance.new("Part")
	part.Name = def.Id .. "Anchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one
	-- il sort du portail de départ
	part.CFrame = CFrame.new(Config.PathStartX, def.Hover, Config.PathZ)
	part:SetAttribute("MonsterKind", def.Id)
	part:SetAttribute("Scale", opts.Scale or 1)
	part:SetAttribute("TargetUserId", 0)
	part:SetAttribute("SummonerName", if opts.Summoner then opts.Summoner.DisplayName else "")
	part:SetAttribute("SummonerId", if opts.Summoner then opts.Summoner.UserId else 0)
	local monster: Monster = {
		Id = def.Id,
		Anchor = part,
		Speed = opts.Speed or def.Speed,
		CatchRange = opts.CatchRange or def.CatchRange,
		Hover = def.Hover,
		Penalty = opts.Penalty or 0,
		Summoner = opts.Summoner,
		EndsAt = if opts.Duration then now() + opts.Duration else nil,
		PatrolDir = 1,
		OnEnd = opts.OnEnd,
	}
	if monster.EndsAt then
		part:SetAttribute("EndsAt", monster.EndsAt)
	end
	part.Parent = workspace
	table.insert(active, monster)
	return monster
end

function MonsterService.remove(monster: Monster)
	local index = table.find(active, monster)
	if index then
		table.remove(active, index)
	end
	if monster.Anchor.Parent then
		monster.Anchor:Destroy()
	end
	if monster.OnEnd then
		monster.OnEnd()
	end
end

function MonsterService.activeCount(): number
	return #active
end

---------------------------------------------------------------- Monstres achetés

local function startNextPaid()
	if paidMonster or #queue == 0 then
		return
	end
	local entry = table.remove(queue, 1) :: { Id: string, Player: Player, Name: string }
	local summoner = if entry.Player.Parent then entry.Player else nil
	local def = Monsters.get(entry.Id) or Monsters.ById.Gloutrouille
	AnnounceService.announce("AnnMonsterSummon", { player = entry.Name, monster = def.Id }, "night")
	AnnounceService.effect("MonsterSummon", { Monster = def.Id })
	paidMonster = MonsterService.spawn(def.Id, {
		Duration = def.Duration,
		Summoner = summoner,
		Penalty = 0,
		OnEnd = function()
			paidMonster = nil
			task.defer(startNextPaid)
		end,
	})
end

-- Un joueur a payé pour lâcher un monstre
function MonsterService.summon(player: Player, id: string): boolean
	local def = Monsters.get(id)
	if not def then
		return false
	end
	table.insert(queue, { Id = def.Id, Player = player, Name = player.DisplayName })
	if paidMonster then
		AnnounceService.notify(player, "MonsterQueued", { monster = def.Id, count = #queue }, "info")
	end
	startNextPaid()
	return true
end

function MonsterService.queueLength(): number
	return #queue
end

---------------------------------------------------------------- Boucle

function MonsterService.start()
	Players.PlayerRemoving:Connect(function(player)
		immuneUntil[player] = nil
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
			local clock = os.clock()
			local stepDt = math.min(clock - last, 0.2)
			last = clock
			local t = now()
			for _, monster in table.clone(active) do
				if monster.EndsAt and t >= monster.EndsAt then
					MonsterService.remove(monster)
				elseif monster.Anchor.Parent then
					step(monster, stepDt)
				end
			end
		end
	end)
end

return MonsterService
