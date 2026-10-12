--[[
	Sounds : tous les sons du jeu au même endroit.

	Par défaut on utilise des sons intégrés à Roblox ("rbxasset://...") : gratuits et
	toujours disponibles. Pour mettre un son du Creator Store à la place :
	  1. Dans Studio : onglet Accueil > Boîte à outils (Toolbox) > catégorie Audio
	  2. Choisis un son gratuit, clic droit > "Copier l'ID de l'élément" (Copy Asset ID)
	  3. Remplace l'Id ci-dessous par "rbxassetid://" suivi du numéro, ex. "rbxassetid://1234567"
	Laisse "" pour désactiver un son.

	Pitch = hauteur (1 = normal, 2 = plus aigu, 0.5 = plus grave)
	Jingle = liste de hauteurs jouées l'une après l'autre (petite fanfare)
]]

local PING = "rbxasset://sounds/electronicpingshort.wav"
local SWOOSH = "rbxasset://sounds/swoosh.wav"
local OOF = "rbxasset://sounds/uuhhh.mp3"
local JUMP = "rbxasset://sounds/action_jump.mp3"

local Sounds = {
	Click = { Id = PING, Volume = 0.25, Pitch = 2.2 },
	Buy = { Id = PING, Volume = 0.6, Jingle = { 1.2, 1.6 } },
	Sell = { Id = PING, Volume = 0.5, Jingle = { 1.6, 1.2 } },
	Gift = { Id = PING, Volume = 0.6, Jingle = { 1, 1.26, 1.5, 2 } },
	Error = { Id = PING, Volume = 0.4, Pitch = 0.55 },
	StealStart = { Id = SWOOSH, Volume = 0.8, Pitch = 1.2 },
	StealAlert = { Id = PING, Volume = 0.7, Jingle = { 2, 1.5, 2, 1.5 } },
	StealSuccess = { Id = PING, Volume = 0.8, Jingle = { 1, 1.26, 1.5, 2, 1.5, 2 } },
	StealFail = { Id = OOF, Volume = 0.7, Pitch = 1.1 },
	Bonk = { Id = JUMP, Volume = 1, Pitch = 2.4 },
	Lock = { Id = PING, Volume = 0.6, Jingle = { 0.8, 0.6 } },
	Mythic = { Id = PING, Volume = 0.9, Jingle = { 1.5, 2, 2.5, 3, 2.5, 3 } },
	NightStart = { Id = SWOOSH, Volume = 1, Pitch = 0.4 },
	NightEnd = { Id = PING, Volume = 0.5, Jingle = { 1, 1.5, 2 } },
	MonsterCatch = { Id = OOF, Volume = 1, Pitch = 0.6 },
	Heartbeat = { Id = PING, Volume = 0.5, Jingle = { 0.35, 0.3 } },
	Rebirth = { Id = PING, Volume = 0.9, Jingle = { 1, 1.26, 1.5, 2, 2.52, 3 } },
	Swing = { Id = SWOOSH, Volume = 0.6, Pitch = 1.7 },
	Vacuum = { Id = SWOOSH, Volume = 0.9, Pitch = 0.6 },
	WheelTick = { Id = PING, Volume = 0.2, Pitch = 2.8 },
	WheelWin = { Id = PING, Volume = 0.8, Jingle = { 1, 1.5, 2, 1.5, 2, 2.5 } },
	MonsterSummon = { Id = SWOOSH, Volume = 1, Pitch = 0.3 },
	Alarm = { Id = PING, Volume = 0.8, Jingle = { 2, 1.5, 2, 1.5, 2, 1.5 } },
	Slip = { Id = SWOOSH, Volume = 0.9, Pitch = 1.4 },
	Web = { Id = SWOOSH, Volume = 0.6, Pitch = 0.5 },
	-- Musique de fond pendant la Nuit Hantée (aucune par défaut).
	-- Mets ici l'ID d'une musique gratuite du Creator Store (catégorie Audio > Music).
	NightMusic = { Id = "", Volume = 0.4, Looped = true },
	DayMusic = { Id = "", Volume = 0.25, Looped = true },
}

return Sounds
