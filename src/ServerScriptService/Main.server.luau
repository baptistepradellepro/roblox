--[[
	Main : le point de départ du serveur. Il démarre tous les services dans l'ordre,
	puis s'occupe de l'arrivée et du départ des joueurs.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- On fait apparaître les personnages nous-mêmes, une fois la base attribuée
Players.CharacterAutoLoads = false

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
Remotes.setup()

local Services = script.Parent:WaitForChild("Services")
local AnnounceService = require(Services:WaitForChild("AnnounceService"))
local BaseService = require(Services:WaitForChild("BaseService"))
local CodeService = require(Services:WaitForChild("CodeService"))
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local GhostService = require(Services:WaitForChild("GhostService"))
local Guard = require(Services:WaitForChild("Guard"))
local IndexService = require(Services:WaitForChild("IndexService"))
local LeaderboardService = require(Services:WaitForChild("LeaderboardService"))
local MapBuilder = require(Services:WaitForChild("MapBuilder"))
local MissionService = require(Services:WaitForChild("MissionService"))
local MonetizationService = require(Services:WaitForChild("MonetizationService"))
local MonsterService = require(Services:WaitForChild("MonsterService"))
local NightService = require(Services:WaitForChild("NightService"))
local RebirthService = require(Services:WaitForChild("RebirthService"))
local StealService = require(Services:WaitForChild("StealService"))
local WeaponService = require(Services:WaitForChild("WeaponService"))
local WheelService = require(Services:WaitForChild("WheelService"))

-- 1. La map
local map = MapBuilder.build()
BaseService.init(map)
WheelService.init(map)

-- 2. Les services
DataService.start()
BaseService.start()
EconomyService.start()
GhostService.start()
StealService.start()
WeaponService.start()
MonsterService.start()
NightService.start()
WheelService.start()
RebirthService.start()
MonetizationService.start()
CodeService.start()
LeaderboardService.start()
MissionService.start()
EconomyService.giveGhostCallback = GhostService.giveGhost
BaseService.onGhostPlaced = IndexService.discover -- chaque nouveau fantôme entre dans le Fantômédex

-- 3. Les joueurs
local function onPlayerAdded(player: Player)
	local profile = DataService.load(player)
	if not profile then
		return
	end
	if not player.Parent then
		DataService.release(player) -- parti pendant le chargement
		return
	end
	local data = profile.Data
	local lastOnline = data.LastOnline

	local base = BaseService.assign(player)
	if not base then
		DataService.release(player)
		player:Kick("Serveur plein, réessaie ! / Server full, try again!")
		return
	end

	MonetizationService.setup(player) -- Game Passes (x2 pièces, verrou+, armes)
	WeaponService.setup(player) -- la Batte et les armes achetées, à chaque apparition
	WheelService.setup(player) -- tours de Roue de la Fortune
	RebirthService.setup(player) -- aura des rebirths
	EconomyService.setup(player)
	IndexService.setup(player) -- collection (avant le cadeau, pour ne pas afficher 2 messages)
	MissionService.setup(player) -- missions du jour

	-- Premier lancement : un fantôme offert tout de suite
	if not data.StarterGiven then
		data.StarterGiven = true
		GhostService.giveGhost(player, Config.StarterGhost)
		AnnounceService.notify(player, "StarterGift", nil, "good")
		AnnounceService.effect("Gift", {}, player)
	end

	-- Bouclier débutant : personne ne peut voler pendant 2 minutes
	BaseService.giveShield(player, Config.NewPlayerShield)
	AnnounceService.notify(player, "ShieldOn", { time = Format.time(Config.NewPlayerShield) }, "info")

	EconomyService.grantOffline(player, lastOnline)
	EconomyService.sendDailyInfo(player)

	player:SetAttribute("TutorialDone", data.TutorialDone == true)
	player:SetAttribute("Ready", true)
	BaseService.spawnCharacter(player)
end

local function onPlayerRemoving(player: Player)
	StealService.onPlayerRemoving(player)
	WheelService.onPlayerRemoving(player) -- gain de la roue pas encore donné
	EconomyService.onPlayerRemoving(player)
	BaseService.release(player)
	Guard.clear(player)
	DataService.release(player)
end

Remotes.get("TutorialDone").OnServerEvent:Connect(function(player)
	local data = DataService.get(player)
	if data then
		data.TutorialDone = true
		player:SetAttribute("TutorialDone", true)
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
