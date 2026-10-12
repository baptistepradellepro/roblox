--[[
	Remotes : la liste des "messages" entre les joueurs (client) et le serveur.
	Règle d'or : le client DEMANDE, le serveur VÉRIFIE et DÉCIDE.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Names = {
	-- Client -> Serveur (des demandes, toujours vérifiées)
	"BuyGhost", -- (uid) acheter un fantôme du chemin
	"SellGhost", -- (slot) revendre un fantôme de sa base
	"StealBegin", -- (baseIndex, slot) début du maintien sur "Voler"
	"Steal", -- (baseIndex, slot) fin du maintien sur "Voler"
	"Bonk", -- () coup de Marteau Pouet
	"RequestLock", -- () verrouiller sa base
	"ClaimDaily", -- () récupérer le cadeau du jour
	"Rebirth", -- () faire un rebirth
	"TutorialDone", -- () le tutoriel est terminé
	-- Serveur -> Client
	"Notify", -- (key, params, kind) petit message pour un joueur
	"Announce", -- (key, params, kind) grande annonce pour tout le serveur
	"Effect", -- (kind, data) effet visuel / sonore
	"DailyInfo", -- (info) état du cadeau du jour
}

local FOLDER_NAME = "Remotes"

-- Appelé UNE fois par le serveur au démarrage
function Remotes.setup()
	assert(RunService:IsServer(), "Remotes.setup() est réservé au serveur")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in Remotes.Names do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

-- Récupère un RemoteEvent par son nom (attend qu'il existe côté client)
function Remotes.get(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
