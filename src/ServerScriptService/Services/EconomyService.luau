--[[
	EconomyService : l'argent du jeu. SEUL le serveur modifie les pièces.
	  - chaque seconde : pièces += revenu des fantômes x multiplicateur
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

local EconomyService = {}

local friendBonus: { [Player]: number } = {}
local friendCache: { [string]: boolean } = {}

---------------------------------------------------------------- Calculs

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
	return m
end

-- Revenu par seconde AVANT multiplicateur
function EconomyService.baseIncome(player: Player): number
	local total = Config.BaseIncome
	for _, ghostId in BaseService.activeGhostIds(player) do
		local ghost = GhostData.get(ghostId)
		if ghost then
			total += ghost.Income
		end
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

-- Revenus gagnés pendant l'absence (50 %, 3 h max). À appeler après la pose des fantômes.
function EconomyService.grantOffline(player: Player, lastOnline: number)
	if lastOnline <= 0 then
		return
	end
	local away = math.min(os.time() - lastOnline, Config.OfflineCapSeconds)
	if away < Config.OfflineMinSeconds then
		return
	end
	-- sans le bonus amis (on ne sait pas qui était là)
	local data = DataService.get(player)
	local rebirths = if data then data.Rebirths else 0
	local perSecond = EconomyService.baseIncome(player) * EconomyService.rebirthMultiplier(rebirths)
	if player:GetAttribute("DoubleCoins") then
		perSecond *= 2
	end
	local amount = math.floor(perSecond * away * Config.OfflineRate)
	if amount > 0 then
		EconomyService.add(player, amount, true)
		AnnounceService.notify(player, "OfflineEarned", { coins = Format.short(amount) }, "good")
	end
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

	-- Le revenu tombe toutes les secondes
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				if DataService.get(player) and BaseService.getBase(player) then
					EconomyService.add(player, EconomyService.incomePerSecond(player), true)
				end
			end
		end
	end)
end

return EconomyService
