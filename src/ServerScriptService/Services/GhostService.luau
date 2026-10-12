--[[
	GhostService : les fantômes qui défilent sur le chemin hanté.

	Le serveur ne déplace AUCUN objet 3D : il note juste "tel fantôme est parti à telle
	heure". Chaque joueur calcule la position et affiche le fantôme lui-même (sans saccades et
	léger). Quand un joueur veut acheter, le serveur recalcule la position et vérifie
	la distance, l'argent et la place libre.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local GhostData = require(Shared:WaitForChild("GhostData"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local AnnounceService = require(script.Parent.AnnounceService)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Guard = require(script.Parent.Guard)

local GhostService = {}

type Entry = { Uid: string, GhostId: string, SpawnTime: number, Holder: Instance }

local entries: { [string]: Entry } = {}
local folder: Folder
local counter = 0
local rng = Random.new()

local PATH_LENGTH = Config.PathEndX - Config.PathStartX
local TRAVEL_TIME = PATH_LENGTH / Config.PathSpeed

local function now(): number
	return workspace:GetServerTimeNow()
end

function GhostService.isEventActive(): boolean
	if Config.ForceHalloween then
		return true
	end
	local t = os.time()
	return t >= Config.HalloweenStart and t < Config.HalloweenEnd
end

function GhostService.isNight(): boolean
	return ReplicatedStorage:GetAttribute("NightActive") == true
end

function GhostService.positionOf(entry: Entry, at: number): Vector3
	local x = Config.PathStartX + (at - entry.SpawnTime) * Config.PathSpeed
	return Vector3.new(x, Config.PathY, Config.PathZ)
end

local function count(): number
	local n = 0
	for _ in entries do
		n += 1
	end
	return n
end

local function removeEntry(uid: string)
	local entry = entries[uid]
	if entry then
		entries[uid] = nil
		entry.Holder:Destroy()
	end
end

-- Fait apparaître un fantôme au début du chemin (au hasard si ghostId est nil)
function GhostService.spawn(ghostId: string?)
	local ghost
	if ghostId then
		ghost = GhostData.get(ghostId)
	else
		local rarity = Rarities.roll(rng:NextNumber(), GhostService.isNight(), GhostService.isEventActive())
		ghost = GhostData.pick(rarity, rng:NextNumber())
	end
	if not ghost then
		return
	end
	counter += 1
	local uid = tostring(counter)
	local holder = Instance.new("Configuration")
	holder.Name = uid
	holder:SetAttribute("GhostId", ghost.Id)
	holder:SetAttribute("SpawnTime", now())
	holder.Parent = folder
	entries[uid] = { Uid = uid, GhostId = ghost.Id, SpawnTime = now(), Holder = holder }

	-- Annonce à tout le serveur pour les apparitions très rares
	if ghost.Rarity == "Mythic" then
		AnnounceService.announce("AnnMythicSpawn", { ghost = ghost.Id }, "mythic")
	elseif ghost.Rarity == "Halloween" then
		AnnounceService.announce("AnnHalloweenSpawn", { ghost = ghost.Id }, "halloween")
	end
end

-- Donne un fantôme directement dans la base (cadeau). Renvoie le socle ou nil si plein.
function GhostService.giveGhost(player: Player, ghostId: string): number?
	local slot = BaseService.placeGhost(player, ghostId)
	if slot then
		local base = BaseService.getBase(player)
		if base then
			AnnounceService.effect("Placed", { Position = BaseService.pedestalPosition(base, slot), GhostId = ghostId })
		end
		EconomyService.refresh(player)
	end
	return slot
end

local function onBuy(player: Player, uid: any)
	if typeof(uid) ~= "string" or #uid > 12 then
		return
	end
	if not Guard.rate(player, "Buy", 0.25) then
		return
	end
	local data = DataService.get(player)
	local base = BaseService.getBase(player)
	if not data or not base then
		return
	end
	local entry = entries[uid]
	if not entry then
		AnnounceService.notify(player, "AlreadyGone", nil, "bad")
		return
	end
	local ghost = GhostData.get(entry.GhostId)
	local root = Guard.root(player)
	if not ghost or not root then
		return
	end
	-- marge de 6 studs pour la latence réseau
	if (root.Position - GhostService.positionOf(entry, now())).Magnitude > Config.BuyRange + 6 then
		AnnounceService.notify(player, "TooFar", nil, "bad")
		return
	end
	if not BaseService.findFreeSlot(player) then
		AnnounceService.notify(player, "NoFreePedestal", nil, "bad")
		return
	end
	if not EconomyService.trySpend(player, ghost.Price) then
		AnnounceService.notify(player, "NotEnoughCoins", nil, "bad")
		return
	end

	removeEntry(uid)
	local slot = GhostService.giveGhost(player, ghost.Id)
	if not slot then
		EconomyService.add(player, ghost.Price) -- ne devrait pas arriver : on rembourse
		return
	end
	AnnounceService.notify(player, "Bought", { ghost = ghost.Id }, "good")
	AnnounceService.effect("Bought", { GhostId = ghost.Id }, player)
	player:SetAttribute("HasBought", true)
	if Rarities.rank(ghost.Rarity) >= Rarities.rank("Legendary") then
		AnnounceService.announce("AnnBigBuy", { player = player.DisplayName, ghost = ghost.Id }, string.lower(ghost.Rarity))
	end
end

local function onSell(player: Player, slot: any)
	if not Guard.isInt(slot, 1, Config.MaxPedestals) then
		return
	end
	if not Guard.rate(player, "Sell", 0.3) then
		return
	end
	local base = BaseService.getBase(player)
	local ghostId = BaseService.getGhost(player, slot)
	if not base or not ghostId or BaseService.isStolenOut(player, slot) then
		return
	end
	local root = Guard.root(player)
	if not root or (root.Position - BaseService.pedestalPosition(base, slot)).Magnitude > 16 then
		AnnounceService.notify(player, "TooFar", nil, "bad")
		return
	end
	local ghost = GhostData.get(ghostId)
	BaseService.removeGhost(player, slot)
	local value = if ghost then math.floor(ghost.Price * Config.SellRatio) else 0
	EconomyService.add(player, value)
	AnnounceService.notify(player, "Sold", { coins = Format.short(value) }, "good")
	AnnounceService.effect("Sold", { Position = BaseService.pedestalPosition(base, slot) })
end

function GhostService.start()
	folder = Instance.new("Folder")
	folder.Name = "PathGhosts"
	folder.Parent = ReplicatedStorage

	Remotes.get("BuyGhost").OnServerEvent:Connect(onBuy)
	Remotes.get("SellGhost").OnServerEvent:Connect(onSell)

	-- Boucle d'apparition
	task.spawn(function()
		-- quelques fantômes déjà en route au démarrage, pour ne pas avoir un chemin vide
		for i = 1, 5 do
			GhostService.spawn()
			local entry = entries[tostring(counter)]
			if entry then
				entry.SpawnTime -= i * (TRAVEL_TIME / 6)
				entry.Holder:SetAttribute("SpawnTime", entry.SpawnTime)
			end
		end
		while true do
			local interval = Config.PathSpawnInterval
			if GhostService.isNight() then
				interval /= 1.5 -- plus de fantômes la nuit
			end
			task.wait(interval)
			local t = now()
			for uid, entry in entries do
				if t - entry.SpawnTime > TRAVEL_TIME then
					removeEntry(uid)
				end
			end
			if count() < Config.MaxGhostsOnPath then
				GhostService.spawn()
			end
		end
	end)
end

return GhostService
