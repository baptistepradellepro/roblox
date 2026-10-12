--[[
	Strings : tous les textes du jeu en français (fr) et en anglais (en).
	Les mots entre accolades {comme_ca} sont remplacés automatiquement.
	Les noms de fantômes et de raretés sont dans GhostData / plus bas.
]]

local Strings = {}

Strings.fr = {
	-- Raretés
	Rarity_Common = "Commun",
	Rarity_Rare = "Rare",
	Rarity_Epic = "Épique",
	Rarity_Legendary = "Légendaire",
	Rarity_Mythic = "Mythique",
	Rarity_Halloween = "Halloween",

	-- Boutons et invites
	Buy = "Acheter",
	Steal = "Voler",
	Sell = "Vendre",
	Lock = "Verrouiller",
	Bonk = "Pouet !",
	PerSecond = "{coins}/s",
	SellFor = "Vendre {coins}",
	BuyFor = "{coins}",

	-- Bases
	YourBase = "TA BASE",
	BaseOf = "Base de {name}",
	FreeBase = "Base libre",
	LockedFor = "{time}",
	LockReady = "Verrou",
	LockCooldown = "Recharge {time}",
	ThiefLabel = "VOLEUR !",

	-- Notifications
	NotEnoughCoins = "Pas assez de pièces !",
	NoFreePedestal = "Plus de socle libre ! Vends un fantôme.",
	NoFreePedestalFloor = "Base pleine ! Achète l'étage 2 ou vends un fantôme.",
	NoFreePedestalThief = "Ta base est pleine, impossible de voler !",
	BaseIsLocked = "Cette base est verrouillée !",
	TooFar = "Trop loin !",
	AlreadyCarrying = "Tu portes déjà un fantôme !",
	AlreadyGone = "Trop tard, il est parti !",
	Bought = "{ghost} est à toi !",
	Sold = "Vendu pour {coins} pièces",
	StarterGift = "Cadeau ! Voici ton premier fantôme",
	LockOn = "Base verrouillée !",
	LockNotReady = "Le verrou recharge encore ({time})",
	ShieldOn = "Bouclier débutant : personne ne peut te voler pendant {time}",
	StealGo = "Cours jusqu'à ta base !",
	StealAlert = "{thief} vole ton {ghost} ! Attrape-le !",
	StealFailTimeout = "Trop lent ! {ghost} est rentré chez lui.",
	StealFailBonk = "POUET ! Tu as lâché {ghost} !",
	StealFailCaught = "{owner} t'a rattrapé !",
	StealFailMonster = "Gloutrouille t'a fait lâcher {ghost} !",
	StealFailNoSpace = "Ta base est pleine, {ghost} est reparti !",
	Recovered = "Tu as récupéré {ghost} !",
	OwnerLeftGift = "{owner} est parti... {ghost} est à toi !",
	BonkHit = "Bien joué ! {ghost} rentre chez {owner}",
	NotAllowed = "Impossible pour l'instant",

	-- Annonces serveur
	AnnSteal = "{thief} a volé {ghost} à {owner} !",
	AnnMythicSpawn = "Un fantôme MYTHIQUE apparaît : {ghost} !",
	AnnHalloweenSpawn = "Un fantôme HALLOWEEN apparaît : {ghost} !",
	AnnRainbowSpawn = "Un fantôme ARC-EN-CIEL apparaît : {ghost} !",
	AnnBigBuy = "{player} a attrapé {ghost} !",
	AnnRebirth = "{player} a fait son rebirth n°{count} !",
	AnnCaught = "Gloutrouille a attrapé {player} !",

	-- HUD
	Income = "+{coins}/s",
	FriendsBonus = "Amis +{percent} %",

	-- Nuit Hantée
	NightSoon = "La Nuit Hantée tombe dans {time} !",
	NightStart = "NUIT HANTÉE ! Fantômes rares... et Gloutrouille !",
	NightStartFog = "NUIT DU BROUILLARD ! On n'y voit rien... et Gloutrouille va plus vite !",
	NightStartCandy = "NUIT DES BONBONS ! Des pièces sur le chemin... à tes risques !",
	NightStartSuper = "SUPER NUIT ! Gloutrouille GÉANT et un Mythique garanti !",
	WeekendBoost = "Week-end x2 !",
	NightEnd = "Le jour se lève. Ouf !",
	NightTimer = "Nuit : {time}",
	DayTimer = "Nuit dans {time}",
	MonsterCaughtYou = "BOUH ! Gloutrouille t'a attrapé (-{coins} pièces)",
	SafeInBase = "Ta base te protège de Gloutrouille",

	-- Rebirth
	Rebirth = "Rebirth",
	RebirthTitle = "REBIRTH",
	RebirthDesc = "Recommence à zéro (pièces et fantômes) et gagne pour toujours :",
	RebirthGain = "+{percent} % de revenus pour toujours",
	RebirthCost = "Coût : {coins} pièces",
	RebirthCurrent = "Multiplicateur actuel : x{mult}",
	RebirthConfirm = "REBIRTH !",
	RebirthSure = "Sûr ? Re-clique !",
	RebirthNotEnough = "Il te faut {coins} pièces",
	RebirthBusy = "Pas pendant un vol !",
	RebirthDone = "Rebirth réussi ! Revenus x{mult}",

	-- Récompense quotidienne
	Daily = "Cadeau",
	DailyTitle = "CADEAU DU JOUR",
	DailyDay = "Jour {day}",
	DailyClaim = "Récupérer",
	DailyClaimed = "Reviens demain !",
	DailyGot = "Jour {day} : +{coins} pièces !",
	DailyGotGhost = "Jour {day} : +{coins} pièces et {ghost} !",
	DailyNext = "Prochain cadeau dans {time}",
	DailyGhostBonus = "+ fantôme Épique",
	OfflineEarned = "Pendant ton absence, tes fantômes ont produit {coins} pièces : va les récupérer sur les plaques vertes !",

	-- Boutique
	Shop = "Boutique",
	ShopTitle = "BOUTIQUE",
	ShopDouble = "x2 Pièces",
	ShopDoubleDesc = "Double tous tes revenus, pour toujours",
	ShopLock = "Verrou+",
	ShopLockDesc = "Verrou de {long} s au lieu de {normal} s",
	ShopCoins = "Pack de pièces",
	ShopCoinsDesc = "+{coins} pièces tout de suite",
	ShopOwned = "Possédé",
	ShopSoon = "Bientôt",
	ShopThanks = "Merci ! Achat reçu",

	-- Tutoriel (3 flèches, très peu de texte)
	Tuto1 = "Achète !",
	Tuto2 = "Récupère !",
	Tuto3 = "Vole !",

	-- Base : récolte, étage, verrou
	StoredPill = "{coins} à récupérer",
	FloorBuy = "Acheter l'étage 2",
	FloorLocked = "Étage 2 : {coins}",
	FloorUp = "Étage 2",
	FloorDown = "Rez-de-chaussée",
	FloorBought = "Étage 2 débloqué : 10 socles de plus !",
	LockStation = "VERROU",


	-- Fantômédex
	Index = "Fantômédex",
	IndexTitle = "FANTÔMÉDEX",
	IndexNew = "Nouveau dans le Fantômédex : {ghost} !",
	IndexRarityDone = "Série {rarity} complète ! +{coins} pièces",
	IndexCompleteDone = "Fantômédex complet ! +{percent} % de revenus pour toujours",
	IndexBonus = "Trouve-les tous : +{percent} % de revenus pour toujours",
	IndexBonusDone = "Fantômédex complet : +{percent} % de revenus",
	IndexHint = "Touche un fantôme pour lire sa fiche",
	IndexUnknown = "???",
	IndexUnknownHint = "Pas encore trouvé. Guette le chemin... ou les bases des autres !",
	IndexCard = "{ghost} : {gag}",
	AnnIndexComplete = "{player} a complété le Fantômédex !",

	-- Codes promo
	Codes = "Codes secrets",
	CodesDesc = "Tape un code secret",
	CodePlaceholder = "CODE",
	CodeRedeem = "OK",
	CodeOk = "Code accepté : +{coins} pièces !",
	CodeOkGhost = "Code accepté : {ghost} est à toi !",
	CodeUsed = "Tu as déjà utilisé ce code",
	CodeInvalid = "Code invalide",
	CodeExpired = "Ce code a expiré",

	-- Missions du jour
	Missions = "Missions",
	MissionsTitle = "MISSIONS DU JOUR",
	Mission_Buy = "Achète {n} fantômes",
	Mission_Earn = "Gagne {n} pièces",
	Mission_Lock = "Verrouille ta base",
	Mission_Sell = "Vends {n} fantômes",
	Mission_BuyRare = "Achète un fantôme Rare ou mieux",
	Mission_NightOutside = "Reste {n} s hors de ta base pendant une Nuit Hantée",
	Mission_Steal = "Vole un fantôme à un autre joueur",
	Mission_Bonk = "Arrête un voleur au Marteau Pouet",
	Mission_BuyEpic = "Achète un fantôme Épique ou mieux",
	MissionTier_easy = "Facile",
	MissionTier_medium = "Moyen",
	MissionTier_hard = "Difficile",
	MissionReward = "+{coins}",
	MissionDone = "Mission réussie : +{coins} pièces !",
	MissionsAllDone = "Les 3 missions sont faites ! Bonus : +{coins} pièces",
	MissionsBonus = "🎁 Les 3 missions : bonus de {coins} pièces",
	MissionsBonusDone = "✅ Bonus du jour récupéré, reviens demain !",
	MissionsNext = "Nouvelles missions dans {time}",

	-- Classement des voleurs
	LeaderTitle = "PLUS GRANDS VOLEURS DE LA SEMAINE",
	LeaderEmpty = "Personne n'a encore volé cette semaine... à toi de jouer !",
	LeaderSteals = "🦹 {count}",
	LeaderReset = "Remise à zéro dans {days} j {hours} h",

	Close = "Fermer",
}

Strings.en = {
	Rarity_Common = "Common",
	Rarity_Rare = "Rare",
	Rarity_Epic = "Epic",
	Rarity_Legendary = "Legendary",
	Rarity_Mythic = "Mythic",
	Rarity_Halloween = "Halloween",

	Buy = "Buy",
	Steal = "Steal",
	Sell = "Sell",
	Lock = "Lock",
	Bonk = "Bonk!",
	PerSecond = "{coins}/s",
	SellFor = "Sell {coins}",
	BuyFor = "{coins}",

	YourBase = "YOUR BASE",
	BaseOf = "{name}'s base",
	FreeBase = "Free base",
	LockedFor = "{time}",
	LockReady = "Lock",
	LockCooldown = "Ready in {time}",
	ThiefLabel = "THIEF!",

	NotEnoughCoins = "Not enough coins!",
	NoFreePedestal = "No free pedestal! Sell a ghost.",
	NoFreePedestalFloor = "Base full! Buy floor 2 or sell a ghost.",
	NoFreePedestalThief = "Your base is full, you can't steal!",
	BaseIsLocked = "This base is locked!",
	TooFar = "Too far!",
	AlreadyCarrying = "You're already carrying a ghost!",
	AlreadyGone = "Too late, it's gone!",
	Bought = "{ghost} is yours!",
	Sold = "Sold for {coins} coins",
	StarterGift = "Gift! Here's your first ghost",
	LockOn = "Base locked!",
	LockNotReady = "Lock still recharging ({time})",
	ShieldOn = "Newbie shield: nobody can steal from you for {time}",
	StealGo = "Run back to your base!",
	StealAlert = "{thief} is stealing your {ghost}! Catch them!",
	StealFailTimeout = "Too slow! {ghost} went home.",
	StealFailBonk = "BONK! You dropped {ghost}!",
	StealFailCaught = "{owner} caught you!",
	StealFailMonster = "Gloutrouille made you drop {ghost}!",
	StealFailNoSpace = "Your base is full, {ghost} went back!",
	Recovered = "You got {ghost} back!",
	OwnerLeftGift = "{owner} left... {ghost} is yours!",
	BonkHit = "Nice! {ghost} goes back to {owner}",
	NotAllowed = "Not possible right now",

	AnnSteal = "{thief} stole {ghost} from {owner}!",
	AnnMythicSpawn = "A MYTHIC ghost appeared: {ghost}!",
	AnnHalloweenSpawn = "A HALLOWEEN ghost appeared: {ghost}!",
	AnnRainbowSpawn = "A RAINBOW ghost appeared: {ghost}!",
	AnnBigBuy = "{player} grabbed {ghost}!",
	AnnRebirth = "{player} just did rebirth #{count}!",
	AnnCaught = "Gloutrouille caught {player}!",

	Income = "+{coins}/s",
	FriendsBonus = "Friends +{percent}%",

	NightSoon = "The Haunted Night falls in {time}!",
	NightStart = "HAUNTED NIGHT! Rare ghosts... and Gloutrouille!",
	NightStartFog = "FOG NIGHT! You can't see a thing... and Gloutrouille is faster!",
	NightStartCandy = "CANDY NIGHT! Coins on the path... at your own risk!",
	NightStartSuper = "SUPER NIGHT! GIANT Gloutrouille and a guaranteed Mythic!",
	WeekendBoost = "Weekend x2!",
	NightEnd = "The sun is rising. Phew!",
	NightTimer = "Night: {time}",
	DayTimer = "Night in {time}",
	MonsterCaughtYou = "BOO! Gloutrouille caught you (-{coins} coins)",
	SafeInBase = "Your base protects you from Gloutrouille",

	Rebirth = "Rebirth",
	RebirthTitle = "REBIRTH",
	RebirthDesc = "Start over (coins and ghosts) and earn forever:",
	RebirthGain = "+{percent}% income forever",
	RebirthCost = "Cost: {coins} coins",
	RebirthCurrent = "Current multiplier: x{mult}",
	RebirthConfirm = "REBIRTH!",
	RebirthSure = "Sure? Tap again!",
	RebirthNotEnough = "You need {coins} coins",
	RebirthBusy = "Not during a theft!",
	RebirthDone = "Rebirth done! Income x{mult}",

	Daily = "Gift",
	DailyTitle = "DAILY GIFT",
	DailyDay = "Day {day}",
	DailyClaim = "Claim",
	DailyClaimed = "Come back tomorrow!",
	DailyGot = "Day {day}: +{coins} coins!",
	DailyGotGhost = "Day {day}: +{coins} coins and {ghost}!",
	DailyNext = "Next gift in {time}",
	DailyGhostBonus = "+ Epic ghost",
	OfflineEarned = "While you were away, your ghosts made {coins} coins: collect them on the green pads!",

	Shop = "Shop",
	ShopTitle = "SHOP",
	ShopDouble = "x2 Coins",
	ShopDoubleDesc = "Doubles all your income, forever",
	ShopLock = "Lock+",
	ShopLockDesc = "{long} s lock instead of {normal} s",
	ShopCoins = "Coin pack",
	ShopCoinsDesc = "+{coins} coins right now",
	ShopOwned = "Owned",
	ShopSoon = "Soon",
	ShopThanks = "Thanks! Purchase received",

	Tuto1 = "Buy!",
	Tuto2 = "Collect!",
	Tuto3 = "Steal!",

	StoredPill = "{coins} to collect",
	FloorBuy = "Buy floor 2",
	FloorLocked = "Floor 2: {coins}",
	FloorUp = "Floor 2",
	FloorDown = "Ground floor",
	FloorBought = "Floor 2 unlocked: 10 more pedestals!",
	LockStation = "LOCK",


	Index = "Ghostdex",
	IndexTitle = "GHOSTDEX",
	IndexNew = "New in the Ghostdex: {ghost}!",
	IndexRarityDone = "{rarity} set complete! +{coins} coins",
	IndexCompleteDone = "Ghostdex complete! +{percent}% income forever",
	IndexBonus = "Find them all: +{percent}% income forever",
	IndexBonusDone = "Ghostdex complete: +{percent}% income",
	IndexHint = "Tap a ghost to read its card",
	IndexUnknown = "???",
	IndexUnknownHint = "Not found yet. Watch the path... or other players' bases!",
	IndexCard = "{ghost}: {gag}",
	AnnIndexComplete = "{player} completed the Ghostdex!",

	Codes = "Secret codes",
	CodesDesc = "Enter a secret code",
	CodePlaceholder = "CODE",
	CodeRedeem = "OK",
	CodeOk = "Code redeemed: +{coins} coins!",
	CodeOkGhost = "Code redeemed: {ghost} is yours!",
	CodeUsed = "You already used this code",
	CodeInvalid = "Invalid code",
	CodeExpired = "This code has expired",

	Missions = "Missions",
	MissionsTitle = "DAILY MISSIONS",
	Mission_Buy = "Buy {n} ghosts",
	Mission_Earn = "Earn {n} coins",
	Mission_Lock = "Lock your base",
	Mission_Sell = "Sell {n} ghosts",
	Mission_BuyRare = "Buy a Rare ghost or better",
	Mission_NightOutside = "Stay {n} s outside your base during a Haunted Night",
	Mission_Steal = "Steal a ghost from another player",
	Mission_Bonk = "Stop a thief with a BONK",
	Mission_BuyEpic = "Buy an Epic ghost or better",
	MissionTier_easy = "Easy",
	MissionTier_medium = "Medium",
	MissionTier_hard = "Hard",
	MissionReward = "+{coins}",
	MissionDone = "Mission complete: +{coins} coins!",
	MissionsAllDone = "All 3 missions done! Bonus: +{coins} coins",
	MissionsBonus = "🎁 All 3 missions: {coins} coins bonus",
	MissionsBonusDone = "✅ Daily bonus collected, come back tomorrow!",
	MissionsNext = "New missions in {time}",

	LeaderTitle = "TOP THIEVES OF THE WEEK",
	LeaderEmpty = "Nobody has stolen anything this week... your turn!",
	LeaderSteals = "🦹 {count}",
	LeaderReset = "Resets in {days}d {hours}h",

	Close = "Close",
}

-- Remplace {mots} par les valeurs données. Ex : format("fr", "Sold", { coins = "1.2K" })
function Strings.format(lang: string, key: string, params: { [string]: any }?): string
	local tableForLang = Strings[lang] or Strings.en
	local text = tableForLang[key] or Strings.en[key] or key
	if params then
		text = string.gsub(text, "{(%w+)}", function(name)
			local value = params[name]
			if value == nil then
				return "{" .. name .. "}"
			end
			return tostring(value)
		end)
	end
	return text
end

return Strings
