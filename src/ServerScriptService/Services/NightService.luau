--[[
	NightService : la Nuit Hantée.
	  - toutes les 10 minutes : 8 min de jour, puis 2 min de nuit
	  - la nuit : plus de fantômes rares sur le chemin, un fantôme spécial garanti,
	    et Gloutrouille (le monstre) poursuit les joueurs qui sont HORS de leur base
	  - attrapé : "BOUH !", retour à la base, -5 % de pièces, et on lâche le fantôme volé
	  - chaque nuit a un thème : Classique, Brouillard (monstre plus rapide), Bonbons (des
	    pièces à ramasser sur le chemin), et le samedi soir la Super Nuit (monstre géant,
	    Mythique garanti, plus de variantes Dorées et Arc-en-ciel)

	Le monstre lui-même (poursuite, capture) est géré par MonsterService.
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
local Hooks = require(script.Parent.Hooks)
local MonsterService = require(script.Parent.MonsterService)

local NightService = {}

local TICK = 1 / 15

local theme = "Classic"
local candyFolder: Folder? = nil
local rng = Random.new()
local outsideTime: { [Player]: number } = {}

-- Mission du jour "reste dehors pendant la nuit" : on compte les secondes hors des bases
local function countOutside(dt: number)
	for _, player in Players:GetPlayers() do
		local root = Guard.root(player)
		if root and not BaseService.baseAt(root.Position) then
			outsideTime[player] = (outsideTime[player] or 0) + dt
			if outsideTime[player] >= 1 then
				outsideTime[player] -= 1
				Hooks.fire("NightOutside", player, 1)
			end
		end
	end
end

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

local candyTaken: { [Player]: number } = {} -- pièces ramassées cette nuit
local candyLast: { [Player]: number } = {}

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
		local root = player and Guard.root(player)
		if not player or not root then
			return
		end
		-- anti-triche : vraiment à côté de la pièce, pas trop vite, et un maximum par nuit
		if (root.Position - coin.Position).Magnitude > 8 then
			return
		end
		local t = os.clock()
		if (candyLast[player] or 0) > t - 0.4 or (candyTaken[player] or 0) >= Config.CandyMaxPerPlayer then
			return
		end
		candyLast[player] = t
		candyTaken[player] = (candyTaken[player] or 0) + 1
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
	table.clear(candyTaken)
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

local START_KEYS = { Classic = "NightStart", Fog = "NightStartFog", Candy = "NightStartCandy", Super = "NightStartSuper" }

local function runNight()
	theme = pickTheme()
	ReplicatedStorage:SetAttribute("NightTheme", theme)
	local endsAt = now() + Config.NightDuration
	setState(true, endsAt, endsAt + Config.DayDuration)
	AnnounceService.announce(START_KEYS[theme], nil, "night")
	AnnounceService.effect("NightStart", { Theme = theme })

	-- un fantôme spécial garanti au début de chaque nuit
	local eventRarity = GhostService.eventRarity()
	if eventRarity then
		local list = GhostData.ByRarity[eventRarity]
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

	-- l'hiver, c'est le Bonhomme Grelot qui sort à la place de Gloutrouille
	local monsterId = if GhostService.activeEvents().Winter then "BonhommeGrelot" else "Gloutrouille"
	local monster = MonsterService.spawn(monsterId, {
		Speed = if theme == "Fog" then Config.FogMonsterSpeed else Config.MonsterSpeed,
		CatchRange = if theme == "Super" then Config.MonsterCatchRange + 3 else Config.MonsterCatchRange,
		Scale = if theme == "Super" then Config.SuperMonsterScale else 1,
		Penalty = Config.MonsterCoinPenalty,
		Duration = Config.NightDuration + 5, -- sécurité : il repart même si la nuit s'arrête mal
	})
	local last = os.clock()
	while now() < endsAt do
		task.wait(TICK)
		local t = os.clock()
		countOutside(math.min(t - last, 0.2))
		last = t
	end
	MonsterService.remove(monster)
	stopCandy()
	GhostService.mutationBoost = 1
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
			Guard.safely("Night", runNight)
			-- même après une erreur pendant la nuit, on remet tout comme avant
			stopCandy()
			GhostService.mutationBoost = 1
			setState(false, 0, now() + Config.DayDuration)
			AnnounceService.announce("NightEnd", nil, "info")
			AnnounceService.effect("NightEnd", {})
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		outsideTime[player] = nil
		candyTaken[player] = nil
		candyLast[player] = nil
	end)
end

return NightService
