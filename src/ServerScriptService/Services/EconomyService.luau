--[[
	EconomyService : l'argent du jeu. SEUL le serveur modifie les pièces.
	  - chaque seconde : chaque fantôme remplit SON socle (revenu x multiplicateur) ;
	    le propriétaire passe sur la plaque verte devant le socle pour récupérer les pièces
	  - un petit revenu de base (1/s) arrive directement, pour ne jamais être bloqué
	  - achat de l'étage 2
	  - multiplicateur = rebirths x Game Pass x2 x bonus amis
	  - gains hors ligne (plafonnés) et cadeau du jour
	  - affichage : attributs du joueur + classement (leaderstats)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local GhostData = require(Shared:WaitForChild("GhostData"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local AnnounceService = require(script.Parent.AnnounceService)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Guard)
local Hooks = require(script.Parent.Hooks)

local EconomyService = {}

local friendBonus: { [Player]: number } = {}
local friendCache: { [string]: boolean } = {}

-- Total des pièces qui attendent sur les socles (affiché dans le HUD)
local function updateStoredTotal(player: Player, data)
	local total = 0
	for _, amount in data.Stored do
		total += amount
	end
	player:SetAttribute("Stored", math.floor(total))
end

---------------------------------------------------------------- Calculs

-- Week-end x2 : du vendredi 17h UTC au dimanche 23h UTC
function EconomyService.isWeekendBoost(t: number?): boolean
	if not Config.WeekendBoost.Enabled then
		return false
	end
	local date = os.date("!*t", t or os.time())
	-- wday : 1 = dimanche, 6 = vendredi, 7 = samedi
	return (date.wday == 6 and date.hour >= 17) or date.wday == 7 or (date.wday == 1 and date.hour < 23)
end

-- Multiplicateur de rebirth seul (x1, x1.5, x2...)
function EconomyService.rebirthMultiplier(rebirths: number): number
	return 1 + rebirths * Config.RebirthIncomeBonus
end

function EconomyService.multiplier(player: Player): number
	local data = DataService.get(player)
	if not data then
		return 1
	end
	local m = EconomyService.rebirthMultiplier(data.Rebirths)
	if player:GetAttribute("DoubleCoins") then
		m *= 2
	end
	m *= 1 + (friendBonus[player] or 0)
	if data.IndexComplete then
		m *= 1 + Config.IndexCompleteBonus
	end
	if ReplicatedStorage:GetAttribute("WeekendBoost") then
		m *= Config.WeekendBoost.Mult
	end
	-- Roue de la Fortune : revenus x2 pendant un moment
	if (data.BoostUntil or 0) > os.time() then
		m *= Config.WheelBoostMult
	end
	return m
end

-- Revenu par seconde AVANT multiplicateur
function EconomyService.baseIncome(player: Player): number
	local total = Config.BaseIncome
	for _, ghostKey in BaseService.activeGhostIds(player) do
		total += GhostData.incomeOf(ghostKey) -- variante Dorée / Arc-en-ciel comprise
	end
	return total
end

function EconomyService.incomePerSecond(player: Player): number
	return EconomyService.baseIncome(player) * EconomyService.multiplier(player)
end

---------------------------------------------------------------- Affichage

local function ensureLeaderstats(player: Player)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		return stats
	end
	stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = stats
	stats.Parent = player
	return stats
end

-- Met à jour ce que le joueur voit (pièces, revenu, multiplicateur)
function EconomyService.refresh(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local income = EconomyService.incomePerSecond(player)
	player:SetAttribute("Coins", math.floor(data.Coins))
	player:SetAttribute("Income", math.floor(income * 10) / 10)
	player:SetAttribute("Multiplier", math.floor(EconomyService.multiplier(player) * 100) / 100)
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("FriendBonus", friendBonus[player] or 0)
	-- fin du bonus x2, en heure du serveur (l'horloge du téléphone peut être fausse)
	local boostLeft = (data.BoostUntil or 0) - os.time()
	player:SetAttribute("BoostUntil", if boostLeft > 0 then workspace:GetServerTimeNow() + boostLeft else 0)
	if data.Stored then
		updateStoredTotal(player, data)
	end
	local stats = ensureLeaderstats(player)
	stats.Coins.Value = Format.short(data.Coins)
	stats.Rebirths.Value = data.Rebirths
end

---------------------------------------------------------------- Pièces

function EconomyService.add(player: Player, amount: number, countAsEarned: boolean?)
	local data = DataService.get(player)
	if not data or amount ~= amount or amount <= 0 then
		return
	end
	data.Coins += amount
	if countAsEarned then
		data.TotalEarned += amount
		Hooks.fire("Earn", player, amount)
	end
	EconomyService.refresh(player)
end

-- Retire des pièces si le joueur en a assez. Renvoie true si c'est fait.
function EconomyService.trySpend(player: Player, amount: number): boolean
	local data = DataService.get(player)
	if not data or amount < 0 or data.Coins < amount then
		return false
	end
	data.Coins -= amount
	EconomyService.refresh(player)
	return true
end

-- Retire un pourcentage des pièces (attrapé par le monstre). Renvoie le montant retiré.
function EconomyService.takePercent(player: Player, percent: number): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local amount = math.floor(data.Coins * percent)
	if amount > 0 then
		data.Coins -= amount
		EconomyService.refresh(player)
	end
	return amount
end

---------------------------------------------------------------- Amis

local function areFriends(a: Player, b: Player): boolean
	if a.UserId <= 0 or b.UserId <= 0 then
		return false -- joueurs de test dans Studio
	end
	local key = if a.UserId < b.UserId then a.UserId .. "_" .. b.UserId else b.UserId .. "_" .. a.UserId
	if friendCache[key] == nil then
		local ok, result = pcall(function()
			return a:IsFriendsWith(b.UserId)
		end)
		friendCache[key] = ok and result == true
	end
	return friendCache[key]
end

-- +10 % par ami présent dans le serveur (max +50 %)
function EconomyService.recomputeFriends()
	local players = Players:GetPlayers()
	for _, player in players do
		local count = 0
		for _, other in players do
			if other ~= player and areFriends(player, other) then
				count += 1
			end
		end
		local bonus = math.min(count * Config.FriendBonus, Config.FriendBonusMax)
		friendBonus[player] = bonus
		EconomyService.refresh(player)
	end
end

---------------------------------------------------------------- Hors ligne & cadeau du jour

---------------------------------------------------------------- Récolte sur les socles

-- Le propriétaire passe sur la plaque verte : il récupère les pièces du socle
function EconomyService.collect(player: Player, slot: number): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local key = tostring(slot)
	local stored = data.Stored[key] or 0
	local amount = math.floor(stored)
	if amount < 1 then
		return 0
	end
	data.Stored[key] = stored - amount
	BaseService.showStored(player, slot, data.Stored[key])
	EconomyService.add(player, amount, true)
	updateStoredTotal(player, data)
	player:SetAttribute("HasCollected", true)
	return amount
end

-- Chaque fantôme remplit son socle (appelé chaque seconde)
local function produce(player: Player, data, seconds: number, multiplier: number)
	local base = BaseService.getBase(player)
	if not base then
		return
	end
	for key, ghostKey in data.Slots do
		local slot = tonumber(key)
		if slot and not BaseService.isStolenOut(player, slot) then
			local amount = GhostData.incomeOf(ghostKey) * multiplier * seconds
			data.Stored[key] = (data.Stored[key] or 0) + amount
			BaseService.showStored(player, slot, data.Stored[key])
		end
	end
	updateStoredTotal(player, data)
end

-- Revenus produits pendant l'absence (50 %, 3 h max), posés sur les socles.
-- À appeler après la pose des fantômes.
function EconomyService.grantOffline(player: Player, lastOnline: number)
	if lastOnline <= 0 then
		return
	end
	local away = math.min(os.time() - lastOnline, Config.OfflineCapSeconds)
	if away < Config.OfflineMinSeconds then
		return
	end
	-- sans le bonus amis ni le week-end (on ne sait pas ce qui s'est passé)
	local data = DataService.get(player)
	if not data then
		return
	end
	local multiplier = EconomyService.rebirthMultiplier(data.Rebirths)
	if player:GetAttribute("DoubleCoins") then
		multiplier *= 2
	end
	if data.IndexComplete then
		multiplier *= 1 + Config.IndexCompleteBonus
	end
	local before = player:GetAttribute("Stored") or 0
	produce(player, data, away * Config.OfflineRate, multiplier)
	local amount = (player:GetAttribute("Stored") or 0) - before
	if amount > 0 then
		AnnounceService.notify(player, "OfflineEarned", { coins = Format.short(amount) }, "good")
	end
end

-- Achat de l'étage 2
local function buyFloor(player: Player)
	if not Guard.rate(player, "BuyFloor", 1) then
		return
	end
	local data = DataService.get(player)
	if not data or not BaseService.getBase(player) then
		return
	end
	if (data.Floors or 1) >= 2 then
		return
	end
	if not EconomyService.trySpend(player, Config.FloorPrice) then
		AnnounceService.notify(player, "NotEnoughCoins", nil, "bad")
		return
	end
	BaseService.unlockFloor(player)
	AnnounceService.notify(player, "FloorBought", nil, "good")
	AnnounceService.effect("Rebirth", { Position = BaseService.getBase(player).Origin.Position, PlayerId = player.UserId })
end

local function today(): number
	return os.time() // 86400
end

-- Infos du cadeau du jour pour l'affichage
function EconomyService.dailyInfo(player: Player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local day = today()
	local canClaim = data.DailyDay < day
	-- si on a raté un jour, la série recommence au jour 1
	local streak = data.DailyStreak
	if data.DailyDay < day - 1 then
		streak = 0
	end
	local nextDay = if canClaim then (streak % #Config.DailyRewards) + 1 else ((streak - 1) % #Config.DailyRewards) + 1
	return {
		CanClaim = canClaim,
		Day = nextDay,
		NextAt = (day + 1) * 86400, -- minuit UTC
		Rewards = Config.DailyRewards,
	}
end

function EconomyService.sendDailyInfo(player: Player)
	local info = EconomyService.dailyInfo(player)
	if info then
		player:SetAttribute("DailyReady", info.CanClaim)
		Remotes.get("DailyInfo"):FireClient(player, info)
	end
end

-- giveGhost est fourni par GhostService (pour le fantôme Épique du jour 7)
EconomyService.giveGhostCallback = nil :: ((Player, string) -> number?)?

function EconomyService.claimDaily(player: Player)
	local data = DataService.get(player)
	local info = EconomyService.dailyInfo(player)
	if not data or not info or not info.CanClaim then
		return
	end
	local reward = Config.DailyRewards[info.Day]
	data.DailyDay = today()
	data.DailyStreak = (if info.Day == 1 then 0 else data.DailyStreak) + 1
	local coins = math.max(reward.Min, math.floor(EconomyService.incomePerSecond(player) * 60 * reward.Minutes))
	EconomyService.add(player, coins, true)

	local ghostId = nil
	if reward.RandomGhostRarity and EconomyService.giveGhostCallback then
		local list = GhostData.ByRarity[reward.RandomGhostRarity]
		local ghost = list[math.random(1, #list)]
		local slot = EconomyService.giveGhostCallback(player, ghost.Id)
		if slot then
			ghostId = ghost.Id
		else
			EconomyService.add(player, ghost.Price, true) -- base pleine : on donne sa valeur
		end
	end

	if ghostId then
		AnnounceService.notify(player, "DailyGotGhost", { day = info.Day, coins = Format.short(coins), ghost = ghostId }, "good")
	else
		AnnounceService.notify(player, "DailyGot", { day = info.Day, coins = Format.short(coins) }, "good")
	end
	AnnounceService.effect("Gift", {}, player)
	EconomyService.sendDailyInfo(player)
end

---------------------------------------------------------------- Démarrage

function EconomyService.setup(player: Player)
	ensureLeaderstats(player)
	EconomyService.refresh(player)
	task.spawn(EconomyService.recomputeFriends)
end

function EconomyService.onPlayerRemoving(player: Player)
	friendBonus[player] = nil
	task.defer(EconomyService.recomputeFriends)
end

function EconomyService.start()
	Remotes.get("ClaimDaily").OnServerEvent:Connect(function(player)
		if Guard.rate(player, "Daily", 1) then
			EconomyService.claimDaily(player)
		end
	end)
	Remotes.get("BuyFloor").OnServerEvent:Connect(buyFloor)

	-- Plaques vertes : seul le propriétaire de la base récupère les pièces
	local padCooldown: { [BasePart]: number } = {}
	for _, base in BaseService.allBases() do
		for slot, ped in base.Pedestals do
			local pad = ped:FindFirstChild("CollectPad") :: BasePart?
			if pad then
				pad.Touched:Connect(function(hit)
					local owner = base.Owner
					if not owner or (padCooldown[pad] or 0) > os.clock() then
						return
					end
					local character = hit.Parent
					if not character or Players:GetPlayerFromCharacter(character) ~= owner then
						return
					end
					padCooldown[pad] = os.clock() + 0.3
					local amount = EconomyService.collect(owner, slot)
					if amount > 0 then
						AnnounceService.effect("Collect", { Position = pad.Position, Amount = amount }, owner)
					end
				end)
			end
		end
	end

	-- Le revenu tombe toutes les secondes
	task.spawn(function()
		while true do
			task.wait(1)
			local boost = EconomyService.isWeekendBoost()
			if ReplicatedStorage:GetAttribute("WeekendBoost") ~= boost then
				ReplicatedStorage:SetAttribute("WeekendBoost", boost)
			end
			for _, player in Players:GetPlayers() do
				Guard.safely("Income", function()
					local data = DataService.get(player)
					if data and BaseService.getBase(player) then
						local multiplier = EconomyService.multiplier(player)
						EconomyService.add(player, Config.BaseIncome * multiplier, true)
						produce(player, data, 1, multiplier)
					end
				end)
			end
		end
	end)
end

return EconomyService
