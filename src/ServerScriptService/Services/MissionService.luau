--[[
	MissionService : les missions du jour et les défis de la semaine.
	  - 3 missions par joueur et par jour (facile, moyenne, difficile), qui changent à minuit UTC
	  - 3 défis par semaine, plus longs, qui changent le lundi à 0h UTC
	  - le serveur compte les progrès grâce aux événements de Hooks (achat, vol, vente...)
	  - mission réussie : pièces tout de suite ; les 3 du jour : un bonus en pièces ;
	    les 3 de la semaine : un fantôme Épique Doré
	Les progrès sont sauvegardés avec le reste des données du joueur.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local GhostData = require(Shared:WaitForChild("GhostData"))
local Missions = require(Shared:WaitForChild("Missions"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local AnnounceService = require(script.Parent.AnnounceService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GhostService = require(script.Parent.GhostService)
local Hooks = require(script.Parent.Hooks)

local MissionService = {}

local dirty: { [Player]: boolean } = {}
local rng = Random.new()

local function today(): number
	return Missions.today(os.time())
end

function MissionService.sync(player: Player)
	local data = DataService.get(player)
	if not data or not data.Missions then
		return
	end
	dirty[player] = nil
	local weekly = data.Weekly
	Remotes.get("MissionsInfo"):FireClient(player, {
		Day = data.Missions.Day,
		List = data.Missions.List,
		BonusDone = data.Missions.BonusDone,
		ResetAt = (data.Missions.Day + 1) * 86400,
		Weekly = if type(weekly) == "table" and weekly.List
			then {
				Week = weekly.Week,
				List = weekly.List,
				BonusDone = weekly.BonusDone,
				ResetAt = Missions.weekEnd(weekly.Week),
			}
			else nil,
	})
end

-- Donne de nouvelles missions si on a changé de jour. Renvoie true si c'est le cas.
function MissionService.ensure(player: Player): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	local day = today()
	if type(data.Missions) == "table" and data.Missions.Day == day then
		return false
	end
	data.Missions = {
		Day = day,
		List = Missions.generate(day, player.UserId, EconomyService.incomePerSecond(player)),
		BonusDone = false,
	}
	return true
end

-- Pareil pour les défis de la semaine
function MissionService.ensureWeekly(player: Player): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	local week = Missions.thisWeek(os.time())
	if type(data.Weekly) == "table" and data.Weekly.Week == week then
		return false
	end
	data.Weekly = {
		Week = week,
		List = Missions.generateWeekly(week, player.UserId, EconomyService.incomePerSecond(player)),
		BonusDone = false,
	}
	return true
end

-- Est-ce que cet événement fait avancer cette mission ?
local function matches(mission, defs, kind: string, info: any): boolean
	local def = defs[mission.Id]
	if not def then
		return false
	end
	if def.MinRarity then
		if kind ~= "Buy" then
			return false
		end
		local ghost = type(info) == "string" and GhostData.get(info)
		return ghost ~= nil and ghost ~= false and Rarities.rank(ghost.Rarity) >= Rarities.rank(def.MinRarity)
	end
	return mission.Id == kind
end

-- Avance une liste de missions. Renvoie les missions qui viennent d'être réussies.
local function advance(list, defs, kind: string, amount: number, info: any)
	local completed = {}
	for _, mission in list do
		if not mission.Done and matches(mission, defs, kind, info) then
			-- "Buy" compte 1 fantôme acheté
			local step = if kind == "Buy" then 1 else amount
			mission.Progress = math.min(mission.Target, mission.Progress + step)
			if mission.Progress >= mission.Target then
				mission.Done = true
				table.insert(completed, mission)
			end
		end
	end
	return completed
end

local function allDone(list): boolean
	for _, mission in list do
		if not mission.Done then
			return false
		end
	end
	return true
end

-- Les 3 défis de la semaine : un fantôme Épique Doré (en pièces si la base est pleine)
local function giveWeeklyBonus(player: Player)
	local bonus = Missions.WeeklyBonusGhost
	local ghost = GhostData.pick(bonus.Rarity, rng:NextNumber())
	local key = GhostData.key(ghost.Id, bonus.Mutation)
	if GhostService.giveGhost(player, key) then
		AnnounceService.notify(player, "WeeklyAllDone", { ghost = key }, "good")
	else
		local coins = GhostData.priceOf(key)
		EconomyService.add(player, coins)
		AnnounceService.notify(player, "WeeklyAllDoneCoins", { ghost = key, coins = Format.short(coins) }, "good")
	end
	AnnounceService.announce("AnnWeekly", { player = player.DisplayName }, "rebirth")
	Hooks.fire("WeeklyBonus", player)
	AnnounceService.effect("Gift", {}, player)
end

local function progress(player: Player, kind: string, amount: number, info: any)
	local data = DataService.get(player)
	if not data then
		return
	end
	if MissionService.ensure(player) then
		dirty[player] = true
	end
	if MissionService.ensureWeekly(player) then
		dirty[player] = true
	end
	local income = EconomyService.incomePerSecond(player)
	local changed = false

	-- missions du jour
	local before = {}
	for i, mission in data.Missions.List do
		before[i] = mission.Progress
	end
	local daily = advance(data.Missions.List, Missions.Defs, kind, amount, info)
	for i, mission in data.Missions.List do
		if mission.Progress ~= before[i] then
			changed = true
		end
	end
	for _, mission in daily do
		local coins = Missions.reward(mission.Tier, income)
		EconomyService.add(player, coins)
		AnnounceService.notify(player, "MissionDone", { coins = Format.short(coins) }, "good")
		AnnounceService.effect("Gift", {}, player)
	end
	if #daily > 0 and not data.Missions.BonusDone and allDone(data.Missions.List) then
		data.Missions.BonusDone = true
		local coins = Missions.reward("bonus", income)
		EconomyService.add(player, coins)
		AnnounceService.notify(player, "MissionsAllDone", { coins = Format.short(coins) }, "good")
	end

	-- défis de la semaine
	local weekly = data.Weekly
	local finished = {}
	if type(weekly) == "table" and weekly.List then
		local beforeWeekly = {}
		for i, mission in weekly.List do
			beforeWeekly[i] = mission.Progress
		end
		finished = advance(weekly.List, Missions.WeeklyDefs, kind, amount, info)
		for i, mission in weekly.List do
			if mission.Progress ~= beforeWeekly[i] then
				changed = true
			end
		end
		for _ in finished do
			local coins = Missions.weeklyReward(income)
			EconomyService.add(player, coins)
			AnnounceService.notify(player, "WeeklyDone", { coins = Format.short(coins) }, "good")
			AnnounceService.effect("Gift", {}, player)
		end
		if #finished > 0 and not weekly.BonusDone and allDone(weekly.List) then
			weekly.BonusDone = true
			giveWeeklyBonus(player)
		end
	end

	if changed then
		dirty[player] = true
	end
	if #daily > 0 or #finished > 0 then
		MissionService.sync(player)
	end
end
MissionService.progress = progress

function MissionService.setup(player: Player)
	MissionService.ensure(player)
	MissionService.ensureWeekly(player)
	MissionService.sync(player)
end

function MissionService.start()
	for _, kind in { "Buy", "Sell", "Steal", "Bonk", "Lock", "Earn", "NightOutside", "Trap" } do
		Hooks.on(kind, function(player: Player, value: any)
			local amount = if type(value) == "number" then value else 1
			progress(player, kind, amount, value)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)
	-- Envoie les progrès aux joueurs (toutes les 2 s au plus) et change les missions à minuit
	task.spawn(function()
		local sinceDayCheck = 0
		while true do
			task.wait(2)
			sinceDayCheck += 2
			if sinceDayCheck >= 60 then
				sinceDayCheck = 0
				for _, player in Players:GetPlayers() do
					local newDay = MissionService.ensure(player)
					local newWeek = MissionService.ensureWeekly(player)
					if newDay or newWeek then
						dirty[player] = true
					end
				end
			end
			for player in dirty do
				if player.Parent then
					MissionService.sync(player)
				else
					dirty[player] = nil
				end
			end
		end
	end)
end

return MissionService
