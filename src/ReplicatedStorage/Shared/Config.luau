--[[
	Config : TOUS les réglages du jeu au même endroit.
	Tu peux changer les nombres ici sans toucher au reste du code.
	(Les durées sont en secondes, les distances en "studs", l'unité de Roblox.)
]]

local Config = {}

-- Langue forcée pour tes tests : "fr", "en" ou nil (= automatique selon le joueur)
Config.ForceLanguage = nil

-- ===== Sauvegarde =====
Config.DataStoreName = "StealAGhost_Data_v1"
Config.AutosaveInterval = 120 -- sauvegarde automatique toutes les 2 minutes
Config.SessionLockTimeout = 600 -- verrou de session : évite que 2 serveurs sauvegardent le même joueur
Config.SessionLockMaxWait = 25 -- au pire, on attend 25 s avant de reprendre la main

-- ===== Bases =====
Config.BaseCount = 12 -- une base par joueur (mets 12 joueurs max dans les paramètres)
Config.PedestalsPerFloor = 10 -- 5 socles à gauche + 5 à droite
Config.MaxPedestals = 20 -- 2 étages
Config.FloorPrice = 50000 -- prix de l'étage 2 (en pièces)
Config.RebirthKeepsFloors = true -- false = le rebirth fait aussi perdre l'étage 2
Config.StartCoins = 100
Config.StarterGhost = "DrapMou" -- le fantôme offert au premier lancement
Config.BaseIncome = 1 -- pièces/s versées directement, pour ne jamais être bloqué à 0
-- Les fantômes, eux, remplissent leur socle : il faut passer sur la plaque verte
-- devant le socle pour récupérer les pièces.
Config.RespawnDelay = 3

-- ===== Chemin hanté =====
Config.PathStartX = -150
Config.PathEndX = 150
Config.PathY = 4.5
Config.PathZ = 0
Config.PathSpeed = 7 -- vitesse des fantômes sur le chemin
Config.PathSpawnInterval = 3.5 -- un nouveau fantôme toutes les 3,5 s
Config.MaxGhostsOnPath = 12
Config.BuyRange = 14 -- distance max pour acheter
Config.SellRatio = 0.5 -- on revend à 50 % du prix

-- ===== Vol =====
Config.StealHoldDuration = 1.5 -- temps à maintenir pour voler
Config.StealRange = 12
Config.NormalWalkSpeed = 16
Config.CarrierWalkSpeed = 10 -- le voleur est ralenti
Config.StealTimeout = 45 -- au-delà, le fantôme rentre chez lui
Config.RecoverRange = 6 -- le propriétaire touche le voleur = fantôme récupéré
-- Les armes contre les voleurs (portée, recharge...) sont réglées dans Weapons.luau

-- ===== Pièges (achetés avec des pièces, une fois pour toutes) =====
-- Price = prix, Cooldown = temps avant de resservir (banane) ou entre deux alertes (alarme)
Config.Traps = {
	Banana = { Price = 2500, Cooldown = 40, Stun = 2.5 },
	Web = { Price = 8000, Speed = 6, SlowTime = 4 },
	Alarm = { Price = 20000, Cooldown = 20, RingTime = 6 },
}
Config.RebirthKeepsTraps = true -- false = le rebirth fait aussi perdre les pièges

-- ===== Verrou de base =====
Config.LockDuration = 45
Config.LockCooldown = 120 -- recharge après la fin du verrou
Config.NewPlayerShield = 45 -- protection automatique à l'arrivée (porte fermée 45 s, comme le verrou)

-- ===== Nuit Hantée =====
Config.DayDuration = 480 -- 8 min de jour...
Config.NightDuration = 120 -- ...puis 2 min de nuit = une nuit toutes les 10 min
Config.NightWarning = 10 -- alerte "la nuit tombe" 10 s avant
Config.MonsterSpeed = 14
Config.MonsterCatchRange = 5
Config.MonsterCoinPenalty = 0.05 -- perd 5 % de ses pièces si attrapé
Config.MonsterStunTime = 2

-- Thèmes de nuit, tirés au hasard (plus le nombre est grand, plus c'est fréquent)
Config.NightThemes = { Classic = 50, Fog = 25, Candy = 25 }
Config.FogMonsterSpeed = 15 -- Nuit du Brouillard : Gloutrouille va plus vite
Config.CandyCoinCount = 24 -- Nuit des Bonbons : pièces bonus posées en même temps
Config.CandyCoinSeconds = 8 -- chaque pièce vaut 8 s de revenus (minimum 25 pièces)
-- Super Nuit : chaque samedi de 17h à 18h UTC (= 18h-19h à Paris en hiver)
-- Gloutrouille géant, un Mythique garanti et 3 fois plus de variantes
Config.SuperNight = { WeekDay = 7, StartHour = 17, EndHour = 18 } -- WeekDay : 1 = dimanche ... 7 = samedi
Config.SuperMonsterScale = 1.6
Config.SuperMutationBoost = 3

-- Week-end x2 : revenus doublés du vendredi 17h UTC au dimanche 23h UTC
Config.WeekendBoost = { Enabled = true, Mult = 2 }
Config.WheelBoostMult = 2 -- case "x2 revenus" de la Roue de la Fortune

-- ===== Rebirth =====
Config.RebirthBaseCost = 10000000
Config.RebirthCostGrowth = 3
Config.RebirthIncomeBonus = 0.5 -- +50 % de revenus par rebirth

-- ===== Retour des joueurs =====
Config.FriendBonus = 0.10 -- +10 % par ami dans le serveur
Config.FriendBonusMax = 0.50
Config.OfflineRate = 0.5 -- 50 % des revenus pendant l'absence
Config.OfflineCapSeconds = 3 * 3600 -- plafond : 3 heures
Config.OfflineMinSeconds = 60
-- Récompense quotidienne (jour 1 à 7, puis ça recommence)
-- Minutes = combien de minutes de revenus on reçoit, Min = minimum de pièces
Config.DailyRewards = {
	{ Minutes = 2, Min = 100 },
	{ Minutes = 3, Min = 250 },
	{ Minutes = 4, Min = 500 },
	{ Minutes = 5, Min = 1000 },
	{ Minutes = 6, Min = 2000 },
	{ Minutes = 8, Min = 4000 },
	{ Minutes = 10, Min = 8000, RandomGhostRarity = "Epic" },
}

-- ===== Fantômédex (collection) =====
-- Pièces gagnées quand on a trouvé TOUS les fantômes d'une rareté
Config.IndexRewards = {
	Common = 500,
	Rare = 5000,
	Epic = 50000,
	Legendary = 400000,
	Mythic = 5000000,
	Halloween = 2000000,
}
-- Bonus permanent quand tous les fantômes (hors Halloween) sont trouvés : +10 % de revenus
Config.IndexCompleteBonus = 0.10

-- ===== Codes promo =====
-- Publie-les sur TikTok / Shorts. Le joueur les tape dans la Boutique.
-- Coins = pièces fixes, Minutes/Min = minutes de revenus (minimum Min), Ghost = un fantôme offert.
-- Expires = date de fin en temps Unix (0 = jamais). Un code ne marche qu'une fois par joueur.
-- Astuce : https://www.epochconverter.com transforme une date en temps Unix.
Config.Codes = {
	BOUH2026 = { Coins = 5000, Expires = 0 },
	GLOUTROUILLE = { Minutes = 10, Min = 2000, Expires = 0 },
	POUET = { Ghost = "Caquetome", Expires = 0 },
}

-- ===== Événement Halloween =====
-- Dates en "temps Unix" (UTC). 1790812800 = 1er oct. 2026, 1793664000 = 3 nov. 2026
Config.HalloweenStart = 1790812800
Config.HalloweenEnd = 1793664000
Config.ForceHalloween = false -- mets true pour tester les fantômes Halloween hors période

-- ===== Monétisation (mets 0 tant que tu ne les as pas créés) =====
-- La liste complète des articles, avec les prix conseillés, est dans Shop.luau.
-- Dans Studio, un article dont l'ID vaut 0 est donné gratuitement quand on clique dessus
-- (pour tester). Dans le vrai jeu, il affiche "Bientôt".
Config.GamePasses = {
	DoubleCoins = 0, -- ID du Game Pass "x2 Pièces"
	WeaponHammer = 0, -- ID du Game Pass "Marteau Pouet Géant"
	WeaponBroom = 0, -- ID du Game Pass "Balai de Sorcière"
	WeaponVacuum = 0, -- ID du Game Pass "Aspira-Fantôme"
}
Config.Products = {
	CoinPack = 0, -- ID du Developer Product "Pack de pièces"
	Spin1 = 0, -- ID du Developer Product "1 tour de roue"
	Spin5 = 0, -- ID du Developer Product "5 tours de roue"
	MonsterGloutrouille = 0, -- ID du Developer Product "Lâcher Gloutrouille"
	MonsterBat = 0, -- ID du Developer Product "Lâcher la Chauve-Souris Turbo"
	MonsterSpider = 0, -- ID du Developer Product "Lâcher Mamie Toile"
}
-- Icônes de la boutique (facultatif). Pour mettre tes propres images :
-- Creator Hub > Développement > Décalcomanies (Decals) > importe l'image, copie son ID,
-- et colle "rbxassetid://ID" ci-dessous. Vide = l'emoji habituel.
Config.ShopIcons = {
	Batte = "",
	MarteauPouet = "",
	BalaiSorciere = "",
	AspiraFantome = "",
	Gloutrouille = "",
	MamieToile = "",
	ChauveSourisTurbo = "",
	Wheel = "",
}
Config.CoinPackMinutes = 10 -- le pack donne 10 min de revenus...
Config.CoinPackMin = 5000 -- ...et au moins 5 000 pièces

return Config
