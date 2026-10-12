--[[
	AwardService : les badges Roblox, affichés sur le profil des joueurs (leurs amis
	les voient, c'est une bonne pub gratuite).
	Chaque badge se crée sur le Creator Hub (ton jeu > Engagement > Badges), puis son
	ID va dans Config.Badges. Tant qu'un ID vaut 0, le badge est ignoré.
	Un badge n'est demandé qu'une fois par joueur (on le note dans sa sauvegarde).
]]

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GhostData = require(Shared:WaitForChild("GhostData"))

local DataService = require(script.Parent.DataService)
local Hooks = require(script.Parent.Hooks)

local AwardService = {}

-- Donne un badge (une seule fois). key = nom dans Config.Badges
function AwardService.award(player: Player, key: string)
	local badgeId = Config.Badges[key]
	local data = DataService.get(player)
	if not badgeId or badgeId == 0 or not data then
		return
	end
	data.Badges = data.Badges or {}
	if data.Badges[key] then
		return
	end
	local ok, err = pcall(function()
		BadgeService:AwardBadge(player.UserId, badgeId)
	end)
	if ok then
		data.Badges[key] = true
	else
		warn("[AwardService] Badge " .. key .. " non donné : " .. tostring(err))
	end
end

function AwardService.setup(player: Player)
	AwardService.award(player, "Welcome")
end

function AwardService.start()
	Hooks.on("Steal", function(player: Player)
		AwardService.award(player, "FirstSteal")
	end)
	Hooks.on("Discover", function(player: Player, ghostId: string)
		local ghost = GhostData.get(ghostId)
		if ghost and ghost.Rarity == "Mythic" then
			AwardService.award(player, "FirstMythic")
		elseif ghost and ghost.Rarity == "Secret" then
			AwardService.award(player, "FirstSecret")
		end
	end)
	Hooks.on("Rebirth", function(player: Player)
		AwardService.award(player, "FirstRebirth")
	end)
	Hooks.on("IndexComplete", function(player: Player)
		AwardService.award(player, "IndexComplete")
	end)
	Hooks.on("WeeklyBonus", function(player: Player)
		AwardService.award(player, "WeeklyChallenges")
	end)
end

return AwardService
