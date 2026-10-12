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
	SlotLocked = "Rebirth pour débloquer",
	ThiefLabel = "VOLEUR !",

	-- Notifications
	NotEnoughCoins = "Pas assez de pièces !",
	NoFreePedestal = "Plus de socle libre ! Vends un fantôme.",
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
	AnnBigBuy = "{player} a attrapé {ghost} !",
	AnnRebirth = "{player} a fait son rebirth n°{count} !",
	AnnCaught = "Gloutrouille a attrapé {player} !",

	-- HUD
	Income = "+{coins}/s",
	FriendsBonus = "Amis +{percent} %",

	-- Nuit Hantée
	NightSoon = "La Nuit Hantée tombe dans {time} !",
	NightStart = "NUIT HANTÉE ! Fantômes rares... et Gloutrouille !",
	NightEnd = "Le jour se lève. Ouf !",
	NightTimer = "Nuit : {time}",
	DayTimer = "Nuit dans {time}",
	MonsterCaughtYou = "BOUH ! Gloutrouille t'a attrapé (-{coins} pièces)",
	SafeInBase = "Ta base te protège de Gloutrouille",

	-- Rebirth
	Rebirth = "Rebirth",
	RebirthTitle = "REBIRTH",
	RebirthDesc = "Recommence à zéro (pièces et fantômes) et gagne pour toujours :",
	RebirthGain = "+{percent} % de revenus  •  +1 socle",
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
	OfflineEarned = "Pendant ton absence, tes fantômes ont gagné {coins} pièces !",

	-- Boutique
	Shop = "Boutique",
	ShopTitle = "BOUTIQUE",
	ShopDouble = "x2 Pièces",
	ShopDoubleDesc = "Double tous tes revenus, pour toujours",
	ShopLock = "Verrou+",
	ShopLockDesc = "Verrou de 90 s au lieu de 60 s",
	ShopCoins = "Pack de pièces",
	ShopCoinsDesc = "+{coins} pièces tout de suite",
	ShopOwned = "Possédé",
	ShopSoon = "Bientôt",
	ShopThanks = "Merci ! Achat reçu",

	-- Tutoriel (3 flèches, très peu de texte)
	Tuto1 = "Achète !",
	Tuto2 = "Ta base",
	Tuto3 = "Vole !",


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
	SlotLocked = "Rebirth to unlock",
	ThiefLabel = "THIEF!",

	NotEnoughCoins = "Not enough coins!",
	NoFreePedestal = "No free pedestal! Sell a ghost.",
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
	AnnBigBuy = "{player} grabbed {ghost}!",
	AnnRebirth = "{player} just did rebirth #{count}!",
	AnnCaught = "Gloutrouille caught {player}!",

	Income = "+{coins}/s",
	FriendsBonus = "Friends +{percent}%",

	NightSoon = "The Haunted Night falls in {time}!",
	NightStart = "HAUNTED NIGHT! Rare ghosts... and Gloutrouille!",
	NightEnd = "The sun is rising. Phew!",
	NightTimer = "Night: {time}",
	DayTimer = "Night in {time}",
	MonsterCaughtYou = "BOO! Gloutrouille caught you (-{coins} coins)",
	SafeInBase = "Your base protects you from Gloutrouille",

	Rebirth = "Rebirth",
	RebirthTitle = "REBIRTH",
	RebirthDesc = "Start over (coins and ghosts) and earn forever:",
	RebirthGain = "+{percent}% income  •  +1 pedestal",
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
	OfflineEarned = "While you were away, your ghosts earned {coins} coins!",

	Shop = "Shop",
	ShopTitle = "SHOP",
	ShopDouble = "x2 Coins",
	ShopDoubleDesc = "Doubles all your income, forever",
	ShopLock = "Lock+",
	ShopLockDesc = "90 s lock instead of 60 s",
	ShopCoins = "Coin pack",
	ShopCoinsDesc = "+{coins} coins right now",
	ShopOwned = "Owned",
	ShopSoon = "Soon",
	ShopThanks = "Thanks! Purchase received",

	Tuto1 = "Buy!",
	Tuto2 = "Your base",
	Tuto3 = "Steal!",


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
