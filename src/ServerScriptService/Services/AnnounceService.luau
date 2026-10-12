--[[
	AnnounceService : envoie des messages aux joueurs.
	On envoie des CLÉS de texte (ex. "AnnSteal") et chaque joueur les traduit
	dans sa langue. Les paramètres "ghost" sont des Id de fantômes, traduits aussi.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local AnnounceService = {}

local notifyRemote = Remotes.get("Notify")
local announceRemote = Remotes.get("Announce")
local effectRemote = Remotes.get("Effect")

-- Petit message pour un seul joueur. kind = "info", "good", "bad"
function AnnounceService.notify(player: Player, key: string, params: { [string]: any }?, kind: string?)
	if player.Parent then
		notifyRemote:FireClient(player, key, params or {}, kind or "info")
	end
end

-- Grande annonce pour tout le serveur. kind = "steal", "mythic", "halloween", "rebirth", "night"...
function AnnounceService.announce(key: string, params: { [string]: any }?, kind: string?)
	announceRemote:FireAllClients(key, params or {}, kind or "info")
end

-- Effet visuel/sonore. Si player est donné, seul ce joueur le voit.
function AnnounceService.effect(kind: string, data: { [string]: any }?, player: Player?)
	if player then
		if player.Parent then
			effectRemote:FireClient(player, kind, data or {})
		end
	else
		effectRemote:FireAllClients(kind, data or {})
	end
end

return AnnounceService
