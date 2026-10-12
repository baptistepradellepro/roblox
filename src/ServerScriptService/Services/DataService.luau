--[[
	DataService : charge et sauvegarde les données des joueurs (DataStoreService).

	Sécurités :
	  - 5 essais en cas d'erreur Roblox, avec une attente qui augmente
	  - "verrou de session" : si le joueur change vite de serveur, le nouveau serveur
	    attend que l'ancien ait fini de sauvegarder (évite d'écraser des données)
	  - si le chargement échoue en jeu publié, le joueur est renvoyé (kick) plutôt que
	    de jouer avec des données vides qui écraseraient sa vraie sauvegarde
	  - sauvegarde auto toutes les 2 min, à la déconnexion et à l'arrêt du serveur
	  - dans Studio sans accès aux API : on joue quand même, mais rien n'est sauvegardé
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataService = {}

export type Profile = {
	Data: { [string]: any },
	CanSave: boolean,
	Key: string,
	IsNew: boolean,
	Released: boolean,
}

local IS_STUDIO = RunService:IsStudio()
local profiles: { [Player]: Profile } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore indisponible : " .. tostring(result))
	end
end

-- Les données d'un nouveau joueur
local function template()
	return {
		Version = 1,
		Coins = Config.StartCoins,
		Slots = {}, -- ["1"] = "DrapMou" : le fantôme posé sur le socle 1
		Stored = {}, -- ["1"] = 12.5 : pièces qui attendent sur le socle 1
		Floors = 1, -- 2 quand l'étage est acheté
		Rebirths = 0,
		TotalEarned = 0,
		TotalSteals = 0,
		LastOnline = 0,
		DailyDay = 0, -- dernier jour (UTC) où le cadeau a été récupéré
		DailyStreak = 0,
		StarterGiven = false,
		TutorialDone = false,
		Receipts = {}, -- achats Robux déjà traités (anti double crédit)
		Discovered = {}, -- Fantômédex : ["DrapMou"] = true
		IndexRewards = {}, -- séries déjà récompensées : ["Common"] = true
		IndexComplete = false, -- bonus permanent du Fantômédex complet
		RedeemedCodes = {}, -- codes promo déjà utilisés : ["BOUH2026"] = true
		Missions = {}, -- missions du jour : { Day, List, BonusDone }
		Spins = 0, -- tours de Roue de la Fortune achetés et pas encore utilisés
		BoostUntil = 0, -- fin du bonus "x2 revenus" de la roue (temps Unix)
	}
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Ajoute les champs manquants (utile quand on ajoute une nouveauté au jeu)
local function reconcile(data: { [string]: any }, tmpl: { [string]: any })
	for key, value in tmpl do
		if data[key] == nil then
			data[key] = deepCopy(value)
		end
	end
end

local function makeProfile(player: Player, data, canSave: boolean): Profile
	reconcile(data, template())
	local profile: Profile = {
		Data = data,
		CanSave = canSave,
		Key = "Player_" .. player.UserId,
		IsNew = data.LastOnline == 0,
		Released = false,
	}
	profiles[player] = profile
	return profile
end

local function studioFallback(player: Player, reason: any): Profile
	warn(
		"[DataService] Mode test : la sauvegarde est désactivée ("
			.. tostring(reason)
			.. "). Pour l'activer dans Studio : Accueil > Paramètres du jeu > Sécurité > "
			.. "'Enable Studio Access to API Services'."
	)
	return makeProfile(player, template(), false)
end

-- Charge les données d'un joueur. Renvoie nil si le joueur a été renvoyé ou est parti.
function DataService.load(player: Player): Profile?
	if not store then
		if IS_STUDIO then
			return studioFallback(player, "pas de DataStore")
		end
		player:Kick("Les sauvegardes Roblox ne répondent pas, réessaie dans un instant. / Roblox saves are down, please retry soon.")
		return nil
	end

	local ds = store :: DataStore
	local key = "Player_" .. player.UserId
	local attempts = 0
	local waitedForLock = 0

	while player.Parent do
		attempts += 1
		local lockedElsewhere = false
		local loaded = nil
		local ok, err = pcall(function()
			ds:UpdateAsync(key, function(old)
				lockedElsewhere = false
				loaded = nil
				if type(old) == "table" and type(old.Lock) == "table" and old.Lock.Job ~= game.JobId then
					local age = os.time() - (old.Lock.Time or 0)
					if age < Config.SessionLockTimeout and waitedForLock < Config.SessionLockMaxWait then
						lockedElsewhere = true
						return nil -- on n'écrit rien, on réessaiera
					end
				end
				local data = if type(old) == "table" then old else template()
				data.Lock = { Job = game.JobId, Time = os.time() }
				loaded = data
				return data
			end)
		end)

		if ok and loaded and not lockedElsewhere then
			return makeProfile(player, loaded, true)
		elseif ok and lockedElsewhere then
			-- L'ancien serveur n'a pas encore fini de sauvegarder : on patiente
			waitedForLock += 5
			task.wait(5)
		else
			warn(string.format("[DataService] Échec de chargement pour %s (essai %d) : %s", player.Name, attempts, tostring(err)))
			if IS_STUDIO then
				return studioFallback(player, err)
			end
			if attempts >= 5 then
				player:Kick("Impossible de charger ta sauvegarde, réessaie. / Could not load your save, please rejoin.")
				return nil
			end
			task.wait(2 ^ attempts)
		end
	end
	return nil
end

local function writeOnce(profile: Profile, release: boolean): (boolean, any)
	local snapshot = deepCopy(profile.Data)
	snapshot.LastOnline = os.time()
	snapshot.Lock = if release then nil else { Job = game.JobId, Time = os.time() }
	local ds = store :: DataStore
	return pcall(function()
		ds:UpdateAsync(profile.Key, function(old)
			if profile.Released and not release then
				return nil -- le joueur est déjà parti : une vieille sauvegarde auto ne doit rien écrire
			end
			if type(old) == "table" and type(old.Lock) == "table" and old.Lock.Job ~= game.JobId then
				return nil -- un autre serveur a repris ce joueur : on n'écrase pas
			end
			return snapshot
		end)
	end)
end

-- Sauvegarde un joueur. release = true quand il quitte le jeu.
function DataService.save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile then
		return true
	end
	if release then
		profile.Released = true
	end
	if not profile.CanSave or not store then
		return true
	end
	for attempt = 1, 3 do
		local ok, err = writeOnce(profile, release == true)
		if ok then
			return true
		end
		warn(string.format("[DataService] Échec de sauvegarde pour %s (essai %d) : %s", player.Name, attempt, tostring(err)))
		task.wait(attempt)
	end
	return false
end

-- Appelé quand le joueur quitte : dernière sauvegarde puis on oublie son profil
function DataService.release(player: Player)
	DataService.save(player, true)
	profiles[player] = nil
end

function DataService.getProfile(player: Player): Profile?
	return profiles[player]
end

-- Les données du joueur (nil si pas encore chargées)
function DataService.get(player: Player): { [string]: any }?
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService.canSave(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.CanSave
end

function DataService.start()
	-- Sauvegarde automatique
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			local list = {}
			for player, profile in profiles do
				if profile.CanSave and not profile.Released then
					table.insert(list, player)
				end
			end
			for _, player in list do
				task.spawn(DataService.save, player, false)
				task.wait(1) -- on étale les sauvegardes
			end
		end
	end)

	-- Arrêt du serveur : on sauvegarde tout le monde avant de fermer
	game:BindToClose(function()
		if not store then
			return
		end
		local pending = 0
		for player, profile in profiles do
			if profile.CanSave and not profile.Released then
				pending += 1
				task.spawn(function()
					DataService.save(player, true)
					pending -= 1
				end)
			end
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)
end

return DataService
