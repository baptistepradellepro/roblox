--[[
	Simulation de parties complètes avec le VRAI code serveur : `lune run tests/sim.luau`
	3 joueurs arrivent, achètent, volent, se font rattraper, la nuit tombe, rebirth,
	cadeau du jour, achats Robux, déconnexion / reconnexion avec la sauvegarde...
]]

local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Fake = require("./fakeroblox")
local Sched = Fake.Sched
local Vector3 = roblox.Vector3

local passed, failed = 0, 0
local function check(condition: any, message: string)
	if condition then
		passed += 1
	else
		failed += 1
		print("ÉCHEC : " .. message)
	end
end

local function section(name: string)
	print("-- " .. name)
end

-- Messages envoyés aux joueurs depuis un certain moment
local function mark(): number
	return #Fake.sentToClients
end
local function notified(player, key: string, since: number?): boolean
	for i = (since or 0) + 1, #Fake.sentToClients do
		local entry = Fake.sentToClients[i]
		if entry.remote == "Notify" and entry.to == player and entry.args[1] == key then
			return true
		end
	end
	return false
end
local function announced(key: string, since: number?): boolean
	for i = (since or 0) + 1, #Fake.sentToClients do
		local entry = Fake.sentToClients[i]
		if entry.remote == "Announce" and entry.args[1] == key then
			return true
		end
	end
	return false
end

math.randomseed(7)
Fake.mountProject()

-- Réglages de test (le module Config est partagé avec le serveur)
local Config = Fake.require("ReplicatedStorage.Shared.Config")
Config.Products.CoinPack = 999
Config.GamePasses.DoubleCoins = 555

Fake.runServer()
Sched.advance(1)

local RS = Fake.service("ReplicatedStorage")
local workspace = Fake.workspace
local DataService = Fake.require("ServerScriptService.Services.DataService")
local BaseService = Fake.require("ServerScriptService.Services.BaseService")
local GhostService = Fake.require("ServerScriptService.Services.GhostService")
local StealService = Fake.require("ServerScriptService.Services.StealService")
local EconomyService = Fake.require("ServerScriptService.Services.EconomyService")
local GhostData = Fake.require("ReplicatedStorage.Shared.GhostData")

section("Démarrage du serveur")
check(workspace:FindFirstChild("Map") ~= nil, "la map est construite")
check(RS:FindFirstChild("Remotes") ~= nil, "les RemoteEvents existent")
check(RS:FindFirstChild("PathGhosts") ~= nil and #RS.PathGhosts:GetChildren() >= 5, "des fantômes sont déjà sur le chemin")
check(RS:GetAttribute("NightActive") == false, "on commence de jour")

local function pedestalPos(player, slot: number): Vector3
	return BaseService.pedestalPosition(BaseService.getBase(player), slot)
end
local function baseCenter(player): Vector3
	return BaseService.getBase(player).Origin.Position + Vector3.new(0, 3, 0)
end
local function inOwnBase(player): boolean
	return BaseService.isInside(BaseService.getBase(player), Fake.position(player))
end
local function park(player, x: number, z: number)
	Fake.moveTo(player, Vector3.new(x, 3, z))
end

-- Vol complet : le voleur maintient 1,6 s sur le socle
local function steal(thief, owner, slot: number)
	Fake.moveTo(thief, pedestalPos(owner, slot) + Vector3.new(2, 1, 0))
	local index = BaseService.getBase(owner).Index
	Fake.fire(thief, "StealBegin", index, slot)
	Sched.advance(1.6)
	Fake.fire(thief, "Steal", index, slot)
end

section("Arrivée des joueurs")
local alice = Fake.addPlayer("Alice", 101)
local bob = Fake.addPlayer("Bob", 102)
local chloe = Fake.addPlayer("Chloe", 103)
Sched.advance(2)
for _, p in { alice, bob, chloe } do
	check(p:GetAttribute("Ready") == true, p.Name .. " est prêt")
	check(p:GetAttribute("BaseIndex") ~= nil, p.Name .. " a une base")
	check(p.Character ~= nil, p.Name .. " a un personnage")
	check(p.Character and inOwnBase(p), p.Name .. " apparaît dans sa base")
	check(notified(p, "StarterGift"), p.Name .. " reçoit le fantôme offert")
	check(notified(p, "ShieldOn"), p.Name .. " a le bouclier débutant")
	check(p:FindFirstChild("leaderstats") ~= nil, p.Name .. " a un classement")
end
local aData = DataService.get(alice)
local bData = DataService.get(bob)
local cData = DataService.get(chloe)
check(aData.Slots["1"] == Config.StarterGhost, "fantôme de départ sur le socle 1")
check(BaseService.getBase(alice) ~= BaseService.getBase(bob), "bases différentes")

section("Revenus")
local before = aData.Coins
Sched.advance(10)
local gained = aData.Coins - before
check(gained >= 19 and gained <= 21, "2 pièces/s pendant 10 s (gagné : " .. gained .. ")")
check(alice:GetAttribute("Coins") == math.floor(aData.Coins), "attribut Coins à jour")
check(alice:GetAttribute("Income") == 2, "revenu affiché = 2/s")

section("Achat sur le chemin")
aData.Coins = 10_000_000
local function pathPosition(holder): Vector3
	local now = workspace:GetServerTimeNow()
	local x = Config.PathStartX + (now - holder:GetAttribute("SpawnTime")) * Config.PathSpeed
	return Vector3.new(x, 3, Config.PathZ)
end
local holders = RS.PathGhosts:GetChildren()
local target = holders[1]
local boughtId = target:GetAttribute("GhostId")
Fake.moveTo(alice, pathPosition(target))
local m = mark()
Fake.fire(alice, "BuyGhost", target.Name)
check(aData.Slots["2"] == boughtId, "le fantôme acheté est sur le socle 2")
check(target.Parent == nil, "il a disparu du chemin")
check(notified(alice, "Bought", m), "message d'achat")
check(alice:GetAttribute("HasBought") == true, "tutoriel : achat noté")
check(aData.Coins == 10_000_000 - GhostData.get(boughtId).Price, "le prix est retiré")

local other = RS.PathGhosts:GetChildren()[1]
Sched.advance(0.3) -- anti-spam : une demande d'achat toutes les 0,25 s maximum
m = mark()
Fake.moveTo(alice, pathPosition(other) + Vector3.new(0, 0, 60))
Fake.fire(alice, "BuyGhost", other.Name)
check(notified(alice, "TooFar", m) and other.Parent ~= nil, "achat refusé de trop loin")

bData.Coins = 0
m = mark()
Fake.moveTo(bob, pathPosition(other))
Fake.fire(bob, "BuyGhost", other.Name)
check(notified(bob, "NotEnoughCoins", m) and other.Parent ~= nil, "achat refusé sans argent")
Sched.advance(0.3)
m = mark()
Fake.fire(bob, "BuyGhost", 12345)
Sched.advance(0.3)
Fake.fire(bob, "BuyGhost", "inexistant")
check(notified(bob, "AlreadyGone", m), "uid invalide refusé proprement")

section("Vente")
local coinsBefore = aData.Coins
Fake.moveTo(alice, pedestalPos(alice, 2))
Fake.fire(alice, "SellGhost", 2)
check(aData.Slots["2"] == nil, "fantôme vendu")
check(aData.Coins == coinsBefore + math.floor(GhostData.get(boughtId).Price * Config.SellRatio), "50 % du prix remboursé")
Sched.advance(0.4)
Fake.fire(alice, "SellGhost", 99)
Sched.advance(0.4)
Fake.fire(alice, "SellGhost", "1")
Sched.advance(0.4)
Fake.fire(alice, "SellGhost", 1.5)
check(aData.Slots["1"] ~= nil, "ventes invalides ignorées")

section("Vol pendant le bouclier débutant")
m = mark()
steal(bob, alice, 1)
check(notified(bob, "BaseIsLocked", m), "vol refusé : base protégée")
check(bob:GetAttribute("CarryGhost") == nil, "Bob ne porte rien")

section("Vol sans maintenir 1,5 s (triche)")
Sched.advance(Config.NewPlayerShield + 1)
Fake.moveTo(bob, pedestalPos(alice, 1))
Fake.fire(bob, "StealBegin", BaseService.getBase(alice).Index, 1)
Fake.fire(bob, "Steal", BaseService.getBase(alice).Index, 1)
check(bob:GetAttribute("CarryGhost") == nil, "vol instantané refusé")
Sched.advance(0.4)
Fake.fire(bob, "Steal", BaseService.getBase(alice).Index, 1)
check(bob:GetAttribute("CarryGhost") == nil, "vol sans début de maintien refusé")

section("Vol réussi")
park(alice, 160, 75) -- Alice est loin
local aliceIncome = alice:GetAttribute("Income")
steal(bob, alice, 1)
check(bob:GetAttribute("CarryGhost") == Config.StarterGhost, "Bob porte le fantôme")
check(BaseService.getBase(alice).Pedestals[1]:GetAttribute("Stolen") == true, "le socle d'Alice affiche le vol")
check(alice:GetAttribute("Income") < aliceIncome, "Alice ne gagne plus rien avec ce fantôme")
check(bob.Character.Humanoid.WalkSpeed == Config.CarrierWalkSpeed, "Bob est ralenti")
m = mark()
Fake.walk(bob, baseCenter(bob), Config.CarrierWalkSpeed * 0.95)
Sched.advance(0.2)
check(bob:GetAttribute("CarryGhost") == nil, "livraison terminée")
local bobHas = false
for _, id in bData.Slots do
	if id == Config.StarterGhost then
		bobHas = true
	end
end
check(bobHas, "le fantôme est maintenant chez Bob")
check(aData.Slots["1"] == nil, "Alice l'a perdu")
check(announced("AnnSteal", m), "annonce du vol à tout le serveur")
check(bData.TotalSteals == 1, "compteur de vols")
check(bob.Character.Humanoid.WalkSpeed == Config.NormalWalkSpeed, "Bob retrouve sa vitesse")

section("Récupération par le propriétaire")
GhostService.giveGhost(alice, "Caquetome")
local slot = nil
for key, id in aData.Slots do
	if id == "Caquetome" then
		slot = tonumber(key)
	end
end
steal(bob, alice, slot)
check(bob:GetAttribute("CarryGhost") == "Caquetome", "Bob vole le Caquetôme")
m = mark()
Fake.moveTo(alice, Fake.position(bob) + Vector3.new(2, 0, 0))
Sched.advance(0.3)
check(bob:GetAttribute("CarryGhost") == nil, "Alice a rattrapé Bob")
check(aData.Slots[tostring(slot)] == "Caquetome" and not BaseService.isStolenOut(alice, slot), "le fantôme est revenu")
check(notified(alice, "Recovered", m) and notified(bob, "StealFailCaught", m), "messages de récupération")

section("Marteau Pouet")
park(alice, 160, 75)
steal(bob, alice, slot)
check(bob:GetAttribute("CarryGhost") == "Caquetome", "nouveau vol")
Fake.moveTo(bob, Vector3.new(0, 3, 12))
Fake.moveTo(chloe, Vector3.new(4, 3, 12))
m = mark()
Fake.fire(chloe, "Bonk")
check(bob:GetAttribute("CarryGhost") == nil, "Bob a lâché le fantôme")
check(notified(chloe, "BonkHit", m) and notified(bob, "StealFailBonk", m), "messages du Marteau Pouet")
check(bob.Character.Humanoid.WalkSpeed == 4, "Bob est étourdi")
Sched.advance(Config.BonkStunTime + 0.1)
check(bob.Character.Humanoid.WalkSpeed == Config.NormalWalkSpeed, "Bob n'est plus étourdi")
m = mark()
Fake.fire(chloe, "Bonk")
check(not notified(chloe, "BonkHit", m), "pas de Pouet sans voleur")

section("Anti-triche vitesse")
park(chloe, -160, -75)
steal(bob, alice, slot)
check(bob:GetAttribute("CarryGhost") ~= nil, "vol lancé")
park(bob, -100, 70)
Sched.advance(1.1)
park(bob, 100, 70)
Sched.advance(1.1)
check(bob:GetAttribute("CarryGhost") == nil, "téléportation détectée : vol annulé")
check(aData.Slots[tostring(slot)] == "Caquetome", "le fantôme est rentré")

section("Trop lent (45 s)")
Sched.advance(1)
steal(bob, alice, slot)
check(bob:GetAttribute("CarryGhost") ~= nil, "vol lancé")
park(bob, 40, 12)
m = mark()
Sched.advance(Config.StealTimeout + 1)
check(bob:GetAttribute("CarryGhost") == nil, "délai dépassé : vol annulé")
check(notified(bob, "StealFailTimeout", m), "message 'trop lent'")

section("Verrou de base")
Fake.moveTo(bob, pedestalPos(alice, slot))
m = mark()
Fake.fire(alice, "RequestLock")
check(notified(alice, "LockOn", m), "base verrouillée")
check(BaseService.getBase(alice).Model:FindFirstChild("Barrier") ~= nil, "la barrière est là")
Sched.advance(0.5)
check(not BaseService.isInside(BaseService.getBase(alice), Fake.position(bob)), "Bob est renvoyé dehors")
m = mark()
steal(bob, alice, slot)
check(notified(bob, "BaseIsLocked", m), "vol impossible pendant le verrou")
Sched.advance(Config.LockDuration + 1)
check(BaseService.getBase(alice).Model:FindFirstChild("Barrier") == nil, "la barrière disparaît après 60 s")
m = mark()
Fake.fire(alice, "RequestLock")
check(notified(alice, "LockNotReady", m), "le verrou recharge")
Sched.advance(Config.LockCooldown + 1)
m = mark()
Fake.fire(alice, "RequestLock")
check(notified(alice, "LockOn", m), "le verrou est de nouveau disponible")
Sched.advance(Config.LockDuration + 1)

section("Nuit Hantée")
local nextNight = RS:GetAttribute("NextNightAt")
check(nextNight ~= nil, "prochaine nuit programmée")
m = mark()
Sched.advance(nextNight - workspace:GetServerTimeNow() + 1)
check(RS:GetAttribute("NightActive") == true, "la nuit est tombée")
check(announced("NightSoon", m) and announced("NightStart", m), "annonces de la nuit")
local anchor = workspace:FindFirstChild("GloutrouilleAnchor")
check(anchor ~= nil, "Gloutrouille est là")
-- les autres sont à l'abri chez eux
Fake.moveTo(alice, baseCenter(alice))
Fake.moveTo(bob, baseCenter(bob))
Fake.moveTo(chloe, Vector3.new(-100, 3, 0))
Sched.advance(1)
check(anchor:GetAttribute("TargetUserId") == chloe.UserId, "il poursuit Chloé, seule dehors")
local monsterBefore = anchor.Position
Sched.advance(1)
check((anchor.Position - monsterBefore).Magnitude > 10, "il se rapproche")
cData.Coins = 1000
m = mark()
Fake.moveTo(chloe, anchor.Position + Vector3.new(1, -2, 0))
Sched.advance(0.2)
check(announced("AnnCaught", m), "annonce : Chloé attrapée")
check(cData.Coins < 1000 and cData.Coins >= 940, "Chloé perd 5 % (reste " .. cData.Coins .. ")")
check(inOwnBase(chloe), "Chloé est renvoyée chez elle")
-- un voleur attrapé lâche le fantôme
steal(bob, alice, slot)
check(bob:GetAttribute("CarryGhost") ~= nil, "vol de nuit")
Fake.moveTo(bob, anchor.Position + Vector3.new(1, -2, 0))
Sched.advance(0.3)
check(bob:GetAttribute("CarryGhost") == nil, "Gloutrouille fait lâcher le fantôme")
Sched.advance(Config.NightDuration)
check(RS:GetAttribute("NightActive") == false, "le jour revient")
check(workspace:FindFirstChild("GloutrouilleAnchor") == nil, "Gloutrouille est parti")

section("Rebirth")
m = mark()
aData.Coins = 10
Fake.fire(alice, "Rebirth")
check(notified(alice, "RebirthNotEnough", m) and aData.Rebirths == 0, "rebirth refusé sans argent")
Sched.advance(3)
aData.Coins = 2_000_000
Fake.fire(alice, "Rebirth")
check(aData.Rebirths == 1, "rebirth fait")
check(aData.Coins == Config.StartCoins, "pièces remises à zéro")
local count = 0
for _ in aData.Slots do
	count += 1
end
check(count == 1 and aData.Slots["1"] == Config.StarterGhost, "il ne reste que le fantôme de départ")
check(BaseService.getBase(alice).Pedestals[9]:GetAttribute("Unlocked") == true, "un 9e socle est débloqué")
check(alice:GetAttribute("Multiplier") == 1.5, "multiplicateur x1,5")
check(announced("AnnRebirth", m), "annonce du rebirth")

section("Cadeau du jour")
local coins0 = aData.Coins
Fake.fire(alice, "ClaimDaily")
check(aData.Coins > coins0 and aData.DailyStreak == 1, "cadeau du jour 1 reçu")
Sched.advance(2)
local coins1 = aData.Coins
Fake.fire(alice, "ClaimDaily")
Sched.advance(0.01)
check(aData.Coins - coins1 < 10, "pas de deuxième cadeau le même jour")

section("Achats Robux")
local MarketplaceService = Fake.service("MarketplaceService")
local receipt = { PlayerId = alice.UserId, PurchaseId = "achat-1", ProductId = 999 }
local c0 = aData.Coins
local decision = MarketplaceService.ProcessReceipt(receipt)
check(decision == roblox.Enum.ProductPurchaseDecision.PurchaseGranted, "pack de pièces accordé")
check(aData.Coins >= c0 + Config.CoinPackMin, "pièces du pack reçues")
local c1 = aData.Coins
MarketplaceService.ProcessReceipt(receipt)
check(aData.Coins - c1 < 50, "le même achat n'est jamais crédité deux fois")
local unknown = MarketplaceService.ProcessReceipt({ PlayerId = alice.UserId, PurchaseId = "x", ProductId = 1 })
check(unknown == roblox.Enum.ProductPurchaseDecision.NotProcessedYet, "produit inconnu non accordé")
local mult = alice:GetAttribute("Multiplier")
MarketplaceService.PromptGamePassPurchaseFinished:Fire(alice, 555, true)
check(alice:GetAttribute("DoubleCoins") == true and alice:GetAttribute("Multiplier") == mult * 2, "Game Pass x2 actif")

section("Le propriétaire quitte pendant un vol")
GhostService.giveGhost(chloe, "WifiFantome")
local chloeSlot
for key, id in cData.Slots do
	if id == "WifiFantome" then
		chloeSlot = tonumber(key)
	end
end
park(chloe, 160, -75)
steal(bob, chloe, chloeSlot)
check(bob:GetAttribute("CarryGhost") == "WifiFantome", "Bob vole Chloé")
m = mark()
Fake.removePlayer(chloe)
Sched.advance(1)
check(bob:GetAttribute("CarryGhost") == nil, "plus de vol en cours")
local bobGotIt = false
for _, id in bData.Slots do
	if id == "WifiFantome" then
		bobGotIt = true
	end
end
check(bobGotIt and notified(bob, "OwnerLeftGift", m), "Bob reçoit le fantôme")
local raw = Fake.dataStores[Config.DataStoreName]["Player_103"]
check(raw ~= nil and not string.find(raw, "WifiFantome"), "la sauvegarde de Chloé ne l'a plus")
check(raw ~= nil and not string.find(raw, '"Lock"'), "le verrou de session de Chloé est libéré")

section("Sauvegarde et retour d'Alice")
local savedRebirths = aData.Rebirths
Fake.removePlayer(alice)
Sched.advance(1)
check(DataService.get(alice) == nil, "profil libéré")
Sched.advance(600)
local alice2 = Fake.addPlayer("Alice", 101)
Sched.advance(2)
local aData2 = DataService.get(alice2)
check(aData2 ~= nil and aData2.Rebirths == savedRebirths, "rebirth retrouvé après reconnexion")
check(notified(alice2, "OfflineEarned"), "gains hors ligne")
check(not notified(alice2, "StarterGift", m), "pas de deuxième fantôme offert")
check(alice2:GetAttribute("TutorialDone") == false, "tutoriel pas encore fini")
Fake.fire(alice2, "TutorialDone")
check(aData2.TutorialDone == true, "tutoriel noté comme fini")

section("Verrou de session (changement de serveur rapide)")
local store = Fake.dataStores[Config.DataStoreName]
store["Player_104"] = '{"Coins":5000,"Slots":{},"Rebirths":2,"Lock":{"Job":"autre-serveur","Time":' .. (Fake.os.time()) .. "}}"
local dan = Fake.addPlayer("Dan", 104)
Sched.advance(3)
check(dan:GetAttribute("Ready") ~= true, "Dan attend que l'autre serveur libère sa sauvegarde")
Sched.advance(40)
check(dan:GetAttribute("Ready") == true, "Dan joue après l'attente maximale")
check(DataService.get(dan).Rebirths == 2 and DataService.get(dan).Coins >= 5000, "ses données sont bien reprises")

section("Erreurs passagères du DataStore")
Fake.dataStoreFailures = 2
local eve = Fake.addPlayer("Eve", 105)
Sched.advance(10)
check(eve:GetAttribute("Ready") == true, "chargement réussi après 2 erreurs")

section("Arrêt du serveur")
for _, callback in Fake.closeCallbacks or {} do
	Sched.spawn(callback)
end
Sched.advance(5)
local savedBob = store["Player_102"]
check(savedBob ~= nil and string.find(savedBob, "WifiFantome") ~= nil, "Bob est sauvegardé à l'arrêt")

-- Bilan
local _ = EconomyService
local _s = StealService
for _, e in Fake.propertyErrors do
	print("  propriété invalide : " .. e)
end
check(#Fake.propertyErrors == 0, "toutes les propriétés Roblox utilisées existent")
check(#Sched.errors == 0, "aucune erreur Luau pendant la simulation (" .. #Sched.errors .. ")")
if #Fake.warnings > 0 then
	print("Avertissements du jeu :")
	for _, w in Fake.warnings do
		print("  " .. w)
	end
end
print(string.format("\n%d vérifications réussies, %d échouées", passed, failed))
if failed > 0 then
	process.exit(1)
end
