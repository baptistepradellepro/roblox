--[[
	MissionService : les missions du jour.
	  - 3 missions par joueur et par jour (facile, moyenne, difficile), qui changent à minuit UTC
	  - le serveur compte les progrès grâce aux événements de Hooks (achat, vol, vente...)
	  - mission réussie : pièces tout de suite ; les 3 réussies : un bonus en plus
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
local Hooks = require(script.Parent.Hooks)

local MissionService = {}

local dirty: { [Player]: boolean } = {}

local function today(): number
	return Missions.today(os.time())
end

function MissionService.sync(player: Player)
	local data = DataService.get(player)
	if not data or not data.Missions then
		return
	end
	dirty[player] = nil
	Remotes.get("MissionsInfo"):FireClient(player, {
		Day = data.Missions.Day,
		List = data.Missions.List,
		BonusDone = data.Missions.BonusDone,
		ResetAt = (data.Missions.Day + 1) * 86400,
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

-- Est-ce que cet événement fait avancer cette mission ?
local function matches(mission, kind: string, info: any): boolean
	if mission.Id == kind then
		return true
	end
	if kind == "Buy" and (mission.Id == "BuyRare" or mission.Id == "BuyEpic") then
		local ghost = type(info) == "string" and GhostData.get(info)
		local minRarity = Missions.Defs[mission.Id].MinRarity
		return ghost ~= nil and ghost ~= false and Rarities.rank(ghost.Rarity) >= Rarities.rank(minRarity)
	end
	return false
end

local function progress(player: Player, kind: string, amount: number, info: any)
	local data = DataService.get(player)
	if not data then
		return
	end
	if MissionService.ensure(player) then
		dirty[player] = true
	end
	local completedOne = false
	for _, mission in data.Missions.List do
		if not mission.Done and matches(mission, kind, info) then
			-- "Buy" compte 1 fantôme acheté, sauf pour les missions qui demandent une rareté
			local step = if kind == "Buy" then 1 else amount
			mission.Progress = math.min(mission.Target, mission.Progress + step)
			dirty[player] = true
			if mission.Progress >= mission.Target then
				mission.Done = true
				completedOne = true
				local coins = Missions.reward(mission.Tier, EconomyService.incomePerSecond(player))
				EconomyService.add(player, coins)
				AnnounceService.notify(player, "MissionDone", { coins = Format.short(coins) }, "good")
				AnnounceService.effect("Gift", {}, player)
			end
		end
	end
	if completedOne and not data.Missions.BonusDone then
		local allDone = true
		for _, mission in data.Missions.List do
			if not mission.Done then
				allDone = false
			end
		end
		if allDone then
			data.Missions.BonusDone = true
			local coins = Missions.reward("bonus", EconomyService.incomePerSecond(player))
			EconomyService.add(player, coins)
			AnnounceService.notify(player, "MissionsAllDone", { coins = Format.short(coins) }, "good")
		end
	end
	if completedOne then
		MissionService.sync(player)
	end
end
MissionService.progress = progress

function MissionService.setup(player: Player)
	MissionService.ensure(player)
	MissionService.sync(player)
end

function MissionService.start()
	for _, kind in { "Buy", "Sell", "Steal", "Bonk", "Lock", "Earn", "NightOutside" } do
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
					if MissionService.ensure(player) then
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
