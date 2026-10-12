--[[
	IndexService : le Fantômédex, la collection des 32 fantômes.
	  - un fantôme est "découvert" dès qu'il arrive dans ta base (achat, vol, cadeau, code)
	  - série complète (tous les fantômes d'une rareté) : des pièces en récompense
	  - tous les fantômes permanents trouvés : +10 % de revenus pour toujours
	La collection n'est jamais effacée, même par un rebirth.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local GhostData = require(Shared:WaitForChild("GhostData"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local AnnounceService = require(script.Parent.AnnounceService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Hooks = require(script.Parent.Hooks)

local IndexService = {}

-- Envoie au joueur l'état de sa collection
function IndexService.sync(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local found = {}
	for ghostId in data.Discovered do
		table.insert(found, ghostId)
	end
	Remotes.get("IndexInfo"):FireClient(player, {
		Discovered = found,
		Rewarded = data.IndexRewards,
		Complete = data.IndexComplete == true,
	})
end

local function isRarityComplete(data, rarity: string): boolean
	for _, ghost in GhostData.ByRarity[rarity] or {} do
		if not data.Discovered[ghost.Id] then
			return false
		end
	end
	return true
end

-- Vérifie les séries complètes et le Fantômédex complet
local function checkRewards(player: Player, data)
	for _, rarity in Rarities.Order do
		if not data.IndexRewards[rarity] and isRarityComplete(data, rarity) then
			data.IndexRewards[rarity] = true
			local coins = Config.IndexRewards[rarity] or 0
			EconomyService.add(player, coins, true)
			AnnounceService.notify(player, "IndexRarityDone", { rarity = rarity, coins = Format.short(coins) }, "good")
			AnnounceService.effect("Gift", {}, player)
		end
	end
	if not data.IndexComplete then
		for _, rarity in Rarities.Order do
			local info = Rarities.Info[rarity]
			if not info.EventOnly and not info.Bonus and not data.IndexRewards[rarity] then
				return
			end
		end
		data.IndexComplete = true
		Hooks.fire("IndexComplete", player)
		EconomyService.refresh(player)
		AnnounceService.notify(player, "IndexCompleteDone", { percent = math.floor(Config.IndexCompleteBonus * 100) }, "good")
		AnnounceService.announce("AnnIndexComplete", { player = player.DisplayName }, "legendary")
	end
end

-- Un fantôme arrive dans la base du joueur
function IndexService.discover(player: Player, ghostKey: string, silent: boolean?)
	local data = DataService.get(player)
	local ghostId = GhostData.split(ghostKey) -- la collection compte le fantôme, pas sa variante
	if not data or not GhostData.get(ghostId) or data.Discovered[ghostId] then
		return
	end
	data.Discovered[ghostId] = true
	if not silent then
		AnnounceService.notify(player, "IndexNew", { ghost = ghostId }, "info")
	end
	Hooks.fire("Discover", player, ghostId)
	checkRewards(player, data)
	IndexService.sync(player)
end

-- À l'arrivée du joueur : on ajoute à la collection ce qu'il possède déjà (sans message)
function IndexService.setup(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.Discovered[Config.StarterGhost] = true
	for _, ghostKey in data.Slots do
		local ghostId = GhostData.split(ghostKey)
		if GhostData.get(ghostId) then
			data.Discovered[ghostId] = true
		end
	end
	checkRewards(player, data)
	IndexService.sync(player)
end

return IndexService
